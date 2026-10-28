#requires -Version 5.1
# One-shot command line for the developer copy (see DevCopy.psm1). Global Settings runs it hidden
# through RunCommand; tools\Sync-ParallaxDev.ps1 runs it from the repository.
# Prints ASCII protocol lines only:
#   RESULT|OK|<action>|<changed files>|<utilities that differ>|<detail>
#   RESULT|ERR|<code>|<message>            (exit code 1)
#   CONFIG|<config>|<ini file>|<x or ->|<y or ->     configs to load (Enable, Reset) or unload (Disable)
# Actions: Enable (create the copy if missing, rebuild it when it was cloned from an earlier release,
# compare, list configs to load), Disable (list configs to unload; files stay), Compare, Sync (mirror
# -SourceRoot into the copy, then compare), Reset (set the copy aside as @ParallaxDev-backup-<time> and
# clone the release again).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Enable', 'Disable', 'Compare', 'Sync', 'Reset')][string]$Action,
    # The Skins folder; a trailing "\." keeps a quoted command-line argument from ending in a backslash.
    [Parameter(Mandatory)][string]$SkinsPath,
    # Folder name of the release, or of the copy (the Dev suffix is removed).
    [string]$Release = 'Parallax',
    [string]$SourceRoot,
    # Rainmeter's settings folder (Rainmeter.ini), read to find which configs are loaded.
    [string]$SettingsPath,
    [switch]$NoPlace,
    # Where to write "<phase>|<done>|<total>" while working (the Global Settings progress bar reads it).
    [string]$ProgressFile
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DevCopy.psm1') -Force
$lines = @(Invoke-ParallaxDev @PSBoundParameters)
foreach ($line in $lines) { Write-Output $line }
if ($lines[0] -like 'RESULT|ERR|*') { exit 1 }
