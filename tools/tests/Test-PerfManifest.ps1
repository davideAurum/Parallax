#requires -Version 5.1
# Re-runnable check of the step-3 fix manifest (tools/perf-fixes.json) against
# the repository: the claims docs/PERF-STEP3.md makes about it. Opt-in and slow:
# a full run makes 2 + 2 x units + 1 builds (63 for phase A); -CompareMinusByPick
# adds one per unit, each picking nearly every fix. With it, phase A took 33
# minutes on 2026-10-23. -SkipBuilds checks history and units in seconds.
# Run it whenever the manifest changes.
#
# History checks read the repository only. Build checks run in a temporary
# 'git clone --shared' under a short root, so the shared repository gains no
# worktree, branch, ref or object; the clone and its builds are removed
# afterwards unless -Keep. Never starts Rainmeter.
#
#  1. Packages: each package tip is its merge's second parent, every merge is
#     on the first-parent line from the baseline to the all tip, and those are
#     all its merges.
#  2. Commits: every non-merge commit on a package branch (baseline..tip) is
#     listed exactly once, as a fix or support commit of that package; every
#     listed commit is on its package branch, or (package null) a non-merge
#     commit of the first-parent line; every first-parent non-merge commit is
#     listed; support commits change nothing inside the scope.
#  3. Units: the manifest's units partition its fixes, and each unit id names
#     exactly its fixes.
#  4. Builds (unless -SkipBuilds): New-PerfBuild -Set over every unit (or -Unit)
#     makes the baseline, the all tip and a plus and a minus build per unit,
#     with no -IncludeRequired or -IncludeDependents, and none fails.
#  5. Baseline + every fix picked (-Role all -Within <every package>) has the
#     all tip's scope digest: the manifest holds every runtime change.
#  6. With -CompareMinusByPick: each unit's minus build by revert has the
#     scope digest of baseline + every other fix picked.
[CmdletBinding()]
param(
    [string]$Manifest = '',
    [string]$Root = '',
    [string]$Python = 'python',
    [string[]]$Unit = @(),
    [switch]$SkipBuilds,
    [switch]$CompareMinusByPick,
    [switch]$Keep
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $toolsRoot 'Parallax.PerfBuild.psm1') -Force
if (-not $Manifest) { $Manifest = Join-Path $toolsRoot 'perf-fixes.json' }
$watch = [Diagnostics.Stopwatch]::StartNew()
$script:assertions = 0
$script:failures = [Collections.Generic.List[string]]::new()
# Collects every failure instead of stopping at the first, so one run reports
# the whole state of the manifest.
function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { $script:failures.Add($Message); Write-Host "FAIL: $Message" -ForegroundColor Red }
}

