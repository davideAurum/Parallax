-- Original independent Disk Meter settings controller, Lua 5.1.
-- Reads cached native drive types; only explicit refresh requests update them.
-- Drive models use the bundled helper only at load or explicit user actions.
-- No polling or free-form action interpolation.
-- Only explicit controls persist known values to the module's User include.
local state, Names
local defaults = {
    IODiskQuota = '0', IODiskUnits = 'bytes', IODiskMaxMiBs = '500',
    IODiskDrives = 'C', IOGraphMode = 'combined', IODriveNames = 'volume'
}
local limits = { 10, 50, 100, 250, 500, 1000, 2000, 5000 }
local graphModes = { 'c', 'combined', 'overlay', 'split' }
local graphLabels = { c = 'C: only', combined = 'Combined', overlay = 'Overlay', split = 'Split + / -' }
local nameModes = { 'letters', 'volume', 'model', 'both' }
local nameLabels = { letters = 'Letters only', volume = 'Volume labels', model = 'Drive models', both = 'Both' }
local driveTypes = {
    [3] = 'Detected removable drive. Empty or inaccessible media is unavailable.',
    [4] = 'Detected fixed drive. Transfer counters can still be unavailable.',
    [5] = 'Detected network drive. Capacity needs access; local transfer counters may be unavailable.',
    [6] = 'Detected optical drive. Native CD/DVD capacity is unsupported; transfer counters may be unavailable.',
    [7] = 'Detected RAM drive. Transfer counters may be unavailable.'
}

