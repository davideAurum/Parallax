-- Parallax idle stand-down hook (owner decision 2, 2026-10-22; docs/PERFORMANCE-
-- REVIEW.md T6: SHARED-01, ENGINE-08). Loaded only while Global Settings "Idle
-- pause" is on (@Resources\Idle\Hook5/10/30.inc -> Hook.inc), as the last
-- section of each utility skin.
--
-- The Parallax\Idle coordinator broadcasts ParallaxIdlePaused (1 after the
-- chosen minutes without keyboard or mouse input) with ParallaxIdleBeat and
-- ParallaxIdleSync, and forces this measure (group ParallaxIdleHook). This
-- script reconciles the skin with that level on every run:
--
--   in place (most skins): freeze. Module controllers' IdleEnter(), then
--     !PauseMeasureGroup ParallaxIdlePause, every repainting meter (group
--     ParallaxIdleFreeze) to UpdateDivider -1 with one forced update, and the
--     "Paused (idle)" line over the headline value. The skin then repaints
--     nothing until input. Leaving unpauses, runs IdleLeave(), forces fresh
--     samples before anything is shown, deletes the freeze dividers (the
--     style or skin default applies again), lets the controllers re-apply the
--     dividers they manage (ReapplyDividers) and the headline
--     (RestoreHeadline), then forces one meter pass and one paint.
--   refresh standby (ParallaxIdleStandbyMode=refresh: Media.ini, the
--     standalone Visualizer): when the wanted level differs from the one this
--     load was built with (ParallaxIdleStandbyState), one request to the
--     module's single writer (ParallaxIdleStandbyWriter "IdleStandby(n,
--     'reason')"), which saves the state and reloads the skin once. A load
--     built in standby then freezes in place as above.
--
-- Paints happen only in enter and leave (XMOD-04). Never trusted blindly:
--   * nothing happens until the coordinator has synced this load;
--   * a beat older than 3 minutes counts as no coordinator: a paused skin
--     leaves (fails live) and re-joins, rate-limited; a gap in this measure's
--     own schedule (sleep) re-arms that clock instead;
--   * a load built in standby with no sync 10 s after the load fails live.
-- Joining (Link.lua) happens once per load after the load's own first update,
-- as the last statement; a broadcast that re-enters during the join is
-- evaluated again once the outer pass finishes, never dropped.
--
-- Module controllers (ParallaxIdleControllers, Script measure names separated
-- by |) may define IdleEnter, IdleLeave, ReapplyDividers and RestoreHeadline;
-- a missing function is skipped. Test hooks (staged copies only, absent from
-- shipped files, honoured only inside their bounds):
-- ParallaxIdleTestStaleSeconds (5-180) and ParallaxIdleTestUnsyncedSeconds
-- (2-10).

local STALE_SECONDS = 180
local UNSYNCED_SECONDS = 10
local RETRY_SECONDS = 30

local link
local controllers, refreshMode, persisted, writer
local entered, loadAt, lastRun, rearmAt, requestedAt
local updates, busy, rerun
local staleSeconds, unsyncedSeconds, gapSeconds

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

-- The shared idle link; nil when it is missing (Rainmeter's dofile logs an
-- error for a missing file, so look first).
local function loadLink()
    local path = SKIN:GetVariable('@') .. 'Idle\\Link.lua'
    local file = io.open(path, 'rb')
    if not file then return nil end
    file:close()
    local ok, module = pcall(dofile, path)
    if not ok or type(module) ~= 'table' or type(module.new) ~= 'function' then return nil end
    return module.new(SKIN)
end

local function call(name)
    for _, controller in ipairs(controllers) do
        SKIN:Bang('!CommandMeasure', controller, 'if ' .. name .. ' then ' .. name .. '() end')
    end
end

local function enter()
    entered = true
    call('IdleEnter')
    SKIN:Bang('!PauseMeasureGroup', 'ParallaxIdlePause')
    SKIN:Bang('!SetOptionGroup', 'ParallaxIdleFreeze', 'UpdateDivider', '-1')
    SKIN:Bang('!UpdateMeterGroup', 'ParallaxIdleFreeze')
    SKIN:Bang('!ShowMeter', 'MeterParallaxPaused')
    SKIN:Bang('!UpdateMeter', 'MeterParallaxPaused')
    SKIN:Bang('!Redraw')
