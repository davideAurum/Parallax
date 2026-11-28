# Developer-only offline tests for the TV queue core (M1): framing, session,
# event merge, up next, DPAPI pairing, snapshot, requests, and HTTP against a
# stand-in on 127.0.0.1. Nothing reaches a TV or YouTube. All data is made up.
# Host: Windows PowerShell 5.1 (powershell.exe), a normal user (DPAPI).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCore.ps1
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$here = Split-Path -Parent $PSScriptRoot
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
function Assert-Throws { param([scriptblock]$Block, [string]$Message); $threw = $false; try { & $Block } catch { $threw = $true }; Assert-Check $threw $Message }

foreach ($file in Get-ChildItem -LiteralPath $here -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.psm1' }) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-Check ($errors.Count -eq 0) "$($file.Name) parses"
    $raw = [IO.File]::ReadAllBytes($file.FullName)
    Assert-Check (@($raw | Where-Object { $_ -gt 127 }).Count -eq 0) "$($file.Name) is plain ASCII (Windows PowerShell 5.1 reads it as ANSI)"
}
Import-Module (Join-Path $here 'TvLounge.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $here 'TvStore.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'TvStandIn.ps1')

# Made-up ids: 11 characters, never real videos.
function Get-FakeId([int]$Number) { return ('vid' + $Number.ToString('00000000')) }
function New-Event([string]$Name, $Data = $null, [long]$Id = 1) {
    [object[]]$items = @()
    if ($null -ne $Data) { $items = [object[]]@(, $Data) }
    return [pscustomobject]@{ Id = $Id; Name = $Name; Data = $items }
}
$ids = 1..140 | ForEach-Object { Get-FakeId $_ }

# ------------------------------------------------------------------ framing
function Frame([string]$Json) { return "$($Json.Length)`n$Json" }
$streamText = (Frame '[[0,["c","SID-X","",8]],[1,["S","GS-X"]]]') + "`n" +
    (Frame ('[[2,["loungeStatus",{"devices":"[{\"type\":\"LOUNGE_SCREEN\",\"name\":\"T\"}]"}]],[3,["nowPlaying",{"videoId":"' + $ids[0] + '","state":"1","listId":"RDmix0001"}]]]')) +
    (Frame '[[4,["noop"]]]') + (Frame '[[5,["onStateChange",{"state":"2","currentTime":"3.5"}]]]')
$wanted = 'c,S,loungeStatus,nowPlaying,noop,onStateChange'
for ($split = 0; $split -le $streamText.Length; $split++) {
    $reader = New-TvFrameReader
    $events = @(Read-TvFrames $reader $streamText.Substring(0, $split)) + @(Read-TvFrames $reader $streamText.Substring($split))
    if ((@($events | ForEach-Object { $_.Name }) -join ',') -cne $wanted) { throw "FAILED: framing split at $split" }
}
Assert-Check $true 'framing gives the same events split at every position'
$reader = New-TvFrameReader
$byChar = foreach ($char in $streamText.ToCharArray()) { Read-TvFrames $reader ([string]$char) }
Assert-Check ((@($byChar | ForEach-Object { $_.Name }) -join ',') -ceq $wanted) 'framing fed one character at a time'
Assert-Check ($events[0].Data[0] -ceq 'SID-X' -and $events[4].Data.Count -eq 0 -and $events[3].Id -eq 3) 'event id, name and data kept; no-data event has none'
Assert-Throws { Read-TvFrames (New-TvFrameReader) "<html><body>not framed at all</body></html>" } 'text without a length line is refused'
Assert-Throws { Read-TvFrames (New-TvFrameReader) "12x`n[]" } 'a bad length line is refused'
Assert-Throws { Read-TvFrames (New-TvFrameReader) "99999999`n" } 'an oversized length is refused'
$odd = @(Read-TvFrames (New-TvFrameReader) (Frame '[[1,["ok"]],"x",[2],[-1,["neg"]],[3,[7]],[4,["fine",{"a":"b"}]]]'))
Assert-Check ((@($odd | ForEach-Object { $_.Name }) -join ',') -ceq 'ok,fine') 'entries of an unexpected shape are skipped'
$single = @(Read-TvFrames (New-TvFrameReader) (Frame '[[9,["one"]]]'))
Assert-Check ($single.Count -eq 1 -and $single[0].Name -ceq 'one') 'a one-event chunk stays one event'

