# Offline discovery contract checks. No HWiNFO, Rainmeter, registry access, or
# writes are needed: load only the pure functions from the source AST. The list
# branch is exercised with a local Get-Process mock, never the native command.
# Run: powershell -NoProfile -File .\Test-DiscoverSensors.ps1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$helperPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'DiscoverSensors.ps1'
$parseTokens = $null
$parseErrors = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $helperPath, [ref] $parseTokens, [ref] $parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }

foreach ($functionName in @('ConvertTo-CPUPrecisionValue', 'Get-CPUPrecisionResponse', 'Invoke-CPUPrecisionInput',
        'ConvertTo-CPUSensorCandidate', 'Select-CPUExport', 'Format-CPUExportCandidates', 'Format-CPUCoreCandidates')) {
    $definitions = @($sourceAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
    }, $false))
    if ($definitions.Count -ne 1) { throw ('Expected one pure function: ' + $functionName) }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}

$script:checks = 0
function Assert-Fixture {
    param([bool] $Condition, [string] $Name)
    if (-not $Condition) { throw ('FAIL ' + $Name) }
    $script:checks++
    'PASS ' + $Name
}

# Precision editing uses the same explicitly invoked helper that is packaged for
# HWiNFO discovery. Validate-only returns before any WinForms work, allowing its
# bounded command protocol to be checked without showing a native editor.
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUDecimals' -ValidateOnly -Value '1') -ceq
    'PARALLAX_CPU_DECIMAL_V1|ok|1') 'percentage precision valid'
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUVoltageDecimals' -ValidateOnly -Value '03') -ceq
    'PARALLAX_CPU_DECIMAL_V1|ok|3') 'voltage precision normalizes bounded integer'
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUDecimals' -ValidateOnly -Value '2') -ceq
    'PARALLAX_CPU_DECIMAL_V1|cancel|') 'percentage precision upper bound'
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUTemperatureDecimals' -ValidateOnly -Value '1.0') -ceq
    'PARALLAX_CPU_DECIMAL_V1|cancel|') 'precision requires whole number'
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUVoltageDecimals' -ValidateOnly -Value '[!Quit]') -ceq
    'PARALLAX_CPU_DECIMAL_V1|cancel|') 'precision text remains data'
Assert-Fixture ((Invoke-CPUPrecisionInput -InputKey 'CPUDecimals' -Cancelled) -ceq
    'PARALLAX_CPU_DECIMAL_V1|cancel|') 'precision cancellation is explicit'

function New-Fixture {
    param(
        [int] $Index,
        [string] $Sensor,
        [string] $Label,
        [string] $Raw,
        [string] $Formatted,
        [string] $SourceHive = 'HKEY_CURRENT_USER'
    )
    $fixtureValues = @{}
    $fixtureValues['Sensor' + $Index] = $Sensor
    $fixtureValues['Label' + $Index] = $Label
    $fixtureValues['ValueRaw' + $Index] = $Raw
    $fixtureValues['Value' + $Index] = $Formatted
    ConvertTo-CPUSensorCandidate -Values $fixtureValues -Index $Index -SourceHive $SourceHive
}

$temperature = New-Fixture 0 'CPU [#0]: Example' 'CPU Package' '42' ('42 ' + [char]176 + 'C')
$vid = New-Fixture 1 'CPU [#0]: Example' 'Core VIDs' '1.234' '1.234 V'
$vcore = New-Fixture 2 'Example Board: Nuvoton' 'Vcore' '1.1' '1.100 V'
$clock = New-Fixture 12 'CPU [#0]: Example' 'Core Clocks' '3906.1' '3906.1 MHz'
$clockGHz = New-Fixture 13 'CPU [#0]: Example' 'Core Clocks' '3.9061' '3.9061 GHz'

