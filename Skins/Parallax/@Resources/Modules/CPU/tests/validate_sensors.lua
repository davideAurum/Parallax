-- Offline Sensors.lua behavioral suite, compatible with Rainmeter's Lua 5.1.
-- No registry, process, telemetry, or user settings are read or changed.
-- Invocation from an isolated native Lua harness:
--   local suite = assert(loadfile(testPath))()
--   local report = suite.Run(sensorsPath)
-- Run returns a readable report on success and raises the full report on failure.
-- The synthetic export indices below are fixtures, not discovered machine IDs.

local suite = {}
local HIVE_USER, HIVE_MACHINE = 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE'
local fieldNames = {Sensor='Sensor', Label='Label', Formatted='Value', Raw='ValueRaw'}

local function equal(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function contains(actual, expected, label)
    assert(type(actual) == 'string' and actual:find(expected, 1, true),
        (label or 'text') .. ': expected ' .. expected .. ' in ' .. tostring(actual))
end

local function hex(value)
    return (value:gsub('.', function(character) return string.format('%02X', string.byte(character)) end))
end

local function fixture(options)
    options = options or {}
    local hive = options.hive or HIVE_USER
    local sensor = options.sensor or 'CPU [#0]: Fixture Processor'
    local temperatureLabel = options.temperatureLabel or 'CPU Package'
    local voltageKind = options.voltageKind or 'VID'
    local voltageLabel = voltageKind == 'VID' and 'Core VIDs' or 'Vcore'
    local temperatureUnit, voltageUnit = options.temperatureUnit or 'C', options.voltageUnit or 'V'
    local temperatureRaw, voltageRaw = options.temperatureRaw or '65', options.voltageRaw or '1.250'
    local temperatureIndex, voltageIndex = options.temperatureIndex or 3, options.voltageIndex or 7
    local clockSensor = options.clockSensor or sensor
    local clockLabel, clockUnit = options.clockLabel or 'Core Clocks', options.clockUnit or 'MHz'
    local clockRaw, clockIndex = options.clockRaw or '3906.1', options.clockIndex or 11
    local fanSensor = options.fanSensor or 'DELL EC: Fixture System'
    local fanLabel, fanUnit = options.fanLabel or 'CPU', options.fanUnit or 'RPM'
    local fanRaw, fanIndex = options.fanRaw or '2529', options.fanIndex or 29
    local motherboardFanSensor = options.motherboardFanSensor or 'DELL EC: Fixture System'
    local motherboardFanLabel, motherboardFanUnit = options.motherboardFanLabel or 'Mainboard', options.motherboardFanUnit or 'RPM'
    local motherboardFanRaw, motherboardFanIndex = options.motherboardFanRaw or '1049', options.motherboardFanIndex or 30
    local registry, records = {}, {'HWINFOV1'}
    local function export(index, source, label, raw, unit)
        for key, value in pairs({Sensor=source, Label=label, Value=raw .. ' ' .. unit, ValueRaw=raw}) do
            registry[key .. index] = value
        end
    end
    if options.aggregate ~= false then
        export(temperatureIndex, sensor, temperatureLabel, temperatureRaw, temperatureUnit)
        export(voltageIndex, sensor, voltageLabel, voltageRaw, voltageUnit)
        records[#records + 1] = 'TEMP|' .. hive .. '|' .. temperatureIndex .. '|' .. hex(sensor) .. '|' .. hex(temperatureLabel) .. '|' .. temperatureUnit
        records[#records + 1] = 'VOLT|' .. hive .. '|' .. voltageIndex .. '|' .. hex(sensor) .. '|' .. hex(voltageLabel) .. '|' .. voltageUnit .. '|' .. voltageKind
        if options.clock ~= false then
            export(clockIndex, clockSensor, clockLabel, clockRaw, clockUnit)
            records[#records + 1] = 'CLOCK|' .. hive .. '|' .. clockIndex .. '|' .. hex(clockSensor) .. '|' .. hex(clockLabel) .. '|' .. clockUnit
        end
        if options.fan ~= false then
            export(fanIndex, fanSensor, fanLabel, fanRaw, fanUnit)
            records[#records + 1] = 'FAN|' .. hive .. '|' .. fanIndex .. '|' .. hex(fanSensor) .. '|' .. hex(fanLabel) .. '|' .. fanUnit
        end
        if options.motherboardFan ~= false then
            export(motherboardFanIndex, motherboardFanSensor, motherboardFanLabel, motherboardFanRaw, motherboardFanUnit)
            records[#records + 1] = 'MBFAN|' .. hive .. '|' .. motherboardFanIndex .. '|' .. hex(motherboardFanSensor) .. '|' .. hex(motherboardFanLabel) .. '|' .. motherboardFanUnit
        end
    end
    -- Individual fixtures use independent indices so changing an aggregate can
    -- never make a physical-core assertion pass accidentally.
    for ordinal, core in ipairs(options.cores or {{id=0}}) do
        local id = core.id
        for _, kind in ipairs({'TEMP', 'VOLT'}) do
            local isTemperature = kind == 'TEMP'
            local source = isTemperature and (core.temperatureSensor or (core.sensor or sensor) .. ': DTS')
                or (core.voltageSensor or core.sensor or sensor)
            if not (isTemperature and core.noTemperature or not isTemperature and core.noVoltage) then
                local index = isTemperature and (core.temperatureIndex or temperatureIndex + 100 + (ordinal - 1) * 20)
                    or (core.voltageIndex or voltageIndex + 100 + (ordinal - 1) * 20)
                local raw = isTemperature and (core.temperatureRaw or temperatureRaw) or (core.voltageRaw or voltageRaw)
                local unit = isTemperature and (core.temperatureUnit or temperatureUnit) or (core.voltageUnit or voltageUnit)
                local label = isTemperature and (core.temperatureLabel or 'Core ' .. id) or (core.voltageLabel or 'Core ' .. id .. ' VID')
                export(index, source, label, raw, unit)
                records[#records + 1] = 'CORE|' .. kind .. '|' .. id .. '|' .. hive .. '|' .. index .. '|' .. hex(source) .. '|' .. hex(label) .. '|' .. unit .. '|' .. (isTemperature and '' or (core.voltageKind or 'VID'))
            end
        end
    end
    local output = table.concat(records, '\n') .. '\n'
    -- Normal fixtures echo the launched request. Explicit raw/malformed output
    -- fixtures omit this marker so their protocol is not silently repaired.
    return {hive=hive, registry=registry, output=output, correlate=true}
end

local function newMock(sensorPath, options)
    options = options or {}
    local context = {
        variables={CPUSensorsEnabled=options.enabled or '1', CPUSensorHive=options.hive or 'Auto',
            CPUTemperatureIndex=options.temperatureIndex or '-1', CPUVoltageIndex=options.voltageIndex or '-1',
            CPUTemperatureDecimals=options.temperatureDecimals or '0', CPUVoltageDecimals=options.voltageDecimals or '3'},
        registry={[HIVE_USER]={}, [HIVE_MACHINE]={}}, measures={}, meters={}, native={},
        queue={}, now=1000, running=options.running == nil and 1 or options.running,
        runs=0, serial=0, requests={}, nativeReads=0
    }
    local function measure(name, native, enabled)
        local item = {name=name, options={Disabled=enabled == false and '1' or '0'},
            value=0, string='', enabled=enabled ~= false, native=native}
        function item:GetValue() return self.value end
        function item:GetStringValue() return self.string end
        function item:GetOption(key, fallback) return self.options[key] or fallback or '' end
        context.measures[name] = item
        if native then context.native[#context.native + 1] = item end
        return item
    end
    measure('MeasureCPUHWiNFORunning', true)
    measure('MeasureCPUNativeClock', false).value = options.nativeClock or 0
    measure('MeasureCPUSensorNamesUser', true, false).hive = HIVE_USER
    measure('MeasureCPUSensorNamesMachine', true, false).hive = HIVE_MACHINE
    for _, kind in ipairs({'Temperature', 'Voltage', 'Clock', 'Fan', 'MotherboardFan'}) do
        for field in pairs(fieldNames) do
            measure('MeasureCPUSensor' .. kind .. field, true, false)
            if kind == 'Temperature' or kind == 'Voltage' then
                for slot = 1, 64 do
                    measure('MeasureCPUSensorCore' .. kind .. field .. slot, true, false)
                end
            end
        end
    end
    context.discovery = measure('MeasureCPUSensorDiscover', false)
    local skin = {}
    function skin:GetVariable(key, fallback) return context.variables[key] or fallback end
    function skin:GetMeasure(name) return assert(context.measures[name], 'Unknown mocked measure: ' .. name) end
    function skin:Bang(...)
        context.queue[#context.queue + 1] = {...}
    end
    local environment = {SKIN=skin, os={time=function() return context.now end}}
    environment._G = environment
    setmetatable(environment, {__index=_G})
    local chunk
    if setfenv then
        chunk = assert(loadfile(sensorPath))
        setfenv(chunk, environment)
    else
        chunk = assert(loadfile(sensorPath, 't', environment))
    end
    chunk()
    context.environment = environment

    function context:readNative(item)
        self.nativeReads = self.nativeReads + 1
        -- SetOption schedules ReadOptions even after an EnableMeasure bang.
        -- The cached Disabled option must agree with the intended running state.
        if item.readOptionsPending then
            item.enabled = item.options.Disabled ~= '1'
            item.readOptionsPending = false
        end
        if not item.enabled then return end
        if item.name == 'MeasureCPUHWiNFORunning' then
            item.value = self.running
        elseif item.hive then
            local names = {}
            for key in pairs(self.registry[item.hive]) do names[#names + 1] = key end
            table.sort(names)
            item.string = table.concat(names, '|')
        else
            local exports = self.registry[item.options.RegHKey] or {}
            -- Real Registry measures may return zero for a missing field; the
            -- independent ValueList must distinguish that from a legitimate zero.
            item.string = exports[item.options.RegValue] or '0'
            item.value = tonumber(item.string) or 0
        end
    end
    function context:refreshNative()
        for _, item in ipairs(self.native) do self:readNative(item) end
    end
    function context:flush()
        local index = 1
        while index <= #self.queue do
            assert(index < 50000, 'Mock bang loop did not settle')
            local args = self.queue[index]
            local bang, name = args[1], args[2]
            if bang == '!SetOption' then
                local target = self.measures[name]
                if target then
                    target.options[args[3]] = tostring(args[4])
                    if target.native then target.readOptionsPending = true end
                else
                    self.meters[name] = self.meters[name] or {}
                    self.meters[name][args[3]] = args[4]
                end
            elseif bang == '!EnableMeasure' or bang == '!DisableMeasure' then
                assert(self.measures[name], name).enabled = bang == '!EnableMeasure'
            elseif bang == '!EnableMeasureGroup' or bang == '!DisableMeasureGroup' then
                equal(name, 'CPUSensorNative', 'native group')
                for _, item in ipairs(self.native) do item.enabled = bang == '!EnableMeasureGroup' end
            elseif bang == '!UpdateMeasureGroup' then
                equal(name, 'CPUSensorNative', 'updated native group')
                self:refreshNative()
            elseif bang == '!UpdateMeasure' then
                if name ~= 'MeasureCPUSensorDiscover' then self:readNative(assert(self.measures[name])) end
            elseif bang == '!CommandMeasure' then
                if name == 'MeasureCPUSensorDiscover' then
                    equal(args[3], 'Run', 'discovery command')
                    self.runs = self.runs + 1
                    local parameter = self.discovery.options.Parameter or ''
                    self.serial = tonumber(parameter:match('%-RequestId (%d+)'))
                    assert(self.serial and self.serial > 0, 'Discovery must pass a positive RequestId')
                    self.requests[#self.requests + 1] = {serial=self.serial, parameter=parameter}
                    -- RunCommand can retain its previous output while a new
                    -- process starts. Completion is supplied only by complete().
                else
                    equal(name, 'MeasureCPUSensors', 'script callback target')
                    equal(args[3], 'PrimeComplete()', 'script callback')
                    self.environment.PrimeComplete()
                end
            elseif bang ~= '!UpdateMeterGroup' and bang ~= '!Redraw' then
                error('Unexpected production bang in offline test: ' .. tostring(bang))
            end
            index = index + 1
        end
        self.queue = {}
    end
    function context:call(name, ...)
        local result = assert(self.environment[name], 'Missing function ' .. name)(...)
        self:flush()
        return result
    end
    function context:install(data)
        self.registry[data.hive] = data.registry
        self:refreshNative()
    end
    function context:complete(data, status, serial)
        local result = data.output
        if data.correlate then result = result .. 'REQUEST|' .. tostring(serial or self.serial) .. '\n' end
        self.discovery.string, self.discovery.value = result, status or 1
        -- This represents the RunCommand FinishAction, not a polling update.
        self:call('ApplyDiscovery')
    end
    function context:text(meter, key)
        return (self.meters[meter] or {})[key or 'Text']
    end
    function context:change(hive, key, value)
        self.registry[hive][key] = value
        self:refreshNative()
        self:call('Update')
    end
    function context:setEnabled(value)
        self.variables.CPUSensorsEnabled = value and '1' or '0'
        self:call('ApplyPreferences')
    end
    context:call('Initialize')
    context:refreshNative()
    return context
end

local function connect(sensorPath, options)
    local context, data = newMock(sensorPath, options), fixture(options)
    context:install(data)
    -- Match the main controller, which declares the visible page before sensor
    -- discovery completes. Most fixtures exercise a full 64-row page.
    context:call('SetThreadPage', 1, options and options.visibleSlots or 64)
    context:call('Reconnect')
    context:complete(data)
    return context, data
end

local function threadReading(context, slot, temperature, voltage)
    local temperatureText = temperature == '-' and '-' or temperature .. string.char(176) .. 'C'
    local voltageText = voltage == '-' and '-' or voltage .. 'V'
    equal(context:text('MeterCoreTemperature' .. slot), temperatureText, 'thread temperature slot ' .. slot)
    equal(context:text('MeterCoreVoltage' .. slot), voltageText, 'thread VID slot ' .. slot)
end

local function coreReading(context, coreSuffix, temperature, voltage)
    -- Default page: the user-requested adjacent pair shares one core reading.
    -- Native binding suffix coreId+1 remains independent of display row suffix.
    local first = (coreSuffix - 1) * 2 + 1
    threadReading(context, first, temperature, voltage)
    threadReading(context, first + 1, temperature, voltage)
end

local function readings(context, temperature, voltage)
    coreReading(context, 1, temperature, voltage)
    -- Only threads 1/2 can use the default core 0 export. Other pairs cannot
    -- borrow that reading or the independently exported CPU-wide aggregate.
    for slot = 3, 64 do threadReading(context, slot, '-', '-') end
end

local function noReadings(context)
    for slot = 1, 64 do
        threadReading(context, slot, '-', '-')
    end
end

local function clockReading(context, expected)
    equal(context:text('MeterCurrentClockValue'), expected, 'current CPU-wide clock')
end

local function fanReading(context, expected)
    equal(context:text('MeterCurrentFanValue'), expected, 'current CPU fan speed')
end

local function motherboardFanReading(context, expected)
    equal(context:text('MeterMotherboardFanValue'), expected, 'current motherboard fan speed')
end

local function bindingState(context)
    local values = {}
    for _, item in ipairs(context.native) do
        values[#values + 1] = table.concat({item.name, item:GetOption('RegHKey'), item:GetOption('RegValue'),
            item:GetOption('Disabled'), tostring(item.enabled)}, '|')
    end
    return table.concat(values, '\n')
end

local function fieldDisabledOptions(context, disabled)
    for _, kind in ipairs({'Temperature', 'Voltage', 'Clock', 'Fan'}) do
        for field in pairs(fieldNames) do
            local name = 'MeasureCPUSensor' .. kind .. field
            equal(context.measures[name]:GetOption('Disabled'), disabled, name .. ' parsed Disabled')
            equal(context.measures[name].enabled, disabled == '0', name .. ' enabled state')
            if kind == 'Temperature' or kind == 'Voltage' then
                for slot = 1, 64 do
                    local coreName = 'MeasureCPUSensorCore' .. kind .. field .. slot
                    local coreDisabled = slot == 1 and disabled or '1'
                    equal(context.measures[coreName]:GetOption('Disabled'), coreDisabled, coreName .. ' parsed Disabled')
                    equal(context.measures[coreName].enabled, coreDisabled == '0', coreName .. ' enabled state')
                end
            end
        end
    end
end

function suite.Run(sensorPath)
    assert(type(sensorPath) == 'string' and sensorPath ~= '', 'Pass the absolute Sensors.lua path')
    local results = {passed=0, failed=0, total=0}
    local report = {'Offline Sensors.lua suite: mocked inputs and queued bangs; no hardware access.'}
    local function test(name, action)
        results.total = results.total + 1
        local ok, failure = pcall(action)
        if ok then
            results.passed = results.passed + 1
            report[#report + 1] = 'PASS ' .. name
        else
            results.failed = results.failed + 1
            report[#report + 1] = 'FAIL ' .. name .. ': ' .. tostring(failure)
        end
    end

    test('one core reading populates its adjacent thread pair only', function()
        local context = connect(sensorPath)
        readings(context, '65', '1.250')
        contains(context:text('MeterTableVoltageHeader', 'ToolTipText'), 'Lightning symbol')
        contains(context:text('MeterTableVoltageHeader', 'ToolTipText'), 'VID')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'requested VID, not measured supply voltage')
        contains(context:text('MeterCoreTemperature1', 'ToolTipText'), 'Core 0')
        equal(context:text('MeterCoreTemperature1'), context:text('MeterCoreTemperature2'), 'paired temperature')
        equal(context:text('MeterCoreVoltage1'), context:text('MeterCoreVoltage2'), 'paired VID')
        equal(context.runs, 1, 'one discovery launch')
    end)
    test('CPU-wide Core Clocks binds separately and formats MHz as GHz', function()
        local context = connect(sensorPath, {clockIndex=11, clockRaw='3906.1'})
        clockReading(context, '3.91 GHz')
        contains(context:text('MeterCurrentClockValue', 'ToolTipText'), 'HWiNFO provider aggregation, not a per-core or per-thread measurement.')
        equal(context.measures.MeasureCPUSensorClockRaw.options.RegValue, 'ValueRaw11')
        readings(context, '65', '1.250')
    end)
    test('CPU fan export binds separately and formats RPM', function()
        local context = connect(sensorPath, {fanIndex=29, fanRaw='2529'})
        fanReading(context, '2529 RPM')
        contains(context:text('MeterCurrentFanValue', 'ToolTipText'), 'CPU fan speed in RPM')
        equal(context.measures.MeasureCPUSensorFanRaw.options.RegValue, 'ValueRaw29')
    end)
    test('missing, changed or invalid CPU fan export stays unavailable', function()
        local context = connect(sensorPath, {fan=false})
        fanReading(context, 'Unavailable')
        context = connect(sensorPath, {fanLabel='GPU Fan'})
        fanReading(context, 'Unavailable')
        local data
        context, data = connect(sensorPath)
        context:change(data.hive, 'Sensor29', 'dGPU [#1]: Fixture GPU')
        fanReading(context, 'Unavailable')
        context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw29', '100001')
        fanReading(context, 'Unavailable')
    end)
    test('motherboard fan export binds separately and formats RPM', function()
        local context = connect(sensorPath, {motherboardFanIndex=30, motherboardFanRaw='1049'})
        motherboardFanReading(context, '1049 RPM')
        contains(context:text('MeterMotherboardFanValue', 'ToolTipText'), 'motherboard fan speed in RPM')
        equal(context.measures.MeasureCPUSensorMotherboardFanRaw.options.RegValue, 'ValueRaw30')
    end)
    test('missing, changed or invalid motherboard fan export stays unavailable', function()
        local context = connect(sensorPath, {motherboardFan=false})
        motherboardFanReading(context, 'Unavailable')
        context = connect(sensorPath, {motherboardFanLabel='GPU Fan'})
        motherboardFanReading(context, 'Unavailable')
        local data
        context, data = connect(sensorPath)
        context:change(data.hive, 'Sensor30', 'dGPU [#1]: Fixture GPU')
        motherboardFanReading(context, 'Unavailable')
        context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw30', '100001')
        motherboardFanReading(context, 'Unavailable')
    end)
    test('GHz current clock normalizes to the same CPU-wide display unit', function()
        local context = connect(sensorPath, {clockUnit='GHz', clockRaw='0.800'})
        clockReading(context, '800 MHz')
    end)
    test('native Windows aggregate clock remains available without HWiNFO exports', function()
        local context = connect(sensorPath, {clock=false, nativeClock=4289.5})
        clockReading(context, '4.29 GHz')
        contains(context:text('MeterCurrentClockValue', 'ToolTipText'), 'Windows Processor Information aggregate clock')
    end)
    test('missing or invalid Core Clocks remains unavailable without substituting base or per-core values', function()
        for _, options in ipairs({{clock=false}, {clockLabel='Core Effective Clocks'},
                {clockLabel='Core 0 Clock'}, {clockLabel='Bus Clock'},
                {clockSensor='CPU [#1]: Other Processor'}, {clockUnit='V'}}) do
            local context = connect(sensorPath, options)
            clockReading(context, 'Unavailable')
        end
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Sensor11', 'CPU [#1]: Reindexed Processor')
        clockReading(context, 'Unavailable')
        contains(context:text('MeterCurrentClockValue', 'ToolTipText'), 'Sensor identity changed')
        context, data = connect(sensorPath)
        context:change(data.hive, 'Value11', '3906.1 GHz')
        clockReading(context, 'Unavailable')
        context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw11', '1e999')
        clockReading(context, 'Unavailable')
    end)
    test('Fahrenheit and millivolts convert to Celsius and volts', function()
        local context = connect(sensorPath, {temperatureUnit='F', temperatureRaw='98.6', voltageUnit='mV', voltageRaw='1250'})
        readings(context, '37', '1.250')
    end)
    test('precision preferences reformat temperature and voltage without a reconnect', function()
        local context = connect(sensorPath, {temperatureRaw='65.4', voltageRaw='1.234',
            temperatureDecimals='1', voltageDecimals='2'})
        readings(context, '65.4', '1.23')
        contains(context:text('MeterSensors'), 'CPU 65.4' .. string.char(176) .. 'C | VID 1.23V')
        local runs = context.runs
        context.variables.CPUTemperatureDecimals, context.variables.CPUVoltageDecimals = '0', '3'
        context:call('ApplyPreferences')
        readings(context, '65', '1.234')
        contains(context:text('MeterSensors'), 'CPU 65' .. string.char(176) .. 'C | VID 1.234V')
        equal(context.runs, runs, 'precision change must not reconnect')
    end)
    test('degree-marked UTF-8 temperature exports preserve recognized units', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value103', '65 \194\176C')
        readings(context, '65', '1.250')
        context:change(data.hive, 'Value103', '65 \194\176F')
        readings(context, '-', '1.250')
    end)
    test('native ANSI degree-byte temperatures preserve recognized units', function()
        local context, data = connect(sensorPath)
        -- Native Rainmeter Registry GetStringValue was observed returning B0
        -- for the degree sign, rather than the UTF-8 C2 B0 fixture above.
        context:change(data.hive, 'Value103', '65 \176C')
        readings(context, '65', '1.250')
        context:change(data.hive, 'Value103', '65 \176F')
        readings(context, '-', '1.250')
    end)
    test('aggregate Vcore stays CPU-wide and the V column identifies requested VID', function()
        local context = connect(sensorPath, {voltageKind='VCORE'})
        readings(context, '65', '1.250')
        contains(context:text('MeterTableVoltageHeader', 'ToolTipText'), 'Lightning symbol')
        contains(context:text('MeterSensors', 'ToolTipText'), 'measured CPU supply voltage')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'requested VID')
    end)
    test('bound native fields retain Disabled=0 through forced option rereads', function()
        local context = connect(sensorPath)
        fieldDisabledOptions(context, '0')
        context:refreshNative()
        context:call('Update')
        readings(context, '65', '1.250')
        fieldDisabledOptions(context, '0')
    end)
    test('reconnect reset writes Disabled=1 before fresh bindings restore zero', function()
        local context, data = connect(sensorPath)
        context:call('Reconnect')
        fieldDisabledOptions(context, '1')
        context:refreshNative()
        fieldDisabledOptions(context, '1')
        context:complete(data)
        fieldDisabledOptions(context, '0')
        readings(context, '65', '1.250')
    end)
    test('valid numeric zero remains visible; missing ValueRaw is unavailable', function()
        local context, data = connect(sensorPath, {temperatureRaw='0', voltageRaw='0'})
        readings(context, '0', '0.000')
        context:change(data.hive, 'ValueRaw107', nil)
        readings(context, '0', '-')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'export was removed')
    end)
    test('missing formatted field is rejected even when cached numeric value exists', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value103', nil)
        readings(context, '-', '1.250')
    end)
    test('sensor or label identity swap suppresses the old index', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Sensor103', 'GPU [#0]: Unrelated fixture')
        readings(context, '-', '1.250')
        contains(context:text('MeterCoreTemperature1', 'ToolTipText'), 'Sensor identity changed')
        context:change(data.hive, 'Label107', 'Unrelated voltage')
        readings(context, '-', '-')
    end)
    test('identity retains leading and trailing spaces exactly', function()
        local context = connect(sensorPath, {sensor=' CPU [#0]: Fixture Processor ', cores={{id=0, temperatureLabel=' Core 0 '}}})
        readings(context, '65', '1.250')
    end)
    test('changed or absent units reject otherwise valid numbers', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value103', '65 F')
        readings(context, '-', '1.250')
        context:change(data.hive, 'Value107', '1.250')
        readings(context, '-', '-')
    end)
    test('NaN, infinity and non-numeric readings are rejected', function()
        for _, bad in ipairs({'NaN', '1e999', 'not a number', ''}) do
            local context, data = connect(sensorPath)
            context:change(data.hive, 'ValueRaw103', bad)
            context:change(data.hive, 'ValueRaw107', bad)
            readings(context, '-', '-')
        end
    end)
    test('a correct unit suffix without a numeric prefix is rejected', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value103', 'unavailable C')
        context:change(data.hive, 'Value107', 'V')
        readings(context, '-', '-')
    end)
    test('temperature and voltage ranges reject unsupported extremes', function()
        for _, pair in ipairs({{'201', '5.010'}, {'-81', '-0.01'}}) do
            local context, data = connect(sensorPath)
            context:change(data.hive, 'ValueRaw103', pair[1])
            context:change(data.hive, 'ValueRaw107', pair[2])
            readings(context, '-', '-')
        end
    end)
    test('decimal comma raw readings convert without accepting grouped numbers', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw103', '65,0')
        context:change(data.hive, 'ValueRaw107', '1,25')
        readings(context, '65', '1.250')
        context:change(data.hive, 'ValueRaw107', '1,234,567')
        readings(context, '65', '-')
    end)
    test('stopped HWiNFO process suppresses lingering readings and restart rediscovers', function()
        local context, data = connect(sensorPath)
        context:call('Update')
        context.running = 0
        context:refreshNative()
        context:call('Update')
        readings(context, '-', '-')
        clockReading(context, 'Unavailable')
        equal(context:text('MeterSensors'), 'HWiNFO: not running')
        context.running = 1
        context:refreshNative()
        context:call('Update')
        equal(context.runs, 2, 'provider restart launches one fresh discovery')
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        context:complete(data)
        readings(context, '65', '1.250')
    end)
    test('provider start during pending discovery queues exactly one replacement', function()
        local context, data = newMock(sensorPath, {running=0}), fixture()
        context:install(data)
        context:call('Update')
        context:call('Reconnect')
        equal(context.runs, 1)
        context.running = 1
        context:refreshNative()
        context:call('Update')
        equal(context.runs, 1, 'restart waits for the active helper')
        context:complete(data)
        equal(context.runs, 2, 'completion launches one replacement helper')
        readings(context, '-', '-')
        context:complete(data)
        readings(context, '65', '1.250')
    end)
    test('polling does not consume cached completion while reconnect is pending', function()
        local context, data = connect(sensorPath)
        context:call('Reconnect')
        equal(context.runs, 2)
        context:call('Update')
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        context:complete(data)
        readings(context, '65', '1.250')
    end)
    test('disable then reenable while discovery is pending accepts one completion', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data)
        context:call('Reconnect')
        context:setEnabled(false)
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO sensors: off')
        context:setEnabled(true)
        equal(context.runs, 1, 'no overlapping discovery')
        context:complete(data)
        readings(context, '65', '1.250')
    end)
    test('completion after disable cannot enable fields or restore values', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data)
        context:call('Reconnect')
        context:setEnabled(false)
        fieldDisabledOptions(context, '1')
        context:complete(data)
        fieldDisabledOptions(context, '1')
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO sensors: off')
        for _, item in ipairs(context.native) do equal(item.enabled, false, item.name .. ' disabled') end
        context:setEnabled(true)
        equal(context.runs, 2, 'fresh discovery after discarded completion')
        context:complete(data)
        readings(context, '65', '1.250')
        fieldDisabledOptions(context, '0')
    end)
    test('starting disabled neither launches discovery nor leaves native measures active', function()
        local context = newMock(sensorPath, {enabled='0'})
        context:call('Reconnect')
        equal(context.runs, 0)
        readings(context, '-', '-')
        clockReading(context, 'Unavailable')
        for _, item in ipairs(context.native) do equal(item.enabled, false, item.name .. ' disabled') end
    end)
    test('pending timeout stays unavailable and ignores late completion', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data)
        context:call('Reconnect')
        context.now = context.now + 13
        context:call('Update')
        readings(context, '-', '-')
        contains(context:text('MeterSensors', 'ToolTipText'), 'timed out')
        context:complete(data)
        readings(context, '-', '-')
    end)
    test('mapping changes during discovery queue only the newest arguments', function()
        local context, oldData = newMock(sensorPath), fixture()
        local newData = fixture({hive=HIVE_MACHINE, temperatureIndex=23, voltageIndex=29,
            temperatureRaw='47', voltageRaw='1.050', voltageKind='VCORE'})
        context:install(oldData); context:install(newData)
        context:call('Reconnect')
        local oldSerial = context.serial
        context.variables.CPUSensorHive = 'HKLM'
        context.variables.CPUTemperatureIndex = '23'
        context.variables.CPUVoltageIndex = '27'
        context:call('Reconnect')
        context.variables.CPUVoltageIndex = '29'
        context:call('Reconnect')
        equal(context.runs, 1, 'no overlapping scan for changed mappings')
        contains(context.requests[1].parameter, '-Hive Auto -TemperatureIndex -1 -VoltageIndex -1')
        context:complete(oldData, 1, oldSerial)
        equal(context.runs, 2, 'one replacement scan for newest mapping')
        assert(context.serial ~= oldSerial, 'Replacement must have a new request serial')
        contains(context.requests[2].parameter, '-Hive ' .. HIVE_MACHINE .. ' -TemperatureIndex 23 -VoltageIndex 29')
        readings(context, '-', '-')
        context:complete(newData)
        readings(context, '47', '1.050')
        equal(context.measures.MeasureCPUSensorTemperatureRaw.options.RegValue, 'ValueRaw23')
        equal(context.measures.MeasureCPUSensorVoltageRaw.options.RegValue, 'ValueRaw29')
        equal(context.measures.MeasureCPUSensorVoltageRaw.options.RegHKey, HIVE_MACHINE)
    end)
    test('identical reconnect while pending does not queue a redundant scan', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data); context:call('Reconnect')
        context:call('Reconnect'); context:call('Reconnect')
        context:complete(data)
        equal(context.runs, 1)
        readings(context, '65', '1.250')
    end)
    test('old callback after timeout and retry cannot bind retained readings', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data); context:call('Reconnect')
        local oldSerial = context.serial
        context.now = context.now + 13; context:call('Update')
        context:call('Reconnect')
        local currentSerial = context.serial
        assert(currentSerial ~= oldSerial, 'Retry must use a new request serial')
        context:complete(data, 1, oldSerial)
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        fieldDisabledOptions(context, '1')
        context:complete(data, 1, currentSerial)
        readings(context, '65', '1.250')
        equal(context.runs, 2)
    end)
    test('successful output without correlation cannot finish a pending scan', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data); context:call('Reconnect')
        context:complete({output=data.output}, 1)
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        context:complete(data)
        readings(context, '65', '1.250')
    end)
    test('explicit hive aliases and indices produce safe discovery arguments', function()
        for _, pair in ipairs({{'HKCU', HIVE_USER}, {'HKLM', HIVE_MACHINE}, {'invalid', 'Auto'}}) do
            local context = newMock(sensorPath, {hive=pair[1], temperatureIndex='3', voltageIndex='7'})
            context:call('Reconnect')
            local parameter = context.discovery.options.Parameter
            contains(parameter, '-Hive ' .. pair[2])
            contains(parameter, '-TemperatureIndex 3 -VoltageIndex 7')
        end
        local context = newMock(sensorPath, {temperatureIndex='99999', voltageIndex='1;Run'})
        context:call('Reconnect')
        contains(context.discovery.options.Parameter, '-TemperatureIndex -1 -VoltageIndex -1')
    end)
    test('HKLM binding uses the machine value list and matching registry hive', function()
        local context = connect(sensorPath, {hive=HIVE_MACHINE})
        readings(context, '65', '1.250')
        equal(context.measures.MeasureCPUSensorTemperatureRaw.options.RegHKey, HIVE_MACHINE)
        equal(context.measures.MeasureCPUSensorVoltageRaw.options.RegValue, 'ValueRaw7')
    end)
    test('invalid discovery status and malformed protocol never fabricate values', function()
        for _, data in ipairs({{output='HWINFOV1\n', status=101}, {output='unrelated output\n', status=1},
            {output='HWINFOV1\nTEMP|HKEY_CURRENT_USER|3|zz|00|C\n', status=1}}) do
            local context = newMock(sensorPath)
            context:call('Reconnect')
            context:complete(data, data.status)
            readings(context, '-', '-')
        end
    end)
    test('regular updates never launch another discovery process', function()
        local context = connect(sensorPath)
        for _ = 1, 20 do context.now = context.now + 1; context:call('Update') end
        equal(context.runs, 1)
        readings(context, '65', '1.250')
    end)
    test('distinct physical readings retain their own identity despite discovery order', function()
        local context = connect(sensorPath, {cores={
            {id=1, temperatureRaw='67', voltageRaw='0.950'},
            {id=0, temperatureRaw='51', voltageRaw='1.100'}
        }})
        coreReading(context, 1, '51', '1.100')
        coreReading(context, 2, '67', '0.950')
        coreReading(context, 3, '-', '-')
        equal(context.measures.MeasureCPUSensorCoreTemperatureRaw1.options.RegValue, 'ValueRaw123')
        equal(context.measures.MeasureCPUSensorCoreTemperatureRaw2.options.RegValue, 'ValueRaw103')
    end)
    test('sparse core IDs preserve thread pair positions without compaction', function()
        local context = connect(sensorPath, {cores={
            {id=7, temperatureRaw='73', voltageRaw='1.170'},
            {id=0, temperatureRaw='44', voltageRaw='0.940'},
            {id=3, temperatureRaw='58', voltageRaw='1.030'}
        }})
        coreReading(context, 1, '44', '0.940')
        coreReading(context, 4, '58', '1.030')
        coreReading(context, 8, '73', '1.170')
        for _, slot in ipairs({3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 17, 64}) do threadReading(context, slot, '-', '-') end
    end)
    test('missing individual sensors never borrow package or aggregate readings', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureRaw='42', noVoltage=true},
            {id=3, voltageRaw='0.930', noTemperature=true}
        }})
        coreReading(context, 1, '42', '-')
        coreReading(context, 4, '-', '0.930')
        coreReading(context, 2, '-', '-')
    end)
    test('aggregate-only discovery leaves every thread sensor cell empty', function()
        local context = connect(sensorPath, {cores={}})
        noReadings(context)
        contains(context:text('MeterSensors'), '65')
        contains(context:text('MeterSensors'), '1.250')
        clockReading(context, '3.91 GHz')
    end)
    test('physical sensors work without any CPU-wide aggregate export', function()
        local context = connect(sensorPath, {aggregate=false})
        readings(context, '65', '1.250')
    end)
    test('aggregate updates do not alter individual physical readings', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw3', '20')
        context:change(data.hive, 'ValueRaw7', '0.800')
        readings(context, '65', '1.250')
        contains(context:text('MeterSensors'), '20')
        contains(context:text('MeterSensors'), '0.800')
    end)
    test('conflicting duplicate bindings for the same core fail closed', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureRaw='51', voltageRaw='1.100'},
            {id=0, temperatureRaw='74', voltageRaw='1.290'}
        }})
        noReadings(context)
    end)
    test('reindexed physical identity suppresses only the affected core readings', function()
        local context, data = connect(sensorPath, {cores={
            {id=0, temperatureRaw='41', voltageRaw='0.910'},
            {id=1, temperatureRaw='61', voltageRaw='1.210'}
        }})
        context:change(data.hive, 'Sensor123', 'CPU [#1]: Other package')
        context:change(data.hive, 'Label127', 'Core 7 VID')
        coreReading(context, 1, '41', '0.910')
        coreReading(context, 2, '-', '-')
    end)
    test('stopping or disabling clears all sparse paired sensor values', function()
        local options = {cores={{id=0}, {id=7, temperatureRaw='79', voltageRaw='1.390'}}}
        local context, data = connect(sensorPath, options)
        context:call('Update')
        coreReading(context, 8, '79', '1.390')
        context.running = 0; context:refreshNative(); context:call('Update')
        noReadings(context)
        context.running = 1; context:refreshNative(); context:call('Update')
        noReadings(context)
        context:complete(data)
        coreReading(context, 8, '79', '1.390')
        context:setEnabled(false)
        noReadings(context)
        for _, item in ipairs(context.native) do equal(item.enabled, false, item.name .. ' off') end
    end)
    test('reconnect removes old physical identities before rendering the replacement', function()
        local context = connect(sensorPath, {cores={{id=0}, {id=7}}})
        local replacement = fixture({cores={{id=3, temperatureRaw='53', voltageRaw='1.030'}}})
        context:install(replacement); context:call('Reconnect')
        noReadings(context)
        context:complete(replacement)
        coreReading(context, 1, '-', '-')
        coreReading(context, 4, '53', '1.030')
        coreReading(context, 8, '-', '-')
    end)
    test('physical units convert independently and aggregate Vcore cannot enter VID rows', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureRaw='98.6', temperatureUnit='F', voltageRaw='1250', voltageUnit='mV'},
            {id=1, temperatureRaw='54', temperatureUnit='C', voltageRaw='1.110', voltageKind='VCORE'}
        }})
        coreReading(context, 1, '37', '1.250')
        coreReading(context, 2, '54', '-')
        contains(context:text('MeterTableVoltageHeader', 'ToolTipText'), 'Lightning symbol')
    end)
    test('unsupported physical IDs and units never populate a core row', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureUnit='K', voltageUnit='A'},
            {id=-1}, {id=64}
        }})
        noReadings(context)
    end)
    test('non-DTS temperature and wrong core labels are rejected at discovery', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureSensor='CPU [#0]: Fixture Processor', voltageLabel='Core VIDs'},
            {id=1, temperatureLabel='Core 0', voltageLabel='Core 0 VID'},
            {id=2, sensor='GPU [#0]: Fixture Graphics'},
            {id=3, sensor='CPU [#1]: Second Fixture Processor'}
        }})
        noReadings(context)
    end)
    test('page starting at thread 9 immediately shows core 4 in its first pair', function()
        local context = connect(sensorPath, {cores={
            {id=0, temperatureRaw='41', voltageRaw='0.910'},
            {id=4, temperatureRaw='64', voltageRaw='1.240'},
            {id=5, temperatureRaw='75', voltageRaw='1.350'}
        }})
        coreReading(context, 1, '41', '0.910')
        local bindings, reads, runs = bindingState(context), context.nativeReads, context.runs
        context:call('SetThreadPage', 9)
        threadReading(context, 1, '64', '1.240')
        threadReading(context, 2, '64', '1.240')
        threadReading(context, 3, '75', '1.350')
        threadReading(context, 4, '75', '1.350')
        threadReading(context, 5, '-', '-')
        equal(bindingState(context), bindings, 'page change preserves every native binding')
        equal(context.nativeReads, reads, 'page change reads only cached measure strings')
        equal(context.runs, runs, 'page change launches no discovery')
        context:call('SetThreadPage', 1)
        coreReading(context, 1, '41', '0.910')
        coreReading(context, 5, '64', '1.240')
        equal(bindingState(context), bindings, 'returning page preserves bindings')
    end)
    test('only visible thread slots own sensor tooltips', function()
        local context = connect(sensorPath, {visibleSlots=2, cores={
            {id=0, temperatureRaw='41', voltageRaw='0.910'},
            {id=4, temperatureRaw='64', voltageRaw='1.240'}
        }})
        contains(context:text('MeterCoreTemperature1', 'ToolTipText'), 'Core 0')
        contains(context:text('MeterCoreVoltage2', 'ToolTipText'), 'requested VID')
        equal(context:text('MeterCoreTemperature3', 'ToolTipText'), nil, 'unused slots never create empty tooltips')
        equal(context:text('MeterCoreVoltage64', 'ToolTipText'), nil, 'far unused slots never create empty tooltips')
        context:call('SetThreadPage', 9, 1)
        contains(context:text('MeterCoreTemperature1', 'ToolTipText'), 'Core 4')
        equal(context:text('MeterCoreTemperature2', 'ToolTipText'), '', 'a previously visible tooltip is cleared')
        equal(context:text('MeterCoreVoltage2', 'ToolTipText'), '', 'a previously visible VID tooltip is cleared')
    end)
    test('odd page starts retain absolute adjacent pairing across row boundaries', function()
        local context = connect(sensorPath, {cores={
            {id=4, temperatureRaw='64', voltageRaw='1.240'},
            {id=5, temperatureRaw='75', voltageRaw='1.350'},
            {id=6, temperatureRaw='46', voltageRaw='0.960'}
        }})
        context:call('SetThreadPage', 10)
        threadReading(context, 1, '64', '1.240')
        threadReading(context, 2, '75', '1.350')
        threadReading(context, 3, '75', '1.350')
        threadReading(context, 4, '46', '0.960')
        threadReading(context, 5, '46', '0.960')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), '9/10')
        contains(context:text('MeterCoreVoltage2', 'ToolTipText'), '11/12')
    end)
    test('page slots after absolute thread 64 clear instead of exposing later cores', function()
        local context = connect(sensorPath, {cores={
            {id=31, temperatureRaw='61', voltageRaw='1.210'},
            {id=32, temperatureRaw='72', voltageRaw='1.320'}
        }})
        context:call('SetThreadPage', 63)
        threadReading(context, 1, '61', '1.210')
        threadReading(context, 2, '61', '1.210')
        for slot = 3, 64 do threadReading(context, slot, '-', '-') end
        context:call('SetThreadPage', 64)
        threadReading(context, 1, '61', '1.210')
        for slot = 2, 64 do threadReading(context, slot, '-', '-') end
    end)
    test('invalid page arguments leave the current page and its bindings unchanged', function()
        local context = connect(sensorPath, {cores={{id=4, temperatureRaw='64', voltageRaw='1.240'}}})
        context:call('SetThreadPage', 9)
        local bindings, reads, runs = bindingState(context), context.nativeReads, context.runs
        for _, invalid in ipairs({0, -1, 65, 9.5, 'NaN', '1e999', '9;Run', ''}) do
            context:call('SetThreadPage', invalid)
            threadReading(context, 1, '64', '1.240')
            threadReading(context, 2, '64', '1.240')
            threadReading(context, 3, '-', '-')
        end
        equal(bindingState(context), bindings)
        equal(context.nativeReads, reads)
        equal(context.runs, runs)
    end)
    test('discovery completion retains the selected thread page', function()
        local context = connect(sensorPath, {cores={{id=0}, {id=4, temperatureRaw='64', voltageRaw='1.240'}}})
        context:call('SetThreadPage', 9)
        local replacement = fixture({cores={{id=0}, {id=4, temperatureRaw='54', voltageRaw='1.140'}}})
        context:install(replacement); context:call('Reconnect')
        noReadings(context)
        context:complete(replacement)
        threadReading(context, 1, '54', '1.140')
        threadReading(context, 2, '54', '1.140')
        threadReading(context, 3, '-', '-')
    end)
    test('paging cannot restore stopped disabled or pending sensor values', function()
        local context, data = connect(sensorPath, {cores={{id=0}, {id=4, temperatureRaw='64', voltageRaw='1.240'}}})
        context.running = 0; context:refreshNative()
        context:call('SetThreadPage', 9)
        noReadings(context)
        context.running = 1; context:refreshNative(); context:setEnabled(false)
        context:call('SetThreadPage', 1)
        noReadings(context)
        context:setEnabled(true)
        context:call('SetThreadPage', 9)
        noReadings(context)
        context:complete(data)
        threadReading(context, 1, '64', '1.240')
        threadReading(context, 2, '64', '1.240')
    end)
    report[#report + 1] = string.format('%d passed, %d failed, %d total.', results.passed, results.failed, results.total)
    results.report = table.concat(report, '\n')
    assert(results.failed == 0, results.report)
    return results.report
end

return suite
