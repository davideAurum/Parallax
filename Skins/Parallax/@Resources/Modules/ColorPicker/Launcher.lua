-- Opens Parallax\ColorPicker on one color variable, beside the skin that holds
-- its swatch. Add a Script measure to any skin with swatches:
--
--   [MeasureColorLauncher]
--   Measure=Script
--   ScriptFile=#@#Modules\ColorPicker\Launcher.lua
--
-- and point the swatch at it (the second argument, the swatch's meter name, is
-- optional; it lets the picker line up with the swatch instead of the skin top):
--
--   LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('RAMColor','MeterRAMSwatch')"]
--
-- Event driven: runs only when a swatch is clicked.
local T
local PICKER = 'Parallax\\ColorPicker'
local MONITORS = 8

function Initialize()
    T = dofile(SKIN:GetVariable('@') .. 'Modules\\ColorPicker\\Targets.lua')
end
function Update() return 0 end

local function number(text)
    return tonumber(SKIN:ReplaceVariables(text))
end

-- The picker is one column of fixed width and height (ColorPicker.ini). These
-- are Geometry.inc's formulas, so the size follows the suite's scale and gutter.
local function pickerSize()
    local scale = tonumber(SKIN:GetVariable('Scale')) or 1
    local gutter = tonumber(SKIN:GetVariable('Gutter')) or 8
    local gap = 2 * math.floor(gutter * scale / 2 + 0.5)
    local width = math.floor(T.PickerColumnWidth * scale + 0.5) + gap
    local height = math.floor(T.PickerPanelHeight * scale + 0.5) + gap
    return width, height
end

-- The work area of the monitor holding point (x, y), or nil when it lies on
-- none (an off-screen or unusual layout; the caller then skips clamping).
local function workArea(x, y)
    for n = 1, MONITORS do
        local sx, sy = number('#SCREENAREAX@' .. n .. '#'), number('#SCREENAREAY@' .. n .. '#')
        local sw, sh = number('#SCREENAREAWIDTH@' .. n .. '#'), number('#SCREENAREAHEIGHT@' .. n .. '#')
        if not (sx and sy and sw and sh) or sw <= 0 or sh <= 0 then break end
        if x >= sx and x < sx + sw and y >= sy and y < sy + sh then
            local wx, wy = number('#WORKAREAX@' .. n .. '#'), number('#WORKAREAY@' .. n .. '#')
            local ww, wh = number('#WORKAREAWIDTH@' .. n .. '#'), number('#WORKAREAHEIGHT@' .. n .. '#')
            if wx and wy and ww and wh and ww > 0 and wh > 0 then return wx, wy, ww, wh end
            return sx, sy, sw, sh
        end
    end
    return nil
end

-- Top-left for the picker window: against the skin's right edge (its left edge
-- when the right side would leave the monitor), top-aligned with the skin or
-- centered on the swatch, kept on the monitor. Windows carry their own gutter,
-- so edge to edge leaves the suite's normal gap between the two panels.
function Place(skinX, skinY, skinW, skinH, pickerW, pickerH, swatchY)
    local cx, cy = skinX + skinW / 2, skinY + skinH / 2
    local wx, wy, ww, wh = workArea(cx, cy)
    local x = skinX + skinW
    if wx and x + pickerW > wx + ww and skinX - pickerW >= wx then x = skinX - pickerW end
    local y = skinY
    if swatchY then
        y = swatchY - pickerH / 2
        y = math.min(y, skinY + skinH - pickerH)
        y = math.max(y, skinY)
    end
    if wx then
        x = math.max(wx, math.min(x, wx + ww - pickerW))
        y = math.max(wy, math.min(y, wy + wh - pickerH))
    end
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Opens the picker on key. meterName (optional) is the swatch in this skin.
-- Returns false, without any bang, for a key that is not a listed color
-- variable; the key is quoted into an action only after that check.
function Open(key, meterName)
    if not T.Find(key) then return false end
    local pickerW, pickerH = pickerSize()
    local skinX, skinY = SKIN:GetX(), SKIN:GetY()
    local skinW = SKIN:GetW()
    local skinH = SKIN:GetH()
    local swatchY
    local meter = type(meterName) == 'string' and SKIN:GetMeter(meterName) or nil
    if meter then swatchY = skinY + meter:GetY() + meter:GetH() / 2 end
    local x, y = Place(skinX, skinY, skinW, skinH, pickerW, pickerH, swatchY)
    SKIN:Bang('!ActivateConfig', PICKER, 'ColorPicker.ini')
    SKIN:Bang('!Move', tostring(x), tostring(y), PICKER)
    SKIN:Bang('!CommandMeasure', 'MeasureColorPicker', "OpenTarget('" .. key .. "')", PICKER)
    return true
end
