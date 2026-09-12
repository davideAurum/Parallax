[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(20, 30)][int]$TimeoutSeconds = 30,
    [int[]]$Columns = @(1, 2),
    [int[]]$ColumnWidths = @(180),
    [double[]]$Scales = @(0.75, 1, 2),
    [ValidateRange(0, 12)][int]$TitleFontSize = 0,
    [ValidateRange(0, 10)][int]$HeaderFontSize = 0,
    [ValidateRange(0, 10)][int]$FontSize = 0,
    [ValidateRange(-1, 4)][int]$BorderThickness = -1,
    [ValidateRange(-1, 4)][int]$DividerThickness = -1
)

$ErrorActionPreference = 'Stop'
$smokeRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$moduleRoot = Split-Path -Parent (Split-Path -Parent $smokeRoot)
$resourceRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$suiteRoot = Split-Path -Parent $resourceRoot
$runtimeRoot = Join-Path $smokeRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('run-' + [guid]::NewGuid().ToString('N'))
$testProcess = $null
$caseCount = 0
$totalChecks = 0

function Assert-WithinRun([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if ($resolved -ne $runRoot -and -not $resolved.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing operation outside generated settings smoke run: $resolved"
    }
}
function Write-Utf8([string]$Path, [string]$Contents) {
    Assert-WithinRun $Path
    [IO.File]::WriteAllText($Path, $Contents, (New-Object Text.UTF8Encoding($false)))
}
function Copy-IntoRun([string]$Source, [string]$Target) {
    Assert-WithinRun $Target
    Copy-Item -LiteralPath $Source -Destination $Target
}
function Set-FixtureVariable([string]$Contents, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
    if ([regex]::IsMatch($Contents, $pattern)) { return [regex]::Replace($Contents, $pattern, ($Key + '=' + $Value)) }
    return $Contents.TrimEnd() + "`n$Key=$Value`n"
}

if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
if ((Test-Path -LiteralPath $runtimeRoot) -and ((Get-Item -LiteralPath $runtimeRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Settings smoke runtime root must not be a junction or symbolic link.'
}
foreach ($column in $Columns) { if ($column -notin @(1, 2)) { throw 'Columns must be 1 or 2.' } }
foreach ($width in $ColumnWidths) { if ($width -notin @(180, 200, 240, 280, 320)) { throw 'Unsupported ColumnWidth.' } }
foreach ($scale in $Scales) { if ($scale -notin @(0.75, 1, 1.25, 1.5, 2)) { throw 'Unsupported Scale.' } }
$countdownIni = Get-Content -LiteralPath (Join-Path $suiteRoot 'Chronometer\Chronometer.ini') -Raw
$menuIni = Get-Content -LiteralPath (Join-Path $suiteRoot 'Chronometer\Settings\Settings.ini') -Raw
# Enable only this copied menu's test orchestration. Production remains click-driven.
$menuIni = [regex]::Replace($menuIni, '(?m)^Update=-1\s*$', 'Update=1000')
$meterNames = @([regex]::Matches($menuIni, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { $_.Groups[1].Value }) -join '|'

try {
    foreach ($width in $ColumnWidths) {
        foreach ($column in $Columns) {
            foreach ($scale in $Scales) {
                $scaleText = $scale.ToString([Globalization.CultureInfo]::InvariantCulture)
                $caseRoot = Join-Path $runRoot ("w$width-c$column-s$scaleText")
                $skinRoot = Join-Path $caseRoot 'Skins'
                $skinDirectory = Join-Path $skinRoot 'Parallax\Chronometer'
                $menuDirectory = Join-Path $skinDirectory 'Settings'
                $resources = Join-Path $skinRoot 'Parallax\@Resources'
                $scripts = Join-Path $resources 'Modules\Chronometer'
                foreach ($directory in @($skinDirectory, $menuDirectory, $scripts, (Join-Path $resources 'User'),
                    (Join-Path $caseRoot 'Layouts'), (Join-Path $caseRoot 'Plugins'), (Join-Path $caseRoot 'Addons'))) {
                    Assert-WithinRun $directory
                    New-Item -ItemType Directory -Path $directory -Force | Out-Null
                }
                foreach ($name in @('Defaults.inc', 'Geometry.inc', 'Styles.inc')) {
                    Copy-IntoRun (Join-Path $resourceRoot $name) (Join-Path $resources $name)
                }
                foreach ($source in Get-ChildItem -LiteralPath $moduleRoot -File) {
                    if ($source.Extension -in @('.lua', '.inc')) { Copy-IntoRun $source.FullName (Join-Path $scripts $source.Name) }
                }
                Copy-IntoRun (Join-Path $smokeRoot 'Smoke.lua') (Join-Path $scripts 'SettingsSmoke.lua')
                $sourceFonts = Join-Path $resourceRoot 'Fonts'
                if (Test-Path -LiteralPath $sourceFonts -PathType Container) {
                    $targetFonts = Join-Path $resources 'Fonts'
                    Assert-WithinRun $targetFonts
                    New-Item -ItemType Directory -Path $targetFonts -Force | Out-Null
                    foreach ($font in Get-ChildItem -LiteralPath $sourceFonts -File) {
                        if ($font.Extension -in @('.ttf', '.otf')) { Copy-IntoRun $font.FullName (Join-Path $targetFonts $font.Name) }
                    }
                }
                $globalSettings = Get-Content -LiteralPath (Join-Path $resourceRoot 'User\Settings.inc') -Raw
                $globalSettings = [regex]::Replace($globalSettings, '(?m)^Scale=.*$', "Scale=$scaleText")
                $globalSettings = [regex]::Replace($globalSettings, '(?m)^ColumnWidth=.*$', "ColumnWidth=$width")
                foreach ($entry in @{ TitleFontSize=$TitleFontSize; HeaderFontSize=$HeaderFontSize; FontSize=$FontSize }.GetEnumerator()) {
                    if ($entry.Value -gt 0) { $globalSettings = Set-FixtureVariable $globalSettings $entry.Key $entry.Value }
                }
                foreach ($entry in @{ BorderThickness=$BorderThickness; DividerThickness=$DividerThickness }.GetEnumerator()) {
                    if ($entry.Value -ge 0) { $globalSettings = Set-FixtureVariable $globalSettings $entry.Key $entry.Value }
                }
                Write-Utf8 (Join-Path $resources 'User\Settings.inc') $globalSettings
                $moduleSettings = Get-Content -LiteralPath (Join-Path $resourceRoot 'User\Chronometer.inc') -Raw
                $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^Columns=.*$', "Columns=$column")
                $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerClockFormat=.*$', 'ChronometerClockFormat=%H:%M:%S')
                $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Timer1Seconds=.*$', 'ChronometerList1Timer1Seconds=1500')
                $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Timer2Seconds=.*$', 'ChronometerList1Timer2Seconds=300')
                foreach ($section in @('Clock', 'Uptime', 'Event', 'Timers')) {
                    $moduleSettings = Set-FixtureVariable $moduleSettings ('ChronometerShow' + $section) '1'
                }
                Write-Utf8 (Join-Path $resources 'User\Chronometer.inc') $moduleSettings
                $resultPath = Join-Path $caseRoot 'countdown-results.txt'
                $menuResultPath = Join-Path $caseRoot 'menu-results.txt'
                $baselinePath = Join-Path $caseRoot 'baseline.txt'
                $eventBaselinePath = Join-Path $caseRoot 'event-baseline.txt'
                $visibilityAckPath = Join-Path $caseRoot 'visibility-ack.txt'
                Write-Utf8 (Join-Path $skinDirectory 'Chronometer.ini') ($countdownIni + "`n" + @"
[MeasureSettingsLifecycleSmoke]
Measure=Script
ScriptFile=#@#Modules\Chronometer\SettingsSmoke.lua
Role=Countdown
ResultPath=$resultPath
MenuResultPath=$menuResultPath
BaselinePath=$baselinePath
EventBaselinePath=$eventBaselinePath
VisibilityAckPath=$visibilityAckPath
"@)
                Write-Utf8 (Join-Path $menuDirectory 'Settings.ini') ($menuIni + "`n" + @"
[MeasureSettingsMenuSmoke]
Measure=Script
ScriptFile=#@#Modules\Chronometer\SettingsSmoke.lua
Role=Menu
ResultPath=$menuResultPath
MeterNames=$meterNames
EventBaselinePath=$eventBaselinePath
VisibilityAckPath=$visibilityAckPath
"@)
                $probeIni = ''
                foreach ($probe in @('Title', 'ClockVisibility', 'TimerSeconds1', 'Status')) {
                    $probeIni += "`n[MeterSettingsSmoke$probe]`nMeter=String`nFontColor=0,0,0,0`nDynamicVariables=1`nX=0`nY=0`n"
                }
                $stagedMenu = Join-Path $menuDirectory 'Settings.ini'
                Write-Utf8 $stagedMenu ((Get-Content -LiteralPath $stagedMenu -Raw) + $probeIni)
                $iniPath = Join-Path $caseRoot 'Rainmeter.ini'
                Write-Utf8 $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[Parallax\Chronometer]
Active=1
WindowX=0
WindowY=0
Draggable=0
ClickThrough=1
AlphaValue=0

[Parallax\Chronometer\Settings]
Active=0
WindowX=0
WindowY=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@
                Write-Utf8 (Join-Path $caseRoot 'Rainmeter.data') "[Rainmeter]`n"
                if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
                Write-Output "Settings smoke: ColumnWidth=$width Columns=$column Scale=$scaleText"
                $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $caseRoot -WindowStyle Hidden -PassThru
                if (-not $testProcess.WaitForExit($TimeoutSeconds * 1000)) {
                    Stop-Process -InputObject $testProcess -Force
                    $testProcess.WaitForExit(5000) | Out-Null
                    throw 'Isolated settings smoke process timed out.'
                }
                $testProcess.Dispose()
                $testProcess = $null
                $logPath = Join-Path $caseRoot 'Rainmeter.log'
                $log = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
                foreach ($path in @($menuResultPath, $resultPath)) {
                    if (Test-Path -LiteralPath $path -PathType Leaf) { Write-Output (Get-Content -LiteralPath $path -Raw) }
                }
                foreach ($path in @($menuResultPath, $resultPath)) {
                    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-Output $log; throw "Missing settings smoke report: $path" }
                    $report = Get-Content -LiteralPath $path -Raw
                    if ($report -notmatch 'SUMMARY: (\d+) checks, 0 failed') { Write-Output $log; throw 'Native settings smoke failed.' }
                    $totalChecks += [int]$Matches[1]
                }
                if ($log -match '(?m)^ERRO|\bError:|Script:.*(not valid|error)') { Write-Output $log; throw 'Rainmeter logged a settings error.' }
                $savedIni = Get-Content -LiteralPath $iniPath -Raw
                foreach ($expected in @(@('Parallax\Chronometer', '1'), @('Parallax\Chronometer\Settings', '0'))) {
                    $sectionPattern = '(?ms)^\[' + [regex]::Escape($expected[0]) + '\]\s*\r?\n(.*?)(?=^\[|\z)'
                    $section = [regex]::Match($savedIni, $sectionPattern).Groups[1].Value
                    if ($section -notmatch ('(?m)^Active=' + $expected[1] + '\s*$')) { throw "Unexpected saved active state for $($expected[0])." }
                    $totalChecks++
                }
                $caseCount++
            }
        }
    }
    $version = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
    Write-Output "Rainmeter $version : $caseCount settings cases passed; $totalChecks checks; no Rainmeter errors."
}
finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $testProcess.WaitForExit(5000) | Out-Null }
        $testProcess.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        $expectedRuntime = [IO.Path]::GetFullPath($runtimeRoot) + '\'
        if (-not $resolvedRun.StartsWith($expectedRuntime, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedRun) -notmatch '^run-[a-f0-9]{32}$' -or
            ((Get-Item -LiteralPath $runRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing cleanup outside exact generated settings smoke run.'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
