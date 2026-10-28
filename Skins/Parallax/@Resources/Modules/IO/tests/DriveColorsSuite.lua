-- Original Parallax Disk Meter drive color module tests for Lua 5.1.
-- Pure functions only; no Rainmeter, file or process access.
-- Usage: local count, report = dofile(thisPath).run(driveColorsProductionPath)
-- The settings and monitor controllers use these functions; their suites cover the wiring.
local Suite = {}

function Suite.run(productionPath)
    assert(type(productionPath) == 'string' and productionPath ~= '', 'productionPath is required')
    local assertions, passed, failed, report = 0, 0, 0, {}

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

    local function load()
        local chunk = assert(loadfile(productionPath))
        return chunk()
    end

    test('defaults are fixed per letter, distinct, and valid opaque RGB', function()
        local Colors = load()
        local seen = {}
        for code = 65, 90 do
            local letter = string.char(code)
            local color = Colors.Default(letter)
            truth(color:match('^%d+,%d+,%d+$'), 'default is R,G,B')
            for channel in color:gmatch('%d+') do truth(tonumber(channel) <= 255, 'channel range') end
            equal(Colors.Default(letter), color, 'default must be stable')
            truth(not seen[color], 'duplicate default for ' .. letter)
            seen[color] = true
        end
    end)

    test('normalize accepts hex and RGB, drops alpha, and rejects everything else', function()
        local Colors = load()
        equal(Colors.Normalize('#FF8000', 'x'), '255,128,0')
        equal(Colors.Normalize('ff8000', 'x'), '255,128,0')
        equal(Colors.Normalize('#FF800080', 'x'), '255,128,0')
        equal(Colors.Normalize(' 1, 2 ,3 ', 'x'), '1,2,3')
        for _, bad in ipairs({ '', '#FFF', '256,0,0', '1,2', '#GG0000', 'red', '1,2,3,4' }) do
            equal(Colors.Normalize(bad, 'x'), 'x', 'rejects ' .. bad)
        end
        equal(Colors.Normalize(nil, nil), nil)
        equal(Colors.Hex('255,128,0'), '#FF8000')
        equal(Colors.Hex('0,0,0'), '#000000')
    end)

    test('Get returns the saved color, else the default for invalid or absent values', function()
        local Colors = load()
        local vars = { IODriveColorD = '#00C8FF', IODriveColorE = 'junk' }
        local skin = { GetVariable = function(_, key, default) return vars[key] == nil and default or vars[key] end }
        equal(Colors.Get(skin, 'D'), '0,200,255')
        equal(Colors.Get(skin, 'E'), Colors.Default('E'))
        equal(Colors.Get(skin, 'F'), Colors.Default('F'))
    end)

    local summary = string.format('SUMMARY: %d tests, %d assertions, %d failed', passed + failed, assertions, failed)
    report[#report + 1] = summary
    if failed > 0 then error(table.concat(report, '\n'), 0) end
    return assertions, report
end

return Suite
