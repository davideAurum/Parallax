-- Independent CPU settings. No telemetry polling or writes outside user actions.
local state
local limits = {
    CPUShowInfo = {1, 0, 1},
    CPUShowCores = {1, 0, 1},
    CPUShowProcesses = {1, 0, 1},
    CPUProcessCount = {5, 1, 10},
    CPUShowHistory = {1, 0, 1},
    CPUHistorySamples = {60, 10, 300},
    CPUDecimals = {0, 0, 1},
    CPUSensorsEnabled = {1, 0, 1}
}

local sensorKeys = {TEMP='CPUTemperatureIndex', VOLT='CPUVoltageIndex'}
local hiveNames = {Auto='Automatic', HKCU='Current user', HKLM='All users'}

local function safe(value)
    return (tostring(value or ''):gsub('[%c]', ' '):gsub('#', '')
        :gsub('%[', '('):gsub('%]', ')'):gsub('"', "'"))
end

local function indexValue(value)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < -1 or value > 4096 then return -1 end
    return value
end

local function unhex(value)
    if #value == 0 or #value > 8192 or #value % 2 ~= 0 or value:find('[^%x]') then return nil end
    return (value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end))
end

local function sensorCaption(kind)
    local index = state[sensorKeys[kind]]
    local selected = state.sensorSelected[kind]
    if index == -1 then
        return selected and ('Auto: ' .. selected.label) or (state.scanComplete and 'Auto: not found' or 'Auto: scan to detect')
    end
    for _, candidate in ipairs(state.sensorChoices[kind]) do
        if candidate.index == index then return candidate.label .. ' / ' .. index end
    end
    return 'Export ' .. index .. ': unavailable'
end

local function renderSensors()
    for kind, meter in pairs({TEMP='MeterSettingsTemperatureValue', VOLT='MeterSettingsVoltageValue'}) do
        SKIN:Bang('!SetOption', meter, 'Text', safe(sensorCaption(kind)))
        local selected = state.sensorSelected[kind]
        local detail = selected and (selected.sensor .. ' / ' .. selected.label .. '; export ' .. selected.index .. '. ') or ''
        detail = detail .. 'Click to cycle Auto and supported exported sensors. Changes save and reconnect CPU Meter.'
        SKIN:Bang('!SetOption', meter, 'ToolTipText', safe(detail))
    end
    SKIN:Bang('!SetOption', 'MeterSettingsSensorHiveValue', 'Text', hiveNames[state.CPUSensorHive])
    SKIN:Bang('!SetOption', 'MeterSettingsSensorStatus', 'Text', safe(state.scanStatus))
    SKIN:Bang('!SetOption', 'MeterSettingsSensorDetail', 'Text', safe(state.scanDetail))
    SKIN:Bang('!SetOption', 'MeterSettingsSensorDetail', 'ToolTipText', safe(state.scanDetail))
    SKIN:Bang('!SetOption', 'MeterSettingsScan', 'Text', state.scanRunning and 'Scanning...' or 'Scan sensors')
end

local function bounded(value, rule)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return rule[1]
    end
    return math.max(rule[2], math.min(rule[3], math.floor(value)))
end

local function render()
    if not state then return end
    local values = {
        MeterSettingsInfoValue = state.CPUShowInfo == 1 and 'On' or 'Off',
        MeterSettingsCoresValue = state.CPUShowCores == 1 and 'On' or 'Off',
        MeterSettingsProcessesValue = state.CPUShowProcesses == 1 and 'On' or 'Off',
        MeterSettingsProcessCountValue = tostring(state.CPUProcessCount),
        MeterSettingsHistoryValue = state.CPUShowHistory == 1 and 'On' or 'Off',
        MeterSettingsSamplesValue = tostring(state.CPUHistorySamples),
        MeterSettingsDecimalsValue = tostring(state.CPUDecimals),
        MeterSettingsSensorsValue = state.CPUSensorsEnabled == 1 and 'On' or 'Off'
    }
    for meter, value in pairs(values) do
        SKIN:Bang('!SetOption', meter, 'Text', value)
    end
    renderSensors()
    SKIN:Bang('!UpdateMeterGroup', 'CPUSettingsUI')
    SKIN:Bang('!Redraw')
