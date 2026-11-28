# Developer-only synthetic Lua checks of Media settings' Live video row, with and
# without the ParallaxVideoCover plugin. Excluded from skin packaging. Same method
# as TvQueue\tests\Test-TvCastLua.ps1: the sources are copied into a fresh temp
# root and run in a separate Rainmeter instance with its own settings file and
# skin path; the live Rainmeter configuration and user data are never touched.
# Host: Windows PowerShell 5.1 and an installed Rainmeter (nothing is installed).
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$controller = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Settings.lua'))
$suite = Join-Path $PSScriptRoot 'MediaVideoRowSuite.luatest'
foreach ($required in $RainmeterPath, $controller, $suite) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}
$runRoot = Join-Path ([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) ('Parallax-MediaVideoRow-test-' + [Guid]::NewGuid().ToString('N'))
if ($runRoot.Contains(']=]') -or $runRoot.Contains('"')) { throw 'Unsupported test path.' }
function Write-TestFile([string]$Path, [string]$Content) { [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false)) }
$configRoot = Join-Path $runRoot 'Skins\MediaVideoRowTest'
$null = New-Item -ItemType Directory -Path $configRoot -Force
Copy-Item -LiteralPath $controller -Destination (Join-Path $runRoot 'Settings.lua')
Copy-Item -LiteralPath $suite -Destination (Join-Path $runRoot 'MediaVideoRowSuite.lua')
$resultPath = Join-Path $runRoot 'results.txt'
Write-TestFile (Join-Path $runRoot 'Rainmeter.ini') "[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[MediaVideoRowTest]`nActive=1`nWindowX=-32000`nWindowY=-32000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-TestFile (Join-Path $configRoot 'Test.ini') "[Rainmeter]`nUpdate=-1`nDynamicWindowSize=0`nOnRefreshAction=[!CommandMeasure TestHarness `"AuditAndQuit()`"]`n`n[TestHarness]`nMeasure=Script`nScriptFile=$runRoot\Harness.lua`n`n[MeterBounds]`nMeter=Image`nX=0`nY=0`nW=1`nH=1`nSolidColor=0,0,0,0`n"
Write-TestFile (Join-Path $runRoot 'Harness.lua') @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local suite = dofile([=[$runRoot\MediaVideoRowSuite.lua]=])
        local total, cases = suite.run([=[$runRoot\Settings.lua]=])
        return 'PASS: '..total..' assertions in '..#cases..' Live video row scenarios; '.._VERSION..'.\n'..table.concat(cases, '\n')..'\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@
try {
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $runRoot 'Rainmeter.ini')) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated Live video row tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Live video row tests failed.' }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        if ($errors.Count) { $errors | Write-Output; throw 'Isolated Rainmeter logged errors.' }
    }
} finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null = $testProcess.WaitForExit(5000) }
        $testProcess.Dispose()
    }
}
