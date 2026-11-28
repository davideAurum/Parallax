# Developer-only offline tests: a TV worker still running from older code is
# restarted once by Resume (Media's player loading) after an update. A stand-in
# "worker" (a runspace holding the worker's lock) plays the old process; no
# process is launched (background starts are recorded) and nothing touches the
# network. Host: Windows PowerShell 5.1, a normal user (DPAPI).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvUpgrade.ps1
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\TvProvider.ps1'))
. $provider -Command Help
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
$script:launches = [Collections.Generic.List[object]]::new()
function Start-TvBackground { param([string]$Root, [bool]$WithDiagnostics, [bool]$Takeover = $false); $script:launches.Add([pscustomobject]@{ Root = $Root; Diagnostics = $WithDiagnostics; Takeover = $Takeover }) }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-TvUpgrade-test-' + [Guid]::NewGuid().ToString('N'))
function Invoke-As { param([string]$Name, [string]$Root)
    $script:Command = $Name; $script:DataRoot = $Root; $script:Quiet = $true; $script:Code = ''; $script:NoStart = $false; $script:Diagnostics = $false
    Invoke-TvCommand
}
function New-PairedRoot {
    $root = Initialize-TvPrivateDirectory (Join-Path $runRoot ([Guid]::NewGuid().ToString('N')))
    Save-TvPairing $root (New-TvPairing -ScreenId 'SCREEN-SECRET-0001' -LoungeToken 'TOKEN-SECRET-A' -Name 'x')
    Set-TvIntent $root $true
    return $root
}
# The old worker: holds the run lock until a stop request appears (or, with
# -Stubborn, never lets go within the test), optionally with a stamp.
function Start-FakeWorker { param([string]$Root, [string]$Stamp = '', [string]$StopPath = '')
    if (-not $StopPath) { $StopPath = Join-Path $Root 'stop.request' }
    if ($Stamp) { Set-TvStampFile $Root 'worker.stamp' $Stamp }
    $ps = [PowerShell]::Create()
    $null = $ps.AddScript({
        param($Name, $StopPath)
        $mutex = [Threading.Mutex]::new($false, $Name)
        $null = $mutex.WaitOne()
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        while (-not [IO.File]::Exists($StopPath) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
        $mutex.ReleaseMutex(); $mutex.Dispose()
    }).AddArgument((Get-TvMutexName $Root)).AddArgument($StopPath)
    $handle = $ps.BeginInvoke()
    $wait = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-TvWorkerRunning $Root)) { if ([DateTime]::UtcNow -gt $wait) { throw 'fake worker did not start' }; Start-Sleep -Milliseconds 20 }
    return [pscustomobject]@{ PS = $ps; Handle = $handle }
}
function Stop-FakeWorker { param($Fake, [string]$Root)
    if (-not $Fake.Handle.IsCompleted) { Request-TvStop $Root; $null = $Fake.Handle.AsyncWaitHandle.WaitOne(5000); Clear-TvStop $Root }
    $Fake.PS.Dispose()
}

