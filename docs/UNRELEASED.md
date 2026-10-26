# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.8](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.8) (2026-10-25): the performance review (phases A-C: paint on change, the waiting Media Source helper, shared GPU/RAM plumbing), default-off Idle pause, the spectrum drawer's capture lease, the auto-ranged Memory Meter History option, and the performance branch's GPU host recovery in place of alpha.7's. Not yet installed on the maintainer's desktop (alpha.7 is). Not verified before release: real keyboard/mouse idle, real WebNowPlaying playback on the new build, sleep/resume. Known open item: the Idle-pause helper-launch kill race (RAM/GPU host stranded ~15 s). Previous: [0.1.0-alpha.7](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.7), installed via the updater the same day.

## On main, not in any release

- **Updater moved to Global Settings, with a daily check and an update prompt** (2026-10-26, branch `claude/updater-global-settings`). Global Settings has an Updates section (installed and latest version, Auto check Daily/Off, Check now, Update, Notes); the loaded utilities check the release feed about once a day (on by default) and open a small `Parallax\Update` prompt for a newer release; the Welcome panel's update row is gone. Same feed and install helper. See [UPDATES.md](UPDATES.md). Not verified: a real upgrade through the new path (needs a release newer than the installed one), the live installation, mixed DPI.

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
