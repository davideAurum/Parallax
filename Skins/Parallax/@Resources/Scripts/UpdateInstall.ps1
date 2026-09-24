# One-shot Parallax update download, started only by the Welcome panel's Install click.
# Downloads one .rmskin from the fixed release prefix into %TEMP%\Parallax\Update,
# verifies its size, SHA-256 and RMSKIN trailer, then hands it to Rainmeter's own
# Skin Installer, which shows the package and asks the user to confirm. This helper
# installs nothing itself, writes nothing under Skins, and exits right after the hand-off.
# Output is one line of data for the caller: PARALLAX_UPDATE_V1|ok|<file> or PARALLAX_UPDATE_V1|error|<reason>.
[CmdletBinding()]
param(
    [string]$Url,
    [string]$Sha256,
    [string]$Version,
    [string]$ReleaseBase,
    [string]$ProgramPath,
    [switch]$ValidateOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$maxBytes = 64MB
$partial = $null

function Write-Result([string]$State, [string]$Detail) {
    [Console]::Out.WriteLine('PARALLAX_UPDATE_V1|' + $State + '|' + ($Detail -replace '[\r\n|]', ' '))
}

function Test-UpdateArguments {
    if ($ReleaseBase -cnotmatch '\Ahttps://github\.com/[A-Za-z0-9-]{1,39}/[A-Za-z0-9._-]{1,100}/releases/\z') { return 'The release location is not a GitHub releases address.' }
    if ($Version -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z') { return 'The offered version is not a valid version string.' }
    if ($Sha256 -cnotmatch '\A[0-9A-Fa-f]{64}\z') { return 'The offered checksum is not a SHA-256 value.' }
    $expected = $ReleaseBase + 'download/v' + $Version + '/Parallax_' + $Version + '.rmskin'
    if (-not [string]::Equals($Url, $expected, [StringComparison]::Ordinal)) { return 'The offered package is not the release asset for that version.' }
    return $null
}

try {
    $problem = Test-UpdateArguments
    if ($problem) { Write-Result 'error' $problem; exit 0 }
    if ($ValidateOnly) { Write-Result 'valid' $Url; exit 0 }

    $root = Join-Path ([IO.Path]::GetTempPath()) 'Parallax\Update'
    $null = [IO.Directory]::CreateDirectory($root)
    $target = Join-Path $root ('Parallax_' + $Version + '.rmskin')
    $partial = $target + '.partial'
    # Only this helper's own earlier downloads are removed.
    Get-ChildItem -LiteralPath $root -File -Force | Where-Object { $_.Name -match '\AParallax_[A-Za-z0-9._-]+\.rmskin(\.partial)?\z' } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    # One retry for a dropped connection or failed handshake; HTTP errors such as 404 are final.
    $response = $null
    for ($attempt = 1; $null -eq $response; $attempt++) {
        $request = [Net.HttpWebRequest]::Create($Url)
        $request.UserAgent = 'Parallax-Updater/1'
        $request.Timeout = 30000
        $request.ReadWriteTimeout = 30000
        $request.AllowAutoRedirect = $true
        $request.KeepAlive = $false
        try { $response = $request.GetResponse() } catch [Net.WebException] {
            if ($attempt -ge 2 -or $_.Exception.Status -eq [Net.WebExceptionStatus]::ProtocolError) { throw }
            Start-Sleep -Seconds 2
        }
    }
    try {
        # GitHub redirects release assets to its own download hosts; anything else is refused.
        $finalHost = $response.ResponseUri.Host
        if ($response.ResponseUri.Scheme -ne 'https' -or ($finalHost -ne 'github.com' -and $finalHost -notlike '*.githubusercontent.com')) {
            Write-Result 'error' "The download was redirected to an unexpected host ($finalHost)."; exit 0
        }
        if ($response.ContentLength -gt $maxBytes) { Write-Result 'error' 'The package is larger than 64 MB.'; exit 0 }
        $in = $response.GetResponseStream()
        $out = [IO.File]::Create($partial)
        try {
            $buffer = New-Object byte[] 65536
            $total = 0L
            while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $total += $read
                if ($total -gt $maxBytes) { throw 'The package is larger than 64 MB.' }
                $out.Write($buffer, 0, $read)
            }
        } finally { $out.Dispose(); $in.Dispose() }
    } finally { $response.Dispose() }

    $actual = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $Sha256, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $partial -Force
        Write-Result 'error' 'The download does not match the published checksum. Nothing was installed.'; exit 0
    }
    # Skin Installer's own acceptance check: int64 archive length, a flags byte, then RMSKIN\0.
    $bytes = [IO.File]::ReadAllBytes($partial)
    $valid = $bytes.Length -ge 32
    if ($valid) {
        $key = [Text.Encoding]::ASCII.GetString($bytes, $bytes.Length - 7, 7)
        $length = [BitConverter]::ToInt64($bytes, $bytes.Length - 16)
        $valid = $key -eq "RMSKIN`0" -and $length -eq ($bytes.Length - 16)
    }
    if (-not $valid) {
        Remove-Item -LiteralPath $partial -Force
        Write-Result 'error' 'The download is not a Rainmeter skin package. Nothing was installed.'; exit 0
    }
    Move-Item -LiteralPath $partial -Destination $target -Force

    # Prefer the Skin Installer beside the running Rainmeter (portable installs have no
    # .rmskin file association); otherwise let Windows open the package.
    $installer = if ($ProgramPath) { Join-Path $ProgramPath 'SkinInstaller.exe' } else { $null }
    if ($installer -and (Test-Path -LiteralPath $installer -PathType Leaf)) {
        Start-Process -FilePath $installer -ArgumentList ('"' + $target + '"')
    } else {
        Start-Process -FilePath $target
    }
    Write-Result 'ok' $target
} catch {
    if ($partial -and (Test-Path -LiteralPath $partial)) { Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue }
    $problem = $_.Exception
    while ($problem.InnerException) { $problem = $problem.InnerException }
    Write-Result 'error' ('Download failed: ' + $problem.Message)
}
