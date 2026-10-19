# Owner lease for the resident Media providers. Windows PowerShell 5.1.
# A worker started from Rainmeter exits when that Rainmeter process does, so a
# helper can never outlive the instance that launched it (and keep a handle in
# the skin folder through a later upgrade). Workers started from a shell with
# no Rainmeter ancestor carry no lease and keep their explicit Start/Stop life.
Set-StrictMode -Version 2.0

# Lease text is "<pid>:<start ticks UTC>". The start time pins the exact
# process, so a recycled process ID can never stand in for the owner.
function Get-MediaOwnerLease {
    param([int]$ProcessId = $PID, [int]$Depth = 4)
    try {
        $id = $ProcessId
        $child = [Diagnostics.Process]::GetProcessById($id)
        $childStart = $child.StartTime.ToUniversalTime().Ticks
        for ($level = 0; $level -lt $Depth; $level++) {
            # One CIM read per ancestor, only on an enabling command: never per poll.
            $row = Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId=' + $id) -Property ParentProcessId -ErrorAction Stop
            if ($null -eq $row -or [int]$row.ParentProcessId -le 4) { return $null }
            $parent = [Diagnostics.Process]::GetProcessById([int]$row.ParentProcessId)
            $parentStart = $parent.StartTime.ToUniversalTime().Ticks
            # A parent that started after its child is a recycled ID, not an ancestor.
            if ($parentStart -gt $childStart) { return $null }
            if ([string]::Equals($parent.ProcessName, 'Rainmeter', [StringComparison]::OrdinalIgnoreCase)) {
                return ('{0}:{1}' -f $parent.Id, $parentStart)
            }
            $id = $parent.Id; $childStart = $parentStart
        }
    } catch { }
    return $null
}

function Test-MediaOwnerLeaseText {
    param([AllowEmptyString()][string]$Lease)
    return $Lease -cmatch '\A(?:[1-9][0-9]{0,9}:[1-9][0-9]{0,18})?\z'
}

# Returns the live owner process, $false when the lease names a process that
# is gone or replaced, and $null when there is no lease.
function Open-MediaOwner {
    param([AllowEmptyString()][string]$Lease)
    if (-not $Lease) { return $null }
    if (-not (Test-MediaOwnerLeaseText $Lease)) { return $false }
    $parts = $Lease.Split(':')
    try {
        $process = [Diagnostics.Process]::GetProcessById([int]$parts[0])
        # Reading StartTime opens and keeps a handle, so the ID cannot be
        # recycled while this worker is still watching it.
        if ($process.StartTime.ToUniversalTime().Ticks -ne [long]$parts[1] -or $process.HasExited) { return $false }
        return $process
    } catch { return $false }
}

# Waits up to $Milliseconds; returns $true as soon as the owner has exited.
function Wait-MediaOwnerExit {
    param($Owner, [int]$Milliseconds)
    if ($null -eq $Owner) { Start-Sleep -Milliseconds $Milliseconds; return $false }
    if ($Owner -is [bool]) { return $true }
    try { return $Owner.WaitForExit($Milliseconds) } catch { return $true }
}

Export-ModuleMember -Function Get-MediaOwnerLease, Test-MediaOwnerLeaseText, Open-MediaOwner, Wait-MediaOwnerExit
