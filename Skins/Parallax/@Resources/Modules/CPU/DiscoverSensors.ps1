# One-shot, read-only HWiNFO Gadget discovery. Invoked on skin load/reconnect,
# never for telemetry polling. Live values are read by native Registry measures.
# Protocol (ASCII, one record per line):
# HWINFOV1
# TEMP|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|C or F
# VOLT|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|V or mV|VCORE or VID
# CLOCK|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|MHz or GHz
# FAN|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|RPM
# MBFAN|HKEY_CURRENT_USER|index|UTF8-hex sensor|UTF8-hex label|RPM
# STATUS|human-readable ASCII explanation (one line for each unavailable kind)
# With -List or positive -RequestId, append REQUEST|id. With -List only, also
# append STATE|RUNNING or STOPPED, then up to 128 records:
# CAND|TEMP, VOLT, CLOCK, FAN or MBFAN|hive|index|UTF8-hex sensor|UTF8-hex label|unit|VCORE or VID
# TEMP, CLOCK, FAN and MBFAN candidates have an empty final field. Candidate lines contain no readings.
# With -CoreList or -List, append unique per-core mappings (at most 128):
# CORE|TEMP or VOLT|coreId0..63|hive|index|UTF8-hex sensor|UTF8-hex label|unit|VID
# TEMP core records have an empty final field. Core IDs are HWiNFO identities,
# not Windows logical-processor indices; the consumer must establish topology.
# HKLM records use HKEY_LOCAL_MACHINE. There are no writes or saved IDs.
# With -PrecisionInput, output is PARALLAX_CPU_DECIMAL_V1|ok|integer or |cancel|.
# That UI path runs only after an explicit CPU Settings click and does not inspect HWiNFO.
[CmdletBinding()]
param(
    [ValidateRange(-1, 4096)] [int] $TemperatureIndex = -1,
    [ValidateRange(-1, 4096)] [int] $VoltageIndex = -1,
    [ValidateSet('Auto', 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE')]
    [string] $Hive = 'Auto',
    [switch] $List,
    [switch] $CoreList,
    [ValidateRange(0, 2147483647)] [int] $RequestId = 0,
    # Explicit CPU Settings action only: a bounded one-line precision editor.
    [switch] $PrecisionInput,
    [ValidateSet('CPUDecimals', 'CPUVoltageDecimals', 'CPUTemperatureDecimals')]
    [string] $PrecisionKey,
    [string] $PrecisionInitial,
    [string] $PrecisionX = '0',
    [string] $PrecisionY = '0',
    [string] $PrecisionWidth = '28',
    [string] $PrecisionHeight = '20',
    [string] $PrecisionScale = '1',
    [switch] $PrecisionValidateOnly,
    [string] $PrecisionValue,
    [switch] $PrecisionCancel
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.ASCIIEncoding]::new()

function ConvertTo-CPUPrecisionValue {
    param([string]$InputKey, [AllowNull()][string]$Text)
    $limits = @{
        CPUDecimals = @(0, 1)
        CPUVoltageDecimals = @(0, 3)
        CPUTemperatureDecimals = @(0, 1)
    }
    if (-not $limits.ContainsKey($InputKey)) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = 'Unknown CPU precision setting.' }
    }
    $minimum, $maximum = $limits[$InputKey]
    $message = 'Enter a whole number from {0} to {1}.' -f $minimum, $maximum
    if ($null -eq $Text -or $Text.Length -gt 16) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = $message }
    }
    $candidate = $Text.Trim()
    $number = 0
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $valid = $candidate -match '\A[0-9]+\z' -and [int]::TryParse($candidate,
        [Globalization.NumberStyles]::None, $culture, [ref]$number)
    if (-not $valid -or $number -lt $minimum -or $number -gt $maximum) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = $message }
    }
    return [pscustomobject]@{ Valid = $true; Value = $number.ToString($culture); Error = '' }
}

function Get-CPUPrecisionResponse {
    param([string]$InputKey, [AllowNull()][string]$Text, [switch]$Cancelled)
    if (-not $Cancelled) {
        $parsed = ConvertTo-CPUPrecisionValue -InputKey $InputKey -Text $Text
        if ($parsed.Valid) { return 'PARALLAX_CPU_DECIMAL_V1|ok|' + $parsed.Value }
    }
    return 'PARALLAX_CPU_DECIMAL_V1|cancel|'
}

