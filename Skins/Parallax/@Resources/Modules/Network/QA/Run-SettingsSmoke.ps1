#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(12,60)][int]$TimeoutSeconds=40,
    [switch]$Capture,
    [switch]$KeepArtifacts
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$moduleRoot=Split-Path -Parent $PSScriptRoot
$resourcesRoot=Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource=Split-Path -Parent $resourcesRoot
$runRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('settings-run-'+[guid]::NewGuid().ToString('N'))))
$testProcess=$null
$encoding=[Text.UTF8Encoding]::new($false)
function Assert-RunPath([string]$Path) {
    $absolute=[IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes isolated Network Settings run.' }
}
function Write-TestFile([string]$Path,[string]$Text) {
    Assert-RunPath $Path
    [IO.File]::WriteAllText($Path,$Text,$encoding)
}
function Set-VariableText([string]$Text,[string]$Key,[string]$Value) {
    $pattern='(?m)^'+[regex]::Escape($Key)+'=[^\r\n]*'
    if ([regex]::IsMatch($Text,$pattern)) { return [regex]::Replace($Text,$pattern,($Key+'='+$Value)) }
    return $Text+"`n$Key=$Value`n"
}
function Read-Variables([string]$Path) {
    $values=@{}
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $Path -Raw),'(?m)^([A-Za-z][A-Za-z0-9]*)=([^\r\n]*)')) { $values[$match.Groups[1].Value]=$match.Groups[2].Value }
    return $values
}
function Wait-Check([scriptblock]$Condition,[string]$Message) {
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $testProcess.Refresh()
        if ($testProcess.HasExited) { throw 'Isolated Settings process exited early.' }
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw $Message
}
function Counter([string]$Name) {
    $path=Join-Path $runRoot ($Name+'-count.txt')
    if (Test-Path -LiteralPath $path) { return [int](Get-Content -LiteralPath $path -Raw) }
    return 0
}
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; this harness installs nothing.' }
try {
    $sourceEntry=Get-Content -LiteralPath (Join-Path $skinSource 'Network\Settings\Settings.ini') -Raw
    if ($sourceEntry -notmatch '(?m)^Update=-1\r?$') { throw 'Production Settings must have no recurring update.' }
    $sourceMeters=Get-Content -LiteralPath (Join-Path $moduleRoot 'SettingsMeters.inc') -Raw
    $noteText=Get-Content -LiteralPath (Join-Path $resourcesRoot 'UtilitySettingsNote.inc') -Raw
    $meterNames=[Collections.Generic.List[string]]::new()
    $glyphs=[Collections.Generic.List[object]]::new()
    function Add-Glyph([string]$Target,[string]$Text,[bool]$Width=$true,[bool]$Live=$false) {
        $glyphs.Add([pscustomobject]@{Target=$Target;Text=$Text;Width=$Width;Live=$Live})
    }
    foreach ($section in [regex]::Matches(($sourceEntry+"`n"+$sourceMeters+"`n"+$noteText),'(?ms)^\[(Meter[^\]\r\n]+)\]\r?\n(.*?)(?=^\[|\z)')) {
        $name=$section.Groups[1].Value;$body=$section.Groups[2].Value
        $meterNames.Add($name)
        if ($body -match '(?m)^Meter=String\r?$') {
            Add-Glyph $name '--' ($name -notin @('MeterNetworkSettingsAdapterValue','MeterNetworkSettingsHeightValue')) $true
        }
    }
    foreach ($target in @('UnitsValue')) { foreach ($caption in @('bits','bytes')) { Add-Glyph ('MeterNetworkSettings'+$target) $caption } }
    foreach ($target in @('WidthValue')) { foreach ($caption in @('1','2')) { Add-Glyph ('MeterNetworkSettings'+$target) $caption } }
    foreach ($target in @('InCeilingValue','OutCeilingValue')) {
        foreach ($caption in @('0.0001','10','25','50','100','250','500','1000','1000000000','999999999.9999')) { Add-Glyph ('MeterNetworkSettings'+$target) $caption }
    }
    foreach ($caption in @('On','Off')) { Add-Glyph 'MeterNetworkSettingsWiFiEnabledValue' $caption }
    foreach ($caption in @('0','63')) { Add-Glyph 'MeterNetworkSettingsWiFiIndexValue' $caption }
    foreach ($field in @('Adapter','Units','Width','Height','InCeiling','OutCeiling','WiFiEnabled','WiFiIndex')) {
        foreach ($caption in @('Missing','Invalid')) { Add-Glyph ('MeterNetworkSettings'+$field+'Value') $caption }
    }
    Add-Glyph 'MeterNetworkSettingsAdapterValue' 'Best'
    foreach ($field in @('Height')) {
        Add-Glyph ('MeterNetworkSettings'+$field+'Value') '236'
        Add-Glyph ('MeterNetworkSettings'+$field+'Value') '999999999.9999'
        Add-Glyph ('MeterNetworkSettings'+$field+'Value') 'Custom'
    }
    foreach ($caption in @('Cannot read Network.inc.','Check invalid or missing values.','Invalid settings action.',
        'Saved. Refresh requested.','File reloaded. Refresh requested.',
        'Cannot open Network.inc.','Invalid navigation target.','Finish the open number editor.','Saved value changed; edit again.',
        'Enter a number or edit the file.','Edit this custom value in Network.inc.','Number editor unavailable.',
        'Enter to apply. Esc to cancel.','Number edit cancelled.','Number was not applied.')) { Add-Glyph 'MeterNetworkSettingsStatus' $caption }
    $cases=@(
        [pscustomobject]@{Width=180;Scale=0.75;Typography='maximum'},
        [pscustomobject]@{Width=220;Scale=1;Typography='default'},
        [pscustomobject]@{Width=220;Scale=1;Typography='maximum'}
    )
    $settings="[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    $entries=[Collections.Generic.List[object]]::new()
    $before=[Collections.Generic.List[object]]::new()
    $index=0
    foreach ($case in $cases) {
        $index++
        $actionCase=$case.Width -eq 220 -and $case.Scale -eq 1 -and $case.Typography -eq 'maximum'
        $rootName=if ($actionCase) {'Parallax'} else {'Case'+$index}
        $caseRoot=Join-Path $runRoot ('Skins\'+$rootName)
        foreach ($subdir in @('Network\Settings','@Resources\User','@Resources\Modules\Network','@Resources\Scripts')) {
            $dir=Join-Path $caseRoot $subdir;Assert-RunPath $dir;$null=New-Item -ItemType Directory -Path $dir -Force
        }
        foreach ($file in @('Defaults.inc','Geometry.inc','Styles.inc','UtilitySettingsNote.inc')) {
            Copy-Item -LiteralPath (Join-Path $resourcesRoot $file) -Destination (Join-Path $caseRoot ('@Resources\'+$file))
        }
        Copy-Item -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Destination (Join-Path $caseRoot '@Resources\Fonts') -Recurse
        Copy-Item -LiteralPath (Join-Path $resourcesRoot 'Scripts\SettingsInput.ps1') -Destination (Join-Path $caseRoot '@Resources\Scripts\SettingsInput.ps1')
        # Explicit production-only allowlist: never copy QA, tests or runtime data.
        foreach ($file in @('Core.lua','Settings.lua','SettingsMeters.inc')) {
            Copy-Item -LiteralPath (Join-Path $moduleRoot $file) -Destination (Join-Path $caseRoot ('@Resources\Modules\Network\'+$file))
        }
        $scaleText=$case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture)
        $global=Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Settings.inc') -Raw
        $fixture=@{ColumnWidth=[string]$case.Width;Scale=$scaleText;BorderThickness='4';DividerThickness='4';TableHeaderBorderThickness='0';DataBarThickness='12';TitleFontSize='10';HeaderFontSize='8';FontSize='9';AccentColor='203,97,41';HeaderTextColor='51,149,211';TextColor='221,222,223'}
        if ($case.Typography -eq 'maximum') { $fixture.TitleFontSize='12';$fixture.HeaderFontSize='10';$fixture.FontSize='10' }
        foreach ($key in $fixture.Keys) { $global=Set-VariableText $global $key $fixture[$key] }
        $globalPath=Join-Path $caseRoot '@Resources\User\Settings.inc';Write-TestFile $globalPath $global
        $module=Get-Content -LiteralPath (Join-Path $resourcesRoot 'User\Network.inc') -Raw
        foreach ($entry in @(@('NetworkUnits','bits'),@('Columns','1'),@('PanelHeight','236'),@('NetworkInCeilingMbps','100'),@('NetworkOutCeilingMbps','25'),@('NetworkConnectionColumns','deprecated'),@('NetworkConnectionHeight','retain legacy minimum'),@('NetworkWiFiEnabled','0'),@('NetworkWiFiInterface','0'))) {
            $module=Set-VariableText $module $entry[0] $entry[1]
        }
        if ($index -eq 1) {
            $module=Set-VariableText $module 'NetworkInterface' 'QA long adapter alias that must remain clipped inside the value field without changing the window'
            $module=Set-VariableText $module 'Columns' '2'
            $module=Set-VariableText $module 'PanelHeight' '333'
        }
        $modulePath=Join-Path $caseRoot '@Resources\User\Network.inc';Write-TestFile $modulePath $module
        $before.Add([pscustomobject]@{Global=$globalPath;GlobalHash=(Get-FileHash -LiteralPath $globalPath).Hash;Module=$modulePath;ModuleHash=(Get-FileHash -LiteralPath $modulePath).Hash})
        $entry=[regex]::Replace($sourceEntry,'(?m)^Update=-1\r?$','Update=100')
        # Only the instrumentation polls. Preserve the production controller's
        # one initial Update so action redraws cannot be masked by a QA cadence.
        $entry+="`n[MeasureNetworkSettings]`nUpdateDivider=-1`n"
        $entry+="`n[MeasureNetworkSettingsSmoke]`nMeasure=Script`nScriptFile=$PSScriptRoot\SettingsSmoke.lua`nMode=Layout`nResultFile=$runRoot\result-$index.txt`nExpectedColumnWidth=$($case.Width)`nExpectedScale=$scaleText`nTypography=$($case.Typography)`nMeterCount=$($meterNames.Count)`nGlyphCount=$($glyphs.Count)`n"
        if ($index -eq 1) { $entry+="LongValueFixture=1`n" }
        if ($actionCase) {
            $entry+="CommandFile=$runRoot\action.txt`nAckFile=$runRoot\ack.txt`nActionErrorFile=$runRoot\action-error.txt`nCountFile=$runRoot\settings-count.txt`nInputAnchorFile=$runRoot\input-anchor.txt`nInputFinishFile=$runRoot\input-finish.txt`n"
            $actionRoot=$caseRoot;$actionModule=$modulePath;$actionGlobal=$globalPath;$actionResult=Join-Path $runRoot "result-$index.txt"
        }
        for ($m=0;$m -lt $meterNames.Count;$m++) { $entry+='MeterName'+($m+1)+'='+$meterNames[$m]+"`n" }
        for ($g=0;$g -lt $glyphs.Count;$g++) {
            $probe=$glyphs[$g];$n=$g+1
            $entry+="GlyphTarget$n=$($probe.Target)`nGlyphWidth$n=$([int]$probe.Width)`nGlyphLive$n=$([int]$probe.Live)`n"
        }
        for ($g=0;$g -lt $glyphs.Count;$g++) {
            $probe=$glyphs[$g];$n=$g+1
            $entry+="`n[MeterNetworkSettingsGlyph$n]`nMeter=String`nX=0`nY=0`nHidden=1`nClipString=0`nPadding=0,0,0,0`nFontColor=0,0,0,0`nFontFace=#FontFace#`nFontSize=(#FontSize#*#Scale#)`nFontWeight=500`nStringStyle=Normal`nStringCase=None`nCharacterSpacing=0`nDynamicVariables=1`nAntiAlias=1`nText=$($probe.Text)`n"
        }
        Write-TestFile (Join-Path $caseRoot 'Network\Settings\Settings.ini') $entry
        $captureThis=$Capture -and (($case.Width -eq 180 -and $case.Scale -eq 0.75) -or ($case.Width -eq 220 -and $case.Scale -eq 1 -and $case.Typography -eq 'default'))
        $alpha=if ($captureThis) {255} else {0}
        $config=$rootName+'\Network\Settings'
        $settings+="`n[$config]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=$alpha`n"
        $entries.Add([pscustomobject]@{Config=$config;Capture=$captureThis;Case=$case})
    }
    # Exercise the production helper and real RunCommand pipeline without showing a dialog.
    # Replace only its modal boundary, using the shared helper test's own-HWND event approach.
    $inputPath=Join-Path $actionRoot '@Resources\Scripts\SettingsInput.ps1'
    $inputSource=Get-Content -LiteralPath $inputPath -Raw
    $modalBoundary='$null = $form.ShowDialog()'
    if ([regex]::Matches($inputSource,[regex]::Escape($modalBoundary)).Count -ne 1) { throw 'Numeric helper modal boundary changed; review hidden-HWND instrumentation.' }
    $hiddenBoundary=@'
$qaCase=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SettingsQaInput.json') -Raw | ConvertFrom-Json
$qaReport=[ordered]@{Status='FAIL';Sequence=$qaCase.Sequence;Key=$Key;Initial=$Initial;Minimum=$Minimum;Maximum=$Maximum;DecimalPlaces=$DecimalPlaces;X=$X;Y=$Y;Width=$Width;Height=$Height;Scale=$Scale}
try {
    if ($Key -cne 'UtilityNumber' -or $Initial -cne $qaCase.Initial) { throw 'Unexpected numeric key or initial launch value.' }
    if ($form.FormBorderStyle -ne [Windows.Forms.FormBorderStyle]::None -or $form.ShowInTaskbar -or $form.Controls.Count -ne 1) { throw 'Unexpected editor window.' }
    $null=$form.Handle; $null=$box.Handle; $form.PerformLayout()
    $boxScreen=$box.PointToScreen([Drawing.Point]::Empty)
    if ($form.Location.X -ne [int]$X -or $form.Location.Y -ne [int]$Y -or $form.Width -ne [int]$Width -or $form.Height -ne [int]$Height) { throw 'Form HWND differs from requested frame bounds.' }
    if ($boxScreen.X -ne ([int]$X+1) -or $boxScreen.Y -ne ([int]$Y+1) -or $box.Width -ne ([int]$Width-2) -or $box.Height -ne ([int]$Height-2)) { throw 'TextBox HWND differs from the input frame interior.' }
    if ($box.Text -cne $qaCase.Initial) { throw 'Input box did not preserve the canonical or blank initial value.' }
    if ($qaCase.Action -eq 'delayed') {
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'SettingsQaPending.json'),(@{Sequence=$qaCase.Sequence;ProcessId=$PID}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
        Start-Sleep -Seconds 10
    }
    $box.Text=[string]$qaCase.Text; $tip.Active=$false
    $onKeyDown=$box.GetType().GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic')
    $keyCode=if ($qaCase.Action -eq 'escape') {[Windows.Forms.Keys]::Escape} else {[Windows.Forms.Keys]::Enter}
    $keyEvent=New-Object Windows.Forms.KeyEventArgs($keyCode)
    $null=$onKeyDown.Invoke($box,[object[]]@($keyEvent.PSObject.BaseObject))
    if ($qaCase.Action -eq 'invalid') {
        if ($form.IsDisposed -or $form.BackColor.R -ne 230 -or $form.Tag.Response -ne 'PARALLAX_INPUT_V1|cancel|') { throw 'Invalid entry did not remain open with an error.' }
        $escapeEvent=New-Object Windows.Forms.KeyEventArgs([Windows.Forms.Keys]::Escape)
        $null=$onKeyDown.Invoke($box,[object[]]@($escapeEvent.PSObject.BaseObject))
    }
    $qaReport.Response=[string]$form.Tag.Response
    $qaReport.Status='PASS'
} catch { $qaReport.Error=$_.Exception.Message; throw }
finally { [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'SettingsQaResult.json'),($qaReport|ConvertTo-Json),[Text.UTF8Encoding]::new($false)) }
'@
    Write-TestFile $inputPath ($inputSource.Replace($modalBoundary,$hiddenBoundary))
    $actionEntryPath=Join-Path $actionRoot 'Network\Settings\Settings.ini'
    $actionEntry=Get-Content -LiteralPath $actionEntryPath -Raw
    $finishAction='FinishAction=[!UpdateMeasure MeasureNetworkSettingsInput][!CommandMeasure MeasureNetworkSettings "FinishNumberInput()"]'
    if (-not $actionEntry.Contains($finishAction)) { throw 'Production numeric input FinishAction differs.' }
    Write-TestFile $actionEntryPath ($actionEntry.Replace($finishAction,$finishAction+'[!CommandMeasure MeasureNetworkSettingsSmoke "InputFinished()"]'))
    foreach ($stub in @(@('Network','Network\Network.ini','Parallax|ParallaxNetwork',1),@('Connection','Network\Connection\Connection.ini','Parallax|ParallaxNetwork',1),@('Sentinel','Sentinel\Sentinel.ini','Parallax',1),@('Global','Settings\Settings.ini','Parallax',0))) {
        $stubPath=Join-Path $actionRoot $stub[1]
        $null=New-Item -ItemType Directory -Path (Split-Path -Parent $stubPath) -Force
        $stubText="[Rainmeter]`nUpdate=-1`nGroup=$($stub[2])`nDynamicWindowSize=1`n[Variables]`n@Include1=#@#User\Network.inc`n[MeasureObserver]`nMeasure=Script`nScriptFile=$PSScriptRoot\SettingsSmoke.lua`nMode=Observer`nCountFile=$runRoot\$($stub[0])-count.txt`nSnapshotFile=$runRoot\$($stub[0])-snapshot.txt`n[MeterBounds]`nMeter=Image`nW=2`nH=2`nSolidColor=0,0,0,1`n"
        Write-TestFile $stubPath $stubText
        $config='Parallax\'+(Split-Path -Parent $stub[1])
        $settings+="`n[$config]`nActive=$($stub[3])`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
    }
    foreach ($subdir in @('Layouts','Plugins','Addons','Captures')) { $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $subdir) -Force }
    $iniPath=Join-Path $runRoot 'Rainmeter.ini';Write-TestFile $iniPath $settings
    Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    Write-TestFile (Join-Path $runRoot 'QA-ONLY.txt') "Isolated Network Settings fixtures and own-window captures. Do not distribute.`n"
    # Own-PID window inventory and capture only; independent of monitor QA runners.
    if (-not ('ParallaxNetworkSettingsCapture' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxNetworkSettingsCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width, Height; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr destination, uint flags);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] private struct PROCESSENTRY32 {
        public uint Size, Usage, ProcessId;
        public UIntPtr DefaultHeap;
        public uint ModuleId, Threads, ParentId;
        public int BasePriority;
        public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string ExeFile;
    }
    [DllImport("kernel32.dll")] private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, EntryPoint="Process32FirstW")] private static extern bool Process32First(IntPtr snapshot, ref PROCESSENTRY32 entry);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, EntryPoint="Process32NextW")] private static extern bool Process32Next(IntPtr snapshot, ref PROCESSENTRY32 entry);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    public static bool IsOwnPowerShellChild(uint pid, uint parent) {
        IntPtr snapshot=CreateToolhelp32Snapshot(2,0);
        if (snapshot==new IntPtr(-1)) return false;
        try {
            var entry=new PROCESSENTRY32(); entry.Size=(uint)Marshal.SizeOf(entry);
            if (Process32First(snapshot,ref entry)) do {
                if (entry.ProcessId==pid) return entry.ParentId==parent && String.Equals(entry.ExeFile,"powershell.exe",StringComparison.OrdinalIgnoreCase);
            } while (Process32Next(snapshot,ref entry));
            return false;
        } finally { CloseHandle(snapshot); }
    }
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
    function Own-Windows { return @([ParallaxNetworkSettingsCapture]::GetOwnWindows([uint32]$testProcess.Id)) }
    function Config-Windows([string]$Config) {
        $file=switch ($Config) {
            'Parallax\Network' {'Network.ini'}
            'Parallax\Network\Connection' {'Connection.ini'}
            'Parallax\Sentinel' {'Sentinel.ini'}
            default {'Settings.ini'}
        }
        $absolute=[IO.Path]::GetFullPath((Join-Path $runRoot ('Skins\'+$Config+'\'+$file)))
        return @(Own-Windows | Where-Object { $_.Title -eq $absolute -or $_.Title -eq $Config -or $_.Title -eq ($Config+' - '+$file) })
    }
    function Has-Window([string]$Config) { return @(Config-Windows $Config).Count -eq 1 }
    $testProcess=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Wait-Check { @(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt').Count -eq $cases.Count } 'Not all Settings layout reports arrived.'
    $reports=@(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt')
    foreach ($report in $reports) { $text=Get-Content -LiteralPath $report.FullName -Raw;Write-Output $text;if ($text -notmatch '^PASS ') { throw $text } }
    foreach ($file in $before) {
        if ((Get-FileHash -LiteralPath $file.Global).Hash -ne $file.GlobalHash -or (Get-FileHash -LiteralPath $file.Module).Hash -ne $file.ModuleHash) { throw 'Opening Settings modified preferences.' }
    }
    Write-TestFile (Join-Path $runRoot 'own-window-titles.json') (@(Own-Windows | Select-Object Title,Width,Height) | ConvertTo-Json -Depth 3)
    if ($Capture) {
        Add-Type -AssemblyName System.Drawing
        $captures=[Collections.Generic.List[object]]::new()
        foreach ($entry in @($entries | Where-Object Capture)) {
            $matches=@(Config-Windows $entry.Config)
            if ($matches.Count -ne 1) { throw ('Missing unique own Settings capture window: '+$entry.Config) }
            $window=$matches[0]
            if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 4096 -or $window.Height -gt 4096) { throw 'Unexpected own Settings dimensions.' }
            $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics=[Drawing.Graphics]::FromImage($bitmap);$hdc=[IntPtr]::Zero
            try {
                $graphics.Clear([Drawing.Color]::Magenta);$hdc=$graphics.GetHdc()
                $printed=[ParallaxNetworkSettingsCapture]::PrintWindow($window.Handle,$hdc,2)
                $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
                $colors=[Collections.Generic.HashSet[int]]::new()
                for ($x=0;$x -lt $bitmap.Width;$x+=3) { for ($y=0;$y -lt $bitmap.Height;$y+=3) { $null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
                if (-not $printed -or $colors.Count -lt 16) { throw 'Blank or unsupported own-window capture.' }
                $path=Join-Path $runRoot ('Captures\NetworkSettings-width'+$entry.Case.Width+'-scale'+$entry.Case.Scale.ToString([Globalization.CultureInfo]::InvariantCulture)+'-'+$entry.Case.Typography+'.png')
                $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
                $captures.Add([pscustomobject]@{File=$path;Width=$window.Width;Height=$window.Height;PrintWindow=$printed;SampledColors=$colors.Count})
            } finally { if ($hdc -ne [IntPtr]::Zero) {$graphics.ReleaseHdc($hdc)};$graphics.Dispose();$bitmap.Dispose() }
        }
        Write-TestFile (Join-Path $runRoot 'capture-report.json') ($captures.ToArray() | ConvertTo-Json -Depth 4)
    }
    function Action([string]$Command) {
        $pending=Join-Path $runRoot 'action-pending.txt';$ready=Join-Path $runRoot 'action.txt'
        $ack=Join-Path $runRoot 'ack.txt';Assert-RunPath $ack
        if (Test-Path -LiteralPath $ack) { Remove-Item -LiteralPath $ack }
        Write-TestFile $pending $Command;Assert-RunPath $pending;Assert-RunPath $ready
        Move-Item -LiteralPath $pending -Destination $ready
        Wait-Check { (Test-Path -LiteralPath (Join-Path $runRoot 'ack.txt')) -and (Get-Content -LiteralPath (Join-Path $runRoot 'ack.txt') -Raw) -eq $Command } ('Production action not acknowledged: '+$Command)
        if (Test-Path -LiteralPath (Join-Path $runRoot 'action-error.txt')) { throw (Get-Content -LiteralPath (Join-Path $runRoot 'action-error.txt') -Raw) }
    }
    $globalBefore=(Get-FileHash -LiteralPath $actionGlobal).Hash
    if ((Counter 'Network') -ne 1 -or (Counter 'Connection') -ne 1 -or (Counter 'Sentinel') -ne 1 -or (Counter 'settings') -ne 1) { throw 'Unexpected initial isolated target counts.' }
    $nativeChecks=[Collections.Generic.List[string]]::new()
    $typedReports=[Collections.Generic.List[object]]::new()
    function Assert-SavedDelta($Before,[int]$CountBefore,[string]$Key,[string]$Expected,[string]$Label) {
        $changed=$Before[$Key] -cne $Expected
        $targetCount=$CountBefore+[int]$changed
        Wait-Check { (Counter 'Network') -eq $targetCount } ($Label+' did not use its exact Network refresh count.')
        $after=Read-Variables $actionModule
        if ($after[$Key] -cne $Expected) { throw ($Label+' did not preserve/save expected '+$Key+'='+$Expected) }
        foreach ($other in $Before.Keys) { if ($other -cne $Key -and $Before[$other] -cne $after[$other]) { throw ($Label+' changed unrelated or deprecated '+$other) } }
        if ($after.Count -ne $Before.Count -or (Get-FileHash -LiteralPath $actionGlobal).Hash -ne $globalBefore) { throw ($Label+' changed other settings data.') }
        if ((Counter 'Connection') -ne 1 -or (Counter 'Sentinel') -ne 1 -or (Counter 'settings') -ne 1) { throw ($Label+' refreshed an unrelated target.') }
        $nativeChecks.Add($Label)
    }
    function Check-Control([string]$Command,[string]$Key,[string]$Expected) {
        $beforeValue=Read-Variables $actionModule;$countBefore=Counter 'Network'
        Action $Command
        Assert-SavedDelta $beforeValue $countBefore $Key $Expected $Command
    }
    foreach ($choice in @(@('units','NetworkUnits','bytes'),@('unitsBack','NetworkUnits','bits'),@('units','NetworkUnits','bytes'),
        @('wifi','NetworkWiFiEnabled','1'),@('sourceDown','NetworkWiFiInterface','0'),@('source','NetworkWiFiInterface','1'),
        @('widthDown','Columns','1'),@('widthUp','Columns','2'),@('widthUp','Columns','2'),@('widthDown','Columns','1'),
        @('heightUp','PanelHeight','237'),@('heightDown','PanelHeight','236'),
        @('inUp','NetworkInCeilingMbps','250'),@('inDown','NetworkInCeilingMbps','100'),
        @('outDown','NetworkOutCeilingMbps','10'),@('outUp','NetworkOutCeilingMbps','25'))) {
        Check-Control $choice[0] $choice[1] $choice[2]
    }
    function Check-Typed([string]$Command,[string]$Key,[string]$Initial,[string]$Text,[string]$Kind,[string]$Expected) {
        $sequence=$typedReports.Count+1
        $beforeValue=Read-Variables $actionModule;$countBefore=Counter 'Network'
        $finishPath=Join-Path $runRoot 'input-finish.txt'
        $finishBefore=if (Test-Path -LiteralPath $finishPath) {[int](Get-Content -LiteralPath $finishPath -Raw)} else {0}
        $scenarioPath=Join-Path $actionRoot '@Resources\Scripts\SettingsQaInput.json'
        $reportPath=Join-Path $actionRoot '@Resources\Scripts\SettingsQaResult.json'
        Write-TestFile $scenarioPath ([ordered]@{Sequence=$sequence;Initial=$Initial;Text=$Text;Action=$Kind}|ConvertTo-Json)
        Action $Command
        Wait-Check { (Test-Path -LiteralPath $reportPath) -and (Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json).Sequence -eq $sequence } ('Hidden helper report missing for '+$Command)
        $inputReport=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
        if ($inputReport.Status -ne 'PASS') { throw ('Hidden numeric helper failed: '+($inputReport|ConvertTo-Json -Compress)) }
        Wait-Check { (Test-Path -LiteralPath $finishPath) -and [int](Get-Content -LiteralPath $finishPath -Raw) -eq ($finishBefore+1) } 'Real RunCommand FinishAction did not run.'
        $anchor=(Get-Content -LiteralPath (Join-Path $runRoot 'input-anchor.txt') -Raw).Split(',')
        if ([int]$inputReport.X -ne [int]$anchor[0] -or [int]$inputReport.Y -ne [int]$anchor[1] -or [int]$inputReport.Width -ne [int]$anchor[2] -or [int]$inputReport.Height -ne [int]$anchor[3]) { throw 'Helper HWND launch rectangle does not match the native input Frame.' }
        $typedReports.Add($inputReport)
        Assert-SavedDelta $beforeValue $countBefore $Key $Expected ($Command+'/'+$Kind)
        Check-Control 'replayInput' $Key $Expected
    }
    Check-Typed 'inputWidth' 'Columns' '1' '2' 'enter' '2'
    Check-Typed 'inputHeight' 'PanelHeight' '236' '512.25' 'enter' '512.25'
    Check-Typed 'inputIn' 'NetworkInCeilingMbps' '100' '42.5' 'enter' '42.5'
    Check-Typed 'inputOut' 'NetworkOutCeilingMbps' '25' '-1' 'invalid' '25'
    Check-Typed 'inputHeight' 'PanelHeight' '512.25' '600' 'escape' '512.25'
    Check-Typed 'inputSource' 'NetworkWiFiInterface' '1' '63' 'enter' '63'
    Check-Control 'source' 'NetworkWiFiInterface' '63'
    Check-Typed 'inputWidth' 'Columns' '2' '2' 'enter' '2'
    $networkBeforeNavigation=Counter 'Network'
    $savedHash=(Get-FileHash -LiteralPath $actionModule).Hash
    Action 'hide-network';Wait-Check { -not (Has-Window 'Parallax\Network') } 'Private target fixture did not unload.'
    Action 'apply';Wait-Check { (Counter 'settings') -eq 2 } 'Apply did not refresh current Settings with Network unloaded.'
    if ((Has-Window 'Parallax\Network') -or (Counter 'Network') -ne $networkBeforeNavigation -or (Counter 'Connection') -ne 1) { throw 'Apply activated Network or refreshed the retired Connection observer.' }
    Action 'network';Wait-Check { (Has-Window 'Parallax\Network') -and (Counter 'Network') -eq ($networkBeforeNavigation+1) } 'Show Network did not activate its exact target.'
    Action 'global';Wait-Check { (Has-Window 'Parallax\Settings') -and (Counter 'Global') -eq 1 } 'Shared Global Settings link did not open its exact target.'
    Write-TestFile $actionResult 'PENDING refresh validation'
    Action 'apply';Wait-Check { (Counter 'Network') -eq ($networkBeforeNavigation+2) -and (Counter 'Connection') -eq 1 -and (Counter 'settings') -eq 3 } 'Apply saved file did not refresh only Network and Settings.'
    Wait-Check { (Get-Content -LiteralPath $actionResult -Raw) -match '^PASS ' } 'Refreshed Settings layout failed.'
    # Begin a real one-shot child, then close before completion. It owns only hidden HWNDs.
    $delayedSequence=$typedReports.Count+1
    $pendingScenario=Join-Path $actionRoot '@Resources\Scripts\SettingsQaInput.json'
    $pendingChildPath=Join-Path $actionRoot '@Resources\Scripts\SettingsQaPending.json'
    Write-TestFile $pendingScenario ([ordered]@{Sequence=$delayedSequence;Initial='2';Text='1';Action='delayed'}|ConvertTo-Json)
    Action 'inputWidth'
    Wait-Check { Test-Path -LiteralPath $pendingChildPath } 'Delayed own helper did not reach its hidden modal boundary.'
    $pendingChild=Get-Content -LiteralPath $pendingChildPath -Raw|ConvertFrom-Json
    if ($pendingChild.Sequence -ne $delayedSequence) { throw 'Unexpected delayed helper identity.' }
    if (-not [ParallaxNetworkSettingsCapture]::IsOwnPowerShellChild([uint32]$pendingChild.ProcessId,[uint32]$testProcess.Id)) { throw 'Delayed helper is not the isolated Rainmeter PowerShell child.' }
    $blockedHash=(Get-FileHash -LiteralPath $actionModule).Hash;$blockedCount=Counter 'Network'
    Action 'units'
    if ((Get-FileHash -LiteralPath $actionModule).Hash -ne $blockedHash -or (Counter 'Network') -ne $blockedCount) { throw 'An action changed preferences while numeric input was pending.' }
    $closeTimer=[Diagnostics.Stopwatch]::StartNew()
    Action 'close';Wait-Check { -not (Has-Window 'Parallax\Network\Settings') } 'Close did not deactivate only Settings.'
    Wait-Check { -not (Get-Process -Id ([int]$pendingChild.ProcessId) -ErrorAction SilentlyContinue) } 'Closing Settings did not terminate its hidden one-shot input child.'
    if ($closeTimer.ElapsedMilliseconds -ge 3000) { throw 'Input child did not exit promptly on Close; natural delayed completion is not cancellation.' }
    foreach ($config in @('Parallax\Network','Parallax\Network\Connection','Parallax\Sentinel','Parallax\Settings')) { if (-not (Has-Window $config)) { throw ('Close also removed '+$config) } }
    if ((Counter 'Sentinel') -ne 1 -or (Counter 'Global') -ne 1 -or (Get-FileHash -LiteralPath $actionModule).Hash -ne $savedHash -or (Get-FileHash -LiteralPath $actionGlobal).Hash -ne $globalBefore) { throw 'Navigation/apply/close changed preferences or refreshed unrelated targets.' }
    $errors=@(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object {$_ -match '^ERRO'})
    Write-TestFile (Join-Path $runRoot 'run-report.json') ([ordered]@{Cases=$cases.Count;GlyphChecksPerCase=$glyphs.Count;NativeControlChecks=$nativeChecks.ToArray();TypedInputReports=$typedReports.ToArray();PendingActionBlocked=$true;DelayedChildCancelledOnClose=$true;LifecycleChecks='No-write open; exact Network refresh; legacy keys/inert observers preserved; only Network activation; Global link; active/inactive Apply; independent Close';ArrowBackingTolerance='One physical pixel only for centered arrow hit bounds versus passive Shape background; native window bounds, adjacent hit separation and glyph fit remain strict.';LogErrors=$errors;Distributable=$false;CaptureMethod='Own-PID offscreen PrintWindow';Limitations='Network, legacy Connection and Global Settings use inert target stubs. Numeric helper constructs its own hidden HWNDs with only ShowDialog replaced; no displayed overlay, desktop input, provider or mixed-DPI behavior claimed.'} | ConvertTo-Json -Depth 5)
    if ($errors.Count) { throw ($errors -join "`n") }
    Write-Output "Network Settings smoke: $($cases.Count) layouts, $($glyphs.Count) glyph probes per layout, native save/refresh/navigation/close passed; no Rainmeter errors."
} finally {
    if ($testProcess) { $testProcess.Refresh();if (-not $testProcess.HasExited) {Stop-Process -InputObject $testProcess -Force;$null=$testProcess.WaitForExit(5000)};$testProcess.Dispose() }
    if (Test-Path -LiteralPath $runRoot) {
        if ($Capture -or $KeepArtifacts) { Write-Output "Network Settings QA evidence retained at $runRoot" }
        else {
            $item=Get-Item -LiteralPath $runRoot -Force;$resolved=[IO.Path]::GetFullPath($item.FullName)
            if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+'\',[StringComparison]::OrdinalIgnoreCase) -or
                (Split-Path -Leaf $resolved) -notmatch '^settings-run-[a-f0-9]{32}$' -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Refusing cleanup outside generated Settings QA directory.' }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
