-- Work happens on open and user actions. The production skin has Update=-1.
local C, T, mode, channels, original, ready, entry, originalAlpha
local menu, menuOpen, menuTop = nil, false, 1
local MENU_ROWS = 10
local rows, stops = 48,24
local names = {RGB={'R','G','B'},HSV={'H','S','V'},LAB={'L*','a*','b*'}}
local limits = {RGB={{0,255},{0,255},{0,255}},HSV={{0,360},{0,100},{0,100}},LAB={{0,100},{-128,127},{-128,127}}}
local function option(meter,key,value) SKIN:Bang('!SetOption',meter,key,tostring(value)) end
local function resources() return SKIN:GetVariable('@') end

-- [Variables] of User\<file>.inc as a table (the last assignment wins, as in
-- Rainmeter). Module colors are stored there, not in the picker's own scope.
local function readUserFile(file)
    local values = {}
    local handle = io.open(resources()..'User\\'..file..'.inc','rb')
    if not handle then return values end
    local text = handle:read('*a') or ''
    handle:close()
    local inVariables = false
    for line in text:gmatch('[^\r\n]+') do
        local section = line:match('^%s*%[([^%]]*)%]')
        if section then inVariables = section:lower() == 'variables'
        elseif inVariables and not line:match('^%s*;') then
            local key, value = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            if key then values[key] = value end
        end
    end
    return values
end
local function savedValue(target, files)
    if target.file == 'Settings' then return SKIN:GetVariable(target.key, target.default) end
    local values = files[target.file] or readUserFile(target.file)
    files[target.file] = values
    return values[target.key] or target.default
end

local function rgb()
    if mode == 'RGB' then return {channels[1]/255,channels[2]/255,channels[3]/255} end
    if mode == 'HSV' then return C.HsvToRgb({channels[1],channels[2]/100,channels[3]/100}) end
    return C.LabToRgb(channels)
end
local function setChannels(color)
    if mode == 'RGB' then channels={color[1]*255,color[2]*255,color[3]*255}
    elseif mode == 'HSV' then
        local hsv=C.RgbToHsv(color); channels={hsv[1],hsv[2]*100,hsv[3]*100}
    else channels=C.RgbToLab(color) end
end
local function planeColor(x,y)
    if mode == 'RGB' then return {x,1-y,channels[3]/255} end
    if mode == 'HSV' then return C.HsvToRgb({channels[1],x,1-y}) end
    return C.LabToRgb({channels[1],x*255-128,(1-y)*255-128})
end
local function sliceColor(t)
    if mode == 'RGB' then return {channels[1]/255,channels[2]/255,t} end
    if mode == 'HSV' then return C.HsvToRgb({t*360,1,1}) end
    return C.LabToRgb({t*100,channels[2],channels[3]})
end
local function coordinates()
    if mode == 'RGB' then return channels[1]/255,1-channels[2]/255,channels[3]/255 end
    if mode == 'HSV' then return channels[2]/100,1-channels[3]/100,channels[1]/360 end
    return (channels[2]+128)/255,1-(channels[3]+128)/255,channels[1]/100
