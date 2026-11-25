#requires -Version 5.1
<#
.SYNOPSIS
Checks that the tall settings panels fit a short screen and that every control stays reachable.

.DESCRIPTION
Stages the distributable sources and loads each panel in an isolated Rainmeter (its own settings file, Skins
folder, windows, log and TEMP), once per simulated work area and suite scale. A work area is simulated by
replacing the work-area variables that Scripts\PanelScroll.lua reads in the staged copy with its height.
Windows scaling itself is not simulated: the windows are ordinary ones, offscreen and click-through.

For each panel it reads the window Rainmeter really made and the meters' real positions, then:
- the window is the designed height, or the work area's where that is shorter;
- the panel's own wheel actions, and separately its own arrow buttons, reach a place where each clickable
  control lies whole inside the visible part (or in the fixed title part);
- a posted mouse click at each control's center reaches that control's action through Rainmeter's own hit
  test, and a click where a scrolled-away control would be does not reach it;
- one posted wheel message moves the panel by one step;
- moved down the real screen (nearly transparent, for a moment) it ends at the work area's bottom edge at the next
  pointer entry, with every control still reachable, and is whole again at the top; with room it keeps its height;
- the panel stays put while a number is being typed (a stand-in for the text box, so nothing opens);
- a refresh keeps the place, and closing forgets it;
- with room (-WorkArea 4000) nothing scrolls and no arrow shows.
It saves a capture at every page of each panel. No pointer, keyboard or focus of the desktop is used.

.EXAMPLE
.\tools\tests\Test-PanelScroll.ps1
.\tools\tests\Test-PanelScroll.ps1 -Panels Settings -WorkArea 672 -Scales 1
#>
[CmdletBinding()]
param(
    [ValidateSet('Settings', 'CPU', 'Chronometer', 'GPU')][string[]]$Panels = @('Settings', 'CPU', 'Chronometer', 'GPU'),
    [ValidateRange(300, 5000)][int[]]$WorkArea = @(816, 672, 4000),
    [ValidateSet('0.75', '1', '1.25', '1.5', '2')][string[]]$Scales = @('0.75', '1', '1.5'),
    [ValidateSet(180, 200, 220, 240, 280, 320)][int]$ColumnWidth = 220,
    [switch]$SkipClicks,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }
# Skin Installer can close the wrong Rainmeter (docs/PACKAGING.md).
if (Get-Process -Name SkinInstaller -ErrorAction SilentlyContinue) { throw 'Skin Installer is open. Run this after it has finished.' }
$invariant = [Globalization.CultureInfo]::InvariantCulture
$utf8 = [Text.UTF8Encoding]::new($false)

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxPanelScroll' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxPanelScroll {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] private static extern IntPtr SetFocus(IntPtr hwnd);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    public static List<object[]> Windows(uint pid) {
        var list = new List<object[]>();
        EnumWindows((h, u) => {
            uint owner; GetWindowThreadProcessId(h, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(h, cls, 256);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(h, title, 1024);
            RECT r; GetWindowRect(h, out r);
            list.Add(new object[] { h, title.ToString(), r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top });
            return true;
        }, IntPtr.Zero);
        return list;
    }
    private static IntPtr Point(int x, int y) { return (IntPtr)unchecked((int)(((uint)(ushort)(short)y << 16) | (uint)(ushort)(short)x)); }
    public static void Click(IntPtr hwnd, int x, int y) { PostMessage(hwnd, 0x0202, IntPtr.Zero, Point(x, y)); }
    // Rainmeter takes a posted wheel message only for the window its own thread has focused. The focus is set inside
    // the isolated instance's input queue; it is never made the foreground window.
    public static void Wheel(IntPtr hwnd, int screenX, int screenY, int delta) {
        uint pid; uint target = GetWindowThreadProcessId(hwnd, out pid); uint self = GetCurrentThreadId();
        AttachThreadInput(self, target, true);
        try {
            SetFocus(hwnd);
            PostMessage(hwnd, 0x020A, (IntPtr)unchecked((int)((uint)(ushort)(short)delta << 16)), Point(screenX, screenY));
        } finally { AttachThreadInput(self, target, false); }
    }
}
'@
}
# Rainmeter is not DPI aware, so its own coordinates are the DPI-unaware ones.
$null = [ParallaxPanelScroll]::SetThreadDpiAwarenessContext([IntPtr]-1)

