-- Original Parallax Chronometer settings. Only explicit clicks write configuration.
-- InputText is deliberately not used: its $UserInput$ replacement reaches the
-- command parser before Lua validation, and InputNumber filters keypresses only.
-- Typed numbers return from the shared one-shot helper as a validated data protocol.
local settingsPath, selectedList, stepIndex, values, status, pendingNumber
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
local settingsDetailHeights = { Clock = 84, Uptime = 0, Event = 28, Timers = 216 }
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
local function tooltip(meter, value)
    SKIN:Bang('!SetOption', meter, 'ToolTipText', tostring(value))
end
local function numberVariable(key, fallback)
    local value = SKIN:GetVariable(key, tostring(fallback))
    return tonumber(value) or SKIN:ParseFormula(value)
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
    local settingsHeight = 752
    for section, key in pairs(sectionKeys) do
        local visible = current(key, '1') == '0' and '0' or '1'
        -- Drive only this menu's dynamic layout from verified saved preferences.
        -- Hidden settings keep their values; monitor geometry is never written here.
        SKIN:Bang('!SetVariable', key, visible)
        option('Meter' .. section .. 'Visibility', visible == '0' and 'Hidden' or 'Shown')
        if visible == '0' then settingsHeight = settingsHeight - settingsDetailHeights[section] end
    end
    -- Derived variables are expanded when loaded, so refresh all three local
    -- height values explicitly. These bangs do not write the monitor's User file.
    local heightPx = math.floor(settingsHeight * numberVariable('Scale', 1) + 0.5)
    SKIN:Bang('!SetVariable', 'PanelHeight', tostring(settingsHeight))
    SKIN:Bang('!SetVariable', 'PanelHeightPx', tostring(heightPx))
    SKIN:Bang('!SetVariable', 'WindowHeight', tostring(heightPx + numberVariable('Gap', 0)))
    local listName = plain(SKIN:GetVariable('ChronometerList' .. selectedList .. 'Name'), 'List ' .. selectedList)
    option('MeterListName', string.format('%d / 3  %s', selectedList, listName))
    local listTip = listName .. '\nUse the arrows to select the previous or next timer list.'
    tooltip('MeterListName', listTip)
    tooltip('MeterListLabel', listTip)
    for row = 1, 4 do
        local name = plain(SKIN:GetVariable('ChronometerList' .. selectedList .. 'Timer' .. row .. 'Label'), 'Timer ' .. row)
        local duration = durationText(integer(current(timerKey(row)), 1, maximum))
        option('MeterTimerLabel' .. row, name)
        option('MeterTimerSeconds' .. row, duration)
        local timerTip = name .. ': ' .. duration .. '\nEnter whole seconds from 1 to 604800. Arrows adjust by ' .. stepNames[stepIndex] .. '. Changing duration resets this timer.'
        tooltip('MeterTimerLabel' .. row, timerTip)
        tooltip('MeterTimerSeconds' .. row, timerTip)
    end
    option('MeterStepValue', stepNames[stepIndex])
    option('MeterStatus', status)
    tooltip('MeterStatus', status)
    -- Include panel bounds, section rules and hidden hit targets in the reflow.
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Chronometer.inc'
    selectedList, stepIndex, status = 1, 2, 'Changes apply immediately.'
    pendingNumber = nil
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
    if pendingNumber and (pendingNumber.spec.key == key or (key == 'ChronometerShowTimers' and pendingNumber.target ~= 'Columns')) then
        pendingNumber.stale = true
    end
    status = key:match('Seconds$') and 'Saved. Changed timer reset.' or 'Saved.'
    Render()
    -- Core.reconcile retains every other timer, including running deadlines.
    SKIN:Bang('!Refresh', 'Parallax\\Chronometer')
    return true
end

function CycleClock(direction)
    direction = direction == nil and 1 or direction
    if direction ~= -1 and direction ~= 1 then return false end
    values = readValues() or values
    local twelve, seconds = clockParts()
    return save('ChronometerClockFormat', clockFormat(not twelve, seconds))
