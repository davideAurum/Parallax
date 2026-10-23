-- Media spectrum drawer capture lease (docs/PERFORMANCE-REVIEW.md T2: VIS-01,
-- MEDIA-05, ENGINE-03; owner decision 1, 2026-10-22).
--
-- Rainmeter's AudioLevel keeps the Windows audio engine running for as long as
-- the drawer's capture measure exists, even in silence, and only unloading it
-- releases that. So after about 2 minutes of silence while you have been away
-- for 5 minutes, and no WebNowPlaying player reports Playing, this lease asks
-- MediaOptions.ApplyLease to reload Media into the capture-free "Capture
-- paused" drawer (Modules\Media\DrawerCapture1.inc). It resumes the capture on
-- your next input, when a player reports Playing, or on a click on the plot.
--
-- State: Modules\Media\CaptureState.inc MediaDrawerCapture (0 live, 1 paused,
-- 2 deferred), written only by MediaOptions.ApplyLease, which also reloads
-- Media once (without a provider resume) and so ends this script's load.
-- Input-idle: the Parallax\Idle coordinator's ParallaxIdleAway/Beat/Sync
-- broadcast (@Resources\Idle\Coordinator.lua, joined through Link.lua).
--
-- Never trusted blindly:
--   * nothing happens until the coordinator has synced this load
--     (ParallaxIdleSync=1), and parking needs a beat younger than 3 minutes;
--   * a paused drawer resumes ("fail-live") if no coordinator has synced 10 s
--     after the load, or if its beat goes 3 minutes stale; a gap in this
--     script's own schedule (sleep) re-arms that clock instead;
--   * at most one change is requested per load; MediaStandby=1 (the idle
--     stand-down) leaves everything to that feature.
-- Test hooks (staged copies only, absent from shipped files, honoured only
-- inside their bounds): MediaLeaseTestQuietSeconds (1-120) and
-- MediaLeaseTestStaleSeconds (5-180).

local QUIET_SECONDS = 120
local STALE_SECONDS = 180
local UNSYNCED_SECONDS = 10
local RETRY_SECONDS = 30

local link
local loadedCapture, loadedStandby
local loadAt, lastRun, rearmAt, quietSince, requestedAt
local updates, busy, rerun
local quietSeconds, staleSeconds, gapSeconds

local function variable(name, default)
    local value = SKIN:GetVariable(name, default)
    if value == nil then return default end
    return value
end

local function hook(name, low, high)
    local text = variable(name, '')
    if type(text) ~= 'string' or not text:match('^%s*%d+%s*$') then return nil end
    local number = tonumber(text)
    if number < low or number > high then return nil end
    return number
end

-- Loads the shared idle link; nil when it is missing (Rainmeter's dofile logs
-- an error for a missing file, so look first).
local function loadLink()
    local path = SKIN:GetVariable('@') .. 'Idle\\Link.lua'
    local file = io.open(path, 'rb')
    if not file then return nil end
    file:close()
    local ok, module = pcall(dofile, path)
    if not ok or type(module) ~= 'table' or type(module.new) ~= 'function' then return nil end
    return module.new(SKIN)
end

local function measureValue(name)
    local measure = SKIN:GetMeasure(name)
    if not measure then return nil end
    return measure:GetValue()
end

-- One lease change per load: MediaOptions writes, stamps and reloads.
local function request(capture, reason, now)
    requestedAt = now
    SKIN:Bang('!CommandMeasure', 'MeasureMediaOptions', string.format("ApplyLease(%d, nil, '%s')", capture, reason))
end

local function join(now)
    if link then link.join(now) end
end

function Initialize()
    link = loadLink()
    loadedCapture = variable('MediaDrawerCapture', '0')
    loadedStandby = variable('MediaStandby', '0')
    loadAt = os.time()
    lastRun, rearmAt, quietSince, requestedAt = nil, nil, nil, nil
    updates, busy, rerun = 0, false, false
    quietSeconds = hook('MediaLeaseTestQuietSeconds', 1, QUIET_SECONDS) or QUIET_SECONDS
    staleSeconds = hook('MediaLeaseTestStaleSeconds', 5, STALE_SECONDS) or STALE_SECONDS
    -- About twice this measure's own period (MediaInterval, 1 s), plus the
    -- whole-second resolution of os.time().
    local interval = tonumber(variable('MediaInterval', '1000')) or 1000
    gapSeconds = math.max(3, math.floor(2 * interval / 1000 + 1))
end

local function evaluate()
    local now = os.time()
    updates = updates + 1
    -- A gap in this script's own schedule means the computer slept: re-arm
    -- the staleness clock rather than calling the coordinator dead.
    if lastRun ~= nil and (now - lastRun > gapSeconds or now < lastRun) then rearmAt = now end
    lastRun = now
    if loadedStandby == '1' then return end
    -- The reload a request causes ends this load; retry only if it never came.
    if requestedAt ~= nil and now - requestedAt >= 0 and now - requestedAt < RETRY_SECONDS then return end

    local signal = measureValue('MeasureVisualizerState') == 2
    if signal then quietSince = nil elseif quietSince == nil then quietSince = now end
    local synced = variable('ParallaxIdleSync', '0') == '1'
    local away = variable('ParallaxIdleAway', '0') == '1'
    local beat = tonumber(variable('ParallaxIdleBeat', '0')) or 0
    local stale = now - math.max(beat, rearmAt or loadAt) > staleSeconds
    local playing = measureValue('MeasureState') == 1

    if loadedCapture == '2' then
        -- Nothing defers yet: a saved deferred state goes back to live.
        return request(0, 'reclaim', now)
    elseif loadedCapture == '1' then
        if synced and not away then return request(0, 'unpark', now) end
        if playing then return request(0, 'unpark', now) end
        if not synced and now - loadAt >= UNSYNCED_SECONDS then return request(0, 'fail-live', now) end
        if synced and stale then
            request(0, 'fail-live', now)
            return join(now)
        end
    else
        if synced and away and not stale and not playing and quietSince ~= nil and now - quietSince >= quietSeconds then
            return request(1, 'park', now)
        end
        if synced and stale then return join(now) end
    end
    -- Join after the load's own first update (the delayed ParallaxIdleJoin
    -- group update or the next regular one), as the last statement: the
    -- coordinator's first broadcast can re-enter this script inside it. The
    -- link allows one join per load and one re-join per 10 minutes.
    if not synced and updates > 1 then join(now) end
end

function Update()
    if busy then
        -- A broadcast arrived inside this script's own join: evaluate again
        -- once the outer pass has finished, never drop it.
        rerun = true
        return tonumber(loadedCapture) or 0
    end
    busy = true
    local passes = 0
    repeat
        rerun = false
        passes = passes + 1
        evaluate()
    until not rerun or passes >= 3
    busy = false
    return tonumber(loadedCapture) or 0
end

-- The paused plot's click target: back to live capture with one reload.
function Unpark(reason)
    if loadedCapture ~= '1' or loadedStandby == '1' then return false end
    request(0, 'unpark', os.time())
    return true
end
