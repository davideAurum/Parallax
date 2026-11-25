-- Fits a tall settings panel to the screen it is on and scrolls the rest
-- (PanelScroll.inc; docs/UTILITY-SETTINGS.md, "Tall panels"). Rainmeter is not
-- DPI aware, so Windows scaling divides the screen first: a 1080p screen is a
-- 816 px work area at 125% and 672 px at 150%, less than several panels need.
--
-- The panel keeps its designed height (PanelHeight) where the work area has room
-- for it. Where it has not, the window ends at the work area, the title row stays
-- and the rest scrolls. Event driven: a load, the pointer entering the panel, a
-- controller that changed PanelHeight, the wheel, or an arrow.
local ROW = 28          -- logical px, the settings row pitch
local EDGE = 4          -- logical px kept free above the panel's bottom border
local MONITORS = 8
local scale, offset, limit, view = 1, 0, 0, 0
local drawn
local memory

local function number(text)
    return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(text) .. ')')
end

local function literal(text) return tonumber(SKIN:ReplaceVariables(text)) end

-- The work area height of the screen that holds the panel's center, which is the
-- screen Keep on screen holds it to; the primary one when it is on none.
local function workHeight()
    local x, y = SKIN:GetX() + SKIN:GetW() / 2, SKIN:GetY() + SKIN:GetH() / 2
    for n = 1, MONITORS do
        local left, top = literal('#SCREENAREAX@' .. n .. '#'), literal('#SCREENAREAY@' .. n .. '#')
        local width, height = literal('#SCREENAREAWIDTH@' .. n .. '#'), literal('#SCREENAREAHEIGHT@' .. n .. '#')
        if not (left and top and width and height) then break end
        if x >= left and x < left + width and y >= top and y < top + height then
            return literal('#WORKAREAHEIGHT@' .. n .. '#')
        end
    end
    return literal('#WORKAREAHEIGHT#')
end

local function set(name, value) SKIN:Bang('!SetVariable', name, tostring(value)) end

-- Sets every variable the panel's window and PanelScroll.inc read. quiet: the
-- caller updates the meters and redraws.
function Fit(quiet)
    scale = number('#Scale#')
    local gap, inset = number('#Gap#'), number('#Inset#')
    local top = math.floor(inset + number('#PanelScrollTop#') * scale + 0.5)
    local full = math.floor(number('#PanelHeight#') * scale + 0.5)
    -- A work area too short even for a few rows is left to overflow.
    local least = top + 4 * ROW * scale
    local shown = math.floor(math.min(full, math.max((workHeight() or math.huge) - gap, least)))
    view = math.floor(inset + shown - EDGE * scale) - top
    limit = full - shown
    offset = math.max(0, math.min(limit, math.floor(offset + 0.5)))
    local thumb = math.max(math.min(ROW * scale, view), math.floor(view * view / (view + limit) + 0.5))
    local thumbY = top + (limit > 0 and math.floor((view - thumb) * offset / limit + 0.5) or 0)
    local accent, muted = SKIN:GetVariable('AccentColor'), SKIN:GetVariable('MutedColor')
    set('PanelHeightPx', shown)
    set('WindowHeight', shown + gap)
    set('PanelScrollY', offset)
    set('PanelScrollTopPx', top)
    set('PanelScrollView', view)
    set('PanelScrollHidden', limit > 0 and 0 or 1)
    set('PanelScrollThumbY', thumbY)
    set('PanelScrollThumbH', thumb)
    set('PanelScrollUpColor', offset > 0 and accent or muted)
    set('PanelScrollDownColor', offset < limit and accent or muted)
    local state = table.concat({ shown, top, view, limit, offset }, ' ')
    if state == drawn then return false end
    drawn = state
    if quiet then return true end
    SKIN:Bang('!UpdateMeter', 'MeterBounds')
    SKIN:Bang('!UpdateMeter', 'MeterPanel')
    SKIN:Bang('!UpdateMeterGroup', 'PanelScroll')
    SKIN:Bang('!Redraw')
    return true
end

-- Numeric entry is a text box placed over its field: while it is open the field
-- must not move from under it.
local function editing()
    local name = SKIN:GetVariable('PanelScrollEditor', '')
    local editor = name ~= '' and SKIN:GetMeasure(name)
    if not editor then return false end
    SKIN:Bang('!UpdateMeasure', name)
    return editor:GetValue() == 0
end

-- A refresh (every saved value refreshes the suite) starts this script again, so
-- the position is kept in one small file until the panel closes.
local function remember()
    local file = memory and io.open(memory, 'wb')
    if not file then return end
    file:write(string.format('%.2f', offset / scale))
    file:close()
end

function Forget()
    if memory then os.remove(memory) end
end

local function move(distance)
    if limit == 0 or editing() then return false end
    offset = offset + distance
    if not Fit() then return false end
    remember()
    return true
end

function Wheel(direction) return move(direction * 2 * ROW * scale) end
function Page(direction) return move(direction * (view - ROW * scale)) end

function Initialize()
    local temp = os.getenv('TEMP')
    if temp and temp ~= '' then
        memory = temp .. '\\ParallaxScroll-' .. (SKIN:GetVariable('CURRENTCONFIG', ''):gsub('%W', '-')) .. '.txt'
    end
    local file = memory and io.open(memory, 'rb')
    if file then
        offset = (tonumber(file:read('*a')) or 0) * number('#Scale#')
        file:close()
    end
    Fit(true)
end

-- Once per load, now that the window's own position is known.
function Update()
    Fit(true)
    return 0
end
