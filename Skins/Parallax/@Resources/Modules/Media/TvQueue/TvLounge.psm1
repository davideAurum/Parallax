#requires -Version 5.1
# YouTube on the TV: the protocol side of Media's optional TV queue.
# Windows PowerShell 5.1 / built-in .NET only. Importing touches no network,
# disk or account: requests are only built and sent when the worker asks.
#
# The TV is reached through YouTube's unofficial "Lounge" remote-control API,
# paired by the TV's "Link with TV code". Written for Parallax from protocol
# facts (sources listed in README.md beside this file); no code from GPL projects.
# The API is undocumented: everything read here is parsed defensively and
# anything unexpected is dropped, never guessed at.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LoungeBase = 'https://www.youtube.com/api/lounge'
$script:TitleBase = 'https://www.youtube.com/oembed'
# YouTube's public thumbnail host: one fixed-size picture per video id.
$script:ThumbBase = 'https://i.ytimg.com/vi'
$script:RemoteName = 'Parallax'
$script:UserAgent = 'Parallax-Media/1'
# One frame of the event stream, and one HTTP answer, are never larger.
$script:FrameLimit = 1048576
$script:BodyLimit = 1048576
# An id list this short (only the current video, or nothing) is "not known yet",
# never an empty queue: one live reading had a list of 1 (handoff, up next).
$script:ShortList = 1
$script:VideoIdPattern = '\A[A-Za-z0-9_-]{11}\z'
$script:ListIdPattern = '\A[A-Za-z0-9_-]{2,64}\z'
$script:Utf8 = [Text.UTF8Encoding]::new($false, $true)

function Get-TvUnixMs { return [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalMilliseconds) }

function Set-TvEndpointForTest {
    # Test-only: points requests at a stand-in on this PC. Only plain HTTP to
    # 127.0.0.1 is accepted, so nothing can redirect the worker elsewhere, and
    # nothing in the shipped skin calls this.
    # Thumbnails go to the title stand-in's /vi unless named: a test can never
    # reach the real thumbnail host by leaving it out.
    param([Parameter(Mandatory)][string]$LoungeBase, [Parameter(Mandatory)][string]$TitleBase, [string]$ThumbBase = '')
    if (-not $ThumbBase -and $TitleBase -cmatch '\A(http://127\.0\.0\.1:[0-9]{2,5})/') { $ThumbBase = $Matches[1] + '/vi' }
    foreach ($url in @($LoungeBase, $TitleBase, $ThumbBase)) {
        if ($url -cnotmatch '\Ahttp://127\.0\.0\.1:[0-9]{2,5}/[A-Za-z0-9/_-]*\z') { throw 'Test endpoints must be http://127.0.0.1:<port>/...' }
    }
    $script:LoungeBase = $LoungeBase.TrimEnd('/')
    $script:TitleBase = $TitleBase.TrimEnd('/')
    $script:ThumbBase = $ThumbBase.TrimEnd('/')
}

function Test-TvVideoId { param([AllowNull()][object]$Value); return ($Value -is [string] -and $Value -cmatch $script:VideoIdPattern) }
function Test-TvListId { param([AllowNull()][object]$Value); return ($Value -is [string] -and $Value -cmatch $script:ListIdPattern) }

function ConvertFrom-TvJson {
    # Bounded JSON: dictionaries and object arrays, never PowerShell objects.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Json, [int]$Limit = $script:BodyLimit)
    if ($Json.Length -gt $Limit) { throw 'TV answer exceeds the size limit.' }
    Add-Type -AssemblyName System.Web.Extensions
    $parser = [Web.Script.Serialization.JavaScriptSerializer]::new()
    $parser.MaxJsonLength = $Limit
    $parser.RecursionLimit = 16
    try { return ,$parser.DeserializeObject($Json) } catch { throw 'TV answer is not valid bounded JSON.' }
}

# ------------------------------------------------------------------ framing
# The event stream is a sequence of "<length>\n<length characters of JSON>",
# where each JSON chunk is an array of [eventId, [name, data...]] entries. A
# read can end anywhere, so text is collected until a whole chunk is there.

function New-TvFrameReader { return [pscustomobject]@{ Pending = '' } }

function Read-TvFrames {
    # Feeds one slice of the stream; returns every event completed by it.
    param([Parameter(Mandatory)][object]$Reader, [AllowEmptyString()][string]$Text)
    $events = [Collections.Generic.List[object]]::new()
    $pending = $Reader.Pending + $Text
    while ($pending.Length -gt 0) {
        $newline = $pending.IndexOf([char]10)
        if ($newline -lt 0) {
            if ($pending.Length -gt 12) { $Reader.Pending = ''; throw 'TV stream framing is broken: no length line.' }
            break
        }
        $head = $pending.Substring(0, $newline).Trim()
        if ($head.Length -eq 0) { $pending = $pending.Substring($newline + 1); continue }
        if ($head -cnotmatch '\A[0-9]{1,7}\z' -or [int]$head -gt $script:FrameLimit) { $Reader.Pending = ''; throw 'TV stream framing is broken: bad length line.' }
        $length = [int]$head
        if ($pending.Length - $newline - 1 -lt $length) { break }
        $chunk = $pending.Substring($newline + 1, $length)
        $pending = $pending.Substring($newline + 1 + $length)
        foreach ($item in (ConvertTo-TvEvents $chunk)) { $events.Add($item) }
    }
    if ($pending.Length -gt $script:FrameLimit + 16) { $Reader.Pending = ''; throw 'TV stream framing is broken: frame too large.' }
    $Reader.Pending = $pending
    return $events.ToArray()
}

function ConvertTo-TvEvents {
    # One JSON chunk to events: Id (number), Name (text), Data (object[]).
    # Entries of an unexpected shape are skipped, not fatal.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Chunk)
    $parsed = ConvertFrom-TvJson $Chunk -Limit $script:FrameLimit
    $events = [Collections.Generic.List[object]]::new()
    if ($parsed -isnot [object[]]) { return $events.ToArray() }
    foreach ($entry in $parsed) {
        if ($entry -isnot [object[]] -or $entry.Count -ne 2) { continue }
        $id = $entry[0]
        if (-not ($id -is [int] -or $id -is [long]) -or $id -lt 0) { continue }
        $body = $entry[1]
        if ($body -isnot [object[]] -or $body.Count -lt 1 -or $body[0] -isnot [string]) { continue }
        # Assigned, not taken from an if-expression, which would unroll it.
        [object[]]$data = @()
        if ($body.Count -gt 1) { $data = [object[]]$body[1..($body.Count - 1)] }
        $events.Add([pscustomobject]@{ Id = [long]$id; Name = [string]$body[0]; Data = $data })
    }
    return $events.ToArray()
}

function Get-TvEventFields {
    # The dictionary most events carry as their first data item, or an empty one.
    param([Parameter(Mandatory)][object]$TvEvent)
    if ($TvEvent.Data.Count -gt 0 -and $TvEvent.Data[0] -is [Collections.IDictionary]) { return $TvEvent.Data[0] }
    return @{}
}

# ------------------------------------------------------------------ session

function New-TvSession {
    # One remote-control session. Events and commands both use it: in an early
    # live test a second connection for commands left the listening one without events.
    param([Parameter(Mandatory)][object]$Pairing)
    return [pscustomobject]@{
        Pairing  = $Pairing
        Sid      = ''
        GSession = ''
        Aid      = -1L
        Rid      = 1
        # Commands in early live tests started at ofs 1, counted up, and were obeyed.
        Ofs      = 1
    }
}

function Update-TvSession {
    # Session ids arrive as events 'c' (session id) and 'S' (gsession id); every
    # event moves the acknowledged event id on.
    param([Parameter(Mandatory)][object]$Session, [Parameter(Mandatory)][object]$TvEvent)
    if ($TvEvent.Id -gt $Session.Aid) { $Session.Aid = $TvEvent.Id }
    if ($TvEvent.Data.Count -lt 1 -or $TvEvent.Data[0] -isnot [string]) { return }
    $value = [string]$TvEvent.Data[0]
    if ($value.Length -lt 1 -or $value.Length -gt 256 -or $value -cnotmatch '\A[!-~]+\z') { return }
    if ($TvEvent.Name -ceq 'c') { $Session.Sid = $value }
    elseif ($TvEvent.Name -ceq 'S') { $Session.GSession = $value }
}