end
function ToggleSeconds()
    values = readValues() or values
    local twelve, seconds = clockParts()
    return save('ChronometerClockFormat', clockFormat(twelve, not seconds))
end
function CycleDate(direction)
    direction = direction == nil and 1 or direction
    if direction ~= -1 and direction ~= 1 then return false end
    values = readValues() or values
    local nextIndex = direction == 1 and 1 or #dateFormats
    for index, candidate in ipairs(dateFormats) do
        if current('ChronometerDateFormat') == candidate then nextIndex = (index - 1 + direction) % #dateFormats + 1 end
    end
    return save('ChronometerDateFormat', dateFormats[nextIndex])
end
function ToggleColumns()
    values = readValues() or values
    return save('Columns', current('Columns') == '2' and '1' or '2')
end
function AdjustColumns(direction)
    if direction ~= -1 and direction ~= 1 then return false end
    values = readValues() or values
    local columns = integer(current('Columns'), 1, 2)
    if not columns then return false end
    local nextValue = math.max(1, math.min(2, columns + direction))
    if nextValue == columns then return false end
    return save('Columns', tostring(nextValue))
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
    if pendingNumber and pendingNumber.target ~= 'Columns' then pendingNumber.stale = true end
    selectedList = (selectedList - 1 + delta) % 3 + 1
    values = readValues() or values
    status = 'Changes apply immediately.'
    Render()
    return true
end
function CycleStep()
    if pendingNumber and pendingNumber.target == 'Step' then pendingNumber.stale = true end
    stepIndex = stepIndex % #steps + 1
    Render()
    return true
