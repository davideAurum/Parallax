-- Original Parallax IO settings regression tests for Lua 5.1.
-- Synthetic settings and captured bangs exist only in this mock. No file write,
-- provider access, process launch, or live Rainmeter operation is performed.
-- Usage: local count, report = dofile(thisPath).run(settingsProductionPath)
-- Success returns an assertion count and report; failures raise a combined report.
local Suite = {}

function Suite.run(productionPath)
    assert(type(productionPath) == 'string' and productionPath ~= '', 'productionPath is required')
    local assertions, passed, failed, report = 0, 0, 0, {}
    local resourceRoot = 'C:\\ParallaxTests\\@Resources\\'
    local userFile = resourceRoot .. 'User\\IO.inc'
    local allowed = {
        IODrive1 = true, IODrive2 = true, IOShowDrive2 = true,
        IOIgnoreRemovable = true, IODiskQuota = true, IODiskUnits = true,
        IODiskCategory = true, IODiskInstance = true, IODiskMaxMiBs = true
    }
    local levels = { 10, 50, 100, 250, 500, 1000, 2000, 5000 }

    local function equal(actual, expected, message)
        assertions = assertions + 1
        if actual ~= expected then
            error((message or 'value') .. ': expected ' .. tostring(expected)
                .. ', got ' .. tostring(actual), 2)
        end
    end

    local function check(value, message)
        assertions = assertions + 1
        if not value then error(message or 'expected true', 2) end
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

    local function fixture(overrides)
        local vars = {
            ['@'] = resourceRoot, CURRENTCONFIG = 'Parallax\\IO\\Settings',
            IODrive1 = 'C:', IODrive2 = 'D:', IOShowDrive2 = '0',
            IOIgnoreRemovable = '0', IODiskQuota = '0', IODiskUnits = 'bytes',
            IODiskCategory = 'PhysicalDisk', IODiskInstance = '_Total',
            IODiskMaxMiBs = '500'
        }
        for key, value in pairs(overrides or {}) do vars[key] = value end
        local f = { vars = vars, persisted = {}, calls = {}, writes = {},
            refreshes = {}, options = {}, activations = {}, closes = {} }
        for key, value in pairs(vars) do f.persisted[key] = value end
        local skin = {}
        function skin:GetVariable(key, default)
            if vars[key] == nil then return default end
            return vars[key]
        end
        function skin:Bang(command, ...)
            local args = { ... }
            f.calls[#f.calls + 1] = { command = command, args = args }
            if command == '!SetOption' then
                assert(select('#', ...) == 3, 'display update must not add a config argument')
                assert(type(args[1]) == 'string', 'meter name must be a string')
                assert(args[2] == 'Text' or args[2] == 'ToolTipText',
                    'settings must not build actions from user values')
                assert(type(args[3]) == 'string', 'display value must be a string')
                f.options[args[1]] = f.options[args[1]] or {}
                f.options[args[1]][args[2]] = args[3]
            elseif command == '!SetVariable' then
                assert(allowed[args[1]], 'non-IO or unsupported variable mutation')
                assert(type(args[2]) == 'string', 'variable value must be a string')
                assert(select('#', ...) == 2, 'variable update must target only this settings skin')
                vars[args[1]] = args[2]
            elseif command == '!WriteKeyValue' then
                assert(select('#', ...) == 4, 'write requires exact scalar arguments')
                assert(args[1] == 'Variables', 'write must use the Variables section')
                assert(allowed[args[2]], 'non-IO or unsupported key persisted')
                assert(type(args[3]) == 'string', 'persisted value must be a string')
                assert(not args[3]:find('[%c#%[%]]'), 'unsafe syntax in persisted value')
                assert(args[4] == userFile, 'write escaped User/IO.inc')
                f.writes[#f.writes + 1] = { key = args[2], value = args[3], path = args[4] }
                f.persisted[args[2]] = args[3]
            elseif command == '!RefreshGroup' then
                assert(select('#', ...) == 1 and args[1] == 'ParallaxIO',
                    'refresh escaped the IO group')
                f.refreshes[#f.refreshes + 1] = { command = command, target = args[1] }
            elseif command == '!Refresh' then
                assert(select('#', ...) == 0, 'settings reload must affect only its own config')
                f.refreshes[#f.refreshes + 1] = { command = command }
            elseif command == '!ActivateConfig' then
                assert(select('#', ...) == 2 and args[1] == 'Parallax\\IO',
                    'activation escaped the IO config')
                assert(args[2] == 'IO.ini' or args[2] == 'IO-Disk.ini',
                    'activation used an unknown variant')
                f.activations[#f.activations + 1] = { config = args[1], file = args[2] }
            elseif command == '!DeactivateConfig' then
                assert(select('#', ...) == 0, 'close must affect only its own settings config')
                f.closes[#f.closes + 1] = true
            elseif command == '!UpdateMeterGroup' then
                assert(select('#', ...) == 1 and args[1] == 'IOSettingsUI',
                    'meter update escaped the IO settings view')
            elseif command == '!Redraw' then
                assert(select('#', ...) == 0, 'redraw must affect only its own settings config')
            else
                error('unexpected bang in settings mock: ' .. tostring(command))
            end
        end
        local function forbidden() error('settings attempted external work in fixture', 2) end
        local blockedLibrary = setmetatable({}, { __index = function() return forbidden end })
        local env = setmetatable({ SKIN = skin, SELF = {}, io = blockedLibrary,
            os = blockedLibrary, package = blockedLibrary, debug = blockedLibrary,
            require = forbidden, dofile = forbidden, loadfile = forbidden, loadstring = forbidden },
            { __index = _G })
        env._G = env
        local chunk, loadError = loadfile(productionPath)
        assert(chunk, loadError)
        setfenv(chunk, env)
        chunk()
        for _, name in ipairs({ 'Initialize', 'Update', 'Toggle', 'CycleDrive',
            'CycleUnits', 'CycleCategory', 'UseTotal', 'UseCapacityDrive',
            'CycleLimit', 'Activate', 'Apply', 'Close' }) do
            assert(type(env[name]) == 'function', 'settings entrypoint missing: ' .. name)
        end
        f.env = env
        function f:clear()
            self.calls, self.writes, self.refreshes, self.activations, self.closes = {}, {}, {}, {}, {}
        end
        function f:reload() return fixture(self.persisted) end
        env.Initialize()
        env.Update()
        return f
    end

    local function idle(f)
        equal(#f.writes, 0, 'unexpected persistence')
        equal(#f.refreshes, 0, 'unexpected refresh')
        equal(#f.activations, 0, 'unexpected activation')
        equal(#f.closes, 0, 'unexpected close')
    end

    local function saved(f, expected)
        local count, seen, lastWrite, refreshPosition = 0, {}, 0, nil
        for _ in pairs(expected) do count = count + 1 end
        equal(#f.writes, count, 'write count')
        for _, write in ipairs(f.writes) do
            check(expected[write.key] ~= nil, 'unexpected written key: ' .. write.key)
            check(not seen[write.key], 'same key written twice in one action')
            seen[write.key] = true
            equal(write.value, expected[write.key], write.key)
            equal(f.persisted[write.key], expected[write.key], 'persisted ' .. write.key)
        end
        equal(#f.refreshes, 1, 'one IO refresh per edit')
        equal(f.refreshes[1].command, '!RefreshGroup')
        equal(f.refreshes[1].target, 'ParallaxIO')
        for index, call in ipairs(f.calls) do
            if call.command == '!WriteKeyValue' then lastWrite = index end
            if call.command == '!RefreshGroup' then refreshPosition = index end
        end
        check(refreshPosition > lastWrite, 'refresh happened before the save batch completed')
        equal(#f.activations, 0, 'save must not load a variant')
        equal(#f.closes, 0, 'save must not close settings')
    end

    test('initialization and repeated view updates never persist or refresh', function()
        local f = fixture()
        idle(f)
        for _ = 1, 5 do f.env.Update() end
        idle(f)
        check(next(f.options) ~= nil, 'settings view never rendered')
    end)

    test('opening custom preferences preserves exact values until an explicit edit', function()
        local custom = { IODrive1 = '\\\\server\\share', IODrive2 = 'Q:\\Mount\\',
            IODiskInstance = '0 C: D:', IODiskCategory = 'Custom Category',
            IODiskUnits = 'CUSTOM', IODiskMaxMiBs = '737.125', IODiskQuota = 'custom' }
        local f = fixture(custom)
        f.env.Update()
        idle(f)
        for key, value in pairs(custom) do equal(f.persisted[key], value, key) end
        f:clear()
        f.env.Toggle('IOShowDrive2')
        saved(f, { IOShowDrive2 = '1' })
        for key, value in pairs(custom) do equal(f.persisted[key], value, 'untouched ' .. key) end
    end)

    test('all three boolean controls toggle and save independently', function()
        for _, key in ipairs({ 'IOShowDrive2', 'IOIgnoreRemovable', 'IODiskQuota' }) do
            local f = fixture()
            f.env.Toggle(key)
            saved(f, { [key] = '1' })
            f:clear()
            f.env.Toggle(key)
            saved(f, { [key] = '0' })
        end
    end)

    test('toggle cannot act as an arbitrary settings writer', function()
        local f = fixture()
        for _, key in ipairs({ 'IODrive1', 'IODiskCategory', 'IODiskInstance', 'IODiskUnits',
            'IODiskMaxMiBs', 'Scale', 'Theme', 'Columns', 'ParallaxIO', '',
            'IOShowDrive2][!Quit]', {}, false, 0, math.huge }) do
            f.env.Toggle(key)
        end
        f.env.Toggle(nil)
        idle(f)
        equal(f.persisted.IOShowDrive2, '0')
    end)

    test('drive controls step letters and wrap at A and Z independently', function()
        for _, case in ipairs({
            { 1, 'C:', 1, 'D:' }, { 2, 'D:', -1, 'C:' },
            { 1, 'Z:', 1, 'A:' }, { 2, 'A:', -1, 'Z:' },
            { 1, 'c:\\', 1, 'D:' }, { 2, 'z:/', -1, 'Y:' }
        }) do
            local key = 'IODrive' .. case[1]
            local f = fixture({ [key] = case[2], IODiskInstance = '0 C: D:' })
            f.env.CycleDrive(case[1], case[3])
            saved(f, { [key] = case[4] })
            equal(f.persisted.IODiskInstance, '0 C: D:', 'capacity change must not select a counter')
        end
    end)

    test('custom capacity roots only change when their own drive control is used', function()
        for _, step in ipairs({ -1, 1 }) do
            local f = fixture({ IODrive1 = '\\\\server\\share' })
            idle(f)
            f.env.CycleDrive(1, step)
            saved(f, { IODrive1 = step == 1 and 'C:' or 'Z:' })
        end
    end)

    test('drive controls reject invalid indices and steps without side effects', function()
        local f = fixture()
        for _, index in ipairs({ 0, 3, -1, 1.5, '1', {}, false, math.huge, 0/0 }) do
            f.env.CycleDrive(index, 1)
            f.env.UseCapacityDrive(index)
        end
        f.env.CycleDrive(nil, 1)
        f.env.UseCapacityDrive(nil)
        for _, step in ipairs({ 0, 2, -2, 0.5, '1', {}, false, math.huge, 0/0 }) do
            f.env.CycleDrive(1, step)
        end
        f.env.CycleDrive(1, nil)
        idle(f)
    end)

    test('units cycle between bytes and bits with one write per action', function()
        local f = fixture()
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bits' })
        f:clear()
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bytes' })
        equal(f.persisted.IODiskMaxMiBs, '500', 'display units must not alter the binary scale')
    end)

    test('category cycles preserve the exact independently configured instance', function()
        local f = fixture({ IODiskInstance = '3 E: F:' })
        f.env.CycleCategory()
        saved(f, { IODiskCategory = 'LogicalDisk' })
        equal(f.persisted.IODiskInstance, '3 E: F:')
        f:clear()
        f.env.CycleCategory()
        saved(f, { IODiskCategory = 'PhysicalDisk' })
        equal(f.persisted.IODiskInstance, '3 E: F:')
    end)

    test('explicit unit and category controls repair only their own custom choice', function()
        local f = fixture({ IODiskUnits = 'custom units', IODiskCategory = 'Process',
            IODiskInstance = 'custom exact instance' })
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bytes' })
        equal(f.persisted.IODiskCategory, 'Process')
        equal(f.persisted.IODiskInstance, 'custom exact instance')
        f:clear()
        f.env.CycleCategory()
        saved(f, { IODiskCategory = 'PhysicalDisk' })
        equal(f.persisted.IODiskInstance, 'custom exact instance')
    end)

    test('the explicit total action changes only the instance', function()
        local f = fixture({ IODiskCategory = 'LogicalDisk', IODiskInstance = 'D:' })
        f.env.UseTotal()
        saved(f, { IODiskInstance = '_Total' })
        equal(f.persisted.IODiskCategory, 'LogicalDisk')
        equal(f.persisted.IODrive1, 'C:')
        equal(f.persisted.IODrive2, 'D:')
    end)

    test('using a capacity drive batches LogicalDisk and its normalized instance', function()
        for _, case in ipairs({ {1, 'q:', 'Q:'}, {1, 'R:\\', 'R:'},
            {2, 's:/', 'S:'}, {2, 'Z:', 'Z:'} }) do
            local f = fixture({ ['IODrive' .. case[1]] = case[2] })
            f.env.UseCapacityDrive(case[1])
            saved(f, { IODiskCategory = 'LogicalDisk', IODiskInstance = case[3] })
            equal(f.persisted['IODrive' .. case[1]], case[2], 'counter selection must not rewrite capacity')
        end
    end)

    test('selecting the already configured instance performs no redundant write or refresh', function()
        local total = fixture()
        total.env.UseTotal()
        idle(total)
        local drive = fixture({ IODiskCategory = 'LogicalDisk', IODiskInstance = 'C:' })
        drive.env.UseCapacityDrive(1)
        idle(drive)
        local instanceOnly = fixture({ IODiskCategory = 'LogicalDisk', IODiskInstance = 'Z:' })
        instanceOnly.env.UseCapacityDrive(1)
        saved(instanceOnly, { IODiskInstance = 'C:' })
    end)

    test('capacity-to-counter selection rejects custom paths and unsafe drive syntax', function()
        for _, drive in ipairs({ '', ' ', 'C', 'CC:', 'C:\\Mount\\', 'C:/Mount/',
            '\\\\server\\share', ' C:', 'C: ', 'C:\\\\', 'C://', 'C:\n',
            'C:#x#', 'C:][!Quit]', '[&Measure:Run()]', '1:', 'é:' }) do
            local f = fixture({ IODrive1 = drive })
            f.env.UseCapacityDrive(1)
            idle(f)
            equal(f.persisted.IODiskCategory, 'PhysicalDisk')
            equal(f.persisted.IODiskInstance, '_Total')
            equal(f.persisted.IODrive1, drive)
        end
    end)

    test('all graph limit presets advance and reverse with wraparound', function()
        for index, level in ipairs(levels) do
            for _, step in ipairs({ -1, 1 }) do
                local f = fixture({ IODiskMaxMiBs = tostring(level) })
                local nextIndex = ((index - 1 + step) % #levels) + 1
                f.env.CycleLimit(step)
                saved(f, { IODiskMaxMiBs = tostring(levels[nextIndex]) })
            end
        end
    end)

    test('custom finite graph limits move to the next greater or smaller preset', function()
        for _, case in ipairs({ {'75', 1, '100'}, {'75', -1, '50'},
            {'737.125', 1, '1000'}, {'737.125', -1, '500'},
            {'5', 1, '10'}, {'5', -1, '5000'},
            {'6000', 1, '10'}, {'6000', -1, '5000'} }) do
            local f = fixture({ IODiskMaxMiBs = case[1] })
            idle(f)
            equal(f.persisted.IODiskMaxMiBs, case[1])
            f.env.CycleLimit(case[2])
            saved(f, { IODiskMaxMiBs = case[3] })
        end
    end)

    test('editing a malformed or nonfinite graph limit yields a safe supported preset', function()
        for _, value in ipairs({ '', 'bad', '1e309', '-1e309', 'nan', '0/0',
            '[!Quit]', math.huge, -math.huge, 0/0 }) do
            for _, step in ipairs({ -1, 1 }) do
                local f = fixture({ IODiskMaxMiBs = value })
                idle(f)
                f.env.CycleLimit(step)
                equal(#f.writes, 1)
                local written = f.writes[1].value
                local supported = false
                for _, level in ipairs(levels) do
                    if written == tostring(level) then supported = true end
                end
                check(supported, 'unsafe graph limit persisted: ' .. tostring(written))
                saved(f, { IODiskMaxMiBs = written })
            end
        end
    end)

    test('graph limit controls reject malformed steps without persisting', function()
        local f = fixture()
        for _, step in ipairs({ 0, 2, -2, 0.5, '1', {}, false, math.huge, 0/0 }) do
            f.env.CycleLimit(step)
        end
        f.env.CycleLimit(nil)
        idle(f)
    end)

    test('counter and native activation use only their fixed IO variants', function()
        local f = fixture()
        f.env.Activate('counters')
        f.env.Activate('native')
        equal(#f.activations, 2)
        equal(f.activations[1].file, 'IO-Disk.ini')
        equal(f.activations[2].file, 'IO.ini')
        equal(#f.writes, 0)
        equal(#f.refreshes, 0)
        equal(#f.closes, 0)
    end)

    test('variant activation rejects unknown modes and action-shaped strings', function()
        local f = fixture()
        for _, mode in ipairs({ '', 'Native', 'Counters', 'IO.ini', '..\\Network',
            'native][!Quit]', '[!ActivateConfig "Other"]', {}, false, 1 }) do
            f.env.Activate(mode)
        end
        f.env.Activate(nil)
        idle(f)
    end)

    test('explicit Apply refreshes the IO group then only its own settings config', function()
        local f = fixture()
        equal(f.env.Apply(), true)
        equal(#f.writes, 0)
        equal(#f.refreshes, 2)
        equal(f.refreshes[1].command, '!RefreshGroup')
        equal(f.refreshes[1].target, 'ParallaxIO')
        equal(f.refreshes[2].command, '!Refresh')
        equal(f.refreshes[2].target, nil)
        equal(#f.activations, 0)
        equal(#f.closes, 0)
    end)

    test('Close deactivates only the settings config and never persists or refreshes', function()
        local f = fixture()
        equal(f.env.Close(), true)
        equal(#f.closes, 1)
        equal(#f.writes, 0)
        equal(#f.refreshes, 0)
        equal(#f.activations, 0)
    end)

    test('reinitialization reads externally changed preferences without writing them', function()
        local f = fixture()
        f.vars.IODrive1 = 'Y:'
        f.vars.IODiskUnits = 'bits'
        f.vars.IODiskMaxMiBs = '75'
        f.env.Initialize()
        f.env.Update()
        idle(f)
        f.env.CycleDrive(1, 1)
        saved(f, { IODrive1 = 'Z:' })
        f:clear()
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bytes' })
        f:clear()
        f.env.CycleLimit(-1)
        saved(f, { IODiskMaxMiBs = '50' })
    end)

    test('saved settings survive a fresh controller load without repeated writes', function()
        local f = fixture({ IODiskInstance = 'custom exact instance' })
        f.env.Toggle('IOShowDrive2')
        f.env.CycleDrive(2, 1)
        f.env.CycleUnits()
        f.env.CycleCategory()
        f.env.CycleLimit(1)
        local reloaded = f:reload()
        idle(reloaded)
        equal(reloaded.persisted.IOShowDrive2, '1')
        equal(reloaded.persisted.IODrive2, 'E:')
        equal(reloaded.persisted.IODiskUnits, 'bits')
        equal(reloaded.persisted.IODiskCategory, 'LogicalDisk')
        equal(reloaded.persisted.IODiskMaxMiBs, '1000')
        equal(reloaded.persisted.IODiskInstance, 'custom exact instance')
        reloaded.env.Toggle('IOShowDrive2')
        saved(reloaded, { IOShowDrive2 = '0' })
    end)

    test('display sanitizes custom setting text without expanding actions or rewriting it', function()
        local dirty = 'custom#x#[!Quit]\t\r\n'
        local f = fixture({ IODrive1 = dirty, IODrive2 = dirty, IODiskCategory = dirty,
            IODiskInstance = dirty, IODiskUnits = dirty, IODiskMaxMiBs = dirty })
        idle(f)
        for meter, options in pairs(f.options) do
            for key, value in pairs(options) do
                check(not value:find('[%c#%[%]]'), meter .. '.' .. key .. ' has expression delimiters')
            end
        end
        for _, key in ipairs({ 'IODrive1', 'IODrive2', 'IODiskCategory',
            'IODiskInstance', 'IODiskUnits', 'IODiskMaxMiBs' }) do
            equal(f.persisted[key], dirty, 'display must preserve raw ' .. key)
        end
        f:clear()
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '1' })
        equal(f.persisted.IODiskInstance, dirty, 'unrelated edit must preserve exact instance')
    end)

    report[#report + 1] = string.format('SUMMARY: %d tests, %d assertions, %d failed',
        passed + failed, assertions, failed)
    local summary = table.concat(report, '\n')
    if failed > 0 then error(summary, 0) end
    return assertions, summary
end

return Suite
