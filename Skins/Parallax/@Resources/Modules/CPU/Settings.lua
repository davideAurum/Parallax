-- Independent CPU settings. No telemetry polling or writes outside user actions.
local state
local limits = {
    CPUShowInfo = {1, 0, 1},
    CPUShowCores = {1, 0, 1},
    CPUShowProcesses = {1, 0, 1},
    CPUProcessCount = {5, 1, 10},
    CPUShowHistory = {1, 0, 1},
    CPUHistorySource = {0, 0, 1},
    CPUHistorySamples = {60, 10, 300},
    CPUDecimals = {0, 0, 1},
    CPUVoltageDecimals = {3, 0, 3},
    CPUTemperatureDecimals = {0, 0, 1},
    CPUUpdateInterval = {1000, 500, 2000},
    CPUSensorInterval = {2000, 500, 5000},
    CPUSensorsEnabled = {1, 0, 1}
}

local sensorKeys = {TEMP='CPUTemperatureIndex', VOLT='CPUVoltageIndex'}
local hiveNames = {Auto='Automatic', HKCU='Current user', HKLM='All users'}
local numberFields = {
    CPUDecimals = {'Decimals', 1}, CPUVoltageDecimals = {'VoltageDecimals', 1},
    CPUTemperatureDecimals = {'TemperatureDecimals', 1}, CPUProcessCount = {'ProcessCount', 1},
    CPUHistorySamples = {'Samples', 10}, CPUUpdateInterval = {'UpdateRate', 500},
    CPUSensorInterval = {'SensorRate', 500}
}

local function layout()
    local y = 74
    local function variable(key, value) SKIN:Bang('!SetVariable', key, tostring(value)) end
    local function section(name)
        variable('CPUSettings' .. name .. 'SectionY', y)
        y = y + 26
    end
    local function row(name, visible)
        variable('CPUSettings' .. name .. 'Hidden', visible == false and 1 or 0)
        variable('CPUSettings' .. name .. 'Y', visible == false and 0 or y)
        if visible ~= false then y = y + 28 end
    end
    section('Appearance')
    row('Info'); row('Cores'); row('Decimals') -- Percentage precision also formats the always-visible total.
    -- The always-visible sensor footer also uses both precisions, independently
    -- of the Info and Thread visibility flags or current provider availability.
    row('VoltageDecimals'); row('TemperatureDecimals')
    -- Colors are shared by the thread table and per-thread graph.
    row('ThreadColors', state.CPUShowCores == 1 or (state.CPUShowHistory == 1 and state.CPUHistorySource == 1))
    y = y + 12; section('Processes'); row('Processes'); row('ProcessCount', state.CPUShowProcesses == 1)
    y = y + 12; section('Graph'); row('History')
    row('Source', state.CPUShowHistory == 1); row('Samples', state.CPUShowHistory == 1)
    y = y + 12; section('Rates'); row('UpdateRate'); row('SensorRate')
    -- Provider enablement is not a display visibility flag. Setup and recovery stay accessible.
    y = y + 12; section('Sensors'); row('Sensors')
    for _, name in ipairs({'OpenHWiNFO','Guide','Scan'}) do variable('CPUSettings' .. name .. 'Y', y) end
    y = y + 34
    for index = 1, 4 do variable('CPUSettingsSensorGuide' .. index .. 'Y', y); y = y + 18 end
    variable('CPUSettingsSensorStatusY', y); y = y + 18
    variable('CPUSettingsSensorDetailY', y); y = y + 42
    row('Temperature'); row('Voltage'); row('SensorHive'); row('Reconnect')
    y = y + 8
    for _, name in ipairs({'SensorsHint','Hint','Independence'}) do
        variable('CPUSettings' .. name .. 'Y', y); y = y + 18
    end
    local height = y + 16
    local scale = tonumber(SKIN:GetVariable('Scale', '1')) or 1
    local gap = tonumber(SKIN:GetVariable('Gap', '8'))
    if not gap and SKIN.ParseFormula then gap = SKIN:ParseFormula(SKIN:GetVariable('Gap', '8')) end
    local pixels = math.floor(height * scale + 0.5)
    variable('PanelHeight', height); variable('PanelHeightPx', pixels); variable('WindowHeight', pixels + (gap or 8))
end

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

local function rateCaption(milliseconds)
    return milliseconds < 1000 and (milliseconds .. 'ms') or ((milliseconds / 1000) .. 's')
end

local function sensorRateCaption()
    local effective = math.ceil(state.CPUSensorInterval / state.CPUUpdateInterval) * state.CPUUpdateInterval
    local target, actual = rateCaption(state.CPUSensorInterval), rateCaption(effective)
    return target == actual and target or (target .. '→' .. actual)
