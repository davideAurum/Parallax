#requires -Version 5.1
<#
Focused native check of the RAM history cover's retirement once the plot is
full (RAM-05). One isolated instance of an existing Rainmeter loads a copied
RAM skin at a fast test cadence, with every provider (including physical
memory) replaced by constant Calc fixtures, so the plot fills in seconds and
draws deterministically. HistoryCoverNative.lua asserts the cover hides and
idles exactly when the plot is full, the count stops at ContentWidth, and
showing history again keeps the retired cover hidden. It then switches units
to MB, checking that only the shown unit meter keeps updating.

-CompareSkinRoot optionally names another Skins\Parallax tree (for example an
exported pre-change commit). Its RAM copy runs beside the current one with the
same fixtures and actions, and both windows are captured with PrintWindow
after the plot is full and compared pixel for pixel.

All writes stay in Tests/.runtime/<unique run>. No live Rainmeter
configuration is read or changed and no command-line bang is sent. This is a
behaviour check, not a performance measurement.
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string]$CompareSkinRoot,
    [ValidateRange(25,1000)][int]$IntervalMs = 50,
    [ValidateRange(10,600)][int]$TimeoutSeconds = 90
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('ram-cover-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'An existing Rainmeter installation is required; nothing is installed.' }

function Assert-RunPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Test destination escaped its runtime directory.' }
}
function Write-RunText([string]$Path, [string]$Content) {
    Assert-RunPath $Path
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}
function Set-IniVariable([string]$Source, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
    if ([regex]::IsMatch($Source, $pattern)) { return [regex]::Replace($Source, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) "$Key=$Value" }) }
    return $Source.TrimEnd() + "`n$Key=$Value`n"
}
function Set-Section([string]$Source, [string]$Name, [string]$Replacement) {
    $pattern = '(?ms)^\[' + [regex]::Escape($Name) + '\]\r?\n.*?(?=^\[|\z)'
    if ([regex]::Matches($Source, $pattern).Count -ne 1) { throw "Expected exactly one [$Name] section." }
    return [regex]::Replace($Source, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $Replacement })
}

$null = New-Item -ItemType Directory -Path $runRoot -Force
$relatives = @('RAM\RAM.ini', '@Resources\Defaults.inc', '@Resources\Idle\Hook0.inc','@Resources\Version.inc', '@Resources\Update\Hook1.inc', '@Resources\Update\Feed.inc', '@Resources\Update\Update.lua', '@Resources\Update\State.inc', '@Resources\Idle\Link.lua', '@Resources\User\Settings.inc', '@Resources\User\RAM.inc', '@Resources\Geometry.inc', '@Resources\Styles.inc',
    '@Resources\Modules\RAM\Measures.inc', '@Resources\Modules\RAM\Meters.inc', '@Resources\Modules\RAM\InfoMeters.inc', '@Resources\Modules\RAM\ProcessMeters.inc',
    '@Resources\Modules\RAM\Info.lua', '@Resources\Modules\RAM\InfoModel.lua', '@Resources\Modules\RAM\Display.lua', '@Resources\Modules\RAM\Process.lua',
    '@Resources\Modules\RAM\ProcessModel.lua', '@Resources\Modules\RAM\PageFile.lua', '@Resources\Modules\RAM\PageFileModel.lua')
