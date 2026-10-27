# Optional Spotify queue helper. Windows PowerShell 5.1 / built-in .NET only.
# Imports are passive. Resume honors only the user's saved Start/Connect intent.
#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Help','Configure','Connect','Start','Resume','Run','Stop','Restart','Disconnect','Refresh','Play')][string]$Command = 'Help',
    # Play: the clicked row (1-5) and the observed time of the snapshot it was
    # read from, so the worker acts only on the queue the user actually saw.
    [ValidateRange(0,5)][int]$Position = 0,
    [ValidateRange(0,253402300000)][long]$Observed = 0,
    [string]$ClientId = '',
    [ValidateRange(30,150)][int]$PollSeconds = 30,
    [switch]$Once,
    [switch]$Quiet,
    [switch]$ResumeAfterQuota,
    [ValidatePattern('\A(?:[a-f0-9]{32})?\z')][string]$LaunchId = '',
    [string]$DataRoot = '',
    [ValidatePattern('\A(?:[1-9][0-9]{0,9}:[1-9][0-9]{0,18})?\z')][string]$OwnerLease = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'QueueAuth.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'QueueCore.psm1') -Force -DisableNameChecking
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProviderOwner.psm1') -Force -DisableNameChecking
$script:ProviderPath = $PSCommandPath

function Show-QueueHelp {
    Write-Output @'
Parallax Spotify queue (read-only)
1. Open https://developer.spotify.com/dashboard and select your app.
2. Add redirect URI http://127.0.0.1/callback and save it.
3. Run this script with -Command Connect. Enter the public Client ID if asked.
4. Sign in and consent in Spotify's browser page. The queue helper starts after login.

Commands: Connect (sign in), Start (background), Resume (saved intent), Run, Stop, Restart,
          Disconnect (stop and remove local tokens/listening cache), Configure,
          Refresh (ask the running helper to read now), Play -Position n -Observed t
          (skip the running helper's player to queue row n; needs the playback
          control permission, granted by signing in again with Connect).
Run accepts -Once, -PollSeconds 30..150 and -ResumeAfterQuota for an explicit retry
after resolving exhausted quota. Ordinary server Retry-After waits are retained.
No client secret is needed. Development apps require owner Premium and allowlisting.
Tokens and display cache stay in LocalAppData, outside skins. Skin-load Resume
continues an enabled helper without opening sign-in. Stop/Disconnect disable it.
Direct Run honors an earlier Stop; use Start or Restart to enable it again.
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
function New-QueueControlMutex { param([string]$Root); return [Threading.Mutex]::new($false, ((Get-QueueMutexName $Root) + '.Control')) }
function Wait-QueueMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds)
    try { return $Mutex.WaitOne($Milliseconds) } catch [Threading.AbandonedMutexException] { return $true }
}

