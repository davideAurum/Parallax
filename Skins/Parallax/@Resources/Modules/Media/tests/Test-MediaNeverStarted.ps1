# Developer-only native check of Media on a machine where neither optional
# helper was ever started (docs/modules/Media.md "Never-started helpers"). The
# real Media.ini and both real snapshot readers run in an isolated Rainmeter
# against a synthetic data root that does not exist at first. Provider measures
# are built-in fixtures; no helper, network, sign-in, live runtime data or live
# Rainmeter profile is used. Run under Windows PowerShell 5.1.
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet('1','2')][string[]]$Columns = @('2','1')
)

$ErrorActionPreference = 'Stop'
$testProcess = $null
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent cannot be a junction.' }
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw "Required file missing: $RainmeterPath. Nothing is installed by this runner." }

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxMediaHintCapture' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxMediaHintCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    private delegate bool Callback(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback,IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd,IntPtr destination,uint flags);
    public static IntPtr MediaWindow(uint pid) {
        IntPtr found=IntPtr.Zero;
        EnumWindows((hwnd,data)=>{
            uint owner;GetWindowThreadProcessId(hwnd,out owner);if(owner!=pid)return true;
            var cls=new StringBuilder(256);GetClassName(hwnd,cls,cls.Capacity);
            if(cls.ToString()!="RainmeterMeterWindow")return true;
            var title=new StringBuilder(1024);GetWindowText(hwnd,title,title.Capacity);
            if(title.ToString().EndsWith("\\Media.ini",StringComparison.OrdinalIgnoreCase))found=hwnd;
            return true;
        },IntPtr.Zero);
        return found;
    }
}
'@
}

