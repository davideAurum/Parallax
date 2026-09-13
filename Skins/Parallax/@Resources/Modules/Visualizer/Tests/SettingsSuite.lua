-- Run inside an isolated Lua 5.1 host: dofile(thisFile)(productionModulePath).
-- Production code receives only a mocked SKIN; no file, UI or provider actions run.
return function(modulePath)
    local cases = 0
    local function test(name, fn)
        local ok, failure = pcall(fn)
        assert(ok, name .. ': ' .. tostring(failure))
        cases = cases + 1
    end
    local function eq(actual, expected)
        assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
    end
    local definitions = {
        {'Width','Columns',{1,2},true},
        {'Color','VisualizerColorMode',{0,1,2,3},true},
        {'Quality','VisualizerQuality',{0,1,2},true},
        {'Cadence','VisualizerUpdateOverride',{0,33,50,100},true},
        {'Height','PanelHeight',{126,146,186},false,126,186,true},
        {'Spacing','VisualizerBandGap',{0,1,3,4},false,0,4},
        {'Sensitivity','VisualizerSensitivity',{10,20,35,50,65,80},false,10,80},
        {'Attack','VisualizerAttack',{0,50,100,200,2000},false,0,2000},
        {'Decay','VisualizerDecay',{0,100,250,500,1000,5000},false,0,5000}
    }
    local allowed = {}
    for _, item in ipairs(definitions) do allowed[item[2]] = true end
    local function fixture(key, value)
        local vars = { ['@']='C:\\Isolated\\@Resources\\', Scale='0.75',
            Columns='2', PanelHeight='146', VisualizerBandGap='1', VisualizerColorMode='0',
            VisualizerQuality='1', VisualizerUpdateOverride='0', VisualizerSensitivity='35',
            VisualizerAttack='50', VisualizerDecay='250', VisualizerDeviceID='kept',
            VisualizerIdleThreshold='0.001' }
        if key then vars[key] = tostring(value) end
        local calls, output = {}, ''
        local skin = {}
        function skin:GetVariable(name, fallback) return vars[name] or fallback end
        function skin:GetX() return -100 end
        function skin:GetY() return 40 end
        function skin:GetMeter(name)
            assert(name:match('^MeterVisualizerSettings%w+Row$'))
            return {GetX=function() return 105 end, GetY=function() return 76 end,
                GetW=function() return 42 end, GetH=function() return 15 end}
        end
        function skin:GetMeasure(name)
            eq(name,'MeasureVisualizerSettingsInput')
            return {GetStringValue=function() return output end}
        end
        function skin:Bang(...)
            local args = {...}
            calls[#calls+1] = args
            if args[1] == '!WriteKeyValue' then
                eq(args[2],'Variables'); assert(allowed[args[3]])
                eq(args[5],vars['@'] .. 'User\\Visualizer.inc')
                assert(args[4]:match('^%d+$'))
                vars[args[3]] = args[4]
            elseif args[1] == '!Refresh' then
                assert(args[2] == nil or args[2] == 'Parallax\\Visualizer')
            elseif args[1] == '!SetOption' then
                eq(args[2],'MeasureVisualizerSettingsInput'); eq(args[3],'Parameter')
                assert(args[4]:find('-Key UtilityNumber',1,true))
                assert(not args[4]:find('!WriteKeyValue',1,true))
            elseif args[1] == '!UpdateMeasure' or args[1] == '!CommandMeasure' then
                eq(args[2],'MeasureVisualizerSettingsInput')
                if args[1] == '!CommandMeasure' then eq(args[3],'Run') end
            else error('Unexpected bang: ' .. tostring(args[1])) end
        end
        local env = setmetatable({SKIN=skin}, {__index=_G})
        setfenv(assert(loadfile(modulePath)),env)()
        env.Initialize()
        eq(#calls,0); eq(env.Update(),0); eq(#calls,0)
        return env, vars, calls, function(value) output=value end
    end
    local function saved(calls, key, value)
        eq(#calls,3); eq(calls[1][1],'!WriteKeyValue'); eq(calls[1][3],key)
        eq(calls[1][4],tostring(value)); eq(calls[2][1],'!Refresh')
        eq(calls[2][2],'Parallax\\Visualizer'); eq(calls[3][1],'!Refresh'); eq(calls[3][2],nil)
    end
    for _, definition in ipairs(definitions) do
        local name,key,values,categorical = unpack(definition)
        for index,value in ipairs(values) do
            for _,direction in ipairs({-1,1}) do
                test(name .. ' step ' .. value .. '/' .. direction,function()
                    local env,vars,calls=fixture(key,value)
                    local nextIndex = index + direction
                    if categorical then nextIndex=(nextIndex-1)%#values+1 end
                    if nextIndex<1 or nextIndex>#values then eq(env.Step(name,direction),false); eq(#calls,0)
                    else eq(env.Step(name,direction),true); saved(calls,key,values[nextIndex]) end
                    eq(vars.VisualizerDeviceID,'kept'); eq(vars.VisualizerIdleThreshold,'0.001')
                end)
            end
            if categorical then
                test(name .. ' center ' .. value,function()
                    local env,_,calls=fixture(key,value)
                    eq(env.Activate(name),true); saved(calls,key,values[index%#values+1])
                end)
            end
        end
        test(name .. ' custom remains until explicit action',function()
            local env,vars,calls=fixture(key,'(10+5)')
            eq(vars[key],'(10+5)'); eq(#calls,0)
            eq(env.Step(name,1),true); saved(calls,key,values[1])
        end)
        if not categorical then
            test(name .. ' custom nearest neighbors',function()
                local value=(values[1]+values[2])/2
                -- Choose an integer custom value where the first interval permits it.
                if value ~= math.floor(value) then value=2 end
                local previous,nextValue
                for _,choice in ipairs(values) do
                    if choice<value then previous=choice end
                    if choice>value and not nextValue then nextValue=choice end
                end
                for _,pair in ipairs({{-1,previous},{1,nextValue}}) do
                    local env,_,calls=fixture(key,value)
                    eq(env.Step(name,pair[1]),true); saved(calls,key,pair[2])
                end
            end)
            for _,value in ipairs({definition[5],definition[6]}) do
                test(name .. ' typed bound ' .. value,function()
                    local env,_,calls,setOutput=fixture(key,value==values[1] and values[2] or values[1])
                    eq(env.Activate(name),true); eq(#calls,3)
                    local parameter=calls[1][4]
                    assert(parameter:find('-Minimum '..definition[5]..' -Maximum '..definition[6]..' -DecimalPlaces 0',1,true))
                    assert(parameter:find('-X 5 -Y 116 -Width 42 -Height 20 -Scale 0.7500',1,true))
                    for i=#calls,1,-1 do calls[i]=nil end
                    setOutput('PARALLAX_INPUT_V1|ok|'..value..'\r\n')
                    eq(env.CommitInput(),true); saved(calls,key,value)
                    eq(env.CommitInput(),false); eq(#calls,3)
                end)
            end
            local invalid={'','PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|nan',
                'PARALLAX_INPUT_V1|ok|1e2','PARALLAX_INPUT_V1|ok|1.0',
                'PARALLAX_INPUT_V1|ok|1.5','PARALLAX_INPUT_V1|ok| 1',
                'PARALLAX_INPUT_V1|ok|1|extra','PARALLAX_INPUT_V1|ok|1\n[!Quit]',
                'PARALLAX_INPUT_V1|ok|99999999999999999999999999999999999999999',
                'PARALLAX_INPUT_V1|ok|'..(definition[5]-1),'PARALLAX_INPUT_V1|ok|'..(definition[6]+1)}
            if definition[7] then invalid[#invalid+1]='PARALLAX_INPUT_V1|ok|150' end
            for index,text in ipairs(invalid) do
                test(name .. ' reject input ' .. index,function()
                    local env,vars,calls,setOutput=fixture(key,values[1])
                    eq(env.Activate(name),true)
                    eq(env.Activate(name),false); eq(env.Step('Width',1),false); eq(#calls,3)
                    setOutput(text); eq(env.CommitInput(),false); eq(#calls,3); eq(vars[key],tostring(values[1]))
                    -- Cancel or rejection releases the pending editor for another attempt.
                    eq(env.Activate(name),true); eq(#calls,6)
                end)
            end
            test(name .. ' unchanged input writes nothing',function()
                local env,_,calls,setOutput=fixture(key,values[1])
                eq(env.Activate(name),true)
                setOutput('PARALLAX_INPUT_V1|ok|'..values[1]); eq(env.CommitInput(),false); eq(#calls,3)
            end)
        end
    end
    test('Continuous typed value and canonical sign',function()
        local env,vars,calls,setOutput=fixture('VisualizerBandGap',1)
        eq(env.Activate('Spacing'),true)
        for i=#calls,1,-1 do calls[i]=nil end
        setOutput('PARALLAX_INPUT_V1|ok|+002'); eq(env.CommitInput(),true)
        saved(calls,'VisualizerBandGap',2); eq(vars.VisualizerBandGap,'2')
    end)
    test('Unknown field, invalid direction, stale result',function()
        local env,_,calls,setOutput=fixture()
        for _,name in ipairs({'','VisualizerDeviceID','Width); os.execute("bad")','NoSuchField'}) do
            eq(env.Activate(name),false); eq(env.Step(name,1),false)
        end
        for _,direction in ipairs({0,2,-2,'1',true}) do eq(env.Step('Width',direction),false) end
        setOutput('PARALLAX_INPUT_V1|ok|2'); eq(env.CommitInput(),false); eq(#calls,0)
    end)
    return cases
end
