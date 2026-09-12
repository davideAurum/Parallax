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
$measures = Read-RAMIni (Join-Path $PSScriptRoot 'Measures.inc')
$meters = Read-RAMIni (Join-Path $PSScriptRoot 'Meters.inc')
$info = Read-RAMIni (Join-Path $PSScriptRoot 'InfoMeters.inc')
$menu = Read-RAMIni (Join-Path $PSScriptRoot 'SettingsMeters.inc')
foreach ($layer in @($info)) {
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
Assert-RAM ($entry.Rainmeter.ContextAction -eq '[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'Shared Settings action is incorrect.'
$expectedIncludes = @('#@#Defaults.inc', '#@#User\Settings.inc', '#@#User\RAM.inc', '#@#Geometry.inc', '#@#Styles.inc')
for ($i = 0; $i -lt $expectedIncludes.Count; $i++) {
    Assert-RAM ($entry.Variables[('@Include{0}' -f ($i + 1))] -eq $expectedIncludes[$i]) 'Shared include order changed.'
}
foreach ($key in $entry.Variables.Keys | Where-Object { $_ -like 'RAM*' }) {
    Assert-RAM ($user.Variables.ContainsKey($key)) "Module option $key has no preserved default."
}
foreach ($name in 'MeasureRAMUsed', 'MeasureRAMAvailable', 'MeasureRAMTotal') {
    Assert-RAM ($measures[$name].Measure -eq 'PhysicalMemory') "$name must use native PhysicalMemory."
    Assert-RAM ($measures[$name].UpdateDivider -eq '1') "$name does not sample at MetricsInterval."
    Assert-RAM (-not $measures[$name].ContainsKey('MaxValue')) "$name must retain its native normalization."
}
Assert-RAM ($measures.MeasureRAMAvailable.InvertMeasure -eq '1') 'Available must invert native physical memory.'
Assert-RAM ($measures.MeasureRAMTotal.Total -eq '1') 'Total must request native physical memory total.'
Assert-RAM ($meters.MeterRAMPercent.Percentual -eq '1') 'Percentage must use native normalization.'
foreach ($name in 'MeterRAMPercent', 'MeterRAMBar', 'MeterRAMHistory') {
    Assert-RAM ($meters[$name].MeasureName -eq 'MeasureRAMUsed') "$name lost its native used-memory binding."
}
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
Assert-RAM ($entry.Rainmeter.OnRefreshAction -eq '[!CommandMeasure MeasureRAMInfo "Run"]') 'Hardware metadata must query once per refresh.'
Assert-RAM ($measures.MeasureRAMInfoView.Measure -eq 'Script') 'Missing hardware view controller.'
$includeValues = @($entry.Variables.Keys | Where-Object { $_ -like '@Include*' } | Sort-Object { [int]($_ -replace '@Include','') } | ForEach-Object { $entry.Variables[$_] })
Assert-RAM ($includeValues[-1] -eq '#@#Modules\RAM\InfoMeters.inc') 'Missing hardware meters.'
Assert-RAM ($includeValues -notcontains '#@#Modules\RAM\SettingsMeters.inc') 'Settings controls must not overlay the RAM meter.'
Assert-RAM ($settingsEntry.Rainmeter.Update -eq '-1') 'Settings utility must not poll.'
Assert-RAM ($settingsEntry.Rainmeter.Group -eq 'Parallax') 'Settings utility must participate in shared appearance refreshes.'
Assert-RAM ($settingsEntry.Rainmeter.ContextAction -eq '[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'Settings utility lost global settings access.'
Assert-RAM ($settingsEntry.Variables.Columns -eq '2' -and $settingsEntry.Variables.PanelHeight -eq '248') 'Settings utility must own its layout independently of the meter.'
for ($i = 0; $i -lt $expectedIncludes.Count; $i++) {
    Assert-RAM ($settingsEntry.Variables[('@Include{0}' -f ($i + 1))] -eq $expectedIncludes[$i]) 'Utility shared include order changed.'
}
$settingsMeasures = @($settingsEntry.Keys | Where-Object { $settingsEntry[$_].ContainsKey('Measure') })
Assert-RAM ($settingsMeasures.Count -eq 1 -and $settingsMeasures[0] -eq 'MeasureRAMSettings') 'Settings utility must not collect telemetry or hardware metadata.'
Assert-RAM ($settingsEntry.MeasureRAMSettings.ScriptFile -eq '#@#Modules\RAM\Settings.lua') 'Settings utility must own its preferences controller.'
Assert-RAM ($menu.MeterRAMSettingsClose.LeftMouseUpAction -eq '[!DeactivateConfig]') 'Closing settings must deactivate only its own config.'
$settingsScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Settings.lua') -Raw
$displayScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Display.lua') -Raw
Assert-RAM ($settingsScript -match '!SetVariableGroup' -and $settingsScript -match 'ParallaxRAM' -and $settingsScript -match '!UpdateMeasureGroup' -and $settingsScript -match 'ParallaxRAMApply') 'Preferences must reach the running RAM skin without refreshing it.'
Assert-RAM ($settingsScript -notmatch '!Refresh|MeasureRAMInfo|MeasureRAMHistory|!UpdateMeter.*,.*\*') 'Settings must not refresh RAM, query hardware, or force its history.'
Assert-RAM ($displayScript -notmatch '!Refresh|!WriteKeyValue|ToggleMenu|RAMSettingsMenu') 'Display controller must not persist preferences or own an overlay.'
foreach ($pair in @(@('Units','RAMUseMiB'), @('Decimals','RAMDecimals'), @('PercentDecimals','RAMPercentDecimals'), @('Bar','RAMShowBar'), @('History','RAMShowHistory'))) {
    foreach ($suffix in '', 'Label', 'Row') {
        $name = 'MeterRAMSettings' + $pair[0] + $suffix
        Assert-RAM ($menu[$name].LeftMouseUpAction -eq ('[!CommandMeasure MeasureRAMSettings "Cycle(''{0}'')"]' -f $pair[1])) "$name must operate the corresponding setting."
        Assert-RAM ($menu[$name].ToolTipText.Length -gt 10) "$name requires a descriptive tooltip."
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
    $value = [double](Invoke-Expression $expanded)
    $script:numberCache[$cacheKey] = $value
    $script:contextNumberCache[$contextKey] = $value
    return $value
}
foreach ($name in 'MeterRAMTitle') {
    $meter = Get-RAMMeter $name
    Assert-RAM ($meter.FontColor -eq '#TitleTextColor#' -and $meter.FontSize -eq '(#TitleFontSize#*#Scale#)') "$name must inherit title typography."
}
foreach ($name in 'MeterRAMInfoHeading', 'MeterRAMSubtitle', 'MeterRAMHistoryLabel') {
    $meter = Get-RAMMeter $name
    Assert-RAM ($meter.FontColor -eq '#HeaderTextColor#' -and $meter.FontSize -eq '(#HeaderFontSize#*#Scale#)') "$name must inherit section-header typography."
}
Assert-RAM ($menu.StyleRAMSettingsSection.FontColor -eq '#HeaderTextColor#' -and $menu.StyleRAMSettingsSection.FontSize -eq '(#HeaderFontSize#*#Scale#)') 'Settings sections must use semantic header typography.'
Assert-RAM ($menu.StyleRAMSettingsLabel.FontColor -eq '#TextColor#' -and $menu.StyleRAMSettingsLabel.FontSize -eq '(#FontSize#*#Scale#)') 'Settings labels must use body typography.'
Assert-RAM ($menu.StyleRAMSettingsValue.FontColor -eq '#AccentColor#') 'Settings choices must use the primary action accent.'
Assert-RAM ($menu.MeterRAMSettingsClose.MeterStyle -match 'StyleSecondaryButton') 'Settings close must use the secondary action accent.'
foreach ($field in 'Installed','Type','Speed','Devices','Form') {
    $meter = Get-RAMMeter "MeterRAMInfo$field"
    Assert-RAM ($meter.Meter -eq 'String') "Hardware field $field must use text for availability."
    Assert-RAM ($meter.Group -eq 'RAMHardwareInfo') "Hardware field $field cannot be updated separately from history."
    Assert-RAM ($meter.ClipString -eq '1') "Hardware field $field must clip long metadata."
    Assert-RAM ($meter.Text -eq 'Checking...') "Hardware field $field must not start with invented metadata."
}
foreach ($kind in 'Used', 'Available', 'Total') {
    foreach ($unit in 'GiB', 'MiB') {
        $meter = Get-RAMMeter "MeterRAM$kind$unit"
        $expectedDivisor = if ($unit -eq 'GiB') { 1073741824.0 } else { 1048576.0 }
        Assert-RAM ([double]$meter.Scale -eq $expectedDivisor) "Incorrect $unit divisor."
        Assert-RAM ($meter.Text -eq "%1 $unit") "Incorrect $unit label."
        Assert-RAM ($meter.MeasureName -eq "MeasureRAM$kind") "Incorrect $kind binding."
        Assert-RAM ($meter.AutoScale -eq '0') 'Automatic units would override the explicit byte divisor.'
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
        foreach ($layer in $settingsEntry, $menu) {
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
foreach ($columnWidth in 180, 200, 240, 280, 320) {
foreach ($suiteScale in 0.75, 1, 1.25, 1.5, 2) {
    foreach ($columns in $columnCases) {
        $variables.ColumnWidth = [string]$columnWidth
        $variables.Scale = $suiteScale.ToString([Globalization.CultureInfo]::InvariantCulture)
        $variables.Columns = [string]$columns
        $contextNumberCache = @{}
        $windowWidth = Get-RAMNumber '#WindowWidth#'
        # RAM preserves older user PanelHeight values while giving the new
        # hardware panel and configurable graph an actual minimum window.
        $windowHeight = if ($utility) { Get-RAMNumber '#WindowHeight#' } else { Get-RAMNumber $meters.MeterRAMBounds.H }
        $inset = Get-RAMNumber '#Inset#'
        $contentWidth = Get-RAMNumber '#ContentWidth#'
        Assert-RAM ($contentWidth -gt 0) 'Nonpositive content width.'
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
                $minX = [Math]::Min($minX, [Math]::Min($x1, $x2) - $stroke / 2)
                $minY = [Math]::Min($minY, [Math]::Min($y1, $y2) - $stroke / 2)
                $maxX = [Math]::Max($maxX, [Math]::Max($x1, $x2) + $stroke / 2)
                $maxY = [Math]::Max($maxY, [Math]::Max($y1, $y2) + $stroke / 2)
                }
                $x += $minX; $y += $minY
                $width = $maxX - $minX; $height = $maxY - $minY
            } else {
                $width = Get-RAMNumber $meter.W
                $height = Get-RAMNumber $meter.H
            }
            if ($meter.ContainsKey('StringAlign') -and $meter.StringAlign -eq 'Right') { $x -= $width }
            Assert-RAM ($width -ge 0 -and $height -ge 0) "Negative size on $name."
            Assert-RAM ($x -ge 0 -and $y -ge 0 -and $x + $width -le $windowWidth + 0.001 -and $y + $height -le $windowHeight + 0.001) "$name leaves its window at scale $suiteScale / columns $columns."
            if ($name -notin 'MeterRAMBounds', 'MeterRAMSettingsBounds') {
                Assert-RAM ($x -ge $inset -and $y -ge $inset -and $x + $width -le $windowWidth - $inset + 0.001 -and $y + $height -le $windowHeight - $inset + 0.001) "$name enters the transparent gutter."
            }
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
        $geometryRows += [pscustomobject]@{ Utility = $utility; Border = $border; ColumnWidth = $columnWidth; Scale = $suiteScale; Columns = $columns; Window = "${windowWidth}x${windowHeight}" }
    }
}
}
}
}
$geometryRows | Format-Table -AutoSize
Write-Output "RAM source checks passed: $checks assertions across 150 RAM and 75 dedicated-settings geometry cases (border 0/1/4). This source check does not verify live rendering, telemetry, persistence or CPU cost."
