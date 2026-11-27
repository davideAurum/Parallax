#requires -Version 5.1
# Original checks for the telemetry host's second GPU (GPU Settings Second GPU)
# and its DXCore path for discrete adapters without a bound NVIDIA driver.
# Pure checks need no hardware. -Live also, on this computer: finds the second
# GPU beside the main one, reads its load frame twice, and runs one bounded
# host session in-process with a random temp token, then checks that every
# session file is removed. Reads only; no GPU, registry or settings data is
# changed. Production source is never rewritten: test accessors are added to
# an in-memory copy, as tests/Run-DriverChecks.ps1 does.
# Run in Windows PowerShell 5.1, x64 or x86.
param([switch]$Live)
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run these checks in Windows PowerShell 5.1.' }
$ErrorActionPreference = 'Stop'
$directory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.File]::ReadAllText((Join-Path $directory 'DriverTemperature.cs.txt'))
$accessors = @'
    public static int TestChooseSecondIndex(bool sawMain, int others, bool sorted) { return Driver.ChooseSecondIndex(sawMain, others, sorted); }
    public static string TestSecondSnapshot(string status, string luid, char kind, string nameHex, string loadStatus,
        long core, long video, long physical, long available, string memoryStatus, long resident, string sharedStatus, long sharedLimit)
    {
        Frame frame = new Frame("UNSUPPORTED");
        frame.UtilizationStatus = loadStatus;
        if (core >= 0) frame.Utilization[0] = (uint)core;
        if (video >= 0) frame.Utilization[2] = (uint)video;
        frame.MemoryStatus = memoryStatus;
        if (physical >= 0) { frame.Physical = (ulong)physical; frame.Allocatable = (ulong)physical; frame.Available = (ulong)available; }
        frame.SharedStatus = sharedStatus;
        if (resident >= 0) { frame.SharedCommitted = (ulong)resident; frame.SharedResident = (ulong)resident; }
        return SecondSnapshot("0123456789abcdef0123456789abcdef", 7, 1700000000, status, luid, kind, nameHex, frame, (ulong)sharedLimit);
    }
    public static string TestFindSecond(string mainLuid)
    {
        ulong second;
        string status = Driver.FindSecond(UInt64.Parse(mainLuid, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture), out second);
        return status + "|" + second.ToString("X16", CultureInfo.InvariantCulture);
    }
    public static string TestLoadFrames(string luid, int pauseMs)
    {
        using (Driver driver = new Driver(UInt64.Parse(luid, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture), true))
        {
            string open = driver.Open();
            if (open != "OK") return "OPEN|" + open;
            Frame first = driver.ReadLoadFrame();
            Thread.Sleep(pauseMs);
            Frame next = driver.ReadLoadFrame();
            Func<uint?, string> value = delegate(uint? v) { return v.HasValue ? v.Value.ToString(CultureInfo.InvariantCulture) : "?"; };
            return String.Join("|", new string[] { "FRAMES", driver.Integrated ? "I" : "D", first.UtilizationStatus, next.UtilizationStatus,
                value(next.Utilization[0]), value(next.Utilization[2]), next.MemoryStatus, next.SharedStatus,
                next.TemperatureStatus, next.PowerStatus, next.ClockStatus, driver.SharedLimit.ToString(CultureInfo.InvariantCulture) });
        }
    }
    // One bounded session: lease, Run on a worker thread, read the files, stop
    // by removing the lease, and report whether every session file is gone.
    public static string TestSession(string luid, string secondMode, int waitMs)
    {
        string token = Guid.NewGuid().ToString("N");
        Paths paths = new Paths(token);
        Exception failure = null;
        Thread worker = new Thread(delegate() { try { Run(token, luid, 1000, secondMode); } catch (Exception error) { failure = error; } });
        worker.IsBackground = true;
        try
        {
            WriteNew(paths.Lease, token + "|" + Number(Now()));
            worker.Start();
            string main = "", second = "";
            for (int waited = 0; waited < waitMs; waited += 250)
            {
                Thread.Sleep(250);
                try { File.WriteAllText(paths.Lease, token + "|" + Number(Now()), Ascii); } catch (IOException) { }
            }
            try { main = File.ReadAllText(paths.Data); } catch (IOException) { main = "?"; }
            try { second = File.Exists(paths.Second) ? File.ReadAllText(paths.Second) : "-"; } catch (IOException) { second = "?"; }
            File.Delete(paths.Lease);
            bool stopped = worker.Join(8000);
            bool clean = !File.Exists(paths.Data) && !File.Exists(paths.Temporary) && !File.Exists(paths.Second) &&
                !File.Exists(paths.SecondTemporary) && !File.Exists(paths.Lease);
            return (failure == null ? "RUN" : "FAILED " + failure.Message) + "\n" + main + "\n" + second + "\n" + (stopped ? "STOPPED" : "RUNNING") + "|" + (clean ? "CLEAN" : "LEFT");
        }
        finally
        {
            Delete(paths.Lease); Delete(paths.Data); Delete(paths.Temporary); Delete(paths.Second); Delete(paths.SecondTemporary);
        }
    }
