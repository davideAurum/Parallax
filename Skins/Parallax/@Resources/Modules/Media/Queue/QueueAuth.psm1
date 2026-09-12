#requires -Version 5.1
#requires -PSEdition Desktop
# Windows PowerShell 5.1 / .NET Framework only. Importing performs no auth or I/O.
# The CLI must invoke Connect-QueueSpotify only after the user's explicit connect action.
# Spotify: /documentation/web-api/tutorials/{code-pkce-flow,refreshing-tokens}
# Redirect registration: http://127.0.0.1/callback (dynamic loopback port exception).
Set-StrictMode -Version 2.0
$script:QueueScope = 'user-read-currently-playing'
$script:TokenTransport = $null # Internal injection point; never set from user configuration.

function Stop-QueueAuth {
    param([string]$State = 'error', [Nullable[long]]$RetryAfterSeconds)
    $messages = @{
        onboarding_required = 'Configure a Spotify client ID before connecting.'
        reauth_required = 'Spotify authorization is missing or expired. Connect again.'
        auth_busy = 'Another Spotify authorization operation is in progress.'
        auth_timeout = 'Spotify authorization timed out. Connect again when ready.'
        authorization_denied = 'Spotify authorization was not granted.'
        invalid_callback = 'The authorization callback was rejected.'
        offline = 'Spotify authorization service could not be reached.'
        rate_limited = 'Spotify authorization is temporarily rate limited.'
        quota_exceeded = 'Spotify authorization quota is exhausted.'
        forbidden = 'Spotify denied access for this app or account.'
        storage_error = 'Spotify private storage is unavailable or invalid.'
        error = 'Spotify authorization could not be completed.'
    }
    if (-not $messages.ContainsKey($State)) { $State = 'error' }
    $failure = [InvalidOperationException]::new($messages[$State])
    $failure.Data['QueueState'] = $State
    if ($null -ne $RetryAfterSeconds) { $failure.Data['RetryAfterSeconds'] = [long]$RetryAfterSeconds }
    throw $failure
}

function Get-QueueDataRoot {
    # This only resolves the standard path. It does not create/read storage.
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Parallax\Media\Spotify'
}

function Get-QueuePathAttributes {
    param([string]$Path)
    try { return [IO.File]::GetAttributes($Path) }
    catch [IO.FileNotFoundException] { return $null }
    catch [IO.DirectoryNotFoundException] { return $null }
    catch { Stop-QueueAuth storage_error }
}

function Resolve-QueuePrivatePath {
    param([Parameter(Mandatory = $true)][string]$DataRoot)
    try {
        if ($DataRoot -notmatch '^[A-Za-z]:[\\/]' -or $DataRoot -match '[\x00-\x1f]' -or $DataRoot.Substring(2).Contains(':')) { Stop-QueueAuth storage_error }
        $full = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
        if ($full.Length -lt 6 -or $full -match '(?i)[\\/]Skins(?:[\\/]|$)') { Stop-QueueAuth storage_error }
        # Refuse common profile roots: ACL updates belong to a dedicated provider directory.
        foreach ($special in @('UserProfile', 'LocalApplicationData', 'ApplicationData', 'MyDocuments', 'Desktop')) {
            $protected = [Environment]::GetFolderPath($special).TrimEnd('\')
            if ($protected -and [string]::Equals($full, $protected, [StringComparison]::OrdinalIgnoreCase)) { Stop-QueueAuth storage_error }
        }
        $cursor = $full
        while ($cursor) {
            $attributes = Get-QueuePathAttributes $cursor
            if ($null -ne $attributes) {
                if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-QueueAuth storage_error }
            }
            $parent = [IO.Directory]::GetParent($cursor)
            if ($null -eq $parent) { break }
            $cursor = $parent.FullName
        }
        if ([IO.File]::Exists($full)) { Stop-QueueAuth storage_error }
        return $full
    } catch { Stop-QueueAuth storage_error }
}

