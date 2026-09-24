#requires -Version 5.1
<#
.SYNOPSIS
Measures the runtime cost of ToolTipText across the Parallax suite.

.DESCRIPTION
Stages a clean copy of the suite, optionally strips every ToolTipText= line from
the staged copy, then cold-starts an ISOLATED Rainmeter instance against that
stage N times and records, per trial:

  * LoadMs      - wall time from process start until every expected skin window
                  exists AND every skin's Lua harness has written its report
                  (i.e. full parse + meter construction complete).
  * WorkingSet  - process working set after settle.
  * PrivateMB   - private (committed) bytes after settle.
  * UserObjects - USER handle count (GetGuiResources). Rainmeter creates one
                  TOOLTIPS_CLASS window per tooltip-bearing meter, so this is the
                  direct measure of tooltip window pressure.
  * GdiObjects  - GDI handle count.
  * Handles     - total kernel handle count.
  * IdleCpuMs   - processor time consumed across a fixed idle window after settle.

Safety: the isolated instance is launched with an explicit generated Rainmeter.ini
inside the stage, its windows are placed off-screen, and ONLY the PID this script
started is sampled or terminated. No bangs are ever sent (a bang could be routed
to a live Rainmeter instance), and no file outside the generated stage is written.

.EXAMPLE
  pwsh tools\Benchmark-Tooltips.ps1 -Variant baseline -Trials 5
  pwsh tools\Benchmark-Tooltips.ps1 -Variant stripped -Trials 5
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),

    # baseline = stage exactly as the working tree stands.
    # stripped = stage, then delete every ToolTipText= line (upper bound on savings).
    [ValidateSet('baseline', 'stripped')][string]$Variant = 'baseline',

    # main     = the always-on utility skins.
    # settings = the per-utility Settings panels.
    # both     = everything at once (covers all 658 tooltips).
    [ValidateSet('main', 'settings', 'both')][string]$Scope = 'both',

    [ValidateRange(1, 25)][int]$Trials = 5,
    [ValidateRange(2, 60)][int]$SettleSeconds = 8,
    [ValidateRange(0, 120)][int]$IdleSeconds = 10,
    [string]$Label = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) {
    throw 'Existing Rainmeter installation required; this script downloads and installs nothing.'
}

$mainModules = @('Settings', 'Welcome', 'Chronometer', 'CPU', 'RAM', 'GPU', 'IO', 'Network', 'Media', 'Visualizer')
# Modules that own a Settings panel (Settings/ColorPicker/Welcome are themselves panels).
$settingsModules = @('Chronometer', 'CPU', 'RAM', 'GPU', 'IO', 'Network', 'Media', 'Visualizer')

# --------------------------------------------------------------------------
# Native helpers: enumerate only our own windows, and read GUI resource counts.
# --------------------------------------------------------------------------
if (-not ('ParallaxBenchNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxBenchNative {
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint uiFlags);

    private static string ClassOf(IntPtr hwnd) {
        var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity); return cls.ToString();
    }

    // Counts every window of the given class owned by the pid, top-level and child alike.
    // Rainmeter creates one tooltips_class32 window per tooltip-bearing meter, so this is
    // the ground truth for tooltip pressure INCLUDING tooltips assigned at runtime from Lua.
    public static int CountWindowsOfClass(uint pid, string className) {
        int found = 0;
        EnumCallback child = null;
        child = (hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner == pid && string.Equals(ClassOf(hwnd), className, StringComparison.OrdinalIgnoreCase)) found++;
            EnumChildWindows(hwnd, child, IntPtr.Zero);
            return true;
        };
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            if (string.Equals(ClassOf(hwnd), className, StringComparison.OrdinalIgnoreCase)) found++;
            EnumChildWindows(hwnd, child, IntPtr.Zero);
            return true;
        }, IntPtr.Zero);
        return found;
    }

    // Counts only top-level RainmeterMeterWindow windows owned by the given pid.
    public static int CountSkinWindows(uint pid) {
        int found = 0;
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() == "RainmeterMeterWindow") found++;
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static uint GdiObjects(IntPtr h)  { return GetGuiResources(h, 0); }
    public static uint UserObjects(IntPtr h) { return GetGuiResources(h, 1); }
}
'@
}

