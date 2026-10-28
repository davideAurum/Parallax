#requires -Version 5.1
# Developer copy engine (Global Settings > Developer mode; tools\Sync-ParallaxDev.ps1).
#
# The copy is a second skin folder, <Skins>\ParallaxDev, that loads beside the
# release folder <Skins>\Parallax. This module clones the release into it,
# mirrors a source tree into it, compares the two and writes the result where
# the dev skins can read it (@Resources\Dev\Status.inc). It starts nothing, polls
# nothing and writes only below the dev folder (and its own temporary sibling).
#
# The two folders must be told apart by Rainmeter, which names a config by its
# folder path, so every hard-coded `Parallax\<config>` reference in the copy's
# .ini/.inc/.lua files is rewritten to `ParallaxDev\<config>` on the way in
# (ConvertTo-ParallaxDevRewrite). The comparison applies the same rewrite to the
# release side first, so the rewrite itself never counts as a difference.
Set-StrictMode -Version Latest

$script:Monitors = @('Chronometer', 'CPU', 'GPU', 'IO', 'Media', 'Network', 'RAM', 'Visualizer')
$script:ConfigFolders = $script:Monitors + @('Settings', 'ColorPicker', 'Welcome', 'Update', 'Idle')
$script:RewriteRegex = [regex]'(?<![A-Za-z0-9_])Parallax(?=\\{1,2}(?:Settings|ColorPicker|Welcome|Update|Idle|Chronometer|CPU|RAM|GPU|IO|Network|Media|Visualizer)(?![A-Za-z0-9_]))'
$script:RewriteExtensions = @('.ini', '.inc', '.lua')
$script:TextExtensions = @('.ini', '.inc', '.lua', '.ps1', '.psm1', '.cs', '.txt', '.md', '.json')
$script:StatusPath = '@Resources\Dev\Status.inc'
$script:DiffPath = '@Resources\Dev\Diff.txt'
$script:IdentityPath = '@Resources\User\Settings.inc'
# Files a running skin or the user changes: never compared, never overwritten by a sync.
$script:IgnoredPaths = @(
    '@Resources\Update\State.inc',
    '@Resources\Modules\Media\CaptureState.inc',
    $script:StatusPath,
    $script:DiffPath
)
# Suite-level files that only the Global Settings family reads; every other
# @Resources file is shared by the utilities and counts for all of them.
$script:SuitePaths = @(
    '@Resources\Scripts\Settings.lua',
    '@Resources\Scripts\UpdateInstall.ps1',
    '@Resources\Update\Install.inc'
)

function Get-ParallaxDevMonitors { return ,$script:Monitors }

# ---- text and bytes ---------------------------------------------------------

function Read-ParallaxDevText {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        return [pscustomobject]@{ Kind = 'utf16le'; Text = [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2) }
    }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        return [pscustomobject]@{ Kind = 'utf8bom'; Text = [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3) }
    }
    try {
        $strict = New-Object Text.UTF8Encoding($false, $true)
        return [pscustomobject]@{ Kind = 'utf8'; Text = $strict.GetString($Bytes) }
    } catch {
        return [pscustomobject]@{ Kind = 'latin1'; Text = [Text.Encoding]::GetEncoding(28591).GetString($Bytes) }
    }
}

