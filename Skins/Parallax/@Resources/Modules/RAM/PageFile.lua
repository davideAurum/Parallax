-- Original paging-file reader bridge. One bounded setup-time launch starts
-- one resident Windows API host, detached from RunCommand; display/settings
-- updates never launch a poller.
local model, state, interval, deadline, session, cached, previous, measures
local lastSequence, lastEpoch, lastLease, lastWire, launched
-- aliveUntil: the detached host counts as running while its newest accepted
-- sample is recent enough (see readFrame).
local aliveUntil
-- Recovery. A failed session (a launch that fails, a lease that cannot be
-- renewed, or a host that stops publishing, for example after its lease
-- lapsed while Rainmeter was suspended or its main thread was blocked) is
-- retried after 10 s, 60 s and 300 s, then left Unavailable until refresh.
-- A session that has delivered samples for 10 minutes resets the count, so a
-- later incident is retried again, while a host that keeps dying cannot cause
-- a launch loop. failures: consecutive failed sessions; retryAt: when the
-- next attempt starts; healthySince: first accepted sample of this session.
local retryDelays, healthyAfter = {10, 60, 300}, 600
local failures, retryAt, healthySince
local launcher = 'MeasureRAMPageLauncher'
local targets = {'MeterRAMPageGiB', 'MeterRAMPageMiB', 'MeterRAMPageBar'}
-- owner: this skin's owner-file key (see stopRecorded).
local owner
-- One check of a launch that an idle stand-down let run, a second from now
-- (see Drain). The launcher measure is never paused; this one is.
local drainCheck = '[!Delay 1000][!CommandMeasure MeasureRAMPageView "Drain()"]'

local function measure(name)
    if not measures[name] then measures[name] = SKIN:GetMeasure(name) end
    return measures[name]
end
local function status(name) local item = measure(name); return item and item:GetValue() or 103 end
local function output(name) local item = measure(name); return item and tostring(item:GetStringValue() or '') or '' end
local function set(name, option, value)
    local key = name .. ':' .. option
    if previous[key] == value then return false end
    previous[key] = value
    SKIN:Bang('!SetOption', name, option, value)
    return true
end

function Display(immediate)
    local frame = cached
    if frame and frame.epoch and not model.Fresh(frame.epoch, os.time(), interval) then frame = nil end
    local dirty = {}
    local useMB = tonumber(SKIN:GetVariable('RAMUseMiB')) == 1
    local decimals = tonumber(SKIN:GetVariable('RAMDecimals')) or 1
    local ratio = frame and frame.status == 'OK' and frame.total > 0 and frame.used / frame.total or nil
    if set('MeasureRAMPageRatio', 'Formula', string.format('%.15f', ratio or 0)) then
        SKIN:Bang('!UpdateMeasure', 'MeasureRAMPageRatio')
        dirty.MeterRAMPageBar = true
    end
    local showBar = tonumber(SKIN:GetVariable('RAMShowPageBar')) == 1 and ratio ~= nil
    if set('MeterRAMPageBar', 'Hidden', showBar and '0' or '1') then dirty.MeterRAMPageBar = true end
    for _, entry in ipairs({{'MeterRAMPageGiB', false}, {'MeterRAMPageMiB', true}}) do
        local text = set(entry[1], 'Text', model.Format(frame, entry[2], decimals).text)
        local hidden = set(entry[1], 'Hidden', entry[2] == useMB and '0' or '1')
        if text or hidden then dirty[entry[1]] = true end
    end
    -- The PAGE meters use UpdateDivider=-1, so a changed option appears only
    -- after a forced update. Periodic calls (immediate == false) still force
    -- the changed meters and leave the redraw to the skin's own update cycle;
    -- out-of-cycle calls from Start, failure and Settings redraw themselves.
    local changed = false
    for _, name in ipairs(targets) do
        if dirty[name] then
            SKIN:Bang('!UpdateMeter', name)
            changed = true
        end
    end
    if changed and immediate ~= false then SKIN:Bang('!Redraw') end
end

-- Removing the lease is also the detached host's stop request: it exits at
-- its next check, within one sampling interval (at most five seconds).
local function cleanup()
    if session then
        os.remove(session.lease)
        os.remove(session.path)
        os.remove(session.tmp)
        session = nil
    end
end