function Invoke-CPUPrecisionInput {
    param(
        [string]$InputKey, [string]$Initial, [string]$X, [string]$Y,
        [string]$Width, [string]$Height, [string]$Scale,
        [switch]$ValidateOnly, [string]$Value, [switch]$Cancelled
    )
    $response = 'PARALLAX_CPU_DECIMAL_V1|cancel|'
    $form = $null
    $inputFont = $null
    $tip = $null
    try {
        if ($Cancelled) {
            return Get-CPUPrecisionResponse -Cancelled
        }
        if ($ValidateOnly) {
            return Get-CPUPrecisionResponse -InputKey $InputKey -Text $Value
        }
        $initialValue = ConvertTo-CPUPrecisionValue -InputKey $InputKey -Text $Initial
        if (-not $initialValue.Valid) { throw 'Invalid initial CPU precision.' }
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $positions = @{}
        foreach ($entry in @(@('X', $X, -100000, 100000), @('Y', $Y, -100000, 100000),
                @('Width', $Width, 24, 2048), @('Height', $Height, 12, 512))) {
            $integer = 0
            if (-not [int]::TryParse($entry[1], [Globalization.NumberStyles]::AllowLeadingSign,
                    $culture, [ref]$integer) -or $integer -lt $entry[2] -or $integer -gt $entry[3]) {
                throw 'Invalid editor bounds.'
            }
            $positions[$entry[0]] = $integer
        }
        $uiScale = [decimal]0
        if (-not [decimal]::TryParse($Scale, [Globalization.NumberStyles]::AllowDecimalPoint,
                $culture, [ref]$uiScale) -or $uiScale -lt 0.75 -or $uiScale -gt 2) {
            throw 'Invalid editor scale.'
        }
        $null = Add-Type -AssemblyName System.Windows.Forms
        $null = Add-Type -AssemblyName System.Drawing
        [Windows.Forms.Application]::EnableVisualStyles()
        $form = New-Object Windows.Forms.Form
        $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
        $form.MinimumSize = New-Object Drawing.Size(1, 1)
        $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
        $form.Location = New-Object Drawing.Point($positions.X, $positions.Y)
        $form.ClientSize = New-Object Drawing.Size($positions.Width, $positions.Height)
        $form.ShowInTaskbar = $false
        $form.TopMost = $true
        $form.BackColor = [Drawing.Color]::FromArgb(137, 190, 250)
        $form.Padding = New-Object Windows.Forms.Padding(1)
        $form.KeyPreview = $true
        $form.Text = 'CPU precision'
        $form.Tag = [pscustomobject]@{ Response = $response; Active = $false }

        $box = New-Object Windows.Forms.TextBox
        $box.AutoSize = $false
        $box.Multiline = $false
        $box.BorderStyle = [Windows.Forms.BorderStyle]::None
        $box.Dock = [Windows.Forms.DockStyle]::Fill
        $box.BackColor = [Drawing.Color]::FromArgb(25, 25, 25)
        $box.ForeColor = [Drawing.Color]::FromArgb(220, 220, 220)
        $box.TextAlign = [Windows.Forms.HorizontalAlignment]::Center
        $box.MaxLength = 16
        $inputFont = New-Object Drawing.Font('Segoe UI', [single](9 * $uiScale), [Drawing.FontStyle]::Regular)
        $box.Font = $inputFont
        $box.Text = $initialValue.Value
        $box.AccessibleName = 'CPU decimal precision'
        $box.AccessibleDescription = 'Enter applies the typed whole number. Escape cancels.'
        $form.Controls.Add($box)
        $tip = New-Object Windows.Forms.ToolTip

        $form.add_Shown({
            $form.Tag.Active = $true
            $form.Activate()
            $box.Focus() | Out-Null
            $box.SelectAll()
        })
        $form.add_Deactivate({ if ($form.Tag.Active) { $form.Close() } })
        $box.add_KeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Escape) {
                $eventArgs.SuppressKeyPress = $true
                $form.Close()
            }
            elseif ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Enter) {
                $eventArgs.SuppressKeyPress = $true
                $submitted = ConvertTo-CPUPrecisionValue -InputKey $InputKey -Text $box.Text
                if ($submitted.Valid) {
                    $form.Tag.Response = Get-CPUPrecisionResponse -InputKey $InputKey -Text $submitted.Value
                    $form.Close()
                }
                else {
                    $form.BackColor = [Drawing.Color]::FromArgb(230, 90, 90)
                    $tip.Show($submitted.Error, $box, 0, $box.Height + 3, 3500)
                    $box.AccessibleDescription = $submitted.Error + ' Escape cancels.'
                }
            }
        })
        $box.add_TextChanged({
            $form.BackColor = [Drawing.Color]::FromArgb(137, 190, 250)
            $tip.Hide($box)
        })
        $null = $form.ShowDialog()
        return [string]$form.Tag.Response
    }
    catch {
        # No user text or exception detail is reflected into the command channel.
        return 'PARALLAX_CPU_DECIMAL_V1|cancel|'
    }
    finally {
        if ($null -ne $tip) { $tip.Dispose() }
        if ($null -ne $form) { $form.Dispose() }
        if ($null -ne $inputFont) { $inputFont.Dispose() }
    }
}

