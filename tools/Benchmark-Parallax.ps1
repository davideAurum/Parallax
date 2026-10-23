#requires -Version 5.1
<#
.SYNOPSIS
Measures Parallax steady-state cost per utility, alone and together, in an
isolated Rainmeter instance.

.DESCRIPTION
Stages the working tree (or reuses a stage), then for each scenario cold-starts
an ISOLATED Rainmeter instance with only that scenario's skins active, waits for
every skin to finish building, settles, and samples once per second for a fixed
window. Per trial it records, as percent of ONE logical core:

  * MainCpuPct    - Rainmeter's UI thread (owner of the skin windows), where all
                    skins update and draw; the contended resource.
  * OtherCpuPct   - Rainmeter's remaining threads (plugin workers such as
                    UsageMonitor, AudioLevel, RunCommand readers).
  * HelperCpuPct  - processes descended from the instance (PowerShell hosts).
  * TotalCpuPct   - all of the above; p95/max of the 1-second series expose spikes.
  * context switches per second (wakeups), working set / private bytes for the
    instance and its helpers, GDI/USER/kernel handles, load time, and GPU engine
    running time (percent busy per engine type) from the GPU Engine counters.

Scenarios:
  empty            Rainmeter with no skin (fixed engine cost, subtracted below).
  shell            One generated Parallax skin with only the shared includes,
                   bounds, panel and title (per-skin fixed cost of the suite).
  solo:<Module>    One utility alone.
  suite            All eight utilities.
  loo:<Module>     All eight except one (marginal cost inside the suite).
  set:<A>+<B>...   Any explicit set.
  standard         empty, shell, every solo, suite and every loo.

Trials are interleaved in rounds (each round runs every scenario once, rotated),
so slow drift and thermal state affect scenarios alike.

Safety: the instance runs from a generated Rainmeter.ini inside the stage with
windows off-screen; only the PID this script started and processes descended
from it (created after its launch) are sampled or terminated. No Rainmeter
command-line bangs are sent (one could reach a live instance). -Preferences live
COPIES the live User\*.inc into the stage; nothing outside the stage is written
except the JSON report under build\perf-benchmark.

.EXAMPLE
  powershell -File tools\Benchmark-Parallax.ps1 -Scenario standard -Trials 3
  powershell -File tools\Benchmark-Parallax.ps1 -Scenario suite,solo:Media -Preferences live
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string[]]$Scenario = @('standard'),
    [ValidateSet('default', 'live')][string]$Preferences = 'default',
    [string]$LiveSkinRoot = (Join-Path $env:USERPROFILE 'Local Programs\Rainmeter\Skins\Parallax'),
    [ValidateRange(1, 25)][int]$Trials = 3,
    [ValidateRange(0, 600)][int]$SettleSeconds = 15,
    [ValidateRange(5, 3600)][int]$MeasureSeconds = 30,
    [string]$StageRoot = '',
    # Rainmeter's renderer for the isolated instance: 0 = WARP software rendering
    # (Rainmeter's default), 1 = hardware Direct3D. 'default' writes no key.
    [ValidateSet('default', '0', '1')][string]$HardwareAcceleration = 'default',
    [string]$Label = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.Perf.psm1') -Force

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) {
    throw 'Existing Rainmeter installation required; this script downloads and installs nothing.'
}

$modules = [ordered]@{
    Chronometer = 'Chronometer\Chronometer.ini'
    CPU         = 'CPU\CPU.ini'
    RAM         = 'RAM\RAM.ini'
    GPU         = 'GPU\GPU.ini'
    IO          = 'IO\IO-Disk.ini'
    Network     = 'Network\Network.ini'
    Media       = 'Media\Media.ini'
    Visualizer  = 'Visualizer\Visualizer.ini'
}
$moduleNames = @($modules.Keys)

