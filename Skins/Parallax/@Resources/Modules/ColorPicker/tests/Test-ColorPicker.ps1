#requires -Version 5.1
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$sourceRoot = Join-Path $projectRoot 'Skins\Parallax'
$runRoot = Join-Path $projectRoot ('build\color-picker-test-' + [Guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test downloads and installs nothing.' }
foreach ($parent in @($projectRoot, (Join-Path $projectRoot 'build'))) {
    if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test parent must not be a junction.' }
}
$null = New-Item -ItemType Directory -Path $runRoot

function Write-Isolated([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside isolated color-picker test.' }
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
                # Lua may still hold the newly-created report open for its single write.
                try { $text = [IO.File]::ReadAllText($Path) } catch [IO.IOException] { $text = '' }
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
if (-not ('ParallaxColorPickerNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxColorPickerNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public int Width, Height, Left, Top; }
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
            RECT rect; if (GetWindowRect(hwnd, out rect)) result.Add(new Window { Handle=hwnd, Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top, Left=rect.Left, Top=rect.Top });
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
function Capture-OwnWindow([Diagnostics.Process]$Process, [string]$Path, [int]$Width, [int]$Height) {
    $windows = @([ParallaxColorPickerNative]::OwnWindows([uint32]$Process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 })
    if ($windows.Count -ne 1) { throw "Expected one isolated window, found $($windows.Count)." }
    $window = $windows[0]
    if ($window.Width -ne $Width -or $window.Height -ne $Height) { throw "Native window unexpectedly resized: $($window.Width)x$($window.Height)." }
    $bitmap = [Drawing.Bitmap]::new($Width,$Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxColorPickerNative]::PrintWindow($window.Handle,$hdc,2)
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

$sourcePicker=Get-Content -LiteralPath "$sourceRoot\ColorPicker\ColorPicker.ini" -Raw
if ($sourcePicker -notmatch '(?m)^Update=-1\r?$') { throw 'Production picker must be event-driven.' }
$records=[Collections.Generic.List[object]]::new()
foreach ($case in @(@{Name='default';Scale='1';ColumnWidth='200';Rounding='3';Background='15,15,15,128';Width=288;Height=270;Finish='apply'},@{Name='narrow';Scale='0.75';ColumnWidth='180';Rounding='24';Background='0,0,0,0';Width=216;Height=203;Finish='cancel'})) {
    $caseRoot=Join-Path $runRoot $case.Name
    $skinRoot=Join-Path $caseRoot 'Skins'
    $parallaxRoot=Join-Path $skinRoot 'Parallax'
    $process=$null
    foreach ($relative in @('','Skins','Skins\Parallax','Skins\Parallax\ColorPicker','Skins\Parallax\TestLauncher','Skins\Parallax\@Resources','Skins\Parallax\@Resources\User','Skins\Parallax\@Resources\Modules','Layouts','Plugins','Addons','captures')) {
        $null=New-Item -ItemType Directory -Path (Join-Path $caseRoot $relative)
    }
    foreach ($file in @('Defaults.inc','Geometry.inc','Styles.inc','User\Settings.inc')) {
        Copy-Item -LiteralPath (Join-Path "$sourceRoot\@Resources" $file) -Destination (Join-Path "$parallaxRoot\@Resources" $file)
    }
    Copy-Item -LiteralPath "$sourceRoot\@Resources\Fonts" -Destination "$parallaxRoot\@Resources\Fonts" -Recurse
    Copy-Item -LiteralPath "$sourceRoot\@Resources\Modules\ColorPicker" -Destination "$parallaxRoot\@Resources\Modules\ColorPicker" -Recurse
    $userPath=Join-Path $parallaxRoot '@Resources\User\Settings.inc'
    $user=Get-Content -LiteralPath $userPath -Raw
    $sentinels=@{Scale=$case.Scale;ColumnWidth=$case.ColumnWidth;Gutter='8';CornerRadius=$case.Rounding;AccentColor='12,34,56';AccentColor2='181,161,226';TitleTextColor='0,0,0';HeaderTextColor='10,12,15';TextColor='0,0,0';BackgroundColor=$case.Background;BorderColor='0,0,0,255';DividerColor='50,50,50,255';TableHeaderBorderColor='70,80,90,128';BorderThickness='3';DividerThickness='1';TableHeaderBorderThickness='2';MetricsInterval='2000';SensorInterval='4000';CapacityInterval='60000';VisualizerInterval='100';CustomPickerSentinel='preserve-me'}
    foreach ($key in $sentinels.Keys) { $user=Set-IniValue $user $key $sentinels[$key] }
    Write-Isolated $userPath $user
    $before=Read-Variables $userPath
    $overridePath=Join-Path $parallaxRoot '@Resources\User\CPU.inc'
    $override="[Variables]`nCPUColor=111,22,33`nScale=1.25`nColumns=2`n"
    Write-Isolated $overridePath $override
    $ramPath=Join-Path $parallaxRoot '@Resources\User\RAM.inc'
    Write-Isolated $ramPath "[Variables]`nRAMShowBar=1`nRAMHistoryEmptyColor=25,25,25`n"
    $picker=[regex]::Replace($sourcePicker,'(?m)^Update=-1\r?$','Update=100')
    $picker+="`n[MeasureColorPickerHarness]`nMeasure=Script`nScriptFile=#@#Modules\ColorPicker\tests\NativeHarness.lua`nReportDirectory=$caseRoot\`nExpectedWidth=$($case.Width)`nExpectedHeight=$($case.Height)`n"
    Write-Isolated (Join-Path $parallaxRoot 'ColorPicker\ColorPicker.ini') $picker
    Write-Isolated (Join-Path $parallaxRoot 'TestLauncher\Launcher.ini') "[Rainmeter]`nUpdate=100`n`n[Variables]`n@Include=#@#Defaults.inc`n@Include2=#@#User\Settings.inc`n`n[MeasureLauncher]`nMeasure=Script`nScriptFile=#@#Modules\ColorPicker\tests\LauncherHarness.lua`nReportDirectory=$caseRoot\`n`n[MeasureColorLauncher]`nMeasure=Script`nScriptFile=#@#Modules\ColorPicker\Launcher.lua`n`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,1`n"
    $iniPath=Join-Path $caseRoot 'Rainmeter.ini'
    Write-Isolated $iniPath "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[Parallax\ColorPicker]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n`n[Parallax\TestLauncher]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    Write-Isolated (Join-Path $caseRoot 'Rainmeter.data') "[Rainmeter]`n"
    $sequence=0
    try {
        $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $caseRoot -WindowStyle Hidden -PassThru
        $ready=Await-Report (Join-Path $caseRoot 'ready.txt') 12000
        if ($ready -notmatch 'Hex=#0C2238') { throw 'Picker did not seed from the global AccentColor.' }
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\hsv-initial.png') $case.Width $case.Height))
        foreach ($action in @('rgb','plane','slice','plus','minus','lab','slice','corner','hsv','plane','slice')) {
            $sequence++
            Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|$action"
            $result=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
            if ([IO.File]::ReadAllText($userPath) -ne $user) { throw 'Preview action persisted a change before Apply.' }
            if ($sequence -eq 5) { $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\rgb.png') $case.Width $case.Height)) }
            if ($action -eq 'corner') {
                if ($result -notmatch 'Outside sRGB') { throw 'Out-of-gamut Lab preview lacks clipping warning.' }
                $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\lab-clipped.png') $case.Width $case.Height))
            }
        }
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\hsv-edited.png') $case.Width $case.Height))
        $sequence++
        Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|$($case.Finish)"
        $closing=Await-Report (Join-Path $caseRoot 'before-close.txt')
        # One bounded quiet period; enumerate this test PID once, with no process polling.
        Start-Sleep -Milliseconds 700
        $windows=@([ParallaxColorPickerNative]::OwnWindows([uint32]$process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 })
        if ($windows.Count -ne 0) { throw "$($case.Finish) did not close the picker." }
        if ($case.Finish -eq 'apply') {
            $hex=[regex]::Match($closing,'Hex=#([0-9A-F]{6})').Groups[1].Value
            $expected=(@([Convert]::ToInt32($hex.Substring(0,2),16),[Convert]::ToInt32($hex.Substring(2,2),16),[Convert]::ToInt32($hex.Substring(4,2),16)) -join ',')
            $after=Read-Variables $userPath
            if ($after['AccentColor'] -ne $expected -or $after['AccentColor'] -eq $before['AccentColor']) { throw 'Apply did not save the displayed accent.' }
            foreach ($key in $before.Keys) { if ($key -ne 'AccentColor' -and $before[$key] -ne $after[$key]) { throw "Apply modified unrelated $key." } }
            if ($after.Count -ne $before.Count) { throw 'Apply introduced unrelated settings keys.' }
        } elseif ([IO.File]::ReadAllText($userPath) -ne $user) { throw 'Cancel persisted preview changes.' }
        if ([IO.File]::ReadAllText($overridePath) -ne $override) { throw 'Picker modified module overrides.' }
        if ([int]([IO.File]::ReadAllText((Join-Path $caseRoot 'generations.txt'))) -gt 2) { throw 'Unexpected picker refresh loop.' }
        $launchSequence=0
        $targetLabels=[ordered]@{AccentColor='Accent Color 1';AccentColor2='Accent Color 2';TitleTextColor='Title Text Color';HeaderTextColor='Header Text Color';TextColor='Body Text Color';BackgroundColor='Background Color';BorderColor='Border Color';DividerColor='Divider Color';TableHeaderBorderColor='Table header border';GridColor='Graph Grid'}
        foreach ($targetKey in $targetLabels.Keys) {
            $snapshot=[IO.File]::ReadAllText($userPath)
            $previous=Read-Variables $userPath
            $launchSequence++
            Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|$targetKey"
            $opened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
            if ($opened -notmatch ('(?m)^Title='+[regex]::Escape($targetLabels[$targetKey])+'\r?$')) { throw "Wrong target title for $targetKey." }
            $previousRGB=($previous[$targetKey].Split(',')[0..2] -join ',')
            if ($opened -notmatch ('(?m)^Original='+[regex]::Escape($previousRGB)+'\r?$')) { throw "Wrong current color for $targetKey." }
            $placed=@([ParallaxColorPickerNative]::OwnWindows([uint32]$process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 })
            if ($placed.Count -ne 1 -or $placed[0].Left -ne -19999 -or $placed[0].Top -ne -20000) { throw "Launcher did not place the picker beside its skin: $($placed[0].Left),$($placed[0].Top)." }
            if ($targetKey -in @('AccentColor2','TextColor','BackgroundColor','BorderColor','DividerColor','TableHeaderBorderColor','GridColor')) { $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot "captures\target-$targetKey.png") $case.Width $case.Height)) }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|invalid"
            $rejected=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
            if ($rejected -notmatch ('(?m)^Title='+[regex]::Escape($targetLabels[$targetKey])+'\r?$')) { throw 'Invalid target changed the active target.' }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|corner"
            $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
            # ActivateConfig + OpenTarget also works with an already-open preview.
            $launchSequence++
            Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|$targetKey"
            $reopened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
            $oldHex=[regex]::Match($opened,'(?m)^Hex=([^\r\n]+)').Groups[1].Value
            if ($reopened -notmatch ('(?m)^Hex='+[regex]::Escape($oldHex)+'\r?$')) { throw 'Reopening retained an unsaved preview.' }
            foreach ($action in @('corner','slice')) {
                $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|$action"
                $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
            }
            if ([IO.File]::ReadAllText($userPath) -ne $snapshot) { throw 'Retargeting or preview changed preferences.' }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|apply"
            $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
            Start-Sleep -Milliseconds 700
            $windows=@([ParallaxColorPickerNative]::OwnWindows([uint32]$process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 })
            if ($windows.Count) { throw "Apply did not close $targetKey." }
            $saved=Read-Variables $userPath
            $expectedSaved=if ($targetKey -in @('BackgroundColor','GridColor')) { '0,255,255,'+$previous[$targetKey].Split(',')[3] } else { '0,255,255' }
            if ($saved[$targetKey] -ne $expectedSaved) { throw "Apply saved the wrong color, alpha or key for $targetKey." }
            if ($saved.Count -ne $previous.Count) { throw 'Apply introduced an unrelated key.' }
            foreach ($key in $previous.Keys) { if ($key -ne $targetKey -and $saved[$key] -ne $previous[$key]) { throw "Editing $targetKey changed unrelated $key." } }
            $savedSnapshot=[IO.File]::ReadAllText($userPath)
            $launchSequence++
            Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|$targetKey"
            $reopened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
            if ($reopened -notmatch '(?m)^Hex=#00FFFF\r?$') { throw "Reopening $targetKey did not read its saved value." }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|plane"
            $null=Await-Report (Join-Path $caseRoot "result-$sequence.txt")
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|cancel"
            $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
            # The report precedes Rainmeter's queued deactivation and native HWND teardown.
            Start-Sleep -Milliseconds 1000
            $windows=@([ParallaxColorPickerNative]::OwnWindows([uint32]$process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 })
            $unchanged=[IO.File]::ReadAllText($userPath) -eq $savedSnapshot
            if ($windows.Count -or -not $unchanged) { throw "Cancel failed for $targetKey. Remaining windows: $($windows.Count); preferences unchanged: $unchanged." }
        }
        if ([IO.File]::ReadAllText($overridePath) -ne $override) { throw 'Targeted picker changed module overrides.' }
        $step={ param([string]$command) $script:sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$($script:sequence)|$command"; Await-Report (Join-Path $caseRoot "result-$($script:sequence).txt") }
        $row={ param([string]$report,[int]$index) [regex]::Match($report,"(?m)^Row$index=([^\r\n]*)").Groups[1].Value }
        $title={ param([string]$report) [regex]::Match($report,'(?m)^Title=([^\r\n]*)').Groups[1].Value }
        $closed={ Start-Sleep -Milliseconds 800; @([ParallaxColorPickerNative]::OwnWindows([uint32]$process.Id) | Where-Object { $_.Width -gt 1 -or $_.Height -gt 1 }).Count -eq 0 }
        # Dropdown: opens from the target text or the chevron, scrolls, ignores group headings, retargets.
        $launchSequence++
        Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|TextColor"
        $opened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
        if ([int][regex]::Match($opened,'(?m)^ChevronX=(\d+)').Groups[1].Value -lt [int][regex]::Match($opened,'(?m)^TargetRight=(\d+)').Groups[1].Value) { throw 'Chevron sits inside the target text.' }
        $report=& $step 'menu'
        if ((& $row $report 1) -ne 'Accent Color 2' -or (& $row $report 4) -ne 'Body Text Color') { throw 'Dropdown did not open on the current target.' }
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\menu-open.png') $case.Width $case.Height))
        $report=& $step 'scrolldown'
        if ((& $row $report 1) -ne 'Body Text Color' -or (& $row $report 3) -ne 'Surfaces') { throw 'Wheel scroll did not move the list.' }
        $report=& $step 'scrollup'
        if ((& $row $report 1) -ne 'Accent Color 2') { throw 'Wheel scroll up did not move the list back.' }
        $null=& $step 'scrolldown'
        $report=& $step 'pick3'
        if ((& $title $report) -ne 'Body Text Color') { throw 'A group heading changed the target.' }
        $report=& $step 'pick2'
        if ((& $title $report) -ne 'Muted Color') { throw 'Picking a row did not retarget the picker.' }
        $records.Add((Capture-OwnWindow $process (Join-Path $caseRoot 'captures\menu-picked.png') $case.Width $case.Height))
        foreach ($command in @('corner','slice')) { $null=& $step $command }
        $snapshot=Read-Variables $userPath
        $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|apply"
        $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
        if (-not (& $closed)) { throw 'Apply after a dropdown pick did not close the picker.' }
        $saved=Read-Variables $userPath
        if ($saved['MutedColor'] -ne '0,255,255') { throw 'Apply after a dropdown pick saved the wrong color.' }
        foreach ($key in $snapshot.Keys) { if ($key -ne 'MutedColor' -and $snapshot[$key] -ne $saved[$key]) { throw "Dropdown apply changed unrelated $key." } }
        # The chevron opens the same list; the last rows are the CPU threads.
        $launchSequence++
        Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|BorderColor"
        $null=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
        $report=& $step 'chevron'
        if ((& $row $report 4) -ne 'Border Color') { throw 'Chevron did not open the list.' }
        $threads=[Math]::Min(64,[int]$env:NUMBER_OF_PROCESSORS)
        for ($i=0; $i -lt [Math]::Ceiling((26+5+$threads)/3); $i++) { $report=& $step 'scrolldown' }
        if ((& $row $report 10) -ne "CPU Thread $threads") { throw "List did not end on CPU Thread $threads." }
        $report=& $step 'pick10'
        if ((& $title $report) -ne "CPU Thread $threads") { throw 'Picking the last thread did not retarget the picker.' }
        $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|cancel"
        $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
        if (-not (& $closed)) { throw 'Cancel after a dropdown pick did not close the picker.' }
        if ([IO.File]::ReadAllText($overridePath) -ne $override -or (Read-Variables $userPath)['MutedColor'] -ne '0,255,255') { throw 'Dropdown cancel changed preferences.' }
        # Module-file targets write only their own key, to their own User file.
        foreach ($module in @(@{Key='RAMHistoryEmptyColor';Label='Memory History Cover';Seed='25,25,25';File=$ramPath;Original=$null},@{Key='CPUThreadColor3';Label='CPU Thread 3';Seed='240,225,40';File=$overridePath})) {
            $before=Read-Variables $module.File
            $settingsBefore=[IO.File]::ReadAllText($userPath)
            $launchSequence++
            Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|$($module.Key)"
            $opened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
            if ((& $title $opened) -ne $module.Label -or $opened -notmatch ('(?m)^Original='+[regex]::Escape($module.Seed)+'\r?$')) { throw "Wrong title or seed for $($module.Key)." }
            foreach ($command in @('corner','slice')) { $null=& $step $command }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|apply"
            $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
            if (-not (& $closed)) { throw "Apply did not close $($module.Key)." }
            $after=Read-Variables $module.File
            if ($after[$module.Key] -ne '0,255,255') { throw "Apply saved the wrong value for $($module.Key)." }
            foreach ($key in $before.Keys) { if ($key -ne $module.Key -and $before[$key] -ne $after[$key]) { throw "Editing $($module.Key) changed $key." } }
            if ([IO.File]::ReadAllText($userPath) -ne $settingsBefore) { throw "Editing $($module.Key) changed Settings.inc." }
        }
        # On a monitor (Rainmeter's own coordinates): beside the skin, flipped to its left at the right edge, held above the work-area bottom.
        $wx,$wy,$ww,$wh=@(([IO.File]::ReadAllText((Join-Path $caseRoot 'monitor.txt'))).Trim().Split('|') | ForEach-Object { [int]$_ })
        foreach ($place in @(
            @{X=$wx+$ww-1;Y=$wy+100;ExpectX=$wx+$ww-1-$case.Width;ExpectY=$wy+100},
            @{X=$wx;Y=$wy+100;ExpectX=$wx+1;ExpectY=$wy+100},
            @{X=$wx+200;Y=$wy+$wh-50;ExpectX=$wx+201;ExpectY=$wy+$wh-$case.Height})) {
            $launchSequence++
            Write-Isolated (Join-Path $caseRoot 'launch-request.txt') "$launchSequence|AccentColor|$($place.X)|$($place.Y)"
            $opened=Await-Report (Join-Path $caseRoot "launch-$launchSequence.txt")
            $px=[int][regex]::Match($opened,'(?m)^PickerX=(-?\d+)').Groups[1].Value
            $py=[int][regex]::Match($opened,'(?m)^PickerY=(-?\d+)').Groups[1].Value
            if ($px -ne $place.ExpectX -or $py -ne $place.ExpectY) { throw "Picker opened at $px,$py; expected $($place.ExpectX),$($place.ExpectY) for a skin at $($place.X),$($place.Y) on the work area $wx,$wy,$ww,$wh." }
            $sequence++; Write-Isolated (Join-Path $caseRoot 'request.txt') "$sequence|cancel"
            $null=Await-Report (Join-Path $caseRoot "before-close-$sequence.txt")
            if (-not (& $closed)) { throw 'Cancel did not close the picker after an on-monitor launch.' }
        }
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
$report=[ordered]@{Status='PASS';Runs=2;Math='sRGB/HSV primaries, D50 Lab white/black, published W3C leaf vector, 125-color roundtrips, explicit gamut clipping; Background RGB/RGBA and hex6/8 alpha0/128/255 retention';Actions='Native source modes, channels, spectra, Apply and Cancel; Launcher.lua from a separate skin opens each target beside it (window position checked off screen and on the first monitor: right, flipped left, bottom clamp), closed/open/reopened; title dropdown by target text and chevron, wheel, heading rows, retarget, Apply and Cancel through it; RAM and CPU-thread targets write only their own User file';Persistence='Preview and invalid targets never write; Apply changes only selected key; independent panel/divider/table-header colors and thicknesses; BackgroundColor retains alpha; Cancel preserves exact bytes; module override unchanged';Captures=$records.ToArray();Limitations='Executes source actions in isolated Rainmeter. Mouse percentages are substituted from test values; does not simulate system cursor hit testing, mixed DPI, or a live user configuration.'}
Write-Isolated (Join-Path $runRoot 'report.json') ($report | ConvertTo-Json -Depth 6)
[pscustomobject]@{Status='PASS';RunRoot=$runRoot;Captures=$records.ToArray()}
