-- Original isolated Lua 5.1 regressions. Driver, files and time are fixtures.
-- No process, live provider, registry or persistent preference is touched.
local Suite = {}
function Suite.run(path)
    local total, failed, lines = 0, 0, {}
    local function eq(actual, expected, label)
        total = total + 1
        if actual ~= expected then error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
    end
    local function contains(value, part) eq(not not tostring(value):find(part, 1, true), true, part) end
    local function test(name, body)
        local pass, err = pcall(body)
        lines[#lines + 1] = (pass and 'PASS: ' or 'FAIL: ') .. name .. (pass and '' or ': ' .. tostring(err))
        if not pass then failed = failed + 1 end
    end
    local function hex(value) return (value:gsub('.', function(c) return string.format('%02X', c:byte()) end)) end
    local adapter = 'Fixture Graphics 9000'
    local luid, token = '0123456789ABCDEF', '0123456789abcdef0123456789abcdef'
    local namesOnlyLuid = string.rep('0', 16)
    local tempRoot = 'C:\\Fixture Temp'
    local base = tempRoot .. '\\Parallax-GPU-' .. token
    local dataPath, leasePath, tmpPath = base .. '.dat', base .. '.lease', base .. '.tmp'
    local foreignPath = tempRoot .. '\\Parallax-GPU-another-session.dat'
    local info, bootstrap, driver = 'MeasureGPUInfo', 'MeasureGPUTemperatureBootstrap', 'MeasureGPUTemperatureDriver'
    local metadata = 'OK|' .. adapter .. '|8589934592|GDDR6|Vendor|PHYSICAL|1600000|1900000\nGPU_ADAPTER|1|' .. luid
    local function sessionOutput(overrides)
        local f = {'GPU_TEMP_SESSION', '1', token, hex(dataPath), luid}
        for key, value in pairs(overrides or {}) do f[key] = value end
        return table.concat(f, '|')
    end
    local meterNames = {MeterTemperatureValue = true, MeterActivityValue = true, MeterGPUVRAMValue = true,
        MeterGPUVRAMBar = true, MeterGPUSharedValue = true, MeterGPULoadValue = true,
        MeterGPUControllerLoadValue = true, MeterGPUVideoLoadValue = true, MeterGPUBusLoadValue = true,
        MeterGPULoadBar = true, MeterGPUControllerLoadBar = true, MeterGPUVideoLoadBar = true, MeterGPUBusLoadBar = true,
        MeterPowerValue = true, MeterClockValue = true}
    local loadMeters = {'MeterGPULoadValue', 'MeterGPUControllerLoadValue',
        'MeterGPUVideoLoadValue', 'MeterGPUBusLoadValue'}
    local loadBars = {'MeterGPULoadBar', 'MeterGPUControllerLoadBar',
        'MeterGPUVideoLoadBar', 'MeterGPUBusLoadBar'}
    -- Engine bars span the Engine table track (ContentWidth - 102 * Scale); the VRAM bar keeps the full ContentWidth.
    local engineWidth = 98 -- fixture ContentWidth 200, Scale 1
    local registryNames = {MeasureGPURegistryNames = true}
    for _, field in ipairs({'Power', 'Clock'}) do
        for _, suffix in ipairs({'Sensor', 'Label', 'Value', 'ValueRaw'}) do registryNames['MeasureGPU' .. field .. suffix] = true end
    end
    local function canonical(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
    local function fixture(options)
        options = options or {}
        local f = {now = 1000, calls = {}, meter = {}, meters = {}, parameters = {}, launches = {}, kills = {}, reads = {},
            registryEnables = {}, registryUpdates = {}, initializing = false,
            files = {[foreignPath] = 'preserve'}, removed = {}, leaseWrites = 0, vars = options.vars or {},
            statuses = {[info] = options.infoStatus or 1, [bootstrap] = options.bootstrapStatus or -1, [driver] = options.driverStatus or -1},
            outputs = {[info] = options.metadata or metadata, [bootstrap] = '', [driver] = '', MeasureGPUProcessController = options.pids or '?'},
            exports = {MeasureGPURegistryNames = 'Sensor3|Label3|Value3|ValueRaw3|Sensor4|Label4|Value4|ValueRaw4',
                MeasureGPUPowerSensor = adapter, MeasureGPUPowerLabel = 'GPU Power',
                MeasureGPUPowerValue = '77.7 W', MeasureGPUPowerValueRaw = '77.7',
                MeasureGPUClockSensor = adapter, MeasureGPUClockLabel = 'GPU Clock',
                MeasureGPUClockValue = '1234.5 MHz', MeasureGPUClockValueRaw = '1234.5'}}
        for name, value in pairs(options.exports or {}) do f.exports[name] = value end
        local allowedFiles = {[dataPath] = true, [leasePath] = true, [tmpPath] = true}
        f.meters.MeterTemperatureValue = f.meter
        f.vars.Scale = f.vars.Scale or '1'
        f.vars.ContentWidth = f.vars.ContentWidth or '200'
        f.vars.DataBarThickness = f.vars.DataBarThickness or '6'
        f.vars.DataBarThicknessPx = f.vars.DataBarThicknessPx or '(Max(1,Round(#DataBarThickness#*#Scale#)))'
        f.vars.GPUEngineBarWidth = f.vars.GPUEngineBarWidth or '(#ContentWidth#-102*#Scale#)'
        local panelFormula, engineFormula = '(#PanelWidth#-2*#Padding#)', '(#ContentWidth#-102*#Scale#)'
        -- Rainmeter expands nested variables fully, so a derived ContentWidth appears inside the engine width.
        local function expandedWidth() return f.vars.ContentWidth == panelFormula and '(220-2*10)' or f.vars.ContentWidth end
        local skin = {}
        function skin:GetVariable(name, fallback)
            assert(name == 'MetricsInterval' or name == 'SensorInterval' or name == 'ContentWidth'
                or name == 'GPUEngineBarWidth' or name == 'DataBarThicknessPx' or name == 'GPUEnableSensors'
                or name:match('^GPUPowerSource$') or name:match('^GPUClockSource$')
                or name:match('^GPUPowerIndex$') or name:match('^GPUPowerSensor$') or name:match('^GPUPowerLabel$')
                or name:match('^GPUClockIndex$') or name:match('^GPUClockSensor$') or name:match('^GPUClockLabel$'),
                'unexpected variable or HWiNFO dependency: ' .. name)
            return f.vars[name] or fallback
        end
        function skin:ReplaceVariables(raw)
            if raw == panelFormula then return '(220-2*10)' end
            if raw == engineFormula then return '(' .. expandedWidth() .. '-102*' .. f.vars.Scale .. ')' end
            assert(raw == '(Max(1,Round(#DataBarThickness#*#Scale#)))', 'unexpected geometry expansion')
            return '(Max(1,Round(' .. f.vars.DataBarThickness .. '*' .. f.vars.Scale .. ')))'
        end
        function skin:ParseFormula(raw)
            if raw == '((220-2*10))' then return 200 end
            if raw == '((' .. expandedWidth() .. '-102*' .. f.vars.Scale .. '))' then
                local width = f.vars.ContentWidth == panelFormula and 200 or tonumber(f.vars.ContentWidth)
                local scale = tonumber(f.vars.Scale)
                return width and scale and width - 102 * scale or nil
            end
            assert(raw == '((Max(1,Round(' .. f.vars.DataBarThickness .. '*' .. f.vars.Scale .. '))))', 'unexpected geometry formula')
            local thickness, scale = tonumber(f.vars.DataBarThickness), tonumber(f.vars.Scale)
            return thickness and scale and math.max(1, math.floor(thickness * scale + 0.5)) or nil
        end
        function skin:GetMeasure(name)
            if registryNames[name] then
                assert(canonical(f.vars.GPUEnableSensors) == '1', 'disabled HWiNFO export accessed: ' .. name)
                local field = name:match('^MeasureGPU(Power)') or name:match('^MeasureGPU(Clock)')
                if field then assert(canonical(f.vars['GPU' .. field .. 'Source']) == '1', 'unselected HWiNFO export accessed: ' .. name)
                else assert(name == 'MeasureGPURegistryNames' and (canonical(f.vars.GPUPowerSource) == '1' or canonical(f.vars.GPUClockSource) == '1'),
                    'registry inventory accessed without an explicit HWiNFO source') end
                assert(f.registryEnables[name] == 1 and f.registryUpdates[name] == 1, 'export read before one-time initialization: ' .. name)
                if f.exports[name] == false then return nil end
                return {GetValue = function() return 0 end,
                    GetStringValue = function() f.reads[name] = (f.reads[name] or 0) + 1; return f.exports[name] end}
            end
            if name == 'MeasureGPUProcessController' then
                return {GetStringValue = function() f.reads[name] = (f.reads[name] or 0) + 1; return f.outputs[name] end}
            end
            assert(f.statuses[name] ~= nil, 'unexpected measure or HWiNFO dependency: ' .. name)
            if options.missingInfo and name == info then return nil end
            return {GetValue = function() return f.statuses[name] end,
                GetStringValue = function() f.reads[name] = (f.reads[name] or 0) + 1; return f.outputs[name] end}
        end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = {command, unpack(args)}
            if command == '!SetOption' then
                assert(#args == 3 and type(args[3]) == 'string', 'scalar option required')
                if meterNames[args[1]] then
                    local isBar = args[1]:find('Bar$') ~= nil
                    assert(args[2] == 'ToolTipText' or (isBar and args[2] == 'Shape2')
                        or (not isBar and args[2] == 'Text'), 'unexpected meter option')
                    if args[2] ~= 'Shape2' then assert(not args[3]:find('[#%[%]"%c]'), 'unsafe display data') end
                    f.meters[args[1]] = f.meters[args[1]] or {}
                    f.meters[args[1]][args[2]] = args[3]
                else
                    assert((args[1] == bootstrap or args[1] == driver) and args[2] == 'Parameter', 'unexpected helper option')
                    assert(args[3]:find("ReadAllText('DriverTemperature.cs.txt')", 1, true), 'fixed source only')
                    f.parameters[args[1]] = args[3]
                end
            elseif command == '!CommandMeasure' then
                assert(#args == 2 and (args[1] == bootstrap or args[1] == driver), 'unexpected subprocess target')
                if args[2] == 'Run' then
                    assert(f.parameters[args[1]], 'helper must have a parameter')
                    f.launches[args[1]] = (f.launches[args[1]] or 0) + 1
                    f.statuses[args[1]] = 0 -- Native RunCommand RUN state; initial is -1.
                elseif args[2] == 'Kill' then
                    assert((f.launches[args[1]] or 0) > 0, 'cannot kill a never-launched helper')
                    assert(f.statuses[args[1]] == 0, 'only native RUN state0 may be killed')
                    local previous = f.calls[#f.calls - 1]
                    assert(previous and previous[1] == '!UpdateMeasure' and previous[2] == args[1],
                        'refresh cached RunCommand status immediately before Kill')
                    f.kills[args[1]] = (f.kills[args[1]] or 0) + 1
                else error('unexpected helper command') end
            elseif command == '!EnableMeasure' then
                assert(#args == 1 and registryNames[args[1]], 'only known registry measures may be enabled')
                assert(f.initializing, 'registry enabling must happen only at initialization')
                assert(canonical(f.vars.GPUEnableSensors) == '1', 'disabled override bank enabled')
                local field = args[1]:match('^MeasureGPU(Power)') or args[1]:match('^MeasureGPU(Clock)')
                if field then assert(canonical(f.vars['GPU' .. field .. 'Source']) == '1', 'unselected override bank enabled')
                else assert(canonical(f.vars.GPUPowerSource) == '1' or canonical(f.vars.GPUClockSource) == '1', 'unselected inventory enabled') end
                f.registryEnables[args[1]] = (f.registryEnables[args[1]] or 0) + 1
                assert(f.registryEnables[args[1]] == 1, 'registry measure enabled repeatedly')
            elseif command == '!UpdateMeasure' then
                assert(#args == 1)
                if registryNames[args[1]] then
                    assert(f.initializing and f.registryEnables[args[1]] == 1, 'registry update must follow initialization enable')
                    f.registryUpdates[args[1]] = (f.registryUpdates[args[1]] or 0) + 1
                    assert(f.registryUpdates[args[1]] == 1, 'registry update repeatedly forced')
                else
                    assert(args[1] == bootstrap or args[1] == driver, 'unexpected forced update')
                    if f.statusOnRefresh and f.statusOnRefresh[args[1]] ~= nil then
                        f.statuses[args[1]] = f.statusOnRefresh[args[1]]
                        f.statusOnRefresh[args[1]] = nil
                    end
                end
            elseif command == '!UpdateMeterGroup' then assert(#args == 1 and args[1] == 'GPUDriverReadout')
            elseif command == '!Redraw' then assert(#args == 0)
            else error('unexpected write/action ' .. tostring(command)) end
        end
        local fakeio = {}
        function fakeio.open(filename, mode)
            assert(allowedFiles[filename], 'access outside own session: ' .. tostring(filename))
            if mode == 'wb' then
                assert(filename == leasePath, 'only lease can be written')
                if f.failOpen then return nil end
                local handle = {}
                function handle:write(value)
                    assert(type(value) == 'string' and value:match('^' .. token .. '|%d+|%d+|[%d,?]+$'), 'invalid lease')
                    if f.failWrite then return nil end
                    f.files[filename] = value; f.leaseWrites = f.leaseWrites + 1; return self
                end
                function handle:close() return not f.failClose or nil end
                return handle
            end
            assert(mode == 'rb' and filename == dataPath, 'unexpected file mode/read')
            if f.files[filename] == nil then return nil end
            local handle = {close = function() return true end}
            function handle:read(count)
                assert(count == 8193, 'snapshot read must be bounded')
                if f.nilRead then return nil end
                return f.files[filename]:sub(1, count)
            end
            return handle
        end
        local function forbidden() error('unexpected external work') end
        local blocked = setmetatable({}, {__index = function() return forbidden end})
        local fakeos = {
            time = function() return f.now end,
            getenv = function(key)
                assert(key == 'TMP' or key == 'TEMP', 'unexpected environment access')
                return key == 'TMP' and tempRoot or 'C:\\Other Fixture Temp'
            end,
            remove = function(filename)
                assert(allowedFiles[filename], 'cleanup outside own session')
                f.removed[filename] = (f.removed[filename] or 0) + 1; f.files[filename] = nil; return true
            end
        }
        local env = setmetatable({SKIN = skin, SELF = {}, io = fakeio, os = setmetatable(fakeos, {__index = function() return forbidden end}),
            package = blocked, debug = blocked, require = forbidden, dofile = forbidden, loadfile = forbidden, loadstring = forbidden}, {__index = _G})
        env._G = env
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk(); f.env = env
        function f:update() local n, names = self.env.Update(); self.names = names; return n, names end
        function f:sample(overrides)
            local values = {'GPU_TEMP', '4', token, '1', tostring(self.now), 'OK', '42', luid, hex(adapter),
                'OK', '8589934592', '8053063680', '6442450944', 'OK', '182452224', '182452224',
                'OK', '25', '50', '75', '100', 'OK', '55321', 'OK', '1607500',
                (self.files[leasePath] or ''):match('|%d+|(%d+)|') or '0', '?'}
            for key, value in pairs(overrides or {}) do values[key] = value end
            self.files[dataPath] = table.concat(values, '|')
        end
        function f:start(output)
            self.outputs[bootstrap] = output or sessionOutput(); self.statuses[bootstrap] = 1; self:update()
        end
        function f:live(overrides) self:start(); self:sample(overrides); self:update() end
        function f:clear() self.calls = {} end
        function f:text(meter) return self.meters[meter] and self.meters[meter].Text end
        function f:tip(meter) return self.meters[meter] and self.meters[meter].ToolTipText end
        function f:bar(meter)
            meter = meter or 'MeterGPUVRAMBar'
            local shape = assert(self.meters[meter], 'missing bar ' .. meter).Shape2
            local y, endpoint, y2, stroke = shape:match('^Line 0,([%d.]+),([%d.]+),([%d.]+) | StrokeWidth ([%d.]+)')
            assert(y and y == y2, 'invalid horizontal bar geometry')
            return tonumber(endpoint), tonumber(stroke), tonumber(y)
        end
        function f:allUnavailable()
            eq(self.meter.Text, 'Unavailable')
            eq(self:text('MeterActivityValue'), '--')
            contains(self:text('MeterGPUVRAMValue'), '--')
            contains(self:text('MeterGPUSharedValue'), '--')
            for _, name in ipairs(loadMeters) do eq(self:text(name), '--') end
            if canonical(self.vars.GPUPowerSource) ~= '1' then eq(self:text('MeterPowerValue'), 'Unavailable') end
            if canonical(self.vars.GPUClockSource) ~= '1' then eq(self:text('MeterClockValue'), 'Unavailable') end
            local endpoint, stroke = self:bar(); eq(endpoint, 0); eq(stroke, 0)
            for _, name in ipairs(loadBars) do
                local engineEndpoint, engineStroke = self:bar(name); eq(engineEndpoint, 0, name); eq(engineStroke, 0, name)
            end
        end
        function f:ownedClean()
            eq(self.files[dataPath], nil); eq(self.files[leasePath], nil); eq(self.files[tmpPath], nil)
            eq(self.files[foreignPath], 'preserve', 'other sessions remain untouched')
        end
        f.initializing = true; env.Initialize(); f.initializing = false; env.Update(); return f
    end
    local function manualOptions(power, clock)
        return {vars = {GPUEnableSensors = '1', GPUPowerSource = power and '1' or '0', GPUClockSource = clock and '1' or '0',
            GPUPowerIndex = '3', GPUPowerSensor = adapter, GPUPowerLabel = 'GPU Power',
            GPUClockIndex = '4', GPUClockSensor = adapter, GPUClockLabel = 'GPU Clock'}}
    end
    test('metadata, bootstrap and driver each start once without a HWiNFO dependency', function()
        local f = fixture({vars = {GPUEnableSensors = '0', GPUTemperatureIndex = '77'}})
        eq(f.meter.Text, 'Checking...'); eq(f.reads[info], 1); eq(f.launches[bootstrap], 1); eq(f.launches[driver], nil)
        contains(f.parameters[bootstrap], "CreateSession('" .. luid .. "',2000)")
        for _ = 1, 4 do f:update() end; eq(f.launches[bootstrap], 1)
        f:live(); eq(f.launches[driver], 1); eq(f.leaseWrites, 1); eq(f.files[leasePath], token .. '|1000|0|?')
        eq(f.meter.Text, '42 °C'); contains(f.meter.ToolTipText, adapter); contains(f.meter.ToolTipText, 'NVIDIA driver')
        contains(f.meter.ToolTipText, 'hottest measured area')
        f:clear(); for _ = 1, 4 do f:update() end
        eq(#f.calls, 0, 'deduplicated unchanged view'); eq(f.leaseWrites, 1); eq(f.reads[info], 1)
        eq(f.launches[bootstrap], 1); eq(f.launches[driver], 1)
    end)
    test('interval follows slower collection cadence and bounded integer limits', function()
        local cases = {{{MetricsInterval = '5000', SensorInterval = '2000'}, 5000},
            {{MetricsInterval = '300', SensorInterval = '400'}, 1000},
            {{MetricsInterval = '30001', SensorInterval = '2000'}, 30000},
            {{MetricsInterval = 'bad', SensorInterval = '2500.9'}, 2500},
            {{MetricsInterval = '1e309', SensorInterval = '2000'}, 2000}}
        for _, item in ipairs(cases) do
            local f = fixture({vars = item[1]}); contains(f.parameters[bootstrap], "'," .. item[2] .. '))')
        end
    end)
    test('pending or missing metadata has a deadline, then runs names only and never launches from stale output', function()
        for _, status in ipairs({-1, 0, 2, 101, 102, 103}) do
            local f = fixture({infoStatus = status}); eq(f.meter.Text, 'Checking...'); eq(f.reads[info], nil)
            f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable'); contains(f.meter.ToolTipText, 'GPU identity is unavailable.')
            eq(f.launches[bootstrap], 1); contains(f.parameters[bootstrap], "CreateSession('" .. namesOnlyLuid .. "',2000)")
            f.statuses[info] = 1; f.now = 2000; f:update(); eq(f.launches[bootstrap], 1); eq(f.reads[info], nil, 'late metadata is never read')
        end
        local f = fixture({missingInfo = true}); f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable')
        contains(f.parameters[bootstrap], "CreateSession('" .. namesOnlyLuid .. "',")
    end)
    test('never-launched helpers reporting minus one are not killed during metadata failure or Stop', function()
        local function untouched(f)
            eq(f.launches[bootstrap], nil); eq(f.launches[driver], nil)
            eq(f.kills[bootstrap], nil); eq(f.kills[driver], nil)
            eq(next(f.removed), nil, 'unaccepted sessions have no owned files')
        end
        -- Failed metadata now owns only a names-only bootstrap; the driver host
        -- was never launched and must never be killed.
        local function namesOnlyBootstrap(f)
            eq(f.launches[bootstrap], 1); eq(f.launches[driver], nil); eq(f.kills[driver], nil)
            eq(next(f.removed), nil, 'unaccepted sessions have no owned files')
        end
        local f = fixture({metadata = 'NONE', bootstrapStatus = -1, driverStatus = -1})
        eq(f.meter.Text, 'Unavailable'); namesOnlyBootstrap(f); eq(f.kills[bootstrap], nil)
        f.env.Stop(); namesOnlyBootstrap(f); eq(f.kills[bootstrap], 1, 'owned running bootstrap is stopped')
        for _, statusValue in ipairs({0, -1}) do
            f = fixture({infoStatus = statusValue, bootstrapStatus = -1, driverStatus = -1})
            eq(f.meter.Text, 'Checking...'); untouched(f)
            f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable'); namesOnlyBootstrap(f)
            f = fixture({infoStatus = statusValue, bootstrapStatus = -1, driverStatus = -1})
            f.env.Stop(); untouched(f)
            f:clear(); f.now = 2000; f:update(); eq(#f.calls, 0); untouched(f)
        end
    end)
    test('malformed and ambiguous metadata cannot select any driver adapter, only a names-only session', function()
        local cases = {'NONE', metadata:gsub('OK|', 'AMBIGUOUS|', 1), metadata:gsub('PHYSICAL', 'UNKNOWN'),
            metadata:gsub('GPU_ADAPTER|1|', 'GPU_ADAPTER|2|'), metadata .. '|extra', metadata .. '\nother',
            metadata:gsub(luid, '123'), metadata:gsub(luid, 'G123456789ABCDEF'), metadata:gsub(adapter, ''),
            (metadata:gsub(luid, namesOnlyLuid)), string.rep('x', 12001)}
        for _, output in ipairs(cases) do
            local f = fixture({metadata = output}); eq(f.meter.Text, 'Unavailable')
            contains(f.meter.ToolTipText, 'No unambiguous discrete GPU identity is available. Refresh GPU to retry.')
            eq(f.launches[bootstrap], 1); contains(f.parameters[bootstrap], "CreateSession('" .. namesOnlyLuid .. "',2000)")
            f:update(); eq(f.launches[bootstrap], 1)
        end
        local f = fixture({metadata = metadata:gsub('\n', '\r\n'):gsub('PHYSICAL', 'DEDICATED')})
        eq(f.launches[bootstrap], 1, 'CRLF dedicated metadata accepted')
    end)
    test('session response requires exact version, token, LUID and temp filename', function()
        local cases = {'', 'GPU_TEMP_FAILED', sessionOutput({[2] = '2'}), sessionOutput({[3] = 'short'}),
            sessionOutput({[3] = string.rep('Z', 32)}), sessionOutput({[5] = 'FFFFFFFFFFFFFFFF'}),
            sessionOutput({[4] = hex('C:\\Elsewhere\\Parallax-GPU-' .. token .. '.dat')}),
            sessionOutput({[4] = hex(dataPath .. '.exe')}), sessionOutput({[4] = hex(tempRoot .. '\\..\\Parallax-GPU-' .. token .. '.dat')}),
            sessionOutput({[4] = hex('\\\\server\\share\\Parallax-GPU-' .. token .. '.dat')}),
            sessionOutput({[4] = hex('Parallax-GPU-' .. token .. '.dat')}), sessionOutput({[4] = 'ABC'}),
            sessionOutput({[4] = 'FF'}), sessionOutput({[4] = hex(dataPath .. '\n')}), sessionOutput() .. '|extra'}
        for _, output in ipairs(cases) do
            local f = fixture(); f:start(output); eq(f.meter.Text, 'Unavailable'); eq(f.launches[driver], nil)
            eq(f.leaseWrites, 0); eq(next(f.removed), nil); f:update(); eq(f.launches[bootstrap], 1)
        end
    end)
    test('bootstrap deadline prevents repeated launches or delayed stale completion', function()
        local f = fixture(); f.now = 1020; f:update(); eq(f.meter.Text, 'Unavailable')
        f:start(); eq(f.launches[driver], nil); eq(f.launches[bootstrap], 1); eq(f.leaseWrites, 0)
    end)
    test('valid zero, negative and supported boundary values retain their numeric meaning', function()
        for _, value in ipairs({'0', '-15', '-273', '300'}) do
            local f = fixture(); f:live({[7] = value}); eq(f.meter.Text, value .. ' °C')
        end
    end)
    test('unsupported, unavailable, changed and startup status never appear as measured zero', function()
        for _, item in ipairs({{'STARTING', 'Checking...'}, {'UNSUPPORTED', 'Unsupported'},
            {'UNAVAILABLE', 'Unavailable'}, {'DEVICE_CHANGED', 'Unavailable'}}) do
            local f = fixture(); f:live({[6] = item[1], [7] = '?', [9] = '?'}); eq(f.meter.Text, item[2])
            eq(f.launches[driver], 1); f:update(); eq(f.launches[driver], 1)
        end
    end)
    test('invalid payload fields, identities, temperatures and UTF8 are rejected', function()
        local cases = {{[1] = 'OTHER'}, {[2] = '1'}, {[2] = '2'}, {[3] = string.rep('a', 32)}, {[8] = 'FFFFFFFFFFFFFFFF'},
            {[4] = '-1'}, {[4] = '1.5'}, {[4] = '9007199254740992'}, {[4] = 'NaN'},
            {[5] = '0'}, {[5] = '1e3'}, {[5] = '1006'}, {[5] = '991'}, {[6] = 'FAKE'},
            {[7] = '?'}, {[7] = '0.5'}, {[7] = '1e2'}, {[7] = '-274'}, {[7] = '301'}, {[7] = 'NaN'}, {[7] = ''},
            {[6] = 'UNSUPPORTED', [7] = '0'}, {[9] = 'ABC'}, {[9] = 'GG'},
            {[9] = hex(adapter .. '\0')}, {[9] = 'C080'}, {[9] = 'EDA080'}, {[9] = 'F4908080'},
            {[9] = hex(string.rep('A', 512))}, {[9] = hex(string.char(194, 128))}}
        for _, override in ipairs(cases) do
            local f = fixture(); f:live(override); eq(f.meter.Text, 'Unavailable')
            eq(f.launches[bootstrap], 1); eq(f.launches[driver], 1)
        end
        for _, data in ipairs({'', 'GPU_TEMP', string.rep('x', 8193), 'GPU_TEMP|1|' .. token .. '|1|1000|OK|42|' .. luid .. '|' .. hex(adapter) .. '|extra'}) do
            local f = fixture(); f:start(); f.files[dataPath] = data; f:update(); eq(f.meter.Text, 'Unavailable')
        end
        local f = fixture(); f:live(); f.nilRead = true; f:update(); eq(f.meter.Text, 'Unavailable')
    end)
    test('a missing optional GPU name preserves a valid identity-checked temperature', function()
        local f = fixture(); f:live({[9] = '?'})
        eq(f.meter.Text, '42 °C')
        contains(f.meter.ToolTipText, 'Selected GPU: GPU Temperature from the NVIDIA driver.')
        eq(f.launches[driver], 1)
        f:sample({[4] = '2'}); f:update()
        contains(f.meter.ToolTipText, adapter .. ': GPU Temperature from the NVIDIA driver.')
        f:sample({[4] = '3', [8] = 'FFFFFFFFFFFFFFFF', [9] = '?'}); f:update()
        eq(f.meter.Text, 'Unavailable', 'name fallback cannot bypass exact GPU identity')
    end)
    test('freshness, monotonic sequence and epoch checks clear old displayed samples', function()
        local f = fixture(); f:live({[4] = '5'}); eq(f.meter.Text, '42 °C')
        f.now = 1008; f:update(); eq(f.meter.Text, '42 °C', 'inclusive age boundary')
        f.now = 1009; f:update(); eq(f.meter.Text, 'Unavailable', 'stale sample hidden')
        f:sample({[4] = '6'}); f:update(); eq(f.meter.Text, '42 °C')
        f:sample({[4] = '5'}); f:update(); eq(f.meter.Text, 'Unavailable', 'sequence rollback hidden')
        f:sample({[4] = '7', [5] = '1008'}); f:update(); eq(f.meter.Text, 'Unavailable', 'epoch rollback hidden')
        f:sample({[4] = '7', [5] = '1014'}); f:update(); eq(f.meter.Text, '42 °C', 'allowed clock skew')
        f.now = 1000; f:update(); eq(f.meter.Text, 'Unavailable', 'clock rollback makes future sample unavailable')
    end)
    test('lease renews every five seconds and bounded snapshot absence remains explicit', function()
        local f = fixture(); f:start(); eq(f.leaseWrites, 1)
        f.now = 1004; f:update(); eq(f.leaseWrites, 1); eq(f.meter.Text, 'Checking...')
        f.now = 1005; f:update(); eq(f.leaseWrites, 2); eq(f.files[leasePath], token .. '|1005|0|?')
        f.now = 1009; f:update(); eq(f.leaseWrites, 2)
        f.now = 1020; f:update(); eq(f.leaseWrites, 3); eq(f.meter.Text, 'Unavailable')
        eq(f.launches[driver], 1); eq(f.launches[bootstrap], 1)
    end)
    test('lease failures stop the host and clean only this session', function()
        for _, mode in ipairs({'failOpen', 'failWrite', 'failClose'}) do
            local f = fixture(); f[mode] = true; f:start(); eq(f.meter.Text, 'Unavailable')
            eq(f.launches[driver], nil); f:ownedClean(); f:update(); eq(f.launches[bootstrap], 1)
        end
        local f = fixture(); f:live(); f.failOpen = true; f.now = 1005; f:update()
        eq(f.meter.Text, 'Unavailable'); eq(f.kills[driver], 1); f:ownedClean()
        f.failOpen = false; f:update(); eq(f.launches[driver], 1)
    end)
    test('a stopped host cannot leave a plausible retained reading or restart loop', function()
        local f = fixture(); f:live(); f.files[tmpPath] = 'partial'
        f.statuses[driver] = 1; f:update(); eq(f.meter.Text, 'Unavailable'); f:ownedClean()
        f.statuses[driver] = -1; f:update(); eq(f.meter.Text, 'Unavailable'); eq(f.launches[driver], 1)
    end)
    test('Stop removes owned lease/snapshot/temp files and never restarts helpers', function()
        local f = fixture(); f:live(); f.files[tmpPath] = 'partial'; f.env.Stop(); f:ownedClean()
        eq(f.kills[bootstrap], nil, 'finished bootstrap need not be killed'); eq(f.kills[driver], 1)
        f:clear(); f.now = 2000; f:update(); eq(#f.calls, 0); eq(f.launches[driver], 1)
        f = fixture(); f.env.Stop(); eq(next(f.removed), nil, 'no files removed before session accepted')
        eq(f.kills[bootstrap], 1); eq(f.kills[driver], nil)
        f:start(); eq(f.launches[driver], nil); eq(f.leaseWrites, 0)
    end)
    test('failure and Stop kill owned native RUN state zero exactly once', function()
        for _, name in ipairs({bootstrap, driver}) do
            for _, action in ipairs({'failure', 'Stop'}) do
                local f = fixture(); if name == driver then f:live() end
                eq(f.launches[name], 1); eq(f.statuses[name], 0, 'RunCommand is actively running')
                if action == 'Stop' then f.env.Stop()
                elseif name == bootstrap then f.now = 1020; f:update()
                else f.failOpen = true; f.now = 1005; f:update() end
                eq(f.kills[name], 1)
                eq(f.kills[name == bootstrap and driver or bootstrap], nil)
                eq(f.statuses[name], 0, 'asynchronous Kill may retain RUN until the plugin updates')
                f.env.Stop(); f.env.Stop(); eq(f.kills[name], 1, 'repeated shutdown cannot send a second Kill')
                if name == driver then f:ownedClean() else eq(next(f.removed), nil) end
            end
        end
    end)
    test('owned initial, completed and error states are never killed on failure or Stop', function()
        for _, stateValue in ipairs({-1, 1, 2, 101, 102, 103}) do
            for _, name in ipairs({bootstrap, driver}) do
                for _, action in ipairs({'failure', 'Stop'}) do
                    local f = fixture(); if name == driver then f:live() end
                    eq(f.launches[name], 1); f.statuses[name] = stateValue
                    if action == 'Stop' then f.env.Stop()
                    elseif name == bootstrap then f.now = 1020; f:update()
                    else f.failOpen = true; f.now = 1005; f:update() end
                    eq(f.kills[bootstrap], nil); eq(f.kills[driver], nil)
                    f.env.Stop(); eq(f.kills[bootstrap], nil); eq(f.kills[driver], nil)
                end
            end
        end
    end)
    test('unowned helper status cannot authorize Kill even if the plugin reports RUN', function()
        for _, stateValue in ipairs({-1, 0, 1, 101, 102, 103}) do
            local f = fixture({metadata = 'NONE', bootstrapStatus = stateValue, driverStatus = stateValue})
            eq(f.meter.Text, 'Unavailable'); f.env.Stop()
            eq(f.launches[bootstrap], 1, 'names-only bootstrap is owned'); eq(f.launches[driver], nil)
            eq(f.kills[driver], nil, 'the never-launched driver host is never killed')
            f = fixture({infoStatus = 0, bootstrapStatus = stateValue, driverStatus = stateValue})
            f.env.Stop(); eq(f.launches[bootstrap], nil); eq(f.launches[driver], nil)
            eq(f.kills[bootstrap], nil); eq(f.kills[driver], nil)
        end
    end)
    test('shutdown refreshes stale plugin status before deciding whether a helper is live', function()
        for _, name in ipairs({bootstrap, driver}) do
            for _, stateValue in ipairs({1, 101, 102, 103}) do
                local f = fixture(); if name == driver then f:live() end
                eq(f.statuses[name], 0)
                f.statusOnRefresh = {[name] = stateValue}; f.env.Stop()
                eq(f.statuses[name], stateValue); eq(f.kills[name], nil, 'completed/error status supersedes cached RUN')
            end
            local f = fixture(); if name == driver then f:live() end
            f.statuses[name] = -1; f.statusOnRefresh = {[name] = 0}; f.env.Stop()
            eq(f.kills[name], 1, 'fresh RUN status supersedes cached initial state for an owned helper')
        end
    end)
    test('memory capacity and activity domains stay separate in their units', function()
        local f = fixture(); f:live()
        eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB')
        eq(f:text('MeterGPUSharedValue'), '182 MB')
        local endpoint, stroke, y = f:bar(); eq(endpoint, 50); eq(stroke, 6); eq(y, 3) -- fixture ContentWidth 200
        for index, name in ipairs(loadMeters) do eq(f:text(name), tostring(index * 25) .. '%') end
        for index, name in ipairs(loadBars) do
            local endpoint, stroke, y = f:bar(name); eq(endpoint, index * 25 / 100 * engineWidth, name); eq(stroke, 6); eq(y, 3)
            contains(f.meters[name].Shape2, 'Stroke Color #GPUColor#'); contains(f:tip(name), 'activity')
        end
        contains(f:tip('MeterGPUVRAMValue'), adapter)
        contains(f:tip('MeterGPUVRAMValue'), 'decimal units')
        eq(f:tip('MeterGPUVRAMBar'), f:tip('MeterGPUVRAMValue'), 'bar and value share one explanation')
        contains(f:tip('MeterGPUSharedValue'), adapter)
        contains(f.meters.MeterGPUVRAMBar.Shape2, 'StrokeStartCap Flat | StrokeEndCap Flat')
        contains(f.meters.MeterGPUVRAMBar.Shape2, 'Stroke Color #GPUColor#')
    end)
    test('headline activity follows the Core domain and is the numeric return value', function()
        local f = fixture(); f:start(); f:sample()
        local n = f:update(); eq(n, 25); eq(f:text('MeterActivityValue'), '25%')
        contains(f:tip('MeterActivityValue'), adapter); contains(f:tip('MeterActivityValue'), 'History graph')
        f:sample({[4] = '2', [18] = '0'}); n = f:update(); eq(n, 0); eq(f:text('MeterActivityValue'), '0%', 'measured zero keeps its unit')
        f:sample({[4] = '3', [18] = '100'}); n = f:update(); eq(n, 100); eq(f:text('MeterActivityValue'), '100%')
        eq(f:bar('MeterGPULoadBar'), engineWidth, 'full Core activity fills the engine track')
        for _, value in ipairs({'?', '-1', '101', '1.5', '1e2', 'NaN', '', '9007199254740992'}) do
            f = fixture(); f:live({[18] = value}); n = f:update(); eq(n, 0, 'invalid Core percent ' .. value)
            eq(f:text('MeterActivityValue'), '--'); eq(f:text('MeterGPULoadValue'), '--')
            local endpoint, stroke = f:bar('MeterGPULoadBar'); eq(endpoint, 0); eq(stroke, 0)
            eq(f:text('MeterGPUControllerLoadValue'), '50%'); eq(f:text('MeterGPUVideoLoadValue'), '75%'); eq(f:text('MeterGPUBusLoadValue'), '100%')
            eq(f:bar('MeterGPUControllerLoadBar'), engineWidth / 2)
            eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB'); eq(f:text('MeterGPUSharedValue'), '182 MB')
            eq(f.meter.Text, '42 °C'); eq(f:text('MeterPowerValue'), '55.3 W'); eq(f:text('MeterClockValue'), '1607.5 MHz')
        end
        f = fixture(); f:live({[17] = 'UNSUPPORTED', [18] = '?', [19] = '?', [20] = '?', [21] = '?'})
        n = f:update(); eq(n, 0); eq(f:text('MeterActivityValue'), '--'); eq(f.meter.Text, '42 °C')
        f = fixture(); f:live({[7] = 'NaN'}); n = f:update()
        eq(n, 25, 'unusable temperature keeps a valid Core reading'); eq(f:text('MeterActivityValue'), '25%'); eq(f.meter.Text, 'Unavailable')
    end)
    test('unavailable, stale, failed and stopped states return zero activity and clear the headline', function()
        local f = fixture(); local n = f:update(); eq(n, 0); eq(f:text('MeterActivityValue'), '--'); eq(f.meter.Text, 'Checking...')
        f = fixture({metadata = 'NONE'}); n = f:update(); eq(n, 0, 'metadata failure'); eq(f:text('MeterActivityValue'), '--')
        f = fixture(); f:start(); n = f:update(); eq(n, 0, 'no snapshot yet'); eq(f:text('MeterActivityValue'), '--')
        f = fixture(); f:live(); n = f:update(); eq(n, 25)
        f.now = 1009; n = f:update(); eq(n, 0, 'stale sample'); eq(f:text('MeterActivityValue'), '--')
        f = fixture(); f:live(); f:sample({[4] = '2', [6] = 'DEVICE_CHANGED'}); n = f:update(); eq(n, 0, 'changed device'); f:allUnavailable()
        f = fixture(); f:live(); f:sample({[4] = '2', [17] = 'DEVICE_CHANGED'}); n = f:update(); eq(n, 0, 'changed engine identity'); f:allUnavailable()
        f = fixture(); f:live(); f.files[dataPath] = f.files[dataPath] .. '|extra'; n = f:update(); eq(n, 0, 'malformed sample'); f:allUnavailable()
        f = fixture(); f:live(); f.statuses[driver] = 1; n = f:update(); eq(n, 0, 'stopped host'); f:allUnavailable()
        f:clear(); n = f:update(); eq(n, 0, 'failed state stays zero'); eq(#f.calls, 0)
        f = fixture(); f:live(); f.failOpen = true; f.now = 1005; n = f:update(); eq(n, 0, 'lost lease'); eq(f:text('MeterActivityValue'), '--')
        f = fixture(); f:live(); f.env.Stop(); local stopped, names = f:update(); eq(stopped, 0, 'stopped'); eq(names, '')
    end)
    test('unsupported metric categories retain other independently valid observations', function()
        for _, item in ipairs({{6, {7}}, {10, {11, 12, 13}}, {14, {15, 16}}, {17, {18, 19, 20, 21}}}) do
            local override = {[item[1]] = 'UNSUPPORTED'}
            for _, field in ipairs(item[2]) do override[field] = '?' end
            local f = fixture(); f:live(override)
            eq(f.meter.Text, item[1] == 6 and 'Unsupported' or '42 °C')
            if item[1] == 10 then
                contains(f:text('MeterGPUVRAMValue'), '--')
                local endpoint, stroke = f:bar(); eq(endpoint, 0); eq(stroke, 0)
            else eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB') end
            if item[1] == 14 then contains(f:text('MeterGPUSharedValue'), '--')
            else eq(f:text('MeterGPUSharedValue'), '182 MB') end
            for index, name in ipairs(loadMeters) do eq(f:text(name), item[1] == 17 and '--' or tostring(index * 25) .. '%') end
            eq(f:text('MeterActivityValue'), item[1] == 17 and '--' or '25%')
        end
        local f = fixture(); f:live({[7] = 'NaN'})
        eq(f.meter.Text, 'Unavailable'); eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB')
        eq(f:text('MeterGPUSharedValue'), '182 MB'); eq(f:text('MeterGPULoadValue'), '25%'); eq(f:text('MeterActivityValue'), '25%')
    end)
    test('any changed adapter status and bad common identity clear every prior category', function()
        local overrides = {{[6] = 'DEVICE_CHANGED'}, {[10] = 'DEVICE_CHANGED'}, {[14] = 'DEVICE_CHANGED'},
            {[17] = 'DEVICE_CHANGED'}, {[22] = 'DEVICE_CHANGED'}, {[24] = 'DEVICE_CHANGED'},
            {[1] = 'OTHER'}, {[2] = '1'}, {[2] = '2'}, {[3] = string.rep('a', 32)},
            {[8] = 'FFFFFFFFFFFFFFFF'}, {[9] = 'GG'}, {[4] = '-1'}, {[5] = '1006'}}
        for _, override in ipairs(overrides) do
            local f = fixture(); f:live(); f:sample(override); f:update(); f:allUnavailable()
            eq(f.launches[driver], 1); eq(f.launches[bootstrap], 1)
        end
        local f = fixture(); f:live(); f.now = 1009; f:update(); f:allUnavailable()
        f = fixture(); f:live(); f.files[dataPath] = f.files[dataPath] .. '|extra'; f:update(); f:allUnavailable()
        f = fixture(); f:live(); f.statuses[driver] = 1; f:update(); f:allUnavailable()
    end)
    test('VRAM validation rejects missing capacities, TCC zeros and inconsistent availability independently', function()
        local invalid = {{[11] = '0'}, {[12] = '0'}, {[12] = '8589934593'}, {[13] = '8053063681'},
            {[11] = '-1'}, {[12] = '1.5'}, {[13] = '-1'}, {[13] = '1e3'}, {[11] = '9007199254740992'},
            {[12] = 'NaN'}, {[13] = '?'}, {[11] = '?'}, {[10] = 'FAKE'}, {[12] = '0', [13] = '0'}}
        for _, override in ipairs(invalid) do
            local f = fixture(); f:live(override); contains(f:text('MeterGPUVRAMValue'), '--')
            local endpoint, stroke = f:bar(); eq(endpoint, 0); eq(stroke, 0)
            eq(f.meter.Text, '42 °C'); eq(f:text('MeterGPUSharedValue'), '182 MB')
            eq(f:text('MeterGPULoadValue'), '25%')
        end
    end)
    test('VRAM zero-use, full-use and maximum exact integer remain bounded', function()
        local cases = {{'8589934592', '8589934592', '8589934592', '0.0/8.6 GB', 0},
            {'8589934592', '8053063680', '0', '8.6/8.6 GB', 200},
            {'9007199254740991', '9007199254740991', '9007199254740991', '0.0/9007.2 TB', 0},
            {'9007199254740991', '9007199254740991', '0', '9007.2/9007.2 TB', 200}}
        for _, item in ipairs(cases) do
            local f = fixture(); f:live({[11] = item[1], [12] = item[2], [13] = item[3]})
            if item[4] then eq(f:text('MeterGPUVRAMValue'), item[4]) end
            eq(not not f:text('MeterGPUVRAMValue'):find('--', 1, true), false)
            local endpoint, stroke = f:bar(); eq(endpoint, item[5]); eq(stroke, item[5] == 0 and 0 or 6)
        end
    end)
    test('shared memory uses observed residency, preserves zero, and does not substitute a capacity limit', function()
        local f = fixture(); f:live({[15] = '0', [16] = '0'}); eq(f:text('MeterGPUSharedValue'), '0 MB')
        f = fixture(); f:live({[15] = '1048576', [16] = '2147483648'})
        eq(f:text('MeterGPUSharedValue'), '2.15 GB', 'resident may exceed committed')
        f = fixture(); f:live({[15] = '17179869184', [16] = '182452224'})
        eq(f:text('MeterGPUSharedValue'), '182 MB', 'committed value must not replace resident')
        for _, override in ipairs({{[15] = '-1'}, {[16] = '-1'}, {[15] = '9007199254740992'},
            {[16] = '1.5'}, {[16] = '1e3'}, {[15] = '?'}, {[16] = '?'}, {[14] = 'FAKE'},
            {[14] = 'UNSUPPORTED', [15] = '?', [16] = '?'}}) do
            f = fixture(); f:live(override); contains(f:text('MeterGPUSharedValue'), '--')
            eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB'); eq(f.meter.Text, '42 °C')
        end
    end)
    test('utilization accepts zero and 100 while unavailable domains remain independent', function()
        local f = fixture(); f:live({[18] = '0', [19] = '100', [20] = '?', [21] = '0'})
        eq(f:text(loadMeters[1]), '0%'); eq(f:text(loadMeters[2]), '100%')
        eq(f:text(loadMeters[3]), '--'); eq(f:text(loadMeters[4]), '0%')
        for index, name in ipairs(loadMeters) do
            for _, value in ipairs({'-1', '101', '1.5', '1e2', 'NaN', '', '9007199254740992'}) do
                f = fixture(); f:live({[17 + index] = value}); eq(f:text(name), '--')
                for other, otherName in ipairs(loadMeters) do
                    if other ~= index then eq(f:text(otherName), tostring(other * 25) .. '%') end
                end
                eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB'); eq(f.meter.Text, '42 °C')
            end
        end
    end)
    test('VRAM bar inherits rounded physical thickness and exact content width through scale changes', function()
        for _, scale in ipairs({0.75, 1, 2}) do
            for _, thickness in ipairs({1, 6, 12}) do
                local width = 200 * scale
                local f = fixture({vars = {Scale = tostring(scale), DataBarThickness = tostring(thickness), ContentWidth = tostring(width)}})
                f:live(); local endpoint, stroke, y = f:bar()
                local expected = math.max(1, math.floor(thickness * scale + 0.5))
                eq(endpoint, width / 4); eq(stroke, expected); eq(y, expected / 2)
                local engineEndpoint, engineStroke, engineY = f:bar('MeterGPULoadBar')
                eq(engineEndpoint, (width - 102 * scale) / 4, 'engine track follows ContentWidth - 102 * Scale'); eq(engineStroke, expected); eq(engineY, expected / 2)
                f:sample({[4] = '2', [13] = '0'}); f:update(); eq(f:bar(), width)
            end
        end
        local f = fixture({vars = {ContentWidth = '(#PanelWidth#-2*#Padding#)'}})
        f:live(); eq(f:bar(), 50, 'derived geometry resolves before use')
        eq(f:bar('MeterGPULoadBar'), engineWidth / 4, 'nested derived engine geometry resolves before use')
        for _, vars in ipairs({{ContentWidth = '0'}, {ContentWidth = '-1'}, {ContentWidth = 'NaN'},
            {DataBarThicknessPx = '0'}, {DataBarThicknessPx = '-1'}, {DataBarThicknessPx = 'NaN'}}) do
            f = fixture({vars = vars}); f:live(); local endpoint, stroke = f:bar(); eq(endpoint, 0); eq(stroke, 0)
            local engineEndpoint, engineStroke = f:bar('MeterGPULoadBar'); eq(engineEndpoint, 0); eq(engineStroke, 0)
            eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB'); eq(f:text('MeterGPULoadValue'), '25%')
        end
        for _, vars in ipairs({{GPUEngineBarWidth = '0'}, {GPUEngineBarWidth = '-1'}, {GPUEngineBarWidth = 'NaN'}}) do
            f = fixture({vars = vars}); f:live()
            local engineEndpoint, engineStroke = f:bar('MeterGPULoadBar'); eq(engineEndpoint, 0); eq(engineStroke, 0)
            eq(f:bar(), 50, 'VRAM bar keeps the full content width'); eq(f:text('MeterGPULoadValue'), '25%')
        end
    end)
    test('driver power and graphics clock are the default despite enabled legacy export mappings', function()
        local options = manualOptions(false, false)
        options.vars.GPUPowerSource, options.vars.GPUClockSource = nil, nil
        local f = fixture(options); f:live()
        eq(f:text('MeterPowerValue'), '55.3 W'); eq(f:text('MeterClockValue'), '1607.5 MHz')
        eq(f.reads.MeasureGPURegistryNames, nil); eq(f.reads.MeasureGPUPowerValue, nil); eq(f.reads.MeasureGPUClockValue, nil)
        f:sample({[4] = '2', [22] = 'UNSUPPORTED', [23] = '?', [24] = 'UNSUPPORTED', [25] = '?'}); f:update()
        eq(f:text('MeterPowerValue'), 'Unsupported'); eq(f:text('MeterClockValue'), 'Unsupported')
        eq(f.reads.MeasureGPURegistryNames, nil, 'unsupported direct readings cannot silently choose HWiNFO')
    end)
    test('driver power and clock retain precision, zero rules and unsigned API boundaries', function()
        for _, item in ipairs({{'0', '0.0 W'}, {'53', '0.1 W'}, {'55321', '55.3 W'}, {'4294967295', '4294967.3 W'}}) do
            local f = fixture(); f:live({[23] = item[1]}); eq(f:text('MeterPowerValue'), item[2])
        end
        for _, item in ipairs({{'1', '0.001 MHz'}, {'1000', '1 MHz'}, {'1607000', '1607 MHz'},
            {'1607500', '1607.5 MHz'}, {'1607510', '1607.51 MHz'}, {'1607513', '1607.513 MHz'},
            {'4294967295', '4294967.295 MHz'}}) do
            local f = fixture(); f:live({[25] = item[1]}); eq(f:text('MeterClockValue'), item[2])
        end
        local f = fixture(); f:live({[25] = '0'})
        eq(f:text('MeterClockValue'), 'Unavailable'); eq(f:text('MeterPowerValue'), '55.3 W')
    end)
    test('invalid power or clock data clears only its direct metric', function()
        local cases = {'', '?', '-1', '0.5', '1e3', 'NaN', '4294967296', '9007199254740992'}
        for _, field in ipairs({{22, 23, 'MeterPowerValue', 'MeterClockValue', '1607.5 MHz'},
            {24, 25, 'MeterClockValue', 'MeterPowerValue', '55.3 W'}}) do
            for _, value in ipairs(cases) do
                local f = fixture(); f:live({[field[2]] = value})
                eq(f:text(field[3]), 'Unavailable'); eq(f:text(field[4]), field[5])
                eq(f.meter.Text, '42 °C'); eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB')
            end
            for _, status in ipairs({'FAKE', 'UNAVAILABLE', 'UNSUPPORTED', 'STARTING'}) do
                local f = fixture(); f:live({[field[1]] = status, [field[2]] = '?'})
                local expected = status == 'UNSUPPORTED' and 'Unsupported' or (status == 'STARTING' and 'Checking...' or 'Unavailable')
                eq(f:text(field[3]), expected); eq(f:text(field[4]), field[5])
                eq(f.meter.Text, '42 °C')
                f:sample({[4] = '2', [field[1]] = status, [field[2]] = '123'}); f:update()
                eq(f:text(field[3]), 'Unavailable', 'failure status cannot carry a plausible numeric reading')
            end
        end
    end)
    test('explicit HWiNFO override selects each field separately and keeps its unknown-age status', function()
        for _, selection in ipairs({{true, false}, {false, true}, {true, true}}) do
            local f = fixture(manualOptions(selection[1], selection[2])); f:live()
            eq(f:text('MeterPowerValue'), selection[1] and '77.7 W' or '55.3 W')
            eq(f:text('MeterClockValue'), selection[2] and '1234.5 MHz' or '1607.5 MHz')
            eq((f.reads.MeasureGPURegistryNames or 0) > 0, true)
            if selection[1] then contains(f:tip('MeterPowerValue'), 'sample age unknown')
            else eq(f.reads.MeasureGPUPowerValue, nil) end
            if selection[2] then contains(f:tip('MeterClockValue'), 'sample age unknown')
            else eq(f.reads.MeasureGPUClockValue, nil) end
        end
        local options = manualOptions(true, false); options.vars.GPUEnableSensors = '0'
        local f = fixture(options); f:live()
        eq(f:text('MeterPowerValue'), 'Off'); eq(f:text('MeterClockValue'), '1607.5 MHz')
        eq(f.reads.MeasureGPURegistryNames, nil)
    end)
    test('canonical override selection enables and initializes only its required banks once', function()
        for _, selection in ipairs({{true, false, 5}, {false, true, 5}, {true, true, 9}, {false, false, 0}}) do
            local f = fixture(manualOptions(selection[1], selection[2]))
            local count = 0
            for name in pairs(registryNames) do
                local field = name:match('^MeasureGPU(Power)') or name:match('^MeasureGPU(Clock)')
                local selected = field == 'Power' and selection[1] or field == 'Clock' and selection[2]
                    or not field and (selection[1] or selection[2])
                eq(f.registryEnables[name], selected and 1 or nil, name .. ' enable selection')
                eq(f.registryUpdates[name], selected and 1 or nil, name .. ' initialization update')
                if f.registryEnables[name] then count = count + 1 end
            end
            eq(count, selection[3], 'bounded selected bank size')
            f:live(); f:clear()
            for _ = 1, 4 do f:update() end
            eq(#f.calls, 0, 'unchanged updates do not re-enable or force registry collection')
            for name, value in pairs(f.registryEnables) do eq(value, 1); eq(f.registryUpdates[name], 1) end
        end
        local options = manualOptions(true, false)
        options.vars.GPUEnableSensors, options.vars.GPUPowerSource = ' 1 ', ' 1 '
        options.exports = {MeasureGPUPowerSensor = ' ' .. adapter .. ' ', MeasureGPUPowerLabel = ' GPU Power ',
            MeasureGPUPowerValue = ' 77.7 W ', MeasureGPUPowerValueRaw = ' 77.7 '}
        local f = fixture(options); f:live(); eq(f:text('MeterPowerValue'), '77.7 W')
        eq(f.registryEnables.MeasureGPURegistryNames, 1); eq(f.registryEnables.MeasureGPUPowerValue, 1)
        eq(f.registryEnables.MeasureGPUClockValue, nil)
    end)
    test('invalid, missing and disabled source preferences leave all registry measures disabled', function()
        for _, field in ipairs({'Power', 'Clock'}) do
            for _, source in ipairs({'', '0', '2', '-1', '1.0', '1e0', '(1)', '1+0', 'invalid'}) do
                local options = manualOptions(false, false); options.vars['GPU' .. field .. 'Source'] = source
                local f = fixture(options); f:live()
                eq(next(f.registryEnables), nil); eq(next(f.registryUpdates), nil); eq(f.reads.MeasureGPURegistryNames, nil)
            end
        end
        for _, enabled in ipairs({'', '0', '2', '-1', '1.0', '1e0', '(1)', '1+0', 'invalid'}) do
            local options = manualOptions(true, true); options.vars.GPUEnableSensors = enabled
            local f = fixture(options); f:live()
            eq(next(f.registryEnables), nil); eq(next(f.registryUpdates), nil)
            eq(f:text('MeterPowerValue'), 'Off'); eq(f:text('MeterClockValue'), 'Off')
        end
        local options = manualOptions(false, false)
        options.vars.GPUPowerSource, options.vars.GPUClockSource = nil, nil
        local f = fixture(options); f:live()
        eq(next(f.registryEnables), nil); eq(next(f.registryUpdates), nil)
        eq(f:text('MeterPowerValue'), '55.3 W'); eq(f:text('MeterClockValue'), '1607.5 MHz')
    end)
    test('invalid source choices never read exports or silently choose driver values', function()
        for _, field in ipairs({'Power', 'Clock'}) do
            for _, source in ipairs({'', '2', '-1', '1.0', '1e0', '(1)', '1+0', 'driver', 'NaN'}) do
                local options = manualOptions(false, false); options.vars['GPU' .. field .. 'Source'] = source
                local f = fixture(options); f:live(); eq(f:text('Meter' .. field .. 'Value'), 'Unavailable')
                eq(f.reads.MeasureGPURegistryNames, nil)
                eq(f:text(field == 'Power' and 'MeterClockValue' or 'MeterPowerValue'), field == 'Power' and '1607.5 MHz' or '55.3 W')
            end
        end
    end)
    test('manual mapping validates identity, export inventory, raw values and formatted units', function()
        local cases = {
            {vars = {GPUPowerIndex = '-1'}, expected = 'Unmapped'},
            {vars = {GPUPowerSensor = ''}, expected = 'Unmapped'},
            {vars = {GPUPowerLabel = ''}, expected = 'Unmapped'},
            {vars = {GPUPowerIndex = '3.5'}, expected = 'Check mapping'},
            {exports = {MeasureGPURegistryNames = 'Sensor3|Label3|Value3'}, expected = 'Unavailable'},
            {exports = {MeasureGPUPowerSensor = 'Different GPU'}, expected = 'Check mapping'},
            {exports = {MeasureGPUPowerLabel = 'Different sensor'}, expected = 'Check mapping'},
            {exports = {MeasureGPUPowerValueRaw = 'NaN'}, expected = 'Unavailable'},
            {exports = {MeasureGPUPowerValueRaw = '1e309'}, expected = 'Unavailable'},
            {exports = {MeasureGPUPowerValue = ''}, expected = 'Unavailable'},
            {exports = {MeasureGPUPowerValue = '77.7'}, expected = 'Unavailable'},
            {exports = {MeasureGPUPowerValue = 'W'}, expected = 'Unavailable'}}
        for _, item in ipairs(cases) do
            local options = manualOptions(true, false)
            for name, value in pairs(item.vars or {}) do options.vars[name] = value end
            options.exports = item.exports
            local f = fixture(options); f:live(); eq(f:text('MeterPowerValue'), item.expected)
            eq(f:text('MeterClockValue'), '1607.5 MHz')
        end
        local options = manualOptions(true, false)
        options.exports = {MeasureGPUPowerValueRaw = '0', MeasureGPUPowerValue = '0.0 W',
            MeasureGPURegistryNames = ' sensor3 | LABEL3 | Value3 | ValueRAW3 '}
        local f = fixture(options); f:live(); eq(f:text('MeterPowerValue'), '0.0 W')
        contains(f:tip('MeterPowerValue'), 'registry snapshot')
    end)
    test('selected manual exports remain usable and refresh after direct driver failure without relaunch', function()
        local f = fixture(manualOptions(true, true)); f:live()
        f.now = 1009; f:update(); f:allUnavailable()
        eq(f:text('MeterPowerValue'), '77.7 W'); eq(f:text('MeterClockValue'), '1234.5 MHz')
        f.statuses[driver] = 1; f:update(); f:ownedClean()
        f.exports.MeasureGPUPowerValue, f.exports.MeasureGPUPowerValueRaw = '80.5 W', '80.5'
        f.exports.MeasureGPUClockValue, f.exports.MeasureGPUClockValueRaw = '999.5 MHz', '999.5'
        f.now = 1010; f:update()
        eq(f:text('MeterPowerValue'), '80.5 W'); eq(f:text('MeterClockValue'), '999.5 MHz')
        eq(f.launches[bootstrap], 1); eq(f.launches[driver], 1)
        for _, statusField in ipairs({22, 24}) do
            f = fixture(manualOptions(true, true)); f:live({[statusField] = 'DEVICE_CHANGED'})
            f:allUnavailable(); eq(f:text('MeterPowerValue'), '77.7 W'); eq(f:text('MeterClockValue'), '1234.5 MHz')
        end
        local options = manualOptions(true, false); options.metadata = 'NONE'
        f = fixture(options); eq(f:text('MeterPowerValue'), '77.7 W'); eq(f.launches[bootstrap], 1)
        f.exports.MeasureGPUPowerValue, f.exports.MeasureGPUPowerValueRaw = '81.0 W', '81'
        f:update(); eq(f:text('MeterPowerValue'), '81.0 W'); eq(f.launches[bootstrap], 1); eq(f.launches[driver], nil)
    end)
    test('changed process requests are sent at once, renewed every five seconds, as canonical bounded PID data', function()
        local f = fixture({pids = '7,42,4294967295'}); f:live()
        eq(f.files[leasePath], token .. '|1000|1|7,42,4294967295'); eq(f.leaseWrites, 1)
        f.outputs.MeasureGPUProcessController = '8'
        f:update(); eq(f.leaseWrites, 1, 'at most one lease write per second')
        f.now = 1001; f:sample(); f:update()
        eq(f.files[leasePath], token .. '|1001|2|8'); eq(f.leaseWrites, 2)
        f.now = 1005; f:sample(); f:update(); eq(f.leaseWrites, 2, 'an unchanged request waits for renewal')
        f.now = 1006; f:sample(); f:update()
        eq(f.files[leasePath], token .. '|1006|2|8'); eq(f.leaseWrites, 3)
        f.outputs.MeasureGPUProcessController = '?'
        f.now = 1007; f:sample(); f:update(); eq(f.files[leasePath], token .. '|1007|3|?')
        eq(f.launches[bootstrap], 1); eq(f.launches[driver], 1)
        for _, csv in ipairs({'', '0', '-1', '01', '1.0', '1e0', '4294967296', '2,1', '1,1', ',1', '1,',
            '1,2,3,4,5,6,7,8,9,10,11', '1|2', '1;2', ' 1', '1 ', string.rep('9', 55), string.rep('9', 110)}) do
            f = fixture({pids = csv}); f:live(); eq(f.files[leasePath], token .. '|1000|0|?')
        end
    end)
    test('a failed changed-request write retries under a new number; a failed renewal still ends the session', function()
        local f = fixture({pids = '7'}); f:live(); eq(f.files[leasePath], token .. '|1000|1|7')
        f.outputs.MeasureGPUProcessController = '8'; f.failOpen = true
        f.now = 1001; f:sample(); f:update()
        eq(f.meter.Text, '42 °C'); eq(f.kills[driver], nil); eq(f.files[leasePath], token .. '|1000|1|7')
        f.failOpen = false; f.now = 1002; f:sample(); f:update()
        eq(f.files[leasePath], token .. '|1002|3|8', 'a failed request number is never reused')
        f.failWrite = true; f.outputs.MeasureGPUProcessController = '9'; f.now = 1007; f:sample(); f:update()
        eq(f.meter.Text, 'Unavailable'); eq(f.kills[driver], 1); f:ownedClean()
        -- A failed change followed by a revert is still committed under a fresh
        -- number; renewing the burned number would leave every reply unmatched.
        local game = '7,' .. hex('game.exe')
        f = fixture({pids = '7'}); f:live({[27] = game})
        f.outputs.MeasureGPUProcessController = '7,8'; f.failOpen = true; f.now = 1001; f:sample({[27] = game}); f:update()
        eq(f.names, 'GPU_NAMES|1|1001|' .. game, 'the committed request still names 7')
        f.failOpen = false; f.outputs.MeasureGPUProcessController = '7'; f.now = 1002; f:sample({[27] = game}); f:update()
        eq(f.files[leasePath], token .. '|1002|3|7', 'the reverted request is committed under a fresh number')
        f.now = 1060; for second = 1003, 1060 do f.now = second; f:sample({[27] = game}); f:update() end
        eq(f.files[leasePath], token .. '|1057|3|7'); eq(f.names, 'GPU_NAMES|1|1060|' .. game)
    end)
    test('without one discrete GPU the same host runs for process names only', function()
        local map = '7,' .. hex('game.exe') .. ';42,' .. hex('tool.exe')
        for _, output in ipairs({'NONE', (metadata:gsub('OK|', 'AMBIGUOUS|', 1))}) do
            local f = fixture({metadata = output, pids = '7,42'})
            eq(f.meter.Text, 'Unavailable'); local reason = f.meter.ToolTipText
            eq(reason, 'No unambiguous discrete GPU identity is available. Refresh GPU to retry.')
            f:start(sessionOutput({[5] = namesOnlyLuid}))
            eq(f.launches[driver], 1); contains(f.parameters[driver], "','" .. namesOnlyLuid .. "',2000)")
            eq(f.files[leasePath], token .. '|1000|1|7,42')
            f:update(); eq(f.meter.ToolTipText, reason, 'no Checking state before the first reply')
            -- GPU readings in a names-only reply (here a plausible 42 C) are never shown.
            f:sample({[8] = namesOnlyLuid, [9] = '?', [27] = map}); f:update()
            eq(f.names, 'GPU_NAMES|1|1000|' .. map); f:allUnavailable(); eq(f.meter.ToolTipText, reason)
            f.now = 1001; f:sample({[8] = namesOnlyLuid, [9] = '?', [27] = map}); f:update()
            eq(f.names, 'GPU_NAMES|1|1001|' .. map); eq(f.launches[driver], 1)
            f:sample({[27] = map}); f:update(); eq(f.names, '', 'a reply for a real adapter LUID is rejected')
            eq(f.meter.ToolTipText, reason)
            f.statuses[driver] = 1; f:update(); eq(f.names, '')
            eq(f.meter.ToolTipText, reason, 'a stopped host keeps the metadata reason'); f:ownedClean()
        end
        local f = fixture({metadata = 'NONE'}); f:start()
        eq(f.launches[driver], nil, 'a session must echo the names-only LUID'); eq(f.meter.Text, 'Unavailable')
    end)
    test('a request change keeps names of PIDs still requested and withholds re-entered ones until answered', function()
        local game, tool, extra = '7,' .. hex('game.exe'), '42,' .. hex('tool.exe'), '9,' .. hex('extra.exe')
        local f = fixture({pids = '7,42'}); f:live({[27] = game .. ';' .. tool})
        eq(f.names, 'GPU_NAMES|1|1000|' .. game .. ';' .. tool)
        -- The helper has not read request 2 yet; its reply to request 1 still names 7.
        f.outputs.MeasureGPUProcessController = '7,9'; f.now = 1001
        f:sample({[26] = '1', [27] = game .. ';' .. tool}); f:update()
        eq(f.files[leasePath], token .. '|1001|2|7,9')
        eq(f.names, 'GPU_NAMES|1|1001|' .. game, 'a continuing PID keeps its name and a dropped one loses it')
        f.now = 1002; f:sample({[27] = game .. ';' .. extra}); f:update()
        eq(f.names, 'GPU_NAMES|1|1002|' .. game .. ';' .. extra)
        -- 42 re-enters at request 3. Neither a reply to request 2, which dropped
        -- it, nor one to request 1, from before it left, may name it: a listed
        -- PID is not pinned between samples and may have been reused.
        f.outputs.MeasureGPUProcessController = '7,42'; f.now = 1003
        f:sample({[26] = '2', [27] = game}); f:update()
        eq(f.names, 'GPU_NAMES|1|1003|' .. game, 'a reply to a request without 42 cannot name it')
        f:sample({[26] = '1', [27] = game .. ';' .. tool}); f:update()
        eq(f.names, 'GPU_NAMES|1|1003|' .. game, 'a re-entered PID needs a reply at or after its re-entry')
        f.now = 1004; f:sample({[27] = game .. ';' .. tool}); f:update()
        eq(f.names, 'GPU_NAMES|1|1004|' .. game .. ';' .. tool)
        f:sample({[26] = '4', [27] = game}); f:update(); eq(f.names, '', 'an uncommitted request number')
        f:sample({[26] = '2', [27] = game .. ';' .. tool}); f:update(); eq(f.names, '', 'a PID the old request never asked for')
        for i = 1, 32 do
            f.outputs.MeasureGPUProcessController = '7,' .. (100 + i); f.now = 1004 + i; f:sample(); f:update()
        end
        f:sample({[26] = '4', [27] = game}); f:update(); contains(f.names, 'GPU_NAMES|1|')
        f:sample({[26] = '3', [27] = game}); f:update(); eq(f.names, '', 'a request older than the bounded history')
    end)
    test('matching process names are data-only and retain telemetry and numeric return value', function()
        local map = '7,' .. hex('game.exe') .. ';42,' .. hex('渲染.exe')
        local f = fixture({pids = '7,42'}); f:live({[27] = map})
        local n, names = f:update(); eq(n, 25, 'Core activity accompanies the name packet'); eq(names, 'GPU_NAMES|1|1000|' .. map)
        eq(f.meter.Text, '42 °C'); eq(f:text('MeterPowerValue'), '55.3 W')
        -- A name is never inserted in a controller Bang; the graph handles text.
        for _, call in ipairs(f.calls) do
            for _, value in ipairs(call) do eq(tostring(value):find('game.exe', 1, true), nil) end
        end
        f:sample({[26] = '0', [27] = map}); f:update(); eq(f.names, '')
        eq(f.meter.Text, '42 °C'); eq(f:text('MeterPowerValue'), '55.3 W')
        f:sample({[27] = map}); f:update(); eq(f.names, 'GPU_NAMES|1|1000|' .. map)
        f.outputs.MeasureGPUProcessController = '43'; f.now = 1005; f:sample({[27] = map}); f:update()
        eq(f.names, '', 'changed request rejects old response immediately on heartbeat')
        f:sample({[27] = '43,' .. hex('new.exe')}); f:update()
        eq(f.names, 'GPU_NAMES|1|1005|43,' .. hex('new.exe'))
        f.env.Stop(); eq(select(2, f:update()), '')
    end)
    test('invalid process maps clear names alone including unknown PIDs and invalid UTF-8', function()
        local good = '7,' .. hex('game.exe')
        local maps = {'?', '', '7,' .. hex(' '), '7,' .. hex('.'), '7,' .. hex('..'), '7,', '7,GG', '07,' .. hex('game.exe'), '8,' .. hex('game.exe'),
            good .. ';' .. good, good .. ';', ';' .. good, '7,' .. hex('C:\\game.exe'),
            '7,' .. hex('folder/game.exe'), '7,' .. hex('bad\nname.exe'), '7,C080', '7,EDA080',
            '7,' .. string.rep('61', 129), string.rep('a', 2680)}
        for _, map in ipairs(maps) do
            local f = fixture({pids = '7'}); f:live({[27] = good}); eq(f.names, 'GPU_NAMES|1|1000|' .. good)
            f:sample({[27] = map}); f:update(); eq(f.names, '')
            eq(f.meter.Text, '42 °C'); eq(f:text('MeterPowerValue'), '55.3 W')
        end
        for _, request in ipairs({'-1', '01', '1.0', '1e0', '2', '?', '9007199254740992'}) do
            local f = fixture({pids = '7'}); f:live({[26] = request, [27] = good})
            eq(f.names, ''); eq(f.meter.Text, '42 °C')
        end
        local f = fixture({pids = '1,2,3,4,5,6,7,8,9,10'})
        local full = {}; for i=1,10 do full[#full+1] = i .. ',' .. string.rep('61', 128) end
        f:live({[27] = table.concat(full, ';')}); eq(f.names, 'GPU_NAMES|1|1000|' .. table.concat(full, ';'), 'ten maximum names pass')
        f = fixture({pids = '4294967286,4294967287,4294967288,4294967289,4294967290,4294967291,4294967292,4294967293,4294967294,4294967295'}); f:live(); eq(f.files[leasePath], token .. '|1000|1|4294967286,4294967287,4294967288,4294967289,4294967290,4294967291,4294967292,4294967293,4294967294,4294967295', 'the longest request fits the lease')
    end)
    test('common failure clears process names while isolated metric and driver identity failures retain them', function()
        local map = '7,' .. hex('game.exe')
        for _, override in ipairs({{[3]=string.rep('a',32)}, {[2]='3'}}) do
            local f = fixture({pids='7'}); f:live({[27]=map}); contains(f.names, 'GPU_NAMES|1|')
            override[27]=map; f:sample(override); f:update(); eq(f.names,''); f:allUnavailable()
        end
        for _, field in ipairs({6, 10, 14, 17, 22, 24}) do
            local f = fixture({pids='7'}); f:live({[27]=map})
            f:sample({[field]='DEVICE_CHANGED', [27]=map}); f:update()
            eq(f.names, 'GPU_NAMES|1|1000|' .. map, 'names do not depend on the GPU driver'); f:allUnavailable()
        end
        local f = fixture({pids='7'}); f:live({[27]=map}); f.now=1009; f:update(); eq(f.names,'')
        f = fixture({pids='7'}); f:live({[27]=map}); f.statuses[driver]=1; f:update(); eq(f.names,'')
        f = fixture({pids='7'}); f:live({[27]=map, [6]='UNSUPPORTED', [7]='?'})
        contains(f.names, 'GPU_NAMES|1|'); eq(f.meter.Text,'Unsupported')
    end)
    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end
return Suite
