#requires -Version 5.1
#requires -PSEdition Desktop
# YouTube on the TV: the disk side of Media's optional TV queue. Windows
# PowerShell 5.1 / built-in .NET only. Importing reads and writes nothing.
#
# Everything lives in %LOCALAPPDATA%\Parallax\Media\YouTube, a folder only the
# current Windows user can open. The pairing (the TV's screen id and token,
# which can control the TV) is sealed with DPAPI for this Windows account and
# never written anywhere else. Logs and snapshots never hold ids or tokens.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$script:Utf8 = [Text.UTF8Encoding]::new($false, $true)
$script:PairingEntropy = [Text.Encoding]::ASCII.GetBytes('Parallax.Media.YouTube.Pairing.v1')
$script:RuntimeFiles = @('pairing.dpapi', 'tv.snapshot', 'tv.request', 'stop.request', 'enabled.intent', 'launch.id', 'events.log', 'events.old.log', 'tv.cover1.jpg', 'tv.cover2.jpg',
    # Which code a running worker was started from, and the code a Resume last
    # restarted a worker for (so an update restarts it once, never in a loop).
    'worker.stamp', 'upgrade.marker',
    # Casts (opt-in): the switch, the cast key sealed with DPAPI, and the state
    # Connections shows. Forget removes all three.
    'cast.intent', 'cast.dpapi', 'cast.status')
# The current video's thumbnail: two slots, written alternately, so a reader
# never sees a half-written picture and Rainmeter never shows a cached old one.
$script:CoverFiles = @('tv.cover1.jpg', 'tv.cover2.jpg')
$script:CoverLimit = 262144
$script:States = @('not_paired', 'connecting', 'ready', 'no_screen', 'offline', 'pair_again', 'error', 'stopped')
$script:PlayNames = @('unknown', 'idle', 'ended', 'playing', 'paused', 'loading', 'cued', 'ad')
$script:UpNextNames = @('known', 'unknown', 'end', 'none')
# Whether the TV names its list. Its id does not tell a Mix from a playlist.
$script:ListKinds = @('list', 'none')
# A request's outcome, shown once with the next snapshot.
$script:Notices = @('', 'sent', 'failed', 'queue_changed', 'not_connected')
$script:RequestKinds = @('refresh', 'pause', 'play', 'next', 'jump')
$script:RowLimit = 20
$script:LogLimit = 262144

function Get-TvUnixTime { return [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalSeconds) }

function Get-TvDataRoot {
    # Only names the standard folder; creates and reads nothing.
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Parallax\Media\YouTube'
}

# ------------------------------------------------------------------ private folder

function Resolve-TvPrivatePath {
    # A full local path that is not a profile root, not inside a skin folder,
    # and has no link (junction or symbolic link) anywhere along it.
    param([Parameter(Mandatory)][string]$DataRoot)
    if ($DataRoot -cnotmatch '\A[A-Za-z]:[\\/]' -or $DataRoot -match '[\x00-\x1f]' -or $DataRoot.Substring(2).Contains(':')) { throw 'TV storage path is not usable.' }
    $full = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
    if ($full.Length -lt 6 -or $full -match '(?i)[\\/]Skins(?:[\\/]|$)') { throw 'TV storage path is not usable.' }
    foreach ($special in @('UserProfile', 'LocalApplicationData', 'ApplicationData', 'MyDocuments', 'Desktop')) {
        $protected = [Environment]::GetFolderPath($special).TrimEnd('\')
        if ($protected -and [string]::Equals($full, $protected, [StringComparison]::OrdinalIgnoreCase)) { throw 'TV storage path is not usable.' }
    }
    $cursor = $full
    while ($cursor) {
        $attributes = $null
        try { $attributes = [IO.File]::GetAttributes($cursor) } catch [IO.FileNotFoundException] {} catch [IO.DirectoryNotFoundException] {}
        if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'TV storage path is not usable.' }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if ([IO.File]::Exists($full)) { throw 'TV storage path is not usable.' }
    return $full
}

function New-TvFolderSecurity {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', $inherit, 'None', 'Allow'))
    return $acl
}

function Test-TvFolderPrivate {
    param([Parameter(Mandatory)][string]$Path)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $acl = [IO.Directory]::GetAccessControl($Path)
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne $sid -or -not $acl.AreAccessRulesProtected) { return $false }
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($rules.Count -lt 1) { return $false }
    foreach ($rule in $rules) { if ($rule.IdentityReference.Value -cne $sid -or $rule.AccessControlType -ne 'Allow') { return $false } }
    return $true
}

