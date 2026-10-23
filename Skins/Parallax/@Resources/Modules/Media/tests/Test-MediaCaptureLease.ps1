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
#
# Stage B (lease): CaptureLeaseSuite.luatest inside Rainmeter's own Lua, then
# Media.ini with the real coordinator (tick 500 ms, away 5 s, heartbeat 2 s,
# test idle file) and shortened lease hooks (quiet 3 s, stale 8 s). Going away
# parks within a tick; input, the paused plot's click action and a
# WebNowPlaying fixture reporting Playing each resume it; a coordinator that
# stops beating fails live once its beat is 8 s old; unloading the coordinator
# resumes at once and the next live load re-joins it. Each transition is one
# Media refresh, the render session goes and comes back with the capture, and
# the log stays clean. Steps slowed by Windows display re-detection (which
# stalls Rainmeter's timers) are reported as late, not failed.
#
# Stage C (one capture): Media's open drawer defers to the standalone Audio
# Visualizer when it loads (one refresh, the deferred message captured at
# 180/0.75 compact with fonts 12/10/10) and takes the capture back when it
# unloads; the reversed load order and a startup with both loaded also defer;
# clean logs. Rainmeter exit (no notice) is covered offline only.
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet('A', 'B', 'C')][string[]]$Stage = @('A', 'B', 'C'),
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
$late = 0
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
    @($Windows | Where-Object { $_.Title -eq $Config -or $_.Title -like "$Config *" -or $_.Title -like "$Config\*.ini*" -or $_.Title -like "*\$Config\*.ini*" })
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

# Stage B (lease): Media.ini live drawer plus the staged coordinator (tick
# 500 ms, away 5 s, heartbeat 2 s, test idle file) and lease hooks (quiet 3 s,
# stale 8 s). A driver skin in the same isolated instance carries out each
# step this runner asks for: idle-file writes, the WebNowPlaying fixture
# state, the paused plot's own click action, pausing the coordinator's script
# (a coordinator that stops beating) and unloading the coordinator.
$driverLua = @'
-- Test driver: executes numbered commands from cmd.txt in this isolated
-- instance and records each with os.clock() in driver.log.
local seen, cmdPath, logPath, idlePath
local function log(text)
    local file = assert(io.open(logPath, 'ab'))
    file:write(string.format('%.3f|%s\n', os.clock(), text))
    file:close()
end
function Initialize()
    seen = 0
    cmdPath = SKIN:GetVariable('CommandFile')
    logPath = SKIN:GetVariable('DriverLog')
    idlePath = SKIN:GetVariable('IdleFile')
end
function Update()
    local file = io.open(cmdPath, 'rb')
    if not file then return 0 end
    local text = file:read('*a') or ''
    file:close()
    local seq, command, argument = text:match('^(%d+) (%S+) ?(%S*)')
    seq = tonumber(seq)
    if not seq or seq <= seen then return 0 end
    seen = seq
    if command == 'idle' then
        local idle = assert(io.open(idlePath, 'wb')); idle:write(argument); idle:close()
    elseif command == 'wnp' then
        SKIN:Bang('!SetVariable', 'FixtureState', argument, 'Parallax\\Media')
    elseif command == 'click' then
        SKIN:Bang('!CommandMeasure', 'MeasureMediaCaptureLease', "Unpark('click')", 'Parallax\\Media')
    elseif command == 'hang' then
        -- A coordinator that neither beats nor answers a sync request.
        SKIN:Bang('!PauseMeasure', 'MeasureParallaxIdle', 'Parallax\\Idle')
        SKIN:Bang('!PauseMeasure', 'MeasureParallaxIdleSyncRequest', 'Parallax\\Idle')
    elseif command == 'unhang' then
        SKIN:Bang('!UnpauseMeasure', 'MeasureParallaxIdleSyncRequest', 'Parallax\\Idle')
        SKIN:Bang('!UnpauseMeasure', 'MeasureParallaxIdle', 'Parallax\\Idle')
    elseif command == 'unload' then
        SKIN:Bang('!DeactivateConfig', 'Parallax\\Idle')
    elseif command == 'loadvis' then
        SKIN:Bang('!ActivateConfig', 'Parallax\\Visualizer', 'Visualizer.ini')
    elseif command == 'unloadvis' then
        SKIN:Bang('!DeactivateConfig', 'Parallax\\Visualizer')
    elseif command == 'loadmedia' then
        SKIN:Bang('!ActivateConfig', 'Parallax\\Media', 'Media.ini')
    elseif command == 'quit' then
        log(seq .. '|quit')
        SKIN:Bang('!Quit')
        return 0
    end
    log(seq .. '|' .. command .. '|' .. argument)
    return seq