function New-QueueDirectorySecurity {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', $inherit, 'None', 'Allow')
    $acl.AddAccessRule($rule)
    return $acl
}

function Initialize-QueuePrivateDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot)
    try {
        $root = Resolve-QueuePrivatePath $DataRoot
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
        if ([IO.Directory]::Exists($root)) {
            $old = [IO.Directory]::GetAccessControl($root)
            if ($old.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne $sid.Value) { Stop-QueueAuth storage_error }
            $rules = @($old.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
            $expectedInheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
            $alreadyPrivate = $old.AreAccessRulesProtected -and $rules.Count -eq 1 -and
                $rules[0].IdentityReference.Value -ceq $sid.Value -and $rules[0].AccessControlType -eq 'Allow' -and
                $rules[0].FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl -and
                $rules[0].InheritanceFlags -eq $expectedInheritance -and $rules[0].PropagationFlags -eq 'None'
            # Repeated token reads should not rewrite an already-private DACL.
            if (-not $alreadyPrivate) { [IO.Directory]::SetAccessControl($root, (New-QueueDirectorySecurity)) }
        } else {
            $null = [IO.Directory]::CreateDirectory($root, (New-QueueDirectorySecurity))
        }
        $null = Resolve-QueuePrivatePath $root
        $acl = [IO.Directory]::GetAccessControl($root)
        if (-not $acl.AreAccessRulesProtected) { Stop-QueueAuth storage_error }
        foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
            if ($rule.IdentityReference.Value -cne $sid.Value -or $rule.AccessControlType -ne 'Allow') { Stop-QueueAuth storage_error }
        }
        return $root
    } catch { Stop-QueueAuth storage_error }
}

function Assert-QueuePrivateFile {
    param([string]$Path)
    $attributes = Get-QueuePathAttributes $Path
    if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-QueueAuth storage_error }
    if (-not [IO.File]::Exists($Path)) {
        if ([IO.Directory]::Exists($Path)) { Stop-QueueAuth storage_error }
        return
    }
    try {
        if (([IO.File]::GetAttributes($Path) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-QueueAuth storage_error }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl = [IO.File]::GetAccessControl($Path)
        if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne $sid.Value) { Stop-QueueAuth storage_error }
        # Existing private files cannot silently retain broad explicit permissions.
        foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
            if ($rule.IdentityReference.Value -cne $sid.Value -or $rule.AccessControlType -ne 'Allow') { Stop-QueueAuth storage_error }
        }
    } catch { Stop-QueueAuth storage_error }
}

