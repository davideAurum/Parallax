# Developer-only check that resident Media providers cannot block a skin upgrade.
# Runs a separate, isolated Rainmeter instance against a temp copy of the provider
# scripts and temp data roots. Never touches the live Rainmeter, its settings, or
# the user's LocalAppData provider storage. No network: the queue worker is held in
# a synthetic offline retry wait and never requests Spotify.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$mediaSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$scriptsSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Scripts'))
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$runRoot = Join-Path $tempParent ('Parallax-ProviderLease-test-' + [Guid]::NewGuid().ToString('N'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw "Rainmeter is not installed at $RainmeterPath. Nothing is installed by this runner." }
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$failures = 0; $count = 0
function Check([bool]$Condition, [string]$Message) {
    $script:count++
    if ($Condition) { Write-Output "ok   $Message" } else { $script:failures++; Write-Output "FAIL $Message" }
}
function Get-Workers {
    @(Get-CimInstance -ClassName Win32_Process -Filter "Name='powershell.exe'" -Property ProcessId, CommandLine |
        Where-Object { ([string]$_.CommandLine).Contains($runRoot) -and $_.CommandLine -match '-Command Run' })
}
function Wait-Until([scriptblock]$Condition, [int]$Milliseconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt $Milliseconds) { if (& $Condition) { return $clock.ElapsedMilliseconds }; Start-Sleep -Milliseconds 50 }
    return -1
}

$skins = Join-Path $runRoot 'Skins'
$skin = Join-Path $skins 'Parallax'
$media = Join-Path $skin '@Resources\Modules\Media'
$sourceData = Join-Path $runRoot 'Data\Source'
$queueData = Join-Path $runRoot 'Data\Queue'
foreach ($directory in @("$media\Source", "$media\Queue", "$skin\@Resources\Scripts", "$skin\LeaseTest", $queueData)) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}
Copy-Item -LiteralPath "$mediaSource\ProviderOwner.psm1" -Destination $media
Copy-Item -LiteralPath "$mediaSource\Source\SourceProvider.ps1" -Destination "$media\Source"
foreach ($name in 'QueueProvider.ps1', 'QueueCore.psm1', 'QueueAuth.psm1') { Copy-Item -LiteralPath "$mediaSource\Queue\$name" -Destination "$media\Queue" }
Copy-Item -LiteralPath "$scriptsSource\UpdateInstall.ps1" -Destination "$skin\@Resources\Scripts"
# Hold the queue worker in an unpaused offline wait: resident, but no request.
$retry = '{"schema":2,"state":"offline","retry_not_before":' + ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 900) + ',"pause":false}'
[IO.File]::WriteAllText("$queueData\queue.retry.json", $retry, [Text.UTF8Encoding]::new($false))

$sourceArgs = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + "$media\Source\SourceProvider.ps1" + '" -Command Start -DataRoot "' + $sourceData + '" -Quiet'
$queueArgs = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + "$media\Queue\QueueProvider.ps1" + '" -Command Start -PollSeconds 30 -DataRoot "' + $queueData + '" -Quiet'
# The skin starts both providers exactly as Settings does (hidden RunCommand), then
# quits its own instance gracefully after 12 seconds.
$ini = @"
[Rainmeter]
Update=1000
OnRefreshAction=[!CommandMeasure MeasureSourceStart Run][!CommandMeasure MeasureQueueStart Run]

[MeasureSourceStart]
Measure=Plugin
Plugin=RunCommand
Program=$powershell
Parameter=$sourceArgs
State=Hide
Timeout=20000

[MeasureQueueStart]
Measure=Plugin
Plugin=RunCommand
Program=$powershell
Parameter=$queueArgs
State=Hide
Timeout=20000

[MeasureClock]
Measure=Calc
Formula=MeasureClock+1
IfCondition=MeasureClock>=12
IfTrueAction=[!Quit]