# ------------------------------------------------------------------ session and requests
$pairing = [pscustomobject]@{ Name = 'Stand-in TV'; PairedAt = 1; DeviceId = [Guid]::NewGuid().ToString(); ScreenId = 'SCREEN-SECRET-0001'; LoungeToken = 'TOKEN-SECRET-A' }
$session = New-TvSession $pairing
foreach ($e in $events) { Update-TvSession $session $e }
Assert-Check ($session.Sid -ceq 'SID-X' -and $session.GSession -ceq 'GS-X' -and $session.Aid -eq 5) 'session ids and the last event id are tracked'
Update-TvSession $session (New-Event 'c' 'bad value with spaces' 2)
Assert-Check ($session.Sid -ceq 'SID-X' -and $session.Aid -eq 5) 'an implausible session id and an older event id change nothing'
$bind = New-TvBindRequest (New-TvSession $pairing)
Assert-Check ($bind.Method -eq 'POST' -and $bind.Url -like '*/bc/bind?RID=1&VER=8*' -and $bind.Body -like '*device=REMOTE_CONTROL*' -and $bind.Token -ceq 'TOKEN-SECRET-A') 'bind request shape'
$first = New-TvCommandRequest $session 'pause'
$second = New-TvCommandRequest $session 'setPlaylist' ([ordered]@{ videoId = $ids[3]; currentIndex = '3' })
Assert-Check ($first.Url -like '*SID=SID-X*' -and $first.Url -like '*AID=5*' -and $first.Url -like '*RID=2*' -and $first.Body -ceq 'count=1&ofs=1&req0__sc=pause') 'first command: same session, next request number, ofs 1'
Assert-Check ($second.Url -like '*RID=3*' -and $second.Body -like 'count=1&ofs=2&req0__sc=setPlaylist&req0_videoId=*&req0_currentIndex=3') 'second command counts on; fields are req0_ prefixed'
Assert-Throws { New-TvCommandRequest $session 'removeVideo' } 'commands outside the known set are refused'
$poll = New-TvPollRequest $session
Assert-Check ($poll.Method -eq 'GET' -and $poll.Url -like '*RID=rpc*' -and $poll.Url -like '*TYPE=xmlhttp*') 'poll request shape'
$leave = New-TvLeaveRequest $session
Assert-Check ($leave.Body -like '*TYPE=terminate*' -and $leave.Url -like '*RID=4*') 'leave request shape'
Assert-Throws { New-TvTitleRequest 'not-an-id' } 'title lookups take only a video id'
Assert-Check ((New-TvTitleRequest $ids[0]).Url -like '*oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D*') 'title lookup sends only the watch address'

$answer = ConvertFrom-TvPairAnswer '{"screen":{"screenId":"S1","loungeToken":"T1","name":"Living\u202eroom\u0007TV","expiration":1}}'
Assert-Check ($answer.ScreenId -ceq 'S1' -and $answer.LoungeToken -ceq 'T1' -and $answer.Name -ceq 'Living room TV') 'pairing answer read; name cleaned of controls and bidi overrides'
Assert-Throws { ConvertFrom-TvPairAnswer '{"screen":{"name":"x"}}' } 'a pairing answer without id and token is refused'
Assert-Throws { ConvertFrom-TvPairAnswer '<html>' } 'a non-JSON pairing answer is refused'
Assert-Check ((ConvertFrom-TvTokenAnswer '{"screens":[{"screenId":"S1","loungeToken":"T2"}]}') -ceq 'T2') 'token answer read'
Assert-Throws { ConvertFrom-TvTokenAnswer '{"screens":[]}' } 'an empty token answer is refused'
Assert-Check ((ConvertFrom-TvTitleAnswer '{"title":"Song\u0000 One"}') -ceq 'Song  One' -and (ConvertFrom-TvTitleAnswer 'x') -ceq '') 'title answer read; junk gives no title'
$video = ConvertFrom-TvVideoAnswer '{"title":"A","author_name":"Chan\u202Enel"}'
Assert-Check ($video.Title -ceq 'A' -and $video.Channel -ceq 'Chan nel' -and (ConvertFrom-TvVideoAnswer 'x').Channel -ceq '') 'the channel name is read and cleaned; junk gives none'
Assert-Check ((New-TvThumbRequest $ids[0]).Url -ceq ('https://i.ytimg.com/vi/' + $ids[0] + '/mqdefault.jpg') -and -not (New-TvThumbRequest $ids[0]).Token) 'a thumbnail is asked of the public thumbnail host by video id only'
$long = Limit-TvText ([string]::new([char]0x00E9, 400)) 512
Assert-Check ([Text.Encoding]::UTF8.GetByteCount($long) -le 512 -and $long.Length -eq 256) 'long text is cut at a character boundary'

