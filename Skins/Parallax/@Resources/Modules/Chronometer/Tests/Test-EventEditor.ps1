[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('event-editor-' + [guid]::NewGuid().ToString('N'))
$binary = Join-Path $moduleRoot 'EventEditor.exe'
$process = $null
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw 'Build the original EventEditor.exe with Build-EventEditor.ps1 before testing.' }
try {
    if ((Test-Path -LiteralPath $runtimeRoot) -and ((Get-Item -LiteralPath $runtimeRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Runtime folder must not be a junction.' }
    $fixtures = Join-Path $runRoot 'fixtures'
    $null = New-Item -ItemType Directory -Path $fixtures -Force
    $stdout = Join-Path $runRoot 'results.txt'
    $stderr = Join-Path $runRoot 'errors.txt'
    $process = Start-Process -FilePath $binary -ArgumentList ('-SelfTestRoot "{0}"' -f $fixtures) -WorkingDirectory $runRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $process.WaitForExit(15000)) { Stop-Process -InputObject $process -Force; throw 'Event editor self-tests timed out.' }
    $report = Get-Content -LiteralPath $stdout -Raw
    Write-Output $report
    if ($process.ExitCode -ne 0 -or $report -notmatch 'SUMMARY: 13 passed, 0 failed') { throw 'Event editor native self-tests failed.' }
    $process.Dispose(); $process = $null
    $state = Join-Path $fixtures 'Parallax-Chronometer-event-v1.state'
    $before = [IO.File]::ReadAllText($state)
    $process = Start-Process -FilePath $binary -ArgumentList ('-StatePath "{0}" -ValidateOnly' -f $state) -WorkingDirectory $runRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $process.WaitForExit(15000)) { Stop-Process -InputObject $process -Force; throw 'Event editor validation timed out.' }
    if ($process.ExitCode -ne 0 -or (Get-Content -LiteralPath $stdout -Raw).Trim() -ne 'VALID CLEARED' -or [IO.File]::ReadAllText($state) -cne $before) { throw 'ValidateOnly changed data or returned an invalid result.' }
    Write-Output 'PASS native ValidateOnly reads without opening UI or changing data'
    Write-Output 'EDITOR SUMMARY: 14 passed, 0 failed'
}
finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) {
        $resolved = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        $allowed = [IO.Path]::GetFullPath($runtimeRoot) + '\'
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^event-editor-[a-f0-9]{32}$' -or ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing cleanup outside this generated test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
