-- Original Parallax GPU process table regressions for native Rainmeter Lua 5.1.
-- Fixtures expose five ranked engine instances, five exact named memory
-- lookups, validated name packets and time. Rows are grouped by PID; only
-- meter text, bounded row visibility and the bounded memory lookups may
-- change. No files, geometry, redraw requests or process actions are permitted.
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
    local function absent(value, fragment, label)
        ok(not tostring(value):find(fragment, 1, true), label or ('unexpected ' .. fragment))
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
    local noMemory = '__ParallaxNoGPUProcess__'
    local idleText = 'No active GPU process data'
    local sourceRanks = {MeasureGPUActivity = 1, MeasureGPUProcess2 = 2,
        MeasureGPUProcess3 = 3, MeasureGPUProcess4 = 4, MeasureGPUProcess5 = 5}
    local function fixture(rows, options)
        options = options or {}
        local f = {rows = rows or {}, calls = {}, options = {}, reads = {}, visible = {},
            now = options.now or 1000, names = options.names or '', missingNames = options.missingNames,
            nameReads = 0, nameLookups = 0, memory = {}, memoryLookups = {},
            memoryValues = options.memoryValues or {}, missingMemory = {},
            updateFailures = {}, readFailures = {}, frozenMemory = {},
            lookups = {}, variableReads = {}, variables = {}}
        for key, value in pairs(options.variables or {}) do f.variables[key] = value end
        for slot = 1, 5 do
            f.memory[slot] = {name = noMemory, enabled = false,
                returnedName = '', bytes = 0, updates = 0, reads = 0}
        end
        function f:refreshMemory(slot)
            local source = self.memory[slot]
            if not source.enabled or self.frozenMemory[slot] then return end
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
            local memorySlot = tonumber(name:match('^MeasureGPUProcessMemory([1-5])$'))
            if memorySlot then
                f.memoryLookups[memorySlot] = (f.memoryLookups[memorySlot] or 0) + 1
                if f.missingMemory[memorySlot] then return nil end
                return {
                    GetStringValue = function()
                        if f.readFailures[memorySlot] then error('counter cache unavailable') end
                        f.memory[memorySlot].reads = f.memory[memorySlot].reads + 1
                        return f.memory[memorySlot].returnedName
                    end,
                    GetValue = function() return f.memory[memorySlot].bytes end
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
            assert(name == 'MetricsInterval' or name == 'SensorInterval', 'unexpected variable access: ' .. tostring(name))
            f.variableReads[name] = (f.variableReads[name] or 0) + 1
            return f.variables[name] or fallback
        end
        function skin:ReplaceVariables() error('unexpected geometry expansion') end
        function skin:ParseFormula() error('unexpected geometry formula') end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = {command = command, args = args}
            if command == '!SetOption' then
                assert(#args == 3 and type(args[3]) == 'string', 'option must be one scalar string')
                local memorySlot = tonumber(args[1]:match('^MeasureGPUProcessMemory([1-5])$'))
                if memorySlot then
                    assert(args[2] == 'Name' and #args[3] > 0, 'memory lookup changes only nonempty Name')
                    f.memory[memorySlot].name = args[3]
                    return
                end
                local kind, slot = args[1]:match('^MeterGPUProcess(%a+)([1-5])$')
                assert(slot and (kind == 'Name' or kind == 'Value' or kind == 'Memory'), 'unexpected meter write')
                assert(args[2] == 'Text' or args[2] == 'ToolTipText', 'unexpected option write')
                f.options[args[1]] = f.options[args[1]] or {}
                f.options[args[1]][args[2]] = args[3]
            elseif command == '!EnableMeasure' or command == '!DisableMeasure' or command == '!UpdateMeasure' then
                local slot = #args == 1 and tonumber(args[1]:match('^MeasureGPUProcessMemory([1-5])$'))
                assert(slot, 'only bounded named memory lookups may be changed')
                if command == '!UpdateMeasure' then
                    if f.updateFailures[slot] then error('forced update unavailable') end
                    f.memory[slot].updates = f.memory[slot].updates + 1
                    f:refreshMemory(slot)
                else
                    f.memory[slot].enabled = command == '!EnableMeasure'
                end
            elseif command == '!ShowMeterGroup' or command == '!HideMeterGroup' then
                local slot = #args == 1 and tonumber(args[1]:match('^GPUProcessRow([1-5])$'))
                assert(slot, 'only bounded process rows may change visibility')
                f.visible[slot] = command == '!ShowMeterGroup'
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
            for slot = 1, 5 do self:refreshMemory(slot) end
            self.value, self.request = self.env.Update(); return self.value, self.request
        end
        function f:text(kind, slot) return (self.options['MeterGPUProcess' .. kind .. slot] or {}).Text end
        function f:tip(kind, slot) return (self.options['MeterGPUProcess' .. kind .. slot] or {}).ToolTipText end
        -- Every dispatched call other than row visibility.
        function f:writes()
            local result = {}
            for _, call in ipairs(self.calls) do
                if call.command ~= '!ShowMeterGroup' and call.command ~= '!HideMeterGroup' then result[#result + 1] = call end
            end
            return result
        end
        function f:clear() self.calls, self.reads = {}, {} end
        env.Initialize(); f:update()
        return f
    end
    -- Rows 1..count are visible; an empty ranking still shows row 1.
    local function shown(f, count, label)
        for slot = 1, 5 do eq(f.visible[slot], slot <= math.max(count, 1), (label or 'row visibility') .. ' ' .. slot) end
    end
    local function idle(f)
        eq(f:text('Name', 1), idleText, 'empty ranking label')
        eq(f:text('Value', 1), '--', 'empty percentage')
        eq(f:text('Memory', 1), '--', 'empty memory')
        for _, kind in ipairs({'Name', 'Value', 'Memory'}) do
            contains(f:tip(kind, 1), 'No ranked GPU process-engine observation', kind .. ' idle tooltip')
        end
        shown(f, 0, 'idle visibility')
        eq(f.request, '?', 'idle name request')
        for slot = 1, 5 do eq(f.memory[slot].enabled, false, 'idle memory lookup ' .. slot) end
    end

    test('ranks group by PID at their busiest engine percentage in rank order', function()
        local f = fixture({
            {name = instance(11, '3D'), value = 75},
            {name = instance(11, 'Copy'), value = 30},
            {name = instance(33, 'VideoDecode'), value = 25.24},
            {name = instance(44, 'Compute'), value = 10},
            {name = instance(55, '3D', '0x00000000_0x00000002'), value = 5}
        })
        for rank = 1, 5 do eq(f.reads[rank], rank, 'read order') end
        eq(#f.reads, 5, 'bounded reads')
        local labels, percentages = {'PID 11', 'PID 33', 'PID 44', 'PID 55'}, {'75.0%', '25.2%', '10.0%', '5.0%'}
        for slot = 1, 4 do
            eq(f:text('Name', slot), labels[slot]); eq(f:text('Value', slot), percentages[slot])
            eq(f:tip('Value', slot), f:tip('Name', slot), 'name and percentage share one tooltip')
            contains(f:tip('Name', slot), 'across all exposed GPUs, not a sum')
            contains(f:tip('Name', slot), 'is unavailable; showing its PID.')
            contains(f:tip('Name', slot), 'sample age is not exposed')
        end
        contains(f:tip('Name', 1), 'Busiest engine for this process: 3D at 75.0%.')
        contains(f:tip('Name', 1), 'Also observed here: Copy 30.0%.')
        contains(f:tip('Name', 2), 'Busiest engine for this process: VideoDecode at 25.2%.')
        for slot = 2, 4 do absent(f:tip('Name', slot), 'Also observed here') end
        shown(f, 4)
        eq(f.request, '11,33,44,55')
    end)
    test('small positive values remain visible as positive percentages and 100 is valid', function()
        local f = fixture({{name = instance(1), value = 100}, {name = instance(1, 'Copy'), value = 0.05},
            {name = instance(2), value = 0.001}})
        eq(f:text('Value', 1), '100.0%'); eq(f:text('Value', 2), '<0.1%')
        contains(f:tip('Name', 1), 'Also observed here: Copy <0.1%.')
        contains(f:tip('Name', 2), 'at <0.1%.')
        shown(f, 2)
    end)
    test('name requests are bounded sorted unique positive uint32 PIDs from valid active ranks', function()
        local f = fixture({{name = instance('00011', 'Copy'), value = 25},
            {name = instance(2), value = 20}, {name = instance(11), value = 15},
            {name = instance(4294967295), value = 10}, {name = instance(77), value = 0}})
        eq(f.value, 0); eq(f.request, '2,11,4294967295')
        eq(f:text('Name', 1), 'PID 11', 'leading zeros are canonical and merge with the same PID')
        eq(f:text('Name', 2), 'PID 2'); eq(f:text('Name', 3), 'PID 4294967295'); shown(f, 3)
        local invalid = {'0', '4294967296', '-1', '1e3', '1.5', string.rep('9', 17)}
        for _, pid in ipairs(invalid) do
            f.rows = {{name = instance(pid), value = 20}}; f:update()
            idle(f)
        end
        f.rows = {{name = instance(11), value = 101}, {name = instance(12), value = 0},
            {name = 'app.exe', value = 25}, false, {name = instance(14), value = 0/0}}
        f:update(); idle(f)
        f.rows = {}; for rank = 1, 5 do f.rows[rank] = {name = instance(6 - rank), value = 6 - rank} end
        f:update(); eq(f.request, '1,2,3,4,5'); shown(f, 5)
        for slot = 1, 5 do eq(f:text('Name', slot), 'PID ' .. (6 - slot)) end
    end)
    test('Windows basenames label grouped processes without changing their percentages', function()
        local f = fixture({{name = instance(11, '3D'), value = 75}, {name = instance(11, 'Copy'), value = 30},
            {name = instance(22, 'VideoDecode'), value = 25}},
            {names = packet({{11, 'example.exe'}, {22, 'example.exe'}})})
        eq(f:text('Name', 1), 'example.exe'); eq(f:text('Value', 1), '75.0%')
        eq(f:text('Name', 2), 'example.exe', 'identical executable names remain separate PIDs')
        eq(f:text('Value', 2), '25.0%')
        contains(f:tip('Name', 1), 'Current Windows name lookup for PID 11: example.exe.')
        contains(f:tip('Name', 2), 'Current Windows name lookup for PID 22: example.exe.')
        shown(f, 2); eq(f.request, '11,22'); eq(f.nameReads, 1)
        f:clear(); f:update(); eq(#f:writes(), 0, 'unchanged names dispatch no writes')
        eq(f.nameReads, 2); eq(f.nameLookups, 1)
    end)
    test('delayed, removed and unavailable lookups fall back to the current PID without retained names', function()
        local f = fixture({{name = instance(11), value = 75}}, {names = packet({{11, 'before.exe'}})})
        eq(f:text('Name', 1), 'before.exe')
        f.rows[1] = {name = instance(22), value = 30}; f:update()
        eq(f:text('Name', 1), 'PID 22'); eq(f.request, '22'); eq(f:text('Value', 1), '30.0%')
        f.names = packet({{22, 'current.exe'}}); f:update(); eq(f:text('Name', 1), 'current.exe')
        -- Exit/access failure/PID reuse is withheld by the resident resolver.
        -- A removed entry must never survive in a renderer-side PID cache.
        for _, unavailable in ipairs({packet(), '', 'GPU_NAMES|1|991|22,' .. hex('old.exe')}) do
            f.names = unavailable; f:update()
            eq(f:text('Name', 1), 'PID 22'); eq(f:text('Value', 1), '30.0%')
            contains(f:tip('Name', 1), 'name lookup for PID 22 is unavailable')
        end
        f = fixture({{name = instance(11), value = 75}}, {missingNames = true})
        eq(f:text('Name', 1), 'PID 11'); eq(f.nameReads, 0)
        f.missingNames = false; f.names = packet({{11, 'available.exe'}}); f:update()
        eq(f:text('Name', 1), 'available.exe'); eq(f.nameLookups, 2)
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
            eq(f:text('Name', 1), 'PID 11'); eq(f:text('Value', 1), '25.0%')
            eq(f.request, '11')
        end
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}})})
        f.names = 123; f:update(); eq(f:text('Name', 1), 'PID 11')
    end)
    test('name freshness respects collection cadence, inclusive boundaries and clock rollback', function()
        local cases = {{1000, 2000, 8}, {5000, 2000, 17}, {30001, 2000, 92},
            {300, 400, 8}, {'bad', 'bad', 8}, {'1e309', 2000, 8}}
        for _, values in ipairs(cases) do
            local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}}),
                variables = {MetricsInterval = tostring(values[1]), SensorInterval = tostring(values[2])}})
            f.now = 1000 + values[3]; f:update(); eq(f:text('Name', 1), 'valid.exe')
            f.now = f.now + 1; f:update(); eq(f:text('Name', 1), 'PID 11')
            f.now = 995; f:update(); eq(f:text('Name', 1), 'valid.exe')
            f.now = 994; f:update(); eq(f:text('Name', 1), 'PID 11')
        end
    end)
    test('strict UTF8 basenames are byte-bounded and display metacharacters cannot become actions', function()
        local unicode = string.char(195, 169, 240, 159, 154, 128) .. '.exe'
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, unicode}})})
        eq(f:text('Name', 1), unicode)
        for _, valid in ipairs({string.rep('a', 128), string.rep(string.char(195, 169), 64), 'name#[!Refresh]".exe'}) do
            f.names = packet({{11, valid}}); f:update()
            ok(f:text('Name', 1) ~= 'PID 11')
            for _, text in ipairs({f:text('Name', 1), f:tip('Name', 1)}) do ok(not text:find('[#%[%]"%c]')) end
            eq(f:text('Value', 1), '25.0%')
        end
        eq(f:text('Name', 1), "name(!Refresh)'.exe")
        local invalid = {'', ' ', '.', '..', 'C:\\private\\app.exe', '/private/app.exe',
            'name\0.exe', 'name\n.exe', string.char(127), string.char(194, 128),
            string.char(192, 128), string.char(237, 160, 128), string.char(244, 144, 128, 128),
            string.char(195), string.char(128), string.rep('a', 129), string.rep(string.char(195, 169), 65)}
        for _, name in ipairs(invalid) do
            f.names = packet({{11, 'valid.exe'}, {22, name}}); f:update()
            eq(f:text('Name', 1), 'PID 11'); eq(f:text('Value', 1), '25.0%'); eq(f.request, '11')
        end
    end)
    test('missing idle empty and undefined observations never fabricate zero percent', function()
        local f = fixture({false, {name = '', value = 32}, {name = '0', value = 10},
            {name = instance(4), value = 0}, {name = instance(5)}})
        idle(f)
        for slot = 1, 5 do absent(f:text('Value', slot), '0.0%', 'no fabricated zero in row ' .. slot) end
    end)
    test('negative over-range nonnumeric NaN and infinite values are rejected without occupying a row', function()
        for _, value in ipairs({-1, 100.001, '25', 0/0, math.huge, -math.huge}) do
            local f = fixture({{name = instance(1), value = value}})
            idle(f)
            f.rows[2] = {name = instance(2), value = 40}; f:update()
            eq(f:text('Name', 1), 'PID 2', 'rejected rank does not occupy a row')
            eq(f:text('Value', 1), '40.0%'); shown(f, 1); eq(f.request, '2')
        end
    end)
    test('renamed merged and incomplete counter identities are rejected', function()
        for _, name in ipairs({'example.exe', 'pid_8_eng_0_engtype_3D',
            'luid_0_phys_0_eng_0_engtype_3D', 'pid_8_luid_0_phys_0_engtype_3D'}) do
            idle(fixture({{name = name, value = 20}}))
        end
        local f = fixture({{name = 'pid_8_luid_0_phys_0_eng_0_engtype_', value = 20}})
        eq(f:text('Name', 1), 'PID 8', 'missing engine label retains valid raw identity')
        contains(f:tip('Name', 1), 'Busiest engine for this process: unknown engine at 20.0%.')
        eq(f:text('Memory', 1), '--', 'abbreviated adapter identity cannot select memory')
        contains(f:tip('Memory', 1), 'No exact active PID / adapter / physical GPU identity')
    end)
    test('provider display text is sanitized and cannot dispatch actions', function()
        local f = fixture({{name = instance(1, '3D[#danger#]"\n[!Execute cmd]'), value = 25}})
        eq(f:text('Name', 1), 'PID 1')
        contains(f:tip('Name', 1), "Busiest engine for this process: 3D(danger)' (!Execute cmd) at 25.0%.")
        for _, kind in ipairs({'Name', 'Value', 'Memory'}) do
            for _, text in ipairs({f:text(kind, 1), f:tip(kind, 1)}) do
                ok(not text:find('[#%[%]"%c]'), kind .. ' display metacharacters removed')
            end
        end
    end)
    test('idle and invalid transitions hide extra rows and release their memory lookups', function()
        local f = fixture({{name = instance(1), value = 75}, {name = instance(2), value = 50},
            {name = instance(3), value = 25}})
        shown(f, 3)
        for slot = 1, 3 do eq(f.memory[slot].enabled, true, 'active lookup ' .. slot) end
        f.rows[3] = {name = '', value = 0}; f:update()
        shown(f, 2); eq(f.memory[3].enabled, false); eq(f.memory[3].name, noMemory)
        f.rows[1] = {name = '', value = 0}; f.rows[2] = {name = instance(2), value = 101}; f:update()
        idle(f)
        for slot = 1, 3 do eq(f.memory[slot].name, noMemory, 'released lookup ' .. slot) end
    end)
    test('unchanged observations write no options or lookups and only restate row visibility', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f:update()
        eq(#f:writes(), 0, 'deduplicated presentation')
        eq(#f.reads, 5, 'one read per existing rank per update')
        for rank = 1, 5 do eq(f.lookups[rank], 1, 'cached measure reference') end
        shown(f, 1)
        f:clear(); f.rows[1].value = 25; f:update()
        eq(f:text('Value', 1), '25.0%')
        local writes = f:writes()
        eq(#writes, 3, 'percentage text and its shared tooltip only')
        for _, call in ipairs(writes) do
            eq(call.command, '!SetOption', 'only changed text is written')
            ok(call.args[1] == 'MeterGPUProcessName1' or call.args[1] == 'MeterGPUProcessValue1', 'only the changed row is written')
        end
    end)
    test('reinitialization discards references, bindings and rendering cache', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f.env.Initialize(); f:update()
        ok(#f:writes() > 0, 'initial presentation reapplied')
        for rank = 1, 5 do eq(f.lookups[rank], 2, 'reference reacquired') end
        eq(f.memory[1].updates, 2, 'memory binding refreshed after reinitialization')
        f.rows[1] = {name = instance(22, 'Copy'), value = 10}
        f.env.Initialize(); f:update()
        eq(f:text('Name', 1), 'PID 22'); eq(f:text('Value', 1), '10.0%')
        contains(f:tip('Name', 1), 'Copy at 10.0%.')
    end)
    test('late available measures are acquired without resetting other ranks', function()
        local f = fixture({false})
        idle(f)
        f.rows[1] = {name = instance(1), value = 50}; f:update()
        eq(f:text('Name', 1), 'PID 1'); eq(f:text('Value', 1), '50.0%')
        eq(f.lookups[1], 2)
        eq(f.lookups[2], 1)
    end)
    test('the table reads only cadence variables and never geometry', function()
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}})})
        eq(f:text('Name', 1), 'valid.exe')
        eq(f.variableReads.MetricsInterval, 1); eq(f.variableReads.SensorInterval, 1)
    end)

    local function memoryKey(raw)
        return assert(raw:match('^(.-)_eng_%d+_engtype_'))
    end
    test('dedicated memory binds each row to its busiest engine exact PID adapter physical prefix', function()
        local secondAdapter = '0x00000000_0x00000002'
        local rows = {{name = instance(11), value = 25}, {name = instance(11, 'Copy', secondAdapter), value = 20},
            {name = instance(22, '3D', secondAdapter), value = 15},
            {name = instance(33):gsub('_phys_0_', '_phys_1_'), value = 10},
            {name = instance(44), value = 5}}
        local values = {}
        values[memoryKey(rows[1].name)] = 123 * 1048576
        values[memoryKey(rows[2].name)] = 999 * 1048576
        values[memoryKey(rows[3].name)] = 1.25 * 1073741824
        values[memoryKey(rows[4].name)] = 512
        values[memoryKey(rows[5].name)] = 1073741824
        local f = fixture(rows, {memoryValues = values})
        local bound, labels = {rows[1], rows[3], rows[4], rows[5]}, {'129 MB', '1.34 GB', '512 B', '1.07 GB'}
        for slot = 1, 4 do
            local key = memoryKey(bound[slot].name)
            eq(f.memory[slot].name, key); eq(f.memory[slot].returnedName, key)
            eq(f.memory[slot].enabled, true); eq(f.memory[slot].updates, 1)
            eq(f:text('Memory', slot), labels[slot])
            local tip = f:tip('Memory', slot)
            contains(tip, key); contains(tip, string.format('%.0f bytes', values[key]))
            contains(tip, 'not to one engine'); contains(tip, 'do not sum those rows')
            contains(tip, 'Cross-process shared allocations'); contains(tip, 'Shared RAM system-memory row')
            contains(tip, 'sample age is not exposed')
        end
        contains(f:tip('Name', 1), 'Also observed here: Copy 20.0%.')
        absent(f:tip('Memory', 1), memoryKey(rows[2].name), 'merged lower engine does not select another adapter')
        eq(f.memory[5].enabled, false); eq(f.memory[5].name, noMemory); shown(f, 4)
        eq(f.request, '11,22,33,44', 'memory does not change name request PID set')
        f:clear(); f:update(); eq(#f:writes(), 0, 'unchanged binding and presentation dispatch nothing')
        for slot = 1, 4 do eq(f.memory[slot].updates, 1); eq(f.memoryLookups[slot], 1) end
        eq(f.memoryLookups[5], nil, 'hidden row never reads a memory counter')
    end)
    test('row replacement forces refreshed binding and never borrows prior PID adapter bytes', function()
        local first, second = instance(11), instance(22)
        local otherGpu = instance(22, 'Copy', '0x00000000_0x000000FF')
        local f = fixture({{name = first, value = 25}}, {memoryValues = {
            [memoryKey(first)] = 100 * 1048576, [memoryKey(second)] = 200 * 1048576,
            [memoryKey(otherGpu)] = 300 * 1048576}})
        f:clear(); f.rows[1] = {name = second, value = 30}; f:update()
        eq(f.calls[1].command, '!SetOption'); eq(f.calls[1].args[1], 'MeasureGPUProcessMemory1')
        eq(f.calls[1].args[3], memoryKey(second))
        eq(f.calls[2].command, '!EnableMeasure'); eq(f.calls[3].command, '!UpdateMeasure')
        eq(f:text('Memory', 1), '210 MB'); eq(f.memory[1].updates, 2)
        f.rows[1] = {name = otherGpu, value = 35}; f:update()
        eq(f:text('Memory', 1), '315 MB'); eq(f.memory[1].updates, 3)
        f.frozenMemory[1] = true; f.rows[1] = {name = first, value = 40}; f:update()
        eq(f.memory[1].returnedName, memoryKey(otherGpu), 'simulate failed stale plugin cache')
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '40.0%')
        contains(f:tip('Memory', 1), 'exact requested instance')
        f.frozenMemory[1] = false; f:update(); eq(f:text('Memory', 1), '105 MB')
    end)
    test('zero missing malformed and unsupported byte readings never claim measured zero', function()
        local row = instance(11)
        local f = fixture({{name = row, value = 25}})
        eq(f.memory[1].returnedName, memoryKey(row), 'absent named lookup echoes requested name')
        eq(f:text('Memory', 1), '--')
        for _, value in ipairs({0, -1, 1.5, 9007199254740992, '123', 0/0, math.huge, -math.huge}) do
            f.memoryValues[memoryKey(row)] = value; f:update()
            eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '25.0%')
            contains(f:tip('Memory', 1), 'cannot be distinguished')
        end
        for _, case in ipairs({{1, '1 B'}, {999, '999 B'}, {1000, '1 KB'}, {12345678, '12 MB'},
            {2500000000, '2.50 GB'}, {3000000000000, '3.00 TB'}}) do
            f.memoryValues[memoryKey(row)] = case[1]; f:update()
            eq(f:text('Memory', 1), case[2], 'decimal size ' .. case[1])
        end
        f.memoryValues[memoryKey(row)] = 9007199254740991; f:update()
        contains(f:tip('Memory', 1), '9007199254740991 bytes')
    end)
    test('idle and malformed memory identities disable old lookup and cannot select a total', function()
        local row = instance(11)
        -- Valid ranked engine identities without an exact adapter / physical-node prefix.
        local rowOnly = {'pid_11_luid_0_phys_0_eng_0_engtype_3D',
            instance(11, '3D', '0x00000000_0x000000001'), instance(11, '3D', '0x00000000_0x0000000G'),
            (row:gsub('_phys_0_', '_phys_4294967296_')), (row:gsub('_phys_0_', '_phys_-1_')),
            (row:gsub('_eng_0_', '_eng_4294967296_'))}
        -- Not ranked engine identities at all.
        local rejected = {(row:gsub('_eng_0_', '_eng_1e3_')), string.rep('x', 1025), '', '0', 'example.exe'}
        for _, list in ipairs({rowOnly, rejected}) do
            for _, name in ipairs(list) do
                local f = fixture({{name = row, value = 25}}, {memoryValues = {[memoryKey(row)] = 1048576}})
                f:clear(); f.rows[1] = {name = name, value = 25}; f:update()
                eq(f:text('Memory', 1), '--'); eq(f.memory[1].enabled, false)
                eq(f.memory[1].name, noMemory); eq(f.memory[1].updates, 1)
                eq(f.calls[1].command, '!DisableMeasure'); eq(f.calls[2].command, '!SetOption')
                if list == rowOnly then
                    eq(f:text('Name', 1), 'PID 11'); eq(f:text('Value', 1), '25.0%')
                    contains(f:tip('Memory', 1), 'No exact active PID / adapter / physical GPU identity')
                else
                    idle(f)
                end
                f:clear(); f:update(); eq(#f:writes(), 0, 'invalid stable identity dispatches nothing')
            end
        end
        local f = fixture({{name = row, value = 25}})
        f.rows[1].value = 0; f:update(); idle(f)
        eq(f.memory[1].name, noMemory)
        f.rows[1].value = 25; f:update(); eq(f.memory[1].enabled, true); eq(f.memory[1].updates, 2)
        eq(f:text('Name', 1), 'PID 11'); shown(f, 1)
    end)
    test('missing references forced update failures and read failures remain local to memory', function()
        local first, second = instance(11), instance(22)
        local f = fixture({{name = first, value = 25}}, {memoryValues = {[memoryKey(first)] = 1048576,
            [memoryKey(second)] = 2 * 1048576}})
        f.readFailures[1] = true; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '25.0%'); eq(f.request, '11')
        f.readFailures[1] = false; f:update(); eq(f:text('Memory', 1), '1 MB')
        f.updateFailures[1] = true; f.rows[1] = {name = second, value = 30}; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Name', 1), 'PID 22')
        contains(f:tip('Memory', 1), 'could not be rebound')
        f.updateFailures[1] = false; f:update(); eq(f:text('Memory', 1), '2 MB')
        f = fixture({})
        f.missingMemory[1] = true; f.rows[1] = {name = first, value = 25}; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '25.0%')
        f.missingMemory[1] = false; f.memoryValues[memoryKey(first)] = 1048576; f:update()
        eq(f:text('Memory', 1), '1 MB'); eq(f.memoryLookups[1], 2)
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
