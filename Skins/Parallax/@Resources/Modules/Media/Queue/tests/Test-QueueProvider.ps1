# Developer-only synthetic lifecycle tests. No Spotify requests or browser launch.
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\QueueProvider.ps1'))
. $provider -Command Help
$script:storageInitializations=0
function Initialize-QueuePrivateDirectory {
    param([string]$DataRoot)
    $script:storageInitializations++
    QueueAuth\Initialize-QueuePrivateDirectory -DataRoot $DataRoot
}
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-QueueProvider-test-' + [Guid]::NewGuid().ToString('N'))
$runRoot = Initialize-QueuePrivateDirectory $runRoot
$script:checks = 0
function Assert-Check { param([bool]$Value,[string]$Message); if (-not $Value) { throw $Message }; $script:checks++ }
function Fresh-Root { $root = Join-Path $runRoot ([Guid]::NewGuid().ToString('N')); return Initialize-QueuePrivateDirectory $root }
$script:responses = @()
$script:apiCalls = 0
$script:tokenCalls = 0
$script:refreshCalls = 0
$script:tokenFailure = ''
$script:tokenWait = 0L
$script:stopOnResponse = ''
$script:tokenControl = $true
$script:tokenPlaylists = $true
$script:endpoints = [Collections.Generic.List[string]]::new()
$script:requests = [Collections.Generic.List[string]]::new()
$script:verifyWorkerLocks = $false
$script:imageReplies = @{}
$script:imageRequests = [Collections.Generic.List[string]]::new()
$script:stopOnImage = ''
function Reset-Transport {
    param([object[]]$Replies = @())
    $script:responses = $Replies; $script:apiCalls=0; $script:tokenCalls=0; $script:refreshCalls=0
    $script:tokenFailure=''; $script:tokenWait=0L; $script:stopOnResponse=''
    $script:tokenControl=$true; $script:tokenPlaylists=$true; $script:endpoints=[Collections.Generic.List[string]]::new(); $script:requests=[Collections.Generic.List[string]]::new()
    $script:imageReplies=@{}; $script:imageRequests=[Collections.Generic.List[string]]::new(); $script:stopOnImage=''
    $script:CoverRetryAt=@{}
}
function Get-QueueAccessToken {
    param([string]$DataRoot,[switch]$ForceRefresh,[switch]$WithControl)
    if ($script:verifyWorkerLocks) {
        Assert-Check (Test-MutexAvailable ((Get-QueueMutexName $DataRoot)+'.Control')) 'Live polling releases lifecycle control before token work'
        Assert-Check (-not (Test-MutexAvailable (Get-QueueMutexName $DataRoot))) 'Live polling retains exclusive worker ownership'
    }
    $script:tokenCalls++; if ($ForceRefresh) { $script:refreshCalls++ }
    if ($script:tokenFailure) {
        $errorRecord = [InvalidOperationException]::new('Synthetic failure')
        $errorRecord.Data['QueueState']=$script:tokenFailure
        $errorRecord.Data['RetryAfterSeconds']=$script:tokenWait
        throw $errorRecord
    }
    if ($WithControl) { return [pscustomobject]@{ Token='SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'; Control=$script:tokenControl; Playlists=$script:tokenPlaylists } }
    return 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'
}
function Invoke-QueueApiRequest {
    param([string]$AccessToken,[string]$Endpoint='Queue',[string]$ContextUri='',[string]$ItemUri='',[int]$Offset=0)
    $script:endpoints.Add($Endpoint)
    $script:requests.Add((@($Endpoint,$ContextUri,$ItemUri,$Offset) -join '|'))
    Assert-Check ($AccessToken -ceq 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL') 'Unexpected synthetic token'
    if ($script:apiCalls -ge $script:responses.Count) { throw 'Unexpected synthetic request' }
    $response = $script:responses[$script:apiCalls]; $script:apiCalls++
    if ($script:stopOnResponse) { Request-QueueStop $script:stopOnResponse }
    return $response
}
# The synthetic image CDN. Every cover request in this suite lands here and is
# recorded; a URL with no prepared reply gets "no response", never the network.
function Invoke-QueueImageRequest {
    param([Parameter(Mandatory)][string]$Uri)
    Assert-Check ($PSBoundParameters.Count -eq 1 -and $PSBoundParameters.ContainsKey('Uri')) 'A cover request carries only its URL, never the token'
    $script:imageRequests.Add($Uri)
    if ($script:stopOnImage) { Request-QueueStop $script:stopOnImage }
    if (-not $script:imageReplies.ContainsKey($Uri)) { return [pscustomobject]@{ StatusCode=0; ContentType=''; Bytes=$null } }
    return $script:imageReplies[$Uri]
}
$script:jpeg = [byte[]]::new(64); $script:jpeg[0] = 0xFF; $script:jpeg[1] = 0xD8; $script:jpeg[2] = 0xFF
$script:png = [byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0,0,0,0,0,0,0,0)
function Cover { param([string]$Type='image/jpeg',[int]$Code=200,[object]$Bytes=$script:jpeg); return [pscustomobject]@{ StatusCode=$Code; ContentType=$Type; Bytes=$Bytes } }
function Art-Url { param([string]$Name); return 'https://i.scdn.co/image/synthetic-' + $Name }
function Art-Track { param([string]$Name); return '{"type":"track","name":"Synthetic ' + $Name + '","artists":[{"name":"Synthetic artist"}],"album":{"images":[{"url":"' + (Art-Url $Name) + '-640","width":640},{"url":"' + (Art-Url $Name) + '","width":64}]}}' }
function Art-Queue { param([string[]]$Names); return '{"currently_playing":null,"queue":[' + (@($Names | ForEach-Object { Art-Track $_ }) -join ',') + ']}' }
function Cover-Name { param([string]$Name,[string]$Extension='jpg'); return (Get-QueueImageKey (Art-Url $Name)) + '.' + $Extension }
function Cover-Files { param([string]$Root); $folder = Join-Path $Root 'covers'; if (-not [IO.Directory]::Exists($folder)) { return @() }; return @([IO.DirectoryInfo]::new($folder).GetFiles() | ForEach-Object { $_.Name } | Sort-Object) }
function Reply { param([int]$Code=200,[string]$Body='{"currently_playing":null,"queue":[]}',[string]$Wait=''); return [pscustomobject]@{StatusCode=$Code;Body=$Body;RetryAfter=$Wait} }
function Read-Snapshot { param([string]$Root); return [IO.File]::ReadAllText((Join-Path $Root 'queue.snapshot')) }
$root = Fresh-Root
Reset-Transport @(Reply)
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $cycle.Snapshot.State -eq 'ready' -and $cycle.Snapshot.Items.Count -eq 0) 'Measured empty queue must be ready'
Assert-Check ($cycle.Snapshot.ValidUntil-$cycle.Snapshot.Observed -eq 90) 'Default freshness window'
Assert-Check ($script:apiCalls -eq 1 -and $script:refreshCalls -eq 0) 'Success request count'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'queue.snapshot'))) 'Cycle should publish only through scheduler'

$duplicate = '{"type":"track","name":"Synthetic track","artists":[{"name":"Synthetic artist"}]}'
$episode = '{"type":"episode","name":"Synthetic episode","show":{"name":"Synthetic show"}}'
Reset-Transport @(Reply 200 ('{"currently_playing":null,"queue":['+$duplicate+','+$duplicate+','+$episode+']}'))
$cycle = Invoke-QueueCycle $root 150
Assert-Check ($cycle.Success -and $cycle.Snapshot.Items.Count -eq 3) 'Track/episode response accepted'
Assert-Check ($cycle.Snapshot.Items[0].Title -ceq $cycle.Snapshot.Items[1].Title) 'Duplicate order retained'
Assert-Check ($cycle.Snapshot.Items[2].Detail -ceq 'Synthetic show') 'Episode show retained'
Assert-Check ($cycle.Snapshot.ValidUntil-$cycle.Snapshot.Observed -eq 300) 'Maximum freshness window'
Assert-Check ($null -eq $cycle.Snapshot.Current) 'Nothing playing: the snapshot names no current track'
Reset-Transport @(Reply 200 ('{"currently_playing":'+$duplicate+',"queue":['+$episode+']}'))
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $cycle.Snapshot.Items.Count -eq 1 -and $cycle.Snapshot.Current.Title -ceq 'Synthetic track' -and $cycle.Snapshot.Current.Detail -ceq 'Synthetic artist') 'The snapshot names the track its rows come after'
Reset-Transport @(Reply 200 ('{"currently_playing":{"type":"ad"},"queue":['+$episode+']}'))
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $cycle.Snapshot.Items.Count -eq 1 -and $null -eq $cycle.Snapshot.Current) 'An unreadable current item never fails the queue read'

Reset-Transport @((Reply 401),(Reply))
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $script:apiCalls -eq 2 -and $script:refreshCalls -eq 1) '401 gets exactly one forced refresh and retry'
Assert-Check ($script:imageRequests.Count -eq 0 -and @(Cover-Files $root).Count -eq 0 -and -not [IO.Directory]::Exists((Join-Path $root 'covers'))) 'A queue without art requests and creates nothing'

