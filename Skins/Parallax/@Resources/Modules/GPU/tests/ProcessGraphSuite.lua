-- Original Parallax GPU process graph regressions for native Rainmeter Lua 5.1.
-- Fixtures expose five engine ranks, five exact named memory lookups, validated
-- name packets, time and shared geometry. No files or process actions are permitted.
local Suite = {}

function Suite.run(path)
    local total, failed, lines = 0, 0, {}
    local function eq(actual, expected, label)
        total = total + 1
        if actual ~= expected then
            error((label or 'value') .. ': expected ' .. tostring(expected)
                .. ', got ' .. tostring(actual), 2)
        end
    end
    local function ok(value, label) eq(not not value, true, label) end
    local function contains(value, fragment, label)
        ok(tostring(value):find(fragment, 1, true), label or fragment)
    end
    local function test(name, body)
        local pass, err = pcall(body)
        lines[#lines + 1] = (pass and 'PASS: ' or 'FAIL: ') .. name
            .. (pass and '' or ': ' .. tostring(err))
        if not pass then failed = failed + 1 end
    end
    local function instance(pid, engine, luid)
        return 'pid_' .. pid .. '_luid_' .. (luid or '0x00000000_0x00000001')
            .. '_phys_0_eng_0_engtype_' .. (engine or '3D')
    end
    local function hex(value)
        return (value:gsub('.', function(character) return string.format('%02X', character:byte()) end))
    end
    local function packet(entries, epoch)
        local records = {}
        for _, entry in ipairs(entries or {}) do records[#records + 1] = tostring(entry[1]) .. ',' .. hex(entry[2]) end
        return 'GPU_NAMES|1|' .. tostring(epoch or 1000) .. '|' .. (#records > 0 and table.concat(records, ';') or '?')
    end
    local sourceRanks = {MeasureGPUActivity = 1, MeasureGPUProcess2 = 2,
        MeasureGPUProcess3 = 3, MeasureGPUProcess4 = 4, MeasureGPUProcess5 = 5}
    local function fixture(rows, options)
        options = options or {}
        local f = {rows = rows or {}, calls = {}, options = {}, reads = {},
            now = options.now or 1000, names = options.names or '', missingNames = options.missingNames,
            nameReads = 0, nameLookups = 0, memory = {}, memoryLookups = {},
            memoryValues = options.memoryValues or {}, missingMemory = {},
            updateFailures = {}, readFailures = {}, frozenMemory = {},
            lookups = {}, variables = {Scale = '1', ContentWidth = '200', DataBarThickness = '6',
                DataBarThicknessPx = '(Max(1,Round(#DataBarThickness#*#Scale#)))'}}
        for key, value in pairs(options.variables or {}) do f.variables[key] = value end
        for rank = 1, 5 do
            f.memory[rank] = {name = '__ParallaxNoGPUProcess__', enabled = false,
                returnedName = '', bytes = 0, updates = 0, reads = 0}
        end
        function f:refreshMemory(rank)
            local source = self.memory[rank]
            if not source.enabled or self.frozenMemory[rank] then return end
            local result = self.memoryValues[source.name]
            source.returnedName = type(result) == 'table' and result.name or source.name
            source.bytes = type(result) == 'table' and result.bytes or result or 0
        end
        local skin = {}
        function skin:GetMeasure(name)
            if name == 'MeasureGPUTemperatureController' then
                f.nameLookups = f.nameLookups + 1
                if f.missingNames then return nil end
                return {GetStringValue = function() f.nameReads = f.nameReads + 1; return f.names end}
            end
            local memoryRank = tonumber(name:match('^MeasureGPUProcessMemory([1-5])$'))
            if memoryRank then
                f.memoryLookups[memoryRank] = (f.memoryLookups[memoryRank] or 0) + 1
                if f.missingMemory[memoryRank] then return nil end
                return {
                    GetStringValue = function()
                        if f.readFailures[memoryRank] then error('counter cache unavailable') end
                        f.memory[memoryRank].reads = f.memory[memoryRank].reads + 1
                        return f.memory[memoryRank].returnedName
                    end,
                    GetValue = function() return f.memory[memoryRank].bytes end
                }
            end
            local rank = assert(sourceRanks[name], 'unexpected counter access: ' .. tostring(name))
            f.lookups[rank] = (f.lookups[rank] or 0) + 1
            if f.rows[rank] == false then return nil end
            local source = {}
            function source:GetStringValue()
                f.reads[#f.reads + 1] = rank
                return (f.rows[rank] or {}).name or ''
            end
            function source:GetValue() return (f.rows[rank] or {}).value end
            return source
        end
        function skin:GetVariable(name, fallback)
            assert(name == 'DataBarThicknessPx' or name == 'ContentWidth'
                or name == 'MetricsInterval' or name == 'SensorInterval', 'unexpected variable access')
            return f.variables[name] or fallback
        end
        function skin:ReplaceVariables(raw)
            if raw == '(#PanelWidth#-2*#Padding#)' then return '(220-2*10)' end
            assert(raw == '(Max(1,Round(#DataBarThickness#*#Scale#)))', 'unexpected geometry expansion')
            return '(Max(1,Round(' .. f.variables.DataBarThickness .. '*' .. f.variables.Scale .. ')))'
        end
        function skin:ParseFormula(raw)
            if raw == '((220-2*10))' then return 200 end
            assert(raw == '((Max(1,Round(' .. f.variables.DataBarThickness .. '*'
                .. f.variables.Scale .. '))))', 'unexpected geometry formula')
            local thickness, scale = tonumber(f.variables.DataBarThickness), tonumber(f.variables.Scale)
            return thickness and scale and math.max(1, math.floor(thickness * scale + 0.5)) or nil
        end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = {command = command, args = args}
            if command == '!SetOption' then
                assert(#args == 3 and type(args[3]) == 'string', 'option must be one scalar string')
                local memoryRank = tonumber(args[1]:match('^MeasureGPUProcessMemory([1-5])$'))
                if memoryRank then
                    assert(args[2] == 'Name' and #args[3] > 0, 'memory lookup changes only nonempty Name')
                    f.memory[memoryRank].name = args[3]
                    return
                end
                local kind, rank = args[1]:match('^MeterGPUProcess(%a+)([1-5])$')
                assert(rank and (kind == 'Name' or kind == 'Value' or kind == 'Bar' or kind == 'Memory'), 'unexpected meter write')
                assert(args[2] == 'ToolTipText' or (kind == 'Bar' and args[2] == 'Shape2')
                    or (kind ~= 'Bar' and args[2] == 'Text'), 'unexpected option write')
                f.options[args[1]] = f.options[args[1]] or {}
                f.options[args[1]][args[2]] = args[3]
            elseif command == '!EnableMeasure' or command == '!DisableMeasure' or command == '!UpdateMeasure' then
                local rank = #args == 1 and tonumber(args[1]:match('^MeasureGPUProcessMemory([1-5])$'))
                assert(rank, 'only bounded named memory lookups may be changed')
                if command == '!UpdateMeasure' then
                    if f.updateFailures[rank] then error('forced update unavailable') end
                    f.memory[rank].updates = f.memory[rank].updates + 1
                    f:refreshMemory(rank)
                else
                    f.memory[rank].enabled = command == '!EnableMeasure'
                end
            elseif command == '!UpdateMeterGroup' then
                assert(#args == 1 and args[1] == 'GPUProcessGraph', 'unexpected group')
            elseif command == '!Redraw' then
                assert(#args == 0, 'unexpected redraw arguments')
            else
                error('unexpected action or external work: ' .. tostring(command))
            end
        end
        local function forbidden() error('unexpected external work') end
        local blocked = setmetatable({}, {__index = function() return forbidden end})
        local fakeos = setmetatable({time = function() return f.now end}, {__index = function() return forbidden end})
        local env = setmetatable({SKIN = skin, SELF = {}, os = fakeos, io = blocked,
            package = blocked, debug = blocked, require = forbidden,
            dofile = forbidden, loadfile = forbidden, loadstring = forbidden}, {__index = _G})
        env._G = env
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
        f.env = env
        function f:update()
            for rank = 1, 5 do self:refreshMemory(rank) end
            self.value, self.request = self.env.Update(); return self.value, self.request
        end
        function f:text(kind, rank) return self.options['MeterGPUProcess' .. kind .. rank].Text end
        function f:tip(rank) return self.options['MeterGPUProcessName' .. rank].ToolTipText end
        function f:bar(rank)
            local shape = self.options['MeterGPUProcessBar' .. rank].Shape2
            local y, endpoint, y2, stroke = shape:match('^Line 0,([%d.]+),([%d.]+),([%d.]+) | StrokeWidth ([%d.]+)')
            assert(y and y == y2, 'invalid horizontal bar geometry')
            return tonumber(endpoint), tonumber(stroke), tonumber(y)
        end
        function f:clear() self.calls, self.reads = {}, {} end
        env.Initialize(); f:update()
        return f
    end
    local function empty(f, rank)
        eq(f:text('Name', rank), '--', 'empty name')
        eq(f:text('Value', rank), '--', 'empty percentage')
        eq(f:text('Memory', rank), 'VRAM: --', 'empty memory')
        local endpoint, stroke = f:bar(rank)
        eq(endpoint, 0, 'empty bar width')
        eq(stroke, 0, 'empty bar stroke')
    end

    test('exact counter ranks retain individual PID engine identities and percentages', function()
        local f = fixture({
            {name = instance(11, '3D'), value = 75},
            {name = instance(11, 'Copy'), value = 30},
            {name = instance(33, 'VideoDecode'), value = 25.24},
            {name = instance(44, 'Compute'), value = 5},
            {name = instance(55, '3D', '0x00000000_0x00000002'), value = 10}
        })
        local percentages = {'75.0%', '30.0%', '25.2%', '5.0%', '10.0%'}
        local labels = {'PID 11 / 3D', 'PID 11 / Copy', 'PID 33 / VideoDecode', 'PID 44 / Compute', 'PID 55 / 3D'}
        for rank = 1, 5 do
            eq(f.reads[rank], rank, 'read order')
            eq(f:text('Name', rank), labels[rank])
            eq(f:text('Value', rank), percentages[rank])
            local endpoint, stroke, y = f:bar(rank)
            eq(endpoint, f.rows[rank].value * 2, 'independent bar width')
            eq(stroke, 6); eq(y, 3)
            contains(f:tip(rank), f.rows[rank].name, 'complete instance in tooltip')
            contains(f:tip(rank), 'across all exposed GPUs')
            contains(f:tip(rank), 'not total process or adapter usage')
            contains(f:tip(rank), 'sample age is not exposed')
        end
        eq(#f.reads, 5, 'bounded reads')
    end)
    test('small positive values remain visible as positive percentages and 100 is valid', function()
        local f = fixture({{name = instance(1), value = 0.001}, {name = instance(2), value = 100}})
        eq(f:text('Value', 1), '<0.1%')
        eq(f:bar(1), 0.002)
        eq(f:text('Value', 2), '100.0%')
        eq(f:bar(2), 200)
    end)
    test('name requests are bounded sorted unique positive uint32 PIDs from valid active ranks', function()
        local f = fixture({{name = instance('00011', 'Copy'), value = 10},
            {name = instance(2), value = 20}, {name = instance(11), value = 15},
            {name = instance(4294967295), value = 25}, {name = instance(77), value = 0}})
        eq(f.value, 0); eq(f.request, '2,11,4294967295')
        local invalid = {'0', '4294967296', '-1', '1e3', '1.5', string.rep('9', 17)}
        for _, pid in ipairs(invalid) do
            f.rows = {{name = instance(pid), value = 20}}; f:update()
            eq(f.request, '?'); empty(f, 1)
        end
        f.rows = {{name = instance(11), value = 101}, {name = instance(12), value = 0},
            {name = 'app.exe', value = 25}, false, {name = instance(14), value = 0/0}}
        f:update(); eq(f.request, '?')
        f.rows = {}; for rank = 1, 5 do f.rows[rank] = {name = instance(6 - rank), value = rank} end
        f:update(); eq(f.request, '1,2,3,4,5')
    end)
    test('Windows basenames decorate independent engine ranks without changing their percentages', function()
        local f = fixture({{name = instance(11, '3D'), value = 75}, {name = instance(11, 'Copy'), value = 30},
            {name = instance(22, 'VideoDecode'), value = 25}},
            {names = packet({{11, 'example.exe'}, {22, 'example.exe'}})})
        for rank, label in ipairs({'example.exe / 3D', 'example.exe / Copy', 'example.exe / VideoDecode'}) do
            eq(f:text('Name', rank), label)
            eq(f:bar(rank), f.rows[rank].value * 2)
            contains(f:tip(rank), f.rows[rank].name)
            contains(f:tip(rank), 'Current Windows name lookup for PID ' .. (rank == 3 and '22' or '11'))
            contains(f:tip(rank), 'sample age is not exposed')
        end
        eq(f:text('Value', 1), '75.0%'); eq(f:text('Value', 2), '30.0%'); eq(f:text('Value', 3), '25.0%')
        eq(f.request, '11,22'); eq(f.nameReads, 1)
        f:clear(); f:update(); eq(#f.calls, 0); eq(f.nameReads, 2); eq(f.nameLookups, 1)
    end)
    test('delayed, removed and unavailable lookups fall back to the current PID without retained names', function()
        local f = fixture({{name = instance(11), value = 75}}, {names = packet({{11, 'before.exe'}})})
        eq(f:text('Name', 1), 'before.exe / 3D')
        f.rows[1] = {name = instance(22), value = 30}; f:update()
        eq(f:text('Name', 1), 'PID 22 / 3D'); eq(f.request, '22'); eq(f:bar(1), 60)
        f.names = packet({{22, 'current.exe'}}); f:update(); eq(f:text('Name', 1), 'current.exe / 3D')
        -- Exit/access failure/PID reuse is withheld by the resident resolver.
        -- A removed entry must never survive in a renderer-side PID cache.
        for _, unavailable in ipairs({packet(), '', 'GPU_NAMES|1|991|22,' .. hex('old.exe')}) do
            f.names = unavailable; f:update()
            eq(f:text('Name', 1), 'PID 22 / 3D'); eq(f:text('Value', 1), '30.0%'); eq(f:bar(1), 60)
            contains(f:tip(1), 'name lookup for PID 22 is unavailable')
        end
        f = fixture({{name = instance(11), value = 75}}, {missingNames = true})
        eq(f:text('Name', 1), 'PID 11 / 3D'); eq(f.nameReads, 0)
        f.missingNames = false; f.names = packet({{11, 'available.exe'}}); f:update()
        eq(f:text('Name', 1), 'available.exe / 3D'); eq(f.nameLookups, 2)
    end)
    test('stale, future, malformed and duplicate maps invalidate all names but no valid counter', function()
        local prefix = 'GPU_NAMES|1|1000|'
        local first = '11,' .. hex('valid.exe')
        local bad = {'', '0', 'OTHER|1|1000|' .. first, 'GPU_NAMES|2|1000|' .. first,
            'GPU_NAMES|1|0|' .. first, 'GPU_NAMES|1|1e3|' .. first, 'GPU_NAMES|1|1000.0|' .. first,
            'GPU_NAMES|1|-1|' .. first, 'GPU_NAMES|1|9007199254740992|' .. first,
            'GPU_NAMES|1|991|' .. first, 'GPU_NAMES|1|1006|' .. first,
            prefix .. first .. '|extra', prefix .. first .. ';', prefix .. ';' .. first,
            prefix .. first .. ';11,' .. hex('conflict.exe'), prefix .. first .. ';011,' .. hex('conflict.exe'),
            prefix .. first .. ';0,' .. hex('zero.exe'), prefix .. first .. ';4294967296,' .. hex('overflow.exe'),
            prefix .. first .. ';1e2,' .. hex('exponent.exe'), prefix .. first .. ';22,ABC',
            prefix .. first .. ';22,GG', prefix .. first .. ';22,', prefix .. first .. ';malformed',
            prefix .. first .. ';22,3F;33,3F;44,3F;55,3F;66,3F', string.rep('x', 2049)}
        for _, value in ipairs(bad) do
            local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'old.exe'}})})
            f.names = value; f:update()
            eq(f:text('Name', 1), 'PID 11 / 3D'); eq(f:text('Value', 1), '25.0%'); eq(f:bar(1), 50)
            eq(f.request, '11')
        end
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}})})
        f.names = 123; f:update(); eq(f:text('Name', 1), 'PID 11 / 3D')
    end)
    test('name freshness respects collection cadence, inclusive boundaries and clock rollback', function()
        local cases = {{1000, 2000, 8}, {5000, 2000, 17}, {30001, 2000, 92},
            {300, 400, 8}, {'bad', 'bad', 8}, {'1e309', 2000, 8}}
        for _, values in ipairs(cases) do
            local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}}),
                variables = {MetricsInterval = tostring(values[1]), SensorInterval = tostring(values[2])}})
            f.now = 1000 + values[3]; f:update(); eq(f:text('Name', 1), 'valid.exe / 3D')
            f.now = f.now + 1; f:update(); eq(f:text('Name', 1), 'PID 11 / 3D')
            f.now = 995; f:update(); eq(f:text('Name', 1), 'valid.exe / 3D')
            f.now = 994; f:update(); eq(f:text('Name', 1), 'PID 11 / 3D')
        end
    end)
    test('strict UTF8 basenames are byte-bounded and display metacharacters cannot become actions', function()
        local unicode = string.char(195, 169, 240, 159, 154, 128) .. '.exe'
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, unicode}})})
        eq(f:text('Name', 1), unicode .. ' / 3D')
        for _, valid in ipairs({string.rep('a', 128), string.rep(string.char(195, 169), 64), 'name#[!Refresh]".exe'}) do
            f.names = packet({{11, valid}}); f:update()
            ok(f:text('Name', 1) ~= 'PID 11 / 3D')
            for _, text in ipairs({f:text('Name', 1), f:tip(1)}) do ok(not text:find('[#%[%]"%c]')) end
            eq(f:bar(1), 50)
        end
        local invalid = {'', ' ', '.', '..', 'C:\\private\\app.exe', '/private/app.exe',
            'name\0.exe', 'name\n.exe', string.char(127), string.char(194, 128),
            string.char(192, 128), string.char(237, 160, 128), string.char(244, 144, 128, 128),
            string.char(195), string.char(128), string.rep('a', 129), string.rep(string.char(195, 169), 65)}
        for _, name in ipairs(invalid) do
            f.names = packet({{11, 'valid.exe'}, {22, name}}); f:update()
            eq(f:text('Name', 1), 'PID 11 / 3D'); eq(f:bar(1), 50); eq(f.request, '11')
        end
    end)
    test('missing idle empty and undefined observations never fabricate zero percent', function()
        local f = fixture({false, {name = '', value = 32}, {name = '0', value = 10},
            {name = instance(4), value = 0}, {name = instance(5)}})
        for rank = 1, 5 do empty(f, rank) end
    end)
    test('negative over-range nonnumeric NaN and infinite values are rejected', function()
        for _, value in ipairs({-1, 100.001, '25', 0/0, math.huge, -math.huge}) do
            local f = fixture({{name = instance(1), value = value}})
            empty(f, 1)
            contains(f:tip(1), 'usable percentage')
        end
    end)
    test('renamed merged and incomplete counter identities are rejected', function()
        for _, name in ipairs({'example.exe', 'pid_8_eng_0_engtype_3D',
            'luid_0_phys_0_eng_0_engtype_3D', 'pid_8_luid_0_phys_0_engtype_3D'}) do
            local f = fixture({{name = name, value = 20}})
            empty(f, 1)
            contains(f:tip(1), 'Expected a raw PID / adapter / engine instance')
        end
        local f = fixture({{name = 'pid_8_luid_0_phys_0_eng_0_engtype_', value = 20}})
        eq(f:text('Name', 1), 'PID 8', 'missing engine label retains valid raw identity')
    end)
    test('provider display text is sanitized and cannot alter bar geometry or dispatch actions', function()
        local name = instance(1, '3D[#danger#]"\n[!Execute cmd]')
        local f = fixture({{name = name, value = 25}})
        eq(f:text('Name', 1), "PID 1 / 3D(danger)' (!Execute cmd)")
        for _, text in ipairs({f:text('Name', 1), f:tip(1)}) do
            ok(not text:find('[#%[%]"%c]'), 'display metacharacters removed')
        end
        eq(f:bar(1), 50)
        contains(f.options.MeterGPUProcessBar1.Shape2, 'Stroke Color #GPUColor#')
        contains(f.options.MeterGPUProcessBar1.Shape2, 'StrokeStartCap Flat | StrokeEndCap Flat')
    end)
    test('idle and invalid transitions clear previous colored bars and labels', function()
        local f = fixture({{name = instance(1), value = 75}, {name = instance(2), value = 50}})
        f.rows[1] = {name = '', value = 0}
        f.rows[2] = {name = instance(2), value = 101}
        f.env.Update()
        empty(f, 1); empty(f, 2)
    end)
    test('unchanged observations avoid all meter writes updates and redraws', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f.env.Update()
        eq(#f.calls, 0, 'deduplicated presentation')
        eq(#f.reads, 5, 'one read per existing rank per update')
        for rank = 1, 5 do eq(f.lookups[rank], 1, 'cached measure reference') end
        f.rows[1].value = 25; f.env.Update()
        eq(f:bar(1), 50)
        eq(f.calls[#f.calls - 1].command, '!UpdateMeterGroup')
        eq(f.calls[#f.calls].command, '!Redraw')
    end)
    test('reinitialization discards references and rendering cache', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f.env.Initialize(); f.env.Update()
        ok(#f.calls > 0, 'initial presentation reapplied')
        for rank = 1, 5 do eq(f.lookups[rank], 2, 'reference reacquired') end
        f.rows[1] = {name = instance(22, 'Copy'), value = 10}
        f.env.Initialize(); f.env.Update()
        eq(f:text('Name', 1), 'PID 22 / Copy')
        eq(f:bar(1), 20)
    end)
    test('late available measures are acquired without resetting other ranks', function()
        local f = fixture({false})
        empty(f, 1)
        f.rows[1] = {name = instance(1), value = 50}
        f.env.Update()
        eq(f:text('Value', 1), '50.0%')
        eq(f:bar(1), 100)
        eq(f.lookups[1], 2)
        eq(f.lookups[2], 1)
    end)
    test('shared scale and formula width resolve before numeric bar geometry', function()
        local f = fixture({{name = instance(1), value = 50}})
        f.variables.Scale = '1.5'
        f.variables.ContentWidth = '(#PanelWidth#-2*#Padding#)'
        f.env.Update()
        local endpoint, stroke, y = f:bar(1)
        eq(endpoint, 100); eq(stroke, 9); eq(y, 4.5)
        f.variables.ContentWidth = '300'; f.env.Update()
        eq(f:bar(1), 150)
    end)
    test('shared data-bar thickness rounds to physical pixels while preserving percentages', function()
        local f = fixture({{name = instance(1), value = 50}, {name = instance(2), value = 100}})
        for _, scale in ipairs({0.75, 1, 2}) do
            for _, thickness in ipairs({1, 6, 12}) do
                f.variables.Scale, f.variables.DataBarThickness = tostring(scale), tostring(thickness)
                f.env.Update()
                local endpoint, stroke, y = f:bar(1)
                local physical = math.max(1, math.floor(thickness * scale + 0.5))
                eq(endpoint, 100); eq(stroke, physical); eq(y, physical / 2)
                eq(f:text('Value', 1), '50.0%')
                eq(f:bar(2), 200, 'full-width bar remains within its track')
                empty(f, 3)
            end
        end
        f:clear(); f.env.Update()
        eq(#f.calls, 0, 'unchanged thickness and telemetry remain deduplicated')
    end)
    test('invalid or nonfinite dimensions cannot produce colored geometry', function()
        local f = fixture({{name = instance(1), value = 50}})
        for _, value in ipairs({'0', '-1', 'unresolved', '1e999'}) do
            f.variables.ContentWidth = value; f.env.Update()
            local endpoint, stroke = f:bar(1)
            eq(endpoint, 0); eq(stroke, 0)
            eq(f:text('Value', 1), '50.0%', 'known telemetry retained')
        end
        f.variables.ContentWidth = '200'; f.variables.Scale = '1e999'; f.env.Update()
        local endpoint, stroke = f:bar(1)
        eq(endpoint, 0); eq(stroke, 0)
        f.variables.Scale = '1'
        for _, value in ipairs({'0', '-1', 'unresolved', '1e999'}) do
            f.variables.DataBarThicknessPx = value; f.env.Update()
            endpoint, stroke = f:bar(1)
            eq(endpoint, 0); eq(stroke, 0)
            eq(f:text('Value', 1), '50.0%', 'invalid thickness does not replace known telemetry')
        end
    end)

    local function memoryKey(raw)
        return assert(raw:match('^(.-)_eng_%d+_engtype_'))
    end
    test('dedicated memory binds exact PID adapter physical prefix before reading raw bytes', function()
        local rows = {{name = instance(11), value = 25}, {name = instance(11, 'Copy'), value = 10},
            {name = instance(11, '3D', '0x00000000_0x00000002'), value = 20},
            {name = instance(22):gsub('_phys_0_', '_phys_1_'), value = 15},
            {name = instance(33), value = 5}}
        local values = {}
        values[memoryKey(rows[1].name)] = 123 * 1048576
        values[memoryKey(rows[3].name)] = 1.25 * 1073741824
        values[memoryKey(rows[4].name)] = 512
        values[memoryKey(rows[5].name)] = 1073741824
        local f = fixture(rows, {memoryValues = values})
        local labels = {'VRAM: 123 MiB', 'VRAM: 123 MiB', 'VRAM: 1.25 GiB', 'VRAM: <1 MiB', 'VRAM: 1.00 GiB'}
        for rank = 1, 5 do
            local key = memoryKey(rows[rank].name)
            eq(f.memory[rank].name, key); eq(f.memory[rank].returnedName, key)
            eq(f.memory[rank].enabled, true); eq(f.memory[rank].updates, 1)
            eq(f:text('Memory', rank), labels[rank]); eq(f:bar(rank), rows[rank].value * 2)
            local tip = f.options['MeterGPUProcessMemory' .. rank].ToolTipText
            contains(tip, key); contains(tip, string.format('%.0f bytes', values[key]))
            contains(tip, 'not to one engine'); contains(tip, 'do not sum those rows')
            contains(tip, 'Cross-process shared allocations'); contains(tip, 'Shared RAM system-memory row')
            contains(tip, 'sample age is not exposed')
        end
        eq(f.request, '11,22,33', 'memory does not change name request PID set')
        f:clear(); f:update(); eq(#f.calls, 0, 'unchanged binding and presentation dispatch nothing')
        for rank = 1, 5 do eq(f.memory[rank].updates, 1); eq(f.memoryLookups[rank], 1) end
    end)
    test('row replacement forces refreshed binding and never borrows prior PID adapter bytes', function()
        local first, second = instance(11), instance(22)
        local otherGpu = instance(22, 'Copy', '0x00000000_0x000000FF')
        local f = fixture({{name = first, value = 25}}, {memoryValues = {
            [memoryKey(first)] = 100 * 1048576, [memoryKey(second)] = 200 * 1048576,
            [memoryKey(otherGpu)] = 300 * 1048576}})
        f:clear(); f.rows[1] = {name = second, value = 30}; f:update()
        eq(f.calls[1].command, '!SetOption'); eq(f.calls[1].args[3], memoryKey(second))
        eq(f.calls[2].command, '!EnableMeasure'); eq(f.calls[3].command, '!UpdateMeasure')
        eq(f:text('Memory', 1), 'VRAM: 200 MiB'); eq(f.memory[1].updates, 2)
        f.rows[1] = {name = otherGpu, value = 35}; f:update()
        eq(f:text('Memory', 1), 'VRAM: 300 MiB'); eq(f.memory[1].updates, 3)
        f.frozenMemory[1] = true; f.rows[1] = {name = first, value = 40}; f:update()
        eq(f.memory[1].returnedName, memoryKey(otherGpu), 'simulate failed stale plugin cache')
        eq(f:text('Memory', 1), 'VRAM: --'); eq(f:text('Value', 1), '40.0%'); eq(f:bar(1), 80)
        contains(f.options.MeterGPUProcessMemory1.ToolTipText, 'exact requested instance')
        f.frozenMemory[1] = false; f:update(); eq(f:text('Memory', 1), 'VRAM: 100 MiB')
    end)
    test('zero missing malformed and unsupported byte readings never claim measured zero', function()
        local row = instance(11)
        local f = fixture({{name = row, value = 25}})
        eq(f.memory[1].returnedName, memoryKey(row), 'absent named lookup echoes requested name')
        eq(f:text('Memory', 1), 'VRAM: --')
        for _, value in ipairs({0, -1, 1.5, 9007199254740992, '123', 0/0, math.huge, -math.huge}) do
            f.memoryValues[memoryKey(row)] = value; f:update()
            eq(f:text('Memory', 1), 'VRAM: --'); eq(f:text('Value', 1), '25.0%')
            contains(f.options.MeterGPUProcessMemory1.ToolTipText, 'cannot be distinguished')
        end
        f.memoryValues[memoryKey(row)] = 1; f:update(); eq(f:text('Memory', 1), 'VRAM: <1 MiB')
        f.memoryValues[memoryKey(row)] = 9007199254740991; f:update()
        contains(f.options.MeterGPUProcessMemory1.ToolTipText, '9007199254740991 bytes')
    end)
    test('idle and malformed memory identities disable old lookup and cannot select a total', function()
        local row = instance(11)
        local invalid = {'pid_11_luid_0_phys_0_eng_0_engtype_3D',
            instance(11, '3D', '0x00000000_0x000000001'),
            instance(11, '3D', '0x00000000_0x0000000G'),
            row:gsub('_phys_0_', '_phys_4294967296_'), row:gsub('_phys_0_', '_phys_-1_'),
            row:gsub('_eng_0_', '_eng_4294967296_'), row:gsub('_eng_0_', '_eng_1e3_'),
            string.rep('x', 1025), '', '0', 'example.exe'}
        for _, name in ipairs(invalid) do
            local f = fixture({{name = row, value = 25}}, {memoryValues = {[memoryKey(row)] = 1048576}})
            f:clear(); f.rows[1] = {name = name, value = 25}; f:update()
            eq(f:text('Memory', 1), 'VRAM: --'); eq(f.memory[1].enabled, false)
            eq(f.memory[1].name, '__ParallaxNoGPUProcess__'); eq(f.memory[1].updates, 1)
            eq(f.calls[1].command, '!DisableMeasure'); eq(f.calls[2].command, '!SetOption')
            f:clear(); f:update(); eq(#f.calls, 0, 'invalid stable identity dispatches nothing')
        end
        local f = fixture({{name = row, value = 25}})
        f.rows[1].value = 0; f:update(); empty(f, 1)
        eq(f.memory[1].enabled, false); eq(f.memory[1].name, '__ParallaxNoGPUProcess__')
        f.rows[1].value = 25; f:update(); eq(f.memory[1].enabled, true); eq(f.memory[1].updates, 2)
    end)
    test('missing references forced update failures and read failures remain local to memory', function()
        local first, second = instance(11), instance(22)
        local f = fixture({{name = first, value = 25}}, {memoryValues = {[memoryKey(first)] = 1048576,
            [memoryKey(second)] = 2 * 1048576}})
        f.readFailures[1] = true; f:update()
        eq(f:text('Memory', 1), 'VRAM: --'); eq(f:bar(1), 50); eq(f.request, '11')
        f.readFailures[1] = false; f:update(); eq(f:text('Memory', 1), 'VRAM: 1 MiB')
        f.updateFailures[1] = true; f.rows[1] = {name = second, value = 30}; f:update()
        eq(f:text('Memory', 1), 'VRAM: --'); eq(f:text('Name', 1), 'PID 22 / 3D')
        contains(f.options.MeterGPUProcessMemory1.ToolTipText, 'could not be rebound')
        f.updateFailures[1] = false; f:update(); eq(f:text('Memory', 1), 'VRAM: 2 MiB')
        f = fixture({})
        f.missingMemory[1] = true; f.rows[1] = {name = first, value = 25}; f:update()
        eq(f:text('Memory', 1), 'VRAM: --'); eq(f:bar(1), 50)
        f.missingMemory[1] = false; f.memoryValues[memoryKey(first)] = 1048576; f:update()
        eq(f:text('Memory', 1), 'VRAM: 1 MiB'); eq(f.memoryLookups[1], 2)
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
