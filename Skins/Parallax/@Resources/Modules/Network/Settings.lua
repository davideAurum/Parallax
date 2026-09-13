-- Original Network settings controller. File values are literal INI data, never code.
-- No telemetry, periodic polling, or writes until a persistent control is clicked.
local Core, userFile, resourceRoot, loadError, pendingInput
local MAX_FILE_BYTES, MAX_TOOLTIP_BYTES = 262144, 1024
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
local help = {
    NetworkInterface = 'Saved selector; adapter availability is not queried here. Click to edit Network.inc, save, then Apply.',
    NetworkUnits = 'Click the value or either arrow to toggle decimal bits/s and binary bytes/s. Refreshes Network only.',
    Columns = 'Click the value to enter 1 or 2 columns. Arrows move one column without wrapping.',
    PanelHeight = 'Click the value to enter a minimum height from 0.0001 to 1000000000 logical px, with up to 4 decimals. Arrows move 1 px without wrapping. The combined panel grows to fit its content. Custom formulas remain available through the file editor.',
    NetworkInCeilingMbps = 'Click the value to enter 0.0001 to 1000000000 Mbit/s, with up to 4 decimals. Arrows choose neighboring graph ceilings: 10, 25, 50, 100, 250, 500, 1000 Mbit/s without wrapping. This is not link speed.',
    NetworkOutCeilingMbps = 'Click the value to enter 0.0001 to 1000000000 Mbit/s, with up to 4 decimals. Arrows choose neighboring graph ceilings: 10, 25, 50, 100, 250, 500, 1000 Mbit/s without wrapping. This is not link speed.',
    NetworkWiFiEnabled = 'Click to toggle Wi-Fi queries in this module. This does not change the Windows radio.',
    NetworkWiFiInterface = 'Click the value to enter a whole WLAN index from 0 to 63. Arrows move one index without wrapping. It is separate from the Network adapter selector. The native provider may fall back to index 0 if the requested adapter does not exist.'
}

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function safe(value, limit)
    local text = Core and Core.safe(value) or tostring(value or ''):gsub('[%c#%[%]]', ' ')
    text = text:gsub('"', "'")
    if limit and #text > limit then
        local last = limit - 3
        while last > 0 and text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last = last - 1 end
        text = text:sub(1, last) .. '...'
    end
    return text
end
local function option(meter, key, value) SKIN:Bang('!SetOption', meter, key, safe(value, key == 'ToolTipText' and MAX_TOOLTIP_BYTES or nil)) end
local function redraw() SKIN:Bang('!UpdateMeter', '*'); SKIN:Bang('!Redraw') end
local function status(caption, detail, errorState)
    option('MeterNetworkSettingsStatus', 'Text', caption)
    option('MeterNetworkSettingsStatus', 'ToolTipText', detail or caption)
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
    if #data > MAX_FILE_BYTES then return nil, 'Network.inc exceeds the 256 KiB settings limit.' end
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
    status('Finish the open number editor.', 'Press Enter to apply or Esc to cancel before changing another setting.', false)
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
        local meter = 'MeterNetworkSettings' .. keys[key] .. 'Value'
        option(meter, 'Text', label)
        local detail = help[key]
        if numberRules[key] and not typedNumber(key, raw) then
            detail = 'Click the value or label to open Network.inc. This saved value cannot seed the numeric editor; it remains unchanged until you edit the file. '
                .. detail:gsub('Click the value to enter', 'Numeric entry supports')
        end
        detail = detail .. ' Saved ' .. key .. ' = ' .. (raw == nil and '(missing)' or raw)
        if not valid then detail = detail .. '. Invalid or missing saved value; it is preserved until you change it.' end
        option(meter, 'ToolTipText', detail)
        if numberRules[key] then
            option('MeterNetworkSettings' .. keys[key] .. 'Frame', 'ToolTipText', detail)
            option('MeterNetworkSettings' .. keys[key] .. 'Label', 'ToolTipText', detail)
        end
    end
    if errorText then status('Cannot read Network.inc.', errorText, true)
    elseif invalid > 0 then status('Check invalid or missing values.', 'Existing values are preserved. Click a control to replace that choice, or edit the file and Apply.', true)
    else status(caption or 'Changes save immediately. File edits need Apply.', nil, false) end
