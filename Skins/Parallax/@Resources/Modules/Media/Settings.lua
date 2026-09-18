-- Original Parallax Media settings. Fixed controls write on explicit clicks only.
-- Rainmeter performs the individual key updates so unrelated settings and the
-- original file encoding remain intact. Only a numeric field click starts the
-- shared one-shot input overlay; queue/source workers remain explicit actions.
local settingsPath, values, status, restartPending, layoutExpanded
local editingRequest, settingsRevision, providerLaunched
local defaults = { Columns = '1', QueueExpanded = '0', QueueRowLimit = '5', QueueShowDetails = '1', QueuePollSeconds = '30' }
local allowed = {
    QueueExpanded = { '0', '1' }, QueueShowDetails = { '0', '1' }
}
local numberFields = {
    Columns = { minimum = 1, maximum = 2, meter = 'MeterWidthFrame' },
    QueueRowLimit = { minimum = 1, maximum = 5, meter = 'MeterQueueRowsFrame' },
    QueuePollSeconds = { minimum = 30, maximum = 150, meter = 'MeterQueuePollFrame' }
}
local managed = {}
for key in pairs(defaults) do managed[key:lower()] = true end

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function accepted(key, value)
    local field = numberFields[key]
    if field then
        if type(value) ~= 'string' or #value > 3 or not value:match('^[1-9]%d*$') then return nil end
        local number = tonumber(value)
        if number >= field.minimum and number <= field.maximum then return value end
        return nil
    end
    for _, candidate in ipairs(allowed[key] or {}) do
        if value == candidate then return candidate end
    end
    return nil
end
local function option(meter, value)
    SKIN:Bang('!SetOption', meter, 'Text', tostring(value))
end
local function storedNumber(key, source)
    local value = source and source[key:lower()]
    if value == nil then value = defaults[key] end
    local field = numberFields[key]
    local number = type(value) == 'string' and value:match('^%d+$') and tonumber(value)
    if number and number >= field.minimum and number <= field.maximum and number == math.floor(number) then
        return tostring(number)
    end
    return nil
end

-- Read back bounded ASCII key/value data only. Non-ASCII names and comments are
-- ignored here and are never rewritten by Lua. Both UTF-16 byte orders and a
-- UTF-8 BOM are accepted. Ambiguous duplicate managed keys fail closed.
local function readValues()
    local file = io.open(settingsPath, 'rb')
    if not file then return nil end
    local contents = file:read(262145)
    file:close()
    if not contents or #contents > 262144 then return nil end
    local bom = contents:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        if #contents % 2 ~= 0 then return nil end
        local ascii, little = {}, bom == '\255\254'
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
        if section then
            inVariables = section:lower() == 'variables'
        elseif inVariables then
            local key, value = line:match('^%s*([%w_]+)%s*=(.*)$')
            key = key and key:lower()
            if key and managed[key] then
                if found[key] ~= nil then return nil end
                found[key] = trim(value)
            end
        end
    end
    return found
end
local function current(key)
    local value = values and values[key:lower()]
    if value == nil then value = SKIN:GetVariable(key, defaults[key]) end
    value = trim(value)
    -- Preserve the full previously supported saved ranges, including a harmless
    -- leading zero, while all new writes use canonical integer text.
    if numberFields[key] then
        return storedNumber(key, { [key:lower()] = value }) or defaults[key]
    end
    return accepted(key, value) or defaults[key]
end

-- Queue display details follow the saved feature visibility. These variables
-- affect this settings window only; monitor dimensions and choices stay saved.
local function renderLayout()
    local expanded = current('QueueExpanded') == '1' and 1 or 0
    if layoutExpanded == expanded then return end
    layoutExpanded = expanded
    local collapsedHeight = (1 - expanded) * 56
    local settingsHeight = 554 - collapsedHeight
    -- Rainmeter expands nested variable references at load, so rebuild both
    -- physical heights instead of retaining the initial collapsed expression.
    local heightPx = SKIN:ParseFormula(SKIN:ReplaceVariables('(Round(' .. settingsHeight .. '*#Scale#))'))
    local gap = SKIN:ParseFormula(SKIN:ReplaceVariables('(#Gap#)'))
    SKIN:Bang('!SetVariable', 'MediaSettingsQueueDetailsVisible', expanded)
    SKIN:Bang('!SetVariable', 'MediaSettingsQueueCollapsedHeight', collapsedHeight)
    SKIN:Bang('!SetVariable', 'SettingsPanelHeight', settingsHeight)
    SKIN:Bang('!SetVariable', 'PanelHeightPx', heightPx)
    SKIN:Bang('!SetVariable', 'WindowHeight', heightPx + gap)
