-- Original Parallax presentation logic for the adapter inset. No polling
-- processes, file writes, provider installation, history cache, or assumption
-- of adapter-total usage. The telemetry controller (Temperature.lua)
-- exclusively owns every live reading, including the header figure.
local measures, previous
local infoComplete, infoDeadline

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

-- Decimal units (1 GB = 1,000,000,000 bytes) with one decimal, the same
-- convention as Memory Meter's module and RAM:/PAGE: readings and Disk Meter:
-- an 8589803520-byte framebuffer reads 8.6 GB, the DXCore dedicated fallback
-- of 8450473984 bytes reads 8.5 GB.
local function capacity(bytes)
    if bytes >= 1000000000 then return string.format('%.1f GB', bytes / 1000000000) end
    return string.format('%.0f MB', bytes / 1000000)
end

-- PHYSICAL and DEDICATED-fallback capacities read alike; the memory
-- manufacturer field is part of the payload but is not displayed.
local function memoryOverview(parts)
    if not parts then return 'VRAM unavailable' end
    local bytes = parts[2]:match('^%d+$') and tonumber(parts[2])
    local size = 'VRAM unknown'
    if finite(bytes) and bytes > 0 and bytes <= 9007199254740991 then size = capacity(bytes) end
    local memoryType = parts[3] ~= '?' and trim(parts[3]) or ''
    return size .. (memoryType ~= '' and (' ' .. memoryType) or ' (type unknown)')
end

local function clockOverview(parts)
    local function frequency(index)
        local raw = parts and parts[index] or '?'
        local khz = raw:match('^%d+$') and tonumber(raw)
        if not finite(khz) or khz <= 0 or khz > 4294967295 then return nil end
        -- Whole MHz keeps the decimal details line inside the inset at the
        -- default width.
        return string.format('%.0f', khz / 1000)
    end
    local base, boost = frequency(6), frequency(7)
    if base and boost then return ' @ ' .. base .. '-' .. boost .. ' MHz' end
    if base then return ' @ ' .. base .. ' MHz base' end
    if boost then return ' @ ' .. boost .. ' MHz boost' end
    return ' @ -- MHz'
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
        return name, memoryOverview(parts) .. clockOverview(parts)
    end
    -- No integrated, software or arbitrarily chosen adapter is ever substituted.
    local details = memoryOverview(nil) .. clockOverview(nil)
    if status == 1 and result == 'NONE' then return 'No discrete GPU found', details end
    if status == 1 and result == 'AMBIGUOUS' then return 'Multiple discrete GPUs', details end
    return 'GPU name unavailable', details
end

function Initialize()
    measures = {}
    previous = {}
    infoComplete = false
    infoDeadline = os.time() + 14
end

function Update()
    local adapterName, adapterDetails = adapterInfo()
    if adapterName then
        set('MeterAdapterName', 'Text', adapterName)
        set('MeterAdapterDetails', 'Text', adapterDetails)
    end
    -- The normal skin cycle updates meters and redraws after all Script
    -- measures finish. Avoid an extra partial GPU redraw from this measure.
    return 0
end
