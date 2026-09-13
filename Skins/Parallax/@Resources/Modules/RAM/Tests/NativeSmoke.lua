-- Test-only: runs in a copied RAM skin owned by the isolated smoke instance.
-- API reference: https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html
local ticks, completed, checks = 0, false, 0

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function number(expression)
    return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(expression) .. ')')
end

local function meter(name)
    local value = SKIN:GetMeter(name)
    check(value ~= nil, 'Missing native meter: ' .. name)
    return value
end

local function equalOption(item, key, expected)
    check(item:GetOption(key) == expected, item:GetName() .. ' incorrect ' .. key)
end

local infoModel, processModel, pageModel
local function checkPageController()
    -- Execute the production controller in a Lua 5.1 sandbox. All provider
    -- commands and session IO remain in memory; this never starts a helper.
    local now, opens, launches, kills = 2000000000, 0, {}, {}
    local rejectLease, ratioValue = false, 0
    local token = '0123456789abcdef0123456789abcdef'
    local root = 'C:\\RAMFixtureTemp'
    local path = root..'\\Parallax-RAM-Page-'..token..'.dat'
    local lease, temporary = path:sub(1,-5)..'.lease', path:sub(1,-5)..'.tmp'
    local files, removed, options, actions = {}, {}, {}, {}
    local variables = {['@']='fixture-resource\\', MetricsInterval='1000', RAMUseMiB='0', RAMDecimals='2', RAMShowBar='1', RAMShowPageBar='1'}
    local providers = {}
    for _, name in ipairs({'MeasureRAMPageBootstrap','MeasureRAMPageHost'}) do
        providers[name] = {value=-1, text=''}
        providers[name].GetValue = function(self) return self.value end
        providers[name].GetStringValue = function(self) return self.text end
    end
    local fakeSkin = {}
    function fakeSkin:GetVariable(name) return variables[name] end
    function fakeSkin:GetMeasure(name) return assert(providers[name], 'Controller touched an unrelated measure') end
    function fakeSkin:Bang(command, name, key, value)
        actions[#actions+1] = {command,name,key,value}
        if command == '!CommandMeasure' then
            check(providers[name] ~= nil, 'PAGE controller dispatched to an unrelated provider')
            -- RunCommand starts at -1; an unupdated native cache can be 0.
            -- A tracked running launch reports 0.
            if key == 'Run' then launches[name]=(launches[name] or 0)+1; providers[name].value=0
            elseif key == 'Kill' then kills[name]=(kills[name] or 0)+1; providers[name].value=0
            else error('Unexpected PAGE provider command: '..tostring(key)) end
        elseif command == '!SetOption' then
            options[name] = options[name] or {}; options[name][key] = value
        elseif command == '!UpdateMeter' then
            check(name == 'MeterRAMPageLabel' or name == 'MeterRAMPageGiB' or name == 'MeterRAMPageMiB' or name == 'MeterRAMPageBar',
                'PAGE updates must not force physical history or other meters')
        elseif command == '!UpdateMeasure' then
            if name == 'MeasureRAMPageRatio' then
                ratioValue = assert(tonumber(options[name].Formula))
                check(ratioValue >= 0 and ratioValue <= 1, 'PAGE ratio must retain its native 0..1 range')
            else
                check(providers[name] ~= nil, 'PAGE update touched an unrelated measure')
                local provider = providers[name]
                provider.updates = (provider.updates or 0)+1
                if provider.refreshValue ~= nil then
                    provider.value, provider.refreshValue = provider.refreshValue, nil
                end
            end
        else check(command == '!Redraw', 'Unexpected PAGE controller action') end
    end
    local env = setmetatable({SKIN=fakeSkin}, {__index=_G})
    env.dofile = function(value)
        check(value == variables['@']..'Modules\\RAM\\PageFileModel.lua', 'Controller loaded an unexpected script')
        return pageModel
    end
    env.io = {open=function(filePath,mode)
        opens=opens+1
        check(filePath == path or filePath == lease, 'Controller IO escaped its validated session')
        if mode == 'rb' then
            if not files[filePath] then return nil end
            return {read=function(_,count) check(count == 513,'PAGE file read must be bounded'); return files[filePath]:sub(1,count) end,
                close=function() return true end}
        end
        check(mode == 'wb' and filePath == lease, 'Controller may only write its own lease')
        if rejectLease then return nil end
        return {write=function(_,value) files[filePath]=value; return true end,close=function() return true end}
    end}
    env.os = {time=function() return now end, getenv=function(key)
        check(key == 'TMP' or key == 'TEMP', 'Controller requested unrelated environment data'); return root
    end, remove=function(filePath)
        check(filePath == path or filePath == lease or filePath == temporary, 'Controller cleanup escaped its own session')
        removed[filePath]=(removed[filePath] or 0)+1; files[filePath]=nil; return true
    end}
    local chunk = assert(loadfile(SKIN:GetVariable('@')..'Modules\\RAM\\PageFile.lua'))
    setfenv(chunk,env)
    local function reset()
        now, opens, launches, kills = 2000000000, 0, {}, {}
        files, removed, options, actions = {}, {}, {}, {}
        rejectLease, ratioValue = false, 0
        variables.RAMUseMiB, variables.RAMDecimals = '0','2'
        variables.RAMShowBar, variables.RAMShowPageBar = '1','1'
        for _, provider in pairs(providers) do
            provider.value, provider.text, provider.updates, provider.refreshValue = -1,'',0,nil
        end
        chunk(); env.Initialize()
    end
    local function startHost()
        env.Start()
        providers.MeasureRAMPageBootstrap.value = 1
        providers.MeasureRAMPageBootstrap.text = 'RAM_PAGE_SESSION|1|'..token..'|'..path:gsub('.',function(c) return string.format('%02X',c:byte()) end)
        env.Update()
        check(launches.MeasureRAMPageHost == 1 and providers.MeasureRAMPageHost.value == 0,
            'Completed bootstrap must launch one host with RunCommand running value zero')
    end
    reset()
    check(#actions == 0 and opens == 0, 'PAGE initialization must not launch or read a provider')
    env.Display()
    check(options.MeterRAMPageGiB.Text == 'Checking...' and opens == 0, 'PAGE must start with an honest cached checking state')
    env.Start(); env.Start()
    check(launches.MeasureRAMPageBootstrap == 1 and not launches.MeasureRAMPageHost, 'PAGE Start must launch bootstrap only once')
    providers.MeasureRAMPageBootstrap.value = 1
    providers.MeasureRAMPageBootstrap.text = 'RAM_PAGE_SESSION|1|'..token..'|'..path:gsub('.',function(c) return string.format('%02X',c:byte()) end)
    env.Update()
    check(launches.MeasureRAMPageHost == 1 and files[lease] == token..'|'..now, 'PAGE must start one resident host with its own lease')
    files[path] = 'RAM_PAGE|1|'..token..'|1|'..now..'|OK|3000000000|12000000000|2'
    env.Update()
    check(options.MeterRAMPageGiB.Text == '3.00/12.00 GB' and options.MeterRAMPageMiB.Text == '3000.00/12000.00 MB', 'Controller lost actual paging-file byte formatting')
    check(ratioValue == 0.25 and options.MeterRAMPageBar.Hidden == '0', 'PAGE bar must use its own paging-file used/allocated ratio')
    local beforeReads, beforeActions = opens, #actions
    variables.RAMUseMiB, variables.RAMDecimals = '1','0'
    env.Display()
    check(opens == beforeReads and launches.MeasureRAMPageHost == 1 and launches.MeasureRAMPageBootstrap == 1,
        'Cached PAGE setting changes must not read files or relaunch helpers')
    check(options.MeterRAMPageMiB.Text == '3000/12000 MB' and options.MeterRAMPageMiB.Hidden == '0'
        and options.MeterRAMPageGiB.Hidden == '1', 'Cached PAGE units/precision did not apply immediately')
    check(#actions > beforeActions, 'PAGE cached format did not update its meters')
    variables.RAMShowBar='0'; env.Display()
    check(options.MeterRAMPageBar.Hidden == '0', 'Hiding physical RAM bar must not hide PAGE bar')
    variables.RAMShowPageBar='0'; env.Display()
    check(options.MeterRAMPageBar.Hidden == '1' and ratioValue == 0.25, 'Hiding PAGE bar must preserve its cached ratio')
    variables.RAMShowPageBar='1'; env.Display()
    check(options.MeterRAMPageBar.Hidden == '0' and opens == beforeReads, 'PAGE bar toggle must use cached data without IO')
    now = now+9
    beforeReads=opens; env.Display()
    check(opens == beforeReads and options.MeterRAMPageMiB.Text == 'Unavailable', 'Cached PAGE must expire without polling on Display')
    check(ratioValue == 0 and options.MeterRAMPageBar.Hidden == '1', 'Stale PAGE data must clear and hide its bar')
    files[path] = 'RAM_PAGE|1|'..token..'|2|'..now..'|OK|0|4000000000|1'
    env.Update()
    check(options.MeterRAMPageMiB.Text == '0/4000 MB', 'Fresh zero paging-file usage must recover from stale data')
    check(ratioValue == 0 and options.MeterRAMPageBar.Hidden == '0', 'Known zero PAGE usage must retain a visible empty bar')
    files[path] = 'RAM_PAGE|1|'..token..'|2|'..now..'|OK|1|4000000000|1'
    env.Update()
    check(options.MeterRAMPageMiB.Text == 'Unavailable', 'A changed frame at the same sequence must be rejected')
    files[path] = 'RAM_PAGE|1|'..token..'|3|'..now..'|NONE|0|0|0'
    env.Update()
    check(options.MeterRAMPageMiB.Text == 'No paging file', 'Controller must preserve the no-paging-file state')
    check(ratioValue == 0 and options.MeterRAMPageBar.Hidden == '1', 'No-file PAGE state must hide its bar')
    files[path] = 'RAM_PAGE|1|'..token..'|4|'..now..'|OK|0|0|1'
    env.Update()
    check(options.MeterRAMPageBar.Hidden == '1' and ratioValue == 0, 'Zero allocated PAGE capacity must not produce a ratio or visible bar')
    env.Stop(); env.Stop()
    check(kills.MeasureRAMPageHost == 1 and not kills.MeasureRAMPageBootstrap, 'Stop must kill only its running resident helper')
    check(removed[path] == 1 and removed[lease] == 1 and removed[temporary] == 1, 'Stop must clean only its three session files once')
    env.Start()
    check(launches.MeasureRAMPageHost == 1 and launches.MeasureRAMPageBootstrap == 1, 'Stopped controller must not restart from incidental actions')

    reset(); env.Stop(); env.Stop()
    check(next(kills) == nil and next(launches) == nil and #actions == 0,
        'Stop before Start must not kill an unlaunched minus-one-status helper')

    reset(); providers.MeasureRAMPageBootstrap.value=0; providers.MeasureRAMPageHost.value=0
    env.Stop(); env.Stop()
    check(next(kills) == nil and next(launches) == nil and #actions == 0,
        'Stop before Start must not mistake an unupdated zero cache for a running helper')

    reset(); env.Start(); env.Stop(); env.Stop()
    check(kills.MeasureRAMPageBootstrap == 1 and not kills.MeasureRAMPageHost,
        'Stop must kill the tracked running bootstrap at zero exactly once')
    check(next(removed) == nil, 'Stopping bootstrap before session creation must not remove files')

    reset(); env.Start(); providers.MeasureRAMPageBootstrap.value=1; env.Stop(); env.Stop()
    check(next(kills) == nil, 'Stop must not kill a completed bootstrap')

    reset(); startHost(); providers.MeasureRAMPageHost.value=1; env.Stop(); env.Stop()
    check(next(kills) == nil, 'Stop must not kill a completed host or completed bootstrap')
    check(removed[path] == 1 and removed[lease] == 1 and removed[temporary] == 1,
        'Completed host still requires idempotent session cleanup')

    reset(); startHost()
    local hostUpdates = providers.MeasureRAMPageHost.updates
    providers.MeasureRAMPageHost.refreshValue = 1
    env.Stop(); env.Stop()
    check(providers.MeasureRAMPageHost.updates == hostUpdates+1 and next(kills) == nil,
        'Stop must refresh tracked status once so cached zero cannot kill a completed host')

    reset(); env.Start(); now=now+20; env.Update(); env.Stop(); env.Stop()
    check(kills.MeasureRAMPageBootstrap == 1 and not kills.MeasureRAMPageHost,
        'Bootstrap timeout must kill only its tracked running zero-status helper once')
    check(options.MeterRAMPageGiB.Text == 'Unavailable', 'Bootstrap timeout must expose unavailable PAGE data')

    reset(); env.Start(); providers.MeasureRAMPageBootstrap.value=103; env.Update(); env.Stop()
    check(next(kills) == nil and not launches.MeasureRAMPageHost,
        'Terminal bootstrap launch failure must not receive Kill or launch the host')

    reset(); startHost(); providers.MeasureRAMPageHost.value=103; env.Update(); env.Stop()
    check(next(kills) == nil, 'Terminal host failure must not receive Kill')

    reset(); startHost(); now=now+5; rejectLease=true; env.Update(); env.Stop(); env.Stop()
    check(kills.MeasureRAMPageHost == 1 and not kills.MeasureRAMPageBootstrap,
        'Lease failure must kill only its tracked running zero-status host once')
    check(removed[path] == 1 and removed[lease] == 1 and removed[temporary] == 1,
        'Lease failure must clean its own session once')
end

local function checkSettingsController()
    -- Exercise the copied production settings controller with a fake skin.
    -- All bangs are captured; numeric input never opens a helper or popup.
    local inputName = 'MeasureRAMSettingsInput'
    local applyGroup = assert(SKIN:GetMeasure('MeasureRAMSettings')):GetOption('Group')
    local monitorGroup = applyGroup:gsub('Apply$','')
    local variables, options, actions, writes, broadcasts, applies = {}, {}, {}, {}, {}, {}
    local launches, kills, closes, inputUpdates = 0, 0, 0, 0
    local provider = {value=-1,text='',present=true}
    local frameX, frameY, frameWidth, frameHeight, framePresent = 150,128,56,20,true
    local skinX, skinY = 20,30
    local frame = {}
    function frame:GetX() return frameX end
    function frame:GetY() return frameY end
    function frame:GetW() return frameWidth end
    function frame:GetH() return frameHeight end
    local allowed = {RAMUseMiB=true,RAMDecimals=true,RAMPercentDecimals=true,
        RAMShowBar=true,RAMShowPageBar=true,RAMShowHistory=true}
    function provider:GetValue() return self.value end
    function provider:GetStringValue() return self.text end
    local fakeSkin = {}
    function fakeSkin:GetVariable(name, default) return variables[name] or default end
    function fakeSkin:GetMeasure(name)
        assert(name == inputName,'Settings controller queried a telemetry or unrelated measure')
        return provider.present and provider or nil
    end
    function fakeSkin:GetMeter(name)
        assert(name == 'MeterRAMSettingsDecimalsFrame' or name == 'MeterRAMSettingsPercentDecimalsFrame',
            'Numeric editor queried an unrelated frame')
        return framePresent and frame or nil
    end
    function fakeSkin:GetX() return skinX end
    function fakeSkin:GetY() return skinY end
    function fakeSkin:GetW() return 456 end
    function fakeSkin:GetH() return 340 end
    function fakeSkin:Bang(command, name, key, value, target)
        actions[#actions+1] = {command,name,key,value,target}
        if command == '!SetOption' then
            assert(name == inputName or name:match('^MeterRAMSettings'),
                'Settings controller changed an unrelated meter or measure')
            options[name] = options[name] or {}; options[name][key] = value
        elseif command == '!SetVariable' then
            assert(allowed[name] and tostring(key):match('^[012]$'),'Settings controller assigned an unsafe preference')
            variables[name] = key
        elseif command == '!WriteKeyValue' then
            assert(name == 'Variables' and allowed[key] and tostring(value):match('^[012]$')
                and target == variables['@']..'User\\RAM.inc','Settings persistence escaped its fixed destination or allowlist')
            writes[#writes+1] = {key,value}
        elseif command == '!SetVariableGroup' then
            assert(allowed[name] and value == monitorGroup,'Settings broadcast escaped loaded RAM monitors')
            broadcasts[#broadcasts+1] = {name,key}
        elseif command == '!UpdateMeasureGroup' then
            assert(name == applyGroup and key == '*','Settings apply forced collection or history work')
            applies[#applies+1] = name
        elseif command == '!UpdateMeterGroup' then
            assert(name == 'RAMSettingsUI','Settings render touched monitor meters or history')
        elseif command == '!UpdateMeasure' then
            assert(name == inputName,'Settings updated a telemetry or unrelated measure')
            inputUpdates = inputUpdates+1
            if provider.refreshValue ~= nil then
                provider.value, provider.refreshValue = provider.refreshValue, nil
            end
            if provider.refreshCallback then
                local callback = provider.refreshCallback; provider.refreshCallback=nil; callback()
            end
        elseif command == '!CommandMeasure' then
            assert(name == inputName,'Settings launched a telemetry or unrelated provider')
            if key == 'Run' then
                local parameter = assert(options[inputName] and options[inputName].Parameter)
                assert(parameter:find('-File "SettingsInput.ps1" -Key UtilityNumber',1,true)
                    and parameter:find('-Minimum 0 -Maximum 2 -DecimalPlaces 0',1,true)
                    and parameter:match('%-Initial [012] ') and not parameter:find('RAMDecimals',1,true)
                    and not parameter:find('RAMPercentDecimals',1,true) and not parameter:find('User\\',1,true),
                    'Input launch escaped its fixed script, numeric mode or canonical bounds')
                launches=launches+1; provider.value=provider.launchStatus or 0
            elseif key == 'Kill' then kills=kills+1
            else error('Settings used an unexpected helper command') end
        elseif command == '!DeactivateConfig' then
            assert(name == nil,'Closing settings targeted another config'); closes=closes+1
        else assert(command == '!Redraw','Unexpected settings action: '..tostring(command)) end
    end
    local function forbidden() error('Settings controller attempted direct IO, code loading or process access') end
    local env = setmetatable({SKIN=fakeSkin,io=setmetatable({}, {__index=forbidden}),
        os=setmetatable({}, {__index=forbidden}),dofile=forbidden,loadfile=forbidden,loadstring=forbidden}, {__index=_G})
    env._G = env
    local chunk = assert(loadfile(SKIN:GetVariable('@')..'Modules\\RAM\\Settings.lua'))
    setfenv(chunk,env)
    local function reset(overrides)
        variables = {['@']='C:\\Synthetic Resources\\',RAMUseMiB='0',RAMDecimals='1',RAMPercentDecimals='0',
            RAMShowBar='1',RAMShowPageBar='1',RAMShowHistory='1',Scale='1',
            CURRENTCONFIGX='20',CURRENTCONFIGY='30',CURRENTCONFIGWIDTH='456',CURRENTCONFIGHEIGHT='340',
            AccentColor='137,190,250',TextColor='220,220,220',MutedColor='120,120,120',DangerColor='255,80,80'}
        for key,value in pairs(overrides or {}) do variables[key]=value end
        options, actions, writes, broadcasts, applies = {}, {}, {}, {}, {}
        launches, kills, closes, inputUpdates = 0,0,0,0
        provider.value, provider.text, provider.present, provider.refreshValue, provider.launchStatus, provider.refreshCallback = -1,'',true,nil,nil,nil
        frameX, frameY, frameWidth, frameHeight, framePresent, skinX, skinY = 150,128,56,20,true,20,30
        chunk(); env.Initialize(); env.Update()
    end
    local function sameWork(previous, message)
        check(#writes==previous[1] and #broadcasts==previous[2] and #applies==previous[3]
            and launches==previous[4] and kills==previous[5],message)
    end
    local function work() return {#writes,#broadcasts,#applies,launches,kills} end
    local function changed(key, value, previous)
        check(tonumber(variables[key])==value,'Settings preference did not change: '..key)
        check(#writes==previous[1]+1 and #broadcasts==previous[2]+1 and #applies==previous[3]+1,
            'One settings change must persist, broadcast and apply exactly once')
        check(writes[#writes][1]==key and tonumber(writes[#writes][2])==value
            and broadcasts[#broadcasts][1]==key and tonumber(broadcasts[#broadcasts][2])==value,
            'Settings persistence and broadcast disagree')
        check(launches==previous[4] and kills==previous[5],'Preference apply unexpectedly changed helper lifecycle')
    end
    local function finish(output, status)
        provider.value, provider.text = status or 1,output
        env.CompleteInput()
    end
    reset()
    check(#writes==0 and #applies==0 and launches==0 and inputUpdates==0,
        'Opening or rendering settings must not write, launch or query a provider')
    local before = work(); env.CompleteInput(); env.CompleteInput()
    sameWork(before,'Unowned input completion changed settings or launched work')
    check(inputUpdates==0,'Unowned completion queried the idle input measure')

    for _,key in ipairs({'RAMDecimals','RAMPercentDecimals'}) do
        reset({[key]='0'})
        before=work(); env.Adjust(key,-1)
        sameWork(before,'Numeric decrement wrote or applied at zero')
        for expected=1,2 do before=work(); env.Adjust(key,1); changed(key,expected,before) end
        before=work(); env.Adjust(key,1)
        sameWork(before,'Numeric increment wrote or applied at two')
        for expected=1,0,-1 do before=work(); env.Adjust(key,-1); changed(key,expected,before) end
        before=work()
        for _,direction in ipairs({0,2,-2,0.5,'invalid',math.huge,0/0}) do env.Adjust(key,direction) end
        env.Adjust(key,nil)
        sameWork(before,'Invalid numeric step direction changed settings')
        check(launches==0,'Numeric arrows started an input helper')
    end
    for _,case in ipairs({{'RAMDecimals','2.5',1},{'RAMPercentDecimals','-3',-1}}) do
        reset({[case[1]]=case[2]}); before=work(); env.Adjust(case[1],case[3])
        sameWork(before,'Loading or taking a no-op step rewrote a legacy saved numeric value')
        check(variables[case[1]]==case[2],'No-op numeric display normalization overwrote the raw saved preference')
    end
    reset()
    before=work(); env.Cycle('RAMUseMiB',-1); changed('RAMUseMiB',1,before)
    before=work(); env.Cycle('RAMUseMiB',1); changed('RAMUseMiB',0,before)
    before=work(); env.Cycle('RAMUseMiB'); changed('RAMUseMiB',1,before)
    before=work(); env.Cycle('RAMUseMiB',1); changed('RAMUseMiB',0,before)
    for _,key in ipairs({'RAMShowBar','RAMShowPageBar','RAMShowHistory'}) do
        before=work(); env.Cycle(key); changed(key,0,before)
        before=work(); env.Cycle(key); changed(key,1,before)
    end
    before=work()
    for _,key in ipairs({'RAMDecimals','RAMPercentDecimals','Unknown','Columns','PanelHeight','RAMTitle',
        'RAMDecimals[!Execute]','RAMUseMiB;Write'}) do env.Cycle(key) end
    for _,key in ipairs({'RAMUseMiB','RAMShowBar','RAMShowPageBar','RAMShowHistory','Unknown','Columns'}) do
        env.Adjust(key,1); env.Edit(key)
    end
    for _,direction in ipairs({0,2,-2,0.5,'invalid',math.huge,0/0}) do env.Cycle('RAMUseMiB',direction) end
    sameWork(before,'Invalid, numeric or disallowed settings action escaped its allowlist')

    for _,key in ipairs({'RAMDecimals','RAMPercentDecimals'}) do
        for _,case in ipairs({{'0','PARALLAX_INPUT_V1|ok|2',2},
            {'2','PARALLAX_INPUT_V1|ok|1\r\n',1},{'1','PARALLAX_INPUT_V1|ok|0\n',0}}) do
            reset({[key]=case[1]})
            env.Edit(key)
            check(launches==1 and #writes==0,'Valid numeric edit must launch exactly one event-only input')
            check(options[inputName].Parameter:find('-X 170 -Y 158 -Width 56 -Height 20 -Scale 1.0000',1,true),
                'Numeric entry did not use the clicked field absolute physical geometry')
            local parameter = options[inputName].Parameter
            before=work(); finish(case[2]); changed(key,case[3],before)
            check(options[inputName].Parameter==parameter,'Typed input was interpolated into a command')
            before=work(); env.CompleteInput(); env.CompleteInput()
            sameWork(before,'Repeated input completion applied a result more than once')
            check(kills==0,'Successful numeric entry killed a completed helper')
        end
    end
    reset(); env.Edit('RAMDecimals')
    before=work(); finish('PARALLAX_INPUT_V1|ok|1')
    sameWork(before,'Typing the existing value wrote or reapplied a preference')
    for _,output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|cancel|\r\n',
        'PARALLAX_INPUT_V1|cancel|\n'}) do
        reset(); env.Edit('RAMDecimals'); before=work(); finish(output)
        sameWork(before,'Cancelled numeric input changed settings or killed a completed helper')
        check(options.MeterRAMSettingsHint.Text:lower():find('cancel',1,true),
            'Cancelled entry did not expose its state in settings')
    end
    for _,output in ipairs({'','PARALLAX_INPUT_V1|ok|','PARALLAX_INPUT_V1|ok|-1',
        'PARALLAX_INPUT_V1|ok|3','PARALLAX_INPUT_V1|ok|1.5','PARALLAX_INPUT_V1|ok|1.0',
        'PARALLAX_INPUT_V1|ok|01','PARALLAX_INPUT_V1|ok|+1','PARALLAX_INPUT_V1|ok|1e0',
        'PARALLAX_INPUT_V1|ok|nan','PARALLAX_INPUT_V1|ok|inf','PARALLAX_INPUT_V1|ok|1%',
        'PARALLAX_INPUT_V1|ok|#RAMDecimals#','PARALLAX_INPUT_V1|ok|[!Execute]',
        'PARALLAX_INPUT_V1|ok|1|extra','PARALLAX_INPUT_V1|ok|1\nPARALLAX_INPUT_V1|ok|2',
        'PARALLAX_INPUT_V1|ok|1\n\n',' PARALLAX_INPUT_V1|ok|1','PARALLAX_INPUT_V1|ok|1 ',
        'PARALLAX_INPUT_V1|ok|1\r','PARALLAX_INPUT_V1|cancel|1','PARALLAX_INPUT_V1|error|',
        'PARALLAX_INPUT_V2|ok|1','PARALLAX_INPUT_V1|OK|1',string.rep('x',65)}) do
        reset(); env.Edit('RAMDecimals'); before=work(); finish(output)
        sameWork(before,'Malformed or unsupported numeric input changed settings')
        check(variables.RAMDecimals=='1','Rejected input changed the saved numeric choice')
        check(options.MeterRAMSettingsHint.Text:lower():find('invalid',1,true),
            'Rejected numeric entry did not expose its state in settings')
        before=work(); env.Edit('RAMPercentDecimals')
        check(launches==before[4]+1,'Rejected terminal input left the editor permanently pending')
    end
    for _,output in ipairs({false,1}) do
        reset(); env.Edit('RAMDecimals'); before=work(); finish(output)
        sameWork(before,'Non-string numeric input changed settings')
    end
    reset(); env.Edit('RAMDecimals'); before=work(); finish(nil)
    sameWork(before,'Missing numeric input output changed settings')

    reset(); env.Edit('RAMDecimals'); before=work()
    env.Edit('RAMPercentDecimals'); env.Edit('RAMDecimals')
    env.Adjust('RAMDecimals',1); env.Cycle('RAMUseMiB'); env.Cycle('RAMShowHistory')
    sameWork(before,'Pending input permitted a concurrent edit or setting change')
    provider.value=0; env.CompleteInput(); env.CompleteInput()
    sameWork(before,'Running input completion wrote, killed or relaunched a helper')
    check(inputUpdates>=2,'Running input completion did not refresh actual status')
    before=work(); finish('PARALLAX_INPUT_V1|ok|2'); changed('RAMDecimals',2,before)
    check(variables.RAMPercentDecimals=='0' and variables.RAMUseMiB=='0' and variables.RAMShowHistory=='1',
        'Concurrent edit changed the pending destination or unrelated choices')
    reset(); env.Edit('RAMDecimals'); before=work()
    provider.refreshCallback=function() env.CompleteInput() end
    finish('PARALLAX_INPUT_V1|ok|2'); changed('RAMDecimals',2,before)
    check(provider.refreshCallback==nil,'Reentrant completion fixture did not execute')

    for _,status in ipairs({100,101,102,103}) do
        reset(); env.Edit('RAMDecimals'); before=work(); finish('PARALLAX_INPUT_V1|ok|2',status)
        sameWork(before,'Terminal input failure applied output or killed a completed helper')
        check(options.MeterRAMSettingsHint.Text:lower():find('failed',1,true),
            'Terminal numeric-input failure did not expose its state in settings')
        env.Edit('RAMPercentDecimals')
        check(launches==before[4]+1,'Terminal input failure did not release pending ownership')
    end
    reset(); provider.launchStatus=103; env.Edit('RAMDecimals')
    check(launches==1 and kills==0 and #writes==0 and options.MeterRAMSettingsHint.Text:lower():find('failed',1,true),
        'Immediate input launch failure was not released and reported without writing or killing')
    before=work(); provider.value=1; provider.text='PARALLAX_INPUT_V1|ok|2'; env.CompleteInput()
    sameWork(before,'Unowned callback applied output after an immediate launch failure')
    provider.launchStatus=nil; env.Edit('RAMPercentDecimals')
    check(launches==2,'Immediate launch failure left numeric entry permanently pending')
    reset(); provider.present=false; before=work(); env.Edit('RAMDecimals')
    sameWork(before,'Unavailable input measure launched or changed a preference')
    reset(); framePresent=false; before=work(); env.Edit('RAMDecimals')
    sameWork(before,'Missing numeric field geometry launched or changed a preference')
    for _,case in ipairs({{'skinX',math.huge},{'skinY',0/0},{'frameX',-100021},{'frameY',100001},
        {'width',0},{'height',-1},{'scale',math.huge}}) do
        reset()
        if case[1]=='skinX' then skinX=case[2]
        elseif case[1]=='skinY' then skinY=case[2]
        elseif case[1]=='frameX' then frameX=case[2]
        elseif case[1]=='frameY' then frameY=case[2]
        elseif case[1]=='width' then frameWidth=case[2]
        elseif case[1]=='height' then frameHeight=case[2]
        else variables.Scale=case[2] end
        before=work(); env.Edit('RAMDecimals')
        sameWork(before,'Invalid physical entry geometry launched or changed a preference')
    end

    reset(); before=work(); env.Close(); env.Close()
    sameWork(before,'Closing an unlaunched editor killed an initial minus-one-status measure')
    check(closes==0 and inputUpdates==0,'Unlaunched close queried input or dispatched config actions')
    local closedActions = #actions
    env.Edit('RAMDecimals'); env.Adjust('RAMDecimals',1); env.Cycle('RAMUseMiB'); env.CompleteInput()
    env.Update()
    sameWork(before,'Closed settings controller accepted a later callback or action')
    check(#actions==closedActions,'Closed settings controller kept rendering or querying input')
    reset(); provider.value=0; before=work(); env.Close(); env.Close()
    sameWork(before,'Closing an unlaunched editor mistook an unupdated zero cache for a running helper')
    check(closes==0 and inputUpdates==0,'Cached-zero unlaunched close queried input or dispatched config actions')
    for _,status in ipairs({0,1,103}) do
        reset(); env.Edit('RAMDecimals'); provider.value=status
        env.Close(); env.Close()
        check(kills==(status==0 and 1 or 0) and closes==0,'Close killed the wrong tracked input state or dispatched config actions')
        before=work(); provider.value=1; provider.text='PARALLAX_INPUT_V1|ok|2'; env.CompleteInput()
        sameWork(before,'Late input completion applied after settings closed')
    end
    reset(); env.Edit('RAMDecimals'); provider.refreshValue=1; env.Close()
    check(kills==0 and inputUpdates>=1,'Close trusted stale zero instead of refreshing tracked helper status')
end

local function checkPage()
    local frame = pageModel.Parse(SELF:GetOption('PageFixture', '', false), SELF:GetOption('PageToken'), SELF:GetNumberOption('PageNow'), 1000)
    local view = assert(SKIN:GetMeasure('MeasureRAMPageView'))
    check(view:GetValue() == 1, 'PAGE fixture must parse once and retain its cache through settings actions')
    for _, name in ipairs({'MeasureRAMPageBootstrap','MeasureRAMPageHost'}) do
        equalOption(assert(SKIN:GetMeasure(name)), 'Measure', 'Calc')
    end
    check(SKIN:GetMeasure('MeasureRAMPageUsed') == nil and SKIN:GetMeasure('MeasureRAMPageTotal') == nil,
        'PAGE must not retain native commit-accounting measures')
    local ratio = frame and frame.status == 'OK' and frame.total > 0 and frame.used/frame.total or nil
    local ratioMeasure = assert(SKIN:GetMeasure('MeasureRAMPageRatio'))
    equalOption(ratioMeasure, 'Measure', 'Calc')
    check(math.abs(ratioMeasure:GetValue()-(ratio or 0)) < 0.0000001, 'PAGE bar is not bound to paging-file-only ratio')
    equalOption(meter('MeterRAMPageBar'), 'MeasureName', 'MeasureRAMPageRatio')
    local visible = ratio ~= nil and tonumber(SKIN:GetVariable('RAMShowPageBar')) == 1
    equalOption(meter('MeterRAMPageBar'), 'Hidden', visible and '0' or '1')
    for _, pair in ipairs({{'GiB',0}, {'MiB',1}}) do
        local item = meter('MeterRAMPage'..pair[1])
        local value = pageModel.Format(frame, pair[2], SKIN:GetVariable('RAMDecimals'))
        equalOption(item, 'Text', value.text)
        equalOption(item, 'ToolTipText', value.tip)
        equalOption(item, 'MeasureName', '')
        equalOption(item, 'MeasureName2', '')
        equalOption(item, 'ClipString', '1')
        local useMB = tonumber(SKIN:GetVariable('RAMUseMiB'))
        check(number(item:GetOption('Hidden')) == (pair[2] == 0 and useMB or 1-useMB), 'Wrong PAGE units visible')
    end
    return frame and frame.status:lower() or 'stale/unavailable'
end

local function checkProcesses(checkLayout)
    local mode = SELF:GetOption('ProcessMode')
    local count = -1
    if mode == 'Fixture' then
        local samples = {}
        for rank=1,5 do
            local provider = assert(SKIN:GetMeasure('MeasureRAMProcess'..rank))
            equalOption(provider, 'Measure', 'Calc')
            samples[rank] = {name=provider:GetStringValue(), bytes=provider:GetValue()}
        end
        local result = processModel.Format(samples, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
        count = #result.rows
        check(count == SELF:GetNumberOption('ExpectedProcesses'), 'Ranked/missing process fixture did not format correctly')
        equalOption(meter('MeterRAMProcessesHeader'), 'ToolTipText', 'Five largest private working sets, highest first. '..result.tip)
        check(result.tip:find(count..' of 5 ranked entries',1,true) ~= nil, 'Process header must report ranked-entry availability')
        local state = meter('MeterRAMProcessesState')
        equalOption(state, 'Text', result.state)
        check(number(state:GetOption('Hidden','0')) == (count == 0 and 0 or 1), 'Process availability state visibility is incorrect')
        for rank=1,5 do
            local row = result.rows[rank]
            for _, kind in ipairs({'Name','Value'}) do
                local item = meter('MeterRAMProcess'..kind..rank)
                equalOption(item, 'Text', row and (kind == 'Name' and row.name or row.text) or '')
                check(number(item:GetOption('Hidden','0')) == (row and 0 or 1), 'Missing or ranked process row visibility is incorrect')
                if row then
                    equalOption(item, 'ClipString', '1')
                    check(item:GetOption('ToolTipText'):find('private working set',1,true) ~= nil, 'Process value must explain its memory metric')
                end
            end
        end
        if count > 0 then
            check(result.rows[1].name == 'Fixture Browser with a deliberately long process group name', 'Provider rank order changed')
            check(result.rows[5].name == 'Fixture Service', 'Fifth process rank disappeared')
        end
    end
    if checkLayout then
        local scale = tonumber(SKIN:GetVariable('Scale'))
        local extra = math.max(0,tonumber(SKIN:GetVariable('DataBarThickness'))-6)
        local origin = number('#Inset#')+(tonumber(SKIN:GetVariable('RAMInfoHeight'))+2*extra)*scale
        local header = meter('MeterRAMProcessesHeader')
        local historyLabel = meter('MeterRAMHistoryLabel')
        local lastRow = meter('MeterRAMProcessName5')
        equalOption(header, 'Text', 'Process')
        check(historyLabel:GetY(true) >= lastRow:GetY(true)+lastRow:GetH(), 'Bottom history section overlaps the process table')
        check(math.abs(header:GetY(true)-(origin+96*scale)) <= 1.01, 'Process header did not follow overview height')
        for rank=1,5 do
            local name = meter('MeterRAMProcessName'..rank)
            local value = meter('MeterRAMProcessValue'..rank)
            local expected = origin+(118+(rank-1)*18)*scale
            check(math.abs(name:GetY(true)-expected) <= 1.01 and math.abs(value:GetY(true)-expected) <= 1.01, 'Process row did not follow overview height')
            check(name:GetX(true)+name:GetW() <= value:GetX(true)-value:GetW(), 'Process name and value columns overlap')
            if rank < 5 then check(name:GetY(true)+name:GetH() <= meter('MeterRAMProcessName'..(rank+1)):GetY(true)+1.01, 'Process rows overlap') end
        end
    end
    return mode:lower()..':'..(count >= 0 and tostring(count)..' rows' or 'provider bindings only')
end

local function checkHardware(checkLayout)
    local mode = SELF:GetOption('InfoMode')
    local provider = SKIN:GetMeasure('MeasureRAMInfo')
    local raw = mode == 'Fixture' and SELF:GetOption('InfoFixture', '', false) or provider:GetStringValue()
    local data = mode ~= 'Timeout' and provider:GetValue() == 1 and infoModel.Parse(raw) or nil
    local fields = infoModel.Format(data, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    local item = meter('MeterRAMInfoSummary')
    equalOption(item, 'Text', SKIN:ReplaceVariables(fields.Summary.text))
    equalOption(item, 'ClipString', '2')
    check(item:GetOption('Group'):find('RAMHardwareInfo',1,true) ~= nil, 'Summary cannot update independently from history')
    check(item:GetOption('Text') ~= 'Checking...', 'Hardware summary did not settle')
    check(#item:GetOption('ToolTipText') > 20, 'Summary has no metadata explanation')
    local expectedGroups = SELF:GetNumberOption('ExpectedGroups', -1)
    if expectedGroups >= 0 then check(#fields.groups == expectedGroups, 'Duplicate or mixed module groups formatted incorrectly') end
    if checkLayout then
        local scale = tonumber(SKIN:GetVariable('Scale'))
        local infoHeight = tonumber(SKIN:GetVariable('RAMInfoHeight'))
        local thickness = tonumber(SKIN:GetVariable('DataBarThickness'))
        local extra = math.max(0,thickness-6)
        local needed = math.ceil(math.max(18*scale, item:GetH()))/scale+8
        check(item:GetH() > 0, 'Wrapped summary has no measured height')
        check(math.abs(infoHeight-needed) < 0.05, 'Overview height did not settle to the measured summary: '..infoHeight..' expected '..needed)
        local panel = meter('MeterRAMInfoPanel')
        check(item:GetY(true) >= panel:GetY(true) and item:GetY(true)+item:GetH() <= panel:GetY(true)+panel:GetH()+0.01,
            'Wrapped summary leaves its hardware panel')
        check(panel:GetY(true)+panel:GetH() < meter('MeterRAMUsedLabel'):GetY(true), 'Hardware summary overlaps compact memory rows')
        for _, pair in ipairs({{'UsedLabel',34}, {'PageLabel',66+extra}, {'Bar',math.max(54,57-thickness/2)}, {'PageBar',math.max(86,89-thickness/2)+extra}, {'HistoryLabel',216+2*extra}, {'History',236+2*extra}, {'HistoryFrame',236+2*extra}, {'HistoryUncollected',236+2*extra}}) do
            local actual = meter('MeterRAM'..pair[1]):GetY(true)
            local expected = number('#Inset#')+(infoHeight+pair[2])*scale
            check(math.abs(actual-expected) <= 1.01, 'Meter did not follow wrapped summary: '..pair[1]..' y='..actual..' expected '..expected)
        end
        local roundedHeight = math.max(1,math.floor(thickness*scale+0.5))
        for _, spec in ipairs({{'MeterRAMBar','MeterRAMUsedLabel','MeterRAMPageLabel'}, {'MeterRAMPageBar','MeterRAMPageLabel','MeterRAMProcessesHeader'}}) do
            local bar, label, nextRow = meter(spec[1]), meter(spec[2]), meter(spec[3])
            local barHeight, barY = number(bar:GetOption('H')), number(bar:GetOption('Y'))
            check(barHeight == roundedHeight, spec[1]..' must use shared rounded pixel thickness')
            if number(bar:GetOption('Hidden','0')) == 0 then
                check(bar:GetH() > 0 and math.abs(bar:GetH()-roundedHeight) <= 1.01, 'Visible '..spec[1]..' loses configured pixel thickness')
                barHeight, barY = bar:GetH(), bar:GetY(true)
            end
            check(barY >= label:GetY(true)+label:GetH()+2*scale-1.01, spec[1]..' loses clearance below its readout')
            check(nextRow:GetY(true) >= barY+barHeight+4*scale-1.01, spec[1]..' overlaps following content')
        end
    end
    local text = SKIN:ReplaceVariables(fields.Summary.text):gsub('[\r\n]+',' / ')
    return string.format('%s:%s [%s]; groups=%d summaryHeight=%g overviewHeight=%s', mode:lower(), data and 'reported' or 'unavailable',
        text, #fields.groups, item:GetH(), SKIN:GetVariable('RAMInfoHeight'))
end

local function run()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local columns = tonumber(SKIN:GetVariable('Columns'))
    local width = tonumber(SKIN:GetVariable('ColumnWidth'))
    local thickness = tonumber(SKIN:GetVariable('DataBarThickness'))
    check(scale == SELF:GetNumberOption('ExpectedScale'), 'Scale override lost')
    check(columns == SELF:GetNumberOption('ExpectedColumns'), 'Column override lost')
    check(width == SELF:GetNumberOption('ExpectedWidth'), 'Width override lost')
    check(thickness == SELF:GetNumberOption('ExpectedDataBarThickness'), 'Data-bar thickness override lost')
    local round = function(value) return math.floor(value + 0.5) end
    local gap = 2 * round(tonumber(SKIN:GetVariable('Gutter')) * scale / 2)
    local expectedW = columns * (round(width * scale) + gap)
    local expectedH = math.max(round(tonumber(SKIN:GetVariable('PanelHeight')) * scale),
        round((242 + tonumber(SKIN:GetVariable('RAMInfoHeight')) + tonumber(SKIN:GetVariable('GraphHeight')) + 2*math.max(0,thickness-6)) * scale)) + gap
    local inset = gap / 2
    check(SKIN:GetW() == expectedW, 'Native skin width ' .. SKIN:GetW() .. ' expected ' .. expectedW)
    check(SKIN:GetH() == expectedH, 'Native skin height ' .. SKIN:GetH() .. ' expected ' .. expectedH)
    local bounds = meter('MeterRAMBounds')
    check(bounds:GetW() == expectedW and bounds:GetH() == expectedH, 'Bounds meter does not preserve window')
    local visible = 0
    for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
        local item = meter(name)
        local x, y, w, h = item:GetX(true), item:GetY(true), item:GetW(), item:GetH()
        local hidden = number(item:GetOption('Hidden', '0')) ~= 0
        if not hidden then
            visible = visible + 1
            -- Lua GetX(true) resolves relative placement but keeps String anchors.
            local align = item:GetOption('StringAlign'):lower()
            if align:match('^right') then x = x - w end
            if align:match('^center') then x = x - w / 2 end
            if align:match('center$') then y = y - h / 2 end
            if align:match('bottom$') then y = y - h end
            check(w >= 0 and h >= 0, name .. ' negative native size')
            check(x >= -0.01 and y >= -0.01 and x + w <= expectedW + 0.01 and y + h <= expectedH + 0.01,
                string.format('%s exceeds window: %.2f,%.2f %.2fx%.2f', name, x, y, w, h))
            if name ~= 'MeterRAMBounds' then
                check(x >= inset - 0.01 and y >= inset - 0.01 and x + w <= expectedW - inset + 0.01 and y + h <= expectedH - inset + 0.01,
                    string.format('%s enters gutter: %.2f,%.2f %.2fx%.2f', name, x, y, w, h))
            end
        end
    end
    local used = assert(SKIN:GetMeasure('MeasureRAMUsed'))
    local available = assert(SKIN:GetMeasure('MeasureRAMAvailable'))
    local total = assert(SKIN:GetMeasure('MeasureRAMTotal'))
    for _, measure in ipairs({used, available, total}) do
        equalOption(measure, 'Measure', 'PhysicalMemory')
        check(measure:GetNumberOption('UpdateDivider') == 1, measure:GetName() .. ' changed cadence')
        check(measure:GetValue() >= 0 and measure:GetValue() <= total:GetValue(), measure:GetName() .. ' outside physical memory range')
    end
    check(total:GetValue() > 0, 'No native physical memory total')
    check(used:GetMaxValue() == total:GetValue(), 'Used range lost native total')
    check(used:GetMinValue() == 0, 'Used native range minimum changed')
    check(math.abs(used:GetRelativeValue() - used:GetValue() / total:GetValue()) < 0.000001, 'Native relative value is not used/total')
    equalOption(available, 'InvertMeasure', '1')
    equalOption(total, 'Total', '1')
    equalOption(meter('MeterRAMUsedLabel'), 'Text', 'RAM:')
    equalOption(meter('MeterRAMPageLabel'), 'Text', 'PAGE:')
    local percent = meter('MeterRAMPercent')
    equalOption(percent, 'MeasureName', 'MeasureRAMUsed')
    equalOption(percent, 'Percentual', '1')
    equalOption(percent, 'AutoScale', '0')
    equalOption(meter('MeterRAMBar'), 'MeasureName', 'MeasureRAMUsed')
    local history = meter('MeterRAMHistory')
    equalOption(history, 'MeasureName', 'MeasureRAMUsed')
    equalOption(history, 'AutoScale', '0')
    equalOption(history, 'GraphStart', 'Right')
    check(tonumber(history:GetOption('Scale')) == 1, 'History byte scale changed')
    local useMiB = tonumber(SKIN:GetVariable('RAMUseMiB'))
    for _, binding in ipairs({{'Used','MeasureRAMUsed','MeasureRAMTotal'}}) do
        local kind = binding[1]
        for _, unit in ipairs({'GiB', 'MiB'}) do
            -- Meter IDs stay compatible; visible units use decimal divisors.
            local displayUnit = unit == 'GiB' and 'GB' or 'MB'
            local item = meter('MeterRAM' .. kind .. unit)
            equalOption(item, 'MeasureName', binding[2])
            equalOption(item, 'MeasureName2', binding[3])
            equalOption(item, 'AutoScale', '0')
            equalOption(item, 'Text', '%1/%2 ' .. displayUnit)
            check(tonumber(item:GetOption('Scale')) == (unit == 'GiB' and 1000000000 or 1000000), 'Decimal byte divisor and suffix mismatch')
            local expectedHidden = (unit == 'GiB') and useMiB or (1 - useMiB)
            check(number(item:GetOption('Hidden')) == expectedHidden, 'Wrong unit meter visible')
            equalOption(item, 'ClipString', '1')
        end
    end
    equalOption(meter('MeterRAMTitle'), 'ClipString', '1')
    equalOption(meter('MeterRAMTitle'), 'FontColor', SKIN:GetVariable('TitleTextColor'))
    check(number(meter('MeterRAMTitle'):GetOption('FontSize')) == tonumber(SKIN:GetVariable('TitleFontSize'))*scale, 'Title font role lost')
    for _, name in ipairs({'MeterRAMHistoryLabel', 'MeterRAMProcessesHeader', 'MeterRAMProcessesMemoryHeader'}) do
        equalOption(meter(name), 'FontColor', SKIN:GetVariable('HeaderTextColor'))
        check(number(meter(name):GetOption('FontSize')) == tonumber(SKIN:GetVariable('HeaderFontSize'))*scale, 'Header font role lost: '..name)
    end
    for _, name in ipairs({'MeterRAMUsedGiB', 'MeterRAMPageGiB', 'MeterRAMInfoSummary', 'MeterRAMProcessName1', 'MeterRAMProcessValue1'}) do
        equalOption(meter(name), 'FontColor', SKIN:GetVariable('TextColor'))
        check(number(meter(name):GetOption('FontSize')) == tonumber(SKIN:GetVariable('FontSize'))*scale, 'Body font role lost: '..name)
    end
    local visibleBody = tonumber(SKIN:GetVariable('RAMUseMiB')) == 1 and 'MeterRAMUsedMiB' or 'MeterRAMUsedGiB'
    for _, pair in ipairs({{'Title','MeterRAMTitle'}, {'Header','MeterRAMProcessesHeader'}, {'Body',visibleBody}}) do
        local natural = meter('MeterRAMProbe'..pair[1]):GetH()
        local allocated = meter(pair[2]):GetH()
        check(natural > 0 and natural <= allocated, pair[1]..' natural font height '..natural..' exceeds allocated '..allocated)
    end
    check(#meter('MeterRAMTitle'):GetOption('Text') > 40, 'Long-title test override lost')
    local samples = assert(SKIN:GetMeasure('MeasureRAMHistorySamples')):GetValue()
    check(samples >= 1 and samples <= number('#ContentWidth#'), 'History sample count outside plot')
    local hardware = checkHardware(true)
    local processes = checkProcesses(true)
    local page = checkPage()
    return string.format('PASS: width=%d columns=%d scale=%g bar=%g window=%dx%d unit=%s; %d checks, %d visible meters; hover/leave restored; hardware=%s; processes=%s; PAGE=%s; native Lua %s',
        width, columns, scale, thickness, expectedW, expectedH, useMiB == 1 and 'MB' or 'GB', checks, visible, hardware, processes, page, _VERSION)
end

local function checkHoverState(hovered)
    local options = meter('MeterRAMOptions')
    equalOption(options, 'Hidden', hovered and '0' or '1')
    equalOption(meter('MeterRAMPercent'), 'Hidden', hovered and '1' or '0')
    if hovered then
        equalOption(options, 'Meter', 'Shape')
        equalOption(options, 'MouseActionCursor', '1')
        local x, y, w, h = options:GetX(true), options:GetY(true), options:GetW(), options:GetH()
        local inset = number('#Inset#')
        check(w > 0 and h > 0, 'Shown gear has no native area')
        check(x >= inset and y >= inset and x + w <= SKIN:GetW() - inset and y + h <= SKIN:GetH() - inset,
            string.format('Shown gear enters gutter: %.2f,%.2f %.2fx%.2f', x, y, w, h))
    end
end

local beforeUnits, lastSamples
local utilityOpenings, utilityChecks, utilityFailed = 0, 0, false
function UtilityOpened(count)
    utilityOpenings = utilityOpenings + 1
    utilityChecks = utilityChecks + tonumber(count)
end
function UtilityVerified(count)
    utilityChecks = utilityChecks + tonumber(count)
end
function UtilityFailed() utilityFailed = true end

local function settings(command)
    SKIN:Bang('!CommandMeasure', 'MeasureRAMSettingsSmoke', command, SELF:GetOption('SettingsConfig'))
end

local function openSettings()
    local action = meter('MeterRAMOptions'):GetOption('LeftMouseUpAction', '', false)
    local expected = '[!ActivateConfig "' .. SELF:GetOption('SettingsConfig') .. '" "Settings.ini"]'
    check(action == expected, 'Gear does not open the copied dedicated settings utility')
    SKIN:Bang(action)
end

local function saved(key, expected)
    check(tonumber(SKIN:GetVariable(key)) == expected, key .. ' did not apply immediately')
    local path = SKIN:GetVariable('@') .. 'User\\RAM.inc'
    local file = assert(io.open(path, 'rb'))
    local text = assert(file:read('*a')); file:close()
    local persisted = ('\n' .. text):match('\n' .. key .. '=([^\r\n]+)')
    check(tonumber(persisted) == expected, key .. ' not persisted in the copied user file')
    check(tonumber(('\n'..text):match('\nColumns=([^\r\n]+)')) == SELF:GetNumberOption('ExpectedColumns'),
        'Utility overwrote the live meter column preference')
    check(tonumber(('\n'..text):match('\nPanelHeight=([^\r\n]+)')) == tonumber(SKIN:GetVariable('PanelHeight')),
        'Utility overwrote the live meter height preference')
    check(text:find('RAMTitle=RAM physical memory with a deliberately long clipped title', 1, true) ~= nil,
        'Saving utility preferences damaged unrelated settings')
end

local function step()
    local samples = SKIN:GetMeasure('MeasureRAMHistorySamples'):GetValue()
    check(not utilityFailed, 'Dedicated settings test failed; inspect its utility-failure.txt report')
    if lastSamples then check(samples == lastSamples + 1, 'Utility action reset or advanced history sample count') end
    lastSamples = samples
    checkPage()
    -- Execute actual production actions. Their bangs run after Lua returns.
    if ticks == 3 then
        dofile(SELF:GetOption('ModelTestsPath'))(infoModel, check)
        dofile(SELF:GetOption('ProcessModelTestsPath'))(processModel, check)
        dofile(SELF:GetOption('PageModelTestsPath'))(pageModel, check)
        checkPageController()
        checkSettingsController()
        checkProcesses()
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        if SELF:GetOption('InfoMode') == 'Timeout' then equalOption(meter('MeterRAMInfoSummary'),'Text','Checking...') end
        beforeUnits = tonumber(SKIN:GetVariable('RAMUseMiB'))
        check(utilityOpenings == 0, 'Settings utility unexpectedly active before clicking the gear')
        check(SKIN:GetMeter('MeterRAMSettingsTitle') == nil, 'Settings still overlays the live RAM skin')
        checkHoverState(false)
        SKIN:Bang(SELF:GetOption('HoverAction', '', false))
    elseif ticks == 4 then
        checkHoverState(true)
        openSettings()
    elseif ticks == 5 then
        check(utilityOpenings == 1, 'Gear failed to activate a separate settings config')
        settings("Verify('Units','RAMUseMiB',"..beforeUnits..",'"..(beforeUnits == 1 and 'MB' or 'GB').."')")
        SKIN:Bang(SELF:GetOption('LeaveAction', '', false))
        settings("Click('Units','RAMUseMiB')")
    elseif ticks == 6 then
        saved('RAMUseMiB', 1-beforeUnits)
        checkHoverState(false)
        settings("Verify('Units','RAMUseMiB',"..(1-beforeUnits)..",'"..(beforeUnits == 1 and 'GB' or 'MB').."')")
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        checkProcesses()
        settings("Click('Decimals','RAMDecimals')")
    elseif ticks == 7 then
        saved('RAMDecimals', 0)
        settings("Verify('Decimals','RAMDecimals',0,'0')")
        equalOption(meter('MeterRAMUsedGiB'), 'NumOfDecimals', '0')
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        checkProcesses()
        settings("Click('PercentDecimals','RAMPercentDecimals')")
    elseif ticks == 8 then
        saved('RAMPercentDecimals', 0)
        settings("Verify('PercentDecimals','RAMPercentDecimals',0,'0')")
        equalOption(meter('MeterRAMPercent'), 'NumOfDecimals', '0')
        settings("Click('Bar','RAMShowBar')")
    elseif ticks == 9 then
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware(true) end
        checkProcesses(true)
        saved('RAMShowBar', 0)
        settings("Verify('Bar','RAMShowBar',0,'Off')")
        equalOption(meter('MeterRAMBar'), 'Hidden', '1')
        saved('RAMShowPageBar', 1)
        settings("Click('PageBar','RAMShowPageBar')")
    elseif ticks == 10 then
        saved('RAMShowPageBar', 0)
        settings("Verify('PageBar','RAMShowPageBar',0,'Off')")
        equalOption(meter('MeterRAMPageBar'), 'Hidden', '1')
        equalOption(meter('MeterRAMBar'), 'Hidden', '1')
        settings("Click('Bar','RAMShowBar')")
    elseif ticks == 11 then
        saved('RAMShowBar', 1)
        settings("Verify('Bar','RAMShowBar',1,'On')")
        equalOption(meter('MeterRAMBar'), 'Hidden', '0')
        equalOption(meter('MeterRAMPageBar'), 'Hidden', '1')
        settings("Click('History','RAMShowHistory')")
    elseif ticks == 12 then
        saved('RAMShowHistory', 0)
        settings("Verify('History','RAMShowHistory',0,'Off')")
        for _,suffix in ipairs({'', 'Label', 'Range', 'Uncollected', 'Frame'}) do
            equalOption(meter('MeterRAMHistory'..suffix), 'Hidden', '1')
        end
        settings("Click('History','RAMShowHistory')")
        settings("Click('PageBar','RAMShowPageBar')")
    elseif ticks == 13 then
        saved('RAMShowHistory', 1)
        settings("Verify('History','RAMShowHistory',1,'On')")
        equalOption(meter('MeterRAMHistory'), 'Hidden', '0')
        saved('RAMShowPageBar', 1)
        settings("Verify('PageBar','RAMShowPageBar',1,'On')")
        settings('Close()')
    elseif ticks == 14 then
        checkHoverState(false)
        SKIN:Bang(SELF:GetOption('HoverAction', '', false))
        openSettings()
    elseif ticks == 15 then
        check(utilityOpenings == 2, 'Settings did not close independently and initialize again on reopen')
        settings("Verify('Units','RAMUseMiB',"..(1-beforeUnits)..",'"..(beforeUnits == 1 and 'GB' or 'MB').."')")
        settings("Verify('Decimals','RAMDecimals',0,'0')")
        settings("Verify('PercentDecimals','RAMPercentDecimals',0,'0')")
        settings("Verify('Bar','RAMShowBar',1,'On')")
        settings("Verify('PageBar','RAMShowPageBar',1,'On')")
        settings("Verify('History','RAMShowHistory',1,'On')")
        settings('Close()')
    elseif ticks == 16 then
        checkHoverState(true)
        SKIN:Bang(SELF:GetOption('LeaveAction', '', false))
    elseif ticks == 17 then
        checkHoverState(false)
    elseif ticks == 20 then
        check(utilityChecks > 100, 'Dedicated settings geometry or preference checks did not complete')
        return run() .. string.format('; separate utility opened/closed twice, reopened preferences persisted, %d utility checks', utilityChecks)
    end
end

function Initialize()
    infoModel = dofile(SKIN:GetVariable('@')..'Modules\\RAM\\InfoModel.lua')
    processModel = dofile(SKIN:GetVariable('@')..'Modules\\RAM\\ProcessModel.lua')
    pageModel = dofile(SKIN:GetVariable('@')..'Modules\\RAM\\PageFileModel.lua')
end
function Update()
    if completed then return 0 end
    ticks = ticks + 1
    -- At least two completed meter updates precede the assertions; no test-only
    -- !UpdateMeter calls can append graph samples or alter production cadence.
    if ticks < 3 then return 0 end
    local ok, result = pcall(step)
    if ok and result == nil then return 0 end
    completed = true
    local output = assert(io.open(SELF:GetOption('ResultPath'), 'wb'))
    assert(output:write((ok and result or ('FAIL: ' .. tostring(result))) .. '\n'))
    assert(output:close())
    return ok and 1 or -1
end