# Covers: the download step of a successful read, against the synthetic CDN.
$root = Fresh-Root
Reset-Transport @(Reply 200 (Art-Queue 'a','b','c'))
$script:imageReplies[(Art-Url 'a')] = Cover
$script:imageReplies[(Art-Url 'b')] = Cover 'image/png' 200 $script:png
$script:imageReplies[(Art-Url 'c')] = Cover 'text/html'
$cycle = Invoke-QueueCycle $root 30
$images = @($cycle.Snapshot.Items | ForEach-Object { $_.Image })
Assert-Check ($cycle.Success -and $cycle.Snapshot.State -eq 'ready' -and $cycle.Snapshot.Items.Count -eq 3) 'A refused cover never fails the queue read'
Assert-Check ($images[0] -ceq (Cover-Name 'a') -and $images[1] -ceq (Cover-Name 'b' 'png') -and $images[2] -ceq '') 'Each row names its saved cover; the extension follows Content-Type; a bad type leaves the row empty'
Assert-Check ((@(Cover-Files $root) -join ',') -ceq ((@((Cover-Name 'a'), (Cover-Name 'b' 'png')) | Sort-Object) -join ',')) 'Only accepted covers are written, with no temporary file left'
Assert-Check (($script:imageRequests -join ',') -ceq ((@('a','b','c') | ForEach-Object { Art-Url $_ }) -join ',') -and $script:apiCalls -eq 1 -and ($script:endpoints -join ',') -ceq 'Queue') 'One request per shown cover, in row order, and no extra Spotify API call'
$covers = Join-Path $root 'covers'
$acl = [IO.Directory]::GetAccessControl($covers)
$rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
Assert-Check ($acl.AreAccessRulesProtected -and $rules.Count -eq 1 -and $rules[0].IdentityReference.Value -ceq [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) 'The covers folder has the data root''s current-user-only ACL'
$text = ConvertTo-QueueSnapshotText $cycle.Snapshot
Assert-Check (([regex]::Matches($text, '(?m)^image\d+=.*$') | ForEach-Object { $_.Value }) -join ' ' -ceq "image1=$(Cover-Name 'a') image2=$(Cover-Name 'b' 'png') image3=") 'The snapshot names the saved covers'

# A saved cover is reused and marked recently used; a refused one waits.
$aPath = Join-Path $covers (Cover-Name 'a')
[IO.File]::SetLastWriteTimeUtc($aPath, [DateTime]::UtcNow.AddDays(-2))
$retries = $script:CoverRetryAt.Clone()
Reset-Transport @(Reply 200 (Art-Queue 'a','b','c')); $script:CoverRetryAt = $retries
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($script:imageRequests.Count -eq 0 -and $cycle.Snapshot.Items[0].Image -ceq (Cover-Name 'a') -and $cycle.Snapshot.Items[1].Image -ceq (Cover-Name 'b' 'png')) 'Saved covers are reused without a request'
Assert-Check ([IO.File]::GetLastWriteTimeUtc($aPath) -gt [DateTime]::UtcNow.AddMinutes(-1)) 'Reuse renews the cover''s write time'
Assert-Check ($cycle.Snapshot.Items[2].Image -ceq '') 'A refused cover is not retried on the next read'
$items = (ConvertTo-QueueItems (ConvertFrom-QueueJson (Art-Queue 'c'))).Items
$script:imageReplies[(Art-Url 'c')] = Cover
Update-QueueCovers -Root $root -Items $items -Now ((Get-QueueUnixTime) + 301)
Assert-Check ($items[0].Image -ceq (Cover-Name 'c') -and ($script:imageRequests -join ',') -ceq (Art-Url 'c')) 'A refused cover is retried after five minutes'

# Refusals: oversized, abandoned, HTTP errors, and a CDN that gives no answer.
Reset-Transport @(Reply 200 (Art-Queue 'big','cut','gone','redirect','silent'))
$big = [byte[]]::new(262145); $big[0] = 0xFF; $big[1] = 0xD8; $big[2] = 0xFF
$script:imageReplies[(Art-Url 'big')] = Cover 'image/jpeg' 200 $big
$script:imageReplies[(Art-Url 'cut')] = Cover 'image/jpeg' 200 $null
$script:imageReplies[(Art-Url 'gone')] = Cover '' 404 $null
$script:imageReplies[(Art-Url 'redirect')] = Cover 'image/jpeg' 302 $null
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and @($cycle.Snapshot.Items | Where-Object { $_.Image -cne '' }).Count -eq 0) 'Oversized, abandoned, missing and redirected covers leave their rows empty'
Assert-Check (@(Cover-Files $root).Count -eq 3 -and ($script:imageRequests -join ',') -ceq ((@('big','cut','gone','redirect','silent') | ForEach-Object { Art-Url $_ }) -join ',')) 'Refused covers write nothing, and an HTTP refusal does not stop the next row'
Reset-Transport @(Reply 200 (Art-Queue 'a','silent','b','late'))
$cycle = Invoke-QueueCycle $root 30
Assert-Check (($script:imageRequests -join ',') -ceq (Art-Url 'silent')) 'No response ends this read''s downloads'
Assert-Check ($cycle.Success -and $cycle.Snapshot.Items[0].Image -ceq (Cover-Name 'a') -and $cycle.Snapshot.Items[2].Image -ceq (Cover-Name 'b' 'png') -and $cycle.Snapshot.Items[3].Image -ceq '') 'Saved covers are still reused after the CDN stops answering'
Reset-Transport @(Reply 200 (Art-Queue 'x','y')); $script:imageReplies[(Art-Url 'x')] = Cover; $script:imageReplies[(Art-Url 'y')] = Cover; $script:stopOnImage = $root
$cycle = Invoke-QueueCycle $root 30
Assert-Check (($script:imageRequests -join ',') -ceq (Art-Url 'x') -and $cycle.Snapshot.Items[1].Image -ceq '') 'Stop ends the downloads'
Clear-QueueStop $root
$offCdn = '{"currently_playing":null,"queue":[{"type":"track","name":"T","artists":[],"album":{"images":[{"url":"https://evil.example/image/a","width":64},{"url":"https://i.scdn.co@evil.example/b","width":64},{"url":"http://i.scdn.co/image/c","width":64}]}}]}'
Reset-Transport @(Reply 200 $offCdn)
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $script:imageRequests.Count -eq 0 -and $cycle.Snapshot.Items[0].Image -ceq '') 'Art off Spotify''s CDN is never requested'

# Pruning keeps the most recently used covers and every cover being published.
# Covers past the first rows arrive after the rows are published.
$laterRoot = Fresh-Root
$names8 = @(1..8 | ForEach-Object { 'later' + $_ })
Reset-Transport @(Reply 200 (Art-Queue $names8)); foreach ($n in $names8) { $script:imageReplies[(Art-Url $n)] = Cover }
$cycle = Invoke-QueueCycle $laterRoot 30
Assert-Check ($cycle.Snapshot.Items.Count -eq 8 -and $script:imageRequests.Count -eq 5 -and @($cycle.Snapshot.Items | Where-Object { $_.Image }).Count -eq 5) 'A read fetches the first five covers only'
Publish-QueueSnapshot $laterRoot $cycle.Snapshot
$at = Update-QueueRowCovers $laterRoot $cycle.Snapshot 5
Assert-Check ($at -eq 8 -and $script:imageRequests.Count -eq 8 -and [regex]::Matches((Read-Snapshot $laterRoot), '(?m)^image\d+=.+$').Count -eq 8) 'The rest follow in batches, in the same snapshot'
Reset-Transport @(Reply 200 (Art-Queue $names8))
$cycle = Invoke-QueueCycle $laterRoot 30
Assert-Check ($script:imageRequests.Count -eq 0 -and @($cycle.Snapshot.Items | Where-Object { $_.Image }).Count -eq 8) 'Saved covers are named at once, later rows included'
Reset-Transport @()
$null = Update-QueueRowCovers $laterRoot $cycle.Snapshot 5
Assert-Check ($script:imageRequests.Count -eq 0) 'A batch with nothing missing does nothing'
Assert-Check ($script:CoverLimit -eq 120) 'Room for the queue''s covers and fifty playlists'
$script:CoverLimit = 60 # fewer files to write here; the rule is the same
$pruneRoot = Fresh-Root
$folder = Join-Path $pruneRoot 'covers'; $null = Initialize-QueuePrivateDirectory $folder
$start = [DateTime]::UtcNow.AddDays(-10)
$names = @(for ($index = 0; $index -lt 70; $index++) { Get-QueueImageKey ('https://i.scdn.co/image/prune-' + $index) })
for ($index = 0; $index -lt 70; $index++) {
    $path = Join-Path $folder ($names[$index] + '.jpg')
    [IO.File]::WriteAllBytes($path, $script:jpeg); [IO.File]::SetLastWriteTimeUtc($path, $start.AddMinutes($index))
}
$leftover = Join-Path $folder ('.cover-' + [Guid]::NewGuid().ToString('N') + '.tmp'); [IO.File]::WriteAllBytes($leftover, $script:jpeg)
$foreign = Join-Path $folder 'notes.txt'; [IO.File]::WriteAllText($foreign, 'not a cover')
Limit-QueueCovers $folder @($names[0] + '.jpg')
$left = @(Cover-Files $pruneRoot)
Assert-Check ($left -contains ($names[0] + '.jpg')) 'Prune never deletes a cover named in the snapshot, even the oldest'
Assert-Check (@($left | Where-Object { $_ -cmatch '\A[0-9a-f]{40}\.jpg\z' }).Count -eq 61 -and -not ($left -contains ($names[9] + '.jpg')) -and ($left -contains ($names[10] + '.jpg'))) 'Prune keeps the 60 most recently written covers'
Assert-Check (-not [IO.File]::Exists($leftover) -and [IO.File]::Exists($foreign)) 'Prune clears its own leftover temporary files and nothing foreign'
Reset-Transport @(Reply 200 (Art-Queue 'p','q')); $script:imageReplies[(Art-Url 'p')] = Cover; $script:imageReplies[(Art-Url 'q')] = Cover
$cycle = Invoke-QueueCycle $pruneRoot 30
$left = @(Cover-Files $pruneRoot | Where-Object { $_ -cmatch '\A[0-9a-f]{40}\.jpg\z' })
Assert-Check ($left.Count -eq 60 -and ($left -contains (Cover-Name 'p')) -and ($left -contains (Cover-Name 'q')) -and -not ($left -contains ($names[0] + '.jpg'))) 'Each read prunes to 60, keeping the covers it publishes'
$script:CoverLimit = 120

