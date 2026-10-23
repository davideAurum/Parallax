#requires -Version 5.1
<#
.SYNOPSIS
Read-only trace of the running (live) Parallax session and of whole-machine
activity, to attribute quiet-state CPU/GPU spikes and fan activity.

.DESCRIPTION
Every -IntervalSeconds, one NtQuerySystemInformation snapshot gives CPU time for
every process without opening handles. The trace records, as percent of ONE
logical core per interval:

  * the live Rainmeter process: UI (update/draw) thread, other threads, wakeups
  * each live Parallax helper (PowerShell hosts launched by the live skins)
  * audiodg, dwm and HWiNFO64 (audio engine, compositor, sensor provider)
  * whole-machine busy percent (all logical cores) and the top processes
  * GPU engine busy percent for Rainmeter, dwm and audiodg (every -GpuEverySeconds)
  * HWiNFO shared-memory registry values whose labels match -SensorPattern
    (temperatures, fan speeds, power), when HWiNFO's registry export is enabled

It sends no bangs, writes nothing outside build\perf-trace, and never signals or
stops a process. Leave it running overnight with PowerToys Awake to correlate fan
spikes with process activity:

  powershell -File tools\Trace-ParallaxLive.ps1 -DurationMinutes 600 -IntervalSeconds 2
#>
[CmdletBinding()]
param(
    [ValidateRange(0.1, 1440)][double]$DurationMinutes = 10,
    [ValidateRange(1, 60)][int]$IntervalSeconds = 1,
    [ValidateRange(0, 600)][int]$GpuEverySeconds = 10,
    [ValidateRange(1, 20)][int]$TopProcesses = 5,
    [int]$RainmeterPid = 0,
    [string]$LiveSkinPattern = '\Rainmeter\Skins\Parallax\',
    [string]$SensorPattern = 'Temp|Fan|RPM|Power',
    # Other applications to record, summed over all of their processes.
    [string[]]$Watch = @('Spotify.exe'),
    [string]$Label = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.Perf.psm1') -Force

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outDir = Join-Path $projectRoot 'build\perf-trace'
if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Path $outDir -Force }
$stamp = [DateTime]::Now.ToString('yyyyMMddTHHmmss')
$base = Join-Path $outDir ($(if ($Label) { "$stamp-$Label" } else { $stamp }))
$csvPath = "$base.csv"
$topPath = "$base-top.csv"
$summaryPath = "$base-summary.json"
$logical = [Environment]::ProcessorCount
$selfPid = $PID

# The live instance is the longest-running Rainmeter unless one is named.
$first = Get-ParallaxPerfSnapshot -Threads
if ($RainmeterPid -eq 0) {
    $candidates = @($first.Processes | Where-Object { $_.Name -eq 'Rainmeter.exe' } | Sort-Object CreateTime)
    if ($candidates.Count -eq 0) { throw 'No running Rainmeter process.' }
    $RainmeterPid = $candidates[0].Pid
}
if (-not $first.ByPid.ContainsKey($RainmeterPid)) { throw "Rainmeter pid $RainmeterPid not found." }
$rmCreate = $first.ByPid[$RainmeterPid].CreateTime
$mainTid = [ParallaxPerfNative]::SkinWindowThread([uint32]$RainmeterPid)
if ($mainTid -eq 0) { $mainTid = (@($first.ByPid[$RainmeterPid].Threads) | Sort-Object CreateTime | Select-Object -First 1).Tid }

# Live helpers: descendants of the live instance, plus PowerShell hosts started
# from the live skin folder whose launcher has already exited.
$helpers = @{}
function Update-Helpers($Snapshot) {
    foreach ($id in (Get-ParallaxDescendants -Snapshot $Snapshot -RootPids (@($RainmeterPid) + @($helpers.Keys)) -NotBefore $rmCreate)) {
        if (-not $helpers.ContainsKey($id)) { $helpers[$id] = $null }
    }
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
        if ($process.CommandLine -and $process.CommandLine.IndexOf($LiveSkinPattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $helpers[[int]$process.ProcessId] = $process.CommandLine
        }
    }
    foreach ($id in @($helpers.Keys)) {
        if ($null -eq $helpers[$id]) {
            $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
            $helpers[$id] = if ($cim) { [string]$cim.CommandLine } else { '' }
        }
    }
}
function Get-HelperLabel([string]$CommandLine, [int]$Id) {
    foreach ($pair in @(@('conhost', 'Console'), @('SourceProvider', 'MediaSource'), @('QueueProvider', 'MediaQueue'), @('DriverTemp', 'GPUHost'), @('PageFile', 'RAMPageHost'), @('MemoryInfo', 'RAMInfo'), @('AdapterInfo', 'GPUInfo'), @('DiscoverSensors', 'CPUSensors'), @('DriveModels', 'IOModels'))) {
        if ($CommandLine -match $pair[0]) { return $pair[1] }
    }
    "helper$Id"
}
Update-Helpers $first

