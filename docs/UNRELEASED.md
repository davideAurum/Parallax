# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.11](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.11) (2026-10-28): the redesigned Network Meter ([Network.md](modules/Network.md)), Disk Meter's per-drive colors and split-mode autoscale ([IO.md](modules/IO.md)), the rebuilt color picker ([COLOR-PICKER.md](COLOR-PICKER.md)), Disk Meter shipping with only `C` selected, and developer mode ([DEVMODE.md](DEVMODE.md)). Tagged at `972a90c`. Package SHA-256 `f7d0042c645bc3b51719488adf7e0c5731dabe61d9083e32902e8f2bb61dba2a`, 1,022,509 bytes (279 entries); `Test-ParallaxPackage` passed during the build, and the live feed served alpha.11 right after publishing. Not yet installed or exercised: nobody has installed this package, run the upgrade from alpha.10, or checked the new Network, Disk color and color picker behavior in the live skins.

## On main, not in any release

Nothing yet. Everything on `main` is in alpha.11.

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