# The scheduler publishes only after the covers it names exist.
$root = Fresh-Root
Reset-Transport @(Reply 200 (Art-Queue 'r','s','t')); $script:imageReplies[(Art-Url 'r')] = Cover; $script:imageReplies[(Art-Url 's')] = Cover '' 404 $null; $script:imageReplies[(Art-Url 't')] = Cover 'image/png' 200 $script:png
Invoke-QueueRun $root -Single -Silent
$published = @([regex]::Matches((Read-Snapshot $root), '(?m)^image[1-5]=(.+)$') | ForEach-Object { $_.Groups[1].Value })
Assert-Check ((Read-Snapshot $root).StartsWith("PARALLAX_QUEUE_V5`nstate=ready`n") -and ($published -join ',') -ceq ((Cover-Name 'r') + ',' + (Cover-Name 't' 'png'))) 'The published V5 snapshot names the saved covers'
Assert-Check (@($published | Where-Object { -not [IO.File]::Exists((Join-Path $root ('covers\' + $_))) }).Count -eq 0) 'Every published cover name exists on disk'

# Row clicks (Play) and Refresh. The click names the snapshot it was read from;
# the worker re-reads the queue and skips only while every row up to the click
# still matches. Synthetic transport only; no Spotify request.
$root = Fresh-Root
function Synthetic-Track { param([string]$Name); return '{"type":"track","name":"Synthetic ' + $Name + '","artists":[{"name":"Synthetic artist"}]}' }
$queueBody = '{"currently_playing":null,"queue":[' + (Synthetic-Track 'one') + ',' + (Synthetic-Track 'two') + ',' + (Synthetic-Track 'three') + ']}'
Reset-Transport @(Reply 200 $queueBody)
$cycle = Invoke-QueueCycle $root 30 -Notice 'no_device'
Assert-Check ($cycle.Snapshot.Control -and $cycle.Snapshot.Notice -ceq 'no_device') 'A control grant marks rows clickable and carries the notice'
Reset-Transport @(Reply 200 $queueBody); $script:tokenControl = $false
Assert-Check (-not (Invoke-QueueCycle $root 30).Snapshot.Control) 'A read-only grant leaves rows unclickable'
$last = $cycle.Snapshot
$play = [pscustomobject]@{ Kind='play'; Position=2; Observed=$last.Observed; Created=0 }
Reset-Transport @((Reply 200 $queueBody),(Reply 204 ''),(Reply 204 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next,Next') 'Row 2 re-reads the queue, then skips exactly twice'
# The click is a song, not a place: it is looked up in the queue as it is now.
$moved = '{"currently_playing":null,"queue":[' + (Synthetic-Track 'two') + ',' + (Synthetic-Track 'three') + ']}'
Reset-Transport @((Reply 200 $moved),(Reply 204 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next') 'A queue that moved up since still plays the clicked song'
$queued = '{"currently_playing":null,"queue":[' + (@('new','one','other','two') | ForEach-Object { Synthetic-Track $_ }) + ']}'
Reset-Transport @((Reply 200 ($queued.Replace('} {','},{'))),(Reply 204 ''),(Reply 204 ''),(Reply 204 ''),(Reply 204 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next,Next,Next,Next') 'and so does one it moved down in'
$gone = '{"currently_playing":null,"queue":[' + (Synthetic-Track 'one') + ',' + (Synthetic-Track 'three') + ']}'
Reset-Transport @(Reply 200 $gone)
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq 'queue_changed' -and ($script:endpoints -join ',') -ceq 'Queue') 'A song no longer queued is never skipped to'
$twice = '{"currently_playing":null,"queue":[' + (Synthetic-Track 'two') + ',' + (Synthetic-Track 'two') + ']}'
Reset-Transport @((Reply 200 $twice),(Reply 204 ''),(Reply 204 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next,Next') 'Of two alike, the one in the clicked place'
# The snapshot the click names may be one of the last few.
$later = [pscustomobject]@{ Observed=$last.Observed + 5; Items=@($last.Items[2]) }
Reset-Transport @((Reply 200 $queueBody),(Reply 204 ''),(Reply 204 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last,$later) -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next,Next') 'A click on the rows shown a moment ago still plays that song'
Reset-Transport @()
$stale = [pscustomobject]@{ Kind='play'; Position=2; Observed=($last.Observed - 1); Created=0 }
$notice = Invoke-QueuePlay -Root $root -Action $stale -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq 'queue_changed' -and $script:tokenCalls -eq 0 -and $script:apiCalls -eq 0) 'A click on rows this worker does not know does no token or network work'
Assert-Check ((Invoke-QueuePlay -Root $root -Action $play -Recent @() -GapMilliseconds 0) -ceq 'queue_changed' -and $script:apiCalls -eq 0) 'nor does one before any'
$beyond = [pscustomobject]@{ Kind='play'; Position=4; Observed=$last.Observed; Created=0 }
Assert-Check ((Invoke-QueuePlay -Root $root -Action $beyond -Recent @($last) -GapMilliseconds 0) -ceq 'queue_changed' -and $script:apiCalls -eq 0) 'A row past the snapshot is refused'
Reset-Transport @(); $script:tokenControl = $false
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq 'control_reauth' -and $script:apiCalls -eq 0) 'A read-only grant asks for sign-in and never skips'
Reset-Transport @((Reply 200 $queueBody),(Reply 404 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0
Assert-Check ($notice -ceq 'no_device' -and ($script:endpoints -join ',') -ceq 'Queue,Next') 'No active device stops at the first skip'
Reset-Transport @((Reply 200 $queueBody),(Reply 204 ''),(Reply 403 ''))
Assert-Check ((Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0) -ceq 'control_denied') 'A refused second skip is reported'
Reset-Transport @(); $script:tokenFailure = 'reauth_required'
Assert-Check ((Invoke-QueuePlay -Root $root -Action $play -Recent @($last) -GapMilliseconds 0) -ceq 'control_reauth') 'An expired grant asks for sign-in'
Reset-Transport @()

# Direct jump: a later row that belongs to the playing album or playlist.
function Addressed-Track { param([string]$Name,[string]$Id); return '{"type":"track","name":"Synthetic ' + $Name + '","artists":[{"name":"Synthetic artist"}],"uri":"' + (Song $Id) + '"}' }
function Song { param([string]$Id); return 'spotify:track:' + $Id * 22 }
function Playing { param([string]$Uri); return Reply 200 ('{"context":{"uri":"' + $Uri + '"},"item":null}') }
function Page { param([int]$Total,[string[]]$Ids); return Reply 200 ('{"total":' + $Total + ',"items":[' + (@($Ids | ForEach-Object { '{"item":{"uri":"' + (Song $_) + '"}}' }) -join ',') + ']}') }
$playlist = 'spotify:playlist:' + 'P' * 22
$addressedBody = '{"currently_playing":null,"queue":[' + (Addressed-Track 'one' 'a') + ',' + (Addressed-Track 'two' 'b') + ',' + (Addressed-Track 'three' 'c') + ']}'
Reset-Transport @(Reply 200 $addressedBody)
$jumpLast = (Invoke-QueueCycle $root 30).Snapshot
function Click { param([int]$Row); return Invoke-QueuePlay -Root $root -Action ([pscustomobject]@{ Kind='play'; Position=$Row; Observed=$jumpLast.Observed; Created=0 }) -Recent @($jumpLast) -GapMilliseconds 0 }
# What a start waits for: Spotify naming the song.
function Started { param([string]$Id); return Reply 200 ('{"context":null,"item":{"uri":"' + (Song $Id) + '"}}') }
function Expect { param([string]$Notice,[string]$Endpoints,[string]$Message); $got = Click $script:clickRow; Assert-Check ($got -ceq $Notice -and ($script:endpoints -join ',') -ceq $Endpoints) ($Message + ": got '$got' by " + ($script:endpoints -join ',')) }
$script:ContextItems = $null; $script:clickRow = 2
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Page 3 'a','b','c'),(Reply 204 ''),(Started 'b'))
Expect '' 'Queue,Playing,Items,Start,Playing' 'Row 2 of the playing playlist is played directly, with no skip'
Assert-Check ($script:requests[2] -ceq "Items|$playlist||0" -and $script:requests[3] -ceq ("Start|$playlist|" + (Song 'b') + '|0')) 'The start names the playing playlist and the clicked song'
$script:clickRow = 3
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Reply 204 ''),(Started 'a'),(Reply 500 ''),(Reply 200 'not-json'),(Started 'c'))
Expect '' 'Queue,Playing,Start,Playing,Playing,Playing,Playing' 'The playlist is read once while it plays, and the start is awaited'
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Reply 204 ''),(Started 'a'),(Started 'a'),(Started 'a'),(Started 'a'),(Started 'a'))
Expect '' 'Queue,Playing,Start,Playing,Playing,Playing,Playing,Playing' 'The wait for it is bounded, and no error'
$script:clickRow = 1
Reset-Transport @((Reply 200 $addressedBody),(Reply 204 ''))
Expect '' 'Queue,Next' 'Row 1 is one skip'
$script:clickRow = 2; $script:ContextItems = $null
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Page 5 'a','x'),(Page 5 'y','z'),(Page 5 'b'),(Reply 200 ''),(Started 'b'))
Expect '' 'Queue,Playing,Items,Items,Items,Start,Playing' 'A longer playlist is read page by page'
Assert-Check (($script:requests[2..4] -join ' ') -ceq "Items|$playlist||0 Items|$playlist||2 Items|$playlist||4") 'Each page continues where the last ended'
# Not possible: skip as before, and nothing was started.
$album = 'spotify:album:' + 'L' * 22
foreach ($case in @(
    @('a song queued by hand from elsewhere', @((Playing $playlist),(Page 2 'a','c')), 'Queue,Playing,Items,Next,Next'),
    @('an artist page', @(,(Playing ('spotify:artist:' + 'R' * 22))), 'Queue,Playing,Next,Next'),
    @('nothing playing', @(,(Reply 204 '')), 'Queue,Playing,Next,Next'),
    @('an unreadable state', @(,(Reply 200 'not-json')), 'Queue,Playing,Next,Next'),
    @('a playlist Spotify does not share', @((Playing $playlist),(Reply 403 '')), 'Queue,Playing,Items,Next,Next'),
    @('a malformed page', @((Playing $playlist),(Reply 200 '{"total":3}')), 'Queue,Playing,Items,Next,Next'),
    @('a page that stops short', @((Playing $playlist),(Page 3 'a','b'),(Reply 200 '{"total":3,"items":[]}')), 'Queue,Playing,Items,Items,Next,Next'),
    @('a refused start', @((Playing $album),(Page 3 'a','b','c'),(Reply 404 '')), 'Queue,Playing,Items,Start,Next,Next'))) {
    $script:ContextItems = $null
    Reset-Transport (@(Reply 200 $addressedBody) + $case[1] + @((Reply 204 ''),(Reply 204 '')))
    Expect '' $case[2] ('Skips instead: ' + $case[0])
}
$script:ContextItems = $null; $script:ContextPageLimit = 2
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Page 9 'a','x'),(Page 9 'y','z'),(Reply 204 ''),(Reply 204 ''))
Expect '' 'Queue,Playing,Items,Items,Next,Next' 'Skips instead: a playlist past the page limit'
$script:ContextPageLimit = 10
foreach ($unclear in @(0, 500, 503)) {
    $script:ContextItems = $null
    Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Page 3 'a','b','c'),(Reply $unclear ''))
    Expect 'control_failed' 'Queue,Playing,Items,Start' ('A start with no clear answer is not followed by skips: ' + $unclear)
}
$held = [pscustomobject]@{ Uri = $playlist; At = (Get-QueueUnixTime) - 1801; Items = $null }
$script:ContextItems = $held
Reset-Transport @((Reply 200 $addressedBody),(Playing $playlist),(Page 3 'a','b','c'),(Reply 204 ''),(Started 'b'))
Expect '' 'Queue,Playing,Items,Start,Playing' 'A list kept for half an hour is read again'
Reset-Transport @((Reply 200 $addressedBody),(Playing $album),(Page 3 'a','b','c'),(Reply 204 ''),(Started 'b'))
Expect '' 'Queue,Playing,Items,Start,Playing' 'Another context is read afresh'
# A clicked song of the playing playlist that the queue no longer lists still plays.
$elsewhere = '{"currently_playing":null,"queue":[' + (Addressed-Track 'one' 'a') + ']}'
Reset-Transport @((Reply 200 $elsewhere),(Playing $album),(Reply 204 ''),(Started 'b'))
Expect '' 'Queue,Playing,Start,Playing' 'It is started in its playlist, wherever the queue has gone'
$script:ContextItems = $null
Reset-Transport @((Reply 200 $elsewhere),(Playing $playlist),(Page 1 'a'))
Expect 'queue_changed' 'Queue,Playing,Items' 'One that is neither queued nor in the playlist is refused, with no skip'
$script:ContextItems = $null
Reset-Transport @()

# Playlists view: listing, covers and starting one. Synthetic transport only.
function List-Body { param([string[]]$Ids); return '{"total":' + $Ids.Count + ',"items":[' + (@($Ids | ForEach-Object { '{"name":"List ' + $_ + '","uri":"spotify:playlist:' + $_ * 22 + '","items":{"total":7},"images":[{"url":"' + (Art-Url ('list-' + $_)) + '","width":64}]}' }) -join ',') + ']}' }
function Read-List { param([string]$Root); return [IO.File]::ReadAllText((Join-Path $Root 'playlists.snapshot')) }
$listRoot = Fresh-Root
Reset-Transport @((Reply 200 (List-Body 'm','n','o','p')),(Playing ('spotify:playlist:' + 'n' * 22)))
$list = Invoke-QueuePlaylists $listRoot -Now 1800000000
Assert-Check ($list.State -ceq 'ready' -and $list.Items.Count -eq 4 -and $list.Current -eq 2 -and ($script:endpoints -join ',') -ceq 'Playlists,Playing') 'The list is read once, with the playing one marked'
Assert-Check ((Read-List $listRoot).StartsWith("PARALLAX_PLAYLISTS_V1`nstate=ready`nobserved=1800000000`ntotal=4`ncount=4`ncurrent=2`ntitle1=")) 'The list is published at once, covers later'
Assert-Check ($script:imageRequests.Count -eq 0 -and (Read-List $listRoot) -notmatch 'spotify:|[mnop]{22}') 'No cover is fetched and no address is written with it'
Reset-Transport @()
foreach ($id in 'm','n','o','p') { $script:imageReplies[(Art-Url ('list-' + $id))] = Cover }
Update-QueuePlaylistCovers $listRoot $list
Assert-Check ($script:imageRequests.Count -eq 3 -and $list.CoverAt -eq 3 -and [regex]::Matches((Read-List $listRoot), '(?m)^image\d+=.+$').Count -eq 3) 'Covers arrive in small batches'
Update-QueuePlaylistCovers $listRoot $list
Assert-Check ($script:imageRequests.Count -eq 4 -and [regex]::Matches((Read-List $listRoot), '(?m)^image\d+=.+$').Count -eq 4 -and (Read-List $listRoot) -match '(?m)^observed=1800000000$') 'The last batch completes the same list'
$open = [pscustomobject]@{ Kind='open'; Position=3; Observed=1800000000L; Created=0 }
Reset-Transport @((Reply 204 ''),(Playing ('spotify:playlist:' + 'n' * 22)),(Playing ('spotify:playlist:' + 'o' * 22)))
Assert-Check ((Invoke-QueueOpen -Root $listRoot -Action $open -List $list -SettleMilliseconds 0) -ceq '' -and ($script:requests -join ' ') -ceq ('Open|spotify:playlist:' + 'o' * 22 + '||0 Playing|||0 Playing|||0')) 'A click starts exactly the clicked playlist, and waits for Spotify to say so'
Assert-Check ($list.Current -eq 3 -and (Read-List $listRoot) -match '(?m)^current=3$') 'and the list marks it as playing'
foreach ($case in @(@(404,'no_device'),@(403,'control_denied'),@(401,'control_reauth'),@(429,'control_failed'),@(500,'control_failed'),@(0,'control_failed'))) {
    Reset-Transport @(Reply $case[0] '')
    Assert-Check ((Invoke-QueueOpen -Root $listRoot -Action $open -List $list -SettleMilliseconds 0) -ceq $case[1] -and $list.Current -eq 3) ('A refused start is reported: ' + $case[0])
}
Reset-Transport @()
foreach ($bad in @(@($null,3,1800000000L), @($list,3,1799999999L), @($list,5,1800000000L), @([pscustomobject]@{ State='error'; Items=@(); Observed=1800000000L },1,1800000000L))) {
    Assert-Check ((Invoke-QueueOpen -Root $listRoot -Action ([pscustomobject]@{ Kind='open'; Position=$bad[1]; Observed=$bad[2]; Created=0 }) -List $bad[0] -SettleMilliseconds 0) -ceq 'queue_changed') 'A click on a list this worker does not hold starts nothing'
}
Assert-Check ($script:apiCalls -eq 0 -and $script:tokenCalls -eq 0) 'and does no token or network work'
$script:tokenControl = $false
Assert-Check ((Invoke-QueueOpen -Root $listRoot -Action $open -List $list -SettleMilliseconds 0) -ceq 'control_reauth' -and $script:apiCalls -eq 0) 'A read-only grant starts nothing'
Reset-Transport @(); $script:tokenPlaylists = $false
Assert-Check ((Invoke-QueuePlaylists $listRoot).State -ceq 'scope_required' -and $script:apiCalls -eq 0 -and (Read-List $listRoot) -match 'state=scope_required') 'A grant without the permission asks for sign-in, and makes no request'
foreach ($case in @(@(403,'{}','scope_required'),@(500,'','error'),@(0,'','error'),@(429,'{}','error'),@(200,'not-json','error'),@(200,'{}','error'))) {
    Reset-Transport @(Reply $case[0] $case[1])
    $failed = Invoke-QueuePlaylists $listRoot
    Assert-Check ($failed.State -ceq $case[2] -and $failed.Items.Count -eq 0 -and (Read-List $listRoot) -match 'count=0') ('A failed list names nothing: ' + $case[0] + ' ' + $case[1])
}
Reset-Transport @(); $script:tokenFailure = 'reauth_required'
Assert-Check ((Invoke-QueuePlaylists $listRoot).State -ceq 'scope_required') 'An expired grant asks for sign-in'
Reset-Transport @((Reply 200 (List-Body 'm')),(Reply 500 ''))
Assert-Check ((Invoke-QueuePlaylists $listRoot).Current -eq 0) 'An unknown player state marks none'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $listRoot 'queue.snapshot')) -and $null -eq (Get-QueueRetry $listRoot)) 'Listing never touches the queue rows or its waits'
Reset-Transport @()
foreach ($good in @(@('playlists',0,0),@('open',1,5),@('open',50,1800000000))) {
    [IO.File]::WriteAllText((Join-Path $root 'action.request'), ("PARALLAX_QUEUE_ACTION_V1|{0}|{1}|{2}|{3}`n" -f $good[0],$good[1],$good[2],(Get-QueueUnixTime)), [Text.Encoding]::ASCII)
    $read = Read-QueueAction $root
    Assert-Check ($read.Kind -ceq $good[0] -and $read.Position -eq $good[1] -and $read.Observed -eq $good[2]) ('A playlist request is read: ' + ($good -join ' '))
}
foreach ($bad in @('playlists|1|0','playlists|0|5','open|0|5','open|51|5','open|1|0','open|100|5','play|21|5')) {
    [IO.File]::WriteAllText((Join-Path $root 'action.request'), ("PARALLAX_QUEUE_ACTION_V1|$bad|" + (Get-QueueUnixTime) + "`n"), [Text.Encoding]::ASCII)
    Assert-Check ($null -eq (Read-QueueAction $root)) ('A malformed playlist request is discarded: ' + $bad)
}

