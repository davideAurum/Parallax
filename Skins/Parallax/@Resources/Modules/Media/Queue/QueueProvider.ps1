# Optional Spotify queue helper. Windows PowerShell 5.1 / built-in .NET only.
# Imports are passive. Resume honors only the user's saved Start/Connect intent.
#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Help','Configure','Connect','Start','Resume','Run','Stop','Restart','Disconnect','Refresh','Play')][string]$Command = 'Help',
    # Play: the clicked row (1-20) and the observed time of the snapshot it was
    # read from, so the worker acts only on the queue the user actually saw.
    [ValidateRange(0,20)][int]$Position = 0,
    [ValidateRange(0,253402300000)][long]$Observed = 0,
    [string]$ClientId = '',
    [ValidateRange(30,150)][int]$PollSeconds = 30,
    [switch]$Once,
    [switch]$Quiet,
    [switch]$ResumeAfterQuota,
    [ValidatePattern('\A(?:[a-f0-9]{32})?\z')][string]$LaunchId = '',
    [string]$DataRoot = '',
    [ValidatePattern('\A(?:[1-9][0-9]{0,9}:[1-9][0-9]{0,18})?\z')][string]$OwnerLease = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'QueueAuth.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'QueueCore.psm1') -Force -DisableNameChecking
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProviderOwner.psm1') -Force -DisableNameChecking
$script:ProviderPath = $PSCommandPath
# Saved covers: at most this many, most recently used first (the queue's, and
# up to 50 playlists').
$script:CoverLimit = 120
# Covers fetched before the rows are published (what the drawer shows unscrolled),
# then per pass, for later rows and playlists, so a click or Stop never waits for all.
$script:FirstCovers = 5
$script:CoverBatch = 3
# A cover URL whose download failed is not tried again for this long, so a
# broken or unreachable image costs one attempt per five minutes, not one per read.
$script:CoverRetrySeconds = 300
$script:CoverRetryAt = @{}
# The playing context's songs (Get-QueueContextItems), and how many pages of
# them are read: 1,000 songs of a playlist, 500 of an album.
$script:ContextItems = $null
$script:ContextPageLimit = 10

function Show-QueueHelp {
    Write-Output @'
Parallax Spotify queue (read-only)
1. Open https://developer.spotify.com/dashboard and select your app.
2. Add redirect URI http://127.0.0.1/callback and save it.
3. Run this script with -Command Connect. Enter the public Client ID if asked.
4. Sign in and consent in Spotify's browser page. The queue helper starts after login.

Commands: Connect (sign in), Start (background), Resume (saved intent), Run, Stop, Restart,
          Disconnect (stop and remove local tokens/listening cache), Configure,
          Refresh (ask the running helper to read now), Play -Position n -Observed t
          (play queue row n on the running helper's player; needs the playback
          control permission, granted by signing in again with Connect).
Run accepts -Once, -PollSeconds 30..150 and -ResumeAfterQuota for an explicit retry
after resolving exhausted quota. Ordinary server Retry-After waits are retained.
No client secret is needed. Development apps require owner Premium and allowlisting.
Tokens and display cache stay in LocalAppData, outside skins. Skin-load Resume
continues an enabled helper without opening sign-in. Stop/Disconnect disable it.
Direct Run honors an earlier Stop; use Start or Restart to enable it again.
'@
}

function Get-QueueMutexName {
    param([string]$Root)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value + '|' + [IO.Path]::GetFullPath($Root).ToUpperInvariant()
        $suffix = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-','')
        return 'Local\Parallax.Spotify.Queue.' + $suffix
    } finally { $hash.Dispose() }
}

function New-QueueRunMutex { param([string]$Root); return [Threading.Mutex]::new($false, (Get-QueueMutexName $Root)) }
function New-QueueControlMutex { param([string]$Root); return [Threading.Mutex]::new($false, ((Get-QueueMutexName $Root) + '.Control')) }
function Wait-QueueMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds)
    try { return $Mutex.WaitOne($Milliseconds) } catch [Threading.AbandonedMutexException] { return $true }
}

function Get-QueueRuntimeFile {
    param([string]$Root, [ValidateSet('stop.request','queue.retry.json','queue.snapshot','enabled.intent','launch.id','action.request','playlists.snapshot')][string]$Name)
    $path = Join-Path ([IO.Path]::GetFullPath($Root)) $Name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Queue runtime file is not a regular file.' }
    }
    return $path
}

function Request-QueueStop {
    param([string]$Root)
    $path = Get-QueueRuntimeFile $Root 'stop.request'
    [IO.File]::WriteAllText($path, 'stop', [Text.UTF8Encoding]::new($false))
}

function Test-QueueStop { param([string]$Root); return [IO.File]::Exists((Get-QueueRuntimeFile $Root 'stop.request')) }

function Clear-QueueStop {
    param([string]$Root)
    # Only an explicit enabling command calls this, while holding control ownership.
    $path = Get-QueueRuntimeFile $Root 'stop.request'
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
}

function Test-QueueEnabledIntent {
    param([string]$Root)
    $path = Get-QueueRuntimeFile $Root 'enabled.intent'
    if (-not [IO.File]::Exists($path)) { return $false }
    $expected = [Text.Encoding]::ASCII.GetBytes("PARALLAX_AUTOSTART_V1|1`n")
    if ([IO.FileInfo]::new($path).Length -ne $expected.Length) { return $false }
    $actual = [IO.File]::ReadAllBytes($path)
    if ($actual.Length -ne $expected.Length) { return $false }
    for ($index = 0; $index -lt $expected.Length; $index++) {
        if ($actual[$index] -ne $expected[$index]) { return $false }
    }
    return $true
}

function Set-QueueEnabledIntent {
    param([string]$Root, [bool]$Enabled)
    $value = if ($Enabled) { '1' } else { '0' }
    Write-QueueControlFile $Root 'enabled.intent' "PARALLAX_AUTOSTART_V1|$value`n"
}

