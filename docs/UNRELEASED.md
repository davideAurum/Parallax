# Unreleased and outstanding

Where things stand between releases: what is on `main` but not yet in a published package, and what is still open. Update this file when work lands. When a release ships, move its "On main" entries into that release's notes and clear them here. Stage goals live in [ROADMAP.md](ROADMAP.md); this file is the short list.

**Latest release:** [0.1.0-alpha.9](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.9) (2026-10-26): the updater moved to Global Settings with a daily check and an update prompt, and three RAM PAGE / GPU host fixes (the Idle-pause launch kill race, the host a skin refresh left running, and the host a slow PowerShell start stranded; see [RAM.md](modules/RAM.md#idle-pause)). Package SHA-256 `4934bceff939a93a4d12aed892666460a7450dc815aa8828231ec36ffbacc0b2`; the live feed served alpha.9 and the downloaded asset matched it right after publishing. Installed on the maintainer's desktop by 2026-10-27 through alpha.8's Welcome panel button; the Global Settings path gets its first real upgrade with alpha.10. Not verified before release: an install or upgrade of this package, the updater's live installation and mixed DPI, a genuinely slow PowerShell start (the delays were staged), a refresh from the Settings window in a live session, real keyboard/mouse idle, real WebNowPlaying playback, sleep/resume. Previous: [0.1.0-alpha.8](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha.8).

## On main, not in any release

**Release candidate:** 0.1.0-alpha.10 is bumped (`9d0e75e`) and packaged from `8cd0fbc` (`dist\Parallax_0.1.0-alpha.10.rmskin`, 977,572 bytes, SHA-256 `faf33882f7475a42fc3bb6e5dd3bf9d3d49d29149aabf4d8448369e4b7ff0545`) with notes drafted in `dist\release-notes-0.1.0-alpha.10.md`; not published. Preparing it caught two gaps, both fixed: `Eject.ps1` was missing from the staging allowlist (`1eb3be8`), and Media Setup showed a dead queue Refresh (`97de882`). Disk Meter's saved height was also renamed so upgrades drop the old 157 (`8cd0fbc`).

- **Disk Meter drive rows are links** (2026-10-26). Clicking a drive's name opens its root folder. The letter is underlined, the whole name underlines on hover, and an unnamed C: reads Windows. See [IO.md](modules/IO.md#current-validation).
- **Disk Meter load gauge and two-figure rates** (2026-10-26). The "Capacity: free / total" heading is gone. Each drive's summary line is now a block: a gauge over its load percentage (100 minus `% Idle Time`), read over write, and free / total on the read line, all to two significant figures. An empty optical drive reads unavailable instead of 100% busy. The saved minimum is now `IOMinPanelHeight=0` (was `PanelHeight=157`), so upgrades drop the old value and the panel fits its drives; see [IO.md](modules/IO.md#current-validation). Not verified: load against Task Manager under sustained transfers, write-rate fit at 180 / 0.75 scale. A long read rate and a mixed-unit capacity clip there.
- **Disk Meter eject button** (2026-10-27). Removable and optical drives show an eject icon at the right end of the name row. A removable drive gets the taskbar's Safely Remove request; an optical drive opens its tray. When Windows refuses, the row reads "In use by <program>" or "Couldn't eject" briefly. Checked live by holding G: open ("G: In use by pwsh").
- **Media shuffle and repeat, and a clickable Spotify queue** (2026-10-27). Two transport toggles for WebNowPlaying shuffle and repeat are accent-filled when on, muted when the player doesn't report support, and hidden in the narrowest layouts. Clicking a queue row skips forward to it. This needs one fresh Spotify sign-in (a new scope), Premium and an active device; a failure shows as a short notice. See [Media.md](modules/Media.md#shuffle-repeat-and-clickable-queue-2026-10-27). Not verified: live WNP shuffle/repeat support, a real Spotify skip, the drawer's Refresh look in an expanded queue.

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