function Write-QueuePrivateBytes {
    param([string]$DataRoot, [string]$Name, [byte[]]$Bytes)
    if ($Name -cnotin @('client.json', 'tokens.dpapi')) { Stop-QueueAuth storage_error }
    $root = Initialize-QueuePrivateDirectory $DataRoot
    $path = Join-Path $root $Name
    $temp = Join-Path $root ('auth-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $stream = $null
    try {
        Assert-QueuePrivateFile $path
        $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        Assert-QueuePrivateFile $temp
        # PowerShell 5.1 converts $null to an empty string for this overload.
        # NullString supplies a real null backup path, so no plaintext/old backup is kept.
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp, $path, [Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $path) }
        Assert-QueuePrivateFile $path
    } catch { Stop-QueueAuth storage_error }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

function Enter-QueueAuthLock {
    param([string]$DataRoot)
    $root = Initialize-QueuePrivateDirectory $DataRoot
    $path = Join-Path $root 'auth.lock'
    Assert-QueuePrivateFile $path
    try { return [IO.FileStream]::new($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { Stop-QueueAuth auth_busy }
}

function Get-QueueClientId {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot)
    try {
        $root = Resolve-QueuePrivatePath $DataRoot
        $path = Join-Path $root 'client.json'
        Assert-QueuePrivateFile $path
        if (-not [IO.File]::Exists($path)) { return $null }
        if ([IO.FileInfo]::new($path).Length -gt 2048) { Stop-QueueAuth storage_error }
        $config = [IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop
        if ($config.schema_version -ne 1 -or $config.client_id -isnot [string] -or $config.client_id -cnotmatch '\A[0-9a-fA-F]{32}\z') { Stop-QueueAuth storage_error }
        return $config.client_id.ToLowerInvariant()
    } catch { Stop-QueueAuth storage_error }
}

function Set-QueueClientId {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot, [Parameter(Mandatory = $true)][string]$ClientId)
    if ($ClientId -cnotmatch '\A[0-9a-fA-F]{32}\z') { Stop-QueueAuth onboarding_required }
    $lock = Enter-QueueAuthLock $DataRoot
    try {
        $existing = Get-QueueClientId $DataRoot
        if ($existing -and $existing -cne $ClientId.ToLowerInvariant()) { Remove-QueueTokenFile $DataRoot }
        $json = @{ schema_version = 1; client_id = $ClientId.ToLowerInvariant() } | ConvertTo-Json -Compress
        Write-QueuePrivateBytes $DataRoot 'client.json' ([Text.Encoding]::UTF8.GetBytes($json))
    } finally { $lock.Dispose() }
}

function Remove-QueueTokenFile {
    param([string]$DataRoot)
    try {
        $path = Join-Path (Resolve-QueuePrivatePath $DataRoot) 'tokens.dpapi'
        Assert-QueuePrivateFile $path
        if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
    } catch { Stop-QueueAuth storage_error }
}

function Clear-QueueTokens {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot)
    if (-not [IO.Directory]::Exists((Resolve-QueuePrivatePath $DataRoot))) { return }
    $lock = Enter-QueueAuthLock $DataRoot
    try { Remove-QueueTokenFile $DataRoot } finally { $lock.Dispose() }
}

function Write-QueueTokenRecord {
    param([string]$DataRoot, [object]$Record)
    $plain = $null
    try {
        Add-Type -AssemblyName System.Security -ErrorAction Stop
        $plain = [Text.Encoding]::UTF8.GetBytes(($Record | ConvertTo-Json -Depth 4 -Compress))
        if ($plain.Length -gt 32768) { Stop-QueueAuth storage_error }
        $sealed = [Security.Cryptography.ProtectedData]::Protect($plain, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        Write-QueuePrivateBytes $DataRoot 'tokens.dpapi' $sealed
    } catch { Stop-QueueAuth storage_error }
    finally { if ($null -ne $plain) { [Array]::Clear($plain, 0, $plain.Length) } }
}

function Read-QueueTokenRecord {
    param([string]$DataRoot)
    $plain = $null
    try {
        $root = Resolve-QueuePrivatePath $DataRoot
        $path = Join-Path $root 'tokens.dpapi'
        Assert-QueuePrivateFile $path
        if (-not [IO.File]::Exists($path)) { return $null }
        if ([IO.FileInfo]::new($path).Length -gt 65536) { Stop-QueueAuth storage_error }
        Add-Type -AssemblyName System.Security -ErrorAction Stop
        $sealed = [IO.File]::ReadAllBytes($path)
        $plain = [Security.Cryptography.ProtectedData]::Unprotect($sealed, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        if ($plain.Length -gt 32768) { Stop-QueueAuth storage_error }
        return ([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json -ErrorAction Stop)
    } catch { Stop-QueueAuth storage_error }
    finally { if ($null -ne $plain) { [Array]::Clear($plain, 0, $plain.Length) } }
}

function Get-QueuePkceChallenge {
    param([string]$Verifier)
    if ($Verifier -cnotmatch '\A[A-Za-z0-9._~-]{43,128}\z') { Stop-QueueAuth error }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($Verifier))).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    finally { $sha.Dispose() }
}

function New-QueuePkceMaterial {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = [byte[]]::new(64)
        $rng.GetBytes($bytes)
        $verifier = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $rng.GetBytes($bytes)
        $state = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        return [pscustomobject]@{ Verifier = $verifier; Challenge = Get-QueuePkceChallenge $verifier; State = $state }
    } finally { $rng.Dispose() }
}

function Test-QueueCallbackRequest {
    param([string]$RequestText, [int]$Port, [string]$ExpectedState, [double]$ElapsedSeconds, [switch]$Consumed)
    if ($Consumed) { Stop-QueueAuth invalid_callback }
    if ($ElapsedSeconds -lt 0 -or $ElapsedSeconds -ge 180 -or [double]::IsNaN($ElapsedSeconds) -or [double]::IsInfinity($ElapsedSeconds)) { Stop-QueueAuth auth_timeout }
    if ($Port -lt 1 -or $Port -gt 65535 -or $ExpectedState -cnotmatch '\A[A-Za-z0-9_-]{43,128}\z') { Stop-QueueAuth invalid_callback }
    if ($null -eq $RequestText -or $RequestText.Length -gt 16384 -or -not $RequestText.EndsWith("`r`n`r`n", [StringComparison]::Ordinal)) { Stop-QueueAuth invalid_callback }
    if ($RequestText -match '[^\x20-\x7e\r\n]' -or $RequestText -match '(?<!\r)\n|\r(?!\n)') { Stop-QueueAuth invalid_callback }
    $lines = $RequestText.Split(@("`r`n"), [StringSplitOptions]::None)
    if ($lines[0] -cnotmatch '\AGET (/callback\?[^ #]+) HTTP/1\.[01]\z') { Stop-QueueAuth invalid_callback }
    $target = $Matches[1]
    $hosts = 0
    for ($i = 1; $i -lt $lines.Length - 2; $i++) {
        if ($lines[$i] -notmatch '\A([A-Za-z0-9-]+):[ ]*([^\r\n]*)\z') { Stop-QueueAuth invalid_callback }
        $name, $value = $Matches[1], $Matches[2].Trim()
        if ([string]::Equals($name, 'Host', [StringComparison]::OrdinalIgnoreCase)) {
            $hosts++
            if ($value -cne "127.0.0.1:$Port") { Stop-QueueAuth invalid_callback }
        }
        if ($name -ieq 'Transfer-Encoding' -or ($name -ieq 'Content-Length' -and $value -cne '0')) { Stop-QueueAuth invalid_callback }
    }
    if ($hosts -ne 1) { Stop-QueueAuth invalid_callback }
    $query = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($pair in $target.Substring('/callback?'.Length).Split('&')) {
        if ($pair -cnotmatch '\A([^=]+)=(.*)\z' -or $pair -match '%(?![0-9A-Fa-f]{2})') { Stop-QueueAuth invalid_callback }
        try {
            $key = [Uri]::UnescapeDataString($Matches[1].Replace('+', ' '))
            $value = [Uri]::UnescapeDataString($Matches[2].Replace('+', ' '))
        } catch { Stop-QueueAuth invalid_callback }
        # OAuth 2.0 section 4.1.2 requires ignoring unrecognized response
        # parameters. Spotify adds optional fields such as ubi. Keep the whole
        # request bounded and reject duplicate keys; only code/state/error affect
        # authorization, and no extension value is persisted or reflected.
        if ($key -cnotmatch '\A[A-Za-z0-9._-]{1,128}\z' -or $query.ContainsKey($key) -or $query.Count -ge 32 -or $value.Length -gt 4096 -or $value -match '[^\x20-\x7e]') { Stop-QueueAuth invalid_callback }
        if ($key -cin @('state', 'code', 'error') -and ($value.Length -eq 0 -or $value -match '[^\x21-\x7e]')) { Stop-QueueAuth invalid_callback }
        $query.Add($key, $value)
    }
    if (-not $query.ContainsKey('state') -or -not [string]::Equals($query['state'], $ExpectedState, [StringComparison]::Ordinal)) { Stop-QueueAuth invalid_callback }
    if ($query.ContainsKey('code') -eq $query.ContainsKey('error')) { Stop-QueueAuth invalid_callback }
    if ($query.ContainsKey('error')) { return [pscustomobject]@{ Kind = 'denied' } }
    return [pscustomobject]@{ Kind = 'code'; Code = $query['code'] }
}

function Write-QueueCallbackResponse {
    param([IO.Stream]$Stream, [bool]$Accepted)
    # Static text, no reflected callback/auth fields and no external resources.
    $status = if ($Accepted) { '200 OK' } else { '400 Bad Request' }
    $body = if ($Accepted) { 'Authorization response received. Return to Parallax for the result.' } else { 'Authorization callback rejected.' }
    $bytes = [Text.Encoding]::ASCII.GetBytes($body)
    $header = "HTTP/1.1 $status`r`nContent-Type: text/plain; charset=utf-8`r`nCache-Control: no-store`r`nContent-Security-Policy: default-src 'none'`r`nX-Content-Type-Options: nosniff`r`nReferrer-Policy: no-referrer`r`nConnection: close`r`nContent-Length: $($bytes.Length)`r`n`r`n"
    $headBytes = [Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headBytes, 0, $headBytes.Length)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Wait-QueueCallback {
    param([Net.Sockets.TcpListener]$Listener, [int]$Port, [string]$State, [Diagnostics.Stopwatch]$Clock)
    while ($Clock.Elapsed.TotalSeconds -lt 180) {
        if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 50; continue }
        $client, $stream = $null, $null
        try {
            $client = $Listener.AcceptTcpClient()
            if (-not [Net.IPAddress]::IsLoopback($client.Client.RemoteEndPoint.Address)) { continue }
            $stream = $client.GetStream()
            $stream.WriteTimeout = 1000
            $connectionClock = [Diagnostics.Stopwatch]::StartNew()
            $bytes = [Collections.Generic.List[byte]]::new()
            $complete = $false
            while ($bytes.Count -lt 16384 -and $connectionClock.Elapsed.TotalSeconds -lt 3 -and $Clock.Elapsed.TotalSeconds -lt 180) {
                $remaining = [Math]::Min(3000 - $connectionClock.ElapsedMilliseconds, 180000 - $Clock.ElapsedMilliseconds)
                $stream.ReadTimeout = [Math]::Max(1, [int]$remaining)
                $value = $stream.ReadByte()
                if ($value -lt 0) { break }
                if (($value -lt 32 -and $value -notin @(13, 10)) -or $value -gt 126) { break }
                $bytes.Add([byte]$value)
                $n = $bytes.Count
                if ($n -ge 4 -and $bytes[$n-4] -eq 13 -and $bytes[$n-3] -eq 10 -and $bytes[$n-2] -eq 13 -and $bytes[$n-1] -eq 10) { $complete = $true; break }
            }
            if (-not $complete) { continue }
            $request = [Text.Encoding]::ASCII.GetString($bytes.ToArray())
            $callback = Test-QueueCallbackRequest -RequestText $request -Port $Port -ExpectedState $State -ElapsedSeconds $Clock.Elapsed.TotalSeconds
            try { Write-QueueCallbackResponse $stream $true } catch {}
            return $callback
        } catch {
            if ($null -ne $stream) { try { Write-QueueCallbackResponse $stream $false } catch {} }
            # Invalid requests/favicons do not consume the one legitimate callback.
        } finally {
            if ($null -ne $stream) { $stream.Dispose() }
            if ($null -ne $client) { $client.Close() }
        }
    }
    Stop-QueueAuth auth_timeout
}

function Invoke-QueueTokenHttp {
    param([Collections.IDictionary]$Form)
    $request, $response, $inputStream, $outputStream = $null, $null, $null, $null
    $oldTls = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $encoded = @($Form.Keys | ForEach-Object { [Uri]::EscapeDataString([string]$_) + '=' + [Uri]::EscapeDataString([string]$Form[$_]) }) -join '&'
        $payload = [Text.Encoding]::UTF8.GetBytes($encoded)
        $request = [Net.HttpWebRequest]::Create('https://accounts.spotify.com/api/token')
        $request.Method = 'POST'
        $request.ContentType = 'application/x-www-form-urlencoded'
        $request.AllowAutoRedirect = $false
        $request.Timeout = 15000
        $request.ReadWriteTimeout = 15000
        $request.ContentLength = $payload.Length
        $outputStream = $request.GetRequestStream()
        $outputStream.Write($payload, 0, $payload.Length)
        $outputStream.Dispose(); $outputStream = $null
        try { $response = $request.GetResponse() }
        catch [Net.WebException] { if ($null -eq $_.Exception.Response) { Stop-QueueAuth offline }; $response = $_.Exception.Response }
        $inputStream = $response.GetResponseStream()
        $buffer = [byte[]]::new(4096)
        $body = [IO.MemoryStream]::new()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        try {
            do {
                if ($clock.Elapsed.TotalSeconds -ge 15) { Stop-QueueAuth offline }
                if ($inputStream.CanTimeout) { $inputStream.ReadTimeout = [Math]::Max(1, 15000 - [int]$clock.ElapsedMilliseconds) }
                $read = $inputStream.Read($buffer, 0, $buffer.Length)
                if ($body.Length + $read -gt 65536) { Stop-QueueAuth error }
                $body.Write($buffer, 0, $read)
            } while ($read -gt 0)
            return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Body = [Text.Encoding]::UTF8.GetString($body.ToArray()); RetryAfter = $response.Headers['Retry-After'] }
        } finally { $body.Dispose() }
    } catch {
        if ($_.Exception.Data.Contains('QueueState')) { throw }
        Stop-QueueAuth offline
    } finally {
        if ($null -ne $outputStream) { $outputStream.Dispose() }
        if ($null -ne $inputStream) { $inputStream.Dispose() }
        if ($null -ne $response) { $response.Close() }
        if ($null -ne $request) { $request.Abort() }
        [Net.ServicePointManager]::SecurityProtocol = $oldTls
    }
}

