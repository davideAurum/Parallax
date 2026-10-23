# Original Parallax native media-source observer. Windows PowerShell 5.1.
# No network, authentication, playback controls, or executable dependencies.
[CmdletBinding()]
param(
    [ValidateSet('Help','Start','Resume','Run','Stop','Once')][string]$Command = 'Help',
    [string]$DataRoot,
    [string]$OwnerLease = '',
    [switch]$Quiet
)

Set-StrictMode -Version 2.0
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProviderOwner.psm1') -Force -DisableNameChecking
$script:SourceProviderPath = $PSCommandPath
$script:SourceManager = $null
$script:SourcePendingTask = $null
$script:SourceAsTask = $null
$script:SourceAdapter = $null
$script:SourceStrictUtf8 = New-Object Text.UTF8Encoding($false, $true)
# The last root string accepted by Resolve-SourceDataRoot and its resolved form.
$script:SourceRootInput = $null
$script:SourceRoot = $null
# Change-only publishing: an unchanged ready observation without a playing
# Spotify record is rewritten once the published one has less than this many
# seconds of validity left (see Test-SourcePublishDue).
$script:SourceHeartbeatLeadSeconds = 3.0

function Get-SourceUnixTime { [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds) }
function Get-SourceUnixTimeExact { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0 }

function Get-SourceDefaultRoot {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Parallax\Media\Source'
}

function Resolve-SourceDataRoot {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { $Path = Get-SourceDefaultRoot }
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]' -or
        $Path -match '[\x00-\x1F"<>|?*]' -or $Path.Substring(2).Contains(':')) {
        throw 'Source storage must be an absolute local directory.'
    }
    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($resolved.Length -gt 220) { throw 'Source storage path is too long.' }
    $default = [IO.Path]::GetFullPath((Get-SourceDefaultRoot)).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $resolved.Equals($default, [StringComparison]::OrdinalIgnoreCase) -and
        -not $resolved.StartsWith($temp + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Source storage must use its private default directory or a dedicated temp directory.'
    }
    if ($resolved -match '(?i)(^|[\\/])skins([\\/]|$)') { throw 'Source storage cannot be inside skins.' }
    Assert-SourceOrdinaryAncestors $resolved
    return $resolved
}

# Anti-junction guard: every existing component of $Path, up to its drive root,
# must be an ordinary directory, never a file, junction or symbolic link. .NET
# calls only, because it runs before every runtime-file write.
function Assert-SourceOrdinaryAncestors {
    param([string]$Path)
    $probe = $Path
    while ($probe) {
        if ([IO.File]::Exists($probe) -or ([IO.Directory]::Exists($probe) -and
            ([IO.File]::GetAttributes($probe) -band [IO.FileAttributes]::ReparsePoint))) {
            throw 'Source storage ancestors must be ordinary directories.'
        }
        $parent = [IO.Path]::GetDirectoryName($probe)
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
}

# The same guard for one runtime file: its directory chain, and the file itself
# when present, which must be an ordinary file.
function Assert-SourceRuntimePath {
    param([string]$Path)
    Assert-SourceOrdinaryAncestors ([IO.Path]::GetDirectoryName($Path))
    if ([IO.Directory]::Exists($Path) -or ([IO.File]::Exists($Path) -and
        ([IO.File]::GetAttributes($Path) -band [IO.FileAttributes]::ReparsePoint))) {
        throw 'Source runtime files must be ordinary files.'
    }
}

function Set-SourcePrivateFile {
    param([string]$Path)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object Security.AccessControl.FileSecurity
    $security.SetOwner($sid)
    $security.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'Allow')
    $null = $security.AddAccessRule($rule)
    [IO.File]::SetAccessControl($Path, $security)
}

