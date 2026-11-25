#requires -Version 5.1
<#
.SYNOPSIS
Checks where Parallax panels open the first time, in an isolated Rainmeter.

.DESCRIPTION
Stages the distributable sources and runs Rainmeter three times against generated
settings profiles. The fresh profile has no Parallax section at all, so every
panel opens through its DefaultWindowX/Y: Welcome is activated the way Skin
Installer does it, Load all runs through the real controller, and the windows
Rainmeter created are read from Windows. The panels must not overlap, must stay
inside the work area, and must return to the same places after Unload all and
Load all. The placed profile seeds saved positions, one of them exactly 0,0, and
none of those may move or be rewritten. The stacked profile has every panel saved
at 0,0, as releases before 0.1.0-alpha.16 left them, with Disk Meter taller and
Visualizer narrower than they ship: Arrange must take them apart by their real
sizes, Undo must put every one back, and a second Arrange must survive a reload.

-WorkArea simulates a primary work area: the staged copy's work-area variables
become numbers and DefaultKeepOnScreen=0 lets panels open past the edge of the
real screen. 'native' uses the real screen and leaves Keep on screen alone.

The live Rainmeter, its settings and Media's local data are never read or
changed; the test windows are click-through and almost transparent.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^(native|\d{3,5}x\d{3,5})$')][string]$WorkArea = '1920x1032',
    [ValidatePattern('^(0\.(7[5-9]|[89]\d?)|1(\.\d{1,2})?|2)$')][string]$Scale = '1',
    [ValidateSet(0, 180, 200, 220, 240, 280, 320)][int]$ColumnWidth = 0,
    # Panels that may overlap another or leave the work area, for sizes the layout does not cover.
    [ValidateSet('Chronometer', 'CPU', 'RAM', 'GPU', 'IO', 'Network', 'Media', 'Visualizer', 'Settings', 'Welcome')]
    [string[]]$Except = @(),
    [ValidateRange(6, 60)][int]$SettleSeconds = 12,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }
# Skin Installer can close the wrong Rainmeter (docs/PACKAGING.md).
if (Get-Process -Name SkinInstaller -ErrorAction SilentlyContinue) { throw 'Skin Installer is open. Run this after it has finished.' }

if (-not ('ParallaxPlacement.Native' -as [type])) {
    Add-Type -Namespace ParallaxPlacement -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
public delegate bool EnumProc(IntPtr window, IntPtr state);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr state);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, System.Text.StringBuilder text, int length);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr window, System.Text.StringBuilder text, int length);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);
'@
}
$components = [ordered]@{
    Chronometer = 'Chronometer.ini'; CPU = 'CPU.ini'; RAM = 'RAM.ini'; GPU = 'GPU.ini'
    IO = 'IO-Disk.ini'; Network = 'Network.ini'; Media = 'Media.ini'
    Visualizer = 'Visualizer.ini'; Settings = 'Settings.ini'; Welcome = 'Welcome.ini'
}
# Rainmeter is not DPI aware, so its own coordinates are the DPI-unaware ones.
function Get-Panels([int]$ProcessId) {
    $previous = [ParallaxPlacement.Native]::SetThreadDpiAwarenessContext([IntPtr]-1)
    $found = @{}
    $callback = [ParallaxPlacement.Native+EnumProc] {
        param($window, $state)
        $owner = [uint32]0
        $null = [ParallaxPlacement.Native]::GetWindowThreadProcessId($window, [ref]$owner)
        if ($owner -eq $ProcessId) {
            $text = New-Object Text.StringBuilder 512
            $null = [ParallaxPlacement.Native]::GetClassName($window, $text, 512)
            if ($text.ToString() -eq 'RainmeterMeterWindow') {
                $null = [ParallaxPlacement.Native]::GetWindowText($window, $text, 512)
                foreach ($key in $components.Keys) {
                    if (-not $text.ToString().EndsWith("\Parallax\$key\$($components[$key])", [StringComparison]::OrdinalIgnoreCase)) { continue }
                    $r = New-Object ParallaxPlacement.Native+RECT
                    $null = [ParallaxPlacement.Native]::GetWindowRect($window, [ref]$r)
                    if ($r.Right - $r.Left -gt 20) {
                        $found[$key] = [pscustomobject]@{ Panel = $key; X = $r.Left; Y = $r.Top; W = $r.Right - $r.Left; H = $r.Bottom - $r.Top; Right = $r.Right; Bottom = $r.Bottom }
                    }
                }
            }
        }
        return $true
    }
    $null = [ParallaxPlacement.Native]::EnumWindows($callback, [IntPtr]::Zero)
    if ($previous -ne [IntPtr]::Zero) { $null = [ParallaxPlacement.Native]::SetThreadDpiAwarenessContext($previous) }
    $found
}
function Wait-Panels([Diagnostics.Process]$Rainmeter, [int]$Count, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        Start-Sleep -Milliseconds 500
        $Rainmeter.Refresh()
        if ($Rainmeter.HasExited) { throw "Isolated Rainmeter exited early; inspect $runRoot" }
        $panels = Get-Panels $Rainmeter.Id
        if ($panels.Count -eq $Count) { return $panels }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Expected $Count panel windows, found $($panels.Count): $(@($panels.Keys) -join ', ')"
}
function Format-Place($Panel) { '{0},{1} {2}x{3}' -f $Panel.X, $Panel.Y, $Panel.W, $Panel.H }

