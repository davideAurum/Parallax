-- HWiNFO Gadget adapter. Discovery runs on refresh/reconnect only; native
-- Registry and Process measures perform ongoing reads without subprocess polling.
local state
local fields = {'Sensor', 'Label', 'Formatted', 'Raw'}
local registryNames = {Sensor='Sensor', Label='Label', Formatted='Value', Raw='ValueRaw'}

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

local function resetBindings()
    state.bindings = {}
    state.prime = true
    SKIN:Bang('!DisableMeasure', 'MeasureCPUSensorNamesUser')
    SKIN:Bang('!DisableMeasure', 'MeasureCPUSensorNamesMachine')
    for _, kind in ipairs({'Temperature', 'Voltage'}) do
        for _, field in ipairs(fields) do
            SKIN:Bang('!SetOption', 'MeasureCPUSensor' .. kind .. field, 'Disabled', '1')
            SKIN:Bang('!DisableMeasure', 'MeasureCPUSensor' .. kind .. field)
        end
    end
end

local function readBinding(kind)
    local binding = state.bindings[kind]
    if not binding then return nil, state.detail or 'No matching exported sensor. Enable Gadget reporting in HWiNFO and reconnect.' end
    local list = text(binding.hive == 'HKEY_CURRENT_USER' and 'MeasureCPUSensorNamesUser' or 'MeasureCPUSensorNamesMachine')
    local names = {}
    for key in list:gmatch('[^|]+') do names[key] = true end
    for _, field in ipairs(fields) do
        if not names[registryNames[field] .. binding.index] then
            return nil, 'An export was removed. Reconnect HWiNFO sensors.'
        end
    end
    local prefix = 'MeasureCPUSensor' .. kind
    if text(prefix .. 'Sensor', true) ~= binding.sensor or text(prefix .. 'Label', true) ~= binding.label then
        return nil, 'Sensor identity changed. Reconnect instead of using a different reading at the old index.'
    end
    local formatted = text(prefix .. 'Formatted')
    local display = formatted:gsub('\194\176', '')
    local unit
    if kind == 'Temperature' then unit = display:match('^[+-]?%d[%d%.,%s]*([CF])%s*$')
    else unit = display:match('^[+-]?%d[%d%.,%s]*(mV)%s*$') or display:match('^[+-]?%d[%d%.,%s]*(V)%s*$') end
    if unit ~= binding.unit then return nil, 'Missing or changed sensor units. Reconnect HWiNFO sensors.' end
    local rawText = text(prefix .. 'Raw')
    if rawText:match('^[+-]?%d+,%d+$') then rawText = rawText:gsub(',', '.') end
    local value = tonumber(rawText)
    if not finite(value) then return nil, 'Invalid numeric sensor reading.' end
    if kind == 'Temperature' then
        if unit == 'F' then value = (value - 32) * 5 / 9 end
        if value < -80 or value > 200 then return nil, 'Temperature reading outside the supported range.' end
    else
        if unit == 'mV' then value = value / 1000 end
        if value < 0 or value > 5 then return nil, 'Voltage reading outside the supported range.' end
    end
    return value, binding.sensor .. ' / ' .. binding.label .. '. CPU-wide reading shared across logical-processor rows; '
        .. (kind == 'Temperature' and 'degrees Celsius.' or (binding.kind == 'VID' and 'requested VID, not measured supply voltage.' or 'measured CPU supply voltage in volts.'))
        .. ' HWiNFO registry export; sample age is not exposed.'
end

