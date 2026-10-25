-- HWiNFO Gadget adapter. Discovery runs on refresh, reconnect, sensor enable,
-- or an observed HWiNFO restart; native Registry and Process measures perform
-- ongoing reads without subprocess polling.
local state
local fields = {'Sensor', 'Label', 'Formatted', 'Raw'}
local registryNames = {Sensor='Sensor', Label='Label', Formatted='Value', Raw='ValueRaw'}
-- Rainmeter consumes Lua SetOption text through the Windows ANSI bridge on this
-- path. Use its single-byte degree code instead of a UTF-8 literal, which can
-- otherwise render as an extra A-circumflex character before the degree sign.
local degree = string.char(176)

local function text(name, identity)
    local measure = SKIN:GetMeasure(name)
    local value = measure and tostring(measure:GetStringValue() or '') or ''
    return identity and value or value:match('^%s*(.-)%s*$')
end

local function finite(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge
end

local function safe(value)
    return tostring(value or ''):gsub('[%c]', ' '):gsub('#', '')
        :gsub('%[', '('):gsub('%]', ')'):gsub('"', "'")
end

local function set(meter, option, value)
    value = safe(value)
    local key = meter .. ':' .. option
    if state.previous[key] ~= value then
        state.previous[key] = value
        SKIN:Bang('!SetOption', meter, option, value)
    end
end

local function redraw()
    SKIN:Bang('!UpdateMeterGroup', 'CPUUI')
    SKIN:Bang('!Redraw')
end

local function unhex(value)
    if #value == 0 or #value > 8192 or #value % 2 ~= 0 or value:find('[^%x]') then return nil end
    return (value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end))
end

local function indexOption(key)
    local value = tonumber(SKIN:GetVariable(key, '-1'))
    if not value or value ~= math.floor(value) or value < -1 or value > 4096 then return -1 end
    return value
end

local function enabled()
    return tonumber(SKIN:GetVariable('CPUSensorsEnabled', '1')) == 1
end

local function decimalOption(key, fallback, maximum)
    local value = tonumber(SKIN:GetVariable(key, tostring(fallback)))
    if not finite(value) or value ~= math.floor(value) then return fallback end
    return math.max(0, math.min(maximum, value))
end

local function resetBindings()
    state.bindings = {}
    state.coreBindings = {Temperature={}, Voltage={}}
    state.coreIds = {}
    state.prime = true
    SKIN:Bang('!DisableMeasure', 'MeasureCPUSensorNamesUser')
    SKIN:Bang('!DisableMeasure', 'MeasureCPUSensorNamesMachine')
    for _, kind in ipairs({'Temperature', 'Voltage', 'Clock', 'Fan', 'MotherboardFan'}) do
        for _, field in ipairs(fields) do
            SKIN:Bang('!SetOption', 'MeasureCPUSensor' .. kind .. field, 'Disabled', '1')
            SKIN:Bang('!DisableMeasure', 'MeasureCPUSensor' .. kind .. field)
        end
    end
    for _, kind in ipairs({'Temperature', 'Voltage'}) do
        for core = 1, 64 do
            for _, field in ipairs(fields) do
                local name = 'MeasureCPUSensorCore' .. kind .. field .. core
                SKIN:Bang('!SetOption', name, 'Disabled', '1')
                SKIN:Bang('!DisableMeasure', name)
            end
        end
    end
end

-- A hive's exported value-name list is the same for every reading in one
-- render. Split it into a set once per render; lists caches it by measure.
local function valueNames(lists, measure)
    local names = lists[measure]
    if not names then
        names = {}
        for key in text(measure):gmatch('[^|]+') do names[key] = true end
        lists[measure] = names
    end
    return names
end