function Initialize-TvPrivateDirectory {
    # Creates the folder for this Windows user only, or makes an existing one
    # owner-only. Called only by an explicit Pair, Start or a running worker.
    param([Parameter(Mandatory)][string]$DataRoot)
    $root = Resolve-TvPrivatePath $DataRoot
    if ([IO.Directory]::Exists($root)) {
        $owner = [IO.Directory]::GetAccessControl($root).GetOwner([Security.Principal.SecurityIdentifier]).Value
        if ($owner -cne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'TV storage belongs to another account.' }
        if (-not (Test-TvFolderPrivate $root)) { [IO.Directory]::SetAccessControl($root, (New-TvFolderSecurity)) }
    } else {
        $null = [IO.Directory]::CreateDirectory($root, (New-TvFolderSecurity))
    }
    $null = Resolve-TvPrivatePath $root
    if (-not (Test-TvFolderPrivate $root)) { throw 'TV storage could not be made private.' }
    return $root
}

function Get-TvRuntimePath {
    # One of this helper's own files, refused when it is a folder or a link.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name)
    if ($Name -cnotin $script:RuntimeFiles) { throw 'Unknown TV runtime file.' }
    $path = Join-Path ([IO.Path]::GetFullPath($Root)) $Name
    if ([IO.Directory]::Exists($path)) { throw 'TV runtime file is not a regular file.' }
    if ([IO.File]::Exists($path) -and ([IO.File]::GetAttributes($path) -band [IO.FileAttributes]::ReparsePoint)) { throw 'TV runtime file is not a regular file.' }
    return $path
}

function Write-TvFile {
    # Whole-file replace: a reader sees the old file or the new one, never half.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][byte[]]$Bytes)
    $path = Get-TvRuntimePath $Root $Name
    $temporary = Join-Path ([IO.Path]::GetFullPath($Root)) ('.tv-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $stream = $null
    try {
        $stream = [IO.FileStream]::new($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        $null = Get-TvRuntimePath $Root $Name
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temporary, $path, [Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $path) }
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Remove-TvFile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name)
    $path = Get-TvRuntimePath $Root $Name
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path); return $true }
    return $false
}

# ------------------------------------------------------------------ pairing

function New-TvPairing {
    param([Parameter(Mandatory)][string]$ScreenId, [Parameter(Mandatory)][string]$LoungeToken, [AllowEmptyString()][string]$Name = '')
    return [pscustomobject]@{
        Name        = $Name
        PairedAt    = (Get-TvUnixTime)
        # A fresh id per pairing, so the TV sees this PC as one remote.
        DeviceId    = [Guid]::NewGuid().ToString()
        ScreenId    = $ScreenId
        LoungeToken = $LoungeToken
    }
}