function ConvertTo-TvForm {
    param([Parameter(Mandatory)][Collections.IDictionary]$Fields)
    $pairs = [Collections.Generic.List[string]]::new()
    foreach ($key in @($Fields.Keys)) { $pairs.Add([Uri]::EscapeDataString([string]$key) + '=' + [Uri]::EscapeDataString([string]$Fields[$key])) }
    return ($pairs -join '&')
}

function Get-TvSessionQuery {
    param([Parameter(Mandatory)][object]$Session)
    $query = [ordered]@{
        name          = $script:RemoteName
        loungeIdToken = $Session.Pairing.LoungeToken
        SID           = $Session.Sid
        gsessionid    = $Session.GSession
        device        = 'REMOTE_CONTROL'
        app           = 'youtube-desktop'
        VER           = '8'
        v             = '2'
    }
    if ($Session.Aid -ge 0) { $query['AID'] = [string]$Session.Aid }
    return $query
}

function New-TvBindRequest {
    param([Parameter(Mandatory)][object]$Session)
    $form = [ordered]@{
        app           = 'web'
        'mdx-version' = '3'
        name          = $script:RemoteName
        id            = $Session.Pairing.DeviceId
        device        = 'REMOTE_CONTROL'
        capabilities  = 'que,dsdtr,atp'
        magnaKey      = 'cloudPairedDevice'
        ui            = 'false'
        theme         = 'cl'
        loungeIdToken = $Session.Pairing.LoungeToken
    }
    return [pscustomobject]@{ Method = 'POST'; Url = ($script:LoungeBase + '/bc/bind?RID=' + $Session.Rid + '&VER=8&CVER=1&auth_failure_option=send_error'); Body = (ConvertTo-TvForm $form); Token = $Session.Pairing.LoungeToken }
}

function New-TvPollRequest {
    param([Parameter(Mandatory)][object]$Session)
    $query = Get-TvSessionQuery $Session
    $query['RID'] = 'rpc'
    $query['CI'] = '0'
    $query['TYPE'] = 'xmlhttp'
    return [pscustomobject]@{ Method = 'GET'; Url = ($script:LoungeBase + '/bc/bind?' + (ConvertTo-TvForm $query)); Body = ''; Token = $Session.Pairing.LoungeToken }
}

$script:TvCommands = @('getNowPlaying', 'play', 'pause', 'next', 'setPlaylist')

function New-TvCommandRequest {
    # One command on the listening session. Each call uses the next request
    # number, so a command is never sent twice under the same one.
    param([Parameter(Mandatory)][object]$Session, [Parameter(Mandatory)][string]$Name, [Collections.IDictionary]$Fields = @{})
    if ($Name -cnotin $script:TvCommands) { throw 'Unknown TV command.' }
    $Session.Rid++
    $offset = $Session.Ofs
    $Session.Ofs++
    $query = Get-TvSessionQuery $Session
    $query['RID'] = [string]$Session.Rid
    $form = [ordered]@{ count = '1'; ofs = [string]$offset; 'req0__sc' = $Name }
    foreach ($key in @($Fields.Keys)) { $form['req0_' + $key] = [string]$Fields[$key] }
    return [pscustomobject]@{ Method = 'POST'; Url = ($script:LoungeBase + '/bc/bind?' + (ConvertTo-TvForm $query)); Body = (ConvertTo-TvForm $form); Token = $Session.Pairing.LoungeToken }
}

function New-TvLeaveRequest {
    param([Parameter(Mandatory)][object]$Session)
    $Session.Rid++
    $query = Get-TvSessionQuery $Session
    $query['RID'] = [string]$Session.Rid
    $query['CVER'] = '1'
    $query['auth_failure_option'] = 'send_error'
    $form = [ordered]@{ ui = ''; TYPE = 'terminate'; clientDisconnectReason = 'MDX_SESSION_DISCONNECT_REASON_DISCONNECTED_BY_USER' }
    return [pscustomobject]@{ Method = 'POST'; Url = ($script:LoungeBase + '/bc/bind?' + (ConvertTo-TvForm $query)); Body = (ConvertTo-TvForm $form); Token = $Session.Pairing.LoungeToken }
}

function New-TvPairRequest {
    param([Parameter(Mandatory)][string]$Code)
    return [pscustomobject]@{ Method = 'POST'; Url = ($script:LoungeBase + '/pairing/get_screen'); Body = (ConvertTo-TvForm @{ pairing_code = $Code }); Token = '' }
}

function New-TvTokenRequest {
    param([Parameter(Mandatory)][string]$ScreenId)
    return [pscustomobject]@{ Method = 'POST'; Url = ($script:LoungeBase + '/pairing/get_lounge_token_batch'); Body = (ConvertTo-TvForm @{ screen_ids = $ScreenId }); Token = '' }
}

function New-TvTitleRequest {
    # Public oEmbed: sends only the watch address of one video id.
    param([Parameter(Mandatory)][string]$VideoId)
    if (-not (Test-TvVideoId $VideoId)) { throw 'Invalid video id.' }
    $watch = [Uri]::EscapeDataString('https://www.youtube.com/watch?v=' + $VideoId)
    return [pscustomobject]@{ Method = 'GET'; Url = ($script:TitleBase + '?format=json&url=' + $watch); Body = ''; Token = '' }
}

function New-TvThumbRequest {
    # The video's medium thumbnail (320x180, no letterbox bars) from YouTube's
    # public thumbnail host: sends only the video id in the path, no token.
    param([Parameter(Mandatory)][string]$VideoId)
    if (-not (Test-TvVideoId $VideoId)) { throw 'Invalid video id.' }
    return [pscustomobject]@{ Method = 'GET'; Url = ($script:ThumbBase + '/' + $VideoId + '/mqdefault.jpg'); Body = ''; Token = '' }
}

function ConvertFrom-TvPairAnswer {
    # The pairing answer's screen: id, token and name. Throws when it lacks one.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $answer = ConvertFrom-TvJson $Text
    if ($answer -isnot [Collections.IDictionary] -or -not $answer.ContainsKey('screen') -or $answer['screen'] -isnot [Collections.IDictionary]) { throw 'The pairing answer has no screen.' }
    $screen = $answer['screen']
    $id = if ($screen.ContainsKey('screenId')) { $screen['screenId'] } else { $null }
    $token = if ($screen.ContainsKey('loungeToken')) { $screen['loungeToken'] } else { $null }
    if ($id -isnot [string] -or $id.Length -lt 1 -or $id.Length -gt 512 -or $token -isnot [string] -or $token.Length -lt 1 -or $token.Length -gt 4096) { throw 'The pairing answer has no usable screen id and token.' }
    $name = ''
    if ($screen.ContainsKey('name') -and $screen['name'] -is [string]) { $name = Limit-TvText $screen['name'] 200 }
    return [pscustomobject]@{ ScreenId = $id; LoungeToken = $token; Name = $name }
}

function ConvertFrom-TvTokenAnswer {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $answer = ConvertFrom-TvJson $Text
    if ($answer -isnot [Collections.IDictionary] -or -not $answer.ContainsKey('screens') -or $answer['screens'] -isnot [object[]] -or $answer['screens'].Count -lt 1) { throw 'The token answer has no screen.' }
    $screen = $answer['screens'][0]
    if ($screen -isnot [Collections.IDictionary] -or -not $screen.ContainsKey('loungeToken')) { throw 'The token answer has no token.' }
    $token = $screen['loungeToken']
    if ($token -isnot [string] -or $token.Length -lt 1 -or $token.Length -gt 4096) { throw 'The token answer has no usable token.' }
    return $token
}

function ConvertFrom-TvTitleAnswer {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    try { $answer = ConvertFrom-TvJson $Text -Limit 65536 } catch { return '' }
    if ($answer -isnot [Collections.IDictionary] -or -not $answer.ContainsKey('title')) { return '' }
    return (Limit-TvText $answer['title'] 512)
}

function ConvertFrom-TvVideoAnswer {
    # oEmbed's title and channel name (author_name). Either may be empty.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $none = [pscustomobject]@{ Title = ''; Channel = '' }
    try { $answer = ConvertFrom-TvJson $Text -Limit 65536 } catch { return $none }
    if ($answer -isnot [Collections.IDictionary]) { return $none }
    $title = if ($answer.ContainsKey('title')) { Limit-TvText $answer['title'] 512 } else { '' }
    $channel = if ($answer.ContainsKey('author_name')) { Limit-TvText $answer['author_name'] 200 } else { '' }
    return [pscustomobject]@{ Title = $title; Channel = $channel }
}

