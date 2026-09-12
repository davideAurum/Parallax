# Developer-only actual Queue.ini rendering/behavior with synthetic snapshots.
# No provider/auth files are copied or executed. No live queue storage is read.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),[switch]$TypographyFocused)
$ErrorActionPreference = 'Stop'
$testProcess = $null
$moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-QueueView-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Test root escapes temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test temp parent must not be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test directory must be fresh.' }
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$skinRoot = Join-Path $runRoot 'Skins'
foreach ($directory in @($skinRoot,"$runRoot\Layouts","$runRoot\Plugins","$runRoot\Addons","$runRoot\captures")) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}
function Write-TestFile([string]$Path,[string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes test directory.' }
    [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}
$sourceMap = [ordered]@{
    'Media\Queue\Queue.ini' = (Join-Path $skinSource 'Media\Queue\Queue.ini')
    '@Resources\Defaults.inc' = (Join-Path $resourcesRoot 'Defaults.inc')
    '@Resources\Geometry.inc' = (Join-Path $resourcesRoot 'Geometry.inc')
    '@Resources\Styles.inc' = (Join-Path $resourcesRoot 'Styles.inc')
    '@Resources\User\Settings.inc' = (Join-Path $resourcesRoot 'User\Settings.inc')
    '@Resources\User\Media.inc' = (Join-Path $resourcesRoot 'User\Media.inc')
    '@Resources\Modules\Media\Queue\QueueMeters.inc' = (Join-Path $moduleRoot 'Queue\QueueMeters.inc')
    '@Resources\Modules\Media\HeaderGear.inc' = (Join-Path $moduleRoot 'HeaderGear.inc')
    '@Resources\Modules\Media\Queue\QueueReader.lua' = (Join-Path $moduleRoot 'Queue\QueueReader.lua')
}
foreach ($font in Get-ChildItem -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Filter '*.ttf') {
    $sourceMap[('@Resources\Fonts\'+$font.Name)] = $font.FullName
}
$sourceHashes = @{}
foreach ($path in $sourceMap.Values) { $sourceHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$readerBytes = [IO.File]::ReadAllBytes($sourceMap['@Resources\Modules\Media\Queue\QueueReader.lua'])
if ($readerBytes.Length -lt 2 -or $readerBytes[0] -ne 0xFF -or $readerBytes[1] -ne 0xFE) {
    throw 'Production QueueReader needs UTF-16LE BOM for Rainmeter 4.5 Unicode APIs.'
}
$harnessPath = Join-Path $runRoot 'QueueViewSuite.lua'
# Give this observer Unicode API semantics too, so GetOption compares actual
# rendered Unicode against expected UTF-8 bytes and catches ANSI mojibake.
[IO.File]::WriteAllText($harnessPath,[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'QueueViewSuite.luatest')),[Text.Encoding]::Unicode)
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$settings = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = @()
$index = 0
$profiles=if ($TypographyFocused) { @('default','max') } else { @('default') }
$widths=if ($TypographyFocused) { @(180) } else { @(180,200) }
$scales=if ($TypographyFocused) { @(1,2) } else { @(0.75,1,1.25,1.5,2) }
$columnChoices=if ($TypographyFocused) { @(1) } else { @(1,2) }
foreach ($profile in $profiles) { foreach ($width in $widths) { foreach ($scale in $scales) { foreach ($columns in $columnChoices) {
    $index++
    $name = 'Case{0:D2}' -f $index
    $caseRoot = Join-Path $skinRoot $name
    foreach ($relative in $sourceMap.Keys) {
        $destination = Join-Path $caseRoot $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    }
    $scaleText = $scale.ToString([Globalization.CultureInfo]::InvariantCulture)
    $preferencesPath = Join-Path $caseRoot '@Resources\User\Media.inc'
    $preferences = Get-Content -LiteralPath $preferencesPath -Raw
    $preferences = [regex]::Replace($preferences,'(?m)^Columns=.*$',"Columns=$columns")
    $preferences = [regex]::Replace($preferences,'(?m)^Queue(RowLimit|ShowDetails|Expanded)=.*$','')
    $preferences += "`nScale=$scaleText`nColumnWidth=$width`nQueueRowLimit=5`nQueueShowDetails=1`nQueueExpanded=0`n"
    Write-TestFile $preferencesPath $preferences
    $titleSize=if ($profile -eq 'max') { 12 } else { 10 }
    $headerSize=if ($profile -eq 'max') { 10 } else { 8 }
    $bodySize=if ($profile -eq 'max') { 10 } else { 9 }
    $thickness=if ($profile -eq 'max') { if ($scale -eq 1) { 4 } else { 0 } } else { 1 }
    Write-TestFile (Join-Path $caseRoot '@Resources\User\Settings.inc') "[Variables]`nTitleFontSize=$titleSize`nHeaderFontSize=$headerSize`nFontSize=$bodySize`nTitleTextColor=211,181,249`nHeaderTextColor=110,218,175`nTextColor=234,210,145`nAccentColor=95,188,246`nAccentColor2=246,138,174`nBorderThickness=$thickness`nDividerThickness=$thickness`nDividerColor=219,122,81`n"
    $cache = Join-Path $runRoot ("synthetic-$name.snapshot")
    $report = Join-Path $runRoot ("result-$name.txt")
    $entryPath = Join-Path $caseRoot 'Media\Queue\Queue.ini'
    $entry = Get-Content -LiteralPath $entryPath -Raw
    $scriptLine = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
    if (($entry.Split(@($scriptLine),[StringSplitOptions]::None)).Count -ne 2) { throw 'Expected exactly one QueueReader ScriptFile in production Queue.ini.' }
    $entry = $entry.Replace($scriptLine,($scriptLine+"`nQueueCachePath=$cache"))
    $entry += @"

[MeasureQueueViewTest]
Measure=Script
ScriptFile=$harnessPath
SyntheticCachePath=$cache
ResultFile=$report
ExpectedWidth=$width
ExpectedScale=$scaleText
ExpectedColumns=$columns
TypographyProfile=$profile
"@
    foreach ($probe in @(@('Heading','Spotify queue'),@('Status','Storage unavailable'),@('Row','Synthetic title / Artist'),
                         @('Connect','Sign in'),@('Start','Start'),@('Stop','Stop'))) {
        $entry += @"

[MeterQueueProbe$($probe[0])]
Meter=String
Group=QueueTestProbes
X=0
Y=0
Text=$($probe[1])
ClipString=0
Hidden=1
FontColor=0,0,0,0
Padding=0,0,0,0
AntiAlias=1
"@
    }
    Write-TestFile $entryPath $entry
    $settings += "`n[$name\Media\Queue]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $cases += [pscustomobject]@{Name=$name;Width=$width;Scale=$scale;Columns=$columns;Profile=$profile;Report=$report}
} } } }
Write-TestFile $iniPath $settings
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxQueueViewNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxQueueViewNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
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
            RECT rect;if(GetWindowRect(hwnd,out rect))result.Add(new Window {Handle=hwnd,Title=title.ToString(),Width=rect.Right-rect.Left,Height=rect.Bottom-rect.Top});
            return true;
        },IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
try {
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    $testProcess=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 250
        $reports=@(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt')
    } while($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) native reports; inspect $runRoot\Rainmeter.log" }
    $failed=@()
    foreach($case in $cases) {
        $report=Get-Content -LiteralPath $case.Report -Raw
        Write-Output $report.TrimEnd()
        if($report -notmatch '^PASS ') { $failed+=$case.Name }
    }
    $captures=@()
    $windows=@([ParallaxQueueViewNative]::OwnWindows([uint32]$testProcess.Id))
    if($windows.Count -ne $cases.Count) { throw "Expected $($cases.Count) own test windows, found $($windows.Count)." }
    foreach($window in $windows) {
        $matching=@($cases | Where-Object { $window.Title.Contains($_.Name+'\Media\Queue') })
        if($matching.Count -ne 1) { throw 'Cannot associate owned window with a test case.' }
        $case=$matching[0]
        if($case.Columns -ne 1 -or $case.Scale -notin @(0.75,1,2)) { continue }
        if($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 2048 -or $window.Height -gt 2048) { throw 'Unexpected capture dimensions.' }
        $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $hdc=[IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta)
            $hdc=$graphics.GetHdc()
            $printed=[ParallaxQueueViewNative]::PrintWindow($window.Handle,$hdc,2)
            $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
            $colors=[Collections.Generic.HashSet[int]]::new()
            for($x=0;$x -lt $bitmap.Width;$x+=2){for($y=0;$y -lt $bitmap.Height;$y+=2){$null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb())}}
            $file=Join-Path $runRoot ("captures\synthetic-$($case.Name)-w$($case.Width)-s$($case.Scale)-c$($case.Columns).png")
            $bitmap.Save($file,[Drawing.Imaging.ImageFormat]::Png)
            $captures += [pscustomobject]@{Case=$case.Name;Synthetic=$true;File=$file;Printed=$printed;Colors=$colors.Count;Width=$window.Width;Height=$window.Height}
        } finally {
            if($hdc -ne [IntPtr]::Zero){$graphics.ReleaseHdc($hdc)}
            $graphics.Dispose();$bitmap.Dispose()
        }
    }
    $errors=@()
    $log=Join-Path $runRoot 'Rainmeter.log'
    if(Test-Path -LiteralPath $log){$errors=@(Get-Content -LiteralPath $log | Where-Object {$_ -match '^ERRO'})}
    $evidence=[ordered]@{Synthetic=$true;Cases=$cases.Count;FailedCases=$failed;LogErrors=$errors;OwnedPid=$testProcess.Id;
        RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion;SourceHashes=$sourceHashes;Captures=$captures;
        Limits='Synthetic Queue view only. No Spotify authorization, helper execution, real queue/session/cache read, live Rainmeter settings, or performance verification.'}
    Write-TestFile (Join-Path $runRoot 'queue-view-evidence.json') ($evidence | ConvertTo-Json -Depth 5)
    Write-Output "Evidence retained at $runRoot"
    foreach($path in $sourceHashes.Keys){if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $sourceHashes[$path]){throw 'Source changed during native run; rerun for coherent evidence.'}}
    if($failed.Count -or $errors.Count){$errors | Write-Output;throw "$($failed.Count) native Queue cases failed; $($errors.Count) Rainmeter error entries."}
    if(@($captures | Where-Object {-not $_.Printed -or $_.Colors -le 16}).Count){throw 'A capture is blank/unsupported; do not treat it as visual QA.'}
    Write-Output "PASS: $($cases.Count) native Queue view layouts; $($captures.Count) synthetic own-window captures."
} finally {
    if($null -ne $testProcess){
        $testProcess.Refresh()
        if(-not $testProcess.HasExited){Stop-Process -InputObject $testProcess -Force;$null=$testProcess.WaitForExit(5000)}
        $testProcess.Dispose()
    }
    # Retain evidence. Never kill by process name, send CLI bangs, or delete live files.
}
