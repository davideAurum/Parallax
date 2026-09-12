[CmdletBinding()]
param([switch]$KeepRuntime)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('event-form-' + [guid]::NewGuid().ToString('N'))
$previewRoot = Join-Path $PSScriptRoot '.preview'
$previewPath = Join-Path $previewRoot 'event-editor.png'
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$binary = Join-Path $runRoot 'EventEditorFormTests.exe'
$process = $null
try {
    foreach ($root in @($runtimeRoot, $previewRoot)) {
        if ((Test-Path -LiteralPath $root) -and ((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test directories must not be junctions.' }
    }
    $fixtures = Join-Path $runRoot 'fixtures'
    $null = New-Item -ItemType Directory -Path $fixtures -Force
    $null = New-Item -ItemType Directory -Path $previewRoot -Force
    $sources = @((Join-Path $moduleRoot 'EventEditor.cs'), (Join-Path $moduleRoot 'EventEditorForm.cs'), (Join-Path $PSScriptRoot 'EventEditorFormTests.cs'))
    & $compiler /nologo /target:winexe /optimize+ /main:Parallax.Chronometer.EventEditorFormTests '/reference:System.Windows.Forms.dll,System.Drawing.dll' "/out:$binary" @sources
    if ($LASTEXITCODE -ne 0) { throw 'Form-test compilation failed.' }
    $stdout = Join-Path $runRoot 'results.txt'
    $stderr = Join-Path $runRoot 'errors.txt'
    $arguments = '-SelfTestRoot "{0}" -PreviewPath "{1}"' -f $fixtures, $previewPath
    $process = Start-Process -FilePath $binary -ArgumentList $arguments -WorkingDirectory $runRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $process.WaitForExit(15000)) { Stop-Process -InputObject $process -Force; throw 'Event form tests timed out.' }
    $report = Get-Content -LiteralPath $stdout -Raw
    Write-Output $report
    if ($process.ExitCode -ne 0 -or $report -notmatch 'FORM SUMMARY: 7 passed, 0 failed') { throw 'Event form tests failed.' }
    if (-not (Test-Path -LiteralPath $previewPath -PathType Leaf)) { throw 'Authored form preview was not rendered.' }
    Write-Output ('Preview: ' + $previewPath)
    if ($KeepRuntime) { Write-Output ('Integration test executable: ' + $binary); Write-Output ('Runtime retained: ' + $runRoot) }
}
finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
    }
    if (-not $KeepRuntime -and (Test-Path -LiteralPath $runRoot)) {
        $resolved = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        $allowed = [IO.Path]::GetFullPath($runtimeRoot) + '\'
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^event-form-[a-f0-9]{32}$' -or ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Refusing cleanup outside the generated form-test directory.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
