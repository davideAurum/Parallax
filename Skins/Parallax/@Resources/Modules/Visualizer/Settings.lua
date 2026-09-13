-- Event-only settings controller. No audio capture or recurring helper work.
-- Every writable key and input bound is local; helper output is parsed as data.
local fields = {
    Width = { key='Columns', values={1,2}, categorical=true },
    Height = { key='PanelHeight', values={126,146,186}, minimum=126, maximum=186, discrete=true },
    Spacing = { key='VisualizerBandGap', values={0,1,3,4}, minimum=0, maximum=4 },
    Color = { key='VisualizerColorMode', values={0,1,2,3}, categorical=true },
    Quality = { key='VisualizerQuality', values={0,1,2}, categorical=true },
    Cadence = { key='VisualizerUpdateOverride', values={0,33,50,100}, categorical=true },
    Sensitivity = { key='VisualizerSensitivity', values={10,20,35,50,65,80}, minimum=10, maximum=80 },
    Attack = { key='VisualizerAttack', values={0,50,100,200,2000}, minimum=0, maximum=2000 },
    Decay = { key='VisualizerDecay', values={0,100,250,500,1000,5000}, minimum=0, maximum=5000 }
}
local pending
local input = 'MeasureVisualizerSettingsInput'

local function finite(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge
end

local function number(text)
    if type(text) ~= 'string' or #text > 32 or not text:match('^[+-]?%d+$') then return nil end
    local value = tonumber(text)
    if finite(value) then return value end
end

local function current(field)
    return number(SKIN:GetVariable(field.key, ''))
end

local function member(values, value)
    for index, item in ipairs(values) do if item == value then return index end end
end

local function accepted(field, value)
    if not finite(value) or value ~= math.floor(value) then return false end
    if field.categorical or field.discrete then return member(field.values, value) ~= nil end
    return value >= field.minimum and value <= field.maximum
end

local function save(field, value)
    if not accepted(field, value) or current(field) == value then return false end
    local canonical = string.format('%.0f', value)
    SKIN:Bang('!WriteKeyValue', 'Variables', field.key, canonical, SKIN:GetVariable('@') .. 'User\\Visualizer.inc')
    SKIN:Bang('!Refresh', 'Parallax\\Visualizer')
    SKIN:Bang('!Refresh')
    return true
end

function Initialize()
    pending = nil
end

function Update() return 0 end

function Step(name, direction)
    local field = fields[name]
    if not field or pending or (direction ~= -1 and direction ~= 1) then return false end
    local value = current(field)
    if field.categorical then
        local index = member(field.values, value)
        if not index then return save(field, field.values[1]) end
        return save(field, field.values[(index - 1 + direction) % #field.values + 1])
    end
    if not value then return save(field, field.values[1]) end
    if direction == 1 then
        for _, choice in ipairs(field.values) do if choice > value then return save(field, choice) end end
    else
        for index = #field.values, 1, -1 do
            if field.values[index] < value then return save(field, field.values[index]) end
        end
    end
    -- Numeric presets clamp; clicking beyond either end writes nothing.
    return false
end

function Activate(name)
    local field = fields[name]
    if not field or pending then return false end
    if field.categorical then return Step(name, 1) end
    local meter = SKIN:GetMeter('MeterVisualizerSettings' .. name .. 'Row')
    if not meter then return false end
    local value = current(field)
    if not accepted(field, value) then value = field.values[1] end
    local scale = tonumber(SKIN:GetVariable('Scale'))
    if not finite(scale) then scale = 1 end
    scale = math.max(0.75, math.min(2, scale))
    pending = name
    -- Fixed script/key/range and canonical numeric coordinates only. Typed text
    -- never enters Parameter or any Rainmeter action string.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sScripts\\SettingsInput.ps1" -Key UtilityNumber -Minimum %d -Maximum %d -DecimalPlaces 0 -Initial "%.0f" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        SKIN:GetVariable('@'), field.minimum, field.maximum, value,
        math.floor(SKIN:GetX() + meter:GetX()), math.floor(SKIN:GetY() + meter:GetY()),
        math.max(28, math.floor(meter:GetW())), math.max(20, math.floor(meter:GetH())), scale)
    SKIN:Bang('!SetOption', input, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', input)
    SKIN:Bang('!CommandMeasure', input, 'Run')
    return true
end

function CommitInput()
    if not pending then return false end
    local field = fields[pending]
    pending = nil
    local measure = SKIN:GetMeasure(input)
    local output = measure and measure:GetStringValue() or ''
    if type(output) ~= 'string' or #output > 96 then return false end
    output = output:gsub('[\r\n]+$', '')
    if output == 'PARALLAX_INPUT_V1|cancel|' then return false end
    local value = number(output:match('^PARALLAX_INPUT_V1|ok|([+-]?%d+)$'))
    if not accepted(field, value) then return false end
    return save(field, value)
end
