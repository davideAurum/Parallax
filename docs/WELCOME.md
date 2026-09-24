# Welcome panel

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when the panel changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape/String/Image meters | Required; supplied by Rainmeter | Draws the list and handles clicks with no background process, timer or polling. |
| `Welcome.ini`, `Modules/Welcome/Welcome.lua`, `Modules/Welcome/Rows.inc` and shared Parallax includes | Bundled source; required | Component list, check state and geometry. Missing source is an incomplete installation. |
| Rainmeter's own settings file at `#SETTINGSPATH#Rainmeter.ini` | Required for check marks only; supplied by Rainmeter | Read only, on explicit events, to find which configs Rainmeter records as active. If it cannot be read the check marks clear, the status line says so, and the buttons still load. |
| `!ActivateConfig` / `!DeactivateConfig` | Required; supplied by Rainmeter | The only writes the panel performs. Rainmeter itself records the resulting active state. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Uses the suite font and typography. No system installation. |
| `@Resources/Version.inc` and `Modules/Welcome/Update.lua` | Bundled source; required for the update check | Installed version, feed address and the check/offer logic. See [UPDATES.md](UPDATES.md). |
| Rainmeter's built-in WebParser measure and network access to `github.com` | Optional; supplied by Rainmeter / the user's connection | One request per **Check for updates** click. Offline or blocked: `Could not reach the update server.`, and nothing else changes. While `davideAurum/Parallax` is private, the feed is unreachable and the check reports `Update check failed.` |
| `@Resources/Scripts/UpdateInstall.ps1` via Rainmeter's bundled RunCommand plugin and Windows PowerShell 5.1 | Bundled helper; optional, used only by **Install** | One hidden, one-shot launch per Install click. Downloads the offered package to `%TEMP%\Parallax\Update`, verifies it and opens it in Skin Installer. If PowerShell is unavailable, the status line reports that the download failed and nothing is installed. |
| Rainmeter's `SkinInstaller.exe` (from `#PROGRAMPATH#`) or the `.rmskin` file association | Required for Install; supplied by Rainmeter | Performs the actual upgrade after the user confirms. |
| The eight utility configs and Global Settings | Bundled; listed, not required | A component missing from the installation cannot be loaded; Rainmeter reports the failed activation in its log and the row stays clear. |

The component loader needs no PowerShell helper, external plugin, network service, account or preference file of its own. Only the explicit update check touches the network, and only Install launches a helper. The panel writes nothing to `@Resources/User/`; the helper writes only its download under `%TEMP%\Parallax\Update`.

## What it is for

`Parallax\Welcome\Welcome.ini` is the config the `.rmskin` loads after installation (`loadSkin` in [`packaging/release.json`](../packaging/release.json)). It answers the first question a new installation raises — what is in this suite, and how do I put the parts I want on the desktop — without sending the user to Manage Rainmeter.

It uses the shared two-column geometry, font, padding and rounding. Its logical panel height is 424 pixels: the default window is 456 × 432 pixels including the snapping gutter. (It was 400 before the update row was added.)

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

Companion configs are not listed. Each per-utility settings panel, `Parallax\CPU\Colors`, `Parallax\Media\Queue`, `Parallax\Media\Setup.ini`, `Parallax\Network\Connection` and `Parallax\ColorPicker` are opened from the utility that owns them.

## Behavior

Clicking a row's check box, name or description toggles that component: an unchecked row issues `!ActivateConfig` with the config and file above, and a checked row issues `!DeactivateConfig` for that config. Rainmeter remembers the resulting state across restarts, so the panel does not keep a preference of its own.

**Load all** activates every component in the list that is not already loaded, including Global Settings. **Unload all** deactivates every component the list reports as loaded; the Welcome panel itself is never in the list and stays open. The **X** in the title row closes only the panel.

The status line reports how many of the nine components are loaded. A loaded row's name uses the body text color and an unloaded row's name uses the muted color, so the list reads at a glance without inspecting each box.

## How loaded state is determined

