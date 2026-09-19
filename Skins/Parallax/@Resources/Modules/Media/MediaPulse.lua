-- Time-driven pulse for the current-player icon. No file I/O, subprocesses,
-- timers or network; it only rewrites MeterPlayerIcon's bar geometry.
--
-- Deliberately separate from Media.lua: that adapter is a pure function of the
-- current provider sample, and its suite asserts an identical sample produces
-- no display work. This pulse changes every tick by design while a track
-- plays, so it cannot live behind the same contract.
local measures, applied, tick, step
-- MeterPlayerIcon's rest bars (Lucide audio-lines, 24-unit viewBox) as
-- key/x/center/half-height. Header.inc holds the same values statically.
local bars = {
    { key = 'Shape', x = 2, center = 11.5, half = 1.5 },
    { key = 'Shape2', x = 6, center = 11.5, half = 5.5 },
    { key = 'Shape3', x = 10, center = 12, half = 9 },
    { key = 'Shape4', x = 14, center = 11.5, half = 3.5 },
    { key = 'Shape5', x = 18, center = 11.5, half = 6.5 },
    { key = 'Shape6', x = 22, center = 11.5, half = 1.5 }
}
-- One full cycle in milliseconds, converted to a per-tick phase step so the
-- pulse keeps its period at whatever cadence the skin runs.
local period = 1100

function Initialize()
    measures, applied, tick = {}, {}, 0
    for _, name in ipairs({ 'MeasureConnection', 'MeasureState' }) do
        measures[name] = SKIN:GetMeasure(name)
    end
    local interval = tonumber(SKIN:GetVariable('MediaAnimationInterval')) or 50
    if interval <= 0 then interval = 50 end
    step = 2 * math.pi * interval / period
end

local function number(name)
    local measure = measures[name]
    local value = measure and tonumber(measure:GetValue())
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function shape(bar, half)
    return string.format('Line (%d*#MediaPlayerLucideScale#),(%.3f*#MediaPlayerLucideScale#),(%d*#MediaPlayerLucideScale#),(%.3f*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke',
        bar.x, bar.center - half, bar.x, bar.center + half)
end

function Update()
    local playing = number('MeasureConnection') == 1 and number('MeasureState') == 1
    tick = playing and (tick + 1) or 0
    for index, bar in ipairs(bars) do
        local half = bar.half
        if playing then
            -- The icon is only ~14px tall, so a shallow wave moves each bar a
            -- fraction of a pixel per frame and reads as a stutter. Swing over
            -- most of the bar's height, staggered so the pulse travels.
            local wave = 0.5 + 0.5 * math.sin(tick * step + (index - 1) * 0.7)
            -- Cap keeps the tallest bar's stroke inside the 24-unit viewBox.
            half = math.min(bar.half * (0.3 + 0.9 * wave), bar.center - 1.2)
        end
        local value = shape(bar, half)
        -- No redraw bang: MeterPlayerIcon runs at UpdateDivider=1, so the
        -- normal skin cycle repaints it, as periodic changes must.
        if applied[bar.key] ~= value then
            applied[bar.key] = value
            SKIN:Bang('!SetOption', 'MeterPlayerIcon', bar.key, value)
        end
    end
    return playing and 1 or 0
end