function Write-QueueControlFile {
    param([string]$Root, [ValidateSet('enabled.intent','launch.id','action.request')][string]$Name, [string]$Text)
    $path = Get-QueueRuntimeFile $Root $Name
    $temporary = Join-Path $Root ('.queue-control-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
    $stream = $null
    try {
        $stream = [IO.FileStream]::new($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        $null = Get-QueueRuntimeFile $Root $Name
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temporary, $path, [Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $path) }
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function New-QueueLaunchId {
    param([string]$Root)
    $identifier = [Guid]::NewGuid().ToString('N')
    Write-QueueControlFile $Root 'launch.id' "$identifier`n"
    return $identifier
}

function Test-QueueLaunchId {
    param([string]$Root, [string]$Identifier)
    if ($Identifier -cnotmatch '\A[a-f0-9]{32}\z') { return $false }
    $path = Get-QueueRuntimeFile $Root 'launch.id'
    if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -ne 33) { return $false }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ne 33) { return $false }
    for ($index=0; $index -lt 32; $index++) {
        if ($bytes[$index] -ne [byte][char]$Identifier[$index]) { return $false }
    }
    return $bytes[32] -eq 10
}

function Set-QueueRetry {
    param([string]$Root, [object]$Decision)
    $record = [ordered]@{ schema=2; state=$Decision.State; retry_not_before=[long]$Decision.RetryNotBefore; pause=[bool]$Decision.Pause }
    Write-QueueAtomicFile -DataRoot $Root -Name 'queue.retry.json' -Text ($record | ConvertTo-Json -Compress)
}

function Get-QueueRetry {
    param([string]$Root)
    $path = Get-QueueRuntimeFile $Root 'queue.retry.json'
    if (-not [IO.File]::Exists($path)) { return $null }
    if ((Get-Item -LiteralPath $path).Length -gt 4096) { throw 'Queue retry record is invalid.' }
    $record = ConvertFrom-QueueJson ([IO.File]::ReadAllText($path))
    if ($record -isnot [Collections.IDictionary] -or $record.Count -ne 4 -or $record['schema'] -ne 2 -or $record['state'] -notin @('rate_limited','quota_exceeded','offline','service_unavailable','error','forbidden','reauth_required','onboarding_required')) { throw 'Queue retry record is invalid.' }
    if ($record['pause'] -isnot [bool] -or [string]$record['retry_not_before'] -notmatch '^\d{1,12}$' -or [long]$record['retry_not_before'] -gt 253402300000) { throw 'Queue retry record is invalid.' }
    return [pscustomobject]@{ State=[string]$record['state']; RetryNotBefore=[long]$record['retry_not_before']; Pause=[bool]$record['pause'] }
}

function Get-QueueExceptionDecision {
    param([Exception]$Exception, [int]$FailureCount)
    $state = [string]$Exception.Data['QueueState']
    while (-not $state -and $null -ne $Exception.InnerException) { $Exception=$Exception.InnerException; $state=[string]$Exception.Data['QueueState'] }
    if ($state -in @('onboarding_required','reauth_required','forbidden','quota_exceeded')) {
        return [pscustomobject]@{ State=$state; RetryNotBefore=0L; Pause=$true }
    }
    if ($state -in @('auth_timeout','authorization_denied')) { return [pscustomobject]@{ State='reauth_required'; RetryNotBefore=0L; Pause=$true } }
    if ($state -eq 'rate_limited') {
        return Get-QueueResponseDecision 429 -RetryAfter ([string]$Exception.Data['RetryAfterSeconds']) -FailureCount $FailureCount
    }
    if ($state -eq 'offline') { return Get-QueueResponseDecision 0 -FailureCount $FailureCount }
    return Get-QueueResponseDecision 204 -FailureCount $FailureCount
}

function Write-QueueAction {
    # A short-lived control process (a row click or Refresh) hands its request
    # to the running worker through this one file; only the worker, which owns
    # the tokens, talks to Spotify. A newer click replaces an unread one. When
    # the player changes track, QueueReader.lua writes the same refresh request
    # itself, with no process.
    param([string]$Root, [ValidateSet('refresh','play')][string]$Kind, [int]$Position = 0, [long]$Observed = 0)
    if ($Kind -eq 'play' -and ($Position -lt 1 -or $Position -gt 20 -or $Observed -lt 1)) { throw 'Invalid queue action.' }
    if ($Kind -eq 'refresh') { $Position = 0; $Observed = 0 }
    Write-QueueControlFile $Root 'action.request' ("PARALLAX_QUEUE_ACTION_V1|$Kind|$Position|$Observed|" + (Get-QueueUnixTime) + "`n")
}

function Read-QueueAction {
    # Consumes the pending request, if any. Anything malformed, or older than
    # 15 seconds (written before this worker started), is discarded unread. A
    # file someone still holds open waits for the next pass: the skin writes
    # some requests, and a scanner may open any of them.
    param([string]$Root, [long]$Now = (Get-QueueUnixTime))
    $path = Get-QueueRuntimeFile $Root 'action.request'
    if (-not [IO.File]::Exists($path)) { return $null }
    $text = ''
    try {
        if ([IO.FileInfo]::new($path).Length -le 128) { $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) }
        [IO.File]::Delete($path)
    } catch [IO.IOException] { return $null }
    catch [UnauthorizedAccessException] { return $null }
    # The skin also asks for the playlist list (playlists) and to start one of
    # it (open, by its position and the list's observed time).
    if ($text -cnotmatch '\APARALLAX_QUEUE_ACTION_V1\|(refresh|play|playlists|open)\|([0-9]{1,2})\|([0-9]{1,12})\|([0-9]{1,12})\n\z') { return $null }
    $action = [pscustomobject]@{ Kind=$Matches[1]; Position=[int]$Matches[2]; Observed=[long]$Matches[3]; Created=[long]$Matches[4] }
    if ($action.Created -gt $Now + 5 -or $action.Created -lt $Now - 15) { return $null }
    $most = switch ($action.Kind) { 'play' { 20 } 'open' { 50 } default { 0 } }
    if ($most -gt 0 -and ($action.Position -lt 1 -or $action.Position -gt $most -or $action.Observed -lt 1)) { return $null }
    if ($most -eq 0 -and ($action.Position -ne 0 -or $action.Observed -ne 0)) { return $null }
    return $action
}