Write-QueueAction $root play 2 $last.Observed
$read = Read-QueueAction $root
Assert-Check ($read.Kind -ceq 'play' -and $read.Position -eq 2 -and $read.Observed -eq $last.Observed) 'A click request round-trips'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'action.request'))) 'A request is consumed once'
Assert-Check ($null -eq (Read-QueueAction $root)) 'No request reads as none'
Write-QueueAction $root refresh
Assert-Check ($null -eq (Read-QueueAction $root -Now ((Get-QueueUnixTime) + 60))) 'A request older than 15 seconds is discarded'
foreach ($bad in @("PARALLAX_QUEUE_ACTION_V1|play|9|1|1`n", "PARALLAX_QUEUE_ACTION_V1|play|0|1|NOW`n", "PARALLAX_QUEUE_ACTION_V1|stop|0|0|NOW`n", "PARALLAX_QUEUE_ACTION_V1|refresh|1|0|NOW`n", "PARALLAX_QUEUE_ACTION_V1|play|1|1|NOW")) {
    [IO.File]::WriteAllText((Join-Path $root 'action.request'), $bad.Replace('NOW', [string](Get-QueueUnixTime)), [Text.Encoding]::ASCII)
    Assert-Check ($null -eq (Read-QueueAction $root)) ('A malformed request is discarded: ' + $bad.Trim())
    Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'action.request'))) 'A malformed request is removed'
}
# The skin writes the refresh request itself when the player changes track
# (QueueReader.lua). One still open is left for the next pass: the worker must
# neither fail nor lose it.
$requestPath = Join-Path $root 'action.request'
[IO.File]::WriteAllText($requestPath, ("PARALLAX_QUEUE_ACTION_V1|refresh|0|0|" + (Get-QueueUnixTime) + "`n"), [Text.Encoding]::ASCII)
$held = [IO.FileStream]::new($requestPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
try {
    Assert-Check ($null -eq (Read-QueueAction $root)) 'A request someone holds open reads as none'
    Assert-Check (Test-Path -LiteralPath $requestPath) 'A held request is not lost'
} finally { $held.Dispose() }
Assert-Check ((Read-QueueAction $root).Kind -ceq 'refresh' -and -not (Test-Path -LiteralPath $requestPath)) 'A released request is read on the next pass'
$rejected = $false; try { Write-QueueAction $root play 0 1 } catch { $rejected = $true }
Assert-Check $rejected 'A play request needs a row'

# The control command writes a request only while a worker holds its mutex.
$savedRoot = $DataRoot; $savedCommand = $Command
$DataRoot = $root; $Command = 'Play'; $Position = 1; $Observed = $last.Observed
Invoke-QueueCommand
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'action.request'))) 'No running worker: a click writes nothing'
# A real worker holds it in another process; a mutex is re-entrant for its
# owning thread, so the stand-in holds it from a separate runspace thread.
$ready = [Threading.ManualResetEvent]::new($false); $release = [Threading.ManualResetEvent]::new($false)
$holder = [PowerShell]::Create()
$null = $holder.AddScript({ param($Name,$Ready,$Release) $m = [Threading.Mutex]::new($false,$Name); $null = $m.WaitOne(); $null = $Ready.Set(); $null = $Release.WaitOne(); $m.ReleaseMutex(); $m.Dispose() }).AddArgument((Get-QueueMutexName $root)).AddArgument($ready).AddArgument($release)
$handle = $holder.BeginInvoke()
Assert-Check ($ready.WaitOne(10000)) 'Stand-in worker holds the run mutex'
try {
    Invoke-QueueCommand
    Assert-Check ((Read-QueueAction $root).Position -eq 1) 'A running worker receives the click'
    $Command = 'Refresh'; Invoke-QueueCommand
    Assert-Check ((Read-QueueAction $root).Kind -ceq 'refresh') 'A running worker receives Refresh'
    Request-QueueStop $root; $Command = 'Play'; Invoke-QueueCommand
    Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'action.request'))) 'A stopped helper receives nothing'
    Clear-QueueStop $root
} finally { $null = $release.Set(); $null = $holder.EndInvoke($handle); $holder.Dispose(); $ready.Dispose(); $release.Dispose() }
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0) 'Control commands never touch tokens or the network'
$DataRoot = $savedRoot; $Command = $savedCommand; $Position = 0; $Observed = 0
Reset-Transport @((Reply 401),(Reply 401))
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Pause -and $cycle.Snapshot.State -eq 'reauth_required' -and $script:apiCalls -eq 2 -and $script:refreshCalls -eq 1) 'Repeated401 pauses without loop'
foreach ($body in @('not-json','{}','{"currently_playing":null,"queue":[{"type":"unknown","name":"x"}]}')) {
    Reset-Transport @(Reply 200 $body)
    $cycle = Invoke-QueueCycle $root 30
    Assert-Check (-not $cycle.Success -and $cycle.Snapshot.State -eq 'error' -and $cycle.Snapshot.Items.Count -eq 0) 'Malformed200 suppresses rows'
}
foreach ($test in @(@(403,'forbidden',$true),@(429,'rate_limited',$false),@(503,'service_unavailable',$false),@(0,'offline',$false))) {
    Reset-Transport @(Reply $test[0] '{}' '7200')
    $cycle = Invoke-QueueCycle $root 30
    Assert-Check ($cycle.Snapshot.State -eq $test[1] -and $cycle.Pause -eq $test[2] -and -not $cycle.Success -and $cycle.Snapshot.Items.Count -eq 0) 'Failure state and suppression'
}
Reset-Transport @(Reply 429 '{"error":{"reason":"QUOTA_EXCEEDED"}}' '30')
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Pause -and $cycle.NextAt -eq 0 -and $cycle.Snapshot.State -eq 'quota_exceeded') 'Quota exhaustion has no invented reset'
foreach ($state in @('onboarding_required','reauth_required','forbidden','quota_exceeded')) {
    Reset-Transport; $script:tokenFailure=$state
    $cycle = Invoke-QueueCycle $root 30
    Assert-Check ($cycle.Pause -and $cycle.Snapshot.State -eq $state -and $script:apiCalls -eq 0) 'Auth failure sends no queue request'
}
Reset-Transport; $script:tokenFailure='rate_limited'; $script:tokenWait=3000000000L
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Snapshot.State -eq 'rate_limited' -and $cycle.NextAt -ge (Get-QueueUnixTime)+2999999999L) 'Long token-service wait retained'