function Invoke-QueueTokenPost {
    param([Collections.IDictionary]$Form)
    try {
        if ($null -ne $script:TokenTransport) { $reply = & $script:TokenTransport $Form }
        else { $reply = Invoke-QueueTokenHttp $Form }
    } catch {
        if ($_.Exception.Data.Contains('QueueState')) { throw }
        Stop-QueueAuth offline
    }
    try {
        if ($reply.Body -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($reply.Body) -gt 65536) { Stop-QueueAuth error }
        $data = $null
        try { $data = $reply.Body | ConvertFrom-Json -ErrorAction Stop }
        catch { if ([int]$reply.StatusCode -eq 200) { Stop-QueueAuth error } }
        if ([int]$reply.StatusCode -eq 200) { return $data }
        $errorValue = if ($null -ne $data -and $data.PSObject.Properties['error']) { $data.error } else { $null }
        if ([int]$reply.StatusCode -eq 400 -and $errorValue -is [string] -and $errorValue -ceq 'invalid_grant') { Stop-QueueAuth reauth_required }
        if ([int]$reply.StatusCode -in @(400, 401)) { Stop-QueueAuth onboarding_required }
        if ([int]$reply.StatusCode -eq 403) { Stop-QueueAuth forbidden }
        if ([int]$reply.StatusCode -eq 429) {
            if ($null -ne $errorValue -and $errorValue -isnot [string] -and $errorValue.PSObject.Properties['reason'] -and $errorValue.reason -ceq 'QUOTA_EXCEEDED') { Stop-QueueAuth quota_exceeded }
            $retry = 0L
            if ($reply.RetryAfter -is [string] -and $reply.RetryAfter -cmatch '\A[0-9]{1,12}\z' -and [long]::TryParse($reply.RetryAfter, [ref]$retry)) { Stop-QueueAuth rate_limited -RetryAfterSeconds ([Math]::Max(1L, $retry)) }
            $when = [DateTimeOffset]::MinValue
            if ([DateTimeOffset]::TryParse([string]$reply.RetryAfter, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$when)) {
                Stop-QueueAuth rate_limited -RetryAfterSeconds ([Math]::Max(1L, [long][Math]::Ceiling(($when - [DateTimeOffset]::UtcNow).TotalSeconds)))
            }
            Stop-QueueAuth rate_limited
        }
        Stop-QueueAuth error
    } catch {
        if ($_.Exception.Data.Contains('QueueState')) { throw }
        Stop-QueueAuth error
    }
}