function ConvertTo-ParallaxDevBytes {
    param([Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    switch ($Kind) {
        'utf16le' { $body = [Text.Encoding]::Unicode.GetBytes($Text); $bom = [byte[]](0xFF, 0xFE) }
        'utf8bom' { $body = (New-Object Text.UTF8Encoding($false)).GetBytes($Text); $bom = [byte[]](0xEF, 0xBB, 0xBF) }
        'latin1' { $body = [Text.Encoding]::GetEncoding(28591).GetBytes($Text); $bom = [byte[]]@() }
        default { $body = (New-Object Text.UTF8Encoding($false)).GetBytes($Text); $bom = [byte[]]@() }
    }
    $all = New-Object byte[] ($bom.Length + $body.Length)
    [Array]::Copy($bom, 0, $all, 0, $bom.Length)
    [Array]::Copy($body, 0, $all, $bom.Length, $body.Length)
    return ,$all
}

# The one place a release file's bytes become a dev file's bytes.
function ConvertTo-ParallaxDevRewrite {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes, [Parameter(Mandatory)][AllowEmptyString()][string]$Extension)
    if ($script:RewriteExtensions -notcontains $Extension.ToLowerInvariant()) { return ,$Bytes }
    $text = Read-ParallaxDevText $Bytes
    $rewritten = $script:RewriteRegex.Replace($text.Text, 'ParallaxDev')
    if ([string]::Equals($rewritten, $text.Text, [StringComparison]::Ordinal)) { return ,$Bytes }
    return ,(ConvertTo-ParallaxDevBytes $text.Kind $rewritten)
}

# Content identity for comparison: text files ignore CRLF versus LF (the live
# copy was once deployed that way) but not an encoding or BOM change; UTF-16
# and binary files compare byte for byte.
function Get-ParallaxDevHash {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes, [Parameter(Mandatory)][AllowEmptyString()][string]$Extension)
    $payload = $Bytes
    if ($script:TextExtensions -contains $Extension.ToLowerInvariant()) {
        $text = Read-ParallaxDevText $Bytes
        if ($text.Kind -ne 'utf16le') {
            $normal = $text.Text.Replace("`r`n", "`n")
            $payload = [Text.Encoding]::UTF8.GetBytes($text.Kind + ':' + $normal)
        }
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($payload)) } finally { $sha.Dispose() }
}

function Get-ParallaxDevRawHash {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)) } finally { $sha.Dispose() }
}

# ---- paths and trees --------------------------------------------------------

function Get-ParallaxDevPaths {
    param([Parameter(Mandatory)][string]$SkinsPath, [Parameter(Mandatory)][string]$Release)
    $name = $Release.Trim().TrimEnd('\', '/')
    if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._ -]{0,40}$') { throw 'BadName|The skin folder name is not usable.' }
    # Run from the copy itself: the release is the folder without the Dev suffix.
    if ($name -match '^(?<base>.+)Dev$') { $name = $Matches['base'] }
    $skins = [IO.Path]::GetFullPath($SkinsPath).TrimEnd('\', '/')
    return [pscustomobject]@{
        Skins = $skins; Name = $name; DevName = $name + 'Dev'
        Release = Join-Path $skins $name; Dev = Join-Path $skins ($name + 'Dev')
    }
}

function Assert-ParallaxDevRelease {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($needed in 'Settings\Settings.ini', '@Resources\Version.inc') {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $needed) -PathType Leaf)) { throw "NoRelease|$Root is not a Parallax skin folder." }
    }
}

