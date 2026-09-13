-- Isolated native Settings layout, glyph and action instrumentation only.
local ticks, completed, probeError = 0, false
local prefix, probes, meterNames = 'MeterNetworkSettings', {}, {}
local fontOptions = {FontFace='Arial', FontSize='10', FontWeight='400',
    StringStyle='Normal', StringCase='None', CharacterSpacing='0'}
local fields = {Adapter=101, Units=129, Width=157, Height=185, InCeiling=242,
    OutCeiling=270, WiFiEnabled=355, WiFiIndex=383}
local numeric = {Width='Columns',Height='PanelHeight',InCeiling='NetworkInCeilingMbps',
    OutCeiling='NetworkOutCeilingMbps',WiFiIndex='NetworkWiFiInterface'}

local function read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local value = file:read('*a'); file:close(); return value
end
local function write(path, value)
    local file = assert(io.open(path, 'wb')); file:write(value); file:close()
end
local function meter(name)
    local target=assert(SKIN:GetMeter(name), 'Missing native meter: ' .. name)
    meterNames[target]=name
    return target
end
local function number(value)
    return assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(value) .. ')'), 'Invalid numeric formula: ' .. value)
end
local function variable(key) return number(SKIN:GetVariable(key)) end
local function option(target, key) return number(target:GetOption(key)) end
local function bounds(target, width, height)
    local x, y, w, h = target:GetX(false), target:GetY(false), target:GetW(), target:GetH()
    assert(x >= 0 and y >= 0 and x + w <= width and y + h <= height,
        string.format('%s escapes native window: %g,%g %gx%g / %gx%g', meterNames[target], x,y,w,h,width,height))
end

function Initialize()
    local countFile = SELF:GetOption('CountFile', '')
    if countFile ~= '' then write(countFile, tostring((tonumber(read(countFile)) or 0) + 1)) end
end