$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'placement-smoke'
$runRoot = $stage.StageRoot
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated placement test with harness instrumentation. Do not distribute.`n"

$globalPath = Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$globalText = [regex]::Replace((Get-Content -LiteralPath $globalPath -Raw), '(?m)^Scale=[^\r\n]*', "Scale=$Scale")
if ($ColumnWidth) { $globalText = [regex]::Replace($globalText, '(?m)^ColumnWidth=[^\r\n]*', "ColumnWidth=$ColumnWidth") }
Write-RunFile $globalPath $globalText
$simulated = $WorkArea -ne 'native'
if ($simulated) {
    $areaWidth, $areaHeight = $WorkArea.Split('x') | ForEach-Object { [int]$_ }
    $geometryPath = Join-Path $parallaxRoot '@Resources\Geometry.inc'
    $geometry = Get-Content -LiteralPath $geometryPath -Raw
    foreach ($pair in @(@('#PWORKAREAX#', '0'), @('#PWORKAREAY#', '0'), @('#PWORKAREAWIDTH#', "$areaWidth"), @('#PWORKAREAHEIGHT#', "$areaHeight"))) { $geometry = $geometry.Replace($pair[0], $pair[1]) }
    Write-RunFile $geometryPath $geometry
    # Arrange reads Rainmeter's own screens, which a variable cannot replace.
    $controllerPath = Join-Path $parallaxRoot '@Resources\Modules\Welcome\Welcome.lua'
    $controller = Get-Content -LiteralPath $controllerPath -Raw
    $call = "area('WORKAREA', '@' .. number)"
    if (-not $controller.Contains($call)) { throw 'Welcome.lua no longer reads the screens as this check expects.' }
    Write-RunFile $controllerPath ($controller.Replace($call, "area('PLACEMENTTEST', '')"))
    $welcomePath = Join-Path $parallaxRoot 'Welcome\Welcome.ini'
    Write-RunFile $welcomePath ((Get-Content -LiteralPath $welcomePath -Raw) -replace '(?m)^Columns=2\r?$', "Columns=2`r`nPLACEMENTTESTX=0`r`nPLACEMENTTESTY=0`r`nPLACEMENTTESTWIDTH=$areaWidth`r`nPLACEMENTTESTHEIGHT=$areaHeight")
} else {
    Add-Type -AssemblyName System.Windows.Forms
    $previous = [ParallaxPlacement.Native]::SetThreadDpiAwarenessContext([IntPtr]-1)
    $area = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if ($previous -ne [IntPtr]::Zero) { $null = [ParallaxPlacement.Native]::SetThreadDpiAwarenessContext($previous) }
    $areaWidth = $area.Width; $areaHeight = $area.Height
    if ($area.X -ne 0 -or $area.Y -ne 0) { throw 'The native check expects the primary work area to start at 0,0.' }
}

# Test-only instrumentation: near-transparent click-through windows, and a one
# second clock in the event-driven Welcome panel that runs one command file.
$commandPath = Join-Path $runRoot 'command.txt'
$harnessPath = Join-Path $runRoot 'PlacementHarness.lua'
Write-RunFile $harnessPath (@'
function Initialize() end
function Update()
    local file = io.open([[__COMMAND__]], 'rb')
    if not file then return 0 end
    local call = file:read('*a')
    file:close()
    os.remove([[__COMMAND__]])
    SKIN:Bang('!CommandMeasure', 'MeasureWelcome', (call:gsub('%s+$', '')))
    return 1
end
'@.Replace('__COMMAND__', $commandPath))
foreach ($key in $components.Keys) {
    $path = Join-Path $parallaxRoot "$key\$($components[$key])"
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($axis in 'X', 'Y') {
        if ($text -notmatch "(?m)^DefaultWindow$axis=#Place${key}$axis#\r?$") { throw "$key does not name its first placement ($axis)." }
    }
    $options = "[Rainmeter]`r`nDefaultAlphaValue=1`r`nDefaultClickThrough=1`r`n"
    if ($simulated) { $options += "DefaultKeepOnScreen=0`r`n" }
    $text = [regex]::new('(?m)^\[Rainmeter\]\r?\n').Replace($text, $options, 1)
    if ($key -eq 'Welcome') {
        $text = [regex]::new('(?m)^Update=-1\r?$').Replace($text, 'Update=1000', 1)
        $text += "`r`n[MeasurePlacementHarness]`r`nMeasure=Script`r`nScriptFile=$harnessPath`r`n"
    }
    Write-RunFile $path $text
}
$loaderRoot = Join-Path $runRoot 'Skins\Loader'
$null = New-Item -ItemType Directory -Path $loaderRoot
Write-RunFile (Join-Path $loaderRoot 'Loader.ini') "[Rainmeter]`nUpdate=-1`nOnRefreshAction=[!Delay 500][!ActivateConfig `"Parallax\Welcome`" `"Welcome.ini`"]`n[MeterBounds]`nMeter=Image`nW=1`nH=1`n"