function Limit-TvText {
    # Display text: no controls or bidi overrides, at most $Bytes UTF-8 bytes,
    # never split inside a character.
    param([AllowNull()][object]$Value, [int]$Bytes = 512)
    if ($Value -isnot [string]) { return '' }
    $clean = [regex]::Replace($Value, '[\x00-\x1F\x7F-\x9F\u200E\u200F\u202A-\u202E\u2066-\u2069]', ' ').Trim()
    if (-not $clean) { return '' }
    try { $encoded = $script:Utf8.GetBytes($clean) } catch { return '' }
    if ($encoded.Length -le $Bytes) { return $clean }
    for ($length = $Bytes; $length -ge $Bytes - 4; $length--) {
        try { return $script:Utf8.GetString($encoded, 0, $length).TrimEnd() } catch {}
    }
    return ''
}

# ------------------------------------------------------------------ player state
# Events are partial: onStateChange has no video id, some nowPlaying events
# carry only a list id, and the duration is 0 while loading. Each event only
# changes what it carries; the rest of the picture is kept.

function New-TvPlayer {
    return [pscustomobject]@{
        VideoId    = ''
        ListId     = ''
        State      = $null   # the screen's player state number, $null before any
        PositionMs = 0L
        PositionAt = 0L      # unix ms when PositionMs was true
        DurationMs = 0L
        Ids        = [string[]]@()
        IdsAt      = 0L
        Screen     = $null   # $true / $false once the session says, $null before
        Autoplay   = ''      # autoplayUpNext's video, kept but not shown
        Changed    = $true
        Gone       = $false  # the screen left the session (rejoin needed)
    }
}

function Get-TvPlayName {
    # The screen's numbers as seen live: 3 loading, 1 playing, 2 paused, 0 at the
    # end of a video, -1 around starts and reconnects. 0 is the end, not buffering.
    param([AllowNull()][object]$State)
    if ($null -eq $State) { return 'unknown' }
    switch ([int]$State) {
        -1 { return 'idle' }
        0 { return 'ended' }
        1 { return 'playing' }
        2 { return 'paused' }
        3 { return 'loading' }
        5 { return 'cued' }
        1081 { return 'ad' }
    }
    return 'unknown'
}

function ConvertTo-TvMs {
    # "12.5" seconds to 12500 ms; $null for anything else.
    param([AllowNull()][object]$Value)
    $text = [string]$Value
    if ($text -cnotmatch '\A[0-9]{1,7}(?:\.[0-9]{1,6})?\z') { return $null }
    return [long][Math]::Round([double]::Parse($text, [Globalization.CultureInfo]::InvariantCulture) * 1000)
}

function ConvertTo-TvState {
    param([AllowNull()][object]$Value)
    $text = [string]$Value
    if ($text -cnotmatch '\A-?[0-9]{1,5}\z') { return $null }
    return [int]$text
}

function Get-TvIdList {
    # The comma-separated id list a screen sends with nowPlaying. Invalid ids
    # make the whole list untrustworthy, so it is dropped ($null).
    param([Parameter(Mandatory)][Collections.IDictionary]$Fields)
    foreach ($key in @('mdxExpandedReceiverVideoIdList', 'videoIds')) {
        if (-not $Fields.ContainsKey($key)) { continue }
        $text = $Fields[$key]
        if ($text -isnot [string] -or $text.Length -eq 0) { continue }
        if ($text.Length -gt 24000) { return $null }
        $ids = [string[]]@($text.Split(',') | Where-Object { $_.Length -gt 0 })
        foreach ($id in $ids) { if (-not (Test-TvVideoId $id)) { return $null } }
        return ,$ids
    }
    return $null
}

function Test-TvScreenListed {
    # loungeStatus lists the session's devices as JSON inside a string. $true
    # when a screen is among them, $false when not, $null when unreadable.
    param([AllowNull()][object]$Devices)
    if ($Devices -isnot [string]) { return $null }
    try { $list = ConvertFrom-TvJson $Devices -Limit 65536 } catch { return $null }
    if ($list -isnot [object[]]) { return $null }
    foreach ($device in $list) {
        if ($device -is [Collections.IDictionary] -and $device.ContainsKey('type') -and [string]$device['type'] -ceq 'LOUNGE_SCREEN') { return $true }
    }
    return $false
}

function Update-TvTiming {
    param([Parameter(Mandatory)][object]$Player, [Parameter(Mandatory)][Collections.IDictionary]$Fields, [long]$NowMs)
    if ($Fields.ContainsKey('state')) {
        $state = ConvertTo-TvState $Fields['state']
        if ($null -ne $state -and $state -ne $Player.State) { $Player.State = $state; $Player.Changed = $true }
    }
    if ($Fields.ContainsKey('currentTime')) {
        $position = ConvertTo-TvMs $Fields['currentTime']
        if ($null -ne $position) { $Player.PositionMs = $position; $Player.PositionAt = $NowMs; $Player.Changed = $true }
    }
    if ($Fields.ContainsKey('duration')) {
        $duration = ConvertTo-TvMs $Fields['duration']
        # 0 while loading: keep the known duration rather than forget it.
        if ($null -ne $duration -and $duration -gt 0 -and $duration -ne $Player.DurationMs) { $Player.DurationMs = $duration; $Player.Changed = $true }
    }
}

function Merge-TvEvent {
    # Applies one event to the player picture. Unknown events change nothing.
    param([Parameter(Mandatory)][object]$Player, [Parameter(Mandatory)][object]$TvEvent, [long]$NowMs = (Get-TvUnixMs))
    $fields = Get-TvEventFields $TvEvent
    switch -CaseSensitive ($TvEvent.Name) {
        'nowPlaying' {
            if ($fields.Count -eq 0) {
                # An empty nowPlaying: nothing is loaded on the screen.
                if ($Player.VideoId -or $Player.Ids.Count -gt 0) { $Player.Changed = $true }
                $Player.VideoId = ''; $Player.ListId = ''; $Player.Ids = [string[]]@(); $Player.State = $null
                $Player.PositionMs = 0L; $Player.PositionAt = 0L; $Player.DurationMs = 0L
                $Player.Screen = $true
                return
            }
            $Player.Screen = $true
            $video = if ($fields.ContainsKey('videoId')) { $fields['videoId'] } else { $null }
            if ((Test-TvVideoId $video) -and $video -cne $Player.VideoId) {
                $Player.VideoId = $video; $Player.DurationMs = 0L; $Player.PositionMs = 0L; $Player.PositionAt = $NowMs; $Player.Changed = $true
            }
            if ($fields.ContainsKey('listId')) {
                $list = $fields['listId']
                $value = if (Test-TvListId $list) { [string]$list } else { '' }
                if ($value -cne $Player.ListId) { $Player.ListId = $value; $Player.Changed = $true }
            }
            $ids = Get-TvIdList $fields
            # Always the latest list: a Mix's list grows and reorders as it settles.
            if ($null -ne $ids) {
                if (($ids -join ',') -cne ($Player.Ids -join ',')) { $Player.Changed = $true }
                $Player.Ids = $ids; $Player.IdsAt = $NowMs
            }
            Update-TvTiming $Player $fields $NowMs
        }
        'onStateChange' { $Player.Screen = $true; Update-TvTiming $Player $fields $NowMs }
        'loungeStatus' {
            if ($fields.ContainsKey('devices')) {
                $listed = Test-TvScreenListed $fields['devices']
                if ($null -ne $listed -and $listed -ne $Player.Screen) { $Player.Screen = $listed; $Player.Changed = $true }
            }
        }
        'loungeScreenDisconnected' { $Player.Screen = $false; $Player.Gone = $true; $Player.Changed = $true }
        'loungeScreenConnected' { if ($Player.Screen -ne $true) { $Player.Screen = $true; $Player.Changed = $true } }
        'autoplayUpNext' {
            $video = if ($fields.ContainsKey('videoId')) { $fields['videoId'] } else { $null }
            $Player.Autoplay = if (Test-TvVideoId $video) { [string]$video } else { '' }
        }
        'playlistModified' {
            $ids = Get-TvIdList $fields
            if ($null -ne $ids) {
                if (($ids -join ',') -cne ($Player.Ids -join ',')) { $Player.Changed = $true }
                $Player.Ids = $ids; $Player.IdsAt = $NowMs
            }
        }
    }
}

