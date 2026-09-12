-- Calls the production Lua API directly in a mock environment. The payloads
-- below remain data; none is passed to Rainmeter as executable action text.
return function(path,resources)
    local calls,checks={},0
    local variables={['@']=resources,AccentColor='68,9,115',AccentColor2='181,161,226',TitleTextColor='220,220,220',HeaderTextColor='175,175,175',TextColor='210,211,212',BorderColor='50,50,50',DividerColor='60,60,60'}
    local env=setmetatable({SKIN={}}, {__index=_G})
    function env.SKIN:GetVariable(key) return variables[key] end
    function env.SKIN:Bang(...) calls[#calls+1]={...} end
    local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk(); env.Initialize()
    for _,key in ipairs({'AccentColor','AccentColor2','TitleTextColor','HeaderTextColor','TextColor','BorderColor','DividerColor'}) do
        calls={}; assert(env.OpenTarget(key)==true); assert(env.Apply()==true)
        checks=checks+3
        assert(#calls==3 and calls[1][1]=='!WriteKeyValue' and calls[1][3]==key and calls[1][4]==variables[key])
    end
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
