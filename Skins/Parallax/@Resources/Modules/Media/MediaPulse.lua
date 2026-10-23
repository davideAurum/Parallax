-- Time-driven title icon. No file I/O, subprocesses, timers or network; it
-- only swaps the title icon and rewrites MeterPlayerIcon's bar geometry.
--
-- Deliberately separate from Media.lua: that adapter is a pure function of the
-- current provider sample, and its suite asserts an identical sample produces
-- no display work. This pulse changes every tick by design while a track
-- plays, so it cannot live behind the same contract.
--
-- Paint on change (docs/PERFORMANCE-REVIEW.md MEDIA-01): Rainmeter repaints
-- the whole window whenever any meter's divider elapses, so MeterPlayerIcon
-- rests at UpdateDivider=-1 and a tick with nothing playing does no work.
-- Playback raises it to every tick for the pulse; stopping settles the bars,
-- returns it to -1 and paints that last frame explicitly.
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
    for _, name in ipairs({ 'MeasureConnection', 'MeasureState', 'MeasureTitle' }) do
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

local function nonblank(name)
    local measure = measures[name]
    local value = measure and measure:GetStringValue()
    return type(value) == 'string' and value:find('%S') ~= nil
end

local function shape(bar, half)
    return string.format('Line (%d*#MediaPlayerLucideScale#),(%.3f*#MediaPlayerLucideScale#),(%d*#MediaPlayerLucideScale#),(%.3f*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke',
        bar.x, bar.center - half, bar.x, bar.center + half)
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- The shortest decimal that parses back to the same double, never in exponent
-- form (Rainmeter's formula parser does not read exponents); as SpectrumPaths.lua.
local function literal(value)
    if not finite(value) then return nil end
    if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format('%.0f', value) end
    for digits = 1, 17 do
        local text = string.format('%.' .. digits .. 'g', value)
        if not text:find('[eE]') and tonumber(text) == value then return text end
    end
    return nil
end

-- Once per load, as SpectrumPaths.lua does for the band paths: Media's
-- [Variables] are stored pre-expanded, so the shared icon box's X=#ContentX#
-- alone is about 4 KB of formula text, and every !SetOption that animates the
-- bars makes the meter re-read it (docs/PERFORMANCE-REVIEW.md MEDIA-03).
-- Evaluate the style's own X and Y once and write them back as literal
-- numbers, kept in parentheses so Rainmeter converts them exactly as it did
-- the formulas. If either fails to evaluate, the style's text stays; a failed
-- ParseFormula returns 0, and the icon box always lies inside the panel.
local function place()
    local icon = SKIN:GetMeter('MeterPlayerIcon')
    if not icon then return end
    for _, key in ipairs({ 'X', 'Y' }) do
        local text = icon:GetOption(key, '')
        local value = nil
        if type(text) == 'string' and text ~= '' and not text:find('[#%[]') then
            value = SKIN:ParseFormula('(' .. text .. ')')
        end
        local number = finite(value) and value > 0 and literal(value)
        if number then SKIN:Bang('!SetOption', 'MeterPlayerIcon', key, '(' .. number .. ')') end
    end
end

function Update()
    -- Playing means connected, reporting Playing (state 1) and holding a track.
    -- MediaHeader.lua applies the identical test to the title text, so the
    -- icon and "Media Player: <name>" always switch together.
    local playing = number('MeasureConnection') == 1 and number('MeasureState') == 1 and nonblank('MeasureTitle')
    -- Still not playing, and the rest frame is already applied: nothing to do.
    if applied.playing == false and not playing then return 0 end
    tick = playing and (tick + 1) or 0
    -- Exactly one title icon is visible. The first tick applies this
    -- unconditionally, so it never depends on the ini defaults agreeing.
    local first = applied.playing == nil
    local transition = applied.playing ~= playing
    -- The load tick's forced update reads the literal box with everything else.
    if first then place() end
    if transition then
        applied.playing = playing
        SKIN:Bang(playing and '!ShowMeter' or '!HideMeter', 'MeterPlayerIcon')
        SKIN:Bang(playing and '!HideMeter' or '!ShowMeter', 'MeterMediaIcon')
    end
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
        -- No redraw bang while playing: MeterPlayerIcon then runs at
        -- UpdateDivider=1, so the normal skin cycle repaints it, as periodic
        -- changes must.
        if applied[bar.key] ~= value then
            applied[bar.key] = value
            SKIN:Bang('!SetOption', 'MeterPlayerIcon', bar.key, value)
        end
    end
    if transition then
        -- Measures update before meters, so the bars and the divider set
        -- here reach the icon together. A -1 meter ignores !SetOption until it
        -- is forced, hence the explicit update. The first tick after a load
        -- updates every meter and repaints anyway, and a redraw from here
        -- would paint meters that have not had their first update yet.
        SKIN:Bang('!SetOption', 'MeterPlayerIcon', 'UpdateDivider', playing and '1' or '-1')
        if not first then
            SKIN:Bang('!UpdateMeter', 'MeterPlayerIcon')
            -- Back at -1, nothing else is due to repaint the settled icon or
            -- the swap back to Monitor Play; while playing, the icon's own
            -- update repaints this tick.
            if not playing then SKIN:Bang('!Redraw') end
        end
    end
    return playing and 1 or 0
end
