-- Original Parallax Chronometer settings. Only explicit clicks write configuration.
-- InputText is deliberately not used: its $UserInput$ replacement reaches the
-- command parser before Lua validation, and InputNumber filters keypresses only.
-- Fixed presets and numeric step buttons keep all bang arguments under our control.
local settingsPath, selectedList, stepIndex, values, status
local steps = { 1, 60, 300, 3600 }
local stepNames = { '1 sec', '1 min', '5 min', '1 hour' }
local presets = { 60, 300, 600, 900, 1500, 1800, 2700, 3600, 5400, 7200, 14400, 28800, 43200, 86400, 172800, 604800 }
local dateFormats = { '%A, %d %B %Y', '%a, %d %b', '%Y-%m-%d' }
local dateNames = { 'Full', 'Short', 'ISO' }
local defaults = { ChronometerClockFormat = '%H:%M:%S', ChronometerDateFormat = dateFormats[1], Columns = '1' }
local sectionKeys = {
    Clock = 'ChronometerShowClock', Uptime = 'ChronometerShowUptime',
    Event = 'ChronometerShowEvent', Timers = 'ChronometerShowTimers'
}
local maximum = 604800

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function integer(value, low, high)
    local text = trim(value)
    if not text:match('^%d+$') then return nil end
    local number = tonumber(text)
    if not number or number < low or number > high or number ~= math.floor(number) then return nil end
    return number
end
local function plain(value, fallback)
    local text = tostring(value or ''):gsub('[%c#%%%[%]]', ' ')
    text = trim(text)
    return text ~= '' and text or fallback
end
local function option(meter, value)
    SKIN:Bang('!SetOption', meter, 'Text', tostring(value))
end
local function timerKey(row)
    return 'ChronometerList' .. selectedList .. 'Timer' .. row .. 'Seconds'
end

