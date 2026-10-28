-- Native Rainmeter owns telemetry. This script formats values and bounded history.
-- No subprocesses, remote requests, or runtime state files.
local Core, model, options
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
    local width = SELF:GetNumberOption('GraphWidth', 248)
    local height = SELF:GetNumberOption('GraphHeight', 48)
    local scale = SELF:GetNumberOption('GraphScale', 1)
    -- Both traces share one axis that follows the largest sample in the window.
    local ceiling = Core.autoCeiling(model.history, units)
    for index, direction in ipairs({'In', 'Out'}) do
        local rate = index == 1 and input.inbound or input.outbound
        local path = Core.path(model.history, index, ceiling, width, height, scale)
        text(direction .. 'Rate', result.valid and Core.rate(rate, units) or '--')
        option(direction .. 'Graph', 'History', path)
        option(direction .. 'Graph', 'Shape2', #model.history > 1 and ceiling
            and ('Path History | Stroke Color ' .. setting(index == 1 and 'NetworkInColor' or 'NetworkOutColor', '220,220,220')
                .. ' | StrokeWidth ' .. tostring(scale) .. ' | Fill Color 0,0,0,0')
            or 'Line 1,1,1,1 | StrokeWidth 0')
    end
    return result.valid and 1 or 0
end

