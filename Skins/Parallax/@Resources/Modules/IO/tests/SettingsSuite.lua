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
        IODiskQuota = true, IODiskUnits = true, IODiskMaxMiBs = true,
        IODiskDrives = true, IOGraphMode = true, IODriveNames = true
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

    local function fixture(overrides, inventory, initialize, metadata)
        local vars = {
            ['@'] = resourceRoot, CURRENTCONFIG = 'Parallax\\IO\\Settings',
            Scale = '1', Inset = '4', Gap = '8', PanelHeight = '400',
            IODiskQuota = '0', IODiskUnits = 'bytes',
            IODiskMaxMiBs = '500', IODiskDrives = 'C', IOGraphMode = 'combined', IODriveNames = 'volume'
        }
        for key, value in pairs(overrides or {}) do vars[key] = value end
        local f = { vars = vars, persisted = {}, calls = {}, writes = {},
            refreshes = {}, options = {}, activations = {}, closes = {},
            inventoryRefreshes = {}, modelQueries = {}, namePublishes = {}, mainNamesCalls = {}, types = {}, labels = {},
            inputRuns = {}, inputUpdates = {}, inputOutput = '', inputMeterAvailable = true,
            skinX = 100, skinY = 200, frameW = 104, frameH = 20 }
        for key, value in pairs(vars) do f.persisted[key] = value end
        for code = 65, 90 do f.types[string.char(code)] = 1 end
        f.types.C = 4
        f.labels.C = 'System'
        for letter, value in pairs(inventory or {}) do f.types[letter] = value end
        for letter, value in pairs((metadata or {}).labels or {}) do f.labels[letter] = value end
        f.modelOutput = (metadata or {}).modelOutput or ''
        local skin = {}
        function skin:GetVariable(key, default)
            if vars[key] == nil then return default end
            return vars[key]
        end
        function skin:GetX() return f.skinX end
        function skin:GetY() return f.skinY end
        function skin:GetMeter(name)
            assert(name == 'MeterIOSettingsLimitFrame', 'numeric editor requested an unexpected meter')
            if not f.inputMeterAvailable then return nil end
            return { GetX = function() return 150 end,
                GetY = function() return tonumber((f.options[name] or {}).Y) or 304 end,
                GetW = function() return f.frameW end, GetH = function() return f.frameH end }
        end
        function skin:GetMeasure(name)
            if name == 'MeasureIOSettingsNumberInput' then
                return { GetStringValue = function() return f.inputOutput end }
            end
            if name == 'MeasureIOModelQuery' then
                return { GetStringValue = function() return f.modelOutput end }
            end
            local namedLetter = type(name) == 'string' and name:match('^MeasureIOName([A-Z])$')
            if namedLetter then
                return { GetStringValue = function() return f.labels[namedLetter] or '' end }
            end
            local letter = type(name) == 'string' and name:match('^MeasureIOType([A-Z])$')
            assert(letter, 'unexpected inventory measure: ' .. tostring(name))
            if f.types[letter] == nil then return nil end
            return { GetValue = function() return f.types[letter] end }
        end
        function skin:Bang(command, ...)
            local args = { ... }
            f.calls[#f.calls + 1] = { command = command, args = args }
            if command == '!SetOption' then
                assert(select('#', ...) == 3, 'display update must not add a config argument')
                assert(type(args[1]) == 'string', 'meter name must be a string')
                local textOption = args[2] == 'Text' or args[2] == 'ToolTipText'
                local drivePart = args[1]:match('^MeterIOSettingsDrive[A-Z]$')
                    or args[1]:match('^MeterIOSettingsDrive[A-Z]Label$')
                local quotaPart = args[1] == 'MeterIOSettingsQuotaLabel'
                    or args[1] == 'MeterIOSettingsQuotaValue'
                local limitArrow = args[1] == 'MeterIOSettingsLimitDecrease' or args[1] == 'MeterIOSettingsLimitIncrease'
                local arrowOption = limitArrow and (args[2] == 'FontColor' or args[2] == 'MouseActionCursor' or args[2] == 'LeftMouseUpAction')
                local inputOption = args[1] == 'MeasureIOSettingsNumberInput' and args[2] == 'Parameter'
                local geometryOption = args[1]:match('^MeterIOSettings') and args[2] == 'Y'
                    or (drivePart or quotaPart) and args[2] == 'Hidden'
                    or args[1] == 'MeterBounds' and args[2] == 'H'
                assert(textOption or geometryOption or arrowOption or inputOption, 'unsupported settings option mutation')
                assert(type(args[3]) == 'string', 'display and geometry values must be strings')
                f.options[args[1]] = f.options[args[1]] or {}
                f.options[args[1]][args[2]] = args[3]
            elseif command == '!SetVariable' then
                assert(allowed[args[1]] or args[1] == 'PanelHeightPx',
                    'non-IO or unsupported variable mutation')
                assert(type(args[2]) == 'string', 'variable value must be a string')
                assert(select('#', ...) == 2, 'variable update must target only this settings skin')
                vars[args[1]] = args[2]
            elseif command == '!SetVariableGroup' then
                assert(select('#', ...) == 3 and args[1] == 'IODriveNames' and args[3] == 'ParallaxIO',
                    'name publication escaped the IO variable/group')
                assert(args[2] == 'letters' or args[2] == 'volume' or args[2] == 'model' or args[2] == 'both',
                    'name publication must use an allowlisted mode')
                f.namePublishes[#f.namePublishes + 1] = args[2]
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
                assert(args[2] == 'IO-Disk.ini',
                    'activation must open the Drive I/O entrypoint')
                f.activations[#f.activations + 1] = { config = args[1], file = args[2] }
            elseif command == '!DeactivateConfig' then
                assert(select('#', ...) == 0, 'close must affect only its own settings config')
                f.closes[#f.closes + 1] = true
            elseif command == '!UpdateMeterGroup' then
                assert(select('#', ...) == 1 and args[1] == 'IOSettingsUI',
                    'meter update escaped the IO settings view')
            elseif command == '!UpdateMeasureGroup' then
                assert(select('#', ...) == 1 and args[1] == 'IOInventory',
                    'inventory update escaped the local IO inventory group')
                f.inventoryRefreshes[#f.inventoryRefreshes + 1] = args[1]
            elseif command == '!CommandMeasure' then
                if select('#', ...) == 2 then
                    assert(args[2] == 'Run', 'helper dispatch must use the fixed Run command')
                    if args[1] == 'MeasureIOSettingsNumberInput' then
                        f.inputRuns[#f.inputRuns + 1] = args[1]
                    else
                        assert(args[1] == 'MeasureIOModelQuery', 'unexpected local helper target')
                        f.modelQueries[#f.modelQueries + 1] = { target = args[1], action = args[2] }
                    end
                else
                    assert(select('#', ...) == 3 and args[1] == 'MeasureIO' and args[3] == 'Parallax\\IO'
                        and (args[2] == 'ApplyNamesMode()' or args[2] == 'RefreshNamesInventory()'),
                        'name update must use a fixed callback in the monitor config')
                    f.mainNamesCalls[#f.mainNamesCalls + 1] = args[2]
                end
            elseif command == '!UpdateMeasure' then
                assert(select('#', ...) == 1 and args[1] == 'MeasureIOSettingsNumberInput',
                    'numeric input must update only its fixed local result measure')
                f.inputUpdates[#f.inputUpdates + 1] = args[1]
            elseif command == '!UpdateMeter' then
                assert(select('#', ...) == 1 and (args[1] == 'MeterBounds' or args[1] == 'MeterPanel'),
                    'meter update escaped the settings bounds and panel')
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
            require = forbidden, loadfile = forbidden, loadstring = forbidden },
            { __index = _G })
        env._G = env
        env.dofile = function(path)
            assert(path == resourceRoot .. 'Modules\\IO\\Names.lua', 'settings loaded an unexpected script')
            local namesPath, replaced = productionPath:gsub('Settings%.lua$', 'Names.lua')
            assert(replaced == 1, 'production settings path must identify Settings.lua')
            local namesChunk, namesError = loadfile(namesPath)
            assert(namesChunk, namesError)
            setfenv(namesChunk, env)
            return namesChunk()
        end
        local chunk, loadError = loadfile(productionPath)
        assert(chunk, loadError)
        setfenv(chunk, env)
        chunk()
        for _, name in ipairs({ 'Initialize', 'Update', 'Toggle', 'CycleUnits',
            'CycleLimit', 'Open', 'Apply', 'Close', 'ToggleDrive', 'SelectAllDrives',
            'SelectCDrive', 'ToggleAllDrives', 'CycleGraphMode', 'RefreshInventory',
            'CycleNamesMode', 'NamesReady', 'BeginLimitInput', 'FinishLimitInput' }) do
            assert(type(env[name]) == 'function', 'settings entrypoint missing: ' .. name)
        end
        f.env = env
        function f:clear()
            self.calls, self.writes, self.refreshes, self.activations, self.closes = {}, {}, {}, {}, {}
            self.inventoryRefreshes = {}
            self.modelQueries = {}
            self.namePublishes, self.mainNamesCalls = {}, {}
            self.inputRuns, self.inputUpdates = {}, {}
        end
        function f:reload() return fixture(self.persisted, self.types, nil, { labels = self.labels, modelOutput = self.modelOutput }) end
        function f:text(meter) return (self.options[meter] or {}).Text end
        function f:tip(meter) return (self.options[meter] or {}).ToolTipText end
        if initialize ~= false then
            env.Initialize()
            env.Update()
        end
        return f
    end

    local function idle(f)
        equal(#f.writes, 0, 'unexpected persistence')
        equal(#f.refreshes, 0, 'unexpected refresh')
        equal(#f.activations, 0, 'unexpected activation')
        equal(#f.closes, 0, 'unexpected close')
        equal(#f.inventoryRefreshes, 0, 'unexpected forced inventory refresh')
        equal(#f.modelQueries, 0, 'unexpected model query')
        equal(#f.namePublishes, 0, 'unexpected name publication')
        equal(#f.mainNamesCalls, 0, 'unexpected monitor names callback')
        equal(#f.inputRuns, 0, 'unexpected numeric editor process')
        equal(#f.inputUpdates, 0, 'unexpected numeric input update')
    end

    local function saved(f, expected)
        local count, seen, lastWrite, refreshPosition, publishPosition, callbackPosition = 0, {}, 0, nil, nil, nil
        for _ in pairs(expected) do count = count + 1 end
        equal(#f.writes, count, 'write count')
        for _, write in ipairs(f.writes) do
            check(expected[write.key] ~= nil, 'unexpected written key: ' .. write.key)
            check(not seen[write.key], 'same key written twice in one action')
            seen[write.key] = true
            equal(write.value, expected[write.key], write.key)
            equal(f.persisted[write.key], expected[write.key], 'persisted ' .. write.key)
        end
        for index, call in ipairs(f.calls) do
            if call.command == '!WriteKeyValue' then lastWrite = index end
            if call.command == '!RefreshGroup' then refreshPosition = index end
            if call.command == '!SetVariableGroup' then publishPosition = index end
            if call.command == '!CommandMeasure' and call.args[1] == 'MeasureIO' then callbackPosition = index end
        end
        if count == 1 and expected.IODriveNames then
            equal(#f.refreshes, 0, 'changing only names must preserve monitor history')
            equal(#f.namePublishes, 1, 'one name publication per edit')
            equal(f.namePublishes[1], expected.IODriveNames)
            equal(#f.mainNamesCalls, 1, 'one main-name update per edit')
            equal(f.mainNamesCalls[1], 'ApplyNamesMode()')
            check(publishPosition > lastWrite and callbackPosition > publishPosition,
                'save and publish must finish before the main name callback')
        else
            equal(#f.refreshes, 1, 'one IO refresh per non-name edit')
            equal(f.refreshes[1].command, '!RefreshGroup')
            equal(f.refreshes[1].target, 'ParallaxIO')
            equal(#f.namePublishes, 0, 'unrelated edit must not publish names')
            equal(#f.mainNamesCalls, 0, 'unrelated edit must not dispatch a names callback')
            check(refreshPosition > lastWrite, 'refresh happened before the save batch completed')
        end
        equal(#f.activations, 0, 'save must not open Drive I/O')
        equal(#f.closes, 0, 'save must not close settings')
        equal(#f.inventoryRefreshes, 0, 'save must not force inventory collection')
    end

    local function grid(f, selected)
        for code = 65, 90 do
            local letter = string.char(code)
            local meter = 'MeterIOSettingsDrive' .. letter
            local chosen = selected:find(letter, 1, true) ~= nil
            local kind = f.types[letter]
            local detected = type(kind) == 'number' and kind >= 3 and kind <= 7 and kind % 1 == 0
            local visible = chosen or detected
            for _, target in ipairs({ meter, meter .. 'Label' }) do
                -- The INI declares every drive label/value pair hidden before render.
                local hidden = tonumber((f.options[target] or {}).Hidden or '1')
                equal(hidden, visible and 0 or 1, 'drive field visibility ' .. target)
            end
            if visible then
                equal(f:text(meter), chosen and 'On' or 'Off', 'drive choice ' .. letter)
                local tip = f:tip(meter)
                check(type(tip) == 'string', 'drive tooltip missing: ' .. letter)
                tip = tip:lower()
                local unselected = tip:find('unselected', 1, true) or tip:find('not selected', 1, true)
                if chosen then
                    check(tip:find('selected', 1, true) and not unselected, 'selected tooltip: ' .. letter)
                else
                    check(unselected, 'unselected tooltip: ' .. letter)
                end
                check(tip:find(detected and 'detected' or 'unavailable', 1, true),
                    'inventory tooltip: ' .. letter)
            end
        end
        local summary = f:text('MeterIOSettingsDriveValue')
        check(type(summary) == 'string' and summary ~= '', 'drive selection summary missing')
        equal(f:text('MeterIOSettingsAllValue'), f.persisted.IODiskDrives == 'all' and 'On' or 'Off',
            'All drives toggle state')
    end

    local function numericOption(f, meter, key)
        local value = tonumber((f.options[meter] or {})[key])
        check(value ~= nil, 'missing numeric option ' .. meter .. '.' .. key)
        return value
    end

    local function quotaLayout(f, collapsed)
        local visible = 0
        for code = 65, 90 do
            if numericOption(f, 'MeterIOSettingsDrive' .. string.char(code), 'Hidden') == 0 then
                visible = visible + 1
            end
        end
        local scale, inset = tonumber(f.vars.Scale), tonumber(f.vars.Inset)
        local cursor = 184 + 28 * visible
        for _, part in ipairs({ {'Label', 150}, {'Value', 148} }) do
            local meter = 'MeterIOSettingsQuota' .. part[1]
            equal(numericOption(f, meter, 'Hidden'), collapsed and 1 or 0, meter .. ' visibility')
            equal(numericOption(f, meter, 'Y'), collapsed and 0 or inset + (cursor + part[2]) * scale,
                meter .. ' restored position')
        end
        -- Hidden=1 is Rainmeter's no-hit-target state. The mock checks both real
        -- label/value options; native captures verify actual rendering separately.
        for _, name in ipairs({ 'Title', 'Close', 'DrivesSection', 'DrivesRule',
            'AllLabel', 'AllValue', 'NamesLabel', 'NamesValue', 'COnly', 'DriveValue', 'InventoryRefresh',
            'GraphSection', 'GraphRule', 'GraphLabel', 'GraphValue',
            'UnitsLabel', 'UnitsValue', 'LimitLabel', 'LimitValue',
            'CapacitySection', 'CapacityRule' }) do
            local meter = 'MeterIOSettings' .. name
            equal(tonumber((f.options[meter] or {}).Hidden or '0'), 0,
                'quota collapse hid unrelated control ' .. meter)
        end
        local quota = f.persisted.IODiskQuota
        equal(f.vars.IODiskQuota, quota, 'quota value changed during layout')
        equal(f:text('MeterIOSettingsQuotaValue'), quota == '1' and 'On' or quota == '0' and 'Off' or 'Check',
            'quota display changed during collapse')
        equal(f.persisted.PanelHeight, '400', 'saved monitor height changed')
        return visible
    end

    test('explicit none collapses only quota and reclaims one row at every scale', function()
        for _, scale in ipairs({ .75, 1, 1.25, 1.5, 2 }) do
            for _, quota in ipairs({ '0', '1', 'custom quota' }) do
                -- The empty inventory deliberately leaves all enabled: absence
                -- must not be confused with the explicit saved none preference.
                for _, types in ipairs({ { C = 1 }, { A = 3, C = 4, F = 6 } }) do
                    local none = fixture({ Scale = tostring(scale), IODiskDrives = 'none', IODiskQuota = quota }, types)
                    local all = fixture({ Scale = tostring(scale), IODiskDrives = 'all', IODiskQuota = quota }, types)
                    equal(quotaLayout(none, true), quotaLayout(all, false), 'comparison must have equal visible drive counts')
                    for _, name in ipairs({ 'Open', 'EditFile', 'Reload', 'ProviderHint', 'Notice', 'Independence' }) do
                        local meter = 'MeterIOSettings' .. name
                        equal(numericOption(all, meter, 'Y') - numericOption(none, meter, 'Y'), 28 * scale,
                            meter .. ' must reclaim exactly one row')
                    end
                    for _, name in ipairs({ 'GraphSection', 'GraphRule', 'GraphLabel', 'GraphValue',
                        'UnitsLabel', 'UnitsValue', 'LimitLabel', 'LimitValue', 'CapacitySection', 'CapacityRule' }) do
                        local meter = 'MeterIOSettings' .. name
                        equal(numericOption(none, meter, 'Y'), numericOption(all, meter, 'Y'),
                            'quota collapse moved preceding control ' .. meter)
                    end
                    equal(tonumber(all.vars.PanelHeightPx) - tonumber(none.vars.PanelHeightPx), 28 * scale,
                        'painted panel must reclaim exactly one row')
                    equal(numericOption(all, 'MeterBounds', 'H') - numericOption(none, 'MeterBounds', 'H'), 28 * scale,
                        'window bounds must reclaim exactly one row')
                    idle(none)
                    idle(all)
                end
            end
        end
    end)

    test('none recovers through C all and an offline individual drive without changing quota', function()
        for _, scale in ipairs({ .75, 1, 1.25, 1.5, 2 }) do
            for _, quota in ipairs({ '0', '1', 'custom quota' }) do
                for _, target in ipairs({ 'C', 'all', 'Z' }) do
                    local f = fixture({ Scale = tostring(scale), IODiskDrives = 'none', IODiskQuota = quota })
                    quotaLayout(f, true)
                    local collapsedPanel = f.vars.PanelHeightPx
                    local collapsedCommands = numericOption(f, 'MeterIOSettingsOpen', 'Y')
                    if target == 'C' then f.env.SelectCDrive()
                    elseif target == 'all' then f.env.SelectAllDrives()
                    else f.env.ToggleDrive('Z') end
                    saved(f, { IODiskDrives = target })
                    quotaLayout(f, false)
                    equal(f.persisted.IODiskQuota, quota, 'drive recovery rewrote quota')
                    if target == 'Z' then
                        equal(numericOption(f, 'MeterIOSettingsDriveZ', 'Hidden'), 0, 'selected offline drive must remain visible')
                        check(f:tip('MeterIOSettingsDriveZ'):lower():find('unavailable', 1, true), 'offline recovery must be honest')
                    end
                    local reopened = f:reload()
                    quotaLayout(reopened, false)
                    idle(reopened)
                    equal(reopened.persisted.IODiskQuota, quota, 'reopening lost the saved quota')
                    f:clear()
                    if target == 'all' then f.env.ToggleAllDrives()
                    else f.env.ToggleDrive(target) end
                    saved(f, { IODiskDrives = 'none' })
                    quotaLayout(f, true)
                    equal(f.vars.PanelHeightPx, collapsedPanel, 'round trip did not restore compact panel height')
                    equal(numericOption(f, 'MeterIOSettingsOpen', 'Y'), collapsedCommands, 'round trip left a blank quota row')
                    equal(f.persisted.IODiskQuota, quota, 'collapse rewrote quota')
                end
            end
        end
    end)

    test('none keeps graph units cap and inventory recovery active while quota remains hidden', function()
        local f = fixture({ IODiskDrives = 'none', IOGraphMode = 'c', IODiskQuota = 'custom quota' })
        quotaLayout(f, true)
        f.env.CycleGraphMode()
        saved(f, { IOGraphMode = 'combined' })
        quotaLayout(f, true)
        f:clear()
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bits' })
        quotaLayout(f, true)
        f:clear()
        f.env.CycleLimit(1)
        saved(f, { IODiskMaxMiBs = '1000' })
        quotaLayout(f, true)
        f:clear()
        f.types.Z = 4
        f.env.RefreshInventory()
        quotaLayout(f, true)
        equal(#f.inventoryRefreshes, 1, 'recovery should refresh inventory once')
        equal(#f.writes, 0, 'inventory recovery must not persist')
        equal(#f.refreshes, 0, 'inventory recovery must not refresh the monitor')
        equal(f.persisted.IODiskDrives, 'none', 'new detection changed explicit selection')
        equal(f.persisted.IODiskQuota, 'custom quota', 'independent controls changed quota')
    end)

    test('initialization and repeated view updates never persist or refresh', function()
        local f = fixture()
        idle(f)
        equal(f.options.MeterIOSettingsLimitValue.Text, '524.288', 'cap display must convert to decimal MB/s with editor precision')
        check(f.options.MeterIOSettingsLimitValue.ToolTipText:find('524.288 MB/s', 1, true), 'tooltip must retain the precise cap conversion')
        equal(f.persisted.IODiskMaxMiBs, '500', 'display conversion must preserve the stored cap')
        grid(f, 'C')
        equal(f:text('MeterIOSettingsGraphValue'), 'Combined')
        equal(f:text('MeterIOSettingsNamesValue'), 'Volume labels')
        equal(f:text('MeterIOSettingsDriveCLabel'), 'C: System')
        for _ = 1, 5 do f.env.Update() end
        idle(f)
        check(next(f.options) ~= nil, 'settings view never rendered')
    end)

    test('missing and invalid name modes display volume labels without changing saved values', function()
        for _, mode in ipairs({ '', 'Volume', 'both ', '[!Quit]', '#Names#', 'unknown' }) do
            local f = fixture({ IODriveNames = mode })
            equal(f:text('MeterIOSettingsNamesValue'), 'Volume labels')
            equal(f:text('MeterIOSettingsDriveCLabel'), 'C: System')
            equal(f.persisted.IODriveNames, mode)
            f.env.NamesReady()
            f.env.Update()
            idle(f)
        end
        local absent = fixture(nil, nil, false)
        absent.vars.IODriveNames, absent.persisted.IODriveNames = nil, nil
        absent.env.Initialize()
        absent.env.Update()
        equal(absent:text('MeterIOSettingsNamesValue'), 'Volume labels')
        equal(absent:text('MeterIOSettingsDriveCLabel'), 'C: System')
        equal(absent.persisted.IODriveNames, nil)
        idle(absent)
    end)

    test('name choices cycle through the four modes and query only model modes', function()
        local f = fixture({ IODriveNames = 'letters', IODiskDrives = 'none', IODiskQuota = 'custom quota', IOGraphMode = 'c' })
        equal(f:text('MeterIOSettingsDriveCLabel'), 'C:')
        idle(f)
        for _, case in ipairs({ { 'volume', 'Volume labels', 0 }, { 'model', 'Drive models', 1 },
            { 'both', 'Both', 1 }, { 'letters', 'Letters only', 0 } }) do
            f:clear()
            equal(f.env.CycleNamesMode(), true)
            saved(f, { IODriveNames = case[1] })
            equal(f:text('MeterIOSettingsNamesValue'), case[2])
            equal(#f.modelQueries, case[3], 'query count for chosen name mode')
            equal(f.persisted.IODiskDrives, 'none', 'name mode changed drive selection')
            equal(f.persisted.IODiskQuota, 'custom quota', 'name mode changed hidden quota')
            equal(f.persisted.IOGraphMode, 'c', 'name mode changed independent C graph')
            quotaLayout(f, true)
            f:clear()
            for _ = 1, 3 do f.env.Update() end
            equal(f.env.NamesReady(), true)
            idle(f)
        end
    end)

    test('initial model modes query once and render actual cached names on completion', function()
        local packet = 'IO_MODELS_V1\nOK\nC|Fixture SSD\nD|External SSD'
        for _, case in ipairs({ { 'model', 'C: Fixture SSD' }, { 'both', 'C: System / Fixture SSD' } }) do
            local f = fixture({ IODriveNames = case[1] }, { D = 3 }, nil,
                { labels = { D = 'Backup' }, modelOutput = packet })
            equal(#f.modelQueries, 1, 'load must dispatch one model query')
            equal(f.modelQueries[1].target, 'MeasureIOModelQuery')
            equal(f.modelQueries[1].action, 'Run')
            equal(f:text('MeterIOSettingsDriveCLabel'), case[2])
            check(f:tip('MeterIOSettingsDriveDLabel'):find('External SSD', 1, true), 'drive metadata tooltip missing')
            f:clear()
            f.modelOutput = 'IO_MODELS_V1\nOK\nC|Updated SSD'
            equal(f.env.NamesReady(), true)
            check(f:text('MeterIOSettingsDriveCLabel'):find('Updated SSD', 1, true), 'completion did not render the new cached name')
            for _ = 1, 3 do f.env.Update() end
            idle(f)
            equal(f.persisted.IODriveNames, case[1], 'model completion rewrote name mode')
            local reloaded = f:reload()
            equal(#reloaded.modelQueries, 1, 'new settings instance must perform its own requested model query')
            equal(#reloaded.writes, 0, 'reopening names mode must not persist')
            equal(reloaded.persisted.IODriveNames, case[1])
        end
    end)

    test('name fallbacks remain explicit for unlabeled missing and unmapped drives', function()
        local volume = fixture(nil, nil, nil, { labels = { C = '' } })
        equal(volume:text('MeterIOSettingsDriveCLabel'), 'C: No label / unavailable')
        idle(volume)
        local model = fixture({ IODriveNames = 'model' }, nil, nil,
            { modelOutput = 'IO_MODELS_V1\nUNAVAILABLE' })
        equal(model:text('MeterIOSettingsDriveCLabel'), 'C: Model unavailable')
        check(model:tip('MeterIOSettingsDriveCLabel'):find('Model unavailable', 1, true), 'unknown model tooltip missing')
        local both = fixture({ IODriveNames = 'both', IODiskDrives = 'Z' }, { Z = 1 }, nil,
            { labels = { Z = 'Old volume label' }, modelOutput = 'IO_MODELS_V1\nOK\nZ|Old device model' })
        equal(both:text('MeterIOSettingsDriveZLabel'), 'Z: No label / unavailable; Model unavailable')
        check(not both:tip('MeterIOSettingsDriveZLabel'):find('Old device model', 1, true), 'offline drive kept a cached model')
        equal(numericOption(both, 'MeterIOSettingsDriveZ', 'Hidden'), 0, 'selected unavailable drive should stay visible')
        equal(#both.writes, 0)
    end)

    test('drive metadata is normalized without becoming commands or persisted preferences', function()
        local dirty = 'Projects#Scale#[!Quit]\t\r\n%1|extra'
        local f = fixture({ IODriveNames = 'both' }, nil, nil,
            { labels = { C = dirty }, modelOutput = 'IO_MODELS_V1\nOK\nC|Bad[!Quit]' })
        f:clear()
        f.env.NamesReady()
        check(f:text('MeterIOSettingsDriveCLabel'):find('Projects', 1, true), 'safe label text was lost')
        for _, meter in ipairs({ 'MeterIOSettingsDriveC', 'MeterIOSettingsDriveCLabel' }) do
            for _, key in ipairs({ 'Text', 'ToolTipText' }) do
                local value = f.options[meter][key]
                check(not value:find('[%c#%%%[%]|]'), 'metadata expansion delimiters in ' .. meter .. '.' .. key)
            end
        end
        idle(f)
        equal(f.persisted.IODriveNames, 'both')
    end)

    test('explicit drive refresh queries models only for the selected model modes', function()
        for _, mode in ipairs({ 'letters', 'volume', 'model', 'both' }) do
            local f = fixture({ IODriveNames = mode })
            f:clear()
            equal(f.env.RefreshInventory(), true)
            equal(#f.inventoryRefreshes, 1)
            equal(f.calls[1].command, '!UpdateMeasureGroup', 'inventory must update before requesting model metadata')
            equal(#f.modelQueries, (mode == 'model' or mode == 'both') and 1 or 0)
            equal(#f.mainNamesCalls, 1, 'explicit refresh must update the main metadata cache once')
            equal(f.mainNamesCalls[1], 'RefreshNamesInventory()')
            equal(#f.namePublishes, 0, 'refresh must preserve the existing main name mode')
            equal(#f.writes, 0)
            equal(#f.refreshes, 0)
            equal(f.persisted.IODriveNames, mode)
            f:clear()
            f.env.NamesReady()
            idle(f)
        end
    end)

    test('name callbacks before initialization have no side effects', function()
        local f = fixture(nil, nil, false)
        equal(f.env.CycleNamesMode(), false)
        equal(f.env.NamesReady(), false)
        equal(#f.calls, 0)
        idle(f)
    end)

    test('opening custom preferences preserves exact values until an explicit edit', function()
        local custom = { IODiskUnits = 'CUSTOM', IODiskMaxMiBs = '737.125', IODiskQuota = 'custom',
            IODiskDrives = 'invalid drives', IOGraphMode = 'invalid graph' }
        local f = fixture(custom)
        f.env.Update()
        idle(f)
        for key, value in pairs(custom) do equal(f.persisted[key], value, key) end
        f:clear()
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '1' })
        equal(f.persisted.IODiskUnits, custom.IODiskUnits, 'untouched units')
        equal(f.persisted.IODiskMaxMiBs, custom.IODiskMaxMiBs, 'untouched graph limit')
        equal(f.persisted.IODiskDrives, custom.IODiskDrives, 'untouched drive selection')
        equal(f.persisted.IOGraphMode, custom.IOGraphMode, 'untouched graph mode')
    end)

    test('disk quota toggles and saves independently', function()
        local f = fixture()
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '1' })
        f:clear()
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '0' })
    end)

    test('toggle cannot act as an arbitrary settings writer', function()
        local f = fixture()
        for _, key in ipairs({ 'IODiskUnits', 'IODiskDrives', 'IOGraphMode', 'IODriveNames',
            'IODiskMaxMiBs', 'Scale', 'Theme', 'Columns', 'ParallaxIO', '',
            'IODiskQuota][!Quit]', {}, false, 0, math.huge }) do
            f.env.Toggle(key)
        end
        f.env.Toggle(nil)
        idle(f)
        equal(f.persisted.IODiskQuota, '0')
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

    test('the units control repairs only its own custom choice', function()
        local f = fixture({ IODiskUnits = 'custom units', IODiskQuota = 'custom quota',
            IODiskMaxMiBs = '737.125' })
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bytes' })
        equal(f.persisted.IODiskQuota, 'custom quota')
        equal(f.persisted.IODiskMaxMiBs, '737.125')
    end)

    test('canonical drive selections render their exact selection without writes', function()
        for _, case in ipairs({ {'C', 'C'}, {'A,C,Z', 'ACZ'}, {'all', 'ACF'}, {'none', ''} }) do
            local f = fixture({ IODiskDrives = case[1] }, { A = 3, F = 6 })
            grid(f, case[2])
            equal(f.persisted.IODiskDrives, case[1])
            idle(f)
        end
    end)

    test('missing or malformed drive preferences use C without rewriting the file', function()
        for _, value in ipairs({ '', ' ', 'c', 'C:', 'C,A', 'C,C', 'A,,C', ',C', 'C,',
            'A, C', 'A,C ', 'All', 'NONE', 'C;D', 'C][!Quit]', '#C#', 'C\n' }) do
            local f = fixture({ IODiskDrives = value })
            grid(f, 'C')
            quotaLayout(f, false)
            equal(f.persisted.IODiskDrives, value)
            idle(f)
        end
        local absent = fixture(nil, nil, false)
        absent.vars.IODiskDrives, absent.persisted.IODiskDrives = nil, nil
        absent.env.Initialize()
        absent.env.Update()
        grid(absent, 'C')
        quotaLayout(absent, false)
        equal(absent.persisted.IODiskDrives, nil)
        idle(absent)
    end)

    test('all selects only present native drive types including optical drives', function()
        local f = fixture({ IODiskDrives = 'all' }, {
            A = 3, B = 4, C = 5, D = 6, E = 7,
            F = 0, G = 1, H = 2, I = 8, J = -1, K = math.huge,
            L = 0/0, M = '4', N = false, O = 4.5
        })
        f.types.P = nil
        f.env.Update()
        grid(f, 'ABCDE')
        equal(f.persisted.IODiskDrives, 'all')
        idle(f)
    end)

    test('drive toggles save sorted letters and allow selected offline drives', function()
        local f = fixture()
        f.env.ToggleDrive('Z')
        saved(f, { IODiskDrives = 'C,Z' })
        grid(f, 'CZ')
        f:clear()
        f.env.ToggleDrive('A')
        saved(f, { IODiskDrives = 'A,C,Z' })
        f:clear()
        f.env.ToggleDrive('C')
        saved(f, { IODiskDrives = 'A,Z' })
        grid(f, 'AZ')
        equal(f.persisted.IOGraphMode, 'combined', 'drive selection must preserve graph mode')
    end)

    test('toggling the last selected drive saves none and can select again', function()
        local f = fixture()
        f.env.ToggleDrive('C')
        saved(f, { IODiskDrives = 'none' })
        grid(f, '')
        f:clear()
        f.env.ToggleDrive('Z')
        saved(f, { IODiskDrives = 'Z' })
        grid(f, 'Z')
    end)

    test('a toggle in all materializes detected drives before changing the clicked letter', function()
        local remove = fixture({ IODiskDrives = 'all' }, { A = 3, F = 6 })
        remove.env.ToggleDrive('C')
        saved(remove, { IODiskDrives = 'A,F' })
        grid(remove, 'AF')
        local add = fixture({ IODiskDrives = 'all' }, { A = 3, F = 6 })
        add.env.ToggleDrive('Z')
        saved(add, { IODiskDrives = 'A,C,F,Z' })
        grid(add, 'ACFZ')
        local empty = fixture({ IODiskDrives = 'all' }, { C = 1 })
        empty.env.ToggleDrive('C')
        saved(empty, { IODiskDrives = 'C' })
        grid(empty, 'C')
    end)

    test('All and C selection actions persist only the drive preference', function()
        local f = fixture(nil, { A = 3, C = 1, F = 6 })
        f.env.SelectAllDrives()
        saved(f, { IODiskDrives = 'all' })
        grid(f, 'AF')
        f:clear()
        f.env.SelectCDrive()
        saved(f, { IODiskDrives = 'C' })
        grid(f, 'C')
    end)

    test('the All drives toggle switches all to none and explicit selections to all', function()
        local f = fixture({ IODiskDrives = 'C,Z' }, { A = 3, F = 6 })
        f.env.ToggleAllDrives()
        saved(f, { IODiskDrives = 'all' })
        grid(f, 'ACF')
        f:clear()
        f.env.ToggleAllDrives()
        saved(f, { IODiskDrives = 'none' })
        grid(f, '')
        f:clear()
        f.env.ToggleAllDrives()
        saved(f, { IODiskDrives = 'all' })
        grid(f, 'ACF')
    end)

    test('drive callbacks reject malformed and action-shaped letters', function()
        local f = fixture()
        for _, letter in ipairs({ '', 'c', 'C:', 'CC', ' C', 'C ', 'C,D', 'all', 'none',
            'C][!Quit]', '#C#', 'C\n', {}, false, 1, math.huge }) do
            f.env.ToggleDrive(letter)
        end
        f.env.ToggleDrive(nil)
        equal(f.persisted.IODiskDrives, 'C')
        idle(f)
    end)

    test('stored graph modes display their matching labels without writes', function()
        for _, case in ipairs({ {'combined', 'Combined'}, {'overlay', 'Overlay'}, {'c', 'C: only'}, {'split', 'Split + / -'} }) do
            local f = fixture({ IOGraphMode = case[1] })
            equal(f:text('MeterIOSettingsGraphValue'), case[2])
            equal(f.persisted.IOGraphMode, case[1])
            idle(f)
        end
    end)

    test('missing or malformed graph modes use Combined until explicitly changed', function()
        for _, value in ipairs({ '', 'Combined', 'C', 'overlay ', 'bad', '#mode#', '[!Quit]' }) do
            local f = fixture({ IOGraphMode = value })
            equal(f:text('MeterIOSettingsGraphValue'), 'Combined')
            equal(f.persisted.IOGraphMode, value)
            idle(f)
            f.env.CycleGraphMode()
            saved(f, { IOGraphMode = 'overlay' })
        end
        local absent = fixture(nil, nil, false)
        absent.vars.IOGraphMode, absent.persisted.IOGraphMode = nil, nil
        absent.env.Initialize()
        absent.env.Update()
        equal(absent:text('MeterIOSettingsGraphValue'), 'Combined')
        equal(absent.persisted.IOGraphMode, nil)
        idle(absent)
    end)

    test('graph modes cycle Combined to Overlay to Split to C only and back', function()
        local f = fixture({ IODiskDrives = 'A,Z' })
        for _, case in ipairs({ {'overlay', 'Overlay'}, {'split', 'Split + / -'}, {'c', 'C: only'}, {'combined', 'Combined'} }) do
            f:clear()
            f.env.CycleGraphMode()
            saved(f, { IOGraphMode = case[1] })
            equal(f:text('MeterIOSettingsGraphValue'), case[2])
            equal(f.persisted.IODiskDrives, 'A,Z', 'graph mode must preserve selected drives')
        end
    end)

    test('categorical arrows wrap backward and reject unsupported directions', function()
        local graph = fixture({ IOGraphMode = 'c' })
        for _, value in ipairs({ 'split', 'overlay', 'combined', 'c' }) do
            graph:clear()
            equal(graph.env.CycleGraphMode(-1), true)
            saved(graph, { IOGraphMode = value })
        end
        local names = fixture({ IODriveNames = 'letters' })
        for _, value in ipairs({ 'both', 'model', 'volume', 'letters' }) do
            names:clear()
            equal(names.env.CycleNamesMode(-1), true)
            saved(names, { IODriveNames = value })
            equal(#names.modelQueries, (value == 'both' or value == 'model') and 1 or 0)
        end
        local units = fixture()
        equal(units.env.CycleUnits(-1), true)
        saved(units, { IODiskUnits = 'bits' })
        units:clear()
        equal(units.env.CycleUnits(-1), true)
        saved(units, { IODiskUnits = 'bytes' })
        for _, control in ipairs({ 'CycleGraphMode', 'CycleNamesMode', 'CycleUnits' }) do
            local f = fixture()
            for _, direction in ipairs({ 0, 2, -2, .5, '1', {}, false, math.huge, 0/0 }) do
                equal(f.env[control](direction), false)
            end
            idle(f)
        end
    end)

    test('inventory refresh updates cached names in the monitor without saving or refreshing skins', function()
        local f = fixture({ IODiskDrives = 'all' })
        f:clear()
        f.types.A, f.types.C, f.types.F = 3, 1, 6
        equal(f.env.RefreshInventory(), true)
        equal(#f.inventoryRefreshes, 1)
        equal(f.calls[1].command, '!UpdateMeasureGroup', 'inventory must update before rendering')
        equal(f.inventoryRefreshes[1], 'IOInventory')
        equal(#f.mainNamesCalls, 1)
        equal(f.mainNamesCalls[1], 'RefreshNamesInventory()')
        equal(#f.writes, 0)
        equal(#f.refreshes, 0)
        equal(#f.activations, 0)
        equal(#f.closes, 0)
        equal(f.persisted.IODiskDrives, 'all')
        grid(f, 'AF')
        f:clear()
        f.types.B = 7
        f.env.Update()
        grid(f, 'ABF')
        idle(f)
    end)

    test('inventory refresh before initialization is a side-effect-free false result', function()
        local f = fixture(nil, nil, false)
        equal(f.env.RefreshInventory(), false)
        equal(#f.calls, 0)
        idle(f)
    end)

    test('graph limit preset arrows advance and reverse without wrapping or writing at endpoints', function()
        for index, level in ipairs(levels) do
            for _, step in ipairs({ -1, 1 }) do
                local f = fixture({ IODiskMaxMiBs = tostring(level) })
                local nextIndex = index + step
                if nextIndex < 1 or nextIndex > #levels then
                    equal(f.env.CycleLimit(step), false)
                    idle(f)
                    local meter = step == -1 and 'MeterIOSettingsLimitDecrease' or 'MeterIOSettingsLimitIncrease'
                    equal(f.options[meter].LeftMouseUpAction, '', 'endpoint arrow must have no click action')
                    equal(f.options[meter].MouseActionCursor, '0')
                else
                    f.env.CycleLimit(step)
                    saved(f, { IODiskMaxMiBs = tostring(levels[nextIndex]) })
                end
            end
        end
    end)

    test('custom finite graph limits move to the next greater or smaller preset', function()
        for _, case in ipairs({ {'75', 1, '100'}, {'75', -1, '50'},
            {'737.125', 1, '1000'}, {'737.125', -1, '500'},
            {'5', 1, '10'}, {'6000', -1, '5000'} }) do
            local f = fixture({ IODiskMaxMiBs = case[1] })
            idle(f)
            equal(f.persisted.IODiskMaxMiBs, case[1])
            f.env.CycleLimit(case[2])
            saved(f, { IODiskMaxMiBs = case[3] })
        end
        for _, case in ipairs({ { '5', -1 }, { '6000', 1 } }) do
            local f = fixture({ IODiskMaxMiBs = case[1] })
            equal(f.env.CycleLimit(case[2]), false)
            equal(f.persisted.IODiskMaxMiBs, case[1])
            idle(f)
        end
    end)

    test('malformed or nonfinite graph limits remain untouched with disabled arrows', function()
        for _, value in ipairs({ '', 'bad', '1e309', '-1e309', 'nan', '0/0',
            '[!Quit]', math.huge, -math.huge, 0/0 }) do
            for _, step in ipairs({ -1, 1 }) do
                local f = fixture({ IODiskMaxMiBs = value })
                idle(f)
                equal(f.env.CycleLimit(step), false)
                equal(f.options.MeterIOSettingsLimitDecrease.LeftMouseUpAction, '')
                equal(f.options.MeterIOSettingsLimitIncrease.LeftMouseUpAction, '')
                check(f:tip('MeterIOSettingsLimitValue'):find('Edit file', 1, true), 'invalid cap must retain the file route')
                idle(f)
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

    local function numericSubmission(f, output)
        f:clear()
        equal(f.env.BeginLimitInput(), true)
        equal(#f.inputRuns, 1, 'numeric entry launches one fixed helper')
        equal(#f.inputUpdates, 1)
        local args = f.options.MeasureIOSettingsNumberInput.Parameter
        check(args:find('-File "SettingsInput.ps1" -Key UtilityNumber -Minimum 0.0001 -Maximum 1000000000 -DecimalPlaces 4', 1, true),
            'numeric editor arguments changed their fixed helper/range')
        check(args:find('-X 250 -Y 504 -Width 104 -Height 20 -Scale 1.0000', 1, true), 'numeric input must align with its actual frame')
        local initial = args:match('%-Initial "([%d%.]+)"')
        check(initial ~= nil, 'numeric initial must be canonical decimal data')
        f:clear()
        f.inputOutput = type(output) == 'function' and output(initial) or output
        return f.env.FinishLimitInput()
    end

    test('typed decimal MB/s caps preserve physical values through compatibility storage', function()
        for _, value in ipairs({ '0.0001', '0.1', '104.9', '123.4567', '1000000000' }) do
            local f = fixture()
            equal(numericSubmission(f, 'PARALLAX_INPUT_V1|ok|' .. value .. '\r\n'), true)
            local expected, stored = tonumber(value), tonumber(f.persisted.IODiskMaxMiBs)
            check(stored and stored > 0 and math.abs(stored * 1.048576 - expected) <= math.max(1e-12, expected * 1e-12),
                'typed MB/s was not preserved through the MiB/s compatibility key')
            equal(f:text('MeterIOSettingsLimitValue'), value)
            saved(f, { IODiskMaxMiBs = f.persisted.IODiskMaxMiBs })
            if value == '104.9' then check(stored ~= 100, 'typed cap was silently snapped to a preset') end
            local reloaded = f:reload()
            equal(reloaded.persisted.IODiskMaxMiBs, f.persisted.IODiskMaxMiBs)
            idle(reloaded)
        end
    end)

    test('numeric cancel and unchanged canonical input preserve raw custom caps exactly', function()
        for _, raw in ipairs({ '500', '500.00000000000001', '737.12500000000001', '00075.00000001' }) do
            local f = fixture({ IODiskMaxMiBs = raw })
            equal(numericSubmission(f, 'PARALLAX_INPUT_V1|cancel|\n'), false)
            equal(f.persisted.IODiskMaxMiBs, raw)
            idle(f)
            equal(numericSubmission(f, function(initial) return 'PARALLAX_INPUT_V1|ok|' .. initial end), false)
            equal(f.persisted.IODiskMaxMiBs, raw, 'rounded initial acceptance rewrote the precise original')
            idle(f)
        end
    end)

    test('numeric completion rejects malformed output range violations precision and action syntax', function()
        for _, output in ipairs({ '', '123.4567', 'PARALLAX_INPUT_V1|ok|', 'PARALLAX_INPUT_V1|ok|0',
            'PARALLAX_INPUT_V1|ok|0.00001', 'PARALLAX_INPUT_V1|ok|1000000000.0001',
            'PARALLAX_INPUT_V1|ok|1.23456', 'PARALLAX_INPUT_V1|ok|-1', 'PARALLAX_INPUT_V1|ok|+1',
            'PARALLAX_INPUT_V1|ok|1e3', 'PARALLAX_INPUT_V1|ok|nan', 'PARALLAX_INPUT_V1|ok|1,5',
            'PARALLAX_INPUT_V1|ok|1 MB/s', 'PARALLAX_INPUT_V1|ok|[!Quit]',
            'PARALLAX_INPUT_V1|ok|#Scale#', 'PARALLAX_INPUT_V1|ok|12\n13',
            'PARALLAX_INPUT_V1|ok|12|other', string.rep('9', 100) }) do
            local f = fixture()
            equal(numericSubmission(f, output), false)
            equal(f.persisted.IODiskMaxMiBs, '500')
            idle(f)
        end
    end)

    test('numeric editor prevents reentry replay and stale overwrites after another cap edit', function()
        local f = fixture()
        equal(f.env.FinishLimitInput(), false)
        idle(f)
        equal(f.env.BeginLimitInput(), true)
        equal(f.env.BeginLimitInput(), false)
        equal(#f.inputRuns, 1)
        f:clear()
        f.env.CycleLimit(1)
        saved(f, { IODiskMaxMiBs = '1000' })
        f:clear()
        f.inputOutput = 'PARALLAX_INPUT_V1|ok|123.4567'
        equal(f.env.FinishLimitInput(), false)
        equal(f.env.FinishLimitInput(), false)
        equal(f.persisted.IODiskMaxMiBs, '1000')
        idle(f)
    end)

    test('unrepresentable saved caps use file editing without invented input defaults', function()
        for _, raw in ipairs({ '1e-10', '1e20', 'bad', '0', '-1', '1e309' }) do
            local f = fixture({ IODiskMaxMiBs = raw })
            equal(f.env.BeginLimitInput(), false)
            equal(f.persisted.IODiskMaxMiBs, raw)
            check(f:tip('MeterIOSettingsLimitValue'):find('Edit file', 1, true), 'unrepresentable cap must retain the file route')
            check(f:text('MeterIOSettingsLimitValue') ~= '0.0', 'positive legacy cap was shown as zero')
            idle(f)
        end
    end)

    test('numeric input validates geometry and cannot launch before initialization', function()
        local empty = fixture(nil, nil, false)
        equal(empty.env.BeginLimitInput(), false)
        equal(empty.env.FinishLimitInput(), false)
        idle(empty)
        local absent = fixture()
        absent.inputMeterAvailable = false
        equal(absent.env.BeginLimitInput(), false)
        idle(absent)
        for _, change in ipairs({ { 'skinX', math.huge }, { 'skinY', -200001 },
            { 'frameW', 0 }, { 'frameH', -1 } }) do
            local f = fixture()
            f[change[1]] = change[2]
            equal(f.env.BeginLimitInput(), false)
            idle(f)
        end
    end)

    test('Open loads only Drive I/O without persisting or refreshing settings', function()
        local f = fixture()
        equal(f.env.Open(), true)
        equal(#f.activations, 1)
        equal(f.activations[1].config, 'Parallax\\IO')
        equal(f.activations[1].file, 'IO-Disk.ini')
        equal(#f.writes, 0)
        equal(#f.refreshes, 0)
        equal(#f.closes, 0)
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
        f.vars.IODiskQuota = '1'
        f.vars.IODiskUnits = 'bits'
        f.vars.IODiskMaxMiBs = '75'
        f.vars.IODiskDrives = 'A,Z'
        f.vars.IOGraphMode = 'c'
        f.env.Initialize()
        f.env.Update()
        idle(f)
        grid(f, 'AZ')
        equal(f:text('MeterIOSettingsGraphValue'), 'C: only')
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '0' })
        f:clear()
        f.env.CycleUnits()
        saved(f, { IODiskUnits = 'bytes' })
        f:clear()
        f.env.CycleLimit(-1)
        saved(f, { IODiskMaxMiBs = '50' })
        f:clear()
        f.env.ToggleDrive('A')
        saved(f, { IODiskDrives = 'Z' })
        f:clear()
        f.env.CycleGraphMode()
        saved(f, { IOGraphMode = 'combined' })
    end)

    test('saved settings survive a fresh controller load without repeated writes', function()
        local f = fixture()
        f.env.Toggle('IODiskQuota')
        f.env.CycleUnits()
        f.env.CycleLimit(1)
        f.env.ToggleDrive('Z')
        f.env.CycleGraphMode()
        local reloaded = f:reload()
        idle(reloaded)
        equal(reloaded.persisted.IODiskQuota, '1')
        equal(reloaded.persisted.IODiskUnits, 'bits')
        equal(reloaded.persisted.IODiskMaxMiBs, '1000')
        equal(reloaded.persisted.IODiskDrives, 'C,Z')
        equal(reloaded.persisted.IOGraphMode, 'overlay')
        grid(reloaded, 'CZ')
        equal(reloaded:text('MeterIOSettingsGraphValue'), 'Overlay')
        reloaded.env.Toggle('IODiskQuota')
        saved(reloaded, { IODiskQuota = '0' })
    end)

    test('display sanitizes custom setting text without expanding actions or rewriting it', function()
        local dirty = 'custom#x#[!Quit]\t\r\n'
        local f = fixture({ IODiskQuota = dirty, IODiskUnits = dirty, IODiskMaxMiBs = dirty,
            IODiskDrives = dirty, IOGraphMode = dirty })
        idle(f)
        for meter, options in pairs(f.options) do
            for key, value in pairs(options) do
                if key == 'Text' or key == 'ToolTipText' then
                    check(not value:find('[%c#%[%]]'), meter .. '.' .. key .. ' has expression delimiters')
                end
            end
        end
        for _, key in ipairs({ 'IODiskQuota', 'IODiskUnits', 'IODiskMaxMiBs', 'IODiskDrives', 'IOGraphMode' }) do
            equal(f.persisted[key], dirty, 'display must preserve raw ' .. key)
        end
        f:clear()
        f.env.Toggle('IODiskQuota')
        saved(f, { IODiskQuota = '1' })
        equal(f.persisted.IODiskUnits, dirty, 'unrelated edit must preserve units')
        equal(f.persisted.IODiskMaxMiBs, dirty, 'unrelated edit must preserve graph limit')
        equal(f.persisted.IODiskDrives, dirty, 'unrelated edit must preserve drive preference')
        equal(f.persisted.IOGraphMode, dirty, 'unrelated edit must preserve graph preference')
    end)

    report[#report + 1] = string.format('SUMMARY: %d tests, %d assertions, %d failed',
        passed + failed, assertions, failed)
    local summary = table.concat(report, '\n')
    if failed > 0 then error(summary, 0) end
    return assertions, summary
end

return Suite
