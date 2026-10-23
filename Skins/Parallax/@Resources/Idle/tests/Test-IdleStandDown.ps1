#requires -Version 5.1
# Developer-only native checks for the idle stand-down (Global Settings "Idle
# pause"; @Resources\Idle\Hook.inc and StandDown.lua). Each run is its own
# isolated Rainmeter instance (fresh absolute Rainmeter.ini and SkinPath under
# a short C:\pxc\<id> root) against a production copy of this checkout's skin.
# It never sends a command-line bang, never reads or writes %APPDATA%\Rainmeter
# or the live skin, and stops only the Rainmeter process it started. Input is
# simulated through the coordinator's test idle file; physical input is not
# exercised. Run under Windows PowerShell 5.1.
#
# Staging (copies only): User\Settings.inc IdlePauseMinutes=5,
# ParallaxIdleHookMs=2000 (the hook runs every 2 s), ParallaxIdleTestStaleSeconds=6
# and the layout (width/scale, fonts 12/10/10); Idle.ini tick 500 ms, test idle
# file, pause 4 s, away 4 s, heartbeat 4 ticks. The entrypoint gets
# DividerProbe.lua with a statically extracted list of every meter and every
# ParallaxIdlePause measure (tools/tests/test_idle_freeze_contract.py --list).
# A driver skin in the same instance carries out numbered commands.
#
# Per skin (-Skin), mode full:
#   enter    idle file 10: "Paused (idle)" shows within a coordinator tick plus
#            one skin tick; every meter resolves to UpdateDivider -1; every
#            paused measure's value stays constant for 3 s.
#   leave    idle file 0: the line hides within the same bound; every meter's
#            divider equals its pre-enter snapshot; measure values move again
#            (reported; a quiet machine can leave some unchanged).
#   restart  paused, then the skin reloads: it re-enters once synced.
#   watchdog paused, then the coordinator stops beating (its script paused by
#            the driver): the skin fails live within the staged 6 s stale limit
#            plus one 2 s hook period.
#   log      no error or warning in Rainmeter.log.
# Mode capture: live and paused window captures only (both default layouts).
# -Suite runs StandDownSuite.lua inside Rainmeter's own Lua.
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string[]]$Skin = @(),
    [ValidateSet('full', 'capture')][string]$Mode = 'full',
    [ValidateSet('w220-s1', 'w180-s0.75')][string[]]$Layout = @('w220-s1', 'w180-s0.75'),
    [switch]$Suite,
    [string]$OutDir = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$skinSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $skinSource '..\..'))
$toolsRoot = Join-Path $repoRoot 'tools'
Import-Module (Join-Path $toolsRoot 'Parallax.Build.psm1') -Force
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test installs nothing.' }
$encoding = [Text.UTF8Encoding]::new($false)
$invariant = [Globalization.CultureInfo]::InvariantCulture
$failures = 0
$checks = 0
function Check([bool]$Condition, [string]$Message) {
    $script:checks++
    if ($Condition) { Write-Output "ok   $Message" } else { $script:failures++; Write-Output "FAIL $Message" }
}

