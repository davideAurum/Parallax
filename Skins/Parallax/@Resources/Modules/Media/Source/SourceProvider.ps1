# Original Parallax native media-source observer. Windows PowerShell 5.1.
# No network, authentication, playback controls, or executable dependencies.
[CmdletBinding()]
param(
    [ValidateSet('Help','Start','Run','Stop','Once')][string]$Command = 'Help',
    [string]$DataRoot,
    [switch]$Quiet
)

Set-StrictMode -Version 2.0
$script:SourceProviderPath = $PSCommandPath
$script:SourceManager = $null
$script:SourcePendingTask = $null
$script:SourceAsTask = $null
$script:SourceStrictUtf8 = New-Object Text.UTF8Encoding($false, $true)

function Get-SourceUnixTime { [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds) }

function Get-SourceDefaultRoot {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Parallax\Media\Source'
}

function Resolve-SourceDataRoot {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { $Path = Get-SourceDefaultRoot }
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]' -or
        $Path -match '[\x00-\x1F"<>|?*]' -or $Path.Substring(2).Contains(':')) {
        throw 'Source storage must be an absolute local directory.'
    }
    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($resolved.Length -gt 220) { throw 'Source storage path is too long.' }
    $default = [IO.Path]::GetFullPath((Get-SourceDefaultRoot)).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $resolved.Equals($default, [StringComparison]::OrdinalIgnoreCase) -and
        -not $resolved.StartsWith($temp + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Source storage must use its private default directory or a dedicated temp directory.'
    }
    if ($resolved -match '(?i)(^|[\\/])skins([\\/]|$)') { throw 'Source storage cannot be inside skins.' }
    $probe = $resolved
    while ($probe) {
        if (Test-Path -LiteralPath $probe) {
            $item = Get-Item -LiteralPath $probe -Force -ErrorAction Stop
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Source storage ancestors must be ordinary directories.'
            }
        }
        $parent = [IO.Path]::GetDirectoryName($probe)
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
    return $resolved
}

function Set-SourcePrivateFile {
    param([string]$Path)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object Security.AccessControl.FileSecurity
    $security.SetOwner($sid)
    $security.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'Allow')
    $null = $security.AddAccessRule($rule)
    [IO.File]::SetAccessControl($Path, $security)
}

function Initialize-SourceStorage {
    param([string]$Path)
    $root = Resolve-SourceDataRoot $Path
    $null = [IO.Directory]::CreateDirectory($root)
    $null = Resolve-SourceDataRoot $root
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object Security.AccessControl.DirectorySecurity
    $security.SetOwner($sid)
    $security.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $null = $security.AddAccessRule($rule)
    [IO.Directory]::SetAccessControl($root, $security)
    foreach ($name in @('source.snapshot','stop.request')) {
        $file = Get-SourceRuntimeFile $root $name
        if (Test-Path -LiteralPath $file) { Set-SourcePrivateFile $file }
    }
    return $root
}

function Get-SourceRuntimeFile {
    param([string]$Root, [ValidateSet('source.snapshot','stop.request')][string]$Name)
    $root = Resolve-SourceDataRoot $Root
    $path = Join-Path $root $Name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Source runtime files must be ordinary files.'
        }
    }
    return $path
}

function Get-SourceMutexName {
    param([string]$Root)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $canonical = (Resolve-SourceDataRoot $Root).ToLowerInvariant()
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $hex = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($sid + '|' + $canonical))).Replace('-','') }
    finally { $hash.Dispose() }
    'Local\Parallax.Media.Source.' + $hex
}

function New-SourceMutex { param([string]$Root) New-Object Threading.Mutex($false, (Get-SourceMutexName $Root)) }
function New-SourceControlMutex { param([string]$Root) New-Object Threading.Mutex($false, ((Get-SourceMutexName $Root)+'.Control')) }
function Enter-SourceMutex {
    param([Threading.Mutex]$Mutex, [int]$Milliseconds = 0)
    try { return $Mutex.WaitOne($Milliseconds) }
    catch [Threading.AbandonedMutexException] { return $true }
}

function Get-SourceKind {
    param([string]$AppId)
    foreach ($known in @('Spotify.exe','Spotify','SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify')) {
        if ([string]::Equals($AppId, $known, [StringComparison]::OrdinalIgnoreCase)) { return 'spotify' }
    }
    return 'other'
}

