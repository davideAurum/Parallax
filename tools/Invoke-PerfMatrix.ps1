#requires -Version 5.1
<#
.SYNOPSIS
Runs the step-3 build matrix: tools\Benchmark-Parallax.ps1 from each build's own
checkout, in interleaved and rotated trials, then computes every fix's gain
alone and inside all fixes.

.DESCRIPTION
Builds come from tools\New-PerfBuild.ps1 (each holds build\perf-build.json with
its role: baseline, all, plus or minus, and its unit). Per round, every build
runs once per scenario with -Trials 1; the build order and the scenario order
rotate from round to round (see -Order), so drift and thermal state spread over
all builds. Each run uses that build's own Benchmark-Parallax.ps1 and stage
(staged on its first run, then reused with -StageRoot), and its JSON report is
copied into the matrix folder. The matrix refuses builds whose measuring tools
differ (Benchmark-Parallax.ps1, Parallax.Perf.psm1, Stage-Parallax.ps1,
Parallax.Build.psm1) unless -AllowToolDifference, builds that are not clean or
have moved since they were made, and failed builds.

The analysis (tools\Parallax.PerfMatrix.psm1) computes per scenario and metric:
  g_k = cost(baseline) - cost(baseline + k)   m_k = cost(all - k) - cost(all)
  G = cost(baseline) - cost(all)              I = G - sum(g_k)
and classifies I by the rule declared before measuring: synergistic beyond twice
the pooled trial spread, antagonistic below minus that, additive otherwise. It
writes analysis.json and analysis.md into the matrix folder.

-DryRun checks the builds and tools, writes the plan (matrix-plan.json) and
prints the schedule with its estimated duration. It never starts Rainmeter,
and it refuses a matrix folder that already holds a real plan or reports.
-AnalyzeOnly recomputes the analysis from a matrix folder's plan and reports.
Real runs start isolated Rainmeter instances through Benchmark-Parallax.ps1;
they are the orchestrator's to run, one matrix at a time, with nothing else
measuring.