end
local function refreshView(caption)
    local values, err = readSaved(); render(values, err, caption); redraw(); return values
end
local function change(key, target, nextValue, expected)
    if inputBlocked() then return false end
    if not keys[key] or not configs[target] then status('Invalid settings action.', nil, true); redraw(); return false end
    local values, err = readSaved()
    if not values then render(nil, err); redraw(); return false end
    if expected and values[key] ~= expected.raw then
        render(values); status('Saved value changed; edit again.', 'The pending number was discarded because this saved setting changed while the editor was open.', true)
        redraw(); return false
    end
    local chosen = nextValue(values[key])
    local _, oldValid = display(key, values[key])
    if chosen == nil or chosen == values[key] or (numberRules[key] and oldValid and tonumber(chosen) == tonumber(values[key])) then
        render(values, nil, 'No change.'); redraw(); return false
    end
    local _, valid = display(key, chosen)
    if not valid or (numberRules[key] and not typedNumber(key, chosen)) then
        status('Invalid settings action.', 'The requested value was not saved.', true); redraw(); return false
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
    if panel ~= 'Network' then status('Invalid settings action.', nil, true); redraw(); return false end
    return AdjustNumber('Columns', 1)
end
function ToggleWiFi() return change('NetworkWiFiEnabled', 'Network', function(raw) return raw == '1' and '0' or '1' end) end
function CycleWiFiIndex() return AdjustNumber('NetworkWiFiInterface', 1) end
function CycleCeiling(direction)
    if direction ~= 'In' and direction ~= 'Out' then status('Invalid settings action.', nil, true); redraw(); return false end
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
        render(values); status('Enter a number or edit the file.', 'This saved value has no supported arrow starting point. It remains unchanged.', true)
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
        render(values); status('Edit this custom value in Network.inc.', 'The saved value cannot seed the numeric editor. Save your file edit, then Apply saved file.', false)
        redraw(); OpenFile(); return false
    end
    local meter = SKIN:GetMeter('MeterNetworkSettings' .. keys[key] .. 'Frame')
    local measure = SKIN:GetMeasure(INPUT_MEASURE)
    if not meter or not measure then
        status('Number editor unavailable.', 'The bundled numeric input measure or field anchor is missing. Edit Network.inc instead.', true)
        redraw(); return false
    end
    local initial = canonical(number, rule.decimals)
    local scale = tonumber(SKIN:GetVariable('Scale', '1'))
    scale = Core.finite(scale) and math.max(0.75, math.min(2, scale)) or 1
    local x, y, width, height = SKIN:GetX() + meter:GetX(), SKIN:GetY() + meter:GetY(), meter:GetW(), meter:GetH()
    for _, value in ipairs({x, y, width, height}) do
        if not Core.finite(value) then status('Number editor unavailable.', 'The field position is unavailable.', true); redraw(); return false end
    end
    -- Every argument is a fixed path, fixed range, or canonical number. Raw saved
    -- formulas and typed output never enter an executable command or bang string.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "SettingsInput.ps1" -Key UtilityNumber -Minimum %s -Maximum %s -DecimalPlaces %d -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        canonical(rule.minimum, rule.decimals), canonical(rule.maximum, rule.decimals), rule.decimals,
        initial, math.floor(x), math.floor(y), math.max(24, math.floor(width)), math.max(12, math.floor(height)), scale)
    pendingInput = {key = key, raw = values[key]}
    status('Enter to apply. Esc to cancel.', nil, false)
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
        status('Number was not applied.', 'The editor returned an invalid, out-of-range or over-precision result. Click the value to try again.', true)
        redraw(); return false
    end
    return change(pending.key, 'Network', function() return canonical(number, numberRules[pending.key].decimals) end, pending)
end
function OpenFile()
    if inputBlocked() then return false end
    if not userFile or userFile:find('[%c"]') or resourceRoot == '' then status('Cannot open Network.inc.', nil, true); redraw(); return end
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
    if not configs[panel] then status('Invalid navigation target.', nil, true); redraw(); return end
    SKIN:Bang('!ActivateConfig', configs[panel], 'Network.ini')
end
function Close() pendingInput = nil; SKIN:Bang('!DeactivateConfig') end
