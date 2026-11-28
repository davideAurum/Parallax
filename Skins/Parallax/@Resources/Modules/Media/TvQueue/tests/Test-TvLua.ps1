# Developer-only synthetic Lua checks of the TV queue's skin side: Media's drawer
# (QueueReader.lua with TvQueue on), Connections' TV row (TvConnections.lua) and
# the resume on Media load (MediaLifecycle.lua). Excluded from skin packaging.
# Copies the sources into a fresh temp root and runs them in a separate Rainmeter
# instance with its own absolute settings file and skin path: the live Rainmeter
# configuration and the user's data folders are never read or written.
# Host: Windows PowerShell 5.1 and an installed Rainmeter (nothing is installed).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvLua.ps1
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Queue\QueueReader.lua'))
$suiteSourcePath = Join-Path $PSScriptRoot 'TvReaderSuite.luatest'
# Further pairs: production source, its copy's name, suite, its copy's name.
$others = @(
    @([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Connections\TvConnections.lua')), 'TvConnections.lua', (Join-Path $PSScriptRoot 'TvConnectionsSuite.luatest'), 'TvConnectionsSuite.lua'),
    @([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\MediaLifecycle.lua')), 'MediaLifecycle.lua', (Join-Path $PSScriptRoot 'TvLifecycleSuite.luatest'), 'TvLifecycleSuite.lua'),
    # Media's player card: one field for a meter (stage 3).
    @([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\TvField.lua')), 'TvField.lua', (Join-Path $PSScriptRoot 'TvFieldSuite.luatest'), 'TvFieldSuite.lua')
)
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-TvReader-test-' + [Guid]::NewGuid().ToString('N'))))
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent must not be a junction.' }
foreach ($required in @($RainmeterPath, $sourcePath, $suiteSourcePath) + @($others | ForEach-Object { $_[0]; $_[2] })) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}
function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the run directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'TvReaderBehaviorTest'
foreach ($directory in @($runRoot, $skinRoot, $configRoot)) { $null = New-Item -ItemType Directory -Path $directory }
$productionPath = Join-Path $runRoot 'QueueReader.lua'
$suitePath = Join-Path $runRoot 'TvReaderSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
foreach ($path in @($productionPath, $suitePath, $resultPath)) { if ($path.Contains(']=]') -or $path.Contains('"')) { throw 'Unsupported test path.' } }
# Rainmeter loads the UTF-16LE reader as UTF-8; Lua's loadfile does not, so the
# same text is handed to the suite as UTF-8.
$bytes = [IO.File]::ReadAllBytes($sourcePath)
if ($bytes.Length -lt 2 -or $bytes[0] -ne 0xFF -or $bytes[1] -ne 0xFE) { throw 'QueueReader must keep its UTF-16LE BOM.' }
Write-TestFile $productionPath ([IO.File]::ReadAllText($sourcePath))
Copy-Item -LiteralPath $suiteSourcePath -Destination $suitePath
foreach ($pair in $others) {
    Copy-Item -LiteralPath $pair[0] -Destination (Join-Path $runRoot $pair[1])
    Copy-Item -LiteralPath $pair[2] -Destination (Join-Path $runRoot $pair[3])
}
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
Write-TestFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[TvReaderBehaviorTest]
Active=1
WindowX=-32000
WindowY=-32000
KeepOnScreen=0
SavePosition=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-TestFile (Join-Path $configRoot 'Test.ini') @"
[Rainmeter]
Update=-1
DynamicWindowSize=0
OnRefreshAction=[!CommandMeasure TestHarness "AuditAndQuit()"]

[TestHarness]
Measure=Script
ScriptFile=$runRoot\Harness.lua

[MeterBounds]
Meter=Image
X=0
Y=0
W=1
H=1
SolidColor=0,0,0,0
"@
Write-TestFile (Join-Path $runRoot 'Harness.lua') @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local total, lines = 0, {}
        for _, pair in ipairs({ { [=[$suitePath]=], [=[$productionPath]=] },
            { [=[$runRoot\TvConnectionsSuite.lua]=], [=[$runRoot\TvConnections.lua]=] },
            { [=[$runRoot\TvLifecycleSuite.lua]=], [=[$runRoot\MediaLifecycle.lua]=] },
            { [=[$runRoot\TvFieldSuite.lua]=], [=[$runRoot\TvField.lua]=] } }) do
            local suite = dofile(pair[1])
            local count, cases = suite.run(pair[2])
            total = total + count
            for _, line in ipairs(cases) do lines[#lines + 1] = line end
        end
        return 'PASS: '..total..' assertions in '..#lines..' synthetic TV skin scenarios; '.._VERSION..'.\n'
            ..table.concat(lines, '\n')..'\nReader SHA256: $sourceHash\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@
try {
    # The absolute settings file selects a separate Rainmeter instance. No
    # command-line bangs, no process-name targeting.
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated TV drawer tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'TV drawer tests failed.' }
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
