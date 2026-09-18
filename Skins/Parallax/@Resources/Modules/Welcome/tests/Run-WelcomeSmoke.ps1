#requires -Version 5.1
<#
.SYNOPSIS
Runs the Parallax Welcome checks in an isolated Rainmeter instance.

.DESCRIPTION
Stages the distributable sources, then launches Rainmeter against a generated
settings profile that contains only Parallax\Welcome. A test-only harness runs
the offline WelcomeSuite assertions and then drives the real controller through
a checkbox toggle, Load all and Unload all, recording after each step which
configs Rainmeter itself reports as active. The live Rainmeter installation,
its settings and the user's desktop are never read or changed; every activated
skin is positioned offscreen inside the isolated instance.
#>
[CmdletBinding()]
param(
    [ValidateSet('0.75', '1', '1.25', '1.5', '2')][string]$Scale = '1',
    [ValidateRange(8, 60)][int]$SettleSeconds = 20,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }

$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'welcome-smoke'
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
foreach ($name in @('Layouts', 'Plugins', 'Addons')) { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native Welcome test with harness instrumentation. Do not distribute.`n"

# WebNowPlaying is deliberately absent from this profile. Its host binds a fixed
# local port, so a second copy running in an isolated instance terminates
# Rainmeter when the user's own Rainmeter already hosts it. Media still loads;
# only its player measures report the missing plugin, and those specific errors
# are tolerated in the log check below.

$globalPath = Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$globalText = [regex]::Replace((Get-Content -LiteralPath $globalPath -Raw), '(?m)^Scale=[^\r\n]*', "Scale=$Scale")
Write-RunFile $globalPath $globalText

$components = [ordered]@{
    Chronometer = 'Chronometer.ini'; CPU = 'CPU.ini'; RAM = 'RAM.ini'; GPU = 'GPU.ini'
    IO = 'IO-Disk.ini'; Network = 'Network.ini'; Media = 'Media.ini'
    Visualizer = 'Visualizer.ini'; Settings = 'Settings.ini'
}
foreach ($key in $components.Keys) {
    $configFile = Join-Path $parallaxRoot ("$key\" + $components[$key])
    if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) { throw "Staged component missing: $key\$($components[$key])" }
    $siblings = @(Get-ChildItem -LiteralPath (Split-Path -Parent $configFile) -Filter '*.ini' | Sort-Object Name)
    if ($siblings[0].Name -ne $components[$key]) { throw "$key no longer lists $($components[$key]) first; update the position recorded in Welcome.lua." }
}

$welcomePath = Join-Path $parallaxRoot 'Welcome\Welcome.ini'
$welcomeText = Get-Content -LiteralPath $welcomePath -Raw
foreach ($required in @('[!CommandMeasure MeasureWelcome "LoadAll()"]', '[!CommandMeasure MeasureWelcome "UnloadAll()"]', 'Toggle(''CPU'')')) {
    if (-not $welcomeText.Contains($required) -and -not (Get-Content -LiteralPath (Join-Path $parallaxRoot '@Resources\Modules\Welcome\Rows.inc') -Raw).Contains($required)) {
        throw "Welcome no longer wires $required."
    }
}
$reportPath = Join-Path $runRoot 'welcome-report.txt'
$suitePath = Join-Path $PSScriptRoot 'WelcomeSuite.lua'
$controllerPath = Join-Path $parallaxRoot '@Resources\Modules\Welcome\Welcome.lua'
$harnessPath = Join-Path $runRoot 'WelcomeHarness.lua'
# A literal here-string keeps Lua patterns intact; only the three paths below are
# substituted, and each is a generated path inside this run.
$harness = @'
-- Test-only harness. Reads the isolated settings file with its own parser so the
-- recorded state does not depend on the controller under test.
local step = 0
local lines = {}
local order = {
    { key = 'Chronometer', config = 'parallax\\chronometer' },
    { key = 'CPU', config = 'parallax\\cpu' },
    { key = 'RAM', config = 'parallax\\ram' },
    { key = 'GPU', config = 'parallax\\gpu' },
    { key = 'IO', config = 'parallax\\io' },
    { key = 'Network', config = 'parallax\\network' },
    { key = 'Media', config = 'parallax\\media' },
    { key = 'Visualizer', config = 'parallax\\visualizer' },
    { key = 'Settings', config = 'parallax\\settings' }
}

local function active()
    local file = io.open((SKIN:GetVariable('SETTINGSPATH') or '') .. 'Rainmeter.ini', 'rb')
    if not file then return nil end
    local data = file:read(4 * 1024 * 1024)
    file:close()
    if not data then return nil end
    if data:sub(1, 2) == '\255\254' then
        local out = {}
        for i = 3, #data - 1, 2 do
            local low, high = data:byte(i), data:byte(i + 1)
            out[#out + 1] = (high == 0 and low < 128) and string.char(low) or '\1'
        end
        data = table.concat(out)
    end
    local map, section = {}, nil
    for line in data:gmatch('[^\r\n]+') do
        local name = line:match('^%s*%[(.-)%]%s*$')
        if name then section = name:lower()
        elseif section then
            local key, value = line:match('^%s*([^=]-)%s*=%s*(.-)%s*$')
            if key and key:lower() == 'active' then map[section] = tonumber(value) or 0 end
        end
    end
    return map
end

local function snapshot(label)
    local map = active()
    if not map then lines[#lines + 1] = label .. '=UNREADABLE'; return end
    local loaded, raw = {}, {}
    for _, entry in ipairs(order) do
        if map[entry.config] == 1 then loaded[#loaded + 1] = entry.key end
        raw[#raw + 1] = entry.key .. ':' .. tostring(map[entry.config])
    end
    lines[#lines + 1] = label .. '=' .. table.concat(loaded, ',')
    lines[#lines + 1] = label .. '-active=' .. table.concat(raw, ',')
end

local function command(call) SKIN:Bang('!CommandMeasure', 'MeasureWelcome', call) end

function Initialize() end

function Update()
    step = step + 1
    if step == 1 then
        local suite = assert(loadfile([[__SUITE__]]))()
        local passed, result, detail = pcall(suite.run, [[__CONTROLLER__]])
        lines[#lines + 1] = 'suite=' .. (passed and 'PASS' or 'FAIL')
        if passed then
            lines[#lines + 1] = 'suite-assertions=' .. tostring(result)
            lines[#lines + 1] = 'suite-detail=' .. tostring(detail):gsub('[\r\n]+', ' | ')
        else
            lines[#lines + 1] = 'suite-detail=' .. tostring(result):gsub('[\r\n]+', ' | ')
        end
        snapshot('baseline')
        command("Toggle('CPU')")
    elseif step == 2 then
        snapshot('after-check-cpu')
        command("Toggle('CPU')")
    elseif step == 3 then
        snapshot('after-uncheck-cpu')
        command('LoadAll()')
    elseif step == 4 then
        snapshot('after-load-all')
        command('UnloadAll()')
    elseif step == 5 then
        snapshot('after-unload-all')
        local file = io.open([[__REPORT__]], 'wb')
        if file then
            file:write(table.concat(lines, '\n'), '\nDONE\n')
            file:close()
        end
    end
    return 0
end
'@
$harness = $harness.Replace('__SUITE__', $suitePath).Replace('__CONTROLLER__', $controllerPath).Replace('__REPORT__', $reportPath)
Write-RunFile $harnessPath $harness

# Test-only instrumentation: the shipped panel is event driven (Update=-1) and
# has no timed work. The harness needs a clock to step through the sequence.
$welcomeText = [regex]::new('(?m)^Update=-1\r?$').Replace($welcomeText, 'Update=1000', 1)
if ($welcomeText -notmatch '(?m)^Update=1000\r?$') { throw 'Could not instrument the Welcome update rate.' }
$welcomeText += "`n[MeasureWelcomeHarness]`nMeasure=Script`nScriptFile=$harnessPath`n"
Write-RunFile $welcomePath $welcomeText

$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$ini += "`n[Parallax\Welcome]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
# Seeded inactive entries keep every skin this test activates offscreen and
# click-through inside the isolated instance.
foreach ($key in $components.Keys) {
    $ini += "`n[Parallax\$key]`nActive=0`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
}
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunFile $iniPath $ini
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($SettleSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $reportPath) {
            if ((Get-Content -LiteralPath $reportPath -Raw) -match '(?m)^DONE\r?$') { break }
        }
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated instance exited early; inspect $runRoot\Rainmeter.log" }
    }
    if (-not (Test-Path -LiteralPath $reportPath)) { throw "Harness produced no report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $reportPath
    $values = @{}
    foreach ($line in $report) { if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] } }
    $report | Write-Output

    $all = ($components.Keys -join ',')
    $expected = [ordered]@{
        'suite' = 'PASS'
        'baseline' = ''
        'after-check-cpu' = 'CPU'
        'after-uncheck-cpu' = ''
        'after-load-all' = $all
        'after-unload-all' = ''
    }
    $failures = @()
    foreach ($key in $expected.Keys) {
        if (-not $values.ContainsKey($key)) { $failures += "missing report line '$key'"; continue }
        if ($values[$key] -ne $expected[$key]) { $failures += "$key : expected '$($expected[$key])', got '$($values[$key])'" }
    }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $logErrors = @()
    $mediaErrors = @()
    if (Test-Path -LiteralPath $logPath) {
        $reported = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        # Media runs here without the bundled WebNowPlaying plugin, so its player
        # measures and the cover art they resolve report expected failures. They
        # belong to Media's own checks; Welcome only activates the config.
        $mediaErrors = @($reported | Where-Object { $_ -match 'WebNowPlaying' -or $_ -match [regex]::Escape('Parallax\Media\Media.ini') })
        $logErrors = @($reported | Where-Object { $mediaErrors -notcontains $_ })
    }
    if ($logErrors.Count) { $failures += 'isolated Rainmeter reported errors'; $logErrors | Write-Output }
    if ($failures.Count) {
        $failures | ForEach-Object { Write-Output ("FAIL: " + $_) }
        throw "Welcome smoke failed. Evidence retained at $runRoot"
    }
    Write-Output "PASS: checkbox toggle, Load all and Unload all changed the configs Rainmeter reports as active."
    Write-Output "Evidence retained at $runRoot"
    [pscustomobject]@{
        RunRoot = $runRoot
        Scale = $Scale
        SuiteAssertions = $(if ($values.ContainsKey('suite-assertions')) { $values['suite-assertions'] } else { 'unreported' })
        Steps = $expected
        ToleratedMediaPluginErrors = $mediaErrors.Count
        Limitations = 'Controller behavior in an isolated instance only. Media runs without its bundled plugin here. Does not establish visual quality, DPI behavior, upgrade behavior or long-run performance.'
    }
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
