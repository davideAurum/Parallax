# Windows PowerShell 5.1 / .NET Framework. No account access on import.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:QueueStates = @('onboarding_required','connecting','ready','reauth_required','forbidden','rate_limited','quota_exceeded','offline','service_unavailable','error','stopped')
$script:Utf8 = [Text.UTF8Encoding]::new($false, $true)
# One-snapshot outcome of a row click or refresh, shown in place of "Next N".
$script:QueueNotices = @('','queue_changed','no_device','control_denied','control_failed','control_reauth')
# A saved cover: SHA-1 of its image URL, typed by the response's Content-Type.
# The reader accepts exactly this shape and nothing that could leave the folder.
$script:QueueImageName = '\A[0-9a-f]{40}\.(?:jpg|png)\z'
# Album art is about 5 KB at 64 px; anything near this cap is not a thumbnail.
$script:QueueImageLimit = 262144

function Get-QueueUnixTime { return [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalSeconds) }

function ConvertFrom-QueueJson {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Json)
    if ($script:Utf8.GetByteCount($Json) -gt 1048576) { throw 'Queue response exceeds the size limit.' }
    Add-Type -AssemblyName System.Web.Extensions
    $parser = [Web.Script.Serialization.JavaScriptSerializer]::new()
    $parser.MaxJsonLength = 1048576
    $parser.RecursionLimit = 24
    try { return $parser.DeserializeObject($Json) } catch { throw 'Queue response is not valid bounded JSON.' }
}

function Limit-QueueText {
    param([AllowNull()][object]$Value, [string]$Fallback = '')
    if ($null -eq $Value -or $Value -isnot [string]) { return $Fallback }
    $clean = [regex]::Replace($Value, '[\x00-\x1F\x7F-\x9F]', ' ').Trim()
    if (-not $clean) { return $Fallback }
    try { $bytes = $script:Utf8.GetBytes($clean) } catch { throw 'Queue text contains invalid Unicode.' }
    if ($bytes.Length -le 512) { return $clean }
    for ($length = 512; $length -ge 508; $length--) {
        try { return $script:Utf8.GetString($bytes, 0, $length) } catch {}
    }
    throw 'Queue text could not be bounded.'
}

function Test-QueueImageUrl {
    # Covers come only from Spotify's public image CDN, over HTTPS on the
    # default port. The raw string must spell a bare host (no user info, no
    # port, not even :443) and [Uri] must read the same host, so a URL that
    # parsers disagree about is refused rather than interpreted.
    param([AllowNull()][object]$Url)
    try {
        if ($Url -isnot [string] -or $Url.Length -gt 2048 -or $Url -cnotmatch '\Ahttps://([a-z0-9-]+(?:\.[a-z0-9-]+)+)/[!-~]*\z') { return $false }
        $name = $Matches[1]
        $parsed = $null
        if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$parsed)) { return $false }
        if ($parsed.Scheme -cne 'https' -or $parsed.UserInfo -or -not $parsed.IsDefaultPort -or $parsed.Host -cne $name) { return $false }
        return ($name -ceq 'i.scdn.co' -or $name.EndsWith('.scdn.co', [StringComparison]::Ordinal) -or $name.EndsWith('.spotifycdn.com', [StringComparison]::Ordinal))
    } catch { return $false }
}

function Select-QueueImageUrl {
    # Spotify lists an item's images largest first (640/300/64 px for album
    # art). The smallest at least 48 px wide fills a 32 px row tile even at
    # 150% scaling; when no width says so (missing, or all smaller), the last
    # listed is the smallest. Malformed or off-CDN entries are skipped, and no
    # usable entry means no cover, never a failed queue read.
    param([AllowNull()][object]$Images)
    try {
        if ($Images -isnot [Array]) { return '' }
        $best = ''; $bestWidth = [double]::MaxValue; $last = ''; $seen = 0
        foreach ($image in $Images) {
            $seen++
            if ($seen -gt 10) { break }
            if ($image -isnot [Collections.IDictionary] -or -not $image.ContainsKey('url') -or -not (Test-QueueImageUrl $image['url'])) { continue }
            $last = $image['url']
            $width = if ($image.ContainsKey('width')) { $image['width'] } else { $null }
            if ($width -is [int] -or $width -is [long] -or $width -is [decimal] -or $width -is [double]) {
                if ([double]$width -ge 48 -and [double]$width -lt $bestWidth) { $best = $last; $bestWidth = [double]$width }
            }
        }
        if ($best) { return $best }
        return $last
    } catch { return '' }
}

