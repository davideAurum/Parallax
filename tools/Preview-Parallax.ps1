#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet('Settings','ColorPicker','Welcome','Chronometer','CPU','RAM','GPU','IO','Network','Media','Visualizer')]
    [string[]]$Modules = @('Settings','Welcome','Chronometer','CPU','RAM','GPU','IO','Network','Media','Visualizer'),
    [ValidateRange(4,30)][int]$SettleSeconds = 8,
    [ValidateSet('source','0.75','1','1.25','1.5','2')][string]$Scale = 'source',
    [ValidateSet(0,180,200,220,240,280,320)][int]$ColumnWidth = 0,
    [ValidateRange(6,12)][Nullable[double]]$TitleFontSize = $null,
    [ValidateSet(1,2)][Nullable[int]]$Columns = $null,
    [switch]$UtilitySettings,
    [ValidateSet('IO-Disk.ini')][string]$IOVariant = 'IO-Disk.ini'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }
$stage = & (Join-Path $PSScriptRoot 'Stage-Parallax.ps1') -Version 'visual-preview'
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$captureRoot = Join-Path $runRoot 'captures'
$encoding = [Text.UTF8Encoding]::new($false)
foreach ($directory in @('Layouts','Plugins','Addons','captures')) { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $directory) }

function Write-RunFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated preview directory.' }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