end
'@

function Get-CaptureState([string]$Path) {
    # Share read and write: a plain ReadAllText denies writers while open, and
    # Rainmeter's !WriteKeyValue then fails (seen in an earlier run).
    try {
        $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        try { $text = [IO.StreamReader]::new($stream).ReadToEnd() } finally { $stream.Dispose() }
    } catch { return $null }
    $match = [regex]::Match($text, '(?m)^MediaDrawerCapture=(\d)')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}
function Get-MediaRefreshes([string]$Root) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return 0 }
    try { @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'Parallax\\Media\\Media\.ini: Refreshing skin' }).Count } catch { 0 }
}
# Windows display re-detection (monitors switching inputs or links) makes
# Rainmeter re-lay out every window and can stall its timers for seconds;
# Rainmeter logs each event. Reported beside a step so a latency miss can be
# told apart from a lease fault.
function Get-DisplayEvents([string]$Root) {
    $log = "$Root\Rainmeter.log"
    if (-not (Test-Path -LiteralPath $log)) { return 0 }
    try { @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'System: (Display settings|Work area) changed' }).Count } catch { 0 }
}

if ('B' -in $Stage) {
    Write-Output '--- Stage B: CaptureLeaseSuite inside Rainmeter'
    $root = New-Root
    $suiteRoot = Join-Path $root 'Skins\LeaseSuite'
    $null = New-Item -ItemType Directory -Path $suiteRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CaptureLeaseSuite.luatest') -Destination "$root\CaptureLeaseSuite.lua"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\CaptureLease.lua') -Destination "$root\CaptureLease.lua"
    Copy-Item -LiteralPath (Join-Path $skinSource '@Resources\Idle\Link.lua') -Destination "$root\Link.lua"
    Put $root "$root\Harness.lua" @"
function Initialize() end
function Update() return 0 end
function Run()
    local ok, report = pcall(function()
        return dofile([=[$root\CaptureLeaseSuite.lua]=]).Run([=[$root\CaptureLease.lua]=], [=[$root\Link.lua]=])
    end)
    local file = assert(io.open([=[$root\suite.txt]=], 'wb'))
    file:write(ok and report or ('FAIL: ' .. tostring(report)))
    file:close()
    SKIN:Bang('!Quit')