if ($PrecisionInput) {
    $precisionParameters = @{
        InputKey = $PrecisionKey
        Initial = $PrecisionInitial
        X = $PrecisionX
        Y = $PrecisionY
        Width = $PrecisionWidth
        Height = $PrecisionHeight
        Scale = $PrecisionScale
        ValidateOnly = [bool]$PrecisionValidateOnly
        Value = $PrecisionValue
        Cancelled = [bool]$PrecisionCancel
    }
    [Console]::WriteLine((Invoke-CPUPrecisionInput @precisionParameters))
    exit 0
}

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
    # raw field is used numerically. Preserve C/F, V/mV, MHz/GHz and RPM for the
    # live reader.
    $unitMatch = [regex]::Match($formatted,
        '\A[+-]?[0-9][0-9.,\s]*\s*(?:\u00b0\s*)?(C|F|mV|V|MHz|GHz|RPM)\z')
    if (-not $unitMatch.Success) { return }
    $unit = $unitMatch.Groups[1].Value
    $isCPU0 = $sensor -match '^CPU\s*\[#0\](?::|$)'
    $isOtherCPU = $sensor -match '^CPU\s*\[#([1-9][0-9]*)\](?::|$)'
    $isGraphics = $sensor -match '(?i)(?:\bGPU\b|\bGraphics\b|\bVRAM\b)'
    $kind = ''
    $voltageKind = ''
    $scope = 'AGGREGATE'
    $coreId = -1

    if ($isCPU0 -and $unit -in @('C', 'F')) {
        if ($label -in @('CPU Package', 'CPU (Tctl/Tdie)', 'Core Temperatures')) {
            # Core Temperatures is HWiNFO's current average across core sensors,
            # not a package temperature. Preserve its label in the protocol.
            $kind = 'TEMP'
        }
        elseif ($sensor -match ':\s*DTS$' -and $label -match '^Core ([0-9]|[1-5][0-9]|6[0-3])$') {
            $kind = 'TEMP'
            $scope = 'CORE'
            $coreId = [int] $Matches[1]
        }
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
        elseif ($isCPU0 -and $label -match '^Core ([0-9]|[1-5][0-9]|6[0-3]) VID$') {
            $kind = 'VOLT'
            $voltageKind = 'VID'
            $scope = 'CORE'
            $coreId = [int] $Matches[1]
        }
    }
    elseif ($isCPU0 -and $unit -in @('MHz', 'GHz') -and $label -eq 'Core Clocks') {
        # This is HWiNFO's CPU-wide export. Do not substitute individual,
        # effective, or bus clock readings for the requested aggregate line.
        $kind = 'CLOCK'
    }
    elseif ($unit -eq 'RPM' -and -not $isGraphics -and -not $isOtherCPU -and
            $label -match '(?i)\ACPU(?:\s+Fan(?:\s+(?:Speed|#?1))?)?\z') {
        # Fan controllers normally live in a motherboard or embedded-controller
        # group rather than the CPU group. Require an exact CPU-fan label and RPM
        # so a chassis, pump or GPU fan can never fill this row accidentally.
        $kind = 'FAN'
    }
    elseif ($unit -eq 'RPM' -and -not $isGraphics -and -not $isOtherCPU -and
            $label -match '(?i)\A(?:Mainboard|Motherboard)(?:\s+Fan)?\z') {
        # The motherboard fan is separate from CPU, chassis, pump and GPU fans.
        $kind = 'MBFAN'
    }
    if ($kind.Length -eq 0) { return }
    [pscustomobject]@{
        Kind = $kind
        Scope = $scope
        CoreId = $coreId
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

    $matchingCandidates = @($Candidates | Where-Object { $_.Scope -eq 'AGGREGATE' -and $_.Kind -eq $Kind })
    if ($RequestedIndex -ge 0) {
        $matchingCandidates = @($matchingCandidates | Where-Object { $_.Index -eq $RequestedIndex })
    }
    elseif ($Kind -eq 'VOLT') {
        $measured = @($matchingCandidates | Where-Object { $_.VoltageKind -eq 'VCORE' })
        if ($measured.Count -gt 0) { $matchingCandidates = $measured }
    }
    elseif ($Kind -eq 'TEMP') {
        $primary = @($matchingCandidates | Where-Object { $_.Label.Trim() -in @('CPU Package', 'CPU (Tctl/Tdie)') })
        if ($primary.Count -gt 0) { $matchingCandidates = $primary }
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
    $description = if ($Kind -eq 'TEMP') { 'temperature' }
        elseif ($Kind -eq 'VOLT') { 'voltage' }
        elseif ($Kind -eq 'CLOCK') { 'core clock' }
        elseif ($Kind -eq 'FAN') { 'fan speed' }
        else { 'motherboard fan speed' }
    if ($unique.Count -eq 0) {
        $detail = if ($RequestedIndex -ge 0) {
            'Requested CPU ' + $description + ' export is missing or unsupported'
        } else {
            'No exported CPU ' + $description + ' with a supported label and unit'
        }
        return 'STATUS|' + $detail
    }
    if ($unique.Count -gt 1) {
        if ($Kind -eq 'CLOCK' -or $Kind -eq 'FAN' -or $Kind -eq 'MBFAN') {
            return 'STATUS|Ambiguous CPU ' + $description + ' exports; choose a search scope with one mapping'
        }
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
    $ordered = @($Candidates | Where-Object { $_.Scope -eq 'AGGREGATE' } |
        Sort-Object Kind, Hive, Index | Select-Object -First 128)
    foreach ($candidate in $ordered) {
        $sensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Sensor)).Replace('-', '')
        $labelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Label)).Replace('-', '')
        'CAND|' + $candidate.Kind + '|' + $candidate.Hive + '|' + $candidate.Index + '|' +
            $sensorHex + '|' + $labelHex + '|' + $candidate.Unit + '|' + $candidate.VoltageKind
    }
}

