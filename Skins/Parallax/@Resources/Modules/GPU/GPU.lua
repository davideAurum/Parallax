-- Original Parallax presentation logic. No polling processes, file writes,
-- provider installation, history cache, or assumption of adapter-total usage.
local measures, previous
local infoComplete, infoDeadline
local fields = {'Temperature', 'Power', 'Clock'}
local capabilityFields = {'VRAM', 'Direct3D', 'Shader', 'RayTracing', 'Driver'}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

-- Provider text is data, never Rainmeter option syntax or an action.
local function display(value)
    return trim(value):gsub('[%c]', ' '):gsub('#', '')
        :gsub('%[', '('):gsub('%]', ')'):gsub('"', "'")
end

local function measure(name)
    if not measures[name] then measures[name] = SKIN:GetMeasure(name) end
    return measures[name]
end

local function read(name)
    local source = measure(name)
    return source and trim(source:GetStringValue()) or ''
end

local function variable(name, fallback)
    return trim(SKIN:GetVariable(name, fallback or ''))
end

local function finite(number)
    return number and number == number and number ~= math.huge and number ~= -math.huge
end

local function set(meter, option, value)
    local key = meter .. ':' .. option
    value = display(value)
    if previous[key] ~= value then
        previous[key] = value
        SKIN:Bang('!SetOption', meter, option, value)
        return true
    end
    return false
end

local function activity()
    local source = measure('MeasureGPUActivity')
    if not source then return '--', 'Counter unavailable', 'UsageMonitor measure unavailable.' end
    local name = read('MeasureGPUActivity')
    local value = source:GetValue()
    -- Index=1 has no name at zero. Do not turn a missing counter into 0%.
    if name == '' or name == '0' or value == 0 then
        return '--', 'Idle / unavailable', 'No ranked observation: idle, starting up, unsupported driver, or missing counter. These cannot be distinguished here.'
    end
    if not finite(value) or value < 0 then
        return '--', 'Invalid counter', 'The GPU engine counter did not return a usable positive value.'
    end
    local pid = name:match('^pid_(%d+)_')
    local engine = name:match('_engtype_(.+)$')
    -- Refuse a renamed / merged process result: our scope depends on keeping
    -- one raw process-adapter-engine instance, including its adapter LUID.
    if not pid or not name:find('_luid_', 1, true) or not name:match('_eng_%d+_') then
        return '--', 'Unsupported counter format', 'Expected a raw PID / adapter / engine instance. Received: ' .. name
    end
    local detail = 'PID ' .. pid .. (engine and (' / ' .. engine) or '')
    local formatted = value < 0.1 and '<0.1%' or string.format('%.1f%%', value)
    return formatted, detail, 'Peak process-engine instance across exposed GPUs: ' .. name .. '. Counter sample age is not exposed; collection failures may retain an older observation.'
end

local function sensor(field, names)
    local prefix = 'GPU' .. field
    local index = variable(prefix .. 'Index', '-1')
    local expectedSensor = variable(prefix .. 'Sensor')
    local expectedLabel = variable(prefix .. 'Label')
    if index == '-1' or index == '' or expectedSensor == '' or expectedLabel == '' then
        return 'Unmapped', 'Set ' .. prefix .. 'Index, ' .. prefix .. 'Sensor and ' .. prefix .. 'Label in GPU.inc.'
    end
    if not index:match('^%d+$') then
        return 'Check mapping', 'The export index must be a non-negative integer copied from HWiNFO.'
    end
    for _, suffix in ipairs({'Sensor', 'Label', 'Value', 'ValueRaw'}) do
        if not names[(suffix .. index):lower()] then
            return 'Unavailable', 'Missing registry export ' .. suffix .. index .. '. Check the hive, key and Gadget export selection.'
        end
    end
    local actualSensor = read('Measure' .. prefix .. 'Sensor')
    local actualLabel = read('Measure' .. prefix .. 'Label')
    if actualSensor ~= expectedSensor or actualLabel ~= expectedLabel then
        return 'Check mapping', 'Export identity changed. Expected: ' .. expectedSensor .. ' / ' .. expectedLabel .. '. Received: ' .. actualSensor .. ' / ' .. actualLabel
    end
    local raw = tonumber(read('Measure' .. prefix .. 'ValueRaw'))
    local formatted = read('Measure' .. prefix .. 'Value')
    -- Formatted ValueN carries HWiNFO's unit. Bare numeric fallback is not a
    -- complete formatted sensor export; raw zero itself IS a valid reading.
    if not finite(raw) or formatted == '' or tonumber(formatted) or not formatted:find('%d') then
        return 'Unavailable', 'The export has no usable numeric value and formatted unit. Verify HWiNFO sensor reporting.'
    end
    return formatted, actualSensor .. ' / ' .. actualLabel .. ': ' .. formatted .. ' / registry snapshot; sample age unknown.'
end