end
"@
    Put $root "$suiteRoot\Suite.ini" "[Rainmeter]`r`nUpdate=-1`r`nOnRefreshAction=[!CommandMeasure MeasureHarness ""Run()""]`r`n`r`n[MeasureHarness]`r`nMeasure=Script`r`nScriptFile=$root\Harness.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`n"
    Put $root "$root\Rainmeter.ini" "[Rainmeter]`nSkinPath=$root\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n`n[LeaseSuite]`nActive=1`nWindowX=-20000`nWindowY=-20000`n"
    Put $root "$root\Rainmeter.data" "[Rainmeter]`n"
    $process = $null
    try {
        $process = Start-Run $root
        Check ($process.WaitForExit(60000)) 'The suite run finished'
        $report = if (Test-Path -LiteralPath "$root\suite.txt") { [IO.File]::ReadAllText("$root\suite.txt") } else { 'FAIL: no report' }
        Write-Output ("     " + ($report -split "`n")[0])
        Check ($report -match '^PASS:') 'CaptureLeaseSuite passes in Rainmeter''s Lua'
        $issues = @(Get-LogIssues $root)
        Check ($issues.Count -eq 0) 'Suite run logged no error or warning'
    } finally { Stop-Run $process }

    Write-Output '--- Stage B: park and resume'
    $root = New-Root
    $layout = [pscustomobject]@{ Name = 'w220-s1-c2'; Width = '220'; Scale = '1'; Columns = '2' }
    $target = Copy-Skin $root $skinSource 'Parallax' $layout
    $idleIni = Join-Path $target 'Idle\Idle.ini'
    Set-Key $idleIni 'ParallaxIdleTick' '500'
    Set-Key $idleIni 'ParallaxIdleTestAwaySeconds' '5'
    Set-Key $idleIni 'ParallaxIdleTestHeartbeatTicks' '4'
    Set-Key $idleIni 'ParallaxIdleTestFile' "$root\idle.txt"
    $entry = Join-Path $target 'Media\Media.ini'
    $text = [IO.File]::ReadAllText($entry)
    $text = [regex]::Replace($text, '(?m)^\[Variables\]\r?$', "[Variables]`r`nMediaLeaseTestQuietSeconds=3`r`nMediaLeaseTestStaleSeconds=8")
    [IO.File]::WriteAllText($entry, $text, $encoding)
    Add-Probe $root $entry "$root\report.txt"
    Put $root "$root\idle.txt" '0'
    Put $root "$root\Driver.lua" $driverLua
    Put $root "$target\ADriver\Driver.ini" "[Rainmeter]`r`nUpdate=100`r`n`r`n[Variables]`r`nCommandFile=$root\cmd.txt`r`nDriverLog=$root\driver.log`r`nIdleFile=$root\idle.txt`r`n`r`n[MeasureDriver]`r`nMeasure=Script`r`nScriptFile=$root\Driver.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`nUpdateDivider=-1`r`n"
    Write-Settings $root @('Parallax\Media', 'Parallax\ADriver')
    $statePath = Join-Path $target '@Resources\Modules\Media\CaptureState.inc'
    $script:sequence = 0
    function Send([string]$Command) {
        $script:sequence++
        [IO.File]::WriteAllText("$root\cmd.txt", "$($script:sequence) $Command", $encoding)
        return [Diagnostics.Stopwatch]::StartNew()
    }
    function Wait-State([string]$Want, [int]$Milliseconds) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while ($clock.ElapsedMilliseconds -lt $Milliseconds) {
            if ((Get-CaptureState $statePath) -eq $Want) { return $clock.ElapsedMilliseconds }
            Start-Sleep -Milliseconds 50
        }
        return -1
    }
    function Wait-Refreshes([int]$Count, [int]$Milliseconds) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while ($clock.ElapsedMilliseconds -lt $Milliseconds) {
            if ((Get-MediaRefreshes $root) -ge $Count) { return $true }
            Start-Sleep -Milliseconds 100
        }
        return $false
    }
    function Get-Sessions { @([ParallaxLeaseNative]::SessionStates([uint32]$process.Id)) }
    # One transition: the command, the state it must reach, the latency bound,
    # exactly one Media refresh, and the capture's render session after it.
    function Step([string]$Label, [string]$Command, [string]$Want, [int]$BoundMs) {
        $before = Get-MediaRefreshes $root
        $displayBefore = Get-DisplayEvents $root
        $clock = if ($Command) { Send $Command } else { [Diagnostics.Stopwatch]::StartNew() }
        # Generous: Windows display re-detection can stall Rainmeter's timers for
        # many seconds, and each stall also re-arms the lease's staleness clock.
        $elapsed = Wait-State $Want ([math]::Max($BoundMs * 6, 60000))
        $total = $clock.ElapsedMilliseconds
        $refreshed = Wait-Refreshes ($before + 1) 20000
        Start-Sleep -Milliseconds 2500
        $after = Get-MediaRefreshes $root
        $sessions = Get-Sessions
        $active = @($sessions | Where-Object { $_ -eq 1 }).Count
        $display = (Get-DisplayEvents $root) - $displayBefore
        $note = if ($display) { "; $display Windows display re-detection events during this step" } else { '' }
        Write-Output ("     {0}: state {1} after {2} ms; Media refreshes {3} -> {4}; active render sessions {5}{6}" -f $Label, $Want, $total, $before, $after, $active, $note)
        if ($elapsed -ge 0 -and $total -gt $BoundMs -and $display -gt 0) {
            # Reached, but while Windows display re-detection stalled Rainmeter.
            $script:late++
            Write-Output "LATE ${Label}: capture state $Want after $total ms (bound $BoundMs ms) during $display display re-detection events"
        } else {
            Check ($elapsed -ge 0 -and $total -le $BoundMs) "${Label}: capture state $Want within $BoundMs ms"
        }
        Check ($refreshed -and $after -eq $before + 1) "${Label}: exactly one Media refresh"
        if ($Want -eq '1') { Check ($active -eq 0) "${Label}: no active render session while paused" }
        else { Check ($active -ge 1) "${Label}: the live capture's render session is back" }
    }
    $process = $null
    try {
        $process = Start-Run $root
        $null = Wait-Loaded $process @("$root\report.txt")
        Check ((Get-CaptureState $statePath) -eq '0') 'Starts live'
        Check ((@(Get-Sessions | Where-Object { $_ -eq 1 })).Count -ge 1) 'Live capture holds a render session'
        $windows = @([ParallaxLeaseNative]::Of([uint32]$process.Id))
        Check (@(Find-Window $windows 'Parallax\Idle').Count -eq 1) "The lease joined: the coordinator is loaded (windows: $(($windows | ForEach-Object Title) -join ' | '))"
        # Quiet (3 s) has long passed since the load, so going away parks at
        # the coordinator's next tick.
        Step 'away (idle 10)' 'idle 10' '1' 1500
        $window = @(Find-Window ([ParallaxLeaseNative]::Of([uint32]$process.Id)) 'Parallax\Media')
        if ($window.Count -eq 1) {
            $bitmap = Save-Capture $window[0] "$root\B-parked.png"; $bitmap.Dispose()
            Write-Output "     capture: $root\B-parked.png"
        }
        Step 'input (idle 0)' 'idle 0' '0' 2000
        Step 'away again' 'idle 10' '1' 6000
        Step 'click on the paused plot' 'click' '0' 1500
        # Still away: the live drawer parks again after its quiet time.
        Step 'parks again while away' '' '1' 8000
        Step 'WebNowPlaying reports Playing' 'wnp 1' '0' 3000
        $null = Send 'wnp 2'
        Step 'parks again after playback stops' '' '1' 9000
        # A coordinator that stops beating: fail live once the beat is 8 s old.
        Step 'coordinator stops beating' 'hang' '0' 11000
        $null = Send 'idle 0'
        Start-Sleep -Milliseconds 300
        $null = Send 'unhang'
        Start-Sleep -Seconds 3
        Check ((Get-CaptureState $statePath) -eq '0') 'Stays live after the coordinator recovers with input'
        $null = Send 'idle 10'
        Step 'parks with the coordinator back' '' '1' 9000
        # Unloading the coordinator: its OnCloseAction broadcasts away=0.
        Step 'coordinator unloaded' 'unload' '0' 2500
        Start-Sleep -Seconds 3
        $windows = @([ParallaxLeaseNative]::Of([uint32]$process.Id))
        Check (@(Find-Window $windows 'Parallax\Idle').Count -eq 1) "The live drawer re-joined: the coordinator is loaded again (windows: $(($windows | ForEach-Object Title) -join ' | '))"
        $null = Send 'quit'
        $null = $process.WaitForExit(10000)
        $issues = @(Get-LogIssues $root)
        $issues | Select-Object -First 8 | ForEach-Object { Write-Output "     log: $_" }
        Check ($issues.Count -eq 0) 'Rainmeter logged no error or warning'
    } finally { Stop-Run $process }
    Write-Output "     evidence: $root"
}

