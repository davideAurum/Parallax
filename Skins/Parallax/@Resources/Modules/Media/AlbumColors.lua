-- Original Parallax album colors (2026-11-19). Lua 5.1.
-- Turns Chameleon's samples of the current cover into a small palette and
-- applies it to fixed meter options, once per change: no DynamicVariables, no
-- refresh, nothing on the animation tick (measured about 2 ms per recolor).
-- What follows the cover and what keeps the theme is David's decision log:
-- docs/superpowers/specs/2026-11-19-media-queue-art-and-album-colors-design.md.
--
-- Follows the cover: title icon, progress fill, queue notch icon, a
-- left-to-right gradient on the song/artist/album text, the queue's artist
-- names, the open spectrum drawer's bars, and a tint (MediaAlbumTint %) on the
-- lighter gray surfaces: queue and spectrum sheets, progress track, panel
-- border, shuffle face when off. Keeps the theme: the black panel fill, the
-- transport buttons, the metadata icons and the queue's song titles.
--
-- The option templates below mirror the ini they replace (Header.inc,
-- PlayerMeters.inc, Common.inc); keep them in step.

local AlbumColors = {}

-- Tuning (decision C10).
local MIN_SATURATION = 0.18   -- at or above this a cover has color
-- A muted cover has color too (2026-11-24): one sample at least this saturated,
-- whose channels (0-255) also spread this far, because near black and near white
-- a gray can look saturated. Its text is lifted, or it would read as gray.
local MUTED_SATURATION = 0.10
local MUTED_CHROMA = 10
local MUTED_TEXT_SATURATION = 0.35
local MAIN_SATURATION = 0.20  -- Average must reach this to be the main color
local HUE_GAP = 25            -- degrees between the two text colors
local TEXT_LIGHTNESS = 0.68   -- floor for text on the black panel
local TEXT_LIGHTNESS_MAX = 0.88
local TEXT_SATURATION = 0.85  -- cap: fully saturated text glows
local MEDIA_LIGHTNESS = { 0.55, 0.75 }
local MEDIA_SATURATION = { 0.35, 0.85 }
local MAX_TINT = 30

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

