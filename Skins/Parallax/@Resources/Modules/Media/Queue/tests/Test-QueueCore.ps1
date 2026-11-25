# Offline synthetic tests. No HTTP, accounts, tokens, or live Rainmeter access.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\QueueCore.psm1') -Force
$script:checks = 0
function Check([bool]$Condition, [string]$Label) { if (-not $Condition) { throw "FAILED: $Label" }; $script:checks++ }
function Reject([scriptblock]$Action, [string]$Label) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Check $failed $Label
}
$now = 1800000000L
$payload = ConvertFrom-QueueJson '{"currently_playing":null,"queue":[{"type":"track","name":"Synthetic title","artists":[{"name":"Artist"}]},{"type":"track","name":"Synthetic title","artists":[{"name":"Artist"}]},{"type":"episode","name":"Episode","show":{"name":"Show"}}]}'
$normalized = ConvertTo-QueueItems $payload
Check ($normalized.Items.Count -eq 3) 'track, duplicate, and episode retained'
Check ($normalized.Items[0].Title -ceq $normalized.Items[1].Title) 'duplicate order preserved'
Check ($normalized.Items[2].Detail -ceq 'Show') 'episode show source'
$text = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $normalized.Items -Now $now)
Check ($text.StartsWith("PARALLAX_QUEUE_V5`nstate=ready`n")) 'versioned inert snapshot'
Check ($text.Contains("count=3`ncontrol=0`nnotice=`n")) 'read-only grant: rows not clickable, no notice'
Check ($text.Contains('count=3')) 'display count'
Check ($text.EndsWith("title4=`ndetail4=`ntitle5=`ndetail5=`nimage1=`nimage2=`nimage3=`nimage4=`nimage5=`ncurrent_title=`ncurrent_detail=`n")) 'unused rows blank; no cover saved, none named; nothing playing, no current track'
Check ($text -notmatch 'Synthetic title|Artist|Episode') 'display metadata encoded, not Rainmeter syntax'
Check (($text -split "`n").Count -eq 26) 'exact bounded field count'
$controlText = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $normalized.Items -Now $now -Control $true -Notice 'queue_changed')
Check ($controlText.Contains("control=1`nnotice=queue_changed`n")) 'control grant and click notice recorded'
Reject { New-QueueSnapshot -State ready -Items $normalized.Items -Now $now -Notice 'skip_everything' } 'unknown notice rejected'
Reject { New-QueueSnapshot -State stopped -Now $now -Control $true } 'control without live rows rejected'
Reject { New-QueueSnapshot -State offline -Now $now -Notice 'no_device' } 'notice without live rows rejected'
foreach ($pair in @(@(204,''),@(200,''),@(401,'control_reauth'),@(403,'control_denied'),@(404,'no_device'),@(429,'control_failed'),@(500,'control_failed'),@(0,'control_failed'))) {
    Check ((Get-QueueControlDecision $pair[0]) -ceq $pair[1]) ('skip response ' + $pair[0])
}

# Current track (V5): what the rows come after. It never fails the queue read.
$playing = ConvertTo-QueueItems (ConvertFrom-QueueJson '{"currently_playing":{"type":"track","name":"Now #1","artists":[{"name":"One"},{"name":"Two"}]},"queue":[{"type":"track","name":"Next","artists":[{"name":"Artist"}]}]}')
Check ($playing.Current.Title -ceq 'Now #1' -and $playing.Current.Detail -ceq 'One, Two') 'current track named as a row would be'
$playingText = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $playing.Items -Now $now -Current $playing.Current)
Check ($playingText.EndsWith("image5=`ncurrent_title=4E6F77202331`ncurrent_detail=4F6E652C2054776F`n")) 'current track encoded after the covers'
$episodeNow = ConvertTo-QueueItems (ConvertFrom-QueueJson '{"currently_playing":{"type":"episode","name":"Now","show":{"name":"Show"}},"queue":[]}')
Check ($episodeNow.Current.Title -ceq 'Now' -and $episodeNow.Current.Detail -ceq 'Show') 'a current episode is named too'
Check ($null -eq $normalized.Current) 'nothing playing: no current track'
foreach ($odd in @('{"type":"ad","name":"x"}','{"type":"track"}','{"type":"track","name":7}','{}')) {
    $unread = ConvertTo-QueueItems (ConvertFrom-QueueJson ('{"currently_playing":' + $odd + ',"queue":[{"type":"track","name":"Next","artists":[]}]}'))
    Check ($unread.Items.Count -eq 1 -and $null -eq $unread.Current) ('an unreadable current item keeps the queue: ' + $odd)
}
Reject { New-QueueSnapshot -State stopped -Now $now -Current $playing.Current } 'current track without live rows rejected'
Reject { ConvertTo-QueueSnapshotText ([pscustomobject]@{ State='stopped'; Observed=0L; ValidUntil=0L; RetryNotBefore=0L; Items=@(); Current=$playing.Current }) } 'nonready text never names a current track'

