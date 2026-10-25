#requires -Version 5.1
# Isolated native check of the GPU History graph cadence and startup cover.
# Stages the suite with tools/Stage-Parallax.ps1, starts an isolated Rainmeter
# (own Rainmeter.ini and SkinPath under build/, offscreen, own PID only) with
# only Parallax\GPU active, and records every update after the controller:
# the helper's snapshot sequence, the History point count and the startup
# cover's runtime options. Test-stage instrumentation only; the live
# Rainmeter profile and installed skins are never read or changed.
#
#   -FillStep N  (test stage only) counts each History point as N samples so
#                the graph's point count reaches its width in seconds and the
#                cover's retirement can be observed natively.
#   -ProjectRoot lets the same check run against another source tree (for a
#                before/after comparison); it must contain tools\Stage-Parallax.ps1.
[CmdletBinding()]
param(
    [ValidateRange(10,120)][int]$SettleSeconds=26,
    [ValidateRange(0,200)][int]$FillStep=0,
    [string]$ProjectRoot,
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
$ErrorActionPreference='Stop'
$process=$null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
if (-not $ProjectRoot) { $ProjectRoot=Join-Path $PSScriptRoot '..\..\..\..\..\..' }
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$stage=& (Join-Path $ProjectRoot 'tools\Stage-Parallax.ps1') -Version 'gpu-history-check' -ProjectRoot $ProjectRoot
$runRoot=$stage.StageRoot
$parallaxRoot=$stage.SkinRoot
$utf8=[Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path,[string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path,$Text,$utf8)
}
foreach ($name in @('Layouts','Plugins','Addons','captures')) { $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native GPU History check with test-stage instrumentation. Do not distribute."
if ($FillStep -gt 1) {
    $measuresPath=Join-Path $parallaxRoot '@Resources\Modules\GPU\Measures.inc'
    $measures=[IO.File]::ReadAllText($measuresPath)
    $counter='Formula=Min(MeasureGPUGraphSamples+1,#ContentWidth#)'
    if ([regex]::Matches($measures,[regex]::Escape($counter)).Count -ne 1) { throw 'History counter formula changed; update this check.' }
    Write-RunFile $measuresPath $measures.Replace($counter,"Formula=Min(MeasureGPUGraphSamples+$FillStep,#ContentWidth#)")
}
$logPath=Join-Path $runRoot 'history-observed.txt'
$harnessPath=Join-Path $runRoot 'HistoryHarness.lua'
Write-RunFile $harnessPath @"
-- Runs after every GPU measure in each update (appended last).
local function read(path) local f=io.open(path,'rb');if not f then return nil end;local t=f:read(8193);f:close();return t end
local function unhex(value) return (value:gsub('%x%x',function(pair) return string.char(tonumber(pair,16)) end)) end
local ticks=0
function Initialize() local f=io.open([=[$logPath]=],'wb');f:write('tick|time|seq|activity|points|width|coverDivider|coverDynamic|coverH|graphDynamic|graphDivider|formula\n');f:close() end
function Update()
    ticks=ticks+1
    local seq,activity='-','-'
    local session=tostring(SKIN:GetMeasure('MeasureGPUTemperatureLauncher'):GetStringValue() or ''):match('^%s*(.-)%s*$')
    local pathHex=session:match('^GPU_TEMP_SESSION|1|%x+|(%x+)|%x+$')
    if pathHex then
        local snapshot=read(unhex(pathHex))
        if snapshot then
            local f={};for part in (snapshot..'|'):gmatch('(.-)|') do f[#f+1]=part end
            seq,activity=f[4] or '-',f[17] or '-'
        end
    end
    local width=SKIN:ParseFormula('('..SKIN:ReplaceVariables('#ContentWidth#')..')')
    local cover,graph=SKIN:GetMeter('MeterGPUGraphUncollected'),SKIN:GetMeter('MeterGPUUtilizationGraph')
    local history=SKIN:GetMeasure('MeasureGPUUtilizationHistory')
    local line=table.concat({ticks,os.time(),seq,activity,SKIN:GetMeasure('MeasureGPUGraphSamples'):GetValue(),width,
        cover:GetOption('UpdateDivider',''),cover:GetOption('DynamicVariables',''),cover:GetH(),
        graph:GetOption('DynamicVariables',''),graph:GetOption('UpdateDivider',''),history:GetOption('Formula','')},'|')
    local f=io.open([=[$logPath]=],'ab');f:write(line,'\n');f:close()
    return 0
end
"@
$mainPath=Join-Path $parallaxRoot 'GPU\GPU.ini'
$mainText=[IO.File]::ReadAllText($mainPath)
Write-RunFile $mainPath ($mainText+"`r`n[MeasureGPUHistoryCheck]`r`nMeasure=Script`r`nScriptFile=$harnessPath`r`n")
$iniPath=Join-Path $runRoot 'Rainmeter.ini'
Write-RunFile $iniPath "[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n[Parallax\GPU]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
$preview=[IO.File]::ReadAllText((Join-Path $ProjectRoot 'tools\Preview-Parallax.ps1'))
$definition=[regex]::Match($preview,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxPreviewNative' -as [type])) { Add-Type -TypeDefinition $definition }
try {
    if (-not (Test-Path -LiteralPath (Join-Path $runRoot 'Skins') -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds $SettleSeconds
    $process.Refresh()
    if ($process.HasExited) { throw "Isolated instance exited early; inspect $runRoot\Rainmeter.log" }
    foreach ($window in @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))) {
        $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap);$hdc=[IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta);$hdc=$graphics.GetHdc()
            $null=[ParallaxPreviewNative]::PrintWindow($window.Handle,$hdc,2);$graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
            $bitmap.Save((Join-Path $runRoot 'captures\GPU.png'),[Drawing.Imaging.ImageFormat]::Png)
        } finally { if ($hdc -ne [IntPtr]::Zero) {$graphics.ReleaseHdc($hdc)};$graphics.Dispose();$bitmap.Dispose() }
    }
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null=$process.WaitForExit(5000) }
        $process.Dispose()
    }
}
$rows=@(Get-Content -LiteralPath $logPath | Select-Object -Skip 1 | ForEach-Object {
    $f=$_ -split '\|'
    [pscustomobject]@{Tick=[int]$f[0];Time=[long]$f[1];Seq=$f[2];Activity=$f[3];Points=[double]$f[4];Width=[double]$f[5];
        CoverDivider=$f[6];CoverDynamic=$f[7];CoverH=[double]$f[8];GraphDynamic=$f[9];GraphDivider=$f[10];Formula=$f[11]}
})
if ($rows.Count -lt 8) { throw "Too few native updates recorded ($($rows.Count))." }
$step=[Math]::Max(1,$FillStep)
$maxPerTick=0;$pointTicks=0
for ($i=1;$i -lt $rows.Count;$i++) {
    $delta=$rows[$i].Points-$rows[$i-1].Points
    if ($delta -gt 0) { $pointTicks++ }
    if ($delta -gt $maxPerTick) { $maxPerTick=$delta }
}
# Distinct non-starting helper sequences with a valid activity reading, as seen
# by this harness after the controller in the same update.
$sequences=@($rows | Where-Object { $_.Seq -match '^\d+$' -and [long]$_.Seq -ge 1 -and $_.Activity -eq 'OK' } | ForEach-Object { $_.Seq } | Select-Object -Unique)
$ticksAfterFirst=@($rows | Where-Object { $_.Seq -match '^\d+$' -and [long]$_.Seq -ge 1 }).Count
$last=$rows[-1]
$summary=[ordered]@{
    Updates=$rows.Count; TicksWithSamples=$ticksAfterFirst; DistinctSamples=$sequences.Count; TicksWithNewPoint=$pointTicks
    MaxPointDeltaPerTick=$maxPerTick; FillStep=$FillStep; FinalPoints=$last.Points; GraphWidth=$last.Width
    FinalCoverDivider=$last.CoverDivider; FinalCoverDynamic=$last.CoverDynamic; FinalCoverHeight=$last.CoverH
    GraphDynamicVariables=$last.GraphDynamic; GraphDivider=$last.GraphDivider; LastFormula=$last.Formula
}
$summary.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Set-Content -LiteralPath (Join-Path $runRoot 'history-summary.txt') -Encoding UTF8
$summary.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
"Evidence: $runRoot"
$log=Join-Path $runRoot 'Rainmeter.log'
$problems=@(); if (Test-Path -LiteralPath $log) { $problems=@(Get-Content -LiteralPath $log | Where-Object { $_ -match '^(ERRO|WARN)' }) }
if ($problems.Count) { $problems; throw 'Isolated Rainmeter logged errors or warnings.' }
if ($maxPerTick -gt $step) { throw "More than one History point in one update (delta $maxPerTick)." }
if ($sequences.Count -lt 4) { throw 'Too few driver samples observed to judge the History cadence.' }
if ($FillStep -le 1) {
    # One point per new sample: the harness may see one sample the controller
    # reads next update, so allow a difference of one either way.
    if ([Math]::Abs($pointTicks-$sequences.Count) -gt 1) { throw "History points ($pointTicks) do not follow driver samples ($($sequences.Count))." }
    if ($pointTicks -gt [Math]::Ceiling($ticksAfterFirst*0.75)) { throw "History advanced on $pointTicks of $ticksAfterFirst updates; expected about one per 2 s sample." }
} else {
    if ($last.Points -lt $last.Width) { throw 'The test-stage fill step did not fill the graph in time; raise -FillStep or -SettleSeconds.' }
    if ($last.CoverDivider -ne '-1' -or $last.CoverDynamic -ne '0' -or $last.CoverH -ne 0) { throw 'A full graph did not retire the startup cover (hidden, DynamicVariables 0, UpdateDivider -1).' }
}
if ($last.GraphDynamic -ne '' -or $last.GraphDivider -ne '-1') { throw 'The History Line meter must be UpdateDivider=-1 without DynamicVariables.' }
'PASS: native History cadence and startup cover checks'
