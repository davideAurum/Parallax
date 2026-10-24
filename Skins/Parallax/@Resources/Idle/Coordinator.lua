-- Parallax\Idle coordinator: the suite's one input-idle signal.
--
-- The only input-idle source is the SysInfo IDLE_TIME measure, and Rainmeter
-- 4.5.28 reads Windows' network interface table (MeasureNet::UpdateIFTable,
-- GetIfTable2) before every update of a skin that holds any SysInfo measure,
-- and for every !UpdateMeasure of one (Skin.cpp Update, UpdateMeasure): about
-- 2 ms and 30 context switches of Rainmeter's UI thread per reading on the
-- owner's PC (docs/PERFORMANCE-REVIEW.md T6 and phase C). So the measure lives
-- in this hidden config, and the config never runs Rainmeter's own skin update
-- (Idle.ini Update=-1): its tick is a self-rearming [!Delay] chain started by
-- Start(), and the measure is updated only when a reading could change what is
-- broadcast (Reads, below). Consumers start this config when they need it
-- (@Resources\Idle\Link.lua) and it unloads itself when nothing does.
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
-- Reads. A tick reads the measure while away or paused (input is seen at the
-- next tick), at Start(), on every heartbeat tick and after a tick gap.
-- Otherwise it skips the reading while the last reading, plus the time since
-- (the larger of os.time() and os.clock() differences), plus 3 s for rounding,
-- is still short of the nearest threshold (away, or the Idle pause): idle time
-- can only grow by the time that passed, so the state is still "not away, not
-- paused" and the broadcasts are the ones a reading on every tick would send,
-- at the same ticks. While you are at the computer that is one reading a
-- minute instead of one every 2 s. A test idle file is read on every tick (its
-- values may jump), and the measure is still updated on the real schedule, so
-- a test run costs what a real one does.
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
-- IDLE_TIME is floored to whole seconds and the wrap guard can read up to a
-- second low; os.time() has whole-second steps. 3 s covers both with room.
local READ_MARGIN = 3
local PAUSE_MINUTES = { ['5'] = 5, ['10'] = 10, ['30'] = 30 }
-- Configs whose skins carry the idle stand-down hook while it is on.
local UTILITY_CONFIGS = { 'Chronometer', 'CPU', 'GPU', 'RAM', 'IO', 'Network', 'Media', 'Media\\Queue', 'Visualizer' }

local Link
local started, closing, ticks, lastTick, requested
local lastAway, lastPaused
local sampleIdle, sampleTime, sampleClock
local loadId, serial, token
local awaySeconds, pauseSeconds, heartbeatTicks, reevaluateTicks, testFile, tickMs, tickSeconds, gapSeconds

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

-- Wall-clock seconds since Rainmeter started (MSVC clock()); nil when
-- unusable (it stops at -1 after 24.8 days). Only ever widens an estimate.
local function clockNow()
    local ok, value = pcall(os.clock)
    if ok and type(value) == 'number' and value == value and value >= 0 and value < math.huge then return value end
    return nil
end

local function measuredIdle()
    local measure = SKIN:GetMeasure('MeasureParallaxIdleRaw')
    return measure and measure:GetValue() or nil
end

local function fileIdle()
    local text = Link.readText(testFile, 32)
    local digits = text and text:match('^%s*(%d+)%s*$')
    return digits and tonumber(digits) or nil
end

-- Whether a reading could change the state last broadcast (Reads, above).
local function due(now, clock)
    if lastAway or lastPaused or sampleIdle == nil or sampleTime == nil or now < sampleTime then return true end
    local elapsed = now - sampleTime
    if clock and sampleClock and clock >= sampleClock and clock - sampleClock > elapsed then elapsed = clock - sampleClock end
    local nearest = pauseSeconds and math.min(awaySeconds, pauseSeconds) or awaySeconds
    return sampleIdle + elapsed + READ_MARGIN >= nearest
end