function Get-TvPositionMs {
    # Between events the position is advanced here while playing: the screen
    # reports it only with changes, not regularly.
    param([Parameter(Mandatory)][object]$Player, [long]$NowMs = (Get-TvUnixMs))
    $position = $Player.PositionMs
    if ($Player.State -eq 1 -and $Player.PositionAt -gt 0 -and $NowMs -gt $Player.PositionAt) { $position += $NowMs - $Player.PositionAt }
    if ($Player.DurationMs -gt 0 -and $position -gt $Player.DurationMs) { $position = $Player.DurationMs }
    return [long]$position
}

function Get-TvUpNext {
    # What follows the current video in the screen's id list.
    # Kind: list (the TV names the list it plays from) or none.
    # Status: none (nothing loaded), unknown (no list, a very short one, or the
    # current video is not in it), end (nothing listed after it), known.
    param([Parameter(Mandatory)][object]$Player, [ValidateRange(1,100)][int]$Limit = 20)
    $kind = 'none'
    # Only whether the TV names a list: its id does not tell a Mix from a playlist
    # (a Mix in the live gate had an id the 'RD' prefix rule calls a playlist).
    if ($Player.ListId) { $kind = 'list' }
    $result = [pscustomobject]@{ Status = 'unknown'; Ids = [string[]]@(); Total = 0; Index = -1; Kind = $kind }
    if (-not $Player.VideoId) { $result.Status = 'none'; return $result }
    $ids = $Player.Ids
    if ($ids.Count -le $script:ShortList) { return $result }
    $index = [Array]::IndexOf($ids, $Player.VideoId)
    if ($index -lt 0) { return $result }
    $result.Index = $index
    $result.Total = $ids.Count - $index - 1
    if ($result.Total -eq 0) { $result.Status = 'end'; return $result }
    $last = [Math]::Min($ids.Count - 1, $index + $Limit)
    $result.Ids = [string[]]$ids[($index + 1)..$last]
    $result.Status = 'known'
    return $result
}

# ------------------------------------------------------------------ HTTP

function New-TvWebRequest {
    param([Parameter(Mandatory)][object]$Request, [int]$TimeoutSeconds = 20)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    [Net.ServicePointManager]::Expect100Continue = $false
    $web = [Net.HttpWebRequest][Net.WebRequest]::Create($Request.Url)
    # The long poll holds one connection while commands and titles use others.
    $web.ServicePoint.ConnectionLimit = [Math]::Max($web.ServicePoint.ConnectionLimit, 6)
    $web.Method = $Request.Method
    $web.Timeout = $TimeoutSeconds * 1000
    $web.ReadWriteTimeout = $TimeoutSeconds * 1000
    $web.AllowAutoRedirect = $false
    $web.UserAgent = $script:UserAgent
    $web.Headers['Origin'] = 'https://www.youtube.com'
    if ($Request.Token) { $web.Headers['X-YouTube-LoungeId-Token'] = $Request.Token }
    if ($Request.Method -eq 'POST') {
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Request.Body)
        $web.ContentType = 'application/x-www-form-urlencoded'
        $web.ContentLength = $bytes.Length
        $stream = $web.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    return $web
}

function Get-TvFailureStatus {
    # The HTTP status inside a failure, or 0 when no answer came at all.
    param([AllowNull()][Exception]$Exception)
    while ($null -ne $Exception -and $Exception -isnot [Net.WebException]) { $Exception = $Exception.InnerException }
    if ($null -ne $Exception -and $null -ne $Exception.Response) {
        try { return [int]$Exception.Response.StatusCode } finally { $Exception.Response.Close() }
    }
    return 0
}

function Invoke-TvHttp {
    # One short request. Never throws for HTTP or network failures; the body is
    # read only up to the limit. Errors carry no request text (it holds tokens).
    # -Binary: the body as bytes (Data) instead of text, for a thumbnail.
    param([Parameter(Mandatory)][object]$Request, [ValidateRange(1,60)][int]$TimeoutSeconds = 20, [int]$Limit = $script:BodyLimit, [switch]$Binary)
    $response = $null
    try {
        $web = New-TvWebRequest $Request $TimeoutSeconds
        $response = $web.GetResponse()
        $stream = $response.GetResponseStream()
        $memory = [IO.MemoryStream]::new()
        try {
            $buffer = New-Object byte[] 8192
            while ($true) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                if ($memory.Length + $read -gt $Limit) { return [pscustomobject]@{ Status = -1; Text = ''; Kind = 'too_large' } }
                $memory.Write($buffer, 0, $read)
            }
            if ($Binary) { return [pscustomobject]@{ Status = [int]$response.StatusCode; Text = ''; Data = [byte[]]$memory.ToArray(); Kind = '' } }
            $text = [Text.Encoding]::UTF8.GetString($memory.ToArray())
        } finally { $memory.Dispose() }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Text = $text; Kind = '' }
    } catch {
        $status = Get-TvFailureStatus $_.Exception
        return [pscustomobject]@{ Status = $status; Text = ''; Kind = $(if ($status -eq 0) { 'offline' } else { 'http' }) }
    } finally {
        if ($null -ne $response) { $response.Close() }
    }
}

# ------------------------------------------------------------------ long poll
# One open GET carries the session's events. Step-TvPoll waits at most a short
# moment, so the worker can take requests, send commands on the same session and
# notice Stop while the poll stays open.

function Open-TvPoll {
    param([Parameter(Mandatory)][object]$Session, [ValidateRange(1,3600)][int]$QuietSeconds = 300)
    $web = New-TvWebRequest (New-TvPollRequest $Session) 60
    $now = Get-TvUnixMs
    return [pscustomobject]@{
        Web          = $web
        Answer       = $web.GetResponseAsync()
        Response     = $null
        Stream       = $null
        Read         = $null
        Bytes        = New-Object byte[] 8192
        Chars        = New-Object char[] 8193
        Decoder      = [Text.Encoding]::UTF8.GetDecoder()
        Frames       = New-TvFrameReader
        OpenedAt     = $now
        LastByteAt   = $now
        Received     = 0L
        QuietMs      = [long]$QuietSeconds * 1000
    }
}

function Step-TvPoll {
    # Returns Events (possibly none), Ended ($true once the poll is over),
    # Status (HTTP status of a failed poll, 0 for no answer) and Kind
    # ('' / 'ended' / 'quiet' / 'http' / 'offline' / 'broken').
    param([Parameter(Mandatory)][object]$Poll, [ValidateRange(0,5000)][int]$WaitMs = 250, [long]$NowMs = 0)
    $none = [object[]]@()
    try {
        if ($null -eq $Poll.Stream) {
            if (-not $Poll.Answer.Wait($WaitMs)) { return (Test-TvPollQuiet $Poll $NowMs) }
            $Poll.Response = $Poll.Answer.Result
            $Poll.Stream = $Poll.Response.GetResponseStream()
            $Poll.Read = $Poll.Stream.ReadAsync($Poll.Bytes, 0, $Poll.Bytes.Length)
            $WaitMs = 0
        }
        if (-not $Poll.Read.Wait($WaitMs)) { return (Test-TvPollQuiet $Poll $NowMs) }
        $count = $Poll.Read.Result
        if ($count -le 0) { return [pscustomobject]@{ Events = $none; Ended = $true; Status = 200; Kind = 'ended' } }
        $Poll.LastByteAt = if ($NowMs -gt 0) { $NowMs } else { Get-TvUnixMs }
        $Poll.Received += $count
        $length = $Poll.Decoder.GetChars($Poll.Bytes, 0, $count, $Poll.Chars, 0)
        $events = @(Read-TvFrames $Poll.Frames ([string]::new($Poll.Chars, 0, $length)))
        # A stream that never ends is renewed rather than grown without bound.
        if ($Poll.Received -gt 16MB) { return [pscustomobject]@{ Events = $events; Ended = $true; Status = 200; Kind = 'ended' } }
        $Poll.Read = $Poll.Stream.ReadAsync($Poll.Bytes, 0, $Poll.Bytes.Length)
        return [pscustomobject]@{ Events = $events; Ended = $false; Status = 200; Kind = '' }
    } catch {
        $status = Get-TvFailureStatus $_.Exception
        $kind = if ($_.Exception.Message -like '*framing*') { 'broken' } elseif ($status -eq 0) { 'offline' } else { 'http' }
        return [pscustomobject]@{ Events = $none; Ended = $true; Status = $status; Kind = $kind }
    }
}