local function tempRoots()
    local roots = {}
    for _, key in ipairs({'TMP', 'TEMP'}) do
        local root = os.getenv(key)
        if root then roots[#roots + 1] = root end
    end
    return roots
end

-- A refresh runs no OnCloseAction, so the previous load never reaches
-- Stop(), and RunCommand's unload ends a launcher before it reports. Either
-- way that load's host would run on, beside the new load's, until its lease
-- lapsed (60 s). So every launch writes its session token to an owner file
-- in TEMP before it starts the host, and a new load (Initialize) or a close
-- (Stop) removes the session that file names: the host exits within one
-- sampling interval. The file is keyed to this Rainmeter instance and skin
-- (settings folder, config and resource path), so no other instance's host
-- is touched. Only a 32-digit hex token is accepted; the paths derive from it.
local function ownerKey()
    local identity = ((SKIN:GetVariable('SETTINGSPATH') or '') .. '|' .. (SKIN:GetVariable('CURRENTCONFIG') or '')
        .. '|' .. (SKIN:GetVariable('@') or '')):lower()
    local a, b = 5381, 0
    for index = 1, #identity do
        local byte = identity:byte(index)
        a = (a * 33 + byte) % 4294967296
        b = (b * 65599 + byte) % 4294967296
    end
    -- %x takes 32-bit signed integers in Lua 5.1 on Windows: format halves.
    return string.format('%04x%04x%04x%04x', math.floor(a / 65536), a % 65536, math.floor(b / 65536), b % 65536)
end

local function stopRecorded()
    for _, root in ipairs(tempRoots()) do
        root = root:gsub('[\\/]+$', '')
        local record = root .. '\\Parallax-RAM-Owner-' .. owner .. '.txt'
        local file = io.open(record, 'rb')
        if file then
            local token = file:read(33)
            file:close()
            if token and #token == 32 and not token:find('[^0-9a-f]') then
                local base = root .. '\\Parallax-RAM-Page-' .. token
                os.remove(base .. '.lease')
                os.remove(base .. '.dat')
                os.remove(base .. '.tmp')
            end
            os.remove(record)
        end
    end
end

local function stopProcesses()
    for _, name in ipairs({launcher}) do
        if launched[name] then
            -- RunCommand runs at 0 and starts at -1; the skin may also expose
            -- an unlaunched cached 0. Track launches and refresh before deciding.
            SKIN:Bang('!UpdateMeasure', name)
            local current = status(name)
            launched[name] = nil
            if current == 0 then SKIN:Bang('!CommandMeasure', name, 'Kill') end
        end
    end
end

-- A launch that ends without reporting a session (RunCommand's Timeout ended
-- a slow launcher with empty output, or the deadline Kill) may already have
-- started a host on the session it recorded, so the owner file stops that
-- host too. Otherwise the record names the session ending here, or one that
-- already ended.
local function fail()
    state, cached = 'failed', nil
    stopProcesses()
    cleanup()
    stopRecorded()
    local now = os.time()
    if healthySince and now - healthySince >= healthyAfter then failures = 0 end
    healthySince, failures = nil, failures + 1
    retryAt = retryDelays[failures] and now + retryDelays[failures] or nil
    Display()
end

local function launch(name, parameter)
    SKIN:Bang('!SetOption', name, 'Parameter', parameter)
    SKIN:Bang('!UpdateMeasure', name)
    launched[name] = true
    SKIN:Bang('!CommandMeasure', name, 'Run')
end

-- A PowerShell single-quoted literal.
local function literal(text) return "'" .. (text:gsub("'", "''")) .. "'" end

-- The only launch: plain PowerShell (no compile). It mints a random session
-- with [guid]::NewGuid(), creating its lease exclusively so names never
-- collide, and writes the first heartbeat, then the token to this skin's
-- owner file (see stopRecorded); a failed write ends the launch before any
-- host exists. It starts the host hidden, outside
-- the skin folder, with the source's absolute path on its command line, and
-- waits up to 10 s until the host has written its first frame (by then it
-- holds its Rainmeter ancestor handle) or has exited, but never past 13 s
-- after its own start: RunCommand's Timeout=15000 ends a launcher at 15 s,
-- before it reports, so a slow PowerShell start still reports its session
-- (the startup guard then waits for the first frame). It then renews the
-- lease and prints the session, or removes the lease and reports failure, and
-- exits, ending RunCommand's polling thread for this command. Only fixed text,
-- the hex owner key and a validated integer enter it; the host validates the
-- token and derives every path itself, and this controller validates the
-- returned path.
local function launcherParameter()
    local hostScript = "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; try { "
        .. "Add-Type -TypeDefinition ([IO.File]::ReadAllText('@S@')); "
        .. "[ParallaxRamPageFile]::Run('@T@'," .. interval .. ') } catch { exit 1 }'
    return '-NoLogo -NoProfile -NonInteractive -Command "'
        .. "$ErrorActionPreference='Stop'; $l=$null; try { $q=[string][char]39; "
        .. "$s=[IO.Path]::Combine([IO.Directory]::GetCurrentDirectory(),'PageFileHost.cs.txt'); "
        .. '$t=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $k=$null; '
        .. 'for ($i=0; $i -lt 3 -and -not $k; $i++) { '
        .. "$g=[guid]::NewGuid().ToString('N'); $b=[IO.Path]::Combine($t,'Parallax-RAM-Page-'+$g); "
        .. "if ([IO.File]::Exists($b+'.dat') -or [IO.File]::Exists($b+'.tmp')) { continue }; "
        .. "try { $f=[IO.File]::Open($b+'.lease','CreateNew','Write','Read') } catch [IO.IOException] { continue }; "
        .. "$l=$b+'.lease'; try { $e=[Text.Encoding]::ASCII.GetBytes($g+'|'+[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); $f.Write($e,0,$e.Length) } finally { $f.Dispose() }; "
        .. '$k=$g }; '
        .. "if (-not $k) { throw 'session' }; "
        .. "[IO.File]::WriteAllText([IO.Path]::Combine($t,'Parallax-RAM-Owner-" .. owner .. ".txt'),$k,[Text.Encoding]::ASCII); "
        .. '$h=' .. literal(hostScript) .. ".Replace('@T@',$k).Replace('@S@',$s.Replace($q,$q+$q)); "
        .. "$p=Start-Process -FilePath ([IO.Path]::Combine($PSHOME,'powershell.exe')) "
        .. "-ArgumentList ('-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -Command '+[char]34+$h+[char]34) "
        .. '-WorkingDirectory $t -WindowStyle Hidden -PassThru; '
        .. "$d=$b+'.dat'; $w=[Diagnostics.Stopwatch]::StartNew(); $z=[Diagnostics.Process]::GetCurrentProcess().StartTime.AddSeconds(13); "
        .. 'while (-not $p.HasExited -and -not [IO.File]::Exists($d) -and $w.ElapsedMilliseconds -lt 10000 -and [DateTime]::Now -lt $z) { Start-Sleep -Milliseconds 100 }; '
        .. "if ($p.HasExited) { throw 'host' }; "
        .. "[IO.File]::WriteAllText($l,$k+'|'+[DateTimeOffset]::UtcNow.ToUnixTimeSeconds(),[Text.Encoding]::ASCII); "
        .. "[Console]::Write('RAM_PAGE_SESSION|1|'+$k+'|'+[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($d)).Replace('-','')) "
        .. "} catch { if ($l) { try { [IO.File]::Delete($l) } catch {} }; [Console]::Write('RAM_PAGE_FAILED') }\""
end

local function heartbeat(now)
    if now >= lastLease and now - lastLease < 5 then return true end
    local file = io.open(session.lease, 'wb')
    if not file then return false end
    local written = file:write(session.token .. '|' .. tostring(now))
    local closed = file:close()
    if not written or not closed then return false end
    lastLease = now
    return true
end

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\PageFileModel.lua')
    state, session, cached, previous, measures = 'idle', nil, {status = 'STARTING'}, {}, {}
    lastSequence, lastEpoch, lastLease, lastWire = -1, 0, -1, nil
    launched, aliveUntil = {}, 0
    failures, retryAt, healthySince = 0, nil, nil
    interval = tonumber(SKIN:GetVariable('MetricsInterval')) or 1000
    if interval ~= interval or interval == math.huge or interval == -math.huge then interval = 1000 end
    interval = math.max(1000, math.min(30000, math.floor(interval)))
    -- The previous load of this skin (a refresh) may have left a host.
    owner = ownerKey()
    stopRecorded()
end

-- Starts one session: a fresh launch with nothing carried over.
local function begin(now)
    session, cached = nil, {status = 'STARTING'}
    lastSequence, lastEpoch, lastLease, lastWire = -1, 0, -1, nil
    aliveUntil, healthySince = 0, nil
    state, deadline = 'launching', now + 20
    launch(launcher, launcherParameter())
end

function Start()
    if state ~= 'idle' then return end
    begin(os.time())
    Display()
end

local function readFrame(now)
    local file = io.open(session.path, 'rb')
    if not file then
        cached = now < deadline and {status = 'STARTING'} or nil
        return
    end
    local wire = file:read(513)
    file:close()
    local frame = model.Parse(wire, session.token, now, interval, lastSequence, lastEpoch)
    if not frame or (frame.sequence == lastSequence and lastWire and wire ~= lastWire) then
        cached = nil
        return
    end
    cached, lastSequence, lastEpoch, lastWire = frame, frame.sequence, frame.epoch, wire
    healthySince = healthySince or now
    -- A late host is shown Unavailable after the freshness window but may
    -- still resume; with no sample for twice that window (at least 30 s) it
    -- counts as stopped. Accepted epochs never regress, so this only moves
    -- forward. The first sample replaces the 20-second startup guard.
    aliveUntil = frame.epoch + math.max(30, 2 * model.Window(interval))
end

function Update()
    local now = os.time()
    if state == 'launching' then
        -- The launcher reports once, with the session of a started host.
        local current = status(launcher)
        if current == 1 then
            launched[launcher] = nil
            session = model.ParseSession(output(launcher), tempRoots())
            if not session then fail(); return 0 end
            if not heartbeat(now) then fail(); return 0 end
            state, deadline = 'running', now + 20
            aliveUntil = deadline
        elseif current >= 100 or now >= deadline then
            fail(); return 0
        end
    elseif state == 'running' then
        -- The host's own samples are the only evidence it is running; a host
        -- silent past the grace in readFrame ends the session, as a host exit
        -- did before.
        if not heartbeat(now) then fail(); return 0 end
        readFrame(now)
        if now > aliveUntil then fail(); return 0 end
    elseif state == 'failed' and retryAt and now >= retryAt then
        retryAt = nil
        begin(now)
    elseif state == 'resume' then
        begin(now)
    end
    if state ~= 'stopped' and state ~= 'standby' and state ~= 'draining' then Display(false) end
    return 0
end

-- Idle stand-down (Global Settings Idle pause; @Resources\Idle\StandDown.lua
-- calls IdleEnter before pausing this measure and IdleLeave after unpausing
-- it). StandDown ends the session without counting a failure: removing the
-- lease stops a running host within one sampling interval. Not Stop(), which
-- is terminal for this load. A failed state keeps its retry schedule (or
-- stays Unavailable after the last retry), so a host that keeps failing is
-- not relaunched per pause.
-- A launch still in progress is not killed. A Kill sent before RunCommand's
-- thread has created the process is refused (Error 102) and the launch
-- carries on; one sent after the launcher's Start-Process ends only the
-- launcher, and the detached host it started runs on the launcher's lease
-- until that lapses. Either way nobody here knows the session to stop. So
-- the launch is let run (it reports within about 10 s; RunCommand's Timeout
-- bounds it) and drained: Drain stops whatever host it reports.
function StandDown()
    if state ~= 'launching' and state ~= 'running' then return false end
    cached, retryAt = nil, nil
    if state == 'launching' then
        state = 'draining'
        SKIN:Bang(drainCheck)
        return true
    end
    cleanup()
    state = 'standby'
    return true
end

-- A launch a stand-down let run, checked once a second while this measure is
-- paused (the delayed !CommandMeasure still reaches it, and the launcher
-- measure keeps updating). When it reports a session, removing that lease
-- stops the host at its next check, within one sampling interval; a launch
-- that ended without reporting one (RunCommand's Timeout) is stopped through
-- the owner file, as in fail(), and a failed launch left nothing running. One
-- still running at its deadline is killed, as fail() does (it has long
-- existed by then). Each check arms at most the
-- next, so the checks end with the drain or at the deadline. A check that
-- reaches another state, or a later load (a delayed bang survives a
-- refresh), does nothing. No process is started here.
function Drain()
    if state ~= 'draining' then return end
    SKIN:Bang('!UpdateMeasure', launcher)
    local current = status(launcher)
    if current == 1 then
        launched[launcher] = nil
        session = model.ParseSession(output(launcher), tempRoots())
        cleanup()
        stopRecorded()
        state = 'standby'
    elseif current >= 100 or os.time() >= deadline then
        stopProcesses()
        stopRecorded()
        state = 'standby'
    else
        SKIN:Bang(drainCheck)
    end
end

-- Arms a fresh session for the next update (the stand-down's forced resume
-- update): PAGE shows Starting until the new host's first sample. A launch
-- still draining before its deadline becomes this session's start again, so
-- a quick resume starts no second host.
function StandUp()
    if state == 'draining' and os.time() < deadline then
        state, cached = 'launching', {status = 'STARTING'}
        return true
    end
    if state == 'draining' then Drain() end
    if state ~= 'standby' then return false end
    state, cached = 'resume', {status = 'STARTING'}
    return true
end

function IdleEnter() StandDown() end
function IdleLeave() StandUp() end

-- Close only: removing the lease stops the detached host. RunCommand's own
-- unload terminates any setup command still running; a Kill sent here first
-- made that a second termination of the same process (logged Error 105).
-- A launch that has not reported has already recorded its session if it
-- started a host, so the owner file stops that host too. Pending retries end
-- with it.
function Stop()
    state, launched, retryAt = 'stopped', {}, nil
    cleanup()
    stopRecorded()
end