end

local function leave()
    entered = false
    SKIN:Bang('!UnpauseMeasureGroup', 'ParallaxIdlePause')
    call('IdleLeave')
    -- Fresh samples before any meter shows them.
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxIdlePause')
    -- Deleting the key restores the style or skin default divider.
    SKIN:Bang('!SetOptionGroup', 'ParallaxIdleFreeze', 'UpdateDivider', '')
    call('ReapplyDividers')
    SKIN:Bang('!UpdateMeterGroup', 'ParallaxIdleFreeze')
    SKIN:Bang('!HideMeter', 'MeterParallaxPaused')
    call('RestoreHeadline')
    SKIN:Bang('!Redraw')
end

-- Refresh standby: one request per load to the module's single writer, which
-- saves the level and reloads this skin (ending this load).
local function request(level, reason, now)
    if writer == '' then return end
    if requestedAt ~= nil and now - requestedAt >= 0 and now - requestedAt < RETRY_SECONDS then return end
    requestedAt = now
    SKIN:Bang('!CommandMeasure', writer, string.format("IdleStandby(%d, '%s')", level, reason))
end

local function join(now)
    if link then link.join(now) end
end

function Initialize()
    link = loadLink()
    controllers = {}
    for name in (variable('ParallaxIdleControllers', '') or ''):gmatch('[^|%s]+') do controllers[#controllers + 1] = name end
    refreshMode = variable('ParallaxIdleStandbyMode', '') == 'refresh'
    writer = refreshMode and (variable('ParallaxIdleStandbyWriter', '') or '') or ''
    persisted = refreshMode and variable('ParallaxIdleStandbyState', '0') == '1'
    entered = false
    loadAt = os.time()
    lastRun, rearmAt, requestedAt = nil, nil, nil
    updates, busy, rerun = 0, false, false
    staleSeconds = hook('ParallaxIdleTestStaleSeconds', 5, STALE_SECONDS) or STALE_SECONDS
    unsyncedSeconds = hook('ParallaxIdleTestUnsyncedSeconds', 2, UNSYNCED_SECONDS) or UNSYNCED_SECONDS
    -- About twice this measure's own nominal period (ParallaxIdleHookMs, 60 s;
    -- the entrypoint derives its divider from it) plus os.time()'s
    -- whole-second resolution. A longer silence is a sleep, not a dead
    -- coordinator.
    local period = tonumber(variable('ParallaxIdleHookMs', '60000')) or 60000
    gapSeconds = math.max(3, math.floor(2 * period / 1000 + 1))
end

local function evaluate()
    local now = os.time()
    updates = updates + 1
    if lastRun ~= nil and (now - lastRun > gapSeconds or now < lastRun) then rearmAt = now end
    lastRun = now
    local synced = variable('ParallaxIdleSync', '0') == '1'
    if not synced then
        -- A load built in standby never stays frozen without a coordinator.
        if persisted and now - loadAt >= unsyncedSeconds then request(0, 'fail-live', now) end
        -- Join after the load's own first update, as the last statement: the
        -- coordinator's first broadcast can re-enter this script inside it.
        if updates > 1 then join(now) end
        return
    end
    local beat = tonumber(variable('ParallaxIdleBeat', '0')) or 0
    local stale = now - math.max(beat, rearmAt or loadAt) > staleSeconds
    local want = variable('ParallaxIdlePaused', '0') == '1' and not stale
    if refreshMode and want ~= persisted then
        request(want and 1 or 0, stale and 'fail-live' or 'standby', now)
    elseif want and not entered then
        enter()
    elseif not want and entered then
        leave()
    end
    if stale then join(now) end
end

function Update()
    if busy then
        -- A broadcast arrived inside this script's own join or a controller
        -- call: evaluate again once the outer pass has finished.
        rerun = true
        return entered and 1 or 0
    end
    busy = true
    local passes, ok, message = 0, true, nil
    repeat
        rerun = false
        passes = passes + 1
        ok, message = pcall(evaluate)
    until not ok or not rerun or passes >= 3
    -- Always leave the guard open: a script error in one pass must not stop
    -- every later update of this load. Rainmeter still logs the error.
    busy = false
    if not ok then error(message, 0) end
    return entered and 1 or 0
end