$root = Fresh-Root
Reset-Transport @(Reply)
# A click left from before this worker started is discarded, never acted on;
# so is a playlist list another worker wrote, whose playlists this one lacks.
Write-QueueAction $root play 1 1
[IO.File]::WriteAllText((Join-Path $root 'playlists.snapshot'), 'stale')
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=ready' -and $script:apiCalls -eq 1) 'One-shot publishes validated snapshot'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $root 'playlists.snapshot'))) 'A new worker removes an earlier worker''s playlist list'
Assert-Check (($script:endpoints -join ',') -ceq 'Queue' -and -not (Test-Path -LiteralPath (Join-Path $root 'action.request'))) 'A request from before the worker started is discarded'
Assert-Check ((Read-Snapshot $root) -notmatch 'SYNTHETIC_ACCESS') 'No token in display cache'
Reset-Transport @(Reply 429 '{}' '3600')
Invoke-QueueRun $root -Single -Silent
$retry = Get-QueueRetry $root
Assert-Check ($retry.State -eq 'rate_limited' -and $retry.RetryNotBefore -gt (Get-QueueUnixTime)+3598) 'Server wait persisted'
Reset-Transport
Invoke-QueueRun $root -Single -Silent -RetryQuota
Assert-Check ($script:apiCalls -eq 0 -and $script:tokenCalls -eq 0) 'Explicit quota resume cannot bypass Retry-After'
Set-QueueRetry $root ([pscustomobject]@{State='rate_limited';RetryNotBefore=1L;Pause=$false})
Reset-Transport @(Reply)
Invoke-QueueRun $root -Single -Silent
Assert-Check ($script:apiCalls -eq 1 -and $null -eq (Get-QueueRetry $root)) 'Expired retry permits request and success clears record'
Reset-Transport @(Reply 429 '{"error":{"reason":"QUOTA_EXCEEDED"}}')
Invoke-QueueRun $root -Single -Silent
Reset-Transport
Invoke-QueueRun $root -Single -Silent
Assert-Check ($script:apiCalls -eq 0 -and (Read-Snapshot $root) -match 'state=quota_exceeded') 'Restart preserves quota pause'
Reset-Transport @(Reply)
Invoke-QueueRun $root -Single -Silent -RetryQuota
Assert-Check ($script:apiCalls -eq 1 -and (Read-Snapshot $root) -match 'state=ready') 'Explicit quota recovery retries'
Reset-Transport @(Reply); $script:stopOnResponse=$root
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=stopped' -and (Read-Snapshot $root) -match 'count=0') 'Stop during request prevents response publication'
# Model a later explicit Start; a delayed Run must never clear Stop itself.
Clear-QueueStop $root
Reset-Transport @(Reply 429 '{}' '3600'); $script:stopOnResponse=$root
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=stopped' -and (Get-QueueRetry $root).RetryNotBefore -gt (Get-QueueUnixTime)+3598) 'Stop during429 retains server retry barrier'
Clear-QueueStop $root
Reset-Transport
Invoke-QueueRun $root -Single -Silent
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0) 'Restart after in-flight429 does not bypass server wait'

