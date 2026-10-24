-- Developer-only checks for the Parallax\Idle coordinator and its consumer
-- link. Every SKIN call, file, clock and Bang is injected; nothing reaches
-- Rainmeter, the file system or another process. Lua 5.1 (Rainmeter's own, or
-- OBS's LuaJIT through ctypes). Suite.Run(coordinatorPath, linkPath) returns a
-- report and raises on the first failure.
local Suite = {}

local function utf16le(text)
    local out = { '\255\254' }
    for index = 1, #text do out[#out + 1] = text:sub(index, index) .. '\0' end
    return table.concat(out)
end

function Suite.Run(coordinatorPath, linkPath)
    local passed, cases, notes = 0, {}, {}
    local function check(ok, message) if not ok then error(message, 2) end passed = passed + 1 end
    local function equal(actual, expected, message)
        if actual ~= expected then
            error((message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
        end
        passed = passed + 1
    end
    local function scenario(name, body)
        local before = passed
        local ok, message = pcall(body)
        if not ok then error(name .. ': ' .. tostring(message), 0) end
        cases[#cases + 1] = name .. ': ' .. (passed - before) .. ' assertions'
    end

    local resources = 'C:\\Fixture\\Skins\\Parallax\\@Resources\\'
    local skins = 'C:\\Fixture\\Skins\\'
    local settingsPath = 'C:\\Fixture\\Settings\\'
    local settingsFile = settingsPath .. 'Rainmeter.ini'
    local idleIni = skins .. 'Parallax\\Idle\\Idle.ini'
    local mediaInc = resources .. 'User\\Media.inc'
    local stateInc = resources .. 'Modules\\Media\\CaptureState.inc'

    -- A fresh coordinator or link environment. options.files: path -> text
    -- (or false for an unreadable file); options.variables override SKIN
    -- variables; options.idle is the raw IDLE_TIME value; options.clock is
    -- os.clock() (nil: unusable). Bangs are recorded in three lists: reads
    -- (!UpdateMeasure of the raw measure, where Rainmeter reads the network
    -- table), arms (the coordinator's own [!Delay] tick chain) and everything
    -- else (bangs).
    local function fixture(options)
        options = options or {}
        local state = { bangs = {}, reads = {}, arms = {}, updates = 0, now = options.now or 1000000, clock = options.clock, idle = options.idle, files = {} }
        for path, text in pairs(options.files or {}) do state.files[path] = text end
        local variables = {
            ['@'] = resources, ROOTCONFIG = 'Parallax', SETTINGSPATH = settingsPath, SKINSPATH = skins,
            ParallaxIdleTestFile = '', ParallaxIdleTestAwaySeconds = '', ParallaxIdleTestReevaluateTicks = '',
            ParallaxIdleTestHeartbeatTicks = '', ParallaxIdleTestPauseSeconds = '', IdlePauseMinutes = '0'
        }
        for key, value in pairs(options.variables or {}) do variables[key] = value end
        state.variables = variables
        local skin = {}
        function skin:GetVariable(name, default)
            local value = variables[name]
            if value == nil then return default end
            return value
        end
        function skin:GetMeasure(name)
            assert(name == 'MeasureParallaxIdleRaw', 'Only the raw idle measure is read')
            if state.idle == false then return nil end
            return { GetValue = function() return state.idle end }
        end
        function skin:ReplaceVariables(text)
            assert(text == '#ParallaxIdleTickMs#', 'Only the clamped tick is expanded')
            return options.tick or '2000'
        end
        function skin:ParseFormula(text) return tonumber(text) end
        function skin:Bang(...)
            local args = { ... }
            for _, value in ipairs(args) do assert(type(value) == 'string', 'Bang arguments are strings') end
            local bang = table.concat(args, ' ')
            -- Rainmeter's own update of the coordinator measure: skipped while
            -- the measure is paused (state.paused), like a skin timer's.
            if bang == '!UpdateMeasure MeasureParallaxIdle' then
                state.updates = state.updates + 1
                if not state.paused then state.env.Update() end
                return
            end
            local list = state.bangs
            if bang == '!UpdateMeasure MeasureParallaxIdleRaw' then list = state.reads
            elseif bang:sub(1, 8) == '[!Delay ' then list = state.arms end
            list[#list + 1] = bang
        end
        local fakeIo = { open = function(path, mode)
            assert(mode == 'rb', 'Files are opened read-only')
            local text = state.files[path]
            if text == nil then return nil, 'missing', 2 end
            if text == false then return nil, 'denied', 5 end
            return {
                read = function(_, limit) assert(type(limit) == 'number' and limit <= 4194305, 'Reads are bounded'); return text:sub(1, limit) end,
                close = function() return true end
            }
        end }
        setmetatable(fakeIo, { __index = function(_, key) error('Unexpected io.' .. tostring(key)) end })
        local fakeOs = { time = function() return state.now end, clock = function() return state.clock end }
        setmetatable(fakeOs, { __index = function(_, key) error('Unexpected os.' .. tostring(key)) end })
        local env = setmetatable({ SKIN = skin, io = fakeIo, os = fakeOs }, { __index = _G })
        env.dofile = function(path)
            assert(path == resources .. 'Idle\\Link.lua', 'The coordinator loads only the shared link')
            local chunk = assert(loadfile(linkPath))
            setfenv(chunk, env)
            return chunk()
        end
        state.env, state.skin = env, skin
        function state.load()
            local chunk = assert(loadfile(coordinatorPath))
            setfenv(chunk, env)
            chunk()
            env.Initialize()
            equal(#state.bangs + #state.reads + #state.arms, 0, 'Initialize sends nothing')
        end
        function state.link()
            local chunk = assert(loadfile(linkPath))
            setfenv(chunk, env)
            return chunk().new(skin)
        end
        function state.reset() state.bangs, state.reads, state.arms = {}, {}, {} end
        -- One tick dt seconds later with the raw idle (or the test file) at idle.
        function state.step(dt, idle, path)
            state.now = state.now + dt
            if state.clock then state.clock = state.clock + math.max(dt, 0) end
            if path then state.files[path] = tostring(idle) else state.idle = idle end
            return state.env.Update()
        end
        function state.count(prefix)
            local count = 0
            for _, bang in ipairs(state.bangs) do if bang:sub(1, #prefix) == prefix then count = count + 1 end end
            return count
        end
        return state
    end

    local function broadcastOf(away, paused, beat)
        return {
            '!SetVariableGroup ParallaxIdleAway ' .. away .. ' Parallax',
            '!SetVariableGroup ParallaxIdlePaused ' .. paused .. ' Parallax',
            '!SetVariableGroup ParallaxIdleBeat ' .. beat .. ' Parallax',
            '!SetVariableGroup ParallaxIdleSync 1 Parallax',
            '!UpdateMeasureGroup ParallaxIdleHook *'
        }
    end
    local function expectBroadcast(state, away, message, paused)
        local expected = broadcastOf(away, paused or '0', string.format('%d', state.now))
        equal(#state.bangs, #expected, message .. ' (bang count)')
        for index, bang in ipairs(expected) do equal(state.bangs[index], bang, message .. ' (bang ' .. index .. ')') end
    end
    local function rainmeterIni(sections, encoding)
        local lines = { '[Rainmeter]', 'SkinPath=' .. skins }
        for _, section in ipairs(sections) do
            lines[#lines + 1] = '[' .. section[1] .. ']'
            if section[2] ~= nil then lines[#lines + 1] = 'Active=' .. section[2] end
            lines[#lines + 1] = 'WindowX=10'
        end
        local text = table.concat(lines, '\r\n') .. '\r\n'
        if encoding == 'utf16' then return utf16le(text) end
        return text
    end

    scenario('wrap guard keeps idle time within a second for k = 0..3', function()
        local state = fixture()
        state.load()
        local step = 4294967296
        for k = 0, 3 do
            for _, seconds in ipairs({ 0, 0.3, 0.7, 1.5, 299, 301 }) do
                -- MeasureSysInfo: (GetTickCount64() - dwTime) / 1000, integer.
                local raw = math.floor((seconds * 1000 + k * step) / 1000)
                local value = state.env.Wrap(raw)
                check(value ~= nil and value >= 0, 'Wrapped value exists for k=' .. k .. ', d=' .. seconds)
                check(math.abs(value - seconds) < 1, 'Within a second for k=' .. k .. ', d=' .. seconds .. ': ' .. tostring(value))
                equal(value >= 300, seconds >= 300, 'Away threshold for k=' .. k .. ', d=' .. seconds)
            end
        end
        -- A plain modulo would read the first second after input as 49.7 days.
        equal(4294967 % 4294967.296, 4294967, 'The unguarded modulo reads 49.7 days')
        equal(state.env.Wrap(4294967), 0, 'Just below a whole step reads 0')
    end)

    scenario('NaN, negative and missing raw values are rejected', function()
        local state = fixture({ idle = 600 })
        state.load()
        equal(state.env.Wrap(0 / 0), nil, 'NaN')
        equal(state.env.Wrap(-1), nil, 'Negative')
        equal(state.env.Wrap(math.huge), nil, 'Infinite')
        equal(state.env.Wrap(nil), nil, 'Missing')
        state.env.Start()
        state.reset()
        -- Away, so every tick reads.
        state.step(2, 0 / 0)
        equal(#state.reads, 1, 'Away: the tick reads')
        equal(#state.bangs, 0, 'An invalid sample keeps the last state and sends nothing')
        state.step(2, -5)
        equal(#state.bangs, 0, 'A negative sample keeps the last state')
        state.step(2, false)
        equal(#state.bangs, 0, 'A missing measure keeps the last state')
        equal(#state.reads, 3, 'One reading per tick while away')
        -- Not away: an invalid reading leaves no estimate, so the next tick reads again.
        local active = fixture({ idle = 0 })
        active.load()
        active.env.Start()
        active.reset()
        active.step(2, 1)
        equal(#active.reads, 0, 'Not away and far from 300 s: no reading')
        active.now = active.now + 11
        active.step(0, 0 / 0)
        equal(#active.reads, 1, 'A tick gap forces a reading')
        active.reset()
        active.step(2, 2)
        equal(#active.reads, 1, 'After an invalid reading the next tick reads')
        active.reset()
        active.step(2, 4)
        equal(#active.reads, 0, 'A valid reading resumes the skipping')
    end)

    scenario('nothing is sent before Start, and Sync before Start is ignored', function()
        -- Nothing needs this coordinator (no Media), so only a request could
        -- unload it before its regular 300-tick check.
        local state = fixture({ idle = 600, files = { [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 1 } }, 'utf16') } })
        state.load()
        for _ = 1, 5 do state.now = state.now + 2; equal(state.env.Update(), 0, 'Update waits for Start') end
        state.env.Sync()
        state.env.RequestReevaluate()
        state.env.Tick('anything')
        equal(#state.bangs + #state.reads + #state.arms, 0, 'No bang, reading or tick before Start')
        state.env.Start()
        expectBroadcast(state, '1', 'Start broadcasts the current state once')
        -- The request Calcs also fire during the load, before Start: a
        -- re-evaluation requested then must not unload a needless coordinator
        -- early (it waits for its regular 300-tick check).
        state.reset()
        for _ = 1, 20 do state.now = state.now + 2; state.env.Update() end
        equal(state.count('!DeactivateConfig'), 0, 'A request made before Start is dropped')
    end)

    -- The away flag of the broadcast this tick sent, or nil.
    local function awayOf(state)
        return state.bangs[1] and state.bangs[1]:match('^!SetVariableGroup ParallaxIdleAway (%d) Parallax$') or nil
    end

    scenario('broadcast only on change, heartbeat and tick gap, with the exact bangs', function()
        local state = fixture({ idle = 0 })
        state.load()
        state.env.Start()
        expectBroadcast(state, '0', 'Start')
        equal(#state.reads, 1, 'Start reads the measure')
        state.reset()
        -- 29 ticks of work (input every few seconds): heartbeat every 30 ticks of 2 s.
        for tick = 1, 29 do state.step(2, tick % 3) end
        equal(#state.bangs, 0, 'An unchanged state sends nothing between heartbeats')
        equal(#state.reads, 0, 'Far from 300 s no tick reads the measure')
        state.step(2, 1)
        expectBroadcast(state, '0', 'Heartbeat on tick 30 (about 60 s)')
        equal(#state.reads, 1, 'The heartbeat tick reads')
        -- Then no input: idle time grows with the clock from that reading.
        local idle, tick, crossed, reads = 1, 30, nil, 0
        while not crossed and tick < 400 do
            tick, idle = tick + 1, idle + 2
            state.reset()
            state.step(2, idle)
            reads = reads + #state.reads
            if idle < 300 then
                local away = awayOf(state)
                check(away == nil or (away == '0' and tick % 30 == 0), 'Below 300 s only heartbeats broadcast (tick ' .. tick .. ')')
            else
                crossed = tick
                expectBroadcast(state, '1', 'Away at the first tick at or past 300 s')
            end
        end
        equal(idle, 301, 'Crossed at 301 s, the first tick at or past 300 s')
        check(reads <= 8, 'About one reading a minute until the crossing comes near (' .. reads .. ' readings in ' .. (crossed - 30) .. ' ticks)')
        state.reset()
        state.step(2, 303)
        equal(#state.bangs, 0, 'Still away sends nothing')
        equal(#state.reads, 1, 'Away: every tick reads')
        state.step(2, 0)
        expectBroadcast(state, '0', 'Input clears away at the next tick')
        state.reset()
        state.step(11, 1)
        expectBroadcast(state, '0', 'A tick gap over 10 s (sleep) re-broadcasts')
        equal(#state.reads, 1, 'A tick gap reads')
        state.reset()
        state.step(-30, 1)
        expectBroadcast(state, '0', 'A clock moved backwards re-broadcasts')
        equal(#state.reads, 1, 'A clock moved backwards reads')
        state.reset()
        state.env.Sync()
        expectBroadcast(state, '0', 'Sync after Start repeats the state')
        equal(#state.reads, 0, 'Sync repeats without reading')
    end)

    scenario('bounded test hooks and tick', function()
        local state = fixture({ idle = 6, variables = { ParallaxIdleTestAwaySeconds = '5', ParallaxIdleTestHeartbeatTicks = '4' } })
        state.load()
        state.env.Start()
        expectBroadcast(state, '1', 'A 5 s away hook is honoured')
        state.reset()
        for _ = 1, 3 do state.now = state.now + 2; state.env.Update() end
        equal(#state.bangs, 0, 'No heartbeat before tick 4')
        state.now = state.now + 2
        state.env.Update()
        expectBroadcast(state, '1', 'A 4-tick heartbeat hook is honoured')
        for _, bad in ipairs({ '0', '301', 'abc', '-5', '5.5', '' }) do
            local other = fixture({ idle = 6, variables = { ParallaxIdleTestAwaySeconds = bad, ParallaxIdleTestHeartbeatTicks = bad } })
            other.load()
            other.env.Start()
            expectBroadcast(other, '0', 'Out-of-bounds away hook ' .. bad .. ' keeps 300 s')
            other.reset()
            for _ = 1, 29 do other.now = other.now + 2; other.env.Update() end
            equal(#other.bangs, 0, 'Out-of-bounds heartbeat hook ' .. bad .. ' keeps 30 ticks')
        end
        local slow = fixture({ idle = 0, tick = '10000' })
        slow.load()
        slow.env.Start()
        slow.reset()
        for _ = 1, 5 do slow.now = slow.now + 11; slow.env.Update() end
        equal(#slow.bangs, 0, 'A 10 s tick sees no gap at 11 s and no heartbeat before tick 6')
        slow.now = slow.now + 10
        slow.env.Update()
        expectBroadcast(slow, '0', 'A 10 s tick heartbeats every 6 ticks (about 60 s)')
        local fast = fixture({ idle = 0, tick = '100' })
        fast.load()
        fast.env.Start()
        fast.reset()
        for _ = 1, 29 do fast.now = fast.now + 2; fast.env.Update() end
        equal(#fast.bangs, 0, 'An out-of-range tick falls back to 2 s (30-tick heartbeat)')
        local filed = fixture({ idle = 0, variables = { ParallaxIdleTestFile = 'C:\\Fixture\\idle.txt' }, files = { ['C:\\Fixture\\idle.txt'] = '400\r\n' } })
        filed.load()
        filed.env.Start()
        expectBroadcast(filed, '1', 'The test file replaces the measure when set')
        local relative = fixture({ idle = 0, variables = { ParallaxIdleTestFile = 'idle.txt' }, files = { ['idle.txt'] = '400' } })
        relative.load()
        relative.env.Start()
        expectBroadcast(relative, '0', 'A relative test file path is ignored')
    end)

    -- Rainmeter.ini, User\Media.inc and CaptureState.inc decide the need.
    local function needFixture(mediaActive, drawer, capture, encoding, extra)
        local files = {
            [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 1 }, { 'Parallax\\Media', mediaActive } }, encoding),
            [mediaInc] = '[Variables]\r\nColumns=2\r\n' .. (drawer and ('VisualizerDrawer=' .. drawer .. '\r\n') or ''),
        }
        if capture ~= nil then files[stateInc] = '[Variables]\r\nMediaDrawerCapture=' .. capture .. '\r\nMediaStandby=0\r\n' end
        for path, text in pairs(extra or {}) do files[path] = text end
        local state = fixture({ idle = 0, files = files })
        state.load()
        state.env.Start()
        state.reset()
        return state
    end
    local function deactivatesAt(state)
        for tick = 1, 300 do
            state.now = state.now + 2
            state.env.Update()
            for _, bang in ipairs(state.bangs) do if bang == '!DeactivateConfig' then return tick end end
        end
        return nil
    end

    scenario('re-evaluation never acts synchronously and never on tick 1', function()
        local state = needFixture(0, '2', '0')
        state.env.RequestReevaluate()
        equal(#state.bangs, 0, 'RequestReevaluate only sets a flag')
        state.now = state.now + 2
        state.env.Update()
        equal(state.count('!DeactivateConfig'), 0, 'Tick 1 never deactivates')
        state.now = state.now + 2
        state.env.Update()
        equal(state.count('!DeactivateConfig'), 1, 'Tick 2 acts on the pending request')
        local periodic = needFixture(0, '2', '0')
        equal(deactivatesAt(periodic), 300, 'Without a request the need is re-checked every 300 ticks')
    end)

    scenario('need from Rainmeter.ini (UTF-16LE and UTF-8), Media.inc and CaptureState.inc', function()
        for _, encoding in ipairs({ 'utf16', 'utf8' }) do
            local cases = {
                { 1, '2', '0', true, 'open drawer, live capture' },
                { 1, '2', '1', true, 'open drawer, parked capture' },
                { 1, '2', nil, true, 'open drawer, no state file' },
                { 1, '2', '2', false, 'capture deferred to the standalone' },
                { 1, '1', '0', false, 'collapsed drawer' },
                { 1, '0', '0', false, 'hidden drawer' },
                { 1, nil, '0', false, 'no saved drawer value (default collapsed)' },
                { 2, '2', '0', false, 'Setup.ini loaded instead of Media.ini' },
                { 0, '2', '0', false, 'Media unloaded' },
                { nil, '2', '0', false, 'Media never loaded (no Active key)' },
            }
            for _, case in ipairs(cases) do
                local state = needFixture(case[1], case[2], case[3], encoding)
                state.env.RequestReevaluate()
                state.now = state.now + 2; state.env.Update()
                state.now = state.now + 2; state.env.Update()
                equal(state.count('!DeactivateConfig') == 0, case[4], encoding .. ': ' .. case[5])
            end
        end
        local unreadable = needFixture(0, '2', '0', 'utf8', { [settingsFile] = false })
        unreadable.env.RequestReevaluate()
        unreadable.now = unreadable.now + 2; unreadable.env.Update()
        unreadable.now = unreadable.now + 2; unreadable.env.Update()
        equal(unreadable.count('!DeactivateConfig'), 0, 'An unreadable Rainmeter.ini keeps the coordinator loaded')
        local noPreferences = needFixture(1, '2', '0', 'utf8', { [mediaInc] = false })
        noPreferences.env.RequestReevaluate()
        noPreferences.now = noPreferences.now + 2; noPreferences.env.Update()
        noPreferences.now = noPreferences.now + 2; noPreferences.env.Update()
        equal(noPreferences.count('!DeactivateConfig'), 0, 'An unreadable User\\Media.inc keeps the coordinator loaded')
    end)

    scenario('idle pause: paused after 5, 10 and 30 minutes, only while the setting is on', function()
        for _, minutes in ipairs({ 5, 10, 30 }) do
            local threshold = minutes * 60
            local state = fixture({ idle = 0, variables = { IdlePauseMinutes = tostring(minutes) } })
            state.load()
            state.env.Start()
            expectBroadcast(state, '0', minutes .. ' min: Start', '0')
            -- No input from 1 s idle on, 2 s ticks: idle time is 1, 3, 5, ...
            local idle, tick, awayAt, pausedAt = 1, 0, nil, nil
            while idle < threshold + 4 do
                tick = tick + 1
                state.reset()
                state.step(2, idle)
                local away = awayOf(state)
                local paused = state.bangs[2] and state.bangs[2]:match('^!SetVariableGroup ParallaxIdlePaused (%d) Parallax$') or nil
                if away == '1' and not awayAt then awayAt = idle; equal(paused, idle >= threshold and '1' or '0', minutes .. ' min: away broadcast carries the pause flag') end
                if paused == '1' and not pausedAt then pausedAt = idle end
                if away and idle ~= awayAt and idle ~= pausedAt then
                    check(tick % 30 == 0, minutes .. ' min: no broadcast but changes and heartbeats (idle ' .. idle .. ')')
                end
                if idle == threshold - 1 then
                    equal(paused == nil or paused == '0', true, minutes .. ' min: one second short of the pause sends no pause')
                end
                idle = idle + 2
            end
            equal(awayAt, 301, minutes .. ' min: away at the first tick past 300 s')
            equal(pausedAt, threshold + 1, minutes .. ' min: paused at the first tick past ' .. threshold .. ' s')
            state.reset()
            state.step(2, idle)
            check(#state.bangs == 0 or tick % 30 == 29, minutes .. ' min: still paused sends nothing')
            equal(#state.reads, 1, minutes .. ' min: paused, every tick reads')
            state.reset()
            state.step(2, 0)
            expectBroadcast(state, '0', minutes .. ' min: input clears away and paused in one broadcast', '0')
            state.reset()
            state.env.Sync()
            expectBroadcast(state, '0', minutes .. ' min: Sync repeats both flags', '0')
        end
        -- Restart while idle: Start reports both flags at once.
        local restart = fixture({ idle = 700, variables = { IdlePauseMinutes = '10' } })
        restart.load()
        restart.env.Start()
        expectBroadcast(restart, '1', 'Start while idle past 10 min', '1')
    end)

    scenario('idle pause: away and paused flip together in one broadcast at 5 minutes', function()
        local state = fixture({ idle = 0, variables = { IdlePauseMinutes = '5' } })
        state.load()
        state.env.Start()
        -- No input for 300 s: idle 3, 5, ... 297 (heartbeats in between), 299, 301.
        for idle = 3, 297, 2 do state.step(2, idle) end
        state.reset()
        state.step(2, 299)
        equal(#state.bangs, 0, 'Below 300 s neither flag is set')
        state.step(2, 301)
        expectBroadcast(state, '1', 'Both flags in the same broadcast', '1')
        equal(state.count('!UpdateMeasureGroup'), 1, 'One hook update for both flags')
    end)

    scenario('idle pause: invalid minutes act as Off; the test hook only shortens a setting that is on', function()
        for _, bad in ipairs({ '0', '7', '15', '', 'abc', '5.0', '-5', '60' }) do
            local state = fixture({ idle = 4000, variables = { IdlePauseMinutes = bad, ParallaxIdleTestPauseSeconds = '4' } })
            state.load()
            state.env.Start()
            expectBroadcast(state, '1', 'IdlePauseMinutes=' .. bad .. ' never pauses', '0')
            state.reset()
            state.step(2, 4002)
            equal(#state.bangs, 0, 'IdlePauseMinutes=' .. bad .. ' still away, still not paused')
        end
        local spaced = fixture({ idle = 600, variables = { IdlePauseMinutes = ' 10 ' } })
        spaced.load()
        spaced.env.Start()
        expectBroadcast(spaced, '1', 'Surrounding spaces are ignored (10 min)', '1')
        local shortened = fixture({ idle = 5, variables = { IdlePauseMinutes = '30', ParallaxIdleTestPauseSeconds = '4' } })
        shortened.load()
        shortened.env.Start()
        expectBroadcast(shortened, '0', 'A 4 s pause hook is honoured while the setting is on', '1')
        for _, bad in ipairs({ '0', '1801', 'x', '2.5' }) do
            local other = fixture({ idle = 5, variables = { IdlePauseMinutes = '5', ParallaxIdleTestPauseSeconds = bad } })
            other.load()
            other.env.Start()
            expectBroadcast(other, '0', 'Out-of-bounds pause hook ' .. bad .. ' keeps 5 minutes', '0')
        end
    end)

    scenario('idle pause need: any utility config loaded while the setting is on', function()
        local function pauseFixture(minutes, sections)
            local files = {
                [settingsFile] = rainmeterIni(sections, 'utf16'),
                [mediaInc] = '[Variables]\r\nVisualizerDrawer=1\r\n',
            }
            local state = fixture({ idle = 0, files = files, variables = { IdlePauseMinutes = minutes } })
            state.load()
            state.env.Start()
            state.env.RequestReevaluate()
            state.reset()
            state.now = state.now + 2; state.env.Update()
            state.now = state.now + 2; state.env.Update()
            return state.count('!DeactivateConfig') == 0
        end
        for _, config in ipairs({ 'Chronometer', 'CPU', 'GPU', 'RAM', 'IO', 'Network', 'Visualizer', 'Media\\Queue' }) do
            equal(pauseFixture('5', { { 'Parallax\\Idle', 1 }, { 'Parallax\\' .. config, 1 } }), true, 'Pause on keeps the coordinator for ' .. config)
            equal(pauseFixture('0', { { 'Parallax\\Idle', 1 }, { 'Parallax\\' .. config, 1 } }), false, 'Pause off does not keep it for ' .. config)
        end
        equal(pauseFixture('10', { { 'Parallax\\Idle', 1 }, { 'Parallax\\Media', 2 } }), true, 'Setup.ini (Active=2) counts as a utility')
        equal(pauseFixture('30', { { 'Parallax\\Idle', 1 }, { 'Parallax\\Media', 1 } }), true, 'Media.ini with a collapsed drawer counts while the pause is on')
        equal(pauseFixture('30', { { 'Parallax\\Idle', 1 }, { 'Parallax\\CPU', 0 }, { 'Parallax\\Settings', 1 }, { 'Parallax\\Welcome', 1 } }), false,
            'Only Global Settings and Welcome loaded: not needed')
        equal(pauseFixture('7', { { 'Parallax\\Idle', 1 }, { 'Parallax\\CPU', 1 } }), false, 'A Custom value is Off')
        -- Unreadable Rainmeter.ini keeps it loaded, as before.
        local unreadable = fixture({ idle = 0, files = { [settingsFile] = false }, variables = { IdlePauseMinutes = '5' } })
        unreadable.load()
        unreadable.env.Start()
        unreadable.env.RequestReevaluate()
        unreadable.now = unreadable.now + 2; unreadable.env.Update()
        unreadable.now = unreadable.now + 2; unreadable.env.Update()
        equal(unreadable.count('!DeactivateConfig'), 0, 'Unreadable Rainmeter.ini with the pause on keeps the coordinator')
    end)

    scenario('reads: the same broadcasts as a reading on every tick, for realistic input traces', function()
        -- The reference is a test-file coordinator, which reads its source on
        -- every tick; the real one reads the measure only when due. Real time
        -- runs in fractions of a second; os.time() and IDLE_TIME floor it, as
        -- Windows does. Input restarts idle time somewhere in the last tick;
        -- ticks jitter, the computer sleeps and, with os.clock, the system
        -- clock is set back.
        local seed = 20261023
        local function random(n) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % n end
        local path = 'C:\\Fixture\\idle.txt'
        local farTicks, farReads, changes = 0, 0, 0
        local setups = {
            { IdlePauseMinutes = '0' }, { IdlePauseMinutes = '5' }, { IdlePauseMinutes = '10' }, { IdlePauseMinutes = '30' },
            { IdlePauseMinutes = '10', ParallaxIdleTestPauseSeconds = '200' }, { IdlePauseMinutes = '0', ParallaxIdleTestAwaySeconds = '20' },
        }
        for index, variables in ipairs(setups) do
            local nearest = tonumber(variables.ParallaxIdleTestAwaySeconds) or 300
            for _, withClock in ipairs({ false, true }) do
                local start = random(400)
                local real = fixture({ idle = start, variables = variables, clock = withClock and 5000 or nil })
                local filedVariables = { ParallaxIdleTestFile = path }
                for key, value in pairs(variables) do filedVariables[key] = value end
                local filed = fixture({ idle = 0, variables = filedVariables, files = { [path] = tostring(start) } })
                real.load()
                filed.load()
                real.env.Start()
                filed.env.Start()
                local label = 'setup ' .. index .. (withClock and ' with os.clock' or '')
                -- One transcript line per tick; compared once per trace, with
                -- the first differing tick named.
                local realLines, filedLines = {}, {}
                local function same(tick)
                    realLines[#realLines + 1] = tick .. ': ' .. table.concat(real.bangs, ' ; ')
                    filedLines[#filedLines + 1] = tick .. ': ' .. table.concat(filed.bangs, ' ; ')
                end
                same(0)
                local working = random(2) == 0
                local lastFlags = nil
                local base, time, back = real.now, 0.37, 0
                local input = time - start
                for tick = 1, 3000 do
                    real.reset()
                    filed.reset()
                    if random(250) == 0 then working = not working end
                    local dt, roll = 2, random(100)
                    if roll < 8 then dt = 1 elseif roll < 16 then dt = 3 elseif roll == 99 then dt = 12 + random(60) end
                    dt = dt + (random(121) - 60) / 1000
                    time = time + dt
                    if withClock and random(150) == 0 then back = back + 1 + random(30) end
                    if working and random(4) == 0 then input = time - random(1000) / 1000 * dt end
                    local idle = math.floor(time - input)
                    local far = nearest >= 300 and idle + 2 * dt < nearest / 2
                    real.now = base + math.floor(time) - back
                    filed.now = real.now
                    if real.clock then real.clock = 5000 + time end
                    real.idle, filed.files[path] = idle, tostring(idle)
                    real.env.Update()
                    filed.env.Update()
                    same(tick)
                    if far then farTicks, farReads = farTicks + 1, farReads + #real.reads end
                    local flags = filed.bangs[1] and (filed.bangs[1]:match('Away (%d)') .. filed.bangs[2]:match('Paused (%d)'))
                    if flags and flags ~= (lastFlags or '00') then changes = changes + 1 end
                    lastFlags = flags or lastFlags
                end
                local differs = nil
                for i = 1, #filedLines do if realLines[i] ~= filedLines[i] then differs = i; break end end
                equal(differs and realLines[differs] or 'same', differs and filedLines[differs] or 'same', label .. ': first differing tick')
            end
        end
        check(changes > 50, 'The traces cross the thresholds often (' .. changes .. ' changes)')
        notes[#notes + 1] = string.format('equivalence traces: %d state changes; readings far from the thresholds: %d of %d ticks', changes, farReads, farTicks)
        check(farTicks > 5000, 'The traces spend time far from the thresholds (' .. farTicks .. ' ticks)')
        check(farReads < farTicks * 0.08, 'Far from the thresholds about one tick in 30 reads (' .. farReads .. ' of ' .. farTicks .. ')')
    end)

    scenario('reads: a test idle file is read on every tick, the measure on the real schedule', function()
        local path = 'C:\\Fixture\\idle.txt'
        local state = fixture({ idle = 0, variables = { ParallaxIdleTestFile = path }, files = { [path] = '0' } })
        state.load()
        state.env.Start()
        equal(#state.reads, 1, 'Start updates the measure')
        state.reset()
        for _ = 1, 29 do state.step(2, 0, path) end
        equal(#state.reads, 0, 'Far from a threshold the measure is not updated')
        equal(#state.bangs, 0, 'Nothing changes')
        state.step(2, 0, path)
        equal(#state.reads, 1, 'The heartbeat tick updates the measure')
        state.reset()
        state.step(2, 400, path)
        expectBroadcast(state, '1', 'A jump in the file is seen at the next tick')
        equal(#state.reads, 0, 'The measure follows the real schedule, not the file')
        state.reset()
        state.step(2, 402, path)
        equal(#state.reads, 1, 'Away: the measure is updated every tick')
        equal(#state.bangs, 0, 'Still away')
        state.step(2, 0, path)
        expectBroadcast(state, '0', 'Input in the file is seen at the next tick')
    end)

    scenario('reads: os.clock widens the estimate when the system clock lags', function()
        -- The system clock gains only 1 s per 2 s tick (set back a second at a
        -- time); os.clock and idle time gain 2 s. Away must still be seen at
        -- the first tick at or past 300 s, not at the next heartbeat.
        for _, clock in ipairs({ 5000, false }) do
            local state = fixture({ idle = 11, clock = clock or nil })
            state.load()
            state.env.Start()
            local idle, awayAt, tick = 11, nil, 0
            while not awayAt and tick < 200 do
                tick, idle = tick + 1, idle + 2
                state.reset()
                state.now = state.now + 1
                if state.clock then state.clock = state.clock + 2 end
                state.idle = idle
                state.env.Update()
                if awayOf(state) == '1' then awayAt = idle end
            end
            if clock then
                equal(awayAt, 301, 'With os.clock: away at the first tick past 300 s')
            else
                -- Without a usable os.clock the heartbeat's forced reading bounds the delay.
                check(awayAt ~= nil and awayAt <= 301 + 60, 'Without os.clock: away by the next heartbeat (' .. tostring(awayAt) .. ')')
            end
        end
    end)

    scenario('tick chain: one per Start, other tokens dropped, nothing after closing', function()
        local state = fixture({ idle = 0 })
        state.load()
        state.env.Start()
        equal(#state.arms, 1, 'Start arms one tick')
        local first = state.arms[1]:match('^%[!Delay 2000%]%[!CommandMeasure MeasureParallaxIdle "Tick%(\'(%w+)\'%)"%]$')
        check(first ~= nil, 'A 2 s [!Delay] into this measure with a token: ' .. state.arms[1])
        state.reset()
        state.now = state.now + 2
        state.env.Tick(first)
        equal(#state.arms, 1, 'A tick arms the next one')
        equal(state.arms[1]:match("Tick%('(%w+)'%)"), first, 'With the same token')
        for _ = 2, 29 do state.now = state.now + 2; state.env.Tick(first) end
        state.reset()
        state.now = state.now + 2
        state.env.Tick(first)
        expectBroadcast(state, '0', 'Thirty chained ticks make a heartbeat')
        equal(state.updates, 30, 'Each tick is one Rainmeter update of the measure')
        -- Test drivers pause the measure to stop the beat: the chain goes on,
        -- the ticks do not, as with a skin timer.
        state.paused = true
        state.reset()
        for _ = 1, 40 do state.now = state.now + 2; state.env.Tick(first) end
        equal(#state.arms, 40, 'Paused: the chain goes on')
        equal(#state.bangs + #state.reads, 0, 'Paused: no tick, reading or heartbeat')
        state.paused = false
        state.reset()
        state.now = state.now + 2
        state.env.Tick(first)
        expectBroadcast(state, '0', 'Unpaused after 82 s: the first tick sees the gap and broadcasts')
        state.reset()
        state.env.Tick('stale')
        state.env.Tick(first .. '0')
        state.env.Tick(nil)
        equal(#state.arms + #state.bangs + #state.reads, 0, 'A tick with another token does nothing')
        state.env.Start()
        local second = state.arms[1]:match("Tick%('(%w+)'%)")
        check(second ~= nil and second ~= first, 'A new Start arms a chain with a new token')
        state.reset()
        state.env.Tick(first)
        equal(#state.arms + #state.bangs + #state.reads, 0, 'The earlier chain ends')
        local other = fixture({ idle = 0 })
        other.load()
        other.env.Start()
        check(other.arms[1]:match("Tick%('(%w+)'%)") ~= first, 'Another load has another token')
        local slow = fixture({ idle = 0, tick = '10000' })
        slow.load()
        slow.env.Start()
        check(slow.arms[1]:match('^%[!Delay 10000%]') ~= nil, 'The chain follows the clamped tick')
        state.env.Closing()
        state.reset()
        state.env.Tick(second)
        equal(state.env.Update(), 0, 'Update does nothing after OnCloseAction')
        equal(#state.arms + #state.bangs + #state.reads, 0, 'No tick after OnCloseAction')
        local unneeded = needFixture(0, '2', '0')
        unneeded.env.Start()
        local token = unneeded.arms[1]:match("Tick%('(%w+)'%)")
        unneeded.env.RequestReevaluate()
        unneeded.reset()
        unneeded.now = unneeded.now + 2
        unneeded.env.Tick(token)
        unneeded.now = unneeded.now + 2
        unneeded.env.Tick(token)
        equal(unneeded.count('!DeactivateConfig'), 1, 'The second tick unloads a needless coordinator')
        unneeded.reset()
        unneeded.now = unneeded.now + 2
        unneeded.env.Tick(token)
        equal(#unneeded.arms + #unneeded.bangs + #unneeded.reads, 0, 'No tick after the coordinator unloaded itself')
    end)

    scenario('Closing broadcasts only after a real unload', function()
        for _, case in ipairs({ { 0, true, 'Active=0 (unloaded)' }, { 1, false, 'Active=1 (Rainmeter exit or game mode)' } }) do
            local state = fixture({ idle = 600, files = { [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', case[1] } }, 'utf16') } })
            state.load()
            state.env.Start()
            state.reset()
            state.env.Closing()
            if case[2] then expectBroadcast(state, '0', case[3]) else equal(#state.bangs, 0, case[3]) end
        end
        local unreadable = fixture({ idle = 600, files = { [settingsFile] = false } })
        unreadable.load()
        unreadable.env.Closing()
        equal(#unreadable.bangs, 0, 'Closing with an unreadable Rainmeter.ini sends nothing')
    end)

    scenario('link: missing coordinator, active coordinator, inactive coordinator, rate limit', function()
        local missing = fixture({ files = { [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 0 } }, 'utf16') } })
        local link = missing.link()
        equal(link.join(), false, 'A missing Idle.ini does nothing')
        equal(#missing.bangs, 0, 'No modal-opening activation for a missing file')

        local active = fixture({ files = { [idleIni] = '[Rainmeter]\r\n', [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 1 } }, 'utf16') } })
        link = active.link()
        equal(link.join(), true, 'Active coordinator: joined')
        equal(#active.bangs, 1, 'One silent request')
        equal(active.bangs[1], '!UpdateMeasureGroup ParallaxIdleSyncRequest *', 'Silent group sync request, never !CommandMeasure')

        local inactive = fixture({ files = { [idleIni] = '[Rainmeter]\r\n', [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 0 } }, 'utf8') } })
        link = inactive.link()
        equal(link.join(), true, 'Inactive coordinator: joined')
        equal(inactive.bangs[1], '!ActivateConfig Parallax\\Idle Idle.ini', 'Activates the coordinator')
        inactive.reset()
        inactive.now = inactive.now + 599
        equal(link.join(), false, 'A second join within 10 minutes is refused')
        equal(#inactive.bangs, 0, 'Rate limit sends nothing')
        inactive.now = inactive.now + 1
        equal(link.join(), true, 'A re-join after 10 minutes is allowed')
        equal(#inactive.bangs, 1, 'One activation per join')

        local unreadable = fixture({ files = { [idleIni] = '[Rainmeter]\r\n', [settingsFile] = false } })
        link = unreadable.link()
        equal(link.join(), false, 'An unreadable Rainmeter.ini does nothing')
        equal(#unreadable.bangs, 0, 'Nothing sent without settings')

        local noSection = fixture({ files = { [idleIni] = '[Rainmeter]\r\n', [settingsFile] = rainmeterIni({}, 'utf16') } })
        link = noSection.link()
        link.join()
        equal(noSection.bangs[1], '!ActivateConfig Parallax\\Idle Idle.ini', 'A never-loaded coordinator is activated')

        local request = fixture()
        link = request.link()
        link.requestReevaluate()
        equal(request.bangs[1], '!UpdateMeasureGroup ParallaxIdleReevaluateRequest *', 'Re-evaluation is a silent group request')
    end)

    return 'PASS: ' .. passed .. ' assertions in ' .. #cases .. ' coordinator scenarios; ' .. _VERSION .. '.\n' .. table.concat(cases, '\n') .. (#notes > 0 and ('\n' .. table.concat(notes, '\n')) or '')
end

return Suite
