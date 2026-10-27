#requires -Version 5.1
# Static include-variant checks. Never loads Rainmeter, touches no live profile
# and writes only its own fixtures under the temp folder.
#
# Rainmeter picks some includes by a saved value (VisualizerDrawer<n>.inc,
# DrawerCapture<n>.inc), so a plain validator run sees only the variant the
# shipped files name. This runner:
#   1. proves on small fixtures that Test-Parallax.ps1 -Variable selects the
#      alternate include, and that a missing include, an unknown MeasureName
#      and an unknown bang target in a variant are each reported;
#   2. runs Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors on the real
#      tree once per listed variant set (0 errors, 0 warnings each);
#   3. checks, per config and variant set, that every static action bang naming
#      a section in its own skin names one that exists there. Checked bangs:
#      !CommandMeasure, !UpdateMeasure, !UpdateMeter, !UpdateMeterGroup,
#      !ShowMeter, !HideMeter and !SetOption, each only without a config
#      argument (with one, the target is another skin's business). Targets that
#      still hold a #variable# or [section] reference after static expansion
#      are dynamic and skipped; so is '*'.
[CmdletBinding()]
param(
    [string]$SkinRoot = '',
    [switch]$SkipFixtures,
    [switch]$SkipValidator
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 leaves $PSScriptRoot empty while it evaluates
# parameter defaults, so the default skin root is resolved here.
if (-not $SkinRoot) { $SkinRoot = Join-Path $PSScriptRoot '..\..\Skins\Parallax' }
$toolsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $toolsRoot 'Parallax.Build.psm1') -Force
$validator = Join-Path $toolsRoot 'Test-Parallax.ps1'
$SkinRoot = (Get-Item -LiteralPath $SkinRoot).FullName

# Every include variant a saved value can select, as validator -Variable sets.
# The empty set is the shipped default.
$variantSets = @(
    , @()
    , @('VisualizerDrawer=0')
    # The open drawer's capture variants (Modules\Media\DrawerCapture<n>.inc).
    , @('VisualizerDrawer=2', 'MediaDrawerCapture=0')
    , @('VisualizerDrawer=2', 'MediaDrawerCapture=1')
    , @('VisualizerDrawer=2', 'MediaDrawerCapture=2')
    # Idle pause on (Hook5/10/30.inc load the stand-down hook in every utility).
    , @('IdlePauseMinutes=5')
    # Media stood down for the idle pause: provider tick, open drawer parked.
    , @('IdlePauseMinutes=5', 'MediaStandby=1', 'VisualizerDrawer=2', 'MediaDrawerCapture=1')
    # The standalone Audio Visualizer stood down (Standalone1.inc, no capture).
    , @('IdlePauseMinutes=5', 'VisualizerStandby=1')
    , @('VisualizerStandby=1')
    , @('UpdateCheck=0')
)

$assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Variant check failed: $Message" }
    $script:assertions++
}

# --- A small Rainmeter-like resolver -------------------------------------
# Every config re-reads the shared includes once per variant set; the files do
# not change during a run (fixtures are written before they are read).
$parsedIni = @{}
function Read-VariantIni([string]$Path) {
    if ($parsedIni.ContainsKey($Path)) { return $parsedIni[$Path] }
    $sections = [Collections.Generic.List[object]]::new()
    $section = $null
    $number = 0
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $number++
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith(';')) { continue }
        if ($trimmed -match '^\[([^\]]+)\]\s*$') {
            $section = [pscustomobject]@{ Name = $Matches[1]; Keys = [Collections.Generic.List[object]]::new() }
            $sections.Add($section)
            continue
        }
        if ($null -eq $section -or $trimmed -notmatch '^([^=]+)=(.*)$') { continue }
        $section.Keys.Add([pscustomobject]@{ Key = $Matches[1].Trim(); Value = $Matches[2].Trim(); Line = $number })
    }
    $parsedIni[$Path] = $sections
    return $sections
}

