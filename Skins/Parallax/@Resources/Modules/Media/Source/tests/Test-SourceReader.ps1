# Developer-only synthetic native Lua checks; excluded from skin packaging.
# Copies sources into a unique temp root. Never reads live source storage.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$sourcePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SourceReader.lua'))
$suiteSourcePath = Join-Path $PSScriptRoot 'SourceReaderSuite.luatest'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-SourceReader-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Run path must remain inside the temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent must not be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test run root must be fresh.' }
foreach ($required in @($RainmeterPath, $sourcePath, $suiteSourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}

function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes generated run directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

$skinRoot = Join-Path $runRoot 'Skins'
$configRoot = Join-Path $skinRoot 'SourceReaderBehaviorTest'
foreach ($directory in @($runRoot, $skinRoot, $configRoot, "$runRoot\Production", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $directory
}
$productionPath = Join-Path $runRoot 'Production\SourceReader.lua'
$suitePath = Join-Path $runRoot 'SourceReaderSuite.lua'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
$scratchPath = Join-Path $runRoot 'synthetic.snapshot'
$nativePath = Join-Path $runRoot 'Production\NativeSourceReader.lua'
$nativeSnapshot = Join-Path $runRoot 'native.snapshot'
$nativeTitle = 'Caf' + [char]0xE9 + ' ' + [char]0x6F22
$nativeTitleHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($nativeTitle)).Replace('-','')
$nativeArtistHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes('Fixture artist')).Replace('-','')
foreach ($path in @($productionPath, $suitePath, $resultPath, $scratchPath, $runRoot)) {
    if ($path.Contains(']=]') -or $path.Contains('"') -or $path.Contains("`r") -or $path.Contains("`n")) { throw 'Unsupported test path delimiter.' }
}
# Rainmeter loads UTF-16LE scripts as UTF-8 chunks. Lua's standalone loadfile
# does not, so mirror only that decoding for the injected parser/mock suite.
# The synthetic native binding case separately loads the unchanged production bytes.
$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
if ($sourceBytes.Length -lt 2 -or $sourceBytes[0] -ne 0xFF -or $sourceBytes[1] -ne 0xFE) {
    throw 'SourceReader must retain UTF-16LE BOM for Rainmeter 4.5 Unicode APIs.'
}
Write-TestFile $productionPath ([IO.File]::ReadAllText($sourcePath))
Copy-Item -LiteralPath $sourcePath -Destination $nativePath
Copy-Item -LiteralPath $suiteSourcePath -Destination $suitePath
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
Write-TestFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[SourceReaderBehaviorTest]
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

[MeasureConnection]
Measure=Calc
Formula=1

[MeasurePlayer]
Measure=String
String=Windows Media Session
DynamicVariables=1

[MeasureTitle]
Measure=String
String=$nativeTitle
DynamicVariables=1

[MeasureSourceArtist]
Measure=String
String=Fixture artist
DynamicVariables=1

[MeasureState]
Measure=Calc
Formula=1
DynamicVariables=1

[MeasureMediaSource]
Measure=Script
ScriptFile=$nativePath
SourceCachePath=$nativeSnapshot

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

[MeterPlayerName]
Meter=String
MeasureName=MeasureMediaSource
X=0
Y=0
W=1
H=1
Hidden=1
"@
[IO.File]::WriteAllText((Join-Path $configRoot 'Test.ini'), $nativeIni, [Text.UnicodeEncoding]::new($false,$true))
$harness = @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local suite = dofile([=[$suitePath]=])
        local count, cases = suite.run([=[$productionPath]=], [=[$scratchPath]=])
        local function equal(actual, expected)
            count = count + 1
            assert(actual == expected, 'native binding: '..tostring(actual)..' ~= '..tostring(expected))
        end
        local function change(name, option, value)
            SKIN:Bang('!SetOption', name, option, value)
            SKIN:Bang('!UpdateMeasure', name)
        end
        local function publish(duplicate, age)
            local now = os.time() - (age or 0)
            local lines = {'PARALLAX_SOURCE_V1','state=ready','observed='..now,
                'valid_until='..(now+6),'count='..(duplicate and 2 or 1)}
            for i=1,(duplicate and 2 or 1) do
                lines[#lines+1]='source'..i..'='..(i==1 and 'spotify' or 'other')
                lines[#lines+1]='title'..i..'=$nativeTitleHex'
                lines[#lines+1]='artist'..i..'=$nativeArtistHex'
                lines[#lines+1]='playing'..i..'=1'
            end
            local file = assert(io.open([=[$nativeSnapshot]=], 'wb'))
            assert(file:write(table.concat(lines,'\n')..'\n')); assert(file:close())
        end
        local function label()
            SKIN:Bang('!UpdateMeasure','MeasureMediaSource')
            return SKIN:GetMeasure('MeasureMediaSource'):GetStringValue()
        end
        publish(false)
        equal(label(),'Spotify')
        equal(SKIN:GetMeter('MeterPlayerName'):GetOption('ToolTipText'),
            'Spotify desktop detected from one matching Windows media session.')
        change('MeasureSourceArtist','String','')
        equal(label(),'Windows')
        change('MeasureSourceArtist','String','Fixture artist')
        equal(label(),'Spotify')
        publish(true)
        equal(label(),'Windows')
        publish(false,7)
        equal(label(),'Windows')
        change('MeasurePlayer','String','YouTube')
        equal(label(),'YouTube')
        equal(SKIN:GetMeter('MeterPlayerName'):GetOption('ToolTipText'),'Source reported by WebNowPlaying.')
        cases[#cases+1]='native UTF-16 script binding: Unicode match, raw artist, ambiguity, expiry and direct provider'
        return 'PASS: '..count..' assertions in '..#cases..' synthetic source-reader scenarios; '.._VERSION..'.\n'
            ..table.concat(cases, '\n')..'\nProduction SHA256: $sourceHash\n'
            ..'Snapshot reader only. No Spotify request, authorization, live cache, live Rainmeter configuration, screenshot or performance verification.\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@
[IO.File]::WriteAllText((Join-Path $runRoot 'Harness.lua'), $harness, [Text.UnicodeEncoding]::new($false,$true))

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
        SourceEncoding = 'UTF-16LE BOM; same text decoded to UTF-8 for Lua loadfile mock tests'
        SuiteSha256 = (Get-FileHash -LiteralPath $suitePath -Algorithm SHA256).Hash
        Provider = 'None; injected synthetic snapshots only'
    }
    Write-TestFile (Join-Path $runRoot 'run-evidence.json') ($evidence | ConvertTo-Json)
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated source-reader tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Source-reader behavior tests failed.' }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        if ($errors.Count) { $errors | Write-Output; throw 'Isolated Rainmeter logged errors.' }
    }
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Production source changed during the test; rerun for current evidence.' }
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