function Initialize-SourceStorage {
    param([string]$Path)
    $root = Resolve-SourceDataRoot $Path
    $null = [IO.Directory]::CreateDirectory($root)
    $null = Resolve-SourceDataRoot $root
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object Security.AccessControl.DirectorySecurity
    $security.SetOwner($sid)
    $security.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $null = $security.AddAccessRule($rule)
    [IO.Directory]::SetAccessControl($root, $security)
    foreach ($name in @('source.snapshot','stop.request','enabled.intent')) {
        $file = Get-SourceRuntimeFile $root $name
        if (Test-Path -LiteralPath $file) { Set-SourcePrivateFile $file }
    }
    return $root
}

function Get-SourceRuntimeFile {
    param([string]$Root, [ValidateSet('source.snapshot','stop.request','enabled.intent')][string]$Name)
    # The root string (location, length, characters) is validated once per value;
    # it cannot change. The file-system guard runs on every call, so every write
    # still rechecks the whole directory chain for junctions.
    if (-not [string]::Equals($Root, $script:SourceRootInput, [StringComparison]::Ordinal)) {
        $resolved = Resolve-SourceDataRoot $Root
        $script:SourceRootInput = $Root; $script:SourceRoot = $resolved
    }
    $path = [IO.Path]::Combine($script:SourceRoot, $Name)
    Assert-SourceRuntimePath $path
    return $path
}

function Get-SourceMutexName {
    param([string]$Root)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $canonical = (Resolve-SourceDataRoot $Root).ToLowerInvariant()
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $hex = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($sid + '|' + $canonical))).Replace('-','') }
    finally { $hash.Dispose() }
    'Local\Parallax.Media.Source.' + $hex
}

function New-SourceMutex { param([string]$Root) New-Object Threading.Mutex($false, (Get-SourceMutexName $Root)) }
function New-SourceControlMutex { param([string]$Root) New-Object Threading.Mutex($false, ((Get-SourceMutexName $Root)+'.Control')) }
# Auto-reset, so a wake-up nobody consumed cannot keep a later worker spinning.
function New-SourceStopEvent { param([string]$Root) New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, ((Get-SourceMutexName $Root)+'.Stop')) }

# Wakes a waiting worker right after Stop writes its durable marker. The event
# is only a wake-up; if it cannot be set, the worker still sees the marker at
# the end of its current cycle (at most two seconds).
function Send-SourceStopSignal {
    param([string]$Root)
    try {
        $event = New-SourceStopEvent $Root
        try { $null = $event.Set() } finally { $event.Dispose() }
    } catch { }
}

# What a worker waits on between collections: the stop event and, with a lease,
# the owner's own process handle, which the Process object keeps open for the
# whole run. If that handle cannot be waited on, PollOwner keeps the earlier
# 100 ms owner wait instead.
function New-SourceWaiter {
    param($Owner, [Threading.WaitHandle]$StopEvent)
    $handles = New-Object 'Collections.Generic.List[Threading.WaitHandle]'
    if ($null -ne $StopEvent) { $handles.Add($StopEvent) }
    $ownerIndex = -1; $pollOwner = $false
    if ($null -ne $Owner) {
        try {
            $ownerWait = New-Object Threading.ManualResetEvent($false)
            $unused = $ownerWait.SafeWaitHandle
            $ownerWait.SafeWaitHandle = New-Object Microsoft.Win32.SafeHandles.SafeWaitHandle($Owner.Handle, $false)
            $unused.Dispose()
            $ownerIndex = $handles.Count; $handles.Add($ownerWait)
        } catch { $pollOwner = $true }
    }
    [pscustomobject]@{Owner=$Owner; Handles=$handles.ToArray(); OwnerIndex=$ownerIndex; PollOwner=$pollOwner}
}