# Any run here with a pairing must never reach YouTube: requests go to a closed
# port on this PC, and casts find no device.
Set-TvEndpointForTest -LoungeBase 'http://127.0.0.1:19/api/lounge' -TitleBase 'http://127.0.0.1:19/oembed'
Set-CastForTest @()
try {
    $null = New-Item -ItemType Directory -Path $runRoot
    $current = Get-TvCurrentStamp
    Assert-Check ($current -cmatch '\A[a-f0-9]{32}\z') 'the code stamp is a 32-hex hash of the worker files'
    Assert-Check ((Get-TvCodeStamp $script:CodeFiles) -ceq $current) 'the stamp is stable for the same files'
    $copy = Join-Path $runRoot 'copy.ps1'
    [IO.File]::WriteAllText($copy, 'changed'); $other = Get-TvCodeStamp @($copy, $script:CodeFiles[1], $script:CodeFiles[2], $script:CodeFiles[3])
    Assert-Check ($other -cne $current) 'a changed file changes the stamp'

    # ------------------------------------------------ an old worker with no stamp
    $root = New-PairedRoot
    $fake = Start-FakeWorker $root
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Invoke-As 'Resume' $root
    Assert-Check ($watch.ElapsedMilliseconds -lt 5000 -and $script:launches.Count -eq 1 -and $script:launches[0].Takeover) 'Resume starts a new worker to take over from one with no stamp, and returns at once'
    Assert-Check (-not $fake.Handle.IsCompleted -and -not (Test-TvStop $root) -and (Test-TvIntent $root)) 'Resume itself stops nothing and leaves no barrier: nothing half done if it is cut off'
    Assert-Check ((Get-TvStampFile $root 'upgrade.marker') -ceq $current) 'the restart is remembered for this code'
    # The new worker's takeover (what the launched process runs).
    Invoke-TvRun $root -Takeover -UntilMs ((Get-TvUnixMs) + 1500) -StepMs 50
    Assert-Check ($fake.Handle.IsCompleted -or $fake.Handle.AsyncWaitHandle.WaitOne(3000)) 'the takeover stops the old worker'
    Assert-Check (-not (Test-TvStop $root) -and (Test-TvIntent $root)) 'and clears its stop request: the user''s switch is as it was'
    Stop-FakeWorker $fake $root
    # A user's Stop during the takeover stays.
    $fake = Start-FakeWorker $root
    Set-TvIntent $root $false
    Invoke-TvRun $root -Takeover -UntilMs ((Get-TvUnixMs) + 1500) -StepMs 50
    Assert-Check ((Test-TvStop $root) -and -not (Test-TvIntent $root)) 'a Stop pressed meanwhile keeps its barrier'
    Clear-TvStop $root; Set-TvIntent $root $true
    Stop-FakeWorker $fake $root
    # An old worker that never lets go: the takeover gives up and leaves no barrier.
    $release = Join-Path $runRoot ('release-' + [Guid]::NewGuid().ToString('N'))
    $fake = Start-FakeWorker $root '' $release
    Invoke-TvRun $root -Takeover -TakeoverMs 300 -UntilMs ((Get-TvUnixMs) + 1500) -StepMs 50
    Assert-Check (-not $fake.Handle.IsCompleted -and -not (Test-TvStop $root)) 'an old worker that does not let go: the takeover gives up and leaves no barrier'
    [IO.File]::WriteAllText($release, 'x'); $null = $fake.Handle.AsyncWaitHandle.WaitOne(5000)
    $fake.PS.Dispose()

    # ------------------------------------------------ never loops
    $fake = Start-FakeWorker $root
    Invoke-As 'Resume' $root
    Invoke-As 'Resume' $root
    Assert-Check (-not $fake.Handle.IsCompleted -and $script:launches.Count -eq 1) 'a worker still without the new stamp is not restarted again for the same code'
    Stop-FakeWorker $fake $root

    # ------------------------------------------------ an older stamp, then the same one
    $root = New-PairedRoot
    $fake = Start-FakeWorker $root ('0' * 32)
    Invoke-As 'Resume' $root
    Assert-Check ($script:launches.Count -eq 2 -and $script:launches[1].Takeover) 'a worker with an older stamp is replaced'
    Stop-FakeWorker $fake $root
    $root = New-PairedRoot
    $fake = Start-FakeWorker $root $current
    Invoke-As 'Resume' $root
    Assert-Check (-not $fake.Handle.IsCompleted -and $script:launches.Count -eq 2 -and -not (Test-TvStop $root)) 'a worker from the current code is left running'
    Stop-FakeWorker $fake $root

    # ------------------------------------------------ the user's Stop is respected
    $root = New-PairedRoot
    $fake = Start-FakeWorker $root
    Set-TvIntent $root $false
    Invoke-As 'Resume' $root
    Assert-Check (-not $fake.Handle.IsCompleted -and $script:launches.Count -eq 2) 'with the switch off, Resume restarts nothing'
    Stop-FakeWorker $fake $root
    Set-TvIntent $root $true
    Request-TvStop $root
    Invoke-As 'Resume' $root
    Assert-Check ($script:launches.Count -eq 2 -and (Test-TvStop $root)) 'after Stop, Resume does nothing and keeps the barrier'
    Clear-TvStop $root

    # ------------------------------------------------ Start does not restart
    $fake = Start-FakeWorker $root
    Invoke-As 'Start' $root
    Assert-Check (-not $fake.Handle.IsCompleted -and $script:launches.Count -eq 2) 'Start leaves a running worker alone (only Resume upgrades)'
    Stop-FakeWorker $fake $root

    # ------------------------------------------------ a real run stamps itself and cleans up
    $root = Initialize-TvPrivateDirectory (Join-Path $runRoot ([Guid]::NewGuid().ToString('N')))
    Invoke-TvRun $root -UntilMs ((Get-TvUnixMs) + 500) -StepMs 50
    Assert-Check (-not [IO.File]::Exists((Join-Path $root 'worker.stamp'))) 'a worker removes its stamp when it ends'
    $text = [IO.File]::ReadAllText((Join-Path $root 'tv.snapshot'))
    Assert-Check ($text.StartsWith('PARALLAX_TV_V1')) 'and still publishes its snapshot'
} finally {
    if ([IO.Directory]::Exists($runRoot)) { [IO.Directory]::Delete($runRoot, $true) }
}
Write-Output "TV upgrade: $script:checks checks passed."