function ConvertTo-SourceHex {
    param([AllowEmptyString()][string]$Text)
    if ($Text.IndexOf([char]0) -ge 0) { throw 'Native metadata contains an unsupported NUL character.' }
    if ($Text.Length -gt 1024) { throw 'Native metadata exceeds the source protocol limit.' }
    $bytes = $script:SourceStrictUtf8.GetBytes($Text)
    if ($bytes.Length -gt 1024) { throw 'Native metadata exceeds the source protocol limit.' }
    [BitConverter]::ToString($bytes).Replace('-','')
}

function New-SourceSnapshot {
    param([ValidateSet('ready','unavailable','stopped')][string]$State, [object[]]$Records = @(), [long]$Observed = 0)
    if ($State -ne 'ready') { return [pscustomobject]@{State=$State; Observed=0L; ValidUntil=0L; Records=@()} }
    if ($Observed -le 0 -or $Observed -gt 253402300790L -or $Records.Count -gt 16) { throw 'Invalid source snapshot bounds.' }
    [pscustomobject]@{State=$State; Observed=$Observed; ValidUntil=($Observed+6L); Records=@($Records)}
}

function ConvertTo-SourceSnapshotText {
    param($Snapshot)
    $lines = New-Object 'Collections.Generic.List[string]'
    if ($Snapshot.State -notin @('ready','unavailable','stopped')) { throw 'Invalid source state.' }
    $records = @($Snapshot.Records)
    if ($records.Count -gt 16) { throw 'Too many native sessions.' }
    if ($Snapshot.State -eq 'ready') {
        if ($Snapshot.Observed -le 0 -or $Snapshot.ValidUntil -ne ($Snapshot.Observed+6L)) { throw 'Invalid source freshness.' }
    } elseif ($Snapshot.Observed -ne 0 -or $Snapshot.ValidUntil -ne 0 -or $records.Count -ne 0) { throw 'Nonready source snapshot contains data.' }
    foreach ($line in @('PARALLAX_SOURCE_V1',('state='+$Snapshot.State),('observed='+$Snapshot.Observed),
        ('valid_until='+$Snapshot.ValidUntil),('count='+$records.Count))) { $lines.Add($line) }
    for ($index=0; $index -lt $records.Count; $index++) {
        $record = $records[$index]; $number = $index+1
        if ($record.Source -notin @('spotify','other') -or $record.Title -isnot [string] -or $record.Artist -isnot [string] -or
            $record.Playing -notin @(0,1)) { throw 'Invalid source record.' }
        $lines.Add('source'+$number+'='+$record.Source)
        $lines.Add('title'+$number+'='+(ConvertTo-SourceHex $record.Title))
        $lines.Add('artist'+$number+'='+(ConvertTo-SourceHex $record.Artist))
        $lines.Add('playing'+$number+'='+[int]$record.Playing)
    }
    $text = ($lines -join "`n") + "`n"
    if ([Text.Encoding]::ASCII.GetByteCount($text) -gt 131072) { throw 'Source snapshot is too large.' }
    return $text
}

