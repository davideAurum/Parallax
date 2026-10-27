#requires -Version 5.1
<#
.SYNOPSIS
Checks that the machine is ready for an overnight live trace, then starts
Trace-ParallaxLive.ps1 hidden and detached and confirms it is recording.

.DESCRIPTION
The preflight is read-only. It refuses to start the trace (FAIL) when:
  * the live Rainmeter is not running, or a second (preview) Rainmeter is;
  * another trace, benchmark, matrix, preview or test script is running;
  * HWiNFO is not running or its registry export is not changing. HWiNFO
    exports only while its sensors window is open: minimised is fine, closed
    is not;
  * the PC would sleep or hibernate before the trace ends and PowerToys Awake
    is not keeping it awake;
  * the output drive has under 1 GB free.
It warns (WARN), and asks before starting unless -Force, when:
  * the leak logger (build\leak-watch\Watch-Leak.ps1) is not running. The
    morning dropout check reads its display-events.csv, so without it a night
    of dropouts reads as none. The script offers to start it;
  * the machine is busy during a -SampleSeconds CPU sample (the limits of
    build\wakeup-recheck\wait-quiet.ps1), or TextInputHost is running away;
  * Spotify is busy (an open window keeps its renderer drawing) or has run for
    over an hour. The script offers to restart it minimised;
  * Windows has a restart pending;
  * the Claude app is not running (scheduled checks fire only while it is open).

The trace runs from the main working tree (the checkout that owns .git), so its
output lands in that checkout's build\perf-trace whichever worktree this script
is run from. The trace's console output goes to build\perf-trace\launch\.

  powershell -NoProfile -ExecutionPolicy Bypass -File tools\Start-ParallaxOvernightTrace.ps1 -Label overnight-clean-baseline
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\Start-ParallaxOvernightTrace.ps1 -PreflightOnly

Exit codes: 0 started (or preflight passed), 1 a check failed or the trace did
not start recording, 2 declined at a prompt.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)][double]$DurationMinutes = 600,
    [ValidateRange(1, 60)][int]$IntervalSeconds = 5,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$Label = 'overnight',
    # Checkout whose tools\Trace-ParallaxLive.ps1 runs; default: the main working tree.
    [string]$TraceRoot = '',
    # Folder holding Watch-Leak.ps1; default: this checkout's build\leak-watch.
    [string]$LeakWatchDir = '',
    [ValidateRange(5, 120)][int]$SampleSeconds = 20,
    # Start the leak logger without asking when it is not running.
    [switch]$StartLeakLogger,
    # Restart Spotify (minimised) without asking when it is busy or old. Playback stops.
    [switch]$RestartSpotify,
    # Run the checks only; start nothing.
    [switch]$PreflightOnly,
    # Start despite warnings, without asking. Failures still block.
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.Perf.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms

$here = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $TraceRoot) {
    $TraceRoot = $here
    try {
        $common = & git -C $here rev-parse --path-format=absolute --git-common-dir 2>$null
        if ($LASTEXITCODE -eq 0 -and $common) { $TraceRoot = Split-Path -Parent ([IO.Path]::GetFullPath(([string]$common).Trim())) }
    } catch { }
}
if (-not $LeakWatchDir) { $LeakWatchDir = Join-Path $here 'build\leak-watch' }
$tracer = Join-Path $TraceRoot 'tools\Trace-ParallaxLive.ps1'
$outDir = Join-Path $TraceRoot 'build\perf-trace'
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$sensorPattern = 'Temp|Fan|RPM|Power'   # Trace-ParallaxLive's default -SensorPattern
$busyScripts = 'Trace-ParallaxLive|Benchmark-Parallax|Benchmark-Tooltips|Invoke-PerfMatrix|Preview-Parallax|Test-Parallax\w*|Test-IdleStandDown'

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check([string]$Status, [string]$Name, [string]$Detail) {
    $checks.Add([pscustomobject]@{ Status = $Status; Name = $Name; Detail = $Detail })
    $color = @{ PASS = 'Green'; INFO = 'Gray'; WARN = 'Yellow'; FAIL = 'Red' }[$Status]
    Write-Host ('{0,-4}  {1,-13} {2}' -f $Status, $Name, $Detail) -ForegroundColor $color
}
function Format-Age([datetime]$Since) {
    $m = [math]::Round(((Get-Date) - $Since).TotalMinutes)
    if ($m -lt 90) { "$m min" } else { '{0:N1} h' -f ($m / 60) }
}
function Format-Timeout($Seconds) {
    if ($null -eq $Seconds) { '?' } elseif ($Seconds -eq 0) { 'never' } elseif ($Seconds -lt 120) { "$Seconds s" } else { '{0} min' -f [math]::Round($Seconds / 60) }
}
function Get-PowerTimeout([string]$Subgroup, [string]$Setting, [string]$Source) {
    try {
        $text = (& powercfg /query SCHEME_CURRENT $Subgroup $Setting) -join "`n"
        if ($text -match "Current $Source Power Setting Index:\s*0x([0-9a-fA-F]+)") { return [Convert]::ToInt32($Matches[1], 16) }
    } catch { }
    $null
}
function Read-HwinfoExport {
    $key = Get-ItemProperty -LiteralPath 'HKCU:\Software\HWiNFO64\VSB' -ErrorAction SilentlyContinue
    if (-not $key) { return $null }
    $raw = @{}; $traced = 0
    foreach ($p in $key.PSObject.Properties) {
        if ($p.Name -match '^ValueRaw(\d+)$') { $raw[$Matches[1]] = [string]$p.Value }
        elseif ($p.Name -match '^Label(\d+)$') {
            # The tracer keeps entries whose label matches its -SensorPattern or whose value is in RPM.
            $value = $key.PSObject.Properties["Value$($Matches[1])"]
            if ([string]$p.Value -match $sensorPattern -or ($value -and [string]$value.Value -match 'RPM')) { $traced++ }
        }
    }
    [pscustomobject]@{ Raw = $raw; Traced = $traced }
}
function Start-Detached([string]$CommandLine, [string]$WorkingDirectory, [uint16]$ShowWindow = 0) {
    # Win32_Process.Create starts the process outside this console and its job, so
    # closing this window does not end it. ShowWindow 0 is hidden, 7 minimised.
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = $ShowWindow }
    $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $CommandLine; CurrentDirectory = $WorkingDirectory; ProcessStartupInformation = $startup }
    if ($r.ReturnValue -ne 0) { throw "Win32_Process.Create returned $($r.ReturnValue) for: $CommandLine" }
    [int]$r.ProcessId
}
function Measure-ProcessCpu([string]$Name, [int]$Seconds) {
    $a = Get-ParallaxPerfSnapshot
    Start-Sleep -Seconds $Seconds
    $b = Get-ParallaxPerfSnapshot
    $sec = Get-ParallaxElapsedSeconds $a.Timestamp $b.Timestamp
    $sum = 0.0
    foreach ($d in [ParallaxPerfNative]::Diff($a.Processes, $b.Processes)) { if ($d.Name -eq $Name) { $sum += $d.CpuDelta / 1e7 / $sec * 100 } }
    $sum
}
function Quote([string]$Text) { "'" + ($Text -replace "'", "''") + "'" }

$endAt = (Get-Date).AddMinutes($DurationMinutes)
Write-Host ("Preflight for a {0}-minute trace every {1} s, label '{2}', ending about {3:ddd HH:mm}" -f $DurationMinutes, $IntervalSeconds, $Label, $endAt) -ForegroundColor Cyan

if (Test-Path -LiteralPath $tracer) { Add-Check PASS 'tracer' $tracer } else { Add-Check FAIL 'tracer' "not found: $tracer" }
$os = Get-CimInstance Win32_OperatingSystem
Add-Check INFO 'boot' ('{0:HH:mm} ({1} ago)' -f $os.LastBootUpTime, (Format-Age $os.LastBootUpTime))
$procs = @(Get-CimInstance Win32_Process -Property ProcessId, Name, CommandLine, CreationDate)

$rm = @($procs | Where-Object { $_.Name -eq 'Rainmeter.exe' } | Sort-Object CreationDate)
if ($rm.Count -eq 0) { Add-Check FAIL 'Rainmeter' 'not running' }
elseif ($rm.Count -gt 1) { Add-Check FAIL 'Rainmeter' ('{0} instances (pids {1}); close the preview instance first' -f $rm.Count, (($rm | ForEach-Object { $_.ProcessId }) -join ', ')) }
else {
    $windows = [ParallaxPerfNative]::CountSkinWindows([uint32]$rm[0].ProcessId)
    Add-Check $(if ($windows -gt 0) { 'PASS' } else { 'WARN' }) 'Rainmeter' ('pid {0}, up {1}, {2} skin windows' -f $rm[0].ProcessId, (Format-Age $rm[0].CreationDate), $windows)
}

