#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet(180,220)][int]$ColumnWidth=220,[ValidateSet('0.75','1','2')][string]$Scale='1')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$sourceRoot=Join-Path $repo 'Skins\Parallax'
$runRoot=Join-Path $PSScriptRoot ('.runtime\cpu-settings-'+[guid]::NewGuid().ToString('N'))
$skinRoot=Join-Path $runRoot 'Skins'
$stage=Join-Path $skinRoot 'Parallax'
$process=$null
$encoding=[Text.UTF8Encoding]::new($false)
function Write-Fixture([string]$Path,[string]$Text) {
    $absolute=[IO.Path]::GetFullPath($Path)
    if (-not $absolute.StartsWith([IO.Path]::GetFullPath($runRoot)+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Not an isolated fixture path.'}
    [IO.File]::WriteAllText($absolute,$Text,$encoding)
}
foreach($dir in @('CPU\Settings','@Resources\User','@Resources\Modules\CPU','@Resources\Scripts')) {
    $null=New-Item -ItemType Directory -Path (Join-Path $stage $dir) -Force
}
foreach($file in @('@Resources\Defaults.inc','@Resources\Geometry.inc','@Resources\Styles.inc','@Resources\UtilitySettingsNote.inc','@Resources\User\Settings.inc','@Resources\User\CPU.inc','CPU\Settings\Settings.ini','@Resources\Modules\CPU\Settings.lua','@Resources\Modules\CPU\SettingsMeters.inc','@Resources\Scripts\SettingsInput.ps1')) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot $file) -Destination (Join-Path $stage $file)
}
Copy-Item -LiteralPath (Join-Path $sourceRoot '@Resources\Fonts') -Destination (Join-Path $stage '@Resources\Fonts') -Recurse
$global=Join-Path $stage '@Resources\User\Settings.inc'
$text=Get-Content -LiteralPath $global -Raw
foreach($pair in @{Scale=$Scale;ColumnWidth=$ColumnWidth;TitleFontSize=12;HeaderFontSize=10;FontSize=10;DividerThickness=4;BorderThickness=4}.GetEnumerator()) {
    $text=[regex]::Replace($text,'(?m)^'+$pair.Key+'=[^\r\n]*',$pair.Key+'='+$pair.Value)
}
Write-Fixture $global $text
$user=Join-Path $stage '@Resources\User\CPU.inc'
$text=Get-Content -LiteralPath $user -Raw
foreach($pair in @{CPUShowInfo=1;CPUShowCores=1;CPUShowProcesses=1;CPUShowHistory=1;CPUProcessCount=5;CPUHistorySamples=60;CPUDecimals=0;CPUHistorySource=0;Columns=1;PanelHeight=123}.GetEnumerator()) {
    $text=[regex]::Replace($text,'(?m)^'+$pair.Key+'=[^\r\n]*',$pair.Key+'='+$pair.Value)
}
Write-Fixture $user $text
$entry=Join-Path $stage 'CPU\Settings\Settings.ini'
$text=Get-Content -LiteralPath $entry -Raw
# Only the fixture suppresses the established one-shot discovery and enables test ticks.
$text=[regex]::Replace($text,'(?m)^OnRefreshAction=[^\r\n]*','OnRefreshAction=')
$text=[regex]::Replace($text,'(?m)^Update=-1\r?$','Update=100')
$text+="`n[MeasureCPUSettingsStyleQA]`nMeasure=Script`nScriptFile=$PSScriptRoot\SettingsStyleSmoke.lua`nSuitePath=$PSScriptRoot\validate_sensor_setup.lua`nControllerPath=$stage\@Resources\Modules\CPU\Settings.lua`nReportRoot=$runRoot\`nUpdateDivider=1`n"
Write-Fixture $entry $text
$ini=Join-Path $runRoot 'Rainmeter.ini'
Write-Fixture $ini "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nTrayIcon=0`n`n[Parallax\CPU\Settings]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`n"
Write-Fixture (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxCPUSettingsNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxCPUSettingsNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public string ClassName; public int Width, Height; }
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
            windows.Add(new Window { Handle=hwnd, Title=title.ToString(), ClassName=cls.ToString(), Width=rect.Right-rect.Left, Height=rect.Bottom-rect.Top });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}
'@
}

function Capture-Own($window,[string]$name) {
    $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    $hdc=[IntPtr]::Zero
    try {
        $hdc=$graphics.GetHdc()
        if (-not [ParallaxCPUSettingsNative]::PrintWindow($window.Handle,$hdc,2)) {throw 'Own PrintWindow failed.'}
        $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
        $bitmap.Save((Join-Path $runRoot ($name+'.png')),[Drawing.Imaging.ImageFormat]::Png)
        Write-Fixture (Join-Path $runRoot ($name+'-size.txt')) ($window.Width.ToString()+'x'+$window.Height)
    } finally {
        if($hdc -ne [IntPtr]::Zero){$graphics.ReleaseHdc($hdc)}
        $graphics.Dispose();$bitmap.Dispose()
    }
}
try {
    $process=Start-Process -FilePath (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe') -ArgumentList ('"'+$ini+'"') -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    $captured=@{}
    while([DateTime]::UtcNow -lt $deadline) {
        if(Test-Path -LiteralPath (Join-Path $runRoot 'failed.txt')) {throw (Get-Content -LiteralPath (Join-Path $runRoot 'failed.txt') -Raw)}
        $windows=@([ParallaxCPUSettingsNative]::GetOwnWindows([uint32]$process.Id))
        $ready=Join-Path $runRoot 'capture-ready.txt'
        if(Test-Path -LiteralPath $ready) {
            $phase=(Get-Content -LiteralPath $ready -Raw).Trim()
            if(-not $captured.ContainsKey($phase) -and $windows.Count -eq 1) {
                Capture-Own $windows[0] $phase
                $captured[$phase]=$true
                Write-Fixture (Join-Path $runRoot ('capture-complete-'+$phase+'.txt')) 'captured'
            }
        }
        if((Test-Path -LiteralPath (Join-Path $runRoot 'passed.txt')) -and $windows.Count -eq 0) {break}
        Start-Sleep -Milliseconds 100
    }
    if(-not (Test-Path -LiteralPath (Join-Path $runRoot 'passed.txt'))) {throw 'Native test timed out.'}
    if($windows.Count -ne 0) {throw 'Settings close did not deactivate its own window.'}
    if($captured.Count -ne 2) {throw 'Missing expanded/collapsed capture.'}
    $log=Join-Path $runRoot 'Rainmeter.log'
    if(Test-Path -LiteralPath $log) {if(@(Get-Content -LiteralPath $log|Where-Object {$_ -match '^ERRO'}).Count){throw 'Rainmeter errors in fixture log.'}}
    $saved=Get-Content -LiteralPath $user -Raw
    if($saved -notmatch '(?m)^PanelHeight=123\r?$' -or $saved -notmatch '(?m)^Columns=1\r?$') {throw 'Settings overwrote monitor geometry.'}
    Get-Content -LiteralPath (Join-Path $runRoot 'controller.txt') | Select-Object -Last 1
    Get-Content -LiteralPath (Join-Path $runRoot 'passed.txt')
    Write-Output ('Evidence: '+$runRoot)
} finally {
    if($null -ne $process) {$process.Refresh();if(-not $process.HasExited){Stop-Process -InputObject $process -Force;$null=$process.WaitForExit(5000)}}
}