function Format-CPUCoreCandidates {
    param([object[]] $Candidates)

    # Each kind/core identity must resolve to exactly one export. Collapse only
    # identical HKCU/HKLM mirrors, preferring HKCU. A conflicting identity, index,
    # unit, or voltage type suppresses this core instead of guessing a binding.
    $selected = @()
    $groups = @($Candidates | Where-Object { $_.Scope -eq 'CORE' } | Group-Object Kind, CoreId)
    foreach ($group in $groups) {
        $unique = @()
        foreach ($candidate in @($group.Group | Sort-Object Hive, Index)) {
            $same = @($unique | Where-Object {
                $_.Index -eq $candidate.Index -and $_.Sensor -ceq $candidate.Sensor -and
                $_.Label -ceq $candidate.Label -and $_.Unit -ceq $candidate.Unit -and
                $_.VoltageKind -ceq $candidate.VoltageKind
            })
            if ($same.Count -eq 0) { $unique += $candidate }
        }
        if ($unique.Count -eq 1) { $selected += $unique[0] }
    }
    foreach ($candidate in @($selected | Sort-Object Kind, CoreId | Select-Object -First 128)) {
        $sensorHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Sensor)).Replace('-', '')
        $labelHex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($candidate.Label)).Replace('-', '')
        'CORE|' + $candidate.Kind + '|' + $candidate.CoreId + '|' + $candidate.Hive + '|' + $candidate.Index + '|' +
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
Select-CPUExport -Candidates $candidates -Kind 'CLOCK' -RequestedIndex -1
Select-CPUExport -Candidates $candidates -Kind 'FAN' -RequestedIndex -1
Select-CPUExport -Candidates $candidates -Kind 'MBFAN' -RequestedIndex -1
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
if ($CoreList -or $List) {
    Format-CPUCoreCandidates -Candidates $candidates
}
