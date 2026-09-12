#requires -Version 5.1
<#
Loads only copied RAM skins in an isolated instance of an existing Rainmeter.
All writes remain in Tests/.runtime/<unique run>; no live configuration is read
or changed. Test files and runtime evidence are excluded by suite staging.
This is a native smoke check, not a screenshot, accuracy, or performance test.
#>
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(10,60)][int]$TimeoutSeconds = 60,
    [switch]$PrepareOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$runtimeRoot = Join-Path $PSScriptRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('ram-native-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
$process = $null
if (-not $PrepareOnly -and -not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) {
    throw 'An existing Rainmeter installation is required. This test does not download or install it.'
}

function Assert-RegularPath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing a junction or symbolic link: $current"
            }
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent) { break }
        $current = $parent.FullName
    }
}
function Assert-RunPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -ne $runRoot -and -not $absolute.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Test destination escaped its unique runtime directory.'
    }
    Assert-RegularPath $absolute
}
function Write-RunText([string]$Path, [string]$Content) {
    Assert-RunPath $Path
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}
function Set-IniVariable([string]$Source, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
    if ([regex]::IsMatch($Source, $pattern)) {
        return [regex]::Replace($Source, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) "$Key=$Value" })
    }
    # The shipped user include is a single Variables section.
    return $Source.TrimEnd() + "`n$Key=$Value`n"
}

