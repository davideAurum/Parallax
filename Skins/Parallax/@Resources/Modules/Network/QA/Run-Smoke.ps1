#requires -Version 5.1
# Compatibility command: the former separate monitor matrix is retired.
# Both public monitor QA commands now validate the combined utility and redirect.
[CmdletBinding()]
param(
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet(180,220)][int[]]$ColumnWidths=@(180,220),
    [ValidateSet('default','maximum')][string]$Typography='maximum',
    [ValidateRange(15,60)][int]$TimeoutSeconds=60,
    [switch]$Capture,
    [switch]$KeepArtifacts
)
Write-Output 'This legacy monitor QA command now runs the combined Network matrix. Use Run-UnifiedSmoke.ps1 directly for the current contract.'
& (Join-Path $PSScriptRoot 'Run-UnifiedSmoke.ps1') @PSBoundParameters