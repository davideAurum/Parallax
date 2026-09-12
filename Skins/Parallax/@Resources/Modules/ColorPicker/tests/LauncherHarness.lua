-- Native cross-config activation test. Never addresses another Rainmeter PID.
local root,last,pending,ticks
local allowed={AccentColor=true,AccentColor2=true,TitleTextColor=true,HeaderTextColor=true,TextColor=true,BackgroundColor=true,BorderColor=true,DividerColor=true}
local function read(path)
    local f=io.open(path,'rb'); if not f then return '' end
    local text=f:read('*a'); f:close(); return text
end
function Initialize() root=SELF:GetOption('ReportDirectory'); last,ticks=0,0 end
function Update()
    ticks=ticks+1
    if pending and ticks>=pending.tick then
        SKIN:Bang('!CommandMeasure','MeasureColorPickerHarness','ReportLaunch('..pending.sequence..')','Parallax\\ColorPicker')
        pending=nil
    end
    local sequence,key=read(root..'launch-request.txt'):match('^(%d+)|(%w+)$')
    sequence=tonumber(sequence)
    if not sequence or sequence<=last then return 0 end
    assert(allowed[key],'Unexpected launcher fixture target')
    last=sequence
    -- This is the exact activation/targeting sequence used by Global Settings.
    SKIN:Bang('[!ActivateConfig "Parallax\\ColorPicker" "ColorPicker.ini"][!CommandMeasure "MeasureColorPicker" "OpenTarget(\''..key..'\')" "Parallax\\ColorPicker"]')
    pending={sequence=sequence,tick=ticks+3}
    return 0
end
