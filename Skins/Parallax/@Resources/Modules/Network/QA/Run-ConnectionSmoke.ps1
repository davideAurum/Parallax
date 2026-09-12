#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet(180, 200, 240, 280, 320)][int[]]$ColumnWidths = @(180, 200),
    [ValidateSet('source', 'default', 'maximum')][string]$Typography = 'source',
    [switch]$TypographyEdges,
    [switch]$SurfaceEdges,
    [ValidateRange(12, 60)][int]$TimeoutSeconds = 40,
    [switch]$Capture,
    [switch]$KeepArtifacts
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$runRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('connection-run-' + [guid]::NewGuid().ToString('N'))))
$testProcess = $null
$encoding = [Text.UTF8Encoding]::new($false)
function Assert-RunPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes isolated Connection run: $absolute"
    }
}
function Write-TestFile([string]$Path, [string]$Text) {
    Assert-RunPath $Path
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed by this test.' }
try {
    $settings = "[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $cases = @()
    foreach ($width in $ColumnWidths) { foreach ($scale in @(0.75, 1, 1.25, 1.5, 2)) { foreach ($columns in @(1, 2)) {
        $cases += [pscustomobject]@{ ColumnWidth=$width; Scale=$scale; Columns=$columns; Selector='Best'; WiFiEnabled='1'; WiFiInterface='0'; Kind='layout' }
    } } }
    $cases += [pscustomobject]@{ ColumnWidth=180; Scale=0.75; Columns=1; Selector='Parallax-intentionally-missing-NIC'; WiFiEnabled='1'; WiFiInterface='0'; Kind='invalid-adapter' }
    $cases += [pscustomobject]@{ ColumnWidth=180; Scale=0.75; Columns=1; Selector='Best'; WiFiEnabled='1'; WiFiInterface='-1'; Kind='invalid-wifi' }
    $cases += [pscustomobject]@{ ColumnWidth=200; Scale=1; Columns=1; Selector='Best'; WiFiEnabled='0'; WiFiInterface='0'; Kind='disabled-wifi' }
    foreach ($case in $cases) {
        $case | Add-Member -NotePropertyName Typography -NotePropertyValue $Typography
        $case | Add-Member -NotePropertyName Surface -NotePropertyValue 'source'
    }
    if ($TypographyEdges) {
        foreach ($profile in @('title10-body10','title12-body9')) { foreach ($scale in @(0.75,1,1.25,1.5,2)) {
            $cases += [pscustomobject]@{ ColumnWidth=180; Scale=$scale; Columns=1; Selector='Best'; WiFiEnabled='1'; WiFiInterface='0'; Kind='typography-edge'; Typography=$profile; Surface='source' }
        } }
    }
    if ($SurfaceEdges) {
        foreach ($thickness in @('0','4')) { foreach ($scale in @(0.75,2)) {
            $cases += [pscustomobject]@{ ColumnWidth=180; Scale=$scale; Columns=1; Selector='Best'; WiFiEnabled='1'; WiFiInterface='0'; Kind='surface-edge'; Typography=$Typography; Surface=$thickness }
        } }
    }
    $entries = [Collections.Generic.List[object]]::new()
    $glyphs = [Collections.Generic.List[object]]::new()
    function Add-Glyph([string]$Target, [string]$Text, [bool]$RequireWidth = $true, [bool]$Live = $false) {
        $glyphs.Add([pscustomobject]@{ Target=$Target; Text=$Text; RequireWidth=$RequireWidth; Live=$Live })
    }
    Add-Glyph 'Width' '1x'
    Add-Glyph 'Width' '2x'
    Add-Glyph 'Title' 'Connection'
    # Probe every actual text meter's height. Variable device/address strings may ellipsize.
    foreach ($target in @('Adapter','Description','Status','InternetLabel','Internet','IPLabel','IP',
        'GatewayLabel','Gateway','RxLabel','Rx','TxLabel','Tx','WiFi','SignalLabel','Signal','Radio')) {
        Add-Glyph $target '--' ($target -notin @('Adapter','Description','IP','Gateway','WiFi')) $true
    }
    foreach ($text in @('Detected','Not reported','Unknown')) { Add-Glyph 'Internet' $text }
    foreach ($text in @('100%','0%','Pending','Unavailable','--')) { Add-Glyph 'Signal' $text }
    foreach ($type in @('Ethernet','Wi-Fi','Other')) {
        foreach ($state in @('Up','Down','Disconnected','Not present','Lower layer down','Status unknown','Dormant','Testing','Unavailable')) {
            $display = if ($state -eq 'Lower layer down') { $state } else { $type + ' / ' + $state }
            Add-Glyph 'Status' $display
        }
    }
    foreach ($text in @('Selected NIC not found','Select one adapter','Adapter unavailable')) { Add-Glyph 'Status' $text }
    Add-Glyph 'Adapter' 'Adapter unavailable'
    foreach ($text in @('Wi-Fi unavailable','Check Wi-Fi settings','Wi-Fi off in module')) { Add-Glyph 'WiFi' $text }
    foreach ($text in @('Radio unavailable','Radio: Pending','Radio: 802.11ax','Radio: ir-band')) { Add-Glyph 'Radio' $text }
    foreach ($target in @('IP','Gateway')) { Add-Glyph $target '255.255.255.255' }
    foreach ($target in @('Rx','Tx')) {
        foreach ($unit in @('Mbit/s','Gbit/s','Tbit/s')) {
            Add-Glyph $target ('999.9 ' + $unit)
            Add-Glyph $target ('1000.0 ' + $unit)
        }
    }
    $index = 0
    foreach ($case in $cases) {
        $index++
        $caseRoot = Join-Path $runRoot "Skins\Case$index"
        foreach ($subdir in @('Network\Connection', '@Resources', '@Resources\User', '@Resources\Modules\Network')) {
            $dir = Join-Path $caseRoot $subdir
            Assert-RunPath $dir
            $null = New-Item -ItemType Directory -Path $dir -Force
        }
        foreach ($file in @('Defaults.inc', 'Geometry.inc', 'Styles.inc', 'User\Settings.inc')) {
            Copy-Item -LiteralPath (Join-Path $resourcesRoot $file) -Destination (Join-Path $caseRoot "@Resources\$file")
        }
        $fontSource = Join-Path $resourcesRoot 'Fonts'
        if (-not (Test-Path -LiteralPath $fontSource -PathType Container)) { throw 'Bundled local font directory missing.' }
        Copy-Item -LiteralPath $fontSource -Destination (Join-Path $caseRoot '@Resources\Fonts') -Recurse
        # Explicit allowlist excludes existing tests, screenshots, and runtime data.
        foreach ($file in @('Core.lua', 'ConnectionCore.lua', 'Connection.lua', 'ConnectionMeasures.inc', 'ConnectionMeters.inc')) {
            Copy-Item -LiteralPath (Join-Path $moduleRoot $file) -Destination (Join-Path $caseRoot "@Resources\Modules\Network\$file")
        }
        $overrides = Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Network.inc') -Raw
        $values = @{ NetworkConnectionColumns=$case.Columns; NetworkInterface=$case.Selector; NetworkWiFiEnabled=$case.WiFiEnabled; NetworkWiFiInterface=$case.WiFiInterface }
        foreach ($key in $values.Keys) {
            if ($overrides -notmatch ('(?m)^' + $key + '=')) { throw "Missing shipping default: $key" }
            $overrides = [regex]::Replace($overrides, '(?m)^' + $key + '=[^\r\n]*', ($key + '=' + $values[$key]))
        }
        $scaleText = $case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture)
        # Last module values isolate the test from persisted global scale/cadence choices.
        $overrides += "`nColumnWidth=$($case.ColumnWidth)`nScale=$scaleText`nMetricsInterval=5000`n"
        if ($case.Typography -eq 'maximum') { $overrides += "TitleFontSize=12`nHeaderFontSize=10`nFontSize=10`n" }
        if ($case.Typography -eq 'default') { $overrides += "TitleFontSize=10`nHeaderFontSize=8`nFontSize=9`n" }
        if ($case.Typography -eq 'title10-body10') { $overrides += "TitleFontSize=10`nHeaderFontSize=10`nFontSize=10`n" }
        if ($case.Typography -eq 'title12-body9') { $overrides += "TitleFontSize=12`nHeaderFontSize=8`nFontSize=9`n" }
        if ($case.Surface -ne 'source') { $overrides += "BorderThickness=$($case.Surface)`nDividerThickness=$($case.Surface)`nDividerColor=110,180,210,255`n" }
        Write-TestFile (Join-Path $caseRoot '@Resources\User\Network.inc') $overrides
        $entry = Get-Content -LiteralPath (Join-Path $skinSource 'Network\Connection\Connection.ini') -Raw
        $entry += "`n[MeasureConnectionSmoke]`nMeasure=Script`nScriptFile=$PSScriptRoot\ConnectionSmoke.lua`nResultFile=$runRoot\result-$index.txt`nExpectedColumnWidth=$($case.ColumnWidth)`nExpectedScale=$scaleText`nExpectedColumns=$($case.Columns)`nCaseKind=$($case.Kind)`nTypography=$($case.Typography)`nSurface=$($case.Surface)`nGlyphCount=$($glyphs.Count)`n"
        $glyphIndex = 0
        foreach ($probe in $glyphs) {
            $glyphIndex++
            $entry += "GlyphTarget$glyphIndex=$($probe.Target)`nGlyphWidth$glyphIndex=$([int]$probe.RequireWidth)`nGlyphLive$glyphIndex=$([int]$probe.Live)`n"
        }
        $glyphIndex = 0
        foreach ($probe in $glyphs) {
            $glyphIndex++
            $probeFont = if ($probe.Target -eq 'Title') { '#TitleFontSize#' } else { '#FontSize#' }
            $probeWeight = if ($probe.Target -eq 'Title') { 600 } else { 500 }
            $entry += "`n[MeterConnectionGlyph$glyphIndex]`nMeter=String`nX=0`nY=0`nText=$($probe.Text)`nHidden=1`nClipString=0`nPadding=0,0,0,0`nFontColor=0,0,0,0`nFontFace=#FontFace#`nFontSize=($probeFont*#Scale#)`nFontWeight=$probeWeight`nStringStyle=Normal`nStringCase=None`nCharacterSpacing=0`nDynamicVariables=1`nAntiAlias=1`n"
        }
        Write-TestFile (Join-Path $caseRoot 'Network\Connection\Connection.ini') $entry
        $captureThis = $Capture -and $case.Kind -eq 'layout' -and $case.Columns -eq 1 -and (
            ($case.ColumnWidth -eq 180 -and $case.Scale -eq 0.75) -or ($case.ColumnWidth -eq 200 -and $case.Scale -eq 1))
        $alpha = if ($captureThis) { 255 } else { 0 }
        $config = "Case$index\Network\Connection"
        $settings += "`n[$config]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=$alpha`n"
        $entries.Add([pscustomobject]@{ Index=$index; Config=$config; Capture=$captureThis; Case=$case })
    }
    foreach ($subdir in @('Layouts', 'Plugins', 'Addons', 'Captures')) {
        $dir = Join-Path $runRoot $subdir
        Assert-RunPath $dir
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    $iniPath = Join-Path $runRoot 'Rainmeter.ini'
    Write-TestFile $iniPath $settings
    Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    Write-TestFile (Join-Path $runRoot 'QA-ONLY.txt') "Isolated Connection fixtures and local connection screenshots. Never distribute this directory.`n"
    if (-not (Test-Path -LiteralPath (Join-Path $runRoot 'Skins') -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $reports = @(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt')
        $testProcess.Refresh()
        if ($testProcess.HasExited) { throw 'Isolated Connection test process exited early.' }
    } while ($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) isolated Connection reports arrived." }
    $failedReports = 0
    foreach ($report in $reports) {
        $reportText = Get-Content -LiteralPath $report.FullName -Raw
        Write-Output $reportText
        if ($reportText -notmatch '^PASS ') { $failedReports++ }
    }
    $log = Join-Path $runRoot 'Rainmeter.log'
    $logErrors = @()
    if (Test-Path -LiteralPath $log) { $logErrors = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' }) }
    if ($Capture) {
        Add-Type -AssemblyName System.Drawing
        if (-not ('ParallaxConnectionCapture' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxConnectionCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width, Height; }
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
            windows.Add(new Window { Handle=hwnd, Title=title.ToString(), Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}
'@
        }
        $windows = @([ParallaxConnectionCapture]::GetOwnWindows([uint32]$testProcess.Id))
        if ($windows.Count -ne $cases.Count) { throw "Expected $($cases.Count) own Connection windows, found $($windows.Count)." }
        $captures = [Collections.Generic.List[object]]::new()
        foreach ($entry in @($entries | Where-Object Capture)) {
            $matches = @($windows | Where-Object { $_.Title -eq $entry.Config -or $_.Title -like ($entry.Config + ' *') -or $_.Title -like ('*\' + $entry.Config + '\*') })
            if ($matches.Count -ne 1) { throw "Cannot uniquely identify own window: $($entry.Config)" }
            $window = $matches[0]
            if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 4096 -or $window.Height -gt 4096) { throw 'Unexpected own window dimensions.' }
            $bitmap = [Drawing.Bitmap]::new($window.Width, $window.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $hdc = [IntPtr]::Zero
            try {
                $graphics.Clear([Drawing.Color]::Magenta)
                $hdc = $graphics.GetHdc()
                $printed = [ParallaxConnectionCapture]::PrintWindow($window.Handle, $hdc, 2)
                $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
                $colors = [Collections.Generic.HashSet[int]]::new()
                for ($x=0; $x -lt $bitmap.Width; $x+=3) { for ($y=0; $y -lt $bitmap.Height; $y+=3) { $null = $colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
                $usable = $printed -and $colors.Count -gt 16
                $captureName = 'Connection-width' + $entry.Case.ColumnWidth + '-scale' + $entry.Case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture) + '-type-' + $entry.Case.Typography + '.png'
                $pngPath = Join-Path $runRoot ('Captures\' + $captureName)
                $bitmap.Save($pngPath, [Drawing.Imaging.ImageFormat]::Png)
                $captures.Add([pscustomobject]@{ Config=$entry.Config; Width=$window.Width; Height=$window.Height; PrintWindow=$printed; SampledColors=$colors.Count; Usable=$usable; File=$pngPath })
            } finally {
                if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
                $graphics.Dispose(); $bitmap.Dispose()
            }
        }
        Write-TestFile (Join-Path $runRoot 'capture-report.json') ($captures.ToArray() | ConvertTo-Json -Depth 4)
        $captures | Format-Table Config,Width,Height,PrintWindow,SampledColors,Usable
        if (@($captures | Where-Object { -not $_.Usable }).Count) { throw 'Own-window capture blank or unsupported; do not treat it as visual QA.' }
    }
    Write-TestFile (Join-Path $runRoot 'run-report.json') ([ordered]@{
        TestedUtc=[DateTime]::UtcNow.ToString('o'); RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        Cases=$cases.Count; Failed=$failedReports; LogErrors=$logErrors; ProcessId=$testProcess.Id; Typography=$Typography; GlyphChecksPerCase=$glyphs.Count
        Distributable=$false; CaptureMethod='PrintWindow on own PID RainmeterMeterWindow handles only, offscreen'
        Limitations='Native layout and unavailable-state checks do not establish Wi-Fi signal calibration, internet reachability, transfer accuracy, mixed DPI, or long-run performance.'
    } | ConvertTo-Json -Depth 4)
    if ($logErrors.Count) { $logErrors | Write-Output; throw 'Rainmeter logged errors in isolated Connection run.' }
    if ($failedReports) { throw "$failedReports/$($cases.Count) Connection smoke checks failed." }
    Write-Output "Connection smoke: $($cases.Count) cases passed; no Rainmeter error entries. Live configuration untouched."
} finally {
    if ($testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null = $testProcess.WaitForExit(5000) }
        $testProcess.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) {
        if ($Capture -or $KeepArtifacts) {
            Write-Output "Connection QA evidence retained at $runRoot"
        } else {
            $resolved = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
            if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot) + '\', [StringComparison]::OrdinalIgnoreCase) -or
                (Split-Path -Leaf $resolved) -notmatch '^connection-run-[a-f0-9]{32}$' -or
                ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Refusing cleanup outside generated Connection QA directory.'
            }
            for ($attempt=0; $attempt -lt 10; $attempt++) {
                if (-not (Test-Path -LiteralPath $resolved)) { break }
                try { Remove-Item -LiteralPath $resolved -Recurse -Force; break } catch {
                    if ($attempt -eq 9) { throw }
                    Start-Sleep -Milliseconds 250
                }
            }
        }
    }
}