$staticToken = [regex]::new('#([^#\s]+)#')
function Expand-Static([string]$Value, [hashtable]$Variables) {
    for ($i = 0; $i -lt 30; $i++) {
        # [regex]::Replace keeping unknown #names#, written as a loop: a
        # script-block evaluator per match is slow over every action of every config.
        $text = [Text.StringBuilder]::new()
        $last = 0
        foreach ($match in $staticToken.Matches($Value)) {
            $name = $match.Groups[1].Value
            $replacement = if ($Variables.ContainsKey($name)) { [string]$Variables[$name] } else { $match.Value }
            $null = $text.Append($Value, $last, $match.Index - $last).Append($replacement)
            $last = $match.Index + $match.Length
        }
        $expanded = $text.Append($Value, $last, $Value.Length - $last).ToString()
        if ($expanded -eq $Value) { break }
        $Value = $expanded
    }
    return $Value
}

# Includes are read where their key appears, with the variables known then;
# a -Variable override outlasts every file assignment (as in Test-Parallax).
function Resolve-VariantConfig([string]$ConfigPath, [hashtable]$Overrides, [string]$Root = $SkinRoot) {
    $state = @{
        Variables = @{
            '@' = (Join-Path $Root '@Resources') + '\'
            ROOTCONFIGPATH = $Root + '\'
            CURRENTPATH = (Split-Path -Parent $ConfigPath) + '\'
            CURRENTFILE = (Split-Path -Leaf $ConfigPath)
            ROOTCONFIG = 'Parallax'
        }
        Sections = @{}
        Files = [Collections.Generic.List[string]]::new()
        Missing = [Collections.Generic.List[string]]::new()
    }
    foreach ($name in $Overrides.Keys) { $state.Variables[$name] = $Overrides[$name] }
    $visit = $null
    $visit = {
        param([string]$Path)
        if ($state.Files.Contains($Path)) { return }
        $state.Files.Add($Path)
        foreach ($section in Read-VariantIni $Path) {
            if (-not $state.Sections.ContainsKey($section.Name)) {
                $state.Sections[$section.Name] = [pscustomobject]@{ Name = $section.Name; File = $Path; Keys = @{} }
            }
            foreach ($entry in $section.Keys) {
                if ($entry.Key -notlike '@Include*') {
                    $state.Sections[$section.Name].Keys[$entry.Key] = $entry
                    if ($section.Name -ieq 'Variables') {
                        $state.Variables[$entry.Key] = $entry.Value
                        if ($Overrides.ContainsKey($entry.Key)) { $state.Variables[$entry.Key] = $Overrides[$entry.Key] }
                    }
                    continue
                }
                $target = Expand-Static $entry.Value.Trim('"') $state.Variables
                if ($target -match '#[^#]+#') { $state.Missing.Add($target); continue }
                if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path -Parent $Path) $target }
                $target = [IO.Path]::GetFullPath($target)
                if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $state.Missing.Add($target); continue }
                & $visit $target
            }
        }
    }
    & $visit $ConfigPath
    return $state
}

# Rainmeter's multi-bang split counts brackets without regard to quotes.
function Get-BangCommands([string]$Text) {
    $commands = [Collections.Generic.List[string]]::new()
    $depth = 0
    $start = -1
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $character = $Text[$i]
        if ($character -eq '[') {
            if ($depth -eq 0) { $start = $i }
            $depth++
        } elseif ($character -eq ']') {
            $depth--
            if ($depth -eq 0 -and $start -ge 0) {
                $commands.Add($Text.Substring($start + 1, $i - $start - 1).Trim())
                $start = -1
            }
        }
    }
    if ($commands.Count -eq 0 -and $Text.TrimStart().StartsWith('!')) { $commands.Add($Text.Trim()) }
    return $commands
}

