[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(5, 60)][int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
$testsRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$moduleRoot = Split-Path -Parent $testsRoot
$runtimeRoot = Join-Path $testsRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('run-' + [guid]::NewGuid().ToString('N'))
$testProcess = $null

function Assert-WithinRun([string]$Path) {
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $allowedRoot = [System.IO.Path]::GetFullPath($runRoot)
    if ($resolvedPath -ne $allowedRoot -and -not $resolvedPath.StartsWith($allowedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing operation outside isolated run directory: $resolvedPath"
    }
}

function Write-Utf8([string]$Path, [string]$Contents) {
    Assert-WithinRun $Path
    [System.IO.File]::WriteAllText($Path, $Contents, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) {
    throw 'Rainmeter executable not found. Supply -RainmeterPath for an existing installation; this runner installs nothing.'
}
foreach ($source in @('Core.lua', 'Store.lua', 'Chronometer.lua', 'Settings.lua', 'EventCore.lua', 'Tests\Suite.lua', 'Tests\SettingsSuite.lua', 'Tests\EventSuite.lua')) {
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot $source) -PathType Leaf)) { throw "Missing production/test source: $source" }
}
if ((Test-Path -LiteralPath $runtimeRoot) -and ((Get-Item -LiteralPath $runtimeRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'The test runtime root must not be a junction or symbolic link.'
}

try {
    $skinRoot = Join-Path $runRoot 'Skins'
    $skinDirectory = Join-Path $skinRoot 'ChronometerTests'
    $fixtureDirectory = Join-Path $runRoot 'fixtures'
    foreach ($directory in @($skinDirectory, $fixtureDirectory, (Join-Path $runRoot 'Layouts'), (Join-Path $runRoot 'Plugins'), (Join-Path $runRoot 'Addons'))) {
        Assert-WithinRun $directory
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $iniPath = Join-Path $runRoot 'Rainmeter.ini'
    $resultPath = Join-Path $runRoot 'results.txt'
    $readonlyPrefix = Join-Path $fixtureDirectory 'readonly'
    $readonlyFile = $readonlyPrefix + '.a.state'
    Write-Utf8 $readonlyFile 'read-only test fixture'
    (Get-Item -LiteralPath $readonlyFile).IsReadOnly = $true

    # Existing, absolute SkinPath is essential: a missing directory falls back to live user skins.
    Write-Utf8 $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033

[ChronometerTests]
Active=1
WindowX=0
WindowY=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@
    Write-Utf8 (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    Write-Utf8 (Join-Path $skinDirectory 'Tests.ini') @"
[Rainmeter]
Update=-1
AccurateText=1
OnRefreshAction=[!CommandMeasure TestScript "QuitTest()"]

[TestScript]
Measure=Script
ScriptFile=$runRoot\Harness.lua

[Bounds]
Meter=Image
W=1
H=1
SolidColor=0,0,0,0
"@

    # Literal long Lua strings preserve Windows separators without executing path text.
    foreach ($literalPath in @($moduleRoot, $testsRoot, $fixtureDirectory, $readonlyPrefix, $resultPath)) {
        if ($literalPath.Contains(']=]')) { throw 'Unsupported Lua long-string delimiter in test path.' }
    }
    Write-Utf8 (Join-Path $runRoot 'Harness.lua') @"
function Initialize()
    local ok, report = pcall(function()
        local core = dofile([=[$moduleRoot\Core.lua]=])
        local store = dofile([=[$moduleRoot\Store.lua]=])
        local suite = dofile([=[$testsRoot\Suite.lua]=])
        return suite.run(core, store, { directory = [=[$fixtureDirectory]=], readOnlyPrefix = [=[$readonlyPrefix]=], moduleRoot = [=[$moduleRoot]=] })
    end)
    if not ok then report = 'HARNESS FAILED: ' .. tostring(report) .. '\n' end
    local output = assert(io.open([=[$resultPath]=], 'wb'))
    assert(output:write(report)); assert(output:close())
end

function Update() return 0 end
function QuitTest() SKIN:Bang('!Quit') end
"@

    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container) -or -not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
        throw 'Isolation preflight failed: settings and skin directory must already exist.'
    }
    $version = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
    Write-Output "Running production Chronometer code with installed Rainmeter $version in isolated temporary settings."
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $exited = $testProcess.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) {
        # Stop only the process returned by this runner. Never dispatch a CLI bang to Rainmeter.
        Stop-Process -InputObject $testProcess -Force
        $testProcess.WaitForExit(5000) | Out-Null
        throw "Isolated test process exceeded $TimeoutSeconds seconds."
    }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        $logPath = Join-Path $runRoot 'Rainmeter.log'
        if (Test-Path -LiteralPath $logPath) { Write-Output (Get-Content -LiteralPath $logPath -Raw) }
        throw 'No result report produced by the isolated test script.'
    }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch 'SUMMARY: (\d+) passed, 0 failed') { throw 'Chronometer logic tests failed; see report above.' }
}
finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $testProcess.WaitForExit(5000) | Out-Null }
        $testProcess.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) {
        $expectedRuntime = [System.IO.Path]::GetFullPath($runtimeRoot) + '\'
        $resolvedRun = [System.IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        if (-not $resolvedRun.StartsWith($expectedRuntime, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedRun) -notmatch '^run-[a-f0-9]{32}$' -or
            ((Get-Item -LiteralPath $runRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing cleanup: isolated run target failed path validation.'
        }
        # Recursive deletion remains in native PowerShell and is confined to this exact generated run.
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
