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
    local temperatureRaw, voltageRaw = options.temperatureRaw or '65', options.voltageRaw or '1.25'
    local temperatureIndex, voltageIndex = options.temperatureIndex or 3, options.voltageIndex or 7
    local registry = {}
    for key, value in pairs({Sensor=sensor, Label=temperatureLabel, Value=temperatureRaw .. ' ' .. temperatureUnit, ValueRaw=temperatureRaw}) do
        registry[key .. temperatureIndex] = value
    end
    for key, value in pairs({Sensor=sensor, Label=voltageLabel, Value=voltageRaw .. ' ' .. voltageUnit, ValueRaw=voltageRaw}) do
        registry[key .. voltageIndex] = value
    end
    local output = 'HWINFOV1\nTEMP|' .. hive .. '|' .. temperatureIndex .. '|' .. hex(sensor) .. '|' .. hex(temperatureLabel) .. '|' .. temperatureUnit
        .. '\nVOLT|' .. hive .. '|' .. voltageIndex .. '|' .. hex(sensor) .. '|' .. hex(voltageLabel) .. '|' .. voltageUnit .. '|' .. voltageKind .. '\n'
    -- Normal fixtures echo the launched request. Explicit raw/malformed output
    -- fixtures omit this marker so their protocol is not silently repaired.
    return {hive=hive, registry=registry, output=output, correlate=true}
end

