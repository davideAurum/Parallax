-- Native cross-config test: drives the production Launcher.lua from a separate
-- skin, as a swatch would. Never addresses another Rainmeter PID.
local root,last,pending,ticks,targets
local function read(path)
    local f=io.open(path,'rb'); if not f then return '' end
    local text=f:read('*a'); f:close(); return text
end
function Initialize()
    root=SELF:GetOption('ReportDirectory'); last,ticks=0,0
    targets=dofile(SKIN:GetVariable('@')..'Modules\\ColorPicker\\Targets.lua')
    -- Work area of Rainmeter's first monitor, in Rainmeter's own coordinates.
    local area={}
    for _,name in ipairs({'WORKAREAX','WORKAREAY','WORKAREAWIDTH','WORKAREAHEIGHT'}) do area[#area+1]=SKIN:ReplaceVariables('#'..name..'@1#') end
    local f=assert(io.open(root..'monitor.txt','wb')); f:write(table.concat(area,'|')); f:close()
end
function Update()
    ticks=ticks+1
    if pending and ticks>=pending.tick then
        SKIN:Bang('!CommandMeasure','MeasureColorPickerHarness','ReportLaunch('..pending.sequence..')','Parallax\\ColorPicker')
        pending=nil
    end
    -- sequence|key, optionally followed by |x|y: where this skin sits first.
    local fields={}
    for field in read(root..'launch-request.txt'):gmatch('[^|\r\n]+') do fields[#fields+1]=field end
    local sequence,key=tonumber(fields[1]),fields[2]
    if not sequence or sequence<=last or not key then return 0 end
    assert(targets.Find(key),'Unexpected launcher fixture target')
    last=sequence
    if fields[3] and fields[4] then SKIN:Bang('!Move',tostring(tonumber(fields[3])),tostring(tonumber(fields[4]))) end
    -- A swatch click: activate beside this skin and open the target.
    SKIN:Bang('!CommandMeasure','MeasureColorLauncher',"Open('"..key.."')")
    pending={sequence=sequence,tick=ticks+3}
    return 0
end
