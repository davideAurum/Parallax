# Welcome panel

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when the panel changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape/String/Image meters | Required; supplied by Rainmeter | Draws the list and handles clicks with no background process, timer or polling. |
| `Welcome.ini`, `Modules/Welcome/Welcome.lua`, `Modules/Welcome/Rows.inc` and shared Parallax includes | Bundled source; required | Component list, check state and geometry. Missing source is an incomplete installation. |
| Rainmeter's own settings file at `#SETTINGSPATH#Rainmeter.ini` | Required for check marks only; supplied by Rainmeter | Read only, on explicit events, to find which configs Rainmeter records as active. If it cannot be read the check marks clear, the status line says so, and the buttons still load. |
| `!ActivateConfig` / `!DeactivateConfig` | Required; supplied by Rainmeter | What the check boxes and buttons do. Rainmeter itself records the resulting active state. |
| `!Move`, `!SetVariable` and `!UpdateMeasure` to another config, `#CURRENTCONFIGX/Y/WIDTH/HEIGHT#`, `IfCondition`, `#WORKAREA…@n#` | Required for [Arrange](#arrange) and Undo; supplied by Rainmeter | Each panel carries one idle measure, `MeasureParallaxPlace` in `Geometry.inc`. A panel that does not answer is left where it is. |
| `DefaultWindowX` / `DefaultWindowY` with formulas | Required; supplied by Rainmeter | Where each panel, this one included, [opens the first time](#where-panels-open-the-first-time). Loading a panel never moves it; only Arrange and Undo do. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Uses the suite font and typography. No system installation. |
| The eight utility configs and Global Settings | Bundled; listed, not required | A component missing from the installation cannot be loaded; Rainmeter reports the failed activation in its log and the row stays clear. |

The component loader needs no PowerShell helper, external plugin, network service, account or preference file of its own, and writes nothing to `@Resources/User/`. Since 2026-10-26 it has no update check: updates are in [Global Settings](SETTINGS.md#updates) ([UPDATES.md](UPDATES.md)).

## What it is for

`Parallax\Welcome\Welcome.ini` is the config the `.rmskin` loads after installation (`loadSkin` in [`packaging/release.json`](../packaging/release.json)). It answers the first question a new installation raises — what is in this suite, and how do I put the parts I want on the desktop — without sending the user to Manage Rainmeter.

It uses the shared two-column geometry, font, padding and rounding. Its logical panel height is 400 pixels: the default window is 456 × 408 pixels including the snapping gutter. (It was 424 while it carried the update row, until 2026-10-26.)

## The component list

One row per loadable component, each with a check box, a name and a one-line description:

| Row | Config | Skin file |
| --- | --- | --- |
| Chronometer | `Parallax\Chronometer` | `Chronometer.ini` |
| CPU | `Parallax\CPU` | `CPU.ini` |
| RAM | `Parallax\RAM` | `RAM.ini` |
| GPU | `Parallax\GPU` | `GPU.ini` |
| IO | `Parallax\IO` | `IO-Disk.ini` |
| Network | `Parallax\Network` | `Network.ini` |
| Media | `Parallax\Media` | `Media.ini` |
| Visualizer | `Parallax\Visualizer` | `Visualizer.ini` |
| Global Settings | `Parallax\Settings` | `Settings.ini` |

Global Settings sits below a divider because it is a configuration surface rather than a desktop instrument, but it behaves like any other row.

Companion configs are not listed. Each per-utility settings panel, `Parallax\CPU\Colors`, `Parallax\Media\Queue`, `Parallax\Media\Setup.ini`, `Parallax\Network\Connection`, `Parallax\Connections` and `Parallax\ColorPicker` are opened from the utility that owns them. The hidden input-idle coordinator `Parallax\Idle` is not a row either: skins that need it load it and it unloads itself (see [ARCHITECTURE.md](ARCHITECTURE.md#input-idle-coordinator)); it appears in Manage Rainmeter, and **Unload all** leaves it to unload itself.

## Behavior

Clicking a row's check box, name or description toggles that component: an unchecked row issues `!ActivateConfig` with the config and file above, and a checked row issues `!DeactivateConfig` for that config. Rainmeter remembers the resulting state across restarts, so the panel does not keep a preference of its own.

**Load all** activates every component in the list that is not already loaded, including Global Settings. **Unload all** deactivates every component the list reports as loaded; the Welcome panel itself is never in the list and stays open. The **X** in the title row closes only the panel.

**Arrange** moves every loaded panel to its place and **Undo**, which appears after it, puts them back ([below](#arrange)).

The status line reports how many of the nine components are loaded. A loaded row's name uses the body text color and an unloaded row's name uses the muted color, so the list reads at a glance without inspecting each box.

## Where panels open the first time

Since 2026-11-25 a panel that Rainmeter has never loaded opens in its own place instead of at 0,0. The places come from one layout in `Geometry.inc` through each panel's `DefaultWindowX/Y` ([ARCHITECTURE.md](ARCHITECTURE.md#first-placement)), so they also apply to panels loaded from Manage Rainmeter or from a gear.

The layout fills columns from the top right of the primary screen's work area. On a 1920 × 1080 screen at 100% with Windows 11's taskbar (a 1920 × 1032 work area), at the default size and with the shipped options:

| Left edge | Width | Panels, with their top edges |
| --- | --- | --- |
| 1692 | 1 column | CPU (0). It grows with the processor: 366 px plus 16 per thread. |
| 1464 | 1 column | GPU (0), IO (494), Chronometer (654) |
| 1236 | 1 column | Network (0), RAM (312) |
| 780 | 2 columns | Visualizer (0), Media (154), Welcome (340) |
| 324 | 2 columns | Global Settings (0), 1005 px tall, or the work area's height where that is less |

Edges include the gutter, so the painted panels are 8 px apart and line up with Rainmeter's snapping. Welcome, alone on the screen after an install, is near the middle. The left 324 px stay free. Each utility's settings panel, Thread colors and the separate Spotify queue open from the top left, each one a step lower and further right than the one before.

If the work area is too short for GPU, IO and Chronometer in one column, IO goes under Media instead.

Since 0.1.0-alpha.18 the place under GPU Meter leaves 24 px for the second-GPU line it shows by default on a computer with two GPUs. No panel can know that count at first load, so with one GPU a 24 px gap (at scale 1) stays above Disk Meter. [Arrange](#arrange) closes it.

### What fits

| Work area at the default size | Result |
| --- | --- |
| 1596 × 814 or larger | All ten panels apart. Under 1005 px tall Global Settings ends at the bottom of the work area and [scrolls](UTILITY-SETTINGS.md#tall-panels); until 2026-11-25 it ran past it. |
| 1140 × 814 or larger | The eight utilities and Welcome apart. Under 1596 px wide Global Settings overlaps Visualizer, Media and Welcome (by 60 px at 1536, completely at 1140). |
| 1140 × 654 or larger | The eight utilities apart. Welcome overlaps Media and IO, and Global Settings overlaps Visualizer, Media, IO and Welcome. |
| Smaller | Utilities overlap too |

The numbers grow with the suite scale: 1140 × 654 is 1710 × 981 at 150%. The column width changes the widths. Rainmeter is not DPI aware, so Windows scaling divides the screen first: a 1920 × 1080 screen is a 1536 × 816 work area at 125% and 1280 × 672 at 150%. A processor with more threads than fit (41 in a 1032 px work area, 19 in 672) makes CPU run past the bottom.

### Limits

- **Only the first load.** A panel with a section in Rainmeter.ini keeps its recorded position, and changing the scale, width or options later rearranges nothing. An upgrade moves nothing either: on a computer with two GPUs, GPU Meter's second-GPU line (new in 0.1.0-alpha.18) reaches 24 px over a panel that sits directly under it until that panel is moved or Arrange is clicked.
- **Second GPU: Rows** and **Rows + history** are 32 px taller than the room left, so on a new install they cover the top of Disk Meter by that much.
- **0,0 left by an older version stays** until [Arrange](#arrange). Until now Rainmeter recorded 0,0 on a first load. That cannot be told apart from a panel someone dragged to exactly 0,0, so both stay where they are. A panel dragged to exactly 0,0 from now on also stays there.
- **It does not look at the desktop.** A panel can open over one you placed there, another suite's skin, or Rainmeter's own starter skins (illustro), which sit where CPU opens. The [update prompt](UPDATES.md#the-update-prompt) opens over the top of the CPU panel's place.
- **Shipped options.** A panel saved larger than it ships (two columns, more drives, timers, an open queue or spectrum drawer) can reach into its neighbor.
- **The primary screen only.** A portrait or other screen under 1140 px wide overlaps.

## Arrange

Added on 2026-11-25, because a panel keeps its saved place and a copy that was used before 0.1.0-alpha.16 can have all of them in the top left corner. It happened to the owner's laptop: nine of ten panels were at 0,0 after the update.

**Arrange** uses the same columns as the first placement, from the right, but packs them with the panels' real sizes, so a longer thread table, more drives or an open queue do not overlap the next panel. It moves the loaded components and Welcome itself, on the screen the middle of Welcome is on (the primary one if it is on none). It loads and unloads nothing, and leaves settings panels, Connections and the separate queue alone.

- A panel its column has no room for goes under the first column with room, else into a new column on the left. If there is none, it steps down from the top left, 30 px at a time, so its title stays visible, and the status line says how many overlap.
- A panel is as wide as it is now. A narrow one keeps to the right edge of a wide column.
- **Undo** puts back every panel Arrange moved that is still loaded. It is offered until it is used or Welcome is refreshed or closed; places from before that are not kept anywhere.
- It does not look at what else is on the desktop, and nothing is rearranged later when a panel grows.

No panel can read another one's size, so each answers for itself. `Geometry.inc` gives every panel the variable `ParallaxPlaceAsked=0` and the measure `MeasureParallaxPlace` (`UpdateDivider=-1`, so it does nothing by itself). Welcome sets the variable to the panel's number and updates the measure, whose `IfTrueAction` calls Welcome's `Placed(number, x, y, w, h)`; then it clears the variable the same way. Rainmeter runs the answer before the `!UpdateMeasure` returns, so Welcome has every size when it starts to move. Only configs that Rainmeter's settings file reports as loaded are asked: a bang to one that is not logs an error. If that file cannot be read, nothing moves.

## How loaded state is determined

Rainmeter records each config in its own settings file as `[<config>]` with `Active=<n>`, where `n` is the 1-based position of the loaded skin file among the `.ini` files in that config folder, and `0` when the config is not loaded. The controller reads that file through Rainmeter's built-in `#SETTINGSPATH#`, decoding the UTF-16LE encoding Rainmeter writes (a UTF-8 or ANSI profile is also accepted).

A row is checked only when its config's `Active` equals the position recorded for that row's skin file. Every config above ships a single `.ini` except Media, whose folder holds `Media.ini` then `Setup.ini`; loading `Setup.ini` records `Active=2` and correctly leaves the Media row clear. **Adding an alphabetically earlier `.ini` to any of these config folders changes its position and must be reflected in the `components` table in `Welcome.lua`.** `Run-WelcomeSmoke.ps1` fails if any listed file is no longer first in its folder.

Reads happen only on explicit events: when the skin loads, when a `!RefreshGroup Parallax` reaches it after a settings change, when the pointer enters the panel, and immediately after a click. The panel's own update rate is `-1`; it adds no timer, sampling or recurring work.

A click also paints its own intent immediately, so the box responds even though Rainmeter records the change asynchronously. That optimistic mark lasts one render — the next event shows the state Rainmeter actually recorded, so a failed activation cannot stay on screen as a false check.

If the settings file cannot be read, every check clears and the status line reads `Rainmeter settings are not readable; check marks show clicks only.` Toggling and **Load all** still activate configs in that state; **Unload all** deactivates nothing rather than logging an error for each config that may not be loaded.

## Updates moved to Global Settings (2026-10-26)

The panel used to end with **Check for updates**, a status line and **Install**/**Notes**. Welcome is the package's `loadSkin`, so it opens after an install, but once closed nothing reopens it (on the maintainer's desktop it was `Active=0`), so that button was out of reach. The row and its `MeasureUpdate`, `MeasureUpdateFeed` and `MeasureUpdateInstall` were removed, the panel returned to 400 px, and the updater now lives in Global Settings' [Updates](SETTINGS.md#updates) section, with a daily background check and an update prompt ([UPDATES.md](UPDATES.md)). The Global Settings row in this panel leads there. The two update validation records below are kept as history; the checker is now `@Resources/Update/Update.lua`, tested under `@Resources/Update/tests/`.

A capture through `tools\Preview-Parallax.ps1 -Modules Settings,Welcome,Update` on 2026-10-26 rendered this panel at 456 × 408 with the Load all row last and `1 of 9 components loaded.`, with zero log errors.

## Reopening the panel

Right-click Global Settings and choose **Open the Welcome panel**, or load `Parallax\Welcome\Welcome.ini` from Manage Rainmeter. Right-clicking the Welcome panel opens Global Settings.

## Validation report

`Skins\Parallax\@Resources\Modules\Welcome\tests\Run-WelcomeSmoke.ps1` stages the distributable sources and launches Rainmeter against a generated settings profile containing only `Parallax\Welcome`. The live Rainmeter installation, its settings and the desktop are never read or changed, and every skin the test activates is positioned offscreen inside the isolated instance.

The run on 2026-09-17 with Rainmeter 4.5.26.3894 on Windows 11 26200 recorded:

- `WelcomeSuite.lua`: 89 assertions, 0 failed, covering UTF-16LE and UTF-8 parsing, case and whitespace differences, inactive/absent/non-numeric entries, the Media skin-file position, unreadable settings, toggle direction, the one-render optimistic mark, unknown component names, Load all, Unload all, first-paint behavior and a missing settings path. Every bang the controller issued was checked against an allowlist; no variable write, file write or unexpected command occurred.
- Checking the CPU box changed Rainmeter's recorded state to `CPU:1`; clearing it returned `CPU:0`.
- **Load all** produced `Active=1` for all nine configs; **Unload all** returned all nine to `0`.
- No Rainmeter errors outside `Parallax\Media\Media.ini`. That profile deliberately omits the bundled WebNowPlaying plugin, because its host binds a fixed local port and a second copy terminates Rainmeter when the user's own Rainmeter already runs it; Media's player and cover-art measures therefore report the missing plugin. Those errors belong to Media's own checks.

A native capture through `tools\Preview-Parallax.ps1 -Modules Welcome` rendered a 456 × 408 window at scale 1 before the update row was added. A capture with CPU loaded and Media loaded through `Setup.ini` shows the CPU row checked, the Media row clear and `1 of 9 components loaded.`

Not established by these checks: visual quality at other scales and column widths, mixed-DPI behavior, upgrade behavior over an existing installation, Skin Installer's post-install load of this config, and behavior when a listed config is missing from the installation.

### First placement, 2026-11-25

`tests\Run-PlacementSmoke.ps1` runs the staged suite in an isolated Rainmeter twice: a profile with no Parallax section (Welcome activated by an outside `!ActivateConfig`, as Skin Installer does it, then the real Load all), and one with saved positions. It reads the windows Rainmeter created from Windows, not from the settings file, with an empty local data folder and click-through, nearly transparent windows. `-WorkArea 1920x1032` (the default) replaces the work-area variables in the staged copy and turns off Keep on screen there, so a larger screen can be checked on a smaller one; `-WorkArea native` uses the real screen unchanged.

Runs on the Surface laptop (Rainmeter 4.5.28.3936, Windows 11, 2400 × 1600 at 150%, so a real work area of 1600 × 1019; 8 threads). Before the change the same Load all put all ten panels at 0,0. After it:

| Work area | Scale, column width | Result |
| --- | --- | --- |
| 1600 × 1019, the real screen, Keep on screen on | 1, 220 | All ten apart |
| 1920 × 1032 | 1, 220; 1, 180; 0.75, 220 | All ten apart |
| 2560 × 1392 | 1.25, 220 | All ten apart |
| 3840 × 2112 | 2, 220; 1, 320 | All ten apart |
| 1920 × 1032 | 1.13, 220 | All ten apart; Global Settings ran past the bottom (it scrolls since the change below) |
| 1536 × 816 (1080p at 125%) | 1, 220 | Nine apart; Global Settings overlaps Visualizer, Media and Welcome by 60 px and ran past the bottom (it scrolls since the change below) |
| 1280 × 672 (1080p at 150%) and 1366 × 720 | 1, 220 | The eight utilities apart; Global Settings and Welcome overlap others |
| 1920 × 1032 | 1.5, 220 | The eight utilities apart; Global Settings and Welcome overlap others |

All but the first are simulated. At 1.25 and 0.75 the first version of the layout put Welcome 1 px into Media, whose height has two roundings; the table in `Geometry.inc` now repeats them. The runs at 1600 × 1019, at 1920 × 1032 with 0.75, 1 and 1.13 at width 220, and at 2560 × 1392 were made after that change; the others before it, at scales where it changes no number.

In every run the panels with saved positions (CPU at exactly 0,0, GPU at 300,200, Global Settings at 123,45, Welcome at 40,60) opened there and Rainmeter.ini kept those numbers; the other six opened at their first places; and after Unload all and Load all every panel of the fresh profile was where it had been.

The test was checked against a copy with two faults: RAM placed at Network's top, and CPU moving itself with `!Move` when it loads. It failed on both, with the RAM and Network overlap, CPU's overlap, CPU opening at 500,500 instead of its saved 0,0, and the rewritten position.

The ten panels that open from another one were loaded together in a fresh profile on the same screen (scratch script, not checked in): CPU settings at 0,0, then Media, Chronometer, GPU, Network, IO, Audio and RAM settings, Thread colors and the Spotify queue, each 30 px lower and further right, and Connections at its own 572,296, with no log errors. `Run-WelcomeSmoke.ps1` still passes (89 assertions, Load all and Unload all).

Rerun on 2026-11-25 after Global Settings began to end at the work area ([Tall panels](UTILITY-SETTINGS.md#tall-panels)); in a simulated run the test now replaces that panel's work area too. All ten apart at 1920 × 1032 (scale 1 and 1.13), on the real 1600 × 1019 and at 1596 × 790, where Global Settings is 790 px tall; at 1.13 it is 1032 instead of running past the bottom. At 1536 × 816 it is 816 px tall and overlaps the same three panels by 60 px; at 1280 × 672 it is 672 px tall, and it and Welcome overlap others as before. Saved positions and second loads held in all six runs, and so did the stacked profile's Arrange and Undo once the two changes were merged. At 1280 × 672 Arrange steps Global Settings down to 30,30 at its full 672 px, so its last 30 px are below the work area until the pointer enters it, when it ends there ([Tall panels](UTILITY-SETTINGS.md#tall-panels)).

Not established: a real 1920 × 1080 screen at 100% (the 1080p numbers above are simulated), several screens and mixed scaling, a taskbar on another edge, a real Skin Installer run (its source at 4.5.28.3936 activates the panel the way the test does), Rainmeter 4.5.26 itself (its source reads the same options the same way) and 5.x, a processor with more than 8 threads, more than one drive, and how the arrangement looks to someone new to it.

### Room for the second GPU, 2026-11-28

With the second-GPU line on by default, a first placement on a computer with two GPUs put Disk Meter 24 px under the bottom of GPU Meter. `PlaceGPUHeight` now includes that line. `Run-PlacementSmoke.ps1` passes on the hybrid laptop (Rainmeter 4.5.28.3936) at 1920 × 1032, 1596 × 814, 1536 × 816, 1140 × 814, 1140 × 654, 3840 × 2112 at scale 2 and the real screen, and with Second GPU Off at 1920 × 1032 and 1140 × 814. The work areas in the table above moved from 790 and 651 px tall accordingly; all but the real screen are simulated. A computer with one GPU was stood in for by Second GPU Off only.

### Arrange, 2026-11-25

Surface laptop, Rainmeter 4.5.28.3936. `Run-WelcomeSmoke.ps1` passes with 200 suite assertions, 12 of its 29 tests new: the laptop's real sizes, the shipped sizes (the places match the table above), a narrow panel in a wide column, a panel moved under another column, a screen without room, only loaded panels asked, a panel that does not answer, a second screen, Undo, an unloaded panel at Undo, and unreadable settings or screens.

`Run-PlacementSmoke.ps1` has a third profile with all ten panels saved at 0,0, Disk Meter 278 px tall instead of 160 and Visualizer one column wide. In the real Rainmeter, Arrange took them apart, Undo returned every one to 0,0, and after a second Arrange, Unload all and Load all they were where Arrange had put them. The fresh profile, whose places Rainmeter records as formulas, closes GPU: Arrange moved Disk Meter and Chronometer up, Undo put them back, and their new places survived a reload. It passes at 1600 × 1019 (the real screen, Keep on screen on), 1920 × 1032, and 3840 × 2112 at scale 2. At 1280 × 672 the stack came apart except Global Settings and Welcome, which stepped down from the top left. All but the first are simulated.

The panel was captured at scale 1, 0.75 (180 px columns) and 2; the buttons fit. Undo was not in a capture.

Not established: a click by hand, a real second screen, Welcome on a screen left of or above the primary one, a taskbar on another edge, Rainmeter 4.5.26 and 5.x, and the developer copy `ParallaxDev` (its rewrite covers both names used here; not run).

### Update check stalls at "Checking for updates...", fixed 2026-10-19 (historical)

Reported on 0.1.0-alpha.3: **Check for updates** took a very long time. The panel runs no skin update cycle (`Update=-1`), and a WebParser downloads only on its first measure update and then every `UpdateRate` updates. `Check()` enabled `MeasureUpdateFeed` and sent its `Update` command, but nothing updated the measure, so the request waited for an unrelated redraw of the skin. `Check()` now also sends `!UpdateMeasure MeasureUpdateFeed`, which starts the first download; the `Update` command still starts every later one.

The smoke below did not catch this because it switches Welcome to `Update=500` to drive its harness. A scratch timing harness (not checked in) ran the shipped `Update=-1` panel against the real GitHub feed in an isolated Rainmeter 4.5.26 instance: before the fix, no result within 90 s; after it, `up to date` in about 1 s, and with the installed version set to alpha.2, `0.1.0-alpha.3 is available.` on the first click and again on a second click 1.5 s later. `Run-UpdateSmoke.ps1` still passes (newer, equal and unreachable feeds). Not checked: the Install step against the real release and the live panel.

### Update check, 2026-09-23 (historical)

`Skins\Parallax\@Resources\Modules\Welcome\tests\Run-UpdateSmoke.ps1 -ExerciseInstall` stages the sources, replaces the feed address with local `file://` manifests, and runs the real `MeasureUpdateFeed` / `MeasureUpdate` / `MeasureUpdateInstall` chain in an isolated Rainmeter 4.5.26.3894 instance on Windows 11 26200:

- 26 offline assertions on version ordering (pre-releases, numeric identifiers, refused two-part and `+build` versions) and feed validation (future schema, other package, foreign host, mismatched asset, short checksum, embedded quote, spaces, foreign notes link, empty, 404 body, oversized).
- A newer feed produced `Parallax 99.0.0 is available.`, an equal feed `up to date`, and a missing feed `Could not reach the update server.` The WebParser connection error for the missing feed is the only log error, and it is expected.
- Install for the fake 99.0.0 launched the hidden helper through RunCommand, which received GitHub's 404 for the nonexistent asset and reported `Download failed. Nothing was installed.` Skin Installer was not opened. Two earlier runs got `The connection was closed unexpectedly` instead of the 404; the helper now retries once on transport errors (never on HTTP errors), and the rerun passed.

The helper's success path was checked outside Rainmeter with a test-only copy that accepts a `file://` source and records the hand-off instead of launching Skin Installer. The real `dist\Parallax_0.1.0-alpha.rmskin` verified and was handed off. A wrong checksum and a package with its RMSKIN trailer removed were both refused and deleted.

Unverified: a real end-to-end upgrade from a published release (none exists, and the repository is private), the offered-state visual layout with Install and Notes shown, the Notes link opening a browser, the Skin Installer hand-off through `#PROGRAMPATH#` on a portable installation, and proxies or TLS-inspecting networks.
