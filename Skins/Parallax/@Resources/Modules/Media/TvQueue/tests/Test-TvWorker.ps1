# Developer-only offline tests for the TV queue worker (M2): lifecycle, one
# session for events and commands, requests, rejoin, token renewal, titles and
# honest states, against a stand-in on 127.0.0.1. Nothing reaches a TV or
# YouTube, and no process is launched (background starts are recorded instead).
# Host: Windows PowerShell 5.1 (powershell.exe), a normal user (DPAPI).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvWorker.ps1
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\TvProvider.ps1'))
. $provider -Command Help
. (Join-Path $PSScriptRoot 'TvStandIn.ps1')
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
$script:launches = [Collections.Generic.List[object]]::new()
# Recorded instead of starting a process.
function Start-TvBackground { param([string]$Root, [bool]$WithDiagnostics); $script:launches.Add([pscustomobject]@{ Root = $Root; Diagnostics = $WithDiagnostics }) }
function Get-FakeId([int]$Number) { return ('vid' + $Number.ToString('00000000')) }
$ids = 1..60 | ForEach-Object { Get-FakeId $_ }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-TvWorker-test-' + [Guid]::NewGuid().ToString('N'))
function Fresh-Root { return (Join-Path $runRoot ([Guid]::NewGuid().ToString('N'))) }
function Invoke-As { param([string]$Name, [string]$Root, [hashtable]$With = @{})
    $script:Command = $Name; $script:DataRoot = $Root; $script:Quiet = $true; $script:Code = ''; $script:NoStart = $false; $script:Diagnostics = $false; $script:Action = 'refresh'; $script:Row = 0; $script:Observed = 0
    foreach ($key in $With.Keys) { Set-Variable -Scope Script -Name $key -Value $With[$key] }
    Invoke-TvCommand
}
function Step-Until { param([object]$Worker, [scriptblock]$Condition, [int]$Seconds = 8, [string]$What = 'condition')
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while (-not (& $Condition)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "FAILED: timed out waiting for $What" }
        Step-TvWorker $Worker 50
    }
}
function Snap { param([string]$Root); return (Read-TvSnapshotFields $Root) }
function Hex([string]$Text) { return [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text)).Replace('-', '') }

