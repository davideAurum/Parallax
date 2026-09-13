# Developer-only synthetic native Lua checks; excluded from skin packaging.
# Copies sources into a unique temp root. Never reads live queue/auth storage.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\QueueReader.lua'))
$optionsSourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\MediaOptions.lua'))
$suiteSourcePath = Join-Path $PSScriptRoot 'QueueReaderSuite.luatest'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-QueueReader-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Run path must remain inside the temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent must not be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test run root must be fresh.' }
foreach ($required in @($RainmeterPath, $sourcePath, $optionsSourcePath, $suiteSourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}

function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes generated run directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'QueueReaderBehaviorTest'
foreach ($directory in @($runRoot, $skinRoot, $configRoot, "$runRoot\Production", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $directory
}
$productionPath = Join-Path $runRoot 'Production\QueueReader.lua'
$optionsProductionPath = Join-Path $runRoot 'Production\MediaOptions.lua'
$suitePath = Join-Path $runRoot 'QueueReaderSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
$scratchPath = Join-Path $runRoot 'synthetic.snapshot'
foreach ($path in @($productionPath, $suitePath, $resultPath, $scratchPath, $runRoot)) {
    if ($path.Contains(']=]') -or $path.Contains('"') -or $path.Contains("`r") -or $path.Contains("`n")) { throw 'Unsupported test path delimiter.' }
}
# Rainmeter loads UTF-16LE scripts as UTF-8 chunks. Lua's standalone loadfile
# does not, so mirror only that decoding for the injected parser/mock suite.
# Test-QueueView.ps1 separately loads the unchanged production bytes natively.
$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
if ($sourceBytes.Length -lt 2 -or $sourceBytes[0] -ne 0xFF -or $sourceBytes[1] -ne 0xFE) {
    throw 'QueueReader must retain UTF-16LE BOM for Rainmeter 4.5 Unicode APIs.'
}
Write-TestFile $productionPath ([IO.File]::ReadAllText($sourcePath))
Write-TestFile $optionsProductionPath ([IO.File]::ReadAllText($optionsSourcePath))
Copy-Item -LiteralPath $suiteSourcePath -Destination $suitePath
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$optionsSourceHash = (Get-FileHash -LiteralPath $optionsSourcePath -Algorithm SHA256).Hash
Write-TestFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[QueueReaderBehaviorTest]
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
        local suite = dofile([=[$suitePath]=])
        local count, cases = suite.run([=[$productionPath]=], [=[$scratchPath]=], [=[$optionsProductionPath]=])
        return 'PASS: '..count..' assertions in '..#cases..' synthetic queue-reader scenarios; '.._VERSION..'.\n'
            ..table.concat(cases, '\n')..'\nProduction SHA256: $sourceHash\n'
            ..'Accordion SHA256: $optionsSourceHash\n'
            ..'Snapshot reader only. No Spotify request, authorization, live cache, live Rainmeter configuration, screenshot or performance verification.\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@

try {
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container) -or -not (Test-Path -LiteralPath $iniPath -PathType Leaf)) { throw 'Isolation preflight failed.' }
    # Existing absolute INI and SkinPath select a separate Rainmeter instance.
    # No CLI bangs and no process-name targeting are used.
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $evidence = [ordered]@{
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        OwnedPid = $testProcess.Id
        RainmeterVersion = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion
        IniPath = $iniPath
        SkinPath = $skinRoot
        TestedSourceSha256 = $sourceHash
        TestedAccordionSha256 = $optionsSourceHash
        SourceEncoding = 'UTF-16LE BOM; same text decoded to UTF-8 for Lua loadfile mock tests'
        SuiteSha256 = (Get-FileHash -LiteralPath $suitePath -Algorithm SHA256).Hash
        Provider = 'None; injected synthetic snapshots only'
    }
    Write-TestFile (Join-Path $runRoot 'run-evidence.json') ($evidence | ConvertTo-Json)
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated queue-reader tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Queue-reader behavior tests failed.' }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        if ($errors.Count) { $errors | Write-Output; throw 'Isolated Rainmeter logged errors.' }
    }
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Production source changed during the test; rerun for current evidence.' }
    if ((Get-FileHash -LiteralPath $optionsSourcePath -Algorithm SHA256).Hash -ne $optionsSourceHash) { throw 'Accordion source changed during the test; rerun for current evidence.' }
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
    # Retain synthetic evidence; no recursive deletion or other process changes.
}
