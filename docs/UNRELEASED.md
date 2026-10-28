# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.12](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.12) (2026-10-28): the developer-mode follow-ups: Media's status icon aligned with its title, developer tooling no longer turning every icon red, and a copy cloned from an earlier release rebuilt on the next turn-on with the old one kept as a backup, plus a **Reset** button ([DEVMODE.md](DEVMODE.md)). Tagged at `bd43103`. Package SHA-256 `e732509c505095103adb488fc39e4a0c4b1b748e585dc5fa3ecd5414ecfb668d`, 1,024,014 bytes (279 entries); `Test-ParallaxPackage` passed during the build, the live feed served alpha.12 right after publishing, and the downloaded asset matched the SHA-256. Not yet installed on the maintainer's desktop. Still unverified on a real install: the Reset button and the stale-copy rebuild, and developer mode on more than one monitor. The previous release, [0.1.0-alpha.11](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.11) (Network Meter redesign, per-drive Disk colors, the rebuilt color picker, developer mode), is installed and its changes were confirmed working in the live skins.

## On main, not in any release

- **Developer mode shows the Visualizer's icon** (2026-10-28, pushed in `8f821b5`): its meters came from an include after the dev hook and painted over the icon; the hook now sits last in `Visualizer.ini`. Checked on the maintainer's live dev copy.
- **Developer mode progress bar** (2026-10-28): a thin bar under the Developer status line follows Dev mode on and off, Compare and Reset, with the step named in the status line (`Building the copy 120/275`, `Loading 3/8`). The helper reports through `%TEMP%\ParallaxDevProgress.txt`; loading and unloading step through the utilities. The offline suites (218 Lua, 126 PowerShell) and the isolated native run (26 checks, including the bar being drawn during Reset) pass; not installed ([DEVMODE.md](DEVMODE.md)).

## Open: Stage 1 (prove the upgrade path)

None of these is ticked in [ROADMAP.md](ROADMAP.md) yet. Upgrades alpha.2 → 4 → 5 → 6 worked on the maintainer's install, but:

- [ ] Change settings (Global Settings plus three utilities, including an empty value and a countdown), upgrade, and check that each value survived.
- [ ] Offered state: Install and Notes visible, the Notes link opens, and cancelling Skin Installer leaves the old version intact.
- [ ] The retired `Parallax\IO\IO.ini` upgrade gate ([PACKAGING.md](PACKAGING.md#release-gates)).
- [ ] The updater on a portable Rainmeter install.
- [ ] Withdraw a release (mark the previous one Latest again) and confirm the check stops offering it.

## Open: known gaps and housekeeping

- Before alpha.5, Media's Source/Queue workers could outlive Rainmeter and block upgrades. Copies at alpha.4 or earlier still have this. alpha.5 and later fix it, but the first upgrade from an old copy may need Rainmeter quit and those `powershell.exe` workers ended by hand ([UPDATES.md](UPDATES.md#upgrading-past-running-media-helpers)).
- A Windows PowerShell helper that starts using `Get-FileHash` or a `Microsoft.PowerShell.Security` cmdlet needs the same `PSModulePath` reset as `UpdateInstall.ps1`.
- Three Global Settings test fixtures were stale before developer mode: `Test-ThemeDropdown.ps1`, `Test-SettingsFields.ps1` and `Test-SettingsRefresh.ps1` still expected the 758 px panel and did not stage `Version.inc`, `Update\*` or `Idle\Link.lua`, so none could run since the Idle pause and Updates sections. On 2026-10-28 their file lists and heights were brought up to date; the first two pass, and `Test-SettingsRefresh.ps1` (run it with `powershell.exe`, not PowerShell 7) now stops at "Scale burst: pixels changed outside MeterGeometry/MeterScaleInput (row 761)", a row inside the Updates section that its before/after capture comparison does not allow for. It predates the Developer section (which starts below that row) and is still open.
- Stage 2 onward (physical input, display, environment, provider and hardware passes) is untouched; see [ROADMAP.md](ROADMAP.md).
