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
#   headline every ParallaxIdleHeadline meter is hidden while paused and back
#            exactly as before after leave (B probe records); with a hover
#            pair, emulated hover actions while paused move only the gear,
#            the frozen value never shows, a resume with the pointer still
#            over the skin keeps the value hidden, and the next hover-out
#            restores the live headline.
#   restart  paused, then the skin reloads: it re-enters once synced. RAM and
#            GPU: no helper launcher or host outlives the pause, before the
#            reload and after re-entry (the reload's launch is still running at
#            re-entry; -LaunchDelayMs makes that certain for the hover cycles'
#            launches and the reload's, with their hosts already started).
#   watchdog paused, then the coordinator stops beating (its script paused by
#            the driver): the skin fails live within the staged 6 s stale limit
#            plus one 2 s hook period.
#   log      no error or warning in Rainmeter.log.
# Mode capture: live and paused window captures only (both default layouts).
# -BackgroundAlpha stages a translucent BackgroundColor (Global Settings
# Background transparency) for captures that show the headline is hidden.
# -Suite runs StandDownSuite.lua inside Rainmeter's own Lua.
# -Combined loads every utility config at once in one instance (Media.ini for
# Parallax\Media; Setup.ini shares that config and runs on its own) with the
# driver: every skin syncs, enters and leaves on one idle write, every meter
# freezes and comes back to its snapshot, the RAM and GPU hosts stop and one
# new host each starts, the instance has no active render session while
# paused, the coordinator loads exactly once and Media and the Visualizer
# reload exactly twice, and the log stays clean. The coordinator starts from
# the first join, or with -CoordinatorAtStart in its place in Rainmeter's own
# startup walk, after some utilities and before others. One thread runs every
# skin's transition and both standby reloads, so each skin's latency bound is
# the slowest skin's; the longest main-thread block is reported. -Skin picks a
# subset (Setup excluded).
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string[]]$Skin = @(),
    [ValidateSet('full', 'capture')][string]$Mode = 'full',
    [ValidateSet('w220-s1', 'w180-s0.75')][string[]]$Layout = @('w220-s1', 'w180-s0.75'),
    [switch]$Suite,
    [switch]$Combined,
    [switch]$CoordinatorAtStart,
    [string]$OutDir = '',
    # Staged BackgroundColor alpha (Global Settings Background transparency);
    # -1 keeps the shipped value. A translucent background shows anything the
    # paused line only covered, so captures with it prove the headline hides.
    [ValidateRange(-1, 255)][int]$BackgroundAlpha = -1,
    # Staged RAM and GPU launchers wait this long after their host's first
    # frame before reporting, so a stand-down shortly after a launch (the
    # reload while paused) always finds the launch in progress with its host
    # already started: the kill race's stranded-host case, made deterministic.
    [ValidateRange(0, 8000)][int]$LaunchDelayMs = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# powershell.exe -File passes 'A,B' as one string.
