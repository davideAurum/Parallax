# Developer-only synthetic lifecycle tests. No Spotify requests or browser launch.
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\QueueProvider.ps1'))
. $provider -Command Help
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
function Reset-Transport {
    param([object[]]$Replies = @())
    $script:responses = $Replies; $script:apiCalls=0; $script:tokenCalls=0; $script:refreshCalls=0
    $script:tokenFailure=''; $script:tokenWait=0L; $script:stopOnResponse=''
}
function Get-QueueAccessToken {
    param([string]$DataRoot,[switch]$ForceRefresh)
    $script:tokenCalls++; if ($ForceRefresh) { $script:refreshCalls++ }
    if ($script:tokenFailure) {
        $errorRecord = [InvalidOperationException]::new('Synthetic failure')
        $errorRecord.Data['QueueState']=$script:tokenFailure
        $errorRecord.Data['RetryAfterSeconds']=$script:tokenWait
        throw $errorRecord
    }
    return 'SYNTHETIC_ACCESS_NOT_A_REAL_CREDENTIAL'
}
function Invoke-QueueApiRequest {
    param([string]$AccessToken)
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
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=ready' -and $script:apiCalls -eq 1) 'One-shot publishes validated snapshot'
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
Reset-Transport @(Reply 429 '{}' '3600'); $script:stopOnResponse=$root
Invoke-QueueRun $root -Single -Silent
Assert-Check ((Read-Snapshot $root) -match 'state=stopped' -and (Get-QueueRetry $root).RetryNotBefore -gt (Get-QueueUnixTime)+3598) 'Stop during429 retains server retry barrier'
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
$script:connectCalls=0; $script:launchCalls=0; $script:connectFailure=''
function Connect-QueueSpotify {
    param([string]$DataRoot)
    $script:connectCalls++
    if ($script:connectFailure) { $ex=[InvalidOperationException]::new('Synthetic'); $ex.Data['QueueState']=$script:connectFailure; $ex.Data['RetryAfterSeconds']=1800L; throw $ex }
}
function Start-QueueBackground { param([string]$Root,[int]$Interval,[switch]$RetryQuota); $script:launchCalls++; $script:lastLaunchInterval=$Interval; $script:lastLaunchRoot=$Root; $script:lastLaunchQuota=[bool]$RetryQuota }
$Command='Connect'; $ClientId=''; $script:connectFailure='rate_limited'
Invoke-QueueCommand
Assert-Check ((Get-QueueRetry $DataRoot).State -eq 'rate_limited' -and $script:launchCalls -eq 0) 'Connect failure persists wait and launches no worker'
$script:connectFailure=''; Invoke-QueueCommand
Assert-Check ($script:connectCalls -eq 1 -and $script:launchCalls -eq 0) 'Repeated connect preserves wait'
Set-QueueRetry $DataRoot ([pscustomobject]@{State='rate_limited';RetryNotBefore=1L;Pause=$false})
Invoke-QueueCommand
Assert-Check ($script:connectCalls -eq 2 -and $script:launchCalls -eq 1) 'Completed consent launches one worker'
[IO.File]::WriteAllText((Join-Path $DataRoot 'tokens.dpapi'),'SYNTHETIC_ENCRYPTED_FILE_FIXTURE')
Publish-QueueSnapshot $DataRoot (New-QueueSnapshot -State ready -Items @([pscustomobject]@{Title='SYNTHETIC_PRIVATE_TITLE';Detail='Fixture'}))
$Command='Disconnect'; Invoke-QueueCommand
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'tokens.dpapi'))) 'Disconnect removes token file'
Assert-Check ((Read-Snapshot $DataRoot) -match 'state=onboarding_required' -and (Read-Snapshot $DataRoot) -match 'count=0' -and (Read-Snapshot $DataRoot) -notmatch '53594E5448455449435F505249564154455F5449544C45') 'Disconnect removes queue metadata'
Assert-Check ((Get-QueueClientId $DataRoot) -eq '00000000000000000000000000000001') 'Disconnect retains public app configuration'
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

$report=[ordered]@{assertions=$script:checks;runtime=$PSVersionTable.PSVersion.ToString();provider_sha256=(Get-FileHash $provider -Algorithm SHA256).Hash;synthetic=$true;live_network=$false}
$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'results.json') -Encoding UTF8
Write-Output ('Queue provider: '+$script:checks+' synthetic assertions passed. Evidence: '+$runRoot)
