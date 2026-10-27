# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.9](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.9) (2026-10-26): the updater moved to Global Settings with a daily check and an update prompt, and three RAM PAGE / GPU host fixes (the Idle-pause launch kill race, the host a skin refresh left running, and the host a slow PowerShell start stranded; see [RAM.md](modules/RAM.md#idle-pause)). Package SHA-256 `4934bceff939a93a4d12aed892666460a7450dc815aa8828231ec36ffbacc0b2`; the live feed served alpha.9 and the downloaded asset matched it right after publishing. Not yet installed on the maintainer's desktop (alpha.8 is), so updating to it goes through alpha.8's Welcome panel button; the Global Settings path gets its first real upgrade at the next release. Not verified before release: an install or upgrade of this package, the updater's live installation and mixed DPI, a genuinely slow PowerShell start (the delays were staged), a refresh from the Settings window in a live session, real keyboard/mouse idle, real WebNowPlaying playback, sleep/resume. Previous: [0.1.0-alpha.8](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.8), installed on the maintainer's desktop.

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
