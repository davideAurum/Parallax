-- Original Parallax GPU process table regressions for native Rainmeter Lua 5.1.
-- ProcessGraph.lua reads five ranked process-engine counters, groups them by PID
-- into at most five Name / Value / Memory rows (busiest engine, never a sum),
-- shows or hides the GPUProcessRow<N> groups, decorates rows from validated name
-- packets and binds five exact named memory lookups. Fixtures resolve every
-- measure through one name-keyed table (unknown names return nil), expose a
-- controllable clock, and permit no files or process actions.
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
    local function lacks(value, fragment, label)
        ok(not tostring(value):find(fragment, 1, true), label or ('no ' .. fragment))
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
    local function memoryKey(raw)
        return assert(raw:match('^(.-)_eng_%d+_engtype_'))
    end
    local function hex(value)
        return (value:gsub('.', function(character) return string.format('%02X', character:byte()) end))
    end
    local function packet(entries, epoch)
        local records = {}
        for _, entry in ipairs(entries or {}) do records[#records + 1] = tostring(entry[1]) .. ',' .. hex(entry[2]) end
        return 'GPU_NAMES|1|' .. tostring(epoch or 1000) .. '|' .. (#records > 0 and table.concat(records, ';') or '?')
    end
    local sourceNames = {'MeasureGPUActivity', 'MeasureGPUProcess2',
        'MeasureGPUProcess3', 'MeasureGPUProcess4', 'MeasureGPUProcess5'}
    local noMemory = '__ParallaxNoGPUProcess__'
    local unsafe = '[#%[%]"%c]'

    -- A plain measure mock whose fields tests may change in place, e.g. a
    -- RunCommand status/output pair: f:setMeasure('MeasureGPUInfo', {value = 0, text = '...'}).
    local function plainMeasure(spec)
        local mock = {value = spec.value, text = spec.text, valueReads = 0, textReads = 0}
        function mock:GetValue() self.valueReads = self.valueReads + 1; return self.value end
        function mock:GetStringValue() self.textReads = self.textReads + 1; return self.text end
        return mock
    end

    -- options: names, missingNames, memoryValues, variables, now (number or
    -- function), measures = {Name = {value =, text =} | mock | provider | false},
    -- bangs = {['!Command'] = function(f, args) end} for additional allowed bangs.
    local function fixture(rows, options)
        options = options or {}
        local f = {rows = rows or {}, calls = {}, options = {}, reads = {}, visible = {},
            now = options.now or 1000, names = options.names or '', missingNames = options.missingNames,
            nameReads = 0, nameLookups = 0, memory = {}, memoryLookups = {},
            memoryValues = options.memoryValues or {}, missingMemory = {},
            updateFailures = {}, readFailures = {}, frozenMemory = {},
            lookups = {}, measures = {}, measureLookups = {}, bangs = options.bangs or {},
            variables = {}}
        for key, value in pairs(options.variables or {}) do f.variables[key] = value end
        for rank = 1, 5 do
            f.memory[rank] = {name = noMemory, enabled = false,
                returnedName = '', bytes = 0, updates = 0, reads = 0}
        end
        function f:refreshMemory(rank)
            local source = self.memory[rank]
            if not source.enabled or self.frozenMemory[rank] then return end
            local result = self.memoryValues[source.name]
            source.returnedName = type(result) == 'table' and result.name or source.name
            source.bytes = type(result) == 'table' and result.bytes or result or 0
        end
        -- Measures by exact name. A provider function runs on every GetMeasure
        -- and may return nil; a table is returned as is; absent names are nil.
        function f:setMeasure(name, spec)
            if not spec then self.measures[name] = nil; return nil end
            if type(spec) == 'table' and type(spec.GetValue) ~= 'function'
                and type(spec.GetStringValue) ~= 'function' then spec = plainMeasure(spec) end
            self.measures[name] = spec
            return spec
        end
        for rank, name in ipairs(sourceNames) do
            f.measures[name] = function()
                f.lookups[rank] = (f.lookups[rank] or 0) + 1
                if f.rows[rank] == false then return nil end
                return {
                    GetStringValue = function()
                        f.reads[#f.reads + 1] = rank
                        return (f.rows[rank] or {}).name or ''
                    end,
                    GetValue = function() return (f.rows[rank] or {}).value end
                }
            end
        end
        f.measures.MeasureGPUTemperatureController = function()
            f.nameLookups = f.nameLookups + 1
            if f.missingNames then return nil end
            return {GetStringValue = function() f.nameReads = f.nameReads + 1; return f.names end}
        end
        for rank = 1, 5 do
            f.measures['MeasureGPUProcessMemory' .. rank] = function()
                f.memoryLookups[rank] = (f.memoryLookups[rank] or 0) + 1
                if f.missingMemory[rank] then return nil end
                return {
                    GetStringValue = function()
                        if f.readFailures[rank] then error('counter cache unavailable') end
                        f.memory[rank].reads = f.memory[rank].reads + 1
                        return f.memory[rank].returnedName
                    end,
                    GetValue = function() return f.memory[rank].bytes end
                }
            end
        end
        for name, spec in pairs(options.measures or {}) do f:setMeasure(name, spec) end
        local skin = {}
        function skin:GetMeasure(name)
            f.measureLookups[name] = (f.measureLookups[name] or 0) + 1
            local provider = f.measures[name]
            if type(provider) == 'function' then return provider(name) end
            return provider
        end
        function skin:GetVariable(name, fallback)
            local value = f.variables[name]
            if value == nil then return fallback end
            return value
        end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = {command = command, args = args}
            if command == '!SetOption' then
                assert(#args == 3 and type(args[3]) == 'string', 'option must be one scalar string')
                local target = tostring(args[1])
                local memoryRank = tonumber(target:match('^MeasureGPUProcessMemory([1-5])$'))
                if memoryRank then
                    assert(args[2] == 'Name' and #args[3] > 0, 'memory lookup changes only nonempty Name')
                    f.memory[memoryRank].name = args[3]
                    return
                end
                local kind, rank = target:match('^MeterGPUProcess(%a+)([1-5])$')
                assert(rank and (kind == 'Name' or kind == 'Value' or kind == 'Memory'),
                    'unexpected meter write: ' .. target)
                assert(args[2] == 'Text' or args[2] == 'ToolTipText', 'unexpected option write: ' .. tostring(args[2]))
                f.options[target] = f.options[target] or {}
                f.options[target][args[2]] = args[3]
            elseif command == '!EnableMeasure' or command == '!DisableMeasure' or command == '!UpdateMeasure' then
                local rank = #args == 1 and tonumber(tostring(args[1]):match('^MeasureGPUProcessMemory([1-5])$'))
                assert(rank, 'only bounded named memory lookups may be changed')
                if command == '!UpdateMeasure' then
                    if f.updateFailures[rank] then error('forced update unavailable') end
                    f.memory[rank].updates = f.memory[rank].updates + 1
                    f:refreshMemory(rank)
                else
                    f.memory[rank].enabled = command == '!EnableMeasure'
                end
            elseif command == '!ShowMeterGroup' or command == '!HideMeterGroup' then
                local rank = #args == 1 and tonumber(tostring(args[1]):match('^GPUProcessRow([1-5])$'))
                assert(rank, 'only the five process row groups may change visibility')
                f.visible[rank] = command == '!ShowMeterGroup'
            elseif f.bangs[command] then
                return f.bangs[command](f, args)
            else
                -- Includes !UpdateMeterGroup / !Redraw: changed meters repaint at
                -- the end of Rainmeter's normal skin cycle, never mid-cycle.
                error('unexpected action or external work: ' .. tostring(command))
            end
        end
        local function forbidden() error('unexpected external work') end
        local blocked = setmetatable({}, {__index = function() return forbidden end})
        local fakeos = setmetatable({time = function()
            if type(f.now) == 'function' then return f.now() end
            return f.now
        end}, {__index = function() return forbidden end})
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
        function f:option(kind, rank, option)
            local meter = self.options['MeterGPUProcess' .. kind .. rank]
            return meter and meter[option]
        end
        function f:text(kind, rank) return self:option(kind, rank, 'Text') end
        function f:tip(kind, rank) return self:option(kind, rank, 'ToolTipText') end
        -- Calls other than the row-visibility bangs, which are re-sent every update.
        function f:work()
            local list = {}
            for _, call in ipairs(self.calls) do
                if call.command ~= '!ShowMeterGroup' and call.command ~= '!HideMeterGroup' then
                    list[#list + 1] = call
                end
            end
            return list
        end
        -- Sorted Target:Option keys of every !SetOption since the last clear.
        function f:written()
            local keys = {}
            for _, call in ipairs(self.calls) do
                if call.command == '!SetOption' then keys[#keys + 1] = call.args[1] .. ':' .. call.args[2] end
            end
            table.sort(keys)
            return table.concat(keys, ',')
        end
        function f:unknownLookups()
            local names = {}
            for name in pairs(self.measureLookups) do
                if self.measures[name] == nil then names[#names + 1] = name end
            end
            table.sort(names)
            return table.concat(names, ',')
        end
        function f:clear() self.calls, self.reads = {}, {} end
        env.Initialize(); f:update()
        return f
    end
    local function shown(f, count)
        for rank = 1, 5 do eq(f.visible[rank], rank <= count, 'row ' .. rank .. ' visibility') end
    end
    -- request: PIDs still requested for names after the ranking empties
    -- (recently ranked ones stay requested for fifteen seconds), default none.
    local function noData(f, request)
        eq(f:text('Name', 1), 'No active GPU process data', 'empty ranking label')
        eq(f:text('Value', 1), '--', 'empty ranking percentage')
        eq(f:text('Memory', 1), '--', 'empty ranking memory')
        local tip = f:tip('Name', 1)
        contains(tip, 'No ranked GPU process-engine observation')
        contains(tip, 'cannot be distinguished')
        eq(f:tip('Value', 1), tip, 'percentage tooltip explains the empty ranking')
        eq(f:tip('Memory', 1), tip, 'memory tooltip explains the empty ranking')
        shown(f, 1)
        eq(f.request, request or '?', 'only recently ranked PIDs stay requested for names')
    end

    test('exact counter ranks are read in order and distinct PIDs keep their own rows and percentages', function()
        local f = fixture({
            {name = instance(11, '3D'), value = 75},
            {name = instance(22, 'Copy'), value = 30},
            {name = instance(33, 'VideoDecode'), value = 25.24},
            {name = instance(44, 'Compute'), value = 10},
            {name = instance(55, '3D', '0x00000000_0x00000002'), value = 5}
        })
        local pids = {'11', '22', '33', '44', '55'}
        local engines = {'3D', 'Copy', 'VideoDecode', 'Compute', '3D'}
        local percentages = {'75.0%', '30.0%', '25.2%', '10.0%', '5.0%'}
        for rank = 1, 5 do
            eq(f.reads[rank], rank, 'read order')
            eq(f:text('Name', rank), 'PID ' .. pids[rank])
            eq(f:text('Value', rank), percentages[rank])
            local tip = f:tip('Name', rank)
            contains(tip, 'Busiest engine for this process: ' .. engines[rank] .. ' at ' .. percentages[rank] .. '.')
            contains(tip, 'across all exposed GPUs, not a sum')
            contains(tip, 'Current Windows name lookup for PID ' .. pids[rank] .. ' is unavailable')
            contains(tip, 'sample age is not exposed')
            lacks(tip, 'Also observed here', 'single-engine row lists no other engines')
            eq(f:tip('Value', rank), tip, 'percentage shares the row tooltip')
        end
        shown(f, 5)
        eq(#f.reads, 5, 'bounded reads')
        eq(f.value, 0); eq(f.request, '11,22,33,44,55')
        eq(f:unknownLookups(), '', 'only known measures are requested')
    end)
    test('a PID at several ranks becomes one row at its busiest engine percentage, never a sum', function()
        local otherAdapter = instance(11, 'Compute', '0x00000000_0x00000002')
        local rows = {{name = instance(11, '3D'), value = 75}, {name = instance(11, 'Copy'), value = 30},
            {name = instance(33, 'VideoDecode'), value = 25.24}, {name = otherAdapter, value = 0.05},
            {name = instance(55), value = 0.04}}
        local f = fixture(rows, {memoryValues = {[memoryKey(rows[1].name)] = 100 * 1000000,
            [memoryKey(otherAdapter)] = 900 * 1000000, [memoryKey(rows[3].name)] = 50 * 1000000}})
        eq(f:text('Name', 1), 'PID 11'); eq(f:text('Value', 1), '75.0%', 'busiest engine, not 75 + 30 + 0.05')
        contains(f:tip('Name', 1), 'Busiest engine for this process: 3D at 75.0%.')
        contains(f:tip('Name', 1), 'Also observed here: Copy 30.0%, Compute <0.1%.')
        eq(f:text('Name', 2), 'PID 33'); eq(f:text('Value', 2), '25.2%')
        lacks(f:tip('Name', 2), 'Also observed here')
        eq(f:text('Name', 3), 'PID 55'); eq(f:text('Value', 3), '<0.1%')
        shown(f, 3)
        eq(f.request, '11,33,55', 'one sorted request entry per PID')
        eq(f.memory[1].name, memoryKey(rows[1].name), 'memory follows the busiest engine instance')
        eq(f:text('Memory', 1), '100 MB', 'other adapter bytes are neither shown nor added')
        eq(f.memory[2].name, memoryKey(rows[3].name), 'memory slot follows the row, not the rank')
        eq(f:text('Memory', 2), '50 MB')
        eq(f.memory[3].name, memoryKey(rows[5].name)); eq(f:text('Memory', 3), '--')
        for slot = 4, 5 do
            eq(f.memory[slot].enabled, false, 'unused memory lookup stays disabled')
            eq(f.memory[slot].name, noMemory); eq(f.memory[slot].updates, 0)
            eq(f.memoryLookups[slot], nil, 'unused memory lookup is never read')
        end
        f.rows = {{name = instance(33, 'VideoDecode'), value = 60}, {name = instance(11, '3D'), value = 40},
            {name = instance(11, 'Copy'), value = 20}}
        f:update()
        eq(f:text('Name', 1), 'PID 33'); eq(f:text('Value', 1), '60.0%'); eq(f:text('Memory', 1), '50 MB')
        lacks(f:tip('Name', 1), 'Also observed here')
        eq(f:text('Name', 2), 'PID 11'); eq(f:text('Value', 2), '40.0%'); eq(f:text('Memory', 2), '100 MB')
        contains(f:tip('Name', 2), 'Also observed here: Copy 20.0%.')
        shown(f, 2); eq(f.request, '11,33,55', 'recently ranked 55 keeps a spare request slot')
        eq(f.memory[3].enabled, false, 'vacated row releases its memory lookup')
        eq(f.memory[3].name, noMemory)
    end)
    test('small positive values remain visible as positive percentages and 100 is valid', function()
        local f = fixture({{name = instance(2), value = 100}, {name = instance(3), value = 0.1},
            {name = instance(1), value = 0.001}})
        eq(f:text('Value', 1), '100.0%')
        eq(f:text('Value', 2), '0.1%')
        eq(f:text('Value', 3), '<0.1%')
        contains(f:tip('Name', 3), 'Busiest engine for this process: 3D at <0.1%.')
        eq(f.request, '1,2,3')
    end)
    test('name requests are bounded sorted unique positive uint32 PIDs from valid active ranks', function()
        local f = fixture({{name = instance('00011', 'Copy'), value = 25},
            {name = instance(2), value = 20}, {name = instance(11), value = 15},
            {name = instance(4294967295), value = 10}, {name = instance(77), value = 0}})
        eq(f.value, 0); eq(f.request, '2,11,4294967295')
        eq(f:text('Name', 1), 'PID 11', 'zero-padded PID is canonical and grouped')
        contains(f:tip('Name', 1), 'Also observed here: 3D 15.0%.')
        eq(f:text('Name', 3), 'PID 4294967295'); shown(f, 3)
        local invalid = {'0', '4294967296', '-1', '1e3', '1.5', string.rep('9', 17)}
        for _, pid in ipairs(invalid) do
            f.rows = {{name = instance(pid), value = 20}}; f:update()
            noData(f, '2,11,4294967295')
        end
        f.rows = {{name = instance(11), value = 101}, {name = instance(12), value = 0},
            {name = 'app.exe', value = 25}, false, {name = instance(14), value = 0/0}}
        f:update(); noData(f, '2,11,4294967295')
        f.rows = {}; for rank = 1, 5 do f.rows[rank] = {name = instance(6 - rank), value = 50 - rank} end
        f:update(); eq(f.request, '1,2,3,4,5,11,4294967295', 'recently ranked valid PIDs stay requested')
        eq(f:text('Name', 1), 'PID 5', 'rows keep rank order while the request is sorted')
    end)
    test('Windows basenames decorate PID rows without merging distinct PIDs or changing percentages', function()
        local f = fixture({{name = instance(11, '3D'), value = 75}, {name = instance(22, 'VideoDecode'), value = 30},
            {name = instance(11, 'Copy'), value = 25}},
            {names = packet({{11, 'example.exe'}, {22, 'example.exe'}})})
        eq(f:text('Name', 1), 'example.exe'); eq(f:text('Name', 2), 'example.exe', 'same name never merges PIDs')
        eq(f:text('Value', 1), '75.0%'); eq(f:text('Value', 2), '30.0%')
        contains(f:tip('Name', 1), 'Current Windows name lookup for PID 11: example.exe.')
        contains(f:tip('Name', 1), 'Also observed here: Copy 25.0%.')
        contains(f:tip('Name', 2), 'Current Windows name lookup for PID 22: example.exe.')
        shown(f, 2)
        eq(f.request, '11,22'); eq(f.nameReads, 1)
        f:clear(); f:update(); eq(#f:work(), 0, 'unchanged names dispatch no work')
        eq(f.nameReads, 2); eq(f.nameLookups, 1)
    end)
    test('delayed, removed and unavailable lookups fall back to the current PID without retained names', function()
        local f = fixture({{name = instance(11), value = 75}}, {names = packet({{11, 'before.exe'}})})
        eq(f:text('Name', 1), 'before.exe')
        f.rows[1] = {name = instance(22), value = 30}; f:update()
        eq(f:text('Name', 1), 'PID 22'); eq(f.request, '11,22'); eq(f:text('Value', 1), '30.0%')
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
            prefix .. first .. ';22,3F;33,3F;44,3F;55,3F;66,3F;77,3F;88,3F;99,3F;110,3F;121,3F', string.rep('x', 4097)}
        eq(fixture({{name = instance(11), value = 25}}, {names = prefix .. first}):text('Name', 1),
            'valid.exe', 'baseline packet is accepted')
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
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, 'valid.exe'}})})
        f.now = 0/0; f:update(); eq(f:text('Name', 1), 'PID 11', 'nonfinite clock withholds names')
    end)
    test('strict UTF8 basenames are byte-bounded and display metacharacters cannot become actions', function()
        local unicode = string.char(195, 169, 240, 159, 154, 128) .. '.exe'
        local f = fixture({{name = instance(11), value = 25}}, {names = packet({{11, unicode}})})
        eq(f:text('Name', 1), unicode)
        for _, valid in ipairs({string.rep('a', 128), string.rep(string.char(195, 169), 64), 'name#[!Refresh]".exe'}) do
            f.names = packet({{11, valid}}); f:update()
            ok(f:text('Name', 1) ~= 'PID 11', 'valid basename accepted')
            for _, text in ipairs({f:text('Name', 1), f:tip('Name', 1), f:tip('Value', 1)}) do
                ok(not text:find(unsafe), 'display metacharacters removed')
            end
            eq(f:text('Value', 1), '25.0%')
        end
        eq(f:text('Name', 1), "name(!Refresh)'.exe", 'metacharacters are neutralized in place')
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
        noData(f)
    end)
    test('negative over-range nonnumeric NaN and infinite values are rejected', function()
        for _, value in ipairs({-1, 100.001, '25', 0/0, math.huge, -math.huge}) do
            noData(fixture({{name = instance(1), value = value}}))
        end
    end)
    test('renamed merged and incomplete counter identities are rejected', function()
        for _, name in ipairs({'example.exe', 'pid_8_eng_0_engtype_3D',
            'luid_0_phys_0_eng_0_engtype_3D', 'pid_8_luid_0_phys_0_engtype_3D'}) do
            noData(fixture({{name = name, value = 20}}))
        end
        local f = fixture({{name = 'pid_8_luid_0_phys_0_eng_0_engtype_', value = 20}})
        eq(f:text('Name', 1), 'PID 8', 'missing engine label retains valid raw identity')
        contains(f:tip('Name', 1), 'Busiest engine for this process: unknown engine at 20.0%.')
        eq(f:text('Memory', 1), '--', 'non-hex adapter LUID cannot bind memory')
    end)
    test('provider display text is sanitized and cannot dispatch actions or reach memory binding', function()
        local f = fixture({{name = instance(1, '3D[#danger#]"\n[!Execute cmd]'), value = 25}})
        eq(f:text('Name', 1), 'PID 1')
        contains(f:tip('Name', 1), "Busiest engine for this process: 3D(danger)' (!Execute cmd) at 25.0%.")
        for _, text in ipairs({f:text('Name', 1), f:tip('Name', 1), f:tip('Value', 1), f:tip('Memory', 1)}) do
            ok(not text:find(unsafe), 'display metacharacters removed')
        end
        eq(f:text('Value', 1), '25.0%')
        eq(f.memory[1].name, 'pid_1_luid_0x00000000_0x00000001_phys_0', 'engine text never reaches the memory Name')
    end)
    test('idle and invalid transitions clear previous rows and surviving PIDs move up', function()
        local f = fixture({{name = instance(1), value = 75}, {name = instance(2), value = 50}})
        shown(f, 2); eq(f.memory[2].enabled, true)
        f.rows[1] = {name = '', value = 0}
        f.rows[2] = {name = instance(2), value = 101}
        f:update()
        noData(f, '1,2')
        eq(f.memory[1].enabled, false); eq(f.memory[2].enabled, false, 'hidden row releases its memory lookup')
        f.rows[2] = {name = instance(2), value = 50}; f:update()
        eq(f:text('Name', 1), 'PID 2', 'no gap is left at the idle rank'); eq(f:text('Value', 1), '50.0%')
        eq(f.memory[1].name, memoryKey(instance(2))); shown(f, 1)
        f.rows[1] = {name = instance(1), value = 75}; f:update()
        shown(f, 2); eq(f:text('Name', 1), 'PID 1'); eq(f:text('Name', 2), 'PID 2')
    end)
    test('unchanged observations write nothing and changes write only affected options', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f:update()
        eq(#f:work(), 0, 'deduplicated presentation and memory binding')
        shown(f, 1)
        eq(#f.reads, 5, 'one read per existing rank per update')
        for rank = 1, 5 do eq(f.lookups[rank], 1, 'cached measure reference') end
        f:clear(); f.rows[1].value = 25; f:update()
        eq(f:written(), 'MeterGPUProcessName1:ToolTipText,MeterGPUProcessValue1:Text,MeterGPUProcessValue1:ToolTipText')
        eq(#f:work(), 3, 'no memory rebinding, group update or redraw')
        eq(f:text('Value', 1), '25.0%')
    end)
    test('reinitialization discards references, memory bindings and rendering cache', function()
        local f = fixture({{name = instance(1), value = 75}})
        f:clear(); f.env.Initialize(); f:update()
        contains(f:written(), 'MeterGPUProcessName1:Text', 'initial presentation reapplied')
        eq(f.memory[1].updates, 2, 'memory lookup rebound and refreshed')
        for rank = 1, 5 do eq(f.lookups[rank], 2, 'reference reacquired') end
        eq(f.nameLookups, 2)
        f.rows[1] = {name = instance(22, 'Copy'), value = 10}
        f.env.Initialize(); f:update()
        eq(f:text('Name', 1), 'PID 22'); eq(f:text('Value', 1), '10.0%')
        contains(f:tip('Name', 1), 'Busiest engine for this process: Copy at 10.0%.')
    end)
    test('late available measures are acquired without resetting other ranks', function()
        local f = fixture({false})
        noData(f)
        f.rows[1] = {name = instance(1), value = 50}
        f:update()
        eq(f:text('Value', 1), '50.0%')
        eq(f.lookups[1], 2)
        eq(f.lookups[2], 1)
    end)

    test('dedicated memory binds exact PID adapter physical prefix before reading raw bytes', function()
        local rows = {{name = instance(11), value = 25},
            {name = instance(12, 'Copy', '0x00000000_0x00000002'), value = 20},
            {name = (instance(22):gsub('_phys_0_', '_phys_1_')), value = 15},
            {name = instance(33), value = 10}, {name = instance(44), value = 5}}
        local bytes = {512, 10 * 1000, 123 * 1000000, 1.25 * 1000000000, 1.5 * 1000000000000}
        local labels = {'512 B', '10 KB', '123 MB', '1.25 GB', '1.50 TB'}
        local values = {}
        for rank = 1, 5 do values[memoryKey(rows[rank].name)] = bytes[rank] end
        local f = fixture(rows, {memoryValues = values})
        for rank = 1, 5 do
            local key = memoryKey(rows[rank].name)
            eq(f.memory[rank].name, key); eq(f.memory[rank].returnedName, key)
            eq(f.memory[rank].enabled, true); eq(f.memory[rank].updates, 1)
            eq(f:text('Memory', rank), labels[rank])
            local tip = f:tip('Memory', rank)
            contains(tip, 'Windows GPU Process Memory Local Usage for ' .. key .. ':')
            contains(tip, string.format('Reported local memory: %.0f bytes.', bytes[rank]))
            contains(tip, 'not to one engine'); contains(tip, 'Cross-process shared allocations')
            contains(tip, 'Shared RAM system-memory row'); contains(tip, 'sample age is not exposed')
        end
        eq(f.memory[3].name, 'pid_22_luid_0x00000000_0x00000001_phys_1', 'physical adapter index is bound')
        eq(f.request, '11,12,22,33,44', 'memory does not change name request PID set')
        f:clear(); f:update(); eq(#f:work(), 0, 'unchanged binding and presentation dispatch nothing')
        for rank = 1, 5 do eq(f.memory[rank].updates, 1); eq(f.memoryLookups[rank], 1) end
    end)
    test('memory text uses decimal 1000-step B KB MB GB and TB units at exact boundaries', function()
        local row = instance(11)
        local f = fixture({{name = row, value = 25}})
        local cases = {{1, '1 B'}, {999, '999 B'}, {1000, '1 KB'}, {1000000, '1 MB'}, {1048576, '1 MB'},
            {228454400, '228 MB'}, {1000000000, '1.00 GB'}, {1073741824, '1.07 GB'},
            {1000000000000, '1.00 TB'}, {1792337280000, '1.79 TB'}, {9007199254740991, '9007.20 TB'}}
        for _, case in ipairs(cases) do
            f.memoryValues[memoryKey(row)] = case[1]; f:update()
            eq(f:text('Memory', 1), case[2])
            contains(f:tip('Memory', 1), string.format('Reported local memory: %.0f bytes.', case[1]))
        end
    end)
    test('row replacement forces refreshed binding and never borrows prior PID adapter bytes', function()
        local first, second = instance(11), instance(22)
        local otherGpu = instance(22, 'Copy', '0x00000000_0x000000FF')
        local f = fixture({{name = first, value = 25}}, {memoryValues = {
            [memoryKey(first)] = 100 * 1000000, [memoryKey(second)] = 200 * 1000000,
            [memoryKey(otherGpu)] = 300 * 1000000}})
        f:clear(); f.rows[1] = {name = second, value = 30}; f:update()
        eq(f.calls[1].command, '!SetOption'); eq(f.calls[1].args[3], memoryKey(second))
        eq(f.calls[2].command, '!EnableMeasure'); eq(f.calls[3].command, '!UpdateMeasure')
        eq(f:text('Memory', 1), '200 MB'); eq(f.memory[1].updates, 2)
        f.rows[1] = {name = otherGpu, value = 35}; f:update()
        eq(f:text('Memory', 1), '300 MB'); eq(f.memory[1].updates, 3)
        f.frozenMemory[1] = true; f.rows[1] = {name = first, value = 40}; f:update()
        eq(f.memory[1].returnedName, memoryKey(otherGpu), 'simulate failed stale plugin cache')
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '40.0%'); eq(f:text('Name', 1), 'PID 11')
        contains(f:tip('Memory', 1), 'exact requested instance')
        f.frozenMemory[1] = false; f:update(); eq(f:text('Memory', 1), '100 MB')
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
        f.memoryValues[memoryKey(row)] = 1; f:update(); eq(f:text('Memory', 1), '1 B')
    end)
    test('idle and malformed memory identities disable old lookup and cannot select a total', function()
        local row = instance(11)
        -- {raw counter name, whether the engine identity itself is still valid}
        local invalid = {{'pid_11_luid_0_phys_0_eng_0_engtype_3D', true},
            {instance(11, '3D', '0x00000000_0x000000001'), true},
            {instance(11, '3D', '0x00000000_0x0000000G'), true},
            {(row:gsub('_phys_0_', '_phys_4294967296_')), true}, {(row:gsub('_phys_0_', '_phys_-1_')), true},
            {(row:gsub('_eng_0_', '_eng_4294967296_')), true}, {(row:gsub('_eng_0_', '_eng_1e3_')), false},
            {string.rep('x', 1025), false}, {'', false}, {'0', false}, {'example.exe', false}}
        for _, case in ipairs(invalid) do
            local f = fixture({{name = row, value = 25}}, {memoryValues = {[memoryKey(row)] = 1048576}})
            f:clear(); f.rows[1] = {name = case[1], value = 25}; f:update()
            eq(f.memory[1].enabled, false); eq(f.memory[1].name, noMemory); eq(f.memory[1].updates, 1)
            eq(f.calls[1].command, '!DisableMeasure'); eq(f.calls[2].command, '!SetOption')
            if case[2] then
                eq(f:text('Name', 1), 'PID 11', 'valid engine identity keeps its row')
                eq(f:text('Value', 1), '25.0%'); eq(f:text('Memory', 1), '--')
                contains(f:tip('Memory', 1), 'No exact active PID / adapter / physical GPU identity')
            else
                noData(f, '11')
            end
            f:clear(); f:update(); eq(#f:work(), 0, 'invalid stable identity dispatches nothing')
        end
        local f = fixture({{name = row, value = 25}})
        f.rows[1].value = 0; f:update(); noData(f, '11')
        eq(f.memory[1].enabled, false); eq(f.memory[1].name, noMemory)
        f.rows[1].value = 25; f:update(); eq(f.memory[1].enabled, true); eq(f.memory[1].updates, 2)
        eq(f.memory[1].name, memoryKey(row))
    end)
    test('missing references forced update failures and read failures remain local to memory', function()
        local first, second = instance(11), instance(22)
        local f = fixture({{name = first, value = 25}}, {memoryValues = {[memoryKey(first)] = 1048576,
            [memoryKey(second)] = 2 * 1048576}})
        f.readFailures[1] = true; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '25.0%'); eq(f.request, '11')
        contains(f:tip('Memory', 1), 'exact requested instance')
        f.readFailures[1] = false; f:update(); eq(f:text('Memory', 1), '1 MB')
        f.updateFailures[1] = true; f.rows[1] = {name = second, value = 30}; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Name', 1), 'PID 22'); eq(f:text('Value', 1), '30.0%')
        contains(f:tip('Memory', 1), 'could not be rebound')
        f.updateFailures[1] = false; f:update(); eq(f:text('Memory', 1), '2 MB')
        eq(f.memory[1].updates, 2, 'failed forced update is retried, not recorded as bound')
        f = fixture({})
        noData(f)
        f.missingMemory[1] = true; f.rows[1] = {name = first, value = 25}; f:update()
        eq(f:text('Memory', 1), '--'); eq(f:text('Value', 1), '25.0%')
        f.missingMemory[1] = false; f.memoryValues[memoryKey(first)] = 1048576; f:update()
        eq(f:text('Memory', 1), '1 MB'); eq(f.memoryLookups[1], 2)
    end)
    test('name requests keep recently ranked PIDs in spare slots for fifteen seconds', function()
        local f = fixture({{name = instance(11), value = 50}, {name = instance(22), value = 40},
            {name = instance(33), value = 30}})
        eq(f.request, '11,22,33')
        f.rows = {{name = instance(11), value = 50}}; f.now = 1005; f:update()
        shown(f, 1); eq(f:text('Name', 1), 'PID 11')
        eq(f.request, '11,22,33', 'rows show only the ranking; dropped PIDs stay requested')
        f.rows = {{name = instance(11), value = 50}, {name = instance(44), value = 40},
            {name = instance(55), value = 30}, {name = instance(66), value = 20}}
        f.now = 1006; f:update(); shown(f, 4)
        eq(f.request, '11,22,33,44,55,66', 'ranked PIDs first, then recently ranked ones')
        f.rows = {{name = instance(11), value = 50}}; f.now = 1015; f:update()
        eq(f.request, '11,22,33,44,55,66', 'every PID ranked in the last 15 s fits')
        f.now = 1016; f:update(); eq(f.request, '11,44,55,66', 'PIDs unranked for over 15 s leave the request')
        f.now = 1022; f:update(); eq(f.request, '11')
        f.rows = {}; f.now = 1023; f:update(); noData(f, '11')
        f.now = 1039; f:update(); noData(f)
        f.rows = {{name = instance(11), value = 50}, {name = instance(22), value = 40}}; f:update()
        f.rows = {{name = instance(22), value = 40}}; f.now = 1030; f:update()
        eq(f.request, '22', 'a clock rollback drops PIDs seen in the future')
        -- Five distinct ranked PIDs still leave five spare slots, so a PID
        -- displaced from the ranking keeps its name while it is recent.
        local five = {}
        for rank = 1, 5 do five[rank] = {name = instance(rank), value = 60 - rank} end
        f.rows = five; f.now = 1031; f:update(); eq(f.request, '1,2,3,4,5,22')
        f.rows = {five[1], five[2], five[3], five[4], {name = instance(6), value = 30}}; f.now = 1032; f:update()
        eq(f.request, '1,2,3,4,5,6,22', 'the displaced PID stays requested')
        -- Ten at most: the ranked five, then the five most recently ranked others.
        for second = 1, 7 do
            local rows = {}
            for rank = 1, 5 do rows[rank] = {name = instance(100 + second * 5 + rank), value = 60 - rank} end
            f.rows = rows; f.now = 1032 + second; f:update()
        end
        eq(f.request, '131,132,133,134,135,136,137,138,139,140', 'ranked PIDs outrank recent ones, newest recent first')
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