$others = @($procs | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match "\\($busyScripts)\.ps1" })
if ($others.Count) { Add-Check FAIL 'other runs' ('already running: ' + (($others | ForEach-Object { 'pid {0} {1}' -f $_.ProcessId, [regex]::Match($_.CommandLine, "($busyScripts)\.ps1").Value }) -join '; ')) }
else { Add-Check PASS 'other runs' 'no other trace, benchmark or test is running' }

$leakScript = Join-Path $LeakWatchDir 'Watch-Leak.ps1'
$leakStop = Join-Path $LeakWatchDir 'leak-watch.stop'
$leakMissing = $false
if (Test-Path -LiteralPath $leakScript) {
    $lw = @($procs | Where-Object { $_.CommandLine -and $_.CommandLine -match 'Watch-Leak\.ps1' })
    $samplesCsv = Join-Path $LeakWatchDir 'leak-samples.csv'
    $last = if (Test-Path -LiteralPath $samplesCsv) { (Get-Item -LiteralPath $samplesCsv).LastWriteTime } else { $null }
    if ($lw.Count -and $last -and ((Get-Date) - $last).TotalMinutes -le 15) { Add-Check PASS 'leak logger' ('pid {0}, last sample {1:HH:mm}' -f $lw[0].ProcessId, $last) }
    elseif ($lw.Count) { Add-Check WARN 'leak logger' ('pid {0} is running but has written no sample since {1:HH:mm}' -f $lw[0].ProcessId, $last) }
    else {
        $leakMissing = $true
        $why = if ($last -and $last -lt $os.LastBootUpTime) { 'stopped at the {0:HH:mm} restart' -f $os.LastBootUpTime } else { 'not running' }
        Add-Check WARN 'leak logger' "$why. The morning dropout check reads its display-events.csv, so tonight's dropouts would go unrecorded"
    }
    if (Test-Path -LiteralPath $leakStop) { Add-Check WARN 'leak logger' "leak-watch.stop exists, so the logger stops (or exits at start); remove it to keep logging" }
}
else { Add-Check INFO 'leak logger' "none in $LeakWatchDir; skipped" }

$hw = @($procs | Where-Object { $_.Name -match '^HWiNFO(64|32)?\.exe$' })
$sp = @($procs | Where-Object { $_.Name -eq 'Spotify.exe' } | Sort-Object CreationDate)
$spotifyStale = $false
if (-not $sp.Count) { Add-Check INFO 'Spotify' 'not running' }
elseif (((Get-Date) - $sp[0].CreationDate).TotalMinutes -gt 60) {
    Add-Check WARN 'Spotify' ('running for {0}; restart it first (its renderer runs away over time)' -f (Format-Age $sp[0].CreationDate))
    $spotifyStale = $true
}
else { Add-Check PASS 'Spotify' ('started {0} ago' -f (Format-Age $sp[0].CreationDate)) }

if (@($procs | Where-Object { $_.Name -eq 'claude.exe' }).Count) { Add-Check PASS 'Claude app' 'running (scheduled checks fire only while it is open)' }
else { Add-Check WARN 'Claude app' 'not running; a scheduled morning check fires only while it is open' }

