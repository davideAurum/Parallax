# Developer-only native Lua tests. Synthetic measures; no WebNowPlaying or auth.
# Pattern: tools/tests/Test-Settings.ps1. All writes stay in a fresh temp root.
# Official Lua API: https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Media.lua'))
$sourceSuitePath = Join-Path $PSScriptRoot 'MediaSuite.luatest'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-Media-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Test root must be inside the temp parent.' }
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test installs nothing.' }
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw 'Production Media.lua is missing.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test run root must be fresh.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test temp parent must not be a junction.' }

$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'MediaBehaviorTest'
foreach ($dir in @($runRoot, $skinRoot, $configRoot, "$runRoot\Production", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $dir
}
$productionPath = Join-Path $runRoot 'Production\Media.lua'
$suitePath = Join-Path $runRoot 'MediaSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
$evidencePath = Join-Path $runRoot 'run-evidence.json'
foreach ($path in @($suitePath, $productionPath, $resultPath, $runRoot)) {
    if ($path.Contains(']=]') -or $path.Contains('"') -or $path.Contains("`r") -or $path.Contains("`n")) { throw 'Unsupported delimiter in test path.' }
}
Copy-Item -LiteralPath $sourcePath -Destination $productionPath
Copy-Item -LiteralPath $sourceSuitePath -Destination $suitePath
$sourceHash = (Get-FileHash -LiteralPath $productionPath -Algorithm SHA256).Hash
$encoding = [Text.UTF8Encoding]::new($false)

[IO.File]::WriteAllText($iniPath, @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033

[MediaBehaviorTest]
Active=1
WindowX=-32000
WindowY=-32000
KeepOnScreen=0
SavePosition=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@, $encoding)
[IO.File]::WriteAllText("$runRoot\Rainmeter.data", "[Rainmeter]`n", $encoding)
[IO.File]::WriteAllText("$configRoot\Test.ini", @"
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
"@, $encoding)
[IO.File]::WriteAllText("$runRoot\Harness.lua", @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local suite = dofile([=[$suitePath]=])
        local count, cases = suite.run([=[$productionPath]=])
        return 'PASS: '..count..' assertions in '..#cases..' synthetic Media scenarios; '.._VERSION..'.\n'
            ..table.concat(cases, '\n')..'\n'
            ..'Production SHA256: $sourceHash\n'
            ..'Adapter behavior only. No WNP, authentication, live Rainmeter settings, screenshot, DPI or performance verification.\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    file:write(report)
    file:close()
    SKIN:Bang('!Quit')
end
"@, $encoding)

try {
    # A fresh existing absolute INI + SkinPath selects an isolated instance.
    # Never dispatch CLI bangs or address a process by its executable name.
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $evidence = [ordered]@{
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        OwnedPid = $testProcess.Id
        RainmeterPath = [IO.Path]::GetFullPath($RainmeterPath)
        RainmeterVersion = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion
        IniPath = $iniPath
        SkinPath = $skinRoot
        SourcePath = $sourcePath
        TestedSourceSha256 = $sourceHash
        SuiteSha256 = (Get-FileHash -LiteralPath $suitePath -Algorithm SHA256).Hash
        Provider = 'none; synthetic fixtures only'
    }
    [IO.File]::WriteAllText($evidencePath, ($evidence | ConvertTo-Json), $encoding)
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated Media tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No result report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Media behavior tests failed.' }
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Production source changed during the test; results cover only the retained snapshot.' }
    Write-Output "Isolated evidence retained at $runRoot"
} finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) {
            Stop-Process -InputObject $testProcess -Force
            $null = $testProcess.WaitForExit(5000)
        }
        $testProcess.Dispose()
    }
    # Retain the fresh temp evidence. No files or other Rainmeter PIDs are deleted.
}
