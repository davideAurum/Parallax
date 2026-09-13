-- Original Parallax UI adapter. No file I/O, subprocesses, timers, or network.
-- Metadata stays bound to measures; it never becomes a bang or Lua command.
local measures, applied, playPauseHovered, transportHovered, activeTiming
local emptyShape = 'Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0'
local playPauseShapes = {
    play = { 'Path LucideTransportPlayPath | Extend LucideTransportStroke', emptyShape, emptyShape },
    playOff = {
        'Path LucideTransportPlayOffUpperPath | Extend LucideTransportStroke',
        'Path LucideTransportPlayOffLowerPath | Extend LucideTransportStroke',
        'Path LucideTransportPlayOffSlashPath | Extend LucideTransportStroke'
    },
    stepForward = {
        'Path LucideTransportStepForwardPath | Extend LucideTransportStroke',
        'Path LucideTransportStepForwardBarPath | Extend LucideTransportStroke',
        emptyShape
    },
    pause = {
        'Rectangle (14*#Scale#),(3*#Scale#),(5*#Scale#),(18*#Scale#),#Scale# | Extend LucideTransportStroke',
        'Rectangle (5*#Scale#),(3*#Scale#),(5*#Scale#),(18*#Scale#),#Scale# | Extend LucideTransportStroke',
        emptyShape
    }
}
local commands = {
    Previous = { measure = 'MeasureCanPrevious', meter = 'MeterPrevious', label = 'Previous track' },
    PlayPause = { measure = 'MeasureCanPlayPause', meter = 'MeterPlayPause', label = 'Play or pause' },
    Next = { measure = 'MeasureCanNext', meter = 'MeterNext', label = 'Next track' }
}

function Initialize()
    measures, applied, playPauseHovered = {}, {}, false
    transportHovered, activeTiming = {}, nil
    local names = { 'MeasureConnection', 'MeasureTitle', 'MeasureCover', 'MeasureState',
        'MeasurePosition', 'MeasureDuration', 'MeasureCanPrevious', 'MeasureCanPlayPause', 'MeasureCanNext' }
    for _, name in ipairs(names) do measures[name] = SKIN:GetMeasure(name) end
end

local function number(name)
    local measure = measures[name]
    local value = measure and tonumber(measure:GetValue())
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function nonblank(name)
    local measure = measures[name]
    return measure and (measure:GetStringValue() or ''):find('%S') ~= nil
end

local function connected()
    return number('MeasureConnection') == 1
end

local function change(key, value, bang, ...)
    if applied[key] == value then return false end
    applied[key] = value
    SKIN:Bang(bang, ...)
    return true
end

local function option(meter, key, value)
    return change(meter .. ':' .. key, value, '!SetOption', meter, key, value)
end

local function group(name, visible)
    return change('group:' .. name, visible, visible and '!ShowMeterGroup' or '!HideMeterGroup', name)
end

local function meter(name, visible)
    return change('meter:' .. name, visible, visible and '!ShowMeter' or '!HideMeter', name)
end