function Get-QueueContextItems {
    # Every song address in the playing album or playlist, or $null when that
    # cannot be known: a playlist whose songs Spotify does not share, one too
    # long, or a failed read. Kept while the same context plays, so one playlist
    # costs its pages once per half hour of clicking.
    param([string]$Token, [string]$ContextUri, [long]$Now = (Get-QueueUnixTime))
    $held = $script:ContextItems
    if ($null -ne $held -and $held.Uri -ceq $ContextUri -and $Now -ge $held.At -and $Now -lt $held.At + 1800) { return ,$held.Items }
    $script:ContextItems = $null
    $items = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $offset = 0
    for ($page = 0; $page -lt $script:ContextPageLimit; $page++) {
        $response = Invoke-QueueApiRequest -AccessToken $Token -Endpoint Items -ContextUri $ContextUri -Offset $offset
        if ($response.StatusCode -ne 200) { return $null }
        try { $read = ConvertTo-QueueContextPage (ConvertFrom-QueueJson $response.Body) } catch { return $null }
        foreach ($uri in $read.Uris) { $null = $items.Add($uri) }
        $offset += $read.Count
        if ($offset -ge $read.Total) {
            $script:ContextItems = [pscustomobject]@{ Uri = $ContextUri; At = $Now; Items = $items }
            return ,$items
        }
        if ($read.Count -eq 0) { return $null }
    }
    return $null
}

function Invoke-QueueJump {
    # Plays one song of the album or playlist already playing. Spotify keeps the
    # rest of the order, shuffled or not, and songs queued by hand (tried live,
    # 2026-11-24). Only for a song known to be in it: one that is not would
    # reshuffle the queue and drop the songs queued by hand. Returns 'done',
    # 'skip' (not possible here, nothing was changed) or 'failed' (no clear
    # answer, so skipping as well could act twice).
    param([string]$Token, [string]$ItemUri)
    if (-not $ItemUri) { return 'skip' }
    $playing = Invoke-QueueApiRequest -AccessToken $Token -Endpoint Playing
    if ($playing.StatusCode -ne 200) { return 'skip' }
    try { $context = ConvertTo-QueueContextUri (ConvertFrom-QueueJson $playing.Body) } catch { return 'skip' }
    if (-not $context) { return 'skip' }
    $items = Get-QueueContextItems -Token $Token -ContextUri $context
    if ($null -eq $items -or -not $items.Contains($ItemUri)) { return 'skip' }
    $code = (Invoke-QueueApiRequest -AccessToken $Token -Endpoint Start -ContextUri $context -ItemUri $ItemUri).StatusCode
    if ($code -ge 200 -and $code -le 299) { return 'done' }
    if ($code -ge 400 -and $code -le 499) { return 'skip' }
    return 'failed'
}

function Wait-QueuePlaying {
    # After a start, until Spotify reports the song or context it was asked for
    # (a queue read before that still describes the old one). Never an error: a
    # wait that runs out just leaves the reads that follow to catch up.
    param([string]$Token, [string]$ItemUri = '', [string]$ContextUri = '', [int]$Milliseconds = 400, [int]$Tries = 5)
    for ($try = 0; $try -lt $Tries; $try++) {
        if ($Milliseconds -gt 0) { Start-Sleep -Milliseconds $Milliseconds }
        try {
            $response = Invoke-QueueApiRequest -AccessToken $Token -Endpoint Playing
            if ($response.StatusCode -ne 200) { continue }
            $playing = ConvertFrom-QueueJson $response.Body
            if ($ItemUri -and (ConvertTo-QueuePlayingUri $playing) -ceq $ItemUri) { return }
            if ($ContextUri -and (ConvertTo-QueueContextUri $playing) -ceq $ContextUri) { return }
        } catch {}
    }
}

function Find-QueueItem {
    # Where an item the user saw is in the queue now (1-based), or 0. By its
    # address, or by its text when it has none. Its old place wins, so one of two
    # identical rows is the one that was clicked.
    param([object[]]$Items, [object]$Item, [int]$Position)
    for ($pass = 0; $pass -lt 2; $pass++) {
        for ($index = 0; $index -lt $Items.Count; $index++) {
            if ($pass -eq 0 -and $index -ne $Position - 1) { continue }
            $candidate = $Items[$index]
            $same = if ($Item.Uri -and $candidate.Uri) { $candidate.Uri -ceq $Item.Uri } else { $candidate.Title -ceq $Item.Title -and $candidate.Detail -ceq $Item.Detail }
            if ($same) { return $index + 1 }
        }
    }
    return 0
}

