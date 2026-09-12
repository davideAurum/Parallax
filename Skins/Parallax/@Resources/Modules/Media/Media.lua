-- Original Parallax UI adapter. No file I/O, subprocesses, timers, or network.
-- Metadata stays bound to measures; it never becomes a bang or Lua command.
local measures, applied
local commands = {
    Previous = { measure = 'MeasureCanPrevious', meter = 'MeterPrevious', label = 'Previous track' },
    PlayPause = { measure = 'MeasureCanPlayPause', meter = 'MeterPlayPause', label = 'Play or pause' },
    Next = { measure = 'MeasureCanNext', meter = 'MeterNext', label = 'Next track' }
}

function Initialize()
    measures, applied = {}, {}
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
    local changed = group('MediaTrack', track)
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
    changed = meter('MeterArtworkLabel', not track and tonumber(SKIN:GetVariable('Columns')) == 2) or changed
    for _, command in pairs(commands) do
        local enabled = online and number(command.measure) == 1
        changed = option(command.meter, 'FontColor', SKIN:GetVariable(enabled and 'AccentColor' or 'MutedColor')) or changed
        changed = option(command.meter, 'MouseActionCursor', enabled and '1' or '0') or changed
        changed = option(command.meter, 'ToolTipText', command.label .. (enabled and ' (reported supported by player).' or ' unavailable: no connection or player does not report support.')) or changed
    end
    changed = option('MeterPlayPause', 'Text', online and state == 1 and '||' or '>') or changed
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

function Control(command)
    local spec = commands[command]
    -- Recheck the latest sampled values at click time; these are not a heartbeat.
    if spec and connected() and number(spec.measure) == 1 then
        SKIN:Bang('!CommandMeasure', 'MeasureConnection', command)
        return true
    end
    return false
end