'@
# Stands in for a discrete adapter with no NVIDIA driver (AMD, Intel Arc): in
# this in-memory copy only, an opt-in flag makes the NVIDIA open report
# UNSUPPORTED, so a real discrete GPU here is read through DXCore instead.
$nvidiaOpen = '                    nvidiaStatus = OpenNvidia();'
if (-not $source.Contains($nvidiaOpen)) { throw 'Missing NVIDIA open anchor' }
$source = $source.Replace($nvidiaOpen, '                    nvidiaStatus = TestWithoutNvidia ? "UNSUPPORTED" : OpenNvidia();')
$accessors = '    internal static bool TestWithoutNvidia;' + [Environment]::NewLine + $accessors + @'
    public static string TestDxcoreDiscrete(string luid, int pauseMs)
    {
        TestWithoutNvidia = true;
        try
        {
            using (Driver driver = new Driver(UInt64.Parse(luid, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture)))
            {
                string open = driver.Open();
                if (open != "OK") return "OPEN|" + open;
                Frame first = driver.ReadFrame();
                Thread.Sleep(pauseMs);
                Frame next = driver.ReadFrame();
                Func<uint?, string> value = delegate(uint? v) { return v.HasValue ? v.Value.ToString(CultureInfo.InvariantCulture) : "?"; };
                Func<ulong?, string> bytes = delegate(ulong? v) { return v.HasValue ? v.Value.ToString(CultureInfo.InvariantCulture) : "?"; };
                return String.Join("|", new string[] { "DXCORE", driver.Integrated ? "I" : "D", first.UtilizationStatus, next.UtilizationStatus,
                    value(next.Utilization[0]), value(next.Utilization[1]), value(next.Utilization[2]), value(next.Utilization[3]),
                    next.MemoryStatus, bytes(next.Physical), bytes(next.Available), next.SharedStatus,
                    next.TemperatureStatus, next.PowerStatus, next.ClockStatus });
            }
        }
        finally { TestWithoutNvidia = false; }
    }
'@
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

# Second-GPU choice inside the host: first other hardware adapter, sorted.
Check ($T::TestChooseSecondIndex($true, 1, $true) -eq 0) 'one other adapter'
Check ($T::TestChooseSecondIndex($true, 3, $true) -eq 0) 'three others: the next in order only'
Check ($T::TestChooseSecondIndex($true, 0, $true) -eq -1) 'single GPU: none'
Check ($T::TestChooseSecondIndex($false, 1, $true) -eq -1) 'main missing: no pairing'
Check ($T::TestChooseSecondIndex($true, 1, $false) -eq 0) 'unsorted with one other is still unambiguous'
Check ($T::TestChooseSecondIndex($true, 2, $false) -eq -2) 'unsorted with two others is not guessed'