function Test-QueueGrantedScope {
    param([object]$Scope)
    # Spotify can return a superset (including user-read-playback-state) when
    # refreshing a minimal-scope grant. Validate the required permission as a
    # token, not by comparing the complete scope string or its ordering.
    if ($Scope -isnot [string] -or $Scope.Length -gt 2048 -or $Scope -cnotmatch '\A[a-z][a-z0-9-]*( [a-z][a-z0-9-]*)*\z') { return $false }
    return @($Scope.Split(' ')) -ccontains $script:QueueScope
}

function ConvertTo-QueueTokenRecord {
    param([object]$Response, [string]$ClientId, [object]$Previous)
    try {
        if ($Response.access_token -isnot [string] -or $Response.access_token -cnotmatch '\A[\x21-\x7e]{1,8192}\z' -or $Response.token_type -ine 'Bearer') { Stop-QueueAuth error }
        $seconds = 0L
        if (-not [long]::TryParse([string]$Response.expires_in, [ref]$seconds) -or $seconds -lt 1 -or $seconds -gt 86400) { Stop-QueueAuth error }
        $scope = if ($Response.PSObject.Properties['scope']) { $Response.scope } elseif ($null -ne $Previous) { $Previous.scope } else { $null }
        if (-not (Test-QueueGrantedScope $scope)) { Stop-QueueAuth forbidden }
        $refresh = if ($Response.PSObject.Properties['refresh_token']) { $Response.refresh_token } elseif ($null -ne $Previous) { $Previous.refresh_token } else { $null }
        if ($refresh -isnot [string] -or $refresh -cnotmatch '\A[\x21-\x7e]{1,8192}\z') { Stop-QueueAuth error }
        $authorized = if ($null -eq $Previous) { [DateTimeOffset]::UtcNow.ToString('o') } else { $Previous.authorized_at_utc }
        return [pscustomobject]@{
            schema_version = 1; client_id = $ClientId; access_token = $Response.access_token
            refresh_token = $refresh; scope = $scope; authorized_at_utc = $authorized
            expires_at_utc = [DateTimeOffset]::UtcNow.AddSeconds($seconds).ToString('o')
        }
    } catch {
        if ($_.Exception.Data.Contains('QueueState')) { throw }
        Stop-QueueAuth error
    }
}

