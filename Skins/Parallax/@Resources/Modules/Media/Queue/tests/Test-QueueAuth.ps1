# Developer-only, synthetic Windows PowerShell 5.1 tests. No browser, listener or
# Spotify requests are made. Each run retains an isolated private temp directory.
[CmdletBinding()]
param([string]$ModulePath = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($ModulePath)) { $ModulePath = Join-Path $PSScriptRoot '..\QueueAuth.psm1' }
$sourcePath = [IO.Path]::GetFullPath($ModulePath)
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw 'QueueAuth module is missing.' }
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Run this script with Windows PowerShell 5.1 (powershell.exe).'
}

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-QueueAuth-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test root.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test root must be fresh.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test temp parent is a reparse point.' }
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$runAcl = New-Object Security.AccessControl.DirectorySecurity
$runAcl.SetOwner($currentSid)
$runAcl.SetAccessRuleProtection($true, $false)
$runRule = New-Object Security.AccessControl.FileSystemAccessRule($currentSid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$runAcl.AddAccessRule($runRule)
$null = [IO.Directory]::CreateDirectory($runRoot, $runAcl)
$results = New-Object 'Collections.Generic.List[object]'
$utf8 = New-Object Text.UTF8Encoding($false)
$syntheticClientId = '00000000000000000000000000000001'
$syntheticAccess = 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'
$syntheticRefresh = 'SYNTHETIC_REFRESH_NOT_A_REAL_CREDENTIAL'
$syntheticCode = 'SYNTHETIC_CODE_NOT_A_REAL_CREDENTIAL'
$secretMarkers = @($syntheticAccess, $syntheticRefresh, $syntheticCode, 'SYNTHETIC_ERROR_DETAIL_NOT_FOR_OUTPUT')
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$authModule = Import-Module -Name $sourcePath -Force -PassThru -DisableNameChecking

function Assert-Test {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        $failure = New-Object InvalidOperationException('Synthetic test assertion failed.')
        $failure.Data['TestAssertion'] = $Code
        throw $failure
    }
}

function Get-TestQueueState {
    param([Exception]$Exception)
    for ($item = $Exception; $null -ne $item; $item = $item.InnerException) {
        if ($item.Data.Contains('QueueState')) { return [string]$item.Data['QueueState'] }
    }
    return ''
}

function Assert-QueueFailure {
    param([scriptblock]$Action, [string]$ExpectedState = '', [long]$ExpectedRetryAfterSeconds = -1)
    $caught = $null
    try { $null = & $Action } catch { $caught = $_ }
    Assert-Test ($null -ne $caught) 'expected_failure'
    $state = Get-TestQueueState $caught.Exception
    Assert-Test (-not [string]::IsNullOrWhiteSpace($state)) 'missing_queue_state'
    if ($ExpectedState) { Assert-Test ($state -ceq $ExpectedState) 'wrong_queue_state' }
    if ($ExpectedRetryAfterSeconds -ge 0) {
        $retry = $null
        for ($item = $caught.Exception; $null -ne $item; $item = $item.InnerException) {
            if ($item.Data.Contains('RetryAfterSeconds')) { $retry = $item.Data['RetryAfterSeconds']; break }
        }
        Assert-Test ($null -ne $retry -and $retry -eq $ExpectedRetryAfterSeconds) 'wrong_retry_after'
    }
    $errorText = $caught.ToString() + $caught.Exception.ToString()
    if ($null -ne $caught.ErrorDetails) { $errorText += $caught.ErrorDetails.Message }
    foreach ($marker in $secretMarkers) { Assert-Test (-not $errorText.Contains($marker)) 'secret_in_exception' }
}