# Sleep: a timeout shorter than the trace is fine only while PowerToys Awake holds the PC awake.
$source = if ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Offline') { 'DC' } else { 'AC' }
$standby = Get-PowerTimeout SUB_SLEEP STANDBYIDLE $source
$hibernate = Get-PowerTimeout SUB_SLEEP HIBERNATEIDLE $source
$display = Get-PowerTimeout SUB_VIDEO VIDEOIDLE $source
$sleepText = 'on {0}: sleep after {1}, hibernate after {2}' -f $source, (Format-Timeout $standby), (Format-Timeout $hibernate)
$traceSeconds = $DurationMinutes * 60 + 300
if ($null -eq $standby) { Add-Check WARN 'sleep' 'could not read the sleep timeout (powercfg)' }
elseif (-not @(@($standby, $hibernate) | Where-Object { $null -ne $_ -and $_ -gt 0 -and $_ -lt $traceSeconds }).Count) { Add-Check PASS 'sleep' "$sleepText; neither comes before the trace ends" }
else {
    $awake = @($procs | Where-Object { $_.Name -eq 'PowerToys.Awake.exe' })
    $mode = $null; $expiry = $null
    try {
        $json = Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Awake\settings.json') -Raw | ConvertFrom-Json
        $mode = [int]$json.properties.mode
        $expiry = [datetime]$json.properties.expirationDateTime
    } catch { }
    if (-not $awake.Count) { Add-Check FAIL 'sleep' "$sleepText, before the trace ends. Start PowerToys Awake (keep awake indefinitely) or raise the timeout" }
    elseif ($mode -eq 1) { Add-Check PASS 'sleep' "$sleepText, but PowerToys Awake keeps it awake indefinitely" }
    elseif ($mode -eq 3 -and $expiry -and $expiry -gt $endAt) { Add-Check PASS 'sleep' ('{0}, but PowerToys Awake keeps it awake until {1:ddd HH:mm}' -f $sleepText, $expiry) }
    elseif ($mode -eq 2) { Add-Check WARN 'sleep' ('{0}; PowerToys Awake is on a timer: check it runs past {1:ddd HH:mm}' -f $sleepText, $endAt) }
    else { Add-Check FAIL 'sleep' "$sleepText, before the trace ends, and PowerToys Awake is not keeping it awake (mode $mode). Set it to keep awake indefinitely" }
}
Add-Check INFO 'display' ('turns off after {0}' -f (Format-Timeout $display))

$pending = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' | Where-Object { Test-Path -LiteralPath $_ })
if ($pending.Count) { Add-Check WARN 'restart' 'Windows has a restart pending; an update could restart the PC overnight' }
else { Add-Check PASS 'restart' 'none pending' }

$drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($TraceRoot))
$freeGb = $drive.AvailableFreeSpace / 1GB
Add-Check $(if ($freeGb -ge 1) { 'PASS' } else { 'FAIL' }) 'disk' ('{0:N1} GB free on {1}' -f $freeGb, $drive.Name)

Write-Host "Sampling CPU and HWiNFO for $SampleSeconds s..." -ForegroundColor Cyan
$hwBefore = Read-HwinfoExport
$a = Get-ParallaxPerfSnapshot
Start-Sleep -Seconds $SampleSeconds
$b = Get-ParallaxPerfSnapshot
$hwAfter = Read-HwinfoExport
$sec = Get-ParallaxElapsedSeconds $a.Timestamp $b.Timestamp

if (-not $hw.Count) { Add-Check FAIL 'HWiNFO' 'not running; the trace would record no temperatures or fan speeds' }
elseif ($null -eq $hwBefore -or $null -eq $hwAfter) { Add-Check FAIL 'HWiNFO' 'no registry export (HKCU\Software\HWiNFO64\VSB); turn it on in HWiNFO''s settings' }
else {
    $changed = @($hwAfter.Raw.Keys | Where-Object { $hwBefore.Raw[$_] -ne $hwAfter.Raw[$_] }).Count
    if ($changed -gt 0) { Add-Check PASS 'HWiNFO' ('export live: {0} of {1} values changed in {2} s; the trace records {3} of them (temperatures, fans, power)' -f $changed, $hwAfter.Raw.Count, $SampleSeconds, $hwAfter.Traced) }
    else { Add-Check FAIL 'HWiNFO' ('export frozen: none of {0} values changed in {1} s. Open HWiNFO''s sensors window (minimised is fine, closed is not)' -f $hwAfter.Raw.Count, $SampleSeconds) }
}

