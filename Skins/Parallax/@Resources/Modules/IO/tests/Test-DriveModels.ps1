# Synthetic association fixtures execute the actual helper with Get-CimInstance
# shadowed in local scope. No device query, helper process or file write occurs.
param([string] $ProductionPath = (Join-Path $PSScriptRoot '..\DriveModels.ps1.txt'))
$ErrorActionPreference = 'Stop'
$script:IOModelAssertions = 0
$ioSource = [ScriptBlock]::Create([IO.File]::ReadAllText((Resolve-Path -LiteralPath $ProductionPath)))

function Assert-IOEqual($Actual, $Expected, [string] $Message) {
    $script:IOModelAssertions++
    if ($Actual -cne $Expected) { throw ('{0}: expected <{1}>, got <{2}>' -f $Message, $Expected, $Actual) }
}
function Assert-IOTrue([bool] $Condition, [string] $Message) {
    $script:IOModelAssertions++
    if (-not $Condition) { throw $Message }
}
function New-IORef([string] $Id) { [pscustomobject]@{ DeviceID = $Id } }
function New-IOLink([string] $From, [string] $To) {
    [pscustomobject]@{ Antecedent = (New-IORef $From); Dependent = (New-IORef $To) }
}
function Invoke-IOFixture([hashtable] $Data, [string[]] $FailClasses = @()) {
    $requests = [Collections.Generic.List[object]]::new()
    function Get-CimInstance {
        param([string] $ClassName, [string[]] $Property, [string] $ErrorAction)
        $requests.Add([pscustomobject]@{ Class = $ClassName; Properties = $Property })
        if ($FailClasses -contains $ClassName) { throw 'Synthetic provider failure; private details must never be emitted.' }
        if (-not $Data.ContainsKey($ClassName)) { throw 'Unexpected class; fixture never calls a live CIM provider.' }
        return $Data[$ClassName]
    }
    $originalOutput = [Console]::Out
    $captured = [IO.StringWriter]::new()
    try {
        [Console]::SetOut($captured)
        & $ioSource
    } finally { [Console]::SetOut($originalOutput) }
    return [pscustomobject]@{ Text = $captured.ToString(); Requests = $requests.ToArray() }
}
function New-IOData {
    return @{
        Win32_DiskDrive = @()
        Win32_DiskDriveToDiskPartition = @()
        Win32_LogicalDiskToPartition = @()
        Win32_CDROMDrive = @()
    }
}

$data = New-IOData
$data.Win32_DiskDrive = @(
    [pscustomobject]@{ DeviceID = 'device-alpha'; Model = 'Example Alpha'; SerialNumber = 'must-not-leak' },
    [pscustomobject]@{ DeviceID = 'device-beta'; Model = 'Example Beta' })
$data.Win32_DiskDriveToDiskPartition = @(
    (New-IOLink 'device-alpha' 'partition-one'), (New-IOLink 'device-alpha' 'partition-two'),
    (New-IOLink 'device-beta' 'partition-two'), (New-IOLink 'device-beta' 'partition-two'))
$data.Win32_LogicalDiskToPartition = @(
    (New-IOLink 'partition-one' 'C:'), (New-IOLink 'partition-two' 'D:'),
    (New-IOLink 'partition-two' 'E:'), (New-IOLink 'unrelated-partition' 'Z:'),
    (New-IOLink 'partition-one' 'C:\mount'))
$data.Win32_CDROMDrive = @([pscustomobject]@{ Drive = 'F:'; Name = 'Example Optical' })
$result = Invoke-IOFixture $data
Assert-IOEqual $result.Text "IO_MODELS_V1`nOK`nC|Example Alpha`nD|Example Alpha; Example Beta`nE|Example Alpha; Example Beta`nF|Example Optical" 'Association direction, grouping, sorting and optical mapping'
Assert-IOEqual $result.Requests.Count 4 'Exactly one query per supported class'
foreach ($request in $result.Requests) {
    Assert-IOTrue ($request.Properties -notcontains 'SerialNumber') 'Serial numbers must not be requested'
}
Assert-IOTrue ($result.Text -notmatch 'device-alpha|partition-one|must-not-leak|Z\|') 'Transient keys and unmapped roots must not be emitted'
$result = Invoke-IOFixture $data @('Win32_CDROMDrive')
Assert-IOTrue ($result.Text.StartsWith("IO_MODELS_V1`nOK`nC|Example Alpha`n")) 'Optical failure must preserve local disk results'
Assert-IOTrue ($result.Text -notmatch 'F\||private details') 'Optical failures must remain data-only'

