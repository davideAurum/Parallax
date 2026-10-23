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
    -- One RunCommand launcher mints each session and starts the detached host
    -- ('bootstrap' remains its alias here). 'driver' counts host sessions: one
    -- per session whose first lease the controller writes.
    local info, launcher, driver = 'MeasureGPUInfo', 'MeasureGPUTemperatureLauncher', 'host session'
    local bootstrap = launcher
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
    -- Freshness probes read ValueRaw0..7; like the value list they serve every
    -- override, so they count as inventory rather than either field's bank.
    local function inventory(name) return name == 'MeasureGPURegistryNames' or name:match('^MeasureGPUExportProbe[0-7]$') ~= nil end
    for index = 0, 7 do registryNames['MeasureGPUExportProbe' .. index] = true end
    local function canonical(value) return tostring(value or ''):match('^%s*(.-)%s*$') end
    local function fixture(options)
        options = options or {}
        local f = {now = 1000, calls = {}, meter = {}, meters = {}, parameters = {}, launches = {}, kills = {}, reads = {},
            registryEnables = {}, registryUpdates = {}, initializing = false, history = {}, pushes = 0,
            files = {[foreignPath] = 'preserve'}, removed = {}, leaseWrites = 0, vars = options.vars or {},
            statuses = {[info] = options.infoStatus or 1, [launcher] = options.bootstrapStatus or -1},
            outputs = {[info] = options.metadata or metadata, [launcher] = '', MeasureGPUProcessController = options.pids or '?'},
            exports = {MeasureGPURegistryNames = 'Sensor3|Label3|Value3|ValueRaw3|Sensor4|Label4|Value4|ValueRaw4',
                MeasureGPUPowerSensor = adapter, MeasureGPUPowerLabel = 'GPU Power',
                MeasureGPUPowerValue = '77.7 W', MeasureGPUPowerValueRaw = '77.7',
                MeasureGPUClockSensor = adapter, MeasureGPUClockLabel = 'GPU Clock',
                MeasureGPUClockValue = '1234.5 MHz', MeasureGPUClockValueRaw = '1234.5',
                -- Only ValueRaw3/4 exist in the default list; they mirror the mapped indices.
                MeasureGPUExportProbe3 = '77.7', MeasureGPUExportProbe4 = '1234.5'}}
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
            f.formulas = f.formulas + 1
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
                else assert(inventory(name) and (canonical(f.vars.GPUPowerSource) == '1' or canonical(f.vars.GPUClockSource) == '1'),
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
                    assert((isBar and args[2] == 'Shape2') or (not isBar and args[2] == 'Text'),
                        'unexpected meter option (tooltips were removed)')
                    if args[2] ~= 'Shape2' then assert(not args[3]:find('[#%[%]"%c]'), 'unsafe display data') end
                    f.meters[args[1]] = f.meters[args[1]] or {}
                    f.meters[args[1]][args[2]] = args[3]
                elseif args[1] == 'MeasureGPUUtilizationHistory' then
                    assert(args[2] == 'Formula' and args[3]:match('^%d+$') and tonumber(args[3]) <= 100,
                        'a History point is a literal 0-100 percentage')
                    f.historyFormula = args[3]
                else
                    assert(args[1] == launcher and args[2] == 'Parameter', 'unexpected helper option')
                    -- The launcher compiles nothing; the host reads the fixed
                    -- source by the absolute path the launcher substitutes.
                    assert(args[3]:find("[IO.Directory]::GetCurrentDirectory(),'DriverTemperature.cs.txt')", 1, true)
                        and args[3]:find("ReadAllText(''@S@'')", 1, true)
                        and not args[3]:find("ReadAllText('DriverTemperature", 1, true), 'fixed source only')
                    f.parameters[args[1]] = args[3]
                end
            elseif command == '!CommandMeasure' then
                assert(#args == 2 and args[1] == launcher, 'unexpected subprocess target')
                if args[2] == 'Run' then
                    assert(f.parameters[args[1]], 'helper must have a parameter')
                    f.sessionPending = true
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
                else assert(inventory(args[1]) and (canonical(f.vars.GPUPowerSource) == '1' or canonical(f.vars.GPUClockSource) == '1'), 'unselected inventory enabled') end
                f.registryEnables[args[1]] = (f.registryEnables[args[1]] or 0) + 1
                assert(f.registryEnables[args[1]] == 1, 'registry measure enabled repeatedly')
            elseif command == '!UpdateMeasure' then
                assert(#args == 1)
                if registryNames[args[1]] then
                    assert(f.initializing and f.registryEnables[args[1]] == 1, 'registry update must follow initialization enable')
                    f.registryUpdates[args[1]] = (f.registryUpdates[args[1]] or 0) + 1
                    assert(f.registryUpdates[args[1]] == 1, 'registry update repeatedly forced')
                elseif args[1] == 'MeasureGPUUtilizationHistory' then
                    local previous = f.calls[#f.calls - 1]
                    assert(previous and previous[1] == '!SetOption' and previous[2] == args[1], 'the History Calc is forced right after its point is set')
                    f.history[#f.history + 1] = tonumber(f.historyFormula)
                elseif args[1] == 'MeasureGPUGraphSamples' then
                    local previous = f.calls[#f.calls - 1]
                    assert(previous and previous[1] == '!UpdateMeasure' and previous[2] == 'MeasureGPUUtilizationHistory', 'the point count follows the point')
                else
                    assert(args[1] == launcher, 'unexpected forced update')
                    if f.statusOnRefresh and f.statusOnRefresh[args[1]] ~= nil then
                        f.statuses[args[1]] = f.statusOnRefresh[args[1]]
                        f.statusOnRefresh[args[1]] = nil
                    end
                end
            elseif command == '!UpdateMeter' then
                assert(#args == 1 and args[1] == 'MeterGPUUtilizationGraph', 'only the History graph is forced')
                local previous = f.calls[#f.calls - 1]
                assert(previous and previous[1] == '!UpdateMeasure' and previous[2] == 'MeasureGPUGraphSamples', 'the graph pushes after its point and count')
                f.pushes = f.pushes + 1
            elseif command == '!UpdateMeterGroup' or command == '!Redraw' then
                -- Every GPUDriverReadout meter keeps UpdateDivider=1, so the normal
                -- end-of-cycle redraw paints changes; Update must not force an
                -- extra mid-cycle frame.
                error('Update forced a mid-cycle paint: ' .. command)
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
                    f.files[filename] = value; f.leaseWrites = f.leaseWrites + 1; self.wrote = true; return self
                end
                function handle:close()
                    if f.failClose then return nil end
                    -- The first committed lease after a launch starts a host session.
                    if self.wrote and f.sessionPending then
                        f.sessionPending = false; f.launches[driver] = (f.launches[driver] or 0) + 1
                    end
                    return true
                end
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
        -- Counts hex-decoded bytes (string.char) so tests can tell when a
        -- snapshot's names or adapter field were decoded again.
        f.chars, f.formulas = 0, 0
        local countedString = setmetatable({char = function(...) f.chars = f.chars + 1; return string.char(...) end}, {__index = string})
        local env = setmetatable({SKIN = skin, SELF = {}, io = fakeio, string = countedString, os = setmetatable(fakeos, {__index = function() return forbidden end}),
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
            self.outputs[launcher] = output or sessionOutput(); self.statuses[launcher] = 1; self:update()
        end
        -- The detached host stops: it removes its snapshot and publishes no
        -- more, and the controller sees only that, after its liveness grace.
        function f:hostStops() self.files[dataPath] = nil; self.now = self.now + 31 end
        function f:live(overrides) self:start(); self:sample(overrides); self:update() end
        function f:clear() self.calls = {} end
        function f:text(meter) return self.meters[meter] and self.meters[meter].Text end
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
        contains(f.parameters[launcher], "[ParallaxGpuTemperature]::Run(''@T@'',''" .. luid .. "'',2000)")
        for _ = 1, 4 do f:update() end; eq(f.launches[bootstrap], 1)
        f:live(); eq(f.launches[driver], 1); eq(f.leaseWrites, 1); eq(f.files[leasePath], token .. '|1000|0|?')
        eq(f.meter.Text, '42 °C')
        f:clear(); for _ = 1, 4 do f:update() end
        eq(#f.calls, 0, 'deduplicated unchanged view'); eq(f.leaseWrites, 1); eq(f.reads[info], 1)
        eq(f.launches[bootstrap], 1); eq(f.launches[driver], 1)
        -- The launcher starts the host hidden and detached, then exits.
        local launch = f.parameters[launcher]
        local _, quotes = launch:gsub('"', '')
        eq(quotes, 2, 'one quoted -Command argument'); eq(launch:sub(-1), '"')
        contains(launch, '-Command "'); contains(launch, 'Start-Process'); contains(launch, '-WorkingDirectory $t -WindowStyle Hidden -PassThru')
        contains(launch, "'-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -Command '")
        contains(launch, "[ParallaxGpuTemperature]::Run(''@T@'',''" .. luid .. "'',2000)")
        -- It mints the session itself: a GUID token and an exclusively created
        -- lease; it prints the session and removes its lease on failure.
        contains(launch, "[guid]::NewGuid().ToString('N')"); contains(launch, "'CreateNew','Write','Read'")
        contains(launch, "'GPU_TEMP_SESSION|1|'+$k+'|'"); contains(launch, "+'|" .. luid .. "')")
        contains(launch, '[IO.File]::Delete($l)'); contains(launch, '-lt 10000')
        eq(launch:find('CreateSession', 1, true), nil)
    end)
    test('the detached host counts as stopped after twice the freshness window without a sample', function()
        local f = fixture(); f:live()
        f.now = 1001; f:update(); eq(f.meter.Text, '42 °C')
        f.now = 1008; f:update(); eq(f.meter.Text, '42 °C', 'current through its whole freshness window')
        f.now = 1009; f:update(); eq(f.meter.Text, 'Unavailable', 'a late sample is hidden at once')
        f.now = 1030; f:update(); eq(f.meter.Text, 'Unavailable'); eq(next(f.removed), nil, 'a late host may still resume')
        f.now = 1031; f:update(); eq(f.meter.Text, 'Unavailable'); f:ownedClean()
        eq(f.kills[launcher], nil, 'a completed launcher is never killed'); eq(f.launches[driver], 1, 'no relaunch')
        f.now = 1040; f:update(); eq(f.launches[launcher], 1, 'no retry before 10 s')
        f.now = 1041; f:update(); eq(f.launches[launcher], 2, 'a retry after 10 s'); eq(f.meter.Text, 'Checking...')
        f = fixture(); f:live()
        f.now = 1025; f:update(); eq(f.meter.Text, 'Unavailable')
        f:sample({[4] = '2'}); f:update(); eq(f.meter.Text, '42 °C', 'a late host resumes within the grace')
        f.now = 1055; f:update(); eq(next(f.removed), nil); f.now = 1056; f:update(); f:ownedClean()
    end)
    test('a launcher that does not report a valid session ends the attempt without Kill', function()
        for _, output in ipairs({'', 'GPU_TEMP_FAILED', 'GPU_TEMP_STARTED', sessionOutput() .. '|extra'}) do
            local f = fixture(); f:start(output); eq(f.meter.Text, 'Unavailable'); eq(f.kills[launcher], nil)
            eq(f.leaseWrites, 0); eq(next(f.removed), nil, 'no unvalidated path is touched')
            f:update(); eq(f.launches[launcher], 1); eq(f.launches[driver], nil)
        end
    end)
    test('changed readings are written as options without a forced mid-cycle paint', function()
        local f = fixture(); f:live(); f:clear()
        for sequence = 2, 5 do
            f.now = f.now + 2; f:sample({[4] = tostring(sequence), [23] = tostring(50000 + sequence * 1000)}); f:update()
        end
        local writes = 0
        for _, call in ipairs(f.calls) do
            eq(call[1] ~= '!Redraw' and call[1] ~= '!UpdateMeterGroup', true, 'no forced paint: ' .. tostring(call[1]))
            if call[1] == '!SetOption' and call[2] == 'MeterPowerValue' then writes = writes + 1 end
        end
        eq(writes, 4, 'each changed power reading is written once'); eq(f:text('MeterPowerValue'), '55.0 W')
    end)
    test('an unchanged snapshot is not parsed, decoded or written again but still ages out', function()
        local map = '7,' .. hex('game.exe')
        local f = fixture({pids = '7'}); f:live({[27] = map})
        local names, vram = f.names, f:text('MeterGPUVRAMValue')
        contains(names, 'GPU_NAMES|1|1000|7,'); f:clear(); f.chars, f.formulas = 0, 0
        for _ = 1, 3 do f:update() end
        eq(#f.calls, 0, 'no option writes'); eq(f.chars, 0, 'no hex decoding'); eq(f.formulas, 0, 'no geometry parsing')
        eq(f.names, names, 'names kept'); eq(f:text('MeterGPUVRAMValue'), vram); eq(f.meter.Text, '42 °C')
        eq((f:update()), 25, 'Core load kept')
        f:sample({[4] = '2'}); f:update(); eq(f.chars > 0, true, 'a new snapshot is decoded')
        f.now = 1009; f:update(); f:allUnavailable(); eq(f.names, '', 'an unchanged snapshot still ages out')
        local n = fixture({metadata = 'NONE', pids = '7'}); n:start(sessionOutput({[5] = namesOnlyLuid}))
        n:sample({[8] = namesOnlyLuid, [9] = '?', [27] = map}); n:update(); contains(n.names, 'GPU_NAMES|1|1000|7,')
        n:clear(); n.chars = 0; n:update(); n:update()
        eq(#n.calls, 0, 'names only: no writes'); eq(n.chars, 0, 'names only: no decoding')
        contains(n.names, 'GPU_NAMES|1|1000|7,'); n:allUnavailable()
    end)
    test('an unchanged snapshot is re-filtered at once when the name request changes', function()
        local map = '7,' .. hex('game.exe')
        local f = fixture({pids = '7'}); f:live({[27] = map}); contains(f.names, 'GPU_NAMES|1|1000|7,')
        f.outputs.MeasureGPUProcessController = '8'; f.now = 1001; f:update()
        eq(f.names, '', 'a PID dropped from the request loses its name at once')
        f.outputs.MeasureGPUProcessController = '7'; f.now = 1002; f:update()
        eq(f.names, '', 'a re-entered PID waits for a reply at or after its re-entry')
        eq(f.meter.Text, '42 °C', 'readings stay valid throughout')
    end)
    test('bar geometry is resolved once per load, not on every bar write', function()
        for _, case in ipairs({{vars = {}, width = 98, thickness = 6},
            {vars = {ContentWidth = '(#PanelWidth#-2*#Padding#)', DataBarThickness = '12', Scale = '1.5'}, width = 47, thickness = 18}}) do
            local f = fixture({vars = case.vars}); f:live(); local parsed = f.formulas
            eq(parsed > 0, true, 'formula variables are resolved')
            for sequence = 2, 4 do
                f.now = f.now + 2
                f:sample({[4] = tostring(sequence), [13] = tostring(6442450944 - sequence * 1000000000), [18] = tostring(10 * sequence)}); f:update()
            end
            eq(f.formulas, parsed, 'no geometry parse after the first')
            eq(f:text('MeterGPUVRAMValue'), '6.1/8.6 GB'); eq(f:text('MeterGPULoadValue'), '40%')
            local endpoint, stroke = f:bar('MeterGPULoadBar')
            eq(stroke, case.thickness, 'cached thickness')
            eq(endpoint, tonumber(string.format('%.3f', case.width * 0.4)), 'cached engine width')
            endpoint = f:bar('MeterGPUVRAMBar')
            eq(endpoint, tonumber(string.format('%.3f', 200 * 6147483648 / 8589934592)), 'cached content width')
        end
    end)
    test('a snapshot shown unavailable in between is validated and shown again in full', function()
        local f = fixture(); f:live(); local saved = f.files[dataPath]
        f.files[dataPath] = nil; f:update(); eq(f.meter.Text, 'Checking...'); eq(f:text('MeterActivityValue'), '--')
        f.files[dataPath] = saved; f:update()
        eq(f.meter.Text, '42 °C'); eq(f:text('MeterActivityValue'), '25%'); eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB')
    end)
    test('the History graph records exactly one point per new driver sample', function()
        local starting = {[4] = '0', [6] = 'STARTING', [7] = '?', [9] = '?'}
        for _, index in ipairs({10, 14, 17, 22, 24}) do starting[index] = 'STARTING' end
        for _, index in ipairs({11, 12, 13, 15, 16, 18, 19, 20, 21, 23, 25}) do starting[index] = '?' end
        local f = fixture(); eq(#f.history, 0, 'nothing while metadata is pending')
        f:start(); f.now = 1005; f:update(); eq(#f.history, 0, 'nothing before the first sample')
        f:sample(starting); f:update(); eq(f.meter.Text, 'Checking...'); eq(#f.history, 0, 'a starting snapshot has no reading to plot')
        f:sample({[4] = '1', [18] = '30'}); f:update(); eq(table.concat(f.history, ','), '30')
        for _ = 1, 3 do f:update() end
        eq(#f.history, 1, 'an unchanged sample is not plotted again')
        f.now = 1006; f:update(); eq(#f.history, 1, 'a tick without a new sample adds nothing')
        f.now = 1007; f:sample({[4] = '2', [18] = '45'}); f:update(); eq(table.concat(f.history, ','), '30,45')
        f:sample({[4] = '2', [18] = '99'}); f:update(); eq(#f.history, 2, 'a rewritten sequence is not a new sample')
        f.now = 1009; f:sample({[4] = '3', [17] = 'UNSUPPORTED', [18] = '?', [19] = '?', [20] = '?', [21] = '?'}); f:update()
        eq(table.concat(f.history, ','), '30,45,0', 'unsupported activity traces 0 at the sample cadence')
        eq(f.pushes, #f.history, 'every point is pushed to the graph once')
    end)
    test('while the reading is unavailable the History traces 0 once per sampling interval', function()
        local f = fixture({metadata = 'NONE'})
        eq(table.concat(f.history, ','), '0', 'names-only mode traces 0')
        f:update(); f.now = 1001; f:update(); eq(#f.history, 1, 'not again within the interval')
        f.now = 1002; f:update(); eq(table.concat(f.history, ','), '0,0')
        f = fixture(); f:live(); eq(table.concat(f.history, ','), '25')
        f.now = 1009; f:update(); eq(table.concat(f.history, ','), '25,0', 'a stale reading traces 0')
        f.now = 1010; f:update(); eq(#f.history, 2); f.now = 1011; f:update(); eq(table.concat(f.history, ','), '25,0,0')
        f:sample({[4] = '2', [18] = '60'}); f:update(); eq(table.concat(f.history, ','), '25,0,0,60', 'a fresh sample resumes the trace')
        f = fixture(); f:live(); f.now = 1002; f:sample({[4] = '2', [6] = 'DEVICE_CHANGED'}); f:update()
        eq(table.concat(f.history, ','), '25,0', 'a changed device traces 0')
        f = fixture(); f:live(); f:hostStops(); f:update(); eq(table.concat(f.history, ','), '25,0', 'a stopped host traces 0')
        f.now = f.now + 1; f:update(); eq(#f.history, 2, 'not within the interval of the last point')
        f.now = f.now + 1; f:update(); eq(table.concat(f.history, ','), '25,0,0', 'the zero trace keeps the sampling cadence')
        f.env.Stop(); f.now = f.now + 10; f:update(); eq(#f.history, 3, 'nothing after Stop')
        -- At a 5 s interval a sample stays fresh for 17 s, then 0 is traced every 5 s.
        f = fixture({vars = {SensorInterval = '5000'}}); f:live(); f.now = 1017; f:update(); eq(#f.history, 1, 'still fresh')
        f.now = 1018; f:update(); f.now = 1022; f:update()
        eq(table.concat(f.history, ','), '25,0', 'the zero cadence follows the sampling interval')
        f.now = 1023; f:update(); eq(table.concat(f.history, ','), '25,0,0')
    end)
    test('interval follows slower collection cadence and bounded integer limits', function()
        local cases = {{{MetricsInterval = '5000', SensorInterval = '2000'}, 5000},
            {{MetricsInterval = '300', SensorInterval = '400'}, 1000},
            {{MetricsInterval = '30001', SensorInterval = '2000'}, 30000},
            {{MetricsInterval = 'bad', SensorInterval = '2500.9'}, 2500},
            {{MetricsInterval = '1e309', SensorInterval = '2000'}, 2000}}
        for _, item in ipairs(cases) do
            local f = fixture({vars = item[1]}); contains(f.parameters[launcher], "''," .. item[2] .. ') }')
        end
    end)
    test('pending or missing metadata has a deadline, then runs names only and never launches from stale output', function()
        for _, status in ipairs({-1, 0, 2, 101, 102, 103}) do
            local f = fixture({infoStatus = status}); eq(f.meter.Text, 'Checking...'); eq(f.reads[info], nil)
            f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable')
            eq(f.launches[bootstrap], 1); contains(f.parameters[launcher], "''@T@'',''" .. namesOnlyLuid .. "'',2000)")
            f.statuses[info] = 1; f.now = 2000; f:update(); eq(f.launches[bootstrap], 1); eq(f.reads[info], nil, 'late metadata is never read')
        end
        local f = fixture({missingInfo = true}); f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable')
        contains(f.parameters[launcher], "''@T@'',''" .. namesOnlyLuid .. "'',")
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
        local f = fixture({metadata = 'NONE', bootstrapStatus = -1})
        eq(f.meter.Text, 'Unavailable'); namesOnlyBootstrap(f); eq(f.kills[bootstrap], nil)
        f.env.Stop(); namesOnlyBootstrap(f); eq(f.kills[bootstrap], nil, 'a running bootstrap is left to RunCommand unload termination')
        for _, statusValue in ipairs({0, -1}) do
            f = fixture({infoStatus = statusValue, bootstrapStatus = -1})
            eq(f.meter.Text, 'Checking...'); untouched(f)
            f.now = 1014; f:update(); eq(f.meter.Text, 'Unavailable'); namesOnlyBootstrap(f)
            f = fixture({infoStatus = statusValue, bootstrapStatus = -1})
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
            eq(f.launches[bootstrap], 1); contains(f.parameters[launcher], "''@T@'',''" .. namesOnlyLuid .. "'',2000)")
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
    test('launcher deadline prevents repeated launches or delayed stale completion', function()
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
        eq(f.launches[driver], 1)
        f:sample({[4] = '2'}); f:update()
        eq(f.meter.Text, '42 °C')
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
        -- The launcher has reported, so nothing is killed: removing the lease
        -- is the detached host's stop request.
        eq(f.meter.Text, 'Unavailable'); eq(f.kills[launcher], nil); f:ownedClean()
        f.failOpen = false; f:update(); eq(f.launches[driver], 1)
    end)
    test('a stopped host cannot leave a plausible retained reading or a restart loop', function()
        local f = fixture(); f:live(); f.files[tmpPath] = 'partial'
        f:hostStops(); f:update(); eq(f.meter.Text, 'Unavailable'); f:ownedClean()
        -- Bounded recovery: retries after 10, 60 and 300 s (each launcher here
        -- never reports), then nothing more until refresh.
        local launches = 1
        for _, delay in ipairs({10, 60, 300}) do
            local failedAt = f.now
            f.now = failedAt + delay - 1; f:update(); eq(f.launches[launcher], launches)
            f.now = failedAt + delay; f:update(); launches = launches + 1; eq(f.launches[launcher], launches)
            eq(f.meter.Text, 'Checking...', 'a retry shows Checking..., never the old reading')
            f.now = f.now + 20; f:update(); eq(f.meter.Text, 'Unavailable'); eq(f.kills[launcher], launches - 1)
        end
        f.now = f.now + 100000; f:update(); eq(f.launches[launcher], 4); eq(f.meter.Text, 'Unavailable')
        eq(f.launches[driver], 1, 'no retried launcher reported a session')
    end)
    test('a retried session recovers, a long healthy session resets the count, and Stop cancels a retry', function()
        -- Reproduced owner symptom (RAM, same design here): the host's lease
        -- lapsed while Rainmeter was suspended, and readings stayed Unavailable
        -- with no host until refresh.
        local f = fixture(); f:live()
        f:hostStops(); f:update(); eq(f.meter.Text, 'Unavailable')
        f.now = f.now + 10; f:update(); eq(f.launches[launcher], 2); eq(f.meter.Text, 'Checking...')
        f:start(); eq(f.launches[driver], 2, 'the retry starts a new host session')
        eq(f.files[leasePath], token .. '|' .. f.now .. '|0|?')
        f:sample({[4] = '1'}); f:update(); eq(f.meter.Text, '42 °C', 'a retried session restarts its sequence')
        local start = f.now
        for second = 2, 600, 2 do f.now = start + second; f:sample({[4] = tostring(1 + second / 2)}); f:update() end
        eq(f.meter.Text, '42 °C')
        f:hostStops(); f:update(); f.now = f.now + 9; f:update(); eq(f.launches[launcher], 2)
        f.now = f.now + 1; f:update(); eq(f.launches[launcher], 3, 'after 10 healthy minutes the first retry is again after 10 s')
        f = fixture(); f:live(); f:hostStops(); f:update(); f.env.Stop()
        f.now = f.now + 1000; f:update(); eq(f.launches[launcher], 1, 'Stop cancels a pending retry')
        -- Names-only sessions recover the same way and stay names-only.
        f = fixture({metadata = 'NONE'}); f:start(sessionOutput({[5] = namesOnlyLuid})); eq(f.launches[driver], 1)
        f:hostStops(); f:update(); f.now = f.now + 10; f:update(); eq(f.launches[launcher], 2)
        contains(f.parameters[launcher], "'',''" .. namesOnlyLuid .. "'',2000)"); eq(f.meter.Text, 'Unavailable')
    end)
    test('Stop removes owned lease/snapshot/temp files and never restarts helpers', function()
        -- Removing the lease is the detached host's stop request. Stop sends no
        -- Kill: RunCommand's unload terminates a running setup command once.
        local f = fixture(); f:live(); f.files[tmpPath] = 'partial'; f.env.Stop(); f:ownedClean()
        eq(f.kills[bootstrap], nil, 'finished bootstrap need not be killed'); eq(f.kills[driver], nil)
        f:clear(); f.now = 2000; f:update(); eq(#f.calls, 0); eq(f.launches[driver], 1)
        f = fixture(); f:clear(); f.env.Stop(); eq(next(f.removed), nil, 'no files removed before session accepted')
        eq(f.kills[bootstrap], nil, 'a running bootstrap is left to RunCommand unload'); eq(f.kills[driver], nil)
        eq(#f.calls, 0, 'Stop neither commands nor refreshes a provider')
        f:start(); eq(f.launches[driver], nil); eq(f.leaseWrites, 0)
    end)
    test('failure kills the owned running launcher exactly once; Stop never kills', function()
        for _, action in ipairs({'failure', 'Stop'}) do
            local f = fixture()
            eq(f.launches[launcher], 1); eq(f.statuses[launcher], 0, 'RunCommand is actively running')
            if action == 'Stop' then f.env.Stop() else f.now = 1020; f:update() end
            local expected = action == 'failure' and 1 or nil
            eq(f.kills[launcher], expected)
            eq(f.statuses[launcher], 0, 'asynchronous Kill may retain RUN until the plugin updates')
            f.env.Stop(); f.env.Stop(); eq(f.kills[launcher], expected, 'repeated shutdown cannot send another Kill')
            eq(next(f.removed), nil)
        end
        -- Once the launcher has reported, nothing is killed: removing the
        -- lease is the detached host's stop request.
        for _, action in ipairs({'failure', 'Stop'}) do
            local f = fixture(); f:live()
            if action == 'Stop' then f.env.Stop() else f.failOpen = true; f.now = 1005; f:update() end
            eq(f.kills[launcher], nil); f:ownedClean()
        end
    end)
    test('owned initial, completed and error states are never killed on failure or Stop', function()
        for _, stateValue in ipairs({-1, 1, 2, 101, 102, 103}) do
            for _, action in ipairs({'failure', 'Stop'}) do
                local f = fixture(); eq(f.launches[launcher], 1); f.statuses[launcher] = stateValue
                if action == 'Stop' then f.env.Stop() else f.now = 1020; f:update() end
                eq(f.kills[launcher], nil)
                f.env.Stop(); eq(f.kills[launcher], nil)
            end
        end
    end)
    test('unowned helper status cannot authorize Kill even if the plugin reports RUN', function()
        for _, stateValue in ipairs({-1, 0, 1, 101, 102, 103}) do
            local f = fixture({metadata = 'NONE', bootstrapStatus = stateValue})
            eq(f.meter.Text, 'Unavailable'); f.env.Stop()
            eq(f.launches[launcher], 1, 'the names-only launcher is owned'); eq(f.launches[driver], nil)
            eq(f.kills[launcher], nil, 'Stop never kills')
            f = fixture({infoStatus = 0, bootstrapStatus = stateValue})
            f.env.Stop(); eq(f.launches[launcher], nil); eq(f.launches[driver], nil)
            eq(f.kills[launcher], nil)
        end
    end)
    test('failure refreshes stale plugin status before deciding whether the launcher is live', function()
        for _, stateValue in ipairs({1, 101, 102, 103}) do
            local f = fixture(); eq(f.statuses[launcher], 0)
            f.statusOnRefresh = {[launcher] = stateValue}; f.now = 1020; f:update()
            eq(f.statuses[launcher], stateValue); eq(f.kills[launcher], nil, 'completed/error status supersedes cached RUN')
        end
        local f = fixture(); f.statuses[launcher] = -1; f.statusOnRefresh = {[launcher] = 0}; f.now = 1020; f:update()
        eq(f.kills[launcher], 1, 'fresh RUN status supersedes cached initial state for an owned helper')
    end)
    test('memory capacity and activity domains stay separate in their units', function()
        local f = fixture(); f:live()
        eq(f:text('MeterGPUVRAMValue'), '2.1/8.6 GB')
        eq(f:text('MeterGPUSharedValue'), '182 MB')
        local endpoint, stroke, y = f:bar(); eq(endpoint, 50); eq(stroke, 6); eq(y, 3) -- fixture ContentWidth 200
        for index, name in ipairs(loadMeters) do eq(f:text(name), tostring(index * 25) .. '%') end
        for index, name in ipairs(loadBars) do
            local endpoint, stroke, y = f:bar(name); eq(endpoint, index * 25 / 100 * engineWidth, name); eq(stroke, 6); eq(y, 3)
            contains(f.meters[name].Shape2, 'Stroke Color #GPUColor#')
        end
        contains(f.meters.MeterGPUVRAMBar.Shape2, 'StrokeStartCap Flat | StrokeEndCap Flat')
        contains(f.meters.MeterGPUVRAMBar.Shape2, 'Stroke Color #GPUColor#')
    end)
    test('headline activity follows the Core domain and is the numeric return value', function()
        local f = fixture(); f:start(); f:sample()
        local n = f:update(); eq(n, 25); eq(f:text('MeterActivityValue'), '25%')
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
        f = fixture(); f:live(); f:hostStops(); n = f:update(); eq(n, 0, 'stopped host'); f:allUnavailable()
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
        f = fixture(); f:live(); f:hostStops(); f:update(); f:allUnavailable()
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
            if not selection[1] then eq(f.reads.MeasureGPUPowerValue, nil) end
            if not selection[2] then eq(f.reads.MeasureGPUClockValue, nil) end
        end
        local options = manualOptions(true, false); options.vars.GPUEnableSensors = '0'
        local f = fixture(options); f:live()
        eq(f:text('MeterPowerValue'), 'Off'); eq(f:text('MeterClockValue'), '1607.5 MHz')
        eq(f.reads.MeasureGPURegistryNames, nil)
    end)
    test('canonical override selection enables and initializes only its required banks once', function()
        -- One field's four-measure bank, plus the shared value list and the eight
        -- freshness probes (ValueRaw0..7) whenever any override is selected.
        for _, selection in ipairs({{true, false, 13}, {false, true, 13}, {true, true, 17}, {false, false, 0}}) do
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
    -- Advance the fixture clock in 2 s steps with a fresh driver sample each
    -- time, so only the HWiNFO export, never the driver snapshot, can go stale.
    local function hold(f, seconds)
        for _ = 1, seconds / 2 do f.now = f.now + 2; f:sample(); f:update() end
    end
    test('a frozen HWiNFO override export reads Not updating after 60 s and recovers on any change', function()
        local f = fixture(manualOptions(true, false)); f:live()
        eq(f:text('MeterPowerValue'), '77.7 W'); eq(f:text('MeterClockValue'), '1607.5 MHz')
        hold(f, 58)
        eq(f:text('MeterPowerValue'), '77.7 W', 'still within the window')
        hold(f, 2)
        eq(f:text('MeterPowerValue'), 'Not updating')
        eq(f:text('MeterClockValue'), '1607.5 MHz', 'the driver source is unaffected')
        eq(f.meter.Text, '42 °C', 'driver temperature is unaffected')
        hold(f, 120)
        eq(f:text('MeterPowerValue'), 'Not updating', 'stays withheld')
        -- Any probed export value moving restores the reading at once.
        f.exports.MeasureGPUExportProbe4 = '1300.0'; f:update()
        eq(f:text('MeterPowerValue'), '77.7 W', 'any change restores the reading')
        hold(f, 60); eq(f:text('MeterPowerValue'), 'Not updating', 'caught again')
        -- So does the mapped value itself.
        f.exports.MeasureGPUPowerValue, f.exports.MeasureGPUPowerValueRaw = '80.5 W', '80.5'; f:update()
        eq(f:text('MeterPowerValue'), '80.5 W')
        -- Both overrides are withheld together; values lingering after HWiNFO
        -- exits look the same and are withheld the same way.
        f = fixture(manualOptions(true, true)); f:live(); hold(f, 60)
        eq(f:text('MeterPowerValue'), 'Not updating'); eq(f:text('MeterClockValue'), 'Not updating')
        eq(f.launches[bootstrap], 1, 'detection launches nothing')
    end)
    test('an idle mapped clock that holds one value stays live while the export moves', function()
        -- Live 2026-10-23 export: GPU Clock held 139.0 MHz for 36 s while GPU
        -- Power changed on every poll. Here ValueRaw3 stands in for that power.
        local f = fixture(manualOptions(false, true)); f:live()
        for step = 1, 5 do
            hold(f, 40)
            f.exports.MeasureGPUExportProbe3 = tostring(11 + step / 10); f:update()
            eq(f:text('MeterClockValue'), '1234.5 MHz', 'live at step ' .. step)
        end
        hold(f, 60)
        eq(f:text('MeterClockValue'), 'Not updating', 'the whole export froze')
        eq(f:text('MeterPowerValue'), '55.3 W', 'driver power unaffected')
    end)
    test('mapping and availability statuses stay more specific than Not updating', function()
        for _, item in ipairs({
                {vars = {GPUPowerIndex = '-1'}, expected = 'Unmapped'},
                {vars = {GPUPowerIndex = '3.5'}, expected = 'Check mapping'},
                {exports = {MeasureGPUPowerSensor = 'Different GPU'}, expected = 'Check mapping'},
                {exports = {MeasureGPURegistryNames = 'Sensor3|Label3|Value3'}, expected = 'Unavailable'},
                {exports = {MeasureGPUPowerValue = '77.7'}, expected = 'Unavailable'}}) do
            local options = manualOptions(true, false)
            for name, value in pairs(item.vars or {}) do options.vars[name] = value end
            options.exports = item.exports
            local f = fixture(options); f:live(); hold(f, 90)
            eq(f:text('MeterPowerValue'), item.expected)
        end
        local options = manualOptions(true, true); options.vars.GPUEnableSensors = '0'
        local f = fixture(options); f:live(); hold(f, 90)
        eq(f:text('MeterPowerValue'), 'Off'); eq(f:text('MeterClockValue'), 'Off')
    end)
    test('the default driver path never enables or reads the freshness probes', function()
        local f = fixture(); f:live(); hold(f, 120)
        for index = 0, 7 do
            eq(f.registryEnables['MeasureGPUExportProbe' .. index], nil)
            eq(f.reads['MeasureGPUExportProbe' .. index], nil)
        end
        eq(f:text('MeterPowerValue'), '55.3 W'); eq(f:text('MeterClockValue'), '1607.5 MHz')
    end)
    test('probes outside the exported value list are not read; a lone constant export still freezes', function()
        -- Known limit: an export whose only probed values hold perfectly still
        -- for a minute is flagged until one moves.
        local options = manualOptions(false, true)
        options.exports = {MeasureGPURegistryNames = 'Sensor4|Label4|Value4|ValueRaw4', MeasureGPUExportProbe0 = '5'}
        local f = fixture(options); f:live(); hold(f, 60)
        eq(f:text('MeterClockValue'), 'Not updating')
        eq(f.reads.MeasureGPUExportProbe0, nil, 'a probe outside the value list is not read')
        eq((f.reads.MeasureGPUExportProbe4 or 0) > 0, true, 'an exported probe is read')
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
    end)
    test('selected manual exports remain usable and refresh after direct driver failure without relaunch', function()
        local f = fixture(manualOptions(true, true)); f:live()
        f.now = 1009; f:update(); f:allUnavailable()
        eq(f:text('MeterPowerValue'), '77.7 W'); eq(f:text('MeterClockValue'), '1234.5 MHz')
        f:hostStops(); f:update(); f:ownedClean()
        f.exports.MeasureGPUPowerValue, f.exports.MeasureGPUPowerValueRaw = '80.5 W', '80.5'
        f.exports.MeasureGPUClockValue, f.exports.MeasureGPUClockValueRaw = '999.5 MHz', '999.5'
        f.now = f.now + 1; f:update()
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
        eq(f.meter.Text, 'Unavailable'); eq(f.kills[launcher], nil); f:ownedClean()
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
            eq(f.meter.Text, 'Unavailable')
            f:start(sessionOutput({[5] = namesOnlyLuid}))
            eq(f.launches[driver], 1); contains(f.parameters[launcher], "'',''" .. namesOnlyLuid .. "'',2000)")
            eq(f.files[leasePath], token .. '|1000|1|7,42')
            f:update(); eq(f.meter.Text, 'Unavailable', 'no Checking state before the first reply')
            -- GPU readings in a names-only reply (here a plausible 42 C) are never shown.
            f:sample({[8] = namesOnlyLuid, [9] = '?', [27] = map}); f:update()
            eq(f.names, 'GPU_NAMES|1|1000|' .. map); f:allUnavailable()
            f.now = 1001; f:sample({[8] = namesOnlyLuid, [9] = '?', [27] = map}); f:update()
            eq(f.names, 'GPU_NAMES|1|1001|' .. map); eq(f.launches[driver], 1)
            f:sample({[27] = map}); f:update(); eq(f.names, '', 'a reply for a real adapter LUID is rejected')
            eq(f.meter.Text, 'Unavailable')
            f:hostStops(); f:update(); eq(f.names, '')
            eq(f.meter.Text, 'Unavailable', 'a stopped host stays unavailable'); f:ownedClean()
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
        f = fixture({pids='7'}); f:live({[27]=map}); f:hostStops(); f:update(); eq(f.names,'')
        f = fixture({pids='7'}); f:live({[27]=map, [6]='UNSUPPORTED', [7]='?'})
        contains(f.names, 'GPU_NAMES|1|'); eq(f.meter.Text,'Unsupported')
    end)
    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end
return Suite
