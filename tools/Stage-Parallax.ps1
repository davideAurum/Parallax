#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Version,
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..'),
    [switch]$RequireAllModules
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Parallax.Build.psm1') -Force
$ProjectRoot = (Get-Item -LiteralPath $ProjectRoot).FullName
$skinRoot = Join-Path $ProjectRoot 'Skins\Parallax'
$buildRoot = Join-Path $ProjectRoot 'build'

# Do not follow a junction/symlink in any source or destination ancestor.
foreach ($path in @($ProjectRoot, (Join-Path $ProjectRoot 'Skins'), $skinRoot, $buildRoot)) {
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Expected a regular directory, not a file or reparse point: $path"
        }
    }
}
$null = & (Join-Path $PSScriptRoot 'Test-Parallax.ps1') -SkinRoot $skinRoot -RequireAllModules:$RequireAllModules
$excluded = [Collections.Generic.List[object]]::new()
$sourceFiles = @(Get-ParallaxFiles $skinRoot -ProductionOnly -ExcludedEntries $excluded | Sort-Object FullName)
$allowedExtensions = @('.ini', '.inc', '.lua', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.svg', '.wav', '.ogg', '.mp3', '.ttf', '.otf', '.txt', '.md')
# Reviewed helper/build payloads and extensionless license notices. Exact paths do not override private,
# hidden, test, fixture, runtime, or cache exclusions above or below.
$allowedExactPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in @(
    '@Resources\Scripts\SettingsInput.ps1',
    '@Resources\Modules\Chronometer\EventEditor.exe',
    '@Resources\Modules\Chronometer\EventEditor.cs',
    '@Resources\Modules\Chronometer\EventEditorForm.cs',
    '@Resources\Modules\Chronometer\Build-EventEditor.ps1',
    '@Resources\Modules\CPU\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\ThreadColorInput.ps1',
    '@Resources\Modules\GPU\DiscoverExports.ps1.txt',
    '@Resources\Modules\GPU\AdapterInfo.cs.txt',
    '@Resources\Modules\GPU\DriverTemperature.cs.txt',
    '@Resources\Modules\IO\DriveModels.ps1.txt',
    '@Resources\Modules\RAM\MemoryInfo.ps1.txt',
    '@Resources\Modules\RAM\PageFileHost.cs.txt',
    '@Resources\Modules\Media\Queue\QueueProvider.ps1',
    '@Resources\Modules\Media\Queue\QueueCore.psm1',
    '@Resources\Modules\Media\Queue\QueueAuth.psm1',
    '@Resources\Modules\Media\Source\SourceProvider.ps1',
    '@Resources\Modules\Media\Icons\Lucide\LICENSE',
    '@Resources\Modules\RAM\Icons\Lucide\LICENSE',
    '@Resources\Modules\IO\Icons\Lucide\LICENSE',
    '@Resources\Modules\Visualizer\Icons\Lucide\LICENSE'
)) { $null = $allowedExactPaths.Add($path) }
$selected = [Collections.Generic.List[object]]::new()
foreach ($file in $sourceFiles) {
    $relative = Get-ParallaxRelativePath $file.FullName $skinRoot
    $reason = Get-ParallaxExclusionReason $relative $file.Attributes
    $allowedExact = $allowedExactPaths.Contains($relative.Replace('/', '\'))
    # A text suffix does not turn executable/helper/build source into documentation.
    # Preserve only reviewed exact paths; repeated .txt suffixes do not evade this rule.
    $compoundSource = $relative -match '(?i)\.(ps1|psm1|psd1|cs|vb|fs|py|rb|sh|exe|dll|com|scr|cpl|bat|cmd|msi|msp|hta|vbs|vbe|js|jse|wsf|wsh)(?:\.txt)+$'
    if (-not $reason -and $compoundSource -and -not $allowedExact) {
        $reason = 'Executable or build source with a text suffix requires an exact reviewed path'
    } elseif (-not $reason -and $file.Extension.ToLowerInvariant() -notin $allowedExtensions -and -not $allowedExact) {
        $reason = 'Extension not in distributable allowlist'
    } elseif ($relative -match '^@Resources[\\/]User[\\/]' -and $file.Extension -ine '.inc') {
        $reason = 'Only default INI variable includes ship from User'
    }
    if (-not $reason) {
        $ancestor = $file.Directory
        while ($null -ne $ancestor -and (Test-ParallaxChildPath $ancestor.FullName $skinRoot)) {
            if ($ancestor.Attributes -band [IO.FileAttributes]::Hidden) { $reason = 'Hidden parent directory'; break }
            $ancestor = $ancestor.Parent
        }
    }
    if ($reason) {
        $excluded.Add([pscustomobject]@{ Path = $relative; Reason = $reason })
        continue
    }
    # Report the location only, never the potential credential value.
    if ($file.Extension -in '.ini', '.inc') {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            if ($line -match '^\s*(?:[A-Za-z0-9_]*(?:AccessToken|RefreshToken|ClientSecret|ApiKey|Password|Credential)[A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') {
                $candidate = $Matches[1].Trim()
                if ($candidate -notin @('""', "''")) {
                    throw "Potential credential in ${relative}:${lineNumber}. Stage only clean, empty credential defaults."
                }
            }
        }
    }
    $selected.Add([pscustomobject]@{ File = $file; Relative = $relative })
}
if ($selected.Count -eq 0) { throw 'No distributable files selected.' }

$stageName = 'Parallax-{0}-{1}-{2}' -f $Version, [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'), [Guid]::NewGuid().ToString('N').Substring(0, 8)
$stageRoot = Join-Path $buildRoot $stageName
$stageSkinRoot = Join-Path $stageRoot 'Skins\Parallax'
if (-not (Test-ParallaxChildPath $stageRoot $buildRoot) -or -not (Test-ParallaxChildPath $stageSkinRoot $stageRoot)) { throw 'Unsafe staging destination.' }
if (Test-Path -LiteralPath $stageRoot) { throw "Refusing to reuse staging directory: $stageRoot" }
if (-not (Test-Path -LiteralPath $buildRoot)) { $null = New-Item -ItemType Directory -Path $buildRoot }
$null = New-Item -ItemType Directory -Path $stageRoot
$null = New-Item -ItemType Directory -Path $stageSkinRoot
$manifestFiles = [Collections.Generic.List[object]]::new()
foreach ($entry in $selected) {
    $destination = Join-Path $stageSkinRoot $entry.Relative
    if (-not (Test-ParallaxChildPath $destination $stageSkinRoot)) { throw 'Unsafe staged file destination.' }
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    Copy-Item -LiteralPath $entry.File.FullName -Destination $destination -ErrorAction Stop
    $manifestFiles.Add([pscustomobject]@{
        Path = ('Skins\Parallax\' + $entry.Relative)
        Bytes = (Get-Item -LiteralPath $destination).Length
        SHA256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    })
}
# Detect an include or Lua script accidentally omitted by staging rules.
# A failing stage is left in place for inspection; a later attempt always uses a new folder.
$null = & (Join-Path $PSScriptRoot 'Test-Parallax.ps1') -SkinRoot $stageSkinRoot -RequireAllModules:$RequireAllModules
$variablesFiles = @($selected | Where-Object { $_.Relative -match '^@Resources[\\/]User[\\/].+\.inc$' } | ForEach-Object { 'Parallax\' + $_.Relative } | Sort-Object)
if ($variablesFiles.Count -eq 0) { throw 'No persistent User/*.inc files selected; check the settings layout.' }
$variablesValue = $variablesFiles -join ' | '
$variablesValue | Set-Content -LiteralPath (Join-Path $stageRoot 'variables-files.txt') -Encoding UTF8
$manifest = [ordered]@{
    Name = 'Parallax'
    Version = $Version
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Status = 'Staged source only; not an rmskin package or runtime test result'
    SkinRoot = 'Skins\Parallax'
    VariablesFiles = $variablesFiles
    MergeSkins = $false
    Files = @($manifestFiles.ToArray())
    Excluded = @($excluded.ToArray())
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stageRoot 'stage-manifest.json') -Encoding UTF8
Write-Host "Staged $($selected.Count) file(s); excluded $($excluded.Count)."
Write-Host "Skin Packager source: $stageSkinRoot"
Write-Host "Variables files: $variablesValue"
Write-Host 'Review the stage manifest, then create the .rmskin with tools\Package-Parallax.ps1 (or the official Rainmeter Skin Packager).'
[pscustomobject]@{ StageRoot = $stageRoot; SkinRoot = $stageSkinRoot; Files = $selected.Count; Excluded = $excluded.Count; VariablesFiles = $variablesValue }