end
function AdjustStep(direction)
    if direction ~= -1 and direction ~= 1 then return false end
    values = readValues() or values
    if current('ChronometerShowTimers', '1') == '0' then return false end
    local nextIndex = math.max(1, math.min(#steps, stepIndex + direction))
    if nextIndex == stepIndex then return false end
    if pendingNumber and pendingNumber.target == 'Step' then pendingNumber.stale = true end
    stepIndex = nextIndex
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
    if nextValue == duration then return false end
    return save(timerKey(row), tostring(nextValue))
end

local inputMeasure = 'MeasureChronometerSettingsInput'
local function inputFailure(message)
    status = message
    Render()
    return false
end
local function inputSpec(target, row)
    if target == 'Columns' and row == nil then
        return { key = 'Columns', meter = 'MeterWidthRow', low = 1, high = 2, fallback = 1 }
    elseif target == 'Step' and row == nil then
        return { meter = 'MeterStepRow', low = 1, high = 3600, fallback = 60 }
    elseif target == 'Duration' then
        row = integer(row, 1, 4)
        if row then return { key = timerKey(row), meter = 'MeterTimerRow' .. row, low = 1, high = maximum, fallback = 60 } end
    end
end
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function BeginNumberInput(target, row)
    if pendingNumber then return false end
    local spec = inputSpec(target, row)
    if not spec then return false end
    local snapshot = readValues()
    if not snapshot then return inputFailure('Cannot read Chronometer settings.') end
    values = snapshot
    local visible = current('ChronometerShowTimers', '1') ~= '0'
    if target ~= 'Columns' and not visible then return false end
    local measure = SKIN:GetMeasure(inputMeasure)
    local meter = SKIN:GetMeter(spec.meter)
    if not measure or not meter then return inputFailure('Numeric editor unavailable. Reopen settings.') end
    if measure:GetValue() == 0 then return inputFailure('Numeric editor is already open.') end
    local resource = SKIN:GetVariable('@', '')
    if type(resource) ~= 'string' or resource == '' or resource:find('[%c"]') then
        return inputFailure('Numeric editor path is unavailable.')
    end
    local helper = resource .. 'Scripts\\SettingsInput.ps1'
    local file = io.open(helper, 'rb')
    if not file then return inputFailure('Numeric editor helper is missing.') end
    file:close()
    local x, y, width, height = SKIN:GetX() + meter:GetX(), SKIN:GetY() + meter:GetY(), meter:GetW(), meter:GetH()
    local scale = numberVariable('Scale', 1)
    if not finite(x) or not finite(y) or not finite(width) or not finite(height) or not finite(scale)
        or x < -100000 or x > 100000 or y < -100000 or y > 100000
        or width < 24 or width > 2048 or height < 12 or height > 512 or scale < 0.75 or scale > 2 then
        return inputFailure('Numeric editor bounds are unavailable.')
    end
    local expected = spec.key and current(spec.key) or tostring(steps[stepIndex])
    local initial = integer(expected, spec.low, spec.high) or spec.fallback
    pendingNumber = { target = target, spec = spec, expected = expected, list = selectedList, visible = visible }
    status = target == 'Step' and 'Enter step seconds: 1, 60, 300 or 3600.' or 'Enter to apply. Esc to cancel.'
    Render()
    -- Only a fixed helper path, fixed switch names and canonical numbers reach the
    -- process. The typed result is never interpolated into a command or action.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%s" -Key UtilityNumber -Minimum %d -Maximum %d -DecimalPlaces 0 -Initial "%d" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        helper, spec.low, spec.high, initial, math.floor(x), math.floor(y), math.floor(width), math.floor(height), scale)
    SKIN:Bang('!SetOption', inputMeasure, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', inputMeasure)
    SKIN:Bang('!CommandMeasure', inputMeasure, 'Run')
    return true
end

function CommitNumberInput()
    if not pendingNumber then return false end
    local measure = SKIN:GetMeasure(inputMeasure)
    if measure and measure:GetValue() == 0 then return false end
    local edit = pendingNumber
    pendingNumber = nil
    if not measure then return inputFailure('Numeric editor unavailable. Value was not applied.') end
    local output = measure:GetStringValue()
    if type(output) ~= 'string' or #output > 96 then return inputFailure('Value was not applied. Try again.') end
    -- Accept the helper's single optional line terminator, never extra lines/data.
    if output:sub(-2) == '\r\n' then output = output:sub(1, -3)
    elseif output:sub(-1) == '\n' then output = output:sub(1, -2) end
    if output == 'PARALLAX_INPUT_V1|cancel|' then
        status = 'Edit cancelled.'; Render(); return false
    end
    local literal = output:match('^PARALLAX_INPUT_V1|ok|([+-]?%d+)$')
    local value = literal and tonumber(literal)
    if not finite(value) or value < edit.spec.low or value > edit.spec.high or value ~= math.floor(value) then
        return inputFailure('Value was not applied. Enter a whole number in range.')
    end
    local nextStep
    if edit.target == 'Step' then
        for index, candidate in ipairs(steps) do if value == candidate then nextStep = index end end
        if not nextStep then return inputFailure('Step must be 1, 60, 300 or 3600 seconds.') end
    end
    local snapshot = readValues()
    if not snapshot then return inputFailure('Cannot read Chronometer settings. Value was not applied.') end
    values = snapshot
    local stale = edit.target ~= 'Columns' and (selectedList ~= edit.list or
        (current('ChronometerShowTimers', '1') ~= '0') ~= edit.visible)
    local actual = edit.spec.key and current(edit.spec.key) or tostring(steps[stepIndex])
    if edit.stale or stale or actual ~= edit.expected then return inputFailure('Setting changed during editing. Value was not applied.') end
    if nextStep then
        if nextStep == stepIndex then status = 'Already set.'; Render(); return false end
        stepIndex = nextStep
        status = 'Adjustment step updated.'; Render(); return true
    end
    if value == tonumber(actual) then status = 'Already set.'; Render(); return false end
    return save(edit.spec.key, tostring(value))
end
