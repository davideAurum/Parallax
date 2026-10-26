-- Parallax updates: the release check, the update offer and the install
-- hand-off. One script serves three hosts, chosen by ParallaxUpdateRole:
--   settings  Global Settings' Updates section: Check now, Update and Notes,
--             plus one check when it opens if automatic checks are on and the
--             last check started over 10 minutes ago.
--   hook      @Resources\Update\Hook1.inc in each loaded utility (automatic
--             check on): a background check 60 s after the load and then
--             whenever one is due (24 h after a good check, 1 h after a failed
--             or unfinished one), looked at by an hourly [!Delay] timer. A
--             newer version the user has not dismissed opens the prompt.
--   prompt    Parallax\Update: Update, Notes and Later.
-- A check is one WebParser request for the release feed; nothing launches a
-- process to poll. Update starts the one-shot UpdateInstall.ps1 helper, which
-- downloads and verifies the package and hands it to Rainmeter's own Skin
-- Installer, where the user confirms. The hosts share @Resources\Update\
-- State.inc; Rainmeter runs every skin on one thread, so the first utility
-- that finds a check due claims it and the others see the claim. Remote text
-- is only ever data. docs/UPDATES.md describes the design.

local FEED, INSTALL = 'MeasureParallaxUpdateFeed', 'MeasureParallaxUpdateInstall'
local DAY, RETRY, OPEN_FRESH = 86400, 3600, 600
local STATE_LIMIT = 65536
local RESULT_TEXT = {
    current = 'Up to date.',
    offline = 'Could not reach github.com.',
    missing = 'No Parallax release was found.',
    ratelimit = 'GitHub is limiting requests.',
    format = 'The release feed could not be read.'
}
local KEYS = { 'UpdateCheckedAt', 'UpdateResultAt', 'UpdateResult', 'UpdateLatest', 'UpdateLatestAt',
    'UpdateUrl', 'UpdateSha256', 'UpdateNotes', 'UpdateDismissed' }

local Link
local role, installed, releaseBase, statePath, settingsFile
local token, firstUpdate
local checking   -- nil, or the kind of check in flight: 'manual' | 'open' | 'background'
local installing -- nil | 'downloading' | 'handed'
local note       -- an install result shown until the next check: { text, error }

local function clamp(value, low, high, fallback)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    return math.max(low, math.min(high, math.floor(value)))
end