function Get-ParallaxDevFiles {
    param([Parameter(Mandatory)][string]$Root)
    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    if (-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse|Expected a plain folder: $Root" }
    $prefix = $rootItem.FullName.TrimEnd('\') + '\'
    $map = @{}
    $pending = New-Object Collections.Generic.Stack[string]
    $pending.Push($rootItem.FullName)
    while ($pending.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse|Links are not followed: $($item.FullName)" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            $map[$item.FullName.Substring($prefix.Length)] = $item
        }
    }
    return $map
}

# Developer tooling (icon script, panel, helpers, Lucide shapes) changes no utility's
# behavior, so it never turns an icon red: Get-ParallaxDevArea returns $null for it and
# the comparison skips it. Unlike user and runtime files, a sync still mirrors it. The
# hook includes stay compared (Hook0 is what a release runs); Status.inc and Diff.txt
# are runtime output.
function Test-ParallaxDevTooling {
    param([Parameter(Mandatory)][string]$Relative)
    $path = $Relative.Replace('/', '\')
    return ($path -imatch '^@Resources\\Dev\\' -and $path -inotmatch '^@Resources\\Dev\\(Hook\d\.inc|Status\.inc|Diff\.txt)$')
}

# $null for ignored files; otherwise the area a difference belongs to: a utility
# name, 'Suite' (Settings, ColorPicker, Welcome, Update, Idle) or 'Shared'.
function Get-ParallaxDevArea {
    param([Parameter(Mandatory)][string]$Relative)
    $path = $Relative.Replace('/', '\')
    if ($path -imatch '^@Resources\\User\\') { return $null }
    if (Test-ParallaxDevTooling $path) { return $null }
    foreach ($ignored in $script:IgnoredPaths) { if ($path -ieq $ignored) { return $null } }
    foreach ($suite in $script:SuitePaths) { if ($path -ieq $suite) { return 'Suite' } }
    if ($path -match '^(?<top>[^\\]+)\\') {
        $top = $Matches['top']
        foreach ($monitor in $script:Monitors) { if ($top -ieq $monitor) { return $monitor } }
        foreach ($suite in 'Settings', 'ColorPicker', 'Welcome', 'Update', 'Idle') { if ($top -ieq $suite) { return 'Suite' } }
        if ($top -ieq '@Resources' -and $path -match '^@Resources\\Modules\\(?<module>[^\\]+)\\') {
            $module = $Matches['module']
            foreach ($monitor in $script:Monitors) { if ($module -ieq $monitor) { return $monitor } }
            if ($module -ieq 'ColorPicker' -or $module -ieq 'Welcome') { return 'Suite' }
        }
    }
    return 'Shared'
}

function Get-ParallaxDevVersion {
    param([Parameter(Mandatory)][string]$Root)
    $path = Join-Path $Root '@Resources\Version.inc'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $match = [regex]::Match((Read-ParallaxDevText ([IO.File]::ReadAllBytes($path))).Text, '(?m)^ParallaxVersion=([^\r\n]+)')
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    return 'unknown'
}

# ---- .inc values -------------------------------------------------------------

function Set-ParallaxDevIncValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
    $bytes = if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllBytes($Path) } else { [byte[]]@() }
    $text = Read-ParallaxDevText $bytes
    $eol = if ($text.Text.Contains("`r`n") -or $text.Text.Length -eq 0) { "`r`n" } else { "`n" }
    $line = "$Key=$Value"
    $pattern = '(?im)^[ \t]*' + [regex]::Escape($Key) + '[ \t]*=[^\r\n]*'
    if ([regex]::IsMatch($text.Text, $pattern)) {
        $new = ([regex]$pattern).Replace($text.Text, [Text.RegularExpressions.MatchEvaluator]{ param($m) $line }, 1)
    } else {
        $body = $text.Text
        if ($body.Length -gt 0 -and -not $body.EndsWith("`n")) { $body += $eol }
        if ($body -notmatch '(?im)^\[Variables\]') { $body += '[Variables]' + $eol }
        $new = $body + $line + $eol
    }
    if (-not [string]::Equals($new, $text.Text, [StringComparison]::Ordinal)) {
        [IO.File]::WriteAllBytes($Path, (ConvertTo-ParallaxDevBytes $text.Kind $new))
    }
}

function Test-ParallaxDevIdentity {
    param([Parameter(Mandatory)][string]$DevRoot)
    $path = Join-Path $DevRoot $script:IdentityPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    return [regex]::IsMatch((Read-ParallaxDevText ([IO.File]::ReadAllBytes($path))).Text, '(?im)^ParallaxDevBuild=1[ \t]*\r?$')
}

function Set-ParallaxDevIdentity {
    param([Parameter(Mandatory)][string]$DevRoot, [switch]$StopUpdateChecks)
    $path = Join-Path $DevRoot $script:IdentityPath
    $directory = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory }
    Set-ParallaxDevIncValue $path 'ParallaxDevBuild' '1'
    # The copy is the release plus edits: an update prompt from it is only noise.
    if ($StopUpdateChecks) { Set-ParallaxDevIncValue $path 'UpdateCheck' '0' }
}

# ---- write helpers -----------------------------------------------------------