# Stage C (one capture): Media's open drawer and the standalone Audio
# Visualizer in one isolated instance, at 180/0.75 with fonts 12/10/10. The
# driver skin loads and unloads the standalone or Media; each case checks the
# drawer's capture state, the number of Media loads and the log.
if ('C' -in $Stage) {
    Write-Output '--- Stage C: defer to the standalone Audio Visualizer'
    $narrow = [pscustomobject]@{ Name = 'w180-s0.75-c1'; Width = '180'; Scale = '0.75'; Columns = '1' }
    $cases = @(
        [pscustomobject]@{ Name = 'Media first, then the standalone'; Active = @('Parallax\Media', 'Parallax\ADriver') },
        [pscustomobject]@{ Name = 'standalone first, then Media'; Active = @('Parallax\Visualizer', 'Parallax\ADriver') },
        [pscustomobject]@{ Name = 'startup with both loaded'; Active = @('Parallax\Media', 'Parallax\Visualizer', 'Parallax\ADriver') }
    )
    foreach ($case in $cases) {
        Write-Output "  case: $($case.Name)"
        $root = New-Root
        $target = Copy-Skin $root $skinSource 'Parallax' $narrow
        Add-Probe $root (Join-Path $target 'Media\Media.ini') "$root\report.txt"
        Put $root "$root\idle.txt" '0'
        Put $root "$root\Driver.lua" $driverLua
        Put $root "$target\ADriver\Driver.ini" "[Rainmeter]`r`nUpdate=100`r`n`r`n[Variables]`r`nCommandFile=$root\cmd.txt`r`nDriverLog=$root\driver.log`r`nIdleFile=$root\idle.txt`r`n`r`n[MeasureDriver]`r`nMeasure=Script`r`nScriptFile=$root\Driver.lua`r`n`r`n[MeterBounds]`r`nMeter=Image`r`nW=1`r`nH=1`r`nSolidColor=0,0,0,1`r`nUpdateDivider=-1`r`n"
        Write-Settings $root $case.Active
        $statePath = Join-Path $target '@Resources\Modules\Media\CaptureState.inc'
        $script:sequence = 0
        function Send([string]$Command) {
            $script:sequence++
            [IO.File]::WriteAllText("$root\cmd.txt", "$($script:sequence) $Command", $encoding)
        }
        function Wait-For([scriptblock]$Condition, [int]$Milliseconds) {
            $clock = [Diagnostics.Stopwatch]::StartNew()
            while ($clock.ElapsedMilliseconds -lt $Milliseconds) { if (& $Condition) { return $clock.ElapsedMilliseconds }; Start-Sleep -Milliseconds 100 }
            return -1
        }
        $process = $null
        try {
            $process = Start-Run $root
            Start-Sleep -Seconds 2
            switch ($case.Name) {
                'Media first, then the standalone' {
                    $null = Wait-Loaded $process @("$root\report.txt")
                    Check ((Get-CaptureState $statePath) -eq '0') 'Media alone starts live'
                    $before = Get-MediaRefreshes $root
                    Send 'loadvis'
                    $elapsed = Wait-For { (Get-CaptureState $statePath) -eq '2' } 15000
                    Start-Sleep -Seconds 3
                    $after = Get-MediaRefreshes $root
                    Write-Output ("     deferred {0} ms after the standalone was asked to load; Media refreshes {1} -> {2}" -f $elapsed, $before, $after)
                    Check ($elapsed -ge 0) 'Media defers (state 2) once the standalone loads'
                    Check ($after -eq $before + 1) 'Exactly one Media refresh'
                    $report = Read-Report "$root\report.txt"
                    $window = @(Find-Window ([ParallaxLeaseNative]::Of([uint32]$process.Id)) 'Parallax\Media')
                    if ($window.Count -eq 1) {
                        $bitmap = Save-Capture $window[0] "$root\C-deferred-w180-s0.75-c1.png"; $bitmap.Dispose()
                        Write-Output "     capture: $root\C-deferred-w180-s0.75-c1.png ($($window[0].Width)x$($window[0].Height))"
                    }
                    $before = Get-MediaRefreshes $root
                    Send 'unloadvis'
                    $elapsed = Wait-For { (Get-CaptureState $statePath) -eq '0' } 15000
                    Start-Sleep -Seconds 3
                    $after = Get-MediaRefreshes $root
                    Write-Output ("     reclaimed {0} ms after the standalone was asked to unload; Media refreshes {1} -> {2}" -f $elapsed, $before, $after)
                    Check ($elapsed -ge 0) 'Media takes the capture back (state 0) once the standalone unloads'
                    Check ($after -eq $before + 1) 'Exactly one Media refresh'
                    Check (@([ParallaxLeaseNative]::SessionStates([uint32]$process.Id) | Where-Object { $_ -eq 1 }).Count -ge 1) 'The drawer''s live capture holds a render session again'
                }
                'standalone first, then Media' {
                    $null = Wait-For { @(Find-Window ([ParallaxLeaseNative]::Of([uint32]$process.Id)) 'Parallax\Visualizer').Count -eq 1 } 60000
                    Start-Sleep -Seconds 2
                    Send 'loadmedia'
                    $elapsed = Wait-For { (Get-CaptureState $statePath) -eq '2' } 30000
                    Start-Sleep -Seconds 3
                    $loads = Get-MediaRefreshes $root
                    Write-Output ("     deferred {0} ms after Media was asked to load; Media loads {1}" -f $elapsed, $loads)
                    Check ($elapsed -ge 0) 'Media opened after the standalone defers'
                    Check ($loads -eq 2) 'The load plus exactly one deferral refresh'
                }
                'startup with both loaded' {
                    $elapsed = Wait-For { (Get-CaptureState $statePath) -eq '2' } 60000
                    Start-Sleep -Seconds 3
                    $loads = Get-MediaRefreshes $root
                    Write-Output ("     deferred {0} ms into the run; Media loads {1}" -f $elapsed, $loads)
                    Check ($elapsed -ge 0) 'Starting with both loaded leaves Media deferred'
                    Check ($loads -eq 2) 'The load plus exactly one deferral refresh'
                }
            }
            Send 'quit'
            $null = $process.WaitForExit(10000)
            $issues = @(Get-LogIssues $root)
            $issues | Select-Object -First 8 | ForEach-Object { Write-Output "     log: $_" }
            Check ($issues.Count -eq 0) "$($case.Name): Rainmeter logged no error or warning"
        } finally { Stop-Run $process }
        Write-Output "     evidence: $root"
    }
}

Write-Output "$checks checks, $failures failures, $late late step(s) during Windows display re-detection."
if ($failures) { throw 'Media capture-lease native checks failed.' }