$repo = (Invoke-ParallaxGit -Directory $toolsRoot -Arguments @('rev-parse', '--show-toplevel')).Stdout.Trim()
function Git([string[]]$Arguments) { (Invoke-ParallaxGit -Directory $repo -Arguments $Arguments).Stdout }
function Lines([string]$Text) { @($Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Full([string]$Spec) { (Git @('rev-parse', '--verify', "$Spec^{commit}")).Trim() }

$fixManifest = Read-ParallaxFixManifest -Path $Manifest
$data = $fixManifest.Data
$include = @($data.scope.include)
$exclude = @(if ($data.scope.PSObject.Properties['exclude']) { $data.scope.exclude })
$baseline = Full $data.baseline.commit
$all = Full $data.all.commit
Write-Host "Manifest $($fixManifest.Path): $($fixManifest.Fixes.Count) fixes, $(@($data.support).Count) support commits, $(@($data.units).Count) units; baseline $($baseline.Substring(0, 9)), all $($all.Substring(0, 9))" -ForegroundColor Cyan
Assert-True ((Invoke-ParallaxGit -Directory $repo -Arguments @('merge-base', '--is-ancestor', $baseline, $all) -AllowFailure).ExitCode -eq 0) 'the baseline is an ancestor of the all tip'

function Get-InScopeChanges([string]$Sha) {
    $names = Split-ParallaxNul (Git @('diff', '--no-renames', '--name-only', '-z', "$Sha^", $Sha))
    @($names | Where-Object { Test-ParallaxInScope -Path $_ -Include $include -Exclude $exclude })
}

# --------------------------------------------------------------------------
# 1-2. History.
# --------------------------------------------------------------------------
$listed = @{}
foreach ($fix in $fixManifest.Fixes.Values) {
    foreach ($commit in @($fix.commits)) {
        $sha = Full $commit.sha
        Assert-True (-not $listed.ContainsKey($sha)) "commit $($sha.Substring(0, 9)) is listed once (fix $($fix.id)$(if ($listed.ContainsKey($sha)) { ', also ' + $listed[$sha].What }))"
        $listed[$sha] = [pscustomobject]@{ What = "fix $($fix.id)"; Package = $fix.package; Support = $false }
    }
}
foreach ($support in @($data.support)) {
    $sha = Full $support.commit
    Assert-True (-not $listed.ContainsKey($sha)) "commit $($sha.Substring(0, 9)) is listed once (support$(if ($listed.ContainsKey($sha)) { ', also ' + $listed[$sha].What }))"
    $listed[$sha] = [pscustomobject]@{ What = "support $($support.kind)"; Package = $support.package; Support = $true }
    $inScope = @(Get-InScopeChanges $sha)
    Assert-True ($inScope.Count -eq 0) "support commit $($sha.Substring(0, 9)) changes nothing inside the scope (changes: $($inScope -join ', '))"
}

$firstParent = @(Lines (Git @('rev-list', '--first-parent', "$baseline..$all")))
$firstParentMerges = @(Lines (Git @('rev-list', '--first-parent', '--merges', "$baseline..$all")))
$packageMerges = @{}
$onBranch = @{}
foreach ($package in @($data.packages)) {
    $merge = Full $package.merge
    $tip = Full $package.tip
    $packageMerges[$merge] = $package.id
    Assert-True ($merge -in $firstParent) "package $($package.id): merge $($merge.Substring(0, 9)) is on the first-parent line"
    $second = (Invoke-ParallaxGit -Directory $repo -Arguments @('rev-parse', '--verify', '--quiet', "$merge^2") -AllowFailure).Stdout.Trim()
    Assert-True ($second -eq $tip) "package $($package.id): the tip $($tip.Substring(0, 9)) is the merge's second parent (got $second)"
    foreach ($sha in (Lines (Git @('rev-list', '--no-merges', "$baseline..$tip")))) {
        $onBranch[$sha] = $package.id
        $entry = $listed[$sha]
        if ($null -eq $entry) { Assert-True $false "package $($package.id): branch commit $($sha.Substring(0, 9)) $((Git @('log', '-1', '--format=%s', $sha)).Trim()) is listed"; continue }
        Assert-True ($entry.Package -eq $package.id) "package $($package.id): branch commit $($sha.Substring(0, 9)) is listed under its own package (got $($entry.Package))"
    }
}
foreach ($merge in $firstParentMerges) { Assert-True ($packageMerges.ContainsKey($merge)) "first-parent merge $($merge.Substring(0, 9)) is a listed package merge" }
$directCommits = @(Lines (Git @('rev-list', '--first-parent', '--no-merges', "$baseline..$all")))
foreach ($sha in $directCommits) {
    $entry = $listed[$sha]
    Assert-True ($null -ne $entry -and $entry.Support -and $null -eq $entry.Package) "first-parent commit $($sha.Substring(0, 9)) is listed as support with no package"
}
foreach ($sha in $listed.Keys) {
    $entry = $listed[$sha]
    if ($null -eq $entry.Package) { Assert-True ($sha -in $directCommits) "$($entry.What) $($sha.Substring(0, 9)) without a package is a first-parent commit" }
    else { Assert-True ($onBranch.ContainsKey($sha)) "$($entry.What) $($sha.Substring(0, 9)) is on the branch of package $($entry.Package)" }
}

# --------------------------------------------------------------------------
# 3. Units.
# --------------------------------------------------------------------------
$owner = @{}
foreach ($unitEntry in @($data.units)) {
    $resolved = @(Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit @($unitEntry.id))
    Assert-True ((@($resolved | Sort-Object) -join ',') -ceq (@($unitEntry.fixes | Sort-Object) -join ',')) "unit $($unitEntry.id) names exactly its fixes ($($unitEntry.fixes -join ', '))"
    foreach ($id in @($unitEntry.fixes)) {
        Assert-True (-not $owner.ContainsKey($id)) "fix $id is in one unit only$(if ($owner.ContainsKey($id)) { ' (also ' + $owner[$id] + ')' })"
        $owner[$id] = $unitEntry.id
    }
}
foreach ($id in $fixManifest.Fixes.Keys) { Assert-True ($owner.ContainsKey($id)) "fix $id is in a unit" }
Write-Host ("History and units: {0} assertions, {1} failure(s), {2:n1} s" -f $script:assertions, $script:failures.Count, $watch.Elapsed.TotalSeconds) -ForegroundColor Cyan

# --------------------------------------------------------------------------
# 4-6. Builds in a temporary --shared clone.
# --------------------------------------------------------------------------
if (-not $SkipBuilds) {
    if (-not $Root) { $Root = Join-Path ([IO.Path]::GetTempPath()) ('pxmc-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)) }
    $Root = [IO.Path]::GetFullPath($Root)
    if (Test-Path -LiteralPath $Root) { throw "Root already exists: $Root. Pass a new -Root." }
    $clone = Join-Path $Root 'r'
    $buildRoot = Join-Path $Root 'b'
    $newBuild = Join-Path $toolsRoot 'New-PerfBuild.ps1'
    $units = if ($Unit.Count) { @($Unit | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @($data.units | ForEach-Object { $_.id }) }
    $packages = @($data.packages | ForEach-Object { $_.id })
    function Get-Digest([string]$Name) {
        $path = Join-Path $buildRoot $Name
        if (-not (Test-Path -LiteralPath (Get-ParallaxPerfBuildRecordPath $path))) { return $null }
        $record = Read-ParallaxPerfBuild -BuildPath $path
        if ($record.Status -ne 'ok') { return $null }
        $record.ScopeDigest
    }
    function Invoke-Build([hashtable]$Arguments) {
        try { $null = & $newBuild -RepoRoot $clone -Root $buildRoot -Manifest $fixManifest.Path -Python $Python @Arguments 6>$null; $true }
        catch { Write-Host "build failed: $($_.Exception.Message)" -ForegroundColor Red; $false }
    }
    try {
        $commonDir = (Git @('rev-parse', '--git-common-dir')).Trim()
        if (-not [IO.Path]::IsPathRooted($commonDir)) { $commonDir = Join-Path $repo $commonDir }
        $null = New-Item -ItemType Directory -Path $Root
        $null = Invoke-ParallaxGit -Directory $Root -Arguments @('clone', '-q', '--shared', '--no-checkout', [IO.Path]::GetFullPath($commonDir), $clone)
        Write-Host "Clone: $clone; builds under $buildRoot ($($units.Count) unit(s))" -ForegroundColor Cyan

        $setOk = Invoke-Build @{ Set = $true; Fix = $units; Prefix = 'c' }
        Assert-True $setOk "-Set over $($units.Count) unit(s) makes every build"
        $names = @('c-base', 'c-all') + @($units | ForEach-Object { $safe = $_.Replace('+', '_'); "c-p-$safe"; "c-m-$safe" })
        foreach ($name in $names) {
            $record = if (Test-Path -LiteralPath (Get-ParallaxPerfBuildRecordPath (Join-Path $buildRoot $name))) { Read-ParallaxPerfBuild -BuildPath (Join-Path $buildRoot $name) } else { $null }
            Assert-True ($null -ne $record -and $record.Status -eq 'ok') "build $name is made"
            if ($record -and $name -like 'c-[pm]-*') {
                $key = $name.Substring(4)
                $expected = @(Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit @(($units | Where-Object { $_.Replace('+', '_') -eq $key }) | Select-Object -First 1))
                Assert-True ((@($record.Fixes) -join ',') -eq ($expected -join ',')) "build $name holds exactly its unit's fixes, with no include flag (got $(@($record.Fixes) -join ','))"
            }
        }
        $baseDigest = Get-Digest 'c-base'
        $allDigest = Get-Digest 'c-all'
        Assert-True ($baseDigest -and $allDigest -and $baseDigest -ne $allDigest) 'the baseline and the all tip differ inside the scope'

        $pickOk = Invoke-Build @{ Name = 'c-allpick'; Role = 'all'; Within = $packages }
        $pickDigest = Get-Digest 'c-allpick'
        Assert-True ($pickOk -and $pickDigest -eq $allDigest) "baseline + every fix picked has the all tip's scope digest (pick $pickDigest, tip $allDigest)"
        if ($pickDigest) { Write-Host "All tip scope digest $allDigest; baseline + every fix picked $pickDigest" -ForegroundColor Cyan }

        if ($CompareMinusByPick) {
            foreach ($unitId in $units) {
                $safe = $unitId.Replace('+', '_')
                $byPick = "c-q-$safe"
                $ok = Invoke-Build @{ Name = $byPick; Role = 'minus'; Fix = @($unitId); Within = $packages }
                $revertDigest = Get-Digest "c-m-$safe"
                $pickMinus = Get-Digest $byPick
                Assert-True ($ok -and $pickMinus -and $pickMinus -eq $revertDigest) "all - ${unitId}: revert and pick give the same scope digest (revert $revertDigest, pick $pickMinus)"
            }
        }
    }
    finally {
        if ($Keep) { Write-Host "Kept: $Root (remove it with Remove-Item -Recurse -Force)" -ForegroundColor Yellow }
        elseif (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$summary = "Test-PerfManifest: {0} assertions, {1} failure(s), {2:n0} s." -f $script:assertions, $script:failures.Count, $watch.Elapsed.TotalSeconds
if ($script:failures.Count) { throw ($summary + "`n  " + ($script:failures -join "`n  ")) }
Write-Host $summary -ForegroundColor Green