function Update()
    local online = connected()
    local track = online and nonblank('MeasureTitle') or false
    local state = number('MeasureState')
    local duration, position = number('MeasureDuration'), number('MeasurePosition')
    local timeline = track and duration and duration > 0 and position and position >= 0 or false
    activeTiming = timeline and 'MeterTiming' or 'MeterTimingUnavailable'
    local trackChanged = group('MediaTrack', track)
    local changed = trackChanged
    changed = meter('MeterNoMedia', not track) or changed
    changed = group('MediaTimeline', timeline) or changed
    changed = meter('MeterTimingUnavailable', not timeline) or changed
    -- Cover and its label belong to MediaTrack; reapply after a group change.
    local cover = track and nonblank('MeasureCover') or false
    if applied.coverTrack ~= track then
        applied['meter:MeterCover'], applied['meter:MeterCoverLabel'] = nil, nil
        applied.coverTrack = track
    end
    changed = meter('MeterCover', cover) or changed
    changed = meter('MeterCoverLabel', track and not cover) or changed
    changed = meter('MeterArtworkPlaceholder', not track and tonumber(SKIN:GetVariable('Columns')) == 2) or changed
    changed = meter('MeterArtworkLabel', not track and tonumber(SKIN:GetVariable('Columns')) == 2) or changed
    for name, command in pairs(commands) do
        local enabled = online and number(command.measure) == 1
        local color = SKIN:GetVariable(enabled and 'AccentColor' or 'MutedColor')
        local fill = enabled and transportHovered[name] and color or '0,0,0,0'
        changed = option(command.meter, 'LucideTransportStroke', 'Fill Color ' .. fill .. ' | Stroke Color ' .. color
            .. ' | StrokeWidth (2*#Scale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset (2*#Scale#),#Scale#') or changed
        changed = option(command.meter, 'MouseActionCursor', enabled and '1' or '0') or changed
        changed = option(command.meter, 'ToolTipText', command.label .. (enabled and ' (reported supported by player).' or ' unavailable: no connection or player does not report support.')) or changed
    end
    local hovered = online and number('MeasureCanPlayPause') == 1 and playPauseHovered
    -- Artwork shows the reported state; hover previews the opposite action.
    -- Paused uses Step Forward to resume; playing uses Play Off to pause.
    local playPauseMode = online and state == 2 and (hovered and 'stepForward' or 'pause')
        or (hovered and 'playOff' or 'play')
    for index, shape in ipairs(playPauseShapes[playPauseMode]) do
        changed = option('MeterPlayPause', 'Shape' .. (index + 1), shape) or changed
    end
    -- Static metadata Shapes need their options rebuilt after hide/show changes.
    -- UpdateDivider=-1 keeps this work confined to track availability transitions.
    if trackChanged then SKIN:Bang('!UpdateMeterGroup', 'MediaTrack') end
    if changed then
        SKIN:Bang('!UpdateMeterGroup', 'MediaDynamic')
        SKIN:Bang('!Redraw')
    end
    if not online then return 'WNP disconnected' end
    if not track then return 'WNP idle' end
    if state == 1 then return 'Playing' end
    if state == 2 then return 'Paused' end
    if state == 0 then return 'Stopped' end
    return 'State unknown'
end

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function LayoutTransport(timingName)
    -- Only the active String meter calls this after its current text is measured.
    if timingName ~= activeTiming or (timingName ~= 'MeterTiming' and timingName ~= 'MeterTimingUnavailable') then return false end
    local timing = SKIN:GetMeter(timingName)
    if not timing then return false end
    local scale = finite(SKIN:GetVariable('Scale'))
    local left = finite(SKIN:ParseFormula(SKIN:ReplaceVariables('(#MediaTransportLeft#)')))
    local right = finite(SKIN:ParseFormula(SKIN:ReplaceVariables('(#ContentX#+#ContentWidth#)')))
    local timingLeft, timingWidth = finite(timing:GetX()), finite(timing:GetW())
    if not scale or scale <= 0 or not left or left < 0 or not right or right <= left
        or not timingLeft or not timingWidth or timingWidth <= 0
        or timingLeft + timingWidth > right + 1 then return false end
    local width = 92 * scale
    local space = timingLeft - left
    -- Normal timing is capped to reserve six pixels on each side; allow four
    -- at fractional pixel boundaries, and reject an impossible layout safely.
    if space < width + 8 * scale then return false end
    local gap = math.min(6 * scale, (space - width) / 2)
    local x = math.max(left + gap, math.min((left + timingLeft - width) / 2, timingLeft - gap - width))
    local changed = false
    for index, name in ipairs({ 'MeterPrevious', 'MeterPlayPause', 'MeterNext' }) do
        local position = tostring(math.floor(x + (index - 1) * 32 * scale + 0.5))
        changed = option(name, 'X', position) or changed
    end
    if changed then
        -- This group excludes timing meters, so layout callbacks cannot recurse.
        SKIN:Bang('!UpdateMeterGroup', 'MediaTransport')
        SKIN:Bang('!Redraw')
    end
    return changed
end

function HoverPlayPause(entered)
    if type(entered) ~= 'boolean' or playPauseHovered == entered then return false end
    playPauseHovered = entered
    -- Hover is display-only. Playback state changes only when WNP reports them.
    Update()
    return true
end

function HoverTransport(command, entered)
    if (command ~= 'Previous' and command ~= 'Next') or type(entered) ~= 'boolean'
        or (transportHovered[command] or false) == entered then return false end
    transportHovered[command] = entered
    Update()
    return true
end

function Control(command)
    local spec = commands[command]
    -- Recheck the latest sampled values at click time; these are not a heartbeat.
    if spec and connected() and number(spec.measure) == 1 then
        SKIN:Bang('!CommandMeasure', 'MeasureConnection', command)
        return true
    end
    return false
end