# Covers (V4). Synthetic URLs on the allowlisted hosts; nothing is fetched.
$cdn = 'https://i.scdn.co/image/'
$album = '{"type":"track","name":"Track","artists":[{"name":"Artist"}],"album":{"images":[{"url":"' + $cdn + 'large","width":640,"height":640},{"url":"' + $cdn + 'medium","width":300,"height":300},{"url":"' + $cdn + 'small","width":64,"height":64}]}}'
$ownArt = '{"type":"episode","name":"Episode","images":[{"url":"' + $cdn + 'episode","width":300}],"show":{"name":"Show","images":[{"url":"' + $cdn + 'show","width":64}]}}'
$showArt = '{"type":"episode","name":"Episode","images":[],"show":{"name":"Show","images":[{"url":"' + $cdn + 'show-large","width":640},{"url":"' + $cdn + 'show-small","width":64}]}}'
$noArt = '{"type":"track","name":"Track","artists":[],"album":{"images":[]}}'
$noAlbum = '{"type":"track","name":"Track","artists":[]}'
$art = (ConvertTo-QueueItems (ConvertFrom-QueueJson ('{"currently_playing":null,"queue":[' + (@($album,$ownArt,$showArt,$noArt,$noAlbum) -join ',') + ']}'))).Items
Check ($art.Count -eq 5) 'items with and without art all read'
Check ($art[0].ImageUrl -ceq ($cdn + 'small')) 'album art: the smallest of at least 48 px'
Check ($art[1].ImageUrl -ceq ($cdn + 'episode')) 'episode: its own images first'
Check ($art[2].ImageUrl -ceq ($cdn + 'show-small')) 'episode without images: its show''s'
Check ($art[3].ImageUrl -ceq '' -and $art[4].ImageUrl -ceq '') 'empty or missing images: no cover'
Check (@($art | Where-Object { $_.Image -cne '' }).Count -eq 0) 'no cover is named before the helper saves it'
function Pick([string]$Json) { $holder = ConvertFrom-QueueJson ('{"images":' + $Json + '}'); return Select-QueueImageUrl $holder['images'] }
Check ((Pick '[{"url":"https://i.scdn.co/image/a","width":640},{"url":"https://i.scdn.co/image/b","width":300},{"url":"https://i.scdn.co/image/c","width":40}]') -ceq 'https://i.scdn.co/image/b') 'a 48 px minimum outranks a smaller image'
Check ((Pick '[{"url":"https://i.scdn.co/image/a","width":64.0},{"url":"https://i.scdn.co/image/b","width":640}]') -ceq 'https://i.scdn.co/image/a') 'fractional widths are numbers too'
Check ((Pick '[{"url":"https://i.scdn.co/image/a","width":null},{"url":"https://i.scdn.co/image/b"}]') -ceq 'https://i.scdn.co/image/b') 'no widths: the last listed'
Check ((Pick '[{"url":"https://i.scdn.co/image/a","width":32},{"url":"https://i.scdn.co/image/b","width":24}]') -ceq 'https://i.scdn.co/image/b') 'all below 48 px: the last listed'
Check ((Pick '[{"url":"https://evil.example/image/a","width":64},{"url":"https://i.scdn.co/image/b","width":640}]') -ceq 'https://i.scdn.co/image/b') 'off-CDN entries are skipped'
Check ((Pick '[]') -ceq '' -and (Pick 'null') -ceq '' -and (Pick '{"url":"https://i.scdn.co/image/a"}') -ceq '') 'no list: no cover'
Check ((Pick '[{"width":64},null,7,"https://i.scdn.co/image/a",{"url":7,"width":64}]') -ceq '') 'malformed entries: no cover, no failure'
$hostileArt = '{"currently_playing":null,"queue":[{"type":"track","name":"Track","artists":[],"album":{"images":"https://i.scdn.co/image/a"}},{"type":"episode","name":"Episode","images":7,"show":{"name":"Show","images":[null]}}]}'
Check (@((ConvertTo-QueueItems (ConvertFrom-QueueJson $hostileArt)).Items | Where-Object { $_.ImageUrl -ceq '' }).Count -eq 2) 'malformed art never fails the queue read'

