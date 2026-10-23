-- Refresh-scope test roles; isolated test copies only.
-- probe: lives in the instrumented Global Settings and runs real meter actions.
-- driver: replays requested clicks into Settings, one per 100 ms tick.
-- other roles: passive witnesses that count their own loads.
-- os.clock is the CRT's wall clock since process start, shared by every skin.
local root, role, generation, steps, sequence
local reported = { 'MeterScaleInput', 'MeterGeometry', 'MeterBackgroundTransparencyInput', 'MeterBackgroundColorValue', 'MeterRefreshValue', 'MeterCadence' }
local function read(path)
    local file = io.open(path, 'rb'); if not file then return nil end
    local value = file:read('*a'); file:close(); return value
end
local function write(path, value)
    local file = assert(io.open(path, 'wb')); file:write(value); file:close()
end
local function append(path, value)
    local file = assert(io.open(path, 'ab')); file:write(value); file:close()
end
local function now() return string.format('%.3f', os.clock()) end
local function snapshot(path)
    local ok, result = pcall(function()
        local lines = { 'PASS', 'Generation='..generation, 'Clock='..now(), 'LastClick='..(read(root..'lastclick.txt') or '') }
        for _, name in ipairs({ 'Scale', 'BackgroundColor', 'MetricsInterval', 'SensorInterval', 'CapacityInterval', 'VisualizerInterval' }) do
            lines[#lines+1] = name..'Variable='..SKIN:GetVariable(name)
        end
        local bounds = assert(SKIN:GetMeter('MeterBounds'))
        lines[#lines+1] = 'Width='..bounds:GetW(); lines[#lines+1] = 'Height='..bounds:GetH()
        for _, name in ipairs(reported) do
            local meter = assert(SKIN:GetMeter(name))
            lines[#lines+1] = name..'='..meter:GetOption('Text', '')
            lines[#lines+1] = name..'Rows='..math.floor(meter:GetY())..','..math.floor(meter:GetY() + meter:GetH())
        end
        return table.concat(lines, '\n')..'\n'
    end)
    write(path, ok and result or ('FAIL\n'..tostring(result)..'\n'))
end
function Initialize()
    root = SELF:GetOption('ReportDirectory'); role = SELF:GetOption('Role', 'witness')
    assert(root ~= '', 'Missing private report directory')
    generation = (tonumber(read(root..role..'-generation.txt')) or 0) + 1
    write(root..role..'-generation.txt', tostring(generation))
    append(root..role..'-loads.txt', generation..'|'..now()..'\n')
    steps, sequence = {}, tonumber(read(root..'driver-sequence.txt')) or 0
end
function Update()
    if role ~= 'driver' then return 0 end
    if #steps == 0 then
        local request = read(root..'request.txt') or ''
        local nextSequence, list = request:match('^(%d+)|([%w:;]+)$')
        nextSequence = tonumber(nextSequence)
        if not nextSequence or nextSequence <= sequence then return 0 end
        sequence = nextSequence; write(root..'driver-sequence.txt', tostring(sequence))
        for step in list:gmatch('[^;]+') do steps[#steps+1] = step end
    end
    local step = table.remove(steps, 1)
    local meter = step:match('^click:(Meter%w+)$')
    if meter then
        SKIN:Bang('!CommandMeasure', 'SettingsProbe', "Click('"..meter.."')", 'Parallax\\Settings')
    elseif step == 'snap' then
        SKIN:Bang('!CommandMeasure', 'SettingsProbe', "Snapshot('result-"..sequence.."')", 'Parallax\\Settings')
    end
    return 0
end
-- probe: OnRefreshAction, after the meters have their final bounds.
function Ready() snapshot(root..'ready-'..generation..'.txt') end
function Snapshot(name) snapshot(root..name..'.txt') end
function Click(name)
    local meter = assert(SKIN:GetMeter(name), 'Unknown meter '..tostring(name))
    local action = meter:GetOption('LeftMouseUpAction', '')
    assert(action ~= '', name..' has no click action')
    append(root..'clicks.txt', name..'|'..action..'\n')
    write(root..'lastclick.txt', now())
    SKIN:Bang(action)
end
