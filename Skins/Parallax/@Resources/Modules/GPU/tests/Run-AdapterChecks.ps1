#requires -Version 5.1
# Original adapter-selection checks for the Main GPU choice and the second-GPU
# ordering rule. The pure checks need no hardware; -Live also runs the real
# query once per choice on this computer and checks the reply's shape and the
# choice it honored. Reads only; no GPU, registry or settings data is changed.
# Run in Windows PowerShell 5.1, x64 or x86.
param([switch]$Live)
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run these checks in Windows PowerShell 5.1.' }
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Join-Path $PSScriptRoot '..') 'AdapterInfo.cs.txt'
Add-Type -TypeDefinition ([IO.File]::ReadAllText($sourcePath))
$script:count = 0
function Check([bool]$condition, [string]$label) {
    if (-not $condition) { throw "FAIL: $label" }
    $script:count++
}

# ChooseMain(kinds, choice): kinds is one character per hardware adapter in
# Windows' high-performance order, D discrete and I integrated.
$main = @(
    # kinds, choice, expected main, expected second
    @('', '0', -1, -1), @('', '1', -1, -1), @('', '2', -1, -1),
    @('D', '0', 0, -1), @('D', '1', 0, -1), @('D', '2', 0, -1),
    @('I', '0', 0, -1), @('I', '1', 0, -1), @('I', '2', 0, -1),
    # Hybrid laptop, discrete first (the Surface Laptop Studio's order).
    @('DI', '0', 0, 1), @('DI', '1', 1, 0), @('DI', '2', 0, 1),
    # Integrated ranked first (a power-saving order) still prefers discrete under Auto.
    @('ID', '0', 1, 0), @('ID', '1', 0, 1), @('ID', '2', 1, 0),
    # Two discrete cards: the second is the next one, whatever the choice.
    @('DD', '0', 0, 1), @('DD', '1', 0, 1), @('DD', '2', 0, 1),
    # Three or more: only one second GPU, the next in order.
    @('DDI', '0', 0, 1), @('DDI', '1', 2, 0), @('IDD', '0', 1, 0), @('IDD', '1', 0, 1),
    @('IID', '2', 2, 0)
)
foreach ($case in $main) {
    $kinds, $choice, $expected, $second = $case
    $chosen = [ParallaxGpuInfo]::ChooseMain($kinds, $choice)
    Check ($chosen -eq $expected) "ChooseMain('$kinds','$choice') = $chosen, expected $expected"
    $next = [ParallaxGpuInfo]::ChooseSecond($kinds, $chosen)
    Check ($next -eq $second) "ChooseSecond('$kinds',$chosen) = $next, expected $second"
    if ($next -ge 0) { Check ($next -ne $chosen) "second differs from main for '$kinds'" }
}
# Unknown or malformed choices are Auto; nothing but 1 and 2 changes the rule.
foreach ($choice in @($null, '', ' ', '3', '-1', '01', 'Integrated', '1.0', "1'; exit", '2 ')) {
    $expected = if ($choice -eq '2 ') { 2 } else { 0 }
    Check ([ParallaxGpuInfo]::MainChoice($choice) -eq $expected) "MainChoice('$choice')"
    if ($expected -eq 0) { Check ([ParallaxGpuInfo]::ChooseMain('ID', $choice) -eq 1) "malformed '$choice' is Auto" }
}
Check ([ParallaxGpuInfo]::ChooseMain($null, '1') -eq -1) 'null kinds'
Check ([ParallaxGpuInfo]::ChooseSecond($null, 0) -eq -1) 'null kinds second'
Check ([ParallaxGpuInfo]::ChooseSecond('DI', -1) -eq -1) 'no main, no second'
Check ([ParallaxGpuInfo]::ChooseSecond('DXI', 0) -eq 2) 'non-hardware marks are skipped'
"PASS: $script:count pure adapter-selection assertions"

if ($Live) {
    $pattern = '^OK\|[^|\r\n]+\|(\d+|\?)\|[^|\r\n]+\|[^|\r\n]+\|(PHYSICAL|DEDICATED|INTEGRATED)\|[^|\r\n]+\|[^|\r\n]+\nGPU_ADAPTER\|1\|[0-9A-F]{16}$'
    $results = @{}
    foreach ($choice in '0', '1', '2', 'x') {
        $reply = [ParallaxGpuInfo]::ReadForSkin($choice)
        $results[$choice] = $reply
        "LIVE choice=${choice}: " + ($reply -replace "`n", ' / ')
        if ($reply -notmatch '^(NONE|UNAVAILABLE|AMBIGUOUS)$') { Check ($reply -cmatch $pattern) "live reply shape for choice $choice" }
    }
    Check ($results['x'] -ceq $results['0']) 'a malformed live choice is Auto'
    Check ([ParallaxGpuInfo]::ReadForSkin() -ceq $results['0']) 'the parameterless query is Auto'
    $source = { param($reply) if ($reply -match '\|(PHYSICAL|DEDICATED|INTEGRATED)\|') { $Matches[1] } else { '' } }
    $auto, $integrated, $discrete = (& $source $results['0']), (& $source $results['1']), (& $source $results['2'])
    # Discrete when one exists under Auto and Discrete; Integrated picks an integrated one when present.
    Check ($discrete -ceq $auto) 'Discrete matches Auto (both prefer a discrete GPU)'
    if ($auto -ne 'INTEGRATED' -and $integrated -eq 'INTEGRATED') { 'LIVE: Integrated choice selected the integrated GPU over the discrete one' }
    elseif ($integrated -ceq $auto) { 'LIVE: Integrated choice fell back to Auto (no other kind of GPU here)' }
    else { Check $false 'Integrated choice neither selected an integrated GPU nor fell back to Auto' }
    "PASS: $script:count adapter assertions including live queries"
}