function Invoke-Layout([string]$ColumnCount) {
    # Short root: deep include paths past MAX_PATH are skipped silently by Rainmeter.
    $script:runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('PxMN-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))))
    if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $runRoot)) { throw 'Test root must be a fresh folder in the temp parent.' }
    $skinRoot = Join-Path $runRoot 'Skins'
    $parallax = Join-Path $skinRoot 'Parallax'
    foreach ($directory in @($runRoot, $parallax, "$runRoot\Layouts", "$runRoot\Plugins", "$runRoot\Addons")) { $null = New-Item -ItemType Directory -Path $directory -Force }
    function Write-TestFile([string]$Path, [string]$Content) {
        if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the test directory.' }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
        [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    }

    # Media.ini, its includes and its scripts (both readers unchanged); no tests
    # and no PowerShell providers.
    $relatives = @('Media\Media.ini') + (@('Defaults.inc','Idle\Hook0.inc','Idle\Link.lua','Dev\Hook0.inc','Version.inc','Update\Hook1.inc','Update\Feed.inc',
        'Update\Update.lua','Update\State.inc','Geometry.inc','Styles.inc','User\Settings.inc','User\Visualizer.inc',
        'Modules\Visualizer\Fallbacks.inc','Modules\Visualizer\Options.inc') | ForEach-Object { '@Resources\' + $_ })
    foreach ($folder in @('Modules\Visualizer\HeightPresets','Fonts')) {
        $relatives += @(Get-ChildItem -LiteralPath (Join-Path $resourcesRoot $folder) -File | Where-Object { $_.Extension -in @('.inc','.ttf') } | ForEach-Object { "@Resources\$folder\$($_.Name)" })
    }
    $relatives += @(Get-ChildItem -LiteralPath $moduleRoot -Recurse -File | Where-Object { $_.Extension -in @('.inc','.lua') -and $_.FullName -notmatch '\\tests\\' } |
        ForEach-Object { '@Resources\Modules\Media\' + $_.FullName.Substring($moduleRoot.Length + 1) })
    foreach ($relative in $relatives) {
        $destination = Join-Path $parallax $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath (Join-Path $skinSource $relative) -Destination $destination
    }
    Write-TestFile (Join-Path $parallax '@Resources\User\Media.inc') "[Variables]`nColumns=$ColumnCount`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=1`nQueueRowLimit=3`nQueueShowDetails=1`nQueuePollSeconds=30`nVisualizerDrawer=1`nMediaTitleAnimation=0`n"

    # WebNowPlaying reports a generic Windows session playing one track.
    $numeric = @{ MeasureConnection='1'; MeasureReportedState='1'; MeasurePosition='45'; MeasureDuration='180'; MeasureProgress='25'
        MeasureCanPrevious='1'; MeasureCanPlayPause='1'; MeasureCanNext='1'; MeasureShuffle='0'; MeasureRepeat='0'; MeasureCanShuffle='1'; MeasureCanRepeat='1' }
    $strings = @{ MeasurePlayer='Windows Media Session'; MeasureTitle='Synthetic title'; MeasureArtist='Synthetic artist'
        MeasureSourceArtist='Synthetic artist'; MeasureAlbum='Synthetic album'; MeasureCover='' }
    $providerPath = Join-Path $parallax '@Resources\Modules\Media\WebNowPlaying.inc'
    $script:replaced = 0
    $provider = [regex]::Replace([IO.File]::ReadAllText($providerPath), '(?ms)^\[(Measure\w+)\]\r?\n(.*?)(?=^\[|\z)', {
        param($match)
        $name = $match.Groups[1].Value; $body = $match.Groups[2].Value
        if ($body -notmatch '(?m)^Plugin=WebNowPlaying\r?$') { return $match.Value }
        $keep = @([regex]::Matches($body, '(?m)^(UpdateDivider|MinValue|MaxValue)=[^\r\n]*') | ForEach-Object { $_.Value }) -join "`n"
        $script:replaced++
        if ($numeric.ContainsKey($name)) { return "[$name]`nMeasure=Calc`nFormula=$($numeric[$name])`n$keep`n`n" }
        if (-not $strings.ContainsKey($name)) { throw "Unexpected provider measure $name." }
        return "[$name]`nMeasure=String`nString=$($strings[$name])`n$keep`n`n"
    })
    if ($script:replaced -ne ($numeric.Count + $strings.Count)) { throw "Replaced $($script:replaced) provider measures; expected $($numeric.Count + $strings.Count)." }
    Write-TestFile $providerPath $provider

    # Inert launch hosts, readers pointed at the synthetic root, no plugins.
    $dataRoot = Join-Path $runRoot 'Data\Parallax\Media'
    $sourceSnapshot = Join-Path $dataRoot 'Source\source.snapshot'
    $queueSnapshot = Join-Path $dataRoot 'Spotify\queue.snapshot'
    Write-TestFile (Join-Path $parallax '@Resources\Modules\Media\ProviderControlFixture.lua') "function Update() return 1 end`nfunction Run() end`n"
    Write-TestFile (Join-Path $parallax '@Resources\Modules\Media\AlbumColors1.inc') "; Fixture: album colors off (no plugin in fixtures).`n"
    foreach ($entryFile in Get-ChildItem -LiteralPath $parallax -Recurse -File | Where-Object { $_.Extension -in @('.ini', '.inc') }) {
        $text = [IO.File]::ReadAllText($entryFile.FullName); $updated = $text
        foreach ($name in @('MeasureMediaSourceResume', 'MeasureMediaQueueResume', 'MeasureQueueProviderControl')) {
            $updated = [regex]::Replace($updated, '(?ms)^\[' + $name + '\]\r?\n.*?(?=^\[|\z)', "[$name]`nMeasure=Script`nScriptFile=#@#Modules\Media\ProviderControlFixture.lua`nUpdateDivider=-1`n`n")
        }
        foreach ($reader in @(@('Queue\QueueReader.lua', "QueueCachePath=$queueSnapshot"), @('Source\SourceReader.lua', "SourceCachePath=$sourceSnapshot"))) {
            $line = 'ScriptFile=#@#Modules\Media\' + $reader[0]
            $updated = $updated.Replace($line, $line + "`n" + $reader[1])
        }
        if ($updated -ne $text) { Write-TestFile $entryFile.FullName $updated }
        if ($updated -match '(?m)^\s*Plugin\s*=') { throw "A fixture still loads a plugin: $($entryFile.FullName)" }
    }

    # Stands in for Media settings (the title) and Connections (the drawer's
    # line): a click must load exactly one of these configs.
    $openedPath = Join-Path $runRoot 'opened.txt'
    Write-TestFile (Join-Path $runRoot 'Opened.lua') "function Initialize() local f=assert(io.open([=[$openedPath]=],'ab'));f:write('x');f:close() end`nfunction Update() return 0 end`n"
    foreach ($standIn in 'Media\Settings\Settings.ini', 'Connections\Connections.ini') {
        Write-TestFile (Join-Path $parallax $standIn) "[Rainmeter]`nUpdate=-1`nOnRefreshAction=[!DeactivateConfig]`n`n[MeasureOpened]`nMeasure=Script`nScriptFile=$runRoot\Opened.lua`n`n[MeterOpened]`nMeter=String`nText=x`n"
    }

    # Reports what the skin shows once per provider cycle and performs the
    # meters' own click actions on request; it never touches Media's meters.
    $reportPath = Join-Path $runRoot 'report.txt'; $goPath = Join-Path $runRoot 'go.txt'
    Write-TestFile $goPath '0'
    Write-TestFile (Join-Path $runRoot 'Observer.lua') @'
local tick, last, done
function Initialize() tick, last, done = 0, '', 0 end
function Update()
    tick = tick + 1
    local go = assert(io.open(SELF:GetOption('GoFile'), 'rb'))
    local text = go:read('*a'); go:close()
    local number, meter = text:match('^(%d+) (%w+)$')
    if number and tonumber(number) > done then
        done = tonumber(number)
        SKIN:Bang(SKIN:GetMeter(meter):GetOption('LeftMouseUpAction'))
    end
    local off = SKIN:GetMeter('MeterQueueOff')
    -- A hidden meter reports zero size.
    local now = table.concat({ 'title=' .. SKIN:GetMeasure('MeasureMediaHeader'):GetStringValue(),
        'cursor=' .. SKIN:GetMeter('MeterHeading'):GetOption('MouseActionCursor'),
        'off=' .. (off:GetW() > 0 and 'shown' or 'hidden'), 'row=' .. (SKIN:GetMeter('MeterQueueRow1'):GetW() > 0 and 'shown' or 'hidden'),
        'clicks=' .. done, 'end' }, '\n')
    if now ~= last then
        last = now
        local file = io.open(SELF:GetOption('ReportFile'), 'wb')
        if file then file:write(now .. '\n'); file:close() else last = '' end
    end
    return tick
end
'@
    $entryPath = Join-Path $parallax 'Media\Media.ini'
    Write-TestFile $entryPath ([IO.File]::ReadAllText($entryPath) + "`n[MeasureHintObserver]`nMeasure=Script`nScriptFile=$runRoot\Observer.lua`nUpdateDivider=1`nReportFile=$reportPath`nGoFile=$goPath`n")
    Write-TestFile (Join-Path $runRoot 'Rainmeter.ini') "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[Parallax\Media]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

    function Wait-Report([string]$Stage, [hashtable]$Expected) {
        $deadline = [DateTime]::UtcNow.AddSeconds(20); $seen = ''
        while ([DateTime]::UtcNow -lt $deadline) {
            $testProcess.Refresh()
            if ($testProcess.HasExited) { throw "Isolated Rainmeter exited at '$Stage'; inspect $runRoot\Rainmeter.log" }
            try { $seen = [IO.File]::ReadAllText($reportPath) } catch [IO.IOException] { }
            if ($seen -match '(?m)^end$') {
                $miss = @($Expected.Keys | Where-Object { $seen -notmatch ('(?m)^' + $_ + '=' + [regex]::Escape($Expected[$_]) + '$') })
                if (-not $miss.Count) { return }
            }
            Start-Sleep -Milliseconds 100
        }
        throw "'$Stage' never matched. Last report:`n$seen"
    }
    function Save-Capture([string]$Name) {
        Start-Sleep -Milliseconds 400
        $window = [ParallaxMediaHintCapture]::MediaWindow([uint32]$testProcess.Id)
        $rect = New-Object ParallaxMediaHintCapture+RECT
        if ($window -eq [IntPtr]::Zero -or -not [ParallaxMediaHintCapture]::GetWindowRect($window, [ref]$rect)) { throw 'No Media window to capture.' }
        $bitmap = [Drawing.Bitmap]::new($rect.Right - $rect.Left, $rect.Bottom - $rect.Top, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(30, 60, 70))
            $hdc = $graphics.GetHdc()
            $printed = [ParallaxMediaHintCapture]::PrintWindow($window, $hdc, 2)
            $graphics.ReleaseHdc($hdc)
            if (-not $printed) { throw 'PrintWindow failed.' }
            $bitmap.Save((Join-Path $runRoot "$Name.png"), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
    function Assert-Opened([int]$Count) {
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ([IO.File]::Exists($openedPath) -and ([IO.FileInfo]$openedPath).Length -ge $Count) { break }
            Start-Sleep -Milliseconds 100
        }
        $seen = if ([IO.File]::Exists($openedPath)) { ([IO.FileInfo]$openedPath).Length } else { 0 }
        if ($seen -ne $Count) { throw "Media settings opened $seen times; expected $Count." }
    }
    function Get-Hex([string]$Text) { return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text)) -replace '-', '') }
    function Write-Queue([string]$State, [string[]]$Titles = @()) {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $ready = $State -eq 'ready'
        $lines = @('PARALLAX_QUEUE_V2', "state=$State", ('observed=' + $(if ($ready) { $now } else { 0 })), ('valid_until=' + $(if ($ready) { $now + 90 } else { 0 })), 'retry_not_before=0', "count=$($Titles.Count)")
        for ($i = 1; $i -le 5; $i++) { $lines += 'title' + $i + '=' + $(if ($i -le $Titles.Count) { Get-Hex $Titles[$i - 1] }); $lines += "detail$i=" }
        Write-TestFile $queueSnapshot (($lines -join "`n") + "`n")
    }

    try {
        if (Test-Path -LiteralPath (Join-Path $runRoot 'Data')) { throw 'The synthetic data root must not exist at first.' }
        $script:testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $runRoot 'Rainmeter.ini')) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
        $label = if ($ColumnCount -eq '1') { 'Media' } else { 'Media Player' }

        # A machine with no Media data.
        Wait-Report 'never started' @{ title="${label}: detection off"; cursor='1'; off='shown'; row='hidden' }
        Save-Capture "never-started-$ColumnCount"
        Write-TestFile $goPath '1 MeterHeading'; Assert-Opened 1
        Write-TestFile $goPath '2 MeterQueueOff'; Assert-Opened 2
        # Nothing the skin did created the data root, let alone an intent file.
        if (Test-Path -LiteralPath (Join-Path $runRoot 'Data')) { throw 'Showing a hint wrote to the data root.' }

        # Source detection started: its first observation names Spotify.
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        Write-TestFile $sourceSnapshot ("PARALLAX_SOURCE_V1`nstate=ready`nobserved=$now`nvalid_until=$($now + 6)`ncount=1`nsource1=spotify`ntitle1=$(Get-Hex 'Synthetic title')`nartist1=$(Get-Hex 'Synthetic artist')`nplaying1=1`n")
        Wait-Report 'source started' @{ title="${label}: Spotify"; cursor='0'; off='shown' }
        # An ordinary title ignores the same click.
        Write-TestFile $goPath '3 MeterHeading'; Wait-Report 'ordinary title click' @{ clicks='3' }; Start-Sleep -Milliseconds 1500; Assert-Opened 2

        # Sign in: the queue helper's first snapshot, then its rows.
        Write-Queue 'connecting'
        Wait-Report 'queue connecting' @{ off='hidden'; row='hidden' }
        Write-Queue 'ready' @('First synthetic track', 'Second synthetic track')
        Wait-Report 'queue ready' @{ off='hidden'; row='shown' }
        Save-Capture "started-$ColumnCount"

        # Stopped by choice: no nagging.
        Write-TestFile $sourceSnapshot "PARALLAX_SOURCE_V1`nstate=stopped`nobserved=0`nvalid_until=0`ncount=0`n"
        Write-Queue 'stopped'
        Wait-Report 'stopped by choice' @{ title="${label}: Unknown"; cursor='0'; off='hidden'; row='hidden' }

        $log = Join-Path $runRoot 'Rainmeter.log'
        $errors = @(if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' } })
        if ($errors.Count) { throw "Isolated Rainmeter logged errors:`n$($errors -join "`n")" }
        Write-Output "PASS columns=${ColumnCount}: never started, title and drawer clicks, started, stopped by choice; evidence $runRoot"
    } finally {
        if ($null -ne $testProcess) {
            $testProcess.Refresh()
            if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null = $testProcess.WaitForExit(5000) }
            $testProcess.Dispose(); $script:testProcess = $null
        }
        # The fresh temp evidence is kept; nothing outside it is deleted or changed.
    }
}

foreach ($count in $Columns) { Invoke-Layout $count }