function Invoke-TestCase {
    param([string]$Name, [scriptblock]$Action)
    try {
        $null = & $Action
        $results.Add([pscustomobject]@{ Name = $Name; Result = 'PASS'; Code = '' })
    } catch {
        # Never serialize an ErrorRecord or exception body: fixtures intentionally
        # place credential markers in hostile input and token endpoint responses.
        $code = 'unexpected_exception'
        $queueState = Get-TestQueueState $_.Exception
        if ($queueState -cmatch '^[a-z_]{1,40}$') { $code = 'unexpected_' + $queueState }
        for ($item = $_.Exception; $null -ne $item; $item = $item.InnerException) {
            if ($item.Data.Contains('TestAssertion')) { $code = [string]$item.Data['TestAssertion']; break }
        }
        $results.Add([pscustomobject]@{ Name = $Name; Result = 'FAIL'; Code = $code; ExceptionType = $_.Exception.GetType().FullName; ScriptLine = $_.InvocationInfo.ScriptLineNumber })
    }
}

function New-TestDataRoot {
    param([string]$Name)
    $path = Join-Path $runRoot $Name
    $null = Initialize-QueuePrivateDirectory -DataRoot $path
    return $path
}

function New-TestTokenRecord {
    param([int]$ExpiresInSeconds = 600)
    return [pscustomobject][ordered]@{
        schema_version = 1
        client_id = $syntheticClientId
        access_token = $syntheticAccess
        refresh_token = $syntheticRefresh
        scope = 'user-read-currently-playing'
        expires_at_utc = [DateTimeOffset]::UtcNow.AddSeconds($ExpiresInSeconds).ToString('o')
        authorized_at_utc = [DateTimeOffset]::UtcNow.AddDays(-1).ToString('o')
    }
}

function Write-TestRecord {
    param([string]$DataRoot, [object]$Record)
    $null = & $authModule { param($root, $value) Write-QueueTokenRecord -DataRoot $root -Record $value } $DataRoot $Record
}

function Read-TestRecord {
    param([string]$DataRoot)
    return & $authModule { param($root) Read-QueueTokenRecord -DataRoot $root } $DataRoot
}

function Set-TestTransport {
    param([int]$StatusCode = 200, [object]$Body = $null, [string]$RawBody = '', [string]$RetryAfter = '')
    $json = if ($PSBoundParameters.ContainsKey('RawBody')) { $RawBody } elseif ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Compress -Depth 5 }
    $null = & $authModule {
        param($status, $responseJson, $retryHeader)
        $script:TestTransportCalls = 0
        $script:TestLastForm = $null
        $script:TestTransportResponse = [pscustomobject]@{ StatusCode = $status; Body = $responseJson; RetryAfter = $retryHeader }
        $script:TokenTransport = {
            param($Form)
            $script:TestTransportCalls++
            $script:TestLastForm = $Form
            return $script:TestTransportResponse
        }
    } $StatusCode $json $RetryAfter
}

function Get-TestTransportCalls {
    return & $authModule { $script:TestTransportCalls }
}

function Assert-TestRefreshForm {
    $ok = & $authModule {
        param($id, $refresh)
        return (($script:TestLastForm['grant_type'] -ceq 'refresh_token') -and
            ($script:TestLastForm['client_id'] -ceq $id) -and
            ($script:TestLastForm['refresh_token'] -ceq $refresh) -and
            (-not $script:TestLastForm.ContainsKey('client_secret')) -and
            (-not $script:TestLastForm.ContainsKey('code')))
    } $syntheticClientId $syntheticRefresh
    Assert-Test $ok 'wrong_refresh_form'
}

function New-TestCallback {
    param([string]$Target, [string]$Method = 'GET', [string]$HostValue = '127.0.0.1:53681', [string]$ExtraHeaders = '')
    return "$Method $Target HTTP/1.1`r`nHost: $HostValue`r`n${ExtraHeaders}`r`n"
}

function Invoke-TestCallback {
    param([string]$RequestText, [double]$ElapsedSeconds = 1, [switch]$Consumed)
    return & $authModule {
        param($request, $elapsed, $wasConsumed)
        Test-QueueCallbackRequest -RequestText $request -Port 53681 -ExpectedState 'Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789' -ElapsedSeconds $elapsed -Consumed:$wasConsumed
    } $RequestText $ElapsedSeconds ([bool]$Consumed)
}

