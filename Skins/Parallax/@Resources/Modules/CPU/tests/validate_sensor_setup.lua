-- Offline CPU Settings sensor-setup checks, compatible with Rainmeter Lua 5.1.
-- suite.Run(absoluteSettingsPath) returns a report or raises the full failure report.
-- SKIN bangs, RunCommand output, time, environment and file access are mocked.
-- Synthetic export indices are fixtures. No settings, processes or files change.
local suite = {}
local HKCU, HKLM = 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE'

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
local function candidate(kind, index, options)
    options = options or {}
    return {kind=kind, index=index, hive=options.hive or HKCU,
        sensor=options.sensor or 'CPU [#0]: Fixture Processor',
        label=options.label or (kind == 'TEMP' and 'CPU Package' or 'Core VIDs'),
        unit=options.unit or (kind == 'TEMP' and 'C' or 'V'),
        voltageKind=kind == 'VOLT' and (options.voltageKind or 'VID') or ''}
end
local function record(item, isCandidate)
    local line = (isCandidate and 'CAND|' or '') .. item.kind .. '|' .. item.hive .. '|' .. item.index
        .. '|' .. hex(item.sensor) .. '|' .. hex(item.label) .. '|' .. item.unit
    if isCandidate or item.kind == 'VOLT' then line = line .. '|' .. item.voltageKind end
    return line