# ------------------------------------------------------------------ player merge and up next
$player = New-TvPlayer
Merge-TvEvent $player (New-Event 'loungeStatus' @{ devices = '[{"type":"REMOTE_CONTROL","name":"x"}]' }) 1000
Assert-Check ($player.Screen -eq $false) 'a session listing no screen says so'
Merge-TvEvent $player (New-Event 'loungeStatus' @{ devices = '[{"type":"LOUNGE_SCREEN","name":"x"}]' }) 1000
Assert-Check ($player.Screen -eq $true) 'a listed screen is seen'
Assert-Check ((Get-TvUpNext $player).Status -ceq 'none') 'nothing loaded: up next is none'

$mix25 = [string[]]$ids[0..24]
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[0]; listId = 'RDmix0001'; state = '3'; duration = '0'; currentTime = '0'; mdxExpandedReceiverVideoIdList = ($mix25 -join ',') }) 2000
$up = Get-TvUpNext $player
Assert-Check ($up.Status -ceq 'known' -and $up.Kind -ceq 'list' -and $up.Total -eq 24 -and $up.Ids.Count -eq 20 -and $up.Ids[0] -ceq $ids[1]) 'a Mix gives up next from its id list, 20 rows at most'
Assert-Check ((Get-TvPlayName $player.State) -ceq 'loading') 'state 3 is loading'
$player.Changed = $false
$mix100 = [string[]]@($ids[0]) + [string[]]$ids[30..128]
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[0]; listId = 'RDmix0001'; mdxExpandedReceiverVideoIdList = ($mix100 -join ',') }) 3000
$up = Get-TvUpNext $player
Assert-Check ($player.Changed -and $up.Total -eq 99 -and $up.Ids[0] -ceq $ids[30]) 'a settling Mix: the latest list wins, and its next entry moves'
Merge-TvEvent $player (New-Event 'onStateChange' @{ state = '1'; currentTime = '10'; duration = '200.5' }) 10000
Assert-Check ($player.VideoId -ceq $ids[0] -and (Get-TvPlayName $player.State) -ceq 'playing' -and $player.DurationMs -eq 200500) 'onStateChange (no video id) applies to the current video'
Assert-Check ((Get-TvPositionMs $player 15000) -eq 15000) 'position advances between events while playing'
Assert-Check ((Get-TvPositionMs $player 999999) -eq 200500) 'position never passes the duration'
Merge-TvEvent $player (New-Event 'onStateChange' @{ state = '2'; currentTime = '20' }) 20000
Assert-Check ((Get-TvPositionMs $player 90000) -eq 20000) 'position holds while paused'
Merge-TvEvent $player (New-Event 'onStateChange' @{ state = '0'; duration = '0' }) 21000
Assert-Check ((Get-TvPlayName 0) -ceq 'ended' -and (Get-TvPlayName 0) -cne 'buffering' -and $player.DurationMs -eq 200500) 'state 0 is the end of a video (not buffering); a 0 duration keeps the known one'
Assert-Check ((Get-TvPlayName -1) -ceq 'idle' -and (Get-TvPlayName 1081) -ceq 'ad' -and (Get-TvPlayName 42) -ceq 'unknown' -and (Get-TvPlayName $null) -ceq 'unknown') 'other state numbers'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ listId = 'RDmix0001' }) 22000
Assert-Check ($player.VideoId -ceq $ids[0] -and $player.Ids.Count -eq 100) 'a nowPlaying with only a list id keeps the video and the list'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[30]; state = '1'; mdxExpandedReceiverVideoIdList = ($ids[30]) }) 23000
$up = Get-TvUpNext $player
Assert-Check ($up.Status -ceq 'unknown' -and $up.Ids.Count -eq 0) 'a list of only the current video is not known yet, never an empty queue'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[30]; mdxExpandedReceiverVideoIdList = ($ids[30] + ',bad id!,' + $ids[31]) }) 23500
Assert-Check ($player.Ids.Count -eq 1) 'a list with an invalid id is dropped; the last good one is kept'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[50]; mdxExpandedReceiverVideoIdList = (($ids[1..5]) -join ',') }) 24000
Assert-Check ((Get-TvUpNext $player).Status -ceq 'unknown') 'a list without the current video is not known'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = $ids[5]; listId = 'PLlist0001' }) 25000
$up = Get-TvUpNext $player
Assert-Check ($up.Status -ceq 'end' -and $up.Total -eq 0 -and $up.Kind -ceq 'list') 'the last listed video: nothing listed after it'
Assert-Check ($player.DurationMs -eq 0 -and $player.PositionMs -eq 0) 'a new video starts with no duration or position'
Merge-TvEvent $player (New-Event 'playlistModified' @{ videoIds = (($ids[5..8]) -join ',') }) 25500
Assert-Check ((Get-TvUpNext $player).Total -eq 3) 'playlistModified with ids updates the list'
Merge-TvEvent $player (New-Event 'autoplayUpNext' @{ videoId = $ids[9] }) 25600
Assert-Check ($player.Autoplay -ceq $ids[9] -and (Get-TvUpNext $player).Ids[0] -ceq $ids[6]) 'autoplayUpNext is kept but does not replace the list'
Merge-TvEvent $player (New-Event 'someFutureEvent' @{ videoId = $ids[99] }) 26000
Assert-Check ($player.VideoId -ceq $ids[5]) 'unknown events change nothing'
Merge-TvEvent $player (New-Event 'nowPlaying' @{ videoId = 'x'; state = 'one'; currentTime = '-5'; listId = 'bad list!' }) 27000
Assert-Check ($player.VideoId -ceq $ids[5] -and $player.ListId -ceq '' -and $player.State -eq 1) 'malformed values are ignored (an invalid list id clears the list kind)'
Merge-TvEvent $player (New-Event 'nowPlaying' @{}) 28000
Assert-Check ((Get-TvUpNext $player).Status -ceq 'none' -and $player.Ids.Count -eq 0) 'an empty nowPlaying: nothing loaded'
Merge-TvEvent $player (New-Event 'loungeScreenDisconnected') 29000
Assert-Check ($player.Gone -and $player.Screen -eq $false) 'a screen disconnect is noticed'

