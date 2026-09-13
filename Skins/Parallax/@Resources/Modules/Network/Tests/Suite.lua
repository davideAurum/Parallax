-- Original Parallax tests. Fixtures are synthetic inputs, never displayed as telemetry.
local Suite = {}

function Suite.run(Core, fixtures)
    local passed, failed, report = 0, 0, {}
    local function equal(actual, expected, detail)
        if actual ~= expected then error((detail or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
    end
    local function truth(value, detail)
        if not value then error(detail or 'expected true', 2) end
    end
    local function contains(actual, expected)
        truth(tostring(actual):find(expected, 1, true), 'expected ' .. tostring(actual) .. ' to contain ' .. expected)
    end
    local function test(name, body)
        local ok, err = pcall(body)
        if ok then
            passed = passed + 1
            report[#report + 1] = 'PASS: ' .. name
        else
            failed = failed + 1
            report[#report + 1] = 'FAIL: ' .. name .. ': ' .. tostring(err)
        end
    end
    local guid = '{01234567-89AB-CDEF-0123-456789ABCDEF}'
    local secondGuid = '{FEDCBA98-7654-3210-FEDC-BA9876543210}'
    local function input(overrides)
        local value = { selector = 'Best', alias = 'Ethernet', description = 'Test adapter', guid = guid,
            status = 1, state = 1, inbound = 8000000, outbound = 8000 }
        for key, replacement in pairs(overrides or {}) do value[key] = replacement end
        return value
    end
    local function ready(overrides)
        local model, sample = Core.new(), input(overrides)
        Core.step(model, sample, 100)
        Core.step(model, sample, 101)
        local result = Core.step(model, sample, 102)
        truth(result.valid, 'fixture failed to reach valid sampling')
        return model, sample
    end
    local function read(path)
        local file = assert(io.open(path, 'rb'))
        local data = assert(file:read('*a'))
        assert(file:close())
        return data
    end

    test('Best and exact named selectors resolve verified GUIDs', function()
        truth(Core.identity(input()))
        truth(Core.identity(input({selector = 'ethernet'})))
        truth(Core.identity(input({selector = 'TEST ADAPTER'})))
        truth(Core.identity(input({selector = '23'})))
    end)
    test('invalid named selector rejects a provider Best fallback', function()
        local id, message = Core.identity(input({selector = 'Missing adapter'}))
        equal(id, nil)
        contains(message, 'not found')
    end)
    test('zero, empty, negative, fractional, and overflowing indexes fail', function()
        for _, selector in ipairs({'', ' ', '0', '00', '-1', '1.5', '2147483648', '4294967296'}) do
            equal(Core.identity(input({selector = selector})), nil, selector)
        end
    end)
    test('numeric-like non-digit selectors cannot bypass exact identity match', function()
        for _, selector in ipairs({'1e1', '+1', '1.0', '0x10'}) do
            equal(Core.identity(input({selector = selector})), nil, selector)
        end
    end)
    test('missing and null GUIDs reject native aggregate or numeric fallback', function()
        for _, missing in ipairs({'', '0', '0.0', 'Unknown', '{00000000-0000-0000-0000-000000000000}'}) do
            equal(Core.identity(input({guid = missing})), nil, missing)
        end
        equal(Core.identity(input({selector = '99999', guid = '0'})), nil)
    end)
    test('malformed GUIDs cannot establish identity', function()
        for _, malformed in ipairs({'{01234567-89AB-CDEF-0123-456789ABCDEZ}',
            '{01234567-89AB-CDEF-0123-456789ABCDEF',
            '{{01234567-89AB-CDEF-0123-456789ABCDEF}}',
            '0123{4567-89AB-CDEF-0123-456789ABCDEF}'}) do
            equal(Core.identity(input({guid = malformed})), nil, malformed)
        end
    end)
    test('startup discards two samples before showing valid idle zero', function()
        local model, sample = Core.new(), input({inbound = 0, outbound = 0})
        equal(Core.step(model, sample, 1).valid, false)
        equal(#model.history, 0)
        equal(Core.step(model, sample, 2).valid, false)
        equal(Core.step(model, sample, 3).valid, true)
        equal(#model.history, 1)
        equal(model.history[1][1], 0)
    end)
    test('operational status mapping retains explicit unavailable states', function()
        local expected = { [-3] = 'Adapter not present', [-2] = 'Lower layer down', [-1] = 'Adapter down',
            [0] = 'Adapter status unknown', [2] = 'Adapter dormant', [3] = 'Adapter testing', [9] = 'Adapter unavailable' }
        for status, label in pairs(expected) do
            local model = ready()
            local result = Core.step(model, input({status = status}), 103)
            equal(result.valid, false)
            equal(result.state, label)
            equal(#model.history, 0)
        end
    end)
    test('media disconnect overrides operational Up and clears history', function()
        local model = ready()
        local result = Core.step(model, input({state = -1}), 103)
        equal(result.state, 'Adapter disconnected')
        equal(result.valid, false)
        equal(#model.history, 0)
    end)
    test('GUID switch clears old adapter data and warms up', function()
        local model = ready()
        local nextInput = input({guid = secondGuid, inbound = 9e12})
        equal(Core.step(model, nextInput, 103).valid, false)
        equal(#model.history, 0)
        equal(Core.step(model, nextInput, 104).valid, false)
        nextInput.inbound = 42
        truth(Core.step(model, nextInput, 105).valid)
        equal(#model.history, 1)
        equal(model.history[1][1], 42)
    end)
    test('same-GUID reconnect discards counter transition samples', function()
        local model, sample = ready()
        Core.step(model, input({state = -1}), 103)
        equal(Core.step(model, sample, 104).valid, false)
        equal(Core.step(model, sample, 105).valid, false)
        truth(Core.step(model, sample, 106).valid)
        equal(#model.history, 1)
    end)
    test('adapter disappearance and later return clears and warms up', function()
        local model, sample = ready()
        local unavailable = Core.step(model, input({guid = '0'}), 103)
        equal(unavailable.state, 'Adapter unavailable')
        equal(#model.history, 0)
        equal(Core.step(model, sample, 104).valid, false)
        equal(Core.step(model, sample, 105).valid, false)
        truth(Core.step(model, sample, 106).valid)
    end)
    test('resume and nonadvancing clocks reset history and sampling', function()
        for _, now in ipairs({110, 102, 101}) do
            local model, sample = ready()
            equal(Core.step(model, sample, now).valid, false)
            equal(#model.history, 0)
            equal(Core.step(model, sample, now + 1).valid, false)
            truth(Core.step(model, sample, now + 2).valid)
        end
    end)
    test('invalid numeric samples stay unavailable instead of measured zero', function()
        for _, invalid in ipairs({-1, math.huge, -math.huge, 0/0}) do
            local model = ready()
            local result = Core.step(model, input({inbound = invalid}), 103)
            equal(result.state, 'Sample unavailable')
            equal(result.valid, false)
            equal(#model.history, 0)
        end
        local model = ready()
        local sample = input(); sample.outbound = nil
        equal(Core.step(model, sample, 103).valid, false)
    end)
    test('history is capped at sixty real directional samples', function()
        local model, sample = ready()
        for i = 1, 100 do
            sample.inbound, sample.outbound = i, i * 2
            truth(Core.step(model, sample, 102 + i).valid)
        end
        equal(#model.history, 60)
        equal(model.history[1][1], 41)
        equal(model.history[60][2], 200)
    end)
    test('decimal bits and binary bytes have exact independent conversions', function()
        equal(Core.rate(8000000, 'bits'), '8.0 Mbit/s')
        equal(Core.rate(8388608, 'bytes'), '1.0 MiB/s')
        equal(Core.rate(8192, 'bytes'), '1.0 KiB/s')
        equal(Core.rate(8, 'bytes'), '1.0 B/s')
        equal(Core.rate(0, 'bits'), '0.0 bit/s')
        equal(Core.rate(-1, 'bits'), '--')
        equal(Core.rate(math.huge, 'bits'), '--')
        equal(Core.rate(1000, 'invalid'), 'Check units')
    end)
    test('graph ceiling validates finite positive decimal megabits', function()
        equal(Core.ceiling('100'), 100000000)
        equal(Core.ceiling('0.5'), 500000)
        for _, invalid in ipairs({'', 'abc', '0', '-1', '1e309'}) do equal(Core.ceiling(invalid), nil) end
    end)
    test('empty and singleton graphs do not invent a predecessor', function()
        local empty, clipped = Core.path({}, 1, 100, 188, 42, 1)
        equal(empty, '1,1 | LineTo 1,1'); equal(clipped, false)
        local single = Core.path({{0, 100}}, 1, 100, 188, 42, 1)
        equal(single, '186.000,40.000 | LineTo 186.000,40.000')
        equal(Core.path({{5, 5}}, 1, nil, 188, 42, 1), '1,1 | LineTo 1,1')
    end)
    test('graph clips only its path and preserves original directional data', function()
        local history = {{0, 200}, {50, 0}, {200, 100}}
        local inbound, clipped = Core.path(history, 1, 100, 188, 42, 1)
        truth(clipped)
        contains(inbound, '186.000,2.000')
        equal(history[3][1], 200)
        local outbound, outClipped = Core.path(history, 2, 1000, 188, 42, 1)
        equal(outClipped, false)
        truth(inbound ~= outbound)
    end)
    test('full history path remains inside graph at every suite scale', function()
        for _, scale in ipairs({0.75, 1, 1.25, 1.5, 2}) do
            for _, columnWidth in ipairs({180, 200, 240, 280, 320}) do
                for _, columns in ipairs({1, 2}) do
                    local gap = 2 * math.floor(8 * scale / 2 + 0.5)
                    local width = columns * (math.floor(columnWidth * scale + 0.5) + gap) - gap - 2 * math.floor(6 * scale + 0.5)
                    local history = {}
                    for i = 1, 60 do history[i] = {i * 4, 60 - i} end
                    local path = Core.path(history, 1, 100, width, 42 * scale, scale)
                    local count = 0
                    for xs, ys in path:gmatch('([%d%.]+),([%d%.]+)') do
                        local x, y = tonumber(xs), tonumber(ys)
                        truth(x >= 2 * scale - 0.001 and x <= width - 2 * scale + 0.001)
                        truth(y >= 2 * scale - 0.001 and y <= 40 * scale + 0.001)
                        count = count + 1
                    end
                    equal(count, 60)
                end
            end
        end
    end)
    test('adapter text neutralizes Rainmeter action and variable delimiters', function()
        local safe = Core.safe('NIC [!Quit] #CURRENTCONFIG#\nnext')
        truth(not safe:find('[%c#%[%]]'))
        contains(safe, 'NIC')
    end)

    local meterNames, measureNames = {}, {}
    for name in ('\n' .. read(fixtures.moduleRoot .. '\\Meters.inc')):gmatch('\n%s*%[([^%]\r\n]+)%]') do meterNames[name] = true end
    for name in ('\n' .. read(fixtures.moduleRoot .. '\\Measures.inc')):gmatch('\n%s*%[([^%]\r\n]+)%]') do measureNames[name] = true end
    local function controller()
        local mock = {now = 200, calls = {}, latest = {}, sample = input(), missing = {},
            variables = { NetworkInterface = 'Best', NetworkUnits = 'bits', Columns = '1',
                NetworkInCeilingMbps = '100', NetworkOutCeilingMbps = '25',
                NetworkInColor = '240,225,40', NetworkOutColor = '100,230,90',
                ['@'] = 'C:\\ParallaxTest\\@Resources\\' }}
        local names = {Alias = 'alias', Description = 'description', Guid = 'guid', Status = 'status',
            State = 'state', In = 'inbound', Out = 'outbound'}
        local skin = {}
        function skin:GetVariable(key, default) return mock.variables[key] or default end
        function skin:GetMeasure(name)
            truth(measureNames[name], 'unknown controller measure: ' .. name)
            if mock.missing[name] then return nil end
            local key = assert(names[name:match('^MeasureNetwork(.+)$')], name)
            return {GetValue = function() return mock.sample[key] end,
                GetStringValue = function() return mock.sample[key] end}
        end
        function skin:Bang(bang, ...)
            local args = {...}; mock.calls[#mock.calls + 1] = {bang = bang, args = args}
            if bang == '!SetOption' then
                truth(meterNames[args[1]], 'unknown controller meter: ' .. tostring(args[1]))
                mock.latest[args[1] .. ':' .. args[2]] = args[3]
            elseif bang == '!SetVariable' then
                mock.variables[args[1]] = args[2]
            elseif bang ~= '!WriteKeyValue' and bang ~= '!Refresh' then
                error('unexpected controller side effect: ' .. bang)
            end
        end
        local self = {}
        function self:GetOption(key)
            equal(key, 'CoreFile')
            return fixtures.moduleRoot .. '\\Core.lua'
        end
        function self:GetNumberOption(key, default)
            return ({GraphWidth = 188, GraphHeight = 42, GraphScale = 1})[key] or default
        end
        local env = setmetatable({SKIN = skin, SELF = self, os = {time = function() return mock.now end}}, {__index = _G})
        local chunk = assert(loadfile(fixtures.moduleRoot .. '\\Network.lua'))
        setfenv(chunk, env); chunk(); env.Initialize()
        function mock:tick()
            local value = env.Update(); self.now = self.now + 1; return value
        end
        function mock:count(bang)
            local n = 0; for _, call in ipairs(self.calls) do if call.bang == bang then n = n + 1 end end; return n
        end
        mock.environment = env
        return mock
    end
    test('controller targets real sections and does not write during polling', function()
        local mock = controller()
        equal(mock:tick(), 0); equal(mock:tick(), 0); equal(mock:tick(), 1)
        equal(mock.latest['MeterNetworkInRate:Text'], '8.0 Mbit/s')
        for i = 1, 65 do mock:tick() end
        contains(mock.latest['MeterNetworkInGraph:Shape2'], 'Stroke Color 240,225,40')
        contains(mock.latest['MeterNetworkOutGraph:Shape2'], 'Stroke Color 100,230,90')
        equal(mock:count('!WriteKeyValue'), 0)
        equal(mock:count('!SetVariable'), 0)
        equal(mock:count('!Refresh'), 0)
        contains(mock.latest['MeterNetworkFooter:Text'], '60/60 samples')
    end)
    test('traffic controller leaves adapter display to metadata and reports invalid fallback', function()
        local mock = controller()
        mock.sample.alias = 'NIC [!Quit] #CURRENTCONFIG#'
        mock:tick()
        equal(mock.latest['MeterNetworkAdapter:Text'], nil)
        equal(mock.latest['MeterNetworkAdapter:ToolTipText'], nil)
        mock.variables.NetworkInterface = 'Not found'
        mock:tick()
        equal(mock.latest['MeterNetworkStatus:Text'], 'Selected NIC not found')
        equal(mock.latest['MeterNetworkInRate:Text'], '--')
    end)
    test('controller tolerates absent native measures without showing zero', function()
        local mock = controller(); mock.missing.MeasureNetworkGuid = true
        mock:tick()
        equal(mock.latest['MeterNetworkStatus:Text'], 'Adapter unavailable')
        equal(mock.latest['MeterNetworkOutRate:Text'], '--')
    end)
    test('controller graph ceiling and units errors remain explicit', function()
        local mock = controller()
        mock.variables.NetworkInCeilingMbps = '0'
        mock.variables.NetworkUnits = 'invalid'
        mock:tick(); mock:tick(); mock:tick()
        equal(mock.latest['MeterNetworkInCeiling:Text'], 'Set positive graph ceiling')
        equal(mock.latest['MeterNetworkInRate:Text'], 'Check units')
        equal(mock.latest['MeterNetworkInGraph:Shape2'], 'Line 1,1,1,1 | StrokeWidth 0')
    end)
    test('units action writes only the module choice and does not force sampling', function()
        local mock = controller(); mock:tick(); mock.calls = {}
        mock.environment.ToggleUnits()
        equal(#mock.calls, 2)
        equal(mock.calls[1].bang, '!WriteKeyValue')
        equal(mock.calls[1].args[1], 'Variables')
        equal(mock.calls[1].args[2], 'NetworkUnits')
        equal(mock.calls[1].args[3], 'bytes')
        equal(mock.calls[1].args[4], 'C:\\ParallaxTest\\@Resources\\User\\Network.inc')
        equal(mock.calls[2].bang, '!SetVariable')
        mock:tick(); mock:tick()
        equal(mock.latest['MeterNetworkInRate:Text'], '976.6 KiB/s')
        equal(mock:count('!WriteKeyValue'), 1)
        equal(mock:count('!Refresh'), 0)
        mock.environment.ToggleUnits()
        equal(mock.variables.NetworkUnits, 'bits')
    end)
    test('width action writes only Network Columns and refreshes current skin', function()
        local mock = controller(); mock.calls = {}
        mock.environment.ToggleWidth()
        equal(#mock.calls, 2)
        equal(mock.calls[1].bang, '!WriteKeyValue')
        equal(mock.calls[1].args[1], 'Variables')
        equal(mock.calls[1].args[2], 'Columns')
        equal(mock.calls[1].args[3], '2')
        equal(mock.calls[1].args[4], 'C:\\ParallaxTest\\@Resources\\User\\Network.inc')
        equal(mock.calls[2].bang, '!Refresh')
        equal(#mock.calls[2].args, 0)
        mock.variables.Columns = '2'; mock.calls = {}
        mock.environment.ToggleWidth()
        equal(mock.calls[1].args[3], '1')
    end)

    report[#report + 1] = string.format('SUMMARY: %d passed, %d failed', passed, failed)
    return table.concat(report, '\n') .. '\n'
end

return Suite
