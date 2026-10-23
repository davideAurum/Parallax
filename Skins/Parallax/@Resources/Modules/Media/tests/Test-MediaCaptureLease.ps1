#requires -Version 5.1
# Developer-only native checks for the spectrum drawer's capture variants and
# lease (docs/PERFORMANCE-REVIEW.md phase C1). Every run is a separate isolated
# Rainmeter instance with its own absolute Rainmeter.ini and SkinPath under a
# short C:\pxc\<id> root, against a production copy of this checkout's skin.
# WebNowPlaying, the Source reader and the provider launch hosts are replaced
# by built-in fixtures with the production dividers, so nothing reaches a
# player, a helper or the network. It never sends a command-line bang, never
# touches %APPDATA%\Rainmeter or the live skin, and stops only the processes it
# started. Run under Windows PowerShell 5.1 (pwsh reports window rects
# DPI-virtualised).
#
# Stage A (variants): the open drawer with the capture state staged as 0, 1
# and 2, at 220/1 and 180/0.75 with fonts 12/10/10, compact and double. Window
# size identical across variants; variant 0 pixel-identical to the baseline
# build passed with -BaselineSkinRoot (b0f1aba); no AudioLevel parent in
# variants 1 and 2; an active render session for the Rainmeter process in
# variant 0 and none in variant 1 (IAudioSessionManager2); clean logs.
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet('A')][string[]]$Stage = @('A'),
    # A Skins\Parallax tree of the build before the variant split (b0f1aba),
    # for the pixel-identity check of the live variant. Optional.
    [string]$BaselineSkinRoot = '',
    [ValidateRange(2, 30)][int]$SettleSeconds = 5,
    # Stage A layouts to run (default all): w220-s1-c2, w220-s1-c1,
    # w180-s0.75-c2, w180-s0.75-c1, w180-s0.75-c1-h126.
    [string[]]$OnlyLayout = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$skinSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$toolsRoot = [IO.Path]::GetFullPath((Join-Path $skinSource '..\..\tools'))
Import-Module (Join-Path $toolsRoot 'Parallax.Build.psm1') -Force
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; this test installs nothing.' }
if ($BaselineSkinRoot -and -not (Test-Path -LiteralPath (Join-Path $BaselineSkinRoot 'Media\Media.ini') -PathType Leaf)) { throw "No Media\Media.ini under $BaselineSkinRoot." }
$encoding = [Text.UTF8Encoding]::new($false)
$invariant = [Globalization.CultureInfo]::InvariantCulture
$failures = 0
$checks = 0
function Check([bool]$Condition, [string]$Message) {
    $script:checks++
    if ($Condition) { Write-Output "ok   $Message" } else { $script:failures++; Write-Output "FAIL $Message" }
}

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxLeaseNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxLeaseNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width, Height; }
    private delegate bool Callback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static Window[] Of(uint pid) {
        var found = new List<Window>();
        EnumWindows((hwnd, data) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(hwnd, title, title.Capacity);
            RECT rect; GetWindowRect(hwnd, out rect);
            found.Add(new Window { Handle = hwnd, Title = title.ToString(), Width = rect.Right - rect.Left, Height = rect.Bottom - rect.Top });
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }

    // Core Audio, read-only: the default render endpoint's sessions and peak.
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] private class MMDeviceEnumeratorCom { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object face);
    }
    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionManager2 {
        int GetAudioSessionControl(IntPtr sessionGuid, int flags, out IntPtr control);
        int GetSimpleAudioVolume(IntPtr sessionGuid, int flags, out IntPtr volume);
        int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
    }
    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionEnumerator {
        int GetCount(out int count);
        int GetSession(int index, out IAudioSessionControl2 session);
    }
    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionControl2 {
        int GetState(out int state);
        int GetDisplayName(out IntPtr name);
        int SetDisplayName(IntPtr name, IntPtr context);
        int GetIconPath(out IntPtr path);
        int SetIconPath(IntPtr path, IntPtr context);
        int GetGroupingParam(out Guid param);
        int SetGroupingParam(IntPtr param, IntPtr context);
        int RegisterAudioSessionNotification(IntPtr client);
        int UnregisterAudioSessionNotification(IntPtr client);
        int GetSessionIdentifier(out IntPtr id);
        int GetSessionInstanceIdentifier(out IntPtr id);
        int GetProcessId(out uint pid);
    }
    [ComImport, Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioMeterInformation { int GetPeakValue(out float peak); }

    private static IMMDevice DefaultRender() {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDevice device;
        Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out device));
        return device;
    }
    // Session states (0 inactive, 1 active, 2 expired) of one process on the
    // default render endpoint.
    public static int[] SessionStates(uint pid) {
        var states = new List<int>();
        var iid = typeof(IAudioSessionManager2).GUID;
        object face;
        Marshal.ThrowExceptionForHR(DefaultRender().Activate(ref iid, 23, IntPtr.Zero, out face));
        IAudioSessionEnumerator sessions;
        Marshal.ThrowExceptionForHR(((IAudioSessionManager2)face).GetSessionEnumerator(out sessions));
        int count; sessions.GetCount(out count);
        for (int i = 0; i < count; i++) {
            IAudioSessionControl2 session; sessions.GetSession(i, out session);
            uint owner; session.GetProcessId(out owner);
            if (owner == pid) { int state; session.GetState(out state); states.Add(state); }
        }
        return states.ToArray();
    }
    public static float Peak() {
        var iid = typeof(IAudioMeterInformation).GUID;
        object face;
        Marshal.ThrowExceptionForHR(DefaultRender().Activate(ref iid, 23, IntPtr.Zero, out face));
        float peak; ((IAudioMeterInformation)face).GetPeakValue(out peak);
        return peak;
    }
}
'@
}

