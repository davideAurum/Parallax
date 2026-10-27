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
$script:endpoints = [Collections.Generic.List[string]]::new()
$script:verifyWorkerLocks = $false
function Reset-Transport {
    param([object[]]$Replies = @())
    $script:responses = $Replies; $script:apiCalls=0; $script:tokenCalls=0; $script:refreshCalls=0
    $script:tokenFailure=''; $script:tokenWait=0L; $script:stopOnResponse=''
    $script:tokenControl=$true; $script:endpoints=[Collections.Generic.List[string]]::new()
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
    if ($WithControl) { return [pscustomobject]@{ Token='SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'; Control=$script:tokenControl } }
    return 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'
}
function Invoke-QueueApiRequest {
    param([string]$AccessToken,[string]$Endpoint='Queue')
    $script:endpoints.Add($Endpoint)
    Assert-Check ($AccessToken -ceq 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL') 'Unexpected synthetic token'
    if ($script:apiCalls -ge $script:responses.Count) { throw 'Unexpected synthetic request' }
    $response = $script:responses[$script:apiCalls]; $script:apiCalls++
    if ($script:stopOnResponse) { Request-QueueStop $script:stopOnResponse }
    return $response
}
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

Reset-Transport @((Reply 401),(Reply))
$cycle = Invoke-QueueCycle $root 30
Assert-Check ($cycle.Success -and $script:apiCalls -eq 2 -and $script:refreshCalls -eq 1) '401 gets exactly one forced refresh and retry'

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
$notice = Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0
Assert-Check ($notice -ceq '' -and ($script:endpoints -join ',') -ceq 'Queue,Next,Next') 'Row 2 re-reads the queue, then skips exactly twice'
$changed = '{"currently_playing":null,"queue":[' + (Synthetic-Track 'two') + ',' + (Synthetic-Track 'three') + ']}'
Reset-Transport @(Reply 200 $changed)
$notice = Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0
Assert-Check ($notice -ceq 'queue_changed' -and ($script:endpoints -join ',') -ceq 'Queue') 'A queue that moved since the click never skips'
Reset-Transport @()
$stale = [pscustomobject]@{ Kind='play'; Position=2; Observed=($last.Observed - 1); Created=0 }
$notice = Invoke-QueuePlay -Root $root -Action $stale -Last $last -GapMilliseconds 0
Assert-Check ($notice -ceq 'queue_changed' -and $script:tokenCalls -eq 0 -and $script:apiCalls -eq 0) 'A click on an older snapshot does no token or network work'
$beyond = [pscustomobject]@{ Kind='play'; Position=4; Observed=$last.Observed; Created=0 }
Assert-Check ((Invoke-QueuePlay -Root $root -Action $beyond -Last $last -GapMilliseconds 0) -ceq 'queue_changed' -and $script:apiCalls -eq 0) 'A row past the snapshot is refused'
Reset-Transport @(); $script:tokenControl = $false
$notice = Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0
Assert-Check ($notice -ceq 'control_reauth' -and $script:apiCalls -eq 0) 'A read-only grant asks for sign-in and never skips'
Reset-Transport @((Reply 200 $queueBody),(Reply 404 ''))
$notice = Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0
Assert-Check ($notice -ceq 'no_device' -and ($script:endpoints -join ',') -ceq 'Queue,Next') 'No active device stops at the first skip'
Reset-Transport @((Reply 200 $queueBody),(Reply 204 ''),(Reply 403 ''))
Assert-Check ((Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0) -ceq 'control_denied') 'A refused second skip is reported'
Reset-Transport @(); $script:tokenFailure = 'reauth_required'
Assert-Check ((Invoke-QueuePlay -Root $root -Action $play -Last $last -GapMilliseconds 0) -ceq 'control_reauth') 'An expired grant asks for sign-in'
Reset-Transport @()

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
# A click left from before this worker started is discarded, never acted on.
Write-QueueAction $root play 1 1
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=ready' -and $script:apiCalls -eq 1) 'One-shot publishes validated snapshot'
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
Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State ready -Items @([pscustomobject]@{Title='SYNTHETIC_PRIVATE_TITLE';Detail='Fixture'}))
$Command='Disconnect'; Invoke-QueueCommand
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'tokens.dpapi'))) 'Disconnect removes token file'
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