end

function Initialize()
    state = {userFile = SKIN:GetVariable('@') .. 'User\\CPU.inc',
        sensorChoices={TEMP={}, VOLT={}}, sensorSelected={}, scanId=0,
        scanStatus='HWiNFO: scan to check setup', scanDetail='Enable Gadget reporting in HWiNFO, then scan for CPU sensors.'}
    for key, rule in pairs(limits) do
        state[key] = bounded(SKIN:GetVariable(key), rule)
    end
    local hive = SKIN:GetVariable('CPUSensorHive', 'Auto')
    state.CPUSensorHive = hiveNames[hive] and hive or 'Auto'
    for _, key in pairs(sensorKeys) do state[key] = indexValue(SKIN:GetVariable(key, '-1')) end
end

function Update()
    render()
    return 0
end

local function save(key, value)
    if not state or not limits[key] then return false end
    value = bounded(value, limits[key])
    if state[key] == value then return false end
    state[key] = value
    SKIN:Bang('!SetVariable', key, tostring(value))
    SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), state.userFile)
    -- Only CPU skins receive the new variable. Updating their dedicated apply
    -- measure makes the change immediate without adding a usage sample or refresh.
    -- An unloaded CPU meter simply reads the saved preference on its next load.
    SKIN:Bang('!SetVariableGroup', key, tostring(value), 'ParallaxCPU')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxCPUApply', '*')
    render()
    return true
end

function Toggle(key)
    if not state or (key ~= 'CPUShowInfo' and key ~= 'CPUShowCores' and key ~= 'CPUShowProcesses' and key ~= 'CPUShowHistory' and key ~= 'CPUSensorsEnabled') then return false end
    return save(key, state[key] == 1 and 0 or 1)
end

function CycleProcessCount()
    if not state then return false end
    for _, count in ipairs({3, 5, 10}) do
        if count > state.CPUProcessCount then return save('CPUProcessCount', count) end
    end
    return save('CPUProcessCount', 3)
end

function CycleHistorySamples()
    if not state then return false end
    for _, capacity in ipairs({30, 60, 120, 300}) do
        if capacity > state.CPUHistorySamples then return save('CPUHistorySamples', capacity) end
    end
    return save('CPUHistorySamples', 30)
end

function ToggleDecimals()
    if not state then return false end
    return save('CPUDecimals', state.CPUDecimals == 1 and 0 or 1)
end