# Utility entrypoints this harness can run. Tick: the skin's own update in
# seconds (the paused line is observed by the probe on that tick). Extra: a
# module check run after the shared steps (later commits add them).
$skins = [ordered]@{}
function Register-Skin([string]$Key, [string]$Config, [string]$File, [double]$Tick, [scriptblock]$Extra = $null, [string]$Texts = '') {
    $script:skins[$Key] = [pscustomobject]@{ Key = $Key; Config = $Config; File = $File; Tick = $Tick; Extra = $Extra; Texts = $Texts
        Relative = ($Config.Substring('Parallax\'.Length) + '\' + $File).Replace('\', '/') }
}

# Resident PowerShell hosts started by this run's instance (created after it
# started, so the live profile's own hosts never count), by a marker in their
# command line. Read-only process listing.
function Get-RunHosts($Process, [string]$Marker) {
    $since = $Process.StartTime
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.Contains($Marker) -and $_.CreationDate -gt $since
    } | ForEach-Object { [pscustomobject]@{ Id = [int]$_.ProcessId; Created = $_.CreationDate } })
}
function Wait-Until([scriptblock]$Condition, [int]$Milliseconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt $Milliseconds) {
        if (& $Condition) { return $clock.ElapsedMilliseconds }
        Start-Sleep -Milliseconds 200
    }
    return -1
}
# A helper-backed module: its host stops while paused and a new one starts on
# resume; the watched meter shows a starting state, then a fresh reading.
function Test-HostCycle($Run, $Process, [string]$Label, [string]$Marker, [string]$Meter, [string]$StartingPattern, [string]$FreshPattern) {
    $before = @(Get-RunHosts $Process $Marker | Where-Object { -not (Get-Process -Id $_.Id -ErrorAction SilentlyContinue).HasExited })
    Check ($before.Count -ge 1) "${Label}: a host is running before the pause ($($before.Count))"
    $written = Send $Run 'idle 10'
    $enter = Wait-Hidden $Run '0' $written 15000
    Check ($null -ne $enter) "${Label}: paused"
    $gone = Wait-Until { @($before | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue }).Count -eq 0 } 15000
    Write-Output ("     {0}: host exited {1} ms after the pause" -f $Label, $gone)
    Check ($gone -ge 0 -and $gone -le 8000) "${Label}: the host exits within about 5 s of the pause"
    Start-Sleep -Seconds 2
    $stray = @(Get-RunHosts $Process $Marker | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
    Check ($stray.Count -eq 0) "${Label}: no host runs while paused"
    $resumedAt = Send $Run 'idle 0'
    $leave = Wait-Hidden $Run '1' $resumedAt 15000
    Check ($null -ne $leave) "${Label}: resumed"
    $fresh = Wait-Until { @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq 'T' -and $_.Clock -ge $resumedAt -and $_.Rest[0] -eq $Meter -and $_.Rest[1] -match $FreshPattern }).Count -gt 0 } 30000
    $texts = @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq 'T' -and $_.Clock -ge $resumedAt -and $_.Rest[0] -eq $Meter })
    Write-Output ("     {0}: after resume {1}: {2}" -f $Label, $Meter, (($texts | ForEach-Object { '{0:N1}s {1}' -f ($_.Clock - $resumedAt), $_.Rest[1] }) -join ' -> '))
    Check ($texts.Count -ge 1 -and $texts[0].Rest[1] -match $StartingPattern) "${Label}: the first resumed reading is a starting state, not the frozen value"
    Check ($fresh -ge 0) "${Label}: a fresh reading follows within 30 s"
    $after = @(Get-RunHosts $Process $Marker | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
    Check ($after.Count -eq 1 -and @($after | Where-Object { $_.Id -in @($before | ForEach-Object Id) }).Count -eq 0) "${Label}: exactly one new host after the resume"
}

