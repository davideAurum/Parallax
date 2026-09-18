#requires -Version 5.1
<#
.SYNOPSIS
Creates the distributable Parallax .rmskin package from a validated stage.

.DESCRIPTION
Runs Stage-Parallax.ps1 with -RequireAllModules (or reuses an existing stage), then
writes the package in the format Rainmeter's Skin Packager produces
(rainmeter/rainmeter, Library/DialogPackage.cpp and DialogInstall.cpp):

  - a deflate ZIP archive whose root holds RMSKIN.ini and the optional RMSKIN.bmp header,
  - every staged file as Skins/Parallax/... with ASCII, forward-slash entry names,
  - each bundled plugin from packaging\release.json as Plugins/32bit/<name>.dll and
    Plugins/64bit/<name>.dll after PE, architecture, version and shipped-license checks,
  - a 16-byte trailer { int64 archiveLength; byte flags = 0; "RMSKIN\0" } after the archive.

RMSKIN.ini is written as UTF-16LE with a byte-order mark, which every Skin Installer
version reads. Release metadata comes from packaging\release.json unless overridden by
parameters. The finished file is re-read and verified by Test-ParallaxPackage.ps1 against
the stage manifest before it is moved into place.

The script never installs the package, launches Rainmeter or Skin Installer, touches the
live Rainmeter profile, or publishes anything.
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..'),
    [string]$ReleaseFile,
    [string]$StageRoot,
    [string]$OutputDirectory,
    [string]$Name,
    [string]$Author,
    [string]$MinimumRainmeter,
    [string]$MinimumWindows,
    [string]$LoadSkin,
    [string]$HeaderImage,
    [switch]$NoHeaderImage,
    [switch]$NoPlugins,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($assembly in 'System.IO.Compression', 'System.IO.Compression.FileSystem') {
    try { Add-Type -AssemblyName $assembly -ErrorAction Stop } catch { }
}
Import-Module (Join-Path $PSScriptRoot 'Parallax.Build.psm1') -Force
$ProjectRoot = (Get-Item -LiteralPath $ProjectRoot).FullName
if (-not $ReleaseFile) { $ReleaseFile = Join-Path $ProjectRoot 'packaging\release.json' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot 'dist' }
$skinRootName = 'Parallax'

function Get-ReleaseValue([object]$Release, [string]$Key, [string]$Default = '') {
    if ($null -eq $Release) { return $Default }
    $property = $Release.PSObject.Properties[$Key]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return [string]$property.Value
}
function Assert-IniValue([string]$Key, [string]$Value) {
    if ($Value -match '[\x00-\x1F]') { throw "$Key must not contain control characters." }
    if ($Value -ne $Value.Trim()) { throw "$Key must not start or end with whitespace." }
}
function Get-FileSha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