local function readBinding(kind, core, lists)
    local binding
    if core ~= nil then binding = state.coreBindings[kind][core] else binding = state.bindings[kind] end
    if not binding then return nil end
    local names = valueNames(lists or {},
        binding.hive == 'HKEY_CURRENT_USER' and 'MeasureCPUSensorNamesUser' or 'MeasureCPUSensorNamesMachine')
    for _, field in ipairs(fields) do
        if not names[registryNames[field] .. binding.index] then return nil end
    end
    local prefix = core ~= nil and ('MeasureCPUSensorCore' .. kind) or ('MeasureCPUSensor' .. kind)
    local suffix = core ~= nil and tostring(core + 1) or ''
    -- A changed identity means the old index now holds a different reading.
    if text(prefix .. 'Sensor' .. suffix, true) ~= binding.sensor or text(prefix .. 'Label' .. suffix, true) ~= binding.label then
        return nil
    end
    local formatted = text(prefix .. 'Formatted' .. suffix)
    -- Rainmeter's Lua bridge can return the degree sign in the Windows ANSI
    -- encoding even though discovery used UTF-8. Accept either representation.
    local display = formatted:gsub('\194\176', ''):gsub('\176', '')
    local unit
    if kind == 'Temperature' then
        unit = display:match('^[+-]?%d[%d%.,%s]*([CF])%s*$')
    elseif kind == 'Voltage' then
        unit = display:match('^[+-]?%d[%d%.,%s]*(mV)%s*$') or display:match('^[+-]?%d[%d%.,%s]*(V)%s*$')
    elseif kind == 'Clock' then
        unit = display:match('^[+-]?%d[%d%.,%s]*(MHz)%s*$') or display:match('^[+-]?%d[%d%.,%s]*(GHz)%s*$')
    else
        unit = display:match('^[+-]?%d[%d%.,%s]*(RPM)%s*$')
    end
    if unit ~= binding.unit then return nil end
    local rawText = text(prefix .. 'Raw' .. suffix)
    if rawText:match('^[+-]?%d+,%d+$') then rawText = rawText:gsub(',', '.') end
    local value = tonumber(rawText)
    if not finite(value) then return nil end
    if kind == 'Temperature' then
        if unit == 'F' then value = (value - 32) * 5 / 9 end
        if value < -80 or value > 200 then return nil end
    elseif kind == 'Voltage' then
        if unit == 'mV' then value = value / 1000 end
        if value < 0 or value > 5 then return nil end
    elseif kind == 'Clock' then
        if unit == 'GHz' then value = value * 1000 end
        if value < 100 or value > 10000 then return nil end
    else
        if value < 0 or value > 100000 then return nil end
    end
    return value
end

local function formatClock(value)
    if value >= 1000 then return string.format('%.2f GHz', value / 1000) end
    return string.format('%.0f MHz', value)
end

local function formatFan(value)
    return string.format('%.0f RPM', value)
end

local function formatTemperature(value)
    return string.format('%.' .. state.temperatureDecimals .. 'f', value) .. degree .. 'C'
end

local function formatVoltage(value)
    return string.format('%.' .. state.voltageDecimals .. 'f', value) .. 'V'
end

local function readNativeClock()
    local measure = SKIN:GetMeasure('MeasureCPUNativeClock')
    local value = measure and measure:GetValue()
    if finite(value) and value >= 100 and value <= 10000 then return value end
    return nil
end

-- HWiNFO's Gadget export carries no sample timestamp. If HWiNFO keeps running
-- but stops writing it, the last values stay in the registry and would look
-- live. Every bound raw value (temperatures, VIDs, clock and fans, including
-- the CPU-wide summaries) forms one signature. If that signature is unchanged
-- for exportStaleSeconds while HWiNFO runs, the export counts as not
-- updating; any single change restores live readings. A reading that is
-- legitimately constant cannot trip this while any other bound reading
-- moves. A frozen export is only recognisable after that window, so it still
-- shows as connected for up to a minute after load, reconnect or restart.
-- HWiNFO polls its sensors, and writes this export, only while its Sensors
-- window is open (minimised is fine), so the footer names that fix. The text
-- is 10.64 em in IBM Plex Sans Medium and fits the narrowest footer (12.5 em
-- at width 180) at the 10 pt body maximum and every scale.
local exportStaleSeconds = 60
local exportStaleStatus = 'HWiNFO: open Sensors'
local exportKinds = {'Temperature', 'Voltage', 'Clock', 'Fan', 'MotherboardFan'}

