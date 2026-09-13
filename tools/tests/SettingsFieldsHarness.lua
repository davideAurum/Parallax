-- Native source-action driver and passive refresh witness; isolated test copies only.
local root, role, generation, sequence, ticks, pending
local fields = {
    Scale='MeterScaleInput', ColumnWidth='MeterWidthInput', Gutter='MeterGapInput', CornerRadius='MeterRoundingInput',
    TitleFontSize='MeterTitleSizeInput', HeaderFontSize='MeterHeaderSizeInput', FontSize='MeterBodySizeInput',
    BackgroundTransparency='MeterBackgroundTransparencyInput', BorderThickness='MeterBorderSizeInput', DividerThickness='MeterDividerSizeInput',
    TableHeaderBorderThickness='MeterTableHeaderBorderSizeInput', DataBarThickness='MeterDataBarSizeInput'
}
local function read(path)
    local file=io.open(path,'rb'); if not file then return nil end
    local value=file:read('*a'); file:close(); return value
end
local function write(path,value)
    local file=assert(io.open(path,'wb')); file:write(value); file:close()
end
local function snapshot(path)
    local ok, result=pcall(function()
        local lines={'PASS','Generation='..generation,'Lua='.._VERSION}
        for _, name in ipairs({'Scale','ColumnWidth','Gutter','CornerRadius','TitleFontSize','HeaderFontSize','FontSize',
                'BackgroundColor','BorderThickness','DividerThickness','TableHeaderBorderThickness','DataBarThickness','Columns','PanelHeight','AccentColor'}) do
            lines[#lines+1]=name..'='..SKIN:GetVariable(name)
        end
        lines[#lines+1]='BackgroundTransparencyVariable='..SKIN:GetVariable('BackgroundTransparency','<unset>')
        local bounds=assert(SKIN:GetMeter('MeterBounds'))
        lines[#lines+1]='Width='..bounds:GetW(); lines[#lines+1]='Height='..bounds:GetH()
        for key,name in pairs(fields) do
            local meter=assert(SKIN:GetMeter(name))
            assert(meter:GetX()>=0 and meter:GetY()>=0 and meter:GetX()+meter:GetW()<=bounds:GetW()+1 and meter:GetY()+meter:GetH()<=bounds:GetH()+1, name..' outside window')
            lines[#lines+1]=key..'Text='..meter:GetOption('Text','')
            local frame=assert(SKIN:GetMeter(name:gsub('Input$','Frame')))
            lines[#lines+1]=key..'Bounds='..table.concat({math.floor(SKIN:GetX()+frame:GetX()),math.floor(SKIN:GetY()+frame:GetY()),math.max(40,math.floor(frame:GetW())),math.max(20,math.floor(frame:GetH()))},',')
        end
        for _,name in ipairs({'MeterGeometry','MeterAccentValue','MeterBackgroundColorValue','MeterInputStatus'}) do
            lines[#lines+1]=name..'='..assert(SKIN:GetMeter(name)):GetOption('Text','')
        end
        lines[#lines+1]='HelperOutput='..assert(SKIN:GetMeasure('MeasureSettingsInput')):GetStringValue():gsub('[\r\n]+$',''):gsub('\n','<LF>')
        return table.concat(lines,'\n')..'\n'
    end)
    write(path,ok and result or ('FAIL\n'..tostring(result)..'\n'))
end
function Initialize()
    root=SELF:GetOption('ReportDirectory'); role=SELF:GetOption('Role','settings')
    assert(root~='', 'Missing private report directory')
    generation=(tonumber(read(root..role..'-generation.txt')) or 0)+1
    write(root..role..'-generation.txt',tostring(generation))
    sequence=tonumber(read(root..'sequence.txt')) or 0
    ticks,pending=0,nil
end
function Update()
    if role~='settings' then return 0 end
    ticks=ticks+1
    if ticks==2 then snapshot(root..'ready-'..generation..'.txt') end
    if ticks<3 then return 0 end
    if pending then
        local expected=read(root..'expected-response.txt') or ''
        local output=assert(SKIN:GetMeasure('MeasureSettingsInput')):GetStringValue():gsub('[\r\n]+$','')
        -- Repeated cancel outputs may equal the previous RunCommand result.
        -- Require evidence that this exact helper invocation ran before settling.
        local launched=read(root..'helper-'..pending.sequence..'.json')
        if launched and output==expected then pending.stable=pending.stable+1 else pending.stable=0 end
        if pending.stable>=3 then snapshot(root..'result-'..pending.sequence..'.txt'); pending=nil end
    end
    local request=read(root..'request.txt') or ''
    local nextSequence,key=request:match('^(%d+)|([%w_]+)$')
    nextSequence=tonumber(nextSequence)
    if not nextSequence or nextSequence<=sequence then return 0 end
    sequence=nextSequence; write(root..'sequence.txt',tostring(sequence))
    local ok,err=pcall(function()
        local name=assert(fields[key],'Unknown test field')
        local action=assert(SKIN:GetMeter(name)):GetOption('LeftMouseUpAction','')
        assert(action:find("BeginEdit('"..key.."')",1,true),'Source field action changed')
        snapshot(root..'before-'..sequence..'.txt')
        pending={sequence=sequence,stable=0}
        SKIN:Bang(action)
    end)
    if not ok then write(root..'result-'..sequence..'.txt','FAIL\n'..tostring(err)..'\n') end
    return 0
end
