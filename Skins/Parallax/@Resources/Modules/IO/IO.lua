-- Original Parallax presentation controller. Native measures own all telemetry.
-- No processes, filesystem writes, network requests, or fabricated samples.
local cache

local function variable(key, default)
    return SKIN:GetVariable(key, default)
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge
        and value ~= -math.huge
end

local function number(key)
    local measure = SKIN:GetMeasure(key)
    local value = measure and measure:GetValue() or nil
    if finite(value) then return value end
    return nil
end

-- Keep external labels as display text, never Rainmeter variable/action syntax.
local function safe(text)
    return tostring(text or ''):gsub('[%c#%[%]]', ' ')
end

local function option(meter, key, value)
    local id = meter .. ':' .. key
    value = tostring(value)
    if cache[id] ~= value then
        SKIN:Bang('!SetOption', meter, key, value)
        cache[id] = value
    end
end

local function text(meter, value)
    option(meter, 'Text', safe(value))
end

local function visible(meter, show)
    local id = meter .. ':visible'
    if cache[id] ~= show then
        SKIN:Bang(show and '!ShowMeter' or '!HideMeter', meter)
        cache[id] = show
    end
end

local function scaled(value, base, units)
    if not finite(value) or value < 0 then return '--' end
    local unit = 1
    while value >= base and unit < #units do
        value = value / base
        unit = unit + 1
    end
    return string.format('%.1f %s', value, units[unit])
end

local function bytes(value)
    return scaled(value, 1024, {'B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'})
end

local function diskRate(value)
    local units = variable('IODiskUnits', 'bytes'):lower()
    if units == 'bits' then
        return scaled(value * 8, 1000, {'bit/s', 'kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'})
    elseif units == 'bytes' then
        return bytes(value) .. '/s'
    end
    return 'Check IO units'
end

local function positiveSetting(key)
    local value = tonumber(variable(key, ''))
    return finite(value) and value > 0 and value or nil
end

local function capacity(index)
    local drive = variable('IODrive' .. index, '')
    local show = index == 1 or variable('IOShowDrive2', '0') == '1'
    local total = number('MeasureIOTotal' .. index)
    local free = number('MeasureIOFree' .. index)
    local kind = number('MeasureIOType' .. index)
    local valid = false
    local detail
    if not show then
        detail = 'Off'
    elseif kind == 6 then
        detail = 'Optical unsupported'
    elseif kind == 0 or kind == 1 then
        detail = 'Missing / unavailable'
    elseif kind == 3 and variable('IOIgnoreRemovable', '0') == '1' then
        detail = 'Removable ignored'
    elseif not finite(total) or not finite(free) or total <= 0 or free < 0 or free > total then
        detail = 'Unavailable'
    else
        valid = true
        detail = bytes(free) .. ' / ' .. bytes(total)
    end
    if index == 1 then
        local percent = valid and (100 * (1 - free / total)) or nil
        text('MeterIOTotal', percent and string.format('%.0f%%', percent) or '--')
        option('MeterIOTotal', 'ToolTipText', safe(valid
            and string.format('%s %.1f%% used', drive, percent)
            or (drive .. ' ' .. detail)))
    end
    text('MeterIODrive' .. index, drive ~= '' and drive or (tostring(index) .. ':'))
    text('MeterIOCapacity' .. index, detail)
    option('MeterIOCapacity' .. index, 'FontColor', valid
        and variable('TextColor', '220,220,220') or variable('MutedColor', '175,175,175'))
    option('MeterIOCapacity' .. index, 'ToolTipText', safe(drive .. ': ' .. detail .. (valid and ' (free / total)' or '')))
    visible('MeterIOUsed' .. index, valid)
    if valid then
        option('MeterIOUsed' .. index, 'ToolTipText', string.format('%.1f%% used', 100 * (1 - free / total)))
    end
end

local function disk()
    local enabled = SELF:GetNumberOption('DiskProvider', 0) == 1
    local category = variable('IODiskCategory', 'PhysicalDisk')
    local instance = variable('IODiskInstance', '_Total')
    local supported = category == 'PhysicalDisk' or category == 'LogicalDisk'
    local hasInstance = instance:match('%S') ~= nil
    local ceiling = positiveSetting('IODiskMaxMiBs')
    local havePositive = false
    for _, direction in ipairs({'Read', 'Write'}) do
        local value = enabled and supported and hasInstance and number('MeasureIODisk' .. direction) or nil
        local positive = finite(value) and value > 0
        havePositive = havePositive or positive
        text('MeterIODisk' .. direction, positive and diskRate(value) or '--')
        visible('MeterIODisk' .. direction .. 'Bar', positive and ceiling ~= nil)
        option('MeterIODisk' .. direction, 'ToolTipText',
            positive and (direction .. ': ' .. diskRate(value) .. '. Provider-reported; sample freshness is unknown.')
            or (direction .. ': no positive rate; idle, missing counter, unavailable provider, or initial sample.'))
    end
    local state = not enabled and 'Counters off'
        or not supported and 'Unsupported category'
        or not hasInstance and 'Check disk instance'
        or havePositive and 'Reported; age unknown'
        or 'Idle or unavailable'
    text('MeterIODiskHeading', enabled and (category .. ' / ' .. instance) or 'Disk transfers')
    option('MeterIODiskHeading', 'ToolTipText', safe(category .. ' / ' .. instance .. '. Independent of capacity drive selection.'))
    text('MeterIODiskStatus', state)
    option('MeterIODiskStatus', 'ToolTipText', safe(category .. ' / ' .. instance
        .. '. A zero cannot distinguish idle from missing. A nonzero value may be stale.'))
    text('MeterIODiskScale', enabled and ceiling
        and string.format('Read/write limit: %g MiB/s', ceiling)
        or enabled and 'Check graph limit' or 'Native capacity only')
    text('MeterIOToggle', enabled and 'Disable counters' or 'Enable counters')
    option('MeterIOToggle', 'LeftMouseUpAction', enabled
        and '[!ActivateConfig "Parallax\\IO" "IO.ini"]'
        or '[!ActivateConfig "Parallax\\IO" "IO-Disk.ini"]')
    option('MeterIOToggle', 'ToolTipText', enabled
        and 'Switch to IO.ini to remove this skin\'s disk category queries.'
        or 'Switch to IO-Disk.ini. Adds a UsageMonitor category worker; zeros and freshness are ambiguous.')
end

function Initialize()
    cache = {}
    local interval = tonumber(variable('CapacityInterval', '30000')) or 30000
    option('MeterIOCapacityHeading', 'ToolTipText', string.format(
        'Native capacity sampled every %d seconds. Bars show used percentage.',
        math.max(5, math.ceil(interval / 1000))))
end

function Update()
    capacity(1)
    capacity(2)
    disk()
    return 0
end
