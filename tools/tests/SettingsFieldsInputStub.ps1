# Test-only replacement for the isolated copy of SettingsInput.ps1.
# Production validation is dot-sourced passively; no textbox is constructed.
[CmdletBinding()]
param([string]$Key, [string]$Initial, [string]$X, [string]$Y,
    [string]$Width, [string]$Height, [string]$Scale)
$ErrorActionPreference = 'Stop'
$runRoot = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SettingsFieldsRunRoot.txt'))
$case = Get-Content -LiteralPath (Join-Path $runRoot 'helper-case.json') -Raw | ConvertFrom-Json
$report = [ordered]@{ Status='FAIL'; Sequence=$case.Sequence; Key=$Key; Initial=$Initial; X=$X; Y=$Y; Width=$Width; Height=$Height; Scale=$Scale }
$response = 'PARALLAX_INPUT_V1|cancel|'
try {
    # A child scope keeps the production script's param defaults from replacing
    # the actual RunCommand launch arguments being audited by this stub.
    $validation = & {
        param($SourceKey, $SourceInitial, $SourceInput, $SourcePath)
        . $SourcePath
        [pscustomobject]@{
            Parsed = (ConvertTo-ParallaxInputValue -InputKey $SourceKey -Text $SourceInitial)
            Protocol = (Get-ParallaxInputResponse -InputKey $SourceKey -Text $SourceInitial)
            Submitted = (ConvertTo-ParallaxInputValue -InputKey $SourceKey -Text $SourceInput)
            SubmittedProtocol = (Get-ParallaxInputResponse -InputKey $SourceKey -Text $SourceInput)
        }
    } $Key $Initial $case.Input (Join-Path $PSScriptRoot 'SettingsFieldsProductionInput.ps1')
    $parsed = $validation.Parsed
    if (-not $parsed.Valid -or $Key -cne $case.Key -or $parsed.Value -cne $case.Initial) { throw 'Production validator rejected or changed the expected initial value.' }
    $report.InitialProtocol = $validation.Protocol
    if ($case.Kind -eq 'valid') {
        if (-not $validation.Submitted.Valid -or $validation.SubmittedProtocol -cne $case.Response) { throw 'Production validator rejected or changed the submitted test value.' }
        $report.InputProtocol = $validation.SubmittedProtocol
    }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    foreach ($entry in @(@('X',$X,-100000,100000),@('Y',$Y,-100000,100000),@('Width',$Width,24,2048),@('Height',$Height,12,512))) {
        $number = 0
        if (-not [int]::TryParse($entry[1], [Globalization.NumberStyles]::AllowLeadingSign, $culture, [ref]$number) -or $number -lt $entry[2] -or $number -gt $entry[3]) { throw 'Invalid launch bounds.' }
    }
    $numericScale = [decimal]0
    if (-not [decimal]::TryParse($Scale, [Globalization.NumberStyles]::AllowDecimalPoint, $culture, [ref]$numericScale) -or $numericScale -lt 0.75 -or $numericScale -gt 2) { throw 'Invalid launch scale.' }
    $response = [string]$case.Response
    $report.Status = 'PASS'
} catch { $report.Error = $_.Exception.Message }
[IO.File]::WriteAllText((Join-Path $runRoot ('helper-' + $case.Sequence + '.json')), ($report | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
[Console]::WriteLine($response)
