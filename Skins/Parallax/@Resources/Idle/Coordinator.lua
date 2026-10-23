-- Parallax\Idle coordinator: the suite's one input-idle signal.
--
-- Any SysInfo measure makes its whole skin poll Windows' network interface
-- table on every tick (Rainmeter 4.5.28 Skin.cpp, MeasureNet::UpdateIFTable),
-- so the only IDLE_TIME measure lives here, in a hidden config on a slow tick
-- (docs/PERFORMANCE-REVIEW.md T6). Consumers start this config when they need
-- it (@Resources\Idle\Link.lua) and it unloads itself when nothing does.
--
-- Protocol, sent to the Parallax group:
--   !SetVariableGroup ParallaxIdleAway  0|1        Parallax
--   !SetVariableGroup ParallaxIdlePaused 0|1       Parallax
--   !SetVariableGroup ParallaxIdleBeat <os.time()> Parallax
--   !SetVariableGroup ParallaxIdleSync 1           Parallax
--   !UpdateMeasureGroup ParallaxIdleHook *
-- on a change, about once a minute as a heartbeat, after a tick gap of more
-- than 10 s (sleep or resume), on Start() and on a consumer's sync request.
-- ParallaxIdleAway is 1 after 5 minutes without input (the drawer's capture
-- lease). ParallaxIdlePaused is 1 after the Global Settings "Idle pause"
-- minutes without input (User\Settings.inc IdlePauseMinutes 5, 10 or 30;
-- anything else is Off): the idle stand-down (@Resources\Idle\StandDown.lua).
--
-- Update() does nothing until Start() has run from OnRefreshAction: the load's
-- forced first update, and the request Calcs' load-time OnUpdateAction, come
-- before it. The config deactivates itself only from a regular tick, tick 2
-- onward, never inside a load (Rainmeter marks a skin running after its first
-- update) and never inside another skin's group request.

local MODULUS = 4294967.296      -- 2^32 ms in seconds: IDLE_TIME's wrap step
local GAP_SECONDS = 10
local AWAY_SECONDS = 300
local HEARTBEAT_SECONDS = 60
local REEVALUATE_TICKS = 300
local PAUSE_MINUTES = { ['5'] = 5, ['10'] = 10, ['30'] = 30 }
-- Configs whose skins carry the idle stand-down hook while it is on.
local UTILITY_CONFIGS = { 'Chronometer', 'CPU', 'GPU', 'RAM', 'IO', 'Network', 'Media', 'Media\\Queue', 'Visualizer' }

local Link
local started, ticks, lastTick, requested
local lastAway, lastPaused
local awaySeconds, pauseSeconds, heartbeatTicks, reevaluateTicks, testFile, tickSeconds, gapSeconds

-- A test hook: a whole number inside [low, high], otherwise nil. Shipped
-- files leave every hook empty; test harnesses set them in staged copies.
local function hook(name, low, high)
    local text = SKIN:GetVariable(name, '')
    if type(text) ~= 'string' or not text:match('^%s*%d+%s*$') then return nil end
    local number = tonumber(text)
    if number < low or number > high then return nil end
    return number
end

-- IDLE_TIME is (GetTickCount64 - dwTime) / 1000 with a 32-bit dwTime, so
-- after 49.7 days of uptime it carries k * 4294967.296 s, floored. Reducing
-- by that step leaves the true idle time within a second, except that the
-- first second after input can come out just below a whole step (0.296 * k
-- fractions); anything within 2 s of the step is that case and reads 0.
function Wrap(raw)
    if type(raw) ~= 'number' or raw ~= raw or raw < 0 or raw == math.huge then return nil end
    local value = raw % MODULUS
    if value > MODULUS - 2 then value = 0 end
    return value
end

local function readIdle()
    local raw
    if testFile then
        local text = Link.readText(testFile, 32)
        raw = text and text:match('^%s*(%d+)%s*$') and tonumber(text:match('^%s*(%d+)%s*$')) or nil
    else
        local measure = SKIN:GetMeasure('MeasureParallaxIdleRaw')
        raw = measure and measure:GetValue() or nil
    end
    return Wrap(raw)
end

local function broadcast(away, paused)
    lastAway, lastPaused = away, paused
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleAway', away and '1' or '0', 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdlePaused', paused and '1' or '0', 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleBeat', string.format('%d', os.time()), 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleSync', '1', 'Parallax')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxIdleHook', '*')
end