function Write-ParallaxDevFile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Relative, [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes, $Stamp = $null)
    $destination = Join-Path $Root $Relative
    $full = [IO.Path]::GetFullPath($destination)
    if (-not $full.StartsWith(([IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw "Escape|Path leaves the dev copy: $Relative" }
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    [IO.File]::WriteAllBytes($full, $Bytes)
    if ($null -ne $Stamp) { [IO.File]::SetLastWriteTimeUtc($full, $Stamp) }
}

function Remove-ParallaxDevTemp {
    param([string]$Path, [string]$Skins)
    if ($Path -and (Test-Path -LiteralPath $Path) -and
        ([IO.Path]::GetFileName($Path) -match '^@ParallaxDevNew-[0-9a-f]{8}$') -and
        ([IO.Path]::GetFullPath((Split-Path -Parent $Path)) -ieq [IO.Path]::GetFullPath($Skins))) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---- clone and mirror --------------------------------------------------------

# Builds the copy beside a temporary name (an @-folder, which Rainmeter does not
# list as a skin) and moves it into place whole, so a failure leaves no
# half-copied ParallaxDev behind.
function New-ParallaxDevCopy {
    param([Parameter(Mandatory)][string]$ReleaseRoot, [Parameter(Mandatory)][string]$DevRoot)
    Assert-ParallaxDevRelease $ReleaseRoot
    if (Test-Path -LiteralPath $DevRoot) { throw "Exists|$DevRoot already exists." }
    $skins = Split-Path -Parent $DevRoot
    $temp = Join-Path $skins ('@ParallaxDevNew-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $files = Get-ParallaxDevFiles $ReleaseRoot
    try {
        $null = New-Item -ItemType Directory -Path $temp
        foreach ($relative in $files.Keys) {
            $item = $files[$relative]
            $bytes = ConvertTo-ParallaxDevRewrite ([IO.File]::ReadAllBytes($item.FullName)) $item.Extension
            Write-ParallaxDevFile $temp $relative $bytes $item.LastWriteTimeUtc
        }
        Set-ParallaxDevIdentity $temp -StopUpdateChecks
        [IO.Directory]::Move($temp, $DevRoot)
    } catch {
        Remove-ParallaxDevTemp $temp $skins
        throw
    }
    return $files.Count
}

# Mirrors SourceRoot (a Skins\Parallax-shaped tree, normally a staged one) into
# the copy. Managed files are added, replaced and removed to match; User and
# runtime files are never overwritten (a missing one is created from the source).
function Sync-ParallaxDevCopy {
    param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$DevRoot)
    Assert-ParallaxDevRelease $SourceRoot
    if (-not (Test-ParallaxDevIdentity $DevRoot)) { throw "Foreign|$DevRoot is not a Parallax developer copy." }
    $source = Get-ParallaxDevFiles $SourceRoot
    $dev = Get-ParallaxDevFiles $DevRoot
    $updated = 0; $removed = 0
    foreach ($relative in $source.Keys) {
        $area = Get-ParallaxDevArea $relative
        if ($null -eq $area -and $dev.ContainsKey($relative) -and -not (Test-ParallaxDevTooling $relative)) { continue }
        $item = $source[$relative]
        $bytes = ConvertTo-ParallaxDevRewrite ([IO.File]::ReadAllBytes($item.FullName)) $item.Extension
        if ($dev.ContainsKey($relative)) {
            $current = [IO.File]::ReadAllBytes($dev[$relative].FullName)
            if ($current.Length -eq $bytes.Length -and (Get-ParallaxDevRawHash $current) -eq (Get-ParallaxDevRawHash $bytes)) { continue }
        }
        Write-ParallaxDevFile $DevRoot $relative $bytes $item.LastWriteTimeUtc
        $updated++
    }
    foreach ($relative in @($dev.Keys)) {
        if ($source.ContainsKey($relative) -or ($null -eq (Get-ParallaxDevArea $relative) -and -not (Test-ParallaxDevTooling $relative))) { continue }
        Remove-Item -LiteralPath $dev[$relative].FullName -Force
        $removed++
    }
    # Folders the removals emptied.
    $folders = @(Get-ChildItem -LiteralPath $DevRoot -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending)
    foreach ($folder in $folders) {
        if (-not @(Get-ChildItem -LiteralPath $folder.FullName -Force)) { Remove-Item -LiteralPath $folder.FullName -Force }
    }
    return [pscustomobject]@{ Updated = $updated; Removed = $removed }
}

# ---- comparison --------------------------------------------------------------

function Compare-ParallaxDev {
    param([Parameter(Mandatory)][string]$ReleaseRoot, [Parameter(Mandatory)][string]$DevRoot)
    $release = Get-ParallaxDevFiles $ReleaseRoot
    $dev = Get-ParallaxDevFiles $DevRoot
    $changes = New-Object Collections.Generic.List[object]
    $names = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    foreach ($key in $release.Keys) { $null = $names.Add($key) }
    foreach ($key in $dev.Keys) { $null = $names.Add($key) }
    foreach ($relative in ($names | Sort-Object)) {
        $area = Get-ParallaxDevArea $relative
        if ($null -eq $area) { continue }
        if (-not $release.ContainsKey($relative)) { $kind = 'Added' }
        elseif (-not $dev.ContainsKey($relative)) { $kind = 'Removed' }
        else {
            $extension = $release[$relative].Extension
            $releaseBytes = ConvertTo-ParallaxDevRewrite ([IO.File]::ReadAllBytes($release[$relative].FullName)) $extension
            $devBytes = [IO.File]::ReadAllBytes($dev[$relative].FullName)
            if ((Get-ParallaxDevHash $releaseBytes $extension) -eq (Get-ParallaxDevHash $devBytes $extension)) { continue }
            $kind = 'Changed'
        }
        $changes.Add([pscustomobject]@{ Area = $area; Path = $relative; Kind = $kind })
    }
    return $changes.ToArray()
}

function Write-ParallaxDevStatus {
    param([Parameter(Mandatory)][string]$DevRoot, [Parameter(Mandatory)][string]$ReleaseVersion, [AllowEmptyCollection()][object[]]$Changes = @())
    $counts = @{ Shared = 0; Suite = 0 }
    foreach ($monitor in $script:Monitors) { $counts[$monitor] = 0 }
    foreach ($change in $Changes) { $counts[$change.Area]++ }
    $now = [DateTimeOffset]::UtcNow
    $eol = "`r`n"
    $status = '; Result of the last comparison between this developer copy and the release.' + $eol +
        '; Written by @Resources\Dev\DevMode.ps1 (Compare) and read by DevStatus.lua. Not a' + $eol +
        '; preference; the comparison ignores it.' + $eol + '[Variables]' + $eol +
        'DevComparedAt=' + $now.ToUnixTimeSeconds() + $eol + 'DevReleaseVersion=' + $ReleaseVersion + $eol +
        'DevDiffTotal=' + @($Changes).Count + $eol + 'DevDiffShared=' + $counts['Shared'] + $eol + 'DevDiffSuite=' + $counts['Suite'] + $eol
    foreach ($monitor in $script:Monitors) { $status += "DevDiff$monitor=" + $counts[$monitor] + $eol }
    $report = "Parallax developer copy against release $ReleaseVersion$eol" +
        "Compared " + $now.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') + $eol +
        'M changed, A only in the copy, D only in the release. Shared files count for every utility.' + $eol + $eol
    if (@($Changes).Count -eq 0) { $report += 'No differences.' + $eol }
    foreach ($group in (@($Changes) | Group-Object Area | Sort-Object Name)) {
        $report += "$($group.Name): $($group.Count)$eol"
        foreach ($change in $group.Group) { $report += '  ' + $change.Kind.Substring(0, 1).Replace('C', 'M').Replace('R', 'D') + ' ' + $change.Path + $eol }
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    Write-ParallaxDevFile $DevRoot $script:StatusPath ($utf8.GetBytes($status))
    Write-ParallaxDevFile $DevRoot $script:DiffPath ($utf8.GetBytes($report))
    return $counts
}

# ---- Rainmeter placement -----------------------------------------------------

# Active configs recorded in Rainmeter.ini: name -> 1-based position of the
# loaded .ini among the config folder's .ini files.
function Get-ParallaxDevActiveConfigs {
    param([string]$SettingsPath)
    $active = @{}
    if (-not $SettingsPath) { return $active }
    $ini = Join-Path $SettingsPath 'Rainmeter.ini'
    if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { return $active }
    $section = $null
    foreach ($line in ((Read-ParallaxDevText ([IO.File]::ReadAllBytes($ini))).Text -split "`r?`n")) {
        if ($line -match '^\[(?<name>[^\]]+)\]\s*$') { $section = $Matches['name']; continue }
        if ($section -and $line -match '^Active=(?<value>\d+)\s*$' -and [int]$Matches['value'] -gt 0) { $active[$section] = [int]$Matches['value'] }
    }
    return $active
}

function Get-ParallaxDevConfigFile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Config, [Parameter(Mandatory)][int]$Position)
    $folder = Join-Path $Root $Config
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return $null }
    $files = @(Get-ChildItem -LiteralPath $folder -Filter '*.ini' -File | Sort-Object Name)
    if ($Position -lt 1 -or $Position -gt $files.Count) { return $null }
    return $files[$Position - 1].Name
}

# Pure geometry. $Windows: the release windows to sit beside {Name, Left, Top,
# Right, Bottom}; $Obstacles: every window already on screen (the release windows
# included); $WorkAreas: {Left, Top, Right, Bottom}. Each copy window goes beside
# its release window (right, left, below, above, in that order) at the first spot
# that is inside a work area and overlaps no obstacle or earlier copy.
function Get-ParallaxDevPlacements {
    param([object[]]$Windows, [object[]]$Obstacles = $null, [object[]]$WorkAreas)
    if ($null -eq $Obstacles) { $Obstacles = $Windows }
    $placed = New-Object Collections.Generic.List[object]
    $result = @{}
    function Test-Overlap($a, $b) { return ($a.Left -lt $b.Right -and $a.Right -gt $b.Left -and $a.Top -lt $b.Bottom -and $a.Bottom -gt $b.Top) }
    foreach ($window in $Windows) {
        $width = $window.Right - $window.Left; $height = $window.Bottom - $window.Top
        $candidates = @(
            @($window.Right, $window.Top), @(($window.Left - $width), $window.Top),
            @($window.Left, $window.Bottom), @($window.Left, ($window.Top - $height))
        )
        foreach ($candidate in $candidates) {
            $rect = [pscustomobject]@{ Left = $candidate[0]; Top = $candidate[1]; Right = $candidate[0] + $width; Bottom = $candidate[1] + $height }
            $inside = $false
            foreach ($area in $WorkAreas) { if ($rect.Left -ge $area.Left -and $rect.Top -ge $area.Top -and $rect.Right -le $area.Right -and $rect.Bottom -le $area.Bottom) { $inside = $true; break } }
            if (-not $inside) { continue }
            $clash = $false
            foreach ($other in $Obstacles) { if (Test-Overlap $rect $other) { $clash = $true; break } }
            if (-not $clash) { foreach ($other in $placed) { if (Test-Overlap $rect $other) { $clash = $true; break } } }
            if ($clash) { continue }
            $placed.Add($rect)
            $result[$window.Name] = @($rect.Left, $rect.Top)
            break
        }
    }
    return $result
}

function Get-ParallaxDevLiveWindows {
    if (-not ('ParallaxDevNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxDevNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    public static string[] Find() {
        var found = new List<string>();
        EnumWindows((hwnd, unused) => {
            var cls = new StringBuilder(64); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow" || !IsWindowVisible(hwnd)) return true;
            var title = new StringBuilder(512); GetWindowText(hwnd, title, title.Capacity);
            RECT r; if (!GetWindowRect(hwnd, out r)) return true;
            found.Add(title.ToString() + "|" + r.Left + "|" + r.Top + "|" + r.Right + "|" + r.Bottom);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@
    }
    $windows = New-Object Collections.Generic.List[object]
    foreach ($entry in [ParallaxDevNative]::Find()) {
        $part = $entry.Split('|')
        if ($part.Count -ne 5) { continue }
        $windows.Add([pscustomobject]@{ Title = $part[0]; Left = [int]$part[1]; Top = [int]$part[2]; Right = [int]$part[3]; Bottom = [int]$part[4] })
    }
    return $windows.ToArray()
}

function Get-ParallaxDevWorkAreas {
    Add-Type -AssemblyName System.Windows.Forms
    return @([Windows.Forms.Screen]::AllScreens | ForEach-Object {
        $area = $_.WorkingArea
        [pscustomobject]@{ Left = $area.Left; Top = $area.Top; Right = $area.Right; Bottom = $area.Bottom }
    })
}

# ---- actions -----------------------------------------------------------------

# Returns protocol lines for the caller to print:
#   RESULT|OK|<action>|<changed files>|<utilities that differ>   or   RESULT|ERR|<code>|<message>
#   CONFIG|<config>|<ini file>|<x or ->|<y or ->     (Enable and Reset: configs to load beside the release;
#                                                    Disable, Compare and Sync: the copy's loaded configs)
function Invoke-ParallaxDev {
    param(
        [Parameter(Mandatory)][ValidateSet('Enable', 'Disable', 'Compare', 'Sync', 'Reset')][string]$Action,
        [Parameter(Mandatory)][string]$SkinsPath,
        [string]$Release = 'Parallax',
        [string]$SourceRoot,
        [string]$SettingsPath,
        [switch]$NoPlace
    )
    $lines = New-Object Collections.Generic.List[string]
    try {
        $paths = Get-ParallaxDevPaths $SkinsPath $Release
        Assert-ParallaxDevRelease $paths.Release
        $detail = ''
        if ($Action -in 'Enable', 'Sync', 'Reset') {
            if ($Action -eq 'Reset' -and (Test-Path -LiteralPath $paths.Dev)) {
                if (-not (Test-ParallaxDevIdentity $paths.Dev)) { throw "Foreign|$($paths.Dev) is not a Parallax developer copy." }
                $backup = Join-Path $paths.Skins ('@' + $paths.DevName + '-backup-' + (Get-Date -Format 'yyyyMMddTHHmmss'))
                [IO.Directory]::Move($paths.Dev, $backup)
                $detail = 'backup ' + [IO.Path]::GetFileName($backup)
            }
            if (-not (Test-Path -LiteralPath $paths.Dev)) {
                $count = New-ParallaxDevCopy $paths.Release $paths.Dev
                $detail = (@($detail, "cloned $count files") | Where-Object { $_ }) -join '; '
            } elseif (-not (Test-ParallaxDevIdentity $paths.Dev)) {
                throw "Foreign|$($paths.Dev) exists but is not a Parallax developer copy."
            }
            if ($Action -eq 'Sync') {
                if (-not $SourceRoot) { throw 'NoSource|Sync needs a source tree.' }
                $sync = Sync-ParallaxDevCopy $SourceRoot $paths.Dev
                $detail = "updated $($sync.Updated), removed $($sync.Removed)"
            }
        } elseif (-not (Test-Path -LiteralPath $paths.Dev -PathType Container)) {
            throw 'NoCopy|There is no developer copy yet.'
        } elseif (-not (Test-ParallaxDevIdentity $paths.Dev)) {
            throw "Foreign|$($paths.Dev) is not a Parallax developer copy."
        }

        $changes = @(Compare-ParallaxDev $paths.Release $paths.Dev)
        $counts = Write-ParallaxDevStatus $paths.Dev (Get-ParallaxDevVersion $paths.Release) $changes
        $differing = @($script:Monitors | Where-Object { $counts[$_] -gt 0 -or $counts['Shared'] -gt 0 }).Count

        # Enable and Reset list the release's loaded utilities to load the copy beside; the other
        # actions list the copy's own loaded configs (to unload, or to tell to re-read the status).
        if ($true) {
            $active = Get-ParallaxDevActiveConfigs $SettingsPath
            $wanted = New-Object Collections.Generic.List[object]
            foreach ($monitor in $script:Monitors) {
                $releaseConfig = "$($paths.Name)\$monitor"; $devConfig = "$($paths.DevName)\$monitor"
                if ($Action -in 'Disable', 'Compare', 'Sync') {
                    if ($active.ContainsKey($devConfig)) {
                        $loadedFile = Get-ParallaxDevConfigFile $paths.Dev $monitor $active[$devConfig]
                        if (-not $loadedFile) { $loadedFile = "$monitor.ini" }
                        $wanted.Add([pscustomobject]@{ Config = $devConfig; File = $loadedFile })
                    }
                } elseif ($active.ContainsKey($releaseConfig) -and -not $active.ContainsKey($devConfig)) {
                    $file = Get-ParallaxDevConfigFile $paths.Dev $monitor $active[$releaseConfig]
                    if ($file) { $wanted.Add([pscustomobject]@{ Config = $devConfig; File = $file; ReleaseConfig = $releaseConfig }) }
                }
            }
            $places = @{}
            if (($Action -in 'Enable', 'Reset') -and -not $NoPlace -and $wanted.Count -gt 0) {
                try {
                    # Every Rainmeter window is an obstacle; the release windows are also the anchors.
                    $live = @(Get-ParallaxDevLiveWindows)
                    $subjects = @()
                    foreach ($entry in $wanted) {
                        # A Rainmeter window's title is its skin file's full path, ...\Skins\Parallax\CPU\CPU.ini.
                        $anchor = $live | Where-Object { $_.Title -like ('*\' + $entry.ReleaseConfig + '\' + $entry.File) } | Select-Object -First 1
                        if ($anchor) { $subjects += [pscustomobject]@{ Name = $entry.Config; Left = $anchor.Left; Top = $anchor.Top; Right = $anchor.Right; Bottom = $anchor.Bottom } }
                    }
                    $places = Get-ParallaxDevPlacements -Windows $subjects -Obstacles $live -WorkAreas (Get-ParallaxDevWorkAreas)
                } catch { $places = @{} }
            }
            foreach ($entry in $wanted) {
                $x = '-'; $y = '-'
                if ($places.ContainsKey($entry.Config)) { $x = [string]$places[$entry.Config][0]; $y = [string]$places[$entry.Config][1] }
                $lines.Add("CONFIG|$($entry.Config)|$($entry.File)|$x|$y")
            }
        }
        $lines.Insert(0, "RESULT|OK|$Action|$(@($changes).Count)|$differing|$detail")
    } catch {
        $message = $_.Exception.Message
        $code = 'Failed'
        if ($message -match '^(?<code>[A-Za-z]+)\|(?<text>.*)$') { $code = $Matches['code']; $message = $Matches['text'] }
        $lines.Clear()
        $lines.Add("RESULT|ERR|$code|" + ($message -replace '[\r\n|]+', ' '))
    }
    return $lines.ToArray()
}

Export-ModuleMember -Function Get-ParallaxDevMonitors, Read-ParallaxDevText, ConvertTo-ParallaxDevBytes, ConvertTo-ParallaxDevRewrite,
    Get-ParallaxDevHash, Get-ParallaxDevPaths, Get-ParallaxDevFiles, Get-ParallaxDevArea, Test-ParallaxDevTooling, Get-ParallaxDevVersion,
    Set-ParallaxDevIncValue, Test-ParallaxDevIdentity, Set-ParallaxDevIdentity, New-ParallaxDevCopy, Sync-ParallaxDevCopy,
    Compare-ParallaxDev, Write-ParallaxDevStatus, Get-ParallaxDevActiveConfigs, Get-ParallaxDevConfigFile,
    Get-ParallaxDevPlacements, Get-ParallaxDevLiveWindows, Get-ParallaxDevWorkAreas, Invoke-ParallaxDev