function Test-TvPollQuiet {
    param([Parameter(Mandatory)][object]$Poll, [long]$NowMs)
    if ($NowMs -le 0) { $NowMs = Get-TvUnixMs }
    if ($NowMs - $Poll.LastByteAt -ge $Poll.QuietMs) { return [pscustomobject]@{ Events = [object[]]@(); Ended = $true; Status = 200; Kind = 'quiet' } }
    return [pscustomobject]@{ Events = [object[]]@(); Ended = $false; Status = 200; Kind = '' }
}

function Close-TvPoll {
    param([AllowNull()][object]$Poll)
    if ($null -eq $Poll) { return }
    try { $Poll.Web.Abort() } catch {}
    try { if ($null -ne $Poll.Response) { $Poll.Response.Close() } } catch {}
    # Observe a faulted task so it never surfaces later as an unhandled error.
    foreach ($task in @($Poll.Answer, $Poll.Read)) {
        if ($null -ne $task) { try { $null = $task.Wait(0) } catch {} }
    }
}

# ------------------------------------------------------------------ Cast (local network)
# Casts from Chrome (opt-in). The TV is found on
# the home network by mDNS and read over the Google Cast v2 channel (TLS, port
# 8009). Only CONNECT, GET_STATUS, PING, PONG and, to a YouTube app that is
# already running, getMdxSessionStatus are ever sent: Send-CastJson refuses
# anything else, so nothing here launches an app, plays, pauses or changes the
# volume. Play, pause and next go through the Lounge API with the cast key (the
# cast app's screen id and its token), a route obeyed in an early live test.
# Written for Parallax from protocol facts; the sources listed in README.md
# beside this file were read for names only. Nothing here runs until the worker
# calls it.

$script:CastNsConnection = 'urn:x-cast:com.google.cast.tp.connection'
$script:CastNsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat'
$script:CastNsReceiver = 'urn:x-cast:com.google.cast.receiver'
$script:CastNsMedia = 'urn:x-cast:com.google.cast.media'
$script:CastNsYouTube = 'urn:x-cast:com.google.youtube.mdx'
$script:CastYouTubeApp = '233637DE'
$script:CastService = '_googlecast._tcp.local'
# The only message types this suite sends to a Cast device.
$script:CastTypes = @('CONNECT', 'GET_STATUS', 'PING', 'PONG', 'getMdxSessionStatus')
$script:CastFrameLimit = 65536
$script:CastDiscoveryMs = 3000
# Keep-alive: a PING after this much silence from us; a device silent this
# long is gone.
$script:CastPingMs = 5000
$script:CastQuietMs = 30000
# Test-only (Set-CastForTest): fixed devices on 127.0.0.1 instead of mDNS.
$script:CastTestDevices = $null
$script:CastAllowLoopback = $false

function Set-CastForTest {
    # Test-only: discovery returns these devices instead of asking the network,
    # and 127.0.0.1 counts as a device address. Every device must be on
    # 127.0.0.1. Nothing in the shipped skin calls this.
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Devices)
    foreach ($device in $Devices) { if ([string]$device.Address -cne '127.0.0.1') { throw 'Test Cast devices must be on 127.0.0.1.' } }
    $script:CastTestDevices = [object[]]@($Devices)
    $script:CastAllowLoopback = $true
}

function Test-CastAddress {
    # A private (10/8, 172.16/12, 192.168/16) or link-local (169.254/16) IPv4
    # address. Nothing else is ever connected to.
    param([AllowNull()][object]$Address)
    if ($Address -isnot [string] -or $Address -cnotmatch '\A[0-9]{1,3}(?:\.[0-9]{1,3}){3}\z') { return $false }
    $parts = [int[]]$Address.Split('.')
    foreach ($part in $parts) { if ($part -gt 255) { return $false } }
    if ($script:CastAllowLoopback -and $Address -ceq '127.0.0.1') { return $true }
    if ($parts[0] -eq 10) { return $true }
    if ($parts[0] -eq 172 -and $parts[1] -ge 16 -and $parts[1] -le 31) { return $true }
    if ($parts[0] -eq 192 -and $parts[1] -eq 168) { return $true }
    if ($parts[0] -eq 169 -and $parts[1] -eq 254) { return $true }
    return $false
}

# ---------------------------------------------------------- mDNS (RFC 6762/6763)

function New-CastMdnsQuery {
    # One question: PTR records of the Cast service, unicast answer preferred.
    $bytes = [Collections.Generic.List[byte]]::new()
    foreach ($value in 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0) { $bytes.Add([byte]$value) }
    foreach ($label in $script:CastService.Split('.')) {
        $text = [Text.Encoding]::ASCII.GetBytes($label)
        $bytes.Add([byte]$text.Length)
        $bytes.AddRange([byte[]]$text)
    }
    foreach ($value in 0, 0, 12, 0x80, 1) { $bytes.Add([byte]$value) }
    return ,$bytes.ToArray()
}

function Read-CastU16 { param([byte[]]$Data, [int]$At); if ($At + 1 -ge $Data.Length) { throw 'DNS field runs past the packet.' }; return ([int]$Data[$At] * 256) + [int]$Data[$At + 1] }

function Read-CastDnsName {
    param([Parameter(Mandatory)][byte[]]$Data, [int]$At)
    $labels = [Collections.Generic.List[string]]::new()
    $position = $At
    $next = -1
    $jumps = 0
    while ($true) {
        if ($position -ge $Data.Length) { throw 'DNS name runs past the packet.' }
        $length = [int]$Data[$position]
        if ($length -eq 0) { $position++; break }
        if (($length -band 0xC0) -eq 0xC0) {
            if ($position + 1 -ge $Data.Length) { throw 'DNS name runs past the packet.' }
            if ($next -lt 0) { $next = $position + 2 }
            $position = (($length -band 0x3F) * 256) + [int]$Data[$position + 1]
            $jumps++
            if ($jumps -gt 16) { throw 'DNS name loops.' }
            continue
        }
        if (($length -band 0xC0) -ne 0 -or $position + 1 + $length -gt $Data.Length -or $labels.Count -ge 32) { throw 'Bad DNS label.' }
        $labels.Add([Text.Encoding]::UTF8.GetString($Data, $position + 1, $length))
        $position += 1 + $length
    }
    if ($next -lt 0) { $next = $position }
    return [pscustomobject]@{ Name = ($labels -join '.'); Next = $next }
}

function Read-CastMdnsRecords {
    # The PTR, SRV, TXT and A records of one answer. Throws on a broken packet.
    param([Parameter(Mandatory)][byte[]]$Data)
    if ($Data.Length -lt 12) { return }
    $questions = Read-CastU16 $Data 4
    $total = (Read-CastU16 $Data 6) + (Read-CastU16 $Data 8) + (Read-CastU16 $Data 10)
    if ($questions -gt 16 -or $total -gt 128) { throw 'Too many DNS records.' }
    $at = 12
    for ($i = 0; $i -lt $questions; $i++) { $at = (Read-CastDnsName $Data $at).Next + 4 }
    for ($i = 0; $i -lt $total; $i++) {
        $owner = Read-CastDnsName $Data $at
        $at = $owner.Next
        $type = Read-CastU16 $Data $at
        $length = Read-CastU16 $Data ($at + 8)
        $start = $at + 10
        $at = $start + $length
        if ($at -gt $Data.Length) { throw 'DNS record runs past the packet.' }
        switch ($type) {
            12 { [pscustomobject]@{ Name = $owner.Name; Type = 'PTR'; Value = (Read-CastDnsName $Data $start).Name } }
            33 { if ($length -ge 7) { [pscustomobject]@{ Name = $owner.Name; Type = 'SRV'; Value = [pscustomobject]@{ Port = (Read-CastU16 $Data ($start + 4)); Target = (Read-CastDnsName $Data ($start + 6)).Name } } } }
            16 {
                $entries = @{}
                $cursor = $start
                while ($cursor -lt $at) {
                    $size = [int]$Data[$cursor]
                    if ($cursor + 1 + $size -gt $at) { break }
                    $text = [Text.Encoding]::UTF8.GetString($Data, $cursor + 1, $size)
                    $equals = $text.IndexOf('=')
                    if ($equals -gt 0) { $entries[$text.Substring(0, $equals).ToLowerInvariant()] = $text.Substring($equals + 1) }
                    $cursor += 1 + $size
                }
                [pscustomobject]@{ Name = $owner.Name; Type = 'TXT'; Value = $entries }
            }
            1 { if ($length -eq 4) { [pscustomobject]@{ Name = $owner.Name; Type = 'A'; Value = ('{0}.{1}.{2}.{3}' -f $Data[$start], $Data[$start + 1], $Data[$start + 2], $Data[$start + 3]) } } }
        }
    }
}

