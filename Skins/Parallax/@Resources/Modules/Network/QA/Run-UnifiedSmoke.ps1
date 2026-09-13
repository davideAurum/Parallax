#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet(180,220)][int[]]$ColumnWidths=@(180,220),
    [ValidateSet('default','maximum')][string]$Typography='maximum',
    [ValidateRange(15,60)][int]$TimeoutSeconds=60,
    [switch]$Capture,
    [switch]$KeepArtifacts
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$moduleRoot=Split-Path -Parent $PSScriptRoot
$resourcesRoot=Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource=Split-Path -Parent $resourcesRoot
$runRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('unified-run-'+[guid]::NewGuid().ToString('N'))))
$testProcess=$null
$encoding=[Text.UTF8Encoding]::new($false)
function Assert-RunPath([string]$Path) {
    $absolute=[IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes isolated unified Network run.' }
}
function Write-TestFile([string]$Path,[string]$Text) { Assert-RunPath $Path;[IO.File]::WriteAllText($Path,$Text,$encoding) }
function Set-VariableText([string]$Text,[string]$Key,[string]$Value) {
    $pattern='(?m)^'+[regex]::Escape($Key)+'=[^\r\n]*'
    if ([regex]::IsMatch($Text,$pattern)) { return [regex]::Replace($Text,$pattern,($Key+'='+$Value)) }
    return $Text+"`n$Key=$Value`n"
}
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; this test installs nothing.' }
try {
    $sourceEntry=Get-Content -LiteralPath (Join-Path $skinSource 'Network\Network.ini') -Raw
    $sourceRedirect=Get-Content -LiteralPath (Join-Path $skinSource 'Network\Connection\Connection.ini') -Raw
    if ($sourceEntry -notmatch '(?m)^Update=1000\r?$') { throw 'Combined native monitor must retain one-second update.' }
    if ($sourceRedirect -notmatch '(?m)^Update=-1\r?$' -or $sourceRedirect -match '(?m)^Measure=') { throw 'Legacy redirect must not collect telemetry or poll.' }
    $nativeDefinitions=(Get-Content -LiteralPath (Join-Path $moduleRoot 'Measures.inc') -Raw)+"`n"+(Get-Content -LiteralPath (Join-Path $moduleRoot 'ConnectionMeasures.inc') -Raw)
    if ([regex]::Matches($nativeDefinitions,'(?m)^Measure=SysInfo\r?$').Count -ne 16 -or
        [regex]::Matches($nativeDefinitions,'(?m)^Measure=Net(In|Out)\r?$').Count -ne 2 -or
        [regex]::Matches($nativeDefinitions,'(?m)^Measure=WiFiStatus\r?$').Count -ne 5 -or
        [regex]::Matches($nativeDefinitions,'(?m)^Measure=Script\r?$').Count -ne 2 -or
        [regex]::Matches($nativeDefinitions,'(?m)^Measure=').Count -ne 25) { throw 'Combined provider banks changed unexpectedly.' }
    $sourceMeters=(Get-Content -LiteralPath (Join-Path $moduleRoot 'Meters.inc') -Raw)+"`n"+(Get-Content -LiteralPath (Join-Path $moduleRoot 'ConnectionMeters.inc') -Raw)
    $meterNames=[Collections.Generic.List[string]]::new();$glyphs=[Collections.Generic.List[object]]::new()
    function Add-Glyph([string]$Target,[string]$Text,[bool]$Width=$true,[bool]$Live=$false) {
        if ($meterNames.Contains($Target)) { $glyphs.Add([pscustomobject]@{Target=$Target;Text=$Text;Width=$Width;Live=$Live}) }
    }
    foreach ($section in [regex]::Matches(($sourceEntry+"`n"+$sourceMeters),'(?ms)^\[(Meter[^\]\r\n]+)\]\r?\n(.*?)(?=^\[|\z)')) {
        $name=$section.Groups[1].Value
        if ($meterNames.Contains($name)) { throw ('Duplicate production meter: '+$name) }
        $meterNames.Add($name)
        if ($section.Groups[2].Value -match '(?m)^Meter=String\r?$') {
            Add-Glyph $name '--' ($name -notin @('MeterNetworkAdapter','MeterConnectionAdapter','MeterConnectionDescription','MeterConnectionIP','MeterConnectionGateway','MeterConnectionWiFi')) $true
        }
    }
    foreach ($caption in @('1x','2x')) { Add-Glyph 'MeterNetworkWidth' $caption }
    foreach ($caption in @('bits','bytes','units?')) { Add-Glyph 'MeterNetworkUnits' $caption }
    Add-Glyph 'MeterNetworkTitle' 'Network'
    foreach ($caption in @('Up / 1 s samples','Up / sampling...','Disconnected','Not present','Down','Status unknown','Dormant','Testing','Selected NIC not found','Select one adapter','Adapter unavailable','Lower layer down','Sample unavailable')) { Add-Glyph 'MeterNetworkStatus' $caption }
    foreach ($direction in @('In','Out')) {
        foreach ($caption in @('1023.9 Gbit/s','1023.9 GiB/s','0.0 bit/s','Check units')) { Add-Glyph ('MeterNetwork'+$direction+'Rate') $caption }
        foreach ($caption in @('Set positive graph ceiling','Ceiling 100.0 Mbit/s','Clipped: 100.0 Mbit/s')) { Add-Glyph ('MeterNetwork'+$direction+'Ceiling') $caption }
    }
    Add-Glyph 'MeterNetworkFooter' '60/60 samples / incl. LAN'
    foreach ($caption in @('Detected','Not reported','Unknown')) { Add-Glyph 'MeterConnectionInternet' $caption }
    foreach ($type in @('Ethernet','Wi-Fi','Other')) {
        foreach ($state in @('Up','Down','Disconnected','Not present','Status unknown','Dormant','Testing','Unavailable')) { Add-Glyph 'MeterConnectionStatus' ($type+' / '+$state) }
    }
    foreach ($caption in @('Lower layer down','Selected NIC not found','Select one adapter','Adapter unavailable')) { Add-Glyph 'MeterConnectionStatus' $caption }
    foreach ($caption in @('Wi-Fi unavailable','Check Wi-Fi settings','Wi-Fi off in module')) { Add-Glyph 'MeterConnectionWiFi' $caption }
    foreach ($caption in @('0%','100%','--','Pending','Unavailable')) { Add-Glyph 'MeterConnectionSignal' $caption }
    foreach ($caption in @('Radio unavailable','Radio: Pending','Radio: 802.11ax','Radio: ir-band')) { Add-Glyph 'MeterConnectionRadio' $caption }
    foreach ($field in @('IP','Gateway')) { Add-Glyph ('MeterConnection'+$field) '255.255.255.255' }
    foreach ($field in @('Rx','Tx')) { foreach ($unit in @('Mbit/s','Gbit/s','Tbit/s')) { Add-Glyph ('MeterConnection'+$field) ('1000.0 '+$unit) } }
    $cases=@()
    foreach ($width in $ColumnWidths) { foreach ($scale in @(0.75,1,1.25,1.5,2)) { foreach ($columns in @(1,2)) {
        $cases += [pscustomobject]@{Width=$width;Scale=$scale;Columns=$columns;Thickness=6;Kind='layout';Selector='Best';WiFiEnabled='1';WiFiIndex='0'}
    } } }
    foreach ($edge in @(@(1,0.75),@(1,2),@(2.5,0.75),@(2.5,1),@(12,0.75),@(12,2))) {
        $cases += [pscustomobject]@{Width=180;Scale=$edge[1];Columns=1;Thickness=$edge[0];Kind='bar-edge';Selector='Best';WiFiEnabled='1';WiFiIndex='0'}
    }
    $cases += [pscustomobject]@{Width=180;Scale=0.75;Columns=1;Thickness=12;Kind='invalid-nic';Selector='Parallax intentionally missing NIC';WiFiEnabled='1';WiFiIndex='0'}
    $cases += [pscustomobject]@{Width=180;Scale=0.75;Columns=1;Thickness=1;Kind='wifi-off';Selector='Best';WiFiEnabled='0';WiFiIndex='0'}
    $cases += [pscustomobject]@{Width=180;Scale=0.75;Columns=1;Thickness=2.5;Kind='invalid-wifi';Selector='Best';WiFiEnabled='1';WiFiIndex='-1'}
    $cases += [pscustomobject]@{Width=220;Scale=1;Columns=1;Thickness=6;Kind='redirect';Selector='Best';WiFiEnabled='1';WiFiIndex='0'}
    $settings="[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $entries=[Collections.Generic.List[object]]::new();$before=[Collections.Generic.List[object]]::new();$index=0
    foreach ($case in $cases) {
        $index++;$rootName=if ($case.Kind -eq 'redirect') {'Parallax'} else {'Case'+$index}
        $caseRoot=Join-Path $runRoot ('Skins\'+$rootName)
        foreach ($subdir in @('Network\Connection','@Resources\User','@Resources\Modules\Network')) {
            $dir=Join-Path $caseRoot $subdir;Assert-RunPath $dir;$null=New-Item -ItemType Directory -Path $dir -Force
        }
        foreach ($file in @('Defaults.inc','Geometry.inc','Styles.inc')) { Copy-Item -LiteralPath (Join-Path $resourcesRoot $file) -Destination (Join-Path $caseRoot ('@Resources\'+$file)) }
        Copy-Item -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Destination (Join-Path $caseRoot '@Resources\Fonts') -Recurse
        # The production-only allowlist excludes tests, QA captures and runtime data.
        foreach ($file in @('Core.lua','Network.lua','Measures.inc','Meters.inc','ConnectionCore.lua','Connection.lua','ConnectionMeasures.inc','ConnectionMeters.inc')) {
            Copy-Item -LiteralPath (Join-Path $moduleRoot $file) -Destination (Join-Path $caseRoot ('@Resources\Modules\Network\'+$file))
        }
        $scaleText=$case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture);$barText=$case.Thickness.ToString([Globalization.CultureInfo]::InvariantCulture)
        $global=Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Settings.inc') -Raw
        $fixture=@{ColumnWidth=[string]$case.Width;Scale=$scaleText;BorderThickness='4';DividerThickness='4';DataBarThickness=$barText;TitleFontSize='12';HeaderFontSize='10';FontSize='10'}
        if ($Typography -eq 'default') { $fixture.TitleFontSize='10';$fixture.HeaderFontSize='8';$fixture.FontSize='9' }
        foreach ($key in $fixture.Keys) { $global=Set-VariableText $global $key $fixture[$key] }
        $globalPath=Join-Path $caseRoot '@Resources\User\Settings.inc';Write-TestFile $globalPath $global
        $module=Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Network.inc') -Raw
        $legacyColumns=if ($case.Columns -eq 1) {'2'} else {'1'}
        $values=@{Columns=[string]$case.Columns;PanelHeight='236';NetworkConnectionColumns=$legacyColumns;NetworkConnectionHeight='999';NetworkInterface=$case.Selector;NetworkWiFiEnabled=$case.WiFiEnabled;NetworkWiFiInterface=$case.WiFiIndex;NetworkUnits='bits';NetworkInCeilingMbps='100';NetworkOutCeilingMbps='25'}
        foreach ($key in $values.Keys) { $module=Set-VariableText $module $key $values[$key] }
        $modulePath=Join-Path $caseRoot '@Resources\User\Network.inc';Write-TestFile $modulePath $module
        foreach ($path in @($globalPath,$modulePath)) { $before.Add([pscustomobject]@{Path=$path;Hash=(Get-FileHash -LiteralPath $path).Hash}) }
        $entry=$sourceEntry+"`n[MeasureUnifiedSmoke]`nMeasure=Script`nScriptFile=$PSScriptRoot\UnifiedSmoke.lua`nResultFile=$runRoot\result-$index.txt`nExpectedWidth=$($case.Width)`nExpectedScale=$scaleText`nExpectedColumns=$($case.Columns)`nExpectedThickness=$barText`nCaseKind=$($case.Kind)`nTypography=$Typography`nMeterCount=$($meterNames.Count)`nGlyphCount=$($glyphs.Count)`n"
        for ($m=0;$m -lt $meterNames.Count;$m++) { $entry+='MeterName'+($m+1)+'='+$meterNames[$m]+"`n" }
        for ($g=0;$g -lt $glyphs.Count;$g++) {
            $probe=$glyphs[$g];$n=$g+1;$entry+="GlyphTarget$n=$($probe.Target)`nGlyphWidth$n=$([int]$probe.Width)`nGlyphLive$n=$([int]$probe.Live)`n"
        }
        for ($g=0;$g -lt $glyphs.Count;$g++) {
            $probe=$glyphs[$g];$n=$g+1
            $entry+="`n[MeterUnifiedGlyph$n]`nMeter=String`nX=0`nY=0`nHidden=1`nClipString=0`nPadding=0,0,0,0`nFontColor=0,0,0,0`nFontFace=#FontFace#`nFontSize=(#FontSize#*#Scale#)`nFontWeight=500`nStringStyle=Normal`nStringCase=None`nCharacterSpacing=0`nDynamicVariables=1`nAntiAlias=1`nText=$($probe.Text)`n"
        }
        $entryPath=Join-Path $caseRoot 'Network\Network.ini';Write-TestFile $entryPath $entry
        $captureThis=$Capture -and $case.Kind -eq 'layout' -and $case.Columns -eq 1 -and (($case.Width -eq 180 -and $case.Scale -eq 0.75) -or ($case.Width -eq 220 -and $case.Scale -eq 1))
        $alpha=if ($captureThis) {255} else {0};$active=if ($case.Kind -eq 'redirect') {0} else {1};$config=$rootName+'\Network'
        $settings+="`n[$config]`nActive=$active`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=$alpha`n"
        if ($case.Kind -eq 'redirect') {
            Write-TestFile (Join-Path $caseRoot 'Network\Connection\Connection.ini') $sourceRedirect
            $settings+="`n[Parallax\Network\Connection]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
        }
        $entries.Add([pscustomobject]@{Config=$config;File=$entryPath;Capture=$captureThis;Case=$case})
    }
    foreach ($subdir in @('Layouts','Plugins','Addons','Captures')) { $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $subdir) -Force }
    $iniPath=Join-Path $runRoot 'Rainmeter.ini';Write-TestFile $iniPath $settings
    Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    Write-TestFile (Join-Path $runRoot 'QA-ONLY.txt') "Isolated combined Network fixtures and own-window captures. Never distribute.`n"
    if (-not ('ParallaxUnifiedCapture' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxUnifiedCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width, Height; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    public static Window[] GetOwnWindows(uint pid) {
        var windows = new List<Window>();
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner != pid) return true;
            var cls = new StringBuilder(256); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "RainmeterMeterWindow") return true;
            var title = new StringBuilder(1024); GetWindowText(hwnd, title, title.Capacity);
            RECT rect; if (!GetWindowRect(hwnd, out rect)) return true;
            windows.Add(new Window { Handle=hwnd, Title=title.ToString(), Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}
'@
    }
    $testProcess=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250;$reports=@(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt')
        $testProcess.Refresh();if ($testProcess.HasExited) { throw 'Isolated combined Network process exited early.' }
    } while ($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) combined reports arrived, including the real legacy redirect." }
    $failed=0
    foreach ($report in $reports) { $text=Get-Content -LiteralPath $report.FullName -Raw;Write-Output $text;if ($text -notmatch '^PASS ') {$failed++} }
    foreach ($file in $before) { if ((Get-FileHash -LiteralPath $file.Path).Hash -ne $file.Hash) { throw ('Load/redirect changed saved preferences: '+$file.Path) } }
    $windows=@([ParallaxUnifiedCapture]::GetOwnWindows([uint32]$testProcess.Id))
    Write-TestFile (Join-Path $runRoot 'own-windows.json') ($windows | Select-Object Title,Width,Height | ConvertTo-Json -Depth 3)
    if ($windows.Count -ne $cases.Count) { throw 'Unexpected own window count; the compatibility Connection config must deactivate itself.' }
    foreach ($entry in $entries) { if (@($windows | Where-Object {$_.Title -eq $entry.File}).Count -ne 1) { throw ('Missing exact combined entrypoint window: '+$entry.Config) } }
    $captures=[Collections.Generic.List[object]]::new()
    if ($Capture) {
        Add-Type -AssemblyName System.Drawing
        foreach ($entry in @($entries | Where-Object Capture)) {
            $window=@($windows | Where-Object {$_.Title -eq $entry.File})[0]
            if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 4096 -or $window.Height -gt 4096) { throw 'Unexpected own combined window dimensions.' }
            $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics=[Drawing.Graphics]::FromImage($bitmap);$hdc=[IntPtr]::Zero
            try {
                $graphics.Clear([Drawing.Color]::Magenta);$hdc=$graphics.GetHdc();$printed=[ParallaxUnifiedCapture]::PrintWindow($window.Handle,$hdc,2)
                $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
                $colors=[Collections.Generic.HashSet[int]]::new()
                for ($x=0;$x -lt $bitmap.Width;$x+=3) { for ($y=0;$y -lt $bitmap.Height;$y+=3) { $null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
                if (-not $printed -or $colors.Count -lt 16) { throw 'Blank or unsupported own-window capture.' }
                $path=Join-Path $runRoot ('Captures\Network-combined-width'+$entry.Case.Width+'-scale'+$entry.Case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture)+'-'+$Typography+'.png')
                $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
                $captures.Add([pscustomobject]@{File=$path;Width=$window.Width;Height=$window.Height;PrintWindow=$printed;SampledColors=$colors.Count})
            } finally { if ($hdc -ne [IntPtr]::Zero) {$graphics.ReleaseHdc($hdc)};$graphics.Dispose();$bitmap.Dispose() }
        }
        Write-TestFile (Join-Path $runRoot 'capture-report.json') ($captures.ToArray() | ConvertTo-Json -Depth 4)
    }
    $errors=@(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object {$_ -match '^ERRO'})
    Write-TestFile (Join-Path $runRoot 'run-report.json') ([ordered]@{Cases=$cases.Count;Failed=$failed;Typography=$Typography;GlyphChecksPerCase=$glyphs.Count;LogErrors=$errors;LegacyRedirect='Actual canonical redirect activates one Network window and deactivates itself';NoPreferenceWrites=$true;Distributable=$false;CaptureMethod='Exact-entrypoint own-PID offscreen PrintWindow';Limitations='No traffic accuracy, Internet reachability, Wi-Fi calibration, mixed-DPI or long-run performance claim.'} | ConvertTo-Json -Depth 4)
    if ($errors.Count) { throw ($errors -join "`n") };if ($failed) { throw "$failed/$($cases.Count) combined native cases failed." }
    Write-Output "Combined Network smoke: $($cases.Count) cases and $($glyphs.Count) glyph probes per case passed; actual legacy redirect passed; no writes or Rainmeter errors."
} finally {
    if ($testProcess) { $testProcess.Refresh();if (-not $testProcess.HasExited) {Stop-Process -InputObject $testProcess -Force;$null=$testProcess.WaitForExit(5000)};$testProcess.Dispose() }
    if (Test-Path -LiteralPath $runRoot) {
        if ($Capture -or $KeepArtifacts) { Write-Output "Combined Network QA evidence retained at $runRoot" }
        else {
            $item=Get-Item -LiteralPath $runRoot -Force;$resolved=[IO.Path]::GetFullPath($item.FullName)
            if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+'\',[StringComparison]::OrdinalIgnoreCase) -or
                (Split-Path -Leaf $resolved) -notmatch '^unified-run-[a-f0-9]{32}$' -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Refusing cleanup outside generated combined QA directory.' }
            for ($attempt=0;$attempt -lt 10;$attempt++) {
                if (-not (Test-Path -LiteralPath $resolved)) {break}
                try {Remove-Item -LiteralPath $resolved -Recurse -Force;break} catch {if ($attempt -eq 9) {throw};Start-Sleep -Milliseconds 250}
            }
        }
    }
}
