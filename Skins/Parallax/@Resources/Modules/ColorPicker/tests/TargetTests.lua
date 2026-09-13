-- Calls the production Lua API directly in a mock environment. The payloads
-- below remain data; none is passed to Rainmeter as executable action text.
return function(path,resources)
    local calls,checks={},0
    local variables={['@']=resources,AccentColor='68,9,115',AccentColor2='181,161,226',TitleTextColor='220,220,220',HeaderTextColor='175,175,175',TextColor='210,211,212',BorderColor='50,50,50',DividerColor='60,60,60',TableHeaderBorderColor='70,80,90,0',BorderThickness='3',DividerThickness='1',TableHeaderBorderThickness='2'}
    local env=setmetatable({SKIN={}}, {__index=_G})
    function env.SKIN:GetVariable(key,default) return variables[key] or default end
    function env.SKIN:Bang(...)
        local call={...}; calls[#calls+1]=call
        if call[1]=='!WriteKeyValue' then variables[call[3]]=call[4] end
    end
    local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk(); env.Initialize()
    for _,key in ipairs({'AccentColor','AccentColor2','TitleTextColor','HeaderTextColor','TextColor','BorderColor','DividerColor','TableHeaderBorderColor'}) do
        local expected=variables[key]:match('^(%d+,%d+,%d+)')
        calls={}; assert(env.OpenTarget(key)==true); assert(env.Apply()==true)
        checks=checks+3
        assert(#calls==3 and calls[1][1]=='!WriteKeyValue' and calls[1][3]==key and calls[1][4]==expected)
    end
    -- Editing one line color must preserve the other line colors and thicknesses.
    for _,key in ipairs({'TableHeaderBorderColor','DividerColor','BorderColor'}) do
        local before={}; for name,value in pairs(variables) do before[name]=value end
        calls={}; assert(env.OpenTarget(key)==true)
        env.SelectPlane(100,0); env.SelectSlice(50)
        assert(#calls==0 and variables[key]==before[key])
        assert(env.Apply()==true and #calls==3 and calls[1][3]==key and variables[key]=='0,255,255')
        checks=checks+3
        for name,value in pairs(before) do
            if name~=key then assert(variables[name]==value); checks=checks+1 end
        end
    end
    for _,seed in ipairs({'#46505A80','70,80,90,0'}) do
        variables.TableHeaderBorderColor=seed
        calls={}; assert(env.OpenTarget('TableHeaderBorderColor')==true); assert(env.Apply()==true)
        assert(#calls==3 and calls[1][3]=='TableHeaderBorderColor' and variables.TableHeaderBorderColor=='70,80,90')
        checks=checks+3
    end
    variables.TableHeaderBorderColor=nil
    calls={}; assert(env.OpenTarget('TableHeaderBorderColor')==true); assert(env.Apply()==true)
    assert(#calls==3 and calls[1][3]=='TableHeaderBorderColor' and variables.TableHeaderBorderColor=='50,50,50')
    checks=checks+3
    for _,case in ipairs({{'15,15,15',255},{'15,15,15,0',0},{'15,15,15,128',128},{'15,15,15,255',255},{'0F0F0F',255},{'#0F0F0F00',0},{'0F0F0F80',128},{'#0F0F0FFF',255}}) do
        variables.BackgroundColor=case[1]
        calls={}; assert(env.OpenTarget('BackgroundColor')==true)
        env.SelectPlane(100,0); env.SelectSlice(50); assert(env.Apply()==true)
        assert(#calls==3 and calls[1][3]=='BackgroundColor' and calls[1][4]=='0,255,255,'..case[2])
        checks=checks+3
    end
    for _,bad in ipairs({'','NotAColorTarget','accentcolor','../Settings.inc','AccentColor2\nTextColor=1,2,3',"AccentColor'); os.execute('invalid'); --",'[!WriteKeyValue Variables Unexpected 1]','AccentColor2 ',42,true,{}}) do
        calls={}; assert(env.OpenTarget(bad)==false); assert(#calls==0); checks=checks+2
    end
    calls={}; assert(env.OpenTarget(nil)==false); assert(#calls==0); checks=checks+2
    -- Rejection retains the prior valid target rather than authorizing any new key.
    env.Apply(); assert(calls[1][3]=='BackgroundColor'); checks=checks+1
    return checks
end
