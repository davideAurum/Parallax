-- Offline suite for @Resources\Update\Update.lua. Runs the production script
-- in three roles against a mock SKIN whose !WriteKeyValue really writes a
-- private copy of State.inc, so claims, results and dismissals are read back
-- through the shipped Idle\Link.lua reader exactly as in Rainmeter. Nothing
-- outside the private work directory is read or written.
-- suite.run(updatePath, resourcesPath, workPath) returns the assertion count.
local suite = {}

local BASE = 'https://github.com/davideAurum/Parallax/releases/'
local INSTALLED = '0.1.0-alpha.8'

local function readFile(path)
    local file = io.open(path, 'rb'); if not file then return nil end
    local text = file:read('*a'); file:close(); return text
end
local function writeFile(path, text)
    local file = assert(io.open(path, 'wb')); file:write(text); file:close()
end

-- A minimal !WriteKeyValue: replaces key= in [section] or appends it. Like
-- Rainmeter's, it never creates a missing file.
local function writeKey(path, section, key, value)
    local text = readFile(path)
    if not text then return end
    local out, inSection, done, seen = {}, false, false, false
    for line in (text .. (text:sub(-1) == '\n' and '' or '\n')):gmatch('([^\n]*)\n') do
        line = line:gsub('\r$', '')
        local name = line:match('^%s*%[([^%]]+)%]%s*$')
        if name then
            if inSection and not done then out[#out + 1] = key .. '=' .. value; done = true end
            inSection = name:lower() == section:lower(); seen = seen or inSection
        elseif inSection and not done and line:match('^%s*([%w_]+)%s*=') and line:match('^%s*([%w_]+)'):lower() == key:lower() then
            line = key .. '=' .. value; done = true
        end
        out[#out + 1] = line
    end
    if not done then
        if not seen then out[#out + 1] = '[' .. section .. ']' end
        out[#out + 1] = key .. '=' .. value
    end
    writeFile(path, table.concat(out, '\r\n') .. '\r\n')
end

local function feed(version, extra)
    local fields = {
        '"schema": 1', '"name": "Parallax"', '"version": "' .. version .. '"',
        '"url": "' .. BASE .. 'download/v' .. version .. '/Parallax_' .. version .. '.rmskin"',
        '"sha256": "' .. string.rep('ab', 32) .. '"', '"bytes": 1', '"minimumRainmeter": "4.5.26"',
        '"notes": "' .. BASE .. 'tag/v' .. version .. '"' }
    if extra then fields[#fields + 1] = extra end
    return '{' .. table.concat(fields, ', ') .. '}'
end

function suite.run(updatePath, resourcesPath, workPath)
    local passed = 0
    local function check(value, message)
        if not value then error(message, 2) end
        passed = passed + 1
    end
    local function eq(a, b, label)
        if a ~= b then error(label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
        passed = passed + 1
    end

    -- Private tree: @Resources with the shipped Link.lua and a blank State.inc,
    -- Skins\Parallax\Update\Update.ini, and a Rainmeter.ini to edit.
    local at = workPath .. '\\@Resources\\'
    local statePath = at .. 'Update\\State.inc'
    local settingsPath = workPath .. '\\Rainmeter.ini'
    local promptIni = workPath .. '\\Skins\\Parallax\\Update\\Update.ini'
    writeFile(at .. 'Idle\\Link.lua', assert(readFile(resourcesPath .. '\\Idle\\Link.lua'), 'Link.lua'))
    local blank = assert(readFile(resourcesPath .. '\\Update\\State.inc'), 'State.inc')
    local function resetState() writeFile(statePath, blank) end
    local function setPromptActive(value, windowX)
        local text = '[Rainmeter]\r\nSkinPath=' .. workPath .. '\\Skins\\\r\n'
        if value then text = text .. '[Parallax\\Update]\r\nActive=' .. value .. '\r\n' end
        if windowX then text = text .. 'WindowX=' .. windowX .. '\r\n' end
        writeFile(settingsPath, text)
    end
    writeFile(promptIni, '[Rainmeter]\r\n')
    resetState(); setPromptActive('0')

    -- Shipped State.inc must hold no user data.
    for _, line in ipairs({ 'UpdateCheckedAt=0', 'UpdateResultAt=0', 'UpdateResult=', 'UpdateLatest=', 'UpdateLatestAt=0',
        'UpdateUrl=', 'UpdateSha256=', 'UpdateNotes=', 'UpdateDismissed=' }) do
        check(blank:find('\n' .. line .. '\r?\n') ~= nil, 'Shipped State.inc must ship blank: ' .. line)
    end

    local function load(role, vars)
        local self = { calls = {}, feedText = '', installOutput = '', clock = 100, now = os.time(), writable = true }
        local values = { ['@'] = at, ParallaxVersion = INSTALLED, UpdateReleaseBase = BASE, ParallaxUpdateRole = role,
            SETTINGSPATH = workPath .. '\\', SKINSPATH = workPath .. '\\Skins\\', ROOTCONFIG = 'Parallax',
            CURRENTCONFIG = 'Parallax\\Update', PROGRAMPATH = 'C:\\Program Files\\Rainmeter\\', UpdateCheck = '1',
            MutedColor = '175,175,175', DangerColor = '235,55,75', WORKAREAX = '0', WORKAREAY = '0',
            WORKAREAWIDTH = '1920', WORKAREAHEIGHT = '1040', WindowWidth = '228' }
        for key, value in pairs(vars or {}) do values[key] = value end
        self.vars = values
        local skin = {}
        function skin.GetVariable(_, name, default)
            local value = values[name]
            if value == nil then return default end
            return value
        end
        function skin.Bang(_, ...)
            local call = { ... }
            table.insert(self.calls, call)
            if call[1] == '!WriteKeyValue' and self.writable then writeKey(call[5], call[2], call[3], call[4]) end
        end
        function skin.GetMeasure(_, name)
            if name == 'MeasureParallaxUpdateFeed' then return { GetStringValue = function() return self.feedText end } end
            if name == 'MeasureParallaxUpdateInstall' then return { GetStringValue = function() return self.installOutput end } end
        end
        function skin.ReplaceVariables(_, text) return (text:gsub('#(%w+)#', function(name) return values[name] or '' end)) end
        function skin.ParseFormula(_, text) return tonumber(text) end
        local env = setmetatable({ SKIN = skin }, { __index = _G })
        env.os = setmetatable({ clock = function() return self.clock end, time = function(t) if t then return os.time(t) end return self.now end },
            { __index = os })
        env.dofile = function(path)
            local chunk = assert(loadfile(path)); setfenv(chunk, env); return chunk()
        end
        local chunk = assert(loadfile(updatePath))
        setfenv(chunk, env); chunk()
        env.Initialize()
        self.env = env
        function self.reset() self.calls = {} end
        function self.find(name, a, b)
            for _, call in ipairs(self.calls) do
                if call[1] == name and (a == nil or call[2] == a) and (b == nil or call[3] == b) then return call end
            end
        end
        function self.text(meter)
            local found
            for _, call in ipairs(self.calls) do
                if call[1] == '!SetOption' and call[2] == meter and call[3] == 'Text' then found = call[4] end
            end
            return found
        end
        function self.option(meter, option)
            local found
            for _, call in ipairs(self.calls) do
                if call[1] == '!SetOption' and call[2] == meter and call[3] == option then found = call[4] end
            end
            return found
        end
        function self.shown(meter)
            local state
            for _, call in ipairs(self.calls) do
                if call[2] == meter and (call[1] == '!ShowMeter' or call[1] == '!HideMeter') then state = call[1] == '!ShowMeter' end
            end
            return state
        end
        function self.delays()
            local list = {}
            for _, call in ipairs(self.calls) do
                local ms, fn, token = tostring(call[1]):match('^%[!Delay (%d+)%]%[!CommandMeasure MeasureParallaxUpdate "(%a+)%((%d+)%)"%]$')
                if ms then list[#list + 1] = { ms = tonumber(ms), fn = fn, token = tonumber(token) } end
            end
            return list
        end
        function self.requested()
            return self.find('!EnableMeasure', 'MeasureParallaxUpdateFeed') ~= nil
                and self.find('!CommandMeasure', 'MeasureParallaxUpdateFeed', 'Update') ~= nil
                and self.find('!UpdateMeasure', 'MeasureParallaxUpdateFeed') ~= nil
        end
        return self
    end
    local function state()
        local text = readFile(statePath)
        local values = {}
        for key, value in text:gmatch('\n([%w_]+)=([^\r\n]*)') do values[key] = value end
        return values
    end

    -- Version order and feed validation (unchanged from the Welcome checker).
    local probe = load('hook')
    local C = probe.env.CompareVersions
    eq(C('0.1.0', '0.2.0'), -1, 'minor'); eq(C('1.0.0', '0.9.9'), 1, 'major')
    eq(C('0.1.0-alpha', '0.1.0'), -1, 'pre before release'); eq(C('0.1.0', '0.1.0-alpha'), 1, 'release after pre')
    eq(C('0.1.0-alpha', '0.1.0-beta'), -1, 'alpha before beta'); eq(C('0.1.0-alpha', '0.1.0-alpha.1'), -1, 'shorter pre first')
    eq(C('0.1.0-alpha.2', '0.1.0-alpha.10'), -1, 'numeric identifiers'); eq(C('0.1.0-2', '0.1.0-alpha'), -1, 'numeric before text')
    eq(C('0.1.0-alpha.8', '0.1.0-alpha.8'), 0, 'equal'); eq(C('0.1.0+build.5', '0.1.0'), nil, 'build metadata refused')
    eq(C('0.10.0', '0.9.0'), 1, 'numeric not lexical'); eq(C('dev', '0.1.0'), nil, 'unreadable'); eq(C('0.1', '0.1.0'), nil, 'two-part refused')
    local P = probe.env.ParseFeed
    local item = P(feed('0.2.0'))
    eq(item and item.version, '0.2.0', 'good feed'); eq(item and item.notes, BASE .. 'tag/v0.2.0', 'good notes')
    eq(P(feed('0.2.0'):gsub('"schema": 1', '"schema": 2')), nil, 'future schema refused')
    eq(P(feed('0.2.0'):gsub('"Parallax"', '"Other"')), nil, 'other package refused')
    eq(P(feed('0.2.0'):gsub('https://github.com/davideAurum/Parallax/releases/download', 'https://example.com/download')), nil, 'foreign host refused')
    eq(P(feed('0.2.0'):gsub('download/v0.2.0/Parallax_0.2.0', 'download/v0.3.0/Parallax_0.3.0')), nil, 'mismatched asset refused')
    eq(P(feed('0.2.0'):gsub(string.rep('ab', 32), 'abc')), nil, 'short checksum refused')
    eq(P(feed('0.2.0 x')), nil, 'spaces refused'); eq(P(feed('0.2.0\\" & calc')), nil, 'escaped quote refused')
    eq(P((feed('0.2.0'):gsub('"notes": "[^"]*"', '"notes": "https://example.com/notes"'))).notes, nil, 'foreign notes dropped')
    -- Failure classification by body: GitHub's 404 body, rate-limit pages, junk.
    local K = probe.env.Classify
    eq(select(2, K('Not Found')), 'missing', '404 body is no release')
    eq(select(2, K('{"error":"Not Found"}')), 'missing', 'the 404 body WebParser receives')
    eq(select(2, K('{"message":"API rate limit exceeded for 1.2.3.4."}')), 'ratelimit', 'API rate limit')
    eq(select(2, K('<html><title>Too Many Requests</title></html>')), 'ratelimit', '429 page')
    eq(select(2, K('')), 'format', 'empty body'); eq(select(2, K('<html>Server Error</html>')), 'format', 'other page')
    eq(select(2, K(string.rep(' ', 9000) .. feed('0.2.0'))), 'format', 'oversized feed')
    eq(K(feed('0.2.0')).version, '0.2.0', 'good feed classified')
    -- Due: a day after a good check, an hour after a failed or unfinished one.
    local D, now = probe.env.Due, 1800000000
    check(D(now, { checkedAt = 0 }), 'Never checked is due')
    check(not D(now, { checkedAt = now - 3600, resultAt = now - 3599, result = 'current' }), 'Good check an hour ago is not due')
    check(not D(now, { checkedAt = now - 86399, resultAt = now - 86398, result = 'available' }), 'Good check a second short of a day')
    check(D(now, { checkedAt = now - 86400, resultAt = now - 86399, result = 'current' }), 'Good check a day ago is due')
    check(not D(now, { checkedAt = now - 3599, resultAt = now - 3598, result = 'offline' }), 'Failure retries after an hour, not before')
    check(D(now, { checkedAt = now - 3600, resultAt = now - 3599, result = 'ratelimit' }), 'Failure an hour ago is due')
    check(D(now, { checkedAt = now - 3600, resultAt = now - 90000, result = 'current' }), 'An unfinished check retries after an hour')
    check(not D(now, { checkedAt = now - 1800, resultAt = now - 90000, result = 'current' }), 'An unfinished check waits an hour')
    check(D(now, { checkedAt = now + 301, resultAt = now + 301, result = 'current' }), 'A clock that went back makes it due')
    check(not D(now, { checkedAt = now + 200, resultAt = now + 200, result = 'current' }), 'Small skew is not a clock change')
    local O = probe.env.OpenDue
    check(O(now, { checkedAt = 0 }) and O(now, { checkedAt = now - 600 }) and not O(now, { checkedAt = now - 599 }), 'Settings opens check after 10 minutes')

    -- Hook: first update arms the first look; Tick re-arms first and claims.
    resetState(); setPromptActive('0')
    local hook = load('hook', { ParallaxUpdateFirstDelay = '60000', ParallaxUpdateTickMs = '3600000' })
    hook.reset(); hook.env.Update()
    local armed = hook.delays()
    check(#armed == 1 and armed[1].ms == 60000 and armed[1].fn == 'Tick', 'Load arms one first look at 60 s')
    local token = armed[1].token
    hook.reset(); hook.env.Update()
    check(#hook.calls == 0, 'Later hook updates do nothing')
    hook.reset(); check(not hook.env.Tick(token + 1) and #hook.calls == 0, 'A stale timer is ignored')
    hook.reset(); check(hook.env.Tick(token), 'A due tick checks')
    armed = hook.delays()
    check(#armed == 1 and armed[1].ms == 3600000 and armed[1].token == token, 'The tick re-arms hourly with this load token')
    check(hook.calls[1][1]:match('^%[!Delay'), 'The tick re-arms before anything else')
    check(hook.requested(), 'A due tick enables and starts the feed request')
    eq(state().UpdateCheckedAt, tostring(hook.now), 'The claim is saved')
    local other = load('hook')
    other.env.Update(); local otherToken = other.delays()[1].token
    other.reset(); check(not other.env.Tick(otherToken), 'Another utility sees the claim')
    check(not other.requested(), 'Only one request per due check')
    -- Newer feed: saved, prompt opened once, views told.
    hook.feedText = feed('99.0.0')
    hook.reset(); check(hook.env.FeedReady(), 'Newer feed accepted')
    check(hook.find('!DisableMeasure', 'MeasureParallaxUpdateFeed') ~= nil, 'Feed disabled after the request')
    local s = state()
    eq(s.UpdateResult, 'available', 'result'); eq(s.UpdateLatest, '99.0.0', 'latest saved')
    eq(s.UpdateUrl, BASE .. 'download/v99.0.0/Parallax_99.0.0.rmskin', 'url saved'); eq(s.UpdateSha256, string.rep('ab', 32), 'sha saved')
    eq(s.UpdateNotes, BASE .. 'tag/v99.0.0', 'notes saved'); eq(s.UpdateResultAt, tostring(hook.now), 'result time')
    local activate = hook.find('!ActivateConfig')
    check(activate and activate[2] == 'Parallax\\Update' and activate[3] == 'Update.ini', 'Background available opens the prompt')
    check(hook.find('!UpdateMeasureGroup', 'ParallaxUpdateView', '*') ~= nil, 'Views are told')
    hook.reset(); check(not hook.env.FeedReady() and #hook.calls == 0, 'A late second finish does nothing')
    -- Already open, dismissed, or no Update.ini: no activation.
    local function backgroundAgain(prepare)
        local h = load('hook'); h.env.Update(); local t = h.delays()[1].token
        writeKey(statePath, 'Variables', 'UpdateCheckedAt', '0')
        if prepare then prepare() end
        h.reset(); h.env.Tick(t); h.feedText = feed('99.0.0'); h.reset(); h.env.FeedReady()
        return h.find('!ActivateConfig') ~= nil
    end
    setPromptActive('1'); check(not backgroundAgain(), 'An open prompt is not activated again')
    setPromptActive('0')
    writeKey(statePath, 'Variables', 'UpdateDismissed', '99.0.0'); check(not backgroundAgain(), 'A dismissed version does not prompt')
    writeKey(statePath, 'Variables', 'UpdateDismissed', '')
    os.remove(promptIni); check(not backgroundAgain(), 'Missing Update.ini never activates')
    writeFile(promptIni, '[Rainmeter]\r\n')
    os.remove(settingsPath); check(not backgroundAgain(), 'Unreadable Rainmeter.ini never activates')
    setPromptActive('0'); check(backgroundAgain(), 'The control case still prompts')
    -- Not newer and failures: recorded, never a prompt.
    local function finishWith(text, errorKind)
        resetState()
        local h = load('hook'); h.env.Update(); local t = h.delays()[1].token
        h.reset(); h.env.Tick(t); h.feedText = text or ''
        h.reset()
        if errorKind then h.env.FeedError(errorKind) else h.env.FeedReady() end
        return state(), h
    end
    local sameState, same = finishWith(feed(INSTALLED))
    eq(sameState.UpdateResult, 'current', 'equal is current'); check(not same.find('!ActivateConfig'), 'equal never prompts')
    eq(finishWith(feed('0.1.0-alpha.7')).UpdateResult, 'current', 'older is current')
    eq(finishWith('Not Found').UpdateResult, 'missing', 'missing recorded')
    eq(finishWith('API rate limit exceeded').UpdateResult, 'ratelimit', 'rate limit recorded')
    eq(finishWith(nil, 'connect').UpdateResult, 'offline', 'offline recorded')
    local formatState, formatHook = finishWith(nil, 'format')
    eq(formatState.UpdateResult, 'format', 'unreadable recorded'); eq(formatState.UpdateLatest, '', 'a failure saves no version')
    check(not formatHook.find('!ActivateConfig'), 'failures never prompt')
    -- An unwritable state file stops background checks instead of repeating them.
    resetState()
    local stuck = load('hook'); stuck.writable = false; stuck.env.Update(); local stuckToken = stuck.delays()[1].token
    stuck.reset(); check(not stuck.env.Tick(stuckToken) and not stuck.requested(), 'No request without a saved claim')
    -- A missing State.inc (incomplete installation): no background check, and
    -- Global Settings says so instead of pretending nothing was checked.
    os.remove(statePath)
    local orphan = load('hook'); orphan.env.Update(); local orphanToken = orphan.delays()[1].token
    orphan.reset(); check(not orphan.env.Tick(orphanToken) and not orphan.requested(), 'No request without State.inc')
    local orphanView = load('settings'); orphanView.reset(); orphanView.env.Update()
    eq(orphanView.text('MeterUpdateStatus'), 'Update state file is missing. Reinstall Parallax.', 'Missing state reported')
    eq(orphanView.option('MeterUpdateStatus', 'FontColor'), '235,55,75', 'Missing state is an error')
    -- Hostile feed fields never reach the state file.
    resetState()
    local hostile = load('hook'); hostile.env.Update(); local hostileToken = hostile.delays()[1].token
    hostile.reset(); hostile.env.Tick(hostileToken)
    hostile.feedText = feed('99.0.0'):gsub('"url": "[^"]*"', '"url": "https://evil.example/x.rmskin"')
    hostile.reset(); hostile.env.FeedReady()
    eq(state().UpdateResult, 'format', 'foreign package refused'); eq(state().UpdateUrl, '', 'nothing saved from it')

    -- Settings view: shows the saved offer, checks as it opens, Check now, Install.
    resetState(); setPromptActive('0')
    local h2 = load('hook'); h2.env.Update(); local t2 = h2.delays()[1].token
    h2.env.Tick(t2); h2.feedText = feed('99.0.0'); h2.env.FeedReady()
    local view = load('settings')
    view.reset(); view.env.Update()
    eq(view.text('MeterUpdateLatestValue'), '99.0.0', 'Latest shown')
    eq(view.text('MeterUpdateStatus'), 'Parallax 99.0.0 is available. Checked ' .. os.date('%H:%M', view.now) .. '.', 'Available status')
    eq(view.option('MeterUpdateStatus', 'FontColor'), '175,175,175', 'Neutral status text')
    eq(view.shown('MeterUpdateInstall'), true, 'Update shown'); eq(view.shown('MeterUpdateNotes'), true, 'Notes shown')
    eq(view.text('MeterUpdateCheckNow'), 'Check now', 'Check now idle')
    local open = view.delays()
    check(#open == 1 and open[1].fn == 'OpenCheck' and open[1].ms == 500, 'Opening arms one open check')
    view.reset(); check(not view.env.OpenCheck(open[1].token) and not view.requested(), 'No open check within 10 minutes of the last')
    view.now = view.now + 601
    view.reset(); check(view.env.OpenCheck(open[1].token) and view.requested(), 'Open check after 10 minutes')
    eq(view.text('MeterUpdateStatus'), 'Checking github.com for a new release...', 'Checking shown')
    eq(view.text('MeterUpdateCheckNow'), 'Checking...', 'Button shows the request'); eq(view.shown('MeterUpdateInstall'), false, 'No Update while checking')
    view.reset(); check(not view.env.CheckNow() and not view.requested(), 'No second request while one runs')
    view.feedText = feed('99.0.0'); view.reset(); view.env.FeedReady()
    check(not view.find('!ActivateConfig'), 'A check from Settings never opens the prompt')
    view.reset(); check(view.env.CheckNow() and view.requested(), 'Check now always checks')
    view.reset(); view.env.FeedError('connect')
    eq(view.text('MeterUpdateStatus'), 'Could not reach github.com. Checked ' .. os.date('%H:%M', view.now) .. '.', 'Offline status')
    eq(view.option('MeterUpdateStatus', 'FontColor'), '235,55,75', 'Failure uses the danger color')
    eq(view.text('MeterUpdateLatestValue'), '99.0.0', 'Latest kept after a failure in the same minute')
    writeKey(statePath, 'Variables', 'UpdateLatestAt', tostring(view.now - 2 * 86400))
    view.reset(); view.env.Update()
    eq(view.text('MeterUpdateLatestValue'), '99.0.0 (' .. tonumber(os.date('%d', view.now - 2 * 86400)) .. os.date(' %b', view.now - 2 * 86400) .. ')', 'An older answer is dated')
    local autoOff = load('settings', { UpdateCheck = '0' })
    autoOff.env.Update(); local offToken = autoOff.delays()[1].token; autoOff.now = autoOff.now + 7200
    autoOff.reset(); check(not autoOff.env.OpenCheck(offToken) and not autoOff.requested(), 'Auto check Off never checks on open')
    -- Install from Settings: the same helper command as the Welcome panel had.
    view.reset(); check(view.env.Install(), 'Install starts')
    local parameter = view.option('MeasureParallaxUpdateInstall', 'Parameter')
    eq(parameter, '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' .. at .. 'Scripts\\UpdateInstall.ps1" -Url "'
        .. BASE .. 'download/v99.0.0/Parallax_99.0.0.rmskin" -Sha256 ' .. string.rep('ab', 32) .. ' -Version 99.0.0 -ReleaseBase "' .. BASE
        .. '" -ProgramPath "C:\\Program Files\\Rainmeter"', 'Helper command')
    check(view.find('!CommandMeasure', 'MeasureParallaxUpdateInstall', 'Run') ~= nil, 'Helper runs once')
    eq(view.text('MeterUpdateStatus'), 'Downloading 99.0.0...', 'Downloading shown')
    view.reset(); check(not view.env.Install() and not view.env.CheckNow() and #view.calls == 0, 'Nothing else while downloading')
    view.installOutput = 'PARALLAX_UPDATE_V1|ok|C:\\x.rmskin\r\n'
    view.reset(); check(view.env.InstallDone(), 'Hand-off reported')
    eq(view.text('MeterUpdateStatus'), 'Confirm in Skin Installer to finish.', 'Hand-off status')
    for output, expected in pairs({ ['PARALLAX_UPDATE_V1|error|404'] = 'Download failed. Nothing was installed.',
        ['PARALLAX_UPDATE_V1|blocked|media'] = 'A media helper is running. Quit Rainmeter.', [''] = 'Download failed. Nothing was installed.' }) do
        view.reset(); view.env.Install(); view.installOutput = output
        view.reset(); check(not view.env.InstallDone(), 'Failure reported for ' .. output)
        eq(view.text('MeterUpdateStatus'), expected, 'Install result ' .. output)
    end
    -- A tampered or not-newer saved offer is never installed.
    writeKey(statePath, 'Variables', 'UpdateUrl', 'https://evil.example/Parallax_99.0.0.rmskin')
    view.reset(); check(not view.env.Install() and not view.find('!CommandMeasure'), 'Tampered offer refused')
    view.reset(); view.env.Update(); eq(view.shown('MeterUpdateInstall'), false, 'No Update for a tampered offer')
    writeKey(statePath, 'Variables', 'UpdateUrl', BASE .. 'download/v99.0.0/Parallax_99.0.0.rmskin')
    writeKey(statePath, 'Variables', 'UpdateResult', 'available')
    local current = load('settings', { ParallaxVersion = '99.0.0' })
    current.reset(); current.env.Update()
    eq(current.text('MeterUpdateStatus'), 'Up to date. Checked ' .. os.date('%H:%M', view.now) .. '.', 'Installed equals latest')
    check(not current.env.Install(), 'Nothing to install when current')
    resetState()
    local fresh = load('settings'); fresh.env.Update()
    eq(fresh.text('MeterUpdateStatus'), 'Not checked yet.', 'Never checked'); eq(fresh.text('MeterUpdateLatestValue'), 'Unknown', 'Latest unknown')

    -- Prompt: placement, offer, Later, and closing when nothing is left.
    resetState(); setPromptActive('1')
    local h3 = load('hook'); h3.env.Update(); local t3 = h3.delays()[1].token
    h3.env.Tick(t3); h3.feedText = feed('99.0.0'); h3.env.FeedReady()
    local prompt = load('prompt')
    prompt.reset(); prompt.env.Update()
    eq(prompt.text('MeterHeadline'), '99.0.0 is available', 'Prompt headline')
    eq(prompt.text('MeterUpdateStatus'), 'Skin Installer asks you to confirm.', 'Prompt explains the confirmation')
    eq(prompt.option('MeterUpdateStatus', 'FontColor'), '175,175,175', 'Prompt status uses MutedColor')
    local move = prompt.find('!Move')
    check(move and move[2] == tostring(1920 - 228 - 16) and move[3] == '16', 'First appearance at the top right of the work area')
    check(not prompt.find('[!Delay 100][!DeactivateConfig]'), 'An offer keeps the prompt open')
    setPromptActive('1', '40')
    local placed = load('prompt'); placed.reset(); placed.env.Update()
    check(not placed.find('!Move'), 'A recorded position is kept')
    -- Rainmeter writes WindowX=0/WindowY=0 on a first activation: still unplaced.
    setPromptActive('1', '0')
    local unplaced = load('prompt'); unplaced.reset(); unplaced.env.Update()
    check(unplaced.find('!Move') ~= nil, 'The 0,0 that Rainmeter records first is placed')
    prompt.reset(); check(prompt.env.Install(), 'Update from the prompt'); eq(prompt.text('MeterUpdateInstall'), 'Working...', 'Prompt shows the download')
    prompt.reset(); prompt.env.Update()
    check(not prompt.find('[!Delay 100][!DeactivateConfig]'), 'Never closes during a download')
    prompt.installOutput = 'PARALLAX_UPDATE_V1|ok|x'; prompt.env.InstallDone()
    prompt.reset(); check(prompt.env.Later(), 'Later accepted')
    eq(state().UpdateDismissed, '99.0.0', 'Later dismisses this version'); check(prompt.find('!DeactivateConfig') ~= nil, 'Later closes')
    local dismissed = load('prompt'); dismissed.reset(); dismissed.env.Update()
    check(dismissed.find('[!Delay 100][!DeactivateConfig]') ~= nil, 'A dismissed version closes a reloaded prompt')
    resetState()
    local empty = load('prompt'); empty.reset(); empty.env.Update()
    check(empty.find('[!Delay 100][!DeactivateConfig]') ~= nil, 'Nothing to offer closes the prompt')
    check(not load('hook').env.Later() and not load('settings').env.Later(), 'Only the prompt has Later')
    return passed
end

return suite
