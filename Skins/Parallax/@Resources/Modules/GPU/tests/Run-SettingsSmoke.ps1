#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet(180,200,240,280,320)][int]$ColumnWidth=200,
    [ValidateSet('0.75','1','1.25','1.5','2')][string]$Scale='1',
    [switch]$CaptureOnly,
    [switch]$MaxTypography,
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$process=$null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$stage=& (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'gpu-settings-smoke'
$runRoot=$stage.StageRoot
$parallaxRoot=$stage.SkinRoot
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
Write-RunFile $globalPath $globalText
$userPath=Join-Path $parallaxRoot '@Resources\User\GPU.inc'
$userText=Get-Content -LiteralPath $userPath -Raw
$userText=[regex]::Replace($userText,'(?m)^Columns=[^\r\n]*','Columns=1')
$userText=[regex]::Replace($userText,'(?m)^PanelHeight=[^\r\n]*','PanelHeight=333')
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
$observedPath=Join-Path $runRoot 'gpu-observed.txt'
$mainHarness=Join-Path $runRoot 'MainHarness.lua'
Write-RunFile $mainHarness @"
local opened=false
local last=''
local function read(path) local f=io.open(path,'rb');if not f then return '' end;local t=f:read('*a');f:close();return t end
local function write(path,value) local f=assert(io.open(path,'wb'));f:write(value);f:close() end
function Initialize()
    local t={};for _,key in ipairs({'Columns','PanelHeight','GPUEnableSensors','GPUTemperatureIndex','GPUTemperatureSensor','GPUTemperatureLabel'}) do t[#t+1]=key..'='..SKIN:GetVariable(key) end
    write([=[$observedPath]=],table.concat(t,'\n'))
    if read([=[$resultPath]=])=='' then
        local ok,result=pcall(function()local n,r=dofile([=[$suite]=]).run([=[$controller]=]);return 'PASS: '..n..' assertions under '.._VERSION..'\n'..r end)
        write([=[$resultPath]=],ok and result or ('FAIL: '..tostring(result)))
    end
end
function Update()
    if read([=[$runRoot\opened.txt]=])=='' then write([=[$runRoot\opened.txt]=],'opened');SKIN:Bang([=[$openAction]=]) end
    local command=read([=[$runRoot\main-command.txt]=])
    if command~='' and command~=last then last=command;SKIN:Bang([=[$openAction]=]);write([=[$runRoot\main-done.txt]=],command) end
    local info={}
    for _,name in ipairs({'MeterAdapterName','MeterVRAMValue','MeterDirect3DValue','MeterShaderValue','MeterRayTracingValue','MeterDriverValue'}) do
        local meter=SKIN:GetMeter(name);if meter then info[#info+1]=name..'='..meter:GetOption('Text','') end
    end
    write([=[$runRoot\metadata-observed.txt]=],table.concat(info,'\n'))
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
    local actions={columns='CycleColumns()',sensors='ToggleSensors()',fit='FitHeight()',browse="Browse('Temperature')",rescan='Rescan()',select='Select(1)',close='Close()',closeagain='Close()'}
    if command~='' and command~=last then last=command;local action=actions[command];if action then SKIN:Bang('!CommandMeasure','MeasureGPUSettings',action) end;write([=[$runRoot\popup-done.txt]=],command) end
    local out={'Columns='..SKIN:GetVariable('Columns'),'PanelHeight='..SKIN:GetVariable('PanelHeight')}
    for _,name in ipairs({'MeterSettingsColumnsValue','MeterSettingsHeightValue','MeterSettingsSensorsValue','MeterSettingsTemperatureValue','MeterSettingsNotice','MeterSettingsPick1','MeterSettingsTitle'}) do
        local meter=SKIN:GetMeter(name);if meter then out[#out+1]=name..'='..meter:GetOption('Text','') end
    end
    write([=[$runRoot\settings-observed.txt]=],table.concat(out,'\n'))
    local m=SKIN:GetMeasure('MeasureGPUDiscover');write([=[$runRoot\discovery-observed.txt]=],tostring(m:GetValue())..'\n'..m:GetStringValue())
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
function Wait-Condition([scriptblock]$Condition,[string]$Message,[int]$Seconds=12) {
    $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
    do { if (& $Condition) { return };Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $deadline)
    throw $Message
}
function Own-Windows { @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id)) }
function Text-Matches([string]$Path,[string]$Pattern) { (Test-Path -LiteralPath $Path) -and ((Get-Content -LiteralPath $Path -Raw) -match $Pattern) }
function Action([string]$Name) {
    Write-RunFile (Join-Path $runRoot 'popup-command.txt') $Name
    Wait-Condition { Text-Matches (Join-Path $runRoot 'popup-done.txt') ('^'+$Name+'$') } "Action not delivered: $Name"
    Start-Sleep -Milliseconds 800
}
function Capture([string]$Suffix) {
    Wait-Condition { @(Own-Windows | Where-Object {$_.Width -le 0 -or $_.Height -le 0}).Count -eq 0 } 'Native windows did not finish creating their bounds.'
    Start-Sleep -Milliseconds 500
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
try {
    $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Wait-Condition { (Own-Windows).Count -eq 2 } 'Gear failed to open a separate settings window.'
    Wait-Condition { Test-Path -LiteralPath (Join-Path $runRoot 'settings-observed.txt') } 'Missing native settings observation.'
    Start-Sleep -Seconds 3
    if ($MaxTypography) {
        Wait-Condition {
            $metadataPath=Join-Path $runRoot 'metadata-observed.txt'
            (Text-Matches $metadataPath '(?m)^MeterAdapterName=.+') -and
                -not (Text-Matches $metadataPath 'Checking\.\.\.|GPU name unavailable|No discrete GPU|Multiple discrete GPUs')
        } 'GPU metadata did not complete for maximum typography capture.' 30
    }
    foreach ($entry in $before.GetEnumerator()) { if ((Get-FileHash -LiteralPath (Join-Path $parallaxRoot ('@Resources\User\'+$entry.Key))).Hash -ne $entry.Value) { throw 'Opening wrote a preference file.' } }
    $suiteResult=Get-Content -LiteralPath $resultPath -Raw
    if ($suiteResult -notmatch '^PASS:') { throw $suiteResult }
    Write-Output (($suiteResult -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    Capture ''
    if (-not $CaptureOnly) {
        Action 'columns';Wait-Condition {Text-Matches $observedPath '(?m)^Columns=2$'} 'GPU did not reload saved columns.'
        Action 'sensors';Wait-Condition {Text-Matches $observedPath '(?m)^GPUEnableSensors=1$'} 'GPU did not reload saved sensor toggle.'
        Action 'fit';Wait-Condition {Text-Matches $observedPath '(?m)^PanelHeight=288$'} 'GPU did not reload fitted height.'
        if (-not (Text-Matches (Join-Path $runRoot 'settings-observed.txt') '(?m)^PanelHeight=422$')) { throw 'Settings geometry changed with monitor height.' }
        Action 'browse';Wait-Condition {Text-Matches (Join-Path $runRoot 'discovery-observed.txt') '(?m)^1\r?$'} 'Real discovery did not complete.'
        $realDiscovery=Get-Content -LiteralPath (Join-Path $runRoot 'discovery-observed.txt') -Raw
        Write-RunFile (Join-Path $runRoot 'real-discovery-result.txt') $realDiscovery
        Capture '-real-discovery'
        $hex={param($value) ([Text.Encoding]::UTF8.GetBytes($value) | ForEach-Object {$_.ToString('X2')}) -join ''}
        $fixture='GPU_EXPORTS|1|OK|'+(& $hex 'HKEY_CURRENT_USER')+'|'+(& $hex 'SOFTWARE\HWiNFO64\VSB')+'|0|0'+[Environment]::NewLine+'ITEM|7|'+(& $hex 'GPU [#0]: Test adapter')+'|'+(& $hex 'GPU Temperature')+'|'+(& $hex '55 C')+'|'+(& $hex '55')
        Write-RunFile $helperPath ("[Console]::OutputEncoding=[Text.UTF8Encoding]::new(`$false);[Console]::Write('"+$fixture+"')")
        Action 'rescan';Wait-Condition {Text-Matches (Join-Path $runRoot 'settings-observed.txt') 'MeterSettingsPick1=7: GPU Temperature / 55 C'} 'Fixture discovery list did not render.'
        Capture '-fixture'
        Action 'select';Wait-Condition {Text-Matches $observedPath '(?m)^GPUTemperatureSensor=GPU \[#0\]: Test adapter$'} 'Exact ordinal sensor identity did not survive native persistence and GPU reload.'
        if (-not (Text-Matches $observedPath '(?m)^GPUTemperatureIndex=7$')) { throw 'Selected export index was not saved.' }
        Action 'close';Wait-Condition {(Own-Windows).Count -eq 1} 'Close did not leave only GPU active.'
        if ((Own-Windows)[0].Title -match 'GPU[\\/]Settings') { throw 'GPU closed instead of settings.' }
        Write-RunFile (Join-Path $runRoot 'main-command.txt') 'reopen'
        Wait-Condition {(Own-Windows).Count -eq 2} 'Reopening settings failed.'
        Wait-Condition {Text-Matches (Join-Path $runRoot 'settings-observed.txt') 'MeterSettingsTemperatureValue=GPU Temperature'} 'Reopening lost saved mapping.'
        Capture '-reopened'
        Action 'closeagain';Wait-Condition {(Own-Windows).Count -eq 1} 'Reopened settings did not close independently.'
        foreach ($entry in $before.GetEnumerator()) {
            if ($entry.Key -ne 'GPU.inc' -and (Get-FileHash -LiteralPath (Join-Path $parallaxRoot ('@Resources\User\'+$entry.Key))).Hash -ne $entry.Value) { throw 'GPU settings changed another preferences file.' }
        }
        Write-Output 'PASS: separate gear utility; no writes on open; columns, toggle, fit and exact ordinal mapping persisted; GPU refreshed; close and reopen independent; only GPU.inc changed.'
    }
    $errors=@(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object {$_ -match '^ERRO'})
    if ($errors.Count) { throw ($errors -join "`n") }
    Write-Output 'PASS: zero Rainmeter errors.'
    Write-Output "Evidence: $runRoot"
} finally {
    if ($null -ne $process) { $process.Refresh();if (-not $process.HasExited) {Stop-Process -InputObject $process -Force;$null=$process.WaitForExit(5000)};$process.Dispose() }
}
