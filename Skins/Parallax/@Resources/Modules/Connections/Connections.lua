-- Parallax Connections: what the suite connects to, in one place. Reads only: the
-- fixed header fields of the Media helpers' status files, whether their sign-in
-- files exist (never what is in them), and HWiNFO's native measures. No network,
-- token, title or process; every text shown is one of the fixed strings below.
-- The Spotify Sign in and Disconnect clicks are the queue helper's own commands.

local HOST = 'MeasureConnectionsDisconnect'
local HEADER_BYTES = 1024
-- A helper may finish a write just after the second this script reads.
local CLOCK_SLACK = 5
-- The helper waits three minutes for the browser; after this long a status left
-- at "connecting" belongs to a console that was closed.
local CONNECT_SECONDS = 200
local CONFIRM_SECONDS = 8
local DEFAULT_STATUS = 'Only Sign in and Disconnect change anything here.'
local QUEUE_FORMATS = { PARALLAX_QUEUE_V2 = true, PARALLAX_QUEUE_V3 = true, PARALLAX_QUEUE_V4 = true, PARALLAX_QUEUE_V5 = true }
local QUEUE_STATES = { ready = true, stopped = true, connecting = true, onboarding_required = true,
    reauth_required = true, forbidden = true, rate_limited = true, quota_exceeded = true,
    offline = true, service_unavailable = true, error = true }
local LIST_FORMATS = { PARALLAX_PLAYLISTS_V1 = true }
local LIST_STATES = { ready = true, scope_required = true, error = true }
local SOURCE_FORMATS = { PARALLAX_SOURCE_V1 = true }
local SOURCE_STATES = { ready = true, stopped = true, unavailable = true }
local TONES = { good = 'GoodColor', warn = 'WarningColor', muted = 'MutedColor' }
-- What a signed-in account shows while the queue is not being read.
local WAITING = {
    stopped = { 'Signed in', 'muted', 'Queue helper is off. Start it in Media settings.' },
    reauth_required = { 'Sign in again', 'warn', 'Spotify needs a new sign-in.' },
    onboarding_required = { 'Sign in again', 'warn', 'Spotify needs a new sign-in.' },
    forbidden = { 'Access denied', 'warn', 'Spotify refused this account or app. See Help.' },
    rate_limited = { 'Signed in', 'muted', 'Spotify asked to wait. The queue resumes by itself.' },
    quota_exceeded = { 'Signed in', 'warn', 'The Spotify app has used its quota. See Help.' },
    offline = { 'Signed in', 'muted', 'Offline. The queue helper tries again.' },
    service_unavailable = { 'Signed in', 'muted', 'Spotify is unavailable. The helper tries again.' },
    error = { 'Signed in', 'warn', 'Queue unavailable. Try Restart in Media settings.' }
}

local root, resources, pluginFound
local applied, shown
local signedIn, connectingSince, confirmUntil, launched, status

local function safeRoot(value)
    if type(value) ~= 'string' or #value > 2048 or not value:match('^%a:[/\\]') then return nil end
    if value:find('[%z\001-\031"<>|?*]') then return nil end
    return (value:gsub('[/\\]+$', ''))
end

-- True unless Windows says there is no such file. A file that exists but cannot
-- be opened this moment (the helper is replacing it) still counts.
local function present(path)
    local ok, file, message, code = pcall(io.open, path, 'rb')
    if not ok then return false end
    if file then pcall(file.close, file); return true end
    return not (code == 2 or code == 3 or (type(message) == 'string' and message:lower():find('no such file', 1, true)))
end

local function readStart(path, bytes)
    local ok, file = pcall(io.open, path, 'rb')
    if not ok or not file then return nil end
    local good, data = pcall(file.read, file, bytes)
    pcall(file.close, file)
    return good and type(data) == 'string' and data or nil
end

local function integer(text)
    if type(text) ~= 'string' or #text > 15 or not (text == '0' or text:match('^[1-9]%d*$')) then return nil end
    return tonumber(text)
end

