-- The playback state every Media consumer reads, as [MeasureState]. It is the
-- provider's own state, except where "stopped" or "paused" contradicts the
-- provider's own position: while a YouTube tab casts to a TV, the browser's
-- local video is idle, so the WebNowPlaying extension reports Stopped or Paused
-- although the position it reports keeps advancing. A moving position reads
-- Playing; a position that then holds reads Paused. Nothing else is inferred: a
-- track that has not been seen moving keeps its reported state. No file I/O,
-- bangs, timers or network.
local ADVANCES, HOLDS = 2, 3 -- consecutive samples before the state changes
local reported, connection, title, position, maxStep
local inferred, lastTitle, lastPosition, advances, holds

local function reset()
    inferred, lastTitle, lastPosition, advances, holds = nil, nil, nil, 0, 0
end

function Initialize()
    connection = SKIN:GetMeasure('MeasureConnection')
    reported = SKIN:GetMeasure('MeasureReportedState')
    title = SKIN:GetMeasure('MeasureTitle')
    position = SKIN:GetMeasure('MeasurePosition')
    -- One sample may advance by about its own length; more than that is a seek.
    local seconds = (tonumber(SKIN:GetVariable('MediaInterval')) or 1000) / 1000
    maxStep = math.max(seconds, 1) * 2 + 1
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
    if name ~= lastTitle then
        reset()
        lastTitle, lastPosition = name, now
        return state
    end
    local step = now - lastPosition
    lastPosition = now
    if step == 0 then
        advances, holds = 0, holds + 1
        if inferred == 1 and holds >= HOLDS then inferred = 2 end
    elseif step > 0 and step <= maxStep then
        advances, holds = advances + 1, 0
        if advances >= ADVANCES then inferred = 1 end
    else
        advances, holds = 0, 0 -- a seek: keep what was already established
    end
    return inferred or state
end
