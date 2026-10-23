#requires -Version 5.1
# Isolated lifecycle proof for a detached resident helper host: RAM's PAGE
# host (-Module RAM) or GPU's telemetry host (-Module GPU).
#
# Stages the suite with tools/Stage-Parallax.ps1 and starts an isolated
# Rainmeter (own Rainmeter.ini and SkinPath under build/, offscreen, own PID
# only) with the module and a small test-only control config. The control
# config executes bangs that this script drops as files into the run root, so
# no command-line bang is ever sent to any Rainmeter instance. It checks:
#   - the host runs detached: its launcher has exited and no PowerShell child
#     of Rainmeter remains, so no RunCommand thread is attached to it;
#   - no console window becomes visible while helpers start;
#   - Unload: !DeactivateConfig stops the host within one interval and removes
#     its session files; the module is then activated again;
#   - Suspend (optional): the Rainmeter process is suspended past the lease
#     window, then resumed; records whether the reading and a host come back;
#   - Finish Exit (!Quit) or Kill (Stop-Process): the host exits on its own.
# Rainmeter.log must contain no errors (Error 105 included). The live
# Rainmeter profile and installed skins are never read or changed.
[CmdletBinding()]
param(
    [ValidateSet('RAM','GPU')][string]$Module = 'RAM',
    [switch]$Suspend,
    [ValidateRange(16,120)][int]$SuspendSeconds = 20,
    [ValidateRange(10,180)][int]$RecoverySeconds = 45,
    [ValidateSet('Exit','Kill')][string]$Finish = 'Exit',
    [switch]$SkipUnload,
    # Seconds to watch after the first reading: every skin update must keep
    # showing a current reading (no stale or Checking flicker).
    [ValidateRange(0,600)][int]$ObserveSeconds = 0,
    [string]$ProjectRoot,
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
if (-not $ProjectRoot) { $ProjectRoot = Join-Path $PSScriptRoot '..\..\..\..\..\..' }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$spec = @{
    RAM = @{ Config = 'Parallax\RAM'; File = 'RAM.ini'; Source = 'PageFileHost.cs.txt'; Prefix = 'Parallax-RAM-Page-'
        Meter = 'MeterRAMPageGiB'; Reading = '^\d+(\.\d+)?/\d+(\.\d+)? (GB|TB)$|^No paging file$'; IntervalSeconds = 1 }
    GPU = @{ Config = 'Parallax\GPU'; File = 'GPU.ini'; Source = 'DriverTemperature.cs.txt'; Prefix = 'Parallax-GPU-'
        # Celsius sign bytes depend on the Lua code page; match any one or two.
        Meter = 'MeterTemperatureValue'; Reading = '^-?\d+ \S{1,2}C$|^Unsupported$'; IntervalSeconds = 2 }
}[$Module]
$stage = & (Join-Path $ProjectRoot 'tools\Stage-Parallax.ps1') -Version ($Module.ToLowerInvariant() + '-lifecycle') -ProjectRoot $ProjectRoot
$runRoot = $stage.StageRoot
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside generated test directory.' }
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
foreach ($name in @('Layouts','Plugins','Addons')) { $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $name) }
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated helper lifecycle check with test-stage instrumentation. Do not distribute."
$observedPath = Join-Path $runRoot 'observed.txt'
$harnessPath = Join-Path $runRoot 'LifecycleHarness.lua'
Write-RunFile $harnessPath @"
-- Appended last: records the module's own reading after its controller runs.
function Update()
    local meter = SKIN:GetMeter('$($spec.Meter)')
    local text = meter and meter:GetOption('Text', '') or '?'
    local f = io.open([=[$observedPath]=], 'ab'); f:write(os.time(), '|', text, '\n'); f:close()
    return 0