try {
    # Install the synthetic transport before any getter can need a refresh.
    Set-TestTransport -StatusCode 599 -Body @{ error = 'synthetic_transport_unconfigured' }

    Invoke-TestCase 'PKCE RFC 7636 S256 vector' {
        $challenge = & $authModule { Get-QueuePkceChallenge -Verifier 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }
        Assert-Test ($challenge -ceq 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM') 'pkce_vector'
    }
    Invoke-TestCase 'PKCE random material shape and independence' {
        $first = & $authModule { New-QueuePkceMaterial }
        $second = & $authModule { New-QueuePkceMaterial }
        Assert-Test ($first.Verifier -cmatch '^[A-Za-z0-9._~-]{43,128}$') 'pkce_verifier_shape'
        Assert-Test ($first.Challenge -cmatch '^[A-Za-z0-9_-]{43}$') 'pkce_challenge_shape'
        Assert-Test ($first.State.Length -ge 32) 'state_entropy_length'
        Assert-Test ($first.Verifier -cne $second.Verifier -and $first.State -cne $second.State) 'pkce_reused_material'
        $derived = & $authModule { param($verifier) Get-QueuePkceChallenge -Verifier $verifier } $first.Verifier
        Assert-Test ($first.Challenge -ceq $derived) 'pkce_challenge_mismatch'
    }

    $validTarget = '/callback?code=' + $syntheticCode + '&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789'
    $validRequest = New-TestCallback $validTarget
    Invoke-TestCase 'Callback accepts valid code' {
        $callback = Invoke-TestCallback $validRequest
        Assert-Test ($callback.Kind -ceq 'code' -and $callback.Code -ceq $syntheticCode) 'callback_code_result'
    }
    Invoke-TestCase 'Callback decodes opaque code exactly once' {
        $callback = Invoke-TestCallback (New-TestCallback '/callback?code=synthetic%2B%2F%3D%252B&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789')
        Assert-Test ($callback.Code -ceq 'synthetic+/=%2B') 'callback_code_decode'
    }
    Invoke-TestCase 'Callback accepts matching-state user denial' {
        $callback = Invoke-TestCallback (New-TestCallback '/callback?error=access_denied&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789')
        Assert-Test ($callback.Kind -ceq 'denied') 'callback_denial_result'
    }
    Invoke-TestCase 'Callback ignores Spotify optional response metadata' {
        $callback = Invoke-TestCallback (New-TestCallback ($validTarget + '&ubi=SYNTHETIC_OPTIONAL_METADATA%3D%3D&future_field=synthetic+value&empty='))
        Assert-Test ($callback.Kind -ceq 'code' -and $callback.Code -ceq $syntheticCode -and @($callback.PSObject.Properties).Count -eq 2) 'optional_parameter_changed_code'
    }
    Invoke-TestCase 'Callback denial tolerates descriptive extension' {
        $callback = Invoke-TestCallback (New-TestCallback '/callback?error=access_denied&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789&error_description=User+declined')
        Assert-Test ($callback.Kind -ceq 'denied') 'denial_extension_changed_result'
    }
    $badCallbacks = [ordered]@{
        'wrong host' = (New-TestCallback $validTarget -HostValue 'example.invalid:53681')
        'wrong port' = (New-TestCallback $validTarget -HostValue '127.0.0.1:53682')
        'missing host port' = (New-TestCallback $validTarget -HostValue '127.0.0.1')
        'duplicate Host header' = (New-TestCallback $validTarget -ExtraHeaders "hOsT: 127.0.0.1:53681`r`n")
        'wrong path' = (New-TestCallback $validTarget.Replace('/callback?', '/callback/extra?'))
        'encoded path' = (New-TestCallback $validTarget.Replace('/callback?', '/%63allback?'))
        'absolute request target' = (New-TestCallback ('http://127.0.0.1:53681' + $validTarget))
        'wrong method' = (New-TestCallback $validTarget -Method 'POST')
        'state case mismatch' = (New-TestCallback $validTarget.Replace('Synthetic_State_aA', 'SYNTHETIC_STATE_AA'))
        'duplicate state' = (New-TestCallback ($validTarget + '&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789'))
        'encoded duplicate state' = (New-TestCallback ($validTarget + '&%73tate=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789'))
        'encoded duplicate code' = (New-TestCallback ($validTarget + '&%63ode=synthetic-second-code'))
        'duplicate optional field' = (New-TestCallback ($validTarget + '&ubi=one&ubi=two'))
        'wrong state with optional metadata' = (New-TestCallback ($validTarget.Replace('Synthetic_State_aA', 'Wrong_State_aA') + '&ubi=synthetic'))
        'missing state' = (New-TestCallback ('/callback?code=' + $syntheticCode))
        'empty state' = (New-TestCallback ('/callback?code=' + $syntheticCode + '&state='))
        'empty code' = (New-TestCallback '/callback?code=&state=Synthetic_State_aA_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789')
        'code and error' = (New-TestCallback ($validTarget + '&error=access_denied'))
        'denial with wrong state' = (New-TestCallback '/callback?error=access_denied&state=synthetic-wrong')
        'malformed percent escape' = (New-TestCallback $validTarget.Replace($syntheticCode, 'synthetic%Q0'))
        'decoded control' = (New-TestCallback $validTarget.Replace($syntheticCode, 'synthetic%0D%0A'))
        'raw control' = (New-TestCallback $validTarget.Replace($syntheticCode, ('synthetic' + [char]0)))
        'fragment' = (New-TestCallback ($validTarget + '#synthetic-fragment'))
    }
    foreach ($entry in $badCallbacks.GetEnumerator()) {
        $badRequest = $entry.Value
        Invoke-TestCase ('Callback rejects ' + $entry.Key) { Assert-QueueFailure { Invoke-TestCallback $badRequest } 'invalid_callback' }
    }
    Invoke-TestCase 'Callback rejects expired attempt' { Assert-QueueFailure { Invoke-TestCallback $validRequest -ElapsedSeconds 181 } 'auth_timeout' }
    Invoke-TestCase 'Callback rejects consumed attempt' { Assert-QueueFailure { Invoke-TestCallback $validRequest -Consumed } 'invalid_callback' }

    Invoke-TestCase 'Private directory has only current-user access' {
        $root = New-TestDataRoot 'acl'
        $acl = Get-Acl -LiteralPath $root
        Assert-Test ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ceq $currentSid.Value) 'root_owner'
        Assert-Test $acl.AreAccessRulesProtected 'root_inheritance'
        $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
        Assert-Test ($rules.Count -gt 0) 'root_empty_acl'
        foreach ($rule in $rules) {
            Assert-Test ($rule.IdentityReference.Value -ceq $currentSid.Value) 'root_foreign_acl'
            Assert-Test ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow) 'root_deny_acl'
        }
    }
    Invoke-TestCase 'Client ID persists and malformed value fails safely' {
        $root = New-TestDataRoot 'client-id'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Assert-Test ((Get-QueueClientId -DataRoot $root) -ceq $syntheticClientId) 'client_id_roundtrip'
        Assert-QueueFailure { Set-QueueClientId -DataRoot $root -ClientId $syntheticCode }
        Assert-Test ((Get-QueueClientId -DataRoot $root) -ceq $syntheticClientId) 'invalid_id_overwrote_config'
    }
    Invoke-TestCase 'DPAPI token roundtrip has no plaintext credential on disk' {
        $root = New-TestDataRoot 'dpapi'
        $record = New-TestTokenRecord
        Write-TestRecord $root $record
        $loaded = Read-TestRecord $root
        Assert-Test ($loaded.access_token -ceq $record.access_token -and $loaded.refresh_token -ceq $record.refresh_token) 'dpapi_roundtrip'
        Assert-Test ($loaded.authorized_at_utc -ceq $record.authorized_at_utc) 'dpapi_authorized_date'
        $files = @(Get-ChildItem -LiteralPath $root -File)
        Assert-Test ($files.Count -gt 0) 'dpapi_no_files'
        foreach ($file in $files) {
            foreach ($rule in (Get-Acl -LiteralPath $file.FullName).GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
                Assert-Test ($rule.IdentityReference.Value -ceq $currentSid.Value -and $rule.AccessControlType -eq 'Allow') 'token_file_foreign_acl'
            }
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            foreach ($decoder in @([Text.Encoding]::UTF8, [Text.Encoding]::Unicode)) {
                $storedText = $decoder.GetString($bytes)
                Assert-Test (-not $storedText.Contains($syntheticAccess) -and -not $storedText.Contains($syntheticRefresh)) 'plaintext_credentials'
            }
        }
    }
    Invoke-TestCase 'Fresh access token does not call transport' {
        $root = New-TestDataRoot 'fresh'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord)
        Set-TestTransport -StatusCode 599
        Assert-Test ((Get-QueueAccessToken -DataRoot $root) -ceq $syntheticAccess) 'fresh_access_value'
        Assert-Test ((Get-TestTransportCalls) -eq 0) 'fresh_token_network'
    }
    Invoke-TestCase 'Encrypted token overwrite preserves the new record' {
        $root = New-TestDataRoot 'token-overwrite'
        $record = New-TestTokenRecord
        Write-TestRecord $root $record
        $record.access_token = $syntheticAccess + '_REPLACED'
        Write-TestRecord $root $record
        Assert-Test ((Read-TestRecord $root).access_token -ceq ($syntheticAccess + '_REPLACED')) 'token_overwrite_value'
    }
    foreach ($rotate in @($false, $true)) {
        Invoke-TestCase ('Refresh preserves authorization date; rotation=' + $rotate) {
            $root = New-TestDataRoot ('refresh-' + $rotate)
            $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
            $record = New-TestTokenRecord -ExpiresInSeconds -120
            Write-TestRecord $root $record
            $body = @{ access_token = $syntheticAccess + '_NEW'; token_type = 'Bearer'; expires_in = 3600; scope = 'user-read-currently-playing' }
            if ($rotate) { $body.refresh_token = $syntheticRefresh + '_ROTATED' }
            Set-TestTransport -Body $body
            $token = Get-QueueAccessToken -DataRoot $root
            Assert-Test ($token -ceq ($syntheticAccess + '_NEW')) 'refreshed_access_value'
            Assert-Test ((Get-TestTransportCalls) -eq 1) 'refresh_request_count'
            Assert-TestRefreshForm
            $loaded = Read-TestRecord $root
            $expectedRefresh = if ($rotate) { $syntheticRefresh + '_ROTATED' } else { $syntheticRefresh }
            Assert-Test ($loaded.refresh_token -ceq $expectedRefresh) 'refresh_rotation'
            Assert-Test ($loaded.authorized_at_utc -ceq $record.authorized_at_utc) 'refresh_extended_authorization'
            Assert-Test ([DateTimeOffset]::Parse($loaded.expires_at_utc) -gt [DateTimeOffset]::UtcNow.AddMinutes(55)) 'refresh_expiry'
        }
    }
    Invoke-TestCase 'ForceRefresh refreshes an otherwise fresh token' {
        $root = New-TestDataRoot 'force-refresh'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord)
        Set-TestTransport -Body @{ access_token = $syntheticAccess + '_FORCED'; token_type = 'Bearer'; expires_in = 3600 }
        Assert-Test ((Get-QueueAccessToken -DataRoot $root -ForceRefresh) -ceq ($syntheticAccess + '_FORCED')) 'force_refresh_value'
        Assert-Test ((Get-TestTransportCalls) -eq 1) 'force_refresh_count'
    }
    Invoke-TestCase 'Invalid grant clears credentials and does not repeat refresh' {
        $root = New-TestDataRoot 'invalid-grant'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord -ExpiresInSeconds -120)
        Set-TestTransport -StatusCode 400 -Body @{ error = 'invalid_grant'; error_description = 'SYNTHETIC_ERROR_DETAIL_NOT_FOR_OUTPUT' }
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root }
        Assert-Test ((Get-TestTransportCalls) -eq 1) 'invalid_grant_count'
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root }
        Assert-Test ((Get-TestTransportCalls) -eq 1) 'invalid_grant_retried'
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $root 'tokens.dpapi'))) 'invalid_grant_kept_tokens'
        Assert-Test ((Get-QueueClientId -DataRoot $root) -ceq $syntheticClientId) 'invalid_grant_cleared_client'
    }
    Invoke-TestCase 'Transient refresh failure preserves refresh credential' {
        $root = New-TestDataRoot 'transient'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord -ExpiresInSeconds -120)
        Set-TestTransport -StatusCode 503 -Body @{ error = 'temporarily_unavailable'; error_description = $syntheticRefresh }
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root }
        Assert-Test ((Read-TestRecord $root).refresh_token -ceq $syntheticRefresh) 'transient_cleared_refresh'
        Assert-Test ((Get-TestTransportCalls) -eq 1) 'transient_retry_loop'
    }
    Invoke-TestCase 'Six-month original authorization expiry requires reconnect' {
        $root = New-TestDataRoot 'six-month-expired'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        $record = New-TestTokenRecord
        $record.authorized_at_utc = [DateTimeOffset]::UtcNow.AddMonths(-6).AddDays(-1).ToString('o')
        Write-TestRecord $root $record
        Set-TestTransport -StatusCode 599
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'reauth_required'
        Assert-Test ((Get-TestTransportCalls) -eq 0) 'expired_authorization_refreshed'
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $root 'tokens.dpapi'))) 'expired_authorization_kept_tokens'
    }
    Invoke-TestCase 'Authorization before six-month limit retains a fresh token' {
        $root = New-TestDataRoot 'six-month-valid'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        $record = New-TestTokenRecord
        $record.authorized_at_utc = [DateTimeOffset]::UtcNow.AddMonths(-6).AddDays(1).ToString('o')
        Write-TestRecord $root $record
        Set-TestTransport -StatusCode 599
        Assert-Test ((Get-QueueAccessToken -DataRoot $root) -ceq $syntheticAccess) 'authorization_early_expiry'
        Assert-Test ((Get-TestTransportCalls) -eq 0) 'authorization_early_refresh'
    }
    foreach ($responseKind in @('json', 'non-json', 'invalid-header', 'long-wait', 'http-date', 'quota')) {
        Invoke-TestCase ('HTTP 429 handling: ' + $responseKind) {
            $root = New-TestDataRoot ('rate-limit-' + $responseKind)
            $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
            Write-TestRecord $root (New-TestTokenRecord -ExpiresInSeconds -120)
            if ($responseKind -eq 'json') {
                Set-TestTransport -StatusCode 429 -Body @{ error = 'SYNTHETIC_ERROR_DETAIL_NOT_FOR_OUTPUT' } -RetryAfter '17'
                Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'rate_limited' -ExpectedRetryAfterSeconds 17
            } elseif ($responseKind -eq 'non-json') {
                Set-TestTransport -StatusCode 429 -RawBody '<html>SYNTHETIC_ERROR_DETAIL_NOT_FOR_OUTPUT</html>' -RetryAfter '23'
                Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'rate_limited' -ExpectedRetryAfterSeconds 23
            } elseif ($responseKind -eq 'invalid-header') {
                Set-TestTransport -StatusCode 429 -RawBody '' -RetryAfter 'synthetic-invalid-delay'
                Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'rate_limited'
            } elseif ($responseKind -eq 'long-wait') {
                Set-TestTransport -StatusCode 429 -RawBody '{}' -RetryAfter '3000000000'
                Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'rate_limited' -ExpectedRetryAfterSeconds 3000000000L
            } elseif ($responseKind -eq 'http-date') {
                Set-TestTransport -StatusCode 429 -RawBody '{}' -RetryAfter ([DateTimeOffset]::UtcNow.AddHours(1).ToString('r'))
                $failure = $null
                try { $null = Get-QueueAccessToken -DataRoot $root } catch { $failure = $_.Exception }
                Assert-Test ($null -ne $failure -and $failure.Data['QueueState'] -eq 'rate_limited' -and $failure.Data['RetryAfterSeconds'] -ge 3598 -and $failure.Data['RetryAfterSeconds'] -le 3600) 'http_date_wait_not_retained'
            } else {
                Set-TestTransport -StatusCode 429 -Body @{ error = @{ reason = 'QUOTA_EXCEEDED'; message = 'SYNTHETIC_ERROR_DETAIL_NOT_FOR_OUTPUT' } } -RetryAfter '19'
                Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'quota_exceeded'
            }
            Assert-Test ((Get-TestTransportCalls) -eq 1) 'rate_limit_retry_loop'
            Assert-Test ((Read-TestRecord $root).refresh_token -ceq $syntheticRefresh) 'rate_limit_cleared_refresh'
        }
    }
    Invoke-TestCase 'Corrupt encrypted record fails safely before transport' {
        $root = New-TestDataRoot 'corrupt-token'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord)
        [IO.File]::WriteAllBytes((Join-Path $root 'tokens.dpapi'), [byte[]](1,2,3,4))
        Set-TestTransport -StatusCode 599
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'storage_error'
        Assert-Test ((Get-TestTransportCalls) -eq 0) 'corrupt_record_transport'
    }
    Invoke-TestCase 'Broad explicit token-file ACL is rejected before read' {
        $root = New-TestDataRoot 'broad-token-acl'
        Write-TestRecord $root (New-TestTokenRecord)
        $path = Join-Path $root 'tokens.dpapi'
        $acl = Get-Acl -LiteralPath $path
        $everyone = New-Object Security.Principal.SecurityIdentifier('S-1-1-0')
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($everyone, 'Read', 'Allow')))
        Set-Acl -LiteralPath $path -AclObject $acl
        Assert-QueueFailure { Read-TestRecord $root } 'storage_error'
    }
    foreach ($returnedScope in @('user-read-playback-state user-read-currently-playing','user-read-currently-playing user-read-playback-state')) {
        Invoke-TestCase ('Refresh accepts required scope in granted set: ' + $returnedScope) {
            $root = New-TestDataRoot ('scope-superset-' + [Guid]::NewGuid().ToString('N'))
            $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
            Write-TestRecord $root (New-TestTokenRecord -ExpiresInSeconds -120)
            Set-TestTransport -Body @{access_token=$syntheticAccess;token_type='Bearer';expires_in=3600;scope=$returnedScope}
            $token = Get-QueueAccessToken -DataRoot $root
            Assert-Test ($token -ceq $syntheticAccess) 'superset_refresh_rejected'
            Assert-Test ((Read-TestRecord $root).scope -ceq $returnedScope) 'granted_scope_not_retained'
            $token = Get-QueueAccessToken -DataRoot $root
            Assert-Test ($token -ceq $syntheticAccess -and (Get-TestTransportCalls) -eq 1) 'stored_superset_rejected'
            Set-TestTransport -Body @{access_token=$syntheticAccess;token_type='Bearer';expires_in=3600}
            $token = Get-QueueAccessToken -DataRoot $root -ForceRefresh
            Assert-Test ((Read-TestRecord $root).scope -ceq $returnedScope) 'omitted_scope_dropped_previous_grant'
        }
    }
    foreach ($returnedScope in @('user-read-private','user-read-currently-playing-extra','USER-READ-CURRENTLY-PLAYING')) {
        Invoke-TestCase ('Refresh rejects missing required permission: ' + $returnedScope) {
            $root = New-TestDataRoot ('scope-missing-' + [Guid]::NewGuid().ToString('N'))
            $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
            Write-TestRecord $root (New-TestTokenRecord -ExpiresInSeconds -120)
            Set-TestTransport -Body @{access_token=$syntheticAccess;token_type='Bearer';expires_in=3600;scope=$returnedScope}
            Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root } 'forbidden'
        }
    }
    foreach ($invalidField in @('client_id', 'scope', 'expires_at_utc')) {
        Invoke-TestCase ('Stored record rejects invalid ' + $invalidField) {
            $root = New-TestDataRoot ('invalid-record-' + $invalidField)
            $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
            $record = New-TestTokenRecord
            if ($invalidField -eq 'client_id') { $record.client_id = '00000000000000000000000000000002' }
            if ($invalidField -eq 'scope') { $record.scope = 'user-read-private' }
            if ($invalidField -eq 'expires_at_utc') { $record.expires_at_utc = 'synthetic-invalid-time' }
            Set-TestTransport -StatusCode 599
            Assert-QueueFailure { Write-TestRecord $root $record; Get-QueueAccessToken -DataRoot $root }
            Assert-Test ((Get-TestTransportCalls) -eq 0) 'invalid_record_transport'
        }
    }
    Invoke-TestCase 'Clear tokens preserves client ID and stops refresh' {
        $root = New-TestDataRoot 'clear'
        $null = Set-QueueClientId -DataRoot $root -ClientId $syntheticClientId
        Write-TestRecord $root (New-TestTokenRecord)
        $null = Clear-QueueTokens -DataRoot $root
        Set-TestTransport -StatusCode 599
        Assert-QueueFailure { Get-QueueAccessToken -DataRoot $root }
        Assert-Test ((Get-TestTransportCalls) -eq 0) 'clear_token_transport'
        Assert-Test ((Get-QueueClientId -DataRoot $root) -ceq $syntheticClientId) 'clear_removed_client'
    }

    # Junctions and their targets stay in the fresh run root. Nothing is removed,
    # recursively traversed, or redirected into an existing user-data directory.
    foreach ($junctionCase in @('target', 'ancestor')) {
        $linkPath = Join-Path $runRoot ('junction-' + $junctionCase)
        $targetPath = Join-Path $runRoot ('junction-destination-' + $junctionCase)
        $null = [IO.Directory]::CreateDirectory($targetPath, $runAcl)
        $junctionCreated = $false
        try { $null = New-Item -ItemType Junction -Path $linkPath -Value $targetPath; $junctionCreated = $true } catch { }
        if (-not $junctionCreated) {
            $results.Add([pscustomobject]@{ Name = 'Storage rejects reparse ' + $junctionCase; Result = 'SKIP'; Code = 'junction_creation_unavailable' })
            continue
        }
        Invoke-TestCase ('Storage rejects reparse ' + $junctionCase) {
            $root = if ($junctionCase -eq 'ancestor') { Join-Path $linkPath 'child' } else { $linkPath }
            $beforeSddl = (Get-Acl -LiteralPath $targetPath).Sddl
            Assert-QueueFailure { Initialize-QueuePrivateDirectory -DataRoot $root }
            Assert-Test ((Get-Acl -LiteralPath $targetPath).Sddl -ceq $beforeSddl) 'reparse_target_acl_changed'
            if ($junctionCase -eq 'ancestor') { Assert-Test (-not (Test-Path -LiteralPath (Join-Path $targetPath 'child'))) 'reparse_created_child' }
        }
    }
} finally {
    $passed = @($results | Where-Object { $_.Result -eq 'PASS' }).Count
    $failed = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
    $skipped = @($results | Where-Object { $_.Result -eq 'SKIP' }).Count
    $report = [ordered]@{
        schema_version = 1
        provider = 'synthetic; no browser, listener or Spotify requests'
        runtime = $PSVersionTable.PSVersion.ToString()
        source_sha256 = $sourceHash
        source_unchanged = ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ceq $sourceHash)
        suite_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
        passed = $passed
        failed = $failed
        skipped = $skipped
        cases = @($results.ToArray())
        limitation = 'Does not verify browser authorization, real HTTP, Spotify responses, cross-user decryption or same-user hostile races.'
    }
    [IO.File]::WriteAllText((Join-Path $runRoot 'results.json'), ($report | ConvertTo-Json -Depth 6), $utf8)
    Write-Output ('Queue auth synthetic checks: {0} passed, {1} failed, {2} skipped.' -f $passed, $failed, $skipped)
    Write-Output ('Windows PowerShell runtime: ' + $report.runtime)
    Write-Output ('Tested QueueAuth SHA256: ' + $report.source_sha256)
    Write-Output ('Test suite SHA256: ' + $report.suite_sha256)
    foreach ($result in $results) { if ($result.Result -ne 'PASS') { Write-Output ('{0}: {1} ({2})' -f $result.Result, $result.Name, $result.Code) } }
    Write-Output ('Retained synthetic evidence: ' + $runRoot)
    Remove-Module -ModuleInfo $authModule -Force
}
if ($failed -gt 0 -or -not $report.source_unchanged) { throw 'Synthetic QueueAuth checks failed or source changed during execution; see sanitized results.json.' }
