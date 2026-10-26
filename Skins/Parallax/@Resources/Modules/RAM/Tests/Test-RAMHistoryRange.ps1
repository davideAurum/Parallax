#requires -Version 5.1
<#
Focused native check of the Auto history scale (RAMHistoryScale=1). One isolated
instance of an existing Rainmeter loads a copied RAM skin at a fast test cadence
with every provider replaced by Calc fixtures; the used-memory feed is a
triangle wave HistoryRangeNative.lua moves between narrow and wide limits.
At each checkpoint the harness asserts the range label and the proxy range, and
this script captures the window with PrintWindow and checks the DRAWN result:
the line's vertical extent against (data span / shown span) of the plot height,
the old samples re-mapped when the range widens (the Line maps stored samples at
draw time), and the label's pixels (same text, same pixels; new text, new
pixels, which an UpdateDivider=-1 meter would not show unless forced). The
harness then checks the MB and zero-decimal rewrites and the idle-resume Reset.

All writes stay in Tests/.runtime/<unique run>. No live Rainmeter configuration
is read or changed and no command-line bang is sent. This is a behaviour check,
not a performance measurement.
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(25,1000)][int]$IntervalMs = 50,
    [ValidateRange(10,600)][int]$TimeoutSeconds = 120
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('ram-range-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
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
$relatives = @('RAM\RAM.ini', '@Resources\Defaults.inc', '@Resources\Idle\Hook0.inc', '@Resources\Version.inc', '@Resources\Update\Hook1.inc', '@Resources\Update\Feed.inc', '@Resources\Update\Update.lua', '@Resources\Update\State.inc', '@Resources\Idle\Link.lua', '@Resources\User\Settings.inc', '@Resources\User\RAM.inc', '@Resources\Geometry.inc', '@Resources\Styles.inc',
    '@Resources\Modules\RAM\Measures.inc', '@Resources\Modules\RAM\Meters.inc', '@Resources\Modules\RAM\InfoMeters.inc', '@Resources\Modules\RAM\ProcessMeters.inc',
    '@Resources\Modules\RAM\Info.lua', '@Resources\Modules\RAM\InfoModel.lua', '@Resources\Modules\RAM\Display.lua', '@Resources\Modules\RAM\Process.lua',
    '@Resources\Modules\RAM\ProcessModel.lua', '@Resources\Modules\RAM\PageFile.lua', '@Resources\Modules\RAM\PageFileModel.lua',
    '@Resources\Modules\RAM\ProcessMeasures1.inc', '@Resources\Modules\RAM\HistoryScale0.inc', '@Resources\Modules\RAM\HistoryScale1.inc', '@Resources\Modules\RAM\HistoryRange.lua')
$harnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'HistoryRangeNative.lua'))
$fixtureSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PageFileFixture.lua'))
$pageToken = '0123456789abcdef0123456789abcdef'
$pageNow = 2000000000
$pageWire = "RAM_PAGE|1|$pageToken|1|$pageNow|OK|3000000000|12000000000|2"
$infoFixture = 'RAMINFO2|16000000000,26,3200,0,4D6963726F6E;16000000000,26,3200,0,4D6963726F6E'
$skinRoot = Join-Path $runRoot 'Skins'
$caseName = 'RAMRange'
$caseRoot = Join-Path $skinRoot $caseName
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$copied = @{}
foreach ($relative in $relatives) {
    $text = [IO.File]::ReadAllText((Join-Path $sourceRoot $relative))
    $copied[$relative] = $text.Replace('ParallaxRAMApply', ($caseName + 'Apply')).Replace('ParallaxRAM', $caseName)
}
$fontRoot = Join-Path $sourceRoot '@Resources\Fonts'
if (Test-Path -LiteralPath $fontRoot) {
    foreach ($font in Get-ChildItem -LiteralPath $fontRoot -File | Where-Object { $_.Extension -in '.ttf','.otf' }) {
        $destination = Join-Path $caseRoot ('@Resources\Fonts\' + $font.Name)
        Assert-RunPath $destination
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $font.FullName -Destination $destination
    }
}
$user = $copied['@Resources\User\RAM.inc']
$overrides = [ordered]@{ ColumnWidth=180; Columns=1; Scale='0.75'; MetricsInterval=$IntervalMs; RAMUseMiB=0; RAMDecimals=1; RAMPercentDecimals=0; RAMShowBar=1; RAMShowPageBar=1; RAMShowHistory=1; PanelHeight=170
    RAMHistoryScale=1; RAMHistoryMinSpan=2; FeedLow=22800000000; FeedHigh=23200000000 }
foreach ($key in $overrides.Keys) { $user = Set-IniVariable $user $key ([string]$overrides[$key]) }
$copied['@Resources\User\RAM.inc'] = $user
# Every provider is a Calc fixture. Used memory is a 20-sample triangle wave
# (the limits are variables the harness moves); only the controller, its proxy
# and the Line are real.
$measures = $copied['@Resources\Modules\RAM\Measures.inc']
$feed = "[MeasureRAMFeedTick]`nMeasure=Calc`nFormula=MeasureRAMFeedTick+1`nUpdateDivider=1`n`n[MeasureRAMUsed]`nMeasure=Calc`nFormula=(#FeedLow#+Abs((MeasureRAMFeedTick%20)-10)/10*(#FeedHigh#-#FeedLow#))`nDynamicVariables=1`nMinValue=0`nMaxValue=32000000000`nUpdateDivider=1`n`n"
$measures = Set-Section $measures 'MeasureRAMUsed' $feed
$measures = Set-Section $measures 'MeasureRAMTotal' "[MeasureRAMTotal]`nMeasure=Calc`nFormula=32000000000`nMinValue=0`nMaxValue=32000000000`nUpdateDivider=1`n`n"
$measures = Set-Section $measures 'MeasureRAMPageLauncher' "[MeasureRAMPageLauncher]`nMeasure=Calc`nFormula=0`nUpdateDivider=-1`n`n"
$fixturePath = Join-Path $caseRoot 'PageFileFixture.lua'
$measures = Set-Section $measures 'MeasureRAMPageView' "[MeasureRAMPageView]`nMeasure=Script`nScriptFile=$fixturePath`nFixtureWire=$pageWire`nFixtureToken=$pageToken`nFixtureNow=$pageNow`nUpdateDivider=1`n`n"
$measures = Set-Section $measures 'MeasureRAMInfo' "[MeasureRAMInfo]`nMeasure=Calc`nFormula=1`nSubstitute=`"1`":`"$infoFixture`"`nUpdateDivider=1`n`n"
$copied['@Resources\Modules\RAM\Measures.inc'] = $measures
$ranks = $copied['@Resources\Modules\RAM\ProcessMeasures1.inc']
$names = @('Fixture Browser','Fixture Renderer','Fixture Editor','Fixture Explorer','Fixture Service')
$bytes = @(4500000000,3000000000,1500000000,750000000,125000000)
foreach ($rank in 1..5) {
    $ranks = Set-Section $ranks "MeasureRAMProcess$rank" "[MeasureRAMProcess$rank]`nMeasure=Calc`nFormula=$($bytes[$rank-1])`nSubstitute=`"$($bytes[$rank-1])`":`"$($names[$rank-1])`"`nUpdateDivider=1`n`n"
}
$copied['@Resources\Modules\RAM\ProcessMeasures1.inc'] = $ranks
if (($measures + $ranks) -match '(?im)^(Plugin=(RunCommand|UsageMonitor)|Measure=PhysicalMemory)\s*$') { throw 'Fixture copy still contains a provider; refusing launch.' }
foreach ($relative in $relatives) { Write-RunText (Join-Path $caseRoot $relative) $copied[$relative] }
Write-RunText $fixturePath $fixtureSource
$harnessPath = Join-Path $caseRoot 'HistoryRangeNative.lua'
Write-RunText $harnessPath $harnessSource
$resultPath = Join-Path $runRoot ($caseName + '.txt')
$progressPath = Join-Path $runRoot ($caseName + '.progress')
$entry = Set-IniVariable $copied['RAM\RAM.ini'] 'OnRefreshAction' '[!CommandMeasure MeasureRAMInfoView "Complete()"]'
$entry += "`n[MeasureRAMHistoryRangeTest]`nMeasure=Script`nScriptFile=$harnessPath`nRunDir=$runRoot`nResultPath=$resultPath`nProgressPath=$progressPath`nUpdateDivider=1`n"
Write-RunText (Join-Path $caseRoot 'RAM\RAM.ini') $entry
$ini += "`n[$caseName\RAM]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
foreach ($directory in 'Layouts','Plugins','Addons','captures') { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $directory) }
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunText $iniPath $ini
Write-RunText (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-RunText (Join-Path $runRoot 'TEST-ONLY.txt') "Copied RAM history-range test skin and evidence. Never distribute this directory.`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxRangeNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxRangeNative {
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
        try { $printed = [ParallaxRangeNative]::PrintWindow($Window.Handle, $hdc, 2) } finally { $graphics.ReleaseHdc($hdc) }
        if (-not $printed) { throw 'PrintWindow failed.' }
        $bitmap.Save($PngPath, [Drawing.Imaging.ImageFormat]::Png)
        $rect = [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height)
        $data = $bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $buffer = [byte[]]::new($data.Stride * $data.Height)
            [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buffer, 0, $buffer.Length)
        } finally { $bitmap.UnlockBits($data) }
        return [pscustomobject]@{ Width=$bitmap.Width; Height=$bitmap.Height; Stride=$data.Stride; Bytes=$buffer }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