function Write-SourceAtomicFile {
    param([string]$Root, [ValidateSet('source.snapshot','stop.request')][string]$Name, [string]$Text)
    $destination = Get-SourceRuntimeFile $Root $Name
    if ($Text -match '[^\x00-\x7F]' -or $Text.Length -gt 131072) { throw 'Invalid source output bytes.' }
    $temporary = Join-Path $Root ($Name+'.'+[Guid]::NewGuid().ToString('N')+'.tmp')
    try {
        $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
            $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true)
        } finally { $stream.Dispose() }
        Set-SourcePrivateFile $temporary
        $null = Get-SourceRuntimeFile $Root $Name
        if ([IO.File]::Exists($destination)) {
            Set-SourcePrivateFile $destination
            [IO.File]::Replace($temporary,$destination,[Management.Automation.Language.NullString]::Value)
        } else { [IO.File]::Move($temporary,$destination) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Publish-SourceSnapshot {
    param([string]$Root, $Snapshot)
    Write-SourceAtomicFile $Root 'source.snapshot' (ConvertTo-SourceSnapshotText $Snapshot)
}

function Get-SourceRemaining {
    param([scriptblock]$Elapsed)
    $elapsedMs = [double](& $Elapsed)
    if ([double]::IsNaN($elapsedMs) -or [double]::IsInfinity($elapsedMs) -or $elapsedMs -lt 0 -or $elapsedMs -ge 4000) {
        throw 'Native session collection exceeded its deadline.'
    }
    return [int][Math]::Max(1,[Math]::Floor(4000-$elapsedMs))
}

function Invoke-SourceAwait {
    param($Operation, [Type]$ResultType, [int]$TimeoutMilliseconds)
    $task = $script:SourceAsTask.MakeGenericMethod($ResultType).Invoke($null,@($Operation))
    $script:SourcePendingTask = $task
    try {
        if (-not $task.Wait($TimeoutMilliseconds)) {
            try { $Operation.Cancel() } catch { }
            throw 'Native session request timed out.'
        }
        return $task.Result
    } finally {
        # A noncooperative timed-out request blocks further collection until it
        # completes, rather than accumulating background requests every poll.
        if ($task.IsCompleted) { $script:SourcePendingTask = $null }
    }
}

function New-SourceNativeAdapter {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
    $script:SourceAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    if ($null -eq $script:SourceAsTask) { throw 'Native session APIs are unavailable.' }
    return [pscustomobject]@{
        GetSessions = {
            param([int]$Remaining)
            if ($null -ne $script:SourcePendingTask -and -not $script:SourcePendingTask.IsCompleted) { throw 'A native session request is still pending.' }
            if ($null -eq $script:SourceManager) {
                $managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
                $script:SourceManager = Invoke-SourceAwait ($managerType::RequestAsync()) $managerType $Remaining
            }
            $list = $script:SourceManager.GetSessions()
            if ($null -eq $list) { throw 'Native session enumeration failed.' }
            foreach ($session in $list) { $session }
        }
        Read = {
            param($Session,[int]$Remaining)
            $properties = Invoke-SourceAwait ($Session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]) $Remaining
            if ($null -eq $properties) { throw 'Native media properties are unavailable.' }
            $playback = $Session.GetPlaybackInfo()
            if ($null -eq $playback) { throw 'Native playback information is unavailable.' }
            [pscustomobject]@{AppId=[string]$Session.SourceAppUserModelId; Title=[string]$properties.Title;
                Artist=[string]$properties.Artist; Playing=([int]($playback.PlaybackStatus.ToString() -eq 'Playing'))}
        }
    }
}

function Read-SourceRecord {
    param($Adapter, $Session, [scriptblock]$Elapsed)
    $record = & $Adapter.Read $Session (Get-SourceRemaining $Elapsed)
    $null = Get-SourceRemaining $Elapsed
    if ($null -eq $record -or $record.AppId -isnot [string] -or $record.Title -isnot [string] -or
        $record.Artist -isnot [string] -or $record.Playing -notin @(0,1)) { throw 'Invalid native session metadata.' }
    $null = ConvertTo-SourceHex $record.Title
    $null = ConvertTo-SourceHex $record.Artist
    return $record
}

function Assert-SourceSessionList {
    param([object[]]$Expected, [object[]]$Actual)
    if ($Expected.Count -gt 16 -or $Expected.Count -ne $Actual.Count) { throw 'Native session list changed or exceeded its limit.' }
    for ($index=0; $index -lt $Expected.Count; $index++) {
        if ($null -eq $Expected[$index] -or -not [object]::ReferenceEquals($Expected[$index],$Actual[$index])) {
            throw 'Native session identity or order changed during collection.'
        }
    }
}

function Get-SourceCollection {
    param($Adapter, [long]$Observed = (Get-SourceUnixTime), [scriptblock]$Elapsed)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if ($null -eq $Elapsed) { $Elapsed = { $timer.Elapsed.TotalMilliseconds }.GetNewClosure() }
    try {
        if ($null -eq $Adapter) { $Adapter = New-SourceNativeAdapter }
        $sessions = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        $null = Get-SourceRemaining $Elapsed
        if ($sessions.Count -gt 16) { throw 'Too many native media sessions.' }
        $records = @()
        foreach ($session in $sessions) { $records += Read-SourceRecord $Adapter $session $Elapsed }
        $middle = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        Assert-SourceSessionList $sessions $middle
        for ($index=0; $index -lt $sessions.Count; $index++) {
            $again = Read-SourceRecord $Adapter $sessions[$index] $Elapsed
            foreach ($key in @('AppId','Title','Artist','Playing')) {
                if (-not [string]::Equals([string]$records[$index].$key,[string]$again.$key,[StringComparison]::Ordinal)) {
                    throw 'Native media properties changed during collection.'
                }
            }
        }
        $after = @(& $Adapter.GetSessions (Get-SourceRemaining $Elapsed))
        Assert-SourceSessionList $sessions $after
        $null = Get-SourceRemaining $Elapsed
        $output = @($records | ForEach-Object { [pscustomobject]@{Source=(Get-SourceKind $_.AppId);Title=$_.Title;Artist=$_.Artist;Playing=[int]$_.Playing} })
        return New-SourceSnapshot 'ready' $output $Observed
    } catch { return New-SourceSnapshot 'unavailable' }
    finally { $timer.Stop() }
}