# One wait for the rest of a cycle. Returns 'owner' once the launching Rainmeter
# has exited (a failed wait counts too: the worker ends and its observation
# expires), 'wake' when the stop event fired or a fallback owner slice ended,
# and 'timeout' otherwise. The stop event comes first, so a Stop that is
# already pending wins over an owner exit, as it did when Stop was polled first.
function Wait-SourceSignal {
    param($Waiter, [int]$Milliseconds)
    if ($Waiter.PollOwner) {
        if (Wait-MediaOwnerExit $Waiter.Owner ([Math]::Min(100, $Milliseconds))) { return 'owner' }
        return 'wake'
    }
    if ($Waiter.Handles.Count -eq 0) { Start-Sleep -Milliseconds $Milliseconds; return 'timeout' }
    try { $index = [Threading.WaitHandle]::WaitAny($Waiter.Handles, $Milliseconds) }
    catch { return 'owner' }
    if ($index -eq [Threading.WaitHandle]::WaitTimeout) { return 'timeout' }
    if ($index -eq $Waiter.OwnerIndex) { return 'owner' }
    return 'wake'
}
function Enter-SourceMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds = 0)
    try { return $Mutex.WaitOne($Milliseconds) }
    catch [Threading.AbandonedMutexException] { return $true }
}

# A passive probe: true while another worker holds this root's worker mutex.
function Test-SourceWorkerRunning {
    param([string]$Root)
    $mutex = New-SourceMutex $Root
    try {
        if (-not (Enter-SourceMutex $mutex)) { return $true }
        $mutex.ReleaseMutex(); return $false
    } finally { $mutex.Dispose() }
}

function Get-SourceKind {
    param([string]$AppId)
    foreach ($known in @('Spotify.exe','Spotify','SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify')) {
        if ([string]::Equals($AppId, $known, [StringComparison]::OrdinalIgnoreCase)) { return 'spotify' }
    }
    return 'other'
}

function ConvertTo-SourceHex {
    param([AllowEmptyString()][string]$Text)
    if ($Text.IndexOf([char]0) -ge 0) { throw 'Native metadata contains an unsupported NUL character.' }
    if ($Text.Length -gt 1024) { throw 'Native metadata exceeds the source protocol limit.' }
    $bytes = $script:SourceStrictUtf8.GetBytes($Text)
    if ($bytes.Length -gt 1024) { throw 'Native metadata exceeds the source protocol limit.' }
    [BitConverter]::ToString($bytes).Replace('-','')
}

function New-SourceSnapshot {
    param([ValidateSet('ready','unavailable','stopped')][string]$State, [object[]]$Records = @(), [long]$Observed = 0)
    if ($State -ne 'ready') { return [pscustomobject]@{State=$State; Observed=0L; ValidUntil=0L; Records=@()} }
    if ($Observed -le 0 -or $Observed -gt 253402300790L -or $Records.Count -gt 16) { throw 'Invalid source snapshot bounds.' }
    [pscustomobject]@{State=$State; Observed=$Observed; ValidUntil=($Observed+6L); Records=@($Records)}
}

function ConvertTo-SourceSnapshotText {
    param($Snapshot)
    $lines = New-Object 'Collections.Generic.List[string]'
    if ($Snapshot.State -notin @('ready','unavailable','stopped')) { throw 'Invalid source state.' }
    $records = @($Snapshot.Records)
    if ($records.Count -gt 16) { throw 'Too many native sessions.' }
    if ($Snapshot.State -eq 'ready') {
        if ($Snapshot.Observed -le 0 -or $Snapshot.ValidUntil -ne ($Snapshot.Observed+6L)) { throw 'Invalid source freshness.' }
    } elseif ($Snapshot.Observed -ne 0 -or $Snapshot.ValidUntil -ne 0 -or $records.Count -ne 0) { throw 'Nonready source snapshot contains data.' }
    foreach ($line in @('PARALLAX_SOURCE_V1',('state='+$Snapshot.State),('observed='+$Snapshot.Observed),
        ('valid_until='+$Snapshot.ValidUntil),('count='+$records.Count))) { $lines.Add($line) }
    for ($index=0; $index -lt $records.Count; $index++) {
        $record = $records[$index]; $number = $index+1
        if ($record.Source -notin @('spotify','other') -or $record.Title -isnot [string] -or $record.Artist -isnot [string] -or
            $record.Playing -notin @(0,1)) { throw 'Invalid source record.' }
        $lines.Add('source'+$number+'='+$record.Source)
        $lines.Add('title'+$number+'='+(ConvertTo-SourceHex $record.Title))
        $lines.Add('artist'+$number+'='+(ConvertTo-SourceHex $record.Artist))
        $lines.Add('playing'+$number+'='+[int]$record.Playing)
    }
    $text = ($lines -join "`n") + "`n"
    if ([Text.Encoding]::ASCII.GetByteCount($text) -gt 131072) { throw 'Source snapshot is too large.' }
    return $text
}

