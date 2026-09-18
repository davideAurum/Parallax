-- Actual Color.lua under native Rainmeter Lua 5.1, with a restricted mocked SKIN.
-- Caller: assert(loadfile(suitePath))()(colorLuaPath) -> passed case count.
-- Rendering/interpolation belongs to native Shape meters and is checked separately.
return function(modulePath)
    local passed = 0
    local base = 'Rectangle 0,0,#VisualizerPlotInnerWidth#,#VisualizerBarHeight#'
    local gradientShape = base .. ' | Fill LinearGradient SpectrumGradient | StrokeWidth 0'
    local function equal(actual, expected, label)
        if actual ~= expected then
            error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
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
    local allowed = {VisualizerColorMode=true, MediaColor=true, AccentColor=true, AccentColor2=true}
    local function fixture(overrides)
        local mock = {variables={VisualizerColorMode='3', MediaColor='12,34,56,78',
            AccentColor='137,190,250', AccentColor2='181,161,226'}, calls={}, options={}}
        for key, value in pairs(overrides or {}) do mock.variables[key] = value end
        local skin = {}
        function skin:GetVariable(key, default)
            truth(allowed[key], 'unexpected variable read ' .. tostring(key))
            local value = mock.variables[key]
            if value == nil then return default end
            return value
        end
        function skin:Bang(name, ...)
            local argv = {...}
            mock.calls[#mock.calls + 1] = {name=name, args=argv}
            if name == '!SetOption' then
                equal(#argv, 3)
                equal(argv[1], 'MeterVisualizerFill', 'only the fill may be modified')
                truth(argv[2] == 'Shape' or argv[2] == 'SpectrumGradient', 'unexpected option')
                equal(type(argv[3]), 'string')
                mock.options[argv[2]] = argv[3]
            elseif name == '!UpdateMeter' then
                equal(#argv, 1)
                equal(argv[1], 'MeterVisualizerFill', 'only the static fill needs an explicit update')
            elseif name == '!Redraw' then
                equal(#argv, 0)
            else
                error('forbidden side effect: ' .. tostring(name))
            end
        end
        local env = setmetatable({SKIN=skin, tonumber=tonumber, tostring=tostring,
            math={max=math.max, min=math.min, floor=math.floor, huge=math.huge},
            table={concat=table.concat}}, {
            __index=function(_, key) error('forbidden global access: ' .. tostring(key), 2) end
        })
        local chunk, message = loadfile(modulePath)
        truth(chunk, 'cannot load Color.lua: ' .. tostring(message))
        setfenv(chunk, env)
        chunk()
        equal(#mock.calls, 0, 'source loading is passive')
        equal(type(rawget(env, 'Apply')), 'function')
        equal(rawget(env, 'Update'), nil, 'no per-frame Lua callback')
        mock.env = env
        function mock:apply()
            self.calls = {}
            self.env.Apply()
        end
        return mock
    end
    local function completed(mock, count)
        equal(#mock.calls, count + 2, 'bounded call count')
        equal(mock.calls[count + 1].name, '!UpdateMeter', 'one explicit fill update')
        equal(mock.calls[count + 2].name, '!Redraw', 'one final redraw')
    end
    local firstDefault, lastDefault = '137,190,250,255', '181,161,226,255'
    local function gradient(mock, angle, first, last)
        mock:apply()
        completed(mock, 2)
        equal(mock.calls[1].name, '!SetOption')
        equal(mock.calls[1].args[2], 'SpectrumGradient', 'stops must precede shape rebind')
        equal(mock.calls[2].name, '!SetOption')
        equal(mock.calls[2].args[2], 'Shape')
        equal(mock.options.SpectrumGradient, angle .. ' | ' .. first .. ' ; 0 | ' .. last .. ' ; 1')
        equal(mock.options.Shape, gradientShape, 'fixed full-height fill; mask owns amplitude')
    end
    local function solid(mock, expected)
        mock:apply()
        completed(mock, 1)
        equal(mock.calls[1].name, '!SetOption')
        equal(mock.calls[1].args[2], 'Shape')
        equal(mock.options.Shape, base .. ' | Fill Color ' .. expected .. ' | StrokeWidth 0')
    end
    test('passive load exports only refresh work', function() fixture() end)
    for _, mode in ipairs({'3', '4'}) do
        local angle = mode == '3' and '180' or '90'
        local function colors(label, first, last, expectedFirst, expectedLast)
            test(label .. ', mode ' .. mode, function()
                gradient(fixture({VisualizerColorMode=mode, AccentColor=first, AccentColor2=last}),
                    angle, expectedFirst, expectedLast)
            end)
        end
        colors('exact shipped endpoints and native axis', '137,190,250', '181,161,226', firstDefault, lastDefault)
        colors('different endpoint alpha including zero', '10,200,0,0', '240,10,255,255', '10,200,0,0', '240,10,255,255')
        colors('RGB alpha defaults opaque', '12,34,56', '78,90,12', '12,34,56,255', '78,90,12,255')
        colors('six-digit hex', '0c2238', '4E5A0C', '12,34,56,255', '78,90,12,255')
        colors('eight-digit hex alpha', '0c223800', '4E5A0C80', '12,34,56,0', '78,90,12,128')
        colors('whitespace accepted', ' 12, 34, 56, 78 ', ' 0C22384E ', '12,34,56,78', '12,34,56,78')
        colors('channels rounded and clamped', '-3,256,1.6,0', '254.5,1.4,2.5,999', '0,255,2,0', '255,1,3,255')
        colors('invalid first falls back independently', 'invalid', '12,34,56', firstDefault, '12,34,56,255')
        colors('invalid second falls back independently', '12,34,56', 'invalid', '12,34,56,255', lastDefault)
        test('missing accents use defaults, mode ' .. mode, function()
            local mock = fixture({VisualizerColorMode=mode})
            mock.variables.AccentColor, mock.variables.AccentColor2 = nil, nil
            gradient(mock, angle, firstDefault, lastDefault)
        end)
        for _, invalid in ipairs({'', '1,2', '1,2,3,4,5', '1,,3', '1,2,3,', ',1,2,3',
            '11223Z', '#112233', '(100+37),190,250', '1e999,2,3', '-1e999,2,3'}) do
            colors('malformed color fallback ' .. invalid, invalid, invalid, firstDefault, lastDefault)
        end
    end
    for _, previous in ipairs({'3', '4'}) do
        for _, mode in ipairs({'0', '1', '2', '-1', '0.5', '5', '999', 'invalid', ''}) do
            test('solid/invalid mode replaces gradient ' .. previous .. ' to ' .. mode, function()
                local mock = fixture({VisualizerColorMode=previous})
                gradient(mock, previous == '3' and '180' or '90', firstDefault, lastDefault)
                mock.variables.VisualizerColorMode = mode
                local key = mode == '1' and 'AccentColor' or mode == '2' and 'AccentColor2' or 'MediaColor'
                solid(mock, mock.variables[key])
                equal(mock.variables.VisualizerColorMode, mode, 'saved mode remains unmodified')
            end)
        end
    end
    test('missing mode returns to Media', function()
        local mock = fixture()
        gradient(mock, '180', firstDefault, lastDefault)
        mock.variables.VisualizerColorMode = nil
        solid(mock, '12,34,56,78')
    end)
    test('switching axes restores each exact full-plot gradient', function()
        local mock = fixture()
        for _, mode in ipairs({'3', '4', '3', '4'}) do
            mock.variables.VisualizerColorMode = mode
            gradient(mock, mode == '3' and '180' or '90', firstDefault, lastDefault)
        end
    end)
    test('reapply reads changed accents without touching visibility or profiles', function()
        local mock = fixture()
        gradient(mock, '180', firstDefault, lastDefault)
        mock.variables.AccentColor, mock.variables.AccentColor2 = '12,34,56,0', '78,90,12,128'
        gradient(mock, '180', '12,34,56,0', '78,90,12,128')
        equal(mock.variables.AccentColor, '12,34,56,0')
        equal(mock.variables.AccentColor2, '78,90,12,128')
        equal(rawget(mock.env, 'Update'), nil)
    end)
    return passed
end