# Per interior column of the plot: the line's weighted vertical centre in
# pixels from the plot top (line colour 105,205,255 on 25,25,25 and 50,50,50).
function Get-LineCentres($Capture, [int[]]$Plot) {
    $x0, $y0, $w, $h = $Plot
    $centres = [Collections.Generic.List[object]]::new()
    for ($x = 1; $x -lt $w - 1; $x++) {
        $sum = 0.0; $moment = 0.0
        for ($y = 1; $y -lt $h - 1; $y++) {
            $i = ($y0 + $y) * $Capture.Stride + ($x0 + $x) * 4
            $weight = [Math]::Max(0.0, ([int]$Capture.Bytes[$i] - [int]$Capture.Bytes[$i + 2]) / 150.0)
            $sum += $weight; $moment += $weight * ($y + 0.5)
        }
        $centres.Add($(if ($sum -ge 0.2) { $moment / $sum } else { $null }))
    }
    return $centres
}
function Get-Region($Capture, [int[]]$Rect) {
    $x0, $y0, $w, $h = $Rect
    $region = [byte[]]::new($w * $h * 4)
    for ($y = 0; $y -lt $h; $y++) { [Array]::Copy($Capture.Bytes, ($y0 + $y) * $Capture.Stride + $x0 * 4, $region, $y * $w * 4, $w * 4) }
    return ,$region
}
function Test-Same([byte[]]$A, [byte[]]$B) { return ([Convert]::ToBase64String($A) -ceq [Convert]::ToBase64String($B)) }

