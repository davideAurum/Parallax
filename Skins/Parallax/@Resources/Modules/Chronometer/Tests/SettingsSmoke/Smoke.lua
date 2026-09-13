-- Appended only to copied production skins in the isolated settings smoke.
local ticks, checks, stopped = 0, 0, false
local openedAt, closedAt, initialTime
local originalColumns, originalDuration, originalDeadline1, originalDeadline2
local reopenPending
local numberPhase, numberWaitTicks, numberSavedBytes
local sections = { 'Clock', 'Uptime', 'Event', 'Timers' }
local visibilityClicks = { 'Clock', 'Uptime', 'Event', 'Timers', 'Clock', 'Uptime', 'Event', 'Timers' }
local probes = {
    { 'Title', 'Chronometer settings' }, { 'ClockVisibility', 'Hidden' },
    { 'WidthValue', '2 columns' }, { 'ClockValue', '12-hour' },
    { 'DateValue', 'Custom' }, { 'StepValue', '1 hour' },
    { 'TimerSeconds1', '7d 00:00:00' }, { 'Status', 'Saved. Changed timer reset.' }
}
for _, name in ipairs({ 'WidthLabel', 'ClockVisibilityLabel', 'ClockLabel', 'SecondsLabel', 'DateLabel',
    'UptimeVisibilityLabel', 'EventVisibilityLabel', 'EventConfigureLabel', 'TimersVisibilityLabel', 'ListLabel',
    'StepLabel' }) do
    probes[#probes + 1] = { name }
end
local rows = {
    { 'Width', 'WidthLabel', 'WidthValue' },
    { 'ClockVisibility', 'ClockVisibilityLabel', 'ClockVisibility' },
    { 'Clock', 'ClockLabel', 'ClockValue', 'Clock' }, { 'Seconds', 'SecondsLabel', 'SecondsValue', 'Clock' },
    { 'Date', 'DateLabel', 'DateValue', 'Clock' },
    { 'UptimeVisibility', 'UptimeVisibilityLabel', 'UptimeVisibility' },
    { 'EventVisibility', 'EventVisibilityLabel', 'EventVisibility' },
    { 'EventConfigure', 'EventConfigureLabel', 'EventConfigure', 'Event' },
    { 'TimersVisibility', 'TimersVisibilityLabel', 'TimersVisibility' },
    { 'List', 'ListLabel', 'ListName', 'Timers' }, { 'Step', 'StepLabel', 'StepValue', 'Timers' },
    { 'Timer1', 'TimerLabel1', 'TimerSeconds1', 'Timers' }, { 'Timer2', 'TimerLabel2', 'TimerSeconds2', 'Timers' },
    { 'Timer3', 'TimerLabel3', 'TimerSeconds3', 'Timers' }, { 'Timer4', 'TimerLabel4', 'TimerSeconds4', 'Timers' }
}
local stepperArrows = {
    Width = { 'WidthDecrease', 'WidthIncrease' }, Clock = { 'ClockDecrease', 'ClockIncrease' },
    Date = { 'DateDecrease', 'DateIncrease' }, List = { 'PreviousList', 'NextList' },
    Step = { 'StepDecrease', 'StepIncrease' }, Timer1 = { 'TimerMinus1', 'TimerPlus1' },
    Timer2 = { 'TimerMinus2', 'TimerPlus2' }, Timer3 = { 'TimerMinus3', 'TimerPlus3' }, Timer4 = { 'TimerMinus4', 'TimerPlus4' }
}
local collapsedOwners = { MeterResetNote = 'Timers' }
for _, spec in ipairs(rows) do
    if spec[4] then
        local number = spec[1]:match('^Timer(%d)$')
        collapsedOwners['Meter' .. (number and ('TimerRow' .. number) or (spec[1] .. 'Row'))] = spec[4]
        collapsedOwners['Meter' .. spec[2]], collapsedOwners['Meter' .. spec[3]] = spec[4], spec[4]
        if stepperArrows[spec[1]] then
            for _, arrow in ipairs(stepperArrows[spec[1]]) do collapsedOwners['Meter' .. arrow] = spec[4] end
        end
    end
end

local function numberVariable(name)
    local value = SKIN:GetVariable(name)
    return assert(tonumber(value) or SKIN:ParseFormula(value), 'Invalid numeric variable: ' .. name)
end

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function meter(name)
    local item = SKIN:GetMeter(name)
    check(item ~= nil, 'Missing meter: ' .. name)
    return item
end

local function write(path, contents)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(contents))
    assert(file:close())
end

local function read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local contents = file:read('*a')
    file:close()
    return contents
end

