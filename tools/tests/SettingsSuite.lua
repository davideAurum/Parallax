-- Run production Settings.lua with a mock SKIN; actual preset clicks never touch user files.
local suite = {}
function suite.run(sourcePath)
    local passed, calls, inputOutput = 0, {}, ''
    local vars = { ['@']='X:\\Isolated\\', Scale='1', ColumnWidth='280', Gutter='8', CornerRadius='3', AccentColor='137,190,250', MutedColor='175,175,175', DangerColor='235,55,75', MetricsInterval='1000', SensorInterval='2000', CapacityInterval='30000', VisualizerInterval='50' }
    for key, value in pairs({AccentColor2='181,161,226',TitleTextColor='220,220,220',HeaderTextColor='175,175,175',TextColor='220,220,220',BackgroundColor='15,15,15,255',BorderColor='50,50,50,255',DividerColor='50,50,50,255',TitleFontSize='10',HeaderFontSize='8',FontSize='9',BorderThickness='1',DividerThickness='1'}) do vars[key]=value end
    local mock = {}
    function mock:GetVariable(name) return vars[name] end
    function mock:Bang(...) calls[#calls+1] = {...} end
    function mock:GetX() return 100 end
    function mock:GetY() return 200 end
    function mock:GetMeter() return { GetX=function() return 76 end, GetY=function() return 83 end, GetW=function() return 300 end, GetH=function() return 20 end } end
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
    check(#calls == 20, 'Display update should set summaries, fields and all color hex values')
    for _, call in ipairs(calls) do check(call[1] == '!SetOption', 'Display update must not persist or refresh') end
    check(display('MeterAccentValue') == '#89BEFA' and display('MeterAccent2Value') == '#B5A1E2', 'Accent hex differs from shared RGB value')
    check(display('MeterBackgroundTransparencyInput')=='0%' and display('MeterTitleSizeInput')=='10 pt', 'Initial surface/text controls differ from settings')
    check(calls[1][4]:find('280 / 568 px', 1, true) ~= nil, 'Default geometry summary incorrect')
    for input, expected in pairs({FF0000FF='#FF0000FF',aabbcc='#AABBCC',['12,34,56,128']='#0C223880',['999,2,3']='Unavailable',['12,34,56 extra']='Unavailable',['12,34,56 78']='Unavailable',['12,34,56,']='Unavailable'}) do
        vars.AccentColor=input; reset(); env.Update(); check(display('MeterAccentValue') == expected, 'Accent format was misrepresented: '..input)
    end
    vars.AccentColor='137,190,250'
    for _, value in ipairs({'0.75','1','1.25','1.5','2'}) do
        reset(); check(env.Set('Scale',value), 'Valid scale rejected'); check(writes().Scale == value, 'Scale was not preserved')
    end
    for _, value in ipairs({'180','200','240','280','320'}) do
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
        'TitleFontSize','HeaderFontSize','TitleTextColor','HeaderTextColor','AccentColor2','BorderThickness','DividerColor','DividerThickness'
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

    for _, key in ipairs({'AccentColor','AccentColor2','TitleTextColor','HeaderTextColor','TextColor','BackgroundColor','BorderColor','DividerColor'}) do
        reset(); check(env.OpenColor(key), 'Valid color target rejected: '..key)
        check(#calls==2 and calls[1][1]=='!ActivateConfig' and calls[1][2]=='Parallax\\ColorPicker' and calls[1][3]=='ColorPicker.ini','Picker activation differs')
        check(calls[2][1]=='!CommandMeasure' and calls[2][2]=='MeasureColorPicker' and calls[2][3]=="OpenTarget('"..key.."')" and calls[2][4]=='Parallax\\ColorPicker','Picker must receive exact allowlisted key/config')
    end
    for _, key in ipairs({'Unknown','AccentColor2][!Quit]',"TextColor');os.execute('bad')",'backgroundcolor'}) do
        reset(); check(not env.OpenColor(key) and #calls==0,'Untrusted color target executed')
    end
    for key, value in pairs({TitleFontSize='11.25',HeaderFontSize='9.5',FontSize='9.75',BorderThickness='2.5',DividerThickness='0'}) do
        reset(); check(env.Set(key,value),'Valid text/surface size rejected'); check(writes()[key]==value,'Text/surface value changed')
    end
    for _, item in ipairs({{'TitleFontSize','12.01'},{'HeaderFontSize','10.1'},{'FontSize','5.99'},{'FontSize','9.123'},{'BorderThickness','4.01'},{'DividerThickness','0.001'}}) do
        reset(); check(not env.Set(item[1],item[2]) and #calls==0,'Out-of-range/overprecise text/surface value saved')
    end
    for _, item in ipairs({{'15,15,15,255','25','15,15,15,191'},{'#11223380','50','17,34,51,128'},{'17,34,51','100','17,34,51,0'},{'17,34,51,0','0','17,34,51,255'}}) do
        vars.BackgroundColor=item[1]; reset(); check(env.Set('BackgroundTransparency',item[2]),'Valid transparency rejected')
        local saved=writes(); check(saved.BackgroundColor==item[3] and not saved.BackgroundTransparency,'Transparency must preserveRGB and storealpha in existing color')
    end
    vars.BackgroundColor='bad'; reset(); check(not env.Set('BackgroundTransparency','50') and not env.BeginEdit('BackgroundTransparency') and #calls==0,'Malformed background color should not be overwritten')
    vars.BackgroundColor='15,15,15,255'

    for key, value in pairs({Scale='1.125',ColumnWidth='237',Gutter='3',CornerRadius='12'}) do
        reset(); check(env.Set(key,value), 'Custom in-range numeric value rejected'); check(writes()[key] == value, 'Custom numeric value changed')
    end
    for key, value in pairs({Scale='2.01',ColumnWidth='179',Gutter='2.5',CornerRadius='25'}) do
        reset(); check(not env.Set(key,value) and #calls == 0, 'Invalid layout range/precision was saved')
    end
    reset(); check(not env.BeginEdit('Password') and #calls == 0, 'Unknown editor key launched a helper')
    reset(); check(env.BeginEdit('Scale'), 'Editor did not start')
    check(calls[#calls][1] == '!CommandMeasure' and calls[#calls][2] == 'MeasureSettingsInput' and calls[#calls][3] == 'Run', 'Editor must launch only its own fixed measure')
    local before = #calls
    check(not env.BeginEdit('Gutter') and #calls == before, 'Second editor launched before first finished')
    check(not env.OpenColor('TextColor') and #calls==before,'Color picker opened while numeric edit was pending')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|113.5\r\n'
    check(env.CommitInput(), 'Valid helper result rejected'); check(writes().Scale == '1.135', 'Percent-to-factor conversion failed')
    reset(); check(not env.CommitInput() and #calls == 0, 'Old result was replayed without an edit')
    for _, output in ipairs({'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|999','PARALLAX_INPUT_V1|ok|1][!Quit]','PARALLAX_INPUT_V1|ok|[&Measure:Run()]','PARALLAX_INPUT_V1|ok|nan','PARALLAX_INPUT_V1|ok|3\nextra'}) do
        reset(); check(env.BeginEdit('CornerRadius'), 'Editor did not reset after completion')
        reset(); inputOutput=output
        check(not env.CommitInput(), 'Invalid/cancelled helper result applied')
        for _, call in ipairs(calls) do check(call[1] ~= '!WriteKeyValue' and call[1] ~= '!RefreshGroup' and call[1] ~= '!CommandMeasure', 'Invalid input reached persistence or execution') end
    end
    reset(); check(env.BeginEdit('CornerRadius'), 'Rounding editor did not start')
    reset(); inputOutput='PARALLAX_INPUT_V1|ok|16'
    check(env.CommitInput(), 'Rounding was rejected'); check(writes().CornerRadius == '16', 'Rounding did not save to shared style variable')
    for _, name in ipairs({'cyan','amber','lilac','green'}) do
        reset(); check(env.Accent(name), 'Accent rejected'); local values = writes()
        check(values.AccentColor and not values.BackgroundColor, 'Accent changed surface')
    end
    reset(); env.Profile('economy'); local values = writes()
    check(values.MetricsInterval=='2000' and values.SensorInterval=='4000' and values.CapacityInterval=='60000' and values.VisualizerInterval=='100', 'Economy cadence incorrect')
    reset(); env.Profile('balanced'); values = writes()
    check(values.MetricsInterval=='1000' and values.SensorInterval=='2000' and values.CapacityInterval=='30000' and values.VisualizerInterval=='50', 'Balanced cadence incorrect')
    return passed
end
return suite
