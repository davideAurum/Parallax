-- Parallax Connections: the Casts row (a YouTube cast from Chrome, followed on
-- the TV). Off until the user turns it on here.
-- Reads only the switch file, whether a cast key file exists (never what is in
-- it) and the worker's one-word cast state. No network, name, address, id or
-- title; every text shown is one of the fixed strings below. Turn on, Turn off,
-- Start and Forget run the TV worker hidden, once per click, through the TV
-- row's command host (MeasureTvControl); the two rows share its busy state.

local HOST = 'MeasureTvControl'
local CLOCK_SLACK = 5
local CONFIRM_SECONDS = 8
local BUSY_SECONDS = 20
local TONES = { good = 'GoodColor', warn = 'WarningColor', muted = 'MutedColor' }
local COMMANDS = { CastOn = true, CastOff = true, CastForget = true }
local PROVIDER = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "TvProvider.ps1" -Command "%s" -Quiet'
-- The worker's cast states (TvStore.psm1, cast.status) and what each shows.
local STATES = {
    following = { 'Following', 'good', 'Media follows the cast on the TV.' },
    waiting = { 'On', 'good', 'Cast from Chrome to the TV to follow it.' },
    searching = { 'Looking', 'muted', 'Looking for the TV on your network.' },
    no_device = { 'No TV found', 'muted', 'It looks again by itself.' },
    several = { 'Several casts', 'warn', 'More than one TV plays YouTube. None shown.' },
    tv_app = { 'TV app', 'muted', 'The TV app shows through the row above.' },
    no_key = { 'No cast key', 'warn', 'The cast gave no key. Controls may fail.' },
    error = { 'Unavailable', 'warn', 'The TV did not answer. It tries again.' },
    off = { 'Off', 'muted', 'Turn on to follow a cast from Chrome.' },
}

local root, applied, shown, confirmUntil, busyUntil, note, noteUntil, ran

local function safeRoot(value)
    if type(value) ~= 'string' or #value > 2048 or not value:match('^%a:[/\\]') then return nil end
    if value:find('[%z\001-\031"<>|?*]') then return nil end
    return (value:gsub('[/\\]+$', ''))
end

local function readStart(path, bytes)
    local ok, file = pcall(io.open, path, 'rb')
    if not ok or not file then return nil end
    local good, data = pcall(file.read, file, bytes)
    pcall(file.close, file)
    return good and type(data) == 'string' and data or nil
end

local function present(path)
    local ok, file = pcall(io.open, path, 'rb')
    if ok and file then pcall(file.close, file); return true end
    return false
end

-- Row text, tone, detail; whether casts are on; whether the worker reports them;
-- whether anything cast-related is stored (Forget shows).
local function cast(now)
    if not root then return { 'Unknown', 'muted', 'The local app data folder was not found.' }, false, false, false end
    local intent = readStart(root .. 'cast.intent', 64)
    local on = intent == 'PARALLAX_TV_CAST_V1|1\n'
    local stored = intent ~= nil or present(root .. 'cast.dpapi')
    if not on then return STATES.off, false, false, stored end
    local data = readStart(root .. 'cast.status', 64) or ''
    local state, expiry = data:match('^PARALLAX_TV_CASTSTATE_V1|([a-z_]+)|(%d+)\n$')
    expiry = tonumber(expiry)
    if state and STATES[state] and state ~= 'off' and expiry and expiry > 0 and now < expiry + CLOCK_SLACK then
        return STATES[state], true, true, true
    end
    return { 'On, not running', 'muted', 'Start runs the TV worker again.' }, true, false, true
end

local function put(meter, key, value)
    local slot = meter .. '/' .. key
    if applied[slot] == value then return end
    applied[slot], shown = value, true
    SKIN:Bang('!SetOption', meter, key, value)
end

local function show(meter, visible)
    if applied['v/' .. meter] == visible then return end
    applied['v/' .. meter], shown = visible, true
    SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', meter)
end

function Render()
    local now = os.time()
    if confirmUntil and now >= confirmUntil then confirmUntil = nil end
    if busyUntil and now >= busyUntil then busyUntil, note = nil, nil end
    -- A refusal's note lasts as long as what caused it.
    if noteUntil and now >= noteUntil then noteUntil, note = nil, nil end
    local entry, on, running, stored = cast(now)
    if not stored then confirmUntil = nil end
    put('MeterCastState', 'Text', entry[1])
    put('MeterCastState', 'FontColor', '#' .. TONES[entry[2]] .. '#')
    put('MeterCastDetail', 'Text', note or (confirmUntil and 'Click Forget again to remove the cast key.') or entry[3])
    put('MeterCastSwitch', 'Text', (not on and 'Turn on') or (running and 'Turn off') or 'Start')
    put('MeterCastForget', 'Text', confirmUntil and 'Forget?' or 'Forget')
    put('MeterCastForget', 'FontColor', confirmUntil and '#WarningColor#' or '#AccentColor2#')
    show('MeterCastSwitch', root ~= nil)
    show('MeterCastForget', stored)
    if shown then
        shown = false
        SKIN:Bang('!UpdateMeterGroup', 'CastConnectionsData')
        SKIN:Bang('!Redraw')
    end
end

local function run(command, message)
    if not COMMANDS[command] or not SKIN:GetMeasure(HOST) then return false end
    local now = os.time()
    -- One host for both rows: never while the TV row's command runs (it
    -- publishes TvCommandBusyUntil, TvConnections.lua).
    if busyUntil and now < busyUntil then
        note = 'The last command is still running.'
        Render()
        return false
    end
    local tvBusy = tonumber(SKIN:GetVariable('TvCommandBusyUntil', '0')) or 0
    if now < tvBusy then
        note, noteUntil = 'A TV command is still running.', tvBusy
        Render()
        return false
    end
    SKIN:Bang('!SetOption', HOST, 'Parameter', string.format(PROVIDER, command))
    SKIN:Bang('!UpdateMeasure', HOST)
    SKIN:Bang('!CommandMeasure', HOST, 'Run')
    busyUntil, note, noteUntil, ran = now + BUSY_SECONDS, message, nil, true
    -- And this row's busy time, for the TV row to read.
    SKIN:Bang('!SetVariable', 'CastCommandBusyUntil', tostring(busyUntil))
    Render()
    return true
end

-- Turn on (also Start when on but not running) or Turn off.
function Switch()
    if not root then return false end
    local _, on, running = cast(os.time())
    confirmUntil = nil
    if on and running then return run('CastOff', 'Turning casts off...') end
    return run('CastOn', 'Turning casts on...')
end

function Forget()
    local _, _, _, stored = cast(os.time())
    if not stored then return false end
    local now = os.time()
    if not confirmUntil then
        confirmUntil = now + CONFIRM_SECONDS
        Render()
        return false
    end
    confirmUntil = nil
    return run('CastForget', 'Removing the cast key...')
end

function CommandFinished()
    -- The host's finish (for either row's command): this row's busy time ends.
    if ran then SKIN:Bang('!SetVariable', 'CastCommandBusyUntil', '0') end
    busyUntil, note, noteUntil, ran = nil, nil, nil, false
    Render()
    return true
end

function Initialize()
    applied, shown, confirmUntil, busyUntil, note, noteUntil, ran = {}, false, nil, nil, nil, nil, false
    local folder = safeRoot(os.getenv('LOCALAPPDATA'))
    root = folder and folder .. '\\Parallax\\Media\\YouTube\\' or nil
end

function Update()
    Render()
    return 0
end