local function prepareGlyphs()
    for index = 1, SELF:GetNumberOption('GlyphCount') do
        local target = meter(SELF:GetOption('GlyphTarget' .. index))
        local probe = meter(prefix .. 'Glyph' .. index)
        probes[#probes + 1] = {target=target, probe=probe, width=SELF:GetNumberOption('GlyphWidth' .. index) == 1}
        for key, default in pairs(fontOptions) do SKIN:Bang('!SetOption', meterNames[probe], key, target:GetOption(key, default)) end
        if SELF:GetNumberOption('GlyphLive' .. index) == 1 then SKIN:Bang('!SetOption', meterNames[probe], 'Text', target:GetOption('Text')) end
    end
end

local function glyphChecks()
    assert(not probeError, probeError)
    local failures = {}
    for _, spec in ipairs(probes) do
        local probe, target = spec.probe, spec.target
        for key, default in pairs(fontOptions) do
            assert(probe:GetOption(key, default) == target:GetOption(key, default), 'Probe font differs: ' .. key)
        end
        assert(probe:GetOption('W', '') == '' and probe:GetOption('H', '') == '' and probe:GetOption('ClipString') == '0',
            'Glyph probe must retain intrinsic unclipped bounds')
        probe:Show(); local w,h = probe:GetW(),probe:GetH(); probe:Hide()
        local padding = {}
        for value in target:GetOption('Padding', '0,0,0,0'):gmatch('[^,]+') do padding[#padding+1]=math.floor(number(value)) end
        local aw,ah=target:GetW()-padding[1]-padding[3],target:GetH()-padding[2]-padding[4]
        if w <= 0 or h <= 0 or (spec.width and w > aw) or h > ah then
            failures[#failures+1]=string.format('%s:%s=%dx%d/%dx%d',meterNames[target],probe:GetOption('Text'),w,h,aw,ah)
        end
    end
    assert(#failures == 0, 'Intrinsic glyph fit: ' .. table.concat(failures, '; '))
    return #probes
end

local function layout()
    local scale, cw = variable('Scale'),variable('ColumnWidth')
    assert(scale == SELF:GetNumberOption('ExpectedScale') and cw == SELF:GetNumberOption('ExpectedColumnWidth'), 'Fixture dimensions differ')
    assert(variable('Columns') == 2 and variable('PanelHeight') == 598, 'Independent settings geometry changed')
    assert(variable('BorderThickness') == 4 and variable('DividerThickness') == 4
        and variable('TableHeaderBorderThickness') == 0 and variable('DataBarThickness') == 12, 'Surface fixture changed')
    local maximum=SELF:GetOption('Typography')=='maximum'
    assert(variable('FontSize') == (maximum and 10 or 9) and variable('TitleFontSize') == (maximum and 12 or 10)
        and variable('HeaderFontSize') == (maximum and 10 or 8), 'Typography fixture differs')
    local gap=2*math.floor(variable('Gutter')*scale/2+0.5)
    local expectedW=2*(math.floor(cw*scale+0.5)+gap)
    local expectedH=math.floor(variable('PanelHeight')*scale+0.5)+gap
    assert(SKIN:GetW()==expectedW and SKIN:GetH()==expectedH, 'Native settings window dimensions differ')
    for index=1,SELF:GetNumberOption('MeterCount') do bounds(meter(SELF:GetOption('MeterName'..index)),expectedW,expectedH) end
    local title,close=meter(prefix..'Title'),meter(prefix..'Close')
    for _,target in ipairs({title,close}) do
        assert(math.abs(option(target,'Y')-variable('TitleRowCenterY'))<0.001, 'Header does not use shared center')
        assert(math.abs(target:GetY(false)+target:GetH()/2-variable('TitleRowCenterY'))<=1, 'Native header center differs')
    end
    assert(title:GetX(false)+title:GetW() <= close:GetX(false), 'Title overlaps close control')
    assert(option(title,'FontSize')==variable('TitleFontSize')*scale, 'Title typography bypassed')
    local note=meter('MeterUtilitySettingsNote')
    assert(title:GetY(false)+title:GetH() <= note:GetY(false), 'Title overlaps shared note')
    assert(meter('MeterUtilitySettingsGlobalLink'):GetY(false)+meter('MeterUtilitySettingsGlobalLink'):GetH()
        <= meter(prefix..'TrafficSection'):GetY(false), 'Shared note overlaps first section')
    for field,rowY in pairs(fields) do
        local row,label,value=meter(prefix..field..'Row'),meter(prefix..field..'Label'),meter(prefix..field..'Value')
        assert(math.abs(option(row,'Y')-variable('Inset')-rowY*scale)<0.001 and option(row,'H')==20*scale, field..' field geometry differs')
        assert(math.abs(option(row,'X')-variable('ContentX')-150*scale)<0.001
            and math.abs(option(row,'W')-variable('ContentWidth')+150*scale)<0.001, field..' backing must shade only the value field')
        assert(label:GetX(false)+label:GetW() <= value:GetX(false), field..' label overlaps value')
        assert(math.abs(option(label,'Y')-variable('Inset')-(rowY+2)*scale)<0.001, field..' label baseline differs')
        assert(value:GetX(false)>=row:GetX(false) and value:GetX(false)+value:GetW()<=row:GetX(false)+row:GetW(), field..' value escapes shaded field')
        for _,target in ipairs({label,value}) do
            assert(target:GetY(false)>=row:GetY(false) and target:GetY(false)+target:GetH()<=row:GetY(false)+row:GetH(), field..' text escapes row')
            assert(math.abs(option(target,'FontSize')-variable('FontSize')*scale)<0.001, field..' bypasses body font')
            assert(target:GetOption('FontColor')==SKIN:GetVariable('TextColor'), field..' value/label bypasses body color')
        end
        assert(value:GetOption('Text')~='...', field..' value never rendered')
        if numeric[field] or field=='Units' then
            local decrease,frame,increase=meter(prefix..field..'Decrease'),meter(prefix..field..'Frame'),meter(prefix..field..'Increase')
            assert(row:GetOption('LeftMouseUpAction','')=='',field..' full-field backing must not intercept stepper clicks')
            -- Centered String bounds can round one physical pixel beyond a passive Shape.
            -- Window bounds, neighboring hit areas and glyph fit remain strict.
            assert(decrease:GetX(false)>=row:GetX(false)-1 and increase:GetX(false)+increase:GetW()<=row:GetX(false)+row:GetW()+1,
                string.format('%s arrows escape field: left %g+%g, right %g+%g, backing %g+%g',field,decrease:GetX(false),decrease:GetW(),increase:GetX(false),increase:GetW(),row:GetX(false),row:GetW()))
            assert(decrease:GetX(false)+decrease:GetW()<=frame:GetX(false) and frame:GetX(false)+frame:GetW()<=increase:GetX(false),field..' arrow/input hit boxes overlap')
            assert(value:GetX(false)>=frame:GetX(false) and value:GetX(false)+value:GetW()<=frame:GetX(false)+frame:GetW(),field..' centered value escapes input anchor')
            for _,target in ipairs({decrease,frame,value,increase}) do
                assert(target:GetOption('Hidden','0')=='0',field..' has an unexpected hidden hit target')
                assert(target:GetY(false)>=row:GetY(false) and target:GetY(false)+target:GetH()<=row:GetY(false)+row:GetH(),field..' stepper escapes row')
                assert(target:GetOption('LeftMouseUpAction','')~='',field..' has an inert stepper target')
            end
            for _,arrow in ipairs({decrease,increase}) do
                assert(option(arrow,'W')==18*scale and option(arrow,'FontSize')==variable('FontSize')*scale,field..' arrow bypasses shared geometry/font')
                assert(arrow:GetOption('FontColor')==SKIN:GetVariable('AccentColor'),field..' arrow bypasses shared Accent 1')
            end
            assert(frame:GetOption('LeftMouseUpAction')==value:GetOption('LeftMouseUpAction')
                and label:GetOption('LeftMouseUpAction')==value:GetOption('LeftMouseUpAction'),field..' label/input actions disagree')
            if numeric[field] then
                assert(decrease:GetOption('LeftMouseUpAction'):find("AdjustNumber('"..numeric[field].."',-1)",1,true),field..' decrement action differs')
                assert(increase:GetOption('LeftMouseUpAction'):find("AdjustNumber('"..numeric[field].."',1)",1,true),field..' increment action differs')
                assert(value:GetOption('LeftMouseUpAction'):find("BeginNumberInput('"..numeric[field].."')",1,true),field..' center does not open numeric input')
            else
                assert(decrease:GetOption('LeftMouseUpAction'):find('CycleUnits(-1)',1,true) and increase:GetOption('LeftMouseUpAction'):find('CycleUnits(1)',1,true),'Units direction controls differ')
            end
        end
    end
    assert(not SKIN:GetMeter(prefix..'ConnectionWidthValue') and not SKIN:GetMeter(prefix..'ConnectionHeightValue')
        and not SKIN:GetMeter(prefix..'OpenConnection'), 'Retired separate Connection settings remain')
    for _,field in ipairs({'WiFiEnabled','WiFiIndex'}) do
        for _,part in ipairs(field=='WiFiIndex' and {'Decrease','Frame','Label','Value','Increase'} or {'Row','Label','Value'}) do
            local target=meter(prefix..field..part)
            assert(target:GetOption('Hidden','0')=='0' and target:GetOption('LeftMouseUpAction','')~='', 'Wi-Fi query/source controls must remain accessible')
        end
    end
    local following={Traffic='AdapterRow',History='InCeilingRow',WiFi='WiFiEnabledRow',Actions='OpenNetwork'}
    for id,y in pairs({Traffic=74,History=215,WiFi=328,Actions=459}) do
        local section,rule=meter(prefix..id..'Section'),meter(prefix..id..'Rule')
        assert(section:GetOption('FontColor')==SKIN:GetVariable('AccentColor'),id..' section must use Accent 1')
        assert(math.abs(option(section,'FontSize')-variable('HeaderFontSize')*scale)<0.001,
            id..' section must retain header font size')
        assert(math.abs(option(section,'Y')-variable('Inset')-y*scale)<0.001
            and math.abs(option(rule,'Y')-variable('Inset')-(y+21)*scale)<0.001,id..' section geometry differs')
        assert(section:GetY(false)+section:GetH()<=rule:GetY(false),id..' section glyph box overlaps divider')
        assert(rule:GetOption('Shape'):find('Stroke Color '..SKIN:GetVariable('DividerColor'),1,true),id..' section does not use divider color')
        local stroke=assert(rule:GetOption('Shape'):match('StrokeWidth%s+([^|]+)'))
        assert(math.abs(number(stroke)-variable('DividerThickness')*scale)<0.001,id..' section does not use divider thickness')
        assert(section:GetY(false)+section:GetH()<=rule:GetY(false)-number(stroke)/2,
            id..' heading touches the painted upper divider edge')
        assert(rule:GetY(false)+number(stroke)/2<meter(prefix..following[id]):GetY(false),
            id..' painted divider touches its following control')
    end
    if SELF:GetNumberOption('LongValueFixture')==1 then
        local adapter=meter(prefix..'AdapterValue')
        assert(adapter:GetOption('ClipString')=='1' and adapter:GetOption('Text'):find('QA long adapter alias',1,true), 'Long saved selector fixture missing')
        assert(adapter:GetOption('ToolTipText'):find('without changing the window',1,true), 'Full long selector missing from tooltip')
        assert(meter(prefix..'WidthValue'):GetOption('Text')=='2' and meter(prefix..'HeightValue'):GetOption('Text')=='333',
            'Settings did not read monitor geometry independently from its local size')
    end
    local rows={'AdapterRow','UnitsRow','WidthRow','HeightRow','HistorySection','InCeilingRow','OutCeilingRow',
        'CeilingHint','WiFiSection','WiFiEnabledRow','WiFiIndexRow',
        'WiFiHint','WiFiHint2','ActionsSection','OpenNetwork','OpenFile','Status','Independence'}
    for index=1,#rows-1 do
        local a,b=meter(prefix..rows[index]),meter(prefix..rows[index+1])
        assert(a:GetY(false)+a:GetH()<=b:GetY(false),rows[index]..' overlaps '..rows[index+1])
    end
    for _,pair in ipairs({{'OpenFile','ApplyFile'}}) do
        local a,b=meter(prefix..pair[1]),meter(prefix..pair[2])
        assert(a:GetX(false)+a:GetW()<=b:GetX(false),pair[1]..' overlaps '..pair[2])
        assert(a:GetY(false)==b:GetY(false) and a:GetH()==b:GetH(),'Action row baseline differs')
    end
    local footer=meter(prefix..'Independence')
    assert(footer:GetY(false)+footer:GetH()<=variable('Inset')+variable('PanelHeightPx')-4*scale,'Footer reaches inside border')
    return string.format('PASS settings width=%d scale=%g typography=%s size=%dx%d glyphs=%d',cw,scale,
        SELF:GetOption('Typography'),expectedW,expectedH,glyphChecks())
end

local function actions()
    local path=SELF:GetOption('CommandFile','')
    if path=='' then return end
    local command=read(path)
    if not command then return end
    assert(os.remove(path), 'Cannot consume private QA command')
    local targets={units='UnitsIncrease',unitsBack='UnitsDecrease',wifi='WiFiEnabledValue',source='WiFiIndexIncrease',
        widthUp='WidthIncrease',widthDown='WidthDecrease',heightUp='HeightIncrease',heightDown='HeightDecrease',
        inUp='InCeilingIncrease',inDown='InCeilingDecrease',outUp='OutCeilingIncrease',outDown='OutCeilingDecrease',sourceDown='WiFiIndexDecrease',
        inputWidth='WidthValue',inputHeight='HeightValue',inputIn='InCeilingFrame',inputOut='OutCeilingValue',inputSource='WiFiIndexLabel',
        global='MeterUtilitySettingsGlobalLink',network='OpenNetwork',apply='ApplyFile',close='Close'}
    local action
    if command=='hide-network' then action='[!DeactivateConfig "Parallax\\Network"]'
    elseif command=='replayInput' then action='[!CommandMeasure MeasureNetworkSettings "FinishNumberInput()"]'
    else
        local target=assert(targets[command], 'Unknown private QA command')
        action=meter(target=='MeterUtilitySettingsGlobalLink' and target or prefix..target):GetOption('LeftMouseUpAction')
        assert(action~='', 'Production action missing')
        if command:sub(1,5)=='input' then
            local frames={inputWidth='Width',inputHeight='Height',inputIn='InCeiling',inputOut='OutCeiling',inputSource='WiFiIndex'}
            local frame=meter(prefix..frames[command]..'Frame')
            write(SELF:GetOption('InputAnchorFile'),string.format('%d,%d,%d,%d',
                variable('CURRENTCONFIGX')+frame:GetX(false),variable('CURRENTCONFIGY')+frame:GetY(false),frame:GetW(),frame:GetH()))
        end
    end
    SKIN:Bang(action)
    write(SELF:GetOption('AckFile'),command)
end

function InputFinished()
    local path=SELF:GetOption('InputFinishFile','')
    if path~='' then write(path,tostring((tonumber(read(path)) or 0)+1)) end
end

function Update()
    if SELF:GetOption('Mode')=='Observer' then
        write(SELF:GetOption('SnapshotFile'),'NetworkUnits='..SKIN:GetVariable('NetworkUnits','missing')..'\nNetworkWiFiEnabled='..SKIN:GetVariable('NetworkWiFiEnabled','missing')..'\nNetworkWiFiInterface='..SKIN:GetVariable('NetworkWiFiInterface','missing')..'\n')
        return 0
    end
    ticks=ticks+1
    if ticks==1 then local ok,err=pcall(prepareGlyphs);if not ok then probeError=tostring(err) end end
    if ticks==4 then
        local ok,result=pcall(layout)
        write(SELF:GetOption('ResultFile'),ok and result or 'FAIL '..tostring(result))
        completed=ok
    end
    if completed then
        local ok,err=pcall(actions)
        if not ok then write(SELF:GetOption('ActionErrorFile'),'FAIL '..tostring(err));completed=false end
    end
    return completed and 1 or 0
end