# Release metadata: parameters override packaging\release.json.
$release = $null
if (Test-Path -LiteralPath $ReleaseFile -PathType Leaf) {
    $release = Get-Content -LiteralPath $ReleaseFile -Raw | ConvertFrom-Json
} elseif (-not ($Version -and $Author -and $MinimumRainmeter -and $MinimumWindows -and $LoadSkin)) {
    throw "Release metadata file not found: $ReleaseFile"
}
if (-not $Name) { $Name = Get-ReleaseValue $release 'name' $skinRootName }
if (-not $Version) { $Version = Get-ReleaseValue $release 'version' }
if (-not $Author) { $Author = Get-ReleaseValue $release 'author' }
if (-not $MinimumRainmeter) { $MinimumRainmeter = Get-ReleaseValue $release 'minimumRainmeter' }
if (-not $MinimumWindows) { $MinimumWindows = Get-ReleaseValue $release 'minimumWindows' }
if (-not $LoadSkin) { $LoadSkin = Get-ReleaseValue $release 'loadSkin' }
$loadType = Get-ReleaseValue $release 'loadType' 'Skin'
$mergeSkins = (Get-ReleaseValue $release 'mergeSkins' 'false') -ieq 'true'
if (-not $HeaderImage -and -not $NoHeaderImage) { $HeaderImage = Get-ReleaseValue $release 'headerImage' }
if ($NoHeaderImage) { $HeaderImage = '' }

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$') { throw "Name must be 1-64 letters, digits, spaces, dots, underscores or hyphens: '$Name'" }
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw "Version is required (packaging\release.json or -Version) and may use letters, digits, dots, underscores and hyphens: '$Version'" }
if ([string]::IsNullOrWhiteSpace($Author)) { throw 'Author is required. Set "author" in packaging\release.json or pass -Author.' }
Assert-IniValue 'Author' $Author
Assert-IniValue 'Name' $Name
foreach ($pair in @(@('MinimumRainmeter', $MinimumRainmeter), @('MinimumWindows', $MinimumWindows))) {
    if (-not $pair[1]) { throw "$($pair[0]) is required for a distributable package. Record the lowest tested version in packaging\release.json." }
    if ($pair[1] -notmatch '^\d+(\.\d+){0,3}$') { throw "$($pair[0]) must be dotted numeric components such as 4.5.26 or 10.0: '$($pair[1])'" }
}
if ($loadType -ine 'Skin') { throw "Only LoadType=Skin is supported by this packager; release.json loadType is '$loadType'." }
if (-not $LoadSkin) { throw 'loadSkin is required: the config Rainmeter loads after installation, for example Parallax\Settings\Settings.ini.' }
$LoadSkin = $LoadSkin.Replace('/', '\')
if ($LoadSkin -notmatch "^$skinRootName\\[^\\].*\.ini$" -or $LoadSkin -match '\\\.\.?(\\|$)' -or $LoadSkin -match '\\@Resources\\') {
    throw "loadSkin must be a $skinRootName skin config such as $skinRootName\Settings\Settings.ini: '$LoadSkin'"
}
if ($mergeSkins) { throw 'mergeSkins must stay false: Variables files preservation is incompatible with Merge skins.' }

# Stage: fresh (all modules required) or an existing stage created by Stage-Parallax.ps1.
if ($StageRoot) {
    $StageRoot = (Get-Item -LiteralPath $StageRoot).FullName
} else {
    $stage = & (Join-Path $PSScriptRoot 'Stage-Parallax.ps1') -ProjectRoot $ProjectRoot -Version $Version -RequireAllModules
    $StageRoot = $stage.StageRoot
}
$stageSkinRoot = Join-Path $StageRoot "Skins\$skinRootName"
$manifestPath = Join-Path $StageRoot 'stage-manifest.json'
$variablesPath = Join-Path $StageRoot 'variables-files.txt'
foreach ($required in $stageSkinRoot, $manifestPath, $variablesPath) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Incomplete stage, missing: $required" }
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.Name -ne $skinRootName) { throw "Stage manifest is for '$($manifest.Name)', not $skinRootName." }
if ([string]$manifest.Version -ne $Version) { throw "Stage version '$($manifest.Version)' does not match the package version '$Version'. Stage again or pass the matching -Version." }
$manifestFiles = @($manifest.Files)
if ($manifestFiles.Count -eq 0) { throw 'Stage manifest lists no files.' }
$variablesValue = (Get-Content -LiteralPath $variablesPath -Raw).Trim()
$variablesFiles = @($variablesValue -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($variablesFiles.Count -eq 0 -or $variablesFiles.Count -ne @($manifest.VariablesFiles).Count) { throw 'variables-files.txt disagrees with stage-manifest.json.' }

# The staged bytes must still be exactly what the manifest recorded, with nothing added.
$expected = @{}
foreach ($file in $manifestFiles) {
    $relative = [string]$file.Path
    if ($relative -notmatch "^Skins\\$skinRootName\\.") { throw "Manifest path is outside the skin root: $relative" }
    $full = Join-Path $StageRoot $relative
    if (-not (Test-ParallaxChildPath $full $stageSkinRoot)) { throw "Manifest path escapes the stage: $relative" }
    $item = Get-Item -LiteralPath $full -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point in stage: $relative" }
    if ($item.Length -ne [int64]$file.Bytes) { throw "Staged size changed since the manifest was written: $relative" }
    if ((Get-FileSha256 $full) -ne [string]$file.SHA256) { throw "Staged bytes changed since the manifest was written: $relative" }
    $expected[$relative] = $file
}
$stagedItems = @(Get-ChildItem -LiteralPath $stageSkinRoot -Recurse -File -Force)
foreach ($item in $stagedItems) {
    $relative = "Skins\$skinRootName\" + (Get-ParallaxRelativePath $item.FullName $stageSkinRoot)
    if (-not $expected.ContainsKey($relative)) { throw "File in the stage is not listed in its manifest: $relative" }
}
if ($stagedItems.Count -ne $manifestFiles.Count) { throw 'Stage contents and manifest disagree.' }
if (-not $expected.ContainsKey("Skins\$LoadSkin")) { throw "loadSkin is not part of the stage: $LoadSkin" }
foreach ($variableFile in $variablesFiles) {
    if ($variableFile -notmatch "^$skinRootName\\@Resources\\User\\.+\.inc$") { throw "Unexpected Variables file: $variableFile" }
    if (-not $expected.ContainsKey("Skins\$variableFile")) { throw "Variables file is not part of the stage: $variableFile" }
}

# Optional 400x60 Windows bitmap shown at the top of the Skin Installer dialog.
$headerBytes = $null
if ($HeaderImage) {
    if (-not [IO.Path]::IsPathRooted($HeaderImage)) { $HeaderImage = Join-Path $ProjectRoot $HeaderImage }
    $HeaderImage = (Get-Item -LiteralPath $HeaderImage).FullName
    if ([IO.Path]::GetExtension($HeaderImage) -ine '.bmp') { throw "Header image must be a .bmp file: $HeaderImage" }
    $headerBytes = [IO.File]::ReadAllBytes($HeaderImage)
    if ($headerBytes.Length -lt 54 -or $headerBytes[0] -ne 0x42 -or $headerBytes[1] -ne 0x4D) { throw "Header image is not a Windows bitmap: $HeaderImage" }
    $width = [BitConverter]::ToInt32($headerBytes, 18)
    $height = [Math]::Abs([BitConverter]::ToInt32($headerBytes, 22))
    if ($width -ne 400 -or $height -ne 60) { throw "Header image must be exactly 400x60 pixels; ${HeaderImage} is ${width}x${height}." }
}

# Bundled third-party plugins: both architectures, real PE images of the right machine type,
# a version resource that matches release.json, and a license that ships inside the skin.
$pluginRecords = [Collections.Generic.List[object]]::new()
$pluginHashes = @{}
$pluginNames = [Collections.Generic.List[string]]::new()
$pluginSpecs = @()
if (-not $NoPlugins -and $null -ne $release) {
    $pluginProperty = $release.PSObject.Properties['plugins']
    if ($null -ne $pluginProperty -and $null -ne $pluginProperty.Value) { $pluginSpecs = @($pluginProperty.Value) }
}
# Skin Installer ignores these names (Library/DialogInstall.cpp, IsIgnoredPlugin); they ship with Rainmeter.
$rainmeterPlugins = 'ActionTimer', 'AdvancedCPU', 'AudioLevel', 'CoreTemp', 'FileView', 'FolderInfo', 'InputText', 'iTunesPlugin', 'MediaKey', 'NowPlaying', 'PerfMon', 'PingPlugin', 'PowerPlugin', 'Process', 'QuotePlugin', 'RecycleManager', 'ResMon', 'RunCommand', 'SpeedFanPlugin', 'SysInfo', 'UsageMonitor', 'WebParser', 'WifiStatus', 'Win7AudioPlugin', 'WindowMessagePlugin'
foreach ($spec in $pluginSpecs) {
    $pluginName = Get-ReleaseValue $spec 'name'
    $pluginVersion = Get-ReleaseValue $spec 'version'
    $pluginDirectory = Get-ReleaseValue $spec 'directory'
    $pluginLicense = Get-ReleaseValue $spec 'license'
    if ($pluginName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$') { throw "Plugin names may use letters, digits, dots, underscores or hyphens: '$pluginName'" }
    if ($pluginName -in $rainmeterPlugins) { throw "$pluginName ships with Rainmeter; Skin Installer ignores bundled copies of it." }
    if ($pluginVersion -notmatch '^\d+(\.\d+){0,3}$') { throw "Plugin $pluginName needs a dotted numeric version in release metadata: '$pluginVersion'" }
    if (-not $pluginDirectory) { throw "Plugin $pluginName needs a directory containing 32bit\ and 64bit\ builds." }
    if (-not [IO.Path]::IsPathRooted($pluginDirectory)) { $pluginDirectory = Join-Path $ProjectRoot $pluginDirectory }
    $pluginDirectory = (Get-Item -LiteralPath $pluginDirectory).FullName
    if (-not $pluginLicense) { throw "Plugin $pluginName needs a license path inside the skin, relative to Skins\$skinRootName." }
    $pluginLicense = $pluginLicense.Replace('/', '\')
    if (-not $expected.ContainsKey("Skins\$skinRootName\$pluginLicense")) { throw "Plugin $pluginName license is not part of the stage: $pluginLicense" }
    if ($pluginNames -contains $pluginName) { throw "Plugin $pluginName is listed twice." }
    $pluginNames.Add($pluginName)
    foreach ($architecture in @(@('32bit', 0x14C), @('64bit', 0x8664))) {
        $arch = $architecture[0]
        $path = Join-Path $pluginDirectory "$arch\$pluginName.dll"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Plugin $pluginName is missing its $arch build: $path" }
        $item = Get-Item -LiteralPath $path -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse points are not allowed: $path" }
        $bytes = [IO.File]::ReadAllBytes($path)
        if ($bytes.Length -lt 128 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw "Not a Windows DLL (no MZ header): $path" }
        $peOffset = [BitConverter]::ToInt32($bytes, 60)
        if ($peOffset -lt 64 -or $peOffset + 6 -gt $bytes.Length -or $bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0) { throw "Not a PE image: $path" }
        $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        if ($machine -ne $architecture[1]) { throw ('{0} build of {1} has PE machine type 0x{2:X} instead of 0x{3:X}: {4}' -f $arch, $pluginName, $machine, $architecture[1], $path) }
        $fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion
        if ($fileVersion) {
            $fileVersion = $fileVersion.Trim()
            if ($fileVersion -ne $pluginVersion) { throw "Plugin $pluginName $arch reports version '$fileVersion' but release metadata says '$pluginVersion'." }
        } else {
            Write-Warning "Plugin $pluginName $arch has no readable version resource; the declared version $pluginVersion is unverified."
        }
        $entryName = "Plugins/$arch/$pluginName.dll"
        $hash = Get-FileSha256 $path
        $pluginHashes[$entryName] = $hash
        $pluginRecords.Add([ordered]@{
            Name = $pluginName; Version = $pluginVersion; Architecture = $arch; Entry = $entryName
            Source = $path; Bytes = $bytes.Length; SHA256 = $hash; FileVersion = $fileVersion; License = $pluginLicense
        })
    }
}

# RMSKIN.ini, in the order Skin Packager writes its keys.
$iniLines = @(
    '[rmskin]',
    "Name=$Name",
    "Author=$Author",
    "Version=$Version",
    'LoadType=Skin',
    "Load=$LoadSkin",
    "VariableFiles=$variablesValue",
    "MinimumRainmeter=$MinimumRainmeter",
    "MinimumWindows=$MinimumWindows"
)
$iniText = ($iniLines -join "`r`n") + "`r`n"
$iniBytes = [byte[]]([Text.Encoding]::Unicode.GetPreamble() + [Text.Encoding]::Unicode.GetBytes($iniText))
[IO.File]::WriteAllBytes((Join-Path $StageRoot 'RMSKIN.ini'), $iniBytes)

if (-not (Test-Path -LiteralPath $OutputDirectory)) { $null = New-Item -ItemType Directory -Path $OutputDirectory }
$OutputDirectory = (Get-Item -LiteralPath $OutputDirectory).FullName
$packageFileName = '{0}_{1}.rmskin' -f $Name, $Version
$packagePath = Join-Path $OutputDirectory $packageFileName
if ((Test-Path -LiteralPath $packagePath) -and -not $Force) { throw "Package already exists: $packagePath. Use -Force to replace it." }
$partialPath = Join-Path $OutputDirectory ('{0}_{1}.partial.rmskin' -f $Name, $Version)
if (Test-Path -LiteralPath $partialPath) { Remove-Item -LiteralPath $partialPath -Force }

function Add-PackageEntry([IO.Compression.ZipArchive]$Archive, [string]$EntryName, [byte[]]$Content, [DateTime]$LastWrite) {
    if ($EntryName -match '[^\x20-\x7E]' -or $EntryName.Contains('\')) { throw "Archive entry names must be ASCII with forward slashes: $EntryName" }
    $entry = $Archive.CreateEntry($EntryName, [IO.Compression.CompressionLevel]::Optimal)
    if ($LastWrite.Year -lt 1980 -or $LastWrite.Year -gt 2107) { $LastWrite = [DateTime]::new(1980, 1, 1, 0, 0, 0) }
    $entry.LastWriteTime = [DateTimeOffset]::new($LastWrite)
    $stream = $entry.Open()
    try { $stream.Write($Content, 0, $Content.Length) } finally { $stream.Dispose() }
}

$orderedFiles = @($manifestFiles | Sort-Object { [string]$_.Path })
$fileStream = [IO.File]::Open($partialPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        if ($null -ne $headerBytes) { Add-PackageEntry $archive 'RMSKIN.bmp' $headerBytes (Get-Item -LiteralPath $HeaderImage).LastWriteTime }
        Add-PackageEntry $archive 'RMSKIN.ini' $iniBytes ([DateTime]::Now)
        foreach ($record in $pluginRecords) {
            Add-PackageEntry $archive $record.Entry ([IO.File]::ReadAllBytes($record.Source)) (Get-Item -LiteralPath $record.Source).LastWriteTime
        }
        foreach ($file in $orderedFiles) {
            $full = Join-Path $StageRoot ([string]$file.Path)
            Add-PackageEntry $archive (([string]$file.Path).Replace('\', '/')) ([IO.File]::ReadAllBytes($full)) (Get-Item -LiteralPath $full).LastWriteTime
        }
    } finally { $archive.Dispose() }
    $fileStream.Flush()
    $archiveLength = [int64]$fileStream.Length
    $null = $fileStream.Seek(0, [IO.SeekOrigin]::End)
    # Trailer: { __int64 size; BYTE flags; char key[7]; } exactly as DialogPackage::CreatePackage writes it.
    $footer = New-Object byte[] 16
    [Array]::Copy([BitConverter]::GetBytes($archiveLength), 0, $footer, 0, 8)
    $footer[8] = 0
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('RMSKIN'), 0, $footer, 9, 6)
    $footer[15] = 0
    $fileStream.Write($footer, 0, $footer.Length)
} finally { $fileStream.Dispose() }

# Independent re-read of the finished bytes before the package gets its final name.
$verification = & (Join-Path $PSScriptRoot 'Test-ParallaxPackage.ps1') -PackagePath $partialPath -StageManifest $manifestPath -ExpectedName $Name -ExpectedVersion $Version -ExpectedSkinRoot $skinRootName -RequireHeaderImage:($null -ne $headerBytes) -ExpectedPluginHashes $pluginHashes
if ($verification.SkinFiles -ne $manifestFiles.Count -or -not $verification.ManifestMatched) { throw 'Package verification did not cover every staged file.' }
if ($verification.PluginEntries -ne $pluginRecords.Count) { throw 'Package verification did not cover every bundled plugin file.' }
if (Test-Path -LiteralPath $packagePath) { Remove-Item -LiteralPath $packagePath -Force }
Move-Item -LiteralPath $partialPath -Destination $packagePath
$packageHash = Get-FileSha256 $packagePath
if ($packageHash -ne $verification.SHA256) { throw 'Package bytes changed while being renamed.' }

$checksumPath = $packagePath + '.sha256'
[IO.File]::WriteAllText($checksumPath, ('{0}  {1}' -f $packageHash.ToLowerInvariant(), $packageFileName) + "`n", [Text.UTF8Encoding]::new($false))
$headerRecord = $null
if ($null -ne $headerBytes) { $headerRecord = [ordered]@{ Path = $HeaderImage; SHA256 = Get-FileSha256 $HeaderImage } }
$record = [ordered]@{
    Name = $Name
    Version = $Version
    Author = $Author
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Package = $packagePath
    Bytes = (Get-Item -LiteralPath $packagePath).Length
    SHA256 = $packageHash
    ArchiveBytes = $verification.ArchiveBytes
    Entries = $verification.Entries
    SkinFiles = $verification.SkinFiles
    UncompressedSkinBytes = $verification.UncompressedSkinBytes
    StageRoot = $StageRoot
    StageManifestSHA256 = Get-FileSha256 $manifestPath
    RmskinIni = [ordered]@{
        Name = $Name; Author = $Author; Version = $Version; LoadType = 'Skin'; Load = $LoadSkin
        VariableFiles = $variablesFiles; MinimumRainmeter = $MinimumRainmeter; MinimumWindows = $MinimumWindows
    }
    HeaderImage = $headerRecord
    Plugins = @($pluginRecords.ToArray())
    Tooling = [ordered]@{ PowerShell = $PSVersionTable.PSVersion.ToString(); Packager = 'tools\Package-Parallax.ps1' }
    Status = 'Package built and structurally verified against the stage manifest; installation, upgrade and runtime behavior are not tested by this tool.'
}
$recordPath = $packagePath + '.json'
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8

Write-Host "Package: $packagePath"
Write-Host "SHA-256: $packageHash"
Write-Host "Checksum file: $checksumPath"
Write-Host "Package record: $recordPath"
Write-Host 'Next: install this file into a clean or disposable Rainmeter profile and run the release gates in docs\PACKAGING.md.'
[pscustomobject]@{
    Package = $packagePath
    SHA256 = $packageHash
    Bytes = $record.Bytes
    Entries = $verification.Entries
    SkinFiles = $verification.SkinFiles
    StageRoot = $StageRoot
    Record = $recordPath
    Checksum = $checksumPath
    VariablesFiles = $variablesValue
    Plugins = @($pluginNames.ToArray())
}