Register-Skin 'Chronometer' 'Parallax\Chronometer' 'Chronometer.ini' 1.0
Register-Skin 'RAM' 'Parallax\RAM' 'RAM.ini' 1.0 {
    param($Run, $Process)
    Test-HostCycle $Run $Process 'RAM page-file host' 'ParallaxRamPageFile' 'MeterRAMPageGiB' '^Checking' 'GB$'
} 'MeterRAMPageGiB'
Register-Skin 'GPU' 'Parallax\GPU' 'GPU.ini' 1.0 {
    param($Run, $Process)
    # Readings come from the resident driver host; on a machine without one
    # discrete GPU it runs for process names only and the temperature stays
    # Unavailable, which this check then reports as its fresh state.
    Test-HostCycle $Run $Process 'GPU telemetry host' 'ParallaxGpuTemperature' 'MeterTemperatureValue' '^Checking' '(C|Unavailable|Unsupported)$'
} 'MeterTemperatureValue|MeterActivityValue'
Register-Skin 'CPU' 'Parallax\CPU' 'CPU.ini' 1.0

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxStandDownNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxStandDownNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width, Height; }
    private delegate bool Callback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static Window[] Of(uint pid) {
        var found = new List<Window>();
        EnumWindows((hwnd, data) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(hwnd, title, title.Capacity);
            RECT rect; GetWindowRect(hwnd, out rect);
            found.Add(new Window { Handle = hwnd, Title = title.ToString(), Width = rect.Right - rect.Left, Height = rect.Bottom - rect.Top });
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@
}

$driverLua = @'
-- Test driver: executes numbered commands from cmd.txt in this isolated
-- instance and records each with os.clock() in driver.log.
local seen, cmdPath, logPath, idlePath
local function log(text)
    local file = assert(io.open(logPath, 'ab'))
    file:write(string.format('%.3f|%s\n', os.clock(), text))
    file:close()
end
function Initialize()
    seen = 0
    cmdPath = SKIN:GetVariable('CommandFile')
    logPath = SKIN:GetVariable('DriverLog')
    idlePath = SKIN:GetVariable('IdleFile')
end
function Update()
    local file = io.open(cmdPath, 'rb')
    if not file then return 0 end
    local text = file:read('*a') or ''
    file:close()
    local seq, command, argument, extra = text:match('^(%d+) (%S+) ?(%S*) ?(%S*)')
    seq = tonumber(seq)
    if not seq or seq <= seen then return 0 end
    seen = seq
    -- Logged before acting: a command can end in a synchronous reload.
    log(seq .. '|' .. command .. '|' .. argument)
    if command == 'idle' then
        local idle = assert(io.open(idlePath, 'wb')); idle:write(argument); idle:close()
    elseif command == 'hang' then
        -- A coordinator that neither beats nor answers a sync request.
        SKIN:Bang('!PauseMeasure', 'MeasureParallaxIdle', 'Parallax\\Idle')
        SKIN:Bang('!PauseMeasure', 'MeasureParallaxIdleSyncRequest', 'Parallax\\Idle')
    elseif command == 'unhang' then
        SKIN:Bang('!UnpauseMeasure', 'MeasureParallaxIdleSyncRequest', 'Parallax\\Idle')
        SKIN:Bang('!UnpauseMeasure', 'MeasureParallaxIdle', 'Parallax\\Idle')
    elseif command == 'unload' then
        SKIN:Bang('!DeactivateConfig', 'Parallax\\Idle')
    elseif command == 'refresh' then
        SKIN:Bang('!Refresh', argument)
    elseif command == 'snap' then
        SKIN:Bang('!CommandMeasure', 'MeasureParallaxDividerProbe', "Snapshot('" .. extra .. "')", argument)
    elseif command == 'quit' then
        SKIN:Bang('!Quit')
    end
    return seq
end
'@

$suiteLua = @'
-- Runs StandDownSuite.lua inside Rainmeter's own Lua, writes the report, quits.
local done = false
function Initialize() end
function Update()
    if done then return 0 end
    done = true
    local ok, report = pcall(function()
        local suite = dofile(SKIN:GetVariable('SuitePath'))
        return suite.Run(SKIN:GetVariable('@') .. 'Idle\\StandDown.lua', SKIN:GetVariable('@') .. 'Idle\\Link.lua')
    end)
    local file = assert(io.open(SKIN:GetVariable('SuiteReport'), 'wb'))
    file:write(ok and report or ('FAIL: ' .. tostring(report)))
    file:close()
    SKIN:Bang('!Quit')
    return 1
end
'@

function New-Root {
    $root = 'C:\pxc\' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    if (Test-Path -LiteralPath $root) { throw 'Run root must be fresh.' }
    foreach ($directory in @($root, "$root\Skins", "$root\Layouts", "$root\Plugins", "$root\Addons")) { $null = New-Item -ItemType Directory -Path $directory }
    return $root
}
function Put([string]$Root, [string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the run root.' }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}
function Set-Key([string]$Path, [string]$Key, [string]$Value) {
    $text = [IO.File]::ReadAllText($Path)
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=[^\r\n]*'
    $count = [regex]::Matches($text, $pattern).Count
    if ($count -eq 1) { $text = [regex]::Replace($text, $pattern, ($Key + '=' + $Value).Replace('$', '$$')) }
    elseif ($count -eq 0) { $text = $text.TrimEnd() + "`r`n$Key=$Value`r`n" }
    else { throw "More than one $Key in $Path." }
    [IO.File]::WriteAllText($Path, $text, $encoding)
}
function Copy-Skin([string]$Root) {
    $target = Join-Path $Root 'Skins\Parallax'
    foreach ($file in Get-ParallaxFiles $skinSource -ProductionOnly) {
        $destination = Join-Path $target (Get-ParallaxRelativePath $file.FullName $skinSource)
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    return $target
}
function Get-ActiveIndex([string]$Folder, [string]$File) {
    $names = @(Get-ChildItem -LiteralPath $Folder -Filter '*.ini' -File | Sort-Object Name | ForEach-Object Name)
    return [array]::IndexOf([string[]]$names, $File) + 1
}
function Write-Settings([string]$Root, [object[]]$Configs) {
    $ini = "[Rainmeter]`nSkinPath=$Root\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $x = -30000
    foreach ($config in $Configs) {
        $ini += "`n[$($config.Name)]`nActive=$($config.Active)`nWindowX=$x`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
        $x += 1000
    }
    Put $Root "$Root\Rainmeter.ini" $ini
    Put $Root "$Root\Rainmeter.data" "[Rainmeter]`n"
}
function Start-Run([string]$Root) {
    Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f "$Root\Rainmeter.ini") -WorkingDirectory $Root -WindowStyle Hidden -PassThru
}
function Stop-Run($Process) {
    if ($null -eq $Process) { return }
    $Process.Refresh()
    if (-not $Process.HasExited) { Stop-Process -InputObject $Process -Force; $null = $Process.WaitForExit(5000) }
}
function Get-LogIssues([string]$Root) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return @('no Rainmeter.log') }
    @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^(ERRO|WARN)' })
}
function Get-DisplayEvents([string]$Root) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return 0 }
    try { @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'System: (Display settings|Work area) changed' }).Count } catch { 0 }
}
function Save-Capture($Window, [string]$Path) {
    $bitmap = [Drawing.Bitmap]::new($Window.Width, $Window.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxStandDownNative]::PrintWindow($Window.Handle, $hdc, 2)
        $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
        if (-not $printed) { throw 'PrintWindow failed.' }
    } finally {
        if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
        $graphics.Dispose()
    }
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}
# Probe records (DividerProbe.lua), read with sharing so Rainmeter can append.
function Read-Probe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        try { $text = [IO.StreamReader]::new($stream).ReadToEnd() } finally { $stream.Dispose() }
    } catch { return @() }
    @($text -split "`n" | Where-Object { $_ -match '^\w\|' } | ForEach-Object {
        $part = $_.TrimEnd("`r").Split('|')
        [pscustomobject]@{ Kind = $part[0]; Clock = [double]::Parse($part[1], $invariant); Rest = @($part | Select-Object -Skip 2) }
    })
}
function Read-Driver([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @(Get-Content -LiteralPath $Path | ForEach-Object {
        $part = $_.Split('|')
        [pscustomobject]@{ Clock = [double]::Parse($part[0], $invariant); Seq = [int]$part[1]; Command = $part[2]; Argument = if ($part.Count -gt 3) { $part[3] } else { '' } }
    })
}
function Get-Snapshot($Records, [string]$Tag, [double]$After = -1) {
    $selected = @($Records | Where-Object { $_.Kind -eq 'S' -and $_.Rest[0] -eq $Tag -and $_.Clock -ge $After })
    if (-not $selected.Count) { return $null }
    $first = $selected[0].Clock
    $map = [ordered]@{}
    foreach ($record in $selected) { if ([math]::Abs($record.Clock - $first) -lt 0.5 -and -not $map.Contains($record.Rest[1])) { $map[$record.Rest[1]] = $record.Rest[2] } }
    return [pscustomobject]@{ Clock = $first; Dividers = $map }
}

# One staged instance: the target skin, the coordinator (started by the join)
# and the driver.
function New-StandDownRun($Entry, [string]$LayoutName) {
    $root = New-Root
    $target = Copy-Skin $root
    $settings = Join-Path $target '@Resources\User\Settings.inc'
    $width, $scale = switch ($LayoutName) { 'w220-s1' { '220', '1' } 'w180-s0.75' { '180', '0.75' } }
    foreach ($pair in @(@('IdlePauseMinutes', '5'), @('ParallaxIdleHookMs', '2000'), @('ParallaxIdleTestStaleSeconds', '6'),
            @('Scale', $scale), @('ColumnWidth', $width), @('TitleFontSize', '12'), @('HeaderFontSize', '10'), @('FontSize', '10'))) {
        Set-Key $settings $pair[0] $pair[1]
    }
    $idleIni = Join-Path $target 'Idle\Idle.ini'
    Set-Key $idleIni 'ParallaxIdleTick' '500'
    Set-Key $idleIni 'ParallaxIdleTestFile' "$root\idle.txt"
    Set-Key $idleIni 'ParallaxIdleTestPauseSeconds' '4'
    Set-Key $idleIni 'ParallaxIdleTestAwaySeconds' '4'
    Set-Key $idleIni 'ParallaxIdleTestHeartbeatTicks' '4'
    $lists = & python (Join-Path $toolsRoot 'tests\test_idle_freeze_contract.py') --list $Entry.Relative "$root\meters.txt" "$root\measures.txt" 'IdlePauseMinutes=5' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Static list failed: $lists" }
    Write-Host "     $lists"
    $entryPath = Join-Path $target ($Entry.Config.Substring('Parallax\'.Length) + '\' + $Entry.File)
    $default = '1'
    $entryText = [IO.File]::ReadAllText($entryPath)
    $match = [regex]::Match($entryText, '(?m)^DefaultUpdateDivider=([^\r\n]*)')
    if ($match.Success) { $default = $match.Groups[1].Value }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DividerProbe.lua') -Destination "$root\DividerProbe.lua"
    $entryText = $entryText.TrimEnd() + "`r`n`r`n[MeasureParallaxDividerProbe]`r`nMeasure=Script`r`nScriptFile=$root\DividerProbe.lua`r`nUpdateDivider=1`r`nProbeMeters=$root\meters.txt`r`nProbeMeasures=$root\measures.txt`r`nProbeLog=$root\probe.log`r`nProbeDefault=$default`r`nProbeTexts=$($Entry.Texts)`r`n"
    [IO.File]::WriteAllText($entryPath, $entryText, $encoding)
    Put $root "$root\idle.txt" '0'
    Put $root "$root\Driver.lua" $driverLua
    Put $root "$target\ADriver\Driver.ini" "[Rainmeter]`r`nUpdate=100`r`n`r`n[Variables]`r`nCommandFile=$root\cmd.txt`r`nDriverLog=$root\driver.log`r`nIdleFile=$root\idle.txt`r`n`r`n[MeasureDriver]`r`nMeasure=Script`r`nScriptFile=$root\Driver.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`nUpdateDivider=-1`r`n"
    $folder = Split-Path -Parent $entryPath
    Write-Settings $root @([pscustomobject]@{ Name = $Entry.Config; Active = (Get-ActiveIndex $folder $Entry.File) }, [pscustomobject]@{ Name = 'Parallax\ADriver'; Active = 1 })
    return [pscustomobject]@{ Root = $root; Target = $target; Probe = "$root\probe.log"; Driver = "$root\driver.log"; Entry = $Entry; Layout = $LayoutName; Sequence = 0 }
}
function Send($Run, [string]$Command) {
    $Run.Sequence++
    [IO.File]::WriteAllText("$($Run.Root)\cmd.txt", "$($Run.Sequence) $Command", $encoding)
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt 5000) {
        $record = @(Read-Driver $Run.Driver | Where-Object { $_.Seq -eq $Run.Sequence })
        if ($record.Count) { return $record[0].Clock }
        Start-Sleep -Milliseconds 50
    }
    throw "The driver did not run command $($Run.Sequence) ($Command)."
}
# The first H (paused-line) record with this value after a clock, or $null.
function Wait-Hidden($Run, [string]$Value, [double]$After, [int]$Milliseconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt $Milliseconds) {
        $record = @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq 'H' -and $_.Rest[0] -eq $Value -and $_.Clock -ge $After } | Select-Object -First 1)
        if ($record.Count) { return $record[0] }
        Start-Sleep -Milliseconds 100
    }
    return $null
}
function Wait-Record($Run, [string]$Kind, [double]$After, [int]$Milliseconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt $Milliseconds) {
        $record = @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq $Kind -and $_.Clock -ge $After } | Select-Object -First 1)
        if ($record.Count) { return $record[0] }
        Start-Sleep -Milliseconds 100
    }
    return $null
}
function Find-Window($Process, [string]$Config) {
    @([ParallaxStandDownNative]::Of([uint32]$Process.Id) | Where-Object { $_.Title -eq $Config -or $_.Title -like "$Config *" -or $_.Title -like "*\$($Config.Split('\')[-1])\*.ini*" -or $_.Title -like "$Config\*" })
}
function Capture($Run, $Process, [string]$Label) {
    if (-not $OutDir) { return }
    $window = @(Find-Window $Process $Run.Entry.Config)
    if ($window.Count -lt 1) { Write-Output "     (no window for $($Run.Entry.Config) to capture)"; return }
    $null = New-Item -ItemType Directory -Path $OutDir -Force
    $path = Join-Path $OutDir ("{0}-{1}-{2}.png" -f $Run.Entry.Key, $Run.Layout, $Label)
    Save-Capture $window[0] $path
    Write-Output "     capture: $path ($($window[0].Width)x$($window[0].Height))"
}