-- The header fields of a helper's status file: nil when there is no usable file,
-- with 'missing' when there is none at all. Encoded titles that follow are never
-- decoded or used.
local function header(path, formats, states)
    if not present(path) then return nil, 'missing' end
    local data = readStart(path, HEADER_BYTES)
    if not data then return nil, 'unreadable' end
    data = data:gsub('\r\n', '\n')
    local format = data:match('^([^\n]+)\n')
    if not format or not formats[format] then return nil, 'unreadable' end
    local fields = {}
    for line in data:sub(#format + 2):gmatch('([^\n]*)\n') do
        local key, value = line:match('^([a-z_]+)=([a-z0-9_]*)$')
        if not key then break end
        if fields[key] ~= nil then return nil, 'unreadable' end
        fields[key] = value
    end
    if not states[fields.state or ''] then return nil, 'unreadable' end
    return fields
end

local function live(fields, now)
    local observed, expiry = integer(fields.observed), integer(fields.valid_until)
    return fields.state == 'ready' and observed ~= nil and expiry ~= nil and observed > 0
        and observed <= now + CLOCK_SLACK and now < expiry
end

-- The Spotify account: state, tone, detail, and whether a sign-in is saved.
local function account(now)
    if not root then return { 'Unknown', 'muted', 'The local app data folder was not found.' }, false end
    local folder = root .. 'Spotify\\'
    local saved = present(folder .. 'tokens.dpapi')
    local queue, reason = header(folder .. 'queue.snapshot', QUEUE_FORMATS, QUEUE_STATES)
    local state = queue and queue.state or (reason == 'missing' and 'stopped' or 'error')
    if state == 'connecting' then
        connectingSince = connectingSince or now
        if now - connectingSince < CONNECT_SECONDS then
            return { 'Signing in', 'warn', 'Finish in the console and the browser.' }, saved
        end
        return { saved and 'Sign in again' or 'Not signed in', 'warn', 'The last sign-in did not finish.' }, saved
    end
    connectingSince = nil
    if not saved then
        if state == 'reauth_required' then return { 'Not signed in', 'muted', 'The last sign-in did not finish.' }, false end
        if present(folder .. 'client.json') then
            return { 'Not signed in', 'muted', 'Sign in opens a console and your browser.' }, false
        end
        return { 'Not set up', 'muted', 'Experimental. Needs Premium and your own app ID. See Help.' }, false
    end
    if state ~= 'ready' then return WAITING[state], true end
    if not live(queue, now) then
        return { 'Signed in', 'muted', 'Queue helper is not running. See Media settings.' }, true
    end
    -- V2 predates the field, so nothing is known about playback control there.
    local list = header(folder .. 'playlists.snapshot', LIST_FORMATS, LIST_STATES)
    local control, playlists = queue.control, list and list.state
    if control == '0' and playlists == 'scope_required' then
        return { 'Sign in again', 'warn', 'To allow playback control and playlists.' }, true
    elseif control == '0' then
        return { 'Sign in again', 'warn', 'To allow playback control.' }, true
    elseif playlists == 'scope_required' then
        return { 'Sign in again', 'warn', 'To allow playlists.' }, true
    end
    local can = control == '1' and 'Queue and playback control' or 'Queue'
    if playlists == 'ready' then
        can = control == '1' and 'Queue, playback control and playlists.' or 'Queue and playlists.'
    elseif playlists == 'error' then
        can = can .. '. Playlists unavailable.'
    else
        -- The helper reads the list only when the Playlists view is opened.
        can = can .. '. Playlists not checked yet.'
    end
    return { 'Signed in', 'good', can }, true
end

local function source(now)
    if not root then return { 'Unknown', 'muted' } end
    local folder = root .. 'Source\\'
    local fields, reason = header(folder .. 'source.snapshot', SOURCE_FORMATS, SOURCE_STATES)
    if not fields then return reason == 'missing' and { 'Off', 'muted' } or { 'Unavailable', 'warn' } end
    if live(fields, now) then return { 'On', 'good' } end
    if fields.state == 'unavailable' then return { 'Unavailable', 'warn' } end
    if fields.state == 'ready' and readStart(folder .. 'enabled.intent', 32) == 'PARALLAX_AUTOSTART_V1|1\n' then
        return { 'Not running', 'warn' }
    end
    return { 'Off', 'muted' }
end

local function plugin()
    return pluginFound and { 'Plugin installed', 'good' } or { 'Plugin missing', 'warn' }
end

local function hwinfo()
    local running = SKIN:GetMeasure('MeasureHWiNFORunning')
    if not running or running:GetValue() ~= 1 then return { 'Not running', 'muted' } end
    for _, name in ipairs({ 'MeasureHWiNFOUser', 'MeasureHWiNFOMachine' }) do
        local measure = SKIN:GetMeasure(name)
        -- An empty value list reads as 0, so only a real export name counts.
        if measure and tostring(measure:GetStringValue()):find('Sensor%d') then return { 'Running', 'good' } end
    end
    -- HWiNFO exports only while its Sensors window is open (minimised is fine).
    return { 'Open Sensors', 'warn' }
end

local function updates()
    local value = SKIN:GetVariable('UpdateCheck', '1')
    if value == '1' then return { 'Daily, GitHub', 'good' } end
    if value ~= '0' then return { 'Custom', 'muted' } end
    -- The developer copy is made with its own check off; the release beside it
    -- keeps its own setting, so name whose this is.
    local copy = SKIN:GetVariable('ParallaxDevBuild', '0') == '1'
    return { copy and 'Off in this copy' or 'Off', 'muted' }
end

local function put(meter, key, value)
    local slot = meter .. '/' .. key
    if applied[slot] == value then return end
    applied[slot], shown = value, true
    SKIN:Bang('!SetOption', meter, key, value)
end

local function row(prefix, entry)
    put('Meter' .. prefix .. 'State', 'Text', entry[1])
    put('Meter' .. prefix .. 'State', 'FontColor', '#' .. TONES[entry[2]] .. '#')
end

function Render()
    local now = os.time()
    if confirmUntil and now >= confirmUntil then confirmUntil, status = nil, DEFAULT_STATUS end
    local spotify
    spotify, signedIn = account(now)
    if not signedIn and confirmUntil then confirmUntil, status = nil, DEFAULT_STATUS end
    row('Spotify', spotify)
    put('MeterSpotifyDetail', 'Text', spotify[3])
    put('MeterSignIn', 'Text', signedIn and 'Sign in again' or 'Sign in')
    put('MeterDisconnect', 'Text', confirmUntil and 'Disconnect?' or 'Disconnect')
    put('MeterDisconnect', 'FontColor', confirmUntil and '#WarningColor#' or '#AccentColor2#')
    if applied.disconnect ~= signedIn then
        applied.disconnect, shown = signedIn, true
        SKIN:Bang(signedIn and '!ShowMeter' or '!HideMeter', 'MeterDisconnect')
    end
    row('Source', source(now))
    row('Plugin', plugin())
    row('HWiNFO', hwinfo())
    row('Update', updates())
    put('MeterStatus', 'Text', status)
    if shown then
        shown = false
        SKIN:Bang('!UpdateMeterGroup', 'ConnectionsData')
        SKIN:Bang('!Redraw')
    end
end

-- The interval Sign in hands to the helper is Media's saved one, or the default.
local function pollSeconds()
    local data = readStart(resources .. 'User\\Media.inc', 65536)
    data = data and data:gsub('%z', '') or ''
    local value
    for line in data:gmatch('[^\r\n]+') do
        local found = line:match('^%s*[Qq]ueue[Pp]oll[Ss]econds%s*=%s*(%d+)%s*$')
        if found then value = found end
    end
    local number = value and #value <= 3 and tonumber(value) or nil
    return number and number >= 30 and number <= 150 and tostring(number) or '30'
end

local function findPlugin()
    for _, name in ipairs({ 'SETTINGSPATH', 'PROGRAMPATH' }) do
        local path = SKIN:GetVariable(name, '')
        if path ~= '' and present(path .. 'Plugins\\WebNowPlaying.dll') then return true end
    end
    return false
end

function ReadInterval()
    SKIN:Bang('!SetVariable', 'QueuePollSeconds', pollSeconds())
    SKIN:Bang('!UpdateMeter', 'MeterSignIn')
    return true
end

function Initialize()
    applied, shown = {}, false
    signedIn, connectingSince, confirmUntil, launched = false, nil, nil, false
    status = DEFAULT_STATUS
    resources = SKIN:GetVariable('@', '')
    local folder = safeRoot(os.getenv('LOCALAPPDATA'))
    root = folder and folder .. '\\Parallax\\Media\\' or nil
    -- Installing a plugin restarts Rainmeter, so one look per load is enough.
    pluginFound = findPlugin()
    SKIN:Bang('!SetVariable', 'QueuePollSeconds', pollSeconds())
end

function Update()
    Render()
    return 0
end

function SignInOpened()
    confirmUntil = nil
    status = 'Sign-in console opened. Close it once it says it is done.'
    Render()
    return true
end

function Disconnect()
    if not signedIn then return false end
    local measure = SKIN:GetMeasure(HOST)
    if not measure then return false end
    local now = os.time()
    if not confirmUntil or now >= confirmUntil then
        confirmUntil = now + CONFIRM_SECONDS
        status = 'Click again to remove the saved Spotify sign-in.'
        Render()
        return false
    end
    confirmUntil = nil
    SKIN:Bang('!UpdateMeasure', HOST)
    if launched and measure:GetValue() == 0 then
        status = 'Disconnect is already running.'
        Render()
        return false
    end
    launched = true
    status = 'Disconnecting...'
    SKIN:Bang('!CommandMeasure', HOST, 'Run')
    Render()
    return true
end

function DisconnectFinished()
    if not launched then return false end
    launched = false
    local measure = SKIN:GetMeasure(HOST)
    local removed = root ~= nil and not present(root .. 'Spotify\\tokens.dpapi')
    status = (removed and measure and measure:GetValue() == 1) and 'Disconnected. The saved sign-in was removed.'
        or 'Disconnect did not finish. Try again.'
    Render()
    return removed
end