function Invoke-QueuePlay {
    # Plays the clicked item on the active player. The click names a row and the
    # snapshot it was shown in, one of the last few this worker published; the
    # queue is read again and the same item looked up in it, so a queue that moved
    # on meanwhile still plays what was clicked. The next item is one skip. A later
    # one is played directly when it belongs to the playing album or playlist, and
    # otherwise by skipping to it, since Spotify has no "play queue row N". Returns
    # the notice to show ('' on success); the caller refreshes the rows.
    param([string]$Root, [object]$Action, [object[]]$Recent, [int]$GapMilliseconds = 250)
    $seen = @($Recent | Where-Object { $null -ne $_ -and $_.Observed -eq $Action.Observed })
    if ($seen.Count -eq 0 -or $Action.Position -gt $seen[-1].Items.Count) { return 'queue_changed' }
    $clicked = $seen[-1].Items[$Action.Position - 1]
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        if (-not $auth.Control) { return 'control_reauth' }
        $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        if ($response.StatusCode -eq 401) {
            $auth = Get-QueueAccessToken -DataRoot $Root -ForceRefresh -WithControl
            if (-not $auth.Control) { return 'control_reauth' }
            $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        }
        if ($response.StatusCode -ne 200) { return (Get-QueueControlDecision $response.StatusCode) }
        $current = (ConvertTo-QueueItems (ConvertFrom-QueueJson $response.Body)).Items
        $place = Find-QueueItem -Items $current -Item $clicked -Position $Action.Position
        $jump = if ($place -ne 1) { Invoke-QueueJump -Token $auth.Token -ItemUri $clicked.Uri } else { 'skip' }
        if ($jump -eq 'failed') { return 'control_failed' }
        if ($jump -eq 'done') {
            Wait-QueuePlaying -Token $auth.Token -ItemUri $clicked.Uri -Milliseconds ([int](1.6 * $GapMilliseconds))
            return ''
        }
        if ($place -lt 1) { return 'queue_changed' }
        for ($skip = 1; $skip -le $place; $skip++) {
            if ($skip -gt 1) { Start-Sleep -Milliseconds $GapMilliseconds }
            $notice = Get-QueueControlDecision (Invoke-QueueApiRequest -AccessToken $auth.Token -Endpoint Next).StatusCode
            if ($notice) { return $notice }
        }
        # Let the player settle before the refresh reads its new queue.
        Start-Sleep -Milliseconds (2 * $GapMilliseconds)
        return ''
    } catch {
        $state = [string]$_.Exception.Data['QueueState']
        if ($state -in @('reauth_required','forbidden')) { return 'control_reauth' }
        return 'control_failed'
    } finally { $auth = $null }
}

function Publish-QueuePlaylists {
    # Writes the list the Playlists view shows. Its covers fill in later, under
    # the same observed time, so a click still names the same list.
    param([string]$Root, [object]$List)
    $text = ConvertTo-QueuePlaylistText -State $List.State -Items $List.Items -Total $List.Total -Current $List.Current -Now $List.Observed
    Write-QueueAtomicFile -DataRoot $Root -Name 'playlists.snapshot' -Text $text
}

function Remove-QueuePlaylists {
    param([string]$Root)
    $path = Get-QueueRuntimeFile $Root 'playlists.snapshot'
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
}

function Invoke-QueuePlaylists {
    # Reads the account's first 50 playlists for the Playlists view, only when
    # the view asks. A failed read is shown there; it never touches the queue's
    # own state, waits or rows. Returns the list, which the worker keeps.
    param([string]$Root, [long]$Now = (Get-QueueUnixTime))
    $list = [pscustomobject]@{ State = 'error'; Items = @(); Total = 0L; Current = 0; Observed = $Now; CoverAt = 0 }
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        if (-not $auth.Playlists) { $list.State = 'scope_required' }
        else {
            $response = Invoke-QueueApiRequest -AccessToken $auth.Token -Endpoint Playlists
            if ($response.StatusCode -eq 403) { $list.State = 'scope_required' }
            elseif ($response.StatusCode -eq 200) {
                $read = ConvertTo-QueuePlaylists (ConvertFrom-QueueJson $response.Body)
                $list.Items = $read.Items; $list.Total = $read.Total; $list.State = 'ready'
                $playing = Invoke-QueueApiRequest -AccessToken $auth.Token -Endpoint Playing
                if ($playing.StatusCode -eq 200) {
                    $context = ''
                    try { $context = ConvertTo-QueueContextUri (ConvertFrom-QueueJson $playing.Body) } catch {}
                    for ($index = 0; $context -and $index -lt $list.Items.Count; $index++) { if ($list.Items[$index].Uri -ceq $context) { $list.Current = $index + 1; break } }
                }
            }
        }
    } catch {
        $list.State = if ([string]$_.Exception.Data['QueueState'] -in @('reauth_required','forbidden')) { 'scope_required' } else { 'error' }
        $list.Items = @(); $list.Total = 0L; $list.Current = 0
    } finally { $auth = $null }
    Publish-QueuePlaylists $Root $list
    return $list
}

function Update-QueuePlaylistCovers {
    # One batch of the list's covers, then the list again if any were found.
    param([string]$Root, [object]$List)
    $batch = @($List.Items | Select-Object -Skip $List.CoverAt -First $script:CoverBatch)
    $List.CoverAt += $script:CoverBatch
    if ($batch.Count -eq 0) { return }
    try { Update-QueueCovers -Root $Root -Items $batch } catch {}
    if (@($batch | Where-Object { $_.Image }).Count -gt 0) { Publish-QueuePlaylists $Root $List }
}

function Update-QueueRowCovers {
    # One batch of the covers later rows still lack, then the rows again under the
    # same observed time. Returns where the next batch starts.
    param([string]$Root, [object]$Snapshot, [int]$At)
    $batch = @($Snapshot.Items | Select-Object -Skip $At -First $script:CoverBatch | Where-Object { -not $_.Image -and $_.ImageUrl })
    if ($batch.Count -gt 0) {
        try { Update-QueueCovers -Root $Root -Items $batch } catch {}
        if (@($batch | Where-Object { $_.Image }).Count -gt 0) { Publish-QueueSnapshot $Root $Snapshot }
    }
    return $At + $script:CoverBatch
}