function Save-TvPairing {
    # The whole record, name included, is one DPAPI blob for this Windows user.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object]$Pairing)
    $record = [ordered]@{ v = 1; name = [string]$Pairing.Name; pairedAt = [long]$Pairing.PairedAt; deviceId = [string]$Pairing.DeviceId; screenId = [string]$Pairing.ScreenId; loungeToken = [string]$Pairing.LoungeToken }
    Add-Type -AssemblyName System.Web.Extensions
    $json = [Web.Script.Serialization.JavaScriptSerializer]::new().Serialize($record)
    $plain = $script:Utf8.GetBytes($json)
    try {
        $sealed = [Security.Cryptography.ProtectedData]::Protect($plain, $script:PairingEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    } finally { [Array]::Clear($plain, 0, $plain.Length) }
    Write-TvFile $Root 'pairing.dpapi' $sealed
}

function Read-TvPairing {
    # The pairing, or $null when there is none or it cannot be opened (another
    # account's, damaged, or of an unknown shape). Never throws for those.
    param([Parameter(Mandatory)][string]$Root)
    try {
        $path = Get-TvRuntimePath $Root 'pairing.dpapi'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 32768) { return $null }
        $plain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($path), $script:PairingEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        try { $json = $script:Utf8.GetString($plain) } finally { [Array]::Clear($plain, 0, $plain.Length) }
        Add-Type -AssemblyName System.Web.Extensions
        $parser = [Web.Script.Serialization.JavaScriptSerializer]::new()
        $parser.RecursionLimit = 4
        $record = $parser.DeserializeObject($json)
        if ($record -isnot [Collections.IDictionary] -or $record['v'] -ne 1) { return $null }
        foreach ($key in @('name', 'deviceId', 'screenId', 'loungeToken')) { if ($record[$key] -isnot [string]) { return $null } }
        if ($record['screenId'].Length -lt 1 -or $record['screenId'].Length -gt 512 -or $record['loungeToken'].Length -lt 1 -or $record['loungeToken'].Length -gt 4096) { return $null }
        $device = [Guid]::Empty
        if (-not [Guid]::TryParse($record['deviceId'], [ref]$device)) { return $null }
        return [pscustomobject]@{ Name = $record['name']; PairedAt = [long]$record['pairedAt']; DeviceId = $record['deviceId']; ScreenId = $record['screenId']; LoungeToken = $record['loungeToken'] }
    } catch { return $null }
}

function Test-TvPaired {
    # Whether a pairing file exists, without opening it.
    param([Parameter(Mandatory)][string]$Root)
    try { return [IO.File]::Exists((Get-TvRuntimePath $Root 'pairing.dpapi')) } catch { return $false }
}

# ------------------------------------------------------------------ snapshot
# PARALLAX_TV_V1, inert ASCII lines for Media's reader. Text is UTF-8 as hex.
# It never holds a video, list or screen id, a token or an address: a row is
# named by its place and the snapshot's observed time, and the worker maps
# that back to the video it showed.

function ConvertTo-TvHex {
    param([AllowEmptyString()][string]$Text)
    if (-not $Text) { return '' }
    return [BitConverter]::ToString($script:Utf8.GetBytes($Text)).Replace('-', '')
}

function New-TvSnapshot {
    param(
        [Parameter(Mandatory)][string]$State,
        [long]$Observed = 0, [long]$ValidUntil = 0, [long]$RetryAt = 0,
        [string]$Play = '', [long]$PositionMs = 0, [long]$PositionAtMs = 0, [long]$DurationMs = 0,
        [string]$UpNext = '', [string]$List = '', [int]$Total = 0,
        [AllowEmptyString()][string]$Notice = '', [AllowEmptyString()][string]$CurrentTitle = '', [string[]]$Titles = @(),
        [AllowEmptyString()][string]$CurrentChannel = '', [int]$Cover = 0,
        # What a ready snapshot shows: the TV's own app, or a cast followed on the TV.
        [ValidateSet('tv', 'cast')][string]$Source = 'tv'
    )
    return [pscustomobject]@{ State = $State; Observed = $Observed; ValidUntil = $ValidUntil; RetryAt = $RetryAt; Play = $Play; PositionMs = $PositionMs
        PositionAtMs = $PositionAtMs; DurationMs = $DurationMs; UpNext = $UpNext; List = $List; Total = $Total; Notice = $Notice; CurrentTitle = $CurrentTitle; Titles = [string[]]@($Titles)
        CurrentChannel = $CurrentChannel; Cover = $Cover; Source = $Source }
}