# A different runspace holds the named mutex, proving duplicate starts do no work.
$root = Fresh-Root
$entered = [Threading.ManualResetEvent]::new($false)
$release = [Threading.ManualResetEvent]::new($false)
$holder = [PowerShell]::Create()
$null = $holder.AddScript('param($name,$entered,$release) $mutex=[Threading.Mutex]::new($false,$name); try { $null=$mutex.WaitOne(); $null=$entered.Set(); $null=$release.WaitOne(15000) } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }').AddArgument((Get-QueueMutexName $root)).AddArgument($entered).AddArgument($release)
$pending = $holder.BeginInvoke()
try {
    Assert-Check ($entered.WaitOne(5000)) 'Mutex holder did not start'
    Reset-Transport
    Invoke-QueueRun $root -Single -Silent
    Assert-Check ($script:tokenCalls -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $root 'queue.snapshot'))) 'Duplicate worker makes no request or cache write'
} finally { $null=$release.Set(); $null=$holder.EndInvoke($pending); $holder.Dispose(); $entered.Dispose(); $release.Dispose() }

# CLI account actions use synthetic configuration and a stub browser launcher.
$DataRoot = Fresh-Root; $ClientId='00000000000000000000000000000001'; $Quiet=$true
$Command='Configure'; $output=@(Invoke-QueueCommand)
Assert-Check ($output.Count -eq 0 -and (Get-QueueClientId $DataRoot) -eq $ClientId) 'Configure is quiet and saves only public ID'
Assert-Check (-not (Test-QueueEnabledIntent $DataRoot) -and (Test-QueueStop $DataRoot)) 'Configuration alone does not enable resume'
$script:connectCalls=0; $script:launchCalls=0; $script:connectFailure=''
function Connect-QueueSpotify {
    param([string]$DataRoot)
    $script:connectCalls++
    if ($script:connectFailure) { $ex=[InvalidOperationException]::new('Synthetic'); $ex.Data['QueueState']=$script:connectFailure; $ex.Data['RetryAfterSeconds']=1800L; throw $ex }
}
function Test-MutexAvailable {
    param([string]$Name)
    $probe = [PowerShell]::Create()
    try {
        $null = $probe.AddScript('param($name) $mutex=[Threading.Mutex]::new($false,$name); $owned=$false; try { $owned=$mutex.WaitOne(0); return $owned } finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }').AddArgument($Name)
        $result = @($probe.Invoke())
        if ($probe.HadErrors -or $result.Count -ne 1) { throw 'Mutex probe failed' }
        return [bool]$result[0]
    } finally { $probe.Dispose() }
}
function Start-Process {
    param([string]$FilePath,[string]$ArgumentList,[string]$WorkingDirectory,[string]$WindowStyle,[switch]$PassThru)
    Assert-Check ($FilePath -ceq (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -and $WindowStyle -ceq 'Hidden' -and $PassThru) 'Background launcher uses hidden Windows PowerShell'
    Assert-Check ($ArgumentList -match ' -DataRoot "([^"]+)"') 'Launch root is quoted'
    $Root=$Matches[1]
    Assert-Check ($WorkingDirectory -ceq $Root) 'Worker starts in its private storage, never the skin folder'
    Assert-Check ($ArgumentList -match ' -PollSeconds (\d+) ') 'Launch interval is a fixed integer'
    $Interval=[int]$Matches[1]
    Assert-Check ($ArgumentList -match ' -LaunchId ([a-f0-9]{32}) ') 'Child receives a fixed canonical launch permit'
    $identifier=$Matches[1]
    Assert-Check (Test-QueueLaunchId $Root $identifier) 'Launch permit is atomically saved before the child is requested'
    Assert-Check (-not (Test-MutexAvailable ((Get-QueueMutexName $Root)+'.Control'))) 'Lifecycle control remains owned through child launch'
    Assert-Check (Test-MutexAvailable (Get-QueueMutexName $Root)) 'Worker ownership is released before child launch'
    $script:launchCalls++; $script:lastLaunchInterval=$Interval; $script:lastLaunchRoot=$Root; $script:lastLaunchQuota=$ArgumentList.Contains(' -ResumeAfterQuota'); $script:lastLaunchId=$identifier
}
$Command='Connect'; $ClientId=''; $script:connectFailure='rate_limited'
Invoke-QueueCommand
Assert-Check ((Get-QueueRetry $DataRoot).State -eq 'rate_limited' -and $script:launchCalls -eq 0) 'Connect failure persists wait and launches no worker'
Assert-Check (-not (Test-QueueEnabledIntent $DataRoot)) 'Failed consent leaves automatic resume disabled'
$script:connectFailure=''; Invoke-QueueCommand
Assert-Check ($script:connectCalls -eq 1 -and $script:launchCalls -eq 0) 'Repeated connect preserves wait'
Set-QueueRetry $DataRoot ([pscustomobject]@{State='rate_limited';RetryNotBefore=1L;Pause=$false})
Invoke-QueueCommand
Assert-Check ($script:connectCalls -eq 2 -and $script:launchCalls -eq 1) 'Completed consent launches one worker'
Assert-Check ((Test-QueueEnabledIntent $DataRoot) -and -not (Test-QueueStop $DataRoot)) 'Successful consent enables future resume'
[IO.File]::WriteAllText((Join-Path $DataRoot 'tokens.dpapi'),'SYNTHETIC_ENCRYPTED_FILE_FIXTURE')
$coverFolder = Initialize-QueuePrivateDirectory (Join-Path $DataRoot 'covers')
[IO.File]::WriteAllBytes((Join-Path $coverFolder (Cover-Name 'private')), $script:jpeg)
Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State ready -Items @([pscustomobject]@{Title='SYNTHETIC_PRIVATE_TITLE';Detail='Fixture';Image=(Cover-Name 'private')}))
[IO.File]::WriteAllText((Join-Path $DataRoot 'playlists.snapshot'), 'list')
$Command='Disconnect'; Invoke-QueueCommand
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'tokens.dpapi'))) 'Disconnect removes token file'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'playlists.snapshot'))) 'Disconnect removes the playlist list'
Assert-Check (-not (Test-Path -LiteralPath $coverFolder)) 'Disconnect deletes the covers folder'
Assert-Check ((Read-Snapshot $DataRoot) -notmatch '(?m)^image[1-5]=.') 'Disconnect leaves no cover named'
# A covers entry that is a junction is removed as a link; its target is untouched.
$outside = Join-Path $runRoot ('outside-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $outside
[IO.File]::WriteAllText((Join-Path $outside 'keep.txt'), 'outside the data root')
$null = New-Item -ItemType Junction -Path $coverFolder -Target $outside
Invoke-QueueCommand
Assert-Check (-not (Test-Path -LiteralPath $coverFolder) -and [IO.File]::Exists((Join-Path $outside 'keep.txt'))) 'Disconnect removes a covers junction without entering it'
Assert-Check ((Read-Snapshot $DataRoot) -match 'state=onboarding_required' -and (Read-Snapshot $DataRoot) -match 'count=0' -and (Read-Snapshot $DataRoot) -notmatch '53594E5448455449435F505249564154455F5449544C45') 'Disconnect removes queue metadata'
Assert-Check ((Get-QueueClientId $DataRoot) -eq '00000000000000000000000000000001') 'Disconnect retains public app configuration'
Assert-Check (-not (Test-QueueEnabledIntent $DataRoot) -and (Test-QueueStop $DataRoot)) 'Disconnect persistently disables resume'
Reset-Transport
Invoke-QueueRun $DataRoot -Single -Silent
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -match 'state=onboarding_required') 'Delayed Run cannot undo completed Disconnect or overwrite onboarding'
$Command='Stop'; Invoke-QueueCommand
Assert-Check ((Read-Snapshot $DataRoot) -match 'state=stopped') 'Explicit stop publishes stopped state'