local function capabilities(parts, reason)
    local result = {}
    for _, field in ipairs(capabilityFields) do
        result[field] = {'Unknown', reason or 'Windows did not return this capability for the named GPU. Refresh to retry.'}
    end
    if not parts then return result end
    local bytes = parts[2]:match('^%d+$') and tonumber(parts[2])
    if finite(bytes) and bytes >= 0 and bytes <= 9007199254740991 then
        local gib = bytes / 1073741824
        local value = string.format('%.1f', gib):gsub('%.0$', '') .. ' GiB'
        result.VRAM = {value, 'Dedicated video memory capacity: ' .. parts[2] .. ' bytes (' .. value .. '). Excludes shared system memory; this is capacity, not current usage or an available-memory budget.'}
    end
    if parts[3]:match('^%d%d%.%d$') then
        local level = parts[3]:gsub('%.', '_')
        result.Direct3D = {'FL ' .. level, 'Highest Direct3D feature level reported for this GPU and driver: ' .. level .. '. Feature levels describe functionality, not an installed DirectX version or a performance rating.'}
    end
    if parts[4]:match('^%d+%.%d+$') then
        result.Shader = {parts[4], 'Highest shader model reported by this GPU with the installed Windows Direct3D 12 runtime and driver: ' .. parts[4] .. '.'}
    end
    if parts[5] == 'NONE' then
        result.RayTracing = {'Unsupported', 'The Direct3D 12 device explicitly reports no DirectX ray-tracing support. This is the installed driver/runtime capability.'}
    elseif parts[5]:match('^%d+%.%d+$') then
        result.RayTracing = {'DXR ' .. parts[5], 'DirectX ray-tracing API tier ' .. parts[5] .. ' is supported by this GPU and driver. This does not identify dedicated ray-tracing cores or predict ray-tracing performance.'}
    end
    if parts[6]:match('^%d+%.%d+%.%d+%.%d+$') then
        result.Driver = {parts[6], 'Windows graphics driver version: ' .. parts[6] .. '. This may differ from the vendor package version. Refreshed at skin load or refresh.'}
    end
    return result
end

local function adapterInfo()
    if infoComplete then return nil end
    local source = measure('MeasureGPUInfo')
    local status = source and source:GetValue() or 103
    if (status == -1 or status == 0) and os.time() < infoDeadline then return nil end
    infoComplete = true
    local result = source and read('MeasureGPUInfo') or ''
    -- Six payload fields, with ? for an individually unavailable capability.
    local parts = {result:match('^OK|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$')}
    local name = status == 1 and parts[1] or nil
    if name and trim(name) ~= '' then
        return name, name .. '. Windows high-performance selection among hardware adapters reported as non-integrated. Capabilities describe this GPU with its installed driver. Refreshed at skin load; the activity counter still spans all GPUs.', capabilities(parts)
    end
    if status == 1 and result == 'NONE' then
        return 'No discrete GPU found', 'Windows DXCore exposed no compatible discrete graphics adapter. Integrated and software adapters are excluded.', capabilities(nil, 'No compatible discrete GPU was selected; capabilities are unavailable.')
    end
    if status == 1 and result == 'AMBIGUOUS' then
        return 'Multiple discrete GPUs', 'Multiple discrete graphics adapters were found, but Windows could not rank their performance. No arbitrary adapter was selected.', capabilities(nil, 'Windows could not select a preferred discrete GPU; capabilities are unavailable.')
    end
    return 'GPU name unavailable', 'Discrete GPU identification failed or is unsupported. Requires Windows DXCore and a compatible graphics driver. Refresh to retry; integrated graphics are never substituted.', capabilities(nil, 'Discrete GPU identification failed or timed out; capabilities are unavailable. Refresh to retry.')
end

function Initialize()
    measures = {}
    previous = {}
    infoComplete = false
    infoDeadline = os.time() + 14
end

function Update()
    local changed = false
    local function assign(meter, option, value)
        changed = set(meter, option, value) or changed
    end
    local adapterName, adapterTip, adapterCapabilities = adapterInfo()
    if adapterName then
        assign('MeterAdapterName', 'Text', adapterName)
        assign('MeterAdapterName', 'ToolTipText', adapterTip)
        for _, field in ipairs(capabilityFields) do
            assign('Meter' .. field .. 'Value', 'Text', adapterCapabilities[field][1])
            assign('Meter' .. field .. 'Value', 'ToolTipText', adapterCapabilities[field][2])
        end
    end
    local value, detail, tip = activity()
    assign('MeterActivityValue', 'Text', value)
    assign('MeterActivityDetail', 'Text', detail)
    assign('MeterActivityValue', 'ToolTipText', tip)
    assign('MeterActivityDetail', 'ToolTipText', tip)

    local enabled = variable('GPUEnableSensors', '0') == '1'
    local names = {}
    if enabled then
        for name in read('MeasureGPURegistryNames'):gmatch('[^|]+') do
            names[trim(name):lower()] = true
        end
    end
    for _, field in ipairs(fields) do
        local text, tooltip = 'Off', 'Optional HWiNFO registry sensor reads are disabled. Edit GPU.inc to map and enable them.'
        if enabled then text, tooltip = sensor(field, names) end
        assign('Meter' .. field .. 'Value', 'Text', text)
        assign('Meter' .. field .. 'Value', 'ToolTipText', tooltip)
    end
    assign('MeterSensorStatus', 'Text', enabled and 'Snapshot / age unknown' or 'Sensors off / use gear')
    if changed then
        SKIN:Bang('!UpdateMeterGroup', 'GPUReadout')
        SKIN:Bang('!Redraw')
    end
    return 0
end
