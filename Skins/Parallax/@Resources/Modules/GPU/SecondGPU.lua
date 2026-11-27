-- Original Parallax second-GPU section (GPU Settings Second GPU). Reads the
-- second GPU's samples that the one telemetry host writes beside its main
-- snapshot (<session>.second, GPU_SECOND|1; DriverTemperature.cs.txt) and
-- shows them between the memory rows and the process table. No process, no polling command, no
-- writes except Rainmeter options. Temperature.lua tells this measure which
-- session file to read (Session), and nothing at all while Second GPU is Off.
local mode, path, token, interval, lastSequence, shown, block, previous, geometry, nameText
-- The collapsed panel's numbers at load: Rainmeter expands nested variables
-- when it reads them, so the section recomputes the derived heights itself.
local base

local function trim(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
local function finite(value) return value and value == value and value ~= math.huge and value ~= -math.huge end
local function integer(value, low, high)
    if type(value) ~= 'string' or not value:match('^%d+$') or #value > 16 then return nil end
    local number = tonumber(value)
    if not finite(number) or number < low or number > high then return nil end
    return number
end
local function hex(value, length) return type(value) == 'string' and #value == length and not value:find('[^%x]') end
local function split(value)
    local fields = {}
    for field in (value .. '|'):gmatch('(.-)|') do fields[#fields + 1] = field end
    return fields
end
-- Hex-encoded UTF-8 with no control characters; nil for anything else.
local function unhex(value)
    if type(value) ~= 'string' or #value == 0 or #value % 2 ~= 0 or #value > 2048 or value:find('[^%x]') then return nil end
    local decoded = value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end)
    if decoded:find('[%z\1-\31\127]') then return nil end
    return decoded
end

-- Provider text is data, never Rainmeter option syntax.
local function assign(meter, option, value)
    if option ~= 'Shape2' then
        value = trim(value):gsub('%c', ' '):gsub('#', ''):gsub('%[', '('):gsub('%]', ')'):gsub('"', "'")
    end
    local key = meter .. ':' .. option
    if previous[key] ~= value then
        previous[key] = value
        SKIN:Bang('!SetOption', meter, option, value)
    end
end
local function text(meter, value) assign(meter, 'Text', value) end

-- Bar geometry changes only with a refresh, so it is resolved once per load.
local function dimension(name)
    if geometry[name] then return geometry[name] end
    local raw = SKIN:GetVariable(name, '0')
    local value = tonumber(raw)
    if not value then
        local ok, resolved = pcall(function() return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(raw) .. ')') end)
        if ok then value = resolved end
    end
    geometry[name] = type(value) == 'number' and finite(value) and value > 0 and value <= 1000000 and value or 0
    return geometry[name]
end
local function bar(meter, fraction)
    local width, thickness = dimension('GPUEngineBarWidth'), dimension('DataBarThicknessPx')
    local endpoint, stroke = 0, 0
    if fraction and fraction > 0 and width > 0 and thickness > 0 then
        endpoint, stroke = width * math.min(1, fraction), thickness
    end
    assign(meter, 'Shape2', string.format('Line 0,%.3f,%.3f,%.3f | StrokeWidth %.3f | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat', thickness / 2, endpoint, thickness / 2, stroke))
end

-- Decimal units, as the rest of GPU Meter: 1 GB = 1,000,000,000 bytes.
local function usedOfTotal(used, total)
    local divisor, unit = total >= 1000000000000 and 1000000000000 or 1000000000, total >= 1000000000000 and 'TB' or 'GB'
    return string.format('%.1f/%.1f %s', used / divisor, total / divisor, unit)
end

local function number(name)
    local ok, value = pcall(function() return SKIN:ParseFormula(SKIN:GetVariable(name, '')) end)
    return ok and type(value) == 'number' and finite(value) and value or nil