foreach ($url in @('https://i.scdn.co/image/ab67616d00004851', 'https://mosaic.scdn.co/640/ab67616d0000b273', 'https://x.spotifycdn.com/image/abc', 'https://image-cdn-ak.spotifycdn.com/image/abc?x=1')) {
    Check (Test-QueueImageUrl $url) ('cover host accepted: ' + $url)
}
foreach ($url in @('http://i.scdn.co/image/a', 'https://evil.com/i.scdn.co', 'https://i.scdn.co@evil.com/', 'https://user:pw@i.scdn.co/image/a',
        'https://i.scdn.co:443/image/a', 'https://i.scdn.co:8443/image/a', 'https://x.spotifycdn.com:443/image/a', 'https://scdn.co/image/a', 'https://evilscdn.co/image/a',
        'https://i.scdn.co.evil.com/image/a', 'https://spotifycdn.com.evil.com/a', 'https://i.scdn.co', 'https://i.scdn.co\@evil.com/', 'https://I.SCDN.CO/image/a',
        'ftp://i.scdn.co/image/a', '//i.scdn.co/image/a', 'https://i.scdn.co/image/a b', ("https://i.scdn.co/image/a`n"), ('https://i.scdn.co/' + ('a' * 2048)), '', $null, 7)) {
    Check (-not (Test-QueueImageUrl $url)) ('cover host refused: ' + $url)
}
foreach ($url in @('http://i.scdn.co/image/a', 'https://evil.example/a', 'https://i.scdn.co@evil.example/', 'https://i.scdn.co:443/image/a')) {
    $refused = Invoke-QueueImageRequest -Uri $url
    Check ($refused.StatusCode -eq 0 -and $null -eq $refused.Bytes) ('a refused URL is never requested: ' + $url)
}
$parameters = @((Get-Command Invoke-QueueImageRequest).Parameters.Keys | Where-Object { $_ -notin [Management.Automation.PSCmdlet]::CommonParameters })
Check (($parameters -join ',') -ceq 'Uri') 'a cover request takes a URL and nothing else: no token can reach it'
Check ((Get-Command Invoke-QueueImageRequest).ScriptBlock.ToString() -cnotmatch '\.Headers|CookieContainer') 'a cover request sets no header or cookie beyond Accept'

Check ((Get-QueueImageKey 'abc') -ceq 'a9993e364706816aba3e25717850c26c9cd0d89d') 'cover key is lowercase SHA-1 of the URL text'
$jpeg = [byte[]]::new(64); $jpeg[0] = 0xFF; $jpeg[1] = 0xD8; $jpeg[2] = 0xFF
$png = [byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0,0,0,0,0,0,0,0)
Check ((Get-QueueImageExtension 'image/jpeg' $jpeg) -ceq 'jpg') 'JPEG by Content-Type and signature'
Check ((Get-QueueImageExtension 'image/png' $png) -ceq 'png') 'PNG by Content-Type and signature'
Check ((Get-QueueImageExtension 'Image/JPEG; charset=binary' $jpeg) -ceq 'jpg') 'Content-Type case and parameters ignored'
foreach ($bad in @(@('text/html',$jpeg), @('image/gif',$jpeg), @('image/webp',$jpeg), @('',$jpeg), @('image/png',$jpeg), @('image/jpeg',$png), @('image/jpeg',[byte[]](0xFF,0xD8,0xFF)))) {
    Check ((Get-QueueImageExtension $bad[0] $bad[1]) -ceq '') ('bad content type or body refused: ' + $bad[0])
}
$oversized = [byte[]]::new(262145); $oversized[0] = 0xFF; $oversized[1] = 0xD8; $oversized[2] = 0xFF
Check ((Get-QueueImageExtension 'image/jpeg' $oversized) -ceq '') 'a body over 256 KB is refused'
$whole = Read-QueueBoundedStream -Stream ([IO.MemoryStream]::new([byte[]]::new(262144))) -Limit 262144 -Milliseconds 5000
Check ($whole -is [byte[]] -and $whole.Length -eq 262144) 'a body at the 256 KB cap is read whole, as one array'
Check ($null -eq (Read-QueueBoundedStream -Stream ([IO.MemoryStream]::new($oversized)) -Limit 262144 -Milliseconds 5000)) 'a body past the cap is abandoned, never truncated'