function Invoke-QueueOpen {
    # Starts the clicked playlist on the active player. The click names the list
    # it was shown in; only that list, still held here, is acted on. Returns the
    # notice to show ('' on success); the caller refreshes the rows.
    param([string]$Root, [object]$Action, [object]$List, [int]$SettleMilliseconds = 400)
    if ($null -eq $List -or $List.State -ne 'ready' -or $List.Observed -ne $Action.Observed -or $Action.Position -gt $List.Items.Count) { return 'queue_changed' }
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        if (-not $auth.Control) { return 'control_reauth' }
        $uri = $List.Items[$Action.Position - 1].Uri
        $notice = Get-QueueControlDecision (Invoke-QueueApiRequest -AccessToken $auth.Token -Endpoint Open -ContextUri $uri).StatusCode
        if ($notice) { return $notice }
        # Before the refresh reads its new queue, and before the view leaves the
        # list (it takes the playing mark as the start having worked).
        Wait-QueuePlaying -Token $auth.Token -ContextUri $uri -Milliseconds $SettleMilliseconds
        $List.Current = $Action.Position
        Publish-QueuePlaylists $Root $List
        return ''
    } catch {
        if ([string]$_.Exception.Data['QueueState'] -in @('reauth_required','forbidden')) { return 'control_reauth' }
        return 'control_failed'
    } finally { $auth = $null }
}

function Find-QueueCover {
    # A cover saved by an earlier read is reused, and its write time renewed so
    # pruning counts it as recently used. Returns its file name, or ''. An
    # entry that is not a plain, plausibly sized file is removed instead.
    param([string]$CoverRoot, [string]$Key)
    foreach ($extension in @('jpg','png')) {
        $name = $Key + '.' + $extension
        $path = Join-Path $CoverRoot $name
        if (-not [IO.File]::Exists($path)) { continue }
        $file = [IO.FileInfo]::new($path)
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -lt 8 -or $file.Length -gt 262144) {
            try { $file.Delete() } catch {}
            continue
        }
        try { $file.LastWriteTimeUtc = [DateTime]::UtcNow } catch {}
        return $name
    }
    return ''
}

function Limit-QueueCovers {
    # Keeps the most recently used covers, and always every cover named in the
    # snapshot about to be published. Only cover files and this helper's own
    # leftover temporary files are ever deleted; anything else is left alone.
    param([string]$CoverRoot, [string[]]$Keep = @(), [int]$Limit = $script:CoverLimit)
    $kept = 0
    foreach ($file in @([IO.DirectoryInfo]::new($CoverRoot).GetFiles() | Sort-Object -Property LastWriteTimeUtc -Descending)) {
        try {
            if ($file.Name -cmatch '\A\.cover-[0-9a-f]{32}\.tmp\z') { $file.Delete(); continue }
            if ($file.Name -cnotmatch '\A[0-9a-f]{40}\.(?:jpg|png)\z') { continue }
            if ($Keep -ccontains $file.Name -or $kept -lt $Limit) { $kept++; continue }
            $file.Delete()
        } catch {}
    }
}

function Update-QueueCovers {
    # The download step of a successful queue read, for the shown rows only.
    # It runs before the snapshot exists, so the snapshot names only covers
    # already on disk, and it never fails the read: a row whose cover is
    # missing, refused, oversized or slow just has none. Stop ends the
    # downloads, and so does a request that got no response at all (the CDN
    # is unreachable; waiting on the rest would only hold up Stop and clicks).
    # Covers already saved are still reused either way.
    # -SavedOnly names covers already on disk and downloads none.
    param([string]$Root, [object[]]$Items = @(), [long]$Now = (Get-QueueUnixTime), [switch]$SavedOnly)
    try {
        $folder = Join-Path $Root 'covers'
        $wanted = @($Items | Where-Object { $_.ImageUrl })
        if ($wanted.Count -eq 0 -and -not [IO.Directory]::Exists($folder)) { return }
        # The same private, current-user-only directory handling as the data
        # root itself (and a covers entry that is a link is refused).
        $covers = Initialize-QueuePrivateDirectory -DataRoot $folder
    } catch { return }
    if ($script:CoverRetryAt.Count -gt 64) { $script:CoverRetryAt.Clear() }
    $download = -not $SavedOnly
    foreach ($item in $Items) {
        $url = ''
        try {
            $url = [string]$item.ImageUrl
            if (-not $url) { continue }
            $key = Get-QueueImageKey $url
            $item.Image = Find-QueueCover $covers $key
            if ($item.Image -or -not $download) { continue }
            if ($script:CoverRetryAt.ContainsKey($url) -and $script:CoverRetryAt[$url] -gt $Now) { continue }
            if (Test-QueueStop $Root) { $download = $false; continue }
            # The URL alone: the cover request never carries the Spotify token.
            $response = Invoke-QueueImageRequest -Uri $url
            $extension = ''
            if ($response.StatusCode -eq 200) { $extension = Get-QueueImageExtension $response.ContentType $response.Bytes }
            if ($extension) {
                $name = $key + '.' + $extension
                Write-QueueCoverFile -CoverRoot $covers -Name $name -Bytes $response.Bytes
                $item.Image = $name
                $script:CoverRetryAt.Remove($url)
            } else {
                $script:CoverRetryAt[$url] = $Now + $script:CoverRetrySeconds
                if ($response.StatusCode -eq 0) { $download = $false }
            }
        } catch {
            $item.Image = ''
            if ($url) { $script:CoverRetryAt[$url] = $Now + $script:CoverRetrySeconds }
        }
    }
    if ($SavedOnly) { return }
    try { Limit-QueueCovers $covers @($Items | ForEach-Object { [string]$_.Image } | Where-Object { $_ }) } catch {}
}