$checkResults = [Collections.Generic.List[string]]::new()
function Assert-Range([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message }; $script:checkCount++ }
$checkCount = 0
$captures = @{}
$serviced = @{}
function Invoke-Checkpoint([int]$N) {
    $file = Join-Path $runRoot "cp$N.txt"
    if ($serviced.ContainsKey($N) -or -not (Test-Path -LiteralPath $file)) { return }
    Start-Sleep -Milliseconds 150
    $parts = (Get-Content -LiteralPath $file -Raw).Trim().Split('|')
    $plot = [int[]]($parts[0].Split(','))
    $tag = [int[]]($parts[1].Split(','))
    $windows = @([ParallaxRangeNative]::GetOwnWindows([uint32]$process.Id) | Where-Object { $_.Title -like ('*' + $caseName + '*') })
    if ($windows.Count -ne 1) { throw "Expected one window for $caseName; found $($windows.Count)." }
    $capture = Get-WindowPixels $windows[0] (Join-Path $runRoot "captures\RAM-range-cp$N.png")
    # The label is right-aligned at X; its box ends there.
    $labelRect = @(($tag[0] - $tag[2]), $tag[1], $tag[2], $tag[3])
    $captures[$N] = [pscustomobject]@{ Plot=$plot; Label=(Get-Region $capture $labelRect); Centres=(Get-LineCentres $capture $plot); Text=$parts[2]; Low=[double]$parts[3]; High=[double]$parts[4] }
    $serviced[$N] = $true
    Set-Content -LiteralPath (Join-Path $runRoot "ack$N") -Value 'ok'
}
function Get-Extent($Centres, [double]$FromFraction = 0, [double]$ToFraction = 1) {
    $count = $Centres.Count
    $slice = @($Centres[[int][Math]::Floor($count * $FromFraction)..([int][Math]::Ceiling($count * $ToFraction) - 1)] | Where-Object { $null -ne $_ })
    Assert-Range ($slice.Count -ge 5) 'Too few drawn columns to measure.'
    $measure = $slice | Measure-Object -Minimum -Maximum -Average
    return [pscustomobject]@{ Extent=($measure.Maximum - $measure.Minimum); Mean=$measure.Average; Columns=$slice.Count }
}

