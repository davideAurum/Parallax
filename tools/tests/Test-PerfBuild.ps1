#requires -Version 5.1
# Behavioural fixtures for tools/New-PerfBuild.ps1 against a scratch git
# repository: cherry-pick and revert builds, UTF-16 binary-conflict merges,
# scope, manifest roles and requirements, and the loud failures. Never touches
# the Parallax repository, Rainmeter or C:\pxab. Removes its own temp folder.
[CmdletBinding()]
param([string]$Python = 'python')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsRoot = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $toolsRoot 'New-PerfBuild.ps1'
Import-Module (Join-Path $toolsRoot 'Parallax.PerfBuild.psm1') -Force

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('pxpb-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$repo = Join-Path $fixture 'repo'
$root = Join-Path $fixture 'b'
$script:assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $script:assertions++
    $text = $null
    try { $null = & $Action } catch { $text = $_.Exception.Message }
    if ($null -eq $text) { throw "Assertion failed (no error): $Message" }
    if ($text -notmatch $Pattern) { throw "Assertion failed: $Message. Error was: $text" }
}
function Git([string[]]$Arguments) {
    $result = Invoke-ParallaxGit -Directory $repo -Arguments $Arguments
    $result.Stdout.Trim()
}
$utf16 = [Text.UnicodeEncoding]::new($false, $true)
function Get-LuaText([hashtable]$Changed = @{}) {
    $builder = [Text.StringBuilder]::new()
    for ($i = 0; $i -lt 40; $i++) {
        $line = if ($Changed.ContainsKey($i)) { $Changed[$i] } else { 'local value{0:D2} = {0} -- caf{1}' -f $i, [char]0xE9 }
        $null = $builder.Append($line).Append($(if ($i % 2) { "`n" } else { "`r`n" }))
    }
    $builder.ToString()
}
function Get-LuaBytes([hashtable]$Changed = @{}) { [byte[]](@(0xFF, 0xFE) + $utf16.GetBytes((Get-LuaText $Changed))) }
function Put-Bytes([string]$Relative, [byte[]]$Bytes) {
    $path = Join-Path $repo $Relative
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    [IO.File]::WriteAllBytes($path, $Bytes)
}
function Put-Text([string]$Relative, [string]$Text) { Put-Bytes $Relative ([Text.UTF8Encoding]::new($false).GetBytes($Text)) }
function Commit([string]$Message) { $null = Git @('add', '-A'); $null = Git @('commit', '-q', '-m', $Message); Git @('rev-parse', 'HEAD') }
function Read-BuildBytes([string]$Build, [string]$Relative) { [IO.File]::ReadAllBytes((Join-Path (Join-Path $root $Build) $Relative)) }
function Test-SameBytes([byte[]]$A, [byte[]]$B) { ($A.Length -eq $B.Length) -and (-not (Compare-Object $A $B -SyncWindow 0)) }
function Build([hashtable]$Arguments) {
    $Arguments.RepoRoot = $repo; $Arguments.Root = $root; $Arguments.Python = $Python
    & $tool @Arguments
}
function Get-Worktrees { @((Git @('worktree', 'list', '--porcelain')).Split("`n") | Where-Object { $_ -like 'worktree *' }) }

