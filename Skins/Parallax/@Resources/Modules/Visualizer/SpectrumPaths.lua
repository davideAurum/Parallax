-- Runs once per load (UpdateDivider=-1) in both spectrum hosts, before any
-- meter updates. Spectrum.inc's raw band paths name the host's geometry
-- variables, and the mask's DynamicVariables re-expands and re-parses every one
-- of them, and re-resolves each [Measure] reference, on each update. In Media
-- the plot width is a ~7 KB formula chain inlined ~36 times per path: ~6.5 MB
-- of math per 50 ms tick, enough to saturate Rainmeter's main thread.
--
-- This script evaluates the static geometry once - each slot's left edge and
-- width, the bar height and the radius cap - from Spectrum.inc's own variables,
-- and writes paths that carry those as literal numbers. Only each band's height
-- stays dynamic. The outline is the raw path's, point for point; with no
-- radius every corner term is zero, so a bar is its four corners and reads its
-- measure twice instead of sixteen times. If any input fails to evaluate, the
-- raw paths stay in place: slower, but drawn the same.
local BANDS = 24
local MASK = 'MeterVisualizerSpectrumMask'
local KAPPA = '0.44771525'

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- ParseFormula returns 0, not nil, when a formula fails, so an unresolved
-- variable is rejected before parsing and callers bound every result.
local function evaluate(name)
    local text = SKIN:ReplaceVariables('#' .. name .. '#')
    if type(text) ~= 'string' or text == '' or text:find('[#%[]') then return nil end
    local value = SKIN:ParseFormula('(' .. text .. ')')
    if not finite(value) then return nil end
    return value
end

-- The shortest decimal that parses back to the same double, never in exponent
-- form (Rainmeter's formula parser does not read exponents).
local function literal(value)
    if not finite(value) then return nil end
    if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format('%.0f', value) end
    for digits = 1, 17 do
        local text = string.format('%.' .. digits .. 'g', value)
        if not text:find('[eE]') and tonumber(text) == value then return text end
    end
    return nil
end

local function compile(index, left, right, barHeight, radiusCap)
    local h = '(Round(Max(0,Min(1,[MeasureVisualizerBand' .. index .. ']))*' .. barHeight .. '))'
    local top = '(' .. barHeight .. '-' .. h .. ')'
    if radiusCap == nil then
        return left .. ',' .. barHeight .. ' | LineTo ' .. left .. ',' .. top
            .. ' | LineTo ' .. right .. ',' .. top .. ' | LineTo ' .. right .. ',' .. barHeight .. ' | ClosePath 1'
    end
    local r = '(Min(' .. radiusCap .. ',' .. h .. '))'
    return left .. ',' .. barHeight
        .. ' | LineTo ' .. left .. ',(' .. top .. '+' .. r .. ')'
        .. ' | CurveTo (' .. left .. '+' .. r .. '),' .. top .. ',' .. left .. ',(' .. top .. '+' .. KAPPA .. '*' .. r .. '),('
            .. left .. '+' .. KAPPA .. '*' .. r .. '),' .. top
        .. ' | LineTo (' .. right .. '-' .. r .. '),' .. top
        .. ' | CurveTo ' .. right .. ',(' .. top .. '+' .. r .. '),(' .. right .. '-' .. KAPPA .. '*' .. r .. '),' .. top .. ','
            .. right .. ',(' .. top .. '+' .. KAPPA .. '*' .. r .. ')'
        .. ' | LineTo ' .. right .. ',' .. barHeight .. ' | ClosePath 1'
end

-- Returns the number of compiled paths: 24, or 0 when the raw paths remain.
function Update()
    local barHeight = evaluate('VisualizerBarHeight')
    local radius = evaluate('VisualizerBarRadiusPx')
    local heightText = barHeight and literal(barHeight)
    if not heightText or barHeight <= 0 or not radius or radius < 0 then return 0 end
    local paths = {}
    for index = 0, BANDS - 1 do
        local left = evaluate('VisualizerBandLeft' .. index)
        local width = evaluate('VisualizerBandWidth' .. index)
        if not left or left < 0 or not width or width < 1 then return 0 end
        local leftText, rightText = literal(left), literal(left + width)
        -- The raw radius is Min(BarRadiusPx, Min(Width/2, height)); the first
        -- two terms are static. At zero every corner term vanishes.
        local cap = math.min(radius, width / 2)
        local capText = cap > 0 and literal(cap) or nil
        if not leftText or not rightText or (cap > 0 and not capText) then return 0 end
        paths[index] = compile(index, leftText, rightText, heightText, capText)
    end
    for index = 0, BANDS - 1 do
        SKIN:Bang('!SetOption', MASK, 'BandPath' .. index, paths[index])
    end
    return BANDS
end
