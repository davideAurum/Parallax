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
    for _, kind in ipairs({'Temperature', 'Voltage', 'Clock'}) do
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

local function readBinding(kind, core)
    local binding
    if core ~= nil then binding = state.coreBindings[kind][core] else binding = state.bindings[kind] end
    if not binding then
        return nil, core ~= nil and ('No exported ' .. kind:lower() .. ' for HWiNFO core ' .. core .. '. Enable its Gadget reporting and scan again.')
            or (kind == 'Clock' and state.clockDetail) or state.detail
            or 'No matching exported sensor. Enable Gadget reporting in HWiNFO and reconnect.'
    end
    local list = text(binding.hive == 'HKEY_CURRENT_USER' and 'MeasureCPUSensorNamesUser' or 'MeasureCPUSensorNamesMachine')
    local names = {}
    for key in list:gmatch('[^|]+') do names[key] = true end
    for _, field in ipairs(fields) do
        if not names[registryNames[field] .. binding.index] then
            return nil, 'An export was removed. Reconnect HWiNFO sensors.'
        end
    end
    local prefix = core ~= nil and ('MeasureCPUSensorCore' .. kind) or ('MeasureCPUSensor' .. kind)
    local suffix = core ~= nil and tostring(core + 1) or ''
    if text(prefix .. 'Sensor' .. suffix, true) ~= binding.sensor or text(prefix .. 'Label' .. suffix, true) ~= binding.label then
        return nil, 'Sensor identity changed. Reconnect instead of using a different reading at the old index.'
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
    else
        unit = display:match('^[+-]?%d[%d%.,%s]*(MHz)%s*$') or display:match('^[+-]?%d[%d%.,%s]*(GHz)%s*$')
    end
    if unit ~= binding.unit then return nil, 'Missing or changed sensor units. Reconnect HWiNFO sensors.' end
    local rawText = text(prefix .. 'Raw' .. suffix)
    if rawText:match('^[+-]?%d+,%d+$') then rawText = rawText:gsub(',', '.') end
    local value = tonumber(rawText)
    if not finite(value) then return nil, 'Invalid numeric sensor reading.' end
    if kind == 'Temperature' then
        if unit == 'F' then value = (value - 32) * 5 / 9 end
        if value < -80 or value > 200 then return nil, 'Temperature reading outside the supported range.' end
    elseif kind == 'Voltage' then
        if unit == 'mV' then value = value / 1000 end
        if value < 0 or value > 5 then return nil, 'Voltage reading outside the supported range.' end
    else
        if unit == 'GHz' then value = value * 1000 end
        if value < 100 or value > 10000 then return nil, 'Clock reading outside the supported range.' end
    end
    return value, binding.sensor .. ' / ' .. binding.label .. '. '
        .. (core ~= nil and ('HWiNFO physical core ' .. core .. '; ') or 'CPU-wide summary; ')
        .. (kind == 'Temperature' and 'degrees Celsius.'
            or kind == 'Clock' and 'current clock in MHz; HWiNFO provider aggregation, not a per-core or per-thread measurement.'
            or (binding.kind == 'VID' and 'requested VID, not measured supply voltage.' or 'measured CPU supply voltage in volts.'))
        .. ' HWiNFO registry export; sample age is not exposed.'
end

local function formatClock(value)
    if value >= 1000 then return string.format('%.2f GHz', value / 1000) end
    return string.format('%.0f MHz', value)
end

local function formatTemperature(value)
    return string.format('%.' .. state.temperatureDecimals .. 'f', value) .. degree .. 'C'
end

local function formatVoltage(value)
    return string.format('%.' .. state.voltageDecimals .. 'f', value) .. 'V'
end