.EXAMPLE
  powershell -File tools\Invoke-PerfMatrix.ps1 -BuildRoot C:\pxab -Prefix s3 -Scenario empty,suite,solo:CPU -Trials 5 -DryRun
  powershell -File tools\Invoke-PerfMatrix.ps1 -BuildRoot C:\pxab -Prefix s3 -Scenario empty,suite -Trials 5 -Preferences live -HardwareAcceleration 1
  powershell -File tools\Invoke-PerfMatrix.ps1 -AnalyzeOnly -MatrixDir build\perf-matrix\20261023T010000
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [string[]]$Build = @(),
    [string]$BuildRoot = 'C:\pxab',
    [string]$Prefix = '',
    [string[]]$Scenario = @('suite'),
    [ValidateRange(1, 25)][int]$Trials = 5,
    [ValidateRange(0, 600)][int]$SettleSeconds = 15,
    [ValidateRange(5, 3600)][int]$MeasureSeconds = 60,
    [ValidateSet('default', 'live')][string]$Preferences = 'default',
    [ValidateSet('default', '0', '1')][string]$HardwareAcceleration = 'default',
    [ValidateSet('BuildMajor', 'ScenarioMajor')][string]$Order = 'BuildMajor',
    [string]$MatrixId = '',
    [string]$MatrixDir = '',
    [string]$Manifest = '',
    [string[]]$Metric = @(),
    [string]$RainmeterPath = '',
    [string]$BenchmarkRelativePath = 'tools\Benchmark-Parallax.ps1',
    [string[]]$InstrumentFiles = @('tools\Benchmark-Parallax.ps1', 'tools\Parallax.Perf.psm1', 'tools\Stage-Parallax.ps1', 'tools\Parallax.Build.psm1'),
    [string]$PowerShellPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'),
    [switch]$AllowToolDifference,
    [switch]$Resume,
    [switch]$DryRun,
    [switch]$AnalyzeOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.PerfBuild.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Parallax.PerfMatrix.psm1') -Force

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), $utf8) }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
if (-not $Metric.Count) { $Metric = @(Get-ParallaxPerfDefaultMetrics) }
$Scenario = @($Scenario | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# --------------------------------------------------------------------------
# Analysis (also the tail of every run).
# --------------------------------------------------------------------------
function Invoke-Analysis([string]$Folder) {
    $plan = Read-Json (Join-Path $Folder 'matrix-plan.json')
    $trials = [Collections.Generic.List[object]]::new()
    $missing = [Collections.Generic.List[string]]::new()
    foreach ($item in @($plan.Schedule)) {
        $reportPath = Join-Path $Folder ("reports\{0}\{1}.json" -f $item.Build, $item.Label)
        if (-not (Test-Path -LiteralPath $reportPath)) { $missing.Add($item.Label); continue }
        $report = Read-Json $reportPath
        $found = @{}
        foreach ($row in @($report.Trialwise)) {
            $copy = [ordered]@{ Build = $item.Build; Round = $item.Round; Scenario = $row.Scenario }
            foreach ($metric in $plan.Metrics) { $copy[$metric] = $(if ($row.PSObject.Properties[$metric]) { $row.$metric } else { $null }) }
            $trials.Add([pscustomobject]$copy)
            $found[$row.Scenario] = $true
        }
        foreach ($scenario in @($item.Scenarios)) { if (-not $found.ContainsKey($scenario)) { $missing.Add("$($item.Label):$scenario") } }
    }
    $builds = @($plan.Builds | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Role = $_.Role; UnitKey = $_.UnitKey; Fixes = @($_.Fixes) } })
    $assumable = @{}
    foreach ($entry in @($plan.Assumable)) { $assumable[$entry.Fix] = $entry.Reason }
    $analysis = Invoke-ParallaxPerfMatrixAnalysis -Builds $builds -Trials $trials.ToArray() -Metrics @($plan.Metrics) -AllFixes @($plan.AllFixes) -Assumable $assumable
    $analysis.MissingTrials = @($missing)
    $analysis.Matrix = $plan.MatrixId
    $analysis.Configuration = $plan.Configuration
    Write-Json (Join-Path $Folder 'analysis.json') $analysis
    $header = [ordered]@{
        Title = "Step 3 build matrix $($plan.MatrixId)"
        Configuration = ('preferences {0}, hardware acceleration {1}, {2} round(s), settle {3} s, window {4} s, order {5}' -f $plan.Configuration.Preferences,
            $plan.Configuration.HardwareAcceleration, $plan.Configuration.Rounds, $plan.Configuration.SettleSeconds, $plan.Configuration.MeasureSeconds, $plan.Configuration.Order)
        Builds = (@($plan.Builds | ForEach-Object { '{0} ({1}{2}, {3})' -f $_.Name, $_.Role, $(if ($_.UnitKey) { ' ' + $_.UnitKey } else { '' }), $_.Head.Substring(0, 9) }) -join '; ')
    }
    if ($missing.Count) { $header['Missing trials'] = "$($missing.Count): $(@($missing | Select-Object -First 8) -join ', ')$(if ($missing.Count -gt 8) { ', ...' })" }
    [IO.File]::WriteAllText((Join-Path $Folder 'analysis.md'), (ConvertTo-ParallaxPerfMatrixMarkdown -Analysis $analysis -Header $header), $utf8)
    Write-Host "Analysis: $(Join-Path $Folder 'analysis.md')" -ForegroundColor Green
    if ($missing.Count) { Write-Host "Missing trials: $($missing.Count)" -ForegroundColor Yellow }
    $analysis
}

if ($AnalyzeOnly) {
    if (-not $MatrixDir) { throw '-AnalyzeOnly needs -MatrixDir.' }
    $null = Invoke-Analysis ([IO.Path]::GetFullPath($MatrixDir))
    return
}