function ConvertTo-TvSnapshotText {
    param([Parameter(Mandatory)][object]$Snapshot)
    $s = $Snapshot
    if ($s.State -cnotin $script:States -or $s.Notice -cnotin $script:Notices) { throw 'Invalid TV snapshot state.' }
    foreach ($value in @($s.Observed, $s.ValidUntil, $s.RetryAt, $s.PositionMs, $s.PositionAtMs, $s.DurationMs)) {
        if ($value -lt 0 -or $value -gt 253402300000000) { throw 'Invalid TV snapshot number.' }
    }
    if ($s.Cover -lt 0 -or $s.Cover -gt $script:CoverFiles.Count) { throw 'Invalid TV snapshot cover.' }
    $ready = $s.State -ceq 'ready'
    if ($ready) {
        if ($s.Observed -lt 1 -or $s.ValidUntil -le $s.Observed -or $s.Play -cnotin $script:PlayNames -or $s.UpNext -cnotin $script:UpNextNames -or $s.List -cnotin $script:ListKinds) { throw 'Invalid ready TV snapshot.' }
        if ($s.Titles.Count -gt $script:RowLimit -or $s.Total -lt $s.Titles.Count -or ($s.UpNext -cne 'known' -and $s.Titles.Count -ne 0)) { throw 'Invalid TV snapshot rows.' }
    } else {
        # Outside 'ready' nothing about what plays is kept.
        if ($s.Observed -ne 0 -or $s.Play -or $s.UpNext -or $s.List -or $s.Total -ne 0 -or $s.Titles.Count -ne 0 -or $s.CurrentTitle -or $s.CurrentChannel -or $s.Cover -ne 0 -or $s.PositionMs -ne 0 -or $s.DurationMs -ne 0 -or $s.Notice -cin @('sent', 'queue_changed')) { throw 'Nonready TV snapshot holds live data.' }
    }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('PARALLAX_TV_V1')
    $lines.Add('state=' + $s.State)
    $lines.Add('observed=' + $s.Observed)
    $lines.Add('valid_until=' + $s.ValidUntil)
    $lines.Add('retry_at=' + $s.RetryAt)
    $lines.Add('play=' + $s.Play)
    $lines.Add('position_ms=' + $s.PositionMs)
    $lines.Add('position_at_ms=' + $s.PositionAtMs)
    $lines.Add('duration_ms=' + $s.DurationMs)
    $lines.Add('upnext=' + $s.UpNext)
    $lines.Add('list=' + $s.List)
    $lines.Add('total=' + $s.Total)
    $lines.Add('count=' + $s.Titles.Count)
    $lines.Add('notice=' + $s.Notice)
    $lines.Add('current_title=' + (ConvertTo-TvHex $s.CurrentTitle))
    # Added for Media's player card (stage 3). A reader also takes a snapshot
    # without these two lines, from a worker started before an update.
    $lines.Add('current_channel=' + (ConvertTo-TvHex $s.CurrentChannel))
    # The slot of the current video's thumbnail (tv.cover<n>.jpg), or empty.
    $lines.Add('cover=' + $(if ($s.Cover -gt 0) { [string]$s.Cover } else { '' }))
    # Added for casts (stage 3, tv-cast-link): tv or cast while ready, else empty.
    # A cast has no up next. A reader also takes a snapshot without this line.
    $lines.Add('source=' + $(if ($ready) { $s.Source } else { '' }))
    # An empty title means not known (yet): the reader shows a placeholder.
    for ($index = 0; $index -lt $s.Titles.Count; $index++) { $lines.Add('title' + ($index + 1) + '=' + (ConvertTo-TvHex $s.Titles[$index])) }
    $text = ($lines -join "`n") + "`n"
    if ($text.Length -gt 65536) { throw 'TV snapshot is too large.' }
    return $text
}

function Publish-TvSnapshot {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object]$Snapshot)
    Write-TvFile $Root 'tv.snapshot' ([Text.Encoding]::ASCII.GetBytes((ConvertTo-TvSnapshotText $Snapshot)))
}

