-- Original Network settings controller. File values are literal INI data, never code.
-- No telemetry, periodic polling, or writes until a persistent control is clicked.
local Core, userFile, resourceRoot, loadError, pendingInput
local MAX_FILE_BYTES = 262144
local INPUT_MEASURE = 'MeasureNetworkSettingsInput'
local numberRules = {
    Columns = {minimum = 1, maximum = 2, decimals = 0},
    PanelHeight = {minimum = 0.0001, maximum = 1000000000, decimals = 4},
    NetworkInCeilingMbps = {minimum = 0.0001, maximum = 1000000000, decimals = 4, presets = true},
    NetworkOutCeilingMbps = {minimum = 0.0001, maximum = 1000000000, decimals = 4, presets = true},
    NetworkWiFiInterface = {minimum = 0, maximum = 63, decimals = 0}
}
local ceilingPresets = {10, 25, 50, 100, 250, 500, 1000}
local configs = {Network = 'Parallax\\Network'}
local keys = {
    NetworkInterface = 'Adapter', NetworkUnits = 'Units', Columns = 'Width', PanelHeight = 'Height',
    NetworkInCeilingMbps = 'InCeiling', NetworkOutCeilingMbps = 'OutCeiling',
    NetworkWiFiEnabled = 'WiFiEnabled', NetworkWiFiInterface = 'WiFiIndex'
}
local keyLookup = {}
for key in pairs(keys) do keyLookup[key:lower()] = key end
local order = {'NetworkInterface', 'NetworkUnits', 'Columns', 'PanelHeight', 'NetworkInCeilingMbps',
    'NetworkOutCeilingMbps', 'NetworkWiFiEnabled', 'NetworkWiFiInterface'}

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function safe(value)
    local text = Core and Core.safe(value) or tostring(value or ''):gsub('[%c#%[%]]', ' ')
    text = text:gsub('"', "'")
    return text
end
local function option(meter, key, value) SKIN:Bang('!SetOption', meter, key, safe(value)) end
local function redraw() SKIN:Bang('!UpdateMeter', '*'); SKIN:Bang('!Redraw') end
local function status(caption, errorState)
    option('MeterNetworkSettingsStatus', 'Text', caption)
    option('MeterNetworkSettingsStatus', 'FontColor', SKIN:GetVariable(errorState and 'WarningColor' or 'TextColor', '220,220,220'))
end
local function utf8(code)
    if code < 128 then return string.char(code) end
    if code < 2048 then return string.char(192 + math.floor(code / 64), 128 + code % 64) end
    if code < 65536 then return string.char(224 + math.floor(code / 4096), 128 + math.floor(code / 64) % 64, 128 + code % 64) end
    return string.char(240 + math.floor(code / 262144), 128 + math.floor(code / 4096) % 64,
        128 + math.floor(code / 64) % 64, 128 + code % 64)