# Whitespace-separated arguments; "..." and """...""" group as Rainmeter's
# ParseString does.
function Split-BangArguments([string]$Text) {
    $arguments = [Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $Text.Length) {
        while ($i -lt $Text.Length -and [char]::IsWhiteSpace($Text[$i])) { $i++ }
        if ($i -ge $Text.Length) { break }
        if ($Text.Substring($i).StartsWith('"""')) {
            $end = $Text.IndexOf('"""', $i + 3)
            if ($end -lt 0) { $end = $Text.Length }
            $arguments.Add($Text.Substring($i + 3, $end - $i - 3)); $i = $end + 3
        } elseif ($Text[$i] -eq '"') {
            $end = $Text.IndexOf('"', $i + 1)
            if ($end -lt 0) { $end = $Text.Length }
            $arguments.Add($Text.Substring($i + 1, $end - $i - 1)); $i = $end + 1
        } else {
            $end = $i
            while ($end -lt $Text.Length -and -not [char]::IsWhiteSpace($Text[$end])) { $end++ }
            $arguments.Add($Text.Substring($i, $end - $i)); $i = $end
        }
    }
    return $arguments
}

# Bang -> number of arguments before the optional config, and target kind.
$checkedBangs = @{
    '!CommandMeasure' = @{ Count = 2; Kind = 'Measure' }
    '!UpdateMeasure' = @{ Count = 1; Kind = 'Measure' }
    '!UpdateMeter' = @{ Count = 1; Kind = 'Meter' }
    '!UpdateMeterGroup' = @{ Count = 1; Kind = 'MeterGroup' }
    '!ShowMeter' = @{ Count = 1; Kind = 'Meter' }
    '!HideMeter' = @{ Count = 1; Kind = 'Meter' }
    '!SetOption' = @{ Count = 3; Kind = 'Section' }
}

function Test-BangTargets($Resolved, [string]$Label) {
    $problems = [Collections.Generic.List[string]]::new()
    $checked = 0
    $meterGroups = @{}
    foreach ($section in $Resolved.Sections.Values) {
        if (-not $section.Keys.ContainsKey('Meter') -or -not $section.Keys.ContainsKey('Group')) { continue }
        foreach ($group in $section.Keys['Group'].Value.Split('|')) { if ($group.Trim()) { $meterGroups[$group.Trim()] = $true } }
    }
    foreach ($section in $Resolved.Sections.Values) {
        if ($section.Name -in @('Variables', 'Metadata')) { continue }
        foreach ($key in @($section.Keys.Keys)) {
            if ($key -notmatch '(?i)Action\d*$') { continue }
            $entry = $section.Keys[$key]
            $text = Expand-Static $entry.Value $Resolved.Variables
            foreach ($command in Get-BangCommands $text) {
                $arguments = @(Split-BangArguments $command)
                if ($arguments.Count -eq 0) { continue }
                $bang = $arguments[0]
                $rule = $null
                foreach ($name in $checkedBangs.Keys) { if ($name -ieq $bang) { $rule = $checkedBangs[$name] } }
                if ($null -eq $rule) { continue }
                $parameters = @($arguments | Select-Object -Skip 1)
                if ($parameters.Count -gt $rule.Count) { continue }  # names another config
                if ($parameters.Count -lt 1) { $problems.Add("${Label}: [$($section.Name)] $key has $bang without a target."); continue }
                $target = $parameters[0]
                if ($target -eq '*' -or $target -match '#|\[|\]') { continue }
                $checked++
                $found = $false
                switch ($rule.Kind) {
                    'MeterGroup' { $found = $meterGroups.ContainsKey($target) }
                    default {
                        if ($Resolved.Sections.ContainsKey($target)) {
                            $keys = $Resolved.Sections[$target].Keys
                            $found = switch ($rule.Kind) {
                                'Measure' { $keys.ContainsKey('Measure') }
                                'Meter' { $keys.ContainsKey('Meter') }
                                default { $keys.ContainsKey('Measure') -or $keys.ContainsKey('Meter') }
                            }
                        }
                    }
                }
                if (-not $found) {
                    $where = $section.File
                    if (Test-ParallaxChildPath $section.File $SkinRoot) { $where = Get-ParallaxRelativePath $section.File $SkinRoot }
                    $problems.Add("${Label}: $where [$($section.Name)] $key line $($entry.Line): $bang names no $($rule.Kind.ToLowerInvariant()) '$target' in this skin.")
                }
            }
        }
    }
    return [pscustomobject]@{ Problems = $problems; Checked = $checked }
}