function Write-SourceAtomicFile {
    param([string]$Root, [ValidateSet('source.snapshot','stop.request','enabled.intent')][string]$Name, [string]$Text)
    $destination = Get-SourceRuntimeFile $Root $Name
    if ($Text -match '[^\x00-\x7F]' -or $Text.Length -gt 131072) { throw 'Invalid source output bytes.' }
    # stop.request and enabled.intent are the durable lifecycle vetoes and keep
    # an explicit private ACL on every write. The snapshot's temporary file
    # inherits the private directory's user-only ACL; its first creation still
    # gets the explicit protected ACL, and File.Replace keeps the replaced
    # file's DACL, so routine publishes make no ACL calls.
    $lifecycle = $Name -ne 'source.snapshot'
    $temporary = [IO.Path]::Combine([IO.Path]::GetDirectoryName($destination), $Name+'.'+[Guid]::NewGuid().ToString('N')+'.tmp')
    try {
        $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
            $stream.Write($bytes,0,$bytes.Length)
            # Only the vetoes must survive a power loss. The reader reads the
            # snapshot through the file cache, and after a power loss its old
            # observation is stale anyway (a torn file reads as unavailable).
            if ($lifecycle) { $stream.Flush($true) }
        } finally { $stream.Dispose() }
        # The junction guard again, right before the swap, on the path already
        # resolved above (no second root resolution).
        Assert-SourceRuntimePath $destination
        $replace = [IO.File]::Exists($destination)
        if ($lifecycle -or -not $replace) { Set-SourcePrivateFile $temporary }
        if ($replace) {
            if ($lifecycle) { Set-SourcePrivateFile $destination }
            [IO.File]::Replace($temporary,$destination,[Management.Automation.Language.NullString]::Value)
        } else { [IO.File]::Move($temporary,$destination) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Publish-SourceSnapshot {
    param([string]$Root, $Snapshot)
    Write-SourceAtomicFile $Root 'source.snapshot' (ConvertTo-SourceSnapshotText $Snapshot)
}

# Everything a reader sees in a snapshot except its two timestamps.
function Get-SourcePayloadKey {
    param([string]$Text)
    $Text -replace '(?m)^(?:observed|valid_until)=\d+\n', ''
}

# True when an observation holds a playing Spotify record: the only payload
# whose freshness the Player can show. MediaHeader.lua consults the source
# reader only while WNP reports a generic session playing (state 1), and
# SourceReader.resolve confirms Spotify only for one matching record that is
# classified spotify and also playing. Without such a record a fresh snapshot
# resolves as unmatched and an expired one as stale, and both read Unknown.
function Test-SourcePlayingSpotify {
    param($Snapshot)
    foreach ($record in @($Snapshot.Records)) {
        if ($record.Source -eq 'spotify' -and [int]$record.Playing -eq 1) { return $true }
    }
    return $false
}

# Change-only publishing. A changed observation (state or any record) is written
# at once. An unchanged ready observation is rewritten:
# - every cycle while it holds a playing Spotify record, exactly as before
#   change-only publishing, so the header keeps the old tolerance to a slow
#   collection (the previous observation still has about 3-4 s left when the
#   next one is written);
# - otherwise as a heartbeat when the published one has less than
#   SourceHeartbeatLeadSeconds of validity left, or when the clock has moved
#   back before it. With the 2-second cycle that is about every 4 s; a late one
#   lets the snapshot expire for a moment, which nothing displays.
# SourceReader.parse accepts a ready snapshot only while now < valid_until =
# observed + 6 and observed <= now + 1. Unavailable and stopped observations
# carry no expiry, so unchanged ones are not rewritten.
function Test-SourcePublishDue {
    param($Published, [string]$Key, $Snapshot, [double]$Now)
    if ($null -eq $Published -or -not [string]::Equals($Published.Key, $Key, [StringComparison]::Ordinal)) { return $true }
    if ($Snapshot.State -ne 'ready') { return $false }
    if (Test-SourcePlayingSpotify $Snapshot) { return $true }
    return (($Published.ValidUntil - $Now) -lt $script:SourceHeartbeatLeadSeconds) -or ($Published.Observed -gt $Now)
}

function Get-SourceRemaining {
    param([scriptblock]$Elapsed)
    $elapsedMs = [double](& $Elapsed)
    if ([double]::IsNaN($elapsedMs) -or [double]::IsInfinity($elapsedMs) -or $elapsedMs -lt 0 -or $elapsedMs -ge 4000) {
        throw 'Native session collection exceeded its deadline.'
    }
    return [int][Math]::Max(1,[Math]::Floor(4000-$elapsedMs))
}

function Invoke-SourceAwait {
    param($Operation, [Type]$ResultType, [int]$TimeoutMilliseconds)
    $task = $script:SourceAsTask.MakeGenericMethod($ResultType).Invoke($null,@($Operation))
    $script:SourcePendingTask = $task
    try {
        if (-not $task.Wait($TimeoutMilliseconds)) {
            try { $Operation.Cancel() } catch { }
            throw 'Native session request timed out.'
        }
        return $task.Result
    } finally {
        # A noncooperative timed-out request blocks further collection until it
        # completes, rather than accumulating background requests every poll.
        if ($task.IsCompleted) { $script:SourcePendingTask = $null }
    }
}

function New-SourceNativeAdapter {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
    $script:SourceAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    if ($null -eq $script:SourceAsTask) { throw 'Native session APIs are unavailable.' }
    return [pscustomobject]@{
        GetSessions = {
            param([int]$Remaining)
            if ($null -ne $script:SourcePendingTask -and -not $script:SourcePendingTask.IsCompleted) { throw 'A native session request is still pending.' }
            if ($null -eq $script:SourceManager) {
                $managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
                $script:SourceManager = Invoke-SourceAwait ($managerType::RequestAsync()) $managerType $Remaining
            }
            $list = $script:SourceManager.GetSessions()
            if ($null -eq $list) { throw 'Native session enumeration failed.' }
            foreach ($session in $list) { $session }
        }
        Read = {
            param($Session,[int]$Remaining)
            $properties = Invoke-SourceAwait ($Session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]) $Remaining
            if ($null -eq $properties) { throw 'Native media properties are unavailable.' }
            $playback = $Session.GetPlaybackInfo()
            if ($null -eq $playback) { throw 'Native playback information is unavailable.' }
            [pscustomobject]@{AppId=[string]$Session.SourceAppUserModelId; Title=[string]$properties.Title;
                Artist=[string]$properties.Artist; Playing=([int]($playback.PlaybackStatus.ToString() -eq 'Playing'))}
        }
    }
}

function Read-SourceRecord {
    param($Adapter, $Session, [scriptblock]$Elapsed)
    $record = & $Adapter.Read $Session (Get-SourceRemaining $Elapsed)
    $null = Get-SourceRemaining $Elapsed
    if ($null -eq $record -or $record.AppId -isnot [string] -or $record.Title -isnot [string] -or
        $record.Artist -isnot [string] -or $record.Playing -notin @(0,1)) { throw 'Invalid native session metadata.' }
    $null = ConvertTo-SourceHex $record.Title
    $null = ConvertTo-SourceHex $record.Artist
    return $record
}

function Assert-SourceSessionList {
    param([object[]]$Expected, [object[]]$Actual)
    if ($Expected.Count -gt 16 -or $Expected.Count -ne $Actual.Count) { throw 'Native session list changed or exceeded its limit.' }
    for ($index=0; $index -lt $Expected.Count; $index++) {
        if ($null -eq $Expected[$index] -or -not [object]::ReferenceEquals($Expected[$index],$Actual[$index])) {
            throw 'Native session identity or order changed during collection.'
        }
    }
}

function Get-SourceCollection {
    param($Adapter, [long]$Observed = (Get-SourceUnixTime), [scriptblock]$Elapsed)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if ($null -eq $Elapsed) { $Elapsed = { $timer.Elapsed.TotalMilliseconds }.GetNewClosure() }
    try {
        if ($null -eq $Adapter) {
            # Built once per process (Add-Type plus a reflection search), like the
            # session manager it uses; a failed build is retried next cycle.
            if ($null -eq $script:SourceAdapter) { $script:SourceAdapter = New-SourceNativeAdapter }
            $Adapter = $script:SourceAdapter
        }
        $sessions = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        $null = Get-SourceRemaining $Elapsed
        if ($sessions.Count -gt 16) { throw 'Too many native media sessions.' }
        $records = @()
        foreach ($session in $sessions) { $records += Read-SourceRecord $Adapter $session $Elapsed }
        $middle = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        Assert-SourceSessionList $sessions $middle
        for ($index=0; $index -lt $sessions.Count; $index++) {
            $again = Read-SourceRecord $Adapter $sessions[$index] $Elapsed
            foreach ($key in @('AppId','Title','Artist','Playing')) {
                if (-not [string]::Equals([string]$records[$index].$key,[string]$again.$key,[StringComparison]::Ordinal)) {
                    throw 'Native media properties changed during collection.'
                }
            }
        }
        $after = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        Assert-SourceSessionList $sessions $after
        $null = Get-SourceRemaining $Elapsed
        $output = @($records | ForEach-Object { [pscustomobject]@{Source=(Get-SourceKind $_.AppId);Title=$_.Title;Artist=$_.Artist;Playing=[int]$_.Playing} })
        return New-SourceSnapshot 'ready' $output $Observed
    } catch { return New-SourceSnapshot 'unavailable' }
    finally { $timer.Stop() }
}

# A plain existence check on a root already validated by Resolve-SourceDataRoot
# (every caller passes one). Reading the marker writes nothing, so it needs no
# junction guard; any entry named stop.request, file or not, counts as Stop.
function Test-SourceStopPath {
    param([string]$Path)
    [IO.File]::Exists($Path) -or [IO.Directory]::Exists($Path)
}

function Test-SourceStop {
    param([string]$Root)
    Test-SourceStopPath ([IO.Path]::Combine($Root, 'stop.request'))
}

function Test-SourceEnabledIntent {
    param([string]$Root)
    $path = Get-SourceRuntimeFile $Root 'enabled.intent'
    if (-not [IO.File]::Exists($path)) { return $false }
    $expected = "PARALLAX_AUTOSTART_V1|1`n"
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
        ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        # Exact bounded ASCII bytes only. Missing, disabled, malformed, BOM or
        # oversized intent is not authorization to resume a native observer.
        if ($stream.Length -ne $expected.Length) { return $false }
        foreach ($character in $expected.ToCharArray()) {
            if ($stream.ReadByte() -ne [int]$character) { return $false }
        }
        return $stream.ReadByte() -eq -1
    } finally { $stream.Dispose() }
}

