#requires -Version 5.1
# One end-to-end resident-host probe using the production bootstrap and Run.
# It launches one hidden PowerShell host, observes native snapshots as data,
# renews then removes the lease, and waits for the host to cleanly stop itself.
# No live Rainmeter configuration, paging-file configuration or dependencies
# are changed. Evidence contains no sampled byte totals or paging-file names.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runtimeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runtime'))
$scratch = Join-Path $runtimeRoot ('ram-page-resident-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($scratch)
$scratchPrefix = $scratch.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\PageFileHost.cs.txt'))
$stdoutPath = Join-Path $scratch 'host.stdout.txt'
$stderrPath = Join-Path $scratch 'host.stderr.txt'
$resultPath = Join-Path $scratch 'result.json'
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$resident = $null
$sessionPaths = @()
$script:checks = 0
$result = [ordered]@{
    passed = $false
    architectureBits = [IntPtr]::Size * 8
    assertions = 0
    intervalMs = 1000
    maximumLeaseAgeSeconds = 15
    hostLaunchCount = 0
    exitCode = $null
    distinctFrames = 0
    successiveFramesObserved = $false
    continuedBeyondInitialLease = $false
    renewedLease = $false
    stoppedAfterLeaseRemoval = $false
    sessionFilesCleaned = $false
    stdoutEmpty = $false
    stderrEmpty = $false
    forcedStop = $false
    rainmeterUnloadTested = $false
}
function Check-Resident([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function Get-Epoch {
    return [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalSeconds)
}
function Write-Lease([string]$Path, [string]$Token, [long]$Epoch) {
    [IO.File]::WriteAllText($Path, ($Token + '|' + $Epoch.ToString([Globalization.CultureInfo]::InvariantCulture)), [Text.Encoding]::ASCII)
}
function Read-Frame([string]$Path, [string]$Token) {
    if (-not [IO.File]::Exists($Path)) { return $null }
    $stream = $null
    try {
        $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        Check-Resident ($stream.Length -gt 0 -and $stream.Length -le 512) 'Resident snapshot size is invalid.'
        $bytes = [byte[]]::new(513)
        $used = 0
        while ($used -lt $bytes.Length) {
            $read = $stream.Read($bytes, $used, $bytes.Length - $used)
            if ($read -eq 0) { break }
            $used += $read
        }
        Check-Resident ($used -le 512) 'Resident snapshot exceeded its read bound.'
        for ($index = 0; $index -lt $used; $index++) {
            Check-Resident ($bytes[$index] -ge 32 -and $bytes[$index] -le 126) 'Resident snapshot contains non-ASCII or control bytes.'
        }
        $fields = [Text.Encoding]::ASCII.GetString($bytes, 0, $used).Split('|')
        Check-Resident ($fields.Length -eq 9) 'Resident snapshot is not a complete frame.'
        Check-Resident ($fields[0] -ceq 'RAM_PAGE' -and $fields[1] -ceq '1' -and $fields[2] -ceq $Token) 'Resident snapshot identity is invalid.'
        Check-Resident ($fields[3] -cmatch '^(0|[1-9][0-9]{0,15})$') 'Resident sequence is invalid.'
        Check-Resident ($fields[4] -cmatch '^(0|[1-9][0-9]{0,11})$') 'Resident timestamp is invalid.'
        $sequence = [long]::Parse($fields[3], [Globalization.CultureInfo]::InvariantCulture)
        $epoch = [long]::Parse($fields[4], [Globalization.CultureInfo]::InvariantCulture)
        Check-Resident ($sequence -le 9007199254740991 -and $epoch -le 253402300799) 'Resident numeric metadata exceeds bounds.'
        $now = Get-Epoch
        Check-Resident ($epoch -ge $now - 5 -and $epoch -le $now + 5) 'Resident snapshot timestamp is not current.'
        $status = $fields[5]
        Check-Resident ($status -cin @('STARTING', 'OK', 'NONE', 'UNAVAILABLE', 'UNSUPPORTED')) 'Resident status is invalid.'
        if ($status -cin @('OK', 'NONE')) {
            foreach ($field in $fields[6..8]) {
                Check-Resident ($field -cmatch '^(0|[1-9][0-9]{0,15})$') 'Resident quantity is not a canonical integer.'
            }
            $usedBytes = [uint64]::Parse($fields[6], [Globalization.CultureInfo]::InvariantCulture)
            $totalBytes = [uint64]::Parse($fields[7], [Globalization.CultureInfo]::InvariantCulture)
            $count = [uint64]::Parse($fields[8], [Globalization.CultureInfo]::InvariantCulture)
            Check-Resident ($usedBytes -le $totalBytes -and $totalBytes -le 9007199254740991 -and $count -le 512) 'Resident quantities are inconsistent.'
            Check-Resident ($usedBytes % [Environment]::SystemPageSize -eq 0 -and $totalBytes % [Environment]::SystemPageSize -eq 0) 'Resident quantities are not page aligned.'
            if ($status -ceq 'NONE') {
                Check-Resident ($usedBytes -eq 0 -and $totalBytes -eq 0 -and $count -eq 0) 'Resident NONE state contains quantities.'
            }
            else { Check-Resident ($count -gt 0) 'Resident OK state has no enumerated files.' }
        }
        else { Check-Resident (($fields[6..8] -join '|') -ceq '?|?|?') 'Resident unknown state contains fabricated quantities.' }
        # Only metadata leaves this local reader; actual quantities are not logged.
        return [pscustomobject]@{ Sequence=$sequence; Epoch=$epoch; Status=$status }
    }
    catch [IO.FileNotFoundException] { return $null }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}
try {
    $env:TEMP = $scratch
    $env:TMP = $scratch
    Add-Type -TypeDefinition ([IO.File]::ReadAllText($sourcePath)) -Language CSharp
    $session = [ParallaxRamPageFile]::CreateSession(1000).Split('|')
    Check-Resident ($session.Length -eq 4 -and $session[0] -ceq 'RAM_PAGE_SESSION' -and $session[1] -ceq '1') 'Bootstrap protocol is invalid.'
    $token = $session[2]
    Check-Resident ($token -cmatch '^[0-9a-f]{32}$') 'Bootstrap token is invalid.'
    Check-Resident ($session[3] -cmatch '^(?:[0-9A-F]{2})+$') 'Bootstrap path encoding is invalid.'
    $pathBytes = [byte[]]::new($session[3].Length / 2)
    for ($index = 0; $index -lt $pathBytes.Length; $index++) {
        $pathBytes[$index] = [byte]::Parse($session[3].Substring(2 * $index, 2), [Globalization.NumberStyles]::HexNumber, [Globalization.CultureInfo]::InvariantCulture)
    }
    $dataPath = [Text.UTF8Encoding]::new($false, $true).GetString($pathBytes)
    $expectedDataPath = Join-Path $scratch ('Parallax-RAM-Page-' + $token + '.dat')
    Check-Resident ($dataPath -ceq $expectedDataPath) 'Bootstrap path escapes the owned scratch session.'
    $leasePath = [IO.Path]::ChangeExtension($dataPath, '.lease')
    $temporaryPath = [IO.Path]::ChangeExtension($dataPath, '.tmp')
    $sessionPaths = @($dataPath, $leasePath, $temporaryPath)
    foreach ($path in $sessionPaths) { Check-Resident (-not [IO.File]::Exists($path)) 'Bootstrap unexpectedly wrote a session file.' }
    $initialEpoch = Get-Epoch
    $lastRenewedEpoch = $initialEpoch
    Write-Lease $leasePath $token $initialEpoch
    $escapedSource = $sourcePath.Replace("'", "''")
    $hostScript = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
try {
    Add-Type -TypeDefinition ([IO.File]::ReadAllText('$escapedSource')) -Language CSharp
    [ParallaxRamPageFile]::Run('$token', 1000)
} catch { [Console]::Error.WriteLine('Resident provider failed.'); exit 1 }
"@
    $encodedHost = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($hostScript))
    $powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $resident = Start-Process -FilePath $powershell -ArgumentList @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedHost) -WorkingDirectory $scratch -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    # Retain the real process handle before exit so Windows PowerShell's
    # Start-Process object can query its exit code after the process is gone.
    Check-Resident ($resident.Handle -ne [IntPtr]::Zero) 'The owned host process handle was not retained.'
    $result.hostLaunchCount = 1
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $lastSequence = [long]-1
    $lastFrame = $null
    while ($watch.Elapsed.TotalSeconds -lt 30) {
        Check-Resident (-not $resident.HasExited) 'Resident host exited before the lease test completed.'
        $now = Get-Epoch
        # Renew on the UI's five-second cadence, then stop renewing so a frame
        # beyond the original lease boundary proves the renewal was consumed.
        if ($now - $lastRenewedEpoch -ge 5 -and $now - $initialEpoch -le 16) {
            Write-Lease $leasePath $token $now
            $lastRenewedEpoch = $now
            $result.renewedLease = $true
        }
        $frame = Read-Frame $dataPath $token
        if ($null -ne $frame -and $frame.Sequence -ne $lastSequence) {
            Check-Resident ($frame.Sequence -gt $lastSequence) 'Resident sequence did not advance monotonically.'
            if ($frame.Status -cin @('OK', 'NONE')) {
                if ($null -ne $lastFrame -and $lastFrame.Status -cin @('OK', 'NONE') -and $frame.Sequence -eq $lastSequence + 1) {
                    $result.successiveFramesObserved = $true
                }
                if ($frame.Epoch -gt $initialEpoch + 16 -and $frame.Epoch -gt $lastRenewedEpoch) {
                    $result.continuedBeyondInitialLease = $true
                }
            }
            $lastSequence = $frame.Sequence
            $lastFrame = $frame
            $result.distinctFrames++
        }
        if ($result.successiveFramesObserved -and $result.continuedBeyondInitialLease) { break }
        Start-Sleep -Milliseconds 100
    }
    Check-Resident $result.successiveFramesObserved 'Two successive valid paging-file frames were not observed.'
    Check-Resident ($result.renewedLease -and $result.continuedBeyondInitialLease) 'The renewed lease did not demonstrably extend the real host lifetime.'
    # The final observation is at least one epoch second after renewal, leaving
    # at most the documented 15-second freshness window plus one sample interval.
    [IO.File]::Delete($leasePath)
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()
    while (-not $resident.HasExited -and $stopWatch.Elapsed.TotalSeconds -lt 16) { Start-Sleep -Milliseconds 100 }
    Check-Resident $resident.HasExited 'Resident host exceeded its lease expiry and sample interval.'
    $resident.WaitForExit()
    $result.exitCode = $resident.ExitCode
    Check-Resident ($resident.ExitCode -eq 0) 'Resident host did not exit cleanly.'
    $result.stoppedAfterLeaseRemoval = $true
    foreach ($path in $sessionPaths) { Check-Resident (-not [IO.File]::Exists($path)) 'Resident host left a session file after clean exit.' }
    $result.sessionFilesCleaned = $true
    $result.stdoutEmpty = ([IO.FileInfo]::new($stdoutPath).Length -eq 0)
    $result.stderrEmpty = ([IO.FileInfo]::new($stderrPath).Length -eq 0)
    Check-Resident ($result.stdoutEmpty -and $result.stderrEmpty) 'Resident host emitted unexpected output.'
    $result.passed = $true
}
finally {
    if ($null -ne $resident) {
        if (-not $resident.HasExited) {
            $result.forcedStop = $true
            # This retained Process object belongs only to the host launched above.
            $resident.Kill()
            [void]$resident.WaitForExit(5000)
        }
        $resident.Dispose()
    }
    foreach ($path in $sessionPaths) {
        $resolved = [IO.Path]::GetFullPath($path)
        if (-not $resolved.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Cleanup target escaped the owned scratch directory.' }
        if ([IO.File]::Exists($resolved)) { Remove-Item -LiteralPath $resolved -Force }
    }
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
    $result.assertions = $script:checks
    [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json), [Text.Encoding]::UTF8)
}
Write-Output ('PASS: ' + $script:checks + ' end-to-end resident assertions; one hidden host, successive valid atomic native frames, five-second renewal beyond the initial lease, self-exit within TTL plus interval, and own-session cleanup. No sampled totals or paging-file names retained; Rainmeter UI unload remains untested.')
Write-Output ('Evidence: ' + $resultPath)
