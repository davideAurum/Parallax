#requires -Version 5.1
# Original checks for the telemetry host's sleep gate: while Windows reports a
# bound NVIDIA GPU out of D0, a sample makes no NVAPI or NVML call.
# Pure checks need no hardware. -Live also, on a computer with an NVIDIA GPU:
# opens it, waits for it to sleep, samples it, and watches that it stays asleep.
# -Live needs nothing else polling the GPU (unload GPU Meter first), and a GPU
# that can sleep (a hybrid laptop with nothing using the card). Reads only.
# Production source is never rewritten: test accessors are added to an
# in-memory copy, as tests/Run-DriverChecks.ps1 does.
# Run in Windows PowerShell 5.1, x64 or x86.
param([switch]$Live)
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run these checks in Windows PowerShell 5.1.' }
$ErrorActionPreference = 'Stop'
$directory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.File]::ReadAllText((Join-Path $directory 'DriverTemperature.cs.txt'))
$accessors = @'
    public static bool TestAsleep(bool opened, bool bound, int state) { return Driver.TestAsleep(opened, bound, state); }
    public static string TestLive(string luid, int timeoutMs) { return Driver.TestLive(luid, timeoutMs); }
    public static string TestSleepingSnapshot()
    {
        return Snapshot("0123456789abcdef0123456789abcdef", 7, 1700000000, new Frame("ASLEEP"), "00000000000105AB", "?");
    }
    public static string TestSleepingSecond()
    {
        return SecondSnapshot("0123456789abcdef0123456789abcdef", 7, 1700000000, "OK", "00000000000105AB", 'D', "4E", new Frame("ASLEEP"), 0);
    }
'@
$inner = @'
    // state: the stored power state the fixture reports; -1 throws, -2 no source.
    internal static bool TestAsleep(bool opened, bool bound, int state)
    {
        Driver driver = new Driver(1);
        driver.opened = opened; driver.nvidiaBound = bound;
        if (state == -1) driver.powerState = delegate { throw new InvalidOperationException(); };
        else if (state != -2) driver.powerState = delegate { return state; };
        bool asleep = driver.Asleep();
        driver.opened = false; driver.nvidiaBound = false;
        return asleep;
    }
    // Opens the real GPU, waits for it to sleep, then removes every NVAPI and
    // NVML entry point from the driver object: a gated sample that reached one
    // would fail instead of reading ASLEEP. Reports the D0 time seen after.
    internal static string TestLive(string luid, int timeoutMs)
    {
        using (Driver driver = new Driver(UInt64.Parse(luid, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture)))
        {
            string open = driver.Open();
            if (open != "OK") return "OPEN|" + open;
            if (!driver.nvidiaBound) return "NOT_BOUND";
            if (driver.powerState == null) return "NOT_MATCHED";
            string awake = driver.Sample().TemperatureStatus;
            int waited = 0;
            while (!driver.Asleep() && waited < timeoutMs) { Thread.Sleep(100); waited += 100; }
            if (!driver.Asleep()) return "NEVER_ASLEEP|" + awake;
            NvidiaLogicalInfo logical = driver.logicalInfo; NvidiaThermalQuery thermal = driver.thermal;
            NvmlPciQuery pci = driver.nvmlPci; NvidiaScalar power = driver.nvmlPower;
            driver.logicalInfo = null; driver.thermal = null; driver.nvmlPci = null; driver.nvmlPower = null;
            int d0 = 0;
            Frame frame = null, load = null;
            for (int sample = 0; sample < 5; ++sample)
            {
                frame = driver.Sample();
                load = driver.SampleLoad();
                for (int slice = 0; slice < 40; ++slice) { Thread.Sleep(50); if (driver.powerState() == 1) ++d0; }
            }
            driver.logicalInfo = logical; driver.thermal = thermal; driver.nvmlPci = pci; driver.nvmlPower = power;
            return String.Join("|", new string[] { "LIVE", awake, frame.TemperatureStatus, frame.MemoryStatus, frame.UtilizationStatus,
                frame.PowerStatus, frame.ClockStatus, frame.SharedStatus, load.UtilizationStatus, d0.ToString(CultureInfo.InvariantCulture) });
        }
    }
'@
$member = '        private static readonly Guid FactoryId'
if (-not $source.Contains($member)) { throw 'Missing Driver member anchor' }
$source = $source.Replace($member, $inner + [Environment]::NewLine + $member)
$anchor = '    private sealed class Driver : IDisposable'
if (-not $source.Contains($anchor)) { throw 'Missing Driver anchor' }
$source = $source.Replace($anchor, $accessors + [Environment]::NewLine + $anchor)
Add-Type -TypeDefinition $source -Language CSharp
$script:count = 0
function Check([bool]$condition, [string]$label) {
    if (-not $condition) { throw "FAIL: $label" }
    $script:count++
}
$T = [ParallaxGpuTemperature]

Check (-not $T::TestAsleep($true, $true, 1)) 'D0 samples'
foreach ($state in 2, 3, 4) { Check ($T::TestAsleep($true, $true, $state)) "D$($state - 1) is asleep" }
foreach ($state in 0, 5, -1, -2) { Check (-not $T::TestAsleep($true, $true, $state)) "unknown state $state samples as before" }
Check (-not $T::TestAsleep($true, $false, 4)) 'an adapter with no NVIDIA driver is never gated'
Check (-not $T::TestAsleep($false, $true, 4)) 'a closed driver is not gated'

$f = $T::TestSleepingSnapshot().Split('|')
Check ($f.Length -eq 27 -and $f[1] -eq '4') 'a sleeping sample keeps protocol 4'
foreach ($index in 5, 9, 13, 16, 21, 23) { Check ($f[$index] -eq 'ASLEEP') "field $index reads ASLEEP" }
foreach ($index in 6, 10, 11, 12, 14, 15, 17, 18, 19, 20, 22, 24) { Check ($f[$index] -eq '?') "field $index carries no reading" }
$s = $T::TestSleepingSecond().Split('|')
Check ($s.Length -eq 14 -and $s[5] -eq 'OK' -and $s[9] -eq 'ASLEEP') 'a sleeping second GPU stays present with ASLEEP load'
Check ((($s[10..13] | Where-Object { $_ -ne '?' }).Count) -eq 0) 'a sleeping second GPU carries no reading'
"PASS: $script:count pure sleep-gate assertions"

if ($Live) {
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $directory 'AdapterInfo.cs.txt')))
    $info = [ParallaxGpuInfo]::ReadForSkin('2')
    if ($info -notmatch 'GPU_ADAPTER\|1\|([0-9A-F]{16})$') { 'LIVE: no discrete GPU; skipped'; return }
    $result = $T::TestLive($Matches[1], 30000)
    "LIVE: $result"
    $g = $result.Split('|')
    Check ($g[0] -eq 'LIVE') "the GPU opens, matches its device and sleeps ($result)"
    Check ($g[1] -eq 'OK') 'the sample right after opening reads the GPU'
    Check ((($g[2..6] + $g[8]) | Where-Object { $_ -ne 'ASLEEP' }).Count -eq 0) 'sleeping samples read ASLEEP without a driver call'
    Check ($g[7] -eq 'OK') 'DXCore shared memory still reads'
    Check ($g[9] -eq '0') 'the GPU stayed out of D0 across five samples, 2 s apart'
    "PASS: $script:count sleep-gate assertions including live"
}
