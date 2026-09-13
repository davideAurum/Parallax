# Developer-only synthetic native Lua checks; excluded from skin packaging.
# Copies sources into a unique temp root. Never reads real intent/stop/provider storage.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\MediaLifecycle.lua'))
$includeSourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Lifecycle.inc'))
$suiteSourcePath = Join-Path $PSScriptRoot 'MediaLifecycleSuite.luatest'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-MediaLifecycle-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Run path must remain inside the temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent must not be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test run root must be fresh.' }
foreach ($required in @($RainmeterPath, $sourcePath, $includeSourcePath, $suiteSourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}

function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes generated run directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'MediaLifecycleBehaviorTest'
foreach ($directory in @($runRoot, $skinRoot, $configRoot, "$runRoot\Production", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $directory
}
$productionPath = Join-Path $runRoot 'Production\MediaLifecycle.lua'
$includeProductionPath = Join-Path $runRoot 'Production\Lifecycle.inc'
$suitePath = Join-Path $runRoot 'MediaLifecycleSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'

foreach ($path in @($productionPath, $suitePath, $resultPath, $runRoot)) {
    if ($path.Contains(']=]') -or $path.Contains('"') -or $path.Contains("`r") -or $path.Contains("`n")) { throw 'Unsupported test path delimiter.' }
}
# Decode only the copied source for Lua loadfile; the suite injects every I/O,
# environment and Bang interface. No production lifecycle callback is attached
# to the real fixture SKIN and no provider command can reach Rainmeter.
Write-TestFile $productionPath ([IO.File]::ReadAllText($sourcePath))
Write-TestFile $includeProductionPath ([IO.File]::ReadAllText($includeSourcePath))
Copy-Item -LiteralPath $suiteSourcePath -Destination $suitePath
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$includeSourceHash = (Get-FileHash -LiteralPath $includeSourcePath -Algorithm SHA256).Hash
Write-TestFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[MediaLifecycleBehaviorTest]
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
        local count, cases = suite.run([=[$productionPath]=], [=[$includeProductionPath]=])
        return 'PASS: '..count..' assertions in '..#cases..' synthetic lifecycle scenarios; '.._VERSION..'.\n'
            ..table.concat(cases, '\n')..'\nProduction SHA256: $sourceHash\n'
            ..'Lifecycle include SHA256: $includeSourceHash\n'
            ..'Injected lifecycle commands only; none execute. No provider, intent file, environment directory, live settings, network, screenshot or performance verification.\n'
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
        TestedIncludeSha256 = $includeSourceHash
        SourceEncoding = 'Source text decoded to UTF-8 only in copied Lua loadfile mock fixture'
        SuiteSha256 = (Get-FileHash -LiteralPath $suitePath -Algorithm SHA256).Hash
        Provider = 'None; injected intent/stop files, environment and captured Bang strings only'
    }
    Write-TestFile (Join-Path $runRoot 'run-evidence.json') ($evidence | ConvertTo-Json)
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated media-lifecycle tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Media lifecycle behavior tests failed.' }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        if ($errors.Count) { $errors | Write-Output; throw 'Isolated Rainmeter logged errors.' }
    }
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Production source changed during the test; rerun for current evidence.' }
    if ((Get-FileHash -LiteralPath $includeSourcePath -Algorithm SHA256).Hash -ne $includeSourceHash) { throw 'Lifecycle include changed during the test; rerun for current evidence.' }
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
