-- Original Parallax IO name-provider regression tests for Lua 5.1.
-- All labels, models, measures and captured bangs are synthetic. This suite
-- does not query hardware, launch a provider, write files or operate Rainmeter.
-- String fixtures cover UTF-8 and opaque local-ANSI bytes; transport is not assumed UTF-8.
-- Usage: local count, report = dofile(thisPath).run(namesProductionPath)
-- Success returns an assertion count and report; failures raise a combined report.
local Suite = {}

function Suite.run(productionPath)
    assert(type(productionPath) == 'string' and productionPath ~= '', 'productionPath is required')
    local assertions, passed, failed, report = 0, 0, 0, {}
    local header = 'IO_MODELS_V1\n'
    local noLabel, noModel = 'No label / unavailable', 'Model unavailable'

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

    local blocked = { io = true, os = true, package = true, debug = true,
        require = true, dofile = true, loadfile = true, loadstring = true }
    local env = setmetatable({}, { __index = function(_, key)
        if blocked[key] then error('unexpected external capability: ' .. key, 2) end
        return _G[key]
    end })
    local chunk, loadError = loadfile(productionPath)
    assert(chunk, loadError)
    setfenv(chunk, env)
    local names = chunk()
    assert(type(names) == 'table', 'Names.lua must return its API table')
    for _, key in ipairs({ 'Parse', 'Format', 'Query' }) do
        assert(type(names[key]) == 'function', 'missing Names.' .. key)
    end

    local function parsed(raw, expected, expectedStatus)
        local map, status = names.Parse(raw)
        equal(type(map), 'table', 'Parse map type')
        equal(status, expectedStatus, 'Parse status')
        local count, expectedCount = 0, 0
        for letter, value in pairs(expected) do
            expectedCount = expectedCount + 1
            equal(map[letter], value, 'model for ' .. letter)
        end
        for letter in pairs(map) do
            count = count + 1
            check(expected[letter] ~= nil, 'unexpected model entry ' .. tostring(letter))
        end
        equal(count, expectedCount, 'model count')
        return map
    end

    local function fixture(options)
        options = options or {}
        local f = { types = { C = 4 }, labels = { C = 'Archive' },
            raw = header .. 'OK\nC|Synthetic Storage', calls = {}, failures = {} }
        for letter, value in pairs(options.types or {}) do f.types[letter] = value end
        for letter, value in pairs(options.labels or {}) do f.labels[letter] = value end
        if options.raw ~= nil then f.raw = options.raw end
        local skin = {}
        function skin:GetMeasure(name)
            if name == 'MeasureIOModelQuery' then
                if f.raw == nil then return nil end
                return { GetStringValue = function()
                    if f.failures.query then error('synthetic query read failure') end
                    return f.raw
                end }
            end
            local letter = type(name) == 'string' and name:match('^MeasureIOType([A-Z])$')
            if letter then
                if f.types[letter] == nil then return nil end
                return { GetValue = function()
                    if f.failures.type then error('synthetic type read failure') end
                    return f.types[letter]
                end }
            end
            letter = type(name) == 'string' and name:match('^MeasureIOName([A-Z])$')
            assert(letter, 'unexpected measure: ' .. tostring(name))
            if f.labels[letter] == nil then return nil end
            return { GetStringValue = function()
                if f.failures.label then error('synthetic label read failure') end
                return f.labels[letter]
            end }
        end
        function skin:Bang(command, ...)
            local args = { ... }
            equal(command, '!CommandMeasure', 'only an explicit model query may dispatch a bang')
            equal(select('#', ...), 2, 'query argument count')
            equal(args[1], 'MeasureIOModelQuery', 'fixed query target')
            equal(args[2], 'Run', 'fixed query command')
            f.calls[#f.calls + 1] = { command = command, args = args }
        end
        f.skin = skin
        return f
    end

    local function formatted(f, letter, mode, expected, tipPart)
        local display, tooltip = names.Format(f.skin, letter, mode)
        equal(display, expected, 'display without drive letter')
        equal(type(tooltip), 'string', 'tooltip type')
        check(not display:find('[%c#%%%[%]]'), 'display contains expression delimiters or controls')
        check(not tooltip:find('[%c#%%%[%]]'), 'tooltip contains expression delimiters or controls')
        if tipPart then
            check(tooltip:find(tipPart, 1, true), 'tooltip must contain ' .. tipPart)
        end
        equal(#f.calls, 0, 'formatting must only read cached data')
        return display, tooltip
    end

    test('empty input and explicit unavailability return an empty unavailable map', function()
        parsed(nil, {}, 'unavailable')
        parsed('', {}, 'unavailable')
        for _, raw in ipairs({ header .. 'UNAVAILABLE', header .. 'UNAVAILABLE\n',
            'IO_MODELS_V1\r\nUNAVAILABLE\r\n' }) do
            parsed(raw, {}, 'unavailable')
        end
    end)

    test('successful packets accept no rows or one optional final newline', function()
        for _, raw in ipairs({ header .. 'OK', header .. 'OK\n' }) do
            parsed(raw, {}, 'ok')
        end
        for _, ending in ipairs({ '', '\n' }) do
            parsed(header .. 'OK\nC|Synthetic Storage' .. ending,
                { C = 'Synthetic Storage' }, 'ok')
        end
        parsed('IO_MODELS_V1\r\nOK\r\nC|Synthetic Storage\r\n',
            { C = 'Synthetic Storage' }, 'ok')
    end)

    test('all 26 unique letters and multiple physical models remain data', function()
        local rows, expected = {}, {}
        for code = 90, 65, -1 do
            local letter = string.char(code)
            expected[letter] = 'Synthetic ' .. letter .. ' / Synthetic Mirror ' .. letter
            rows[#rows + 1] = letter .. '|' .. expected[letter]
        end
        parsed(header .. 'OK\n' .. table.concat(rows, '\n'), expected, 'ok')
    end)

    test('headers statuses and non-string packets must match the protocol exactly', function()
        for _, raw in ipairs({ ' ', 'OK', 'IO_MODELS_V1', 'IO_MODELS_V2\nOK',
            'io_models_v1\nOK', '\239\187\191' .. header .. 'OK',
            ' ' .. header .. 'OK', header .. 'ok', header .. 'UNKNOWN',
            header .. 'OK ', header .. ' OK', header .. 'UNAVAILABLE ',
            0, false, {}, math.huge }) do
            parsed(raw, {}, 'invalid')
        end
    end)

    test('invalid rows reject the complete packet without keeping an earlier model', function()
        for _, row in ipairs({ '', 'c|Model', 'C:|Model', 'CC|Model', '1|Model',
            ' C|Model', 'C |Model', '|Model', 'D', 'D|', 'D|Model|Extra' }) do
            parsed(header .. 'OK\nA|Valid Model\n' .. row .. '\nZ|Another Model', {}, 'invalid')
        end
        parsed(header .. 'UNAVAILABLE\nC|Model', {}, 'invalid')
    end)

    test('duplicate letters reject even identical models and never overwrite', function()
        for _, second in ipairs({ 'First Model', 'Second Model' }) do
            parsed(header .. 'OK\nC|First Model\nC|' .. second, {}, 'invalid')
        end
        local rows = {}
        for code = 65, 90 do rows[#rows + 1] = string.char(code) .. '|Model' end
        rows[#rows + 1] = 'A|Twenty Seventh'
        parsed(header .. 'OK\n' .. table.concat(rows, '\n'), {}, 'invalid')
    end)

    test('extra blank lines and embedded carriage returns reject the packet', function()
        for _, raw in ipairs({ header .. 'OK\n\n', header .. 'UNAVAILABLE\n\n',
            header .. 'OK\nC|Model\n\n', header .. 'OK\nC|One\n\nD|Two',
            'IO_MODELS_V1\rOK', header .. 'OK\nC|Mod\rel' }) do
            parsed(raw, {}, 'invalid')
        end
    end)

    test('model payload rejects expression delimiters control bytes and unnormalized spaces', function()
        for _, payload in ipairs({ '#Variable#', '%PATH%', '[Measure]', '[!Quit]',
            'Model|Other', ' Leading', 'Trailing ', 'Double  Space', 'Tab\tName',
            'Null\0Name', 'Line\nName', 'Return\rName', 'Delete\127Name' }) do
            parsed(header .. 'OK\nC|' .. payload, {}, 'invalid')
        end
    end)

    test('model payload and whole packet are bounded by bytes including multibyte text', function()
        local twoByte = string.char(195, 169)
        parsed(header .. 'OK\nC|' .. string.rep('M', 512), { C = string.rep('M', 512) }, 'ok')
        parsed(header .. 'OK\nC|' .. string.rep(twoByte, 256), { C = string.rep(twoByte, 256) }, 'ok')
        parsed(header .. 'OK\nC|' .. string.rep('M', 513), {}, 'invalid')
        parsed(header .. 'OK\nC|' .. string.rep(twoByte, 257), {}, 'invalid')
        local rows, expected = {}, {}
        for code = 65, 90 do
            local letter = string.char(code)
            expected[letter] = string.rep('M', 512)
            rows[#rows + 1] = letter .. '|' .. expected[letter]
        end
        parsed(header .. 'OK\n' .. table.concat(rows, '\n'), expected, 'ok')
        parsed(header .. 'OK\nC|' .. string.rep('M', 14001), {}, 'invalid')
    end)

    test('local ANSI high-byte labels and models preserve their opaque bytes', function()
        local label = 'Local ' .. string.char(233) .. ' label'
        local model = 'Synthetic ' .. string.char(250) .. ' model'
        local raw = header .. 'OK\nC|' .. model
        parsed(raw, { C = model }, 'ok')
        local f = fixture({ labels = { C = label }, raw = raw })
        formatted(f, 'C', 'volume', label)
        formatted(f, 'C', 'model', model)
        formatted(f, 'C', 'both', label .. ' / ' .. model)
    end)

    test('valid UTF-8 two three and four byte models survive unchanged', function()
        local model = 'Synthetic ' .. string.char(195, 169, 228, 184, 173, 240, 159, 146, 190)
        parsed(header .. 'OK\nC|' .. model, { C = model }, 'ok')
    end)

    test('letters volume model and both modes format only their requested names', function()
        local f = fixture()
        formatted(f, 'C', 'letters', '')
        formatted(f, 'C', 'volume', 'Archive')
        formatted(f, 'C', 'model', 'Synthetic Storage')
        formatted(f, 'C', 'both', 'Archive / Synthetic Storage')
    end)

    test('invalid display modes fall back to volume without dispatching a query', function()
        local f = fixture()
        for _, mode in ipairs({ '', 'Volume', 'MODEL', 'both ', 'model][!Quit]',
            '#Mode#', false, 1, {} }) do
            formatted(f, 'C', mode, 'Archive')
        end
        formatted(f, 'C', nil, 'Archive')
    end)

    test('all native present types including optical may supply names', function()
        for value = 3, 7 do
            local f = fixture({ types = { C = value } })
            formatted(f, 'C', 'both', 'Archive / Synthetic Storage')
        end
    end)

    test('absent invalid and disconnected types mask stale labels and cached models', function()
        for _, value in ipairs({ 0, 1, 2, 8, -1, 4.5, '4', false, math.huge, -math.huge, 0/0 }) do
            local f = fixture({ types = { C = value } })
            formatted(f, 'C', 'letters', '')
            formatted(f, 'C', 'volume', noLabel)
            formatted(f, 'C', 'model', noModel)
            formatted(f, 'C', 'both', noLabel .. '; ' .. noModel)
        end
        local f = fixture()
        f.types.C = nil
        formatted(f, 'C', 'both', noLabel .. '; ' .. noModel)
    end)

    test('invalid letters never become measure names or action arguments', function()
        local f = fixture()
        for _, letter in ipairs({ '', 'c', 'C:', 'CC', ' C', 'C ', 'C,D',
            'C][!Quit]', '#C#', 'C\n', {}, false, 1, math.huge }) do
            local display, tooltip = names.Format(f.skin, letter, 'both')
            equal(display, '')
            equal(tooltip, 'Drive unavailable.')
        end
        local display, tooltip = names.Format(f.skin, nil, 'both')
        equal(display, '')
        equal(tooltip, 'Drive unavailable.')
        equal(#f.calls, 0)
    end)

    test('unlabeled and missing native names use exact mode-specific fallbacks', function()
        for _, label in ipairs({ '', ' \t\r\n ', false, 42 }) do
            local f = fixture({ labels = { C = label } })
            formatted(f, 'C', 'volume', noLabel)
            formatted(f, 'C', 'both', 'Synthetic Storage', noLabel)
        end
        local f = fixture()
        f.labels.C = nil
        formatted(f, 'C', 'volume', noLabel)
        formatted(f, 'C', 'both', 'Synthetic Storage', noLabel)
    end)

    test('missing unavailable and invalid model packets retain only a known volume', function()
        for _, raw in ipairs({ '', header .. 'UNAVAILABLE', header .. 'OK',
            header .. 'OK\nD|Other Model', header .. 'OK\nC|First\nC|Duplicate',
            'bad packet', false }) do
            local f = fixture({ raw = raw })
            formatted(f, 'C', 'model', noModel)
            formatted(f, 'C', 'both', 'Archive', noModel)
        end
        local f = fixture()
        f.raw = nil
        formatted(f, 'C', 'model', noModel)
        formatted(f, 'C', 'both', 'Archive', noModel)
    end)

    test('neither available name exposes both missing parts explicitly', function()
        local f = fixture({ labels = { C = '' }, raw = header .. 'UNAVAILABLE' })
        local _, tooltip = formatted(f, 'C', 'both', noLabel .. '; ' .. noModel, noLabel)
        check(tooltip:find(noModel, 1, true), 'tooltip must identify missing model')
    end)

    test('failed cached measure reads preserve available parts without querying', function()
        local f = fixture()
        f.failures.label = true
        formatted(f, 'C', 'both', 'Synthetic Storage', noLabel)
        f.failures.label, f.failures.query = nil, true
        formatted(f, 'C', 'both', 'Archive', noModel)
        f.failures.query, f.failures.type = nil, true
        formatted(f, 'C', 'both', noLabel .. '; ' .. noModel)
    end)

    test('native labels are normalized into single-line literal display data', function()
        local f = fixture({ labels = { C = '  Alpha#Beta%Gamma[Delta]\tEpsilon\r\nZeta  ' } })
        formatted(f, 'C', 'volume', 'Alpha Beta Gamma Delta Epsilon Zeta')
        formatted(f, 'C', 'both', 'Alpha Beta Gamma Delta Epsilon Zeta / Synthetic Storage')
        f.labels.C = 'Quote " and apostrophe \' stay'
        formatted(f, 'C', 'volume', 'Quote " and apostrophe \' stay')
        f.labels.C = '#[%]\t\r\n'
        formatted(f, 'C', 'volume', noLabel)
    end)

    test('long native labels truncate at complete UTF-8 character boundaries', function()
        for _, bytes in ipairs({ {195, 169}, {228, 184, 173}, {240, 159, 146, 190} }) do
            local character = string.char(unpack(bytes))
            local f = fixture({ labels = { C = string.rep(character, 520) } })
            local display, tooltip = names.Format(f.skin, 'C', 'volume')
            equal(type(display), 'string')
            check(#display > 0 and #display <= 512, 'label must fit the 512-byte limit')
            equal(#display % #character, 0, 'truncation split a UTF-8 character')
            equal(display, string.rep(character, #display / #character), 'truncation changed complete characters')
            equal(type(tooltip), 'string')
            equal(#f.calls, 0)
        end
    end)

    test('cached model lookup stays letter-specific and preserves multiple model names', function()
        local f = fixture({ types = { A = 3, Z = 7 }, labels = { A = 'First', Z = 'Last' },
            raw = header .. 'OK\nA|Model Alpha / Model Mirror\nC|Model Center\nZ|Model Zeta' })
        formatted(f, 'A', 'both', 'First / Model Alpha / Model Mirror')
        formatted(f, 'C', 'model', 'Model Center')
        formatted(f, 'Z', 'both', 'Last / Model Zeta')
    end)

    test('format observes cache and type transitions without launching collection', function()
        local f = fixture()
        formatted(f, 'C', 'both', 'Archive / Synthetic Storage')
        f.raw, f.labels.C = header .. 'OK\nC|Replacement Model', 'New Label'
        formatted(f, 'C', 'both', 'New Label / Replacement Model')
        f.types.C = 1
        formatted(f, 'C', 'both', noLabel .. '; ' .. noModel)
        f.types.C = 4
        formatted(f, 'C', 'both', 'New Label / Replacement Model')
        f.raw = header .. 'UNAVAILABLE'
        formatted(f, 'C', 'both', 'New Label', noModel)
    end)

    test('only exact model and both query modes dispatch the fixed Run command', function()
        for _, mode in ipairs({ 'model', 'both' }) do
            local f = fixture()
            equal(names.Query(f.skin, mode), true)
            equal(#f.calls, 1, 'one explicit query request')
        end
        local f = fixture()
        for _, mode in ipairs({ 'letters', 'volume', '', 'Model', 'BOTH', 'model ',
            '[!Quit]', 'model][!Quit]', '#Mode#', false, {}, 1 }) do
            equal(names.Query(f.skin, mode), false)
        end
        equal(names.Query(f.skin, nil), false)
        equal(#f.calls, 0, 'non-model modes must not query')
    end)

    report[#report + 1] = string.format('SUMMARY: %d tests, %d assertions, %d failed',
        passed + failed, assertions, failed)
    local summary = table.concat(report, '\n')
    if failed > 0 then error(summary, 0) end
    return assertions, summary
end

return Suite
