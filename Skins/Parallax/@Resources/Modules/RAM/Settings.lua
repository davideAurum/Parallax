-- Independent RAM settings utility. No telemetry or periodic work. The shared
-- numeric editor is an owned, bounded one-shot process launched only by Edit.
local values, userFile, inputKey, inputLaunched, closed, completing, hint
local inputMeasure = 'MeasureRAMSettingsInput'
local defaultHint = 'Changes save automatically.'
local choices = {
    RAMUseMiB = {default=0, count=2, kind='units', meter='MeterRAMSettingsUnits'},
    RAMDecimals = {default=1, count=3, kind='number', meter='MeterRAMSettingsDecimals'},
    RAMPercentDecimals = {default=0, count=3, kind='number', meter='MeterRAMSettingsPercentDecimals'},
    RAMShowBar = {default=1, count=2, kind='toggle', meter='MeterRAMSettingsBar'},
    RAMShowPageBar = {default=1, count=2, kind='toggle', meter='MeterRAMSettingsPageBar'},
    RAMShowHistory = {default=1, count=2, kind='toggle', meter='MeterRAMSettingsHistory'}
}

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function numericChoice(key)
    return type(key) == 'string' and choices[key] and choices[key].kind == 'number'
end

local function render()
    if not values or closed then return end
    for key, spec in pairs(choices) do
        local label = tostring(values[key])
        if spec.kind == 'units' then label = values[key] == 1 and 'MB' or 'GB'
        elseif spec.kind == 'toggle' then label = values[key] == 1 and 'On' or 'Off' end
        SKIN:Bang('!SetOption', spec.meter, 'Text', label)
    end
    SKIN:Bang('!SetOption', 'MeterRAMSettingsHint', 'Text', hint or defaultHint)
    SKIN:Bang('!UpdateMeterGroup', 'RAMSettingsUI')
    SKIN:Bang('!Redraw')
end

local function message(text)
    hint = text
    render()
end

local function canChange()
    if not values or closed then return false end
    if inputKey then message('Finish or cancel the current number entry.'); return false end
    return true
end

local function save(key, value)
    local spec = choices[key]
    if not spec or not finite(value) or value ~= math.floor(value) or value < 0 or value >= spec.count then return false end
    -- Preserve raw legacy/custom preferences on load and unchanged actions.
    -- Only the explicitly changed key is normalized and persisted.
    if value == values[key] then return false end
    values[key] = value
    SKIN:Bang('!SetVariable', key, tostring(value))
    SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), userFile)
    SKIN:Bang('!SetVariableGroup', key, tostring(value), 'ParallaxRAM')
    -- Reformat/apply cached main values without refresh, resampling or history loss.
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxRAMApply', '*')
    hint = defaultHint
    render()
    return true
end

local function refreshedInputStatus()
    -- RunCommand caches GetValue: refresh before distinguishing active 0 from
    -- complete 1. Initial -1 or an unupdated 0 never establish ownership.
    SKIN:Bang('!UpdateMeasure', inputMeasure)
    local measure = SKIN:GetMeasure(inputMeasure)
    local value = measure and measure:GetValue()
    return finite(value) and value or 103, measure
end

function Initialize()
    values = {}
    inputKey, inputLaunched, closed, completing, hint = nil, false, false, false, defaultHint
    userFile = SKIN:GetVariable('@') .. 'User\\RAM.inc'
    for key, spec in pairs(choices) do
        local value = tonumber(SKIN:GetVariable(key))
        if not finite(value) then value=spec.default end
        values[key] = math.max(0, math.min(spec.count-1, math.floor(value)))
    end
end

function Update()
    render()
    return 0
end

function Cycle(key, direction)
    local spec = type(key) == 'string' and choices[key]
    if not spec or spec.kind == 'number' then return false end
    if direction == nil then direction = 1 end
    if direction ~= -1 and direction ~= 1 then return false end
    if not canChange() then return false end
    return save(key, (values[key] + direction) % spec.count)
end

function Adjust(key, direction)
    if not numericChoice(key) or (direction ~= -1 and direction ~= 1) then return false end
    if not canChange() then return false end
    return save(key, math.max(0, math.min(2, values[key] + direction)))