function Read-TvSnapshotFields {
    # The snapshot's lines as a dictionary (for status display and tests), or
    # $null when absent or not a V1 snapshot.
    param([Parameter(Mandatory)][string]$Root)
    $path = Get-TvRuntimePath $Root 'tv.snapshot'
    if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 65536) { return $null }
    $lines = [IO.File]::ReadAllText($path, [Text.Encoding]::ASCII).Split([char]10)
    if ($lines[0] -cne 'PARALLAX_TV_V1') { return $null }
    $fields = [ordered]@{}
    foreach ($line in $lines | Select-Object -Skip 1) {
        if ($line -cmatch '\A([a-z_0-9]+)=(.*)\z') { $fields[$Matches[1]] = $Matches[2] }
    }
    return $fields
}

# ------------------------------------------------------------------ thumbnail
# Only the current video's picture, in one of two fixed files; nothing else
# about what played is kept. Forget and Stop remove both.

function Test-TvJpeg {
    # A JPEG of a sensible size: starts FF D8 FF and ends FF D9.
    param([AllowNull()][byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -lt 128 -or $Bytes.Length -gt $script:CoverLimit) { return $false }
    return ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8 -and $Bytes[2] -eq 0xFF -and $Bytes[$Bytes.Length - 2] -eq 0xFF -and $Bytes[$Bytes.Length - 1] -eq 0xD9)
}

function Save-TvCover {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateRange(1, 2)][int]$Slot, [Parameter(Mandatory)][byte[]]$Bytes)
    if (-not (Test-TvJpeg $Bytes)) { throw 'Not a usable thumbnail.' }
    Write-TvFile $Root $script:CoverFiles[$Slot - 1] $Bytes
}

function Remove-TvCovers {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($name in $script:CoverFiles) { try { $null = Remove-TvFile $Root $name } catch {} }
}

# ------------------------------------------------------------------ requests
# A short-lived control process (a row click, or the live-gate script) hands
# one request to the running worker through tv.request. It holds a fixed word,
# a row number and times: no ids. A newer request replaces an unread one.

function Write-TvRequest {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Kind, [int]$Row = 0, [long]$Observed = 0, [long]$Now = (Get-TvUnixTime))
    if ($Kind -cnotin $script:RequestKinds) { throw 'Unknown TV request.' }
    if ($Kind -ceq 'jump') { if ($Row -lt 1 -or $Row -gt $script:RowLimit -or $Observed -lt 1) { throw 'A jump names a row and the snapshot it was shown in.' } }
    else { $Row = 0; $Observed = 0 }
    Write-TvFile $Root 'tv.request' ([Text.Encoding]::ASCII.GetBytes("PARALLAX_TV_REQUEST_V1|$Kind|$Row|$Observed|$Now`n"))
}

function Read-TvRequest {
    # Consumes the pending request. Malformed ones, and ones older than 15
    # seconds (from before this worker), are dropped unread. A file still held
    # open by its writer waits for the next pass.
    param([Parameter(Mandatory)][string]$Root, [long]$Now = (Get-TvUnixTime))
    $path = Get-TvRuntimePath $Root 'tv.request'
    if (-not [IO.File]::Exists($path)) { return $null }
    $text = ''
    try {
        if ([IO.FileInfo]::new($path).Length -le 128) { $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) }
        [IO.File]::Delete($path)
    } catch [IO.IOException] { return $null } catch [UnauthorizedAccessException] { return $null }
    if ($text -cnotmatch '\APARALLAX_TV_REQUEST_V1\|(refresh|pause|play|next|jump)\|([0-9]{1,2})\|([0-9]{1,12})\|([0-9]{1,12})\n\z') { return $null }
    $request = [pscustomobject]@{ Kind = $Matches[1]; Row = [int]$Matches[2]; Observed = [long]$Matches[3]; Created = [long]$Matches[4] }
    if ($request.Created -gt $Now + 5 -or $request.Created -lt $Now - 15) { return $null }
    if ($request.Kind -ceq 'jump' -and ($request.Row -lt 1 -or $request.Row -gt $script:RowLimit -or $request.Observed -lt 1)) { return $null }
    if ($request.Kind -cne 'jump' -and ($request.Row -ne 0 -or $request.Observed -ne 0)) { return $null }
    return $request
}

