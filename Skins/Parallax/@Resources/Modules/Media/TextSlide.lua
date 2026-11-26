-- Original Parallax sliding text gradient (2026-11-25). Lua 5.1.
-- Album colors "On + slide" (User\Media.inc MediaAlbumColors=2): while a track
-- plays, the cover's two-color gradient on the song/artist/album text moves
-- left to right and loops. AlbumColors.lua stays the owner of the colors: it
-- sends them here (Set) or says there are none (Clear), and writes the still
-- gradient itself. This script only overwrites that one option while moving.
--
-- The colors run first -> second -> first, so the loop has no seam, and the
-- starting frame is the still gradient. Paint on change, as MediaPulse.lua: at
-- rest the three meters keep their provider-cadence divider and a tick here
-- does no work; moving raises them to one update per frame with no redraw bang.

local TextSlide = {}

local ROWS = { 'MeterTrackTitle', 'MeterArtist', 'MeterAlbum' }
local PERIOD = 8000 -- one loop, in milliseconds

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function channels(text)
    local r, g, b = tostring(text or ''):match('^(%d+),(%d+),(%d+)$')
    if not r then return nil end
    return { tonumber(r), tonumber(g), tonumber(b) }
end

-- Share of the second color at box position u (0..1), for words ending at f.
local function share(u, f, phase)
    local t = (u / (2 * f) - phase) % 1
    return t < 0.5 and 2 * t or 2 - 2 * t
end

-- The InlineSetting value for one line: first and second are {r,g,b}, f is
-- where its words end in the meter box, phase is 0..1 through one loop. Only
-- the stops over the words are written; past f there is no text.
function TextSlide.gradient(first, second, f, phase)
    local function mix(t)
        local c = {}
        for i = 1, 3 do c[i] = math.floor(first[i] + (second[i] - first[i]) * t + 0.5) end
        return c[1] .. ',' .. c[2] .. ',' .. c[3] .. ',255'
    end
    local stops = { 'GradientColor | 180', mix(share(0, f, phase)) .. ' ; 0.0' }
    -- The colors turn at u = 2f(phase + k/2): even k first, odd k second.
    local k = math.floor(-2 * phase) + 1
    while true do
        local u = 2 * f * (phase + k / 2)
        if u >= f - 0.0005 then break end
        if u > 0.0005 then
            stops[#stops + 1] = mix(k % 2 == 0 and 0 or 1) .. string.format(' ; %.4f', u)
        end
        k = k + 1
    end
    stops[#stops + 1] = mix(share(f, f, phase)) .. string.format(' ; %.4f', f)
    return table.concat(stops, ' | ')
end

-- env: skin; ticks (skin ticks per frame, 0 never moves); interval (ms per
-- tick); rest (the meters' divider while still).
function TextSlide.new(env)
    local self = { skin = env.skin, palette = nil, moving = false, frame = 0, placed = false }
    local ticks = finite(env.ticks) and env.ticks > 0 and math.floor(env.ticks) or 0
    local step = ticks > 0 and (env.interval * ticks) / PERIOD or 0
    local rest = tostring(env.rest)

    local function number(name)
        local measure = self.skin:GetMeasure(name)
        return measure and tonumber(measure:GetValue())
    end

    -- MediaPulse.lua's test, so the text and the title icon move together.
    local function playing()
        local title = self.skin:GetMeasure('MeasureTitle')
        local text = title and title:GetStringValue()
        return number('MeasureConnection') == 1 and number('MeasureState') == 1
            and type(text) == 'string' and text:find('%S') ~= nil
    end

    -- Once per load, as MediaPulse.lua does for the title icon: write the long
    -- position formulas back as numbers, so each frame's re-read stays small.
    local function place()
        for _, name in ipairs(ROWS) do
            local meter = self.skin:GetMeter(name)
            for _, key in ipairs({ 'X', 'Y', 'W', 'H' }) do
                local text = meter and meter:GetOption(key, '') or ''
                if text ~= '' and not text:find('[#%[]') then
                    local value = self.skin:ParseFormula('(' .. text .. ')')
                    -- A failed formula returns 0; every box here is inside the panel.
                    if finite(value) and value > 0 then
                        self.skin:Bang('!SetOption', name, key, string.format('(%.10g)', value))
                    end
                end
            end
        end
    end

    local function write(phase)
        local p = self.palette
        for index, name in ipairs(ROWS) do
            self.skin:Bang('!SetOption', name, 'InlineSetting',
                TextSlide.gradient(p.first, p.second, p.fractions[index], phase))
        end
    end

    local function divider(value)
        for _, name in ipairs(ROWS) do self.skin:Bang('!SetOption', name, 'UpdateDivider', value) end
    end

    local function force()
        for _, name in ipairs(ROWS) do self.skin:Bang('!UpdateMeter', name) end
    end

    -- Colors as 'r,g,b' and each line's word end (0..1). AlbumColors.lua calls
    -- this after writing its still gradient and before it paints, so a repeat
    -- apply puts the current frame back instead of flashing the start.
    function self:set(first, second, title, artist, album)
        local a, b = channels(first), channels(second)
        if not a or not b then return self:clear() end
        local fractions = {}
        for index, value in ipairs({ title, artist, album }) do
            value = tonumber(value)
            fractions[index] = finite(value) and math.max(0.05, math.min(1, value)) or 1
        end
        local key = table.concat({ first, second, fractions[1], fractions[2], fractions[3] }, ';')
        -- New colors or words start again from the still gradient.
        if not self.palette or self.palette.key ~= key then self.frame = 0 end
        self.palette = { first = a, second = b, fractions = fractions, key = key }
        if self.moving then write((self.frame * step) % 1) end
    end

    -- No cover colors: AlbumColors.lua has written the theme's text color.
    function self:clear()
        self.palette = nil
        if self.moving then
            self.moving = false
            divider(rest)
            force()
        end
    end

    function self:update()
        local move = ticks > 0 and self.palette ~= nil and playing()
        if not move then
            if self.moving then
                -- Paused or stopped: settle on the still gradient.
                self.moving, self.frame = false, 0
                write(0)
                divider(rest)
                force()
                self.skin:Bang('!Redraw')
            end
            return 0
        end
        if not self.moving then
            self.moving = true
            if not self.placed then self.placed = true; place() end
            divider(tostring(ticks))
            write((self.frame * step) % 1)
            force()
            return 1
        end
        self.frame = self.frame + 1
        -- No redraw bang: the meters are due each frame and repaint themselves.
        write((self.frame * step) % 1)
        return 1
    end

    return self
end

local active
function Initialize()
    local function formula(name, fallback)
        local value = SKIN:ParseFormula(SKIN:ReplaceVariables('(#' .. name .. '#)'))
        return finite(value) and value > 0 and value or fallback
    end
    active = TextSlide.new({ skin = SKIN, ticks = formula('MediaTextSlideTicks', 0),
        interval = formula('MediaTickInterval', 50), rest = formula('MediaLegacyDivider', 1) })
end
function Set(first, second, title, artist, album)
    if active then active:set(first, second, title, artist, album) end
end
function Clear()
    if active then active:clear() end
end
function Update()
    if not active then Initialize() end
    return active:update()
end

return TextSlide
