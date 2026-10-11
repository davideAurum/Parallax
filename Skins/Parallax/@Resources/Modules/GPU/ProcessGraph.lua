-- Parallax ranked GPU processes, grouped by PID to read like a per-process
-- table (CPU's process table styling). UsageMonitor owns the shared
-- collection worker and only ever exposes the top 5 busiest process-engine
-- instances system-wide; a PID that occupies more than one of those 5 slots
-- is shown once, at its busiest engine's percentage -- the same convention
-- Task Manager uses for its per-process GPU column (see
-- https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/), never a
-- sum of engines. Windows names decorate, but never merge, raw identities.
local measures, previous, memoryBindings, recentPIDs
local sources = {'MeasureGPUActivity', 'MeasureGPUProcess2',
    'MeasureGPUProcess3', 'MeasureGPUProcess4', 'MeasureGPUProcess5'}
local namesSource = 'MeasureGPUTemperatureController'
local noMemoryInstance = '__ParallaxNoGPUProcess__'
-- PIDs ranked this recently stay in spare name-request slots, so a row that
-- drops in and out of the top five keeps its resolved name.
local stickySeconds = 15
-- The helper accepts at most ten requested PIDs: five rows plus five recent.
local requestLimit = 10
local noDataTip = 'No ranked GPU process-engine observation: idle, starting up, unsupported driver, or missing counter. These cannot be distinguished here.'

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

local function display(value)
    local text = trim(value):gsub('[%c]', ' '):gsub('#', '')
        :gsub('%[', '('):gsub('%]', ')'):gsub('"', "'")
    return text
end

local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function integer(value, maximum)
    if type(value) ~= 'string' or #value > 16 or not value:match('^%d+$') then return nil end
    local number = tonumber(value)
    return finite(number) and number >= 1 and number <= maximum and number or nil
end

local function basename(value)
    if value == '' or #value > 256 or #value % 2 ~= 0 or value:find('[^%x]') then return nil end
    local decoded = value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end)
    if trim(decoded) == '' or decoded == '.' or decoded == '..' or decoded:find('[/\\]') then return nil end
    local offset = 1
    while offset <= #decoded do
        local first = decoded:byte(offset)
        local count, point, minimum
        if first < 128 then count, point, minimum = 1, first, 0
        elseif first >= 194 and first <= 223 then count, point, minimum = 2, first - 192, 128
        elseif first >= 224 and first <= 239 then count, point, minimum = 3, first - 224, 2048
        elseif first >= 240 and first <= 244 then count, point, minimum = 4, first - 240, 65536
        else return nil end
        for index = 1, count - 1 do
            local byte = decoded:byte(offset + index)
            if not byte or byte < 128 or byte > 191 then return nil end
            point = point * 64 + byte - 128
        end
        if point < minimum or point > 1114111 or (point >= 55296 and point <= 57343)
            or point < 32 or (point >= 127 and point <= 159) then return nil end
        offset = offset + count
    end
    return decoded
end

local function processNames()
    if not measures[namesSource] then measures[namesSource] = SKIN:GetMeasure(namesSource) end
    local source = measures[namesSource]
    local packet = source and source:GetStringValue() or ''
    if type(packet) ~= 'string' or #packet > 4096 then return {} end
    local rawEpoch, entries = packet:match('^GPU_NAMES|1|(%d+)|([^|]+)$')
    local epoch = integer(rawEpoch, 9007199254740991)
    if not epoch then return {} end
    local interval = math.max(1000, tonumber(SKIN:GetVariable('MetricsInterval', '1000')) or 1000,
        tonumber(SKIN:GetVariable('SensorInterval', '2000')) or 2000)
    if not finite(interval) then interval = 2000 end
    interval = math.floor(math.min(30000, interval))
    local now = os.time()
    if not finite(now) or epoch > now + 5 or now - epoch > math.max(8, 3 * interval / 1000 + 2) then return {} end
    if entries == '?' then return {} end
    local result, count = {}, 0
    for entry in (entries .. ';'):gmatch('(.-);') do
        count = count + 1
        local rawPid, nameHex = entry:match('^(%d+),(%x+)$')
        local pid = integer(rawPid, 4294967295)
        local name = nameHex and basename(nameHex)
        if count > requestLimit or not pid or not name or result[pid] then return {} end
        result[pid] = name
    end
    return result
end

-- Decimal sizing (1000 per step: KB/MB/GB/TB), the suite convention shared
-- with Memory Meter and Disk Meter rather than Task Manager's binary GB.
local function formatBytes(bytes)
    if bytes < 1000 then return string.format('%.0f B', bytes) end
    if bytes < 1000000 then return string.format('%.0f KB', bytes / 1000) end
    if bytes < 1000000000 then return string.format('%.0f MB', bytes / 1000000) end
    if bytes < 1000000000000 then return string.format('%.2f GB', bytes / 1000000000) end
    return string.format('%.2f TB', bytes / 1000000000000)