$luid = '0000000000010618'; $name = '496E74656C'
$split = { param($text) $text.Split('|') }
# Discrete second: occupied of physical framebuffer, GPU and video domains.
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', $name, 'OK', 12, 3, 4294508544, 4000000000, 'OK', 100, 'OK', 0))
Check ($f.Length -eq 14 -and $f[0] -eq 'GPU_SECOND' -and $f[1] -eq '1' -and $f[3] -eq '7' -and $f[4] -eq '1700000000') 'discrete header'
Check ($f[5] -eq 'OK' -and $f[6] -eq $luid -and $f[7] -eq 'D' -and $f[8] -eq $name) 'discrete identity'
Check ($f[9] -eq 'OK' -and $f[10] -eq '12' -and $f[11] -eq '3' -and $f[12] -eq '4294508544' -and $f[13] -eq '294508544') 'discrete load and memory'
# Integrated second: shared residency over the shared limit; dedicated is ignored.
$f = & $split ($T::TestSecondSnapshot('OK', $luid.ToLower(), 'I', $name, 'OK', 7, 0, 134217728, 134217728, 'OK', 1200000000, 'OK', 8491673600))
Check ($f[6] -eq $luid -and $f[7] -eq 'I' -and $f[12] -eq '8491673600' -and $f[13] -eq '1200000000' -and $f[10] -eq '7' -and $f[11] -eq '0') 'integrated memory is shared of the limit'
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'I', $name, 'OK', 7, 0, -1, 0, 'UNSUPPORTED', 1200000000, 'OK', 0))
Check ($f[12] -eq '?' -and $f[13] -eq '?') 'integrated without a shared limit reads unknown memory'
# DXCore engines start with no comparison: STARTING, no figures.
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', $name, 'STARTING', -1, -1, -1, 0, 'UNSUPPORTED', -1, 'UNSUPPORTED', 0))
Check ($f[9] -eq 'STARTING' -and $f[10] -eq '?' -and $f[11] -eq '?' -and $f[12] -eq '?') 'starting load'
# A load status that is not OK never carries a figure.
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', $name, 'UNAVAILABLE', 50, 50, -1, 0, 'UNAVAILABLE', -1, 'UNAVAILABLE', 0))
Check ($f[9] -eq 'UNAVAILABLE' -and $f[10] -eq '?' -and $f[11] -eq '?') 'unavailable load withholds figures'
# Video missing (NVIDIA domain absent): core still reads.
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', $name, 'OK', 40, -1, -1, 0, 'UNSUPPORTED', -1, 'OK', 0))
Check ($f[10] -eq '40' -and $f[11] -eq '?') 'missing video domain'
# Statuses without an adapter carry no identity or readings.
foreach ($status in 'NONE', 'UNSUPPORTED', 'UNAVAILABLE', 'DEVICE_CHANGED') {
    $f = & $split ($T::TestSecondSnapshot($status, $luid, 'D', $name, 'OK', 40, 1, 1000, 10, 'OK', 5, 'OK', 0))
    Check ($f.Length -eq 14 -and $f[5] -eq $status -and (($f[6..13] | Where-Object { $_ -ne '?' }).Count -eq 0)) "$status carries nothing"
}
# Invalid inputs degrade to UNAVAILABLE or unknown fields, never a guess.
$f = & $split ($T::TestSecondSnapshot('BOGUS', $luid, 'D', $name, 'OK', 40, 1, 1000, 10, 'OK', 5, 'OK', 0))
Check ($f[5] -eq 'UNAVAILABLE') 'unknown status'
$f = & $split ($T::TestSecondSnapshot('OK', '12345', 'D', $name, 'OK', 40, 1, 1000, 10, 'OK', 5, 'OK', 0))
Check ($f[5] -eq 'UNAVAILABLE' -and $f[6] -eq '?') 'malformed LUID'
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'X', $name, 'OK', 40, 1, 1000, 10, 'OK', 5, 'OK', 0))
Check ($f[5] -eq 'UNAVAILABLE') 'unknown kind'
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', 'XYZ', 'OK', 40, 1, 1000, 10, 'OK', 5, 'OK', 0))
Check ($f[8] -eq '?' -and $f[5] -eq 'OK') 'malformed name hex is withheld'
$f = & $split ($T::TestSecondSnapshot('OK', $luid, 'D', $name, 'OK', 40, 1, 1000, 2000, 'OK', 5, 'OK', 0))
Check ($f[12] -eq '?' -and $f[13] -eq '?') 'available above physical is invalid memory'
"PASS: $script:count pure second-GPU host assertions"