-- Setup scans are one-shot actions. This settings utility has no polling timer.
function ScanSensors(reconnect)
    if not state or state.scanRunning then return false end
    state.scanRunning = true
    state.scanComplete = false
    state.scanId = state.scanId + 1
    state.sensorChoices = {TEMP={}, VOLT={}}
    state.sensorSelected = {}
    state.scanStatus = 'Checking HWiNFO exports...'
    state.scanDetail = 'The scan checks CPU sensors already enabled in HWiNFO Gadget reporting.'
    if reconnect ~= false then SKIN:Bang('!UpdateMeasureGroup', 'ParallaxCPUSensorReconnect', '*') end
    local hive = state.CPUSensorHive == 'HKCU' and 'HKEY_CURRENT_USER'
        or state.CPUSensorHive == 'HKLM' and 'HKEY_LOCAL_MACHINE' or 'Auto'
    local args = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "DiscoverSensors.ps1" -List -Hive ' .. hive
        .. ' -TemperatureIndex ' .. state.CPUTemperatureIndex .. ' -VoltageIndex ' .. state.CPUVoltageIndex
        .. ' -RequestId ' .. state.scanId
    SKIN:Bang('!SetOption', 'MeasureCPUSettingsDiscover', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureCPUSettingsDiscover')
    SKIN:Bang('!CommandMeasure', 'MeasureCPUSettingsDiscover', 'Run')
    -- The serial makes a delayed timeout harmless after a newer scan starts.
    SKIN:Bang('[!Delay 12000][!CommandMeasure MeasureCPUSettings "SensorScanTimeout(' .. state.scanId .. ')"]')
    render()
    return true
end

function SensorScanTimeout(serial)
    if not state or not state.scanRunning or serial ~= state.scanId then return end
    state.scanRunning = false
    state.scanStatus = 'HWiNFO scan timed out'
    state.scanDetail = 'Click Scan sensors to retry. No sensor settings were changed.'
    render()
end

local function parseCandidate(parts, offset)
    local kind, hive = parts[offset], parts[offset + 1]
    local index = parts[offset + 2] and parts[offset + 2]:match('^%d+$') and tonumber(parts[offset + 2])
    local sensor, label = unhex(parts[offset + 3] or ''), unhex(parts[offset + 4] or '')
    local unit, voltageKind = parts[offset + 5], parts[offset + 6]
    if (kind ~= 'TEMP' and kind ~= 'VOLT') or not index or index > 4096 or not sensor or not label then return nil end
    if hive ~= 'HKEY_CURRENT_USER' and hive ~= 'HKEY_LOCAL_MACHINE' then return nil end
    if kind == 'TEMP' and unit ~= 'C' and unit ~= 'F' then return nil end
    if kind == 'VOLT' and ((unit ~= 'V' and unit ~= 'mV') or (voltageKind ~= 'VID' and voltageKind ~= 'VCORE')) then return nil end
    return {kind=kind, hive=hive, index=index, sensor=sensor, label=label, unit=unit, voltageKind=voltageKind}
end

function ApplySensorScan()
    if not state or not state.scanRunning then return end
    local measure = SKIN:GetMeasure('MeasureCPUSettingsDiscover')
    local output = measure:GetStringValue() or ''
    local request = tonumber(('\n' .. output):match('[\r\n]REQUEST|(%d+)[\r\n]'))
    -- Ignore retained output from a timed-out scan after the user has retried.
    if request and request ~= state.scanId then return end
    if not request and measure:GetValue() == 1 and output:match('^HWINFOV1[\r\n]') then return end
    state.scanRunning = false
    if measure:GetValue() ~= 1 or not output:match('^HWINFOV1[\r\n]') or request ~= state.scanId then
        state.scanStatus = 'HWiNFO scan failed'
        state.scanDetail = 'Retry Scan sensors. Check that the discovery helper is present and allowed to run.'
        render()
        return
    end
    local process = 'UNKNOWN'
    local candidates = {TEMP={}, VOLT={}}
    local messages = {}
    local records = 0
    for line in output:gmatch('[^\r\n]+') do
        local parts = {}
        for part in (line .. '|'):gmatch('(.-)|') do parts[#parts + 1] = part end
        if parts[1] == 'STATE' and (parts[2] == 'RUNNING' or parts[2] == 'STOPPED') then process = parts[2]
        elseif parts[1] == 'TEMP' or parts[1] == 'VOLT' then
            local candidate = parseCandidate(parts, 1)
            if candidate then state.sensorSelected[candidate.kind] = candidate end
        elseif parts[1] == 'CAND' and records < 128 then
            records = records + 1
            local candidate = parseCandidate(parts, 2)
            if candidate then
                local bucket = candidates[candidate.kind]
                local old = bucket[candidate.index]
                if not old then bucket[candidate.index] = candidate
                elseif old.sensor ~= candidate.sensor or old.label ~= candidate.label or old.unit ~= candidate.unit or old.voltageKind ~= candidate.voltageKind then
                    old.ambiguous = true
                end
            end
        elseif parts[1] == 'STATUS' then messages[#messages + 1] = parts[2] or '' end
    end
    local ambiguous = false
    for kind, bucket in pairs(candidates) do
        for _, candidate in pairs(bucket) do
            if candidate.ambiguous then ambiguous = true
            else state.sensorChoices[kind][#state.sensorChoices[kind] + 1] = candidate end
        end
        table.sort(state.sensorChoices[kind], function(a, b) return a.index < b.index end)
    end
    state.scanComplete = true
    local temperature, voltage = state.sensorSelected.TEMP, state.sensorSelected.VOLT
    if process == 'STOPPED' then
        state.scanStatus = 'Last scan: HWiNFO is not running'
        state.scanDetail = 'Open HWiNFO Sensors and scan again. Retained exports are not live readings.'
    elseif process ~= 'RUNNING' then
        state.scanStatus = 'Last scan: HWiNFO status unknown'
        state.scanDetail = 'Retry the scan with the current discovery helper.'
    else
        state.scanStatus = 'Last scan ' .. os.date('%H:%M:%S') .. ': HWiNFO running'
        if temperature and voltage then
            state.scanDetail = 'CPU temperature and ' .. (voltage.voltageKind == 'VID' and 'requested VID' or 'measured voltage') .. ' exports found. Reconnect to update CPU Meter.'
        elseif voltage then state.scanDetail = 'Voltage export found. Enable CPU Package temperature in HWiNFO Gadget reporting.'
        elseif temperature then state.scanDetail = 'Temperature export found. Enable Vcore or Core VIDs in HWiNFO Gadget reporting.'
        else state.scanDetail = 'No selected CPU exports found. Follow the setup steps, then scan again.' end
        if ambiguous then state.scanDetail = 'Conflicting exports use the same number. Choose Current user or All users in Search scope, then pick a sensor.'
        elseif #messages > 0 and table.concat(messages, ' '):find('Ambiguous', 1, true) then
            state.scanDetail = 'Several CPU exports match. Click Temperature or Voltage to choose one by name.'
        end
    end
    render()
end

local function saveSensorOptions(changes)
    for key, value in pairs(changes) do
        state[key] = value
        SKIN:Bang('!SetVariable', key, tostring(value))
        SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), state.userFile)
        SKIN:Bang('!SetVariableGroup', key, tostring(value), 'ParallaxCPU')
    end
    ScanSensors()
end

function CycleSensor(kind)
    if not state or not sensorKeys[kind] or state.scanRunning then return false end
    if not state.scanComplete then return ScanSensors() end
    local choices = state.sensorChoices[kind]
    if #choices == 0 then
        if state[sensorKeys[kind]] ~= -1 then
            saveSensorOptions({[sensorKeys[kind]]=-1})
            return true
        end
        state.scanDetail = kind == 'TEMP' and 'No supported temperature choices. Export CPU Package in HWiNFO Gadget, then scan again.'
            or 'No supported voltage choices. Export Vcore or Core VIDs in HWiNFO Gadget, then scan again.'
        render()
        return false
    end
    local current, nextIndex = state[sensorKeys[kind]], -1
    if current == -1 then nextIndex = choices[1].index
    else
        for index, candidate in ipairs(choices) do
            if candidate.index == current and choices[index + 1] then nextIndex = choices[index + 1].index; break end
        end
    end
    saveSensorOptions({[sensorKeys[kind]]=nextIndex})
    return true
end

function CycleSensorHive()
    if not state or state.scanRunning then return false end
    local nextHive = {Auto='HKCU', HKCU='HKLM', HKLM='Auto'}
    -- Indices are scoped to a hive. Start both selections at Auto in a new scope.
    saveSensorOptions({CPUSensorHive=nextHive[state.CPUSensorHive], CPUTemperatureIndex=-1, CPUVoltageIndex=-1})
    return true
end

function ReconnectSensors()
    if not state then return end
    return ScanSensors()
end

function OpenHWiNFO()
    if not state then return end
    local folder = os.getenv('ProgramW6432') or os.getenv('ProgramFiles') or ''
    local path = folder .. '\\HWiNFO64\\HWiNFO64.exe'
    local file = folder ~= '' and not path:find('[%c"#%[%]]') and io.open(path, 'rb')
    if file then file:close(); SKIN:Bang('["' .. path .. '"]')
    else
        state.scanDetail = 'Open your portable or custom HWiNFO installation manually, then follow these steps and scan.'
        render()
    end
end
