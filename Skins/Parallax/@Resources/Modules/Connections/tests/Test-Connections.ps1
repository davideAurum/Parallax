#requires -Version 5.1
<#
.SYNOPSIS
Runs the Parallax Connections checks in an isolated Rainmeter instance.

.DESCRIPTION
Stages the distributable sources and launches Rainmeter against a generated
profile that contains only Parallax\Connections, with a synthetic LOCALAPPDATA.
A test-only harness runs the mocked ConnectionsSuite, then compares what the real
panel shows with the synthetic status files, and measures every text it can show
against the space it has, at the default layout and at the narrowest one with the
largest body text. The live Rainmeter, its settings and the real Spotify sign-in
are never read or changed: no click action is performed and nothing is launched.
#>
[CmdletBinding()]
param(
    [ValidateRange(8, 60)][int]$SettleSeconds = 25,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is downloaded or installed.' }
$utf8 = [Text.UTF8Encoding]::new($false)
$suitePath = Join-Path $PSScriptRoot 'ConnectionsSuite.luatest'

# Static: what the panel may launch, and only from a click.
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'Skins\Parallax\Connections\Connections.ini') -Raw
$launches = @([regex]::Matches($source, '(?im)^[^;\r\n]*(powershell|\.ps1)[^\r\n]*') | ForEach-Object { $_.Value.Trim() })
$allowed = @(
    'Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe',
    'Parameter=-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "Disconnect" -Quiet',
    'LeftMouseUpAction=["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" "-NoExit" "-File" "#@#Modules\Media\Queue\QueueProvider.ps1" "-Command" "Connect" "-PollSeconds" "#QueuePollSeconds#"][!CommandMeasure MeasureConnections "SignInOpened()"]',
    # The TV row: MeasureTvControl's Program and default Parameter, and Pair.
    'Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe',
    'Parameter=-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "TvProvider.ps1" -Command "Stop" -Quiet',
    'LeftMouseUpAction=["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" "-NoExit" "-File" "#@#Modules\Media\TvQueue\TvProvider.ps1" "-Command" "Pair"][!CommandMeasure MeasureTvConnections "PairOpened()"]')
