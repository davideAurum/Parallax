# Developer-only offline tests for following a cast (M8): the switch, the
# worker following a cast on the snapshot the card reads, play/pause/next to
# the cast, the TV moving on by itself, the end of a cast, several devices, the
# TV's own app, and Forget. Stand-ins on 127.0.0.1 play the Cast device and
# YouTube; no packet goes to the network (discovery returns the stand-ins), no
# process is launched (background starts are recorded). All data is made up.
# Host: Windows PowerShell 5.1 (powershell.exe), a normal user (DPAPI).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastWorker.ps1
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\TvProvider.ps1'))
. $provider -Command Help
. (Join-Path $PSScriptRoot 'TvStandIn.ps1')
. (Join-Path $PSScriptRoot 'TvCastStandIn.ps1')
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
$script:launches = [Collections.Generic.List[object]]::new()
function Start-TvBackground { param([string]$Root, [bool]$WithDiagnostics); $script:launches.Add([pscustomobject]@{ Root = $Root }) }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-TvCastWorker-test-' + [Guid]::NewGuid().ToString('N'))
function Fresh-Root { return (Join-Path $runRoot ([Guid]::NewGuid().ToString('N'))) }
function Invoke-As { param([string]$Name, [string]$Root)
    $script:Command = $Name; $script:DataRoot = $Root; $script:Quiet = $true; $script:Code = ''; $script:NoStart = $false; $script:Diagnostics = $false; $script:Action = 'refresh'; $script:Row = 0; $script:Observed = 0
    Invoke-TvCommand
}
function Step-Until { param([object]$Worker, [scriptblock]$Condition, [int]$Seconds = 10, [string]$What = 'condition')
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while (-not (& $Condition)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "FAILED: timed out waiting for $What" }
        Step-TvWorker $Worker 30
    }
}
function Snap { param([string]$Root); $f = Read-TvSnapshotFields $Root; if ($null -eq $f) { return @{} }; return $f }
function Hex([string]$Text) { return [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text)).Replace('-', '') }
function CastState { param([string]$Root); $s = Read-TvCastStatus $Root; if ($s) { return $s.State }; return '' }
function Set-Playing { param($Stand, [string]$Video, [string]$Title, [string]$State = 'PLAYING')
    $Stand.State.Media.Clear()
    $null = $Stand.State.Media.Add(@{ playerState = $State; currentTime = 30; media = @{ contentId = $Video; duration = 240; metadata = @{ title = $Title; subtitle = 'Cast channel' } } })
}

