-- Controller checks use the real Lua settings code with a bounded Rainmeter mock.
local Suite = {}
function Suite.register(options, test, equal, check)
    local function fixture(overrides, encoding)
        local f = { displayed = {}, writes = {}, refreshes = {}, failWrite = false, content = nil }
        f.variables = { ['@'] = 'test-resources/', Columns = '1', ChronometerClockFormat = '%H:%M:%S', ChronometerDateFormat = '%A, %d %B %Y' }
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
        local skin = {}
        function skin:GetVariable(key, fallback) return f.variables[key] or fallback end
        function skin:Bang(command, a, b, c, d)
            if command == '!SetOption' then f.displayed[a] = c
            elseif command == '!WriteKeyValue' then
                f.writes[#f.writes + 1] = { section = a, key = b, value = c, path = d }
                if not f.failWrite then
                    local replacements
                    f.raw, replacements = f.raw:gsub('(' .. b .. '=)[^\r\n]*', function(prefix) return prefix .. c end)
                    if replacements == 0 then f.raw = f.raw .. b .. '=' .. c .. '\r\n' end
                    f.content = encode(f.raw)
                end
            elseif command == '!Refresh' then f.refreshes[#f.refreshes + 1] = a
            else check(command == '!UpdateMeterGroup' or command == '!Redraw', 'Unexpected bang: ' .. command) end
        end
        local environment = setmetatable({ SKIN = skin, io = {
            open = function(path, mode)
                equal(path, 'test-resources/User\\Chronometer.inc'); equal(mode, 'rb')
                if not f.content then return nil end
                return { read = function(_, size) return f.content:sub(1, size) end, close = function() return true end }
            end
        } }, { __index = _G })
        local chunk = assert(loadfile(options.moduleRoot .. '/Settings.lua'))
        setfenv(chunk, environment); chunk()
        f.env = environment
        environment.Initialize(); environment.Update()
        return f
    end
    test('settings initialize without writing and show selected list', function()
        local f = fixture()
        equal(#f.writes, 0); equal(#f.refreshes, 0)
        equal(f.displayed.MeterClockValue, '24-hour'); equal(f.displayed.MeterSecondsValue, 'Shown')
        equal(f.displayed.MeterListName, '1 / 3  List 1'); equal(f.displayed.MeterStepValue, 'Step: 1 min')
        equal(f.displayed.MeterTimerSeconds1, '00:02:00')
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
        end
        equal(#f.writes, 0)
        check(f.env.ToggleSection('Clock'))
        equal(f.writes[1].key, 'ChronometerShowClock'); equal(f.writes[1].value, '0')
        f.env.Initialize(); f.env.Update()
        equal(f.displayed.MeterClockVisibility, 'Hidden')
    end)
    for _, section in ipairs({ 'Clock', 'Uptime', 'Event', 'Timers' }) do
        test('settings ' .. section .. ' visibility persists both flips without timer edits', function()
            local key = 'ChronometerShow' .. section
            local f = fixture({ [key] = '1' })
            check(f.env.ToggleSection(section))
            equal(f.writes[1].key, key); equal(f.writes[1].value, '0')
            f.env.Initialize(); f.env.Update()
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Hidden')
            check(f.env.ToggleSection(section))
            equal(f.writes[2].key, key); equal(f.writes[2].value, '1')
            f.env.Initialize(); f.env.Update()
            equal(f.displayed['Meter' .. section .. 'Visibility'], 'Shown')
            equal(#f.writes, 2); equal(#f.refreshes, 2)
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
        f.env.CycleStep(); equal(f.displayed.MeterStepValue, 'Step: 5 min')
        f.env.AdjustDuration(1, 1); equal(f.writes[2].value, '361')
        f.env.CycleStep(); f.env.CycleStep(); equal(f.displayed.MeterStepValue, 'Step: 1 sec')
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
        equal(#f.writes, 0)
    end)
    test('settings failed writes are visible and do not refresh or claim success', function()
        local f = fixture(); f.failWrite = true
        equal(f.env.ToggleColumns(), false); equal(#f.refreshes, 0)
        equal(f.displayed.MeterWidthValue, '1 column'); equal(f.displayed.MeterStatus, 'Save failed. Check file permissions.')
        f.content = nil; equal(f.env.ToggleColumns(), false); equal(#f.writes, 1)
        equal(f.displayed.MeterStatus, 'Cannot read Chronometer settings.')
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
