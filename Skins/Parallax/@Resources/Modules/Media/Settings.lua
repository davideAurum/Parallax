-- Original Parallax Media settings. Fixed controls write on explicit clicks only.
-- Rainmeter performs the individual key updates so unrelated settings and the
-- original file encoding remain intact. This controller never starts a helper.
local settingsPath, values, status, restartPending
local defaults = { Columns = '1', QueueExpanded = '0', QueueRowLimit = '5', QueueShowDetails = '1', QueuePollSeconds = '30' }
local allowed = {
    Columns = { '1', '2' }, QueueExpanded = { '0', '1' },
    QueueRowLimit = { '1', '3', '5' }, QueueShowDetails = { '0', '1' },
    QueuePollSeconds = { '30', '60', '120' }
}
local managed = {}
for key in pairs(defaults) do managed[key:lower()] = true end

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function accepted(key, value)
    for _, candidate in ipairs(allowed[key] or {}) do
        if value == candidate then return candidate end
    end
    return nil
end
local function option(meter, value)
    SKIN:Bang('!SetOption', meter, 'Text', tostring(value))
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
    -- Advanced saved values may use every supported integer, while buttons
    -- continue to write only the small set of fixed presets above.
    if key == 'QueueRowLimit' or key == 'QueuePollSeconds' then
        local number = value:match('^%d+$') and tonumber(value)
        local low, high = key == 'QueueRowLimit' and 1 or 30, key == 'QueueRowLimit' and 5 or 150
        if number and number >= low and number <= high and number == math.floor(number) then
            return tostring(number)
        end
        return defaults[key]
    end
    return accepted(key, value) or defaults[key]
end

function Render()
    option('MeterWidthValue', current('Columns') == '2' and '2 columns' or '1 column')
    option('MeterQueueExpandedValue', current('QueueExpanded') == '1' and 'Expanded' or 'Collapsed')
    local rows = current('QueueRowLimit')
    option('MeterQueueRowsValue', rows .. (rows == '1' and ' item' or ' items'))
    option('MeterQueueDetailsValue', current('QueueShowDetails') == '1' and 'Shown' or 'Hidden')
    option('MeterQueuePollValue', current('QueuePollSeconds') .. ' seconds')
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
    status = values and 'Changes save when clicked.' or 'Cannot read Media settings.'
end
function Update() Render(); return 0 end

local function save(key, value)
    if not accepted(key, value) then return false end
    local before = readValues()
    if not before then status = 'Cannot read Media settings.'; Render(); return false end
    values = before
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

function ToggleColumns() return cycle('Columns') end
function ToggleQueueExpanded() return cycle('QueueExpanded') end
function CycleQueueRows() return cycle('QueueRowLimit') end
function ToggleQueueDetails() return cycle('QueueShowDetails') end
function CycleQueuePoll() return cycle('QueuePollSeconds') end