Assert-Fixture ($temperature.Kind -eq 'TEMP' -and $temperature.Unit -eq 'C') 'CPU package temperature'
Assert-Fixture ($vid.VoltageKind -eq 'VID') 'VID stays requested voltage'
Assert-Fixture ((Select-CPUExport @($vid, $vcore) 'VOLT' -1) -match '\|2\|.*\|V\|VCORE$') 'measured Vcore preferred'
Assert-Fixture ((Select-CPUExport @($vid, $vcore) 'VOLT' 1) -match '\|1\|.*\|V\|VID$') 'explicit VID valid'
Assert-Fixture ($clock.Kind -eq 'CLOCK' -and $clock.Scope -eq 'AGGREGATE' -and $clock.Unit -eq 'MHz') 'CPU-wide Core Clocks accepts MHz'
Assert-Fixture ($clockGHz.Kind -eq 'CLOCK' -and $clockGHz.Scope -eq 'AGGREGATE' -and $clockGHz.Unit -eq 'GHz') 'CPU-wide Core Clocks accepts GHz'
Assert-Fixture ((Select-CPUExport @($clock) 'CLOCK' -1) -match '^CLOCK\|HKEY_CURRENT_USER\|12\|.*\|MHz$') 'automatic Core Clocks export uses CLOCK protocol'
Assert-Fixture ($null -eq (New-Fixture 3 'GPU [#0]: Example' 'Vcore' '1.0' '1.0 V')) 'GPU Vcore rejected'
Assert-Fixture ($null -eq (New-Fixture 4 'GPU [#0]: Example' 'CPU Package' '42' '42 C')) 'non-CPU package rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#1]: Example' 'Core VIDs' '1.0' '1.0 V')) 'other CPU rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'Core #0 VID' '1.0' '1.0 V')) 'unsupported core VID label rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' 'NaN' '42 C')) 'NaN rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' 'Infinity' '42 C')) 'infinity rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' '42,5' '42.5 C')) 'localized raw rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' '42' '42 W')) 'wrong unit rejected'
Assert-Fixture ($null -eq (New-Fixture 4097 'CPU [#0]: Example' 'CPU Package' '42' '42 C')) 'index bound'
Assert-Fixture ($null -eq (New-Fixture 14 'CPU [#0]: Example' 'Core Clock' '3906.1' '3906.1 MHz') -and
    $null -eq (New-Fixture 15 'CPU [#0]: Example' 'Core 0 Clock' '3906.1' '3906.1 MHz') -and
    $null -eq (New-Fixture 16 'CPU [#0]: Example' 'Core Effective Clocks' '3906.1' '3906.1 MHz') -and
    $null -eq (New-Fixture 17 'CPU [#0]: Example' 'Bus Clock' '100' '100 MHz')) 'only exact aggregate Core Clocks label is accepted'
