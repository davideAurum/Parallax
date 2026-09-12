-- Appended only to copied production skins in the isolated settings smoke.
local ticks, checks, stopped = 0, 0, false
local openedAt, closedAt, initialTime
local originalColumns, originalDuration, originalDeadline1, originalDeadline2
local sections = { 'Clock', 'Uptime', 'Event', 'Timers' }
local visibilityClicks = { 'Clock', 'Uptime', 'Event', 'Timers', 'Clock', 'Uptime', 'Event', 'Timers' }
local probes = {
    { 'Title', 'Chronometer settings' }, { 'ClockVisibility', 'Hidden' },
    { 'TimerSeconds1', '7d 00:00:00' }, { 'Status', 'Saved. Changed timer reset.' }
}

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

local function click(name)
    local action = meter(name):GetOption('LeftMouseUpAction')
    check(action ~= '', name .. ' has a native action')
    SKIN:Bang(action)
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
    local expectedH = round(tonumber(SKIN:GetVariable('PanelHeight')) * scale) + gap
    check(SKIN:GetW() == expectedW, 'Settings must occupy exactly two pitches')
    check(SKIN:GetH() == expectedH, 'Settings height must match panel geometry')
    local panel = meter('MeterPanel')
    check(panel:GetX() == gap / 2 and panel:GetY() == gap / 2, 'Settings preserves transparent gutters')
    check(panel:GetW() == expectedW - gap and panel:GetH() == expectedH - gap, 'Settings panel size')
    for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
        local item = meter(name)
        local x, y, w, h = item:GetX(), item:GetY(), item:GetW(), item:GetH()
        local shape = item:GetOption('Meter') == 'Shape'
        if item:GetOption('Hidden', '0') == '1' then
            check(w == 0 and h == 0, name .. ' hidden dimensions')
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
end

local function prepareProbes()
    for _, probe in ipairs(probes) do
        local source = meter('Meter' .. probe[1])
        for _, option in ipairs({ 'FontFace', 'FontSize', 'FontWeight', 'StringStyle', 'AntiAlias', 'Padding' }) do
            local value = source:GetOption(option, '')
            if value ~= '' then SKIN:Bang('!SetOption', 'MeterSettingsSmoke' .. probe[1], option, value) end
        end
        SKIN:Bang('!SetOption', 'MeterSettingsSmoke' .. probe[1], 'Text', probe[2])
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
        check(ticks - openedAt < 16, 'Settings activation or close did not complete')
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

local function menu()
    if ticks == 2 then
        menuBounds()
        prepareProbes()
        local saved = snapshot()
        check(saved.timers[1].status == 'running' and saved.timers[2].status == 'running', 'Both timers running before edits')
        originalDeadline1, originalDeadline2, originalDuration = saved.timers[1].deadline, saved.timers[2].deadline, saved.timers[1].duration
        originalColumns = tonumber(savedOption('Columns'))
        click('MeterClockValue')
    elseif ticks == 3 then
        probeFit()
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
        click('MeterWidthValue')
    elseif ticks == 5 then
        check(tonumber(savedOption('Columns')) == 3 - originalColumns, 'Width action persisted opposite column count')
        check(meter('MeterWidthValue'):GetOption('Text') == (3 - originalColumns == 2 and '2 columns' or '1 column'), 'Width settings readout updated')
        menuBounds()
        click('MeterClockVisibility')
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
        if ticks < 13 then
            click('Meter' .. visibilityClicks[ticks - 4] .. 'Visibility')
        else
        menuBounds()
        local action = meter('MeterClose'):GetOption('LeftMouseUpAction')
        check(action ~= '', 'Settings close has a native action')
        finish(true, 'Production settings bounds, typography, persistence, visibility toggles and close action passed')
        SKIN:Bang(action)
        end
    end
end

function Update()
    if stopped then return 0 end
    ticks = ticks + 1
    local ok, err = pcall(function()
        if SELF:GetOption('Role') == 'Countdown' then
            countdown()
        else menu() end
    end)
    if not ok then finish(false, tostring(err)) end
    return 0
end
