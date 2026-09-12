-- Private file requests drive source-bound actions in an isolated Rainmeter PID.
local root,ticks,last,pending,mathChecks,generation
local meters={'MeterTitle','MeterModeRGB','MeterModeHSV','MeterModeLAB','MeterDescription','MeterPlaneHit','MeterSliceHit','MeterOriginal','MeterPreview','MeterHex','MeterStatus','MeterCancel','MeterApply','MeterHelp'}
local function read(path)
    local f=io.open(path,'rb'); if not f then return '' end
    local s=f:read('*a'); f:close(); return s
end
local function write(path,text)
    local f=assert(io.open(path,'wb')); f:write(text); f:close()
end
local function report(path)
    local ok,result=pcall(function()
        local bounds=assert(SKIN:GetMeter('MeterBounds'))
        local w,h=bounds:GetW(),bounds:GetH()
        assert(w==tonumber(SELF:GetOption('ExpectedWidth')),'Wrong bounds width: '..w)
        assert(h==tonumber(SELF:GetOption('ExpectedHeight')),'Wrong bounds height: '..h)
        local lines={'PASS','Width='..w,'Height='..h,'MathChecks='..mathChecks}
        for _,name in ipairs(meters) do
            local m=assert(SKIN:GetMeter(name),name)
            assert(m:GetX()>=0 and m:GetY()>=0,name..' outside origin')
            assert(m:GetX()+m:GetW()<=w+1 and m:GetY()+m:GetH()<=h+1,name..' overflows bounds')
        end
        for i=1,3 do
            for _,kind in ipairs({'Label','Minus','Value','Plus'}) do
                local name='MeterChannel'..kind..i; local m=assert(SKIN:GetMeter(name))
                assert(m:GetX()+m:GetW()<=w+1 and m:GetY()+m:GetH()<=h+1,name..' overflows bounds')
            end
        end
        lines[#lines+1]='Hex='..SKIN:GetMeter('MeterHex'):GetOption('Text')
        lines[#lines+1]='Title='..SKIN:GetMeter('MeterTitle'):GetOption('Text')
        lines[#lines+1]='Original='..SKIN:GetMeter('MeterOriginal'):GetOption('SolidColor')
        lines[#lines+1]='Status='..SKIN:GetMeter('MeterStatus'):GetOption('Text')
        for i=1,3 do lines[#lines+1]='Channel'..i..'='..SKIN:GetMeter('MeterChannelValue'..i):GetOption('Text') end
        return table.concat(lines,'\n')..'\n'
    end)
    write(path,ok and result or 'FAIL\n'..tostring(result)..'\n')
end
local function action(name,required,x,y)
    local command=assert(SKIN:GetMeter(name)):GetOption('LeftMouseUpAction','')
    assert(command:find(required,1,true),'Unexpected source action '..name)
    if x then command=command:gsub('%$MouseX:%%%$',tostring(x)) end
    if y then command=command:gsub('%$MouseY:%%%$',tostring(y)) end
    assert(not command:find('$Mouse',1,true),'Unresolved mouse variable')
    SKIN:Bang(command)
end
function Initialize()
    root=SELF:GetOption('ReportDirectory'); ticks,pending=0,nil
    last=tonumber(read(root..'picker-sequence.txt')) or 0
    local count=tonumber(read(root..'generations.txt')) or 0
    generation=count+1
    write(root..'generations.txt',tostring(generation))
    local module=SKIN:GetVariable('@')..'Modules\\ColorPicker\\'
    local ok,result=pcall(function()
        return dofile(module..'tests\\ColorMathTests.lua')(dofile(module..'ColorMath.lua'))
            + dofile(module..'tests\\TargetTests.lua')(module..'ColorPicker.lua',SKIN:GetVariable('@'))
    end)
    if not ok then write(root..'ready.txt','FAIL\n'..tostring(result)); mathChecks=0 else mathChecks=result end
end
function Update()
    ticks=ticks+1
    if ticks==2 and mathChecks>0 then report(root..'ready.txt') end
    if ticks<3 or mathChecks==0 then return 0 end
    if pending then report(root..'result-'..pending..'.txt'); pending=nil end
    local sequence,command=read(root..'request.txt'):match('^(%d+)|(%w+)')
    sequence=tonumber(sequence)
    if not sequence or sequence<=last then return 0 end
    last=sequence
    write(root..'picker-sequence.txt',tostring(last))
    local ok,err=pcall(function()
        if command=='rgb' then action('MeterModeRGB',"SetMode('RGB')")
        elseif command=='hsv' then action('MeterModeHSV',"SetMode('HSV')")
        elseif command=='lab' then action('MeterModeLAB',"SetMode('LAB')")
        elseif command=='plane' then action('MeterPlaneHit','SelectPlane(',73,28)
        elseif command=='corner' then action('MeterPlaneHit','SelectPlane(',100,0)
        elseif command=='slice' then action('MeterSliceHit','SelectSlice(',50)
        elseif command=='plus' then action('MeterChannelPlus2','ChangeChannel(2,1)')
        elseif command=='minus' then action('MeterChannelMinus2','ChangeChannel(2,-1)')
        elseif command=='invalid' then SKIN:Bang('!CommandMeasure','MeasureColorPicker',"OpenTarget('NotAColorTarget')")
        elseif command=='apply' then
            report(root..'before-close.txt'); report(root..'before-close-'..sequence..'.txt'); action('MeterApply','Apply()'); return
        elseif command=='cancel' then
            report(root..'before-close.txt'); report(root..'before-close-'..sequence..'.txt'); action('MeterCancel','Cancel()'); return
        else error('Unknown request') end
        pending=sequence
    end)
    if not ok then write(root..'result-'..sequence..'.txt','FAIL\n'..tostring(err)) end
    return 0
end
function ReportLaunch(sequence)
    assert(tonumber(sequence) and sequence==math.floor(sequence))
    report(root..'launch-'..sequence..'.txt')
end