# --------------------------------------------------------------------------
# Builds: records, roles, cleanliness, identical measuring tools.
# --------------------------------------------------------------------------
$paths = [Collections.Generic.List[string]]::new()
foreach ($path in @($Build | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) { $paths.Add([IO.Path]::GetFullPath($path)) }
if ($Prefix) {
    if (-not (Test-Path -LiteralPath $BuildRoot)) { throw "Build root not found: $BuildRoot" }
    foreach ($folder in @(Get-ChildItem -LiteralPath $BuildRoot -Directory | Where-Object { $_.Name -like "$Prefix-*" } | Sort-Object Name)) {
        if (Test-Path -LiteralPath (Get-ParallaxPerfBuildRecordPath $folder.FullName)) { $paths.Add($folder.FullName) }
    }
}
if (-not $paths.Count) { throw 'No builds: pass -Build <paths> or -BuildRoot with -Prefix.' }

$builds = [Collections.Generic.List[object]]::new()
$problems = [Collections.Generic.List[string]]::new()
$instrumentHashes = @{}
foreach ($path in $paths) {
    $record = Read-ParallaxPerfBuild -BuildPath $path
    if ($record.Status -ne 'ok') { $problems.Add("$($record.Name): build status is '$($record.Status)'"); continue }
    $head = (Invoke-ParallaxGit -Directory $path -Arguments @('rev-parse', 'HEAD')).Stdout.Trim()
    if ($head -ne $record.Head) { $problems.Add("$($record.Name): HEAD moved since the build was made ($head, record $($record.Head))") }
    $dirty = (Invoke-ParallaxGit -Directory $path -Arguments @('status', '--porcelain')).Stdout.Trim()
    if ($dirty) { $problems.Add("$($record.Name): working tree is not clean") }
    $hashes = [ordered]@{}
    foreach ($relative in $InstrumentFiles) {
        $file = Join-Path $path $relative
        $hashes[$relative] = $(if (Test-Path -LiteralPath $file -PathType Leaf) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash } else { 'missing' })
    }
    $instrumentHashes[$record.Name] = $hashes
    if (-not (Test-Path -LiteralPath (Join-Path $path $BenchmarkRelativePath) -PathType Leaf)) { $problems.Add("$($record.Name): no $BenchmarkRelativePath") }
    $role = if ($record.Role) { $record.Role } else { 'other' }
    $within = if ($record.PSObject.Properties['Within']) { @($record.Within | Where-Object { $_ }) } else { @() }
    $builds.Add([pscustomobject][ordered]@{
        Name = $record.Name; Path = $path; Role = $role; UnitKey = (@($record.Unit) -join ','); Fixes = @($record.Fixes); Within = $within
        Head = $record.Head; Start = $record.Start; ScopeDigest = $record.ScopeDigest; Manifest = $record.Manifest; Instruments = $hashes
    })
}
$names = @($builds | ForEach-Object { $_.Name })
if (@($names | Select-Object -Unique).Count -ne $names.Count) { $problems.Add('Two builds share a name.') }
foreach ($relative in $InstrumentFiles) {
    $distinct = @($builds | ForEach-Object { $_.Instruments[$relative] } | Select-Object -Unique)
    if ($distinct.Count -gt 1 -or $distinct -contains 'missing') {
        $message = "Measuring tool $relative differs between builds or is missing: " + (@($builds | ForEach-Object { "$($_.Name)=$($_.Instruments[$relative].Substring(0, [math]::Min(8, $_.Instruments[$relative].Length)))" }) -join ', ')
        if ($AllowToolDifference) { Write-Warning $message } else { $problems.Add($message + ' (pass -AllowToolDifference only if the difference cannot affect the measurement)') }
    }
}
$digests = @($builds | Group-Object ScopeDigest | Where-Object { $_.Count -gt 1 -and $_.Name })
foreach ($group in $digests) { Write-Warning ("Builds with identical runtime trees: {0}. Their difference is noise by construction (a useful control)." -f (@($group.Group | ForEach-Object Name) -join ', ')) }
if (@($builds | Where-Object Role -eq 'baseline').Count -gt 1 -or @($builds | Where-Object Role -eq 'all').Count -gt 1) { $problems.Add('At most one baseline and one all build per matrix.') }
foreach ($role in 'plus', 'minus') {
    $keys = @($builds | Where-Object Role -eq $role | ForEach-Object UnitKey)
    if (@($keys | Select-Object -Unique).Count -ne $keys.Count) { $problems.Add("Two $role builds measure the same unit.") }
}
if ($problems.Count) { throw ("Matrix refused:`n  " + ($problems -join "`n  ")) }
# Plus and minus pair by unit; -IncludeRequired / -IncludeDependents can give
# them different fixes, and the analysis then marks the unit not comparable.
foreach ($plusBuild in @($builds | Where-Object Role -eq 'plus')) {
    $partner = @($builds | Where-Object { $_.Role -eq 'minus' -and $_.UnitKey -eq $plusBuild.UnitKey }) | Select-Object -First 1
    if ($partner -and ((@($plusBuild.Fixes | Sort-Object) -join ',') -cne (@($partner.Fixes | Sort-Object) -join ','))) {
        Write-Warning ("Unit {0}: {1} holds {2} but {3} holds {4}. g and m measure different changes; the analysis marks the unit not comparable." -f $plusBuild.UnitKey, $plusBuild.Name, (@($plusBuild.Fixes) -join ', '), $partner.Name, (@($partner.Fixes) -join ', '))
    }
}

