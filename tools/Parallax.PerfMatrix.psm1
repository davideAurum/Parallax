#requires -Version 5.1
# Schedule and analysis for the step-3 build matrix (Invoke-PerfMatrix.ps1).
# Pure functions: no process is started and nothing is written here.
#
# Analysis, per scenario and metric (all metrics are costs: lower is better):
#   cost(b) = median of build b's trials
#   g_k = cost(baseline) - cost(baseline + k)     gain of unit k alone
#   m_k = cost(all - k)  - cost(all)              marginal gain of k inside all
#   G   = cost(baseline) - cost(all)              combined gain
#   I   = G - sum(g_k)                            interaction
# Classification, declared before measuring (docs/PERFORMANCE-REVIEW.md, Step 3):
#   synergistic if I > 2 s, antagonistic if I < -2 s, additive otherwise,
#   where s is the pooled trial spread: the pooled sample standard deviation
#   of every build's trials in that scenario and metric,
#   s = sqrt( sum((n_b - 1) * var_b) / sum(n_b - 1) ).
# A unit whose g_k and m_k differ by more than 2 s is flagged as interacting.

Set-StrictMode -Version Latest

$script:DefaultMetrics = @('TotalCpuPct', 'MainCpuPct', 'OtherCpuPct', 'HelperCpuPct', 'TotalP95Pct', 'MainP95Pct',
    'RmCtxPerSec', 'MainCtxPerSec', 'HelperCtxPerSec', 'RmPrivateMB', 'HelperPrivateMB', 'GpuAllPct')
$script:MetricLabels = @{
    TotalCpuPct = 'Total CPU'; MainCpuPct = 'UI thread'; OtherCpuPct = 'Plugin threads'; HelperCpuPct = 'Helpers'
    TotalP95Pct = 'Total p95 s'; MainP95Pct = 'UI p95 s'; RmCtxPerSec = 'Rainmeter wakeups/s'; MainCtxPerSec = 'UI wakeups/s'
    HelperCtxPerSec = 'Helper wakeups/s'; RmPrivateMB = 'Rainmeter private MB'; HelperPrivateMB = 'Helper private MB'
    GpuAllPct = 'GPU %'; Gpu3dPct = 'GPU 3D %'; LoadMs = 'Load ms'; RmWorkingSetMB = 'Rainmeter working set MB'
}

function Get-ParallaxPerfDefaultMetrics { $script:DefaultMetrics }
function Get-ParallaxPerfMetricLabel([string]$Metric) { if ($script:MetricLabels.ContainsKey($Metric)) { $script:MetricLabels[$Metric] } else { $Metric } }

function Get-ParallaxRotated([object[]]$Items, [int]$Shift) {
    $count = $Items.Count
    if ($count -le 1) { return @($Items) }
    $shift = (($Shift % $count) + $count) % $count
    if ($shift -eq 0) { return @($Items) }
    @($Items[$shift..($count - 1)]) + @($Items[0..($shift - 1)])
}

# Interleaved, rotated schedule. BuildMajor: each round runs every build once
# (one Benchmark invocation with every scenario), build order and scenario
# order both rotated by the round. ScenarioMajor: each round walks the
# scenarios, and for each runs every build back to back (one invocation per
# build and scenario), build order rotated by round and scenario, so the
# builds compared in a scenario sit next to each other in time.
function New-ParallaxPerfSchedule {
    param(
        [Parameter(Mandatory)][string[]]$Builds,
        [Parameter(Mandatory)][string[]]$Scenarios,
        [Parameter(Mandatory)][int]$Rounds,
        [ValidateSet('BuildMajor', 'ScenarioMajor')][string]$Order = 'BuildMajor',
        [Parameter(Mandatory)][string]$MatrixId
    )
    $slot = 0
    $list = [Collections.Generic.List[object]]::new()
    for ($round = 1; $round -le $Rounds; $round++) {
        if ($Order -eq 'BuildMajor') {
            $scenarioOrder = Get-ParallaxRotated $Scenarios ($round - 1)
            foreach ($build in (Get-ParallaxRotated $Builds ($round - 1))) {
                $list.Add([pscustomobject]@{ Slot = ++$slot; Round = $round; Build = $build; Scenarios = @($scenarioOrder); Label = "$MatrixId-$build-r$round" })
            }
        } else {
            $scenarioOrder = Get-ParallaxRotated $Scenarios ($round - 1)
            for ($i = 0; $i -lt $scenarioOrder.Count; $i++) {
                $scenario = $scenarioOrder[$i]
                $index = [array]::IndexOf($Scenarios, $scenario)
                foreach ($build in (Get-ParallaxRotated $Builds ($round - 1 + $i))) {
                    $list.Add([pscustomobject]@{ Slot = ++$slot; Round = $round; Build = $build; Scenarios = @($scenario); Label = "$MatrixId-$build-r$round-s$index" })
                }
            }
        }
    }
    $list.ToArray()
}

