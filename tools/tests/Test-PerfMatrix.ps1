#requires -Version 5.1
# Fixtures for tools/Invoke-PerfMatrix.ps1 and tools/Parallax.PerfMatrix.psm1.
# Never starts Rainmeter: the run loop is exercised with a stand-in benchmark
# script committed into a scratch repository, whose builds come from
# tools/New-PerfBuild.ps1. Removes its own temp folder.
[CmdletBinding()]
param([string]$Python = 'python')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $toolsRoot 'Parallax.PerfBuild.psm1') -Force
Import-Module (Join-Path $toolsRoot 'Parallax.PerfMatrix.psm1') -Force
$script:assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}
function Assert-Near($Actual, [double]$Expected, [string]$Message) {
    Assert-True ($null -ne $Actual -and [math]::Abs([double]$Actual - $Expected) -lt 1e-6) "$Message (expected $Expected, got $Actual)"
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $script:assertions++
    $text = $null
    try { $null = & $Action } catch { $text = $_.Exception.Message }
    if ($null -eq $text) { throw "Assertion failed (no error): $Message" }
    if ($text -notmatch $Pattern) { throw "Assertion failed: $Message. Error was: $text" }
}

# --------------------------------------------------------------------------
# Schedule.
# --------------------------------------------------------------------------
$schedule = @(New-ParallaxPerfSchedule -Builds @('b1', 'b2', 'b3') -Scenarios @('empty', 'suite') -Rounds 3 -MatrixId 'm')
Assert-True ($schedule.Count -eq 9) 'BuildMajor: one invocation per build per round'
Assert-True ((($schedule | Where-Object Round -eq 1).Build -join ',') -eq 'b1,b2,b3') 'round 1 keeps the build order'
Assert-True ((($schedule | Where-Object Round -eq 2).Build -join ',') -eq 'b2,b3,b1') 'round 2 rotates the build order'
Assert-True ((($schedule | Where-Object Round -eq 3).Build -join ',') -eq 'b3,b1,b2') 'round 3 rotates again'
Assert-True (($schedule[0].Scenarios -join ',') -eq 'empty,suite' -and ($schedule[3].Scenarios -join ',') -eq 'suite,empty') 'scenario order rotates by round'
Assert-True ($schedule[4].Label -eq 'm-b3-r2') 'labels name the matrix, build and round'
foreach ($build in 'b1', 'b2', 'b3') {
    $positions = @($schedule | Where-Object Build -eq $build | ForEach-Object { ($_.Slot - 1) % 3 })
    Assert-True ((@($positions | Sort-Object) -join ',') -eq '0,1,2') "each build takes every position once ($build)"
}
$major = @(New-ParallaxPerfSchedule -Builds @('b1', 'b2') -Scenarios @('empty', 'suite') -Rounds 2 -Order ScenarioMajor -MatrixId 'm')
Assert-True ($major.Count -eq 8) 'ScenarioMajor: one invocation per build, scenario and round'
Assert-True ((($major | Select-Object -First 2 | ForEach-Object { $_.Scenarios[0] }) -join ',') -eq 'empty,empty') 'builds of one scenario run back to back'
Assert-True ((($major | Select-Object -First 4 | ForEach-Object Build) -join ',') -eq 'b1,b2,b2,b1') 'the build order rotates with the scenario'
Assert-True ($major[2].Label -eq 'm-b2-r1-s1') 'ScenarioMajor labels carry the scenario index'

# --------------------------------------------------------------------------
# Statistics and analysis on synthetic trials with known answers.
# --------------------------------------------------------------------------
Assert-Near (Get-ParallaxMedian @(3, 1, 2)) 2 'median of an odd count'
Assert-Near (Get-ParallaxMedian @(4, 1, 3, 2)) 2.5 'median of an even count'
Assert-Near (Get-ParallaxVariance @(1, 2, 3, 4)) (5.0 / 3) 'sample variance'
Assert-Near (Get-ParallaxPooledSd @(, @(1, 3)) ) ([math]::Sqrt(2)) 'pooled SD of one group'
Assert-Near (Get-ParallaxPooledSd @(@(1, 3), @(10, 10, 10, 10))) ([math]::Sqrt(2 / 4.0)) 'pooled SD weights by degrees of freedom'
Assert-True ($null -eq (Get-ParallaxPooledSd @(, @(5)))) 'no spread from single trials'