# --------------------------------------------------------------------------
# Scenario expansion.
# --------------------------------------------------------------------------
$plan = [Collections.Generic.List[object]]::new()
function Add-Scenario([string]$Name, [string[]]$Set) {
    if ($plan | Where-Object { $_.Name -eq $Name }) { return }
    foreach ($module in $Set) { if ($module -ne 'BenchShell' -and $module -notin $moduleNames) { throw "Unknown module in scenario ${Name}: $module" } }
    $plan.Add([pscustomobject]@{ Name = $Name; Modules = @($Set) })
}
foreach ($entry in $Scenario) {
    foreach ($item in $entry.Split(',')) {
        $item = $item.Trim()
        switch -Regex ($item) {
            '^standard$' {
                Add-Scenario 'empty' @()
                Add-Scenario 'shell' @('BenchShell')
                foreach ($m in $moduleNames) { Add-Scenario "solo:$m" @($m) }
                Add-Scenario 'suite' $moduleNames
                foreach ($m in $moduleNames) { Add-Scenario "loo:$m" @($moduleNames | Where-Object { $_ -ne $m }) }
            }
            '^empty$' { Add-Scenario 'empty' @() }
            '^shell$' { Add-Scenario 'shell' @('BenchShell') }
            '^suite$' { Add-Scenario 'suite' $moduleNames }
            '^solo$' { foreach ($m in $moduleNames) { Add-Scenario "solo:$m" @($m) } }
            '^loo$' { foreach ($m in $moduleNames) { Add-Scenario "loo:$m" @($moduleNames | Where-Object { $_ -ne $m }) } }
            '^solo:(.+)$' { Add-Scenario $item @($Matches[1]) }
            '^loo:(.+)$' { $out = $Matches[1]; Add-Scenario $item @($moduleNames | Where-Object { $_ -ne $out }) }
            '^set:(.+)$' { Add-Scenario $item @($Matches[1].Split('+') | ForEach-Object { $_.Trim() }) }
            default { throw "Unknown scenario: $item" }
        }
    }
}