end
"@
$mainPath = Join-Path $parallaxRoot ($Module + '\' + $spec.File)
Write-RunFile $mainPath ([IO.File]::ReadAllText($mainPath) + "`r`n[MeasureLifecycleHarness]`r`nMeasure=Script`r`nScriptFile=$harnessPath`r`n")
$controlPath = Join-Path $runRoot 'Control.lua'
Write-RunFile $controlPath @"
-- Test-only: executes one bang per file dropped by the lifecycle script.
local root = [=[$runRoot\]=]
function Update()
    for index = 1, 9 do
        local path = root .. 'command' .. index .. '.txt'
        local f = io.open(path, 'rb')
        if f then
            local bang = f:read('*a'); f:close(); os.remove(path)
            local done = io.open(root .. 'command' .. index .. '.done', 'wb'); done:write(os.time()); done:close()
            SKIN:Bang(bang)
            return 0
        end
    end
    return 0
end
"@
Write-RunFile (Join-Path $parallaxRoot 'LifecycleControl\Control.ini') "[Rainmeter]`r`nUpdate=200`r`n[MeasureControl]`r`nMeasure=Script`r`nScriptFile=$controlPath`r`n[MeterBounds]`r`nMeter=String`r`nW=1`r`nH=1`r`n"
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$window = "WindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
Write-RunFile $iniPath ("[Rainmeter]`nSkinPath=$runRoot\Skins\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n" +
    "[$($spec.Config)]`nActive=1`n$window[Parallax\LifecycleControl]`nActive=1`n$window")
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"

if (-not ('ParallaxLifecycleNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class ParallaxLifecycleNative
{
    private delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassNameW(IntPtr window, StringBuilder name, int count);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("ntdll.dll")] private static extern int NtSuspendProcess(IntPtr process);
    [DllImport("ntdll.dll")] private static extern int NtResumeProcess(IntPtr process);
    private static readonly HashSet<string> consoleClasses = new HashSet<string>(StringComparer.Ordinal)
        { "ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS", "PseudoConsoleWindow" };
    private static HashSet<IntPtr> baseline;
    private static readonly List<string> appeared = new List<string>();
    private static volatile bool watching;
    private static Thread watcher;
    private static List<KeyValuePair<IntPtr, string>> VisibleConsoles()
    {
        List<KeyValuePair<IntPtr, string>> found = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows(delegate(IntPtr window, IntPtr unused)
        {
            if (!IsWindowVisible(window)) return true;
            StringBuilder name = new StringBuilder(256);
            GetClassNameW(window, name, name.Capacity);
            if (consoleClasses.Contains(name.ToString()))
            {
                uint process; GetWindowThreadProcessId(window, out process);
                found.Add(new KeyValuePair<IntPtr, string>(window, name + " pid " + process));
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    // Polls every 10 ms for console windows that become visible after the
    // baseline. A console flash is visible for about 200 ms.
    public static void StartWatch()
    {
        baseline = new HashSet<IntPtr>();
        foreach (KeyValuePair<IntPtr, string> item in VisibleConsoles()) baseline.Add(item.Key);
        lock (appeared) appeared.Clear();
        watching = true;
        watcher = new Thread(delegate()
        {
            while (watching)
            {
                foreach (KeyValuePair<IntPtr, string> item in VisibleConsoles())
                    if (baseline.Add(item.Key)) lock (appeared) appeared.Add(DateTime.Now.ToString("HH:mm:ss.fff") + " " + item.Value);
                Thread.Sleep(10);
            }
        });
        watcher.IsBackground = true;
        watcher.Start();
    }
    public static string[] StopWatch()
    {
        watching = false;
        if (watcher != null) watcher.Join(2000);
        lock (appeared) return appeared.ToArray();
    }
    public static int Suspend(IntPtr process) { return NtSuspendProcess(process); }
    public static int Resume(IntPtr process) { return NtResumeProcess(process); }
}
'@
}

$sourcePath = Join-Path $parallaxRoot ('@Resources\Modules\' + $Module + '\' + $spec.Source)
$commandIndex = 0
$result = [ordered]@{ Module = $Module; RunRoot = $runRoot; Passed = $false; Checks = [Collections.Generic.List[string]]::new() }
function Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $result.Checks.Add($Message)
}
function Send-Bang([string]$Bang) {
    $script:commandIndex++
    if ($script:commandIndex -gt 9) { throw 'Too many control commands.' }
    $path = Join-Path $runRoot ('command' + $script:commandIndex + '.txt')
    Write-RunFile $path $Bang
    $done = [IO.Path]::ChangeExtension($path, '.done')
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $done)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "Control config did not run: $Bang" }
        Start-Sleep -Milliseconds 50
    }
}
function Get-Reading {
    if (-not (Test-Path -LiteralPath $observedPath)) { return $null }
    $last = @(Get-Content -LiteralPath $observedPath -Encoding UTF8 -Tail 1)
    if (-not $last.Count) { return $null }
    $parts = $last[0].Split('|', 2)
    if ($parts.Count -lt 2) { return $null }
    [pscustomobject]@{ Time = [long]$parts[0]; Text = $parts[1] }
}
function Wait-Reading([int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $reading = Get-Reading
        if ($null -ne $reading -and $reading.Text -match $spec.Reading) { return $reading }
        Start-Sleep -Milliseconds 250
    }
    $reading = Get-Reading
    throw ("No {0} reading within {1} s (last: {2})" -f $Module, $Seconds, $(if ($reading) { $reading.Text } else { 'none' }))
}
# Every staged host carries the staged source path on its command line.
function Get-Hosts {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.IndexOf($sourcePath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine -match "::Run\('"
    })
}
function Get-SessionFiles([string]$Token) {
    @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter ($spec.Prefix + $Token + '.*') -ErrorAction SilentlyContinue | ForEach-Object Name)
}
function Get-Token($HostProcess) { ([regex]::Match($HostProcess.CommandLine, "::Run\('([0-9a-f]{32})'")).Groups[1].Value }
function Wait-Exit([int]$ProcessId, [double]$Seconds) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return [Math]::Round($watch.Elapsed.TotalSeconds, 2) }
        Start-Sleep -Milliseconds 50
    }
    return $null
}
function Assert-Detached($Rainmeter, [string]$Label) {
    $hosts = @(Get-Hosts)
    Check ($hosts.Count -eq 1) "$Label`: exactly one $Module host runs (found $($hosts.Count))"
    $hostProcess = $hosts[0]
    Check ($hostProcess.CommandLine -match '-WindowStyle Hidden -Command "') "$Label`: the host was started with a hidden window style"
    $hostStart = (Get-Process -Id $hostProcess.ProcessId).StartTime
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        # A parent ID now naming a younger process is a reused ID: the launcher is gone.
        $parent = Get-Process -Id $hostProcess.ParentProcessId -ErrorAction SilentlyContinue
        $launcherGone = $null -eq $parent -or $parent.StartTime -gt $hostStart
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($Rainmeter.Id)" | Where-Object { $_.Name -eq 'powershell.exe' })
        if ($launcherGone -and -not $children.Count) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    Check $launcherGone "$Label`: the launcher exited, leaving the host detached"
    Check ($children.Count -eq 0) "$Label`: no PowerShell remains a RunCommand child of Rainmeter"
    return $hostProcess
}