local function canonicalDrives(value)
    if value == 'all' or value == 'none' then return value end
    if type(value) ~= 'string' or value == '' then return nil end
    local previous, letters = '', {}
    for letter in (value .. ','):gmatch('(.-),') do
        if not letter:match('^[A-Z]$') or letter <= previous then return nil end
        letters[#letters + 1], previous = letter, letter
    end
    local canonical = table.concat(letters, ',')
    return canonical == value and canonical or nil
end

local function inventory()
    local detected = {}
    for code = string.byte('A'), string.byte('Z') do
        local letter = string.char(code)
        local measure = SKIN:GetMeasure('MeasureIOType' .. letter)
        if measure then
            local ok, value = pcall(function() return measure:GetValue() end)
            if ok and driveTypes[value] then detected[letter] = value end
        end
    end
    return detected
end

local function selectedDrives(detected)
    local selection = canonicalDrives(state.IODiskDrives) or defaults.IODiskDrives
    local selected = {}
    if selection == 'all' then
        for letter in pairs(detected) do selected[letter] = true end
    elseif selection ~= 'none' then
        for letter in selection:gmatch('[A-Z]') do selected[letter] = true end
    end
    return selected, selection
end

local function namesMode()
    return nameLabels[state.IODriveNames] and state.IODriveNames or defaults.IODriveNames
end

local function serializeDrives(selected)
    local letters = {}
    for code = string.byte('A'), string.byte('Z') do
        local letter = string.char(code)
        if selected[letter] then letters[#letters + 1] = letter end
    end
    return #letters > 0 and table.concat(letters, ',') or 'none', #letters
end

local function safe(value)
    return (tostring(value or ''):gsub('[%c#%[%]]', ' '))
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function geometryNumber(key, fallback)
    local raw = SKIN:GetVariable(key, tostring(fallback))
    local value = tonumber(raw)
    if not value and type(raw) == 'string' and raw ~= '' then
        local ok, parsed = pcall(function()
            return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(raw) .. ')')
        end)
        if ok then value = parsed end
    end
    return finite(value) and value or fallback
end

local function text(meter, value)
    SKIN:Bang('!SetOption', meter, 'Text', safe(value))
end

local function tip(meter, value)
    SKIN:Bang('!SetOption', meter, 'ToolTipText', safe(value))
end

local function position(meter, logicalY, scale, inset)
    SKIN:Bang('!SetOption', meter, 'Y', string.format('%.6f', inset + logicalY * scale))
end

local function layout(detected, selected)
    local scale = geometryNumber('Scale', 1)
    local inset = geometryNumber('Inset', 0)
    local gap = geometryNumber('Gap', 0)
    scale = scale > 0 and scale or 1
    inset = math.max(0, inset)
    gap = math.max(0, gap)
    local cursor = 184
    for code = string.byte('A'), string.byte('Z') do
        local letter = string.char(code)
        local base = 'MeterIOSettingsDrive' .. letter
        local visible = detected[letter] ~= nil or selected[letter] == true
        for _, suffix in ipairs({ 'Label', '' }) do
            local meter = base .. suffix
            SKIN:Bang('!SetOption', meter, 'Hidden', visible and '0' or '1')
            if visible then
                position(meter, cursor + (suffix == 'Label' and 2 or 0), scale, inset)
            else
                SKIN:Bang('!SetOption', meter, 'Y', '0')
            end
        end
        if visible then cursor = cursor + 28 end
    end
    position('MeterIOSettingsGraphSection', cursor + 4, scale, inset)
    position('MeterIOSettingsGraphRule', cursor + 24, scale, inset)
    for index, control in ipairs({ 'Graph', 'Units', 'Limit' }) do
        local base = 'MeterIOSettings' .. control
        local fieldY = cursor + 32 + (index - 1) * 28
        position(base .. 'Label', fieldY + 2, scale, inset)
        position(base .. 'Frame', fieldY, scale, inset)
        for _, part in ipairs({ 'Decrease', 'Value', 'Increase' }) do
            position(base .. part, fieldY + 1, scale, inset)
        end
    end
    position('MeterIOSettingsCapacitySection', cursor + 120, scale, inset)
    position('MeterIOSettingsCapacityRule', cursor + 140, scale, inset)
    -- Only an explicit saved none hides the readouts. Empty/disconnected
    -- inventory must retain setup controls, and the C: graph is independent.
    local quotaVisible = state.IODiskDrives ~= 'none'
    local collapsed = quotaVisible and 0 or 28
    for _, suffix in ipairs({ 'Label', 'Value' }) do
        local meter = 'MeterIOSettingsQuota' .. suffix
        SKIN:Bang('!SetOption', meter, 'Hidden', quotaVisible and '0' or '1')
        if quotaVisible then
            position(meter, cursor + (suffix == 'Label' and 150 or 148), scale, inset)
        else
            SKIN:Bang('!SetOption', meter, 'Y', '0')
        end
    end
    for _, meter in ipairs({ 'Open', 'EditFile', 'Reload' }) do
        position('MeterIOSettings' .. meter, cursor + 188 - collapsed, scale, inset)
    end
    position('MeterIOSettingsProviderHint', cursor + 214 - collapsed, scale, inset)
    position('MeterIOSettingsNotice', cursor + 236 - collapsed, scale, inset)
    position('MeterIOSettingsIndependence', cursor + 258 - collapsed, scale, inset)
    local panelHeight = math.floor((cursor + 282 - collapsed) * scale + .5)
    SKIN:Bang('!SetVariable', 'PanelHeightPx', tostring(panelHeight))
    SKIN:Bang('!SetOption', 'MeterBounds', 'H', tostring(panelHeight + gap))
    SKIN:Bang('!UpdateMeter', 'MeterBounds')
    SKIN:Bang('!UpdateMeter', 'MeterPanel')
end

local function onOff(value)
    return value == '1' and 'On' or value == '0' and 'Off' or 'Check'
end

local function render()
    if not state then return end
    local detected = inventory()
    local selected, selection = selectedDrives(detected)
    local chosen, count = serializeDrives(selected)
    text('MeterIOSettingsAllValue', selection == 'all' and 'On' or 'Off')
    text('MeterIOSettingsNamesValue', nameLabels[namesMode()])
    tip('MeterIOSettingsNamesValue', 'Choose drive letters, volume labels, physical drive models, or both names. '
        .. 'Model names are queried at load, when choosing a model mode, or with Refresh drives; unknown names remain explicit.')
    text('MeterIOSettingsDriveValue', selection == 'all' and ('All detected (' .. count .. ')')
        or count == 0 and 'None selected' or (count .. ' selected'))
    tip('MeterIOSettingsDriveValue', (canonicalDrives(state.IODiskDrives) and ''
        or 'Saved selection is invalid; using C: until changed. ')
        .. (selection == 'all' and 'All detected drive letters. Current selection: ' or 'Selected drive letters: ')
        .. chosen .. '. Drive letters do not cover volumes without letters.')
    for code = string.byte('A'), string.byte('Z') do
        local letter = string.char(code)
        local meter = 'MeterIOSettingsDrive' .. letter
        local name, nameDetail = Names.Format(SKIN, letter, namesMode())
        text(meter, selected[letter] and 'On' or 'Off')
        text(meter .. 'Label', letter .. ':' .. (name ~= '' and (' ' .. name) or ''))
        local detail = letter .. ': ' .. (selected[letter] and 'selected. ' or 'not selected. ')
            .. (driveTypes[detected[letter]] or 'Not detected or unavailable. You may select this letter for when it returns.')
            .. ' ' .. nameDetail .. ' Click to toggle this letter.'
        tip(meter, detail)
        tip(meter .. 'Label', detail)
    end
    local mode = graphLabels[state.IOGraphMode] and state.IOGraphMode or defaults.IOGraphMode
    text('MeterIOSettingsGraphValue', graphLabels[mode])
    tip('MeterIOSettingsGraphValue', 'One graph: C: only shows C: activity independently of the selected rows; '
        .. 'Combined sums selected drives; Overlay shows individual traces; Split + / - sums reads above zero and writes below zero. Center cycles forward; arrows go backward or forward.')
    text('MeterIOSettingsQuotaValue', onOff(state.IODiskQuota))
    text('MeterIOSettingsUnitsValue', state.IODiskUnits == 'bytes' and 'Bytes'
        or state.IODiskUnits == 'bits' and 'Bits' or 'Check')
    -- Compatibility storage and presets remain unchanged; only display units convert.
    local limit = tonumber(state.IODiskMaxMiBs)
    local capMBs = finite(limit) and limit * 1.048576 or nil
    local validCap = finite(capMBs) and capMBs > 0
    local capText = 'Check'
    if validCap then
        capText = (capMBs < .0001 or capMBs > 1000000000) and string.format('%.6g', capMBs)
            or string.format('%.4f', capMBs):gsub('0+$', ''):gsub('%.$', '')
    end
    text('MeterIOSettingsLimitValue', capText)
    for _, arrow in ipairs({ { 'Decrease', -1, validCap and limit > limits[1] },
        { 'Increase', 1, validCap and limit < limits[#limits] } }) do
        local meter, enabled = 'MeterIOSettingsLimit' .. arrow[1], arrow[3]
        SKIN:Bang('!SetOption', meter, 'FontColor', SKIN:GetVariable(enabled and 'AccentColor' or 'MutedColor', '175,175,175'))
        SKIN:Bang('!SetOption', meter, 'MouseActionCursor', enabled and '1' or '0')
        SKIN:Bang('!SetOption', meter, 'LeftMouseUpAction', enabled
            and ('[!CommandMeasure MeasureIOSettings "CycleLimit(' .. arrow[2] .. ')"]') or '')
    end
    tip('MeterIOSettingsLimitValue', validCap
        and string.format('Automatic history scale cannot exceed this cap: %.9g MB/s, regardless of rate display units. Arrows choose adjacent presets without wrapping. %s', capMBs,
            capMBs >= .0001 and capMBs <= 1000000000
                and 'Click the center to enter 0.0001 to 1000000000 MB/s, up to four decimals.'
                or 'This saved cap is outside the numeric editor range; use Edit file to retain its precision or range.')
        or 'Graph cap unavailable. Use Edit file to correct the saved cap before using numeric controls.')
    text('MeterIOSettingsNotice', state.notice)
    layout(detected, selected)
    SKIN:Bang('!UpdateMeterGroup', 'IOSettingsUI')
    SKIN:Bang('!Redraw')
end

function Initialize()
    state = { userFile = SKIN:GetVariable('@') .. 'User\\IO.inc',
        notice = 'Changes save immediately; only Disk Meter refreshes.' }
    for key, value in pairs(defaults) do
        state[key] = SKIN:GetVariable(key, value)
    end
    Names = dofile(SKIN:GetVariable('@') .. 'Modules\\IO\\Names.lua')
    Names.Query(SKIN, namesMode())
end

function Update()
    render()
    return 0
end

-- Validation is applied to outgoing preset values, never to unrelated saved
-- custom settings. Opening the utility cannot silently rewrite the user's file.
local function valid(key, value)
    if not defaults[key] or type(value) ~= 'string' then return false end
    if key == 'IODiskQuota' then return value == '0' or value == '1' end
    if key == 'IODiskUnits' then return value == 'bytes' or value == 'bits' end
    if key == 'IODiskDrives' then return canonicalDrives(value) ~= nil end
    if key == 'IOGraphMode' then return graphLabels[value] ~= nil end
    if key == 'IODriveNames' then return nameLabels[value] ~= nil end
    if key == 'IODiskMaxMiBs' then
        local limit = tonumber(value)
        return finite(limit) and limit > 0
    end
    return false
end

local function save(changes)
    if not state then return false end
    local namesOnly = true
    for key, value in pairs(changes) do
        if not valid(key, value) then return false end
        if key ~= 'IODriveNames' then namesOnly = false end
    end
    local changed = false
    for key, value in pairs(changes) do
        if state[key] ~= value then
            changed = true
            state[key] = value
            SKIN:Bang('!SetVariable', key, value)
            SKIN:Bang('!WriteKeyValue', 'Variables', key, value, state.userFile)
        end
    end
    if changed then
        if namesOnly then
            SKIN:Bang('!SetVariableGroup', 'IODriveNames', state.IODriveNames, 'ParallaxIO')
            SKIN:Bang('!CommandMeasure', 'MeasureIO', 'ApplyNamesMode()', 'Parallax\\IO')
            state.notice = 'Saved. Drive names update without resetting history.'
        else
            SKIN:Bang('!RefreshGroup', 'ParallaxIO')
            state.notice = 'Saved. Disk Meter reads these choices when loaded.'
        end
        render()
    end
    return changed
end

function Toggle(key)
    if not state or key ~= 'IODiskQuota' then return false end
    return save({ [key] = state[key] == '1' and '0' or '1' })
end

local function directionOrDefault(direction)
    if direction == nil then return 1 end
    return (direction == -1 or direction == 1) and direction or nil
end

function CycleUnits(direction)
    if not state or not directionOrDefault(direction) then return false end
    return save({ IODiskUnits = state.IODiskUnits == 'bytes' and 'bits' or 'bytes' })
end

function SelectAllDrives()
    if not state then return false end
    return save({ IODiskDrives = 'all' })
end

function ToggleAllDrives()
    if not state then return false end
    return save({ IODiskDrives = state.IODiskDrives == 'all' and 'none' or 'all' })
end

function SelectCDrive()
    if not state then return false end
    return save({ IODiskDrives = 'C' })
end

function ToggleDrive(letter)
    if not state or type(letter) ~= 'string' or not letter:match('^[A-Z]$') then return false end
    -- In all mode, a manual edit freezes the currently detected set first.
    local selected = selectedDrives(inventory())
    selected[letter] = not selected[letter]
    return save({ IODiskDrives = serializeDrives(selected) })
end

function CycleGraphMode(direction)
    direction = directionOrDefault(direction)
    if not state or not direction then return false end
    local current = graphLabels[state.IOGraphMode] and state.IOGraphMode or defaults.IOGraphMode
    for index, mode in ipairs(graphModes) do
        if mode == current then return save({ IOGraphMode = graphModes[(index - 1 + direction) % #graphModes + 1] }) end
    end
end

function CycleNamesMode(direction)
    direction = directionOrDefault(direction)
    if not state or not direction then return false end
    local current = namesMode()
    for index, mode in ipairs(nameModes) do
        if mode == current then
            local nextMode = nameModes[(index - 1 + direction) % #nameModes + 1]
            local changed = save({ IODriveNames = nextMode })
            if changed then Names.Query(SKIN, nextMode) end
            return changed
        end
    end
end

function NamesReady()
    if not state then return false end
    render()
    return true
end

function RefreshInventory()
    if not state then return false end
    SKIN:Bang('!UpdateMeasureGroup', 'IOInventory')
    Names.Query(SKIN, namesMode())
    SKIN:Bang('!CommandMeasure', 'MeasureIO', 'RefreshNamesInventory()', 'Parallax\\IO')
    state.notice = 'Drive list refreshed. Counter availability may differ.'
    render()
    return true
end

function CycleLimit(step)
    if not state or (step ~= -1 and step ~= 1) then return false end
    local current = tonumber(state.IODiskMaxMiBs)
    if not finite(current) or current <= 0 then return false end
    if step == 1 then
        for _, limit in ipairs(limits) do
            if limit > current then return save({ IODiskMaxMiBs = tostring(limit) }) end
        end
        return false
    end
    for index = #limits, 1, -1 do
        if limits[index] < current then return save({ IODiskMaxMiBs = tostring(limits[index]) }) end
    end
    return false
end

function BeginLimitInput()
    if not state or state.editingCap then return false end
    local meter = SKIN:GetMeter('MeterIOSettingsLimitFrame')
    if not meter then return false end
    local current = tonumber(state.IODiskMaxMiBs)
    local displayed = finite(current) and current > 0 and current * 1.048576 or nil
    if not finite(displayed) then displayed = nil end
    if not displayed or displayed < .0001 or displayed > 1000000000 then
        state.notice = 'This saved cap is outside the numeric editor range. Use Edit file to retain or correct its saved value.'
        render()
        return false
    end
    local initial = string.format('%.4f', displayed):gsub(',', '.')
    local scale = math.max(.75, math.min(2, geometryNumber('Scale', 1)))
    local x, y = SKIN:GetX() + meter:GetX(), SKIN:GetY() + meter:GetY()
    local width, height = meter:GetW(), meter:GetH()
    if not finite(x) or not finite(y) or not finite(width) or not finite(height) or width <= 0 or height <= 0
        or x < -100000 or x > 100000 or y < -100000 or y > 100000 then return false end
    state.editingCap = { saved = state.IODiskMaxMiBs,
        displayed = initial }
    -- All command arguments are fixed paths or canonical numeric values. User
    -- input returns only through stdout and is validated below as data.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "SettingsInput.ps1" -Key UtilityNumber -Minimum 0.0001 -Maximum 1000000000 -DecimalPlaces 4 -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        initial, math.floor(x), math.floor(y), math.max(24, math.min(2048, math.floor(width))),
        math.max(12, math.min(512, math.floor(height))), scale)
    SKIN:Bang('!SetOption', 'MeasureIOSettingsNumberInput', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureIOSettingsNumberInput')
    SKIN:Bang('!CommandMeasure', 'MeasureIOSettingsNumberInput', 'Run')
    return true
end

function FinishLimitInput()
    if not state or not state.editingCap then return false end
    local pending = state.editingCap
    state.editingCap = nil
    if state.IODiskMaxMiBs ~= pending.saved then return false end
    local ok, output = pcall(function()
        local measure = SKIN:GetMeasure('MeasureIOSettingsNumberInput')
        return measure and measure:GetStringValue() or ''
    end)
    if not ok or type(output) ~= 'string' or #output > 80 then return false end
    output = output:gsub('[\r\n]+$', '')
    local raw = output:match('^PARALLAX_INPUT_V1|ok|(.+)$')
    if not raw or not (raw:match('^%d+$') or raw:match('^%d+%.%d%d?%d?%d?$')) then return false end
    local value = tonumber(raw)
    if not finite(value) or value < .0001 or value > 1000000000 then return false end
    if pending.displayed and value == tonumber(pending.displayed) then return false end
    local stored = value / 1.048576
    if not finite(stored) or stored <= 0 then return false end
    return save({ IODiskMaxMiBs = string.format('%.17g', stored):gsub(',', '.') })
end

function Open()
    if not state then return false end
    SKIN:Bang('!ActivateConfig', 'Parallax\\IO', 'IO-Disk.ini')
    state.notice = 'Disk Meter requested; counter freshness unknown.'
    render()
    return true
end

function Apply()
    if not state then return false end
    SKIN:Bang('!RefreshGroup', 'ParallaxIO')
    SKIN:Bang('!Refresh')
    return true
end

function Close()
    if not state then return false end
    SKIN:Bang('!DeactivateConfig')
    return true
end
