#requires -Version 5.1
<#
.SYNOPSIS
Runs the Welcome update-check controller in an isolated Rainmeter instance.

.DESCRIPTION
Stages the distributable sources and launches Rainmeter against a generated
profile containing only Parallax\Welcome. The staged feed address is replaced
with local file:// manifests, so the real WebParser measure, FinishAction wiring
and Update.lua run without contacting a real feed. The harness checks version
ordering and feed validation offline, then drives Check() against a newer, an
equal and a missing feed. With -ExerciseInstall it also presses Install for the
fake newer version: the one-shot helper then asks GitHub for a release asset that
does not exist and must report the failure without opening Skin Installer.
The live Rainmeter installation, its settings and the desktop are never touched.
#>
[CmdletBinding()]
param(
    [switch]$ExerciseInstall,
    [ValidateRange(10, 90)][int]$SettleSeconds = 40,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }

$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'update-smoke'
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
foreach ($name in @('Layouts', 'Plugins', 'Addons')) { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native Welcome update test with harness instrumentation. Do not distribute.`n"

$versionPath = Join-Path $parallaxRoot '@Resources\Version.inc'
$versionText = Get-Content -LiteralPath $versionPath -Raw
$installed = [regex]::Match($versionText, '(?m)^ParallaxVersion=([^\r\n]+)').Groups[1].Value.Trim()
$base = [regex]::Match($versionText, '(?m)^UpdateReleaseBase=([^\r\n]+)').Groups[1].Value.Trim()
if (-not $installed -or -not $base) { throw 'Version.inc no longer declares ParallaxVersion and UpdateReleaseBase.' }

function New-Feed([string]$Version) {
    [ordered]@{
        schema = 1; name = 'Parallax'; version = $Version
        url = "${base}download/v$Version/Parallax_$Version.rmskin"
        sha256 = ('0' * 64); bytes = 1; minimumRainmeter = '4.5.26'; notes = "${base}tag/v$Version"
    } | ConvertTo-Json
}
$feedRoot = Join-Path $runRoot 'feeds'
$null = New-Item -ItemType Directory -Path $feedRoot
Write-RunFile (Join-Path $feedRoot 'newer.json') (New-Feed '99.0.0')
Write-RunFile (Join-Path $feedRoot 'same.json') (New-Feed $installed)
function ConvertTo-FileUrl([string]$Path) { return ([Uri]$Path).AbsoluteUri }
$newerUrl = ConvertTo-FileUrl (Join-Path $feedRoot 'newer.json')
$sameUrl = ConvertTo-FileUrl (Join-Path $feedRoot 'same.json')
$missingUrl = ConvertTo-FileUrl (Join-Path $feedRoot 'missing.json')

$reportPath = Join-Path $runRoot 'update-report.txt'
$updatePath = Join-Path $parallaxRoot '@Resources\Modules\Welcome\Update.lua'
$installSteps = if ($ExerciseInstall) { 'true' } else { 'false' }
$harness = @'
-- Test-only harness. Offline assertions load a second copy of Update.lua against a
-- mocked skin; the live steps drive the real MeasureUpdate through its bangs.
local step, lines, phase, waited = 0, {}, 'start', 0
local base, installed = [[__BASE__]], [[__INSTALLED__]]
local exerciseInstall = __INSTALL__

local function offline()
    local count = 0
    local env = setmetatable({}, { __index = _G })
    env.SKIN = { GetVariable = function(_, key, default)
        if key == 'ParallaxVersion' then return installed end
        if key == 'UpdateReleaseBase' then return base end
        return default
    end, Bang = function() end }
    local chunk = assert(loadfile([[__UPDATE__]]))
    setfenv(chunk, env)
    chunk()
    env.Initialize()
    local function eq(a, b, label)
        count = count + 1
        if a ~= b then error(label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
    end
    local C = env.CompareVersions
    eq(C('0.1.0', '0.2.0'), -1, 'minor'); eq(C('1.0.0', '0.9.9'), 1, 'major')
    eq(C('0.1.0-alpha', '0.1.0'), -1, 'pre before release'); eq(C('0.1.0', '0.1.0-alpha'), 1, 'release after pre')
    eq(C('0.1.0-alpha', '0.1.0-beta'), -1, 'alpha before beta'); eq(C('0.1.0-alpha', '0.1.0-alpha.1'), -1, 'shorter pre first')
    eq(C('0.1.0-alpha.2', '0.1.0-alpha.10'), -1, 'numeric identifiers'); eq(C('0.1.0-2', '0.1.0-alpha'), -1, 'numeric before text')
    eq(C('0.1.0-alpha', '0.1.0-alpha'), 0, 'equal'); eq(C('0.1.0+build.5', '0.1.0'), nil, 'build metadata refused')
    eq(C('0.10.0', '0.9.0'), 1, 'numeric not lexical'); eq(C('dev', '0.1.0'), nil, 'unreadable')
    eq(C('0.1', '0.1.0'), nil, 'two-part refused')
    local function feed(fields)
        local parts = {}
        for k, v in pairs(fields) do parts[#parts + 1] = string.format('"%s": %s', k, v) end
        return '{' .. table.concat(parts, ', ') .. '}'
    end
    local good = { schema = '1', name = '"Parallax"', version = '"0.2.0"',
        url = '"' .. base .. 'download/v0.2.0/Parallax_0.2.0.rmskin"',
        sha256 = '"' .. string.rep('a', 64) .. '"', notes = '"' .. base .. 'tag/v0.2.0"' }
    local item = env.ParseFeed(feed(good))
    eq(item ~= nil and item.version, '0.2.0', 'good feed')
    eq(item ~= nil and item.notes, base .. 'tag/v0.2.0', 'good notes')
    local function bad(key, value, label)
        local copy = {}
        for k, v in pairs(good) do copy[k] = v end
        copy[key] = value
        local parsed = env.ParseFeed(feed(copy))
        eq(parsed, nil, label)
    end
    bad('schema', '2', 'future schema refused')
    bad('name', '"Other"', 'other package refused')
    bad('url', '"https://example.com/download/v0.2.0/Parallax_0.2.0.rmskin"', 'foreign host refused')
    bad('url', '"' .. base .. 'download/v0.3.0/Parallax_0.3.0.rmskin"', 'mismatched asset refused')
    bad('sha256', '"abc"', 'short checksum refused')
    bad('version', '"0.2.0\\" & calc"', 'escaped quote refused')
    bad('version', '"0.2.0 x"', 'spaces refused')
    local noNotes = {}
    for k, v in pairs(good) do noNotes[k] = v end
    noNotes.notes = '"https://example.com/notes"'
    local stripped = env.ParseFeed(feed(noNotes))
    eq(stripped ~= nil and stripped.notes, nil, 'foreign notes dropped')
    eq(env.ParseFeed(''), nil, 'empty refused'); eq(env.ParseFeed('Not Found'), nil, '404 body refused')
    eq(env.ParseFeed(string.rep(' ', 9000) .. feed(good)), nil, 'oversized refused')
    return count
end

local function status()
    local meter = SKIN:GetMeter('MeterUpdateStatus')
    return meter and meter:GetOption('Text') or '<no meter>'
end

local function check(url)
    SKIN:Bang('!SetOption', 'MeasureUpdateFeed', 'URL', url)
    SKIN:Bang('!CommandMeasure', 'MeasureUpdate', 'Check()')
end

local function waitFor(pattern, label, limit)
    waited = waited + 1
    local text = status()
    if text:find(pattern) or waited >= limit then
        lines[#lines + 1] = label .. '=' .. text
        lines[#lines + 1] = label .. '-tip=' .. (SKIN:GetMeter('MeterUpdateStatus'):GetOption('ToolTipText') or '')
        waited = 0
        return true
    end
    return false
end

function Initialize() end

function Update()
    step = step + 1
    if phase == 'start' then
        local passed, result = pcall(offline)
        lines[#lines + 1] = 'offline=' .. (passed and 'PASS' or 'FAIL')
        lines[#lines + 1] = 'offline-detail=' .. tostring(result)
        lines[#lines + 1] = 'initial=' .. status()
        check([[__NEWER__]])
        phase = 'newer'
    elseif phase == 'newer' then
        if waitFor('available', 'newer', 10) then
            if exerciseInstall then
                SKIN:Bang('!CommandMeasure', 'MeasureUpdate', 'Install()')
                phase = 'install'
            else
                check([[__SAME__]])
                phase = 'same'
            end
        end
    elseif phase == 'install' then
        if waitFor('fail', 'install', 60) then check([[__SAME__]]); phase = 'same' end
    elseif phase == 'same' then
        if waitFor('up to date', 'same', 10) then check([[__MISSING__]]); phase = 'missing' end
    elseif phase == 'missing' then
        if waitFor('reach', 'missing', 10) then
            phase = 'done'
            local file = io.open([[__REPORT__]], 'wb')
            if file then
                file:write(table.concat(lines, '\n'), '\nDONE\n')
                file:close()
            end
        end
    end
    return 0
end
'@
$harness = $harness.Replace('__BASE__', $base).Replace('__INSTALLED__', $installed).Replace('__INSTALL__', $installSteps)
$harness = $harness.Replace('__UPDATE__', $updatePath).Replace('__REPORT__', $reportPath)
$harness = $harness.Replace('__NEWER__', $newerUrl).Replace('__SAME__', $sameUrl).Replace('__MISSING__', $missingUrl)
$harnessPath = Join-Path $runRoot 'UpdateHarness.lua'
Write-RunFile $harnessPath $harness

# Test-only instrumentation: a clock for the harness, and a feed URL the harness may
# replace between checks. The shipped panel keeps Update=-1 and a static URL.
$welcomePath = Join-Path $parallaxRoot 'Welcome\Welcome.ini'
$welcomeText = Get-Content -LiteralPath $welcomePath -Raw
$welcomeText = [regex]::new('(?m)^Update=-1\r?$').Replace($welcomeText, 'Update=500', 1)
$welcomeText = [regex]::new('(?m)^(Measure=WebParser\r?)$').Replace($welcomeText, "`$1`nDynamicVariables=1", 1)
if ($welcomeText -notmatch '(?m)^Update=500\r?$' -or $welcomeText -notmatch 'DynamicVariables=1') { throw 'Could not instrument Welcome.' }
$welcomeText += "`n[MeasureUpdateHarness]`nMeasure=Script`nScriptFile=$harnessPath`n"
Write-RunFile $welcomePath $welcomeText

$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$ini += "`n[Parallax\Welcome]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunFile $iniPath $ini
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

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
    $expected = [ordered]@{
        'offline' = '^PASS$'
        'initial' = [regex]::Escape("Parallax $installed installed.")
        'newer' = [regex]::Escape("Parallax 99.0.0 is available.")
        'newer-tip' = [regex]::Escape("You have $installed.")
        'same' = [regex]::Escape("Parallax $installed is up to date.")
        'missing' = '^Could not reach the update server\.$'
    }
    if ($ExerciseInstall) {
        $expected['install'] = '^Download failed\. Nothing was installed\.$'
        $expected['install-tip'] = '^Download failed: .*\(404\)'
    }
    $failures = @()
    foreach ($key in $expected.Keys) {
        if (-not $values.ContainsKey($key)) { $failures += "missing report line '$key'"; continue }
        if ($values[$key] -notmatch $expected[$key]) { $failures += "$key : got '$($values[$key])'" }
    }
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $logErrors = @()
    if (Test-Path -LiteralPath $logPath) {
        # The missing-feed step deliberately produces WebParser's own connection error.
        $logErrors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' -and $_ -notmatch 'MeasureUpdateFeed' })
    }
    if ($logErrors.Count) { $failures += 'isolated Rainmeter reported errors'; $logErrors | Write-Output }
    if ($failures.Count) {
        $failures | ForEach-Object { Write-Output ('FAIL: ' + $_) }
        throw "Update smoke failed. Evidence retained at $runRoot"
    }
    Write-Output 'PASS: the real WebParser feed request, FinishAction and Update.lua reported newer, equal and unreachable feeds.'
    Write-Output "Evidence retained at $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