end

local function set(meter, option, value)
    local key = meter .. ':' .. option
    if previous[key] ~= value then
        previous[key] = value
        SKIN:Bang('!SetOption', meter, option, value)
        return true
    end
    return false
end

-- A memory instance identifies a process on one physical adapter, without
-- the GPU Engine suffix. Preserve its exact spelling for Name's case-sensitive
-- lookup; only the validated ASCII prefix is ever supplied as an option.
local function memoryIdentity(raw)
    if type(raw) ~= 'string' or #raw > 1024 then return nil end
    local prefix, pid, high, low, physical, engine = raw:match(
        '^(pid_(%d+)_luid_(0x%x%x%x%x%x%x%x%x)_(0x%x%x%x%x%x%x%x%x)_phys_(%d+))_eng_(%d+)_engtype_.*$')
    if not prefix or not integer(pid, 4294967295) then return nil end
    for _, part in ipairs({physical, engine}) do
        local number = tonumber(part)
        if #part > 10 or not finite(number) or number > 4294967295 then return nil end
    end
    return prefix
end

local function memoryObservation(slot, raw)
    local key = 'MeasureGPUProcessMemory' .. slot
    local identity = memoryIdentity(raw)
    if not identity then
        if memoryBindings[slot] then
            local cleared = pcall(function()
                SKIN:Bang('!DisableMeasure', key)
                SKIN:Bang('!SetOption', key, 'Name', noMemoryInstance)
            end)
            if cleared then memoryBindings[slot] = nil end
        end
        return '--', 'No exact active PID / adapter / physical GPU identity is available for the memory lookup.'
    end
    local tip = 'Windows GPU Process Memory Local Usage for ' .. identity .. ': memory this process holds in the adapter\'s own local memory (VRAM). This is memory attributed to this PID on this adapter, not to one engine.'
        .. ' It covers every engine this process uses on that adapter, not only the one ranked here.'
        .. ' Cross-process shared allocations may be counted in more than one process. This local memory is separate from the Shared RAM system-memory row.'
        .. ' Counter sample age is not exposed; collection failures may retain an older observation.'
    local ready = pcall(function()
        if memoryBindings[slot] ~= identity then
            SKIN:Bang('!SetOption', key, 'Name', identity)
            SKIN:Bang('!EnableMeasure', key)
            -- Refresh after changing Name before reading, so a prior row's
            -- positive value cannot be attributed to its replacement.
            SKIN:Bang('!UpdateMeasure', key)
            memoryBindings[slot] = identity
        end
    end)
    if not ready then return '--', tip .. ' The memory lookup could not be rebound.' end
    local readable, returnedName, bytes = pcall(function()
        if not measures[key] then measures[key] = SKIN:GetMeasure(key) end
        local source = measures[key]
        return source and source:GetStringValue() or '', source and source:GetValue() or nil
    end)
    if not readable or returnedName ~= identity then
        return '--', tip .. ' The memory counter did not return the exact requested instance.'
    end
    -- UsageMonitor creates a zero-valued named instance even when absent.
    -- RawValue bypasses the computed counter's initial zero, but cannot give
    -- zero a trustworthy availability flag. Never present it as measured zero.
    if not finite(bytes) or bytes <= 0 or bytes > 9007199254740991 or bytes ~= math.floor(bytes) then
        return '--', tip .. ' No usable positive byte reading. Zero bytes, an absent counter, startup and unsupported data cannot be distinguished by this named lookup.'
    end
    return formatBytes(bytes), tip .. string.format(' Reported local memory: %.0f bytes.', bytes)
end

-- One raw ranked process-engine-adapter instance. Renamed or merged values
-- cannot be presented as one engine's percentage, even if within bounds.
local function rawObservation(rank)
    local key = sources[rank]
    if not measures[key] then measures[key] = SKIN:GetMeasure(key) end
    local source = measures[key]
    if not source then return nil end
    local name = trim(source:GetStringValue())
    local value = source:GetValue()
    if name == '' or name == '0' or value == 0 then return nil end
    if not finite(value) or value < 0 or value > 100 then return nil end
    local pid = name:match('^pid_(%d+)_')
    local processId = integer(pid, 4294967295)
    if not processId or not name:find('_luid_', 1, true) or not name:match('_eng_%d+_') then return nil end
    return {pid = processId, value = value, raw = name, engine = name:match('_engtype_(.+)$') or 'unknown engine'}
end

function Initialize()
    measures, previous, memoryBindings, recentPIDs = {}, {}, {}, {}
