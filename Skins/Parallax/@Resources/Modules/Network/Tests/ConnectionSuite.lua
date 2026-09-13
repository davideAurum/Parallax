-- Synthetic connection fixtures exercise presentation only; no Wi-Fi API is called.
local Suite = {}

function Suite.run(Core, Connection, fixtures)
    local passed, failed, report = 0, 0, {}
    local function equal(actual, expected, label)
        if actual ~= expected then error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
    end
    local function truth(value, label) if not value then error(label or 'expected true', 2) end end
    local function contains(value, part) truth(tostring(value):find(part, 1, true), 'expected ' .. tostring(value) .. ' to contain ' .. part) end
    local function test(name, body)
        local ok, err = pcall(body)
        if ok then passed = passed + 1; report[#report + 1] = 'PASS: ' .. name
        else failed = failed + 1; report[#report + 1] = 'FAIL: ' .. name .. ': ' .. tostring(err) end
    end
    local function adapter(overrides)
        local a = { selector = 'Best', alias = 'Ethernet', description = 'Synthetic test adapter',
            guid = '{12345678-1234-1234-1234-123456789ABC}', status = 1, state = 1, type = 6,
            internet = 1, ip = '192.0.2.2', gateway = '192.0.2.1', receiveSpeed = 1000000000, transmitSpeed = 1000000000 }
        for k, v in pairs(overrides or {}) do a[k] = v end
        return a
    end
    local function wifi(overrides)
        local w = { ssid = 'Synthetic WLAN', quality = 80, phy = '802.11ax', receiveRate = 1200000000, transmitRate = 600000000 }
        for k, v in pairs(overrides or {}) do w[k] = v end
        return w
    end
    local function describe(a, w, config)
        return Connection.describe(Core, a or adapter(), w or wifi(), config or Connection.configureWifi('1', '0'))
    end

    test('configuration accepts only enabled flags and bounded digit indexes', function()
        for _, raw in ipairs({'0', '1', '63', '00'}) do
            local c = Connection.configureWifi('1', raw)
            equal(c.enabled, true); equal(c.index, tonumber(raw)); equal(c.error, nil)
        end
        local disabled = Connection.configureWifi('0', '7')
        equal(disabled.enabled, false); equal(disabled.index, 7); equal(disabled.error, nil)
    end)
    test('invalid enabled values never reach a native index', function()
        for _, raw in ipairs({'', 'true', '2', '-1', ' 1 ', 1, true}) do
            local c = Connection.configureWifi(raw, '3')
            equal(c.enabled, false); equal(c.index, 0); truth(c.error)
        end
        equal(Connection.configureWifi(nil, '0').enabled, false)
    end)
    test('negative, nonnumeric, fractional and oversized indexes disable querying', function()
        for _, raw in ipairs({'', '-1', '+1', '1.0', '1e1', '0x10', '64', '999999999999999999999', 'Best', ' 1 ', 1}) do
            local c = Connection.configureWifi('1', raw)
            equal(c.enabled, false); equal(c.index, 0); truth(c.error)
        end
        equal(Connection.configureWifi('1', nil).enabled, false)
        truth(Connection.configureWifi('0', '-1').error)
    end)
    test('verified adapter metadata and native link units are preserved', function()
        local d = describe()
        equal(d.adapter, 'Ethernet'); equal(d.description, 'Synthetic test adapter')
        equal(d.status, 'Ethernet / Up'); equal(d.statusColor, 'GoodColor')
        equal(d.ip, '192.0.2.2'); equal(d.gateway, '192.0.2.1')
        equal(d.receiveLink, '1.0 Gbit/s'); equal(d.transmitLink, '1.0 Gbit/s')
    end)
    test('adapter type distinguishes Ethernet, Wi-Fi and other', function()
        contains(describe(adapter({type = 71})).status, 'Wi-Fi / ')
        contains(describe(adapter({type = 131})).status, 'Other / ')
    end)
    test('invalid named fallback suppresses all selected-adapter data', function()
        local d = describe(adapter({selector = 'Missing NIC'}))
        equal(d.status, 'Selected NIC not found'); equal(d.description, '--')
        equal(d.ip, '--'); equal(d.gateway, '--'); equal(d.receiveLink, '--'); equal(d.transmitLink, '--')
        equal(d.internet, 'Detected'); equal(d.wifiName, 'Wi-Fi: Synthetic WLAN')
    end)
    test('missing GUID rejects even otherwise plausible adapter metadata', function()
        local d = describe(adapter({guid = '0'}))
        equal(d.status, 'Adapter unavailable'); equal(d.description, '--'); equal(d.receiveLink, '--')
    end)
    test('down adapters retain model identity while hiding addresses and links', function()
        local labels = { [-3] = 'Not present', [-2] = 'Lower layer down', [-1] = 'Down', [0] = 'Status unknown', [2] = 'Dormant', [3] = 'Testing' }
        for status, label in pairs(labels) do
            local d = describe(adapter({status = status}))
            equal(d.description, 'Synthetic test adapter'); contains(d.status, label)
            equal(d.ip, '--'); equal(d.gateway, '--'); equal(d.receiveLink, '--'); equal(d.transmitLink, '--')
            equal(d.statusColor, 'WarningColor')
        end
    end)
    test('media disconnection overrides operational Up', function()
        local d = describe(adapter({state = -1}))
        equal(d.status, 'Ethernet / Disconnected'); equal(d.receiveLink, '--'); equal(d.ip, '--')
    end)
    test('PC Internet report remains independent of selected NIC state', function()
        local online = describe(adapter({status = -1, internet = 1}))
        equal(online.internet, 'Detected'); equal(online.internetColor, 'GoodColor')
        local unreported = describe(adapter({status = 1, internet = -1}))
        equal(unreported.internet, 'Not reported'); equal(unreported.statusColor, 'GoodColor')
        for _, value in ipairs({0, 2, -2, '1'}) do equal(describe(adapter({internet = value})).internet, 'Unknown') end
    end)
    test('empty alias falls back to available adapter description', function()
        equal(describe(adapter({alias = ''})).adapter, 'Synthetic test adapter')
    end)
    test('unspecified addresses and nonpositive links remain unavailable', function()
        local d = describe(adapter({ip = '0.0.0.0', gateway = '::', receiveSpeed = 0, transmitSpeed = -1}))
        equal(d.ip, '--'); equal(d.gateway, '--'); equal(d.receiveLink, '--'); equal(d.transmitLink, '--')
        equal(describe(adapter({receiveSpeed = math.huge})).receiveLink, '--')
    end)
    test('disabled Wi-Fi cannot leak retained native readings or a signal bar', function()
        local d = describe(nil, nil, Connection.configureWifi('0', '0'))
        equal(d.wifiName, 'Wi-Fi off in module'); equal(d.signal, '--'); equal(d.signalPercent, nil)
        equal(d.radio, 'Radio unavailable')
    end)
    test('invalid Wi-Fi configuration has a visible repair state', function()
        local d = describe(nil, nil, Connection.configureWifi('1', '-2'))
        equal(d.wifiName, 'Check Wi-Fi settings'); equal(d.signalPercent, nil)
        contains(d.wifiTooltip, '0 to 63')
    end)
    test('malformed configuration objects fail closed', function()
        for _, c in ipairs({{enabled = true, index = -1}, {enabled = true, index = 64}, {enabled = '1', index = 0}}) do
            equal(describe(nil, nil, c).wifiName, 'Check Wi-Fi settings')
        end
    end)
    test('native SSID error sentinels suppress plausible stale Wi-Fi values', function()
        for _, ssid in ipairs({'', ' ', '-1', '0'}) do
            local d = describe(nil, wifi({ssid = ssid}))
            equal(d.wifiName, 'Wi-Fi unavailable'); equal(d.signalPercent, nil)
            contains(d.wifiTooltip, 'Location')
        end
    end)
    test('pending native SSIDs never present connection quality as current', function()
        for _, suffix in ipairs({'(connecting...)', '(authorizing...)'}) do
            local d = describe(nil, wifi({ssid = 'Synthetic WLAN' .. suffix}))
            equal(d.wifiName, 'Wi-Fi: Synthetic WLAN' .. suffix); equal(d.signal, 'Pending'); equal(d.radio, 'Radio: Pending'); equal(d.signalPercent, nil)
        end
    end)
    test('SSID alone with only numeric zeros is insufficient connection proof', function()
        local d = describe(nil, wifi({phy = '0', receiveRate = 0, transmitRate = 0, quality = 0}))
        equal(d.wifiName, 'Wi-Fi unavailable'); equal(d.signalPercent, nil)
    end)
    test('connected signal zero is real weak quality and keeps its bar value', function()
        local d = describe(nil, wifi({quality = 0, receiveRate = 0, transmitRate = 0}))
        equal(d.wifiName, 'Wi-Fi: Synthetic WLAN'); equal(d.signal, '0%'); equal(d.signalPercent, 0); equal(d.signalColor, 'DangerColor')
    end)
    test('unknown PHY can use a positive native link to prove querying', function()
        local d = describe(nil, wifi({phy = '???', quality = 0}))
        equal(d.wifiName, 'Wi-Fi: Synthetic WLAN'); equal(d.signalPercent, 0); equal(d.radio, 'Radio unavailable')
    end)
    test('invalid signal quality is withheld without fabricating zero', function()
        for _, quality in ipairs({-1, 101, math.huge, -math.huge, 0/0, '80'}) do
            local d = describe(nil, wifi({quality = quality}))
            equal(d.wifiName, 'Wi-Fi: Synthetic WLAN'); equal(d.signal, 'Unavailable'); equal(d.signalPercent, nil)
            equal(d.signalColor, 'MutedColor')
        end
    end)
    test('quality colors and values cover weak, moderate and strong readings', function()
        for _, fixture in ipairs({{25, 'DangerColor'}, {26, 'WarningColor'}, {50, 'WarningColor'}, {51, 'GoodColor'}, {100, 'GoodColor'}}) do
            local d = describe(nil, wifi({quality = fixture[1]}))
            equal(d.signalPercent, fixture[1]); equal(d.signalColor, fixture[2])
        end
    end)
    test('Wi-Fi link rates stay bits per second without a second multiplier', function()
        local d = describe()
        contains(d.wifiTooltip, 'RX: 1.2 Gbit/s'); contains(d.wifiTooltip, 'TX: 600.0 Mbit/s')
        equal(d.radio, 'Radio: 802.11ax')
        contains(d.wifiTooltip, 'channel and frequency band are not exposed')
    end)
    test('Wi-Fi source disclosure never implies selected adapter matching', function()
        local d = describe(adapter({type = 6}), nil, Connection.configureWifi('1', '3'))
        equal(d.wifiName, 'Wi-Fi: Synthetic WLAN')
        contains(d.wifiTooltip, 'WLAN index 3'); contains(d.wifiTooltip, 'separate from the selected adapter')
        contains(d.wifiTooltip, 'may fall back to 0')
    end)
    test('all displayed external strings and tooltips are sanitized', function()
        local d = describe(adapter({alias = 'NIC #x# [!Quit]', description = 'Model\n[!Quit]', ip = '192.0.2.2#x#', gateway = '192.0.2.1[evil]'}),
            wifi({ssid = 'SSID #CURRENTCONFIG# [!Quit]\nline'}))
        for key, value in pairs(d) do
            if type(value) == 'string' then truth(not value:find('[%c#%[%]]'), key .. ' contains executable delimiters') end
        end
        local invalid = describe(nil, nil, {enabled = false, index = 0, error = '#bad#[!Quit]\n'})
        truth(not invalid.wifiTooltip:find('[%c#%[%]]'))
    end)
    test('missing source tables remain explicitly unavailable', function()
        local d = Connection.describe(Core, {}, {}, Connection.configureWifi('1', '0'))
        equal(d.internet, 'Unknown'); equal(d.ip, '--'); equal(d.wifiName, 'Wi-Fi unavailable'); equal(d.signalPercent, nil)
    end)

    local function read(path)
        local file = assert(io.open(path, 'rb'))
        local data = assert(file:read('*a'))
        assert(file:close())
        return data
    end
    local meterNames, measureNames = {}, {}
    for name in ('\n' .. read(fixtures.moduleRoot .. '\\ConnectionMeters.inc')):gmatch('\n%s*%[([^%]\r\n]+)%]') do meterNames[name] = true end
    for name in ('\n' .. read(fixtures.moduleRoot .. '\\ConnectionMeasures.inc')):gmatch('\n%s*%[([^%]\r\n]+)%]') do measureNames[name] = true end
    local wifiNames = {'SSID', 'Quality', 'PHY', 'Rx', 'Tx'}
    local function controller(overrides)
        local mock = {calls = {}, latest = {}, adapter = adapter(), wifi = wifi(), missing = {},
            dimensions = {SignalWidth = 188, SignalHeight = 3},
            variables = { NetworkInterface = 'Best', NetworkWiFiEnabled = '1',
                NetworkWiFiInterface = '0', GoodColor = '20,200,20', WarningColor = '200,150,20',
                DangerColor = '200,20,20', MutedColor = '150,150,150', ['@'] = 'C:\\ParallaxTest\\@Resources\\' }}
        for key, value in pairs(overrides or {}) do mock.variables[key] = value end
        local fields = {Alias = 'alias', Description = 'description', Guid = 'guid', Status = 'status',
            State = 'state', Type = 'type', Internet = 'internet', IP = 'ip', Gateway = 'gateway',
            RxLink = 'receiveSpeed', TxLink = 'transmitSpeed'}
        local wifiFields = {WiFiSSID = 'ssid', WiFiQuality = 'quality', WiFiPHY = 'phy', WiFiRx = 'receiveRate', WiFiTx = 'transmitRate'}
        local skin = {}
        function skin:GetVariable(key, default) return mock.variables[key] or default end
        function skin:GetMeasure(name)
            truth(measureNames[name], 'unknown controller measure: ' .. name)
            if mock.missing[name] then return nil end
            local suffix = name:match('^MeasureConnection(.+)$')
            local source, key = mock.adapter, fields[suffix]
            if wifiFields[suffix] then source, key = mock.wifi, wifiFields[suffix] end
            truth(key, 'unmapped controller measure: ' .. name)
            return {GetValue = function() return source[key] end, GetStringValue = function() return source[key] end}
        end
        function skin:Bang(bang, ...)
            local args = {...}; mock.calls[#mock.calls + 1] = {bang = bang, args = args}
            if bang == '!SetOption' then
                truth(meterNames[args[1]] or measureNames[args[1]], 'unknown controller section: ' .. tostring(args[1]))
                if measureNames[args[1]] then
                    truth(args[1]:match('^MeasureConnectionWiFi'), 'controller changed a non-Wi-Fi measure')
                    truth(args[2] == 'WiFiIntfID' or args[2] == 'Disabled', 'unexpected native option mutation')
                    if args[2] == 'WiFiIntfID' then
                        truth(type(args[3]) == 'string' and args[3]:match('^%d+$'), 'unsafe native index text')
                        truth(tonumber(args[3]) <= 63, 'unsafe native index range')
                    end
                end
                mock.latest[args[1] .. ':' .. args[2]] = args[3]
            elseif bang == '!EnableMeasure' or bang == '!DisableMeasure' then
                truth(measureNames[args[1]] and args[1]:match('^MeasureConnectionWiFi'), 'unknown Wi-Fi enable/disable target')
            else
                error('unexpected controller side effect: ' .. bang)
            end
        end
        local self = {}
        function self:GetOption(key)
            return fixtures.moduleRoot .. '\\' .. assert(({CoreFile = 'Core.lua', ConnectionCoreFile = 'ConnectionCore.lua'})[key], key)
        end
        function self:GetNumberOption(key, default) return mock.dimensions[key] or default end
        local env = setmetatable({SKIN = skin, SELF = self}, {__index = _G})
        local chunk = assert(loadfile(fixtures.moduleRoot .. '\\Connection.lua'))
        setfenv(chunk, env); chunk(); env.Initialize()
        function mock:tick() return env.Update() end
        function mock:count(bang)
            local n = 0; for _, call in ipairs(self.calls) do if call.bang == bang then n = n + 1 end end; return n
        end
        mock.environment = env
        return mock
    end
    test('controller initializes every Wi-Fi measure with one validated index', function()
        local mock = controller({NetworkWiFiInterface = '03'})
        equal(#mock.calls, 15); equal(mock:count('!EnableMeasure'), 5)
        for _, suffix in ipairs(wifiNames) do
            equal(mock.latest['MeasureConnectionWiFi' .. suffix .. ':WiFiIntfID'], '3')
            equal(mock.latest['MeasureConnectionWiFi' .. suffix .. ':Disabled'], '0')
        end
        equal(mock:count('!WriteKeyValue'), 0)
    end)
    test('invalid raw indexes disable all native Wi-Fi queries using safe index zero', function()
        for _, raw in ipairs({'-1', '64', 'not a number', '[!Quit]'}) do
            local mock = controller({NetworkWiFiInterface = raw})
            equal(mock:count('!DisableMeasure'), 5); equal(mock:count('!EnableMeasure'), 0)
            for _, suffix in ipairs(wifiNames) do
                equal(mock.latest['MeasureConnectionWiFi' .. suffix .. ':WiFiIntfID'], '0')
                equal(mock.latest['MeasureConnectionWiFi' .. suffix .. ':Disabled'], '1')
            end
            equal(mock:tick(), 0); equal(mock.latest['MeterConnectionWiFi:Text'], 'Check Wi-Fi settings')
        end
    end)
    test('disabled module and malformed enable flag disable all five native fields', function()
        for _, flag in ipairs({'0', 'true'}) do
            local mock = controller({NetworkWiFiEnabled = flag})
            equal(mock:count('!DisableMeasure'), 5); equal(mock:count('!EnableMeasure'), 0)
            equal(mock:tick(), 0); equal(mock.latest['MeterConnectionSignal:Text'], '--')
        end
    end)
    test('controller polling targets real meters without native mutations or persisted writes', function()
        local mock = controller(); mock.calls = {}
        for i = 1, 65 do equal(mock:tick(), 1) end
        equal(mock.latest['MeterConnectionRx:Text'], '1.0 Gbit/s')
        equal(mock.latest['MeterConnectionWiFi:Text'], 'Wi-Fi: Synthetic WLAN')
        contains(mock.latest['MeterConnectionSignalBar:Shape2'], '150.400')
        for _, call in ipairs(mock.calls) do
            equal(call.bang, '!SetOption')
            truth(meterNames[call.args[1]], 'polling mutated a native measure')
        end
        equal(mock:count('!WriteKeyValue'), 0); equal(mock:count('!Refresh'), 0)
        mock.calls = {}; mock:tick(); equal(#mock.calls, 0, 'unchanged display should not rewrite cached options')
    end)
    test('controller sanitizes text and clears unavailable signal while preserving real zero', function()
        local mock = controller()
        mock.adapter.alias = 'NIC #x# [!Quit]'; mock.wifi.ssid = 'SSID #x# [!Quit]'
        mock.wifi.quality = 0
        equal(mock:tick(), 1)
        equal(mock.latest['MeterConnectionSignal:Text'], '0%')
        contains(mock.latest['MeterConnectionSignalBar:Shape2'], 'Rectangle 0,0,0.000,3')
        for key, value in pairs(mock.latest) do
            if key:match(':Text$') or key:match(':ToolTipText$') then truth(not value:find('[%c#%[%]]'), 'unsanitized display ' .. key) end
        end
        mock.missing.MeasureConnectionWiFiSSID = true
        equal(mock:tick(), 0)
        equal(mock.latest['MeterConnectionSignal:Text'], '--')
        equal(mock.latest['MeterConnectionSignalBar:Shape2'], 'Line 0,0,0,0 | StrokeWidth 0')
        mock.adapter.status = -2
        mock:tick()
        equal(mock.latest['MeterConnectionStatus:Text'], 'Lower layer down')
        contains(mock.latest['MeterConnectionStatus:ToolTipText'], 'Ethernet / Lower layer down')
    end)
    test('signal fill follows scaled shared thickness without fabricating unknown quality', function()
        local mock = controller()
        for _, thickness in ipairs({1, 2.5, 6, 12}) do
            for _, scale in ipairs({0.75, 1, 2}) do
                mock.dimensions.SignalWidth = 188 * scale
                mock.dimensions.SignalHeight = math.max(1, math.floor(thickness * scale + 0.5))
                for _, quality in ipairs({0, 50, 100}) do
                    mock.wifi.quality = quality
                    equal(mock:tick(), 1)
                    local width, height = mock.latest['MeterConnectionSignalBar:Shape2']:match('^Rectangle 0,0,([%d.]+),([%d.]+) |')
                    equal(tonumber(width), mock.dimensions.SignalWidth * quality / 100)
                    equal(tonumber(height), mock.dimensions.SignalHeight)
                end
                mock.missing.MeasureConnectionWiFiSSID = true
                equal(mock:tick(), 0)
                equal(mock.latest['MeterConnectionSignalBar:Shape2'], 'Line 0,0,0,0 | StrokeWidth 0')
                mock.missing.MeasureConnectionWiFiSSID = nil
            end
        end
        equal(mock:count('!WriteKeyValue'), 0)
    end)
    test('metadata controller has no companion width output or persistence action', function()
        local mock = controller({NetworkConnectionColumns = '2'})
        equal(rawget(mock.environment, 'ToggleWidth'), nil)
        mock:tick()
        equal(mock.latest['MeterConnectionWidth:Text'], nil)
        equal(mock:count('!WriteKeyValue'), 0); equal(mock:count('!Refresh'), 0)
        contains(mock.latest['MeterConnectionAdapter:ToolTipText'], 'Click for Network Settings.')
    end)
    report[#report + 1] = string.format('SUMMARY: %d passed, %d failed', passed, failed)
    return table.concat(report, '\n') .. '\n'
end

return Suite