Assert-Fixture ($null -eq (New-Fixture 18 'CPU [#1]: Example' 'Core Clocks' '3906.1' '3906.1 MHz') -and
    $null -eq (New-Fixture 19 'GPU [#0]: Example' 'Core Clocks' '3906.1' '3906.1 MHz') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example' 'Core Clocks' '3906.1' '3906.1 V')) 'non-primary CPU and wrong-unit clocks rejected'

$mirror = New-Fixture 0 'CPU [#0]: Example' 'CPU Package' '44' '44 C' 'HKEY_LOCAL_MACHINE'
Assert-Fixture ((Select-CPUExport @($temperature, $mirror) 'TEMP' -1) -match '^TEMP\|HKEY_CURRENT_USER\|0\|') 'mirrored mapping deduplicated'
$clockMirror = New-Fixture 12 'CPU [#0]: Example' 'Core Clocks' '3800' '3800 MHz' 'HKEY_LOCAL_MACHINE'
Assert-Fixture ((Select-CPUExport @($clock, $clockMirror) 'CLOCK' -1) -match '^CLOCK\|HKEY_CURRENT_USER\|12\|') 'mirrored Core Clocks mapping deduplicated'
$otherClock = New-Fixture 21 'CPU [#0]: Example: Enhanced' 'Core Clocks' '4200' '4200 MHz'
Assert-Fixture ((Select-CPUExport @($clock, $otherClock) 'CLOCK' -1) -match '^STATUS\|Ambiguous') 'ambiguous Core Clocks exports are unavailable'
$otherTemperature = New-Fixture 7 'CPU [#0]: Example: Enhanced' 'CPU Package' '45' '45 C'
Assert-Fixture ((Select-CPUExport @($temperature, $otherTemperature) 'TEMP' -1) -match '^STATUS\|Ambiguous') 'ambiguous temperature rejected'
Assert-Fixture ((Select-CPUExport @($temperature, $otherTemperature) 'TEMP' 7) -match '^TEMP\|HKEY_CURRENT_USER\|7\|') 'explicit index resolves ambiguity'
$otherVcore = New-Fixture 8 'Other board sensor' 'VR VOUT' '1.0' '1.0 V'
Assert-Fixture ((Select-CPUExport @($vid, $vcore, $otherVcore) 'VOLT' -1) -match '^STATUS\|Ambiguous') 'ambiguous Vcore does not fall back to VID'

Assert-Fixture ((New-Fixture 9 'CPU [#0]: Example' 'CPU Package' '105.8' '105.8 F').Unit -eq 'F') 'Fahrenheit supported'
Assert-Fixture ((New-Fixture 10 'CPU [#0]: Example' 'Core VIDs' '1234' '1,234 mV').Unit -eq 'mV') 'millivolts supported'
Assert-Fixture ((Select-CPUExport @($temperature) 'TEMP' 22) -match '^STATUS\|Requested') 'missing explicit index reported'
Assert-Fixture ((Select-CPUExport @() 'TEMP' -1) -match '^STATUS\|No exported') 'no candidates safe'
$missing = @{'Sensor0' = 'CPU [#0]: Example'; 'Label0' = 'CPU Package'; 'ValueRaw0' = '42'}
Assert-Fixture ($null -eq (ConvertTo-CPUSensorCandidate $missing 0 'HKEY_CURRENT_USER')) 'incomplete tuple rejected'

# Preserve identity whitespace and encode non-ASCII safely in the flat protocol.
$exactSensor = ' CPU [#0]: Example ' + [char]0x2122 + ' '
$exactLabel = 'CPU Package '
$exact = New-Fixture 11 $exactSensor $exactLabel '42' '42 C'
$line = Select-CPUExport @($exact) 'TEMP' -1
$sensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($exactSensor)).Replace('-', '')
$labelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($exactLabel)).Replace('-', '')
$expected = 'TEMP|HKEY_CURRENT_USER|11|' + $sensorHex + '|' + $labelHex + '|C'
Assert-Fixture ($exact.Sensor -ceq $exactSensor -and $exact.Label -ceq $exactLabel -and
    $line -ceq $expected -and $line -notmatch '[^\x00-\x7F]') 'exact UTF-8 identity encoded as ASCII hex'

$exactList = @(Format-CPUExportCandidates @($exact))
Assert-Fixture ($exactList.Count -eq 1 -and $exactList[0] -ceq ('CAND|' + $expected + '|')) 'candidate retains exact UTF-8 identity and empty temperature kind'
Assert-Fixture ($exactList[0].Split('|').Length -eq 8 -and $exactList[0] -notmatch '[^\x00-\x7F]') 'candidate protocol has eight ASCII fields and no reading'
$clockSensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes('CPU [#0]: Example')).Replace('-', '')
$clockLabelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes('Core Clocks')).Replace('-', '')
$clockExpected = 'CLOCK|HKEY_CURRENT_USER|12|' + $clockSensorHex + '|' + $clockLabelHex + '|MHz'
$clockLine = Select-CPUExport @($clock) 'CLOCK' -1
$clockList = @(Format-CPUExportCandidates @($clock))
Assert-Fixture ($clockLine -ceq $clockExpected -and $clockLine.Split('|').Length -eq 6 -and
    $clockList.Count -eq 1 -and $clockList[0] -ceq ('CAND|' + $clockExpected + '|') -and
    $clockList[0].Split('|').Length -eq 8) 'CLOCK uses an ASCII aggregate record and an empty candidate kind field'