foreach ($driveRoot in @('D:', 'd:', 'D:\', 'd:\')) {
    $opticalData = New-IOData
    $opticalData.Win32_CDROMDrive = @([pscustomobject]@{ Drive = $driveRoot; Name = 'Example Optical' })
    $result = Invoke-IOFixture $opticalData
    Assert-IOEqual $result.Text "IO_MODELS_V1`nOK`nD|Example Optical" ('Optical root normalization: ' + $driveRoot)
}
foreach ($drivePath in @('', 'D', 'DD:', 'D:/', 'D:\folder', '\\server\share', 'D:\\', "D:`n", ' D:', 'D: ', ([string][char]0x212A + ':'))) {
    $opticalData = New-IOData
    $opticalData.Win32_CDROMDrive = @([pscustomobject]@{ Drive = $drivePath; Name = 'Must not be mapped' })
    $result = Invoke-IOFixture $opticalData
    Assert-IOEqual $result.Text "IO_MODELS_V1`nOK" 'Reject non-root or non-ASCII optical path'
}

foreach ($required in @('Win32_DiskDrive', 'Win32_DiskDriveToDiskPartition', 'Win32_LogicalDiskToPartition')) {
    $result = Invoke-IOFixture $data @($required)
    Assert-IOEqual $result.Text "IO_MODELS_V1`nUNAVAILABLE" ('Required provider failure: ' + $required)
}
$result = Invoke-IOFixture (New-IOData)
Assert-IOEqual $result.Text "IO_MODELS_V1`nOK" 'An empty successful inventory is distinct from failure'

$unsafe = New-IOData
$unsafe.Win32_DiskDrive = @([pscustomobject]@{ DeviceID = 'example'; Model = "  Example#[call()]%PATH%|`r`n Device  " })
$unsafe.Win32_DiskDriveToDiskPartition = @((New-IOLink 'example' 'part'))
$unsafe.Win32_LogicalDiskToPartition = @((New-IOLink 'part' 'C:'))
$result = Invoke-IOFixture $unsafe
Assert-IOEqual $result.Text "IO_MODELS_V1`nOK`nC|Example call() PATH Device" 'Model text must be passive canonical data'

$unsafe.Win32_DiskDrive[0].Model = ([string][char]0x00E9) * 400
$result = Invoke-IOFixture $unsafe
$value = $result.Text.Substring($result.Text.IndexOf('C|') + 2)
Assert-IOEqual ([Text.Encoding]::UTF8.GetByteCount($value)) 512 'Model byte bound'
Assert-IOEqual $value (([string][char]0x00E9) * 256) 'UTF-8 truncation preserves complete characters'
$unsafe.Win32_DiskDrive[0].Model = [char]::ConvertFromUtf32(0x1F4BE) * 200
$result = Invoke-IOFixture $unsafe
$value = $result.Text.Substring($result.Text.IndexOf('C|') + 2)
Assert-IOEqual ([Text.Encoding]::UTF8.GetByteCount($value)) 512 'Supplementary characters obey byte bound'
Assert-IOEqual $value ([char]::ConvertFromUtf32(0x1F4BE) * 128) 'Truncation preserves surrogate pairs'

$oversized = New-IOData
$oversized.Win32_DiskDriveToDiskPartition = @(1..4097 | ForEach-Object { New-IOLink 'example' 'part' })
$result = Invoke-IOFixture $oversized
Assert-IOEqual $result.Text "IO_MODELS_V1`nUNAVAILABLE" 'Association bound fails closed'
[pscustomobject]@{ Result = 'PASS'; Assertions = $script:IOModelAssertions; Scope = 'Synthetic mapping only; no real CIM queries' }