function Get-QueueImageKey {
    # The cover's file name stem: lowercase SHA-1 of the URL's UTF-8 bytes.
    # Spotify's image URLs are content-addressed, so one URL is one picture.
    param([Parameter(Mandatory)][string]$Url)
    $hash = [Security.Cryptography.SHA1]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($script:Utf8.GetBytes($Url))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Get-QueueImageExtension {
    # The file type comes from the response's Content-Type, and the body must
    # start with that format's signature, so a mislabelled body (an HTML error
    # page, say) is refused instead of saved as a picture. '' means refused.
    param([AllowNull()][string]$ContentType, [AllowNull()][byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -lt 8 -or $Bytes.Length -gt $script:QueueImageLimit -or -not $ContentType) { return '' }
    $type = $ContentType.Split(';')[0].Trim().ToLowerInvariant()
    if ($type -ceq 'image/jpeg' -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8 -and $Bytes[2] -eq 0xFF) { return 'jpg' }
    $png = [byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A)
    if ($type -ceq 'image/png') {
        for ($index = 0; $index -lt 8; $index++) { if ($Bytes[$index] -ne $png[$index]) { return '' } }
        return 'png'
    }
    return ''
}

function ConvertTo-QueueItem {
    # One track or episode as display text and its cover's URL; anything else,
    # or a nameless item, throws. ImageUrl is where the cover comes from; Image
    # is the saved file's name, filled in by the helper's download step (empty:
    # no cover).
    param([AllowNull()][object]$Entry)
    if ($Entry -isnot [Collections.IDictionary] -or -not $Entry.ContainsKey('type')) { throw 'Queue contains an unsupported item.' }
    if ($Entry['type'] -notin @('track','episode')) { throw 'Queue contains an unsupported item type.' }
    if (-not $Entry.ContainsKey('name') -or $Entry['name'] -isnot [string]) { throw 'Queue contains an invalid item name.' }
    $title = Limit-QueueText $Entry['name'] ('Untitled ' + $Entry['type'])
    $detail = ''
    # Tracks show their album's art; episodes their own, else their show's.
    $imageUrl = ''
    if ($Entry['type'] -eq 'track') {
        if ($Entry.ContainsKey('album') -and $Entry['album'] -is [Collections.IDictionary] -and $Entry['album'].ContainsKey('images')) {
            $imageUrl = Select-QueueImageUrl $Entry['album']['images']
        }
        $artists = [Collections.Generic.List[string]]::new()
        if ($Entry.ContainsKey('artists') -and $Entry['artists'] -is [Array]) {
            foreach ($artist in $Entry['artists']) {
                if ($artists.Count -ge 10) { break }
                if ($artist -is [Collections.IDictionary] -and $artist.ContainsKey('name')) {
                    $name = Limit-QueueText $artist['name']
                    if ($name) { $artists.Add($name) }
                }
            }
        }
        $detail = Limit-QueueText ($artists -join ', ') 'Artist unavailable'
    } else {
        if ($Entry.ContainsKey('show') -and $Entry['show'] -is [Collections.IDictionary] -and $Entry['show'].ContainsKey('name')) {
            $detail = Limit-QueueText $Entry['show']['name']
        }
        if (-not $detail) { $detail = 'Podcast episode' }
        if ($Entry.ContainsKey('images')) { $imageUrl = Select-QueueImageUrl $Entry['images'] }
        if (-not $imageUrl -and $Entry.ContainsKey('show') -and $Entry['show'] -is [Collections.IDictionary] -and $Entry['show'].ContainsKey('images')) {
            $imageUrl = Select-QueueImageUrl $Entry['show']['images']
        }
    }
    return [pscustomobject]@{ Title = $title; Detail = $detail; ImageUrl = $imageUrl; Image = '' }
}

function ConvertTo-QueueItems {
    param([Parameter(Mandatory)][object]$Payload)
    if ($Payload -isnot [Collections.IDictionary] -or -not $Payload.ContainsKey('queue') -or -not $Payload.ContainsKey('currently_playing')) { throw 'Queue response schema is unavailable.' }
    if ($Payload['queue'] -isnot [Array]) { throw 'Queue response is missing its item list.' }
    if ($null -ne $Payload['currently_playing'] -and $Payload['currently_playing'] -isnot [Collections.IDictionary]) { throw 'Queue current-item schema is invalid.' }
    $items = [Collections.Generic.List[object]]::new()
    foreach ($entry in $Payload['queue']) {
        if ($items.Count -ge 5) { break }
        $items.Add((ConvertTo-QueueItem $entry))
    }
    # The track these rows come after, so the reader can tell when the player
    # has moved on. One it cannot read is left unnamed, never a failed read.
    $current = $null
    if ($null -ne $Payload['currently_playing']) { try { $current = ConvertTo-QueueItem $Payload['currently_playing'] } catch {} }
    # A wrapper preserves a zero/one item array through PowerShell's pipeline.
    return [pscustomobject]@{ Items = $items.ToArray(); Current = $current }
}

function New-QueueSnapshot {
    param([Parameter(Mandatory)][string]$State, [object[]]$Items = @(), [long]$Now = (Get-QueueUnixTime), [ValidateRange(1,300)][int]$LifetimeSeconds = 90, [long]$RetryNotBefore = 0,
        [bool]$Control = $false, [AllowEmptyString()][string]$Notice = '', [AllowNull()][object]$Current = $null)
    if ($State -notin $script:QueueStates) { throw 'Invalid queue state.' }
    if ($Now -lt 1 -or $Now -gt 253402300000 -or $RetryNotBefore -lt 0 -or $RetryNotBefore -gt 253402300000) { throw 'Invalid queue timestamp.' }
    if ($Items.Count -gt 5 -or ($State -ne 'ready' -and ($Items.Count -ne 0 -or $null -ne $Current))) { throw 'Invalid items for queue state.' }
    # Rows are clickable, and a click outcome is shown, only beside live rows.
    if ($Notice -cnotin $script:QueueNotices -or ($State -ne 'ready' -and ($Control -or $Notice))) { throw 'Invalid queue control for state.' }
    $observed = 0L; $expires = 0L
    if ($State -eq 'ready') { $observed = $Now; $expires = $Now + $LifetimeSeconds }
    return [pscustomobject]@{ State=$State; Observed=$observed; ValidUntil=$expires; RetryNotBefore=$RetryNotBefore; Items=@($Items); Control=$Control; Notice=$Notice; Current=$Current }
}

function ConvertTo-QueueSnapshotText {
    param([Parameter(Mandatory)][object]$Snapshot)
    if ($Snapshot.State -notin $script:QueueStates -or $Snapshot.Items.Count -gt 5) { throw 'Invalid snapshot.' }
    if ($Snapshot.State -ne 'ready' -and ($Snapshot.Items.Count -ne 0 -or $Snapshot.Observed -ne 0 -or $Snapshot.ValidUntil -ne 0)) { throw 'Nonready snapshot contains live data.' }
    if ($Snapshot.State -eq 'ready' -and ($Snapshot.Observed -le 0 -or $Snapshot.ValidUntil -le $Snapshot.Observed -or $Snapshot.ValidUntil -gt $Snapshot.Observed+300)) { throw 'Invalid snapshot lifetime.' }
    $control = [bool]($Snapshot.PSObject.Properties['Control'] -and $Snapshot.Control)
    $notice = if ($Snapshot.PSObject.Properties['Notice']) { [string]$Snapshot.Notice } else { '' }
    if ($notice -cnotin $script:QueueNotices -or ($Snapshot.State -ne 'ready' -and ($control -or $notice))) { throw 'Invalid snapshot control.' }
    $currentTitle = ''; $currentDetail = ''
    if ($Snapshot.PSObject.Properties['Current'] -and $null -ne $Snapshot.Current) {
        if ($Snapshot.State -ne 'ready') { throw 'Nonready snapshot contains live data.' }
        $currentTitle = Limit-QueueText $Snapshot.Current.Title
        $currentDetail = Limit-QueueText $Snapshot.Current.Detail
        if (-not $currentTitle) { throw 'Current queue item has no display title.' }
    }
    $lines = [Collections.Generic.List[string]]::new()
    # V3 adds control (rows may be clicked) and notice (a click's outcome).
    # V4 appends image1..image5 after the rows: each a saved cover's bare file
    # name, or empty for none, for unused rows and in every nonready state.
    # V5 appends the track the rows come after; both lines are empty when
    # Spotify names none, and in every nonready state.
    $lines.Add('PARALLAX_QUEUE_V5')
    $lines.Add('state=' + $Snapshot.State)
    $lines.Add('observed=' + [long]$Snapshot.Observed)
    $lines.Add('valid_until=' + [long]$Snapshot.ValidUntil)
    $lines.Add('retry_not_before=' + [long]$Snapshot.RetryNotBefore)
    $lines.Add('count=' + $Snapshot.Items.Count)
    $lines.Add('control=' + [int]$control)
    $lines.Add('notice=' + $notice)
    $images = [Collections.Generic.List[string]]::new()
    for ($index = 1; $index -le 5; $index++) {
        $title = ''; $detail = ''; $image = ''
        if ($index -le $Snapshot.Items.Count) {
            $item = $Snapshot.Items[$index-1]
            $title = Limit-QueueText $item.Title
            $detail = Limit-QueueText $item.Detail
            if (-not $title) { throw 'Ready queue item has no display title.' }
            if ($item.PSObject.Properties['Image'] -and $item.Image) { $image = [string]$item.Image }
            if ($image -and $image -cnotmatch $script:QueueImageName) { throw 'Queue cover name is invalid.' }
        }
        $lines.Add('title' + $index + '=' + [BitConverter]::ToString($script:Utf8.GetBytes($title)).Replace('-', ''))
        $lines.Add('detail' + $index + '=' + [BitConverter]::ToString($script:Utf8.GetBytes($detail)).Replace('-', ''))
        $images.Add('image' + $index + '=' + $image)
    }
    $lines.AddRange($images)
    $lines.Add('current_title=' + [BitConverter]::ToString($script:Utf8.GetBytes($currentTitle)).Replace('-', ''))
    $lines.Add('current_detail=' + [BitConverter]::ToString($script:Utf8.GetBytes($currentDetail)).Replace('-', ''))
    return ($lines -join "`n") + "`n"
}

function Write-QueueAtomicFile {
    param([Parameter(Mandatory)][string]$DataRoot, [Parameter(Mandatory)][ValidateSet('queue.snapshot','queue.retry.json')][string]$Name, [Parameter(Mandatory)][string]$Text)
    # Runtime directory ACL/ancestor validation is performed by QueueAuth first.
    $root = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
    if (-not [IO.Directory]::Exists($root) -or (([IO.File]::GetAttributes($root)) -band [IO.FileAttributes]::ReparsePoint)) { throw 'Queue storage is unavailable.' }
    $target = Join-Path $root $Name
    if ([IO.File]::Exists($target) -and (([IO.File]::GetAttributes($target)) -band [IO.FileAttributes]::ReparsePoint)) { throw 'Queue storage is not a regular file.' }
    $temporary = Join-Path $root ('.queue-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, $Text, $script:Utf8)
        if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary, $target, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $target) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Publish-QueueSnapshot {
    param([Parameter(Mandatory)][string]$DataRoot, [Parameter(Mandatory)][object]$Snapshot)
    Write-QueueAtomicFile -DataRoot $DataRoot -Name 'queue.snapshot' -Text (ConvertTo-QueueSnapshotText $Snapshot)
}

function Write-QueueCoverFile {
    # A cover appears under its final name only once complete: the bytes go to
    # a temporary file in the same folder (a name the reader never accepts),
    # then move into place. The folder's private ACL is the helper's to set up.
    param([Parameter(Mandatory)][string]$CoverRoot, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][byte[]]$Bytes)
    if ($Name -cnotmatch $script:QueueImageName -or $Bytes.Length -lt 1 -or $Bytes.Length -gt $script:QueueImageLimit) { throw 'Queue cover is invalid.' }
    $root = [IO.Path]::GetFullPath($CoverRoot).TrimEnd('\')
    if (-not [IO.Directory]::Exists($root) -or (([IO.File]::GetAttributes($root)) -band [IO.FileAttributes]::ReparsePoint)) { throw 'Queue cover storage is unavailable.' }
    $target = Join-Path $root $Name
    if ([IO.Directory]::Exists($target) -or ([IO.File]::Exists($target) -and (([IO.File]::GetAttributes($target)) -band [IO.FileAttributes]::ReparsePoint))) { throw 'Queue cover is not a regular file.' }
    $temporary = Join-Path $root ('.cover-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary, $target, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $target) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Get-QueueResponseDecision {
    param([int]$StatusCode, [AllowNull()][string]$Body, [AllowNull()][string]$RetryAfter, [long]$Now = (Get-QueueUnixTime), [ValidateRange(0,10)][int]$FailureCount = 0)
    if ($StatusCode -eq 200) { return [pscustomobject]@{ State='response_requires_validation'; RetryNotBefore=0L; Pause=$false } }
    if ($StatusCode -eq 401) { return [pscustomobject]@{ State='reauth_required'; RetryNotBefore=0L; Pause=$true } }
    if ($StatusCode -eq 403) { return [pscustomobject]@{ State='forbidden'; RetryNotBefore=0L; Pause=$true } }
    $delay = [long][Math]::Min(300, 30 * [Math]::Pow(2, $FailureCount))
    $state = 'error'
    if ($StatusCode -eq 429) {
        $state = 'rate_limited'
        try {
            $parsed = ConvertFrom-QueueJson $Body
            if ($parsed -is [Collections.IDictionary] -and $parsed.ContainsKey('error') -and $parsed['error'] -is [Collections.IDictionary] -and $parsed['error'].ContainsKey('reason') -and $parsed['error']['reason'] -eq 'QUOTA_EXCEEDED') {
                return [pscustomobject]@{ State='quota_exceeded'; RetryNotBefore=0L; Pause=$true }
            }
        } catch {}
        if ($RetryAfter -match '^[0-9]{1,12}$') {
            # Retain a long server wait. Never shorten it to our ordinary backoff.
            $delay = [Math]::Max(1L, [long]$RetryAfter)
        } else {
            $when = [DateTimeOffset]::MinValue
            if ([DateTimeOffset]::TryParse($RetryAfter, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$when)) {
                $seconds = [long][Math]::Ceiling(($when.UtcDateTime - [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalSeconds) - $Now
                $delay = [Math]::Max(1L, $seconds)
            }
        }
    } elseif ($StatusCode -eq 0) { $state = 'offline' }
    elseif ($StatusCode -ge 500 -and $StatusCode -le 599) { $state = 'service_unavailable' }
    if ($delay -gt 253402300000 - $Now) { return [pscustomobject]@{ State=$state; RetryNotBefore=253402300000L; Pause=$false } }
    return [pscustomobject]@{ State=$state; RetryNotBefore=($Now+$delay); Pause=$false }
}

function Invoke-QueueApiRequest {
    # Queue reads the queue (GET); Next skips one item (POST, empty body). No
    # other endpoint or method is reachable from here.
    param([Parameter(Mandatory)][string]$AccessToken, [ValidateSet('Queue','Next')][string]$Endpoint = 'Queue')
    if (-not $AccessToken -or $AccessToken -match '[\r\n]') { throw 'Access token is unavailable.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uri = if ($Endpoint -eq 'Next') { 'https://api.spotify.com/v1/me/player/next' } else { 'https://api.spotify.com/v1/me/player/queue' }
    $request = [Net.HttpWebRequest]::Create($uri)
    $request.Method = if ($Endpoint -eq 'Next') { 'POST' } else { 'GET' }
    if ($Endpoint -eq 'Next') { $request.ContentLength = 0 }
    $request.Accept = 'application/json'
    $request.Headers['Authorization'] = 'Bearer ' + $AccessToken
    $request.AllowAutoRedirect = $false
    $request.Timeout = 15000
    $request.ReadWriteTimeout = 15000
    $request.MaximumResponseHeadersLength = 32
    $response = $null
    try {
        try { $response = $request.GetResponse() }
        catch [Net.WebException] {
            if ($null -eq $_.Exception.Response) { return [pscustomobject]@{ StatusCode=0; Body=''; RetryAfter='' } }
            $response = $_.Exception.Response
        }
        $stream = $response.GetResponseStream()
        $buffer = New-Object byte[] 8192
        $memory = [IO.MemoryStream]::new()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        try {
            while ($true) {
                if ($clock.ElapsedMilliseconds -ge 15000) { return [pscustomobject]@{ StatusCode=0; Body=''; RetryAfter='' } }
                if ($stream.CanTimeout) { $stream.ReadTimeout = [Math]::Max(1,15000-[int]$clock.ElapsedMilliseconds) }
                $read = $stream.Read($buffer,0,$buffer.Length)
                if ($read -le 0) { break }
                if ($memory.Length + $read -gt 1048576) { return [pscustomobject]@{ StatusCode=204; Body=''; RetryAfter='' } }
                $memory.Write($buffer,0,$read)
            }
            try { $body = $script:Utf8.GetString($memory.ToArray()) }
            catch { return [pscustomobject]@{ StatusCode=204; Body=''; RetryAfter='' } }
        } finally { $stream.Dispose(); $memory.Dispose() }
        return [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$body; RetryAfter=[string]$response.Headers['Retry-After'] }
    } catch { return [pscustomobject]@{ StatusCode=0; Body=''; RetryAfter='' } }
    finally { if ($null -ne $response) { $response.Dispose() } }
}

function Read-QueueBoundedStream {
    # Reads a whole body, or gives up: $null once it passes Limit bytes (an
    # oversized body is abandoned, never truncated into a broken file), and a
    # throw once Milliseconds have passed, which callers treat as no response.
    param([Parameter(Mandatory)][IO.Stream]$Stream, [ValidateRange(1,1048576)][int]$Limit, [ValidateRange(1,60000)][int]$Milliseconds)
    $buffer = New-Object byte[] 8192
    $memory = [IO.MemoryStream]::new()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($true) {
            $left = $Milliseconds - [int]$clock.ElapsedMilliseconds
            if ($left -le 0) { throw 'Queue response read timed out.' }
            if ($Stream.CanTimeout) { $Stream.ReadTimeout = $left }
            $read = $Stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            if ($memory.Length + $read -gt $Limit) { return $null }
            $memory.Write($buffer, 0, $read)
        }
        # The comma keeps PowerShell from unrolling the bytes into the pipeline.
        return ,$memory.ToArray()
    } finally { $memory.Dispose() }
}

function Invoke-QueueImageRequest {
    # GETs one cover from Spotify's public image CDN. It takes no token and
    # sends no Authorization header, cookie or credential: the CDN needs none,
    # and the Spotify token never leaves api.spotify.com. Redirects are not
    # followed, so only the allowlisted host is contacted. 5 s in total, at
    # most 256 KB. StatusCode 0 means no usable response arrived (network
    # failure or timeout); Bytes is $null unless a whole 200 body was read.
    param([Parameter(Mandatory)][string]$Uri)
    $none = [pscustomobject]@{ StatusCode=0; ContentType=''; Bytes=$null }
    if (-not (Test-QueueImageUrl $Uri)) { return $none }
    $response = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $request = [Net.HttpWebRequest]::Create($Uri)
        $request.Method = 'GET'
        $request.Accept = 'image/jpeg, image/png'
        $request.AllowAutoRedirect = $false
        $request.UseDefaultCredentials = $false
        $request.Credentials = $null
        $request.PreAuthenticate = $false
        $request.Timeout = 5000
        $request.ReadWriteTimeout = 5000
        $request.MaximumResponseHeadersLength = 32
        # With redirects off, a 3xx arrives here as an ordinary response and
        # 4xx/5xx as a WebException carrying one; only 200 is a cover.
        try { $response = $request.GetResponse() }
        catch [Net.WebException] {
            if ($null -eq $_.Exception.Response) { return $none }
            $response = $_.Exception.Response
        }
        $status = [int]$response.StatusCode
        $type = [string]$response.ContentType
        if ($status -ne 200 -or $response.ContentLength -gt $script:QueueImageLimit) { return [pscustomobject]@{ StatusCode=$status; ContentType=$type; Bytes=$null } }
        $left = 5000 - [int]$clock.ElapsedMilliseconds
        if ($left -le 0) { return $none }
        $stream = $response.GetResponseStream()
        try { $bytes = Read-QueueBoundedStream -Stream $stream -Limit $script:QueueImageLimit -Milliseconds $left }
        finally { $stream.Dispose() }
        return [pscustomobject]@{ StatusCode=$status; ContentType=$type; Bytes=$bytes }
    } catch { return $none }
    finally { if ($null -ne $response) { $response.Dispose() } }
}

function Get-QueueControlDecision {
    # A click's skip response: 2xx continues; anything else ends the action
    # with the notice shown beside the refreshed rows. A 429 is only a failed
    # click here: the regular queue read that follows records any server wait.
    param([int]$StatusCode)
    if ($StatusCode -ge 200 -and $StatusCode -le 299) { return '' }
    if ($StatusCode -eq 401) { return 'control_reauth' }
    if ($StatusCode -eq 403) { return 'control_denied' }
    if ($StatusCode -eq 404) { return 'no_device' }
    return 'control_failed'
}

Export-ModuleMember -Function Get-QueueControlDecision,Get-QueueUnixTime,ConvertFrom-QueueJson,Limit-QueueText,ConvertTo-QueueItems,New-QueueSnapshot,ConvertTo-QueueSnapshotText,Write-QueueAtomicFile,Publish-QueueSnapshot,Get-QueueResponseDecision,Invoke-QueueApiRequest,
    Test-QueueImageUrl,Select-QueueImageUrl,Get-QueueImageKey,Get-QueueImageExtension,Write-QueueCoverFile,Read-QueueBoundedStream,Invoke-QueueImageRequest