$Skin = @($Skin | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Layout = @($Layout | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
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
# A latency bound: a transition that happened but missed its bound while
# Windows re-detected displays (Rainmeter logs each event; its timers stall
# then) is reported LATE, not failed. A transition that never came fails.
$late = 0
function Check-Bound([bool]$Reached, [bool]$Within, [int]$DisplayEvents, [string]$Message) {
    if ($Reached -and -not $Within -and $DisplayEvents -gt 0) {
        $script:late++
        Write-Output "LATE $Message ($DisplayEvents display re-detection events during the step)"
        return
    }
    Check ($Reached -and $Within) $Message
}

# Utility entrypoints this harness can run. Tick: the time the paused line may
# take after the coordinator's tick, in seconds (one skin tick for in-place
# skins; a reload for refresh-standby skins). Extra: a module check run after
# the shared steps. Texts: meters whose Text the probe logs. Prepare: staging
# changes for this skin (e.g. provider fixtures). Variable: a variable the
# probe evaluates once per load.
$skins = [ordered]@{}
function Register-Skin([string]$Key, [string]$Config, [string]$File, [double]$Tick, [scriptblock]$Extra = $null, [string]$Texts = '',
        [scriptblock]$Prepare = $null, [string]$Variable = '', [switch]$StaticValues, [string]$Hover = '') {
    $script:skins[$Key] = [pscustomobject]@{ Key = $Key; Config = $Config; File = $File; Tick = $Tick; Extra = $Extra; Texts = $Texts
        Prepare = $Prepare; Variable = $Variable; StaticValues = [bool]$StaticValues; Hover = $Hover
        Relative = ($Config.Substring('Parallax\'.Length) + '\' + $File).Replace('\', '/') }
}
# Hover pairs (ParallaxIdleHoverSwap): 'swap:Gear,Value' for a bang swap in
# the skin's hover actions, 'script:Measure:Gear,Value' for a script hover.
function Send-Hover($Run, [string]$Side) {
    $spec = $Run.Entry.Hover
    if ($spec -like 'swap:*') { return Send $Run ("swap {0} {1},{2}" -f $Run.Entry.Config, $Side, $spec.Substring(5)) }
    $measure = $spec.Split(':')[1]
    return Send $Run ("scripthover {0} {1},{2}" -f $Run.Entry.Config, $measure, $(if ($Side -eq 'in') { '1' } else { '0' }))
}
function Get-HoverPair($Entry) { $names = $Entry.Hover.Split(':')[-1].Split(','); return [pscustomobject]@{ Gear = $names[0]; Value = $names[1] } }
# Headline visibility records (B) of one snapshot tag after a clock: meter -> '1' hidden, '0' shown.
function Get-Visibility($Records, [string]$Tag, [double]$After = -1) {
    $selected = @($Records | Where-Object { $_.Kind -eq 'B' -and $_.Rest[0] -eq $Tag -and $_.Clock -ge $After })
    if (-not $selected.Count) { return $null }
    $first = $selected[0].Clock
    $map = [ordered]@{}
    foreach ($record in $selected) { if ([math]::Abs($record.Clock - $first) -lt 0.5 -and -not $map.Contains($record.Rest[1])) { $map[$record.Rest[1]] = $record.Rest[2] } }
    return $map
}
function Format-Visibility($Map) { if ($null -eq $Map) { return '(none)' }; ($Map.Keys | ForEach-Object { "$_=$($Map[$_])" }) -join ' ' }
function Get-RefreshCount([string]$Root, [string]$Pattern) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return 0 }
    try { @(Get-Content -LiteralPath $log | Where-Object { $_ -match $Pattern }).Count } catch { 0 }
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
# Waits up to 20 s for no launcher or host of this run (started after $After,
# when given) to be left. Quiet is the ms until then (-1: never); Trace lists
# every one seen, by kind (a launcher's command line carries the session
# report), with when it was first and last seen (ms after the call).
function Wait-HelpersGone($Process, [string]$Marker, [datetime]$After = [datetime]::MinValue) {
    $since = if ($After -gt $Process.StartTime) { $After } else { $Process.StartTime }
    $seen = [ordered]@{}
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $quiet = -1
    while ($clock.ElapsedMilliseconds -lt 20000) {
        $live = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
            $_.CommandLine -and $_.CommandLine.Contains($Marker) -and $_.CreationDate -gt $since })
        $at = $clock.ElapsedMilliseconds
        foreach ($item in $live) {
            # A string key: an int would index the ordered dictionary.
            $id = [string]$item.ProcessId
            if (-not $seen.Contains($id)) { $seen[$id] = [pscustomobject]@{ Kind = $(if ($item.CommandLine -match '_SESSION\|') { 'launcher' } else { 'host' }); Created = $item.CreationDate.ToString('HH:mm:ss.fff'); First = $at; Last = $at } }
            else { $seen[$id].Last = $at }
        }
        if (-not $live.Count) { $quiet = $at; break }
        Start-Sleep -Milliseconds 100
    }
    $trace = ($seen.Keys | ForEach-Object { '{0} {1} created {2}, seen {3}-{4} ms' -f $seen[$_].Kind, $_, $seen[$_].Created, $seen[$_].First, $seen[$_].Last }) -join '; '
    [pscustomobject]@{ Quiet = $quiet; Trace = $(if ($trace) { $trace } else { 'no launcher or host seen' }) }
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
    # The probe logs a text only when it changes. When the host had not sampled
    # yet before the pause (a skin reloaded or failed live just before), the
    # meter already read the starting state and kept it through the resume.
    $prior = @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq 'T' -and $_.Clock -lt $resumedAt -and $_.Rest[0] -eq $Meter } | Select-Object -Last 1)
    Write-Output ("     {0}: after resume {1}: {2}{3}" -f $Label, $Meter, $(if ($prior.Count) { "(before: $($prior[0].Rest[1])) " } else { '' }),
        (($texts | ForEach-Object { '{0:N1}s {1}' -f ($_.Clock - $resumedAt), $_.Rest[1] }) -join ' -> '))
    $startingFirst = $texts.Count -ge 1 -and $texts[0].Rest[1] -match $StartingPattern
    $startingThrough = $texts.Count -ge 1 -and $texts[0].Rest[1] -match $FreshPattern -and $prior.Count -and $prior[0].Rest[1] -match $StartingPattern
    Check ($startingFirst -or $startingThrough) "${Label}: the first resumed reading is a starting state, not the frozen value"
    Check ($fresh -ge 0) "${Label}: a fresh reading follows within 30 s"
    $after = @(Get-RunHosts $Process $Marker | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
    Check ($after.Count -eq 1 -and @($after | Where-Object { $_.Id -in @($before | ForEach-Object Id) }).Count -eq 0) "${Label}: exactly one new host after the resume"
}

# Media's providers become built-in fixtures (Test-MediaCaptureLease.ps1's
# approach): no WebNowPlaying server, Source reader or provider launch, so
# nothing reaches a player, a helper or the network. The drawer is open.
$mediaPrepare = {
    param($Root, $Target)
    $media = Join-Path $Target '@Resources\Modules\Media'
    $providerPath = Join-Path $media 'WebNowPlaying.inc'
    $provider = [IO.File]::ReadAllText($providerPath)
    $numeric = @{ MeasureConnection = '1'; MeasureState = '2'; MeasurePosition = '45'; MeasureDuration = '180'; MeasureProgress = '25'
        MeasureCanPrevious = '1'; MeasureCanPlayPause = '1'; MeasureCanNext = '1' }
    $strings = @{ MeasurePlayer = 'Synthetic player'; MeasureTitle = 'Synthetic title'; MeasureArtist = 'Synthetic artist'
        MeasureSourceArtist = 'Synthetic artist'; MeasureAlbum = 'Synthetic album'; MeasureCover = ''; MeasureMediaSource = 'Spotify' }
    $provider = [regex]::Replace($provider, '(?ms)^\[(Measure\w+)\]\r?\n(.*?)(?=^\[|\z)', {
        param($match)
        $name = $match.Groups[1].Value
        $body = $match.Groups[2].Value
        if ($body -notmatch '(?m)^Plugin=WebNowPlaying\r?$' -and $body -notmatch '(?m)^ScriptFile=.*SourceReader\.lua\r?$') { return $match.Value }
        $keep = @([regex]::Matches($body, '(?m)^(UpdateDivider|MinValue|MaxValue|Group)=[^\r\n]*') | ForEach-Object { $_.Value })
        if ($numeric.ContainsKey($name)) { return "[$name]`nMeasure=Calc`nFormula=$($numeric[$name])`n$($keep -join "`n")`n`n" }
        return "[$name]`nMeasure=String`nString=$($strings[$name])`n$($keep -join "`n")`n`n"
    })
    [IO.File]::WriteAllText($providerPath, $provider, $encoding)
    [IO.File]::WriteAllText((Join-Path $media 'ProviderControlFixture.lua'), "function Update() return 1 end`nfunction Run() end`n", $encoding)
    foreach ($file in Get-ChildItem -LiteralPath $Target -Recurse -File | Where-Object { $_.Extension -in @('.ini', '.inc') }) {
        $text = [IO.File]::ReadAllText($file.FullName)
        $updated = $text
        foreach ($resumeHost in @('MeasureMediaSourceResume', 'MeasureMediaQueueResume')) {
            $updated = [regex]::Replace($updated, '(?ms)^\[' + $resumeHost + '\]\r?\n.*?(?=^\[|\z)', "[$resumeHost]`nMeasure=Script`nScriptFile=#@#Modules\Media\ProviderControlFixture.lua`nUpdateDivider=-1`n`n")
        }
        $reader = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        $updated = $updated.Replace($reader, $reader + "`nQueueCachePath=$Root\no-queue.snapshot")
        if ($updated -ne $text) { [IO.File]::WriteAllText($file.FullName, $updated, $encoding) }
    }
    $preferences = Join-Path $Target '@Resources\User\Media.inc'
    Set-Key $preferences 'VisualizerDrawer' '2'
    Set-Key $preferences 'QueueExpanded' '0'
}
if (-not ('ParallaxStandDownAudio' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class ParallaxStandDownAudio {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] private class MMDeviceEnumeratorCom { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator { int EnumAudioEndpoints(int f, int m, out IntPtr d); int GetDefaultAudioEndpoint(int f, int r, out IMMDevice d); }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice { int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionManager2 { int GetAudioSessionControl(IntPtr g, int f, out IntPtr c); int GetSimpleAudioVolume(IntPtr g, int f, out IntPtr v); int GetSessionEnumerator(out IAudioSessionEnumerator s); }
    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionEnumerator { int GetCount(out int c); int GetSession(int i, out IAudioSessionControl2 s); }
    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionControl2 {
        int GetState(out int s); int GetDisplayName(out IntPtr n); int SetDisplayName(IntPtr n, IntPtr c); int GetIconPath(out IntPtr p);
        int SetIconPath(IntPtr p, IntPtr c); int GetGroupingParam(out Guid g); int SetGroupingParam(IntPtr g, IntPtr c);
        int RegisterAudioSessionNotification(IntPtr c); int UnregisterAudioSessionNotification(IntPtr c);
        int GetSessionIdentifier(out IntPtr i); int GetSessionInstanceIdentifier(out IntPtr i); int GetProcessId(out uint p); }
    // Session states (0 inactive, 1 active, 2 expired) of one process on the
    // default render endpoint. Read-only.
    public static int[] SessionStates(uint pid) {
        var states = new List<int>();
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDevice device; Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out device));
        var iid = typeof(IAudioSessionManager2).GUID; object face;
        Marshal.ThrowExceptionForHR(device.Activate(ref iid, 23, IntPtr.Zero, out face));
        IAudioSessionEnumerator sessions; Marshal.ThrowExceptionForHR(((IAudioSessionManager2)face).GetSessionEnumerator(out sessions));
        int count; sessions.GetCount(out count);
        for (int i = 0; i < count; i++) {
            IAudioSessionControl2 session; sessions.GetSession(i, out session);
            uint owner; session.GetProcessId(out owner);
            if (owner == pid) { int state; session.GetState(out state); states.Add(state); }
        }
        return states.ToArray();
    }
}
'@
}
function Get-ActiveSessions($Process) { @([ParallaxStandDownAudio]::SessionStates([uint32]$Process.Id) | Where-Object { $_ -eq 1 }).Count }
# A refresh-standby skin (Media.ini, the standalone Visualizer) stands down by
# reloading: one refresh into standby (slow tick, no capture, so no render
# session for the instance) and one refresh back (fast tick, live capture);
# a Rainmeter restart while in standby with input recent loads once in
# standby and refreshes once back to live. Live: regexes the state file must
# match when live; Standby: the one it matches when stood down.
function Test-RefreshStandby($Run, $Process, [string]$Label, [string]$Pattern, [string]$StateFile, [string[]]$Live, [string]$Standby,
        [string]$TickName, [string]$SlowTick, [string]$FastTick) {
    $pattern = $Pattern
    foreach ($step in @(@{ Idle = '10'; Hidden = '0'; Tick = $SlowTick; Sessions = 0; Label = 'standby' }, @{ Idle = '0'; Hidden = '1'; Tick = $FastTick; Sessions = 1; Label = 'back to live' })) {
        $before = Get-RefreshCount $Run.Root $pattern
        $written = Send $Run "idle $($step.Idle)"
        $seen = Wait-Hidden $Run $step.Hidden $written 20000
        Start-Sleep -Seconds 3
        $after = Get-RefreshCount $Run.Root $pattern
        $tick = @(Read-Probe $Run.Probe | Where-Object { $_.Kind -eq 'F' -and $_.Clock -ge $written } | Select-Object -Last 1)
        $sessions = Get-ActiveSessions $Process
        Write-Output ("     {7} {0}: line {1} after {2:N2} s; refreshes {3} -> {4}; {8} {5}; active render sessions {6}" -f $step.Label,
            $(if ($step.Hidden -eq '0') { 'shown' } else { 'hidden' }), $(if ($seen) { $seen.Clock - $written } else { [double]::NaN }), $before, $after,
            $(if ($tick.Count) { $tick[0].Rest[1] } else { '?' }), $sessions, $Label, $TickName)
        Check ($null -ne $seen -and $after -eq $before + 1) "$Label $($step.Label): exactly one refresh"
        Check ($tick.Count -eq 1 -and $tick[0].Rest[1] -eq $step.Tick) "$Label $($step.Label): $TickName $($step.Tick)"
        if ($step.Sessions -eq 0) { Check ($sessions -eq 0) "$Label $($step.Label): no capture and no render session" }
        else { Check ($sessions -ge 1) "$Label $($step.Label): the live capture's render session is back" }
    }
    $statePath = Join-Path $Run.Target $StateFile
    $state = [IO.File]::ReadAllText($statePath)
    Check (@($Live | Where-Object { $state -notmatch $_ }).Count -eq 0) "${Label}: the state file is back to live"
    # Rainmeter restarts while Media is in standby and input is recent: the
    # standby load syncs with paused 0 and reloads once, back to live.
    $written = Send $Run 'idle 10'
    $null = Wait-Hidden $Run '0' $written 20000
    Start-Sleep -Seconds 2
    Check ([IO.File]::ReadAllText($statePath) -match $Standby) "${Label}: standby saved before the restart"
    try { $null = Send $Run 'quit' } catch { }
    Check ($Process.WaitForExit(20000)) "${Label}: the instance quit while in standby"
    [IO.File]::WriteAllText("$($Run.Root)\idle.txt", '0', $encoding)
    foreach ($stale in @("$($Run.Root)\cmd.txt", "$($Run.Root)\driver.log")) { if (Test-Path -LiteralPath $stale) { Remove-Item -LiteralPath $stale } }
    $Run.Sequence = 0
    $restarted = Start-Run $Run.Root
    try {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $liveAt = -1
        while ($clock.ElapsedMilliseconds -lt 45000) {
            $text = try { [IO.File]::ReadAllText($statePath) } catch { '' }
            if (@($Live | Where-Object { $text -notmatch $_ }).Count -eq 0) { $liveAt = $clock.ElapsedMilliseconds; break }
            Start-Sleep -Milliseconds 200
        }
        Start-Sleep -Seconds 3
        $refreshes = Get-RefreshCount $Run.Root $pattern
        $sessions = Get-ActiveSessions $restarted
        Write-Output ("     {3} restart in standby with input recent: live after {0} ms; loads/refreshes in the new log {1}; active render sessions {2}" -f $liveAt, $refreshes, $sessions, $Label)
        Check ($liveAt -ge 0) "${Label}: restart in standby with input recent returns to live"
        Check ($refreshes -eq 2) "${Label}: one load in standby plus exactly one refresh back"
        Check ($sessions -ge 1) "${Label}: live capture after the restart"
    } finally {
        try { $null = Send $Run 'quit' } catch { }
        if (-not $restarted.WaitForExit(15000)) { Stop-Run $restarted }
    }
}

$mediaExtra = {
    param($Run, $Process)
    Test-RefreshStandby $Run $Process 'Media' 'Parallax\\Media\\Media\.ini: Refreshing skin' '@Resources\Modules\Media\CaptureState.inc' @('(?m)^MediaStandby=0', '(?m)^MediaDrawerCapture=0') '(?m)^MediaStandby=1' 'MediaTickInterval' '1000' '50'
}
$visualizerExtra = {
    param($Run, $Process)
    Test-RefreshStandby $Run $Process 'Visualizer' 'Parallax\\Visualizer\\Visualizer\.ini: Refreshing skin' '@Resources\Modules\Visualizer\StandbyState.inc' @('(?m)^VisualizerStandby=0') '(?m)^VisualizerStandby=1' 'VisualizerTickMs' '1000' '50'
}

Register-Skin 'Chronometer' 'Parallax\Chronometer' 'Chronometer.ini' 1.0
Register-Skin 'RAM' 'Parallax\RAM' 'RAM.ini' 1.0 {
    param($Run, $Process)
    Test-HostCycle $Run $Process 'RAM page-file host' 'ParallaxRamPageFile' 'MeterRAMPageGiB' '^Checking' 'GB$'
} 'MeterRAMPageGiB' -Hover 'script:MeasureRAMSettings:MeterRAMOptions,MeterRAMPercent'
Register-Skin 'GPU' 'Parallax\GPU' 'GPU.ini' 1.0 {
    param($Run, $Process)
    # Readings come from the resident driver host; on a machine without one
    # discrete GPU it runs for process names only and the temperature stays
    # Unavailable, which this check then reports as its fresh state.
    Test-HostCycle $Run $Process 'GPU telemetry host' 'ParallaxGpuTemperature' 'MeterTemperatureValue' '^Checking' '(C|Unavailable|Unsupported)$'
} 'MeterTemperatureValue|MeterActivityValue' -Hover 'swap:MeterOptions,MeterActivityValue'
Register-Skin 'CPU' 'Parallax\CPU' 'CPU.ini' 1.0 -Hover 'swap:MeterOptions,MeterTotal'
Register-Skin 'IO' 'Parallax\IO' 'IO-Disk.ini' 1.0 -Hover 'swap:MeterIOOptions,MeterIOTotal'
Register-Skin 'Network' 'Parallax\Network' 'Network.ini' 1.0 {
    param($Run, $Process)
    # NetIn/NetOut report bytes accumulated over the pause on their first
    # update; Core.lua must show 'sampling...' for two ticks, then 1 s samples.
    $records = @(Read-Probe $Run.Probe)
    $enter = @($records | Where-Object { $_.Kind -eq 'H' -and $_.Rest[0] -eq '0' } | Select-Object -First 1)
    $leave = @(if ($enter.Count) { $records | Where-Object { $_.Kind -eq 'H' -and $_.Rest[0] -eq '1' -and $_.Clock -gt $enter[0].Clock } | Select-Object -First 1 })
    if (-not $leave.Count) { Check $false 'Network: a first leave was recorded'; return }
    $texts = @($records | Where-Object { $_.Kind -eq 'T' -and $_.Rest[0] -eq 'MeterNetworkStatus' -and $_.Clock -ge $leave[0].Clock -and $_.Clock -le $leave[0].Clock + 6 })
    Write-Output ("     status after the first resume: {0}" -f (($texts | ForEach-Object { '{0:N1}s {1}' -f ($_.Clock - $leave[0].Clock), $_.Rest[1] }) -join ' -> '))
    Check ($texts.Count -ge 2 -and $texts[0].Rest[1] -match 'sampling') 'Network: the first status after resume reads sampling..., not a pause-long delta'
    Check (@($texts | Where-Object { $_.Rest[1] -match '1 s samples' }).Count -ge 1) 'Network: valid 1 s samples follow within 6 s'
} 'MeterNetworkStatus'
Register-Skin 'Media' 'Parallax\Media' 'Media.ini' 3.0 $mediaExtra '' $mediaPrepare 'MediaTickInterval'
Register-Skin 'Setup' 'Parallax\Media' 'Setup.ini' 1.0 $null '' $mediaPrepare -StaticValues
Register-Skin 'Queue' 'Parallax\Media\Queue' 'Queue.ini' 1.0 $null '' $mediaPrepare -StaticValues
Register-Skin 'Visualizer' 'Parallax\Visualizer' 'Visualizer.ini' 3.0 $visualizerExtra '' $null 'VisualizerTickMs'

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
    elseif command == 'swap' then
        -- A bang hover pair, as the skin's MouseOver/MouseLeaveAction run it:
        -- extra is in|out,Gear,Value; then #ParallaxIdleHoverAction# and the
        -- action's !Redraw.
        local side, gear, value = extra:match('^(%a+),([^,]+),([^,]+)$')
        local out = side == 'out'
        SKIN:Bang(out and '!HideMeter' or '!ShowMeter', gear, argument)
        SKIN:Bang(out and '!ShowMeter' or '!HideMeter', value, argument)
        SKIN:Bang('!CommandMeasure', 'MeasureParallaxStandDown', 'Hover()', argument)
        SKIN:Bang('!Redraw', argument)
    elseif command == 'scripthover' then
        -- A script hover (RAM.ini: !CommandMeasure MeasureRAMSettings "Hover(n)").
        local measure, inside = extra:match('^([^,]+),(%d)$')
        SKIN:Bang('!CommandMeasure', measure, 'Hover(' .. inside .. ')', argument)
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

# Shared staging: Idle pause 5 min with fast test hooks, the layout, and the
# coordinator's test idle file.
function Set-StandDownStage([string]$Root, [string]$Target, [string]$LayoutName) {
    $settings = Join-Path $Target '@Resources\User\Settings.inc'
    $width, $scale = switch ($LayoutName) { 'w220-s1' { '220', '1' } 'w180-s0.75' { '180', '0.75' } }
    foreach ($pair in @(@('IdlePauseMinutes', '5'), @('ParallaxIdleHookMs', '2000'), @('ParallaxIdleTestStaleSeconds', '6'),
            @('Scale', $scale), @('ColumnWidth', $width), @('TitleFontSize', '12'), @('HeaderFontSize', '10'), @('FontSize', '10'))) {
        Set-Key $settings $pair[0] $pair[1]
    }
    if ($LaunchDelayMs -gt 0) {
        # PageFile.lua is ASCII; Temperature.lua is UTF-16LE with BOM, kept so.
        foreach ($pair in @(@('@Resources\Modules\RAM\PageFile.lua', [Text.Encoding]::ASCII), @('@Resources\Modules\GPU\Temperature.lua', [Text.Encoding]::Unicode))) {
            $path = Join-Path $Target $pair[0]
            $text = [IO.File]::ReadAllText($path)
            $anchor = "if (`$p.HasExited) { throw 'host' }; "
            if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "No single launcher report step in $($pair[0])." }
            [IO.File]::WriteAllText($path, $text.Replace($anchor, "Start-Sleep -Milliseconds $LaunchDelayMs; $anchor"), $pair[1])
        }
    }
    if ($BackgroundAlpha -ge 0) {
        $channels = ([regex]::Match([IO.File]::ReadAllText($settings), '(?m)^BackgroundColor=(\d+),(\d+),(\d+)')).Groups
        Set-Key $settings 'BackgroundColor' ('{0},{1},{2},{3}' -f $channels[1].Value, $channels[2].Value, $channels[3].Value, $BackgroundAlpha)
    }
    $idleIni = Join-Path $Target 'Idle\Idle.ini'
    Set-Key $idleIni 'ParallaxIdleTick' '500'
    Set-Key $idleIni 'ParallaxIdleTestFile' "$Root\idle.txt"
    Set-Key $idleIni 'ParallaxIdleTestPauseSeconds' '4'
    Set-Key $idleIni 'ParallaxIdleTestAwaySeconds' '4'
    Set-Key $idleIni 'ParallaxIdleTestHeartbeatTicks' '4'
    Put $Root "$Root\idle.txt" '0'
    Put $Root "$Root\Driver.lua" $driverLua
    Put $Root "$Target\ADriver\Driver.ini" "[Rainmeter]`r`nUpdate=100`r`n`r`n[Variables]`r`nCommandFile=$Root\cmd.txt`r`nDriverLog=$Root\driver.log`r`nIdleFile=$Root\idle.txt`r`n`r`n[MeasureDriver]`r`nMeasure=Script`r`nScriptFile=$Root\Driver.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`nUpdateDivider=-1`r`n"
}
# Appends the divider probe to one staged entrypoint; Suffix keeps the files of
# several probes in one instance apart. Returns the probe log path.
function Add-StandDownProbe([string]$Root, [string]$Target, $Entry, [string]$Suffix = '') {
    # Every meter and paused measure of each variant this run loads (Media: the
    # open drawer live and parked), merged; a name a load lacks reads 'missing'.
    $variantSets = [Collections.Generic.List[object]]::new()
    if ($Entry.Key -eq 'Media') {
        $variantSets.Add([string[]]@('VisualizerDrawer=2', 'MediaDrawerCapture=0'))
        $variantSets.Add([string[]]@('VisualizerDrawer=2', 'MediaDrawerCapture=1', 'MediaStandby=1'))
    } else {
        $variantSets.Add([string[]]@())
    }
    $meterNames = [Collections.Generic.List[string]]::new(); $measureNames = [Collections.Generic.List[string]]::new()
    $index = 0
    foreach ($set in $variantSets) {
        $index++
        $lists = & python (Join-Path $toolsRoot 'tests\test_idle_freeze_contract.py') --list $Entry.Relative "$Root\meters$Suffix$index.txt" "$Root\measures$Suffix$index.txt" 'IdlePauseMinutes=5' @set 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Static list failed: $lists" }
        Write-Host "     $lists $($set -join ' ')"
        foreach ($name in [IO.File]::ReadAllLines("$Root\meters$Suffix$index.txt")) { if ($name -and -not $meterNames.Contains($name)) { $meterNames.Add($name) } }
        foreach ($name in [IO.File]::ReadAllLines("$Root\measures$Suffix$index.txt")) { if ($name -and -not $measureNames.Contains($name)) { $measureNames.Add($name) } }
    }
    [IO.File]::WriteAllLines("$Root\meters$Suffix.txt", $meterNames)
    [IO.File]::WriteAllLines("$Root\measures$Suffix.txt", $measureNames)
    $entryPath = Join-Path $Target ($Entry.Config.Substring('Parallax\'.Length) + '\' + $Entry.File)
    $default = '1'
    $entryText = [IO.File]::ReadAllText($entryPath)
    $match = [regex]::Match($entryText, '(?m)^DefaultUpdateDivider=([^\r\n]*)')
    if ($match.Success) { $default = $match.Groups[1].Value }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DividerProbe.lua') -Destination "$Root\DividerProbe.lua" -Force
    $entryText = $entryText.TrimEnd() + "`r`n`r`n[MeasureParallaxDividerProbe]`r`nMeasure=Script`r`nScriptFile=$Root\DividerProbe.lua`r`nUpdateDivider=1`r`nProbeMeters=$Root\meters$Suffix.txt`r`nProbeMeasures=$Root\measures$Suffix.txt`r`nProbeLog=$Root\probe$Suffix.log`r`nProbeDefault=$default`r`nProbeTexts=$($Entry.Texts)`r`nProbeVariable=$($Entry.Variable)`r`n"
    [IO.File]::WriteAllText($entryPath, $entryText, $encoding)
    return "$Root\probe$Suffix.log"
}
# One staged instance: the target skin, the coordinator (started by the join)
# and the driver.
function New-StandDownRun($Entry, [string]$LayoutName) {
    $root = New-Root
    $target = Copy-Skin $root
    Set-StandDownStage $root $target $LayoutName
    if ($Entry.Prepare) { & $Entry.Prepare $root $target }
    $probe = Add-StandDownProbe $root $target $Entry
    $folder = Join-Path $target $Entry.Config.Substring('Parallax\'.Length)
    Write-Settings $root @([pscustomobject]@{ Name = $Entry.Config; Active = (Get-ActiveIndex $folder $Entry.File) }, [pscustomobject]@{ Name = 'Parallax\ADriver'; Active = 1 })
    return [pscustomobject]@{ Root = $root; Target = $target; Probe = $probe; Driver = "$root\driver.log"; Entry = $Entry; Layout = $LayoutName; Sequence = 0 }
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
        $baselineShown = Get-Visibility (Read-Probe $run.Probe) 'baseline'
        Write-Output "     headline before the pause: $(Format-Visibility $baselineShown)"
        # The Visualizer's overlay shows only without signal, so its live
        # headline depends on what is playing: reported, not compared.
        $signalDependent = $Entry.Key -eq 'Visualizer'
        if (-not $signalDependent) { Check ($null -ne $baselineShown -and @($baselineShown.Values | Where-Object { $_ -eq '0' }).Count -gt 0) "$($Entry.Key): the headline list names meters shown before the pause" }
        Capture $run $process 'live'

        $displayBefore = Get-DisplayEvents $run.Root
        $written = Send $run 'idle 10'
        $enter = Wait-Hidden $run '0' $written 15000
        $latency = if ($enter) { $enter.Clock - $written } else { [double]::NaN }
        Write-Output ("     enter: paused line shown {0:N3} s after the idle write (bound {1:N1} s)" -f $latency, $bound)
        Check-Bound ($null -ne $enter) ($latency -le $bound) ((Get-DisplayEvents $run.Root) - $displayBefore) "$($Entry.Key): enter within a coordinator tick plus one skin tick"
        if ($null -eq $enter) { return }
        $records = Read-Probe $run.Probe
        $snapshot = Get-Snapshot $records 'enter' $enter.Clock
        $notFrozen = @($snapshot.Dividers.Keys | Where-Object { $snapshot.Dividers[$_] -ne '-1' -and $snapshot.Dividers[$_] -ne 'missing' })
        Check ($notFrozen.Count -eq 0) "$($Entry.Key): every meter resolves to UpdateDivider -1 while paused ($($snapshot.Dividers.Count) meters$(if ($notFrozen.Count) { '; not frozen: ' + (($notFrozen | Select-Object -First 8) -join ', ') }))"
        $pausedShown = Get-Visibility $records 'enter' $enter.Clock
        $pair = if ($Entry.Hover) { Get-HoverPair $Entry } else { $null }
        $stillShown = @(if ($pausedShown) { $pausedShown.Keys | Where-Object { $pausedShown[$_] -eq '0' -and -not ($pair -and $_ -eq $pair.Gear) } })
        Write-Output "     headline while paused: $(Format-Visibility $pausedShown)"
        Check ($null -ne $pausedShown -and $stillShown.Count -eq 0) "$($Entry.Key): every headline meter is hidden while paused$(if ($stillShown.Count) { '; shown: ' + ($stillShown -join ', ') })"
        Start-Sleep -Milliseconds 3800
        if ($Full) {
            $window = @(Read-Probe $run.Probe | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $enter.Clock + 0.5 -and $_.Clock -le $enter.Clock + 3.5 })
            $moved = @($window | Where-Object { [int]$_.Rest[2] -ne 0 })
            $digests = @($window | ForEach-Object { $_.Rest[1] } | Select-Object -Unique)
            # Fewer than two probe ticks in 3 s means Rainmeter's timers stalled.
            Check-Bound ($moved.Count -eq 0 -and $digests.Count -le 1) ($window.Count -ge 2) ((Get-DisplayEvents $run.Root) - $displayBefore) "$($Entry.Key): paused measure values stay constant for 3 s ($($window.Count) ticks, $($digests.Count) distinct digest)"
        }
        Capture $run $process 'paused'

        $displayBefore = Get-DisplayEvents $run.Root
        $written = Send $run 'idle 0'
        $leave = Wait-Hidden $run '1' $written 15000
        $latency = if ($leave) { $leave.Clock - $written } else { [double]::NaN }
        Write-Output ("     leave: paused line hidden {0:N3} s after the idle write" -f $latency)
        Check-Bound ($null -ne $leave) ($latency -le $bound) ((Get-DisplayEvents $run.Root) - $displayBefore) "$($Entry.Key): leave within a coordinator tick plus one skin tick"
        if ($null -eq $leave) { return }
        $after = Get-Snapshot (Read-Probe $run.Probe) 'live' $leave.Clock
        $differ = @($baseline.Dividers.Keys | Where-Object { $after.Dividers[$_] -ne $baseline.Dividers[$_] })
        Check ($differ.Count -eq 0) "$($Entry.Key): every meter's divider equals its pre-enter snapshot after leave$(if ($differ.Count) { '; differ: ' + (($differ | Select-Object -First 8 | ForEach-Object { "$_ $($baseline.Dividers[$_])->$($after.Dividers[$_])" }) -join ', ') })"
        $afterShown = Get-Visibility (Read-Probe $run.Probe) 'live' $leave.Clock
        Write-Output "     headline after leave: $(Format-Visibility $afterShown)"
        if ($signalDependent) { Check ($null -ne $afterShown) "$($Entry.Key): the headline was recorded after leave (signal-dependent, not compared)" }
        else { Check ($null -ne $afterShown -and (Format-Visibility $afterShown) -eq (Format-Visibility $baselineShown)) "$($Entry.Key): the headline is back exactly as before the pause" }
        if (-not $Full) { return }
        Start-Sleep -Seconds 3
        $resumed = @(Read-Probe $run.Probe | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $leave.Clock -and [int]$_.Rest[2] -gt 0 })
        Write-Output "     after leave: $($resumed.Count) ticks with changed measure values in 3 s"
        if ($Entry.StaticValues) { Write-Output '     (this view has no changing value without a provider; not checked)' }
        else { Check ($resumed.Count -gt 0) "$($Entry.Key): measure values move again after leave" }
        Capture $run $process 'resumed'

        # Hover pair (emulated hover actions, as the skin's MouseOver/Leave run
        # them): while paused the gear follows the pointer and the frozen value
        # never shows; resuming with the pointer still over the skin keeps the
        # value hidden and the gear shown; the next hover-out restores both.
        if ($Entry.Hover) {
            $pair = Get-HoverPair $Entry
            if ($Entry.Hover -like 'swap:*') {
                # The swap's MouseLeaveAction ends with #ParallaxIdleHoverAction#
                # (test_idle_freeze_contract.py); this load expanded it to:
                $action = @(Read-Probe $run.Probe | Where-Object { $_.Kind -eq 'A' } | Select-Object -Last 1)
                $expanded = if ($action.Count) { $action[0].Rest[0] } else { '(none)' }
                Check ($expanded -eq '[!CommandMeasure MeasureParallaxStandDown "Hover()"]') "$($Entry.Key): the hover actions' #ParallaxIdleHoverAction# expands to the hook's Hover() ($expanded)"
            }
            $written = Send $run 'idle 10'
            $null = Wait-Hidden $run '0' $written 15000
            $steps = @(@{ Side = 'in'; Tag = 'hoverin'; Gear = '0'; Value = '1'; Text = 'hover-in while paused: gear shown, value hidden' },
                @{ Side = 'out'; Tag = 'hoverout'; Gear = '1'; Value = '1'; Text = 'hover-out while paused: gear hidden, the frozen value stays hidden' },
                @{ Side = 'in'; Tag = 'hoverin2'; Gear = '0'; Value = '1'; Text = 'hover-in again before the resume' })
            foreach ($step in $steps) {
                $null = Send-Hover $run $step.Side
                $null = Send $run "snap $($Entry.Config) $($step.Tag)"
                Start-Sleep -Milliseconds 500
                $map = Get-Visibility (Read-Probe $run.Probe) $step.Tag
                Check ($null -ne $map -and $map[$pair.Gear] -eq $step.Gear -and $map[$pair.Value] -eq $step.Value) "$($Entry.Key): $($step.Text) ($(Format-Visibility $map))"
            }
            $resumedAt = Send $run 'idle 0'
            $back = Wait-Hidden $run '1' $resumedAt 15000
            $map = if ($back) { Get-Visibility (Read-Probe $run.Probe) 'live' $back.Clock } else { $null }
            Check ($null -ne $map -and $map[$pair.Gear] -eq '0' -and $map[$pair.Value] -eq '1') "$($Entry.Key): resumed with the pointer over the skin: the value follows the gear and stays hidden ($(Format-Visibility $map))"
            $null = Send-Hover $run 'out'
            $null = Send $run "snap $($Entry.Config) hoverlive"
            Start-Sleep -Milliseconds 500
            $map = Get-Visibility (Read-Probe $run.Probe) 'hoverlive'
            Check ($null -ne $map -and (Format-Visibility $map) -eq (Format-Visibility $baselineShown)) "$($Entry.Key): the next hover-out restores the live headline ($(Format-Visibility $map))"
        }

        # Restart while paused: the reload starts live, joins, and re-enters.
        $written = Send $run 'idle 10'
        $enter = Wait-Hidden $run '0' $written 15000
        Check ($null -ne $enter) "$($Entry.Key): paused again before the restart"
        # A pause during a helper launch (the kill race: in one RAM run the
        # pause came 47 ms after the launch) lets the launch finish and removes
        # the lease of the host it reports, so no launcher or host outlives the
        # pause: at most the launcher's 10 s bound, one 1 s drain check and one
        # 2 s sampling interval. The hover cycles above resume and pause again
        # within 2 s, so with -LaunchDelayMs their launches are in progress.
        # This waits before the reload: a reload during a launch kills its
        # launcher (RunCommand's unload) and orphans the host until its lease
        # lapses, with or without Idle pause, which is not what this checks.
        $marker = @{ RAM = 'ParallaxRamPageFile'; GPU = 'ParallaxGpuTemperature' }[$Entry.Key]
        if ($marker -and $null -ne $enter) {
            $gone = Wait-HelpersGone $process $marker
            Write-Output ("     before the restart: none left {0} ms after the pause ({1})" -f $gone.Quiet, $gone.Trace)
            Check ($gone.Quiet -ge 0 -and $gone.Quiet -le 13000) "$($Entry.Key): no helper outlives the pause"
        }
        $reloadAt = Get-Date
        $reloaded = Send $run "refresh $($Entry.Config)"
        $load = Wait-Record $run 'L' $reloaded 15000
        $again = if ($load) { Wait-Hidden $run '0' $load.Clock 20000 } else { $null }
        Write-Output ("     restart while paused: re-entered {0:N3} s after the reload" -f $(if ($again) { $again.Clock - $load.Clock } else { [double]::NaN }))
        Check ($null -ne $again) "$($Entry.Key): a reload while paused re-enters once synced"
        # The reload starts a launch and the load re-enters the pause while it
        # runs: the same bound, for the helpers started since the reload.
        if ($marker -and $null -ne $again) {
            $gone = Wait-HelpersGone $process $marker $reloadAt
            Write-Output ("     restart while paused: none left {0} ms after re-entry ({1})" -f $gone.Quiet, $gone.Trace)
            Check ($gone.Quiet -ge 0 -and $gone.Quiet -le 13000) "$($Entry.Key): no helper launched by the reload outlives the pause"
        }

        # Watchdog: the coordinator stops beating; fail live after 6 s + 2 s.
        $displayBefore = Get-DisplayEvents $run.Root
        $hung = Send $run 'hang'
        $live = Wait-Hidden $run '1' $hung 30000
        $after = if ($live) { $live.Clock - $hung } else { [double]::NaN }
        Write-Output ("     watchdog: failed live {0:N3} s after the coordinator stopped beating (bound 6 s stale + 2 s hook + {1:N1} s)" -f $after, $Entry.Tick)
        Check-Bound ($null -ne $live) ($after -le 6 + 2 + $Entry.Tick + 1.5) ((Get-DisplayEvents $run.Root) - $displayBefore) "$($Entry.Key): with no beat the skin fails live within the stale limit plus one hook period"
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

# The longest gap between consecutive ticks of one probe (a 1 s skin) within
# 4 s after a clock: how long Rainmeter's thread was blocked.
function Get-LongestBlock([string]$Probe, [double]$After) {
    $ticks = @(Read-Probe $Probe | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $After - 1 -and $_.Clock -le $After + 4 } | ForEach-Object Clock)
    $longest = 0.0
    for ($i = 1; $i -lt $ticks.Count; $i++) { $longest = [math]::Max($longest, $ticks[$i] - $ticks[$i - 1]) }
    return $longest
}
function Invoke-Combined([string]$LayoutName, [bool]$AtStart) {
    $keys = @('Chronometer', 'RAM', 'GPU', 'CPU', 'IO', 'Network', 'Media', 'Queue', 'Visualizer')
    if ($Skin.Count) { $keys = @($Skin | Where-Object { $_ -ne 'Setup' }) }
    foreach ($key in $keys) { if (-not $skins.Contains($key)) { throw "Unknown skin '$key'." } }
    Write-Output "--- combined $LayoutName`: $($keys -join ', '); coordinator $(if ($AtStart) { 'active at start' } else { 'started by the first join' })"
    $root = New-Root
    $target = Copy-Skin $root
    Set-StandDownStage $root $target $LayoutName
    & $mediaPrepare $root $target
    $control = [pscustomobject]@{ Root = $root; Target = $target; Driver = "$root\driver.log"; Sequence = 0 }
    $runs = [ordered]@{}
    $configs = [Collections.Generic.List[object]]::new()
    foreach ($key in $keys) {
        $entry = $skins[$key]
        $probe = Add-StandDownProbe $root $target $entry "-$key"
        $runs[$key] = [pscustomobject]@{ Root = $root; Target = $target; Probe = $probe; Entry = $entry }
        $folder = Join-Path $target $entry.Config.Substring('Parallax\'.Length)
        $configs.Add([pscustomobject]@{ Name = $entry.Config; Active = (Get-ActiveIndex $folder $entry.File) })
    }
    if ($AtStart) { $configs.Add([pscustomobject]@{ Name = 'Parallax\Idle'; Active = 1 }) }
    $configs.Add([pscustomobject]@{ Name = 'Parallax\ADriver'; Active = 1 })
    Write-Settings $root $configs
    # One Rainmeter thread runs every skin's enter or leave and both standby
    # reloads back to back, so no skin can be faster than the slowest one: each
    # skin's bound here is the slowest skin's single-run bound. The longest gap
    # between one probe's ticks around each step (the main-thread block) is
    # reported.
    $combinedBound = 0.5 + (@($keys | ForEach-Object { $skins[$_].Tick }) | Measure-Object -Maximum).Maximum + 0.4
    $hostMarkers = [ordered]@{}
    foreach ($pair in @(@('RAM', 'ParallaxRamPageFile'), @('GPU', 'ParallaxGpuTemperature'))) { if ($keys -contains $pair[0]) { $hostMarkers[$pair[0]] = $pair[1] } }
    $reloads = [ordered]@{ Coordinator = 'Parallax\\Idle\\Idle\.ini: Refreshing skin' }
    if ($keys -contains 'Media') { $reloads['Media'] = 'Parallax\\Media\\Media\.ini: Refreshing skin' }
    if ($keys -contains 'Visualizer') { $reloads['Visualizer'] = 'Parallax\\Visualizer\\Visualizer\.ini: Refreshing skin' }
    $capture = $keys -contains 'Visualizer'
    $process = $null
    try {
        $process = Start-Run $root
        $started = [Diagnostics.Stopwatch]::StartNew()
        foreach ($key in $keys) {
            $left = [math]::Max(1000, 120000 - [int]$started.ElapsedMilliseconds)
            $sync = Wait-Record $runs[$key] 'Y' 0 $left
            Check ($null -ne $sync) "combined $key`: the hook joined and synced"
        }
        Write-Output ("     all synced {0:N1} s after the start" -f ($started.ElapsedMilliseconds / 1000))
        Start-Sleep -Seconds 3
        $baseline = @{}
        foreach ($key in $keys) { $null = Send $control "snap $($runs[$key].Entry.Config) baseline" }
        Start-Sleep -Milliseconds 800
        foreach ($key in $keys) {
            $baseline[$key] = Get-Snapshot (Read-Probe $runs[$key].Probe) 'baseline'
            Check ($null -ne $baseline[$key] -and $baseline[$key].Dividers.Count -gt 0) "combined $key`: baseline snapshot of $(if ($baseline[$key]) { $baseline[$key].Dividers.Count } else { 0 }) meters"
        }
        $hosts = @{}
        foreach ($name in $hostMarkers.Keys) {
            $hosts[$name] = @(Get-RunHosts $process $hostMarkers[$name] | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
            Check ($hosts[$name].Count -ge 1) "combined $name`: a host is running before the pause ($($hosts[$name].Count))"
        }
        $sessionsLive = Get-ActiveSessions $process
        Write-Output "     active render sessions before the pause: $sessionsLive"
        if ($capture) { Check ($sessionsLive -ge 1) 'combined: the live capture has a render session before the pause' }

        # Loads before the pause (Media also reloads once to defer its drawer
        # when the standalone Visualizer loads after it in the walk).
        $reloadBase = @{}
        foreach ($name in $reloads.Keys) { $reloadBase[$name] = Get-RefreshCount $root $reloads[$name] }
        $displayBefore = Get-DisplayEvents $root
        $written = Send $control 'idle 10'
        $enter = @{}
        foreach ($key in $keys) {
            $bound = $combinedBound
            $enter[$key] = Wait-Hidden $runs[$key] '0' $written 20000
            $latency = if ($enter[$key]) { $enter[$key].Clock - $written } else { [double]::NaN }
            Write-Output ("     {0} enter: {1:N3} s (bound {2:N1} s)" -f $key, $latency, $bound)
            Check-Bound ($null -ne $enter[$key]) ($latency -le $bound) ((Get-DisplayEvents $root) - $displayBefore) "combined $key`: enter within a coordinator tick plus the slowest skin's tick"
        }
        Write-Output ("     enter: longest main-thread block {0:N2} s" -f (Get-LongestBlock $runs[$keys[0]].Probe $written))
        Start-Sleep -Milliseconds 4000
        foreach ($key in $keys) {
            if ($null -eq $enter[$key]) { continue }
            $records = Read-Probe $runs[$key].Probe
            $snapshot = Get-Snapshot $records 'enter' $enter[$key].Clock
            $notFrozen = @(if ($snapshot) { $snapshot.Dividers.Keys | Where-Object { $snapshot.Dividers[$_] -ne '-1' -and $snapshot.Dividers[$_] -ne 'missing' } })
            Check ($null -ne $snapshot -and $notFrozen.Count -eq 0) "combined $key`: every meter resolves to UpdateDivider -1 while paused ($(if ($snapshot) { $snapshot.Dividers.Count } else { 0 }) meters$(if ($notFrozen.Count) { '; not frozen: ' + (($notFrozen | Select-Object -First 8) -join ', ') }))"
            $window = @($records | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $enter[$key].Clock + 0.5 -and $_.Clock -le $enter[$key].Clock + 3.5 })
            $moved = @($window | Where-Object { [int]$_.Rest[2] -ne 0 })
            $digests = @($window | ForEach-Object { $_.Rest[1] } | Select-Object -Unique)
            Check-Bound ($moved.Count -eq 0 -and $digests.Count -le 1) ($window.Count -ge 2) ((Get-DisplayEvents $root) - $displayBefore) "combined $key`: paused measure values stay constant for 3 s ($($window.Count) ticks, $($digests.Count) distinct digest)"
        }
        foreach ($name in $hostMarkers.Keys) {
            $running = @(Get-RunHosts $process $hostMarkers[$name] | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
            Check ($running.Count -eq 0) "combined $name`: no host runs while paused"
        }
        $sessionsPaused = Get-ActiveSessions $process
        Write-Output "     active render sessions while paused: $sessionsPaused"
        Check ($sessionsPaused -eq 0) 'combined: no active render session while paused'
        if ($OutDir) {
            $null = New-Item -ItemType Directory -Path $OutDir -Force
            foreach ($key in $keys) {
                $window = @(Find-Window $process $runs[$key].Entry.Config)
                if ($window.Count) { Save-Capture $window[0] (Join-Path $OutDir ("combined-{0}-{1}-paused.png" -f $key, $LayoutName)) }
            }
        }

        $displayBefore = Get-DisplayEvents $root
        $resumedAt = Send $control 'idle 0'
        $leave = @{}
        foreach ($key in $keys) {
            $bound = $combinedBound
            $leave[$key] = Wait-Hidden $runs[$key] '1' $resumedAt 20000
            $latency = if ($leave[$key]) { $leave[$key].Clock - $resumedAt } else { [double]::NaN }
            Write-Output ("     {0} leave: {1:N3} s" -f $key, $latency)
            Check-Bound ($null -ne $leave[$key]) ($latency -le $bound) ((Get-DisplayEvents $root) - $displayBefore) "combined $key`: leave within a coordinator tick plus the slowest skin's tick"
        }
        Write-Output ("     leave: longest main-thread block {0:N2} s" -f (Get-LongestBlock $runs[$keys[0]].Probe $resumedAt))
        Start-Sleep -Seconds 3
        foreach ($key in $keys) {
            if ($null -eq $leave[$key] -or $null -eq $baseline[$key]) { continue }
            $records = Read-Probe $runs[$key].Probe
            $after = Get-Snapshot $records 'live' $leave[$key].Clock
            $differ = @(if ($after) { $baseline[$key].Dividers.Keys | Where-Object { $after.Dividers[$_] -ne $baseline[$key].Dividers[$_] } })
            Check ($null -ne $after -and $differ.Count -eq 0) "combined $key`: every meter's divider equals its pre-enter snapshot after leave$(if ($differ.Count) { '; differ: ' + (($differ | Select-Object -First 8 | ForEach-Object { "$_ $($baseline[$key].Dividers[$_])->$($after.Dividers[$_])" }) -join ', ') })"
            $resumed = @($records | Where-Object { $_.Kind -eq 'V' -and $_.Clock -ge $leave[$key].Clock -and [int]$_.Rest[2] -gt 0 })
            # Media's drawer defers to the standalone Visualizer here, so its
            # paused measures are the provider fixtures, which never change.
            if ($runs[$key].Entry.StaticValues -or $key -eq 'Media') { Write-Output "     $key`: $($resumed.Count) ticks with changed values after leave (fixtures only; not checked)" }
            else { Check ($resumed.Count -gt 0) "combined $key`: measure values move again after leave ($($resumed.Count) ticks)" }
        }
        foreach ($name in $hostMarkers.Keys) {
            $old = @($hosts[$name] | ForEach-Object Id)
            $one = Wait-Until { @(Get-RunHosts $process $hostMarkers[$name] | Where-Object { (Get-Process -Id $_.Id -ErrorAction SilentlyContinue) -and $_.Id -notin $old }).Count -ge 1 } 30000
            Start-Sleep -Seconds 1
            $after = @(Get-RunHosts $process $hostMarkers[$name] | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
            Write-Output ("     {0}: a new host {1} ms after the resume; running now: {2}" -f $name, $one, $after.Count)
            Check ($one -ge 0 -and $after.Count -eq 1 -and @($after | Where-Object { $_.Id -in $old }).Count -eq 0) "combined $name`: exactly one new host after the resume"
        }
        $sessionsBack = Get-ActiveSessions $process
        Write-Output "     active render sessions after the resume: $sessionsBack"
        if ($capture) { Check ($sessionsBack -ge 1) 'combined: the live capture''s render session is back after the resume' }
        foreach ($name in $reloads.Keys) {
            $count = Get-RefreshCount $root $reloads[$name]
            $during = $count - $reloadBase[$name]
            Write-Output "     $name loads: $($reloadBase[$name]) before the pause, $during during pause and resume"
            if ($name -eq 'Coordinator') { Check ($count -eq 1) 'combined: the coordinator loaded exactly once in the whole run' }
            else { Check ($during -eq 2) "combined $name`: exactly two reloads for the pause and the resume (standby, back)" }
        }
    } finally {
        if ($null -ne $process) {
            try { $null = Send $control 'quit' } catch { }
            if (-not $process.WaitForExit(15000)) { Stop-Run $process }
        }
        $display = Get-DisplayEvents $root
        if ($display) { Write-Output "     note: Windows reported $display display/work-area change(s); Rainmeter's timers can stall then." }
        $issues = @(Get-LogIssues $root)
        $issues | Select-Object -First 12 | ForEach-Object { Write-Output "     log: $_" }
        Check ($issues.Count -eq 0) "combined $LayoutName`: Rainmeter logged no error or warning"
        Write-Output "     evidence: $root"
    }
}

if ($Combined) {
    foreach ($layoutName in $Layout) { Invoke-Combined $layoutName ([bool]$CoordinatorAtStart) }
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

# With -Combined, -Skin chooses the combined run's skins instead.
foreach ($key in $(if ($Combined) { @() } else { $Skin })) {
    if (-not $skins.Contains($key)) { throw "Unknown skin '$key'. Registered: $(@($skins.Keys) -join ', ')" }
    $entry = $skins[$key]
    $first = $true
    foreach ($layoutName in $Layout) {
        Invoke-StandDown $entry $layoutName ($Mode -eq 'full' -and $first)
        $first = $false
    }
}
Write-Output "$checks checks, $failures failures, $late late during display re-detection."
if ($failures) { throw 'Idle stand-down native checks failed.' }