function Remove-QueueCovers {
    # Saved covers are listening history too, so Disconnect removes them with
    # the tokens and rows. A covers entry that is a link (junction or symbolic
    # link) is removed itself; its target is never entered.
    param([string]$Root)
    $path = Join-Path $Root 'covers'
    $attributes = [IO.FileAttributes]0
    try { $attributes = [IO.File]::GetAttributes($path) }
    catch [IO.FileNotFoundException] { return }
    catch [IO.DirectoryNotFoundException] { return }
    if (($attributes -band [IO.FileAttributes]::Directory) -eq 0) { [IO.File]::Delete($path); return }
    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { [IO.Directory]::Delete($path, $false); return }
    [IO.Directory]::Delete($path, $true)
}

function Invoke-QueueCycle {
    param([string]$Root, [int]$Interval, [int]$FailureCount = 0, [AllowEmptyString()][string]$Notice = '')
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        if ($response.StatusCode -eq 401) {
            # Exactly one forced refresh, then one GET retry. Never a consent loop.
            $auth = Get-QueueAccessToken -DataRoot $Root -ForceRefresh -WithControl
            $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        }
        $control = [bool]$auth.Control
        $auth = $null
        $now = Get-QueueUnixTime
        $decision = Get-QueueResponseDecision -StatusCode $response.StatusCode -Body $response.Body -RetryAfter $response.RetryAfter -Now $now -FailureCount $FailureCount
        if ($decision.State -eq 'response_requires_validation') {
            try {
                $items = ConvertTo-QueueItems (ConvertFrom-QueueJson $response.Body)
                # Covers are saved before the snapshot is built, so it names
                # only files that exist. This step cannot fail the read. Only the
                # first rows' are fetched here; the worker fetches the rest after the
                # rows are published (Update-QueueRowCovers).
                try { Update-QueueCovers -Root $Root -Items @($items.Items | Select-Object -First $script:FirstCovers) -Now $now } catch {}
                try { Update-QueueCovers -Root $Root -Items @($items.Items | Select-Object -Skip $script:FirstCovers) -Now $now -SavedOnly } catch {}
                $lifetime = [Math]::Min(300, [Math]::Max(90, $Interval*2))
                $snapshot = New-QueueSnapshot -State ready -Items $items.Items -Now $now -LifetimeSeconds $lifetime -Control $control -Notice $Notice -Current $items.Current
                return [pscustomobject]@{ Snapshot=$snapshot; NextAt=($now+$Interval); Pause=$false; Success=$true }
            } catch {
                $decision = Get-QueueResponseDecision 204 -Now $now -FailureCount $FailureCount
            }
        }
    } catch { $decision = Get-QueueExceptionDecision $_.Exception $FailureCount }
    finally { $auth=$null }
    $snapshot = New-QueueSnapshot -State $decision.State -RetryNotBefore $decision.RetryNotBefore
    return [pscustomobject]@{ Snapshot=$snapshot; NextAt=$decision.RetryNotBefore; Pause=$decision.Pause; Success=$false }
}

function Start-QueueBackground {
    param([string]$Root, [int]$Interval, [switch]$RetryQuota)
    $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($script:ProviderPath.Contains('"') -or $Root.Contains('"')) { throw 'Unsupported helper path.' }
    # The controller owns the lifecycle mutex here. A later launch replaces this
    # permit, preventing a delayed child from applying obsolete cadence/flags.
    $identifier = New-QueueLaunchId $Root
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script:ProviderPath + '" -Command Run -Quiet -PollSeconds ' + $Interval + ' -LaunchId ' + $identifier + ' -DataRoot "' + $Root + '"'
    if ($RetryQuota) { $arguments += ' -ResumeAfterQuota' }
    # Bind the worker to the Rainmeter that asked for it (no lease from a shell),
    # and start it outside the skin folder so it cannot block an upgrade.
    $lease = Get-MediaOwnerLease
    if ($lease) { $arguments += ' -OwnerLease ' + $lease }
    $null = Start-Process -FilePath $hostPath -ArgumentList $arguments -WorkingDirectory $Root -WindowStyle Hidden -PassThru
}