-- Read back only ASCII configuration keys / scalar values. Native WriteKeyValue
-- handles the actual update, retaining unrelated keys, comments and file encoding.
-- UTF-16 input is decoded to ASCII for validation; non-ASCII names are read by
-- Rainmeter itself and never rewritten by this controller.
local function readValues()
    local file = io.open(settingsPath, 'rb')
    if not file then return nil end
    local contents = file:read(262145)
    file:close()
    if not contents or #contents > 262144 then return nil end
    local bom = contents:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        local ascii, little = {}, bom == '\255\254'
        if #contents % 2 ~= 0 then return nil end
        for index = 3, #contents, 2 do
            local a, b = contents:byte(index, index + 1)
            local code = little and (a + 256 * b) or (b + 256 * a)
            ascii[#ascii + 1] = code < 128 and string.char(code) or '?'
        end
        contents = table.concat(ascii)
    else
        contents = contents:gsub('^\239\187\191', '')
    end
    local found, inVariables = {}, false
    for line in (contents .. '\n'):gmatch('([^\r\n]*)[\r\n]+') do
        local section = line:match('^%s*%[([^%]]+)%]%s*$')
        if section then inVariables = section:lower() == 'variables'
        elseif inVariables then
            local key, value = line:match('^%s*([%w_]+)%s*=(.*)$')
            if key then found[key:lower()] = trim(value) end
        end
    end
    return found
end
local function current(key, fallback)
    if values and values[key:lower()] ~= nil then return values[key:lower()] end
    return SKIN:GetVariable(key, fallback or defaults[key] or '')
end
local function clockParts()
    local format = current('ChronometerClockFormat')
    return format:find('%%I') ~= nil, format:find('%%S') ~= nil
end
local function clockFormat(twelve, seconds)
    return (twelve and '%I:%M' or '%H:%M') .. (seconds and ':%S' or '') .. (twelve and ' %p' or '')
end
local function durationText(seconds)
    if not seconds then return 'Fix duration' end
    local days = math.floor(seconds / 86400)
    local clock = string.format('%02d:%02d:%02d', math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60, seconds % 60)
    return (days > 0 and tostring(days) .. 'd ' or '') .. clock
end

function Render()
    local twelve, seconds = clockParts()
    local format = current('ChronometerClockFormat')
    local standard = format == clockFormat(twelve, seconds)
    option('MeterClockValue', standard and (twelve and '12-hour' or '24-hour') or 'Custom')
    option('MeterSecondsValue', seconds and 'Shown' or 'Hidden')
    local dateName = 'Custom'
    for index, candidate in ipairs(dateFormats) do
        if current('ChronometerDateFormat') == candidate then dateName = dateNames[index] end
    end
    option('MeterDateValue', dateName)
    option('MeterWidthValue', current('Columns') == '2' and '2 columns' or '1 column')
    for section, key in pairs(sectionKeys) do
        option('Meter' .. section .. 'Visibility', current(key, '1') == '0' and 'Hidden' or 'Shown')
    end
    option('MeterListName', string.format('%d / 3  %s', selectedList, plain(SKIN:GetVariable('ChronometerList' .. selectedList .. 'Name'), 'List ' .. selectedList)))
    for row = 1, 4 do
        option('MeterTimerLabel' .. row, plain(SKIN:GetVariable('ChronometerList' .. selectedList .. 'Timer' .. row .. 'Label'), 'Timer ' .. row))
        option('MeterTimerSeconds' .. row, durationText(integer(current(timerKey(row)), 1, maximum)))
    end
    option('MeterStepValue', 'Step: ' .. stepNames[stepIndex])
    option('MeterStatus', status)
    SKIN:Bang('!UpdateMeterGroup', 'ChronometerSettingsData')
    SKIN:Bang('!Redraw')
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Chronometer.inc'
    selectedList, stepIndex, status = 1, 2, 'Changes apply immediately.'
    values = readValues()
end
function Update() Render(); return 0 end

local function save(key, value)
    -- Callers supply only a fixed format, visibility flag, column count or checked integer.
    -- No names, user input, paths or executable expressions enter this value.
    local before = readValues()
    if not before then status = 'Cannot read Chronometer settings.'; Render(); return false end
    values = before
    if current(key) == value then status = 'Already set.'; Render(); return true end
    SKIN:Bang('!WriteKeyValue', 'Variables', key, value, settingsPath)
    local after = readValues()
    if not after or after[key:lower()] ~= value then
        status = 'Save failed. Check file permissions.'
        Render()
        return false
    end
    values = after
    status = key:match('Seconds$') and 'Saved. Changed timer reset.' or 'Saved.'
    Render()
    -- Core.reconcile retains every other timer, including running deadlines.
    SKIN:Bang('!Refresh', 'Parallax\\Chronometer')
    return true
end

function CycleClock()
    values = readValues() or values
    local twelve, seconds = clockParts()
    return save('ChronometerClockFormat', clockFormat(not twelve, seconds))
end
function ToggleSeconds()
    values = readValues() or values
    local twelve, seconds = clockParts()
    return save('ChronometerClockFormat', clockFormat(twelve, not seconds))
end
function CycleDate()
    values = readValues() or values
    local nextIndex = 1
    for index, candidate in ipairs(dateFormats) do
        if current('ChronometerDateFormat') == candidate then nextIndex = index % #dateFormats + 1 end
    end
    return save('ChronometerDateFormat', dateFormats[nextIndex])
end
function ToggleColumns()
    values = readValues() or values
    return save('Columns', current('Columns') == '2' and '1' or '2')
end
function ToggleSection(section)
    if type(section) ~= 'string' or not sectionKeys[section] then return false end
    values = readValues() or values
    local key = sectionKeys[section]
    -- Visibility changes never alter timer durations or event state.
    return save(key, current(key, '1') == '0' and '1' or '0')
end
function SelectList(delta)
    if delta ~= 1 and delta ~= -1 then return false end
    selectedList = (selectedList - 1 + delta) % 3 + 1
    values = readValues() or values
    status = 'Changes apply immediately.'
    Render()
    return true
end
function CycleStep()
    stepIndex = stepIndex % #steps + 1
    Render()
    return true
end
function CycleDuration(row)
    row = integer(row, 1, 4)
    if not row then return false end
    values = readValues() or values
    local duration = integer(current(timerKey(row)), 1, maximum)
    local nextValue = presets[1]
    if duration then
        for _, candidate in ipairs(presets) do
            if candidate > duration then nextValue = candidate; break end
        end
    end
    return save(timerKey(row), tostring(nextValue))
end
function AdjustDuration(row, direction)
    row = integer(row, 1, 4)
    if not row or (direction ~= -1 and direction ~= 1) then return false end
    values = readValues() or values
    local duration = integer(current(timerKey(row)), 1, maximum)
    local nextValue = duration and math.min(maximum, math.max(1, duration + direction * steps[stepIndex])) or presets[1]
    return save(timerKey(row), tostring(nextValue))
end
