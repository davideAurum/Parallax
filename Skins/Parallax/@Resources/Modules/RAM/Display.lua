-- RAM meter presentation. Event-only: never refreshes or resamples telemetry.
local values
local choices = {
    RAMUseMiB = {default=0, count=2},
    RAMDecimals = {default=1, count=3},
    RAMPercentDecimals = {default=0, count=3},
    RAMShowBar = {default=1, count=2},
    RAMShowPageBar = {default=1, count=2},
    RAMShowHistory = {default=1, count=2}
}
local historyMeters = {'MeterRAMHistoryLabel', 'MeterRAMHistoryRange',
    'MeterRAMHistory', 'MeterRAMHistoryUncollected', 'MeterRAMHistoryFrame'}

local function show(name, visible)
    SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', name)
end

local function option(key, spec)
    local value = tonumber(SKIN:GetVariable(key))
    if not value or value ~= value or value == math.huge or value == -math.huge then value=spec.default end
    return math.max(0, math.min(spec.count-1, math.floor(value)))
end

function Initialize() values = {} end

function Hover(inside)
    local hovered = tonumber(inside) == 1
    show('MeterRAMOptions', hovered)
    show('MeterRAMPercent', not hovered)
    SKIN:Bang('!Redraw')
end

function ApplyPreferences()
    local changed = {}
    for key, spec in pairs(choices) do
        local value = option(key, spec)
        changed[key] = values[key] ~= value
        values[key] = value
        SKIN:Bang('!SetVariable', key, tostring(value))
    end
    if changed.RAMUseMiB or changed.RAMDecimals then
        -- Keep legacy section names and the saved unit key; displayed units
        -- and their meter divisors are decimal GB / MB.
        for _, kind in ipairs({'Used'}) do
            for _, unit in ipairs({'GiB','MiB'}) do
                local name = 'MeterRAM'..kind..unit
                show(name, (unit == 'MiB') == (values.RAMUseMiB == 1))
                SKIN:Bang('!SetOption', name, 'NumOfDecimals', tostring(values.RAMDecimals))
                SKIN:Bang('!UpdateMeter', name)
            end
        end
        SKIN:Bang('!CommandMeasure', 'MeasureRAMInfoView', 'Display()')
        SKIN:Bang('!CommandMeasure', 'MeasureRAMProcessView', 'Display()')
    end
    if changed.RAMUseMiB or changed.RAMDecimals or changed.RAMShowPageBar then
        SKIN:Bang('!CommandMeasure', 'MeasureRAMPageView', 'Display()')
    end
    if changed.RAMPercentDecimals then
        SKIN:Bang('!SetOption', 'MeterRAMPercent', 'NumOfDecimals', tostring(values.RAMPercentDecimals))
        SKIN:Bang('!UpdateMeter', 'MeterRAMPercent')
    end
    if changed.RAMShowBar then show('MeterRAMBar', values.RAMShowBar == 1) end
    if changed.RAMShowHistory then
        for _, name in ipairs(historyMeters) do show(name, values.RAMShowHistory == 1) end
    end
    -- Visibility bangs do not append samples. Never force-update the Line meter.
    SKIN:Bang('!Redraw')
end

function Update()
    ApplyPreferences()
    return 0
end
