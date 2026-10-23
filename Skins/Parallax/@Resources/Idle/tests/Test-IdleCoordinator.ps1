#requires -Version 5.1
# Developer-only native checks for the Parallax\Idle coordinator. Each case runs
# its own isolated Rainmeter instance (fresh absolute Rainmeter.ini and SkinPath
# under a short C:\pxc\<id> root) against copies of Idle.ini, Coordinator.lua,
# Link.lua and the shared includes, with test hooks set in the copies only. It
# never sends a command-line bang, never reads or writes %APPDATA%\Rainmeter or
# the live skin, and stops only the Rainmeter process it started. The idle
# signal comes from a test file the witness skin writes, not physical input.
#
# Cases:
#   transitions      tick 500 ms, away 5 s, heartbeat 6 ticks; idle 0 -> 10 -> 0.
#                    A witness hook skin joins (first activation, defaults
#                    apply), sees away 0 -> 1 -> 0 within a tick of each write
#                    and heartbeat beats in between; the coordinator window is
#                    hidden or a transparent pixel. Also runs CoordinatorSuite.lua
#                    inside Rainmeter's own Lua.
#   startup-active   Rainmeter.ini has Parallax\Idle Active=1 and the witness
#                    loads first in folder order: delayed join, 0 warnings.
#   startup-inactive Parallax\Idle Active=0, witness first: the join activates
#                    the coordinator, 0 warnings.
#   no-consumer      Parallax\Idle alone with a 4-tick re-evaluation: it unloads
#                    itself (Active=0 recorded) with no error.
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet('transitions', 'startup-active', 'startup-inactive', 'no-consumer')]
    [string[]]$Case = @('transitions', 'startup-active', 'startup-inactive', 'no-consumer')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$skinSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$resources = Join-Path $skinSource '@Resources'
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test installs nothing.' }
foreach ($required in @("$skinSource\Idle\Idle.ini", "$resources\Idle\Coordinator.lua", "$resources\Idle\Link.lua", "$PSScriptRoot\CoordinatorSuite.lua")) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing source: $required" }
}
$encoding = [Text.UTF8Encoding]::new($false)
$failures = 0
$checks = 0
function Check([bool]$Condition, [string]$Message) {
    $script:checks++
    if ($Condition) { Write-Output "ok   $Message" } else { $script:failures++; Write-Output "FAIL $Message" }
}