$voltageList = @(Format-CPUExportCandidates @($vcore, $vid))
Assert-Fixture ($voltageList.Count -eq 2 -and
    $voltageList[0] -ceq ('CAND|' + (Select-CPUExport @($vid) 'VOLT' -1)) -and
    $voltageList[1] -ceq ('CAND|' + (Select-CPUExport @($vcore) 'VOLT' -1))) 'voltage candidates preserve VCORE and VID kinds'
$mirrorList = @(Format-CPUExportCandidates @($mirror, $temperature))
Assert-Fixture ($mirrorList.Count -eq 2 -and
    $mirrorList[0] -match '^CAND\|TEMP\|HKEY_CURRENT_USER\|' -and
    $mirrorList[1] -match '^CAND\|TEMP\|HKEY_LOCAL_MACHINE\|') 'candidate list keeps both mirrored hives in stable order'
$mixed = @(Format-CPUExportCandidates @($vcore, $exact, $mirror, $temperature))
Assert-Fixture ($mixed.Count -eq 4 -and
    $mixed[0] -match '^CAND\|TEMP\|HKEY_CURRENT_USER\|0\|' -and
    $mixed[1] -match '^CAND\|TEMP\|HKEY_CURRENT_USER\|11\|' -and
    $mixed[2] -match '^CAND\|TEMP\|HKEY_LOCAL_MACHINE\|0\|' -and
    $mixed[3] -match '^CAND\|VOLT\|HKEY_CURRENT_USER\|2\|') 'candidate order is kind then hive then numeric index'
$many = @(foreach ($index in 160..0) { New-Fixture $index 'CPU [#0]: Example' 'CPU Package' '42' '42 C' })
$bounded = @(Format-CPUExportCandidates $many)
Assert-Fixture ($bounded.Count -eq 128 -and
    $bounded[0] -match '^CAND\|TEMP\|HKEY_CURRENT_USER\|0\|' -and
    $bounded[127] -match '^CAND\|TEMP\|HKEY_CURRENT_USER\|127\|') 'candidate cap applies after numeric sorting'
Assert-Fixture (@(Format-CPUExportCandidates @()).Count -eq 0) 'empty candidate list emits no candidate records'

$coreVoltage = New-Fixture 17 'CPU [#0]: Example' 'Core 0 VID' '1.234' '1.234 V'
$coreTemperature = New-Fixture 18 'CPU [#0]: Example: DTS' 'Core 63' '42' '42 C'
Assert-Fixture ($coreVoltage.Scope -eq 'CORE' -and $coreVoltage.Kind -eq 'VOLT' -and
    $coreVoltage.CoreId -eq 0 -and $coreVoltage.VoltageKind -eq 'VID') 'individual core VID has physical core identity and requested voltage kind'
Assert-Fixture ($coreTemperature.Scope -eq 'CORE' -and $coreTemperature.Kind -eq 'TEMP' -and
    $coreTemperature.CoreId -eq 63) 'DTS temperature accepts highest supported core identity'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#0]: Example: DTS' 'Core 64' '42' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example' 'Core 64 VID' '1.2' '1.2 V')) 'core identity above63 rejected'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#0]: Example: DTS' 'Core 00' '42' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example' 'Core 00 VID' '1.2' '1.2 V')) 'ambiguous leading-zero core identity rejected'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#1]: Example: DTS' 'Core 0' '42' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#1]: Example' 'Core 0 VID' '1.2' '1.2 V')) 'per-core exports from another CPU rejected'
Assert-Fixture ($null -eq (New-Fixture 19 'dGPU [#0]: Example: DTS' 'Core 0' '42' '42 C') -and
    $null -eq (New-Fixture 20 'GPU [#0]: Example' 'Core 0 VID' '1.2' '1.2 V')) 'GPU per-core lookalikes rejected'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#0]: Example' 'Core 0' '42' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example: DTS: Other' 'Core 0' '42' '42 C')) 'individual temperatures require group ending DTS'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#0]: Example: DTS' 'Core 0 Distance to TjMAX' '42' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example: DTS' 'Core Distance to TjMAX' '42' '42 C')) 'TjMAX distances remain excluded'