function Get-Configs([string]$Root) {
    @(Get-ParallaxFiles $Root -ProductionOnly | Where-Object {
        $_.Extension -ieq '.ini' -and (Get-ParallaxRelativePath $_.FullName $Root) -notmatch '^@Resources[\\/]'
    } | Sort-Object FullName)
}

function ConvertTo-Overrides([string[]]$Set) {
    $table = @{}
    foreach ($assignment in $Set) {
        $name, $value = $assignment -split '=', 2
        $table[$name] = $value
    }
    return $table
}

# Runs the validator in this process and returns its result object, its
# printed issue lines and whether it threw.
function Invoke-Validator([string]$Root, [string[]]$Set, [switch]$Strict) {
    $lines = [Collections.Generic.List[string]]::new()
    $result = $null
    $failed = $false
    $arguments = @{ SkinRoot = $Root }
    if ($Set.Count) { $arguments.Variable = $Set }
    if ($Strict) { $arguments.RequireAllModules = $true; $arguments.WarningsAsErrors = $true }
    try {
        & $validator @arguments 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) { $lines.Add([string]$_.MessageData) } else { $result = $_ }
        }
    } catch { $failed = $true }
    return [pscustomobject]@{ Result = $result; Lines = $lines; Failed = $failed }
}

# The strict real-tree runs are independent, so they start together as
# background jobs (a process each; runspaces in one process did not run them
# any faster), and Receive-Validator returns what Invoke-Validator -Strict
# would have for that set.
function Start-Validator([string]$Root, [string[]]$Set) {
    Start-Job -ArgumentList $validator, $Root, $Set -ScriptBlock {
        param($Validator, $Root, $Set)
        # Invoke-Validator -Strict, inside the job.
        $arguments = @{ SkinRoot = $Root; RequireAllModules = $true; WarningsAsErrors = $true }
        if (@($Set).Count) { $arguments.Variable = [string[]]@($Set) }
        $lines = [Collections.Generic.List[string]]::new()
        $result = $null
        $failed = $false
        try {
            & $Validator @arguments 6>&1 | ForEach-Object {
                if ($_ -is [Management.Automation.InformationRecord]) { $lines.Add([string]$_.MessageData) } else { $result = $_ }
            }
        } catch { $failed = $true }
        [pscustomobject]@{ Result = $result; Lines = @($lines); Failed = $failed }
    }
}

function Receive-Validator($Job) {
    $run = $null
    try { $run = Receive-Job (Wait-Job $Job) -ErrorAction Stop } catch { }
    Remove-Job $Job -Force
    if ($null -eq $run) { return [pscustomobject]@{ Result = $null; Lines = @(); Failed = $true } }
    return [pscustomobject]@{ Result = $run.Result; Lines = @($run.Lines); Failed = [bool]$run.Failed }
}

