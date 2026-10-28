-- Per-drive overlay colors shared by Disk Meter (graph traces and legend) and
-- its Drive Colors editor. Pure functions; Get reads one saved variable.
-- A saved IODriveColor<letter> is an opaque RGB value; absent or invalid
-- values use the letter's fixed default, so a letter never changes color
-- with selection order.
local Colors = {}

-- Golden-angle hue per letter: adjacent letters stay visibly distinct.
function Colors.Default(letter)
    local hue = ((string.byte(letter) - 65) * 0.61803398875 % 1) * 6
    local sector, fraction = math.floor(hue), hue - math.floor(hue)
    local value, saturation = 0.95, 0.65
    local p, q, t = value * (1 - saturation), value * (1 - saturation * fraction), value * (1 - saturation * (1 - fraction))
    local channels = {{value,t,p},{q,value,p},{p,value,t},{p,q,value},{t,p,value},{value,p,q}}
    local color = channels[sector + 1]
    return string.format('%d,%d,%d', math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

-- Accepts R,G,B (0-255) or #RRGGBB / #RRGGBBAA and returns canonical R,G,B.
function Colors.Normalize(value, fallback)
    local text = tostring(value or ''):match('^%s*(.-)%s*$')
    local hex = text:gsub('^#', '')
    if (#hex == 6 or #hex == 8) and hex:match('^%x+$') then
        return table.concat({
            tostring(tonumber(hex:sub(1, 2), 16)),
            tostring(tonumber(hex:sub(3, 4), 16)),
            tostring(tonumber(hex:sub(5, 6), 16))
        }, ',')
    end
    local red, green, blue = text:match('^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
    red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
    if red and green and blue and red <= 255 and green <= 255 and blue <= 255 then
        return string.format('%d,%d,%d', red, green, blue)
    end
    return fallback
end

function Colors.Hex(color)
    local red, green, blue = tostring(color):match('^(%d+),(%d+),(%d+)$')
    return string.format('#%02X%02X%02X', tonumber(red) or 0, tonumber(green) or 0, tonumber(blue) or 0)
end

-- The color for a drive letter: its saved value, else its default.
function Colors.Get(skin, letter)
    local fallback = Colors.Default(letter)
    return Colors.Normalize(skin:GetVariable('IODriveColor' .. letter, fallback), fallback)
end

return Colors