Assert-Fixture ($null -eq (New-Fixture 19 'CPU [#0]: Example: DTS' 'Core 0' 'NaN' '42 C') -and
    $null -eq (New-Fixture 20 'CPU [#0]: Example' 'Core 0 VID' '1.2' '1.2 F')) 'core tuples retain finite number and unit validation'
$coreFahrenheit = New-Fixture 19 'CPU [#0]: Example: DTS' 'Core 2' '104' '104 F'
$coreMillivolts = New-Fixture 20 'CPU [#0]: Example' 'Core 2 VID' '1234' '1,234 mV'
Assert-Fixture ($coreFahrenheit.Unit -eq 'F' -and $coreMillivolts.Unit -eq 'mV') 'per-core Fahrenheit and millivolts preserved'
$coreLines = @(Format-CPUCoreCandidates @($coreVoltage, $coreTemperature))
Assert-Fixture ($coreLines.Count -eq 2 -and $coreLines[0] -match '^CORE\|TEMP\|63\|HKEY_CURRENT_USER\|18\|.*\|C\|$' -and
    $coreLines[1] -match '^CORE\|VOLT\|0\|HKEY_CURRENT_USER\|17\|.*\|V\|VID$' -and
    $coreLines[0].Split('|').Length -eq 9 -and $coreLines[1].Split('|').Length -eq 9) 'CORE protocol has nine fields with temperature empty kind and VID voltage kind'
$coreQuotedSensor = ' CPU [#0]: Example ' + [char]0x2122 + ': DTS '
$coreExact = New-Fixture 21 $coreQuotedSensor 'Core 0 ' '42' '42 C'
$coreExactLines = @(Format-CPUCoreCandidates @($coreExact))
$coreExactHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($coreQuotedSensor)).Replace('-', '')
Assert-Fixture ($coreExactLines[0].Contains('|' + $coreExactHex + '|436F7265203020|C|') -and
    $coreExactLines[0] -notmatch '[^\x00-\x7F]') 'CORE preserves exact identities as ASCII hex'
Assert-Fixture ((Select-CPUExport @($coreVoltage, $coreTemperature) 'VOLT' -1) -match '^STATUS\|No exported' -and
    (Select-CPUExport @($coreVoltage, $coreTemperature) 'TEMP' -1) -match '^STATUS\|No exported') 'individual cores never replace shared automatic aggregate records'
Assert-Fixture ((Select-CPUExport @($coreVoltage) 'VOLT' 17) -match '^STATUS\|Requested' -and
    @(Format-CPUExportCandidates @($coreVoltage, $coreTemperature)).Count -eq 0) 'manual aggregate choices and CAND records exclude individual cores'
$coreMirror = New-Fixture 17 'CPU [#0]: Example' 'Core 0 VID' '1.230' '1.230 V' 'HKEY_LOCAL_MACHINE'
$coreMirrors = @(Format-CPUCoreCandidates @($coreMirror, $coreVoltage))
Assert-Fixture ($coreMirrors.Count -eq 1 -and $coreMirrors[0] -match '^CORE\|VOLT\|0\|HKEY_CURRENT_USER\|17\|') 'identical per-core mirror resolves to current user'
$coreConflict = New-Fixture 17 'CPU [#0]: Another sensor' 'Core 0 VID' '1.2' '1.2 V' 'HKEY_LOCAL_MACHINE'
Assert-Fixture (@(Format-CPUCoreCandidates @($coreVoltage, $coreConflict)).Count -eq 0) 'conflicting per-core sensor identities suppressed'
$coreIndexConflict = New-Fixture 22 'CPU [#0]: Example' 'Core 0 VID' '1.2' '1.2 V'
Assert-Fixture (@(Format-CPUCoreCandidates @($coreVoltage, $coreIndexConflict)).Count -eq 0) 'multiple exports for one core remain ambiguous'
$coreUnitConflict = New-Fixture 18 'CPU [#0]: Example: DTS' 'Core 63' '104' '104 F' 'HKEY_LOCAL_MACHINE'
Assert-Fixture (@(Format-CPUCoreCandidates @($coreTemperature, $coreUnitConflict)).Count -eq 0) 'conflicting per-core units suppressed'
Assert-Fixture (@(Format-CPUCoreCandidates @($coreTemperature, $coreVoltage, $coreConflict)).Count -eq 1) 'one ambiguous core does not discard unrelated core mappings'
$coreTen = New-Fixture 23 'CPU [#0]: Example: DTS' 'Core 10' '42' '42 C'
$coreOrdered = @(Format-CPUCoreCandidates @($coreTemperature, $coreTen, $coreFahrenheit))
Assert-Fixture ($coreOrdered[0] -match '^CORE\|TEMP\|2\|' -and
    $coreOrdered[1] -match '^CORE\|TEMP\|10\|' -and $coreOrdered[2] -match '^CORE\|TEMP\|63\|') 'CORE records use numeric core ordering'
