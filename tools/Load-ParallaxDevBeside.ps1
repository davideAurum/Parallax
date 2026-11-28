#requires -Version 5.1
<#
.SYNOPSIS
Right-click "Load dev version beside this" for one utility (docs\DEVMODE.md).

.DESCRIPTION
Every utility's context menu ends with an item that is empty, and so absent, until

    .\tools\Load-ParallaxDevBeside.ps1 -Menu On

saves the item's title and its command, with this checkout's path, in the installed release's User\Settings.inc
(and the developer copy's, if there is one). No shipped file holds the command. Refresh all in Rainmeter
afterwards. -Menu Off clears both.

The item runs this script hidden with the clicked config and file. It mirrors the whole repository into
<Skins>\ParallaxDev (Sync-ParallaxDev.ps1, without the static validation passes), then loads that utility's dev
config beside the release window, or refreshes it where it is if it is already loaded. Failures show a message box.

Bangs go only to the Rainmeter running -RainmeterPath with the Rainmeter.ini in -SettingsPath (Parallax.Bang.psm1),
so another instance (an isolated test, for example) may stay open. If that one cannot be identified it fails before
changing anything.
#>
[CmdletBinding(DefaultParameterSetName = 'Load')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Load')][string]$Config,
    [Parameter(Mandatory, ParameterSetName = 'Load')][string]$IniFile,
    [Parameter(Mandatory, ParameterSetName = 'Menu')][ValidateSet('On', 'Off')][string]$Menu,
    # Default: SkinPath from Rainmeter's own settings file.
    [string]$SkinsPath,
    [string]$SettingsPath = (Join-Path $env:APPDATA 'Rainmeter'),
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    # Report on the console instead of a message box.
    [switch]$NoDialog
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot '..')).FullName

