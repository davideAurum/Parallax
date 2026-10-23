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
local cover = 'MeterRAMHistoryUncollected'

local function show(name, visible)
    SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', name)
end

-- MeasureRAMHistorySamples retires the startup cover once the plot is full:
-- it hides the zero-width cover and sets its UpdateDivider to -1 until the
-- next refresh. A retired cover stays hidden when history is shown again.
local function coverRetired()
    local meter = SKIN:GetMeter(cover)
    return meter ~= nil and tonumber(meter:GetOption('UpdateDivider', '1')) == -1
end

local function option(key, spec)
    local value = tonumber(SKIN:GetVariable(key))
    if not value or value ~= value or value == math.huge or value == -math.huge then value=spec.default end
    return math.max(0, math.min(spec.count-1, math.floor(value)))
end

function Initialize() values = {} end

-- While the idle stand-down has this skin paused (Global Settings Idle pause;
-- @Resources\Idle\StandDown.lua shows MeterParallaxPaused in the title row),
-- the headline percentage stays hidden: a hover-out must not show the frozen
-- value. The gear follows the hover as usual, and the hook restores the
-- percentage from the gear on resume.
local function idlePaused()
    local line = SKIN:GetMeter('MeterParallaxPaused')
    return line ~= nil and line:GetOption('Hidden', '1') == '0'
end

function Hover(inside)
    local hovered = tonumber(inside) == 1
    show('MeterRAMOptions', hovered)
    show('MeterRAMPercent', not hovered and not idlePaused())
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
                local visible = (unit == 'MiB') == (values.RAMUseMiB == 1)
                show(name, visible)
                SKIN:Bang('!SetOption', name, 'NumOfDecimals', tostring(values.RAMDecimals))
                -- Only the shown unit samples every update; the hidden one idles
                -- instead of re-reading its dynamic options each second. The
                -- forced update below applies the divider and draws current values.
                SKIN:Bang('!SetOption', name, 'UpdateDivider', visible and '1' or '-1')
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
        local retired = values.RAMShowHistory == 1 and coverRetired()
        for _, name in ipairs(historyMeters) do
            show(name, values.RAMShowHistory == 1 and not (name == cover and retired))
        end
    end
    -- Visibility bangs do not append samples. Never force-update the Line meter.
    SKIN:Bang('!Redraw')
end

function Update()
    ApplyPreferences()
    return 0
end

-- Idle stand-down (Global Settings Idle pause; @Resources\Idle\StandDown.lua).
-- While paused every repainting meter sits at UpdateDivider -1; on resume the
-- hook deletes that key (the skin default, 1, applies again) and calls
-- ReapplyDividers, which sets every divider this script and the history
-- retirement manage from the stored preferences, ignoring any cache: the
-- shown Used unit samples, the hidden one idles, and the restarted history
-- cover updates. The hook hides the title and headline percentage while
-- paused and restores them itself (ParallaxIdleHeadline and
-- ParallaxIdleHoverSwap in RAM.ini), so there is no RestoreHeadline here.
function ReapplyDividers()
    if values.RAMUseMiB ~= nil then
        for _, unit in ipairs({'GiB', 'MiB'}) do
            local visible = (unit == 'MiB') == (values.RAMUseMiB == 1)
            SKIN:Bang('!SetOption', 'MeterRAMUsed' .. unit, 'UpdateDivider', visible and '1' or '-1')
        end
    end
    SKIN:Bang('!SetOption', cover, 'UpdateDivider', '1')
end

-- The paused Line meter added no samples, but its ring buffer still holds the
-- pre-pause history. Restart the uncollected cover and its sample count, as a
-- refresh would, so only samples taken after the resume are shown: nothing is
-- joined across the pause. Runs before the hook's forced measure update, which
-- then counts the first new sample.
function IdleLeave()
    local samples = SKIN:GetMeasure('MeasureRAMHistorySamples')
    if not samples then return end
    local formula = samples:GetOption('Formula', '')
    SKIN:Bang('!SetOption', 'MeasureRAMHistorySamples', 'Formula', '0')
    SKIN:Bang('!SetOption', 'MeasureRAMHistorySamples', 'UpdateDivider', '1')
    SKIN:Bang('!UpdateMeasure', 'MeasureRAMHistorySamples')
    if formula ~= '' then SKIN:Bang('!SetOption', 'MeasureRAMHistorySamples', 'Formula', formula) end
    show(cover, tonumber(values.RAMShowHistory or SKIN:GetVariable('RAMShowHistory')) == 1)
end
