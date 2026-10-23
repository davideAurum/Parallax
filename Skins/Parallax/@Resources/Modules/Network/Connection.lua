-- Connection presentation only: native measures own every reported value.
local Core, Connection, config, cache
local ticks, bankDivider, wifiDivider, identity, lastResult
local wifiNames = {'SSID', 'Quality', 'PHY', 'Rx', 'Tx'}

local function variable(key, default) return SKIN:GetVariable(key, default) end

local function read(name, stringValue)
    local measure = SKIN:GetMeasure(name)
    if not measure then return stringValue and '' or nil end
    return stringValue and measure:GetStringValue() or measure:GetValue()
end

local function value(suffix, stringValue) return read('MeasureConnection' .. suffix, stringValue) end

local function option(suffix, key, content)
    content = tostring(content)
    local id = suffix .. ':' .. key
    if cache[id] ~= content then
        SKIN:Bang('!SetOption', 'MeterConnection' .. suffix, key, content)
        cache[id] = content
    end
end

local function text(suffix, content) option(suffix, 'Text', Core.safe(content)) end
local function color(suffix, key) option(suffix, 'FontColor', variable(key, '175,175,175')) end

-- A whole number of skin ticks between updates of a native measure bank.
local function divider(key)
    local n = SELF:GetNumberOption(key, 1)
    if n ~= n or n < 1 or n > 3600 then return 1 end
    return math.floor(n)
end

function Initialize()
    Core = dofile(SELF:GetOption('CoreFile'))
    Connection = dofile(SELF:GetOption('ConnectionCoreFile'))
    config = Connection.configureWifi(variable('NetworkWiFiEnabled', '1'), variable('NetworkWiFiInterface', '0'))
    cache = {}
    -- The SysInfo connection bank and the enabled Wi-Fi measures update on
    -- the first tick, then every BankDivider / WiFiDivider ticks; this
    -- controller runs every tick from the first.
    ticks, bankDivider, wifiDivider = -1, divider('BankDivider'), divider('WiFiDivider')
    identity, lastResult = nil, nil
    for _, suffix in ipairs(wifiNames) do
        local measure = 'MeasureConnectionWiFi' .. suffix
        SKIN:Bang('!SetOption', measure, 'WiFiIntfID', tostring(config.index))
        SKIN:Bang('!SetOption', measure, 'Disabled', config.enabled and '0' or '1')
        SKIN:Bang(config.enabled and '!EnableMeasure' or '!DisableMeasure', measure)
    end
end

function Update()
    ticks = ticks + 1
    local bankTick = ticks % bankDivider == 0
    -- Every value this section shows comes from the connection bank or the
    -- Wi-Fi measures. On a tick where neither updated, the view cannot have
    -- changed: keep it, and the measure value, instead of re-deriving both.
    if lastResult ~= nil and not bankTick and not (config.enabled and ticks % wifiDivider == 0) then
        return lastResult
    end
    if not identity or bankTick then
        -- Adapter identity comes from Network's per-second traffic bank, which
        -- uses the same selector. Sample it only on this bank's ticks so the
        -- identity, addresses and link rates shown together are one snapshot,
        -- as when the bank kept its own copies of these five measures.
        identity = {
            alias = read('MeasureNetworkAlias', true), description = read('MeasureNetworkDescription', true),
            guid = read('MeasureNetworkGuid', true), status = read('MeasureNetworkStatus'),
            state = read('MeasureNetworkState')
        }
    end
    local adapter = {
        selector = variable('NetworkInterface', 'Best'), alias = identity.alias,
        description = identity.description, guid = identity.guid,
        status = identity.status, state = identity.state, type = value('Type'),
        internet = value('Internet'), ip = value('IP', true), gateway = value('Gateway', true),
        receiveSpeed = value('RxLink'), transmitSpeed = value('TxLink')
    }
    local wifi = {ssid = value('WiFiSSID', true), quality = value('WiFiQuality'),
        phy = value('WiFiPHY', true), receiveRate = value('WiFiRx'), transmitRate = value('WiFiTx')}
    local view = Connection.describe(Core, adapter, wifi, config)
    text('Adapter', view.adapter)
    text('Description', view.description)
    -- Keep the longest operational state readable; its link type is dropped to fit.
    text('Status', view.status:gsub('^.+ / Lower layer down$', 'Lower layer down'))
    color('Status', view.statusColor)
    text('Internet', view.internet)
    color('Internet', view.internetColor)
    text('IP', view.ip)
    text('Gateway', view.gateway)
    text('Rx', view.receiveLink)
    text('Tx', view.transmitLink)
    text('WiFi', view.wifiName)
    text('Signal', view.signal)
    color('Signal', view.signalColor)
    text('Radio', view.radio)
    local width, height = SELF:GetNumberOption('SignalWidth', 188), SELF:GetNumberOption('SignalHeight', 3)
    option('SignalBar', 'Shape2', view.signalPercent ~= nil
        and ('Rectangle 0,0,' .. string.format('%.3f', width * view.signalPercent / 100) .. ',' .. tostring(height)
            .. ' | Fill Color ' .. variable(view.signalColor, '137,190,250') .. ' | StrokeWidth 0')
        or 'Line 0,0,0,0 | StrokeWidth 0')
    lastResult = view.signalPercent ~= nil and 1 or 0
    return lastResult
end