function Invoke-StandDown($Entry, [string]$LayoutName, [bool]$Full) {
    Write-Output "--- $($Entry.Key) $LayoutName ($(if ($Full) { 'full' } else { 'capture' }))"
    $run = New-StandDownRun $Entry $LayoutName
    $process = $null
    $bound = 0.5 + $Entry.Tick + 0.4
    try {
        $process = Start-Run $run.Root
        $sync = Wait-Record $run 'Y' 0 90000
        Check ($null -ne $sync) "$($Entry.Key): the hook joined and synced"
        if ($null -eq $sync) { return }
        Start-Sleep -Seconds 3
        $null = Send $run "snap $($Entry.Config) baseline"
        Start-Sleep -Milliseconds 600
        $baseline = Get-Snapshot (Read-Probe $run.Probe) 'baseline'
        Check ($null -ne $baseline -and $baseline.Dividers.Count -gt 0) "$($Entry.Key): baseline snapshot of $(if ($baseline) { $baseline.Dividers.Count } else { 0 }) meters"
        Capture $run $process 'live'

        $written = Send $run 'idle 10'
        $enter = Wait-Hidden $run '0' $written 15000
        $latency = if ($enter) { $enter.Clock - $written } else { [double]::NaN }
        Write-Output ("     enter: paused line shown {0:N3} s after the idle write (bound {1:N1} s)" -f $latency, $bound)
        Check ($null -ne $enter -and $latency -le $bound) "$($Entry.Key): enter within a coordinator tick plus one skin tick"
        if ($null -eq $enter) { return }
        $records = Read-Probe $run.Probe
        $snapshot = Get-Snapshot $records 'enter' $enter.Clock
        $notFrozen = @($snapshot.Dividers.Keys | Where-Object { $snapshot.Dividers[$_] -ne '-1' })
        Check ($notFrozen.Count -eq 0) "$($Entry.Key): every meter resolves to UpdateDivider -1 while paused ($($snapshot.Dividers.Count) meters$(if ($notFrozen.Count) { '; not frozen: ' + (($notFrozen | Select-Object -First 8) -join ', ') }))"
        Start-Sleep -Milliseconds 3800
        if ($Full) {
            $window = @(Read-Probe $run.Probe | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $enter.Clock + 0.5 -and $_.Clock -le $enter.Clock + 3.5 })
            $moved = @($window | Where-Object { [int]$_.Rest[2] -ne 0 })
            $digests = @($window | ForEach-Object { $_.Rest[1] } | Select-Object -Unique)
            Check ($window.Count -ge 2 -and $moved.Count -eq 0 -and $digests.Count -eq 1) "$($Entry.Key): paused measure values stay constant for 3 s ($($window.Count) ticks, $($digests.Count) distinct digest)"
        }
        Capture $run $process 'paused'

        $written = Send $run 'idle 0'
        $leave = Wait-Hidden $run '1' $written 15000
        $latency = if ($leave) { $leave.Clock - $written } else { [double]::NaN }
        Write-Output ("     leave: paused line hidden {0:N3} s after the idle write" -f $latency)
        Check ($null -ne $leave -and $latency -le $bound) "$($Entry.Key): leave within a coordinator tick plus one skin tick"
        if ($null -eq $leave) { return }
        $after = Get-Snapshot (Read-Probe $run.Probe) 'live' $leave.Clock
        $differ = @($baseline.Dividers.Keys | Where-Object { $after.Dividers[$_] -ne $baseline.Dividers[$_] })
        Check ($differ.Count -eq 0) "$($Entry.Key): every meter's divider equals its pre-enter snapshot after leave$(if ($differ.Count) { '; differ: ' + (($differ | Select-Object -First 8 | ForEach-Object { "$_ $($baseline.Dividers[$_])->$($after.Dividers[$_])" }) -join ', ') })"
        if (-not $Full) { return }
        Start-Sleep -Seconds 3
        $resumed = @(Read-Probe $run.Probe | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $leave.Clock -and [int]$_.Rest[2] -gt 0 })
        Write-Output "     after leave: $($resumed.Count) ticks with changed measure values in 3 s"
        Check ($resumed.Count -gt 0) "$($Entry.Key): measure values move again after leave"
        Capture $run $process 'resumed'

        # Restart while paused: the reload starts live, joins, and re-enters.
        $written = Send $run 'idle 10'
        $enter = Wait-Hidden $run '0' $written 15000
        Check ($null -ne $enter) "$($Entry.Key): paused again before the restart"
        $reloaded = Send $run "refresh $($Entry.Config)"
        $load = Wait-Record $run 'L' $reloaded 15000
        $again = if ($load) { Wait-Hidden $run '0' $load.Clock 20000 } else { $null }
        Write-Output ("     restart while paused: re-entered {0:N3} s after the reload" -f $(if ($again) { $again.Clock - $load.Clock } else { [double]::NaN }))
        Check ($null -ne $again) "$($Entry.Key): a reload while paused re-enters once synced"

        # Watchdog: the coordinator stops beating; fail live after 6 s + 2 s.
        $hung = Send $run 'hang'
        $live = Wait-Hidden $run '1' $hung 30000
        $after = if ($live) { $live.Clock - $hung } else { [double]::NaN }
        Write-Output ("     watchdog: failed live {0:N3} s after the coordinator stopped beating (bound 6 s stale + 2 s hook + {1:N1} s)" -f $after, $Entry.Tick)
        Check ($null -ne $live -and $after -le 6 + 2 + $Entry.Tick + 1.5) "$($Entry.Key): with no beat the skin fails live within the stale limit plus one hook period"
        $null = Send $run 'idle 0'
        $null = Send $run 'unhang'
        Start-Sleep -Seconds 2

        if ($Entry.Extra) { & $Entry.Extra $run $process }
    } finally {
        if ($null -ne $process) {
            try { $null = Send $run 'quit' } catch { }
            if (-not $process.WaitForExit(10000)) { Stop-Run $process }
        }
        $display = Get-DisplayEvents $run.Root
        if ($display) { Write-Output "     note: Windows reported $display display/work-area change(s); Rainmeter's timers can stall then." }
        $issues = @(Get-LogIssues $run.Root)
        $issues | Select-Object -First 12 | ForEach-Object { Write-Output "     log: $_" }
        Check ($issues.Count -eq 0) "$($Entry.Key) $LayoutName`: Rainmeter logged no error or warning"
        Write-Output "     evidence: $($run.Root)"
    }
}

