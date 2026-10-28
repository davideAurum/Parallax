# Developer mode

Added 2026-10-28. A testing iteration loop for the suite: a second copy of Parallax that loads **beside** the installed release, so a change can be edited and looked at next to the build it changes. Each utility in the copy carries a small status icon after its title that says whether it differs from the release.

| Icon | Meaning |
| --- | --- |
| Red **git-branch-plus** | This utility, or a file every utility shares, differs from the release. |
| Green **git-compare-arrows** | It matches the release. |
| Muted **git-compare-arrows** | Not compared yet, or the comparison could not run. Never a false green. |

The icons are the two user-selected [Lucide](https://lucide.dev) vectors, adapted to native Shapes ([provenance and licence](../Skins/Parallax/@Resources/Dev/Icons/Lucide/README.md)). They exist only in the copy: a release loads a comment-only include and carries no icon, script or measure for this.

## Dependencies

Inherits the [shared platform requirements](DEPENDENCIES.md#shared-requirements). Developer mode is a bundled, optional feature; nothing outside Windows and Rainmeter is needed.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape meters; `@Resources/Dev/DevStatus.lua`, `DevCommon.lua`, `Hook0.inc`, `Hook1.inc`, `Status.inc` | Required for the icons; bundled | Hook0 (every release) loads nothing. Hook1 (the copy only) adds one Script measure, one RunCommand measure and four meters, all `UpdateDivider=-1`. No timer, no polling. Missing files: Rainmeter logs the missing include and the utility runs without the icon. |
| Rainmeter standard RunCommand plugin; Windows PowerShell 5.1 (`@Resources/Dev/DevMode.ps1`, `DevCopy.psm1`) | Required for Dev mode, Compare and the icon click; host components, no package installation | One hidden, one-shot launch per explicit click. Reads and writes files below the Skins folder only (plus the Windows window list for placement). If PowerShell is blocked, the panel shows the failure and nothing is created. |
| `@Resources/Dev/DevPanel.lua`, `Panel.inc` and the Developer rows of `Settings/Settings.ini` | Bundled | Global Settings > Developer. Event driven. |
| `tools/Sync-ParallaxDev.ps1`, `tools/Stage-Parallax.ps1` | Repository tooling, not shipped | The edit-and-see loop from the repository (below). |
| Lucide `git-branch-plus` and `git-compare-arrows` SVGs and notice | Bundled attribution (ISC) | Retained for provenance; Rainmeter draws the native Shapes and does not load the SVGs. |

No network access, account, driver, helper download or system change. The copy is a plain skin folder; deleting it removes everything but the `DevMode` saved key.

## Using it from Global Settings

**Global Settings > Developer** (the last section above the footer, 96 px tall) has a **Dev mode** row (Off or On, the same cycling control as Idle pause: either arrow or the centre flips it), a status line, and **Report** and **Compare** buttons.

- **Turn on.** One hidden helper run creates `<Skins>\ParallaxDev` from the installed release (only if it does not exist), compares the two, and lists the release's loaded utilities. Rainmeter then loads the copy's matching utilities (the same `.ini` file each has loaded: Media Setup stays Setup) beside the release windows. The first time a copy is created Rainmeter must refresh its skin list, because it refuses to activate a folder created since it started (`!ActivateConfig: ... exists, but is not available. Please refresh Rainmeter.`). Global Settings therefore saves `DevMode=1`, sets `DevPending=1`, runs `!RefreshApp` **once** (every loaded skin reloads, as for *Refresh all*), and on its next load clears `DevPending` and resumes the load. Later turn-ons, and any start where the folder already exists, need no refresh.
- **Turn off.** Unloads the copy's utilities and saves `DevMode=0`. The copy's files stay, so edits survive; delete `ParallaxDev` yourself to start again (or use `Sync-ParallaxDev.ps1 -Action Reset`, which sets it aside rather than deleting it).
- **Compare.** One helper run re-compares and rewrites the status; every loaded dev utility is then told to re-read it (`Reload()`), so the icons update without reloading anything. **Report** opens the list of differing files in Notepad.
- **After a new release is installed.** The copy is a clone, so it stays at the release it was cloned from (`ParallaxDevBase` in its `User\Settings.inc`, written once and never touched by a sync). With Dev mode on, the status line reads `Out of date: from <version>` in `DangerColor`. **Turn on** compares that base with the installed `Version.inc` and, when they differ, rebuilds the copy first: the old one is moved to `@ParallaxDev-backup-<time>` (edits made directly in it are there), a fresh one is cloned and the status says so. A rebuild replaces a folder Rainmeter already lists, so it needs no refresh; only the first creation does.
- **Reset** (shown whenever a copy exists, beside **Report**) does the same rebuild on demand. With Dev mode on it unloads the copy's utilities, rebuilds, then reloads them; with it off it only rebuilds. The `@ParallaxDev-backup-<time>` folders are never deleted; remove them when you no longer need them. Rainmeter lists them as skins until you do.
- **Progress bar.** While Dev mode is turned on or off, Compare or Reset runs, a thin bar under the status line follows it and the status line names the step: `Building the copy 120/275`, `Comparing...`, `Finding utilities...`, `Loading 3/8`, `Unloading 3/8`. The helper writes `<phase>|<done>|<total>` to `%TEMP%\ParallaxDevProgress.txt` (the clone counts files; later phases are markers, not measurements), and the panel reads it on a 120 ms tick that reschedules itself only while the helper runs and stops with the action. Loading and unloading the utilities step through them one at a time, 220 ms apart, so each step moves the bar; "Loading 3/8" counts requests sent to Rainmeter, not windows confirmed drawn. One bar covers the whole action: for Dev mode on, the helper is the first 60% and loading the rest; off is 40% and 60%; Reset with Dev mode on is unload 20%, rebuild 60%, reload 20%. The first creation of a copy ends in a Rainmeter refresh, which reloads the panel, so its bar restarts for the load after it.
- **Inside the copy**, Global Settings is the copy's own panel: the heading reads *Developer copy*, the Dev mode row is hidden, and Compare and Report compare the copy against the release beside it. Compare, Report and the icon click work there.
- **Click an icon** to compare once and open the report. That is one hidden PowerShell launch per click; nothing runs between clicks.

The status line reads `No dev copy yet.`, `Not compared yet.`, `All match (14:35)`, `2 of 8 differ (14:35)` (utilities that differ, counting shared files for every utility), `Off. Last: ...` while Dev mode is off, or the reason an action failed (in `DangerColor`).

## What the copy is

- **A clone, not a link.** `<Skins>\ParallaxDev` holds every file of the release folder. The build is made beside a temporary `@ParallaxDevNew-<id>` folder (an isolated test on Rainmeter 4.5.28 showed that Rainmeter lists `@`-prefixed and hidden-attribute folders like any other, so neither hides anything; the name only keeps the temporary folder from being mistaken for the copy) and moved into place whole, so an interrupted run leaves no half-copied `ParallaxDev`. Junctions and symbolic links anywhere in either tree are refused.
- **It must tell itself apart from the release.** Rainmeter names a config by its folder, so every hard-coded `Parallax\<config>` reference in the copy's `.ini`, `.inc` and `.lua` files (`Parallax\Settings`, `Parallax\\ColorPicker` in Lua, `Parallax\Media\Settings`, and so on) is rewritten to `ParallaxDev\<config>`. Code that asks Rainmeter (`ROOTCONFIG`) needs no rewrite. Encodings and line endings are preserved, UTF-16LE files included. `Group=Parallax` and the group names (`ParallaxIdleHook`, `!RefreshGroup Parallax`) are left alone on purpose, so a suite-wide refresh from either build reloads both and the single input-idle truth reaches both.
- **Its settings are its own.** `@Resources\User\*.inc` is copied from the release once, so the copy looks the same, then never touched again. The copy's `User\Settings.inc` gets `ParallaxDevBuild=1` (which loads `Dev\Hook1.inc` instead of the empty `Hook0.inc`) and `UpdateCheck=0` (no second update prompt). Everything the skins write at run time (`Update\State.inc`, `Modules\Media\CaptureState.inc`, the status and report) is also its own.
- **`ParallaxDev` must be a developer copy.** A folder of that name without `ParallaxDevBuild=1` is refused (`Foreign`) and never written.

## What is compared

Both folders are walked and every file is classified:

| Class | Files | Effect |
| --- | --- | --- |
| Utility | `<Utility>\**` and `@Resources\Modules\<Utility>\**` for Chronometer, CPU, GPU, IO, Media, Network, RAM, Visualizer | Turns that utility's icon red. |
| Suite | `Settings\`, `ColorPicker\`, `Welcome\`, `Update\`, `Idle\` configs, `Modules\ColorPicker`, `Modules\Welcome`, `Scripts\Settings.lua`, `Scripts\UpdateInstall.ps1`, `Update\Install.inc` | Counted and reported; turns no utility red. |
| Shared | Everything else (`Defaults.inc`, `Styles.inc`, `Geometry.inc`, `Version.inc`, fonts, `Scripts\SettingsInput.ps1`, `Idle\`, `Update\` hooks, `Dev\Hook0.inc` and `Hook1.inc`) | Turns **every** utility red: a shared file changes how all of them look or run. |
| Ignored | `@Resources\User\**`, `Update\State.inc`, `Modules\Media\CaptureState.inc`, `Dev\Status.inc`, `Dev\Diff.txt` | Never compared, never overwritten by a sync. |
| Tooling | The rest of `Dev\` (`DevStatus.lua`, `DevPanel.lua`, `DevCommon.lua`, `DevMode.ps1`, `DevCopy.psm1`, `Panel.inc`, `Icons\`) | Never compared, so editing the icon code turns no utility red; a sync still mirrors it into the copy. |

The release side is rewritten the same way before it is hashed, so the rewrite itself never counts. Text files compare as SHA-256 of the decoded text with CRLF and LF treated alike (a BOM or encoding change is a difference); UTF-16 and binary files compare byte for byte. A file only in the copy is `A`, one only in the release `D`, otherwise `M`. A cross-utility dependency (Media's drawer reading Visualizer includes) is not tracked: the Visualizer's icon turns red for its own files only.

The result is written to the copy's `@Resources\Dev\Status.inc` (counts per utility, `Shared`, `Suite`, the time and the release version) and `Diff.txt` (the report). Both are read by the dev skins and ignored by the comparison. Compare takes about 3 to 5 seconds, mostly PowerShell start-up and hashing about 260 files twice.

## The icon

`DevStatus.lua` reads `Status.inc` once when the skin loads and again on `Reload()`; it shows one of the three icon meters. To sit **after the title text** it measures the title with a transparent probe meter (the title's typography, no width, so it sizes itself to the text), then places the icon at `title X + text width + TitleIconGap`, clamped inside the title's own width so it never covers the gear or a readout at the right. The title meter and, for Media, the measure that feeds its text are named by `ParallaxDevTitle` and `ParallaxDevTitleMeasure` in each entrypoint (`ParallaxDevModule` names the utility). Icons are 14 px (`TitleIconSize`) and scale with the suite.

Limits: the position is computed at load and on `Reload()`, so a Media title that changes with the player does not move the icon until the next refresh or compare; while Idle pause hides a title the icon stays where it was. No tooltips (the suite ships none): the report is the detail.

## The repository loop: `tools\Sync-ParallaxDev.ps1`

```powershell
.\tools\Sync-ParallaxDev.ps1            # stage the repo like a release, mirror it into the copy, compare, refresh the loaded dev utilities
.\tools\Sync-ParallaxDev.ps1 -Watch     # keep doing that a moment after any file under Skins\Parallax changes
.\tools\Sync-ParallaxDev.ps1 -Action Compare
.\tools\Sync-ParallaxDev.ps1 -Action Enable   # create and load the copy (what the Dev mode toggle does)
.\tools\Sync-ParallaxDev.ps1 -Action Disable
.\tools\Sync-ParallaxDev.ps1 -Action Reset    # set the copy aside as @ParallaxDev-backup-<time>, clone the release again, sync
.\tools\Sync-ParallaxDev.ps1 -NoRefresh       # write files and the comparison only; send Rainmeter nothing
```

Sync stages `Skins\Parallax` with `Stage-Parallax.ps1`, so the copy receives exactly the files a release would (the same exclusions: tests, QA, caches, private files, non-distributable extensions) and the first sync runs the full static validation (about 14 s); a failing validation stops before the copy is touched. `-Watch` stages with `-SkipValidation` (no validation and no manifest hashes: about 3 s), debounces 800 ms and ignores `tests`, `QA` and `.runtime` folders. Measured on this PC, an edit to a skin file reaches a refreshed copy about 8 s after the save (debounce, stage, mirror, compare). The sync **overwrites** the copy's managed files, so edits made directly in `ParallaxDev` are lost on the next sync (hand edits are for the no-repository flow: install a release, turn Dev mode on, edit the copy, Compare). `User` and runtime files are never overwritten. The skins folder defaults to `SkinPath` in Rainmeter's own `Rainmeter.ini`; `-SkinsPath` overrides it.

The refresh sends `Rainmeter.exe !Refresh "ParallaxDev\<utility>"` for each loaded dev utility (or `!ActivateConfig` / `!DeactivateConfig` / `!CommandMeasure ... Reload()` for the other actions) from the command line, which reaches whichever Rainmeter answers. Use `-NoRefresh` with any isolated test instance.

## Placement

When the toggle loads the copy, each utility is placed **beside** its release window: right, else left, else below, else above, at the first spot inside a monitor's work area that overlaps no Rainmeter window and no earlier copy; if none fits, Rainmeter's own default applies. The release windows are found by their title, which Rainmeter sets to the skin file's full path. The window list, monitor work areas and the `!Move` use the same DPI-unaware coordinates as Rainmeter on this suite's target setup (see the [DPI note](PERFORMANCE-REVIEW.md)); mixed-DPI multi-monitor placement is unverified.

## The helper protocol

`DevMode.ps1 -Action Enable|Disable|Compare|Sync|Reset -SkinsPath <Skins>. -Release Parallax [-SettingsPath <folder with Rainmeter.ini>] [-SourceRoot <tree>] [-NoPlace]` prints ASCII lines only:

```
RESULT|OK|<action>|<changed files>|<utilities that differ>|<detail>
RESULT|ERR|<code>|<message>            (exit code 1; codes: NoRelease, NoCopy, Foreign, Reparse, BadName, Exists, NoSource, Failed)
CONFIG|<config>|<ini file>|<x or ->|<y or ->
```

Enable and Reset list the release's loaded utilities to load beside it; Disable, Compare and Sync list the copy's own loaded configs. The skin side reads this as **data**: a `CONFIG` line is accepted only for one of the eight utilities inside the copy's own root config, with a plain `.ini` name and integer or `-` coordinates; anything else is dropped. A path containing a double quote is never built into a command line. Run from the copy, `-Release ParallaxDev` is read as the release `Parallax`.

## Cost

Nothing runs between clicks: no timer, no worker, no process. Loading the copy loads a second set of utilities, which costs what they cost (each helper and provider included), so turn Dev mode off when not testing. In a copy the extra work per utility is one Script measure, one RunCommand measure that never runs unless clicked, and four small meters that never repaint. Both builds share `Group=Parallax`, the input-idle coordinators and everything outside the skin folders: Media's WebNowPlaying listener and provider helpers, their `enabled.intent` files and mutexes, and the Windows audio device. Running two **Media** or **Visualizer** players at once is untested and may conflict (the earlier second-process preview could not run Media's player for this reason).

## Validation record (2026-10-28, Rainmeter 4.5.28)

- `tools/tests/Test-DevMode.ps1`: 126 assertions (including the rebuild after a release change, the kept backup, Reset and the progress file) against throwaway trees under `%TEMP%`: config-name rewrite (INI, doubled-backslash Lua, UTF-16LE, CRLF, near misses that must not change), file classification, CRLF/LF/BOM hashing, window placement geometry, clone/compare/Enable/Disable/Reset through the real CLI (utility, suite and shared changes, added and removed files, ignored state, loaded-config lists, refusals), and the Sync tool end to end (tests and private files stay out, a second sync changes nothing, the release folder is byte-identical afterwards). Static validation of the copy as a developer build: 0 errors, 0 warnings.
- `Skins/Parallax/@Resources/Dev/tests/run_dev_suite.py` (OBS LuaJIT, offline): 179 assertions on `DevCommon.lua`, `DevStatus.lua` and `DevPanel.lua` against a mock `SKIN` (states and the never-green rule, icon placement and clamping, click and report, helper output treated as data, the refresh-and-resume path, the copy's own panel, refused paths).
- `tools/tests/Test-DevModeNative.ps1` (isolated Rainmeter, its own INI, Skins folder and log; a test-only harness skin drives the real Settings buttons by trigger file, with no command-line bangs): Global Settings 456×1005 with the Developer section; Dev mode On created the copy, refreshed, and loaded the copy's CPU and RAM beside the release; `DevMode=1` and `ParallaxDevBuild=1` saved; after editing a CPU file and **Compare**, the CPU icon changed from green to red (one 14 px area, 54 red pixels) and RAM stayed green (0 changed pixels); a click on the CPU icon ran a comparison from inside the copy (the test then closes the Notepad window that opens with the report; `-SkipClick` skips this step); Dev mode Off unloaded the copy and kept its files; the release windows were untouched; 0 log errors (18 checks). Evidence: `build/devmode-native-7c2ce458/captures`. Inspected by eye: the 14 px icons are recognisable at 100%, the red icon sits right after the title text, and the Developer section matches the panel's grammar (the first capture clipped *Compare now* to *Compare n…*; the button now reads *Compare*).
- `Sync-ParallaxDev.ps1 -Watch` in a throwaway tree with `-NoRefresh`: the first sync ran, an edit to `RAM\RAM.ini` produced a second sync reporting 1 file and 1 utility red 7.8 s after the save, and creating a file under a `tests` folder triggered none.
- `test_settings_geometry.py` (120 combinations, with the new section), `test_idle_freeze_contract.py` (10 tests) and `Test-Settings.ps1` (2,801 assertions, 456×1005) pass; `Test-Parallax.ps1` passes for the release and `-Variable ParallaxDevBuild=1`.

**Not verified:** the live installation (nothing here touched it); first creation against the maintainer's real, populated Rainmeter (the one-time `!RefreshApp` reloads every skin there); placement on a real multi-monitor, mixed-DPI desktop (only the pure geometry and the window-title match were tested; native windows were offscreen); two Media or Visualizer players loaded at once; a copy created from an older release that lacks `@Resources\Dev` (the Sync tool adds the files, but Global Settings in that release has no Developer section, so use the tool); `-Watch` and the Sync tool's `!Refresh` against a running Rainmeter (only with `-NoRefresh`); performance of a loaded second set of utilities. Not run from Windows PowerShell started by PowerShell 7 with an inherited `PSModulePath`: Windows PowerShell then cannot find `Get-FileHash` (the same hazard `UpdateInstall.ps1` documents), which only affects launching the tool that way.