# --------------------------------------------------------------------------
# Stage a clean copy, then apply the variant transform to the STAGE only.
# --------------------------------------------------------------------------
$stageVersion = ('bench-{0}-{1}' -f $Variant, ([guid]::NewGuid().ToString('N').Substring(0, 8)))
Write-Host "Staging suite ($Variant)..." -ForegroundColor Cyan
$stage = & (Join-Path $PSScriptRoot 'Stage-Parallax.ps1') -Version $stageVersion
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$encoding = [Text.UTF8Encoding]::new($false)

foreach ($directory in @('Layouts', 'Plugins', 'Addons')) {
    $path = Join-Path $runRoot $directory
    if (-not (Test-Path -LiteralPath $path)) { $null = New-Item -ItemType Directory -Path $path }
}

function Assert-InStage([string]$Path) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside the generated benchmark stage: $Path"
    }
}
function Write-RunFile([string]$Path, [string]$Content) {
    Assert-InStage $Path
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

$strippedLines = 0
$strippedFiles = 0
if ($Variant -eq 'stripped') {
    $targets = @(Get-ChildItem -LiteralPath $parallaxRoot -Recurse -File -Include '*.ini', '*.inc')
    foreach ($file in $targets) {
        Assert-InStage $file.FullName
        $text = [IO.File]::ReadAllText($file.FullName)
        $before = ([regex]::Matches($text, '(?im)^[ \t]*ToolTipText[ \t]*=.*$')).Count
        if ($before -eq 0) { continue }
        # Remove the whole line including its newline so section layout is untouched.
        $text = [regex]::Replace($text, '(?im)^[ \t]*ToolTipText[ \t]*=.*\r?\n?', '')
        [IO.File]::WriteAllText($file.FullName, $text, $encoding)
        $strippedLines += $before
        $strippedFiles++
    }
    Write-Host "Stripped $strippedLines ToolTipText line(s) from $strippedFiles staged file(s)." -ForegroundColor Yellow
}

# Count what actually remains in the stage, so the report is self-verifying.
$remainingTips = 0
foreach ($file in @(Get-ChildItem -LiteralPath $parallaxRoot -Recurse -File -Include '*.ini', '*.inc')) {
    $remainingTips += ([regex]::Matches([IO.File]::ReadAllText($file.FullName), '(?im)^[ \t]*ToolTipText[ \t]*=.*$')).Count
}

# --------------------------------------------------------------------------
# Build the isolated Rainmeter.ini and inject a completion-signal Lua measure.
# --------------------------------------------------------------------------
$harnessPath = Join-Path $runRoot 'BenchHarness.lua'
Write-RunFile $harnessPath @'
-- Writes one report per loaded skin on first Update after initialization.
-- Used purely as a "this skin finished building" signal for load timing.
local reported = false
function Initialize() end
function Update()
    if reported then return 0 end
    local path = SELF:GetOption('ReportPath', '')
    if path == '' then return 0 end
    local file = io.open(path, 'wb')
    if file then
        file:write('Config=', SKIN:GetVariable('CURRENTCONFIG'), '\n')
        file:write('File=', SKIN:GetVariable('CURRENTFILE'), '\n')
        file:close()
        reported = true
    end
    return 0
end
'@

$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$entries = [Collections.Generic.List[object]]::new()

function Add-Entry([string]$Config, [string]$RelativeConfig, [string]$File, [string]$ReportKey) {
    $configPath = Join-Path $parallaxRoot $RelativeConfig
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Benchmark config missing: $RelativeConfig" }
    $variants = @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter '*.ini' | Sort-Object Name)
    $active = 1
    for ($index = 0; $index -lt $variants.Count; $index++) { if ($variants[$index].Name -eq $File) { $active = $index + 1 } }
    $reportPath = Join-Path $runRoot ("report-$ReportKey.txt")
    $source = [IO.File]::ReadAllText($configPath)
    $source += "`n[MeasureParallaxBench]`nMeasure=Script`nScriptFile=$harnessPath`nReportPath=$reportPath`n"
    Write-RunFile $configPath $source
    $script:ini += "`n[$Config]`nActive=$active`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $entries.Add([pscustomobject]@{ Key = $ReportKey; Config = $Config; ReportPath = $reportPath })
}