function Set-SourceEnabledIntent {
    param([string]$Root, [bool]$Enabled)
    $value = if ($Enabled) { '1' } else { '0' }
    Write-SourceAtomicFile $Root 'enabled.intent' ("PARALLAX_AUTOSTART_V1|$value`n")
}

function Invoke-SourceOnce {
    param([string]$Root, [scriptblock]$Collector = { Get-SourceCollection })
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return $false }
        $snapshot = & $Collector
        Publish-SourceSnapshot $Root $snapshot
        return $true
    } finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}

function Invoke-SourceRun {
    # CycleMilliseconds and Clock exist for the synthetic tests; the Run command
    # always uses the 2-second cycle and the system clock.
    param([string]$Root, [scriptblock]$Collector = { Get-SourceCollection }, [string]$Lease = '',
        [ValidateRange(50,2000)][int]$CycleMilliseconds = 2000, [scriptblock]$Clock = { Get-SourceUnixTimeExact })
    $owner = Open-MediaOwner $Lease
    if ($owner -is [bool]) { return $false }
    $mutex = New-SourceMutex $Root; $owned = $false; $stopEvent = $null; $waiter = $null
    try {
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return $false }
        # The root was validated by the caller; the stop marker's path is fixed
        # for the whole run, so checking it is a single .NET existence check.
        $stopPath = [IO.Path]::Combine($Root, 'stop.request')
        # Without the event (an unavailable or squatted name) Stop is still seen
        # at the end of the current cycle, because the marker is checked there.
        try { $stopEvent = New-SourceStopEvent $Root } catch { $stopEvent = $null }
        $waiter = New-SourceWaiter $owner $stopEvent
        # The first observation of every run is always written; see
        # Test-SourcePublishDue for when later ones are.
        $published = $null
        # Only an explicit Start clears a previous Stop. A delayed child must
        # preserve a Stop that completed after the launch was requested.
        while (-not (Test-SourceStopPath $stopPath)) {
            $cycle = [Diagnostics.Stopwatch]::StartNew()
            try { $snapshot = & $Collector } catch { $snapshot = New-SourceSnapshot 'unavailable' }
            if (Test-SourceStopPath $stopPath) { break }
            $text = ConvertTo-SourceSnapshotText $snapshot
            $key = Get-SourcePayloadKey $text
            if (Test-SourcePublishDue $published $key $snapshot ([double](& $Clock))) {
                Write-SourceAtomicFile $Root 'source.snapshot' $text
                $published = [pscustomobject]@{Key=$key; Observed=$snapshot.Observed; ValidUntil=$snapshot.ValidUntil}
            }
            # One wait for the rest of the cycle instead of 100 ms polling. A wake
            # re-checks the durable marker, because any process in this session
            # can set a Local\ event; a spurious wake only resumes the wait.
            while (($remaining = $CycleMilliseconds - $cycle.ElapsedMilliseconds) -gt 0) {
                $signal = Wait-SourceSignal $waiter ([int]$remaining)
                # The launching Rainmeter is gone. Exit without a 'stopped'
                # snapshot: resume intent is unchanged, and the next Rainmeter's
                # skin load starts a fresh worker.
                if ($signal -eq 'owner') { return $true }
                if ($signal -eq 'timeout' -or (Test-SourceStopPath $stopPath)) { break }
            }
            $cycle.Stop()
        }
        Publish-SourceSnapshot $Root (New-SourceSnapshot 'stopped')
        return $true
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose()
        if ($null -ne $waiter -and $waiter.OwnerIndex -ge 0) { $waiter.Handles[$waiter.OwnerIndex].Dispose() }
        if ($null -ne $stopEvent) { $stopEvent.Dispose() }
        if ($owner) { $owner.Dispose() }
    }
}