end

function Edit(key)
    if not numericChoice(key) or not canChange() then return false end
    local frame = SKIN:GetMeter(choices[key].meter .. 'Frame')
    if not frame or not SKIN:GetMeasure(inputMeasure) then
        message('Number entry unavailable. Use the arrows.'); return false
    end
    local skinX, skinY, frameX, frameY = SKIN:GetX(), SKIN:GetY(), frame:GetX(), frame:GetY()
    if not finite(skinX) or not finite(skinY) or not finite(frameX) or not finite(frameY) then
        message('Number entry unavailable. Use the arrows.'); return false
    end
    local x, y = skinX + frameX, skinY + frameY
    local width, height, scale = frame:GetW(), frame:GetH(), tonumber(SKIN:GetVariable('Scale')) or 1
    if not finite(x) or not finite(y) or not finite(width) or not finite(height) or not finite(scale) or
        x < -100000 or x > 100000 or y < -100000 or y > 100000 or width <= 0 or height <= 0 then
        message('Number entry unavailable. Use the arrows.'); return false
    end
    scale = math.max(0.75, math.min(2, scale))
    local scaleText = string.format('%.4f', scale):gsub(',', '.')
    -- Script name, mode and bounds are fixed. Initial values and geometry are
    -- canonical numbers; neither typed text nor arbitrary keys enter a command.
    local parameter = string.format('-NoLogo -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "SettingsInput.ps1" -Key UtilityNumber -Initial %d -Minimum 0 -Maximum 2 -DecimalPlaces 0 -X %d -Y %d -Width %d -Height %d -Scale %s',
        values[key], math.floor(x), math.floor(y), math.max(24, math.min(2048, math.floor(width))),
        math.max(12, math.min(512, math.floor(height))), scaleText)
    SKIN:Bang('!SetOption', inputMeasure, 'Parameter', parameter)
    SKIN:Bang('!UpdateMeasure', inputMeasure)
    inputKey, inputLaunched = key, true
    message('Enter 0 to 2; Enter saves, Esc cancels.')
    SKIN:Bang('!CommandMeasure', inputMeasure, 'Run')
    if inputLaunched then
        local status = refreshedInputStatus()
        if status >= 100 then
            inputKey, inputLaunched = nil, false
            message('Number entry failed. Use the arrows.')
            return false
        end
    end
    return true
end

function CompleteInput()
    if closed or completing or not inputLaunched or not numericChoice(inputKey) then return false end
    completing = true
    local status, measure = refreshedInputStatus()
    completing = false
    if status == 0 then return false end
    local key = inputKey
    -- Release before saving so duplicate FinishAction callbacks are harmless.
    inputKey, inputLaunched = nil, false
    if status ~= 1 then message('Number entry failed. Use the arrows.'); return false end
    local wire = measure and measure:GetStringValue()
    if type(wire) ~= 'string' or #wire > 64 then
        message('Invalid number entry. Use the arrows.'); return false
    end
    -- The shared helper writes exactly one line. Accept one terminal Windows
    -- or LF line ending, never duplicate frames or arbitrary surrounding text.
    if wire:sub(-2) == '\r\n' then wire = wire:sub(1, -3)
    elseif wire:sub(-1) == '\n' then wire = wire:sub(1, -2) end
    if wire == 'PARALLAX_INPUT_V1|cancel|' then message('Number entry cancelled.'); return false end
    local value = wire:match('^PARALLAX_INPUT_V1|ok|([012])$')
    if not value then message('Invalid number entry. Use the arrows.'); return false end
    value = tonumber(value)
    if not numericChoice(key) or not finite(value) or value ~= math.floor(value) or value < 0 or value > 2 then
        message('Invalid number entry. Use the arrows.'); return false
    end
    if value == values[key] then message(defaultHint); return false end
    return save(key, value)
end

function Close()
    if closed then return end
    closed = true
    if inputLaunched then
        local status = refreshedInputStatus()
        inputKey, inputLaunched = nil, false
        if status == 0 then SKIN:Bang('!CommandMeasure', inputMeasure, 'Kill') end
    end
end
