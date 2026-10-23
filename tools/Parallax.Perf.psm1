#requires -Version 5.1
# Shared, read-only process accounting for Parallax performance tools.
#
# One NtQuerySystemInformation(SystemProcessInformation) call returns CPU time,
# memory and per-thread context-switch counts for every process without opening
# a handle to any of them, so it can observe protected processes (audiodg, dwm)
# and costs about a millisecond per snapshot. Nothing here writes, signals or
# terminates a process.

Set-StrictMode -Version Latest

if (-not ('ParallaxPerfNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class PxThread {
    public long Tid;
    public long CreateTime;
    public long CpuTime;          // kernel + user, 100 ns units
    public uint ContextSwitches;  // cumulative
}

public sealed class PxProcess {
    public int Pid;
    public int ParentPid;
    public string Name;
    public long CreateTime;       // FILETIME (UTC, 100 ns)
    public long CpuTime;          // kernel + user, 100 ns units
    public long WorkingSet;
    public long PrivateBytes;
    public uint HandleCount;
    public uint ThreadCount;
    public PxThread[] Threads;
}

public sealed class PxDelta {
    public int Pid;
    public string Name;
    public long CpuDelta;         // 100 ns units over the interval
}

public static class ParallaxPerfNative {
    // CPU consumed by every process between two snapshots. A pid whose create
    // time changed (reuse) or that is new counts its whole lifetime.
    public static PxDelta[] Diff(PxProcess[] before, PxProcess[] after) {
        var map = new Dictionary<int, PxProcess>(before.Length);
        foreach (var process in before) map[process.Pid] = process;
        var list = new List<PxDelta>(after.Length);
        foreach (var process in after) {
            if (process.Pid == 0) continue;
            PxProcess old;
            long delta = (map.TryGetValue(process.Pid, out old) && old.CreateTime == process.CreateTime) ? process.CpuTime - old.CpuTime : process.CpuTime;
            if (delta > 0) list.Add(new PxDelta { Pid = process.Pid, Name = process.Name, CpuDelta = delta });
        }
        return list.ToArray();
    }

    [DllImport("ntdll.dll")] private static extern int NtQuerySystemInformation(int infoClass, IntPtr buffer, int length, out int returned);
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern uint GetGuiResources(IntPtr hProcess, uint flags);

    // x64 layouts: SYSTEM_PROCESS_INFORMATION is 0x100 bytes and is followed by
    // NumberOfThreads SYSTEM_THREAD_INFORMATION records of 0x50 bytes each.
    private const int ProcessHeader = 256;
    private const int ThreadRecord = 80;

    public static PxProcess[] Snapshot(bool withThreads) {
        if (IntPtr.Size != 8) throw new PlatformNotSupportedException("64-bit PowerShell required");
        int size = 1 << 20;
        for (int attempt = 0; attempt < 8; attempt++) {
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try {
                int returned;
                int status = NtQuerySystemInformation(5, buffer, size, out returned);
                if (status == unchecked((int)0xC0000004)) { size = Math.Max(size * 2, returned + 65536); continue; }
                if (status != 0) throw new InvalidOperationException("NtQuerySystemInformation failed: 0x" + status.ToString("X8"));
                var list = new List<PxProcess>(512);
                long offset = 0;
                while (true) {
                    IntPtr p = new IntPtr(buffer.ToInt64() + offset);
                    uint next = (uint)Marshal.ReadInt32(p, 0);
                    var process = new PxProcess();
                    process.ThreadCount = (uint)Marshal.ReadInt32(p, 4);
                    process.CreateTime = Marshal.ReadInt64(p, 32);
                    process.CpuTime = Marshal.ReadInt64(p, 40) + Marshal.ReadInt64(p, 48);
                    int nameBytes = (ushort)Marshal.ReadInt16(p, 56);
                    IntPtr nameBuffer = Marshal.ReadIntPtr(p, 64);
                    process.Name = nameBuffer == IntPtr.Zero ? "Idle" : Marshal.PtrToStringUni(nameBuffer, nameBytes / 2);
                    process.Pid = (int)Marshal.ReadIntPtr(p, 80).ToInt64();
                    process.ParentPid = (int)Marshal.ReadIntPtr(p, 88).ToInt64();
                    process.HandleCount = (uint)Marshal.ReadInt32(p, 96);
                    process.WorkingSet = Marshal.ReadIntPtr(p, 144).ToInt64();
                    process.PrivateBytes = Marshal.ReadIntPtr(p, 200).ToInt64();
                    if (withThreads) {
                        process.Threads = new PxThread[process.ThreadCount];
                        for (int i = 0; i < process.ThreadCount; i++) {
                            IntPtr t = new IntPtr(p.ToInt64() + ProcessHeader + (long)i * ThreadRecord);
                            var thread = new PxThread();
                            thread.CpuTime = Marshal.ReadInt64(t, 0) + Marshal.ReadInt64(t, 8);
                            thread.CreateTime = Marshal.ReadInt64(t, 16);
                            thread.Tid = Marshal.ReadIntPtr(t, 48).ToInt64();
                            thread.ContextSwitches = (uint)Marshal.ReadInt32(t, 64);
                            process.Threads[i] = thread;
                        }
                    }
                    list.Add(process);
                    if (next == 0) break;
                    offset += next;
                }
                return list.ToArray();
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }
        throw new InvalidOperationException("Process snapshot buffer did not converge.");
    }

    private static string ClassOf(IntPtr hwnd) {
        var text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString();
    }

    // Top-level RainmeterMeterWindow windows owned by pid.
    public static int CountSkinWindows(uint pid) {
        int found = 0;
        EnumWindows((hwnd, unused) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner == pid && ClassOf(hwnd) == "RainmeterMeterWindow") found++;
            return true;
        }, IntPtr.Zero);
        return found;
    }

    // The thread that owns the skin windows is Rainmeter's UI (update/draw) thread.
    public static long SkinWindowThread(uint pid) {
        long tid = 0;
        EnumWindows((hwnd, unused) => {
            uint owner; uint thread = GetWindowThreadProcessId(hwnd, out owner);
            if (owner == pid && ClassOf(hwnd) == "RainmeterMeterWindow") { tid = thread; return false; }
            return true;
        }, IntPtr.Zero);
        return tid;
    }

    public static uint GdiObjects(IntPtr process)  { return GetGuiResources(process, 0); }
    public static uint UserObjects(IntPtr process) { return GetGuiResources(process, 1); }
}
'@
}