-- Something that needs this coordinator, read from files only. Unreadable
-- files keep it loaded; a missing preference uses the shipped default.
--   C1: Parallax\Media running Media.ini, its spectrum drawer open
--       (User\Media.inc VisualizerDrawer=2) and its capture not deferred to
--       the standalone Audio Visualizer (CaptureState.inc MediaDrawerCapture
--       is not 2).
--   C2: Idle pause on and any utility config loaded (Media's Setup.ini and
--       the Queue config included).
local function needed()
    local resources = SKIN:GetVariable('@', '')
    local root = SKIN:GetVariable('ROOTCONFIG', 'Parallax')
    local settings = SKIN:GetVariable('SETTINGSPATH', '') .. 'Rainmeter.ini'
    if pauseSeconds then
        for _, config in ipairs(UTILITY_CONFIGS) do
            local active = Link.activeOf(settings, root .. '\\' .. config)
            if active == nil or active > 0 then return true end
        end
    end
    local media = Link.activeOf(settings, root .. '\\Media')
    if media == nil then return true end
    if media == 1 then
        local preferences = Link.readSection(resources .. 'User\\Media.inc', 262144, 'Variables', { visualizerdrawer = true })
        if preferences == nil then return true end
        if preferences.visualizerdrawer == '2' then
            -- A missing or unreadable state file means live capture.
            local state = Link.readSection(resources .. 'Modules\\Media\\CaptureState.inc', 65536, 'Variables', { mediadrawercapture = true }) or {}
            if state.mediadrawercapture ~= '2' then return true end
        end
    end
    return false
end

function Initialize()
    Link = dofile(SKIN:GetVariable('@') .. 'Idle\\Link.lua')
    started, ticks, lastTick, requested = false, 0, nil, false
    lastAway, lastPaused = false, false
    local tickMs = tonumber(SKIN:ParseFormula(SKIN:ReplaceVariables('#ParallaxIdleTickMs#')))
    if not tickMs or tickMs ~= tickMs or tickMs < 500 or tickMs > 10000 then tickMs = 2000 end
    tickSeconds = tickMs / 1000
    -- A gap longer than 10 s means sleep or resume; a slow hand-set tick
    -- (up to 10 s) needs room for its own jitter.
    gapSeconds = math.max(GAP_SECONDS, 2 * tickSeconds)
    awaySeconds = hook('ParallaxIdleTestAwaySeconds', 1, AWAY_SECONDS) or AWAY_SECONDS
    -- Idle pause: 5, 10 or 30 minutes, otherwise Off (a hand-edited value
    -- shows Custom in Global Settings and acts as Off). The test hook only
    -- shortens a setting that is on.
    local minutes = SKIN:GetVariable('IdlePauseMinutes', '0')
    minutes = type(minutes) == 'string' and PAUSE_MINUTES[minutes:match('^%s*(.-)%s*$')] or nil
    pauseSeconds = minutes and (hook('ParallaxIdleTestPauseSeconds', 1, 1800) or minutes * 60) or nil
    heartbeatTicks = hook('ParallaxIdleTestHeartbeatTicks', 2, 300) or math.max(2, math.floor(HEARTBEAT_SECONDS / tickSeconds + 0.5))
    reevaluateTicks = hook('ParallaxIdleTestReevaluateTicks', 2, REEVALUATE_TICKS) or REEVALUATE_TICKS
    local file = SKIN:GetVariable('ParallaxIdleTestFile', '')
    testFile = (type(file) == 'string' and file:match('^%a:\\[^%c"*?<>|]+$')) and file or nil
end

function Update()
    if not started then return 0 end
    ticks = ticks + 1
    local now = os.time()
    local idle = readIdle()
    local away, paused = lastAway, lastPaused
    if idle ~= nil then away, paused = idle >= awaySeconds, pauseSeconds ~= nil and idle >= pauseSeconds end
    local gap = lastTick ~= nil and (now - lastTick > gapSeconds or now < lastTick)
    lastTick = now
    if away ~= lastAway or paused ~= lastPaused or ticks % heartbeatTicks == 0 or gap then broadcast(away, paused) end
    if ticks >= 2 and (requested or ticks % reevaluateTicks == 0) then
        requested = false
        if not needed() then
            SKIN:Bang('!DeactivateConfig')
            return -1
        end
    end
    return idle or -1
end

-- OnRefreshAction: the first broadcast, after the load has finished.
function Start()
    local idle = readIdle()
    lastTick = os.time()
    ticks = 0
    started = true
    broadcast(idle ~= nil and idle >= awaySeconds or false, idle ~= nil and pauseSeconds ~= nil and idle >= pauseSeconds or false)
end

-- A consumer's silent group request: repeat the current state.
function Sync()
    if not started then return end
    broadcast(lastAway, lastPaused)
end

-- A consumer collapsed or hid what needed this: re-check at the next regular
-- tick. Never acts here, which can be inside another skin's group request.
-- The request Calc also fires once during the load, before Start(): ignored.
function RequestReevaluate()
    if started then requested = true end
end

-- OnCloseAction. Rainmeter has already recorded Active=0 when this config is
-- unloaded, so tell every consumer to stop waiting; at Rainmeter exit or a
-- game-mode unload Active is unchanged and nothing is sent.
function Closing()
    if not Link then return end
    local settings = SKIN:GetVariable('SETTINGSPATH', '') .. 'Rainmeter.ini'
    local active = Link.activeOf(settings, SKIN:GetVariable('ROOTCONFIG', 'Parallax') .. '\\Idle')
    if active == 0 then broadcast(false, false) end
end
