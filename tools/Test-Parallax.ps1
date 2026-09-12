#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$SkinRoot = (Join-Path $PSScriptRoot '..\Skins\Parallax'),
    [switch]$RequireAllModules,
    [switch]$WarningsAsErrors
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.Build.psm1') -Force
$SkinRoot = (Get-Item -LiteralPath $SkinRoot).FullName
$issues = [Collections.Generic.List[object]]::new()
$cache = @{}
function Add-Issue([string]$Level, [string]$File, [int]$Line, [string]$Message) {
    $issues.Add([pscustomobject]@{ Level = $Level; File = $File; Line = $Line; Message = $Message })
}
function Read-Ini([string]$Path) {
    if ($cache.ContainsKey($Path)) { return $cache[$Path] }
    $sections = [Collections.Generic.List[object]]::new()
    $includes = [Collections.Generic.List[object]]::new()
    $seenSections = @{}
    $section = $null
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $Path) {
        $lineNumber++
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith(';')) { continue }
        if ($trimmed -match '^\[([^\]]+)\]\s*$') {
            $name = $Matches[1]
            if ($seenSections.ContainsKey($name)) {
                Add-Issue 'Error' $Path $lineNumber "Duplicate section [$name] in the same file; Rainmeter ignores the later section."
            }
            $seenSections[$name] = $true
            $section = [pscustomobject]@{ Name = $name; Line = $lineNumber; Keys = @{} }
            $sections.Add($section)
            continue
        }
        if ($trimmed -notmatch '^([^=]+)=(.*)$') {
            Add-Issue 'Warning' $Path $lineNumber 'Unrecognized INI line; check continuation or malformed syntax manually.'
            continue
        }
        $key = $Matches[1].Trim()
        $value = $Matches[2].Trim()
        if ($null -eq $section) {
            Add-Issue 'Error' $Path $lineNumber "Option '$key' appears before a section."
            continue
        }
        if ($section.Keys.ContainsKey($key)) { Add-Issue 'Error' $Path $lineNumber "Duplicate option '$key' in [$($section.Name)]." }
        $section.Keys[$key] = [pscustomobject]@{ Value = $value; Line = $lineNumber }
        if ($key -like '@Include*') { $includes.Add([pscustomobject]@{ Value = $value; Line = $lineNumber }) }
    }
    $parsed = [pscustomobject]@{ Sections = $sections; Includes = $includes }
    $cache[$Path] = $parsed
    return $parsed
}
function Expand-PathVariables([string]$Value, [hashtable]$Variables) {
    for ($i = 0; $i -lt 20; $i++) {
        $expanded = [regex]::Replace($Value, '#([^#]+)#', {
            param($match)
            if ($Variables.ContainsKey($match.Groups[1].Value)) { return [string]$Variables[$match.Groups[1].Value] }
            return $match.Value
        })
        if ($expanded -eq $Value) { break }
        $Value = $expanded
    }
    return $Value
}
function Visit-Ini([string]$Path, [hashtable]$State) {
    if ($State.Active.ContainsKey($Path)) { Add-Issue 'Error' $Path 0 'Circular @Include dependency.'; return }
    if ($State.Visited.ContainsKey($Path)) { Add-Issue 'Warning' $Path 0 'File included more than once in this config.'; return }
    $State.Active[$Path] = $true
    $State.Visited[$Path] = $true
    $parsed = Read-Ini $Path
    foreach ($section in $parsed.Sections) {
        if ($State.Sections.ContainsKey($section.Name)) {
            if ($section.Name -ine 'Variables' -and $State.Sections[$section.Name].File -ine $Path) {
                Add-Issue 'Warning' $Path $section.Line "[$($section.Name)] also exists in another included file; review the intended override order."
            }
        } else {
            $State.Sections[$section.Name] = [pscustomobject]@{ Keys = @{}; File = $Path; Line = $section.Line }
        }
        # Options are consumed in file order. An include runs at its key, then
        # later local assignments can override the included defaults.
        foreach ($key in ($section.Keys.Keys | Sort-Object { $section.Keys[$_].Line })) {
            $entry = $section.Keys[$key]
            if ($key -notlike '@Include*') {
                $State.Sections[$section.Name].Keys[$key] = $entry
                if ($section.Name -ieq 'Variables') { $State.Variables[$key] = $entry.Value }
                continue
            }
            $target = Expand-PathVariables $entry.Value.Trim('"') $State.Variables
            if ($target -match '#[^#]+#|\[[^\]]+\]') {
                Add-Issue 'Error' $Path $entry.Line 'Include path cannot be resolved statically. Use a shipped default path and document dynamic alternatives.'
                continue
            }
            if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path -Parent $Path) $target }
            try { $target = [IO.Path]::GetFullPath($target) } catch {
                Add-Issue 'Error' $Path $entry.Line 'Invalid include path.'; continue
            }
            if (-not (Test-ParallaxChildPath $target $SkinRoot)) {
                Add-Issue 'Error' $Path $entry.Line 'Include points outside the distributable Parallax root.'; continue
            }
            if (-not $productionPaths.ContainsKey($target)) {
                $reason = Get-ParallaxExclusionReason (Get-ParallaxRelativePath $target $SkinRoot)
                if ($reason -or (Test-Path -LiteralPath $target -PathType Leaf)) {
                    Add-Issue 'Error' $Path $entry.Line 'Required include points into an excluded or undiscovered path.'; continue
                }
            }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                Add-Issue 'Error' $Path $entry.Line "Missing include: $(Get-ParallaxRelativePath $target $SkinRoot)"; continue
            }
            Visit-Ini $target $State
        }
    }
    $State.Active.Remove($Path)
}

