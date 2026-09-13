#requires -Version 5.1
# Compiles the production C# with deterministic, in-assembly test seams using
# the existing Windows .NET runtime. All temporary writes remain below a unique
# Tests/.runtime directory. No Rainmeter config changes or resident child host.
[CmdletBinding()]
param([switch]$ProbeNative)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runtimeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runtime'))
$scratch = Join-Path $runtimeRoot ('ram-page-provider-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($scratch)
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\PageFileHost.cs.txt'))
$harness = @'

public static class ParallaxRamPageFileTests
{
    private static int checks;
    private const string Token = "0123456789abcdef0123456789abcdef";
    private static void Check(bool condition, string message)
    { ++checks; if (!condition) throw new Exception(message); }
    private static void Throws(Action action, string message)
    {
        bool threw = false;
        try { action(); } catch (ArgumentException) { threw = true; } catch (InvalidOperationException) { threw = true; }
        Check(threw, message);
    }
    private static ParallaxRamPageFile.PageFileInformation Info(ulong used, ulong total)
    {
        ParallaxRamPageFile.PageFileInformation info = new ParallaxRamPageFile.PageFileInformation();
        info.Size = (uint)Marshal.SizeOf(typeof(ParallaxRamPageFile.PageFileInformation));
        info.TotalInUse = new UIntPtr(used);
        info.TotalSize = new UIntPtr(total);
        info.PeakUsage = new UIntPtr(1);
        return info;
    }
    private static ParallaxRamPageFile.Frame Collect(int pageSize, bool complete, params ulong[][] rows)
    {
        return ParallaxRamPageFile.Collect(pageSize, delegate(ParallaxRamPageFile.PageFileCallback callback)
        {
            foreach (ulong[] row in rows)
            {
                ParallaxRamPageFile.PageFileInformation info = Info(row[0], row[1]);
                // Deliberately invalid filename pointer: the provider must ignore it.
                if (!callback(IntPtr.Zero, ref info, new IntPtr(1))) return false;
            }
            return complete;
        });
    }
    private static void Frame(ParallaxRamPageFile.Frame frame, string status, ulong? used, ulong? total, int? count)
    {
        Check(frame.Status == status, "Frame status");
        Check(frame.Used == used, "Frame used");
        Check(frame.Total == total, "Frame total");
        Check(frame.Count == count, "Frame count");
    }
    private static ParallaxRamPageFile.Paths NewPaths()
    { return new ParallaxRamPageFile.Paths(Guid.NewGuid().ToString("N")); }
    private static void Lease(ParallaxRamPageFile.Paths paths, long epoch)
    { File.WriteAllText(paths.Lease, paths.Token + "|" + epoch.ToString(CultureInfo.InvariantCulture), Encoding.ASCII); }
    private sealed class Guard : ParallaxRamPageFile.IGuard
    {
        internal readonly ParallaxRamPageFile.Paths Paths;
        internal long Time = 10000;
        internal bool Live = true;
        internal int Waits, Limit = 3, Step = 1;
        internal bool Renew, Corrupt;
        internal readonly List<string> Samples = new List<string>();
        internal Guard(ParallaxRamPageFile.Paths paths) { Paths = paths; }
        public bool Alive { get { return Live; } }
        public bool Wait(int milliseconds)
        {
            Check(milliseconds == 1000, "Requested cadence unchanged");
            Samples.Add(File.ReadAllText(Paths.Data, Encoding.ASCII));
            ++Waits;
            Time += Step;
            if (Renew) Lease(Paths, Time);
            if (Corrupt) File.WriteAllText(Paths.Lease, Paths.Token + "|", Encoding.ASCII);
            return Waits < Limit;
        }
    }
    private static void Cleaned(ParallaxRamPageFile.Paths paths)
    {
        Check(!File.Exists(paths.Data), "Session data cleaned");
        Check(!File.Exists(paths.Lease), "Session lease cleaned");
        Check(!File.Exists(paths.Temporary), "Session temporary cleaned");
    }
    [DllImport("kernel32.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    private static extern IntPtr CreateEventW(IntPtr attributes, [MarshalAs(UnmanagedType.Bool)] bool manualReset,
        [MarshalAs(UnmanagedType.Bool)] bool initialState, string name);
    [DllImport("kernel32.dll", ExactSpelling = true)]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool SetEvent(IntPtr handle);
    private static void RetainedHandle()
    {
        // An unnamed native event exercises the same wait/signaled states as a
        // retained process handle without launching or terminating a process.
        Type type = typeof(ParallaxRamPageFile).GetNestedType("ParentGuard", System.Reflection.BindingFlags.NonPublic);
        System.Reflection.ConstructorInfo constructor = type.GetConstructor(System.Reflection.BindingFlags.NonPublic |
            System.Reflection.BindingFlags.Instance, null, new Type[] { typeof(IntPtr) }, null);
        IntPtr handle = CreateEventW(IntPtr.Zero, true, false, null);
        Check(handle != IntPtr.Zero, "Owned unnamed wait handle created");
        object guard = constructor.Invoke(new object[] { handle });
        try
        {
            ParallaxRamPageFile.IGuard lifetime = (ParallaxRamPageFile.IGuard)guard;
            Check(lifetime.Alive && lifetime.Wait(0), "Unsignaled retained handle permits work");
            Check(SetEvent(handle), "Owned lifetime handle signals");
            Check(!lifetime.Alive && !lifetime.Wait(0), "Signaled retained handle stops work");
        }
        finally { ((IDisposable)guard).Dispose(); }
        Check((IntPtr)type.GetField("handle", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance).GetValue(guard) == IntPtr.Zero,
            "Dispose releases retained handle");
        guard = constructor.Invoke(new object[] { IntPtr.Zero });
        Check(((ParallaxRamPageFile.IGuard)guard).Alive && ((ParallaxRamPageFile.IGuard)guard).Wait(0), "Unavailable ancestry preserves lease fallback");
        ((IDisposable)guard).Dispose();
        // Capture reads ancestry only; no global-name process selection or PID termination.
        object captured = type.GetMethod("Capture", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).Invoke(null, null);
        try { Check(((ParallaxRamPageFile.IGuard)captured).Alive, "Actual ancestry capture is usable or falls back"); }
        finally { ((IDisposable)captured).Dispose(); }
    }
    private static void Lifecycle()
    {
        ParallaxRamPageFile.Paths paths = NewPaths();
        Guard guard = new Guard(paths);
        Lease(paths, guard.Time);
        int calls = 0;
        ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
        {
            if (++calls == 1)
            {
                Check(File.ReadAllText(paths.Data).Contains("|0|10000|STARTING|?|?|?"), "STARTING precedes sample");
                return new ParallaxRamPageFile.Frame("UNAVAILABLE");
            }
            return calls == 2 ? new ParallaxRamPageFile.Frame("OK", 4096, 8192, 1) : new ParallaxRamPageFile.Frame("NONE", 0, 0, 0);
        });
        Check(calls == 3 && guard.Samples.Count == 3, "Ordinary error retries");
        Check(guard.Samples[0].Contains("|1|10000|UNAVAILABLE|?|?|?"), "Unavailable sample");
        Check(guard.Samples[1].Contains("|2|10001|OK|4096|8192|1"), "Recovery sample");
        Check(guard.Samples[2].Contains("|3|10002|NONE|0|0|0"), "No files recovery sample");
        Cleaned(paths);

        paths = NewPaths(); guard = new Guard(paths); Lease(paths, guard.Time); calls = 0;
        ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
        { ++calls; return new ParallaxRamPageFile.Frame("UNSUPPORTED"); });
        Check(calls == 1 && guard.Samples.Count == 3, "Unsupported is terminal for native calls");
        Check(guard.Samples[2].Contains("|3|10002|UNSUPPORTED|?|?|?"), "Unsupported heartbeat continues");
        Cleaned(paths);

        foreach (bool corrupt in new bool[] { false, true })
        {
            paths = NewPaths(); guard = new Guard(paths); guard.Step = 5; guard.Limit = 8; guard.Corrupt = corrupt;
            Lease(paths, guard.Time); calls = 0;
            ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
            { ++calls; return new ParallaxRamPageFile.Frame("NONE", 0, 0, 0); });
            Check(calls == 4, "Expired or truncated lease stops at freshness boundary");
            Cleaned(paths);
        }
        paths = NewPaths(); guard = new Guard(paths); guard.Step = 5; guard.Limit = 6; guard.Renew = true;
        Lease(paths, guard.Time); calls = 0;
        ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
        { ++calls; return new ParallaxRamPageFile.Frame("NONE", 0, 0, 0); });
        Check(calls == 6, "Valid UI renewal extends lifetime");
        Cleaned(paths);

        paths = NewPaths(); guard = new Guard(paths); guard.Live = false; Lease(paths, guard.Time); calls = 0;
        ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
        { ++calls; return new ParallaxRamPageFile.Frame("UNAVAILABLE"); });
        Check(calls == 0, "Dead retained parent prevents sampling"); Cleaned(paths);

        paths = NewPaths(); guard = new Guard(paths); Lease(paths, guard.Time + 6); calls = 0;
        ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate
        { ++calls; return new ParallaxRamPageFile.Frame("UNAVAILABLE"); });
        Check(calls == 0 && !File.Exists(paths.Data), "Invalid initial lease prevents work");
        File.Delete(paths.Lease);

        paths = NewPaths(); guard = new Guard(paths); Lease(paths, guard.Time);
        File.WriteAllText(paths.Data, "existing", Encoding.ASCII);
        bool failed = false;
        try { ParallaxRamPageFile.RunSession(paths, 1000, guard, delegate { return guard.Time; }, delegate { return new ParallaxRamPageFile.Frame("UNAVAILABLE"); }); }
        catch (IOException) { failed = true; }
        Check(failed && File.ReadAllText(paths.Data) == "existing", "Initial collision never overwrites or removes an existing data file");
        Check(!File.Exists(paths.Temporary), "Failed initial move removes only own temporary");
        File.Delete(paths.Data);
    }
    public static string Run(string scratch, bool probeNative)
    {
        checks = 0;
        string root = Path.GetFullPath(scratch).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        Check(Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar == root, "Temp scope is isolated");
        int before = Directory.GetFiles(scratch).Length;
        string session = ParallaxRamPageFile.CreateSession(1000);
        string[] parts = session.Split('|');
        Check(parts.Length == 4 && parts[0] == "RAM_PAGE_SESSION" && parts[1] == "1", "Bootstrap protocol");
        Check(System.Text.RegularExpressions.Regex.IsMatch(parts[2], "^[0-9a-f]{32}$"), "Canonical token");
        byte[] pathBytes = new byte[parts[3].Length / 2];
        for (int i = 0; i < pathBytes.Length; ++i) pathBytes[i] = Byte.Parse(parts[3].Substring(i * 2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        string dataPath = new UTF8Encoding(false, true).GetString(pathBytes);
        Check(dataPath == Path.Combine(scratch, "Parallax-RAM-Page-" + parts[2] + ".dat"), "Token-derived UTF-8 path");
        Check(Directory.GetFiles(scratch).Length == before, "Bootstrap writes no files");
        Check(ParallaxRamPageFile.CreateSession(30000) != session, "Unique sessions");
        string previousTemp = Environment.GetEnvironmentVariable("TEMP"), previousTmp = Environment.GetEnvironmentVariable("TMP");
        try
        {
            string unicodePath = Path.Combine(scratch, "\u00e9-\u4e2d");
            Environment.SetEnvironmentVariable("TEMP", unicodePath);
            Environment.SetEnvironmentVariable("TMP", unicodePath);
            string[] unicodeParts = ParallaxRamPageFile.CreateSession(1000).Split('|');
            string expectedPath = Path.Combine(unicodePath, "Parallax-RAM-Page-" + unicodeParts[2] + ".dat");
            Check(unicodeParts[3] == BitConverter.ToString(Encoding.UTF8.GetBytes(expectedPath)).Replace("-", ""), "Unicode temporary path uses exact UTF-8 hex");
            Check(!Directory.Exists(unicodePath), "Unicode bootstrap still writes nothing");
        }
        finally { Environment.SetEnvironmentVariable("TEMP", previousTemp); Environment.SetEnvironmentVariable("TMP", previousTmp); }
        Throws(delegate { ParallaxRamPageFile.CreateSession(999); }, "Reject fast interval");
        Throws(delegate { ParallaxRamPageFile.CreateSession(30001); }, "Reject slow interval");
        foreach (string bad in new string[] { null, "", "../bad", Token + "x", Token.Substring(1), Token.ToUpperInvariant(), new String('z', 32) })
            Throws(delegate { ParallaxRamPageFile.Run(bad, 1000); }, "Reject malformed token");
        Throws(delegate { ParallaxRamPageFile.Run(Token, 0); }, "Run validates interval");
        ParallaxRamPageFile.Run(Token, 1000);
        Check(!File.Exists(new ParallaxRamPageFile.Paths(Token).Data), "Missing lease creates no sample");

        Check(Marshal.SizeOf(typeof(ParallaxRamPageFile.PageFileInformation)) == 8 + 3 * IntPtr.Size, "Native SIZE_T structure size");
        Check(Marshal.OffsetOf(typeof(ParallaxRamPageFile.PageFileInformation), "TotalSize").ToInt32() == 8, "Native TotalSize offset");
        Check(Marshal.OffsetOf(typeof(ParallaxRamPageFile.PageFileInformation), "TotalInUse").ToInt32() == 8 + IntPtr.Size, "Native usage offset");
        object[] callbackAttributes = typeof(ParallaxRamPageFile.PageFileCallback).GetCustomAttributes(typeof(UnmanagedFunctionPointerAttribute), false);
        Check(((UnmanagedFunctionPointerAttribute)callbackAttributes[0]).CallingConvention == CallingConvention.StdCall, "Native callback stdcall");
        foreach (System.Reflection.MethodInfo method in typeof(ParallaxRamPageFile).GetMethods(System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static))
        {
            object[] imports = method.GetCustomAttributes(typeof(DllImportAttribute), false);
            if (imports.Length == 0) continue;
            object[] searches = method.GetCustomAttributes(typeof(DefaultDllImportSearchPathsAttribute), false);
            Check(searches.Length == 1 && ((DefaultDllImportSearchPathsAttribute)searches[0]).Paths == DllImportSearchPath.System32, "Every import is System32-only");
        }

        Frame(Collect(4096, true, new ulong[] { 2, 8 }), "OK", 8192, 32768, 1);
        Frame(Collect(8192, true, new ulong[] { 2, 8 }, new ulong[] { 1, 4 }), "OK", 24576, 98304, 2);
        Frame(Collect(4096, true, new ulong[] { 0, 8 }), "OK", 0, 32768, 1);
        Frame(Collect(4096, true, new ulong[] { 8, 8 }), "OK", 32768, 32768, 1);
        Frame(Collect(4096, true, new ulong[] { 0, 0 }), "OK", 0, 0, 1);
        Frame(Collect(4096, true), "NONE", 0, 0, 0);
        Frame(Collect(4096, false), "UNAVAILABLE", null, null, null);
        Frame(Collect(4096, false, new ulong[] { 1, 8 }), "UNAVAILABLE", null, null, null);
        Frame(Collect(0, true, new ulong[] { 1, 8 }), "UNAVAILABLE", null, null, null);
        Frame(Collect(-1, true), "UNAVAILABLE", null, null, null);
        Frame(Collect(4096, true, new ulong[] { 9, 8 }), "UNAVAILABLE", null, null, null);
        Frame(Collect(Int32.MaxValue, true, new ulong[] { 0, 4194305 }), "UNAVAILABLE", null, null, null);
        Frame(Collect(Int32.MaxValue, true, new ulong[] { 0, 4194304 }, new ulong[] { 0, 1 }), "UNAVAILABLE", null, null, null);
        Frame(Collect(Int32.MaxValue, true, new ulong[] { 4194304, 4194304 }), "OK", 9007199250546688, 9007199250546688, 1);
        Frame(ParallaxRamPageFile.Collect(4096, delegate(ParallaxRamPageFile.PageFileCallback callback)
        { ParallaxRamPageFile.PageFileInformation info = Info(1, 8); info.Size = 0; callback(IntPtr.Zero, ref info, IntPtr.Zero); return true; }), "UNAVAILABLE", null, null, null);
        Frame(ParallaxRamPageFile.Collect(4096, delegate(ParallaxRamPageFile.PageFileCallback callback)
        { for (int i = 0; i < 513; ++i) { ParallaxRamPageFile.PageFileInformation info = Info(0, 1); if (!callback(IntPtr.Zero, ref info, IntPtr.Zero)) break; } return true; }), "UNAVAILABLE", null, null, null);
        foreach (Exception error in new Exception[] { new DllNotFoundException(), new EntryPointNotFoundException(), new BadImageFormatException(), new PlatformNotSupportedException(), new IOException(), new UnauthorizedAccessException() })
            Frame(ParallaxRamPageFile.Collect(4096, delegate(ParallaxRamPageFile.PageFileCallback callback) { throw error; }),
                error is IOException || error is UnauthorizedAccessException ? "UNAVAILABLE" : "UNSUPPORTED", null, null, null);

        foreach (int interval in new int[] { 1000, 5000, 5001, 30000 })
        {
            long age = Math.Max(15, (3 * interval + 999) / 1000);
            Check(ParallaxRamPageFile.LeaseFresh(10000 - age, 10000, interval), "Inclusive lease age");
            Check(!ParallaxRamPageFile.LeaseFresh(9999 - age, 10000, interval), "Expired lease");
            Check(ParallaxRamPageFile.LeaseFresh(10005, 10000, interval), "Future tolerance boundary");
            Check(!ParallaxRamPageFile.LeaseFresh(10006, 10000, interval), "Future lease rejected");
        }
        long timestamp;
        Check(ParallaxRamPageFile.ParseLease(Token + "|10000", Token, 10000, 1000, out timestamp) && timestamp == 10000, "Canonical lease");
        foreach (string value in new string[] { null, "", Token + "|", Token + "|010000", Token + "|-1", Token + "|+10000", Token + "|10000\n", Token + "|10000 ", Token + "|1e4", Token + "|253402300800", Token + "|9999999999999", Token.ToUpperInvariant() + "|10000", Token + "|\u0661" })
            Check(!ParallaxRamPageFile.ParseLease(value, Token, 10000, 1000, out timestamp), "Malformed lease rejected");
        Check(!ParallaxRamPageFile.LeaseFresh(-1, 10000, 1000), "Negative timestamp rejected");
        Check(!ParallaxRamPageFile.LeaseFresh(10000, -1, 1000), "Negative clock rejected");
        ParallaxRamPageFile.Paths leasePaths = NewPaths();
        File.WriteAllBytes(leasePaths.Lease, new byte[] { 255 });
        Check(!ParallaxRamPageFile.ReadLease(leasePaths, 10000, 1000, out timestamp), "Non-ASCII lease rejected");
        File.WriteAllText(leasePaths.Lease, new String('x', 129));
        Check(!ParallaxRamPageFile.ReadLease(leasePaths, 10000, 1000, out timestamp), "Oversized lease rejected");
        File.Delete(leasePaths.Lease);

        foreach (string status in new string[] { "STARTING", "UNAVAILABLE", "UNSUPPORTED" })
            Check(ParallaxRamPageFile.Snapshot(Token, 0, 0, new ParallaxRamPageFile.Frame(status)) == "RAM_PAGE|1|" + Token + "|0|0|" + status + "|?|?|?", "Unknown protocol has no numeric values");
        Check(ParallaxRamPageFile.Snapshot(Token, ParallaxRamPageFile.MaximumInteger, 253402300799, new ParallaxRamPageFile.Frame("OK", 0, (ulong)ParallaxRamPageFile.MaximumInteger, 512)).Length <= 512, "Maximum snapshot bounded");
        Check(ParallaxRamPageFile.Snapshot(Token, 1, 1, new ParallaxRamPageFile.Frame("NONE", 0, 0, 0)).EndsWith("|NONE|0|0|0", StringComparison.Ordinal), "NONE protocol");
        foreach (ParallaxRamPageFile.Frame frame in new ParallaxRamPageFile.Frame[] {
            null, new ParallaxRamPageFile.Frame("bad"), new ParallaxRamPageFile.Frame("OK"), new ParallaxRamPageFile.Frame("OK", 1, 0, 1),
            new ParallaxRamPageFile.Frame("OK", 0, 1, 0), new ParallaxRamPageFile.Frame("OK", 0, 1, 513),
            new ParallaxRamPageFile.Frame("OK", 0, (ulong)ParallaxRamPageFile.MaximumInteger + 1, 1),
            new ParallaxRamPageFile.Frame("NONE", 0, 1, 0), new ParallaxRamPageFile.Frame("NONE", 0, 0, 1),
            new ParallaxRamPageFile.Frame("UNAVAILABLE", 0, 0, 0) })
            Throws(delegate { ParallaxRamPageFile.Snapshot(Token, 0, 0, frame); }, "Invalid snapshot rejected");
        Throws(delegate { ParallaxRamPageFile.Snapshot(Token, -1, 0, new ParallaxRamPageFile.Frame("STARTING")); }, "Negative sequence rejected");
        Throws(delegate { ParallaxRamPageFile.Snapshot(Token, ParallaxRamPageFile.MaximumInteger + 1, 0, new ParallaxRamPageFile.Frame("STARTING")); }, "Unsafe sequence rejected");
        Throws(delegate { ParallaxRamPageFile.Snapshot(Token, 0, -1, new ParallaxRamPageFile.Frame("STARTING")); }, "Negative epoch rejected");
        Throws(delegate { ParallaxRamPageFile.Snapshot(Token, 0, 253402300800, new ParallaxRamPageFile.Frame("STARTING")); }, "Oversized epoch rejected");

        ParallaxRamPageFile.Paths atomic = NewPaths();
        string first = ParallaxRamPageFile.Snapshot(atomic.Token, 0, 0, new ParallaxRamPageFile.Frame("STARTING"));
        string second = ParallaxRamPageFile.Snapshot(atomic.Token, 1, 1, new ParallaxRamPageFile.Frame("OK", 0, 4096, 1));
        ParallaxRamPageFile.WriteSnapshot(atomic, first, true);
        using (FileStream reader = new FileStream(atomic.Data, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            ParallaxRamPageFile.WriteSnapshot(atomic, second, false);
            byte[] oldBytes = new byte[reader.Length];
            reader.Read(oldBytes, 0, oldBytes.Length);
            Check(Encoding.ASCII.GetString(oldBytes) == first, "Open reader retains complete old snapshot");
            Check(File.ReadAllText(atomic.Data) == second, "New reader sees complete replacement");
        }
        using (FileStream locked = new FileStream(atomic.Data, FileMode.Open, FileAccess.Read, FileShare.Read))
        {
            bool blocked = false;
            try { ParallaxRamPageFile.WriteSnapshot(atomic, first, false); } catch (IOException) { blocked = true; }
            Check(blocked, "Denied replacement fails safely");
            Check(File.ReadAllText(atomic.Data) == second, "Denied replacement preserves previous sample");
            Check(!File.Exists(atomic.Temporary), "Denied replacement removes own temporary");
        }
        File.WriteAllText(atomic.Temporary, "existing");
        bool collision = false;
        try { ParallaxRamPageFile.WriteSnapshot(atomic, first, false); } catch (IOException) { collision = true; }
        Check(collision && File.ReadAllText(atomic.Temporary) == "existing", "Temporary collision not overwritten or deleted");
        File.Delete(atomic.Temporary); File.Delete(atomic.Data);
        Throws(delegate { ParallaxRamPageFile.WriteSnapshot(atomic, new String('x', 513), true); }, "Oversized write rejected");
        Throws(delegate { ParallaxRamPageFile.WriteSnapshot(atomic, "\u00e9", true); }, "Non-ASCII write rejected");
        Throws(delegate { ParallaxRamPageFile.WriteSnapshot(atomic, "bad\n", true); }, "Control character write rejected");
        Lifecycle();
        RetainedHandle();

        string native = "not requested";
        if (probeNative)
        {
            ParallaxRamPageFile.Frame frame = ParallaxRamPageFile.ReadFrame();
            Check(frame.Status == "OK" || frame.Status == "NONE" || frame.Status == "UNAVAILABLE" || frame.Status == "UNSUPPORTED", "Native state is honest");
            if (frame.Status == "OK" || frame.Status == "NONE")
            {
                Check(frame.Used <= frame.Total && frame.Total <= (ulong)ParallaxRamPageFile.MaximumInteger, "Native totals consistent");
                Check(frame.Used % (uint)Environment.SystemPageSize == 0 && frame.Total % (uint)Environment.SystemPageSize == 0, "Native totals page-aligned");
            }
            native = frame.Status + "; count=" + (frame.Count.HasValue ? frame.Count.Value.ToString(CultureInfo.InvariantCulture) : "?");
        }
        return "PASS: " + checks + " paging-file provider checks; " + (IntPtr.Size * 8) + "-bit ABI; native probe " + native + ". Deterministic lifecycle, aggregation, protocol, lease, collision and atomic replacement checks; no child hosts.";
    }
}
'@
try {
    $env:TEMP = $scratch
    $env:TMP = $scratch
    Add-Type -TypeDefinition ($source + [Environment]::NewLine + $harness) -Language CSharp
    $result = [ParallaxRamPageFileTests]::Run($scratch, [bool]$ProbeNative)
    [IO.File]::WriteAllText((Join-Path $scratch 'result.txt'), $result, [Text.Encoding]::UTF8)
    Write-Output $result
    Write-Output ('Evidence: ' + (Join-Path $scratch 'result.txt'))
}
finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
