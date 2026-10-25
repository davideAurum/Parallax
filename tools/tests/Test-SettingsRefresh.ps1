#requires -Version 5.1
# Global Settings refresh behaviour (SHARED-02) in an isolated Rainmeter
# instance: real meter actions, the production Settings.lua/INI and passive
# witness skins that count their own loads. Run under Windows PowerShell 5.1.
[CmdletBinding()]
param([string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot=Join-Path $projectRoot 'Skins\Parallax'
$runRoot=Join-Path $projectRoot ('build\settings-refresh-test-'+[Guid]::NewGuid().ToString('N'))
$skinRoot=Join-Path $runRoot 'Skins'
$parallaxRoot=Join-Path $skinRoot 'Parallax'
$encoding=[Text.UTF8Encoding]::new($false)
$invariant=[Globalization.CultureInfo]::InvariantCulture
$process=$null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed.' }
foreach ($parent in @($projectRoot,(Join-Path $projectRoot 'build'),$sourceRoot)) {
    if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test roots must not be junctions.' }
}
# Witnesses stand in for the suite: All is Parallax-only (CPU, Network, Chronometer...);
# GPU, RAM and IO carry their module groups; Visualizer and Media sit at their real config paths.
$witnesses=[ordered]@{
    All=@{Config='Parallax\WitnessAll';Group='Parallax'}
    GPU=@{Config='Parallax\WitnessGPU';Group='Parallax|ParallaxGPU'}
    RAM=@{Config='Parallax\WitnessRAM';Group='Parallax | ParallaxRAM'}
    IO=@{Config='Parallax\WitnessIO';Group='Parallax|ParallaxIO'}
    Visualizer=@{Config='Parallax\Visualizer';Group='Parallax'}
    Media=@{Config='Parallax\Media';Group='Parallax'}
    # The input-idle coordinator's config and groups (Idle pause minutes).
    Coordinator=@{Config='Parallax\Idle';Group='Parallax | ParallaxIdleCoordinator'}
    Control=@{Config='RefreshControl';Group='RefreshTestOnly'}
}
foreach ($relative in @('','Skins','Skins\Parallax','Skins\Parallax\Settings','Skins\Parallax\@Resources','Skins\Parallax\@Resources\User','Skins\Parallax\@Resources\Scripts','Skins\RefreshDriver','Layouts','Plugins','Addons','captures')) {
    $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $relative)
}
function Write-Isolated([string]$Path,[string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside isolated refresh test.' }
    [IO.File]::WriteAllText($Path,$Content,$encoding)
}
function Read-Values([string]$Path) {
    $values=@{}
    foreach ($line in Get-Content -LiteralPath $Path) { if ($line -match '^([^;\[=]+)=(.*)$') { $values[$matches[1]]=$matches[2] } }
    return $values
}
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Await-Report([string]$Path,[int]$TimeoutMs=15000) {
    $watcher=[IO.FileSystemWatcher]::new((Split-Path -Parent $Path))
    $watcher.NotifyFilter=[IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents=$true
    $clock=[Diagnostics.Stopwatch]::StartNew()
    try {
        while ($true) {
            if (Test-Path -LiteralPath $Path) {
                $content=[IO.File]::ReadAllText($Path)
                if ($content -match '^(PASS|FAIL)\r?\n') {
                    if ($content -match '^FAIL') { throw $content }
                    return (Read-Values $Path)
                }
            }
            $remaining=$TimeoutMs-[int]$clock.ElapsedMilliseconds
            if ($remaining -le 0) { throw "Timed out waiting for $Path; inspect $runRoot\Rainmeter.log" }
            $null=$watcher.WaitForChanged([IO.WatcherChangeTypes]::All,[Math]::Min($remaining,1000))
        }
    } finally { $watcher.Dispose(); $clock.Stop() }
}
function Await-Generation([string]$Role,[int]$Generation,[int]$TimeoutMs=15000) {
    $path=Join-Path $runRoot "$Role-generation.txt"
    $clock=[Diagnostics.Stopwatch]::StartNew()
    while ((Get-Generation $Role) -lt $Generation) {
        if ($clock.ElapsedMilliseconds -gt $TimeoutMs) { throw "Timed out waiting for $Role generation $Generation; inspect $runRoot\Rainmeter.log" }
        $watcher=[IO.FileSystemWatcher]::new($runRoot,"$Role-generation.txt")
        $watcher.NotifyFilter=[IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite
        try { $null=$watcher.WaitForChanged([IO.WatcherChangeTypes]::All,250) } finally { $watcher.Dispose() }
    }
}
function Get-Generation([string]$Role) {
    $path=Join-Path $runRoot "$Role-generation.txt"
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    return [int]([IO.File]::ReadAllText($path))
}
function Get-Generations { $result=[ordered]@{Settings=(Get-Generation 'probe');Driver=(Get-Generation 'driver')}; foreach ($name in $witnesses.Keys) { $result[$name]=Get-Generation $name }; return $result }
function Get-LastLoadClock([string]$Role) { return [double]::Parse(((Get-Content -LiteralPath (Join-Path $runRoot "$Role-loads.txt"))[-1] -split '\|')[1],$invariant) }
function Assert-Generations($Expected,[string]$Context) {
    $actual=Get-Generations
    foreach ($name in $Expected.Keys) { Require ($actual[$name] -eq $Expected[$name]) "${Context}: $name loaded $($actual[$name]) time(s), expected $($Expected[$name])." }
}
$sequence=0
function Send-Steps([string[]]$Steps) {
    $script:sequence++
    Write-Isolated (Join-Path $runRoot 'request.txt') ("$script:sequence|"+($Steps -join ';'))
    return $script:sequence
}
function Expect-UserValue([string]$Key,[string]$Value) {
    $actual=(Read-Values $userPath)[$Key]
    Require ($actual -eq $Value) "Settings.inc $Key is '$actual', expected '$Value'."
}

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxSettingsRefreshNative' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxSettingsRefreshNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    private delegate bool Callback(IntPtr hwnd, IntPtr ignored);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr ignored);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder name, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    // The largest Rainmeter window owned by this test's own process is Settings.
    public static string Capture(uint pid, string path) {
        IntPtr best = IntPtr.Zero; RECT bestRect = new RECT(); long bestArea = 0;
        EnumWindows((hwnd, ignored) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(128); GetClassName(hwnd, cls, cls.Capacity);
            RECT rect;
            if (cls.ToString() == "RainmeterMeterWindow" && GetWindowRect(hwnd, out rect)) {
                long area = (long)(rect.Right - rect.Left) * (rect.Bottom - rect.Top);
                if (area > bestArea) { bestArea = area; best = hwnd; bestRect = rect; }
            }
            return true;
        }, IntPtr.Zero);
        if (best == IntPtr.Zero) throw new InvalidOperationException("Settings window not found.");
        int width = bestRect.Right - bestRect.Left, height = bestRect.Bottom - bestRect.Top;
        using (var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb))
        using (var graphics = Graphics.FromImage(bitmap)) {
            graphics.Clear(Color.Magenta);
            IntPtr hdc = graphics.GetHdc();
            bool printed;
            try { printed = PrintWindow(best, hdc, 2); } finally { graphics.ReleaseHdc(hdc); }
            if (!printed) throw new InvalidOperationException("PrintWindow failed.");
            bitmap.Save(path, ImageFormat.Png);
        }
        return width + "x" + height;
    }
    // Rows whose pixels differ between two same-sized captures.
    public static int[] DiffRows(string a, string b) {
        using (var first = new Bitmap(a)) using (var second = new Bitmap(b)) {
            if (first.Width != second.Width || first.Height != second.Height) throw new InvalidOperationException("Capture sizes differ.");
            var rect = new Rectangle(0, 0, first.Width, first.Height);
            var dataA = first.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var dataB = second.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int stride = Math.Abs(dataA.Stride);
                var rowA = new byte[stride]; var rowB = new byte[stride];
                var rows = new List<int>();
                for (int y = 0; y < first.Height; y++) {
                    Marshal.Copy(IntPtr.Add(dataA.Scan0, y * dataA.Stride), rowA, 0, stride);
                    Marshal.Copy(IntPtr.Add(dataB.Scan0, y * dataB.Stride), rowB, 0, stride);
                    for (int i = 0; i < first.Width * 4; i++) { if (rowA[i] != rowB[i]) { rows.Add(y); break; } }
                }
                return rows.ToArray();
            } finally { first.UnlockBits(dataA); second.UnlockBits(dataB); }
        }
    }
}
'@
}
function Capture([string]$Name) {
    $path=Join-Path $runRoot "captures\$Name.png"
    $size=[ParallaxSettingsRefreshNative]::Capture([uint32]$process.Id,$path)
    return [pscustomobject]@{Name=$Name;Path=$path;Size=$size}
}
function Assert-DiffBands($Before,$After,$Snapshot,[string[]]$Meters,[string]$Context) {
    $rows=@([ParallaxSettingsRefreshNative]::DiffRows($Before.Path,$After.Path))
    Require ($rows.Count -gt 0) "${Context}: the displayed value did not change before the refresh."
    # Tall captures are resampled on some hosts, so allow a few rows of spread.
    $bands=@(foreach ($meter in $Meters) { $edges=$Snapshot[$meter+'Rows'].Split(','); ,@(([int]$edges[0]-4),([int]$edges[1]+4)) })
    foreach ($row in $rows) {
        $inside=$false; foreach ($band in $bands) { if ($row -ge $band[0] -and $row -le $band[1]) { $inside=$true } }
        Require $inside "${Context}: pixels changed outside $($Meters -join '/') (row $row)."
    }
    foreach ($band in $bands) { Require (@($rows | Where-Object { $_ -ge $band[0] -and $_ -le $band[1] }).Count -gt 0) "${Context}: an expected display row did not change." }
    return $rows.Count
}

