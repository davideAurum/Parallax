-- Original Parallax GPU overview regressions for native Rainmeter Lua 5.1.
-- All telemetry and time are fixtures. The loaded module cannot access files,
-- launch processes, change preferences or dispatch actions in these tests.
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
    local allowedMeters = {
        MeterAdapterName = true, MeterVRAMValue = true,
        MeterActivityValue = true
    }
    local removedMeters = {
        'MeterDirect3DValue', 'MeterShaderValue', 'MeterRayTracingValue',
        'MeterDriverValue', 'MeterGPUClocksValue',
        'MeterGPUBaseClockValue', 'MeterGPUBoostClockValue',
        'MeterTemperatureValue', 'MeterActivityDetail',
        'MeterPowerValue', 'MeterClockValue', 'MeterSensorStatus'
    }
    local function payload(name, bytes, memoryType, vendor, scope, base, boost)
        return table.concat({'OK', name, tostring(bytes), memoryType or '?',
            vendor or '?', scope or 'PHYSICAL', tostring(base or '?'), tostring(boost or '?')}, '|')
    end
    local function fixture(output, status, missing)
        local f = {
            output = output or '', status = status or 1, missing = missing,
            now = 1000, infoReads = 0, statusReads = 0, calls = {},
            options = {
                MeterAdapterName = {Text = 'Checking...'},
                MeterVRAMValue = {Text = 'Checking...'}
            }
        }
        local info = {}
        function info:GetStringValue() f.infoReads = f.infoReads + 1; return f.output end
        function info:GetValue() f.statusReads = f.statusReads + 1; return f.status end
        local activity = {}
        function activity:GetStringValue() return '' end
        function activity:GetValue() return 0 end
        local skin = {}
        function skin:GetMeasure(name)
            if name == 'MeasureGPUInfo' then return not f.missing and info or nil end
            if name == 'MeasureGPUActivity' then return activity end
            error('unexpected measure access: ' .. tostring(name))
        end
        function skin:GetVariable(name, fallback)
            error('overview must not read sensor source settings: ' .. tostring(name))
        end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = {command = command, args = args}
            if command == '!SetOption' then
                assert(#args == 3 and allowedMeters[args[1]], 'unexpected or removed meter write')
                assert(args[2] == 'Text' or args[2] == 'ToolTipText', 'unexpected option')
                assert(type(args[3]) == 'string', 'option must be one scalar string')
                f.options[args[1]] = f.options[args[1]] or {}
                f.options[args[1]][args[2]] = args[3]
            elseif command == '!UpdateMeterGroup' then
                assert(#args == 1 and args[1] == 'GPUReadout', 'wrong meter group')
            elseif command == '!Redraw' then
                assert(#args == 0, 'unexpected redraw arguments')
            else
                error('unexpected action or external work: ' .. tostring(command))
            end
        end
        local function forbidden() error('unexpected external work') end
        local blocked = setmetatable({}, {__index = function() return forbidden end})
        local fakeos = setmetatable({time = function() return f.now end},
            {__index = function() return forbidden end})
        local env = setmetatable({
            SKIN = skin, SELF = {}, os = fakeos, io = blocked,
            package = blocked, debug = blocked, require = forbidden,
            dofile = forbidden, loadfile = forbidden, loadstring = forbidden
        }, {__index = _G})
        env._G = env
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
        f.env = env
        function f:text(meter) return self.options[meter] and self.options[meter].Text end
        function f:tip(meter) return self.options[meter] and self.options[meter].ToolTipText end
        function f:clear() self.calls = {} end
        env.Initialize()
        env.Update()
        return f
    end
    local function unavailable(f, name)
        eq(f:text('MeterAdapterName'), name or 'GPU name unavailable', 'adapter state')
        eq(f:text('MeterVRAMValue'), 'VRAM unavailable @ -- MHz (-- MHz)', 'memory and clock state')
    end

    test('physical capacity type and manufacturer come from the returned adapter fixture', function()
        local f = fixture(payload('Fixture graphics board A', 8192 * 1048576, 'GDDR5X', 'Micron'))
        eq(f:text('MeterAdapterName'), 'Fixture graphics board A')
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR5X @ -- MHz (-- MHz)')
        contains(f:tip('MeterVRAMValue'), '8589934592 bytes')
        contains(f:tip('MeterVRAMValue'), 'Memory manufacturer: Micron.')
        contains(f:tip('MeterVRAMValue'), 'Total physical video memory')
    end)
    test('Initialize clears metadata cache and accepts a different adapter and memory', function()
        local f = fixture(payload('Fixture board A', 8192 * 1048576, 'GDDR5X', 'Micron', 'PHYSICAL', 1607000, 1733500))
        f.output = payload('Different fixture board B', 6144 * 1048576, 'GDDR6', 'Samsung', 'PHYSICAL', 1500000, 2100000)
        f.env.Initialize(); f.env.Update()
        eq(f:text('MeterAdapterName'), 'Different fixture board B')
        eq(f:text('MeterVRAMValue'), '6144 MB GDDR6 @ 1500 MHz (2100 MHz)')
        contains(f:tip('MeterVRAMValue'), 'Memory manufacturer: Samsung.')
        ok(not f:tip('MeterVRAMValue'):find('Micron', 1, true), 'previous memory vendor discarded')
        eq(f.infoReads, 2, 'one metadata read per initialization')
    end)
    test('NONE explicitly reports absent discrete GPU and unavailable memory', function()
        unavailable(fixture('NONE'), 'No discrete GPU found')
    end)
    test('AMBIGUOUS never chooses an arbitrary adapter', function()
        local f = fixture('AMBIGUOUS')
        unavailable(f, 'Multiple discrete GPUs')
        contains(f:tip('MeterAdapterName'), 'No arbitrary adapter was selected')
    end)
    test('missing metadata measure produces an honest failure state', function()
        local f = fixture('', 1, true)
        unavailable(f)
        eq(f.infoReads, 0, 'missing measure was not read')
    end)
    test('failed command status rejects even a plausible old success payload', function()
        for _, status in ipairs({2, 101, 102, 103}) do
            unavailable(fixture(payload('Stale fixture board', 8589934592, 'GDDR5X'), status))
        end
    end)
    test('pending metadata retains checking until successful completion', function()
        local f = fixture(payload('Stale fixture board', 8589934592, 'GDDR5X'), -1)
        eq(f:text('MeterAdapterName'), 'Checking...')
        eq(f:text('MeterVRAMValue'), 'Checking...')
        eq(f.infoReads, 0, 'running command output not consumed')
        f.status = 0; f.now = 1005; f.env.Update()
        eq(f:text('MeterAdapterName'), 'Checking...')
        eq(f.infoReads, 0, 'not-started output not consumed')
        f.output = payload('Completed fixture board', 4294967296, 'GDDR6')
        f.status = 1; f.env.Update()
        eq(f:text('MeterAdapterName'), 'Completed fixture board')
        eq(f:text('MeterVRAMValue'), '4096 MB GDDR6 @ -- MHz (-- MHz)')
    end)
    test('deadline expires pending metadata without accepting stale output', function()
        for _, status in ipairs({-1, 0}) do
            local f = fixture(payload('Stale fixture board', 8589934592, 'GDDR5X'), status)
            f.now = 1014; f.env.Update(); unavailable(f)
            contains(f:tip('MeterVRAMValue'), 'failed or timed out')
        end
    end)
    test('dedicated fallback retains exact byte evidence and unknown memory type', function()
        local f = fixture(payload('Fallback fixture board', 8450473984, '?', '?', 'DEDICATED'))
        eq(f:text('MeterVRAMValue'), '7.9 GiB / type unknown @ -- MHz (-- MHz)')
        contains(f:tip('MeterVRAMValue'), '8450473984 bytes')
        contains(f:tip('MeterVRAMValue'), 'Physical framebuffer capacity was unavailable')
        contains(f:tip('MeterVRAMValue'), 'may exclude driver-reserved memory')
    end)
    test('unknown physical capacity preserves a valid independently queried memory type', function()
        local f = fixture(payload('Partial fixture board', '?', 'HBM2', '?', 'PHYSICAL'))
        eq(f:text('MeterAdapterName'), 'Partial fixture board')
        eq(f:text('MeterVRAMValue'), 'VRAM unknown HBM2 @ -- MHz (-- MHz)')
        contains(f:tip('MeterVRAMValue'), 'did not return a usable memory capacity')
        contains(f:tip('MeterVRAMValue'), 'Memory type: HBM2.')
    end)
    test('invalid noninteger nonfinite and unsafe-size capacities remain unknown', function()
        for _, bytes in ipairs({'0', '-1', '1.5', 'NaN', 'inf', '1e309',
            '9007199254740992', string.rep('9', 400)}) do
            local f = fixture(payload('Invalid capacity fixture', bytes, 'GDDR6'))
            eq(f:text('MeterVRAMValue'), 'VRAM unknown GDDR6 @ -- MHz (-- MHz)', 'invalid capacity ' .. bytes)
        end
    end)
    test('old malformed and unsupported-scope protocols are rejected', function()
        for _, output in ipairs({
            '', 'UNAVAILABLE', 'garbage',
            'OK|Old fixture|8589934592|12.1|6.8|1.0|32.0.0.0',
            'OK|Board|8589934592|GDDR6|Vendor',
            'OK|Board|8589934592|GDDR6|Vendor|PHYSICAL|extra',
            'OK|Board|8589934592|GDDR6|Vendor|PHYSICAL',
            'OK|Board|8589934592|GDDR6|Vendor|UNKNOWN|1607000|1733500',
            'OK|Board|8589934592|GDDR6|Vendor|physical|1607000|1733500',
            'OK| |8589934592|GDDR6|Vendor|PHYSICAL|1607000|1733500'
        }) do unavailable(fixture(output)) end
    end)
    test('provider metacharacters remain sanitized scalar display text', function()
        local f = fixture(payload('Board [!Quit] #Scale# "Demo"\nRev', 8589934592,
            'GDDR6[#Type#]', 'Vendor "Quoted"\tName'))
        eq(f:text('MeterAdapterName'), "Board (!Quit) Scale 'Demo' Rev")
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR6(Type) @ -- MHz (-- MHz)')
        for _, call in ipairs(f.calls) do
            if call.command == '!SetOption' then
                ok(not call.args[3]:find('[#%[%]"%c]'), 'safe display option')
            end
        end
    end)
    test('terminal adapter-identity metadata leaves the complete GPU overview intact', function()
        local base = payload('Temperature suffix fixture', 8589934592, 'GDDR5X', 'Micron', 'PHYSICAL', 1607000, 1733500)
        local suffix = 'GPU_ADAPTER|1|0123456789ABCDEF'
        for _, separator in ipairs({'\n', '\r\n'}) do
            local f = fixture(base .. separator .. suffix)
            eq(f:text('MeterAdapterName'), 'Temperature suffix fixture')
            eq(f:text('MeterVRAMValue'), '8192 MB GDDR5X @ 1607 MHz (1733.5 MHz)')
            contains(f:tip('MeterVRAMValue'), 'Memory manufacturer: Micron.')
            eq(f.options.MeterTemperatureValue, nil, 'temperature belongs to its own controller')
        end
    end)
    test('adapter suffix stripping preserves newlines inside provider display fields', function()
        local f = fixture(payload('Fixture\nBoard', 8589934592, 'GDDR6', 'Vendor\nName', 'PHYSICAL', 1500000, 2100000)
            .. '\nGPU_ADAPTER|1|0123456789ABCDEF')
        eq(f:text('MeterAdapterName'), 'Fixture Board')
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR6 @ 1500 MHz (2100 MHz)')
        contains(f:tip('MeterVRAMValue'), 'Memory manufacturer: Vendor Name.')
    end)
    test('wrong nonterminal and repeated adapter suffixes cannot disguise malformed metadata', function()
        local base = payload('Invalid suffix fixture', 8589934592, 'GDDR6', '?', 'PHYSICAL', 1607000, 1733500)
        local suffix = 'GPU_ADAPTER|1|0123456789ABCDEF'
        for _, tail in ipairs({
            '\nGPU_ADAPTER|2|0123456789ABCDEF', '\nOTHER_ADAPTER|1|0123456789ABCDEF',
            suffix, '\n' .. suffix .. '\ntrailing junk',
            '\n' .. suffix .. '\n' .. suffix
        }) do unavailable(fixture(base .. tail)) end
        local f = fixture(base .. '\ntrailing junk')
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR6 @ 1607 MHz (-- MHz)', 'unrecognized trailing text never restores a valid boost')
    end)
    test('ordinary updates cache metadata and never write removed capability meters', function()
        local f = fixture(payload('Cached fixture board', 8589934592, 'GDDR5X', 'Micron', 'PHYSICAL', 1607000, 1733500))
        local reads, statusReads = f.infoReads, f.statusReads
        f.output = payload('Unrequested different board', 4294967296, 'GDDR6')
        f:clear()
        for _ = 1, 5 do f.now = f.now + 100; f.env.Update() end
        eq(f:text('MeterAdapterName'), 'Cached fixture board')
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR5X @ 1607 MHz (1733.5 MHz)')
        eq(f.infoReads, reads, 'metadata output remains cached')
        eq(f.statusReads, statusReads, 'metadata status remains cached')
        eq(#f.calls, 0, 'unchanged values produce no redraw or action')
        for _, meter in ipairs(removedMeters) do eq(f.options[meter], nil, meter) end
    end)

    test('base and boost graphics clocks retain driver precision in MHz', function()
        local f = fixture(payload('Clock fixture', 8589934592, 'GDDR5X', '?', 'PHYSICAL', 1607000, 1733500))
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR5X @ 1607 MHz (1733.5 MHz)')
        contains(f:tip('MeterVRAMValue'), 'Base: 1607000 kHz.')
        contains(f:tip('MeterVRAMValue'), 'Boost: 1733500 kHz.')
        contains(f:tip('MeterVRAMValue'), 'not the current clock or a measured peak')
        f = fixture(payload('Fine clock fixture', 8589934592, 'GDDR6', '?', 'PHYSICAL', 1607123, 1900001))
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR6 @ 1607.123 MHz (1900.001 MHz)')
    end)
    test('unavailable base and boost remain independent of each other and memory', function()
        local f = fixture(payload('Partial clock fixture', 8589934592, 'GDDR6', '?', 'PHYSICAL', '?', 1733500))
        eq(f:text('MeterVRAMValue'), '8192 MB GDDR6 @ -- MHz (1733.5 MHz)')
        contains(f:tip('MeterVRAMValue'), 'Base clock unavailable.')
        f = fixture(payload('Partial clock fixture', '?', '?', '?', 'DEDICATED', 1607000, '?'))
        eq(f:text('MeterVRAMValue'), 'VRAM unknown / type unknown @ 1607 MHz (-- MHz)')
        contains(f:tip('MeterVRAMValue'), 'Boost clock unavailable.')
    end)
    test('invalid clock values never become reference frequencies', function()
        for _, clock in ipairs({'0', '-1', '1.5', 'NaN', 'inf', '1e309', '4294967296', string.rep('9', 400)}) do
            local f = fixture(payload('Invalid clock fixture', 8589934592, 'GDDR6', '?', 'PHYSICAL', clock, clock))
            eq(f:text('MeterVRAMValue'), '8192 MB GDDR6 @ -- MHz (-- MHz)', 'invalid clock ' .. clock)
        end
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
