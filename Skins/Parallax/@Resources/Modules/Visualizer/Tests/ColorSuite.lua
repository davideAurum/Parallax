-- Synthetic tests for the actual Color.lua under native Rainmeter Lua 5.1.
-- Caller: assert(loadfile(suitePath))()(colorLuaPath) -> passed case count.
-- Only this suite loads the source file. The implementation sees a restricted
-- environment and mocked SKIN: no real meter, preference, process or file changes.
return function(modulePath)
    local passed = 0
    local function equal(actual, expected, label)
        if actual ~= expected then
            error((label or 'value') .. ': expected ' .. tostring(expected) ..
                ', got ' .. tostring(actual), 2)
        end
    end
    local function truth(value, label)
        if not value then error(label or 'expected true', 2) end
    end
    local function test(name, body)
        local success, message = pcall(body)
        if not success then error(name .. ': ' .. tostring(message), 0) end
        passed = passed + 1
    end
    local allowedVariables = {
        VisualizerColorMode=true, MediaColor=true, AccentColor=true, AccentColor2=true
    }
    local function fixture(overrides)
        local mock = {
            variables = {
                VisualizerColorMode='3', MediaColor='12,34,56,78',
                AccentColor='137,190,250', AccentColor2='181,161,226'
            },
            colors={}, calls={}
        }
        for key, value in pairs(overrides or {}) do mock.variables[key] = value end
        local skin = {}
        function skin:GetVariable(key, default)
            truth(allowedVariables[key], 'unexpected variable read ' .. tostring(key))
            local value = mock.variables[key]
            if value == nil then return default end
            return value
        end
        function skin:Bang(name, ...)
            local args = {...}
            mock.calls[#mock.calls + 1] = { name=name, args=args }
            if name == '!SetOption' then
                equal(#args, 3, 'individual color argument count')
                equal(args[2], 'BarColor')
                truth(type(args[3]) == 'string', 'individual color must be a string')
                local index = tonumber(tostring(args[1]):match('^MeterVisualizerBand(%d+)$'))
                truth(index and index >= 0 and index <= 23, 'unexpected meter ' .. tostring(args[1]))
                equal(args[1], 'MeterVisualizerBand' .. index, 'exact meter name')
                local count = 0
                for channel in args[3]:gmatch('[^,]+') do
                    count = count + 1
                    local number = tonumber(channel)
                    truth(number and number >= 0 and number <= 255 and number == math.floor(number),
                        'noncanonical generated channel ' .. tostring(channel))
                end
                equal(count, 4, 'generated RGBA component count')
                mock.colors[index] = args[3]
            elseif name == '!SetOptionGroup' then
                equal(#args, 3, 'group color argument count')
                equal(args[1], 'VisualizerSpectrum')
                equal(args[2], 'BarColor')
                truth(type(args[3]) == 'string', 'solid color must remain a string')
                for index = 0, 23 do mock.colors[index] = args[3] end
            elseif name == '!UpdateMeterGroup' then
                equal(#args, 1)
                equal(args[1], 'VisualizerSpectrum')
            elseif name == '!Redraw' then
                equal(#args, 0)
            else
                error('forbidden side effect: ' .. tostring(name))
            end
        end
        local env = setmetatable({
            SKIN=skin, tonumber=tonumber, tostring=tostring,
            math={max=math.max, min=math.min, floor=math.floor, huge=math.huge},
            table={concat=table.concat}
        }, {
            __index=function(_, key)
                error('forbidden global access: ' .. tostring(key), 2)
            end
        })
        local chunk, message = loadfile(modulePath)
        truth(chunk, 'cannot load Color.lua: ' .. tostring(message))
        setfenv(chunk, env)
        chunk()
        equal(#mock.calls, 0, 'source loading must not perform work')
        equal(type(rawget(env, 'Apply')), 'function', 'refresh callback')
        equal(rawget(env, 'Update'), nil, 'no per-frame Lua callback')
        mock.env = env
        function mock:apply()
            self.calls = {}
            self.env.Apply()
        end
        return mock
    end
    local function completed(mock, mutations)
        equal(#mock.calls, mutations + 2, 'bounded call count')
        equal(mock.calls[mutations + 1].name, '!UpdateMeterGroup', 'single final meter update')
        equal(mock.calls[mutations + 2].name, '!Redraw', 'single final redraw')
    end
    local function gradient(mock, expected)
        mock:apply()
        completed(mock, 24)
        equal(#expected, 24, 'fixture band count')
        local seen = {}
        for index = 0, 23 do
            local call = mock.calls[index + 1]
            equal(call.name, '!SetOption', 'gradient uses individual colors')
            equal(call.args[1], 'MeterVisualizerBand' .. index, 'ordered bounded target')
            truth(not seen[call.args[1]], 'duplicate gradient target')
            seen[call.args[1]] = true
            equal(mock.colors[index], expected[index + 1], 'band ' .. index)
        end
    end
    local function constant(color)
        local result = {}
        for index = 1, 24 do result[index] = color end
        return result
    end
    local fractional = {
        '10,200,0,0',
        '20,192,11,11',
        '30,183,22,22',
        '40,175,33,33',
        '50,167,44,44',
        '60,159,55,55',
        '70,150,67,67',
        '80,142,78,78',
        '90,134,89,89',
        '100,126,100,100',
        '110,117,111,111',
        '120,109,122,122',
        '130,101,133,133',
        '140,93,144,144',
        '150,84,155,155',
        '160,76,166,166',
        '170,68,177,177',
        '180,60,188,188',
        '190,51,200,200',
        '200,43,211,211',
        '210,35,222,222',
        '220,27,233,233',
        '230,18,244,244',
        '240,10,255,255'
    }
    local defaultGradient = {
        '137,190,250,255',
        '139,189,249,255',
        '141,187,248,255',
        '143,186,247,255',
        '145,185,246,255',
        '147,184,245,255',
        '148,182,244,255',
        '150,181,243,255',
        '152,180,242,255',
        '154,179,241,255',
        '156,177,240,255',
        '158,176,239,255',
        '160,175,237,255',
        '162,174,236,255',
        '164,172,235,255',
        '166,171,234,255',
        '168,170,233,255',
        '170,169,232,255',
        '171,167,231,255',
        '173,166,230,255',
        '175,165,229,255',
        '177,164,228,255',
        '179,162,227,255',
        '181,161,226,255'
    }

    test('load is passive and exports no frame callback', function()
        fixture()
    end)
    test('24 exact default band colors and exact accent endpoints', function()
        gradient(fixture(), defaultGradient)
    end)
    test('24 exact asymmetric colors include descending-channel and alpha rounding', function()
        gradient(fixture({AccentColor='10,200,0,0', AccentColor2='240,10,255,255'}), fractional)
    end)
    test('exact unit increments use all 23 intervals', function()
        local expected = {}
        for index = 0, 23 do
            expected[index + 1] = index .. ',' .. (index + 23) .. ',' .. (index + 46) .. ',' .. (index + 69)
        end
        gradient(fixture({AccentColor='0,23,46,69', AccentColor2='23,46,69,92'}), expected)
    end)
    test('omitted alpha is opaque for RGB endpoints', function()
        gradient(fixture({AccentColor='12,34,56', AccentColor2='12,34,56'}), constant('12,34,56,255'))
    end)
    test('explicit zero alpha stays transparent', function()
        gradient(fixture({AccentColor='12,34,56,0', AccentColor2='12,34,56,0'}), constant('12,34,56,0'))
    end)
    test('six-digit hex is RGB and defaults alpha to 255', function()
        gradient(fixture({AccentColor='0c2238', AccentColor2='0C2238'}), constant('12,34,56,255'))
    end)
    test('eight-digit hex uses trailing alpha and preserves zero', function()
        gradient(fixture({AccentColor='0c223800', AccentColor2='0C223800'}), constant('12,34,56,0'))
    end)
    test('mixed RGB and RGBA hex interpolate all channels', function()
        gradient(fixture({AccentColor='0AC80000', AccentColor2='F00AFFFF'}), fractional)
    end)
    test('whitespace around and within decimal color is accepted', function()
        gradient(fixture({AccentColor=' 12, 34, 56, 78 ', AccentColor2='  0C22384E  '}), constant('12,34,56,78'))
    end)
    test('numeric channels are rounded and clamped before interpolation', function()
        gradient(fixture({AccentColor='-3,256,1.6,0', AccentColor2='0,255,2,0'}), constant('0,255,2,0'))
    end)
    test('invalid first accent falls back independently', function()
        local mock = fixture({AccentColor='invalid', AccentColor2='137,190,250,255'})
        gradient(mock, constant('137,190,250,255'))
    end)
    test('invalid second accent falls back independently', function()
        local mock = fixture({AccentColor='181,161,226,255', AccentColor2='invalid'})
        gradient(mock, constant('181,161,226,255'))
    end)
    test('missing accents use shipped defaults', function()
        local mock = fixture()
        mock.variables.AccentColor = nil
        mock.variables.AccentColor2 = nil
        gradient(mock, defaultGradient)
    end)
    for _, invalid in ipairs({
        '', '1,2', '1,2,3,4,5', '1,,3', '1,2,3,', ',1,2,3',
        '11223Z', '#112233', '(100+37),190,250', '1e999,2,3', '-1e999,2,3'
    }) do
        test('malformed color fallback: ' .. invalid, function()
            gradient(fixture({AccentColor=invalid, AccentColor2=invalid}), defaultGradient)
        end)
    end
    for _, mode in ipairs({'0', '1', '2', '-1', '0.5', '4', '999', 'invalid', ''}) do
        test('solid or invalid mode resets every previously gradient-colored band: ' .. mode, function()
            local mock = fixture()
            gradient(mock, defaultGradient)
            mock.variables.VisualizerColorMode = mode
            mock:apply()
            completed(mock, 1)
            equal(mock.calls[1].name, '!SetOptionGroup', 'solid must replace the entire group')
            local key = mode == '1' and 'AccentColor' or mode == '2' and 'AccentColor2' or 'MediaColor'
            for index = 0, 23 do equal(mock.colors[index], mock.variables[key], 'solid reset band ' .. index) end
            equal(mock.variables.VisualizerColorMode, mode, 'mode remains unmodified')
        end)
    end
    test('missing mode returns every band to Media', function()
        local mock = fixture()
        gradient(mock, defaultGradient)
        mock.variables.VisualizerColorMode = nil
        mock:apply()
        completed(mock, 1)
        for index = 0, 23 do equal(mock.colors[index], '12,34,56,78', 'missing mode band ' .. index) end
    end)
    test('explicit reapply reads changed accents without visibility or profile changes', function()
        local mock = fixture()
        gradient(mock, defaultGradient)
        mock.variables.AccentColor = '12,34,56,78'
        mock.variables.AccentColor2 = '12,34,56,78'
        gradient(mock, constant('12,34,56,78'))
        equal(mock.variables.AccentColor, '12,34,56,78')
        equal(mock.variables.AccentColor2, '12,34,56,78')
        equal(rawget(mock.env, 'Update'), nil)
    end)
    return passed
end
