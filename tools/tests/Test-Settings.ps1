[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runRoot = Join-Path $projectRoot ('build\settings-test-' + [Guid]::NewGuid().ToString('N'))
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = Join-Path $skinRoot 'Parallax'
$testProcess = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed by this test.' }
foreach ($ancestor in @($projectRoot, (Join-Path $projectRoot 'build'))) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test parent must not be a junction.' }
}
foreach ($dir in @($runRoot, $skinRoot, $parallaxRoot, "$parallaxRoot\Settings", "$parallaxRoot\@Resources", "$parallaxRoot\@Resources\User", "$parallaxRoot\@Resources\Scripts", "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) {
    $null = New-Item -ItemType Directory -Path $dir
}
$sourceRoot = Join-Path $projectRoot 'Skins\Parallax'
foreach ($file in @('Defaults.inc','Geometry.inc','Styles.inc','User\Settings.inc','Scripts\Settings.lua')) {
    Copy-Item -LiteralPath (Join-Path "$sourceRoot\@Resources" $file) -Destination (Join-Path "$parallaxRoot\@Resources" $file)
}
Copy-Item -LiteralPath "$sourceRoot\@Resources\Fonts" -Destination "$parallaxRoot\@Resources\Fonts" -Recurse
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$resultPath = Join-Path $runRoot 'results.txt'
$suitePath = Join-Path $PSScriptRoot 'SettingsSuite.lua'
$productionPath = Join-Path $parallaxRoot '@Resources\Scripts\Settings.lua'
foreach ($path in @($runRoot,$suitePath,$productionPath,$resultPath)) {
    if ($path.Contains(']=]')) { throw 'Unsupported Lua delimiter in test path.' }
}
$encoding = [Text.UTF8Encoding]::new($false)
$settings = Get-Content -LiteralPath "$sourceRoot\Settings\Settings.ini" -Raw
$settings = $settings.Replace('Update=-1', 'Update=-1' + "`r`nOnRefreshAction=[!CommandMeasure TestHarness `"AuditAndQuit()`"]")
$settings += "`r`n[TestHarness]`r`nMeasure=Script`r`nScriptFile=$runRoot\Harness.lua`r`n"
[IO.File]::WriteAllText("$parallaxRoot\Settings\Settings.ini", $settings, $encoding)
[IO.File]::WriteAllText($iniPath, @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033

[Parallax\Settings]
Active=1
WindowX=0
WindowY=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@, $encoding)
[IO.File]::WriteAllText("$runRoot\Rainmeter.data", "[Rainmeter]`n", $encoding)
$meters = [regex]::Matches($settings, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { "'" + $_.Groups[1].Value + "'" }
$meterList = $meters -join ','
[IO.File]::WriteAllText("$runRoot\Harness.lua", @"
function Initialize() end
function Update() return 0 end
function AuditAndQuit()
    local ok, report = pcall(function()
        local suite = dofile([=[$suitePath]=])
        local count = suite.run([=[$productionPath]=])
        assert(SKIN:GetVariable('Columns') == '2', 'Include precedence lost double width')
        assert(SKIN:GetVariable('PanelHeight') == '758', 'Include precedence lost settings height')
        local bounds = assert(SKIN:GetMeter('MeterBounds'))
        local w, h = bounds:GetW(), bounds:GetH()
        assert(w == 456 and h == 766, 'Unexpected default bounds: '..w..'x'..h)
        for _, name in ipairs({$meterList}) do
            local meter = assert(SKIN:GetMeter(name))
            assert(meter:GetX() >= 0 and meter:GetY() >= 0, name..' begins outside window')
            assert(meter:GetX()+meter:GetW() <= w+1 and meter:GetY()+meter:GetH() <= h+1, name..' exceeds window bounds')
            count = count + 1
        end
        return 'PASS: '..count..' Lua assertions and native meter-bound checks; '.._VERSION..'; default window '..w..'x'..h..'.\nRendering appearance, DPI and performance still require visual/live QA.\n'
    end)
    if not ok then report = 'FAIL: '..tostring(report)..'\n' end
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    file:write(report); file:close()
    SKIN:Bang('!Quit')
end
"@, $encoding)
try {
    # A distinct existing absolute INI/SkinPath isolates Rainmeter's instance and all writes.
    # Never dispatch CLI bangs, which could address the user's existing process.
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    if (-not $testProcess.WaitForExit(20000)) { throw 'Isolated Settings test timed out.' }
    if (-not (Test-Path -LiteralPath $resultPath)) { throw "No report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $report
    if ($report -notmatch '^PASS:') { throw 'Settings test failed.' }
    Write-Output "Isolated evidence retained at $runRoot"
} finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null = $testProcess.WaitForExit(5000) }
        $testProcess.Dispose()
    }
}
