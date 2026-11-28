# Developer-only synthetic Lua checks for casts: a followed cast in Media's reader
# (QueueReader.lua) and Connections' Casts row (CastConnections.lua). Same method
# as Test-TvLua.ps1: the sources are copied into a fresh temp root and run in a
# separate Rainmeter instance with its own settings file and skin path; the live
# Rainmeter configuration and the user's data folders are never read or written.
# Host: Windows PowerShell 5.1 and an installed Rainmeter (nothing is installed).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastLua.ps1
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))

$ErrorActionPreference = 'Stop'
$testProcess = $null
$readerPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Queue\QueueReader.lua'))
$pairs = @(
    @($readerPath, 'QueueReader.lua', (Join-Path $PSScriptRoot 'TvCastSuite.luatest'), 'TvCastSuite.lua'),
    @([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Connections\CastConnections.lua')), 'CastConnections.lua', (Join-Path $PSScriptRoot 'CastConnectionsSuite.luatest'), 'CastConnectionsSuite.lua')
)
foreach ($required in @($RainmeterPath) + @($pairs | ForEach-Object { $_[0]; $_[2] })) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required installed executable or source is missing: $required. Nothing is installed by this runner." }
}
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-TvCastLua-test-' + [Guid]::NewGuid().ToString('N'))))
function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the run directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
$configRoot = Join-Path $runRoot 'Skins\TvCastLuaTest'
$null = New-Item -ItemType Directory -Path $configRoot -Force
if ($runRoot.Contains(']=]') -or $runRoot.Contains('"')) { throw 'Unsupported test path.' }
# Rainmeter loads the UTF-16LE reader as UTF-8; Lua's loadfile does not, so the
# same text is handed to the suite as UTF-8.
$bytes = [IO.File]::ReadAllBytes($readerPath)
if ($bytes.Length -lt 2 -or $bytes[0] -ne 0xFF -or $bytes[1] -ne 0xFE) { throw 'QueueReader must keep its UTF-16LE BOM.' }
$runs = [Collections.Generic.List[string]]::new()
foreach ($pair in $pairs) {
    $production = Join-Path $runRoot $pair[1]
    if ($pair[1] -ceq 'QueueReader.lua') { Write-TestFile $production ([IO.File]::ReadAllText($pair[0])) } else { Copy-Item -LiteralPath $pair[0] -Destination $production }
    Copy-Item -LiteralPath $pair[2] -Destination (Join-Path $runRoot $pair[3])
    $runs.Add("{ [=[$runRoot\$($pair[3])]=], [=[$production]=] }")
}
# The Casts suite also loads the TV row's controller beside it (one shared host).
$tvConnections = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Connections\TvConnections.lua'))
Copy-Item -LiteralPath $tvConnections -Destination (Join-Path $runRoot 'TvConnections.lua')
$resultPath = Join-Path $runRoot 'results.txt'
Write-TestFile (Join-Path $runRoot 'Rainmeter.ini') "[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[TvCastLuaTest]`nActive=1`nWindowX=-32000`nWindowY=-32000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-TestFile (Join-Path $configRoot 'Test.ini') "[Rainmeter]`nUpdate=-1`nDynamicWindowSize=0`nOnRefreshAction=[!CommandMeasure TestHarness `"AuditAndQuit()`"]`n`n[TestHarness]`nMeasure=Script`nScriptFile=$runRoot\Harness.lua`n`n[MeterBounds]`nMeter=Image`nX=0`nY=0`nW=1`nH=1`nSolidColor=0,0,0,0`n`n[MeterProbe]`nMeter=String`nX=0`nY=0`nText=before`n"
Write-TestFile (Join-Path $runRoot 'Harness.lua') @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local total, lines = 0, {}
        -- Native: the Casts row relies on a !SetOption and a !SetVariable being
        -- readable at once, before any update, as the two rows share one host.
        SKIN:Bang('!SetOption', 'MeterProbe', 'Text', 'Starting the TV worker...')
        assert(SKIN:GetMeter('MeterProbe'):GetOption('Text', '') == 'Starting the TV worker...', 'SetOption is not readable at once')
        SKIN:Bang('!SetVariable', 'CastCommandBusyUntil', '123')
        assert(SKIN:GetVariable('CastCommandBusyUntil', '0') == '123', 'SetVariable is not readable at once')
        lines[#lines + 1] = 'native: SetOption and SetVariable are readable at once: 2 assertions'
        total = total + 2
        for _, pair in ipairs({ $($runs -join ', ') }) do
            local suite = dofile(pair[1])
            local count, cases = suite.run(pair[2])
            total = total + count
            for _, line in ipairs(cases) do lines[#lines + 1] = line end
        end
        return 'PASS: '..total..' assertions in '..#lines..' synthetic cast scenarios; '.._VERSION..'.\n'..table.concat(lines, '\n')..'\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    assert(file:write(report)); assert(file:close())
    SKIN:Bang('!Quit')
end
"@
try {
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $runRoot 'Rainmeter.ini')) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated cast Lua tests timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "No test report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Cast Lua tests failed.' }
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