$sourceFiles=@('Settings\Settings.ini','@Resources\Defaults.inc','@Resources\Geometry.inc','@Resources\Styles.inc','@Resources\User\Settings.inc','@Resources\Scripts\Settings.lua')
$sourceHashes=[ordered]@{}
foreach ($relative in $sourceFiles) {
    $source=Join-Path $sourceRoot $relative
    $sourceHashes[$relative]=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $source -Destination (Join-Path $parallaxRoot $relative)
}
Copy-Item -LiteralPath "$sourceRoot\@Resources\Fonts" -Destination "$parallaxRoot\@Resources\Fonts" -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SettingsRefreshHarness.lua') -Destination (Join-Path $runRoot 'Harness.lua')
$settingsPath=Join-Path $parallaxRoot 'Settings\Settings.ini'
$settings=Get-Content -LiteralPath $settingsPath -Raw
Require ($settings -match '(?m)^OnCloseAction=\[!CommandMeasure MeasureSettings "FlushPending\(\)"\]\r?$') 'Source OnCloseAction changed; review this test.'
# Update=-1 is kept: the probe only adds a ready report and runs actions on request.
$settings=[regex]::Replace($settings,'(?m)^Update=-1\r?$',"Update=-1`r`nOnRefreshAction=[!CommandMeasure SettingsProbe `"Ready()`"]")
$settings+="`r`n[SettingsProbe]`r`nMeasure=Script`r`nScriptFile=$runRoot\Harness.lua`r`nReportDirectory=$runRoot\`r`nRole=probe`r`n"
Write-Isolated $settingsPath $settings
$userPath=Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$user=Get-Content -LiteralPath $userPath -Raw
$baseline=@{Scale='1';ColumnWidth='220';Gutter='8';BackgroundColor='15,15,15,255';MetricsInterval='1000';SensorInterval='2000';CapacityInterval='30000';VisualizerInterval='50';IdlePauseMinutes='0'}
foreach ($key in $baseline.Keys) {
    Require ($user -match ('(?im)^'+$key+'=')) "Missing persisted default: $key"
    $user=[regex]::Replace($user,('(?im)^'+$key+'=[^\r\n]*'),($key+'='+$baseline[$key]))
}
Write-Isolated $userPath $user
foreach ($name in $witnesses.Keys) {
    $config=$witnesses[$name].Config
    $leaf=Split-Path -Leaf $config
    $null=New-Item -ItemType Directory -Force -Path (Join-Path $skinRoot $config)
    Write-Isolated (Join-Path $skinRoot "$config\$leaf.ini") "[Rainmeter]`r`nUpdate=-1`r`nGroup=$($witnesses[$name].Group)`r`n[MeasureWitness]`r`nMeasure=Script`r`nScriptFile=$runRoot\Harness.lua`r`nReportDirectory=$runRoot\`r`nRole=$name`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`n"
}
Write-Isolated (Join-Path $skinRoot 'RefreshDriver\RefreshDriver.ini') "[Rainmeter]`r`nUpdate=100`r`nGroup=RefreshTestDriver`r`n[MeasureDriver]`r`nMeasure=Script`r`nScriptFile=$runRoot\Harness.lua`r`nReportDirectory=$runRoot\`r`nRole=driver`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`n"
$ini="[Rainmeter]`r`nSkinPath=$skinRoot\`r`nDisableVersionCheck=1`r`nDisableAutoUpdate=1`r`nLogging=1`r`nLanguage=1033`r`nTrayIcon=0`r`n"
$ini+="`r`n[Parallax\Settings]`r`nActive=1`r`nWindowX=-20000`r`nWindowY=-20000`r`nKeepOnScreen=0`r`nDraggable=0`r`nClickThrough=1`r`nAlphaValue=255`r`n"
foreach ($config in @($witnesses.Values | ForEach-Object { $_.Config }) + 'RefreshDriver') {
    $ini+="`r`n[$config]`r`nActive=1`r`nWindowX=-21000`r`nWindowY=-21000`r`nKeepOnScreen=0`r`nDraggable=0`r`nClickThrough=1`r`nAlphaValue=0`r`n"
}
Write-Isolated (Join-Path $runRoot 'Rainmeter.ini') $ini
Write-Isolated (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`r`n"
Write-Isolated (Join-Path $runRoot 'TEST-ONLY.txt') "Instrumented disposable refresh QA. Do not distribute. No live Rainmeter configuration is used.`r`n"

$report=[ordered]@{Status='FAIL';RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion;SourceSHA256=$sourceHashes;Scenarios=[Collections.Generic.List[object]]::new()}
$expected=[ordered]@{Settings=1;Driver=1}
foreach ($name in $witnesses.Keys) { $expected[$name]=1 }
$parallaxWitnesses=@('All','GPU','RAM','IO','Visualizer','Media','Coordinator')
try {
    # Existing absolute private INI and SkinPath create a separate Rainmeter instance.
    # No CLI bangs are sent; the live configuration is never read or written.
    $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $runRoot 'Rainmeter.ini')) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $ready=Await-Report (Join-Path $runRoot 'ready-1.txt')
    foreach ($name in $witnesses.Keys) { Await-Generation $name 1 }
    Await-Generation 'driver' 1
    Assert-Generations $expected 'Initial load'
    Require ($ready.MeterScaleInput -eq '100%' -and $ready.MeterBackgroundTransparencyInput -eq '0%' -and $ready.MeterRefreshValue -eq 'Balanced' -and $ready.MeterIdlePauseValue -eq 'Off') 'Unexpected initial display.'
    $idle=Capture 'idle'

    # 1. A burst of five Scale clicks: immediate display and file, one refresh 800 ms after the last click.
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $id=Send-Steps @('click:MeterScaleIncrease','click:MeterScaleIncrease','click:MeterScaleIncrease','click:MeterScaleIncrease','click:MeterScaleIncrease','snap')
    $burst=Await-Report (Join-Path $runRoot "result-$id.txt")
    $burstCapture=Capture 'scale-burst'
    Assert-Generations $expected 'Scale burst before the debounce'
    Require ($burst.ScaleVariable -eq '1') 'Settings reloaded during the burst.'
    Require ($burst.MeterScaleInput -eq '105%' -and $burst.MeterGeometry -like '*Scale: 105%') 'Burst did not step from saved values or update its display at once.'
    Expect-UserValue 'Scale' '1.05'
    $changedRows=Assert-DiffBands $idle $burstCapture $burst @('MeterGeometry','MeterScaleInput') 'Scale burst'
    $actions=@(Get-Content -LiteralPath (Join-Path $runRoot 'clicks.txt'))
    Require ($actions.Count -eq 5 -and @($actions | Where-Object { $_ -ne "MeterScaleIncrease|[!CommandMeasure MeasureSettings `"Adjust('Scale',1)`"]" }).Count -eq 0) 'Source arrow action changed.'
    $applied=Await-Report (Join-Path $runRoot 'ready-2.txt')
    $wallMs=$timer.ElapsedMilliseconds
    foreach ($name in $parallaxWitnesses) { Await-Generation $name 2 }
    $delay=(Get-LastLoadClock 'All')-[double]::Parse($applied.LastClick,$invariant)
    Require ($delay -ge 0.79 -and $delay -le 4) "Debounced refresh came $delay s after the last click."
    Start-Sleep -Milliseconds 1500
    $expected.Settings=2; foreach ($name in $parallaxWitnesses) { $expected[$name]=2 }
    Assert-Generations $expected 'Scale burst after the debounce'
    Require ($applied.ScaleVariable -eq '1.05' -and $applied.MeterScaleInput -eq '105%') 'Reloaded Settings lost the burst value.'
    $appliedCapture=Capture 'scale-applied'
    Require ($appliedCapture.Size -eq "$($applied.Width)x$($applied.Height)" -and $appliedCapture.Size -ne $idle.Size) 'The refreshed Settings window did not take the new scale.'
    $report.Scenarios.Add([pscustomobject]@{Name='Scale burst';Clicks=5;Saved='1.05';RefreshesPerSkin=1;LastClickToRefreshS=[Math]::Round($delay,3);RequestToReadyMs=$wallMs;ChangedRowsBeforeRefresh=$changedRows;Sizes="$($idle.Size) -> $($appliedCapture.Size)"})

    # 2. Transparency steps from the saved alpha, not the loaded one (255 -> 252 -> 249 -> 246).
    $id=Send-Steps @('click:MeterBackgroundTransparencyIncrease','click:MeterBackgroundTransparencyIncrease','click:MeterBackgroundTransparencyIncrease','snap')
    $burst=Await-Report (Join-Path $runRoot "result-$id.txt")
    Assert-Generations $expected 'Transparency burst before the debounce'
    Require ($burst.BackgroundColorVariable -eq '15,15,15,255') 'Settings reloaded during the transparency burst.'
    Require ($burst.MeterBackgroundTransparencyInput -eq '3.53%' -and $burst.MeterBackgroundColorValue -eq '#0F0F0FF6') 'Transparency burst did not step from the saved alpha.'
    Expect-UserValue 'BackgroundColor' '15,15,15,246'
    $applied=Await-Report (Join-Path $runRoot 'ready-3.txt')
    foreach ($name in $parallaxWitnesses) { Await-Generation $name 3 }
    $delay=(Get-LastLoadClock 'All')-[double]::Parse($applied.LastClick,$invariant)
    Require ($delay -ge 0.79 -and $delay -le 4) "Debounced transparency refresh came $delay s after the last click."
    Start-Sleep -Milliseconds 1500
    $expected.Settings=3; foreach ($name in $parallaxWitnesses) { $expected[$name]=3 }
    Assert-Generations $expected 'Transparency burst after the debounce'
    Require ($applied.BackgroundColorVariable -eq '15,15,15,246') 'Reloaded Settings lost the transparency value.'
    $report.Scenarios.Add([pscustomobject]@{Name='Transparency burst';Clicks=3;Saved='15,15,15,246';RefreshesPerSkin=1;LastClickToRefreshS=[Math]::Round($delay,3)})

    # 3. A refresh preset is immediate and reloads only the interval consumers;
    #    Settings shows it in place, and Parallax-only skins are left alone.
    $consumers=@('GPU','RAM','IO','Visualizer','Media')
    $id=Send-Steps @('click:MeterRefreshIncrease','snap')
    $shown=Await-Report (Join-Path $runRoot "result-$id.txt")
    foreach ($name in $consumers) { Await-Generation $name 4 }
    $delay=(Get-LastLoadClock 'GPU')-[double]::Parse($shown.LastClick,$invariant)
    Require ($delay -lt 0.75) "Preset refresh was delayed $delay s."
    Start-Sleep -Milliseconds 1500
    foreach ($name in $consumers) { $expected[$name]=4 }
    Assert-Generations $expected 'Scoped preset'
    Require ($shown.MetricsIntervalVariable -eq '1000') 'Settings reloaded for a preset.'
    Require ($shown.MeterRefreshValue -eq 'Economy' -and $shown.MeterCadence -eq 'Metrics 2s  Sensors 4s  Disk 60s  Spectrum ~10 FPS') 'Settings did not show the preset in place.'
    foreach ($pair in @(@('MetricsInterval','2000'),@('SensorInterval','4000'),@('CapacityInterval','60000'),@('VisualizerInterval','100'))) { Expect-UserValue $pair[0] $pair[1] }
    $report.Scenarios.Add([pscustomobject]@{Name='Preset (scoped, immediate)';Refreshed=($consumers -join ',');NotRefreshed='Settings,All,Control';LastClickToRefreshS=[Math]::Round($delay,3)})

    # 3b. A preset clicked while an arrow refresh is pending refreshes the whole suite once, at once.
    $id=Send-Steps @('click:MeterScaleIncrease','click:MeterRefreshIncrease')
    $applied=Await-Report (Join-Path $runRoot 'ready-4.txt')
    foreach ($name in $parallaxWitnesses) { Await-Generation $name ($expected[$name]+1) }
    $delay=(Get-LastLoadClock 'All')-[double]::Parse($applied.LastClick,$invariant)
    Require ($delay -lt 0.75) "Escalated refresh was delayed $delay s."
    Start-Sleep -Milliseconds 1500
    $expected.Settings=4; foreach ($name in $parallaxWitnesses) { $expected[$name]=$expected[$name]+1 }
    Assert-Generations $expected 'Preset with a pending arrow refresh'
    Require ($applied.ScaleVariable -eq '1.06' -and $applied.MeterRefreshValue -eq 'Balanced' -and $applied.MetricsIntervalVariable -eq '1000') 'Escalated refresh lost a value.'
    Expect-UserValue 'Scale' '1.06'; Expect-UserValue 'MetricsInterval' '1000'
    $report.Scenarios.Add([pscustomobject]@{Name='Preset with a pending arrow';Refreshed='Parallax group, once';LastClickToRefreshS=[Math]::Round($delay,3)})

    # 3c. Idle pause Off -> 5 min: shown at once, saved, then (debounced) the whole
    #    Parallax group reloads once, because every utility gains its hook.
    Send-Steps @('click:MeterIdlePauseIncrease') | Out-Null
    $settingsGeneration=$expected.Settings+1
    $applied=Await-Report (Join-Path $runRoot "ready-$settingsGeneration.txt")
    foreach ($name in $parallaxWitnesses) { Await-Generation $name ($expected[$name]+1) }
    $delay=(Get-LastLoadClock 'All')-[double]::Parse($applied.LastClick,$invariant)
    Require ($delay -ge 0.79 -and $delay -le 4) "Idle pause on applied $delay s after the click."
    Start-Sleep -Milliseconds 1500
    $expected.Settings=$settingsGeneration; foreach ($name in $parallaxWitnesses) { $expected[$name]=$expected[$name]+1 }
    Assert-Generations $expected 'Idle pause Off -> 5 min'
    Require ($applied.IdlePauseMinutesVariable -eq '5' -and $applied.MeterIdlePauseValue -eq '5 min') 'Reloaded Settings lost the Idle pause value.'
    Expect-UserValue 'IdlePauseMinutes' '5'
    $report.Scenarios.Add([pscustomobject]@{Name='Idle pause Off -> 5 min';Refreshed='Parallax group, once';LastClickToRefreshS=[Math]::Round($delay,3)})

    # 3d. 5 -> 10 min: shown at once; only the coordinator reloads (debounced).
    $id=Send-Steps @('click:MeterIdlePauseIncrease','snap')
    $shown=Await-Report (Join-Path $runRoot "result-$id.txt")
    Require ($shown.MeterIdlePauseValue -eq '10 min' -and $shown.IdlePauseMinutesVariable -eq '5') 'Idle pause 10 min was not shown in place.'
    Await-Generation 'Coordinator' ($expected.Coordinator+1)
    $delay=(Get-LastLoadClock 'Coordinator')-[double]::Parse($shown.LastClick,$invariant)
    Require ($delay -ge 0.79 -and $delay -le 4) "Idle pause minutes applied $delay s after the click."
    Start-Sleep -Milliseconds 1500
    $expected.Coordinator=$expected.Coordinator+1
    Assert-Generations $expected 'Idle pause 5 -> 10 min'
    Expect-UserValue 'IdlePauseMinutes' '10'
    $report.Scenarios.Add([pscustomobject]@{Name='Idle pause 5 -> 10 min';Refreshed='Parallax\Idle only';NotRefreshed='Settings and every utility';LastClickToRefreshS=[Math]::Round($delay,3)})

    # 3e. A burst 10 -> 30 -> Off: one whole-group reload (the hook goes away).
    Send-Steps @('click:MeterIdlePauseIncrease','click:MeterIdlePauseIncrease') | Out-Null
    $settingsGeneration=$expected.Settings+1
    $applied=Await-Report (Join-Path $runRoot "ready-$settingsGeneration.txt")
    foreach ($name in $parallaxWitnesses) { Await-Generation $name ($expected[$name]+1) }
    Start-Sleep -Milliseconds 1500
    $expected.Settings=$settingsGeneration; foreach ($name in $parallaxWitnesses) { $expected[$name]=$expected[$name]+1 }
    Assert-Generations $expected 'Idle pause burst 10 -> 30 -> Off'
    Require ($applied.MeterIdlePauseValue -eq 'Off') 'Idle pause Off not shown after the reload.'
    Expect-UserValue 'IdlePauseMinutes' '0'
    $report.Scenarios.Add([pscustomobject]@{Name='Idle pause burst 10 -> 30 -> Off';Refreshed='Parallax group, once'})

    # 4. Closing Settings inside the debounce window still applies the change once (OnCloseAction).
    $id=Send-Steps @('click:MeterScaleDecrease','click:MeterClose')
    foreach ($name in $parallaxWitnesses) { Await-Generation $name ($expected[$name]+1) }
    Start-Sleep -Milliseconds 1500
    foreach ($name in $parallaxWitnesses) { $expected[$name]=$expected[$name]+1 }
    Assert-Generations $expected 'Close inside the debounce window'
    Expect-UserValue 'Scale' '1.05'
    $report.Scenarios.Add([pscustomobject]@{Name='Close with a pending change';Saved='1.05';RefreshesPerWitness=1;SettingsReloads=0})


    $logPath=Join-Path $runRoot 'Rainmeter.log'
    $errors=@(); $warnings=@()
    if (Test-Path -LiteralPath $logPath) {
        $errors=@(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        $warnings=@(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^WARN' })
    }
    Require ($errors.Count -eq 0) ('Native Rainmeter errors: '+($errors -join "`n"))
    foreach ($relative in @('@Resources\Scripts\Settings.lua')) {
        Require ((Get-FileHash -LiteralPath (Join-Path $parallaxRoot $relative) -Algorithm SHA256).Hash -eq $sourceHashes[$relative]) "Copied $relative changed during the test."
    }
    $report.Status='PASS'
    $report.Warnings=$warnings
    $report.Limitations='Real meter actions run through Rainmeter in an isolated instance with stand-in witness skins; physical pointer input, the real module skins, helper relaunch costs and the live configuration are not exercised. Captures are PrintWindow images of an off-screen window.'
    Write-Isolated (Join-Path $runRoot 'report.json') ($report|ConvertTo-Json -Depth 6)
    [pscustomobject]@{Status='PASS';Scenarios=$report.Scenarios.Count;Warnings=$warnings.Count;RunRoot=$runRoot}
    $report.Scenarios | Format-Table -AutoSize | Out-String -Width 220
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null=$process.WaitForExit(5000) }
        $process.Dispose()
    }
}