# Every test-only addition is made in the fresh stage. No live Rainmeter files are read or changed.
Write-RunFile (Join-Path $runRoot 'PREVIEW-ONLY.txt') "This stage contains preview instrumentation. Do not package or distribute it.`nThe stage manifest describes the source copy before instrumentation and preview overrides.`n"
$userSettingsPath = Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$userSettings = Get-Content -LiteralPath $userSettingsPath -Raw
if ($Scale -ne 'source') { $userSettings = [regex]::Replace($userSettings, '(?m)^Scale=.*$', "Scale=$Scale") }
if ($ColumnWidth -ne 0) { $userSettings = [regex]::Replace($userSettings, '(?m)^ColumnWidth=.*$', "ColumnWidth=$ColumnWidth") }
if ($null -ne $TitleFontSize) {
    $titleSizeText = $TitleFontSize.ToString([Globalization.CultureInfo]::InvariantCulture)
    $userSettings = [regex]::Replace($userSettings, '(?m)^TitleFontSize=[^\r\n]*', "TitleFontSize=$titleSizeText")
}
Write-RunFile $userSettingsPath $userSettings
$harnessPath = Join-Path $runRoot 'PreviewHarness.lua'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tests\PreviewHarness.lua') -Destination $harnessPath
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$entries = [Collections.Generic.List[object]]::new()
foreach ($module in $Modules) {
    if ($module -notin @('Settings','ColorPicker','Welcome') -and $null -ne $Columns) {
        $moduleSettingsPath = Join-Path $parallaxRoot "@Resources\User\$module.inc"
        if (-not (Test-Path -LiteralPath $moduleSettingsPath -PathType Leaf)) { throw "Missing staged settings for $module column override." }
        $moduleSettings = Get-Content -LiteralPath $moduleSettingsPath -Raw
        if ($moduleSettings -notmatch '(?im)^Columns=') { throw "No Columns key in staged $module settings; add the supported key before previewing this variant." }
        $moduleSettings = [regex]::Replace($moduleSettings, '(?im)^Columns=[^\r\n]*', "Columns=$Columns")
        Write-RunFile $moduleSettingsPath $moduleSettings
    }
    $file = "$module.ini"
    if ($module -eq 'Media') { $file = 'Setup.ini' }
    if ($module -eq 'IO') { $file = $IOVariant }
    $config = "Parallax\$module"
    $relativeConfig = "$module\$file"
    if ($UtilitySettings -and $module -notin @('Settings','ColorPicker','Welcome')) {
        $file = 'Settings.ini'
        $config = "Parallax\$module\Settings"
        $relativeConfig = "$module\Settings\$file"
    }
    $configPath = Join-Path $parallaxRoot $relativeConfig
    if (-not (Test-Path -LiteralPath $configPath)) { throw "Preview config missing: $relativeConfig" }
    $variants = @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter '*.ini' | Sort-Object Name)
    $active = 1
    for ($index = 0; $index -lt $variants.Count; $index++) { if ($variants[$index].Name -eq $file) { $active = $index + 1 } }
    $source = Get-Content -LiteralPath $configPath -Raw
    $source += "`n[MeasureParallaxPreview]`nMeasure=Script`nScriptFile=$harnessPath`nReportPath=$runRoot\native-$module.txt`n"
    Write-RunFile $configPath $source
    $ini += "`n[$config]`nActive=$active`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $entries.Add([pscustomobject]@{ Module=$module; Config=$config; File=$file })
}
Write-RunFile $iniPath $ini
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxPreviewNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxPreviewNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public string ClassName; public int Width, Height; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static Window[] GetOwnWindows(uint pid) {
        var windows = new List<Window>();
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(hwnd, title, title.Capacity);
            RECT rect; if (!GetWindowRect(hwnd, out rect)) return true;
            windows.Add(new Window { Handle=hwnd, Title=title.ToString(), ClassName=cls.ToString(), Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}
'@
}

try {
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds $SettleSeconds
    $process.Refresh()
    if ($process.HasExited) { throw "Preview instance exited early; inspect $runRoot\Rainmeter.log" }
    $windows = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
    if ($windows.Count -ne $entries.Count) { throw "Expected $($entries.Count) isolated skin windows, found $($windows.Count). Inspect $runRoot\Rainmeter.log" }
    foreach ($entry in $entries) {
        $reportPath = Join-Path $runRoot ('native-' + $entry.Module + '.txt')
        if (-not (Test-Path -LiteralPath $reportPath)) { throw "Missing native report for $($entry.Module)." }
        $nativeReport = Get-Content -LiteralPath $reportPath -Raw
        if ($nativeReport -notmatch ('(?m)^Config=' + [regex]::Escape($entry.Config) + '\r?$')) { throw "Incorrect active config for $($entry.Module)." }
        if ($nativeReport -notmatch ('(?m)^File=' + [regex]::Escape($entry.File) + '\r?$')) { throw "Incorrect active variant for $($entry.Module)." }
        $expectedColumns = if ($entry.Module -in @('Settings','ColorPicker','Welcome')) { 2 } elseif ($UtilitySettings) { $null } else { $Columns }
        if ($null -ne $expectedColumns -and $nativeReport -notmatch ('(?m)^Columns=' + $expectedColumns + '\r?$')) { throw "Incorrect effective Columns for $($entry.Module)." }
    }
    $records = [Collections.Generic.List[object]]::new()
    foreach ($window in $windows) {
        if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 4096 -or $window.Height -gt 4096) { throw 'Unexpected own window dimensions.' }
        $match = @($entries | Where-Object { $window.Title -like ('*\' + $_.Module + '\*') -or $window.Title -eq $_.Config -or $window.Title -like ($_.Config + ' *') })
        $name = if ($match.Count -eq 1) { $match[0].Module } else { 'window-' + $window.Handle.ToInt64() }
        $bitmap = [Drawing.Bitmap]::new($window.Width, $window.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $hdc = [IntPtr]::Zero
        try {
            # A sentinel background makes unsupported/blank PrintWindow captures detectable.
            $graphics.Clear([Drawing.Color]::Magenta)
            $hdc = $graphics.GetHdc()
            $printed = [ParallaxPreviewNative]::PrintWindow($window.Handle, $hdc, 2)
            $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
            $colors = [Collections.Generic.HashSet[int]]::new()
            for ($x=0; $x -lt $bitmap.Width; $x+=3) { for ($y=0; $y -lt $bitmap.Height; $y+=3) { $null = $colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
            $usable = $printed -and $colors.Count -gt 16
            $pngPath = Join-Path $captureRoot ($name + '.png')
            $bitmap.Save($pngPath, [Drawing.Imaging.ImageFormat]::Png)
            $records.Add([pscustomobject]@{ Module=$name; Title=$window.Title; Width=$window.Width; Height=$window.Height; PrintWindow=$printed; SampledColors=$colors.Count; Usable=$usable; File=$pngPath })
        } finally {
            if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
            $graphics.Dispose(); $bitmap.Dispose()
        }
    }
    $records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runRoot 'capture-report.json') -Encoding UTF8
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $logErrors = @()
    if (Test-Path -LiteralPath $logPath) { $logErrors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }
    [ordered]@{
        CapturedUtc=[DateTime]::UtcNow.ToString('o')
        RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        Modules=$Modules; Scale=$Scale; ColumnWidth=$ColumnWidth; UtilityColumns=$Columns; IOVariant=$IOVariant; UtilitySettings=[bool]$UtilitySettings
        SettleSeconds=$SettleSeconds; ProcessId=$process.Id
        CaptureMethod='PrintWindow on own PID + RainmeterMeterWindow handles; offscreen windows'
        Instrumented=$true; Distributable=$false; LogErrors=$logErrors
        Limitations='Actual window rendering only. Does not establish traffic accuracy, long-run performance, provider correctness, mixed DPI, or visual quality without inspection.'
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runRoot 'preview-report.json') -Encoding UTF8
    $records | Format-Table Module,Width,Height,PrintWindow,SampledColors,Usable
    Write-Output "Preview evidence retained at $runRoot"
    if (@($records | Where-Object { -not $_.Usable }).Count) { throw 'Window-only capture returned blank or unsupported content. Do not treat these files as visual QA.' }
    if ($logErrors.Count) { $logErrors | Write-Output; throw 'Isolated Rainmeter reported errors; inspect the retained log and captures.' }
    [pscustomobject]@{ RunRoot=$runRoot; Captures=$records.ToArray() }
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