# ------------------------------------------------------------------ control files

function Set-TvIntent {
    # Whether skin load may resume the worker: set by Start or Pair, cleared by
    # Stop and Forget.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][bool]$Enabled)
    Write-TvFile $Root 'enabled.intent' ([Text.Encoding]::ASCII.GetBytes('PARALLAX_TV_INTENT_V1|' + [int]$Enabled + "`n"))
}

function Test-TvIntent {
    param([Parameter(Mandatory)][string]$Root)
    try {
        $path = Get-TvRuntimePath $Root 'enabled.intent'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 64) { return $false }
        return ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) -ceq "PARALLAX_TV_INTENT_V1|1`n")
    } catch { return $false }
}

function Request-TvStop { param([Parameter(Mandatory)][string]$Root); Write-TvFile $Root 'stop.request' ([Text.Encoding]::ASCII.GetBytes("stop`n")) }
function Test-TvStop { param([Parameter(Mandatory)][string]$Root); try { return [IO.File]::Exists((Get-TvRuntimePath $Root 'stop.request')) } catch { return $true } }
function Clear-TvStop { param([Parameter(Mandatory)][string]$Root); $null = Remove-TvFile $Root 'stop.request' }

# ------------------------------------------------------------------ casts (opt-in)
# The cast key is the screen id a running cast app gives (getMdxSessionStatus)
# and the Lounge token YouTube gives for it: together they can control that
# cast. Sealed with DPAPI for this Windows account, never logged or shown. No
# device name or address is stored: the device is found again each time.

$script:CastEntropy = [Text.Encoding]::ASCII.GetBytes('Parallax.Media.YouTube.Cast.v1')
# What Connections shows for casts (cast.status).
$script:CastStates = @('off', 'searching', 'no_device', 'several', 'waiting', 'following', 'tv_app', 'no_key', 'error')

function New-TvCastKey {
    param([Parameter(Mandatory)][string]$ScreenId, [AllowEmptyString()][string]$LoungeToken = '')
    return [pscustomobject]@{ Name = ''; PairedAt = (Get-TvUnixTime); DeviceId = [Guid]::NewGuid().ToString(); ScreenId = $ScreenId; LoungeToken = $LoungeToken }
}

function Save-TvCastKey {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object]$Key)
    if ($Key.ScreenId.Length -lt 1 -or $Key.ScreenId.Length -gt 512 -or $Key.LoungeToken.Length -gt 4096) { throw 'Invalid cast key.' }
    $record = [ordered]@{ v = 1; pairedAt = [long]$Key.PairedAt; deviceId = [string]$Key.DeviceId; screenId = [string]$Key.ScreenId; loungeToken = [string]$Key.LoungeToken }
    Add-Type -AssemblyName System.Web.Extensions
    $plain = $script:Utf8.GetBytes([Web.Script.Serialization.JavaScriptSerializer]::new().Serialize($record))
    try { $sealed = [Security.Cryptography.ProtectedData]::Protect($plain, $script:CastEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser) }
    finally { [Array]::Clear($plain, 0, $plain.Length) }
    Write-TvFile $Root 'cast.dpapi' $sealed
}