$allCores = @(foreach ($coreNumber in 63..0) {
    New-Fixture $coreNumber 'CPU [#0]: Example' ('Core ' + $coreNumber + ' VID') '1.2' '1.2 V'
    New-Fixture (100 + $coreNumber) 'CPU [#0]: Example: DTS' ('Core ' + $coreNumber) '42' '42 C'
})
$allCoreLines = @(Format-CPUCoreCandidates $allCores)
Assert-Fixture ($allCoreLines.Count -eq 128 -and $allCoreLines[0] -match '^CORE\|TEMP\|0\|' -and
    $allCoreLines[127] -match '^CORE\|VOLT\|63\|') 'full supported core set is bounded to128 records'

$average = New-Fixture 24 'CPU [#0]: Example: DTS' 'Core Temperatures' '42' '42 C'
$tctl = New-Fixture 25 'CPU [#0]: Example' 'CPU (Tctl/Tdie)' '42' '42 C'
Assert-Fixture ($average.Scope -eq 'AGGREGATE' -and
    (Select-CPUExport @($average) 'TEMP' -1) -match '^TEMP\|HKEY_CURRENT_USER\|24\|') 'Core Temperatures average is available as aggregate fallback'
Assert-Fixture ((Select-CPUExport @($average, $temperature) 'TEMP' -1) -match '^TEMP\|HKEY_CURRENT_USER\|0\|') 'CPU Package preferred over core average in Auto'
Assert-Fixture ((Select-CPUExport @($average, $tctl) 'TEMP' -1) -match '^TEMP\|HKEY_CURRENT_USER\|25\|') 'CPU Tctl preferred over core average in Auto'
Assert-Fixture ((Select-CPUExport @($average, $temperature) 'TEMP' 24) -match '^TEMP\|HKEY_CURRENT_USER\|24\|') 'explicit core-average aggregate selection remains available'
Assert-Fixture ((Select-CPUExport @($average, $temperature, $otherTemperature) 'TEMP' -1) -match '^STATUS\|Ambiguous') 'ambiguous package readings do not silently fall back to average'
Assert-Fixture ($null -eq (New-Fixture 24 'GPU [#0]: Example' 'Core Temperatures' '42' '42 C')) 'GPU core average is not a CPU aggregate fallback'