end

local function render()
    if not state then return end
    local values = {
        MeterSettingsInfoValue = state.CPUShowInfo == 1 and 'On' or 'Off',
        MeterSettingsCoresValue = state.CPUShowCores == 1 and 'On' or 'Off',
        MeterSettingsProcessesValue = state.CPUShowProcesses == 1 and 'On' or 'Off',
        MeterSettingsProcessCountValue = tostring(state.CPUProcessCount),
        MeterSettingsHistoryValue = state.CPUShowHistory == 1 and 'On' or 'Off',
        MeterSettingsSourceValue = state.CPUHistorySource == 1 and 'Per thread' or 'Total CPU',
        MeterSettingsSamplesValue = tostring(state.CPUHistorySamples),
        MeterSettingsDecimalsValue = tostring(state.CPUDecimals),
        MeterSettingsVoltageDecimalsValue = tostring(state.CPUVoltageDecimals),
        MeterSettingsTemperatureDecimalsValue = tostring(state.CPUTemperatureDecimals),
        MeterSettingsUpdateRateValue = tostring(state.CPUUpdateInterval),
        MeterSettingsSensorRateValue = tostring(state.CPUSensorInterval),
        MeterSettingsSensorsValue = state.CPUSensorsEnabled == 1 and 'On' or 'Off'
    }
    for meter, value in pairs(values) do
        SKIN:Bang('!SetOption', meter, 'Text', value)
    end
    SKIN:Bang('!SetOption', 'MeterSettingsSensorRateValue', 'ToolTipText',
        'Requested ' .. rateCaption(state.CPUSensorInterval) .. '; effective ' .. sensorRateCaption() .. '. Enter integer milliseconds from 500 to 5000.')
    for key, field in pairs(numberFields) do
        for _, direction in ipairs({-1, 1}) do
            local meter = 'MeterSettings' .. field[1] .. (direction == -1 and 'Decrease' or 'Increase')
            local active = direction == -1 and state[key] > limits[key][2] or direction == 1 and state[key] < limits[key][3]
            SKIN:Bang('!SetOption', meter, 'LeftMouseUpAction', active and ('[!CommandMeasure MeasureCPUSettings "AdjustNumber(\'' .. key .. '\',' .. direction .. ')"]') or '')
            SKIN:Bang('!SetOption', meter, 'FontColor', active and '#AccentColor#' or '#MutedColor#')
            SKIN:Bang('!SetOption', meter, 'MouseActionCursor', active and '1' or '0')
        end
    end
    layout()
    renderSensors()
    SKIN:Bang('!UpdateMeter', '*')
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
    -- Only CPU skins receive the new variable. Rate changes reload only CPU Meter
    -- because Rainmeter applies a skin's Update value and Registry dividers at load.
    -- Other preferences remain immediate and do not add a usage sample or refresh.
    SKIN:Bang('!SetVariableGroup', key, tostring(value), 'ParallaxCPU')
    if key == 'CPUUpdateInterval' or key == 'CPUSensorInterval' then
        SKIN:Bang('!Refresh', 'Parallax\\CPU')
    else
        SKIN:Bang('!UpdateMeasureGroup', 'ParallaxCPUApply', '*')
    end
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

function CycleHistorySource(direction)
    direction = direction == nil and 1 or direction
    if not state or (direction ~= -1 and direction ~= 1) then return false end
    return save('CPUHistorySource', state.CPUHistorySource == 1 and 0 or 1)
end

function CycleHistorySamples()
    if not state then return false end
    for _, capacity in ipairs({30, 60, 120, 300}) do
        if capacity > state.CPUHistorySamples then return save('CPUHistorySamples', capacity) end
    end
    return save('CPUHistorySamples', 30)
end

local function numberKey(key)
    return type(key) == 'string' and numberFields[key] ~= nil
end

function AdjustNumber(key, direction)
    if not state or not numberKey(key) or (direction ~= -1 and direction ~= 1) then return false end
    local rule = limits[key]
    local value = math.max(rule[2], math.min(rule[3], state[key] + direction * numberFields[key][2]))
    return save(key, value)
end

