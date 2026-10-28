#requires -Version 5.1
<#
.SYNOPSIS
Testing iteration loop for the Parallax developer copy (docs\DEVMODE.md).

.DESCRIPTION
The developer copy is a second skin folder, <Skins>\ParallaxDev, that loads beside the installed release,
<Skins>\Parallax. Each of its utilities shows a status icon after its title: red git-branch-plus when it
differs from the release, green git-compare-arrows when it matches.

Sync (the default) stages the repository's skin exactly as a release would (same file selection, same static
validation), mirrors it into the copy, compares the copy with the release, and refreshes the copy's loaded
utilities so the new files and the new icons show. Only the copy is written: the release folder, the user
settings in either folder (@Resources\User) and each folder's runtime state are never touched. The copy is created
from the installed release first when it does not exist yet.

-Watch keeps running and repeats the sync a moment after any file under Skins\Parallax changes. It stages without
the two static validation passes (about a second per sync instead of fifteen); the first sync still validates.

Other actions: Compare (re-compare only), Enable (create the copy and load it beside the release, as Global
Settings > Developer does), Disable (unload the copy; its files stay), Reset (move the copy aside as
@ParallaxDev-backup-<time> inside the Skins folder, clone the release again, then sync).

The refresh sends Rainmeter bangs from the command line, which reach whichever Rainmeter answers (normally the one you
run). -NoRefresh writes the files and the comparison only. Do not use this against an isolated test instance.
#>
[CmdletBinding()]
param(
    [ValidateSet('Sync', 'Compare', 'Enable', 'Disable', 'Reset')][string]$Action = 'Sync',
    # The Skins folder that holds the release. Default: SkinPath from Rainmeter's own settings file.
    [string]$SkinsPath,
    [string]$SettingsPath = (Join-Path $env:APPDATA 'Rainmeter'),
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..'),
    [switch]$Watch,
    [switch]$NoRefresh,
    [switch]$NoValidate,
    [switch]$KeepStage
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Get-Item -LiteralPath $ProjectRoot).FullName
$sourceSkin = Join-Path $ProjectRoot 'Skins\Parallax'
Import-Module (Join-Path $sourceSkin '@Resources\Dev\DevCopy.psm1') -Force

if (-not $SkinsPath) {
    $rainmeterIni = Join-Path $SettingsPath 'Rainmeter.ini'
    if (-not (Test-Path -LiteralPath $rainmeterIni -PathType Leaf)) { throw "No -SkinsPath given and $rainmeterIni was not found." }
    $match = [regex]::Match((Read-ParallaxDevText ([IO.File]::ReadAllBytes($rainmeterIni))).Text, '(?m)^SkinPath=([^\r\n]+)')
    if (-not $match.Success) { throw "No SkinPath in $rainmeterIni; pass -SkinsPath." }
    $SkinsPath = $match.Groups[1].Value.Trim()
}
if (-not (Test-Path -LiteralPath $SkinsPath -PathType Container)) { throw "Skins folder not found: $SkinsPath" }
$SkinsPath = (Get-Item -LiteralPath $SkinsPath).FullName

function Invoke-RainmeterBang {
    param([string[]]$Arguments)
    if ($NoRefresh) { return }
    if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { Write-Warning 'Rainmeter.exe not found; nothing refreshed.'; return }
    if (-not (Get-Process -Name Rainmeter -ErrorAction SilentlyContinue)) { Write-Warning 'Rainmeter is not running; nothing refreshed.'; return }
    & $RainmeterPath @Arguments
}

function Use-ParallaxStage {
    param([bool]$Validate)
    $arguments = @{ Version = 'dev-sync'; ProjectRoot = $ProjectRoot }
    if (-not $Validate) { $arguments['SkipValidation'] = $true }
    $stageOutput = @(& (Join-Path $PSScriptRoot 'Stage-Parallax.ps1') @arguments 6>$null)
    return $stageOutput[-1]
}

