# Chronometer logic checks

Run `./Run-Tests.ps1` from PowerShell. Supply `-RainmeterPath` only when an existing Rainmeter installation is elsewhere. No dependency is installed.

Last verified on 2026-09-11, including the appearance revision 2 footer update: **38 checks passed, 0 failed**, using installed Rainmeter **4.5.26.3894** and **Lua 5.1**. The process exited normally through its own test skin, and the generated run directory was removed. Numeric snapshot roundtrips include values beyond 2038 and the largest supported generation boundary.

`Suite.lua` loads the actual module `Core.lua` and `Store.lua`, exercises countdown transitions and wall-clock semantics, validates untrusted snapshot input, and checks alternating snapshot recovery and failed writes. Disk fixtures include an actual read-only file; partial write, close, and verification failures use controlled `io.open` mocks restored after each check. It also loads the production `Chronometer.lua` adapter into separate Lua environments with a mocked Rainmeter skin and snapshot store to verify save cadence, 60-tick retry, refresh, offline expiry, duration edits, command guards, and inert label text.

The runner precreates a unique `.runtime/run-<guid>/` settings file, skin directory, data file, and test-only skin, then starts an isolated Rainmeter process with the sole quoted absolute INI path. Update checks are disabled. It sends quit from that test skin only; timeout cleanup terminates only the process object it started. It deletes its exact generated run directory after printing the report. No test snapshots, user paths, results, or generated executables should enter a distribution. An empty `.runtime` directory is harmless and can be omitted.

This isolation behavior was checked against the installed Rainmeter 4.5.26.3894 [initialization source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/Rainmeter.cpp): INI argument parsing, an instance mutex keyed by the full INI path, settings-derived logs/data, and the skin-directory fallback. The test measure follows the official [Script measure options](https://docs.rainmeter.net/manual/measures/script/).

These checks verify engine and snapshot behavior inside Rainmeter's Lua runtime and adapter behavior with mocked UI calls. They do not establish visual layout, rendered controls, actual UI reload/restart integration, or CPU/power performance of a loaded dashboard. Those require separate frontend checks.
