#requires -Version 5.1
<#
.SYNOPSIS
Verifies the structure of a Rainmeter .rmskin package without installing it.

.DESCRIPTION
The checks mirror what Rainmeter's Skin Installer does before it accepts a package
(rainmeter/rainmeter, Library/DialogInstall.cpp, ReadPackage/ReadOptions):

  - The file ends with a 16-byte trailer: int64 archive length, one flags byte, "RMSKIN\0".
  - The trailer length equals the file length minus 16 and the flags byte is 0.
  - The remaining bytes are a ZIP archive with RMSKIN.ini in the archive root and an
    optional RMSKIN.bmp header image (400x60 Windows bitmap).
  - [rmskin] Name is present; LoadType/Load, VariableFiles, MergeSkins, MinimumRainmeter
    and MinimumWindows are consistent with the archive contents.
  - Every remaining entry is a file below Skins/<root>/ with an ASCII, forward-slash path,
    or a plugin at Plugins/32bit/<name>.dll and Plugins/64bit/<name>.dll (both required,
    each a PE image of the folder's architecture, none of Rainmeter's own plugins).

With -StageManifest, the skin entries must match the stage manifest exactly, including
SHA-256 hashes and sizes of the decompressed bytes. With -ExpectedPluginHashes, the plugin
entries must be exactly those keys with matching SHA-256 hashes. This script never launches
Rainmeter or Skin Installer, and never writes to the Rainmeter profile.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackagePath,
    [string]$StageManifest,
    [string]$ExpectedName,
    [string]$ExpectedVersion,
    [string]$ExpectedSkinRoot,
    [switch]$RequireHeaderImage,
    [hashtable]$ExpectedPluginHashes
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($assembly in 'System.IO.Compression', 'System.IO.Compression.FileSystem') {
    try { Add-Type -AssemblyName $assembly -ErrorAction Stop } catch { }
}

function Read-EntryBytes([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try {
        $memory = [IO.MemoryStream]::new()
        $stream.CopyTo($memory)
        return $memory.ToArray()
    } finally { $stream.Dispose() }
}
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() }
}
function ConvertFrom-PackageIni([byte[]]$Bytes) {
    # Rainmeter reads the options file as UTF-16LE (BOM), UTF-8 (BOM) or ANSI.
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $text = [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    } elseif ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $text = [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    } else {
        $text = [Text.Encoding]::UTF8.GetString($Bytes)
    }
    $sections = @{}
    $current = $null
    foreach ($rawLine in ($text -split "`r?`n")) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith(';')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $current = $Matches[1]
            if (-not $sections.ContainsKey($current)) { $sections[$current] = [ordered]@{} }
            continue
        }
        if ($null -eq $current) { throw 'RMSKIN.ini has an option before any section.' }
        $index = $line.IndexOf('=')
        if ($index -lt 1) { throw "RMSKIN.ini has an unreadable line: $line" }
        $sections[$current][$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim()
    }
    return $sections
}

$warnings = [Collections.Generic.List[string]]::new()
$PackagePath = (Get-Item -LiteralPath $PackagePath).FullName
if ([IO.Path]::GetExtension($PackagePath) -ine '.rmskin') { throw "Expected a .rmskin file: $PackagePath" }
$bytes = [IO.File]::ReadAllBytes($PackagePath)
if ($bytes.Length -le 16 + 22) { throw 'File is too small to be an .rmskin package.' }

# Trailer written by Skin Packager: { __int64 size; BYTE flags; char key[7]; }
$footerOffset = $bytes.Length - 16
$archiveLength = [BitConverter]::ToInt64($bytes, $footerOffset)
$flags = $bytes[$footerOffset + 8]
$key = [Text.Encoding]::ASCII.GetString($bytes, $footerOffset + 9, 7)
if ($key -ne "RMSKIN`0") { throw 'Missing RMSKIN trailer. Rainmeter would not treat this file as a skin package.' }
if ($archiveLength -ne $footerOffset) { throw "Trailer records an archive length of $archiveLength bytes but the archive is $footerOffset bytes." }
if ($flags -ne 0) { throw "Unexpected trailer flags value $flags. Parallax packages use 0, which keeps the installer's normal backup behavior." }
if ($archiveLength -gt [int]::MaxValue) { throw 'Archive is larger than this verifier supports.' }

# Standard readers must also tolerate the trailer (minizip and .NET both scan backwards for the central directory).
$wholeFile = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try { $null = $wholeFile.Entries.Count } finally { $wholeFile.Dispose() }

