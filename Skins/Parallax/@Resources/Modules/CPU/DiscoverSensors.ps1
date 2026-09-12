# One-shot, read-only HWiNFO Gadget discovery. Invoked on skin load/reconnect,
# never for telemetry polling. Live values are read by native Registry measures.
# Protocol (ASCII, one record per line):
# HWINFOV1
# TEMP|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|C or F
# VOLT|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|V or mV|VCORE or VID
# STATUS|human-readable ASCII explanation (one line for each unavailable kind)
# With -List or positive -RequestId, append REQUEST|id. With -List only, also
# append STATE|RUNNING or STOPPED, then up to 128 records:
# CAND|TEMP or VOLT|hive|index|UTF8-hex sensor|UTF8-hex label|unit|VCORE or VID
# TEMP candidates have an empty final field. Candidate lines contain no readings.
# HKLM records use HKEY_LOCAL_MACHINE. There are no writes, saved IDs or helpers.
[CmdletBinding()]
param(
    [ValidateRange(-1, 4096)] [int] $TemperatureIndex = -1,
    [ValidateRange(-1, 4096)] [int] $VoltageIndex = -1,
    [ValidateSet('Auto', 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE')]
    [string] $Hive = 'Auto',
    [switch] $List,
    [ValidateRange(0, 2147483647)] [int] $RequestId = 0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.ASCIIEncoding]::new()

function ConvertTo-CPUSensorCandidate {
    param(
        [System.Collections.IDictionary] $Values,
        [int] $Index,
        [string] $SourceHive
    )

    if ($Index -lt 0 -or $Index -gt 4096) { return }
    foreach ($prefix in @('Sensor', 'Label', 'ValueRaw', 'Value')) {
        $name = $prefix + $Index
        if (-not $Values.Contains($name) -or $Values[$name] -isnot [string]) { return }
        if ($Values[$name].Length -eq 0 -or $Values[$name].Length -gt 1024) { return }
    }
    $sensor = $Values['Sensor' + $Index].Trim()
    $label = $Values['Label' + $Index].Trim()
    $formatted = $Values['Value' + $Index].Trim()
    $raw = $Values['ValueRaw' + $Index].Trim()
    if ($sensor.Length -eq 0 -or $label.Length -eq 0) { return }

    # Raw numeric parsing is culture-independent and deliberately rejects NaN,
    # infinity, thousands separators, empty values, and non-numeric sentinels.
    [double] $number = 0
    if (-not [double]::TryParse($raw, [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref] $number)) { return }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { return }

    # ValueRaw carries no unit. Require a recognized unit in the paired Value.
    # HWiNFO may format the number with decimal/thousands separators; only the
    # raw field is used numerically. Preserve C/F and V/mV for the live reader.
    $unitMatch = [regex]::Match($formatted,
        '\A[+-]?[0-9][0-9.,\s]*\s*(?:\u00b0\s*)?(C|F|mV|V)\z')
    if (-not $unitMatch.Success) { return }
    $unit = $unitMatch.Groups[1].Value
    $isCPU0 = $sensor -match '^CPU\s*\[#0\](?::|$)'
    $isOtherCPU = $sensor -match '^CPU\s*\[#([1-9][0-9]*)\](?::|$)'
    $isGraphics = $sensor -match '(?i)(?:\bGPU\b|\bGraphics\b|\bVRAM\b)'
    $kind = ''
    $voltageKind = ''

    if ($isCPU0 -and $label -in @('CPU Package', 'CPU (Tctl/Tdie)') -and
            $unit -in @('C', 'F')) {
        $kind = 'TEMP'
    }
    elseif ($unit -in @('V', 'mV')) {
        # Exact voltage labels only. Motherboard Vcore/VR VOUT are CPU-wide;
        # GPU groups and additional CPU packages cannot be selected accidentally.
        if (-not $isGraphics -and -not $isOtherCPU -and
                $label -in @('Vcore', 'VR VOUT', 'CPU Core Voltage')) {
            $kind = 'VOLT'
            $voltageKind = 'VCORE'
        }
        elseif ($isCPU0 -and $label -eq 'Core VIDs') {
            # The aggregate Core VIDs reading is requested voltage, not Vcore.
            $kind = 'VOLT'
            $voltageKind = 'VID'
        }
    }
    if ($kind.Length -eq 0) { return }
    [pscustomobject]@{
        Kind = $kind
        Hive = $SourceHive
        Index = $Index
        # Preserve exact identity strings for the live Registry reader's checks.
        Sensor = $Values['Sensor' + $Index]
        Label = $Values['Label' + $Index]
        Unit = $unit
        VoltageKind = $voltageKind
    }
}

function Get-CPUExportCandidates {
    param([string] $SourceHive)

    $base = $null
    $key = $null
    try {
        $hiveId = if ($SourceHive -eq 'HKEY_CURRENT_USER') {
            [Microsoft.Win32.RegistryHive]::CurrentUser
        } else {
            [Microsoft.Win32.RegistryHive]::LocalMachine
        }
        # HWiNFO64 writes the native 64-bit registry view. OpenSubKey is read-only.
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hiveId,
            [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey('SOFTWARE\HWiNFO64\VSB', $false)
        if ($null -eq $key) { return }
        $names = $key.GetValueNames()
        foreach ($name in $names) {
            if ($name -notmatch '^Sensor([0-9]{1,4})$') { continue }
            $index = [int] $Matches[1]
            if ($index -gt 4096 -or $name -ne ('Sensor' + $index)) { continue }
            $values = @{}
            foreach ($prefix in @('Sensor', 'Label', 'ValueRaw', 'Value')) {
                $valueName = $prefix + $index
                $values[$valueName] = $key.GetValue($valueName, $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
            ConvertTo-CPUSensorCandidate -Values $values -Index $index -SourceHive $SourceHive
        }
    }
    catch {
        # Missing/inaccessible exports are reported by the selection stage below.
        # Do not leak unrelated registry details or localized exceptions to Lua.
    }
    finally {
        if ($null -ne $key) { $key.Dispose() }
        if ($null -ne $base) { $base.Dispose() }
    }
}

function Select-CPUExport {
    param([object[]] $Candidates, [string] $Kind, [int] $RequestedIndex)

    $matchingCandidates = @($Candidates | Where-Object { $_.Kind -eq $Kind })
    if ($RequestedIndex -ge 0) {
        $matchingCandidates = @($matchingCandidates | Where-Object { $_.Index -eq $RequestedIndex })
    }
    elseif ($Kind -eq 'VOLT') {
        $measured = @($matchingCandidates | Where-Object { $_.VoltageKind -eq 'VCORE' })
        if ($measured.Count -gt 0) { $matchingCandidates = $measured }
    }

    # HWiNFO normally mirrors exports into both hives. Collapse only identical
    # identity/index/unit mappings, preferring HKCU; distinct mappings are unsafe.
    $unique = @()
    foreach ($candidate in $matchingCandidates) {
        $same = @($unique | Where-Object {
            $_.Index -eq $candidate.Index -and $_.Sensor -ceq $candidate.Sensor -and
            $_.Label -ceq $candidate.Label -and $_.Unit -ceq $candidate.Unit -and
            $_.VoltageKind -ceq $candidate.VoltageKind
        })
        if ($same.Count -eq 0) { $unique += $candidate }
    }
    $description = if ($Kind -eq 'TEMP') { 'temperature' } else { 'voltage' }
    if ($unique.Count -eq 0) {
        $detail = if ($RequestedIndex -ge 0) {
            'Requested CPU ' + $description + ' export is missing or unsupported'
        } else {
            'No exported CPU ' + $description + ' with a supported label and unit'
        }
        return 'STATUS|' + $detail
    }
    if ($unique.Count -gt 1) {
        return 'STATUS|Ambiguous CPU ' + $description + ' exports; select a unique index and hive'
    }
    $selected = $unique[0]
    $sensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($selected.Sensor)).Replace('-', '')
    $labelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($selected.Label)).Replace('-', '')
    $line = $Kind + '|' + $selected.Hive + '|' + $selected.Index + '|' +
        $sensorHex + '|' + $labelHex + '|' + $selected.Unit
    if ($Kind -eq 'VOLT') { $line += '|' + $selected.VoltageKind }
    return $line
}

function Format-CPUExportCandidates {
    param([object[]] $Candidates)

    # Candidates already passed tuple, semantic, raw-number and unit checks.
    # Keep each hive available for explicit setup, including mirrored mappings.
    # Sorting before the cap makes the bounded list independent of registry order.
    $ordered = @($Candidates | Sort-Object Kind, Hive, Index | Select-Object -First 128)
    foreach ($candidate in $ordered) {
        $sensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Sensor)).Replace('-', '')
        $labelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Label)).Replace('-', '')
        'CAND|' + $candidate.Kind + '|' + $candidate.Hive + '|' + $candidate.Index + '|' +
            $sensorHex + '|' + $labelHex + '|' + $candidate.Unit + '|' + $candidate.VoltageKind
    }
}

$hives = if ($Hive -eq 'Auto') {
    @('HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE')
} else { @($Hive) }
$candidates = @(
    foreach ($sourceHive in $hives) { Get-CPUExportCandidates -SourceHive $sourceHive }
)
'HWINFOV1'
Select-CPUExport -Candidates $candidates -Kind 'TEMP' -RequestedIndex $TemperatureIndex
Select-CPUExport -Candidates $candidates -Kind 'VOLT' -RequestedIndex $VoltageIndex
if ($List -or $RequestId -gt 0) {
    # Echo caller correlation as data; a late result cannot finish a newer scan.
    'REQUEST|' + $RequestId
}
if ($List) {
    # This point-in-time setup status is queried only on explicit list requests.
    # It does not start HWiNFO or establish freshness of retained registry values.
    if (@(Get-Process -Name HWiNFO64 -ErrorAction SilentlyContinue).Count -gt 0) {
        'STATE|RUNNING'
    } else {
        'STATE|STOPPED'
    }
    Format-CPUExportCandidates -Candidates $candidates
}
