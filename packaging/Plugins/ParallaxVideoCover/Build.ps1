# Builds ParallaxVideoCover.dll (x64) with the installed Visual Studio Build
# Tools. The DLL goes to -OutDir, never into the repository.
param([string]$OutDir = (Join-Path ([IO.Path]::GetTempPath()) 'parallax-video-cover\plugin'))
$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$install = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $install) { throw 'Visual Studio Build Tools with the C++ workload were not found.' }
$vcvars = Join-Path $install 'VC\Auxiliary\Build\vcvars64.bat'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$source = Join-Path $PSScriptRoot 'ParallaxVideoCover.cpp'
# A batch file: cmd.exe's quoting of a long command line with spaced paths is not.
$batch = Join-Path $OutDir 'build.cmd'
Set-Content -LiteralPath $batch -Encoding Default -Value @(
    '@echo off'
    ('call "{0}" >nul || exit /b 1' -f $vcvars)
    ('cl /nologo /LD /O2 /MT /EHsc /W4 /DUNICODE /D_UNICODE "{0}" /Fo"{1}\\" /Fe"{1}\ParallaxVideoCover.dll" /link dwmapi.lib user32.lib shell32.lib ole32.lib oleaut32.lib propsys.lib' -f $source, $OutDir)
)
$out = & $batch
$code = $LASTEXITCODE
$out
if ($code) { throw "cl failed ($code)" }
Join-Path $OutDir 'ParallaxVideoCover.dll'
