# Windows PowerShell 5.1 / .NET Framework. No account access on import.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:QueueStates = @('onboarding_required','connecting','ready','reauth_required','forbidden','rate_limited','quota_exceeded','offline','service_unavailable','error','stopped')
$script:Utf8 = [Text.UTF8Encoding]::new($false, $true)

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

function ConvertTo-QueueItems {
    param([Parameter(Mandatory)][object]$Payload)
    if ($Payload -isnot [Collections.IDictionary] -or -not $Payload.ContainsKey('queue') -or -not $Payload.ContainsKey('currently_playing')) { throw 'Queue response schema is unavailable.' }
    if ($Payload['queue'] -isnot [Array]) { throw 'Queue response is missing its item list.' }
    if ($null -ne $Payload['currently_playing'] -and $Payload['currently_playing'] -isnot [Collections.IDictionary]) { throw 'Queue current-item schema is invalid.' }
    $items = [Collections.Generic.List[object]]::new()
    foreach ($entry in $Payload['queue']) {
        if ($items.Count -ge 5) { break }
        if ($entry -isnot [Collections.IDictionary] -or -not $entry.ContainsKey('type')) { throw 'Queue contains an unsupported item.' }
        if ($entry['type'] -notin @('track','episode')) { throw 'Queue contains an unsupported item type.' }
        if (-not $entry.ContainsKey('name') -or $entry['name'] -isnot [string]) { throw 'Queue contains an invalid item name.' }
        $title = Limit-QueueText $entry['name'] ('Untitled ' + $entry['type'])
        $detail = ''
        if ($entry['type'] -eq 'track') {
            $artists = [Collections.Generic.List[string]]::new()
            if ($entry.ContainsKey('artists') -and $entry['artists'] -is [Array]) {
                foreach ($artist in $entry['artists']) {
                    if ($artists.Count -ge 10) { break }
                    if ($artist -is [Collections.IDictionary] -and $artist.ContainsKey('name')) {
                        $name = Limit-QueueText $artist['name']
                        if ($name) { $artists.Add($name) }
                    }
                }
            }
            $detail = Limit-QueueText ($artists -join ', ') 'Artist unavailable'
        } else {
            if ($entry.ContainsKey('show') -and $entry['show'] -is [Collections.IDictionary] -and $entry['show'].ContainsKey('name')) {
                $detail = Limit-QueueText $entry['show']['name']
            }
            if (-not $detail) { $detail = 'Podcast episode' }
        }
        $items.Add([pscustomobject]@{ Title = $title; Detail = $detail })
    }
    # A wrapper preserves a zero/one item array through PowerShell's pipeline.
    return [pscustomobject]@{ Items = $items.ToArray() }
}

function New-QueueSnapshot {
    param([Parameter(Mandatory)][string]$State, [object[]]$Items = @(), [long]$Now = (Get-QueueUnixTime), [ValidateRange(1,300)][int]$LifetimeSeconds = 90, [long]$RetryNotBefore = 0)
    if ($State -notin $script:QueueStates) { throw 'Invalid queue state.' }
    if ($Now -lt 1 -or $Now -gt 253402300000 -or $RetryNotBefore -lt 0 -or $RetryNotBefore -gt 253402300000) { throw 'Invalid queue timestamp.' }
    if ($Items.Count -gt 5 -or ($State -ne 'ready' -and $Items.Count -ne 0)) { throw 'Invalid items for queue state.' }
    $observed = 0L; $expires = 0L
    if ($State -eq 'ready') { $observed = $Now; $expires = $Now + $LifetimeSeconds }
    return [pscustomobject]@{ State=$State; Observed=$observed; ValidUntil=$expires; RetryNotBefore=$RetryNotBefore; Items=@($Items) }
}

function ConvertTo-QueueSnapshotText {
    param([Parameter(Mandatory)][object]$Snapshot)
    if ($Snapshot.State -notin $script:QueueStates -or $Snapshot.Items.Count -gt 5) { throw 'Invalid snapshot.' }
    if ($Snapshot.State -ne 'ready' -and ($Snapshot.Items.Count -ne 0 -or $Snapshot.Observed -ne 0 -or $Snapshot.ValidUntil -ne 0)) { throw 'Nonready snapshot contains live data.' }
    if ($Snapshot.State -eq 'ready' -and ($Snapshot.Observed -le 0 -or $Snapshot.ValidUntil -le $Snapshot.Observed -or $Snapshot.ValidUntil -gt $Snapshot.Observed+300)) { throw 'Invalid snapshot lifetime.' }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('PARALLAX_QUEUE_V2')
    $lines.Add('state=' + $Snapshot.State)
    $lines.Add('observed=' + [long]$Snapshot.Observed)
    $lines.Add('valid_until=' + [long]$Snapshot.ValidUntil)
    $lines.Add('retry_not_before=' + [long]$Snapshot.RetryNotBefore)
    $lines.Add('count=' + $Snapshot.Items.Count)
    for ($index = 1; $index -le 5; $index++) {
        $title = ''; $detail = ''
        if ($index -le $Snapshot.Items.Count) {
            $title = Limit-QueueText $Snapshot.Items[$index-1].Title
            $detail = Limit-QueueText $Snapshot.Items[$index-1].Detail
            if (-not $title) { throw 'Ready queue item has no display title.' }
        }
        $lines.Add('title' + $index + '=' + [BitConverter]::ToString($script:Utf8.GetBytes($title)).Replace('-', ''))
        $lines.Add('detail' + $index + '=' + [BitConverter]::ToString($script:Utf8.GetBytes($detail)).Replace('-', ''))
    }
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
    param([Parameter(Mandatory)][string]$AccessToken)
    if (-not $AccessToken -or $AccessToken -match '[\r\n]') { throw 'Access token is unavailable.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $request = [Net.HttpWebRequest]::Create('https://api.spotify.com/v1/me/player/queue')
    $request.Method = 'GET'
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

Export-ModuleMember -Function Get-QueueUnixTime,ConvertFrom-QueueJson,Limit-QueueText,ConvertTo-QueueItems,New-QueueSnapshot,ConvertTo-QueueSnapshotText,Write-QueueAtomicFile,Publish-QueueSnapshot,Get-QueueResponseDecision,Invoke-QueueApiRequest
