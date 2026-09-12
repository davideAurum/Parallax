-- Original independent Drive I/O settings controller, Lua 5.1.
-- No telemetry, polling, helper processes or free-form action interpolation.
-- Only explicit controls persist known values to the module's User include.
local state
local defaults = {
    IODrive1 = 'C:', IODrive2 = 'D:', IOShowDrive2 = '0',
    IOIgnoreRemovable = '0', IODiskQuota = '0', IODiskUnits = 'bytes',
    IODiskCategory = 'PhysicalDisk', IODiskInstance = '_Total', IODiskMaxMiBs = '500'
}
local toggles = { IOShowDrive2 = true, IOIgnoreRemovable = true, IODiskQuota = true }
local limits = { 10, 50, 100, 250, 500, 1000, 2000, 5000 }

local function safe(value)
    return (tostring(value or ''):gsub('[%c#%[%]]', ' '))
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function driveLetter(value)
    if type(value) ~= 'string' then return nil end
    local letter = value:match('^([A-Za-z]):[/\\]?$')
    return letter and letter:upper() or nil
end

local function text(meter, value)
    SKIN:Bang('!SetOption', meter, 'Text', safe(value))
end

local function tip(meter, value)
    SKIN:Bang('!SetOption', meter, 'ToolTipText', safe(value))
end

local function onOff(value)
    return value == '1' and 'On' or value == '0' and 'Off' or 'Check'
end

local function render()
    if not state then return end
    for index = 1, 2 do
        local value = state['IODrive' .. index]
        local letter = driveLetter(value)
        text('MeterIOSettingsDrive' .. index .. 'Value', letter and (letter .. ':') or 'Custom')
        tip('MeterIOSettingsDrive' .. index .. 'Value', value .. '. Arrows choose A: to Z:. Edit file for custom roots.')
    end
    text('MeterIOSettingsSecondValue', onOff(state.IOShowDrive2))
    text('MeterIOSettingsRemovableValue', state.IOIgnoreRemovable == '1' and 'Ignore'
        or state.IOIgnoreRemovable == '0' and 'Include' or 'Check')
    text('MeterIOSettingsQuotaValue', onOff(state.IODiskQuota))
    text('MeterIOSettingsUnitsValue', state.IODiskUnits == 'bytes' and 'Bytes'
        or state.IODiskUnits == 'bits' and 'Bits' or 'Check')
    text('MeterIOSettingsCategoryValue', state.IODiskCategory == 'PhysicalDisk' and 'Physical'
        or state.IODiskCategory == 'LogicalDisk' and 'Logical' or 'Check')
    local limit = tonumber(state.IODiskMaxMiBs)
    text('MeterIOSettingsLimitValue', finite(limit) and limit > 0 and string.format('%g', limit) or 'Check')
    tip('MeterIOSettingsLimitValue', 'Fixed graph ceiling: ' .. state.IODiskMaxMiBs
        .. ' MiB/s per direction, regardless of rate display units. Arrows choose preset limits.')
    text('MeterIOSettingsInstanceValue', state.IODiskInstance:match('%S') and state.IODiskInstance or '(empty)')
    tip('MeterIOSettingsInstanceValue', state.IODiskCategory .. ' / ' .. state.IODiskInstance
        .. '. Exact Perfmon name; independent of capacity drives. Edit file for custom names.')
    text('MeterIOSettingsNotice', state.notice)
    SKIN:Bang('!UpdateMeterGroup', 'IOSettingsUI')
    SKIN:Bang('!Redraw')
end

function Initialize()
    state = { userFile = SKIN:GetVariable('@') .. 'User\\IO.inc',
        notice = 'Changes save immediately; only Drive I/O refreshes.' }
    for key, value in pairs(defaults) do
        state[key] = SKIN:GetVariable(key, value)
    end
end

function Update()
    render()
    return 0
end

-- Validation is applied to outgoing preset values, never to unrelated saved
-- custom settings. Opening the utility cannot silently rewrite the user's file.
local function valid(key, value)
    if not defaults[key] or type(value) ~= 'string' then return false end
    if toggles[key] then return value == '0' or value == '1' end
    if key == 'IODrive1' or key == 'IODrive2' then return value:match('^[A-Z]:$') ~= nil end
    if key == 'IODiskUnits' then return value == 'bytes' or value == 'bits' end
    if key == 'IODiskCategory' then return value == 'PhysicalDisk' or value == 'LogicalDisk' end
    if key == 'IODiskInstance' then return value == '_Total' or value:match('^[A-Z]:$') ~= nil end
    if key == 'IODiskMaxMiBs' then
        for _, limit in ipairs(limits) do if value == tostring(limit) then return true end end
    end
    return false
end

local function save(changes)
    if not state then return false end
    for key, value in pairs(changes) do if not valid(key, value) then return false end end
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
        SKIN:Bang('!RefreshGroup', 'ParallaxIO')
        state.notice = 'Saved. Drive I/O reads these choices when loaded.'
        render()
    end
    return changed
end

function Toggle(key)
    if not state or not toggles[key] then return false end
    return save({ [key] = state[key] == '1' and '0' or '1' })
end

function CycleDrive(index, step)
    if not state or (index ~= 1 and index ~= 2) or (step ~= -1 and step ~= 1) then return false end
    local key = 'IODrive' .. index
    local letter = driveLetter(state[key])
    local nextLetter = letter and string.char((letter:byte() - 65 + step) % 26 + 65)
        or (step == 1 and 'C' or 'Z')
    return save({ [key] = nextLetter .. ':' })
end

function CycleUnits()
    if not state then return false end
    return save({ IODiskUnits = state.IODiskUnits == 'bytes' and 'bits' or 'bytes' })
end

function CycleCategory()
    if not state then return false end
    return save({ IODiskCategory = state.IODiskCategory == 'PhysicalDisk' and 'LogicalDisk' or 'PhysicalDisk' })
end

function UseTotal()
    return save({ IODiskInstance = '_Total' })
end

function UseCapacityDrive(index)
    if not state or (index ~= 1 and index ~= 2) then return false end
    local letter = driveLetter(state['IODrive' .. index])
    if not letter then
        state.notice = 'Custom root: set an exact disk instance in Edit file.'
        render()
        return false
    end
    return save({ IODiskCategory = 'LogicalDisk', IODiskInstance = letter .. ':' })
end

function CycleLimit(step)
    if not state or (step ~= -1 and step ~= 1) then return false end
    local current = tonumber(state.IODiskMaxMiBs)
    if not finite(current) or current <= 0 then return save({ IODiskMaxMiBs = '500' }) end
    if step == 1 then
        for _, limit in ipairs(limits) do
            if limit > current then return save({ IODiskMaxMiBs = tostring(limit) }) end
        end
        return save({ IODiskMaxMiBs = tostring(limits[1]) })
    end
    for index = #limits, 1, -1 do
        if limits[index] < current then return save({ IODiskMaxMiBs = tostring(limits[index]) }) end
    end
    return save({ IODiskMaxMiBs = tostring(limits[#limits]) })
end

function Activate(mode)
    if not state or (mode ~= 'native' and mode ~= 'counters') then return false end
    SKIN:Bang('!ActivateConfig', 'Parallax\\IO', mode == 'native' and 'IO.ini' or 'IO-Disk.ini')
    state.notice = mode == 'native' and 'Native capacity requested; IO disk queries unloaded.'
        or 'Disk counters requested; independent 1 Hz worker.'
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