$saved = [ordered]@{ CPU = @(0, 0); GPU = @(300, 200); Settings = @(123, 45); Welcome = @(40, 60) }
$quiet = "AlphaValue=1`nClickThrough=1`nKeepOnScreen=0`n"
$profiles = [ordered]@{
    fresh = "`n[Loader]`nActive=1`nWindowX=0`nWindowY=0`n$quiet"
    placed = ($saved.Keys | ForEach-Object { "`n[Parallax\$_]`nActive=$([int]($_ -eq 'Welcome'))`nWindowX=$($saved[$_][0])`nWindowY=$($saved[$_][1])`n$quiet" }) -join ''
    stacked = ($components.Keys | ForEach-Object { "`n[Parallax\$_]`nActive=$([int]($_ -eq 'Welcome'))`nWindowX=0`nWindowY=0`n$quiet" }) -join ''
}
# Panels that collide or leave the work area.
function Test-Apart($Panels, [string]$What) {
    $keys = @($Panels.Keys | Sort-Object)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $a = $Panels[$keys[$i]]
        if ($a.X -lt 0 -or $a.Y -lt 0 -or $a.Right -gt $areaWidth -or $a.Bottom -gt $areaHeight) {
            $line = "${What}: $($a.Panel) leaves the work area: $(Format-Place $a)"
            if ($Except -contains $a.Panel) { Write-Output "ALLOWED: $line" } else { $failures.Add($line) }
        }
        for ($j = $i + 1; $j -lt $keys.Count; $j++) {
            $b = $Panels[$keys[$j]]
            $w = [Math]::Min($a.Right, $b.Right) - [Math]::Max($a.X, $b.X)
            $h = [Math]::Min($a.Bottom, $b.Bottom) - [Math]::Max($a.Y, $b.Y)
            if ($w -le 0 -or $h -le 0) { continue }
            $line = "${What}: $($a.Panel) and $($b.Panel) overlap by ${w}x${h}"
            if ($Except -contains $a.Panel -or $Except -contains $b.Panel) { Write-Output "ALLOWED: $line" } else { $failures.Add($line) }
        }
    }
}
$failures = [Collections.Generic.List[string]]::new()
$opened = $null
foreach ($name in $profiles.Keys) {
    $profileRoot = Join-Path $runRoot $name
    if ($name -eq 'stacked') {
        # Other sizes than the first placement allows for.
        foreach ($change in @(@('IO', '(?m)^IOMinPanelHeight=[^\r\n]*', 'IOMinPanelHeight=270'), @('Visualizer', '(?m)^Columns=[^\r\n]*', 'Columns=1'))) {
            $path = Join-Path $parallaxRoot "@Resources\User\$($change[0]).inc"
            $text = Get-Content -LiteralPath $path -Raw
            if ($text -notmatch $change[1]) { throw "User\$($change[0]).inc no longer has the setting this check changes." }
            Write-RunFile $path ([regex]::Replace($text, $change[1], $change[2]))
        }
    }
    foreach ($folder in 'Layouts', 'Plugins', 'Addons', 'Local') { $null = New-Item -ItemType Directory -Path (Join-Path $profileRoot $folder) -Force }
    $iniPath = Join-Path $profileRoot 'Rainmeter.ini'
    Write-RunFile $iniPath ("[Rainmeter]`nSkinPath=$(Join-Path $runRoot 'Skins')\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n" + $profiles[$name])
    Write-RunFile (Join-Path $profileRoot 'Rainmeter.data') "[Rainmeter]`n"
    $process = $null
    # An empty local data folder: Media's helpers have no saved intent to resume.
    $realLocal = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = Join-Path $profileRoot 'Local'
        try { $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $profileRoot -WindowStyle Hidden -PassThru }
        finally { $env:LOCALAPPDATA = $realLocal }
        $null = Wait-Panels $process 1 30
        Write-RunFile $commandPath 'LoadAll()'
        $null = Wait-Panels $process $components.Count 60
        # RAM's summary and CPU's thread rows arrive after the first update.
        Start-Sleep -Seconds $SettleSeconds
        $panels = Wait-Panels $process $components.Count 10
        Write-Output "--- $name, $WorkArea ($areaWidth x $areaHeight), scale $Scale"
        $panels.Values | Sort-Object X, Y | ForEach-Object { '{0,-12}{1}' -f $_.Panel, (Format-Place $_) } | Write-Output
        if ($name -eq 'fresh') {
            $opened = $panels
            Test-Apart $panels 'first placement'
            # Once loaded, Rainmeter has a section for each panel and keeps its place.
            Write-RunFile $commandPath 'UnloadAll()'
            $null = Wait-Panels $process 1 30
            Write-RunFile $commandPath 'LoadAll()'
            $null = Wait-Panels $process $components.Count 60
            Start-Sleep -Seconds $SettleSeconds
            $again = Wait-Panels $process $components.Count 10
            foreach ($key in $components.Keys) {
                if ($again[$key].X -ne $panels[$key].X -or $again[$key].Y -ne $panels[$key].Y) { $failures.Add("$key moved on its second load: $(Format-Place $panels[$key]) to $(Format-Place $again[$key])") }
            }
            # Rainmeter still records these places as formulas. With GPU closed,
            # Arrange must move the panels below it up, and Undo put them back.
            Write-RunFile $commandPath "Toggle('GPU')"
            $null = Wait-Panels $process ($components.Count - 1) 30
            Write-RunFile $commandPath 'Arrange()'
            Start-Sleep -Seconds 4
            $closed = Wait-Panels $process ($components.Count - 1) 10
            if ($closed['IO'].Y -ne 0 -or $closed['Chronometer'].Y -ne $closed['IO'].Bottom) { $failures.Add("Arrange without GPU left IO at $(Format-Place $closed['IO']) and Chronometer at $(Format-Place $closed['Chronometer'])") }
            Write-RunFile $commandPath 'Undo()'
            Start-Sleep -Seconds 4
            $undone = Wait-Panels $process ($components.Count - 1) 10
            foreach ($key in $undone.Keys) {
                if ($undone[$key].X -ne $again[$key].X -or $undone[$key].Y -ne $again[$key].Y) { $failures.Add("Undo left $key at $(Format-Place $undone[$key]), not $(Format-Place $again[$key])") }
            }
            Write-RunFile $commandPath 'Arrange()'
            Start-Sleep -Seconds 4
            Write-RunFile $commandPath 'UnloadAll()'
            $null = Wait-Panels $process 1 30
            Write-RunFile $commandPath 'LoadAll()'
            $null = Wait-Panels $process $components.Count 60
            $reloaded = Wait-Panels $process $components.Count 10
            foreach ($key in 'IO', 'Chronometer') {
                if ($reloaded[$key].X -ne $closed[$key].X -or $reloaded[$key].Y -ne $closed[$key].Y) { $failures.Add("$key did not keep its arranged place: $(Format-Place $closed[$key]) to $(Format-Place $reloaded[$key])") }
            }
        } elseif ($name -eq 'stacked') {
            foreach ($key in $components.Keys) {
                if ($panels[$key].X -ne 0 -or $panels[$key].Y -ne 0) { $failures.Add("$key was saved at 0,0 and opened at $(Format-Place $panels[$key])") }
            }
            if ($panels['IO'].H -le $opened['IO'].H -or $panels['Visualizer'].W -ge $opened['Visualizer'].W) { throw 'The stacked profile did not change the two sizes, so it checks nothing.' }
            Write-RunFile $commandPath 'Arrange()'
            Start-Sleep -Seconds 4
            $arranged = Wait-Panels $process $components.Count 10
            Write-Output "--- $name after Arrange"
            $arranged.Values | Sort-Object X, Y | ForEach-Object { '{0,-12}{1}' -f $_.Panel, (Format-Place $_) } | Write-Output
            Test-Apart $arranged 'after Arrange'
            Write-RunFile $commandPath 'Undo()'
            Start-Sleep -Seconds 4
            $undone = Wait-Panels $process $components.Count 10
            foreach ($key in $components.Keys) {
                if ($undone[$key].X -ne 0 -or $undone[$key].Y -ne 0) { $failures.Add("Undo left $key at $(Format-Place $undone[$key])") }
            }
            Write-RunFile $commandPath 'Arrange()'
            Start-Sleep -Seconds 4
            Write-RunFile $commandPath 'UnloadAll()'
            $null = Wait-Panels $process 1 30
            Write-RunFile $commandPath 'LoadAll()'
            $null = Wait-Panels $process $components.Count 60
            Start-Sleep -Seconds $SettleSeconds
            $again = Wait-Panels $process $components.Count 10
            foreach ($key in $components.Keys) {
                if ($again[$key].X -ne $arranged[$key].X -or $again[$key].Y -ne $arranged[$key].Y) { $failures.Add("$key did not keep its arranged place: $(Format-Place $arranged[$key]) to $(Format-Place $again[$key])") }
            }
        } else {
            $recorded = Get-Content -LiteralPath $iniPath -Raw
            foreach ($key in $components.Keys) {
                if ($saved.Contains($key)) {
                    $x, $y = $saved[$key]
                    if ($panels[$key].X -ne $x -or $panels[$key].Y -ne $y) { $failures.Add("$key was saved at $x,$y and opened at $($panels[$key].X),$($panels[$key].Y)") }
                    if ($recorded -notmatch "(?m)^\[Parallax\\$key\]\r?\n(?:(?!\[)[^\r\n]*\r?\n)*?WindowX=$x\r?\nWindowY=$y\r?$") { $failures.Add("${key}: the saved position was rewritten") }
                } elseif ($panels[$key].X -ne $opened[$key].X -or $panels[$key].Y -ne $opened[$key].Y) {
                    $failures.Add("$key opened at $(Format-Place $panels[$key]), not its first placement $(Format-Place $opened[$key])")
                }
            }
        }
        # Media runs without its two bundled plugins here, as in Run-WelcomeSmoke.ps1.
        $logPath = Join-Path $profileRoot 'Rainmeter.log'
        if (Test-Path -LiteralPath $logPath) {
            @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' -and $_ -notmatch 'WebNowPlaying|Chameleon' -and $_ -notmatch [regex]::Escape('Parallax\Media\Media.ini') }) |
                ForEach-Object { $failures.Add("${name}: $_") }
        }
    } finally {
        if ($null -ne $process) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
            $process.Dispose()
        }
        if (Test-Path -LiteralPath $commandPath) { Remove-Item -LiteralPath $commandPath -Force }
    }
}
if ($failures.Count) {
    $failures | ForEach-Object { Write-Output "FAIL: $_" }
    throw "Placement smoke failed. Evidence retained at $runRoot"
}
Write-Output 'PASS: first placements do not collide, saved positions (0,0 included) did not move, a second load kept every place, and Arrange and Undo moved a stack apart and back.'
Write-Output "Evidence retained at $runRoot"
