-- Work happens on open and user actions. The production skin has Update=-1.
local C, mode, channels, original, ready, targetKey, originalAlpha
local targets = {
    AccentColor='Accent Color 1', AccentColor2='Accent Color 2',
    TitleTextColor='Title Text Color', HeaderTextColor='Header Text Color',
    TextColor='Body Text Color', BackgroundColor='Background Color',
    BorderColor='Border Color', DividerColor='Divider Color'
}
local rows, stops = 48,24
local names = {RGB={'R','G','B'},HSV={'H','S','V'},LAB={'L*','a*','b*'}}
local limits = {RGB={{0,255},{0,255},{0,255}},HSV={{0,360},{0,100},{0,100}},LAB={{0,100},{-128,127},{-128,127}}}
local descriptions = {RGB='R / G plane  |  B strip',HSV='S / V plane  |  Hue strip',LAB='a* / b* plane  |  L* strip  (D50)'}
local function option(meter,key,value) SKIN:Bang('!SetOption',meter,key,tostring(value)) end
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
local function paint(rebuild)
    if not ready then return end
    if rebuild then buildPlane() end
    local color=rgb()
    local colorString,clipped=C.String(color)
    option('MeterPreview','SolidColor',colorString)
    option('MeterHex','Text',C.Hex(color))
    option('MeterOriginal','SolidColor',C.String(original))
    option('MeterTitle','Text',targets[targetKey])
    option('MeterDescription','Text',descriptions[mode])
    local message='Preview only. Apply saves this global color.'
    if targetKey=='BackgroundColor' then message=string.format('Preview only. Background opacity stays %.0f%%.',originalAlpha/255*100) end
    option('MeterStatus','Text',clipped and 'Outside sRGB: preview and Apply are clipped.' or message)
    option('MeterStatus','FontColor',SKIN:GetVariable(clipped and 'WarningColor' or 'PickerMutedColor'))
    for _,m in ipairs({'RGB','HSV','LAB'}) do
        option('MeterMode'..m,'FontColor',SKIN:GetVariable(m==mode and 'PickerTextColor' or 'PickerMutedColor'))
        option('MeterMode'..m,'SolidColor',m==mode and SKIN:GetVariable('TrackColor') or '0,0,0,1')
    end
    for i=1,3 do
        option('MeterChannelLabel'..i,'Text',names[mode][i])
        local suffix=mode=='HSV' and (i==1 and ' deg' or '%') or ''
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
    SKIN:Bang('!Redraw')
end
function Initialize()
    C=dofile(SKIN:GetVariable('@')..'Modules\\ColorPicker\\ColorMath.lua')
    targetKey='AccentColor'
    originalAlpha=255
    original=C.Parse(SKIN:GetVariable(targetKey))
    mode='HSV'; setChannels(original); ready=false
end
function Update()
    return 0
end
-- OnRefreshAction runs after the initial meter dimensions have been resolved.
function Render() ready=true; paint(true) end
-- Call after ActivateConfig, with the explicit Parallax\ColorPicker config.
-- A valid target discards the old preview. Invalid input has no side effects.
function OpenTarget(key)
    if type(key)~='string' or not targets[key] then return false end
    targetKey=key
    local value=SKIN:GetVariable(targetKey)
    original=C.Parse(value)
    originalAlpha=targetKey=='BackgroundColor' and C.Alpha(value) or 255
    mode='HSV'; setChannels(original)
    paint(true)
    return true
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
function Apply()
    if not targets[targetKey] then return false end
    local value=C.String(rgb())
    if targetKey=='BackgroundColor' then value=value..','..originalAlpha end
    SKIN:Bang('!WriteKeyValue','Variables',targetKey,value,SKIN:GetVariable('@')..'User\\Settings.inc')
    SKIN:Bang('!RefreshGroup','Parallax')
    SKIN:Bang('!DeactivateConfig','Parallax\\ColorPicker')
    return true
end
function Cancel() SKIN:Bang('!DeactivateConfig','Parallax\\ColorPicker') end