try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $launched = [DateTime]::UtcNow
    $lastActivity = [DateTime]::UtcNow
    while (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated Rainmeter exited early. Inspect $runRoot" }
        if (([DateTime]::UtcNow - $launched).TotalSeconds -ge $TimeoutSeconds) { throw "History range check exceeded $TimeoutSeconds s. Inspect $runRoot" }
        foreach ($n in 1..4) { Invoke-Checkpoint $n }
        Start-Sleep -Milliseconds 100
    }
    $report = (Get-Content -LiteralPath $resultPath -Raw).Trim()
    Write-Output $report
    if ($report -notmatch '^PASS') { throw "History range harness failed. Inspect $runRoot" }
    foreach ($n in 1..4) { Assert-Range $captures.ContainsKey($n) "Checkpoint $n was never captured." }
    $plotHeight = $captures[1].Plot[3] - 1.0
    $tolerance = 1.5
    # The wave rises over 10 samples (10 columns), so a column holds a line
    # segment of slope extent/10 and the weighted centre at each sharp apex
    # sits about half that slope inside it: centres span extent * (1 - 1/10).
    $apexFactor = 0.9
    # Drawn span: the line covers (data span / shown span) of the plot height,
    # with the shown span read from each checkpoint's own range (the range
    # follows the data with hysteresis, so it is not a fixed fit).
    # Narrow data is 0.4 GB wide, wide data 10 GB.
    foreach ($case in @(@(1, 0.4e9, 'narrow data'), @(3, 10e9, 'wide data'), @(4, 0.4e9, 'narrow data after the range shrank'))) {
        $capture = $captures[$case[0]]
        $shown = $capture.High - $capture.Low
        $expected = $case[1] / $shown * $plotHeight * $apexFactor
        $extent = (Get-Extent $capture.Centres).Extent
        Assert-Range ([Math]::Abs($extent - $expected) -le $tolerance) ("Drawn extent for {0} is {1:N2} px, expected {2:N2} +/- {3} (shown {4:N2} GB, plot {5} px)" -f $case[2], $extent, $expected, $tolerance, ($shown / 1e9), $plotHeight)
        $checkResults.Add(("cp{0} {1}: '{2}' drawn {3:N2} px, expected {4:N2}" -f $case[0], $case[2], $capture.Text, $extent, $expected))
    }
    Assert-Range (($captures[4].High - $captures[4].Low) -lt ($captures[3].High - $captures[3].Low) / 2) 'The range did not shrink back after the wide samples left.'
    # After the range widens the old narrow samples (left of the 25 new ones)
    # are re-mapped at draw time: nearly flat, at 23 GB inside the new range.
    $two = $captures[2]
    $old = Get-Extent $two.Centres 0 0.4
    $shown = $two.High - $two.Low
    $expectedMean = (1.0 - (23e9 - $two.Low) / $shown) * $plotHeight + 0.5
    Assert-Range ($old.Extent -le 2.5) ("Old samples were not re-mapped flat: extent {0:N2} px" -f $old.Extent)
    Assert-Range ([Math]::Abs($old.Mean - $expectedMean) -le $tolerance) ("Old samples re-mapped to row {0:N2}, expected {1:N2}" -f $old.Mean, $expectedMean)
    $whole = (Get-Extent $two.Centres).Extent
    $expectedWhole = 10e9 / $shown * $plotHeight * $apexFactor
    Assert-Range ([Math]::Abs($whole - $expectedWhole) -le $tolerance) ("Whole plot extent after widening is {0:N2} px, expected {1:N2}" -f $whole, $expectedWhole)
    $checkResults.Add(("cp2 widening to '{0}': old samples drawn {1:N2} px tall at row {2:N2} (expected {3:N2}); whole plot {4:N2} px (expected {5:N2})" -f $two.Text, $old.Extent, $old.Mean, $expectedMean, $whole, $expectedWhole))
    # Label pixels: the same text draws the same pixels and new text draws
    # anew (an UpdateDivider=-1 meter would keep the old pixels unless forced).
    foreach ($pair in @(@(1,2), @(1,3), @(1,4), @(2,3), @(2,4), @(3,4))) {
        $sameText = $captures[$pair[0]].Text -ceq $captures[$pair[1]].Text
        $samePixels = Test-Same $captures[$pair[0]].Label $captures[$pair[1]].Label
        Assert-Range ($sameText -eq $samePixels) ("Label pixels for cp{0} '{1}' vs cp{2} '{3}': same text {4}, same pixels {5}" -f $pair[0], $captures[$pair[0]].Text, $pair[1], $captures[$pair[1]].Text, $sameText, $samePixels)
    }
    Assert-Range (-not (Test-Same $captures[1].Label $captures[3].Label)) 'The label did not redraw when the range widened.'
    $checkResults.Add(("label pixels follow the text: " + (($captures.Keys | Sort-Object | ForEach-Object { "cp$_ '$($captures[$_].Text)'" }) -join ', ')))
    $log = Join-Path $runRoot 'Rainmeter.log'
    $problems = @(if (Test-Path -LiteralPath $log) { Select-String -LiteralPath $log -Pattern '^(ERRO|WARN)' })
    Assert-Range ($problems.Count -eq 0) ("Rainmeter.log has problems: " + (($problems | Select-Object -First 3 | ForEach-Object { $_.Line }) -join ' / '))
    $checkResults | Write-Output
    Write-Output "History range check passed ($checkCount script checks). Evidence: $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