end
local function buildPlane()
    local width=SKIN:GetMeter('MeterPlaneHit'):GetW()
    local height=SKIN:GetMeter('MeterPlaneHit'):GetH()
    if width < 1 or height < 1 then return end
    for row=1,rows do
        local gradient={'180'}
        for stop=0,stops do gradient[#gradient+1]=C.String(planeColor(stop/stops,(row-0.5)/rows))..';'..string.format('%.6f',stop/stops) end
        local name='Spectrum'..row
        option('MeterSpectrum',name,table.concat(gradient,' | '))
        -- Integer pixel edges overlap fractional row boundaries, preventing D2D seams.
        local top=math.floor((row-1)*height/rows)
        local bottom=math.ceil(row*height/rows)
        option('MeterSpectrum',row==1 and 'Shape' or 'Shape'..row,string.format('Rectangle 0,%d,%.4f,%d | Fill LinearGradient %s | StrokeWidth 0',top,width,bottom-top,name))
    end
    SKIN:Bang('!UpdateMeter','MeterSpectrum')
end

-- Logical threads the CPU meter shows, as Thread Colors counts them.
local function threadCount(files)
    local detected = tonumber(os.getenv('NUMBER_OF_PROCESSORS')) or 1
    detected = math.max(1, math.min(T.MaxThreads, math.floor(detected)))
    files.CPU = files.CPU or readUserFile('CPU')
    local limit = math.floor(tonumber(files.CPU.CPUCoreLimit) or 0)
    limit = math.max(0, math.min(T.MaxThreads, limit))
    return limit > 0 and math.min(detected, limit) or detected
end
local function menuIndex(key)
    for index, item in ipairs(menu) do if item.key == key then return index end end
    return 1
end

local function paintMenu()
    local files = {}
    local scale = tonumber(SKIN:GetVariable('Scale')) or 1
    for i=1,MENU_ROWS do
        local item = menu[menuTop+i-1]
        local row, dot = 'MeterMenuRow'..i, 'MeterMenuDot'..i
        if not item then
            option(row,'Text',''); option(row,'SolidColor','0,0,0,1'); option(row,'MouseActionCursor',0)
            option(dot,'Shape','Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0')
        elseif item.kind == 'group' then
            option(row,'Text',item.label); option(row,'SolidColor','0,0,0,1'); option(row,'MouseActionCursor',0)
            option(row,'FontColor',SKIN:GetVariable('PickerMutedColor'))
            option(dot,'Shape','Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0')
        else
            local target = T.Find(item.key)
            local color = target and C.Parse(savedValue(target, files)) or {0,0,0}
            option(row,'Text',item.label); option(row,'MouseActionCursor',1)
            option(row,'FontColor',SKIN:GetVariable('PickerTextColor'))
            option(row,'SolidColor',item.key == entry.key and '255,255,255,26' or '0,0,0,1')
            option(dot,'Shape',string.format('Rectangle %.4f,%.4f,%.4f,%.4f,%.4f | Fill Color %s | Stroke Color 255,255,255,70 | StrokeWidth %.4f',
                0.5*scale,0.5*scale,9*scale,9*scale,2*scale,C.String(color),scale))
        end
    end
    local trackHeight = MENU_ROWS*19*scale
    local thumb = 'Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0'
    if #menu > MENU_ROWS then
        local height = math.max(8*scale, trackHeight*MENU_ROWS/#menu)
        local top = (menuTop-1)/(#menu-MENU_ROWS)*(trackHeight-height)
        thumb = string.format('Rectangle 0,%.4f,%.4f,%.4f,%.4f | Fill Color 255,255,255,70 | StrokeWidth 0',top,2*scale,height,scale)
    end
    option('MeterMenuThumb','Shape',thumb)
    SKIN:Bang('!UpdateMeterGroup','PickerMenu')
end

local function paint(rebuild)
    if not ready then return end
    if rebuild then buildPlane() end
    local color=rgb()
    local colorString,clipped=C.String(color)
    option('MeterPreview','SolidColor',colorString)
    option('MeterHex','Text',C.Hex(color))
    option('MeterOriginal','SolidColor',C.String(original))
    option('MeterTarget','Text',entry.label)
    local message,warn='',false
    if clipped then message,warn='Outside sRGB: clipped',true
    elseif entry.alpha then message=string.format('Opacity %.0f%% kept',originalAlpha/255*100) end
    option('MeterStatus','Text',message)
    option('MeterStatus','FontColor',SKIN:GetVariable(warn and 'WarningColor' or 'PickerMutedColor'))
    for _,m in ipairs({'RGB','HSV','LAB'}) do
        option('MeterMode'..m,'FontColor',SKIN:GetVariable(m==mode and 'PickerTextColor' or 'PickerMutedColor'))
    end
    for i=1,3 do
        option('MeterChannelLabel'..i,'Text',names[mode][i])
        -- Hue is degrees; the label says H. (A degree sign would need a non-ASCII script.)
        local suffix=mode=='HSV' and (i==1 and '' or '%') or ''
        option('MeterChannelValue'..i,'Text',string.format(mode=='LAB' and '%.1f' or '%.0f',channels[i])..suffix)
    end
    local gradient={'180'}
    for i=0,stops do gradient[#gradient+1]=C.String(sliceColor(i/stops))..';'..string.format('%.6f',i/stops) end
    option('MeterSlice','SliceGradient',table.concat(gradient,' | '))
    local x,y,t=coordinates()
    local plane=SKIN:GetMeter('MeterPlaneHit')
    local width,height=plane:GetW(),plane:GetH()
    local scale=tonumber(SKIN:GetVariable('Scale')) or 1
    local radius=math.max(2,3*scale)
    x,y=C.Clamp(x*width,radius+1,width-radius-1),C.Clamp(y*height,radius+1,height-radius-1)
    option('MeterPlaneMarker','Shape',string.format('Ellipse %.4f,%.4f,%.4f | Fill Color 0,0,0,0 | Stroke Color 0,0,0,255 | StrokeWidth %.4f',x,y,radius+1,2*scale))
    option('MeterPlaneMarker','Shape2',string.format('Ellipse %.4f,%.4f,%.4f | Fill Color 0,0,0,0 | Stroke Color 255,255,255,255 | StrokeWidth %.4f',x,y,radius,scale))
    local sliceWidth=SKIN:GetMeter('MeterSliceHit'):GetW()
    local sliceHeight=SKIN:GetMeter('MeterSliceHit'):GetH()
    t=C.Clamp(t*sliceWidth,1,sliceWidth-2)
    option('MeterSliceMarker','Shape',string.format('Rectangle %.4f,0,2,%.4f | Fill Color 255,255,255 | Stroke Color 0,0,0 | StrokeWidth 1',t,sliceHeight))
    SKIN:Bang('!UpdateMeterGroup','PickerUI')
    if menuOpen then paintMenu() end
    SKIN:Bang('!Redraw')
end

local function showMenu(open)
    menuOpen = open
    SKIN:Bang(open and '!HideMeterGroup' or '!ShowMeterGroup','PickerBody')
    SKIN:Bang(open and '!ShowMeterGroup' or '!HideMeterGroup','PickerMenu')
end

function Initialize()
    C=dofile(resources()..'Modules\\ColorPicker\\ColorMath.lua')
    T=dofile(resources()..'Modules\\ColorPicker\\Targets.lua')
    entry=T.Find('AccentColor')
    originalAlpha=255
    original=C.Parse(SKIN:GetVariable(entry.key))
    mode='HSV'; setChannels(original); ready=false
    menuOpen=false; menuTop=1; menu=nil
end
function Update()
    return 0
end
-- OnRefreshAction runs after the initial meter dimensions have been resolved.
function Render() ready=true; paint(true) end
-- Call after ActivateConfig, with the explicit Parallax\ColorPicker config
-- (Launcher.lua does). A valid key discards the old preview; an invalid one
-- changes nothing and is never put into an action.
function OpenTarget(key)
    local target=T.Find(key)
    if not target then return false end
    entry=target
    local value=savedValue(entry,{})
    original=C.Parse(value)
    originalAlpha=entry.alpha and C.Alpha(value) or 255
    mode='HSV'; setChannels(original)
    if menuOpen then showMenu(false) end
    paint(true)
    return true
end
-- The title's dropdown: every picker target in one scrolling list.
function ToggleMenu()
    if not ready then return end
    if menuOpen then showMenu(false); paint(false); return end
    menu=T.Menu(threadCount({}))
    menuTop=math.max(1,math.min(math.max(1,#menu-MENU_ROWS+1),menuIndex(entry.key)-3))
    showMenu(true)
    paint(false)
end
function MenuScroll(delta)
    delta=tonumber(delta)
    if not menuOpen or not delta or delta~=delta then return end
    local top=math.max(1,math.min(math.max(1,#menu-MENU_ROWS+1),menuTop+math.floor(delta)))
    if top==menuTop then return end
    menuTop=top
    paintMenu()
    SKIN:Bang('!Redraw')
end
function MenuPick(row)
    row=tonumber(row)
    if not menuOpen or not row or row<1 or row>MENU_ROWS then return false end
    local item=menu[menuTop+math.floor(row)-1]
    if not item or item.kind~='target' then return false end
    return OpenTarget(item.key)
end
function SetMode(value)
    if not names[value] or value==mode then return end
    local bytes=C.Bytes(rgb())
    mode=value; setChannels({bytes[1]/255,bytes[2]/255,bytes[3]/255}); paint(true)
end
function ChangeChannel(index,delta)
    index,delta=tonumber(index),tonumber(delta)
    if not index or not limits[mode][index] or not delta or delta~=delta then return end
    channels[index]=C.Clamp(channels[index]+C.Clamp(delta,-10,10),limits[mode][index][1],limits[mode][index][2])
    paint((mode=='RGB' and index==3) or (mode=='HSV' and index==1) or (mode=='LAB' and index==1))
end
function SelectPlane(x,y)
    x,y=tonumber(x),tonumber(y)
    if not x or not y or x~=x or y~=y then return end
    x,y=C.Clamp(x/100,0,1),C.Clamp(y/100,0,1)
    if mode=='RGB' then channels[1],channels[2]=x*255,(1-y)*255
    elseif mode=='HSV' then channels[2],channels[3]=x*100,(1-y)*100
    else channels[2],channels[3]=x*255-128,(1-y)*255-128 end
    paint(false)
end
function SelectSlice(x)
    x=tonumber(x)
    if not x or x~=x then return end
    x=C.Clamp(x/100,0,1)
    if mode=='RGB' then channels[3]=x*255
    elseif mode=='HSV' then channels[1]=x*360
    else channels[1]=x*100 end
    paint(true)
end
-- Writes the one selected key to the file that stores it. Shared colors
-- reload the suite; a module color reloads only that module. A CPU thread
-- color is pushed to the running CPU meter instead, as Thread Colors does,
-- and only the open Thread Colors panel reloads.
function Apply()
    if not entry then return false end
    local value=C.String(rgb())
    if entry.alpha then value=value..','..originalAlpha end
    SKIN:Bang('!WriteKeyValue','Variables',entry.key,value,resources()..'User\\'..entry.file..'.inc')
    if entry.thread then
        SKIN:Bang('!SetVariableGroup',entry.key,value,'ParallaxCPU')
        SKIN:Bang('!UpdateMeasureGroup','ParallaxCPUApply','*')
        SKIN:Bang('!RefreshGroup','ParallaxCPUColors')
    else
        SKIN:Bang('!RefreshGroup',entry.refresh)
    end
    SKIN:Bang('!DeactivateConfig','Parallax\\ColorPicker')
    return true
end
function Cancel() SKIN:Bang('!DeactivateConfig','Parallax\\ColorPicker') end
