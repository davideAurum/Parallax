# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.7](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.7) (2026-10-25): GPU driver host relaunch after standby, the tighter Media spectrum drawer, and no `0.png` log spam without WebNowPlaying. Installed on the maintainer's desktop the same day through the Welcome panel's updater (alpha.6 → 7; the live `Version.inc` reads `0.1.0-alpha.7`). Rainmeter logging was off, so no log was captured, and settings preservation was not checked item by item.

## On main, not in any release

- **Performance review, phases A-C** (branch `claude/parallax-performance-review-55c97a`, merged 2026-10-25). Media repaints only on change and its Source helper waits instead of polling; shared plumbing cuts GPU and RAM wakeups; a Title animation setting (20 fps / 10 fps / Off). Measured six live skins: 20.5 → 7.7% of a core. See [PERFORMANCE-REVIEW.md](PERFORMANCE-REVIEW.md).
- **Idle pause** (phase C2): a Global Settings row (Off / 5 / 10 / 30 min, default Off) that freezes every utility after that long without keyboard or mouse input and resumes on input, through a new hidden `Parallax\Idle` config. See [ARCHITECTURE.md](ARCHITECTURE.md#idle-stand-down) and [SETTINGS.md](SETTINGS.md#idle-pause).
- **Drawer capture lease** (phase C1): the open spectrum drawer releases audio capture after about 2 minutes of silence while you are away, shows "Capture paused", and resumes on input, playback or a click.
- **Memory Meter**: optional auto-ranged History and a 60 s page-file host lease window.
- **GPU host recovery**: the branch's retry (10/60/300 s, reset after 10 healthy minutes, stall detection) replaces the alpha.7 backoff ([GPU.md](modules/GPU.md)).
- Merged with alpha.7's drawer tightening: the title-row volume and the shorter device row now live in each capture variant (`DrawerCapture0/1/2.inc`).
- Not verified on the merged tree: real keyboard/mouse idle, real WebNowPlaying playback, sleep/resume, and a real release install. Known open item: the Idle-pause helper-launch kill race (RAM/GPU host stranded ~15 s).

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
