# Isolated RAM native smoke check

Run from the repository root after shared styles and RAM edits are stable:

```powershell
& 'Skins/Parallax/@Resources/Modules/RAM/Tests/Test-RAMNative.ps1' -TimeoutSeconds 60
```

The script uses an existing Rainmeter executable. `-RainmeterPath` may select a different existing installation. `-PrepareOnly` creates the snapshots without launching anything.

Twenty RAM copies cover widths 180/200, Columns 1/2, and Scale 0.75/1/1.25/1.5/2. One isolated instance loads those copies offscreen with zero alpha, using its own absolute INI and existing SkinPath. Sources are read once, and only RAM, its Settings utility, required shared includes, and already bundled fonts are copied. Each case has isolated settings/apply groups and an initially inactive Settings config. Unit modes alternate; two-decimal values, long titles, border widths 0/1/4 and divider choices 0/4 are exercised. Ten cases use default fonts and ten use maximum title/header/body sizes 12/10/10 with distinct semantic colors. Actual native memory measures keep their normal cadence and values.

The first copy runs the real refresh-only hardware query. Eighteen copies use explicitly test-only numeric inventory fixtures covering known, mixed, partial, unknown and unavailable metadata. Their provider is replaced with a Calc measure in the copied source, so the matrix launches only one PowerShell query. The final copy leaves its provider unfinished to check the view's timeout fallback. `InfoModelTests.lua` additionally checks protocol validation, byte formatting, raw transfer rates, memory-type/form-factor mappings, unknown and inconsistent slot counts, and incomplete or overflowing capacities inside Rainmeter's Lua runtime. No fixture replaces live PhysicalMemory readings.

The test checks native skin/meter bounds, transparent gutters, PhysicalMemory ranges, unit/percent/history bindings, hardware field text and log errors. Double-column copies preserve `PanelHeight=170` and verify the content still fits. The actual gear action opens each dedicated Settings config; `SettingsNative.lua` exercises all five controls across configs, verifies saved keys and immediate installed-capacity formatting, checks utility-only geometry and the absence of telemetry measures, and closes/reopens the utility twice to verify persistence. The main meter checks hover/leave and uninterrupted history counting throughout. Transparent unconstrained String probes measure actual native font heights after rendering, including the visible GiB/MiB value, and compare them with allocated boxes. The test never sends command-line bangs and stops only its own process. It does not read or change live user configuration, install fonts/plugins, or capture the desktop.

Evidence remains under a unique `Tests/.runtime/ram-native-*` directory. This entire Tests subtree is excluded by the existing staging policy. Do not distribute its instrumented skins or runtime logs. Failed runs are retained for inspection; the test performs no recursive deletion.

Bounds, clipping options and natural font heights do not prove complete visual readability or horizontal text fit. Action execution does not prove physical pointer-event delivery. The real query may correctly settle to Unavailable where Windows denies inventory access; its state is recorded separately in `summary.json`. Settings reopen persistence is tested; full RAM unload/reload persistence, firmware accuracy, full-history rendering, performance, mixed Windows DPI and release readiness remain outside this smoke check. The coordinator performs actual window capture and visual inspection separately. A longer harness deadline accommodates many utility activations under concurrent test load and is not a performance result.

Rainmeter Lua APIs follow the [official Lua scripting documentation](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html).
