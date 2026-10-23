#requires -Version 5.1
<#
.SYNOPSIS
Creates one performance build for step 3: a detached git worktree holding a base
commit plus cherry-picked commits, or a full tip minus reverted commits.

.DESCRIPTION
Step 3 of the performance review (docs/PERFORMANCE-REVIEW.md, "Step 3: evidence
protocol") measures every fix alone and in combination. Each measured tree is a
build: a detached worktree under a SHORT root (default C:\pxab\<Name>, because
long paths push staged includes past MAX_PATH and Rainmeter silently skips
them), made in one of two ways:

  pick    -Base <commit> -Pick <commits or fix ids>   (baseline + fix k)
  revert  -Tip <commit> -Revert <commits or fix ids>  (all fixes - fix k)

or from the fix manifest (tools/perf-fixes.json) by role:

  -Role baseline                      manifest baseline + 'always' support commits
  -Role plus  -Fix <fix or package>   baseline + support + that unit
  -Role all                           the manifest's all-fixes tip
  -Role minus -Fix <fix or package>   the tip with that unit reverted
  -Set -Fix <units>                   baseline, all, and plus/minus per unit

A unit is a fix id, a package id, or several joined with '+' (A3-2+A3-3).
-Within <fixes or packages> narrows 'all' to a sub-matrix, built by picking:
'all' becomes baseline + those fixes and 'minus' becomes baseline + those
fixes - the unit, so one package can be measured alone in a shorter session.

Every commit is applied with git cherry-pick/revert --no-commit, then committed
in the build with a provenance message. A scope (from the manifest, or -Scope /
-ScopeExclude) limits what a build applies: changes to paths outside it are
dropped, and a commit with no in-scope change is skipped. The phase-A manifest
scopes builds to Skins/, the runtime tree; docs and tools stay as the start
commit had them, so every build runs the same measuring tools.

Conflicts: git treats the UTF-16 Lua sources as binary, so cherry-picks and
reverts touching them stop with binary conflicts. Those are resolved by
tools/Merge-Utf16Text.py: decode, 3-way merge with git merge-file, re-encode
with the original byte-order mark and every line ending as it was. Anything else
stops the build: a text conflict, a UTF-16 merge with conflicts, a missing
stage, an encoding mismatch, a merge commit, or a commit whose in-scope change
comes out empty. The tool never guesses. A failed build is removed unless
-KeepOnFailure leaves it, conflicted, for inspection (its record says failed,
and Invoke-PerfMatrix.ps1 refuses it).

Each build carries build\perf-build.json (git-ignored): spec, every step with
its result, UTF-16 merges, dropped out-of-scope paths, the final commit and the
tree hash of each scope prefix, so two builds' runtime trees can be compared.

Nothing here touches Rainmeter, the live skin or any other worktree. The only
repository change is the new worktree's registration (git worktree add); remove
a build with: git worktree remove --force <path>.

.EXAMPLE
  powershell -File tools\New-PerfBuild.ps1 -Manifest tools\perf-fixes.json -Role plus -Fix A3-1 -Name s3-p-A3-1
  powershell -File tools\New-PerfBuild.ps1 -Manifest tools\perf-fixes.json -Set -Fix A1,A2,A3,A4,A6 -Prefix s3 -DryRun
  powershell -File tools\New-PerfBuild.ps1 -Name try1 -Base 916c9ab -Pick 26b6757 -Scope Skins/
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$')][string]$Name,
    [string]$Root = 'C:\pxab',
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),
    [string]$Base = '',
    [string[]]$Pick = @(),
    [string]$Tip = '',
    [string[]]$Revert = @(),
    [string]$Manifest = '',
    [ValidateSet('', 'baseline', 'plus', 'all', 'minus')][string]$Role = '',
    [string[]]$Fix = @(),
    [string[]]$Within = @(),
    [switch]$Set,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,15}$')][string]$Prefix = 's3',
    [switch]$IncludeRequired,
    [switch]$IncludeDependents,
    [string[]]$Scope = @(),
    [string[]]$ScopeExclude = @(),
    [string]$Python = 'python',
    [ValidateRange(120, 259)][int]$MaxPathLength = 240,
    [switch]$KeepOnFailure,
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.PerfBuild.psm1') -Force

