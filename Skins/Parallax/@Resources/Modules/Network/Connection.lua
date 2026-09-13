-- Connection presentation only: native measures own every reported value.
local Core, Connection, config, cache
local wifiNames = {'SSID', 'Quality', 'PHY', 'Rx', 'Tx'}

local function variable(key, default) return SKIN:GetVariable(key, default) end

local function value(suffix, stringValue)
    local measure = SKIN:GetMeasure('MeasureConnection' .. suffix)
    if not measure then return stringValue and '' or nil end
    return stringValue and measure:GetStringValue() or measure:GetValue()
end

local function option(suffix, key, content)
    content = tostring(content)
    local id = suffix .. ':' .. key
    if cache[id] ~= content then
        SKIN:Bang('!SetOption', 'MeterConnection' .. suffix, key, content)
        cache[id] = content
    end
end

local function text(suffix, content) option(suffix, 'Text', Core.safe(content)) end
local function tooltip(suffix, content) option(suffix, 'ToolTipText', Core.safe(content)) end
local function color(suffix, key) option(suffix, 'FontColor', variable(key, '175,175,175')) end

function Initialize()
    Core = dofile(SELF:GetOption('CoreFile'))
    Connection = dofile(SELF:GetOption('ConnectionCoreFile'))
    config = Connection.configureWifi(variable('NetworkWiFiEnabled', '1'), variable('NetworkWiFiInterface', '0'))
    cache = {}
    for _, suffix in ipairs(wifiNames) do
        local measure = 'MeasureConnectionWiFi' .. suffix
        SKIN:Bang('!SetOption', measure, 'WiFiIntfID', tostring(config.index))
        SKIN:Bang('!SetOption', measure, 'Disabled', config.enabled and '0' or '1')
        SKIN:Bang(config.enabled and '!EnableMeasure' or '!DisableMeasure', measure)
    end
end

function Update()
    local adapter = {
        selector = variable('NetworkInterface', 'Best'), alias = value('Alias', true),
        description = value('Description', true), guid = value('Guid', true),
        status = value('Status'), state = value('State'), type = value('Type'),
        internet = value('Internet'), ip = value('IP', true), gateway = value('Gateway', true),
        receiveSpeed = value('RxLink'), transmitSpeed = value('TxLink')
    }
    local wifi = {ssid = value('WiFiSSID', true), quality = value('WiFiQuality'),
        phy = value('WiFiPHY', true), receiveRate = value('WiFiRx'), transmitRate = value('WiFiTx')}
    local view = Connection.describe(Core, adapter, wifi, config)
    text('Adapter', view.adapter)
    text('Description', view.description)
    -- Keep the longest operational state readable; the tooltip retains link type.
    text('Status', view.status:gsub('^.+ / Lower layer down$', 'Lower layer down'))
    color('Status', view.statusColor)
    tooltip('Adapter', 'Selected traffic adapter: ' .. adapter.selector .. '. ' .. view.adapter .. ' / ' .. view.description .. '. Click for Network Settings.')
    tooltip('Description', view.description)
    tooltip('Status', view.status .. '. This is adapter operational status, not Internet reachability.')
    text('Internet', view.internet)
    color('Internet', view.internetColor)
    text('IP', view.ip)
    text('Gateway', view.gateway)
    tooltip('IP', 'Selected adapter local address: ' .. view.ip)
    tooltip('Gateway', 'Selected adapter gateway: ' .. view.gateway)
    text('Rx', view.receiveLink)
    text('Tx', view.transmitLink)
    text('WiFi', view.wifiName)
    text('Signal', view.signal)
    color('Signal', view.signalColor)
    tooltip('WiFi', view.wifiTooltip)
    tooltip('Signal', view.signalTooltip)
    tooltip('SignalBar', view.signalTooltip)
    text('Radio', view.radio)
    tooltip('Radio', view.wifiTooltip)
    local width, height = SELF:GetNumberOption('SignalWidth', 188), SELF:GetNumberOption('SignalHeight', 3)
    option('SignalBar', 'Shape2', view.signalPercent ~= nil
        and ('Rectangle 0,0,' .. string.format('%.3f', width * view.signalPercent / 100) .. ',' .. tostring(height)
            .. ' | Fill Color ' .. variable(view.signalColor, '137,190,250') .. ' | StrokeWidth 0')
        or 'Line 0,0,0,0 | StrokeWidth 0')
    return view.signalPercent ~= nil and 1 or 0
end