# ------------------------------------------------------------------ store
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-TvCore-test-' + [Guid]::NewGuid().ToString('N'))
try {
    $root = Initialize-TvPrivateDirectory $runRoot
    Assert-Check (Test-TvFolderPrivate $root) 'the data folder is private to this user'
    $acl = [IO.Directory]::GetAccessControl($root)
    Assert-Check ($acl.AreAccessRulesProtected -and @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])).Count -eq 1) 'one rule, no inherited access'
    Assert-Throws { Initialize-TvPrivateDirectory ([Environment]::GetFolderPath('LocalApplicationData')) } 'a profile root is refused as the data folder'
    Assert-Throws { Initialize-TvPrivateDirectory 'C:\Somewhere\Skins\Parallax\x' } 'a skin folder is refused'
    Assert-Throws { Initialize-TvPrivateDirectory 'relative\path' } 'a relative path is refused'
    Assert-Check ((Get-TvDataRoot) -like '*\Parallax\Media\YouTube') 'the standard folder is Parallax\Media\YouTube'

    Assert-Check ($null -eq (Read-TvPairing $root) -and -not (Test-TvPaired $root)) 'no pairing yet'
    $paired = New-TvPairing -ScreenId 'SCREEN-SECRET-0001' -LoungeToken 'TOKEN-SECRET-A' -Name 'Stand-in TV'
    Save-TvPairing $root $paired
    $back = Read-TvPairing $root
    Assert-Check ($back.ScreenId -ceq 'SCREEN-SECRET-0001' -and $back.LoungeToken -ceq 'TOKEN-SECRET-A' -and $back.Name -ceq 'Stand-in TV' -and $back.DeviceId -ceq $paired.DeviceId) 'pairing round-trips through DPAPI'
    $sealed = [IO.File]::ReadAllBytes((Join-Path $root 'pairing.dpapi'))
    foreach ($secret in @('SCREEN-SECRET', 'TOKEN-SECRET', 'Stand-in')) {
        $a = [Text.Encoding]::ASCII.GetString($sealed); $w = [Text.Encoding]::Unicode.GetString($sealed)
        Assert-Check (-not $a.Contains($secret) -and -not $w.Contains($secret)) "the stored pairing does not hold '$secret' in plain text"
    }
    $plainOther = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes('{"v":1}'), $null, 'CurrentUser')
    [IO.File]::WriteAllBytes((Join-Path $root 'pairing.dpapi'), $plainOther)
    Assert-Check ($null -eq (Read-TvPairing $root)) 'a blob sealed without the pairing entropy is not accepted'
    [IO.File]::WriteAllBytes((Join-Path $root 'pairing.dpapi'), [byte[]](1..40))
    Assert-Check ($null -eq (Read-TvPairing $root) -and (Test-TvPaired $root)) 'a damaged pairing reads as none, without throwing'
    Save-TvPairing $root $paired
    Assert-Check ((Remove-TvFile $root 'pairing.dpapi') -and -not (Test-TvPaired $root)) 'Forget removes the pairing'
    Assert-Throws { Get-TvRuntimePath $root '..\outside.txt' } 'only known runtime files are touched'

    $titles = [string[]]@('First song', '', ("Th" + [char]0x00EF + "rd"))
    $snap = New-TvSnapshot -State ready -Observed 1000 -ValidUntil 1150 -Play playing -PositionMs 12000 -PositionAtMs 1000000 -DurationMs 200000 -UpNext known -List list -Total 99 -CurrentTitle 'Now song' -Titles $titles
    $text = ConvertTo-TvSnapshotText $snap
    Assert-Check ($text.StartsWith("PARALLAX_TV_V1`nstate=ready`nobserved=1000`n") -and $text.Contains("`ncount=3`n") -and $text.Contains("`ntotal=99`n") -and $text.Contains("`nlist=list`n")) 'ready snapshot header'
    Assert-Check ($text.Contains("`ntitle1=" + ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes('First song')).Replace('-', '')) + "`n") -and $text.Contains("`ntitle2=`n") -and $text.Contains("`ntitle3=5468C3AF7264`n")) 'titles are UTF-8 hex; an unknown title is empty'
    Assert-Check (@([Text.Encoding]::ASCII.GetBytes($text) | Where-Object { $_ -gt 127 }).Count -eq 0) 'the snapshot is ASCII'
    Publish-TvSnapshot $root $snap
    $read = Read-TvSnapshotFields $root
    Assert-Check ($read['state'] -ceq 'ready' -and $read['upnext'] -ceq 'known' -and $read['count'] -ceq '3') 'snapshot published and read back'
    $short = ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 5 -ValidUntil 50 -Play playing -UpNext unknown -List none)
    Assert-Check ($short.Contains("`nupnext=unknown`n") -and $short.Contains("`ncount=0`n")) 'a not-known-yet queue is written as unknown, not as empty'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 5 -ValidUntil 50 -Play playing -UpNext unknown -List none -Total 3 -Titles @('x')) } 'rows only with a known up next'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State offline -Titles @('x')) } 'a nonready snapshot cannot hold rows'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State offline -CurrentTitle 'x') } 'a nonready snapshot cannot hold a title'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State 'buffering') } 'unknown states are refused'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 5 -ValidUntil 50 -Play playing -UpNext known -List list -Total 30 -Titles ([string[]](1..21 | ForEach-Object { 't' }))) } 'at most 20 rows'
    Assert-Check ((ConvertTo-TvSnapshotText (New-TvSnapshot -State stopped)).Contains("`nstate=stopped`n")) 'a stopped snapshot'
    $card = ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 5 -ValidUntil 50 -Play paused -UpNext none -List none -CurrentTitle 'T' -CurrentChannel 'Chan' -Cover 2)
    Assert-Check ($card.Contains("`ncurrent_title=54`ncurrent_channel=4368616E`ncover=2`n")) 'the channel (hex) and thumbnail slot follow the current title'
    Assert-Check ($text.Contains("`ncurrent_channel=`ncover=`n")) 'an unknown channel and no thumbnail are empty'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State offline -CurrentChannel 'x') } 'a nonready snapshot cannot hold a channel'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State offline -Cover 1) } 'a nonready snapshot names no thumbnail'
    Assert-Throws { ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 5 -ValidUntil 50 -Play paused -UpNext none -List none -Cover 3) } 'only two thumbnail slots'
    $jpeg = [byte[]](@(0xFF, 0xD8, 0xFF, 0xE0) + @(1) * 200 + @(0xFF, 0xD9))
    Assert-Check ((Test-TvJpeg $jpeg) -and -not (Test-TvJpeg ([byte[]](@(0x89, 0x50) + @(1) * 200))) -and -not (Test-TvJpeg ([byte[]](@(0xFF, 0xD8, 0xFF) + @(1) * 300000 + @(0xFF, 0xD9))))) 'a thumbnail must be a JPEG under 256 KB'
    Assert-Throws { Save-TvCover $root 1 ([byte[]](1..200)) } 'anything else is not saved'
    Save-TvCover $root 2 $jpeg
    Assert-Check ([IO.File]::Exists((Join-Path $root 'tv.cover2.jpg'))) 'a thumbnail is saved in its slot'
    Remove-TvCovers $root
    Assert-Check (-not [IO.File]::Exists((Join-Path $root 'tv.cover2.jpg'))) 'and removed'

    $now = Get-TvUnixTime
    Write-TvRequest $root next -Now $now
    $request = Read-TvRequest $root -Now $now
    Assert-Check ($request.Kind -ceq 'next' -and $request.Row -eq 0) 'a request is read'
    Assert-Check ($null -eq (Read-TvRequest $root -Now $now)) 'a request is consumed once'
    Write-TvRequest $root jump -Row 4 -Observed 1000 -Now $now
    $request = Read-TvRequest $root -Now $now
    Assert-Check ($request.Kind -ceq 'jump' -and $request.Row -eq 4 -and $request.Observed -eq 1000) 'a jump names a row and the snapshot'
    Write-TvRequest $root pause -Now ($now - 60)
    Assert-Check ($null -eq (Read-TvRequest $root -Now $now)) 'a stale request is dropped'
    Assert-Throws { Write-TvRequest $root jump -Row 0 -Observed 5 } 'a jump without a row is refused'
    Assert-Throws { Write-TvRequest $root seek } 'unknown request words are refused'
    [IO.File]::WriteAllText((Join-Path $root 'tv.request'), "PARALLAX_TV_REQUEST_V1|jump|0|5|$now`n")
    Assert-Check ($null -eq (Read-TvRequest $root -Now $now)) 'a malformed request is dropped'
    [IO.File]::WriteAllText((Join-Path $root 'tv.request'), "PARALLAX_TV_REQUEST_V1|pause|0|0|$now`nextra")
    Assert-Check ($null -eq (Read-TvRequest $root -Now $now)) 'trailing text makes a request malformed'

    Assert-Check (-not (Test-TvIntent $root)) 'no intent at first'
    Set-TvIntent $root $true; Assert-Check (Test-TvIntent $root) 'intent set'
    Set-TvIntent $root $false; Assert-Check (-not (Test-TvIntent $root)) 'intent cleared'
    Request-TvStop $root; Assert-Check (Test-TvStop $root) 'stop requested'
    Clear-TvStop $root; Assert-Check (-not (Test-TvStop $root)) 'stop cleared'
    $launch = New-TvLaunchId $root
    Assert-Check ((Test-TvLaunchId $root $launch) -and -not (Test-TvLaunchId $root ('0' * 32))) 'launch permit'

    Write-TvDiagnostic $root ('event nowPlaying fields=videoId,state ' + [char]0x00E9 + ' <script>')
    $log = [IO.File]::ReadAllText((Join-Path $root 'events.log'))
    Assert-Check ($log -match 'event nowPlaying fields=videoId,state \? \?script\?') 'diagnostic lines are reduced to a small character set'
    Assert-Check ((Get-TvSafeName 'nowPlaying') -ceq 'nowPlaying' -and (Get-TvSafeName 'x y') -ceq '(other)' -and (Get-TvSafeName $ids[0]) -ceq $ids[0].Substring(0) ) 'plain names pass'
} finally {
    if ([IO.Directory]::Exists($runRoot)) { [IO.Directory]::Delete($runRoot, $true) }
}

