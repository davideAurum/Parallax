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

    local function near(actual, expected, message)
        assertions = assertions + 1
        if type(actual) ~= 'number' or math.abs(actual - expected) > 0.0015 then
            error((message or 'value') .. ': expected ' .. tostring(expected)
                .. ', got ' .. tostring(actual), 2)
        end
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

    local targets, bankLetter = {}, {}
    local bankPrefixes = {'MeterIODrive', 'MeterIOCapacity', 'MeterIOUsed',
        'MeterIODiskRead', 'MeterIODiskWrite', 'MeterIODiskReadLabel', 'MeterIODiskWriteLabel',
        'MeterIOGauge', 'MeterIOLoad', 'MeterIOEject', 'MeterIOLegend'}
    for _, name in ipairs({
        'MeterIOTotal', 'MeterIOBounds', 'MeterIOPanel', 'MeterIOEmpty',
        'MeterIODiskGraph', 'MeterIODiskGraphTrack',
        'MeterIOGraphPositive', 'MeterIOGraphZero', 'MeterIOGraphNegative'
    }) do targets[name] = true end
    for code = 65, 90 do
        local letter = string.char(code)
        for _, prefix in ipairs(bankPrefixes) do
            targets[prefix .. letter] = true
            bankLetter[prefix .. letter] = letter
        end
    end

    local function fixture(overrides, samples)
        local vars = {
            IODiskUnits = 'bytes', IODiskDrives = 'C', IOGraphMode = 'combined', IODriveNames = 'letters',
            ['@'] = 'fixture-resources\\',
            Inset = '4', Gap = '8', ContentX = '10', PanelHeight = '152', IOMinPanelHeight = '0', DataBarThickness = '6',
            IODiskMaxMiBs = '500',
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
        -- Drive rows ship idle (UpdateDivider=-1). rows: the stored divider
        -- after a letter's last !SetOptionGroup; effective: the divider a
        -- forced group update has applied (an idle meter ignores !SetOption
        -- until forced); pending: bank meter options set while idle and not
        -- yet applied by a forced update; rowUpdates counts forced updates.
        -- reads counts GetMeasure calls by name and parses ParseFormula calls.
        local state = { vars = vars, values = values, options = {}, shown = {}, calls = {}, now = 1000,
            groups = {}, variableWrites = {}, queryRuns = 0, rows = {}, effective = {}, pending = {}, rowUpdates = {},
            reads = {}, parses = 0, ejects = {}, ejectParameter = nil }
        local skin = {}
        function skin:GetVariable(key, default)
            if vars[key] == nil then return default end
            return vars[key]
        end
        function skin:GetMeasure(key)
            state.reads[key] = (state.reads[key] or 0) + 1
            local letter = key:match('^MeasureIOTotal([A-Z])$') or key:match('^MeasureIOFree([A-Z])$')
            if letter then assert(state.groups['IOCapacity' .. letter], 'read from a disabled capacity bank') end
            letter = key:match('^MeasureIODiskRead([A-Z])$') or key:match('^MeasureIODiskWrite([A-Z])$')
                or key:match('^MeasureIODiskIdle([A-Z])$')
            if letter then assert(state.groups['IORates' .. letter], 'read from a disabled rate bank') end
            if values[key] == nil then return nil end
            return { GetValue = function() return values[key] end,
                GetStringValue = function() return type(values[key]) == 'string' and values[key] or '' end }
        end
        function skin:ReplaceVariables(value)
            return value:gsub('#([%w]+)#', function(key) return vars[key] or '' end)
        end
        function skin:ParseFormula(value)
            state.parses = state.parses + 1
            if not value:match('^[%d%s%.%+%-%*/%(%)]+$') then return nil end
            local expression = assert(loadstring('return ' .. value))
            setfenv(expression, {})
            return expression()
        end
        function skin:Bang(command, target, key, value)
            if command == '!CommandMeasure' and target == 'MeasureIOEject' then
                assert(key == 'Run' and value == nil, 'unexpected eject command')
                state.ejects[#state.ejects + 1] = state.ejectParameter
            elseif command == '!SetOption' and target == 'MeasureIOEject' then
                assert(key == 'Parameter', 'only the eject parameter may change')
                state.ejectParameter = value
            elseif command == '!UpdateMeasure' then
                assert(target == 'MeasureIOEject', 'unexpected measure update: ' .. tostring(target))
            elseif command == '!CommandMeasure' then
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
            elseif command == '!SetOptionGroup' then
                local letter = target:match('^IORow([A-Z])$')
                assert(letter and key == 'UpdateDivider' and (value == '1' or value == '-1'),
                    'unexpected group option mutation: ' .. tostring(target) .. ' ' .. tostring(key))
                state.rows[letter] = value
            elseif command == '!UpdateMeterGroup' then
                local letter = target:match('^IORow([A-Z])$')
                assert(letter, 'unexpected forced meter group: ' .. tostring(target))
                state.rowUpdates[letter] = (state.rowUpdates[letter] or 0) + 1
                state.effective[letter] = state.rows[letter]
                for _, prefix in ipairs(bankPrefixes) do state.pending[prefix .. letter] = nil end
            else
                assert(targets[target], 'unexpected controller target: ' .. tostring(target))
                if command == '!SetOption' then
                    assert(key == 'Text' or key == 'FontColor' or key == 'X' or key == 'Y' or key == 'W' or key == 'H'
                        or (target == 'MeterIODiskGraphTrack' and key == 'Shape3')
                        or (target == 'MeterIODiskGraph' and (key:match('^Shape%d*$') or key:match('^IOHistoryPath%d+$'))),
                        'unexpected option mutation: ' .. tostring(key))
                    state.options[target] = state.options[target] or {}
                    state.options[target][key] = value
                    local letter = bankLetter[target]
                    if letter and state.effective[letter] ~= '1' then state.pending[target] = true end
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
                        or target:match('^MeterIODiskReadLabel[A-Z]$') or target:match('^MeterIODiskWriteLabel[A-Z]$')
                        or target:match('^MeterIOGauge[A-Z]$') or target:match('^MeterIOLoad[A-Z]$')
                        or target:match('^MeterIOEject[A-Z]$'),
                        'unexpected forced meter update')
                    state.pending[target] = nil
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
            local colors = path == vars['@'] .. 'Modules\\IO\\DriveColors.lua'
            assert(colors or path == vars['@'] .. 'Modules\\IO\\Names.lua', 'unexpected library load')
            local library = assert(loadfile(colors and namesPath:gsub('Names%.lua$', 'DriveColors.lua') or namesPath))
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
        -- After every controller entry: a row with any shown meter must be
        -- updating with every option it was given applied (no stale idle
        -- meter); a row with no shown meter must be stored idle.
        function state:checkRows(result)
            for code = 65, 90 do
                local letter = string.char(code)
                local shown = false
                for _, prefix in ipairs(bankPrefixes) do
                    if self.shown[prefix .. letter] then
                        shown = true
                        assert(not self.pending[prefix .. letter], 'shown ' .. prefix .. letter .. ' has options its idle row never applied')
                    end
                end
                if shown then assert(self.effective[letter] == '1', 'shown row ' .. letter .. ' is not updating')
                else assert(self.rows[letter] ~= '1', 'hidden row ' .. letter .. ' still updates every tick') end
            end
            return result
        end
        function state:tick(seconds)
            self.now = self.now + (seconds == nil and 1 or seconds)
            return self:checkRows(env.Update())
        end
        function state:namesReady()
            assert(type(env.NamesReady) == 'function', 'model completion entrypoint missing')
            return self:checkRows(env.NamesReady())
        end
        function state:applyNamesMode() return self:checkRows(env.ApplyNamesMode()) end
        function state:refreshNamesInventory() return self:checkRows(env.RefreshNamesInventory()) end
        function state:eject(letter) return env.Eject(letter) end
        function state:ejectFinished() return self:checkRows(env.EjectFinished()) end
        function state:refresh()
            self.options, self.shown, self.calls, self.groups, self.variableWrites = {}, {}, {}, {}, {}
            self.rows, self.effective, self.pending, self.rowUpdates = {}, {}, {}, {}
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
        state.env = env
        state:tick()
        return state
    end

    local function checkInlineCells(f, letter, scale, width, x)
        local read = f.options['MeterIODiskRead' .. letter]
        local write = f.options['MeterIODiskWrite' .. letter]
        local readIcon = f.options['MeterIODiskReadLabel' .. letter]
        local writeIcon = f.options['MeterIODiskWriteLabel' .. letter]
        local capacity = f.options['MeterIOCapacity' .. letter]
        local gauge = f.options['MeterIOGauge' .. letter]
        local load = f.options['MeterIOLoad' .. letter]
        local rateWidth = (width - 51 * scale) * 0.42
        local capacityWidth = (width - 51 * scale) * 0.58
        local function near(actual, expected, message)
            truth(math.abs(tonumber(actual) - expected) < 0.001, message)
        end
        equal(tonumber(f.options['MeterIODrive' .. letter].W), width)
        near(gauge.X, x, 'gauge sits flush with the content edge')
        near(load.X, x)
        near(load.W, 36 * scale, '100% at 10pt fits without an ellipsis')
        for _, icon in ipairs({readIcon, writeIcon}) do
            near(icon.X, x + 36 * scale)
            near(icon.W, 10 * scale)
        end
        near(read.X, x + 47 * scale)
        near(read.W, rateWidth)
        near(write.X, x + 47 * scale)
        near(write.W, width - 47 * scale, 'nothing shares the write line, so write runs to the edge')
        near(capacity.X, x + width)
        near(capacity.W, capacityWidth)
        near(capacity.Y, tonumber(read.Y), 'capacity shares the read line under the bar')
        near(tonumber(write.Y) - tonumber(read.Y), 16 * scale, 'write stacks one line below read')
        near(load.Y, tonumber(write.Y), 'load shares the write line under the gauge')
        near(tonumber(gauge.Y) - tonumber(read.Y), scale, 'gauge sits on the read line')
        near(tonumber(writeIcon.Y) - tonumber(write.Y), 2 * scale)
        near(tonumber(capacity.X) - tonumber(capacity.W) - tonumber(read.X) - tonumber(read.W), 4 * scale,
            'read/capacity columns must retain their gap')
    end

    test('load is busy time from % Idle Time, clamped, under the gauge and honest when unavailable', function()
        local f = fixture(nil, { MeasureIODiskIdleC = 88, MeasureIODiskReadC = 1e6 })
        equal(f:text('MeterIOLoadC'), '12%')
        equal(f.shown.MeterIOGaugeC, true)
        equal(f.shown.MeterIOLoadC, true)
        for _, case in ipairs({ {100.4, '0%'}, {-3, '100%'}, {0.4, '100%'}, {99.6, '0%'} }) do
            f.values.MeasureIODiskIdleC = case[1]
            f:tick()
            equal(f:text('MeterIOLoadC'), case[2])
        end
        for _, bad in ipairs({ 0/0, math.huge }) do
            f.values.MeasureIODiskIdleC = bad
            f:tick()
            equal(f:text('MeterIOLoadC'), '--')
        end
        f.values.MeasureIODiskIdleC = nil
        f:tick()
        equal(f:text('MeterIOLoadC'), '--', 'a missing counter must not read as idle or busy')
        f.values.MeasureIODiskIdleC, f.values.MeasureIODiskReadC = 0, 0
        f:tick()
        equal(f:text('MeterIOLoadC'), '--', 'a missing instance reads 0 idle with no transfers, not 100% busy')
        f.values.MeasureIODiskWriteC = 1e6
        f:tick()
        equal(f:text('MeterIOLoadC'), '100%', 'zero idle while moving bytes is a real full load')
        local hidden = fixture({ IODiskDrives = 'none' }, { MeasureIODiskIdleC = 50 })
        equal(hidden.shown.MeterIOGaugeC, false)
        equal(hidden.shown.MeterIOLoadC, false)
        truth(not hidden.reads.MeasureIODiskIdleC, 'an unselected drive must not read its idle counter')
    end)

    test('rates and capacity keep two significant figures and carry into the next unit', function()
        local f = fixture(nil, { MeasureIODiskReadC = 999.6e6, MeasureIODiskWriteC = 9.96e3,
            MeasureIOTotalC = 2e12, MeasureIOFreeC = 1.97e12 })
        equal(f:text('MeterIODiskReadC'), '1.0 GB/s', '999.6 MB/s rounds into the next unit')
        equal(f:text('MeterIODiskWriteC'), '10 KB/s')
        equal(f:text('MeterIOCapacityC'), '2.0 / 2.0 TB', 'nearly full rounds honestly; the bar shows the rest')
        for _, case in ipairs({ {150.5e6, '150 MB/s'}, {1234, '1.2 KB/s'}, {519.8e9, '520 GB/s'},
            {99.96, '100 B/s'}, {0.5, '0.50 B/s'}, {5, '5.0 B/s'} }) do
            f.values.MeasureIODiskReadC = case[1]
            f:tick()
            equal(f:text('MeterIODiskReadC'), case[2])
        end
        local mixed = fixture(nil, { MeasureIOTotalC = 997.7e9 * 1.0, MeasureIOFreeC = 519.8e9 })
        equal(mixed:text('MeterIOCapacityC'), '520 GB / 1.0 TB', 'a total that rounds into TB keeps both units')
        local bits = fixture({ IODiskUnits = 'bits' }, { MeasureIODiskReadC = 150.5e6 })
        equal(bits:text('MeterIODiskReadC'), '1.2 Gbit/s')
    end)

    test('removable and optical rows offer eject; the click runs the bundled eject script once', function()
        local f = fixture({ IODiskDrives = 'C,F,G' }, {
            MeasureIOTypeF = 6, MeasureIOTypeG = 3, MeasureIOTotalG = 64e9, MeasureIOFreeG = 63.9e9 })
        equal(f.shown.MeterIOEjectC, false, 'a fixed drive has no eject')
        equal(f.shown.MeterIOEjectF, true, 'optical drives eject')
        equal(f.shown.MeterIOEjectG, true, 'removable drives eject')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(tonumber(f.options.MeterIODriveG.W), 188, 'the name stops 6px before the icon')
        equal(tonumber(f.options.MeterIOEjectG.X), 10 + 208 - 20, 'the hit box starts where the name stops')
        equal(tonumber(f.options.MeterIOEjectG.Y), tonumber(f.options.MeterIODriveG.Y), 'the hit box spans the name row')
        equal(f:eject('G'), 0)
        equal(#f.ejects, 1)
        contains(f.ejects[1], "NewScriptBlock((Get-Content -Raw -LiteralPath 'fixture-resources\\Modules\\IO\\Eject.ps1')) G\"")
        truth(not f.ejects[1]:find('ExecutionPolicy', 1, true), 'no execution-policy override')
        truth(not f.ejects[1]:find('[#%[%]]'), 'the parameter must not expand variables or sections')
        local quoted = fixture({ IODiskDrives = 'G', ['@'] = "C:\\O'Neil\\Skins\\Parallax\\@Resources\\" },
            { MeasureIOTypeG = 3 })
        quoted:eject('G')
        contains(quoted.ejects[1], "'C:\\O''Neil\\Skins\\Parallax\\@Resources\\Modules\\IO\\Eject.ps1'",
            'an apostrophe in the skin path is doubled for PowerShell')
        local expanding = fixture({ IODiskDrives = 'G', ['@'] = 'C:\\Skins [old]\\Parallax\\@Resources\\' },
            { MeasureIOTypeG = 3 })
        expanding:eject('G')
        equal(#expanding.ejects, 0, 'a path Rainmeter would expand is refused')
        for _, bad in ipairs({ 'C', 'g', 'GG', '', "G');", 7, nil }) do
            f:eject(bad)
        end
        equal(#f.ejects, 1, 'fixed, malformed and absent letters never launch the helper')
        local before = f.rowUpdates.G or 0
        f.values.MeasureIOTypeG = 1
        local callsBefore = #f.calls
        equal(f:ejectFinished(), 0)
        local refreshed = false
        for index = callsBefore + 1, #f.calls do
            local call = f.calls[index]
            refreshed = refreshed or (call[1] == '!UpdateMeasureGroup' and call[2] == 'IOInventory')
        end
        truth(refreshed, 'a finished eject re-reads the inventory at once')
        f:tick()
        equal(f.shown.MeterIOEjectG, false, 'an ejected drive loses its icon on the next tick')
        equal(tonumber(f.options.MeterIODriveG.W), 208)
        truth((f.rowUpdates.G or 0) >= before)
        local hidden = fixture({ IODiskDrives = 'C' }, { MeasureIOTypeG = 3 })
        equal(hidden.shown.MeterIOEjectG, false, 'unselected removable drives show nothing')
    end)

    test('a refused eject names the holder on the drive row in WarningColor, then clears', function()
        local f = fixture({ IODiskDrives = 'C,G', TextColor = '220,220,220', WarningColor = '240,225,40' },
            { MeasureIOTypeG = 3, MeasureIOTotalG = 64e9, MeasureIOFreeG = 63.9e9 })
        local normal = f.options.MeterIODriveG.Text
        local function refuse(output, expected)
            f:eject('G')
            f.values.MeasureIOEject = output
            f:ejectFinished()
            f:tick()
            equal(f.options.MeterIODriveG.Text, expected, tostring(output))
            equal(f.options.MeterIODriveG.FontColor, '240,225,40', 'warning color for ' .. tostring(output))
        end
        refuse('vetoed 4 \\Device\\HarddiskVolume5\\Windows\\System32\\SearchIndexer.exe\r\n', 'G: In use by Windows Search')
        refuse('vetoed 5 WSearch', 'G: In use by Windows Search')
        refuse('vetoed 4 C:\\Tools\\Lightroom.EXE', 'G: In use by Lightroom')
        refuse('vetoed 6 USBSTOR\\Disk&Ven_Multiple', "G: Couldn't eject")
        refuse('eject failed 21', "G: Couldn't eject")
        refuse(nil, "G: Couldn't eject")
        equal(f.options.MeterIODriveC.FontColor, '220,220,220', 'other rows keep the text color')
        for _ = 1, 7 do f:tick() end
        equal(f.options.MeterIODriveG.Text, normal, 'the notice clears after eight updates')
        equal(f.options.MeterIODriveG.FontColor, '220,220,220')
        f:eject('G')
        f.values.MeasureIOEject = 'ejected'
        f:ejectFinished()
        f:tick()
        equal(f.options.MeterIODriveG.Text, normal, 'a successful eject shows no notice')
        f.values.MeasureIOEject = 'vetoed 5 WSearch'
        f:ejectFinished()
        f:tick()
        equal(f.options.MeterIODriveG.Text, normal, 'a finish without a click shows nothing')
    end)

    test('C: shows decimal free/total and used percentage with body reading color', function()
        local f = fixture({ TextColor = '210,220,230' })
        equal(f:text('MeterIODriveC'), 'C:')
        equal(f:text('MeterIOCapacityC'), '27 / 110 GB')
        equal(f.options.MeterIOCapacityC.FontColor, '210,220,230')
        equal(f.shown.MeterIOUsedC, true)
        equal(f:text('MeterIOTotal'), '75%')
        local decimal = fixture(nil, { MeasureIOFreeC = 1000000000, MeasureIOTotalC = 2000000000 })
        equal(decimal:text('MeterIOCapacityC'), '1.0 / 2.0 GB')
        local different = fixture(nil, { MeasureIOFreeC = 26.8e9, MeasureIOTotalC = 1.1e12 })
        equal(different:text('MeterIOCapacityC'), '27 GB / 1.1 TB', 'different units must remain explicit')
    end)

    test('a full drive has valid zero free space rather than an unavailable state', function()
        local f = fixture(nil, { MeasureIOFreeC = 0 })
        equal(f:text('MeterIOCapacityC'), '0 / 110 GB')
        equal(f:text('MeterIOTotal'), '100%')
        equal(f.shown.MeterIOUsedC, true)
    end)

    test('a completely free drive remains valid at zero used percentage', function()
        local f = fixture(nil, { MeasureIOFreeC = 100 * GiB })
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
        equal(f:text('MeterIODiskReadC'), '1.0 MB/s')
        equal(f:text('MeterIODiskWriteC'), '--')
        equal(f.shown.MeterIODiskGraph, true)
        equal(#f:traces(), 2)
        equal(f:traces()[1].color, '10,20,30')
        equal(f:text('MeterIOCapacityC'), '27 / 110 GB')
        equal(f:traces()[2].points[1].y, 60, 'a current zero write plots at baseline')
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 1000, 1000000
        f:tick()
        equal(f:text('MeterIODiskReadC'), '1.0 KB/s')
        equal(f:text('MeterIODiskWriteC'), '1.0 MB/s')
    end)

    test('bits use decimal rate units while capacity stays in decimal bytes', function()
        local f = fixture({ IODiskUnits = 'BITS' },
            { MeasureIODiskReadC = 125000, MeasureIODiskWriteC = 125 })
        equal(f:text('MeterIODiskReadC'), '1.0 Mbit/s')
        equal(f:text('MeterIODiskWriteC'), '1.0 kbit/s')
        equal(f:text('MeterIOCapacityC'), '27 / 110 GB')
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
    end)

    test('invalid graph ceilings hide history without hiding valid rate text', function()
        for _, limit in ipairs({ '0', '-1', 'bad', '1e309' }) do
            local f = fixture({ IODiskMaxMiBs = limit }, { MeasureIODiskReadC = 1024 })
            equal(f:text('MeterIODiskReadC'), '1.0 KB/s')
            equal(f.shown.MeterIODiskGraph, false)
            equal(#f:traces(), 0)
        end
    end)

    test('unsupported display units are visible rather than silently reinterpreted', function()
        local f = fixture({ IODiskUnits = 'invalid' }, { MeasureIODiskReadC = 1024 })
        equal(f:text('MeterIODiskReadC'), 'Check IO units')
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
        f:tick()
        traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 2)
        truth(traces[1].points[1].x < 206)
        equal(traces[1].points[2].x, 206)
    end)

    test('history retains at most sixty observations and autoscale forgets an expired peak', function()
        local f = fixture(nil, { MeasureIODiskReadC = 8 * 1048576 })
        f.values.MeasureIODiskReadC = 1048576
        for _ = 1, 60 do f:tick() end
        local traces = f:traces()
        equal(#traces, 2)
        equal(#traces[1].points, 60)
        equal(traces[1].points[1].x, 2)
        equal(traces[1].points[60].x, 206)
        equal(traces[1].points[60].y, 9.565, 'autoscale must follow only the retained peak')
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
        f:tick(-5)
        equal(#f:traces(), 2)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
        f:tick(120)
        equal(#f:traces(), 2)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].x, 206)
    end)

    test('idle stand-down: a 300 s pause leaves a gap and every row divider is re-applied', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1048576 })
        for _ = 1, 5 do f:tick() end
        equal(#f:traces()[1].points, 6, 'six observed seconds before the pause')
        local before = {}
        for code = 65, 90 do before[string.char(code)] = f.rows[string.char(code)] end
        -- The hook deletes the freeze key (rows would update at the default 1),
        -- then ReapplyDividers sends every letter's own divider, cache bypassed.
        f.calls = {}
        f.env.ReapplyDividers()
        equal(#f.calls, 26, 'one group option per letter')
        for code = 65, 90 do
            local letter = string.char(code)
            equal(f.calls[code - 64][1], '!SetOptionGroup')
            equal(f.calls[code - 64][2], 'IORow' .. letter)
            equal(f.rows[letter], before[letter] or '-1', 'row ' .. letter .. ' divider after resume')
        end
        equal(f.rows.C, '1', 'the shown row samples again')
        -- Five minutes paused: the first sample after resume follows a gap of
        -- empty slots; nothing is joined across the pause.
        f:tick(300)
        local points = f:traces()[1].points
        equal(#points, 1, 'only the new sample is plotted after the gap')
        equal(points[1].x, 206, 'the new sample is the newest slot')
    end)

    test('autoscale minimum and hard ceiling remain explicit and bound positive traces', function()
        local low = fixture(nil, { MeasureIODiskReadC = 1 })
        equal(low:traces()[1].points[1].y, 59.999, 'the 65,536 B/s autoscale minimum bounds tiny rates')
        local capped = fixture({ IODiskMaxMiBs = '10' }, { MeasureIODiskReadC = 100 * 1048576 })
        equal(capped:traces()[1].points[1].y, 2)
        equal(capped:text('MeterIODiskReadC'), '100 MB/s', 'graph cap must not alter the reported rate')
        local smallCap = fixture({ IODiskMaxMiBs = '0.001' }, { MeasureIODiskReadC = 1048576 })
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

    test('only shown drive rows update every tick and each divider change is forced once', function()
        local function rowCalls(f, from)
            local result = {}
            for index = from + 1, #f.calls do
                local call = f.calls[index]
                if call[1] == '!SetOptionGroup' or call[1] == '!UpdateMeterGroup' then result[#result + 1] = call end
            end
            return result
        end
        local f = fixture(nil, { MeasureIOTypeD = 4, MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8 })
        local calls = rowCalls(f, 0)
        equal(#calls, 2, 'only the shown C row leaves its shipped idle divider')
        equal(calls[1][1], '!SetOptionGroup'); equal(calls[1][2], 'IORowC'); equal(calls[1][4], '1')
        equal(calls[2][1], '!UpdateMeterGroup'); equal(calls[2][2], 'IORowC')
        -- The forced group update follows every position and visibility write for that row.
        local forced
        for index, call in ipairs(f.calls) do if call[1] == '!UpdateMeterGroup' then forced = index end end
        for index, call in ipairs(f.calls) do
            if call[2] == 'MeterIODriveC' and (call[3] == 'Y' or call[1] == '!ShowMeter') then
                truth(index < forced, 'row C was forced before its position or visibility was set')
            end
        end
        local before = #f.calls
        f:tick(); f:tick()
        equal(#rowCalls(f, before), 0, 'stable rows must not be forced again')
        f.vars.IODiskDrives = 'D'
        before = #f.calls
        f:tick()
        calls = rowCalls(f, before)
        equal(#calls, 4)
        equal(f.rows.C, '-1'); equal(f.effective.C, '-1'); equal(f.rowUpdates.C, 2)
        equal(f.rows.D, '1'); equal(f.effective.D, '1'); equal(f.rowUpdates.D, 1)
        equal(f.shown.MeterIODriveC, false); equal(tonumber(f.options.MeterIODriveC.Y), 0)
        equal(f.shown.MeterIODriveD, true); equal(tonumber(f.options.MeterIODriveD.Y), 28)
        f.vars.IODiskDrives = 'none'
        f:tick()
        for code = 65, 90 do truth(f.rows[string.char(code)] ~= '1', 'none must leave every row idle') end
        local all = {}
        for code = 65, 90 do all['MeasureIOType' .. string.char(code)] = 4 end
        local every = fixture({ IODiskDrives = 'all', IOGraphMode = 'overlay' }, all)
        for code = 65, 90 do
            local letter = string.char(code)
            equal(every.effective[letter], '1', 'every shown row updates')
            equal(every.rowUpdates[letter], 1, 'one forced update per newly shown row')
            equal(every.shown['MeterIOLegend' .. letter], true)
        end
        every.vars.IODiskDrives = 'C'
        every:tick()
        for code = 65, 90 do
            local letter = string.char(code)
            equal(every.effective[letter], letter == 'C' and '1' or '-1')
        end
    end)

    test('slow selection, name and capacity work runs only on ticks whose inputs can change', function()
        -- Inventory, label and capacity measures update on their first tick,
        -- then every Max(5,Ceil(CapacityInterval/1000)) ticks; a forced update
        -- restarts a measure's count. Rates and the graph stay per tick.
        local function slowReads(f)
            local count = 0
            for key, n in pairs(f.reads) do
                if key:match('^MeasureIOType') or key:match('^MeasureIOName') or key:match('^MeasureIOTotal')
                    or key:match('^MeasureIOFree') then count = count + n end
            end
            return count
        end
        local function step(f)
            f.reads = {}
            f:tick()
            return slowReads(f) > 0
        end
        local f = fixture({ CapacityInterval = '30000', IODriveNames = 'volume' }, {
            MeasureIONameC = 'System', MeasureIOTypeD = 4, MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8,
            MeasureIODiskReadC = 1e6 })
        equal(f:text('MeterIOCapacityC'), '27 / 110 GB')
        equal(f:text('MeterIODriveC'), 'C: System')
        local slow = {}
        for t = 1, 61 do
            if t == 5 then f.values.MeasureIOFreeC = 50 * GiB end
            if t == 31 then f.vars.IODiskDrives = 'C,D' end
            if step(f) then slow[#slow + 1] = t end
            truth((f.reads.MeasureIODiskReadC or 0) > 0, 'rates must still be read every tick')
            if t == 29 then equal(f:text('MeterIOCapacityC'), '27 / 110 GB', 'capacity text follows its measure cadence') end
            if t == 30 then equal(f:text('MeterIOCapacityC'), '54 / 110 GB') end
            if t == 31 then equal(f.shown.MeterIODriveD, true, 'a selection variable change applies on the next tick') end
        end
        -- Ticks 0/30/60 follow load; 31 follows the selection change and starts
        -- the D bank's count, so 61 follows that bank.
        equal(table.concat(slow, ','), '30,31,60,61')
        local before = #slow
        for t = 62, 70 do if step(f) then slow[#slow + 1] = t end end
        f:refreshNamesInventory()
        for t = 71, 101 do if step(f) then slow[#slow + 1] = t end end
        -- 71 reconciles the forced inventory update, whose count restarts so
        -- that it next updates at 100; 90/91 continue the load and D phases.
        equal(table.concat(slow, ',', before + 1), '71,90,91,100')
        local fast = fixture({ CapacityInterval = '1000' })
        local fastSlow = {}
        for t = 1, 10 do if step(fast) then fastSlow[#fastSlow + 1] = t end end
        equal(table.concat(fastSlow, ','), '5,10', 'short intervals keep the five-tick minimum')
        local odd = fixture({ CapacityInterval = '45500' })
        local oddSlow = {}
        for t = 1, 46 do if step(odd) then oddSlow[#oddSlow + 1] = t end end
        equal(table.concat(oddSlow, ','), '46', 'the divider rounds the interval up to whole seconds')
        for _, bad in ipairs({'', 'not a number', '(1/0)'}) do
            local every = fixture({ CapacityInterval = bad })
            for _ = 1, 3 do truth(step(every), 'without a usable interval the slow state updates every tick') end
        end
    end)

    test('parsed geometry formulas are reused until their text changes', function()
        local plain = fixture(nil, { MeasureIODiskReadC = 1e6 })
        local formula = fixture({ ContentWidth = '(216-8)', ContentX = '(4+6)', Scale = '(2/2)', Inset = '(8/2)' },
            { MeasureIODiskReadC = 1e6 })
        for _, key in ipairs({'MeterIODriveC', 'MeterIOCapacityC', 'MeterIODiskReadC', 'MeterIODiskGraph'}) do
            for option, value in pairs(plain.options[key]) do
                equal(formula.options[key][option], value, key .. ' ' .. option .. ' differs with formula geometry')
            end
        end
        local parses = formula.parses
        formula:tick(); formula:tick()
        equal(formula.parses, parses, 'unchanged formula variables must not be parsed again')
        formula.vars.ContentWidth = '(220-8)'
        formula:tick()
        truth(formula.parses > parses, 'changed formula text must be parsed again')
        equal(tonumber(formula.options.MeterIODriveC.W), 212)
    end)

    test('malformed or noncanonical drive lists fall back to C without persisting a replacement', function()
        for _, bad in ipairs({'', 'c', 'C:', 'C,D,', ',C', 'C,,D', 'C,C', 'D,C', 'C D', ' C', 'ALL', '[!Quit]', 'C\nD'}) do
            local f = fixture({ IODiskDrives = bad }, { MeasureIOTypeD = 4 })
            equal(f.vars.IODiskDrives, bad)
            equal(f.shown.MeterIODriveC, true)
            equal(f.shown.MeterIODriveD, false)
            truth(not f.groups.IORatesD)
        end
    end)

    test('canonical selected rows put C first then alphabetical letters with compact positions', function()
        local f = fixture({ IODiskDrives = 'A,C,Z' }, {
            MeasureIOTypeA = 3, MeasureIOTotalA = 1e9, MeasureIOFreeA = 5e8,
            MeasureIOTypeZ = 7, MeasureIOTotalZ = 2e9, MeasureIOFreeZ = 1e9 })
        equal(tonumber(f.options.MeterIODriveC.Y), 28)
        equal(tonumber(f.options.MeterIODriveA.Y), 91)
        equal(tonumber(f.options.MeterIODriveZ.Y), 154)
        equal(tonumber(f.options.MeterIOUsedZ.Y), 172)
        equal(tonumber(f.options.MeterIODiskReadZ.Y), 179)
        equal(tonumber(f.options.MeterIODiskWriteLabelZ.Y), 197)
        equal(tonumber(f.options.MeterIOCapacityZ.Y), 179)
        equal(tonumber(f.options.MeterIOGaugeZ.Y), 180)
        equal(tonumber(f.options.MeterIOLoadZ.Y), 195)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 214)
        equal(tonumber(f.vars.PanelHeightPx), 278)
        equal(tonumber(f.options.MeterIOBounds.H), 286)
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
        equal(tonumber(f.options.MeterIODriveE.Y), 280)
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
        equal(f:text('MeterIODiskReadD'), '1.0 MB/s')
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
        equal(tonumber(f.options.MeterIODriveD.Y), 28)
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
        equal(f:text('MeterIODiskReadC'), '1.0 MB/s')
        equal(f:text('MeterIODiskReadD'), '3.0 MB/s')
        truth(not f.groups.IORatesE)
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
        empty.vars.IOMinPanelHeight = '300'
        local before = #empty.calls
        empty:tick()
        equal(#empty:traces()[1].points, 2)
        equal(tonumber(empty.options.MeterIODiskReadC.Y), 59)
        equal(tonumber(empty.options.MeterIODiskGraph.Y), 94)
        equal(tonumber(empty.vars.PanelHeightPx), 300)
        equal(empty.vars.IOMinPanelHeight, '300')
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
        equal(f:traces()[1].points[1].y, 34.783, 'C: only must graph C: rather than the selected D: rates')
        f:tick()
        f.vars.IOGraphMode = 'combined'
        f:tick()
        equal(f.groups.IORatesC, false)
        equal(#f:traces()[1].points, 1)
        equal(f:traces()[1].points[1].y, 22.174, 'combined mode must graph the selected D: rates')
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
        equal(f.shown.MeterIOLegendC, true)
        equal(tonumber(f.options.MeterIOLegendC.Y), 151)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 169)
        equal(tonumber(f.vars.PanelHeightPx), 233)
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
        equal(tonumber(f.options.MeterIODiskGraph.Y), 88)
        equal(tonumber(f.vars.PanelHeightPx), 152)
        equal(#f:traces()[1].points, 1)
    end)

    test('saved drive colors replace the default overlay colors and apply without a refresh', function()
        local samples = { MeasureIODiskReadC = 1e6, MeasureIODiskWriteC = 2e6,
            MeasureIOTypeD = 4, MeasureIODiskReadD = 3e6, MeasureIODiskWriteD = 4e6 }
        local plain = fixture({ IODiskDrives = 'C,D', IOGraphMode = 'overlay' }, samples)
        plain:tick()
        local defaults = plain:traces()
        -- A hex value is canonicalized; an invalid value falls back to the letter's default.
        local f = fixture({ IODiskDrives = 'C,D', IOGraphMode = 'overlay',
            IODriveColorC = '#FF8000', IODriveColorD = 'not a color' }, samples)
        f:tick()
        local traces = f:traces()
        equal(traces[1].color, '255,128,0')
        equal(traces[2].color, '255,128,0', 'read and write share the drive color')
        equal(f.options.MeterIOLegendC.FontColor, '255,128,0')
        equal(traces[3].color, defaults[3].color, 'invalid saved color must use the default')
        equal(f.options.MeterIOLegendD.FontColor, defaults[3].color)
        -- The editor sets the variable and calls ApplyColors: legend and traces repaint at once.
        f.vars.IODriveColorD = '1,2,3'
        equal(f.env.ApplyColors(), 0)
        equal(f.options.MeterIOLegendD.FontColor, '1,2,3')
        equal(f:traces()[3].color, '1,2,3')
        equal(f:traces()[4].color, '1,2,3')
        -- Outside overlay mode the colors are unused, so applying them changes nothing.
        f.vars.IOGraphMode = 'combined'
        f:tick()
        f.vars.IODriveColorD = '9,9,9'
        equal(f.env.ApplyColors(), 0)
        equal(f.options.MeterIOLegendD.FontColor, '1,2,3')
        equal(f:traces()[1].color, '10,20,30', 'combined mode keeps the read/write colors')
    end)

    test('an upgraded copy ignores the old saved PanelHeight and fits its drives', function()
        -- Every release before alpha.10 saved PanelHeight=157 in User\IO.inc.
        local f = fixture({ PanelHeight = '157' })
        f:tick()
        equal(tonumber(f.vars.PanelHeightPx), 152, 'the old saved height left 5px under the graph')
        f.vars.IOMinPanelHeight = '170'
        f:tick()
        equal(tonumber(f.vars.PanelHeightPx), 170, 'the new key still raises the minimum')
        f.vars.IOMinPanelHeight = '100'
        f:tick()
        equal(tonumber(f.vars.PanelHeightPx), 152, 'and never shrinks below the drive rows')
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
        equal(f:text('MeterIODiskReadC'), '1.0 MB/s')
        equal(f:text('MeterIODiskWriteD'), '3.0 MB/s', 'display signs must not change positive speed text')
        truth(not f.groups.IORatesE, 'split must not sample unselected drives')
        equal(f.shown.MeterIOLegendC, false)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 151)
        equal(tonumber(f.vars.PanelHeightPx), 215)
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
        -- Reads peaked at 2 MB/s and writes at 4 MB/s, so the autoscaler gives writes
        -- 65% of the usable height (zero 22.3 px down from the 2 px inset); a current
        -- null still plots on whatever baseline the zero line has moved to.
        near(traces[1].points[2].y, 22.3)
        near(traces[2].points[2].y, 22.3)
        near(tonumber(f.options.MeterIOGraphZero.Y) + 7 - tonumber(f.options.MeterIODiskGraph.Y), 22.3,
            'the 0 marker follows the zero line')
        truth(traces[1].points[1].y < 22.3 and traces[2].points[1].y > 22.3)
        truth(traces[1].points[2].x - traces[1].points[1].x > 10,
            'missed observations must preserve their time positions')
        contains(traces[1].shape, 'Path IOHistoryPath')
        equal(f:text('MeterIODiskReadC'), '--')
        equal(f:text('MeterIODiskWriteC'), '--')
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = math.huge, 0
        for _ = 1, 60 do f:tick() end
        for _, trace in ipairs(f:traces()) do
            equal(#trace.points, 60)
            equal(trace.points[1].x, 2)
            equal(trace.points[60].x, 206)
            for _, point in ipairs(trace.points) do equal(point.y, 31, 'expired peaks must leave the zero baseline') end
        end
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
            equal(f:text('MeterIODiskReadC'), '100 MB/s', 'the split cap must not clip rate text')
            equal(f:traces()[1].points[1].y, inset)
            equal(f:traces()[2].points[1].y, height - inset)
            contains(f.options.MeterIODiskGraphTrack.Shape3, 'Stroke Color #MutedColor#')
            -- Both directions need the whole capped range, so zero stays at the midpoint.
            contains(f.options.MeterIODiskGraphTrack.Shape3, string.format('Line 1,%.3f,', height / 2))
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
        equal(small:traces()[1].points[1].y, 2)
        equal(small:traces()[2].points[1].y, 60)
        small.vars.IODiskMaxMiBs = 'invalid'
        small:tick()
        equal(#small:traces(), 0)
        equal(small.shown.MeterIODiskGraph, false)
        equal(small:text('MeterIODiskReadC'), '1.0 MB/s')
    end)

    test('split autoscale divides the fixed-height graph by direction at one shared scale', function()
        local function zeroOf(f, scale)
            return tonumber(f.options.MeterIOGraphZero.Y) + 7 * (scale or 1) - tonumber(f.options.MeterIODiskGraph.Y)
        end
        -- Quiet or equal traffic keeps zero on the exact frame midpoint.
        local quiet = fixture({ IOGraphMode = 'split' }, { MeasureIODiskReadC = 0, MeasureIODiskWriteC = 0 })
        near(zeroOf(quiet), 31)
        local panel, graphY = quiet.vars.PanelHeightPx, quiet.options.MeterIODiskGraph.Y
        local equalTraffic = fixture({ IOGraphMode = 'split' }, { MeasureIODiskReadC = 5e6, MeasureIODiskWriteC = 5e6 })
        near(zeroOf(equalTraffic), 31)
        -- Reads 4x writes: reads get 80% of the need, clamped to the 75% maximum (zero 45.5).
        local f = fixture({ IOGraphMode = 'split' }, { MeasureIODiskReadC = 40e6, MeasureIODiskWriteC = 10e6 })
        near(zeroOf(f), 45.5)
        -- The panel and graph box are untouched; only the division inside the frame moved.
        equal(f.vars.PanelHeightPx, panel, 'panel height must not change')
        equal(f.options.MeterIODiskGraph.Y, graphY, 'graph position must not change')
        local read, write = f:traces()[1].points[1].y, f:traces()[2].points[1].y
        -- One scale: pixels per byte match above and below zero.
        local ratio = (45.5 - read) / (write - 45.5)
        near(ratio, 4, 'read:write pixels must equal read:write bytes')
        truth(read >= 2 and write <= 60, 'traces stay inside the inset frame')
        -- Writes 2x reads: share .333 snaps to .35, zero 22.3 (moves up).
        local w = fixture({ IOGraphMode = 'split' }, { MeasureIODiskReadC = 10e6, MeasureIODiskWriteC = 20e6 })
        near(zeroOf(w), 22.3)
        -- Slightly unequal traffic snaps to the 5% grid, so small peak changes do not move zero.
        local steady = fixture({ IOGraphMode = 'split' }, { MeasureIODiskReadC = 10e6, MeasureIODiskWriteC = 10.2e6 })
        near(zeroOf(steady), 31)
        -- Moving zero sends one update; a stable split then sends nothing for it.
        f:tick()
        local before = #f.calls
        f:tick()
        for index = before + 1, #f.calls do
            local call = f.calls[index]
            truth(call[2] ~= 'MeterIOGraphZero' and call[2] ~= 'MeterIODiskGraphTrack',
                'a stable zero line must not resend its options')
        end
        -- When the busy direction scrolls out of the 60-sample history, zero returns to the middle.
        f.values.MeasureIODiskReadC, f.values.MeasureIODiskWriteC = 0, 0
        for _ = 1, 60 do f:tick() end
        near(zeroOf(f), 31)
        for _, trace in ipairs(f:traces()) do
            for _, point in ipairs(trace.points) do near(point.y, 31) end
        end
        -- Leaving split restores the grid-colored centered line and hides the markers.
        f.vars.IOGraphMode = 'combined'
        f:tick()
        contains(f.options.MeterIODiskGraphTrack.Shape3, 'Stroke Color #GridColor#')
        contains(f.options.MeterIODiskGraphTrack.Shape3, '(#IOGraphHeight#*#Scale#/2)')
        -- Fractional scales: the 0 marker box stays centered on the moved line.
        for _, scale in ipairs({0.75, 1.25, 2}) do
            local g = fixture({ IOGraphMode = 'split', Scale = tostring(scale), ContentWidth = tostring(168 * scale),
                Inset = tostring(4 * scale), ContentX = tostring(10 * scale) },
                { MeasureIODiskReadC = 40e6, MeasureIODiskWriteC = 10e6 })
            local inset, height = math.max(2, 2 * scale), 62 * scale
            near(zeroOf(g, scale), inset + (height - 2 * inset) * .75)
            local box = tonumber(g.options.MeterIOGraphZero.Y) - tonumber(g.options.MeterIODiskGraph.Y)
            truth(box >= 0 and box + 14 * scale <= height + .001, 'marker box stays inside the frame')
        end
    end)

    test('split mode transitions reset history while metadata reflow preserves observations and empty scope stays blank', function()
        local f = fixture(nil, { MeasureIODiskReadC = 1e6 })
        f:tick()
        equal(#f:traces()[1].points, 2)
        f.vars.IOGraphMode = 'split'
        f:tick()
        equal(#f:traces()[1].points, 1)
        -- Read-only traffic: reads take the maximum 75% share, so zero sits 45.5 px down.
        equal(f:traces()[2].points[1].y, 45.5)
        f.vars.DataBarThickness = '12'
        local before = #f.calls
        f:applyNamesMode()
        equal(#f:traces()[1].points, 1, 'cached split reflow must not add an observation')
        near(tonumber(f.options.MeterIOGraphZero.Y), 132.5, 'the moved zero marker survives a layout reflow')
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
        equal(tonumber(f.options.MeterIODiskGraph.Y), 88)
        equal(tonumber(f.vars.PanelHeightPx), 152)
        equal(f.groups.IORatesC, false)
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
                        local pitch = 63 + extra
                        local legendColumns = math.max(1, math.floor(width / (26 * scale)))
                        local legendRows = mode == 'overlay' and math.ceil(26 / legendColumns) or 0
                        local f = fixture({ IODiskDrives = 'all', IOGraphMode = mode, Scale = tostring(scale),
                            Inset = tostring(inset), Gap = tostring(2 * inset), ContentX = tostring(inset + 6 * scale),
                            ContentWidth = tostring(width), DataBarThicknessPx = tostring(bar) }, samples)
                        local expectedGraph = inset + (84 + extra + 25 * pitch + legendRows * 18) * scale
                        local expectedHeight = math.floor((152 + extra + 25 * pitch + legendRows * 18) * scale + 0.5)
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
                            local rowY = inset + (24 + index * pitch) * scale
                            local barY = inset + (42 + index * pitch) * scale + math.max(0, (6 * scale - bar) / 2)
                            local rateY = inset + (49 + extra + index * pitch) * scale
                            truth(math.abs(tonumber(f.options['MeterIODrive' .. letter].Y) - rowY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIOCapacity' .. letter].Y) - rateY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIOUsed' .. letter].Y) - barY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIODiskRead' .. letter].Y) - rateY) < 0.001)
                            truth(math.abs(tonumber(f.options['MeterIODiskWriteLabel' .. letter].Y) - rateY - 18 * scale) < 0.001)
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

    test('drive names stay above bars with stacked speeds, load and capacity in every name mode', function()
        local f = fixture({ IODriveNames = 'volume', IODiskDrives = 'C,D' }, {
            MeasureIONameC = 'System', MeasureIONameD = 'Archive', MeasureIOTypeD = 4,
            MeasureIOTotalD = 1e9, MeasureIOFreeD = 5e8, MeasureIODiskReadC = 1e6 })
        equal(f:text('MeterIODriveC'), 'C: System')
        equal(f:text('MeterIODriveD'), 'D: Archive')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(tonumber(f.options.MeterIOCapacityC.W), 91.06)
        equal(tonumber(f.options.MeterIODriveC.Y), 28)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 53)
        equal(tonumber(f.options.MeterIOUsedC.Y), 46)
        equal(tonumber(f.options.MeterIODiskReadC.Y), 53)
        equal(tonumber(f.options.MeterIODiskWriteC.Y), 69)
        equal(tonumber(f.options.MeterIOGaugeC.Y), 54)
        equal(tonumber(f.options.MeterIOLoadC.Y), 69)
        equal(tonumber(f.options.MeterIODriveD.Y), 91)
        equal(tonumber(f.options.MeterIOCapacityD.Y), 116)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 151)
        equal(tonumber(f.vars.PanelHeightPx), 215)
        checkInlineCells(f, 'C', 1, 208, 10)
        checkInlineCells(f, 'D', 1, 208, 10)
        equal(f.queryRuns, 0)
        local longName = 'Archive ' .. string.rep('long name ', 8)
        f.values.MeasureIONameC = longName
        f:tick()
        contains(f:text('MeterIODriveC'), 'Archive long name')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(#f:traces()[1].points, 2)
        f.vars.IODriveNames = 'letters'
        local before = #f.calls
        equal(f:applyNamesMode(), 0)
        equal(f:text('MeterIODriveC'), 'C:')
        equal(tonumber(f.options.MeterIODriveC.W), 208)
        equal(tonumber(f.options.MeterIOCapacityC.W), 91.06)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 53)
        equal(tonumber(f.options.MeterIODriveD.Y), 91)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 151)
        equal(tonumber(f.vars.PanelHeightPx), 215)
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
        equal(f:text('MeterIOLegendC'), 'C:')
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
        equal(tonumber(f.options.MeterIODiskGraph.Y), 169)
        equal(tonumber(f.vars.PanelHeightPx), 233)
        f.vars.IODiskDrives, f.vars.IOGraphMode = 'none', 'c'
        f.vars.DataBarThickness = '12'
        f:tick()
        equal(f.shown.MeterIOEmpty, true)
        equal(tonumber(f.options.MeterIODriveC.Y), 0)
        equal(tonumber(f.options.MeterIOCapacityC.Y), 0)
        equal(tonumber(f.options.MeterIODiskGraph.Y), 88)
        equal(tonumber(f.vars.PanelHeightPx), 152, 'empty selection must not reserve name or bar rows')
        equal(#f:traces(), 2)
        equal(f.queryRuns, 1)
        f.vars.IODriveNames = 'invalid'
        f.vars.IODiskDrives = 'C'
        f.vars.DataBarThickness = '6'
        f:tick()
        equal(f:text('MeterIODriveC'), 'C: System')
        equal(tonumber(f.vars.PanelHeightPx), 152)
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
                        local pitch = 63 + extra
                        local legendColumns = math.max(1, math.floor(width / (26 * scale)))
                        local legendRows = math.ceil(count / legendColumns)
                        local f = fixture({ IODriveNames = mode, IODiskDrives = count == 1 and 'C' or 'all',
                            IOGraphMode = 'overlay', Scale = tostring(scale), Inset = tostring(inset),
                            Gap = tostring(2 * inset), ContentX = tostring(inset + 6 * scale), ContentWidth = tostring(width),
                            DataBarThicknessPx = tostring(bar) }, samples)
                        local expectedGraph = inset + (84 + extra + (count - 1) * pitch + legendRows * 18) * scale
                        local expectedHeight = math.floor((152 + extra + (count - 1) * pitch + legendRows * 18) * scale + 0.5)
                        truth(math.abs(tonumber(f.options.MeterIODiskGraph.Y) - expectedGraph) < 0.001)
                        equal(tonumber(f.vars.PanelHeightPx), expectedHeight)
                        equal(tonumber(f.options.MeterIOBounds.H), expectedHeight + 2 * inset)
                        equal(f.queryRuns, mode == 'volume' and 0 or 1)
                        for code = 65, 90 do
                            local letter = string.char(code)
                            if count == 26 or letter == 'C' then
                                local index = letter == 'C' and 0 or (code < 67 and code - 64 or code - 65)
                                checkInlineCells(f, letter, scale, width, inset + 6 * scale)
                                truth(math.abs(tonumber(f.options['MeterIODrive' .. letter].Y) - inset - (24 + index * pitch) * scale) < 0.001)
                                local barY = inset + (42 + index * pitch) * scale + math.max(0, (6 * scale - bar) / 2)
                                local rateY = inset + (49 + extra + index * pitch) * scale
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
        equal(tonumber(f.options.MeterIODiskGraph.Y), 88)
        equal(tonumber(f.vars.PanelHeightPx), 152)
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