$helper = Join-Path $PSScriptRoot 'Merge-Utf16Text.py'
$identity = @('-c', 'user.name=Parallax perf build', '-c', 'user.email=perf-build@localhost.invalid')
# Stage-Parallax.ps1 stages into <build>\build\Parallax-perf-xxxxxxxx-<19-char stamp>-<8 hex>\.
$stageOverhead = '\build\'.Length + 'Parallax-perf-00000000-20260101T000000000Z-00000000'.Length + 1

$repo = (Invoke-ParallaxGit -Directory ([IO.Path]::GetFullPath($RepoRoot)) -Arguments @('rev-parse', '--show-toplevel')).Stdout.Trim()
$fixManifest = $null
if ($Manifest) { $fixManifest = Read-ParallaxFixManifest -Path $Manifest }

# --------------------------------------------------------------------------
# Batch mode: baseline, all, and plus/minus for each unit.
# --------------------------------------------------------------------------
if ($Set) {
    if (-not $fixManifest) { throw '-Set needs -Manifest.' }
    if ($Role -or $Base -or $Tip -or $Pick.Count -or $Revert.Count) { throw '-Set builds roles itself; do not combine it with -Role, -Base, -Tip, -Pick or -Revert.' }
    $jobs = [Collections.Generic.List[object]]::new()
    $jobs.Add(@{ Name = "$Prefix-base"; Role = 'baseline'; Fix = @() })
    $jobs.Add(@{ Name = "$Prefix-all"; Role = 'all'; Fix = @() })
    foreach ($unit in @($Fix | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $null = Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit @($unit)
        $safe = $unit.Replace('+', '_')
        $jobs.Add(@{ Name = "$Prefix-p-$safe"; Role = 'plus'; Fix = @($unit) })
        $jobs.Add(@{ Name = "$Prefix-m-$safe"; Role = 'minus'; Fix = @($unit) })
    }
    $results = [Collections.Generic.List[object]]::new()
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($job in $jobs) {
        $arguments = @{
            Name = $job.Name; Root = $Root; RepoRoot = $repo; Manifest = $fixManifest.Path; Role = $job.Role; Fix = $job.Fix
            IncludeRequired = $IncludeRequired; IncludeDependents = $IncludeDependents; Python = $Python; MaxPathLength = $MaxPathLength
            KeepOnFailure = $KeepOnFailure; Force = $Force; DryRun = $DryRun
        }
        if ($Scope.Count) { $arguments.Scope = $Scope }
        if ($ScopeExclude.Count) { $arguments.ScopeExclude = $ScopeExclude }
        if ($Within.Count -and $job.Role -in 'all', 'minus') { $arguments.Within = $Within }
        try { $results.Add((& $PSCommandPath @arguments)) }
        catch {
            $failures.Add("$($job.Name): $($_.Exception.Message)")
            Write-Host "FAILED $($job.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    $results
    if ($failures.Count) { throw ("{0} of {1} build(s) failed:`n  {2}" -f $failures.Count, $jobs.Count, ($failures -join "`n  ")) }
    return
}

if (-not $Name) { throw '-Name is required (or use -Set).' }

# --------------------------------------------------------------------------
# Resolve the spec.
# --------------------------------------------------------------------------
function Resolve-Commit([string]$Spec) {
    $result = Invoke-ParallaxGit -Directory $repo -Arguments @('rev-parse', '--verify', '--quiet', "$Spec^{commit}") -AllowFailure
    if ($result.ExitCode -ne 0) { throw "Not a commit in ${repo}: $Spec" }
    $result.Stdout.Trim()
}
function Get-Subject([string]$Sha) { (Invoke-ParallaxGit -Directory $repo -Arguments @('log', '-1', '--format=%s', $Sha)).Stdout.Trim() }
function Get-ParentCount([string]$Sha) { @((Invoke-ParallaxGit -Directory $repo -Arguments @('rev-list', '--parents', '-n', '1', $Sha)).Stdout.Trim().Split(' ')).Count - 1 }

$supportAlways = @()
$units = @()
$fixIds = @()
if ($fixManifest) {
    $supportAlways = @($fixManifest.Data.support | Where-Object { $_.policy -eq 'always' })
    if (-not $Scope.Count -and $fixManifest.Data.PSObject.Properties['scope']) { $Scope = @($fixManifest.Data.scope.include) }
    if (-not $ScopeExclude.Count -and $fixManifest.Data.PSObject.Properties['scope'] -and $fixManifest.Data.scope.PSObject.Properties['exclude']) { $ScopeExclude = @($fixManifest.Data.scope.exclude) }
}

# Expands manifest fix/package ids to their commits; anything else must be a commit.
function Expand-Tokens([string[]]$Tokens) {
    $out = [Collections.Generic.List[object]]::new()
    foreach ($token in @($Tokens | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $known = $fixManifest -and @($token.Split('+') | Where-Object { -not ($fixManifest.Fixes.Contains($_) -or $fixManifest.Packages.Contains($_)) }).Count -eq 0
        if ($known) {
            foreach ($id in (Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit @($token))) {
                foreach ($commit in @($fixManifest.Fixes[$id].commits)) { $out.Add([pscustomobject]@{ Spec = $commit.sha; Source = $id }) }
            }
        } else {
            $out.Add([pscustomobject]@{ Spec = $token; Source = 'explicit' })
        }
    }
    $out
}

$mode = ''
$universe = @()
$start = ''
$requested = @()
if ($Role) {
    if (-not $fixManifest) { throw '-Role needs -Manifest.' }
    if ($Base -or $Tip -or $Pick.Count -or $Revert.Count) { throw 'Use either -Role or -Base/-Pick/-Tip/-Revert, not both.' }
    if ($Role -in 'plus', 'minus') {
        if (-not $Fix.Count) { throw "-Role $Role needs -Fix <fix or package id>." }
        $units = @($Fix | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $fixIds = @(Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit $units)
    } elseif ($Fix.Count) { throw "-Fix does not apply to -Role $Role." }
    $universe = @()
    if ($Within.Count) {
        if ($Role -notin 'all', 'minus') { throw "-Within applies to -Role all and minus only." }
        $universe = @(Resolve-ParallaxFixUnit -Manifest $fixManifest -Unit $Within)
        $outside = @($fixIds | Where-Object { $_ -notin $universe })
        if ($outside.Count) { throw "Unit fixes $($outside -join ', ') are outside -Within." }
        $missing = @($universe | ForEach-Object { @($fixManifest.Fixes[$_].requires) } | Where-Object { $_ -and $_ -notin $universe } | Sort-Object -Unique)
        if ($missing.Count) { throw ("-Within needs {0} too (its fixes require them). Add them to -Within." -f ($missing -join ', ')) }
    }
    switch ($Role) {
        'baseline' { $mode = 'pick'; $start = $fixManifest.Data.baseline.commit }
        'all' {
            if ($universe.Count) { $mode = 'pick'; $start = $fixManifest.Data.baseline.commit; $fixIds = $universe }
            else { $mode = 'revert'; $start = $fixManifest.Data.all.commit }
        }
        'plus' {
            $mode = 'pick'; $start = $fixManifest.Data.baseline.commit
            $missing = @($fixIds | ForEach-Object { @($fixManifest.Fixes[$_].requires) } | Where-Object { $_ -and $_ -notin $fixIds } | Sort-Object -Unique)
            if ($missing.Count) {
                if (-not $IncludeRequired) { throw ("Unit {0} requires {1}, which it does not include. Measure them together, or pass -IncludeRequired to add them (the build then measures the larger unit)." -f ($units -join ','), ($missing -join ', ')) }
                while ($missing.Count) {
                    $fixIds = @(@($fixIds) + $missing | Sort-Object -Unique | Sort-Object { $fixManifest.Fixes[$_].Order })
                    $missing = @($fixIds | ForEach-Object { @($fixManifest.Fixes[$_].requires) } | Where-Object { $_ -and $_ -notin $fixIds } | Sort-Object -Unique)
                }
            }
        }
        'minus' {
            $mode = 'revert'; $start = $fixManifest.Data.all.commit
            $dependents = @(Get-ParallaxFixDependents -Manifest $fixManifest -Ids $fixIds)
            if ($universe.Count) { $dependents = @($dependents | Where-Object { $_ -in $universe }) }
            if ($dependents.Count) {
                if (-not $IncludeDependents) { throw ("Fixes {0} require unit {1}, or cannot be reverted around it. Revert them too with -IncludeDependents (the build then measures all minus the larger unit)." -f ($dependents -join ', '), ($units -join ',')) }
                $fixIds = @(@($fixIds) + $dependents | Sort-Object -Unique | Sort-Object { $fixManifest.Fixes[$_].Order })
            }
        }
    }
    $removed = @()
    if ($Role -eq 'minus' -and $universe.Count) {
        # Sub-matrix: baseline + (the -Within fixes minus the unit), by picking.
        $mode = 'pick'; $start = $fixManifest.Data.baseline.commit
        $removed = $fixIds
        $fixIds = @($universe | Where-Object { $_ -notin $removed })
    }
    if ($Role -eq 'plus' -or $Role -eq 'baseline' -or $mode -eq 'pick') {
        $chosen = @($supportAlways | ForEach-Object { [pscustomobject]@{ Spec = $_.commit; Source = 'support' } })
        foreach ($id in $fixIds) { foreach ($commit in @($fixManifest.Fixes[$id].commits)) { $chosen += [pscustomobject]@{ Spec = $commit.sha; Source = $id } } }
        $requested = $chosen
        if ($removed.Count) { $fixIds = $removed }
    } elseif ($Role -eq 'minus') {
        $requested = @($fixIds | ForEach-Object { $id = $_; @($fixManifest.Fixes[$id].commits) | ForEach-Object { [pscustomobject]@{ Spec = $_.sha; Source = $id } } })
    }
} else {
    if ($Base -and $Tip) { throw 'Give -Base (pick mode) or -Tip (revert mode), not both.' }
    if ($Base) { $mode = 'pick'; $start = $Base; $requested = @(Expand-Tokens $Pick) }
    elseif ($Tip) { $mode = 'revert'; $start = $Tip; $requested = @(Expand-Tokens $Revert) }
    else { throw 'Give -Role (with -Manifest), -Base [-Pick ...] or -Tip [-Revert ...].' }
    if ($mode -eq 'pick' -and $Revert.Count) { throw '-Revert needs -Tip.' }
    if ($mode -eq 'revert' -and $Pick.Count) { throw '-Pick needs -Base.' }
    $fixIds = @($requested | Where-Object { $_.Source -ne 'explicit' } | ForEach-Object { $_.Source } | Select-Object -Unique)
}

$startSha = Resolve-Commit $start
$steps = [Collections.Generic.List[object]]::new()
$seen = @{}
foreach ($item in $requested) {
    $sha = Resolve-Commit $item.Spec
    if ($seen.ContainsKey($sha)) { continue }
    $seen[$sha] = $true
    if ((Get-ParentCount $sha) -ne 1) { throw "Merge or root commit cannot be applied: $sha. Name the package commits instead." }
    $steps.Add([pscustomobject]@{ Op = $mode; Sha = $sha; Source = $item.Source; Subject = (Get-Subject $sha) })
}
if ($mode -eq 'revert') {
    # Revert newest first, in the tip's topological order.
    $topo = @((Invoke-ParallaxGit -Directory $repo -Arguments @('rev-list', '--topo-order', $startSha)).Stdout.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $position = @{}
    for ($i = 0; $i -lt $topo.Count; $i++) { $position[$topo[$i]] = $i }
    foreach ($step in $steps) { if (-not $position.ContainsKey($step.Sha)) { throw "Cannot revert $($step.Sha): it is not in the history of $startSha." } }
    $steps = [Collections.Generic.List[object]]::new([object[]]@($steps | Sort-Object { $position[$_.Sha] }))
} else {
    foreach ($step in $steps) {
        $ancestor = Invoke-ParallaxGit -Directory $repo -Arguments @('merge-base', '--is-ancestor', $step.Sha, $startSha) -AllowFailure
        if ($ancestor.ExitCode -eq 0) { throw "Commit $($step.Sha) is already in the history of the base $startSha; picking it again would be wrong." }
    }
}

# In-scope paths of each step, from the commit's own diff.
foreach ($step in $steps) {
    $names = Split-ParallaxNul (Invoke-ParallaxGit -Directory $repo -Arguments @('diff', '--no-renames', '--name-only', '-z', "$($step.Sha)^", $step.Sha)).Stdout
    $inScope = @($names | Where-Object { Test-ParallaxInScope -Path $_ -Include $Scope -Exclude $ScopeExclude })
    $step | Add-Member -NotePropertyName InScope -NotePropertyValue $inScope
    $step | Add-Member -NotePropertyName OutOfScope -NotePropertyValue @($names | Where-Object { $_ -notin $inScope })
}

$rootPath = [IO.Path]::GetFullPath($Root)
$destination = Join-Path $rootPath $Name
$longest = @(Split-ParallaxNul (Invoke-ParallaxGit -Directory $repo -Arguments @('ls-tree', '-r', '--name-only', '-z', $startSha)).Stdout |
    Where-Object { Test-ParallaxInScope -Path $_ -Include $Scope -Exclude $ScopeExclude } | Measure-Object -Property Length -Maximum).Maximum
if (-not $longest) { $longest = 0 }
$worstPath = $destination.Length + $stageOverhead + $longest
$plan = [pscustomobject][ordered]@{
    Name = $Name; Path = $destination; Repo = $repo; Mode = $mode; Start = $startSha; StartSpec = $start
    Role = $Role; Unit = @($units); Fixes = @($fixIds); Within = @($universe); Scope = [pscustomobject]@{ Include = @($Scope); Exclude = @($ScopeExclude) }
    WorstStagedPathLength = $worstPath
    Steps = @($steps | ForEach-Object { [pscustomobject]@{ Op = $_.Op; Sha = $_.Sha; Source = $_.Source; Subject = $_.Subject; InScope = $_.InScope.Count; OutOfScope = $_.OutOfScope.Count } })
}
if ($worstPath -gt $MaxPathLength) {
    throw "A staged path in $destination could reach $worstPath characters (limit $MaxPathLength). Use a shorter -Root or -Name; Rainmeter skips includes past MAX_PATH."
}

Write-Host ("{0} {1}: {2} from {3}, {4} step(s), scope {5}" -f $(if ($DryRun) { 'Plan' } else { 'Build' }), $Name, $mode, $startSha.Substring(0, 12), $steps.Count, $(if ($Scope.Count) { ($Scope -join ',') } else { 'whole tree' })) -ForegroundColor Cyan
foreach ($step in $steps) {
    $note = if (-not $step.InScope.Count) { ' (outside scope: skipped)' } elseif ($step.OutOfScope.Count) { " (drops $($step.OutOfScope.Count) out-of-scope path(s))" } else { '' }
    Write-Host ("  {0,-6} {1} {2,-8} {3}{4}" -f $step.Op, $step.Sha.Substring(0, 9), $step.Source, $step.Subject, $note)
}
if ($DryRun) { return $plan }

# --------------------------------------------------------------------------
# Create the worktree and apply the steps.
# --------------------------------------------------------------------------
if (Test-Path -LiteralPath $destination) {
    $existing = $null
    try { $existing = Read-ParallaxPerfBuild -BuildPath $destination } catch {}
    if (-not ($Force -and $existing)) { throw "Build path already exists: $destination. Remove it (git worktree remove --force) or pass -Force to replace a build this tool made." }
    Write-Host "Replacing existing build $destination" -ForegroundColor Yellow
    $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'remove', '--force', $destination) -AllowFailure
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'prune') -AllowFailure
}
if (-not (Test-Path -LiteralPath $rootPath)) { $null = New-Item -ItemType Directory -Path $rootPath }
$null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'add', '--detach', $destination, $startSha)
$recordPath = Get-ParallaxPerfBuildRecordPath $destination
$results = [Collections.Generic.List[object]]::new()

function Save-Record([string]$Status, [string]$ErrorText) {
    $record = [ordered]@{
        Schema = 1; Tool = 'tools/New-PerfBuild.ps1'; Status = $Status; Error = $ErrorText
        CreatedUtc = [DateTime]::UtcNow.ToString('o'); Name = $Name; Path = $destination; Repo = $repo
        Mode = $mode; Start = $startSha; StartSpec = $start; Role = $Role; Unit = @($units); Fixes = @($fixIds); Within = @($universe)
        Manifest = $(if ($fixManifest) { $fixManifest.Path } else { $null })
        Scope = [ordered]@{ Include = @($Scope); Exclude = @($ScopeExclude) }
        Steps = @($results.ToArray())
        Head = $null; Trees = [ordered]@{}; ScopeFiles = $null; ScopeDigest = $null
    }
    if ($Status -eq 'ok') {
        $record.Head = (Invoke-ParallaxGit -Directory $destination -Arguments @('rev-parse', 'HEAD')).Stdout.Trim()
        $record.Trees['.'] = (Invoke-ParallaxGit -Directory $destination -Arguments @('rev-parse', 'HEAD^{tree}')).Stdout.Trim()
        foreach ($prefix in $Scope) {
            $clean = $prefix.Replace('\', '/').Trim('/')
            if (-not $clean) { continue }
            $tree = Invoke-ParallaxGit -Directory $destination -Arguments @('rev-parse', '--verify', '--quiet', "HEAD:$clean") -AllowFailure
            $record.Trees[$clean] = $(if ($tree.ExitCode -eq 0) { $tree.Stdout.Trim() } else { $null })
        }
        # Digest of every in-scope file (blob id and path): equal digests mean
        # equal runtime trees, whatever the builds hold outside the scope.
        $lines = [Collections.Generic.List[string]]::new()
        foreach ($entry in (Split-ParallaxNul (Invoke-ParallaxGit -Directory $destination -Arguments @('ls-tree', '-r', '-z', 'HEAD')).Stdout)) {
            $meta, $path = $entry.Split([char[]]@([char]9), 2)
            if (Test-ParallaxInScope -Path $path -Include $Scope -Exclude $ScopeExclude) { $lines.Add(($meta.Split(' ')[2]) + ' ' + $path) }
        }
        $lines.Sort([StringComparer]::Ordinal)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")) } finally { $sha.Dispose() }
        $record.ScopeFiles = $lines.Count
        $record.ScopeDigest = (($digest | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    $folder = Split-Path -Parent $recordPath
    if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -ItemType Directory -Path $folder }
    [IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [pscustomobject]$record
}

function Get-Unmerged { Split-ParallaxNul (Invoke-ParallaxGit -Directory $destination -Arguments @('diff', '--name-only', '-z', '--diff-filter=U')).Stdout }

try {
    foreach ($step in $steps) {
        $short = $step.Sha.Substring(0, 12)
        $result = [ordered]@{ Op = $step.Op; Sha = $step.Sha; Source = $step.Source; Subject = $step.Subject; Status = ''; Commit = $null; Utf16Merged = @(); Dropped = @() }
        if (-not $step.InScope.Count) {
            $result.Status = 'skipped: no change inside the scope'
            $results.Add([pscustomobject]$result)
            continue
        }
        $verb = if ($step.Op -eq 'pick') { 'cherry-pick' } else { 'revert' }
        $applied = Invoke-ParallaxGit -Directory $destination -Arguments @($verb, '--no-commit', $step.Sha) -AllowFailure
        $conflicted = @(Get-Unmerged)
        if ($applied.ExitCode -ne 0 -and -not $conflicted.Count) {
            throw "git $verb $short failed without a resolvable conflict: $(($applied.Stderr + $applied.Stdout).Trim())"
        }

        # Drop everything outside the scope: restore it to the build's HEAD.
        $touched = @(Split-ParallaxNul (Invoke-ParallaxGit -Directory $destination -Arguments @('diff', '--cached', '--no-renames', '--name-only', '-z', 'HEAD')).Stdout) + $conflicted | Sort-Object -Unique
        $dropped = @($touched | Where-Object { -not (Test-ParallaxInScope -Path $_ -Include $Scope -Exclude $ScopeExclude) })
        foreach ($path in $dropped) {
            $inHead = (Invoke-ParallaxGit -Directory $destination -Arguments @('cat-file', '-e', "HEAD:$path") -AllowFailure).ExitCode -eq 0
            if ($inHead) {
                $null = Invoke-ParallaxGit -Directory $destination -Arguments @('checkout', 'HEAD', '--', ":(literal)$path")
            } else {
                $null = Invoke-ParallaxGit -Directory $destination -Arguments @('rm', '-q', '--cached', '-f', '--', ":(literal)$path")
                $file = Join-Path $destination $path
                if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file -Force }
            }
        }
        $result.Dropped = @($dropped)

        # Binary conflicts inside the scope: UTF-16 text merge, or stop.
        $conflicted = @(Get-Unmerged)
        if ($conflicted.Count) {
            $merge = Invoke-ParallaxNative -FilePath $Python -ArgumentList (@('-I', $helper, 'resolve', '--repo', $destination) + $conflicted) -WorkingDirectory $destination
            $reports = @($merge.Stdout.Split("`n") | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() | ConvertFrom-Json })
            $bad = @($reports | Where-Object { $_.status -ne 'resolved' })
            if ($merge.ExitCode -ne 0 -or $bad.Count -or $reports.Count -ne $conflicted.Count) {
                $detail = @($bad | ForEach-Object { if ($_.PSObject.Properties['reason']) { "$($_.path): $($_.status) ($($_.reason))" } else { "$($_.path): $($_.status), $($_.conflicts) conflict(s)" } }) -join '; '
                if (-not $detail) { $detail = ($merge.Stderr + $merge.Stdout).Trim() }
                throw "git $verb $short ($($step.Subject)) conflicts in ${Name}: $detail. Not applied; the tool does not guess."
            }
            $result.Utf16Merged = @($reports | ForEach-Object { $_.path })
            $left = @(Get-Unmerged)
            if ($left.Count) { throw "Unmerged paths remain after $verb $short`: $($left -join ', ')" }
        }

        $staged = Invoke-ParallaxGit -Directory $destination -Arguments @('diff', '--cached', '--quiet') -AllowFailure
        if ($staged.ExitCode -eq 0) {
            throw "git $verb $short ($($step.Subject)) left no in-scope change in $Name (already applied, or cancelled out). Not guessing; check the spec."
        }
        $message = @(
            "perf build ${Name}: $($step.Op) $short $($step.Subject)",
            '',
            "perf-build-source: $($step.Sha)",
            "perf-build-op: $($step.Op)",
            "perf-build-unit: $($step.Source)"
        )
        if ($result.Utf16Merged.Count) { $message += "perf-build-utf16-merged: $($result.Utf16Merged -join ' ')" }
        if ($dropped.Count) { $message += "perf-build-out-of-scope: $($dropped.Count) path(s) left as at HEAD" }
        $messageFile = Join-Path ([IO.Path]::GetTempPath()) ('perf-build-' + [Guid]::NewGuid().ToString('N') + '.txt')
        try {
            [IO.File]::WriteAllText($messageFile, ($message -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
            $null = Invoke-ParallaxGit -Directory $destination -Arguments ($identity + @('commit', '-q', '-F', $messageFile))
        } finally { Remove-Item -LiteralPath $messageFile -Force -ErrorAction SilentlyContinue }
        $result.Commit = (Invoke-ParallaxGit -Directory $destination -Arguments @('rev-parse', 'HEAD')).Stdout.Trim()
        $result.Status = $(if ($result.Utf16Merged.Count) { 'applied (UTF-16 merge)' } else { 'applied' })
        $results.Add([pscustomobject]$result)
        Write-Host ("  {0,-6} {1} {2}" -f $step.Op, $short, $result.Status) -ForegroundColor DarkGray
    }
    $dirty = (Invoke-ParallaxGit -Directory $destination -Arguments @('status', '--porcelain')).Stdout.Trim()
    if ($dirty) { throw "Build $Name is not clean after its steps:`n$dirty" }
}
catch {
    $errorText = $_.Exception.Message
    if ($KeepOnFailure) {
        $null = Save-Record 'failed' $errorText
        Write-Host "Build $Name FAILED and was kept for inspection at $destination" -ForegroundColor Red
    } else {
        $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'remove', '--force', $destination) -AllowFailure
        if ((Test-Path -LiteralPath $destination) -and ([IO.Path]::GetFullPath($destination).StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase))) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'prune') -AllowFailure
        Write-Host "Build $Name FAILED and was removed." -ForegroundColor Red
    }
    throw "Build $Name failed: $errorText"
}

$record = Save-Record 'ok' ''
Write-Host ("Build {0} ready at {1}: HEAD {2}, {3} applied, {4} skipped." -f $Name, $destination, $record.Head.Substring(0, 12),
    @($results | Where-Object { $_.Status -like 'applied*' }).Count, @($results | Where-Object { $_.Status -like 'skipped*' }).Count) -ForegroundColor Green
$record