# ------------------------------------------------------------------ HTTP against the stand-in
Assert-Throws { Set-TvEndpointForTest -LoungeBase 'https://example.com/api' -TitleBase 'http://127.0.0.1:1/oembed' } 'test endpoints must be on 127.0.0.1'
$standIn = Start-TvStandIn
try {
    Set-TvEndpointForTest -LoungeBase $standIn.LoungeBase -TitleBase $standIn.TitleBase
    Assert-Check ((New-TvThumbRequest $ids[0]).Url -like 'http://127.0.0.1:*/vi/*') 'test endpoints also move thumbnails to the stand-in'
    $state = $standIn.State
    $state.Titles[$ids[1]] = 'Stand-in title'
    $result = Invoke-TvHttp (New-TvPairRequest '123456789012')
    $screen = ConvertFrom-TvPairAnswer $result.Text
    Assert-Check ($result.Status -eq 200 -and $screen.ScreenId -ceq 'SCREEN-SECRET-0001' -and $screen.Name -ceq 'Stand-in TV') 'pairing by code against the stand-in'
    Assert-Check ((Invoke-TvHttp (New-TvPairRequest '000000000000')).Status -eq 404) 'a wrong code fails with its HTTP status'
    $live = [pscustomobject]@{ Name = 'Stand-in TV'; PairedAt = 1; DeviceId = [Guid]::NewGuid().ToString(); ScreenId = $screen.ScreenId; LoungeToken = $screen.LoungeToken }
    $session = New-TvSession $live
    $state.BindEvents.Add(@('loungeStatus', @{ devices = '[{"type":"LOUNGE_SCREEN","name":"T"}]' })) | Out-Null
    $answer = Invoke-TvHttp (New-TvBindRequest $session)
    $bound = @(Read-TvFrames (New-TvFrameReader) $answer.Text)
    foreach ($e in $bound) { Update-TvSession $session $e }
    Assert-Check ($answer.Status -eq 200 -and $session.Sid -ceq 'SID-1' -and $session.GSession -ceq 'GS-1' -and $session.Aid -eq 3) 'bind gives session ids'
    $player = New-TvPlayer
    foreach ($e in $bound) { Merge-TvEvent $player $e }
    Assert-Check ($player.Screen -eq $true) 'the screen is in the session'

    $poll = Open-TvPoll $session
    $state.Reactions['pause'] = @(, @('onStateChange', @{ state = '2'; currentTime = '42' }))
    Push-TvStandIn $standIn @(, @('nowPlaying', @{ videoId = $ids[0]; state = '1'; listId = 'RDmix0001'; mdxExpandedReceiverVideoIdList = (($ids[0..9]) -join ',') }))
    $got = [Collections.Generic.List[object]]::new()
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ($got.Count -lt 1 -and [DateTime]::UtcNow -lt $deadline) { $step = Step-TvPoll $poll 100; foreach ($e in $step.Events) { $got.Add($e) }; if ($step.Ended) { break } }
    Assert-Check ($got.Count -eq 1 -and $got[0].Name -ceq 'nowPlaying') 'an event pushed on the open stream arrives'
    foreach ($e in $got) { Update-TvSession $session $e; Merge-TvEvent $player $e }
    $sent = Invoke-TvHttp (New-TvCommandRequest $session 'pause')
    Assert-Check ($sent.Status -eq 200) 'a command on the listening session is accepted'
    $got.Clear()
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ($got.Count -lt 1 -and [DateTime]::UtcNow -lt $deadline) { $step = Step-TvPoll $poll 100; foreach ($e in $step.Events) { $got.Add($e) }; if ($step.Ended) { break } }
    Assert-Check ($got.Count -eq 1 -and $got[0].Name -ceq 'onStateChange' -and -not $step.Ended) 'events keep arriving on the same stream after a command'
    $command = $state.Commands[0]
    Assert-Check ($command.Sid -ceq 'SID-1' -and $command.Ofs -ceq '1' -and $command.Aid -ceq '4' -and $state.Binds -eq 1) 'the command used the bound session and sent one bind only'
    $state.ClosePolls = $true
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do { $step = Step-TvPoll $poll 100 } while (-not $step.Ended -and [DateTime]::UtcNow -lt $deadline)
    Assert-Check ($step.Ended -and $step.Kind -ceq 'ended') 'a stream the server closes ends normally'
    Close-TvPoll $poll
    $state.PollStatus = 400
    $poll = Open-TvPoll $session
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do { $step = Step-TvPoll $poll 100 } while (-not $step.Ended -and [DateTime]::UtcNow -lt $deadline)
    Assert-Check ($step.Ended -and $step.Status -eq 400 -and $step.Kind -ceq 'http') 'a refused poll reports its status'
    Close-TvPoll $poll
    $state.PollStatus = 200
    $poll = Open-TvPoll $session -QuietSeconds 1
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do { $step = Step-TvPoll $poll 100 } while (-not $step.Ended -and [DateTime]::UtcNow -lt $deadline)
    Assert-Check ($step.Ended -and $step.Kind -ceq 'quiet') 'a stream silent for too long is ended for renewal'
    Close-TvPoll $poll
    $title = Invoke-TvHttp (New-TvTitleRequest $ids[1]) -TimeoutSeconds 5
    Assert-Check ($title.Status -eq 200 -and (ConvertFrom-TvTitleAnswer $title.Text) -ceq 'Stand-in title') 'a title lookup against the stand-in'
    Assert-Check ((Invoke-TvHttp (New-TvTitleRequest $ids[2]) -TimeoutSeconds 5).Status -eq 404) 'a missing title reports 404'
    $token = Invoke-TvHttp (New-TvTokenRequest 'SCREEN-SECRET-0001')
    Assert-Check ((ConvertFrom-TvTokenAnswer $token.Text) -ceq 'TOKEN-SECRET-B') 'a token renewal against the stand-in'
    $left = Invoke-TvHttp (New-TvLeaveRequest $session)
    Assert-Check ($left.Status -eq 200 -and $state.Leaves -eq 1) 'leaving the session'
    $agents = @($state.Log | ForEach-Object { $_.Agent } | Select-Object -Unique)
    Assert-Check ($agents.Count -eq 1 -and $agents[0] -ceq 'Parallax-Media/1') 'requests carry a plain client name, nothing personal'
    $port = $state.Port
    $state.Quit = $true
    Start-Sleep -Milliseconds 300
    $offline = Invoke-TvHttp ([pscustomobject]@{ Method = 'GET'; Url = "http://127.0.0.1:$port/api/lounge/x"; Body = ''; Token = '' }) -TimeoutSeconds 3
    Assert-Check ($offline.Status -eq 0 -and $offline.Kind -ceq 'offline') 'no answer at all reads as offline'
    Assert-Check ($state.Errors.Count -eq 0) ('the stand-in saw no errors: ' + (@($state.Errors) -join '; '))
} finally {
    Stop-TvStandIn $standIn
}
Write-Output "TV core: $script:checks checks passed."