$by = @{}
foreach ($d in [ParallaxPerfNative]::Diff($a.Processes, $b.Processes)) {
    if ($d.Pid -eq $PID) { continue }
    $name = [string]$d.Name
    $by[$name] = [double]$by[$name] + $d.CpuDelta / 1e7 / $sec * 100
}
$defender = [double]$by['MsMpEng.exe']; $claudeCpu = [double]$by['claude.exe']
$inputHost = [double]$by['TextInputHost.exe']; $spotify = [double]$by['Spotify.exe']
$rest = 0.0; $total = 0.0
foreach ($k in $by.Keys) {
    if ($k -in 'Idle', '') { continue }
    $total += $by[$k]
    if ($k -notin 'TextInputHost.exe', 'Rainmeter.exe', 'audiodg.exe', 'MsMpEng.exe', 'claude.exe') { $rest += $by[$k] }
}
$top = ($by.GetEnumerator() | Where-Object { $_.Key -notin 'Idle', '' } | Sort-Object Value -Descending | Select-Object -First 4 | ForEach-Object { '{0} {1:N1}' -f ($_.Key -replace '\.exe$'), $_.Value }) -join ', '
$quiet = $defender -lt 15 -and $claudeCpu -lt 25 -and $rest -lt 150
Add-Check $(if ($quiet) { 'PASS' } else { 'WARN' }) 'quiet' ('Defender {0:N1}, Claude {1:N1}, everything else {2:N1} (limits 15 / 25 / 150% of a core)' -f $defender, $claudeCpu, $rest)
Add-Check INFO 'busiest' ('{0}  (% of a core; machine {1:N1}% of all {2} cores)' -f $top, ($total / [Environment]::ProcessorCount), [Environment]::ProcessorCount)
if ($inputHost -gt 5) { Add-Check WARN 'TextInputHost' ('{0:N1}% of a core: running away again; end it before tracing' -f $inputHost) }
if ($spotify -gt 10) {
    Add-Check WARN 'Spotify' ('{0:N1}% of a core while sampled (an open window keeps its renderer drawing); restart it minimised first' -f $spotify)
    $spotifyStale = $true
}
Add-Check INFO 'Parallax' ('Rainmeter {0:N1}%, audiodg {1:N1}% of a core' -f [double]$by['Rainmeter.exe'], [double]$by['audiodg.exe'])

$fails = @($checks | Where-Object { $_.Status -eq 'FAIL' })
$warns = @($checks | Where-Object { $_.Status -eq 'WARN' })
Write-Host ''
if ($fails.Count) { Write-Host ('Not ready: {0} failed check(s). Fix them and run this again.' -f $fails.Count) -ForegroundColor Red; exit 1 }
if ($PreflightOnly) {
    if ($warns.Count) { Write-Host ('Ready, with {0} warning(s). Nothing was started.' -f $warns.Count) -ForegroundColor Yellow }
    else { Write-Host 'Ready. Nothing was started.' -ForegroundColor Green }
    exit 0
}

if ($leakMissing) {
    $startLogger = [bool]$StartLeakLogger
    if (-not $startLogger -and -not $Force) { $startLogger = (Read-Host 'Start the leak logger now? [Y/n]') -notmatch '^\s*n' }
    if ($startLogger -and (Test-Path -LiteralPath $leakStop)) { Write-Host 'Not starting the leak logger: leak-watch.stop exists.' -ForegroundColor Yellow }
    elseif ($startLogger) {
        $loggerPid = Start-Detached ('"{0}" -MTA -NoProfile -ExecutionPolicy Bypass -File "{1}"' -f $psExe, $leakScript) $LeakWatchDir
        Start-Sleep -Seconds 5
        if (Get-Process -Id $loggerPid -ErrorAction SilentlyContinue) {
            Write-Host "Leak logger started: pid $loggerPid." -ForegroundColor Green
            $warns = @($warns | Where-Object { $_.Name -ne 'leak logger' })
        }
        else { Write-Host "The leak logger exited at once; see $LeakWatchDir." -ForegroundColor Red }
    }
}
if ($spotifyStale) {
    $restart = [bool]$RestartSpotify
    if (-not $restart -and -not $Force) { $restart = (Read-Host 'Restart Spotify now? Playback stops, and it reopens minimised. [Y/n]') -notmatch '^\s*n' }
    if ($restart) {
        $main = @(Get-CimInstance Win32_Process -Filter "Name='Spotify.exe'" | Where-Object { $_.CommandLine -notmatch '--type=' } | Select-Object -First 1)
        $exe = if ($main.Count) { [string]$main[0].ExecutablePath } else { '' }
        if (-not $exe -or $exe -match '\\WindowsApps\\') { Write-Host 'Not restarting Spotify: this is the Microsoft Store version (or its path is unreadable); restart it yourself.' -ForegroundColor Yellow }
        else {
            Get-Process -Name Spotify -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Wait-Process -Name Spotify -Timeout 15 -ErrorAction SilentlyContinue
            if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { Write-Host 'Spotify did not close; restart it yourself.' -ForegroundColor Yellow }
            else {
                $null = Start-Detached ('"{0}" --minimized' -f $exe) (Split-Path -Parent $exe) 7
                Write-Host 'Spotify reopened minimised; letting it settle for 20 s, then measuring for 10 s...' -ForegroundColor Cyan
                Start-Sleep -Seconds 20
                $spotifyNow = Measure-ProcessCpu 'Spotify.exe' 10
                if ($spotifyNow -le 10) {
                    Write-Host ('Spotify restarted: {0:N1}% of a core now.' -f $spotifyNow) -ForegroundColor Green
                    $warns = @($warns | Where-Object { $_.Name -ne 'Spotify' })
                }
                else { Write-Host ('Spotify restarted but is still at {0:N1}% of a core.' -f $spotifyNow) -ForegroundColor Yellow }
            }
        }
    }
}
if ($warns.Count -and -not $Force) {
    if ((Read-Host ('{0} warning(s) above. Start the trace anyway? [y/N]' -f $warns.Count)) -notmatch '^\s*y') { Write-Host 'Not started.'; exit 2 }
}