function Stop-SourceObserver {
    param([string]$Root)
    $control = New-SourceControlMutex $Root; $controlOwned = $false
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $controlOwned = Enter-SourceMutex $control 10000
        if (-not $controlOwned) { throw 'Another source lifecycle action is still running.' }
        # The Stop marker is the durable veto. If the following intent write
        # fails, Resume must still leave this explicit Stop in force.
        Write-SourceAtomicFile $Root 'stop.request' "stop`n"
        # Wake a waiting worker now; the marker above stays the durable signal.
        Send-SourceStopSignal $Root
        Set-SourceEnabledIntent $Root $false
        $owned = Enter-SourceMutex $mutex 10000
        if (-not $owned) { throw 'The source observer has not stopped yet.' }
        Publish-SourceSnapshot $Root (New-SourceSnapshot 'stopped')
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }; $control.Dispose()
    }
}

function Start-SourceObserver {
    param([string]$Root, [switch]$Resume)
    $executable = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not [IO.File]::Exists($executable) -or $script:SourceProviderPath -match '["\r\n]') { throw 'Windows PowerShell is unavailable.' }
    $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Command Run -DataRoot "{1}" -Quiet' -f $script:SourceProviderPath,$Root
    $control = New-SourceControlMutex $Root; $controlOwned = $false
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $controlOwned = Enter-SourceMutex $control 10000
        if (-not $controlOwned) { throw 'Another source lifecycle action is still running.' }
        if ($Resume) {
            # Recheck under lifecycle ownership: Stop may have completed after
            # the entrypoint's initial passive intent check.
            if (-not (Test-SourceEnabledIntent $Root) -or (Test-SourceStop $Root)) { return }
        } else {
            # A repeated explicit Start also opts an already-running observer
            # into future resume, without launching a duplicate worker.
            Set-SourceEnabledIntent $Root $true
        }
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return }
        # Do not retain worker ownership across asynchronous process startup:
        # a quickly starting child would otherwise mistake us for a worker.
        $mutex.ReleaseMutex(); $owned = $false
        # Bind the worker to the Rainmeter that asked for it (no lease from a
        # shell). Computed only now, as Start-QueueBackground does: its CIM walk
        # is wasted on the usual Resume that finds the worker already running.
        $lease = Get-MediaOwnerLease
        if ($lease) { $arguments += ' -OwnerLease ' + $lease }
        if (-not $Resume) {
            $stop = Get-SourceRuntimeFile $Root 'stop.request'
            if ([IO.File]::Exists($stop)) { [IO.File]::Delete($stop) }
        }
        Start-Process -FilePath $executable -ArgumentList $arguments -WorkingDirectory $Root -WindowStyle Hidden -ErrorAction Stop
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }; $control.Dispose()
    }
}

