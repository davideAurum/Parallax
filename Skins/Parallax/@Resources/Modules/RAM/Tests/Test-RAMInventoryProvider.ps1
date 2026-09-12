#requires -Version 5.1
# Deterministic provider failure/aggregation cases. No Windows inventory access.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$provider = [ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\MemoryInfo.ps1.txt')))
$script:ramDeviceFixture = @([pscustomobject]@{Capacity=8589934592; SMBIOSMemoryType=26; ConfiguredClockSpeed=3200; FormFactor=8})
$script:ramArrayFixture = @()
$script:ramFailDevices = $false
$script:ramFailArrays = $false
$script:ramCalls = @()
function Get-CimInstance {
    param($ClassName, $Property, $ErrorAction)
    $script:ramCalls += $ClassName
    switch ($ClassName) {
        'Win32_PhysicalMemory' {
            if ($script:ramFailDevices) { throw 'Test-only access denied.' }
            if (($Property -join ',') -ne 'Capacity,SMBIOSMemoryType,ConfiguredClockSpeed,FormFactor') { throw 'Unexpected device properties.' }
            return $script:ramDeviceFixture
        }
        'Win32_PhysicalMemoryArray' {
            if ($script:ramFailArrays) { throw 'Test-only missing array provider.' }
            if (($Property -join ',') -ne 'Use,MemoryDevices') { throw 'Unexpected array properties.' }
            return $script:ramArrayFixture
        }
        default { throw 'Unexpected inventory class.' }
    }
}
$checks = 0
function Check-Inventory([string]$Expected, [int]$Calls=2) {
    $script:ramCalls = @()
    $capture = [IO.StringWriter]::new([Globalization.CultureInfo]::InvariantCulture)
    $original = [Console]::Out
    try { [Console]::SetOut($capture); & $provider } finally { [Console]::SetOut($original) }
    $actual = $capture.ToString()
    $capture.Dispose()
    if ($actual -ne $Expected) { throw "Inventory output mismatch: expected $Expected; got $actual" }
    if ($script:ramCalls.Count -ne $Calls) { throw 'Provider issued unexpected repeated queries.' }
    $script:checks += 2
}
$row = '8589934592,26,3200,8'
$script:ramArrayFixture = @([pscustomobject]@{Use=3;MemoryDevices=4})
Check-Inventory "RAMINFO1|4|$row"
$script:ramArrayFixture += [pscustomobject]@{Use=4;MemoryDevices=8}
Check-Inventory "RAMINFO1|4|$row"
$script:ramArrayFixture += [pscustomobject]@{Use=3;MemoryDevices=2}
Check-Inventory "RAMINFO1|6|$row"
$script:ramArrayFixture += [pscustomobject]@{Use=2;MemoryDevices=4}
Check-Inventory "RAMINFO1|0|$row"
foreach ($unknown in 0,2,8,$null) {
    $script:ramArrayFixture = @([pscustomobject]@{Use=3;MemoryDevices=4}, [pscustomobject]@{Use=$unknown;MemoryDevices=4})
    Check-Inventory "RAMINFO1|0|$row"
}
$script:ramArrayFixture = @([pscustomobject]@{Use=3;MemoryDevices=0})
Check-Inventory "RAMINFO1|0|$row"
$script:ramArrayFixture = @()
Check-Inventory "RAMINFO1|0|$row"
$script:ramFailArrays = $true
Check-Inventory "RAMINFO1|0|$row"
$script:ramFailArrays = $false
$script:ramDeviceFixture = @([pscustomobject]@{Capacity=$null; SMBIOSMemoryType=$null; ConfiguredClockSpeed=$null; FormFactor=$null})
Check-Inventory 'RAMINFO1|0|0,0,0,0'
$script:ramDeviceFixture = @()
Check-Inventory 'UNAVAILABLE' 1
$script:ramFailDevices = $true
Check-Inventory 'UNAVAILABLE' 1
Write-Output "PASS: $checks provider checks; missing/unknown arrays, aggregation, empty inventory and denied queries. No hardware queries or writes."