if ($Suite) {
    Write-Output '--- StandDownSuite inside Rainmeter'
    $root = New-Root
    $target = Copy-Skin $root
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'StandDownSuite.lua') -Destination "$root\StandDownSuite.lua"
    Put $root "$root\Suite.lua" $suiteLua
    Put $root "$target\ASuite\Suite.ini" "[Rainmeter]`r`nUpdate=100`r`n`r`n[Variables]`r`nSuitePath=$root\StandDownSuite.lua`r`nSuiteReport=$root\suite.txt`r`n`r`n[MeasureSuite]`r`nMeasure=Script`r`nScriptFile=$root\Suite.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`nUpdateDivider=-1`r`n"
    Write-Settings $root @([pscustomobject]@{ Name = 'Parallax\ASuite'; Active = 1 })
    $process = Start-Run $root
    try {
        Check ($process.WaitForExit(60000)) 'The suite run finished'
    } finally { Stop-Run $process }
    $report = if (Test-Path -LiteralPath "$root\suite.txt") { [IO.File]::ReadAllText("$root\suite.txt") } else { 'FAIL: no report' }
    Write-Output (($report -split "`n")[0])
    Check ($report -match '^PASS:') 'StandDownSuite.lua passes inside Rainmeter''s own Lua'
    $issues = @(Get-LogIssues $root)
    $issues | ForEach-Object { Write-Output "     log: $_" }
    Check ($issues.Count -eq 0) 'Rainmeter logged no error or warning'
}

foreach ($key in $Skin) {
    if (-not $skins.Contains($key)) { throw "Unknown skin '$key'. Registered: $(@($skins.Keys) -join ', ')" }
    $entry = $skins[$key]
    $first = $true
    foreach ($layoutName in $Layout) {
        Invoke-StandDown $entry $layoutName ($Mode -eq 'full' -and $first)
        $first = $false
    }
}
Write-Output "$checks checks, $failures failures."
if ($failures) { throw 'Idle stand-down native checks failed.' }
