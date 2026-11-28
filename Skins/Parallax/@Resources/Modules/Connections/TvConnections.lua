-- Parallax Connections: the TV row (YouTube in the TV's own app, Media's TV
-- queue). Reads only whether a pairing file exists (never what is in it), the
-- fixed header of the TV worker's snapshot and its intent file. No network, id,
-- title or code; every text shown is one of the fixed strings below. Pair opens
-- the worker's own console; Start, Stop and Forget run it hidden, once per click.

local HOST = 'MeasureTvControl'
local HEADER_BYTES = 512
local CLOCK_SLACK = 5
local CONFIRM_SECONDS = 8
-- A click's command is still starting or finishing for about this long.
local BUSY_SECONDS = 20
local STATES = { not_paired = true, connecting = true, ready = true, no_screen = true, offline = true,
    pair_again = true, error = true, stopped = true }
local TONES = { good = 'GoodColor', warn = 'WarningColor', muted = 'MutedColor' }
local COMMANDS = { Start = true, Stop = true, Forget = true }
local PROVIDER = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "TvProvider.ps1" -Command "%s" -Quiet'

local root, applied, shown, confirmUntil, busyUntil, note, noteUntil, ran

local function safeRoot(value)
    if type(value) ~= 'string' or #value > 2048 or not value:match('^%a:[/\\]') then return nil end
    if value:find('[%z\001-\031"<>|?*]') then return nil end
    return (value:gsub('[/\\]+$', ''))
end

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

-- The snapshot's state and times, or nil. Titles after the header are never read.
local function header(path)
    local data = readStart(path, HEADER_BYTES)
    if not data then return nil end
    data = data:gsub('\r\n', '\n')
    if data:sub(1, 15) ~= 'PARALLAX_TV_V1\n' then return nil end
    local fields = {}
    for line in data:sub(16):gmatch('([^\n]*)\n') do
        local key, value = line:match('^([a-z_]+)=([a-z0-9_]*)$')
        if not key or key == 'current_title' then break end
        fields[key] = value
    end
    if not STATES[fields.state or ''] then return nil end
    return fields
end

-- State text, tone, detail, and what the buttons offer.
local function tv(now)
    if not root then return { 'Unknown', 'muted', 'The local app data folder was not found.' }, false, false end
    local paired = present(root .. 'pairing.dpapi')
    if not paired then return { 'Not paired', 'muted', 'Pair opens a console for the code from the TV.' }, false, false end
    local fields = header(root .. 'tv.snapshot')
    local expiry = fields and integer(fields.valid_until) or nil
    local live = expiry ~= nil and expiry > 0 and now < expiry + CLOCK_SLACK
    local state = fields and fields.state or 'stopped'
    if live then
        if state == 'ready' then return { 'Connected', 'good', 'Up next shows in Media when nothing plays here.' }, true, true end
        if state == 'no_screen' then return { 'TV app closed', 'muted', 'The worker rejoins when the TV is back.' }, true, true end
        if state == 'connecting' then return { 'Connecting', 'muted', 'Joining the TV.' }, true, true end
        if state == 'offline' then return { 'Offline', 'muted', 'The worker tries again by itself.' }, true, true end
        if state == 'error' then return { 'Unavailable', 'warn', 'YouTube did not answer. It tries again.' }, true, true end
    end
    if state == 'pair_again' then return { 'Pair again', 'warn', 'The TV refused the saved pairing.' }, true, false end
    if state == 'ready' or state == 'no_screen' or state == 'connecting' or state == 'offline' or state == 'error' then
        return { 'Paired', 'muted', 'The TV worker is not running. Start reads the TV.' }, true, false
    end
    return { 'Paired', 'muted', 'The TV worker is off. Start reads the TV.' }, true, false
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
    local entry, paired, running = tv(now)
    if not paired then confirmUntil = nil end
    put('MeterTvState', 'Text', entry[1])
    put('MeterTvState', 'FontColor', '#' .. TONES[entry[2]] .. '#')
    put('MeterTvDetail', 'Text', note or (confirmUntil and 'Click Forget again to remove the TV pairing.') or entry[3])
    put('MeterTvPair', 'Text', paired and 'Pair again' or 'Pair')
    put('MeterTvSwitch', 'Text', running and 'Stop' or 'Start')
    put('MeterTvForget', 'Text', confirmUntil and 'Forget?' or 'Forget')
    put('MeterTvForget', 'FontColor', confirmUntil and '#WarningColor#' or '#AccentColor2#')
    show('MeterTvSwitch', paired)
    show('MeterTvForget', paired)
    if shown then
        shown = false
        SKIN:Bang('!UpdateMeterGroup', 'TvConnectionsData')
        SKIN:Bang('!Redraw')
    end
end

local function run(command, message)
    if not COMMANDS[command] or not SKIN:GetMeasure(HOST) then return false end
    local now = os.time()
    -- The Casts row runs its commands through the same host (CastConnections.lua).
    -- Each row publishes until when its command counts as running in a skin
    -- variable, read by the other: CastCommandBusyUntil here, TvCommandBusyUntil there.
    local castBusy = tonumber(SKIN:GetVariable('CastCommandBusyUntil', '0')) or 0
    if busyUntil and now < busyUntil then
        note = 'The last TV command is still running.'
        Render()
        return false
    end
    if now < castBusy then
        note, noteUntil = 'A Casts command is still running.', castBusy
        Render()
        return false
    end
    SKIN:Bang('!SetOption', HOST, 'Parameter', string.format(PROVIDER, command))
    SKIN:Bang('!UpdateMeasure', HOST)
    SKIN:Bang('!CommandMeasure', HOST, 'Run')
    busyUntil, note, noteUntil, ran = now + BUSY_SECONDS, message, nil, true
    SKIN:Bang('!SetVariable', 'TvCommandBusyUntil', tostring(busyUntil))
    Render()
    return true
end

function Switch()
    local _, paired, running = tv(os.time())
    if not paired then return false end
    confirmUntil = nil
    if running then return run('Stop', 'Stopping the TV worker...') end
    return run('Start', 'Starting the TV worker...')
end

function Forget()
    local _, paired = tv(os.time())
    if not paired then return false end
    local now = os.time()
    if not confirmUntil then
        confirmUntil = now + CONFIRM_SECONDS
        Render()
        return false
    end
    confirmUntil = nil
    return run('Forget', 'Removing the TV pairing...')
end

function CommandFinished()
    -- The host's finish (for either row's command): this row's busy time ends.
    if ran then SKIN:Bang('!SetVariable', 'TvCommandBusyUntil', '0') end
    busyUntil, note, noteUntil, ran = nil, nil, nil, false
    Render()
    return true
end

function PairOpened()
    confirmUntil = nil
    note = 'Pair console open. Type the code under Link with TV code.'
    busyUntil = os.time() + BUSY_SECONDS
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