end

function Render()
    renderLayout()
    option('MeterWidthValue', current('Columns'))
    option('MeterQueueExpandedValue', current('QueueExpanded') == '1' and 'Expanded' or 'Collapsed')
    option('MeterQueueRowsValue', current('QueueRowLimit'))
    option('MeterQueueDetailsValue', current('QueueShowDetails') == '1' and 'Shown' or 'Hidden')
    option('MeterQueuePollValue', current('QueuePollSeconds'))
    -- The helper buttons use only a validated numeric interval, including after
    -- a saved click without refreshing or closing this settings config.
    SKIN:Bang('!SetVariable', 'QueuePollSeconds', current('QueuePollSeconds'))
    option('MeterStatus', status)
    SKIN:Bang('!UpdateMeterGroup', 'MediaSettingsData')
    SKIN:Bang('!Redraw')
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Media.inc'
    values = readValues()
    restartPending = false
    layoutExpanded = nil
    editingRequest = nil
    settingsRevision = 0
    providerLaunched = {}
    status = values and 'Changes save when clicked.' or 'Cannot read Media settings.'
    renderLayout()
end
function Update() Render(); return 0 end

local function save(key, value)
    if not accepted(key, value) then return false end
    local before = readValues()
    if not before then status = 'Cannot read Media settings.'; Render(); return false end
    values = before
    if key == 'QueueRowLimit' and current('QueueExpanded') ~= '1' then return false end
    -- Typed input can explicitly replace an invalid legacy expression with a
    -- valid value, even when that value matches the fallback shown in the UI.
    local saved = numberFields[key] and storedNumber(key, before) or (not numberFields[key] and current(key))
    if saved == value then return false end
    -- An explicit local mutation invalidates any older overlay, even if its
    -- individual file write subsequently fails verification.
    settingsRevision = settingsRevision + 1
    SKIN:Bang('!WriteKeyValue', 'Variables', key, value, settingsPath)
    local after = readValues()
    if not after or after[key:lower()] ~= value then
        status = 'Save failed. Check file permissions.'
        Render()
        return false
    end
    values = after
    if key == 'QueuePollSeconds' then restartPending = true end
    status = restartPending and 'Use Restart to apply interval.' or 'Saved.'
    Render()
    -- Refresh active Media variants without loading an absent plugin/player or
    -- closing this settings menu. Unloaded target configs remain unloaded.
    SKIN:Bang('!Refresh', 'Parallax\\Media')
    SKIN:Bang('!Refresh', 'Parallax\\Media\\Queue')
    return true
end
local function cycle(key)
    values = readValues() or values
    local now, choices = tonumber(current(key)), allowed[key]
    for _, candidate in ipairs(choices) do
        if tonumber(candidate) > now then return save(key, candidate) end
    end
    return save(key, choices[1])
end

function StepNumber(key, delta)
    local field = numberFields[key]
    if not field or type(delta) ~= 'number' or (delta ~= -1 and delta ~= 1) or editingRequest then return false end
    local before = readValues()
    if not before then status = 'Cannot read Media settings.'; Render(); return false end
    values = before
    if key == 'QueueRowLimit' and current('QueueExpanded') ~= '1' then return false end
    -- An arrow never guesses how to change an invalid/custom saved value.
    -- The explicit numeric editor remains available to replace that value.
    local number = tonumber(storedNumber(key, before))
    if not number then return false end
    local nextNumber = math.max(field.minimum, math.min(field.maximum, number + delta))
    if nextNumber == number then return false end
    return save(key, tostring(nextNumber))
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function BeginNumberInput(key)
    local field = numberFields[key]
    if not field or editingRequest then return false end
    local before = readValues()
    if not before then status = 'Cannot read Media settings.'; Render(); return false end
    values = before
    if key == 'QueueRowLimit' and current('QueueExpanded') ~= '1' then return false end
    local meter = SKIN:GetMeter(field.meter)
    local measure = SKIN:GetMeasure('MeasureMediaSettingsInput')
    if not meter or not measure then return false end
    SKIN:Bang('!UpdateMeasure', 'MeasureMediaSettingsInput')
    if measure:GetValue() == 0 then return false end

    local x, y = SKIN:GetX() + meter:GetX(), SKIN:GetY() + meter:GetY()
    local width, height = meter:GetW(), meter:GetH()
    local scale = tonumber(SKIN:GetVariable('Scale', '1'))
    if not finite(x) or not finite(y) or not finite(width) or not finite(height) or not finite(scale) then return false end
    x, y, width, height = math.floor(x), math.floor(y), math.floor(width), math.floor(height)
    if x < -100000 or x > 100000 or y < -100000 or y > 100000 or
        width < 24 or width > 2048 or height < 12 or height > 512 or scale < 0.75 or scale > 2 then return false end
    local resources = SKIN:GetVariable('@')
    if type(resources) ~= 'string' or resources == '' or resources:find('[%z\1-\31\127"]') then return false end

    -- All arguments are fixed definitions or bounded numbers. Input output is
    -- never expanded into a command, option, variable name or file path.
    local arguments = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sScripts\\SettingsInput.ps1" -Key UtilityNumber -Minimum %d -Maximum %d -DecimalPlaces 0 -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        resources, field.minimum, field.maximum, current(key), x, y, width, height, scale)
    editingRequest = { key = key, saved = before[key:lower()], started = os.time(), revision = settingsRevision }
    SKIN:Bang('!SetOption', 'MeasureMediaSettingsInput', 'Parameter', arguments)
    SKIN:Bang('!UpdateMeasure', 'MeasureMediaSettingsInput')
    SKIN:Bang('!CommandMeasure', 'MeasureMediaSettingsInput', 'Run')
    -- RunCommand resets its numeric status on Run. Refresh that status so stale
    -- stdout cannot masquerade as a completed request while this one is open.
    SKIN:Bang('!UpdateMeasure', 'MeasureMediaSettingsInput')
    return true