$archiveStream = [IO.MemoryStream]::new($bytes, 0, [int]$archiveLength, $false)
$archive = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Read, $false)
$result = $null
try {
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $rootEntries = @{}
    $skinEntries = [Collections.Generic.List[object]]::new()
    $skinRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $namesIgnoreCase = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pluginEntries = [Collections.Generic.List[object]]::new()
    foreach ($entry in @($archive.Entries)) {
        $name = $entry.FullName
        if ($name -match '[^\x20-\x7E]') { throw "Archive entry names must be printable ASCII: $name" }
        if ($name.Contains('\')) { throw "Archive entry uses backslashes; the installer expects forward slashes: $name" }
        if ($name.StartsWith('/') -or $name.EndsWith('/') -or $name.Contains('//') -or $name -match '(^|/)\.\.?(/|$)') {
            throw "Unsafe or directory archive entry: $name"
        }
        if (-not $names.Add($name)) { throw "Duplicate archive entry: $name" }
        $null = $namesIgnoreCase.Add($name)
        if (-not $name.Contains('/')) {
            if ($name -ieq 'RMSKIN.ini' -or $name -ieq 'RMSKIN.bmp') { $rootEntries[$name] = $entry; continue }
            throw "Unexpected file in the archive root: $name"
        }
        if ($name -match '^Plugins/(32bit|64bit)/([^/]+\.dll)$') {
            $pluginEntries.Add([pscustomobject]@{ Entry = $entry; Name = $name; Architecture = $Matches[1]; File = $Matches[2] })
            continue
        }
        if ($name -match '^Skins/([^/]+)/(.+)$') {
            $root = $Matches[1]
            if ($root -in 'Backup', '@Backup', '@Vault') { throw "Skin root '$root' is ignored by the installer." }
            $null = $skinRoots.Add($root)
            $skinEntries.Add([pscustomobject]@{ Entry = $entry; Name = $name; Root = $root })
            continue
        }
        throw "Unexpected package component (only Skins/<root>/ files and Plugins/<32bit|64bit>/<name>.dll are expected): $name"
    }
    if (-not $rootEntries.ContainsKey('RMSKIN.ini')) { throw 'RMSKIN.ini is missing from the archive root.' }
    if ($skinEntries.Count -eq 0) { throw 'The package contains no skin files.' }
    if ($skinRoots.Count -ne 1) { throw "Expected exactly one skin root folder; found $($skinRoots.Count)." }
    $skinRoot = @($skinRoots)[0]
    if ($ExpectedSkinRoot -and $skinRoot -ne $ExpectedSkinRoot) { throw "Skin root '$skinRoot' does not match the expected '$ExpectedSkinRoot'." }

    # Plugins: Skin Installer needs both architectures, ignores Rainmeter's own plugin names,
    # and loads whichever build matches the running Rainmeter.
    $rainmeterPlugins = 'ActionTimer.dll', 'AdvancedCPU.dll', 'AudioLevel.dll', 'CoreTemp.dll', 'FileView.dll', 'FolderInfo.dll', 'InputText.dll', 'iTunesPlugin.dll', 'MediaKey.dll', 'NowPlaying.dll', 'PerfMon.dll', 'PingPlugin.dll', 'PowerPlugin.dll', 'Process.dll', 'QuotePlugin.dll', 'RecycleManager.dll', 'ResMon.dll', 'RunCommand.dll', 'SpeedFanPlugin.dll', 'SysInfo.dll', 'UsageMonitor.dll', 'WebParser.dll', 'WifiStatus.dll', 'Win7AudioPlugin.dll', 'WindowMessagePlugin.dll'
    $pluginFiles = @($pluginEntries | ForEach-Object { $_.File } | Sort-Object -Unique)
    foreach ($pluginFile in $pluginFiles) {
        if ($pluginFile -in $rainmeterPlugins) { throw "$pluginFile ships with Rainmeter; the installer ignores it, so it must not be bundled." }
        foreach ($arch in '32bit', '64bit') {
            if (-not $namesIgnoreCase.Contains("Plugins/$arch/$pluginFile")) { throw "Plugin $pluginFile lacks its $arch build; the installer needs both architectures." }
        }
    }
    $checkPluginHashes = $PSBoundParameters.ContainsKey('ExpectedPluginHashes')
    foreach ($pluginEntry in $pluginEntries) {
        $content = Read-EntryBytes $pluginEntry.Entry
        if ($content.Length -lt 128 -or $content[0] -ne 0x4D -or $content[1] -ne 0x5A) { throw "Plugin entry is not a Windows DLL: $($pluginEntry.Name)" }
        $peOffset = [BitConverter]::ToInt32($content, 60)
        if ($peOffset -lt 64 -or $peOffset + 6 -gt $content.Length -or $content[$peOffset] -ne 0x50 -or $content[$peOffset + 1] -ne 0x45) { throw "Plugin entry is not a PE image: $($pluginEntry.Name)" }
        $machine = [BitConverter]::ToUInt16($content, $peOffset + 4)
        $expectedMachine = 0x8664
        if ($pluginEntry.Architecture -ieq '32bit') { $expectedMachine = 0x14C }
        if ($machine -ne $expectedMachine) { throw "Plugin entry architecture does not match its folder: $($pluginEntry.Name)" }
        if ($checkPluginHashes) {
            if ($null -eq $ExpectedPluginHashes -or -not $ExpectedPluginHashes.ContainsKey($pluginEntry.Name)) { throw "Unexpected plugin entry: $($pluginEntry.Name)" }
            if ((Get-BytesSha256 $content) -ne [string]$ExpectedPluginHashes[$pluginEntry.Name]) { throw "Plugin bytes differ from the expected hash: $($pluginEntry.Name)" }
        }
    }
    if ($checkPluginHashes) {
        $expectedPluginCount = 0
        if ($null -ne $ExpectedPluginHashes) { $expectedPluginCount = $ExpectedPluginHashes.Count }
        if ($expectedPluginCount -ne $pluginEntries.Count) { throw "Expected $expectedPluginCount plugin entries but found $($pluginEntries.Count)." }
    }

    $ini = ConvertFrom-PackageIni (Read-EntryBytes $rootEntries['RMSKIN.ini'])
    if (-not $ini.ContainsKey('rmskin')) { throw 'RMSKIN.ini has no [rmskin] section.' }
    $options = $ini['rmskin']
    $known = 'Name', 'Author', 'Version', 'LoadType', 'Load', 'VariableFiles', 'MergeSkins', 'MinimumRainmeter', 'MinimumWindows'
    foreach ($optionName in @($options.Keys)) {
        if ($optionName -notin $known) { $warnings.Add("Unknown [rmskin] option '$optionName' is ignored by the installer.") }
    }
    function Get-Option([string]$Key) { if ($options.Contains($Key)) { return [string]$options[$Key] } return '' }
    $packageName = Get-Option 'Name'
    if (-not $packageName) { throw 'RMSKIN.ini Name is required; the installer rejects a package without it.' }
    if ($ExpectedName -and $packageName -ne $ExpectedName) { throw "Package Name '$packageName' does not match the expected '$ExpectedName'." }
    $packageVersion = Get-Option 'Version'
    if ($ExpectedVersion -and $packageVersion -ne $ExpectedVersion) { throw "Package Version '$packageVersion' does not match the expected '$ExpectedVersion'." }
    $author = Get-Option 'Author'
    if (-not $author) { $warnings.Add('RMSKIN.ini has no Author; the installer shows an empty credit.') }
    $loadType = Get-Option 'LoadType'
    $load = Get-Option 'Load'
    if ($loadType) {
        if ($loadType -notin 'Skin', 'Layout') { throw "LoadType must be Skin or Layout, not '$loadType'." }
        if (-not $load) { throw 'LoadType is set but Load is empty.' }
        if ($loadType -eq 'Skin') {
            if ($load -notmatch '\.ini$') { throw "Load must name a skin .ini file: $load" }
            $loadEntry = 'Skins/' + $load.Replace('\', '/')
            if (-not $names.Contains($loadEntry)) { throw "Load points to a config that is not in the package: $load" }
        } elseif (-not $names.Contains('Layouts/' + $load + '/Rainmeter.ini')) {
            throw "Load names a layout that is not in the package: $load"
        }
    } elseif ($load) {
        $warnings.Add('Load is set without LoadType; the installer will not load anything after installation.')
    }
    $mergeSkins = (Get-Option 'MergeSkins') -match '^\s*[1-9]'
    $variableFiles = @()
    $variableFilesRaw = Get-Option 'VariableFiles'
    if ($variableFilesRaw) {
        if ($mergeSkins) { throw 'VariableFiles and MergeSkins are mutually exclusive.' }
        $variableFiles = @($variableFilesRaw -split '\|' | ForEach-Object { $_.Trim() })
        foreach ($variableFile in $variableFiles) {
            if (-not $variableFile) { throw 'VariableFiles contains an empty path.' }
            if ($variableFile -notmatch '^[^\\/]+\\') { throw "VariableFiles entries must start with the skin root folder: $variableFile" }
            if (-not $names.Contains('Skins/' + $variableFile.Replace('\', '/'))) { throw "VariableFiles path is not in the package: $variableFile" }
        }
    }
    foreach ($pair in @(@('MinimumRainmeter', (Get-Option 'MinimumRainmeter')), @('MinimumWindows', (Get-Option 'MinimumWindows')))) {
        if ($pair[1] -and $pair[1] -notmatch '^\d+(\.\d+){0,3}$') { throw "$($pair[0]) must be dotted numeric components: $($pair[1])" }
        if (-not $pair[1]) { $warnings.Add("$($pair[0]) is not set; the installer will not enforce a minimum.") }
    }

    $headerImage = $false
    if ($rootEntries.ContainsKey('RMSKIN.bmp')) {
        $header = Read-EntryBytes $rootEntries['RMSKIN.bmp']
        if ($header.Length -lt 54 -or $header[0] -ne 0x42 -or $header[1] -ne 0x4D) { throw 'RMSKIN.bmp is not a Windows bitmap.' }
        $width = [BitConverter]::ToInt32($header, 18)
        $height = [Math]::Abs([BitConverter]::ToInt32($header, 22))
        if ($width -ne 400 -or $height -ne 60) { throw "RMSKIN.bmp must be exactly 400x60 pixels; found ${width}x${height}." }
        $headerImage = $true
    } elseif ($RequireHeaderImage) {
        throw 'RMSKIN.bmp header image is missing.'
    }

    $manifestMatched = $null
    $uncompressedBytes = [int64]0
    if ($StageManifest) {
        $manifest = Get-Content -LiteralPath $StageManifest -Raw | ConvertFrom-Json
        $expected = @{}
        foreach ($file in @($manifest.Files)) { $expected[([string]$file.Path).Replace('\', '/')] = $file }
        if ($expected.Count -ne $skinEntries.Count) { throw "Manifest lists $($expected.Count) file(s) but the package has $($skinEntries.Count) skin file(s)." }
        foreach ($skinEntry in $skinEntries) {
            if (-not $expected.ContainsKey($skinEntry.Name)) { throw "Package entry is not in the stage manifest: $($skinEntry.Name)" }
            $file = $expected[$skinEntry.Name]
            $content = Read-EntryBytes $skinEntry.Entry
            if ($content.Length -ne [int64]$file.Bytes) { throw "Decompressed size differs from the manifest: $($skinEntry.Name)" }
            if ((Get-BytesSha256 $content) -ne [string]$file.SHA256) { throw "Decompressed bytes differ from the manifest: $($skinEntry.Name)" }
            $uncompressedBytes += $content.Length
        }
        $manifestMatched = $true
    } else {
        foreach ($skinEntry in $skinEntries) {
            $content = Read-EntryBytes $skinEntry.Entry
            $uncompressedBytes += $content.Length
        }
    }

    $result = [pscustomobject]@{
        Package = $PackagePath
        Bytes = $bytes.Length
        SHA256 = Get-BytesSha256 $bytes
        ArchiveBytes = $archiveLength
        UncompressedSkinBytes = $uncompressedBytes
        Entries = $names.Count
        SkinFiles = $skinEntries.Count
        SkinRoot = $skinRoot
        Name = $packageName
        Author = $author
        Version = $packageVersion
        LoadType = $loadType
        Load = $load
        VariableFiles = $variableFiles
        MinimumRainmeter = Get-Option 'MinimumRainmeter'
        MinimumWindows = Get-Option 'MinimumWindows'
        HeaderImage = $headerImage
        Plugins = $pluginFiles
        PluginEntries = $pluginEntries.Count
        ManifestMatched = $manifestMatched
        Warnings = @($warnings.ToArray())
    }
} finally {
    $archive.Dispose()
    $archiveStream.Dispose()
}
foreach ($warning in $warnings) { Write-Warning $warning }
Write-Host ("Package structure verified: {0} entries, {1} skin file(s) under Skins\{2}, {3} plugin file(s), {4:N0} bytes, SHA-256 {5}. Installation behavior is not tested." -f $result.Entries, $result.SkinFiles, $result.SkinRoot, $result.PluginEntries, $result.Bytes, $result.SHA256)
$result