if ($Scope -in @('main', 'both')) {
    foreach ($module in $mainModules) {
        $file = "$module.ini"
        if ($module -eq 'Media') { $file = 'Media.ini' }
        if ($module -eq 'IO') { $file = 'IO-Disk.ini' }
        Add-Entry -Config "Parallax\$module" -RelativeConfig "$module\$file" -File $file -ReportKey "main-$module"
    }
}
if ($Scope -in @('settings', 'both')) {
    foreach ($module in $settingsModules) {
        Add-Entry -Config "Parallax\$module\Settings" -RelativeConfig "$module\Settings\Settings.ini" -File 'Settings.ini' -ReportKey "settings-$module"
    }
}

Write-RunFile $iniPath $ini
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-RunFile (Join-Path $runRoot 'BENCHMARK-ONLY.txt') "Generated benchmark stage with instrumentation. Not distributable.`n"

$expectedWindows = $entries.Count
Write-Host "Scope=$Scope  Skins=$expectedWindows  ToolTipText lines present in stage: $remainingTips" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# Trial loop: cold start, wait for full build, sample, terminate.
# --------------------------------------------------------------------------
$results = [Collections.Generic.List[object]]::new()

for ($trial = 1; $trial -le $Trials; $trial++) {
    foreach ($entry in $entries) { if (Test-Path -LiteralPath $entry.ReportPath) { Remove-Item -LiteralPath $entry.ReportPath -Force } }

    $process = $null
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
        $pid32 = [uint32]$process.Id

        $loadMs = $null
        $deadline = [datetime]::UtcNow.AddSeconds(90)
        while ([datetime]::UtcNow -lt $deadline) {
            $process.Refresh()
            if ($process.HasExited) { throw "Benchmark instance exited early; inspect $runRoot\Rainmeter.log" }
            $windows = [ParallaxBenchNative]::CountSkinWindows($pid32)
            if ($windows -ge $expectedWindows) {
                $ready = $true
                foreach ($entry in $entries) { if (-not (Test-Path -LiteralPath $entry.ReportPath)) { $ready = $false; break } }
                if ($ready) { $watch.Stop(); $loadMs = $watch.Elapsed.TotalMilliseconds; break }
            }
            Start-Sleep -Milliseconds 15
        }
        if ($null -eq $loadMs) { throw "Timed out waiting for $expectedWindows skins to finish building; inspect $runRoot\Rainmeter.log" }

        Start-Sleep -Seconds $SettleSeconds
        $process.Refresh()
        if ($process.HasExited) { throw 'Benchmark instance exited during settle.' }

        $handle = $process.Handle
        $cpuStart = $process.TotalProcessorTime
        $sample = [ordered]@{
            Trial        = $trial
            LoadMs       = [math]::Round($loadMs, 1)
            WorkingSetMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
            PrivateMB    = [math]::Round($process.PrivateMemorySize64 / 1MB, 2)
            UserObjects  = [int][ParallaxBenchNative]::UserObjects($handle)
            GdiObjects   = [int][ParallaxBenchNative]::GdiObjects($handle)
            Handles      = $process.HandleCount
            SkinWindows  = [ParallaxBenchNative]::CountSkinWindows($pid32)
            TipWindows   = [ParallaxBenchNative]::CountWindowsOfClass($pid32, 'tooltips_class32')
        }

        if ($IdleSeconds -gt 0) {
            Start-Sleep -Seconds $IdleSeconds
            $process.Refresh()
            if ($process.HasExited) { throw 'Benchmark instance exited during idle window.' }
            $sample['IdleCpuMs'] = [math]::Round(($process.TotalProcessorTime - $cpuStart).TotalMilliseconds, 1)
            $sample['IdleSeconds'] = $IdleSeconds
        }

        $results.Add([pscustomobject]$sample)
        Write-Host ("  trial {0}/{1}: load {2,7:N1} ms  tips {3,4}  ws {4,6:N1} MB  USER {5,5}  GDI {6,5}  idleCPU {7} ms" -f `
            $trial, $Trials, $sample.LoadMs, $sample.TipWindows, $sample.WorkingSetMB, $sample.UserObjects, $sample.GdiObjects, $(if ($sample.Contains('IdleCpuMs')) { $sample.IdleCpuMs } else { 'n/a' }))
    }
    finally {
        if ($null -ne $process) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(10000) }
            $process.Dispose()
        }
    }
    Start-Sleep -Milliseconds 800
}

# --------------------------------------------------------------------------
# Aggregate. Median is used throughout; cold-start timing is noisy at the tail.
# --------------------------------------------------------------------------
function Get-Median([double[]]$Values) {
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $mid = [int][math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return $sorted[$mid] }
    return ($sorted[$mid - 1] + $sorted[$mid]) / 2
}

$metrics = @('LoadMs', 'TipWindows', 'WorkingSetMB', 'PrivateMB', 'UserObjects', 'GdiObjects', 'Handles')
if ($IdleSeconds -gt 0) { $metrics += 'IdleCpuMs' }
$summary = [ordered]@{}
foreach ($metric in $metrics) {
    $values = @($results | ForEach-Object { [double]$_.$metric })
    $summary[$metric] = [ordered]@{
        Median = [math]::Round((Get-Median $values), 2)
        Min    = [math]::Round(($values | Measure-Object -Minimum).Minimum, 2)
        Max    = [math]::Round(($values | Measure-Object -Maximum).Maximum, 2)
    }
}

$logPath = Join-Path $runRoot 'Rainmeter.log'
$logErrors = @()
if (Test-Path -LiteralPath $logPath) { $logErrors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }

$report = [ordered]@{
    CapturedUtc       = [DateTime]::UtcNow.ToString('o')
    Label             = $Label
    Variant           = $Variant
    Scope             = $Scope
    Trials            = $Trials
    SettleSeconds     = $SettleSeconds
    IdleSeconds       = $IdleSeconds
    RainmeterVersion  = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
    SkinsLoaded       = $expectedWindows
    ToolTipLinesInStage = $remainingTips
    StrippedLines     = $strippedLines
    StageRoot         = $runRoot
    Summary           = $summary
    Trialwise         = @($results.ToArray())
    LogErrors         = $logErrors
    Method            = 'Cold start of an isolated Rainmeter instance per trial. LoadMs = process start until every skin window exists and every skin Lua harness has written its report. Memory/handles sampled after settle; IdleCpuMs is processor time across the idle window. Only the launched PID is sampled or terminated; no bangs are sent.'
    Limitations       = 'Cold-start time includes constant process/plugin init overhead, so compare variants by difference rather than treating LoadMs as parse time. Machine is not quiesced; other processes may add noise. Does not measure hover latency or long-run behavior.'
}

$outDir = Join-Path $projectRoot 'build\tooltip-benchmark'
if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Path $outDir -Force }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
$outName = if ($Label) { "$stamp-$Variant-$Scope-$Label.json" } else { "$stamp-$Variant-$Scope.json" }
$outPath = Join-Path $outDir $outName
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Host ''
Write-Host "=== $Variant / $Scope  (n=$Trials, $remainingTips tooltips in stage) ===" -ForegroundColor Green
foreach ($metric in $metrics) {
    Write-Host ("  {0,-13} median {1,10}   [{2} .. {3}]" -f $metric, $summary[$metric].Median, $summary[$metric].Min, $summary[$metric].Max)
}
if ($logErrors.Count) { Write-Host "  Rainmeter log errors: $($logErrors.Count)" -ForegroundColor Yellow }
Write-Host "Report: $outPath"

[pscustomobject]@{ Report = $outPath; StageRoot = $runRoot; Summary = $summary; ToolTips = $remainingTips }
