# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.13](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.13) (2026-10-28): the Developer panel progress bar (Dev mode on and off, Compare and Reset, with the step named in the status line) and the Visualizer's developer status icon, which had been painted over ([DEVMODE.md](DEVMODE.md)). Tagged at `d71d5f3`. Package SHA-256 `ed9fc5e52da6c37e13ef967abe0c2814fd812b502e9c9680f74db9fcc006505b`, 1,026,480 bytes (279 entries); `Test-ParallaxPackage` passed during the build, the live feed served alpha.13 right after publishing, and the downloaded asset matched the SHA-256. Not yet installed on the maintainer's desktop. Still unverified on a real install: the progress bar, and developer mode on more than one monitor. The previous release, [0.1.0-alpha.12](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.12) (Media icon alignment, tooling no longer turning every icon red, the stale-copy rebuild and Reset button), was published earlier the same day; the Visualizer icon fix was checked on the maintainer's live dev copy.

## On main, not in any release

Nothing yet. Everything on `main` is in alpha.13.

## Open: before 0.2.0-beta.1

Re-scoped on 2026-10-28: features are frozen, the customization items moved to after 1.0, and the soak, the `IO.ini` gate and the full sweep moved to the RC. Details and each item's "done when" are in [ROADMAP.md Stage 2](ROADMAP.md#stage-2-before-beta1-010-alphan). Where and how to announce the beta is in [LAUNCH.md](LAUNCH.md). None is ticked yet.

- [ ] Upgrades keep settings: a scripted change → upgrade → diff of `User/*.inc`, plus a cancelled Skin Installer leaving the old version intact. Upgrades alpha.2 → 4 → 5 → 6 worked on the maintainer's install, but values were never checked one by one.
- [ ] First run as a stranger, in a second, standard Windows account.
- [ ] Display check at 1080p and 100% scaling.
- [ ] Laptop, and institutional PC (portable Rainmeter, no admin rights, if IT rules allow it). Start the hardware table.
- [ ] Performance headline from a multi-hour run, put in the README.
- [ ] README rewritten for users. Developer material moves to `docs/DEVELOPMENT.md`.
- [ ] Issue templates and GitHub Discussions.
- [ ] Global Settings ▸ Developer reads as maintainer-only.
- [ ] Spotify queue labelled experimental (each user needs Premium), and a live row-click skip tested.
- [ ] `0.2.0-beta.1`: version bump, Known Issues in the release notes, published as Latest.

Still open from Stage 1, but not blocking the beta: the offered state (Install and Notes visible, Notes link), and withdrawing a release (mark the previous one Latest again, then confirm the check stops offering it).

## Open: known gaps and housekeeping

- Before alpha.5, Media's Source/Queue workers could outlive Rainmeter and block upgrades. Copies at alpha.4 or earlier still have this. alpha.5 and later fix it, but the first upgrade from an old copy may need Rainmeter quit and those `powershell.exe` workers ended by hand ([UPDATES.md](UPDATES.md#upgrading-past-running-media-helpers)).
- A Windows PowerShell helper that starts using `Get-FileHash` or a `Microsoft.PowerShell.Security` cmdlet needs the same `PSModulePath` reset as `UpdateInstall.ps1`.
- Three Global Settings test fixtures were stale before developer mode: `Test-ThemeDropdown.ps1`, `Test-SettingsFields.ps1` and `Test-SettingsRefresh.ps1` still expected the 758 px panel and did not stage `Version.inc`, `Update\*` or `Idle\Link.lua`, so none could run since the Idle pause and Updates sections. On 2026-10-28 their file lists and heights were brought up to date; the first two pass, and `Test-SettingsRefresh.ps1` (run it with `powershell.exe`, not PowerShell 7) now stops at "Scale burst: pixels changed outside MeterGeometry/MeterScaleInput (row 761)", a row inside the Updates section that its before/after capture comparison does not allow for. It predates the Developer section (which starts below that row) and is still open.
- The physical input, provider and wider hardware and display passes now belong to the beta itself ([ROADMAP.md Stage 3](ROADMAP.md#stage-3-beta-020-betan)).
