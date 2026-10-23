# Developer-only, two read-only native observations. No metadata is printed or saved.
# Unlike the synthetic suite, this intentionally reads the user's Windows sessions.
# The second observation shows that the native adapter is built once and reused.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1.' }
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SourceProvider.ps1'))
. $provider
$timer = [Diagnostics.Stopwatch]::StartNew()
$snapshot = Get-SourceCollection
$timer.Stop()
$adapter = $script:SourceAdapter
$second = [Diagnostics.Stopwatch]::StartNew()
$again = Get-SourceCollection
$second.Stop()
[pscustomobject]@{
    State = $snapshot.State
    SessionCount = @($snapshot.Records).Count
    SpotifySessionCount = @($snapshot.Records | Where-Object { $_.Source -eq 'spotify' }).Count
    ElapsedMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds)
    SecondState = $again.State
    SecondElapsedMilliseconds = [Math]::Round($second.Elapsed.TotalMilliseconds)
    AdapterReused = ($null -ne $adapter -and [object]::ReferenceEquals($adapter, $script:SourceAdapter))
    SourceSha256 = (Get-FileHash -LiteralPath $provider -Algorithm SHA256).Hash
    StoredMetadata = $false
    StartedWorker = $false
} | ConvertTo-Json
