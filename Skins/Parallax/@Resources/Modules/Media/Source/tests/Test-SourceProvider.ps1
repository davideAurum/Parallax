# Developer-only synthetic observer checks. Never reads native media sessions.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SourceProvider.ps1'))
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-SourceProvider-test-'+[Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $runRoot) { throw 'Test directory must be fresh.' }
$script:SourceTestChecks = 0
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
Assert-Test ($null -eq $script:SourceManager -and $null -eq $script:SourceAsTask) 'Dot-source initialized native collection.'

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

$script:SourceTestCollections=0
$collector={ $script:SourceTestCollections++; New-SourceSnapshot 'unavailable' }
Assert-Test (Invoke-SourceOnce $root $collector) 'Once could not publish a synthetic observation.'
Assert-Test ($script:SourceTestCollections -eq 1) 'Once did not collect exactly once.'
Stop-SourceObserver $root
Assert-Test (Test-SourceStop $root) 'Stop did not create the signal.'
Assert-Test ([IO.File]::ReadAllText($destination) -match '(?m)^state=stopped$') 'Stop did not clear the display.'
# Every explicit Start is inspected through this stub; no process is launched.
$script:SourceTestLaunches=@()
$script:SourceCheckControlLock=$false
function Start-Process {
    [CmdletBinding()]param($FilePath,$ArgumentList,$WindowStyle)
    if ($script:SourceCheckControlLock) {
        $controlName=(Get-SourceMutexName $root)+'.Control'
        Assert-Test (-not [ParallaxSourceTestMutexHolder]::CanAcquireOnOtherThread($controlName)) 'Concurrent lifecycle action could enter during Start launch.'
    }
    $script:SourceTestLaunches+=@{File=$FilePath;Arguments=$ArgumentList;Style=$WindowStyle}
}
$cycleState=[pscustomobject]@{Calls=0}
$stopDuringCollection={
    $cycleState.Calls++
    Write-SourceAtomicFile $root 'stop.request' "stop`n"
    $ready
}.GetNewClosure()
Start-SourceObserver $root
Assert-Test (-not (Test-SourceStop $root)) 'Explicit Start did not clear the previous Stop.'
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
Assert-Test ($null -eq $script:SourceManager -and $null -eq $script:SourceAsTask) 'Synthetic tests touched native session APIs.'
Assert-Test ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -eq $sourceHash) 'Production source changed during tests.'
$report="PASS: $script:SourceTestChecks synthetic source-provider assertions; no native sessions, network, credentials, or live configuration used.`nSource SHA256: $sourceHash`n"
[IO.File]::WriteAllText((Join-Path $root 'results.txt'),$report,[Text.UTF8Encoding]::new($false))
Write-Output $report
Write-Output "Synthetic evidence retained at $root"
