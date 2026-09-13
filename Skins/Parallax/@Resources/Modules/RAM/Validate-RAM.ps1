#requires -Version 5.1
<#
Read-only module checks. Does not start Rainmeter or change its configuration.
Checks authored INI contracts, actual geometry expressions, and display units.
This is not a Rainmeter renderer, live telemetry test, or performance test.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$skinRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$checks = 0
function Assert-RAM([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Read-RAMIni([string]$Path) {
    $sections = @{}
    $sectionName = ''
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(';')) { continue }
        if ($trimmed -match '^\[(.+)\]$') {
            $sectionName = $Matches[1]
            Assert-RAM (-not $sections.ContainsKey($sectionName)) "Duplicate section in $Path : $sectionName"
            $sections[$sectionName] = @{}
        } elseif ($trimmed -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            Assert-RAM (-not $sections[$sectionName].ContainsKey($key)) "Duplicate key in $Path : $key"
            $sections[$sectionName][$key] = $value
        } else { throw "Unsupported INI syntax in $Path : $trimmed" }
    }
    return $sections
}
$entry = Read-RAMIni (Join-Path $skinRoot 'RAM\RAM.ini')
$settingsEntry = Read-RAMIni (Join-Path $skinRoot 'RAM\Settings\Settings.ini')
$defaults = Read-RAMIni (Join-Path $skinRoot '@Resources\Defaults.inc')
$globalUser = Read-RAMIni (Join-Path $skinRoot '@Resources\User\Settings.inc')
$user = Read-RAMIni (Join-Path $skinRoot '@Resources\User\RAM.inc')
$geometry = Read-RAMIni (Join-Path $skinRoot '@Resources\Geometry.inc')
$sharedStyles = Read-RAMIni (Join-Path $skinRoot '@Resources\Styles.inc')
$settingsNote = Read-RAMIni (Join-Path $skinRoot '@Resources\UtilitySettingsNote.inc')
$measures = Read-RAMIni (Join-Path $PSScriptRoot 'Measures.inc')
$meters = Read-RAMIni (Join-Path $PSScriptRoot 'Meters.inc')
$info = Read-RAMIni (Join-Path $PSScriptRoot 'InfoMeters.inc')
$processMeters = Read-RAMIni (Join-Path $PSScriptRoot 'ProcessMeters.inc')
$menu = Read-RAMIni (Join-Path $PSScriptRoot 'SettingsMeters.inc')
foreach ($layer in @($info, $processMeters)) {
    foreach ($name in $layer.Keys) {
        Assert-RAM (-not $meters.ContainsKey($name)) "Hardware/menu duplicates a meter or style: $name"
        $meters[$name] = $layer[$name]
    }
}
$variables = @{}
foreach ($layer in $entry, $defaults, $globalUser, $user, $geometry) {
    foreach ($key in $layer.Variables.Keys) {
        if ($key -notlike '@Include*') { $variables[$key] = $layer.Variables[$key] }
    }
}
Assert-RAM ($entry.Rainmeter.Group -eq 'Parallax | ParallaxRAM') 'Missing Parallax or RAM application group.'
Assert-RAM ($entry.Rainmeter.Update -eq '#MetricsInterval#') 'MetricsInterval is not the skin cadence.'
Assert-RAM ($entry.Rainmeter.DynamicWindowSize -eq '1') 'RAM window must adapt to the wrapped hardware summary.'
Assert-RAM ($entry.Rainmeter.ContextAction -eq '[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'Shared Settings action is incorrect.'
$expectedIncludes = @('#@#Defaults.inc', '#@#User\Settings.inc', '#@#User\RAM.inc', '#@#Geometry.inc', '#@#Styles.inc')
for ($i = 0; $i -lt $expectedIncludes.Count; $i++) {
    Assert-RAM ($entry.Variables[('@Include{0}' -f ($i + 1))] -eq $expectedIncludes[$i]) 'Shared include order changed.'
}
foreach ($key in $entry.Variables.Keys | Where-Object { $_ -like 'RAM*' -and $_ -ne 'RAMInfoHeight' }) {
    Assert-RAM ($user.Variables.ContainsKey($key)) "Module option $key has no preserved default."
}
foreach ($name in 'MeasureRAMUsed', 'MeasureRAMAvailable', 'MeasureRAMTotal') {
    Assert-RAM ($measures[$name].Measure -eq 'PhysicalMemory') "$name must use native PhysicalMemory."
    Assert-RAM ($measures[$name].UpdateDivider -eq '1') "$name does not sample at MetricsInterval."
    Assert-RAM (-not $measures[$name].ContainsKey('MaxValue')) "$name must retain its native normalization."
}
Assert-RAM ($measures.MeasureRAMAvailable.InvertMeasure -eq '1') 'Available must invert native physical memory.'
Assert-RAM ($measures.MeasureRAMTotal.Total -eq '1') 'Total must request native physical memory total.'
foreach ($name in 'MeasureRAMPageUsed', 'MeasureRAMPageTotal') {
    Assert-RAM (-not $measures.ContainsKey($name)) 'PAGE must not retain native commit-accounting measures.'
}
foreach ($name in 'MeasureRAMPageBootstrap', 'MeasureRAMPageHost') {
    Assert-RAM ($measures[$name].Plugin -eq 'RunCommand' -and $measures[$name].State -eq 'Hide') 'PAGE setup and resident host must use hidden bundled RunCommand.'
    Assert-RAM ($measures[$name].UpdateDivider -eq '1' -and $measures[$name].Parameter -eq '') 'PAGE helpers must await the controller rather than execute polling commands.'
    Assert-RAM (-not $measures[$name].ContainsKey('FinishAction')) 'PAGE helper completion must not relaunch a polling process.'
}
Assert-RAM ([int]$measures.MeasureRAMPageBootstrap.Timeout -gt 0 -and [int]$measures.MeasureRAMPageBootstrap.Timeout -le 15000) 'PAGE session setup must have a bounded timeout.'
Assert-RAM ($measures.MeasureRAMPageHost.Timeout -eq '-1') 'PAGE host must stay resident rather than restart per reading.'
Assert-RAM ($measures.MeasureRAMPageView.ScriptFile -eq '#@#Modules\RAM\PageFile.lua' -and $measures.MeasureRAMPageView.UpdateDivider -eq '1') 'Missing paging-file cache and lifecycle controller.'
Assert-RAM ($meters.MeterRAMPercent.Percentual -eq '1') 'Percentage must use native normalization.'
foreach ($name in 'MeterRAMPercent', 'MeterRAMBar', 'MeterRAMHistory') {
    Assert-RAM ($meters[$name].MeasureName -eq 'MeasureRAMUsed') "$name lost its native used-memory binding."
}
Assert-RAM ($meters.MeterRAMBar.H -eq '#DataBarThicknessPx#') 'RAM capacity bar must inherit shared data-bar thickness.'
Assert-RAM ($meters.MeterRAMPageBar.H -eq '#DataBarThicknessPx#' -and $meters.MeterRAMPageBar.MeasureName -eq 'MeasureRAMPageRatio') 'PAGE must have its own shared-thickness paging-file ratio bar.'
Assert-RAM ($measures.MeasureRAMPageRatio.Measure -eq 'Calc' -and $measures.MeasureRAMPageRatio.UpdateDivider -eq '-1' -and $measures.MeasureRAMPageRatio.MinValue -eq '0' -and $measures.MeasureRAMPageRatio.MaxValue -eq '1') 'PAGE ratio must be an event-only native 0..1 value.'
Assert-RAM ($geometry.Variables.DataBarThicknessPx -eq '(Max(1,Round(#DataBarThickness#*#Scale#)))') 'Shared bar thickness must round scaled pixels and remain visible.'
Assert-RAM ($meters.MeterRAMHistory.AutoScale -eq '0') 'History must keep the native full-capacity range.'
Assert-RAM ($meters.MeterRAMHistory.GraphStart -eq 'Right') 'History startup cover expects newest at right.'
Assert-RAM ($meters.MeterRAMHistory.UpdateDivider -eq $measures.MeasureRAMHistorySamples.UpdateDivider) 'History and collected-sample cadence differ.'
Assert-RAM ($measures.MeasureRAMHistorySamples.Formula -eq 'Min(MeasureRAMHistorySamples+1,#ContentWidth#)') 'History count must reset with the measure on refresh.'
Assert-RAM ($meters.MeterRAMHistoryUncollected.DynamicVariables -eq '1') 'History cover must follow the sample count.'
Assert-RAM ($measures.MeasureRAMSettings.UpdateDivider -eq '-1') 'Settings must be event-driven.'
Assert-RAM ($measures.MeasureRAMSettings.ScriptFile -eq '#@#Modules\RAM\Display.lua') 'Main RAM must use its display-only controller.'
Assert-RAM ($measures.MeasureRAMSettings.Group -eq 'ParallaxRAMApply') 'Main RAM must expose its preference application group.'
Assert-RAM ($meters.MeterRAMOptions.LeftMouseUpAction -eq '[!ActivateConfig "Parallax\RAM\Settings" "Settings.ini"]') 'Gear must open the dedicated settings config.'
Assert-RAM ($entry.Rainmeter.ContextAction3 -eq $meters.MeterRAMOptions.LeftMouseUpAction) 'Context settings must open the same utility as the gear.'
Assert-RAM (-not $meters.MeterRAMHistory.ContainsKey('Group')) 'History must not be forced through menu updates.'
Assert-RAM ($measures.MeasureRAMInfo.Plugin -eq 'RunCommand') 'Hardware information must use the bundled RunCommand provider.'
Assert-RAM ($measures.MeasureRAMInfo.State -eq 'Hide') 'Hardware metadata query must stay hidden.'
Assert-RAM ([int]$measures.MeasureRAMInfo.Timeout -gt 0 -and [int]$measures.MeasureRAMInfo.Timeout -le 15000) 'Hardware query must have a bounded timeout.'
Assert-RAM ($entry.Rainmeter.OnRefreshAction -eq '[!CommandMeasure MeasureRAMInfo "Run"][!CommandMeasure MeasureRAMPageView "Start()"]') 'Refresh must query hardware once and start the paging-file lifecycle once.'
Assert-RAM ($entry.Rainmeter.OnCloseAction -eq '[!CommandMeasure MeasureRAMPageView "Stop()"]') 'RAM unload must stop its own paging-file helper and session.'
Assert-RAM ($measures.MeasureRAMInfoView.Measure -eq 'Script') 'Missing hardware view controller.'
Assert-RAM ($entry.Variables.RAMInfoHeight -eq '26' -and -not $user.Variables.ContainsKey('RAMInfoHeight')) 'Hardware summary height must be transient layout state with a compact fallback.'
$includeValues = @($entry.Variables.Keys | Where-Object { $_ -like '@Include*' } | Sort-Object { [int]($_ -replace '@Include','') } | ForEach-Object { $entry.Variables[$_] })
Assert-RAM ($includeValues -contains '#@#Modules\RAM\InfoMeters.inc') 'Missing hardware meters.'
Assert-RAM ($includeValues[-1] -eq '#@#Modules\RAM\ProcessMeters.inc') 'Missing final process table include.'
foreach ($rank in 1..5) {
    $provider = $measures['MeasureRAMProcess'+$rank]
    Assert-RAM ($provider.Plugin -eq 'UsageMonitor' -and $provider.Alias -eq 'RAM') 'Process ranks must use bundled private-working-set counters.'
    Assert-RAM ($provider.Index -eq [string]$rank -and $provider.Rollup -eq '1' -and $provider.Percent -eq '0') 'Process ranks must retain descending name rollups in bytes.'
    Assert-RAM ($provider.UpdateDivider -eq '1') 'Process rank cadence must follow MetricsInterval.'
}
Assert-RAM ($measures.MeasureRAMProcessView.ScriptFile -eq '#@#Modules\RAM\Process.lua') 'Missing cached process table controller.'
Assert-RAM ($includeValues -notcontains '#@#Modules\RAM\SettingsMeters.inc') 'Settings controls must not overlay the RAM meter.'
Assert-RAM ($settingsEntry.Rainmeter.Update -eq '-1') 'Settings utility must not poll.'
Assert-RAM ($settingsEntry.Rainmeter.Group -eq 'Parallax') 'Settings utility must participate in shared appearance refreshes.'
Assert-RAM ($settingsEntry.Rainmeter.ContextAction -eq '[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'Settings utility lost global settings access.'
Assert-RAM ($settingsEntry.Variables.Columns -eq '2' -and $settingsEntry.Variables.PanelHeight -eq '340') 'Settings utility must own its layout independently of the meter.'
for ($i = 0; $i -lt $expectedIncludes.Count; $i++) {
    Assert-RAM ($settingsEntry.Variables[('@Include{0}' -f ($i + 1))] -eq $expectedIncludes[$i]) 'Utility shared include order changed.'
}
$settingsMeasures = @($settingsEntry.Keys | Where-Object { $settingsEntry[$_].ContainsKey('Measure') })
Assert-RAM ($settingsMeasures.Count -eq 2 -and $settingsMeasures -contains 'MeasureRAMSettings' -and $settingsMeasures -contains 'MeasureRAMSettingsInput') 'Settings utility may only host its controller and event-only numeric input.'
Assert-RAM ($settingsEntry.MeasureRAMSettings.ScriptFile -eq '#@#Modules\RAM\Settings.lua') 'Settings utility must own its preferences controller.'
Assert-RAM ($settingsEntry.MeasureRAMSettingsInput.Plugin -eq 'RunCommand' -and $settingsEntry.MeasureRAMSettingsInput.State -eq 'Hide' -and $settingsEntry.MeasureRAMSettingsInput.UpdateDivider -eq '-1') 'Numeric input must be hidden and event-only, not telemetry.'
Assert-RAM ($settingsEntry.MeasureRAMSettingsInput.FinishAction -eq '[!UpdateMeasure MeasureRAMSettingsInput][!CommandMeasure MeasureRAMSettings "CompleteInput()"]') 'Typed input must finish through a fixed data-reading callback.'
Assert-RAM ($menu.MeterRAMSettingsClose.LeftMouseUpAction -eq '[!DeactivateConfig]') 'Closing settings must deactivate only its own config.'
$settingsScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Settings.lua') -Raw
$displayScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Display.lua') -Raw
$pageScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PageFile.lua') -Raw
Assert-RAM ($settingsScript -match '!SetVariableGroup' -and $settingsScript -match 'ParallaxRAM' -and $settingsScript -match '!UpdateMeasureGroup' -and $settingsScript -match 'ParallaxRAMApply') 'Preferences must reach the running RAM skin without refreshing it.'
Assert-RAM ($settingsScript -notmatch '!Refresh|MeasureRAMInfo|MeasureRAMPage|MeasureRAMHistory|!UpdateMeter.*,.*\*') 'Settings must not refresh RAM, launch providers, or force its history.'
Assert-RAM ($displayScript -notmatch '!Refresh|!WriteKeyValue|ToggleMenu|RAMSettingsMenu') 'Display controller must not persist preferences or own an overlay.'
Assert-RAM ($displayScript.Contains("SKIN:Bang('!CommandMeasure', 'MeasureRAMPageView', 'Display()')")) 'Unit changes must reformat the cached paging-file reading.'
Assert-RAM ($displayScript -notmatch 'MeasureRAMPageBootstrap|MeasureRAMPageHost|Start\(\)|io\.open') 'Settings-driven display must not launch or query the PAGE provider.'
$pageDisplay = [regex]::Match($pageScript,'(?s)function Display\(\)(.*?)\nlocal function cleanup').Groups[1].Value
$pageProviderDisplay = $pageDisplay.Replace("SKIN:Bang('!UpdateMeasure', 'MeasureRAMPageRatio')", '')
Assert-RAM ($pageDisplay.Length -gt 0 -and $pageProviderDisplay -notmatch 'io\.|launch\(|!CommandMeasure|!UpdateMeasure') 'PAGE Display may update its cached ratio without provider or session IO.'
Assert-RAM ($pageScript -notmatch 'MeasureRAMHistory|!UpdateMeterGroup') 'PAGE rendering must not force physical-memory history.'
foreach ($pair in @(@('Units','RAMUseMiB'), @('Decimals','RAMDecimals'), @('PercentDecimals','RAMPercentDecimals'), @('Bar','RAMShowBar'), @('PageBar','RAMShowPageBar'), @('History','RAMShowHistory'))) {
    Assert-RAM (-not $menu.ContainsKey('MeterRAMSettings'+$pair[0]+'Row')) 'Settings must not retain full-row shaded hit targets.'
    foreach ($suffix in '', 'Label') {
        $name = 'MeterRAMSettings' + $pair[0] + $suffix
        $numeric = $pair[0] -in 'Decimals','PercentDecimals'
        $stepper = $pair[0] -in 'Units','Decimals','PercentDecimals'
        $method = if ($numeric) { 'Edit' } else { 'Cycle' }
        Assert-RAM ($menu[$name].LeftMouseUpAction -eq ('[!CommandMeasure MeasureRAMSettings "{0}(''{1}'')"]' -f $method,$pair[1])) "$name must operate the corresponding setting."
        Assert-RAM ($menu[$name].ToolTipText.Length -gt 10) "$name requires a descriptive tooltip."
        $role = if ($suffix) { $suffix } else { 'Value' }
        $styles = ($menu[$name].MeterStyle.Split('|') | ForEach-Object { $_.Trim() }) -join '|'
        $expectedStyle = if ($stepper -and -not $suffix) { 'StyleSettingsStepperValue|StyleRAMSettingsStepperValue' } else { 'StyleUtilitySettings'+$role+'|StyleRAMSettings'+$role }
        Assert-RAM ($styles -eq $expectedStyle) "$name must layer the shared utility style and local geometry."
    }
    if ($stepper) {
        $base = 'MeterRAMSettings'+$pair[0]
        Assert-RAM ((($menu[$base+'Frame'].MeterStyle.Split('|') | ForEach-Object { $_.Trim() }) -join '|') -eq 'StyleSettingsStepperFrame|StyleRAMSettingsStepperFrame') 'Stepper frame must inherit its shared styling.'
        Assert-RAM ($menu[$base+'Frame'].LeftMouseUpAction -eq $menu[$base].LeftMouseUpAction) 'Stepper frame must invoke its current value action.'
        foreach ($direction in @(@('Prev',-1),@('Next',1))) {
            $method = if ($numeric) { 'Adjust' } else { 'Cycle' }
            Assert-RAM ($menu[$base+$direction[0]].LeftMouseUpAction -eq ('[!CommandMeasure MeasureRAMSettings "{0}(''{1}'',{2})"]' -f $method,$pair[1],$direction[1])) 'Stepper arrows must invoke the corresponding numeric or enum direction.'
            Assert-RAM ((($menu[$base+$direction[0]].MeterStyle.Split('|') | ForEach-Object { $_.Trim() }) -join '|') -eq ('StyleSettingsStepperButton|StyleRAMSettingsStepper'+$direction[0])) 'Stepper arrows must inherit shared styling.'
        }
    }
}
$allSections = @{}
foreach ($layer in $sharedStyles, $meters) {
    foreach ($name in $layer.Keys) { $allSections[$name] = $layer[$name] }
}
foreach ($name in $allSections.Keys) {
    if ($name -like 'Style*') { Assert-RAM (-not $allSections[$name].ContainsKey('Meter')) "Style $name draws independently." }
    if ($name -like 'Meter*') { Assert-RAM ($allSections[$name].ContainsKey('Meter')) "$name has no meter type." }
}
function Get-RAMMeter([string]$Name) {
    $result = @{}
    if ($allSections[$Name].ContainsKey('MeterStyle')) {
        foreach ($style in $allSections[$Name].MeterStyle.Split('|')) {
            foreach ($key in $allSections[$style.Trim()].Keys) { $result[$key] = $allSections[$style.Trim()][$key] }
        }
    }
    foreach ($key in $allSections[$Name].Keys) { $result[$key] = $allSections[$Name][$key] }
    return $result
}
$numberCache = @{}
$contextNumberCache = @{}
function Get-RAMNumber([string]$Expression, [double]$Samples = 0) {
    # Geometry repeats the same expressions across many meters. Reset this
    # cache whenever the test changes its variable context, below.
    $contextKey = $Expression + '|' + $Samples.ToString([Globalization.CultureInfo]::InvariantCulture)
    if ($script:contextNumberCache.ContainsKey($contextKey)) { return $script:contextNumberCache[$contextKey] }
    $expanded = $Expression.Replace('[MeasureRAMHistorySamples]', $Samples.ToString([Globalization.CultureInfo]::InvariantCulture))
    for ($pass = 0; $pass -lt 30 -and $expanded.Contains('#'); $pass++) {
        $expanded = [regex]::Replace($expanded, '#([^#]+)#', {
            param($match)
            if (-not $variables.ContainsKey($match.Groups[1].Value)) { throw "Unknown variable: $($match.Value)" }
            return [string]$variables[$match.Groups[1].Value]
        })
    }
    # Only the numeric expression subset authored by this module is accepted.
    $residue = $expanded -replace '\b(Round|Min|Max)\b', '' -replace '[0-9.()+*/ ,<>-]', ''
    if ($residue) { throw "Unsafe or unsupported geometry expression: $expanded" }
    $cacheKey = $expanded
    if ($script:numberCache.ContainsKey($cacheKey)) {
        $script:contextNumberCache[$contextKey] = $script:numberCache[$cacheKey]
        return $script:numberCache[$cacheKey]
    }
    # Rainmeter rounds positive geometry half up, including 6 * 0.75 = 4.5.
    # .NET's default banker rounding would make the narrow-scale checks wrong.
    $expanded = $expanded -replace '\bRound\(', '[Math]::Floor(0.5+' -replace '\bMin\(', '[Math]::Min(' -replace '\bMax\(', '[Math]::Max('
    $expanded = $expanded.Replace('<', ' -lt ').Replace('>', ' -gt ')
    # Rainmeter formulas use doubles. Bare integer literals can make PowerShell
    # select Math.Max(int,int), incorrectly turning Max(74,76.5) into 76.
    $expanded = [regex]::Replace($expanded, '(?<![\w.])\d+(?![\w.])', '$&.0')
    $value = [double](Invoke-Expression $expanded)
    $script:numberCache[$cacheKey] = $value
    $script:contextNumberCache[$contextKey] = $value
    return $value
}
foreach ($name in 'MeterRAMTitle') {
    $meter = Get-RAMMeter $name
    Assert-RAM ($meter.FontColor -eq '#TitleTextColor#' -and $meter.FontSize -eq '(#TitleFontSize#*#Scale#)') "$name must inherit title typography."
    Assert-RAM ($meter.MeterStyle -match 'StyleTitleRow' -and $meter.StringAlign -eq 'LeftCenter') "$name must opt into the shared centered title row."
}
$percent = Get-RAMMeter 'MeterRAMPercent'
Assert-RAM ($percent.MeterStyle -match 'StyleTitleRow' -and $percent.StringAlign -eq 'RightCenter') 'RAM percentage must share the centered title row.'
Assert-RAM ($percent.FontSize -eq '((#FontSize#+1)*#Scale#)') 'RAM percentage must retain its body-relative font size.'
Assert-RAM ($menu.MeterRAMSettingsTitle.MeterStyle -match 'StyleTitleRow') 'Settings title must opt into the shared centered row.'
foreach ($name in 'MeterRAMHistoryLabel', 'MeterRAMProcessesHeader', 'MeterRAMProcessesMemoryHeader') {
    $meter = Get-RAMMeter $name
    Assert-RAM ($meter.FontColor -eq '#HeaderTextColor#' -and $meter.FontSize -eq '(#HeaderFontSize#*#Scale#)') "$name must inherit section-header typography."
}
Assert-RAM ($meters.MeterRAMProcessesHeader.Text -eq 'Process') 'Process table must use the requested column heading.'
Assert-RAM ($entry.Variables.RAMTitle -eq 'Memory Meter' -and $user.Variables.RAMTitle -eq 'Memory Meter') 'Default title must be Memory Meter.'
Assert-RAM ($meters.MeterRAMUsedLabel.Text -eq 'RAM:' -and $meters.MeterRAMPageLabel.Text -eq 'PAGE:') 'Compact memory rows must use RAM: and PAGE: labels.'
foreach ($name in 'MeterRAMSubtitle','MeterRAMAvailableLabel','MeterRAMAvailableGiB','MeterRAMAvailableMiB','MeterRAMTotalLabel','MeterRAMTotalGiB','MeterRAMTotalMiB') {
    Assert-RAM (-not $meters.ContainsKey($name)) 'Superseded standalone physical-memory row remains.'
}
Assert-RAM ($menu.StyleRAMSettingsUI.Count -eq 1 -and $menu.StyleRAMSettingsUI.Group -eq 'RAMSettingsUI') 'Local utility style must only assign its UI group.'
foreach ($role in 'Section','Row') { Assert-RAM (-not $menu.ContainsKey('StyleRAMSettings'+$role)) 'RAM settings must not duplicate shared utility styles.' }
Assert-RAM ($menu.StyleRAMSettingsLabel.Count -eq 2 -and $menu.StyleRAMSettingsLabel.Group -eq 'RAMSettingsUI' -and $menu.StyleRAMSettingsLabel.ContainsKey('W')) 'Local label style must only assign width and UI group.'
Assert-RAM ($menu.StyleRAMSettingsValue.Count -eq 3 -and $menu.StyleRAMSettingsValue.Group -eq 'RAMSettingsUI' -and $menu.StyleRAMSettingsValue.ContainsKey('W') -and $menu.StyleRAMSettingsValue.ContainsKey('X')) 'Local value style must only assign column geometry and UI group.'
foreach ($role in 'Value','Frame','Prev','Next') {
    $stepperStyle = $menu['StyleRAMSettingsStepper'+$role]
    Assert-RAM ($stepperStyle.Count -eq 2 -and $stepperStyle.Group -eq 'RAMSettingsUI' -and $stepperStyle.ContainsKey('X')) 'Local stepper styles may only assign column position and UI group.'
}
Assert-RAM ($sharedStyles.StyleUtilitySettingsSection.FontColor -eq '#AccentColor#' -and $sharedStyles.StyleUtilitySettingsSection.FontSize -eq '(#HeaderFontSize#*#Scale#)') 'Settings sections must use Accent 1 with shared header sizing.'
Assert-RAM ($sharedStyles.StyleUtilitySettingsLabel.FontColor -eq '#TextColor#' -and $sharedStyles.StyleUtilitySettingsLabel.FontSize -eq '(#FontSize#*#Scale#)') 'Settings labels must use shared body typography.'
Assert-RAM ($sharedStyles.StyleUtilitySettingsValue.FontColor -eq '#TextColor#') 'Settings choices must use the shared body text color.'
Assert-RAM ($sharedStyles.StyleUtilitySettingsValue.SolidColor -eq '#GraphBackgroundColor#' -and $sharedStyles.StyleUtilitySettingsValue.Padding -eq '(3*#Scale#),#Scale#,(3*#Scale#),#Scale#' -and $sharedStyles.StyleUtilitySettingsValue.StringAlign -eq 'Left') 'Settings values must inherit the padded shaded Global Settings field style.'
foreach ($name in 'MeterRAMSettingsDisplay','MeterRAMSettingsVisibility') {
    $styles = ($menu[$name].MeterStyle.Split('|') | ForEach-Object { $_.Trim() }) -join '|'
    Assert-RAM ($styles -eq 'StyleUtilitySettingsSection|StyleRAMSettingsUI') 'Settings sections must layer the shared style and local UI group.'
    $styles = ($menu[$name+'Rule'].MeterStyle.Split('|') | ForEach-Object { $_.Trim() }) -join '|'
    Assert-RAM ($styles -eq 'StyleRule|StyleRAMSettingsUI') 'Semantic settings sections must use divider rules, not table-header borders.'
}
Assert-RAM ($settingsNote.MeterUtilitySettingsGlobalLink.LeftMouseUpAction -eq '[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'Shared settings navigation must retain its global config target.'
Assert-RAM ($menu.MeterRAMSettingsClose.MeterStyle -match 'StyleSecondaryButton') 'Settings close must use the secondary action accent.'
$summaryMeter = Get-RAMMeter 'MeterRAMInfoSummary'
Assert-RAM ($summaryMeter.Meter -eq 'String') 'Hardware summary must use text for availability.'
Assert-RAM ($summaryMeter.Group -match 'RAMHardwareInfo') 'Hardware summary must update separately from history.'
Assert-RAM ($summaryMeter.ClipString -eq '2' -and -not $summaryMeter.ContainsKey('H')) 'Hardware summary must wrap with native automatic height.'
Assert-RAM ($summaryMeter.FontColor -eq '#TextColor#' -and $summaryMeter.FontSize -eq '(#FontSize#*#Scale#)') 'Hardware summary must use body typography.'
Assert-RAM ($summaryMeter.Text -eq 'Checking...') 'Hardware summary must not start with invented metadata.'
foreach ($legacy in 'Heading','Installed','InstalledLabel','Type','TypeLabel','Speed','SpeedLabel','Devices','DevicesLabel','Form','FormLabel') {
    Assert-RAM (-not $meters.ContainsKey('MeterRAMInfo'+$legacy)) "Obsolete overview meter remains: $legacy"
}
foreach ($rank in 1..5) {
    foreach ($kind in 'Name','Value') {
        $meter = Get-RAMMeter ('MeterRAMProcess'+$kind+$rank)
        Assert-RAM ($meter.Group -match 'RAMLayout' -and $meter.Group -match 'RAMProcesses' -and $meter.DynamicVariables -eq '1') 'Process rows must follow overview height and cached formatting.'
        Assert-RAM ($meter.FontColor -eq '#TextColor#' -and $meter.FontSize -eq '(#FontSize#*#Scale#)') 'Process rows must inherit body typography.'
    }
}
foreach ($kind in 'Used','Page') {
    # Legacy section suffixes and the saved RAMUseMiB selector are retained;
    # displayed values now use decimal GB and MB.
    foreach ($unit in 'GiB', 'MiB') {
        $meter = Get-RAMMeter "MeterRAM$kind$unit"
        $displayUnit = if ($unit -eq 'GiB') { 'GB' } else { 'MB' }
        $expectedDivisor = if ($unit -eq 'GiB') { 1000000000.0 } else { 1000000.0 }
        if ($kind -eq 'Used') {
            Assert-RAM ([double]$meter.Scale -eq $expectedDivisor) "Incorrect $displayUnit divisor."
            Assert-RAM ($meter.Text -eq "%1/%2 $displayUnit") "Incorrect used/total $displayUnit label."
            Assert-RAM ($meter.MeasureName -eq 'MeasureRAMUsed' -and $meter.MeasureName2 -eq 'MeasureRAMTotal') 'Incorrect physical RAM used/total bindings.'
            Assert-RAM ($meter.AutoScale -eq '0') 'Automatic units would override the explicit byte divisor.'
        } else {
            Assert-RAM (-not $meter.ContainsKey('MeasureName') -and -not $meter.ContainsKey('MeasureName2') -and -not $meter.ContainsKey('Scale')) 'PAGE must use cached actual bytes, not native commit or extra scaling.'
            Assert-RAM ($meter.Text -eq 'Checking...') 'PAGE must not begin with fabricated paging-file usage.'
            Assert-RAM ($meter.ToolTipText -match 'Paging-file space in use / current allocated capacity' -and $meter.ToolTipText -match 'excluding physical RAM') 'PAGE tooltip must describe actual paging-file usage and allocated capacity.'
        }
        foreach ($mode in 0, 1) {
            $variables.RAMUseMiB = [string]$mode
            $contextNumberCache = @{}
            $expectedHidden = if ($unit -eq 'GiB') { $mode } else { 1 - $mode }
            Assert-RAM ((Get-RAMNumber $meter.Hidden) -eq $expectedHidden) 'Unit selector exposes the wrong meter.'
        }
    }
}
$geometryRows = @()
$mainMeters = $meters
$mainPanelHeight = $variables.PanelHeight
foreach ($utility in $false, $true) {
    if ($utility) {
        $meters = @{}
        foreach ($layer in $settingsEntry, $settingsNote, $menu) {
            foreach ($name in $layer.Keys) { if ($name -match '^(Meter|Style|RAMStyle)') { $meters[$name] = $layer[$name] } }
        }
        $variables.PanelHeight = $settingsEntry.Variables.PanelHeight
        $columnCases = @(2)
    } else {
        $meters = $mainMeters
        $variables.PanelHeight = $mainPanelHeight
        $columnCases = @(1, 2)
    }
    $allSections = @{}
    foreach ($layer in $sharedStyles, $meters) {
        foreach ($name in $layer.Keys) { $allSections[$name] = $layer[$name] }
    }
foreach ($border in 0, 1, 4) {
    $variables.BorderThickness = [string]$border
    $variables.TableHeaderBorderThickness = [string]$border
    $variables.DividerThickness = [string]$border
foreach ($columnWidth in 180, 200, 220, 240, 280, 320) {
foreach ($suiteScale in 0.75, 1, 1.25, 1.5, 2) {
    # Keep existing coverage while exercising title/font-dependent icon geometry
    # at the minimum/default widths and representative suite scales.
    $titleSizes = if ($columnWidth -in 180, 220 -and $suiteScale -in 0.75, 1, 2) { @(6, 10, 12) } else { @(10) }
    foreach ($titleSize in $titleSizes) {
    foreach ($columns in $columnCases) {
        $infoHeights = if (-not $utility -and $border -eq 1 -and $titleSize -eq 10 -and $columnWidth -in 180, 220 -and $suiteScale -in 0.75, 1, 2) { @(26,80,188) } else { @(26) }
        foreach ($infoHeight in $infoHeights) {
        $barThicknesses = if (-not $utility -and $infoHeight -eq 26 -and $border -eq 1 -and $titleSize -eq 10 -and $columnWidth -in 180, 220 -and $suiteScale -in 0.75, 1, 2) { @(1,6,6.25,12) } else { @(6) }
        foreach ($barThickness in $barThicknesses) {
        $variables.ColumnWidth = [string]$columnWidth
        $variables.Scale = $suiteScale.ToString([Globalization.CultureInfo]::InvariantCulture)
        $variables.Columns = [string]$columns
        $variables.TitleFontSize = [string]$titleSize
        $variables.RAMInfoHeight = [string]$infoHeight
        $variables.DataBarThickness = $barThickness.ToString([Globalization.CultureInfo]::InvariantCulture)
        $contextNumberCache = @{}
        $windowWidth = Get-RAMNumber '#WindowWidth#'
        # RAM preserves older user PanelHeight values while giving the new
        # hardware panel and configurable graph an actual minimum window.
        $windowHeight = if ($utility) { Get-RAMNumber '#WindowHeight#' } else { Get-RAMNumber $meters.MeterRAMBounds.H }
        $inset = Get-RAMNumber '#Inset#'
        $contentWidth = Get-RAMNumber '#ContentWidth#'
        Assert-RAM ($contentWidth -gt 0) 'Nonpositive content width.'
        $meterBounds = @{}
        foreach ($name in $meters.Keys | Where-Object { $_ -like 'Meter*' }) {
            $meter = Get-RAMMeter $name
            $x = Get-RAMNumber $meter.X
            $y = Get-RAMNumber $meter.Y
            if ($meter.Meter -eq 'Shape') {
                $minX = [double]::PositiveInfinity; $minY = [double]::PositiveInfinity
                $maxX = [double]::NegativeInfinity; $maxY = [double]::NegativeInfinity
                foreach ($shapeKey in $meter.Keys | Where-Object { $_ -match '^Shape\d*$' }) {
                $shapeCoordinates = ($meter[$shapeKey] -split ' \| ')[0]
                # Split only commas outside the nested formula parentheses.
                $shapeType, $coordinates = $shapeCoordinates -split ' ', 2
                if ($shapeType -eq 'Path') {
                    # The shared-with-CPU gear is a closed polygon of LineTo
                    # vertices. Inspect each vertex rather than skipping it.
                    $pathX = @(); $pathY = @()
                    foreach ($segment in $meter[$coordinates] -split ' \| ') {
                        if ($segment -match '^ClosePath 1$') { continue }
                        $vertex = ($segment -replace '^LineTo ', '') -split ','
                        Assert-RAM ($vertex.Count -eq 2) 'Unverified gear path segment.'
                        $pathX += Get-RAMNumber $vertex[0]
                        $pathY += Get-RAMNumber $vertex[1]
                    }
                    $extremeX = $pathX | Measure-Object -Minimum -Maximum
                    $extremeY = $pathY | Measure-Object -Minimum -Maximum
                    $coordinates = '{0},{1},{2},{3}' -f $extremeX.Minimum, $extremeY.Minimum, ($extremeX.Maximum-$extremeX.Minimum), ($extremeY.Maximum-$extremeY.Minimum)
                    $shapeType = 'Rectangle'
                }
                $parts = [Collections.Generic.List[string]]::new()
                $depth = 0; $start = 0
                for ($j = 0; $j -lt $coordinates.Length; $j++) {
                    if ($coordinates[$j] -eq '(') { $depth++ }
                    if ($coordinates[$j] -eq ')') { $depth-- }
                    if ($coordinates[$j] -eq ',' -and $depth -eq 0) { $parts.Add($coordinates.Substring($start, $j - $start)); $start = $j + 1 }
                }
                $parts.Add($coordinates.Substring($start))
                Assert-RAM ($shapeType -in 'Line', 'Rectangle', 'Ellipse') 'Unverified shape type.'
                $x1 = Get-RAMNumber $parts[0]; $y1 = Get-RAMNumber $parts[1]
                $x2 = Get-RAMNumber $parts[2]; $y2 = Get-RAMNumber $parts[3]
                if ($shapeType -eq 'Rectangle') { $x2 += $x1; $y2 += $y1 }
                if ($shapeType -eq 'Ellipse') {
                    $radiusX = $x2; $radiusY = $y2
                    $x2 = $x1 + $radiusX; $y2 = $y1 + $radiusY
                    $x1 -= $radiusX; $y1 -= $radiusY
                }
                $stroke = 0.0
                if ($meter[$shapeKey] -match 'StrokeWidth ([^|]+)') { $stroke = Get-RAMNumber $Matches[1].Trim() }
                if ($name -eq 'MeterRAMIcon') {
                    $svgUnit = (Get-RAMNumber '#TitleIconSize#')/24
                    Assert-RAM ([Math]::Abs($stroke - 2*$svgUnit) -lt 0.001) 'RAM identity-icon strokes must preserve the SVG width of 2 in its scaled 24-unit canvas.'
                    Assert-RAM ($meter[$shapeKey] -match '(?:^|\| )StrokeLineJoin Round(?: \||$)') 'RAM identity-icon joins must preserve the SVG round joins.'
                    if ($shapeType -eq 'Line') {
                        Assert-RAM ($meter[$shapeKey] -match '(?:^|\| )StrokeStartCap Round(?: \||$)' -and $meter[$shapeKey] -match '(?:^|\| )StrokeEndCap Round(?: \||$)') 'RAM identity-icon line caps must preserve the SVG round endpoints.'
                    }
                }
                $padX = $stroke / 2; $padY = $stroke / 2
                # Rainmeter's default flat line caps stop at their endpoints.
                # Axis-aligned rules therefore expand only across the stroke.
                if ($shapeType -eq 'Line' -and $meter[$shapeKey] -notmatch 'Stroke(?:Start|End)Cap (Round|Square)') {
                    if ($y1 -eq $y2) { $padX = 0 }
                    if ($x1 -eq $x2) { $padY = 0 }
                }
                $minX = [Math]::Min($minX, [Math]::Min($x1, $x2) - $padX)
                $minY = [Math]::Min($minY, [Math]::Min($y1, $y2) - $padY)
                $maxX = [Math]::Max($maxX, [Math]::Max($x1, $x2) + $padX)
                $maxY = [Math]::Max($maxY, [Math]::Max($y1, $y2) + $padY)
                }
                if ($name -eq 'MeterRAMIcon') {
                    $canvasWidth = Get-RAMNumber $meter.W
                    $canvasHeight = Get-RAMNumber $meter.H
                    $expectedSize = 14*$suiteScale*$titleSize/10
                    Assert-RAM ([Math]::Abs($canvasWidth-$expectedSize) -lt 0.001 -and [Math]::Abs($canvasHeight-$expectedSize) -lt 0.001) 'RAM icon canvas must follow title size and suite scale.'
                    Assert-RAM ($minX -ge 0 -and $minY -ge 0 -and $maxX -le $canvasWidth+0.001 -and $maxY -le $canvasHeight+0.001) 'RAM icon strokes exceed their typography-scaled canvas.'
                    $svgUnit = $canvasWidth/24
                    Assert-RAM ([Math]::Abs($minX-$svgUnit) -lt 0.001 -and [Math]::Abs($maxX-23*$svgUnit) -lt 0.001 -and [Math]::Abs($minY-5*$svgUnit) -lt 0.001 -and [Math]::Abs($maxY-19*$svgUnit) -lt 0.001) 'RAM icon painted bounds must preserve the memory-stick SVG extents (1..23, 5..19).'
                    Assert-RAM ([Math]::Abs($x-(Get-RAMNumber '#ContentX#')) -lt 0.001) 'RAM icon must align with the shared content edge.'
                    Assert-RAM ([Math]::Abs($y+$canvasHeight/2-(Get-RAMNumber '#TitleRowCenterY#')) -lt 0.001) 'RAM icon canvas is not centered on its title row.'
                }
                $x += $minX; $y += $minY
                $width = $maxX - $minX; $height = $maxY - $minY
            } else {
                $width = Get-RAMNumber $meter.W
                # Source geometry uses representative measured heights. The
                # fixture-only native mode verifies actual text wrapping.
                $height = if ($name -eq 'MeterRAMInfoSummary') { ($infoHeight-8)*$suiteScale } else { Get-RAMNumber $meter.H }
            }
            if ($meter.Meter -eq 'String' -and $meter.ContainsKey('Padding')) {
                $padding = @($meter.Padding.Split(',') | ForEach-Object { Get-RAMNumber $_ })
                Assert-RAM ($padding.Count -eq 4) 'String padding requires four verified components.'
                $width += $padding[0]+$padding[2]
                $height += $padding[1]+$padding[3]
            }
            if ($meter.Meter -eq 'String' -and $meter.ContainsKey('StringAlign')) {
                $alignment = $meter.StringAlign.ToLowerInvariant()
                if ($alignment.StartsWith('right')) { $x -= $width }
                elseif ($alignment.StartsWith('center')) { $x -= $width/2 }
                if ($alignment -match '^(left|center|right)center$') { $y -= $height/2 }
                elseif ($alignment -match '^(left|center|right)bottom$') { $y -= $height }
            }
            $meterBounds[$name] = @{ X=$x; Y=$y; W=$width; H=$height }
            Assert-RAM ($width -ge 0 -and $height -ge 0) "Negative size on $name."
            Assert-RAM ($x -ge 0 -and $y -ge 0 -and $x + $width -le $windowWidth + 0.001 -and $y + $height -le $windowHeight + 0.001) "$name leaves its window at scale $suiteScale / columns $columns."
            if ($name -notin 'MeterRAMBounds', 'MeterRAMSettingsBounds') {
                Assert-RAM ($x -ge $inset -and $y -ge $inset -and $x + $width -le $windowWidth - $inset + 0.001 -and $y + $height -le $windowHeight - $inset + 0.001) "$name enters the transparent gutter."
            }
        }
        $centerY = Get-RAMNumber '#TitleRowCenterY#'
        $titleHeight = Get-RAMNumber '#TitleRowHeight#'
        $titleName = if ($utility) { 'MeterRAMSettingsTitle' } else { 'MeterRAMTitle' }
        $title = $meterBounds[$titleName]
        Assert-RAM ([Math]::Abs($title.Y+$title.H/2-$centerY) -lt 0.001 -and [Math]::Abs($title.H-$titleHeight) -lt 0.001) "$titleName must preserve the shared vertical center and height."
        Assert-RAM ($title.W -gt 0) "$titleName has no room for text."
        if ($utility) {
            $close = $meterBounds.MeterRAMSettingsClose
            Assert-RAM ([Math]::Abs($close.Y+$close.H/2-$centerY) -lt 0.001) 'Settings close control must share the title center.'
            Assert-RAM ($title.X+$title.W -le $close.X+0.001) 'Settings title overlaps its close control.'
            $noteTop = $meterBounds.MeterUtilitySettingsNote.Y
            Assert-RAM ($title.Y+$title.H -le $noteTop -and $close.Y+$close.H -le $noteTop) 'Settings title row overlaps the shared note.'
            foreach ($section in @(@('Display',74,95,'Units'), @('Visibility',188,209,'Bar'))) {
                $heading = $meterBounds['MeterRAMSettings'+$section[0]]
                $rule = $meterBounds['MeterRAMSettings'+$section[0]+'Rule']
                Assert-RAM ([Math]::Abs($heading.Y-($inset+$section[1]*$suiteScale)) -lt 0.001) 'Settings section lost the shared field rhythm.'
                Assert-RAM ([Math]::Abs($rule.Y+$rule.H/2-($inset+$section[2]*$suiteScale)) -lt 0.001 -and [Math]::Abs($rule.H-$border*$suiteScale) -lt 0.001) 'Settings divider lost its semantic stroke or position.'
                Assert-RAM ($rule.Y -ge $heading.Y+$heading.H -and $rule.Y+$rule.H -le $meterBounds['MeterRAMSettings'+$section[3]].Y) 'Settings divider overlaps its heading or first field.'
            }
            foreach ($control in @(@('Units',100), @('Decimals',128), @('PercentDecimals',156), @('Bar',214), @('PageBar',242), @('History',270))) {
                $label = $meterBounds['MeterRAMSettings'+$control[0]+'Label']
                $value = $meterBounds['MeterRAMSettings'+$control[0]]
                if ($control[0] -in 'Units','Decimals','PercentDecimals') {
                    $frame = $meterBounds['MeterRAMSettings'+$control[0]+'Frame']
                    $prev = $meterBounds['MeterRAMSettings'+$control[0]+'Prev']
                    $next = $meterBounds['MeterRAMSettings'+$control[0]+'Next']
                    Assert-RAM ([Math]::Abs($frame.Y-($inset+$control[1]*$suiteScale)) -lt 0.001 -and [Math]::Abs($frame.H-20*$suiteScale) -lt 0.001) 'Stepper frames must retain 20px height and section pitch.'
                    Assert-RAM ([Math]::Abs($value.H-18*$suiteScale) -lt 0.001 -and [Math]::Abs($value.Y-$frame.Y-$suiteScale) -lt 0.001 -and $prev.Y -eq $value.Y -and $next.Y -eq $value.Y) 'Stepper arrows/value must center vertically inside the frame.'
                    Assert-RAM ([Math]::Abs($label.Y-$frame.Y-2*$suiteScale) -lt 0.001 -and $label.X+$label.W -le $prev.X) 'Stepper group must clear its aligned label.'
                    Assert-RAM ([Math]::Abs($prev.X-(Get-RAMNumber '#ContentX#')-138*$suiteScale) -lt 0.001 -and [Math]::Abs($prev.W-18*$suiteScale) -lt 0.001 -and [Math]::Abs($next.W-18*$suiteScale) -lt 0.001) 'Stepper arrows lost shared size or group alignment.'
                    Assert-RAM ([Math]::Abs($frame.X-$prev.X-$prev.W-2*$suiteScale) -lt 0.001 -and [Math]::Abs($next.X-$frame.X-$frame.W-2*$suiteScale) -lt 0.001) 'Stepper arrows must retain clear two-pixel gaps.'
                    Assert-RAM ([Math]::Abs($value.W-56*$suiteScale) -lt 0.001 -and [Math]::Abs($value.X-$frame.X) -lt 0.001 -and [Math]::Abs($frame.W-$value.W) -lt 0.001) 'Stepper current value and frame must share their 56px bounds.'
                } else {
                    Assert-RAM ([Math]::Abs($value.Y-($inset+$control[1]*$suiteScale)) -lt 0.001 -and [Math]::Abs($value.H-20*$suiteScale) -lt 0.001) 'Settings fields must retain padded height and 28px pitch within each section.'
                    Assert-RAM ([Math]::Abs($label.Y-$value.Y-2*$suiteScale) -lt 0.001) 'Settings labels must align two logical pixels below the field top.'
                    Assert-RAM ($label.X+$label.W -le $value.X -and [Math]::Abs($value.X-(Get-RAMNumber '#ContentX#')-138*$suiteScale) -lt 0.001) 'Settings labels overlap the aligned value column.'
                    Assert-RAM ([Math]::Abs($value.X+$value.W-(Get-RAMNumber '#ContentX#')-$contentWidth) -lt 0.001) 'Padded settings fields must end at the content edge.'
                }
            }
        } else {
            $icon = $meterBounds.MeterRAMIcon
            $percentBounds = $meterBounds.MeterRAMPercent
            $gear = Get-RAMMeter 'MeterRAMOptions'
            $iconMeter = Get-RAMMeter 'MeterRAMIcon'
            $iconRight = (Get-RAMNumber $iconMeter.X)+(Get-RAMNumber $iconMeter.W)
            Assert-RAM ([Math]::Abs($icon.Y+$icon.H/2-$centerY) -lt 0.001) 'RAM icon painted bounds must share the title center.'
            Assert-RAM ([Math]::Abs($title.X-$iconRight-(Get-RAMNumber '#TitleIconGap#')) -lt 0.001) 'RAM title must keep the configured gap from its icon canvas.'
            Assert-RAM ([Math]::Abs($percentBounds.Y+$percentBounds.H/2-$centerY) -lt 0.001 -and [Math]::Abs($percentBounds.H-$titleHeight) -lt 0.001) 'RAM percentage must share the title center and row height.'
            Assert-RAM ([Math]::Abs((Get-RAMNumber $gear.Y)+(Get-RAMNumber $gear.H)/2-$centerY) -lt 0.001) 'RAM gear must share the title center.'
            Assert-RAM ([Math]::Abs((Get-RAMNumber $gear.W)-18*$suiteScale) -lt 0.001 -and [Math]::Abs((Get-RAMNumber $gear.H)-18*$suiteScale) -lt 0.001) 'RAM gear must retain its fixed suite-scaled hit area.'
            Assert-RAM ($title.X+$title.W -le $percentBounds.X+0.001 -and $title.X+$title.W -le (Get-RAMNumber $gear.X)+0.001) 'RAM title overlaps the live percentage or hover gear.'
            Assert-RAM ($title.Y+$title.H -le $meterBounds.MeterRAMInfoPanel.Y -and $icon.Y+$icon.H -le $meterBounds.MeterRAMInfoPanel.Y) 'RAM title row overlaps the hardware panel.'
            $summary = $meterBounds.MeterRAMInfoSummary
            $panel = $meterBounds.MeterRAMInfoPanel
            Assert-RAM ($summary.X -ge $panel.X -and $summary.X+$summary.W -le $panel.X+$panel.W+0.001 -and $summary.Y -ge $panel.Y -and $summary.Y+$summary.H -le $panel.Y+$panel.H+0.001) 'Wrapped hardware summary leaves its inset panel.'
            Assert-RAM ($panel.Y+$panel.H -lt $meterBounds.MeterRAMUsedLabel.Y) 'Hardware overview overlaps compact memory rows.'
            foreach ($kind in 'Used', 'Page') {
                $label = $meterBounds['MeterRAM'+$kind+'Label']
                $value = $meterBounds['MeterRAM'+$kind+'GiB']
                Assert-RAM ($label.Y -eq $value.Y -and $label.X+$label.W -le $value.X) 'Compact memory label and value overlap or lose alignment.'
            }
            Assert-RAM ($meterBounds.MeterRAMUsedLabel.Y+$meterBounds.MeterRAMUsedLabel.H -le $meterBounds.MeterRAMPageLabel.Y) 'RAM and PAGE readouts overlap.'
            Assert-RAM ($meterBounds.MeterRAMHistory.Y -gt $meterBounds.MeterRAMHistoryLabel.Y+$meterBounds.MeterRAMHistoryLabel.H) 'Moved history overlaps its heading.'
            $processHeader = $meterBounds.MeterRAMProcessesHeader
            $processMemory = $meterBounds.MeterRAMProcessesMemoryHeader
            $processRule = $meterBounds.MeterRAMProcessesHeaderRule
            $roundedBarHeight = [Math]::Max(1.0,[Math]::Floor(0.5+$barThickness*$suiteScale))
            foreach ($barSpec in @(@('MeterRAMBar','MeterRAMUsedLabel','MeterRAMPageLabel',57), @('MeterRAMPageBar','MeterRAMPageLabel','MeterRAMProcessesHeader',89))) {
                $bar = $meterBounds[$barSpec[0]]
                $label = $meterBounds[$barSpec[1]]
                $following = $meterBounds[$barSpec[2]]
                Assert-RAM ([Math]::Abs($bar.H-$roundedBarHeight) -lt 0.001) 'Memory bar height does not match shared rounded pixel thickness.'
                Assert-RAM ($bar.Y -ge $label.Y+$label.H+2*$suiteScale-0.001) 'Memory bar loses clearance below its readout.'
                if ($barThickness -le 6) {
                    $centerQuantization = ($roundedBarHeight-$barThickness*$suiteScale)/2
                    Assert-RAM ([Math]::Abs($bar.Y+$bar.H/2-$centerQuantization-($inset+($infoHeight+$barSpec[3])*$suiteScale)) -lt 0.001) 'Thin memory bars must preserve their logical center with pixel quantization.'
                }
                Assert-RAM ($following.Y -ge $bar.Y+$bar.H+4*$suiteScale-0.501) 'Following content loses clearance below its memory bar beyond pixel quantization.'
            }
            Assert-RAM ($processHeader.X+$processHeader.W -le $processMemory.X) 'Process headings overlap.'
            Assert-RAM ($processRule.Y -ge $processHeader.Y+$processHeader.H-2*$suiteScale) 'Process header rule overlaps its text box beyond the authored edge.'
            $previousBottom = $processRule.Y+$processRule.H
            foreach ($rank in 1..5) {
                $nameBounds = $meterBounds['MeterRAMProcessName'+$rank]
                $valueBounds = $meterBounds['MeterRAMProcessValue'+$rank]
                Assert-RAM ($nameBounds.Y -ge $previousBottom -and $nameBounds.Y -eq $valueBounds.Y) 'Process rows overlap or columns are misaligned.'
                Assert-RAM ($nameBounds.X+$nameBounds.W -le $valueBounds.X) 'Process name overlaps its memory value.'
                $previousBottom = $nameBounds.Y+$nameBounds.H
            }
            Assert-RAM ($meterBounds.MeterRAMHistoryLabel.Y -ge $previousBottom) 'Bottom history section overlaps the process table.'
        }
        if (-not $utility) {
        $maskFormula = $meters.MeterRAMHistoryUncollected.Shape -replace '^Rectangle 0,0,', '' -replace ',\(#GraphHeight#\*#Scale#\).*$', ''
        foreach ($count in 0, 1, 2, ($contentWidth / 2), ($contentWidth - 1), $contentWidth) {
            $cover = Get-RAMNumber $maskFormula $count
            Assert-RAM ($cover -ge 0 -and $cover -le $contentWidth) 'Startup history cover leaves its plot.'
            if ($count -lt $contentWidth) { Assert-RAM ($cover -ge $contentWidth - $count) 'Startup zeros can be exposed.' }
            else { Assert-RAM ($cover -eq 0) 'A full history must be revealed.' }
        }
        }
        $geometryRows += [pscustomobject]@{ Utility = $utility; Border = $border; ColumnWidth = $columnWidth; Scale = $suiteScale; TitleFontSize = $titleSize; Columns = $columns; InfoHeight = $infoHeight; BarThickness = $barThickness; Window = "${windowWidth}x${windowHeight}" }
}
}
}
}
}
}
}
}
$geometryRows | Format-Table -AutoSize
$mainCases = @($geometryRows | Where-Object { -not $_.Utility }).Count
$utilityCases = @($geometryRows | Where-Object { $_.Utility }).Count
Write-Output "RAM source checks passed: $checks assertions across $mainCases RAM and $utilityCases dedicated-settings geometry cases (border 0/1/4; title sizes 6/10/12; hardware heights 26/80/188; bar thickness 1/6/6.25/12). This source check does not verify live rendering, telemetry, persistence or CPU cost."
