# Optional TV queue worker (YouTube in the TV's own app). Windows PowerShell 5.1
# and built-in .NET only. Imports are passive: nothing touches the network until
# the user pairs a TV (Pair) or starts the worker (Start); Resume only continues
# a worker the user started before. One long-lived worker holds one remote
# session for both the TV's events and the commands sent to it.
#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Help', 'Pair', 'Start', 'Resume', 'Run', 'Stop', 'Forget', 'Send', 'Status', 'CastOn', 'CastOff', 'CastForget')][string]$Command = 'Help',
    # Pair: the code from the TV's Settings > Link with TV code (asked if empty).
    [string]$Code = '',
    # Send: what to ask the running worker. jump needs -Row and -Observed: the row
    # number as shown and the snapshot's observed time.
    [ValidateSet('refresh', 'pause', 'play', 'next', 'jump')][string]$Action = 'refresh',
    [ValidateRange(0, 20)][int]$Row = 0,
    [ValidateRange(0, 253402300000)][long]$Observed = 0,
    # Start/Pair: also keep the redacted events.log (names, numbers, no ids).
    [switch]$Diagnostics,
    [switch]$NoStart,
    # Run only: replace a running worker from older code (Resume after an update).
    [switch]$Takeover,
    [switch]$Quiet,
    [ValidatePattern('\A(?:[a-f0-9]{32})?\z')][string]$LaunchId = '',
    [string]$DataRoot = '',
    [ValidatePattern('\A(?:[1-9][0-9]{0,9}:[1-9][0-9]{0,18})?\z')][string]$OwnerLease = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TvLounge.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'TvStore.psm1') -Force -DisableNameChecking
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProviderOwner.psm1') -Force -DisableNameChecking
$script:ProviderPath = $PSCommandPath
# The files a worker runs from: their stamp tells a worker from older code.
$script:CodeFiles = @($PSCommandPath, (Join-Path $PSScriptRoot 'TvLounge.psm1'), (Join-Path $PSScriptRoot 'TvStore.psm1'), (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProviderOwner.psm1'))
# Waits after failures in a row, in seconds; the last repeats.
$script:Backoff = @(5, 10, 20, 40, 80, 160, 300)
# The snapshot is rewritten at least this often, and counts as gone after.
$script:HeartbeatMs = 60000
$script:ValidSeconds = 150
# Titles: one lookup per pass; a missing video is asked again after an hour, a
# failed lookup after five minutes. At most this many are remembered (in memory
# only: nothing about what played is written to disk but the snapshot).
$script:TitleMissingMs = 3600000
$script:TitleRetryMs = 300000
$script:TitleLimit = 400
# Thumbnail: only the current video's, at most one download per pass; a missing
# one is asked again after an hour, a failed one after five minutes.
$script:CoverLimit = 262144
$script:RowLimit = 20

function Show-TvHelp {
    Write-Output @'
Parallax TV queue (YouTube in the TV's own app)
1. On the TV: YouTube > Settings > Link with TV code.
2. Run this script with -Command Pair and type the code. The worker then starts.

Commands: Pair [-Code n] [-NoStart] [-Diagnostics], Start [-Diagnostics], Resume (only
          if started before), Stop, Forget (stop and remove the pairing), Status,
          Send -Action refresh|pause|play|next, Send -Action jump -Row n -Observed t.
Casts:    CastOn (follow a YouTube cast on the TV; finds the TV on your network),
          CastOff, CastForget (off, and remove the stored cast key).
Data: %LOCALAPPDATA%\Parallax\Media\YouTube, for this Windows user only; the pairing
is sealed with DPAPI. Uses YouTube's unofficial TV remote API, which can change.
'@
}

# ------------------------------------------------------------------ locks

function Get-TvMutexName {
    param([string]$Root)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value + '|' + [IO.Path]::GetFullPath($Root).ToUpperInvariant()
        return 'Local\Parallax.YouTube.Tv.' + [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-', '')
    } finally { $hash.Dispose() }
}
function New-TvRunMutex { param([string]$Root); return [Threading.Mutex]::new($false, (Get-TvMutexName $Root)) }
function New-TvControlMutex { param([string]$Root); return [Threading.Mutex]::new($false, ((Get-TvMutexName $Root) + '.Control')) }
function Wait-TvMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds)
    try { return $Mutex.WaitOne($Milliseconds) } catch [Threading.AbandonedMutexException] { return $true }
}
function Test-TvWorkerRunning {
    param([string]$Root)
    $mutex = New-TvRunMutex $Root
    try {
        if (Wait-TvMutex $mutex 0) { $mutex.ReleaseMutex(); return $false }
        return $true
    } finally { $mutex.Dispose() }
}

# ------------------------------------------------------------------ worker pieces

function Get-TvBackoffMs { param([int]$Failures); return [long]$script:Backoff[[Math]::Min([Math]::Max($Failures, 1), $script:Backoff.Count) - 1] * 1000 }

function Write-TvWorkerLog {
    param([object]$Worker, [string]$Text)
    if ($Worker.Diagnostics) { Write-TvDiagnostic $Worker.Root $Text }
}

function Get-TvEventSummary {
    # A diagnostics line for one event: names and numbers only, never values.
    param([object]$TvEvent, [object]$Player, [string]$VideoBefore)
    $fields = Get-TvEventFields $TvEvent
    $names = @($fields.Keys | ForEach-Object { Get-TvSafeName $_ }) -join ','
    $line = 'event ' + (Get-TvSafeName $TvEvent.Name) + ' fields=' + $names
    if ($fields.ContainsKey('state')) { $line += ' state=' + (Get-TvPlayName $Player.State) }
    if ($TvEvent.Name -ceq 'nowPlaying' -and $fields.Count -gt 0) {
        $line += ' ids=' + $Player.Ids.Count + ' video=' + $(if (-not $Player.VideoId) { 'none' } elseif ($Player.VideoId -ceq $VideoBefore) { 'same' } else { 'new' })
        $up = Get-TvUpNext $Player
        $line += ' upnext=' + $up.Status + ' list=' + $up.Kind + ' after=' + $up.Total
    }
    return $line
}

function Connect-TvScreen {
    # Binds one session. A refused token is renewed once (and saved); a second
    # refusal, or a refused renewal, means pairing again. Returns Session or
    # Kind: offline, refused, error, pair_again.
    # -Cast: the pairing is the cast key, renewed into cast.dpapi.
    param([string]$Root, [object]$Pairing, [switch]$Cast)
    $renewed = $false
    while ($true) {
        $session = New-TvSession $Pairing
        $answer = Invoke-TvHttp (New-TvBindRequest $session)
        if ($answer.Status -eq 401 -or $answer.Status -eq 403) {
            if ($renewed) { return [pscustomobject]@{ Session = $null; Events = @(); Kind = 'pair_again'; Status = $answer.Status } }
            $renewed = $true
            $token = Invoke-TvHttp (New-TvTokenRequest $Pairing.ScreenId)
            if ($token.Status -eq 0) { return [pscustomobject]@{ Session = $null; Events = @(); Kind = 'offline'; Status = 0 } }
            if ($token.Status -ne 200) {
                $kind = if ($token.Status -ge 400 -and $token.Status -le 499 -and $token.Status -ne 429) { 'pair_again' } else { 'error' }
                return [pscustomobject]@{ Session = $null; Events = @(); Kind = $kind; Status = $token.Status }
            }
            try { $Pairing.LoungeToken = ConvertFrom-TvTokenAnswer $token.Text } catch { return [pscustomobject]@{ Session = $null; Events = @(); Kind = 'pair_again'; Status = 200 } }
            if ($Cast) { $null = Save-TvCastKeyGuarded $Root $Pairing } else { Save-TvPairing $Root $Pairing }
            continue
        }
        if ($answer.Status -ne 200) {
            $kind = if ($answer.Status -eq 0) { 'offline' } elseif ($answer.Status -ge 400 -and $answer.Status -le 499 -and $answer.Status -ne 429) { 'refused' } else { 'error' }
            return [pscustomobject]@{ Session = $null; Events = @(); Kind = $kind; Status = $answer.Status }
        }
        try { $events = @(Read-TvFrames (New-TvFrameReader) $answer.Text) } catch { return [pscustomobject]@{ Session = $null; Events = @(); Kind = 'error'; Status = 200 } }
        foreach ($item in $events) { Update-TvSession $session $item }
        if (-not $session.Sid -or -not $session.GSession) { return [pscustomobject]@{ Session = $null; Events = @(); Kind = 'error'; Status = 200 } }
        return [pscustomobject]@{ Session = $session; Events = $events; Kind = ''; Status = 200 }
    }
}

function New-TvWorker {
    param([string]$Root, [object]$Pairing, [bool]$Diagnostics)
    return [pscustomobject]@{
        Root = $Root; Pairing = $Pairing; Diagnostics = $Diagnostics
        Session = $null; Poll = $null; Player = (New-TvPlayer)
        State = 'connecting'; Failures = 0; NextAttemptMs = 0L; QuickEnds = 0; Fatal = $false; TvIdle = $false
        Notice = ''; Observed = 0L; RowsKey = $null; PublishedAt = 0L; LastText = ''
        Views = [Collections.Generic.List[object]]::new()
        Titles = @{}
        # The current video's thumbnail: which video it shows, its slot (1 or 2,
        # 0 for none) and when a failed download may be tried again.
        CoverVideo = ''; CoverSlot = 0; CoverMiss = ''; CoverRetryAt = 0L; LookedUp = $false
        # Casts (opt-in, off until the user's switch is seen): see New-TvCastFollower.
        Cast = (New-TvCastFollower)
    }
}

function Update-TvLookups {
    # At most one title or thumbnail lookup per pass; $true when one arrived.
    param([object]$Worker)
    $Worker.LookedUp = $false
    if (Update-TvTitle $Worker) { return $true }
    # The thumbnail waits while titles are being asked.
    if (-not $Worker.LookedUp -and (Update-TvCover $Worker)) { return $true }
    return $false
}

function Invoke-TvRoutedAction {
    # A request goes to what the snapshot shows: a followed cast, or the TV's app.
    param([object]$Worker, [object]$Request)
    if (Test-TvCastShown $Worker) { return (Invoke-TvCastAction $Worker $Request) }
    if ($null -eq $Worker.Session -or $null -eq $Worker.Poll) { Write-TvWorkerLog $Worker ('request ' + $Request.Kind + ': not connected'); return 'not_connected' }
    return (Invoke-TvAction $Worker $Request)
}

function Get-TvWorkerState {
    param([object]$Worker)
    if ($null -eq $Worker.Pairing) { return 'not_paired' }
    if ($Worker.TvIdle) { return $Worker.State }
    if ($null -ne $Worker.Session) {
        if ($Worker.Player.Screen -eq $true) { return 'ready' }
        if ($Worker.Player.Screen -eq $false) { return 'no_screen' }
        return 'connecting'
    }
    return $Worker.State
}

function Get-TvCachedTitle {
    param([object]$Worker, [string]$VideoId)
    if ($VideoId -and $Worker.Titles.ContainsKey($VideoId)) { return [string]$Worker.Titles[$VideoId].Title }
    return ''
}

function Get-TvCachedChannel {
    param([object]$Worker, [string]$VideoId)
    if ($VideoId -and $Worker.Titles.ContainsKey($VideoId)) { return [string]$Worker.Titles[$VideoId].Channel }
    return ''
}

function Publish-TvWorker {
    # Writes the snapshot from the worker's picture. A new set of rows gets a new
    # observed time (later than the last), and is remembered so a row click can
    # be mapped back to the video it showed.
    param([object]$Worker, [long]$NowMs = (Get-TvUnixMs))
    $now = [long][Math]::Floor($NowMs / 1000)
    if (Test-TvCastShown $Worker) { Publish-TvCastSnapshot $Worker $NowMs; return }
    $state = Get-TvWorkerState $Worker
    $notice = $Worker.Notice
    if ($state -cne 'ready') {
        if ($notice -cin @('sent', 'queue_changed')) { $notice = '' }
        $retry = 0L
        if ($state -cin @('offline', 'error', 'no_screen') -and $null -eq $Worker.Session -and $Worker.NextAttemptMs -gt $NowMs) { $retry = [long][Math]::Ceiling($Worker.NextAttemptMs / 1000) }
        $valid = if ($state -cin @('stopped', 'not_paired', 'pair_again')) { 0L } else { $now + $script:ValidSeconds }
        $snapshot = New-TvSnapshot -State $state -ValidUntil $valid -RetryAt $retry -Notice $notice
        $Worker.RowsKey = $null
    } else {
        $player = $Worker.Player
        $up = Get-TvUpNext $player $script:RowLimit
        $key = $player.VideoId + '|' + $up.Status + '|' + ($up.Ids -join ',')
        if ($key -cne $Worker.RowsKey) {
            $Worker.Observed = [Math]::Max($now, $Worker.Observed + 1)
            $Worker.RowsKey = $key
            $Worker.Views.Add([pscustomobject]@{ Observed = $Worker.Observed; Ids = $up.Ids })
            while ($Worker.Views.Count -gt 6) { $Worker.Views.RemoveAt(0) }
        }
        $titles = [string[]]@($up.Ids | ForEach-Object { Get-TvCachedTitle $Worker $_ })
        $snapshot = New-TvSnapshot -State ready -Observed $Worker.Observed -ValidUntil ([Math]::Max($now, $Worker.Observed) + $script:ValidSeconds) -Play (Get-TvPlayName $player.State) `
            -PositionMs (Get-TvPositionMs $player $NowMs) -PositionAtMs $NowMs -DurationMs $player.DurationMs -UpNext $up.Status -List $up.Kind -Total $up.Total `
            -Notice $notice -CurrentTitle (Get-TvCachedTitle $Worker $player.VideoId) -Titles $titles `
            -CurrentChannel (Get-TvCachedChannel $Worker $player.VideoId) -Cover $(if ($player.VideoId -and $Worker.CoverVideo -ceq $player.VideoId) { $Worker.CoverSlot } else { 0 })
    }
    Publish-TvSnapshot $Worker.Root $snapshot
    $Worker.PublishedAt = $NowMs
    $Worker.Notice = ''
    $Worker.Player.Changed = $false
}

function Update-TvTitle {
    # Looks up at most one missing title (the current video first, then the
    # shown rows). Returns $true when a new title arrived.
    param([object]$Worker, [long]$NowMs = (Get-TvUnixMs))
    if (Test-TvCastShown $Worker) {
        # A cast: Cast reports the title (and usually the channel) itself.
        $picture = $Worker.Cast.Picture
        if ($picture.Title -and $picture.Subtitle) { return $false }
        $wanted = @($picture.VideoId)
    } else {
        if ((Get-TvWorkerState $Worker) -cne 'ready') { return $false }
        $player = $Worker.Player
        $wanted = @($player.VideoId) + @((Get-TvUpNext $player $script:RowLimit).Ids)
    }
    foreach ($id in $wanted) {
        if (-not $id) { continue }
        if ($Worker.Titles.ContainsKey($id)) {
            $held = $Worker.Titles[$id]
            if ($held.Title -or $held.RetryAt -gt $NowMs) { continue }
        }
        if ($Worker.Titles.Count -ge $script:TitleLimit) { $Worker.Titles.Clear() }
        $answer = Invoke-TvHttp (New-TvTitleRequest $id) -TimeoutSeconds 5 -Limit 65536
        $video = if ($answer.Status -eq 200) { ConvertFrom-TvVideoAnswer $answer.Text } else { [pscustomobject]@{ Title = ''; Channel = '' } }
        $title = $video.Title
        $retry = if ($title) { 0L } elseif ($answer.Status -in @(401, 403, 404)) { $NowMs + $script:TitleMissingMs } else { $NowMs + $script:TitleRetryMs }
        $Worker.Titles[$id] = [pscustomobject]@{ Title = $title; Channel = $video.Channel; RetryAt = $retry }
        $Worker.LookedUp = $true
        return [bool]$title
    }
    return $false
}

function Update-TvCover {
    # Downloads the current video's thumbnail into the slot not shown now, once
    # per video. Returns $true when a new one is ready to be named.
    param([object]$Worker, [long]$NowMs = (Get-TvUnixMs))
    if (Test-TvCastShown $Worker) { $id = $Worker.Cast.Picture.VideoId }
    elseif ((Get-TvWorkerState $Worker) -cne 'ready') { return $false }
    else { $id = $Worker.Player.VideoId }
    if (-not $id -or $id -ceq $Worker.CoverVideo) { return $false }
    if ($id -ceq $Worker.CoverMiss -and $Worker.CoverRetryAt -gt $NowMs) { return $false }
    $answer = Invoke-TvHttp (New-TvThumbRequest $id) -TimeoutSeconds 5 -Limit $script:CoverLimit -Binary
    $bytes = if ($answer.Status -eq 200 -and $answer.PSObject.Properties['Data']) { [byte[]]$answer.Data } else { $null }
    if (-not (Test-TvJpeg $bytes)) {
        $Worker.CoverMiss = $id
        $Worker.CoverRetryAt = if ($answer.Status -in @(401, 403, 404)) { $NowMs + $script:TitleMissingMs } else { $NowMs + $script:TitleRetryMs }
        Write-TvWorkerLog $Worker ('thumbnail http=' + $answer.Status + ' usable=no')
        return $false
    }
    $slot = if ($Worker.CoverSlot -eq 1) { 2 } else { 1 }
    try { Save-TvCover $Worker.Root $slot $bytes } catch { $Worker.CoverMiss = $id; $Worker.CoverRetryAt = $NowMs + $script:TitleRetryMs; return $false }
    $Worker.CoverVideo = $id
    $Worker.CoverSlot = $slot
    $Worker.CoverMiss = ''
    return $true
}

# ------------------------------------------------------------------ casts (opt-in)
# With the user's cast switch on (cast.intent, set from Connections), the worker
# finds Cast devices on the home network, keeps a read-only Cast channel to
# them and follows a YouTube cast on the same snapshot Media's card reads. It
# acts only on the device that matches the paired TV's name, or else the single
# device running YouTube; with two or more it shows a state and follows none.
# The cast app is asked for its screen id once per cast session (the cast key
# may differ per cast); its token is asked of YouTube only for the first command.
# Play, pause and next are sent once each on a Lounge session bound for that
# command and left at once, the route tried live in stage 1. No up next.

# Discovery when nothing was found: waits 30 s, 60 s, ... up to 5 min. A
# device that keeps failing is dropped after three tries in a row.
$script:CastDiscoverBackoff = @(30, 60, 120, 300)
$script:CastRediscoverMs = 900000
$script:CastLinkBackoff = @(5, 15, 60)
$script:CastReceiverAskMs = 20000
$script:CastMediaAskMs = 5000
# A cast is shown only once its screen id was compared with the paired TV's
# (an answer, or no answer within this long).
$script:CastScreenWaitMs = 5000
$script:CastStatusMs = 60000
$script:CastDeviceLimit = 4

function New-TvCastFollower {
    return [pscustomobject]@{
        Enabled = $false; CheckAt = 0L; Discovery = $null; NextDiscoverMs = 0L; DiscoverFailures = 0; RediscoverAtMs = 0L
        Devices = [Collections.Generic.List[object]]::new()
        Followed = $null; App = $null; Picture = (New-CastPicture); MediaAskAt = 0L
        ScreenAskedAt = 0L; ScreenChecked = $false; IsTvApp = $false; Key = $null
        Status = 'off'; StatusAt = 0L; StatusPublished = ''
    }
}

function Test-TvCastShown {
    # Whether the snapshot shows a followed cast rather than the TV's own app.
    param([object]$Worker)
    $cast = $Worker.Cast
    return ($cast.Enabled -and $null -ne $cast.Followed -and $cast.ScreenChecked -and -not $cast.IsTvApp -and $cast.Picture.Loaded)
}

function Publish-TvCastSnapshot {
    param([object]$Worker, [long]$NowMs)
    $now = [long][Math]::Floor($NowMs / 1000)
    $picture = $Worker.Cast.Picture
    $key = 'cast|' + $picture.VideoId
    if ($key -cne $Worker.RowsKey) {
        $Worker.Observed = [Math]::Max($now, $Worker.Observed + 1)
        $Worker.RowsKey = $key
    }
    $title = if ($picture.Title) { $picture.Title } else { Get-TvCachedTitle $Worker $picture.VideoId }
    $channel = if ($picture.Subtitle) { $picture.Subtitle } else { Get-TvCachedChannel $Worker $picture.VideoId }
    $cover = if ($picture.VideoId -and $Worker.CoverVideo -ceq $picture.VideoId) { $Worker.CoverSlot } else { 0 }
    $snapshot = New-TvSnapshot -State ready -Observed $Worker.Observed -ValidUntil ([Math]::Max($now, $Worker.Observed) + $script:ValidSeconds) -Play (Get-TvPlayName $picture.State) `
        -PositionMs (Get-TvPositionMs $picture $NowMs) -PositionAtMs $NowMs -DurationMs $picture.DurationMs -UpNext unknown -List none -Total 0 `
        -Notice $Worker.Notice -CurrentTitle $title -CurrentChannel $channel -Cover $cover -Source cast
    Publish-TvSnapshot $Worker.Root $snapshot
    $Worker.PublishedAt = $NowMs
    $Worker.Notice = ''
    $picture.Changed = $false
    $Worker.Player.Changed = $false
}

function Save-TvCastKeyGuarded {
    # Saves the cast key only while casts are on, checked under the control lock
    # that CastOff, CastForget and Forget hold while they remove it: once Forget
    # has run, no key is written again. Returns whether it saved.
    param([string]$Root, [object]$Key)
    $control = New-TvControlMutex $Root
    $owned = $false
    try {
        $owned = Wait-TvMutex $control 2000
        if (-not $owned -or -not (Test-TvCastIntent $Root)) { return $false }
        Save-TvCastKey $Root $Key
        return $true
    } finally {
        if ($owned) { $control.ReleaseMutex() }
        $control.Dispose()
    }
}

function Get-TvCastWait { param([int[]]$Steps, [int]$Failures); return [long]$Steps[[Math]::Min([Math]::Max($Failures, 1), $Steps.Count) - 1] * 1000 }

function Stop-TvCastFollow {
    # Stops following (the cast ended, moved or became ambiguous). The channel
    # to the device stays open; nothing of the old cast is shown.
    param([object]$Worker)
    $cast = $Worker.Cast
    if ($null -eq $cast.Followed) { return }
    $cast.Followed = $null; $cast.App = $null; $cast.Picture = New-CastPicture
    $cast.ScreenChecked = $false; $cast.IsTvApp = $false; $cast.ScreenAskedAt = 0L
    $Worker.RowsKey = $null
    Write-TvWorkerLog $Worker 'cast: no longer followed'
}

function Reset-TvCast {
    # The switch went off (or Forget): every channel closed, the key dropped
    # from memory, nothing of a cast kept.
    param([object]$Worker)
    $cast = $Worker.Cast
    Stop-TvCastFollow $Worker
    Stop-CastDiscovery $cast.Discovery
    foreach ($entry in $cast.Devices) { Close-CastLink $entry.Link }
    $fresh = New-TvCastFollower
    foreach ($name in @('Devices', 'Discovery', 'NextDiscoverMs', 'DiscoverFailures', 'RediscoverAtMs', 'Key', 'Picture')) { $cast.$name = $fresh.$name }
    $cast.Enabled = $false
}

function Set-TvCastDevices {
    # The devices one discovery found: known ones keep their channel; new ones
    # are added, at most four.
    param([object]$Worker, [object[]]$Found)
    $cast = $Worker.Cast
    $now = Get-TvUnixMs
    foreach ($device in $Found) {
        if ($cast.Devices.Count -ge $script:CastDeviceLimit) { break }
        $known = @($cast.Devices | Where-Object { $_.Device.Address -ceq $device.Address -and $_.Device.Port -eq $device.Port })
        if ($known.Count) { $known[0].Device = $device; continue }
        $cast.Devices.Add([pscustomobject]@{ Device = $device; Link = $null; Apps = [object[]]@(); NextTryMs = 0L; Failures = 0; AskedAt = 0L })
    }
    if ($Found.Count -eq 0 -and $cast.Devices.Count -eq 0) {
        $cast.DiscoverFailures = [Math]::Min($cast.DiscoverFailures + 1, 50)
        $cast.NextDiscoverMs = $now + (Get-TvCastWait $script:CastDiscoverBackoff $cast.DiscoverFailures)
    } else {
        # Reset only by a channel that opens (Step-TvCast): a device found but
        # refusing keeps the wait growing.
        $cast.NextDiscoverMs = $now + (Get-TvCastWait $script:CastDiscoverBackoff ([Math]::Max($cast.DiscoverFailures, 1)))
    }
    $cast.RediscoverAtMs = $now + $script:CastRediscoverMs
    Write-TvWorkerLog $Worker ('cast discovery: devices=' + @($Found).Count + ' kept=' + $cast.Devices.Count)
}

function Get-TvCastCandidates {
    # The paired TV, when one device carries its name; otherwise every device.
    param([object]$Worker)
    $cast = $Worker.Cast
    $name = if ($null -ne $Worker.Pairing) { ([string]$Worker.Pairing.Name).Trim() } else { '' }
    if ($name) {
        $named = @($cast.Devices | Where-Object { $_.Device.Name -and [string]::Equals($_.Device.Name.Trim(), $name, [StringComparison]::OrdinalIgnoreCase) })
        if ($named.Count -eq 1) { return ,[object[]]$named }
    }
    return ,[object[]]@($cast.Devices)
}

function Receive-TvCastMessage {
    param([object]$Worker, [object]$Entry, [object]$Message)
    $cast = $Worker.Cast
    $body = $Message.Body
    if ($body['type'] -ceq 'RECEIVER_STATUS') {
        $Entry.Apps = Get-CastApps $body
        return
    }
    if ($null -eq $cast.Followed -or $cast.Followed -ne $Entry -or $null -eq $cast.App -or $Message.Source -cne $cast.App.TransportId) { return }
    if ($body['type'] -ceq 'MEDIA_STATUS') {
        $was = Get-TvPlayName $cast.Picture.State
        Merge-CastMediaStatus $cast.Picture $body
        if ((Get-TvPlayName $cast.Picture.State) -cne $was) { Write-TvWorkerLog $Worker ('cast media: state=' + (Get-TvPlayName $cast.Picture.State) + ' loaded=' + $cast.Picture.Loaded) }
        return
    }
    if ($body['type'] -ceq 'mdxSessionStatus') {
        $screen = Get-CastScreenId $body
        $cast.ScreenChecked = $true
        if (-not $screen) { Write-TvWorkerLog $Worker 'cast key: no screen id in the answer'; return }
        # The TV's own app answers with the screen paired by code: not a cast.
        $cast.IsTvApp = ($null -ne $Worker.Pairing -and $screen -ceq $Worker.Pairing.ScreenId)
        if ($cast.IsTvApp) { Write-TvWorkerLog $Worker 'cast key: same screen as the TV pairing, left to it'; return }
        if ($null -eq $cast.Key) { $cast.Key = Read-TvCastKey $Worker.Root }
        $same = $null -ne $cast.Key -and $cast.Key.ScreenId -ceq $screen
        if (-not $same) {
            $cast.Key = New-TvCastKey -ScreenId $screen
            # Never stored once Forget ran (the switch is checked under its lock).
            if (-not (Save-TvCastKeyGuarded $Worker.Root $cast.Key)) { $cast.Key = $null; return }
        }
        Write-TvWorkerLog $Worker ('cast key: answered, same as stored=' + $same.ToString().ToLowerInvariant())
    }
}

function Step-TvCast {
    # One pass of the cast follower. Never waits: channels are read with no
    # wait (the TV side's step does the waiting). Returns whether the snapshot
    # should be published.
    param([object]$Worker)
    $cast = $Worker.Cast
    $now = Get-TvUnixMs
    $shownBefore = Test-TvCastShown $Worker
    if ($now -ge $cast.CheckAt) {
        $cast.CheckAt = $now + 2000
        $want = Test-TvCastIntent $Worker.Root
        if ($want -and -not $cast.Enabled) { $cast.Enabled = $true; $cast.NextDiscoverMs = 0L; Write-TvWorkerLog $Worker 'cast: switched on' }
        elseif (-not $want -and $cast.Enabled) { Reset-TvCast $Worker; Write-TvWorkerLog $Worker 'cast: switched off' }
    }
    if (-not $cast.Enabled) {
        $cast.Status = 'off'
        Publish-TvCastState $Worker $now
        return ($shownBefore -ne (Test-TvCastShown $Worker))
    }
    # Discovery: gentle, and only while there is something to find.
    if ($null -ne $cast.Discovery) {
        $found = Step-CastDiscovery $cast.Discovery
        if ($null -ne $found) { $cast.Discovery = $null; Set-TvCastDevices $Worker $found }
    } elseif (($cast.Devices.Count -eq 0 -and $now -ge $cast.NextDiscoverMs) -or ($null -eq $cast.Followed -and $cast.RediscoverAtMs -gt 0 -and $now -ge $cast.RediscoverAtMs)) {
        $cast.RediscoverAtMs = 0L
        $cast.Discovery = Start-CastDiscovery
    }
    $candidates = Get-TvCastCandidates $Worker
    foreach ($entry in @($cast.Devices)) {
        if ($candidates -notcontains $entry) {
            if ($null -ne $entry.Link) { Close-CastLink $entry.Link; $entry.Link = $null; $entry.Apps = [object[]]@() }
            continue
        }
        if ($null -eq $entry.Link) {
            if ($now -lt $entry.NextTryMs) { continue }
            try {
                $entry.Link = Open-CastLink $entry.Device.Address $entry.Device.Port
                Send-CastJson $entry.Link 'receiver-0' 'urn:x-cast:com.google.cast.receiver' @{ type = 'GET_STATUS' }
                $entry.AskedAt = Get-TvUnixMs
                $cast.DiscoverFailures = 0
                Write-TvWorkerLog $Worker 'cast channel: open'
            } catch {
                $entry.Link = $null
                $entry.Failures++
                Write-TvWorkerLog $Worker ('cast channel: failed, tries=' + $entry.Failures)
                if ($entry.Failures -ge 3) {
                    $null = $cast.Devices.Remove($entry)
                    $cast.DiscoverFailures = [Math]::Min($cast.DiscoverFailures + 1, 50)
                    $cast.NextDiscoverMs = $now + (Get-TvCastWait $script:CastDiscoverBackoff $cast.DiscoverFailures)
                }
                else { $entry.NextTryMs = $now + (Get-TvCastWait $script:CastLinkBackoff $entry.Failures) }
                continue
            }
        }
        $step = Step-CastLink $entry.Link 0
        foreach ($message in $step.Messages) { Receive-TvCastMessage $Worker $entry $message }
        if ($step.Ended) {
            Close-CastLink $entry.Link
            $entry.Link = $null; $entry.Apps = [object[]]@()
            $entry.Failures++
            $entry.NextTryMs = $now + (Get-TvCastWait $script:CastLinkBackoff $entry.Failures)
            if ($cast.Followed -eq $entry) { Stop-TvCastFollow $Worker }
            Write-TvWorkerLog $Worker ('cast channel: ended ' + $step.Kind)
            continue
        }
        if ($step.Messages.Count) { $entry.Failures = 0 }
        if ($cast.Followed -ne $entry -and $now - $entry.AskedAt -ge $script:CastReceiverAskMs) {
            try { Send-CastJson $entry.Link 'receiver-0' 'urn:x-cast:com.google.cast.receiver' @{ type = 'GET_STATUS' }; $entry.AskedAt = $now } catch {}
        }
    }
    # Which cast to follow: the single candidate running YouTube.
    $running = @($candidates | Where-Object { $null -ne $_.Link -and $null -ne (Select-CastYouTube $_.Apps) })
    if ($running.Count -eq 1) {
        $entry = $running[0]
        $app = Select-CastYouTube $entry.Apps
        if ($cast.Followed -ne $entry -or $null -eq $cast.App -or $cast.App.SessionId -cne $app.SessionId -or $cast.App.TransportId -cne $app.TransportId) {
            Stop-TvCastFollow $Worker
            $cast.Followed = $entry; $cast.App = $app
            try {
                Send-CastJson $entry.Link $app.TransportId 'urn:x-cast:com.google.cast.tp.connection' @{ type = 'CONNECT' }
                Send-CastJson $entry.Link $app.TransportId 'urn:x-cast:com.google.cast.media' @{ type = 'GET_STATUS' }
                # A new cast session: its key may differ from the last one.
                Send-CastJson $entry.Link $app.TransportId 'urn:x-cast:com.google.youtube.mdx' @{ type = 'getMdxSessionStatus' }
            } catch {}
            $cast.MediaAskAt = $now + $script:CastMediaAskMs
            $cast.ScreenAskedAt = $now
            Write-TvWorkerLog $Worker 'cast: following a YouTube cast'
        } elseif ($now -ge $cast.MediaAskAt) {
            try { Send-CastJson $entry.Link $app.TransportId 'urn:x-cast:com.google.cast.media' @{ type = 'GET_STATUS' } } catch {}
            $cast.MediaAskAt = $now + $script:CastMediaAskMs
        }
        if (-not $cast.ScreenChecked -and $now - $cast.ScreenAskedAt -ge $script:CastScreenWaitMs) { $cast.ScreenChecked = $true; Write-TvWorkerLog $Worker 'cast key: no answer' }
        $cast.Status = if ($cast.IsTvApp) { 'tv_app' } elseif ($cast.ScreenChecked -and $null -eq $cast.Key) { 'no_key' } else { 'following' }
    } else {
        Stop-TvCastFollow $Worker
        $cast.Status = if ($running.Count -ge 2) { 'several' }
            elseif ($cast.Devices.Count -eq 0) { if ($null -ne $cast.Discovery -or $cast.DiscoverFailures -eq 0) { 'searching' } else { 'no_device' } }
            elseif (@($candidates | Where-Object { $null -ne $_.Link }).Count -eq 0) { 'error' }
            else { 'waiting' }
    }
    Publish-TvCastState $Worker $now
    $shown = Test-TvCastShown $Worker
    return ($shownBefore -ne $shown -or ($shown -and $cast.Picture.Changed))
}

function Publish-TvCastState {
    # cast.status for Connections: a fixed word, rewritten on change and at
    # least every minute while the worker runs.
    param([object]$Worker, [long]$NowMs)
    $cast = $Worker.Cast
    if ($cast.Status -ceq 'off') {
        # Off writes nothing: a stale state is removed once, so nothing
        # cast-related reappears after Forget.
        if ($cast.StatusPublished -cne 'off') { try { $null = Remove-TvFile $Worker.Root 'cast.status' } catch {}; $cast.StatusPublished = 'off' }
        return
    }
    if ($cast.Status -ceq $cast.StatusPublished -and $NowMs - $cast.StatusAt -lt $script:CastStatusMs) { return }
    $valid = [long][Math]::Floor($NowMs / 1000) + $script:ValidSeconds
    try { Publish-TvCastStatus $Worker.Root $cast.Status $valid } catch { return }
    $cast.StatusPublished = $cast.Status
    $cast.StatusAt = $NowMs
}

function Invoke-TvCastAction {
    # A card command while the snapshot shows a cast: sent once on a Lounge
    # session bound with the cast key for it, then left. A refused key is asked
    # for again from the cast app; the command is not resent.
    param([object]$Worker, [object]$Request)
    $cast = $Worker.Cast
    $entry = $cast.Followed
    if ($Request.Kind -ceq 'refresh') {
        try { Send-CastJson $entry.Link $cast.App.TransportId 'urn:x-cast:com.google.cast.media' @{ type = 'GET_STATUS' } } catch {}
        return ''
    }
    if ($Request.Kind -ceq 'jump') { return 'queue_changed' }
    if ($null -eq $cast.Key) { $cast.Key = Read-TvCastKey $Worker.Root }
    if ($null -eq $cast.Key) { $cast.Status = 'no_key'; Write-TvWorkerLog $Worker ('cast command ' + $Request.Kind + ': no key'); return 'failed' }
    if (-not $cast.Key.LoungeToken) {
        $token = Invoke-TvHttp (New-TvTokenRequest $cast.Key.ScreenId) -TimeoutSeconds 10
        $value = ''
        if ($token.Status -eq 200) { try { $value = ConvertFrom-TvTokenAnswer $token.Text } catch {} }
        Write-TvWorkerLog $Worker ('cast key: token http=' + $token.Status + ' usable=' + $(if ($value) { 'yes' } else { 'no' }))
        if (-not $value) { return $(if ($token.Status -eq 0) { 'not_connected' } else { 'failed' }) }
        $cast.Key.LoungeToken = $value
        if (-not (Save-TvCastKeyGuarded $Worker.Root $cast.Key)) { $cast.Key = $null; return 'failed' }
    }
    $connected = Connect-TvScreen $Worker.Root $cast.Key -Cast
    if ($null -eq $connected.Session) {
        Write-TvWorkerLog $Worker ('cast command ' + $Request.Kind + ': bind ' + $connected.Kind + ' http=' + $connected.Status)
        if ($connected.Kind -cin @('pair_again', 'refused')) {
            # The cast's screen may have changed: ask the cast app again.
            $cast.Key = $null
            try { Send-CastJson $entry.Link $cast.App.TransportId 'urn:x-cast:com.google.youtube.mdx' @{ type = 'getMdxSessionStatus' } } catch {}
        }
        return $(if ($connected.Kind -ceq 'offline') { 'not_connected' } else { 'failed' })
    }
    $answer = Invoke-TvHttp (New-TvCommandRequest $connected.Session $Request.Kind) -TimeoutSeconds 10
    $null = Invoke-TvHttp (New-TvLeaveRequest $connected.Session) -TimeoutSeconds 5
    Write-TvWorkerLog $Worker ('cast command ' + $Request.Kind + ' http=' + $answer.Status)
    # Read the result from the TV soon.
    $cast.MediaAskAt = (Get-TvUnixMs) + 1000
    if ($answer.Status -ne 200) { return 'failed' }
    return 'sent'
}

function Invoke-TvAction {
    # Sends one request's command on the listening session, once. Returns the
    # notice to show. A jump names a row of a snapshot this worker published; the
    # video it showed is looked up in the TV's current list.
    param([object]$Worker, [object]$Request)
    if ($null -eq $Worker.Session -or $null -eq $Worker.Poll) { return 'not_connected' }
    $name = $Request.Kind
    $fields = [ordered]@{}
    if ($name -ceq 'refresh') { $name = 'getNowPlaying' }
    elseif ($name -ceq 'jump') {
        $view = @($Worker.Views | Where-Object { $_.Observed -eq $Request.Observed }) | Select-Object -Last 1
        if ($null -eq $view -or $Request.Row -gt $view.Ids.Count) { Write-TvWorkerLog $Worker 'request jump: not a shown queue'; return 'queue_changed' }
        $target = $view.Ids[$Request.Row - 1]
        $index = [Array]::IndexOf($Worker.Player.Ids, $target)
        if ($index -lt 0) { Write-TvWorkerLog $Worker 'request jump: no longer listed'; return 'queue_changed' }
        $name = 'setPlaylist'
        $fields['videoId'] = $target
        $fields['currentTime'] = '0'
        $fields['currentIndex'] = [string]$index
        # The playing list by its id when known (a Mix keeps going from there),
        # otherwise the list itself.
        if ($Worker.Player.ListId) { $fields['listId'] = $Worker.Player.ListId }
        else { $fields['videoIds'] = $Worker.Player.Ids -join ',' }
    }
    $answer = Invoke-TvHttp (New-TvCommandRequest $Worker.Session $name $fields) -TimeoutSeconds 10
    $detail = if ($Request.Kind -ceq 'jump') { ' row=' + $Request.Row + ' index=' + $fields['currentIndex'] + ' by=' + $(if ($fields.Contains('listId')) { 'list' } else { 'ids' }) } else { '' }
    Write-TvWorkerLog $Worker ('command ' + $name + $detail + ' http=' + $answer.Status)
    if ($answer.Status -ne 200) { return 'failed' }
    if ($name -ceq 'getNowPlaying') { return '' }
    return 'sent'
}

function Close-TvWorkerSession {
    param([object]$Worker, [string]$State)
    Close-TvPoll $Worker.Poll
    $Worker.Poll = $null
    $Worker.Session = $null
    $Worker.State = $State
}

function Step-TvWorker {
    # One pass: connect when due, read what arrived, take a request, look up a
    # title, and publish when anything changed. Waits at most about $StepMs.
    param([object]$Worker, [int]$StepMs = 250, [object]$Owner = $null)
    $before = Get-TvWorkerState $Worker
    $publish = Step-TvCast $Worker
    if ($null -eq $Worker.Pairing -or $Worker.TvIdle) {
        # Casts only: no TV paired by code (or its pairing was refused).
        $request = Read-TvRequest $Worker.Root
        if ($null -ne $request) { $Worker.Notice = Invoke-TvRoutedAction $Worker $request; $publish = $true }
        if (Update-TvLookups $Worker) { $publish = $true }
        if ($publish -or (Get-TvWorkerState $Worker) -cne $before -or (Get-TvUnixMs) - $Worker.PublishedAt -ge $script:HeartbeatMs) { Publish-TvWorker $Worker }
        $null = Wait-MediaOwnerExit $Owner $StepMs
        return
    }
    if ($null -eq $Worker.Session) {
        $request = Read-TvRequest $Worker.Root
        if ($null -ne $request) { $Worker.Notice = Invoke-TvRoutedAction $Worker $request; $publish = $true }
        if ((Get-TvUnixMs) -lt $Worker.NextAttemptMs) {
            if (Update-TvLookups $Worker) { $publish = $true }
            if ($publish -or (Get-TvUnixMs) - $Worker.PublishedAt -ge $script:HeartbeatMs) { Publish-TvWorker $Worker }
            $null = Wait-MediaOwnerExit $Owner $StepMs
            return
        }
        $connected = Connect-TvScreen $Worker.Root $Worker.Pairing
        if ($null -eq $connected.Session) {
            $Worker.Failures = [Math]::Min($Worker.Failures + 1, 50)
            Write-TvWorkerLog $Worker ('bind failed: ' + $connected.Kind + ' http=' + $connected.Status + ' failures=' + $Worker.Failures)
            if ($connected.Kind -ceq 'pair_again') {
                $Worker.State = 'pair_again'
                # With casts on the worker keeps following casts; the TV side rests.
                if ($Worker.Cast.Enabled) { $Worker.TvIdle = $true } else { $Worker.Fatal = $true }
                Publish-TvWorker $Worker
                return
            }
            $Worker.State = if ($connected.Kind -ceq 'offline') { 'offline' } else { 'error' }
            $Worker.NextAttemptMs = (Get-TvUnixMs) + (Get-TvBackoffMs $Worker.Failures)
            Publish-TvWorker $Worker
            return
        }
        # A fresh session starts from a fresh picture: nothing from the old one is
        # shown as if it were still true.
        $Worker.Session = $connected.Session
        $Worker.Player = New-TvPlayer
        $Worker.QuickEnds = 0
        foreach ($item in $connected.Events) { $was = $Worker.Player.VideoId; Merge-TvEvent $Worker.Player $item; Write-TvWorkerLog $Worker (Get-TvEventSummary $item $Worker.Player $was) }
        Write-TvWorkerLog $Worker ('bound: events=' + @($connected.Events).Count + ' screen=' + $(if ($null -eq $Worker.Player.Screen) { 'unknown' } else { [string]$Worker.Player.Screen }))
        try { $Worker.Poll = Open-TvPoll $Worker.Session }
        catch { Close-TvWorkerSession $Worker 'offline'; $Worker.Failures++; $Worker.NextAttemptMs = (Get-TvUnixMs) + (Get-TvBackoffMs $Worker.Failures); Publish-TvWorker $Worker; return }
        # Asks what is playing; changes nothing on the TV.
        $null = Invoke-TvAction $Worker ([pscustomobject]@{ Kind = 'refresh'; Row = 0; Observed = 0 })
        Publish-TvWorker $Worker
        return
    }

    $step = Step-TvPoll $Worker.Poll $StepMs
    foreach ($item in $step.Events) {
        Update-TvSession $Worker.Session $item
        $was = $Worker.Player.VideoId
        Merge-TvEvent $Worker.Player $item
        if ($item.Name -cnotin @('noop', 'c', 'S')) { $Worker.Failures = 0 }
        Write-TvWorkerLog $Worker (Get-TvEventSummary $item $Worker.Player $was)
    }
    if ($Worker.Player.Gone) {
        # The screen left (TV app closed, TV off, or a cast took over): rejoin
        # later, never in a tight loop.
        $Worker.Player.Gone = $false
        Close-TvWorkerSession $Worker 'no_screen'
        $Worker.Failures = [Math]::Min($Worker.Failures + 1, 50)
        $Worker.NextAttemptMs = (Get-TvUnixMs) + [Math]::Max(10000, (Get-TvBackoffMs $Worker.Failures))
        Write-TvWorkerLog $Worker ('screen left; rejoin in ' + [int](($Worker.NextAttemptMs - (Get-TvUnixMs)) / 1000) + ' s')
        Publish-TvWorker $Worker
        return
    }
    if ($step.Ended) {
        $openedAt = $Worker.Poll.OpenedAt
        Close-TvPoll $Worker.Poll
        $Worker.Poll = $null
        Write-TvWorkerLog $Worker ('poll ended: ' + $step.Kind + ' http=' + $step.Status)
        if ($step.Kind -cin @('ended', 'quiet')) {
            # A normal end: listen again at once, unless it keeps ending at once.
            if ((Get-TvUnixMs) - $openedAt -lt 2000) { $Worker.QuickEnds++ } else { $Worker.QuickEnds = 0 }
            if ($Worker.QuickEnds -lt 3) {
                try { $Worker.Poll = Open-TvPoll $Worker.Session } catch { $Worker.Poll = $null }
            }
            if ($null -eq $Worker.Poll) {
                Close-TvWorkerSession $Worker 'error'
                $Worker.Failures = [Math]::Min($Worker.Failures + 1, 50)
                $Worker.NextAttemptMs = (Get-TvUnixMs) + (Get-TvBackoffMs $Worker.Failures)
            }
        } elseif ($step.Kind -ceq 'http' -and $step.Status -in @(400, 401, 403, 404, 410)) {
            # The session is over (expired, or its token refused): bind again now
            # the first time, after a wait when it repeats.
            Close-TvWorkerSession $Worker 'connecting'
            $Worker.NextAttemptMs = if ($Worker.Failures -gt 0) { (Get-TvUnixMs) + (Get-TvBackoffMs $Worker.Failures) } else { 0L }
            $Worker.Failures = [Math]::Min($Worker.Failures + 1, 50)
        } else {
            Close-TvWorkerSession $Worker $(if ($step.Kind -ceq 'offline') { 'offline' } else { 'error' })
            $Worker.Failures = [Math]::Min($Worker.Failures + 1, 50)
            $Worker.NextAttemptMs = (Get-TvUnixMs) + (Get-TvBackoffMs $Worker.Failures)
        }
        $publish = $true
    }
    $request = Read-TvRequest $Worker.Root
    if ($null -ne $request) {
        $Worker.Notice = Invoke-TvRoutedAction $Worker $request
        $publish = $true
    }
    if (Update-TvLookups $Worker) { $publish = $true }
    if ($publish -or $Worker.Player.Changed -or (Get-TvWorkerState $Worker) -cne $before -or (Get-TvUnixMs) - $Worker.PublishedAt -ge $script:HeartbeatMs) { Publish-TvWorker $Worker }
}

function Invoke-TvRun {
    # The worker. -UntilMs is for tests: it ends the run like Stop does.
    param([string]$Root, [string]$Launch = '', [string]$Lease = '', [switch]$WithDiagnostics, [long]$UntilMs = 0, [int]$StepMs = 250, [string]$Stamp = '', [switch]$Takeover, [int]$TakeoverMs = 120000)
    # Taken as the run starts: the code this process loaded.
    if (-not $Stamp) { $Stamp = Get-TvCurrentStamp }
    $stamped = $false
    $owner = Open-MediaOwner $Lease
    if ($owner -is [bool]) { return }
    $control = New-TvControlMutex $Root
    $controlOwned = $false
    $mutex = New-TvRunMutex $Root
    $owned = $false
    $worker = $null
    $ownerGone = $false
    try {
        if ($Takeover) {
            # After an update: this new worker asks the one from older code to
            # stop and waits for it itself, so a cut-off Resume can never leave a
            # stop barrier behind. A user's Stop meanwhile (intent off) stays.
            Request-TvStop $Root
            $taken = $false
            $deadline = (Get-TvUnixMs) + $TakeoverMs
            while (-not $taken -and (Get-TvUnixMs) -lt $deadline) {
                $taken = Wait-TvMutex $mutex 500
                if (-not $taken -and $null -ne $owner -and $owner.HasExited) { break }
            }
            if ($taken) { $mutex.ReleaseMutex() }
            $controlOwned = Wait-TvMutex $control 10000
            if (Test-TvIntent $Root) { Clear-TvStop $Root }
            if (-not $taken -or -not $controlOwned) { return }
        } else {
            $controlOwned = Wait-TvMutex $control 10000
        }
        if (-not $controlOwned) { return }
        $owned = Wait-TvMutex $mutex 0
        if (-not $owned) { return }
        # A child that starts after Stop or Forget, or after a newer launch, does nothing.
        if (Test-TvStop $Root) { return }
        if ($Launch -and -not (Test-TvLaunchId $Root $Launch)) { return }
        $control.ReleaseMutex(); $controlOwned = $false
        # The code this worker runs, for Resume to tell it from a later update.
        try { Set-TvStampFile $Root 'worker.stamp' $Stamp; $stamped = $true } catch {}
        $pairing = Read-TvPairing $Root
        # No TV paired by code: the worker runs only for casts, if they are on.
        if ($null -eq $pairing -and -not (Test-TvCastIntent $Root)) { Publish-TvSnapshot $Root (New-TvSnapshot -State not_paired); return }
        $worker = New-TvWorker $Root $pairing ([bool]$WithDiagnostics)
        Write-TvWorkerLog $worker 'worker started'
        # A request left from before this worker started is never acted on.
        $null = Read-TvRequest $Root -Now 0
        Publish-TvWorker $worker
        while (-not (Test-TvStop $Root)) {
            if ($UntilMs -gt 0 -and (Get-TvUnixMs) -ge $UntilMs) { break }
            if ($null -ne $owner -and $owner.HasExited) { $ownerGone = $true; break }
            Step-TvWorker $worker $StepMs $owner
            if ($worker.Fatal) { break }
        }
    } finally {
        if ($null -ne $worker) {
            # Casts: every channel closed and the key dropped from memory.
            Reset-TvCast $worker
            if ($null -ne $worker.Session) {
                # Leave politely; a failure here changes nothing.
                $null = Invoke-TvHttp (New-TvLeaveRequest $worker.Session) -TimeoutSeconds 5
            }
            Close-TvPoll $worker.Poll
            Write-TvWorkerLog $worker ('worker ended' + $(if ($ownerGone) { ': Rainmeter exited' } else { '' }))
            # When Rainmeter is gone the snapshot is left as is: intent is kept and
            # the next skin load resumes. A fatal state stays published.
            if (-not $ownerGone -and -not $worker.Fatal) {
                $end = if ($null -eq $worker.Pairing) { 'not_paired' } else { 'stopped' }
                try { Publish-TvSnapshot $Root (New-TvSnapshot -State $end) } catch {}
            }
            # A clean end leaves no picture of what played.
            if (-not $ownerGone) { Remove-TvCovers $Root }
        }
        if ($stamped) { try { $null = Remove-TvFile $Root 'worker.stamp' } catch {} }
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
        if ($owner) { $owner.Dispose() }
    }
}

# ------------------------------------------------------------------ lifecycle

function Start-TvBackground {
    param([string]$Root, [bool]$WithDiagnostics, [bool]$Takeover = $false)
    $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($script:ProviderPath.Contains('"') -or $Root.Contains('"')) { throw 'Unsupported helper path.' }
    $launch = New-TvLaunchId $Root
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script:ProviderPath + '" -Command Run -Quiet -LaunchId ' + $launch + ' -DataRoot "' + $Root + '"'
    if ($WithDiagnostics) { $arguments += ' -Diagnostics' }
    if ($Takeover) { $arguments += ' -Takeover' }
    # Bound to the Rainmeter that asked for it (none from a shell), and started
    # outside the skin folder so it can never hold the skin open.
    $lease = Get-MediaOwnerLease
    if ($lease) { $arguments += ' -OwnerLease ' + $lease }
    $null = Start-Process -FilePath $hostPath -ArgumentList $arguments -WorkingDirectory $Root -WindowStyle Hidden -PassThru
}

function Stop-TvWorker {
    # Leaves a stop barrier and waits for a running worker to end. Returns
    # whether it did. Caller holds the control lock.
    param([string]$Root)
    Request-TvStop $Root
    Set-TvIntent $Root $false
    $mutex = New-TvRunMutex $Root
    try {
        if (-not (Wait-TvMutex $mutex 20000)) { return $false }
        $mutex.ReleaseMutex()
        return $true
    } finally { $mutex.Dispose() }
}

function Get-TvCurrentStamp { return (Get-TvCodeStamp $script:CodeFiles) }

function Restart-TvOlderWorker {
    # Resume only, caller holds the control lock and has checked the user's
    # intent and stop barrier. A running worker whose stamp differs from the code
    # on disk (or that has none: it predates stamps) is replaced by a new worker
    # started with -Takeover, which stops the old one and waits for it itself:
    # Resume returns at once, well inside its host's timeout, and nothing is left
    # half done if Resume is cut off. Once per code stamp: if the new worker still
    # does not show the new stamp, later loads leave it alone.
    param([string]$Root)
    $current = Get-TvCurrentStamp
    if ((Get-TvStampFile $Root 'worker.stamp') -ceq $current) { return $false }
    if ((Get-TvStampFile $Root 'upgrade.marker') -ceq $current) { return $false }
    Set-TvStampFile $Root 'upgrade.marker' $current
    Start-TvBackground $Root $false $true
    return $true
}

function Get-TvPairingCode {
    param([string]$Text)
    $digits = ($Text -replace '[\s-]', '')
    if ($digits -cnotmatch '\A[0-9]{6,20}\z') { throw 'Type the digits shown under Link with TV code.' }
    return $digits
}

function Show-TvStatus {
    # Counts and states only: no titles or ids reach the console.
    param([string]$Root)
    $fields = $null
    try { $fields = Read-TvSnapshotFields $Root } catch {}
    if ($null -eq $fields) { Write-Output 'No TV snapshot yet.'; return }
    $now = Get-TvUnixTime
    $titled = @($fields.Keys | Where-Object { $_ -cmatch '\Atitle[0-9]+\z' -and $fields[$_] }).Count
    Write-Output ('state={0} play={1} upnext={2} list={3} after={4} rows={5} titled={6} current_title={7} notice={8}' -f $fields['state'], $fields['play'], $fields['upnext'], $fields['list'], $fields['total'], $fields['count'], $titled, $(if ($fields['current_title']) { 'yes' } else { 'no' }), $fields['notice'])
    $observed = [long]$fields['observed']
    if ($observed -gt 0) { Write-Output ('observed={0} ({1} s ago)' -f $observed, ($now - $observed)) }
    if ([long]$fields['valid_until'] -gt 0 -and [long]$fields['valid_until'] -lt $now) { Write-Output 'The snapshot is out of date: the worker is not running.' }
    Write-Output ('worker running: ' + (Test-TvWorkerRunning $Root))
}

function Invoke-TvCommand {
    if ($Command -eq 'Help') { Show-TvHelp; return }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 to run TvProvider.ps1.' }
    if (-not $DataRoot) { $DataRoot = Get-TvDataRoot }
    if ($Command -in @('Send', 'Status', 'Resume')) {
        # Passive: no folder creation, ACL change, network or pairing read.
        $candidate = Resolve-TvPrivatePath $DataRoot
        if (-not [IO.Directory]::Exists($candidate)) { if ($Command -ne 'Resume' -and -not $Quiet) { Write-Output 'No TV is paired.' }; return }
        if ($Command -eq 'Status') { Show-TvStatus $candidate; return }
        if ($Command -eq 'Send') {
            if ((Test-TvStop $candidate) -or -not (Test-TvWorkerRunning $candidate)) { if (-not $Quiet) { Write-Output 'The TV worker is not running.' }; return }
            Write-TvRequest $candidate $Action -Row $Row -Observed $Observed
            return
        }
        if (-not (Test-TvIntent $candidate) -or (Test-TvStop $candidate) -or -not ((Test-TvPaired $candidate) -or (Test-TvCastIntent $candidate))) { return }
    }
    $DataRoot = Initialize-TvPrivateDirectory $DataRoot
    if ($Command -eq 'Run') {
        # Never keep the skin folder as the working directory.
        [Environment]::CurrentDirectory = $DataRoot
        Set-Location -LiteralPath $DataRoot
        Invoke-TvRun $DataRoot -Launch $LaunchId -Lease $OwnerLease -WithDiagnostics:$Diagnostics -Takeover:$Takeover
        return
    }
    $screen = $null
    if ($Command -eq 'Pair') {
        # The code is read and sent before any lock is taken: a slow answer must
        # not hold up Stop.
        $typed = $Code
        if (-not $typed) {
            if ($Quiet) { throw 'Pair needs -Code when quiet.' }
            Show-TvHelp
            $typed = Read-Host 'TV code'
        }
        $answer = Invoke-TvHttp (New-TvPairRequest (Get-TvPairingCode $typed))
        if ($answer.Status -ne 200) { throw ('pairing did not work (HTTP {0}). Get a fresh code on the TV and try again.' -f $answer.Status) }
        $screen = ConvertFrom-TvPairAnswer $answer.Text
    }
    $control = New-TvControlMutex $DataRoot
    $controlOwned = $false
    try {
        $controlOwned = Wait-TvMutex $control 10000
        if (-not $controlOwned) { throw 'Another TV worker action is still running.' }
        switch ($Command) {
            'Pair' {
                if (-not (Stop-TvWorker $DataRoot)) { throw 'The running TV worker did not stop.' }
                Save-TvPairing $DataRoot (New-TvPairing -ScreenId $screen.ScreenId -LoungeToken $screen.LoungeToken -Name $screen.Name)
                $screen = $null
                if (-not $Quiet) { Write-Output 'Paired with your TV.' }
                if ($NoStart) { Publish-TvSnapshot $DataRoot (New-TvSnapshot -State stopped); return }
                Set-TvIntent $DataRoot $true
                Clear-TvStop $DataRoot
                Publish-TvSnapshot $DataRoot (New-TvSnapshot -State connecting -ValidUntil ((Get-TvUnixTime) + 150))
                Start-TvBackground $DataRoot ([bool]$Diagnostics)
                if (-not $Quiet) { Write-Output 'The TV worker is starting in the background.' }
            }
            { $_ -in @('Start', 'Resume') } {
                if (-not (Test-TvPaired $DataRoot) -and -not (Test-TvCastIntent $DataRoot)) {
                    Publish-TvSnapshot $DataRoot (New-TvSnapshot -State not_paired)
                    if (-not $Quiet) { Write-Output 'No TV is paired. Run -Command Pair first.' }
                    return
                }
                if ($Command -eq 'Resume' -and (-not (Test-TvIntent $DataRoot) -or (Test-TvStop $DataRoot))) { return }
                if ($Command -eq 'Start') { Set-TvIntent $DataRoot $true }
                if (Test-TvWorkerRunning $DataRoot) {
                    # After an update, the worker still running is from the old code.
                    if ($Command -eq 'Resume') { $null = Restart-TvOlderWorker $DataRoot; return }
                    if (-not $Quiet) { Write-Output 'The TV worker is already running.' }
                    return
                }
                if ($Command -eq 'Start') { Clear-TvStop $DataRoot }
                Start-TvBackground $DataRoot ([bool]$Diagnostics)
                if (-not $Quiet) { Write-Output 'The TV worker is starting in the background.' }
            }
            'Stop' {
                if (-not (Stop-TvWorker $DataRoot)) { throw 'The TV worker is busy. Try Stop again.' }
                Remove-TvCovers $DataRoot
                if (Test-TvPaired $DataRoot) { Publish-TvSnapshot $DataRoot (New-TvSnapshot -State stopped) }
                else { Publish-TvSnapshot $DataRoot (New-TvSnapshot -State not_paired) }
                if (-not $Quiet) { Write-Output 'Stopped.' }
            }
            'Forget' {
                if (-not (Stop-TvWorker $DataRoot)) { throw 'The TV worker is busy. Try Forget again.' }
                foreach ($name in @('pairing.dpapi', 'tv.request', 'launch.id', 'events.log', 'events.old.log', 'tv.cover1.jpg', 'tv.cover2.jpg')) { $null = Remove-TvFile $DataRoot $name }
                # Forgetting the TV forgets its cast key too, and turns casts off.
                Remove-TvCastData $DataRoot
                Publish-TvSnapshot $DataRoot (New-TvSnapshot -State not_paired)
                if (-not $Quiet) { Write-Output 'The TV pairing and local TV data were removed. You can also remove Parallax under Linked devices in the TV''s YouTube settings.' }
            }
            'CastOn' {
                # The user's cast switch: the worker (started if needed) looks
                # for the TV on the home network and follows a YouTube cast.
                Set-TvCastIntent $DataRoot $true
                Set-TvIntent $DataRoot $true
                Publish-TvCastStatus $DataRoot searching ((Get-TvUnixTime) + 150)
                if (Test-TvWorkerRunning $DataRoot) { if (-not $Quiet) { Write-Output 'Casts are on.' }; return }
                Clear-TvStop $DataRoot
                if (-not (Test-TvPaired $DataRoot)) { Publish-TvSnapshot $DataRoot (New-TvSnapshot -State not_paired) }
                Start-TvBackground $DataRoot ([bool]$Diagnostics)
                if (-not $Quiet) { Write-Output 'Casts are on. The TV worker is starting in the background.' }
            }
            { $_ -in @('CastOff', 'CastForget') } {
                Set-TvCastIntent $DataRoot $false
                if (-not (Test-TvPaired $DataRoot)) {
                    # Casts were all the worker did: it stops.
                    if (-not (Stop-TvWorker $DataRoot)) { throw 'The TV worker is busy. Try again.' }
                    Remove-TvCovers $DataRoot
                    Publish-TvSnapshot $DataRoot (New-TvSnapshot -State not_paired)
                } elseif (Test-TvWorkerRunning $DataRoot) {
                    # The worker notices the switch within about 2 s and drops
                    # the cast and its key; Forget waits for that first.
                    $deadline = [DateTime]::UtcNow.AddSeconds(6)
                    while ([DateTime]::UtcNow -lt $deadline) {
                        $seen = Read-TvCastStatus $DataRoot
                        if ($null -eq $seen -or $seen.State -ceq 'off') { break }
                        Start-Sleep -Milliseconds 200
                    }
                }
                if ($Command -eq 'CastForget') { Remove-TvCastData $DataRoot; if (-not $Quiet) { Write-Output 'Casts are off and the cast key was removed.' } }
                else { $null = Remove-TvFile $DataRoot 'cast.status'; if (-not $Quiet) { Write-Output 'Casts are off.' } }
            }
        }
    } finally {
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
    }
}

# Dot-sourcing is test-only: it defines functions and reads nothing.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-TvCommand }
    catch {
        if (-not $Quiet) { Write-Output ('The TV worker could not finish: ' + $_.Exception.Message) }
        exit 1
    }
}