$named = @([pscustomobject]@{ Title='A'; Detail='B'; Image=('0' * 40 + '.jpg') }, [pscustomobject]@{ Title='C'; Detail=''; Image='' })
$v5 = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $named -Now $now -Control $true -Current ([pscustomobject]@{ Title='E'; Detail='F' }))
$expected = "PARALLAX_QUEUE_V5`nstate=ready`nobserved=$now`nvalid_until=$($now + 90)`nretry_not_before=0`ncount=2`ncontrol=1`nnotice=`n" +
    "title1=41`ndetail1=42`ntitle2=43`ndetail2=`ntitle3=`ndetail3=`ntitle4=`ndetail4=`ntitle5=`ndetail5=`n" +
    "image1=$('0' * 40).jpg`nimage2=`nimage3=`nimage4=`nimage5=`ncurrent_title=45`ncurrent_detail=46`n"
Check ($v5 -ceq $expected) 'V5 is V4''s lines in V4''s order (V3''s, then image1..image5), then the current track'
Check ((ConvertTo-QueueSnapshotText (New-QueueSnapshot -State stopped -Now $now)).EndsWith("detail5=`nimage1=`nimage2=`nimage3=`nimage4=`nimage5=`ncurrent_title=`ncurrent_detail=`n")) 'a nonready snapshot names no covers and no current track'
foreach ($badName in @('..\x.jpg', ('A' * 40 + '.jpg'), ('0' * 40 + '.gif'), ('0' * 39 + '.jpg'), ('0' * 40 + '.jpg '), ('0' * 40 + '.JPG'), ('C:\covers\' + '0' * 40 + '.jpg'), "x`nimage2=")) {
    Reject { ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items @([pscustomobject]@{ Title='A'; Detail='B'; Image=$badName }) -Now $now) } ('cover name refused: ' + $badName)
}

$empty = ConvertTo-QueueItems (ConvertFrom-QueueJson '{"currently_playing":null,"queue":[]}')
Check ($empty.Items.Count -eq 0) 'real empty list accepted'
$emptyText = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $empty.Items -Now $now)
Check ($emptyText.Contains('state=ready') -and $emptyText.Contains('count=0')) 'measured empty distinguished'
foreach ($bad in @('{}','{"queue":[]}','{"currently_playing":null,"queue":null}','{"currently_playing":0,"queue":[]}','{"currently_playing":null,"queue":[null]}','{"currently_playing":null,"queue":[{"type":"unknown","name":"x"}]}','{"currently_playing":null,"queue":[{"type":"track","name":7}]}')) {
    Reject { ConvertTo-QueueItems (ConvertFrom-QueueJson $bad) } 'invalid queue not empty'
}
Reject { ConvertFrom-QueueJson ('[' * 30 + '0' + ']' * 30) } 'nested JSON bounded'
Reject { ConvertFrom-QueueJson ('x' * 1048577) } 'oversized response bounded'

$long = [char]::ConvertFromUtf32(0x1F3B5) * 400
$bounded = Limit-QueueText $long
$utf8 = [Text.UTF8Encoding]::new($false,$true)
Check ($utf8.GetByteCount($bounded) -eq 512) 'UTF8 byte cap preserves whole characters'
Check ((Limit-QueueText "one`nline`tlabel") -ceq 'one line label') 'control characters normalized'
$hostile = '#CURRENTCONFIG# [!Quit] %1'
$hostileItems = @([pscustomobject]@{Title=$hostile;Detail='artist'})
$hostileSnapshot = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $hostileItems -Now $now)
Check ($hostileSnapshot -notmatch '\[!Quit\]|#CURRENTCONFIG#|%1') 'metacharacters never executable cache'
$many = @{ currently_playing=$null; queue=@() }
for ($index=0; $index -lt 8; $index++) { $many.queue += @{type='track';name="Synthetic $index";artists=@()} }
Check ((ConvertTo-QueueItems $many).Items.Count -eq 5) 'display bounded to next five'