$copies = [ordered]@{ New = $sourceRoot }
if ($CompareSkinRoot) {
    $compare = [IO.Path]::GetFullPath($CompareSkinRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $compare 'RAM\RAM.ini') -PathType Leaf)) { throw 'CompareSkinRoot must be a Skins\Parallax tree containing RAM\RAM.ini.' }
    $copies.Old = $compare
}
$harnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'HistoryCoverNative.lua'))
$fixtureSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PageFileFixture.lua'))
$pageToken = '0123456789abcdef0123456789abcdef'
$pageNow = 2000000000
$pageWire = "RAM_PAGE|1|$pageToken|1|$pageNow|OK|3000000000|12000000000|2"
$infoFixture = 'RAMINFO2|16000000000,26,3200,0,4D6963726F6E;16000000000,26,3200,0,4D6963726F6E'
$skinRoot = Join-Path $runRoot 'Skins'
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = [Collections.Generic.List[object]]::new()
foreach ($role in $copies.Keys) {
    $caseName = 'RAMCover' + $role
    $caseRoot = Join-Path $skinRoot $caseName
    $copied = @{}
    # Since 2026-10-23 the five process ranks are a load-time include; an
    # older -CompareSkinRoot tree still keeps them in Measures.inc.
    $rankFile = '@Resources\Modules\RAM\ProcessMeasures1.inc'
    $caseRelatives = @($relatives)
    # The history-scale include (2026-10-25) is absent from older compare trees.
    $scaleFile = '@Resources\Modules\RAM\HistoryScale0.inc'
    if (Test-Path -LiteralPath (Join-Path $copies[$role] $scaleFile) -PathType Leaf) { $caseRelatives += $scaleFile }
    if (Test-Path -LiteralPath (Join-Path $copies[$role] $rankFile) -PathType Leaf) { $caseRelatives += $rankFile } else { $rankFile = '@Resources\Modules\RAM\Measures.inc' }
    foreach ($relative in $caseRelatives) {
        $text = [IO.File]::ReadAllText((Join-Path $copies[$role] $relative))
        $copied[$relative] = $text.Replace('ParallaxRAMApply', ($caseName + 'Apply')).Replace('ParallaxRAM', $caseName).Replace('"Parallax\RAM\Settings"', ('"' + $caseName + '\RAM\Settings"'))
    }
    $fontRoot = Join-Path $copies[$role] '@Resources\Fonts'
    if (Test-Path -LiteralPath $fontRoot) {
        foreach ($font in Get-ChildItem -LiteralPath $fontRoot -File | Where-Object { $_.Extension -in '.ttf','.otf' }) {
            $destination = Join-Path $caseRoot ('@Resources\Fonts\' + $font.Name)
            Assert-RunPath $destination
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
            Copy-Item -LiteralPath $font.FullName -Destination $destination
        }
    }
    $user = $copied['@Resources\User\RAM.inc']
    $overrides = [ordered]@{ ColumnWidth=180; Columns=1; Scale='0.75'; MetricsInterval=$IntervalMs; RAMUseMiB=0; RAMDecimals=1; RAMPercentDecimals=0; RAMShowBar=1; RAMShowPageBar=1; RAMShowHistory=1; PanelHeight=170 }
    foreach ($key in $overrides.Keys) { $user = Set-IniVariable $user $key ([string]$overrides[$key]) }
    $copied['@Resources\User\RAM.inc'] = $user
    # Every provider becomes a constant Calc: no helper, worker or live memory
    # reading, so both copies draw the same flat history.
    $measures = $copied['@Resources\Modules\RAM\Measures.inc']
    $measures = Set-Section $measures 'MeasureRAMUsed' "[MeasureRAMUsed]`nMeasure=Calc`nFormula=12000000000`nMinValue=0`nMaxValue=32000000000`nUpdateDivider=1`n`n"
    $measures = Set-Section $measures 'MeasureRAMTotal' "[MeasureRAMTotal]`nMeasure=Calc`nFormula=32000000000`nMinValue=0`nMaxValue=32000000000`nUpdateDivider=1`n`n"
    foreach ($helper in @('Launcher')) { $measures = Set-Section $measures "MeasureRAMPage$helper" "[MeasureRAMPage$helper]`nMeasure=Calc`nFormula=0`nUpdateDivider=-1`n`n" }
    $fixturePath = Join-Path $caseRoot 'PageFileFixture.lua'
    $measures = Set-Section $measures 'MeasureRAMPageView' "[MeasureRAMPageView]`nMeasure=Script`nScriptFile=$fixturePath`nFixtureWire=$pageWire`nFixtureToken=$pageToken`nFixtureNow=$pageNow`nUpdateDivider=1`n`n"
    $measures = Set-Section $measures 'MeasureRAMInfo' "[MeasureRAMInfo]`nMeasure=Calc`nFormula=1`nSubstitute=`"1`":`"$infoFixture`"`nUpdateDivider=1`n`n"
    $names = @('Fixture Browser','Fixture Renderer','Fixture Editor','Fixture Explorer','Fixture Service')
    $bytes = @(4500000000,3000000000,1500000000,750000000,125000000)
    $copied['@Resources\Modules\RAM\Measures.inc'] = $measures
    $ranks = $copied[$rankFile]
    foreach ($rank in 1..5) {
        $ranks = Set-Section $ranks "MeasureRAMProcess$rank" "[MeasureRAMProcess$rank]`nMeasure=Calc`nFormula=$($bytes[$rank-1])`nSubstitute=`"$($bytes[$rank-1])`":`"$($names[$rank-1])`"`nUpdateDivider=1`n`n"
    }
    $copied[$rankFile] = $ranks
    if (($copied['@Resources\Modules\RAM\Measures.inc'] + $ranks) -match '(?im)^(Plugin=(RunCommand|UsageMonitor)|Measure=PhysicalMemory)\s*$') { throw 'Fixture copy still contains a provider; refusing launch.' }
    foreach ($relative in $caseRelatives) { Write-RunText (Join-Path $caseRoot $relative) $copied[$relative] }
    Write-RunText $fixturePath $fixtureSource
    $harnessPath = Join-Path $caseRoot 'HistoryCoverNative.lua'
    Write-RunText $harnessPath $harnessSource
    $resultPath = Join-Path $runRoot ($caseName + '.txt')
    $progressPath = Join-Path $runRoot ($caseName + '.progress')
    $entry = Set-IniVariable $copied['RAM\RAM.ini'] 'OnRefreshAction' '[!CommandMeasure MeasureRAMInfoView "Complete()"]'
    $entry += "`n[MeasureRAMHistoryCoverTest]`nMeasure=Script`nScriptFile=$harnessPath`nRole=$role`nResultPath=$resultPath`nProgressPath=$progressPath`nUpdateDivider=1`n"
    Write-RunText (Join-Path $caseRoot 'RAM\RAM.ini') $entry
    $ini += "`n[$caseName\RAM]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $cases.Add([pscustomobject]@{ Role=$role; Case=$caseName; Result=$resultPath; Progress=$progressPath })
}
foreach ($directory in 'Layouts','Plugins','Addons','captures') { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $directory) }
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunText $iniPath $ini
Write-RunText (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-RunText (Join-Path $runRoot 'TEST-ONLY.txt') "Copied RAM history-cover test skins and evidence. Never distribute this directory.`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxCoverNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxCoverNative {
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
function Get-WindowPixels($Window, [string]$PngPath) {
    $bitmap = [Drawing.Bitmap]::new($Window.Width, $Window.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        try { $printed = [ParallaxCoverNative]::PrintWindow($Window.Handle, $hdc, 2) } finally { $graphics.ReleaseHdc($hdc) }
        if (-not $printed) { throw 'PrintWindow failed.' }
        $bitmap.Save($PngPath, [Drawing.Imaging.ImageFormat]::Png)
        $rect = [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height)
        $data = $bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $buffer = [byte[]]::new($data.Stride * $data.Height)
            [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buffer, 0, $buffer.Length)
        } finally { $bitmap.UnlockBits($data) }
        return [pscustomobject]@{ Width=$bitmap.Width; Height=$bitmap.Height; Bytes=$buffer }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $launched = [DateTime]::UtcNow
    while (@($cases | Where-Object { -not (Test-Path -LiteralPath $_.Result -PathType Leaf) }).Count) {
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated Rainmeter exited early. Inspect $runRoot" }
        if (([DateTime]::UtcNow - $launched).TotalSeconds -ge $TimeoutSeconds) { throw "History cover check exceeded $TimeoutSeconds s. Inspect $runRoot" }
        Start-Sleep -Milliseconds 200
    }
    $reports = @($cases | ForEach-Object { (Get-Content -LiteralPath $_.Result -Raw).Trim() })
    $reports | Write-Output
    $comparison = $null
    if ($copies.Contains('Old')) {
        # Both plots are full and flat; capture twice and keep the pair with
        # the fewest differences (each copy ticks on its own timer).
        $windows = @([ParallaxCoverNative]::GetOwnWindows([uint32]$process.Id))
        $byRole = @{}
        foreach ($case in $cases) {
            $match = @($windows | Where-Object { $_.Title -like ('*' + $case.Case + '*') })
            if ($match.Count -ne 1) { throw "Expected one window for $($case.Case); found $($match.Count)." }
            $byRole[$case.Role] = $match[0]
        }
        $best = $null
        foreach ($attempt in 1..2) {
            $new = Get-WindowPixels $byRole.New (Join-Path $runRoot "captures\RAM-cover-new-$attempt.png")
            $old = Get-WindowPixels $byRole.Old (Join-Path $runRoot "captures\RAM-cover-old-$attempt.png")
            if ($new.Width -ne $old.Width -or $new.Height -ne $old.Height) { throw "Window sizes differ: new $($new.Width)x$($new.Height), old $($old.Width)x$($old.Height)." }
            $different = 0; $maxDelta = 0
            for ($i = 0; $i -lt $new.Bytes.Length; $i += 4) {
                $delta = 0
                for ($c = 0; $c -lt 4; $c++) { $delta = [math]::Max($delta, [math]::Abs([int]$new.Bytes[$i+$c] - [int]$old.Bytes[$i+$c])) }
                if ($delta -gt 0) { $different++; if ($delta -gt $maxDelta) { $maxDelta = $delta } }
            }
            $result = [ordered]@{ Attempt=$attempt; Width=$new.Width; Height=$new.Height; Pixels=$new.Width*$new.Height; DifferentPixels=$different; MaxChannelDelta=$maxDelta }
            if ($null -eq $best -or $different -lt $best.DifferentPixels) { $best = $result }
            Start-Sleep -Milliseconds 300
        }
        $comparison = $best
        Write-Output ("Pixel comparison (current vs compare copy, full plot): {0}x{1}, {2} of {3} pixels differ, max channel delta {4}." -f $best.Width, $best.Height, $best.DifferentPixels, $best.Pixels, $best.MaxChannelDelta)
    }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $errors = @()
    if (Test-Path -LiteralPath $logPath) { $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }
    $summary = [ordered]@{ CompletedUtc=[DateTime]::UtcNow.ToString('o'); RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        IntervalMs=$IntervalMs; Reports=$reports; Comparison=$comparison; LogErrors=$errors; Distributable=$false }
    Write-RunText (Join-Path $runRoot 'summary.json') ($summary | ConvertTo-Json -Depth 4)
    if ($errors.Count) { $errors | Write-Output; throw "Rainmeter logged errors. Inspect $runRoot" }
    if (@($reports | Where-Object { $_ -notmatch '^PASS' }).Count) { throw "History cover check failed. Inspect $runRoot" }
    if ($null -ne $comparison -and $comparison.DifferentPixels -ne 0) { throw "Current and compare windows differ by $($comparison.DifferentPixels) pixels. Inspect $runRoot\captures" }
    Write-Output "History cover check passed. Evidence: $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
