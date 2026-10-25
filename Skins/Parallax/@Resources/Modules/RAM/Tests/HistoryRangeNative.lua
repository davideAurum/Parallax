-- Test-only: runs in a copied RAM skin owned by Test-RAMHistoryRange.ps1, with
-- History scale Auto and a synthetic used-memory feed (a triangle wave between
-- FeedLow and FeedHigh). It drives the feed through narrow, wide and narrow
-- phases and, at each checkpoint, asserts the range label and the proxy range,
-- then hands the window to the script for a PrintWindow capture (drawn span
-- and label pixels) and waits for its acknowledgement. It then checks the unit
-- and precision rewrites and the idle-resume reset. It writes only its own
-- report, checkpoint and progress files.
local ticks, phase, mark, checks, width, runDir = 0, 0, 0, 0, nil, nil
local report = {}

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function write(path, text)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(text)); assert(file:close())
end

local function exists(path)
    local file = io.open(path, 'rb')
    if file then file:close(); return true end
    return false
end

local function label() return SKIN:GetMeter('MeterRAMHistoryRange'):GetOption('Text') end

local function range()
    local proxy = SKIN:GetMeasure('MeasureRAMHistoryValue')
    return proxy:GetMinValue(), proxy:GetMaxValue()
end

local function feed(low, high)
    SKIN:Bang('!SetVariable', 'FeedLow', tostring(low))
    SKIN:Bang('!SetVariable', 'FeedHigh', tostring(high))
end

local function setUnits(mb, decimals)
    SKIN:Bang('!SetVariable', 'RAMUseMiB', tostring(mb))
    SKIN:Bang('!SetVariable', 'RAMDecimals', tostring(decimals))
    SKIN:Bang('!UpdateMeasure', 'MeasureRAMSettings')
end

-- The range follows the data with hysteresis: it changes only when a sample
-- leaves it or the data needs under half of it. So the checkpoints assert
-- invariants (contains the data, honours the minimum span, shrinks once the
-- wide samples are gone) and that the label shows the proxy range, then
-- write the range and label rectangles for the capture analysis and wait.
local function checkpoint(n, kind)
    local low, high = range()
    local text = label()
    check(text == string.format('%.1f - %.1f GB', low / 1e9, high / 1e9),
        string.format('checkpoint %d label %q does not show the proxy range %.0f..%.0f', n, text, low, high))
    if kind == 'narrow' then
        -- Data 22.8-23.2 GB inside at least 2.2 GB (the 2 GB minimum span plus
        -- headroom) and at most 1.5 times the span the data needs.
        check(low <= 22800000000 and high >= 23200000000 and high - low >= 2200000000 and high - low <= 3300000000,
            string.format('checkpoint %d narrow range %.0f..%.0f', n, low, high))
    else
        check(low <= 20000000000 and high >= 30000000000 and high - low <= 22000000000,
            string.format('checkpoint %d wide range %.0f..%.0f', n, low, high))
    end
    check(SKIN:GetMeter('MeterRAMHistory'):GetOption('MeasureName') == 'MeasureRAMHistoryValue', 'History Line is not bound to the Auto proxy')
    local line, tag = SKIN:GetMeter('MeterRAMHistory'), SKIN:GetMeter('MeterRAMHistoryRange')
    write(runDir .. '\\cp' .. n .. '.txt', string.format('%d,%d,%d,%d|%d,%d,%d,%d|%s|%.0f|%.0f|tick %d',
        line:GetX(), line:GetY(), line:GetW(), line:GetH(), tag:GetX(), tag:GetY(), tag:GetW(), tag:GetH(),
        text, low, high, ticks))
    report[#report + 1] = string.format('cp%d %s (%s)', n, text, kind)
end

local function step()
    if phase == 0 then
        if ticks == 3 then
            width = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#ContentWidth#') .. ')')
            check(width and width > 20, 'ContentWidth did not resolve')
            check(SKIN:GetMeasure('MeasureRAMHistoryRange') ~= nil, 'Auto range controller is not loaded')
            check(SKIN:GetVariable('RAMHistoryMeasure') == 'MeasureRAMHistoryValue', 'The Auto include did not override the history measure')
        end
        -- Data 22.8-23.2 GB, narrower than the 2 GB minimum span.
        if width and ticks >= width + 5 then
            checkpoint(1, 'narrow')
            phase = 1
        end
    elseif phase == 1 then
        if exists(runDir .. '\\ack1') then feed(20000000000, 30000000000); mark = ticks; phase = 2 end
    elseif phase == 2 then
        -- Old narrow samples still sit in the plot beside the new wide ones.
        if ticks >= mark + 25 then
            checkpoint(2, 'wide')
            phase = 3
        end
    elseif phase == 3 then
        if exists(runDir .. '\\ack2') then phase = 4 end
    elseif phase == 4 then
        if ticks >= mark + width + 5 then
            checkpoint(3, 'wide')
            phase = 5
        end
    elseif phase == 5 then
        if exists(runDir .. '\\ack3') then feed(22800000000, 23200000000); mark = ticks; phase = 6 end
    elseif phase == 6 then
        -- The wide samples have left the plot: the range must shrink back.
        if ticks >= mark + width + 5 then
            checkpoint(4, 'narrow')
            phase = 7
        end
    elseif phase == 7 then
        if exists(runDir .. '\\ack4') then setUnits(1, 1); phase = 8 end
    elseif phase == 8 then
        check(label() == '21900.0 - 24100.0 MB', 'MB label is ' .. label())
        setUnits(0, 0)
        phase = 9
    elseif phase == 9 then
        local low, high = range()
        check(label() == '21 - 25 GB' and low == 21000000000 and high == 25000000000,
            string.format('0-decimal range is %q %.0f..%.0f', label(), low, high))
        setUnits(0, 1)
        phase = 10
    elseif phase == 10 then
        check(label() == '21.9 - 24.1 GB', 'Restored label is ' .. label())
        SKIN:Bang('!CommandMeasure', 'MeasureRAMHistoryRange', 'Reset()')
        mark = ticks
        phase = 11
    elseif phase == 11 and ticks >= mark + 2 then
        -- One sample after the reset: the range is the minimum span around it.
        local low, high = range()
        local value = SKIN:GetMeasure('MeasureRAMUsed'):GetValue()
        check(high - low >= 2200000000 and high - low <= 2400000000 and low <= value and value <= high,
            string.format('Post-reset range %.0f..%.0f does not wrap %.0f at the minimum span', low, high, value))
        return string.format('PASS: %d checks; ContentWidth=%g; %s', checks, width, table.concat(report, '; '))
    end
end

function Initialize()
    runDir = SELF:GetOption('RunDir')
end

function Update()
    if phase < 0 then return 0 end
    ticks = ticks + 1
    local ok, result = pcall(step)
    if ok and result == nil then
        if ticks % 10 == 0 then write(SELF:GetOption('ProgressPath'), tostring(ticks)) end
        return 0
    end
    phase = -1
    write(SELF:GetOption('ResultPath'), (ok and result or ('FAIL tick ' .. ticks .. ': ' .. tostring(result))) .. '\n')
    return ok and 1 or -1
end
