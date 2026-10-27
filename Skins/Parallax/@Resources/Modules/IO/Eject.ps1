# One-shot eject for Disk Meter's eject icon. IO.lua runs this file's text as
# an in-memory script block with one validated letter, so it does not depend
# on the PowerShell execution policy. Prints one result line; exit 0 = ejected.
#   Removable (Win32 type 2): the same device-eject request as the taskbar's
#     Safely Remove Hardware. Programs watching the drive are asked to let go
#     first; one that refuses is named (from the veto, or from Kernel-PnP
#     event 225 when it only holds a handle). A card reader leaves the
#     system as a whole until it is replugged, exactly as with the taskbar.
#   Optical (Win32 type 5): opens the tray.
param([Parameter(Mandatory = $true)][ValidatePattern('^[A-Z]$')][string]$Letter)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
public static class ParallaxEject {
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Locate_DevNodeW(out uint devInst, string deviceId, int flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Request_Device_EjectW(uint devInst, out int vetoType, StringBuilder vetoName, int nameLength, int flags);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(SafeFileHandle device, uint code, IntPtr input, int inputSize, IntPtr output, int outputSize, out int returned, IntPtr overlapped);
    const uint IOCTL_STORAGE_EJECT_MEDIA = 0x2D4808;

    public static string Device(string deviceId) {
        uint devInst;
        int result = CM_Locate_DevNodeW(out devInst, deviceId, 0);
        if (result != 0) return "locate failed " + result;
        int veto;
        var vetoName = new StringBuilder(260);
        result = CM_Request_Device_EjectW(devInst, out veto, vetoName, vetoName.Capacity, 0);
        if (result == 0 && veto == 0) return "ejected";
        return "vetoed " + veto + " " + vetoName;
    }

    public static string Media(char letter) {
        using (var handle = CreateFileW(@"\\.\" + letter + ":", 0x80000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero)) {
            if (handle.IsInvalid) return "open failed " + Marshal.GetLastWin32Error();
            int returned;
            return DeviceIoControl(handle, IOCTL_STORAGE_EJECT_MEDIA, IntPtr.Zero, 0, IntPtr.Zero, 0, out returned, IntPtr.Zero)
                ? "ejected" : "eject failed " + Marshal.GetLastWin32Error();
        }
    }
}
'@
$volume = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${Letter}:'"
if (-not $volume) { 'absent'; exit 2 }
if ($volume.DriveType -eq 5) {
    $result = [ParallaxEject]::Media([char]$Letter)
} elseif ($volume.DriveType -eq 2) {
    $disk = $volume | Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition |
        Get-CimAssociatedInstance -ResultClassName Win32_DiskDrive | Select-Object -First 1
    if (-not $disk) { 'no disk device'; exit 2 }
    $result = [ParallaxEject]::Device($disk.PNPDeviceID)
    # An open handle vetoes as type 6 and names only the volume. Windows logs
    # the holding process in Kernel-PnP event 225 at the same moment; report
    # it as an application veto when that event is readable.
    if ($result -like 'vetoed 6 *') {
        $filter = "*[System[Provider[@Name='Microsoft-Windows-Kernel-PnP'] and EventID=225 and TimeCreated[timediff(@SystemTime) <= 15000]]]"
        for ($attempt = 0; $attempt -lt 5; $attempt++) {
            $holder = Get-WinEvent -LogName System -FilterXPath $filter -ErrorAction SilentlyContinue | ForEach-Object {
                $data = @{}
                ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $data[$_.Name] = $_.'#text' }
                if ($data.DeviceInstance -eq $disk.PNPDeviceID -and $data.ProcessName) { $data.ProcessName }
            } | Select-Object -First 1
            if ($holder) { $result = "vetoed 4 $holder"; break }
            Start-Sleep -Milliseconds 200
        }
    }
} else {
    'not removable'; exit 2
}
$result
if ($result -ne 'ejected') { exit 1 }