$lounge = Start-TvStandIn
$cast = Start-TvCastStandIn
$cast2 = $null
try {
    Set-TvEndpointForTest -LoungeBase $lounge.LoungeBase -TitleBase $lounge.TitleBase
    Set-CastForTest @($cast.Device)
    $null = New-Item -ItemType Directory -Path $runRoot

    # ---------------------------------------------------------- off by default
    $root = Initialize-TvPrivateDirectory (Fresh-Root)
    Invoke-TvRun $root -UntilMs ((Get-TvUnixMs) + 600) -StepMs 50
    Assert-Check ($cast.State.Connections -eq 0 -and (Snap $root)['state'] -ceq 'not_paired') 'with casts off and no TV paired the worker does nothing and connects nowhere'
    $worker = New-TvWorker $root $null $true
    for ($i = 0; $i -lt 5; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ($cast.State.Connections -eq 0 -and (CastState $root) -ceq '' -and $null -eq (Read-TvCastKey $root)) 'a running worker looks for no cast until the switch is on (and writes no cast state)'

    # ---------------------------------------------------------- the switch
    Invoke-As 'CastOn' $root
    Assert-Check ((Test-TvCastIntent $root) -and (Test-TvIntent $root) -and $script:launches.Count -eq 1 -and (CastState $root) -ceq 'searching') 'CastOn turns casts on and starts the worker, with no TV paired'
    Invoke-As 'Resume' $root
    Assert-Check ($script:launches.Count -eq 2) 'Resume continues a worker that runs only for casts'

    # ---------------------------------------------------------- following a cast
    $null = $cast.State.Apps.Add((New-TvCastYouTubeApp))
    Set-Playing $cast 'vidcast0001' 'Cast song'
    $cast.State.CastScreen = 'SCREEN-SECRET-0001'
    $lounge.State.Token = 'TOKEN-SECRET-CAST'; $lounge.State.NextToken = 'TOKEN-SECRET-CAST'
    $worker.Cast.CheckAt = 0
    Step-Until $worker { (Snap $root)['source'] -ceq 'cast' } -What 'the cast on the snapshot'
    $snap = Snap $root
    Assert-Check ($snap['state'] -ceq 'ready' -and $snap['play'] -ceq 'playing' -and $snap['current_title'] -ceq (Hex 'Cast song') -and $snap['current_channel'] -ceq (Hex 'Cast channel')) 'the cast shows on the snapshot: state, title and channel from the TV'
    Assert-Check ($snap['upnext'] -ceq 'unknown' -and $snap['count'] -ceq '0' -and $snap['duration_ms'] -ceq '240000') 'no up next for a cast; the length is the TV''s'
    Step-Until $worker { (CastState $root) -ceq 'following' } -What 'following'
    $key = Read-TvCastKey $root
    Assert-Check ($key.ScreenId -ceq 'SCREEN-SECRET-0001' -and -not $key.LoungeToken) 'the cast key (screen id) is stored sealed; no token asked yet'
    Assert-Check (@($lounge.State.Log | Where-Object { $_.Path -like '*lounge*' }).Count -eq 0) 'following a cast sends nothing to YouTube'

    # ---------------------------------------------------------- next, pause, play on the cast
    Write-TvRequest $root next
    Step-Until $worker { (Snap $root)['notice'] -ceq 'sent' } -What 'next sent'
    $next = @($lounge.State.Commands | Where-Object { $_.Name -ceq 'next' })
    Assert-Check ($next.Count -eq 1 -and $lounge.State.Binds -eq 1 -and $lounge.State.Leaves -eq 1) 'next goes once, on a session bound for it and left'
    Assert-Check (@($lounge.State.Log | Where-Object { $_.Path -like '*get_lounge_token_batch' }).Count -eq 1 -and (Read-TvCastKey $root).LoungeToken -ceq 'TOKEN-SECRET-CAST') 'the token is asked once, at the first command, and kept sealed'
    Write-TvRequest $root pause
    Step-Until $worker { @($lounge.State.Commands | Where-Object { $_.Name -ceq 'pause' }).Count -eq 1 } -What 'pause'
    Write-TvRequest $root play
    Step-Until $worker { @($lounge.State.Commands | Where-Object { $_.Name -ceq 'play' }).Count -eq 1 } -What 'play'
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check (@($lounge.State.Commands).Count -eq 3 -and @($lounge.State.Log | Where-Object { $_.Path -like '*get_lounge_token_batch' }).Count -eq 1) 'each command once; the kept token is reused'
    Write-TvRequest $root jump -Row 1 -Observed ([long](Snap $root)['observed'])
    Step-Until $worker { (Snap $root)['notice'] -ceq 'queue_changed' } -What 'a jump refused'
    Assert-Check (@($lounge.State.Commands).Count -eq 3) 'a cast has no rows to jump to: nothing sent'
    $lounge.State.CommandStatus = 500
    Write-TvRequest $root next
    Step-Until $worker { (Snap $root)['notice'] -ceq 'failed' } -What 'a failed command'
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check (@($lounge.State.Commands | Where-Object { $_.Name -ceq 'next' }).Count -eq 2) 'a failed command says so and is never resent'
    $lounge.State.CommandStatus = 200

    # ---------------------------------------------------------- the TV moves on by itself
    Set-Playing $cast 'vidcast0002' 'Second song'
    $null = $cast.State.Push.Add(@('transport-1', 'urn:x-cast:com.google.cast.media', @{ type = 'MEDIA_STATUS'; requestId = 0; status = [object[]]@($cast.State.Media[0]) }))
    Step-Until $worker { (Snap $root)['current_title'] -ceq (Hex 'Second song') } -What 'the next video'
    Assert-Check ((Snap $root)['source'] -ceq 'cast') 'the card follows the TV when it moves on by itself'
    Set-Playing $cast 'vidcast0002' 'Second song' 'PAUSED'
    Step-Until $worker { (Snap $root)['play'] -ceq 'paused' } -Seconds 12 -What 'a pause on the TV, by the regular status'
    Assert-Check $true 'a pause on the TV shows without any push'

    # ---------------------------------------------------------- the cast ends
    $cast.State.Apps.Clear()
    $null = $cast.State.Push.Add(@('receiver-0', 'urn:x-cast:com.google.cast.receiver', @{ type = 'RECEIVER_STATUS'; requestId = 0; status = @{ applications = [object[]]@() } }))
    Step-Until $worker { (Snap $root)['state'] -ceq 'not_paired' } -What 'the end of the cast'
    Step-Until $worker { (CastState $root) -ceq 'waiting' } -What 'waiting'
    Assert-Check (-not (Snap $root)['source'] -and -not (Snap $root)['current_title']) 'a cast that ends leaves nothing of it on the snapshot'

    # ---------------------------------------------------------- a new cast with another key
    $null = $cast.State.Apps.Add((New-TvCastYouTubeApp -Session 'session-2' -Transport 'transport-2'))
    $cast.State.CastScreen = 'SCREEN-SECRET-OTHER'
    $null = $cast.State.Push.Add(@('receiver-0', 'urn:x-cast:com.google.cast.receiver', @{ type = 'RECEIVER_STATUS'; requestId = 0; status = @{ applications = [object[]]@($cast.State.Apps) } }))
    Step-Until $worker { (Read-TvCastKey $root).ScreenId -ceq 'SCREEN-SECRET-OTHER' } -What 'the new key'
    Assert-Check (-not (Read-TvCastKey $root).LoungeToken) 'a new cast session asks its key again; a changed key starts without a token'
    $mdx = @($cast.State.Seen | Where-Object { $_.Type -ceq 'getMdxSessionStatus' })
    Assert-Check ($mdx.Count -eq 2 -and $mdx[1].Destination -ceq 'transport-2') 'the key is asked once per cast session'

    # ---------------------------------------------------------- off, and Forget
    Set-TvCastIntent $root $false
    $worker.Cast.CheckAt = 0
    Step-TvWorker $worker 20
    Assert-Check ((CastState $root) -ceq '' -and $worker.Cast.Devices.Count -eq 0 -and $null -eq $worker.Cast.Key -and (Snap $root)['state'] -ceq 'not_paired') 'switched off: channels closed, the key dropped from memory, nothing shown'
    $connections = $cast.State.Connections
    for ($i = 0; $i -lt 10; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ($cast.State.Connections -eq $connections) 'and nothing reconnects'
    Set-TvCastIntent $root $true
    Invoke-As 'CastForget' $root
    Assert-Check (-not (Test-Path (Join-Path $root 'cast.dpapi')) -and -not (Test-Path (Join-Path $root 'cast.intent')) -and -not (Test-Path (Join-Path $root 'cast.status'))) 'Forget removes the cast key, the switch and the state'
    Assert-Check ((Test-TvStop $root) -and -not (Test-TvIntent $root)) 'with no TV paired, Forget also stops the worker'
    Assert-Check (-not (Save-TvCastKeyGuarded $root (New-TvCastKey -ScreenId 'SCREEN-SECRET-LATE')) -and -not (Test-Path (Join-Path $root 'cast.dpapi'))) 'a key arriving after Forget (a late answer or token renewal) is never stored'
    $holder = [PowerShell]::Create()
    $null = $holder.AddScript({ param($Name) $m = [Threading.Mutex]::new($false, $Name); $null = $m.WaitOne(); Start-Sleep -Milliseconds 3000; $m.ReleaseMutex(); $m.Dispose() }).AddArgument((Get-TvMutexName $root) + '.Control')
    $held = $holder.BeginInvoke(); Start-Sleep -Milliseconds 300
    Set-TvCastIntent $root $true
    Assert-Check (-not (Save-TvCastKeyGuarded $root (New-TvCastKey -ScreenId 'SCREEN-SECRET-LATE'))) 'while Forget holds the control lock no key is saved'
    $null = $held.AsyncWaitHandle.WaitOne(5000); $holder.Dispose()
    Remove-TvCastData $root
    $types = @($cast.State.Seen | ForEach-Object { $_.Type } | Sort-Object -Unique)
    Assert-Check (@($types | Where-Object { $_ -cnotin @('CONNECT', 'GET_STATUS', 'PING', 'PONG', 'getMdxSessionStatus') }).Count -eq 0) ('the device only ever got CONNECT, GET_STATUS, PING, PONG and getMdxSessionStatus: ' + ($types -join ','))
    $text = [IO.File]::ReadAllText((Join-Path $root 'tv.snapshot')) + [IO.File]::ReadAllText((Join-Path $root 'events.log'))
    foreach ($secret in @('SCREEN-SECRET', 'TOKEN-SECRET', '127.0.0.1', 'Sample Cast', 'vidcast', 'transport-', 'session-')) { Assert-Check (-not $text.Contains($secret)) "no '$secret' in the snapshot or diagnostics" }

    # ---------------------------------------------------------- no device: gentle discovery
    $root = Initialize-TvPrivateDirectory (Fresh-Root)
    Set-TvCastIntent $root $true
    Set-CastForTest @()
    $worker = New-TvWorker $root $null $false
    Step-Until $worker { (CastState $root) -ceq 'no_device' } -What 'no device'
    Assert-Check ($worker.Cast.NextDiscoverMs - (Get-TvUnixMs) -gt 25000) 'no device found: discovery waits at least 30 s'
    $worker.Cast.NextDiscoverMs = 0
    Step-TvWorker $worker 20; Step-TvWorker $worker 20
    Assert-Check ($worker.Cast.NextDiscoverMs - (Get-TvUnixMs) -gt 55000) 'and longer each time'
    # A device found but refusing every connection: the wait keeps growing too.
    $cast.State.Refuse = $true
    Set-CastForTest @($cast.Device)
    $worker.Cast.NextDiscoverMs = 0
    foreach ($round in 1..2) {
        Step-Until $worker { $worker.Cast.Devices.Count -ge 1 } -What 'the refusing device found'
        foreach ($entry in @($worker.Cast.Devices)) { $entry.NextTryMs = 0 }
        Step-Until $worker { foreach ($entry in @($worker.Cast.Devices)) { $entry.NextTryMs = 0 }; $worker.Cast.Devices.Count -eq 0 } -What 'the refusing device dropped'
        $wait = $worker.Cast.NextDiscoverMs - (Get-TvUnixMs)
        if ($round -eq 1) { $first = $wait } else { Assert-Check ($wait -gt $first + 20000) 'a device that keeps refusing is looked for less and less often' }
        $worker.Cast.NextDiscoverMs = 0
    }
    $cast.State.Refuse = $false
    Reset-TvCast $worker

    # ---------------------------------------------------------- two devices casting YouTube
    $cast2 = Start-TvCastStandIn
    $null = $cast2.State.Apps.Add((New-TvCastYouTubeApp))
    Set-Playing $cast2 'vidcast0009' 'Other song'
    $cast.State.Apps.Clear(); $null = $cast.State.Apps.Add((New-TvCastYouTubeApp))
    Set-Playing $cast 'vidcast0001' 'Cast song'
    Set-CastForTest @($cast.Device, $cast2.Device)
    $root = Initialize-TvPrivateDirectory (Fresh-Root)
    Set-TvCastIntent $root $true
    $worker = New-TvWorker $root $null $false
    Step-Until $worker { (CastState $root) -ceq 'several' } -What 'several'
    for ($i = 0; $i -lt 5; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ((Snap $root)['state'] -cne 'ready' -and $null -eq (Read-TvCastKey $root)) 'two devices playing YouTube: none is followed, no key is asked'
    Reset-TvCast $worker
    # The paired TV's name picks one.
    $root = Initialize-TvPrivateDirectory (Fresh-Root)
    Set-TvCastIntent $root $true
    $cast2.Device.Name = 'Stand-in TV'
    $lounge.State.Token = 'TOKEN-SECRET-A'; $lounge.State.ScreenId = 'SCREEN-SECRET-0001'
    $pairing = New-TvPairing -ScreenId 'SCREEN-SECRET-0001' -LoungeToken 'TOKEN-SECRET-A' -Name 'Stand-in TV'
    Save-TvPairing $root $pairing
    $cast2.State.CastScreen = 'SCREEN-SECRET-CAST2'
    $worker = New-TvWorker $root $pairing $false
    Step-Until $worker { (Snap $root)['source'] -ceq 'cast' } -What 'the named device'
    Assert-Check ((Snap $root)['current_title'] -ceq (Hex 'Other song')) 'the device carrying the paired TV''s name is the one followed'

    # ---------------------------------------------------------- the TV's own app is not a cast
    $cast2.State.CastScreen = 'SCREEN-SECRET-0001'
    $null = $cast2.State.Apps.Clear(); $null = $cast2.State.Apps.Add((New-TvCastYouTubeApp -Session 'session-tv' -Transport 'transport-tv'))
    $null = $cast2.State.Push.Add(@('receiver-0', 'urn:x-cast:com.google.cast.receiver', @{ type = 'RECEIVER_STATUS'; requestId = 0; status = @{ applications = [object[]]@($cast2.State.Apps) } }))
    Step-Until $worker { (CastState $root) -ceq 'tv_app' } -What 'tv_app'
    for ($i = 0; $i -lt 5; $i++) { Step-TvWorker $worker 20 }
    Assert-Check ((Snap $root)['source'] -cne 'cast') 'the same screen as the TV pairing is the TV''s own app: left to the TV session'
    Close-TvPoll $worker.Poll
    Reset-TvCast $worker
    Assert-Check ($cast.State.Errors.Count -eq 0 -and $cast2.State.Errors.Count -eq 0 -and $lounge.State.Errors.Count -eq 0) ('the stand-ins saw no errors: ' + (@($cast.State.Errors) + @($cast2.State.Errors) + @($lounge.State.Errors) -join '; '))
} finally {
    Stop-TvStandIn $lounge
    Stop-TvCastStandIn $cast
    if ($null -ne $cast2) { Stop-TvCastStandIn $cast2 }
    if ([IO.Directory]::Exists($runRoot)) { [IO.Directory]::Delete($runRoot, $true) }
}
Write-Output "TV cast worker: $script:checks checks passed."
