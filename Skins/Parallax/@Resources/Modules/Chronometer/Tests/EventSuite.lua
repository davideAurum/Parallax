-- Event protocol and fixed-instant arithmetic checks against production EventCore.lua.
local Suite = {}

function Suite.register(options, test, equal, check)
    local Core = dofile(options.moduleRoot .. '/EventCore.lua')
    local function hex(text) return (text:gsub('.', function(byte) return string.format('%02x', byte:byte()) end)) end
    local function sign(body)
        local sum = 0
        for i = 1, #body do sum = (sum * 31 + body:byte(i)) % 65521 end
        return body .. 'END|' .. sum .. '\n'
    end
    local function envelope(epoch, name, date)
        return sign('PARALLAX-EVENT-1\n' .. tostring(epoch) .. '\n' .. name .. '\n' .. date .. '\n')
    end
    local function active(name, date, deadline)
        return { enabled = true, deadline = deadline or 2000000000, name = name or 'Launch', localDate = date or '2033-05-18 03:33:20' }
    end
    local function invalid(text, message)
        local decoded, err = Core.decode(text)
        equal(decoded, nil, message); check(type(err) == 'string' and err ~= '', 'Invalid input needs a diagnostic')
    end

    test('event ASCII envelope roundtrips active fields with LF and lowercase hex', function()
        local original = active('Launch [A] #1 %')
        local encoded = assert(Core.encode(original))
        check(encoded:match('^PARALLAX%-EVENT%-1\n2000000000\n[0-9a-f]+\n2033%-05%-18 03:33:20\nEND|%d+\n$'))
        local decoded, err = Core.decode(encoded); equal(err, nil)
        equal(decoded.deadline, original.deadline); equal(decoded.name, original.name)
        equal(decoded.localDate, original.localDate); equal(decoded.enabled, true)
    end)
    test('event clear envelope requires exact empty fields and valid checksum', function()
        local encoded = assert(Core.encode({ enabled = false, deadline = 0, name = '', localDate = '' }))
        equal(encoded, envelope(0, '', ''))
        local decoded = assert(Core.decode(encoded)); equal(decoded.enabled, false)
        equal(decoded.deadline, 0); equal(decoded.name, ''); equal(decoded.localDate, '')
        invalid(envelope(0, hex('Name'), '')); invalid(envelope(0, '', '2030-01-01 00:00:00'))
        invalid('PARALLAX-EVENT-1\n0\n\n\nEND|0\n')
    end)
    test('event checksum and bytes match independent editor parity vectors', function()
        local name = 'Caf\195\169 \240\159\142\137'
        local expected = 'PARALLAX-EVENT-1\n2000000000\n436166c3a920f09f8e89\n2033-05-18 03:33:20\nEND|55894\n'
        equal(Core.encode(active(name)), expected); equal(assert(Core.decode(expected)).name, name)
        equal(Core.encode({ enabled = false, deadline = 0, name = '', localDate = '' }), 'PARALLAX-EVENT-1\n0\n\n\nEND|27125\n')
    end)
    test('event epoch bounds are independent of original local timezone metadata', function()
        for _, epoch in ipairs({ 1, 2147483648, 4102531199 }) do
            local decoded = assert(Core.decode(envelope(epoch, hex('Boundary'), '2000-01-01 00:00:00')))
            equal(decoded.deadline, epoch); equal(assert(Core.decode(assert(Core.encode(decoded)))).deadline, epoch)
        end
        for _, epoch in ipairs({ '-1', '4102531200', '2000000000.0', '2e9', '0x10', '+1', ' 1', '1 ', 'nan', '9007199254740991', '0000000001', '01', '00' }) do
            invalid(envelope(epoch, hex('Invalid'), '2030-01-01 00:00:00'), epoch)
        end
    end)
    test('event leap years and calendar month boundaries are validated', function()
        for _, date in ipairs({ '2000-02-29 00:00:00', '2004-02-29 12:34:56', '2096-02-29 23:59:59', '2099-12-31 23:59:59', '2030-04-30 01:02:03' }) do
            check(Core.decode(envelope(1, '61', date)), date)
        end
        for _, date in ipairs({ '1999-12-31 23:59:59', '2100-01-01 00:00:00', '2001-02-29 00:00:00', '2000-02-30 00:00:00',
            '2030-04-31 00:00:00', '2030-00-01 00:00:00', '2030-13-01 00:00:00', '2030-01-00 00:00:00', '2030-01-32 00:00:00' }) do
            invalid(envelope(1, '61', date), date)
        end
    end)
    test('event local metadata uses exact date/time shape and normal second bounds', function()
        for _, date in ipairs({ '2030-1-01 00:00:00', '2030-01-1 00:00:00', '2030-01-01T00:00:00', '2030-01-01 0:00:00',
            '2030-01-01 24:00:00', '2030-01-01 00:60:00', '2030-01-01 00:00:60', '2030-01-01 00:00:00Z', '2030-01-01 00:00:00 ', '', '2030-01-01' }) do
            invalid(envelope(1, '61', date), date)
        end
    end)
    test('event UTF-8 roundtrips accented, CJK, combining and astral names', function()
        local names = { 'Caf\195\169', '\230\151\165\230\156\172', 'e\204\129', '\240\159\142\137', '\244\143\191\191' }
        for _, name in ipairs(names) do
            equal(assert(Core.decode(assert(Core.encode(active(name))))).name, name)
            equal(Core.displayName(name), name)
        end
    end)
    test('event names respect 80 UTF-16 units, the byte cap and nonblank content', function()
        local largest = string.rep('\240\159\142\137', 40)
        equal(#largest, 160); check(Core.decode(envelope(1, hex(largest), '2030-01-01 00:00:00')))
        check(Core.decode(envelope(1, hex(string.rep('\230\151\165', 80)), '2030-01-01 00:00:00')))
        check(Core.decode(envelope(1, hex(string.rep('a', 80)), '2030-01-01 00:00:00')))
        invalid(envelope(1, hex(string.rep('\240\159\142\137', 41)), '2030-01-01 00:00:00'))
        invalid(envelope(1, hex(string.rep('a', 81)), '2030-01-01 00:00:00'))
        invalid(envelope(1, '', '2030-01-01 00:00:00'))
        invalid(envelope(1, hex(string.rep('a', 321)), '2030-01-01 00:00:00'))
        for _, blank in ipairs({ ' ', '   ', '\194\160', '\225\154\128', '\226\128\128', '\226\128\168', '\226\128\169', '\226\128\175', '\226\129\159', '\227\128\128' }) do
            invalid(envelope(1, hex(blank), '2030-01-01 00:00:00'))
        end
    end)
    test('event invalid UTF-8 rejects overlongs, surrogates, gaps and incomplete sequences', function()
        local malformed = { '\128', '\191', '\192\128', '\193\191', '\194', '\194A', '\224\128\128', '\237\160\128',
            '\237\191\191', '\240\128\128\128', '\244\144\128\128', '\245\128\128\128', '\255', '\226\130', '\240\159\142' }
        for _, name in ipairs(malformed) do invalid(envelope(1, hex(name), '2030-01-01 00:00:00'), hex(name)) end
    end)
    test('event C0 and C1 control characters are forbidden in saved names', function()
        for code = 0, 31 do invalid(envelope(1, hex('a' .. string.char(code)), '2030-01-01 00:00:00')) end
        invalid(envelope(1, hex('a' .. string.char(127)), '2030-01-01 00:00:00'))
        for code = 128, 159 do invalid(envelope(1, hex('a' .. string.char(194, code)), '2030-01-01 00:00:00')) end
    end)
    test('event name hex is lowercase, complete and contains only hex digits', function()
        for _, encoded in ipairs({ '6', 'GG', '4A', '0X61', '61 62', '61\r', '61\n62' }) do
            invalid(envelope(1, encoded, '2030-01-01 00:00:00'), encoded)
        end
    end)
    test('event rejects every truncation, trailing content and checksum damage', function()
        local encoded = assert(Core.encode(active()))
        for length = 0, #encoded - 1 do invalid(encoded:sub(1, length), 'Truncated at ' .. length) end
        invalid(encoded .. '\n'); invalid(encoded .. 'extra'); invalid(encoded:gsub('2000000000', '2000000001'))
        invalid(encoded:gsub('END|%d+', 'END|65521')); invalid(encoded:gsub('\n', '\r\n'))
        invalid(encoded:gsub('END|(%d+)', 'END|0%1'))
        invalid(sign('PARALLAX-EVENT-2\n1\n61\n2030-01-01 00:00:00\n'))
    end)
    test('event missing, oversized and executable-looking data never parses as code', function()
        invalid(nil); invalid({}); invalid(string.rep('x', 2049)); invalid('os.execute("must not run")')
        invalid(sign('PARALLAX-EVENT-1\n1\n61\n2030-01-01 00:00:00\nextra\n'))
        local inert = '[&Measure:Run()] #VALUE# %1'
        equal(assert(Core.decode(assert(Core.encode(active(inert))))).name, inert)
    end)
    test('event display name removes evaluation delimiters and preserves valid UTF-8', function()
        local display = Core.displayName(' [!Quit] #Name# %1 \195\169\n\194\128 ')
        equal(display:find('[%c#%%%[%]]'), nil); equal(display:find('\194\128', 1, true), nil)
        check(display:find('\195\169', 1, true)); equal(Core.displayName('#%[]\n'), 'Event')
        equal(Core.displayName(''), 'Event'); equal(Core.displayName(nil), 'Event'); equal(Core.displayName('\255'), 'Event')
    end)
    test('event remaining is fixed-instant, stateless and clamps reached deadlines', function()
        local event = active('Deadline', nil, 1000)
        equal(Core.remaining(event, 900), 100); equal(Core.remaining(event, 999), 1)
        equal(Core.remaining(event, 1000), 0); equal(Core.remaining(event, 5000), 0)
        equal(Core.remaining(event, 800), 200)
        local restored = assert(Core.decode(assert(Core.encode(event))))
        equal(Core.remaining(restored, 900), 100); equal(Core.remaining(restored, 5000), 0)
        equal(Core.remaining({ enabled = false, deadline = 0 }, 900), 0); equal(Core.remaining(nil, 900), 0)
    end)
    test('event format includes compact day hour minute second units at boundaries', function()
        equal(Core.format(0), '0d 0h 0m 0s'); equal(Core.format(-1), '0d 0h 0m 0s')
        equal(Core.format(59.9), '0d 0h 0m 59s'); equal(Core.format(60), '0d 0h 1m 0s')
        equal(Core.format(3599), '0d 0h 59m 59s'); equal(Core.format(3600), '0d 1h 0m 0s')
        equal(Core.format(86399), '0d 23h 59m 59s'); equal(Core.format(86400), '1d 0h 0m 0s')
        equal(Core.format(123 * 86400 + 4 * 3600 + 5 * 60 + 6), '123d 4h 5m 6s')
        equal(Core.format(math.huge), '0d 0h 0m 0s'); equal(Core.format(nil), '0d 0h 0m 0s')
    end)
    test('event encoder rejects mismatched or malformed states', function()
        equal(Core.encode(nil), nil)
        local bad = active(); bad.enabled = false; equal(Core.encode(bad), nil)
        bad = active(); bad.deadline = 1.5; equal(Core.encode(bad), nil)
        bad = active(); bad.name = '\255'; equal(Core.encode(bad), nil)
        bad = active(); bad.localDate = '2030-02-30 00:00:00'; equal(Core.encode(bad), nil)
        bad = active(); bad.deadline = math.huge; equal(Core.encode(bad), nil)
    end)
end

return Suite
