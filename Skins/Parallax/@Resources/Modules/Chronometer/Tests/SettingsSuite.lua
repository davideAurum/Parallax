-- Controller checks use the real Lua settings code with a bounded Rainmeter mock.
local Suite = {}
function Suite.register(options, test, equal, check)
    local function fixture(overrides, encoding)
        local f = { displayed = {}, meterOptions = {}, writes = {}, refreshes = {}, failWrite = false, content = nil }
        f.variables = { ['@'] = 'test-resources/', Columns = '1', Scale = '1', Gutter = '8', Gap = '8', ChronometerClockFormat = '%H:%M:%S', ChronometerDateFormat = '%A, %d %B %Y' }
        for list = 1, 3 do
            f.variables['ChronometerList' .. list .. 'Name'] = 'List ' .. list
            for row = 1, 4 do
                f.variables['ChronometerList' .. list .. 'Timer' .. row .. 'Label'] = 'Timer ' .. list .. '/' .. row
                f.variables['ChronometerList' .. list .. 'Timer' .. row .. 'Seconds'] = '120'
            end
        end
        for key, value in pairs(overrides or {}) do f.variables[key] = value end
        local function encode(text)
            if encoding == 'utf16le' then return '\255\254' .. text:gsub('.', function(c) return c .. '\0' end) end
            if encoding == 'utf16be' then return '\254\255' .. text:gsub('.', function(c) return '\0' .. c end) end
            return (encoding == 'utf8bom' and '\239\187\191' or '') .. text
        end
        local rows = { '; keep this comment', '[Variables]', 'Unrelated=keep me' }
        for key, value in pairs(f.variables) do if key ~= '@' then rows[#rows + 1] = key .. '=' .. value end end
        f.raw = table.concat(rows, '\r\n') .. '\r\n'
        f.content = encode(f.raw)
        f.input = { output = '', exit = -1, runs = 0, helper = true, measure = true, meter = true, width = 160, height = 20 }
        function f.setSaved(key, value)
            local replacements
            f.raw, replacements = f.raw:gsub('(' .. key .. '=)[^\r\n]*', function(prefix) return prefix .. value end)
            if replacements == 0 then f.raw = f.raw .. key .. '=' .. value .. '\r\n' end
            f.content = encode(f.raw)
        end
        local skin = {}
        function skin:GetVariable(key, fallback) return f.variables[key] or fallback end
        function skin:GetX() return 100 end
        function skin:GetY() return 200 end
        function skin:GetMeasure(name)
            equal(name, 'MeasureChronometerSettingsInput')
            if not f.input.measure then return nil end
            return { GetValue = function() return f.input.exit end, GetStringValue = function() return f.input.output end }
        end
        function skin:GetMeter(name)
            check(name == 'MeterWidthRow' or name == 'MeterStepRow' or name:match('^MeterTimerRow[1-4]$'), 'Unexpected input meter')
            if not f.input.meter then return nil end
            return { GetX = function() return 140 end, GetY = function() return 160 end,
                GetW = function() return f.input.width end, GetH = function() return f.input.height end }
        end
        function skin:Bang(command, a, b, c, d)
            if command == '!SetOption' then
                f.meterOptions[a] = f.meterOptions[a] or {}
                f.meterOptions[a][b] = c
                if b == 'Text' then f.displayed[a] = c end
            elseif command == '!SetVariable' then f.variables[a] = tostring(b)
            elseif command == '!WriteKeyValue' then
                f.writes[#f.writes + 1] = { section = a, key = b, value = c, path = d }
                if not f.failWrite then f.setSaved(b, c) end
            elseif command == '!CommandMeasure' then
                equal(a, 'MeasureChronometerSettingsInput'); equal(b, 'Run')
                f.input.runs = f.input.runs + 1; f.input.exit = 0
            elseif command == '!Refresh' then f.refreshes[#f.refreshes + 1] = a
            else check(command == '!UpdateMeterGroup' or command == '!UpdateMeter' or command == '!UpdateMeasure' or command == '!Redraw', 'Unexpected bang: ' .. command) end
        end
        local environment = setmetatable({ SKIN = skin, io = {
            open = function(path, mode)
                equal(mode, 'rb')
                if path == 'test-resources/Scripts\\SettingsInput.ps1' then
                    if not f.input.helper then return nil end
                    return { close = function() return true end }
                end
                equal(path, 'test-resources/User\\Chronometer.inc')
                if not f.content then return nil end
                return { read = function(_, size) return f.content:sub(1, size) end, close = function() return true end }
            end
        } }, { __index = _G })
        local chunk = assert(loadfile(options.moduleRoot .. '/Settings.lua'))
        setfenv(chunk, environment); chunk()
        f.env = environment
        function f.finish(output)
            f.input.output, f.input.exit = output, 1
            return environment.CommitNumberInput()
        end
        environment.Initialize(); environment.Update()
        return f
    end
    test('settings initialize without writing and show selected list', function()
        local f = fixture()
        equal(#f.writes, 0); equal(#f.refreshes, 0)
        equal(f.displayed.MeterClockValue, '24-hour'); equal(f.displayed.MeterSecondsValue, 'Shown')
        equal(f.displayed.MeterListName, '1 / 3  List 1'); equal(f.displayed.MeterStepValue, '1 min')
        equal(f.displayed.MeterTimerSeconds1, '00:02:00')
        check(f.meterOptions.MeterListName.ToolTipText:find('List 1', 1, true))
        equal(f.meterOptions.MeterListLabel.ToolTipText, f.meterOptions.MeterListName.ToolTipText)
        check(f.meterOptions.MeterTimerLabel1.ToolTipText:find('Timer 1/1: 00:02:00', 1, true))
        check(f.meterOptions.MeterTimerSeconds1.ToolTipText:find('Changing duration resets this timer.', 1, true))
    end)
    test('settings clock toggles retain the seconds choice and refresh only Chronometer', function()
        local f = fixture(); f.env.ToggleSeconds(); f.env.CycleClock()
        equal(f.writes[1].value, '%H:%M'); equal(f.writes[2].value, '%I:%M %p')
        equal(f.displayed.MeterClockValue, '12-hour'); equal(f.displayed.MeterSecondsValue, 'Hidden')
        equal(#f.refreshes, 2)
        for _, config in ipairs(f.refreshes) do equal(config, 'Parallax\\Chronometer') end
        equal(f.writes[1].path, 'test-resources/User\\Chronometer.inc')
    end)
    test('settings custom clock format is honest and switches to a supported choice', function()
        local f = fixture({ ChronometerClockFormat = '%X' }); equal(f.displayed.MeterClockValue, 'Custom')
        f.env.CycleClock(); equal(f.writes[1].value, '%I:%M %p')
    end)
    test('settings date and width controls roundtrip', function()
        local f = fixture(); f.env.CycleDate(); equal(f.displayed.MeterDateValue, 'Short')
        f.env.CycleDate(); equal(f.displayed.MeterDateValue, 'ISO')
        f.env.CycleDate(); equal(f.displayed.MeterDateValue, 'Full')
        f.env.ToggleColumns(); equal(f.displayed.MeterWidthValue, '2 columns')
        f.env.ToggleColumns(); equal(f.displayed.MeterWidthValue, '1 column')
    end)
    test('settings missing visibility keys default to shown and can be saved', function()
        local f = fixture()
        for _, section in ipairs({ 'Clock', 'Uptime', 'Event', 'Timers' }) do
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Shown')
            equal(f.variables['ChronometerShow' .. section], '1')
        end
        equal(#f.writes, 0)
        equal(tonumber(f.variables.PanelHeight), 752)
        equal(tonumber(f.variables.PanelHeightPx), 752)
        equal(tonumber(f.variables.WindowHeight), 760)
        check(f.env.ToggleSection('Clock'))
        equal(f.writes[1].key, 'ChronometerShowClock'); equal(f.writes[1].value, '0')
        equal(f.variables.ChronometerShowClock, '0')
        equal(tonumber(f.variables.PanelHeight), 668)
        equal(tonumber(f.variables.PanelHeightPx), 668)
        equal(tonumber(f.variables.WindowHeight), 676)
        f.env.Initialize(); f.env.Update()
        equal(f.displayed.MeterClockVisibility, 'Hidden')
    end)
    for _, section in ipairs({ 'Clock', 'Uptime', 'Event', 'Timers' }) do
        test('settings ' .. section .. ' visibility persists both flips without timer edits', function()
            local key = 'ChronometerShow' .. section
            local f = fixture({ [key] = '1', PanelHeight = '401', Columns = '1' })
            local collapsedHeight = ({ Clock = 668, Uptime = 752, Event = 724, Timers = 536 })[section]
            check(f.env.ToggleSection(section))
            equal(f.writes[1].key, key); equal(f.writes[1].value, '0')
            equal(f.variables[key], '0')
            equal(tonumber(f.variables.PanelHeight), collapsedHeight)
            equal(tonumber(f.variables.PanelHeightPx), collapsedHeight)
            equal(tonumber(f.variables.WindowHeight), collapsedHeight + 8)
            f.env.Initialize(); f.env.Update()
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Hidden')
            check(f.env.ToggleSection(section))
            equal(f.writes[2].key, key); equal(f.writes[2].value, '1')
            equal(f.variables[key], '1')
            f.env.Initialize(); f.env.Update()
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Shown')
            equal(#f.writes, 2); equal(#f.refreshes, 2)
            equal(tonumber(f.variables.PanelHeight), 752)
            equal(tonumber(f.variables.PanelHeightPx), 752)
            equal(tonumber(f.variables.WindowHeight), 760)
            equal(f.variables.Columns, '1')
            check(f.raw:find('PanelHeight=401', 1, true)); check(f.raw:find('Columns=1', 1, true))
            for _, config in ipairs(f.refreshes) do equal(config, 'Parallax\\Chronometer') end
            for list = 1, 3 do
                for row = 1, 4 do
                    check(f.raw:find('ChronometerList' .. list .. 'Timer' .. row .. 'Seconds=120', 1, true))
                end
            end
        end)
    end
    test('settings visibility rejects invalid section callbacks without writes', function()
        local f = fixture()
        for _, value in ipairs({ '', 'clock', 'Date', 'Clock);run()', 1, false, {} }) do
            equal(f.env.ToggleSection(value), false)
        end
        equal(f.env.ToggleSection(nil), false)
        equal(#f.writes, 0); equal(#f.refreshes, 0)
    end)
    test('settings visibility write failures retain visible state and do not refresh', function()
        local f = fixture(); f.failWrite = true
        for _, section in ipairs({ 'Clock', 'Uptime', 'Event', 'Timers' }) do
            equal(f.env.ToggleSection(section), false)
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Shown')
            equal(f.variables['ChronometerShow' .. section], '1')
            equal(tonumber(f.variables.PanelHeight), 752)
            equal(tonumber(f.variables.PanelHeightPx), 752)
            equal(tonumber(f.variables.WindowHeight), 760)
        end
        equal(#f.writes, 4); equal(#f.refreshes, 0)
        equal(f.displayed.MeterStatus, 'Save failed. Check file permissions.')
    end)
    test('settings list navigation wraps without changing active timers or persisting view', function()
        local f = fixture(); f.env.SelectList(-1)
        equal(f.displayed.MeterListName, '3 / 3  List 3')
        equal(f.displayed.MeterTimerLabel1, 'Timer 3/1')
        f.env.SelectList(1); equal(f.displayed.MeterListName, '1 / 3  List 1')
        equal(#f.writes, 0); equal(#f.refreshes, 0)
    end)
    test('settings duration preset updates only the selected timer key', function()
        local f = fixture(); f.env.SelectList(1); f.env.CycleDuration(3)
        equal(#f.writes, 1); equal(f.writes[1].key, 'ChronometerList2Timer3Seconds')
        equal(f.writes[1].value, '300'); equal(f.displayed.MeterTimerSeconds3, '00:05:00')
        equal(f.displayed.MeterTimerSeconds2, '00:02:00')
    end)
    test('settings invalid duration repairs to the first preset', function()
        local f = fixture({ ChronometerList1Timer1Seconds = 'bad' })
        equal(f.displayed.MeterTimerSeconds1, 'Fix duration')
        f.env.AdjustDuration(1, -1); equal(f.writes[1].value, '60')
    end)
    test('settings duration steps cycle and clamp at one second and seven days', function()
        local f = fixture({ ChronometerList1Timer1Seconds = '1', ChronometerList1Timer2Seconds = '604800' })
        f.env.AdjustDuration(1, -1); f.env.AdjustDuration(2, 1); equal(#f.writes, 0)
        equal(f.displayed.MeterTimerSeconds2, '7d 00:00:00')
        f.env.AdjustDuration(1, 1); equal(f.writes[1].value, '61')
        f.env.CycleStep(); equal(f.displayed.MeterStepValue, '5 min')
        f.env.AdjustDuration(1, 1); equal(f.writes[2].value, '361')
        f.env.CycleStep(); f.env.CycleStep(); equal(f.displayed.MeterStepValue, '1 sec')
        f.env.AdjustDuration(1, -1); equal(f.writes[3].value, '360')
    end)
    test('settings last duration preset wraps to one minute', function()
        local f = fixture({ ChronometerList1Timer1Seconds = '604800' })
        f.env.CycleDuration(1); equal(f.writes[1].value, '60')
    end)
    test('settings refuse invalid callback coordinates without writes', function()
        local f = fixture()
        for _, value in ipairs({ 0, 5, -1, 1.5, {}, false, '1);run()', math.huge }) do
            equal(f.env.CycleDuration(value), false); equal(f.env.AdjustDuration(value, 1), false)
        end
        for _, value in ipairs({ 0, 2, '1', {}, false }) do
            equal(f.env.AdjustDuration(1, value), false); equal(f.env.SelectList(value), false)
        end
        equal(#f.writes, 0)
    end)
    test('settings display sanitizes label expansion syntax without rewriting it', function()
        local f = fixture({ ChronometerList1Name = '[&Run:go()] #var# %PATH%' })
        check(not f.displayed.MeterListName:find('[%[%]#%%]'))
        check(not f.meterOptions.MeterListName.ToolTipText:find('[%[%]#%%]'))
        equal(#f.writes, 0)
    end)
    test('settings failed writes are visible and do not refresh or claim success', function()
        local f = fixture(); f.failWrite = true
        equal(f.env.ToggleColumns(), false); equal(#f.refreshes, 0)
        equal(f.displayed.MeterWidthValue, '1 column'); equal(f.displayed.MeterStatus, 'Save failed. Check file permissions.')
        f.content = nil; equal(f.env.ToggleColumns(), false); equal(#f.writes, 1)
        equal(f.displayed.MeterStatus, 'Cannot read Chronometer settings.')
    end)
    test('settings numeric arrows clamp without wrapping or writing at limits', function()
        local f = fixture({ ChronometerList1Timer1Seconds = '1', ChronometerList1Timer2Seconds = '604800' })
        equal(f.env.AdjustColumns(-1), false); equal(#f.writes, 0)
        check(f.env.AdjustColumns(1)); equal(f.writes[1].value, '2')
        equal(f.env.AdjustColumns(1), false); equal(#f.writes, 1)
        check(f.env.AdjustColumns(-1)); equal(f.writes[2].value, '1')
        check(f.env.AdjustStep(-1)); equal(f.displayed.MeterStepValue, '1 sec')
        equal(f.env.AdjustStep(-1), false)
        check(f.env.AdjustStep(1)); check(f.env.AdjustStep(1)); check(f.env.AdjustStep(1))
        equal(f.displayed.MeterStepValue, '1 hour'); equal(f.env.AdjustStep(1), false)
        equal(f.env.AdjustDuration(1, -1), false); equal(f.env.AdjustDuration(2, 1), false)
        equal(#f.writes, 2); equal(#f.refreshes, 2)
        for _, direction in ipairs({ 0, 2, '1', {}, false }) do
            equal(f.env.AdjustColumns(direction), false); equal(f.env.AdjustStep(direction), false)
        end
    end)
    test('settings clock and date arrows wrap in both directions without invalid actions', function()
        local f = fixture()
        check(f.env.CycleDate(-1)); equal(f.displayed.MeterDateValue, 'ISO')
        check(f.env.CycleDate(1)); equal(f.displayed.MeterDateValue, 'Full')
        check(f.env.CycleClock(-1)); equal(f.displayed.MeterClockValue, '12-hour')
        check(f.env.CycleClock(1)); equal(f.displayed.MeterClockValue, '24-hour')
        for _, direction in ipairs({ 0, 2, '1', {}, false }) do
            equal(f.env.CycleClock(direction), false); equal(f.env.CycleDate(direction), false)
        end
        equal(#f.writes, 4)
    end)
    test('settings typed duration launches canonical arguments and accepts one captured result', function()
        local f = fixture(); f.env.SelectList(1)
        check(f.env.BeginNumberInput('Duration', 3)); equal(f.input.runs, 1); equal(#f.writes, 0)
        local args = f.meterOptions.MeasureChronometerSettingsInput.Parameter
        check(args:find('-File "test-resources/Scripts\\SettingsInput.ps1" -Key UtilityNumber', 1, true))
        check(args:find('-Minimum 1 -Maximum 604800 -DecimalPlaces 0 -Initial "120"', 1, true))
        check(args:find('-X 240 -Y 360 -Width 160 -Height 20 -Scale 1.0000', 1, true))
        equal(f.env.BeginNumberInput('Columns'), false); equal(f.env.CommitNumberInput(), false)
        equal(f.input.runs, 1)
        check(f.finish('PARALLAX_INPUT_V1|ok|+000360\r\n'))
        equal(#f.writes, 1); equal(f.writes[1].key, 'ChronometerList2Timer3Seconds'); equal(f.writes[1].value, '360')
        equal(f.displayed.MeterTimerSeconds3, '00:06:00'); equal(f.displayed.MeterTimerSeconds2, '00:02:00')
        equal(f.finish('PARALLAX_INPUT_V1|ok|7200'), false); equal(#f.writes, 1)
    end)
    test('settings typed columns persist while adjustment steps remain session-only', function()
        local f = fixture()
        check(f.env.BeginNumberInput('Columns')); check(f.finish('PARALLAX_INPUT_V1|ok|2\n'))
        equal(f.displayed.MeterWidthValue, '2 columns'); equal(#f.writes, 1)
        check(f.env.BeginNumberInput('Columns')); equal(f.finish('PARALLAX_INPUT_V1|ok|2'), false)
        check(f.env.BeginNumberInput('Step')); check(f.finish('PARALLAX_INPUT_V1|ok|300'))
        equal(f.displayed.MeterStepValue, '5 min'); equal(#f.writes, 1)
        check(f.env.AdjustDuration(1, 1)); equal(f.writes[2].value, '420')
        check(f.env.BeginNumberInput('Step')); equal(f.finish('PARALLAX_INPUT_V1|ok|300'), false)
        equal(#f.writes, 2); f.env.Initialize(); f.env.Update(); equal(f.displayed.MeterStepValue, '1 min')
    end)
    test('settings typed input rejects malformed, suffixed and out-of-range data', function()
        local f = fixture()
        for _, output in ipairs({
            'PARALLAX_INPUT_V2|ok|2', 'PARALLAX_INPUT_V1|ok|0', 'PARALLAX_INPUT_V1|ok|-1',
            'PARALLAX_INPUT_V1|ok|3', 'PARALLAX_INPUT_V1|ok|2.0', 'PARALLAX_INPUT_V1|ok|1e0',
            'PARALLAX_INPUT_V1|ok|2 columns', 'PARALLAX_INPUT_V1|ok| 2', 'PARALLAX_INPUT_V1|ok|2 ',
            'PARALLAX_INPUT_V1|ok|2\n\n', 'PARALLAX_INPUT_V1|ok|2\r', 'PARALLAX_INPUT_V1|ok|2\nignored',
            'PARALLAX_INPUT_V1|ok|[!Execute]', 'PARALLAX_INPUT_V1|ok|#Columns#',
            'PARALLAX_INPUT_V1|cancel|2', 'PARALLAX_INPUT_V1|ok|' .. string.rep('9', 100), 2
        }) do
            check(f.env.BeginNumberInput('Columns')); equal(f.finish(output), false)
        end
        check(f.env.BeginNumberInput('Step')); equal(f.finish('PARALLAX_INPUT_V1|ok|2'), false)
        check(f.env.BeginNumberInput('Duration', 1)); equal(f.finish('PARALLAX_INPUT_V1|ok|604801'), false)
        equal(#f.writes, 0); equal(#f.refreshes, 0); equal(f.displayed.MeterStepValue, '1 min')
    end)
    test('settings numeric cancellation writes nothing and allows another edit', function()
        local f = fixture()
        for _, target in ipairs({ 'Columns', 'Step', 'Duration' }) do
            check(f.env.BeginNumberInput(target, target == 'Duration' and 1 or nil))
            equal(f.finish('PARALLAX_INPUT_V1|cancel|\r\n'), false)
            equal(f.env.CommitNumberInput(), false)
        end
        equal(#f.writes, 0); equal(#f.refreshes, 0)
        check(f.env.BeginNumberInput('Columns')); check(f.finish('PARALLAX_INPUT_V1|ok|2'))
    end)
    test('settings reject stale typed results after list, visibility or saved value changes', function()
        local f = fixture()
        check(f.env.BeginNumberInput('Duration', 1)); f.env.SelectList(1)
        equal(f.finish('PARALLAX_INPUT_V1|ok|600'), false); equal(#f.writes, 0)
        check(f.env.BeginNumberInput('Duration', 1)); f.env.SelectList(1); f.env.SelectList(-1)
        equal(f.finish('PARALLAX_INPUT_V1|ok|600'), false); equal(#f.writes, 0)
        check(f.env.BeginNumberInput('Duration', 1)); f.setSaved('ChronometerList2Timer1Seconds', '900')
        equal(f.finish('PARALLAX_INPUT_V1|ok|600'), false); equal(#f.writes, 0)
        check(f.env.BeginNumberInput('Duration', 1)); check(f.env.ToggleSection('Timers'))
        equal(f.finish('PARALLAX_INPUT_V1|ok|600'), false); equal(#f.writes, 1)
        equal(f.writes[1].key, 'ChronometerShowTimers')
        check(f.env.BeginNumberInput('Columns')); f.setSaved('Columns', '2')
        equal(f.finish('PARALLAX_INPUT_V1|ok|1'), false); equal(#f.writes, 1)
    end)
    test('settings reject stale session-step results and unreadable finish state', function()
        local f = fixture()
        check(f.env.BeginNumberInput('Step')); check(f.env.AdjustStep(1))
        equal(f.finish('PARALLAX_INPUT_V1|ok|1'), false); equal(f.displayed.MeterStepValue, '5 min')
        check(f.env.BeginNumberInput('Columns')); f.content = nil
        equal(f.finish('PARALLAX_INPUT_V1|ok|2'), false)
        equal(#f.writes, 0); equal(#f.refreshes, 0)
    end)
    test('settings numeric editor fails honestly for missing helper, runtime or visible field', function()
        local f = fixture()
        for _, missing in ipairs({ 'helper', 'measure', 'meter' }) do
            f.input[missing] = false
            equal(f.env.BeginNumberInput('Columns'), false)
            check(f.displayed.MeterStatus:find('unavailable', 1, true) or f.displayed.MeterStatus:find('missing', 1, true))
            f.input[missing] = true
        end
        f.input.exit = 0; equal(f.env.BeginNumberInput('Columns'), false); f.input.exit = -1
        f.input.width = 0; equal(f.env.BeginNumberInput('Columns'), false); f.input.width = 160
        f.setSaved('ChronometerShowTimers', '0')
        equal(f.env.BeginNumberInput('Step'), false); equal(f.env.BeginNumberInput('Duration', 1), false)
        for _, target in ipairs({ 'Bad', '', 1, {}, false }) do equal(f.env.BeginNumberInput(target), false) end
        for _, row in ipairs({ 0, 5, {}, '1);run()', false }) do equal(f.env.BeginNumberInput('Duration', row), false) end
        equal(f.env.BeginNumberInput('Columns', 1), false); equal(f.env.BeginNumberInput('Step', 1), false)
        equal(f.input.runs, 0); equal(#f.writes, 0)
    end)
    test('settings invalid saved duration opens with safe initial data and saves only accepted input', function()
        local f = fixture({ ChronometerList1Timer1Seconds = 'bad' })
        check(f.env.BeginNumberInput('Duration', 1)); equal(#f.writes, 0)
        check(f.meterOptions.MeasureChronometerSettingsInput.Parameter:find('-Initial "60"', 1, true))
        equal(f.finish('PARALLAX_INPUT_V1|cancel|'), false); equal(#f.writes, 0)
        check(f.env.BeginNumberInput('Duration', 1)); check(f.finish('PARALLAX_INPUT_V1|ok|75'))
        equal(f.writes[1].key, 'ChronometerList1Timer1Seconds'); equal(f.writes[1].value, '75')
    end)
    test('settings typed save failures retain previous values and never refresh', function()
        local f = fixture(); check(f.env.BeginNumberInput('Columns')); f.failWrite = true
        equal(f.finish('PARALLAX_INPUT_V1|ok|2'), false)
        equal(f.displayed.MeterWidthValue, '1 column'); equal(#f.writes, 1); equal(#f.refreshes, 0)
        equal(f.displayed.MeterStatus, 'Save failed. Check file permissions.')
    end)
    for _, encoding in ipairs({ 'utf8bom', 'utf16le', 'utf16be' }) do
        test('settings scalar readback supports ' .. encoding, function()
            local f = fixture(nil, encoding); f.env.ToggleColumns()
            equal(f.displayed.MeterWidthValue, '2 columns'); equal(#f.refreshes, 1)
            check(f.raw:find('; keep this comment', 1, true)); check(f.raw:find('Unrelated=keep me', 1, true))
        end)
    end
end
return Suite