function Invoke-QueueRun {
    param([string]$Root, [int]$Interval=30, [switch]$Single, [switch]$RetryQuota, [switch]$Silent, [string]$LaunchId = '', [string]$Lease = '')
    $owner = Open-MediaOwner $Lease
    if ($owner -is [bool]) { return }
    $control = New-QueueControlMutex $Root
    $controlOwned = $false
    $mutex = New-QueueRunMutex $Root
    $owned = $false
    try {
        # Match controller lock order. A delayed child must not enter the window
        # between clearing Stop and publishing the replacement launch permit.
        $controlOwned = Wait-QueueMutex $control 10000
        if (-not $controlOwned) { return }
        $owned = Wait-QueueMutex $mutex 0
        if (-not $owned) { if (-not $Silent) { Write-Output 'The queue helper is already running.' }; return }
        # A child may start after Stop/Disconnect has completed. Never erase its
        # stop barrier or overwrite the account action's resulting snapshot.
        if (Test-QueueStop $Root) { return }
        if ($LaunchId -and -not (Test-QueueLaunchId $Root $LaunchId)) { return }
        # Only bootstrap needs control ownership; Stop must be able to signal a
        # live worker during token refresh, HTTP requests and retry waits.
        $control.ReleaseMutex(); $controlOwned = $false
        $retry = Get-QueueRetry $Root
        # Reauthorization fixes auth errors; a new run does not bypass quota waits.
        if ($null -ne $retry -and $retry.State -eq 'quota_exceeded' -and $retry.Pause -and -not $RetryQuota) {
            Publish-QueueSnapshot $Root (New-QueueSnapshot -State quota_exceeded)
            if (-not $Silent) { Write-Output 'Spotify quota is exhausted. Check your app quota before an explicit -ResumeAfterQuota retry.' }
            return
        }
        $next = Get-QueueUnixTime
        if ($null -ne $retry -and $retry.RetryNotBefore -gt $next) {
            $next = $retry.RetryNotBefore
            Publish-QueueSnapshot $Root (New-QueueSnapshot -State $retry.State -RetryNotBefore $next)
            if ($Single) { return }
        }
        if (-not $Silent) { Write-Output 'Queue helper running. Close this console or use Stop in the queue skin to stop it.' }
        $failures = 0
        # The last published ready snapshot (a click must name it) and the
        # outcome of a click to show with the next rows.
        $last = $null; $notice = ''
        # The last few of them: a click may name one shown a moment ago.
        $recent = [Collections.Generic.List[object]]::new()
        # Which of the published rows' covers are fetched next.
        $coverAt = 0
        # The playlist list the Playlists view last asked for. One left by an
        # earlier worker names playlists this one does not hold, so it goes.
        $list = $null
        Remove-QueuePlaylists $Root
        # A request left from before this worker started is never acted on.
        $null = Read-QueueAction $Root -Now 0
        while (-not (Test-QueueStop $Root)) {
            $action = Read-QueueAction $Root
            if ($null -ne $action) {
                # Both need the current rows to be live: a failed read keeps
                # its backoff or server wait, and a click has nothing to name.
                if ($null -ne $last -and $failures -eq 0) {
                    if ($action.Kind -eq 'play') { $notice = Invoke-QueuePlay -Root $Root -Action $action -Recent $recent.ToArray() }
                    if ($action.Kind -eq 'open') { $notice = Invoke-QueueOpen -Root $Root -Action $action -List $list }
                    if ($action.Kind -eq 'playlists') { $list = Invoke-QueuePlaylists $Root }
                    else { $next = Get-QueueUnixTime }
                }
            }
            if ($null -ne $last -and $coverAt -lt $last.Items.Count) {
                $coverAt = Update-QueueRowCovers $Root $last $coverAt
                if ((Get-QueueUnixTime) -lt $next) { continue }
            }
            if ($null -ne $list -and $list.CoverAt -lt $list.Items.Count) {
                Update-QueuePlaylistCovers $Root $list
                if ((Get-QueueUnixTime) -lt $next) { continue }
            }
            if ((Get-QueueUnixTime) -lt $next) {
                # The launching Rainmeter is gone. Exit without a 'stopped'
                # snapshot: resume intent is unchanged, and the next Rainmeter's
                # skin load starts a fresh worker.
                if (Wait-MediaOwnerExit $owner 1000) { return }
                continue
            }
            $result = Invoke-QueueCycle -Root $Root -Interval $Interval -FailureCount $failures -Notice $notice
            $notice = ''
            if (Test-QueueStop $Root) {
                # A stop/restart during an HTTP request must still retain any
                # retry barrier that arrived in that response.
                if (-not $result.Success) {
                    Set-QueueRetry $Root ([pscustomobject]@{ State=$result.Snapshot.State; RetryNotBefore=$result.NextAt; Pause=$result.Pause })
                }
                break
            }
            Publish-QueueSnapshot $Root $result.Snapshot
            if ($result.Success) {
                $failures = 0
                $last = $result.Snapshot
                $coverAt = $script:FirstCovers
                $recent.Add($last)
                if ($recent.Count -gt 6) { $recent.RemoveAt(0) }
                $retryPath = Get-QueueRuntimeFile $Root 'queue.retry.json'
                if ([IO.File]::Exists($retryPath)) { [IO.File]::Delete($retryPath) }
            } else {
                $last = $null; $recent.Clear()
                $failures = [Math]::Min(10,$failures+1)
                Set-QueueRetry $Root ([pscustomobject]@{ State=$result.Snapshot.State; RetryNotBefore=$result.NextAt; Pause=$result.Pause })
            }
            if ($result.Pause -or $Single) { return }
            $next = $result.NextAt
        }
        Publish-QueueSnapshot $Root (New-QueueSnapshot -State stopped)
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
        if ($owner) { $owner.Dispose() }
    }
}

