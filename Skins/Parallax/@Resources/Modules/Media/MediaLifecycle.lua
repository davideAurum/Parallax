-- One bootstrap per skin load for previously enabled providers. Readers remain
-- passive; no timer, authentication, playback action or default opt-in is added.
local attempted = false

local function safePath(value)
    return type(value) == 'string' and #value <= 2048
        and value:match('^%a:[/\\]') ~= nil
        and not value:find('[%z\001-\031\127"%[%]#%%<>|?*]')
        and not value:sub(3):find(':', 1, true)
end

local function enabled(root)
    local ok, file = pcall(io.open, root .. '\\enabled.intent', 'rb')
    if not ok or not file then return false end
    local readOK, content = pcall(file.read, file, 32)
    pcall(file.close, file)
    if not readOK or content ~= 'PARALLAX_AUTOSTART_V1|1\n' then return false end
    local stopOK, stop, _, code = pcall(io.open, root .. '\\stop.request', 'rb')
    if stop then pcall(stop.close, stop) end
    -- Only a missing stop file permits a launch. The provider checks again
    -- under its control mutex, including file type, ACL and path validation.
    return stopOK and not stop and code == 2
end

-- A whole number of seconds as written by MediaOptions.ApplyLease, or nil.
local function stamp(name)
    local text = SKIN:GetVariable(name, '0')
    if type(text) ~= 'string' or #text > 12 or not text:match('^%d+$') then return nil end
    return tonumber(text)
end

-- True only for a Media.ini load that MediaOptions.ApplyLease caused itself
-- (parking or resuming the spectrum drawer's capture) in this same Rainmeter
-- process, at most 15 s ago (docs/PERFORMANCE-REVIEW.md MEDIA-08). Its
-- providers were resumed by an earlier load of this process and keep running,
-- so the lease's own reloads start no PowerShell. os.clock() is wall time
-- since this Rainmeter process started (the C runtime's clock(); checked
-- natively by Test-MediaLifecycle.ps1), so after a restart the clock and
-- wall-time deltas disagree and the normal resume runs. After about 24.8 days
-- of process uptime clock() returns -1, the stamp ("-1") is rejected and the
-- normal resume runs. Setup.ini and Queue.ini, and every reload a user or
-- another skin asks for, resume exactly as before.
local function leaseRefresh(config)
    if config ~= 'Media.ini' then return false end
    local at, clock = stamp('MediaLeaseRefreshAt'), stamp('MediaLeaseRefreshClock')
    if not at or not clock or at == 0 then return false end
    local elapsed = os.time() - at
    if elapsed < 0 or elapsed > 15 then return false end
    return math.abs((os.clock() - clock) - elapsed) <= 2
end

function Initialize() attempted = false end
function Update() return 0 end

function ResumeProviders()
    if attempted then return end
    attempted = true
    local config = SKIN:GetVariable('CURRENTFILE', '')
    if config ~= 'Media.ini' and config ~= 'Setup.ini' and config ~= 'Queue.ini' then return end
    if leaseRefresh(config) then return end
    -- Isolated previews use a separate Rainmeter profile. They must never
    -- restore collectors against the user's ordinary private runtime data.
    local roaming, settings = os.getenv('APPDATA'), SKIN:GetVariable('SETTINGSPATH', '')
    if not safePath(roaming) or not safePath(settings) then return end
    local function normalized(path) return path:gsub('/', '\\'):gsub('\\+$', ''):lower() end
    if normalized(settings) ~= normalized(roaming .. '\\Rainmeter') then return end
    local localRoot, systemRoot, resources = os.getenv('LOCALAPPDATA'), os.getenv('SystemRoot'), SKIN:GetVariable('@', '')
    if not safePath(localRoot) or not safePath(systemRoot) or not safePath(resources) then return end
    localRoot = localRoot:gsub('[/\\]+$', '') .. '\\Parallax\\Media\\'
    local program = systemRoot:gsub('[/\\]+$', '') .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
    resources = resources:gsub('[/\\]+$', '') .. '\\Modules\\Media\\'
    local function resume(folder, host, provider, interval)
        if not enabled(localRoot .. folder) then return end
        local parameter = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
            .. resources .. provider .. '" -Command "Resume" -Quiet'
        if interval then parameter = parameter .. ' -PollSeconds "' .. interval .. '"' end
        -- Hand the validated command to the inert RunCommand host declared in
        -- Lifecycle.inc instead of banging it. RunCommand creates the process
        -- with SW_HIDE; Rainmeter's own [] bang ShellExecutes it visibly, which
        -- is what flashed a console before powershell.exe could hide itself.
        -- safePath already rejects " # % [ ] < > | ? * and control characters,
        -- so neither option can close a quote or smuggle a #variable# or
        -- [measure] reference past the host's DynamicVariables expansion.
        SKIN:Bang('!SetOption', host, 'Program', program)
        SKIN:Bang('!SetOption', host, 'Parameter', parameter)
        SKIN:Bang('!UpdateMeasure', host)
        SKIN:Bang('!CommandMeasure', host, 'Run')
    end
    if config == 'Media.ini' then resume('Source', 'MeasureMediaSourceResume', 'Source\\SourceProvider.ps1') end
    local raw = SKIN:GetVariable('QueuePollSeconds', '30')
    local interval = type(raw) == 'string' and raw:match('^%d+$') and tonumber(raw) or nil
    if not interval or interval < 30 or interval > 150 then interval = 30 end
    resume('Spotify', 'MeasureMediaQueueResume', 'Queue\\QueueProvider.ps1', string.format('%d', interval))
end
