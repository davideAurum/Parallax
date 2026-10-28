-- Calls the production Lua API directly in a mock environment. The payloads
-- below remain data; none is passed to Rainmeter as executable action text.
return function(path,resources)
    local calls,checks={},0
    local files={}
    local variables={['@']=resources,AccentColor='68,9,115',AccentColor2='181,161,226',TitleTextColor='220,220,220',HeaderTextColor='175,175,175',TextColor='210,211,212',BorderColor='50,50,50',DividerColor='60,60,60',TableHeaderBorderColor='70,80,90,0',BorderThickness='3',DividerThickness='1',TableHeaderBorderThickness='2'}
    -- User\<module>.inc reads go to this table first, then the real disk.
    local fakeIo={open=function(file,mode)
        local text=files[file]
        if text==nil then return io.open(file,mode) end
        return {read=function() return text end,close=function() end}
    end}
    local function newEnv(meters)
        local env=setmetatable({SKIN={},io=fakeIo,os=setmetatable({getenv=function(name) if name=='NUMBER_OF_PROCESSORS' then return '8' end return os.getenv(name) end},{__index=os})}, {__index=_G})
        function env.SKIN:GetVariable(key,default) return variables[key] or default end
        function env.SKIN:Bang(...)
            local call={...}; calls[#calls+1]=call
            if call[1]=='!WriteKeyValue' then variables[call[3]]=call[4] end
        end
        if meters then function env.SKIN:GetMeter() return {GetW=function() return 268 end,GetH=function() return 112 end} end end
        local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk(); env.Initialize()
        return env
    end
    local env=newEnv()
    local T=dofile(resources..'Modules\\ColorPicker\\Targets.lua')

    -- Every color in Defaults.inc has a registry entry, and every shared entry names a real default.
    local defaults,inDefaults={},{}
    do
        local handle=assert(io.open(resources..'Defaults.inc','rb')); local text=handle:read('*a'); handle:close()
        for key in text:gmatch('[\r\n](%w*Color%d*)=') do inDefaults[key]=true end
    end
    local shared={}
    for _,group in ipairs(T.Groups) do
        for _,item in ipairs(group.items) do
            if not item.file then shared[#shared+1]=item[1]; defaults[item[1]]=true end
        end
    end
    for key in pairs(inDefaults) do assert(defaults[key],'Defaults.inc color has no picker target: '..key); checks=checks+1 end
    for key in pairs(defaults) do assert(inDefaults[key],'Picker target is not a Defaults.inc color: '..key); checks=checks+1 end
    assert(#shared==25); checks=checks+1

    -- The window size Launcher.lua assumes is the one ColorPicker.ini declares.
    do
        local handle=assert(io.open(resources..'..\\ColorPicker\\ColorPicker.ini','rb')); local ini=handle:read('*a'); handle:close()
        assert(tonumber(ini:match('[\r\n]ColumnWidth=(%d+)'))==T.PickerColumnWidth,'Launcher width differs from ColorPicker.ini')
        assert(tonumber(ini:match('[\r\n]PanelHeight=(%d+)'))==T.PickerPanelHeight,'Launcher height differs from ColorPicker.ini')
        assert(tonumber(ini:match('[\r\n]Columns=(%d+)'))==1)
        checks=checks+3
    end

    for _,key in ipairs({'AccentColor','AccentColor2','TitleTextColor','HeaderTextColor','TextColor','BorderColor','DividerColor','TableHeaderBorderColor'}) do
        local expected=variables[key]:match('^(%d+,%d+,%d+)')
        calls={}; assert(env.OpenTarget(key)==true); assert(env.Apply()==true)
        checks=checks+3
        assert(#calls==3 and calls[1][1]=='!WriteKeyValue' and calls[1][3]==key and calls[1][4]==expected)
        assert(calls[1][5]==resources..'User\\Settings.inc' and calls[2][1]=='!RefreshGroup' and calls[2][2]=='Parallax')
    end
    -- Every shared color applies to Settings.inc and reloads the suite; only alpha-keeping targets keep an alpha byte.
    for _,key in ipairs(shared) do
        variables[key]='10,20,30,128'
        calls={}; assert(env.OpenTarget(key)==true); env.SelectPlane(100,0); env.SelectSlice(50)
        assert(#calls==0); assert(env.Apply()==true and #calls==3)
        local entry=T.Find(key)
        assert(calls[1][3]==key and calls[1][4]==(entry.alpha and '0,255,255,128' or '0,255,255'),'Wrong saved value for '..key)
        assert(calls[1][5]==resources..'User\\Settings.inc' and calls[2][2]=='Parallax' and calls[3][1]=='!DeactivateConfig')
        checks=checks+6
    end
    assert(T.Find('BackgroundColor').alpha and T.Find('GridColor').alpha and T.Find('GraphBackgroundColor').alpha and not T.Find('TrackColor').alpha); checks=checks+1
    -- Editing one line color must preserve the other line colors and thicknesses.
    variables.TableHeaderBorderColor='70,80,90,0'; variables.DividerColor='60,60,60'; variables.BorderColor='50,50,50'
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

    -- Module colors live in their own User file and reload only their module.
    variables.RAMHistoryEmptyColor=nil
    calls={}; assert(env.OpenTarget('RAMHistoryEmptyColor')==true); env.SelectPlane(100,0); env.SelectSlice(50)
    assert(#calls==0 and env.Apply()==true and #calls==3)
    assert(calls[1][3]=='RAMHistoryEmptyColor' and calls[1][4]=='0,255,255' and calls[1][5]==resources..'User\\RAM.inc')
    assert(calls[2][1]=='!RefreshGroup' and calls[2][2]=='ParallaxRAM' and calls[3][1]=='!DeactivateConfig')
    checks=checks+5
    files[resources..'User\\RAM.inc']='[Variables]\nRAMShowBar=1\n; RAMHistoryEmptyColor=1,1,1\nRAMHistoryEmptyColor=30,40,50\nRAMHistoryEmptyColor=60,70,80\r\n[Other]\nRAMHistoryEmptyColor=9,9,9\n'
    calls={}; assert(env.OpenTarget('RAMHistoryEmptyColor')==true); env.SelectPlane(0,100)
    assert(env.Apply()==true and calls[1][4]=='0,0,0'); checks=checks+2
    -- The saved file value seeds the picker (the swatch stays at 60,70,80 until the preview moves).
    calls={}; assert(env.OpenTarget('RAMHistoryEmptyColor')==true and #calls==0)
    local ramMeters=newEnv(true); ramMeters.Render(); assert(ramMeters.OpenTarget('RAMHistoryEmptyColor')==true)
    local seen
    for _,call in ipairs(calls) do if call[1]=='!SetOption' and call[2]=='MeterOriginal' and call[3]=='SolidColor' then seen=call[4] end end
    assert(seen=='60,70,80','Saved module color did not seed the picker: '..tostring(seen)); checks=checks+3
    -- CPU thread colors go to User\CPU.inc, apply to the running CPU meter and reload only the Thread Colors panel.
    files[resources..'User\\CPU.inc']='[Variables]\nCPUCoreLimit=6\nCPUThreadColor3=1,2,3\n'
    calls={}; assert(env.OpenTarget('CPUThreadColor3')==true); env.SelectPlane(100,0); env.SelectSlice(50)
    assert(#calls==0 and env.Apply()==true and #calls==5)
    assert(calls[1][1]=='!WriteKeyValue' and calls[1][3]=='CPUThreadColor3' and calls[1][4]=='0,255,255' and calls[1][5]==resources..'User\\CPU.inc')
    assert(calls[2][1]=='!SetVariableGroup' and calls[2][2]=='CPUThreadColor3' and calls[2][3]=='0,255,255' and calls[2][4]=='ParallaxCPU')
    assert(calls[3][1]=='!UpdateMeasureGroup' and calls[3][2]=='ParallaxCPUApply')
    assert(calls[4][1]=='!RefreshGroup' and calls[4][2]=='ParallaxCPUColors' and calls[5][1]=='!DeactivateConfig')
    checks=checks+8
    -- An unset thread color seeds from the Thread Colors palette.
    files[resources..'User\\CPU.inc']='[Variables]\n'
    local paletteEnv=newEnv(true); paletteEnv.Render(); calls={}
    for index=1,T.MaxThreads do
        calls={}; assert(paletteEnv.OpenTarget('CPUThreadColor'..index)==true)
        local original
        for _,call in ipairs(calls) do if call[1]=='!SetOption' and call[2]=='MeterOriginal' and call[3]=='SolidColor' then original=call[4] end end
        assert(original==T.ThreadPalette[(index-1)%#T.ThreadPalette+1],'Thread '..index..' palette seed'); checks=checks+2
    end

    -- Target registry validation.
    for _,good in ipairs({'CPUThreadColor1','CPUThreadColor9','CPUThreadColor10','CPUThreadColor64'}) do assert(T.Find(good) and T.Find(good).file=='CPU'); checks=checks+1 end
    for _,bad in ipairs({'','NotAColorTarget','accentcolor','../Settings.inc','AccentColor2\nTextColor=1,2,3',"AccentColor'); os.execute('invalid'); --",'[!WriteKeyValue Variables Unexpected 1]','AccentColor2 ',42,true,{},
        'CPUThreadColor0','CPUThreadColor65','CPUThreadColor01','CPUThreadColor1.0','CPUThreadColor-1','CPUThreadColor','CPUThreadColor 1','cputhreadcolor1','CPUThreadColor1\n','RAMHistoryEmptyColor ','CPUThreadColor999999999999'}) do
        assert(T.Find(bad)==nil); calls={}; assert(env.OpenTarget(bad)==false); assert(#calls==0); checks=checks+3
    end
    calls={}; assert(env.OpenTarget(nil)==false); assert(#calls==0); checks=checks+2
    -- Rejection retains the prior valid target rather than authorizing any new key.
    assert(env.OpenTarget('BackgroundColor')==true); calls={}
    assert(env.OpenTarget('NotAColorTarget')==false)
    env.Apply(); assert(calls[1][3]=='BackgroundColor'); checks=checks+3

    -- Dropdown: every target in one scrolling list.
    local menu=T.Menu(6)
    local targets=0
    for _,item in ipairs(menu) do if item.kind=='target' then targets=targets+1; assert(T.Find(item.key)) end end
    assert(targets==26+6 and #menu==targets+5 and menu[1].kind=='group' and menu[#menu-6].label=='CPU threads'); checks=checks+3
    assert(#T.Menu(0)==26+4 and #T.Menu(100)==#T.Menu(64)); checks=checks+2
    local picker=newEnv(true); picker.Render()
    local function find(name,key,from)
        local last
        for index=from or 1,#calls do local call=calls[index]; if call[1]=='!SetOption' and call[2]==name and call[3]==key then last=call[4] end end
        return last
    end
    files[resources..'User\\CPU.inc']='[Variables]\nCPUCoreLimit=6\n'
    variables.AccentColor='68,9,115'
    calls={}; picker.OpenTarget('AccentColor'); picker.ToggleMenu()
    local function has(bang,arg) for _,call in ipairs(calls) do if call[1]==bang and call[2]==arg then return true end end return false end
    assert(has('!HideMeterGroup','PickerBody') and has('!ShowMeterGroup','PickerMenu')); checks=checks+2
    assert(find('MeterMenuRow1','Text')=='Text and accents' and find('MeterMenuRow2','Text')=='Accent Color 1' and find('MeterMenuRow3','Text')=='Accent Color 2'); checks=checks+3
    assert(find('MeterMenuRow2','SolidColor')=='255,255,255,26' and find('MeterMenuRow3','SolidColor')=='0,0,0,1'); checks=checks+2
    assert(find('MeterMenuDot2','Shape'):find('Fill Color 68,9,115',1,true)); checks=checks+1
    assert(picker.MenuPick(1)==false and picker.MenuPick(0)==false and picker.MenuPick(11)==false and picker.MenuPick('x')==false); checks=checks+4
    calls={}; picker.MenuScroll(3)
    assert(find('MeterMenuRow1','Text')=='Title Text Color'); checks=checks+1
    calls={}; picker.MenuScroll(1000); local last=find('MeterMenuRow10','Text')
    assert(last=='CPU Thread 6','Menu did not end on the last thread: '..tostring(last)); checks=checks+1
    calls={}; picker.MenuScroll(-1000); assert(find('MeterMenuRow1','Text')=='Text and accents'); checks=checks+1
    calls={}; picker.MenuScroll(1000); calls={}; assert(picker.MenuPick(10)==true)
    assert(has('!ShowMeterGroup','PickerBody') and has('!HideMeterGroup','PickerMenu')); checks=checks+2
    assert(find('MeterTarget','Text')=='CPU Thread 6'); checks=checks+1
    calls={}; picker.MenuScroll(1); assert(#calls==0); checks=checks+1
    calls={}; assert(picker.Apply()==true and calls[1][3]=='CPUThreadColor6'); checks=checks+1
    -- Opening while the list is open closes it and shows the requested target.
    variables.GridColor='50,50,50,255'
    calls={}; picker.ToggleMenu(); calls={}; assert(picker.OpenTarget('GridColor')==true)
    assert(has('!ShowMeterGroup','PickerBody') and find('MeterTarget','Text')=='Graph Grid' and find('MeterStatus','Text')=='Opacity 100% kept'); checks=checks+3
    calls={}; picker.ToggleMenu(); picker.ToggleMenu(); assert(has('!ShowMeterGroup','PickerBody')); checks=checks+1
    return checks
end
