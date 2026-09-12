-- Original Parallax tests. Runs against production Core.lua and Store.lua in Lua 5.1.
local Suite = {}

function Suite.run(Core, Store, options)
    local lines, passed, failed = { 'Parallax Chronometer logic and persistence tests', 'Runtime: ' .. _VERSION }, 0, 0
    local function equal(actual, expected, message)
        if actual ~= expected then
            error((message or 'Unexpected value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
        end
    end
    local function check(value, message) if not value then error(message or 'Assertion failed', 2) end end
    local function test(name, fn)
        local ok, err = pcall(fn)
        if ok then passed = passed + 1; lines[#lines + 1] = 'PASS ' .. name
        else failed = failed + 1; lines[#lines + 1] = 'FAIL ' .. name .. ': ' .. tostring(err) end
    end
    local function durations()
        return { 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200 }
    end
    local function fresh() return Core.new(durations()) end
    local function write(path, contents)
        local file = assert(io.open(path, 'wb')); assert(file:write(contents)); assert(file:close())
    end
    local function signed(body)
        local sum = 0
        for i = 1, #body do sum = (sum * 31 + body:byte(i)) % 65521 end
        return body .. 'END|' .. tostring(sum) .. '\n'
    end
    local function replaceLine(text, index, replacement)
        local body, rows = text:match('^(.*\n)END|%d+\n$'), {}
        for row in body:gmatch('([^\n]*)\n') do rows[#rows + 1] = row end
        rows[index] = replacement
        return signed(table.concat(rows, '\n') .. '\n')
    end
    local function withOpen(fake, fn)
        local original = io.open
        io.open = fake
        local ok, err = pcall(fn)
        io.open = original
        if not ok then error(err, 0) end
    end
    local function path(name) return options.directory .. '/' .. name end
    local function adapterFixture(overrides)
        local fixture = { now = 1000, writes = 0, logs = 0, displayed = {}, variables = {}, saved = nil, fail = false }
        local variables = fixture.variables
        variables['@'], variables.SETTINGSPATH = 'test-resources/', options.directory .. '/'
        for list = 1, 3 do
            variables['ChronometerList' .. list .. 'Name'] = 'List ' .. list
            for row = 1, 4 do
                local key = 'ChronometerList' .. list .. 'Timer' .. row
                variables[key .. 'Seconds'] = '100'
                variables[key .. 'Label'] = 'Timer ' .. list .. '/' .. row
            end
        end
        for key, value in pairs(overrides or {}) do variables[key] = value end
        local storeMock = {}
        function storeMock.open(prefix)
            fixture.prefix = prefix
            return {}, fixture.saved and assert(Core.decode(Core.encode(fixture.saved, fixture.saved.generation))), fixture.corrupt or false
        end
        function storeMock.save(_, state)
            fixture.writes = fixture.writes + 1
            if fixture.fail then return false end
            state.generation = (fixture.saved and fixture.saved.generation or 0) + 1
            fixture.saved = assert(Core.decode(Core.encode(state, state.generation)))
            return true
        end
        local skin = {}
        function skin:GetVariable(key, fallback)
            if variables[key] ~= nil then return variables[key] end
            return fallback or ''
        end
        function skin:Bang(command, meter, key, value)
            if command == '!SetOption' then fixture.displayed[meter .. ':' .. key] = value end
            if command == '!Log' then fixture.logs = fixture.logs + 1 end
        end
        function fixture.load()
            local env = setmetatable({ SKIN = skin, os = { time = function() return fixture.now end } }, { __index = _G })
            env.dofile = function(file)
                if file:match('Core%.lua$') then return Core end
                if file:match('Store%.lua$') then return storeMock end
                error('Unexpected adapter source: ' .. file)
            end
            local chunk = assert(loadfile(options.moduleRoot .. '/Chronometer.lua'))
            setfenv(chunk, env); chunk()
            fixture.env = env
            env.Initialize(); env.Update()
        end
        fixture.load()
        return fixture
    end

    test('duration accepts integer seconds and supported bounds', function()
        equal(Core.duration(1), 1); equal(Core.duration('604800'), 604800)
        equal(Core.duration('00090'), 90); equal(Core.duration(120), 120)
    end)
    test('duration rejects nondecimal, fractional, unsafe and invalid values', function()
        local invalid = { '', '1.5', ' 10', '10 ', '+10', '-1', '1e2', '0x10', '1;os.execute("x")', 'abc', '0', '604801', 0, -1, 0.5, 604801, math.huge, -math.huge, 0/0, true, false, {} }
        for _, value in ipairs(invalid) do equal(Core.duration(value), nil, tostring(value)) end
        equal(Core.duration(nil), nil)
    end)
    test('invalid configuration creates disabled slots', function()
        local state = Core.new({ 'bad', 0, 1 })
        equal(#state.timers, 12); equal(state.timers[1].status, 'disabled')
        equal(state.timers[2].status, 'disabled'); equal(state.timers[3].status, 'idle')
        equal(state.timers[12].status, 'disabled'); equal(Core.toggle(state, 1, 1000), false)
        equal(Core.reset(state, 1), false); equal(Core.toggle(state, 13, 1000), false)
    end)
    test('start pause resume and reset retain correct seconds', function()
        local state = fresh()
        check(Core.toggle(state, 1, 1000)); equal(state.timers[1].deadline, 1100)
        equal(Core.remaining(state.timers[1], 1030), 70)
        check(Core.toggle(state, 1, 1030)); equal(state.timers[1].status, 'paused')
        equal(Core.remaining(state.timers[1], 9000), 70); equal(state.timers[1].deadline, 0)
        check(Core.toggle(state, 1, 9000)); equal(state.timers[1].deadline, 9070)
        check(Core.reset(state, 1)); equal(state.timers[1].status, 'idle')
        equal(state.timers[1].remaining, 100); equal(state.timers[1].deadline, 0)
    end)
    test('expiry is exact, nonnegative and changes once', function()
        local state = fresh(); Core.toggle(state, 1, 1000)
        equal(Core.tick(state, 1099), false); equal(Core.remaining(state.timers[1], 1099), 1)
        equal(Core.tick(state, 1100), true); equal(state.timers[1].status, 'done')
        equal(Core.remaining(state.timers[1], 9000), 0); equal(Core.tick(state, 9000), false)
        Core.toggle(state, 1, 9000); equal(state.timers[1].deadline, 9100)
    end)
    test('pausing an overdue countdown completes it', function()
        local state = fresh(); Core.toggle(state, 1, 1000); Core.toggle(state, 1, 1300)
        equal(state.timers[1].status, 'done'); equal(state.timers[1].remaining, 0)
    end)
    test('all lists continue while another list is selected', function()
        local state = fresh()
        Core.toggle(state, 1, 1000); Core.toggle(state, 5, 1000); Core.toggle(state, 9, 1000)
        Core.select(state, 1); equal(state.selected, 2); Core.tick(state, 1500)
        equal(state.timers[1].status, 'done'); equal(state.timers[5].status, 'done')
        equal(state.timers[9].status, 'running'); equal(Core.remaining(state.timers[9], 1500), 400)
    end)
    test('list selection wraps in either direction', function()
        local state = fresh(); Core.select(state, -1); equal(state.selected, 3)
        Core.select(state, 1); equal(state.selected, 1)
        Core.select(state, 5); equal(state.selected, 3)
    end)
    test('forward clock adjustment or suspend consumes wall time', function()
        local state = fresh(); Core.toggle(state, 1, 1000)
        equal(Core.remaining(state.timers[1], 1080), 20)
        check(Core.tick(state, 10000)); equal(state.timers[1].status, 'done')
    end)
    test('backward clock adjustment extends a running countdown', function()
        local state = fresh(); Core.toggle(state, 1, 1000)
        equal(Core.remaining(state.timers[1], 900), 200)
        Core.toggle(state, 1, 900); equal(state.timers[1].remaining, 200)
        local loaded = assert(Core.decode(Core.encode(state, 1)))
        equal(loaded.timers[1].remaining, 200); Core.toggle(loaded, 1, 5000)
        equal(loaded.timers[1].deadline, 5200)
    end)
    test('restart preserves deadline and catches expiry while unloaded', function()
        local state = fresh(); Core.toggle(state, 1, 1000); Core.select(state, 2)
        local loaded = assert(Core.decode(Core.encode(state, 7)))
        equal(loaded.selected, 3); equal(loaded.generation, 7)
        equal(Core.remaining(loaded.timers[1], 1060), 40)
        check(Core.tick(loaded, 9999)); equal(loaded.timers[1].status, 'done')
    end)
    test('unchanged durations preserve state independently of labels', function()
        local state = fresh(); Core.toggle(state, 1, 1000); Core.select(state, 1)
        state.generation = 9
        local reconciled, changed = Core.reconcile(state, durations())
        equal(changed, false); equal(reconciled.selected, 2); equal(reconciled.generation, 9)
        equal(reconciled.timers[1].deadline, 1100)
        check(reconciled.timers[1] ~= state.timers[1], 'Reconciliation must not alias saved timers')
        equal(reconciled.timers[1].label, nil, 'Labels are configuration, not persisted identity')
    end)
    test('duration edits reset only changed slots and handle invalid edits', function()
        local state = fresh(); Core.toggle(state, 1, 1000); Core.toggle(state, 2, 1000)
        local values = durations(); values[1], values[3] = 90, 'invalid'
        local reconciled, changed = Core.reconcile(state, values)
        check(changed); equal(reconciled.timers[1].status, 'idle')
        equal(reconciled.timers[1].remaining, 90); equal(reconciled.timers[2].deadline, 1200)
        equal(reconciled.timers[3].status, 'disabled')
    end)
    test('new installation reconciles defaults without a saved state', function()
        local state, changed = Core.reconcile(nil, durations())
        equal(changed, false); equal(state.selected, 1); equal(state.generation, 0)
    end)
    test('display formatting covers seconds, hours, days and zero clamp', function()
        equal(Core.format(-1), '00:00:00'); equal(Core.format(59.9), '00:00:59')
        equal(Core.format(3600), '01:00:00'); equal(Core.format(86400), '1d 00:00:00')
        equal(Core.format(604800), '7d 00:00:00')
    end)
    test('persisted format roundtrips all allowed timer statuses', function()
        local values = durations(); values[5] = 0
        local state = Core.new(values)
        Core.toggle(state, 2, 1000); Core.toggle(state, 3, 1000); Core.toggle(state, 3, 1010)
        Core.toggle(state, 4, 0); Core.tick(state, 400)
        local loaded = assert(Core.decode(Core.encode(state, 4)))
        local statuses = { 'idle', 'running', 'paused', 'done', 'disabled' }
        for i, status in ipairs(statuses) do equal(loaded.timers[i].status, status) end
        equal(loaded.timers[2].deadline, 1200); equal(loaded.timers[3].remaining, 290)
    end)
    test('snapshot numeric formatting preserves post-2038 and large integer values', function()
        for _, number in ipairs({ 2147483648, 4294967296, 9007199254740990 }) do
            local state = fresh()
            state.timers[1].status, state.timers[1].deadline = 'running', number
            local loaded = assert(Core.decode(Core.encode(state, number)))
            equal(loaded.generation, number); equal(loaded.timers[1].deadline, number)
        end
    end)
    test('corruption, truncation, oversized data and executable input are rejected', function()
        local text = Core.encode(fresh(), 1)
        for i = 0, #text - 1 do equal(Core.decode(text:sub(1, i)), nil, 'Truncation at byte ' .. i) end
        equal(Core.decode(text:gsub('100|idle', '101|idle', 1)), nil)
        equal(Core.decode(text .. 'extra'), nil); equal(Core.decode(string.rep('x', 8193)), nil)
        equal(Core.decode('os.execute("must not run")'), nil); equal(Core.decode(nil), nil)
    end)
    test('checksum-valid invalid schema fields are rejected', function()
        local text = Core.encode(fresh(), 1)
        local invalidRows = {
            '2|100|idle|100|0', '1|604801|idle|604801|0', '1|0|idle|0|0',
            '1|100|idle|99|0', '1|100|idle|100|1', '1|100|paused|0|0',
            '1|100|paused|10|20', '1|100|running|0|1234', '1|100|running|20|0',
            '1|100|done|1|0', '1|100|done|0|1', '1|100|disabled|0|0',
            '1|100|arbitrary|1|0', '1|100|idle|100|-1', '1|100|idle|1e2|0',
            '1|100|paused|9007199254740992|0'
        }
        for _, row in ipairs(invalidRows) do equal(Core.decode(replaceLine(text, 3, row)), nil, row) end
        for _, header in ipairs({ '0|1', '1|0', '1|4', '1.0|1', '9007199254740991|1' }) do
            equal(Core.decode(replaceLine(text, 2, header)), nil, header)
        end
        equal(Core.decode(replaceLine(text, 1, 'PARALLAX_CHRONOMETER_V2')), nil)
    end)
    test('store opens missing state without reporting corruption', function()
        local store, state, corrupt = Store.open(path('missing'), Core)
        equal(state, nil); equal(corrupt, false); equal(store.generation, 0); equal(store.slot, nil)
    end)
    test('store alternates snapshots and chooses newest valid generation', function()
        local prefix, state = path('alternate'), fresh()
        local store = Store.open(prefix, Core)
        check(Store.save(store, state)); equal(store.slot, 'a'); equal(state.generation, 1)
        Core.toggle(state, 1, 1000); check(Store.save(store, state))
        equal(store.slot, 'b'); equal(state.generation, 2)
        local loadedStore, loaded, corrupt = Store.open(prefix, Core)
        equal(corrupt, false); equal(loadedStore.slot, 'b'); equal(loaded.generation, 2)
        equal(loaded.timers[1].deadline, 1100)
        Core.toggle(loaded, 1, 1030); check(Store.save(loadedStore, loaded))
        equal(loadedStore.slot, 'a'); equal(loaded.generation, 3)
    end)
    test('corrupt latest snapshot recovers the previous complete save', function()
        local prefix, state = path('recover'), fresh(); local store = Store.open(prefix, Core)
        check(Store.save(store, state)); Core.select(state, 1); check(Store.save(store, state))
        write(prefix .. '.b.state', 'PARALLAX_CHRONOMETER_V1\n2|2\n')
        local recoveredStore, recovered, corrupt = Store.open(prefix, Core)
        check(corrupt); equal(recoveredStore.slot, 'a'); equal(recovered.generation, 1)
        equal(recovered.selected, 1); check(Store.save(recoveredStore, recovered))
        local _, saved, stillCorrupt = Store.open(prefix, Core)
        equal(stillCorrupt, false); equal(saved.generation, 2)
    end)
    test('both corrupt snapshots produce no invented recovered state', function()
        local prefix = path('both-corrupt')
        write(prefix .. '.a.state', 'broken a'); write(prefix .. '.b.state', 'broken b')
        local store, state, corrupt = Store.open(prefix, Core)
        check(corrupt); equal(state, nil); equal(store.generation, 0)
    end)
    test('invalid directory save fails without advancing state generation', function()
        local state = fresh(); local store = Store.open(path('no-such-directory/state'), Core)
        equal(Store.save(store, state), false); equal(store.generation, 0)
        equal(store.slot, nil); equal(state.generation, 0)
    end)
    test('read-only snapshot save fails without advancing state generation', function()
        check(options.readOnlyPrefix, 'Runner must prepare a read-only first-slot fixture')
        local state = fresh(); local store = Store.open(options.readOnlyPrefix, Core)
        equal(Store.save(store, state), false); equal(store.generation, 0); equal(state.generation, 0)
    end)
    test('partial write failure retains previous in-memory slot and generation', function()
        local store = { prefix = 'mock', core = Core, slot = 'a', generation = 7 }
        local state = fresh(); state.generation = 7
        withOpen(function(_, mode)
            equal(mode, 'wb')
            return { write = function() return nil, 'simulated disk full' end, close = function() return true end }
        end, function() equal(Store.save(store, state), false) end)
        equal(store.slot, 'a'); equal(store.generation, 7); equal(state.generation, 7)
    end)
    test('close failure retains previous generation', function()
        local store = { prefix = 'mock', core = Core, slot = 'b', generation = 7 }; local state = fresh()
        withOpen(function()
            return { write = function() return true end, close = function() return nil, 'simulated close failure' end }
        end, function() equal(Store.save(store, state), false) end)
        equal(store.slot, 'b'); equal(store.generation, 7)
    end)
    test('post-write verification failure retains previous generation', function()
        local store = { prefix = 'mock', core = Core, slot = 'a', generation = 7 }; local state = fresh()
        withOpen(function(_, mode)
            if mode == 'wb' then return { write = function() return true end, close = function() return true end } end
            return { read = function() return 'corrupted after write' end, close = function() return true end }
        end, function() equal(Store.save(store, state), false) end)
        equal(store.slot, 'a'); equal(store.generation, 7)
    end)
    test('engine ticks never open files or save per second', function()
        local state, calls = fresh(), 0; Core.toggle(state, 1, 1000)
        withOpen(function() calls = calls + 1; error('Unexpected file access') end, function()
            for now = 1000, 1200 do Core.tick(state, now); Core.remaining(state.timers[1], now) end
        end)
        equal(calls, 0); equal(state.timers[1].status, 'done')
    end)
    test('adapter saves controls immediately without writes on ordinary ticks', function()
        local f = adapterFixture(); equal(f.writes, 0)
        f.env.Toggle(1); equal(f.writes, 1); equal(f.saved.timers[1].deadline, 1100)
        for now = 1001, 1030 do f.now = now; f.env.Update() end
        equal(f.writes, 1); equal(f.displayed['MeterTime1:Text'], '00:01:10')
        f.env.Toggle(1); equal(f.writes, 2); equal(f.saved.timers[1].remaining, 70)
        f.env.Reset(1); equal(f.writes, 3); equal(f.saved.timers[1].status, 'idle')
        f.env.SelectList(1); equal(f.writes, 4); equal(f.saved.selected, 2)
    end)
    test('adapter completion saves once for simultaneous timers across lists', function()
        local f = adapterFixture(); f.env.Toggle(1); f.env.SelectList(1); f.env.Toggle(1)
        equal(f.writes, 3); f.now = 1100; f.env.Update()
        equal(f.writes, 4); equal(f.saved.timers[1].status, 'done'); equal(f.saved.timers[5].status, 'done')
        for i = 1, 120 do f.now = f.now + 1; f.env.Update() end
        equal(f.writes, 4); equal(f.displayed['MeterPersistence:Text'], 'All lists: 0 running / 2 done')
    end)
    test('adapter failed saves retry after 60 ticks without log spam', function()
        local f = adapterFixture(); f.fail = true; f.env.Toggle(1)
        equal(f.writes, 1); equal(f.logs, 1)
        equal(f.displayed['MeterPersistence:Text'], 'NOT SAVED - see Rainmeter log')
        for i = 1, 59 do f.env.Update() end
        equal(f.writes, 1); f.env.Update(); equal(f.writes, 2); equal(f.logs, 1)
        f.fail = false
        for i = 1, 60 do f.env.Update() end
        equal(f.writes, 3); equal(f.saved.timers[1].status, 'running')
        equal(f.displayed['MeterPersistence:Text'], 'All lists: 1 running / 0 done')
    end)
    test('adapter refresh retains selected list, running deadline and paused duration', function()
        local f = adapterFixture(); f.env.Toggle(1); f.env.Toggle(2)
        f.now = 1020; f.env.Toggle(2); f.env.SelectList(1)
        local writes = f.writes; f.now = 1030; f.load()
        equal(f.writes, writes); equal(f.displayed['MeterList:Text'], '2/3  List 2')
        f.env.SelectList(-1)
        equal(f.displayed['MeterTime1:Text'], '00:01:10'); equal(f.displayed['MeterState1:Text'], 'Running')
        equal(f.displayed['MeterTime2:Text'], '00:01:20'); equal(f.displayed['MeterState2:Text'], 'Paused')
        equal(f.saved.timers[1].deadline, 1100); equal(f.saved.timers[2].remaining, 80)
    end)
    test('adapter restart after elapsed offline deadline saves completed state', function()
        local f = adapterFixture(); f.env.Toggle(1); local writes = f.writes
        f.now = 5000; f.load(); equal(f.writes, writes + 1)
        equal(f.saved.timers[1].status, 'done'); equal(f.displayed['MeterTime1:Text'], '00:00:00')
    end)
    test('adapter renders reserved label delimiters inert and retains timer state on rename', function()
        local f = adapterFixture({ ChronometerList1Timer1Label = '[&Measure:Run()] #VAR# %1\nlabel', ChronometerList1Name = '[!Quit]' })
        equal(f.displayed['MeterLabel1:Text']:find('[%c#%%%[%]]'), nil)
        equal(f.displayed['MeterList:Text']:find('[%c#%%%[%]]'), nil)
        check(f.displayed['MeterLabel1:Text']:find('label', 1, true))
        f.env.Toggle(1); f.variables.ChronometerList1Timer1Label = 'Renamed safely'; f.now = 1020; f.load()
        equal(f.displayed['MeterLabel1:Text'], 'Renamed safely')
        equal(f.displayed['MeterState1:Text'], 'Running'); equal(f.displayed['MeterTime1:Text'], '00:01:20')
    end)
    test('adapter invalid duration is disabled and duration edits reset only their slot', function()
        local f = adapterFixture({ ChronometerList1Timer1Seconds = 'os.execute("x")' })
        equal(f.displayed['MeterState1:Text'], 'Fix duration'); equal(f.displayed['MeterTime1:Text'], '--:--:--')
        f.env.Toggle(1); equal(f.writes, 0)
        f.env.Toggle(2); f.env.Toggle(3); f.variables.ChronometerList1Timer2Seconds = '90'; f.load()
        equal(f.displayed['MeterState2:Text'], 'Ready'); equal(f.displayed['MeterTime2:Text'], '00:01:30')
        equal(f.displayed['MeterState3:Text'], 'Running'); equal(f.saved.timers[3].deadline, 1100)
    end)
    test('adapter rejects out-of-range and nonnumeric row commands', function()
        local f = adapterFixture()
        for _, value in ipairs({ 0, -1, 5, 1.5, '1', '1);os.execute("x")', false, {}, math.huge, 0/0 }) do
            f.env.Toggle(value); f.env.Reset(value)
        end
        f.env.Toggle(nil); f.env.Reset(nil)
        for _, value in ipairs({ 0, 2, '-1', false, {} }) do f.env.SelectList(value) end
        equal(f.writes, 0); equal(f.displayed['MeterList:Text'], '1/3  List 1')
    end)
    test('adapter corruption and missing writable settings show honest status', function()
        local f = adapterFixture(); f.corrupt = true; f.load()
        equal(f.displayed['MeterPersistence:Text'], 'State unreadable - timers reset')
        f.variables.SETTINGSPATH = ''; f.load()
        equal(f.displayed['MeterPersistence:Text'], 'NOT SAVED - see Rainmeter log')
    end)

    local settingsSuite = dofile(options.moduleRoot .. '/Tests/SettingsSuite.lua')
    settingsSuite.register(options, test, equal, check)
    local eventSuite = dofile(options.moduleRoot .. '/Tests/EventSuite.lua')
    eventSuite.register(options, test, equal, check)
    lines[#lines + 1] = string.format('SUMMARY: %d passed, %d failed', passed, failed)
    return table.concat(lines, '\n') .. '\n', failed
end

return Suite