function Get-QueueAccessToken {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot, [switch]$ForceRefresh)
    $lock = Enter-QueueAuthLock $DataRoot
    try {
        $clientId = Get-QueueClientId $DataRoot
        if (-not $clientId) { Stop-QueueAuth onboarding_required }
        $record = Read-QueueTokenRecord $DataRoot
        if ($null -eq $record) { Stop-QueueAuth reauth_required }
        try {
            $authorized = [DateTimeOffset]::Parse($record.authorized_at_utc, [Globalization.CultureInfo]::InvariantCulture)
            $expires = [DateTimeOffset]::Parse($record.expires_at_utc, [Globalization.CultureInfo]::InvariantCulture)
            $now = [DateTimeOffset]::UtcNow
            if ($record.schema_version -ne 1 -or $record.client_id -cne $clientId -or -not (Test-QueueGrantedScope $record.scope) -or $record.access_token -isnot [string] -or $record.refresh_token -isnot [string] -or $record.access_token -cnotmatch '\A[\x21-\x7e]{1,8192}\z' -or $record.refresh_token -cnotmatch '\A[\x21-\x7e]{1,8192}\z' -or $authorized -gt $now.AddMinutes(1) -or $expires -gt $now.AddDays(1) -or $authorized.AddMonths(6) -le $now) { Stop-QueueAuth reauth_required }
        } catch { Remove-QueueTokenFile $DataRoot; Stop-QueueAuth reauth_required }
        if (-not $ForceRefresh -and $expires -gt $now.AddSeconds(60)) { return $record.access_token }
        try {
            $reply = Invoke-QueueTokenPost @{ grant_type = 'refresh_token'; refresh_token = $record.refresh_token; client_id = $clientId }
            $updated = ConvertTo-QueueTokenRecord -Response $reply -ClientId $clientId -Previous $record
            Write-QueueTokenRecord $DataRoot $updated
            return $updated.access_token
        } catch {
            if ($_.Exception.Data['QueueState'] -eq 'reauth_required') { Remove-QueueTokenFile $DataRoot }
            throw
        }
    } finally { $lock.Dispose() }
}

