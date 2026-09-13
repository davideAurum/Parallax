#requires -Version 5.1
# Deterministic provider/encoding cases. Get-CimInstance is a local fixture stub;
# this test performs no Windows inventory access or file writes.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$provider = [ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\MemoryInfo.ps1.txt')))
$script:ramDeviceFixture = @()
$script:ramFailDevices = $false
$script:ramCalls = @()
$script:ramInjectionExecuted = $false
function Get-CimInstance {
    param($ClassName, $Property, $ErrorAction)
    $script:ramCalls += [pscustomobject]@{ClassName=$ClassName;Properties=($Property -join ',')}
    if ($ClassName -ne 'Win32_PhysicalMemory') { throw 'Unexpected inventory class.' }
    if (($Property -join ',') -ne 'Capacity,SMBIOSMemoryType,ConfiguredClockSpeed,Manufacturer,PartNumber') { throw 'Unexpected device properties.' }
    if ($script:ramFailDevices) { throw 'Test-only access denied.' }
    return $script:ramDeviceFixture
}
function New-FixtureDevice($Capacity=8589934592, $Type=26, $Rate=3200, $Manufacturer='Example', $PartNumber='') {
    return [pscustomobject]@{Capacity=$Capacity;SMBIOSMemoryType=$Type;ConfiguredClockSpeed=$Rate;Manufacturer=$Manufacturer;PartNumber=$PartNumber}
}
$checks = 0
function Check-Inventory([string]$Expected) {
    $script:ramCalls = @()
    $capture = [IO.StringWriter]::new([Globalization.CultureInfo]::InvariantCulture)
    $original = [Console]::Out
    try { [Console]::SetOut($capture); & $provider } finally { [Console]::SetOut($original) }
    $actual = $capture.ToString()
    $capture.Dispose()
    if ($actual -cne $Expected) { throw "Inventory output mismatch: expected $Expected; got $actual" }
    if ($script:ramCalls.Count -ne 1) { throw 'Provider issued unexpected repeated queries.' }
    if ($script:ramCalls[0].ClassName -ne 'Win32_PhysicalMemory') { throw 'Provider requested an array or other inventory class.' }
    if ($script:ramCalls[0].Properties -ne 'Capacity,SMBIOSMemoryType,ConfiguredClockSpeed,Manufacturer,PartNumber') { throw 'Provider requested unrelated device properties.' }
    if ($script:ramInjectionExecuted) { throw 'Manufacturer data was executed.' }
    $script:checks += 5
}
$script:ramDeviceFixture = @(New-FixtureDevice)
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,4578616D706C65'
$script:ramDeviceFixture += New-FixtureDevice -Capacity 17179869184 -Type 34 -Rate 4800 -Manufacturer 'Other'
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,4578616D706C65;17179869184,34,4800,0,4F74686572'
$script:ramDeviceFixture = @(New-FixtureDevice -Capacity $null -Type $null -Rate $null -Manufacturer $null)
Check-Inventory 'RAMINFO2|0,0,0,0,'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer (" " + [char]9 + "A|B,C;D " + [char]13 + [char]10))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,417C422C433B44'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ('A'+[char]0xE9+[char]0x4E2D+[char]::ConvertFromUtf32(0x1F600)))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,41C3A9E4B8ADF09F9880'
$injection = '$script:ramInjectionExecuted=$true;[!Execute][MeasureRAMUsed]#Scale#'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer $injection)
Check-Inventory ('RAMINFO2|8589934592,26,3200,0,'+[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($injection)).Replace('-',''))
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer '0000AD010000')
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,303030304144303130303030'
# Synthetic part-family member, not a sampled machine-specific part number.
$familyPart = 'HMA81GU6MFR8N-TF'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer '0000AD010000' -PartNumber $familyPart)
Check-Inventory 'RAMINFO2|8589934592,26,3200,1,534B2048796E6978'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer 'Example' -PartNumber $familyPart)
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,4578616D706C65'
foreach ($placeholder in '', 'Unknown', 'undefined', 'Not Specified', 'Not Available', 'None', 'N/A', 'Default string', 'To Be Filled By O.E.M.', 'To Be Filled By OEM') {
    $script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer $placeholder -PartNumber $familyPart)
    Check-Inventory 'RAMINFO2|8589934592,26,3200,1,534B2048796E6978'
}
$script:ramDeviceFixture = @(New-FixtureDevice -Capacity 123 -Type 34 -Rate 0 -Manufacturer 'ABCD' -PartNumber $familyPart)
Check-Inventory 'RAMINFO2|123,34,0,1,534B2048796E6978'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer 'ABC' -PartNumber $familyPart)
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,414243'
foreach ($part in '', 'HMA81GU6MFR8N-ZZ', 'HMB81GU6MFR8N-TF', ('prefix'+$familyPart), ($familyPart+'suffix'), ($familyPart+';'+$injection)) {
    $script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer '0000AD010000' -PartNumber $part)
    Check-Inventory 'RAMINFO2|8589934592,26,3200,0,303030304144303130303030'
}
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer 'Unknown' -PartNumber 'HMA81GU6MFR8N-ZZ')
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,556E6B6E6F776E'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ('A'*128))
Check-Inventory ('RAMINFO2|8589934592,26,3200,0,'+('41'*128))
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ('A'*129))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer (([string][char]0xE9)*64))
Check-Inventory ('RAMINFO2|8589934592,26,3200,0,'+('C3A9'*64))
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer (([string][char]0xE9)*65))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ([char]::ConvertFromUtf32(0x1F600)*32))
Check-Inventory ('RAMINFO2|8589934592,26,3200,0,'+('F09F9880'*32))
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ([char]::ConvertFromUtf32(0x1F600)*33))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,'
$script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer ([string][char]0xD800))
Check-Inventory 'RAMINFO2|8589934592,26,3200,0,'
foreach ($manufacturer in '',(' '+[char]13+[char]10+[char]9+' '),$null) {
    $script:ramDeviceFixture = @(New-FixtureDevice -Manufacturer $manufacturer)
    Check-Inventory 'RAMINFO2|8589934592,26,3200,0,'
}
$script:ramDeviceFixture = @(1..512 | ForEach-Object { New-FixtureDevice -Manufacturer '' })
Check-Inventory ('RAMINFO2|'+((@('8589934592,26,3200,0,')*512)-join ';'))
$script:ramDeviceFixture += New-FixtureDevice
Check-Inventory 'UNAVAILABLE'
foreach ($invalid in @(
    @{Capacity=-1}, @{Capacity='18446744073709551616'},
    @{Type=-1}, @{Type='4294967296'}, @{Rate=-1}, @{Rate='4294967296'}
)) {
    $script:ramDeviceFixture = @(New-FixtureDevice @invalid)
    Check-Inventory 'UNAVAILABLE'
}
$script:ramDeviceFixture = @()
Check-Inventory 'UNAVAILABLE'
$script:ramFailDevices = $true
Check-Inventory 'UNAVAILABLE'
Write-Output "PASS: $checks provider checks; per-module values, UTF-8 hex encoding/bounds, literal manufacturer data, documented maker fallback without part output, record limits, invalid numbers and denied queries. One stubbed CIM call per case; no hardware queries or writes."
