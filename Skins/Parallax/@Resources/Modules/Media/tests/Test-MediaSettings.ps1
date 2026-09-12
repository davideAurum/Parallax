# Native copied-source Media settings/accordion/typography tests. Synthetic data only.
# No helper executable, OAuth material, live queue or live Rainmeter config is used.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),[switch]$TypographyStatusProbeOnly,[switch]$SourceIntegrationFocused,[switch]$ArtworkFocused)
$ErrorActionPreference = 'Stop'
$testProcess = $null
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-MediaSettings-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Test root escapes temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent cannot be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test root must be fresh.' }
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$skinRoot = Join-Path $runRoot 'Skins'
foreach ($directory in @($skinRoot,"$runRoot\Layouts","$runRoot\Plugins","$runRoot\Addons")) { $null = New-Item -ItemType Directory -Path $directory -Force }
function Write-TestFile([string]$Path,[string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes test directory.' }
    [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}
$sourceMap = [ordered]@{
    'Media\Media.ini' = (Join-Path $skinSource 'Media\Media.ini')
    'Media\Setup.ini' = (Join-Path $skinSource 'Media\Setup.ini')
    'Media\Settings\Settings.ini' = (Join-Path $skinSource 'Media\Settings\Settings.ini')
    '@Resources\Defaults.inc' = (Join-Path $resourcesRoot 'Defaults.inc')
    '@Resources\Geometry.inc' = (Join-Path $resourcesRoot 'Geometry.inc')
    '@Resources\Styles.inc' = (Join-Path $resourcesRoot 'Styles.inc')
    '@Resources\User\Settings.inc' = (Join-Path $resourcesRoot 'User\Settings.inc')
    '@Resources\User\Media.inc' = (Join-Path $resourcesRoot 'User\Media.inc')
}
# Module includes/scripts only: exclude tests and the PowerShell service/auth code.
foreach ($file in Get-ChildItem -LiteralPath $moduleRoot -Recurse -File) {
    $relative = $file.FullName.Substring($moduleRoot.Length+1)
    if ($relative -match '(^|\\)tests\\|^Source\\' -or $file.Extension -notin @('.inc','.lua')) { continue }
    $sourceMap[('@Resources\Modules\Media\'+$relative)] = $file.FullName
}
foreach ($font in Get-ChildItem -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Filter '*.ttf') { $sourceMap[('@Resources\Fonts\'+$font.Name)] = $font.FullName }
$sourceHashes = @{}
foreach ($path in $sourceMap.Values) { $sourceHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$harnessPath = Join-Path $runRoot 'MediaSettingsSuite.lua'
[IO.File]::WriteAllText($harnessPath,[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'MediaSettingsSuite.luatest')),[Text.Encoding]::Unicode)
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$settings = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = @()
$index = 0
function Write-TypographyFixture([string]$CaseRoot,[string]$Profile,[double]$FixtureScale=1) {
    $titleSize=if ($Profile -eq 'max') { 12 } else { 10 }
    $headerSize=if ($Profile -eq 'max') { 10 } else { 8 }
    $bodySize=if ($Profile -eq 'max') { 10 } else { 9 }
    $thickness=if ($Profile -eq 'max') { if ($FixtureScale -in @(0.75,1.5)) { 0 } else { 4 } } else { 1 }
    Write-TestFile (Join-Path $CaseRoot '@Resources\User\Settings.inc') "[Variables]`nTitleFontSize=$titleSize`nHeaderFontSize=$headerSize`nFontSize=$bodySize`nTitleTextColor=211,181,249`nHeaderTextColor=110,218,175`nTextColor=234,210,145`nAccentColor=95,188,246`nAccentColor2=246,138,174`nBorderThickness=$thickness`nDividerThickness=$thickness`nDividerColor=219,122,81`n"
}
Add-Type -AssemblyName System.Drawing
function Write-SyntheticCover([string]$Path) {
    # Original, deterministic fixture only. Its quadrants make scaling and crop
    # visible without copying any album artwork or reading a player's metadata.
    $bitmap=[Drawing.Bitmap]::new(192,192)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $colors=@([Drawing.Color]::FromArgb(34,85,130),[Drawing.Color]::FromArgb(82,153,171),[Drawing.Color]::FromArgb(208,137,100),[Drawing.Color]::FromArgb(107,82,137))
        for ($quadrant=0;$quadrant -lt 4;$quadrant++) {
            $brush=[Drawing.SolidBrush]::new($colors[$quadrant])
            try { $graphics.FillRectangle($brush,($quadrant%2)*96,[int][math]::Floor($quadrant/2)*96,96,96) } finally { $brush.Dispose() }
        }
        $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(232,226,202),8)
        try { $graphics.DrawEllipse($pen,36,36,120,120);$graphics.DrawLine($pen,48,144,144,48) } finally { $pen.Dispose() }
        # A transparent center exposes any stale No art label underneath a
        # populated image. The native suite also checks the label visibility.
        $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
        $clear=[Drawing.SolidBrush]::new([Drawing.Color]::Transparent)
        try { $graphics.FillRectangle($clear,64,80,64,32) } finally { $clear.Dispose() }
        $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose();$bitmap.Dispose() }
}
$kinds=if ($ArtworkFocused) { @('ArtworkSetup','ArtworkPlayer','ArtworkPlayerMissing') } else { @('Accordion','Settings','TypographySetup','TypographySettings','TypographyPlayer','TypographyPlayerDefault') }
foreach ($kind in $kinds) { foreach ($width in @(180,200)) { foreach ($scale in @(0.75,1,1.25,1.5,2)) { foreach ($columns in @(1,2)) {
    if ($ArtworkFocused -and $scale -notin @(0.75,1,2)) { continue }
    if ($TypographyStatusProbeOnly -and -not ($kind -eq 'TypographyPlayer' -and $width -eq 180 -and $scale -eq 1 -and $columns -eq 1)) { continue }
    if ($SourceIntegrationFocused -and ($kind -notin @('Settings','TypographySettings','TypographyPlayer','TypographyPlayerDefault') -or $scale -notin @(0.75,1,2))) { continue }
    $isSettings=$kind.EndsWith('Settings')
    $isTypography=$kind.StartsWith('Typography')
    $isPlayer=$kind.Contains('Player')
    if ($isSettings -and $columns -eq 1) { continue }
    if ($isTypography -and -not $isSettings -and $columns -eq 2) { continue }
    if ($isPlayer -and $width -eq 200 -and -not $ArtworkFocused) { continue }
    $profile=if ($ArtworkFocused -or ($isTypography -and $kind -ne 'TypographyPlayerDefault')) { 'max' } else { 'default' }
    $index++
    $name = 'Case{0:D2}' -f $index
    $caseRoot = Join-Path $skinRoot $name
    foreach ($relative in $sourceMap.Keys) {
        $destination = Join-Path $caseRoot $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    }
    Write-TypographyFixture $caseRoot $profile $scale
    $scaleText = $scale.ToString([Globalization.CultureInfo]::InvariantCulture)
    $preferencesPath = Join-Path $caseRoot '@Resources\User\Media.inc'
    $expanded=if ($isTypography -and -not $isSettings) { 1 } else { 0 }
    $preferences = "[Variables]`nColumns=$columns`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=$expanded`nQueueRowLimit=5`nQueueShowDetails=1`nQueuePollSeconds=30`nScale=$scaleText`nColumnWidth=$width`nUnrelatedSentinel=preserve-me`n"
    Write-TestFile $preferencesPath $preferences
    $cache = Join-Path $runRoot ("synthetic-$name.snapshot")
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $snapshot = "PARALLAX_QUEUE_V2`nstate=ready`nobserved=$now`nvalid_until=$($now+240)`nretry_not_before=0`ncount=5`n"
    foreach ($row in 1..5) {
        $title = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Synthetic item $row")).Replace('-','')
        $detail = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Test artist $row")).Replace('-','')
        $snapshot += "title$row=$title`ndetail$row=$detail`n"
    }
    Write-TestFile $cache $snapshot
    $report = Join-Path $runRoot ("result-$name.txt")
    $stateFile = Join-Path $runRoot ("stage-$name.txt")
    Write-TestFile $stateFile '1'
    foreach ($scriptHost in Get-ChildItem -LiteralPath $caseRoot -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
        $text = [IO.File]::ReadAllText($scriptHost.FullName)
        $readerLine = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        if ($text.Contains($readerLine)) { Write-TestFile $scriptHost.FullName ($text.Replace($readerLine,$readerLine+"`nQueueCachePath=$cache")) }
    }
    # Replace in every copied config, including unloaded variants, so a fixture
    # selection error can never access a real provider.
    if ($true) {
        # Replace the copied provider include with built-in, constant fixtures.
        # Official String measure: rainmeter/rainmeter-docs source/manual/measures/string.html.
        $synthetic=''
        $numeric=@{MeasureConnection=1;MeasureState=1;MeasurePosition=45;MeasureDuration=180;MeasureProgress=25;MeasureCanPrevious=1;MeasureCanPlayPause=1;MeasureCanNext=1}
        foreach ($measureName in $numeric.Keys) { $synthetic+="[$measureName]`nMeasure=Calc`nFormula=$($numeric[$measureName])`n`n" }
        $coverPath=Join-Path $caseRoot 'synthetic-cover.png'
        Write-SyntheticCover $coverPath
        $strings=@{MeasureTitle='Agpqy title';MeasureArtist='Agpqy artist';MeasureSourceArtist='Agpqy artist';MeasureAlbum='Synthetic album';MeasurePlayer='Windows Media Session';MeasureMediaSource='Spotify';MeasureCover=$coverPath}
        foreach ($measureName in $strings.Keys) {
            if ($measureName -eq 'MeasureCover' -and $kind -eq 'ArtworkPlayerMissing') {
                $synthetic+="[$measureName]`nMeasure=String`nString=__NO_ART__`nSubstitute=`"__NO_ART__`":`"`"`n`n"
            } else { $synthetic+="[$measureName]`nMeasure=String`nString=$($strings[$measureName])`n`n" }
        }
        $synthetic+="[MeasureMediaUI]`nMeasure=Script`nScriptFile=#@#Modules\Media\Media.lua`n"
        Write-TestFile (Join-Path $caseRoot '@Resources\Modules\Media\WebNowPlaying.inc') $synthetic
    }
    $entryRelative = if ($isSettings) { 'Media\Settings\Settings.ini' } elseif ($isPlayer) { 'Media\Media.ini' } else { 'Media\Setup.ini' }
    $entryPath = Join-Path $caseRoot $entryRelative
    $entry = [IO.File]::ReadAllText($entryPath)
    # Settings is event-driven; this test-only observer needs timed checkpoints.
    if ($isSettings) { $entry = [regex]::Replace($entry,'(?m)^Update=-1\r?$', 'Update=1000') }
    $hoverEnter = [regex]::Match($entry,'(?m)^MouseOverAction=(.*)$').Groups[1].Value.Trim()
    $hoverLeave = [regex]::Match($entry,'(?m)^MouseLeaveAction=(.*)$').Groups[1].Value.Trim()
    $entry += @"

[MeasureMediaSettingsTest]
Measure=Script
ScriptFile=$harnessPath
Kind=$kind
TypographyProfile=$profile
StatusProbeOnly=$([int]$TypographyStatusProbeOnly.IsPresent)
SyntheticCachePath=$cache
ResultFile=$report
StageFile=$stateFile
PreferencesPath=$preferencesPath
HoverEnter=$hoverEnter
HoverLeave=$hoverLeave
ExpectedWidth=$width
ExpectedScale=$scaleText
ExpectedColumns=$columns
"@
    $probes=if ($isSettings) {
        @(@('MeterTitle','Media settings'),@('MeterQueueHeading','Spotify queue'),@('MeterQueuePollLabel','Queue refresh'),
          @('MeterQueuePollValue','120 seconds'),@('MeterStatus','Use Restart to apply interval.'),@('MeterDisconnect','Disconnect'),
          @('MeterPlayerSetup','Player setup'),@('MeterClose','X'),@('MeterSourceLabel','Source detection'),@('MeterSourceStart','Start'),@('MeterSourceStop','Stop'))
    } else {
        @(@('MeterHeading','Media'),@('MeterQueueHeading','Queue -'),@('MeterQueueStatus','Storage error'),@('MeterQueueRow1','Track / Artist'))
    }
    if ($isPlayer) { $probes+=@(@('MeterTrackTitle','Agpqy title'),@('MeterArtist','Agpqy artist'),@('MeterAlbum','Synthetic album'),@('MeterPlayerName','Spotify'),@('MeterTiming','0:45 / 3:00'),@('MeterPrevious','|<'),@('MeterPlayPause','||'),@('MeterNext','>|')) }
    elseif (-not $isSettings) { $probes+=@(@('MeterSetupInstructions','1. Install WNP 2.x+.#CRLF#2. Open a player.'),@('MeterDesktopNote','Browser: add extension.'),@('MeterWNPDocs','WNP docs'),@('MeterLoadPlayer','Load player')) }
    foreach ($probe in $probes) {
        $entry+="`n[Probe$($probe[0])]`nMeter=String`nGroup=TypographyProbes`nX=0`nY=0`nText=$($probe[1])`nClipString=0`nHidden=1`nFontColor=0,0,0,0`nPadding=0,0,0,0`nAntiAlias=1`n"
    }
    if (-not $isSettings) {
        $statusIndex=0
        foreach ($label in @('Storage unavailable','Spotify unavailable','Queue unavailable','App quota reached','Provider stopped')) {
            $statusIndex++
            $entry+="`n[ProbeStatus$statusIndex]`nMeter=String`nGroup=TypographyProbes`nX=0`nY=0`nText=$label`nClipString=0`nHidden=1`nFontColor=0,0,0,0`nPadding=0,0,0,0`nAntiAlias=1`n"
        }
    }
    Write-TestFile $entryPath $entry
    $configName = $name+'\'+(Split-Path -Parent $entryRelative)
    $variantNames=@(Get-ChildItem -LiteralPath (Split-Path -Parent $entryPath) -Filter '*.ini' | Sort-Object Name | ForEach-Object { $_.Name })
    $activeVariant=[Array]::IndexOf($variantNames,(Split-Path -Leaf $entryPath))+1
    if ($activeVariant -lt 1) { throw 'Cannot select exact copied config variant.' }
    $settings += "`n[$configName]`nActive=$activeVariant`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $cases += [pscustomobject]@{Name=$name;Kind=$kind;Profile=$profile;Width=$width;Scale=$scale;Columns=$columns;Report=$report;Preferences=$preferencesPath}
} } } }
# Fail closed before launching any fixture if a copied active or inactive variant
# could load a real player plugin or the private source-detection cache reader.
foreach ($fixture in Get-ChildItem -LiteralPath $skinRoot -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
    $fixtureText=[IO.File]::ReadAllText($fixture.FullName)
    if ($fixtureText -match '(?m)^\s*Plugin\s*=' -or $fixtureText -match '(?im)^\s*ScriptFile=.*SourceReader\.lua') {
        throw 'A native UI fixture still contains a real provider or source reader.'
    }
}
Write-TestFile $iniPath $settings
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
# Register inert unloaded targets for the controller's fixed refresh bangs.
# This matches installed names while no live target or helper is ever loaded.
foreach ($inactive in @('Parallax\Media\Setup.ini','Parallax\Media\Queue\Queue.ini','Parallax\Media\Settings\Settings.ini')) {
    $inactivePath=Join-Path $skinRoot $inactive
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $inactivePath) -Force
    Write-TestFile $inactivePath "[Rainmeter]`nUpdate=-1`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,0`n"
}
function Test-LabelSync {
    $syncProcess=$null
    $syncRoot=Join-Path $runRoot 'Sync'
    $syncSkinRoot=Join-Path $syncRoot 'Skins'
    $syncParallax=Join-Path $syncSkinRoot 'Parallax'
    foreach ($directory in @($syncParallax,"$syncRoot\Layouts","$syncRoot\Plugins","$syncRoot\Addons")) { $null=New-Item -ItemType Directory -Path $directory -Force }
    foreach ($relative in $sourceMap.Keys) {
        $destination=Join-Path $syncParallax $relative
        $null=New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    }
    Write-TypographyFixture $syncParallax 'default'
    Copy-Item -LiteralPath (Join-Path $skinRoot 'Case01\@Resources\Modules\Media\WebNowPlaying.inc') -Destination (Join-Path $syncParallax '@Resources\Modules\Media\WebNowPlaying.inc')
    $syncPrefs=Join-Path $syncParallax '@Resources\User\Media.inc'
    Write-TestFile $syncPrefs "[Variables]`nColumns=1`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=0`nQueueRowLimit=5`nQueueShowDetails=1`nQueuePollSeconds=30`nScale=1`nColumnWidth=200`nUnrelatedSentinel=preserve-me`n"
    $syncCache=Join-Path $syncRoot 'synthetic.snapshot'
    $syncNow=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $syncSnapshot="PARALLAX_QUEUE_V2`nstate=ready`nobserved=$syncNow`nvalid_until=$($syncNow+120)`nretry_not_before=0`ncount=5`n"
    foreach ($row in 1..5) {
        $title=[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Synthetic item $row")).Replace('-','')
        $detail=[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Test artist $row")).Replace('-','')
        $syncSnapshot+="title$row=$title`ndetail$row=$detail`n"
    }
    Write-TestFile $syncCache $syncSnapshot
    foreach ($scriptHost in Get-ChildItem -LiteralPath $syncParallax -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
        $text=[IO.File]::ReadAllText($scriptHost.FullName)
        $readerLine='ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        if ($text.Contains($readerLine)) { Write-TestFile $scriptHost.FullName ($text.Replace($readerLine,$readerLine+"`nQueueCachePath=$syncCache")) }
    }
    $syncReport=Join-Path $syncRoot 'result.txt'
    $syncStage=Join-Path $syncRoot 'stage.txt'
    $syncLabel=Join-Path $syncRoot 'settings-label.txt'
    Write-TestFile $syncStage '1'
    Write-TestFile $syncLabel 'not initialized'
    foreach ($kind in @('SyncMain','SyncSettings')) {
        $relative=if ($kind -eq 'SyncMain') { 'Media\Setup.ini' } else { 'Media\Settings\Settings.ini' }
        $entryPath=Join-Path $syncParallax $relative
        $entry=[IO.File]::ReadAllText($entryPath)
        if ($kind -eq 'SyncSettings') { $entry=[regex]::Replace($entry,'(?m)^Update=-1\r?$','Update=1000') }
        $hoverEnter=[regex]::Match($entry,'(?m)^MouseOverAction=(.*)$').Groups[1].Value.Trim()
        $hoverLeave=[regex]::Match($entry,'(?m)^MouseLeaveAction=(.*)$').Groups[1].Value.Trim()
        $entry+=@"

[MeasureMediaSettingsTest]
Measure=Script
ScriptFile=$harnessPath
Kind=$kind
SyntheticCachePath=$syncCache
ResultFile=$syncReport
StageFile=$syncStage
SyncLabelFile=$syncLabel
PreferencesPath=$syncPrefs
HoverEnter=$hoverEnter
HoverLeave=$hoverLeave
ExpectedWidth=200
ExpectedScale=1
ExpectedColumns=1
"@
        Write-TestFile $entryPath $entry
    }
    $inactiveQueue=Join-Path $syncParallax 'Media\Queue\Queue.ini'
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $inactiveQueue) -Force
    Write-TestFile $inactiveQueue "[Rainmeter]`nUpdate=-1`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,0`n"
    $syncIni=Join-Path $syncRoot 'Rainmeter.ini'
    $syncSettings="[Rainmeter]`nSkinPath=$syncSkinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    foreach ($configName in @('Parallax\Media','Parallax\Media\Settings')) {
        $activeVariant=if ($configName -eq 'Parallax\Media') { 2 } else { 1 }
        $syncSettings+="`n[$configName]`nActive=$activeVariant`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    }
    Write-TestFile $syncIni $syncSettings
    Write-TestFile (Join-Path $syncRoot 'Rainmeter.data') "[Rainmeter]`n"
    try {
        $syncProcess=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $syncIni) -WorkingDirectory $syncRoot -WindowStyle Hidden -PassThru
        $deadline=[DateTime]::UtcNow.AddSeconds(20)
        do { Start-Sleep -Milliseconds 200 } while (-not (Test-Path -LiteralPath $syncReport) -and [DateTime]::UtcNow -lt $deadline)
        if (-not (Test-Path -LiteralPath $syncReport)) { throw "No live-label sync report; inspect $syncRoot\Rainmeter.log" }
        $report=Get-Content -LiteralPath $syncReport -Raw
        $errors=@(Get-Content -LiteralPath (Join-Path $syncRoot 'Rainmeter.log') | Where-Object { $_ -match '^ERRO' })
        if ($report -notmatch '^PASS ' -or $errors.Count) { throw ($report+"`n"+($errors -join "`n")) }
        return [pscustomobject]@{Report=$report.Trim();LogErrors=$errors;OwnedPid=$syncProcess.Id;Evidence=$syncRoot}
    } finally {
        if ($null -ne $syncProcess) {
            $syncProcess.Refresh()
            if (-not $syncProcess.HasExited) { Stop-Process -InputObject $syncProcess -Force; $null=$syncProcess.WaitForExit(5000) }
            $syncProcess.Dispose()
        }
    }
}

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxMediaSettingsCapture' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxMediaSettingsCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width,Height; }
    private delegate bool Callback(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback,IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd,IntPtr destination,uint flags);
    public static Window[] OwnWindows(uint pid) {
        var result=new List<Window>();
        EnumWindows((hwnd,data)=>{
            uint owner;GetWindowThreadProcessId(hwnd,out owner);if(owner!=pid)return true;
            var cls=new StringBuilder(256);GetClassName(hwnd,cls,cls.Capacity);if(cls.ToString()!="RainmeterMeterWindow")return true;
            var title=new StringBuilder(1024);GetWindowText(hwnd,title,title.Capacity);
            RECT rect;if(GetWindowRect(hwnd,out rect))result.Add(new Window{Handle=hwnd,Title=title.ToString(),Width=rect.Right-rect.Left,Height=rect.Bottom-rect.Top});
            return true;
        },IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
function Save-ViewCaptures([uint32]$OwnedPid) {
    $captures=@()
    foreach ($window in [ParallaxMediaSettingsCapture]::OwnWindows($OwnedPid)) {
        $captureCases=@('Case13','Case27','Case31','Case32','Case42','Case52','Case57')
        $case=@($cases | Where-Object { $window.Title.Contains($_.Name+'\Media') })
        if ($case.Count -ne 1) { continue }
        if ($ArtworkFocused) {
            $wideRepresentative=$case[0].Columns -eq 2 -and $case[0].Scale -eq 1
            $compactRepresentative=$case[0].Kind -eq 'ArtworkPlayer' -and $case[0].Width -eq 180 -and $case[0].Columns -eq 1 -and $case[0].Scale -in @(0.75,2)
            if (-not ($wideRepresentative -or $compactRepresentative)) { continue }
        } elseif ($SourceIntegrationFocused) {
            if ($case[0].Width -ne 180 -or $case[0].Scale -ne 1) { continue }
        } elseif ($case[0].Name -notin $captureCases) { continue }
        $case=$case[0]
        if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 2048 -or $window.Height -gt 2048) { throw 'Unexpected capture dimensions.' }
        $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $hdc=[IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta)
            $hdc=$graphics.GetHdc()
            $printed=[ParallaxMediaSettingsCapture]::PrintWindow($window.Handle,$hdc,2)
            $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
            $colors=[Collections.Generic.HashSet[int]]::new()
            for ($x=0;$x -lt $bitmap.Width;$x+=2) { for ($y=0;$y -lt $bitmap.Height;$y+=2) { $null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
            if (-not $printed -or $colors.Count -le 16) { throw 'Native capture is blank/unsupported.' }
            $label="$($case.Kind)-$($case.Profile)-w$($case.Width)-s$($case.Scale)-c$($case.Columns)"
            $file=Join-Path $runRoot ("synthetic-$label.png")
            $bitmap.Save($file,[Drawing.Imaging.ImageFormat]::Png)
            $captures+=[pscustomobject]@{File=$file;Synthetic=$true;Width=$window.Width;Height=$window.Height;Colors=$colors.Count}
        } finally {
            if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
            $graphics.Dispose();$bitmap.Dispose()
        }
    }
    $expectedCaptures=if ($ArtworkFocused) { 8 } elseif ($SourceIntegrationFocused) { 4 } else { 7 }
    if ($captures.Count -ne $expectedCaptures) { throw "Expected $expectedCaptures representative default/max typography captures." }
    if (@($captures.File | Sort-Object -Unique).Count -ne $expectedCaptures) { throw 'Capture files must be distinct.' }
    return $captures
}
try {
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(50)
    do { Start-Sleep -Milliseconds 250; $reports = @(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt') } while ($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) native reports; inspect $runRoot\Rainmeter.log" }
    $failed = @()
    foreach ($case in $cases) {
        $report = Get-Content -LiteralPath $case.Report -Raw
        Write-Output $report.TrimEnd()
        if ($report -notmatch '^PASS ') { $failed += $case.Name }
    }
    $captures=@(); $sync=$null
    if (-not $TypographyStatusProbeOnly) {
        $captures=@(Save-ViewCaptures ([uint32]$testProcess.Id))
        if (-not $SourceIntegrationFocused -and -not $ArtworkFocused) { $sync=Test-LabelSync; Write-Output $sync.Report }
    }
    $errors = @()
    $log = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $log) { $errors = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' }) }
    $evidence = [ordered]@{Synthetic=$true;Cases=$cases.Count;FailedCases=$failed;LogErrors=$errors;OwnedPid=$testProcess.Id;SourceHashes=$sourceHashes;Captures=$captures;LabelSync=$sync;
        RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion;
        Limits='Copied-source native Settings/accordion/player UI. Every WNP include, raw artist and source reader measure is replaced with inert Calc/String fixtures; Source scripts are excluded. Synthetic queue and temporary preferences; no helper, auth, live settings, real queue or performance test.'}
    Write-TestFile (Join-Path $runRoot 'media-settings-evidence.json') ($evidence | ConvertTo-Json -Depth 4)
    Write-Output "Evidence retained at $runRoot"
    foreach ($path in $sourceHashes.Keys) { if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $sourceHashes[$path]) { throw 'Source changed during native run; rerun for coherent evidence.' } }
    if ($failed.Count -or $errors.Count) { $errors | Write-Output; throw "$($failed.Count) native cases failed; $($errors.Count) Rainmeter error entries." }
    if ($TypographyStatusProbeOnly) { Write-Output 'PASS: compact footer substitutions and native max-font player glyph checks.' }
    elseif ($ArtworkFocused) { Write-Output "PASS: $($cases.Count) focused artwork layouts, populated/missing cover states, collapsed/expanded queue and $($captures.Count) synthetic owned-window captures." }
    elseif ($SourceIntegrationFocused) { Write-Output "PASS: $($cases.Count) focused source UI layouts and $($captures.Count) synthetic owned-window captures." }
    else { Write-Output "PASS: $($cases.Count) native Media settings/accordion/player layouts, open-label sync and $($captures.Count) synthetic owned-window captures." }
} finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null=$testProcess.WaitForExit(5000) }
        $testProcess.Dispose()
    }
    # Retain evidence; never kill by process name or dispatch CLI bangs to Rainmeter.
}