local function render()
    local temperature, voltage, clock, tempDetail, voltDetail, clockDetail
    local status
    if not state.enabled then
        status = 'HWiNFO sensors: off'
        tempDetail, voltDetail, clockDetail = 'Enable HWiNFO sensors in CPU Settings.', 'Enable HWiNFO sensors in CPU Settings.', 'Enable HWiNFO sensors in CPU Settings.'
    elseif state.pending or state.prime then
        status = 'HWiNFO: connecting...'
        tempDetail, voltDetail, clockDetail = 'Waiting for sensor discovery and a native registry read.', 'Waiting for sensor discovery and a native registry read.', 'Waiting for sensor discovery and a native registry read.'
    elseif SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() ~= 1 then
        status = 'HWiNFO: not running'
        tempDetail, voltDetail, clockDetail = 'HWiNFO64 is not running. Old registry values are suppressed.', 'HWiNFO64 is not running. Old registry values are suppressed.', 'HWiNFO64 is not running. Old registry values are suppressed.'
    else
        temperature, tempDetail = readBinding('Temperature')
        voltage, voltDetail = readBinding('Voltage')
        clock, clockDetail = readBinding('Clock')
        local summary = {}
        if temperature then
            local label = state.bindings.Temperature.label:match('^%s*(.-)%s*$')
            summary[#summary + 1] = (label == 'Core Temperatures' and 'Avg ' or 'CPU ') .. formatTemperature(temperature)
        end
        if voltage then summary[#summary + 1] = (state.bindings.Voltage.kind == 'VID' and 'VID ' or 'Vcore ') .. formatVoltage(voltage) end
        if clock then summary[#summary + 1] = 'Clock ' .. formatClock(clock) end
        status = #summary > 0 and table.concat(summary, ' | ') or 'HWiNFO: CPU-wide exports unavailable'
    end
    local coreReady = state.enabled and not state.pending and not state.prime
        and SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() == 1
    local coreReadings, readings = 0, {}
    for core = 0, 63 do
        local t, v, td, vd
        if coreReady then
            t, td = readBinding('Temperature', core)
            v, vd = readBinding('Voltage', core)
        end
        if core <= 31 and (t or v) then coreReadings = coreReadings + 1 end
        readings[core] = {temperature=t, voltage=v, temperatureDetail=td, voltageDetail=vd}
    end
    -- Requested paired presentation: threads 1/2 share Core 0, 3/4 share
    -- Core 1, etc. This is an explicit display mapping, not a topology probe.
    -- Read each core once above so both thread cells show the same sample.
    for slot = 1, 64 do
        local thread = state.firstThread + slot - 1
        local core = math.floor((thread - 1) / 2)
        local reading = thread <= 64 and readings[core] or {}
        local pairing = ' Paired thread rows ' .. (core * 2 + 1) .. '/' .. (core * 2 + 2)
            .. ' share HWiNFO Core ' .. core .. ' (two threads per core).'
        set('MeterCoreTemperature' .. slot, 'Text', reading.temperature and formatTemperature(reading.temperature) or '-')
        set('MeterCoreVoltage' .. slot, 'Text', reading.voltage and formatVoltage(reading.voltage) or '-')
        set('MeterCoreTemperature' .. slot, 'ToolTipText', (reading.temperatureDetail or tempDetail or 'This physical core has no exported temperature.') .. pairing)
        set('MeterCoreVoltage' .. slot, 'ToolTipText', (reading.voltageDetail or voltDetail or 'This physical core has no exported VID.') .. pairing)
    end
    if coreReady and #state.coreIds == 0 then status = 'No per-core exports | ' .. status
    elseif coreReady and coreReadings == 0 then status = 'Core readings unavailable | ' .. status end
    set('MeterTableVoltageHeader', 'ToolTipText', 'Lightning symbol: HWiNFO core VID in volts, requested voltage rather than measured Vcore. Values use V with no space and repeat on paired thread rows.')
    set('MeterTableTemperatureHeader', 'ToolTipText', 'Thermometer symbol: HWiNFO DTS core temperature in degrees Celsius. Values use degrees Celsius with no space and repeat on paired thread rows.')
    set('MeterCurrentClockValue', 'Text', clock and formatClock(clock) or 'Unavailable')
    set('MeterCurrentClockValue', 'ToolTipText', clockDetail or 'Enable the CPU [#0] Core Clocks HWiNFO Gadget export to show a current CPU-wide clock.')
    set('MeterSensors', 'Text', status)
    set('MeterSensors', 'ToolTipText', (tempDetail or '') .. ' ' .. (voltDetail or '') .. ' ' .. (clockDetail or ''))
    redraw()
end

function Initialize()
    state = {bindings={}, coreBindings={Temperature={}, Voltage={}}, coreIds={}, previous={}, enabled=enabled(), prime=false, requestId=0, firstThread=1,
        providerRunning=nil,
        temperatureDecimals=decimalOption('CPUTemperatureDecimals', 0, 1), voltageDecimals=decimalOption('CPUVoltageDecimals', 3, 3)}
end

function SetThreadPage(first)
    first = tonumber(first)
    if not state or not finite(first) or first ~= math.floor(first) or first < 1 or first > 64 then return end
    state.firstThread = first
    render()
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
    state.detail = nil
    state.clockDetail = nil
    if not state.enabled then state.prime = false; render(); return end
    if status ~= 1 or not output:match('^HWINFOV1[\r\n]') or request ~= state.requestId then
        state.detail = 'Sensor discovery failed. Open CPU Settings and reconnect.'
        state.prime = false
        render()
        return
    end
    local coreCandidates = {Temperature={}, Voltage={}}
    local coreRecords = 0
    for line in output:gmatch('[^\r\n]+') do
        local parts = {}
        for part in (line .. '|'):gmatch('(.-)|') do parts[#parts + 1] = part end
        if parts[1] == 'STATUS' then
            state.detail = parts[2]
            if (parts[2] or ''):lower():find('core clock', 1, true) then state.clockDetail = parts[2] end
        elseif parts[1] == 'CORE' and coreRecords < 128 then
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
        elseif parts[1] == 'TEMP' or parts[1] == 'VOLT' or parts[1] == 'CLOCK' then
            local kind = parts[1] == 'TEMP' and 'Temperature' or parts[1] == 'VOLT' and 'Voltage' or 'Clock'
            local index = parts[3] and parts[3]:match('^%d+$') and tonumber(parts[3])
            local sensor, label = unhex(parts[4] or ''), unhex(parts[5] or '')
            local normalizedSensor = sensor and sensor:match('^%s*(.-)%s*$') or ''
            local normalizedLabel = label and label:match('^%s*(.-)%s*$') or ''
            local cpuSensor = normalizedSensor:match('^CPU%s*%[#0%]:') or normalizedSensor:match('^CPU%s*%[#0%]$')
            local unitOK = kind == 'Temperature' and (parts[6] == 'C' or parts[6] == 'F')
                or kind == 'Voltage' and (parts[6] == 'V' or parts[6] == 'mV') and (parts[7] == 'VID' or parts[7] == 'VCORE')
                or kind == 'Clock' and cpuSensor and normalizedLabel == 'Core Clocks'
                    and (parts[6] == 'MHz' or parts[6] == 'GHz')
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
        state.detail = 'Sensor discovery timed out. Open CPU Settings and reconnect.'
        if state.reconnectQueued then Reconnect() end
    end
    render()
    return 0
end