function Get-ParallaxPerfSnapshot {
    [CmdletBinding()]
    param([switch]$Threads)
    $stamp = [Diagnostics.Stopwatch]::GetTimestamp()
    $processes = [ParallaxPerfNative]::Snapshot([bool]$Threads)
    $byPid = @{}
    foreach ($process in $processes) { $byPid[$process.Pid] = $process }
    [pscustomobject]@{ Timestamp = $stamp; ByPid = $byPid; Processes = $processes }
}

function Get-ParallaxElapsedSeconds([long]$From, [long]$To) {
    ($To - $From) / [double][Diagnostics.Stopwatch]::Frequency
}

# Processes descending from any of $RootPids (by parent id), created at or after
# $NotBefore (FILETIME), resolved to a fixed point within one snapshot. Exited
# intermediates break the chain, so callers keep a cumulative known set.
function Get-ParallaxDescendants {
    param($Snapshot, [int[]]$RootPids, [long]$NotBefore = 0)
    $known = [Collections.Generic.HashSet[int]]::new()
    foreach ($id in $RootPids) { $null = $known.Add($id) }
    do {
        $added = $false
        foreach ($process in $Snapshot.Processes) {
            if ($known.Contains($process.Pid)) { continue }
            if ($process.CreateTime -lt $NotBefore) { continue }
            if ($known.Contains($process.ParentPid)) { $null = $known.Add($process.Pid); $added = $true }
        }
    } while ($added)
    foreach ($id in $RootPids) { $null = $known.Remove($id) }
    , @($known)
}

# Cumulative GPU engine running time (100 ns) per engine type for the given pids.
# Uses the GPU Engine performance counters; returns an empty table when they are
# unavailable. Two calls bracketing a window give utilization without sampling.
function Get-ParallaxGpuRunningTime {
    param([int[]]$Pids)
    $result = @{}
    if (-not $Pids -or $Pids.Count -eq 0) { return $result }
    $paths = @($Pids | ForEach-Object { "\GPU Engine(pid_$($_)_*)\Running Time" })
    try { $samples = (Get-Counter -Counter $paths -ErrorAction SilentlyContinue).CounterSamples } catch { return $result }
    foreach ($sample in @($samples)) {
        if ($null -eq $sample -or $sample.InstanceName -notmatch '^pid_(\d+)_.*engtype_(.+)$') { continue }
        $key = "$($Matches[1])|$($Matches[2])"
        if (-not $result.ContainsKey($key)) { $result[$key] = 0L }
        $result[$key] += [long]$sample.RawValue
    }
    $result
}

function Get-ParallaxGpuPercent {
    param([hashtable]$Before, [hashtable]$After, [double]$Seconds, [int[]]$Pids)
    # $Pids omitted means every pid in the tables; an empty list means none.
    $byType = @{}
    if ($null -ne $Pids -and $Pids.Count -eq 0) { return $byType }
    foreach ($key in $After.Keys) {
        $parts = $key.Split('|')
        if ($null -ne $Pids -and ([int]$parts[0]) -notin $Pids) { continue }
        $start = if ($Before.ContainsKey($key)) { $Before[$key] } else { 0L }
        $delta = $After[$key] - $start
        if ($delta -lt 0) { continue }
        $type = $parts[1]
        if (-not $byType.ContainsKey($type)) { $byType[$type] = 0.0 }
        $byType[$type] += 100.0 * $delta / ($Seconds * 1e7)
    }
    $byType
}

function Get-ParallaxPercentile {
    param([double[]]$Values, [double]$Percentile)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $rank = ($Percentile / 100.0) * ($sorted.Count - 1)
    $low = [math]::Floor($rank); $high = [math]::Ceiling($rank)
    if ($low -eq $high) { return $sorted[[int]$low] }
    $sorted[[int]$low] + ($rank - $low) * ($sorted[[int]$high] - $sorted[[int]$low])
}

Export-ModuleMember -Function Get-ParallaxPerfSnapshot, Get-ParallaxElapsedSeconds, Get-ParallaxDescendants, Get-ParallaxGpuRunningTime, Get-ParallaxGpuPercent, Get-ParallaxPercentile
