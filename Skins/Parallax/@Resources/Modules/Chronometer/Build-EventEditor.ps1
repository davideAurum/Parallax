[CmdletBinding()]
param(
    [string]$CompilerPath = (Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe')
)
$ErrorActionPreference = 'Stop'
$sources = @((Join-Path $PSScriptRoot 'EventEditor.cs'), (Join-Path $PSScriptRoot 'EventEditorForm.cs'))
$output = Join-Path $PSScriptRoot 'EventEditor.exe'
if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) { throw 'An existing Windows .NET Framework C# compiler is required; this build installs nothing.' }
foreach ($source in $sources) { if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'An event editor source file is missing.' } }
& $CompilerPath /nologo /target:winexe /optimize+ '/reference:System.Windows.Forms.dll,System.Drawing.dll' "/out:$output" @sources
if ($LASTEXITCODE -ne 0) { throw 'Event editor compilation failed.' }
Get-FileHash -LiteralPath $output -Algorithm SHA256 | Select-Object Hash, Path