# --- 1. Fixtures ------------------------------------------------------------
if (-not $SkipFixtures) {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-Variants-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
    $fixtureSkin = Join-Path $fixtureRoot 'Skins\Parallax'
    function Put-Fixture([string]$Relative, [string]$Content) {
        $path = Join-Path $fixtureSkin $Relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
    }
    Put-Fixture 'Demo\Demo.ini' @'
[Rainmeter]
Update=1000
OnRefreshAction=[!UpdateMeter MeterBase][!SetOption MeterBase Text "Loaded"][!Delay 100][!UpdateMeasureGroup DemoGroup]
[Metadata]
Name=Variant fixture
[Variables]
DemoMode=0
@Include1=#@#Defaults.inc
@Include2=#@#Demo\Variant#DemoMode#.inc
[MeterBase]
Meter=String
Text=Base
'@
    Put-Fixture '@Resources\Defaults.inc' "[Variables]`nDemoColor=1,2,3`n"
    Put-Fixture '@Resources\Demo\Variant0.inc' @'
[MeasureDemoValue]
Measure=Calc
Formula=0
OnUpdateAction=[!CommandMeasure MeasureDemoValue "Noop()"][!UpdateMeterGroup DemoMeters]
[MeterDemoZero]
Meter=String
MeasureName=MeasureDemoValue
Group=DemoMeters
LeftMouseUpAction=[!SetOption MeterDemoZero Text "x"][!UpdateMeter MeterDemoZero][!HideMeter MeterBase]
'@
    Put-Fixture '@Resources\Demo\Variant1.inc' @'
[MeterDemoOne]
Meter=String
MeasureName=MeasureOnlyInVariantZero
'@
    Put-Fixture '@Resources\Demo\Variant2.inc' @'
[Variables]
@Include3=#@#Demo\Absent.inc
[MeterDemoTwo]
Meter=String
Text=Two
'@
    Put-Fixture '@Resources\Demo\Variant3.inc' @'
[MeterDemoThree]
Meter=String
Text=Three
LeftMouseUpAction=[!ShowMeter MeterNowhere][!UpdateMeterGroup NoSuchGroup][!SetOption MeterElsewhere Text "y" "Parallax\Other"][!CommandMeasure MeasureElsewhere "Run" "Parallax\Other"]
MouseOverAction=[!UpdateMeasure MeasureNotHere]
'@
    $demoConfig = Join-Path $fixtureSkin 'Demo\Demo.ini'

    $run = Invoke-Validator $fixtureSkin @()
    Assert-True (-not $run.Failed -and $run.Result.Errors -eq 0) 'The shipped fixture variant validates with no error.'
    $resolved = Resolve-VariantConfig $demoConfig @{} $fixtureSkin
    Assert-True (@($resolved.Files -match 'Variant0\.inc$').Count -eq 1) 'Without an override the shipped value selects Variant0.inc.'
    $targets = Test-BangTargets $resolved 'fixture 0'
    Assert-True ($targets.Problems.Count -eq 0) 'Every Variant0 bang target resolves.'
    Assert-True ($targets.Checked -eq 7) "Seven Variant0/base bang targets are checked, not $($targets.Checked)."

    $run = Invoke-Validator $fixtureSkin @('DemoMode=1')
    $resolved = Resolve-VariantConfig $demoConfig (ConvertTo-Overrides @('DemoMode=1')) $fixtureSkin
    Assert-True (@($resolved.Files -match 'Variant1\.inc$').Count -eq 1 -and @($resolved.Files -match 'Variant0\.inc$').Count -eq 0) 'DemoMode=1 selects Variant1.inc instead of Variant0.inc.'
    Assert-True ($run.Failed -and $run.Result -eq $null) 'The validator fails the Variant1 run.'
    Assert-True (@($run.Lines -match "Unknown MeasureName section 'MeasureOnlyInVariantZero'").Count -eq 1) 'An unknown MeasureName in a variant is an error.'
    Assert-True (@($run.Lines -match 'Variant1\.inc').Count -ge 1) 'The error names the alternate include.'

    $run = Invoke-Validator $fixtureSkin @('DemoMode=2')
    Assert-True ($run.Failed) 'The validator fails the Variant2 run.'
    Assert-True (@($run.Lines -match 'ERROR: .*Variant2\.inc.*Missing include: @Resources\\Demo\\Absent\.inc').Count -eq 1) 'A missing include in a variant is an error.'

    $run = Invoke-Validator $fixtureSkin @('DemoMode=9')
    Assert-True ($run.Failed -and @($run.Lines -match 'Missing include: @Resources\\Demo\\Variant9\.inc').Count -eq 1) 'A value naming no variant is a missing include.'

    $run = Invoke-Validator $fixtureSkin @('DemoMode=3')
    Assert-True (-not $run.Failed -and $run.Result.Errors -eq 0) 'Bang targets are outside the INI validator; Variant3 passes it.'
    $targets = Test-BangTargets (Resolve-VariantConfig $demoConfig (ConvertTo-Overrides @('DemoMode=3')) $fixtureSkin) 'fixture 3'
    Assert-True ($targets.Problems.Count -eq 3) "Three unknown same-skin targets are reported in Variant3, not $($targets.Problems.Count)."
    Assert-True (@($targets.Problems -match "meter 'MeterNowhere'").Count -eq 1) 'An unknown !ShowMeter target is an error.'
    Assert-True (@($targets.Problems -match "metergroup 'NoSuchGroup'").Count -eq 1) 'An unknown !UpdateMeterGroup group is an error.'
    Assert-True (@($targets.Problems -match "measure 'MeasureNotHere'").Count -eq 1) 'An unknown !UpdateMeasure target is an error.'
    Assert-True (@($targets.Problems -match 'Elsewhere').Count -eq 0) 'Bangs naming another config are not checked here.'
    Write-Output "Fixtures: $assertions assertions passed (retained at $fixtureRoot)."
}