$sources = @{
    Settings = @{ Config = 'Parallax\Settings'; Edit = "[!CommandMeasure MeasureSettings BeginEdit('Scale')]"; Files = @('Settings\Settings.ini', '@Resources\PanelScroll.inc') }
    CPU = @{ Config = 'Parallax\CPU\Settings'; Edit = "[!CommandMeasure MeasureCPUSettings BeginNumberInput('CPUDecimals')]"; Files = @('CPU\Settings\Settings.ini', '@Resources\PanelScroll.inc', '@Resources\UtilitySettingsNote.inc', '@Resources\Modules\CPU\SettingsMeters.inc') }
    Chronometer = @{ Config = 'Parallax\Chronometer\Settings'; Edit = "[!CommandMeasure MeasureChronometerSettings BeginNumberInput('Columns')]"; Files = @('Chronometer\Settings\Settings.ini', '@Resources\PanelScroll.inc', '@Resources\UtilitySettingsNote.inc') }
    GPU = @{ Config = 'Parallax\GPU\Settings'; Edit = '[!CommandMeasure MeasureGPUSettings BeginColumnsEdit()]'; Files = @('GPU\Settings\Settings.ini', '@Resources\PanelScroll.inc', '@Resources\UtilitySettingsNote.inc', '@Resources\Modules\GPU\SettingsMeters.inc') }
}
$script:checks = 0
function Assert-That([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAILED: $Message (evidence: $script:runRoot)" }
}
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($script:runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Get-Number([string]$Text) { [double]::Parse($Text, $invariant) }
function Read-Report([string]$Name, [int]$Seconds = 15) {
    $path = Join-Path $script:runRoot "$Name.txt"
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $path) {
            $lines = @(Get-Content -LiteralPath $path)
            if ($lines.Count -and $lines[-1] -eq 'END') { return $lines | Where-Object { $_ -ne '' -and $_ -ne 'END' } }
        }
        $script:process.Refresh()
        if ($script:process.HasExited) { throw "Isolated Rainmeter exited early; inspect $script:runRoot" }
        Start-Sleep -Milliseconds 50
    }
    throw "Timed out waiting for $Name; inspect $script:runRoot"
}
$script:seq = 0
function Send-Command([string]$Config, [string]$Call) {
    $script:seq++
    $temporary = Join-Path $script:runRoot 'command.tmp'
    Write-RunFile $temporary "$script:seq|$Config|$Call"
    # The driver may have the old file open for reading at that moment: try again.
    for ($try = 1; ; $try++) {
        try { Move-Item -LiteralPath $temporary -Destination (Join-Path $script:runRoot 'command.txt') -Force -ErrorAction Stop; break }
        catch { if ($try -ge 40) { throw }; Start-Sleep -Milliseconds 25 }
    }
    # The driver reads the file every 50 ms.
    Start-Sleep -Milliseconds 160
}
function Invoke-Report([string]$Config, [string]$Call, [string]$Name) {
    Send-Command $Config $Call
    Read-Report $Name
}
function Get-Window([string]$Config) {
    $found = @([ParallaxPanelScroll]::Windows([uint32]$script:process.Id) | Where-Object { ([string]$_[1]).EndsWith("\$Config\Settings.ini", [StringComparison]::OrdinalIgnoreCase) })
    if ($found.Count -ne 1) { return $null }
    [pscustomobject]@{ Handle = [IntPtr]$found[0][0]; X = [int]$found[0][2]; Y = [int]$found[0][3]; W = [int]$found[0][4]; H = [int]$found[0][5] }
}
function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$What) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) { if (& $Condition) { return } Start-Sleep -Milliseconds 100 }
    throw "Timed out after $Seconds s waiting for: $What (evidence: $script:runRoot)"
}
function Save-Capture([string]$Config, [string]$Name) {
    $window = Get-Window $Config
    $bitmap = New-Object Drawing.Bitmap $window.W, $window.H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([Drawing.Color]::Black)
    $hdc = $graphics.GetHdc()
    $printed = [ParallaxPanelScroll]::PrintWindow($window.Handle, $hdc, 2)
    $graphics.ReleaseHdc($hdc); $graphics.Dispose()
    if (-not $printed) { throw 'PrintWindow failed.' }
    $bitmap.Save((Join-Path $script:captures "$Name.png"), [Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}
# One parsed Audit: the variables, the window, and each stop's meters.
function ConvertFrom-Audit($Lines) {
    $audit = @{ Variables = @{}; Stops = [Collections.Generic.List[object]]::new() }
    foreach ($line in $Lines) {
        $p = $line.Split('|')
        if ($p[0] -eq 'V') { $audit.Variables[$p[1]] = Get-Number $p[2] }
        elseif ($p[0] -eq 'W') { $audit.Window = @($p[1..6] | ForEach-Object { [int]$_ }) }
        elseif ($p[0] -eq 'S') { $audit.Stops.Add(@{ Offset = Get-Number $p[1]; Meters = @{} }) }
        elseif ($p[0] -eq 'M') {
            $audit.Stops[$audit.Stops.Count - 1].Meters[$p[1]] = [pscustomobject]@{ X = Get-Number $p[2]; Y = Get-Number $p[3]; W = Get-Number $p[4]; H = Get-Number $p[5]; Contained = $p[6] -eq '1' }
        }
    }
    $audit
}
# Whole inside the visible part (or the fixed title part) at this stop.
function Test-Visible($Meter, $Audit) {
    if ($Meter.W -le 0 -or $Meter.H -le 0) { return $false }
    $top = 0.0; $bottom = $Audit.Variables.WindowHeight
    if ($Meter.Contained) { $top = $Audit.Variables.PanelScrollTopPx; $bottom = $top + $Audit.Variables.PanelScrollView }
    ($Meter.Y -ge $top - 0.5) -and ($Meter.Y + $Meter.H -le $bottom + 0.5)
}

$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'panel-scroll-test' 6>$null
$stage = @($stage)[-1]
$stageRoot = $stage.StageRoot
$summary = [Collections.Generic.List[object]]::new()
$realTemp = $env:TEMP; $realTmp = $env:TMP; $realLocal = $env:LOCALAPPDATA
foreach ($area in $WorkArea) {
    foreach ($scale in $Scales) {
        $script:runRoot = Join-Path $stageRoot "run-$area-$scale"
        $script:captures = Join-Path $script:runRoot 'captures'
        $skins = Join-Path $script:runRoot 'Skins'
        foreach ($folder in $script:captures, (Join-Path $script:runRoot 'Temp'), (Join-Path $script:runRoot 'Local'), (Join-Path $script:runRoot 'Layouts'), (Join-Path $script:runRoot 'Plugins'), (Join-Path $script:runRoot 'Addons'), (Join-Path $skins 'Driver')) {
            $null = New-Item -ItemType Directory -Path $folder -Force
        }
        $parallax = Join-Path $skins 'Parallax'
        Copy-Item -LiteralPath $stage.SkinRoot -Destination $parallax -Recurse
        Write-RunFile (Join-Path $script:runRoot 'TEST-ONLY.txt') "Isolated scroll test with harness instrumentation. Do not distribute.`n"
        $harness = Join-Path $script:runRoot 'Harness.lua'
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PanelScrollHarness.lua') -Destination $harness

        # The simulated screen: only the two work-area heights change.
        $scriptPath = Join-Path $parallax '@Resources\Scripts\PanelScroll.lua'
        $text = [IO.File]::ReadAllText($scriptPath)
        $patched = $text.Replace("'#WORKAREAHEIGHT@' .. n .. '#'", "'$area'").Replace("'#WORKAREAHEIGHT#'", "'$area'")
        if (($text.Length - $text.Replace('#WORKAREAHEIGHT', '').Length) / '#WORKAREAHEIGHT'.Length -ne 2 -or $patched.Contains('#WORKAREAHEIGHT')) { throw 'PanelScroll.lua reads the work area in another way; update the simulation.' }
        Write-RunFile $scriptPath $patched
        # Numeric entry without its text box: the helper waits, then reports a cancel.
        Write-RunFile (Join-Path $parallax '@Resources\Scripts\SettingsInput.ps1') "Start-Sleep -Milliseconds 2500`r`n[Console]::WriteLine('PARALLAX_INPUT_V1|cancel|')`r`n"
        $userPath = Join-Path $parallax '@Resources\User\Settings.inc'
        $user = [IO.File]::ReadAllText($userPath)
        foreach ($pair in @(@('Scale', $scale), @('ColumnWidth', "$ColumnWidth"), @('UpdateCheck', '0'))) {
            $pattern = "(?m)^$($pair[0])=[^\r\n]*"
            if ($user -match $pattern) { $user = [regex]::Replace($user, $pattern, "$($pair[0])=$($pair[1])") } else { $user = $user.TrimEnd() + "`r`n$($pair[0])=$($pair[1])`r`n" }
        }
        Write-RunFile $userPath $user
        # The tallest state of each panel: every feature that folds its rows away is shown.
        foreach ($pair in @(@('Chronometer', 'ChronometerShow(?:Clock|Uptime|Event|Timers)'), @('CPU', 'CPUShow\w+'), @('GPU', 'GPUShowProcess(?:es|Memory)'))) {
            $path = Join-Path $parallax "@Resources\User\$($pair[0]).inc"
            Write-RunFile $path ([regex]::Replace([IO.File]::ReadAllText($path), "(?m)^($($pair[1]))=[^\r\n]*", '${1}=1'))
        }
        Write-RunFile (Join-Path $skins 'Driver\Driver.ini') "[Rainmeter]`r`nUpdate=50`r`n[MeasurePanelScrollTest]`r`nMeasure=Script`r`nScriptFile=$harness`r`nRunRoot=$script:runRoot\`r`nRole=driver`r`n[MeterDot]`r`nMeter=Image`r`nW=1`r`nH=1`r`n"
        $ini = "[Rainmeter]`r`nSkinPath=$skins\`r`nDisableVersionCheck=1`r`nDisableAutoUpdate=1`r`nLogging=1`r`nLanguage=1033`r`nTrayIcon=0`r`n"
        $quiet = "Active=1`r`nWindowX=-20000`r`nWindowY=-20000`r`nKeepOnScreen=0`r`nDraggable=0`r`nClickThrough=1`r`nAlphaValue=255`r`n"
        $ini += "`r`n[Driver]`r`n$quiet"
        $wheel = @{}; $enter = @{}
        foreach ($panel in $Panels) {
            $source = $sources[$panel]
            $entry = Join-Path $parallax $source.Files[0]
            $names = foreach ($file in $source.Files) { [regex]::Matches([IO.File]::ReadAllText((Join-Path $parallax $file)), '(?m)^\[(Meter\w+)\]') | ForEach-Object { $_.Groups[1].Value } }
            $text = [IO.File]::ReadAllText($entry)
            $wheel[$panel] = @('Down', 'Up' | ForEach-Object { [regex]::Match($text, "(?m)^MouseScroll${_}Action=([^\r\n]+)").Groups[1].Value })
            $enter[$panel] = [regex]::Match($text, '(?m)^MouseOverAction=([^\r\n]+)').Groups[1].Value
            if ($wheel[$panel] -contains '' -or $enter[$panel] -eq '') { throw "$panel declares no wheel or pointer action." }
            # CPU settings scans HWiNFO as it opens; that helper has no part in this test.
            $text = [regex]::Replace($text, '(?m)^OnRefreshAction=[^\r\n]*', 'OnRefreshAction=')
            Write-RunFile $entry ($text + "`r`n[MeasurePanelScrollTest]`r`nMeasure=Script`r`nScriptFile=$harness`r`nRunRoot=$script:runRoot\`r`nRole=panel`r`nMeters=$($names -join '|')`r`nUpdateDivider=-1`r`n")
            $ini += "`r`n[$($source.Config)]`r`n$quiet"
        }
        $iniPath = Join-Path $script:runRoot 'Rainmeter.ini'
        Write-RunFile $iniPath $ini
        Write-RunFile (Join-Path $script:runRoot 'Rainmeter.data') "[Rainmeter]`r`n"
        $script:seq = 0
        $script:process = $null
        try {
            $env:TEMP = Join-Path $script:runRoot 'Temp'; $env:TMP = $env:TEMP; $env:LOCALAPPDATA = Join-Path $script:runRoot 'Local'
            try { $script:process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $script:runRoot -WindowStyle Hidden -PassThru }
            finally { $env:TEMP = $realTemp; $env:TMP = $realTmp; $env:LOCALAPPDATA = $realLocal }
            Wait-Until { @($Panels | Where-Object { -not (Get-Window $sources[$_].Config) }).Count -eq 0 } 30 'the panel windows'
            Start-Sleep -Milliseconds 1500
            foreach ($panel in $Panels) {
                $config = $sources[$panel].Config
                $name = "$panel-$area-$scale"
                $down, $up = $wheel[$panel]
                $audit = ConvertFrom-Audit (Invoke-Report $config "Audit('$name-wheel','$($down.Replace('"', '\"'))','$($up.Replace('"', '\"'))')" "$name-wheel")
                $pages = ConvertFrom-Audit (Invoke-Report $config "Audit('$name-page','[!CommandMeasure MeasurePanelScroll Page(1)]','[!CommandMeasure MeasurePanelScroll Page(-1)]')" "$name-page")
                $v = $audit.Variables
                $factor = Get-Number $scale
                $full = [Math]::Floor($v.PanelHeight * $factor + 0.5) + $v.Gap
                $expected = [Math]::Min($full, $area)
                $window = Get-Window $config
                Assert-That ($window.H -eq $expected) "$name window is $($window.H) px, expected $expected of $full"
                Assert-That ($window.W -eq $v.WindowWidth) "$name window is $($window.W) px wide, expected $($v.WindowWidth)"
                Assert-That ($v.WindowHeight -eq $expected -and $v.PanelHeightPx -eq $expected - $v.Gap) "$name height variables"
                $overflow = $full -gt $area
                $first = $audit.Stops[0]; $last = $audit.Stops[$audit.Stops.Count - 1]
                Assert-That ($v.PanelScrollHidden -eq [int](-not $overflow)) "$name shows the arrows only when it scrolls"
                Assert-That (($first.Meters.MeterScrollUp.W -gt 0) -eq $overflow -and ($first.Meters.MeterScrollThumb.W -gt 0) -eq $overflow) "$name arrow and position meters"
                Assert-That ($first.Offset -eq 0 -and $last.Offset -eq $full - $expected) "$name wheel range $($first.Offset) to $($last.Offset), expected $($full - $expected)"
                Assert-That ($pages.Stops[$pages.Stops.Count - 1].Offset -eq $last.Offset) "$name arrows reach the same end"
                # The clickable controls, with the panel's own actions.
                $actions = @{}
                foreach ($line in (Invoke-Report $config "Arm('$name-arm')" "$name-arm")) { $p = $line.Split('|', 3); if ($p[0] -eq 'A') { $actions[$p[1]] = $p[2] } }
                $controls = @($actions.Keys | Where-Object { $first.Meters.ContainsKey($_) -and $first.Meters[$_].W -gt 0 } | Sort-Object)
                Assert-That ($controls.Count -gt 20) "$name has $($controls.Count) clickable controls"
                $stopOf = @{}
                foreach ($control in $controls) {
                    for ($i = 0; $i -lt $audit.Stops.Count; $i++) { if (Test-Visible $audit.Stops[$i].Meters[$control] $audit) { $stopOf[$control] = $i; break } }
                    Assert-That ($stopOf.ContainsKey($control)) "$name control $control is never whole with the wheel"
                    Assert-That (@($pages.Stops | Where-Object { Test-Visible $_.Meters[$control] $pages }).Count -gt 0) "$name control $control is never whole with the arrows"
                }
                # Text that is not a control must be readable too.
                $texts = @($first.Meters.Keys | Where-Object { $first.Meters[$_].W -gt 0 -and $first.Meters[$_].Contained -and -not $actions.ContainsKey($_) })
                foreach ($item in $texts) { Assert-That (@($audit.Stops | Where-Object { Test-Visible $_.Meters[$item] $audit }).Count -gt 0) "$name $item is never whole" }
                # A capture of every page.
                for ($i = 0; $i -lt $pages.Stops.Count; $i++) {
                    Send-Command $config "Go($i,'[!CommandMeasure MeasurePanelScroll Page(1)]','[!CommandMeasure MeasurePanelScroll Page(-1)]')"
                    Save-Capture $config "$name-page$($i + 1)of$($pages.Stops.Count)"
                }
                $clicked = 0; $blocked = 0
                if (-not $SkipClicks) {
                    $downText = $down.Replace('"', '\"'); $upText = $up.Replace('"', '\"')
                    foreach ($stop in ($stopOf.Values | Sort-Object -Unique)) {
                        Send-Command $config "Go($stop,'$downText','$upText')"
                        $here = $audit.Stops[$stop].Meters
                        $window = Get-Window $config
                        $targets = @($controls | Where-Object { $stopOf[$_] -eq $stop })
                        foreach ($control in $targets) { $m = $here[$control]; [ParallaxPanelScroll]::Click($window.Handle, [int]($m.X + $m.W / 2), [int]($m.Y + $m.H / 2)) }
                        Start-Sleep -Milliseconds 120
                        $hits = @(Invoke-Report $config "Hits('$name-hits$stop')" "$name-hits$stop")
                        Assert-That ($hits.Count -eq $targets.Count) "$name stop ${stop}: $($targets.Count) clicks, $($hits.Count) hits"
                        for ($i = 0; $i -lt $targets.Count; $i++) {
                            # Overlapping parts of one control (frame, value, label) share one action.
                            Assert-That ($hits[$i] -eq $targets[$i] -or $actions[$hits[$i]] -eq $actions[$targets[$i]]) "$name click on $($targets[$i]) reached $($hits[$i])"
                            $clicked++
                        }
                    }
                    if ($overflow) {
                        # At the end, controls scrolled above the visible part lie behind the fixed title part.
                        Send-Command $config "Go(200,'$downText','$upText')"
                        $window = Get-Window $config
                        $above = @($controls | Where-Object { $m = $last.Meters[$_]; $m.Contained -and $m.Y -ge 0 -and $m.Y + $m.H -le $v.PanelScrollTopPx })
                        foreach ($control in $above) { $m = $last.Meters[$control]; [ParallaxPanelScroll]::Click($window.Handle, [int]($m.X + $m.W / 2), [int]($m.Y + $m.H / 2)) }
                        Start-Sleep -Milliseconds 120
                        foreach ($hit in @(Invoke-Report $config "Hits('$name-blocked')" "$name-blocked")) {
                            Assert-That (-not $last.Meters[$hit].Contained) "$name a click on the title part reached $hit behind it"
                        }
                        $blocked = $above.Count
                        # One real wheel message.
                        Send-Command $config "Go(0,'$downText','$upText')"
                        $window = Get-Window $config
                        [ParallaxPanelScroll]::Wheel($window.Handle, $window.X + [int]($window.W / 2), $window.Y + [int]($window.H / 2), -120)
                        Start-Sleep -Milliseconds 250
                        $moved = ConvertFrom-Audit (Invoke-Report $config "State('$name-wheeled')" "$name-wheeled")
                        Assert-That ($moved.Variables.PanelScrollY -eq [Math]::Min([Math]::Floor(56 * $factor + 0.5), $last.Offset)) "$name one wheel message moved to $($moved.Variables.PanelScrollY)"
                    }
                }
                # Where the panel stands, with its own pointer-entry action. The top of the real primary screen stands
                # in for the simulated one, whose height alone is replaced.
                $entering = "Do('$($enter[$panel].Replace('"', '\"'))')"
                $least = $v.PanelScrollTopPx + [Math]::Floor(4 * 28 * $factor) + $v.Gap
                Send-Command $config "Do('[!SetTransparency 1]')"
                foreach ($down_by in 30, 200, 0) {
                    Send-Command $config "Do('[!Move 40 $([int]$v.WORKAREAY + $down_by)]')"
                    Send-Command $config $entering
                    $placed = Get-Window $config
                    $wanted = if ($overflow) { [Math]::Min($full, [Math]::Max($area - $down_by, $least)) } else { $full }
                    Assert-That ($placed.Y -eq [int]$v.WORKAREAY + $down_by -and $placed.H -eq $wanted) "$name moved down $down_by is at $($placed.Y), $($placed.H) px tall, expected $wanted"
                    if ($overflow -and $down_by -eq 30) {
                        $lower = ConvertFrom-Audit (Invoke-Report $config "Audit('$name-lower','$($down.Replace('"', '\"'))','$($up.Replace('"', '\"'))')" "$name-lower")
                        foreach ($control in $controls) { Assert-That (@($lower.Stops | Where-Object { Test-Visible $_.Meters[$control] $lower }).Count -gt 0) "$name control $control is never whole 30 px down" }
                    }
                }
                Send-Command $config "Do('[!Move -20000 -20000]')"
                Send-Command $config $entering
                Send-Command $config "Do('[!SetTransparency 255]')"
                if ($overflow) {
                    # A number being typed holds the panel still; afterwards it scrolls again.
                    Send-Command $config "Go(0,'$($down.Replace('"', '\"'))','$($up.Replace('"', '\"'))')"
                    Send-Command $config "Do([=[$($sources[$panel].Edit)]=])"
                    Start-Sleep -Milliseconds 700
                    Send-Command $config "Do('$($down.Replace('"', '\"'))')"
                    Send-Command $config "Do('[!CommandMeasure MeasurePanelScroll Page(1)]')"
                    $held = ConvertFrom-Audit (Invoke-Report $config "State('$name-editing')" "$name-editing")
                    Assert-That ($held.Variables.PanelScrollY -eq 0) "$name scrolled to $($held.Variables.PanelScrollY) while a number was being typed"
                    for ($try = 1; $try -le 12; $try++) {
                        Start-Sleep -Milliseconds 800
                        Send-Command $config "Do('$($down.Replace('"', '\"'))')"
                        $freed = ConvertFrom-Audit (Invoke-Report $config "State('$name-edited$try')" "$name-edited$try")
                        if ($freed.Variables.PanelScrollY -gt 0) { break }
                    }
                    Assert-That ($freed.Variables.PanelScrollY -gt 0) "$name scrolls again after the number was typed"
                    # A refresh keeps the place; closing forgets it.
                    Send-Command $config "Go(200,'$($down.Replace('"', '\"'))','$($up.Replace('"', '\"'))')"
                    Send-Command $config "Do('[!Refresh]')"
                    Start-Sleep -Milliseconds 900
                    $after = ConvertFrom-Audit (Invoke-Report $config "State('$name-refreshed')" "$name-refreshed")
                    Assert-That ($after.Variables.PanelScrollY -eq $last.Offset) "$name place after a refresh is $($after.Variables.PanelScrollY), expected $($last.Offset)"
                    Send-Command 'Driver' "[!DeactivateConfig `"$config`"]"
                    Wait-Until { -not (Get-Window $config) } 10 "$panel to close"
                    Send-Command 'Driver' "[!ActivateConfig `"$config`" `"Settings.ini`"]"
                    Wait-Until { Get-Window $config } 10 "$panel to open again"
                    Start-Sleep -Milliseconds 900
                    $after = ConvertFrom-Audit (Invoke-Report $config "State('$name-reopened')" "$name-reopened")
                    Assert-That ($after.Variables.PanelScrollY -eq 0) "$name opens at the top again"
                    Assert-That (@(Get-ChildItem -LiteralPath (Join-Path $script:runRoot 'Temp') -Filter 'ParallaxScroll-*').Count -eq 0) "$name left its place file behind"
                }
                $summary.Add([pscustomobject]@{ Panel = $panel; WorkArea = $area; Scale = $scale; Full = $full; Window = $window.H; Stops = $audit.Stops.Count; Pages = $pages.Stops.Count; Controls = $controls.Count; Clicks = $clicked; Behind = $blocked })
            }
            $log = Join-Path $script:runRoot 'Rainmeter.log'
            $errors = @(if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' } })
            Assert-That ($errors.Count -eq 0) "Rainmeter errors: $($errors -join '; ')"
        } finally {
            if ($null -ne $script:process) {
                $script:process.Refresh()
                if (-not $script:process.HasExited) { Stop-Process -InputObject $script:process -Force; $null = $script:process.WaitForExit(5000) }
                $script:process.Dispose()
            }
        }
    }
}
$summary | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
Write-Output "PASS: $script:checks checks. Captures and reports: $stageRoot\run-*"
Write-Output 'Simulated work-area heights on ordinary windows: Windows scaling, a real short screen, a hand on the wheel, a touch screen and several monitors are not covered.'