$probeLua = @'
-- Capture-variant probe (test only): reports what this Media load holds.
local done = false
function Initialize() end
function Update()
    if done then return 0 end
    done = true
    local path = SELF:GetOption('ReportPath', '')
    local bounds = SKIN:GetMeter('MeterBounds')
    local lines = {
        'Config=' .. SKIN:GetVariable('CURRENTCONFIG'),
        'Capture=' .. tostring(SKIN:GetVariable('MediaDrawerCapture')),
        'Tick=' .. tostring(SKIN:ParseFormula(SKIN:ReplaceVariables('(#MediaTickInterval#)'))),
        'AudioLevel=' .. tostring(SKIN:GetMeasure('MeasureVisualizerAudio') ~= nil),
        'Win7Audio=' .. tostring(SKIN:GetMeasure('MeasureVisualizerVolume') ~= nil),
        'Paths=' .. tostring(SKIN:GetMeasure('MeasureVisualizerSpectrumPaths') ~= nil),
        'Lease=' .. tostring(SKIN:GetMeasure('MeasureMediaCaptureLease') ~= nil),
        'Overlay=' .. tostring(SKIN:GetMeter('MeterVisualizerUnavailable') and SKIN:GetMeter('MeterVisualizerUnavailable'):GetOption('Text')),
        'Window=' .. SKIN:GetVariable('WindowWidth') .. 'x' .. SKIN:GetVariable('WindowHeight'),
    }
    local file = assert(io.open(path, 'wb'))
    file:write(table.concat(lines, '\n') .. '\n')
    file:close()
    return 1
end
'@