if (-not ('ParallaxIdleWindows' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxIdleWindows {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public string Title; public bool Visible; public int Width, Height; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    public static Window[] Of(uint pid) {
        var found = new List<Window>();
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(512); GetWindowText(hwnd, title, title.Capacity);
            RECT rect; GetWindowRect(hwnd, out rect);
            found.Add(new Window { Title = title.ToString(), Visible = IsWindowVisible(hwnd), Width = rect.Right - rect.Left, Height = rect.Bottom - rect.Top });
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@
}

$witnessLua = @'
-- Witness: a ParallaxIdleHook / ParallaxIdleJoin consumer that records every
-- update it receives. It joins with the production Link.lua, once, as the last
-- statement of an unsynced update after the load's own first update (during
-- Rainmeter's startup walk an activation would be repeated by the walk); a
-- nested update during that join is logged.
local link, logPath, joined, busy, updates
local function v(name) return SKIN:GetVariable(name, '?') end
local function write(reason)
    local file = assert(io.open(logPath, 'ab'))
    file:write(string.format('%.3f|%s|%s|%s|%s|%s\n', os.clock(), reason, v('ParallaxIdleSync'), v('ParallaxIdleAway'), v('ParallaxIdlePaused'), v('ParallaxIdleBeat')))
    file:close()
end
function Initialize()
    logPath = SKIN:GetVariable('WitnessLog')
    link = dofile(SKIN:GetVariable('@') .. 'Idle\\Link.lua').new(SKIN)
    joined, busy, updates = false, false, 0
    write('load')
end
function Update()
    if busy then write('nested'); return 0 end
    busy = true
    updates = updates + 1
    write('update')
    if v('ParallaxIdleSync') ~= '1' and not joined and updates > 1 then
        joined = true
        write(link.join() and 'joined' or 'join-refused')
    end
    busy = false
    return 0
end
'@

$driverLua = @'
-- Driver: writes the idle test file on a schedule (transitions) or waits for
-- the witness to sync (startup cases), records os.clock() for each step in the
-- witness log and ends the isolated instance.
local mode, idlePath, logPath, donePath, start, stage, syncedAt
local function note(text)
    local file = assert(io.open(logPath, 'ab'))
    file:write(string.format('%.3f|%s\n', os.clock(), text))
    file:close()
end
local function setIdle(value)
    local file = assert(io.open(idlePath, 'wb'))
    file:write(value)
    file:close()
    note('write|' .. value)
end
local function finish(text)
    local file = assert(io.open(donePath, 'wb'))
    file:write(text)
    file:close()
    SKIN:Bang('!Quit')
end
function Initialize()
    mode = SKIN:GetVariable('DriverMode')
    idlePath = SKIN:GetVariable('IdleFile')
    logPath = SKIN:GetVariable('WitnessLog')
    donePath = SKIN:GetVariable('DoneFile')
    start, stage, syncedAt = nil, 0, nil
end
function Update()
    local now = os.clock()
    if not start then
        start = now
        if mode == 'transitions' then
            local ok, report = pcall(function()
                local suite = dofile(SKIN:GetVariable('SuitePath'))
                return suite.Run(SKIN:GetVariable('@') .. 'Idle\\Coordinator.lua', SKIN:GetVariable('@') .. 'Idle\\Link.lua')
            end)
            local file = assert(io.open(SKIN:GetVariable('SuiteReport'), 'wb'))
            file:write(ok and report or ('FAIL: ' .. tostring(report)))
            file:close()
            setIdle('0')
        end
        return 0
    end
    local t = now - start
    if mode == 'transitions' then
        if stage == 0 and t >= 4 then setIdle('10'); stage = 1
        elseif stage == 1 and t >= 10 then setIdle('0'); stage = 2
        elseif stage == 2 and t >= 16 then finish('done') end
    else
        if not syncedAt and SKIN:GetVariable('ParallaxIdleSync', '0') == '1' then syncedAt = now; note('synced') end
        if (syncedAt and now - syncedAt >= 2) or t >= 10 then finish(syncedAt and 'synced' or 'timeout') end
    end
    return 0
end
'@

function New-Run([string]$Name, [hashtable]$Hooks, [bool]$Witness, [string]$IdleSection) {
    $root = 'C:\pxc\' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    if (Test-Path -LiteralPath $root) { throw 'Run root must be fresh.' }
    $skins = Join-Path $root 'Skins'
    $parallax = Join-Path $skins 'Parallax'
    foreach ($directory in @($root, $skins, "$parallax\Idle", "$parallax\@Resources\Idle", "$parallax\@Resources\User", "$root\Layouts", "$root\Plugins", "$root\Addons")) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }
    function Put([string]$Path, [string]$Text) {
        if (-not [IO.Path]::GetFullPath($Path).StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the run root.' }
        [IO.File]::WriteAllText($Path, $Text, $encoding)
    }
    Copy-Item -LiteralPath "$resources\Idle\Coordinator.lua", "$resources\Idle\Link.lua" -Destination "$parallax\@Resources\Idle"
    Copy-Item -LiteralPath "$resources\Defaults.inc" -Destination "$parallax\@Resources"
    Copy-Item -LiteralPath "$resources\User\Settings.inc", "$resources\User\Media.inc" -Destination "$parallax\@Resources\User"
    $idle = [IO.File]::ReadAllText("$skinSource\Idle\Idle.ini")
    foreach ($key in $Hooks.Keys) {
        $pattern = '(?m)^' + [regex]::Escape($key) + '=[^\r\n]*'
        if ([regex]::Matches($idle, $pattern).Count -ne 1) { throw "Idle.ini has no single $key line to set." }
        $value = ([string]$Hooks[$key]).Replace('{root}', $root)
        $idle = [regex]::Replace($idle, $pattern, ($key + '=' + $value).Replace('$', '$$'))
    }
    Put "$parallax\Idle\Idle.ini" $idle
    $ini = "[Rainmeter]`nSkinPath=$skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    if ($Witness) {
        $null = New-Item -ItemType Directory -Path "$parallax\AWitness" -Force
        Put "$root\Witness.lua" $witnessLua
        Put "$root\Driver.lua" $driverLua
        $mode = if ($Name -eq 'transitions') { 'transitions' } else { 'startup' }
        Put "$parallax\AWitness\Witness.ini" @"
[Rainmeter]
Update=100
Group=Parallax
OnRefreshAction=[!Delay 100][!UpdateMeasureGroup ParallaxIdleJoin]

[Metadata]
Name=Idle witness (test only)

[Variables]
ParallaxIdleAway=0
ParallaxIdlePaused=0
ParallaxIdleSync=0
ParallaxIdleBeat=0
WitnessLog=$root\witness.log
IdleFile=$root\idle.txt
DoneFile=$root\done.txt
DriverMode=$mode
SuitePath=$PSScriptRoot\CoordinatorSuite.lua
SuiteReport=$root\suite.txt

[MeasureWitness]
Measure=Script
ScriptFile=$root\Witness.lua
Group=ParallaxIdleHook | ParallaxIdleJoin
UpdateDivider=-1

[MeasureDriver]
Measure=Script
ScriptFile=$root\Driver.lua

[MeterBounds]
Meter=Image
W=1
H=1
SolidColor=0,0,0,1
UpdateDivider=-1
"@
        $ini += "`n[Parallax\AWitness]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nClickThrough=1`nDraggable=0`n"
    }
    if ($IdleSection) { $ini += "`n[Parallax\Idle]`n$IdleSection`n" }
    Put "$root\Rainmeter.ini" $ini
    Put "$root\Rainmeter.data" "[Rainmeter]`n"
    Put "$root\idle.txt" '0'
    return [pscustomobject]@{ Name = $Name; Root = $root; Ini = "$root\Rainmeter.ini"; Log = "$root\Rainmeter.log"; Witness = "$root\witness.log"; Done = "$root\done.txt" }
}

function Start-Run($Run) {
    Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $Run.Ini) -WorkingDirectory $Run.Root -WindowStyle Hidden -PassThru
}
function Stop-Run($Process) {
    if ($null -eq $Process) { return }
    $Process.Refresh()
    if (-not $Process.HasExited) { Stop-Process -InputObject $Process -Force; $null = $Process.WaitForExit(5000) }
}
function Get-LogIssues($Run) {
    if (-not (Test-Path -LiteralPath $Run.Log)) { return @('no Rainmeter.log') }
    @(Get-Content -LiteralPath $Run.Log | Where-Object { $_ -match '^(ERRO|WARN)' })
}
function Read-Witness($Run) {
    if (-not (Test-Path -LiteralPath $Run.Witness)) { return @() }
    @(Get-Content -LiteralPath $Run.Witness | ForEach-Object {
        $part = $_.Split('|')
        [pscustomobject]@{ Clock = [double]::Parse($part[0], [Globalization.CultureInfo]::InvariantCulture); Kind = $part[1]
            Sync = if ($part.Count -gt 2) { $part[2] } else { '' }; Away = if ($part.Count -gt 3) { $part[3] } else { '' }
            Paused = if ($part.Count -gt 4) { $part[4] } else { '' }; Beat = if ($part.Count -gt 5) { $part[5] } else { '' } }
    })
}
function Get-IdleActive([string]$IniPath) {
    $section = $null
    foreach ($line in Get-Content -LiteralPath $IniPath) {
        if ($line -match '^\s*\[(.+)\]\s*$') { $section = $Matches[1]; continue }
        if ($section -eq 'Parallax\Idle' -and $line -match '^\s*Active\s*=\s*(\d+)') { return [int]$Matches[1] }
    }
    return $null
}

$hooks = @{ ParallaxIdleTick = '500'; ParallaxIdleTestAwaySeconds = '5'; ParallaxIdleTestHeartbeatTicks = '6' }
$settled = "StartHidden=1`nClickThrough=1`nDraggable=0`nKeepOnScreen=0`nWindowX=0`nWindowY=0"
foreach ($name in $Case) {
    Write-Output "--- $name"
    $process = $null
    try {
        switch ($name) {
            'transitions' {
                $caseHooks = $hooks.Clone()
                $caseHooks.ParallaxIdleTestFile = '{root}\idle.txt'
                $run = New-Run $name $caseHooks $true ''
                $idle = [IO.File]::ReadAllText("$($run.Root)\Skins\Parallax\Idle\Idle.ini")
                Check ($idle -match ('(?m)^ParallaxIdleTestFile=' + [regex]::Escape("$($run.Root)\idle.txt") + '\r?$')) 'Staged Idle.ini reads the test idle file'
                $process = Start-Run $run
                $windows = [Collections.Generic.List[object]]::new()
                $clock = [Diagnostics.Stopwatch]::StartNew()
                while (-not $process.HasExited -and $clock.ElapsedMilliseconds -lt 45000) {
                    foreach ($window in [ParallaxIdleWindows]::Of([uint32]$process.Id)) { if ($window.Title -like '*Idle*') { $windows.Add($window) } }
                    Start-Sleep -Milliseconds 250
                    $process.Refresh()
                }
                Check ($process.HasExited) 'The transitions run finished within 45 s'
                Check ((Test-Path -LiteralPath $run.Done) -and ([IO.File]::ReadAllText($run.Done) -eq 'done')) 'The driver completed its schedule'
                $suite = if (Test-Path -LiteralPath "$($run.Root)\suite.txt") { [IO.File]::ReadAllText("$($run.Root)\suite.txt") } else { 'FAIL: no report' }
                Write-Output (($suite -split "`n")[0])
                Check ($suite -match '^PASS:') 'CoordinatorSuite.lua passes inside Rainmeter''s own Lua'
                Check ($windows.Count -gt 0) 'The coordinator window was observed while it ran'
                Check (@($windows | Where-Object { $_.Visible -and ($_.Width -gt 2 -or $_.Height -gt 2) }).Count -eq 0) "The coordinator window is hidden or at most a transparent pixel ($(@($windows | Select-Object -First 1 | ForEach-Object { "visible=$($_.Visible) $($_.Width)x$($_.Height)" })))"
                $records = @(Read-Witness $run)
                $writes = @($records | Where-Object { $_.Kind -eq 'write' })
                Check ($writes.Count -eq 3) 'Three idle-file writes (0, 10, 0)'
                $updates = @($records | Where-Object { $_.Kind -in @('update', 'nested') -and $_.Sync -eq '1' })
                Check ($updates.Count -gt 0) 'The witness received synced updates'
                Check (@($records | Where-Object { $_.Kind -eq 'joined' }).Count -eq 1) 'The witness joined once'
                Check (@($records | Where-Object { $_.Kind -eq 'nested' }).Count -ge 1) 'The first broadcast re-entered the joining witness (synchronous activation)'
                $tick = 0.5
                foreach ($step in @(@{ Write = 1; Away = '1'; Label = 'away 0 -> 1' }, @{ Write = 2; Away = '0'; Label = 'away 1 -> 0' })) {
                    $written = $writes[$step.Write].Clock
                    $first = @($updates | Where-Object { $_.Clock -ge $written -and $_.Away -eq $step.Away } | Select-Object -First 1)
                    $latency = if ($first.Count) { $first[0].Clock - $written } else { [double]::NaN }
                    Write-Output ("     {0}: seen {1:N3} s after the write" -f $step.Label, $latency)
                    Check ($first.Count -eq 1 -and $latency -le $tick + 0.15) "$($step.Label) within one 500 ms tick"
                }
                $before = @($updates | Where-Object { $_.Clock -lt $writes[1].Clock })
                Check (@($before | Where-Object { $_.Away -ne '0' }).Count -eq 0) 'Away stays 0 before the idle file says 10'
                $awayBeats = @($updates | Where-Object { $_.Clock -gt $writes[1].Clock -and $_.Clock -lt $writes[2].Clock -and $_.Away -eq '1' } | Select-Object -ExpandProperty Beat -Unique)
                Check ($awayBeats.Count -ge 2) "Heartbeats refresh the beat while the state holds ($($awayBeats.Count) distinct beats while away)"
                # Each broadcast stamps a new beat (os.time). A heartbeat is a new
                # beat with the state unchanged; heartbeats follow the tick count
                # from Start (every 6 ticks, 3 s), not the last change.
                $broadcasts = [Collections.Generic.List[object]]::new()
                foreach ($record in $updates) { if (-not $broadcasts.Count -or $broadcasts[$broadcasts.Count - 1].Beat -ne $record.Beat) { $broadcasts.Add($record) } }
                $heartbeats = @(for ($i = 1; $i -lt $broadcasts.Count; $i++) { if ($broadcasts[$i].Away -eq $broadcasts[$i - 1].Away) { [pscustomobject]@{ Clock = $broadcasts[$i].Clock; Step = [long]$broadcasts[$i].Beat - [long]$broadcasts[$i - 1].Beat } } })
                Write-Output ("     broadcasts at (s): {0}" -f (($broadcasts | ForEach-Object { '{0:N2}{1}' -f $_.Clock, $(if ($_.Away -eq '1') { 'A' } else { '' }) }) -join ', '))
                Check ($heartbeats.Count -ge 2) "Heartbeats re-broadcast an unchanged state ($($heartbeats.Count) seen)"
                Check (@($heartbeats | Where-Object { $_.Step -ge 2 -and $_.Step -le 4 }).Count -ge 1) 'A heartbeat follows the previous same-state broadcast by about 6 ticks (3 s)'
                $display = @(Get-Content -LiteralPath $run.Log | Where-Object { $_ -match 'System: (Display settings|Work area) changed' })
                if ($display.Count) { Write-Output "     note: Windows reported $($display.Count) display/work-area change(s) during the run; Rainmeter's timers can stall then." }
                $issues = @(Get-LogIssues $run)
                $issues | ForEach-Object { Write-Output "     log: $_" }
                Check ($issues.Count -eq 0) 'Rainmeter logged no error or warning'
            }
            { $_ -in @('startup-active', 'startup-inactive') } {
                $section = if ($name -eq 'startup-active') { "Active=1`n$settled" } else { "Active=0`n$settled" }
                $run = New-Run $name $hooks $true $section
                $process = Start-Run $run
                Check ($process.WaitForExit(30000)) "$name finished"
                Check ((Test-Path -LiteralPath $run.Done) -and ([IO.File]::ReadAllText($run.Done) -eq 'synced')) 'The witness synced'
                $records = @(Read-Witness $run)
                $joins = @($records | Where-Object { $_.Kind -eq 'joined' })
                if ($name -eq 'startup-inactive') {
                    Check ($joins.Count -eq 1) 'One delayed join activated the coordinator'
                } else {
                    # The walk loads the coordinator after the witness; its Start
                    # broadcast usually syncs the witness before the delayed join.
                    Check ($joins.Count -le 1) "At most one delayed join ($($joins.Count))"
                }
                $firstJoin = [array]::FindIndex([object[]]$records, [Predicate[object]] { param($r) $r.Kind -eq 'joined' })
                $updatesBefore = if ($firstJoin -ge 0) { @($records[0..$firstJoin] | Where-Object { $_.Kind -eq 'update' }).Count } else { 2 }
                Check ($updatesBefore -ge 2) 'No join inside the load''s first update'
                $load = @($records | Where-Object { $_.Kind -eq 'load' } | Select-Object -First 1)
                if ($joins.Count -and $load.Count) { Write-Output ("     join {0:N3} s after the witness loaded" -f ($joins[0].Clock - $load[0].Clock)) }
                Check ((Get-IdleActive $run.Ini) -eq 1) 'Rainmeter.ini records the coordinator active'
                $issues = @(Get-LogIssues $run)
                $issues | ForEach-Object { Write-Output "     log: $_" }
                Check ($issues.Count -eq 0) 'Rainmeter logged no error or warning'
            }
            'no-consumer' {
                $caseHooks = $hooks.Clone()
                $caseHooks.ParallaxIdleTestReevaluateTicks = '4'
                $run = New-Run $name $caseHooks $false "Active=1`n$settled"
                $process = Start-Run $run
                $clock = [Diagnostics.Stopwatch]::StartNew()
                $seen = $false
                $gone = -1
                while ($clock.ElapsedMilliseconds -lt 15000) {
                    $count = @([ParallaxIdleWindows]::Of([uint32]$process.Id) | Where-Object { $_.Title -like '*Idle*' }).Count
                    if ($count) { $seen = $true }
                    if ($seen -and -not $count -and (Get-IdleActive $run.Ini) -eq 0) { $gone = $clock.ElapsedMilliseconds; break }
                    Start-Sleep -Milliseconds 100
                }
                Check $seen 'The coordinator loaded'
                Write-Output ("     unloaded itself {0} ms after launch" -f $gone)
                Check ($gone -ge 0) 'With no consumer it deactivates itself and Rainmeter records Active=0'
                Start-Sleep -Milliseconds 500
                Stop-Run $process
                $issues = @(Get-LogIssues $run)
                $issues | ForEach-Object { Write-Output "     log: $_" }
                Check ($issues.Count -eq 0) 'Rainmeter logged no error or warning'
                $notes = @(Get-Content -LiteralPath $run.Log | Where-Object { $_ -match 'Idle' })
                $notes | Select-Object -Last 4 | ForEach-Object { Write-Output "     log: $_" }
            }
        }
        Write-Output "     evidence: $($run.Root)"
    } finally {
        Stop-Run $process
    }
}
Write-Output "$checks checks, $failures failures."
if ($failures) { throw 'Idle coordinator native checks failed.' }
