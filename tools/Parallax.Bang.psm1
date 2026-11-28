# Send a bang to one named Rainmeter instance (docs\DEVMODE.md).
#
# "Rainmeter.exe !Bang" hands the bang to the first control window Windows finds, so while an isolated test
# instance is running the bang can land there instead of in the Rainmeter in use. This module picks the target
# by process first and sends the same message to that process's window only:
#
#   instance   = executable path + settings file. The executable alone is not enough: the test harnesses start
#                the installed Rainmeter.exe with a settings file of their own.
#   message    = WM_COPYDATA, dwData 1, a NUL-terminated UTF-16 bang, to the window of class DummyRainWClass
#                titled "Rainmeter control window" (https://docs.rainmeter.net/developers/, "Using SendMessage
#                with External Applications"; the window title and the handler are in Library\Rainmeter.cpp).
#
# Nothing here ever runs Rainmeter.exe. Anything short of exactly one match throws.
#
#   Import-Module .\tools\Parallax.Bang.psm1
#   Send-ParallaxBang '!Refresh' 'ParallaxDev\CPU'

Set-StrictMode -Version Latest

if (-not ('ParallaxBang.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace ParallaxBang {
    public static class Native {
        [StructLayout(LayoutKind.Sequential)]
        private struct COPYDATASTRUCT { public IntPtr dwData; public int cbData; public IntPtr lpData; }
        [DllImport("user32.dll", CharSet=CharSet.Unicode)]
        private static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string className, string title);
        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
        [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wParam, ref COPYDATASTRUCT data, uint flags, uint timeout, out IntPtr result);

        // Every Rainmeter control window on this desktop, as { window handle, process id }.
        public static List<long[]> ControlWindows() {
            var found = new List<long[]>();
            IntPtr window = IntPtr.Zero;
            while ((window = FindWindowEx(IntPtr.Zero, window, "DummyRainWClass", "Rainmeter control window")) != IntPtr.Zero) {
                uint processId;
                GetWindowThreadProcessId(window, out processId);
                found.Add(new long[] { window.ToInt64(), processId });
            }
            return found;
        }

        public static void Send(long window, string bang) {
            var data = new COPYDATASTRUCT();
            data.dwData = new IntPtr(1);
            data.cbData = (bang.Length + 1) * 2;
            data.lpData = Marshal.StringToHGlobalUni(bang);
            try {
                IntPtr result;
                // 0x004A WM_COPYDATA, 2 SMTO_ABORTIFHUNG
                if (SendMessageTimeout(new IntPtr(window), 0x004A, IntPtr.Zero, ref data, 2, 5000, out result) == IntPtr.Zero)
                    throw new Win32Exception(Marshal.GetLastWin32Error());
            } finally { Marshal.FreeHGlobal(data.lpData); }
        }
    }
}
'@
}

# The settings file an instance with this command line uses (Library\Rainmeter.cpp): the one named on the
# command line, otherwise Rainmeter.ini beside the executable (portable), otherwise the one in %APPDATA%.
function Get-ParallaxRainmeterIni {
    param(
        [Parameter(Mandatory)][string]$ExecutablePath,
        [AllowEmptyString()][string]$CommandLine = ''
    )
    $rest = ($CommandLine -replace '^\s*("[^"]*"|\S+)', '').Trim()
    # A bang or "[...]" on the command line is something to run, not a settings file.
    if ($rest -and $rest -notmatch '^[!\[]') {
        $ini = [Environment]::ExpandEnvironmentVariables($rest.Trim('"'))
        if ($ini.EndsWith('\') -or (Test-Path -LiteralPath $ini -PathType Container)) { $ini = Join-Path $ini 'Rainmeter.ini' }
        # A relative path depends on that process's working directory, which cannot be read: no guess.
        if (-not [IO.Path]::IsPathRooted($ini)) { return '' }
        return [IO.Path]::GetFullPath($ini)
    }
    $portable = Join-Path (Split-Path -Parent $ExecutablePath) 'Rainmeter.ini'
    if (Test-Path -LiteralPath $portable -PathType Leaf) { return [IO.Path]::GetFullPath($portable) }
    return [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'))
}

# Every running Rainmeter that can receive a bang. Path and Ini are empty when the process cannot be read
# (for instance one running as administrator, seen from a normal shell).
function Get-ParallaxRainmeterInstances {
    foreach ($window in [ParallaxBang.Native]::ControlWindows()) {
        $process = Get-CimInstance Win32_Process -Filter ('ProcessId={0}' -f $window[1]) -ErrorAction SilentlyContinue
        $path = ''; $ini = ''
        if ($process -and $process.ExecutablePath) {
            $path = [IO.Path]::GetFullPath($process.ExecutablePath)
            if ($process.CommandLine) { $ini = Get-ParallaxRainmeterIni $path $process.CommandLine }
        }
        [pscustomobject]@{ Window = $window[0]; ProcessId = $window[1]; Path = $path; Ini = $ini }
    }
}

# The one running instance of this executable with this settings file. Defaults: the installed Rainmeter and
# the settings it uses when started normally. Throws when there is none, or more than one.
function Get-ParallaxRainmeterTarget {
    param(
        [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
        [string]$IniPath
    )
    if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw "No bang sent: $RainmeterPath was not found." }
    $exe = (Get-Item -LiteralPath $RainmeterPath).FullName
    if (-not $IniPath) { $IniPath = Get-ParallaxRainmeterIni $exe }
    $ini = [IO.Path]::GetFullPath($IniPath)
    $all = @(Get-ParallaxRainmeterInstances)
    $match = @($all | Where-Object { $_.Path -eq $exe -and $_.Ini -eq $ini })
    if ($match.Count -eq 1) { return $match[0] }
    $seen = @($all | ForEach-Object {
        'pid {0}: {1}' -f $_.ProcessId, $(if ($_.Ini) { "$($_.Path) with $($_.Ini)" } else { 'cannot be read (running as administrator?)' })
    }) -join '; '
    if (-not $seen) { $seen = 'none' }
    throw "No bang sent: expected one Rainmeter running $exe with $ini, found $($match.Count). Running: $seen."
}

function Send-ParallaxBang {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Bang,
        [Parameter(ValueFromRemainingArguments)][AllowEmptyString()][string[]]$Arguments = @(),
        [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
        [string]$IniPath
    )
    if ($Bang -notmatch '^![A-Za-z]+$') { throw "No bang sent: not a bang name: $Bang" }
    $text = $Bang
    foreach ($argument in $Arguments) {
        if ($argument -match '["\r\n\0]') { throw "No bang sent: an argument of $Bang holds a quote or a line break." }
        $text += ' "' + $argument + '"'
    }
    $target = Get-ParallaxRainmeterTarget -RainmeterPath $RainmeterPath -IniPath $IniPath
    try { [ParallaxBang.Native]::Send($target.Window, $text) }
    catch { throw "$Bang was not delivered to Rainmeter pid $($target.ProcessId): $($_.Exception.Message)" }
}

Export-ModuleMember -Function Get-ParallaxRainmeterIni, Get-ParallaxRainmeterInstances, Get-ParallaxRainmeterTarget, Send-ParallaxBang
