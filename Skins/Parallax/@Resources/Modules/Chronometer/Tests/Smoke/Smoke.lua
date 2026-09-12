-- Runs only in the copied, isolated frontend smoke skin.
local ticks, checks, report, stopped = 0, 0, {}, false
local pausedText, initialUptime, initialUptimeText
local fixture, initialTime, initialList, initialLabel
local eventCore, eventPath, futureEvent, futureEventText, initialEventRemaining, midnightEvent
local futureEventName = 'A long event name with # [literal] %1 tokens and enough words to clip'
local probes = {
    { 'MeterSmokeTitleProbe', 'MeterTitle', 'Chronometer' },
    { 'MeterSmokeDateProbe', 'MeterDate', 'Wednesday, 30 September 2026' },
    { 'MeterSmokeFooterProbe', 'MeterPersistence', 'All lists: 10 running / 2 done' },
    { 'MeterSmokeLabelProbe', 'MeterLabel1', 'Deep work' },
    { 'MeterSmokeListProbe', 'MeterList', '1 / 3 Focus' },
    { 'MeterSmokeClockProbe', 'MeterClock', '11:59:59 PM' },
    { 'MeterSmokeUptimeProbe', 'MeterUptimeValue', '9999d 23:59:59' },
    { 'MeterSmokeEventLabelProbe', 'MeterEventName', 'Countdown to A:' },
    { 'MeterSmokeEventProbe', 'MeterEventCountdown', '99999d 23h 59m 59s' },
    { 'MeterSmokeTimeProbe', 'MeterTime1', '7d 00:00:00' },
    { 'MeterSmokeToggleProbe', 'MeterToggle1', 'Resume' },
    { 'MeterSmokeStateProbe', 'MeterState1', 'Fix duration' }
}
local sections = { 'Clock', 'Uptime', 'Event', 'Timers' }

local function numberVariable(name)
    local value = SKIN:GetVariable(name)
    return assert(tonumber(value) or SKIN:ParseFormula(value), 'Invalid numeric variable: ' .. name)
end

local function sectionFor(name)
    if name == 'MeterBounds' or name == 'MeterPanel' or name == 'MeterTitle' or name == 'MeterIcon' or name == 'MeterChronometerOptions' then return nil end
    if name == 'MeterClock' or name == 'MeterDate' then return 'Clock' end
    if name:match('^MeterUptime') then return 'Uptime' end
    if name:match('^MeterEvent') then return 'Event' end
    return 'Timers'
end

local function sectionVisible(name)
    local section = sectionFor(name)
    return not section or tonumber(SKIN:GetVariable('ChronometerShow' .. section)) == 1
end

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function meter(name)
    local value = SKIN:GetMeter(name)
    check(value ~= nil, 'Missing actual meter: ' .. name)
    return value
end

local function text(name)
    return meter(name):GetOption('Text', '', true)
end

local function command(code)
    SKIN:Bang('!CommandMeasure', 'MeasureChronometer', code)
end

