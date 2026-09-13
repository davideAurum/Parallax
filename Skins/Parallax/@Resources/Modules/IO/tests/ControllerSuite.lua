-- Original Parallax controller tests for Lua 5.1.
-- All values below are synthetic fixtures supplied only to a mock SKIN/SELF.
-- No fixture is loaded into a real meter, measure, provider, or desktop skin.
-- This suite loads productionPath and its trusted sibling Names.lua; it writes no files, launches no
-- process, and executes no Rainmeter bangs. The caller owns its isolated runner.
-- Usage: local count, report = dofile(thisPath).run(productionPath)
-- A failed test raises its report; success returns the assertion count and report.
local Suite = {}

function Suite.run(productionPath)
    assert(type(productionPath) == 'string' and productionPath ~= '', 'productionPath is required')
    local assertions, passed, failed, report = 0, 0, 0, {}
    local GiB = 1024 * 1024 * 1024
    local namesPath = productionPath:gsub('[^/\\]+$', 'Names.lua')

    local function equal(actual, expected, message)
        assertions = assertions + 1
        if actual ~= expected then
            error((message or 'value') .. ': expected ' .. tostring(expected)
                .. ', got ' .. tostring(actual), 2)
        end
    end

    local function truth(value, message)
        assertions = assertions + 1
        if not value then error(message or 'expected true', 2) end
    end

    local function contains(value, fragment, message)
        truth(type(value) == 'string' and value:find(fragment, 1, true) ~= nil,
            message or ('expected text to contain ' .. fragment))
    end

    local function test(name, body)
        local ok, err = pcall(body)
        if ok then
            passed = passed + 1
            report[#report + 1] = 'PASS: ' .. name
        else
            failed = failed + 1
            report[#report + 1] = 'FAIL: ' .. name .. ': ' .. tostring(err)
        end
    end

    local targets = {}
    for _, name in ipairs({
        'MeterIOTotal', 'MeterIOCapacityHeading', 'MeterIOBounds', 'MeterIOPanel', 'MeterIOEmpty',
        'MeterIODiskGraph', 'MeterIODiskGraphTrack',
        'MeterIOGraphPositive', 'MeterIOGraphZero', 'MeterIOGraphNegative'
    }) do targets[name] = true end
    for code = 65, 90 do
        local letter = string.char(code)
        for _, prefix in ipairs({'MeterIODrive', 'MeterIOCapacity', 'MeterIOUsed',
            'MeterIODiskRead', 'MeterIODiskWrite', 'MeterIODiskReadLabel', 'MeterIODiskWriteLabel', 'MeterIOLegend'}) do
            targets[prefix .. letter] = true
        end
    end

    local function fixture(overrides, samples)
        local vars = {
            IODiskUnits = 'bytes', IODiskDrives = 'C', IOGraphMode = 'combined', IODriveNames = 'letters',
            ['@'] = 'fixture-resources\\',
            Inset = '4', Gap = '8', ContentX = '10', PanelHeight = '157', DataBarThickness = '6',
            IODiskMaxMiBs = '500', CapacityInterval = '30000',
            ContentWidth = '208', Scale = '1', DiskReadColor = '10,20,30', DiskWriteColor = '40,50,60'
        }
        local values = {
            MeasureIOTypeC = 4, MeasureIOTotalC = 100 * GiB, MeasureIOFreeC = 25 * GiB,
            MeasureIODiskReadC = 0, MeasureIODiskWriteC = 0
        }
        for code = 65, 90 do
            local letter = string.char(code)
            if letter ~= 'C' then values['MeasureIOType' .. letter] = 2 end
        end
        for key, value in pairs(overrides or {}) do vars[key] = value end
        for key, value in pairs(samples or {}) do values[key] = value end
        local state = { vars = vars, values = values, options = {}, shown = {}, calls = {}, now = 1000,
            groups = {}, variableWrites = {}, queryRuns = 0 }
        local skin = {}
        function skin:GetVariable(key, default)
            if vars[key] == nil then return default end
            return vars[key]
        end
        function skin:GetMeasure(key)
            local letter = key:match('^MeasureIOTotal([A-Z])$') or key:match('^MeasureIOFree([A-Z])$')
            if letter then assert(state.groups['IOCapacity' .. letter], 'read from a disabled capacity bank') end
            letter = key:match('^MeasureIODiskRead([A-Z])$') or key:match('^MeasureIODiskWrite([A-Z])$')
            if letter then assert(state.groups['IORates' .. letter], 'read from a disabled rate bank') end
            if values[key] == nil then return nil end
            return { GetValue = function() return values[key] end,
                GetStringValue = function() return type(values[key]) == 'string' and values[key] or '' end }
        end
        function skin:ReplaceVariables(value)
            return value:gsub('#([%w]+)#', function(key) return vars[key] or '' end)
        end
        function skin:ParseFormula(value)
            if not value:match('^[%d%s%.%+%-%*/%(%)]+$') then return nil end
            local expression = assert(loadstring('return ' .. value))
            setfenv(expression, {})
            return expression()
        end
        function skin:Bang(command, target, key, value)
            if command == '!CommandMeasure' then
                assert(target == 'MeasureIOModelQuery' and key == 'Run' and value == nil, 'unexpected provider command')
                state.queryRuns = state.queryRuns + 1
            elseif command == '!Redraw' then
                assert(target == nil, 'redraw must stay in the current fixture')
            elseif command == '!EnableMeasureGroup' or command == '!DisableMeasureGroup' or command == '!UpdateMeasureGroup' then
                assert(target:match('^IOCapacity[A-Z]$') or target:match('^IORates[A-Z]$')
                    or (target == 'IOInventory' and command == '!UpdateMeasureGroup'), 'unexpected bank target')
                if command == '!UpdateMeasureGroup' then
                    assert(target == 'IOInventory' or state.groups[target], 'forced update of disabled bank')
                else
                    state.groups[target] = command == '!EnableMeasureGroup'
                end
            elseif command == '!SetVariable' then
                assert(target == 'PanelHeightPx', 'controller attempted to change a saved preference')
                vars[target] = key
                state.variableWrites[#state.variableWrites + 1] = {target, key}
            else
                assert(targets[target], 'unexpected controller target: ' .. tostring(target))
                if command == '!SetOption' then
                    assert(key == 'Text' or key == 'ToolTipText' or key == 'FontColor' or key == 'X' or key == 'Y' or key == 'W' or key == 'H'
                        or (target == 'MeterIODiskGraphTrack' and key == 'Shape3')
                        or (target == 'MeterIODiskGraph' and (key:match('^Shape%d*$') or key:match('^IOHistoryPath%d+$'))),
                        'unexpected option mutation: ' .. tostring(key))
                    state.options[target] = state.options[target] or {}
                    state.options[target][key] = value
                elseif command == '!ShowMeter' then
                    state.shown[target] = true
                elseif command == '!HideMeter' then
                    state.shown[target] = false
                elseif command == '!UpdateMeter' then
                    assert(target == 'MeterIOBounds' or target == 'MeterIOPanel' or target == 'MeterIOEmpty'
                        or target == 'MeterIODiskGraphTrack' or target == 'MeterIODiskGraph'
                        or target == 'MeterIOGraphPositive' or target == 'MeterIOGraphZero' or target == 'MeterIOGraphNegative'
                        or target:match('^MeterIODrive[A-Z]$') or target:match('^MeterIOCapacity[A-Z]$')
                        or target:match('^MeterIOUsed[A-Z]$') or target:match('^MeterIOLegend[A-Z]$')
                        or target:match('^MeterIODiskRead[A-Z]$') or target:match('^MeterIODiskWrite[A-Z]$')
                        or target:match('^MeterIODiskReadLabel[A-Z]$') or target:match('^MeterIODiskWriteLabel[A-Z]$'),
                        'unexpected forced meter update')
                else
                    error('unsupported bang in mock: ' .. tostring(command))
                end
            end
            state.calls[#state.calls + 1] = { command, target, key, value }
        end
        local function forbidden() error('controller attempted external work in fixture', 2) end
        local blockedLibrary = setmetatable({}, { __index = function() return forbidden end })
        local env
        local function trustedNames(path)
            assert(path == vars['@'] .. 'Modules\\IO\\Names.lua', 'unexpected library load')
            local library = assert(loadfile(namesPath))
            setfenv(library, env)
            return library()
        end
        env = setmetatable({ SKIN = skin, SELF = blockedLibrary, io = blockedLibrary,
            os = setmetatable({time = function() return state.now end}, {__index = function() return forbidden end}),
            require = forbidden, dofile = trustedNames, loadfile = forbidden },
            { __index = _G })
        env._G = env
        local chunk, loadError = loadfile(productionPath)
        assert(chunk, loadError)
        setfenv(chunk, env)
        chunk()
        assert(type(env.Initialize) == 'function' and type(env.Update) == 'function',
            'controller entrypoints missing')
        env.Initialize()
        function state:tick(seconds)
            self.now = self.now + (seconds == nil and 1 or seconds)
            return env.Update()
        end
        function state:namesReady()
            assert(type(env.NamesReady) == 'function', 'model completion entrypoint missing')
            return env.NamesReady()
        end
        function state:applyNamesMode() return env.ApplyNamesMode() end
        function state:refreshNamesInventory() return env.RefreshNamesInventory() end
        function state:refresh()
            self.options, self.shown, self.calls, self.groups, self.variableWrites = {}, {}, {}, {}, {}
            env.Initialize()
            return self:tick()
        end
        function state:traces()
            local traces, opts = {}, self.options.MeterIODiskGraph or {}
            for index = 1, 121 do
                local shape = opts[index == 1 and 'Shape' or ('Shape' .. index)]
                if not shape or shape == '' then break end
                local path = shape:match('^Path (%w+)')
                local points = {}
                local radius
                if path then
                    for x, y in (opts[path] or ''):gmatch('([%d%.%-]+),([%d%.%-]+)') do
                        points[#points + 1] = {x = tonumber(x), y = tonumber(y)}
                    end
                    assert(opts[path]:match('ClosePath 0$'), 'history path must stay open')
                elseif shape:match('^Ellipse ') then
                    local x, y, r = shape:match('^Ellipse ([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
                    points[1] = {x = tonumber(x), y = tonumber(y)}
                    radius = tonumber(r)
                end
                if #points > 0 then
                    traces[#traces + 1] = {points = points, radius = radius,
                        color = shape:match('Stroke Color ([%d,]+)') or shape:match('Fill Color ([%d,]+)'), shape = shape}
                end
            end
            return traces
        end
        function state:text(meter) return (self.options[meter] or {}).Text end
        function state:tip(meter) return (self.options[meter] or {}).ToolTipText end
        state:tick()
        return state
    end

    local function checkInlineCells(f, letter, scale, width, x)
        local read = f.options['MeterIODiskRead' .. letter]
        local write = f.options['MeterIODiskWrite' .. letter]
        local readIcon = f.options['MeterIODiskReadLabel' .. letter]
        local writeIcon = f.options['MeterIODiskWriteLabel' .. letter]
        local capacity = f.options['MeterIOCapacity' .. letter]
        local rateWidth = (width - 8 * scale) * 0.28
        local capacityWidth = (width - 8 * scale) * 0.44
        local function near(actual, expected, message)
            truth(math.abs(tonumber(actual) - expected) < 0.001, message)
        end
        equal(tonumber(f.options['MeterIODrive' .. letter].W), width)
        near(readIcon.X, x)
        near(readIcon.W, 10 * scale)
        near(read.X, x + 11 * scale)
        near(read.W, rateWidth - 11 * scale)
        near(writeIcon.X, x + rateWidth + 4 * scale)
        near(writeIcon.W, 10 * scale)
        near(write.X, x + rateWidth + 15 * scale)
        near(write.W, rateWidth - 11 * scale)
        near(capacity.X, x + width)
        near(capacity.W, capacityWidth)
        near(capacity.Y, tonumber(read.Y), 'capacity and read speed must share one row')
        near(write.Y, tonumber(read.Y), 'write speed must share the same row')
        near(tonumber(writeIcon.X) - tonumber(read.X) - tonumber(read.W), 4 * scale,
            'read/write columns must retain their gap')
        near(tonumber(capacity.X) - tonumber(capacity.W) - tonumber(write.X) - tonumber(write.W), 4 * scale,
            'write/capacity columns must retain their gap')
    end

    test('C: shows decimal free/total and used percentage with body reading color', function()
        local f = fixture({ TextColor = '210,220,230' })
        equal(f:text('MeterIODriveC'), 'C:')
        equal(f:text('MeterIOCapacityC'), '26.8/107.4 GB')
        equal(f.options.MeterIOCapacityC.FontColor, '210,220,230')
        equal(f.shown.MeterIOUsedC, true)
        equal(f:tip('MeterIOUsedC'), '75.0% used')
        equal(f:text('MeterIOTotal'), '75%')
        equal(f:tip('MeterIOTotal'), 'Selected C:; 75.0% used, weighted by total capacity.')
        contains(f:tip('MeterIOCapacityC'), '(free / total)')
        contains(f:tip('MeterIOCapacityC'), '26.8 GB / 107.4 GB')
        local decimal = fixture(nil, { MeasureIOFreeC = 1000000000, MeasureIOTotalC = 2000000000 })
        equal(decimal:text('MeterIOCapacityC'), '1.0/2.0 GB')
        local different = fixture(nil, { MeasureIOFreeC = 26.8e9, MeasureIOTotalC = 1.1e12 })
        equal(different:text('MeterIOCapacityC'), '26.8 GB/1.1 TB', 'different units must remain explicit')
        contains(different:tip('MeterIOCapacityC'), '26.8 GB / 1.1 TB')
    end)

    test('a full drive has valid zero free space rather than an unavailable state', function()
        local f = fixture(nil, { MeasureIOFreeC = 0 })
        equal(f:text('MeterIOCapacityC'), '0.0 B/107.4 GB')
        equal(f:tip('MeterIOUsedC'), '100.0% used')
        equal(f:text('MeterIOTotal'), '100%')
        equal(f.shown.MeterIOUsedC, true)
    end)

    test('a completely free drive remains valid at zero used percentage', function()
        local f = fixture(nil, { MeasureIOFreeC = 100 * GiB })
        equal(f:tip('MeterIOUsedC'), '0.0% used')
        equal(f:text('MeterIOTotal'), '0%')
        equal(f.shown.MeterIOUsedC, true)
    end)

    test('missing and errored drive types suppress otherwise plausible capacity', function()
        for _, kind in ipairs({ 0, 1 }) do
            local f = fixture({ MutedColor = '160,170,180' }, { MeasureIOTypeC = kind })
            equal(f:text('MeterIOCapacityC'), 'Missing / unavailable')
            equal(f.options.MeterIOCapacityC.FontColor, '160,170,180')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsedC, false)
        end
        local missing = fixture()
        missing.values.MeasureIOTypeC = nil
        missing:tick()
        equal(missing:text('MeterIOCapacityC'), 'Missing / unavailable')
        equal(missing:text('MeterIOTotal'), '--')
        equal(missing.shown.MeterIOUsedC, false)
    end)

    test('optical capacity is explicitly unsupported', function()
        local f = fixture(nil, { MeasureIOTypeC = 6 })
        equal(f:text('MeterIOCapacityC'), 'Optical unsupported')
        equal(f:text('MeterIOTotal'), '--')
        equal(f.shown.MeterIOUsedC, false)
    end)

    test('invalid totals and free values never produce a capacity bar', function()
        for _, bad in ipairs({ 0, -1, math.huge, -math.huge, 0/0, '100' }) do
            local f = fixture(nil, { MeasureIOTotalC = bad })
            equal(f:text('MeterIOCapacityC'), 'Unavailable')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsedC, false)
        end
        for _, bad in ipairs({ -1, 101 * GiB, math.huge, -math.huge, 0/0, '25' }) do
            local f = fixture(nil, { MeasureIOFreeC = bad })
            equal(f:text('MeterIOCapacityC'), 'Unavailable')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsedC, false)
        end
        local missing = fixture()
        missing.values.MeasureIOTotalC = nil
        missing:tick()
        equal(missing:text('MeterIOCapacityC'), 'Unavailable')
        equal(missing.shown.MeterIOUsedC, false)
    end)

    test('positive C: read and zero write retain their distinct meanings', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576 })
        equal(f:text('MeterIODiskReadC'), '1MB/s')
        equal(f:text('MeterIODiskWriteC'), '--')
        equal(f.shown.MeterIODiskGraph, true)
        equal(#f:traces(), 2)
        equal(f:traces()[1].color, '10,20,30')
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-1.20586 MB/s')
        contains(f:tip('MeterIODiskGraph'), 'cap 524.288 MB/s')
        contains(f:tip('MeterIODiskReadC'), 'sample freshness is unknown')
        contains(f:tip('MeterIODiskWriteC'), 'idle, missing counter, unavailable provider, or initial sample')
        equal(f:text('MeterIOCapacityC'), '26.8/107.4 GB')
        equal(f:traces()[2].points[1].y, 60, 'a current zero write plots at baseline')
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 1000, 1000000
        f:tick()
        equal(f:text('MeterIODiskReadC'), '1KB/s')
        equal(f:text('MeterIODiskWriteC'), '1MB/s')
        contains(f:tip('MeterIODiskReadC'), '1.0 KB/s')
        contains(f:tip('MeterIODiskWriteC'), '1.0 MB/s')
    end)

    test('bits use decimal rate units while capacity stays in decimal bytes', function()
        local f = fixture({ IODiskUnits = 'BITS' },
            { MeasureIODiskReadC = 125000, MeasureIODiskWriteC = 125 })
        equal(f:text('MeterIODiskReadC'), '1Mbit/s')
        equal(f:text('MeterIODiskWriteC'), '1kbit/s')
        contains(f:tip('MeterIODiskReadC'), '1.0 Mbit/s')
        equal(f:text('MeterIOCapacityC'), '26.8/107.4 GB')
    end)

    test('negative nonfinite malformed and absent readings keep unknown text but plot current zero', function()
        for _, bad in ipairs({ -1, math.huge, -math.huge, 0/0, '42', false }) do
            local f = fixture(nil, { MeasureIODiskReadC = bad, MeasureIODiskWriteC = bad })
            equal(f:text('MeterIODiskReadC'), '--')
            equal(f:text('MeterIODiskWriteC'), '--')
            equal(f.shown.MeterIODiskGraph, true)
            equal(#f:traces(), 2)
            equal(f:traces()[1].points[1].y, 60)
            equal(f:traces()[2].points[1].y, 60)
        end
        local f = fixture(nil, nil)
        f.values.MeasureIODiskReadC = nil
        f.values.MeasureIODiskWriteC = nil
        f:tick()
        equal(f:text('MeterIODiskReadC'), '--')
        equal(f:text('MeterIODiskWriteC'), '--')
        equal(f.shown.MeterIODiskGraph, true)
        equal(f:traces()[1].points[2].y, 60)
        equal(f:traces()[2].points[2].y, 60)
        contains(f:tip('MeterIODiskGraph'), 'zero can mean idle or unavailable')
    end)

    test('returning to zero draws the baseline and ages earlier positive observations out', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1024, MeasureIODiskWriteC = 2048 })
        equal(#f:traces(), 2)
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 0, 0
        f:tick()
        equal(f:text('MeterIODiskReadC'), '--')
        equal(f:text('MeterIODiskWriteC'), '--')
        equal(f.shown.MeterIODiskGraph, true)
        equal(#f:traces(), 2)
        equal(f:traces()[1].points[2].y, 60)
        equal(f:traces()[2].points[2].y, 60)
        for _ = 1, 59 do f:tick() end
        equal(f.shown.MeterIODiskGraph, true)
        equal(#f:traces(), 2)
        for _, trace in ipairs(f:traces()) do
            equal(#trace.points, 60)
            equal(trace.points[1].y, 60)
            equal(trace.points[60].y, 60)
        end
        contains(f:tip('MeterIODiskGraphTrack'), 'unchanged reports may be stale')
    end)

    test('invalid graph ceilings hide history without hiding valid rate text', function()
        for _, limit in ipairs({ '0', '-1', 'bad', '1e309' }) do
            local f = fixture({ IODiskMaxMiBs = limit }, { MeasureIODiskReadC = 1024 })
            equal(f:text('MeterIODiskReadC'), '1KB/s')
            equal(f.shown.MeterIODiskGraph, false)
            contains(f:tip('MeterIODiskGraphTrack'), 'Check graph limit')
            equal(#f:traces(), 0)
        end
    end)

    test('unsupported display units are visible rather than silently reinterpreted', function()
        local f = fixture({ IODiskUnits = 'invalid' }, { MeasureIODiskReadC = 1024 })
        equal(f:text('MeterIODiskReadC'), 'Check IO units')
    end)

    test('capacity cadence tooltip rounds upward and respects the five-second minimum', function()
        local slow = fixture({ CapacityInterval = '30500' })
        contains(slow:tip('MeterIOCapacityHeading'), 'every 31 seconds')
        local fast = fixture({ CapacityInterval = '1000' })
        contains(fast:tip('MeterIOCapacityHeading'), 'every 5 seconds')
    end)

    test('unchanged readings still scroll while non-history options remain cached', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1024 })
        local before = #f.calls
        equal(f:tick(), 0)
        truth(#f.calls > before, 'a new observation should extend history')
        for index = before + 1, #f.calls do
            truth(f.calls[index][2] == 'MeterIODiskGraph', 'unchanged non-history option was rewritten')
        end
        equal(#f:traces()[1].points, 2)
    end)

    test('history starts with only right-aligned current dots and no invented earlier values', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576 })
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 1)
        equal(traces[1].points[1].x, 206)
        equal(traces[1].radius, 1)
        contains(f:tip('MeterIODiskGraph'), '60 nominal one-second slots, newest at right')
        contains(f:tip('MeterIODiskGraph'), 'Provider sample freshness is unknown')
        f:tick()
        traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 2)
        truth(traces[1].points[1].x < 206)
        equal(traces[1].points[2].x, 206)
    end)

    test('history retains at most sixty observations and autoscale forgets an expired peak', function()
        local f = fixture(nil, { MeasureIODiskReadC = 8 * 1048576 })
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-9.6469 MB/s')
        f.values.MeasureIODiskReadC = 1048576
        for _ = 1, 60 do f:tick() end
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 60)
        equal(traces[1].points[1].x, 2)
        equal(traces[1].points[60].x, 206)
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-1.20586 MB/s')
        for _, point in ipairs(traces[1].points) do
            equal(point.y, traces[1].points[1].y, 'old peak survived the sixty-slot window')
        end
    end)

    test('read and write form independent continuous traces through current zero readings', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576, MeasureIODiskWriteC = 2097152 })
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 2097152, 0
        f:tick()
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 0, 3145728
        f:tick()
        local traces = f:traces()
        equal(#traces, 2)
        equal(traces[1].color, '10,20,30')
        equal(traces[2].color, '40,50,60')
        equal(#traces[1].points, 3)
        equal(#traces[2].points, 3)
        equal(traces[1].points[3].y, 60, 'current read zero must reach baseline')
        equal(traces[2].points[2].y, 60, 'current write zero must reach baseline')
        truth(traces[1].points[1].y > traces[2].points[1].y, 'direction values were mixed')
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 4194304, 4194304
        f:tick()
        traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 4)
        equal(#traces[2].points, 4)
        for _, trace in ipairs(traces) do
            for index = 2, #trace.points do
                truth(trace.points[index].x > trace.points[index - 1].x,
                    'observation positions must stay in chronological order')
            end
        end
    end)

    test('missed slots preserve positions and interpolate while backward clocks restart history', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576 })
        f.values.MeasureIODiskReadC = 2097152
        f:tick(3)
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 2)
        equal(#traces[2].points, 2)
        truth(traces[1].points[2].x - traces[1].points[1].x > 10,
            'missed update positions must not collapse to adjacent slots')
        truth(traces[1].points[1].y > traces[1].points[2].y,
            'the interpolated segment must use both observed values')
        contains(traces[1].shape, 'Path IOHistoryPath')
        contains(f:tip('MeterIODiskGraph'), 'straight-line interpolation across missed intervals')
        f:tick(-5)
        equal(#f:traces(), 2)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
        f:tick(120)
        equal(#f:traces(), 2)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
    end)

    test('autoscale minimum and hard ceiling remain explicit and bound positive traces', function()
        local low = fixture(nil, { MeasureIODiskReadC = 1 })
        contains(low:tip('MeterIODiskGraph'), 'Displayed range: 0-0.065536 MB/s')
        local capped = fixture({ IODiskMaxMiBs = '10' }, { MeasureIODiskReadC = 100 * 1048576 })
        contains(capped:tip('MeterIODiskGraph'), 'Displayed range: 0-10.4858 MB/s; autoscaled, cap 10.4858 MB/s')
        equal(capped:traces()[1].points[1].y, 2)
        equal(capped:text('MeterIODiskReadC'), '104.9MB/s', 'graph cap must not alter the reported rate')
        contains(capped:tip('MeterIODiskReadC'), '104.9 MB/s')
        local smallCap = fixture({ IODiskMaxMiBs = '0.001' }, { MeasureIODiskReadC = 1048576 })
        contains(smallCap:tip('MeterIODiskGraph'), 'Displayed range: 0-0.00104858 MB/s')
        equal(smallCap:traces()[1].points[1].y, 2)
    end)

    test('refresh clears earlier positive observations before showing the new sample', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576 })
        for _ = 1, 5 do f:tick() end
        equal(#f:traces()[1].points, 6)
        f:refresh()
        equal(#f:traces(), 2)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
        f.values.MeasureIODiskReadC = 0
        f:refresh()
        equal(f.shown.MeterIODiskGraph, true)
        equal(#f:traces(), 2)
        equal(f:traces()[1].points[1].y, 60)
        equal(#f:traces()[1].points, 1)
    end)

    test('trace paths and dots stay inside narrow and standard graph bounds at supported scales', function()
        for _, columnWidth in ipairs({ 180, 220 }) do
            for _, scale in ipairs({ 0.75, 1, 2 }) do
                local width = math.floor((columnWidth - 12) * scale)
                local height = math.floor(62 * scale)
                local f = fixture({ ContentWidth = '((' .. columnWidth .. '-12)*' .. scale .. ')',
                    Scale = tostring(scale), IODiskMaxMiBs = '10' },
                    { MeasureIODiskReadC = 100 * 1048576, MeasureIODiskWriteC = 1 })
                local function checkBounds()
                    equal(#f:traces(), 2)
                    for _, trace in ipairs(f:traces()) do
                        local margin = trace.radius or math.max(1, scale) / 2
                        for _, point in ipairs(trace.points) do
                            truth(point.x - margin >= 0 and point.x + margin <= width, 'trace exceeds graph width')
                            truth(point.y - margin >= 0 and point.y + margin <= height, 'trace exceeds graph height')
                        end
                    end
                end
                checkBounds()
                f:tick()
                f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 0, 0
                f:tick()
                f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 100 * 1048576, 1
                f:tick(3)
                checkBounds()
            end
        end
    end)

    test('default selection activates only the C banks and stable membership does not requery groups', function()
        local f = fixture()
        equal(f.groups.IOCapacityC, true)
        equal(f.groups.IORatesC, true)
        local groupCalls = 0
        for _, call in ipairs(f.calls) do
            if call[1]:find('MeasureGroup', 1, true) then groupCalls = groupCalls + 1 end
        end
        equal(groupCalls, 4, 'one enable and force-update per newly active bank')
        for code = 65, 90 do
            local letter = string.char(code)
            if letter ~= 'C' then
                truth(not f.groups['IOCapacity' .. letter])
                truth(not f.groups['IORates' .. letter])
                equal(f.shown['MeterIODrive' .. letter], false)
                equal(tonumber(f.options['MeterIODrive' .. letter].Y), 0)
            end
        end
        local before = #f.calls
        f:tick()
        for index = before + 1, #f.calls do
            truth(not f.calls[index][1]:find('MeasureGroup', 1, true), 'stable membership forced another bank update')
        end
    end)

    test('malformed or noncanonical drive lists fall back to C without persisting a replacement', function()
        for _, bad in ipairs({'', 'c', 'C:', 'C,D,', ',C', 'C,,D', 'C,C', 'D,C', 'C D', ' C', 'ALL', '[!Quit]', 'C\nD'}) do
            local f = fixture({ IODiskDrives = bad }, { MeasureIOTypeD = 4 })
            equal(f.vars.IODiskDrives, bad)
            equal(f.shown.MeterIODriveC, true)
            equal(f.shown.MeterIODriveD, false)
            truth(not f.groups.IORatesD)
            contains(f:tip('MeterIOTotal'), 'Invalid drive selection; using C:')
        end
    end)

    test('canonical selected rows put C first then alphabetical letters with compact positions', function()
        local f = fixture({ IODiskDrives = 'A,C,Z' }, {
            MeasureIOTypeA = 3, MeasureIOTotalA = 1e9, MeasureIOFreeA = 5e8,
            MeasureIOTypeZ = 7, MeasureIOTotalZ = 2e9, MeasureIOFreeZ = 1e9 })
        equal(tonumber(f.options.MeterIODriveC.Y), 46)
        equal(tonumber(f.options.MeterIODriveA.Y), 96)
        equal(tonumber(f.options.MeterIODriveZ.Y), 146)
        equal(tonumber(f.options.MeterIOUsedZ.Y), 164)
        equal(tonumber(f.options.MeterIODiskReadZ.Y), 172)
        equal(tonumber(f.options.MeterIODiskWriteLabelZ.Y), 174)
        equal(tonumber(f.options.MeterIOCapacityZ.Y), 172)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 193)
        equal(tonumber(f.vars.PanelHeightPx), 257)
        equal(tonumber(f.options.MeterIOBounds.H), 265)
        equal(f.shown.MeterIOEmpty, false)
        equal(f.vars.IODiskDrives, 'A,C,Z', 'display order must not rewrite canonical storage')
    end)

    test('all mode discovers present inventory types and keeps optical capacity explicitly unsupported', function()
        local f = fixture({ IODiskDrives = 'all' }, {
            MeasureIOTypeA = 3, MeasureIOTypeB = 5, MeasureIOTypeD = 6, MeasureIOTypeE = 7, MeasureIOTypeF = 2 })
        for _, letter in ipairs({'C', 'A', 'B', 'D', 'E'}) do equal(f.shown['MeterIODrive' .. letter], true) end
        equal(f.shown.MeterIODriveF, false)
        equal(f:text('MeterIOCapacityD'), 'Optical unsupported')
        truth(not f.groups.IOCapacityD)
        equal(f.groups.IORatesD, true)
        equal(f:text('MeterIOTotal'), '--')
        equal(tonumber(f.options.MeterIODriveE.Y), 246)
    end)

    test('an explicit disconnected selection remains an unavailable row and reconnect enables its banks once', function()
        local f = fixture({ IODiskDrives = 'C,D' }, {
            MeasureIOTypeD = 4, MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8, MeasureIODiskReadD = 1e6 })
        f.values.MeasureIOTypeD = 2
        f:tick()
        equal(f.shown.MeterIODriveD, true)
        equal(f:text('MeterIOCapacityD'), 'Missing / unavailable')
        equal(f:text('MeterIODiskReadD'), '--', 'a retained bank value must not appear after disconnect')
        equal(f.groups.IOCapacityD, false)
        equal(f.groups.IORatesD, false)
        equal(f:text('MeterIOTotal'), '--')
        equal(#f:traces()[1].points, 2, 'unchanged selected letters keep the same history scope')
        f.values.MeasureIOTypeD = 4
        local before = #f.calls
        f:tick()
        equal(f.groups.IOCapacityD, true)
        equal(f.groups.IORatesD, true)
        local updates = 0
        for index = before + 1, #f.calls do
            if f.calls[index][1] == '!UpdateMeasureGroup' then updates = updates + 1 end
        end
        equal(updates, 2)
        equal(f:text('MeterIODiskReadD'), '1MB/s')
    end)

    test('all-mode hotplug resets combined scope and hides removed rows at Y zero', function()
        local f = fixture({ IODiskDrives = 'all' }, {
            MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8, MeasureIODiskReadD = 1e6 })
        f:tick()
        equal(#f:traces()[1].points, 2)
        f.values.MeasureIOTypeD = 4
        f:tick()
        equal(f.shown.MeterIODriveD, true)
        equal(#f:traces()[1].points, 1, 'adding a selected volume must clear old combined history')
        f.values.MeasureIOTypeC = 2
        f:tick()
        equal(f.shown.MeterIODriveC, false)
        equal(tonumber(f.options.MeterIODriveC.Y), 0)
        equal(tonumber(f.options.MeterIOUsedC.Y), 0)
        equal(tonumber(f.options.MeterIODiskReadLabelC.Y), 0)
        equal(tonumber(f.options.MeterIODriveD.Y), 46)
        equal(f.groups.IORatesC, false)
        equal(#f:traces()[1].points, 1)
        f.values.MeasureIOTypeD = 2
        f:tick()
        equal(f.shown.MeterIOEmpty, true)
        equal(f:text('MeterIOEmpty'), 'No drives found')
        equal(f:text('MeterIOTotal'), '--')
        equal(#f:traces(), 0)
    end)

    test('header percentage is capacity-weighted and unavailable when any selected capacity is invalid', function()
        local f = fixture({ IODiskDrives = 'C,D' }, {
            MeasureIOTotalC = 100e9, MeasureIOFreeC = 25e9,
            MeasureIOTypeD = 4, MeasureIOTotalD = 300e9, MeasureIOFreeD = 225e9 })
        equal(f:text('MeterIOTotal'), '38%')
        contains(f:tip('MeterIOTotal'), '37.5% used, weighted by total capacity')
        contains(f:tip('MeterIOTotal'), 'Selected C:, D:')
        equal(f:tip('MeterIOUsedC'), '75.0% used')
        equal(f:tip('MeterIOUsedD'), '25.0% used')
        f.values.MeasureIOTotalD = 0
        f:tick()
        equal(f:text('MeterIOTotal'), '--')
        equal(f.shown.MeterIOUsedC, true)
        equal(f.shown.MeterIOUsedD, false)
    end)

    test('combined graph sums only selected positive rates and changing membership resets the sum history', function()
        local f = fixture({ IODiskDrives = 'C,D' }, {
            MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 2e6,
            MeasureIOTypeD = 4, MeasureIODiskReadD = 3e6, MeasureIODiskWriteD = 4e6,
            MeasureIOTypeE = 4, MeasureIODiskReadE = 100e6 })
        equal(f:text('MeterIODiskReadC'), '1MB/s')
        equal(f:text('MeterIODiskReadD'), '3MB/s')
        truth(not f.groups.IORatesE)
        contains(f:tip('MeterIODiskGraph'), 'Combined selected drives: C:, D:')
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-6.9 MB/s')
        equal(f:traces()[1].points[1].y, 26.377)
        f.values.MeasureIODiskReadD = nil
        f:tick()
        equal(f:text('MeterIODiskReadD'), '--')
        equal(f:traces()[1].points[2].y, 51.594)
        f.vars.IODiskDrives = 'D'
        f:tick()
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
        equal(f.groups.IORatesC, false)
        equal(f.shown.MeterIODriveC, false)
    end)

    test('none adds no observations and changing layout does not append extra history or rewrite preferences', function()
        local empty = fixture({ IODiskDrives = 'none' })
        equal(empty.shown.MeterIOEmpty, true)
        equal(empty:text('MeterIOTotal'), '--')
        equal(#empty:traces(), 0)
        truth(not empty.groups.IORatesC)
        empty:tick(10)
        equal(#empty:traces(), 0)
        empty.vars.IODiskDrives = 'C'
        empty:tick()
        equal(#empty:traces()[1].points, 1)
        empty.vars.DataBarThickness = '12'
        empty.vars.PanelHeight = '300'
        local before = #empty.calls
        empty:tick()
        equal(#empty:traces()[1].points, 2)
        equal(tonumber(empty.options.MeterIODiskReadC.Y), 78)
        equal(tonumber(empty.options.MeterIODiskGraph.Y), 99)
        equal(tonumber(empty.vars.PanelHeightPx), 300)
        equal(empty.vars.PanelHeight, '300')
        equal(empty.vars.DataBarThickness, '12')
        for index = before + 1, #empty.calls do
            truth(not empty.calls[index][1]:find('MeasureGroup', 1, true), 'layout-only change forced a bank update')
        end
        empty.vars.Gap = '12'
        empty:tick()
        equal(tonumber(empty.options.MeterIOBounds.H), 312, 'gap change must resize bounds with unchanged panel height')
    end)

    test('C graph mode activates C rates independently of selected capacity rows', function()
        local f = fixture({ IODiskDrives = 'D', IOGraphMode = 'c' }, {
            MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 2e6,
            MeasureIOTypeD = 4, MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8,
            MeasureIODiskReadD = 30e6, MeasureIODiskWriteD = 40e6 })
        equal(f.groups.IORatesC, true)
        truth(not f.groups.IOCapacityC)
        equal(f.shown.MeterIODriveC, false)
        equal(f.shown.MeterIODriveD, true)
        equal(f:text('MeterIOTotal'), '50%')
        contains(f:tip('MeterIODiskGraph'), 'C: only')
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-2.3 MB/s')
        f:tick()
        f.vars.IOGraphMode = 'combined'
        f:tick()
        equal(f.groups.IORatesC, false)
        equal(#f:traces()[1].points, 1)
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-46 MB/s')
        f.vars.IODiskDrives, f.vars.IOGraphMode = 'none', 'c'
        f:tick()
        equal(f.shown.MeterIOEmpty, true)
        equal(f:text('MeterIOTotal'), '--')
        equal(f.groups.IORatesC, true)
        equal(#f:traces()[1].points, 1)
        f.values.MeasureIOTypeC = 2
        f:tick()
        equal(f.groups.IORatesC, false)
        equal(f:traces()[1].points[2].y, 60)
    end)

    test('overlay uses stable drive colors with solid read dashed write and resets on mode changes', function()
        local f = fixture({ IODiskDrives = 'C,D', IOGraphMode = 'overlay' }, {
            MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 2e6,
            MeasureIOTypeD = 4, MeasureIODiskReadD = 3e6, MeasureIODiskWriteD = 4e6 })
        f:tick()
        local traces = f:traces()
        equal(#traces, 4)
        equal(traces[1].color, traces[2].color)
        equal(traces[3].color, traces[4].color)
        truth(traces[1].color ~= traces[3].color)
        equal(f.options.MeterIOLegendC.FontColor, traces[1].color)
        equal(f.options.MeterIOLegendD.FontColor, traces[3].color)
        truth(not traces[1].shape:find('StrokeDashes', 1, true))
        contains(traces[2].shape, 'StrokeDashes 4,3')
        contains(traces[4].shape, 'StrokeDashes 4,3')
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: 0-4.6 MB/s')
        equal(f.shown.MeterIOLegendC, true)
        equal(tonumber(f.options.MeterIOLegendC.Y), 143)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 161)
        equal(tonumber(f.vars.PanelHeightPx), 225)
        local dColor = traces[3].color
        f.vars.IODiskDrives = 'D'
        f:tick()
        equal(#f:traces(), 2)
        equal(f:traces()[1].color, dColor, 'palette color changed when order changed')
        equal(f.shown.MeterIOLegendC, false)
        equal(tonumber(f.options.MeterIOLegendC.Y), 0)
        f.vars.IOGraphMode = 'combined'
        f:tick()
        equal(f.shown.MeterIOLegendD, false)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 93)
        equal(tonumber(f.vars.PanelHeightPx), 157)
        equal(#f:traces()[1].points, 1)
    end)

    test('split sums selected drives with read above write below and a shared symmetric scale', function()
        local f = fixture({ IODiskDrives = 'C,D', IOGraphMode = 'split' }, {
            MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 1e6,
            MeasureIOTypeD = 4, MeasureIODiskReadD = 3e6, MeasureIODiskWriteD = 3e6,
            MeasureIOTypeE = 4, MeasureIODiskReadE = 100e6, MeasureIODiskWriteE = 100e6 })
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 1, 'split must not prefill earlier observations')
        equal(traces[1].points[1].x, 206)
        equal(traces[1].points[1].y, 5.783)
        equal(traces[2].points[1].y, 56.217)
        equal(traces[1].points[1].y + traces[2].points[1].y, 62,
            'equal magnitudes must be equally distant from the center')
        equal(traces[1].color, '10,20,30')
        equal(traces[2].color, '40,50,60')
        equal(f:text('MeterIODiskReadC'), '1MB/s')
        equal(f:text('MeterIODiskWriteD'), '3MB/s', 'display signs must not change positive speed text')
        truth(not f.groups.IORatesE, 'split must not sample unselected drives')
        equal(f.shown.MeterIOLegendC, false)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 143)
        equal(tonumber(f.vars.PanelHeightPx), 207)
        contains(f:tip('MeterIODiskGraph'), 'Split + / -; combined selected drives: C:, D:')
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: -4.6 to +4.6 MB/s')
        contains(f:tip('MeterIODiskGraph'), 'Read is positive above zero; write is negative below zero')
        contains(f:tip('MeterIODiskGraph'), 'Signs are a display convention; physical transfer rates remain nonnegative')
        f.values.MeasureIODiskWriteD = 1e6
        f:tick()
        traces = f:traces()
        equal(traces[1].points[2].y, 5.783)
        equal(traces[2].points[2].y, 43.609, 'write must share the read peak scale rather than scaling independently')
        truth(not traces[2].shape:find('StrokeDashes', 1, true), 'split retains the shared direction styles')
        local before = #f.calls
        f:tick()
        equal(#f:traces()[1].points, 3)
        for index = before + 1, #f.calls do
            equal(f.calls[index][2], 'MeterIODiskGraph', 'stable split annotations must remain cached')
        end
    end)

    test('split current nulls meet at zero and missed slots retain linear connections and bounded history', function()
        local f = fixture({ IOGraphMode = 'split' }, {
            MeasureIODiskReadC = 2e6, MeasureIODiskWriteC = 4e6 })
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = nil, -3
        f:tick(3)
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 2)
        equal(#traces[2].points, 2)
        equal(traces[1].points[2].y, 31)
        equal(traces[2].points[2].y, 31)
        truth(traces[1].points[1].y < 31 and traces[2].points[1].y > 31)
        truth(traces[1].points[2].x - traces[1].points[1].x > 10,
            'missed observations must preserve their time positions')
        contains(traces[1].shape, 'Path IOHistoryPath')
        equal(f:text('MeterIODiskReadC'), '--')
        equal(f:text('MeterIODiskWriteC'), '--')
        contains(f:tip('MeterIODiskGraph'), 'Current unavailable or nonpositive readings plot as zero')
        contains(f:tip('MeterIODiskGraph'), 'straight-line interpolation across missed intervals')
        contains(f:tip('MeterIODiskGraph'), 'Provider sample freshness is unknown')
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = math.huge, 0
        for _ = 1, 60 do f:tick() end
        for _, trace in ipairs(f:traces()) do
            equal(#trace.points, 60)
            equal(trace.points[1].x, 2)
            equal(trace.points[60].x, 206)
            for _, point in ipairs(trace.points) do equal(point.y, 31, 'expired peaks must leave the zero baseline') end
        end
        contains(f:tip('MeterIODiskGraph'), 'Displayed range: -0.065536 to +0.065536 MB/s')
        f:tick(-5)
        equal(#f:traces()[1].points, 1, 'clock rollback must reset split history')
        equal(f:traces()[1].points[1].y, 31)
    end)

    test('split caps both directions and keeps traces and axis markers inside the declared frame', function()
        for _, scale in ipairs({0.75, 1, 2}) do
            local width, height = 168 * scale, 62 * scale
            local f = fixture({ IOGraphMode = 'split', Scale = tostring(scale), ContentWidth = tostring(width),
                Inset = tostring(4 * scale), ContentX = tostring(10 * scale), IODiskMaxMiBs = '10' },
                { MeasureIODiskReadC = 100 * 1048576, MeasureIODiskWriteC = 200 * 1048576 })
            local inset, graphY = math.max(2, 2 * scale), tonumber(f.options.MeterIODiskGraph.Y)
            contains(f:tip('MeterIODiskGraph'), 'Displayed range: -10.4858 to +10.4858 MB/s; symmetric autoscale, cap 10.4858 MB/s per direction')
            equal(f:text('MeterIODiskReadC'), '104.9MB/s', 'the split cap must not clip rate text')
            equal(f:traces()[1].points[1].y, inset)
            equal(f:traces()[2].points[1].y, height - inset)
            contains(f.options.MeterIODiskGraphTrack.Shape3, 'Stroke Color #MutedColor#')
            contains(f.options.MeterIODiskGraphTrack.Shape3, '(#IOGraphHeight#*#Scale#/2)')
            for index, suffix in ipairs({'Positive', 'Zero', 'Negative'}) do
                local meter = 'MeterIOGraph' .. suffix
                local options = f.options[meter]
                equal(f.shown[meter], true)
                equal(f:text(meter), ({'+', '0', '-'})[index])
                equal(tonumber(options.X), 10 * scale + width - 2 * scale)
                equal(tonumber(options.Y), graphY + (index - 1) * 24 * scale)
                equal(tonumber(options.W), 12 * scale)
                equal(tonumber(options.H), 14 * scale)
                truth(tonumber(options.Y) >= graphY and tonumber(options.Y) + tonumber(options.H) <= graphY + height,
                    'axis labels must remain within the declared graph height')
                truth(tonumber(options.X) - tonumber(options.W) >= 10 * scale
                    and tonumber(options.X) <= 10 * scale + width, 'axis label exceeds graph width')
            end
            equal(tonumber(f.options.MeterIOGraphZero.Y) + 7 * scale, graphY + height / 2)
            local function checkBounds()
                for _, trace in ipairs(f:traces()) do
                    local margin = trace.radius or math.max(1, scale) / 2
                    for _, point in ipairs(trace.points) do
                        truth(point.x - margin >= 0 and point.x + margin <= width)
                        truth(point.y - margin >= 0 and point.y + margin <= height)
                    end
                end
            end
            checkBounds()
            f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 0, 0
            f:tick()
            equal(f:traces()[1].points[2].y, height / 2, 'zero trace and frame midpoint must coincide at fractional scale')
            equal(f:traces()[2].points[2].y, height / 2)
            checkBounds()
        end
        local small = fixture({ IOGraphMode = 'split', IODiskMaxMiBs = '0.001' },
            { MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 1e6 })
        contains(small:tip('MeterIODiskGraph'), 'Displayed range: -0.00104858 to +0.00104858 MB/s')
        equal(small:traces()[1].points[1].y, 2)
        equal(small:traces()[2].points[1].y, 60)
        small.vars.IODiskMaxMiBs = 'invalid'
        small:tick()
        equal(#small:traces(), 0)
        equal(small.shown.MeterIODiskGraph, false)
        equal(small:text('MeterIODiskReadC'), '1MB/s')
        contains(small:tip('MeterIODiskGraph'), 'Check graph limit. Traces hidden.')
    end)

    test('split mode transitions reset history while metadata reflow preserves observations and empty scope stays blank', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1e6 })
        f:tick()
        equal(#f:traces()[1].points, 2)
        f.vars.IOGraphMode = 'split'
        f:tick()
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[2].points[1].y, 31)
        f.vars.DataBarThickness = '12'
        local before = #f.calls
        f:applyNamesMode()
        equal(#f:traces()[1].points, 1, 'cached split reflow must not add an observation')
        equal(tonumber(f.options.MeterIOGraphZero.Y), 123)
        local updated, redraw = {}, false
        for index = before + 1, #f.calls do
            local call = f.calls[index]
            if call[1] == '!UpdateMeter' then updated[call[2]] = true end
            if call[1] == '!Redraw' then redraw = true end
        end
        for _, suffix in ipairs({'Positive', 'Zero', 'Negative'}) do
            truth(updated['MeterIOGraph' .. suffix], 'cached reflow must update each axis marker')
        end
        truth(updated.MeterIODiskGraphTrack and updated.MeterIODiskGraph and redraw)
        f.vars.IOGraphMode = 'combined'
        f:tick()
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[2].points[1].y, 60, 'combined must retain its bottom zero baseline')
        contains(f.options.MeterIODiskGraphTrack.Shape3, 'Stroke Color #GridColor#')
        for _, suffix in ipairs({'Positive', 'Zero', 'Negative'}) do
            equal(f.shown['MeterIOGraph' .. suffix], false)
            equal(tonumber(f.options['MeterIOGraph' .. suffix].Y), 0)
        end
        f.vars.IOGraphMode, f.vars.IODiskDrives = 'split', 'none'
        f:tick()
        equal(#f:traces(), 0)
        equal(f.shown.MeterIODiskGraph, false)
        equal(f.shown.MeterIOEmpty, true)
        equal(f.shown.MeterIOGraphZero, true, 'empty split retains its frame reference')
        equal(tonumber(f.options.MeterIODiskGraph.Y), 93)
        equal(tonumber(f.vars.PanelHeightPx), 157)
        equal(f.groups.IORatesC, false)
        contains(f:tip('MeterIODiskGraph'), 'combined selected drives: none')
        f:tick(10)
        equal(#f:traces(), 0)
        f.vars.IODiskDrives = 'C'
        f:tick()
        equal(#f:traces()[1].points, 1, 'restored selection starts with only the current observation')
        f:refresh()
        equal(#f:traces()[1].points, 1, 'refresh must reset split observations')
    end)

    test('unsupported graph modes fall back to combined without a preference write', function()
        local f = fixture({ IOGraphMode = '[!Quit]' }, { MeasureIODiskReadC = 1e6 })
        equal(f.vars.IOGraphMode, '[!Quit]')
        contains(f:tip('MeterIODiskGraph'), 'Combined selected drives: C:')
        equal(f.shown.MeterIOLegendC, false)
    end)

    test('all twenty-six runtime rows and overlay legends fit reflowed graph and panel endpoints', function()
        local samples = {}
        for code = 65, 90 do
            local letter = string.char(code)
            samples['MeasureIOType' .. letter] = 4
            samples['MeasureIOTotal' .. letter], samples['MeasureIOFree' .. letter] = 1e9, 5e8
            samples['MeasureIODiskRead' .. letter], samples['MeasureIODiskWrite' .. letter] = 1e6, 2e6
        end
        for _, columnWidth in ipairs({180, 220}) do
            for _, scale in ipairs({0.75, 1, 2}) do
                for _, thickness in ipairs({1, 6, 6.01, 8.5, 12}) do
                    for _, mode in ipairs({'combined', 'overlay'}) do
                        local inset = math.floor(4 * scale + 0.5)
                        local width = (columnWidth - 12) * scale
                        local bar = math.max(1, math.floor(thickness * scale + 0.5))
                        local extra = math.max(0, bar / scale - 6)
                        local pitch = 50 + extra
                        local legendColumns = math.max(1, math.floor(width / (26 * scale)))
                        local legendRows = mode == 'overlay' and math.ceil(26 / legendColumns) or 0
                        local f = fixture({ IODiskDrives = 'all', IOGraphMode = mode, Scale = tostring(scale),
                            Inset = tostring(inset), Gap = tostring(2 * inset), ContentX = tostring(inset + 6 * scale),
                            ContentWidth = tostring(width), DataBarThicknessPx = tostring(bar) }, samples)
                        local expectedGraph = inset + (89 + extra + 25 * pitch + legendRows * 18) * scale
                        local expectedHeight = math.floor((157 + extra + 25 * pitch + legendRows * 18) * scale + 0.5)
                        truth(math.abs(tonumber(f.options.MeterIODiskGraph.Y) - expectedGraph) < 0.001)
                        equal(tonumber(f.vars.PanelHeightPx), expectedHeight)
                        equal(tonumber(f.options.MeterIOBounds.H), expectedHeight + 2 * inset)
                        equal(#f:traces(), mode == 'overlay' and 52 or 2)
                        truth(expectedGraph + 62 * scale <= inset + expectedHeight, 'graph extends past the panel')
                        for code = 65, 90 do
                            local letter = string.char(code)
                            local index = letter == 'C' and 0 or (code < 67 and code - 64 or code - 65)
                            equal(f.shown['MeterIODrive' .. letter], true)
                            equal(f.shown['MeterIOUsed' .. letter], true)
                            local rowY = inset + (42 + index * pitch) * scale
                            local barY = inset + (60 + index * pitch) * scale + math.max(0, (6 * scale - bar) / 2)
                            local rateY = inset + (68 + extra + index * pitch) * scale
                            truth(math.abs(tonumber(f.options['MeterIODrive' .. letter].Y) - rowY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIOCapacity' .. letter].Y) - rateY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIOUsed' .. letter].Y) - barY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIODiskRead' .. letter].Y) - rateY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIODiskWriteLabel' .. letter].Y) - rateY - 2 * scale) < 0.001)
                            truth(rateY >= barY + bar, 'read/write speeds overlap the bar')
                            checkInlineCells(f, letter, scale, width, inset + 6 * scale)
                            equal(f.shown['MeterIOLegend' .. letter], mode == 'overlay')
                            if mode == 'overlay' then
                                local legend = f.options['MeterIOLegend' .. letter]
                                truth(tonumber(legend.X) + 26 * scale <= inset + 6 * scale + width + 0.001)
                                truth(tonumber(legend.Y) + 18 * scale <= expectedGraph + 0.001)
                            end
                        end
                    end
                end
            end
        end
    end)

    test('drive names stay above bars with speeds and capacity on one shared row in every name mode', function()
        local f = fixture({ IODriveNames = 'volume', IODiskDrives = 'C,D' }, {
            MeasureIONameC = 'System', MeasureIONameD = 'Archive', MeasureIOTypeD = 4,
            MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8, MeasureIODiskReadC = 1e6 })
        equal(f:text('MeterIODriveC'), 'C: System')
        equal(f:text('MeterIODriveD'), 'D: Archive')
        contains(f:tip('MeterIODriveC'), 'C: ')
        contains(f:tip('MeterIODriveC'), 'System')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(tonumber(f.options.MeterIOCapacityC.W), 88)
        equal(tonumber(f.options.MeterIODriveC.Y), 46)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 72)
        equal(tonumber(f.options.MeterIOUsedC.Y), 64)
        equal(tonumber(f.options.MeterIODiskReadC.Y), 72)
        equal(tonumber(f.options.MeterIODriveD.Y), 96)
        equal(tonumber(f.options.MeterIOCapacityD.Y), 122)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 143)
        equal(tonumber(f.vars.PanelHeightPx), 207)
        checkInlineCells(f, 'C', 1, 208, 10)
        checkInlineCells(f, 'D', 1, 208, 10)
        equal(f.queryRuns, 0)
        local longName = 'Archive ' .. string.rep('long name ', 8)
        f.values.MeasureIONameC = longName
        f:tick()
        contains(f:text('MeterIODriveC'), 'Archive long name')
        contains(f:tip('MeterIODriveC'), 'Archive long name')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(#f:traces()[1].points, 2)
        f.vars.IODriveNames = 'letters'
        local before = #f.calls
        equal(f:applyNamesMode(), 0)
        equal(f:text('MeterIODriveC'), 'C:')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(tonumber(f.options.MeterIOCapacityC.W), 88)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 72)
        equal(tonumber(f.options.MeterIODriveD.Y), 96)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 143)
        equal(tonumber(f.vars.PanelHeightPx), 207)
        equal(#f:traces()[1].points, 2, 'a name display callback must not add a rate observation')
        equal(f.queryRuns, 0)
        for index = before + 1, #f.calls do
            local call = f.calls[index]
            truth(call[1] == '!Redraw' or call[2] == 'MeterIODriveC' or call[2] == 'MeterIODriveD',
                'name formatting alone must not reflow graph or telemetry rows')
        end
        f:tick()
        equal(#f:traces()[1].points, 3, 'the next ordinary update should resume the same history')
    end)

    test('model completion repaints only cached names without another query or history observation', function()
        local f = fixture({ IODriveNames = 'model', IOGraphMode = 'overlay' }, {
            MeasureIOModelQuery = '', MeasureIODiskReadC = 1e6 })
        equal(f.queryRuns, 1)
        contains(f:text('MeterIODriveC'), 'Model unavailable')
        local graphOptions = {}
        for key, value in pairs(f.options.MeterIODiskGraph) do graphOptions[key] = value end
        local before = #f.calls
        f.values.MeasureIOModelQuery = 'IO_MODELS_V1\nOK\nC|Example device model'
        equal(f:namesReady(), 0)
        equal(f:text('MeterIODriveC'), 'C: Example device model')
        contains(f:tip('MeterIODriveC'), 'C: ')
        contains(f:tip('MeterIODriveC'), 'Example device model')
        equal(f:text('MeterIOLegendC'), 'C:')
        contains(f:tip('MeterIOLegendC'), 'Example device model')
        equal(f.queryRuns, 1)
        equal(#f:traces()[1].points, 1)
        for key, value in pairs(f.options.MeterIODiskGraph) do equal(value, graphOptions[key], 'metadata changed the graph') end
        for index = before + 1, #f.calls do
            local call = f.calls[index]
            truth(call[1] == '!Redraw' or call[2] == 'MeterIODriveC' or call[2] == 'MeterIOLegendC',
                'metadata completion touched telemetry or layout')
        end
        before = #f.calls
        f:namesReady()
        equal(#f.calls, before, 'an unchanged completion should leave meter options cached')
        f:tick()
        equal(#f:traces()[1].points, 2)
        equal(f.queryRuns, 1)
        f:refresh()
        equal(f.queryRuns, 2, 'refresh should issue one new model query')
        equal(#f:traces()[1].points, 1)
    end)

    test('both names preserve honest unavailable states and empty C-only graph geometry', function()
        local f = fixture({ IODriveNames = 'both', IOGraphMode = 'overlay', IODiskDrives = 'C,D' }, {
            MeasureIONameC = 'System', MeasureIOTypeD = 2, MeasureIONameD = 'Old label', MeasureIOModelQuery = '' })
        equal(f.queryRuns, 1)
        f.values.MeasureIOModelQuery = 'IO_MODELS_V1\nOK\nC|Example device model\nD|Old device model'
        f:namesReady()
        equal(f:text('MeterIODriveC'), 'C: System / Example device model')
        truth(not f:text('MeterIODriveD'):find('Old', 1, true), 'absent drive must not show stale names')
        contains(f:text('MeterIODriveD'), 'unavailable')
        equal(tonumber(f.options.MeterIODiskGraph.Y), 161)
        equal(tonumber(f.vars.PanelHeightPx), 225)
        f.vars.IODiskDrives, f.vars.IOGraphMode = 'none', 'c'
        f.vars.DataBarThickness = '12'
        f:tick()
        equal(f.shown.MeterIOEmpty, true)
        equal(tonumber(f.options.MeterIODriveC.Y), 0)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 0)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 93)
        equal(tonumber(f.vars.PanelHeightPx), 157, 'empty selection must not reserve name or bar rows')
        equal(#f:traces(), 2)
        equal(f.queryRuns, 1)
        f.vars.IODriveNames = 'invalid'
        f.vars.IODiskDrives = 'C'
        f.vars.DataBarThickness = '6'
        f:tick()
        equal(f:text('MeterIODriveC'), 'C: System')
        equal(tonumber(f.vars.PanelHeightPx), 157)
        equal(f.vars.IODriveNames, 'invalid', 'invalid display choices must not be persisted over')
        equal(f.queryRuns, 1)
    end)

    test('named rows and wrapped legends fit one and twenty-six drive endpoints at supported scales', function()
        local samples = {}
        for code = 65, 90 do
            local letter = string.char(code)
            samples['MeasureIOType' .. letter], samples['MeasureIOName' .. letter] = 4, 'Volume ' .. letter
            samples['MeasureIOTotal' .. letter], samples['MeasureIOFree' .. letter] = 1e9, 5e8
        end
        for _, mode in ipairs({'volume', 'model', 'both'}) do
            for _, scale in ipairs({0.75, 1, 2}) do
                for _, count in ipairs({1, 26}) do
                    for _, thickness in ipairs({1, 12}) do
                        local width, inset = 168 * scale, math.floor(4 * scale + 0.5)
                        local bar = math.max(1, math.floor(thickness * scale + 0.5))
                        local extra = math.max(0, bar / scale - 6)
                        local pitch = 50 + extra
                        local legendColumns = math.max(1, math.floor(width / (26 * scale)))
                        local legendRows = math.ceil(count / legendColumns)
                        local f = fixture({ IODriveNames = mode, IODiskDrives = count == 1 and 'C' or 'all',
                            IOGraphMode = 'overlay', Scale = tostring(scale), Inset = tostring(inset),
                            Gap = tostring(2 * inset), ContentX = tostring(inset + 6 * scale), ContentWidth = tostring(width),
                            DataBarThicknessPx = tostring(bar) }, samples)
                        local expectedGraph = inset + (89 + extra + (count - 1) * pitch + legendRows * 18) * scale
                        local expectedHeight = math.floor((157 + extra + (count - 1) * pitch + legendRows * 18) * scale + 0.5)
                        truth(math.abs(tonumber(f.options.MeterIODiskGraph.Y) - expectedGraph) < 0.001)
                        equal(tonumber(f.vars.PanelHeightPx), expectedHeight)
                        equal(tonumber(f.options.MeterIOBounds.H), expectedHeight + 2 * inset)
                        equal(f.queryRuns, mode == 'volume' and 0 or 1)
                        for code = 65, 90 do
                            local letter = string.char(code)
                            if count == 26 or letter == 'C' then
                                local index = letter == 'C' and 0 or (code < 67 and code - 64 or code - 65)
                                checkInlineCells(f, letter, scale, width, inset + 6 * scale)
                                truth(math.abs(tonumber(f.options['MeterIODrive' .. letter].Y) - inset - (42 + index * pitch) * scale) < 0.001)
                                local barY = inset + (60 + index * pitch) * scale + math.max(0, (6 * scale - bar) / 2)
                                local rateY = inset + (68 + extra + index * pitch) * scale
                                truth(math.abs(tonumber(f.options['MeterIOCapacity' .. letter].Y) - rateY) < 0.001)
                                truth(math.abs(tonumber(f.options['MeterIOUsed' .. letter].Y) - barY) < 0.001)
                                truth(math.abs(tonumber(f.options['MeterIODiskRead' .. letter].Y) - rateY) < 0.001)
                                truth(rateY >= barY + bar, 'named row speeds overlap the bar')
                                truth(tonumber(f.options['MeterIOLegend' .. letter].Y) + 18 * scale <= expectedGraph + 0.001)
                            end
                        end
                    end
                end
            end
        end
    end)

    test('name actions query without reflow sampling or prematurely changing drive membership', function()
        local f = fixture({ IODiskDrives = 'all' }, { MeasureIONameC = 'System',
            MeasureIOModelQuery = '', MeasureIODiskReadC = 1e6,
            MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8, MeasureIONameD = 'Archive' })
        f:tick()
        local points = f:traces()[1].points
        local oldX = points[1].x
        equal(#points, 2)
        f.vars.IODriveNames = 'model'
        local beforeMode = #f.calls
        equal(f:applyNamesMode(), 0)
        equal(f.queryRuns, 1)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 93)
        equal(tonumber(f.vars.PanelHeightPx), 157)
        equal(#f:traces()[1].points, 2)
        equal(f:traces()[1].points[1].x, oldX)
        for index = beforeMode + 1, #f.calls do
            local call = f.calls[index]
            truth(call[1] == '!CommandMeasure' or call[1] == '!Redraw' or call[2] == 'MeterIODriveC',
                'model name choice must not reflow existing readouts or graph')
        end
        f.values.MeasureIOTypeD = 4
        local before = #f.calls
        equal(f:refreshNamesInventory(), 0)
        equal(f.queryRuns, 2)
        equal(f.shown.MeterIODriveD, false, 'inventory callback must leave selected membership for ordinary Update')
        truth(not f.groups.IORatesD)
        equal(#f:traces()[1].points, 2)
        equal(f:traces()[1].points[1].x, oldX)
        local inventoryUpdates = 0
        for index = before + 1, #f.calls do
            local call = f.calls[index]
            if call[1]:find('MeasureGroup', 1, true) then
                equal(call[1], '!UpdateMeasureGroup')
                equal(call[2], 'IOInventory', 'name refresh must not force telemetry banks')
                inventoryUpdates = inventoryUpdates + 1
            end
        end
        equal(inventoryUpdates, 1)
        f:tick()
        equal(f.shown.MeterIODriveD, true)
        equal(f.groups.IORatesD, true)
        equal(#f:traces()[1].points, 1, 'ordinary membership reconciliation resets the changed graph scope')
        equal(f.queryRuns, 2)
    end)

    report[#report + 1] = string.format('SUMMARY: %d tests, %d assertions, %d failed',
        passed + failed, assertions, failed)
    local summary = table.concat(report, '\n')
    if failed > 0 then error(summary, 0) end
    return assertions, summary
end

return Suite