local function newMock(sensorPath, options)
    options = options or {}
    local context = {
        variables={CPUSensorsEnabled=options.enabled or '1', CPUSensorHive=options.hive or 'Auto',
            CPUTemperatureIndex=options.temperatureIndex or '-1', CPUVoltageIndex=options.voltageIndex or '-1'},
        registry={[HIVE_USER]={}, [HIVE_MACHINE]={}}, measures={}, meters={}, native={},
        queue={}, now=1000, running=1, runs=0, serial=0, requests={}
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
    measure('MeasureCPUSensorNamesUser', true, false).hive = HIVE_USER
    measure('MeasureCPUSensorNamesMachine', true, false).hive = HIVE_MACHINE
    for _, kind in ipairs({'Temperature', 'Voltage'}) do
        for field in pairs(fieldNames) do
            measure('MeasureCPUSensor' .. kind .. field, true, false)
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
    context:call('Reconnect')
    context:complete(data)
    return context, data
end

local function readings(context, temperature, voltage)
    for slot = 1, 64 do
        equal(context:text('MeterCoreTemperature' .. slot), temperature, 'temperature LP ' .. slot)
        equal(context:text('MeterCoreVoltage' .. slot), voltage, 'voltage LP ' .. slot)
    end
end

local function fieldDisabledOptions(context, disabled)
    for _, kind in ipairs({'Temperature', 'Voltage'}) do
        for field in pairs(fieldNames) do
            local name = 'MeasureCPUSensor' .. kind .. field
            equal(context.measures[name]:GetOption('Disabled'), disabled, name .. ' parsed Disabled')
            equal(context.measures[name].enabled, disabled == '0', name .. ' enabled state')
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

    test('package Celsius and VID populate every logical row honestly', function()
        local context = connect(sensorPath)
        readings(context, '65', '1.25')
        equal(context:text('MeterTableVoltageHeader'), 'VID')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'requested VID, not measured supply voltage')
        contains(context:text('MeterCoreTemperature64', 'ToolTipText'), 'CPU-wide reading shared across logical-processor rows')
        equal(context.runs, 1, 'one discovery launch')
    end)
    test('Fahrenheit and millivolts convert to Celsius and volts', function()
        local context = connect(sensorPath, {temperatureUnit='F', temperatureRaw='98.6', voltageUnit='mV', voltageRaw='1250'})
        readings(context, '37', '1.25')
    end)
    test('actual Vcore uses V header and measured-voltage tooltip', function()
        local context = connect(sensorPath, {voltageKind='VCORE'})
        readings(context, '65', '1.25')
        equal(context:text('MeterTableVoltageHeader'), 'V')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'measured CPU supply voltage')
    end)
    test('bound native fields retain Disabled=0 through forced option rereads', function()
        local context = connect(sensorPath)
        fieldDisabledOptions(context, '0')
        context:refreshNative()
        context:call('Update')
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
    end)
    test('valid numeric zero remains visible; missing ValueRaw is unavailable', function()
        local context, data = connect(sensorPath, {temperatureRaw='0', voltageRaw='0'})
        readings(context, '0', '0.00')
        context:change(data.hive, 'ValueRaw7', nil)
        readings(context, '0', '-')
        contains(context:text('MeterCoreVoltage1', 'ToolTipText'), 'export was removed')
    end)
    test('missing formatted field is rejected even when cached numeric value exists', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value3', nil)
        readings(context, '-', '1.25')
    end)
    test('sensor or label identity swap suppresses the old index', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Sensor3', 'GPU [#0]: Unrelated fixture')
        readings(context, '-', '1.25')
        contains(context:text('MeterCoreTemperature1', 'ToolTipText'), 'Sensor identity changed')
        context:change(data.hive, 'Label7', 'Unrelated voltage')
        readings(context, '-', '-')
    end)
    test('identity retains leading and trailing spaces exactly', function()
        local context = connect(sensorPath, {sensor=' CPU [#0]: Fixture Processor ', temperatureLabel=' CPU Package '})
        readings(context, '65', '1.25')
    end)
    test('changed or absent units reject otherwise valid numbers', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value3', '65 F')
        readings(context, '-', '1.25')
        context:change(data.hive, 'Value7', '1.25')
        readings(context, '-', '-')
    end)
    test('NaN, infinity and non-numeric readings are rejected', function()
        for _, bad in ipairs({'NaN', '1e999', 'not a number', ''}) do
            local context, data = connect(sensorPath)
            context:change(data.hive, 'ValueRaw3', bad)
            context:change(data.hive, 'ValueRaw7', bad)
            readings(context, '-', '-')
        end
    end)
    test('a correct unit suffix without a numeric prefix is rejected', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'Value3', 'unavailable C')
        context:change(data.hive, 'Value7', 'V')
        readings(context, '-', '-')
    end)
    test('temperature and voltage ranges reject unsupported extremes', function()
        for _, pair in ipairs({{'201', '5.01'}, {'-81', '-0.01'}}) do
            local context, data = connect(sensorPath)
            context:change(data.hive, 'ValueRaw3', pair[1])
            context:change(data.hive, 'ValueRaw7', pair[2])
            readings(context, '-', '-')
        end
    end)
    test('decimal comma raw readings convert without accepting grouped numbers', function()
        local context, data = connect(sensorPath)
        context:change(data.hive, 'ValueRaw3', '65,0')
        context:change(data.hive, 'ValueRaw7', '1,25')
        readings(context, '65', '1.25')
        context:change(data.hive, 'ValueRaw7', '1,234,567')
        readings(context, '65', '-')
    end)
    test('stopped HWiNFO process suppresses lingering registry readings', function()
        local context = connect(sensorPath)
        context.running = 0
        context:refreshNative()
        context:call('Update')
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: not running')
        context.running = 1
        context:refreshNative()
        context:call('Update')
        readings(context, '65', '1.25')
    end)
    test('polling does not consume cached completion while reconnect is pending', function()
        local context, data = connect(sensorPath)
        context:call('Reconnect')
        equal(context.runs, 2)
        context:call('Update')
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        context:complete(data)
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
        fieldDisabledOptions(context, '0')
    end)
    test('starting disabled neither launches discovery nor leaves native measures active', function()
        local context = newMock(sensorPath, {enabled='0'})
        context:call('Reconnect')
        equal(context.runs, 0)
        readings(context, '-', '-')
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
            temperatureRaw='47', voltageRaw='1.05', voltageKind='VCORE'})
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
        readings(context, '47', '1.05')
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
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
        equal(context.runs, 2)
    end)
    test('successful output without correlation cannot finish a pending scan', function()
        local context, data = newMock(sensorPath), fixture()
        context:install(data); context:call('Reconnect')
        context:complete({output=data.output}, 1)
        readings(context, '-', '-')
        equal(context:text('MeterSensors'), 'HWiNFO: connecting...')
        context:complete(data)
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
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
        readings(context, '65', '1.25')
    end)
    report[#report + 1] = string.format('%d passed, %d failed, %d total.', results.passed, results.failed, results.total)
    results.report = table.concat(report, '\n')
    assert(results.failed == 0, results.report)
    return results.report
end

return suite
