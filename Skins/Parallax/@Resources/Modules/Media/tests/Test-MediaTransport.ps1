# Developer-only native capture check: a play/pause or capability change that
# reaches Media only through its provider sample (another app, a media key)
# must repaint the transport row without hover. Synthetic provider measures
# only; no WebNowPlaying, helper, queue cache, network or live Rainmeter
# profile. Every write and the Rainmeter instance belong to a fresh temp root.
# Run under Windows PowerShell 5.1 (pwsh reports window rects DPI-virtualised).
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    # The adapter under test (default: this checkout's Media.lua); another
    # revision's Media.lua reproduces a fault.
    [string]$AdapterPath = '',
    [ValidateSet('20','10','0')][string]$TitleAnimation = '20'
)

$ErrorActionPreference = 'Stop'
$testProcess = $null
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
if (-not $AdapterPath) { $AdapterPath = Join-Path $moduleRoot 'Media.lua' }
$AdapterPath = [IO.Path]::GetFullPath($AdapterPath)
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
# Short root: deep include paths past MAX_PATH are skipped silently by Rainmeter.
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('PxMT-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Test root escapes the temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent cannot be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test root must be fresh.' }
foreach ($required in @($RainmeterPath, $AdapterPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file missing: $required. Nothing is installed by this runner." }
}
$skinRoot = Join-Path $runRoot 'Skins'
$parallax = Join-Path $skinRoot 'Parallax'
foreach ($directory in @($runRoot, $skinRoot, $parallax, "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) { $null = New-Item -ItemType Directory -Path $directory -Force }
function Write-TestFile([string]$Path, [string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the test directory.' }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

# Media.ini and everything it includes; module scripts and includes only (no
# tests, no Source reader or PowerShell providers).
$sourceMap = [ordered]@{
    'Media\Media.ini' = (Join-Path $skinSource 'Media\Media.ini')
    '@Resources\Defaults.inc' = (Join-Path $resourcesRoot 'Defaults.inc')
    '@Resources\Idle\Hook0.inc' = (Join-Path $resourcesRoot 'Idle\Hook0.inc')
    '@Resources\Geometry.inc' = (Join-Path $resourcesRoot 'Geometry.inc')
    '@Resources\Styles.inc' = (Join-Path $resourcesRoot 'Styles.inc')
    '@Resources\User\Settings.inc' = (Join-Path $resourcesRoot 'User\Settings.inc')
    '@Resources\User\Visualizer.inc' = (Join-Path $resourcesRoot 'User\Visualizer.inc')
}
foreach ($file in Get-ChildItem -LiteralPath $moduleRoot -Recurse -File) {
    $relative = $file.FullName.Substring($moduleRoot.Length + 1)
    if ($relative -match '(^|\\)tests\\|^Source\\' -or $file.Extension -notin @('.inc', '.lua')) { continue }
    $sourceMap[('@Resources\Modules\Media\' + $relative)] = $file.FullName
}
$sourceMap['@Resources\Modules\Media\Media.lua'] = $AdapterPath
$visualizerRoot = Join-Path $resourcesRoot 'Modules\Visualizer'
foreach ($relative in @('Fallbacks.inc', 'Options.inc')) { $sourceMap[('@Resources\Modules\Visualizer\' + $relative)] = Join-Path $visualizerRoot $relative }
foreach ($preset in Get-ChildItem -LiteralPath (Join-Path $visualizerRoot 'HeightPresets') -Filter '*.inc') { $sourceMap[('@Resources\Modules\Visualizer\HeightPresets\' + $preset.Name)] = $preset.FullName }
foreach ($font in Get-ChildItem -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Filter '*.ttf') { $sourceMap[('@Resources\Fonts\' + $font.Name)] = $font.FullName }
$sourceHashes = [ordered]@{}
foreach ($relative in $sourceMap.Keys) {
    $destination = Join-Path $parallax $relative
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
    Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    $sourceHashes[$relative] = (Get-FileHash -LiteralPath $sourceMap[$relative] -Algorithm SHA256).Hash
}

# Shipped Media preferences, with the drawer closed to its tab (no audio
# capture) and the requested title animation.
Write-TestFile (Join-Path $parallax '@Resources\User\Media.inc') ("[Variables]`nColumns=2`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=0`nQueueRowLimit=5`nQueueShowDetails=1`nQueuePollSeconds=30`nVisualizerDrawer=1`nMediaTitleAnimation=$TitleAnimation`n")

# Provider: every WebNowPlaying measure becomes a built-in fixture with the
# production divider, so samples change only at the provider cadence.
# MeasureState and MeasureCanNext follow fixture variables that the observer
# changes, exactly as WebNowPlaying reports a change made in another app.
$providerPath = Join-Path $parallax '@Resources\Modules\Media\WebNowPlaying.inc'
$provider = [IO.File]::ReadAllText($providerPath)
$numeric = @{ MeasureConnection = '1'; MeasureState = '#FixtureState#'; MeasurePosition = '45'; MeasureDuration = '180'; MeasureProgress = '25'
    MeasureCanPrevious = '1'; MeasureCanPlayPause = '1'; MeasureCanNext = '#FixtureCanNext#' }
$strings = @{ MeasurePlayer = 'Synthetic player'; MeasureTitle = 'Synthetic title'; MeasureArtist = 'Synthetic artist'
    MeasureSourceArtist = 'Synthetic artist'; MeasureAlbum = 'Synthetic album'; MeasureCover = ''; MeasureMediaSource = 'Spotify' }
$replaced = 0
$provider = [regex]::Replace($provider, '(?ms)^\[(Measure\w+)\]\r?\n(.*?)(?=^\[|\z)', {
    param($match)
    $name = $match.Groups[1].Value
    $body = $match.Groups[2].Value
    if ($body -notmatch '(?m)^Plugin=WebNowPlaying\r?$' -and $body -notmatch '(?m)^ScriptFile=.*SourceReader\.lua\r?$') { return $match.Value }
    $keep = @([regex]::Matches($body, '(?m)^(UpdateDivider|MinValue|MaxValue)=[^\r\n]*') | ForEach-Object { $_.Value })
    if (-not @($keep -match '^UpdateDivider=').Count) { throw "Provider measure $name has no divider to preserve." }
    $script:replaced++
    if ($numeric.ContainsKey($name)) {
        $dynamic = if ($numeric[$name].StartsWith('#')) { "DynamicVariables=1`n" } else { '' }
        return "[$name]`nMeasure=Calc`nFormula=$($numeric[$name])`n$dynamic$($keep -join "`n")`n`n"
    }
    if (-not $strings.ContainsKey($name)) { throw "Unexpected provider measure $name." }
    return "[$name]`nMeasure=String`nString=$($strings[$name])`n$($keep -join "`n")`n`n"
})
if ($replaced -ne ($numeric.Count + $strings.Count)) { throw "Replaced $replaced provider measures; expected $($numeric.Count + $strings.Count)." }
Write-TestFile $providerPath $provider

# Inert hosts: no copied RunCommand can launch anything, even though the
# lifecycle script already refuses isolated profiles.
Write-TestFile (Join-Path $parallax '@Resources\Modules\Media\ProviderControlFixture.lua') "function Update() return 1 end`nfunction Run() end`n"
foreach ($entryFile in Get-ChildItem -LiteralPath $parallax -Recurse -File | Where-Object { $_.Extension -in @('.ini', '.inc') }) {
    $text = [IO.File]::ReadAllText($entryFile.FullName)
    $updated = $text
    foreach ($name in @('MeasureMediaSourceResume', 'MeasureMediaQueueResume')) {
        $updated = [regex]::Replace($updated, '(?ms)^\[' + $name + '\]\r?\n.*?(?=^\[|\z)', "[$name]`nMeasure=Script`nScriptFile=#@#Modules\Media\ProviderControlFixture.lua`nUpdateDivider=-1`n`n")
    }
    # The queue reader reads only a file inside this run root (absent: no queue).
    $readerLine = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
    $updated = $updated.Replace($readerLine, $readerLine + "`nQueueCachePath=$runRoot\no-queue.snapshot")
    if ($updated -ne $text) { Write-TestFile $entryFile.FullName $updated }
}
foreach ($fixture in Get-ChildItem -LiteralPath $parallax -Recurse -File | Where-Object { $_.Extension -in @('.ini', '.inc') }) {
    $fixtureText = [IO.File]::ReadAllText($fixture.FullName)
    if ($fixtureText -match '(?m)^\s*Plugin\s*=' -or $fixtureText -match '(?im)^\s*ScriptFile=.*SourceReader\.lua') { throw "A fixture still loads a plugin or the source reader: $($fixture.FullName)" }
}

# The observer only counts ticks, changes the fixture variables and reads
# state for the report. It forces the transport itself only to produce the
# ground-truth frames; nothing else touches Media's meters.
$readyPath = Join-Path $runRoot 'ready.txt'
$goPath = Join-Path $runRoot 'go.txt'
Write-TestFile $goPath '0'
Write-TestFile (Join-Path $runRoot 'TransportObserver.lua') @'
local tick, stage, waiting, waitUntil, legacy
local function force() SKIN:Bang('!UpdateMeterGroup', 'MediaTransport'); SKIN:Bang('!Redraw') end
-- Odd stages change only the provider sample; even stages force the
-- ground truth for the frame just captured.
local actions = {
    function() SKIN:Bang('!SetVariable', 'FixtureState', '2') end,
    force,
    function() SKIN:Bang('!SetVariable', 'FixtureState', '1') end,
    force,
    function() SKIN:Bang('!SetVariable', 'FixtureCanNext', '0') end,
    force
}
function Initialize()
    tick, stage, waiting = 0, 0, true
    legacy = SKIN:ParseFormula(SKIN:ReplaceVariables('(#MediaLegacyDivider#)'))
    waitUntil = 2 * legacy + 4
end
local function bounds(name)
    local meter = SKIN:GetMeter(name)
    return string.format('%s:%d,%d,%d,%d', name, meter:GetX(), meter:GetY(), meter:GetW(), meter:GetH())
end
local function report()
    local lines = { 'stage=' .. stage, 'tick=' .. tick, 'legacy=' .. legacy,
        'status=' .. SKIN:GetMeasure('MeasureMediaUI'):GetStringValue(),
        'shape4=' .. SKIN:GetMeter('MeterPlayPause'):GetOption('Shape4'),
        'nextstroke=' .. SKIN:GetMeter('MeterNext'):GetOption('LucideTransportStroke'),
        'muted=' .. SKIN:GetVariable('MutedColor'),
        'bounds=' .. bounds('MeterPrevious') .. ';' .. bounds('MeterPlayPause') .. ';' .. bounds('MeterNext'),
        'end' }
    local path = SELF:GetOption('ReadyFile')
    local file = assert(io.open(path .. '.tmp', 'wb'))
    file:write(table.concat(lines, '\n') .. '\n')
    file:close()
    os.remove(path)
    assert(os.rename(path .. '.tmp', path))
end
local function go()
    local file = io.open(SELF:GetOption('GoFile'), 'rb')
    if not file then return 0 end
    local text = file:read('*a')
    file:close()
    return tonumber(text) or 0
end
function Update()
    tick = tick + 1
    if waiting then
        if tick >= waitUntil then
            waiting = false
            report()
        end
        return stage
    end
    if go() <= stage then return stage end
    stage = stage + 1
    local action = actions[stage]
    if not action then SKIN:Bang('!Quit'); return stage end
    action()
    -- A provider change needs two full provider cycles; a forced frame only
    -- the next tick's paint.
    waiting, waitUntil = true, tick + (stage % 2 == 1 and 2 * legacy + 4 or 3)
    return stage
end
'@
$entryPath = Join-Path $parallax 'Media\Media.ini'
$entry = [IO.File]::ReadAllText($entryPath)
if ([regex]::Matches($entry, '(?m)^\[Variables\]\r?$').Count -ne 1) { throw 'Expected one [Variables] section in Media.ini.' }
$entry = [regex]::Replace($entry, '(?m)^\[Variables\]\r?$', "[Variables]`nFixtureState=1`nFixtureCanNext=1")
$entry += "`n[MeasureTransportObserver]`nMeasure=Script`nScriptFile=$runRoot\TransportObserver.lua`nUpdateDivider=1`nReadyFile=$readyPath`nGoFile=$goPath`n"
Write-TestFile $entryPath $entry
Write-TestFile (Join-Path $runRoot 'Rainmeter.ini') "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[Parallax\Media]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxMediaTransportCapture' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxMediaTransportCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    private delegate bool Callback(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback,IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd,IntPtr destination,uint flags);
    public static IntPtr[] OwnWindows(uint pid) {
        var result=new List<IntPtr>();
        EnumWindows((hwnd,data)=>{
            uint owner;GetWindowThreadProcessId(hwnd,out owner);if(owner!=pid)return true;
            var cls=new StringBuilder(256);GetClassName(hwnd,cls,cls.Capacity);
            if(cls.ToString()=="RainmeterMeterWindow")result.Add(hwnd);
            return true;
        },IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
function Wait-Ready([int]$Stage) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $deadline) {
        $testProcess.Refresh()
        if ($testProcess.HasExited) { throw "Isolated Rainmeter exited before stage $Stage; inspect $runRoot\Rainmeter.log" }
        # The observer replaces the report by delete and rename, so the file
        # can be briefly missing or pending deletion; retry on the next poll.
        $text = $null
        try { $text = [IO.File]::ReadAllText($readyPath) } catch [IO.IOException] { } catch [UnauthorizedAccessException] { }
        if ($text) {
            if ($text -and $text -match "(?m)^stage=$Stage$" -and $text -match '(?m)^end$') {
                $values = @{}
                foreach ($line in $text -split "`n") { if ($line -match '^([a-z0-9]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] } }
                return $values
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Timed out waiting for observer stage $Stage."
}
function Save-Capture([string]$Name) {
    $windows = @([ParallaxMediaTransportCapture]::OwnWindows([uint32]$testProcess.Id))
    if ($windows.Count -ne 1) { throw "Expected one Media window, found $($windows.Count)." }
    $rect = New-Object ParallaxMediaTransportCapture+RECT
    if (-not [ParallaxMediaTransportCapture]::GetWindowRect($windows[0], [ref]$rect)) { throw 'Cannot read the window rectangle.' }
    $width = $rect.Right - $rect.Left; $height = $rect.Bottom - $rect.Top
    if ($width -lt 1 -or $height -lt 1 -or $width -gt 2048 -or $height -gt 2048) { throw "Unexpected capture size ${width}x${height}." }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxMediaTransportCapture]::PrintWindow($windows[0], $hdc, 2)
        $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
        if (-not $printed) { throw 'PrintWindow failed.' }
    } finally {
        if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
        $graphics.Dispose()
    }
    $file = Join-Path $runRoot "$Name.png"
    $bitmap.Save($file, [Drawing.Imaging.ImageFormat]::Png)
    return [pscustomobject]@{ Name = $Name; File = $file; Bitmap = $bitmap; Width = $width; Height = $height }
}
function Get-Region([string]$Bounds, [string[]]$Meters) {
    $left = [int]::MaxValue; $top = [int]::MaxValue; $right = [int]::MinValue; $bottom = [int]::MinValue
    foreach ($meter in $Meters) {
        $match = [regex]::Match($Bounds, [regex]::Escape($meter) + ':(-?\d+),(-?\d+),(\d+),(\d+)')
        if (-not $match.Success) { throw "No bounds for $meter." }
        $x = [int]$match.Groups[1].Value; $y = [int]$match.Groups[2].Value
        $left = [math]::Min($left, $x); $top = [math]::Min($top, $y)
        $right = [math]::Max($right, $x + [int]$match.Groups[3].Value); $bottom = [math]::Max($bottom, $y + [int]$match.Groups[4].Value)
    }
    return [pscustomobject]@{ Left = $left; Top = $top; Right = $right; Bottom = $bottom }
}
function Measure-Difference($First, $Second, $Region) {
    if ($First.Width -ne $Second.Width -or $First.Height -ne $Second.Height) { throw "Window size changed between $($First.Name) and $($Second.Name)." }
    if ($Region.Left -lt 0 -or $Region.Top -lt 0 -or $Region.Right -gt $First.Width -or $Region.Bottom -gt $First.Height) { throw 'Transport region lies outside the capture.' }
    $count = 0
    for ($y = $Region.Top; $y -lt $Region.Bottom; $y++) { for ($x = $Region.Left; $x -lt $Region.Right; $x++) {
        if ($First.Bitmap.GetPixel($x, $y).ToArgb() -ne $Second.Bitmap.GetPixel($x, $y).ToArgb()) { $count++ }
    } }
    return $count
}

$captures = @{}
$failures = [Collections.Generic.List[string]]::new()
try {
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $runRoot 'Rainmeter.ini')) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $names = @('1-playing', '2-external-pause', '3-forced-pause', '4-external-resume', '5-forced-resume', '6-external-next-unsupported', '7-forced-next-unsupported')
    $states = @{}
    for ($stage = 0; $stage -lt $names.Count; $stage++) {
        $states[$stage] = Wait-Ready $stage
        $captures[$stage] = Save-Capture $names[$stage]
        Write-TestFile $goPath ([string]($stage + 1))
    }
    $null = $testProcess.WaitForExit(10000)

    # The provider transitions really reached the adapter, so a stale frame is
    # a paint failure, not a missed sample.
    $expect = @{ 0 = 'Playing'; 1 = 'Paused'; 2 = 'Paused'; 3 = 'Playing'; 4 = 'Playing'; 5 = 'Playing'; 6 = 'Playing' }
    foreach ($stage in $expect.Keys) { if ($states[$stage].status -ne $expect[$stage]) { throw "Stage $stage reported '$($states[$stage].status)', expected '$($expect[$stage])'." } }
    if (-not $states[1].shape4.StartsWith('Rectangle ')) { throw 'Paused sample did not select the Pause art.' }
    if ($states[3].shape4 -ne 'Path LucideTransportPlayPath | Extend LucideTransportStroke') { throw 'Resumed sample did not select the Play art.' }
    if (-not $states[5].nextstroke.Contains('Stroke Color ' + $states[5].muted)) { throw 'Unsupported Next did not select the muted stroke.' }

    $row = Get-Region $states[0].bounds @('MeterPrevious', 'MeterPlayPause', 'MeterNext')
    $next = Get-Region $states[0].bounds @('MeterNext')
    $diff = [ordered]@{
        PlayingVsForcedPause = Measure-Difference $captures[0] $captures[2] $row
        ExternalPauseVsForcedPause = Measure-Difference $captures[1] $captures[2] $row
        ExternalPauseVsPlaying = Measure-Difference $captures[1] $captures[0] $row
        ExternalResumeVsForcedResume = Measure-Difference $captures[3] $captures[4] $row
        ForcedResumeVsPlaying = Measure-Difference $captures[4] $captures[0] $row
        NextSupportedVsForcedUnsupported = Measure-Difference $captures[4] $captures[6] $next
        ExternalUnsupportedVsForcedUnsupported = Measure-Difference $captures[5] $captures[6] $row
    }
    # Ground truth must differ where the art changes, or the check proves nothing.
    if ($diff.PlayingVsForcedPause -lt 20) { $failures.Add('Forced Pause art is not distinguishable from Play art.') }
    if ($diff.NextSupportedVsForcedUnsupported -lt 20) { $failures.Add('Forced muted Next is not distinguishable from enabled Next.') }
    if ($diff.ForcedResumeVsPlaying -ne 0) { $failures.Add('Forced Play art after the round trip differs from the original Play art.') }
    # The provider-only changes must paint exactly the forced frames.
    if ($diff.ExternalPauseVsForcedPause -ne 0) { $failures.Add("External pause left the transport stale: $($diff.ExternalPauseVsForcedPause) pixels differ from the forced Pause frame.") }
    if ($diff.ExternalResumeVsForcedResume -ne 0) { $failures.Add("External resume left the transport stale: $($diff.ExternalResumeVsForcedResume) pixels differ from the forced Play frame.") }
    if ($diff.ExternalUnsupportedVsForcedUnsupported -ne 0) { $failures.Add("A capability change left the transport stale: $($diff.ExternalUnsupportedVsForcedUnsupported) pixels differ from the forced frame.") }

    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $logErrors = @()
    if (Test-Path -LiteralPath $logPath) { $logErrors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }
    foreach ($line in $logErrors) { $failures.Add("Rainmeter error: $line") }
    $evidence = [ordered]@{
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        OwnedPid = $testProcess.Id
        RainmeterVersion = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion
        AdapterPath = $AdapterPath
        AdapterSha256 = (Get-FileHash -LiteralPath $AdapterPath -Algorithm SHA256).Hash
        TitleAnimation = $TitleAnimation
        LegacyDivider = $states[0].legacy
        Window = "$($captures[0].Width)x$($captures[0].Height)"
        TransportRegion = $row
        PixelDifferences = $diff
        Captures = @($names | ForEach-Object { Join-Path $runRoot "$_.png" })
        Failures = @($failures)
        SourceSha256 = $sourceHashes
        Provider = 'none; built-in Calc/String fixtures with the production dividers'
    }
    Write-TestFile (Join-Path $runRoot 'transport-evidence.json') ($evidence | ConvertTo-Json -Depth 4)
    Write-Output ("Window $($evidence.Window), legacy divider $($states[0].legacy), transport region " + ($row | ConvertTo-Json -Compress))
    Write-Output ($diff | ConvertTo-Json)
    Write-Output "Isolated evidence retained at $runRoot"
    if ($failures.Count) { throw ("Media transport repaint check failed:`n" + ($failures -join "`n")) }
    Write-Output 'PASS: provider-only pause, resume and capability changes repaint the transport exactly as a forced update does.'
    if ((Get-FileHash -LiteralPath $AdapterPath -Algorithm SHA256).Hash -ne $evidence.AdapterSha256) { throw 'Adapter changed during the test; rerun for current evidence.' }
} finally {
    foreach ($capture in $captures.Values) { $capture.Bitmap.Dispose() }
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) {
            Stop-Process -InputObject $testProcess -Force
            $null = $testProcess.WaitForExit(5000)
        }
        $testProcess.Dispose()
    }
    # Retain the fresh temp evidence; nothing outside it is deleted or changed.
}