$Command='Restart'; $PollSeconds=120
$launchesBefore=$script:launchCalls
$connectsBefore=$script:connectCalls
Set-QueueRetry $DataRoot ([pscustomobject]@{State='rate_limited';RetryNotBefore=((Get-QueueUnixTime)+1800);Pause=$false})
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore+1 -and $script:lastLaunchInterval -eq 120 -and $script:lastLaunchRoot -eq $DataRoot) 'Restart launches one replacement with requested cadence'
Assert-Check ($script:connectCalls -eq $connectsBefore -and -not $script:lastLaunchQuota) 'Restart does not request authorization or bypass quota'
Assert-Check ((Get-QueueRetry $DataRoot).RetryNotBefore -gt (Get-QueueUnixTime)+1798) 'Restart retains server retry barrier'
Assert-Check ((Read-Snapshot $DataRoot) -match 'state=stopped' -and (Read-Snapshot $DataRoot) -match 'count=0') 'Restart clears previous rows while replacement starts'
Assert-Check ((Test-QueueEnabledIntent $DataRoot) -and -not (Test-QueueStop $DataRoot)) 'Restart explicitly enables future resume'

# Startup is data-only: no token presence, malformed record, or quota flag may
# silently opt in. Neither the browser nor the transport is called by Resume.
$DataRoot=Join-Path $runRoot ('not-created-' + [Guid]::NewGuid().ToString('N')); $Command='Resume'
$storageBefore=$script:storageInitializations; $launchesBefore=$script:launchCalls
Invoke-QueueCommand
Assert-Check (-not [IO.Directory]::Exists($DataRoot) -and $script:storageInitializations -eq $storageBefore -and $script:launchCalls -eq $launchesBefore) 'Unconfigured Resume creates no storage and performs no initialization or launch'
$DataRoot = Fresh-Root; $ClientId=''; $Command='Resume'; $ResumeAfterQuota=$true; $PollSeconds=45
[IO.File]::WriteAllText((Join-Path $DataRoot 'tokens.dpapi'),'SYNTHETIC_ENCRYPTED_FILE_FIXTURE')
Reset-Transport
$launchesBefore=$script:launchCalls; $connectsBefore=$script:connectCalls
$storageBefore=$script:storageInitializations
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore -and -not (Test-Path -LiteralPath (Join-Path $DataRoot 'enabled.intent'))) 'Legacy auth without intent is not automatic consent'
Assert-Check ($script:storageInitializations -eq $storageBefore) 'Existing auth with no intent leaves storage and ACL initialization untouched'
$intentPath=Join-Path $DataRoot 'enabled.intent'
foreach ($invalid in @('',"PARALLAX_AUTOSTART_V1|0`n",'PARALLAX_AUTOSTART_V1|1',"PARALLAX_AUTOSTART_V1|1`r`n","PARALLAX_AUTOSTART_V1|1`nextra",('x'*4096))) {
    [IO.File]::WriteAllText($intentPath,$invalid,[Text.UTF8Encoding]::new($false))
    $beforeBytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($intentPath))
    Invoke-QueueCommand
    Assert-Check ($script:launchCalls -eq $launchesBefore -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($intentPath)) -ceq $beforeBytes) 'Missing, disabled or malformed intent never launches or rewrites'
    Assert-Check ($script:storageInitializations -eq $storageBefore) 'Disabled and invalid Resume never initializes storage'
}
[IO.File]::WriteAllText($intentPath,"PARALLAX_AUTOSTART_V1|1`n",[Text.UTF8Encoding]::new($true))
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore) 'BOM-prefixed intent is not enabled'
Assert-Check ($script:storageInitializations -eq $storageBefore) 'BOM-prefixed intent remains passive'
Set-QueueEnabledIntent $DataRoot $true
Assert-Check ([IO.File]::ReadAllText($intentPath) -ceq "PARALLAX_AUTOSTART_V1|1`n" -and [IO.FileInfo]::new($intentPath).Length -eq 24) 'Enabled intent is exact ASCII with one newline'
$stamp=[IO.File]::GetLastWriteTimeUtc($intentPath)
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore+1 -and $script:lastLaunchInterval -eq 45 -and -not $script:lastLaunchQuota) 'Resume launches saved opt-in with requested cadence but no quota bypass'
Assert-Check ([IO.File]::GetLastWriteTimeUtc($intentPath) -eq $stamp -and $script:tokenCalls -eq 0 -and $script:connectCalls -eq $connectsBefore) 'Resume never rewrites intent, reads tokens or opens consent'
Request-QueueStop $DataRoot
$storageBefore=$script:storageInitializations
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore+1 -and (Test-QueueEnabledIntent $DataRoot) -and (Test-QueueStop $DataRoot)) 'Stop marker veto wins even over an enabled intent'
Assert-Check ($script:storageInitializations -eq $storageBefore) 'Stop-vetoed Resume does not initialize storage'
$Command='Start'; $ResumeAfterQuota=$false
Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore+2 -and -not (Test-QueueStop $DataRoot)) 'Explicit Start clears the stop barrier and enables one launch'
$Command='Stop'; Invoke-QueueCommand
Assert-Check (-not (Test-QueueEnabledIntent $DataRoot) -and [IO.File]::Exists((Join-Path $DataRoot 'tokens.dpapi'))) 'Stop disables resume while preserving saved auth'
Assert-Check ([IO.File]::ReadAllText($intentPath) -ceq "PARALLAX_AUTOSTART_V1|0`n") 'Disabled intent has the exact fixed protocol'
Reset-Transport
Invoke-QueueRun $DataRoot -Single -Silent
$Command='Resume'; Invoke-QueueCommand
Assert-Check ($script:launchCalls -eq $launchesBefore+2 -and $script:apiCalls -eq 0 -and $script:tokenCalls -eq 0 -and (Read-Snapshot $DataRoot) -match 'state=stopped') 'Delayed child and later skin-load Resume cannot resurrect a completed Stop'

# Auto-resume keeps the existing quota and server waits inside the single worker.
$Command='Start'; Invoke-QueueCommand
Set-QueueRetry $DataRoot ([pscustomobject]@{State='quota_exceeded';RetryNotBefore=0L;Pause=$true})
$Command='Resume'; $ResumeAfterQuota=$true; Invoke-QueueCommand
Reset-Transport
Invoke-QueueRun $DataRoot -Single -Silent
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -match 'state=quota_exceeded') 'Resumed worker keeps indefinite quota pause without token renewal'
Set-QueueRetry $DataRoot ([pscustomobject]@{State='rate_limited';RetryNotBefore=((Get-QueueUnixTime)+3600);Pause=$false})
Invoke-QueueCommand
Invoke-QueueRun $DataRoot -Single -Silent
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Get-QueueRetry $DataRoot).RetryNotBefore -gt (Get-QueueUnixTime)+3598) 'Resumed worker retains future Retry-After without token renewal'
$ResumeAfterQuota=$false

