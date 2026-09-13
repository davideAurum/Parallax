#requires -Version 5.1
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $projectRoot 'Skins\Parallax'
$runRoot = Join-Path $projectRoot ('build\theme-dropdown-test-' + [Guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test downloads and installs nothing.' }
foreach ($parent in @($projectRoot, (Join-Path $projectRoot 'build'))) {
    if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test parent must not be a junction.' }
}
$null = New-Item -ItemType Directory -Path $runRoot

function Write-Isolated([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside isolated theme test.' }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}
function Set-IniValue([string]$Content, [string]$Name, [string]$Value) {
    $pattern = '(?im)^'+[regex]::Escape($Name)+'=[^\r\n]*'
    if ($Content -match $pattern) { return [regex]::Replace($Content, $pattern, ($Name+'='+$Value)) }
    return $Content.TrimEnd()+"`r`n$Name=$Value`r`n"
}
function Read-Variables([string]$Path) {
    $values = @{}
    foreach ($line in (Get-Content -LiteralPath $Path)) { if ($line -match '^([^;\[=]+)=(.*)$') { $values[$matches[1]]=$matches[2] } }
    return $values
}
function Await-Report([string]$Path, [int]$TimeoutMs=7000) {
    # File-system events avoid periodic process discovery and process polling.
    $watcher = [IO.FileSystemWatcher]::new((Split-Path -Parent $Path))
    $watcher.NotifyFilter = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents = $true
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($true) {
            if (Test-Path -LiteralPath $Path) {
                $text = [IO.File]::ReadAllText($Path)
                if ($text -match '^(PASS|FAIL)\r?\n') {
                    if ($text -match '^FAIL') { throw $text }
                    return $text
                }
            }
            $remaining = $TimeoutMs-[int]$clock.ElapsedMilliseconds
            if ($remaining -le 0) { throw "Timed out waiting for $Path" }
            $null = $watcher.WaitForChanged([IO.WatcherChangeTypes]::All, [Math]::Min($remaining,1000))
        }
    } finally { $watcher.Dispose(); $clock.Stop() }
}

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxThemeDropdownNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxThemeDropdownNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public int Width, Height; }
    private delegate bool Callback(IntPtr hwnd, IntPtr ignored);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static Window[] OwnWindows(uint pid) {
        var result = new List<Window>();
        EnumWindows((hwnd, ignored) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(128); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            RECT rect; if (GetWindowRect(hwnd, out rect)) result.Add(new Window { Handle=hwnd, Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top });
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
function Capture-OwnWindow([Diagnostics.Process]$Process, [string]$Path, [int]$Width, [int]$Height) {
    $windows = @([ParallaxThemeDropdownNative]::OwnWindows([uint32]$Process.Id))
    if ($windows.Count -ne 1) { throw "Expected one isolated window, found $($windows.Count)." }
    $window = $windows[0]
    if ($window.Width -ne $Width -or $window.Height -ne $Height) { throw "Native window unexpectedly resized: $($window.Width)x$($window.Height)." }
    $bitmap = [Drawing.Bitmap]::new($Width,$Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxThemeDropdownNative]::PrintWindow($window.Handle,$hdc,2)
        $graphics.ReleaseHdc($hdc); $hdc=[IntPtr]::Zero
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($x=0; $x -lt $Width; $x+=3) { for ($y=0; $y -lt $Height; $y+=3) { $null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
        if (-not $printed -or $colors.Count -le 16) { throw 'PrintWindow returned blank or unsupported output.' }
        $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
        return [pscustomobject]@{Path=$Path;Width=$Width;Height=$Height;Colors=$colors.Count;Method='PrintWindow, own PID only'}
    } finally {
        if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
        $graphics.Dispose(); $bitmap.Dispose()
    }
}

$sourceSettings = Get-Content -LiteralPath "$sourceRoot\Settings\Settings.ini" -Raw
foreach ($name in @('MeterThemeSelect','MeterThemeDefault','MeterThemeDismiss','MeterThemePopup','MeterThemeArrow')) {
    if ($sourceSettings -notmatch ('(?m)^\['+[regex]::Escape($name)+'\]\r?$')) { throw "Source not ready: missing $name." }
}
if ($sourceSettings -match '(?m)^\[MeterSurface(?:Dark|Light|Glass)\]') { throw 'Legacy surface choices remain in the source.' }
$leave = [regex]::Match($sourceSettings, '(?m)^MouseLeaveAction=([^\r\n]+)').Groups[1].Value
if ($leave -notmatch 'CloseThemeMenu\(\)') { throw 'Source MouseLeaveAction must close the theme menu.' }
$defaults = Read-Variables "$sourceRoot\@Resources\Defaults.inc"
# Explicit appearance contract; layout size and update cadence are excluded.
$appearanceKeys = @('Theme','FontFace','FontSize','PanelPadding','CornerRadius','TextColor','MutedColor','AccentColor','BackgroundColor','BorderColor','TrackColor','GraphBackgroundColor','GridColor','GraphHeight','GoodColor','WarningColor','DangerColor','CPUColor','RAMColor','GPUColor','DiskReadColor','DiskWriteColor','NetworkInColor','NetworkOutColor','MediaColor','ClockColor')
$appearanceKeys += @('AccentColor2','TitleFontSize','HeaderFontSize','TitleTextColor','HeaderTextColor','BorderThickness','DividerColor','DividerThickness')
$appearanceKeys += @('TableHeaderBorderColor','TableHeaderBorderThickness','DataBarThickness')
$records = [Collections.Generic.List[object]]::new()
foreach ($case in @(@{Name='default';Scale='1';ColumnWidth='220';Width=456;Height=766},@{Name='narrow';Scale='0.75';ColumnWidth='180';Width=282;Height=575})) {
    $caseRoot=Join-Path $runRoot $case.Name
    $skinRoot=Join-Path $caseRoot 'Skins'
    $parallaxRoot=Join-Path $skinRoot 'Parallax'
    $process=$null
    foreach ($relative in @('','Skins','Skins\Parallax','Skins\Parallax\Settings','Skins\Parallax\@Resources','Skins\Parallax\@Resources\User','Skins\Parallax\@Resources\Scripts','Layouts','Plugins','Addons','captures')) {
        $null=New-Item -ItemType Directory -Path (Join-Path $caseRoot $relative)
    }
    foreach ($file in @('Defaults.inc','Geometry.inc','Styles.inc','User\Settings.inc','Scripts\Settings.lua')) {
        Copy-Item -LiteralPath (Join-Path "$sourceRoot\@Resources" $file) -Destination (Join-Path "$parallaxRoot\@Resources" $file)
    }
    Copy-Item -LiteralPath "$sourceRoot\@Resources\Fonts" -Destination "$parallaxRoot\@Resources\Fonts" -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ThemeDropdownHarness.lua') -Destination (Join-Path $caseRoot 'Harness.lua')
    $userPath=Join-Path $parallaxRoot '@Resources\User\Settings.inc'
    $user=Get-Content -LiteralPath $userPath -Raw
    $sentinels=@{Scale=$case.Scale;ColumnWidth=$case.ColumnWidth;Gutter='8';MetricsInterval='2000';SensorInterval='4000';CapacityInterval='60000';VisualizerInterval='100';CustomThemeSentinel='preserve-me'}
    foreach ($key in $sentinels.Keys) { $user=Set-IniValue $user $key $sentinels[$key] }
    foreach ($key in $appearanceKeys) {
        $value=if ($key -eq 'Theme') {'custom-test'} elseif ($key -eq 'FontFace') {'Segoe UI'} elseif ($key -eq 'FontSize' -or $key -eq 'HeaderFontSize') {'10'} elseif ($key -eq 'TitleFontSize') {'12'} elseif ($key -eq 'BorderThickness' -or $key -eq 'DividerThickness' -or $key -eq 'TableHeaderBorderThickness') {'4'} elseif ($key -eq 'DataBarThickness') {'9.5'} elseif ($key -eq 'PanelPadding') {'8'} elseif ($key -eq 'CornerRadius') {'6'} elseif ($key -eq 'GraphHeight') {'41'} else {'101,102,103'}
        $user=Set-IniValue $user $key $value
    }
    Write-Isolated $userPath $user
    $overridePath=Join-Path $parallaxRoot '@Resources\User\CPU.inc'
    $override="[Variables]`nFontFace=Consolas`nCPUColor=111,22,33`nScale=1.25`nColumns=2`n"
    Write-Isolated $overridePath $override
    $settings=[regex]::Replace($sourceSettings,'(?m)^Update=-1\r?$','Update=100')
    $settings+="`n[MeasureThemeDropdownHarness]`nMeasure=Script`nScriptFile=$caseRoot\Harness.lua`nReportDirectory=$caseRoot\`nExpectedWidth=$($case.Width)`nExpectedHeight=$($case.Height)`nSourceMouseLeaveAction=$leave`n"
    Write-Isolated (Join-Path $parallaxRoot 'Settings\Settings.ini') $settings
    $iniPath=Join-Path $caseRoot 'Rainmeter.ini'
    Write-Isolated $iniPath "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[Parallax\Settings]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    Write-Isolated (Join-Path $caseRoot 'Rainmeter.data') "[Rainmeter]`n"
    $sequence=0
    try {
        $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $caseRoot -WindowStyle Hidden -PassThru
        $null=Await-Report (Join-Path $caseRoot 'ready-1.txt') 12000
        foreach ($action in @('toggle','toggle','toggle','dismiss','toggle','leave','toggle')) {
            $sequence++
            Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|$action"
            $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
        }
        $sequence++
        Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|select"
        $null=Await-Report (Join-Path $caseRoot 'ready-2.txt')
        $actual=Read-Variables $userPath
        foreach ($key in $appearanceKeys) { if ($actual[$key] -ne $defaults[$key]) { throw "$($case.Name): Default did not restore $key. Expected '$($defaults[$key])', got '$($actual[$key])'." } }
        foreach ($key in $sentinels.Keys) { if ($actual[$key] -ne $sentinels[$key]) { throw "$($case.Name): Theme changed unrelated $key." } }
        if ([IO.File]::ReadAllText($overridePath) -ne $override) { throw 'Theme modified module overrides.' }
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\closed.png') $case.Width $case.Height))
        $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|toggle"
        $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\open.png') $case.Width $case.Height))
        $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|dismiss"
        $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
        # A fixed quiet period detects reinitialization loops without process polling.
        Start-Sleep -Milliseconds 1200
        if ([IO.File]::ReadAllText((Join-Path $caseRoot 'generation.txt')) -ne '2') { throw 'Theme selection caused an unexpected refresh loop.' }
        $logPath=Join-Path $caseRoot 'Rainmeter.log'
        if (Test-Path -LiteralPath $logPath) {
            $errors=@(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
            if ($errors.Count) { throw ($errors -join "`n") }
        }
    } finally {
        if ($null -ne $process) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null=$process.WaitForExit(5000) }
            $process.Dispose()
        }
    }
}
$report=[ordered]@{Status='PASS';Runs=2;CaptureMethod='Own PID PrintWindow, offscreen isolated windows';SourceActions='Trigger toggle; outside dismiss; source MouseLeaveAction; Default selection';Persistence='Appearance restored; size, cadence, custom key and module override file preserved';RefreshGenerationsPerRun=2;Captures=$records.ToArray();Limitations='Executes actual source action strings in the native Rainmeter instance. Does not simulate system cursor hit testing, keyboard focus, mixed DPI, or the live user configuration.'}
Write-Isolated (Join-Path $runRoot 'report.json') ($report | ConvertTo-Json -Depth 6)
[pscustomobject]@{Status='PASS';RunRoot=$runRoot;Captures=$records.ToArray()}
