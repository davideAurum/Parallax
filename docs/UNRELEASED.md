# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.10](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.10) (2026-10-27): Disk Meter's clickable drive names, load gauge with two-figure rates, and eject button for removable and optical drives (see [IO.md](modules/IO.md#current-validation)); Media's shuffle and repeat toggles and clickable Spotify queue (see [Media.md](modules/Media.md#shuffle-repeat-and-clickable-queue-2026-10-27)). Tagged at `8cd0fbc`. Preparing it caught three problems, all fixed before release: `Eject.ps1` missing from the staging allowlist (`1eb3be8`), a dead queue Refresh in Media Setup (`97de882`), and the 5 px gap that Disk Meter's old saved `PanelHeight=157` left on upgraded copies (renamed to `IOMinPanelHeight=0`, `8cd0fbc`). Package SHA-256 `faf33882f7475a42fc3bb6e5dd3bf9d3d49d29149aabf4d8448369e4b7ff0545`, 977,572 bytes; the live feed served alpha.10 and the downloaded asset matched it right after publishing. Installed on the maintainer's desktop 2026-10-27 at 07:26 through Global Settings ▸ Updates, the first real install through that path. The download matched the SHA-256. 251 of the 254 installed files match the package; the other three are the update state and the kept `User\GPU.inc` and `User\IO.inc`. All 176 saved values from alpha.9 survived. `PanelHeight=157` was dropped for `IOMinPanelHeight=0`, and the C+D overlay Disk Meter now measures its fitted 228x241. Still unverified: a real Spotify skip or Premium/device failure, live WebNowPlaying shuffle/repeat support, disk load against Task Manager under sustained transfers, write-rate fit at 180 / 0.75 scale. Previous: [0.1.0-alpha.9](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.9).

## On main, not in any release

- Disk Meter's shipped drive selection is `C` again. It had shipped `C,D,G`, the maintainer's own drive letters, since 2026-09-13 ([IO.md](modules/IO.md#current-validation)). Only fresh installs change, because upgrades keep their saved selection.
- **Developer mode** (2026-10-28, not yet installed anywhere): Global Settings > Developer creates a second copy of the suite, `ParallaxDev`, that loads beside the release; each of its utilities shows a status icon after the title (red git-branch-plus when it differs from the release, green git-compare-arrows when it matches), and `tools\Sync-ParallaxDev.ps1 [-Watch]` mirrors the repository into it. Global Settings grows to 456 × 1005 (the new Developer section). Offline, isolated-native and geometry checks pass; the live installation, the first real creation (it refreshes Rainmeter once), multi-monitor placement and running two Media players are not exercised ([DEVMODE.md](DEVMODE.md#validation-record-2026-10-28-rainmeter-4528)).

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
