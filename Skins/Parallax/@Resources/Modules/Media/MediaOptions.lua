-- Media accordion. Only the explicit toggle writes a fixed scalar preference.
local settingsPath, expanded

local function readExpanded()
    local file = io.open(settingsPath, 'rb')
    if not file then return nil end
    local contents = file:read(262145)
    file:close()
    if not contents or #contents > 262144 then return nil end
    local bom = contents:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        if #contents % 2 ~= 0 then return nil end
        local ascii, little = {}, bom == '\255\254'
        for at = 3, #contents, 2 do
            local a, b = contents:byte(at, at+1)
            local code = little and a+256*b or b+256*a
            ascii[#ascii+1] = code < 128 and string.char(code) or '?'
        end
        contents = table.concat(ascii)
    else
        contents = contents:gsub('^\239\187\191', '')
    end
    local inVariables, value, seen = false, '0', false
    for line in (contents .. '\n'):gmatch('([^\r\n]*)[\r\n]+') do
        local section = line:match('^%s*%[([^%]]+)%]%s*$')
        if section then inVariables = section:lower() == 'variables'
        elseif inVariables then
            local key, scalar = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            if key and key:lower() == 'queueexpanded' then
                if seen then return nil end
                value, seen = scalar, true
            end
        end
    end
    return value == '1' and '1' or '0'
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Media.inc'
    expanded = SKIN:GetVariable('QueueExpanded', '0') == '1'
end

function Update() return expanded and 'Queue -' or 'Queue +' end

function ToggleQueue()
    local before = readExpanded()
    if not before then
        SKIN:Bang('!SetOption', 'MeterQueueStatus', 'ToolTipText', 'Cannot read Media settings. Check file access.')
        return false
    end
    local value = before == '1' and '0' or '1'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'QueueExpanded', value, settingsPath)
    if readExpanded() ~= value then
        SKIN:Bang('!SetOption', 'MeterQueueStatus', 'ToolTipText', 'Could not save the queue display preference.')
        return false
    end
    -- Keep an already-open settings panel in sync with a footer toggle.
    SKIN:Bang('!Refresh', 'Parallax\\Media\\Settings')
    SKIN:Bang('!Refresh')
    return true
end
