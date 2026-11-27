-- The playback state every Media consumer reads, as [MeasureState]. It is the
-- provider's own state, except where "stopped" or "paused" contradicts the
-- provider's own position: while a YouTube tab casts to a TV, the browser's
-- local video is idle, so the WebNowPlaying extension reports Stopped or Paused
-- although the position it reports keeps advancing. A position that keeps pace
-- with the clock reads Playing; one that then holds reads Paused. The tab does
-- not update it evenly: it ticks for a few seconds, freezes for up to about 15,
-- then jumps by the time it missed. Nothing else is inferred: a track that has
-- not been seen moving keeps its reported state. No file I/O, bangs, timers or
-- network.
-- ADVANCES position changes that match the clock (within TOLERANCE seconds) read
-- as playing; HOLD seconds without a change read as paused. For EXPECT seconds
-- after Media itself sends Pause, QUICK seconds are enough.
local ADVANCES, TOLERANCE, HOLD = 2, 2, 20
local QUICK, EXPECT = 3, 10
local reported, connection, title, position
local inferred, lastTitle, lastPosition, changedAt, advances, pausedAt

local function reset()
    inferred, lastTitle, lastPosition, changedAt, advances, pausedAt = nil, nil, nil, nil, 0, nil
end

-- Media.lua calls this after sending Pause. It shows nothing by itself: the
-- position still has to stop.
function ExpectPause()
    pausedAt = os.time()
end

function Initialize()
    connection = SKIN:GetMeasure('MeasureConnection')
    reported = SKIN:GetMeasure('MeasureReportedState')
    title = SKIN:GetMeasure('MeasureTitle')
    position = SKIN:GetMeasure('MeasurePosition')
    reset()
end

local function number(measure)
    local value = measure and tonumber(measure:GetValue())
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function Update()
    local state = number(reported)
    local name = title and title:GetStringValue() or ''
    local now = number(position)
    if (state ~= 0 and state ~= 2) or number(connection) ~= 1 or not name:find('%S') or not now or now < 0 then
        reset()
        return state or 0
    end
    local clock = os.time()
    if name ~= lastTitle then
        reset()
        lastTitle, lastPosition, changedAt = name, now, clock
        return state
    end
    local step, elapsed = now - lastPosition, clock - changedAt
    if pausedAt and clock - pausedAt > EXPECT then pausedAt = nil end
    if step == 0 then
        if pausedAt and inferred == 1 and math.min(elapsed, clock - pausedAt) >= QUICK then
            inferred, advances, pausedAt = 2, 0, nil
        end
        if elapsed >= HOLD then
            advances = 0
            if inferred == 1 then inferred = 2 end
        end
    else
        lastPosition, changedAt = now, clock
        if step > 0 and math.abs(step - elapsed) <= TOLERANCE then
            advances = advances + 1
            if advances >= ADVANCES then inferred = 1 end
        else
            advances = 0 -- a seek: keep what was already established
        end
    end
    return inferred or state
end
