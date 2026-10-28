#requires -Version 5.1
<#
Native check of developer mode in an isolated Rainmeter instance: its own settings file, its own
Skins folder (a staged copy of this repository as the "release"), its own windows, its own log. It drives
the real Global Settings buttons through a test-only harness skin (tools\tests\DevHarness.lua reads a trigger
file), so the whole chain runs: the Dev mode toggle, the hidden PowerShell helper, the saved DevMode key,
!ActivateConfig of the copy's utilities, the status icons, Compare, Reload(), and unloading. It never sends
a bang from the command line and never touches the live installation. The instance is stopped at the end.

Run: .\tools\tests\Test-DevModeNative.ps1 [-Modules CPU,RAM] [-SkipClick]
Evidence (captures, log, run folder) stays under build\devmode-native-<id>.
#>
[CmdletBinding()]
param(
    [string[]]$Modules = @('CPU', 'RAM'),
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    # A click on an icon opens the report in Notepad; this skips that step (and the Notepad window).
    [switch]$SkipClick
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed.' }
$checks = 0
function Assert-That([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAILED: $Message" }
    Write-Host "  ok: $Message"
}

$stageOutput = @(& (Join-Path $repo 'tools\Stage-Parallax.ps1') -Version 'devmode-native' -SkipValidation 6>$null)
$stage = $stageOutput[-1]
$run = Join-Path $repo ('build\devmode-native-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$skins = Join-Path $run 'Skins'
$release = Join-Path $skins 'Parallax'
$dev = Join-Path $skins 'ParallaxDev'
$captures = Join-Path $run 'captures'
foreach ($folder in $skins, $captures, (Join-Path $run 'Layouts'), (Join-Path $run 'Plugins'), (Join-Path $run 'Addons')) { $null = New-Item -ItemType Directory -Path $folder }
Copy-Item -LiteralPath $stage.SkinRoot -Destination $release -Recurse
Remove-Item -LiteralPath $stage.StageRoot -Recurse -Force
# No update prompt from the release in the instance.
$userSettings = Join-Path $release '@Resources\User\Settings.inc'
$text = [IO.File]::ReadAllText($userSettings)
[IO.File]::WriteAllText($userSettings, [regex]::Replace($text, '(?m)^UpdateCheck=[^\r\n]*', 'UpdateCheck=0'))
if ($text -notmatch '(?m)^UpdateCheck=') { Add-Content -LiteralPath $userSettings -Value 'UpdateCheck=0' }

# The harness skin: one Script measure that runs the lines the test writes to trigger.txt.
$harnessDir = Join-Path $skins 'Harness'
$null = New-Item -ItemType Directory -Path $harnessDir
Copy-Item -LiteralPath (Join-Path $repo 'tools\tests\DevHarness.lua') -Destination (Join-Path $harnessDir 'DevHarness.lua')
$trigger = Join-Path $run 'trigger.txt'
[IO.File]::WriteAllText($trigger, '')
[IO.File]::WriteAllText((Join-Path $harnessDir 'Harness.ini'), "[Rainmeter]`r`nUpdate=500`r`n`r`n[Variables]`r`nTriggerFile=$trigger`r`n`r`n[MeasureHarness]`r`nMeasure=Script`r`nScriptFile=#CURRENTPATH#DevHarness.lua`r`n`r`n[MeterDot]`r`nMeter=Image`r`nW=1`r`nH=1`r`n")

$ini = "[Rainmeter]`r`nSkinPath=$skins\`r`nDisableVersionCheck=1`r`nDisableAutoUpdate=1`r`nLogging=1`r`nLanguage=1033`r`nTrayIcon=0`r`n"
foreach ($config in (@('Settings') + $Modules)) {
    $ini += "`r`n[Parallax\$config]`r`nActive=1`r`nWindowX=-20000`r`nWindowY=-20000`r`nKeepOnScreen=0`r`nDraggable=0`r`nClickThrough=1`r`nAlphaValue=255`r`n"
}
$ini += "`r`n[Harness]`r`nActive=1`r`nWindowX=-20000`r`nWindowY=-20000`r`nKeepOnScreen=0`r`nDraggable=0`r`nClickThrough=1`r`n"
$iniPath = Join-Path $run 'Rainmeter.ini'
[IO.File]::WriteAllText($iniPath, $ini)
[IO.File]::WriteAllText((Join-Path $run 'Rainmeter.data'), "[Rainmeter]`r`n")

Add-Type -AssemblyName System.Drawing
if (-not ('DevNativeShot' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class DevNativeShot {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static List<object[]> Windows(uint pid) {
        var list = new List<object[]>();
        EnumWindows((h, u) => {
            uint owner; GetWindowThreadProcessId(h, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(h, cls, 256);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(h, title, 1024);
            RECT r; GetWindowRect(h, out r);
            list.Add(new object[] { h, title.ToString(), r.Right - r.Left, r.Bottom - r.Top, r.Left, r.Top });
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@
}
$script:process = $null
function Get-OwnWindows { @([DevNativeShot]::Windows([uint32]$script:process.Id) | ForEach-Object { [pscustomobject]@{ Handle = [IntPtr]$_[0]; Config = (([string]$_[1]) -replace '^.*\\Skins\\', '' -replace '\\[^\\]+\.ini$', ''); Title = [string]$_[1]; W = [int]$_[2]; H = [int]$_[3]; X = [int]$_[4]; Y = [int]$_[5] } }) }
function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$What) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) { if (& $Condition) { return } Start-Sleep -Milliseconds 400 }
    throw "Timed out after $Seconds s waiting for: $What"
}
function Save-Capture($Window, [string]$Name) {
    $bitmap = New-Object Drawing.Bitmap $Window.W, $Window.H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([Drawing.Color]::Magenta)
    $hdc = $graphics.GetHdc()
    $null = [DevNativeShot]::PrintWindow($Window.Handle, $hdc, 2)
    $graphics.ReleaseHdc($hdc); $graphics.Dispose()
    $path = Join-Path $captures ($Name + '.png')
    $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    return [pscustomobject]@{ Bitmap = $bitmap; Path = $path }
}
# Pixels that differ between two captures inside a rectangle; the title band left of the value readout.
function Compare-Band($A, $B, [int]$Width, [int]$Height) {
    $changed = New-Object Collections.Generic.List[object]
    for ($y = 0; $y -lt $Height; $y++) { for ($x = 0; $x -lt $Width; $x++) {
        $p = $A.Bitmap.GetPixel($x, $y); $q = $B.Bitmap.GetPixel($x, $y)
        if ([Math]::Abs($p.R - $q.R) + [Math]::Abs($p.G - $q.G) + [Math]::Abs($p.B - $q.B) -gt 60) { $changed.Add([pscustomobject]@{ X = $x; Y = $y; Before = $p; After = $q }) }
    } }
    return $changed.ToArray()
}
function Send-Bang([string]$Line) { Add-Content -LiteralPath $trigger -Value $Line }
function Read-Log { if (Test-Path -LiteralPath (Join-Path $run 'Rainmeter.log')) { @(Get-Content -LiteralPath (Join-Path $run 'Rainmeter.log')) } else { @() } }

try {
    $script:process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $run -WindowStyle Hidden -PassThru
    Write-Host "Isolated Rainmeter pid $($script:process.Id); run folder $run"
    $expected = @('Parallax\Settings') + @($Modules | ForEach-Object { "Parallax\$_" }) + @('Harness')
    Wait-Until { @(Get-OwnWindows).Count -ge $expected.Count } 60 'the release windows to load'
    Start-Sleep -Seconds 6
    $titles = @(Get-OwnWindows | ForEach-Object { $_.Config })
    Assert-That (@(Compare-Object $titles $expected).Count -eq 0)"the release windows are loaded: $($titles -join ', ')"
    Assert-That (-not (Test-Path -LiteralPath $dev)) 'no developer copy exists yet'
    $settingsWindow = Get-OwnWindows | Where-Object Config -eq 'Parallax\Settings'
    $before = Save-Capture $settingsWindow 'settings-off'
    Assert-That ($settingsWindow.W -eq 456 -and $settingsWindow.H -eq 1005) "Global Settings is 456x1005 with the Developer section (got $($settingsWindow.W)x$($settingsWindow.H))"

    # ---- Dev mode on, through the real button chain -----------------------------------------------------------------
    Send-Bang '!CommandMeasure MeasureDevPanel "ToggleDev(1)" "Parallax\Settings"'
    Wait-Until { @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' }).Count -ge $Modules.Count } 90 'the dev copy to be created and its utilities loaded'
    Start-Sleep -Seconds 6
    Assert-That (Test-Path -LiteralPath (Join-Path $dev '@Resources\Dev\Status.inc')) 'the copy exists and has a status file'
    $devTitles = @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' } | ForEach-Object { $_.Config } | Sort-Object)
    Assert-That (($devTitles -join ',') -eq ((@($Modules | ForEach-Object { "ParallaxDev\$_" }) | Sort-Object) -join ',')) "the copy's utilities loaded beside the release: $($devTitles -join ', ')"
    Assert-That ((Get-Content -LiteralPath (Join-Path $release '@Resources\User\Settings.inc') -Raw) -match '(?m)^DevMode=1') 'DevMode=1 saved in the release''s settings'
    Assert-That ((Get-Content -LiteralPath (Join-Path $dev '@Resources\User\Settings.inc') -Raw) -match '(?m)^ParallaxDevBuild=1') 'the copy is marked as a developer build'
    $statusText = Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Status.inc') -Raw
    Assert-That ($statusText -match '(?m)^DevDiffTotal=0') 'an unmodified copy reports no differences'
    $first = @{}
    foreach ($module in $Modules) { $first[$module] = Save-Capture (Get-OwnWindows | Where-Object Config -eq "ParallaxDev\$module") "dev-$module-same" }
    $onSettings = Save-Capture (Get-OwnWindows | Where-Object Config -eq 'Parallax\Settings') 'settings-on'

    # ---- edit the copy, compare from Global Settings ------------------------------------------------------------------
    $edited = $Modules[0]
    $iniFile = (Get-ChildItem -LiteralPath (Join-Path $dev $edited) -Filter '*.ini' | Sort-Object Name | Select-Object -First 1).FullName
    Add-Content -LiteralPath $iniFile -Value "`r`n; edited by the native test"
    Send-Bang '!CommandMeasure MeasureDevPanel "Compare()" "Parallax\Settings"'
    Wait-Until { (Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Status.inc') -Raw) -match '(?m)^DevDiffTotal=1' } 60 'the comparison to finish'
    Start-Sleep -Seconds 3
    $report = Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Diff.txt') -Raw
    Assert-That ($report -match "(?m)^  M $edited\\") "the report lists the edited $edited file"
    foreach ($module in $Modules) {
        $now = Save-Capture (Get-OwnWindows | Where-Object Config -eq "ParallaxDev\$module") "dev-$module-after"
        $changed = @(Compare-Band $first[$module] $now 150 30)
        if ($module -eq $edited) {
            $red = @($changed | Where-Object { $_.After.R -gt 150 -and $_.After.G -lt 110 })
            $wasGreen = @($changed | Where-Object { $_.Before.G -gt $_.Before.R })
            Assert-That ($red.Count -ge 8) "$module's status icon turned red (red pixels in the title band: $($red.Count))"
            Assert-That ($wasGreen.Count -ge 8) "$module's icon was green before (green pixels that changed: $($wasGreen.Count))"
            $left = ($changed | Measure-Object X -Minimum).Minimum; $right = ($changed | Measure-Object X -Maximum).Maximum
            Assert-That (($right - $left) -le 22) "the change is one icon-sized area (x $left to $right)"
        } else {
            Assert-That ($changed.Count -eq 0) "$module's icon is unchanged and still green (changed pixels: $($changed.Count))"
        }
    }
    $afterSettings = Save-Capture (Get-OwnWindows | Where-Object Config -eq 'Parallax\Settings') 'settings-compared'

    # ---- the click on an icon runs its own comparison (no Rainmeter bang needed from outside) ------------------------
    if (-not $SkipClick) {
        $stamp = [regex]::Match((Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Status.inc') -Raw), '(?m)^DevComparedAt=(\d+)').Groups[1].Value
        Start-Sleep -Seconds 2
        Send-Bang "!CommandMeasure MeasureParallaxDev `"Click()`" `"ParallaxDev\$edited`""
        Wait-Until { [regex]::Match((Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Status.inc') -Raw), '(?m)^DevComparedAt=(\d+)').Groups[1].Value -ne $stamp } 60 "a click on $edited's icon to run its own comparison"
        Assert-That $true "a click on $edited's icon ran a comparison from inside the copy"
        # The click then opens the report in Notepad; close the one this test caused.
        Start-Sleep -Seconds 3
        Get-Process -Name notepad -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like 'Diff*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # ---- Dev mode off -------------------------------------------------------------------------------------------------
    Send-Bang '!CommandMeasure MeasureDevPanel "ToggleDev(-1)" "Parallax\Settings"'
    Wait-Until { @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' }).Count -eq 0 } 60 'the copy''s utilities to unload'
    Assert-That (Test-Path -LiteralPath $dev) 'the copy''s files stay'
    # The key is written by a bang queued just before the unload, so allow it a moment.
    Wait-Until { (Get-Content -LiteralPath (Join-Path $release '@Resources\User\Settings.inc') -Raw) -match '(?m)^DevMode=0' } 15 'DevMode=0 to be saved'
    Assert-That ((Get-Content -LiteralPath (Join-Path $release '@Resources\User\Settings.inc') -Raw) -match '(?m)^DevMode=0') 'DevMode=0 saved'
    Assert-That (@(Get-OwnWindows | Where-Object { $_.Config -like 'Parallax\*' }).Count -eq ($Modules.Count + 1)) 'the release windows are untouched'
    Save-Capture (Get-OwnWindows | Where-Object Config -eq 'Parallax\Settings') 'settings-off-again' | Out-Null

    # ---- a new release since the copy was made: Dev mode On rebuilds it in place, with no Rainmeter refresh -----------
    $refreshes = { @(Read-Log | Where-Object { $_ -match 'Harness\\Harness\.ini: Refreshing skin' }).Count }
    $refreshesBefore = & $refreshes
    $versionInc = Join-Path $release '@Resources\Version.inc'
    [IO.File]::WriteAllText($versionInc, [regex]::Replace([IO.File]::ReadAllText($versionInc), '(?m)^ParallaxVersion=.*', 'ParallaxVersion=9.9.9-native'))
    Add-Content -LiteralPath (Join-Path $dev 'CPU\Marker.inc') -Value '; edit in the old copy'
    Send-Bang '!CommandMeasure MeasureDevPanel "ToggleDev(1)" "Parallax\Settings"'
    Wait-Until { @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' }).Count -eq $Modules.Count } 90 'the rebuilt copy''s utilities to load'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dev 'CPU\Marker.inc'))) 'the copy was rebuilt from the new release'
    Assert-That (@(Get-ChildItem -LiteralPath $skins -Directory | Where-Object Name -like '@ParallaxDev-backup-*').Count -eq 1) 'the old copy was kept as a backup'
    Assert-That ((Get-Content -LiteralPath (Join-Path $dev '@Resources\User\Settings.inc') -Raw) -match '(?m)^ParallaxDevBase=9\.9\.9-native') 'the rebuilt copy is based on the new release'
    Assert-That ((& $refreshes) -eq $refreshesBefore) 'a rebuild needed no Rainmeter refresh'

    # ---- the Reset button with dev mode on: unload, rebuild, reload ------------------------------------------------------
    Add-Content -LiteralPath (Join-Path $dev 'CPU\Marker.inc') -Value '; edit before Reset'
    Send-Bang '!CommandMeasure MeasureDevPanel "Reset()" "Parallax\Settings"'
    Wait-Until { @(Get-ChildItem -LiteralPath $skins -Directory | Where-Object Name -like '@ParallaxDev-backup-*').Count -eq 2 } 90 'Reset to back the copy up'
    Wait-Until { @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' }).Count -eq $Modules.Count } 90 'the reset copy''s utilities to reload'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dev 'CPU\Marker.inc'))) 'Reset rebuilt the copy'
    Assert-That ((& $refreshes) -eq $refreshesBefore) 'Reset needed no Rainmeter refresh'
    Send-Bang '!CommandMeasure MeasureDevPanel "ToggleDev(-1)" "Parallax\Settings"'
    Wait-Until { @(Get-OwnWindows | Where-Object { $_.Config -like 'ParallaxDev\*' }).Count -eq 0 } 60 'the copy''s utilities to unload again'
    $problems = @(Read-Log | Where-Object { $_ -match '^(ERRO|WARN)' })
    foreach ($line in $problems) { Write-Host "  log: $line" }
    Assert-That (@($problems | Where-Object { $_ -match '^ERRO' }).Count -eq 0) 'the Rainmeter log has no errors'
    Write-Host "PASS $checks checks. Captures: $captures"
} finally {
    if ($null -ne $script:process) {
        $script:process.Refresh()
        if (-not $script:process.HasExited) { Stop-Process -InputObject $script:process -Force; $null = $script:process.WaitForExit(5000) }
    }
    Write-Host "Run folder: $run"
}