function Test-SourceStop {
    param([string]$Root)
    [IO.File]::Exists((Get-SourceRuntimeFile $Root 'stop.request'))
}

function Invoke-SourceOnce {
    param([string]$Root, [scriptblock]$Collector = { Get-SourceCollection })
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return $false }
        $snapshot = & $Collector
        Publish-SourceSnapshot $Root $snapshot
        return $true
    } finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}

function Invoke-SourceRun {
    param([string]$Root, [scriptblock]$Collector = { Get-SourceCollection })
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return $false }
        # Only an explicit Start clears a previous Stop. A delayed child must
        # preserve a Stop that completed after the launch was requested.
        while (-not (Test-SourceStop $Root)) {
            $cycle = [Diagnostics.Stopwatch]::StartNew()
            try { $snapshot = & $Collector } catch { $snapshot = New-SourceSnapshot 'unavailable' }
            if (Test-SourceStop $Root) { break }
            Publish-SourceSnapshot $Root $snapshot
            while ($cycle.ElapsedMilliseconds -lt 2000 -and -not (Test-SourceStop $Root)) { Start-Sleep -Milliseconds 100 }
            $cycle.Stop()
        }
        Publish-SourceSnapshot $Root (New-SourceSnapshot 'stopped')
        return $true
    } finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}

function Stop-SourceObserver {
    param([string]$Root)
    $control = New-SourceControlMutex $Root; $controlOwned = $false
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $controlOwned = Enter-SourceMutex $control 10000
        if (-not $controlOwned) { throw 'Another source lifecycle action is still running.' }
        Write-SourceAtomicFile $Root 'stop.request' "stop`n"
        $owned = Enter-SourceMutex $mutex 10000
        if (-not $owned) { throw 'The source observer has not stopped yet.' }
        Publish-SourceSnapshot $Root (New-SourceSnapshot 'stopped')
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }; $control.Dispose()
    }
}

function Start-SourceObserver {
    param([string]$Root)
    $executable = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not [IO.File]::Exists($executable) -or $script:SourceProviderPath -match '["\r\n]') { throw 'Windows PowerShell is unavailable.' }
    $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Command Run -DataRoot "{1}" -Quiet' -f $script:SourceProviderPath,$Root
    $control = New-SourceControlMutex $Root; $controlOwned = $false
    $mutex = New-SourceMutex $Root; $owned = $false
    try {
        $controlOwned = Enter-SourceMutex $control 10000
        if (-not $controlOwned) { throw 'Another source lifecycle action is still running.' }
        $owned = Enter-SourceMutex $mutex
        if (-not $owned) { return }
        # Do not retain worker ownership across asynchronous process startup:
        # a quickly starting child would otherwise mistake us for a worker.
        $mutex.ReleaseMutex(); $owned = $false
        $stop = Get-SourceRuntimeFile $Root 'stop.request'
        if ([IO.File]::Exists($stop)) { [IO.File]::Delete($stop) }
        Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -ErrorAction Stop
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose()
        if ($controlOwned) { $control.ReleaseMutex() }; $control.Dispose()
    }
}

function Invoke-SourceCommand {
    param([string]$Action, [string]$Path)
    if ($Action -eq 'Help') {
        Write-Output 'Parallax native source observer (Windows PowerShell 5.1). Start enables one local worker; Stop ends it. Once publishes one bounded observation. No Spotify sign-in, network, or playback control is used.'
        return
    }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 for native media sessions.' }
    $root = Initialize-SourceStorage $Path
    switch ($Action) {
        'Start' { Start-SourceObserver $root }
        'Run' { $null = Invoke-SourceRun $root }
        'Stop' { Stop-SourceObserver $root }
        'Once' { $null = Invoke-SourceOnce $root }
        default { throw 'Unknown source observer command.' }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-SourceCommand $Command $DataRoot }
    catch {
        if (-not $Quiet) { Write-Error 'The native source observer could not complete this action. Use Windows PowerShell 5.1 and its dedicated local storage directory.' }
        exit 1
    }
}
