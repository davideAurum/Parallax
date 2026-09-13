-- Original Parallax presentation logic. No polling processes, file writes,
-- provider installation, history cache, or assumption of adapter-total usage.
local measures, previous
local infoComplete, infoDeadline
-- The telemetry controller exclusively owns all sensor values and sources.

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
    if not finite(value) or value < 0 or value > 100 then
        return '--', 'Invalid counter', 'The GPU engine counter did not return a usable value in the 0-100% range.'
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

local function memoryOverview(parts, reason)
    if not parts then
        return {'VRAM unavailable', reason or 'No discrete GPU memory information was returned.'}
    end
    local bytes = parts[2]:match('^%d+$') and tonumber(parts[2])
    local capacity, detail = 'VRAM unknown', 'The driver did not return a usable memory capacity.'
    if finite(bytes) and bytes > 0 and bytes <= 9007199254740991 then
        if parts[5] == 'PHYSICAL' then
            capacity = string.format('%.0f MB', bytes / 1048576)
            detail = 'Total physical video memory reported by the graphics driver: ' .. parts[2] .. ' bytes (' .. capacity .. ').'
        else
            capacity = string.format('%.1f GiB', bytes / 1073741824)
            detail = 'Windows-reported dedicated adapter memory: ' .. parts[2] .. ' bytes (' .. capacity .. '). Physical framebuffer capacity was unavailable; this may exclude driver-reserved memory.'
        end
    end
    local memoryType = parts[3] ~= '?' and trim(parts[3]) or ''
    local vendor = parts[4] ~= '?' and trim(parts[4]) or ''
    local label = memoryType ~= '' and memoryType or '/ type unknown'
    detail = detail .. (memoryType ~= '' and (' Memory type: ' .. memoryType .. '.')
        or ' Memory type was not exposed by a supported driver interface.')
    if vendor ~= '' then detail = detail .. ' Memory manufacturer: ' .. vendor .. '.' end
    return {capacity .. ' ' .. label, detail .. ' Read from this detected GPU at load or refresh; no saved card specifications.'}
end

local function clockOverview(parts)
    local function frequency(index)
        local raw = parts and parts[index] or '?'
        local khz = raw:match('^%d+$') and tonumber(raw)
        if not finite(khz) or khz <= 0 or khz > 4294967295 then return '--', nil end
        local mhz = string.format('%.3f', khz / 1000):gsub('0+$', ''):gsub('%.$', '')
        return mhz, raw
    end
    local base, baseRaw = frequency(6)
    local boost, boostRaw = frequency(7)
    local tip = 'Format: memory @ base clock (boost clock). Graphics clocks reported by the selected GPU driver at load or refresh. '
        .. (baseRaw and ('Base: ' .. baseRaw .. ' kHz. ') or 'Base clock unavailable. ')
        .. (boostRaw and ('Boost: ' .. boostRaw .. ' kHz. ') or 'Boost clock unavailable. ')
        .. 'These are base/boost specifications, not the current clock or a measured peak. Actual boost varies with operating conditions.'
    return {' @ ' .. base .. ' MHz (' .. boost .. ' MHz)', tip}
end

local function adapterInfo()
    if infoComplete then return nil end
    local source = measure('MeasureGPUInfo')
    local status = source and source:GetValue() or 103
    if (status == -1 or status == 0) and os.time() < infoDeadline then return nil end
    infoComplete = true
    local result = source and read('MeasureGPUInfo') or ''
    -- The selected adapter identity is separate from overview metadata.
    local metadata = result:match('^(.-)\r?\nGPU_ADAPTER|1|[^\r\n]*$')
    if metadata then result = metadata
    elseif result:find('\nGPU_ADAPTER|', 1, true) then result = 'UNAVAILABLE' end
    -- Seven payload fields: model, memory data/scope and base/boost graphics kHz.
    local parts = {result:match('^OK|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$')}
    local name = status == 1 and parts[1] or nil
    if name and trim(name) ~= '' and (parts[5] == 'PHYSICAL' or parts[5] == 'DEDICATED') then
        return name, name .. '. Windows high-performance selection among hardware adapters reported as non-integrated. Memory and base/boost clocks describe this GPU. Refreshed at skin load; the activity counter still spans all GPUs.', memoryOverview(parts), clockOverview(parts)
    end
    if status == 1 and result == 'NONE' then
        return 'No discrete GPU found', 'Windows DXCore exposed no compatible discrete graphics adapter. Integrated and software adapters are excluded.', memoryOverview(nil, 'No compatible discrete GPU was selected; memory information is unavailable.'), clockOverview(nil)
    end
    if status == 1 and result == 'AMBIGUOUS' then
        return 'Multiple discrete GPUs', 'Multiple discrete graphics adapters were found, but Windows could not rank their performance. No arbitrary adapter was selected.', memoryOverview(nil, 'Windows could not select a preferred discrete GPU; memory information is unavailable.'), clockOverview(nil)
    end
    return 'GPU name unavailable', 'Discrete GPU identification failed or is unsupported. Requires Windows DXCore and a compatible graphics driver. Refresh to retry; integrated graphics are never substituted.', memoryOverview(nil, 'Discrete GPU identification failed or timed out; memory information is unavailable. Refresh to retry.'), clockOverview(nil)
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
    local adapterName, adapterTip, adapterMemory, adapterClocks = adapterInfo()
    if adapterName then
        assign('MeterAdapterName', 'Text', adapterName)
        assign('MeterAdapterName', 'ToolTipText', adapterTip)
        assign('MeterVRAMValue', 'Text', adapterMemory[1] .. adapterClocks[1])
        assign('MeterVRAMValue', 'ToolTipText', adapterMemory[2] .. ' ' .. adapterClocks[2])
    end
    local value, _, tip = activity()
    assign('MeterActivityValue', 'Text', value)
    assign('MeterActivityValue', 'ToolTipText', tip)

    if changed then
        SKIN:Bang('!UpdateMeterGroup', 'GPUReadout')
        SKIN:Bang('!Redraw')
    end
    return 0
end
