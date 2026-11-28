# Developer-only offline test: the updater's pre-check (UpdateInstall.ps1,
# Stop-ParallaxMediaWorkers) picks this skin's resident Source, Spotify queue and
# TV queue workers, and nothing else. The process list and Stop-Process are
# stand-ins: no process is read, started or ended.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvUpdateStop.ps1
#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
$resources = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$installer = [IO.File]::ReadAllText((Join-Path $resources 'Scripts\UpdateInstall.ps1'))
$ast = [Management.Automation.Language.Parser]::ParseInput($installer, [ref]$null, [ref]$null)
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-ParallaxMediaWorkers' }, $true)
Assert-Check ($null -ne $function) 'the updater has its worker pre-check'
$skin = 'C:\Synthetic\Skins\Parallax'
. ([scriptblock]::Create($function.Extent.Text.Replace("Join-Path `$PSScriptRoot '..\..'", "Join-Path '$skin\@Resources\Scripts' '..\..'")))

$media = "$skin\@Resources\Modules\Media"
$host51 = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
# Ids far above any real process, so the wait that follows finds nothing.
function New-Line([int]$Id, [string]$Script, [string]$Rest) {
    [pscustomobject]@{ ProcessId = 2000000000 + $Id; CommandLine = '"' + $host51 + '" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $Script + '" ' + $Rest }
}
$script:processes = @(
    New-Line 1 "$media\Source\SourceProvider.ps1" '-Command Run -Quiet'
    New-Line 2 "$media\Queue\QueueProvider.ps1" '-Command Run -PollSeconds 30'
    # As TvProvider.ps1's Start-TvBackground writes it.
    New-Line 3 "$media\TvQueue\TvProvider.ps1" '-Command Run -Quiet -LaunchId 0123456789abcdef0123456789abcdef -DataRoot "C:\Synthetic\Data" -Takeover'
    New-Line 4 "$media\TvQueue\TvProvider.ps1" '-Command Stop -Quiet'
    New-Line 5 'C:\Synthetic\Skins\ParallaxDev\@Resources\Modules\Media\TvQueue\TvProvider.ps1' '-Command Run -Quiet'
    New-Line 6 "$media\TvQueue\Other.ps1" '-Command Run'
)
$script:stopped = [Collections.Generic.List[int]]::new()
function Get-CimInstance { param($ClassName, $Filter, $Property) $script:processes }
function Stop-Process { param([int]$Id, [switch]$Force, $ErrorAction) $script:stopped.Add($Id - 2000000000) }

$result = Stop-ParallaxMediaWorkers
Assert-Check ($null -eq $result) 'nothing is left running'
Assert-Check (($script:stopped -join ',') -eq '1,2,3') "stops this skin's three resident workers only (stopped: $($script:stopped -join ','))"
"PASS $($script:checks)"