Assert-RegularPath $sourceRoot
Assert-RegularPath $PSScriptRoot
Assert-RunPath $runRoot
if (Test-Path -LiteralPath $runRoot) { throw 'Refusing to reuse a runtime directory.' }
$null = New-Item -ItemType Directory -Path $runRoot -Force
$sources = [ordered]@{}
foreach ($relative in @('RAM\RAM.ini', 'RAM\Settings\Settings.ini', '@Resources\Defaults.inc', '@Resources\User\Settings.inc', '@Resources\User\RAM.inc', '@Resources\Geometry.inc', '@Resources\Styles.inc', '@Resources\Modules\RAM\Measures.inc', '@Resources\Modules\RAM\Meters.inc', '@Resources\Modules\RAM\InfoMeters.inc', '@Resources\Modules\RAM\Info.lua', '@Resources\Modules\RAM\InfoModel.lua', '@Resources\Modules\RAM\MemoryInfo.ps1.txt', '@Resources\Modules\RAM\SettingsMeters.inc', '@Resources\Modules\RAM\Settings.lua', '@Resources\Modules\RAM\Display.lua')) {
    $path = Join-Path $sourceRoot $relative
    Assert-RegularPath $path
    $sources[$relative] = [IO.File]::ReadAllText($path)
}
$harnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'NativeSmoke.lua'))
$settingsHarnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SettingsNative.lua'))
$modelTestsSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'InfoModelTests.lua'))
$rainmeterSection = [regex]::Match($sources['RAM\RAM.ini'], '(?ms)^\[Rainmeter\]\s*\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
$hoverActions = [ordered]@{}
foreach ($actionName in 'MouseOverAction','MouseLeaveAction') {
    $action = [regex]::Match($rainmeterSection, '(?m)^' + $actionName + '=([^\r\n]+)').Groups[1].Value
    # Exercise the production actions, but never launch programs or dispatch
    # unrelated bangs if this source changes in the future.
    if ($action -notmatch '^\[!CommandMeasure MeasureRAMSettings "Hover\([01]\)"\]$') {
        throw "Missing or unsupported RAM hover action: $actionName"
    }
    $hoverActions[$actionName] = $action
}
$meterSource = $sources['@Resources\Modules\RAM\Meters.inc'] + "`n" + $sources['@Resources\Modules\RAM\InfoMeters.inc']
$meterNames = @([regex]::Matches($meterSource, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
if ($meterNames.Count -eq 0) { throw 'No RAM meters found for native validation.' }
$settingsMeterSource = $sources['RAM\Settings\Settings.ini'] + "`n" + $sources['@Resources\Modules\RAM\SettingsMeters.inc']
$settingsMeterNames = @([regex]::Matches($settingsMeterSource, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
if ($settingsMeterNames.Count -eq 0) { throw 'No dedicated settings meters found.' }
$fontProbeSource = @'

; Test-only unbounded transparent String meters measure real font line height.
; The probes remain inside the skin and do not change the visible design.
[MeterRAMProbeTitle]
Meter=String
X=#ContentX#
Y=#Inset#
FontFace=#FontFace#
FontSize=(#TitleFontSize#*#Scale#)
FontWeight=600
AntiAlias=1
Text=Agpqy
FontColor=0,0,0,0
UpdateDivider=-1

[MeterRAMProbeHeader]
Meter=String
X=#ContentX#
Y=#Inset#
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
AntiAlias=1
Text=Agpqy
FontColor=0,0,0,0
UpdateDivider=-1

[MeterRAMProbeBody]
Meter=String
X=#ContentX#
Y=#Inset#
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
AntiAlias=1
Text=Agpqy
FontColor=0,0,0,0
UpdateDivider=-1
'@
$fonts = @()
$fontRoot = Join-Path $sourceRoot '@Resources\Fonts'
if (Test-Path -LiteralPath $fontRoot) {
    Assert-RegularPath $fontRoot
    $fonts = @(Get-ChildItem -LiteralPath $fontRoot -File | Where-Object { $_.Extension -in '.ttf','.otf' })
    foreach ($font in $fonts) { Assert-RegularPath $font.FullName }
}
$skinRoot = Join-Path $runRoot 'Skins'
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$ini = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = [Collections.Generic.List[object]]::new()
$caseIndex = 0
foreach ($columnWidth in 180,200) {
    foreach ($columns in 1,2) {
        foreach ($scale in '0.75','1','1.25','1.5','2') {
            $caseIndex++
            $caseName = 'RAMNative{0:D2}' -f $caseIndex
            $caseRoot = Join-Path $skinRoot $caseName
            $copiedSources = @{}
            foreach ($relative in $sources.Keys) {
                # Scope preference broadcasts and the production gear to this
                # copied case so no other test or live config can be targeted.
                $copiedSources[$relative] = $sources[$relative].Replace('ParallaxRAMApply', ($caseName + 'Apply')).Replace('ParallaxRAM', $caseName).Replace('"Parallax\RAM\Settings"', ('"' + $caseName + '\RAM\Settings"'))
                Write-RunText (Join-Path $caseRoot $relative) $copiedSources[$relative]
            }
            # Alternate unit modes; exercise two-decimal values and long titles.
            $useMiB = ($caseIndex - 1) % 2
            $user = $sources['@Resources\User\RAM.inc']
            $overrides = [ordered]@{ ColumnWidth=$columnWidth; Columns=$columns; Scale=$scale; MetricsInterval=1000; RAMUseMiB=$useMiB; RAMDecimals=2; RAMPercentDecimals=2; RAMShowBar=1; RAMShowHistory=1; RAMTitle='RAM physical memory with a deliberately long clipped title' }
            # Distinct local colors make semantic theme inheritance observable.
            $overrides['TitleTextColor'] = '231,221,211'
            $overrides['HeaderTextColor'] = '131,141,151'
            $overrides['TextColor'] = '211,221,231'
            $overrides['AccentColor'] = '151,161,171'
            $overrides['AccentColor2'] = '181,191,201'
            $border = @(0,1,4)[($caseIndex-1)%3]
            $overrides['BorderThickness'] = $border
            $overrides['DividerThickness'] = if ($caseIndex%2 -eq 0) { 4 } else { 0 }
            $typography = if ($caseIndex % 2 -eq 0) { 'Maximum' } else { 'Default' }
            if ($typography -eq 'Maximum') {
                $overrides['TitleFontSize'] = 12
                $overrides['HeaderFontSize'] = 10
                $overrides['FontSize'] = 10
            }
            # Exercise the previous saved height as well as the new default.
            if ($columns -eq 2) { $overrides['PanelHeight'] = 170 }
            foreach ($key in $overrides.Keys) { $user = Set-IniVariable $user $key ([string]$overrides[$key]) }
            Write-RunText (Join-Path $caseRoot '@Resources\User\RAM.inc') $user
            foreach ($font in $fonts) {
                $destination = Join-Path $caseRoot ('@Resources\Fonts\' + $font.Name)
                Assert-RunPath $destination
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
                Copy-Item -LiteralPath $font.FullName -Destination $destination
            }
            $resultPath = Join-Path $runRoot ($caseName + '.txt')
            $harnessPath = Join-Path $caseRoot 'NativeSmoke.lua'
            Write-RunText $harnessPath $harnessSource
            $modelTestsPath = Join-Path $caseRoot 'InfoModelTests.lua'
            Write-RunText $modelTestsPath $modelTestsSource
            $entry = $copiedSources['RAM\RAM.ini']
            $infoMode = 'Live'
            $infoFixture = ''
            if ($caseIndex -ne 1) {
                # Only the first case launches the actual metadata query. The
                # remaining copied skins exercise honest states without a
                # burst of 20 PowerShell/WMI processes on the test machine.
                $infoMode = 'Fixture'
                $infoFixture = 'RAMINFO1|4|8589934592,26,3200,8;8589934592,26,3200,8'
                if ($caseIndex -eq 3) { $infoFixture = 'RAMINFO1|4|8589934592,26,3200,8;8589934592,34,4800,12' }
                if ($caseIndex -eq 4) { $infoFixture = 'RAMINFO1|0|0,0,0,0' }
                if ($caseIndex -eq 5) { $infoFixture = 'RAMINFO1|4|8589934592,26,3200,8;0,0,0,0' }
                if ($caseIndex -eq 19) { $infoFixture = 'UNAVAILABLE' }
                if ($caseIndex -eq 20) { $infoMode = 'Timeout'; $infoFixture = '' }
                $status = if ($infoMode -eq 'Timeout') { 0 } else { 1 }
                $replacement = "[MeasureRAMInfo]`nMeasure=Calc`nFormula=$status`nSubstitute=`"$status`":`"$infoFixture`"`nUpdateDivider=1`n`n"
                $pattern = '(?ms)^\[MeasureRAMInfo\]\r?\n.*?(?=^\[|\z)'
                if ([regex]::Matches($sources['@Resources\Modules\RAM\Measures.inc'], $pattern).Count -ne 1) { throw 'Expected exactly one hardware provider section.' }
                $copiedMeasures = [regex]::Replace($copiedSources['@Resources\Modules\RAM\Measures.inc'], $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
                Write-RunText (Join-Path $caseRoot '@Resources\Modules\RAM\Measures.inc') $copiedMeasures
                $startAction = if ($infoMode -eq 'Timeout') { '' } else { '[!CommandMeasure MeasureRAMInfoView "Complete()"]' }
                $entry = Set-IniVariable $entry 'OnRefreshAction' $startAction
            }
            $entry += "`n[MeasureRAMNativeSmoke]`nMeasure=Script`nScriptFile=$harnessPath`nResultPath=$resultPath`nExpectedWidth=$columnWidth`nExpectedColumns=$columns`nExpectedScale=$scale`nMeterNames=$($meterNames -join '|')`nHoverAction=$($hoverActions['MouseOverAction'])`nLeaveAction=$($hoverActions['MouseLeaveAction'])`nInfoMode=$infoMode`nInfoFixture=$infoFixture`nModelTestsPath=$modelTestsPath`nSettingsConfig=$caseName\RAM\Settings`nUpdateDivider=1`n"
            $entry += $fontProbeSource
            Write-RunText (Join-Path $caseRoot 'RAM\RAM.ini') $entry
            $settingsHarnessPath = Join-Path $caseRoot 'SettingsNative.lua'
            Write-RunText $settingsHarnessPath $settingsHarnessSource
            $failurePath = Join-Path $runRoot ($caseName + '.utility-failure.txt')
            $settingsEntry = $copiedSources['RAM\Settings\Settings.ini']
            $settingsEntry = $settingsEntry.Replace('[Rainmeter]', ('[Rainmeter]' + "`n" + 'OnRefreshAction=[!CommandMeasure MeasureRAMSettingsSmoke "Opened()"]'))
            $settingsEntry += "`n[MeasureRAMSettingsSmoke]`nMeasure=Script`nScriptFile=$settingsHarnessPath`nParentConfig=$caseName\RAM`nFailurePath=$failurePath`nExpectedWidth=$columnWidth`nExpectedScale=$scale`nMeterNames=$($settingsMeterNames -join '|')`nUpdateDivider=-1`n"
            $settingsEntry += $fontProbeSource
            Write-RunText (Join-Path $caseRoot 'RAM\Settings\Settings.ini') $settingsEntry
            $ini += "`n[$caseName\RAM]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
            $ini += "`n[$caseName\RAM\Settings]`nActive=0`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
            $cases.Add([pscustomobject]@{ Case=$caseName; ColumnWidth=$columnWidth; Columns=$columns; Scale=$scale; Typography=$typography; BorderThickness=$border; UseMiB=$useMiB; HardwareMode=$infoMode; Result=$resultPath })
        }
    }
}
foreach ($directory in 'Layouts','Plugins','Addons') {
    $path = Join-Path $runRoot $directory
    Assert-RunPath $path
    $null = New-Item -ItemType Directory -Path $path
}
Write-RunText $iniPath $ini
Write-RunText (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-RunText (Join-Path $runRoot 'TEST-ONLY.txt') "Copied RAM smoke-test skins and native evidence. Never distribute this directory. No production source was changed.`n"
Write-RunText (Join-Path $runRoot 'cases.json') ($cases.ToArray() | ConvertTo-Json -Depth 3)
if ($PrepareOnly) {
    Write-Output "Prepared 20 RAM cases without launching Rainmeter: $runRoot"
    [pscustomobject]@{ RunRoot=$runRoot; PreparedOnly=$true; Cases=$cases.Count }
    return
}

try {
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    # An existing, absolute INI and SkinPath select a separate instance. Never
    # dispatch command-line bangs, which might target the user's instance.
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $missing = @($cases | Where-Object { -not (Test-Path -LiteralPath $_.Result -PathType Leaf) })
        if ($missing.Count -eq 0) { break }
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated Rainmeter exited before all reports. Inspect $runRoot" }
        Start-Sleep -Milliseconds 250
    }
    $missing = @($cases | Where-Object { -not (Test-Path -LiteralPath $_.Result -PathType Leaf) })
    if ($missing.Count) { throw "Native RAM smoke timed out; missing $($missing.Case -join ', '). Inspect $runRoot" }
    $reports = @($cases | ForEach-Object { Get-Content -LiteralPath $_.Result -Raw })
    $reports | Write-Output
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $errors = @()
    if (Test-Path -LiteralPath $logPath) { $errors = @(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' }) }
    $failures = @($reports | Where-Object { $_ -notmatch '^PASS:' })
    $summary = [ordered]@{
        CompletedUtc=[DateTime]::UtcNow.ToString('o'); Cases=$cases.Count; FailedCases=$failures.Count
        RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion
        ProcessId=$process.Id; LogErrors=$errors; Distributable=$false
        HardwareQueries=1; HardwareLiveReport=$reports[0]
        TypographyCases='10 default and 10 maximum (title 12 pt, header 10 pt, body 10 pt)'
        BorderCases='Border thickness 0/1/4; divider thickness 0/4 (RAM has no divider meters)'
        Limitations='Native RAM and dedicated Settings bounds, preserved old RAM height, memory bindings, hardware formatting/unknown/mixed/timeout states, hover/gear/control action execution, cross-config immediate updates, scratch-file persistence, utility close/reopen persistence and history-count continuity. One real firmware query; other metadata is explicitly test-only fixtures. No physical pointer delivery, screenshot/glyph quality, firmware accuracy, performance, full-history, full-RAM reload persistence or mixed-DPI assertion.'
    }
    Write-RunText (Join-Path $runRoot 'summary.json') ($summary | ConvertTo-Json -Depth 4)
    if ($errors.Count) { $errors | Write-Output; throw "Native RAM smoke logged errors. Inspect $runRoot" }
    if ($failures.Count) { throw "$($failures.Count) native RAM cases failed. Inspect $runRoot" }
    Write-Output "All 20 native RAM cases passed. Evidence: $runRoot"
    [pscustomobject]@{ RunRoot=$runRoot; Cases=$cases.Count; Passed=$true }
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