function Connect-QueueSpotify {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DataRoot)
    $lock = Enter-QueueAuthLock $DataRoot
    $listener = $null
    try {
        $clientId = Get-QueueClientId $DataRoot
        if (-not $clientId) { Stop-QueueAuth onboarding_required }
        $material = New-QueuePkceMaterial
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.ExclusiveAddressUse = $true
        $listener.Start(4)
        $port = $listener.LocalEndpoint.Port
        $redirect = "http://127.0.0.1:$port/callback"
        $parameters = [ordered]@{ client_id = $clientId; response_type = 'code'; redirect_uri = $redirect; state = $material.State; scope = $script:QueueScope; code_challenge_method = 'S256'; code_challenge = $material.Challenge }
        $query = @($parameters.Keys | ForEach-Object { [Uri]::EscapeDataString($_) + '=' + [Uri]::EscapeDataString([string]$parameters[$_]) }) -join '&'
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $launch = [Diagnostics.ProcessStartInfo]::new('https://accounts.spotify.com/authorize?' + $query)
        $launch.UseShellExecute = $true
        $browser = [Diagnostics.Process]::Start($launch)
        if ($null -ne $browser) { $browser.Dispose() } # Never kill the user's browser.
        $callback = Wait-QueueCallback -Listener $listener -Port $port -State $material.State -Clock $clock
        $listener.Stop(); $listener = $null # Consume once, close before token exchange.
        if ($callback.Kind -ceq 'denied') { Stop-QueueAuth authorization_denied }
        $response = Invoke-QueueTokenPost @{ grant_type = 'authorization_code'; client_id = $clientId; code = $callback.Code; code_verifier = $material.Verifier; redirect_uri = $redirect }
        $record = ConvertTo-QueueTokenRecord -Response $response -ClientId $clientId -Previous $null
        Write-QueueTokenRecord $DataRoot $record
        return [pscustomobject]@{ State = 'authorized'; Scope = $script:QueueScope }
    } catch {
        if ($_.Exception.Data.Contains('QueueState')) { throw }
        Stop-QueueAuth error
    } finally {
        if ($null -ne $listener) { $listener.Stop() }
        $lock.Dispose()
    }
}

Export-ModuleMember -Function Get-QueueDataRoot, Initialize-QueuePrivateDirectory, Set-QueueClientId, Get-QueueClientId, Connect-QueueSpotify, Get-QueueAccessToken, Clear-QueueTokens