function Get-CastDevicesFromRecords {
    # Cast devices named in the records: Name (TXT fn), Id (TXT id), Address,
    # Port. $From maps an instance to the address that answered for it. Only
    # private or link-local addresses are kept.
    param([object[]]$Records = @(), [hashtable]$From = @{})
    $seen = @{}
    $instances = @($Records | Where-Object { $_.Type -ceq 'PTR' -and $_.Name -eq $script:CastService } | ForEach-Object { [string]$_.Value } | Sort-Object -Unique)
    foreach ($instance in $instances) {
        $service = @($Records | Where-Object { $_.Type -ceq 'SRV' -and $_.Name -eq $instance }) | Select-Object -First 1
        $text = @($Records | Where-Object { $_.Type -ceq 'TXT' -and $_.Name -eq $instance }) | Select-Object -First 1
        $address = $null
        $port = 8009
        if ($service) {
            if ($service.Value.Port -ge 1) { $port = [int]$service.Value.Port }
            $host4 = @($Records | Where-Object { $_.Type -ceq 'A' -and $_.Name -eq $service.Value.Target }) | Select-Object -First 1
            if ($host4) { $address = $host4.Value }
        }
        if (-not $address -and $From.ContainsKey($instance)) { $address = $From[$instance] }
        $key = [string]$address + '|' + $port
        if (-not (Test-CastAddress $address) -or $seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $values = if ($text) { $text.Value } else { @{} }
        $id = if ($values.ContainsKey('id') -and $values['id'] -cmatch '\A[A-Za-z0-9-]{1,64}\z') { [string]$values['id'] } else { '' }
        [pscustomobject]@{ Name = (Limit-TvText $values['fn'] 200); Id = $id; Address = [string]$address; Port = $port }
    }
}

function Start-CastDiscovery {
    # Asks once for Cast devices on each private IPv4 network this PC is on and
    # returns at once; Step-CastDiscovery collects the answers for about 3 s.
    $now = Get-TvUnixMs
    $discovery = [pscustomobject]@{ Clients = [Collections.Generic.List[object]]::new(); Records = [Collections.Generic.List[object]]::new(); From = @{}; Until = $now + $script:CastDiscoveryMs; Test = $null }
    if ($null -ne $script:CastTestDevices) { $discovery.Test = $script:CastTestDevices; $discovery.Until = $now; return $discovery }
    $query = [byte[]](New-CastMdnsQuery)
    $group = [Net.IPEndPoint]::new([Net.IPAddress]::Parse('224.0.0.251'), 5353)
    foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($adapter.OperationalStatus -ne 'Up' -or $adapter.NetworkInterfaceType -eq 'Loopback' -or -not $adapter.SupportsMulticast) { continue }
        foreach ($unicast in $adapter.GetIPProperties().UnicastAddresses) {
            if ($unicast.Address.AddressFamily -ne 'InterNetwork' -or -not (Test-CastAddress $unicast.Address.ToString())) { continue }
            $client = $null
            try {
                $client = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new($unicast.Address, 0))
                $null = $client.Send($query, $query.Length, $group)
                $discovery.Clients.Add($client)
                $client = $null
            } catch {} finally { if ($null -ne $client) { $client.Close() } }
        }
    }
    return $discovery
}

function Step-CastDiscovery {
    # $null while answers may still come; then the devices found (an array,
    # possibly empty), with the sockets closed.
    param([Parameter(Mandatory)][object]$Discovery, [long]$NowMs = (Get-TvUnixMs))
    if ($null -ne $Discovery.Test) { return ,[object[]]@($Discovery.Test | Where-Object { Test-CastAddress ([string]$_.Address) }) }
    foreach ($client in $Discovery.Clients) {
        try {
            $count = 0
            while ($client.Available -gt 0 -and $count -lt 64) {
                $count++
                $sender = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
                $packet = $client.Receive([ref]$sender)
                if ($packet.Length -gt 9000) { continue }
                try {
                    foreach ($record in @(Read-CastMdnsRecords $packet)) {
                        if ($Discovery.Records.Count -lt 512) { $Discovery.Records.Add($record) }
                        if ($record.Type -ceq 'PTR') { $Discovery.From[[string]$record.Value] = $sender.Address.ToString() }
                    }
                } catch {}
            }
        } catch {}
    }
    if ($NowMs -lt $Discovery.Until) { return $null }
    Stop-CastDiscovery $Discovery
    return ,[object[]]@(Get-CastDevicesFromRecords -Records $Discovery.Records.ToArray() -From $Discovery.From)
}

function Stop-CastDiscovery {
    param([AllowNull()][object]$Discovery)
    if ($null -eq $Discovery) { return }
    foreach ($client in $Discovery.Clients) { try { $client.Close() } catch {} }
    $Discovery.Clients.Clear()
}

# ---------------------------------------------------------- Cast messages
# CastMessage (protobuf): 1 protocol version (0), 2 source, 3 destination,
# 4 namespace, 5 payload type (0 = text), 6 UTF-8 payload. Each frame on the
# wire is a 4-byte big-endian length and one message.

function Add-CastVarint { param($Bytes, [long]$Value)
    do {
        $part = [int]($Value -band 0x7F)
        $Value = $Value -shr 7
        if ($Value -gt 0) { $part = $part -bor 0x80 }
        $Bytes.Add([byte]$part)
    } while ($Value -gt 0)
}

function Add-CastText { param($Bytes, [int]$Field, [string]$Text)
    $utf8 = [byte[]]$script:Utf8.GetBytes($Text)
    Add-CastVarint $Bytes (($Field * 8) + 2)
    Add-CastVarint $Bytes $utf8.Length
    $Bytes.AddRange($utf8)
}

function ConvertTo-CastMessage {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination, [Parameter(Mandatory)][string]$Namespace, [Parameter(Mandatory)][string]$Payload)
    $bytes = [Collections.Generic.List[byte]]::new()
    Add-CastVarint $bytes 8; Add-CastVarint $bytes 0
    Add-CastText $bytes 2 $Source
    Add-CastText $bytes 3 $Destination
    Add-CastText $bytes 4 $Namespace
    Add-CastVarint $bytes 40; Add-CastVarint $bytes 0
    Add-CastText $bytes 6 $Payload
    return ,$bytes.ToArray()
}

function Read-CastVarint { param([byte[]]$Data, [ref]$At)
    $value = [long]0
    $shift = 0
    while ($true) {
        if ($At.Value -ge $Data.Length -or $shift -gt 56) { throw 'Bad Cast varint.' }
        $part = [int]$Data[$At.Value]
        $At.Value++
        $value = $value -bor ([long]($part -band 0x7F) -shl $shift)
        if (($part -band 0x80) -eq 0) { return $value }
        $shift += 7
    }
}