function BeginNumberInput(key)
    if not state or not numberKey(key) or state.editingNumber then return false end
    local field = numberFields[key][1]
    if SKIN:GetVariable('CPUSettings' .. field .. 'Hidden', '0') == '1' then return false end
    local meter = SKIN:GetMeter('MeterSettings' .. field .. 'Input')
    if not meter then return false end
    local rule = limits[key]
    local initial = tostring(math.max(rule[2], math.min(rule[3], state[key])))
    local scale = tonumber(SKIN:GetVariable('Scale')) or 1
    scale = math.max(0.75, math.min(2, scale))
    state.editingNumber = {key=key, initial=state[key]}
    -- Key, value, bounds and path are all local canonical values. The editor
    -- returns its typed text through RunCommand stdout; it is never a bang.
    local args = string.format('-NoLogo -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "SettingsInput.ps1" -Key UtilityNumber -Minimum %d -Maximum %d -DecimalPlaces 0 -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        rule[2], rule[3], initial, math.floor(SKIN:GetX() + meter:GetX()), math.floor(SKIN:GetY() + meter:GetY()),
        math.max(28, math.floor(meter:GetW())), math.max(20, math.floor(meter:GetH())), scale)
    SKIN:Bang('!SetOption', 'MeasureCPUSettingsDecimalInput', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureCPUSettingsDecimalInput')
    SKIN:Bang('!CommandMeasure', 'MeasureCPUSettingsDecimalInput', 'Run')
    return true
end

function CommitNumberInput()
    if not state or not state.editingNumber then return false end
    local pending = state.editingNumber
    local key = pending.key
    state.editingNumber = nil
    local measure = SKIN:GetMeasure('MeasureCPUSettingsDecimalInput')
    if not measure or measure:GetValue() ~= 1 or state[key] ~= pending.initial then return false end
    if SKIN:GetVariable('CPUSettings' .. numberFields[key][1] .. 'Hidden', '0') == '1' then return false end
    local output = measure and measure:GetStringValue() or ''
    output = output:gsub('[\r\n]+$', '')
    if #output > 80 then return false end
    local value = output:match('^PARALLAX_INPUT_V1|ok|(%d+)$')
    if not value then return false end
    value = tonumber(value)
    local rule = limits[key]
    if not value or value < rule[2] or value > rule[3] then return false end
    return save(key, value)
end

-- Retain internal compatibility with the original three precision controls.
function AdjustDecimals(key, direction)
    if key ~= 'CPUDecimals' and key ~= 'CPUVoltageDecimals' and key ~= 'CPUTemperatureDecimals' then return false end
    return AdjustNumber(key, direction)
end
function BeginDecimalInput(key) return BeginNumberInput(key) end
function CommitDecimalInput() return CommitNumberInput() end

function Finalize()
    if not state or not state.editingNumber then return end
    state.editingNumber = nil
    SKIN:Bang('!UpdateMeasure', 'MeasureCPUSettingsDecimalInput')
    local measure = SKIN:GetMeasure('MeasureCPUSettingsDecimalInput')
    if measure and measure:GetValue() == 0 then SKIN:Bang('!CommandMeasure', 'MeasureCPUSettingsDecimalInput', 'Kill') end
end

local function cycleRate(key, choices)
    if not state then return false end
    for _, choice in ipairs(choices) do
        if choice > state[key] then return save(key, choice) end
    end
    return save(key, choices[1])
end

function CycleCPUUpdateInterval()
    return cycleRate('CPUUpdateInterval', {500, 1000, 2000})
end

function CycleCPUSensorInterval()
    return cycleRate('CPUSensorInterval', {500, 1000, 2000, 5000})
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
    if (kind ~= 'TEMP' and kind ~= 'VOLT' and kind ~= 'CLOCK') or not index or index > 4096 or not sensor or not label then return nil end
    if hive ~= 'HKEY_CURRENT_USER' and hive ~= 'HKEY_LOCAL_MACHINE' then return nil end
    if kind == 'TEMP' and unit ~= 'C' and unit ~= 'F' then return nil end
    if kind == 'VOLT' and ((unit ~= 'V' and unit ~= 'mV') or (voltageKind ~= 'VID' and voltageKind ~= 'VCORE')) then return nil end
    if kind == 'CLOCK' then
        local normalizedSensor = sensor:match('^%s*(.-)%s*$')
        local normalizedLabel = label:match('^%s*(.-)%s*$')
        local primaryCPU = normalizedSensor:match('^CPU%s*%[#0%]:') or normalizedSensor:match('^CPU%s*%[#0%]$')
        if (unit ~= 'MHz' and unit ~= 'GHz') or not primaryCPU or normalizedLabel ~= 'Core Clocks' then return nil end
    end
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
    local candidates = {TEMP={}, VOLT={}, CLOCK={}}
    local coreSensors = {TEMP={}, VOLT={}}
    local clock
    local messages = {}
    local records = 0
    for line in output:gmatch('[^\r\n]+') do
        local parts = {}
        for part in (line .. '|'):gmatch('(.-)|') do parts[#parts + 1] = part end
        if parts[1] == 'STATE' and (parts[2] == 'RUNNING' or parts[2] == 'STOPPED') then process = parts[2]
        elseif parts[1] == 'CORE' then
            local core = parts[3] and parts[3]:match('^%d+$') and tonumber(parts[3])
            local candidate = parseCandidate({parts[2], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9]}, 1)
            if candidate and core and core <= 63 and (candidate.kind == 'TEMP' or candidate.voltageKind == 'VID') then
                coreSensors[candidate.kind][core] = true
            end
        elseif parts[1] == 'TEMP' or parts[1] == 'VOLT' or parts[1] == 'CLOCK' then
            local candidate = parseCandidate(parts, 1)
            if candidate then
                if candidate.kind == 'CLOCK' then clock = candidate
                else state.sensorSelected[candidate.kind] = candidate end
            end
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
            elseif state.sensorChoices[kind] then state.sensorChoices[kind][#state.sensorChoices[kind] + 1] = candidate end
        end
        if state.sensorChoices[kind] then table.sort(state.sensorChoices[kind], function(a, b) return a.index < b.index end) end
    end
    state.scanComplete = true
    local temperature, voltage = state.sensorSelected.TEMP, state.sensorSelected.VOLT
    local coreTemps, coreVolts = 0, 0
    for _ in pairs(coreSensors.TEMP) do coreTemps = coreTemps + 1 end
    for _ in pairs(coreSensors.VOLT) do coreVolts = coreVolts + 1 end
    if process == 'STOPPED' then
        state.scanStatus = 'Last scan: HWiNFO is not running'
        state.scanDetail = 'Open HWiNFO Sensors and scan again. Retained exports are not live readings.'
    elseif process ~= 'RUNNING' then
        state.scanStatus = 'Last scan: HWiNFO status unknown'
        state.scanDetail = 'Retry the scan with the current discovery helper.'
    else
        state.scanStatus = 'Last scan ' .. os.date('%H:%M:%S') .. ': HWiNFO running'
        if coreTemps > 0 or coreVolts > 0 then
            state.scanDetail = 'Found ' .. coreTemps .. ' core temperatures and ' .. coreVolts .. ' core VIDs.'
            if coreTemps == 0 then state.scanDetail = state.scanDetail .. ' Export each Core temperature in the DTS group.'
            elseif coreVolts == 0 then state.scanDetail = state.scanDetail .. ' Export each Core N VID for per-core voltage.' end
            if not clock then state.scanDetail = state.scanDetail .. ' Export Core Clocks for the current clock row.' end
        elseif temperature and voltage and clock then
            state.scanDetail = 'CPU-wide temperature, voltage and current clock exports found. Enable each Core temperature and Core N VID for individual sensor rows.'
        elseif temperature and voltage then
            state.scanDetail = 'CPU-wide exports found. Enable each Core temperature and Core N VID for individual sensor rows.'
            if not clock then state.scanDetail = state.scanDetail .. ' Export Core Clocks for the current clock row.' end
        elseif clock then
            state.scanDetail = 'Core Clocks export found. Enable CPU-wide temperature/voltage and each Core temperature/Core N VID as needed.'
        elseif voltage then state.scanDetail = 'Voltage export found. Enable CPU Package temperature in HWiNFO Gadget reporting.'
        elseif temperature then state.scanDetail = 'Temperature export found. Enable Vcore or Core VIDs in HWiNFO Gadget reporting.'
        else
            state.scanDetail = state.CPUSensorHive ~= 'Auto' and 'No exports in this search scope. Choose Automatic, then scan again.'
                or 'No selected CPU exports found. Follow the setup steps, then scan again.'
        end
        if ambiguous then state.scanDetail = 'Conflicting exports use the same number. Choose Current user or All users in Search scope, then pick a sensor.'
        elseif #messages > 0 and table.concat(messages, ' '):find('Ambiguous CPU core clock', 1, true) then
            state.scanDetail = 'Several Core Clocks exports match. Choose Current user or All users in Search scope.'
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

function CycleSensorHive(direction)
    direction = direction == nil and 1 or direction
    if not state or state.scanRunning or (direction ~= -1 and direction ~= 1) then return false end
    local nextHive = direction == 1 and {Auto='HKCU', HKCU='HKLM', HKLM='Auto'} or {Auto='HKLM', HKLM='HKCU', HKCU='Auto'}
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