function Read-Sensors {
    $values = [ordered]@{}
    $key = 'HKCU:\Software\HWiNFO64\VSB'
    if (-not (Test-Path $key)) { return $values }
    $props = Get-ItemProperty $key
    foreach ($property in $props.PSObject.Properties) {
        if ($property.Name -notmatch '^Label(\d+)$') { continue }
        $index = $Matches[1]
        if ($property.Value -notmatch $SensorPattern) { continue }
        $raw = [string]$props."Value$index"
        $sensor = [string]$props."Sensor$index"
        $device = if ($sensor -match 'GPU') { 'GPU' } elseif ($sensor -match 'CPU') { 'CPU' } else { 'SYS' }
        $name = ('{0} {1}' -f $device, $property.Value) -replace '[^A-Za-z0-9 ]', '' -replace '\s+', '_'
        $number = ($raw -replace '[^0-9.\-]', '')
        $values[$name] = $number
    }
    $values
}

$sensorNames = @((Read-Sensors).Keys)
$staticColumns = @('Time', 'Seconds', 'RmMainPct', 'RmOtherPct', 'RmCtxPerSec', 'MainCtxPerSec', 'HelpersPct', 'ParallaxPct', 'HelperStarts', 'AudiodgPct', 'DwmPct', 'HwinfoPct', 'TracerPct', 'MachineBusyPct', 'GpuRainmeterPct', 'GpuDwmPct', 'GpuAudiodgPct')
$helperColumns = [Collections.Generic.List[string]]::new()
foreach ($label in @('MediaSource', 'MediaQueue', 'GPUHost', 'RAMPageHost')) { $helperColumns.Add($label) }
$watchColumns = @($Watch | ForEach-Object { ($_ -replace '\.exe$', '' -replace '[^A-Za-z0-9]', '') + 'Pct' })
$header = (@($staticColumns) + @($helperColumns | ForEach-Object { "$($_)Pct" }) + @($watchColumns) + @($sensorNames)) -join ','
[IO.File]::WriteAllText($csvPath, $header + "`r`n")
[IO.File]::WriteAllText($topPath, "Time,Rank,Process,Pid,Pct`r`n")

Write-Host ("Tracing live Rainmeter pid {0} (UI thread {1}) for {2} min every {3}s; {4} helper(s) found." -f $RainmeterPid, $mainTid, $DurationMinutes, $IntervalSeconds, $helpers.Count) -ForegroundColor Cyan
foreach ($id in $helpers.Keys) { Write-Host ("  helper {0}: {1}" -f $id, (Get-HelperLabel $helpers[$id] $id)) }
Write-Host "CSV: $csvPath"

$rows = [Collections.Generic.List[object]]::new()
$spikeContributors = @{}
$previous = $first
$gpuPrev = $null; $gpuPrevStamp = 0L; $gpuNext = 0.0
$gpuLatest = @{ Rainmeter = ''; Dwm = ''; Audiodg = '' }
$lastHelperScan = [Diagnostics.Stopwatch]::GetTimestamp()
$end = [Diagnostics.Stopwatch]::GetTimestamp() + [long]($DurationMinutes * 60 * [Diagnostics.Stopwatch]::Frequency)
$elapsedTotal = 0.0
$named = @{}
foreach ($process in $first.Processes) { if ($process.Name -in @('audiodg.exe', 'dwm.exe', 'HWiNFO64.EXE', 'HWiNFO64.exe')) { $named[$process.Name.ToLowerInvariant()] = $process.Pid } }

