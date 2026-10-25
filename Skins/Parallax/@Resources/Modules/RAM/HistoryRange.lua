-- RAM history auto-range (History scale Auto only; HistoryScale1.inc loads it).
-- Keeps the last ContentWidth used-memory samples, the ones the Line meter
-- holds, and sets MinValue/MaxValue on the Calc proxy the Line draws. The Line
-- maps its stored samples with that measure's current range at draw time, so a
-- new range re-maps the whole visible history. This script runs before the
-- proxy in Measures order, so the range applies to the same update's draw.
-- No telemetry, process or file access; bangs are sent only when the range or
-- its label changes.
-- Headroom is the fraction of the data span added around it. SHRINK is how
-- many times the span the data needs the shown range may reach before it is
-- refitted: a refit while old extremes are still leaving the plot is itself
-- too wide, so the threshold sits well under 2 to let it converge in steps.
local HEADROOM, SHRINK = 1.1, 1.5
local size, total, minSpan, ring, head, count, lo, hi

local function number(text, default)
    local value = tonumber(text)
    if not value or value ~= value or value == math.huge or value == -math.huge then return default end
    return value
end

-- Divisor, decimals and unit name of the shown RAM unit (decimal GB / MB).
local function unit()
    local mb = tonumber(SKIN:GetVariable('RAMUseMiB')) == 1
    local decimals = math.max(0, math.min(2, math.floor(number(SKIN:GetVariable('RAMDecimals'), 1))))
    return mb and 1e6 or 1e9, decimals, mb and 'MB' or 'GB'
end

local function setup()
    size = math.max(2, math.floor(number(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#ContentWidth#') .. ')'), 2)))
    local item = SKIN:GetMeasure('MeasureRAMTotal')
    total = item and item:GetValue() or 0
    if total <= 0 then total = nil; return false end
    minSpan = math.max(0.5e9, math.min(total, number(SKIN:GetVariable('RAMHistoryMinSpan'), 2) * 1e9))
    return true
end

local function want(dmin, dmax) return math.min(total, math.max(dmax - dmin, minSpan) * HEADROOM) end

-- The data span plus headroom, centred, rounded outward to the label's
-- precision and moved (not shrunk) to stay inside 0..total.
local function fit(dmin, dmax, step)
    local span = want(dmin, dmax)
    local mid = (dmin + dmax) / 2
    local low = math.floor((mid - span / 2) / step + 1e-9) * step
    local high = math.ceil((mid + span / 2) / step - 1e-9) * step
    local width = high - low
    if width >= total then return 0, total end
    if low < 0 then return 0, width end
    if high > total then return total - width, total end
    return low, high
end

local function extent()
    local lowest, highest = ring[1], ring[1]
    for i = 2, count do
        local value = ring[i]
        if value < lowest then lowest = value elseif value > highest then highest = value end
    end
    return lowest, highest
end

local function show()
    local divisor, decimals, name = unit()
    local step = divisor / 10 ^ decimals
    local format = '%.' .. decimals .. 'f'
    local text = string.format(format, math.floor(lo / step + 1e-9) * step / divisor) .. ' - ' ..
        string.format(format, math.ceil(hi / step - 1e-9) * step / divisor) .. ' ' .. name
    SKIN:Bang('!SetOption', 'MeterRAMHistoryRange', 'Text', text)
    -- The label is an UpdateDivider=-1 meter: forced, or it ignores the option.
    SKIN:Bang('!UpdateMeter', 'MeterRAMHistoryRange')
end

local function apply()
    SKIN:Bang('!SetOption', 'MeasureRAMHistoryValue', 'MinValue', string.format('%.0f', lo))
    SKIN:Bang('!SetOption', 'MeasureRAMHistoryValue', 'MaxValue', string.format('%.0f', hi))
    show()
end

function Initialize()
    ring, head, count, lo, hi = {}, 0, 0, nil, nil
end

function Update()
    if not total and not setup() then return 0 end
    local item = SKIN:GetMeasure('MeasureRAMUsed')
    local value = item and item:GetValue()
    if type(value) ~= 'number' or value ~= value then return 0 end
    head = head % size + 1
    ring[head] = value
    if count < size then count = count + 1 end
    local dmin, dmax = extent()
    -- Re-range only when a sample leaves the range, or the data needs under
    -- 1/SHRINK of it; the common update sends no bang.
    if not lo or dmin < lo or dmax > hi or (hi - lo) > SHRINK * want(dmin, dmax) then
        local divisor, decimals = unit()
        lo, hi = fit(dmin, dmax, divisor / 10 ^ decimals)
        apply()
    end
    return 0
end

-- Unit or decimals changed: re-round the range to the new precision and
-- rewrite the label; the samples are untouched.
function Display()
    if not lo or count == 0 then return end
    local divisor, decimals = unit()
    local dmin, dmax = extent()
    lo, hi = fit(dmin, dmax, divisor / 10 ^ decimals)
    apply()
end

-- Idle resume: the Line is re-shown from empty, so restart the window.
function Reset()
    ring, head, count, lo, hi = {}, 0, 0, nil, nil
end