function Invoke-QueueCommand {
    if ($Command -eq 'Help') { Show-QueueHelp; return }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 to run QueueProvider.ps1.' }
    if (-not $DataRoot) { $DataRoot = Get-QueueDataRoot }
    if ($Command -in @('Refresh','Play')) {
        # A click hands its request to the live worker and exits: no tokens, no
        # network, no directory creation or ACL change, and no lifecycle lock.
        $candidate = & (Get-Module -Name QueueAuth) { param($Path) Resolve-QueuePrivatePath $Path } $DataRoot
        if (-not [IO.Directory]::Exists($candidate) -or (Test-QueueStop $candidate)) { return }
        $mutex = New-QueueRunMutex $candidate
        try {
            # Acquired means no worker is running, so nothing would read it.
            if (Wait-QueueMutex $mutex 0) { $mutex.ReleaseMutex(); return }
        } finally { $mutex.Dispose() }
        if ($Command -eq 'Play') { Write-QueueAction $candidate play $Position $Observed }
        else { Write-QueueAction $candidate refresh }
        return
    }
    if ($Command -eq 'Resume') {
        # Reuse Auth's passive path validation without creating the directory or
        # modifying its ACL. Missing/disabled/malformed intent is a true no-op.
        $candidate = & (Get-Module -Name QueueAuth) { param($Path) Resolve-QueuePrivatePath $Path } $DataRoot
        if (-not (Test-QueueEnabledIntent $candidate) -or (Test-QueueStop $candidate)) { return }
    }
    $DataRoot = Initialize-QueuePrivateDirectory -DataRoot $DataRoot
    if ($Command -eq 'Run') {
        # Never keep the skin folder as the working directory: a live worker
        # would then stop Skin Installer moving Skins\Parallax on upgrade.
        [Environment]::CurrentDirectory = $DataRoot
        Set-Location -LiteralPath $DataRoot
        Invoke-QueueRun $DataRoot $PollSeconds -Single:$Once -RetryQuota:$ResumeAfterQuota -Silent:$Quiet -LaunchId $LaunchId -Lease $OwnerLease
        return
    }
    # Control ownership spans the launch, so Stop cannot finish between an
    # enabling command clearing its marker and requesting the child process.
    $control = New-QueueControlMutex $DataRoot
    $controlOwned = $false
    $mutex = New-QueueRunMutex $DataRoot
    $owned = $false
    try {
        $controlOwned = Wait-QueueMutex $control 10000
        if (-not $controlOwned) { throw 'Another queue lifecycle action is still running.' }
        if ($Command -in @('Start','Resume')) {
            if ($Command -eq 'Resume') {
                # No auth reads, token renewal, login, intent writes or stop-marker
                # clearing occur in this bootstrap. Run retains all retry gates.
                if (-not (Test-QueueEnabledIntent $DataRoot) -or (Test-QueueStop $DataRoot)) { return }
            } else {
                Set-QueueEnabledIntent $DataRoot $true
            }
            $owned = Wait-QueueMutex $mutex 0
            if (-not $owned) { return }
            if ($Command -eq 'Start') { Clear-QueueStop $DataRoot }
            # A fast child must not mistake this controller for a live worker.
            $mutex.ReleaseMutex(); $owned = $false
            Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:($Command -eq 'Start' -and $ResumeAfterQuota)
            return
        }
        # Account/configuration changes keep the existing bounded worker wait.
        # The stop marker is written first: even a failed intent save leaves a
        # durable veto that delayed Run/Resume cannot clear.
        Request-QueueStop $DataRoot
        Set-QueueEnabledIntent $DataRoot $false
        $startAfterLogin = $false
        try {
            $owned = Wait-QueueMutex $mutex 40000
            if (-not $owned) { throw 'The queue helper is busy. Stop it and try again.' }
            if ($Command -eq 'Stop') { Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State stopped); return }
            if ($Command -eq 'Restart') {
                # Stop is observed before the replacement requests its mutex.
                Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State stopped)
                $startAfterLogin = $true
            }
            if ($Command -eq 'Disconnect') {
                Clear-QueueTokens -DataRoot $DataRoot
                # Rows go first, so the reader stops naming covers before they are deleted.
                Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State onboarding_required)
                Remove-QueuePlaylists $DataRoot
                # One retry covers a cover briefly held open (Rainmeter loading it, a
                # scanner). A folder that still will not go leaves the onboarding
                # state in place; an interactive Disconnect says so.
                $coversRemoved = $true
                try { Remove-QueueCovers $DataRoot }
                catch {
                    Start-Sleep -Milliseconds 250
                    try { Remove-QueueCovers $DataRoot } catch { $coversRemoved = $false }
                }
                if (-not $Quiet) {
                    if ($coversRemoved) { Write-Output 'Disconnected. Local tokens, queue rows and saved covers removed. App configuration is retained; you can also revoke access in Spotify account settings.' }
                    else { Write-Output ('Disconnected. Local tokens and queue rows removed, but saved covers could not all be deleted from ' + (Join-Path $DataRoot 'covers') + '. Disconnect again to retry. App configuration is retained; you can also revoke access in Spotify account settings.') }
                }
                return
            }
            if ($Command -in @('Configure','Connect')) {
                $saved = Get-QueueClientId -DataRoot $DataRoot
                if (-not $ClientId -and -not $saved) {
                    if ($Quiet) { Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State onboarding_required); return }
                    Show-QueueHelp
                    $ClientId = Read-Host 'Public Spotify Client ID (not the client secret)'
                }
                if ($ClientId) {
                    if ($ClientId -notmatch '^[a-fA-F0-9]{32}$') { throw 'Enter the 32-character public Client ID from Spotify app settings.' }
                    if ($saved -and $ClientId -ine $saved) { Clear-QueueTokens -DataRoot $DataRoot }
                    Set-QueueClientId -DataRoot $DataRoot -ClientId $ClientId
                }
                if ($Command -eq 'Configure') { Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State onboarding_required); return }
                $retry = Get-QueueRetry $DataRoot
                if ($null -ne $retry -and (($retry.State -eq 'quota_exceeded' -and $retry.Pause -and -not $ResumeAfterQuota) -or $retry.RetryNotBefore -gt (Get-QueueUnixTime))) {
                    Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State $retry.State -RetryNotBefore $retry.RetryNotBefore)
                    if (-not $Quiet) { Write-Output 'Spotify requested a wait or exhausted its quota. See the queue setup guide before retrying.' }
                    return
                }
                Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State connecting)
                $null = Connect-QueueSpotify -DataRoot $DataRoot
                $startAfterLogin = $true
            }
        } catch {
            $decision = Get-QueueExceptionDecision $_.Exception 0
            if ($decision.State -in @('rate_limited','quota_exceeded')) { Set-QueueRetry $DataRoot $decision }
            Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State $decision.State -RetryNotBefore $decision.RetryNotBefore)
            if (-not $Quiet) { Write-Output ('Queue setup did not finish: ' + $decision.State + '. Check the setup guide and try again.') }
        } finally {
            if ($owned) { $mutex.ReleaseMutex(); $owned = $false }
        }
        if ($startAfterLogin) {
            Set-QueueEnabledIntent $DataRoot $true
            Clear-QueueStop $DataRoot
            Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:$ResumeAfterQuota
            if (-not $Quiet) {
                if ($Command -eq 'Restart') { Write-Output 'The queue helper is restarting with the selected interval.' }
                else { Write-Output 'Spotify authorization saved. The queue helper is starting in the background.' }
            }
        }
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
    }
}

# Dot-sourcing is test-only: it defines functions without reading runtime files.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-QueueCommand }
    catch {
        if (-not $Quiet) { Write-Output 'The queue helper could not start. Check Windows PowerShell 5.1, the helper files, and access to its LocalAppData folder.' }
        exit 1
    }
}