while ([Diagnostics.Stopwatch]::GetTimestamp() -lt $end) {
    Start-Sleep -Seconds $IntervalSeconds
    $now = Get-ParallaxPerfSnapshot -Threads
    if (-not $now.ByPid.ContainsKey($RainmeterPid)) { Write-Warning 'Live Rainmeter exited; stopping.'; break }
    if ((Get-ParallaxElapsedSeconds $lastHelperScan $now.Timestamp) -ge 60) { Update-Helpers $now; $lastHelperScan = $now.Timestamp }
    else { foreach ($id in (Get-ParallaxDescendants -Snapshot $now -RootPids (@($RainmeterPid) + @($helpers.Keys)) -NotBefore $rmCreate)) { if (-not $helpers.ContainsKey($id)) { $helpers[$id] = '' } } }
    $seconds = Get-ParallaxElapsedSeconds $previous.Timestamp $now.Timestamp
    $elapsedTotal += $seconds
    $scale = 100.0 / ($seconds * 1e7)
    $diff = [ParallaxPerfNative]::Diff($previous.Processes, $now.Processes)
    $deltaByPid = @{}
    foreach ($entry in $diff) { $deltaByPid[$entry.Pid] = [double]$entry.CpuDelta }
    function Delta([int]$Id) { if ($deltaByPid.ContainsKey($Id)) { $deltaByPid[$Id] } else { 0.0 } }
    $helperStarts = 0
    foreach ($id in @($helpers.Keys)) { if ($now.ByPid.ContainsKey($id) -and -not $previous.ByPid.ContainsKey($id)) { $helperStarts++ } }
    # Resolve named processes every interval: audiodg exits when the audio engine
    # goes idle and returns with a new pid, and watched apps come and go.
    $named = @{}
    $watchPct = @{}
    foreach ($w in $Watch) { $watchPct[$w.ToLowerInvariant()] = 0.0 }
    foreach ($process in $now.Processes) {
        $lower = $process.Name.ToLowerInvariant()
        if ($lower -in @('audiodg.exe', 'dwm.exe', 'hwinfo64.exe')) { $named[$lower] = $process.Pid }
        if ($watchPct.ContainsKey($lower)) { $watchPct[$lower] += (Delta $process.Pid) * $scale }
    }

    $rmNow = $now.ByPid[$RainmeterPid]; $rmPrev = $previous.ByPid[$RainmeterPid]
    $mainNow = @($rmNow.Threads | Where-Object Tid -eq $mainTid)[0]; $mainPrev = @($rmPrev.Threads | Where-Object Tid -eq $mainTid)[0]
    $mainPct = if ($mainNow -and $mainPrev) { ($mainNow.CpuTime - $mainPrev.CpuTime) * $scale } else { 0.0 }
    $mainCtx = if ($mainNow -and $mainPrev) { ($mainNow.ContextSwitches - $mainPrev.ContextSwitches) / $seconds } else { 0.0 }
    # Sum per-thread deltas so threads that exit between snapshots do not subtract.
    $prevCtx = @{}; foreach ($t in $rmPrev.Threads) { $prevCtx[$t.Tid] = $t.ContextSwitches }
    $ctxNow = 0L; $ctxPrev = 0L
    foreach ($t in $rmNow.Threads) { $ctxNow += $t.ContextSwitches; $ctxPrev += $(if ($prevCtx.ContainsKey($t.Tid)) { $prevCtx[$t.Tid] } else { 0 }) }
    $rmPct = (Delta $RainmeterPid) * $scale

    $helperPct = @{}; $helpersTotal = 0.0
    foreach ($id in @($helpers.Keys)) {
        $pct = (Delta $id) * $scale
        $label = Get-HelperLabel ([string]$helpers[$id]) $id
        if (-not $helperPct.ContainsKey($label)) { $helperPct[$label] = 0.0 }
        $helperPct[$label] += $pct
        $helpersTotal += $pct
    }

    $machine = 0.0
    foreach ($entry in $diff) { $machine += $entry.CpuDelta }
    $machineBusy = $machine * $scale / $logical
    $top = @($diff | Sort-Object CpuDelta -Descending | Select-Object -First $TopProcesses | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Pid = $_.Pid; Pct = $_.CpuDelta * $scale } })

    $gpuDue = $GpuEverySeconds -gt 0 -and $elapsedTotal -ge $gpuNext
    if ($gpuDue) {
        $gpuPids = @($RainmeterPid) + @($named.Values)
        $gpuNow = Get-ParallaxGpuRunningTime -Pids $gpuPids
        $gpuStamp = [Diagnostics.Stopwatch]::GetTimestamp()
        if ($null -ne $gpuPrev) {
            $gs = Get-ParallaxElapsedSeconds $gpuPrevStamp $gpuStamp
            $sum = { param($pidValue) if ($null -eq $pidValue) { return '' } $t = Get-ParallaxGpuPercent -Before $gpuPrev -After $gpuNow -Seconds $gs -Pids @($pidValue); [math]::Round((@($t.Values) | Measure-Object -Sum).Sum + 0.0, 3) }
            $gpuLatest = @{ Rainmeter = (& $sum $RainmeterPid); Dwm = (& $sum $named['dwm.exe']); Audiodg = (& $sum $named['audiodg.exe']) }
        }
        $gpuPrev = $gpuNow; $gpuPrevStamp = $gpuStamp; $gpuNext = $elapsedTotal + $GpuEverySeconds
    }
    else { $gpuLatest = @{ Rainmeter = ''; Dwm = ''; Audiodg = '' } }

    $sensors = Read-Sensors
    $time = [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:ss')
    $row = [ordered]@{
        Time = $time; Seconds = [math]::Round($seconds, 3)
        RmMainPct = [math]::Round($mainPct, 2); RmOtherPct = [math]::Round($rmPct - $mainPct, 2)
        RmCtxPerSec = [math]::Round(($ctxNow - $ctxPrev) / $seconds, 0); MainCtxPerSec = [math]::Round($mainCtx, 0)
        HelpersPct = [math]::Round($helpersTotal, 2); ParallaxPct = [math]::Round($rmPct + $helpersTotal, 2); HelperStarts = $helperStarts
        AudiodgPct = [math]::Round($(if ($named['audiodg.exe']) { (Delta $named['audiodg.exe']) * $scale } else { 0 }), 2)
        DwmPct = [math]::Round($(if ($named['dwm.exe']) { (Delta $named['dwm.exe']) * $scale } else { 0 }), 2)
        HwinfoPct = [math]::Round($(if ($named['hwinfo64.exe']) { (Delta $named['hwinfo64.exe']) * $scale } else { 0 }), 2)
        TracerPct = [math]::Round((Delta $selfPid) * $scale, 2)
        MachineBusyPct = [math]::Round($machineBusy, 2)
        GpuRainmeterPct = $gpuLatest.Rainmeter; GpuDwmPct = $gpuLatest.Dwm; GpuAudiodgPct = $gpuLatest.Audiodg
    }
    foreach ($label in $helperColumns) { $row["$($label)Pct"] = [math]::Round($(if ($helperPct.ContainsKey($label)) { $helperPct[$label] } else { 0 }), 2) }
    for ($i = 0; $i -lt $Watch.Count; $i++) { $row[$watchColumns[$i]] = [math]::Round($watchPct[$Watch[$i].ToLowerInvariant()], 2) }
    foreach ($name in $sensorNames) { $row[$name] = $(if ($sensors.Contains($name)) { $sensors[$name] } else { '' }) }
    [IO.File]::AppendAllText($csvPath, ((@($row.Values) | ForEach-Object { [string]$_ }) -join ',') + "`r`n")
    $topText = for ($i = 0; $i -lt $top.Count; $i++) { '{0},{1},{2},{3},{4:N2}' -f $time, ($i + 1), $top[$i].Name, $top[$i].Pid, $top[$i].Pct }
    if ($topText) { [IO.File]::AppendAllText($topPath, (($topText -join "`r`n") + "`r`n")) }
    $rows.Add([pscustomobject]@{ Row = $row; Top = $top })
    $previous = $now
}

