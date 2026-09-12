[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet(180, 200, 240, 280, 320)][int[]]$ColumnWidths = @(180, 200, 240, 280, 320),
    [switch]$MaxTypography,
    [switch]$Capture,
    [ValidateRange(10, 60)][int]$TimeoutSeconds = 40
)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$runRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('run-' + [guid]::NewGuid().ToString('N'))))
$testProcess = $null
function Assert-RunPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes isolated run: $absolute"
    }
}
function Write-TestFile([string]$Path, [string]$Text) {
    Assert-RunPath $Path
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'An existing Rainmeter installation is required; nothing is installed by this test.' }
try {
    $settings = "[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $typographyLabel = if ($MaxTypography) { 'maximum' } else { 'default' }
    $entries = [Collections.Generic.List[object]]::new()
    $cases = @()
    foreach ($width in $ColumnWidths) { foreach ($scale in @(0.75, 1, 1.25, 1.5, 2)) { foreach ($columns in @(1, 2)) {
        $cases += [pscustomobject]@{ ColumnWidth = $width; Scale = $scale; Columns = $columns; Selector = 'Best' }
    } } }
    $cases += [pscustomobject]@{ ColumnWidth = 180; Scale = 0.75; Columns = 1; Selector = 'Parallax-intentionally-missing-NIC' }
    $cases += [pscustomobject]@{ ColumnWidth = 200; Scale = 1; Columns = 2; Selector = '0' }
    # Independent font controls can have different maxima; check their mixed extremes.
    foreach ($thickness in @(0, 4)) {
        $cases += [pscustomobject]@{ ColumnWidth=180; Scale=0.75; Columns=1; Selector='Best'; Title=10; Header=10; Body=10; Thickness=$thickness }
        $cases += [pscustomobject]@{ ColumnWidth=200; Scale=2; Columns=2; Selector='Best'; Title=12; Header=8; Body=9; Thickness=$thickness }
    }
    $index = 0
    foreach ($case in $cases) {
        $index++
        $caseRoot = Join-Path $runRoot "Skins\Case$index"
        foreach ($subdir in @('Network', '@Resources', '@Resources\User', '@Resources\Modules\Network')) {
            $dir = Join-Path $caseRoot $subdir
            Assert-RunPath $dir
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        foreach ($file in @('Defaults.inc', 'Geometry.inc', 'Styles.inc', 'User\Settings.inc')) {
            Copy-Item -LiteralPath (Join-Path $resourcesRoot $file) -Destination (Join-Path $caseRoot "@Resources\$file")
        }
        $fontSource = Join-Path $resourcesRoot 'Fonts'
        $fontDestination = Join-Path $caseRoot '@Resources\Fonts'
        Assert-RunPath $fontDestination
        if (-not (Test-Path -LiteralPath $fontSource -PathType Container)) { throw 'Bundled local font directory is missing.' }
        Copy-Item -LiteralPath $fontSource -Destination $fontDestination -Recurse
        foreach ($file in @('Core.lua', 'Network.lua', 'Measures.inc', 'Meters.inc')) {
            Copy-Item -LiteralPath (Join-Path $moduleRoot $file) -Destination (Join-Path $caseRoot "@Resources\Modules\Network\$file")
        }
        $overrides = Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Network.inc') -Raw
        $overrides = $overrides -replace '(?m)^Columns=.*$', ('Columns=' + $case.Columns)
        $overrides = $overrides -replace '(?m)^NetworkInterface=.*$', ('NetworkInterface=' + $case.Selector)
        $scaleText = $case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture)
        # Module overrides are last so persisted global width/scale choices cannot alter this case.
        $overrides += "`nColumnWidth=$($case.ColumnWidth)`nScale=$scaleText`nMetricsInterval=5000`n"
        $typography = if ($MaxTypography) { 'TitleFontSize=12', 'HeaderFontSize=10', 'FontSize=10' } else { 'TitleFontSize=10', 'HeaderFontSize=8', 'FontSize=9' }
        if ($null -ne $case.Title) { $typography = "TitleFontSize=$($case.Title)", "HeaderFontSize=$($case.Header)", "FontSize=$($case.Body)", "BorderThickness=$($case.Thickness)", "DividerThickness=$($case.Thickness)" }
        $overrides += ($typography -join "`n") + "`n"
        Write-TestFile (Join-Path $caseRoot '@Resources\User\Network.inc') $overrides
        $entry = Get-Content -LiteralPath (Join-Path $skinSource 'Network\Network.ini') -Raw
        $entry += "`n[MeasureSmoke]`nMeasure=Script`nScriptFile=$PSScriptRoot\Smoke.lua`nResultFile=$runRoot\result-$index.txt`nExpectedColumnWidth=$($case.ColumnWidth)`nExpectedScale=$scaleText`nExpectedColumns=$($case.Columns)`n"
        # Intrinsic text probes belong only to this invisible fixture, never the shipped skin.
        # Smoke.lua copies each target's actual font options before measuring native dimensions.
        foreach ($probe in @(
            @{ Name = 'Width1'; Text = '1x' }, @{ Name = 'Width2'; Text = '2x' },
            @{ Name = 'UnitsBytes'; Text = 'bytes' }, @{ Name = 'TitleNetwork'; Text = 'Network' },
            @{ Name = 'HeaderIn'; Text = 'IN' }, @{ Name = 'HeaderOut'; Text = 'OUT' },
            @{ Name = 'BodyAdapter'; Text = 'Ethernet' }, @{ Name = 'BodyStatus'; Text = 'Selected NIC not found' },
            @{ Name = 'BodyRate'; Text = '1023.9 Gbit/s' }, @{ Name = 'BodyCeiling'; Text = 'Set positive graph ceiling' },
            @{ Name = 'BodyFooter'; Text = '60/60 samples / incl. LAN' }
        )) {
            $entry += "`n[MeterGlyph$($probe.Name)]`nMeter=String`nX=0`nY=0`nText=$($probe.Text)`nHidden=1`nClipString=0`nPadding=0,0,0,0`nFontColor=0,0,0,0`nDynamicVariables=1`nAntiAlias=1`n"
        }
        Write-TestFile (Join-Path $caseRoot 'Network\Network.ini') $entry
        # Only ordinary Best-layout fixtures are photographed; mixed/error cases retain their probes.
        $captureThis = $Capture -and $case.Selector -eq 'Best' -and $null -eq $case.Title -and $case.Columns -eq 1 -and (
            ($case.ColumnWidth -eq 180 -and $case.Scale -eq 0.75) -or ($case.ColumnWidth -eq 200 -and $case.Scale -eq 1))
        $alpha = if ($captureThis) { 255 } else { 0 }
        $config = "Case$index\Network"
        $settings += "`n[$config]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=$alpha`n"
        $entries.Add([pscustomobject]@{ Index=$index; Config=$config; Capture=$captureThis; Case=$case })
    }
    foreach ($subdir in @('Layouts', 'Plugins', 'Addons')) {
        $dir = Join-Path $runRoot $subdir
        Assert-RunPath $dir
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if ($Capture) {
        $captureDirectory = Join-Path $runRoot 'Captures'
        Assert-RunPath $captureDirectory
        New-Item -ItemType Directory -Path $captureDirectory -Force | Out-Null
    }
    $iniPath = Join-Path $runRoot 'Rainmeter.ini'
    Write-TestFile $iniPath $settings
    Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    Write-TestFile (Join-Path $runRoot 'QA-ONLY.txt') "Isolated Network fixtures and local adapter screenshots. Never distribute this directory.`n"
    if (-not (Test-Path -LiteralPath (Join-Path $runRoot 'Skins') -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $reports = @(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt')
        $testProcess.Refresh()
        if ($testProcess.HasExited) { throw 'Isolated Network test process exited early.' }
    } while ($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) isolated skin reports arrived." }
    $failedReports = 0
    foreach ($report in $reports) {
        $text = Get-Content -LiteralPath $report.FullName -Raw
        Write-Output $text
        if ($text -notmatch '^PASS ') { $failedReports++ }
    }
    $log = Join-Path $runRoot 'Rainmeter.log'
    $errors = @()
    if (Test-Path -LiteralPath $log) {
        $errors = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' })
    }
    if ($Capture) {
        Add-Type -AssemblyName System.Drawing
        if (-not ('ParallaxNetworkCapture' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxNetworkCapture {
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
        $windows = @([ParallaxNetworkCapture]::GetOwnWindows([uint32]$testProcess.Id))
        if ($windows.Count -ne $cases.Count) { throw "Expected $($cases.Count) own Network windows, found $($windows.Count)." }
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
                $printed = [ParallaxNetworkCapture]::PrintWindow($window.Handle, $hdc, 2)
                $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
                $colors = [Collections.Generic.HashSet[int]]::new()
                for ($x=0; $x -lt $bitmap.Width; $x+=3) { for ($y=0; $y -lt $bitmap.Height; $y+=3) { $null = $colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
                $usable = $printed -and $colors.Count -gt 16
                $captureName = 'Network-width' + $entry.Case.ColumnWidth + '-scale' + $entry.Case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture) + '-type-' + $typographyLabel + '.png'
                $pngPath = Join-Path $captureDirectory $captureName
                Assert-RunPath $pngPath
                $bitmap.Save($pngPath, [Drawing.Imaging.ImageFormat]::Png)
                $captures.Add([pscustomobject]@{ Config=$entry.Config; Width=$window.Width; Height=$window.Height; PrintWindow=$printed; SampledColors=$colors.Count; Usable=$usable; File=$pngPath })
            } finally {
                if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
                $graphics.Dispose(); $bitmap.Dispose()
            }
        }
        Write-TestFile (Join-Path $runRoot 'capture-report.json') (ConvertTo-Json -InputObject $captures.ToArray() -Depth 4)
        $captures | Format-Table Config,Width,Height,PrintWindow,SampledColors,Usable
        if (@($captures | Where-Object { -not $_.Usable }).Count) { throw 'Own-window capture blank or unsupported; do not treat it as visual QA.' }
        if ($captures.Count -eq 0) { Write-Output 'No capture targets in the selected column widths; choose 180 and/or 200 for native images.' }
    }
    Write-TestFile (Join-Path $runRoot 'run-report.json') ([ordered]@{
        TestedUtc=[DateTime]::UtcNow.ToString('o'); RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        Cases=$cases.Count; Failed=$failedReports; LogErrors=$errors; ProcessId=$testProcess.Id; Typography=$typographyLabel; GlyphChecksPerCase=11
        Distributable=$false; CaptureRequested=[bool]$Capture; CaptureMethod='PrintWindow on own PID RainmeterMeterWindow handles only, offscreen'
        Limitations='Native layout and unavailable-state checks do not establish traffic accuracy, Internet reachability, mixed DPI, or long-run performance.'
    } | ConvertTo-Json -Depth 4)
    if ($errors.Count) { $errors | Write-Output; throw 'Rainmeter logged errors in isolated smoke run.' }
    if ($failedReports) { throw "$failedReports/$($cases.Count) full-skin smoke checks failed." }
    Write-Output "Full-skin smoke: $($cases.Count) cases passed; no Rainmeter error log entries. Traffic accuracy is not asserted."
} finally {
    if ($testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $testProcess.WaitForExit(5000) | Out-Null }
        $testProcess.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) {
        $resolved = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        $expectedParent = [IO.Path]::GetFullPath($PSScriptRoot) + '\'
        if (-not $resolved.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolved) -notmatch '^run-[a-f0-9]{32}$' -or
            ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing cleanup outside the generated QA run directory.'
        }
        if ($Capture) {
            Write-Output "Private Network QA evidence retained at $resolved"
        } else {
            # DirectWrite may release a bundled font handle shortly after Rainmeter exits.
            # Retry only this already validated generated tree; do not touch font caches or other processes.
            for ($cleanupAttempt = 0; $cleanupAttempt -lt 10; $cleanupAttempt++) {
                if (-not (Test-Path -LiteralPath $resolved)) { break }
                try {
                    Remove-Item -LiteralPath $resolved -Recurse -Force
                    break
                } catch {
                    if ($cleanupAttempt -eq 9) { throw }
                    Start-Sleep -Milliseconds 250
                }
            }
        }
    }
}