# --- 2 and 3. The real tree, once per variant set -------------------------------
$configs = Get-Configs $SkinRoot
$totalChecked = 0
$failures = [Collections.Generic.List[string]]::new()
$pending = @{}
if (-not $SkipValidator) {
    for ($index = 0; $index -lt $variantSets.Count; $index++) { $pending[$index] = Start-Validator $SkinRoot $variantSets[$index] }
}
for ($index = 0; $index -lt $variantSets.Count; $index++) {
    $set = $variantSets[$index]
    $label = if ($set.Count) { $set -join ', ' } else { 'shipped values' }
    if (-not $SkipValidator) {
        $run = Receive-Validator $pending[$index]
        foreach ($line in $run.Lines) { if ($line -match '^(ERROR|WARNING):') { $failures.Add("[$label] $line") } }
        if ($run.Failed -or $null -eq $run.Result -or $run.Result.Errors -ne 0 -or $run.Result.Warnings -ne 0) {
            $failures.Add("[$label] Test-Parallax -RequireAllModules -WarningsAsErrors did not give 0 errors and 0 warnings.")
        } else {
            Write-Output ("Validator [{0}]: {1} configs, {2} files, 0 errors, 0 warnings." -f $label, $run.Result.Configs, $run.Result.Files)
            $script:assertions++
        }
    }
    $overrides = ConvertTo-Overrides $set
    $setChecked = 0
    foreach ($config in $configs) {
        $resolved = Resolve-VariantConfig $config.FullName $overrides
        foreach ($missing in $resolved.Missing) { $failures.Add("[$label] $($config.Name): include not found: $missing") }
        $targets = Test-BangTargets $resolved "[$label] $(Get-ParallaxRelativePath $config.FullName $SkinRoot)"
        foreach ($problem in $targets.Problems) { $failures.Add($problem) }
        $setChecked += $targets.Checked
    }
    $totalChecked += $setChecked
    Write-Output ("Bang targets [{0}]: {1} same-skin targets in {2} configs." -f $label, $setChecked, $configs.Count)
}
foreach ($failure in $failures) { Write-Output "FAIL: $failure" }
if ($failures.Count) { throw "Variant checks failed: $($failures.Count) problem(s)." }
Write-Output ("PASS: {0} assertions; {1} variant sets; {2} bang targets resolved across {3} configs each." -f $assertions, $variantSets.Count, $totalChecked, $configs.Count)