local function safeUrl(url)
    return type(url) == 'string' and #url <= 300 and url:match('^[%w%./:_%-]+$') ~= nil
        and releaseBase ~= nil and releaseBase ~= '' and url:sub(1, #releaseBase) == releaseBase
end

local function validVersion(v)
    return type(v) == 'string' and #v <= 64 and v:match('^[%w][%w%._%-]*$') ~= nil
end

-- Semantic-version order: numeric core, then a release sorts after any pre-release of
-- the same core, then dot-separated pre-release identifiers. The character set is the
-- one Package-Parallax.ps1 accepts, so build metadata (+...) never occurs.
local function parseVersion(v)
    if not validVersion(v) then return nil end
    local major, minor, patch, rest = v:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
    if not major then return nil end
    local pre = {}
    if rest ~= '' then
        if rest:sub(1, 1) ~= '-' or #rest < 2 then return nil end
        for id in rest:sub(2):gmatch('[^%.]+') do pre[#pre + 1] = id end
    end
    return { tonumber(major), tonumber(minor), tonumber(patch), pre = pre }
end

function CompareVersions(a, b)
    local x, y = parseVersion(a), parseVersion(b)
    if not x or not y then return nil end
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] < y[i] and -1 or 1 end
    end
    if #x.pre == 0 or #y.pre == 0 then
        if #x.pre == #y.pre then return 0 end
        return #x.pre == 0 and 1 or -1
    end
    for i = 1, math.max(#x.pre, #y.pre) do
        local p, q = x.pre[i], y.pre[i]
        if p == nil then return -1 end
        if q == nil then return 1 end
        if p ~= q then
            local pn, qn = tonumber(p), tonumber(q)
            if pn and qn then return pn < qn and -1 or 1 end
            if pn then return -1 end
            if qn then return 1 end
            return p < q and -1 or 1
        end
    end
    return 0
end

local function expectedUrl(version)
    return releaseBase .. 'download/v' .. version .. '/Parallax_' .. version .. '.rmskin'
end

local function validSha(sha)
    return type(sha) == 'string' and sha:match('^' .. string.rep('%x', 64) .. '$') ~= nil
end

local function field(text, name)
    return text:match('"' .. name .. '"%s*:%s*"([^"\\]*)"')
end

-- Reads the manifest Package-Parallax.ps1 writes beside each release package.
-- Returns an offer table or nil and a reason; remote text is only ever data.
function ParseFeed(text)
    if type(text) ~= 'string' or text == '' then return nil, 'The update feed returned nothing.' end
    if #text > 8192 then return nil, 'The update feed is larger than expected.' end
    if tonumber(text:match('"schema"%s*:%s*(%d+)')) ~= 1 then
        return nil, 'No Parallax release information was found at the update address.'
    end
    local item = {
        name = field(text, 'name'), version = field(text, 'version'),
        url = field(text, 'url'), sha256 = field(text, 'sha256'), notes = field(text, 'notes')
    }
    if item.name ~= 'Parallax' then return nil, 'The update feed describes a different package.' end
    if not parseVersion(item.version) then return nil, 'The update feed lists an unreadable version.' end
    if not validSha(item.sha256) then return nil, 'The update feed has no valid checksum.' end
    if item.url ~= expectedUrl(item.version) or not safeUrl(item.url) then
        return nil, 'The update feed points outside the Parallax releases.'
    end
    if item.notes ~= nil and not safeUrl(item.notes) then item.notes = nil end
    return item
end

-- What a finished request means. WebParser does not expose the HTTP status,
-- so failures are told apart by the body. GitHub answers a missing release or
-- asset with a short "Not Found" body: {"error":"Not Found"} to WebParser
-- (measured 2026-10-26, Rainmeter 4.5.28), plain "Not Found" to curl. A
-- rate-limit page names the limit.
-- Returns the offer, or nil and one of: missing, ratelimit, format.
function Classify(text)
    if type(text) ~= 'string' or text == '' then return nil, 'format' end
    local lower = text:sub(1, 8193):lower()
    if lower:find('rate limit', 1, true) or lower:find('too many requests', 1, true) then return nil, 'ratelimit' end
    if #text <= 256 and lower:find('not found', 1, true) and not text:find('"schema"', 1, true) then return nil, 'missing' end
    local item = ParseFeed(text)
    if not item then return nil, 'format' end
    return item
end

-- Whether a background check is due at now (os.time()) for the saved state.
-- A good result waits a day from the check that produced it; a failed check,
-- or one that never reported (its skin was reloaded), retries after an hour.
-- A check stamped more than 5 minutes in the future means the clock went back.
function Due(now, saved)
    local at = saved and saved.checkedAt or 0
    if at <= 0 or at > now + 300 then return true end
    local good = (saved.resultAt or 0) >= at and (saved.result == 'current' or saved.result == 'available')
    return now - at >= (good and DAY or RETRY)
end

-- Global Settings checks as it opens unless a check started in the last 10
-- minutes: it reloads on every settings change.
function OpenDue(now, saved)
    local at = saved and saved.checkedAt or 0
    return at <= 0 or at > now + 300 or now - at >= OPEN_FRESH
end

local function readState()
    local wanted = {}
    for _, key in ipairs(KEYS) do wanted[key:lower()] = true end
    -- nil when the file is missing or unreadable: !WriteKeyValue never creates
    -- a file, so without it nothing can be saved and no background check runs.
    local values = Link.readSection(statePath, STATE_LIMIT, 'Variables', wanted)
    if not values then return nil end
    local result = values.updateresult or ''
    return {
        checkedAt = tonumber(values.updatecheckedat) or 0,
        resultAt = tonumber(values.updateresultat) or 0,
        result = (result == 'available' or RESULT_TEXT[result]) and result or '',
        latest = values.updatelatest or '',
        latestAt = tonumber(values.updatelatestat) or 0,
        url = values.updateurl or '',
        sha256 = values.updatesha256 or '',
        notes = values.updatenotes or '',
        dismissed = values.updatedismissed or ''
    }
end

-- Every value written is a formatted number, a fixed result name or a feed
-- field that ParseFeed validated, so none can carry quotes or bang syntax.
local function writeState(values)
    for _, key in ipairs(KEYS) do
        if values[key] ~= nil then SKIN:Bang('!WriteKeyValue', 'Variables', key, values[key], statePath) end
    end
end

-- The saved latest release when it is newer than this installation, after
-- validating it again: the state file is local, but nothing trusts it blindly.
local function offerFrom(saved)
    if not saved or not parseVersion(saved.latest) then return nil end
    if saved.url ~= expectedUrl(saved.latest) or not safeUrl(saved.url) or not validSha(saved.sha256) then return nil end
    local order = CompareVersions(installed, saved.latest)
    if order == nil or order >= 0 then return nil end
    return { version = saved.latest, url = saved.url, sha256 = saved.sha256,
        notes = safeUrl(saved.notes) and saved.notes or nil }
end

-- Today's checks show the time, older ones the date and time.
local function stamp(t)
    if not t or t <= 0 then return 'never' end
    if os.date('%Y%m%d', t) == os.date('%Y%m%d') then return os.date('%H:%M', t) end
    return tonumber(os.date('%d', t)) .. os.date(' %b %H:%M', t)
end

local function day(t)
    if os.date('%Y%m%d', t) == os.date('%Y%m%d') then return os.date('%H:%M', t) end
    return tonumber(os.date('%d', t)) .. os.date(' %b', t)
end

-- The status line: the request in flight, an install result, or the last
-- check's result with the time it arrived.
function StatusText(saved, offer, autoOn)
    if checking then return 'Checking github.com for a new release...', false end
    if note then return note.text, note.error end
    -- An incomplete installation: results cannot be saved or shown.
    if not saved then return 'Update state file is missing. Reinstall Parallax.', true end
    if saved.result == '' then
        return autoOn and 'Not checked yet.' or 'Not checked yet. Automatic check is off.', false
    end
    local when = ' Checked ' .. stamp(saved.resultAt) .. '.'
    if saved.result == 'current' or saved.result == 'available' then
        if offer then return 'Parallax ' .. offer.version .. ' is available.' .. when, false end
        return RESULT_TEXT.current .. when, false
    end
    return RESULT_TEXT[saved.result] .. when, true
end

-- Global Settings' Latest value: the newest version a check has read, dated
-- when a later check failed, so an old answer is never shown as current.
function LatestText(saved)
    if not saved or not parseVersion(saved.latest) then return 'Unknown' end
    if saved.latestAt > 0 and saved.latestAt < saved.resultAt then
        return saved.latest .. ' (' .. day(saved.latestAt) .. ')'
    end
    return saved.latest
end

local function setText(meter, text) SKIN:Bang('!SetOption', meter, 'Text', text) end
local function show(meter, visible) SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', meter) end

local function render()
    if role == 'hook' then return end
    local saved = readState()
    local offer = offerFrom(saved)
    local autoOn = SKIN:GetVariable('UpdateCheck', '0') == '1'
    local text, isError = StatusText(saved, offer, autoOn)
    local busy = checking ~= nil or installing == 'downloading'
    if role == 'prompt' then
        if offer then
            setText('MeterHeadline', offer.version .. ' is available')
        end
        if not checking and not note and offer then text, isError = 'Skin Installer asks you to confirm.', false end
        setText('MeterUpdateInstall', installing == 'downloading' and 'Working...' or 'Update')
    else
        setText('MeterUpdateLatestValue', LatestText(saved))
        setText('MeterUpdateCheckNow', checking and 'Checking...' or (installing == 'downloading' and 'Working...' or 'Check now'))
        show('MeterUpdateInstall', offer ~= nil and not busy)
    end
    show('MeterUpdateNotes', offer ~= nil and offer.notes ~= nil)
    setText('MeterUpdateStatus', text)
    -- Global Settings keeps neutral editor text (ARCHITECTURE.md, Appearance);
    -- a failure uses the semantic danger color in both views.
    SKIN:Bang('!SetOption', 'MeterUpdateStatus', 'FontColor', isError and SKIN:GetVariable('DangerColor')
        or (role == 'settings' and '175,175,175' or SKIN:GetVariable('MutedColor')))
    SKIN:Bang('!UpdateMeterGroup', 'ParallaxUpdateUI')
    SKIN:Bang('!Redraw')
    return offer
end

-- Tells the other open update views (Global Settings, the prompt) to show
-- the new state. A group update with no members logs nothing.
local function broadcast()
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxUpdateView', '*')
end

local function arm(ms, call)
    SKIN:Bang(string.format('[!Delay %d][!CommandMeasure MeasureParallaxUpdate "%s(%d)"]', ms, call, token))
end

local function beginCheck(kind)
    if checking or installing == 'downloading' then return false end
    local now = os.time()
    writeState({ UpdateCheckedAt = string.format('%d', now) })
    -- A background check only runs when its claim reads back, so an
    -- unwritable state file cannot make every utility check every hour.
    if kind == 'background' then
        local saved = readState()
        if not saved or saved.checkedAt ~= now then return false end
    end
    checking, note = kind, nil
    SKIN:Bang('!EnableMeasure', FEED)
    -- Utilities update this measure only on request (UpdateDivider=-1) and the
    -- settings views never run an update cycle, so drive the WebParser here:
    -- its first update starts the first download, and its Update command
    -- starts every later one.
    SKIN:Bang('!CommandMeasure', FEED, 'Update')
    SKIN:Bang('!UpdateMeasure', FEED)
    render()
    return true
end

-- Opens Parallax\Update for a newer version the user has not dismissed,
-- unless it is already open (it shows the new state from the broadcast).
-- Does nothing when Update.ini is missing (an activation would open a
-- modal) or Rainmeter.ini cannot be read.
local function prompt(saved)
    local offer = offerFrom(saved)
    if not offer or offer.version == saved.dismissed then return false end
    local config = SKIN:GetVariable('ROOTCONFIG', 'Parallax') .. '\\Update'
    if not Link.exists((SKIN:GetVariable('SKINSPATH', '') or '') .. config .. '\\Update.ini') then return false end
    local active = Link.activeOf(settingsFile, config)
    if active == nil or active ~= 0 then return false end
    SKIN:Bang('!ActivateConfig', config, 'Update.ini')
    return true
end

local function finish(result, item)
    local kind = checking
    checking = nil
    local now = string.format('%d', os.time())
    local values = { UpdateResult = result, UpdateResultAt = now }
    if item then
        values.UpdateLatest, values.UpdateLatestAt = item.version, now
        values.UpdateUrl, values.UpdateSha256, values.UpdateNotes = item.url, item.sha256, item.notes or ''
    end
    writeState(values)
    local saved = readState()
    if kind == 'background' and result == 'available' then prompt(saved) end
    render()
    broadcast()
    return result
end

function FeedReady()
    if not checking then return false end
    local measure = SKIN:GetMeasure(FEED)
    local text = measure and measure:GetStringValue() or ''
    SKIN:Bang('!DisableMeasure', FEED)
    local item, result = Classify(text)
    if item then
        local order = CompareVersions(installed, item.version)
        if order == nil then item, result = nil, 'format' else result = order < 0 and 'available' or 'current' end
    end
    finish(result, item)
    return item ~= nil
end

function FeedError(kind)
    if not checking then return false end
    SKIN:Bang('!DisableMeasure', FEED)
    finish(kind == 'connect' and 'offline' or 'format')
    return false
end

function CheckNow()
    if role ~= 'settings' then return false end
    return beginCheck('manual')
end

-- The hook's timer: re-arms itself first, so a script error cannot end the
-- chain, and acts only for this load's token (Rainmeter keeps delayed
-- commands across a refresh).
function Tick(t)
    if role ~= 'hook' or t ~= token then return false end
    arm(clamp(SKIN:GetVariable('ParallaxUpdateTickMs'), 1000, 86400000, 3600000), 'Tick')
    local saved = readState()
    if not saved or not Due(os.time(), saved) then return false end
    return beginCheck('background')
end

function OpenCheck(t)
    if role ~= 'settings' or t ~= token then return false end
    if SKIN:GetVariable('UpdateCheck', '0') ~= '1' then return false end
    local saved = readState()
    if not saved or not OpenDue(os.time(), saved) then return false end
    return beginCheck('open')
end

function Install()
    if role == 'hook' or checking or installing == 'downloading' then return false end
    local offer = offerFrom(readState())
    if not offer then return false end
    local root = SKIN:GetVariable('@', '')
    local program = (SKIN:GetVariable('PROGRAMPATH', '')):gsub('\\+$', '')
    if root:find('"', 1, true) or program:find('"', 1, true) then return false end
    -- Only the validated URL, version, checksum and fixed paths enter this command.
    -- The helper validates them again and reports back through stdout as data.
    local args = string.format('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sScripts\\UpdateInstall.ps1" -Url "%s" -Sha256 %s -Version %s -ReleaseBase "%s" -ProgramPath "%s"',
        root, offer.url, offer.sha256, offer.version, releaseBase, program)
    installing, note = 'downloading', { text = 'Downloading ' .. offer.version .. '...', error = false }
    SKIN:Bang('!SetOption', INSTALL, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', INSTALL)
    SKIN:Bang('!CommandMeasure', INSTALL, 'Run')
    render()
    return true
end

function InstallDone()
    if installing ~= 'downloading' then return false end
    local measure = SKIN:GetMeasure(INSTALL)
    local output = (measure and measure:GetStringValue() or ''):gsub('[\r\n]+$', '')
    local result = output:match('PARALLAX_UPDATE_V1|(%a+)|')
    if result == 'ok' then
        installing, note = 'handed', { text = 'Confirm in Skin Installer to finish.', error = false }
    elseif result == 'blocked' then
        -- Verified package, but a Parallax media helper would not end and would
        -- stop Skin Installer moving the old skin folder aside.
        installing, note = nil, { text = 'A media helper is running. Quit Rainmeter.', error = true }
    else
        installing, note = nil, { text = 'Download failed. Nothing was installed.', error = true }
    end
    render()
    return result == 'ok'
end

function OpenNotes()
    if role == 'hook' then return false end
    local offer = offerFrom(readState())
    if not offer or not offer.notes then return false end
    SKIN:Bang('["' .. offer.notes .. '"]')
    return true
end

-- The prompt's Later and its X: no further prompt for this version. Global
-- Settings still offers it, and a newer release prompts again.
function Later()
    if role ~= 'prompt' then return false end
    local offer = offerFrom(readState())
    if offer then writeState({ UpdateDismissed = offer.version }) end
    SKIN:Bang('!DeactivateConfig')
    return true
end

-- First appearance: the top-right corner of the primary work area. Rainmeter
-- records WindowX=0 and WindowY=0 for a config it has never positioned (it
-- writes them on activation, before this runs), so only that position, or
-- none, is moved; any position from a drag or this move is kept. A prompt
-- dragged to exactly 0,0 therefore moves back on its next appearance.
local function place()
    local values = Link.readSection(settingsFile, Link.SETTINGS_LIMIT, SKIN:GetVariable('CURRENTCONFIG', ''), { windowx = true, windowy = true })
    if not values then return end
    if (values.windowx and tonumber(values.windowx) ~= 0) or (values.windowy and tonumber(values.windowy) ~= 0) then return end
    local right = (tonumber(SKIN:GetVariable('WORKAREAX')) or 0) + (tonumber(SKIN:GetVariable('WORKAREAWIDTH')) or 0)
    local top = tonumber(SKIN:GetVariable('WORKAREAY')) or 0
    -- The window may not be sized yet during the first update.
    local width = tonumber(SKIN:ParseFormula(SKIN:ReplaceVariables('#WindowWidth#')))
    if right <= 0 or not width or width <= 0 then return end
    SKIN:Bang('!Move', string.format('%d', math.max(0, right - width - 16)), string.format('%d', top + 16))
end

function Initialize()
    Link = dofile(SKIN:GetVariable('@') .. 'Idle\\Link.lua')
    role = SKIN:GetVariable('ParallaxUpdateRole', 'hook')
    installed = SKIN:GetVariable('ParallaxVersion', '')
    releaseBase = SKIN:GetVariable('UpdateReleaseBase', '')
    statePath = SKIN:GetVariable('@') .. 'Update\\State.inc'
    settingsFile = (SKIN:GetVariable('SETTINGSPATH', '') or '') .. 'Rainmeter.ini'
    -- Seeded per load and bounded, as in Settings.lua: a timer armed before a
    -- refresh survives it and must not match a token issued after it.
    token = math.floor(os.clock() * 1000) % 1000000000
    firstUpdate = true
    checking, installing, note = nil, nil, nil
end

-- The hook runs once per load (UpdateDivider=-1); the views run at load and
-- whenever another host broadcasts.
function Update()
    local first = firstUpdate
    firstUpdate = false
    if role == 'hook' then
        if first then arm(clamp(SKIN:GetVariable('ParallaxUpdateFirstDelay'), 1000, 600000, 60000), 'Tick') end
        return 0
    end
    local offer = render()
    if first and role == 'settings' then
        arm(500, 'OpenCheck')
    elseif role == 'prompt' then
        if first then place() end
        -- Nothing left to offer (installed, withdrawn or dismissed elsewhere):
        -- close, but never during a download or once handed to Skin Installer.
        local saved = readState()
        if not installing and (not offer or (saved and offer.version == saved.dismissed)) then
            SKIN:Bang('[!Delay 100][!DeactivateConfig]')
        end
    end
    return 0
end