foreach ($state in @('onboarding_required','connecting','reauth_required','forbidden','rate_limited','quota_exceeded','offline','service_unavailable','error','stopped')) {
    $snapshot = New-QueueSnapshot -State $state -Now $now
    Check ($snapshot.Items.Count -eq 0 -and $snapshot.Observed -eq 0 -and $snapshot.ValidUntil -eq 0) 'nonlive states clear listening data'
    Reject { New-QueueSnapshot -State $state -Items $normalized.Items -Now $now } 'nonlive data rejected'
}
Reject { New-QueueSnapshot -State unknown -Now $now } 'unknown state rejected'
Check ((Get-QueueResponseDecision 200 -Now $now).State -eq 'response_requires_validation') 'HTTP200 still needs body validation'
Check ((Get-QueueResponseDecision 204 -Now $now).State -eq 'error') 'HTTP204 not fake empty'
Check ((Get-QueueResponseDecision 401 -Now $now).Pause) '401 pauses after refresh exhausted'
Check ((Get-QueueResponseDecision 403 -Now $now).State -eq 'forbidden') '403 not guessed reason'
Check ((Get-QueueResponseDecision 503 -Now $now).State -eq 'service_unavailable') '5xx distinguished'
Check ((Get-QueueResponseDecision 0 -Now $now).State -eq 'offline') 'connection failure distinguished'
$quota = Get-QueueResponseDecision 429 -Body '{"error":{"reason":"QUOTA_EXCEEDED"}}' -RetryAfter '20' -Now $now
Check ($quota.State -eq 'quota_exceeded' -and $quota.Pause -and $quota.RetryNotBefore -eq 0) 'quota exhaustion never invents reset'
foreach ($wait in @(1,120,86401,999999999999L)) {
    $decision = Get-QueueResponseDecision 429 -RetryAfter ([string]$wait) -Now $now
    Check ($decision.RetryNotBefore -ge [Math]::Min($now+$wait,253402300000L)) 'server wait never shortened'
}
Check ((Get-QueueResponseDecision 429 -RetryAfter 'garbage' -Now $now -FailureCount 4).RetryNotBefore -eq $now+300) 'bounded fallback backoff'
$date = [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc).AddSeconds($now+200).ToString('r',[Globalization.CultureInfo]::InvariantCulture)
Check ((Get-QueueResponseDecision 429 -RetryAfter $date -Now $now).RetryNotBefore -eq $now+200) 'HTTP-date retry preserved'

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-QueueCore-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runRoot
Publish-QueueSnapshot $runRoot (New-QueueSnapshot -State ready -Items $normalized.Items -Now $now)
Publish-QueueSnapshot $runRoot (New-QueueSnapshot -State stopped -Now $now)
$written = [IO.File]::ReadAllText((Join-Path $runRoot 'queue.snapshot'))
Check ($written.Contains('state=stopped') -and -not $written.Contains('53796E746865746963')) 'atomic replacement clears stale rows'
Check (@(Get-ChildItem -LiteralPath $runRoot -Filter '*.tmp' -Force).Count -eq 0) 'atomic temporary files cleaned'
$coverRoot = Join-Path $runRoot 'covers'
$null = New-Item -ItemType Directory -Path $coverRoot
$coverName = (Get-QueueImageKey ($cdn + 'small')) + '.jpg'
Write-QueueCoverFile -CoverRoot $coverRoot -Name $coverName -Bytes $jpeg
$saved = [IO.File]::ReadAllBytes((Join-Path $coverRoot $coverName))
Check ($saved.Length -eq $jpeg.Length -and $saved[1] -eq 0xD8) 'cover written whole under its final name'
Check (@(Get-ChildItem -LiteralPath $coverRoot -Force).Count -eq 1) 'cover temporary file cleaned'
Reject { Write-QueueCoverFile -CoverRoot $coverRoot -Name '..\escape.jpg' -Bytes $jpeg } 'cover name outside the pattern refused'
Reject { Write-QueueCoverFile -CoverRoot $coverRoot -Name $coverName -Bytes $oversized } 'oversized cover refused'
Reject { Write-QueueCoverFile -CoverRoot (Join-Path $runRoot 'missing') -Name $coverName -Bytes $jpeg } 'missing cover folder refused, not created'
Check (-not (Test-Path -LiteralPath (Join-Path $runRoot 'escape.jpg')) -and -not (Test-Path -LiteralPath (Join-Path $runRoot 'missing'))) 'refused covers leave nothing behind'
Write-Output "PASS: $script:checks offline queue core assertions. Synthetic evidence retained at $runRoot"