$builds = @(
    [pscustomobject]@{ Name = 'base'; Role = 'baseline'; UnitKey = ''; Fixes = @() },
    [pscustomobject]@{ Name = 'all'; Role = 'all'; UnitKey = ''; Fixes = @() },
    [pscustomobject]@{ Name = 'p-A'; Role = 'plus'; UnitKey = 'A'; Fixes = @('A') },
    [pscustomobject]@{ Name = 'p-B'; Role = 'plus'; UnitKey = 'B'; Fixes = @('B') },
    [pscustomobject]@{ Name = 'm-A'; Role = 'minus'; UnitKey = 'A'; Fixes = @('A') },
    [pscustomobject]@{ Name = 'm-B'; Role = 'minus'; UnitKey = 'B'; Fixes = @('B') }
)
# cost model: Total = 10 - 3a - 2b - ab (synergy), Main = 5 - 1.5a - 1.5b (additive),
# Other = 4 - a - b + 0.5ab (overlap); every build's trials are x+0.1, x-0.1, x.
$model = @{ 'base' = @(0, 0); 'all' = @(1, 1); 'p-A' = @(1, 0); 'p-B' = @(0, 1); 'm-A' = @(0, 1); 'm-B' = @(1, 0) }
$trials = foreach ($name in $model.Keys) {
    $a = $model[$name][0]; $b = $model[$name][1]
    foreach ($noise in 0.1, -0.1, 0.0) {
        [pscustomobject]@{ Build = $name; Scenario = 'suite'; TotalCpuPct = 10 - 3 * $a - 2 * $b - $a * $b + $noise
            MainCpuPct = 5 - 1.5 * $a - 1.5 * $b + $noise; OtherCpuPct = 4 - $a - $b + 0.5 * $a * $b + $noise }
    }
}
$metrics = @('TotalCpuPct', 'MainCpuPct', 'OtherCpuPct')
$analysis = Invoke-ParallaxPerfMatrixAnalysis -Builds $builds -Trials $trials -Metrics $metrics -AllFixes @('A', 'B', 'C') -Assumable @{ C = 'isolatedEffect interactive' }
$total = $analysis.Scenarios['suite'].Metrics['TotalCpuPct']
Assert-Near $total.G 6 'G = cost(baseline) - cost(all)'
Assert-Near $total.SumG 5 'sum of g_k'
Assert-Near $total.Interaction 1 'I = G - sum g'
Assert-Near $total.PooledSd 0.1 'pooled trial spread'
Assert-Near $total.Threshold 0.2 'threshold is twice the pooled spread'
Assert-True ($total.Class -eq 'synergistic') "I > 2s is synergistic (got $($total.Class))"
$unitA = $total.Units | Where-Object Unit -eq 'A'
Assert-Near $unitA.g 3 'g_A'
Assert-Near $unitA.m 4 'm_A = cost(all - A) - cost(all)'
Assert-True ($unitA.Interacts -match 'synergy') 'a unit gaining more inside all is flagged'
Assert-True ($analysis.Scenarios['suite'].Metrics['MainCpuPct'].Class -eq 'additive') 'I within 2s is additive'
Assert-True (@($analysis.Scenarios['suite'].Metrics['MainCpuPct'].Units | Where-Object Interacts).Count -eq 0) 'additive units are not flagged'
Assert-True ($analysis.Scenarios['suite'].Metrics['OtherCpuPct'].Class -eq 'antagonistic') 'I below -2s is antagonistic'
Assert-True ((@($analysis.Coverage.AssumedZero) -join ',') -eq 'C' -and $analysis.Coverage.Complete) 'an unmeasured non-isolated fix is assumed zero, and said so'
$partial = Invoke-ParallaxPerfMatrixAnalysis -Builds $builds -Trials $trials -Metrics $metrics -AllFixes @('A', 'B', 'C')
Assert-True ($partial.Scenarios['suite'].Metrics['TotalCpuPct'].Class -like 'incomplete*') 'an unmeasured expected fix leaves the class incomplete'
Assert-Near $partial.Scenarios['suite'].Metrics['TotalCpuPct'].Interaction 1 'while still reporting the numbers'
$single = Invoke-ParallaxPerfMatrixAnalysis -Builds $builds -Trials @($trials | Where-Object { $_.TotalCpuPct -eq [math]::Round($_.TotalCpuPct, 0) }) -Metrics $metrics -AllFixes @('A', 'B')
Assert-True ($single.Scenarios['suite'].Metrics['TotalCpuPct'].Class -like 'undetermined: fewer than 2*') 'single trials cannot be classified'
$overlap = @($builds) + @([pscustomobject]@{ Name = 'p-AB'; Role = 'plus'; UnitKey = 'A+B'; Fixes = @('A', 'B') })
$overlapAnalysis = Invoke-ParallaxPerfMatrixAnalysis -Builds $overlap -Trials $trials -Metrics $metrics -AllFixes @('A', 'B')
Assert-True (@($overlapAnalysis.Coverage.Overlaps).Count -eq 2 -and $overlapAnalysis.Scenarios['suite'].Metrics['TotalCpuPct'].Class -like 'incomplete*') 'overlapping units cannot be summed'
$markdown = ConvertTo-ParallaxPerfMatrixMarkdown -Analysis $analysis -Header @{ Title = 'fixture' } -CostMetrics $metrics -UnitMetrics $metrics
Assert-True ($markdown -match '\| Total CPU \| 10\.00 \| 4\.00 \| 6\.00 \| 5\.00 \| 1\.00 \| 0\.20 \| synergistic \|') 'the markdown summary row'
Assert-True ($markdown -match '\| A \| A \| 3\.00 / 4\.00 \|') 'the markdown unit row'
foreach ($line in ($markdown -split "`n" | Where-Object { $_ -like '|*' })) {
    $cells = ($line.Trim().Trim('|') -split '\|').Count
    Assert-True ($cells -ge 4) "a well-formed table row: $line"
}

