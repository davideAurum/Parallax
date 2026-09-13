# Developer-only synthetic native Lua checks; excluded from skin packaging.
# Every write and Rainmeter instance belongs to a fresh temp root. No providers.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\MediaHeader.lua'))
$headerSourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Header.inc'))
$suiteSourcePath = Join-Path $PSScriptRoot 'MediaHeaderSuite.luatest'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-MediaHeader-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Run path must remain inside the temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent must not be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test run root must be fresh.' }
foreach ($required in @($RainmeterPath, $sourcePath, $headerSourcePath, $suiteSourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}

function Write-TestFile([string]$Path, [string]$Content, [switch]$Unicode) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes generated run directory.' }
    $encoding = if ($Unicode) { [Text.UnicodeEncoding]::new($false, $true) } else { [Text.UTF8Encoding]::new($false) }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'MediaHeaderBehaviorTest'
foreach ($directory in @($runRoot, $skinRoot, $configRoot, "$runRoot\Production", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $directory
}
$productionPath = Join-Path $runRoot 'Production\MediaHeader.lua'
$nativePath = Join-Path $runRoot 'Production\NativeMediaHeader.lua'
$nativeHeaderPath = Join-Path $runRoot 'Production\NativeHeader.inc'
$suitePath = Join-Path $runRoot 'MediaHeaderSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
$nativeName = 'Caf' + [char]0xE9 + ' ' + [char]0x6F22 + ' ' + [char]::ConvertFromUtf32(0x1F3B5)
foreach ($path in @($productionPath, $suitePath, $resultPath, $runRoot)) {
    if ($path.Contains(']=]') -or $path.Contains('"') -or $path.Contains("`r") -or $path.Contains("`n")) { throw 'Unsupported test path delimiter.' }
}
# Rainmeter performs this UTF-16 to UTF-8 decoding for its Lua chunks. loadfile
# does not, so only the mocked suite uses the decoded copy. Native binding below
# loads the unchanged production bytes and proves Unicode API behavior directly.
$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
if ($sourceBytes.Length -lt 2 -or $sourceBytes[0] -ne 0xFF -or $sourceBytes[1] -ne 0xFE) { throw 'MediaHeader must retain UTF-16LE BOM for Rainmeter 4.5 Unicode APIs.' }
Write-TestFile $productionPath ([IO.File]::ReadAllText($sourcePath))
Copy-Item -LiteralPath $sourcePath -Destination $nativePath
Copy-Item -LiteralPath $headerSourcePath -Destination $nativeHeaderPath
Copy-Item -LiteralPath $suiteSourcePath -Destination $suitePath
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$headerHash = (Get-FileHash -LiteralPath $headerSourcePath -Algorithm SHA256).Hash
Write-TestFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[MediaHeaderBehaviorTest]
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
$nativeIni = @"
[Rainmeter]
Update=-1
DynamicWindowSize=0
OnRefreshAction=[!CommandMeasure TestHarness "AuditAndQuit()"]

[Variables]
NativeStage=0
HeaderToken=EXPANDED_UNEXPECTEDLY
MediaHeaderInjected=0
HeaderIconRefreshSeen=0
ContentX=0
TitleIconSize=14
TitleRowCenterY=10
MediaSurfaceOffset=0
MediaColor=137,190,250

[MeasureConnection]
Measure=Script
ScriptFile=$runRoot\FixtureMeasures.lua
Field=connection
Group=HeaderInputs

[MeasurePlayer]
Measure=Script
ScriptFile=$runRoot\FixtureMeasures.lua
Field=player
Group=HeaderInputs

[MeasureMediaSource]
Measure=Script
ScriptFile=$runRoot\FixtureMeasures.lua
Field=source
Group=HeaderInputs

[MeasureTitle]
Measure=Script
ScriptFile=$runRoot\FixtureMeasures.lua
Field=title
Group=HeaderInputs
@Include1=$nativeHeaderPath

; Override only the script's copied path; the actual icon include is unchanged.
[MeasureMediaHeader]
ScriptFile=$nativePath

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

[MeterHeading]
Meter=String
MeasureName=MeasureMediaHeader
Text=Media Player: %1
ToolTipText=Media Player: %1
UpdateDivider=1
W=100
H=20
ClipString=1

[MeterMediaIcon]
OnUpdateAction=[!SetVariable HeaderIconRefreshSeen 1]
"@
Write-TestFile (Join-Path $configRoot 'Test.ini') $nativeIni -Unicode
Write-TestFile (Join-Path $runRoot 'FixtureMeasures.lua') @"
local samples = {
    [0] = { player='Spotify', source='Spotify' },
    { player='YouTube', source='Spotify' },
    { player='Windows Media Session', source='Windows' },
    { player='$nativeName', source='Spotify' },
    { player='[!SetVariable MediaHeaderInjected 1]#HeaderToken#[MeasureConnection]', source='Spotify' },
    { player='Windows Media Session', source='Spotify' },
    { player='Windows Media Session', source='Windows' },
    { player='Spotify', source='Spotify', connection=0 },
    { player='Spotify', source='Spotify', title='' },
    { player='VLC', source='Spotify' },
    { player='Windows Media Player', source='Spotify' },
    { player='Apple Music', source='Spotify' }
}
function Initialize() end
function Update()
    local sample = assert(samples[tonumber(SKIN:GetVariable('NativeStage'))])
    local field = SELF:GetOption('Field')
    if field == 'connection' then return sample.connection or 1 end
    if field == 'title' then return sample.title or 'Synthetic native title' end
    return assert(sample[field])
end
"@ -Unicode
$harness = @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local suite = dofile([=[$suitePath]=])
        local count, cases = suite.run([=[$productionPath]=])
        local function equal(actual, expected)
            count = count + 1
            assert(actual == expected, 'native binding: '..tostring(actual)..' ~= '..tostring(expected))
        end
        local function stage(index, expected)
            SKIN:Bang('!SetVariable', 'HeaderIconRefreshSeen', '0')
            SKIN:Bang('!SetVariable', 'NativeStage', tostring(index))
            SKIN:Bang('!UpdateMeasureGroup', 'HeaderInputs')
            SKIN:Bang('!UpdateMeasure', 'MeasureMediaHeader')
            equal(SKIN:GetMeasure('MeasureMediaHeader'):GetStringValue(), expected)
            equal(SKIN:GetVariable('HeaderIconRefreshSeen'), '0')
            equal(SKIN:GetVariable('MediaHeaderInjected'), '0')
            equal(SKIN:GetMeter('MeterMediaIcon'):GetW(), 14)
            equal(SKIN:GetMeter('MeterMediaIcon'):GetH(), 14)
        end
        stage(0, 'Spotify')
        stage(1, 'YouTube')
        stage(1, 'YouTube')
        stage(2, 'Unknown')
        stage(3, '$nativeName')
        stage(4, '[!SetVariable MediaHeaderInjected 1]#HeaderToken#[MeasureConnection]')
        stage(5, 'Spotify')
        stage(6, 'Unknown')
        stage(7, 'Not connected')
        stage(8, 'Idle')
        stage(9, 'VLC')
        stage(10, 'Windows Media Player')
        stage(11, 'Apple Music')
        equal(SKIN:GetMeter('MeterHeading'):GetOption('MeasureName'), 'MeasureMediaHeader')
        equal(SKIN:GetMeter('MeterHeading'):GetOption('Text'), 'Media Player: %1')
        equal(SKIN:GetMeter('MeterHeading'):GetOption('ToolTipText'), 'Media Player: %1')
        equal(SKIN:GetMeter('MeterHeading'):GetOption('DynamicVariables', '0'), '0')
        equal(SKIN:GetMeter('MeterMediaIcon'):GetOption('Meter'), 'Shape')
        equal(SKIN:GetMeter('MeterMediaIcon'):GetOption('Hidden'), '0')
        equal(SKIN:GetMeter('MeterMediaIcon'):GetOption('UpdateDivider'), '-1')
        equal(SKIN:GetMeter('MeterMediaIcon'):GetOption('Shape'), 'Path LucideMonitorPlayPath | Extend LucideMonitorPlayStroke')
        cases[#cases+1] = 'native unchanged UTF-16 script and icon include: literal Unicode, injection data and constant monitor-play across name transitions'
        return 'PASS: '..count..' assertions in '..#cases..' synthetic header scenarios; '.._VERSION..'.\n'
            ..table.concat(cases, '\n')..'\nProduction SHA256: $sourceHash\nHeader include SHA256: $headerHash\n'
            ..'Synthetic measures only. No WNP plugin, native sessions, network, auth, live cache, live configuration or screenshot verification.\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@
Write-TestFile (Join-Path $runRoot 'Harness.lua') $harness -Unicode

try {
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container) -or -not (Test-Path -LiteralPath $iniPath -PathType Leaf)) { throw 'Isolation preflight failed.' }
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $evidence = [ordered]@{
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        OwnedPid = $testProcess.Id
        RainmeterVersion = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion
        IniPath = $iniPath
        SkinPath = $skinRoot
        TestedSourceSha256 = $sourceHash
        TestedHeaderIncludeSha256 = $headerHash
        SourceEncoding = 'UTF-16LE BOM; same text decoded to UTF-8 for Lua loadfile mock tests'
        SuiteSha256 = (Get-FileHash -LiteralPath $suitePath -Algorithm SHA256).Hash
        Provider = 'None; injected synthetic measures only'
    }
    Write-TestFile (Join-Path $runRoot 'run-evidence.json') ($evidence | ConvertTo-Json)
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated header tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Header behavior tests failed.' }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        if ($errors.Count) { $errors | Write-Output; throw 'Isolated Rainmeter logged errors.' }
    }
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Production source changed during the test; rerun for current evidence.' }
    if ((Get-FileHash -LiteralPath $headerSourcePath -Algorithm SHA256).Hash -ne $headerHash) { throw 'Header include changed during the test; rerun for current evidence.' }
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
