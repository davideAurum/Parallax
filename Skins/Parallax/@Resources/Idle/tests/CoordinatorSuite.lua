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
    local mediaInc = resources .. 'User\\Media.inc'
    local stateInc = resources .. 'Modules\\Media\\CaptureState.inc'

    -- A fresh coordinator or link environment. options.files: path -> text
    -- (or false for an unreadable file); options.variables override SKIN
    -- variables; options.idle is the raw IDLE_TIME value.
    local function fixture(options)
        options = options or {}
        local state = { bangs = {}, now = options.now or 1000000, idle = options.idle, files = {} }
        for path, text in pairs(options.files or {}) do state.files[path] = text end
        local variables = {
            ['@'] = resources, ROOTCONFIG = 'Parallax', SETTINGSPATH = settingsPath, SKINSPATH = skins,
            ParallaxIdleTestFile = '', ParallaxIdleTestAwaySeconds = '', ParallaxIdleTestReevaluateTicks = '',
            ParallaxIdleTestHeartbeatTicks = ''
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
            state.bangs[#state.bangs + 1] = table.concat(args, ' ')
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
        local fakeOs = { time = function() return state.now end }
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
            equal(#state.bangs, 0, 'Initialize sends nothing')
        end
        function state.link()
            local chunk = assert(loadfile(linkPath))
            setfenv(chunk, env)
            return chunk().new(skin)
        end
        function state.reset() state.bangs = {} end
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
    local function expectBroadcast(state, away, message)
        local expected = broadcastOf(away, '0', string.format('%d', state.now))
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
        local state = fixture({ idle = 0 })
        state.load()
        equal(state.env.Wrap(0 / 0), nil, 'NaN')
        equal(state.env.Wrap(-1), nil, 'Negative')
        equal(state.env.Wrap(math.huge), nil, 'Infinite')
        equal(state.env.Wrap(nil), nil, 'Missing')
        state.env.Start()
        state.reset()
        state.idle = 0 / 0
        state.now = state.now + 2
        state.env.Update()
        equal(#state.bangs, 0, 'An invalid sample keeps the last state and sends nothing')
        state.idle = -5
        state.now = state.now + 2
        state.env.Update()
        equal(#state.bangs, 0, 'A negative sample keeps the last state')
        state.idle = false
        state.now = state.now + 2
        state.env.Update()
        equal(#state.bangs, 0, 'A missing measure keeps the last state')
    end)

    scenario('nothing is sent before Start, and Sync before Start is ignored', function()
        -- Nothing needs this coordinator (no Media), so only a request could
        -- unload it before its regular 300-tick check.
        local state = fixture({ idle = 600, files = { [settingsFile] = rainmeterIni({ { 'Parallax\\Idle', 1 } }, 'utf16') } })
        state.load()
        for _ = 1, 5 do state.now = state.now + 2; equal(state.env.Update(), 0, 'Update waits for Start') end
        state.env.Sync()
        state.env.RequestReevaluate()
        equal(#state.bangs, 0, 'No bang before Start')
        state.env.Start()
        expectBroadcast(state, '1', 'Start broadcasts the current state once')
        -- The request Calcs also fire during the load, before Start: a
        -- re-evaluation requested then must not unload a needless coordinator
        -- early (it waits for its regular 300-tick check).
        state.reset()
        for _ = 1, 20 do state.now = state.now + 2; state.env.Update() end
        equal(state.count('!DeactivateConfig'), 0, 'A request made before Start is dropped')
    end)

    scenario('broadcast only on change, heartbeat and tick gap, with the exact bangs', function()
        local state = fixture({ idle = 0 })
        state.load()
        state.env.Start()
        expectBroadcast(state, '0', 'Start')
        state.reset()
        -- 29 quiet ticks: heartbeat every 30 ticks of 2 s.
        for tick = 1, 29 do
            state.now = state.now + 2
            state.idle = tick
            state.env.Update()
        end
        equal(#state.bangs, 0, 'An unchanged state sends nothing between heartbeats')
        state.now = state.now + 2
        state.env.Update()
        expectBroadcast(state, '0', 'Heartbeat on tick 30 (about 60 s)')
        state.reset()
        state.idle = 299
        state.now = state.now + 2
        state.env.Update()
        equal(#state.bangs, 0, 'Below 300 s is not away')
        state.idle = 300
        state.now = state.now + 2
        state.env.Update()
        expectBroadcast(state, '1', 'Away at 300 s')
        state.reset()
        state.idle = 302
        state.now = state.now + 2
        state.env.Update()
        equal(#state.bangs, 0, 'Still away sends nothing')
        state.idle = 0
        state.now = state.now + 2
        state.env.Update()
        expectBroadcast(state, '0', 'Input clears away at the next tick')
        state.reset()
        state.idle = 1
        state.now = state.now + 11
        state.env.Update()
        expectBroadcast(state, '0', 'A tick gap over 10 s (sleep) re-broadcasts')
        state.reset()
        state.now = state.now - 30
        state.env.Update()
        expectBroadcast(state, '0', 'A clock moved backwards re-broadcasts')
        state.reset()
        state.env.Sync()
        expectBroadcast(state, '0', 'Sync after Start repeats the state')
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

    return 'PASS: ' .. passed .. ' assertions in ' .. #cases .. ' coordinator scenarios; ' .. _VERSION .. '.\n' .. table.concat(cases, '\n')
end

return Suite
