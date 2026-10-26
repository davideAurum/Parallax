#requires -Version 5.1
<#
.SYNOPSIS
Runs the update check, prompt and Global Settings Updates section in an
isolated Rainmeter instance.

.DESCRIPTION
Stages the distributable sources and launches Rainmeter against a generated
profile. The staged feed address points at a local file:// feed whose contents
the harness rewrites between checks, so the real WebParser, the shared
State.inc, Update.lua in all three roles and the prompt run without contacting
GitHub. Test-only instrumentation: the hook's first look is 1 s instead of
60 s, Global Settings and the prompt update every 500 ms so probe measures can
report their meters, the feed WebParser gets DynamicVariables=1 (for -Online),
and a harness config drives the steps:

  1. Chronometer loads with the hook; a newer feed (99.0.0) must open the
     prompt by itself, at the top right of the work area.
  2. Global Settings opens: Latest, status and Update/Notes from the saved
     result, with no check of its own (the last one is under 10 minutes old).
  3. Check now against an unreachable feed, a rate-limit page and, with
     -Online, GitHub's real 404 for a missing asset; each reports its failure.
  4. Check now against the installed version: up to date, and the open prompt
     closes itself.
  5. A newer feed again, the prompt reopened, Later: closed and dismissed.
  6. With -ExerciseInstall, Update in Global Settings: the helper asks GitHub
     for the nonexistent 99.0.0 package and must report the failure without
     opening Skin Installer.
The live Rainmeter installation, its settings and the desktop are never touched;
every window is offscreen except the prompt, which is placed on screen at
alpha 1 (invisible) and click-through.
#>
[CmdletBinding()]
param(
    [switch]$ExerciseInstall,
    [switch]$Online,
    [ValidateRange(20, 180)][int]$SettleSeconds = 90,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..'))
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }

$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'update-smoke'
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Edit-RunFile([string]$Path, [string]$Pattern, [string]$Replacement) {
    $text = [IO.File]::ReadAllText($Path)
    $edited = [regex]::new($Pattern).Replace($text, $Replacement, 1)
    if ($edited -eq $text) { throw "Could not instrument $Path ($Pattern)." }
    Write-RunFile $Path $edited
}
foreach ($name in @('Layouts', 'Plugins', 'Addons')) { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native update test with harness instrumentation. Do not distribute.`n"

$resources = Join-Path $parallaxRoot '@Resources'
$versionText = [IO.File]::ReadAllText((Join-Path $resources 'Version.inc'))
$installed = [regex]::Match($versionText, '(?m)^ParallaxVersion=([^\r\n]+)').Groups[1].Value.Trim()
$base = [regex]::Match($versionText, '(?m)^UpdateReleaseBase=([^\r\n]+)').Groups[1].Value.Trim()
if (-not $installed -or -not $base) { throw 'Version.inc no longer declares ParallaxVersion and UpdateReleaseBase.' }
$stateText = [IO.File]::ReadAllText((Join-Path $resources 'Update\State.inc'))
if ($stateText -notmatch '(?m)^UpdateCheckedAt=0\r?$' -or $stateText -notmatch '(?m)^UpdateLatest=\r?$') { throw 'The staged State.inc is not blank.' }

function New-Feed([string]$Version) {
    [ordered]@{
        schema = 1; name = 'Parallax'; version = $Version
        url = "${base}download/v$Version/Parallax_$Version.rmskin"
        sha256 = ('0' * 64); bytes = 1; minimumRainmeter = '4.5.26'; notes = "${base}tag/v$Version"
    } | ConvertTo-Json
}
$feedRoot = Join-Path $runRoot 'feeds'
$feedPath = Join-Path $feedRoot 'feed.json'
Write-RunFile $feedPath (New-Feed '99.0.0')
Write-RunFile (Join-Path $feedRoot 'newer.json') (New-Feed '99.0.0')
Write-RunFile (Join-Path $feedRoot 'same.json') (New-Feed $installed)
Write-RunFile (Join-Path $feedRoot 'ratelimit.json') "{`"message`":`"API rate limit exceeded for 127.0.0.1.`"}"
$feedUrl = ([Uri]$feedPath).AbsoluteUri
$reportRoot = Join-Path $runRoot 'report'
$null = New-Item -ItemType Directory -Path $reportRoot

# Instrumentation of the staged copy only.
Edit-RunFile (Join-Path $resources 'Version.inc') '(?m)^UpdateFeedURL=[^\r\n]*' "UpdateFeedURL=$feedUrl"
Edit-RunFile (Join-Path $resources 'Update\Hook1.inc') '(?m)^ParallaxUpdateFirstDelay=60000' 'ParallaxUpdateFirstDelay=1000'
Edit-RunFile (Join-Path $resources 'Update\Feed.inc') '(?m)^(Measure=WebParser)' "`$1`r`nDynamicVariables=1"
$probe = @'
-- Test-only probe: writes the named meters' text and visibility, and the
-- window rectangle and work area, every update and on update broadcasts.
local path, names
function Initialize()
    path = SELF:GetOption('Report')
    names = {}
    for name in SELF:GetOption('Meters'):gmatch('[^|]+') do names[#names + 1] = name end
end
function Update()
    local lines = {}
    for _, name in ipairs(names) do
        local meter = SKIN:GetMeter(name)
        lines[#lines + 1] = name .. '=' .. (meter and meter:GetOption('Text') or '<none>')
        lines[#lines + 1] = name .. 'Hidden=' .. (meter and meter:GetOption('Hidden', '0') or '')
        lines[#lines + 1] = name .. 'Color=' .. (meter and meter:GetOption('FontColor') or '')
    end
    for _, key in ipairs({ 'WORKAREAX', 'WORKAREAY', 'WORKAREAWIDTH' }) do lines[#lines + 1] = key .. '=' .. SKIN:GetVariable(key, '') end
    lines[#lines + 1] = 'X=' .. SKIN:GetX(); lines[#lines + 1] = 'Y=' .. SKIN:GetY(); lines[#lines + 1] = 'W=' .. SKIN:GetW()
    lines[#lines + 1] = 'Clock=' .. string.format('%.3f', os.clock())
    local file = io.open(path .. '.tmp', 'wb'); if not file then return 0 end
    file:write(table.concat(lines, '\n'), '\n'); file:close()
    os.remove(path); os.rename(path .. '.tmp', path)
    return 0
end
'@
Write-RunFile (Join-Path $runRoot 'Probe.lua') $probe
function Add-Probe([string]$Config, [string]$Report, [string]$Meters) {
    $path = Join-Path $parallaxRoot $Config
    Edit-RunFile $path '(?m)^Update=-1' 'Update=500'
    $text = [IO.File]::ReadAllText($path)
    $text += "`r`n[MeasureTestProbe]`r`nMeasure=Script`r`nScriptFile=$runRoot\Probe.lua`r`nGroup=ParallaxUpdateView`r`nReport=$reportRoot\$Report`r`nMeters=$Meters`r`n"
    Write-RunFile $path $text
}
Add-Probe 'Update\Update.ini' 'prompt.txt' 'MeterHeadline|MeterUpdateStatus|MeterUpdateInstall|MeterUpdateNotes'
Add-Probe 'Settings\Settings.ini' 'settings.txt' 'MeterUpdateInstalledValue|MeterUpdateLatestValue|MeterUpdateStatus|MeterUpdateCheckNow|MeterUpdateInstall|MeterUpdateNotes|MeterUpdateCheckValue'

$harness = @'
-- Test-only driver: one step per 500 ms tick, reading the probes, the shared
-- State.inc and the instance's own Rainmeter.ini. Every action is a bang into
-- the real configs.
local root, settingsIni, statePath, feedPath = [[__REPORT__]], [[__SETTINGS__]], [[__STATE__]], [[__FEED__]]
local feeds = { newer = [[__NEWER__]], same = [[__SAME__]], ratelimit = [[__RATELIMIT__]] }
local online, exerciseInstall = __ONLINE__, __INSTALL__
local lines, phase, waited, started, firstCheckedAt = {}, 'prompt', 0, os.clock(), nil
local function read(path) local f = io.open(path, 'rb'); if not f then return nil end local t = f:read('*a'); f:close(); return t end
local function write(path, text) local f = assert(io.open(path, 'wb')); f:write(text); f:close() end
local function values(path)
    local text, out = read(path) or '', {}
    if text:sub(1, 2) == '\255\254' then text = text:sub(3):gsub('(.)%z', '%1') end
    local section = ''
    for line in text:gmatch('[^\r\n]+') do
        local name = line:match('^%[(.+)%]$')
        if name then section = name .. '|' else
            local k, v = line:match('^([^=]+)=(.*)$'); if k then out[section .. k] = v end
        end
    end
    return out
end
local function promptActive() return values(settingsIni)['Parallax\\Update|Active'] end
local function note(label, text) lines[#lines + 1] = label .. '=' .. tostring(text) end
local function since() return string.format('%.1f', os.clock() - started) end
local function feed(name) if name == 'missing' then os.remove(feedPath) else write(feedPath, read(feeds[name])) end end
local function gs(name) return values(root .. 'settings.txt')[name] or '' end
local function pr(name) return values(root .. 'prompt.txt')[name] or '' end
local function checkNow() SKIN:Bang('!CommandMeasure', 'MeasureParallaxUpdate', 'CheckNow()', 'Parallax\\Settings') end
-- Waits for cond; on success or after limit ticks runs record() and moves on.
local function step(cond, limit, record, nextPhase, action)
    waited = waited + 1
    if cond() or waited >= limit then
        record(cond())
        waited = 0
        phase = nextPhase
        if action then action() end
    end
end
function Initialize() end
function Update()
    if phase == 'prompt' then
        step(function() return pr('MeterHeadline') == '99.0.0 is available' and promptActive() == '1' end, 40, function(ok)
            note('prompt', ok and 'opened' or 'missing'); note('promptAfter', since())
            note('promptHeadline', pr('MeterHeadline')); note('promptStatus', pr('MeterUpdateStatus'))
            note('promptNotesHidden', pr('MeterUpdateNotesHidden'))
            local p = values(root .. 'prompt.txt')
            note('promptX', p.X); note('promptY', p.Y); note('promptW', p.W)
            note('promptExpectX', (tonumber(p.WORKAREAX) or 0) + (tonumber(p.WORKAREAWIDTH) or 0) - (tonumber(p.W) or 0) - 16)
            note('promptExpectY', (tonumber(p.WORKAREAY) or 0) + 16)
            local s = values(statePath)
            note('stateResult', s['Variables|UpdateResult']); note('stateLatest', s['Variables|UpdateLatest'])
            note('stateCheckedAt', s['Variables|UpdateCheckedAt']); firstCheckedAt = s['Variables|UpdateCheckedAt']
        end, 'settings', function() SKIN:Bang('!ActivateConfig', 'Parallax\\Settings', 'Settings.ini') end)
    elseif phase == 'settings' then
        step(function() return gs('MeterUpdateLatestValue') == '99.0.0' and gs('MeterUpdateInstallHidden') == '0' end, 20, function()
            note('gsInstalled', gs('MeterUpdateInstalledValue')); note('gsLatest', gs('MeterUpdateLatestValue'))
            note('gsStatus', gs('MeterUpdateStatus')); note('gsInstallHidden', gs('MeterUpdateInstallHidden'))
            note('gsNotesHidden', gs('MeterUpdateNotesHidden')); note('gsAuto', gs('MeterUpdateCheckValue'))
        end, 'openwait')
    elseif phase == 'openwait' then
        -- Past the 500 ms open check: it must not have run.
        step(function() return false end, 3, function()
            note('openCheckSkipped', values(statePath)['Variables|UpdateCheckedAt'] == firstCheckedAt and 'yes' or 'no')
        end, 'offline', function() feed('missing'); checkNow() end)
    elseif phase == 'offline' then
        step(function() return gs('MeterUpdateStatus'):find('reach') ~= nil end, 20, function()
            note('offline', gs('MeterUpdateStatus')); note('offlineColor', gs('MeterUpdateStatusColor')); note('offlineLatest', gs('MeterUpdateLatestValue'))
        end, 'ratelimit', function() feed('ratelimit'); checkNow() end)
    elseif phase == 'ratelimit' then
        step(function() return gs('MeterUpdateStatus'):find('limiting') ~= nil end, 20, function()
            note('ratelimit', gs('MeterUpdateStatus'))
        end, online and 'online' or 'same', function()
            if online then
                SKIN:Bang('!SetOption', 'MeasureParallaxUpdateFeed', 'URL', [[__BASE__]] .. 'latest/download/no-such-asset.json', 'Parallax\\Settings')
            else feed('same') end
            checkNow()
        end)
    elseif phase == 'online' then
        step(function() return gs('MeterUpdateStatus'):find('No Parallax') ~= nil end, 40, function()
            note('online404', gs('MeterUpdateStatus'))
        end, 'same', function()
            SKIN:Bang('!SetOption', 'MeasureParallaxUpdateFeed', 'URL', [[__FEEDURL__]], 'Parallax\\Settings')
            feed('same'); checkNow()
        end)
    elseif phase == 'same' then
        step(function() return gs('MeterUpdateStatus'):find('Up to date') ~= nil and promptActive() == '0' end, 20, function()
            note('same', gs('MeterUpdateStatus')); note('sameLatest', gs('MeterUpdateLatestValue'))
            note('sameInstallHidden', gs('MeterUpdateInstallHidden')); note('promptAfterCurrent', promptActive())
        end, 'newer', function() feed('newer'); checkNow() end)
    elseif phase == 'newer' then
        step(function() return gs('MeterUpdateStatus'):find('is available') ~= nil end, 20, function()
            note('newer', gs('MeterUpdateStatus')); note('promptAfterManual', promptActive())
        end, 'reopen', function() SKIN:Bang('!ActivateConfig', 'Parallax\\Update', 'Update.ini') end)
    elseif phase == 'reopen' then
        step(function() return promptActive() == '1' and pr('MeterHeadline') == '99.0.0 is available' end, 20, function(ok)
            note('reopened', ok and 'yes' or 'no')
        end, 'later', function() SKIN:Bang('!CommandMeasure', 'MeasureParallaxUpdate', 'Later()', 'Parallax\\Update') end)
    elseif phase == 'later' then
        step(function() return promptActive() == '0' end, 20, function()
            note('later', promptActive()); note('dismissed', values(statePath)['Variables|UpdateDismissed'])
        end, exerciseInstall and 'install' or 'done', function()
            if exerciseInstall then SKIN:Bang('!CommandMeasure', 'MeasureParallaxUpdate', 'Install()', 'Parallax\\Settings') end
        end)
    elseif phase == 'install' then
        step(function() local t = gs('MeterUpdateStatus'); return t:find('fail') ~= nil or t:find('Confirm') ~= nil end, 120, function()
            note('install', gs('MeterUpdateStatus'))
        end, 'done')
    elseif phase == 'done' then
        phase = 'written'
        write(root .. 'report.txt', table.concat(lines, '\n') .. '\nDONE\n')
    end
    return 0
end
'@
$statePath = Join-Path $resources 'Update\State.inc'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$harness = $harness.Replace('__REPORT__', "$reportRoot\").Replace('__SETTINGS__', $iniPath).Replace('__STATE__', $statePath).Replace('__FEED__', $feedPath)
$harness = $harness.Replace('__NEWER__', (Join-Path $feedRoot 'newer.json')).Replace('__SAME__', (Join-Path $feedRoot 'same.json')).Replace('__RATELIMIT__', (Join-Path $feedRoot 'ratelimit.json'))
$harness = $harness.Replace('__ONLINE__', $(if ($Online) { 'true' } else { 'false' })).Replace('__INSTALL__', $(if ($ExerciseInstall) { 'true' } else { 'false' }))
$harness = $harness.Replace('__BASE__', $base).Replace('__FEEDURL__', $feedUrl)
Write-RunFile (Join-Path $runRoot 'Harness.lua') $harness
Write-RunFile (Join-Path $parallaxRoot 'UpdateHarness\Harness.ini') "[Rainmeter]`r`nUpdate=500`r`n[MeasureHarness]`r`nMeasure=Script`r`nScriptFile=$runRoot\Harness.lua`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`n"

$offscreen = "WindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$ini += "`n[Parallax\Chronometer]`nActive=1`n$offscreen"
$ini += "`n[Parallax\UpdateHarness]`nActive=1`n$offscreen"
$ini += "`n[Parallax\Settings]`nActive=0`n$offscreen"
# No WindowX: the prompt places itself. Alpha 1 and click-through keep it out of the way.
$ini += "`n[Parallax\Update]`nActive=0`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=1`n"
Write-RunFile $iniPath $ini
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
$reportPath = Join-Path $reportRoot 'report.txt'

try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($SettleSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ((Test-Path -LiteralPath $reportPath) -and ((Get-Content -LiteralPath $reportPath -Raw) -match '(?m)^DONE\r?$')) { break }
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated instance exited early; inspect $runRoot\Rainmeter.log" }
    }
    if (-not (Test-Path -LiteralPath $reportPath)) { throw "Harness produced no report; inspect $runRoot\Rainmeter.log" }
    $report = Get-Content -LiteralPath $reportPath
    $report | Write-Output
    $values = @{}
    foreach ($line in $report) { if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] } }
    $time = '\d{1,2}:\d{2}'
    $expected = [ordered]@{
        'prompt' = '^opened$'
        'promptHeadline' = '^99\.0\.0 is available$'
        'promptStatus' = '^Skin Installer asks you to confirm\.$'
        'promptNotesHidden' = '^0$'
        'stateResult' = '^available$'
        'stateLatest' = '^99\.0\.0$'
        'gsInstalled' = '^' + [regex]::Escape("Installed $installed") + '$'
        'gsLatest' = '^99\.0\.0$'
        'gsStatus' = "^Parallax 99\.0\.0 is available\. Checked $time\.$"
        'gsInstallHidden' = '^0$'
        'gsNotesHidden' = '^0$'
        'gsAuto' = '^Daily$'
        'openCheckSkipped' = '^yes$'
        'offline' = "^Could not reach github\.com\. Checked $time\.$"
        'offlineColor' = '^235,55,75$'
        'offlineLatest' = "^99\.0\.0 \($time\)$"
        'ratelimit' = "^GitHub is limiting requests\. Checked $time\.$"
        'same' = "^Up to date\. Checked $time\.$"
        'sameLatest' = '^' + [regex]::Escape($installed) + '$'
        'sameInstallHidden' = '^1$'
        'promptAfterCurrent' = '^0$'
        'newer' = "^Parallax 99\.0\.0 is available\. Checked $time\.$"
        'promptAfterManual' = '^0$'
        'reopened' = '^yes$'
        'later' = '^0$'
        'dismissed' = '^99\.0\.0$'
    }
    if ($Online) { $expected['online404'] = "^No Parallax release was found\. Checked $time\.$" }
    if ($ExerciseInstall) { $expected['install'] = '^Download failed\. Nothing was installed\.$' }
    $failures = @()
    foreach ($key in $expected.Keys) {
        if (-not $values.ContainsKey($key)) { $failures += "missing report line '$key'"; continue }
        if ($values[$key] -notmatch $expected[$key]) { $failures += "$key : got '$($values[$key])'" }
    }
    if ([int]$values['promptX'] -ne [int]$values['promptExpectX'] -or [int]$values['promptY'] -ne [int]$values['promptExpectY']) {
        $failures += "prompt placed at $($values['promptX']),$($values['promptY']); expected $($values['promptExpectX']),$($values['promptExpectY'])"
    }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $logIssues = @()
    if (Test-Path -LiteralPath $logPath) {
        # The unreachable-feed step deliberately produces WebParser's own connection error.
        $logIssues = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^(ERRO|WARN)' -and $_ -notmatch 'MeasureParallaxUpdateFeed' })
    }
    if ($logIssues.Count) { $failures += 'isolated Rainmeter reported errors or warnings'; $logIssues | Write-Output }
    if ($failures.Count) {
        $failures | ForEach-Object { Write-Output ('FAIL: ' + $_) }
        throw "Update smoke failed. Evidence retained at $runRoot"
    }
    Write-Output "PASS: hook check opened the prompt after $($values['promptAfter']) s at $($values['promptX']),$($values['promptY']); Global Settings showed the saved offer, reported offline, rate-limited$(if ($Online) { ', missing (GitHub 404)' }) and up to date; the prompt closed itself and on Later."
    Write-Output "Evidence retained at $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
