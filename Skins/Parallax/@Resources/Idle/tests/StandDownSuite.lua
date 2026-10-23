-- Developer-only checks for the idle stand-down hook (@Resources\Idle\
-- StandDown.lua). Every SKIN call, file, clock and Bang is injected; nothing
-- reaches Rainmeter, the file system or another process. Lua 5.1 (Rainmeter's
-- own, or OBS's LuaJIT through ctypes). Suite.Run(standDownPath, linkPath)
-- returns a report and raises on the first failure.
local Suite = {}

function Suite.Run(standDownPath, linkPath)
    local passed, cases = 0, {}
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

    local ENTER = {
        '!CommandMeasure MeasureA if IdleEnter then IdleEnter() end',
        '!CommandMeasure MeasureB if IdleEnter then IdleEnter() end',
        '!PauseMeasureGroup ParallaxIdlePause',
        '!SetOptionGroup ParallaxIdleFreeze UpdateDivider -1',
        '!UpdateMeterGroup ParallaxIdleFreeze',
        '!ShowMeter MeterParallaxPaused',
        '!UpdateMeter MeterParallaxPaused',
        '!Redraw',
    }
    local LEAVE = {
        '!UnpauseMeasureGroup ParallaxIdlePause',
        '!CommandMeasure MeasureA if IdleLeave then IdleLeave() end',
        '!CommandMeasure MeasureB if IdleLeave then IdleLeave() end',
        '!UpdateMeasureGroup ParallaxIdlePause',
        '!SetOptionGroup ParallaxIdleFreeze UpdateDivider ',
        '!CommandMeasure MeasureA if ReapplyDividers then ReapplyDividers() end',
        '!CommandMeasure MeasureB if ReapplyDividers then ReapplyDividers() end',
        '!UpdateMeterGroup ParallaxIdleFreeze',
        '!HideMeter MeterParallaxPaused',
        '!CommandMeasure MeasureA if RestoreHeadline then RestoreHeadline() end',
        '!CommandMeasure MeasureB if RestoreHeadline then RestoreHeadline() end',
        '!Redraw',
    }

    local function utf16le(text)
        local out = { '\255\254' }
        for index = 1, #text do out[#out + 1] = text:sub(index, index) .. '\0' end
        return table.concat(out)
    end
    local function rainmeterIni(idleActive)
        return utf16le('[Rainmeter]\r\n[Parallax\\Idle]\r\nActive=' .. idleActive .. '\r\n')
    end

    -- A fresh hook environment. options.variables override SKIN variables;
    -- options.idleActive is the coordinator's recorded Active (nil: no
    -- Idle.ini at all). Each Bang's arguments are joined with spaces; Bang
    -- arguments are always strings (multi-argument SKIN:Bang passes '' as is).
    local function fixture(options)
        options = options or {}
        local state = { bangs = {}, now = options.now or 1000000, files = {}, onBang = nil }
        if options.idleActive ~= nil then
            state.files[idleIni] = '[Rainmeter]\r\n'
            state.files[settingsFile] = rainmeterIni(options.idleActive)
        end
        local variables = {
            ['@'] = resources, ROOTCONFIG = 'Parallax', SETTINGSPATH = settingsPath, SKINSPATH = skins,
            ParallaxIdleControllers = 'MeasureA|MeasureB', ParallaxIdleHookMs = '60000',
            ParallaxIdleAway = '0', ParallaxIdlePaused = '0', ParallaxIdleSync = '0', ParallaxIdleBeat = '0',
        }
        for key, value in pairs(options.variables or {}) do variables[key] = value end
        state.variables = variables
        -- Meters by name: { Hidden = text }. !ShowMeter and !HideMeter write
        -- Hidden as Rainmeter does (Meter::Show/Hide set the parser value).
        state.meters = options.meters or {}
        local skin = {}
        function skin:GetVariable(name, default)
            local value = variables[name]
            if value == nil then return default end
            return value
        end
        function skin:GetMeter(name)
            local meter = state.meters[name]
            if not meter then return nil end
            return { GetOption = function(_, key, default)
                local value = meter[key]
                if value == nil then return default end
                return value
            end }
        end
        function skin:ParseFormula(text)
            assert(text:match('^[%d%s%(%)%+%-%*/%.]+$'), 'Only arithmetic formulas in fixtures: ' .. text)
            return assert(loadstring('return ' .. text))()
        end
        function skin:Bang(...)
            local args = { ... }
            for _, value in ipairs(args) do assert(type(value) == 'string', 'Bang arguments are strings') end
            state.bangs[#state.bangs + 1] = table.concat(args, ' ')
            -- The single writer: a working one posts this load's reload and
            -- says so (options.writerReloads = false: it cannot).
            if args[1] == '!CommandMeasure' and args[2] == variables.ParallaxIdleStandbyWriter and options.writerReloads ~= false then
                variables.ParallaxIdleStandbyPending = '1'
            end
            if (args[1] == '!ShowMeter' or args[1] == '!HideMeter') and state.meters[args[2]] then
                state.meters[args[2]].Hidden = args[1] == '!ShowMeter' and '0' or '1'
            end
            if state.onBang then state.onBang(args) end
        end
        setmetatable(skin, { __index = function(_, key) error('Unexpected SKIN:' .. tostring(key)) end })
        local fakeIo = { open = function(path, mode)
            assert(mode == 'rb', 'Files are opened read-only')
            if path == resources .. 'Idle\\Link.lua' then
                if options.noLink then return nil, 'missing', 2 end
                return { close = function() return true end }
            end
            local text = state.files[path]
            if text == nil then return nil, 'missing', 2 end
            return {
                read = function(_, limit) return text:sub(1, limit) end,
                close = function() return true end
            }
        end }
        setmetatable(fakeIo, { __index = function(_, key) error('Unexpected io.' .. tostring(key)) end })
        local fakeOs = { time = function() return state.now end }
        setmetatable(fakeOs, { __index = function(_, key) error('Unexpected os.' .. tostring(key)) end })
        local env = setmetatable({ SKIN = skin, io = fakeIo, os = fakeOs }, { __index = _G })
        env.dofile = function(path)
            assert(path == resources .. 'Idle\\Link.lua', 'The hook loads only the shared link')
            local chunk = assert(loadfile(linkPath))
            setfenv(chunk, env)
            return chunk()
        end
        state.env = env
        function state.load()
            local chunk = assert(loadfile(standDownPath))
            setfenv(chunk, env)
            chunk()
            env.Initialize()
            equal(#state.bangs, 0, 'Initialize sends nothing')
        end
        function state.reset() state.bangs = {} end
        -- A coordinator broadcast: the variables, then a forced hook update.
        function state.broadcast(paused, beat)
            variables.ParallaxIdlePaused = paused
            variables.ParallaxIdleAway = paused
            variables.ParallaxIdleBeat = tostring(beat or state.now)
            variables.ParallaxIdleSync = '1'
            return env.Update()
        end
        function state.count(prefix)
            local count = 0
            for _, bang in ipairs(state.bangs) do if bang:sub(1, #prefix) == prefix then count = count + 1 end end
            return count
        end
        return state
    end

    local function expectSequence(state, expected, message)
        equal(#state.bangs, #expected, message .. ' (bang count)')
        for index, bang in ipairs(expected) do equal(state.bangs[index], bang, message .. ' (bang ' .. index .. ')') end
    end

    -- A loaded hook past its load's first update, synced and live.
    local function live(options)
        local state = fixture(options)
        state.load()
        state.env.Update()                 -- the load's own forced update
        state.broadcast('0')
        state.reset()
        return state
    end

    scenario('enter and leave send the exact bang sequences, in order', function()
        local state = live()
        equal(state.broadcast('1'), 1, 'Update returns 1 while frozen')
        expectSequence(state, ENTER, 'Enter')
        state.reset()
        equal(state.broadcast('0'), 0, 'Update returns 0 when live')
        expectSequence(state, LEAVE, 'Leave')
        -- Leave deletes the freeze divider: the last argument is an empty string.
        check(state.bangs[5]:sub(-1) == ' ', 'The delete bang ends with an empty value')
        -- A single controller and none.
        local one = live({ variables = { ParallaxIdleControllers = 'MeasureCPU' } })
        one.broadcast('1')
        equal(one.bangs[1], '!CommandMeasure MeasureCPU if IdleEnter then IdleEnter() end', 'One controller')
        equal(one.bangs[2], '!PauseMeasureGroup ParallaxIdlePause', 'Then the pause')
        local none = live({ variables = { ParallaxIdleControllers = '' } })
        none.broadcast('1')
        equal(none.bangs[1], '!PauseMeasureGroup ParallaxIdlePause', 'No controller: straight to the pause')
        equal(#none.bangs, #ENTER - 2, 'No controller calls')
    end)

    scenario('reconciliation is idempotent: repeated broadcasts and heartbeats send nothing', function()
        local state = live()
        for _ = 1, 3 do state.now = state.now + 60; state.broadcast('0') end
        equal(#state.bangs, 0, 'Live heartbeats send nothing')
        state.broadcast('1')
        state.reset()
        for _ = 1, 3 do state.now = state.now + 60; state.broadcast('1') end
        equal(#state.bangs, 0, 'Paused heartbeats send nothing')
        -- The hook's own periodic run (no broadcast) changes nothing either.
        state.now = state.now + 30
        state.env.Update()
        equal(#state.bangs, 0, 'A periodic run with a fresh beat sends nothing')
        state.broadcast('0')
        equal(state.count('!UnpauseMeasureGroup'), 1, 'One leave')
        state.reset()
        state.broadcast('0')
        equal(#state.bangs, 0, 'A second live broadcast sends nothing')
    end)

    scenario('unsynced defaults are ignored; join once, after the first update, as the last statement', function()
        local state = fixture({ idleActive = 1, variables = { ParallaxIdlePaused = '1', ParallaxIdleBeat = tostring(1000000) } })
        state.load()
        state.env.Update()
        equal(#state.bangs, 0, 'The load\'s own first update neither acts nor joins')
        state.now = state.now + 1
        state.env.Update()
        expectSequence(state, { '!UpdateMeasureGroup ParallaxIdleSyncRequest *' }, 'The delayed join: one silent request, nothing else')
        state.reset()
        for _ = 1, 3 do state.now = state.now + 2; state.env.Update() end
        equal(#state.bangs, 0, 'Still unsynced: no second join within 10 minutes, no freeze from unsynced defaults')
        -- Coordinator not active: one activation.
        local inactive = fixture({ idleActive = 0 })
        inactive.load()
        inactive.env.Update()
        inactive.env.Update()
        expectSequence(inactive, { '!ActivateConfig Parallax\\Idle Idle.ini' }, 'An inactive coordinator is activated')
        -- No Idle.ini: nothing at all (an activation would open a modal).
        local missing = fixture({})
        missing.load()
        missing.env.Update(); missing.env.Update()
        equal(#missing.bangs, 0, 'No coordinator file: nothing')
        -- No Link.lua: nothing, no error.
        local noLink = fixture({ idleActive = 0, noLink = true })
        noLink.load()
        noLink.env.Update(); noLink.env.Update()
        equal(#noLink.bangs, 0, 'No link: nothing')
    end)

    scenario('a broadcast inside the join re-enters: deferred, then evaluated, never dropped', function()
        local state = fixture({ idleActive = 0 })
        state.load()
        state.env.Update()
        local nested = nil
        state.onBang = function(args)
            if args[1] == '!ActivateConfig' then
                state.onBang = nil
                -- The coordinator's Start broadcast, synchronously inside the join.
                nested = state.broadcast('1')
            end
        end
        state.now = state.now + 1
        state.env.Update()
        equal(nested, 0, 'The nested update returns at once')
        equal(state.bangs[1], '!ActivateConfig Parallax\\Idle Idle.ini', 'The join came first')
        local rest = {}
        for index = 2, #state.bangs do rest[#rest + 1] = state.bangs[index] end
        equal(#rest, #ENTER, 'The deferred broadcast was evaluated after the join')
        for index, bang in ipairs(ENTER) do equal(rest[index], bang, 'Deferred enter bang ' .. index) end
        -- A nested call during enter (a controller re-entering) is also deferred.
        local again = live()
        local depth = 0
        again.onBang = function(args)
            if args[1] == '!PauseMeasureGroup' and depth == 0 then
                depth = 1
                again.variables.ParallaxIdlePaused = '0'
                again.env.Update()
            end
        end
        again.broadcast('1')
        again.onBang = nil
        equal(again.count('!PauseMeasureGroup'), 1, 'Entered once')
        equal(again.count('!UnpauseMeasureGroup'), 1, 'The level that changed during enter was reconciled afterwards')
    end)

    scenario('a script error in one pass leaves the guard open', function()
        local state = live()
        local fail = true
        state.onBang = function(args)
            if fail and args[1] == '!PauseMeasureGroup' then fail = false; error('synthetic') end
        end
        local ok = pcall(state.broadcast, '1')
        check(not ok, 'The error is raised to Rainmeter')
        state.onBang = nil
        state.reset()
        state.broadcast('0')
        check(#state.bangs > 0, 'The next update still runs')
    end)

    scenario('watchdog: a stale beat fails live and re-joins; a sleep gap re-arms instead', function()
        local state = live({ idleActive = 1 })
        state.broadcast('1')
        local beat = state.now
        -- Periodic runs every 60 s with no broadcast: stale after 180 s.
        for _ = 1, 3 do state.now = state.now + 60; state.env.Update() end
        equal(state.count('!UnpauseMeasureGroup'), 0, 'At exactly 180 s it is not stale yet')
        state.reset()
        state.now = state.now + 60
        state.env.Update()
        local leaveCount = #LEAVE
        for index, bang in ipairs(LEAVE) do equal(state.bangs[index], bang, 'Fail-live leave bang ' .. index) end
        equal(state.bangs[leaveCount + 1], '!UpdateMeasureGroup ParallaxIdleSyncRequest *', 'Then a re-join')
        equal(#state.bangs, leaveCount + 1, 'Nothing else')
        -- Still stale on later runs: stays live; the re-join is rate-limited.
        state.reset()
        state.now = state.now + 60
        state.env.Update()
        equal(#state.bangs, 0, 'Stays live, no second join within 10 minutes')
        -- A coordinator that comes back with a fresh paused beat freezes again.
        state.broadcast('1')
        equal(state.count('!PauseMeasureGroup'), 1, 'A fresh paused beat freezes again')
        check(beat < state.now, 'Clock moved')
        -- Sleep: a gap longer than twice the hook period re-arms the clock.
        local sleeper = live()
        sleeper.broadcast('1')
        sleeper.reset()
        sleeper.now = sleeper.now + 3600
        sleeper.env.Update()
        equal(#sleeper.bangs, 0, 'After a one-hour sleep gap: re-armed, still frozen')
        sleeper.now = sleeper.now + 60
        sleeper.env.Update()
        equal(#sleeper.bangs, 0, '60 s after waking: still within the re-armed window')
        sleeper.now = sleeper.now + 60
        sleeper.env.Update()
        sleeper.now = sleeper.now + 61
        sleeper.env.Update()
        equal(sleeper.count('!UnpauseMeasureGroup'), 1, 'No beat 181 s after waking: fails live')
        -- A clock moved backwards also re-arms.
        local back = live()
        back.broadcast('1')
        back.reset()
        back.now = back.now - 500
        back.env.Update()
        equal(#back.bangs, 0, 'A clock moved backwards re-arms')
        -- Staged hooks: a 5 s stale limit and a 2 s hook period.
        local fast = live({ variables = { ParallaxIdleTestStaleSeconds = '5', ParallaxIdleHookMs = '2000' } })
        fast.broadcast('1')
        fast.reset()
        for _ = 1, 3 do fast.now = fast.now + 2; fast.env.Update() end
        equal(fast.count('!UnpauseMeasureGroup'), 1, 'A 5 s staged stale limit fails live after 6 s')
        for _, bad in ipairs({ '4', '181', 'x' }) do
            local other = live({ variables = { ParallaxIdleTestStaleSeconds = bad } })
            other.broadcast('1')
            other.reset()
            other.now = other.now + 60
            other.env.Update()
            equal(#other.bangs, 0, 'Out-of-bounds stale hook ' .. bad .. ' keeps 180 s')
        end
    end)

    scenario('refresh standby: one request to the writer, freeze after the standby reload, fail live', function()
        local writer = { ParallaxIdleStandbyMode = 'refresh', ParallaxIdleStandbyWriter = 'MeasureMediaOptions', ParallaxIdleStandbyState = '0' }
        local state = live({ variables = writer })
        state.broadcast('1')
        expectSequence(state, { "!CommandMeasure MeasureMediaOptions IdleStandby(1, 'standby')" }, 'Live load, paused: one standby request, no in-place freeze')
        state.reset()
        state.now = state.now + 5
        state.broadcast('1')
        equal(#state.bangs, 0, 'No repeat while the posted reload is pending')
        state.now = state.now + 60
        state.broadcast('1')
        equal(#state.bangs, 0, 'Still pending a minute later: a posted reload always comes')
        -- A writer that posts no reload: retried at most every 30 s; the
        -- live load never freezes in place (it stays live).
        local stuck = live({ variables = writer, writerReloads = false })
        stuck.broadcast('1')
        expectSequence(stuck, { "!CommandMeasure MeasureMediaOptions IdleStandby(1, 'standby')" }, 'Failing writer: one request')
        stuck.reset()
        stuck.now = stuck.now + 5
        stuck.broadcast('1')
        equal(#stuck.bangs, 0, 'No repeat within 30 s')
        stuck.now = stuck.now + 30
        stuck.broadcast('1')
        expectSequence(stuck, { "!CommandMeasure MeasureMediaOptions IdleStandby(1, 'standby')" }, 'A retry after 30 s, and no in-place freeze of a live load')
        -- The reload built in standby.
        local standby = { ParallaxIdleStandbyMode = 'refresh', ParallaxIdleStandbyWriter = 'MeasureMediaOptions', ParallaxIdleStandbyState = '1' }
        local reloaded = fixture({ idleActive = 1, variables = standby })
        reloaded.load()
        reloaded.env.Update()
        reloaded.broadcast('1')
        expectSequence(reloaded, ENTER, 'A standby load that is still wanted freezes in place')
        reloaded.reset()
        reloaded.broadcast('0')
        expectSequence(reloaded, { "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'standby')" }, 'Input: one request back, no in-place leave')
        -- Restart while in standby with input recent: back to live in one request.
        local restarted = fixture({ idleActive = 1, variables = standby })
        restarted.load()
        restarted.env.Update()
        restarted.broadcast('0')
        expectSequence(restarted, { "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'standby')" }, 'Restart with input recent: live again')
        -- No coordinator 10 s after a standby load: fail live once.
        local orphan = fixture({ idleActive = 1, variables = standby })
        orphan.load()
        orphan.env.Update()
        orphan.now = orphan.now + 1
        orphan.env.Update()
        equal(orphan.count('!CommandMeasure MeasureMediaOptions'), 0, 'Not before 10 s')
        orphan.reset()
        orphan.now = orphan.now + 10
        orphan.env.Update()
        equal(orphan.bangs[1], "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'fail-live')", 'Unsynced 10 s after a standby load fails live')
        -- A stale beat in standby fails live through the writer, then re-joins.
        local stale = fixture({ idleActive = 1, variables = standby })
        stale.load()
        stale.env.Update()
        stale.broadcast('1')
        stale.reset()
        for _ = 1, 4 do stale.now = stale.now + 60; stale.env.Update() end
        equal(stale.bangs[1], "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'fail-live')", 'Stale beat in standby fails live')
        equal(stale.bangs[2], '!UpdateMeasureGroup ParallaxIdleSyncRequest *', 'Then re-joins')
        -- In-place skins never fail live while unsynced (nothing persisted).
        local inplace = fixture({ idleActive = 1 })
        inplace.load()
        inplace.env.Update()
        inplace.now = inplace.now + 20
        inplace.env.Update()
        equal(inplace.count('!CommandMeasure'), 0, 'An in-place skin has nothing to fail')
    end)

    scenario('Closing broadcast (away 0, paused 0) and a beat older than the load', function()
        local state = live()
        state.broadcast('1')
        state.reset()
        state.broadcast('0')
        equal(state.count('!UnpauseMeasureGroup'), 1, 'The coordinator\'s unload notice resumes at once')
        -- A beat older than 3 minutes, seen more than 3 minutes after the
        -- load, is stale: no freeze. (Within 3 minutes of a load the load time
        -- is the clock base, as a reload resets the beat to 0.)
        local old = fixture({ idleActive = 1 })
        old.load()
        old.env.Update()
        old.now = old.now + 50
        old.env.Update()
        old.now = old.now + 50
        old.env.Update()
        old.now = old.now + 100
        old.broadcast('1', old.now - 400)
        equal(old.count('!PauseMeasureGroup'), 0, 'A stale beat never freezes')
    end)

    scenario('refresh standby without a reload: a frozen standby load leaves in place, then asks again', function()
        local standby = { ParallaxIdleStandbyMode = 'refresh', ParallaxIdleStandbyWriter = 'MeasureMediaOptions', ParallaxIdleStandbyState = '1' }
        local state = fixture({ idleActive = 1, variables = standby, writerReloads = false })
        state.load()
        state.env.Update()
        state.broadcast('1')
        expectSequence(state, ENTER, 'A wanted standby load freezes in place')
        state.reset()
        state.broadcast('0')
        local expected = { "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'standby')" }
        for _, bang in ipairs(LEAVE) do expected[#expected + 1] = bang end
        expectSequence(state, expected, 'Input and no reload posted: the request, then an in-place leave at once')
        state.reset()
        state.now = state.now + 5
        state.broadcast('0')
        equal(#state.bangs, 0, 'Live in place: no repeat within 30 s')
        state.now = state.now + 30
        state.broadcast('0')
        expectSequence(state, { "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'standby')" }, 'Asked again after 30 s; already live, nothing else')
        state.reset()
        state.broadcast('1')
        expectSequence(state, ENTER, 'Idle again in the same standby load: freezes in place again')
        -- A reload already pending (posted by an earlier request in this load):
        -- nothing is asked and nothing is done; the reload ends this load.
        local pending = fixture({ idleActive = 1, variables = standby })
        pending.load()
        pending.env.Update()
        pending.broadcast('1')
        pending.variables.ParallaxIdleStandbyPending = '1'
        pending.reset()
        pending.broadcast('0')
        equal(#pending.bangs, 0, 'Reload pending: no second request and no in-place leave')
        -- The stale-beat fail-live path with no reload also leaves in place.
        local stale = fixture({ idleActive = 1, variables = standby, writerReloads = false })
        stale.load()
        stale.env.Update()
        stale.broadcast('1')
        stale.reset()
        for _ = 1, 4 do stale.now = stale.now + 60; stale.env.Update() end
        equal(stale.bangs[1], "!CommandMeasure MeasureMediaOptions IdleStandby(0, 'fail-live')", 'Stale: the fail-live request')
        equal(stale.count('!UnpauseMeasureGroup'), 1, 'No reload posted: leaves in place')
        equal(stale.bangs[#stale.bangs], '!UpdateMeasureGroup ParallaxIdleSyncRequest *', 'Then re-joins')
    end)

    scenario('a re-entry during the last allowed pass is re-run from a delayed update, bounded', function()
        local DELAYED = '[!Delay 100][!UpdateMeasureGroup ParallaxIdleHook]'
        local state = live()
        -- Every enter and leave triggers a nested broadcast with the opposite level.
        state.onBang = function(args)
            if args[1] == '!PauseMeasureGroup' or args[1] == '!UnpauseMeasureGroup' then
                state.variables.ParallaxIdlePaused = args[1] == '!PauseMeasureGroup' and '0' or '1'
                state.env.Update()
            end
        end
        state.broadcast('1')
        equal(state.count('!PauseMeasureGroup'), 2, 'Passes 1 and 3 entered')
        equal(state.count('!UnpauseMeasureGroup'), 1, 'Pass 2 left')
        equal(state.bangs[#state.bangs], DELAYED, 'The re-entry in pass 3 is not dropped: a delayed update is armed')
        state.onBang = nil
        state.reset()
        state.env.Update()                 -- the delayed group update
        equal(state.count('!UnpauseMeasureGroup'), 1, 'The delayed update reconciles the latest level (live)')
        equal(state.count(DELAYED), 0, 'A clean pass arms nothing')
        -- Bounded: a loop that never settles arms at most three in a row.
        local loop = live()
        loop.onBang = function(args)
            if args[1] == '!PauseMeasureGroup' or args[1] == '!UnpauseMeasureGroup' then
                loop.variables.ParallaxIdlePaused = args[1] == '!PauseMeasureGroup' and '0' or '1'
                loop.env.Update()
            end
        end
        loop.broadcast('1')
        for _ = 1, 4 do loop.env.Update() end
        equal(loop.count(DELAYED), 3, 'At most three delayed updates in a row')
    end)

    -- The headline: hidden on enter (not covered), restored on leave exactly
    -- as it was, including INI formulas and meters a variant lacks.
    local function headlineMeters()
        return {
            MeterTitle = { Hidden = '0' }, MeterTotal = { Hidden = '0' }, MeterOptions = { Hidden = '1' },
            MeterOff = { Hidden = '(1-0)' }, MeterOn = { Hidden = '(1-1)' }, MeterParallaxPaused = { Hidden = '1' },
        }
    end
    local headlineVariables = {
        ParallaxIdleHeadline = 'MeterTitle|MeterTotal|MeterOff|MeterOn|MeterAbsent',
        ParallaxIdleHoverSwap = 'MeterOptions|MeterTotal',
    }
    local HIDE = { '!HideMeter MeterTitle', '!HideMeter MeterTotal', '!HideMeter MeterOn' }
    local SHOW = { '!ShowMeter MeterTitle', '!ShowMeter MeterTotal', '!ShowMeter MeterOn' }
    local function withHeadline(base, extra, at)
        local out = {}
        for index, bang in ipairs(base) do
            out[#out + 1] = bang
            if bang == at then for _, item in ipairs(extra) do out[#out + 1] = item end end
        end
        return out
    end

    scenario('the headline is hidden while paused and restored as it was', function()
        local state = live({ variables = headlineVariables, meters = headlineMeters() })
        state.broadcast('1')
        expectSequence(state, withHeadline(ENTER, HIDE, '!UpdateMeterGroup ParallaxIdleFreeze'), 'Enter hides the visible headline meters after the freeze pass')
        equal(state.meters.MeterTitle.Hidden, '1', 'Title hidden')
        equal(state.meters.MeterTotal.Hidden, '1', 'Value hidden')
        equal(state.meters.MeterOn.Hidden, '1', 'A formula-visible meter is hidden')
        equal(state.meters.MeterOff.Hidden, '(1-0)', 'An already hidden meter is left alone')
        equal(state.meters.MeterOptions.Hidden, '1', 'The gear is not touched')
        state.reset()
        state.broadcast('0')
        expectSequence(state, withHeadline(LEAVE, SHOW, '!HideMeter MeterParallaxPaused'), 'Leave restores after the meter pass, before RestoreHeadline')
        equal(state.meters.MeterTitle.Hidden, '0', 'Title back')
        equal(state.meters.MeterTotal.Hidden, '0', 'Value back')
        equal(state.meters.MeterOn.Hidden, '0', 'Formula-visible meter back')
        equal(state.meters.MeterOff.Hidden, '(1-0)', 'Hidden meter still hidden, untouched')
        -- A second pause records again.
        state.reset()
        state.broadcast('1')
        equal(state.count('!HideMeter MeterTitle'), 1, 'Second enter hides again')
        -- The watchdog's fail-live leave restores too.
        state.reset()
        for _ = 1, 4 do state.now = state.now + 60; state.env.Update() end
        equal(state.count('!ShowMeter MeterTitle'), 1, 'Fail-live restores the headline')
        -- No list: no meter is touched (Off-equivalent wiring, older entrypoints).
        local bare = live({ meters = headlineMeters() })
        bare.broadcast('1')
        expectSequence(bare, ENTER, 'No ParallaxIdleHeadline: the plain sequence')
    end)

    scenario('hover pair: the gear follows the pointer, the frozen value never shows', function()
        -- Hover-out during the pause: the skin's swap shows the value, Hover() hides it again.
        local state = live({ variables = headlineVariables, meters = headlineMeters() })
        state.env.Hover()
        equal(#state.bangs, 0, 'Hover() while live does nothing')
        state.broadcast('1')
        state.reset()
        state.meters.MeterOptions.Hidden = '0'                    -- MouseOverAction
        state.meters.MeterTotal.Hidden = '1'
        state.env.Hover()
        equal(#state.bangs, 0, 'Hover-in while paused: nothing to hide')
        state.meters.MeterOptions.Hidden = '1'                    -- MouseLeaveAction
        state.meters.MeterTotal.Hidden = '0'
        state.env.Hover()
        expectSequence(state, { '!HideMeter MeterTotal' }, 'Hover-out while paused hides the frozen value again')
        state.reset()
        state.broadcast('0')
        equal(state.meters.MeterTotal.Hidden, '0', 'Gear hidden at enter and at leave: the value returns')
        -- Hover-in during the pause, pointer still over the skin at resume.
        local inside = live({ variables = headlineVariables, meters = headlineMeters() })
        inside.broadcast('1')
        inside.meters.MeterOptions.Hidden = '0'
        inside.meters.MeterTotal.Hidden = '1'
        inside.env.Hover()
        inside.reset()
        inside.broadcast('0')
        equal(inside.meters.MeterTotal.Hidden, '1', 'Gear shown at resume: the value stays hidden')
        equal(inside.meters.MeterOptions.Hidden, '0', 'and the gear stays shown')
        equal(inside.count('!ShowMeter MeterTotal'), 0, 'No show for the value')
        -- Paused while hovered (gear shown, value hidden), hover-out before resume.
        local hovered = headlineMeters()
        hovered.MeterOptions.Hidden = '0'
        hovered.MeterTotal.Hidden = '1'
        local parked = live({ variables = headlineVariables, meters = hovered })
        parked.broadcast('1')
        equal(parked.count('!HideMeter MeterTotal'), 0, 'An already hidden value is not hidden again')
        parked.meters.MeterOptions.Hidden = '1'
        parked.meters.MeterTotal.Hidden = '0'
        parked.env.Hover()
        equal(parked.meters.MeterTotal.Hidden, '1', 'Hover-out while paused hides it')
        parked.broadcast('0')
        equal(parked.meters.MeterTotal.Hidden, '0', 'The gear moved during the pause: the value follows it (shown)')
        -- Paused while hovered, still hovered at resume.
        local still = headlineMeters()
        still.MeterOptions.Hidden = '0'
        still.MeterTotal.Hidden = '1'
        local stay = live({ variables = headlineVariables, meters = still })
        stay.broadcast('1')
        stay.broadcast('0')
        equal(stay.meters.MeterTotal.Hidden, '1', 'Hovered throughout: the value stays hidden')
        -- A half-specified pair is ignored (no gear logic, plain restore).
        local half = live({ variables = { ParallaxIdleHeadline = 'MeterTotal', ParallaxIdleHoverSwap = 'MeterOptions' }, meters = headlineMeters() })
        half.broadcast('1')
        half.meters.MeterOptions.Hidden = '0'
        half.env.Hover()
        half.broadcast('0')
        equal(half.meters.MeterTotal.Hidden, '0', 'No pair: the snapshot is restored')
    end)

    return 'PASS: ' .. passed .. ' assertions in ' .. #cases .. ' stand-down scenarios; ' .. _VERSION .. '.\n' .. table.concat(cases, '\n')
end

return Suite