# A newer intentional launch fences an older child that has not acquired worker
# ownership yet, including stale cadence and an old explicit quota override.
$DataRoot=Fresh-Root; $Command='Start'; $PollSeconds=30; $ResumeAfterQuota=$true
Invoke-QueueCommand
$oldLaunch=$script:lastLaunchId
Set-QueueRetry $DataRoot ([pscustomobject]@{State='quota_exceeded';RetryNotBefore=0L;Pause=$true})
$Command='Restart'; $PollSeconds=60; $ResumeAfterQuota=$false
Invoke-QueueCommand
$newLaunch=$script:lastLaunchId
Assert-Check ($newLaunch -cne $oldLaunch -and $script:lastLaunchInterval -eq 60 -and -not $script:lastLaunchQuota) 'Restart replaces the pending launch permit and its options'
$snapshotBefore=Read-Snapshot $DataRoot
Reset-Transport @(Reply)
Invoke-QueueRun $DataRoot 30 -Single -Silent -RetryQuota -LaunchId $oldLaunch
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -ceq $snapshotBefore) 'Older cadence/quota child exits before auth, API or snapshot writes'
foreach ($invalidId in @('x',('x'*32),('A'*32),($newLaunch+"`n"),'[!SetVariable Probe escaped]')) {
    Invoke-QueueRun $DataRoot 30 -Single -Silent -RetryQuota -LaunchId $invalidId
    Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -ceq $snapshotBefore) 'Malformed supplied launch id cannot access auth/API or change the snapshot'
}
Invoke-QueueRun $DataRoot 60 -Single -Silent -LaunchId $newLaunch
Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -match 'state=quota_exceeded') 'Newest child retains its no-override quota policy'
[IO.File]::Delete((Join-Path $DataRoot 'launch.id'))
$snapshotBefore=Read-Snapshot $DataRoot
Invoke-QueueRun $DataRoot 60 -Single -Silent -RetryQuota -LaunchId $newLaunch
Assert-Check ($script:tokenCalls -eq 0 -and (Read-Snapshot $DataRoot) -ceq $snapshotBefore) 'A missing launch permit rejects the child without output changes'
foreach ($invalidPermit in @('',($newLaunch+"`r`n"),('x'*32+"`n"),($newLaunch+"`nextra"),('x'*4096))) {
    [IO.File]::WriteAllText((Join-Path $DataRoot 'launch.id'),$invalidPermit,[Text.UTF8Encoding]::new($false))
    Invoke-QueueRun $DataRoot 30 -Single -Silent -RetryQuota -LaunchId $newLaunch
    Assert-Check ($script:tokenCalls -eq 0 -and $script:apiCalls -eq 0 -and (Read-Snapshot $DataRoot) -ceq $snapshotBefore) 'Malformed saved launch permit rejects the child before any work'
}
$Command='Restart'; Invoke-QueueCommand
Set-QueueRetry $DataRoot ([pscustomobject]@{State='rate_limited';RetryNotBefore=1L;Pause=$false})
Reset-Transport @(Reply)
$script:verifyWorkerLocks=$true
Invoke-QueueRun $DataRoot 60 -Single -Silent -LaunchId $script:lastLaunchId
$script:verifyWorkerLocks=$false
Assert-Check ($script:apiCalls -eq 1 -and (Read-Snapshot $DataRoot) -match 'state=ready') 'Latest permitted child can publish after barriers expire'
Reset-Transport

# Inject the old child at the actual Restart publication gap: Stop has been
# cleared and the old permit is still on disk. Its bootstrap must wait for the
# controller to publish the replacement ID, then reject its obsolete permit.
$DataRoot=Fresh-Root; $Command='Start'; $PollSeconds=30; $ResumeAfterQuota=$true
Invoke-QueueCommand
$script:gapOldLaunch=$script:lastLaunchId
$script:gapReady=[Threading.ManualResetEvent]::new($false)
$script:gapChild=$null; $script:gapPending=$null; $script:injectGapChild=$true
$script:productionClearQueueStop=(Get-Command Clear-QueueStop).ScriptBlock
function Clear-QueueStop {
    param([string]$Root)
    & $script:productionClearQueueStop $Root
    if (-not $script:injectGapChild) { return }
    $script:injectGapChild=$false
    Assert-Check (Test-QueueLaunchId $Root $script:gapOldLaunch) 'Injection reaches the real old-permit publication gap'
    $script:gapChild=[PowerShell]::Create()
    $null=$script:gapChild.AddScript(@'
param($provider,$root,$oldId,$ready)
. $provider -Command Help
$script:tokenCalls=0; $script:apiCalls=0
function Get-QueueAccessToken { param($DataRoot,[switch]$ForceRefresh,[switch]$WithControl); $script:tokenCalls++; throw 'Synthetic transport must not run' }
function Invoke-QueueApiRequest { param($AccessToken,$Endpoint); $script:apiCalls++; throw 'Synthetic transport must not run' }
$null=$ready.Set()
Invoke-QueueRun $root 30 -Single -Silent -RetryQuota -LaunchId $oldId
[pscustomobject]@{TokenCalls=$script:tokenCalls;ApiCalls=$script:apiCalls}
'@).AddArgument($provider).AddArgument($Root).AddArgument($script:gapOldLaunch).AddArgument($script:gapReady)
    $script:gapPending=$script:gapChild.BeginInvoke()
    Assert-Check ($script:gapReady.WaitOne(5000)) 'Delayed child reaches bootstrap during the publication gap'
    Assert-Check (-not $script:gapPending.AsyncWaitHandle.WaitOne(100)) 'Controller ownership blocks child bootstrap until publication completes'
}
try {
    $Command='Restart'; $PollSeconds=60; $ResumeAfterQuota=$false
    Invoke-QueueCommand
    Assert-Check ($script:gapPending.AsyncWaitHandle.WaitOne(5000)) 'Delayed child exits after controller releases ownership'
    $childResult=@($script:gapChild.EndInvoke($script:gapPending))
    Assert-Check (-not $script:gapChild.HadErrors -and $childResult.Count -eq 1 -and $childResult[0].TokenCalls -eq 0 -and $childResult[0].ApiCalls -eq 0) 'Publication-gap child performs no token or API work'
    Assert-Check ((Read-Snapshot $DataRoot) -match 'state=stopped' -and $script:lastLaunchInterval -eq 60 -and -not $script:lastLaunchQuota -and -not (Test-QueueLaunchId $DataRoot $script:gapOldLaunch)) 'Publication-gap child cannot overwrite latest Restart state or options'
} finally {
    if ($null -ne $script:gapChild) { $script:gapChild.Stop(); $script:gapChild.Dispose() }
    $script:gapReady.Dispose()
    $script:injectGapChild=$false
}

# A running worker makes repeat load/Start requests idempotent. This runspace
# holds real kernel ownership; the controller must not launch another child.
$entered=[Threading.ManualResetEvent]::new($false); $release=[Threading.ManualResetEvent]::new($false)
$holder=[PowerShell]::Create()
$null=$holder.AddScript('param($name,$entered,$release) $mutex=[Threading.Mutex]::new($false,$name); try { $null=$mutex.WaitOne(); $null=$entered.Set(); $null=$release.WaitOne(15000) } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }').AddArgument((Get-QueueMutexName $DataRoot)).AddArgument($entered).AddArgument($release)
$pending=$holder.BeginInvoke()
try {
    Assert-Check ($entered.WaitOne(5000)) 'Resume mutex holder started'
    $launchesBefore=$script:launchCalls
    $snapshotBefore=Read-Snapshot $DataRoot
    $Command='Resume'; Invoke-QueueCommand; Invoke-QueueCommand
    $Command='Start'; Invoke-QueueCommand
    Assert-Check ($script:launchCalls -eq $launchesBefore -and (Test-QueueEnabledIntent $DataRoot)) 'Repeated Resume and Start do not duplicate a running worker'
    Assert-Check ((Read-Snapshot $DataRoot) -ceq $snapshotBefore -and $script:tokenCalls -eq 0) 'Busy resume leaves current rows and authorization untouched'
    Request-QueueStop $DataRoot
    $permitBefore=[IO.File]::ReadAllText((Join-Path $DataRoot 'launch.id'))
    $Command='Start'; Invoke-QueueCommand
    Assert-Check ((Test-QueueStop $DataRoot) -and $script:launchCalls -eq $launchesBefore -and [IO.File]::ReadAllText((Join-Path $DataRoot 'launch.id')) -ceq $permitBefore) 'Start never clears Stop or changes the permit while a worker is still stopping'
} finally { $null=$release.Set(); $null=$holder.EndInvoke($pending); $holder.Dispose(); $entered.Dispose(); $release.Dispose() }

$report=[ordered]@{assertions=$script:checks;runtime=$PSVersionTable.PSVersion.ToString();provider_sha256=(Get-FileHash $provider -Algorithm SHA256).Hash;synthetic=$true;live_network=$false}
$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'results.json') -Encoding UTF8
Write-Output ('Queue provider: '+$script:checks+' synthetic assertions passed. Evidence: '+$runRoot)