Rainmeter records each config in its own settings file as `[<config>]` with `Active=<n>`, where `n` is the 1-based position of the loaded skin file among the `.ini` files in that config folder, and `0` when the config is not loaded. The controller reads that file through Rainmeter's built-in `#SETTINGSPATH#`, decoding the UTF-16LE encoding Rainmeter writes (a UTF-8 or ANSI profile is also accepted).

A row is checked only when its config's `Active` equals the position recorded for that row's skin file. Every config above ships a single `.ini` except Media, whose folder holds `Media.ini` then `Setup.ini`; loading `Setup.ini` records `Active=2` and correctly leaves the Media row clear. **Adding an alphabetically earlier `.ini` to any of these config folders changes its position and must be reflected in the `components` table in `Welcome.lua`.** `Run-WelcomeSmoke.ps1` fails if any listed file is no longer first in its folder.

Reads happen only on explicit events: when the skin loads, when a `!RefreshGroup Parallax` reaches it after a settings change, when the pointer enters the panel, and immediately after a click. The panel's own update rate is `-1`; it adds no timer, sampling or recurring work.

A click also paints its own intent immediately, so the box responds even though Rainmeter records the change asynchronously. That optimistic mark lasts one render — the next event shows the state Rainmeter actually recorded, so a failed activation cannot stay on screen as a false check.

If the settings file cannot be read, every check clears and the status line reads `Rainmeter settings are not readable; check marks show clicks only.` Toggling and **Load all** still activate configs in that state; **Unload all** deactivates nothing rather than logging an error for each config that may not be loaded.

## Checking for updates

**Check for updates** sits at the right end of the Load all row. The bottom line shows the installed version from `@Resources/Version.inc`. A click makes one WebParser request for the release feed. If a newer version is published, the line reads `Parallax <v> is available.`, and **Install** and **Notes** appear beside it. Install downloads and verifies the package, then opens Rainmeter's Skin Installer, which asks for confirmation before changing anything. The status line keeps short text; its tooltip carries the full reason for any failure. The mechanism, feed format, release procedure and state table are in [UPDATES.md](UPDATES.md).

The update controls run in their own script measure (`MeasureUpdate`), so the loader's controller and its bang allowlist test are unchanged. `MeasureUpdateFeed` stays disabled until a click and is disabled again when the request finishes, so neither a skin load nor a refresh contacts the network.

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

### Update check, 2026-09-23

`Skins\Parallax\@Resources\Modules\Welcome\tests\Run-UpdateSmoke.ps1 -ExerciseInstall` stages the sources, replaces the feed address with local `file://` manifests, and runs the real `MeasureUpdateFeed` / `MeasureUpdate` / `MeasureUpdateInstall` chain in an isolated Rainmeter 4.5.26.3894 instance on Windows 11 26200:

- 26 offline assertions on version ordering (pre-releases, numeric identifiers, refused two-part and `+build` versions) and feed validation (future schema, other package, foreign host, mismatched asset, short checksum, embedded quote, spaces, foreign notes link, empty, 404 body, oversized).
- A newer feed produced `Parallax 99.0.0 is available.`, an equal feed `up to date`, and a missing feed `Could not reach the update server.` The WebParser connection error for the missing feed is the only log error, and it is expected.
- Install for the fake 99.0.0 launched the hidden helper through RunCommand, which received GitHub's 404 for the nonexistent asset and reported `Download failed. Nothing was installed.` Skin Installer was not opened. Two earlier runs got `The connection was closed unexpectedly` instead of the 404; the helper now retries once on transport errors (never on HTTP errors), and the rerun passed.

The helper's success path was checked outside Rainmeter with a test-only copy that accepts a `file://` source and records the hand-off instead of launching Skin Installer. The real `dist\Parallax_0.1.0-alpha.rmskin` verified and was handed off. A wrong checksum and a package with its RMSKIN trailer removed were both refused and deleted.

Unverified: a real end-to-end upgrade from a published release (none exists, and the repository is private), the offered-state visual layout with Install and Notes shown, the Notes link opening a browser, the Skin Installer hand-off through `#PROGRAMPATH#` on a portable installation, and proxies or TLS-inspecting networks.
