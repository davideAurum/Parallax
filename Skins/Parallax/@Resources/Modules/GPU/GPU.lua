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

local function memoryOverview(parts, reason)
    if not parts then
        return {'VRAM unavailable', reason or 'No discrete GPU memory information was returned.'}
    end
    local bytes = parts[2]:match('^%d+$') and tonumber(parts[2])
    local size, detail = 'VRAM unknown', 'The driver did not return a usable memory capacity.'
    if finite(bytes) and bytes > 0 and bytes <= 9007199254740991 then
        size = capacity(bytes)
        if parts[5] == 'PHYSICAL' then
            detail = 'Total physical video memory reported by the graphics driver: ' .. parts[2] .. ' bytes (' .. size .. ', decimal GB).'
        else
            detail = 'Windows-reported dedicated adapter memory: ' .. parts[2] .. ' bytes (' .. size .. ', decimal GB). Physical framebuffer capacity was unavailable; this may exclude driver-reserved memory.'
        end
    end
    local memoryType = parts[3] ~= '?' and trim(parts[3]) or ''
    local vendor = parts[4] ~= '?' and trim(parts[4]) or ''
    local label = memoryType ~= '' and (' ' .. memoryType) or ' (type unknown)'
    detail = detail .. (memoryType ~= '' and (' Memory type: ' .. memoryType .. '.')
        or ' Memory type was not exposed by a supported driver interface.')
    if vendor ~= '' then detail = detail .. ' Memory manufacturer: ' .. vendor .. '.' end
    return {size .. label, detail .. ' Read from this detected GPU at load or refresh; no saved card specifications.'}
end

local function clockOverview(parts)
    local function frequency(index)
        local raw = parts and parts[index] or '?'
        local khz = raw:match('^%d+$') and tonumber(raw)
        if not finite(khz) or khz <= 0 or khz > 4294967295 then return nil, nil end
        -- Whole MHz keeps the decimal details line inside the inset at the
        -- default width; the exact kHz values stay in the tooltip.
        return string.format('%.0f', khz / 1000), raw
    end
    local base, baseRaw = frequency(6)
    local boost, boostRaw = frequency(7)
    local text
    if base and boost then text = ' @ ' .. base .. '-' .. boost .. ' MHz'
    elseif base then text = ' @ ' .. base .. ' MHz base'
    elseif boost then text = ' @ ' .. boost .. ' MHz boost'
    else text = ' @ -- MHz' end
    local tip = 'Format: memory size and type @ base-boost graphics clock, shown as whole MHz. Clocks are specifications reported by the selected GPU driver at load or refresh. '
        .. (baseRaw and ('Base: ' .. baseRaw .. ' kHz. ') or 'Base clock unavailable. ')
        .. (boostRaw and ('Boost: ' .. boostRaw .. ' kHz. ') or 'Boost clock unavailable. ')
        .. 'These are not the current clock or a measured peak; the Clock row shows the live graphics clock. Actual boost varies with operating conditions.'
    return {text, tip}
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
        return name, name .. '. Windows high-performance selection among hardware adapters reported as non-integrated. Memory and base/boost clocks describe this GPU. Refreshed at skin load; the process table still spans all GPUs.', memoryOverview(parts), clockOverview(parts)
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
    local adapterName, adapterTip, adapterMemory, adapterClocks = adapterInfo()
    if adapterName then
        set('MeterAdapterName', 'Text', adapterName)
        set('MeterAdapterName', 'ToolTipText', adapterTip)
        set('MeterAdapterDetails', 'Text', adapterMemory[1] .. adapterClocks[1])
        set('MeterAdapterDetails', 'ToolTipText', adapterMemory[2] .. ' ' .. adapterClocks[2])
    end
    -- The normal skin cycle updates meters and redraws after all Script
    -- measures finish. Avoid an extra partial GPU redraw from this measure.
    return 0
end