function Remove-ParallaxStage {
    param($Stage)
    $build = [IO.Path]::GetFullPath((Join-Path $ProjectRoot 'build')).TrimEnd('\') + '\'
    $root = [IO.Path]::GetFullPath($Stage.StageRoot)
    if ($root.StartsWith($build, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $root) -like 'Parallax-dev-sync-*') {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Write-DevResult {
    param([string[]]$Lines)
    $result = $Lines | Where-Object { $_ -like 'RESULT|*' } | Select-Object -First 1
    $parts = ([string]$result).Split('|')
    if ($parts.Count -lt 3 -or $parts[1] -ne 'OK') {
        throw ("Developer copy $($parts[2]): " + ($parts[3..($parts.Count - 1)] -join ' '))
    }
    $detail = if ($parts.Count -gt 5 -and $parts[5]) { ' (' + $parts[5] + ')' } else { '' }
    $differ = [int]$parts[4]
    Write-Host ("{0}: {1} file(s) differ from the release; {2} of 8 utilities show red{3}" -f $parts[2], $parts[3], $differ, $detail)
    return $parts
}

function Invoke-DevAction {
    param([string]$Name, [bool]$Validate)
    $engine = @{ Action = $Name; SkinsPath = $SkinsPath; SettingsPath = $SettingsPath }
    $stage = $null
    try {
        if ($Name -in 'Sync') {
            $stage = Use-ParallaxStage $Validate
            $engine['SourceRoot'] = $stage.SkinRoot
        }
        $lines = @(Invoke-ParallaxDev @engine)
    } finally {
        if ($null -ne $stage -and -not $KeepStage) { Remove-ParallaxStage $stage }
    }
    $parts = Write-DevResult $lines
    # Rainmeter lists skin folders when it starts or refreshes and refuses to activate one created since
    # ("exists, but is not available. Please refresh Rainmeter."), so a copy made just now needs one refresh.
    if ($parts.Count -gt 5 -and $parts[5] -match 'cloned') {
        Invoke-RainmeterBang @('!RefreshApp')
        if (-not $NoRefresh) { Start-Sleep -Seconds 6 }
        if ($Name -eq 'Sync') { Write-Host 'The copy is new and no utility of it is loaded yet: run -Action Enable (or turn on Dev mode in Global Settings).' }
    }
    foreach ($line in ($lines | Where-Object { $_ -like 'CONFIG|*' })) {
        $part = $line.Split('|')
        $config = $part[1]; $file = $part[2]
        switch ($Name) {
            'Disable' { Invoke-RainmeterBang @('!DeactivateConfig', $config) }
            { $_ -in 'Enable', 'Reset' } {
                Invoke-RainmeterBang @('!ActivateConfig', $config, $file)
                if ($part[3] -ne '-' -and $part[4] -ne '-') { Invoke-RainmeterBang @('!Move', $part[3], $part[4], $config) }
            }
            'Compare' { Invoke-RainmeterBang @('!CommandMeasure', 'MeasureParallaxDev', 'Reload()', $config) }
            default { Invoke-RainmeterBang @('!Refresh', $config) }
        }
    }
}

try {
    if ($Action -eq 'Reset') {
        Invoke-DevAction 'Reset' $false
        Invoke-DevAction 'Sync' (-not $NoValidate)
    } else {
        Invoke-DevAction $Action (-not $NoValidate)
    }
    if ($Watch) {
        if ($Action -notin 'Sync', 'Reset') { throw '-Watch repeats Sync; use it with -Action Sync.' }
        $watcher = New-Object IO.FileSystemWatcher $sourceSkin
        $watcher.IncludeSubdirectories = $true
        $watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, DirectoryName'
        $ignore = '\\(tests|Tests|QA|\.runtime|\.preview|__pycache__)(\\|$)'
        $handler = { if ($Event.SourceEventArgs.FullPath -notmatch $Event.MessageData) { $null = New-Event -SourceIdentifier 'ParallaxDevChanged' } }
        $subscriptions = @('Changed', 'Created', 'Deleted', 'Renamed') | ForEach-Object {
            Register-ObjectEvent -InputObject $watcher -EventName $_ -Action $handler -MessageData $ignore
        }
        $watcher.EnableRaisingEvents = $true
        Write-Host "Watching $sourceSkin. Ctrl+C stops."
        $due = $null
        try {
            while ($true) {
                $event = Wait-Event -SourceIdentifier 'ParallaxDevChanged' -Timeout 1
                if ($event) { Get-Event -SourceIdentifier 'ParallaxDevChanged' | Remove-Event; $due = [DateTime]::UtcNow.AddMilliseconds(800) }
                if ($due -and [DateTime]::UtcNow -ge $due) {
                    $due = $null
                    try { Invoke-DevAction 'Sync' $false } catch { Write-Warning $_.Exception.Message }
                }
            }
        } finally {
            $watcher.EnableRaisingEvents = $false
            $subscriptions | ForEach-Object { Unregister-Event -SubscriptionId $_.Id -ErrorAction SilentlyContinue }
            $watcher.Dispose()
        }
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