end
local function decode(data)
    local bom = data:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        if #data % 2 ~= 0 then return nil, 'Malformed UTF-16 settings file.' end
        local parts, pos = {}, 3
        local function unit(index)
            local a, b = data:byte(index, index + 1)
            return bom == '\255\254' and a + b * 256 or a * 256 + b
        end
        while pos <= #data do
            local code = unit(pos); pos = pos + 2
            if code >= 55296 and code <= 56319 then
                if pos > #data then return nil, 'Malformed UTF-16 settings file.' end
                local low = unit(pos); pos = pos + 2
                if low < 56320 or low > 57343 then return nil, 'Malformed UTF-16 settings file.' end
                code = 65536 + (code - 55296) * 1024 + low - 56320
            elseif code >= 56320 and code <= 57343 then return nil, 'Malformed UTF-16 settings file.' end
            if code == 0 then return nil, 'Settings file contains a NUL character.' end
            parts[#parts + 1] = utf8(code)
        end
        return table.concat(parts)
    end
    if data:find('\0', 1, true) then return nil, 'Settings file contains a NUL character.' end
    return data:gsub('^\239\187\191', '')
end
local function readSaved()
    if loadError then return nil, loadError end
    local file = io.open(userFile, 'rb')
    if not file then return nil, 'Cannot read Network.inc. Open the file to check its path and access.' end
    local data = file:read(MAX_FILE_BYTES + 1)
    local closed = file:close()
    if not data or not closed then return nil, 'Could not read Network.inc completely.' end
    if #data > MAX_FILE_BYTES then return nil, 'Network.inc exceeds the 262,144-byte settings limit.' end
    local text, decodeError = decode(data)
    if not text then return nil, decodeError end
    local values, inVariables, foundVariables = {}, false, false
    for line in (text .. '\n'):gmatch('(.-)\n') do
        line = line:gsub('\r$', '')
        local section = line:match('^%s*%[([^%]]+)%]%s*$')
        if section then
            inVariables = trim(section):lower() == 'variables'
            if inVariables then
                if foundVariables then return nil, 'Duplicate Variables sections. Edit Network.inc to remove ambiguity.' end
                foundVariables = true
            end
        elseif inVariables and not line:match('^%s*;') then
            local rawKey, value = line:match('^%s*([^=]+)=(.*)$')
            local key = rawKey and keyLookup[trim(rawKey):lower()]
            if key then
                if values[key] ~= nil then return nil, 'Duplicate setting: ' .. key .. '. Edit Network.inc to remove ambiguity.' end
                values[key] = trim(value)
            end
        end
    end
    if not foundVariables then return nil, 'Network.inc has no Variables section.' end
    return values
end
local function index(raw, minimum, maximum)
    local value = type(raw) == 'string' and raw:match('^%d+$') and tonumber(raw)
    return Core.finite(value) and value >= minimum and value <= maximum and value == math.floor(value) and value or nil
end
local function canonical(number, decimals)
    if number == 0 then return '0' end
    local text = string.format('%.' .. decimals .. 'f', number)
    return decimals > 0 and text:gsub('0+$', ''):gsub('%.$', '') or text
end
local function typedNumber(key, raw)
    local rule = numberRules[key]
    if not rule or type(raw) ~= 'string' or #raw > 64 then return nil end
    local fraction = raw:match('^[+-]?%d+%.(%d+)$')
    if not raw:match('^[+-]?%d+$') and (not fraction or #fraction > rule.decimals) then return nil end
    local number = tonumber(raw)
    if not Core.finite(number) or number < rule.minimum or number > rule.maximum then return nil end
    return number
end
local function inputBlocked()
    if not pendingInput then return false end
    status('Finish the open number editor.', false)
    redraw(); return true
end
local function display(key, raw)
    if raw == nil then return 'Missing', false end
    if key == 'NetworkInterface' then
        local numeric = tonumber(raw)
        local valid = raw ~= '' and (not numeric or index(raw, 1, 2147483647) ~= nil)
        return valid and raw or 'Invalid', valid
    elseif key == 'NetworkUnits' then
        local valid = raw == 'bits' or raw == 'bytes'
        return valid and raw or 'Invalid', valid
    elseif key == 'Columns' then
        local valid = raw == '1' or raw == '2'
        return valid and raw or 'Invalid', valid
    elseif key == 'NetworkWiFiEnabled' then
        local valid = raw == '0' or raw == '1'
        return valid and (raw == '1' and 'On' or 'Off') or 'Invalid', valid
    elseif key == 'NetworkWiFiInterface' then
        local valid = index(raw, 0, 63) ~= nil
        return valid and raw or 'Invalid', valid
    elseif key == 'NetworkInCeilingMbps' or key == 'NetworkOutCeilingMbps' then
        local valid = Core.ceiling(raw) ~= nil
        return valid and raw or 'Invalid', valid
    else
        local number = tonumber(raw)
        if number then
            local valid = Core.finite(number) and number > 0
            return valid and raw or 'Invalid', valid
        end
        -- Rainmeter accepts formulas for geometry. Keep them literal and unassessed here.
        return raw ~= '' and 'Custom' or 'Invalid', raw ~= ''
    end
end
local function render(values, errorText, caption)
    local invalid = 0
    for _, key in ipairs(order) do
        local raw = values and values[key]
        local label, valid = display(key, raw)
        if not valid then invalid = invalid + 1 end
        option('MeterNetworkSettings' .. keys[key] .. 'Value', 'Text', label)
    end
    if errorText then status('Cannot read Network.inc.', true)
    elseif invalid > 0 then status('Check invalid or missing values.', true)
    else status(caption or 'Changes save immediately. File edits need Apply.', false) end
end
local function refreshView(caption)
    local values, err = readSaved(); render(values, err, caption); redraw(); return values
end
local function change(key, target, nextValue, expected)
    if inputBlocked() then return false end
    if not keys[key] or not configs[target] then status('Invalid settings action.', true); redraw(); return false end
    local values, err = readSaved()
    if not values then render(nil, err); redraw(); return false end
    if expected and values[key] ~= expected.raw then
        render(values); status('Saved value changed; edit again.', true)
        redraw(); return false
    end
    local chosen = nextValue(values[key])
    local _, oldValid = display(key, values[key])
    if chosen == nil or chosen == values[key] or (numberRules[key] and oldValid and tonumber(chosen) == tonumber(values[key])) then
        render(values, nil, 'No change.'); redraw(); return false
    end
    local _, valid = display(key, chosen)
    if not valid or (numberRules[key] and not typedNumber(key, chosen)) then
        status('Invalid settings action.', true); redraw(); return false
    end
    -- One allowlisted key only. Rainmeter preserves other keys, comments and sections.
    SKIN:Bang('!WriteKeyValue', 'Variables', key, chosen, userFile)
    local saved, readError = readSaved()
    if not saved or saved[key] ~= chosen then
        render(saved, readError or 'Could not verify the saved choice. Check Network.inc access before retrying.')
        redraw(); return false
    end
    render(saved, nil, 'Saved. Refresh requested.'); redraw()
    -- Named !Refresh never activates an unloaded skin; Rainmeter may log an inactive warning.
    SKIN:Bang('!Refresh', configs[target])
    return true
end

function Initialize()
    Core, loadError, pendingInput = nil, nil, nil
    resourceRoot = SKIN:GetVariable('@', '')
    userFile = resourceRoot .. 'User\\Network.inc'
    if resourceRoot == '' or userFile:find('[%c"]') then loadError = 'Invalid fixed Network settings path.'; return end
    local ok, module = pcall(dofile, resourceRoot .. 'Modules\\Network\\Core.lua')
    if ok then Core = module else loadError = 'Cannot load the bundled Network settings logic.' end
end
function Update() if not pendingInput then refreshView() end; return loadError and 0 or 1 end
function ToggleUnits() return change('NetworkUnits', 'Network', function(raw) return raw == 'bits' and 'bytes' or 'bits' end) end
function CycleUnits(direction)
    if direction ~= -1 and direction ~= 1 then return false end
    return ToggleUnits()
end
function ToggleWidth(panel)
    if panel ~= 'Network' then status('Invalid settings action.', true); redraw(); return false end
    return AdjustNumber('Columns', 1)
end
function ToggleWiFi() return change('NetworkWiFiEnabled', 'Network', function(raw) return raw == '1' and '0' or '1' end) end
function CycleWiFiIndex() return AdjustNumber('NetworkWiFiInterface', 1) end
function CycleCeiling(direction)
    if direction ~= 'In' and direction ~= 'Out' then status('Invalid settings action.', true); redraw(); return false end
    return AdjustNumber('Network' .. direction .. 'CeilingMbps', 1)
end
function AdjustNumber(key, direction)
    local rule = numberRules[key]
    if not rule or (direction ~= -1 and direction ~= 1) then return false end
    if inputBlocked() then return false end
    local values, err = readSaved()
    if not values then render(nil, err); redraw(); return false end
    local current = rule.presets and Core.ceiling(values[key]) or typedNumber(key, values[key])
    if rule.presets and current then current = current / 1000000 end
    if current == nil then
        render(values); status('Enter a number or edit the file.', true)
        redraw(); return false
    end
    local chosen
    if rule.presets then
        for _, preset in ipairs(ceilingPresets) do
            if direction == 1 and preset > current then chosen = preset; break end
            if direction == -1 and preset < current then chosen = preset end
        end
    else chosen = math.max(rule.minimum, math.min(rule.maximum, current + direction)) end
    return change(key, 'Network', function() return chosen and canonical(chosen, rule.decimals) end, {raw = values[key]})
end
function BeginNumberInput(key)
    local rule = numberRules[key]
    if not rule or inputBlocked() or loadError then return false end
    local values, err = readSaved()
    if not values then render(nil, err); redraw(); return false end
    local number = typedNumber(key, values[key])
    if not number then
        render(values); status('Edit this custom value in Network.inc.', false)
        redraw(); OpenFile(); return false
    end
    local meter = SKIN:GetMeter('MeterNetworkSettings' .. keys[key] .. 'Frame')
    local measure = SKIN:GetMeasure(INPUT_MEASURE)
    if not meter or not measure then
        status('Number editor unavailable.', true)
        redraw(); return false
    end
    local initial = canonical(number, rule.decimals)
    local scale = tonumber(SKIN:GetVariable('Scale', '1'))
    scale = Core.finite(scale) and math.max(0.75, math.min(2, scale)) or 1
    local x, y, width, height = SKIN:GetX() + meter:GetX(), SKIN:GetY() + meter:GetY(), meter:GetW(), meter:GetH()
    for _, value in ipairs({x, y, width, height}) do
        if not Core.finite(value) then status('Number editor unavailable.', true); redraw(); return false end
    end
    -- Every argument is a fixed path, fixed range, or canonical number. Raw saved
    -- formulas and typed output never enter an executable command or bang string.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "SettingsInput.ps1" -Key UtilityNumber -Minimum %s -Maximum %s -DecimalPlaces %d -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        canonical(rule.minimum, rule.decimals), canonical(rule.maximum, rule.decimals), rule.decimals,
        initial, math.floor(x), math.floor(y), math.max(24, math.floor(width)), math.max(12, math.floor(height)), scale)
    pendingInput = {key = key, raw = values[key]}
    status('Enter to apply. Esc to cancel.', false)
    redraw()
    SKIN:Bang('!SetOption', INPUT_MEASURE, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', INPUT_MEASURE)
    SKIN:Bang('!CommandMeasure', INPUT_MEASURE, 'Run')
    return true
end
function FinishNumberInput()
    if not pendingInput then return false end
    local pending = pendingInput
    pendingInput = nil
    local measure = SKIN:GetMeasure(INPUT_MEASURE)
    local output = measure and measure:GetStringValue() or ''
    if type(output) ~= 'string' or #output > 128 then output = '' end
    output = output:gsub('[\r\n]+$', '')
    if output == 'PARALLAX_INPUT_V1|cancel|' then refreshView('Number edit cancelled.'); return false end
    local raw = output:match('^PARALLAX_INPUT_V1|ok|([+-]?%d+%.?%d*)$')
    local number = typedNumber(pending.key, raw)
    if not number then
        status('Number was not applied.', true)
        redraw(); return false
    end
    return change(pending.key, 'Network', function() return canonical(number, numberRules[pending.key].decimals) end, pending)
end
function OpenFile()
    if inputBlocked() then return false end
    if not userFile or userFile:find('[%c"]') or resourceRoot == '' then status('Cannot open Network.inc.', true); redraw(); return end
    -- Lua's non-bang launch accepts one quoted command. Only this fixed resource path is used.
    SKIN:Bang('"notepad.exe" "' .. userFile .. '"')
end
function ApplyFile()
    if inputBlocked() then return false end
    if not refreshView('File reloaded. Refresh requested.') then return end
    SKIN:Bang('!Refresh', configs.Network)
    SKIN:Bang('!Refresh')
end
function OpenPanel(panel)
    if not configs[panel] then status('Invalid navigation target.', true); redraw(); return end
    SKIN:Bang('!ActivateConfig', configs[panel], 'Network.ini')
end
function Close() pendingInput = nil; SKIN:Bang('!DeactivateConfig') end