function ConvertFrom-CastMessage {
    # Source, Destination, Namespace and Payload (text) of one message. Binary
    # payloads and unknown fields are skipped; a broken message throws.
    param([Parameter(Mandatory)][byte[]]$Data)
    $message = [ordered]@{ Source = ''; Destination = ''; Namespace = ''; Payload = '' }
    $at = 0
    while ($at -lt $Data.Length) {
        $tag = Read-CastVarint $Data ([ref]$at)
        $field = $tag -shr 3
        $wire = $tag -band 7
        if ($wire -eq 0) { $null = Read-CastVarint $Data ([ref]$at) }
        elseif ($wire -eq 1) { $at += 8 }
        elseif ($wire -eq 5) { $at += 4 }
        elseif ($wire -eq 2) {
            $length = [long](Read-CastVarint $Data ([ref]$at))
            if ($length -lt 0 -or $at + $length -gt $Data.Length) { throw 'Cast field runs past the message.' }
            if ($field -in 2, 3, 4, 6) {
                $text = $script:Utf8.GetString($Data, $at, [int]$length)
                switch ($field) { 2 { $message.Source = $text } 3 { $message.Destination = $text } 4 { $message.Namespace = $text } 6 { $message.Payload = $text } }
            }
            $at += [int]$length
        } else { throw 'Unknown Cast wire type.' }
        if ($at -gt $Data.Length) { throw 'Cast field runs past the message.' }
    }
    return [pscustomobject]$message
}

function ConvertTo-CastFrame {
    param([Parameter(Mandatory)][byte[]]$Message)
    $length = $Message.Length
    $frame = New-Object byte[] (4 + $length)
    $frame[0] = [byte](($length -shr 24) -band 0xFF); $frame[1] = [byte](($length -shr 16) -band 0xFF)
    $frame[2] = [byte](($length -shr 8) -band 0xFF); $frame[3] = [byte]($length -band 0xFF)
    [Array]::Copy($Message, 0, $frame, 4, $length)
    return ,$frame
}

function Read-CastFrames {
    # Takes every whole frame out of a buffer (MemoryStream) and leaves the rest.
    param([Parameter(Mandatory)][IO.MemoryStream]$Buffer)
    $frames = [Collections.Generic.List[object]]::new()
    $data = $Buffer.ToArray()
    $at = 0
    while ($data.Length - $at -ge 4) {
        $length = ([long]$data[$at] -shl 24) -bor ([long]$data[$at + 1] -shl 16) -bor ([long]$data[$at + 2] -shl 8) -bor [long]$data[$at + 3]
        if ($length -le 0 -or $length -gt $script:CastFrameLimit) { throw 'Unreasonable Cast frame length.' }
        if ($data.Length - $at - 4 -lt $length) { break }
        $message = New-Object byte[] $length
        [Array]::Copy($data, $at + 4, $message, 0, $length)
        $frames.Add($message)
        $at += 4 + [int]$length
    }
    $Buffer.SetLength(0)
    if ($at -lt $data.Length) { $Buffer.Write($data, $at, $data.Length - $at) }
    return ,$frames.ToArray()
}

# ---------------------------------------------------------- Cast channel

function Open-CastLink {
    # TLS to one Cast device and a CONNECT to its platform. Cast devices show a
    # self-signed certificate that no Windows root vouches for, so this one
    # stream accepts the device's certificate unchecked. That is scoped to this
    # SslStream only (never ServicePointManager), so HTTPS to YouTube keeps its
    # full checks. The channel is encrypted, but the device is not authenticated:
    # see the TvQueue README, Casts.
    param([Parameter(Mandatory)][string]$Address, [ValidateRange(1, 65535)][int]$Port = 8009, [ValidateRange(200, 10000)][int]$TimeoutMs = 3000)
    if (-not (Test-CastAddress $Address)) { throw 'Not a private network address.' }
    $tcp = [Net.Sockets.TcpClient]::new([Net.Sockets.AddressFamily]::InterNetwork)
    try {
        $connect = $tcp.ConnectAsync([Net.IPAddress]::Parse($Address), $Port)
        $done = $false
        try { $done = $connect.Wait($TimeoutMs) } catch { throw 'The Cast device refused the connection.' }
        if (-not $done) { throw 'No answer from the Cast device.' }
        $tcp.NoDelay = $true
        $network = $tcp.GetStream()
        $network.ReadTimeout = $TimeoutMs
        $network.WriteTimeout = $TimeoutMs
        $accept = [Net.Security.RemoteCertificateValidationCallback] { param($sender, $certificate, $chain, $errors) return ($null -ne $certificate) }
        $ssl = [Net.Security.SslStream]::new($network, $false, $accept)
        $ssl.AuthenticateAsClient($Address, $null, [Security.Authentication.SslProtocols]::Tls12, $false)
        $now = Get-TvUnixMs
        $link = [pscustomobject]@{
            Tcp = $tcp; Stream = $ssl; Read = $null; Bytes = (New-Object byte[] 16384); Buffer = [IO.MemoryStream]::new()
            Address = $Address; Port = $Port; OpenedAt = $now; LastSentMs = 0L; LastHeardMs = $now; NextId = 1
        }
        Send-CastJson $link 'receiver-0' $script:CastNsConnection @{ type = 'CONNECT' }
        return $link
    } catch {
        $tcp.Close()
        throw
    }
}

function Send-CastJson {
    # One message to the device. Only the types in $CastTypes are ever sent.
    param([Parameter(Mandatory)][object]$Link, [Parameter(Mandatory)][string]$Destination, [Parameter(Mandatory)][string]$Namespace, [Parameter(Mandatory)][Collections.IDictionary]$Body)
    if ([string]$Body['type'] -cnotin $script:CastTypes) { throw 'Not a message this suite sends to a Cast device.' }
    if ($Body['type'] -ceq 'GET_STATUS') { $Body['requestId'] = $Link.NextId; $Link.NextId++ }
    Add-Type -AssemblyName System.Web.Extensions
    $payload = [Web.Script.Serialization.JavaScriptSerializer]::new().Serialize($Body)
    $frame = ConvertTo-CastFrame (ConvertTo-CastMessage 'sender-0' $Destination $Namespace $payload)
    $Link.Stream.Write($frame, 0, $frame.Length)
    $Link.Stream.Flush()
    $Link.LastSentMs = Get-TvUnixMs
}

function Step-CastLink {
    # Waits at most $WaitMs for the device; returns Messages (Source, Namespace,
    # Body: a dictionary with a 'type') and Ended with Kind (closed, quiet,
    # broken). Answers the device's PING and keeps the channel alive.
    param([Parameter(Mandatory)][object]$Link, [ValidateRange(0, 5000)][int]$WaitMs = 0)
    $messages = [Collections.Generic.List[object]]::new()
    try {
        if ($null -eq $Link.Read) { $Link.Read = $Link.Stream.ReadAsync($Link.Bytes, 0, $Link.Bytes.Length) }
        while ($Link.Read.Wait($WaitMs)) {
            $count = $Link.Read.Result
            if ($count -le 0) { return [pscustomobject]@{ Messages = $messages.ToArray(); Ended = $true; Kind = 'closed' } }
            $Link.Buffer.Write($Link.Bytes, 0, $count)
            if ($Link.Buffer.Length -gt 4 * $script:CastFrameLimit) { throw 'Cast buffer overflow.' }
            $Link.LastHeardMs = Get-TvUnixMs
            $Link.Read = $Link.Stream.ReadAsync($Link.Bytes, 0, $Link.Bytes.Length)
            $WaitMs = 0
        }
        foreach ($frame in (Read-CastFrames $Link.Buffer)) {
            $message = ConvertFrom-CastMessage $frame
            if (-not $message.Payload) { continue }
            $body = $null
            try { $body = ConvertFrom-TvJson $message.Payload -Limit $script:CastFrameLimit } catch { continue }
            if ($body -isnot [Collections.IDictionary] -or -not $body.ContainsKey('type') -or $body['type'] -isnot [string]) { continue }
            if ($message.Namespace -ceq $script:CastNsHeartbeat) {
                if ($body['type'] -ceq 'PING' -and $message.Source -cmatch '\A[!-~]{1,128}\z') { Send-CastJson $Link $message.Source $script:CastNsHeartbeat @{ type = 'PONG' } }
                continue
            }
            $messages.Add([pscustomobject]@{ Source = $message.Source; Namespace = $message.Namespace; Body = $body })
        }
        $now = Get-TvUnixMs
        if ($now - $Link.LastHeardMs -ge $script:CastQuietMs) { return [pscustomobject]@{ Messages = $messages.ToArray(); Ended = $true; Kind = 'quiet' } }
        if ($now - $Link.LastSentMs -ge $script:CastPingMs) { Send-CastJson $Link 'receiver-0' $script:CastNsHeartbeat @{ type = 'PING' } }
        return [pscustomobject]@{ Messages = $messages.ToArray(); Ended = $false; Kind = '' }
    } catch {
        return [pscustomobject]@{ Messages = $messages.ToArray(); Ended = $true; Kind = 'broken' }
    }
}