local function finish(ok, message)
    stopped = true
    report[#report + 1] = (ok and 'PASS: ' or 'FAIL: ') .. message
    report[#report + 1] = 'SUMMARY: ' .. checks .. ' checks, ' .. (ok and '0' or '1') .. ' failed'
    local output = assert(io.open(SELF:GetOption('ResultPath'), 'wb'))
    assert(output:write(table.concat(report, '\n') .. '\n'))
    assert(output:close())
    SKIN:Bang('!Quit')
end

local function dimensions()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local columns = tonumber(SKIN:GetVariable('Columns'))
    local width = tonumber(SKIN:GetVariable('ColumnWidth'))
    local gutter = tonumber(SKIN:GetVariable('Gutter'))
    local height = numberVariable('ChronometerVisibleHeight')
    local round = function(v) return math.floor(v + 0.5) end
    local gap = 2 * round(gutter * scale / 2)
    local expectedW = columns * (round(width * scale) + gap)
    local expectedH = round(height * scale) + gap
    check(columns == SELF:GetNumberOption('ExpectedColumns'), 'Requested Columns were applied')
    check(width == SELF:GetNumberOption('ExpectedColumnWidth'), 'Requested ColumnWidth was applied')
    check(scale == SELF:GetNumberOption('ExpectedScale'), 'Requested Scale was applied')
    local mask, bit = 0, 1
    local stackedY = numberVariable('ChronometerClockY')
    for _, section in ipairs(sections) do
        local flag = tonumber(SKIN:GetVariable('ChronometerShow' .. section))
        local sectionY = numberVariable('Chronometer' .. section .. 'Y')
        local sectionHeight = numberVariable('Chronometer' .. section .. 'Height')
        check(flag == 0 or flag == 1, section .. ' visibility flag is binary')
        check(sectionY == stackedY, section .. ' starts immediately after previous visible sections')
        check(sectionHeight > 0, section .. ' has a positive expanded section height')
        mask, bit = mask + bit * flag, bit * 2
        stackedY = stackedY + sectionHeight * flag
    end
    check(mask == SELF:GetNumberOption('ExpectedVisibilityMask'), 'Requested visibility combination applied')
    check(height == stackedY + 6 + math.max(0, tonumber(SKIN:GetVariable('PanelHeight')) - 356), 'Visible height includes only visible sections and saved extra padding')
    for _, key in ipairs({ 'TitleFontSize', 'HeaderFontSize', 'FontSize' }) do
        local expected = SELF:GetNumberOption('Expected' .. key, 0)
        if expected > 0 then check(tonumber(SKIN:GetVariable(key)) == expected, 'Requested typography applied: ' .. key) end
    end
    check(SKIN:GetW() == expectedW, 'Window width ' .. SKIN:GetW() .. ' expected ' .. expectedW)
    check(SKIN:GetH() == expectedH, 'Window height ' .. SKIN:GetH() .. ' expected ' .. expectedH)
    local bounds = meter('MeterBounds')
    check(bounds:GetW() == expectedW and bounds:GetH() == expectedH, 'Bounds meter dimensions')
    local inset = gap / 2
    local panel = meter('MeterPanel')
    check(panel:GetX() == inset and panel:GetY() == inset, 'Panel starts inside the transparent gutters')
    check(panel:GetW() == expectedW - gap and panel:GetH() == expectedH - gap, 'Painted panel dimensions')
    for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
        local item = meter(name)
        -- The installed MeterString implementation applies alignment with false/default;
        -- true returns the option anchor. Check the aligned rectangles actually drawn.
        local x, y, w, h = item:GetX(), item:GetY(), item:GetW(), item:GetH()
        local shape = item:GetOption('Meter') == 'Shape'
        if name == 'MeterChronometerOptions' then
            -- Hidden native meters report zero dimensions; visible bounds are checked after hover.
            check(w == 0 and h == 0, 'Settings gear must initially be hidden')
        elseif not sectionVisible(name) then
            check(w == 0 and h == 0, name .. ' must be hidden with its section')
        else
            check(w > 0 and (h > 0 or shape and h == 0), name .. ' has invalid dimensions: ' .. w .. 'x' .. h)
            check(x >= 0 and y >= 0 and x + w <= expectedW and y + h <= expectedH,
                name .. ' exceeds window: ' .. x .. ',' .. y .. ' ' .. w .. 'x' .. h)
            if name ~= 'MeterBounds' and name ~= 'MeterPanel' then
                -- Content must stay inside the painted border, not merely inside the skin window.
                check(x >= inset + 1 and y >= inset + 1 and x + w <= expectedW - inset - 1 and y + h <= expectedH - inset - 1,
                    name .. ' enters panel border/gutter: ' .. x .. ',' .. y .. ' ' .. w .. 'x' .. h)
            end
        end
    end
    check(SKIN:GetMeasure('MeasureClock'):GetStringValue():match('^%d%d:%d%d:%d%d$') ~= nil, 'Clock measure output')
    check(SKIN:GetMeasure('MeasureDate'):GetStringValue() ~= '', 'Date measure output')
    report[#report + 1] = 'Window ' .. expectedW .. 'x' .. expectedH .. '; ColumnWidth=' .. width .. '; Columns=' .. columns .. '; Scale=' .. scale .. '; Visibility=' .. mask .. '; Fixture=' .. fixture
end

local function gearVisible()
    local gear = meter('MeterChronometerOptions')
    local x, y, w, h = gear:GetX(), gear:GetY(), gear:GetW(), gear:GetH()
    local panel = meter('MeterPanel')
    check(w > 0 and h > 0, 'Configured MouseOverAction must reveal the settings gear')
    check(x >= panel:GetX() + 1 and y >= panel:GetY() + 1 and
        x + w <= panel:GetX() + panel:GetW() - 1 and y + h <= panel:GetY() + panel:GetH() - 1,
        'Visible settings gear must remain inside the painted panel')
    check(gear:GetOption('MouseActionCursor') == '1', 'Visible gear must expose an action cursor')
    check(gear:GetOption('ToolTipText') ~= '', 'Visible gear must describe its settings action')
end

local function rect(name)
    local item = meter(name)
    return { x = item:GetX(), y = item:GetY(), w = item:GetW(), h = item:GetH() }
end

local function beforeX(left, right)
    local a, b = rect(left), rect(right)
    if not sectionVisible(left) or not sectionVisible(right) then return end
    check(a.x + a.w <= b.x, left .. ' overlaps ' .. right .. ' horizontally by ' .. (a.x + a.w - b.x) .. 'px')
end

local function beforeY(top, bottom)
    local a, b = rect(top), rect(bottom)
    if not sectionVisible(top) or not sectionVisible(bottom) then return end
    check(a.y + a.h <= b.y, top .. ' overlaps ' .. bottom .. ' vertically by ' .. (a.y + a.h - b.y) .. 'px')
end

local function sectionDividers()
    local scale, inset = numberVariable('Scale'), numberVariable('Inset')
    local lastVisible, lastBottom, visibleRules = 0, inset, 0
    for index, section in ipairs(sections) do
        if numberVariable('ChronometerShow' .. section) == 1 then
            lastVisible = index
            lastBottom = inset + (numberVariable('Chronometer' .. section .. 'Y') +
                numberVariable('Chronometer' .. section .. 'Height')) * scale
        end
    end
    check(SKIN:GetMeter('MeterRule') == nil, 'The former clock-bottom divider is absent')
    for index, section in ipairs(sections) do
        if section ~= 'Clock' then
            local name = 'Meter' .. section .. 'Rule'
            local rule = meter(name)
            local shown = numberVariable('ChronometerShow' .. section) == 1
            local expectedY = math.floor(inset + (shown and numberVariable('Chronometer' .. section .. 'Y') * scale or 0))
            check(rule:GetY() == expectedY, name .. ' sits at its section top, or at Inset while hidden: ' .. rule:GetY() .. ' expected ' .. expectedY)
            if shown then
                check(rule:GetW() > 0, name .. ' is visible with its owning section')
                check(index <= lastVisible and rule:GetY() < lastBottom, name .. ' cannot dangle after the final visible section')
                visibleRules = visibleRules + 1
            else
                check(rule:GetW() == 0 and rule:GetH() == 0, name .. ' hides with its owning section')
            end
        end
    end
    if lastVisible <= 1 then check(visibleRules == 0, 'No boundary divider remains when only the header or clock is shown') end
end

local function layout()
    sectionDividers()
    beforeY('MeterTitle', 'MeterClock')
    beforeY('MeterClock', 'MeterDate')
    beforeY('MeterDate', 'MeterUptimeRule')
    beforeY('MeterUptimeRule', 'MeterUptimeLabel')
    beforeY('MeterUptimeRule', 'MeterUptimeValue')
    beforeX('MeterUptimeLabel', 'MeterUptimeValue')
    beforeY('MeterUptimeLabel', 'MeterEventRule')
    beforeY('MeterUptimeValue', 'MeterEventRule')
    beforeY('MeterEventRule', 'MeterEventName')
    beforeY('MeterEventName', 'MeterEventCountdown')
    beforeY('MeterEventCountdown', 'MeterTimersRule')
    beforeY('MeterTimersRule', 'MeterList')
    local eventText, eventLabel = meter('MeterEventCountdown'), meter('MeterEventName')
    check(SKIN:GetMeter('MeterEventTitle') == nil and SKIN:GetMeter('MeterEventEdit') == nil and SKIN:GetMeter('MeterEventTarget') == nil,
        'Event has no separate section heading, edit link or target-date meter')
    check(eventText:GetOption('StringAlign'):lower() == 'left' and eventLabel:GetOption('StringAlign'):lower() == 'left',
        'Event label and countdown are left aligned')
    check(eventLabel:GetOption('ClipString') == '1', 'Long event labels clip independently of the numeric line')
    if sectionVisible('MeterEventCountdown') then
        check(eventText:GetX() == numberVariable('ContentX') and eventLabel:GetX() == eventText:GetX(), 'Both event lines start at the left content edge')
        check(eventText:GetY() == eventLabel:GetY() + eventLabel:GetH(), 'Countdown starts immediately on the next line without a blank row')
    end
    beforeX('MeterList', 'MeterPrevList')
    beforeX('MeterPrevList', 'MeterNextList')
    beforeY('MeterList', 'MeterLabel1')
    beforeY('MeterNextList', 'MeterLabel1')
    for row = 1, 4 do
        beforeX('MeterLabel' .. row, 'MeterState' .. row)
        beforeX('MeterTime' .. row, 'MeterToggle' .. row)
        beforeX('MeterToggle' .. row, 'MeterReset' .. row)
        beforeY('MeterLabel' .. row, 'MeterTime' .. row)
        beforeY('MeterState' .. row, 'MeterToggle' .. row)
        if row < 4 then
            beforeY('MeterTime' .. row, 'MeterLabel' .. (row + 1))
            beforeY('MeterReset' .. row, 'MeterLabel' .. (row + 1))
        end
    end
    beforeY('MeterTime4', 'MeterEdit')
    beforeY('MeterReset4', 'MeterEdit')
    beforeX('MeterEdit', 'MeterReload')
    beforeY('MeterEdit', 'MeterPersistence')
    beforeY('MeterReload', 'MeterPersistence')
end

local function uptime()
    local measure = SKIN:GetMeasure('MeasureUptime')
    check(measure ~= nil, 'Native uptime measure exists')
    check(measure:GetOption('Measure'):lower() == 'uptime', 'Uptime uses the built-in measure')
    check(measure:GetOption('SecondsValue', '') == '', 'Production uptime measures the system, without a forced value')
    local value, formatted = measure:GetValue(), measure:GetStringValue()
    check(value == value and value >= 0 and value < math.huge, 'Uptime has a finite nonnegative numeric value')
    local days, hours, minutes, seconds = formatted:match('^(%d+)d (%d%d):(%d%d):(%d%d)$')
    check(days ~= nil, 'Uptime uses days and zero-padded clock fields')
    days, hours, minutes, seconds = tonumber(days), tonumber(hours), tonumber(minutes), tonumber(seconds)
    check(hours < 24 and minutes < 60 and seconds < 60, 'Uptime clock fields remain in range')
    check(days * 86400 + hours * 3600 + minutes * 60 + seconds == math.floor(value), 'Formatted uptime agrees with the native seconds value')
    check(meter('MeterUptimeValue'):GetOption('MeasureName') == 'MeasureUptime', 'Visible uptime value binds the native measure')
    return value, formatted
end

local function uptimeRollover()
    local measure = SKIN:GetMeasure('MeasureSmokeUptimeFormat')
    check(measure ~= nil, 'Isolated uptime formatter exists')
    -- Exercise the production format without overriding the real uptime measure.
    for _, sample in ipairs({
        { 0, '0d 00:00:00' }, { 59, '0d 00:00:59' }, { 60, '0d 00:01:00' },
        { 3599, '0d 00:59:59' }, { 3600, '0d 01:00:00' },
        { 86399, '0d 23:59:59' }, { 86400, '1d 00:00:00' },
        { 863999999, '9999d 23:59:59' }
    }) do
        SKIN:Bang('!SetOption', 'MeasureSmokeUptimeFormat', 'SecondsValue', tostring(sample[1]))
        SKIN:Bang('!UpdateMeasure', 'MeasureSmokeUptimeFormat')
        check(measure:GetStringValue() == sample[2], 'Native uptime format rollover for ' .. sample[1] .. ' seconds')
    end
end

local function writeEvent(contents, reload)
    local file = assert(io.open(eventPath, 'wb'))
    assert(file:write(contents))
    assert(file:close())
    if reload then SKIN:Bang('!CommandMeasure', 'MeasureEventCountdown', 'Reload()') end
end

local function eventContents()
    local file = io.open(eventPath, 'rb')
    if not file then return nil end
    local contents = file:read('*a')
    file:close()
    return contents
end

local function eventUnset()
    check(text('MeterEventName') == 'No event set', 'Unset event has an honest setup state')
    check(text('MeterEventCountdown') == 'Add in settings', 'Unset event offers settings guidance without a fabricated countdown')
end

local function futureRemaining(event)
    local displayed = text('MeterEventCountdown')
    local label = 'Countdown to ' .. eventCore.displayName(event.name) .. ':'
    check(text('MeterEventName') == label, 'Event label includes the prefix and sanitized saved name')
    check(meter('MeterEventCountdown'):GetOption('ToolTipText'):find(label .. '\n' .. displayed, 1, true) ~= nil,
        'Event tooltip preserves the label and compact units on separate lines')
    local days, hours, minutes, seconds = displayed:match('^(%d+)d (%d+)h (%d+)m (%d+)s$')
    check(days ~= nil, 'Future event renders compact day/hour/minute/second units')
    days, hours, minutes, seconds = tonumber(days), tonumber(hours), tonumber(minutes), tonumber(seconds)
    check(hours < 24 and minutes < 60 and seconds < 60, 'Event countdown fields remain in range')
    local remaining = days * 86400 + hours * 3600 + minutes * 60 + seconds
    check(remaining > 0 and math.abs(remaining - (event.deadline - os.time())) <= 2, 'Event display agrees with the future deadline')
    check(meter('MeterEventCountdown'):GetOption('ToolTipText'):find(os.date('%Y-%m-%d %H:%M', event.deadline), 1, true) ~= nil,
        'Event tooltip preserves the current local target date/time')
    return remaining
end

local function eventScenario()
    if ticks == 2 then
        check(SKIN:GetMeasure('MeasureEventCountdown') ~= nil, 'Event adapter loaded')
        check(eventContents() == nil, 'Initial event fixture is missing')
        eventUnset()
        futureEvent = { enabled = true, deadline = os.time() + 91800, name = futureEventName }
        futureEvent.localDate = os.date('%Y-%m-%d %H:%M:%S', futureEvent.deadline)
        futureEventText = assert(eventCore.encode(futureEvent))
        writeEvent(futureEventText, true)
    elseif ticks == 3 then
        initialEventRemaining = futureRemaining(futureEvent)
        local displayed = text('MeterEventName')
        check(displayed == 'Countdown to ' .. eventCore.displayName(futureEventName) .. ':', 'Event label retains the complete sanitized name')
        check(not displayed:find('[#%%%[%]]'), 'Event name cannot expose Rainmeter expansion tokens')
        check(meter('MeterEventName'):GetOption('ClipString') == '1', 'Long event name uses a fixed clipping box')
        check(meter('MeterEventName'):GetOption('ToolTipText'):find(displayed, 1, true) ~= nil, 'Full event name is available in the label tooltip')
    elseif ticks == 4 then
        check(futureRemaining(futureEvent) < initialEventRemaining, 'Event countdown advances across native updates')
        check(eventContents() == futureEventText, 'Event updates leave the persisted state untouched')
        local past = { enabled = true, deadline = os.time() - 60, name = 'Finished event' }
        past.localDate = os.date('%Y-%m-%d %H:%M:%S', past.deadline)
        writeEvent(assert(eventCore.encode(past)), true)
    elseif ticks == 5 then
        check(text('MeterEventCountdown') == '0d 0h 0m 0s', 'Expired event shows zero units')
        check(text('MeterEventName') == 'Event reached: Finished event', 'Expired event explicitly marks its reached status with the saved name')
        local past = assert(eventCore.decode(eventContents()))
        check(meter('MeterEventCountdown'):GetOption('ToolTipText'):find(os.date('%Y-%m-%d %H:%M', past.deadline), 1, true) ~= nil,
            'Expired event keeps its original target date in the tooltip')
        writeEvent('intentionally corrupt event state\n', false)
    elseif ticks == 6 then
        check(text('MeterEventCountdown') == '0d 0h 0m 0s' and text('MeterEventName') == 'Event reached: Finished event',
            'Ordinary updates retain cached event state until explicit Reload')
        SKIN:Bang('!CommandMeasure', 'MeasureEventCountdown', 'Reload()')
    elseif ticks == 7 then
        check(text('MeterEventName') == 'Event unavailable', 'Corrupt event is explicitly unavailable')
        check(text('MeterEventCountdown') == 'Open settings to repair', 'Corrupt event offers repair guidance without a fabricated countdown')
        local date = os.date('*t', os.time() + 3 * 86400)
        date.hour, date.min, date.sec, date.isdst = 0, 0, 0, nil
        midnightEvent = { enabled = true, deadline = os.time(date), name = 'Date-only event' }
        midnightEvent.localDate = os.date('%Y-%m-%d %H:%M:%S', midnightEvent.deadline)
        writeEvent(assert(eventCore.encode(midnightEvent)), true)
    elseif ticks == 8 then
        futureRemaining(midnightEvent)
        check(text('MeterEventName') == 'Countdown to Date-only event:', 'Date-only event loads its name above the countdown units')
        check(meter('MeterEventCountdown'):GetOption('ToolTipText'):find(' 00:00', 1, true) ~= nil,
            'Date-only fixture retains its local midnight deadline in the tooltip')
        writeEvent(assert(eventCore.encode({ enabled = false, deadline = 0, name = '', localDate = '' })), true)
    elseif ticks == 9 then
        eventUnset()
        local cleared = assert(eventCore.decode(eventContents()))
        check(not cleared.enabled and cleared.deadline == 0, 'Cleared event persists as valid disabled state')
    end
end

local function prepareProbes()
    for _, probe in ipairs(probes) do
        if sectionVisible(probe[2]) then
        local source = meter(probe[2])
        for _, option in ipairs({ 'FontFace', 'FontSize', 'FontWeight', 'StringStyle', 'AntiAlias', 'Padding' }) do
            local value = source:GetOption(option, '')
            if value ~= '' then SKIN:Bang('!SetOption', probe[1], option, value) end
        end
        if probe[2] == 'MeterDate' then
            -- Measure wrapped height at the real content width instead of forcing one line.
            SKIN:Bang('!SetOption', probe[1], 'W', tostring(source:GetW()))
            SKIN:Bang('!SetOption', probe[1], 'ClipString', '2')
        end
        SKIN:Bang('!SetOption', probe[1], 'Text', probe[3])
        SKIN:Bang('!UpdateMeter', probe[1])
        end
    end
end

local function probeFit()
    local failures = {}
    local function fitCheck(condition, message)
        checks = checks + 1
        if not condition then failures[#failures + 1] = message end
    end
    for _, probe in ipairs(probes) do
        if sectionVisible(probe[2]) then
        local natural, target = meter(probe[1]), meter(probe[2])
        fitCheck(natural:GetW() > 0 and natural:GetH() > 0, probe[1] .. ' must measure text: ' .. natural:GetW() .. 'x' .. natural:GetH() .. ' Text=' .. natural:GetOption('Text'))
        fitCheck(natural:GetW() <= target:GetW(), probe[2] .. ' clips "' .. probe[3] .. '": requires ' .. natural:GetW() .. 'px, has ' .. target:GetW())
        fitCheck(natural:GetH() <= target:GetH(), probe[2] .. ' clips text height: requires ' .. natural:GetH() .. 'px, has ' .. target:GetH())
        end
    end
    if #failures > 0 then error(table.concat(failures, '; ')) end
end

function Initialize()
    fixture = SELF:GetOption('Fixture', 'Default')
    initialTime = fixture == 'Edge' and '7d 00:00:00' or '00:25:00'
    initialList = fixture == 'Edge' and '1/3  An intentionally long countdown collection name that must clip' or '1/3  Focus'
    initialLabel = fixture == 'Edge' and 'An intentionally long seven-day timer label that must clip' or 'Deep work'
    eventCore = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\EventCore.lua')
    eventPath = SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state'
end

function Update()
    if stopped then return 0 end
    ticks = ticks + 1
    if ticks < 2 then return 0 end
    local ok, err = pcall(function()
        if SELF:GetOption('LayoutOnly') == '1' then
            if ticks == 2 then
                dimensions()
                layout()
                prepareProbes()
                SKIN:Bang(SELF:GetOption('HoverAction'))
            elseif ticks == 3 then
                gearVisible()
                probeFit()
                SKIN:Bang(SELF:GetOption('LeaveAction'))
            elseif ticks == 4 then
                local gear = meter('MeterChronometerOptions')
                check(gear:GetW() == 0 and gear:GetH() == 0, 'Gear remains available on hover and hides on leave')
                finish(true, 'Visibility, compact native bounds, section spacing, text fit and header gear passed')
            end
            return
        end
        eventScenario()
        if ticks == 2 then
            dimensions()
            layout()
            initialUptime, initialUptimeText = uptime()
            uptimeRollover()
            prepareProbes()
            SKIN:Bang(SELF:GetOption('HoverAction'))
            check(text('MeterState1') == 'Ready', 'Initial timer not Ready')
            check(text('MeterTime1') == initialTime, 'Initial duration')
            check(text('MeterList') == initialList, 'Initial list')
            check(text('MeterLabel1') == initialLabel, 'Initial label retained as text')
            check(meter('MeterLabel1'):GetOption('ClipString') == '1', 'Long labels must clip to fixed bounds')
            check(meter('MeterList'):GetOption('ClipString') == '1', 'Long list names must clip to fixed bounds')
            if fixture == 'Edge' then
                check(text('MeterState2') == 'Fix duration', 'Invalid duration shows an explicit status')
                check(text('MeterTime2') == '--:--:--', 'Invalid duration has no fabricated countdown')
                check(text('MeterToggle2') == '--', 'Invalid duration has no start action label')
            end
            command('Toggle(1)')
        elseif ticks == 3 then
            gearVisible()
            SKIN:Bang(SELF:GetOption('LeaveAction'))
            probeFit()
            check(text('MeterState1') == 'Running', 'Start control status')
            check(text('MeterToggle1') == 'Pause', 'Start control label')
            check(text('MeterPersistence') == (fixture == 'Edge' and '1 invalid duration(s) - edit lists' or 'All lists: 1 running / 0 done'), 'Running footer')
            command('Toggle(1)')
        elseif ticks == 4 then
            local gear = meter('MeterChronometerOptions')
            check(gear:GetW() == 0 and gear:GetH() == 0, 'Configured MouseLeaveAction must hide the settings gear')
            layout()
            check(text('MeterState1') == 'Paused', 'Pause control status')
            check(text('MeterToggle1') == 'Resume', 'Pause control label')
            pausedText = text('MeterTime1')
            command('SelectList(1)')
        elseif ticks == 5 then
            check(text('MeterList') == '2/3  Daily', 'Next list control')
            check(text('MeterLabel1') == 'Tea', 'Next list label')
            check(text('MeterState1') == 'Ready', 'Other list independent status')
            command('SelectList(-1)')
        elseif ticks == 6 then
            check(text('MeterList') == initialList, 'Previous list control')
            check(text('MeterState1') == 'Paused', 'Original list retained pause')
            check(text('MeterTime1') == pausedText, 'Paused timer changed while switching lists')
            command('Reset(1)')
        elseif ticks == 7 then
            local currentUptime, currentUptimeText = uptime()
            check(currentUptime > initialUptime, 'Native uptime advances across updates')
            check(currentUptimeText ~= initialUptimeText, 'Displayed uptime format advances across updates')
            check(text('MeterState1') == 'Ready', 'Reset control status')
            check(text('MeterToggle1') == 'Start', 'Reset control label')
            check(text('MeterTime1') == initialTime, 'Reset restores duration')
            local path = SKIN:GetVariable('SETTINGSPATH')
            local core = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\Core.lua')
            local store = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\Store.lua')
            local _, saved, damaged = store.open(path .. 'Parallax-Chronometer-v1', core)
            check(saved ~= nil and not damaged, 'Native control snapshots readable')
            check(saved.selected == 1 and saved.timers[1].status == 'idle', 'Native reset snapshot state')
            if fixture == 'Edge' then
                check(saved.timers[2].status == 'disabled', 'Invalid duration persists as disabled')
                command('Toggle(2)')
            end
        elseif ticks == 8 then
            if fixture == 'Edge' then
                check(text('MeterState2') == 'Fix duration' and text('MeterTime2') == '--:--:--', 'Disabled timer cannot be started')
            end
        elseif ticks == 9 then
            finish(true, 'Actual skin loaded; bounds, text fit, timer controls and event state transitions passed')
        end
    end)
    if not ok then finish(false, tostring(err)) end
    return 0
end
