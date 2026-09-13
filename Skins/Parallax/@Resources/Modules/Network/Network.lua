-- Native Rainmeter owns telemetry. This script formats values and bounded history.
-- No subprocesses, remote requests, or runtime state files.
local Core, model, options
local shortStates = {
    ['Adapter up / 1 s samples'] = 'Up / 1 s samples',
    ['Adapter up / sampling...'] = 'Up / sampling...',
    ['Adapter disconnected'] = 'Disconnected',
    ['Adapter not present'] = 'Not present',
    ['Adapter down'] = 'Down',
    ['Adapter status unknown'] = 'Status unknown',
    ['Adapter dormant'] = 'Dormant',
    ['Adapter testing'] = 'Testing',
    ['Configured adapter not found'] = 'Selected NIC not found',
    ['Select one adapter; index 0 unsupported'] = 'Select one adapter'
}

local function setting(key, default)
    return SKIN:GetVariable(key, default)
end

local function value(name, isString)
    local measure = SKIN:GetMeasure('MeasureNetwork' .. name)
    if not measure then return isString and '' or nil end
    if isString then return measure:GetStringValue() end
    return measure:GetValue()
end

local function option(meter, key, text)
    text = tostring(text)
    local id = meter .. ':' .. key
    if options[id] ~= text then
        SKIN:Bang('!SetOption', 'MeterNetwork' .. meter, key, text)
        options[id] = text
    end
end

local function text(meter, content)
    option(meter, 'Text', Core.safe(content))
end

function Initialize()
    Core = dofile(SELF:GetOption('CoreFile'))
    model, options = Core.new(), {}
end

function Update()
    local input = {
        selector = setting('NetworkInterface', 'Best'),
        alias = value('Alias', true), description = value('Description', true),
        guid = value('Guid', true), status = value('Status'), state = value('State'),
        inbound = value('In'), outbound = value('Out')
    }
    local result = Core.step(model, input, os.time())
    local units = setting('NetworkUnits', 'bits'):lower()
    text('Units', units == 'bytes' and 'bytes' or units == 'bits' and 'bits' or 'units?')
    text('Width', setting('Columns', '1') == '2' and '2x' or '1x')
    text('Status', shortStates[result.state] or result.state)
    option('Status', 'FontColor', setting(result.valid and 'GoodColor' or 'WarningColor', '143,155,173'))
    option('Status', 'ToolTipText', result.state .. '. Adapter status does not prove Internet access. Native counters do not expose a per-sample freshness flag; zero can mean idle or an unavailable counter.')
    local width = SELF:GetNumberOption('GraphWidth', 248)
    local height = SELF:GetNumberOption('GraphHeight', 42)
    local scale = SELF:GetNumberOption('GraphScale', 1)
    for index, direction in ipairs({'In', 'Out'}) do
        local rate = index == 1 and input.inbound or input.outbound
        local ceiling = Core.ceiling(setting('Network' .. direction .. 'CeilingMbps', ''))
        local path, clipped = Core.path(model.history, index, ceiling, width, height, scale)
        text(direction .. 'Rate', result.valid and Core.rate(rate, units) or '--')
        option(direction .. 'Graph', 'History', path)
        option(direction .. 'Graph', 'Shape2', #model.history > 1 and ceiling
            and ('Path History | Stroke Color ' .. setting(index == 1 and 'NetworkInColor' or 'NetworkOutColor', '220,220,220')
                .. ' | StrokeWidth ' .. tostring(scale) .. ' | Fill Color 0,0,0,0')
            or 'Line 1,1,1,1 | StrokeWidth 0')
        text(direction .. 'Ceiling', ceiling
            and ((clipped and 'Clipped: ' or 'Ceiling ') .. Core.rate(ceiling, units))
            or 'Set positive graph ceiling')
    end
    text('Footer', string.format('%d/60 samples / incl. LAN', #model.history))
    return result.valid and 1 or 0
end

function ToggleUnits()
    local units = setting('NetworkUnits', 'bits'):lower() == 'bits' and 'bytes' or 'bits'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'NetworkUnits', units, setting('@') .. 'User\\Network.inc')
    SKIN:Bang('!SetVariable', 'NetworkUnits', units)
    -- Do not force native measure updates: maintain their one-second baseline.
end

function ToggleWidth()
    local columns = setting('Columns', '1') == '2' and '1' or '2'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'Columns', columns, setting('@') .. 'User\\Network.inc')
    SKIN:Bang('!Refresh')
end
