# Developer-only, one read-only native observation. No metadata is printed or saved.
# Unlike the synthetic suite, this intentionally reads the user's Windows sessions.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1.' }
$provider = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SourceProvider.ps1'))
. $provider
$timer = [Diagnostics.Stopwatch]::StartNew()
$snapshot = Get-SourceCollection
$timer.Stop()
[pscustomobject]@{
    State = $snapshot.State
    SessionCount = @($snapshot.Records).Count
    SpotifySessionCount = @($snapshot.Records | Where-Object { $_.Source -eq 'spotify' }).Count
    ElapsedMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds)
    SourceSha256 = (Get-FileHash -LiteralPath $provider -Algorithm SHA256).Hash
    StoredMetadata = $false
    StartedWorker = $false
} | ConvertTo-Json