try {
    Import-Module (Join-Path $projectRoot 'Skins\Parallax\@Resources\Dev\DevCopy.psm1') -Force
    if (-not $SkinsPath) {
        $rainmeterIni = Join-Path $SettingsPath 'Rainmeter.ini'
        $match = [regex]::Match((Read-ParallaxDevText ([IO.File]::ReadAllBytes($rainmeterIni))).Text, '(?m)^SkinPath=([^\r\n]+)')
        if (-not $match.Success) { throw "No SkinPath in $rainmeterIni." }
        $SkinsPath = $match.Groups[1].Value.Trim()
    }
    $SkinsPath = (Get-Item -LiteralPath $SkinsPath).FullName
    $devRoot = Join-Path $SkinsPath 'ParallaxDev'

    if ($Menu) {
        $title = ''; $action = ''
        if ($Menu -eq 'On') {
            if ($projectRoot -match '["#\[\]]') { throw "This checkout's path cannot go in a Rainmeter action: $projectRoot" }
            $title = 'Load dev version beside this'
            # Rainmeter fills in #CURRENTCONFIG# and #CURRENTFILE# in the utility that was clicked.
            $action = '["conhost.exe" "--headless" "powershell.exe" "-NoProfile" "-ExecutionPolicy" "Bypass" "-File" "' +
                (Join-Path $projectRoot 'tools\Load-ParallaxDevBeside.ps1') + '" "-Config" "#CURRENTCONFIG#" "-IniFile" "#CURRENTFILE#"]'
        }
        $release = Join-Path $SkinsPath 'Parallax\@Resources\User\Settings.inc'
        if (-not (Test-Path -LiteralPath $release -PathType Leaf)) { throw "No installed Parallax at $SkinsPath." }
        $targets = @($release)
        if (Test-ParallaxDevIdentity $devRoot) { $targets += Join-Path $devRoot '@Resources\User\Settings.inc' }
        foreach ($target in $targets) {
            Set-ParallaxDevIncValue $target 'ParallaxDevMenuTitle' $title
            Set-ParallaxDevIncValue $target 'ParallaxDevMenuAction' $action
        }
        Write-Host "Menu $($Menu.ToLowerInvariant()) in $($targets.Count) copy(ies). Use Refresh all in Rainmeter."
        return
    }

    $parts = $Config.Split('\')
    if ($parts.Count -ne 2 -or $parts[0] -notin 'Parallax', 'ParallaxDev' -or $parts[1] -notin (Get-ParallaxDevMonitors)) {
        throw "Not a Parallax utility: $Config"
    }
    if ($IniFile -notmatch '^[\w\-]+\.ini$') { throw "Unexpected skin file: $IniFile" }
    $module = $parts[1]
    $devConfig = "ParallaxDev\$module"
    Import-Module (Join-Path $PSScriptRoot 'Parallax.Bang.psm1') -Force
    $iniPath = Join-Path $SettingsPath 'Rainmeter.ini'
    # Fails here, before anything is written, when the Rainmeter in use cannot be identified.
    $null = Get-ParallaxRainmeterTarget -RainmeterPath $RainmeterPath -IniPath $iniPath

    $existed = Test-Path -LiteralPath $devRoot
    $sync = Join-Path $PSScriptRoot 'Sync-ParallaxDev.ps1'
    $global:LASTEXITCODE = 0
    $output = & $sync -SkinsPath $SkinsPath -SettingsPath $SettingsPath -NoRefresh -NoValidate *>&1
    if ($LASTEXITCODE -ne 0) { throw "Sync failed: $($output -join ' ')" }

    # The free position closest to the release window, trying every spot aligned to a window or screen edge.
    function Find-NearestSpot($Window, $Obstacles, $WorkAreas) {
        $width = $Window.Right - $Window.Left; $height = $Window.Bottom - $Window.Top
        $best = $null; $bestDistance = [double]::MaxValue
        foreach ($area in $WorkAreas) {
            $xs = @($area.Left, ($area.Right - $width), $Window.Left) + @($Obstacles | ForEach-Object { $_.Right; $_.Left - $width })
            $ys = @($area.Top, ($area.Bottom - $height), $Window.Top) + @($Obstacles | ForEach-Object { $_.Bottom; $_.Top - $height })
            foreach ($x in ($xs | Sort-Object -Unique)) {
                if ($x -lt $area.Left -or $x + $width -gt $area.Right) { continue }
                foreach ($y in ($ys | Sort-Object -Unique)) {
                    if ($y -lt $area.Top -or $y + $height -gt $area.Bottom) { continue }
                    $distance = [math]::Pow($x - $Window.Left, 2) + [math]::Pow($y - $Window.Top, 2)
                    if ($distance -ge $bestDistance) { continue }
                    if ($Obstacles | Where-Object { $x -lt $_.Right -and $x + $width -gt $_.Left -and $y -lt $_.Bottom -and $y + $height -gt $_.Top }) { continue }
                    $best = @($x, $y); $bestDistance = $distance
                }
            }
        }
        return $best
    }
    function Send-Bang([string[]]$Arguments) {
        Send-ParallaxBang -Bang $Arguments[0] -Arguments @($Arguments | Select-Object -Skip 1) -RainmeterPath $RainmeterPath -IniPath $iniPath
    }
    # Rainmeter refuses to activate a skin folder created since it last listed them.
    if (-not $existed) { Send-Bang '!RefreshApp'; Start-Sleep -Seconds 6 }
    if (-not (Test-Path -LiteralPath (Join-Path $devRoot "$module\$IniFile") -PathType Leaf)) { throw "The dev copy has no $module\$IniFile." }

    $active = Get-ParallaxDevActiveConfigs $SettingsPath
    $loadedFile = $null
    if ($active.ContainsKey($devConfig)) { $loadedFile = Get-ParallaxDevConfigFile $devRoot $module $active[$devConfig] }
    if ($loadedFile -eq $IniFile) {
        # Already loaded: re-read the files and leave it where it was put.
        Send-Bang '!Refresh', $devConfig
    } else {
        $place = $null
        try {
            # A Rainmeter window's title is its skin file's full path; another instance's skins live elsewhere.
            $skinsPrefix = $SkinsPath.TrimEnd('\') + '\'
            $live = @(Get-ParallaxDevLiveWindows | Where-Object { $_.Title.StartsWith($skinsPrefix, [StringComparison]::OrdinalIgnoreCase) })
            $anchor = $live | Where-Object { $_.Title -eq "$($skinsPrefix)Parallax\$module\$IniFile" } | Select-Object -First 1
            if ($anchor) {
                $subject = [pscustomobject]@{ Name = $devConfig; Left = $anchor.Left; Top = $anchor.Top; Right = $anchor.Right; Bottom = $anchor.Bottom }
                $areas = Get-ParallaxDevWorkAreas
                $place = (Get-ParallaxDevPlacements -Windows @($subject) -Obstacles $live -WorkAreas $areas)[$devConfig]
                # Panels stacked in a column leave no side free: take the nearest free spot instead.
                if (-not $place) { $place = Find-NearestSpot $subject $live $areas }
            }
        } catch { $place = $null }
        Send-Bang '!ActivateConfig', $devConfig, $IniFile
        # No free spot beside the release: it opens where it was last, or where Rainmeter puts it.
        if ($place) { Start-Sleep -Milliseconds 600; Send-Bang '!Move', "$($place[0])", "$($place[1])", $devConfig }
    }
    Write-Host "Loaded $devConfig\$IniFile."
} catch {
    $message = $_.Exception.Message
    if ($NoDialog -or $Menu) { Write-Error $message; exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    $null = [Windows.Forms.MessageBox]::Show($message, 'Parallax dev version')
    exit 1
}