-- This tick's idle seconds, or nil when no reading was taken or it was
-- invalid (the state then stays as last broadcast). force: Start, heartbeat
-- or a tick gap. The !UpdateMeasure is where Rainmeter reads the network
-- table; Update=-1 keeps every other path from doing so.
local function sample(force)
    local now, clock = os.time(), clockNow()
    local read = force or due(now, clock)
    if read then SKIN:Bang('!UpdateMeasure', 'MeasureParallaxIdleRaw') end
    local idle
    if testFile then idle = Wrap(fileIdle()) elseif read then idle = Wrap(measuredIdle()) end
    if read then sampleIdle, sampleTime, sampleClock = idle, now, clock end
    return idle
end

local function broadcast(away, paused)
    lastAway, lastPaused = away, paused
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleAway', away and '1' or '0', 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdlePaused', paused and '1' or '0', 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleBeat', string.format('%d', os.time()), 'Parallax')
    SKIN:Bang('!SetVariableGroup', 'ParallaxIdleSync', '1', 'Parallax')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxIdleHook', '*')
end

-- The next tick of this Start's chain. Delayed commands outlive a refresh of
-- this config, so each one carries the token of the Start that armed it.
local function arm()
    SKIN:Bang(string.format('[!Delay %d][!CommandMeasure MeasureParallaxIdle "Tick(\'%s\')"]', tickMs, token))
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
    started, closing, ticks, lastTick, requested = false, false, 0, nil, false
    lastAway, lastPaused = false, false
    sampleIdle, sampleTime, sampleClock = nil, nil, nil
    -- Unique to this load: its Lua state's address, the second and the clock.
    loadId = string.format('%s%x%x', (tostring({}):gsub('[^%w]', '')), os.time() % 2147483647, math.floor((clockNow() or 0) * 1000) % 2147483647)
    serial, token = 0, nil
    local ms = tonumber(SKIN:ParseFormula(SKIN:ReplaceVariables('#ParallaxIdleTickMs#')))
    if not ms or ms ~= ms or ms < 500 or ms > 10000 then ms = 2000 end
    tickMs = math.floor(ms + 0.5)
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

-- One coordinator tick. Rainmeter runs it for the chain's !UpdateMeasure
-- (Tick), so a paused or disabled measure does not tick, as with a skin timer,
-- and for the load's forced first update, which comes before Start and does
-- nothing. Returns this tick's reading, or -1 when none was taken.
function Update()
    if not started or closing then return 0 end
    ticks = ticks + 1
    local now = os.time()
    local gap = lastTick ~= nil and (now - lastTick > gapSeconds or now < lastTick)
    lastTick = now
    local heartbeat = ticks % heartbeatTicks == 0
    local idle = sample(heartbeat or gap)
    local away, paused = lastAway, lastPaused
    if idle ~= nil then away, paused = idle >= awaySeconds, pauseSeconds ~= nil and idle >= pauseSeconds end
    if away ~= lastAway or paused ~= lastPaused or heartbeat or gap then broadcast(away, paused) end
    if ticks >= 2 and (requested or ticks % reevaluateTicks == 0) then
        requested = false
        if not needed() then
            closing = true
            SKIN:Bang('!DeactivateConfig')
            return -1
        end
    end
    return idle or -1
end

-- A tick of this config's [!Delay] chain. The next one is armed first, so a
-- script error in one tick cannot end the chain, and the chain outlives a
-- pause of this measure; a tick armed by an earlier Start or an earlier load
-- of this config carries another token and is dropped, so there is only ever
-- one chain. The tick itself goes through Rainmeter's own measure update.
function Tick(id)
    if closing or not started or id ~= token then return end
    arm()
    SKIN:Bang('!UpdateMeasure', 'MeasureParallaxIdle')
end

-- OnRefreshAction: the first reading and broadcast, after the load has
-- finished, and the start of the tick chain.
function Start()
    serial = serial + 1
    token = loadId .. serial
    started, closing = true, false
    ticks = 0
    lastTick = os.time()
    arm()
    local idle = sample(true)
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
-- game-mode unload Active is unchanged and nothing is sent. No tick runs
-- after this.
function Closing()
    closing = true
    if not Link then return end
    local settings = SKIN:GetVariable('SETTINGSPATH', '') .. 'Rainmeter.ini'
    local active = Link.activeOf(settings, SKIN:GetVariable('ROOTCONFIG', 'Parallax') .. '\\Idle')
    if active == 0 then broadcast(false, false) end
end