if ($Live) {
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $directory 'AdapterInfo.cs.txt')))
    foreach ($choice in '0', '1') {
        $info = [ParallaxGpuInfo]::ReadForSkin($choice)
        if ($info -notmatch 'GPU_ADAPTER\|1\|([0-9A-F]{16})$') { "LIVE: no main GPU for choice $choice; skipped"; continue }
        $main = $Matches[1]
        $found = $T::TestFindSecond($main)
        "LIVE choice=$choice main=$main second: $found"
        if ($found -notmatch '^OK\|([0-9A-F]{16})$') { Check ($found -match '^(NONE|UNSUPPORTED)\|') "second status for $main"; continue }
        $second = $Matches[1]
        Check ($second -ne $main) 'second differs from main'
        $frames = $T::TestLoadFrames($second, 1500)
        "LIVE second frames: $frames"
        $g = $frames.Split('|')
        Check ($g[0] -eq 'FRAMES') "second GPU opens ($frames)"
        Check ($g[8] -eq 'UNSUPPORTED' -and $g[9] -eq 'UNSUPPORTED' -and $g[10] -eq 'UNSUPPORTED') 'the load frame reads no temperature, power or clock'
        Check ($g[3] -eq 'OK' -and $g[4] -match '^\d+$') 'second load reads a figure by the second frame'
        if ($g[1] -eq 'I') { Check ($g[2] -eq 'STARTING' -and $g[7] -eq 'OK' -and [UInt64]$g[11] -gt 0) 'integrated: DXCore engines start, shared memory and limit read' }
        $session = $T::TestSession($main, '1', 3500).Split("`n")
        "LIVE session ($choice): " + ($session -join ' / ')
        Check ($session[0] -eq 'RUN') 'host session ran'
        Check ($session[1].StartsWith('GPU_TEMP|4|')) 'main snapshot keeps protocol 4'
        $s = $session[2].Split('|')
        Check ($s.Length -eq 14 -and $s[0] -eq 'GPU_SECOND' -and $s[5] -eq 'OK' -and $s[6] -eq $second) 'second snapshot names the second GPU'
        Check ($s[3] -eq $session[1].Split('|')[3]) 'second sample pairs with the main sequence'
        Check ($session[3] -eq 'STOPPED|CLEAN') 'host stopped on lease removal and removed every session file'
        if ($g[1] -eq 'I') {
            # The main discrete GPU read as a vendor without an NVIDIA driver would be.
            $dx = $T::TestDxcoreDiscrete($main, 1500)
            "LIVE discrete through DXCore: $dx"
            $d = $dx.Split('|')
            Check ($d[0] -eq 'DXCORE' -and $d[1] -eq 'D') 'discrete adapter opens without NVIDIA'
            Check ($d[2] -eq 'STARTING' -and $d[3] -eq 'OK' -and $d[4] -match '^\d+$' -and $d[6] -match '^\d+$') 'DXCore engines: starting, then core and video figures'
            Check ($d[5] -eq '?' -and $d[7] -eq '?') 'no memory-controller or bus figure through DXCore'
            Check ($d[8] -eq 'OK' -and [UInt64]$d[9] -gt 0 -and [UInt64]$d[10] -le [UInt64]$d[9]) 'dedicated memory in use through DXCore'
            Check ($d[12] -eq 'UNSUPPORTED' -and $d[13] -eq 'UNSUPPORTED' -and $d[14] -eq 'UNSUPPORTED') 'temperature, power and clock unsupported without NVIDIA'
        }
        $plain = $T::TestSession($main, $null, 2500).Split("`n")
        Check ($plain[0] -eq 'RUN' -and $plain[2] -eq '-' -and $plain[3] -eq 'STOPPED|CLEAN') 'Second GPU Off writes no second file'
    }
    "PASS: $script:count second-GPU assertions including live hardware"
}