function Get-QueueRuntimeFile {
    param([string]$Root, [ValidateSet('stop.request','queue.retry.json','queue.snapshot','enabled.intent','launch.id','action.request')][string]$Name)
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

function Clear-QueueStop {
    param([string]$Root)
    # Only an explicit enabling command calls this, while holding control ownership.
    $path = Get-QueueRuntimeFile $Root 'stop.request'
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
}

function Test-QueueEnabledIntent {
    param([string]$Root)
    $path = Get-QueueRuntimeFile $Root 'enabled.intent'
    if (-not [IO.File]::Exists($path)) { return $false }
    $expected = [Text.Encoding]::ASCII.GetBytes("PARALLAX_AUTOSTART_V1|1`n")
    if ([IO.FileInfo]::new($path).Length -ne $expected.Length) { return $false }
    $actual = [IO.File]::ReadAllBytes($path)
    if ($actual.Length -ne $expected.Length) { return $false }
    for ($index = 0; $index -lt $expected.Length; $index++) {
        if ($actual[$index] -ne $expected[$index]) { return $false }
    }
    return $true
}

function Set-QueueEnabledIntent {
    param([string]$Root, [bool]$Enabled)
    $value = if ($Enabled) { '1' } else { '0' }
    Write-QueueControlFile $Root 'enabled.intent' "PARALLAX_AUTOSTART_V1|$value`n"
}

function Write-QueueControlFile {
    param([string]$Root, [ValidateSet('enabled.intent','launch.id','action.request')][string]$Name, [string]$Text)
    $path = Get-QueueRuntimeFile $Root $Name
    $temporary = Join-Path $Root ('.queue-control-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
    $stream = $null
    try {
        $stream = [IO.FileStream]::new($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        $null = Get-QueueRuntimeFile $Root $Name
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temporary, $path, [Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $path) }
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function New-QueueLaunchId {
    param([string]$Root)
    $identifier = [Guid]::NewGuid().ToString('N')
    Write-QueueControlFile $Root 'launch.id' "$identifier`n"
    return $identifier
}

function Test-QueueLaunchId {
    param([string]$Root, [string]$Identifier)
    if ($Identifier -cnotmatch '\A[a-f0-9]{32}\z') { return $false }
    $path = Get-QueueRuntimeFile $Root 'launch.id'
    if (-not [IO.File]::Exists($path) -or [IO.FileInfo]::new($path).Length -ne 33) { return $false }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ne 33) { return $false }
    for ($index=0; $index -lt 32; $index++) {
        if ($bytes[$index] -ne [byte][char]$Identifier[$index]) { return $false }
    }
    return $bytes[32] -eq 10
}

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

function Write-QueueAction {
    # A short-lived control process (a row click or Refresh) hands its request
    # to the running worker through this one file; only the worker, which owns
    # the tokens, talks to Spotify. A newer click replaces an unread one.
    param([string]$Root, [ValidateSet('refresh','play')][string]$Kind, [int]$Position = 0, [long]$Observed = 0)
    if ($Kind -eq 'play' -and ($Position -lt 1 -or $Position -gt 5 -or $Observed -lt 1)) { throw 'Invalid queue action.' }
    if ($Kind -eq 'refresh') { $Position = 0; $Observed = 0 }
    Write-QueueControlFile $Root 'action.request' ("PARALLAX_QUEUE_ACTION_V1|$Kind|$Position|$Observed|" + (Get-QueueUnixTime) + "`n")
}

function Read-QueueAction {
    # Consumes the pending request, if any. Anything malformed, or older than
    # 15 seconds (written before this worker started), is discarded unread.
    param([string]$Root, [long]$Now = (Get-QueueUnixTime))
    $path = Get-QueueRuntimeFile $Root 'action.request'
    if (-not [IO.File]::Exists($path)) { return $null }
    $text = ''
    try {
        if ([IO.FileInfo]::new($path).Length -le 128) { $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path)) }
    } finally { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
    if ($text -cnotmatch '\APARALLAX_QUEUE_ACTION_V1\|(refresh|play)\|([0-5])\|([0-9]{1,12})\|([0-9]{1,12})\n\z') { return $null }
    $action = [pscustomobject]@{ Kind=$Matches[1]; Position=[int]$Matches[2]; Observed=[long]$Matches[3]; Created=[long]$Matches[4] }
    if ($action.Created -gt $Now + 5 -or $action.Created -lt $Now - 15) { return $null }
    if ($action.Kind -eq 'play' -and ($action.Position -lt 1 -or $action.Observed -lt 1)) { return $null }
    if ($action.Kind -eq 'refresh' -and ($action.Position -ne 0 -or $action.Observed -ne 0)) { return $null }
    return $action
}

function Invoke-QueuePlay {
    # Skips the active player to queue row Position. The click names the
    # snapshot it was read from; the worker checks that it is still the one it
    # last published, reads the queue again and checks every row up to the
    # clicked one still matches, then skips that many times. Returns the notice
    # to show ('' when every skip succeeded); the caller refreshes the rows.
    param([string]$Root, [object]$Action, [object]$Last, [int]$GapMilliseconds = 250)
    if ($null -eq $Last -or $Last.Observed -ne $Action.Observed -or $Action.Position -gt $Last.Items.Count) { return 'queue_changed' }
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        if (-not $auth.Control) { return 'control_reauth' }
        $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        if ($response.StatusCode -eq 401) {
            $auth = Get-QueueAccessToken -DataRoot $Root -ForceRefresh -WithControl
            if (-not $auth.Control) { return 'control_reauth' }
            $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        }
        if ($response.StatusCode -ne 200) { return (Get-QueueControlDecision $response.StatusCode) }
        $current = (ConvertTo-QueueItems (ConvertFrom-QueueJson $response.Body)).Items
        if ($current.Count -lt $Action.Position) { return 'queue_changed' }
        for ($index = 0; $index -lt $Action.Position; $index++) {
            if ($current[$index].Title -cne $Last.Items[$index].Title -or $current[$index].Detail -cne $Last.Items[$index].Detail) { return 'queue_changed' }
        }
        for ($skip = 1; $skip -le $Action.Position; $skip++) {
            if ($skip -gt 1) { Start-Sleep -Milliseconds $GapMilliseconds }
            $notice = Get-QueueControlDecision (Invoke-QueueApiRequest -AccessToken $auth.Token -Endpoint Next).StatusCode
            if ($notice) { return $notice }
        }
        # Let the player settle before the refresh reads its new queue.
        Start-Sleep -Milliseconds (2 * $GapMilliseconds)
        return ''
    } catch {
        $state = [string]$_.Exception.Data['QueueState']
        if ($state -in @('reauth_required','forbidden')) { return 'control_reauth' }
        return 'control_failed'
    } finally { $auth = $null }
}

function Invoke-QueueCycle {
    param([string]$Root, [int]$Interval, [int]$FailureCount = 0, [AllowEmptyString()][string]$Notice = '')
    try {
        $auth = Get-QueueAccessToken -DataRoot $Root -WithControl
        $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        if ($response.StatusCode -eq 401) {
            # Exactly one forced refresh, then one GET retry. Never a consent loop.
            $auth = Get-QueueAccessToken -DataRoot $Root -ForceRefresh -WithControl
            $response = Invoke-QueueApiRequest -AccessToken $auth.Token
        }
        $control = [bool]$auth.Control
        $auth = $null
        $now = Get-QueueUnixTime
        $decision = Get-QueueResponseDecision -StatusCode $response.StatusCode -Body $response.Body -RetryAfter $response.RetryAfter -Now $now -FailureCount $FailureCount
        if ($decision.State -eq 'response_requires_validation') {
            try {
                $items = ConvertTo-QueueItems (ConvertFrom-QueueJson $response.Body)
                $lifetime = [Math]::Min(300, [Math]::Max(90, $Interval*2))
                $snapshot = New-QueueSnapshot -State ready -Items $items.Items -Now $now -LifetimeSeconds $lifetime -Control $control -Notice $Notice
                return [pscustomobject]@{ Snapshot=$snapshot; NextAt=($now+$Interval); Pause=$false; Success=$true }
            } catch {
                $decision = Get-QueueResponseDecision 204 -Now $now -FailureCount $FailureCount
            }
        }
    } catch { $decision = Get-QueueExceptionDecision $_.Exception $FailureCount }
    finally { $auth=$null }
    $snapshot = New-QueueSnapshot -State $decision.State -RetryNotBefore $decision.RetryNotBefore
    return [pscustomobject]@{ Snapshot=$snapshot; NextAt=$decision.RetryNotBefore; Pause=$decision.Pause; Success=$false }
}

function Start-QueueBackground {
    param([string]$Root, [int]$Interval, [switch]$RetryQuota)
    $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($script:ProviderPath.Contains('"') -or $Root.Contains('"')) { throw 'Unsupported helper path.' }
    # The controller owns the lifecycle mutex here. A later launch replaces this
    # permit, preventing a delayed child from applying obsolete cadence/flags.
    $identifier = New-QueueLaunchId $Root
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script:ProviderPath + '" -Command Run -Quiet -PollSeconds ' + $Interval + ' -LaunchId ' + $identifier + ' -DataRoot "' + $Root + '"'
    if ($RetryQuota) { $arguments += ' -ResumeAfterQuota' }
    # Bind the worker to the Rainmeter that asked for it (no lease from a shell),
    # and start it outside the skin folder so it cannot block an upgrade.
    $lease = Get-MediaOwnerLease
    if ($lease) { $arguments += ' -OwnerLease ' + $lease }
    $null = Start-Process -FilePath $hostPath -ArgumentList $arguments -WorkingDirectory $Root -WindowStyle Hidden -PassThru
}

function Invoke-QueueRun {
    param([string]$Root, [int]$Interval=30, [switch]$Single, [switch]$RetryQuota, [switch]$Silent, [string]$LaunchId = '', [string]$Lease = '')
    $owner = Open-MediaOwner $Lease
    if ($owner -is [bool]) { return }
    $control = New-QueueControlMutex $Root
    $controlOwned = $false
    $mutex = New-QueueRunMutex $Root
    $owned = $false
    try {
        # Match controller lock order. A delayed child must not enter the window
        # between clearing Stop and publishing the replacement launch permit.
        $controlOwned = Wait-QueueMutex $control 10000
        if (-not $controlOwned) { return }
        $owned = Wait-QueueMutex $mutex 0
        if (-not $owned) { if (-not $Silent) { Write-Output 'The queue helper is already running.' }; return }
        # A child may start after Stop/Disconnect has completed. Never erase its
        # stop barrier or overwrite the account action's resulting snapshot.
        if (Test-QueueStop $Root) { return }
        if ($LaunchId -and -not (Test-QueueLaunchId $Root $LaunchId)) { return }
        # Only bootstrap needs control ownership; Stop must be able to signal a
        # live worker during token refresh, HTTP requests and retry waits.
        $control.ReleaseMutex(); $controlOwned = $false
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
        # The last published ready snapshot (a click must name it) and the
        # outcome of a click to show with the next rows.
        $last = $null; $notice = ''
        # A request left from before this worker started is never acted on.
        $null = Read-QueueAction $Root -Now 0
        while (-not (Test-QueueStop $Root)) {
            $action = Read-QueueAction $Root
            if ($null -ne $action) {
                # Both need the current rows to be live: a failed read keeps
                # its backoff or server wait, and a click has nothing to name.
                if ($null -ne $last -and $failures -eq 0) {
                    if ($action.Kind -eq 'play') { $notice = Invoke-QueuePlay -Root $Root -Action $action -Last $last }
                    $next = Get-QueueUnixTime
                }
            }
            if ((Get-QueueUnixTime) -lt $next) {
                # The launching Rainmeter is gone. Exit without a 'stopped'
                # snapshot: resume intent is unchanged, and the next Rainmeter's
                # skin load starts a fresh worker.
                if (Wait-MediaOwnerExit $owner 1000) { return }
                continue
            }
            $result = Invoke-QueueCycle -Root $Root -Interval $Interval -FailureCount $failures -Notice $notice
            $notice = ''
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
                $last = $result.Snapshot
                $retryPath = Get-QueueRuntimeFile $Root 'queue.retry.json'
                if ([IO.File]::Exists($retryPath)) { [IO.File]::Delete($retryPath) }
            } else {
                $last = $null
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
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
        if ($owner) { $owner.Dispose() }
    }
}

function Invoke-QueueCommand {
    if ($Command -eq 'Help') { Show-QueueHelp; return }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 to run QueueProvider.ps1.' }
    if (-not $DataRoot) { $DataRoot = Get-QueueDataRoot }
    if ($Command -in @('Refresh','Play')) {
        # A click hands its request to the live worker and exits: no tokens, no
        # network, no directory creation or ACL change, and no lifecycle lock.
        $candidate = & (Get-Module -Name QueueAuth) { param($Path) Resolve-QueuePrivatePath $Path } $DataRoot
        if (-not [IO.Directory]::Exists($candidate) -or (Test-QueueStop $candidate)) { return }
        $mutex = New-QueueRunMutex $candidate
        try {
            # Acquired means no worker is running, so nothing would read it.
            if (Wait-QueueMutex $mutex 0) { $mutex.ReleaseMutex(); return }
        } finally { $mutex.Dispose() }
        if ($Command -eq 'Play') { Write-QueueAction $candidate play $Position $Observed }
        else { Write-QueueAction $candidate refresh }
        return
    }
    if ($Command -eq 'Resume') {
        # Reuse Auth's passive path validation without creating the directory or
        # modifying its ACL. Missing/disabled/malformed intent is a true no-op.
        $candidate = & (Get-Module -Name QueueAuth) { param($Path) Resolve-QueuePrivatePath $Path } $DataRoot
        if (-not (Test-QueueEnabledIntent $candidate) -or (Test-QueueStop $candidate)) { return }
    }
    $DataRoot = Initialize-QueuePrivateDirectory -DataRoot $DataRoot
    if ($Command -eq 'Run') {
        # Never keep the skin folder as the working directory: a live worker
        # would then stop Skin Installer moving Skins\Parallax on upgrade.
        [Environment]::CurrentDirectory = $DataRoot
        Set-Location -LiteralPath $DataRoot
        Invoke-QueueRun $DataRoot $PollSeconds -Single:$Once -RetryQuota:$ResumeAfterQuota -Silent:$Quiet -LaunchId $LaunchId -Lease $OwnerLease
        return
    }
    # Control ownership spans the launch, so Stop cannot finish between an
    # enabling command clearing its marker and requesting the child process.
    $control = New-QueueControlMutex $DataRoot
    $controlOwned = $false
    $mutex = New-QueueRunMutex $DataRoot
    $owned = $false
    try {
        $controlOwned = Wait-QueueMutex $control 10000
        if (-not $controlOwned) { throw 'Another queue lifecycle action is still running.' }
        if ($Command -in @('Start','Resume')) {
            if ($Command -eq 'Resume') {
                # No auth reads, token renewal, login, intent writes or stop-marker
                # clearing occur in this bootstrap. Run retains all retry gates.
                if (-not (Test-QueueEnabledIntent $DataRoot) -or (Test-QueueStop $DataRoot)) { return }
            } else {
                Set-QueueEnabledIntent $DataRoot $true
            }
            $owned = Wait-QueueMutex $mutex 0
            if (-not $owned) { return }
            if ($Command -eq 'Start') { Clear-QueueStop $DataRoot }
            # A fast child must not mistake this controller for a live worker.
            $mutex.ReleaseMutex(); $owned = $false
            Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:($Command -eq 'Start' -and $ResumeAfterQuota)
            return
        }
        # Account/configuration changes keep the existing bounded worker wait.
        # The stop marker is written first: even a failed intent save leaves a
        # durable veto that delayed Run/Resume cannot clear.
        Request-QueueStop $DataRoot
        Set-QueueEnabledIntent $DataRoot $false
        $startAfterLogin = $false
        try {
            $owned = Wait-QueueMutex $mutex 40000
            if (-not $owned) { throw 'The queue helper is busy. Stop it and try again.' }
            if ($Command -eq 'Stop') { Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State stopped); return }
            if ($Command -eq 'Restart') {
                # Stop is observed before the replacement requests its mutex.
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
            if ($owned) { $mutex.ReleaseMutex(); $owned = $false }
        }
        if ($startAfterLogin) {
            Set-QueueEnabledIntent $DataRoot $true
            Clear-QueueStop $DataRoot
            Start-QueueBackground $DataRoot $PollSeconds -RetryQuota:$ResumeAfterQuota
            if (-not $Quiet) {
                if ($Command -eq 'Restart') { Write-Output 'The queue helper is restarting with the selected interval.' }
                else { Write-Output 'Spotify authorization saved. The queue helper is starting in the background.' }
            }
        }
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }
        $control.Dispose()
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