function Resume-SourceObserver {
    param([string]$Root)
    Start-SourceObserver $Root -Resume
}

function Invoke-SourceCommand {
    param([string]$Action, [string]$Path)
    if ($Action -eq 'Help') {
        Write-Output 'Parallax native source observer (Windows PowerShell 5.1). Start enables one local worker and saves resume intent; Stop ends it and disables resume. Resume starts only a previously enabled, unstopped observer. Once publishes one bounded observation. No Spotify sign-in, network, or playback control is used.'
        return
    }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 for native media sessions.' }
    if (-not (Test-MediaOwnerLeaseText $OwnerLease)) { throw 'Invalid owner lease.' }
    if ($Action -eq 'Resume') {
        $candidate = Resolve-SourceDataRoot $Path
        # A load-time resume check must not create private runtime storage for
        # a user who has never enabled source detection.
        if (-not (Test-SourceEnabledIntent $candidate) -or (Test-SourceStop $candidate)) { return }
        # A running worker set up its storage when it started. Probe it before
        # Initialize-SourceStorage rewrites the directory and file ACLs on every
        # Media refresh. Start-SourceObserver probes again under the control
        # mutex, so the outcome is the one it would have reached anyway.
        if (Test-SourceWorkerRunning $candidate) { return }
    }
    $root = Initialize-SourceStorage $Path
    switch ($Action) {
        'Start' { Start-SourceObserver $root }
        'Resume' { Resume-SourceObserver $root }
        'Run' {
            # Never keep the skin folder as the working directory: a live worker
            # would then stop Skin Installer moving Skins\Parallax on upgrade.
            [Environment]::CurrentDirectory = $root
            Set-Location -LiteralPath $root
            $null = Invoke-SourceRun $root -Lease $OwnerLease
        }
        'Stop' { Stop-SourceObserver $root }
        'Once' { $null = Invoke-SourceOnce $root }
        default { throw 'Unknown source observer command.' }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-SourceCommand $Command $DataRoot }
    catch {
        if (-not $Quiet) { Write-Error 'The native source observer could not complete this action. Use Windows PowerShell 5.1 and its dedicated local storage directory.' }
        exit 1
    }
}