function New-Root {
    $root = 'C:\pxc\' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    if (Test-Path -LiteralPath $root) { throw 'Run root must be fresh.' }
    foreach ($directory in @($root, "$root\Skins", "$root\Layouts", "$root\Plugins", "$root\Addons")) { $null = New-Item -ItemType Directory -Path $directory }
    return $root
}
function Put([string]$Root, [string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes the run root.' }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}
function Set-Key([string]$Path, [string]$Key, [string]$Value) {
    $text = [IO.File]::ReadAllText($Path)
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=[^\r\n]*'
    if ([regex]::Matches($text, $pattern).Count -eq 1) { $text = [regex]::Replace($text, $pattern, ($Key + '=' + $Value).Replace('$', '$$')) }
    elseif ([regex]::Matches($text, $pattern).Count -eq 0) { $text = $text.TrimEnd() + "`r`n$Key=$Value`r`n" }
    else { throw "More than one $Key in $Path." }
    [IO.File]::WriteAllText($Path, $text, $encoding)
}

# A production copy of a Skins\Parallax tree, with providers replaced by
# fixtures (Test-MediaTransport.ps1's approach) and the given layout.
function Copy-Skin([string]$Root, [string]$Source, [string]$Name, $Layout) {
    $target = Join-Path $Root "Skins\$Name"
    foreach ($file in Get-ParallaxFiles $Source -ProductionOnly) {
        $relative = Get-ParallaxRelativePath $file.FullName $Source
        $destination = Join-Path $target $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $media = Join-Path $target '@Resources\Modules\Media'
    $providerPath = Join-Path $media 'WebNowPlaying.inc'
    $provider = [IO.File]::ReadAllText($providerPath)
    $numeric = @{ MeasureConnection = '1'; MeasureState = '#FixtureState#'; MeasurePosition = '45'; MeasureDuration = '180'; MeasureProgress = '25'
        MeasureCanPrevious = '1'; MeasureCanPlayPause = '1'; MeasureCanNext = '1' }
    $strings = @{ MeasurePlayer = 'Synthetic player'; MeasureTitle = 'Synthetic title'; MeasureArtist = 'Synthetic artist'
        MeasureSourceArtist = 'Synthetic artist'; MeasureAlbum = 'Synthetic album'; MeasureCover = ''; MeasureMediaSource = 'Spotify' }
    $script:replaced = 0
    $provider = [regex]::Replace($provider, '(?ms)^\[(Measure\w+)\]\r?\n(.*?)(?=^\[|\z)', {
        param($match)
        $name = $match.Groups[1].Value
        $body = $match.Groups[2].Value
        if ($body -notmatch '(?m)^Plugin=WebNowPlaying\r?$' -and $body -notmatch '(?m)^ScriptFile=.*SourceReader\.lua\r?$') { return $match.Value }
        $keep = @([regex]::Matches($body, '(?m)^(UpdateDivider|MinValue|MaxValue)=[^\r\n]*') | ForEach-Object { $_.Value })
        $script:replaced++
        if ($numeric.ContainsKey($name)) {
            $dynamic = if ($numeric[$name].StartsWith('#')) { "DynamicVariables=1`n" } else { '' }
            return "[$name]`nMeasure=Calc`nFormula=$($numeric[$name])`n$dynamic$($keep -join "`n")`n`n"
        }
        if (-not $strings.ContainsKey($name)) { throw "Unexpected provider measure $name." }
        return "[$name]`nMeasure=String`nString=$($strings[$name])`n$($keep -join "`n")`n`n"
    })
    if ($script:replaced -ne ($numeric.Count + $strings.Count)) { throw "Replaced $($script:replaced) provider measures in $Name; expected $($numeric.Count + $strings.Count)." }
    [IO.File]::WriteAllText($providerPath, $provider, $encoding)
    [IO.File]::WriteAllText((Join-Path $media 'ProviderControlFixture.lua'), "function Update() return 1 end`nfunction Run() end`n", $encoding)
    foreach ($entryFile in Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object { $_.Extension -in @('.ini', '.inc') }) {
        $text = [IO.File]::ReadAllText($entryFile.FullName)
        $updated = $text
        foreach ($resumeHost in @('MeasureMediaSourceResume', 'MeasureMediaQueueResume')) {
            $updated = [regex]::Replace($updated, '(?ms)^\[' + $resumeHost + '\]\r?\n.*?(?=^\[|\z)', "[$resumeHost]`nMeasure=Script`nScriptFile=#@#Modules\Media\ProviderControlFixture.lua`nUpdateDivider=-1`n`n")
        }
        $reader = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        $updated = $updated.Replace($reader, $reader + "`nQueueCachePath=$Root\no-queue.snapshot")
        if ($updated -ne $text) { [IO.File]::WriteAllText($entryFile.FullName, $updated, $encoding) }
    }
    $entry = Join-Path $target 'Media\Media.ini'
    $text = [IO.File]::ReadAllText($entry)
    if ([regex]::Matches($text, '(?m)^\[Variables\]\r?$').Count -ne 1) { throw 'Expected one [Variables] section in Media.ini.' }
    $text = [regex]::Replace($text, '(?m)^\[Variables\]\r?$', "[Variables]`r`nFixtureState=2")
    [IO.File]::WriteAllText($entry, $text, $encoding)
    $settings = Join-Path $target '@Resources\User\Settings.inc'
    Set-Key $settings 'Scale' $Layout.Scale
    Set-Key $settings 'ColumnWidth' $Layout.Width
    Set-Key $settings 'TitleFontSize' '12'
    Set-Key $settings 'HeaderFontSize' '10'
    Set-Key $settings 'FontSize' '10'
    $preferences = Join-Path $target '@Resources\User\Media.inc'
    Set-Key $preferences 'Columns' $Layout.Columns
    Set-Key $preferences 'VisualizerDrawer' '2'
    Set-Key $preferences 'QueueExpanded' '0'
    Set-Key $preferences 'MediaTitleAnimation' '20'
    if ($Layout.PSObject.Properties['Preset']) { Set-Key (Join-Path $target '@Resources\User\Visualizer.inc') 'PanelHeight' $Layout.Preset }
    return $target
}

# A copy of the Media entrypoint as its own config whose capture state comes
# from a state file beside it (#CURRENTPATH#), so several variants can load
# in one instance. Only the state include's path changes.
function Add-VariantConfig([string]$Target, [string]$Folder, [int]$Capture) {
    $entry = [IO.File]::ReadAllText((Join-Path $Target 'Media\Media.ini'))
    $include = '@Include14=#@#Modules\Media\CaptureState.inc'
    if ([regex]::Matches($entry, [regex]::Escape($include)).Count -ne 1) { throw 'Media.ini has no single CaptureState include.' }
    $entry = $entry.Replace($include, '@Include14=#CURRENTPATH#CaptureState.inc')
    $null = New-Item -ItemType Directory -Path (Join-Path $Target $Folder) -Force
    [IO.File]::WriteAllText((Join-Path $Target "$Folder\Media.ini"), $entry, $encoding)
    $state = [IO.File]::ReadAllText((Join-Path $Target '@Resources\Modules\Media\CaptureState.inc'))
    $state = [regex]::Replace($state, '(?m)^MediaDrawerCapture=[^\r\n]*', "MediaDrawerCapture=$Capture")
    [IO.File]::WriteAllText((Join-Path $Target "$Folder\CaptureState.inc"), $state, $encoding)
}
function Add-Probe([string]$Root, [string]$Ini, [string]$Report) {
    $probe = Join-Path $Root 'Probe.lua'
    if (-not (Test-Path -LiteralPath $probe)) { [IO.File]::WriteAllText($probe, $probeLua, $encoding) }
    $text = [IO.File]::ReadAllText($Ini)
    $text = $text.TrimEnd() + "`r`n`r`n[MeasureCaptureProbe]`r`nMeasure=Script`r`nScriptFile=$probe`r`nUpdateDivider=1`r`nReportPath=$Report`r`n"
    [IO.File]::WriteAllText($Ini, $text, $encoding)
}
function Read-Report([string]$Path) {
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in [IO.File]::ReadAllLines($Path)) { if ($line -match '^(\w+)=(.*)$') { $values[$Matches[1]] = $Matches[2] } }
    return $values
}
function Write-Settings([string]$Root, [string[]]$Configs) {
    $ini = "[Rainmeter]`nSkinPath=$Root\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $x = -30000
    foreach ($config in $Configs) {
        $ini += "`n[$config]`nActive=1`nWindowX=$x`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
        $x += 1000
    }
    Put $Root "$Root\Rainmeter.ini" $ini
    Put $Root "$Root\Rainmeter.data" "[Rainmeter]`n"
}
function Start-Run([string]$Root) {
    Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f "$Root\Rainmeter.ini") -WorkingDirectory $Root -WindowStyle Hidden -PassThru
}
function Stop-Run($Process) {
    if ($null -eq $Process) { return }
    $Process.Refresh()
    if (-not $Process.HasExited) { Stop-Process -InputObject $Process -Force; $null = $Process.WaitForExit(5000) }
}
function Get-LogIssues([string]$Root) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return @('no Rainmeter.log') }
    @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^(ERRO|WARN)' })
}
# Every probe report written (each config has had its first update), then
# SettleSeconds for the capture state and anchors to settle. A loaded machine
# can take well over 10 s to start an isolated instance.
function Wait-Loaded($Process, [string[]]$Reports) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt 90) {
        $Process.Refresh()
        if ($Process.HasExited) { throw 'The isolated instance exited early.' }
        if (@($Reports | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -eq 0) { break }
        Start-Sleep -Milliseconds 250
    }
    Start-Sleep -Seconds $SettleSeconds
    return [math]::Round($clock.Elapsed.TotalSeconds, 1)
}
function Find-Window($Windows, [string]$Config) {
    @($Windows | Where-Object { $_.Title -eq $Config -or $_.Title -like "$Config *" -or $_.Title -like "*\$Config\Media.ini*" })
}
function Save-Capture($Window, [string]$Path) {
    $bitmap = [Drawing.Bitmap]::new($Window.Width, $Window.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxLeaseNative]::PrintWindow($Window.Handle, $hdc, 2)
        $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
        if (-not $printed) { throw 'PrintWindow failed.' }
    } finally {
        if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
        $graphics.Dispose()
    }
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    return $bitmap
}
# Differing pixel count and their bounding box.
function Compare-Bitmaps($First, $Second) {
    if ($First.Width -ne $Second.Width -or $First.Height -ne $Second.Height) { return [pscustomobject]@{ Count = -1; Box = 'size differs' } }
    $rect = [Drawing.Rectangle]::new(0, 0, $First.Width, $First.Height)
    $a = $First.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $b = $Second.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = $a.Stride * $First.Height
        $left = [byte[]]::new($bytes); $right = [byte[]]::new($bytes)
        [Runtime.InteropServices.Marshal]::Copy($a.Scan0, $left, 0, $bytes)
        [Runtime.InteropServices.Marshal]::Copy($b.Scan0, $right, 0, $bytes)
    } finally { $First.UnlockBits($a); $Second.UnlockBits($b) }
    $count = 0; $minX = [int]::MaxValue; $minY = [int]::MaxValue; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $First.Height; $y++) {
        $row = $y * $a.Stride
        for ($x = 0; $x -lt $First.Width; $x++) {
            $i = $row + 4 * $x
            if ($left[$i] -ne $right[$i] -or $left[$i + 1] -ne $right[$i + 1] -or $left[$i + 2] -ne $right[$i + 2] -or $left[$i + 3] -ne $right[$i + 3]) {
                $count++
                if ($x -lt $minX) { $minX = $x }; if ($y -lt $minY) { $minY = $y }; if ($x -gt $maxX) { $maxX = $x }; if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    $box = if ($count) { "x $minX-$maxX, y $minY-$maxY" } else { '' }
    return [pscustomobject]@{ Count = $count; Box = $box }
}

if ('A' -in $Stage) {
    Write-Output '--- Stage A: capture variants'
    $layouts = @(
        [pscustomobject]@{ Name = 'w220-s1-c2'; Width = '220'; Scale = '1'; Columns = '2' },
        [pscustomobject]@{ Name = 'w220-s1-c1'; Width = '220'; Scale = '1'; Columns = '1' },
        [pscustomobject]@{ Name = 'w180-s0.75-c2'; Width = '180'; Scale = '0.75'; Columns = '2' },
        [pscustomobject]@{ Name = 'w180-s0.75-c1'; Width = '180'; Scale = '0.75'; Columns = '1' },
        # The shortest plot (Audio settings height 126) at the narrowest layout.
        [pscustomobject]@{ Name = 'w180-s0.75-c1-h126'; Width = '180'; Scale = '0.75'; Columns = '1'; Preset = '126' }
    )
    if ($OnlyLayout) { $layouts = @($layouts | Where-Object { $_.Name -in $OnlyLayout }) }
    foreach ($layout in $layouts) {
        $root = New-Root
        $target = Copy-Skin $root $skinSource 'Parallax' $layout
        Add-VariantConfig $target 'MediaP' 1
        Add-VariantConfig $target 'MediaD' 2
        $configs = [ordered]@{ 'Parallax\Media' = 0; 'Parallax\MediaP' = 1; 'Parallax\MediaD' = 2 }
        if ($BaselineSkinRoot) {
            $null = Copy-Skin $root ([IO.Path]::GetFullPath($BaselineSkinRoot)) 'Base' $layout
            $configs['Base\Media'] = 'baseline'
        }
        foreach ($config in $configs.Keys) {
            $folder = Join-Path "$root\Skins" $config
            Add-Probe $root (Join-Path $folder 'Media.ini') ("$root\report-" + $config.Replace('\', '-') + '.txt')
        }
        Write-Settings $root @($configs.Keys)
        $process = $null
        $bitmaps = @{}
        try {
            $process = Start-Run $root
            $loaded = Wait-Loaded $process @($configs.Keys | ForEach-Object { "$root\report-" + $_.Replace('\', '-') + '.txt' })
            $peak = [ParallaxLeaseNative]::Peak()
            $windows = @([ParallaxLeaseNative]::Of([uint32]$process.Id))
            $sizes = @{}
            foreach ($config in $configs.Keys) {
                $match = @(Find-Window $windows $config)
                if ($match.Count -ne 1) { Check $false "$($layout.Name) ${config}: one window (titles: $(($windows | ForEach-Object Title) -join ' | '))"; continue }
                if ($match[0].Width -lt 1 -or $match[0].Height -lt 1 -or $match[0].Width -gt 4096 -or $match[0].Height -gt 4096) {
                    Check $false "$($layout.Name) ${config}: usable window size ($($match[0].Width)x$($match[0].Height))"; continue
                }
                $png = "$root\$($layout.Name)-$($config.Replace('\', '-')).png"
                $bitmaps[$config] = Save-Capture $match[0] $png
                $sizes[$config] = "$($match[0].Width)x$($match[0].Height)"
            }
            Write-Output ("     {0}: loaded and settled in {3} s; windows {1}; output peak {2:N4}" -f $layout.Name, (($sizes.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Value)" }) -join ', '), $peak, $loaded)
            Check (@($sizes.Values | Select-Object -Unique).Count -eq 1) "$($layout.Name): every variant has the same window size"
            foreach ($config in @($configs.Keys | Where-Object { $configs[$_] -ne 'baseline' })) {
                $report = Read-Report ("$root\report-" + $config.Replace('\', '-') + '.txt')
                $capture = $configs[$config]
                Check ($report['Capture'] -eq [string]$capture) "$($layout.Name) ${config}: loads capture variant $capture"
                $live = $capture -eq 0
                Check ($report['AudioLevel'] -eq ([string]$live).ToLowerInvariant() -and $report['Win7Audio'] -eq ([string]$live).ToLowerInvariant() -and $report['Paths'] -eq ([string]$live).ToLowerInvariant()) "$($layout.Name) ${config}: AudioLevel, Win7Audio and the spectrum script exist only when live (AudioLevel=$($report['AudioLevel']))"
                if (-not $live) { Check ($report['Lease'] -eq 'true') "$($layout.Name) ${config}: the lease measure is present" }
                Write-Output "     $config tick $($report['Tick']) ms, overlay '$($report['Overlay'])'"
            }
            if ($BaselineSkinRoot -and $bitmaps.ContainsKey('Base\Media') -and $bitmaps.ContainsKey('Parallax\Media')) {
                $difference = Compare-Bitmaps $bitmaps['Base\Media'] $bitmaps['Parallax\Media']
                Check ($difference.Count -eq 0) "$($layout.Name): live variant is pixel-identical to the baseline build ($($difference.Count) pixels differ $($difference.Box))"
            }
            $issues = @(Get-LogIssues $root)
            $issues | Select-Object -First 5 | ForEach-Object { Write-Output "     log: $_" }
            Check ($issues.Count -eq 0) "$($layout.Name): Rainmeter logged no error or warning"
        } finally {
            Stop-Run $process
            foreach ($bitmap in $bitmaps.Values) { $bitmap.Dispose() }
        }
        Write-Output "     evidence: $root"
    }

    # Render sessions are per process, so each variant gets its own instance.
    foreach ($capture in 0, 1) {
        $root = New-Root
        $target = Copy-Skin $root $skinSource 'Parallax' $layouts[0]
        $statePath = Join-Path $target '@Resources\Modules\Media\CaptureState.inc'
        Set-Key $statePath 'MediaDrawerCapture' ([string]$capture)
        Add-Probe $root (Join-Path $target 'Media\Media.ini') "$root\report.txt"
        Write-Settings $root @('Parallax\Media')
        $process = $null
        try {
            $process = Start-Run $root
            $null = Wait-Loaded $process @("$root\report.txt")
            $states = @([ParallaxLeaseNative]::SessionStates([uint32]$process.Id))
            $report = Read-Report "$root\report.txt"
            Write-Output ("     variant {0} alone: capture={1}, render sessions of PID {2}: [{3}] (0 inactive, 1 active, 2 expired)" -f $capture, $report['Capture'], $process.Id, ($states -join ','))
            if ($capture -eq 0) { Check (@($states | Where-Object { $_ -eq 1 }).Count -ge 1) 'Variant 0: the Rainmeter process holds an active render session (AudioLevel''s silent stream)' }
            else { Check (@($states | Where-Object { $_ -eq 1 }).Count -eq 0) 'Variant 1: the Rainmeter process holds no active render session' }
            $issues = @(Get-LogIssues $root)
            $issues | Select-Object -First 5 | ForEach-Object { Write-Output "     log: $_" }
            Check ($issues.Count -eq 0) "Variant $capture alone: Rainmeter logged no error or warning"
        } finally { Stop-Run $process }
        Write-Output "     evidence: $root"
    }
}

Write-Output "$checks checks, $failures failures."
if ($failures) { throw 'Media capture-lease native checks failed.' }