# The manifest gives the all build's fixes and which unmeasured fixes may count as zero.
if (-not $Manifest) {
    $fromRecords = @($builds | Where-Object { $_.Manifest } | ForEach-Object Manifest | Select-Object -Unique)
    if ($fromRecords.Count -gt 1) { throw "Builds were made from different manifests: $($fromRecords -join ', '). Pass -Manifest." }
    if ($fromRecords.Count -eq 1) { $Manifest = $fromRecords[0] }
}
$allFixes = @(); $assumable = @()
# A sub-matrix (New-PerfBuild -Within) compares against its own 'all'.
$withinSets = @($builds | Where-Object { $_.Role -in 'all', 'minus' } | ForEach-Object { (@($_.Within) -join ',') } | Select-Object -Unique)
if ($withinSets.Count -gt 1) { throw "The all and minus builds were made with different -Within sets: $($withinSets -join ' | ')" }
if ($Manifest) {
    $fixManifest = Read-ParallaxFixManifest -Path $Manifest
    $allFixes = @($fixManifest.Fixes.Keys)
    $sub = @($builds | Where-Object Role -eq 'all' | ForEach-Object { @($_.Within) })
    if ($sub.Count) { $allFixes = @($sub); Write-Host "Sub-matrix: all = baseline + $($sub -join ', ')" -ForegroundColor Cyan }
    $assumable = @($fixManifest.Fixes.Values | Where-Object { $_.isolatedEffect -ne 'expected' } | ForEach-Object { [pscustomobject]@{ Fix = $_.id; Reason = "isolatedEffect $($_.isolatedEffect)" } })
} else {
    Write-Warning 'No fix manifest: the interaction cannot be classified (the all build''s fix list is unknown).'
}