$launchDir = Join-Path $outDir 'launch'
$null = New-Item -ItemType Directory -Path $launchDir -Force
$launchTime = Get-Date
$log = Join-Path $launchDir ('{0:yyyyMMddTHHmmss}-{1}.log' -f $launchTime, $Label)
$errorLog = $log -replace '\.log$', '.error.log'
$minutes = $DurationMinutes.ToString([Globalization.CultureInfo]::InvariantCulture)
# The command line names Trace-ParallaxLive.ps1 in clear, so other tools can find the trace by it.
$inner = 'try { & ' + (Quote $tracer) + " -DurationMinutes $minutes -IntervalSeconds $IntervalSeconds -Label " + (Quote $Label) +
    ' *>&1 | Out-File -LiteralPath ' + (Quote $log) + ' -Encoding utf8 -Width 300 } catch { (''FAILED: '' + $_) | Out-File -LiteralPath ' + (Quote $errorLog) + ' -Encoding utf8; exit 1 }'
$tracePid = Start-Detached ('"{0}" -NoProfile -ExecutionPolicy Bypass -Command "{1}"' -f $psExe, $inner) $TraceRoot
Write-Host "Started the trace: pid $tracePid. Waiting for its first rows..." -ForegroundColor Cyan

$csv = $null; $rows = 0
$deadline = (Get-Date).AddSeconds(60 + 3 * $IntervalSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Id $tracePid -ErrorAction SilentlyContinue)) { break }
    if (-not $csv) {
        $csv = Get-ChildItem -LiteralPath $outDir -Filter "*-$Label.csv" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -ge $launchTime.AddSeconds(-5) } | Sort-Object CreationTime -Descending | Select-Object -First 1
    }
    if ($csv) { $rows = @(Get-Content -LiteralPath $csv.FullName).Count - 1; if ($rows -ge 2) { break } }
}

if (-not (Get-Process -Id $tracePid -ErrorAction SilentlyContinue)) {
    Write-Host 'The trace exited. Its output:' -ForegroundColor Red
    foreach ($f in $log, $errorLog) { if (Test-Path -LiteralPath $f) { Get-Content -LiteralPath $f | Write-Host } }
    exit 1
}
if (-not $csv -or $rows -lt 1) {
    Write-Host ("The trace (pid $tracePid) is running but has written no rows yet. Check $outDir in a minute; stop it with Stop-Process -Id $tracePid.") -ForegroundColor Yellow
    exit 1
}
Write-Host ''
Write-Host ('Recording: pid {0}, {1} rows so far.' -f $tracePid, $rows) -ForegroundColor Green
Write-Host ('  CSV          {0}' -f $csv.FullName)
Write-Host ('  console log  {0}' -f $log)
Write-Host ('  ends about   {0:ddd HH:mm}; the summary JSON is written then' -f $launchTime.AddMinutes($DurationMinutes))
Write-Host ('  stop early   Stop-Process -Id {0}  (then no summary JSON is written)' -f $tracePid)
Write-Host 'You can close this window; the trace runs on its own.'
exit 0
