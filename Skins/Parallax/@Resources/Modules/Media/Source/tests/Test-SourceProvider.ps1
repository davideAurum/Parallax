# Developer-only synthetic observer checks. Never reads native media sessions.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SourceProvider.ps1'))
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-test-'+[Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $runRoot) { throw 'Test directory must be fresh.' }
$script:SourceTestChecks = 0
$script:SourceTestTimings = @()
function Assert-Test([bool]$Condition,[string]$Message) {
    $script:SourceTestChecks++
    if (-not $Condition) { throw $Message }
}
function Assert-Throws([scriptblock]$Action,[string]$Message) {
    $thrown=$false; try { $null=& $Action } catch { $thrown=$true }
    Assert-Test $thrown $Message
}

# Dot-sourcing defines functions without output, storage, collection or launch.
$loadOutput = @(. $sourcePath)
Assert-Test ($loadOutput.Count -eq 0) 'Dot-source produced output.'
Assert-Test (-not (Test-Path -LiteralPath $runRoot)) 'Dot-source created test storage.'
Assert-Test ($null -eq $script:SourceManager -and $null -eq $script:SourceAsTask -and $null -eq $script:SourceAdapter) 'Dot-source initialized native collection.'

# Every Start/Resume launch is intercepted, including negative startup checks.
# No child process or native observer can be launched by this suite.
$script:SourceTestLaunches=@()
$script:SourceCheckControlLock=$false
function Start-Process {
    [CmdletBinding()]param($FilePath,$ArgumentList,$WorkingDirectory,$WindowStyle)
    Assert-Test ($WorkingDirectory -eq $root) 'Worker must start in its private storage, never the skin folder.'
    if ($script:SourceCheckControlLock) {
        $controlName=(Get-SourceMutexName $root)+'.Control'
        Assert-Test (-not [ParallaxSourceTestMutexHolder]::CanAcquireOnOtherThread($controlName)) 'Concurrent lifecycle action could enter during observer launch.'
    }
    $script:SourceTestLaunches+=@{File=$FilePath;Arguments=$ArgumentList;Style=$WindowStyle}
}
Invoke-SourceCommand 'Resume' $runRoot
Assert-Test (-not (Test-Path -LiteralPath $runRoot)) 'Resume created storage without prior opt-in.'
Assert-Test ($script:SourceTestLaunches.Count -eq 0) 'Resume launched without prior opt-in.'

