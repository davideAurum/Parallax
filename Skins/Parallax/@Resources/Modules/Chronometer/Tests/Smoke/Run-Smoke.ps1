[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(8, 30)][int]$TimeoutSeconds = 15,
    [int[]]$Columns = @(1, 2),
    [int[]]$ColumnWidths = @(180, 200),
    [double[]]$Scales = @(0.75, 1, 1.25, 1.5, 2),
    [ValidateSet('Default', 'Edge')][string[]]$Fixtures = @('Default'),
    [ValidateRange(0, 15)][int[]]$VisibilityMasks = @(15),
    [switch]$LayoutOnly,
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
$summaries = @()
$totalChecks = 0

function Assert-WithinRun([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if ($resolved -ne $runRoot -and -not $resolved.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing operation outside generated smoke run: $resolved"
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

if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed by this runner.' }
if ((Test-Path -LiteralPath $runtimeRoot) -and ((Get-Item -LiteralPath $runtimeRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Smoke runtime root must not be a junction or symbolic link.'
}
foreach ($column in $Columns) { if ($column -notin @(1, 2)) { throw 'Columns must be 1 or 2.' } }
foreach ($width in $ColumnWidths) { if ($width -notin @(180, 200, 240, 280, 320)) { throw 'ColumnWidth must be 180, 200, 240, 280 or 320.' } }
foreach ($scale in $Scales) { if ($scale -notin @(0.75, 1, 1.25, 1.5, 2)) { throw 'Scale must be 0.75, 1, 1.25, 1.5 or 2.' } }
$productionIni = Get-Content -LiteralPath (Join-Path $suiteRoot 'Chronometer\Chronometer.ini') -Raw
$meterNames = @([regex]::Matches($productionIni, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { $_.Groups[1].Value }) -join '|'
$rainmeterSection = [regex]::Match($productionIni, '(?ms)^\[Rainmeter\]\s*\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
$hoverAction = [regex]::Match($rainmeterSection, '(?m)^MouseOverAction=(.+)$').Groups[1].Value.Trim()
$leaveAction = [regex]::Match($rainmeterSection, '(?m)^MouseLeaveAction=(.+)$').Groups[1].Value.Trim()
if (-not $hoverAction -or -not $leaveAction) { throw 'Production Chronometer must define both skin hover actions.' }
$uptimeSection = [regex]::Match($productionIni, '(?ms)^\[MeasureUptime\]\s*\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
$uptimeFormat = [regex]::Match($uptimeSection, '(?m)^Format=(.+)$').Groups[1].Value.Trim()
if (-not $uptimeFormat) { throw 'Production Chronometer must define its uptime format.' }

try {
    foreach ($visibilityMask in $VisibilityMasks) {
    foreach ($fixture in $Fixtures) {
        foreach ($width in $ColumnWidths) {
            foreach ($column in $Columns) {
                foreach ($scale in $Scales) {
                    $scaleText = $scale.ToString([Globalization.CultureInfo]::InvariantCulture)
                    $caseRoot = Join-Path $runRoot ("$fixture-v$visibilityMask-w$width-c$column-s$scaleText")
                    $skinRoot = Join-Path $caseRoot 'Skins'
                    $skinDirectory = Join-Path $skinRoot 'Parallax\Chronometer'
                    $resources = Join-Path $skinRoot 'Parallax\@Resources'
                    $scripts = Join-Path $resources 'Modules\Chronometer'
                    foreach ($directory in @($skinDirectory, $scripts, (Join-Path $resources 'User'), (Join-Path $caseRoot 'Layouts'), (Join-Path $caseRoot 'Plugins'), (Join-Path $caseRoot 'Addons'))) {
                        Assert-WithinRun $directory
                        New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    }
                    foreach ($name in @('Defaults.inc', 'Geometry.inc', 'Styles.inc')) {
                        Copy-IntoRun (Join-Path $resourceRoot $name) (Join-Path $resources $name)
                    }
                    # Stage only already-bundled fonts. Never install or download fonts.
                    $sourceFonts = Join-Path $resourceRoot 'Fonts'
                    if (Test-Path -LiteralPath $sourceFonts -PathType Container) {
                        $targetFonts = Join-Path $resources 'Fonts'
                        Assert-WithinRun $targetFonts
                        New-Item -ItemType Directory -Path $targetFonts -Force | Out-Null
                        foreach ($font in Get-ChildItem -LiteralPath $sourceFonts -File) {
                            if ($font.Extension -in @('.ttf', '.otf')) {
                                Copy-IntoRun $font.FullName (Join-Path $targetFonts $font.Name)
                            }
                        }
                    }
                    foreach ($name in @('Core.lua', 'Store.lua', 'Chronometer.lua', 'Event.lua', 'EventCore.lua', 'Defaults.inc', 'Layout.inc', 'Styles.inc')) {
                        Copy-IntoRun (Join-Path $moduleRoot $name) (Join-Path $scripts $name)
                    }
                    Copy-IntoRun (Join-Path $smokeRoot 'Smoke.lua') (Join-Path $scripts 'Smoke.lua')
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
                    # Keep the clock assertion deterministic when the saved user preference changes.
                    $moduleSettings = Set-FixtureVariable $moduleSettings 'ChronometerClockFormat' '%H:%M:%S'
                    $visibilityBit = 1
                    foreach ($section in @('Clock', 'Uptime', 'Event', 'Timers')) {
                        $visible = if ($visibilityMask -band $visibilityBit) { '1' } else { '0' }
                        $moduleSettings = Set-FixtureVariable $moduleSettings ('ChronometerShow' + $section) $visible
                        $visibilityBit *= 2
                    }
                    if ($fixture -eq 'Edge') {
                        $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Name=.*$', 'ChronometerList1Name=An intentionally long countdown collection name that must clip')
                        $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Timer1Label=.*$', 'ChronometerList1Timer1Label=An intentionally long seven-day timer label that must clip')
                        $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Timer1Seconds=.*$', 'ChronometerList1Timer1Seconds=604800')
                        $moduleSettings = [regex]::Replace($moduleSettings, '(?m)^ChronometerList1Timer2Seconds=.*$', 'ChronometerList1Timer2Seconds=invalid')
                    }
                    Write-Utf8 (Join-Path $resources 'User\Chronometer.inc') $moduleSettings
                    $resultPath = Join-Path $caseRoot 'results.txt'
                    Write-Utf8 (Join-Path $skinDirectory 'Chronometer.ini') ($productionIni + "`n" + @"
[MeasureSmokeUptimeFormat]
Measure=Uptime
Format=$uptimeFormat
SecondsValue=0
DynamicVariables=1
UpdateDivider=-1

[MeasureSmoke]
Measure=Script
ScriptFile=#@#Modules\Chronometer\Smoke.lua
ResultPath=$resultPath
MeterNames=$meterNames
Fixture=$fixture
ExpectedColumns=$column
ExpectedColumnWidth=$width
ExpectedScale=$scaleText
ExpectedVisibilityMask=$visibilityMask
LayoutOnly=$([int]$LayoutOnly.IsPresent)
ExpectedTitleFontSize=$TitleFontSize
ExpectedHeaderFontSize=$HeaderFontSize
ExpectedFontSize=$FontSize
HoverAction=$hoverAction
LeaveAction=$leaveAction

[MeterSmokeLabelProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeListProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeTitleProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeDateProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeFooterProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeEventLabelProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeEventProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeUptimeProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeClockProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeTimeProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeToggleProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0

[MeterSmokeStateProbe]
Meter=String
FontColor=0,0,0,0
DynamicVariables=1
X=0
Y=0
"@)
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
"@
                    Write-Utf8 (Join-Path $caseRoot 'Rainmeter.data') "[Rainmeter]`n"
                    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
                    Write-Output "Native smoke: Fixture=$fixture Visibility=$visibilityMask ColumnWidth=$width Columns=$column Scale=$scaleText"
                    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $caseRoot -WindowStyle Hidden -PassThru
                    if (-not $testProcess.WaitForExit($TimeoutSeconds * 1000)) {
                        Stop-Process -InputObject $testProcess -Force
                        $testProcess.WaitForExit(5000) | Out-Null
                        throw 'Isolated frontend smoke process timed out.'
                    }
                    $testProcess.Dispose()
                    $testProcess = $null
                    $logPath = Join-Path $caseRoot 'Rainmeter.log'
                    $log = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
                    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { Write-Output $log; throw 'Smoke result missing.' }
                    $result = Get-Content -LiteralPath $resultPath -Raw
                    Write-Output $result
                    if ($result -notmatch 'SUMMARY: (\d+) checks, 0 failed') { Write-Output $log; throw 'Native frontend smoke failed.' }
                    $totalChecks += [int]$Matches[1]
                    if ($log -match '(?m)^ERRO|\bError:|Script:.*(not valid|error)') { Write-Output $log; throw 'Rainmeter logged an error during frontend smoke.' }
                    $summaries += "Fixture=$fixture Visibility=$visibilityMask ColumnWidth=$width Columns=$column Scale=$scaleText : PASS; no Rainmeter error entries"
                }
            }
        }
    }
    }
    $version = (Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
    Write-Output "Rainmeter $version : $($summaries.Count) frontend cases passed; $totalChecks checks."
    Write-Output $summaries
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
            throw 'Refusing cleanup outside exact generated smoke run.'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