local function render()
    local temperature, voltage, tempDetail, voltDetail
    local status
    if not state.enabled then
        status = 'HWiNFO sensors: off'
        tempDetail, voltDetail = 'Enable HWiNFO sensors in CPU Settings.', 'Enable HWiNFO sensors in CPU Settings.'
    elseif state.pending or state.prime then
        status = 'HWiNFO: connecting...'
        tempDetail, voltDetail = 'Waiting for sensor discovery and a native registry read.', 'Waiting for sensor discovery and a native registry read.'
    elseif SKIN:GetMeasure('MeasureCPUHWiNFORunning'):GetValue() ~= 1 then
        status = 'HWiNFO: not running'
        tempDetail, voltDetail = 'HWiNFO64 is not running. Old registry values are suppressed.', 'HWiNFO64 is not running. Old registry values are suppressed.'
    else
        temperature, tempDetail = readBinding('Temperature')
        voltage, voltDetail = readBinding('Voltage')
        if temperature and voltage then
            status = 'HWiNFO | CPU-wide ' .. (state.bindings.Voltage.kind == 'VID' and 'VID' or 'Vcore') .. ' + T'
        elseif temperature then status = 'HWiNFO | package T; V unavailable'
        elseif voltage then status = 'HWiNFO | CPU ' .. (state.bindings.Voltage.kind == 'VID' and 'VID' or 'Vcore') .. '; T unavailable'
        else status = 'HWiNFO: exports unavailable' end
    end
    local t = temperature and string.format('%.0f', temperature) or '-'
    local v = voltage and string.format('%.2f', voltage) or '-'
    for slot = 1, 64 do
        set('MeterCoreTemperature' .. slot, 'Text', t)
        set('MeterCoreVoltage' .. slot, 'Text', v)
        set('MeterCoreTemperature' .. slot, 'ToolTipText', tempDetail)
        set('MeterCoreVoltage' .. slot, 'ToolTipText', voltDetail)
    end
    set('MeterTableVoltageHeader', 'Text', voltage and state.bindings.Voltage.kind == 'VID' and 'VID' or 'V')
    set('MeterTableVoltageHeader', 'ToolTipText', voltDetail)
    set('MeterTableTemperatureHeader', 'ToolTipText', tempDetail)
    set('MeterSensors', 'Text', status)
    set('MeterSensors', 'ToolTipText', (tempDetail or '') .. ' ' .. (voltDetail or ''))
    redraw()
end

function Initialize()
    state = {bindings={}, previous={}, enabled=enabled(), prime=false, requestId=0}
end

local function discoveryArguments()
    local hive = SKIN:GetVariable('CPUSensorHive', 'Auto')
    hive = hive == 'HKCU' and 'HKEY_CURRENT_USER' or hive == 'HKLM' and 'HKEY_LOCAL_MACHINE' or 'Auto'
    return '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "DiscoverSensors.ps1" -Hive ' .. hive
        .. ' -TemperatureIndex ' .. indexOption('CPUTemperatureIndex')
        .. ' -VoltageIndex ' .. indexOption('CPUVoltageIndex')
end

function Reconnect()
    local parameters = discoveryArguments()
    if state.pending then state.reconnectQueued = parameters ~= state.arguments; return end
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
    if not state.enabled then state.prime = false; render(); return end
    if status ~= 1 or not output:match('^HWINFOV1[\r\n]') or request ~= state.requestId then
        state.detail = 'Sensor discovery failed. Open CPU Settings and reconnect.'
        state.prime = false
        render()
        return
    end
    for line in output:gmatch('[^\r\n]+') do
        local parts = {}
        for part in (line .. '|'):gmatch('(.-)|') do parts[#parts + 1] = part end
        if parts[1] == 'STATUS' then state.detail = parts[2]
        elseif parts[1] == 'TEMP' or parts[1] == 'VOLT' then
            local kind = parts[1] == 'TEMP' and 'Temperature' or 'Voltage'
            local index = parts[3] and parts[3]:match('^%d+$') and tonumber(parts[3])
            local sensor, label = unhex(parts[4] or ''), unhex(parts[5] or '')
            local unitOK = kind == 'Temperature' and (parts[6] == 'C' or parts[6] == 'F')
                or kind == 'Voltage' and (parts[6] == 'V' or parts[6] == 'mV') and (parts[7] == 'VID' or parts[7] == 'VCORE')
            if index and index <= 4096 and sensor and label and unitOK
                and (parts[2] == 'HKEY_CURRENT_USER' or parts[2] == 'HKEY_LOCAL_MACHINE') and not state.bindings[kind] then
                state.bindings[kind] = {hive=parts[2], index=tostring(index), sensor=sensor, label=label, unit=parts[6], kind=parts[7]}
                SKIN:Bang('!EnableMeasure', parts[2] == 'HKEY_CURRENT_USER' and 'MeasureCPUSensorNamesUser' or 'MeasureCPUSensorNamesMachine')
                for _, field in ipairs(fields) do
                    local name = 'MeasureCPUSensor' .. kind .. field
                    SKIN:Bang('!SetOption', name, 'RegHKey', parts[2])
                    SKIN:Bang('!SetOption', name, 'RegValue', registryNames[field] .. index)
                    -- SetOption forces a native ReadOptions, which also rereads
                    -- Disabled. Keep the parsed option in sync with the bang.
                    SKIN:Bang('!SetOption', name, 'Disabled', '0')
                    SKIN:Bang('!EnableMeasure', name)
                end
            end
        end
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
    local current = enabled()
    if current == state.enabled then return end
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