$root = Initialize-SourceStorage $runRoot
Assert-Test ($root -eq $runRoot) 'Private test root was changed.'
$security = [IO.Directory]::GetAccessControl($root)
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$rules = @($security.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
Assert-Test $security.AreAccessRulesProtected 'Private directory inherits external rules.'
Assert-Test ($security.GetOwner([Security.Principal.SecurityIdentifier]).Value -eq $sid.Value) 'Private directory has wrong owner.'
Assert-Test ($rules.Count -eq 1 -and $rules[0].IdentityReference.Value -eq $sid.Value -and $rules[0].AccessControlType -eq 'Allow') 'Private directory permits other identities.'
foreach ($bad in @('.', 'C:\', [IO.Path]::GetTempPath(), '\\server\share\Source', 'C:\Users\Public\Source',
    (Join-Path $root 'Skins\Source'), (Join-Path $root 'bad:stream'), (Join-Path $root 'bad"path'))) {
    Assert-Throws { Resolve-SourceDataRoot $bad } 'Unsafe storage path was accepted.'
}
$ancestorFile = Join-Path $root 'file-ancestor'
[IO.File]::WriteAllText($ancestorFile,'synthetic')
Assert-Throws { Resolve-SourceDataRoot (Join-Path $ancestorFile 'child') } 'File accepted as directory ancestor.'
$junctionTarget=Join-Path $root 'junction-target'
$junction=Join-Path $root 'junction'
$null=New-Item -ItemType Directory -Path $junctionTarget
$null=New-Item -ItemType Junction -Path $junction -Target $junctionTarget
Assert-Throws { Resolve-SourceDataRoot $junction } 'Reparse directory was accepted as storage.'
Assert-Throws { Resolve-SourceDataRoot (Join-Path $junction 'nested') } 'Reparse ancestor was accepted as storage.'

foreach ($known in @('Spotify.exe','spotify.EXE','Spotify','SPOTIFY','SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify')) {
    Assert-Test ((Get-SourceKind $known) -eq 'spotify') 'Known Spotify app ID was not recognized.'
}
foreach ($other in @('', 'NotSpotify.exe', 'Fake.Spotify', 'Spotify.exe.evil', ' Spotify', 'Spotify ',
    'C:\Apps\Spotify.exe', 'SpotifyAB.SpotifyMusic_fake!Spotify', 'chrome.exe')) {
    Assert-Test ((Get-SourceKind $other) -eq 'other') 'Substring or unrelated app ID was called Spotify.'
}

function New-TestAdapter {
    param([int]$Count=2)
    $state = [pscustomobject]@{Sessions=@(); Enumerations=0; Reads=0; Mode='stable'; Elapsed=0}
    for ($index=0;$index -lt $Count;$index++) {
        $state.Sessions += [pscustomobject]@{Index=$index; AppId=$(if($index -eq 0){'Spotify.exe'}else{'SyntheticOther'});
            Title=('Synthetic title '+$index); Artist=('Synthetic artist '+$index); Playing=($index%2)}
    }
    $getSessions = {
        param($Remaining)
        $state.Enumerations++
        if ($state.Mode -eq 'enumerationFailure') { throw 'Synthetic enumeration failure' }
        if ($state.Mode -eq 'lateEnumeration') { $state.Elapsed=4000 }
        if ($state.Mode -eq 'listChanged' -and $state.Enumerations -gt 1) { return @() }
        if ($state.Mode -eq 'identityChanged' -and $state.Enumerations -gt 1) { return [pscustomobject]@{Index=0} }
        foreach($session in $state.Sessions) { $session }
    }.GetNewClosure()
    $read = {
        param($Session,$Remaining)
        $state.Reads++
        if ($state.Mode -eq 'readFailure') { throw 'Synthetic read failure' }
        if ($state.Mode -eq 'partialFailure' -and $state.Reads -eq 2) { throw 'Synthetic second-session failure' }
        if ($state.Mode -eq 'lateRead') { $state.Elapsed=4000 }
        $title=$Session.Title
        $artist=$Session.Artist
        $appId=$Session.AppId
        $playing=$Session.Playing
        if ($state.Mode -eq 'titleChanged' -and $state.Reads -gt $state.Sessions.Count) { $title += ' changed' }
        if ($state.Mode -eq 'artistChanged' -and $state.Reads -gt $state.Sessions.Count) { $artist += ' changed' }
        if ($state.Mode -eq 'appChanged' -and $state.Reads -gt $state.Sessions.Count) { $appId += ' changed' }
        if ($state.Mode -eq 'stateChanged' -and $state.Reads -gt $state.Sessions.Count) { $playing=1-$playing }
        [pscustomobject]@{AppId=$appId;Title=$title;Artist=$artist;Playing=$playing}
    }.GetNewClosure()
    [pscustomobject]@{State=$state; Adapter=[pscustomobject]@{GetSessions=$getSessions;Read=$read};
        Clock={ $state.Elapsed }.GetNewClosure()}
}

foreach ($count in @(0,1,2,16)) {
    $fixture=New-TestAdapter $count
    $snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
    Assert-Test ($snapshot.State -eq 'ready' -and @($snapshot.Records).Count -eq $count) 'Complete synthetic session list did not produce ready snapshot.'
    Assert-Test ($snapshot.Observed -eq 1000 -and $snapshot.ValidUntil -eq 1006) 'Observation timestamp or six-second lifetime changed.'
    Assert-Test ($fixture.State.Enumerations -eq 3 -and $fixture.State.Reads -eq (2*$count)) 'Collection did not check all sessions twice.'
    $text=ConvertTo-SourceSnapshotText $snapshot
    Assert-Test ($text.StartsWith("PARALLAX_SOURCE_V1`nstate=ready`nobserved=1000`nvalid_until=1006`ncount=$count`n")) 'Protocol header or ordering changed.'
    Assert-Test ($text -notmatch 'AppId|SyntheticOther|Spotify.exe') 'Source app identifiers escaped into snapshot.'
    Assert-Test (($text -split "`n").Count -eq (6+4*$count)) 'Protocol has unexpected record lines.'
    if ($count -ge 2) {
        Assert-Test ($snapshot.Records[0].Source -eq 'spotify' -and $snapshot.Records[1].Source -eq 'other') 'Non-Spotify sessions were filtered or mislabeled.'
        Assert-Test ($text -match '(?m)^playing1=0$' -and $text -match '(?m)^playing2=1$') 'Playing flags were changed.'
    }
}
foreach ($mode in @('enumerationFailure','lateEnumeration','listChanged','identityChanged','readFailure','lateRead',
    'titleChanged','artistChanged','appChanged','stateChanged')) {
    $fixture=New-TestAdapter 1; $fixture.State.Mode=$mode
    $snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
    Assert-Test ($snapshot.State -eq 'unavailable' -and @($snapshot.Records).Count -eq 0) 'Incomplete or changing collection did not fail closed.'
}
$fixture=New-TestAdapter 17
$snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
Assert-Test ($snapshot.State -eq 'unavailable' -and $fixture.State.Reads -eq 0) 'Excess session count did not stop collection before reading metadata.'
$fixture=New-TestAdapter 2; $fixture.State.Mode='partialFailure'
$snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
Assert-Test ($snapshot.State -eq 'unavailable' -and @($snapshot.Records).Count -eq 0) 'Partial metadata failure published an incomplete session list.'
foreach ($elapsed in @(4000,4001,-1,[double]::NaN,[double]::PositiveInfinity)) {
    $fixture=New-TestAdapter 1; $fixture.State.Elapsed=$elapsed
    Assert-Test ((Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock).State -eq 'unavailable') 'Invalid deadline was accepted.'
}
$fixture=New-TestAdapter 2
$fixture.State.Sessions[1].Title=$fixture.State.Sessions[0].Title
$fixture.State.Sessions[1].Artist=$fixture.State.Sessions[0].Artist
$snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
Assert-Test ($snapshot.State -eq 'ready' -and @($snapshot.Records).Count -eq 2) 'Duplicate metadata must remain available for reader ambiguity detection.'
foreach ($bad in @(('x'*1025), ([string][char]0xD800))) {
    $fixture=New-TestAdapter 1; $fixture.State.Sessions[0].Title=$bad
    Assert-Test ((Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock).State -eq 'unavailable') 'Oversized or malformed Unicode metadata was accepted.'
}
$fixture=New-TestAdapter 1
$fixture.State.Sessions[0].Title=([string][char]0x00E9)*512
$fixture.State.Sessions[0].Artist="Synthetic #Scale# [!Quit] %1`n"
$snapshot=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
Assert-Test ($snapshot.State -eq 'ready') 'Valid 1024-byte UTF-8 boundary failed.'
$text=ConvertTo-SourceSnapshotText $snapshot
Assert-Test ($text -notmatch '[^\x00-\x7F]' -and $text -notmatch '\[!Quit\]|#Scale#|%1') 'Metadata did not remain inert ASCII hexadecimal.'
Assert-Test ($text -match ('title1='+('C3A9'*512))) 'Unicode hexadecimal encoding was changed.'
Assert-Throws { ConvertTo-SourceHex ('x'*1025) } 'Hex encoder permits oversized text.'
Assert-Throws { ConvertTo-SourceHex ([string][char]0xD800) } 'Hex encoder permits invalid UTF-16.'
Assert-Throws { ConvertTo-SourceHex ("Synthetic"+[char]0+"title") } 'Hex encoder permits NUL metadata.'
$fixture=New-TestAdapter 1
$fixture.State.Sessions[0].Artist="Synthetic"+[char]0+"artist"
Assert-Test ((Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock).State -eq 'unavailable') 'NUL metadata did not invalidate the complete collection.'

# Without an injected adapter, collection builds the native adapter once per
# process and reuses it; a failed build is not cached and is retried next cycle.
# A synthetic factory stands in for the WinRT adapter.
$savedAdapterFactory=(Get-Item Function:\New-SourceNativeAdapter).ScriptBlock
$factoryState=[pscustomobject]@{Builds=0; Failures=1}
$factoryFixture=New-TestAdapter 1
function New-SourceNativeAdapter {
    $factoryState.Builds++
    if ($factoryState.Failures -gt 0) { $factoryState.Failures--; throw 'Synthetic adapter build failure' }
    $factoryFixture.Adapter
}
try {
    Assert-Test ((Get-SourceCollection -Observed 1000 -Elapsed $factoryFixture.Clock).State -eq 'unavailable') 'Failed adapter build did not fail closed.'
    Assert-Test ($null -eq $script:SourceAdapter) 'Failed adapter build was cached.'
    foreach ($attempt in 1..3) {
        Assert-Test ((Get-SourceCollection -Observed 1000 -Elapsed $factoryFixture.Clock).State -eq 'ready') 'Cached adapter did not collect.'
    }
    Assert-Test ($factoryState.Builds -eq 2) "Adapter was built $($factoryState.Builds) times for four collections."
    Assert-Test ($factoryFixture.State.Enumerations -eq 9 -and $factoryFixture.State.Reads -eq 6) 'Reused adapter skipped session consistency checks.'
} finally { Set-Item Function:\New-SourceNativeAdapter $savedAdapterFactory; $script:SourceAdapter=$null }

foreach ($state in @('unavailable','stopped')) {
    $text=ConvertTo-SourceSnapshotText (New-SourceSnapshot $state)
    Assert-Test ($text -eq "PARALLAX_SOURCE_V1`nstate=$state`nobserved=0`nvalid_until=0`ncount=0`n") 'Nonready protocol is not empty.'
}
$fixture=New-TestAdapter 1
$ready=Get-SourceCollection -Adapter $fixture.Adapter -Observed 1000 -Elapsed $fixture.Clock
Publish-SourceSnapshot $root $ready
$destination=Join-Path $root 'source.snapshot'
Assert-Test ([IO.File]::ReadAllText($destination) -eq (ConvertTo-SourceSnapshotText $ready)) 'Atomic initial snapshot differs from validated protocol.'
Publish-SourceSnapshot $root (New-SourceSnapshot 'unavailable')
Assert-Test ([IO.File]::ReadAllText($destination) -eq (ConvertTo-SourceSnapshotText (New-SourceSnapshot 'unavailable'))) 'Atomic replacement did not remove old metadata.'
Assert-Test (@(Get-ChildItem -LiteralPath $root -Filter '*.tmp').Count -eq 0) 'Atomic write left temporary files.'
$fileSecurity=[IO.File]::GetAccessControl($destination)
$fileRules=@($fileSecurity.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
Assert-Test ($fileSecurity.AreAccessRulesProtected -and $fileRules.Count -eq 1 -and $fileRules[0].IdentityReference.Value -eq $sid.Value) 'Snapshot permissions allow other identities.'
Assert-Throws { Write-SourceAtomicFile $root 'source.snapshot' ([string][char]0x00E9) } 'Atomic writer permits non-ASCII protocol.'
Assert-Throws { Write-SourceAtomicFile $root 'source.snapshot' ('x'*131073) } 'Atomic writer permits oversized protocol.'

# The root string is validated once, but every write still rechecks the whole
# directory chain: a junction swapped in after validation is never written through.
$swapParent=Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-swap-'+[Guid]::NewGuid().ToString('N'))
$swapRoot=Initialize-SourceStorage (Join-Path $swapParent 'Source')
Publish-SourceSnapshot $swapRoot (New-SourceSnapshot 'unavailable')
Assert-Test ($script:SourceRootInput -eq $swapRoot) 'Validated root was not cached for later writes.'
$swapMoved=$swapParent+'-moved'
[IO.Directory]::Move($swapParent,$swapMoved)
$null=New-Item -ItemType Junction -Path $swapParent -Target $swapMoved
try {
    Assert-Throws { Publish-SourceSnapshot $swapRoot (New-SourceSnapshot 'stopped') } 'Snapshot write followed a junction swapped into a validated root.'
    Assert-Throws { Write-SourceAtomicFile $swapRoot 'stop.request' "stop`n" } 'Stop write followed a junction swapped into a validated root.'
    Assert-Throws { Set-SourceEnabledIntent $swapRoot $true } 'Intent write followed a junction swapped into a validated root.'
    $swapTarget=Join-Path $swapMoved 'Source'
    Assert-Test ([IO.File]::ReadAllText((Join-Path $swapTarget 'source.snapshot')) -match '(?m)^state=unavailable$') 'Junction target snapshot was replaced.'
    Assert-Test (-not [IO.File]::Exists((Join-Path $swapTarget 'stop.request')) -and -not [IO.File]::Exists((Join-Path $swapTarget 'enabled.intent'))) 'Junction target received lifecycle files.'
    Assert-Test (@(Get-ChildItem -LiteralPath $swapTarget -Filter '*.tmp').Count -eq 0) 'Rejected writes left temporary files behind the junction.'
} finally { [IO.Directory]::Delete($swapParent) }
# Any entry named stop.request is a Stop for the plain existence check, so a
# directory there ends a worker before it collects instead of being ignored.
$dirStopRoot=Initialize-SourceStorage (Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-dirstop-'+[Guid]::NewGuid().ToString('N')))
$null=[IO.Directory]::CreateDirectory((Join-Path $dirStopRoot 'stop.request'))
Assert-Test (Test-SourceStop $dirStopRoot) 'A directory named stop.request was not treated as Stop.'
$dirStopCalls=[pscustomobject]@{Count=0}
Assert-Test (Invoke-SourceRun $dirStopRoot { $dirStopCalls.Count++; New-SourceSnapshot 'unavailable' }.GetNewClosure()) 'Worker did not exit cleanly on a directory stop marker.'
Assert-Test ($dirStopCalls.Count -eq 0) 'Worker collected despite a directory stop marker.'
Assert-Throws { Write-SourceAtomicFile $dirStopRoot 'stop.request' "stop`n" } 'Stop writer replaced a directory.'

# The worker waits once per cycle on the owner process and a named stop event.
# A second runspace in this process plays the other side (Stop, a stray event),
# so the worker below runs the real Invoke-SourceRun on this thread.
$waitRoot=Initialize-SourceStorage (Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-wait-'+[Guid]::NewGuid().ToString('N')))
function Start-SourceTestPeer {
    param([int[]]$StrayAtMs,[int]$StopAtMs)
    $ready=New-Object Threading.ManualResetEvent($false)
    $peer=[PowerShell]::Create()
    $null=$peer.AddScript({
        param($SourcePath,$Root,$StrayAtMs,$StopAtMs,$Ready)
        . $SourcePath
        # Times count from the moment the worker is released, not from load.
        $null=$Ready.Set()
        $clock=[Diagnostics.Stopwatch]::StartNew()
        foreach ($at in $StrayAtMs) {
            Start-Sleep -Milliseconds ([Math]::Max(0,$at-$clock.ElapsedMilliseconds))
            Send-SourceStopSignal $Root
        }
        Start-Sleep -Milliseconds ([Math]::Max(0,$StopAtMs-$clock.ElapsedMilliseconds))
        $stopAt=[Diagnostics.Stopwatch]::GetTimestamp()
        Stop-SourceObserver $Root
        $stopAt
    }).AddArgument($sourcePath).AddArgument($waitRoot).AddArgument($StrayAtMs).AddArgument($StopAtMs).AddArgument($ready)
    $result=$peer.BeginInvoke()
    if (-not $ready.WaitOne(30000)) { throw 'Synthetic Stop peer did not load.' }
    $ready.Dispose()
    [pscustomobject]@{Shell=$peer; Result=$result}
}
function Complete-SourceTestPeer {
    param($Peer)
    try { $output=@($Peer.Shell.EndInvoke($Peer.Result)) } finally { $Peer.Shell.Dispose() }
    Assert-Test ($output.Count -eq 1) 'Synthetic Stop peer failed.'
    return [long]$output[0]
}
$waitState=[pscustomobject]@{Calls=0; Started=@()}
$waitCollector={ $waitState.Calls++; $waitState.Started+=[Diagnostics.Stopwatch]::GetTimestamp(); New-SourceSnapshot 'unavailable' }.GetNewClosure()
$toMs=1000.0/[Diagnostics.Stopwatch]::Frequency
# Stop arrives 300 ms into the first wait. The old 100 ms poll saw it within a
# slice; a timer-only wait would take the remaining ~1.7 s; the event wakes at once.
$peer=Start-SourceTestPeer @() 300
Assert-Test (Invoke-SourceRun $waitRoot $waitCollector) 'Event-woken worker did not exit cleanly.'
$returnedAt=[Diagnostics.Stopwatch]::GetTimestamp()
$stopAt=Complete-SourceTestPeer $peer
$stopLatency=($returnedAt-$stopAt)*$toMs
Assert-Test ($stopLatency -ge 0 -and $stopLatency -lt 1000) "Stop took $([Math]::Round($stopLatency)) ms to end a waiting worker."
$script:SourceTestTimings+=('Stop to worker exit: {0:N0} ms' -f $stopLatency)
Assert-Test ($waitState.Calls -eq 1) 'Stop during the wait allowed another collection.'
Assert-Test ([IO.File]::ReadAllText((Join-Path $waitRoot 'source.snapshot')) -match '(?m)^state=stopped$') 'Event-woken worker did not leave the stopped display.'
# A stray event without the marker (any process in the session can set it)
# neither stops the worker nor starts an early collection.
[IO.File]::Delete((Join-Path $waitRoot 'stop.request'))
$waitState.Calls=0; $waitState.Started=@()
$peer=Start-SourceTestPeer @(300,600) 2600
Assert-Test (Invoke-SourceRun $waitRoot $waitCollector) 'Worker woken by stray events did not exit cleanly.'
$returnedAt=[Diagnostics.Stopwatch]::GetTimestamp()
$stopAt=Complete-SourceTestPeer $peer
$stopLatency=($returnedAt-$stopAt)*$toMs
Assert-Test ($waitState.Calls -eq 2) "Stray stop events changed the two-second cycle ($($waitState.Calls) collections in 2.6 s)."
$cycleMs=($waitState.Started[1]-$waitState.Started[0])*$toMs
Assert-Test ($cycleMs -ge 1990 -and $cycleMs -lt 2600) "Collection cycle was $([Math]::Round($cycleMs)) ms after stray events."
Assert-Test ($stopLatency -ge 0 -and $stopLatency -lt 1000) "Stop after stray events took $([Math]::Round($stopLatency)) ms."
$script:SourceTestTimings+=('Cycle with two stray events: {0:N0} ms; then Stop to exit: {1:N0} ms' -f $cycleMs,$stopLatency)
# Owner exit stays immediate: a short-lived stand-in process is the lease owner.
[IO.File]::Delete((Join-Path $waitRoot 'stop.request'))
$sleeperInfo=New-Object Diagnostics.ProcessStartInfo((Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'),'-NoLogo -NoProfile -NonInteractive -Command Start-Sleep -Milliseconds 2500')
$sleeperInfo.UseShellExecute=$false; $sleeperInfo.CreateNoWindow=$true
$sleeper=[Diagnostics.Process]::Start($sleeperInfo)
try {
    $lease='{0}:{1}' -f $sleeper.Id,$sleeper.StartTime.ToUniversalTime().Ticks
    Assert-Test (Test-MediaOwnerLeaseText $lease) 'Stand-in owner lease is malformed.'
    $waitState.Calls=0
    Assert-Test (Invoke-SourceRun $waitRoot $waitCollector -Lease $lease) 'Leased worker did not exit when its owner did.'
    $returnedUtc=[DateTime]::UtcNow
    Assert-Test ($sleeper.WaitForExit(5000)) 'Stand-in owner did not exit.'
    $ownerLatency=($returnedUtc-$sleeper.ExitTime.ToUniversalTime()).TotalMilliseconds
    Assert-Test ($ownerLatency -gt -50 -and $ownerLatency -lt 500) "Worker left $([Math]::Round($ownerLatency)) ms after its owner exited."
    $script:SourceTestTimings+=('Owner exit to worker exit: {0:N0} ms' -f $ownerLatency)
    Assert-Test ($waitState.Calls -ge 1) 'Leased worker never collected.'
    Assert-Test ([IO.File]::ReadAllText((Join-Path $waitRoot 'source.snapshot')) -match '(?m)^state=unavailable$') 'Owner exit published a stopped snapshot.'
    Assert-Test (-not (Test-SourceStop $waitRoot)) 'Owner exit wrote a stop marker.'
} finally { if (-not $sleeper.HasExited) { $sleeper.Kill() }; $sleeper.Dispose() }
# Fallbacks: without any handle the wait is a plain timed wait; an owner whose
# handle cannot be waited on keeps the bounded owner wait and never spins.
$waiter=New-SourceWaiter $null $null
$fallbackClock=[Diagnostics.Stopwatch]::StartNew()
Assert-Test ((Wait-SourceSignal $waiter 150) -eq 'timeout' -and $fallbackClock.ElapsedMilliseconds -ge 140) 'Handle-less wait did not wait out its time.'
$waiter=New-SourceWaiter ([pscustomobject]@{Name='not a process'}) $null
Assert-Test ($waiter.PollOwner -and (Wait-SourceSignal $waiter 150) -eq 'owner') 'Unwaitable owner did not fall back to the bounded owner wait.'

# ACLs: the private directory's ACL is set by Initialize-SourceStorage. A
# snapshot gets an explicit private ACL only when first created; File.Replace
# keeps it. The lifecycle vetoes keep their explicit ACL on every write.
$aclRoot=Initialize-SourceStorage (Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-acl-'+[Guid]::NewGuid().ToString('N')))
$savedPrivate=(Get-Item Function:\Set-SourcePrivateFile).ScriptBlock
$aclState=[pscustomobject]@{Calls=@()}
function Set-SourcePrivateFile { param([string]$Path) $aclState.Calls+=[IO.Path]::GetFileName($Path); & $savedPrivate $Path }
function Test-SourcePrivateFile([string]$Path) {
    $fileSecurity=[IO.File]::GetAccessControl($Path)
    $fileRules=@($fileSecurity.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    return ($fileSecurity.AreAccessRulesProtected -and $fileRules.Count -eq 1 -and $fileRules[0].IdentityReference.Value -eq $sid.Value -and
        $fileRules[0].AccessControlType -eq 'Allow' -and -not $fileRules[0].IsInherited)
}
try {
    $aclSnapshot=Join-Path $aclRoot 'source.snapshot'
    Publish-SourceSnapshot $aclRoot (New-SourceSnapshot 'unavailable')
    Assert-Test ($aclState.Calls.Count -eq 1 -and $aclState.Calls[0] -like 'source.snapshot.*.tmp') 'First snapshot creation did not get one explicit private ACL.'
    foreach ($state in @('stopped','unavailable','stopped')) { Publish-SourceSnapshot $aclRoot (New-SourceSnapshot $state) }
    Assert-Test ($aclState.Calls.Count -eq 1) "Routine snapshot replacements made $($aclState.Calls.Count - 1) ACL calls."
    Assert-Test (Test-SourcePrivateFile $aclSnapshot) 'Replaced snapshot lost its protected user-only ACL.'
    # A snapshot left with only inherited permissions is made explicit again by
    # the next command's storage initialization, and replacements then keep it.
    $loose=New-Object Security.AccessControl.FileSecurity
    $loose.SetAccessRuleProtection($false,$false)
    [IO.File]::SetAccessControl($aclSnapshot,$loose)
    Assert-Test (-not (Test-SourcePrivateFile $aclSnapshot)) 'Synthetic inherited-only snapshot ACL was not applied.'
    $null=Initialize-SourceStorage $aclRoot
    Publish-SourceSnapshot $aclRoot (New-SourceSnapshot 'unavailable')
    Assert-Test (Test-SourcePrivateFile $aclSnapshot) 'Storage initialization did not restore the explicit snapshot ACL.'
    $aclState.Calls=@()
    Write-SourceAtomicFile $aclRoot 'stop.request' "stop`n"
    Write-SourceAtomicFile $aclRoot 'stop.request' "stop`n"
    Set-SourceEnabledIntent $aclRoot $true
    Set-SourceEnabledIntent $aclRoot $false
    Assert-Test ($aclState.Calls.Count -eq 6) "Lifecycle vetoes made $($aclState.Calls.Count) ACL calls for four writes instead of 6."
    Assert-Test ((Test-SourcePrivateFile (Join-Path $aclRoot 'stop.request')) -and (Test-SourcePrivateFile (Join-Path $aclRoot 'enabled.intent'))) 'Lifecycle veto lost its explicit private ACL.'
    Assert-Test (@(Get-ChildItem -LiteralPath $aclRoot -Filter '*.tmp').Count -eq 0) 'ACL checks left temporary files.'
} finally { Set-Item Function:\Set-SourcePrivateFile $savedPrivate }

$script:SourceTestCollections=0
$collector={ $script:SourceTestCollections++; New-SourceSnapshot 'unavailable' }
Assert-Test (Invoke-SourceOnce $root $collector) 'Once could not publish a synthetic observation.'
Assert-Test ($script:SourceTestCollections -eq 1) 'Once did not collect exactly once.'
Stop-SourceObserver $root
Assert-Test (Test-SourceStop $root) 'Stop did not create the signal.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Stop did not clear the display.'
Assert-Test (-not (Test-SourceEnabledIntent $root)) 'Stop left resume enabled.'
Assert-Test ([IO.File]::ReadAllText((Get-SourceRuntimeFile $root 'enabled.intent')) -ceq "PARALLAX_AUTOSTART_V1|0`n") 'Stop did not persist exact disabled intent.'
$cycleState=[pscustomobject]@{Calls=0}
$stopDuringCollection={
    $cycleState.Calls++
    Write-SourceAtomicFile $root 'stop.request' "stop`n"
    $ready
}.GetNewClosure()
Start-SourceObserver $root
Assert-Test (-not (Test-SourceStop $root)) 'Explicit Start did not clear the previous Stop.'
Assert-Test (Test-SourceEnabledIntent $root) 'Explicit Start did not persist enabled intent.'
Assert-Test (Invoke-SourceRun $root $stopDuringCollection) 'Synthetic worker did not run.'
Assert-Test ($cycleState.Calls -eq 1) 'Started worker did not enter its collector exactly once.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Stop during collection was overwritten with ready data.'

# A separate managed thread holds the named mutex, matching another worker's
# ownership without launching any process or native observer.
Add-Type -TypeDefinition @'
using System;
using System.Threading;
public sealed class ParallaxSourceTestMutexHolder : IDisposable {
    public readonly ManualResetEvent Acquired = new ManualResetEvent(false);
    private readonly ManualResetEvent finish = new ManualResetEvent(false);
    private readonly Thread thread;
    public ParallaxSourceTestMutexHolder(string name) {
        thread = new Thread(() => { using (var mutex = new Mutex(false,name)) {
            mutex.WaitOne(); Acquired.Set(); finish.WaitOne(); mutex.ReleaseMutex();
        }});
        thread.IsBackground=true; thread.Start();
    }
    public void Dispose() { finish.Set(); thread.Join(5000); Acquired.Dispose(); finish.Dispose(); }
    public static bool CanAcquireOnOtherThread(string name) {
        bool acquired=false;
        var probe=new Thread(() => { using (var mutex=new Mutex(false,name)) {
            acquired=mutex.WaitOne(0); if (acquired) mutex.ReleaseMutex();
        }});
        probe.IsBackground=true; probe.Start();
        if (!probe.Join(5000)) throw new Exception("Synthetic control-lock probe timed out.");
        return acquired;
    }
}
'@
$holder=New-Object ParallaxSourceTestMutexHolder((Get-SourceMutexName $root))
try {
    Assert-Test ($holder.Acquired.WaitOne(5000)) 'Synthetic mutex holder did not acquire ownership.'
    $before=$script:SourceTestCollections
    Assert-Test (-not (Invoke-SourceOnce $root $collector)) 'Once bypassed an existing worker.'
    Assert-Test (-not (Invoke-SourceRun $root $collector)) 'A duplicate worker entered the collection loop.'
    Assert-Test ($script:SourceTestCollections -eq $before) 'Duplicate worker collected despite mutex ownership.'
    # A legacy active worker has no enabled intent. An explicit Start seeds it,
    # while repeated load-time Resume calls never bypass worker ownership.
    [IO.File]::Delete((Get-SourceRuntimeFile $root 'stop.request'))
    [IO.File]::Delete((Get-SourceRuntimeFile $root 'enabled.intent'))
    $beforeLaunches=$script:SourceTestLaunches.Count
    Start-SourceObserver $root
    Assert-Test (Test-SourceEnabledIntent $root) 'Start did not opt an already-running legacy observer into resume.'
    Resume-SourceObserver $root
    Invoke-SourceCommand 'Resume' $root
    Assert-Test ($script:SourceTestLaunches.Count -eq $beforeLaunches) 'Start or repeated Resume launched beside an active worker.'
    Assert-Test ($script:SourceTestCollections -eq $before) 'Resume collected synchronously beside an active worker.'
} finally { $holder.Dispose() }

# Inspect an explicit Start while holding its child launch for later execution.
$script:SourceTestLaunches=@()
$script:SourceCheckControlLock=$true
Start-SourceObserver $root
Assert-Test ($script:SourceTestLaunches.Count -eq 1) 'Start did not request exactly one process.'
Assert-Test ($script:SourceTestLaunches[0].Style -eq 'Hidden') 'Worker startup was not hidden.'
Assert-Test ($script:SourceTestLaunches[0].File -eq (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')) 'Worker executable was not fixed Windows PowerShell.'
Assert-Test ($script:SourceTestLaunches[0].Arguments.Contains('-Command Run') -and $script:SourceTestLaunches[0].Arguments.Contains('-DataRoot "'+$root+'"')) 'Worker startup arguments changed.'
# Regression: Stop can finish while the asynchronously launched Run is delayed.
# The delayed child must make zero observations and retain the stopped state.
Stop-SourceObserver $root
$cycleState.Calls=0
Assert-Test (Invoke-SourceRun $root $stopDuringCollection) 'Delayed synthetic child failed to exit cleanly.'
Assert-Test ($cycleState.Calls -eq 0) 'Delayed Start child collected after Stop had completed.'
Assert-Test (Test-SourceStop $root) 'Delayed Run erased the completed Stop signal.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Delayed Run replaced the stopped display.'
# A later, intentional Start is the only operation that permits collection again.
Start-SourceObserver $root
Assert-Test (-not (Test-SourceStop $root)) 'Intentional restart left the stale Stop marker.'
Assert-Test ($script:SourceTestLaunches.Count -eq 2) 'Intentional restart did not request one fresh launch.'
Assert-Test (Invoke-SourceRun $root $stopDuringCollection) 'Intentional restart could not run.'
Assert-Test ($cycleState.Calls -eq 1) 'Intentional restart did not resume collection.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Restarted worker did not honor its subsequent Stop.'

# Only exact, bounded persisted opt-in permits a load-time Resume. It must not
# normalize invalid bytes or change an existing observation on a rejected check.
$intent=Get-SourceRuntimeFile $root 'enabled.intent'
$beforeLaunches=$script:SourceTestLaunches.Count
$beforeSnapshot=[IO.File]::ReadAllText($destination)
[IO.File]::Delete((Get-SourceRuntimeFile $root 'stop.request'))
foreach ($invalid in @('', "PARALLAX_AUTOSTART_V1|0`n", 'PARALLAX_AUTOSTART_V1|1',
    "PARALLAX_AUTOSTART_V1|1`r`n", "PARALLAX_AUTOSTART_V1|1`n`n", "PARALLAX_AUTOSTART_V2|1`n",
    "PARALLAX_AUTOSTART_V1|2`n", "PARALLAX_AUTOSTART_V1|1`0", ('x'*4096))) {
    Write-SourceAtomicFile $root 'enabled.intent' $invalid
    Assert-Test (-not (Test-SourceEnabledIntent $root)) 'Malformed or disabled intent was accepted.'
    Invoke-SourceCommand 'Resume' $root
    Assert-Test ([IO.File]::ReadAllText($intent) -ceq $invalid) 'Resume rewrote invalid or disabled intent.'
}
[IO.File]::WriteAllBytes($intent,([byte[]](0xEF,0xBB,0xBF)+[Text.Encoding]::ASCII.GetBytes("PARALLAX_AUTOSTART_V1|1`n")))
Assert-Test (-not (Test-SourceEnabledIntent $root)) 'BOM-prefixed intent was accepted.'
Invoke-SourceCommand 'Resume' $root
[IO.File]::Delete($intent)
Invoke-SourceCommand 'Resume' $root
Assert-Test (-not [IO.File]::Exists($intent)) 'Resume created missing intent.'
Assert-Test ($script:SourceTestLaunches.Count -eq $beforeLaunches) 'An invalid, disabled or missing intent launched a worker.'
Assert-Test ([IO.File]::ReadAllText($destination) -ceq $beforeSnapshot) 'Rejected Resume altered the observation.'
$null=[IO.Directory]::CreateDirectory($intent)
Assert-Throws { Test-SourceEnabledIntent $root } 'Intent reader accepted a directory.'
Assert-Throws { Write-SourceAtomicFile $root 'enabled.intent' "PARALLAX_AUTOSTART_V1|1`n" } 'Intent writer replaced a directory.'
[IO.Directory]::Delete($intent)

# Simulate a restart: retain durable intent, discard the helper's in-memory
# state, and use a new command entrypoint invocation. No native reads occur.
Start-SourceObserver $root
$beforeLaunches=$script:SourceTestLaunches.Count
$reloadOutput=@(. $sourcePath)
Assert-Test ($reloadOutput.Count -eq 0 -and $null -eq $script:SourceManager -and $null -eq $script:SourceAdapter) 'Fresh helper load did not remain passive.'
Invoke-SourceCommand 'Resume' $root
Assert-Test ($script:SourceTestLaunches.Count -eq ($beforeLaunches+1)) 'Previously enabled observer did not resume after a fresh helper load.'
Assert-Test ($script:SourceTestLaunches[-1].Style -eq 'Hidden' -and $script:SourceTestLaunches[-1].Arguments.Contains('-Command Run')) 'Resume did not use the existing hidden worker launch.'
Assert-Test ([IO.File]::ReadAllText($intent) -ceq "PARALLAX_AUTOSTART_V1|1`n") 'Resume changed persisted enabled intent.'
$intentSecurity=[IO.File]::GetAccessControl($intent)
$intentRules=@($intentSecurity.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
Assert-Test ($intentSecurity.AreAccessRulesProtected -and $intentRules.Count -eq 1 -and $intentRules[0].IdentityReference.Value -eq $sid.Value) 'Enabled intent permissions allow other identities.'

# Resume launch can be delayed just like Start. A completed Stop wins over the
# delayed child and every later Resume, including after a fresh helper load.
Stop-SourceObserver $root
$cycleState.Calls=0
Assert-Test (Invoke-SourceRun $root $stopDuringCollection) 'Delayed Resume child did not exit cleanly after Stop.'
Assert-Test ($cycleState.Calls -eq 0) 'Delayed Resume child collected after completed Stop.'
Assert-Test (-not (Test-SourceEnabledIntent $root) -and (Test-SourceStop $root)) 'Stop failed to persist both disabled intent and its veto.'
$beforeLaunches=$script:SourceTestLaunches.Count
$null=@(. $sourcePath)
Invoke-SourceCommand 'Resume' $root
Assert-Test ($script:SourceTestLaunches.Count -eq $beforeLaunches) 'A fresh helper resumed after an explicit Stop.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Resume after Stop replaced the stopped display.'

# Interrupted Start or a failed disable-intent write can leave enabled1 beside
# Stop. Stop remains the durable veto; Resume must never erase or age it out.
Set-SourceEnabledIntent $root $true
Invoke-SourceCommand 'Resume' $root
Resume-SourceObserver $root
Assert-Test ($script:SourceTestLaunches.Count -eq $beforeLaunches -and (Test-SourceStop $root)) 'Resume overrode a Stop marker when enabled intent remained.'
$savedSetIntent=(Get-Item Function:\Set-SourceEnabledIntent).ScriptBlock
$script:SourceSawStopBeforeIntent=$false
function Set-SourceEnabledIntent {
    param([string]$Root,[bool]$Enabled)
    $script:SourceSawStopBeforeIntent=Test-SourceStop $Root
    throw 'Synthetic intent write failure'
}
try {
    Assert-Throws { Stop-SourceObserver $root } 'Synthetic disabled-intent write failure was not reported.'
    Assert-Test $script:SourceSawStopBeforeIntent 'Stop did not persist its veto before writing disabled intent.'
} finally { Set-Item Function:\Set-SourceEnabledIntent $savedSetIntent }
Invoke-SourceCommand 'Resume' $root
Assert-Test ($script:SourceTestLaunches.Count -eq $beforeLaunches -and (Test-SourceStop $root)) 'Failed disabled-intent write allowed Resume to override Stop.'
Start-SourceObserver $root
Assert-Test ((Test-SourceEnabledIntent $root) -and -not (Test-SourceStop $root)) 'Later explicit Start did not clear the durable veto and enable resume.'
Assert-Test ($script:SourceTestLaunches.Count -eq ($beforeLaunches+1)) 'Later explicit Start did not request exactly one launch.'
Stop-SourceObserver $root
Assert-Test (@(Get-ChildItem -LiteralPath $root -Filter '*.tmp').Count -eq 0) 'Lifecycle intent updates left atomic temporary files.'
Assert-Test ($null -eq $script:SourceManager -and $null -eq $script:SourceAsTask -and $null -eq $script:SourceAdapter) 'Synthetic tests touched native session APIs.'
Assert-Test ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -eq $sourceHash) 'Production source changed during tests.'
$report="PASS: $script:SourceTestChecks synthetic source-provider assertions; no native sessions, network, credentials, or live configuration used.`n"+
    (($script:SourceTestTimings | ForEach-Object { "  $_`n" }) -join '')+"Source SHA256: $sourceHash`n"
[IO.File]::WriteAllText((Join-Path $root 'results.txt'),$report,[Text.UTF8Encoding]::new($false))
Write-Output $report
Write-Output "Synthetic evidence retained at $root"