function Get-ParallaxMedian([double[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $middle = [math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return [double]$sorted[$middle] }
    ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Get-ParallaxVariance([double[]]$Values) {
    if (-not $Values -or $Values.Count -lt 2) { return $null }
    $mean = ($Values | Measure-Object -Average).Average
    $sum = 0.0
    foreach ($value in $Values) { $sum += ($value - $mean) * ($value - $mean) }
    $sum / ($Values.Count - 1)
}

function Get-ParallaxPooledSd([object[]]$Groups) {
    $numerator = 0.0; $degrees = 0
    foreach ($group in $Groups) {
        $values = @($group)
        if ($values.Count -lt 2) { continue }
        $numerator += ($values.Count - 1) * (Get-ParallaxVariance $values)
        $degrees += $values.Count - 1
    }
    if ($degrees -eq 0) { return $null }
    [math]::Sqrt($numerator / $degrees)
}

function Round-Value($Value, [int]$Digits = 3) { if ($null -eq $Value) { $null } else { [math]::Round([double]$Value, $Digits) } }

# Builds: objects with Name, Role (baseline|all|plus|minus|other), UnitKey,
# Fixes. Trials: objects with Build, Scenario and one property per metric.
# AllFixes: every fix the all build contains. Assumable: fixes that may be
# treated as zero when no plus build measures them (isolatedEffect is not
# 'expected'), each with a reason.
function Invoke-ParallaxPerfMatrixAnalysis {
    param(
        [Parameter(Mandatory)][object[]]$Builds,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Trials,
        [string[]]$Metrics = $script:DefaultMetrics,
        [string[]]$AllFixes = @(),
        [hashtable]$Assumable = @{}
    )
    $byName = @{}
    foreach ($build in $Builds) { $byName[$build.Name] = $build }
    $baseline = @($Builds | Where-Object Role -eq 'baseline')
    $all = @($Builds | Where-Object Role -eq 'all')
    if ($baseline.Count -gt 1 -or $all.Count -gt 1) { throw 'A matrix holds at most one baseline and one all build.' }
    $baseline = if ($baseline.Count) { $baseline[0].Name } else { $null }
    $all = if ($all.Count) { $all[0].Name } else { $null }
    $plus = @($Builds | Where-Object Role -eq 'plus')
    $minus = @($Builds | Where-Object Role -eq 'minus')

    # Coverage of the plus units against the all build's fixes.
    $covered = @{}; $overlaps = [Collections.Generic.List[string]]::new()
    foreach ($build in $plus) {
        foreach ($fix in @($build.Fixes)) {
            if ($covered.ContainsKey($fix)) { $overlaps.Add("$fix ($($covered[$fix]), $($build.Name))") } else { $covered[$fix] = $build.Name }
        }
    }
    $missing = @($AllFixes | Where-Object { -not $covered.ContainsKey($_) })
    $assumedZero = @($missing | Where-Object { $Assumable.ContainsKey($_) })
    $unmeasured = @($missing | Where-Object { -not $Assumable.ContainsKey($_) })
    $coverage = [ordered]@{
        AllFixes = @($AllFixes); Covered = @($covered.Keys | Sort-Object); AssumedZero = @($assumedZero)
        AssumedZeroReasons = [ordered]@{}; Unmeasured = @($unmeasured); Overlaps = @($overlaps)
        Complete = ($AllFixes.Count -gt 0 -and $unmeasured.Count -eq 0 -and $overlaps.Count -eq 0)
    }
    foreach ($fix in $assumedZero) { $coverage.AssumedZeroReasons[$fix] = $Assumable[$fix] }

    $unitKeys = [Collections.Generic.List[string]]::new()
    foreach ($build in @($plus) + @($minus)) { if (-not $unitKeys.Contains($build.UnitKey)) { $unitKeys.Add($build.UnitKey) } }

    $scenarios = @($Trials | ForEach-Object { $_.Scenario } | Select-Object -Unique)
    $result = [ordered]@{}
    foreach ($scenario in $scenarios) {
        $rows = @($Trials | Where-Object Scenario -eq $scenario)
        $buildStats = [ordered]@{}
        foreach ($build in $Builds) {
            $mine = @($rows | Where-Object Build -eq $build.Name)
            $stats = [ordered]@{ Role = $build.Role; Unit = $build.UnitKey; N = $mine.Count; Metrics = [ordered]@{} }
            foreach ($metric in $Metrics) {
                $values = @($mine | Where-Object { $null -ne $_.$metric } | ForEach-Object { [double]$_.$metric })
                if (-not $values.Count) { $stats.Metrics[$metric] = $null; continue }
                $variance = Get-ParallaxVariance $values
                $stats.Metrics[$metric] = [ordered]@{
                    Median = Round-Value (Get-ParallaxMedian $values); Min = Round-Value ($values | Measure-Object -Minimum).Minimum
                    Max = Round-Value ($values | Measure-Object -Maximum).Maximum; Sd = $(if ($null -ne $variance) { Round-Value ([math]::Sqrt($variance)) } else { $null })
                    Values = @($values)
                }
            }
            $buildStats[$build.Name] = $stats
        }
        $metricResults = [ordered]@{}
        foreach ($metric in $Metrics) {
            $cost = @{}
            foreach ($name in $buildStats.Keys) { if ($buildStats[$name].Metrics[$metric]) { $cost[$name] = $buildStats[$name].Metrics[$metric].Median } }
            $groups = @($buildStats.Keys | Where-Object { $buildStats[$_].Metrics[$metric] } | ForEach-Object { , @($buildStats[$_].Metrics[$metric].Values) })
            $pooled = Get-ParallaxPooledSd $groups
            $threshold = if ($null -ne $pooled) { 2 * $pooled } else { $null }
            $baseCost = if ($baseline -and $cost.ContainsKey($baseline)) { $cost[$baseline] } else { $null }
            $allCost = if ($all -and $cost.ContainsKey($all)) { $cost[$all] } else { $null }
            $units = [Collections.Generic.List[object]]::new()
            $sumG = 0.0; $gCount = 0
            foreach ($key in $unitKeys) {
                $p = @($plus | Where-Object UnitKey -eq $key) | Select-Object -First 1
                $m = @($minus | Where-Object UnitKey -eq $key) | Select-Object -First 1
                $g = if ($p -and $null -ne $baseCost -and $cost.ContainsKey($p.Name)) { $baseCost - $cost[$p.Name] } else { $null }
                $mk = if ($m -and $null -ne $allCost -and $cost.ContainsKey($m.Name)) { $cost[$m.Name] - $allCost } else { $null }
                if ($null -ne $g) { $sumG += $g; $gCount++ }
                $difference = if ($null -ne $g -and $null -ne $mk) { $g - $mk } else { $null }
                $flag = ''
                if ($null -ne $difference -and $null -ne $threshold -and [math]::Abs($difference) -gt $threshold) {
                    $flag = if ($difference -lt 0) { 'gains more inside all (synergy)' } else { 'gains less inside all (overlap)' }
                }
                $units.Add([pscustomobject][ordered]@{
                    Unit = $key; Fixes = @($(if ($p) { $p.Fixes } elseif ($m) { $m.Fixes } else { @() }))
                    PlusBuild = $(if ($p) { $p.Name } else { $null }); MinusBuild = $(if ($m) { $m.Name } else { $null })
                    g = Round-Value $g; m = Round-Value $mk; GMinusM = Round-Value $difference; Interacts = $flag
                })
            }
            $combined = if ($null -ne $baseCost -and $null -ne $allCost) { $baseCost - $allCost } else { $null }
            $interaction = if ($null -ne $combined -and $gCount -gt 0) { $combined - $sumG } else { $null }
            $class = if ($null -eq $combined) { 'undetermined: baseline or all build not measured' }
                elseif ($gCount -eq 0) { 'undetermined: no baseline + k build measured' }
                elseif ($null -eq $threshold) { 'undetermined: fewer than 2 trials per build' }
                elseif (-not $coverage.Complete) { 'incomplete: the measured units do not cover every fix in all' }
                elseif ($interaction -gt $threshold) { 'synergistic' }
                elseif ($interaction -lt -$threshold) { 'antagonistic' }
                else { 'additive' }
            $metricResults[$metric] = [ordered]@{
                Baseline = Round-Value $baseCost; All = Round-Value $allCost; G = Round-Value $combined; SumG = Round-Value $(if ($gCount) { $sumG } else { $null })
                Interaction = Round-Value $interaction; PooledSd = Round-Value $pooled; Threshold = Round-Value $threshold; Class = $class
                Units = @($units.ToArray())
            }
        }
        $result[$scenario] = [ordered]@{ Builds = $buildStats; Metrics = $metricResults }
    }
    [ordered]@{
        Rule = 'I = G - sum(g_k); synergistic if I > 2s, antagonistic if I < -2s, additive otherwise; s = pooled sample SD of all builds'' trials (per scenario and metric). Units with |g_k - m_k| > 2s are flagged as interacting.'
        Baseline = $baseline; All = $all; Coverage = $coverage; Metrics = @($Metrics); Scenarios = $result
    }
}

function Format-ParallaxNumber($Value, [int]$Digits = 2) {
    if ($null -eq $Value) { return 'n/a' }
    ([double]$Value).ToString('0.' + ('0' * $Digits), [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-ParallaxPerfMatrixMarkdown {
    param(
        [Parameter(Mandatory)]$Analysis,
        [hashtable]$Header = @{},
        [string[]]$CostMetrics = @('TotalCpuPct', 'MainCpuPct', 'OtherCpuPct', 'HelperCpuPct', 'RmCtxPerSec', 'GpuAllPct'),
        [string[]]$UnitMetrics = @('TotalCpuPct', 'MainCpuPct', 'OtherCpuPct', 'HelperCpuPct', 'RmCtxPerSec')
    )
    $lines = [Collections.Generic.List[string]]::new()
    $title = if ($Header.ContainsKey('Title')) { $Header.Title } else { 'Step 3 build matrix' }
    $lines.Add("# $title")
    $lines.Add('')
    foreach ($key in @($Header.Keys | Where-Object { $_ -ne 'Title' } | Sort-Object)) { $lines.Add("- **${key}:** $($Header[$key])") }
    $lines.Add("- **Rule (declared before measuring):** $($Analysis.Rule)")
    $coverage = $Analysis.Coverage
    $lines.Add("- **Coverage:** $(@($coverage.Covered).Count) of $(@($coverage.AllFixes).Count) fixes measured alone" +
        $(if (@($coverage.AssumedZero).Count) { "; assumed zero (not visible to the isolated benchmark): $(@($coverage.AssumedZero) -join ', ')" } else { '' }) +
        $(if (@($coverage.Unmeasured).Count) { "; **not measured:** $(@($coverage.Unmeasured) -join ', ')" } else { '' }) +
        $(if (@($coverage.Overlaps).Count) { "; **overlapping units:** $(@($coverage.Overlaps) -join ', ')" } else { '' }))
    $lines.Add('- CPU in % of one logical core; costs are medians [min-max] of the trials; g, m, G and I are differences of medians.')
    foreach ($scenario in $Analysis.Scenarios.Keys) {
        $data = $Analysis.Scenarios[$scenario]
        $lines.Add('')
        $lines.Add("## Scenario $scenario")
        $lines.Add('')
        $lines.Add('### Cost per build')
        $lines.Add('')
        $lines.Add('| Build | Role | Unit | N | ' + (($CostMetrics | ForEach-Object { Get-ParallaxPerfMetricLabel $_ }) -join ' | ') + ' |')
        $lines.Add('| --- | --- | --- | ---: | ' + (($CostMetrics | ForEach-Object { '---:' }) -join ' | ') + ' |')
        foreach ($name in $data.Builds.Keys) {
            $b = $data.Builds[$name]
            $cells = foreach ($metric in $CostMetrics) {
                $s = $b.Metrics[$metric]
                if ($s) { '{0} [{1}-{2}]' -f (Format-ParallaxNumber $s.Median), (Format-ParallaxNumber $s.Min), (Format-ParallaxNumber $s.Max) } else { 'n/a' }
            }
            $lines.Add("| $name | $($b.Role) | $($b.Unit) | $($b.N) | " + ($cells -join ' | ') + ' |')
        }
        $lines.Add('')
        $lines.Add('### Combined gain and interaction')
        $lines.Add('')
        $lines.Add('| Metric | Baseline | All | G | Sum g | I = G - Sum g | 2s | Class |')
        $lines.Add('| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |')
        foreach ($metric in $data.Metrics.Keys) {
            $r = $data.Metrics[$metric]
            $lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |' -f (Get-ParallaxPerfMetricLabel $metric), (Format-ParallaxNumber $r.Baseline), (Format-ParallaxNumber $r.All),
                (Format-ParallaxNumber $r.G), (Format-ParallaxNumber $r.SumG), (Format-ParallaxNumber $r.Interaction), (Format-ParallaxNumber $r.Threshold), $r.Class))
        }
        $first = $data.Metrics[$UnitMetrics[0]]
        if ($first -and @($first.Units).Count) {
            $lines.Add('')
            $lines.Add('### Per unit: g (alone) / m (inside all)')
            $lines.Add('')
            $lines.Add('| Unit | Fixes | ' + (($UnitMetrics | ForEach-Object { Get-ParallaxPerfMetricLabel $_ }) -join ' | ') + ' | Interacts (abs(g - m) > 2s) |')
            $lines.Add('| --- | --- | ' + (($UnitMetrics | ForEach-Object { '---:' }) -join ' | ') + ' | --- |')
            for ($i = 0; $i -lt @($first.Units).Count; $i++) {
                $unit = $first.Units[$i]
                $flags = [Collections.Generic.List[string]]::new()
                $cells = foreach ($metric in $UnitMetrics) {
                    $u = $data.Metrics[$metric].Units[$i]
                    if ($u.Interacts) { $flags.Add("$(Get-ParallaxPerfMetricLabel $metric): $($u.Interacts)") }
                    '{0} / {1}' -f (Format-ParallaxNumber $u.g), (Format-ParallaxNumber $u.m)
                }
                $lines.Add("| $($unit.Unit) | $(@($unit.Fixes) -join ', ') | " + ($cells -join ' | ') + " | $($flags -join '; ') |")
            }
        }
    }
    ($lines -join "`n") + "`n"
}

Export-ModuleMember -Function Get-ParallaxPerfDefaultMetrics, Get-ParallaxPerfMetricLabel, Get-ParallaxRotated, New-ParallaxPerfSchedule,
    Get-ParallaxMedian, Get-ParallaxVariance, Get-ParallaxPooledSd, Invoke-ParallaxPerfMatrixAnalysis, ConvertTo-ParallaxPerfMatrixMarkdown, Format-ParallaxNumber
