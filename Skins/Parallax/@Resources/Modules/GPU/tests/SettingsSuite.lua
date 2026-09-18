-- Original Parallax GPU settings tests. Runs against mocked Rainmeter and files.
-- No provider, subprocess, live skin, or persistent user preference is touched.
local Suite = {}
function Suite.run(path)
    local total, failed, lines = 0, 0, {}
    local root = 'C:\\ParallaxTests\\@Resources\\'
    local filePath = root .. 'User\\GPU.inc'
    local function eq(a,b,label)
        total=total+1
        if a~=b then error((label or 'value')..': expected '..tostring(b)..', got '..tostring(a),2) end
    end
    local function ok(a,label) eq(not not a,true,label) end
    local function test(name,body)
        local pass,err=pcall(body)
        lines[#lines+1]=(pass and 'PASS: ' or 'FAIL: ')..name..(pass and '' or ': '..tostring(err))
        if not pass then failed=failed+1 end
    end
    local allowed={Columns=true,PanelHeight=true,GPUEnableSensors=true,GPURegHKey=true,GPUPowerSource=true,GPUClockSource=true}
    for _,field in ipairs({'Temperature','Power','Clock'}) do
        for _,part in ipairs({'Index','Sensor','Label'}) do allowed['GPU'..field..part]=true end
    end
    local function fixture(overrides)
        local persisted={Columns='1',PanelHeight='650',GPUEnableSensors='0',GPURegHKey='HKEY_CURRENT_USER',GPURegKey='SOFTWARE\\HWiNFO64\\VSB'}
        for _,field in ipairs({'Temperature','Power','Clock'}) do
            persisted['GPU'..field..'Index']='-1';persisted['GPU'..field..'Sensor']='';persisted['GPU'..field..'Label']=''
        end
        for k,v in pairs(overrides or {}) do persisted[k]=v end
        local vars={['@']=root,CURRENTCONFIG='Parallax\\GPU\\Settings'}
        for k,v in pairs(persisted) do vars[k]=v end
        vars.Columns='2';vars.PanelHeight='648'
        local f={persisted=persisted,vars=vars,options={},writes={},refreshes={},launches={},closes=0,output='',status=1,calls={},inputOutput='',inputStatus=-1,inputKills=0}
        local function textFile()
            local t={'[Variables]'};for k,v in pairs(persisted) do t[#t+1]=k..'='..v end;return table.concat(t,'\n')
        end
        local skin={}
        function skin:GetVariable(k,default) return vars[k] or default end
        function skin:GetMeasure(name)
            if name=='MeasureGPUSettingsInput' then
                return {GetStringValue=function() return f.inputOutput end,GetValue=function() return f.inputStatus end}
            end
            assert(name=='MeasureGPUDiscover','unexpected measure')
            return {GetStringValue=function() return f.output end,GetValue=function() return f.status end}
        end
        function skin:GetX() return 100 end
        function skin:GetY() return 200 end
        function skin:GetMeter(name)
            assert(name=='MeterSettingsColumnsFrame','unexpected input target')
            return {GetX=function() return 160 end,GetY=function() return 100 end,
                GetW=function() return 56 end,GetH=function() return 20 end}
        end
        function skin:Bang(command,...)
            local a={...};f.calls[#f.calls+1]={command=command,args=a}
            if command=='!SetOption' then
                assert(#a==3 and (a[2]=='Text' or a[2]=='ToolTipText' or a[2]=='Hidden' or a[2]=='FontColor' or a[2]=='MouseActionCursor' or (a[1]=='MeasureGPUSettingsInput' and a[2]=='Parameter')),'unsafe option write')
                if a[1]=='MeterSettingsDisplaySection' or a[1]=='MeterSettingsSensorsSection' or a[1]=='MeterSettingsPickerTitle' then
                    assert(a[2]~='FontColor','section color must inherit Accent 1, including dynamic picker states')
                end
                f.options[a[1]]=f.options[a[1]] or {};f.options[a[1]][a[2]]=a[3]
            elseif command=='!SetVariable' then
                assert(#a==2 and allowed[a[1]],'arbitrary variable mutation');vars[a[1]]=a[2]
            elseif command=='!WriteKeyValue' then
                assert(#a==4 and a[1]=='Variables' and allowed[a[2]] and a[4]==filePath,'write outside GPU allowlist')
                assert(type(a[3])=='string','write must pass scalar string')
                f.writes[#f.writes+1]={key=a[2],value=a[3]};persisted[a[2]]=a[3]
            elseif command=='!RefreshGroup' then
                assert(#a==1 and a[1]=='ParallaxGPU','refresh outside GPU group');f.refreshes[#f.refreshes+1]=a[1]
            elseif command=='!CommandMeasure' then
                assert(#a==2 and ((a[1]=='MeasureGPUDiscover' and a[2]=='Run') or (a[1]=='MeasureGPUSettingsInput' and (a[2]=='Run' or a[2]=='Kill'))),'unexpected process launch')
                if a[2]=='Run' then
                    f.launches[#f.launches+1]=a[1]
                    if a[1]=='MeasureGPUSettingsInput' then f.inputStatus=0 end
                else
                    assert(f.inputStatus==0,'only running owned input can be killed')
                    local previous=f.calls[#f.calls-1]
                    assert(previous and previous.command=='!UpdateMeasure' and previous.args[1]=='MeasureGPUSettingsInput','fresh status before Kill')
                    f.inputKills=f.inputKills+1
                end
            elseif command=='!DeactivateConfig' then assert(#a==0 or (#a==1 and a[1]=='Parallax\\GPU\\Settings'),'close must target itself');f.closes=f.closes+1
            elseif command=='!ShowMeter' or command=='!HideMeter' then assert(#a==1,'meter target outside settings')
            elseif command=='!UpdateMeterGroup' then assert(#a==1 and (a[1]=='GPUSettingsUI' or a[1]=='GPUSettingsPicker'),'wrong meter group')
            elseif command=='!UpdateMeasure' then assert(#a==1 and (a[1]=='MeasureGPUDiscover' or a[1]=='MeasureGPUSettingsInput'),'unexpected measure update')
            elseif command=='!Redraw' then assert(#a==0,'redraw outside settings')
            else error('unexpected bang: '..command) end
        end
        local fakeio={open=function(pathname,mode)
            assert(pathname==filePath and (mode==nil or mode=='r' or mode=='rb'),'unexpected file operation')
            local data=textFile();local fhandle={close=function() return true end}
            function fhandle:read(format) assert(format=='*a' or format=='*all' or format==65537,'unexpected read');return data end
            function fhandle:lines() local iterator=data:gmatch('[^\r\n]+');return function() return iterator() end end
            return fhandle
        end}
        local function forbidden() error('unexpected external work') end
        local blocked=setmetatable({},{__index=function()return forbidden end})
        local env=setmetatable({SKIN=skin,SELF={},io=fakeio,os=blocked,package=blocked,debug=blocked,require=forbidden,dofile=forbidden,loadfile=forbidden,loadstring=forbidden},{__index=_G})
        env._G=env;local chunk=assert(loadfile(path));setfenv(chunk,env);chunk();f.env=env
        function f:clear() self.writes={};self.refreshes={};self.launches={};self.calls={} end
        function f:textContains(fragment)
            for _,opts in pairs(self.options) do for _,v in pairs(opts) do if tostring(v):find(fragment,1,true) then return true end end end
            return false
        end
        env.Initialize();env.Update();return f
    end
    local function idle(f) eq(#f.writes,0,'write count');eq(#f.refreshes,0,'refresh count') end
    local function saved(f,expect)
        local n=0;for _ in pairs(expect) do n=n+1 end;eq(#f.writes,n,'write count')
        for _,w in ipairs(f.writes) do eq(w.value,expect[w.key],w.key);eq(f.persisted[w.key],expect[w.key],'persisted '..w.key) end
        eq(#f.refreshes,1,'refresh count')
        local lastWrite,refresh=0,0;for i,c in ipairs(f.calls) do if c.command=='!WriteKeyValue' then lastWrite=i elseif c.command=='!RefreshGroup' then refresh=i end end
        ok(refresh>lastWrite,'refresh follows complete save')
    end
    local function hex(value) return (value:gsub('.',function(c)return string.format('%02X',string.byte(c))end)) end
    local function export(f,items,status,hive,key)
        local out={'GPU_EXPORTS|1|'..(status or 'OK')..'|'..hex(hive or f.persisted.GPURegHKey)..'|'..hex(key or f.persisted.GPURegKey)..'|0|0'}
        for _,item in ipairs(items or {}) do out[#out+1]='ITEM|'..item[1]..'|'..hex(item[2])..'|'..hex(item[3])..'|'..hex(item[4] or '55 C')..'|'..hex(item[5] or '55') end
        f.output=table.concat(out,'\n');f.env.FinishDiscovery()
    end
    test('opening and updates preserve preferences without writes or launches',function()
        local f=fixture({Columns='1',PanelHeight='399',GPUClockSensor='Custom sensor'});idle(f);eq(#f.launches,0)
        for _=1,4 do f.env.Update() end;idle(f);eq(#f.launches,0);eq(f.persisted.PanelHeight,'399')
    end)
    test('driver temperature ignores and preserves legacy mappings with HWiNFO off',function()
        local f=fixture({GPUTemperatureIndex='7',GPUTemperatureSensor='Legacy sensor',GPUTemperatureLabel='Legacy hotspot'})
        eq(f.options.MeterSettingsTemperatureValue.Text,'Driver')
        ok(f.options.MeterSettingsTemperatureValue.ToolTipText:find('NVIDIA driver',1,true),'driver source tooltip')
        ok(f.options.MeterSettingsTemperatureValue.ToolTipText:find('Hotspot is a separate reading',1,true),'hotspot distinction')
        eq(f.options.MeterSettingsSensorsValue.Text,'Off')
        eq(f.env.Browse('Temperature'),false,'temperature cannot launch picker')
        eq(f.env.Clear('Temperature'),false,'temperature cannot clear legacy mapping')
        f.env.Update();idle(f);eq(#f.launches,0)
        eq(f.persisted.GPUTemperatureIndex,'7');eq(f.persisted.GPUTemperatureSensor,'Legacy sensor');eq(f.persisted.GPUTemperatureLabel,'Legacy hotspot')
        f.env.RefreshGPU();eq(#f.writes,0);eq(#f.launches,0);eq(#f.refreshes,1)
        eq(f.persisted.GPUTemperatureIndex,'7');eq(f.persisted.GPUTemperatureLabel,'Legacy hotspot')
    end)
    test('monitor columns stay independent of fixed settings geometry and reopen',function()
        local f=fixture();f.env.CycleColumns();saved(f,{Columns='2'});eq(f.vars.Columns,'2')
        f:clear();f.env.CycleColumns();saved(f,{Columns='1'});eq(f.vars.Columns,'2','settings Columns remain two')
        local again=fixture(f.persisted);idle(again);again.env.CycleColumns();saved(again,{Columns='2'})
    end)
    test('sensor toggle and fit-height change only explicit keys',function()
        local f=fixture({PanelHeight='399'});f.env.ToggleSensors();saved(f,{GPUEnableSensors='1'});eq(f.persisted.PanelHeight,'399')
        f:clear();f.env.ToggleSensors();saved(f,{GPUEnableSensors='0'});f:clear();f.env.FitHeight();saved(f,{PanelHeight='650'});eq(f.vars.PanelHeight,'648')
        f:clear();f.env.FitHeight();idle(f)
    end)
    test('provider off keeps setup and recovery available and saved mappings intact',function()
        local f=fixture({GPUEnableSensors='1',GPUPowerIndex='8',GPUPowerSensor='Saved GPU',GPUPowerLabel='Saved power'})
        f.env.ToggleSensors();saved(f,{GPUEnableSensors='0'})
        eq(f.options.MeterSettingsPowerValue.Text,'Saved power','disabled provider retains mapping display')
        eq(f.persisted.GPUPowerIndex,'8');eq(f.persisted.GPUPowerSensor,'Saved GPU');eq(f.persisted.GPUPowerLabel,'Saved power')
        for _,call in ipairs(f.calls) do
            ok(call.command~='!HideMeter','provider disable is not feature visibility')
            ok(not (call.command=='!SetOption' and call.args[2]=='Hidden' and call.args[3]=='1'),'setup is not hidden')
        end
        f:clear();ok(f.env.Browse('Power'),'picker remains usable with provider off');eq(#f.launches,1)
        export(f,{},'MISSING');f:clear();ok(f.env.Rescan(),'recovery rescan remains usable');eq(#f.launches,1)
        eq(f.persisted.GPUEnableSensors,'0');eq(f.persisted.GPUPowerLabel,'Saved power')
        local again=fixture(f.persisted);idle(again);eq(again.options.MeterSettingsPowerValue.Text,'Saved power')
    end)
    test('column arrows clamp without writes at limits and reject invalid directions',function()
        local f=fixture({Columns='1',PanelHeight='699'})
        eq(f.env.StepColumns(-1),false);idle(f);eq(#f.launches,0)
        ok(f.env.StepColumns(1));saved(f,{Columns='2'});eq(f.vars.Columns,'2');eq(f.persisted.PanelHeight,'699')
        f:clear();eq(f.env.StepColumns(1),false);idle(f)
        ok(f.env.StepColumns(-1));saved(f,{Columns='1'});eq(f.vars.Columns,'2')
        f:clear();for _,direction in ipairs({0,2,-2,'1','-1',false,{},math.huge}) do eq(f.env.StepColumns(direction),false) end
        eq(f.env.StepColumns(nil),false);idle(f);eq(#f.launches,0)
        local custom=fixture({Columns='legacy expression'});eq(custom.env.StepColumns(1),false);idle(custom)
        eq(custom.persisted.Columns,'legacy expression')
    end)
    test('typed columns use the fixed shared helper and apply one exact preference',function()
        local f=fixture({Columns='1',PanelHeight='699',GPUPowerSource='1'})
        ok(f.env.BeginColumnsEdit());idle(f);eq(#f.launches,1);eq(f.launches[1],'MeasureGPUSettingsInput')
        local parameter=f.options.MeasureGPUSettingsInput.Parameter
        ok(parameter:find("ReadAllText('SettingsInput.ps1')",1,true),'fixed shared helper')
        ok(parameter:find('-Key UtilityNumber -Minimum 1 -Maximum 2 -DecimalPlaces 0 -Initial 1',1,true),'bounded integer contract')
        ok(parameter:find('-X 260 -Y 300 -Width 56 -Height 20 -Scale 1.0000',1,true),'physical frame bounds')
        ok(not parameter:find('GPU.inc',1,true),'no destination path');ok(not parameter:find('-Key Columns',1,true),'no module key')
        eq(f.env.BeginColumnsEdit(),false);eq(f.env.StepColumns(1),false);eq(f.env.CycleColumns(),false)
        f:clear();f.inputStatus=1;f.inputOutput='PARALLAX_INPUT_V1|ok|2\r\n';ok(f.env.CommitColumnsInput());saved(f,{Columns='2'})
        eq(f.persisted.PanelHeight,'699');eq(f.persisted.GPUPowerSource,'1');eq(#f.launches,0)
        f:clear();eq(f.env.CommitColumnsInput(),false);idle(f)
        local again=fixture(f.persisted);eq(again.options.MeterSettingsColumnsValue.Text,'2');idle(again)
    end)
    test('typed column cancellation failure malformed values and stale results never save',function()
        for _,output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|0','PARALLAX_INPUT_V1|ok|3','PARALLAX_INPUT_V1|ok|1.0',
            'PARALLAX_INPUT_V1|ok|01','PARALLAX_INPUT_V1|ok|+1','PARALLAX_INPUT_V1|ok|1e0','PARALLAX_INPUT_V1|ok|2 columns',
            'PARALLAX_INPUT_V1|ok|[!Quit]','PARALLAX_INPUT_V2|ok|2','PARALLAX_INPUT_V1|ok|2\nextra','',string.rep('x',129)}) do
            local f=fixture();ok(f.env.BeginColumnsEdit());f:clear();f.inputStatus=1;f.inputOutput=output;eq(f.env.CommitColumnsInput(),false);idle(f)
        end
        local failed=fixture();ok(failed.env.BeginColumnsEdit());failed:clear();failed.inputStatus=1;failed.inputOutput='PARALLAX_INPUT_V1|ok|2';failed.inputStatus=103
        eq(failed.env.CommitColumnsInput(),false);idle(failed)
        local stale=fixture();ok(stale.env.BeginColumnsEdit());stale:clear();stale.persisted.Columns='2';stale.inputStatus=1;stale.inputOutput='PARALLAX_INPUT_V1|ok|1'
        eq(stale.env.CommitColumnsInput(),false);idle(stale);eq(stale.persisted.Columns,'2')
        local closed=fixture();ok(closed.env.BeginColumnsEdit());closed:clear();closed.env.Close();eq(closed.inputKills,1);eq(closed.closes,1)
        closed.inputStatus=1;closed.inputOutput='PARALLAX_INPUT_V1|ok|2';eq(closed.env.CommitColumnsInput(),false);idle(closed)
    end)
    test('input lifecycle uses native initial and running statuses and only owned cancellation',function()
        local f=fixture();eq(f.inputStatus,-1);ok(f.env.BeginColumnsEdit());eq(f.inputStatus,0)
        f.env.CancelInput();eq(f.inputKills,1);eq(f.env.CancelInput(),false);eq(f.inputKills,1)
        local busy=fixture();busy.inputStatus=0;eq(busy.env.BeginColumnsEdit(),false)
        eq(busy.env.CancelInput(),false);eq(busy.inputKills,0);idle(busy)
        for _,status in ipairs({-1,1,101,102,103}) do
            local done=fixture();ok(done.env.BeginColumnsEdit());done.inputStatus=status
            ok(done.env.CancelInput());eq(done.inputKills,0);idle(done)
        end
    end)
    test('typed columns preserve custom values until explicit valid submission and no-op equality',function()
        local f=fixture({Columns='legacy expression'});ok(f.env.BeginColumnsEdit());idle(f);eq(f.persisted.Columns,'legacy expression')
        ok(f.options.MeasureGPUSettingsInput.Parameter:find('-Initial 1',1,true));f:clear();f.inputStatus=1;f.inputOutput='PARALLAX_INPUT_V1|ok|2'
        ok(f.env.CommitColumnsInput());saved(f,{Columns='2'})
        f:clear();ok(f.env.BeginColumnsEdit());f:clear();f.inputStatus=1;f.inputOutput='PARALLAX_INPUT_V1|ok|2';ok(f.env.CommitColumnsInput());idle(f)
    end)
    test('categorical previous and next wrap without starting input or discovery',function()
        for _,direction in ipairs({-1,1}) do
            local f=fixture({GPUPowerSource='0',GPUClockSource='1'})
            ok(f.env.CycleSource('Power',direction));saved(f,{GPUPowerSource='1'});eq(#f.launches,0)
            f:clear();ok(f.env.CycleSource('Power',direction));saved(f,{GPUPowerSource='0'})
            f:clear();ok(f.env.CycleSource('Clock',direction));saved(f,{GPUClockSource='0'})
            f:clear();ok(f.env.CycleSource('Clock',direction));saved(f,{GPUClockSource='1'})
            f:clear();ok(f.env.CycleHive(direction));saved(f,{GPURegHKey='HKEY_LOCAL_MACHINE'})
            f:clear();ok(f.env.CycleHive(direction));saved(f,{GPURegHKey='HKEY_CURRENT_USER'});eq(#f.launches,0)
        end
        local f=fixture();for _,direction in ipairs({0,2,-2,'1','-1',false,{},math.huge}) do
            eq(f.env.CycleSource('Power',direction),false);eq(f.env.CycleHive(direction),false)
        end;idle(f);eq(#f.launches,0)
    end)
    test('missing source preferences default to Driver without rewriting legacy mappings',function()
        local f=fixture({GPUEnableSensors='1',GPUPowerIndex='8',GPUPowerSensor='Saved GPU',GPUPowerLabel='Saved power'})
        eq(f.options.MeterSettingsPowerSourceValue.Text,'Driver');eq(f.options.MeterSettingsClockSourceValue.Text,'Driver')
        eq(f.persisted.GPUPowerSource,nil);eq(f.persisted.GPUClockSource,nil)
        eq(f.persisted.GPUPowerIndex,'8');eq(f.options.MeterSettingsPowerValue.Text,'Saved power')
        idle(f);eq(#f.launches,0)
    end)
    test('source changes save only the selected preference and preserve mapping and provider choices',function()
        local f=fixture({GPUPowerSource='0',GPUClockSource='1',GPUEnableSensors='0',PanelHeight='699',GPUPowerIndex='8',GPUPowerSensor='Saved GPU',GPUPowerLabel='Saved power'})
        ok(f.env.CycleSource('Power'));saved(f,{GPUPowerSource='1'});eq(#f.launches,0)
        eq(f.options.MeterSettingsPowerSourceValue.Text,'HWiNFO');eq(f.persisted.GPUClockSource,'1')
        eq(f.persisted.GPUEnableSensors,'0');eq(f.persisted.GPUPowerIndex,'8');eq(f.persisted.PanelHeight,'699')
        eq(f.vars.PanelHeight,'648','settings geometry is independent')
        f:clear();ok(f.env.CycleSource('Clock'));saved(f,{GPUClockSource='0'});eq(#f.launches,0)
        eq(f.persisted.GPUPowerSource,'1');eq(f.options.MeterSettingsClockSourceValue.Text,'Driver')
        local again=fixture(f.persisted);idle(again);eq(again.options.MeterSettingsPowerSourceValue.Text,'HWiNFO')
        eq(again.options.MeterSettingsClockSourceValue.Text,'Driver')
        again.env.CycleSource('Power');saved(again,{GPUPowerSource='0'});eq(#again.launches,0)
        eq(again.persisted.GPUPowerSensor,'Saved GPU');eq(again.persisted.GPUPowerLabel,'Saved power')
    end)
    test('custom source values are explicit and reset to Driver only on an allowed action',function()
        local f=fixture({GPUPowerSource='99',GPUClockSource='unexpected'})
        eq(f.options.MeterSettingsPowerSourceValue.Text,'Custom');eq(f.options.MeterSettingsClockSourceValue.Text,'Custom')
        idle(f);ok(f.env.CycleSource('Power'));saved(f,{GPUPowerSource='0'})
        eq(f.persisted.GPUClockSource,'unexpected');eq(#f.launches,0)
    end)
    test('hive cycles preserve custom registry path and return to current user',function()
        local f=fixture({GPURegKey='SOFTWARE\\Custom Sensor Path'});f.env.CycleHive();saved(f,{GPURegHKey='HKEY_LOCAL_MACHINE'});eq(f.persisted.GPURegKey,'SOFTWARE\\Custom Sensor Path')
        f:clear();f.env.CycleHive();saved(f,{GPURegHKey='HKEY_CURRENT_USER'})
    end)
    test('browse then select persists exact ordinal identity with one refresh',function()
        local f=fixture({GPUPowerSource='0',GPUClockSource='1'});f.env.Browse('Power');idle(f);eq(#f.launches,1)
        export(f,{{7,'GPU [#0]: Test adapter','GPU Power','55 W'}});f:clear();f.env.Select(1)
        saved(f,{GPUPowerIndex='7',GPUPowerSensor='GPU [#0]: Test adapter',GPUPowerLabel='GPU Power'})
        eq(f.persisted.GPUEnableSensors,'0','mapping does not enable provider')
        eq(f.persisted.GPUPowerSource,'0','mapping does not select override source');eq(f.persisted.GPUClockSource,'1')
        local again=fixture(f.persisted);idle(again);ok(again:textContains('GPU Power'),'mapping visible after reopen')
    end)
    test('clear removes the complete mapping without touching another field',function()
        local f=fixture({GPUPowerIndex='8',GPUPowerSensor='GPU [#0]: Test adapter',GPUPowerLabel='GPU Power',GPUClockIndex='4',GPUClockSensor='Preserved',GPUClockLabel='Clock'})
        f.env.Clear('Power');saved(f,{GPUPowerIndex='-1',GPUPowerSensor='',GPUPowerLabel=''});eq(f.persisted.GPUClockIndex,'4')
        f:clear();f.env.Clear('Power');idle(f)
    end)
    test('invalid fields and slots cannot become arbitrary writers',function()
        local f=fixture();for _,value in ipairs({'', 'temperature','Scale','GPURegKey','Temperature][!Quit]',{},false,0,math.huge}) do f.env.Browse(value);f.env.Clear(value);f.env.Select(value);eq(f.env.CycleSource(value),false) end
        f.env.Browse(nil);f.env.Clear(nil);f.env.Select(nil);eq(f.env.CycleSource(nil),false);eq(f.env.CycleSource('Temperature'),false);idle(f);eq(#f.launches,0)
        f.env.Browse('Clock');export(f,{{1,'GPU','Clock'}});f:clear()
        for _,slot in ipairs({-1,0,6,1.5,{},false,math.huge}) do f.env.Select(slot) end;idle(f)
    end)
    test('discovery pagination selects the correct row and bounds page changes',function()
        local f=fixture();f.env.Browse('Power');local rows={};for i=1,7 do rows[#rows+1]={i,'GPU [#0]: Test adapter','Power '..i,'50 W','50'} end;export(f,rows)
        f:clear();f.env.PrevPage();f.env.NextPage();f.env.NextPage();idle(f);f.env.Select(2)
        saved(f,{GPUPowerIndex='7',GPUPowerSensor='GPU [#0]: Test adapter',GPUPowerLabel='Power 7'})
    end)
    test('source change invalidates pending discovery and previous results',function()
        local f=fixture();f.env.Browse('Clock');local old=f.persisted.GPURegHKey;f.env.CycleHive();f:clear();export(f,{{1,'GPU','Clock'}},'OK',old);f.env.Select(1);idle(f)
    end)
    test('unavailable empty and unsupported discovery states cannot select',function()
        for _,status in ipairs({'EMPTY','MISSING','UNAVAILABLE','INVALID_CONFIG','TOO_MANY'}) do
            local f=fixture();f.env.Browse('Power');export(f,{},status);f:clear();f.env.Select(1);idle(f)
        end
    end)
    test('malformed and action-shaped identities cannot become mappings',function()
        local unsafe={'GPU #Scale#','GPU [Measure]','GPU [#x]','GPU [#0][!Quit]','GPU "Quoted"','GPU\nInjected','GPU\tInjected'}
        for _,identity in ipairs(unsafe) do local f=fixture();f.env.Browse('Clock');export(f,{{1,identity,'Clock'}});f:clear();f.env.Select(1);idle(f) end
        for _,payload in ipairs({'','garbage','GPU_EXPORTS|2|OK|00|00|0|0','GPU_EXPORTS|1|OK|0X|FF|0|0','ITEM|1|00|00|00|00'}) do
            local f=fixture();f.env.Browse('Clock');f.output=payload;f.env.FinishDiscovery();f:clear();f.env.Select(1);idle(f)
        end
    end)
    test('close and explicit refresh only target their intended configurations',function()
        local f=fixture();f.env.Close();idle(f);eq(f.closes,1);f.env.RefreshGPU();eq(#f.writes,0);eq(#f.refreshes,1)
    end)
    lines[#lines+1]=string.format('SUMMARY: %d assertions, %d failed',total,failed)
    local report=table.concat(lines,'\n');if failed>0 then error(report,0) end;return total,report
end
return Suite