# --------------------------------------------------------------------------
# Stage (or reuse), add the shell skin and the build-complete signal.
# --------------------------------------------------------------------------
if ($StageRoot) {
    $runRoot = [IO.Path]::GetFullPath($StageRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $runRoot 'BENCHMARK-ONLY.txt'))) { throw "Not a benchmark stage: $runRoot" }
}
else {
    $stageVersion = 'perf-{0}' -f ([guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host "Staging suite..." -ForegroundColor Cyan
    $stage = & (Join-Path $PSScriptRoot 'Stage-Parallax.ps1') -Version $stageVersion
    $runRoot = $stage.StageRoot
}
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = Join-Path $skinRoot 'Parallax'
$encoding = [Text.UTF8Encoding]::new($false)

function Assert-InStage([string]$Path) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside the generated benchmark stage: $Path"
    }
}
function Write-RunFile([string]$Path, [string]$Content) {
    Assert-InStage $Path
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

foreach ($directory in @('Layouts', 'Plugins', 'Addons')) {
    $path = Join-Path $runRoot $directory
    if (-not (Test-Path -LiteralPath $path)) { $null = New-Item -ItemType Directory -Path $path }
}

$harnessPath = Join-Path $runRoot 'BenchHarness.lua'
if (-not $StageRoot) {
    Write-RunFile $harnessPath @'
-- Writes one report when the skin first updates, then disables itself so the
-- signal adds no per-tick work during measurement.
function Initialize() end
function Update()
    local path = SELF:GetOption('ReportPath', '')
    if path ~= '' then
        local file = io.open(path, 'wb')
        if file then file:write('Config=', SKIN:GetVariable('CURRENTCONFIG'), '\n'); file:close() end
    end
    SKIN:Bang('!DisableMeasure', SELF:GetName())
    return 0
end
'@
    Write-RunFile (Join-Path $parallaxRoot 'BenchShell\Shell.ini') @'
[Rainmeter]
Update=#MetricsInterval#
AccurateText=1
DynamicWindowSize=1
Group=Parallax

[Variables]
@Include=#@#Defaults.inc
@Include2=#@#User\Settings.inc
Columns=1
PanelHeight=200
@Include3=#@#Geometry.inc
@Include4=#@#Styles.inc

[MeterBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterPanel]
Meter=Shape
MeterStyle=StylePanel

[MeterTitle]
Meter=String
MeterStyle=StyleTitle
Text=Benchmark shell
'@
    $entryFiles = @($modules.Values) + @('BenchShell\Shell.ini')
    foreach ($relative in $entryFiles) {
        $path = Join-Path $parallaxRoot $relative
        $key = ($relative.Split('\')[0])
        $report = Join-Path $runRoot "report-$key.txt"
        $source = [IO.File]::ReadAllText($path)
        $source += "`n[MeasureParallaxBench]`nMeasure=Script`nScriptFile=$harnessPath`nReportPath=$report`n"
        Write-RunFile $path $source
    }
    Write-RunFile (Join-Path $runRoot 'BENCHMARK-ONLY.txt') "Generated benchmark stage with instrumentation. Not distributable.`n"
}

if ($Preferences -eq 'live') {
    $liveUser = Join-Path $LiveSkinRoot '@Resources\User'
    if (-not (Test-Path -LiteralPath $liveUser)) { throw "Live preferences not found: $liveUser" }
    foreach ($file in @(Get-ChildItem -LiteralPath $liveUser -Filter '*.inc' -File)) {
        $destination = Join-Path $parallaxRoot "@Resources\User\$($file.Name)"
        Assert-InStage $destination
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
    Write-Host "Copied live preferences from $liveUser into the stage." -ForegroundColor Yellow
}

$iniPath = Join-Path $runRoot 'Rainmeter.ini'
function Get-EntryFor([string]$Module) {
    if ($Module -eq 'BenchShell') { return [pscustomobject]@{ Config = 'Parallax\BenchShell'; File = 'Shell.ini'; Key = 'BenchShell' } }
    $relative = $modules[$Module]
    $folder = Split-Path -Parent $relative
    [pscustomobject]@{ Config = "Parallax\$folder"; File = (Split-Path -Leaf $relative); Key = $folder }
}
function Write-ScenarioIni($Item) {
    $text = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    if ($HardwareAcceleration -ne 'default') { $text += "HardwareAcceleration=$HardwareAcceleration`n" }
    foreach ($module in $Item.Modules) {
        $entry = Get-EntryFor $module
        $folder = Join-Path $parallaxRoot ($entry.Config.Substring('Parallax\'.Length))
        $files = @(Get-ChildItem -LiteralPath $folder -Filter '*.ini' -File | Sort-Object Name)
        $active = 1
        for ($i = 0; $i -lt $files.Count; $i++) { if ($files[$i].Name -eq $entry.File) { $active = $i + 1 } }
        $text += "`n[$($entry.Config)]`nActive=$active`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    }
    Write-RunFile $iniPath $text
    Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
}

# --------------------------------------------------------------------------
# One trial.
# --------------------------------------------------------------------------
# Helper identity is pid + create time, so a pid Windows reuses for an unrelated
# process after a helper exits is dropped instead of adopted as a helper.
$script:knownCreate = @{}
function Update-Known($Snapshot, [int]$RootPid, [Collections.Generic.HashSet[int]]$Known, [long]$NotBefore) {
    foreach ($id in @($Known)) {
        $process = $Snapshot.ByPid[$id]
        if ($null -ne $process -and $script:knownCreate.ContainsKey($id) -and $process.CreateTime -ne $script:knownCreate[$id]) {
            $null = $Known.Remove($id)
            $script:knownCreate.Remove($id)
        }
    }
    foreach ($id in (Get-ParallaxDescendants -Snapshot $Snapshot -RootPids (@($RootPid) + @($Known)) -NotBefore $NotBefore)) {
        if ($Known.Add($id)) { $script:knownCreate[$id] = $Snapshot.ByPid[$id].CreateTime }
    }
}

function Stop-Owned([int]$RainmeterPid, [Collections.Generic.HashSet[int]]$Known, [long]$NotBefore) {
    $snapshot = Get-ParallaxPerfSnapshot
    Update-Known -Snapshot $snapshot -RootPid $RainmeterPid -Known $Known -NotBefore $NotBefore
    $targets = @($RainmeterPid) + @($Known)
    foreach ($id in $targets) {
        $process = $snapshot.ByPid[$id]
        if ($null -eq $process -or $process.CreateTime -lt $NotBefore) { continue }
        # A reused PID would not still descend from the instance.
        if ($id -ne $RainmeterPid -and $process.ParentPid -ne $RainmeterPid -and -not $Known.Contains($process.ParentPid)) { continue }
        try { Stop-Process -Id $id -Force -ErrorAction Stop } catch {}
    }
    # Orphans whose launcher exited before we saw them still carry the staged
    # skin path. Match the skin folder, not the stage root: this script's own
    # command line names the stage root via -StageRoot.
    $skinPath = $parallaxRoot + [IO.Path]::DirectorySeparatorChar
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='conhost.exe'" -ErrorAction SilentlyContinue)) {
        if ($process.ProcessId -eq $PID) { continue }
        if ($process.CommandLine -and $process.CommandLine.IndexOf($skinPath, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            try { Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop } catch {}
        }
    }
}

function Invoke-Trial($Item, [int]$Trial) {
    Write-ScenarioIni $Item
    $expected = @($Item.Modules | ForEach-Object { Get-EntryFor $_ })
    foreach ($entry in $expected) {
        $report = Join-Path $runRoot "report-$($entry.Key).txt"
        if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force }
    }
    $notBefore = [DateTime]::UtcNow.ToFileTimeUtc() - 10000000
    $known = [Collections.Generic.HashSet[int]]::new()
    $script:knownCreate = @{}
    $process = $null
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
        $rmPid = $process.Id
        $loadMs = $null
        $deadline = [datetime]::UtcNow.AddSeconds(150)
        while ([datetime]::UtcNow -lt $deadline) {
            $process.Refresh()
            if ($process.HasExited) { throw "Instance exited early; inspect $runRoot\Rainmeter.log" }
            if ($expected.Count -eq 0) {
                if ($watch.Elapsed.TotalSeconds -ge 3) { $loadMs = $watch.Elapsed.TotalMilliseconds; break }
            }
            elseif ([ParallaxPerfNative]::CountSkinWindows([uint32]$rmPid) -ge $expected.Count) {
                $ready = $true
                foreach ($entry in $expected) { if (-not (Test-Path -LiteralPath (Join-Path $runRoot "report-$($entry.Key).txt"))) { $ready = $false; break } }
                if ($ready) { $loadMs = $watch.Elapsed.TotalMilliseconds; break }
            }
            Start-Sleep -Milliseconds 20
        }
        if ($null -eq $loadMs) { throw "Timed out waiting for $($expected.Count) skin(s); inspect $runRoot\Rainmeter.log" }

        # Settle, tracking helpers as they appear.
        $settleEnd = [datetime]::UtcNow.AddSeconds($SettleSeconds)
        while ([datetime]::UtcNow -lt $settleEnd) {
            $snap = Get-ParallaxPerfSnapshot
            Update-Known -Snapshot $snap -RootPid $rmPid -Known $known -NotBefore $notBefore
            Start-Sleep -Milliseconds 1000
        }

        $mainTid = [ParallaxPerfNative]::SkinWindowThread([uint32]$rmPid)
        $first = Get-ParallaxPerfSnapshot -Threads
        Update-Known -Snapshot $first -RootPid $rmPid -Known $known -NotBefore $notBefore
        if ($mainTid -eq 0) { $mainTid = (@($first.ByPid[$rmPid].Threads) | Sort-Object CreateTime | Select-Object -First 1).Tid }
        $gpuPids = @($rmPid) + @($known)
        $gpuBefore = Get-ParallaxGpuRunningTime -Pids $gpuPids
        $gpuStamp = [Diagnostics.Stopwatch]::GetTimestamp()

        $series = [Collections.Generic.List[object]]::new()
        $previous = $first
        $helperNames = [Collections.Generic.HashSet[string]]::new()
        $measureEnd = [Diagnostics.Stopwatch]::GetTimestamp() + [long]($MeasureSeconds * [Diagnostics.Stopwatch]::Frequency)
        while ([Diagnostics.Stopwatch]::GetTimestamp() -lt $measureEnd) {
            Start-Sleep -Milliseconds 1000
            $now = Get-ParallaxPerfSnapshot -Threads
            Update-Known -Snapshot $now -RootPid $rmPid -Known $known -NotBefore $notBefore
            $seconds = Get-ParallaxElapsedSeconds $previous.Timestamp $now.Timestamp
            $rmNow = $now.ByPid[$rmPid]; $rmPrev = $previous.ByPid[$rmPid]
            if ($null -eq $rmNow) { throw 'Instance exited during measurement.' }
            $mainNow = @($rmNow.Threads | Where-Object Tid -eq $mainTid)[0]
            $mainPrev = @($rmPrev.Threads | Where-Object Tid -eq $mainTid)[0]
            # Per-thread deltas, so a thread that exits between snapshots does not subtract.
            $prevCtx = @{}; foreach ($t in $rmPrev.Threads) { $prevCtx[$t.Tid] = $t.ContextSwitches }
            $rmCtxNow = 0L; $rmCtxPrev = 0L
            foreach ($t in $rmNow.Threads) { $rmCtxNow += $t.ContextSwitches; $rmCtxPrev += $(if ($prevCtx.ContainsKey($t.Tid)) { $prevCtx[$t.Tid] } else { 0 }) }
            $helperCpu = 0L; $helperCtx = 0L
            foreach ($id in $known) {
                $h = $now.ByPid[$id]
                if ($null -eq $h) { continue }
                $null = $helperNames.Add($h.Name)
                $hp = $previous.ByPid[$id]
                $helperCpu += $h.CpuTime - $(if ($hp -and $hp.CreateTime -eq $h.CreateTime) { $hp.CpuTime } else { 0 })
                $hPrevCtx = @{}; if ($hp -and $hp.CreateTime -eq $h.CreateTime) { foreach ($t in $hp.Threads) { $hPrevCtx[$t.Tid] = $t.ContextSwitches } }
                $ctxNow = 0L; $ctxPrev = 0L
                foreach ($t in $h.Threads) { $ctxNow += $t.ContextSwitches; $ctxPrev += $(if ($hPrevCtx.ContainsKey($t.Tid)) { $hPrevCtx[$t.Tid] } else { 0 }) }
                $helperCtx += $ctxNow - $ctxPrev
            }
            $series.Add([pscustomobject]@{
                Seconds   = $seconds
                MainPct   = 100.0 * ($mainNow.CpuTime - $mainPrev.CpuTime) / ($seconds * 1e7)
                RmPct     = 100.0 * ($rmNow.CpuTime - $rmPrev.CpuTime) / ($seconds * 1e7)
                HelperPct = 100.0 * $helperCpu / ($seconds * 1e7)
                MainCtx   = ($mainNow.ContextSwitches - $mainPrev.ContextSwitches) / $seconds
                RmCtx     = ($rmCtxNow - $rmCtxPrev) / $seconds
                HelperCtx = $helperCtx / $seconds
            })
            $previous = $now
        }
        $window = Get-ParallaxElapsedSeconds $first.Timestamp $previous.Timestamp
        $gpuAfter = Get-ParallaxGpuRunningTime -Pids (@($rmPid) + @($known))
        $gpuSeconds = Get-ParallaxElapsedSeconds $gpuStamp ([Diagnostics.Stopwatch]::GetTimestamp())
        $gpuRm = Get-ParallaxGpuPercent -Before $gpuBefore -After $gpuAfter -Seconds $gpuSeconds -Pids @($rmPid)
        $gpuHelpers = Get-ParallaxGpuPercent -Before $gpuBefore -After $gpuAfter -Seconds $gpuSeconds -Pids @($known)

        $rmEnd = $previous.ByPid[$rmPid]; $rmStart = $first.ByPid[$rmPid]
        $mainEnd = @($rmEnd.Threads | Where-Object Tid -eq $mainTid)[0]; $mainStart = @($rmStart.Threads | Where-Object Tid -eq $mainTid)[0]
        $rmPct = 100.0 * ($rmEnd.CpuTime - $rmStart.CpuTime) / ($window * 1e7)
        $mainPct = 100.0 * ($mainEnd.CpuTime - $mainStart.CpuTime) / ($window * 1e7)
        $helperPct = (($series | Measure-Object -Property HelperPct -Sum).Sum * 1.0) / [math]::Max(1, $series.Count)
        $totals = @($series | ForEach-Object { $_.RmPct + $_.HelperPct })
        $mains = @($series | ForEach-Object { $_.MainPct })
        $helperWs = 0L; $helperPriv = 0L
        foreach ($id in $known) { $h = $previous.ByPid[$id]; if ($h) { $helperWs += $h.WorkingSet; $helperPriv += $h.PrivateBytes } }
        $process.Refresh()
        $handle = $process.Handle

        [pscustomobject][ordered]@{
            Scenario          = $Item.Name
            Trial             = $Trial
            LoadMs            = [math]::Round($loadMs, 0)
            SkinWindows       = [ParallaxPerfNative]::CountSkinWindows([uint32]$rmPid)
            WindowSeconds     = [math]::Round($window, 2)
            MainCpuPct        = [math]::Round($mainPct, 3)
            OtherCpuPct       = [math]::Round($rmPct - $mainPct, 3)
            HelperCpuPct      = [math]::Round($helperPct, 3)
            TotalCpuPct       = [math]::Round($rmPct + $helperPct, 3)
            MainP95Pct        = [math]::Round((Get-ParallaxPercentile $mains 95), 2)
            MainMaxPct        = [math]::Round(($mains | Measure-Object -Maximum).Maximum, 2)
            TotalP95Pct       = [math]::Round((Get-ParallaxPercentile $totals 95), 2)
            TotalMaxPct       = [math]::Round(($totals | Measure-Object -Maximum).Maximum, 2)
            MainCtxPerSec     = [math]::Round((($series | Measure-Object -Property MainCtx -Average).Average), 1)
            RmCtxPerSec       = [math]::Round((($series | Measure-Object -Property RmCtx -Average).Average), 1)
            HelperCtxPerSec   = [math]::Round((($series | Measure-Object -Property HelperCtx -Average).Average), 1)
            RmWorkingSetMB    = [math]::Round($rmEnd.WorkingSet / 1MB, 1)
            RmPrivateMB       = [math]::Round($rmEnd.PrivateBytes / 1MB, 1)
            HelperCount       = @($known | Where-Object { $previous.ByPid[$_] }).Count
            HelperNames       = (@($helperNames) | Sort-Object) -join ' '
            HelperWorkingSetMB = [math]::Round($helperWs / 1MB, 1)
            HelperPrivateMB   = [math]::Round($helperPriv / 1MB, 1)
            GdiObjects        = [int][ParallaxPerfNative]::GdiObjects($handle)
            UserObjects       = [int][ParallaxPerfNative]::UserObjects($handle)
            Handles           = [int]$rmEnd.HandleCount
            Threads           = [int]$rmEnd.ThreadCount
            Gpu3dPct          = [math]::Round($(if ($gpuRm.ContainsKey('3D')) { $gpuRm['3D'] } else { 0.0 }), 3)
            GpuAllPct         = [math]::Round((@($gpuRm.Values) | Measure-Object -Sum).Sum + 0.0, 3)
            HelperGpuPct      = [math]::Round((@($gpuHelpers.Values) | Measure-Object -Sum).Sum + 0.0, 3)
            Series            = @($series | ForEach-Object { [pscustomobject]@{ Main = [math]::Round($_.MainPct, 2); Rm = [math]::Round($_.RmPct, 2); Helper = [math]::Round($_.HelperPct, 2); MainCtx = [math]::Round($_.MainCtx, 0) } })
        }
    }
    finally {
        if ($null -ne $process) {
            Stop-Owned -RainmeterPid $process.Id -Known $known -NotBefore $notBefore
            $null = $process.WaitForExit(10000)
            $process.Dispose()
        }
        Start-Sleep -Milliseconds 1500
    }
}

# --------------------------------------------------------------------------
# Rounds, aggregation and interaction analysis.
# --------------------------------------------------------------------------
$outDir = Join-Path $projectRoot 'build\perf-benchmark'
if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Path $outDir -Force }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
$outPath = Join-Path $outDir ($(if ($Label) { "$stamp-$Preferences-$Label.json" } else { "$stamp-$Preferences.json" }))
$results = [Collections.Generic.List[object]]::new()
$metrics = @('MainCpuPct', 'OtherCpuPct', 'HelperCpuPct', 'TotalCpuPct', 'MainP95Pct', 'TotalP95Pct', 'TotalMaxPct', 'MainCtxPerSec', 'RmCtxPerSec', 'HelperCtxPerSec', 'RmPrivateMB', 'HelperPrivateMB', 'RmWorkingSetMB', 'GdiObjects', 'Handles', 'Gpu3dPct', 'GpuAllPct', 'LoadMs')

function Get-Median([double[]]$Values) { Get-ParallaxPercentile $Values 50 }
function Get-Summary {
    $summary = [ordered]@{}
    foreach ($item in $plan) {
        $rows = @($results | Where-Object Scenario -eq $item.Name)
        if ($rows.Count -eq 0) { continue }
        $entry = [ordered]@{ N = $rows.Count; HelperNames = (@($rows | ForEach-Object { $_.HelperNames.Split(' ') } | Where-Object { $_ } | Sort-Object -Unique) -join ' ') }
        foreach ($metric in $metrics) {
            $values = @($rows | ForEach-Object { [double]$_.$metric })
            $entry[$metric] = [ordered]@{ Median = [math]::Round((Get-Median $values), 3); Min = [math]::Round(($values | Measure-Object -Minimum).Minimum, 3); Max = [math]::Round(($values | Measure-Object -Maximum).Maximum, 3) }
        }
        $summary[$item.Name] = $entry
    }
    $summary
}
function Get-Interaction($Summary) {
    if (-not ($Summary.Contains('empty') -and $Summary.Contains('suite'))) { return $null }
    $analysis = [ordered]@{}
    foreach ($metric in @('MainCpuPct', 'OtherCpuPct', 'HelperCpuPct', 'TotalCpuPct', 'MainCtxPerSec', 'RmPrivateMB', 'HelperPrivateMB')) {
        $base = $Summary['empty'][$metric].Median
        $suite = $Summary['suite'][$metric].Median - $base
        $solo = [ordered]@{}; $marginal = [ordered]@{}; $sum = 0.0; $complete = $true
        foreach ($m in $moduleNames) {
            if ($Summary.Contains("solo:$m")) { $solo[$m] = [math]::Round($Summary["solo:$m"][$metric].Median - $base, 3); $sum += $solo[$m] } else { $complete = $false }
            if ($Summary.Contains("loo:$m")) { $marginal[$m] = [math]::Round($Summary['suite'][$metric].Median - $Summary["loo:$m"][$metric].Median, 3) }
        }
        $analysis[$metric] = [ordered]@{
            EmptyBaseline   = $base
            SuiteBurden     = [math]::Round($suite, 3)
            SoloBurden      = $solo
            SumOfSolo       = $(if ($complete) { [math]::Round($sum, 3) } else { $null })
            Interaction     = $(if ($complete) { [math]::Round($suite - $sum, 3) } else { $null })
            MarginalInSuite = $marginal
        }
    }
    $analysis
}
function Save-Report {
    $summary = Get-Summary
    $report = [ordered]@{
        CapturedUtc      = [DateTime]::UtcNow.ToString('o')
        Label            = $Label
        Preferences      = $Preferences
        HardwareAcceleration = $(if ($HardwareAcceleration -eq 'default') { 'default (0, WARP)' } else { $HardwareAcceleration })
        Trials           = $Trials
        SettleSeconds    = $SettleSeconds
        MeasureSeconds   = $MeasureSeconds
        RainmeterVersion = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        Machine          = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
        LogicalCpus      = [Environment]::ProcessorCount
        Commit           = (git -C $projectRoot rev-parse --short HEAD 2>$null)
        StageRoot        = $runRoot
        Scenarios        = @($plan)
        Summary          = $summary
        Interaction      = (Get-Interaction $summary)
        Trialwise        = @($results.ToArray())
        Method           = 'Cold start of an isolated off-screen Rainmeter instance per trial; settle, then 1-second NtQuerySystemInformation snapshots over the window. CPU percentages are of one logical core. Main = thread owning the skin windows. Helpers = processes descended from the instance created after launch. GPU = GPU Engine Running Time deltas. Rounds interleave scenarios.'
        Limitations      = 'Off-screen windows are still updated and drawn by Rainmeter, but DWM composition of on-screen layered windows is not represented. Isolated profiles keep Media providers inert and lack WebNowPlaying unless supplied. CPU time is tick-accounted (~15.6 ms granularity per thread); short-lived helper processes that exit between snapshots are undercounted. Frequency scaling and other machine load add noise; compare by trial spread.'
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
    $summary
}

Write-Host ("Scenarios: {0}  Trials: {1}  Settle: {2}s  Window: {3}s  Preferences: {4}" -f $plan.Count, $Trials, $SettleSeconds, $MeasureSeconds, $Preferences) -ForegroundColor Cyan
for ($trial = 1; $trial -le $Trials; $trial++) {
    $order = @($plan)
    $shift = ($trial - 1) % [math]::Max(1, $order.Count)
    if ($shift -gt 0) { $order = @($order[$shift..($order.Count - 1)]) + @($order[0..($shift - 1)]) }
    foreach ($item in $order) {
        try {
            $row = Invoke-Trial $item $trial
            $results.Add($row)
            Write-Host ("  [{0}/{1}] {2,-16} main {3,6:N2}%  other {4,5:N2}%  helpers {5,5:N2}%  total {6,6:N2}% (p95 {7,6:N2})  ctx/s {8,6:N0}  priv {9,5:N0}+{10,4:N0} MB  gpu {11,5:N2}%  load {12,6:N0} ms" -f `
                $trial, $Trials, $item.Name, $row.MainCpuPct, $row.OtherCpuPct, $row.HelperCpuPct, $row.TotalCpuPct, $row.TotalP95Pct, $row.RmCtxPerSec, $row.RmPrivateMB, $row.HelperPrivateMB, $row.GpuAllPct, $row.LoadMs)
        }
        catch {
            Write-Warning ("{0} trial {1} failed: {2}" -f $item.Name, $trial, $_.Exception.Message)
        }
        $null = Save-Report
    }
}

$summary = Save-Report
$logPath = Join-Path $runRoot 'Rainmeter.log'
if (Test-Path -LiteralPath $logPath) {
    $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
    if ($errors.Count) { Write-Host "Rainmeter log errors: $($errors.Count) (see $logPath)" -ForegroundColor Yellow }
}
Write-Host ''
Write-Host 'Median per scenario (% of one core):' -ForegroundColor Green
foreach ($name in $summary.Keys) {
    $s = $summary[$name]
    Write-Host ("  {0,-16} main {1,6:N2}  other {2,5:N2}  helpers {3,5:N2}  total {4,6:N2}  p95 {5,6:N2}  ctx/s {6,6:N0}  priv {7,5:N0}+{8,4:N0} MB  gpu {9,5:N2}  [{10}]" -f `
        $name, $s.MainCpuPct.Median, $s.OtherCpuPct.Median, $s.HelperCpuPct.Median, $s.TotalCpuPct.Median, $s.TotalP95Pct.Median, $s.RmCtxPerSec.Median, $s.RmPrivateMB.Median, $s.HelperPrivateMB.Median, $s.GpuAllPct.Median, $s.HelperNames)
}
Write-Host "Report: $outPath"
