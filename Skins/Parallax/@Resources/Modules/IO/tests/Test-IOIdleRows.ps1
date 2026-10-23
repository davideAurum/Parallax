#requires -Version 5.1
<#
Focused native check of Disk Meter's idle hidden drive rows (IO-01) and its
change-driven controller (IO-05). One isolated instance of an existing
Rainmeter loads a copied Disk Meter at a fast 100 ms test cadence with every
provider (drive types, labels, capacities, UsageMonitor rates and the model
query) replaced by constant Calc fixtures. IdleRowsNative.lua walks the
selection through none, C, all, an All-mode removal and return of D, and back
to C,D,G, asserting that shown rows update every tick and hidden rows idle.

-CompareSkinRoot optionally names another Skins\Parallax tree (for example an
exported pre-change commit). Its Disk Meter copy runs beside the current one
with the same fixtures and steps. In every phase, once selection, inventory
and the history graph have settled, both windows are captured with
PrintWindow and compared pixel for pixel, so a stale idle meter shows up as a
drawn difference.

All writes stay in tests/.runtime/<unique run>. No live Rainmeter
configuration is read or changed and no command-line bang is sent. This is a
behaviour check, not a performance measurement.
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string]$CompareSkinRoot,
    [ValidateRange(60,600)][int]$TimeoutSeconds = 240
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('io-idle-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
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
# Constant fixtures. Absent letters report type 1; present: C, D, G fixed, E removable.
$types = @{ C=4; D=4; E=3; G=4 }
$totals = @{ C=500e9; D=2e12; E=64e9; G=128e9 }
$frees = @{ C=180e9; D=1.2e12; E=60e9; G=10e9 }
$reads = @{ C=1.5e6; D=0.2e6; G=12e6 }
$writes = @{ C=0.4e6; D=3.1e6; G=0.05e6 }
function Get-Fixture([string]$Name) {
    if ($Name -match '^MeasureIOType([A-Z])$') { $l = $Matches[1]; return @{ Formula = $(if ($types.ContainsKey($l)) { $types[$l] } else { 1 }) } }
    if ($Name -match '^MeasureIOName([A-Z])$') { return @{ Formula = 1; Substitute = ('"1":"Fixture ' + $Matches[1] + '"') } }
    if ($Name -match '^MeasureIOTotal([A-Z])$') { $l = $Matches[1]; return @{ Formula = $(if ($totals.ContainsKey($l)) { $totals[$l] } else { 0 }) } }
    if ($Name -match '^MeasureIOFree([A-Z])$') { $l = $Matches[1]; return @{ Formula = $(if ($frees.ContainsKey($l)) { $frees[$l] } else { 0 }) } }
    if ($Name -match '^MeasureIODiskRead([A-Z])$') { $l = $Matches[1]; return @{ Formula = $(if ($reads.ContainsKey($l)) { $reads[$l] } else { 0 }) } }
    if ($Name -match '^MeasureIODiskWrite([A-Z])$') { $l = $Matches[1]; return @{ Formula = $(if ($writes.ContainsKey($l)) { $writes[$l] } else { 0 }) } }
    if ($Name -eq 'MeasureIOModelQuery') { return @{ Formula = 0 } }
    throw "No fixture for provider $Name"
}
function Convert-Providers([string]$Source) {
    # Replace every provider section with a constant Calc, keeping its group,
    # enablement, cadence and range so bank switching and phases are unchanged.
    return [regex]::Replace($Source, '(?ms)^\[([^\]\r\n]+)\]\r?\n(.*?)(?=^\[|\z)', [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $name = $m.Groups[1].Value; $body = $m.Groups[2].Value
        if ($body -notmatch '(?m)^(Measure=FreeDiskSpace|Plugin=UsageMonitor|Plugin=RunCommand)\s*$') { return $m.Value }
        $fixture = Get-Fixture $name
        $lines = @("[$name]", 'Measure=Calc', ('Formula=' + ([double]$fixture.Formula).ToString('R', [Globalization.CultureInfo]::InvariantCulture)))
        if ($fixture.ContainsKey('Substitute')) { $lines += 'Substitute=' + $fixture.Substitute }
        foreach ($key in 'Group','Disabled','UpdateDivider','MinValue','MaxValue') {
            $kept = [regex]::Match($body, '(?m)^' + $key + '=([^\r\n]*)')
            if ($kept.Success) { $lines += $key + '=' + $kept.Groups[1].Value }
        }
        return ($lines -join "`n") + "`n`n"
    })
}

$null = New-Item -ItemType Directory -Path $runRoot -Force
$relatives = @('IO\IO-Disk.ini', '@Resources\Defaults.inc', '@Resources\User\Settings.inc', '@Resources\User\IO.inc', '@Resources\Geometry.inc', '@Resources\Styles.inc',
    '@Resources\Modules\IO\Inventory.inc', '@Resources\Modules\IO\Native.inc', '@Resources\Modules\IO\Disk.inc', '@Resources\Modules\IO\Model.inc',
    '@Resources\Modules\IO\View.inc', '@Resources\Modules\IO\DriveMeters.inc', '@Resources\Modules\IO\IO.lua', '@Resources\Modules\IO\Names.lua')
$copies = [ordered]@{ New = $sourceRoot }
if ($CompareSkinRoot) {
    $compare = [IO.Path]::GetFullPath($CompareSkinRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $compare 'IO\IO-Disk.ini') -PathType Leaf)) { throw 'CompareSkinRoot must be a Skins\Parallax tree containing IO\IO-Disk.ini.' }
    $copies.Old = $compare
}
$harnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'IdleRowsNative.lua'))
$skinRoot = Join-Path $runRoot 'Skins'
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = [Collections.Generic.List[object]]::new()
foreach ($role in $copies.Keys) {
    $caseName = 'IOIdle' + $role
    $caseRoot = Join-Path $skinRoot $caseName
    $copied = @{}
    foreach ($relative in $relatives) {
        $copied[$relative] = [IO.File]::ReadAllText((Join-Path $copies[$role] $relative)).Replace('ParallaxIO', $caseName).Replace('"Parallax\IO\Settings"', ('"' + $caseName + '\IO\Settings"'))
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
    $user = $copied['@Resources\User\IO.inc']
    $overrides = [ordered]@{ ColumnWidth=180; Columns=1; Scale='0.75'; PanelHeight=157; CapacityInterval=30000; IODiskDrives='C,D,G'; IOGraphMode='overlay'; IODriveNames='volume'; IODiskUnits='bytes'; IODiskMaxMiBs=500 }
    foreach ($key in $overrides.Keys) { $user = Set-IniVariable $user $key ([string]$overrides[$key]) }
    $copied['@Resources\User\IO.inc'] = $user
    foreach ($relative in '@Resources\Modules\IO\Inventory.inc','@Resources\Modules\IO\Native.inc','@Resources\Modules\IO\Disk.inc','@Resources\Modules\IO\Model.inc') {
        $copied[$relative] = Convert-Providers $copied[$relative]
        if ($copied[$relative] -match '(?im)^(Measure=FreeDiskSpace|Plugin=UsageMonitor|Plugin=RunCommand)\s*$') { throw "Fixture copy still contains a provider in $relative; refusing launch." }
    }
    foreach ($relative in $relatives) { Write-RunText (Join-Path $caseRoot $relative) $copied[$relative] }
    $harnessPath = Join-Path $caseRoot 'IdleRowsNative.lua'
    Write-RunText $harnessPath $harnessSource
    $resultPath = Join-Path $runRoot ($caseName + '.txt')
    $phasePath = Join-Path $runRoot ($caseName + '.phase')
    $entry = $copied['IO\IO-Disk.ini']
    if ($entry -notmatch '(?m)^Update=1000\r?$') { throw 'Unexpected Disk Meter cadence; refusing to rewrite it.' }
    $entry = [regex]::Replace($entry, '(?m)^Update=1000(\r?)$', 'Update=100$1')
    $entry += "`n[MeasureIOIdleRowsTest]`nMeasure=Script`nScriptFile=$harnessPath`nRole=$role`nResultPath=$resultPath`nPhasePath=$phasePath`nPhaseTicks=130`nCaptureTick=105`n"
    Write-RunText (Join-Path $caseRoot 'IO\IO-Disk.ini') $entry
    $ini += "`n[$caseName\IO]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $cases.Add([pscustomobject]@{ Role=$role; Case=$caseName; Result=$resultPath; Phase=$phasePath })
}
foreach ($directory in 'Layouts','Plugins','Addons','captures') { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $directory) }
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunText $iniPath $ini
Write-RunText (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-RunText (Join-Path $runRoot 'TEST-ONLY.txt') "Copied Disk Meter idle-row test skins and evidence. Never distribute this directory.`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxIOIdleNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxIOIdleNative {
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
        try { $printed = [ParallaxIOIdleNative]::PrintWindow($Window.Handle, $hdc, 2) } finally { $graphics.ReleaseHdc($hdc) }
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
function Compare-Pixels($A, $B) {
    if ($A.Width -ne $B.Width -or $A.Height -ne $B.Height) { return [int]::MaxValue }
    $different = 0
    for ($i = 0; $i -lt $A.Bytes.Length; $i += 4) {
        if ($A.Bytes[$i] -ne $B.Bytes[$i] -or $A.Bytes[$i+1] -ne $B.Bytes[$i+1] -or $A.Bytes[$i+2] -ne $B.Bytes[$i+2] -or $A.Bytes[$i+3] -ne $B.Bytes[$i+3]) { $different++ }
    }
    return $different
}
function Read-Phase([string]$Path) { try { return ([IO.File]::ReadAllText($Path)).Trim() } catch { return '' } }

try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $launched = [DateTime]::UtcNow
    $comparisons = [Collections.Generic.List[object]]::new()
    $captured = @{}
    $newCase = $cases | Where-Object { $_.Role -eq 'New' }
    $oldCase = $cases | Where-Object { $_.Role -eq 'Old' }
    while (@($cases | Where-Object { -not (Test-Path -LiteralPath $_.Result -PathType Leaf) }).Count) {
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated Rainmeter exited early. Inspect $runRoot" }
        if (([DateTime]::UtcNow - $launched).TotalSeconds -ge $TimeoutSeconds) { throw "Idle-row check exceeded $TimeoutSeconds s. Inspect $runRoot" }
        $state = Read-Phase $newCase.Phase
        if ($null -ne $oldCase -and $state -match '^phase=(\d+) capture$' -and -not $captured.ContainsKey($Matches[1])) {
            $phase = $Matches[1]
            # Both copies follow the same tick schedule; wait for the compare copy to settle too.
            $deadline = [DateTime]::UtcNow.AddSeconds(2)
            while ((Read-Phase $oldCase.Phase) -ne "phase=$phase capture" -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
            if ((Read-Phase $oldCase.Phase) -ne "phase=$phase capture") { throw "Compare copy did not reach phase $phase in step." }
            $windows = @([ParallaxIOIdleNative]::GetOwnWindows([uint32]$process.Id))
            $new = @($windows | Where-Object { $_.Title -like ('*' + $newCase.Case + '*') })
            $old = @($windows | Where-Object { $_.Title -like ('*' + $oldCase.Case + '*') })
            if ($new.Count -ne 1 -or $old.Count -ne 1) { throw 'Expected one window per copy.' }
            $best = [int]::MaxValue
            foreach ($attempt in 1..3) {
                $a = Get-WindowPixels $new[0] (Join-Path $runRoot "captures\IO-phase$phase-new-$attempt.png")
                $b = Get-WindowPixels $old[0] (Join-Path $runRoot "captures\IO-phase$phase-old-$attempt.png")
                $best = [math]::Min($best, (Compare-Pixels $a $b))
                if ($best -eq 0) { break }
                Start-Sleep -Milliseconds 150
            }
            $captured[$phase] = $true
            $comparisons.Add([pscustomobject]@{ Phase=[int]$phase; Width=$a.Width; Height=$a.Height; NewHeight=$a.Height; OldHeight=$b.Height; DifferentPixels=$best })
            Write-Output ("Phase {0}: {1}x{2} new vs {3}x{4} compare, {5} pixels differ." -f $phase, $a.Width, $a.Height, $b.Width, $b.Height, $(if ($best -eq [int]::MaxValue) { 'size differs;' } else { $best }))
        }
        Start-Sleep -Milliseconds 100
    }
    $reports = @($cases | ForEach-Object { (Get-Content -LiteralPath $_.Result -Raw).Trim() })
    $reports | Write-Output
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $errors = @()
    if (Test-Path -LiteralPath $logPath) { $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }
    $summary = [ordered]@{ CompletedUtc=[DateTime]::UtcNow.ToString('o'); RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        Reports=$reports; Comparisons=$comparisons.ToArray(); LogErrors=$errors; Distributable=$false }
    Write-RunText (Join-Path $runRoot 'summary.json') ($summary | ConvertTo-Json -Depth 4)
    if ($errors.Count) { $errors | Write-Output; throw "Rainmeter logged errors. Inspect $runRoot" }
    if (@($reports | Where-Object { $_ -notmatch '^PASS' }).Count) { throw "Idle-row check failed. Inspect $runRoot" }
    if ($null -ne $oldCase) {
        if ($comparisons.Count -ne 7) { throw "Expected 7 phase comparisons, captured $($comparisons.Count)." }
        if (@($comparisons | Where-Object { $_.DifferentPixels -ne 0 }).Count) { throw "Current and compare windows differ. Inspect $runRoot\captures" }
    }
    Write-Output "Idle-row check passed. Evidence: $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