[MeterDot]
Meter=Shape
Shape=Rectangle 0,0,1,1 | Fill Color 0,0,0,1
"@
[IO.File]::WriteAllText("$skin\LeaseTest\LeaseTest.ini", $ini, [Text.UTF8Encoding]::new($false))
$rainmeterIni = Join-Path $runRoot 'Rainmeter.ini'
[IO.File]::WriteAllText($rainmeterIni, @"
[Rainmeter]
SkinPath=$skins\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
TrayIcon=0

[Parallax\LeaseTest]
Active=1
WindowX=-32000
WindowY=-32000
KeepOnScreen=0
"@, [Text.UTF8Encoding]::new($false))

$rainmeter = $null; $loose = @()
try {
    # Phase 1: workers launched from an isolated Rainmeter exit with it.
    $rainmeter = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $rainmeterIni) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $seen = Wait-Until { (Get-Workers).Count -ge 2 } 11000
    $workers = Get-Workers
    Check ($seen -ge 0 -and $workers.Count -eq 2) "Isolated Rainmeter (pid $($rainmeter.Id)) started both resident workers ($($workers.Count) seen)"
    foreach ($worker in $workers) {
        $leaseOk = $worker.CommandLine -match ('-OwnerLease ' + $rainmeter.Id + ':\d+')
        $name = if ($worker.CommandLine -match 'SourceProvider') { 'Source' } else { 'Queue' }
        Check $leaseOk "$name worker carries the launching Rainmeter's lease"
    }
    Check (-not $rainmeter.HasExited) 'Workers are alive while their Rainmeter runs'
    Check ($rainmeter.WaitForExit(20000)) 'Isolated Rainmeter quit itself'
    $quitAt = [Diagnostics.Stopwatch]::StartNew()
    $gone = Wait-Until { (Get-Workers).Count -eq 0 } 10000
    Check ($gone -ge 0) "Both workers exited after their Rainmeter quit ($gone ms)"
    $snapshot = Get-Content -LiteralPath "$sourceData\source.snapshot" -Raw
    Check ($snapshot -match 'state=ready' -and (Get-Content -LiteralPath "$sourceData\enabled.intent" -Raw) -eq "PARALLAX_AUTOSTART_V1|1`n") 'Owner exit keeps resume intent and publishes no stopped state'
    Rename-Item -LiteralPath $skin -NewName 'Parallax.moved'
    Check (Test-Path -LiteralPath "$skins\Parallax.moved") 'Skin folder can be renamed after Rainmeter quits'
    Rename-Item -LiteralPath "$skins\Parallax.moved" -NewName 'Parallax'

    # Phase 2: a lease-less worker (shell start) never holds the skin folder.
    $null = & $powershell -NoProfile -ExecutionPolicy Bypass -File "$media\Source\SourceProvider.ps1" -Command Start -DataRoot $sourceData -Quiet
    $null = & $powershell -NoProfile -ExecutionPolicy Bypass -File "$media\Queue\QueueProvider.ps1" -Command Start -PollSeconds 30 -DataRoot $queueData -Quiet
    $null = Wait-Until { (Get-Workers).Count -ge 2 } 15000
    $loose = Get-Workers
    Check ($loose.Count -eq 2 -and -not ($loose | Where-Object { $_.CommandLine -match 'OwnerLease' })) 'Shell-started workers run without a lease'
    Start-Sleep -Milliseconds 1500
    $renamed = $true
    try { Rename-Item -LiteralPath $skin -NewName 'Parallax.moved'; Rename-Item -LiteralPath "$skins\Parallax.moved" -NewName 'Parallax' } catch { $renamed = $false }
    Check ($renamed -and (Get-Workers).Count -eq 2) 'Skin folder renames while workers are alive (working directory is their data root)'

    # Phase 3: the Welcome Install pre-check ends exactly this skin's workers.
    $installer = [IO.File]::ReadAllText("$skin\@Resources\Scripts\UpdateInstall.ps1")
    $ast = [Management.Automation.Language.Parser]::ParseInput($installer, [ref]$null, [ref]$null)
    $function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-ParallaxMediaWorkers' }, $true)
    # $PSScriptRoot would be this test's folder; point it at the copied skin's Scripts.
    $definition = $function.Extent.Text.Replace("Join-Path `$PSScriptRoot '..\..'", "Join-Path '$skin\@Resources\Scripts' '..\..'")
    . ([scriptblock]::Create($definition))
    $result = Stop-ParallaxMediaWorkers
    Check ($null -eq $result -and (Get-Workers).Count -eq 0) "Install pre-check stopped this skin's workers ($result)"
} finally {
    if ($null -ne $rainmeter) {
        $rainmeter.Refresh()
        if (-not $rainmeter.HasExited) { Stop-Process -InputObject $rainmeter -Force; $null = $rainmeter.WaitForExit(5000) }
        $rainmeter.Dispose()
    }
    # Only processes running this run's own temp copies are ever ended here.
    foreach ($worker in Get-Workers) { Stop-Process -Id $worker.ProcessId -Force -ErrorAction SilentlyContinue }
}
$log = Join-Path $runRoot 'Rainmeter.log'
if (Test-Path -LiteralPath $log) {
    $errors = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' })
    Check ($errors.Count -eq 0) ('Isolated Rainmeter logged no errors' + $(if ($errors.Count) { ': ' + ($errors -join ' / ') }))
}
Write-Output "$($count - $failures)/$count provider lease checks passed. Evidence: $runRoot"
if ($failures) { exit 1 }