function Read-TvCastKey {
    # The cast key (Pairing-shaped, for New-TvSession), or $null. The token is
    # empty until one was asked for. Never throws.
    param([Parameter(Mandatory)][string]$Root)
    try {
        $path = Get-TvRuntimePath $Root 'cast.dpapi'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 32768) { return $null }
        $plain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($path), $script:CastEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        try { $json = $script:Utf8.GetString($plain) } finally { [Array]::Clear($plain, 0, $plain.Length) }
        Add-Type -AssemblyName System.Web.Extensions
        $parser = [Web.Script.Serialization.JavaScriptSerializer]::new()
        $parser.RecursionLimit = 4
        $record = $parser.DeserializeObject($json)
        if ($record -isnot [Collections.IDictionary] -or $record['v'] -ne 1) { return $null }
        foreach ($key in @('deviceId', 'screenId', 'loungeToken')) { if ($record[$key] -isnot [string]) { return $null } }
        if ($record['screenId'].Length -lt 1 -or $record['screenId'].Length -gt 512 -or $record['loungeToken'].Length -gt 4096) { return $null }
        $device = [Guid]::Empty
        if (-not [Guid]::TryParse($record['deviceId'], [ref]$device)) { return $null }
        return [pscustomobject]@{ Name = ''; PairedAt = [long]$record['pairedAt']; DeviceId = $record['deviceId']; ScreenId = $record['screenId']; LoungeToken = $record['loungeToken'] }
    } catch { return $null }
}

function Set-TvCastIntent {
    # The user's cast switch (Connections): on lets the worker look for casts.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][bool]$Enabled)
    Write-TvFile $Root 'cast.intent' ([Text.Encoding]::ASCII.GetBytes('PARALLAX_TV_CAST_V1|' + [int]$Enabled + "`n"))
}

function Test-TvCastIntent {
    param([Parameter(Mandatory)][string]$Root)
    try {
        $path = Get-TvRuntimePath $Root 'cast.intent'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 64) { return $false }
        return ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) -ceq "PARALLAX_TV_CAST_V1|1`n")
    } catch { return $false }
}

function Publish-TvCastStatus {
    # One fixed word and a time for Connections: no names, addresses or ids.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$State, [long]$ValidUntil = 0)
    if ($State -cnotin $script:CastStates -or $ValidUntil -lt 0) { throw 'Invalid cast state.' }
    Write-TvFile $Root 'cast.status' ([Text.Encoding]::ASCII.GetBytes("PARALLAX_TV_CASTSTATE_V1|$State|$ValidUntil`n"))
}

function Read-TvCastStatus {
    param([Parameter(Mandatory)][string]$Root)
    try {
        $path = Get-TvRuntimePath $Root 'cast.status'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 64) { return $null }
        $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path))
        if ($text -cnotmatch '\APARALLAX_TV_CASTSTATE_V1\|([a-z_]+)\|([0-9]{1,12})\n\z' -or $Matches[1] -cnotin $script:CastStates) { return $null }
        return [pscustomobject]@{ State = $Matches[1]; ValidUntil = [long]$Matches[2] }
    } catch { return $null }
}

function Remove-TvCastData {
    # Forget for casts: the switch, the sealed key and the state are removed.
    param([Parameter(Mandatory)][string]$Root)
    foreach ($name in @('cast.intent', 'cast.dpapi', 'cast.status')) { $null = Remove-TvFile $Root $name }
}

# ------------------------------------------------------------------ code stamp
# A worker writes the stamp of the code it was started from. Resume (Media's
# player loading) compares it with the files now on disk and restarts a worker
# from older code once; a worker with no stamp is from before stamps existed.

function Get-TvCodeStamp {
    # A short hash of the worker's code files as they are on disk now.
    param([Parameter(Mandatory)][string[]]$Paths)
    $hash = [Security.Cryptography.SHA256]::Create()
    $all = [IO.MemoryStream]::new()
    try {
        foreach ($path in $Paths) {
            $name = [Text.Encoding]::ASCII.GetBytes([IO.Path]::GetFileName($path).ToLowerInvariant() + '|')
            $all.Write($name, 0, $name.Length)
            $bytes = [IO.File]::ReadAllBytes($path)
            $all.Write($bytes, 0, $bytes.Length)
        }
        return [BitConverter]::ToString($hash.ComputeHash($all.ToArray())).Replace('-', '').Substring(0, 32).ToLowerInvariant()
    } finally { $all.Dispose(); $hash.Dispose() }
}

