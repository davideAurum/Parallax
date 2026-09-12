# Native Parallax screenshots

`Preview-Parallax.ps1` creates actual Rainmeter window captures from an existing Rainmeter installation. It copies the whole suite into a unique build directory, then loads Settings, Chronometer, CPU, RAM, GPU, IO, Network, Media Setup, and Visualizer in a separate instance using its own absolute INI and existing Skins directory.

```powershell
.\tools\Preview-Parallax.ps1
.\tools\Preview-Parallax.ps1 -Modules Settings,CPU,RAM -Scale 0.75 -ColumnWidth 180
.\tools\Preview-Parallax.ps1 -Modules Settings,CPU,RAM -ColumnWidth 200 -Columns 2
.\tools\Preview-Parallax.ps1 -Modules Settings,ColorPicker
.\tools\Preview-Parallax.ps1 -Modules IO -IOVariant IO-Disk.ini
```

Default settings come from the staged source, currently a 200 logical-pixel column and IBM Plex Sans. `-Scale` accepts 0.75, 1, 1.25, 1.5, or 2; `-ColumnWidth` accepts 180, 200, 240, 280, or 320. Both change only staged global settings, and intentional module overrides retain their normal precedence. `-Columns 1` or `-Columns 2` explicitly changes each selected utility's staged User include. Settings always remains double width; the runner verifies the effective native Columns value. Omitting `-Columns` preserves source utility choices.

Bundled TTFs and their license files are copied by staging with the rest of the suite. They are loaded by Rainmeter from the isolated skin resources; the runner performs no system font installation. Native reports record the configured FontFace; visual inspection is still needed to verify typography.

`-IOVariant IO-Disk.ini` loads the disk-counter variant when IO is selected; the default is `IO.ini` with native capacity and counters off. The runner verifies the selected active file. Native bounds reporting recognizes `MeterBounds` and IO's `MeterIOBounds`, records the declared geometry variables, and captures the actual Windows window dimensions independently.

`-SettleSeconds` controls the brief initialization delay (4–30 seconds, default 8). History graphs initially have only that many samples. Capture while source edits are paused to obtain a coherent review snapshot.

The runner starts its instance hidden, places skins offscreen with normal alpha, and enumerates windows belonging only to the process it launched. It calls Windows `PrintWindow` on those Rainmeter window handles. It never captures the desktop, other processes, or the user's existing Rainmeter instance; it never sends command-line bangs. It terminates only its own process in `finally`, leaving files for review.

The output contains individual PNG files under `captures`, native per-config reports, `capture-report.json`, `preview-report.json`, and `Rainmeter.log`. Inspect the images directly. A color-count heuristic detects likely blank captures but cannot establish visual quality; rendering may vary across Windows/Rainmeter versions. The actual data and honest missing-provider states remain visible. Media defaults to the optional-provider setup variant and no provider is installed or connected. The spectrum may legitimately be quiet. ColorPicker is an optional preview selection, always double width like Settings; `-Columns` affects neither settings utility.

**Do not distribute a preview directory:** it contains test instrumentation, and its original stage manifest predates those additions and preview-only settings. Run the regular staging command again when preparing a release.

This is visual smoke evidence, not a performance benchmark, accuracy test, long history, mixed-DPI test, or proof of optional-provider support. The capture uses [Microsoft's PrintWindow API](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow); layered-window support must be confirmed from actual resulting pixels on the current host.