end
local function readBase()
    local values = {panel = number('PanelHeightPx'), window = number('WindowHeight'),
        natural = number('GPUNaturalHeight'), minimum = number('GPUPanelMinimum'), scale = number('Scale')}
    for _, value in pairs(values) do if not value then return nil end end
    if values.scale <= 0 or values.panel <= 0 then return nil end
    return values
end

-- Opens or collapses the section: the section height and the variables
-- derived from it, then one re-read of the panel, bounds and rows (the
-- GPUSecondLayout group), shown or hidden; DynamicWindowSize lets the window
-- follow. PanelHeightPx keeps GPU.ini's rule, Round(Max(minimum, natural) *
-- Scale), with the section added to the natural height.
local function layout(open)
    -- 24 px for One line, 56 for Rows: rows of 16 px with 8 px either side.
    local height = open and (mode >= 2 and 56 or 24) or 0
    if height == block or not base then return end
    block, shown = height, open
    local panel = math.floor(math.max(base.minimum, base.natural + height) * base.scale + 0.5)
    SKIN:Bang('!SetVariable', 'GPUSecondBlock', tostring(height))
    SKIN:Bang('!SetVariable', 'GPUSecondShown', height > 0 and '1' or '0')
    SKIN:Bang('!SetVariable', 'GPUSecondRowsShown', height > 24 and '1' or '0')
    SKIN:Bang('!SetVariable', 'GPUNaturalHeight', tostring(base.natural + height))
    SKIN:Bang('!SetVariable', 'PanelHeightPx', tostring(panel))
    SKIN:Bang('!SetVariable', 'WindowHeight', tostring(base.window + panel - base.panel))
    -- The process cells keep their own group (GPUProcessGraph) and move with it.
    for _, group in ipairs({'GPUSecondLayout', 'GPUProcessGraph'}) do
        SKIN:Bang('!SetOptionGroup', group, 'DynamicVariables', '1')
        SKIN:Bang('!UpdateMeterGroup', group)
        SKIN:Bang('!SetOptionGroup', group, 'DynamicVariables', '0')
    end
    if open then
        SKIN:Bang('!ShowMeterGroup', 'GPUSecondLine')
        if mode >= 2 then SKIN:Bang('!ShowMeterGroup', 'GPUSecondRows') end
        if mode == 3 then SKIN:Bang('!ShowMeterGroup', 'GPUSecondTrace') end
    else
        SKIN:Bang('!HideMeterGroup', 'GPUSecondLine')
        SKIN:Bang('!HideMeterGroup', 'GPUSecondRows')
        SKIN:Bang('!HideMeterGroup', 'GPUSecondTrace')
    end
    SKIN:Bang('!UpdateMeterGroup', 'GPUSecondLayout')
    SKIN:Bang('!Redraw')
end

local function blank()
    text('MeterGPUSecondLoad', '--')
    if mode >= 2 then
        text('MeterGPUSecondVideoValue', '--'); bar('MeterGPUSecondVideoBar', nil)
        text('MeterGPUSecondMemoryValue', '--')
    end
end

-- One History point per new second-GPU sample, like the main trace: the load
-- while it reads, 0 while it does not, nothing while it is starting.
local function plot(value)
    if mode ~= 3 or not shown then return end
    SKIN:Bang('!SetOption', 'MeasureGPUSecondHistory', 'Formula', tostring(value))
    SKIN:Bang('!UpdateMeasure', 'MeasureGPUSecondHistory')
    SKIN:Bang('!UpdateMeter', 'MeterGPUSecondGraph')
end

-- The section shows the parsed fields of one valid, current sample; nil when
-- the file is missing, malformed, from another session or stale.
local function readSample(now)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local output = file:read(8193); file:close()
    if not output or #output > 8192 then return nil end
    local f = split(trim(output))
    local sequence, epoch = integer(f[4], 0, 9007199254740991), integer(f[5], 1, 9007199254740991)
    if #f ~= 14 or f[1] ~= 'GPU_SECOND' or f[2] ~= '1' or f[3] ~= token or not sequence or not epoch
        or epoch > now + 5 or now - epoch > math.max(8, 3 * interval / 1000 + 2) then return nil end
    return f, sequence