# Evaluate only the optional request/list branches. Get-Process is replaced locally so
# these checks neither enumerate processes nor execute the registry startup.
$listBranches = @($sourceAst.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.IfStatementAst] -and
        $_.Extent.Text.TrimStart().StartsWith('if ($List)')
})
if ($listBranches.Count -ne 1) { throw 'Expected exactly one optional -List branch' }
$requestBranches = @($sourceAst.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.IfStatementAst] -and
        $_.Extent.Text.TrimStart().StartsWith('if ($List -or $RequestId -gt 0)')
})
if ($requestBranches.Count -ne 1) { throw 'Expected exactly one request correlation branch' }
$coreBranches = @($sourceAst.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.IfStatementAst] -and
        $_.Extent.Text.TrimStart().StartsWith('if ($CoreList -or $List)')
})
if ($coreBranches.Count -ne 1) { throw 'Expected exactly one per-core list branch' }
$listBlock = [scriptblock]::Create($requestBranches[0].Extent.Text + "`n" + $listBranches[0].Extent.Text + "`n" + $coreBranches[0].Extent.Text)
$script:processCalls = 0
$script:hwinfoRunning = $false
function Get-Process {
    param([string] $Name, [string] $ErrorAction)
    if ($Name -cne 'HWiNFO64' -or $ErrorAction -cne 'SilentlyContinue') {
        throw 'Unexpected process lookup'
    }
    $script:processCalls++
    if ($script:hwinfoRunning) { [pscustomobject]@{ProcessName = 'HWiNFO64'} }
}
$candidates = @($temperature, $vid)
$List = $false
$CoreList = $false
$RequestId = 0
$disabledList = @(. $listBlock)
Assert-Fixture ($disabledList.Count -eq 0 -and $script:processCalls -eq 0) 'default mode adds no records or process lookup'
$RequestId = 17
$correlated = @(. $listBlock)
Assert-Fixture ($correlated.Count -eq 1 -and $correlated[0] -ceq 'REQUEST|17' -and
    $script:processCalls -eq 0) 'positive request id adds correlation without state, candidates or process lookup'
$List = $true
$RequestId = 0
$stoppedList = @(. $listBlock)
Assert-Fixture ($stoppedList.Count -eq 4 -and $stoppedList[1] -ceq 'STATE|STOPPED' -and
    $script:processCalls -eq 1) 'list mode reports stopped with one process lookup'
Assert-Fixture ($stoppedList[0] -ceq 'REQUEST|0') 'list mode echoes default request id'
$script:hwinfoRunning = $true
$RequestId = 2147483647
$runningList = @(. $listBlock)
Assert-Fixture ($runningList.Count -eq 4 -and $runningList[1] -ceq 'STATE|RUNNING' -and
    $script:processCalls -eq 2) 'list mode reports running with one process lookup'
Assert-Fixture ($runningList[0] -ceq 'REQUEST|2147483647') 'list mode echoes maximum request id without numeric formatting'
Assert-Fixture (($runningList[2..3] -join "`n") -ceq ($stoppedList[2..3] -join "`n")) 'process state does not change validated candidate records'

$candidates = @($temperature, $vid, $coreTemperature, $coreVoltage)
$List = $false
$CoreList = $true
$RequestId = 26
$coreOnlyOutput = @(. $listBlock)
Assert-Fixture ($coreOnlyOutput.Count -eq 3 -and $coreOnlyOutput[0] -ceq 'REQUEST|26' -and
    $coreOnlyOutput[1] -match '^CORE\|TEMP\|' -and $coreOnlyOutput[2] -match '^CORE\|VOLT\|' -and
    $script:processCalls -eq 2) 'CoreList emits correlation and core mappings without process lookup'
$List = $true
$CoreList = $false
$combinedOutput = @(. $listBlock)
Assert-Fixture ($combinedOutput.Count -eq 6 -and
    @($combinedOutput | Where-Object { $_ -match '^CAND\|' }).Count -eq 2 -and
    @($combinedOutput | Where-Object { $_ -match '^CORE\|' }).Count -eq 2 -and
    $script:processCalls -eq 3) 'List includes shared choices and core coverage records'
$candidates = @($clock)
$List = $true
$CoreList = $false
$RequestId = 27
$clockListOutput = @(. $listBlock)
Assert-Fixture ($clockListOutput.Count -eq 3 -and $clockListOutput[0] -ceq 'REQUEST|27' -and
    $clockListOutput[2] -ceq ('CAND|' + $clockExpected + '|') -and
    $script:processCalls -eq 4) 'List exposes the exact aggregate CLOCK candidate without a reading'

'PASS ' + $script:checks + ' offline discovery checks; helper parsed; no registry or process access'
