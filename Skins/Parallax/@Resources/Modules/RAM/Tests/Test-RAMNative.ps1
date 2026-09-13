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
    [switch]$FixtureOnly,
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
foreach ($relative in @('RAM\RAM.ini', 'RAM\Settings\Settings.ini', '@Resources\Defaults.inc', '@Resources\User\Settings.inc', '@Resources\User\RAM.inc', '@Resources\Geometry.inc', '@Resources\Styles.inc', '@Resources\UtilitySettingsNote.inc', '@Resources\Modules\RAM\Measures.inc', '@Resources\Modules\RAM\Meters.inc', '@Resources\Modules\RAM\InfoMeters.inc', '@Resources\Modules\RAM\Info.lua', '@Resources\Modules\RAM\InfoModel.lua', '@Resources\Modules\RAM\MemoryInfo.ps1.txt', '@Resources\Modules\RAM\SettingsMeters.inc', '@Resources\Modules\RAM\Settings.lua', '@Resources\Modules\RAM\Display.lua')) {
    $path = Join-Path $sourceRoot $relative
    Assert-RegularPath $path
    $sources[$relative] = [IO.File]::ReadAllText($path)
}
foreach ($relative in '@Resources\Modules\RAM\ProcessMeters.inc', '@Resources\Modules\RAM\Process.lua', '@Resources\Modules\RAM\ProcessModel.lua', '@Resources\Modules\RAM\PageFile.lua', '@Resources\Modules\RAM\PageFileModel.lua') {
    $path = Join-Path $sourceRoot $relative
    Assert-RegularPath $path
    $sources[$relative] = [IO.File]::ReadAllText($path)
}
$harnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'NativeSmoke.lua'))
$settingsHarnessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SettingsNative.lua'))
$modelTestsSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'InfoModelTests.lua'))
$processModelTestsSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ProcessModelTests.lua'))
$pageModelTestsSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PageFileModelTests.lua'))
$pageFixtureSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PageFileFixture.lua'))
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
$meterSource = $sources['@Resources\Modules\RAM\Meters.inc'] + "`n" + $sources['@Resources\Modules\RAM\InfoMeters.inc'] + "`n" + $sources['@Resources\Modules\RAM\ProcessMeters.inc']
$meterNames = @([regex]::Matches($meterSource, '(?m)^\[(Meter[^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
if ($meterNames.Count -eq 0) { throw 'No RAM meters found for native validation.' }
$settingsMeterSource = $sources['RAM\Settings\Settings.ini'] + "`n" + $sources['@Resources\UtilitySettingsNote.inc'] + "`n" + $sources['@Resources\Modules\RAM\SettingsMeters.inc']
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
$fixtureDuplicate = 'RAMINFO2|16000000000,26,3200,0,4D6963726F6E;16000000000,26,3200,0,4D6963726F6E'
$fixtureMixed = $fixtureDuplicate + ';8000000000,34,4800,0,4B696E6773746F6E'
$longManufacturer = ([Text.Encoding]::UTF8.GetBytes('Example Memory Manufacturing Company') | ForEach-Object { $_.ToString('X2') }) -join ''
$fixtureLong = "RAMINFO2|16000000000,26,3200,0,$longManufacturer;8000000000,34,4800,0,4B696E6773746F6E;32000000000,34,5600,0,53616D73756E67"
$pageToken = '0123456789abcdef0123456789abcdef'
$pageNow = 2000000000
$pageFixtures = @(
    "RAM_PAGE|1|$pageToken|1|$pageNow|OK|3000000000|12000000000|2",
    "RAM_PAGE|1|$pageToken|1|$pageNow|OK|0|4000000000|1",
    "RAM_PAGE|1|$pageToken|1|$pageNow|NONE|0|0|0",
    "RAM_PAGE|1|$pageToken|1|$pageNow|UNAVAILABLE|?|?|?",
    "RAM_PAGE|1|$pageToken|1|$pageNow|UNSUPPORTED|?|?|?",
    "RAM_PAGE|1|$pageToken|1|1999999991|OK|3000000000|12000000000|2"
)
$caseSpecs = @()
if ($FixtureOnly) {
    # Six focused copies cover actual wrapping and both saved column modes.
    # Every metadata provider is replaced with Calc before any process starts.
    $caseSpecs = @(
        @{ Width=180; Columns=1; Scale='0.75'; Fixture=$fixtureLong; Groups=3 },
        @{ Width=220; Columns=2; Scale='0.75'; Fixture=$fixtureDuplicate; Groups=1 },
        @{ Width=180; Columns=2; Scale='1'; Fixture=$fixtureMixed; Groups=2 },
        @{ Width=220; Columns=1; Scale='1'; Fixture=$fixtureDuplicate; Groups=1 },
        @{ Width=180; Columns=1; Scale='2'; Fixture=$fixtureMixed; Groups=2 },
        @{ Width=220; Columns=2; Scale='2'; Fixture=$fixtureLong; Groups=3 }
    )
} else {
    foreach ($width in 180,200) {
        foreach ($columnCount in 1,2) {
            foreach ($suiteScale in '0.75','1','1.25','1.5','2') {
                $caseSpecs += @{ Width=$width; Columns=$columnCount; Scale=$suiteScale; Fixture=''; Groups=-1 }
            }
        }
    }
}
foreach ($spec in $caseSpecs) {
            $columnWidth = $spec.Width
            $columns = $spec.Columns
            $scale = $spec.Scale
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
            $overrides = [ordered]@{ ColumnWidth=$columnWidth; Columns=$columns; Scale=$scale; MetricsInterval=1000; RAMUseMiB=$useMiB; RAMDecimals=2; RAMPercentDecimals=2; RAMShowBar=1; RAMShowPageBar=1; RAMShowHistory=1; RAMTitle='RAM physical memory with a deliberately long clipped title' }
            # Distinct local colors make semantic theme inheritance observable.
            $overrides['TitleTextColor'] = '231,221,211'
            $overrides['HeaderTextColor'] = '131,141,151'
            $overrides['TextColor'] = '211,221,231'
            $overrides['AccentColor'] = '151,161,171'
            $overrides['AccentColor2'] = '181,191,201'
            $border = @(0,1,4)[($caseIndex-1)%3]
            $overrides['BorderThickness'] = $border
            $barThickness = @('1','6','12','6.25','12','1')[($caseIndex-1)%6]
            $overrides['DataBarThickness'] = $barThickness
            $overrides['TableHeaderBorderThickness'] = $border
            $overrides['DividerThickness'] = if ($caseIndex%2 -eq 0) { 4 } else { 0 }
            $typography = if ($caseIndex % 2 -eq 0) { 'Maximum' } else { 'Default' }
            if ($typography -eq 'Maximum') {
                $overrides['TitleFontSize'] = 12
                $overrides['HeaderFontSize'] = 10
                $overrides['FontSize'] = 10
            }
            # Exercise the previous saved height as well as the new default.
            if ($columns -eq 2 -or $FixtureOnly) { $overrides['PanelHeight'] = 170 }
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
            $processModelTestsPath = Join-Path $caseRoot 'ProcessModelTests.lua'
            Write-RunText $processModelTestsPath $processModelTestsSource
            $pageModelTestsPath = Join-Path $caseRoot 'PageFileModelTests.lua'
            Write-RunText $pageModelTestsPath $pageModelTestsSource
            $pageFixturePath = Join-Path $caseRoot 'PageFileFixture.lua'
            Write-RunText $pageFixturePath $pageFixtureSource
            $entry = $copiedSources['RAM\RAM.ini']
            # PAGE always uses a cached test adapter in this display harness.
            # Its actual resident provider is covered by its own bounded tests.
            $entry = $entry.Replace('[!CommandMeasure MeasureRAMPageView "Start()"]', '')
            $infoMode = 'Live'
            $infoFixture = ''
            $copiedMeasures = $copiedSources['@Resources\Modules\RAM\Measures.inc']
            $pageFixture = $pageFixtures[($caseIndex-1)%6]
            foreach ($helper in 'Bootstrap','Host') {
                $pattern = '(?ms)^\[MeasureRAMPage' + $helper + '\]\r?\n.*?(?=^\[|\z)'
                if ([regex]::Matches($copiedMeasures,$pattern).Count -ne 1) { throw "Expected one PAGE $helper section." }
                $replacement = "[MeasureRAMPage$helper]`nMeasure=Calc`nFormula=0`nUpdateDivider=-1`n`n"
                $copiedMeasures = [regex]::Replace($copiedMeasures,$pattern,[Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
            }
            $pattern = '(?ms)^\[MeasureRAMPageView\]\r?\n.*?(?=^\[|\z)'
            if ([regex]::Matches($copiedMeasures,$pattern).Count -ne 1) { throw 'Expected one PAGE view section.' }
            $replacement = "[MeasureRAMPageView]`nMeasure=Script`nScriptFile=$pageFixturePath`nFixtureWire=$pageFixture`nFixtureToken=$pageToken`nFixtureNow=$pageNow`nUpdateDivider=1`n`n"
            $copiedMeasures = [regex]::Replace($copiedMeasures,$pattern,[Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
            $processMode = 'Live'
            $expectedProcesses = -1
            if ($FixtureOnly -or $caseIndex -ne 1) {
                # Only the first case launches the actual metadata query. The
                # remaining copied skins exercise honest states without a
                # burst of 20 PowerShell/WMI processes on the test machine.
                $infoMode = 'Fixture'
                $infoFixture = $fixtureDuplicate
                if ($FixtureOnly) { $infoFixture = $spec.Fixture }
                else {
                    if ($caseIndex -eq 3) { $infoFixture = $fixtureMixed }
                    if ($caseIndex -eq 4) { $infoFixture = 'RAMINFO2|0,0,0,0,556E6B6E6F776E' }
                    if ($caseIndex -eq 5) { $infoFixture = $fixtureDuplicate + ';0,0,0,0,556E6B6E6F776E' }
                    if ($caseIndex -eq 19) { $infoFixture = 'UNAVAILABLE' }
                    if ($caseIndex -eq 20) { $infoMode = 'Timeout'; $infoFixture = '' }
                }
                $status = if ($infoMode -eq 'Timeout') { 0 } else { 1 }
                $replacement = "[MeasureRAMInfo]`nMeasure=Calc`nFormula=$status`nSubstitute=`"$status`":`"$infoFixture`"`nUpdateDivider=1`n`n"
                $pattern = '(?ms)^\[MeasureRAMInfo\]\r?\n.*?(?=^\[|\z)'
                if ([regex]::Matches($sources['@Resources\Modules\RAM\Measures.inc'], $pattern).Count -ne 1) { throw 'Expected exactly one hardware provider section.' }
                $copiedMeasures = [regex]::Replace($copiedMeasures, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
                if ($FixtureOnly -and $copiedMeasures -match '(?im)^Plugin=RunCommand\s*$') { throw 'Focused fixture mode must contain no executable metadata provider.' }
                $startAction = if ($infoMode -eq 'Timeout') { '' } else { '[!CommandMeasure MeasureRAMInfoView "Complete()"]' }
                $entry = Set-IniVariable $entry 'OnRefreshAction' $startAction
            }
            if ($FixtureOnly -or $caseIndex -ne 1) {
                $processMode = 'Fixture'
                $expectedProcesses = if (($FixtureOnly -and $caseIndex -eq 6) -or $caseIndex -eq 19) { 0 } else { 5 }
                $processNames = @('Fixture Browser with a deliberately long process group name','Fixture Renderer','Fixture Editor','Fixture Explorer','Fixture Service')
                $processBytes = @(4500000000,3000000000,1500000000,750000000,125000000)
                foreach ($rank in 1..5) {
                    $processName = if ($expectedProcesses) { $processNames[$rank-1] } else { '' }
                    $bytes = if ($expectedProcesses) { $processBytes[$rank-1] } else { 0 }
                    $pattern = '(?ms)^\[MeasureRAMProcess' + $rank + '\]\r?\n.*?(?=^\[|\z)'
                    if ([regex]::Matches($copiedMeasures, $pattern).Count -ne 1) { throw "Expected exactly one process rank $rank." }
                    $replacement = "[MeasureRAMProcess$rank]`nMeasure=Calc`nFormula=$bytes`nSubstitute=`"$bytes`":`"$processName`"`nUpdateDivider=1`n`n"
                    $copiedMeasures = [regex]::Replace($copiedMeasures, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
                }
            }
            if ($FixtureOnly -and $copiedMeasures -match '(?im)^Plugin=(RunCommand|UsageMonitor)\s*$') { throw 'Focused fixtures must contain no inventory/PAGE helper or process category worker.' }
            if ($entry -match '!CommandMeasure MeasureRAMPage(?:View "Start\(\)"|Bootstrap|Host)') { throw 'Copied entry must not start a PAGE helper.' }
            Write-RunText (Join-Path $caseRoot '@Resources\Modules\RAM\Measures.inc') $copiedMeasures
            $entry += "`n[MeasureRAMNativeSmoke]`nMeasure=Script`nScriptFile=$harnessPath`nResultPath=$resultPath`nExpectedWidth=$columnWidth`nExpectedColumns=$columns`nExpectedScale=$scale`nExpectedDataBarThickness=$barThickness`nExpectedGroups=$($spec.Groups)`nExpectedProcesses=$expectedProcesses`nProcessMode=$processMode`nMeterNames=$($meterNames -join '|')`nHoverAction=$($hoverActions['MouseOverAction'])`nLeaveAction=$($hoverActions['MouseLeaveAction'])`nInfoMode=$infoMode`nInfoFixture=$infoFixture`nModelTestsPath=$modelTestsPath`nProcessModelTestsPath=$processModelTestsPath`nSettingsConfig=$caseName\RAM\Settings`nUpdateDivider=1`n"
            $entry += "PageFixture=$pageFixture`nPageToken=$pageToken`nPageNow=$pageNow`nPageModelTestsPath=$pageModelTestsPath`n"
            $entry += $fontProbeSource
            Write-RunText (Join-Path $caseRoot 'RAM\RAM.ini') $entry
            $settingsHarnessPath = Join-Path $caseRoot 'SettingsNative.lua'
            Write-RunText $settingsHarnessPath $settingsHarnessSource
            $failurePath = Join-Path $runRoot ($caseName + '.utility-failure.txt')
            $settingsEntry = $copiedSources['RAM\Settings\Settings.ini']
            $inputPattern = '(?ms)^\[MeasureRAMSettingsInput\]\r?\n.*?(?=^\[|\z)'
            if ([regex]::Matches($settingsEntry,$inputPattern).Count -ne 1) { throw 'Expected one settings numeric-input helper.' }
            $inputReplacement = "[MeasureRAMSettingsInput]`nMeasure=Calc`nFormula=0`nUpdateDivider=-1`n`n"
            $settingsEntry = [regex]::Replace($settingsEntry,$inputPattern,[Text.RegularExpressions.MatchEvaluator]{ param($match) $inputReplacement })
            if ($settingsEntry -match '(?im)^Plugin=(RunCommand|UsageMonitor)\s*$') { throw 'Copied Settings must contain no executable helper or telemetry worker.' }
            $settingsEntry = $settingsEntry.Replace('[Rainmeter]', ('[Rainmeter]' + "`n" + 'OnRefreshAction=[!CommandMeasure MeasureRAMSettingsSmoke "Opened()"]'))
            $settingsEntry += "`n[MeasureRAMSettingsSmoke]`nMeasure=Script`nScriptFile=$settingsHarnessPath`nParentConfig=$caseName\RAM`nFailurePath=$failurePath`nExpectedWidth=$columnWidth`nExpectedScale=$scale`nMeterNames=$($settingsMeterNames -join '|')`nUpdateDivider=-1`n"
            $settingsEntry += $fontProbeSource
            Write-RunText (Join-Path $caseRoot 'RAM\Settings\Settings.ini') $settingsEntry
            $ini += "`n[$caseName\RAM]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
            $ini += "`n[$caseName\RAM\Settings]`nActive=0`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
            $cases.Add([pscustomobject]@{ Case=$caseName; ColumnWidth=$columnWidth; Columns=$columns; Scale=$scale; Typography=$typography; BorderThickness=$border; DataBarThickness=$barThickness; UseMiB=$useMiB; HardwareMode=$infoMode; ProcessMode=$processMode; PageMode='Fixture'; ExpectedProcesses=$expectedProcesses; Result=$resultPath })
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
    Write-Output "Prepared $($cases.Count) RAM cases without launching Rainmeter: $runRoot"
    [pscustomobject]@{ RunRoot=$runRoot; PreparedOnly=$true; Cases=$cases.Count }
    return
}

try {
    if ($FixtureOnly -and @($cases | Where-Object { $_.HardwareMode -ne 'Fixture' -or $_.ProcessMode -ne 'Fixture' }).Count) { throw 'Focused mode contains a non-fixture metadata or process source; refusing launch.' }
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
        FixtureOnly=[bool]$FixtureOnly
        HardwareQueries=$(if ($FixtureOnly) { 0 } else { 1 }); HardwareLiveReport=$(if ($FixtureOnly) { $null } else { $reports[0] })
        ProcessProviderCases=$(if ($FixtureOnly) { 0 } else { 1 })
        PageFileHelpers=0
        SettingsInputHelpers=0
        TypographyCases='Alternating default and maximum (title 12 pt, header 10 pt, body 10 pt)'
        BorderCases='Border thickness 0/1/4; divider thickness 0/4 (RAM Settings section dividers; no main RAM divider meters)'
        DataBarCases='Data-bar thickness 1/6/6.25/12 logical pixels; native height and row clearance checked'
        Limitations='Native RAM and dedicated Settings bounds, preserved requested RAM height, memory bindings, grouped metadata summaries, measured wrapping and height changes, hover/gear/control actions, cross-config immediate updates, scratch-file persistence, utility close/reopen persistence and history-count continuity. HardwareQueries records whether metadata is entirely fixtures. No physical pointer delivery, screenshot/glyph quality, firmware accuracy, performance, full-history, full-RAM reload persistence or mixed-DPI assertion.'
    }
    Write-RunText (Join-Path $runRoot 'summary.json') ($summary | ConvertTo-Json -Depth 4)
    if ($errors.Count) { $errors | Write-Output; throw "Native RAM smoke logged errors. Inspect $runRoot" }
    if ($failures.Count) { throw "$($failures.Count) native RAM cases failed. Inspect $runRoot" }
    Write-Output "All $($cases.Count) native RAM cases passed. Evidence: $runRoot"
    [pscustomobject]@{ RunRoot=$runRoot; Cases=$cases.Count; Passed=$true }
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}