# --------------------------------------------------------------------------
# End to end with builds and a stand-in benchmark (no Rainmeter).
# --------------------------------------------------------------------------
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('pxpm-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$repo = Join-Path $fixture 'repo'
$root = Join-Path $fixture 'b'
function Git([string[]]$Arguments) { (Invoke-ParallaxGit -Directory $repo -Arguments $Arguments).Stdout.Trim() }
function Put-Text([string]$Relative, [string]$Text) {
    $path = Join-Path $repo $Relative
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}
function Commit([string]$Message) { $null = Git @('add', '-A'); $null = Git @('commit', '-q', '-m', $Message); Git @('rev-parse', 'HEAD') }
$fakeBenchmark = @'
# Stand-in for Benchmark-Parallax.ps1: same parameters, synthetic report, no Rainmeter.
param([string]$RainmeterPath = '', [string[]]$Scenario = @('suite'), [string]$Preferences = 'default', [string]$LiveSkinRoot = '',
    [int]$Trials = 3, [int]$SettleSeconds = 15, [int]$MeasureSeconds = 30, [string]$StageRoot = '', [string]$HardwareAcceleration = 'default', [string]$Label = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$a = [int]((Get-Content -LiteralPath (Join-Path $root 'Skins\P\a.txt') -Raw).Trim() -eq 'on')
$b = [int]((Get-Content -LiteralPath (Join-Path $root 'Skins\P\b.txt') -Raw).Trim() -eq 'on')
$round = [int]($Label -replace '^.*-r(\d+).*$', '$1')
$noise = @(0.1, -0.1, 0.0)[($round - 1) % 3]
$stage = $StageRoot
if (-not $stage) { $stage = Join-Path $root ('build\stage-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)); $null = New-Item -ItemType Directory -Path $stage }
$rows = foreach ($s in ($Scenario -join ',').Split(',')) {
    if ($s -eq 'broken') { continue }
    [pscustomobject]@{ Scenario = $s; Trial = 1; TotalCpuPct = 10 - 3 * $a - 2 * $b - $a * $b + $noise; MainCpuPct = 5 - 1.5 * $a - 1.5 * $b + $noise }
}
$out = Join-Path $root 'build\perf-benchmark'
if (-not (Test-Path -LiteralPath $out)) { $null = New-Item -ItemType Directory -Path $out -Force }
$report = [ordered]@{ Label = $Label; Preferences = $Preferences; HardwareAcceleration = $HardwareAcceleration; StageRoot = $stage; ReceivedStageRoot = $StageRoot
    Settle = $SettleSeconds; Window = $MeasureSeconds; Trials = $Trials; Trialwise = @($rows) }
[IO.File]::WriteAllText((Join-Path $out ('{0}-{1}-{2}.json' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'), $Preferences, $Label)), ($report | ConvertTo-Json -Depth 5))
Write-Host "fake benchmark $Label"
'@
try {
    $null = New-Item -ItemType Directory -Path $repo -Force
    $null = Invoke-ParallaxGit -Directory $repo -Arguments @('init', '-q', '-b', 'main')
    foreach ($pair in @(@('user.name', 'Fixture'), @('user.email', 'fixture@localhost.invalid'), @('core.autocrlf', 'false'))) { $null = Git @('config', $pair[0], $pair[1]) }
    Put-Text '.gitignore' "build/`n"
    Put-Text 'tools/Fake-Benchmark.ps1' $fakeBenchmark
    Put-Text 'Skins/P/a.txt' "off`n"
    Put-Text 'Skins/P/b.txt' "off`n"
    Put-Text 'Skins/P/c.txt' "off`n"
    $base = Commit 'base'
    Put-Text 'Skins/P/a.txt' "on`n"; $ka = Commit 'fix A'
    Put-Text 'Skins/P/b.txt' "on`n"; $kb = Commit 'fix B'
    Put-Text 'Skins/P/c.txt' "on`n"; $kc = Commit 'fix C (settings only)'
    $manifestPath = Join-Path $fixture 'fixes.json'
    $manifestData = [ordered]@{
        schema = 1; baseline = @{ commit = $base }; all = @{ commit = $kc }; scope = @{ include = @('Skins/'); exclude = @() }
        packages = @(@{ id = 'P' })
        fixes = @(
            [ordered]@{ id = 'A'; package = 'P'; commits = @(@{ sha = $ka; role = 'fix' }); requires = @(); isolatedEffect = 'expected' },
            [ordered]@{ id = 'B'; package = 'P'; commits = @(@{ sha = $kb; role = 'fix' }); requires = @(); isolatedEffect = 'expected' },
            [ordered]@{ id = 'C'; package = 'P'; commits = @(@{ sha = $kc; role = 'fix' }); requires = @(); isolatedEffect = 'interactive' }
        )
        support = @()
    }
    [IO.File]::WriteAllText($manifestPath, ($manifestData | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    $made = @(& (Join-Path $toolsRoot 'New-PerfBuild.ps1') -RepoRoot $repo -Root $root -Manifest $manifestPath -Set -Fix A, B -Prefix t -Python $Python)
    Assert-True ($made.Count -eq 6 -and @($made | Where-Object Status -ne 'ok').Count -eq 0) 'six fixture builds made'

    $matrix = Join-Path $toolsRoot 'Invoke-PerfMatrix.ps1'
    $common = @{ BuildRoot = $root; Prefix = 't'; Scenario = @('empty,suite'); Trials = 3; BenchmarkRelativePath = 'tools\Fake-Benchmark.ps1'; InstrumentFiles = @('tools\Fake-Benchmark.ps1') }
    $folder = Join-Path $fixture 'm'
    $plan = & $matrix @common -MatrixId 'fx' -MatrixDir $folder -DryRun
    Assert-True (@($plan.Schedule).Count -eq 18) 'dry run: 6 builds x 3 rounds'
    Assert-True (Test-Path -LiteralPath (Join-Path $folder 'matrix-plan.json')) 'dry run writes the plan'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $folder 'reports'))) 'dry run runs nothing'
    Assert-True (-not (Get-ChildItem -LiteralPath $root -Recurse -Filter '*.json' | Where-Object { $_.FullName -like '*perf-benchmark*' })) 'no benchmark report anywhere after a dry run'
    Assert-True ((@($plan.Builds | Where-Object Role -eq 'plus' | ForEach-Object UnitKey) -join ',') -eq 'A,B') 'plus units come from the build records'
    Assert-True ((@($plan.Assumable | ForEach-Object Fix) -join ',') -eq 'C') 'the manifest marks C as assumable'
    $differing = $common.Clone(); $differing.InstrumentFiles = @('Skins\P\a.txt')
    Assert-Throws { & $matrix @differing -MatrixId 'fx2' -MatrixDir (Join-Path $fixture 'm2') -DryRun } 'differs between builds' 'builds with different measuring tools are refused'
    Put-Text '..\b\t-p-A\stray.txt' 'dirty'
    Assert-Throws { & $matrix @common -MatrixId 'fx3' -MatrixDir (Join-Path $fixture 'm3') -DryRun } 't-p-A: working tree is not clean' 'a dirty build is refused'
    Remove-Item -LiteralPath (Join-Path $root 't-p-A\stray.txt') -Force

    $null = & $matrix @common -MatrixId 'fx' -MatrixDir $folder
    $runs =@((Get-Content -LiteralPath (Join-Path $folder 'matrix-run.json') -Raw | ConvertFrom-Json).Runs)
    Assert-True ($runs.Count -eq 18 -and @($runs | Where-Object { $_.ExitCode -ne 0 -or @($_.Warnings).Count }).Count -eq 0) 'every invocation ran and reported'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $folder 'reports') -Recurse -Filter '*.json').Count -eq 18) 'reports collected centrally'
    $firstOfBase = Get-Content -LiteralPath (Join-Path $folder 'reports\t-base\fx-t-base-r1.json') -Raw | ConvertFrom-Json
    $laterOfBase = Get-Content -LiteralPath (Join-Path $folder 'reports\t-base\fx-t-base-r3.json') -Raw | ConvertFrom-Json
    Assert-True (-not $firstOfBase.ReceivedStageRoot -and $laterOfBase.ReceivedStageRoot -eq $firstOfBase.StageRoot) 'the first run stages, later runs reuse that stage'
    Assert-True ($laterOfBase.Settle -eq 15 -and $laterOfBase.Window -eq 60 -and $laterOfBase.Trials -eq 1) 'settle, window and one trial per invocation are passed through'
    $result = Get-Content -LiteralPath (Join-Path $folder 'analysis.json') -Raw | ConvertFrom-Json
    $suiteTotal = $result.Scenarios.suite.Metrics.TotalCpuPct
    Assert-Near $suiteTotal.G 6 'end to end: G'
    Assert-Near $suiteTotal.SumG 5 'end to end: sum g'
    Assert-True ($suiteTotal.Class -eq 'synergistic') "end to end: synergistic (got $($suiteTotal.Class))"
    Assert-True ($result.Scenarios.suite.Metrics.MainCpuPct.Class -eq 'additive') 'end to end: additive'
    Assert-True (Test-Path -LiteralPath (Join-Path $folder 'analysis.md')) 'end to end: markdown written'
    $again = & $matrix @common -MatrixId 'fx' -MatrixDir $folder -Resume 6>&1 | Out-String
    Assert-True ($again -match 'already collected') 'a resumed matrix skips collected reports'
    Assert-Throws { & $matrix @common -MatrixId 'fx' -MatrixDir $folder } 'already has a plan' 'a matrix folder is not overwritten without -Resume'
    Remove-Item -LiteralPath (Join-Path $folder 'analysis.md') -Force
    $null = & $matrix -AnalyzeOnly -MatrixDir $folder
    Assert-True (Test-Path -LiteralPath (Join-Path $folder 'analysis.md')) '-AnalyzeOnly rebuilds the analysis from the folder'

    # A -Within sub-matrix compares against its own all.
    $sub = @(& (Join-Path $toolsRoot 'New-PerfBuild.ps1') -RepoRoot $repo -Root $root -Manifest $manifestPath -Set -Fix A -Within A, B -Prefix w -Python $Python)
    Assert-True ($sub.Count -eq 4) 'four sub-matrix builds made'
    $subPlan = & $matrix -BuildRoot $root -Prefix 'w' -Scenario @('suite') -Trials 2 -BenchmarkRelativePath 'tools\Fake-Benchmark.ps1' -InstrumentFiles @('tools\Fake-Benchmark.ps1') -MatrixId 'fw' -MatrixDir (Join-Path $fixture 'mw') -DryRun
    Assert-True ((@($subPlan.AllFixes) -join ',') -eq 'A,B') "a sub-matrix's all holds only its -Within fixes"
    Assert-Throws { & $matrix -Build @((Join-Path $root 't-all'), (Join-Path $root 'w-m-A')) -Scenario @('suite') -Trials 2 -BenchmarkRelativePath 'tools\Fake-Benchmark.ps1' -InstrumentFiles @('tools\Fake-Benchmark.ps1') -MatrixId 'fx4' -MatrixDir (Join-Path $fixture 'm4') -DryRun } 'different -Within sets' 'all and minus builds of different sub-matrices are refused'

    # A scenario the benchmark could not run is reported as missing, not invented.
    $broken = Join-Path $fixture 'mb'
    $null = & $matrix -BuildRoot $root -Prefix 't' -Scenario @('suite,broken') -Trials 2 -BenchmarkRelativePath 'tools\Fake-Benchmark.ps1' -InstrumentFiles @('tools\Fake-Benchmark.ps1') -MatrixId 'fb' -MatrixDir $broken 3>$null
    $brokenResult = Get-Content -LiteralPath (Join-Path $broken 'analysis.json') -Raw | ConvertFrom-Json
    Assert-True (@($brokenResult.MissingTrials).Count -eq 12) 'missing trials are listed'
    Assert-True ($brokenResult.Scenarios.PSObject.Properties.Name -notcontains 'broken') 'and no numbers appear for them'

    Write-Host "Test-PerfMatrix: $script:assertions assertions passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $repo) { $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'prune') -AllowFailure }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
}