end

function CommitNumberInput()
    local request = editingRequest
    if not request then return false end
    local measure = SKIN:GetMeasure('MeasureMediaSettingsInput')
    if measure and measure:GetValue() == 0 then return false end
    editingRequest = nil
    if not measure or measure:GetValue() ~= 1 then return false end
    local result = measure:GetStringValue()
    if type(result) ~= 'string' or #result > 128 then return false end
    if result:sub(-2) == '\r\n' then result = result:sub(1, -3)
    elseif result:sub(-1) == '\n' then result = result:sub(1, -2) end
    if result == 'PARALLAX_INPUT_V1|cancel|' then return false end
    local value = result:match('^PARALLAX_INPUT_V1|ok|([1-9]%d*)$')
    if not accepted(request.key, value) then return false end
    local now = os.time()
    if now < request.started or now - request.started > 300 or settingsRevision ~= request.revision then return false end
    local before = readValues()
    if not before or before[request.key:lower()] ~= request.saved then return false end
    values = before
    if request.key == 'QueueRowLimit' and current('QueueExpanded') ~= '1' then return false end
    return save(request.key, value)
end

local providerControls = {
    Source = { measure = 'MeasureMediaSourceControl', script = 'SourceProvider.ps1', actions = { Start=true, Stop=true } },
    Queue = { measure = 'MeasureMediaQueueControl', script = 'QueueProvider.ps1', actions = { Start=true, Stop=true, Restart=true, Disconnect=true } }
}

function ProviderControl(scope, action)
    local spec = providerControls[scope]
    local measure = spec and spec.actions[action] and SKIN:GetMeasure(spec.measure) or nil
    if not measure then return false end
    SKIN:Bang('!UpdateMeasure', spec.measure)
    if providerLaunched[spec.measure] and measure:GetValue() == 0 then
        status = scope .. ' command already running.'
        Render()
        return false
    end
    providerLaunched[spec.measure] = nil
    local arguments = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
        .. spec.script .. '" -Command "' .. action .. '"'
    if scope == 'Queue' and (action == 'Start' or action == 'Restart') then
        arguments = arguments .. ' -PollSeconds "' .. current('QueuePollSeconds') .. '"'
    end
    arguments = arguments .. ' -Quiet'
    SKIN:Bang('!SetOption', spec.measure, 'Parameter', arguments)
    SKIN:Bang('!UpdateMeasure', spec.measure)
    SKIN:Bang('!CommandMeasure', spec.measure, 'Run')
    providerLaunched[spec.measure] = true
    status = scope .. ' ' .. action:lower() .. ' requested.'
    Render()
    return true
end

-- Compatibility callbacks retain the same bounded numeric behavior. The
-- settings UI uses explicit arrows and the numeric overlay instead.
function ToggleColumns() return StepNumber('Columns', 1) end
function ToggleQueueExpanded() return cycle('QueueExpanded') end
function CycleQueueRows() return StepNumber('QueueRowLimit', 1) end
function ToggleQueueDetails() return cycle('QueueShowDetails') end
function CycleQueuePoll() return StepNumber('QueuePollSeconds', 1) end
