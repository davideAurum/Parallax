-- Runs only through the main skin's OnRefreshAction, after meters exist.
-- No Update callback, file access, helper process or recurring color work.
local function byte(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return math.max(0, math.min(255, math.floor(number + 0.5)))
end

local function parseColor(raw, fallback)
    local text = tostring(raw or ''):match('^%s*(.-)%s*$')
    if (#text == 6 or #text == 8) and text:match('^%x+$') then
        return { tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16),
            tonumber(text:sub(5, 6), 16), #text == 8 and tonumber(text:sub(7, 8), 16) or 255 }
    end
    local result = {}
    for part in (text .. ','):gmatch('(.-),') do
        local component = byte(part)
        if component == nil then return fallback end
        result[#result + 1] = component
    end
    if #result ~= 3 and #result ~= 4 then return fallback end
    if #result == 3 then result[4] = 255 end
    return result
end

function Apply()
    local mode = tonumber(SKIN:GetVariable('VisualizerColorMode', '0'))
    local shape = 'Rectangle 0,0,#VisualizerPlotInnerWidth#,#VisualizerBarHeight#'
    if mode == 3 or mode == 4 then
        -- Literal RGB/RGBA and six/eight-digit hex match suite color settings.
        -- Invalid advanced formulas/text fall back to the shipped accent.
        local first = parseColor(SKIN:GetVariable('AccentColor', ''), {137, 190, 250, 255})
        local last = parseColor(SKIN:GetVariable('AccentColor2', ''), {181, 161, 226, 255})
        local angle = mode == 4 and 90 or 180
        local gradient = angle .. ' | ' .. table.concat(first, ',') .. ' ; 0 | ' .. table.concat(last, ',') .. ' ; 1'
        SKIN:Bang('!SetOption', 'MeterVisualizerFill', 'SpectrumGradient', gradient)
        shape = shape .. ' | Fill LinearGradient SpectrumGradient | StrokeWidth 0'
    else
        local key = mode == 1 and 'AccentColor' or mode == 2 and 'AccentColor2' or 'MediaColor'
        shape = shape .. ' | Fill Color ' .. SKIN:GetVariable(key) .. ' | StrokeWidth 0'
    end
    SKIN:Bang('!SetOption', 'MeterVisualizerFill', 'Shape', shape)
    SKIN:Bang('!UpdateMeter', 'MeterVisualizerFill')
    SKIN:Bang('!Redraw')
end
