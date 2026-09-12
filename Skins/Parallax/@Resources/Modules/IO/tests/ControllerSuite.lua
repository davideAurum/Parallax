-- Original Parallax controller tests for Lua 5.1.
-- All values below are synthetic fixtures supplied only to a mock SKIN/SELF.
-- No fixture is loaded into a real meter, measure, provider, or desktop skin.
-- This suite reads productionPath with loadfile; it writes no files, launches no
-- process, and executes no Rainmeter bangs. The caller owns its isolated runner.
-- Usage: local count, report = dofile(thisPath).run(productionPath)
-- A failed test raises its report; success returns the assertion count and report.
local Suite = {}

function Suite.run(productionPath)
    assert(type(productionPath) == 'string' and productionPath ~= '', 'productionPath is required')
    local assertions, passed, failed, report = 0, 0, 0, {}
    local GiB = 1024 * 1024 * 1024

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
        'MeterIOTotal', 'MeterIOCapacityHeading', 'MeterIODrive1', 'MeterIODrive2',
        'MeterIOCapacity1', 'MeterIOCapacity2', 'MeterIOUsed1', 'MeterIOUsed2',
        'MeterIODiskRead', 'MeterIODiskWrite', 'MeterIODiskReadBar',
        'MeterIODiskWriteBar', 'MeterIODiskHeading', 'MeterIODiskStatus',
        'MeterIODiskScale', 'MeterIOToggle'
    }) do targets[name] = true end

    local function fixture(overrides, samples, provider)
        local vars = {
            IODrive1 = 'C:', IODrive2 = 'D:', IOShowDrive2 = '0',
            IOIgnoreRemovable = '0', IODiskUnits = 'bytes',
            IODiskCategory = 'PhysicalDisk', IODiskInstance = '_Total',
            IODiskMaxMiBs = '500', CapacityInterval = '30000'
        }
        local values = {
            MeasureIOType1 = 4, MeasureIOTotal1 = 100 * GiB, MeasureIOFree1 = 25 * GiB,
            MeasureIOType2 = 4, MeasureIOTotal2 = 200 * GiB, MeasureIOFree2 = 50 * GiB,
            MeasureIODiskRead = 0, MeasureIODiskWrite = 0
        }
        for key, value in pairs(overrides or {}) do vars[key] = value end
        for key, value in pairs(samples or {}) do values[key] = value end
        local state = { vars = vars, values = values, options = {}, shown = {}, calls = {} }
        local skin = {}
        function skin:GetVariable(key, default)
            if vars[key] == nil then return default end
            return vars[key]
        end
        function skin:GetMeasure(key)
            if values[key] == nil then return nil end
            return { GetValue = function() return values[key] end }
        end
        function skin:Bang(command, target, key, value)
            assert(targets[target], 'unexpected controller target: ' .. tostring(target))
            if command == '!SetOption' then
                assert(key == 'Text' or key == 'ToolTipText' or key == 'LeftMouseUpAction' or key == 'FontColor',
                    'unexpected option mutation: ' .. tostring(key))
                state.options[target] = state.options[target] or {}
                state.options[target][key] = value
            elseif command == '!ShowMeter' then
                state.shown[target] = true
            elseif command == '!HideMeter' then
                state.shown[target] = false
            else
                error('unsupported bang in mock: ' .. tostring(command))
            end
            state.calls[#state.calls + 1] = { command, target, key, value }
        end
        local self = {}
        function self:GetNumberOption(key, default)
            assert(key == 'DiskProvider', 'unexpected SELF option: ' .. tostring(key))
            if provider == nil then return default end
            return provider
        end
        local function forbidden() error('controller attempted external work in fixture', 2) end
        local blockedLibrary = setmetatable({}, { __index = function() return forbidden end })
        local env = setmetatable({ SKIN = skin, SELF = self, io = blockedLibrary,
            os = blockedLibrary, require = forbidden, dofile = forbidden, loadfile = forbidden },
            { __index = _G })
        env._G = env
        local chunk, loadError = loadfile(productionPath)
        assert(chunk, loadError)
        setfenv(chunk, env)
        chunk()
        assert(type(env.Initialize) == 'function' and type(env.Update) == 'function',
            'controller entrypoints missing')
        env.Initialize()
        function state:tick() return env.Update() end
        function state:text(meter) return (self.options[meter] or {}).Text end
        function state:tip(meter) return (self.options[meter] or {}).ToolTipText end
        state:tick()
        return state
    end

    test('valid drives show binary free/total, used percentage, and independent rows', function()
        local f = fixture({ IOShowDrive2 = '1', TextColor = '210,220,230' })
        equal(f:text('MeterIODrive1'), 'C:')
        equal(f:text('MeterIOCapacity1'), '25.0 GiB / 100.0 GiB')
        equal(f:text('MeterIOCapacity2'), '50.0 GiB / 200.0 GiB')
        equal(f.options.MeterIOCapacity1.FontColor, '210,220,230')
        equal(f.options.MeterIOCapacity2.FontColor, '210,220,230')
        equal(f.shown.MeterIOUsed1, true)
        equal(f.shown.MeterIOUsed2, true)
        equal(f:tip('MeterIOUsed1'), '75.0% used')
        equal(f:text('MeterIOTotal'), '75%')
        equal(f:tip('MeterIOTotal'), 'C: 75.0% used')
        contains(f:tip('MeterIOCapacity1'), '(free / total)')
    end)

    test('a full drive has valid zero free space rather than an unavailable state', function()
        local f = fixture(nil, { MeasureIOFree1 = 0 })
        equal(f:text('MeterIOCapacity1'), '0.0 B / 100.0 GiB')
        equal(f:tip('MeterIOUsed1'), '100.0% used')
        equal(f:text('MeterIOTotal'), '100%')
        equal(f.shown.MeterIOUsed1, true)
    end)

    test('a completely free drive remains valid at zero used percentage', function()
        local f = fixture(nil, { MeasureIOFree1 = 100 * GiB })
        equal(f:tip('MeterIOUsed1'), '0.0% used')
        equal(f:text('MeterIOTotal'), '0%')
        equal(f.shown.MeterIOUsed1, true)
    end)

    test('missing and errored drive types suppress otherwise plausible capacity', function()
        for _, kind in ipairs({ 0, 1 }) do
            local f = fixture({ MutedColor = '160,170,180' }, { MeasureIOType1 = kind })
            equal(f:text('MeterIOCapacity1'), 'Missing / unavailable')
            equal(f.options.MeterIOCapacity1.FontColor, '160,170,180')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsed1, false)
        end
    end)

    test('optical capacity is explicitly unsupported', function()
        local f = fixture(nil, { MeasureIOType1 = 6 })
        equal(f:text('MeterIOCapacity1'), 'Optical unsupported')
        equal(f:text('MeterIOTotal'), '--')
        equal(f.shown.MeterIOUsed1, false)
    end)

    test('removable drives follow the ignore setting', function()
        local ignored = fixture({ IOIgnoreRemovable = '1' }, { MeasureIOType1 = 3 })
        equal(ignored:text('MeterIOCapacity1'), 'Removable ignored')
        equal(ignored:text('MeterIOTotal'), '--')
        equal(ignored.shown.MeterIOUsed1, false)
        local included = fixture({ IOIgnoreRemovable = '0' }, { MeasureIOType1 = 3 })
        equal(included:text('MeterIOCapacity1'), '25.0 GiB / 100.0 GiB')
        equal(included.shown.MeterIOUsed1, true)
    end)

    test('invalid totals and free values never produce a capacity bar', function()
        for _, bad in ipairs({ 0, -1, math.huge, -math.huge, 0/0, '100' }) do
            local f = fixture(nil, { MeasureIOTotal1 = bad })
            equal(f:text('MeterIOCapacity1'), 'Unavailable')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsed1, false)
        end
        for _, bad in ipairs({ -1, 101 * GiB, math.huge, -math.huge, 0/0, '25' }) do
            local f = fixture(nil, { MeasureIOFree1 = bad })
            equal(f:text('MeterIOCapacity1'), 'Unavailable')
            equal(f:text('MeterIOTotal'), '--')
            equal(f.shown.MeterIOUsed1, false)
        end
        local missing = fixture()
        missing.values.MeasureIOTotal1 = nil
        missing:tick()
        equal(missing:text('MeterIOCapacity1'), 'Unavailable')
        equal(missing.shown.MeterIOUsed1, false)
    end)

    test('drive two remains off even when its mock measures have valid values', function()
        local f = fixture()
        equal(f:text('MeterIOCapacity2'), 'Off')
        equal(f.shown.MeterIOUsed2, false)
        equal(f.shown.MeterIOUsed1, true)
    end)

    test('native variant suppresses optional samples and provides its enable action', function()
        local f = fixture(nil, { MeasureIODiskRead = 1048576, MeasureIODiskWrite = 1048576 }, 0)
        equal(f:text('MeterIODiskRead'), '--')
        equal(f:text('MeterIODiskWrite'), '--')
        equal(f.shown.MeterIODiskReadBar, false)
        equal(f.shown.MeterIODiskWriteBar, false)
        equal(f:text('MeterIODiskHeading'), 'Disk transfers')
        equal(f:text('MeterIODiskStatus'), 'Counters off')
        equal(f:text('MeterIODiskScale'), 'Native capacity only')
        equal(f:text('MeterIOToggle'), 'Enable counters')
        equal(f.options.MeterIOToggle.LeftMouseUpAction,
            '[!ActivateConfig "Parallax\\IO" "IO-Disk.ini"]')
    end)

    test('positive optional read and zero write retain their distinct meanings', function()
        local f = fixture(nil, { MeasureIODiskRead = 1048576 }, 1)
        equal(f:text('MeterIODiskRead'), '1.0 MiB/s')
        equal(f:text('MeterIODiskWrite'), '--')
        equal(f.shown.MeterIODiskReadBar, true)
        equal(f.shown.MeterIODiskWriteBar, false)
        equal(f:text('MeterIODiskStatus'), 'Reported; age unknown')
        equal(f:text('MeterIODiskScale'), 'Read/write limit: 500 MiB/s')
        equal(f:text('MeterIOToggle'), 'Disable counters')
        equal(f.options.MeterIOToggle.LeftMouseUpAction,
            '[!ActivateConfig "Parallax\\IO" "IO.ini"]')
        contains(f:tip('MeterIODiskRead'), 'sample freshness is unknown')
        contains(f:tip('MeterIODiskWrite'), 'idle, missing counter, unavailable provider, or initial sample')
        equal(f:text('MeterIOCapacity1'), '25.0 GiB / 100.0 GiB')
    end)

    test('bits use decimal units while capacity stays binary', function()
        local f = fixture({ IODiskUnits = 'BITS' },
            { MeasureIODiskRead = 125000, MeasureIODiskWrite = 125 }, 1)
        equal(f:text('MeterIODiskRead'), '1.0 Mbit/s')
        equal(f:text('MeterIODiskWrite'), '1.0 kbit/s')
        equal(f:text('MeterIOCapacity1'), '25.0 GiB / 100.0 GiB')
    end)

    test('empty and whitespace instance settings cannot expose aggregate fallback values', function()
        for _, instance in ipairs({ '', ' ', '\t\r\n' }) do
            local f = fixture({ IODiskInstance = instance },
                { MeasureIODiskRead = 1048576, MeasureIODiskWrite = 1048576 }, 1)
            equal(f:text('MeterIODiskStatus'), 'Check disk instance')
            equal(f:text('MeterIODiskRead'), '--')
            equal(f:text('MeterIODiskWrite'), '--')
            equal(f.shown.MeterIODiskReadBar, false)
            equal(f.shown.MeterIODiskWriteBar, false)
        end
    end)

    test('Process and other unsupported categories cannot appear as disk throughput', function()
        for _, category in ipairs({ 'Process', 'Network Interface', 'physicaldisk', '' }) do
            local f = fixture({ IODiskCategory = category },
                { MeasureIODiskRead = 1048576, MeasureIODiskWrite = 1048576 }, 1)
            equal(f:text('MeterIODiskStatus'), 'Unsupported category')
            equal(f:text('MeterIODiskRead'), '--')
            equal(f:text('MeterIODiskWrite'), '--')
            equal(f.shown.MeterIODiskReadBar, false)
            equal(f.shown.MeterIODiskWriteBar, false)
        end
    end)

    test('LogicalDisk remains supported with an explicitly named instance', function()
        local f = fixture({ IODiskCategory = 'LogicalDisk', IODiskInstance = 'D:' },
            { MeasureIODiskWrite = 1024 }, 1)
        equal(f:text('MeterIODiskHeading'), 'LogicalDisk / D:')
        equal(f:text('MeterIODiskWrite'), '1.0 KiB/s')
        equal(f.shown.MeterIODiskWriteBar, true)
        contains(f:tip('MeterIODiskHeading'), 'Independent of capacity drive selection')
    end)

    test('negative nonfinite malformed and absent disk values stay ambiguous', function()
        for _, bad in ipairs({ -1, math.huge, -math.huge, 0/0, '42', false }) do
            local f = fixture(nil, { MeasureIODiskRead = bad, MeasureIODiskWrite = bad }, 1)
            equal(f:text('MeterIODiskRead'), '--')
            equal(f:text('MeterIODiskWrite'), '--')
            equal(f.shown.MeterIODiskReadBar, false)
            equal(f.shown.MeterIODiskWriteBar, false)
            equal(f:text('MeterIODiskStatus'), 'Idle or unavailable')
        end
        local f = fixture(nil, nil, 1)
        f.values.MeasureIODiskRead = nil
        f.values.MeasureIODiskWrite = nil
        f:tick()
        equal(f:text('MeterIODiskRead'), '--')
        equal(f:text('MeterIODiskWrite'), '--')
        equal(f:text('MeterIODiskStatus'), 'Idle or unavailable')
    end)

    test('returning to all-zero rates hides both bars and removes earlier positive text', function()
        local f = fixture(nil, { MeasureIODiskRead = 1024, MeasureIODiskWrite = 2048 }, 1)
        equal(f.shown.MeterIODiskReadBar, true)
        equal(f.shown.MeterIODiskWriteBar, true)
        f.values.MeasureIODiskRead, f.values.MeasureIODiskWrite = 0, 0
        f:tick()
        equal(f:text('MeterIODiskRead'), '--')
        equal(f:text('MeterIODiskWrite'), '--')
        equal(f.shown.MeterIODiskReadBar, false)
        equal(f.shown.MeterIODiskWriteBar, false)
        equal(f:text('MeterIODiskStatus'), 'Idle or unavailable')
        contains(f:tip('MeterIODiskStatus'), 'A nonzero value may be stale')
    end)

    test('invalid graph ceilings hide bars without hiding valid rate text', function()
        for _, limit in ipairs({ '0', '-1', 'bad', '1e309' }) do
            local f = fixture({ IODiskMaxMiBs = limit }, { MeasureIODiskRead = 1024 }, 1)
            equal(f:text('MeterIODiskRead'), '1.0 KiB/s')
            equal(f.shown.MeterIODiskReadBar, false)
            equal(f:text('MeterIODiskScale'), 'Check graph limit')
        end
    end)

    test('unsupported display units are visible rather than silently reinterpreted', function()
        local f = fixture({ IODiskUnits = 'invalid' }, { MeasureIODiskRead = 1024 }, 1)
        equal(f:text('MeterIODiskRead'), 'Check IO units')
    end)

    test('labels and provider descriptions cannot introduce Rainmeter expression syntax', function()
        local dirtyDrive = 'C:\n#[!Refresh]'
        local dirtyInstance = '_Total#x#[!Quit]\t'
        local f = fixture({ IODrive1 = dirtyDrive, IODiskInstance = dirtyInstance }, nil, 1)
        truth(f:text('MeterIODrive1') ~= dirtyDrive, 'drive label was not sanitized')
        truth(f:text('MeterIODiskHeading') ~= 'PhysicalDisk / ' .. dirtyInstance,
            'instance label was not sanitized')
        for meter, opts in pairs(f.options) do
            for key, value in pairs(opts) do
                if key == 'Text' or key == 'ToolTipText' then
                    truth(not value:find('[%c#%[%]]'), meter .. '.' .. key .. ' has expression delimiters')
                end
            end
        end
        equal(f.vars.IODrive1, dirtyDrive, 'presentation must not mutate configuration')
        equal(f.vars.IODiskInstance, dirtyInstance, 'presentation must not mutate instance selection')
    end)

    test('capacity cadence tooltip rounds upward and respects the five-second minimum', function()
        local slow = fixture({ CapacityInterval = '30500' })
        contains(slow:tip('MeterIOCapacityHeading'), 'every 31 seconds')
        local fast = fixture({ CapacityInterval = '1000' })
        contains(fast:tip('MeterIOCapacityHeading'), 'every 5 seconds')
    end)

    test('unchanged updates emit no additional option or visibility mutations', function()
        local f = fixture(nil, { MeasureIODiskRead = 1024 }, 1)
        local before = #f.calls
        equal(f:tick(), 0)
        equal(#f.calls, before)
    end)

    report[#report + 1] = string.format('SUMMARY: %d tests, %d assertions, %d failed',
        passed + failed, assertions, failed)
    local summary = table.concat(report, '\n')
    if failed > 0 then error(summary, 0) end
    return assertions, summary
end

return Suite