function Set-TvStampFile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateSet('worker.stamp', 'upgrade.marker')][string]$Name, [Parameter(Mandatory)][string]$Stamp)
    if ($Stamp -cnotmatch '\A[a-f0-9]{32}\z') { throw 'Invalid code stamp.' }
    Write-TvFile $Root $Name ([Text.Encoding]::ASCII.GetBytes("PARALLAX_TV_STAMP_V1|$Stamp`n"))
}

function Get-TvStampFile {
    # The stamp in the file, or '' when there is none or it is unreadable.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateSet('worker.stamp', 'upgrade.marker')][string]$Name)
    try {
        $path = Get-TvRuntimePath $Root $Name
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -gt 64) { return '' }
        $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path))
        if ($text -cmatch '\APARALLAX_TV_STAMP_V1\|([a-f0-9]{32})\n\z') { return $Matches[1] }
    } catch {}
    return ''
}

function New-TvLaunchId {
    param([Parameter(Mandatory)][string]$Root)
    $id = [Guid]::NewGuid().ToString('N')
    Write-TvFile $Root 'launch.id' ([Text.Encoding]::ASCII.GetBytes("$id`n"))
    return $id
}

function Test-TvLaunchId {
    param([Parameter(Mandatory)][string]$Root, [AllowEmptyString()][string]$Id)
    if ($Id -cnotmatch '\A[a-f0-9]{32}\z') { return $false }
    try {
        $path = Get-TvRuntimePath $Root 'launch.id'
        if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -ne 33) { return $false }
        return ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) -ceq "$Id`n")
    } catch { return $false }
}

# ------------------------------------------------------------------ diagnostics
# Opt-in (Start -Diagnostics): one line per event, command and connection
# change, so a live test can see what arrived. Only event and field names,
# state numbers, counts and HTTP statuses are written: callers pass no ids,
# and anything outside a small character set is replaced.

function Write-TvDiagnostic {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Text)
    try {
        $path = Get-TvRuntimePath $Root 'events.log'
        if ([IO.File]::Exists($path) -and [IO.FileInfo]::new($path).Length -gt $script:LogLimit) {
            $old = Get-TvRuntimePath $Root 'events.old.log'
            if ([IO.File]::Exists($old)) { [IO.File]::Delete($old) }
            [IO.File]::Move($path, $old)
        }
        $clean = [regex]::Replace($Text, '[^A-Za-z0-9 _=.,:;|()/+-]', '?')
        if ($clean.Length -gt 400) { $clean = $clean.Substring(0, 400) }
        [IO.File]::AppendAllText($path, ([DateTime]::Now.ToString('HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture) + ' ' + $clean + "`r`n"), [Text.Encoding]::ASCII)
    } catch {}
}

function Get-TvSafeName {
    # An event or field name as sent by the screen, if it is a plain name.
    param([AllowNull()][object]$Name)
    if ($Name -is [string] -and $Name -cmatch '\A[A-Za-z][A-Za-z0-9_]{0,39}\z') { return $Name }
    return '(other)'
}

Export-ModuleMember -Function Get-TvUnixTime, Get-TvDataRoot, Resolve-TvPrivatePath, Initialize-TvPrivateDirectory, Test-TvFolderPrivate, Get-TvRuntimePath, Write-TvFile, Remove-TvFile,
    New-TvPairing, Save-TvPairing, Read-TvPairing, Test-TvPaired,
    New-TvSnapshot, ConvertTo-TvSnapshotText, Publish-TvSnapshot, Read-TvSnapshotFields, Test-TvJpeg, Save-TvCover, Remove-TvCovers,
    Write-TvRequest, Read-TvRequest, Set-TvIntent, Test-TvIntent, Request-TvStop, Test-TvStop, Clear-TvStop, New-TvLaunchId, Test-TvLaunchId,
    Get-TvCodeStamp, Set-TvStampFile, Get-TvStampFile,
    New-TvCastKey, Save-TvCastKey, Read-TvCastKey, Set-TvCastIntent, Test-TvCastIntent, Publish-TvCastStatus, Read-TvCastStatus, Remove-TvCastData,
    Write-TvDiagnostic, Get-TvSafeName
