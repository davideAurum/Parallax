-- CPU-only editor for bounded logical-thread colors. It is event driven: a
-- color input process starts only after a user click and never on a poll.
local state

local palette = {
    '235,55,75', '255,145,77', '240,225,40', '166,219,91',
    '79,205,120', '60,200,194', '77,170,255', '122,139,255',
    '182,130,255', '238,111,196', '245,139,168', '190,190,190'
}

local function set(meter, key, value)
    SKIN:Bang('!SetOption', meter, key, tostring(value))
end

local function defaultColor(index)
    return palette[(index - 1) % #palette + 1]
end

local function normalize(value, fallback)
    local text = tostring(value or ''):match('^%s*(.-)%s*$')
    local hex = text:gsub('^#', '')
    if (#hex == 6 or #hex == 8) and hex:match('^%x+$') then
        return table.concat({
            tostring(tonumber(hex:sub(1, 2), 16)),
            tostring(tonumber(hex:sub(3, 4), 16)),
            tostring(tonumber(hex:sub(5, 6), 16))
        }, ',')
    end
    local red, green, blue = text:match('^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
    red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
    if red and green and blue and red <= 255 and green <= 255 and blue <= 255 then
        return string.format('%d,%d,%d', red, green, blue)
    end
    return fallback
end

local function hex(value)
    local red, green, blue = value:match('^(%d+),(%d+),(%d+)$')
    return string.format('#%02X%02X%02X', tonumber(red), tonumber(green), tonumber(blue))
end

local function boundedInteger(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value ~= math.floor(value) then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function detectedThreadCount()
    local detected = boundedInteger(os.getenv('NUMBER_OF_PROCESSORS'), 1, 1, 64)
    local limit = boundedInteger(SKIN:GetVariable('CPUCoreLimit'), 0, 0, 64)
    return limit > 0 and math.min(detected, limit) or detected
end

local function formula(value)
    return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(value) .. ')')
end

local function setRowGeometry(index, column, row, contentX, contentWidth, inset, scale)
    local width = (contentWidth - 4 * scale) / 2
    local base = contentX + column * (width + 4 * scale)
    local top = inset + 80 * scale + row * 28 * scale
    set('MeterThreadColorLabel' .. index, 'X', base)
    set('MeterThreadColorLabel' .. index, 'Y', top + 2 * scale)
    set('MeterThreadColorLabel' .. index, 'W', 60 * scale)
    set('MeterThreadColorValue' .. index, 'X', base + 64 * scale)
    set('MeterThreadColorValue' .. index, 'Y', top)
    set('MeterThreadColorValue' .. index, 'W', width - 96 * scale)
    set('MeterThreadColorSwatch' .. index, 'X', base + width - 22 * scale)
    set('MeterThreadColorSwatch' .. index, 'Y', top + scale)
end

local function layout()
    local rows = math.ceil(state.count / 2)
    local height = 84 + rows * 28 + 20
    SKIN:Bang('!SetVariable', 'PanelHeight', tostring(height))
    set('MeterBounds', 'H', '(Round(' .. height .. '*#Scale#)+#Gap#)')
    set('MeterPanel', 'Shape', 'Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(Round(' .. height .. '*#Scale#)-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)')
    local scale = tonumber(SKIN:GetVariable('Scale')) or 1
    local contentX, contentWidth, inset = formula('#ContentX#'), formula('#ContentWidth#'), formula('#Inset#')
    for index = 1, 64 do
        if index <= state.count then
            setRowGeometry(index, (index - 1) % 2, math.floor((index - 1) / 2), contentX, contentWidth, inset, scale)
            SKIN:Bang('!ShowMeterGroup', 'CPUThreadColor' .. index)
        else
            SKIN:Bang('!HideMeterGroup', 'CPUThreadColor' .. index)
        end
    end
end

local function render()
    for index = 1, state.count do
        local color = state.colors[index]
        local text = hex(color)
        local tip = 'Thread ' .. index .. ': ' .. text .. '. Click the hex code or swatch to enter an RGB hex color. This same color draws its utilization bar and graph trace.'
        set('MeterThreadColorLabel' .. index, 'Text', 'Thread ' .. index)
        set('MeterThreadColorLabel' .. index, 'ToolTipText', tip)
        set('MeterThreadColorValue' .. index, 'Text', text)
        set('MeterThreadColorValue' .. index, 'ToolTipText', tip)
        set('MeterThreadColorSwatch' .. index, 'Shape', 'Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color ' .. color .. ' | Stroke Color #BorderColor# | StrokeWidth #Scale#')
        set('MeterThreadColorSwatch' .. index, 'ToolTipText', tip)
    end
    SKIN:Bang('!UpdateMeterGroup', 'CPUThreadColorsUI')
    SKIN:Bang('!Redraw')
end

function Initialize()
    state = {
        userFile = SKIN:GetVariable('@') .. 'User\\CPU.inc',
        count = detectedThreadCount(),
        colors = {},
        editingIndex = nil
    }
    for index = 1, state.count do
        local fallback = defaultColor(index)
        state.colors[index] = normalize(SKIN:GetVariable('CPUThreadColor' .. index, fallback), fallback)
    end
end

function Update()
    if not state then return 0 end
    layout()
    render()
    return 0
end

function BeginEdit(index)
    index = boundedInteger(index, 0, 1, state and state.count or 0)
    if not state or index == 0 or state.editingIndex then return false end
    local meter = SKIN:GetMeter('MeterThreadColorValue' .. index)
    if not meter then return false end
    state.editingIndex = index
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "ThreadColorInput.ps1" -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        hex(state.colors[index]), math.floor(SKIN:GetX() + meter:GetX()), math.floor(SKIN:GetY() + meter:GetY()),
        math.max(72, math.floor(meter:GetW())), math.max(20, math.floor(meter:GetH())), tonumber(SKIN:GetVariable('Scale')) or 1)
    set('MeasureCPUThreadColorInput', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureCPUThreadColorInput')
    SKIN:Bang('!CommandMeasure', 'MeasureCPUThreadColorInput', 'Run')
    return true
end

function CommitInput()
    if not state or not state.editingIndex then return false end
    local index = state.editingIndex
    state.editingIndex = nil
    local measure = SKIN:GetMeasure('MeasureCPUThreadColorInput')
    local output = measure and measure:GetStringValue() or ''
    output = output:gsub('[\r\n]+$', '')
    local value = output:match('^PARALLAX_CPU_COLOR_V1|ok|([0-9]+,[0-9]+,[0-9]+)$')
    value = normalize(value, nil)
    if not value then return false end
    state.colors[index] = value
    local key = 'CPUThreadColor' .. index
    SKIN:Bang('!SetVariable', key, value)
    SKIN:Bang('!WriteKeyValue', 'Variables', key, value, state.userFile)
    SKIN:Bang('!SetVariableGroup', key, value, 'ParallaxCPU')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxCPUApply', '*')
    render()
    return true
end