end
local function output(serial, options)
    options = options or {}
    local defaults = {candidate('TEMP', 3), candidate('VOLT', 7)}
    local lines = {'HWINFOV1'}
    for _, item in ipairs(options.selected or defaults) do lines[#lines + 1] = record(item, false) end
    lines[#lines + 1] = 'REQUEST|' .. tostring(serial)
    lines[#lines + 1] = 'STATE|' .. (options.process or 'RUNNING')
    for _, item in ipairs(options.candidates or defaults) do lines[#lines + 1] = record(item, true) end
    for _, message in ipairs(options.messages or {}) do lines[#lines + 1] = 'STATUS|' .. message end
    return table.concat(lines, '\n') .. '\n'
end

local function newMock(settingsPath, preferences)
    local context = {variables={['@']='X:\\fixture\\', CPUSensorHive='Auto',
        CPUTemperatureIndex='-1', CPUVoltageIndex='-1'}, persisted={}, meters={},
        queue={}, writes={}, groupWrites={}, applies=0, reconnects=0, runs=0,
        serial=0, timers={}, now=1000, opens=0, launches=0, closes=0, setOptions=0,
        folder='C:\\Program Files', fileExists=false}
    for key, value in pairs(preferences or {}) do context.variables[key] = value end
    context.discovery = {value=0, string='', options={}}
    function context.discovery:GetValue() return self.value end
    function context.discovery:GetStringValue() return self.string end
    function context.discovery:GetOption(key, fallback) return self.options[key] or fallback or '' end
    local skin = {}
    function skin:GetVariable(key, fallback) return context.variables[key] or fallback end
    function skin:GetMeasure(name)
        equal(name, 'MeasureCPUSettingsDiscover', 'discovery measure')
        return context.discovery
    end
    function skin:Bang(...)
        if select(1, ...) == '!SetOption' then
            -- A final gsub expression returns text AND its substitution count.
            -- Passing both to Bang silently treats the count as a target skin.
            equal(select('#', ...), 4, '!SetOption argument count (unexpected target skin)')
            context.setOptions = context.setOptions + 1
        end
        context.queue[#context.queue + 1] = {...}
    end
    local environment = {SKIN=skin,
        os={time=function() return context.now end, date=function() return '12:34:56' end,
            getenv=function(key)
                assert(key == 'ProgramW6432' or key == 'ProgramFiles', 'Unexpected environment lookup: ' .. key)
                return context.folder
            end},
        io={open=function(path, mode)
            context.opens = context.opens + 1
            equal(mode, 'rb', 'read-only existence check')
            equal(path, context.folder .. '\\HWiNFO64\\HWiNFO64.exe', 'local install path')
            if context.fileExists then return {close=function() context.closes = context.closes + 1 end} end
            return nil
        end}}
    environment._G = environment
    setmetatable(environment, {__index=_G})
    local chunk
    if setfenv then chunk = assert(loadfile(settingsPath)); setfenv(chunk, environment)
    else chunk = assert(loadfile(settingsPath, 't', environment)) end
    chunk()
    context.environment = environment
    function context:flush()
        for _, args in ipairs(self.queue) do
            local bang, name = args[1], args[2]
            if bang == '!SetOption' then
                local target
                if name == 'MeasureCPUSettingsDiscover' then target = self.discovery.options
                else self.meters[name] = self.meters[name] or {}; target = self.meters[name] end
                target[args[3]] = tostring(args[4])
            elseif bang == '!SetVariable' then self.variables[name] = tostring(args[3])
            elseif bang == '!WriteKeyValue' then
                equal(name, 'Variables', 'persisted section')
                equal(args[5], 'X:\\fixture\\User\\CPU.inc', 'CPU-only preference file')
                self.persisted[args[3]] = tostring(args[4])
                self.writes[#self.writes + 1] = {key=args[3], value=tostring(args[4])}
            elseif bang == '!SetVariableGroup' then
                equal(args[4], 'ParallaxCPU', 'CPU-only variable group')
                self.groupWrites[name] = tostring(args[3])
            elseif bang == '!UpdateMeasureGroup' then
                equal(args[3], '*', 'group target')
                if name == 'ParallaxCPUApply' then self.applies = self.applies + 1
                elseif name == 'ParallaxCPUSensorReconnect' then self.reconnects = self.reconnects + 1
                else error('Unexpected updated group: ' .. tostring(name)) end
            elseif bang == '!UpdateMeasure' then equal(name, 'MeasureCPUSettingsDiscover')
            elseif bang == '!CommandMeasure' then
                equal(name, 'MeasureCPUSettingsDiscover'); equal(args[3], 'Run')
                self.runs = self.runs + 1
            elseif bang:find('[!Delay ', 1, true) then
                local serial = tonumber(bang:match('SensorScanTimeout%((%d+)%)'))
                assert(serial, 'Timeout must carry a request serial')
                self.serial = serial
                self.timers[#self.timers + 1] = serial
            elseif bang:sub(1, 2) == '["' then self.launches = self.launches + 1
            elseif bang ~= '!UpdateMeterGroup' and bang ~= '!Redraw' then
                error('Unexpected production bang: ' .. tostring(bang))
            end
        end
        self.queue = {}
    end
    function context:call(name, ...)
        local result = assert(self.environment[name], 'Missing function: ' .. name)(...)
        self:flush()
        return result
    end
    function context:text(meter, option) return (self.meters[meter] or {})[option or 'Text'] end
    function context:complete(options, status, serial)
        self.discovery.string = type(options) == 'string' and options or output(serial or self.serial, options)
        self.discovery.value = status or 1
        self:call('ApplySensorScan')
    end
    function context:scan(options)
        self:call('ScanSensors')
        self:complete(options)
    end
    context:call('Initialize')
    context:call('Update')
    return context
end

function suite.Run(settingsPath)
    assert(type(settingsPath) == 'string' and settingsPath ~= '', 'Pass the absolute Settings.lua path')
    local passed, failed, report = 0, 0, {'Offline CPU sensor setup: mocked provider, clock, IO and queued bangs.'}
    local function test(name, action)
        local okay, failure = pcall(action)
        if okay then passed = passed + 1; report[#report + 1] = 'PASS ' .. name
        else failed = failed + 1; report[#report + 1] = 'FAIL ' .. name .. ': ' .. tostring(failure) end
    end

    test('regular updates do not scan or write settings', function()
        local c = newMock(settingsPath)
        for _ = 1, 20 do c.now = c.now + 1; c:call('Update') end
        equal(c.runs, 0); equal(#c.writes, 0); equal(c.opens, 0)
        c:scan()
        for _ = 1, 20 do c:call('Update') end
        equal(c.runs, 1); equal(#c.writes, 0)
    end)
    test('scan is one-shot, correlated and rejects duplicate click', function()
        local c = newMock(settingsPath)
        equal(c:call('ScanSensors'), true)
        equal(c:call('ScanSensors'), false)
        equal(c.runs, 1)
        contains(c.discovery.options.Parameter, '-List -Hive Auto')
        contains(c.discovery.options.Parameter, '-RequestId ' .. c.serial)
        c:complete()
        equal(c:text('MeterSettingsTemperatureValue'), 'Auto: CPU Package')
        equal(c:text('MeterSettingsVoltageValue'), 'Auto: Core VIDs')
        contains(c:text('MeterSettingsSensorStatus'), '12:34:56')
        equal(#c.writes, 0)
    end)
    test('named temperature choices cycle Auto, each index, then Auto', function()
        local c = newMock(settingsPath)
        local choices = {candidate('TEMP', 3), candidate('TEMP', 8, {label='CPU (Tctl/Tdie)'})}
        c:scan({candidates=choices})
        local initialReconnects = c.reconnects
        for _, index in ipairs({'3', '8', '-1'}) do
            equal(c:call('CycleSensor', 'TEMP'), true)
            equal(c.persisted.CPUTemperatureIndex, index)
            equal(c.groupWrites.CPUTemperatureIndex, index)
            c:complete({candidates=choices})
            if index ~= '-1' then contains(c:text('MeterSettingsTemperatureValue'), ' / ' .. index) end
        end
        equal(c.reconnects, initialReconnects + 3); equal(c.persisted.CPUVoltageIndex, nil)
    end)
    test('voltage choices retain VID and measured voltage names', function()
        local c = newMock(settingsPath)
        local choices = {candidate('VOLT', 7), candidate('VOLT', 9, {label='Vcore', voltageKind='VCORE'})}
        c:scan({candidates=choices})
        c:call('CycleSensor', 'VOLT'); c:complete({candidates=choices})
        equal(c:text('MeterSettingsVoltageValue'), 'Core VIDs / 7')
        c:call('CycleSensor', 'VOLT'); c:complete({candidates=choices})
        equal(c:text('MeterSettingsVoltageValue'), 'Vcore / 9')
        c:call('CycleSensor', 'VOLT'); c:complete({candidates=choices})
        equal(c.persisted.CPUVoltageIndex, '-1')
    end)
    test('mirrored hive candidates deduplicate into one selectable index', function()
        local c = newMock(settingsPath)
        local choices = {candidate('TEMP', 3), candidate('TEMP', 3, {hive=HKLM})}
        c:scan({candidates=choices})
        c:call('CycleSensor', 'TEMP'); equal(c.persisted.CPUTemperatureIndex, '3')
        c:complete({candidates=choices})
        c:call('CycleSensor', 'TEMP'); equal(c.persisted.CPUTemperatureIndex, '-1')
    end)
    test('same index with conflicting identities is excluded', function()
        local c = newMock(settingsPath)
        local choices = {candidate('TEMP', 3), candidate('TEMP', 3, {hive=HKLM, sensor='CPU [#0]: Other sensor'}), candidate('TEMP', 8)}
        c:scan({selected={}, candidates=choices})
        contains(c:text('MeterSettingsSensorDetail'), 'Conflicting exports')
        c:call('CycleSensor', 'TEMP')
        equal(c.persisted.CPUTemperatureIndex, '8')
    end)
    test('scope cycle resets both indices and only reconnects CPU', function()
        local c = newMock(settingsPath, {CPUTemperatureIndex='3', CPUVoltageIndex='7'})
        for _, item in ipairs({{'HKCU', HKCU}, {'HKLM', HKLM}, {'Auto', 'Auto'}}) do
            equal(c:call('CycleSensorHive'), true)
            equal(c.persisted.CPUSensorHive, item[1])
            equal(c.persisted.CPUTemperatureIndex, '-1')
            equal(c.persisted.CPUVoltageIndex, '-1')
            contains(c.discovery.options.Parameter, '-Hive ' .. item[2])
            contains(c.discovery.options.Parameter, '-TemperatureIndex -1 -VoltageIndex -1')
            c:complete()
        end
        equal(c.reconnects, 3); equal(#c.writes, 9)
    end)
    test('empty exports and first sensor click never save a fake selection', function()
        local c = newMock(settingsPath)
        equal(c:call('CycleSensor', 'TEMP'), true)
        equal(c.runs, 1); equal(#c.writes, 0)
        c:complete({selected={}, candidates={}})
        local initialReconnects = c.reconnects
        equal(c:call('CycleSensor', 'TEMP'), false)
        equal(c:call('CycleSensor', 'VOLT'), false)
        equal(#c.writes, 0); equal(c.reconnects, initialReconnects)
        equal(c:text('MeterSettingsTemperatureValue'), 'Auto: not found')
    end)
    test('vanished manual sensor can reset to Auto with no exported choices', function()
        for _, item in ipairs({{'TEMP', 'CPUTemperatureIndex', 'MeterSettingsTemperatureValue'},
                {'VOLT', 'CPUVoltageIndex', 'MeterSettingsVoltageValue'}}) do
            local c = newMock(settingsPath, {[item[2]]='99'})
            c:scan({selected={}, candidates={}})
            equal(c:text(item[3]), 'Export 99: unavailable')
            local initialReconnects, initialWrites = c.reconnects, #c.writes
            equal(c:call('CycleSensor', item[1]), true)
            equal(c.persisted[item[2]], '-1', 'vanished manual index resets to Auto')
            equal(c.groupWrites[item[2]], '-1', 'Auto selection reaches CPU Meter')
            equal(c.reconnects, initialReconnects + 1)
            equal(#c.writes, initialWrites + 1)
            c:complete({selected={}, candidates={}})
            equal(c:text(item[3]), 'Auto: not found')
            equal(c:call('CycleSensor', item[1]), false)
            equal(#c.writes, initialWrites + 1, 'empty Auto selection does not write again')
            equal(c.reconnects, initialReconnects + 1, 'empty Auto selection does not reconnect again')
        end
    end)
    test('sensor display Off persists through scan and selection', function()
        local c = newMock(settingsPath)
        c:call('Toggle', 'CPUSensorsEnabled')
        equal(c.persisted.CPUSensorsEnabled, '0'); equal(c.applies, 1)
        c:scan(); c:call('CycleSensor', 'TEMP'); c:complete()
        equal(c.variables.CPUSensorsEnabled, '0')
        equal(c:text('MeterSettingsSensorsValue'), 'Off')
        local reloaded = newMock(settingsPath, c.persisted)
        equal(reloaded:text('MeterSettingsSensorsValue'), 'Off')
        equal(reloaded.variables.CPUTemperatureIndex, '3')
    end)
    test('failed helper and malformed protocol do not persist choices', function()
        for _, item in ipairs({{text='unrelated\n', status=1}, {text='HWINFOV1\n', status=101}}) do
            local c = newMock(settingsPath)
            c:call('ScanSensors'); c:complete(item.text, item.status)
            contains(c:text('MeterSettingsSensorStatus'), 'failed')
            equal(#c.writes, 0); equal(c:text('MeterSettingsScan'), 'Scan sensors')
        end
    end)
    test('timeout ignores late result until a deliberate retry', function()
        local c = newMock(settingsPath)
        c:call('ScanSensors'); local old = c.serial
        c:call('SensorScanTimeout', old)
        contains(c:text('MeterSettingsSensorStatus'), 'timed out')
        c:complete(nil, 1, old)
        contains(c:text('MeterSettingsSensorStatus'), 'timed out')
        equal(#c.writes, 0)
    end)
    test('old timeout cannot cancel a newer scan', function()
        local c = newMock(settingsPath)
        c:scan(); local old = c.serial
        c:call('ScanSensors')
        c:call('SensorScanTimeout', old)
        equal(c:text('MeterSettingsScan'), 'Scanning...')
        c:complete()
        contains(c:text('MeterSettingsSensorStatus'), 'HWiNFO running')
    end)
    test('late previous callback cannot complete the retried scan', function()
        local c = newMock(settingsPath)
        c:call('ScanSensors'); local old = c.serial
        c:call('SensorScanTimeout', old)
        c:call('ScanSensors'); local current = c.serial
        assert(current ~= old, 'Retry must receive a new request serial')
        c:complete(nil, 1, old)
        equal(c:text('MeterSettingsScan'), 'Scanning...', 'old result must leave new scan pending')
        equal(c:text('MeterSettingsTemperatureValue'), 'Auto: scan to detect')
        c:complete(nil, 1, current)
        equal(c:text('MeterSettingsTemperatureValue'), 'Auto: CPU Package')
        equal(#c.writes, 0)
    end)
    test('successful output missing request correlation leaves scan pending', function()
        local c = newMock(settingsPath)
        c:call('ScanSensors')
        c:complete((output(c.serial):gsub('REQUEST|%d+\n', '')))
        equal(c:text('MeterSettingsScan'), 'Scanning...')
        equal(#c.writes, 0)
        equal(c:text('MeterSettingsTemperatureValue'), 'Auto: scan to detect')
        c:complete(); equal(c:text('MeterSettingsScan'), 'Scan sensors')
    end)
    test('stopped or unknown provider does not claim live readings', function()
        for _, item in ipairs({{'STOPPED', 'not running'}, {'UNKNOWN', 'status unknown'}}) do
            local c = newMock(settingsPath)
            c:scan({process=item[1]})
            contains(c:text('MeterSettingsSensorStatus'), item[2]); equal(#c.writes, 0)
        end
    end)
    test('provider labels are sanitized before meter text or tooltip', function()
        local c = newMock(settingsPath)
        local strange = candidate('TEMP', 3, {sensor='CPU [#0]: "Fixture"\n[!Fake]', label='CPU #Package\r[brackets] "quote"'})
        c:scan({selected={strange}, candidates={strange}})
        local text = c:text('MeterSettingsTemperatureValue')
        local tooltip = c:text('MeterSettingsTemperatureValue', 'ToolTipText')
        assert(not text:find('[%c#%[%]"]') and not tooltip:find('[%c#%[%]"]'), 'unsafe provider syntax reached meter')
        contains(text, '(brackets)'); equal(c.launches, 0); equal(#c.writes, 0)
    end)
    test('sanitized text does not forward gsub count as a target skin', function()
        local c = newMock(settingsPath)
        local before = c.setOptions
        local quoted = candidate('TEMP', 3, {sensor='CPU [#0]: "Fixture"', label='CPU "Package"'})
        c:scan({selected={quoted}, candidates={quoted}})
        assert(c.setOptions > before, 'Expected sensor meter updates')
        equal(c:text('MeterSettingsTemperatureValue'), "Auto: CPU 'Package'")
        -- The mock validates exact vararg count on every SetOption, including
        -- ordinary strings whose gsub substitution count would have been zero.
        c:call('Update')
    end)
    test('malformed candidate fields are excluded from saved choices', function()
        local malformed = {'CAND|TEMP|' .. HKCU .. '|5000|43|50|C|',
            'CAND|TEMP|' .. HKCU .. '|3|zz|50|C|',
            'CAND|TEMP|BAD|3|43|50|C|', 'CAND|TEMP|' .. HKCU .. '|3|43|50|W|',
            'CAND|VOLT|' .. HKCU .. '|7|43|50|V|UNKNOWN'}
        local c = newMock(settingsPath)
        c:call('ScanSensors')
        c:complete(output(c.serial, {selected={}, candidates={}}) .. table.concat(malformed, '\n') .. '\n')
        equal(c:call('CycleSensor', 'TEMP'), false); equal(c:call('CycleSensor', 'VOLT'), false)
        equal(#c.writes, 0)
    end)
    test('candidate parsing cap excludes a valid record after 128 candidates', function()
        local c = newMock(settingsPath)
        c:call('ScanSensors')
        local lines = {output(c.serial, {selected={}, candidates={}})}
        for _ = 1, 128 do lines[#lines + 1] = 'CAND|TEMP|BAD|3|43|50|C|' end
        lines[#lines + 1] = record(candidate('TEMP', 3), true)
        c:complete(table.concat(lines, '\n') .. '\n')
        equal(c:call('CycleSensor', 'TEMP'), false); equal(#c.writes, 0)
    end)
    test('invalid persisted indices and scope cannot enter command arguments', function()
        local c = newMock(settingsPath, {CPUSensorHive='Auto -Bad', CPUTemperatureIndex='3 -Bad', CPUVoltageIndex='99999'})
        c:call('ScanSensors')
        contains(c.discovery.options.Parameter, '-Hive Auto -TemperatureIndex -1 -VoltageIndex -1')
        assert(not c.discovery.options.Parameter:find('-Bad', 1, true))
        equal(#c.writes, 0)
    end)
    test('manual unavailable index returns to Auto without guessing', function()
        local c = newMock(settingsPath, {CPUTemperatureIndex='99'})
        c:scan()
        equal(c:text('MeterSettingsTemperatureValue'), 'Export 99: unavailable')
        c:call('CycleSensor', 'TEMP')
        equal(c.persisted.CPUTemperatureIndex, '-1')
    end)
    test('scope and sensor changes are blocked while scanning', function()
        local c = newMock(settingsPath)
        c:call('ScanSensors')
        equal(c:call('CycleSensorHive'), false); equal(c:call('CycleSensor', 'TEMP'), false)
        equal(c:call('CycleSensor', 'BAD'), false)
        equal(#c.writes, 0); equal(c.runs, 1)
    end)
    test('Open HWiNFO uses only mocked safe local path or helpful missing state', function()
        local c = newMock(settingsPath)
        c:call('OpenHWiNFO')
        contains(c:text('MeterSettingsSensorDetail'), 'manually')
        equal(c.opens, 1); equal(c.launches, 0)
        c.fileExists = true; c:call('OpenHWiNFO')
        equal(c.opens, 2); equal(c.launches, 1); equal(c.closes, 1)
        c.folder = 'C:\\Unsafe[!Fake]'; c:call('OpenHWiNFO')
        equal(c.opens, 2); equal(c.launches, 1); equal(#c.writes, 0)
    end)

    report[#report + 1] = string.format('%d passed, %d failed, %d total.', passed, failed, passed + failed)
    local text = table.concat(report, '\n')
    assert(failed == 0, text)
    return text
end

return suite