try {
    $null = New-Item -ItemType Directory -Path $repo -Force
    $null = Invoke-ParallaxGit -Directory $repo -Arguments @('init', '-q', '-b', 'main')
    foreach ($pair in @(@('user.name', 'Fixture'), @('user.email', 'fixture@localhost.invalid'), @('core.autocrlf', 'false'))) { $null = Git @('config', $pair[0], $pair[1]) }

    $lua = 'Skins/P/Mod/Controller.lua'
    $inc = 'Skins/P/Mod/Meters.inc'
    $suite = 'Skins/P/Mod/tests/Suite.lua'
    Put-Bytes $lua (Get-LuaBytes)
    Put-Text $inc "[MeterA]`nMeter=String`nUpdateDivider=1`n`n[MeterB]`nMeter=String`nText=B`n"
    Put-Text $suite "-- suite v0`nreturn {}`n"
    Put-Text 'docs/Mod.md' "# Mod`n`nNotes.`n"
    Put-Text '.gitignore' "build/`n"
    $base = Commit 'base'
    Put-Bytes $lua (Get-LuaBytes @{ 1 = 'local top = "fix one"' })
    Put-Text $suite "-- suite v1 (fix one)`nreturn {}`n"
    Put-Text 'docs/Mod.md' "# Mod`n`nNotes about fix one.`n"
    $k1 = Commit 'Fix one: top of the controller'
    Put-Bytes $lua (Get-LuaBytes @{ 1 = 'local top = "fix one"'; 38 = 'local bottom = "fix two"' })
    Put-Text $suite "-- suite v2 (fix two)`nreturn {}`n"
    Put-Text $inc "[MeterA]`nMeter=String`nUpdateDivider=-1`n`n[MeterB]`nMeter=String`nText=B`n"
    $k2 = Commit 'Fix two: bottom of the controller and the divider'
    Put-Text 'Skins/P/Mod/tests/Extra.lua' "return true`n"
    $support = Commit 'Add a test (support)'
    Put-Text $inc "[MeterA]`nMeter=String`nUpdateDivider=-1`nGroup=Rows`n`n[MeterB]`nMeter=String`nText=B`n"
    $k3 = Commit 'Fix three: needs fix two'
    Put-Text 'docs/Mod.md' "# Mod`n`nNotes about every fix.`n"
    $docs = Commit 'Docs only'
    $tip = $docs

    # A competing edit of the line fix one changes, for the conflict case.
    $null = Git @('checkout', '-q', '-b', 'other', $base)
    Put-Bytes $lua (Get-LuaBytes @{ 1 = 'local top = "competing"' })
    $competing = Commit 'Competing edit'
    # A base that already carries fix two's change, for the empty-pick case.
    $null = Git @('checkout', '-q', '-b', 'same', $base)
    Put-Bytes $lua (Get-LuaBytes @{ 38 = 'local bottom = "fix two"' })
    Put-Text $inc "[MeterA]`nMeter=String`nUpdateDivider=-1`n`n[MeterB]`nMeter=String`nText=B`n"
    $already = Commit 'Same change as fix two, made separately'
    # A merge commit.
    $null = Git @('checkout', '-q', '-b', 'side', $base)
    Put-Text 'side.txt' "side`n"
    $null = Commit 'Side change'
    $null = Git @('checkout', '-q', '-b', 'merged', $base)
    $null = Git @('merge', '-q', '--no-ff', '-m', 'merge side', 'side')
    $merge = Git @('rev-parse', 'HEAD')
    $null = Git @('checkout', '-q', '--detach', $tip)

    $manifestPath = Join-Path $fixture 'fixes.json'
    $manifestData = [ordered]@{
        schema = 1; title = 'fixture'
        baseline = @{ commit = $base }; all = @{ commit = $tip }
        scope = @{ include = @('Skins/'); exclude = @('(?i)(^|/)tests?/') }
        packages = @(@{ id = 'P1'; title = 'fixture package' })
        fixes = @(
            [ordered]@{ id = 'F1'; package = 'P1'; title = 'one'; kind = 'fix'; findings = @('X-01'); commits = @(@{ sha = $k1; role = 'fix' }); requires = @(); isolatedEffect = 'expected'; isolatedScenarios = @('solo:Mod') },
            [ordered]@{ id = 'F2'; package = 'P1'; title = 'two'; kind = 'fix'; findings = @('X-02'); commits = @(@{ sha = $k2; role = 'fix' }); requires = @(); isolatedEffect = 'expected'; isolatedScenarios = @('solo:Mod') },
            [ordered]@{ id = 'F3'; package = 'P1'; title = 'three'; kind = 'fix'; findings = @('X-03'); commits = @(@{ sha = $k3; role = 'fix' }); requires = @('F2'); isolatedEffect = 'expected'; isolatedScenarios = @('solo:Mod') }
        )
        support = @(@{ commit = $support; kind = 'test'; policy = 'excluded' }, @{ commit = $docs; kind = 'docs'; policy = 'excluded' })
    }
    [IO.File]::WriteAllText($manifestPath, ($manifestData | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))

    # Dry run: a plan, and nothing created.
    $plan = Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F2'); Name = 'p-F2'; DryRun = $true }
    Assert-True ($plan.Mode -eq 'pick' -and $plan.Start -eq $base) 'plus builds start from the baseline'
    Assert-True (@($plan.Steps).Count -eq 1 -and $plan.Steps[0].Sha -eq $k2) 'plus F2 picks exactly fix two'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'p-F2'))) 'a dry run creates nothing'
    Assert-True (@(Get-Worktrees).Count -eq 1) 'a dry run registers no worktree'
    Assert-Throws { Build @{ Manifest = $manifestPath; Set = $true; Fix = @('F1', 'F2'); Prefix = 't'; DryRun = $true } } 't-m-F2: Fixes F3 require' '-Set reports a unit that others require'
    $setPlans = @(Build @{ Manifest = $manifestPath; Set = $true; Fix = @('F1', 'F2'); Prefix = 't'; DryRun = $true; IncludeDependents = $true })
    Assert-True (($setPlans.Name -join ',') -eq 't-base,t-all,t-p-F1,t-m-F1,t-p-F2,t-m-F2') "-Set plans baseline, all and plus/minus per unit (got $($setPlans.Name -join ','))"

    # Baseline + fix two: binary conflict in the UTF-16 controller, merged as text.
    $record = Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F2'); Name = 'p-F2' }
    Assert-True ($record.Status -eq 'ok') 'plus F2 succeeds'
    Assert-True ($record.Steps[0].Status -eq 'applied (UTF-16 merge)') 'the controller needed the UTF-16 merge'
    Assert-True (@($record.Steps[0].Utf16Merged) -contains $lua) 'the merged path is recorded'
    Assert-True (@($record.Steps[0].Dropped) -contains $suite) 'the out-of-scope test change is recorded as dropped'
    Assert-True (Test-SameBytes (Read-BuildBytes 'p-F2' $lua) (Get-LuaBytes @{ 38 = 'local bottom = "fix two"' })) 'controller = base + fix two, byte for byte (BOM and mixed endings kept)'
    Assert-True ([IO.File]::ReadAllText((Join-Path $root "p-F2\$suite")) -eq "-- suite v0`nreturn {}`n") 'the test file outside the scope stays at the base'
    Assert-True ([IO.File]::ReadAllText((Join-Path $root "p-F2\$inc")) -match 'UpdateDivider=-1') 'the in-scope include change is applied'
    $onDisk = Read-ParallaxPerfBuild -BuildPath (Join-Path $root 'p-F2')
    Assert-True ($onDisk.Status -eq 'ok' -and $onDisk.ScopeDigest -match '^[0-9a-f]{64}$' -and $onDisk.Fixes -contains 'F2') 'the build record is written with a scope digest'
    Assert-True ((Invoke-ParallaxGit -Directory (Join-Path $root 'p-F2') -Arguments @('status', '--porcelain')).Stdout.Trim() -eq '') 'the build is clean (its record lives in the git-ignored build folder)'

    # Requirements.
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F3'); Name = 'p-F3' } } 'requires F2' 'a unit missing a required fix is refused'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'p-F3'))) 'a refused spec creates nothing'
    $record = Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F3'); Name = 'p-F3'; IncludeRequired = $true }
    Assert-True (($record.Fixes -join ',') -eq 'F2,F3') '-IncludeRequired adds the required fix, in history order'
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'minus'; Fix = @('F2'); Name = 'm-F2' } } 'F3 require' 'reverting a fix others require is refused'
    $record = Build @{ Manifest = $manifestPath; Role = 'minus'; Fix = @('F2'); Name = 'm-F2'; IncludeDependents = $true }
    Assert-True ((@($record.Steps | ForEach-Object { $_.Sha }) -join ',') -eq "$k3,$k2") 'dependents are reverted first (newest first)'
    Assert-True ([IO.File]::ReadAllText((Join-Path $root "m-F2\$inc")) -match 'UpdateDivider=1\n') 'all minus F2 and F3 restores the include'
    Assert-True (Test-SameBytes (Read-BuildBytes 'm-F2' $lua) (Get-LuaBytes @{ 1 = 'local top = "fix one"' })) 'all minus F2 keeps fix one in the controller'

    # All minus fix one: revert from the tip, UTF-16 merge against fix two's later change.
    $record = Build @{ Manifest = $manifestPath; Role = 'minus'; Fix = @('F1'); Name = 'm-F1' }
    Assert-True ($record.Mode -eq 'revert' -and $record.Start -eq $tip) 'minus builds revert from the tip'
    Assert-True ($record.Steps[0].Status -eq 'applied (UTF-16 merge)') 'the revert needed the UTF-16 merge'
    Assert-True (Test-SameBytes (Read-BuildBytes 'm-F1' $lua) (Get-LuaBytes @{ 38 = 'local bottom = "fix two"' })) 'controller = all minus fix one, byte for byte'
    Assert-True ([IO.File]::ReadAllText((Join-Path $root 'm-F1\docs\Mod.md')) -match 'every fix') 'docs outside the scope stay as at the tip'

    # The scope digest proves equal runtime trees: tip == baseline + every fix.
    $all = Build @{ Manifest = $manifestPath; Role = 'all'; Name = 'all' }
    $picked = Build @{ Manifest = $manifestPath; Base = $base; Pick = @('F1', 'F2', 'F3'); Name = 'all-picked' }
    Assert-True ($all.ScopeDigest -eq $picked.ScopeDigest) 'the tip and baseline + every fix have the same in-scope tree'
    Assert-True ($all.Trees['.'] -ne $picked.Trees['.']) 'while their whole trees differ outside the scope'
    # Sub-matrix: all and minus within a subset, built by picking.
    $subAll = Build @{ Manifest = $manifestPath; Role = 'all'; Within = @('F1', 'F2'); Name = 'sub-all' }
    Assert-True ($subAll.Mode -eq 'pick' -and (@($subAll.Within) -join ',') -eq 'F1,F2' -and (@($subAll.Fixes) -join ',') -eq 'F1,F2') '-Within makes all = baseline + those fixes'
    $subMinus = Build @{ Manifest = $manifestPath; Role = 'minus'; Fix = @('F1'); Within = @('F1', 'F2'); Name = 'sub-m-F1' }
    $plusTwo = Read-ParallaxPerfBuild -BuildPath (Join-Path $root 'p-F2')
    Assert-True ($subMinus.ScopeDigest -eq $plusTwo.ScopeDigest -and (@($subMinus.Fixes) -join ',') -eq 'F1') 'within {F1, F2}, minus F1 is the same runtime tree as baseline + F2'
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'all'; Within = @('F3'); Name = 'sub-bad' } } 'needs F2' '-Within must hold what its fixes require'
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'minus'; Fix = @('F3'); Within = @('F1'); Name = 'sub-bad' } } 'outside -Within' 'a unit must lie inside -Within'
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F1'); Within = @('F1'); Name = 'sub-bad' } } 'all and minus only' '-Within does not apply to plus'
    $joined = Build @{ Manifest = $manifestPath; Role = 'plus'; Fix = @('F2+F3'); Name = 'p-F2_F3' }
    Assert-True ((@($joined.Fixes) -join ',') -eq 'F2,F3' -and (@($joined.Unit) -join ',') -eq 'F2+F3') "a '+' unit measures its fixes together"

    $baseline = Build @{ Manifest = $manifestPath; Role = 'baseline'; Name = 'base' }
    Assert-True ($baseline.ScopeDigest -ne $all.ScopeDigest -and @($baseline.Steps).Count -eq 0) 'the baseline is the bare base commit (support commits are excluded)'

    # Loud failures: a UTF-16 merge with conflicts, a text conflict, an empty pick.
    $before = @(Get-Worktrees).Count
    Assert-Throws { Build @{ Base = $competing; Pick = @($k1); Name = 'clash' } } 'conflict' 'a conflicting UTF-16 change stops the build'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'clash'))) 'a failed build is removed'
    Assert-True (@(Get-Worktrees).Count -eq $before) 'and unregistered'
    Assert-Throws { Build @{ Base = $competing; Pick = @($k1); Name = 'clash'; KeepOnFailure = $true } } 'conflict' 'it also fails when kept'
    $kept = Read-ParallaxPerfBuild -BuildPath (Join-Path $root 'clash')
    Assert-True ($kept.Status -eq 'failed' -and $kept.Error -match 'conflict') 'a kept failure is recorded as failed'
    $unmerged = (Invoke-ParallaxGit -Directory (Join-Path $root 'clash') -Arguments @('diff', '--name-only', '--diff-filter=U')).Stdout.Trim()
    Assert-True ($unmerged -eq $lua) 'a kept failure is left conflicted for inspection'
    Assert-Throws { Build @{ Base = $base; Pick = @($k3); Name = 'text' } } 'byte-order mark' 'a text conflict is refused, not guessed'
    Assert-Throws { Build @{ Manifest = $manifestPath; Base = $already; Pick = @($k2); Name = 'empty' } } 'no in-scope change' 'an empty result is refused'
    Assert-Throws { Build @{ Base = $base; Pick = @($merge); Name = 'merge' } } 'Merge or root commit' 'merge commits are refused'
    Assert-Throws { Build @{ Base = $tip; Pick = @($k1); Name = 'again' } } 'already in the history' 'picking a commit the base has is refused'
    Assert-Throws { Build @{ Tip = $base; Revert = @($k1); Name = 'nothere' } } 'not in the history' 'reverting a commit the tip lacks is refused'

    # Existing paths, -Force, and the path budget.
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'all'; Name = 'all' } } 'already exists' 'an existing build is not overwritten'
    $again = Build @{ Manifest = $manifestPath; Role = 'all'; Name = 'all'; Force = $true }
    Assert-True ($again.ScopeDigest -eq $all.ScopeDigest) '-Force replaces a build this tool made'
    Assert-Throws { Build @{ Manifest = $manifestPath; Role = 'all'; Name = 'all-long-name-for-the-path-budget-test'; MaxPathLength = 120 } } 'MAX_PATH' 'the staged-path budget is enforced'

    Write-Host "Test-PerfBuild: $script:assertions assertions passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $repo) { $null = Invoke-ParallaxGit -Directory $repo -Arguments @('worktree', 'prune') -AllowFailure }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
}