local function snapshot()
    local resources = SKIN:GetVariable('@')
    local core = dofile(resources .. 'Modules\\Chronometer\\Core.lua')
    local store = dofile(resources .. 'Modules\\Chronometer\\Store.lua')
    local _, saved, damaged = store.open(SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-v1', core)
    check(saved ~= nil and not damaged, 'Actual timer snapshot remains readable')
    return saved
end

local function savedOption(key)
    local contents = assert(read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc'))
    -- Native writes may preserve UTF-8 or use UTF-16; fixture keys/values are ASCII.
    contents = contents:gsub('\0', ''):gsub('^\255\254', ''):gsub('^\254\255', '')
    return ('\n' .. contents):match('\n' .. key .. '=([^\r\n]*)')
end

local function optionsExceptVisibility()
    local contents = assert(read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc'))
    contents = contents:gsub('\0', ''):gsub('^\255\254', ''):gsub('^\254\255', '')
    contents = '\n' .. contents:gsub('\r\n', '\n')
    for _, section in ipairs(sections) do contents = contents:gsub('\nChronometerShow' .. section .. '=[^\n]*', '') end
    return contents
end

local function click(name)
    local action = meter(name):GetOption('LeftMouseUpAction')
    check(action ~= '', name .. ' has a native action')
    SKIN:Bang(action)
end

local function rowLayout(visibility)
    local scale = numberVariable('Scale')
    local contentX, contentW = numberVariable('ContentX'), numberVariable('ContentWidth')
    local bodyColor = SKIN:GetVariable('TextColor'):gsub('%s', '')
    local clockShift, eventShift, timerShift = 84 * (1 - visibility.Clock), 28 * (1 - visibility.Event), 216 * (1 - visibility.Timers)
    local rowY = { Width = 101, ClockVisibility = 160, Clock = 188, Seconds = 216, Date = 244,
        UptimeVisibility = 303 - clockShift, EventVisibility = 362 - clockShift, EventConfigure = 390 - clockShift,
        TimersVisibility = 449 - clockShift - eventShift, List = 477 - clockShift - eventShift,
        Step = 505 - clockShift - eventShift, Timer1 = 533 - clockShift - eventShift,
        Timer2 = 561 - clockShift - eventShift, Timer3 = 589 - clockShift - eventShift, Timer4 = 617 - clockShift - eventShift }
    local prior
    for _, spec in ipairs(rows) do
        local number = spec[1]:match('^Timer(%d)$')
        local prefix = number and ('TimerRow' .. number) or (spec[1] .. 'Row')
        local row, label, value = meter('Meter' .. prefix), meter('Meter' .. spec[2]), meter('Meter' .. spec[3])
        local action = value:GetOption('LeftMouseUpAction')
        check(action ~= '' and row:GetOption('LeftMouseUpAction') == action and label:GetOption('LeftMouseUpAction') == action,
            spec[1] .. ' row, label and value retain the same action while shown or hidden')
        if not spec[4] or visibility[spec[4]] == 1 then
        check(math.abs(row:GetY(true) - numberVariable('Inset') - rowY[spec[1]] * scale) <= 1,
            spec[1] .. ' reflows to its exact visible row position')
        check(math.abs(row:GetH() - 20 * scale) <= 1, spec[1] .. ' value frame remains 20 pixels high')
        if prior then
            check(row:GetY() - prior:GetY() >= 28 * scale - 1, spec[1] .. ' preserves at least the 28-pixel row pitch')
        end
        prior = row
        check(math.abs(label:GetX() - contentX) <= 1 and math.abs(label:GetW() - 112 * scale) <= 1,
            spec[1] .. ' label uses the compact form column')
        local arrows = stepperArrows[spec[1]]
        if arrows then
            local left, right = meter('Meter' .. arrows[1]), meter('Meter' .. arrows[2])
            check(row:GetOption('MeterStyle'):find('StyleSettingsStepperFrame', 1, true) ~= nil,
                spec[1] .. ' center uses the shared stepper border frame')
            check(value:GetOption('StringAlign'):lower() == 'center' and
                math.abs(row:GetX() - contentX - 140 * scale) <= 1 and
                math.abs(row:GetW() - contentW + 160 * scale) <= 1 and
                math.abs(value:GetW() - contentW + 166 * scale) <= 1,
                spec[1] .. ' value is centered inside the reserved frame')
            check(math.abs(value:GetX() + value:GetW() / 2 - row:GetX() - row:GetW() / 2) <= 1,
                spec[1] .. ' text and frame share their horizontal center')
            check(math.abs(left:GetX() - contentX - 120 * scale) <= 1 and
                math.abs(right:GetX() + right:GetW() - contentX - contentW) <= 1,
                spec[1] .. ' arrows occupy the ends of its settings field')
            check(label:GetX() + label:GetW() <= left:GetX() and left:GetX() + left:GetW() < row:GetX() and
                row:GetX() + row:GetW() < right:GetX(), spec[1] .. ' label, arrows and frame have separate hit targets')
            for _, arrow in ipairs({ left, right }) do
                check(math.abs(arrow:GetW() - 18 * scale) <= 1 and math.abs(arrow:GetH() - 18 * scale) <= 1 and
                    math.abs(arrow:GetY() - row:GetY() - scale) <= 1,
                    spec[1] .. ' arrow shares the centered 18-pixel stepper row')
                check(arrow:GetOption('FontColor'):gsub('%s', '') == SKIN:GetVariable('AccentColor'):gsub('%s', ''),
                    spec[1] .. ' arrows use Accent 1')
            end
            check(left:GetOption('LeftMouseUpAction') ~= '' and right:GetOption('LeftMouseUpAction') ~= '' and
                left:GetOption('LeftMouseUpAction') ~= right:GetOption('LeftMouseUpAction'),
                spec[1] .. ' arrows retain distinct backward and forward actions')
            check(math.abs(label:GetY() - value:GetY() - scale) <= 1,
                spec[1] .. ' label aligns with the centered stepper text')
        else
            check(math.abs(row:GetX() - value:GetX()) <= 1 and math.abs(row:GetW() - value:GetW()) <= 1,
                spec[1] .. ' backing matches its compact field')
            check(value:GetOption('StringAlign'):lower() == 'left', spec[1] .. ' non-stepper value retains left alignment')
            check(math.abs(value:GetX() - contentX - 120 * scale) <= 1 and
                math.abs(value:GetX() + value:GetW() - contentX - contentW) <= 1,
                spec[1] .. ' non-stepper retains the value column bounds')
            check(value:GetOption('SolidColor'):gsub('%s', '') == SKIN:GetVariable('GraphBackgroundColor'):gsub('%s', ''),
                spec[1] .. ' shades only its compact value field')
            check(math.abs(label:GetY() - value:GetY() - 2 * scale) <= 1,
                spec[1] .. ' label aligns with the padded value field')
        end
        check(label:GetX() + label:GetW() <= value:GetX(), spec[1] .. ' label stays clear of the value')
        check(value:GetX() + value:GetW() <= row:GetX() + row:GetW() + 1 and
            value:GetY() >= row:GetY() and value:GetY() + value:GetH() <= row:GetY() + row:GetH() + 1,
            spec[1] .. ' padded value stays inside its matching field backing')
        check(label:GetOption('FontColor'):gsub('%s', '') == bodyColor and
            value:GetOption('FontColor'):gsub('%s', '') == bodyColor, spec[1] .. ' text uses body TextColor')
        check(math.abs((tonumber(label:GetOption('FontSize')) or SKIN:ParseFormula(label:GetOption('FontSize'))) -
            numberVariable('FontSize') * scale) < 0.01 and
            math.abs((tonumber(value:GetOption('FontSize')) or SKIN:ParseFormula(value:GetOption('FontSize'))) -
            numberVariable('FontSize') * scale) < 0.01, spec[1] .. ' text follows the body font size')
        if number then
            local minus, plus = meter('MeterTimerMinus' .. number), meter('MeterTimerPlus' .. number)
            check(minus:GetOption('LeftMouseUpAction'):find('AdjustDuration(' .. number .. ',-1)', 1, true) ~= nil and
                plus:GetOption('LeftMouseUpAction'):find('AdjustDuration(' .. number .. ',1)', 1, true) ~= nil,
                spec[1] .. ' retains distinct minus and plus commands')
        end
        end
    end
    check(meter('MeterUtilitySettingsGlobalLink'):GetY() + meter('MeterUtilitySettingsGlobalLink'):GetH() <=
        meter('MeterGeneralSection'):GetY(), 'Shared navigation stays clear of the first settings section')
    local sectionRows = {
        { 'General', 'Width', 74 }, { 'Clock', 'ClockVisibility', 133 }, { 'Uptime', 'UptimeVisibility', 276 - clockShift },
        { 'Event', 'EventVisibility', 335 - clockShift }, { 'Timers', 'TimersVisibility', 422 - clockShift - eventShift }
    }
    for _, spec in ipairs(sectionRows) do
        local heading, rule, field = meter('Meter' .. spec[1] .. 'Section'),
            meter('Meter' .. spec[1] .. 'SectionRule'), meter('Meter' .. spec[2] .. 'Row')
        check(rule:GetOption('MeterStyle') == 'StyleRule', spec[1] .. ' section keeps divider styling distinct from a table header')
        check(math.abs(heading:GetY(true) - numberVariable('Inset') - spec[3] * scale) <= 1,
            spec[1] .. ' heading remains accessible and reflows with earlier sections')
        check(heading:GetOption('FontColor'):gsub('%s', '') == SKIN:GetVariable('AccentColor'):gsub('%s', ''),
            spec[1] .. ' settings heading uses Accent 1')
        check(math.abs((tonumber(heading:GetOption('FontSize')) or SKIN:ParseFormula(heading:GetOption('FontSize'))) -
            numberVariable('HeaderFontSize') * scale) < 0.01, spec[1] .. ' heading follows header font size')
        local halfStroke = numberVariable('DividerThickness') * scale / 2
        check(heading:GetY() + heading:GetH() <= rule:GetY(true) - halfStroke + 1 and
            rule:GetY(true) + halfStroke < field:GetY(), spec[1] .. ' section divider clears both heading and first field')
    end
    if visibility.Timers == 1 then
    check(meter('MeterListRow'):GetY() + meter('MeterListRow'):GetH() < meter('MeterStepRow'):GetY(),
        'List stepper clears the following adjustment-step row')
    check(meter('MeterTimerRow4'):GetY() + meter('MeterTimerRow4'):GetH() < meter('MeterResetNote'):GetY() and
        meter('MeterResetNote'):GetY() + meter('MeterResetNote'):GetH() < meter('MeterAdvanced'):GetY() and
        meter('MeterAdvanced'):GetY() + meter('MeterAdvanced'):GetH() < meter('MeterStatus'):GetY(),
        'Timer fields, reset guidance, advanced commands and status occupy separate rows')
    else
        check(meter('MeterTimersVisibilityRow'):GetY() + meter('MeterTimersVisibilityRow'):GetH() < meter('MeterAdvanced'):GetY(),
            'Collapsed timers leave their visibility control clear of the footer')
    end
    check(meter('MeterAdvanced'):GetX() + meter('MeterAdvanced'):GetW() < meter('MeterApply'):GetX(),
        'Advanced and Apply command targets do not overlap')
    local footerShift = clockShift + eventShift + timerShift
    check(math.abs(meter('MeterAdvanced'):GetY(true) - numberVariable('Inset') - (705 - footerShift) * scale) <= 1 and
        math.abs(meter('MeterApply'):GetY(true) - numberVariable('Inset') - (705 - footerShift) * scale) <= 1 and
        math.abs(meter('MeterStatus'):GetY(true) - numberVariable('Inset') - (725 - footerShift) * scale) <= 1,
        'Shared footer moves up by exactly the collapsed detail height')
end

local function finish(ok, message)
    stopped = true
    local report = (ok and 'PASS: ' or 'FAIL: ') .. message .. '\nSUMMARY: ' .. checks ..
        ' checks, ' .. (ok and '0' or '1') .. ' failed\n'
    write(SELF:GetOption('ResultPath'), report)
    if SELF:GetOption('Role') == 'Countdown' or not ok then SKIN:Bang('!Quit') end
end

local function menuBounds()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local width = tonumber(SKIN:GetVariable('ColumnWidth'))
    local round = function(v) return math.floor(v + 0.5) end
    local gap = 2 * round(tonumber(SKIN:GetVariable('Gutter')) * scale / 2)
    local expectedW = 2 * (round(width * scale) + gap)
    local visibility = {}
    for _, section in ipairs(sections) do visibility[section] = tonumber(savedOption('ChronometerShow' .. section)) end
    local expectedLogicalHeight = 752 - 84 * (1 - visibility.Clock) - 28 * (1 - visibility.Event) - 216 * (1 - visibility.Timers)
    check(numberVariable('PanelHeight') == expectedLogicalHeight, 'Settings height derives from saved feature visibility')
    local expectedH = round(expectedLogicalHeight * scale) + gap
    check(SKIN:GetW() == expectedW, 'Settings must occupy exactly two pitches')
    check(SKIN:GetH() == expectedH, 'Settings height must match panel geometry')
    local panel = meter('MeterPanel')
    check(panel:GetX() == gap / 2 and panel:GetY() == gap / 2, 'Settings preserves transparent gutters')
    check(panel:GetW() == expectedW - gap and panel:GetH() == expectedH - gap, 'Settings panel size')
    local title, close = meter('MeterTitle'), meter('MeterClose')
    local center = numberVariable('TitleRowCenterY')
    check(title:GetOption('StringAlign'):lower() == 'centercenter', 'Settings title remains centered')
    check(math.abs(title:GetY(true) - center) < 1 and math.abs(title:GetH() - numberVariable('TitleRowHeight')) < 1,
        'Settings title uses the shared center and row height')
    check(math.abs(close:GetY() + close:GetH() / 2 - center) <= 1,
        'Settings close control shares the title center within native pixel quantization')
    check(title:GetX() + title:GetW() <= close:GetX(), 'Settings title remains clear of the close control')
    check(title:GetY() + title:GetH() <= meter('MeterUtilitySettingsNote'):GetY() and
        close:GetY() + close:GetH() <= meter('MeterUtilitySettingsNote'):GetY(),
        'Settings header remains above the utility note')
    for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
        local item = meter(name)
        local x, y, w, h = item:GetX(), item:GetY(), item:GetW(), item:GetH()
        local shape = item:GetOption('Meter') == 'Shape'
        local hiddenOption = item:GetOption('Hidden', '0')
        local hidden = (tonumber(hiddenOption) or SKIN:ParseFormula(hiddenOption)) == 1
        local shouldHide = collapsedOwners[name] and visibility[collapsedOwners[name]] == 0 or false
        check(hidden == shouldHide, name .. ' visibility follows only its owning saved section choice')
        if hidden then
            check(w == 0 and h == 0, name .. ' hidden dimensions')
            check(math.abs(item:GetY(true) - numberVariable('Inset')) <= 1, name .. ' hidden anchor cannot extend the window')
        else
            check(w > 0 and (h > 0 or shape and h == 0), name .. ' positive native dimensions')
            check(x >= 0 and y >= 0 and x + w <= expectedW and y + h <= expectedH,
                name .. ' exceeds settings window: ' .. x .. ',' .. y .. ' ' .. w .. 'x' .. h)
            if name ~= 'MeterBounds' and name ~= 'MeterPanel' then
                check(x >= gap / 2 + 1 and y >= gap / 2 + 1 and
                    x + w <= expectedW - gap / 2 - 1 and y + h <= expectedH - gap / 2 - 1,
                    name .. ' enters settings border/gutter')
            end
        end
    end
    for _, name in ipairs({ 'MeterClockValue', 'MeterSecondsValue', 'MeterDateValue', 'MeterWidthValue',
        'MeterListName', 'MeterTimerLabel1', 'MeterTimerSeconds1' }) do
        check(meter(name):GetOption('Text') ~= '', name .. ' has a rendered settings value')
    end
    check(SKIN:GetMeasure('MeasureChronometerSettings') ~= nil, 'Settings backend loaded')
    rowLayout(visibility)
end

local function prepareProbes()
    for _, probe in ipairs(probes) do
        local source = meter('Meter' .. probe[1])
        for _, option in ipairs({ 'FontFace', 'FontSize', 'FontWeight', 'StringStyle', 'AntiAlias', 'Padding' }) do
            local value = source:GetOption(option, '')
            if value ~= '' then SKIN:Bang('!SetOption', 'MeterSettingsSmoke' .. probe[1], option, value) end
        end
        SKIN:Bang('!SetOption', 'MeterSettingsSmoke' .. probe[1], 'Text', probe[2] or source:GetOption('Text'))
        SKIN:Bang('!UpdateMeter', 'MeterSettingsSmoke' .. probe[1])
    end
end

local function probeFit()
    for _, probe in ipairs(probes) do
        local natural, target = meter('MeterSettingsSmoke' .. probe[1]), meter('Meter' .. probe[1])
        check(natural:GetW() > 0 and natural:GetH() > 0, probe[1] .. ' natural font metrics exist')
        check(natural:GetW() <= target:GetW(), probe[1] .. ' clips text width: needs ' .. natural:GetW() .. ', has ' .. target:GetW())
        check(natural:GetH() <= target:GetH(), probe[1] .. ' clips text height: needs ' .. natural:GetH() .. ', has ' .. target:GetH())
    end
end

function VerifyVisibility()
    local ok, err = pcall(function()
        local scale = tonumber(SKIN:GetVariable('Scale'))
        local expectedH = math.floor(numberVariable('ChronometerVisibleHeight') * scale + 0.5) + numberVariable('Gap')
        check(SKIN:GetH() == expectedH, 'Countdown compact height matches saved visibility after refresh')
        local names = { Clock = 'MeterClock', Uptime = 'MeterUptimeValue', Event = 'MeterEventCountdown', Timers = 'MeterTime1' }
        local mask, bit = 0, 1
        for _, section in ipairs(sections) do
            local visible = tonumber(SKIN:GetVariable('ChronometerShow' .. section))
            local item = meter(names[section])
            if visible == 0 then
                check(item:GetW() == 0 and item:GetH() == 0, section .. ' is natively hidden after settings refresh')
            else
                check(item:GetW() > 0 and item:GetH() > 0, section .. ' is natively visible after settings refresh')
            end
            mask, bit = mask + bit * visible, bit * 2
        end
        check(meter('MeterTitle'):GetW() > 0, 'Header remains available through hide/show')
        write(SELF:GetOption('VisibilityAckPath'), tostring(mask))
    end)
    if not ok then finish(false, tostring(err)) end
end

local function countdown()
    local baseline = read(SELF:GetOption('BaselinePath'))
    if baseline then
        -- Production setting saves refresh this skin. Retain the test baseline
        -- outside the skin so reloads cannot restart timers or mask reset errors.
        local deadline, columns, clock = baseline:match('^(%d+)\n(%d+)\n([^\n]+)')
        originalDeadline2, originalColumns, initialTime = tonumber(deadline), tonumber(columns), clock
        openedAt = openedAt or ticks
        local menuReport = read(SELF:GetOption('MenuResultPath'))
        if menuReport and not closedAt then
            check(menuReport:match('SUMMARY: %d+ checks, 0 failed') ~= nil, 'Settings bounds, persistence and close dispatch passed')
            closedAt = ticks
        elseif closedAt and ticks >= closedAt + 2 then
            check(SKIN:GetMeasure('MeasureChronometer') ~= nil, 'Closing settings leaves countdown loaded')
            check(SKIN:GetMeasure('MeasureEventCountdown') ~= nil, 'Event adapter survives settings refreshes')
            check(meter('MeterEventName'):GetOption('Text') == 'Countdown to Visibility event:' and
                meter('MeterEventCountdown'):GetOption('Text'):match('^%d+d %d+h %d+m %d+s$') ~= nil,
                'Saved event label and compact countdown reappear after section hide/show')
            check(read(SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state') == read(SELF:GetOption('EventBaselinePath')),
                'Visibility and unrelated settings changes preserve exact event bytes')
            check(meter('MeterState1'):GetOption('Text') == 'Ready', 'Only the changed timer resets')
            check(meter('MeterState2'):GetOption('Text') == 'Running', 'Unchanged countdown keeps running after closing settings')
            check(meter('MeterTime2'):GetOption('Text') ~= initialTime, 'Unchanged countdown advances across settings changes')
            check(snapshot().timers[2].deadline == originalDeadline2, 'Unchanged timer preserves its exact deadline')
            check(tonumber(SKIN:GetVariable('Columns')) == 3 - originalColumns, 'Countdown reloaded persisted Columns')
            check(SKIN:GetMeasure('MeasureClock'):GetOption('Format') == '%I:%M:%S %p', 'Countdown reloaded literal percent clock format')
            check(SKIN:GetMeasure('MeasureClock'):GetStringValue():match('^%d%d:%d%d:%d%d [AP]M$') ~= nil, 'Actual clock renders saved 12-hour format')
            finish(true, 'Production settings actions persisted; changed timer reset; other deadline survived refreshes and close')
        end
        check(ticks - openedAt < tonumber(SELF:GetOption('LifecycleLimitTicks', '16')), 'Settings activation or close did not complete')
    elseif ticks == 2 then
        local eventCore = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\EventCore.lua')
        local event = { enabled = true, name = 'Visibility event', deadline = os.time() + 86400 }
        event.localDate = os.date('%Y-%m-%d %H:%M:%S', event.deadline)
        local encoded = assert(eventCore.encode(event))
        write(SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state', encoded)
        write(SELF:GetOption('EventBaselinePath'), encoded)
        SKIN:Bang('!CommandMeasure', 'MeasureEventCountdown', 'Reload()')
        check(meter('MeterState1'):GetOption('Text') == 'Ready', 'Isolated timer begins ready')
        SKIN:Bang('!CommandMeasure', 'MeasureChronometer', 'Toggle(1)')
        SKIN:Bang('!CommandMeasure', 'MeasureChronometer', 'Toggle(2)')
    elseif ticks == 3 then
        check(meter('MeterState1'):GetOption('Text') == 'Running', 'Timer started before opening settings')
        check(meter('MeterState2'):GetOption('Text') == 'Running', 'Second timer started before opening settings')
        write(SELF:GetOption('BaselinePath'), string.format('%d\n%d\n%s\n', snapshot().timers[2].deadline,
            tonumber(SKIN:GetVariable('Columns')), meter('MeterTime2'):GetOption('Text')))
        click('MeterChronometerOptions')
    end
end

local function numberEvidence(message)
    local path = SELF:GetOption('InputEvidencePath')
    write(path, (read(path) or '') .. message .. '\n')
end

local function startNumberScenario(choice)
    local measure = SKIN:GetMeasure('MeasureChronometerSettingsInput')
    check(measure ~= nil, 'Production numeric RunCommand measure is loaded')
    local idle = measure:GetValue()
    numberEvidence('Numeric input ' .. choice .. ': idle GetValue=' .. tostring(idle))
    check(type(idle) == 'number' and idle ~= 0, 'Numeric helper is idle before a center click')
    numberPhase, numberWaitTicks = choice, 0
    write(SELF:GetOption('InputFixturePath'), choice)
    click('MeterTimerSeconds3')
    SKIN:Bang('!UpdateMeasure', 'MeasureChronometerSettingsInput')
    local running = measure:GetValue()
    numberEvidence('Numeric input ' .. choice .. ': after Run GetValue=' .. tostring(running))
    check(running == 0, 'Actual numeric center action starts the one-shot helper')
    check(measure:GetOption('Parameter'):find('-Key UtilityNumber -Minimum 1 -Maximum 604800 -DecimalPlaces 0', 1, true) ~= nil,
        'Production numeric launch passes the fixed duration range to the shared helper')
    check(measure:GetOption('FinishAction'):find('CommitNumberInput()', 1, true) ~= nil,
        'Production FinishAction owns numeric response commits')
end

local function advanceNumberScenario()
    local measure = SKIN:GetMeasure('MeasureChronometerSettingsInput')
    numberWaitTicks = numberWaitTicks + 1
    check(numberWaitTicks <= 8, 'One-shot numeric helper completed within its bounded fixture timeout')
    SKIN:Bang('!UpdateMeasure', 'MeasureChronometerSettingsInput')
    if measure:GetValue() == 0 then return end
    local output = measure:GetStringValue():gsub('\r?\n$', '')
    numberEvidence('Numeric input ' .. numberPhase .. ': finished GetValue=' .. tostring(measure:GetValue()) .. '; stdout=' .. output)
    if numberPhase == 'valid' then
        check(output == 'PARALLAX_INPUT_V1|ok|1599', 'Actual shared validation helper returns the accepted numeric protocol')
        check(savedOption('ChronometerList1Timer3Seconds') == '1599', 'Production FinishAction commits the typed duration')
        local saved = snapshot()
        check(saved.timers[3].duration == 1599 and saved.timers[3].status == 'idle' and saved.timers[3].deadline == 0,
            'Typed duration reaches the real timer snapshot and resets only its timer')
        check(saved.timers[2].deadline == originalDeadline2, 'Typed duration preserves the other running deadline')
        numberSavedBytes = read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc')
        startNumberScenario('invalid')
    else
        check(output == 'PARALLAX_INPUT_V1|cancel|', 'Invalid/cancel shared helper result uses the inert cancellation protocol')
        check(read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc') == numberSavedBytes,
            numberPhase .. ' numeric response writes no settings bytes')
        check(savedOption('ChronometerList1Timer3Seconds') == '1599' and snapshot().timers[2].deadline == originalDeadline2,
            numberPhase .. ' numeric response preserves saved duration and running deadline')
        if numberPhase == 'invalid' then
            startNumberScenario('cancel')
        else
            numberPhase = nil
            write(SELF:GetOption('OptionsBaselinePath'), optionsExceptVisibility())
            click('MeterClockVisibility')
        end
    end
end

local function menu()
    if ticks == 2 then
        menuBounds()
        prepareProbes()
        local saved = snapshot()
        check(saved.timers[1].status == 'running' and saved.timers[2].status == 'running', 'Both timers running before edits')
        originalDeadline1, originalDeadline2, originalDuration = saved.timers[1].deadline, saved.timers[2].deadline, saved.timers[1].duration
        originalColumns = tonumber(savedOption('Columns'))
        check(meter('MeterUtilitySettingsGlobalLink'):GetOption('LeftMouseUpAction') ==
            '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]', 'Global Settings link retains its navigation-only action')
        click('MeterUtilitySettingsGlobalLink')
        click('MeterClockValue')
    elseif ticks == 3 then
        probeFit()
        check(read(SELF:GetOption('NavigationAckPath')) == 'isolated global settings opened',
            'Actual Global Settings link activates only the isolated navigation target')
        check(savedOption('ChronometerClockFormat') == '%I:%M:%S %p', 'Clock action persisted exact percent format')
        check(meter('MeterClockValue'):GetOption('Text') == '12-hour', 'Clock settings readout updated')
        local saved = snapshot()
        check(saved.timers[1].deadline == originalDeadline1 and saved.timers[2].deadline == originalDeadline2,
            'Clock change preserved both timer deadlines')
        click('MeterTimerPlus1')
    elseif ticks == 4 then
        check(tonumber(savedOption('ChronometerList1Timer1Seconds')) == originalDuration + 60, 'Duration action persisted selected one-minute step')
        local saved = snapshot()
        check(saved.timers[1].status == 'idle' and saved.timers[1].duration == originalDuration + 60 and saved.timers[1].deadline == 0,
            'Changing duration resets only its timer in native snapshot')
        check(saved.timers[2].status == 'running' and saved.timers[2].deadline == originalDeadline2,
            'Other running timer retains exact deadline during duration edit')
        click(originalColumns == 1 and 'MeterWidthIncrease' or 'MeterWidthDecrease')
    elseif ticks == 5 then
        check(tonumber(savedOption('Columns')) == 3 - originalColumns, 'Width action persisted opposite column count')
        check(meter('MeterWidthValue'):GetOption('Text') == (3 - originalColumns == 2 and '2 columns' or '1 column'), 'Width settings readout updated')
        menuBounds()
        if SELF:GetOption('NumberInputEnabled', '0') == '1' then
            startNumberScenario('valid')
        else
            write(SELF:GetOption('OptionsBaselinePath'), optionsExceptVisibility())
            click('MeterClockVisibility')
        end
    elseif ticks >= 6 and ticks <= 13 then
        local section = visibilityClicks[ticks - 5]
        local expected = ticks <= 9 and '0' or '1'
        check(savedOption('ChronometerShow' .. section) == expected, section .. ' toggle persists its flag')
        check(meter('Meter' .. section .. 'Visibility'):GetOption('Text') == (expected == '0' and 'Hidden' or 'Shown'), section .. ' settings readout updates')
        SKIN:Bang('!CommandMeasure', 'MeasureSettingsLifecycleSmoke', 'VerifyVisibility()', 'Parallax\\Chronometer')
        local mask, bit = 0, 1
        for _, name in ipairs(sections) do mask, bit = mask + bit * tonumber(savedOption('ChronometerShow' .. name)), bit * 2 end
        check(tonumber(read(SELF:GetOption('VisibilityAckPath'))) == mask, 'Refreshed native countdown acknowledges the saved visibility combination')
        check(snapshot().timers[2].deadline == originalDeadline2, 'Section toggle preserves the running timer deadline')
        check(read(SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state') == read(SELF:GetOption('EventBaselinePath')),
            'Section toggle preserves the saved event')
        check(optionsExceptVisibility() == read(SELF:GetOption('OptionsBaselinePath')),
            'Section toggle preserves every unrelated saved option and timer duration')
        menuBounds()
        if ticks == 9 then
            if SELF:GetOption('NumberInputEnabled', '0') == '1' then
                local launchLog = read(SELF:GetOption('InputLaunchLogPath'))
                local before = read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc')
                click('MeterStepValue')
                click('MeterTimerSeconds3')
                SKIN:Bang('!UpdateMeasure', 'MeasureChronometerSettingsInput')
                check(SKIN:GetMeasure('MeasureChronometerSettingsInput'):GetValue() ~= 0 and
                    read(SELF:GetOption('InputLaunchLogPath')) == launchLog, 'Hidden numeric targets launch no helper')
                check(read(SKIN:GetVariable('@') .. 'User\\Chronometer.inc') == before, 'Hidden numeric targets write no settings')
                numberEvidence('Hidden Step and duration center actions: no helper launch or settings write.')
            end
            write(SELF:GetOption('ReopenStatePath'), string.format('%d\n%d\n', checks, originalDeadline2))
            SKIN:Bang('!Refresh')
        elseif ticks < 13 then
            click('Meter' .. visibilityClicks[ticks - 4] .. 'Visibility')
        else
        probeFit()
        local action = meter('MeterClose'):GetOption('LeftMouseUpAction')
        check(action ~= '', 'Settings close has a native action')
        finish(true, 'Production settings bounds, typography, persistence, visibility toggles and close action passed')
        SKIN:Bang(action)
        end
    end
end

function Update()
    if stopped then return 0 end
    if numberPhase then
        local ok, err = pcall(advanceNumberScenario)
        if not ok then finish(false, tostring(err)) end
        return 0
    end
    ticks = ticks + 1
    local ok, err = pcall(function()
        if SELF:GetOption('Role') == 'Navigation' then
            write(SELF:GetOption('NavigationAckPath'), 'isolated global settings opened')
            stopped = true
            SKIN:Bang('!DeactivateConfig')
        elseif SELF:GetOption('Role') == 'Countdown' then
            countdown()
        elseif ticks == 1 and (read(SELF:GetOption('ReopenStatePath')) or '') ~= '' then
            local count, deadline = read(SELF:GetOption('ReopenStatePath')):match('^(%d+)\n(%d+)\n$')
            check(count ~= nil and deadline ~= nil, 'Isolated menu refresh retains its test continuation state')
            reopenPending = { checks = tonumber(count), deadline = tonumber(deadline) }
        elseif ticks == 2 and reopenPending then
            checks, originalDeadline2 = reopenPending.checks, reopenPending.deadline
            menuBounds()
            check(numberVariable('PanelHeight') == 424, 'Initially refreshed all-hidden menu starts at the collapsed height')
            check(snapshot().timers[2].deadline == originalDeadline2, 'Refreshing collapsed settings preserves the running deadline')
            check(optionsExceptVisibility() == read(SELF:GetOption('OptionsBaselinePath')),
                'Refreshing collapsed settings preserves every unrelated saved option')
            prepareProbes()
            write(SELF:GetOption('ReopenStatePath'), '')
            ticks, reopenPending = 9, nil
            click('MeterClockVisibility')
        else menu() end
    end)
    if not ok then finish(false, tostring(err)) end
    return 0
end
