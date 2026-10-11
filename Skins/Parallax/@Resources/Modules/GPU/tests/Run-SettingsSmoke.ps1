#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet(180,200,220,240,280,320)][int]$ColumnWidth=200,
    [ValidateSet('0.75','1','1.25','1.5','2')][string]$Scale='1',
    [ValidateSet(6,10,12)][int]$TitleFontSize,
    [ValidateRange(1,12)][int]$DataBarThickness,
    [ValidateRange(330,1000)][int]$MonitorHeight=333,
    [switch]$CaptureOnly,
    [switch]$TypedColumns,
    [switch]$MaxTypography,
    [ValidateSet('Unload','Stop','LeaseFailure')][string]$ControllerLifecycle='Unload',
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$process=$null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$runRoot=Join-Path $projectRoot ('build\gpu-native-smoke-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$parallaxRoot=Join-Path $runRoot 'Skins\Parallax'
$null=New-Item -ItemType Directory -Path (Join-Path $parallaxRoot '@Resources\Modules'),(Join-Path $parallaxRoot '@Resources\User')
# Test-only GPU fixture: do not stage unrelated in-flight modules or build a
# release package. The production helper allowlist remains integration-owned.
$sourceSkin=Join-Path $projectRoot 'Skins\Parallax'
Copy-Item -LiteralPath (Join-Path $sourceSkin 'GPU') -Destination $parallaxRoot -Recurse
Copy-Item -LiteralPath (Join-Path $sourceSkin '@Resources\Modules\GPU') -Destination (Join-Path $parallaxRoot '@Resources\Modules') -Recurse
foreach ($name in @('Defaults.inc','Geometry.inc','Styles.inc','UtilitySettingsNote.inc','Fonts')) {
    Copy-Item -LiteralPath (Join-Path $sourceSkin ('@Resources\'+$name)) -Destination (Join-Path $parallaxRoot '@Resources') -Recurse
}
foreach ($name in @('Settings.inc','GPU.inc')) {
    Copy-Item -LiteralPath (Join-Path $sourceSkin ('@Resources\User\'+$name)) -Destination (Join-Path $parallaxRoot '@Resources\User')
}
$null=New-Item -ItemType Directory -Path (Join-Path $parallaxRoot '@Resources\Scripts')
Copy-Item -LiteralPath (Join-Path $sourceSkin '@Resources\Scripts\SettingsInput.ps1') -Destination (Join-Path $parallaxRoot '@Resources\Scripts')
$utf8=[Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path,[string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path,$Text,$utf8)
}
foreach ($name in @('Layouts','Plugins','Addons','captures')) { $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native GPU settings test, includes fixture instrumentation. Do not distribute."
$globalPath=Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$globalText=Get-Content -LiteralPath $globalPath -Raw
$globalText=[regex]::Replace($globalText,'(?m)^Scale=[^\r\n]*',"Scale=$Scale")
$globalText=[regex]::Replace($globalText,'(?m)^ColumnWidth=[^\r\n]*',"ColumnWidth=$ColumnWidth")
if ($MaxTypography) {
    $styleText=Get-Content -LiteralPath (Join-Path $parallaxRoot '@Resources\Styles.inc') -Raw
    if ($styleText -notmatch '#DividerThickness#' -or $styleText -notmatch '#BorderThickness#') { throw 'Shared styles do not yet consume surface-thickness controls.' }
    $thickness=if ($ColumnWidth -eq 180) {'0'} else {'4'}
    foreach ($entry in @(@('TitleFontSize','12'),@('HeaderFontSize','10'),@('FontSize','10'),@('BorderThickness',$thickness),@('DividerThickness',$thickness))) {
        $pattern='(?m)^'+$entry[0]+'=[^\r\n]*'
        if ($globalText -match $pattern) { $globalText=[regex]::Replace($globalText,$pattern,($entry[0]+'='+$entry[1])) }
        else { $globalText+=[Environment]::NewLine+$entry[0]+'='+$entry[1] }
    }
}
if ($PSBoundParameters.ContainsKey('TitleFontSize')) {
    $pattern='(?m)^TitleFontSize=[^\r\n]*'
    if ($globalText -match $pattern) { $globalText=[regex]::Replace($globalText,$pattern,"TitleFontSize=$TitleFontSize") }
    else { $globalText+=[Environment]::NewLine+"TitleFontSize=$TitleFontSize" }
}
if ($PSBoundParameters.ContainsKey('DataBarThickness')) {
    $pattern='(?m)^DataBarThickness=[^\r\n]*'
    if ($globalText -match $pattern) { $globalText=[regex]::Replace($globalText,$pattern,"DataBarThickness=$DataBarThickness") }
    else { $globalText+=[Environment]::NewLine+"DataBarThickness=$DataBarThickness" }
}
Write-RunFile $globalPath $globalText
$userPath=Join-Path $parallaxRoot '@Resources\User\GPU.inc'
$userText=Get-Content -LiteralPath $userPath -Raw
$userText=[regex]::Replace($userText,'(?m)^Columns=[^\r\n]*','Columns=1')
$userText=[regex]::Replace($userText,'(?m)^PanelHeight=[^\r\n]*',"PanelHeight=$MonitorHeight")
$userText=[regex]::Replace($userText,'(?m)^GPUEnableSensors=[^\r\n]*','GPUEnableSensors=0')
Write-RunFile $userPath $userText
$before=@{}
Get-ChildItem -LiteralPath (Join-Path $parallaxRoot '@Resources\User') -File | ForEach-Object { $before[$_.Name]=(Get-FileHash -LiteralPath $_.FullName).Hash }
$mainPath=Join-Path $parallaxRoot 'GPU\GPU.ini'
$mainText=Get-Content -LiteralPath $mainPath -Raw
$openAction='[!ActivateConfig "Parallax\GPU\Settings" "Settings.ini"]'
if (-not $mainText.Contains('LeftMouseUpAction='+$openAction)) { throw 'Source gear does not open the separate GPU settings config.' }
if ($mainText -notmatch '(?m)^Group=Parallax\|ParallaxGPU\r?$') { throw 'GPU refresh group missing.' }
$suite=Join-Path $PSScriptRoot 'SettingsSuite.lua'
$controller=Join-Path $parallaxRoot '@Resources\Modules\GPU\Settings.lua'
$resultPath=Join-Path $runRoot 'suite-results.txt'
$overviewSuite=Join-Path $PSScriptRoot 'OverviewSuite.lua'
$overviewController=Join-Path $parallaxRoot '@Resources\Modules\GPU\GPU.lua'
$overviewResultPath=Join-Path $runRoot 'overview-results.txt'
$processGraphSuite=Join-Path $PSScriptRoot 'ProcessGraphSuite.lua'
$processGraphController=Join-Path $parallaxRoot '@Resources\Modules\GPU\ProcessGraph.lua'
# ProcessGraph production may use the same UTF-16LE BOM required by Rainmeter;
# its Lua loadfile fixture must receive decoded UTF-8 like Temperature below.
$processGraphFixtureController=Join-Path $runRoot 'ProcessGraphFixture.lua'
Write-RunFile $processGraphFixtureController ([IO.File]::ReadAllText($processGraphController))
$processGraphResultPath=Join-Path $runRoot 'process-graph-results.txt'
$temperatureSuite=Join-Path $PSScriptRoot 'TemperatureSuite.lua'
$temperatureController=Join-Path $parallaxRoot '@Resources\Modules\GPU\Temperature.lua'
# Rainmeter 4.5 recognizes Unicode Lua only with UTF-16LE BOM. Its native
# production measure loads that file; Lua 5.1 loadfile fixtures use decoded UTF-8.
$temperatureFixtureController=Join-Path $runRoot 'TemperatureFixture.lua'
Write-RunFile $temperatureFixtureController ([IO.File]::ReadAllText($temperatureController))
if ($ControllerLifecycle -eq 'LeaseFailure') {
    # Test-stage-only I/O failure: retain the actual controller, helper, session,
    # and native RunCommand. Make only lease writes return a failed open.
    $failureShim=@'
local gpuSmokeOriginalIO = io
local gpuSmokeFailLease = false
local io = setmetatable({open = function(path, mode)
    if gpuSmokeFailLease and mode == 'wb' and path:match('Parallax%-GPU%-%x+%.lease$') then return nil end
    return gpuSmokeOriginalIO.open(path, mode)
end}, {__index = gpuSmokeOriginalIO})
function GPUSmokeFailLease() gpuSmokeFailLease = true end

'@
    [IO.File]::WriteAllText($temperatureController, $failureShim+[IO.File]::ReadAllText($temperatureController), [Text.Encoding]::Unicode)
}
$temperatureResultPath=Join-Path $runRoot 'temperature-results.txt'
$observedPath=Join-Path $runRoot 'gpu-observed.txt'
$mainHarness=Join-Path $runRoot 'MainHarness.lua'
Write-RunFile $mainHarness @"
local opened=false
local last=''
local updatePasses=0
local temperatureUpdates=0
local memoryUpdates,memoryChecks,memoryTransitions=0,0,0
local previousMemoryBindings={}
local function read(path) local f=io.open(path,'rb');if not f then return '' end;local t=f:read('*a');f:close();return t end
local function write(path,value) local f=assert(io.open(path,'wb'));f:write(value);f:close() end
local function observeProcessMemory()
    local evidence,positive,missing={},0,0
    local function check(condition,message)
        memoryChecks=memoryChecks+1
        if not condition then error(message,0) end
    end
    local function finite(value)
        return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
    end
    local function bounds(meter)
        return table.concat({meter:GetX(),meter:GetY(),meter:GetW(),meter:GetH()},',')
    end
    -- Production ProcessGraph.lua formatBytes: decimal steps (1 KB = 1000 bytes), plain unit names.
    local function formatBytes(bytes)
        if bytes<1000 then return string.format('%.0f B',bytes) end
        if bytes<1000000 then return string.format('%.0f KB',bytes/1000) end
        if bytes<1000000000 then return string.format('%.0f MB',bytes/1000000) end
        if bytes<1000000000000 then return string.format('%.2f GB',bytes/1000000000) end
        return string.format('%.2f TB',bytes/1000000000000)
    end
    -- The selected adapter's capacity and LUID from the completed metadata
    -- query, parsed like ProcessGraph.lua's selectedAdapter(). nil while the
    -- query is pending or its text is unusable. Production withholds (--) a
    -- row's dedicated bytes when they exceed this capacity on this LUID.
    local function selectedAdapter()
        local info=SKIN:GetMeasure('MeasureGPUInfo')
        if not info or info:GetValue()~=1 then return nil end
        local output=tostring(info:GetStringValue() or ''):match('^%s*(.-)%s*$'):gsub('\r\n','\n')
        if #output>12000 then return nil end
        local bytes,luid=output:match('^OK|[^|\n]*|(%d+)|[^\n]*\nGPU_ADAPTER|1|(%x+)$')
        local capacity=bytes and #bytes<=16 and tonumber(bytes)
        if finite(capacity) and capacity>=1 and capacity<=9007199254740991 and luid and #luid==16 then
            return {capacity=capacity,luid=luid:upper()}
        end
        return nil
    end
    memoryUpdates=memoryUpdates+1
    local ok,problem=pcall(function()
        local adapter=selectedAdapter()
        evidence[#evidence+1]='AdapterCapacity='..(adapter and string.format('%.0f',adapter.capacity) or 'unknown')
        evidence[#evidence+1]='AdapterLuid='..(adapter and adapter.luid or 'unknown')
        -- Group the five raw ranks by PID in rank order, exactly as
        -- ProcessGraph.lua does: the first sighting of a PID owns its row and
        -- its busiest-engine identity; later sightings add no row.
        local rows,seen={},{}
        for rank=1,5 do
            local prefix='Rank'..rank..'.'
            local engine=SKIN:GetMeasure(rank==1 and 'MeasureGPUActivity' or ('MeasureGPUProcess'..rank))
            check(engine,'Missing native process bank at rank '..rank)
            local raw,value=engine:GetStringValue(),engine:GetValue()
            evidence[#evidence+1]=prefix..'RawEngine='..tostring(raw)
            evidence[#evidence+1]=prefix..'EnginePercent='..tostring(value)
            raw=tostring(raw or ''):match('^%s*(.-)%s*$')
            -- Production rawObservation(): a ranked PID / LUID / engine
            -- instance with a positive in-range percentage.
            local pid=raw:match('^pid_(%d+)_')
            local ranked=pid~=nil and #pid<=16 and tonumber(pid)>=1 and tonumber(pid)<=4294967295
                and raw:find('_luid_',1,true)~=nil and raw:match('_eng_%d+_')~=nil
                and finite(value) and value>0 and value<=100
            -- Production memoryIdentity(): the exact PID / LUID / physical GPU
            -- prefix that may be supplied as a UsageMonitor Name.
            local identity,_,physical,engineIndex=raw:match('^(pid_(%d+)_luid_0x%x%x%x%x%x%x%x%x_0x%x%x%x%x%x%x%x%x_phys_(%d+))_eng_(%d+)_engtype_.*$')
            if identity and (#raw>1024 or #physical>10 or tonumber(physical)>4294967295 or #engineIndex>10 or tonumber(engineIndex)>4294967295) then identity=nil end
            evidence[#evidence+1]=prefix..'Ranked='..tostring(ranked and true or false)
            if ranked then
                local key=tonumber(pid)
                if not seen[key] then
                    seen[key]=true
                    rows[#rows+1]={rank=rank,pid=pid,raw=raw,value=value,identity=identity}
                else
                    evidence[#evidence+1]=prefix..'GroupedIntoPid='..pid
                end
            end
        end
        evidence[#evidence+1]='DistinctPids='..#rows
        local bottom=SKIN:ParseFormula(SKIN:ReplaceVariables('(#Inset#+#PanelHeightPx#)'))
        for slot=1,5 do
            local prefix='Row'..slot..'.'
            local row=rows[slot]
            local memory=SKIN:GetMeasure('MeasureGPUProcessMemory'..slot)
            local name=SKIN:GetMeter('MeterGPUProcessName'..slot)
            local label=SKIN:GetMeter('MeterGPUProcessMemory'..slot)
            local value=SKIN:GetMeter('MeterGPUProcessValue'..slot)
            check(memory and name and label and value,'Missing native memory bank or row meter at slot '..slot)
            local wanted=memory:GetOption('Name','')
            local returned,bytes=memory:GetStringValue(),memory:GetValue()
            local text,tip=label:GetOption('Text',''),label:GetOption('ToolTipText','')
            local nameText,valueText=name:GetOption('Text',''),value:GetOption('Text','')
            -- Rainmeter reports zero width and height for a hidden meter, so
            -- this is the runtime !ShowMeterGroup / !HideMeterGroup state.
            local visible=name:GetH()>0
            evidence[#evidence+1]=prefix..'Visible='..tostring(visible)
            evidence[#evidence+1]=prefix..'RequestedInstance='..wanted
            evidence[#evidence+1]=prefix..'ReturnedInstance='..tostring(returned)
            evidence[#evidence+1]=prefix..'RawBytes='..tostring(bytes)
            evidence[#evidence+1]=prefix..'NameText='..nameText
            evidence[#evidence+1]=prefix..'ValueText='..valueText
            evidence[#evidence+1]=prefix..'MemoryText='..text
            evidence[#evidence+1]=prefix..'MemoryTip='..tip
            for _,option in ipairs({'Alias','Category','Counter','Index','RawValue','PIDToName','Rollup','Percent','Disabled'}) do
                evidence[#evidence+1]=prefix..option..'Option='..memory:GetOption(option,'')
            end
            evidence[#evidence+1]=prefix..'NameBounds='..bounds(name)
            evidence[#evidence+1]=prefix..'MemoryBounds='..bounds(label)
            evidence[#evidence+1]=prefix..'ValueBounds='..bounds(value)
            check(memory:GetOption('Alias','')=='' and memory:GetOption('Category','')=='GPU Process Memory' and memory:GetOption('Counter','')=='Local Usage','Memory bank does not read GPU Process Memory / Local Usage at slot '..slot)
            for _,option in ipairs({'Index','PIDToName','Rollup','Percent'}) do
                check(memory:GetOption(option,'')=='0','Memory bank enables ranking, renaming, rollup or normalization at slot '..slot..': '..option)
            end
            check(memory:GetOption('RawValue','')=='1','Memory bank does not expose raw local bytes at slot '..slot)
            -- This observes one completed native measure pass. Name is the
            -- exact parser option after the controller's rebind, and returned
            -- string/value are the plugin's current pair, not another slot.
            if previousMemoryBindings[slot] and previousMemoryBindings[slot]~=wanted then memoryTransitions=memoryTransitions+1 end
            previousMemoryBindings[slot]=wanted
            if row then
                check(visible,'Row '..slot..' is hidden although rank '..row.rank..' ranks a distinct PID')
                local percentage=row.value<0.1 and '<0.1%' or string.format('%.1f%%',row.value)
                check(valueText==percentage,'GPU percentage does not match the busiest ranked engine of its PID at row '..slot)
                check(nameText~='' and nameText~='--' and nameText~='No active GPU process data','Ranked row has no process label at row '..slot)
                if row.identity then
                    check(wanted==row.identity,'Memory request does not match the exact current PID / LUID / physical GPU at row '..slot)
                    local usable=returned==row.identity and finite(bytes) and bytes>0 and bytes<=9007199254740991 and bytes==math.floor(bytes)
                    if usable then
                        local high,low=row.identity:match('_luid_0x(%x%x%x%x%x%x%x%x)_0x(%x%x%x%x%x%x%x%x)_')
                        local capped=adapter~=nil and high~=nil and (high..low):upper()==adapter.luid and bytes>adapter.capacity
                        if capped then
                            check(text=='--','Dedicated bytes above the selected adapter capacity are presented as measured at row '..slot)
                            check(tip:find(row.identity,1,true)~=nil and tip:find(string.format('%.0f bytes',bytes),1,true)~=nil and tip:find('withheld',1,true)~=nil,'Withheld VRAM tooltip omits its identity, raw byte reading or reason at row '..slot)
                            missing=missing+1
                        else
                            check(text==formatBytes(bytes),'Native VRAM text does not match its exact requested instance and positive raw bytes at row '..slot)
                            check(tip:find(row.identity,1,true)~=nil and tip:find(string.format('%.0f bytes',bytes),1,true)~=nil,'VRAM tooltip omits its exact identity or raw byte reading at row '..slot)
                            positive=positive+1
                        end
                    else
                        check(text=='--','Missing, zero or mismatched native memory counter is presented as measured capacity at row '..slot)
                        missing=missing+1
                    end
                else
                    check(wanted=='__ParallaxNoGPUProcess__','Ranked row without an exact memory identity retained a memory request at row '..slot)
                    check(text=='--','Ranked row without an exact memory identity shows a memory reading at row '..slot)
                    missing=missing+1
                end
            else
                check(wanted=='__ParallaxNoGPUProcess__','Idle slot retained an active memory request at slot '..slot)
                if slot==1 then
                    check(visible,'The first row is hidden although no PID is ranked')
                    check(nameText=='No active GPU process data' and valueText=='--' and text=='--','Empty ranking is not explained on the first row')
                else
                    check(not visible,'Slot '..slot..' is visible although only '..#rows..' distinct PIDs are ranked')
                end
                missing=missing+1
            end
            -- Native meter dimensions are available after the first draw.
            -- DisabledOption above is the configuration text, not proof of
            -- the current !EnableMeasure / !DisableMeasure runtime state.
            if memoryUpdates>1 and visible then
                check(name:GetW()>0 and label:GetW()>0 and label:GetH()>0 and value:GetW()>0 and value:GetH()>0,'Visible process row has no native bounds at row '..slot)
                check(name:GetY()==label:GetY() and name:GetY()==value:GetY() and name:GetH()==label:GetH() and name:GetH()==value:GetH(),'Process name, VRAM and GPU percentage do not share one row at row '..slot)
                -- Centered strings report their laid-out left edge from GetX.
                check(name:GetX()+name:GetW()<=label:GetX(),'Process name overlaps the VRAM column at row '..slot)
                check(label:GetX()+label:GetW()<=value:GetX(),'VRAM column overlaps the GPU percentage column at row '..slot)
                check(bottom and name:GetY()+name:GetH()<=bottom,'Visible process row extends below the painted monitor at row '..slot)
            end
        end
    end)
    evidence[#evidence+1]='PositiveRows='..positive
    evidence[#evidence+1]='UnavailableRows='..missing
    evidence[#evidence+1]='Updates='..memoryUpdates
    evidence[#evidence+1]='BindingTransitions='..memoryTransitions
    write([=[$runRoot\process-memory-observed.txt]=],table.concat(evidence,'\n'))
    local auditPath=[=[$runRoot\process-memory-audit.txt]=]
    -- A later idle pass or settings refresh must not overwrite a real failure.
    if not read(auditPath):match('^FAIL:') then
        write(auditPath,ok and ('PASS: '..memoryChecks..' native per-row memory checks; updates='..memoryUpdates..'; binding transitions='..memoryTransitions)
            or ('FAIL: '..tostring(problem)..'\n'..table.concat(evidence,'\n')))
    end
end
local function runSuite(path,suite,controller)
    if read(path)~='' then return end
    local ok,result=pcall(function()local n,r=dofile(suite).run(controller);return 'PASS: '..n..' assertions under '.._VERSION..'\n'..r end)
    write(path,ok and result or ('FAIL: '..tostring(result)))
end
function Initialize()
    local t={};for _,key in ipairs({'Columns','PanelHeight','GPUEnableSensors','GPUPowerIndex','GPUPowerSensor','GPUPowerLabel','GPUPowerSource','GPUClockSource'}) do t[#t+1]=key..'='..SKIN:GetVariable(key) end
    write([=[$observedPath]=],table.concat(t,'\n'))
    runSuite([=[$resultPath]=],[=[$suite]=],[=[$controller]=])
    runSuite([=[$overviewResultPath]=],[=[$overviewSuite]=],[=[$overviewController]=])
    runSuite([=[$processGraphResultPath]=],[=[$processGraphSuite]=],[=[$processGraphFixtureController]=])
    runSuite([=[$temperatureResultPath]=],[=[$temperatureSuite]=],[=[$temperatureFixtureController]=])
end
function Update()
    updatePasses=updatePasses+1
    -- Pass 1 is the synchronous Update(refresh=true) inside Skin::Refresh. At
    -- startup that refresh runs inside Rainmeter::ActivateActiveSkins, whose
    -- loop over the Rainmeter.ini skin folders has not yet reached
    -- Parallax\GPU\Settings. An !ActivateConfig issued from this pass marks
    -- that folder active, so the loop activates it a second time and
    -- Rainmeter 4.5 logs WARN '!ActivateConfig: "Parallax\GPU\Settings" is
    -- already active' against the settings skin. The gear is a mouse action
    -- and can only run from the message loop, so emulate it, and every other
    -- harness command, from a timer-driven pass only.
    if updatePasses>1 then
        if read([=[$runRoot\opened.txt]=])=='' then write([=[$runRoot\opened.txt]=],'opened');SKIN:Bang([=[$openAction]=]) end
        local command=read([=[$runRoot\main-command.txt]=])
        if command=='deactivate' then SKIN:Bang('!DeactivateConfig');return 0 end
        if command~='' and command~=last then
            last=command
            if command=='stop' then SKIN:Bang('!CommandMeasure','MeasureGPUTemperatureController','Stop()')
            elseif command=='leasefailure' then SKIN:Bang('!CommandMeasure','MeasureGPUTemperatureController','GPUSmokeFailLease()')
            else SKIN:Bang([=[$openAction]=]) end
            write([=[$runRoot\main-done.txt]=],command)
        end
    end
    local info={}
    for _,name in ipairs({'MeterAdapterName','MeterAdapterDetails'}) do
        local meter=SKIN:GetMeter(name);if meter then info[#info+1]=name..'='..meter:GetOption('Text','') end
    end
    write([=[$runRoot\metadata-observed.txt]=],table.concat(info,'\n'))
    local graph={}
    for i=1,5 do
        for _,part in ipairs({'Name','Value','Memory'}) do
            local name='MeterGPUProcess'..part..i
            local meter=SKIN:GetMeter(name)
            if meter then graph[#graph+1]=name..'='..meter:GetOption('Text','') end
        end
    end
    write([=[$runRoot\process-graph-observed.txt]=],table.concat(graph,'\n'))
    observeProcessMemory()
    local processController=SKIN:GetMeasure('MeasureGPUProcessController')
    local telemetryController=SKIN:GetMeasure('MeasureGPUTemperatureController')
    write([=[$runRoot\process-names-observed.txt]=],
        'RequestedPids='..(processController and processController:GetStringValue() or '')..'\n'
        ..'NamesPacket='..(telemetryController and telemetryController:GetStringValue() or ''))
    temperatureUpdates=temperatureUpdates+1
    local temperature={'Updates='..temperatureUpdates}
    local meter=SKIN:GetMeter('MeterTemperatureValue')
    if meter then
        temperature[#temperature+1]='MeterTemperatureValue='..meter:GetOption('Text','')
        temperature[#temperature+1]='ToolTipText='..meter:GetOption('ToolTipText','')
    end
    write([=[$runRoot\temperature-observed.txt]=],table.concat(temperature,'\n'))
    local metrics={}
    for _,name in ipairs({'MeterActivityValue','MeterGPUVRAMValue','MeterGPUVRAMBar','MeterGPUSharedValue','MeterGPULoadValue','MeterGPULoadBar','MeterGPUControllerLoadValue','MeterGPUControllerLoadBar','MeterGPUVideoLoadValue','MeterGPUVideoLoadBar','MeterGPUBusLoadValue','MeterGPUBusLoadBar','MeterPowerValue','MeterClockValue'}) do
        local metric=SKIN:GetMeter(name)
        if metric then metrics[#metrics+1]=name..'='..metric:GetOption(name:find('Bar$') and 'Shape2' or 'Text','') end
    end
    write([=[$runRoot\driver-metrics-observed.txt]=],table.concat(metrics,'\n'))
    local bootstrap=SKIN:GetMeasure('MeasureGPUTemperatureBootstrap')
    write([=[$runRoot\temperature-session.txt]=],bootstrap:GetStringValue())
    write([=[$runRoot\driver-status.txt]=],tostring(SKIN:GetMeasure('MeasureGPUTemperatureDriver'):GetValue()))
    return 0
end
"@
$mainText+="`n[MeasureGPUSettingsTest]`nMeasure=Script`nScriptFile=$mainHarness`n"
Write-RunFile $mainPath $mainText
$popupPath=Join-Path $parallaxRoot 'GPU\Settings\Settings.ini'
$popupText=Get-Content -LiteralPath $popupPath -Raw
$popupHarness=Join-Path $runRoot 'PopupHarness.lua'
Write-RunFile $popupHarness @"
local last=''
local function read(path) local f=io.open(path,'rb');if not f then return '' end;local t=f:read('*a');f:close();return t end
local function write(path,value) local f=assert(io.open(path,'wb'));f:write(value);f:close() end
function Initialize() last=read([=[$runRoot\popup-command.txt]=]) end
function Update()
    local command=read([=[$runRoot\popup-command.txt]=])
    local actions={columns='StepColumns(1)',columnsupper='StepColumns(1)',columnslower='StepColumns(-1)',sensors='ToggleSensors()',fit='FitHeight()',powersource="CycleSource('Power')",clocksource="CycleSource('Clock')",browse="Browse('Power')",rescan='Rescan()',select='Select(1)',close='Close()',closeagain='Close()'}
    if command~='' and command~=last then
        last=command
        if command:match('^typed%d+$') then
            -- Replay the production center action, not a test-only save function.
            local center=SKIN:GetMeter('MeterSettingsColumnsValue')
            if center then SKIN:Bang(center:GetOption('LeftMouseUpAction','')) end
        else local action=actions[command];if action then SKIN:Bang('!CommandMeasure','MeasureGPUSettings',action) end end
        write([=[$runRoot\popup-done.txt]=],command)
    end
    local out={'Columns='..SKIN:GetVariable('Columns'),'PanelHeight='..SKIN:GetVariable('PanelHeight')}
    for _,name in ipairs({'MeterSettingsColumnsValue','MeterSettingsHeightValue','MeterSettingsSensorsValue','MeterSettingsTemperatureValue','MeterSettingsPowerSourceValue','MeterSettingsClockSourceValue','MeterSettingsPowerValue','MeterSettingsNotice','MeterSettingsPick1','MeterSettingsTitle'}) do
        local meter=SKIN:GetMeter(name);if meter then out[#out+1]=name..'='..meter:GetOption('Text','') end
    end
    write([=[$runRoot\settings-observed.txt]=],table.concat(out,'\n'))
    local m=SKIN:GetMeasure('MeasureGPUDiscover');write([=[$runRoot\discovery-observed.txt]=],tostring(m:GetValue())..'\n'..m:GetStringValue())
    local input=SKIN:GetMeasure('MeasureGPUSettingsInput')
    write([=[$runRoot\typed-input-observed.txt]=],tostring(input:GetValue())..'\n'..input:GetStringValue())
    return 0
end
"@
$popupText=[regex]::Replace($popupText,'(?m)^Update=1000','Update=250')
$popupText+="`n[MeasureGPUSettingsPopupTest]`nMeasure=Script`nScriptFile=$popupHarness`n"
Write-RunFile $popupPath $popupText
$helperPath=Join-Path $parallaxRoot '@Resources\Modules\GPU\DiscoverExports.ps1.txt'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw 'Production discovery helper omitted by staging.' }
$iniPath=Join-Path $runRoot 'Rainmeter.ini'
Write-RunFile $iniPath @"
[Rainmeter]
SkinPath=$runRoot\Skins\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0
[Parallax\GPU]
Active=1
WindowX=-20000
WindowY=-20000
KeepOnScreen=0
Draggable=0
ClickThrough=1
[Parallax\GPU\Settings]
Active=0
WindowX=-20000
WindowY=-20000
KeepOnScreen=0
Draggable=0
ClickThrough=1
"@
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
$preview=Get-Content -LiteralPath (Join-Path $projectRoot 'tools\Preview-Parallax.ps1') -Raw
$definition=[regex]::Match($preview,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxPreviewNative' -as [type])) { Add-Type -TypeDefinition $definition }
if (-not ('GpuSmokeProcessTree' -as [type])) { Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class GpuSmokeProcessTree {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    private struct Entry {
        public uint Size, Usage, Id; public UIntPtr Heap;
        public uint Module, Threads, Parent; public int Priority; public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string Name;
    }
    [DllImport("kernel32.dll")] private static extern IntPtr CreateToolhelp32Snapshot(uint flags,uint id);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] private static extern bool Process32FirstW(IntPtr h,ref Entry e);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] private static extern bool Process32NextW(IntPtr h,ref Entry e);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr h);
    public static uint[] Children(uint parent) {
        var result=new List<uint>(); var h=CreateToolhelp32Snapshot(2,0);
        if(h==new IntPtr(-1)) throw new InvalidOperationException("Process snapshot unavailable.");
        try {var e=new Entry();e.Size=(uint)Marshal.SizeOf(typeof(Entry));
            for(bool more=Process32FirstW(h,ref e);more;more=Process32NextW(h,ref e)) {
                if(e.Parent==parent && String.Equals(e.Name,"powershell.exe",StringComparison.OrdinalIgnoreCase))result.Add(e.Id);
                e.Size=(uint)Marshal.SizeOf(typeof(Entry));
            }
        } finally {CloseHandle(h);} return result.ToArray();
    }
}
'@ }
function Wait-Condition([scriptblock]$Condition,[string]$Message,[int]$Seconds=12) {
    $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
    do { if (& $Condition) { return };Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $deadline)
    throw $Message
}
function Own-Windows { @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id)) }
function Text-Matches([string]$Path,[string]$Pattern) { (Test-Path -LiteralPath $Path) -and ((Get-Content -LiteralPath $Path -Raw) -match $Pattern) }
function Temperature-Updates {
    $path=Join-Path $runRoot 'temperature-observed.txt'
    if (Test-Path -LiteralPath $path) {
        $match=[regex]::Match((Get-Content -LiteralPath $path -Raw),'(?m)^Updates=(\d+)\r?$')
        if ($match.Success) { return [int]$match.Groups[1].Value }
    }
    return 0
}
function Read-DriverSnapshot([string]$Path) {
    # The provider atomically replaces this file. Permit delete-sharing and
    # retry transient rename contention instead of failing a healthy sample.
    for ($attempt=0;$attempt -lt 20;$attempt++) {
        $stream=$null;$reader=$null
        try {
            $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII)
            $value=$reader.ReadToEnd()
            if ($value.Length -le 4096) {return ,($value.Trim() -split '\|')}
            throw 'Oversized direct driver snapshot.'
        } catch [IO.IOException] {
            Start-Sleep -Milliseconds 100
        } finally {
            if ($null -ne $reader) {$reader.Dispose()} elseif ($null -ne $stream) {$stream.Dispose()}
        }
    }
    throw 'Direct driver snapshot remained unreadable.'
}
function Action([string]$Name) {
    Write-RunFile (Join-Path $runRoot 'popup-command.txt') $Name
    Wait-Condition { Text-Matches (Join-Path $runRoot 'popup-done.txt') ('^'+$Name+'$') } "Action not delivered: $Name"
    Start-Sleep -Milliseconds 800
}
function Capture([string]$Suffix) {
    Wait-Condition { @(Own-Windows | Where-Object {$_.Width -le 0 -or $_.Height -le 0}).Count -eq 0 } 'Native windows did not finish creating their bounds.'
    Start-Sleep -Milliseconds 500
    $memoryAuditPath=Join-Path $runRoot 'process-memory-audit.txt'
    Wait-Condition {Test-Path -LiteralPath $memoryAuditPath} 'Native process-memory observation did not run.'
    $memoryAudit=Get-Content -LiteralPath $memoryAuditPath -Raw
    if ($memoryAudit -notmatch '^PASS:') {throw $memoryAudit}
    foreach ($window in (Own-Windows)) {
        $name=if ($window.Title -match 'GPU[\\/]Settings') {'GPU-Settings'} else {'GPU'}
        $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height);$graphics=[Drawing.Graphics]::FromImage($bitmap);$hdc=[IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta);$hdc=$graphics.GetHdc();$printed=[ParallaxPreviewNative]::PrintWindow($window.Handle,$hdc,2);$graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
            if (-not $printed) { throw 'PrintWindow failed.' }
            $bitmap.Save((Join-Path $runRoot "captures\$name$Suffix.png"),[Drawing.Imaging.ImageFormat]::Png)
            Write-Output "$name$Suffix window: $($window.Width)x$($window.Height)"
        } finally { if ($hdc -ne [IntPtr]::Zero) {$graphics.ReleaseHdc($hdc)};$graphics.Dispose();$bitmap.Dispose() }
    }
}
function Test-TypedColumns {
    # Exercise the real GPU center action and owned RunCommand with the shared
    # helper. Only its staged modal boundary is replaced, following the native
    # HWND/event method in tools/tests/Test-SettingsInput.ps1. No visible window,
    # global input, other process's window, or live configuration is used.
    $inputPath=Join-Path $parallaxRoot '@Resources\Scripts\SettingsInput.ps1'
    $inputSource=[IO.File]::ReadAllText($inputPath)
    $modal='$null = $form.ShowDialog()'
    if ([regex]::Matches($inputSource,[regex]::Escape($modal)).Count -ne 1) {throw 'Shared input modal boundary changed.'}
    if (-not (Text-Matches (Join-Path $runRoot 'typed-input-observed.txt') '(?m)^-1\r?$')) {throw 'First typed case must exercise the native initial RunCommand status -1.'}
    $boundary=@'
try {
if ($Key -cne 'UtilityNumber' -or $Minimum -cne '1' -or $Maximum -cne '2' -or $DecimalPlaces -cne '0') { throw 'Unexpected Columns editor contract.' }
if ($form.FormBorderStyle -ne [Windows.Forms.FormBorderStyle]::None -or $form.ShowInTaskbar) { throw 'Unexpected editor window.' }
if ($form.Controls.Count -ne 1 -or $box.Text -cne '__INITIAL__') { throw 'Unexpected editor initial value.' }
$null = $form.Handle
$null = $box.Handle
$form.PerformLayout()
$boxScreen = $box.PointToScreen([Drawing.Point]::Empty)
# Native WinForms imposes a 16-physical-pixel minimum on this tested Windows
# host: the scale.75 field requests 15 pixels and receives 16. Keep that exact
# bounded allowance rather than ignoring height; position/width stay exact.
$expectedHeight=[Math]::Max([int]$Height,16)
if ($form.Location.X -ne [int]$X -or $form.Location.Y -ne [int]$Y -or $form.Width -ne [int]$Width -or $form.Height -ne $expectedHeight) { throw ('Unexpected editor HWND bounds: '+$form.Bounds.ToString()+'; requested '+$X+','+$Y+','+$Width+','+$Height) }
if ($boxScreen.X -ne ([int]$X+1) -or $boxScreen.Y -ne ([int]$Y+1) -or $box.Width -ne ([int]$Width-2) -or $box.Height -ne ($expectedHeight-2)) { throw ('Unexpected TextBox HWND bounds: '+$box.Bounds.ToString()+'; screen '+$boxScreen.ToString()) }
$testBounds=$form.Bounds.ToString()
$box.Text = '__TEXT__'
$tip.Active = $false
$onKeyDown = $box.GetType().GetMethod('OnKeyDown', [Reflection.BindingFlags]'Instance,NonPublic')
$keyCode = if ('__ACTION__' -eq 'escape') { [Windows.Forms.Keys]::Escape } else { [Windows.Forms.Keys]::Enter }
$keyEvent = New-Object Windows.Forms.KeyEventArgs($keyCode)
$null = $onKeyDown.Invoke($box, [object[]]@($keyEvent.PSObject.BaseObject))
if ('__ACTION__' -eq 'invalid') {
    if ($form.IsDisposed -or $form.BackColor.R -ne 230 -or $form.Tag.Response -cne 'PARALLAX_INPUT_V1|cancel|') { throw 'Invalid Columns input did not remain open with an error.' }
    $escapeEvent = New-Object Windows.Forms.KeyEventArgs([Windows.Forms.Keys]::Escape)
    $null = $onKeyDown.Invoke($box, [object[]]@($escapeEvent.PSObject.BaseObject))
}
[IO.File]::WriteAllText('__EVIDENCE__', ('PASS: owned native Columns HWND and __ACTION__ handler' + [Environment]::NewLine + 'RequestedWidth='+$Width+';RequestedHeight='+$Height + [Environment]::NewLine + 'Bounds=' + $testBounds + [Environment]::NewLine + 'Response=' + $form.Tag.Response))
} catch {
    # The production helper intentionally returns cancel on failures. Preserve
    # diagnostics only in this generated test stage before that outer catch.
    [IO.File]::WriteAllText('__EVIDENCE__', ('FAIL: owned native Columns boundary: '+$_.Exception.ToString()))
    throw
}
'@
    $scenarios=@(
        @{Initial='1';Text='2';Action='enter';Columns='2';Response='PARALLAX_INPUT_V1|ok|2';Changed=$true},
        @{Initial='2';Text='1';Action='escape';Columns='2';Response='PARALLAX_INPUT_V1|cancel|';Changed=$false},
        @{Initial='2';Text='3';Action='invalid';Columns='2';Response='PARALLAX_INPUT_V1|cancel|';Changed=$false},
        @{Initial='2';Text='1';Action='enter';Columns='1';Response='PARALLAX_INPUT_V1|ok|1';Changed=$true}
    )
    try {
        for ($case=0;$case -lt $scenarios.Count;$case++) {
            $scenario=$scenarios[$case]
            $nativeEvidence=Join-Path $runRoot ('typed-columns-'+($case+1)+'-native.txt')
            $caseBoundary=$boundary.Replace('__INITIAL__',$scenario.Initial).Replace('__TEXT__',$scenario.Text).Replace('__ACTION__',$scenario.Action).Replace('__EVIDENCE__',$nativeEvidence.Replace("'","''"))
            Write-RunFile $inputPath ($inputSource.Replace($modal,$caseBoundary))
            $beforeTypedHash=(Get-FileHash -LiteralPath $userPath).Hash
            $beforeTypedReload=(Get-Item -LiteralPath $observedPath).LastWriteTimeUtc
            Action ('typed'+($case+1))
            Wait-Condition {Test-Path -LiteralPath $nativeEvidence} 'Owned native Columns helper did not complete its actual window/event checks.' 20
            if (-not (Text-Matches $nativeEvidence '^PASS:')) {throw (Get-Content -LiteralPath $nativeEvidence -Raw)}
            Wait-Condition {
                (Text-Matches (Join-Path $runRoot 'typed-input-observed.txt') '(?m)^1\r?$') -and
                (Text-Matches (Join-Path $runRoot 'typed-input-observed.txt') ('(?m)^'+[regex]::Escape($scenario.Response)+'\r?$'))
            } 'Typed Columns result did not reach the production completion action.' 12
            Wait-Condition {Text-Matches $observedPath ('(?m)^Columns='+$scenario.Columns+'\r?$')} 'Typed Columns did not preserve or reload the expected monitor width.' 12
            if (-not $scenario.Changed -and ((Get-FileHash -LiteralPath $userPath).Hash -ne $beforeTypedHash -or (Get-Item -LiteralPath $observedPath).LastWriteTimeUtc -ne $beforeTypedReload)) {throw 'Cancelled or invalid Columns input wrote preferences or refreshed GPU.'}
            if (-not (Text-Matches (Join-Path $runRoot 'settings-observed.txt') '(?m)^PanelHeight=648\r?$')) {throw 'Typed Columns changed settings geometry.'}
            Write-RunFile (Join-Path $runRoot ('typed-columns-'+($case+1)+'-result.txt')) (Get-Content -LiteralPath (Join-Path $runRoot 'typed-input-observed.txt') -Raw)
        }
    } finally {Write-RunFile $inputPath $inputSource}
    Write-Output 'PASS: typed Columns launch from initial status -1, valid Enter/save/reload, Escape, invalid-range recovery, no cancel/invalid writes or refresh, and restoration to one column; only owned unshown helper HWNDs used.'
}
try {
    $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Wait-Condition { (Own-Windows).Count -eq 2 } 'Gear failed to open a separate settings window.'
    Wait-Condition { Test-Path -LiteralPath (Join-Path $runRoot 'settings-observed.txt') } 'Missing native settings observation.'
    Start-Sleep -Seconds 3
    if ($MaxTypography -or $CaptureOnly) {
        Wait-Condition {
            $metadataPath=Join-Path $runRoot 'metadata-observed.txt'
            (Text-Matches $metadataPath '(?m)^MeterAdapterName=.+') -and
                -not (Text-Matches $metadataPath 'Checking\.\.\.') -and
                (-not $MaxTypography -or -not (Text-Matches $metadataPath 'GPU name unavailable|No discrete GPU|Multiple discrete GPUs'))
        } 'GPU metadata did not complete for capture.' 30
    }
    if ($CaptureOnly) {
        $temperatureBaseline=Temperature-Updates
        Wait-Condition { (Temperature-Updates) -ge ($temperatureBaseline+3) -and (Text-Matches (Join-Path $runRoot 'temperature-observed.txt') '(?m)^MeterTemperatureValue=(?!Checking).+') } 'Temperature did not settle after metadata.' 40
    }
    foreach ($entry in $before.GetEnumerator()) { if ((Get-FileHash -LiteralPath (Join-Path $parallaxRoot ('@Resources\User\'+$entry.Key))).Hash -ne $entry.Value) { throw 'Opening wrote a preference file.' } }
    $suiteResult=Get-Content -LiteralPath $resultPath -Raw
    if ($suiteResult -notmatch '^PASS:') { throw $suiteResult }
    Write-Output (($suiteResult -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    $overviewResult=Get-Content -LiteralPath $overviewResultPath -Raw
    if ($overviewResult -notmatch '^PASS:') { throw $overviewResult }
    Write-Output (($overviewResult -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    $processGraphResult=Get-Content -LiteralPath $processGraphResultPath -Raw
    if ($processGraphResult -notmatch '^PASS:') { throw $processGraphResult }
    Write-Output (($processGraphResult -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    $temperatureResult=Get-Content -LiteralPath $temperatureResultPath -Raw
    if ($temperatureResult -notmatch '^PASS:') { throw $temperatureResult }
    Write-Output (($temperatureResult -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    Capture ''
    if ($TypedColumns) {Test-TypedColumns}
    if (-not $CaptureOnly) {
        $lowerHash=(Get-FileHash -LiteralPath $userPath).Hash
        $lowerReload=(Get-Item -LiteralPath $observedPath).LastWriteTimeUtc
        Action 'columnslower'
        if ((Get-FileHash -LiteralPath $userPath).Hash -ne $lowerHash -or (Get-Item -LiteralPath $observedPath).LastWriteTimeUtc -ne $lowerReload) {throw 'Lower Columns bound wrote or refreshed.'}
        Action 'columns';Wait-Condition {Text-Matches $observedPath '(?m)^Columns=2$'} 'GPU did not reload saved columns.'
        $upperHash=(Get-FileHash -LiteralPath $userPath).Hash
        $upperReload=(Get-Item -LiteralPath $observedPath).LastWriteTimeUtc
        Action 'columnsupper'
        if ((Get-FileHash -LiteralPath $userPath).Hash -ne $upperHash -or (Get-Item -LiteralPath $observedPath).LastWriteTimeUtc -ne $upperReload) {throw 'Upper Columns bound wrote or refreshed.'}
        Action 'sensors';Wait-Condition {Text-Matches $observedPath '(?m)^GPUEnableSensors=1$'} 'GPU did not reload saved sensor toggle.'
        Action 'powersource';Wait-Condition {Text-Matches $observedPath '(?m)^GPUPowerSource=1$'} 'Explicit HWiNFO power source did not persist.'
        Action 'clocksource';Wait-Condition {Text-Matches $observedPath '(?m)^GPUClockSource=1$'} 'Explicit HWiNFO clock source did not persist.'
        Action 'powersource';Wait-Condition {Text-Matches $observedPath '(?m)^GPUPowerSource=0$'} 'Driver power source did not persist.'
        Action 'clocksource';Wait-Condition {Text-Matches $observedPath '(?m)^GPUClockSource=0$'} 'Driver clock source did not persist.'
        Action 'fit';Wait-Condition {Text-Matches $observedPath '(?m)^PanelHeight=462$'} 'GPU did not reload fitted height.'
        if (-not (Text-Matches (Join-Path $runRoot 'settings-observed.txt') '(?m)^PanelHeight=648$')) { throw 'Settings geometry changed with monitor height.' }
        Action 'browse';Wait-Condition {Text-Matches (Join-Path $runRoot 'discovery-observed.txt') '(?m)^1\r?$'} 'Real discovery did not complete.'
        $realDiscovery=Get-Content -LiteralPath (Join-Path $runRoot 'discovery-observed.txt') -Raw
        Write-RunFile (Join-Path $runRoot 'real-discovery-result.txt') $realDiscovery
        Capture '-real-discovery'
        $hex={param($value) ([Text.Encoding]::UTF8.GetBytes($value) | ForEach-Object {$_.ToString('X2')}) -join ''}
        $fixture='GPU_EXPORTS|1|OK|'+(& $hex 'HKEY_CURRENT_USER')+'|'+(& $hex 'SOFTWARE\HWiNFO64\VSB')+'|0|0'+[Environment]::NewLine+'ITEM|7|'+(& $hex 'GPU [#0]: Test adapter')+'|'+(& $hex 'GPU Power')+'|'+(& $hex '55 W')+'|'+(& $hex '55')
        Write-RunFile $helperPath ("[Console]::OutputEncoding=[Text.UTF8Encoding]::new(`$false);[Console]::Write('"+$fixture+"')")
        Action 'rescan';Wait-Condition {Text-Matches (Join-Path $runRoot 'settings-observed.txt') 'MeterSettingsPick1=7: GPU Power / 55 W'} 'Fixture discovery list did not render.'
        Capture '-fixture'
        Action 'select';Wait-Condition {Text-Matches $observedPath '(?m)^GPUPowerSensor=GPU \[#0\]: Test adapter$'} 'Exact ordinal sensor identity did not survive native persistence and GPU reload.'
        if (-not (Text-Matches $observedPath '(?m)^GPUPowerIndex=7$')) { throw 'Selected export index was not saved.' }
        Action 'close';Wait-Condition {(Own-Windows).Count -eq 1} 'Close did not leave only GPU active.'
        if ((Own-Windows)[0].Title -match 'GPU[\\/]Settings') { throw 'GPU closed instead of settings.' }
        Write-RunFile (Join-Path $runRoot 'main-command.txt') 'reopen'
        Wait-Condition {(Own-Windows).Count -eq 2} 'Reopening settings failed.'
        Wait-Condition {Text-Matches (Join-Path $runRoot 'settings-observed.txt') 'MeterSettingsPowerValue=GPU Power'} 'Reopening lost saved mapping.'
        Capture '-reopened'
        Action 'closeagain';Wait-Condition {(Own-Windows).Count -eq 1} 'Reopened settings did not close independently.'
        foreach ($entry in $before.GetEnumerator()) {
            if ($entry.Key -ne 'GPU.inc' -and (Get-FileHash -LiteralPath (Join-Path $parallaxRoot ('@Resources\User\'+$entry.Key))).Hash -ne $entry.Value) { throw 'GPU settings changed another preferences file.' }
        }
        Write-Output 'PASS: separate gear utility; no writes on open; columns, toggle, independent driver/export sources, fit and exact ordinal mapping persisted; GPU refreshed; close and reopen independent; only GPU.inc changed.'
    }
    Wait-Condition {Text-Matches (Join-Path $runRoot 'temperature-session.txt') '^GPU_TEMP_SESSION\|1\|[a-f0-9]{32}\|'} 'Direct provider session did not start.' 40
    $sessionText=Get-Content -LiteralPath (Join-Path $runRoot 'temperature-session.txt') -Raw
    $token=($sessionText.Trim() -split '\|')[2]
    if ($token -notmatch '^[a-f0-9]{32}$') { throw 'Malformed test session identity.' }
    $snapshotBase=Join-Path ([IO.Path]::GetTempPath()) ('Parallax-GPU-'+$token)
    Wait-Condition {Test-Path -LiteralPath ($snapshotBase+'.dat')} 'Direct provider did not publish a snapshot.' 30
    $firstSample=Read-DriverSnapshot ($snapshotBase+'.dat')
    Wait-Condition {
        if (-not (Test-Path -LiteralPath ($snapshotBase+'.dat'))) {return $false}
        $latest=Read-DriverSnapshot ($snapshotBase+'.dat')
        $latest.Count -eq 27 -and $latest[0] -eq 'GPU_TEMP' -and $latest[1] -eq '4' -and $latest[2] -eq $token -and [long]$latest[3] -gt [long]$firstSample[3]
    } 'The persistent provider did not advance its sample sequence.' 12
    $combined=Read-DriverSnapshot ($snapshotBase+'.dat')
    Write-RunFile (Join-Path $runRoot 'driver-snapshot-observed.txt') ($combined -join '|')
    Write-RunFile (Join-Path $runRoot 'process-names-snapshot-observed.txt') ('RequestId='+$combined[25]+[Environment]::NewLine+'NameMap='+$combined[26])
    if (Test-Path -LiteralPath (Join-Path $runRoot 'process-names-observed.txt')) {
        Write-RunFile (Join-Path $runRoot 'process-names-settled.txt') (Get-Content -LiteralPath (Join-Path $runRoot 'process-names-observed.txt') -Raw)
    }
    $metricsPath=Join-Path $runRoot 'driver-metrics-observed.txt'
    Wait-Condition {
        if (-not (Test-Path -LiteralPath $metricsPath)) {return $false}
        $metrics=Get-Content -LiteralPath $metricsPath -Raw
        if ($combined[9] -eq 'OK' -and $metrics -notmatch '(?m)^MeterGPUVRAMValue=\d+\.\d/\d+\.\d (GB|TB)\r?$') {return $false}
        if ($combined[13] -eq 'OK' -and $metrics -notmatch '(?m)^MeterGPUSharedValue=\d+(\.\d\d)? (MB|GB|TB)\r?$') {return $false}
        if ($combined[21] -eq 'OK' -and $metrics -notmatch '(?m)^MeterPowerValue=[0-9]+\.[0-9] W\r?$') {return $false}
        if ($combined[23] -eq 'OK' -and $metrics -notmatch '(?m)^MeterClockValue=[0-9]+(?:\.[0-9]{1,3})? MHz\r?$') {return $false}
        if ($combined[16] -eq 'OK') {
            $names=@('MeterGPULoadValue','MeterGPUControllerLoadValue','MeterGPUVideoLoadValue','MeterGPUBusLoadValue')
            for ($i=0;$i -lt 4;$i++) {
                if ($combined[17+$i] -ne '?' -and $metrics -notmatch ('(?m)^'+$names[$i]+'=(?:100|[0-9]{1,2})%\r?$')) {return $false}
            }
            # The title-row headline is the Core (GPU) domain, sample field 18,
            # rendered in the same controller pass as the Core engine row. Both
            # the snapshot and the readouts advance every sample, so compare
            # against a snapshot read in this same pass and retry on a lag.
            $headline=[regex]::Match($metrics,'(?m)^MeterActivityValue=([^\r\n]*)\r?$')
            $coreRow=[regex]::Match($metrics,'(?m)^MeterGPULoadValue=([^\r\n]*)\r?$')
            if (-not $headline.Success -or -not $coreRow.Success -or $headline.Groups[1].Value -ne $coreRow.Groups[1].Value) {return $false}
            if ($combined[17] -ne '?') {
                if (-not (Test-Path -LiteralPath ($snapshotBase+'.dat'))) {return $false}
                $live=Read-DriverSnapshot ($snapshotBase+'.dat')
                if ($live.Count -ne 27 -or $live[16] -ne 'OK' -or $live[17] -notmatch '^[0-9]+$' -or [int]$live[17] -gt 100) {return $false}
                if ($headline.Groups[1].Value -ne (([int]$live[17]).ToString()+'%')) {return $false}
            }
        }
        return $true
    } 'Supported driver metrics did not reach their native readouts.' 12
    Write-Output 'PASS: combined driver snapshot and supported memory/activity/power/clock readouts agree; the title-row headline equals the Core engine percentage; zero activity is valid.'
    # Allow the existing five-second name request lease and the independent
    # in-process GPU Process Memory worker to settle. Neither lookup is required
    # to be available on every host; all-denied/idle/zero cases retain -- / PID.
    $namesVisible=$false
    $memoryVisible=$false
    $namesDeadline=[DateTime]::UtcNow.AddSeconds(18)
    do {
        $namesObserved=Get-Content -LiteralPath (Join-Path $runRoot 'process-names-observed.txt') -Raw
        $graphObserved=Get-Content -LiteralPath (Join-Path $runRoot 'process-graph-observed.txt') -Raw
        $memoryObserved=Get-Content -LiteralPath (Join-Path $runRoot 'process-memory-observed.txt') -Raw
        $namesVisible=$namesObserved -match '(?m)^NamesPacket=GPU_NAMES\|1\|' -and $graphObserved -match '(?m)^MeterGPUProcessName[1-5]=(?!PID [0-9]+(?: /|$)|--|No active GPU process data).+'
        $memoryVisible=$memoryObserved -match '(?m)^PositiveRows=[1-5]\r?$'
        if (-not ($namesVisible -and $memoryVisible)) {Start-Sleep -Milliseconds 250}
    } while (-not ($namesVisible -and $memoryVisible) -and [DateTime]::UtcNow -lt $namesDeadline)
    Write-RunFile (Join-Path $runRoot 'process-names-settled.txt') $namesObserved
    Write-RunFile (Join-Path $runRoot 'process-graph-settled.txt') $graphObserved
    Write-RunFile (Join-Path $runRoot 'process-memory-settled.txt') $memoryObserved
    $settledSample=Read-DriverSnapshot ($snapshotBase+'.dat')
    Write-RunFile (Join-Path $runRoot 'process-names-snapshot-settled.txt') ('RequestId='+$settledSample[25]+[Environment]::NewLine+'NameMap='+$settledSample[26])
    Capture '-settled'
    if ($namesVisible) {Write-Output 'PASS: live Windows process-name packet reached native process labels.'}
    else {Write-Output 'OBSERVED: no resolvable live ranked name during the bounded wait; PID/idle fallback retained. Synthetic name handling passed the native Lua suite.'}
    Write-Output (Get-Content -LiteralPath (Join-Path $runRoot 'process-memory-audit.txt') -Raw)
    if ($memoryVisible) {Write-Output 'PASS: positive native per-process dedicated bytes reached exact PID / LUID / physical-GPU rows; labels, raw values and tooltip identities agree.'}
    else {Write-Output 'OBSERVED: no usable positive ranked dedicated-memory reading during the bounded wait; zero, missing and idle readings remained --. Native Lua fixtures cover unavailable and replacement identities.'}
    $hosts=@([GpuSmokeProcessTree]::Children([uint32]$process.Id))
    if ($hosts.Count -ne 1) {throw 'Expected exactly one owned persistent temperature host.'}
    $hostProcessId=$hosts[0]
    if (-not (Text-Matches (Join-Path $runRoot 'driver-status.txt') '^0$')) {throw 'Native RunCommand did not report running status zero.'}
    if ($ControllerLifecycle -eq 'Unload') {
        Write-RunFile (Join-Path $runRoot 'main-command.txt') 'deactivate'
        Wait-Condition {-not (Get-Process -Id $hostProcessId -ErrorAction SilentlyContinue)} 'Temperature host survived GPU unload.' 12
    } else {
        $lifecycleCommand=if ($ControllerLifecycle -eq 'Stop') {'stop'} else {'leasefailure'}
        $windowsBefore=(Own-Windows).Count
        Write-RunFile (Join-Path $runRoot 'main-command.txt') $lifecycleCommand
        Wait-Condition {Text-Matches (Join-Path $runRoot 'main-done.txt') ('^'+$lifecycleCommand+'$')} 'Controller lifecycle action was not delivered.' 8
        if ($ControllerLifecycle -eq 'LeaseFailure') {
            Wait-Condition {Text-Matches (Join-Path $runRoot 'temperature-observed.txt') '(?m)^MeterTemperatureValue=Unavailable\r?$'} 'Injected lease failure did not fail the controller.' 8
        }
        Wait-Condition {-not (Get-Process -Id $hostProcessId -ErrorAction SilentlyContinue)} 'Started host was not stopped before lease expiry.' 4
        if ((Own-Windows).Count -ne $windowsBefore) {throw 'Lifecycle test unloaded a config and could be masked by plugin finalization.'}
        Write-Output "PASS: $ControllerLifecycle stops running-status-0 host with GPU still loaded, before the minimum 15-second lease expiry."
    }
    Wait-Condition {-not (Test-Path -LiteralPath ($snapshotBase+'.dat')) -and -not (Test-Path -LiteralPath ($snapshotBase+'.lease')) -and -not (Test-Path -LiteralPath ($snapshotBase+'.tmp'))} 'Temperature session files survived GPU unload.' 12
    Write-Output 'PASS: one persistent direct host; sample sequence advances; selected lifecycle stops the host and removes its session files.'
    # Warnings count too: the harness used to earn an already-active settings
    # warning by opening settings from the GPU skin's refresh pass at startup.
    $problems=@(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object {$_ -match '^(ERRO|WARN)'})
    if ($problems.Count) { throw ($problems -join "`n") }
    Write-Output 'PASS: zero Rainmeter errors or warnings.'
    Write-Output "Evidence: $runRoot"
} finally {
    if ($null -ne $process) { $process.Refresh();if (-not $process.HasExited) {Stop-Process -InputObject $process -Force;$null=$process.WaitForExit(5000)};$process.Dispose() }
}
