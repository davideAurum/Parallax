-- Dated event countdown. Read state on load/editor completion only; ticks do not touch disk.
local Core, path, event, invalid, editorError
local cache = {}

local function option(meter, key, value)
    value = tostring(value or '')
    local id = meter .. ':' .. key
    if cache[id] ~= value then
        cache[id] = value
        SKIN:Bang('!SetOption', meter, key, value)
    end
end

local function paint(immediate)
    local active = event and event.enabled
    local remaining = active and Core.remaining(event, os.time()) or 0
    local label, value, color = 'No event set', 'Add in settings', 'AccentColor2'
    local detail = 'Add an event in Chronometer settings.'
    if invalid then
        label, value, color = 'Event unavailable', 'Open settings to repair', 'WarningColor'
        detail = 'The saved event could not be read. Open Event Countdown in Chronometer settings to repair it.'
    elseif active then
        local name = Core.displayName(event.name)
        label = remaining > 0 and ('Countdown to ' .. name .. ':') or ('Event reached: ' .. name)
        value = Core.format(remaining)
        local date = os.date('%Y-%m-%d %H:%M', event.deadline)
        detail = label .. '\n' .. value .. '\nTarget: ' .. date .. ' (local time).'
    end
    if editorError then
        label, color = 'Event editor unavailable', 'WarningColor'
        if not active then value = 'Open settings to retry' end
        detail = detail .. '\nCould not open the event editor. Try again from Chronometer settings.'
    end
    option('MeterEventName', 'Text', label)
    option('MeterEventName', 'ToolTipText', detail)
    option('MeterEventName', 'FontColor', SKIN:GetVariable((invalid or editorError) and 'WarningColor' or 'TextColor'))
    option('MeterEventCountdown', 'Text', value)
    option('MeterEventCountdown', 'ToolTipText', detail)
    option('MeterEventCountdown', 'FontColor', SKIN:GetVariable(color))
    -- Periodic updates already receive Rainmeter's end-of-cycle meter update
    -- and redraw. Editor callbacks still request an immediate visual update.
    if immediate ~= false then
        SKIN:Bang('!UpdateMeterGroup', 'ChronometerEvent')
        SKIN:Bang('!Redraw')
    end
    return remaining
end

local function read()
    local file, _, code = io.open(path, 'rb')
    if not file then
        event, invalid = nil, code ~= 2
        return
    end
    local text = file:read(2049)
    file:close()
    event = text and Core.decode(text) or nil
    invalid = event == nil
end

function Initialize()
    Core = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\EventCore.lua')
    path = SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state'
    editorError = false
    read()
end

function Update() return paint(false) end

function Reload()
    editorError = false
    read()
    return paint()
end

function OpenEditor()
    local measure = SKIN:GetMeasure('MeasureEventEditor')
    -- RunCommand reports zero while the form is open. A second click keeps that form.
    if measure and measure:GetValue() == 0 then return end
    editorError = false
    SKIN:Bang('!CommandMeasure', 'MeasureEventEditor', 'Run')
end

function EditorFinished()
    read()
    local measure = SKIN:GetMeasure('MeasureEventEditor')
    local result = measure and measure:GetStringValue():match('^%s*(.-)%s*$') or ''
    editorError = result ~= 'SAVED' and result ~= 'CLEARED' and result ~= 'CANCELLED'
    return paint()
end

function EditorFailed()
    editorError = true
    return paint()
end