local function exportFrozen()
    local parts = {}
    for _, kind in ipairs(exportKinds) do
        if state.bindings[kind] then parts[#parts + 1] = kind .. '=' .. text('MeasureCPUSensor' .. kind .. 'Raw', true) end
    end
    for core = 0, 63 do
        for _, kind in ipairs({'Temperature', 'Voltage'}) do
            if state.coreBindings[kind][core] then
                parts[#parts + 1] = kind .. core .. '=' .. text('MeasureCPUSensorCore' .. kind .. 'Raw' .. (core + 1), true)
            end
        end
    end
    if #parts == 0 then
        state.exportSignature = nil
        return false
    end
    local signature, now = table.concat(parts, '|'), os.time()
    if signature ~= state.exportSignature then
        state.exportSignature, state.exportChangedAt = signature, now
        return false
    end
    return now - state.exportChangedAt >= exportStaleSeconds
end

-- Event paths repaint at once. The periodic Update() path, and page changes
-- made by the controller (which repaints afterwards itself), pass false and
-- leave painting to the skin cycle: every meter set here has UpdateDivider 1,
-- so the meter pass that follows the measures draws these values this tick.
local function render(paint)
    local clock, fan, motherboardFan
    local nativeClock = readNativeClock()
    local lists = {}
    local status
    local frozen = false
    if not state.enabled then
        status = 'HWiNFO sensors: off'
    elseif state.pending or state.prime then
        status = 'HWiNFO: connecting...'
    elseif SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() ~= 1 then
        -- Old registry values are suppressed while HWiNFO64 is not running.
        status = 'HWiNFO: not running'
    elseif exportFrozen() then
        -- Values from an export that stopped updating are suppressed the same way.
        frozen = true
        status = exportStaleStatus
    else
        -- The footer reports provider status only; readings live in their rows.
        clock = readBinding('Clock', nil, lists)
        fan = readBinding('Fan', nil, lists)
        motherboardFan = readBinding('MotherboardFan', nil, lists)
    end
    -- Off, connecting or stopped: the next readable export starts a fresh window.
    if status and not frozen then state.exportSignature = nil end
    local coreReady = not frozen and state.enabled and not state.pending and not state.prime
        and SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() == 1
    local coreReadings, readings = 0, {}
    for core = 0, 63 do
        local t, v
        if coreReady then
            t = readBinding('Temperature', core, lists)
            v = readBinding('Voltage', core, lists)
        end
        if core <= 31 and (t or v) then coreReadings = coreReadings + 1 end
        readings[core] = {temperature=t, voltage=v}
    end
    -- Requested paired presentation: threads 1/2 share Core 0, 3/4 share
    -- Core 1, etc. This is an explicit display mapping, not a topology probe.
    -- Read each core once above so both thread cells show the same sample.
    for slot = 1, 64 do
        local thread = state.firstThread + slot - 1
        local core = math.floor((thread - 1) / 2)
        local reading = thread <= 64 and readings[core] or {}
        set('MeterCoreTemperature' .. slot, 'Text', reading.temperature and formatTemperature(reading.temperature) or '-')
        set('MeterCoreVoltage' .. slot, 'Text', reading.voltage and formatVoltage(reading.voltage) or '-')
    end
    if coreReady then
        if #state.coreIds == 0 then
            status = (clock or fan or motherboardFan) and 'HWiNFO: no per-core exports' or 'HWiNFO: Gadget exports unavailable'
        elseif coreReadings == 0 then
            status = 'HWiNFO: core readings unavailable'
        else
            status = 'HWiNFO: connected, ' .. coreReadings .. (coreReadings == 1 and ' core' or ' cores')
        end
    end
    -- The HWiNFO Core Clocks export takes precedence. When it is frozen,
    -- missing, unsupported or HWiNFO is off, Windows' own aggregate
    -- (Processor Frequency x % Processor Performance) is shown instead. It is a
    -- different measurement, so its source is named beside it and the two are
    -- never mixed silently; value and source change in the same render.
    local displayClock, clockSource = clock, ''
    if not displayClock and nativeClock then displayClock, clockSource = nativeClock, 'Windows' end
    set('MeterCurrentClockValue', 'Text', displayClock and formatClock(displayClock) or 'Unavailable')
    set('MeterCurrentClockSource', 'Text', clockSource)
    set('MeterCurrentFanValue', 'Text', fan and formatFan(fan) or 'Unavailable')
    set('MeterMotherboardFanValue', 'Text', motherboardFan and formatFan(motherboardFan) or 'Unavailable')
    set('MeterSensors', 'Text', status)
    if paint ~= false then redraw() end
end

function Initialize()
    state = {bindings={}, coreBindings={Temperature={}, Voltage={}}, coreIds={}, previous={}, enabled=enabled(), prime=false, requestId=0, firstThread=1,
        providerRunning=nil,
        temperatureDecimals=decimalOption('CPUTemperatureDecimals', 0, 1), voltageDecimals=decimalOption('CPUVoltageDecimals', 3, 3)}
end

-- Idle stand-down (Global Settings Idle pause; @Resources\Idle\StandDown.lua).
-- This measure does not run while paused, so a discovery still pending at the
-- pause gets its full 12 s again on resume (its FinishAction may still come)
-- instead of being abandoned at once. The HWiNFO export check keeps its
-- wall-clock meaning (owner decision 6): if no exported value changed over the
-- pause, the footer reads that the export is not updating at once.
function IdleLeave()
    if state and state.pending then state.deadline = os.time() + 12 end
end

function SetThreadPage(first)
    first = tonumber(first)
    if not state or not finite(first) or first ~= math.floor(first) or first < 1 or first > 64 then return end
    state.firstThread = first
    render(false)
end

local function discoveryArguments()
    local hive = SKIN:GetVariable('CPUSensorHive', 'Auto')
    hive = hive == 'HKCU' and 'HKEY_CURRENT_USER' or hive == 'HKLM' and 'HKEY_LOCAL_MACHINE' or 'Auto'
    return '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "DiscoverSensors.ps1" -CoreList -Hive ' .. hive
        .. ' -TemperatureIndex ' .. indexOption('CPUTemperatureIndex')
        .. ' -VoltageIndex ' .. indexOption('CPUVoltageIndex')
end

function Reconnect()
    local parameters = discoveryArguments()
    if state.pending then
        -- Preserve a provider-restart retry even when a same-argument manual
        -- reconnect arrives before the current discovery callback.
        state.reconnectQueued = state.reconnectQueued or parameters ~= state.arguments
        return
    end
    state.reconnectQueued = false
    state.enabled = enabled()
    resetBindings()
    if not state.enabled then
        state.prime = false
        SKIN:Bang('!DisableMeasureGroup', 'CPUSensorNative')
        render()
        return
    end
    state.pending = true
    state.deadline = os.time() + 12
    state.arguments = parameters
    state.requestId = state.requestId + 1
    SKIN:Bang('!SetOption', 'MeasureCPUSensorDiscover', 'Parameter', parameters .. ' -RequestId ' .. state.requestId)
    SKIN:Bang('!UpdateMeasure', 'MeasureCPUSensorDiscover')
    SKIN:Bang('!CommandMeasure', 'MeasureCPUSensorDiscover', 'Run')
    render()
end

local function bindNative(kind, binding, core)
    SKIN:Bang('!EnableMeasure', binding.hive == 'HKEY_CURRENT_USER' and 'MeasureCPUSensorNamesUser' or 'MeasureCPUSensorNamesMachine')
    local prefix = core ~= nil and ('MeasureCPUSensorCore' .. kind) or ('MeasureCPUSensor' .. kind)
    local suffix = core ~= nil and tostring(core + 1) or ''
    for _, field in ipairs(fields) do
        local name = prefix .. field .. suffix
        SKIN:Bang('!SetOption', name, 'RegHKey', binding.hive)
        SKIN:Bang('!SetOption', name, 'RegValue', registryNames[field] .. binding.index)
        SKIN:Bang('!SetOption', name, 'Disabled', '0')
        SKIN:Bang('!EnableMeasure', name)
    end
end

function ApplyDiscovery()
    if not state.pending then return end
    local measure = SKIN:GetMeasure('MeasureCPUSensorDiscover')
    local output = text('MeasureCPUSensorDiscover')
    local status = measure:GetValue()
    if status ~= 1 and status < 100 and os.time() < state.deadline then return end
    local request = tonumber(('\n' .. output .. '\n'):match('[\r\n]REQUEST|(%d+)[\r\n]'))
    if request and request ~= state.requestId then return end
    if not request and status == 1 and output:match('^HWINFOV1[\r\n]') then return end
    state.pending = false
    -- A settings selection made during discovery supersedes its old arguments.
    if state.reconnectQueued then Reconnect(); return end
    if not state.enabled then state.prime = false; render(); return end
    if status ~= 1 or not output:match('^HWINFOV1[\r\n]') or request ~= state.requestId then
        state.prime = false
        render()
        return
    end
    local coreCandidates = {Temperature={}, Voltage={}}
    local coreRecords = 0
    for line in output:gmatch('[^\r\n]+') do
        local parts = {}
        for part in (line .. '|'):gmatch('(.-)|') do parts[#parts + 1] = part end
        if parts[1] == 'CORE' and coreRecords < 128 then
            coreRecords = coreRecords + 1
            local kind = parts[2] == 'TEMP' and 'Temperature' or parts[2] == 'VOLT' and 'Voltage'
            local core = parts[3] and parts[3]:match('^%d+$') and tonumber(parts[3])
            local index = parts[5] and parts[5]:match('^%d+$') and tonumber(parts[5])
            local sensor, label = unhex(parts[6] or ''), unhex(parts[7] or '')
            local normalizedSensor = sensor and sensor:match('^%s*(.-)%s*$') or ''
            local normalizedLabel = label and label:match('^%s*(.-)%s*$') or ''
            local cpuSensor = normalizedSensor:match('^CPU%s*%[#0%]:') or normalizedSensor:match('^CPU%s*%[#0%]$')
            local semantic = core and kind and cpuSensor and (
                kind == 'Temperature' and normalizedSensor:match(':%s*DTS$') and normalizedLabel == 'Core ' .. core
                    and (parts[8] == 'C' or parts[8] == 'F')
                or kind == 'Voltage' and normalizedLabel == 'Core ' .. core .. ' VID'
                    and (parts[8] == 'V' or parts[8] == 'mV') and parts[9] == 'VID')
            if semantic and core <= 63 and index and index <= 4096
                and (parts[4] == 'HKEY_CURRENT_USER' or parts[4] == 'HKEY_LOCAL_MACHINE') then
                local binding = {hive=parts[4], index=tostring(index), sensor=sensor, label=label, unit=parts[8], kind=parts[9]}
                local previous = coreCandidates[kind][core]
                if previous == nil then coreCandidates[kind][core] = binding
                elseif previous ~= false and (previous.hive ~= binding.hive or previous.index ~= binding.index
                    or previous.sensor ~= binding.sensor or previous.label ~= binding.label or previous.unit ~= binding.unit) then
                    coreCandidates[kind][core] = false
                end
            end
        elseif parts[1] == 'TEMP' or parts[1] == 'VOLT' or parts[1] == 'CLOCK' or parts[1] == 'FAN' or parts[1] == 'MBFAN' then
            local kind = parts[1] == 'TEMP' and 'Temperature' or parts[1] == 'VOLT' and 'Voltage'
                or parts[1] == 'CLOCK' and 'Clock' or parts[1] == 'FAN' and 'Fan' or 'MotherboardFan'
            local index = parts[3] and parts[3]:match('^%d+$') and tonumber(parts[3])
            local sensor, label = unhex(parts[4] or ''), unhex(parts[5] or '')
            local normalizedSensor = sensor and sensor:match('^%s*(.-)%s*$') or ''
            local normalizedLabel = label and label:match('^%s*(.-)%s*$') or ''
            local cpuSensor = normalizedSensor:match('^CPU%s*%[#0%]:') or normalizedSensor:match('^CPU%s*%[#0%]$')
            local unitOK = kind == 'Temperature' and (parts[6] == 'C' or parts[6] == 'F')
                or kind == 'Voltage' and (parts[6] == 'V' or parts[6] == 'mV') and (parts[7] == 'VID' or parts[7] == 'VCORE')
                or kind == 'Clock' and cpuSensor and normalizedLabel == 'Core Clocks'
                    and (parts[6] == 'MHz' or parts[6] == 'GHz')
                or kind == 'Fan' and parts[6] == 'RPM'
                    and not normalizedSensor:lower():find('gpu', 1, true)
                    and not normalizedSensor:lower():find('graphics', 1, true)
                    and (normalizedLabel:lower() == 'cpu' or normalizedLabel:lower():match('^cpu%s+fan%s*(speed%s*|#?1%s*)?$'))
                or kind == 'MotherboardFan' and parts[6] == 'RPM'
                    and not normalizedSensor:lower():find('gpu', 1, true)
                    and not normalizedSensor:lower():find('graphics', 1, true)
                    and (normalizedLabel:lower() == 'mainboard' or normalizedLabel:lower() == 'motherboard'
                        or normalizedLabel:lower() == 'mainboard fan' or normalizedLabel:lower() == 'motherboard fan')
            if index and index <= 4096 and sensor and label and unitOK
                and (parts[2] == 'HKEY_CURRENT_USER' or parts[2] == 'HKEY_LOCAL_MACHINE') and not state.bindings[kind] then
                state.bindings[kind] = {hive=parts[2], index=tostring(index), sensor=sensor, label=label, unit=parts[6], kind=parts[7]}
                bindNative(kind, state.bindings[kind])
            end
        end
    end
    for core = 0, 63 do
        local found = false
        for _, kind in ipairs({'Temperature', 'Voltage'}) do
            local binding = coreCandidates[kind][core]
            if binding then
                state.coreBindings[kind][core] = binding
                bindNative(kind, binding, core)
                found = true
            end
        end
        if found then state.coreIds[#state.coreIds + 1] = core end
    end
    state.prime = true
    -- These queued native reads precede PrimeComplete; no synchronous option reads.
    SKIN:Bang('!UpdateMeasureGroup', 'CPUSensorNative')
    SKIN:Bang('!CommandMeasure', 'MeasureCPUSensors', 'PrimeComplete()')
end

function PrimeComplete()
    state.prime = false
    render()
end

function ApplyPreferences()
    local temperatureDecimals = decimalOption('CPUTemperatureDecimals', 0, 1)
    local voltageDecimals = decimalOption('CPUVoltageDecimals', 3, 3)
    local precisionChanged = state.temperatureDecimals ~= temperatureDecimals or state.voltageDecimals ~= voltageDecimals
    state.temperatureDecimals, state.voltageDecimals = temperatureDecimals, voltageDecimals
    local current = enabled()
    if current == state.enabled then
        if precisionChanged then render() end
        return
    end
    state.enabled = current
    if current then
        SKIN:Bang('!EnableMeasure', 'MeasureCPUHWiNFORunning')
        Reconnect()
    else
        resetBindings()
        state.prime = false
        SKIN:Bang('!DisableMeasureGroup', 'CPUSensorNative')
        render()
    end
end

function Update()
    local providerRunning = SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() == 1
    local providerStarted = state.providerRunning == false and providerRunning
    state.providerRunning = providerRunning
    if providerStarted and state.enabled then
        if state.pending then
            -- FinishAction will discard the pre-restart result and launch one
            -- fresh discovery. No recurring process or timer is introduced.
            state.reconnectQueued = true
        else
            Reconnect()
            return 0
        end
    end
    -- Only FinishAction consumes discovery output, so reconnect cannot reuse the
    -- previous RunCommand result while a new process is starting.
    if state.pending and os.time() >= state.deadline then
        state.pending = false
        state.prime = false
        if state.reconnectQueued then Reconnect() end
    end
    render(false)
    return 0
end
