# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.10](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.10) (2026-10-27): Disk Meter's clickable drive names, load gauge with two-figure rates, and eject button for removable and optical drives (see [IO.md](modules/IO.md#current-validation)); Media's shuffle and repeat toggles and clickable Spotify queue (see [Media.md](modules/Media.md#shuffle-repeat-and-clickable-queue-2026-10-27)). Tagged at `8cd0fbc`. Preparing it caught three problems, all fixed before release: `Eject.ps1` missing from the staging allowlist (`1eb3be8`), a dead queue Refresh in Media Setup (`97de882`), and the 5 px gap that Disk Meter's old saved `PanelHeight=157` left on upgraded copies (renamed to `IOMinPanelHeight=0`, `8cd0fbc`). Package SHA-256 `faf33882f7475a42fc3bb6e5dd3bf9d3d49d29149aabf4d8448369e4b7ff0545`, 977,572 bytes; the live feed served alpha.10 and the downloaded asset matched it right after publishing. Not yet installed on the maintainer's desktop (alpha.9 is); updating to it is the first real upgrade through Global Settings ▸ Updates. Not verified before release: an install or upgrade of this package (including the `IOMinPanelHeight` migration), a real Spotify skip or Premium/device failure, live WebNowPlaying shuffle/repeat support, disk load against Task Manager under sustained transfers, write-rate fit at 180 / 0.75 scale. Previous: [0.1.0-alpha.9](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.9), installed on the maintainer's desktop.

## On main, not in any release

- Nothing yet.

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
- Stage 2 onward (physical input, display, environment, provider and hardware passes) is untouched; see [ROADMAP.md](ROADMAP.md).