end

local function render(f)
    local status = f[6]
    if status == 'NONE' or status == 'UNSUPPORTED' or status == 'DEVICE_CHANGED' then
        -- No second hardware GPU (or it went away): the panel is today's.
        layout(false); return
    end
    if status ~= 'OK' then
        if shown then blank() end
        return
    end
    if not hex(f[7], 16) or (f[8] ~= 'D' and f[8] ~= 'I') then
        if shown then blank() end
        return
    end
    local name = f[9] ~= '?' and unhex(f[9]) or nil
    nameText = name and trim(name) ~= '' and trim(name) or (f[8] == 'I' and 'Integrated GPU' or 'Second GPU')
    text('MeterGPUSecondName', nameText)
    layout(true)
    local core, video = integer(f[11], 0, 100), integer(f[12], 0, 100)
    local loadOK = f[10] == 'OK'
    text('MeterGPUSecondLoad', loadOK and core and (tostring(core) .. '%') or '--')
    if mode >= 2 then
        text('MeterGPUSecondVideoValue', loadOK and video and (tostring(video) .. '%') or '--')
        bar('MeterGPUSecondVideoBar', loadOK and video and video / 100 or nil)
        text('MeterGPUSecondMemoryLabel', f[8] == 'I' and 'Shared' or 'VRAM')
        local total, used = integer(f[13], 1, 9007199254740991), integer(f[14], 0, 9007199254740991)
        text('MeterGPUSecondMemoryValue', total and used and used <= total and usedOfTotal(used, total) or '--')
    end
    return loadOK and core or (f[10] ~= 'STARTING' and 0 or nil)
end

function Initialize()
    local value = trim(SELF:GetOption('Mode', '1'))
    mode = (value == '1' or value == '2' or value == '3') and tonumber(value) or 0
    path, token, lastSequence, shown, block = nil, nil, -1, false, 0
    previous, geometry, nameText = {}, {}, nil
    base = mode ~= 0 and readBase() or nil
    interval = math.max(1000, tonumber(SKIN:GetVariable('MetricsInterval', '1000')) or 1000,
        tonumber(SKIN:GetVariable('SensorInterval', '2000')) or 2000)
    if not finite(interval) then interval = 2000 end
    interval = math.floor(math.min(30000, interval))
end

-- Temperature.lua passes the hex-encoded path of its accepted session's main
-- snapshot, or '' when that session ends. Only <TMP or TEMP>\Parallax-GPU-
-- <32 hex>.dat is accepted; the second file is its .second sibling.
local function normalize(value) return value:gsub('/', '\\'):gsub('\\+$', ''):lower() end
function Session(pathHex)
    if mode == 0 then return end
    path, token, lastSequence = nil, nil, -1
    local decoded = pathHex ~= '' and unhex(pathHex) or nil
    if not decoded then
        if shown then blank() end
        return
    end
    local root, found = decoded:match('^(.+)[\\/]Parallax%-GPU%-(%x+)%.dat$')
    if not root or not hex(found, 32) or decoded:find('..', 1, true) then return end
    local matched = false
    for _, key in ipairs({'TMP', 'TEMP'}) do
        local expected = os.getenv(key)
        if expected and normalize(root) == normalize(expected) then matched = true end
    end
    if not matched then return end
    path, token = decoded:sub(1, -5) .. '.second', found
end

function Update()
    if mode == 0 then return 0 end
    if not path then return 0 end
    local now = os.time()
    local f, sequence = readSample(now)
    if not f then
        if shown then blank() end
        return 0
    end
    local point = render(f)
    if sequence > lastSequence then
        lastSequence = sequence
        if point then plot(point) end
    end
    return 0
end