# --------------------------------------------------------------------------
# Plan.
# --------------------------------------------------------------------------
if (-not $MatrixId) { $MatrixId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss') }
if ($MatrixId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$') { throw "Invalid -MatrixId: $MatrixId" }
if (-not $MatrixDir) { $MatrixDir = Join-Path $projectRoot "build\perf-matrix\$MatrixId" }
$MatrixDir = [IO.Path]::GetFullPath($MatrixDir)
$planPath = Join-Path $MatrixDir 'matrix-plan.json'
$schedule = @(New-ParallaxPerfSchedule -Builds $names -Scenarios $Scenario -Rounds $Trials -Order $Order -MatrixId $MatrixId)
$configuration = [ordered]@{
    Preferences = $Preferences; HardwareAcceleration = $HardwareAcceleration; Rounds = $Trials; SettleSeconds = $SettleSeconds
    MeasureSeconds = $MeasureSeconds; Order = $Order; Scenarios = @($Scenario); Benchmark = $BenchmarkRelativePath
}
# Per trial: the benchmark's settle and window, about 12 s of start, load and
# stop, and about 4 s of PowerShell start per invocation.
$trialSeconds = $SettleSeconds + $MeasureSeconds + 12
$estimate = [TimeSpan]::FromSeconds((@($schedule | ForEach-Object { $_.Scenarios.Count * $trialSeconds + 4 }) | Measure-Object -Sum).Sum)
$plan = [ordered]@{
    Schema = 1; MatrixId = $MatrixId; CreatedUtc = [DateTime]::UtcNow.ToString('o'); DryRun = [bool]$DryRun
    Configuration = $configuration; Metrics = @($Metric); Manifest = $Manifest; AllFixes = @($allFixes); Assumable = @($assumable)
    Builds = @($builds | ForEach-Object { [ordered]@{ Name = $_.Name; Path = $_.Path; Role = $_.Role; UnitKey = $_.UnitKey; Fixes = @($_.Fixes); Head = $_.Head; Start = $_.Start; ScopeDigest = $_.ScopeDigest; Instruments = $_.Instruments } })
    Schedule = @($schedule | ForEach-Object { [ordered]@{ Slot = $_.Slot; Round = $_.Round; Build = $_.Build; Scenarios = @($_.Scenarios); Label = $_.Label } })
    EstimatedDuration = $estimate.ToString()
}
$reportsPath = Join-Path $MatrixDir 'reports'
if ($DryRun) {
    # A dry run may only replace another dry run's plan: replacing a real
    # matrix's plan would orphan or mismatch its collected reports.
    $realPlan = (Test-Path -LiteralPath $planPath) -and -not (Read-Json $planPath).DryRun
    if ($realPlan -or (Test-Path -LiteralPath $reportsPath)) {
        throw "Matrix folder already holds a matrix that has run or started: $MatrixDir. A dry run would replace its plan; dry-run into a new -MatrixId or -MatrixDir."
    }
}
if ((Test-Path -LiteralPath $planPath) -and -not $Resume -and -not $DryRun) {
    # A dry run's plan may be replaced by the real run, as long as nothing ran.
    $previous = Read-Json $planPath
    if (-not ($previous.DryRun -and -not (Test-Path -LiteralPath $reportsPath))) {
        throw "Matrix folder already has a plan: $MatrixDir. Pass -Resume to continue it, or a new -MatrixId."
    }
}
if (-not (Test-Path -LiteralPath $MatrixDir)) { $null = New-Item -ItemType Directory -Path $MatrixDir -Force }
if ($Resume -and (Test-Path -LiteralPath $planPath)) {
    $previous = Read-Json $planPath
    $same = (($previous.Schedule | ForEach-Object Label) -join '|') -eq (($plan.Schedule | ForEach-Object { $_.Label }) -join '|')
    if (-not $same) { throw 'The resumed matrix has a different schedule; use the same builds, scenarios, rounds, order and -MatrixId.' }
}
Write-Json $planPath $plan

$roles = @($builds | ForEach-Object { '{0} {1}{2}' -f $_.Name, $_.Role, $(if ($_.UnitKey) { " ($($_.UnitKey))" } else { '' }) }) -join ', '
Write-Host ("Matrix {0}: {1} build(s) [{2}]" -f $MatrixId, $builds.Count, $roles) -ForegroundColor Cyan
Write-Host ("  scenarios {0}; {1} round(s), order {2}; preferences {3}; hardware acceleration {4}" -f ($Scenario -join ','), $Trials, $Order, $Preferences, $HardwareAcceleration)
Write-Host ("  {0} benchmark invocation(s), {1} trial(s); estimated {2}" -f $schedule.Count, (@($schedule | ForEach-Object { $_.Scenarios.Count }) | Measure-Object -Sum).Sum, $estimate)
Write-Host "  plan: $planPath"
if ($DryRun) {
    foreach ($item in $schedule) { Write-Host ("  [{0,3}] round {1} {2,-14} {3} -> label {4}" -f $item.Slot, $item.Round, $item.Build, ($item.Scenarios -join ','), $item.Label) }
    Write-Host 'Dry run: no benchmark started.' -ForegroundColor Yellow
    return [pscustomobject]$plan
}

# --------------------------------------------------------------------------
# Run. One isolated benchmark at a time; reports collected centrally.
# --------------------------------------------------------------------------
$runLogPath = Join-Path $MatrixDir 'matrix-run.json'
$runLog = [Collections.Generic.List[object]]::new()
if ($Resume -and (Test-Path -LiteralPath $runLogPath)) { foreach ($entry in @((Read-Json $runLogPath).Runs)) { $runLog.Add($entry) } }
$stages = @{}
foreach ($entry in $runLog) { if ($entry.StageRoot -and -not $stages.ContainsKey($entry.Build)) { $stages[$entry.Build] = $entry.StageRoot } }
$byName = @{}
foreach ($b in $builds) { $byName[$b.Name] = $b }
$logFolder = Join-Path $MatrixDir 'logs'
if (-not (Test-Path -LiteralPath $logFolder)) { $null = New-Item -ItemType Directory -Path $logFolder }

foreach ($item in $schedule) {
    $buildInfo = $byName[$item.Build]
    $reportFolder = Join-Path $MatrixDir "reports\$($item.Build)"
    $target = Join-Path $reportFolder "$($item.Label).json"
    if (Test-Path -LiteralPath $target) { Write-Host ("[{0}/{1}] {2}: already collected" -f $item.Slot, $schedule.Count, $item.Label) -ForegroundColor DarkGray; continue }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $buildInfo.Path $BenchmarkRelativePath),
        '-Scenario', ($item.Scenarios -join ','), '-Trials', '1', '-SettleSeconds', "$SettleSeconds", '-MeasureSeconds', "$MeasureSeconds",
        '-Preferences', $Preferences, '-HardwareAcceleration', $HardwareAcceleration, '-Label', $item.Label)
    if ($RainmeterPath) { $arguments += @('-RainmeterPath', $RainmeterPath) }
    if ($stages.ContainsKey($item.Build)) { $arguments += @('-StageRoot', $stages[$item.Build]) }
    Write-Host ("[{0}/{1}] {2}: {3} in {4}" -f $item.Slot, $schedule.Count, $item.Label, ($item.Scenarios -join ','), $buildInfo.Path) -ForegroundColor Cyan
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-ParallaxNative -FilePath $PowerShellPath -ArgumentList $arguments -WorkingDirectory $buildInfo.Path
    [IO.File]::WriteAllText((Join-Path $logFolder "$($item.Label).log"), $result.Stdout + "`n--- stderr ---`n" + $result.Stderr, $utf8)
    $entry = [ordered]@{ Slot = $item.Slot; Round = $item.Round; Build = $item.Build; Label = $item.Label; Scenarios = @($item.Scenarios); ExitCode = $result.ExitCode
        Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1); Report = $null; StageRoot = $null; Warnings = @() }
    $source = @(Get-ChildItem -LiteralPath (Join-Path $buildInfo.Path 'build\perf-benchmark') -Filter "*-$Preferences-$($item.Label).json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc)
    if ($source.Count) {
        if (-not (Test-Path -LiteralPath $reportFolder)) { $null = New-Item -ItemType Directory -Path $reportFolder -Force }
        Copy-Item -LiteralPath $source[-1].FullName -Destination $target -Force
        $report = Read-Json $target
        $entry.Report = $target
        if ($report.PSObject.Properties['StageRoot'] -and $report.StageRoot) { $entry.StageRoot = $report.StageRoot; if (-not $stages.ContainsKey($item.Build)) { $stages[$item.Build] = $report.StageRoot } }
        $got = @($report.Trialwise | ForEach-Object Scenario)
        foreach ($scenario in $item.Scenarios) { if ($scenario -notin $got) { $entry.Warnings += "no trial for $scenario (see the log)" } }
    } else {
        $entry.Warnings += 'no report written (see the log)'
    }
    if ($result.ExitCode -ne 0) { $entry.Warnings += "benchmark exited $($result.ExitCode)" }
    foreach ($warning in $entry.Warnings) { Write-Warning "$($item.Label): $warning" }
    $runLog.Add([pscustomobject]$entry)
    Write-Json $runLogPath ([ordered]@{ MatrixId = $MatrixId; Runs = @($runLog.ToArray()) })
}

$null = Invoke-Analysis $MatrixDir