$standIn = Start-TvStandIn
try {
    Set-TvEndpointForTest -LoungeBase $standIn.LoungeBase -TitleBase $standIn.TitleBase
    $state = $standIn.State
    $null = New-Item -ItemType Directory -Path $runRoot

    # ---------------------------------------------------------- nothing before Pair or Start
    $root = Fresh-Root
    foreach ($name in @('Resume', 'Send', 'Status')) { Invoke-As $name $root }
    Assert-Check (-not [IO.Directory]::Exists($root)) 'Resume, Send and Status create nothing without a pairing'
    Assert-Check ($state.Log.Count -eq 0 -and $script:launches.Count -eq 0) 'nothing touched the network or started a worker'
    Invoke-As 'Start' $root
    Assert-Check ((Snap $root)['state'] -ceq 'not_paired' -and $script:launches.Count -eq 0 -and $state.Log.Count -eq 0) 'Start without a pairing says not paired and starts nothing'
    Assert-Check (Test-TvFolderPrivate $root) 'the data folder Start created is private'

    # ---------------------------------------------------------- Pair
    $threw = $false
    try { Invoke-As 'Pair' $root @{ Code = '000 000 000 000' } } catch { $threw = $_.Exception.Message -like '*HTTP 404*' }
    Assert-Check ($threw -and -not (Test-TvPaired $root)) 'a wrong code fails with its HTTP status and saves nothing'
    $threw = $false
    try { Invoke-As 'Pair' $root @{ Code = 'abc' } } catch { $threw = $true }
    Assert-Check $threw 'a code that is not digits is refused before anything is sent'
    Invoke-As 'Pair' $root @{ Code = '1234 5678 9012' }
    $pairing = Read-TvPairing $root
    Assert-Check ($pairing.ScreenId -ceq 'SCREEN-SECRET-0001' -and $pairing.LoungeToken -ceq 'TOKEN-SECRET-A') 'Pair saves the sealed pairing'
    Assert-Check ((Test-TvIntent $root) -and -not (Test-TvStop $root) -and $script:launches.Count -eq 1 -and (Snap $root)['state'] -ceq 'connecting') 'Pair enables and starts the worker'
    Invoke-As 'Resume' $root
    Assert-Check ($script:launches.Count -eq 2) 'Resume continues a worker the user started'
    Invoke-As 'Start' $root @{ Diagnostics = $true }
    Assert-Check ($script:launches.Count -eq 3 -and $script:launches[2].Diagnostics) 'Start can turn diagnostics on'

    # ---------------------------------------------------------- one session: events and commands
    $mixIds = [string[]]$ids[0..29]
    $state.BindEvents.Add(@('loungeStatus', @{ devices = '[{"type":"LOUNGE_SCREEN","name":"T"},{"type":"REMOTE_CONTROL","name":"Parallax"}]'; queueId = 'Q' })) | Out-Null
    $state.Reactions['getNowPlaying'] = @(, @('nowPlaying', @{ videoId = $ids[0]; listId = 'RDmix0001'; state = '1'; currentTime = '5'; duration = '180'; mdxExpandedReceiverVideoIdList = ($mixIds -join ','); ctt = 'SECRET-CTT' }))
    $state.Reactions['pause'] = @(, @('onStateChange', @{ state = '2'; currentTime = '7.5'; duration = '180' }))
    $state.Reactions['play'] = @(, @('onStateChange', @{ state = '1'; currentTime = '7.5'; duration = '180' }))
    $state.Reactions['next'] = @(@('nowPlaying', @{ videoId = $ids[1]; listId = 'RDmix0001'; state = '3'; currentTime = '0'; duration = '0'; mdxExpandedReceiverVideoIdList = ($mixIds -join ',') }), @('onStateChange', @{ state = '1'; currentTime = '0.2'; duration = '200' }))
    $state.Titles[$ids[0]] = 'Song zero'
    $state.Titles[$ids[1]] = 'Song one'
    $state.Titles[$ids[2]] = 'Song two'
    $state.Titles[$ids[3]] = 'Song three'
    # Made-up channel names and thumbnails (JPEG-shaped bytes, nothing real).
    $state.Channels[$ids[0]] = 'Channel zero'
    $state.Channels[$ids[1]] = 'Channel one'
    function New-FakeJpeg([byte]$Fill) { $b = [byte[]](@(0xFF, 0xD8, 0xFF, 0xE0) + @($Fill) * 300 + @(0xFF, 0xD9)); return ,$b }
    $thumb0 = New-FakeJpeg 7; $thumb1 = New-FakeJpeg 9
    $state.Thumbs[$ids[0]] = $thumb0
    $state.Thumbs[$ids[1]] = $thumb1
    $worker = New-TvWorker $root $pairing $true
    Step-TvWorker $worker 50
    Assert-Check ($state.Binds -eq 1 -and $null -ne $worker.Session -and $null -ne $worker.Poll) 'the worker binds one session and opens its event stream'
    Assert-Check ($state.Commands.Count -eq 1 -and $state.Commands[0].Name -ceq 'getNowPlaying' -and $state.Commands[0].Sid -ceq 'SID-1') 'it asks what is playing on that session'
    Step-Until $worker { (Snap $root)['upnext'] -ceq 'known' } -What 'up next'
    $snap = Snap $root
    Assert-Check ($snap['state'] -ceq 'ready' -and $snap['play'] -ceq 'playing' -and $snap['list'] -ceq 'list' -and $snap['total'] -ceq '29' -and $snap['count'] -ceq '20') 'the TV app''s Mix shows as up next: 20 rows of 29'
    Step-Until $worker { $s = Snap $root; $s['title1'] -and $s['title2'] -and $s['title3'] -and $s['current_title'] } -What 'titles'
    $snap = Snap $root
    Assert-Check ($snap['current_title'] -ceq (Hex 'Song zero') -and $snap['title1'] -ceq (Hex 'Song one') -and $snap['title3'] -ceq (Hex 'Song three')) 'titles come from oEmbed for the current video and the rows'
    Assert-Check ($snap['current_channel'] -ceq (Hex 'Channel zero')) 'the channel name comes from the same oEmbed answer'
    Step-Until $worker { (Snap $root)['cover'] -ceq '1' } -Seconds 15 -What 'the thumbnail'
    $cover1 = Join-Path $root 'tv.cover1.jpg'
    Assert-Check ([IO.File]::Exists($cover1) -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($cover1)) -ceq [Convert]::ToBase64String($thumb0)) 'the current video''s thumbnail is kept in the private folder, slot 1'
    $thumbLog = @($state.Log | Where-Object { $_.Path -like '/vi/*' })
    Assert-Check ($thumbLog.Count -eq 1 -and $thumbLog[0].Path -ceq ('/vi/' + $ids[0] + '/mqdefault.jpg') -and -not $thumbLog[0].Token) 'one thumbnail request: the video id only, no token'
    Step-Until $worker { $worker.Titles.ContainsKey($ids[4]) } -What 'a missing title'
    Assert-Check (-not (Snap $root)['title4']) 'a video oEmbed does not know keeps an empty title'
    $lookups = @($state.Log | Where-Object { $_.Path -ceq '/oembed' }).Count
    Step-Until $worker { $worker.Titles.Count -ge 21 } -Seconds 15 -What 'all shown titles'
    $before = @($state.Log | Where-Object { $_.Path -ceq '/oembed' }).Count
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check (@($state.Log | Where-Object { $_.Path -ceq '/oembed' }).Count -eq $before -and $before -le 21) 'each shown video is looked up once, only for shown rows'
    $text = [IO.File]::ReadAllText((Join-Path $root 'tv.snapshot'))
    Assert-Check (-not $text.Contains('vid0') -and -not $text.Contains('RDmix') -and -not $text.Contains('SECRET') -and -not $text.Contains('SID-')) 'the snapshot holds no ids, tokens or session ids'

    $observedBefore = [long](Snap $root)['observed']
    Write-TvRequest $root pause
    Step-Until $worker { (Snap $root)['play'] -ceq 'paused' } -What 'paused'
    $pause = @($state.Commands | Where-Object { $_.Name -ceq 'pause' })
    Assert-Check ($pause.Count -eq 1 -and $pause[0].Sid -ceq 'SID-1' -and $pause[0].Ofs -ceq '2' -and $state.Binds -eq 1) 'pause goes once on the listening session (no second session)'
    Assert-Check ($null -eq (Read-TvRequest $root) -and $state.Polls -ge 1) 'the request was consumed'
    Write-TvRequest $root next
    Step-Until $worker { (Snap $root)['title1'] -ceq (Hex 'Song two') -and (Snap $root)['play'] -ceq 'playing' } -What 'next video'
    $snap = Snap $root
    Assert-Check ($snap['current_title'] -ceq (Hex 'Song one') -and $snap['total'] -ceq '28' -and [long]$snap['observed'] -gt $observedBefore) 'next: events still arrive; rows move on under a newer observed time'
    Step-Until $worker { (Snap $root)['cover'] -ceq '2' } -Seconds 15 -What 'the next thumbnail'
    Assert-Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root 'tv.cover2.jpg'))) -ceq [Convert]::ToBase64String($thumb1) -and (Snap $root)['current_channel'] -ceq (Hex 'Channel one')) 'a new video: its thumbnail goes in the other slot, with its channel'
    Assert-Check (@($state.Log | Where-Object { $_.Path -like '/vi/*' }).Count -eq 2) 'each video''s thumbnail is fetched once'
    Write-TvRequest $root play
    for ($i = 0; $i -lt 20; $i++) { Step-TvWorker $worker 20 }
    Assert-Check (@($state.Commands | Where-Object { $_.Name -ceq 'play' }).Count -eq 1) 'play is sent once'

    # A jump to a listed song: row 3 of what was shown is ids[4] at index 4.
    $observed = [long](Snap $root)['observed']
    $state.Reactions['setPlaylist'] = @(, @('nowPlaying', @{ videoId = $ids[4]; listId = 'RDmix0001'; state = '1'; currentTime = '0'; duration = '150'; mdxExpandedReceiverVideoIdList = ($mixIds -join ',') }))
    Write-TvRequest $root jump -Row 3 -Observed $observed
    Step-Until $worker { (Snap $root)['total'] -ceq '25' } -What 'the jump'
    $jump = @($state.Commands | Where-Object { $_.Name -ceq 'setPlaylist' })
    Assert-Check ($jump.Count -eq 1 -and $jump[0].Fields['videoId'] -ceq $ids[4] -and $jump[0].Fields['currentIndex'] -ceq '4' -and $jump[0].Fields['listId'] -ceq 'RDmix0001' -and $jump[0].Sid -ceq 'SID-1') 'a row click jumps by video, index and list on the same session'
    Step-Until $worker { @($state.Log | Where-Object { $_.Path -like '/vi/*' }).Count -ge 3 } -What 'a missing thumbnail'
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ((Snap $root)['cover'] -ceq '' -and @($state.Log | Where-Object { $_.Path -like '/vi/*' }).Count -eq 3) 'no thumbnail: the snapshot names none (never the last video''s), and it is not asked again at once'
    Write-TvRequest $root jump -Row 1 -Observed 12345
    Step-Until $worker { (Snap $root)['notice'] -ceq 'queue_changed' } -What 'queue_changed'
    Assert-Check (@($state.Commands | Where-Object { $_.Name -ceq 'setPlaylist' }).Count -eq 1) 'a click on rows this worker never showed sends nothing and says the queue changed'
    $log = [IO.File]::ReadAllText((Join-Path $root 'events.log'))
    Assert-Check ($log -match 'request jump: not a shown queue' -or $log -match 'no longer listed') 'and says why in diagnostics'
    $commandsSoFar = $state.Commands.Count
    $ofs = @($state.Commands | ForEach-Object { [int]$_.Ofs })
    Assert-Check ((($ofs | ForEach-Object { $_ }) -join ',') -ceq (((1..$ofs.Count) | ForEach-Object { $_ }) -join ',')) 'commands on one session count ofs 1, 2, 3 ...'
    Assert-Check ($log -match 'command pause http=200' -and $log -match 'command setPlaylist row=3 index=4 by=list http=200' -and $log -match 'event onStateChange fields=\S+ state=paused') 'diagnostics show commands and the events that followed'
    foreach ($secret in @('vid0', 'RDmix', 'SECRET', 'SID-', 'GS-', 'Song ', 'Stand-in')) { Assert-Check (-not $log.Contains($secret)) "diagnostics never hold '$secret'" }

    # ---------------------------------------------------------- the screen leaves, and comes back
    $state.Reactions['getNowPlaying'] = @(, @('nowPlaying', @{ videoId = $ids[4]; listId = 'RDmix0001'; state = '1'; currentTime = '9'; mdxExpandedReceiverVideoIdList = ($ids[4]) }))
    Push-TvStandIn $standIn @(, @('loungeScreenDisconnected', @{ reason = 'x' }))
    Step-Until $worker { (Snap $root)['state'] -ceq 'no_screen' } -What 'no screen'
    $snap = Snap $root
    Assert-Check ($null -eq $worker.Session -and [long]$snap['retry_at'] -ge (Get-TvUnixTime) + 9 -and $snap['count'] -ceq '0') 'a screen that leaves: honest no_screen, rejoin after at least 10 s'
    Write-TvRequest $root pause
    Step-TvWorker $worker 20
    Assert-Check ((Snap $root)['notice'] -ceq 'not_connected' -and $state.Commands.Count -eq $commandsSoFar) 'a request while disconnected is not sent, and says so'
    $worker.NextAttemptMs = 0
    Step-Until $worker { (Snap $root)['state'] -ceq 'ready' -and (Snap $root)['upnext'] -ceq 'unknown' } -What 'rejoin'
    Assert-Check ($state.Binds -eq 2 -and $worker.Session.Sid -ceq 'SID-2' -and (Snap $root)['count'] -ceq '0') 'rejoined; a list of only the current video is not known yet, not empty'

    # ---------------------------------------------------------- the session expires
    $state.PollStatus = 400
    $state.ClosePolls = $true
    Step-Until $worker { $null -eq $worker.Session } -What 'session drop'
    Assert-Check ($worker.NextAttemptMs -eq 0) 'an expired session is rebound at once the first time'
    $state.PollStatus = 200
    Step-Until $worker { $state.Binds -eq 3 -and (Snap $root)['state'] -ceq 'ready' } -What 'rebind'
    Assert-Check $true 'rebound after expiry'

    # ---------------------------------------------------------- token renewal
    $state.Token = 'TOKEN-SECRET-OTHER'; $state.NextToken = 'TOKEN-SECRET-NEW'
    $state.PollStatus = 401
    $state.ClosePolls = $true
    Step-Until $worker { $null -eq $worker.Session } -What 'refused poll'
    $state.PollStatus = 200
    Step-Until $worker { $state.Binds -eq 4 -and (Snap $root)['state'] -ceq 'ready' } -What 'renewed bind'
    Assert-Check ((Read-TvPairing $root).LoungeToken -ceq 'TOKEN-SECRET-NEW' -and @($state.Log | Where-Object { $_.Path -like '*get_lounge_token_batch' }).Count -eq 1) 'a refused token is renewed once and saved sealed'

    # ---------------------------------------------------------- service trouble: backoff
    $state.BindStatus = 503
    $state.ClosePolls = $true
    $state.PollStatus = 503
    Step-Until $worker { (Snap $root)['state'] -ceq 'error' } -What 'error state'
    $first = $worker.NextAttemptMs
    $failures = $worker.Failures
    Assert-Check ($failures -ge 1 -and [long](Snap $root)['retry_at'] -gt 0) 'a failing service: error with a retry time'
    $binds = $state.Binds
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ($state.Binds -eq $binds -and @($state.Log | Where-Object { $_.Method -eq 'POST' -and $_.Path -like '*bind' -and -not $_.Query.ContainsKey('SID') }).Count -le 6) 'no retries before the wait is over'
    $worker.NextAttemptMs = 0
    Step-TvWorker $worker 20
    Assert-Check ($worker.Failures -eq $failures + 1 -and ($worker.NextAttemptMs - (Get-TvUnixMs)) -gt 8000) 'each failure in a row waits longer'
    $state.BindStatus = 200; $state.PollStatus = 200
    $worker.NextAttemptMs = 0
    Step-Until $worker { (Snap $root)['state'] -ceq 'ready' } -What 'recovery'
    Step-Until $worker { $worker.Failures -eq 0 } -What 'failures reset by events'
    Assert-Check $true 'recovers, and events reset the wait'

    # ---------------------------------------------------------- a token that cannot be renewed
    $state.Token = 'TOKEN-SECRET-GONE'; $state.TokenStatus = 403
    $state.ClosePolls = $true; $state.PollStatus = 401
    Step-Until $worker { $worker.Fatal } -What 'pair again'
    Assert-Check ((Snap $root)['state'] -ceq 'pair_again' -and (Snap $root)['valid_until'] -ceq '0') 'a refused renewal asks to pair again and stops'
    Close-TvPoll $worker.Poll
    $state.TokenStatus = 200; $state.PollStatus = 200

    # ---------------------------------------------------------- the whole run
    $root2 = Fresh-Root
    $root2 = Initialize-TvPrivateDirectory $root2
    $state.Token = 'TOKEN-SECRET-A'
    Save-TvPairing $root2 (New-TvPairing -ScreenId 'SCREEN-SECRET-0001' -LoungeToken 'TOKEN-SECRET-A' -Name 'x')
    Write-TvRequest $root2 next
    $leaves = $state.Leaves; $binds = $state.Binds; $nexts = @($state.Commands | Where-Object { $_.Name -ceq 'next' }).Count
    Invoke-TvRun $root2 -UntilMs ((Get-TvUnixMs) + 2500) -StepMs 50
    Assert-Check ($state.Binds -eq $binds + 1 -and $state.Leaves -eq $leaves + 1) 'a run binds once and leaves the session when it ends'
    Assert-Check (@($state.Commands | Where-Object { $_.Name -ceq 'next' }).Count -eq $nexts) 'a request from before the worker started is never acted on'
    Assert-Check ((Snap $root2)['state'] -ceq 'stopped' -and -not (Test-TvWorkerRunning $root2)) 'it ends with a stopped snapshot and releases its lock'
    Assert-Check (-not [IO.File]::Exists((Join-Path $root2 'events.log'))) 'no diagnostics unless asked for'
    Request-TvStop $root2
    $binds = $state.Binds
    Invoke-TvRun $root2 -UntilMs ((Get-TvUnixMs) + 2000) -StepMs 50
    Assert-Check ($state.Binds -eq $binds) 'a worker started after Stop does nothing'
    Clear-TvStop $root2
    $launch = New-TvLaunchId $root2
    Invoke-TvRun $root2 -Launch ('f' * 32) -UntilMs ((Get-TvUnixMs) + 2000) -StepMs 50
    Assert-Check ($state.Binds -eq $binds) 'a worker from an older launch does nothing'
    Invoke-TvRun $root2 -Lease '4:1' -UntilMs ((Get-TvUnixMs) + 2000) -StepMs 50
    Assert-Check ($state.Binds -eq $binds) 'a worker whose Rainmeter is gone does nothing'
    $root3 = Initialize-TvPrivateDirectory (Fresh-Root)
    Invoke-TvRun $root3 -UntilMs ((Get-TvUnixMs) + 1000) -StepMs 50
    Assert-Check ((Snap $root3)['state'] -ceq 'not_paired' -and $state.Binds -eq $binds) 'with no pairing it says so and connects nowhere'

    # ---------------------------------------------------------- Stop, Send, Forget
    Invoke-As 'Stop' $root
    Assert-Check ((Test-TvStop $root) -and -not (Test-TvIntent $root) -and (Snap $root)['state'] -ceq 'stopped') 'Stop leaves a barrier, clears intent, says stopped'
    $count = $script:launches.Count
    Invoke-As 'Resume' $root
    Assert-Check ($script:launches.Count -eq $count) 'Resume does not undo Stop'
    Invoke-As 'Send' $root @{ Action = 'next' }
    Assert-Check (-not [IO.File]::Exists((Join-Path $root 'tv.request'))) 'Send writes nothing when no worker runs'
    Invoke-As 'Start' $root
    Assert-Check ($script:launches.Count -eq $count + 1 -and -not (Test-TvStop $root)) 'Start lifts the barrier'
    Invoke-As 'Forget' $root
    Assert-Check (-not (Test-TvPaired $root) -and -not [IO.File]::Exists((Join-Path $root 'events.log')) -and (Snap $root)['state'] -ceq 'not_paired' -and -not (Test-TvIntent $root)) 'Forget removes the pairing and the diagnostics'
    Save-TvCover $root 1 (New-FakeJpeg 3); Save-TvCover $root 2 (New-FakeJpeg 4)
    Invoke-As 'Forget' $root
    Assert-Check (-not [IO.File]::Exists((Join-Path $root 'tv.cover1.jpg')) -and -not [IO.File]::Exists((Join-Path $root 'tv.cover2.jpg'))) 'Forget removes the thumbnails'
    Assert-Check ($state.Errors.Count -eq 0) ('the stand-in saw no errors: ' + (@($state.Errors) -join '; '))
} finally {
    Stop-TvStandIn $standIn
    if ([IO.Directory]::Exists($runRoot)) { [IO.Directory]::Delete($runRoot, $true) }
}
Write-Output "TV worker: $script:checks checks passed."
