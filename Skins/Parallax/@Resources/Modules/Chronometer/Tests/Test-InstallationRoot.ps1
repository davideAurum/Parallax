#requires -Version 5.1
<#
.SYNOPSIS
Checks the installed Parallax folder layout without changing Rainmeter or files.
.DESCRIPTION
Rainmeter resolves #@# from the first config folder beneath SkinPath. Parallax
must therefore be directly beneath SkinPath, with configs named Parallax\CPU,
Parallax\Chronometer, and so on. This checks paths, not rendering or providers.
#>
[CmdletBinding()]
param(
    [string]$RainmeterIni = (Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $RainmeterIni -PathType Leaf)) {
    throw "Rainmeter settings file not found: $RainmeterIni. Supply -RainmeterIni for the settings file used by your installation."
}

# Rainmeter's INI names are case-insensitive. Ignore later duplicates within a
# physical section, matching the first-definition behavior of its INI reader.
$sections = @{}
$current = $null
foreach ($rawLine in Get-Content -LiteralPath $RainmeterIni) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith(';')) { continue }
    if ($line -match '^\[([^\]]+)\]$') {
        $name = $Matches[1]
        if ($sections.ContainsKey($name)) {
            $current = $null
        } else {
            $current = @{}
            $sections[$name] = $current
        }
    } elseif ($null -ne $current -and $line -match '^([^=]+)=(.*)$') {
        $key = $Matches[1].Trim()
        if (-not $current.ContainsKey($key)) { $current[$key] = $Matches[2].Trim() }
    }
}

if (-not $sections.ContainsKey('Rainmeter') -or
    -not $sections['Rainmeter'].ContainsKey('SkinPath') -or
    [string]::IsNullOrWhiteSpace($sections['Rainmeter']['SkinPath'])) {
    throw 'No explicit [Rainmeter] SkinPath was found. Supply the Rainmeter.ini used by the running installation; this check does not guess a default skin folder.'
}
$configuredPath = $sections['Rainmeter']['SkinPath'].Trim('"')
if ($configuredPath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') {
    throw "SkinPath must be an absolute path for this check: $configuredPath. Resolve the configured path before checking this installation."
}
$skinPath = [IO.Path]::GetFullPath($configuredPath)
$suitePath = Join-Path $skinPath 'Parallax'
$issues = [Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $skinPath -PathType Container)) {
    $issues.Add("SkinPath does not exist: $skinPath")
}

$nestedSuite = Join-Path $skinPath 'Skins\Parallax'
if (-not (Test-Path -LiteralPath $suitePath -PathType Container) -and
    (Test-Path -LiteralPath $nestedSuite -PathType Container)) {
    $correctRoot = Join-Path $skinPath 'Skins'
    $issues.Add("SkinPath is one level too high. Parallax must be directly under SkinPath. Use SkinPath=$correctRoot\ and config names Parallax\<Module>, then restart Rainmeter; this script makes no changes.")
} else {
    $requiredFiles = @(
        '@Resources\Defaults.inc', '@Resources\Geometry.inc',
        '@Resources\Styles.inc', '@Resources\User\Settings.inc',
        'Chronometer\Chronometer.ini', 'CPU\CPU.ini', 'RAM\RAM.ini',
        'GPU\GPU.ini', 'IO\IO.ini', 'Network\Network.ini',
        'Media\Media.ini', 'Visualizer\Visualizer.ini', 'Settings\Settings.ini'
    )
    foreach ($relative in $requiredFiles) {
        $requiredPath = Join-Path $suitePath $relative
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            $issues.Add("Missing Parallax file: $requiredPath")
        }
    }
}

$activeParallax = 0
foreach ($config in ($sections.Keys | Sort-Object)) {
    if ($config -ieq 'Rainmeter' -or -not $sections[$config].ContainsKey('Active')) { continue }
    $activeIndex = 0
    if (-not [int]::TryParse($sections[$config]['Active'], [ref]$activeIndex) -or $activeIndex -le 0) { continue }
    $normalized = $config.Replace('/', '\')
    if ($normalized -match '^Skins\\Parallax(?:\\|$)' -or $normalized -match '^build(?:\\|$)') {
        $issues.Add("Active config '$config' uses the wrong root. Load Parallax\<Module> from a SkinPath containing Parallax directly; development build folders are not installed configs.")
        continue
    }
    if ($normalized -notmatch '^Parallax(?:\\|$)') { continue }
    $activeParallax++
    if ($normalized -match '(?:^|\\)\.\.?(?:\\|$)' -or $normalized.Contains(':')) {
        $issues.Add("Active Parallax config has an invalid relative path: $config")
        continue
    }
    $configPath = Join-Path $skinPath $normalized
    if (-not (Test-Path -LiteralPath $configPath -PathType Container)) {
        $issues.Add("Active Parallax config directory is missing: $configPath")
        continue
    }
    $iniFiles = @(Get-ChildItem -LiteralPath $configPath -Filter '*.ini' -File)
    if ($iniFiles.Count -eq 0 -or $activeIndex -gt $iniFiles.Count) {
        $issues.Add("Active Parallax config '$config' has Active=$activeIndex but only $($iniFiles.Count) skin INI file(s).")
    }
}

if ($issues.Count -gt 0) {
    throw ("Parallax installation-root check failed:`n- " + ($issues -join "`n- "))
}
Write-Output "PASS: Parallax is directly under SkinPath: $skinPath"
Write-Output "Shared files and nine main configs found; $activeParallax active Parallax config(s) have valid paths. Rendering and providers are not tested. No files or running settings were changed."