$files = @(Get-ParallaxFiles $SkinRoot -ProductionOnly)
$productionPaths = @{}
foreach ($file in $files) { $productionPaths[$file.FullName] = $true }
$configs = @($files | Where-Object { $_.Extension -ieq '.ini' -and (Get-ParallaxRelativePath $_.FullName $SkinRoot) -notmatch '^@Resources[\\/]' })
foreach ($file in $files | Where-Object { $_.Extension -in '.inc', '.ini' }) { $null = Read-Ini $file.FullName }
if ($configs.Count -eq 0) { Add-Issue 'Error' $SkinRoot 0 'No loadable skin configs found.' }
foreach ($module in 'Settings', 'Chronometer', 'CPU', 'RAM', 'GPU', 'IO', 'Network', 'Media', 'Visualizer') {
    $moduleFiles = @($configs | Where-Object { (Get-ParallaxRelativePath $_.FullName $SkinRoot) -like "$module\*" })
    if ($moduleFiles.Count -eq 0) {
        $level = 'Warning'
        if ($RequireAllModules) { $level = 'Error' }
        Add-Issue $level $SkinRoot 0 "No config yet for $module."
    }
}
foreach ($config in $configs) {
    $state = @{
        ConfigDirectory = $config.DirectoryName
        Active = @{}; Visited = @{}; Sections = @{}
        Variables = @{
            '@' = (Join-Path $SkinRoot '@Resources') + '\'
            ROOTCONFIGPATH = $SkinRoot + '\'
            CURRENTPATH = $config.DirectoryName + '\'
            CURRENTFILE = $config.Name
            ROOTCONFIG = 'Parallax'
        }
    }
    Visit-Ini $config.FullName $state
    if (-not $state.Sections.ContainsKey('Rainmeter')) { Add-Issue 'Error' $config.FullName 0 'Parallax configs require a [Rainmeter] section.' }
    if (-not $state.Sections.ContainsKey('Metadata')) { Add-Issue 'Warning' $config.FullName 0 'Release configs should contain [Metadata].' }
    $meters = @($state.Sections.Values | Where-Object { $_.Keys.ContainsKey('Meter') })
    if ($meters.Count -eq 0) { Add-Issue 'Error' $config.FullName 0 'No Meter= option found in this config or its includes.' }
    foreach ($section in $state.Sections.Values) {
        foreach ($key in $section.Keys.Keys) {
            if ($key -match '^MeasureName\d*$|^MeterStyle$') {
                $reference = Expand-PathVariables $section.Keys[$key].Value $state.Variables
                if ($reference -match '#|\[') { continue }
                foreach ($name in $reference.Split('|')) {
                    if ($name.Trim() -and -not $state.Sections.ContainsKey($name.Trim())) {
                        Add-Issue 'Error' $section.File $section.Keys[$key].Line "Unknown $key section '$($name.Trim())' (config: $($config.Name))."
                    }
                }
            }
            if ($key -ieq 'ScriptFile') {
                $target = Expand-PathVariables $section.Keys[$key].Value.Trim('"') $state.Variables
                if ($target -match '#|\[') {
                    Add-Issue 'Warning' $section.File $section.Keys[$key].Line 'ScriptFile could not be checked statically.'
                } else {
                    if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $config.DirectoryName $target }
                    if (-not (Test-ParallaxChildPath $target $SkinRoot) -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
                        Add-Issue 'Error' $section.File $section.Keys[$key].Line 'ScriptFile is missing or outside the distributable root.'
                    }
                }
            }
        }
    }
}
$uniqueIssues = @($issues | Sort-Object Level, File, Line, Message -Unique)
foreach ($issue in $uniqueIssues) {
    $displayPath = $issue.File
    if (Test-ParallaxChildPath $issue.File $SkinRoot) { $displayPath = Get-ParallaxRelativePath $issue.File $SkinRoot }
    Write-Host ('{0}: {1}:{2}: {3}' -f $issue.Level.ToUpperInvariant(), $displayPath, $issue.Line, $issue.Message)
}
$errors = @($uniqueIssues | Where-Object Level -eq 'Error').Count
$warnings = @($uniqueIssues | Where-Object Level -eq 'Warning').Count
Write-Host "Static validation: $($configs.Count) config(s), $($cache.Count) INI/include file(s), $errors error(s), $warnings warning(s). Runtime behavior is not validated."
if ($errors -gt 0 -or ($WarningsAsErrors -and $warnings -gt 0)) { throw 'Parallax static validation failed.' }
[pscustomobject]@{ Configs = $configs.Count; Files = $cache.Count; Errors = $errors; Warnings = $warnings }