if (Compare-Object $launches $allowed) { throw "The panel's launch actions changed:`n$($launches -join "`n")" }
$plugins = @([regex]::Matches($source, '(?im)^Plugin=[^\r\n]*') | ForEach-Object { $_.Value.Trim() })
if ($plugins.Count -ne 2 -or @($plugins | Where-Object { $_ -cne 'Plugin=RunCommand' }).Count) { throw 'Only the Disconnect and TV control hosts are plugins.' }
Write-Output 'PASS: launches are the sign-in and Pair clicks, the confirmed Disconnect and the TV control host only.'

$harness = @'
-- Test-only harness.
local step, lines = 0, {}
local now = os.time()
local function add(text) lines[#lines + 1] = text end
local function text(name) return SKIN:GetMeter(name):GetOption('Text', '') end
-- Every text each slot can show, and the space it has.
local slots = {
    { 'MeterSpotifyState', { 'Not signed in', 'Sign in again', 'Access denied', 'Signing in' } },
    { 'MeterSourceState', { 'On', 'Off', 'Not running', 'Unavailable', 'Unknown' } },
    { 'MeterPluginState', { 'Plugin installed', 'Plugin missing' } },
    { 'MeterHWiNFOState', { 'Running', 'Open Sensors', 'Not running' } },
    { 'MeterUpdateState', { 'Daily, GitHub', 'Off', 'Off in this copy', 'Custom' } },
    { 'MeterSourceName', { 'Spotify detection', 'WebNowPlaying', 'HWiNFO', 'Update check' } },
    { 'MeterSourceLink', { 'Media settings', 'Setup guide', 'CPU settings', 'Global Settings' }, true },
    { 'MeterSignIn', { 'Sign in', 'Sign in again' }, true },
    { 'MeterDisconnect', { 'Disconnect', 'Disconnect?' }, true },
    { 'MeterSpotifyDetail', { 'The local app data folder was not found.', 'Finish in the console and the browser.',
        'The last sign-in did not finish.', 'Sign in opens a console and your browser.', 'Experimental. Needs Premium and your own app ID. See Help.',
        'Queue helper is off. Start it in Media settings.', 'Queue helper is not running. See Media settings.', 'Spotify needs a new sign-in.',
        'Spotify refused this account or app. See Help.', 'Spotify asked to wait. The queue resumes by itself.',
        'The Spotify app has used its quota. See Help.', 'Spotify is unavailable. The helper tries again.',
        'Queue unavailable. Try Restart in Media settings.', 'To allow playback control and playlists.',
        'Queue and playback control. Playlists not checked yet.', 'Queue and playback control. Playlists unavailable.' } },
    { 'MeterStatus', { 'Only Sign in, Disconnect and TV buttons change things.', 'Sign-in console opened. Close it once it says it is done.',
        'Click again to remove the saved Spotify sign-in.', 'Disconnected. The saved sign-in was removed.', 'Disconnect did not finish. Try again.' } },
    { 'MeterIntro', { 'What Parallax connects to. Nothing here starts by itself.' } },
    { 'MeterTvSection', { 'YouTube on the TV' } },
    { 'MeterTvName', { 'TV app' } },
    { 'MeterTvState', { 'Checking', 'Unknown', 'Not paired', 'Connected', 'TV app closed', 'Connecting', 'Offline',
        'Unavailable', 'Pair again', 'Paired' } },
    { 'MeterTvDetail', { 'The local app data folder was not found.', 'Pair opens a console for the code from the TV.',
        'Up next shows in Media when nothing plays here.', 'The worker rejoins when the TV is back.', 'Joining the TV.',
        'The worker tries again by itself.', 'YouTube did not answer. It tries again.', 'The TV refused the saved pairing.',
        'The TV worker is not running. Start reads the TV.', 'The TV worker is off. Start reads the TV.',
        'The last TV command is still running.', 'Click Forget again to remove the TV pairing.', 'Stopping the TV worker...',
        'Starting the TV worker...', 'Removing the TV pairing...',
        'Pair console open. Type the code under Link with TV code.' } },
    { 'MeterTvPair', { 'Pair', 'Pair again' }, true },
    { 'MeterTvSwitch', { 'Start', 'Stop' }, true },
    { 'MeterTvForget', { 'Forget', 'Forget?' }, true }
}
local function width(meter, words, button)
    SKIN:Bang('!SetOption', 'MeterProbe', 'FontSize', SKIN:GetMeter(meter):GetOption('FontSize', ''))
    SKIN:Bang('!SetOption', 'MeterProbe', 'Text', words)
    SKIN:Bang('!UpdateMeter', 'MeterProbe')
    return SKIN:GetMeter('MeterProbe'):GetW()
end
-- The second load comes from the suite refresh Global Settings makes when Auto
-- check changes: the panel must show the changed setting.
local again
function Initialize()
    local file = io.open([[__REPORT__]] .. '.again', 'rb')
    again = file ~= nil
    if file then file:close() end
end
function Update()
    step = step + 1
    if again then
        if step == 2 then
            local file = assert(io.open([[__REPORT__]], 'ab'))
            file:write('update-after=', text('MeterUpdateState'), '\nDONE\n')
            file:close()
        end
        return 0
    end
    if step == 1 then
        local suite = assert(loadfile([[__SUITE__]]))()
        local passed, total, failed, detail = pcall(suite.run, [[__CONTROLLER__]])
        add('suite=' .. (passed and failed == 0 and 'PASS' or 'FAIL'))
        add('assertions=' .. tostring(passed and total or 0))
        for _, line in ipairs(passed and detail or { tostring(total) }) do add('detail=' .. line:gsub('[\r\n]+', ' | ')) end
        -- The live panel reads these on its next update.
        local folder = [[__LOCAL__]] .. '\\Parallax\\Media\\'
        local function write(name, data) local file = assert(io.open(folder .. name, 'wb')) file:write(data) file:close() end
        write('Spotify\\queue.snapshot', 'PARALLAX_QUEUE_V5\nstate=ready\nobserved=' .. now .. '\nvalid_until=' .. (now + 90)
            .. '\nretry_not_before=0\ncount=0\ncontrol=1\nnotice=\ncurrent_title=\ncurrent_detail=\n')
        write('Source\\source.snapshot', 'PARALLAX_SOURCE_V1\nstate=ready\nobserved=' .. (os.time() + 1) .. '\nvalid_until=' .. (os.time() + 61) .. '\ncount=0\n')
    elseif step == 4 then
        add('spotify=' .. text('MeterSpotifyState') .. '|' .. text('MeterSpotifyDetail') .. '|' .. text('MeterSignIn')
            .. '|' .. (SKIN:GetMeter('MeterDisconnect'):GetW() > 0 and 'disconnect' or 'none'))
        add('source=' .. text('MeterSourceState'))
        add('window=' .. SKIN:GetW() .. 'x' .. SKIN:GetH())
        local worst = 0
        for _, slot in ipairs(slots) do
            local meter = SKIN:GetMeter(slot[1])
            local room = meter:GetW()
            for _, words in ipairs(slot[2]) do
                local need = width(slot[1], words)
                worst = math.max(worst, need / room)
                if need > room then add('clipped=' .. slot[1] .. ' "' .. words .. '" ' .. need .. '/' .. room) end
            end
        end
        add('worst=' .. string.format('%.2f', worst))
        add('update-before=' .. text('MeterUpdateState'))
        add('')
        local file = assert(io.open([[__REPORT__]], 'wb'))
        file:write(table.concat(lines, '\n'))
        file:close()
        assert(io.open([[__REPORT__]] .. '.again', 'wb')):close()
        SKIN:Bang('!WriteKeyValue', 'Variables', 'UpdateCheck', '0', [[__SETTINGS__]])
        SKIN:Bang('!RefreshGroup', 'Parallax')
    end
    return 0
end
'@

$failures = [Collections.Generic.List[string]]::new()
foreach ($variant in @(
        @{ Name = 'default'; Width = 220; Scale = '1'; Font = '9' },
        @{ Name = 'narrow, largest text'; Width = 180; Scale = '1'; Font = '10' },
        @{ Name = 'narrow, largest text, 75%'; Width = 180; Scale = '0.75'; Font = '10' })) {
    $process = $null
    $stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'connections-test'
    $runRoot = $stage.StageRoot
    $skinRoot = Join-Path $runRoot 'Skins'
    $parallaxRoot = $stage.SkinRoot
    function Write-RunFile([string]$Path, [string]$Text) {
        if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
        [IO.File]::WriteAllText($Path, $Text, $utf8)
    }
    foreach ($name in 'Layouts', 'Plugins', 'Addons', 'Local', 'Local\Parallax\Media\Spotify', 'Local\Parallax\Media\Source', 'Local\Parallax\Media\YouTube') { $null = New-Item -ItemType Directory -Force -Path (Join-Path $runRoot $name) }
    Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated native Connections test with harness instrumentation. Do not distribute.`n"
    $localRoot = Join-Path $runRoot 'Local'
    # Stand-ins: the panel only checks that these exist.
    Write-RunFile (Join-Path $localRoot 'Parallax\Media\Spotify\tokens.dpapi') 'synthetic'
    Write-RunFile (Join-Path $localRoot 'Parallax\Media\Spotify\client.json') '{}'
    # Shows the TV row's Start and Forget, so their text is measured too.
    Write-RunFile (Join-Path $localRoot 'Parallax\Media\YouTube\pairing.dpapi') 'synthetic'
    $globalPath = Join-Path $parallaxRoot '@Resources\User\Settings.inc'
    $globalText = Get-Content -LiteralPath $globalPath -Raw
    foreach ($pair in @(@('Scale', $variant.Scale), @('ColumnWidth', $variant.Width), @('FontSize', $variant.Font))) {
        $globalText = [regex]::Replace($globalText, "(?m)^$($pair[0])=[^\r\n]*", "$($pair[0])=$($pair[1])")
    }
    Write-RunFile $globalPath $globalText
    $reportPath = Join-Path $runRoot 'connections-report.txt'
    $harnessPath = Join-Path $runRoot 'ConnectionsHarness.lua'
    $controllerPath = Join-Path $parallaxRoot '@Resources\Modules\Connections\Connections.lua'
    Write-RunFile $harnessPath ($harness.Replace('__SUITE__', $suitePath).Replace('__CONTROLLER__', $controllerPath).Replace('__REPORT__', $reportPath).Replace('__LOCAL__', $localRoot).Replace('__SETTINGS__', $globalPath))
    $panelPath = Join-Path $parallaxRoot 'Connections\Connections.ini'
    $panelText = (Get-Content -LiteralPath $panelPath -Raw) -replace '(?m)^Update=2000', 'Update=500'
    $panelText += "`n[MeterProbe]`nMeter=String`nMeterStyle=StyleLabel`nX=0`nY=0`nW=`nH=`nClipString=0`nFontColor=0,0,0,1`nText=x`n"
    $panelText += "`n[MeasureConnectionsHarness]`nMeasure=Script`nScriptFile=$harnessPath`nUpdateDivider=1`n"
    Write-RunFile $panelPath $panelText
    $iniPath = Join-Path $runRoot 'Rainmeter.ini'
    Write-RunFile $iniPath ("[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n" +
        "`n[Parallax\Connections]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n")
    Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    $realLocal = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $localRoot
        try { $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru }
        finally { $env:LOCALAPPDATA = $realLocal }
        $deadline = [DateTime]::UtcNow.AddSeconds($SettleSeconds)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ((Test-Path -LiteralPath $reportPath) -and (Get-Content -LiteralPath $reportPath -Raw) -match '(?m)^DONE\r?$') { break }
            Start-Sleep -Milliseconds 300
            $process.Refresh()
            if ($process.HasExited) { throw "Isolated instance exited early; inspect $runRoot\Rainmeter.log" }
        }
        if (-not (Test-Path -LiteralPath $reportPath)) { throw "Harness produced no report; inspect $runRoot\Rainmeter.log" }
        $report = @(Get-Content -LiteralPath $reportPath)
        Write-Output "--- $($variant.Name): width $($variant.Width), scale $($variant.Scale), body $($variant.Font) pt"
        $report | Where-Object { $_ -and $_ -ne 'DONE' } | Write-Output
        foreach ($line in 'suite=PASS', 'spotify=Signed in|Queue and playback control. Playlists not checked yet.|Sign in again|disconnect', 'source=On',
                'update-before=Daily, GitHub', 'update-after=Off') {
            if ($report -notcontains $line) { $failures.Add("$($variant.Name): expected '$line'") }
        }
        $report | Where-Object { $_ -like 'clipped=*' } | ForEach-Object { $failures.Add("$($variant.Name): $_") }
        $logPath = Join-Path $runRoot 'Rainmeter.log'
        if (Test-Path -LiteralPath $logPath) {
            @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^(ERRO|WARN)' }) | ForEach-Object { $failures.Add("$($variant.Name): $_") }
        }
    } finally {
        if ($null -ne $process) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
            $process.Dispose()
        }
    }
    Write-Output "Evidence retained at $runRoot"
}
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAIL: $_" }; throw 'Connections checks failed.' }
Write-Output 'PASS: Connections suite, native states and text fit.'