$rainmeter = $null
$leftover = @()
try {
    if (@(Get-Hosts).Count) { throw 'A host for this staged path already runs.' }
    [ParallaxLifecycleNative]::StartWatch()
    $rainmeter = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $first = Wait-Reading 90
    $result.FirstReading = $first.Text
    $hostProcess = Assert-Detached $rainmeter 'Load'
    $token = Get-Token $hostProcess
    Check ($token -ne '') 'Load: the host command carries its session token'
    $files = @(Get-SessionFiles $token)
    Check (($files -contains ($spec.Prefix + $token + '.dat')) -and ($files -contains ($spec.Prefix + $token + '.lease'))) 'Load: the session holds its snapshot and lease'
    if ($ObserveSeconds) {
        $mark = @(Get-Content -LiteralPath $observedPath -Encoding UTF8).Count
        Start-Sleep -Seconds $ObserveSeconds
        $watched = @(Get-Content -LiteralPath $observedPath -Encoding UTF8 | Select-Object -Skip $mark | ForEach-Object { ($_ -split '\|', 2)[1] })
        $other = @($watched | Where-Object { $_ -notmatch $spec.Reading })
        $result.ObservedUpdates = $watched.Count
        $result.ObservedNonReadings = ($other | Select-Object -Unique) -join ', '
        Check ($watched.Count -ge $ObserveSeconds / 2 -and $other.Count -eq 0) "Observe: all $($watched.Count) updates over $ObserveSeconds s showed a current reading"
    }

    if (-not $SkipUnload) {
        Send-Bang ('!DeactivateConfig "' + $spec.Config + '"')
        $seconds = Wait-Exit $hostProcess.ProcessId ($spec.IntervalSeconds + 3)
        $result.UnloadExitSeconds = $seconds
        Check ($null -ne $seconds) "Unload: the host exited within one interval plus 3 s ($seconds s)"
        Start-Sleep -Milliseconds 500
        Check (@(Get-SessionFiles $token).Count -eq 0) 'Unload: the session files were removed'
        Remove-Item -LiteralPath $observedPath -Force
        Send-Bang ('!ActivateConfig "' + $spec.Config + '" "' + $spec.File + '"')
        $null = Wait-Reading 90
        $hostProcess = Assert-Detached $rainmeter 'Reload'
        $token = Get-Token $hostProcess
    }

    if ($Suspend) {
        # The suspended main thread cannot renew the lease; the host gives up
        # after its lease window. Record what the skin shows afterwards.
        $handle = $rainmeter.Handle
        Check ([ParallaxLifecycleNative]::Suspend($handle) -eq 0) 'Suspend: Rainmeter suspended'
        $suspendedAt = [DateTime]::UtcNow
        $hostGoneAfter = Wait-Exit $hostProcess.ProcessId $SuspendSeconds
        while (([DateTime]::UtcNow - $suspendedAt).TotalSeconds -lt $SuspendSeconds) { Start-Sleep -Milliseconds 200 }
        Check ([ParallaxLifecycleNative]::Resume($handle) -eq 0) 'Suspend: Rainmeter resumed'
        $result.SuspendSeconds = $SuspendSeconds
        $result.HostExitedWhileSuspendedAfter = $hostGoneAfter
        $samples = [Collections.Generic.List[string]]::new()
        $recoverDeadline = [DateTime]::UtcNow.AddSeconds($RecoverySeconds)
        $recovered = $null
        while ([DateTime]::UtcNow -lt $recoverDeadline) {
            Start-Sleep -Seconds 1
            $reading = Get-Reading
            if ($reading) { $samples.Add($reading.Text) }
            $hosts = @(Get-Hosts)
            if ($reading -and $reading.Text -match $spec.Reading -and $hosts.Count -eq 1 -and $hosts[0].ProcessId -ne $hostProcess.ProcessId) {
                $recovered = [Math]::Round(($RecoverySeconds - ($recoverDeadline - [DateTime]::UtcNow).TotalSeconds), 1)
                $hostProcess = $hosts[0]; $token = Get-Token $hostProcess
                break
            }
        }
        $result.AfterResumeReadings = (@($samples | Select-Object -Unique) -join ' -> ')
        $result.HostsAfterResume = @(Get-Hosts).Count
        $result.RecoveredAfterSeconds = $recovered
        if ($null -eq $hostGoneAfter) {
            $result.SuspendOutcome = 'host survived the suspension'
        } elseif ($null -ne $recovered) {
            $result.SuspendOutcome = 'host exited on its lease; the skin started a new host'
            $null = Assert-Detached $rainmeter 'Recovery'
        } else {
            $result.SuspendOutcome = 'host exited on its lease; no host and no reading came back'
        }
    }

    $hosts = @(Get-Hosts)
    $finalHost = if ($hosts.Count) { $hosts[0] } else { $null }
    if ($Finish -eq 'Exit') {
        Send-Bang '!Quit'
    } else {
        Stop-Process -Id $rainmeter.Id -Force
    }
    $exited = $rainmeter.WaitForExit(20000)
    Check $exited "$Finish`: the isolated Rainmeter ended"
    if ($null -ne $finalHost) {
        # The retained ancestor handle signals at once; the lease is the fallback.
        $seconds = Wait-Exit $finalHost.ProcessId 20
        $result.FinishHostExitSeconds = $seconds
        Check ($null -ne $seconds) "$Finish`: the host exited after Rainmeter ended ($seconds s)"
        Check ($seconds -le $spec.IntervalSeconds + 2) "$Finish`: the host followed its retained Rainmeter handle, not only the lease"
        Start-Sleep -Milliseconds 500
        $remaining = @(Get-SessionFiles (Get-Token $finalHost))
        $result.FinishSessionFiles = $remaining -join ','
        if ($Finish -eq 'Exit') { Check ($remaining.Count -eq 0) 'Exit: the session files were removed' }
        else { Check (-not ($remaining -match '\.(dat|tmp)$')) 'Kill: the host removed its snapshot on its own exit' }
    }
    $flashes = [ParallaxLifecycleNative]::StopWatch()
    $result.VisibleConsoleWindows = $flashes -join '; '
    Check ($flashes.Count -eq 0) "No console window became visible ($($flashes -join '; '))"
    $log = Join-Path $runRoot 'Rainmeter.log'
    $problems = @(if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Where-Object { $_ -match '^(ERRO|WARN)' } })
    $result.LogProblems = $problems -join ' / '
    Check ($problems.Count -eq 0) 'Rainmeter.log has no errors or warnings (Error 105 included)'
    $result.Passed = $true
}
finally {
    $null = [ParallaxLifecycleNative]::StopWatch()
    if ($null -ne $rainmeter) {
        $rainmeter.Refresh()
        if (-not $rainmeter.HasExited) { Stop-Process -Id $rainmeter.Id -Force; $null = $rainmeter.WaitForExit(5000) }
    }
    # Leftover hosts of this staged path are a failure; stop only those.
    Start-Sleep -Seconds 1
    $leftover = @(Get-Hosts)
    foreach ($process in $leftover) { Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue }
    $result.LeftoverHosts = $leftover.Count
    $result.Checks = @($result.Checks)
    [IO.File]::WriteAllText((Join-Path $runRoot 'lifecycle-result.json'), ($result | ConvertTo-Json -Depth 4), $utf8)
}
if ($leftover.Count) { throw "FAIL: $($leftover.Count) host(s) outlived the test; inspect $runRoot" }
$result.GetEnumerator() | Where-Object { $_.Key -ne 'Checks' } | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }
'PASS: {0} lifecycle checks' -f $result.Checks.Count
