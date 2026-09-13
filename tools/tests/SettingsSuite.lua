-- Run production Settings.lua with a mock SKIN; actual preset clicks never touch user files.
local suite = {}
function suite.run(sourcePath)
    local passed, calls, inputOutput, frameAvailable = 0, {}, '', true
    local vars = { ['@']='X:\\Isolated\\', Scale='1', ColumnWidth='280', Gutter='8', CornerRadius='3', AccentColor='137,190,250', MutedColor='175,175,175', DangerColor='235,55,75', MetricsInterval='1000', SensorInterval='2000', CapacityInterval='30000', VisualizerInterval='50' }
    for key, value in pairs({AccentColor2='181,161,226',TitleTextColor='220,220,220',HeaderTextColor='175,175,175',TextColor='220,220,220',BackgroundColor='15,15,15,255',BorderColor='50,50,50,255',DividerColor='50,50,50,255',TableHeaderBorderColor='50,50,50,255',TitleFontSize='10',HeaderFontSize='8',FontSize='9',BorderThickness='1',DividerThickness='1',TableHeaderBorderThickness='1',DataBarThickness='6'}) do vars[key]=value end
    local mock = {}
    function mock:GetVariable(name) return vars[name] end
    function mock:Bang(...) calls[#calls+1] = {...} end
    function mock:GetX() return 100 end
    function mock:GetY() return 200 end
    function mock:GetMeter(name)
        if name:match('Frame$') then
            if not frameAvailable then return nil end
            return { GetX=function() return 76 end, GetY=function() return 83 end, GetW=function() return 300 end, GetH=function() return 20 end }
        end
        return { GetX=function() return 226 end, GetY=function() return 84 end, GetW=function() return 300 end, GetH=function() return 18 end }
    end
    function mock:GetMeasure() return { GetStringValue=function() return inputOutput end } end
    local env = setmetatable({ SKIN=mock }, { __index=_G })
    local chunk = assert(loadfile(sourcePath))
    setfenv(chunk, env); chunk(); env.Initialize()
    local function check(value, message)
        assert(value, message); passed = passed + 1
    end
    local function reset() calls = {} end
    local function display(meter)
        for _, call in ipairs(calls) do if call[1]=='!SetOption' and call[2]==meter and call[3]=='Text' then return call[4] end end
    end
    local function editorParameter()
        for _, call in ipairs(calls) do
            if call[1]=='!SetOption' and call[2]=='MeasureSettingsInput' and call[3]=='Parameter' then return call[4] end
        end
        error('Numeric editor parameter was not supplied')
    end
    local function writes()
        local values, refresh = {}, 0
        for _, call in ipairs(calls) do
            if call[1] == '!WriteKeyValue' then
                check(call[2] == 'Variables' and call[5] == 'X:\\Isolated\\User\\Settings.inc', 'Unexpected persistence target')
                values[call[3]] = call[4]
            elseif call[1] == '!RefreshGroup' then
                check(call[2] == 'Parallax', 'Refresh escaped the suite group')
                refresh = refresh + 1
            else error('Unexpected preset command: ' .. tostring(call[1])) end
        end
        check(refresh == 1, 'Each accepted preset refreshes exactly once')
        return values
    end
    env.Update()
    check(#calls == 24, 'Display update should set summaries, profile, fields and all color hex values')
    for _, call in ipairs(calls) do check(call[1] == '!SetOption', 'Display update must not persist or refresh') end
    check(display('MeterAccentValue') == '#89BEFA' and display('MeterAccent2Value') == '#B5A1E2', 'Accent hex differs from shared RGB value')
    check(display('MeterBackgroundTransparencyInput')=='0%' and display('MeterTitleSizeInput')=='10 pt', 'Initial surface/text controls differ from settings')
    check(display('MeterTableHeaderBorderSizeInput')=='1 px' and display('MeterTableHeaderBorderColorValue')=='#323232FF', 'Initial table header border controls differ from settings')
    check(display('MeterDataBarSizeInput')=='6 px', 'Data bar default must retain the former CPU bar thickness')
    check(calls[1][4]:find('280 / 568 px', 1, true) ~= nil, 'Default geometry summary incorrect')
    vars.DataBarThickness='9.5'; reset(); env.Update()
    check(display('MeterDataBarSizeInput')=='9.5 px', 'Data bar field did not preserve decimal thickness')
    vars.DataBarThickness='6'
    for input, expected in pairs({FF0000FF='#FF0000FF',aabbcc='#AABBCC',['12,34,56,128']='#0C223880',['999,2,3']='Unavailable',['12,34,56 extra']='Unavailable',['12,34,56 78']='Unavailable',['12,34,56,']='Unavailable'}) do
        vars.AccentColor=input; reset(); env.Update(); check(display('MeterAccentValue') == expected, 'Accent format was misrepresented: '..input)
    end
    vars.AccentColor='137,190,250'
    for _, value in ipairs({'0.75','1','1.25','1.5','2'}) do
        reset(); check(env.Set('Scale',value), 'Valid scale rejected'); check(writes().Scale == value, 'Scale was not preserved')
    end
    for _, value in ipairs({'180','200','220','240','280','320'}) do
        reset(); check(env.Set('ColumnWidth',value), 'Valid width rejected'); check(writes().ColumnWidth == value, 'Width was not preserved')
    end
    for _, value in ipairs({'0','8','12','16'}) do
        reset(); check(env.Set('Gutter',value), 'Valid gap rejected'); check(writes().Gutter == value, 'Gap was not preserved')
    end
    reset()
    check(not env.Set('Scale','0') and not env.Set('Scale','1][!Quit]') and not env.Set('Password','text'), 'Invalid preset accepted')
    check(not env.Theme('unknown') and not env.Accent('unknown') and not env.Profile('unknown') and #calls == 0, 'Invalid choice caused a write')
    reset()
    for _, name in ipairs({'gadgets','slate','midnight','graphite','Default','default][!Quit]'}) do
        check(not env.Theme(name), 'Only the shipped Default theme identifier may apply')
    end
    check(#calls == 0, 'Rejected theme changed state')
    reset(); check(env.Theme('default'), 'Default theme rejected')
    local themeValues = writes()
    local defaultPath = assert(sourcePath:match('^(.*[\\/])Scripts[\\/]Settings%.lua$')) .. 'Defaults.inc'
    local defaults = {}
    for line in io.lines(defaultPath) do
        local key, value = line:match('^([%w_]+)=(.*)$')
        if key then defaults[key] = value:gsub('\r$', '') end
    end
    local expectedThemeKeys = {
        'Theme','FontFace','FontSize','PanelPadding','CornerRadius','BackgroundColor','BorderColor','TrackColor',
        'GraphBackgroundColor','GridColor','GraphHeight','TextColor','MutedColor','AccentColor','GoodColor','WarningColor',
        'DangerColor','CPUColor','RAMColor','GPUColor','DiskReadColor','DiskWriteColor','NetworkInColor','NetworkOutColor','MediaColor','ClockColor',
        'TitleFontSize','HeaderFontSize','TitleTextColor','HeaderTextColor','AccentColor2','BorderThickness','DividerColor','DividerThickness',
        'TableHeaderBorderColor','TableHeaderBorderThickness','DataBarThickness'
    }
    for _, key in ipairs(expectedThemeKeys) do
        check(themeValues[key] ~= nil and themeValues[key] == defaults[key], 'Theme drifted from shipped appearance: '..key)
    end
    local themeCount = 0
    for _ in pairs(themeValues) do themeCount = themeCount + 1 end
    check(themeCount == #expectedThemeKeys, 'Theme wrote settings outside the appearance contract')
    check(not themeValues.Scale and not themeValues.ColumnWidth and not themeValues.Gutter and not themeValues.MetricsInterval, 'Theme changed layout size or polling')

    local function menuCommand(command)
        check(#calls == 3, 'A menu transition must only update visibility and redraw')
        check(calls[1][1] == command and calls[1][2] == 'ThemeMenu', 'Wrong popup visibility/group')
        check(calls[2][1] == '!UpdateMeterGroup' and calls[2][2] == 'ThemeMenu' and calls[3][1] == '!Redraw', 'Popup was not redrawn')
    end
    reset(); env.CloseThemeMenu(); check(#calls == 0, 'Already-closed menu should be idle')
    reset(); env.ToggleThemeMenu(); menuCommand('!ShowMeterGroup')
    reset(); env.ToggleThemeMenu(); menuCommand('!HideMeterGroup')
    reset(); env.ToggleThemeMenu(); menuCommand('!ShowMeterGroup')
    reset(); env.CloseThemeMenu(); menuCommand('!HideMeterGroup')
    reset(); env.CloseThemeMenu(); check(#calls == 0, 'Repeated dismissal should be idle')

    for _, key in ipairs({'AccentColor','AccentColor2','TitleTextColor','HeaderTextColor','TextColor','BackgroundColor','BorderColor','DividerColor','TableHeaderBorderColor'}) do
        reset(); check(env.OpenColor(key), 'Valid color target rejected: '..key)
        check(#calls==2 and calls[1][1]=='!ActivateConfig' and calls[1][2]=='Parallax\\ColorPicker' and calls[1][3]=='ColorPicker.ini','Picker activation differs')
        check(calls[2][1]=='!CommandMeasure' and calls[2][2]=='MeasureColorPicker' and calls[2][3]=="OpenTarget('"..key.."')" and calls[2][4]=='Parallax\\ColorPicker','Picker must receive exact allowlisted key/config')
    end
    for _, key in ipairs({'Unknown','AccentColor2][!Quit]',"TextColor');os.execute('bad')",'backgroundcolor','TableHeaderBorderColor][!Quit]','tableheaderbordercolor'}) do
        reset(); check(not env.OpenColor(key) and #calls==0,'Untrusted color target executed')
    end
    for key, value in pairs({TitleFontSize='11.25',HeaderFontSize='9.5',FontSize='9.75',BorderThickness='2.5',DividerThickness='0',TableHeaderBorderThickness='0.25',DataBarThickness='8.75'}) do
        reset(); check(env.Set(key,value),'Valid text/surface size rejected'); check(writes()[key]==value,'Text/surface value changed')
    end
    for _, item in ipairs({{'TitleFontSize','12.01'},{'HeaderFontSize','10.1'},{'FontSize','5.99'},{'FontSize','9.123'},{'BorderThickness','4.01'},{'DividerThickness','0.001'},{'TableHeaderBorderThickness','4.01'},{'TableHeaderBorderThickness','-0.01'},{'TableHeaderBorderThickness','0.001'},{'DataBarThickness','0'},{'DataBarThickness','0.99'},{'DataBarThickness','12.01'},{'DataBarThickness','6.001'},{'DataBarThickness','6 px'}}) do
        reset(); check(not env.Set(item[1],item[2]) and #calls==0,'Out-of-range/overprecise text/surface value saved')
    end
    for _, value in ipairs({'0','4','1.75'}) do
        reset(); check(env.Set('TableHeaderBorderThickness',value),'Valid table header border thickness rejected')
        local saved=writes()
        check(saved.TableHeaderBorderThickness==value and not saved.DividerThickness and not saved.BorderThickness and not saved.TableHeaderBorderColor,
            'Table header border thickness must persist independently of divider, panel border and color')
    end
    reset(); check(env.Set('DividerThickness','2.5'),'Valid divider thickness rejected')
    check(not writes().TableHeaderBorderThickness,'Divider thickness changed table header border thickness')
    for _, value in ipairs({'1','6','12','1.25'}) do
        reset(); check(env.Set('DataBarThickness',value),'Valid data bar thickness rejected')
        local saved=writes()
        check(saved.DataBarThickness==value and not saved.DividerThickness and not saved.BorderThickness and not saved.TableHeaderBorderThickness and not saved.TrackColor and not saved.GraphHeight,
            'Data bar thickness must persist independently of line styling, track color and graph height')
    end
    for _, item in ipairs({{'15,15,15,255','25','15,15,15,191'},{'#11223380','50','17,34,51,128'},{'17,34,51','100','17,34,51,0'},{'17,34,51,0','0','17,34,51,255'}}) do
        vars.BackgroundColor=item[1]; reset(); check(env.Set('BackgroundTransparency',item[2]),'Valid transparency rejected')
        local saved=writes(); check(saved.BackgroundColor==item[3] and not saved.BackgroundTransparency,'Transparency must preserveRGB and storealpha in existing color')
    end
    vars.BackgroundColor='bad'; reset(); check(not env.Set('BackgroundTransparency','50') and not env.BeginEdit('BackgroundTransparency') and #calls==0,'Malformed background color should not be overwritten')
    vars.BackgroundColor='15,15,15,255'

    -- Exercise arrow behavior against public settings values, without launching
    -- the numeric editor or allowing a step to write an unrelated preference.
    local function adjusted(key, current, direction, expected)
        local stored = key == 'BackgroundTransparency' and 'BackgroundColor' or key
        local original = vars[stored]
        vars[stored] = current
        reset()
        check(env.Adjust(key, direction), 'Valid arrow step rejected: '..key)
        local values = writes()
        local count = 0
        for savedKey in pairs(values) do
            count = count + 1
            check(savedKey == stored, 'Arrow changed an unrelated preference: '..savedKey)
        end
        check(count == 1 and values[stored] == expected, 'Arrow step/precision differs: '..key)
        vars[stored] = original
    end
    local function idleAdjustment(key, current, direction)
        local stored = key == 'BackgroundTransparency' and 'BackgroundColor' or key
        local original = vars[stored]
        vars[stored] = current
        reset()
        check(not env.Adjust(key, direction) and #calls == 0, 'Rejected/bound arrow caused an action: '..tostring(key))
        vars[stored] = original
    end
    local arrowCases = {
        {'Scale','1','0.99','1.01','0.75','2','0.76','1.99'},
        {'ColumnWidth','237','236','238','180','320','181','319'},
        {'Gutter','8','7','9','0','16','1','15'},
        {'CornerRadius','12','11','13','0','24','1','23'},
        {'TitleFontSize','10','9.75','10.25','6','12','6.25','11.75'},
        {'HeaderFontSize','8','7.75','8.25','6','10','6.25','9.75'},
        {'FontSize','9','8.75','9.25','6','10','6.25','9.75'},
        {'BorderThickness','1','0.75','1.25','0','4','0.25','3.75'},
        {'DividerThickness','1','0.75','1.25','0','4','0.25','3.75'},
        {'TableHeaderBorderThickness','1','0.75','1.25','0','4','0.25','3.75'},
        {'DataBarThickness','6','5.75','6.25','1','12','1.25','11.75'},
    }
    for _, item in ipairs(arrowCases) do
        local key = item[1]
        adjusted(key,item[2],-1,item[3]); adjusted(key,item[2],1,item[4])
        idleAdjustment(key,item[5],-1); idleAdjustment(key,item[6],1)
        adjusted(key,item[5],1,item[7]); adjusted(key,item[6],-1,item[8])
        for _, direction in ipairs({0,2,-2,0.5,-0.5,'1','-1','1][!Quit]',true,false,math.huge,-math.huge,0/0}) do
            idleAdjustment(key,item[2],direction)
        end
        idleAdjustment(key,item[2],nil)
        for _, current in ipairs({'bad','1][!Quit]','nan','inf','-1','9999999999999999'}) do
            idleAdjustment(key,current,1)
        end
        idleAdjustment(key,nil,1)
    end
    for _, item in ipairs({
        {'Scale','0.7501',-1,'0.75'}, {'Scale','1.9999',1,'2'},
        {'Scale','1.1234',1,'1.1334'}, {'Scale','1.1234',-1,'1.1134'},
        {'TitleFontSize','11.9',1,'12'}, {'TitleFontSize','6.1',-1,'6'},
        {'FontSize','9.13',1,'9.38'}, {'HeaderFontSize','8.13',-1,'7.88'},
        {'BorderThickness','0.1',-1,'0'}, {'DividerThickness','3.9',1,'4'},
        {'TableHeaderBorderThickness','2.13',1,'2.38'},
        {'DataBarThickness','1.01',-1,'1'}, {'DataBarThickness','11.99',1,'12'},
        {'DataBarThickness','6.01',1,'6.26'},
    }) do adjusted(item[1],item[2],item[3],item[4]) end
    for _, item in ipairs({{'ColumnWidth','237.5'},{'Gutter','3.5'},{'CornerRadius','12.5'},
        {'TitleFontSize','10.001'},{'HeaderFontSize','8.001'},{'FontSize','9.001'},
        {'BorderThickness','1.001'},{'DividerThickness','1.001'},{'TableHeaderBorderThickness','1.001'},{'DataBarThickness','6.001'}}) do
        idleAdjustment(item[1],item[2],1)
    end
    adjusted('BackgroundTransparency','17,34,51,255',1,'17,34,51,252')
    adjusted('BackgroundTransparency','#11223380',1,'17,34,51,125')
    adjusted('BackgroundTransparency','17,34,51,128',-1,'17,34,51,131')
    adjusted('BackgroundTransparency','17,34,51,1',1,'17,34,51,0')
    adjusted('BackgroundTransparency','17,34,51,254',-1,'17,34,51,255')
    idleAdjustment('BackgroundTransparency','17,34,51,255',-1)
    idleAdjustment('BackgroundTransparency','17,34,51,0',1)
    idleAdjustment('BackgroundTransparency','malformed',1)
    idleAdjustment('BackgroundTransparency','17,34,51,128','1')
    for _, key in ipairs({'Unknown','scale','Scale][!Quit]',"FontSize');os.execute('bad')",'AccentColor'}) do
        reset(); check(not env.Adjust(key,1) and #calls == 0, 'Untrusted arrow key caused execution')
    end
    reset(); check(not env.Adjust(nil,1) and #calls == 0, 'Missing arrow key caused execution')

    -- Default is the only theme; stepping must neither reapply it nor disturb
    -- the dropdown, even if the last recorded theme is an unknown identifier.
    for _, recorded in ipairs({'default','unknown'}) do
        vars.Theme = recorded
        for _, direction in ipairs({-1,1,0,2,'1',false}) do
            reset(); check(not env.CycleTheme(direction) and #calls == 0, 'Single-theme arrow should be an idle no-op')
        end
        reset(); check(not env.CycleTheme(nil) and #calls == 0, 'Missing theme direction caused an action')
    end
    vars.Theme='default'
    reset(); env.ToggleThemeMenu(); menuCommand('!ShowMeterGroup')
    reset(); check(not env.CycleTheme(1) and #calls == 0, 'Theme arrow disturbed the open dropdown')
    reset(); env.CloseThemeMenu(); menuCommand('!HideMeterGroup')

    for key, value in pairs({Scale='1.125',ColumnWidth='237',Gutter='3',CornerRadius='12'}) do
        reset(); check(env.Set(key,value), 'Custom in-range numeric value rejected'); check(writes()[key] == value, 'Custom numeric value changed')
    end
    for key, value in pairs({Scale='2.01',ColumnWidth='179',Gutter='2.5',CornerRadius='25'}) do
        reset(); check(not env.Set(key,value) and #calls == 0, 'Invalid layout range/precision was saved')
    end
    reset(); check(not env.BeginEdit('Password') and #calls == 0, 'Unknown editor key launched a helper')
    reset(); check(env.BeginEdit('Scale'), 'Editor did not start')
    check(calls[#calls][1] == '!CommandMeasure' and calls[#calls][2] == 'MeasureSettingsInput' and calls[#calls][3] == 'Run', 'Editor must launch only its own fixed measure')
    check(editorParameter():find(' -X 176 -Y 283 -Width 300 -Height 20 ',1,true) ~= nil, 'Editor must anchor to the outlined frame rather than centered value text')
    local before = #calls
    check(not env.BeginEdit('Gutter') and #calls == before, 'Second editor launched before first finished')
    check(not env.OpenColor('TextColor') and #calls==before,'Color picker opened while numeric edit was pending')
    for _, item in ipairs(arrowCases) do
        for _, direction in ipairs({-1,1}) do
            check(not env.Adjust(item[1],direction) and #calls == before, 'Arrow changed settings while numeric editing was pending')
        end
    end
    check(not env.Adjust('BackgroundTransparency',1) and #calls == before, 'Transparency arrow changed a pending edit')
    check(not env.CycleTheme(1) and #calls == before, 'Theme arrow changed a pending edit')
    check(not env.CycleProfile(1) and not env.CycleProfile(-1) and not env.Profile('economy') and #calls == before, 'Profile changed a pending edit')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|113.5\r\n'
    check(env.CommitInput(), 'Valid helper result rejected'); check(writes().Scale == '1.135', 'Percent-to-factor conversion failed')
    reset(); check(not env.CommitInput() and #calls == 0, 'Old result was replayed without an edit')
    frameAvailable=false
    reset(); check(env.BeginEdit('Gutter'), 'Editor must retain fallback when the frame is unavailable')
    check(editorParameter():find(' -X 326 -Y 284 -Width 300 -Height 20 ',1,true) ~= nil, 'Missing frame did not fall back to the original input meter')
    frameAvailable=true
    reset(); inputOutput='PARALLAX_INPUT_V1|cancel|'
    check(not env.CommitInput() and #calls==0, 'Cancelling fallback editor changed settings')
    for _, output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|999','PARALLAX_INPUT_V1|ok|1][!Quit]','PARALLAX_INPUT_V1|ok|[&Measure:Run()]','PARALLAX_INPUT_V1|ok|nan','PARALLAX_INPUT_V1|ok|3\nextra'}) do
        reset(); check(env.BeginEdit('CornerRadius'), 'Editor did not reset after completion')
        reset(); inputOutput=output
        check(not env.CommitInput(), 'Invalid/cancelled helper result applied')
        for _, call in ipairs(calls) do check(call[1] ~= '!WriteKeyValue' and call[1] ~= '!RefreshGroup' and call[1] ~= '!CommandMeasure', 'Invalid input reached persistence or execution') end
    end
    reset(); check(env.BeginEdit('CornerRadius'), 'Rounding editor did not start')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|16'
    check(env.CommitInput(), 'Rounding was rejected'); check(writes().CornerRadius == '16', 'Rounding did not save to shared style variable')
    reset(); check(env.BeginEdit('TableHeaderBorderThickness'),'Table header border editor did not start')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|0.25\r\n'
    check(env.CommitInput(),'Table header border helper result rejected')
    local savedHeaderBorder=writes()
    check(savedHeaderBorder.TableHeaderBorderThickness=='0.25' and not savedHeaderBorder.DividerThickness and not savedHeaderBorder.BorderThickness,
        'Table header border helper result changed another stroke')
    for _, output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|4.01','PARALLAX_INPUT_V1|ok|0.001','PARALLAX_INPUT_V1|ok|0.5][!Quit]'}) do
        reset(); check(env.BeginEdit('TableHeaderBorderThickness'),'Table header border editor did not reset')
        reset(); inputOutput=output
        check(not env.CommitInput(),'Invalid/cancelled table header border input applied')
        for _, call in ipairs(calls) do check(call[1]~='!WriteKeyValue' and call[1]~='!RefreshGroup' and call[1]~='!CommandMeasure','Rejected table header border input reached persistence or execution') end
    end
    reset(); check(env.BeginEdit('DataBarThickness'),'Data bar editor did not start')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|8.75\r\n'
    check(env.CommitInput(),'Data bar helper result rejected')
    local savedDataBar=writes()
    check(savedDataBar.DataBarThickness=='8.75' and not savedDataBar.DividerThickness and not savedDataBar.BorderThickness and not savedDataBar.TableHeaderBorderThickness,
        'Data bar helper result changed another thickness')
    for _, output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|0','PARALLAX_INPUT_V1|ok|12.01','PARALLAX_INPUT_V1|ok|6.001','PARALLAX_INPUT_V1|ok|6][!Quit]'}) do
        reset(); check(env.BeginEdit('DataBarThickness'),'Data bar editor did not reset')
        reset(); inputOutput=output
        check(not env.CommitInput(),'Invalid/cancelled data bar input applied')
        for _, call in ipairs(calls) do check(call[1]~='!WriteKeyValue' and call[1]~='!RefreshGroup' and call[1]~='!CommandMeasure','Rejected data bar input reached persistence or execution') end
    end
    for _, name in ipairs({'cyan','amber','lilac','green'}) do
        reset(); check(env.Accent(name), 'Accent rejected'); local values = writes()
        check(values.AccentColor and not values.BackgroundColor, 'Accent changed surface')
    end
    reset(); env.Profile('economy'); local values = writes()
    check(values.MetricsInterval=='2000' and values.SensorInterval=='4000' and values.CapacityInterval=='60000' and values.VisualizerInterval=='100', 'Economy cadence incorrect')
    reset(); env.Profile('balanced'); values = writes()
    check(values.MetricsInterval=='1000' and values.SensorInterval=='2000' and values.CapacityInterval=='30000' and values.VisualizerInterval=='50', 'Balanced cadence incorrect')
    local cadenceKeys = {'MetricsInterval','SensorInterval','CapacityInterval','VisualizerInterval'}
    local cadences = {balanced={'1000','2000','30000','50'}, economy={'2000','4000','60000','100'}}
    for _, current in ipairs({'balanced','economy','custom'}) do
        for index, key in ipairs(cadenceKeys) do vars[key] = (cadences[current] or cadences.balanced)[index] end
        if current == 'custom' then vars.SensorInterval='3000' end
        reset(); env.Update()
        check(display('MeterRefreshValue') == (current == 'balanced' and 'Balanced' or current == 'economy' and 'Economy' or 'Custom'), 'Refresh choice misrepresents saved intervals')
        for _, call in ipairs(calls) do check(call[1] == '!SetOption', 'Reading a custom profile mutated settings') end
        for _, direction in ipairs({-1,1}) do
            reset(); check(env.CycleProfile(direction), 'Valid profile direction rejected')
            local saved = writes()
            local target = current == 'balanced' and 'economy' or current == 'economy' and 'balanced' or (direction == -1 and 'economy' or 'balanced')
            local count = 0
            for key in pairs(saved) do count = count + 1 end
            check(count == 4, 'Profile cycle changed keys outside the four cadence settings')
            for index, key in ipairs(cadenceKeys) do check(saved[key] == cadences[target][index], 'Profile cycle failed wrap/custom selection') end
        end
    end
    for _, direction in ipairs({0,2,'1',false}) do
        reset(); check(not env.CycleProfile(direction) and #calls == 0, 'Invalid profile direction caused an action')
    end
    reset(); check(not env.CycleProfile(nil) and #calls == 0, 'Missing profile direction caused an action')
    return passed
end
return suite
