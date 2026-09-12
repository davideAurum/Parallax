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

foreach ($functionName in @('ConvertTo-CPUSensorCandidate', 'Select-CPUExport', 'Format-CPUExportCandidates')) {
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

Assert-Fixture ($temperature.Kind -eq 'TEMP' -and $temperature.Unit -eq 'C') 'CPU package temperature'
Assert-Fixture ($vid.VoltageKind -eq 'VID') 'VID stays requested voltage'
Assert-Fixture ((Select-CPUExport @($vid, $vcore) 'VOLT' -1) -match '\|2\|.*\|V\|VCORE$') 'measured Vcore preferred'
Assert-Fixture ((Select-CPUExport @($vid, $vcore) 'VOLT' 1) -match '\|1\|.*\|V\|VID$') 'explicit VID valid'
Assert-Fixture ($null -eq (New-Fixture 3 'GPU [#0]: Example' 'Vcore' '1.0' '1.0 V')) 'GPU Vcore rejected'
Assert-Fixture ($null -eq (New-Fixture 4 'GPU [#0]: Example' 'CPU Package' '42' '42 C')) 'non-CPU package rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#1]: Example' 'Core VIDs' '1.0' '1.0 V')) 'other CPU rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'Core #0 VID' '1.0' '1.0 V')) 'individual core VID rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' 'NaN' '42 C')) 'NaN rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' 'Infinity' '42 C')) 'infinity rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' '42,5' '42.5 C')) 'localized raw rejected'
Assert-Fixture ($null -eq (New-Fixture 5 'CPU [#0]: Example' 'CPU Package' '42' '42 W')) 'wrong unit rejected'
Assert-Fixture ($null -eq (New-Fixture 4097 'CPU [#0]: Example' 'CPU Package' '42' '42 C')) 'index bound'

$mirror = New-Fixture 0 'CPU [#0]: Example' 'CPU Package' '44' '44 C' 'HKEY_LOCAL_MACHINE'
Assert-Fixture ((Select-CPUExport @($temperature, $mirror) 'TEMP' -1) -match '^TEMP\|HKEY_CURRENT_USER\|0\|') 'mirrored mapping deduplicated'
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
$listBlock = [scriptblock]::Create($requestBranches[0].Extent.Text + "`n" + $listBranches[0].Extent.Text)
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

'PASS ' + $script:checks + ' offline discovery checks; helper parsed; no registry or process access'