end

function Update()
    local names, requested = processNames(), {}

    -- Group the 5 raw ranked instances by PID. Ranks arrive pre-sorted by
    -- descending value, so the first sighting of a PID already holds its
    -- busiest engine reading; later sightings only add to its engine list.
    local groups, order = {}, {}
    for rank = 1, #sources do
        local entry = rawObservation(rank)
        if entry then
            requested[entry.pid] = true
            local group = groups[entry.pid]
            if not group then
                group = {pid = entry.pid, value = entry.value, raw = entry.raw, engines = {}}
                groups[entry.pid] = group
                order[#order + 1] = group
            end
            group.engines[#group.engines + 1] = {engine = entry.engine, value = entry.value}
        end
    end

    for slot = 1, 5 do
        local group = order[slot]
        local nameMeter, valueMeter, memoryMeter = 'MeterGPUProcessName' .. slot, 'MeterGPUProcessValue' .. slot, 'MeterGPUProcessMemory' .. slot
        if group then
            local processName = names[group.pid]
            local pidText = string.format('%.0f', group.pid)
            local label = processName or ('PID ' .. pidText)
            local percentage = group.value < 0.1 and '<0.1%' or string.format('%.1f%%', group.value)
            local memoryLabel, memoryTip = memoryObservation(slot, group.raw)
            local others = ''
            if #group.engines > 1 then
                local parts = {}
                for index = 2, #group.engines do
                    local engine = group.engines[index]
                    parts[#parts + 1] = engine.engine .. ' ' .. (engine.value < 0.1 and '<0.1%' or string.format('%.1f%%', engine.value))
                end
                others = ' Also observed here: ' .. table.concat(parts, ', ') .. '.'
            end
            local tip = display('Busiest engine for this process: ' .. group.engines[1].engine .. ' at ' .. percentage
                .. '. This is the busiest of its ranked engines among the top 5 process-engine instances across all exposed GPUs, not a sum -- the same convention Task Manager uses for its per-process GPU column.' .. others
                .. (processName and (' Current Windows name lookup for PID ' .. pidText .. ': ' .. processName .. '.')
                    or (' Current Windows name lookup for PID ' .. pidText .. ' is unavailable; showing its PID.'))
                .. ' A process may also use additional engines outside this ranked list. Counter sample age is not exposed; collection failures may retain an older observation.')
            set(nameMeter, 'Text', display(label))
            set(valueMeter, 'Text', display(percentage))
            set(memoryMeter, 'Text', memoryLabel)
            set(memoryMeter, 'ToolTipText', display(memoryTip))
            set(nameMeter, 'ToolTipText', tip)
            set(valueMeter, 'ToolTipText', tip)
            SKIN:Bang('!ShowMeterGroup', 'GPUProcessRow' .. slot)
        elseif slot == 1 then
            -- Keep the first row visible to explain an empty ranking instead
            -- of leaving the table blank.
            memoryObservation(slot, nil)
            set(nameMeter, 'Text', 'No active GPU process data')
            set(valueMeter, 'Text', '--')
            set(memoryMeter, 'Text', '--')
            set(nameMeter, 'ToolTipText', noDataTip)
            set(valueMeter, 'ToolTipText', noDataTip)
            set(memoryMeter, 'ToolTipText', noDataTip)
            SKIN:Bang('!ShowMeterGroup', 'GPUProcessRow1')
        else
            memoryObservation(slot, nil)
            SKIN:Bang('!HideMeterGroup', 'GPUProcessRow' .. slot)
        end
    end

    -- Rainmeter repaints changed meters at the end of the normal skin cycle;
    -- an explicit mid-cycle !UpdateMeterGroup/!Redraw here would only add a
    -- redundant partial frame.
    -- Request every ranked PID, then fill spare slots with the most recently
    -- ranked others. Rows still show only the current ranking.
    local now, pids, spare = os.time(), {}, {}
    for pid in pairs(requested) do recentPIDs[pid] = now; pids[#pids + 1] = pid end
    for pid, seen in pairs(recentPIDs) do
        if seen > now or now - seen > stickySeconds then recentPIDs[pid] = nil
        elseif not requested[pid] then spare[#spare + 1] = pid end
    end
    table.sort(spare, function(a, b)
        if recentPIDs[a] ~= recentPIDs[b] then return recentPIDs[a] > recentPIDs[b] end
        return a < b
    end)
    for index = 1, math.min(#spare, requestLimit - #pids) do pids[#pids + 1] = spare[index] end
    table.sort(pids)
    for index, pid in ipairs(pids) do pids[index] = string.format('%.0f', pid) end
    return 0, #pids > 0 and table.concat(pids, ',') or '?'
end