# --------------------------------------------------------------------------
# Summary: distributions, spike intervals and what ran during them.
# --------------------------------------------------------------------------
function Stats([double[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    [ordered]@{
        Mean = [math]::Round(($Values | Measure-Object -Average).Average, 3)
        P50  = [math]::Round((Get-ParallaxPercentile $Values 50), 3)
        P95  = [math]::Round((Get-ParallaxPercentile $Values 95), 3)
        Max  = [math]::Round(($Values | Measure-Object -Maximum).Maximum, 3)
    }
}
$summary = [ordered]@{ RainmeterPid = $RainmeterPid; Intervals = $rows.Count; IntervalSeconds = $IntervalSeconds; LogicalCpus = $logical; Columns = [ordered]@{} }
foreach ($column in @('RmMainPct', 'RmOtherPct', 'RmCtxPerSec', 'MainCtxPerSec', 'HelpersPct', 'ParallaxPct', 'HelperStarts', 'AudiodgPct', 'DwmPct', 'HwinfoPct', 'TracerPct', 'MachineBusyPct') + @($helperColumns | ForEach-Object { "$($_)Pct" }) + @($watchColumns)) {
    $summary.Columns[$column] = Stats @($rows | ForEach-Object { [double]$_.Row[$column] })
}
foreach ($column in @('GpuRainmeterPct', 'GpuDwmPct', 'GpuAudiodgPct')) {
    $summary.Columns[$column] = Stats @($rows | Where-Object { $_.Row[$column] -ne '' } | ForEach-Object { [double]$_.Row[$column] })
}
foreach ($name in $sensorNames) {
    $summary.Columns[$name] = Stats @($rows | Where-Object { $_.Row[$name] -ne '' } | ForEach-Object { [double]$_.Row[$name] })
}
# Spikes: machine-busy intervals above median + 3 * MAD (and at least 2 points).
$busy = @($rows | ForEach-Object { [double]$_.Row.MachineBusyPct })
if ($busy.Count -gt 5) {
    $median = Get-ParallaxPercentile $busy 50
    $mad = Get-ParallaxPercentile @($busy | ForEach-Object { [math]::Abs($_ - $median) }) 50
    $threshold = [math]::Max($median + 3 * $mad, $median + 2)
    $spikes = @($rows | Where-Object { [double]$_.Row.MachineBusyPct -ge $threshold })
    $contributors = @{}
    foreach ($spike in $spikes) { foreach ($entry in $spike.Top) { if (-not $contributors.ContainsKey($entry.Name)) { $contributors[$entry.Name] = 0.0 }; $contributors[$entry.Name] += $entry.Pct } }
    $times = @($spikes | ForEach-Object { [datetime]$_.Row.Time })
    $gaps = @(); for ($i = 1; $i -lt $times.Count; $i++) { $gaps += ($times[$i] - $times[$i - 1]).TotalSeconds }
    $summary['MachineSpikes'] = [ordered]@{
        ThresholdPct = [math]::Round($threshold, 2); Count = $spikes.Count
        TopContributors = @($contributors.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object { [ordered]@{ Process = $_.Key; SumPctInSpikes = [math]::Round($_.Value, 1) } })
        GapSecondsMedian = $(if ($gaps.Count) { Get-ParallaxPercentile $gaps 50 } else { $null })
    }
    $parallax = @($rows | ForEach-Object { [double]$_.Row.ParallaxPct })
    $pm = Get-ParallaxPercentile $parallax 50
    $pmad = Get-ParallaxPercentile @($parallax | ForEach-Object { [math]::Abs($_ - $pm) }) 50
    $pThreshold = [math]::Max($pm + 3 * $pmad, $pm + 2)
    $pTimes = @($rows | Where-Object { [double]$_.Row.ParallaxPct -ge $pThreshold } | ForEach-Object { [datetime]$_.Row.Time })
    $pGaps = @(); for ($i = 1; $i -lt $pTimes.Count; $i++) { $pGaps += ($pTimes[$i] - $pTimes[$i - 1]).TotalSeconds }
    $summary['ParallaxSpikes'] = [ordered]@{ ThresholdPct = [math]::Round($pThreshold, 2); Count = $pTimes.Count; GapSecondsMedian = $(if ($pGaps.Count) { Get-ParallaxPercentile $pGaps 50 } else { $null }) }
}
$summary['Helpers'] = @($helpers.GetEnumerator() | ForEach-Object { [ordered]@{ Pid = $_.Key; Label = (Get-HelperLabel ([string]$_.Value) $_.Key) } })
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ''
Write-Host 'Mean / p95 / max (% of one core unless noted):' -ForegroundColor Green
foreach ($key in $summary.Columns.Keys) {
    $s = $summary.Columns[$key]
    if ($null -ne $s) { Write-Host ("  {0,-22} {1,8:N2} {2,8:N2} {3,8:N2}" -f $key, $s.Mean, $s.P95, $s.Max) }
}
if ($summary.Contains('MachineSpikes')) {
    Write-Host ("Machine spikes >= {0}% of all cores: {1}; top contributors: {2}" -f $summary.MachineSpikes.ThresholdPct, $summary.MachineSpikes.Count, ((@($summary.MachineSpikes.TopContributors) | Select-Object -First 5 | ForEach-Object { "$($_.Process) $($_.SumPctInSpikes)" }) -join ', '))
    Write-Host ("Parallax spikes >= {0}%: {1}, median gap {2}s" -f $summary.ParallaxSpikes.ThresholdPct, $summary.ParallaxSpikes.Count, $summary.ParallaxSpikes.GapSecondsMedian)
}
Write-Host "Summary: $summaryPath"