-- 'RRGGBB' / 'RRGGBBAA' hex or 'r,g,b[,a]' decimal, as suite colors are written.
function AlbumColors.parse(raw)
    if type(raw) ~= 'string' then return nil end
    raw = raw:match('^%s*(.-)%s*$')
    local hex = raw:match('^#?(%x%x%x%x%x%x)%x?%x?$')
    if hex then
        return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
    end
    local r, g, b = raw:match('^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if r and g and b and r <= 255 and g <= 255 and b <= 255 then return { r, g, b } end
    return nil
end

function AlbumColors.toHsl(c)
    local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local l = (high + low) / 2
    if high == low then return 0, 0, l end
    local d = high - low
    local s = l > 0.5 and d / (2 - high - low) or d / (high + low)
    local h
    if high == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif high == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    return h * 60, s, l
end

function AlbumColors.fromHsl(h, s, l)
    h = (h % 360) / 360
    if s == 0 then
        local v = math.floor(l * 255 + 0.5)
        return { v, v, v }
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    local function channel(t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        local v
        if t < 1 / 6 then v = p + (q - p) * 6 * t
        elseif t < 1 / 2 then v = q
        elseif t < 2 / 3 then v = p + (q - p) * (2 / 3 - t) * 6
        else v = p end
        return math.floor(clamp(v, 0, 1) * 255 + 0.5)
    end
    return { channel(h + 1 / 3), channel(h), channel(h - 1 / 3) }
end

local function hueDistance(a, b)
    local d = math.abs(a - b) % 360
    return d > 180 and 360 - d or d
end

-- Palette from Chameleon's Light1, Light2 and Average, or nil when the cover
-- has no usable color (missing, grayscale, plugin absent): the theme then.
function AlbumColors.palette(light1, light2, average)
    local candidates = {}
    for _, raw in ipairs({ light1, light2, average }) do
        local color = AlbumColors.parse(raw)
        if color then
            local h, s, l = AlbumColors.toHsl(color)
            candidates[#candidates + 1] = { color = color, h = h, s = s, l = l,
                chroma = math.max(color[1], color[2], color[3]) - math.min(color[1], color[2], color[3]) }
        end
    end
    local avg = AlbumColors.parse(average) and candidates[#candidates] or nil
    table.sort(candidates, function(a, b) return a.s > b.s end)
    local function quiet(c) return c and c.s >= MUTED_SATURATION and c.chroma >= MUTED_CHROMA end
    local muted = not candidates[1] or candidates[1].s < MIN_SATURATION
    if muted then
        -- No strong color: the visibly tinted samples, strongest tint first.
        local tinted = {}
        for _, c in ipairs(candidates) do if quiet(c) then tinted[#tinted + 1] = c end end
        if not tinted[1] then return nil end
        table.sort(tinted, function(a, b) return a.chroma > b.chroma end)
        candidates = tinted
    end
    local first = candidates[1]
    local strong = avg and avg.s >= MAIN_SATURATION
    local main = (strong or (muted and quiet(avg))) and avg or first
    local second
    for index = 2, #candidates do
        local c = candidates[index]
        if (muted or c.s >= MIN_SATURATION) and hueDistance(c.h, first.h) >= HUE_GAP then second = c; break end
    end
    local function text(c, hueShift)
        local s = muted and math.max(c.s, MUTED_TEXT_SATURATION) or c.s
        return AlbumColors.fromHsl(c.h + (hueShift or 0), math.min(s, TEXT_SATURATION),
            clamp(c.l, TEXT_LIGHTNESS, TEXT_LIGHTNESS_MAX))
    end
    local a, b = text(first), second and text(second) or text(first, 30)
    -- The gradient starts on the lighter color, as in the approved mockup F
    -- (gold to coral, mint to cyan).
    local _, _, la = AlbumColors.toHsl(a)
    local _, _, lb = AlbumColors.toHsl(b)
    if lb > la then a, b = b, a end
    return {
        main = main.color,
        media = AlbumColors.fromHsl(main.h, clamp(main.s, MEDIA_SATURATION[1], MEDIA_SATURATION[2]),
            clamp(main.l, MEDIA_LIGHTNESS[1], MEDIA_LIGHTNESS[2])),
        text1 = a,
        text2 = b
    }
end

-- Lean a theme gray toward the cover's main color by percent, keeping alpha.
function AlbumColors.tint(base, main, percent)
    local t = clamp(percent or 0, 0, MAX_TINT) / 100
    local out = {}
    for index = 1, 3 do out[index] = math.floor(base[index] + (main[index] - base[index]) * t + 0.5) end
    return out
end

local function rgb(c) return c[1] .. ',' .. c[2] .. ',' .. c[3] end
local function rgba(c, alpha) return rgb(c) .. ',' .. (alpha or 255) end

-- Option values for a palette (or the theme when palette is nil). Pure: the
-- tests check these strings; apply() only sends them.
function AlbumColors.options(theme, palette, tintPercent, fractions)
    local media = palette and rgb(palette.media) or theme.media
    local function gray(name)
        if not palette then return theme[name] end
        return rgb(AlbumColors.tint(theme.rgb[name], palette.main, tintPercent))
    end
    local border, sheet, track, off = gray('border'), gray('sheet'), gray('track'), gray('off')
    local options = {
        { 'MeterPlayerIcon', 'LucideAudioLinesStroke', 'Fill Color 0,0,0,0 | Stroke Color ' .. media ..
            ' | StrokeWidth (2*#MediaPlayerLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round' },
        { 'MeterProgress', 'BarColor', media },
        { 'MeterProgress', 'SolidColor', track },
        { 'MeterQueueToggle', 'MediaQueueToggleStroke', 'Stroke Color ' .. (palette and media or theme.header) ..
            ' | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | Offset (2*#Scale#),(2*#Scale#)' },
        { 'MeterQueueToggle', 'Shape6', 'Line (18*14*#Scale#/24),(9*14*#Scale#/24),(18*14*#Scale#/24),(15*14*#Scale#/24) | Stroke Color ' ..
            (palette and media or theme.header) .. ' | StrokeWidth (2*14*#Scale#/24*(1-#QueueExpanded#)) | StrokeStartCap Round | StrokeEndCap Round | Offset (2*#Scale#),(2*#Scale#)' },
        { 'MeterQueueDrawer', 'MediaSheetPaint', 'Fill Color ' .. sheet .. ' | Stroke Color ' .. border .. ' | StrokeWidth (#BorderThickness#*#Scale#)' },
        { 'MeterVisualizerSheet', 'Shape', 'Path MediaVisualizerSheetPath | Fill Color ' .. sheet .. ' | Stroke Color ' .. border .. ' | StrokeWidth (#BorderThickness#*#Scale#)' },
        { 'MeterPanel', 'MediaPanelPaint', 'Fill Color ' .. theme.background .. ' | Stroke Color ' .. border .. ' | StrokeWidth (#BorderThickness#*#Scale#)' },
    }
    for _, line in ipairs({ { 'MeterTrackTitle', 'title' }, { 'MeterArtist', 'artist' }, { 'MeterAlbum', 'album' } }) do
        local value = 'Color | ' .. theme.text
        if palette then
            -- Angle 180 runs left to right (measured); the gradient ends where
            -- the words end, so a short title still shows both colors.
            local stop = clamp((fractions and fractions[line[2]]) or 1, 0.05, 1)
            value = string.format('GradientColor | 180 | %s ; 0.0 | %s ; %.4f', rgba(palette.text1), rgba(palette.text2), stop)
        end
        options[#options + 1] = { line[1], 'InlineSetting', value }
    end
    -- The queue's artist names, and that word in its heading, take the text
    -- gradient's first (lighter) color. A Normal row's artist is a meter of its
    -- own; a Compact row accents the tail of its one line.
    local artist = palette and rgb(palette.text1) or theme.artist
    for index = 1, 5 do
        options[#options + 1] = { 'MeterQueueArtist' .. index, 'FontColor', artist }
        options[#options + 1] = { 'MeterQueueRow' .. index, 'InlineSetting', 'Color | ' .. artist }
    end
    options[#options + 1] = { 'MeterQueueHeaderTrack', 'InlineSetting', 'Color | ' .. artist }
    -- Media.lua reads these two variables when it repaints the shuffle/repeat
    -- faces, so the off face and ring follow without touching Media.lua.
    local variables = { { 'MediaTransportToggleOffFill', off }, { 'BorderColor', border } }
    local spectrum = palette and ('180 | ' .. rgba(palette.text1) .. ' ; 0 | ' .. rgba(palette.text2) .. ' ; 1') or nil
    return options, variables, spectrum
end

function AlbumColors.new(env)
    local self = { skin = env.skin, applied = {}, last = nil, settle = 0 }
    local tint = tonumber(env.tint)
    self.tint = (tint and tint == tint) and clamp(math.floor(tint), 0, MAX_TINT) or 10
    local function variable(name, fallback) return self.skin:GetVariable(name, fallback) end
    local theme = {
        media = variable('MediaColor', '137,190,250'), header = variable('HeaderTextColor', '175,175,175'),
        text = variable('TextColor', '220,220,220'), background = variable('BackgroundColor', '15,15,15,255'),
        border = variable('BorderColor', '50,50,50,255'), sheet = variable('MediaQueueDrawerFill', '45,45,45,255'),
        track = variable('TrackColor', '50,50,50,255'), off = variable('MediaTransportToggleOffFill', '25,25,25,255'),
        artist = variable('MediaQueueArtistColor', '181,161,226'),
    }
    theme.rgb = {}
    for _, name in ipairs({ 'border', 'sheet', 'track', 'off' }) do
        theme.rgb[name] = AlbumColors.parse(theme[name]) or { 50, 50, 50 }
    end
    self.theme = theme

    local function value(name)
        local measure = self.skin:GetMeasure(name)
        return measure and (measure:GetStringValue() or '') or ''
    end
    local function width(probe, target)
        local p, t = self.skin:GetMeter(probe), self.skin:GetMeter(target)
        if not p or not t then return 1 end
        self.skin:Bang('!UpdateMeter', probe)
        local box = t:GetW()
        if not box or box <= 0 then return 1 end
        return (p:GetW() or box) / box
    end

    function self:apply(palette)
        local fractions = palette and {
            title = width('MeterAlbumMeasureTitle', 'MeterTrackTitle'),
            artist = width('MeterAlbumMeasureArtist', 'MeterArtist'),
            album = width('MeterAlbumMeasureAlbum', 'MeterAlbum'),
        } or nil
        local options, variables, spectrum = AlbumColors.options(self.theme, palette, self.tint, fractions)
        local touched, order = {}, {}
        for _, o in ipairs(options) do
            local key = o[1] .. ':' .. o[2]
            if self.applied[key] ~= o[3] and self.skin:GetMeter(o[1]) then
                self.applied[key] = o[3]
                self.skin:Bang('!SetOption', o[1], o[2], o[3])
                if not touched[o[1]] then touched[o[1]] = true; order[#order + 1] = o[1] end
            end
        end
        for _, v in ipairs(variables) do
            if self.applied['var:' .. v[1]] ~= v[2] then
                self.applied['var:' .. v[1]] = v[2]
                self.skin:Bang('!SetVariable', v[1], v[2])
            end
        end
        if self.skin:GetMeter('MeterVisualizerFill') then
            if spectrum then
                self.skin:Bang('!SetOption', 'MeterVisualizerFill', 'SpectrumGradient', spectrum)
                self.skin:Bang('!SetOption', 'MeterVisualizerFill', 'Shape',
                    'Rectangle 0,0,#VisualizerPlotInnerWidth#,#VisualizerBarHeight# | Fill LinearGradient SpectrumGradient | StrokeWidth 0')
                order[#order + 1] = 'MeterVisualizerFill'
            elseif self.applied.spectrum then
                -- Back to the Audio settings palette.
                self.skin:Bang('!CommandMeasure', 'MeasureVisualizerColor', 'Apply(false)')
            end
            self.applied.spectrum = spectrum ~= nil
        end
        -- Every meter here is static (UpdateDivider=-1) or would wait for its
        -- next due update; force each once and paint once.
        for _, name in ipairs(order) do self.skin:Bang('!UpdateMeter', name) end
        if #order > 0 then self.skin:Bang('!Redraw') end
        return #order
    end

    function self:update()
        local track = value('MeasureTitle'):find('%S') ~= nil and value('MeasureCover'):find('%S') ~= nil
        local key = track and table.concat({ value('MeasureAlbumLight1'), value('MeasureAlbumLight2'),
            value('MeasureAlbumAverage'), value('MeasureTitle'), value('MeasureArtist'), value('MeasureAlbum') }, '|') or ''
        -- The spectrum drawer's own palette script runs once after a load; apply
        -- again a few updates in so the cover's colors win over it.
        self.settle = self.settle + 1
        if key == self.last and self.settle ~= 3 then return 0 end
        if self.settle == 3 then self.applied = { spectrum = self.applied.spectrum } end
        self.last = key
        local palette = track and AlbumColors.palette(value('MeasureAlbumLight1'), value('MeasureAlbumLight2'),
            value('MeasureAlbumAverage')) or nil
        self:apply(palette)
        return palette and 1 or 0
    end
    return self
end

local active
function Initialize()
    active = AlbumColors.new({ skin = SKIN, tint = SELF:GetOption('Tint', '10') })
end
function Update()
    if not active then Initialize() end
    return active:update()
end

return AlbumColors
