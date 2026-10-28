-- Runs Launcher.lua against a mock SKIN: key validation, the exact bang
-- sequence and where the picker window goes. No Rainmeter needed.
return function(path,resources)
    local checks=0
    local picker='Parallax\\ColorPicker'
    local function newEnv(opts)
        local calls={}
        local vars={['@']=resources,Scale=opts.scale or '1',Gutter='8'}
        local monitors=opts.monitors or {}
        local skin=opts.skin or {0,0,228,300}
        local env=setmetatable({SKIN={}},{__index=_G})
        function env.SKIN:GetVariable(key,default) return vars[key] or default end
        function env.SKIN:ReplaceVariables(text)
            local field,n=text:match('^#(%u+)@(%d+)#$')
            local m=monitors[tonumber(n)]
            if not field or not m then return text end
            local map={SCREENAREAX=m.x,SCREENAREAY=m.y,SCREENAREAWIDTH=m.w,SCREENAREAHEIGHT=m.h,
                WORKAREAX=m.wx or m.x,WORKAREAY=m.wy or m.y,WORKAREAWIDTH=m.ww or m.w,WORKAREAHEIGHT=m.wh or m.h}
            return tostring(map[field])
        end
        function env.SKIN:GetX() return skin[1] end
        function env.SKIN:GetY() return skin[2] end
        function env.SKIN:GetW() return skin[3] end
        function env.SKIN:GetH() return skin[4] end
        function env.SKIN:GetMeter(name)
            local m=opts.meters and opts.meters[name]
            return m and {GetY=function() return m[1] end,GetH=function() return m[2] end} or nil
        end
        function env.SKIN:Bang(...) calls[#calls+1]={...} end
        local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk(); env.Initialize()
        return env,calls
    end
    local function openAt(opts,key,meter)
        local env,calls=newEnv(opts)
        assert(env.Open(key,meter)==true)
        assert(#calls==3 and calls[1][1]=='!ActivateConfig' and calls[1][2]==picker and calls[1][3]=='ColorPicker.ini')
        assert(calls[2][1]=='!Move' and calls[2][4]==picker and calls[3][1]=='!CommandMeasure' and calls[3][2]=='MeasureColorPicker')
        assert(calls[3][3]=="OpenTarget('"..key.."')" and calls[3][4]==picker)
        checks=checks+8
        return tonumber(calls[2][2]),tonumber(calls[2][3])
    end
    local function expect(label,x,y,ex,ey) assert(x==ex and y==ey,label..': got '..x..','..y..' expected '..ex..','..ey); checks=checks+1 end

    local one={{x=0,y=0,w=1920,h=1080,wh=1040}}
    -- No monitor holds the skin (the isolated test places skins off screen): beside it, unclamped.
    local x,y=openAt({skin={-20000,-20000,1,1}},'RAMColor'); expect('off screen',x,y,-19999,-20000)
    -- 228 px skin on the only monitor: its right edge, top aligned. The picker window is 288 px at scale 1.
    x,y=openAt({skin={100,200,228,300},monitors=one},'AccentColor'); expect('beside',x,y,328,200)
    -- No room on the right: its left edge.
    x,y=openAt({skin={1700,100,220,300},monitors=one},'GridColor'); expect('flipped',x,y,1412,100)
    -- No room on either side: beside it, kept on the monitor.
    x,y=openAt({skin={0,0,300,300},monitors={{x=0,y=0,w=400,h=400}}},'TextColor'); expect('squeezed',x,y,112,0)
    -- Bottom of the work area (1040 of 1080).
    x,y=openAt({skin={100,900,228,300},monitors=one},'TextColor'); expect('bottom',x,y,328,770)
    -- A second monitor: the one holding the skin decides.
    local two={{x=0,y=0,w=1920,h=1080},{x=1920,y=0,w=1920,h=1080}}
    x,y=openAt({skin={3600,50,228,300},monitors=two},'GPUColor'); expect('monitor 2 flip',x,y,3312,50)
    x,y=openAt({skin={1800,50,228,300},monitors=two},'GPUColor'); expect('stay on monitor 1',x,y,1512,50)
    x,y=openAt({skin={2000,50,228,300},monitors=two},'GPUColor'); expect('monitor 2 beside',x,y,2228,50)
    -- Swatch alignment: centered on the swatch, inside the skin's own height.
    local meters={MeterSwatch={520,20},MeterTopSwatch={20,20},MeterNoSuch=nil}
    x,y=openAt({skin={100,100,456,901},monitors=one,meters=meters},'BorderColor','MeterSwatch'); expect('swatch',x,y,556,495)
    x,y=openAt({skin={100,100,456,901},monitors=one,meters=meters},'BorderColor','MeterTopSwatch'); expect('top swatch',x,y,556,100)
    x,y=openAt({skin={100,100,456,901},monitors=one,meters=meters},'BorderColor','MeterNoSuch'); expect('unknown swatch',x,y,556,100)
    x,y=openAt({skin={100,100,456,901},monitors=one,meters=meters},'BorderColor',42); expect('non-string meter',x,y,556,100)
    x,y=openAt({skin={100,100,456,100},monitors=one,meters=meters},'BorderColor','MeterSwatch'); expect('short skin',x,y,556,100)
    x,y=openAt({skin={100,100,228,901},monitors=one,meters={MeterSwatch={880,20}}},'BorderColor','MeterSwatch'); expect('swatch near bottom',x,y,328,731)
    -- The picker window follows the suite scale and gutter (Geometry.inc).
    x,y=openAt({skin={0,0,284,100},monitors={{x=0,y=0,w=500,h=500}},scale='0.75'},'DangerColor'); expect('scale 0.75 fits',x,y,284,0)
    x,y=openAt({skin={0,0,284,100},monitors={{x=0,y=0,w=500,h=500}}},'DangerColor'); expect('scale 1 does not',x,y,212,0)
    -- Every kind of target opens.
    for _,key in ipairs({'AccentColor','MutedColor','TrackColor','CPUColor','NetworkOutColor','ClockColor','RAMHistoryEmptyColor','CPUThreadColor1','CPUThreadColor64'}) do openAt({},key) end

    -- Anything else is refused before any bang, and is never put into an action.
    for _,bad in ipairs({'','NotAColorTarget','accentcolor','AccentColor ','../Settings.inc','AccentColor2\nTextColor=1,2,3',
        "AccentColor'); os.execute('x'); --",'[!WriteKeyValue Variables Unexpected 1]','CPUThreadColor0','CPUThreadColor65','CPUThreadColor01',42,true,{}}) do
        local env,calls=newEnv({})
        assert(env.Open(bad,'MeterSwatch')==false and #calls==0); checks=checks+2
    end
    local env,calls=newEnv({})
    assert(env.Open(nil)==false and #calls==0); checks=checks+2
    return checks
end
