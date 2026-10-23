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

local function fail()
    state, cached = 'failed', nil
    stopProcesses()
    cleanup()
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
-- collide, and writes the first heartbeat. It starts the host hidden, outside
-- the skin folder, with the source's absolute path on its command line, and
-- waits up to 10 s until the host has written its first frame (by then it
-- holds its Rainmeter ancestor handle) or has exited. It then renews the
-- lease and prints the session, or removes the lease and reports failure, and
-- exits, ending RunCommand's polling thread for this command. Only fixed text
-- and a validated integer enter it; the host validates the token and derives
-- every path itself, and this controller validates the returned path.
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
        .. '$h=' .. literal(hostScript) .. ".Replace('@T@',$k).Replace('@S@',$s.Replace($q,$q+$q)); "
        .. "$p=Start-Process -FilePath ([IO.Path]::Combine($PSHOME,'powershell.exe')) "
        .. "-ArgumentList ('-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -Command '+[char]34+$h+[char]34) "
        .. '-WorkingDirectory $t -WindowStyle Hidden -PassThru; '
        .. "$d=$b+'.dat'; $w=[Diagnostics.Stopwatch]::StartNew(); "
        .. 'while (-not $p.HasExited -and -not [IO.File]::Exists($d) -and $w.ElapsedMilliseconds -lt 10000) { Start-Sleep -Milliseconds 100 }; '
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
            local roots = {}
            for _, key in ipairs({'TMP', 'TEMP'}) do
                local root = os.getenv(key)
                if root then roots[#roots + 1] = root end
            end
            session = model.ParseSession(output(launcher), roots)
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
    end
    if state ~= 'stopped' then Display(false) end
    return 0
end

-- Close only: removing the lease stops the detached host. RunCommand's own
-- unload terminates any setup command still running; a Kill sent here first
-- made that a second termination of the same process (logged Error 105).
-- Pending retries end with it.
function Stop()
    state, launched, retryAt = 'stopped', {}, nil
    cleanup()
end
