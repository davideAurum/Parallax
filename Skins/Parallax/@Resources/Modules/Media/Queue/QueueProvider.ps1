# Optional Spotify queue helper. Windows PowerShell 5.1 / built-in .NET only.
# Imports are passive. Run/Connect require an explicit command; no autostart.
#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Help','Configure','Connect','Start','Run','Stop','Restart','Disconnect')][string]$Command = 'Help',
    [string]$ClientId = '',
    [ValidateRange(30,150)][int]$PollSeconds = 30,
    [switch]$Once,
    [switch]$Quiet,
    [switch]$ResumeAfterQuota,
    [string]$DataRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'QueueAuth.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'QueueCore.psm1') -Force -DisableNameChecking
$script:ProviderPath = $PSCommandPath

function Show-QueueHelp {
    Write-Output @'
Parallax Spotify queue (read-only)
1. Open https://developer.spotify.com/dashboard and select your app.
2. Add redirect URI http://127.0.0.1/callback and save it.
3. Run this script with -Command Connect. Enter the public Client ID if asked.
4. Sign in and consent in Spotify's browser page. The queue helper starts after login.

Commands: Connect (sign in), Start (background), Run (foreground), Stop, Restart,
          Disconnect (stop and remove local tokens/listening cache), Configure.
Run accepts -Once, -PollSeconds 30..150 and -ResumeAfterQuota for an explicit retry
after resolving exhausted quota. Ordinary server Retry-After waits are retained.
No client secret is needed. Development apps require owner Premium and allowlisting.
Tokens and display cache stay in LocalAppData, outside skins. No automatic startup.
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
function Wait-QueueMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds)
    try { return $Mutex.WaitOne($Milliseconds) } catch [Threading.AbandonedMutexException] { return $true }
}

function Get-QueueRuntimeFile {
    param([string]$Root, [ValidateSet('stop.request','queue.retry.json','queue.snapshot')][string]$Name)
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

function Invoke-QueueCycle {
    param([string]$Root, [int]$Interval, [int]$FailureCount = 0)
    try {
        $token = Get-QueueAccessToken -DataRoot $Root
        $response = Invoke-QueueApiRequest -AccessToken $token
        if ($response.StatusCode -eq 401) {
            # Exactly one forced refresh, then one GET retry. Never a consent loop.
            $token = Get-QueueAccessToken -DataRoot $Root -ForceRefresh
            $response = Invoke-QueueApiRequest -AccessToken $token
        }
        $token = $null
        $now = Get-QueueUnixTime
        $decision = Get-QueueResponseDecision -StatusCode $response.StatusCode -Body $response.Body -RetryAfter $response.RetryAfter -Now $now -FailureCount $FailureCount
        if ($decision.State -eq 'response_requires_validation') {
            try {
                $items = ConvertTo-QueueItems (ConvertFrom-QueueJson $response.Body)
                $lifetime = [Math]::Min(300, [Math]::Max(90, $Interval*2))
                $snapshot = New-QueueSnapshot -State ready -Items $items.Items -Now $now -LifetimeSeconds $lifetime
                return [pscustomobject]@{ Snapshot=$snapshot; NextAt=($now+$Interval); Pause=$false; Success=$true }
            } catch {
                $decision = Get-QueueResponseDecision 204 -Now $now -FailureCount $FailureCount
            }
        }
    } catch { $decision = Get-QueueExceptionDecision $_.Exception $FailureCount }
    finally { $token=$null }
    $snapshot = New-QueueSnapshot -State $decision.State -RetryNotBefore $decision.RetryNotBefore
    return [pscustomobject]@{ Snapshot=$snapshot; NextAt=$decision.RetryNotBefore; Pause=$decision.Pause; Success=$false }
}

function Start-QueueBackground {
    param([string]$Root, [int]$Interval, [switch]$RetryQuota)
    $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($script:ProviderPath.Contains('"') -or $Root.Contains('"')) { throw 'Unsupported helper path.' }
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script:ProviderPath + '" -Command Run -Quiet -PollSeconds ' + $Interval + ' -DataRoot "' + $Root + '"'
    if ($RetryQuota) { $arguments += ' -ResumeAfterQuota' }
    $null = Start-Process -FilePath $hostPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
}

function Invoke-QueueRun {
    param([string]$Root, [int]$Interval=30, [switch]$Single, [switch]$RetryQuota, [switch]$Silent)
    $mutex = New-QueueRunMutex $Root
    $owned = $false
    try {
        $owned = Wait-QueueMutex $mutex 0
        if (-not $owned) { if (-not $Silent) { Write-Output 'The queue helper is already running.' }; return }
        $stopPath = Get-QueueRuntimeFile $Root 'stop.request'
        if ([IO.File]::Exists($stopPath)) { [IO.File]::Delete($stopPath) }
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
        while (-not (Test-QueueStop $Root)) {
            if ((Get-QueueUnixTime) -lt $next) { Start-Sleep -Milliseconds 1000; continue }
            $result = Invoke-QueueCycle -Root $Root -Interval $Interval -FailureCount $failures
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
                $retryPath = Get-QueueRuntimeFile $Root 'queue.retry.json'
                if ([IO.File]::Exists($retryPath)) { [IO.File]::Delete($retryPath) }
            } else {
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
    }
}

function Invoke-QueueCommand {
    if ($Command -eq 'Help') { Show-QueueHelp; return }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 to run QueueProvider.ps1.' }
    if (-not $DataRoot) { $DataRoot = Get-QueueDataRoot }
    $DataRoot = Initialize-QueuePrivateDirectory -DataRoot $DataRoot
    if ($Command -eq 'Start') { Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:$ResumeAfterQuota; return }
    if ($Command -eq 'Run') { Invoke-QueueRun $DataRoot $PollSeconds -Single:$Once -RetryQuota:$ResumeAfterQuota -Silent:$Quiet; return }
    # Account/configuration changes serialize with the single polling process.
    Request-QueueStop $DataRoot
    $mutex = New-QueueRunMutex $DataRoot
    $owned = $false
    $startAfterLogin = $false
    try {
        $owned = Wait-QueueMutex $mutex 40000
        if (-not $owned) { throw 'The queue helper is busy. Stop it and try again.' }
        if ($Command -eq 'Stop') { Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State stopped); return }
        if ($Command -eq 'Restart') {
            # Stop is observed and the old worker released the mutex before this
            # replacement starts. Persisted server/quota barriers remain intact.
            Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State stopped)
            $startAfterLogin = $true
        }
        if ($Command -eq 'Disconnect') {
            Clear-QueueTokens -DataRoot $DataRoot
            Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State onboarding_required)
            if (-not $Quiet) { Write-Output 'Disconnected. Local tokens and queue rows removed. App configuration is retained; you can also revoke access in Spotify account settings.' }
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
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
    if ($startAfterLogin) {
        Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:$ResumeAfterQuota
        if (-not $Quiet) {
            if ($Command -eq 'Restart') { Write-Output 'The queue helper is restarting with the selected interval.' }
            else { Write-Output 'Spotify authorization saved. The queue helper is starting in the background.' }
        }
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