function Close-CastLink {
    param([AllowNull()][object]$Link)
    if ($null -eq $Link) { return }
    try { $Link.Stream.Dispose() } catch {}
    try { $Link.Tcp.Close() } catch {}
    if ($null -ne $Link.Read) { try { $null = $Link.Read.Wait(0) } catch {} }
    try { $Link.Buffer.Dispose() } catch {}
}

# ---------------------------------------------------------- Cast status

function Get-CastApps {
    # The apps a RECEIVER_STATUS lists: AppId, SessionId, TransportId and the
    # namespaces each offers. Entries of another shape are skipped.
    param([Parameter(Mandatory)][Collections.IDictionary]$Body)
    $apps = [Collections.Generic.List[object]]::new()
    if ($Body['type'] -cne 'RECEIVER_STATUS' -or $Body['status'] -isnot [Collections.IDictionary]) { return ,$apps.ToArray() }
    $list = $Body['status']['applications']
    if ($list -isnot [object[]]) { return ,$apps.ToArray() }
    foreach ($app in $list) {
        if ($app -isnot [Collections.IDictionary]) { continue }
        $names = [Collections.Generic.List[string]]::new()
        if ($app['namespaces'] -is [object[]]) { foreach ($entry in $app['namespaces']) { if ($entry -is [Collections.IDictionary] -and $entry['name'] -is [string]) { $names.Add($entry['name']) } } }
        $transport = if ($app['transportId'] -is [string] -and $app['transportId'] -cmatch '\A[!-~]{1,128}\z') { $app['transportId'] } else { '' }
        $session = if ($app['sessionId'] -is [string] -and $app['sessionId'] -cmatch '\A[!-~]{1,128}\z') { $app['sessionId'] } else { '' }
        $apps.Add([pscustomobject]@{ AppId = [string]$app['appId']; SessionId = $session; TransportId = $transport; Namespaces = $names.ToArray() })
    }
    return ,$apps.ToArray()
}

function Select-CastYouTube {
    # The running YouTube app that offers its remote-control namespace, or $null.
    param([AllowEmptyCollection()][object[]]$Apps = @())
    foreach ($app in $Apps) {
        if ($app.AppId -ceq $script:CastYouTubeApp -and $app.TransportId -and $app.Namespaces -ccontains $script:CastNsYouTube) { return $app }
    }
    return $null
}

function New-CastPicture {
    # What a cast plays, in the TV player's shape (Get-TvPositionMs and
    # Get-TvPlayName apply), plus the title and subtitle Cast reports.
    $picture = New-TvPlayer
    $picture.Screen = $true
    $picture | Add-Member -NotePropertyName Title -NotePropertyValue ''
    $picture | Add-Member -NotePropertyName Subtitle -NotePropertyValue ''
    $picture | Add-Member -NotePropertyName Loaded -NotePropertyValue $false
    return $picture
}

function ConvertTo-CastMs {
    # Seconds as a JSON number to milliseconds; $null for anything else.
    param([AllowNull()][object]$Value)
    if (-not ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [double])) { return $null }
    $seconds = [double]$Value
    if ($seconds -lt 0 -or $seconds -gt 3.6e6) { return $null }
    return [long][Math]::Round($seconds * 1000)
}

function Merge-CastMediaStatus {
    # Applies a MEDIA_STATUS. Cast leaves out the media while it is unchanged,
    # so only what an answer carries changes; an empty status list means
    # nothing is loaded.
    param([Parameter(Mandatory)][object]$Picture, [Parameter(Mandatory)][Collections.IDictionary]$Body, [long]$NowMs = (Get-TvUnixMs))
    if ($Body['type'] -cne 'MEDIA_STATUS' -or $Body['status'] -isnot [object[]]) { return }
    $was = '{0}|{1}|{2}|{3}' -f $Picture.VideoId, $Picture.State, $Picture.Title, $Picture.Loaded
    if ($Body['status'].Count -eq 0) {
        $Picture.VideoId = ''; $Picture.State = $null; $Picture.Title = ''; $Picture.Subtitle = ''
        $Picture.PositionMs = 0L; $Picture.PositionAt = 0L; $Picture.DurationMs = 0L; $Picture.Loaded = $false
    } else {
        $status = $Body['status'][0]
        if ($status -isnot [Collections.IDictionary]) { return }
        $media = $status['media']
        if ($media -is [Collections.IDictionary]) {
            $video = $media['contentId']
            if ((Test-TvVideoId $video) -and $video -cne $Picture.VideoId) {
                $Picture.VideoId = $video; $Picture.Title = ''; $Picture.Subtitle = ''; $Picture.DurationMs = 0L; $Picture.PositionMs = 0L; $Picture.PositionAt = $NowMs
            }
            $duration = ConvertTo-CastMs $media['duration']
            if ($null -ne $duration -and $duration -gt 0) { $Picture.DurationMs = $duration }
            $metadata = $media['metadata']
            if ($metadata -is [Collections.IDictionary]) {
                if ($metadata.ContainsKey('title')) { $Picture.Title = Limit-TvText $metadata['title'] 512 }
                if ($metadata.ContainsKey('subtitle')) { $Picture.Subtitle = Limit-TvText $metadata['subtitle'] 200 }
            }
        }
        $state = switch -CaseSensitive ([string]$status['playerState']) {
            'PLAYING' { 1 } 'PAUSED' { 2 } 'BUFFERING' { 3 }
            'IDLE' { if ([string]$status['idleReason'] -ceq 'FINISHED') { 0 } else { -1 } }
            default { $null }
        }
        if ($null -ne $state) { $Picture.State = $state }
        $position = ConvertTo-CastMs $status['currentTime']
        if ($null -ne $position) { $Picture.PositionMs = $position; $Picture.PositionAt = $NowMs; $Picture.Changed = $true }
        $Picture.Loaded = [bool]$Picture.VideoId -and $null -ne $Picture.State -and $Picture.State -ne -1
    }
    if (('{0}|{1}|{2}|{3}' -f $Picture.VideoId, $Picture.State, $Picture.Title, $Picture.Loaded) -cne $was) { $Picture.Changed = $true }
}

function Get-CastScreenId {
    # The screen id in an mdxSessionStatus answer, or ''. It is a credential:
    # the caller keeps it sealed and never logs or shows it.
    param([Parameter(Mandatory)][Collections.IDictionary]$Body)
    if ($Body['type'] -cne 'mdxSessionStatus' -or $Body['data'] -isnot [Collections.IDictionary]) { return '' }
    $id = $Body['data']['screenId']
    if ($id -is [string] -and $id -cmatch '\A[!-~]{1,512}\z') { return $id }
    return ''
}

Export-ModuleMember -Function Get-TvUnixMs, Set-TvEndpointForTest, Test-TvVideoId, Test-TvListId, ConvertFrom-TvJson,
    New-TvFrameReader, Read-TvFrames, ConvertTo-TvEvents, Get-TvEventFields,
    New-TvSession, Update-TvSession, New-TvBindRequest, New-TvPollRequest, New-TvCommandRequest, New-TvLeaveRequest,
    New-TvPairRequest, New-TvTokenRequest, New-TvTitleRequest, New-TvThumbRequest, ConvertFrom-TvPairAnswer, ConvertFrom-TvTokenAnswer, ConvertFrom-TvTitleAnswer, ConvertFrom-TvVideoAnswer, Limit-TvText,
    New-TvPlayer, Get-TvPlayName, Merge-TvEvent, Get-TvPositionMs, Get-TvUpNext,
    Invoke-TvHttp, Open-TvPoll, Step-TvPoll, Close-TvPoll,
    Set-CastForTest, Test-CastAddress, New-CastMdnsQuery, Read-CastMdnsRecords, Get-CastDevicesFromRecords, Start-CastDiscovery, Step-CastDiscovery, Stop-CastDiscovery,
    ConvertTo-CastMessage, ConvertFrom-CastMessage, ConvertTo-CastFrame, Read-CastFrames, Open-CastLink, Send-CastJson, Step-CastLink, Close-CastLink,
    Get-CastApps, Select-CastYouTube, New-CastPicture, Merge-CastMediaStatus, Get-CastScreenId
