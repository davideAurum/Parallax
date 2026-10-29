# Parallax milestones

## Release roadmap

Parallax ships as public alphas first, then betas, then a 1.0 release. Every public build carries the Welcome update check ([UPDATES.md](UPDATES.md)), so each stage below can reach users who installed an earlier one. Versions follow the updater's ordering:

```text
0.1.0-alpha  <  0.1.0-alpha.2  <  …  <  0.2.0-beta.1  <  …  <  1.0.0-rc.1  <  1.0.0
```

What is on `main` but not yet released, plus the short list of open items, is in [UNRELEASED.md](UNRELEASED.md). Where and how to announce the beta, how to measure interest, and what charging would involve are in [LAUNCH.md](LAUNCH.md).

Publish every one of them as a normal GitHub release marked **Latest**, not **Pre-release**. The update check reads only the Latest release; the version string already says alpha or beta. A stage is finished when every exit item is checked. Record the evidence in the relevant doc; an honest "unverified" is allowed only where a stage says so.

### Stage 0: Go public (now)

Goal: the repository and the first package are public, and the update check has something to read.

- [x] Commit the update check, the MIT license and the pending Media/IO/RAM/Settings work.
- [x] Repair `tools/tests/Test-PackagingTools.ps1`. It failed at the Settings-only fixture because Welcome had become a required component, so none of its packaging assertions ran. Add fixtures for the `Version.inc` check, the update feed and the `UpdateInstall.ps1` exception.
- [x] Review the 7-commit history once more, then make `davideAurum/Parallax` public.
- [x] Build `0.1.0-alpha` with `Package-Parallax.ps1`. Install it into a **disposable** Rainmeter profile and confirm that the Welcome panel loads, Load all works, and the log shows no Parallax errors.
- [x] Publish release `v0.1.0-alpha` with the package, `.sha256` and `parallax-update.json`, marked Latest. From the installed copy, **Check for updates** must report `up to date`.

Allowed to remain unverified: everything in Stage 1 onward. State in the release notes that this is an alpha for early testers.

**Done 2026-09-23.** [v0.1.0-alpha](https://github.com/davideAurum/Parallax/releases/tag/v0.1.0-alpha) was published from commit `b11643e`, marked Latest: package SHA-256 `80a62a945b09d5b7e0cf2ceb0f9fe8a79487aad4d6add2ca3594b031f070ef2c`, 848,295 bytes. The package's 198 skin files were extracted into an isolated Rainmeter 4.5.26.3894 profile with Welcome and all nine components active. All 10 configs loaded, and the only log errors were Media's, because WebNowPlaying is not installed in that profile. The installed copy's **Check for updates** then read the published feed and reported `Parallax 0.1.0-alpha is up to date.` A real install through Skin Installer was not run, because it always targets the live Rainmeter profile. The first real Skin Installer run belongs to Stage 1.

### Stage 1: Prove the upgrade path (`0.1.0-alpha.2`)

Goal: an installed copy upgrades itself through the Welcome panel without losing settings. Every later stage depends on this, so it comes before feature work.

- [ ] Starting from the Stage 0 install in the disposable profile, change settings in Global Settings and in at least three utilities (including an empty value and a countdown).
- [ ] Publish `0.1.0-alpha.2`. Check for updates, then Install, then Skin Installer, then confirm. Verify that the new version loads, every changed `@Resources/User/*.inc` value survives, and new defaults appear where no value was set.
- [ ] Verify the offered-state layout (Install and Notes visible), the Notes link, and a declined Skin Installer (cancel leaves the old version intact).
- [ ] Withdraw a release: mark alpha.2's predecessor Latest again, then confirm the check stops offering alpha.2.

Re-scoped 2026-10-28 (see Stage 2): the retired `Parallax\IO\IO.ini` upgrade gate moved to Stage 4, and the portable-Rainmeter updater test moved to the institutional-PC check in Stage 2 (or Stage 4 if that machine can't be used). The settings-preservation and cancel checks above are the first item before beta.1.

**Progress 2026-10-19 (no item complete yet).** alpha.3 to alpha.6 were published, all marked Latest. The maintainer's own install went alpha.2 → alpha.4 → alpha.5 → alpha.6 through real Skin Installer runs, and the last one ran start to finish from the Welcome panel (Check for updates, Install, confirm). Each new version loaded. Settings preservation was not checked value by value, so the second item stays open. Three upgrade bugs turned up and were fixed:

- Check for updates stalled because the WebParser was never started (alpha.4; [WELCOME.md](WELCOME.md)).
- Leftover Media provider workers blocked Skin Installer's folder move (alpha.5; [UPDATES.md](UPDATES.md#upgrading-past-running-media-helpers)).
- Install reported "Download failed" under a Rainmeter started from PowerShell 7 (alpha.6; [UPDATES.md](UPDATES.md#rainmeter-started-from-powershell-7)).

Clean install of the published alpha.6 package (SHA-256 `a10e925b…122a7`): its 211 skin files were extracted into an isolated Rainmeter 4.5.28 profile on Windows 11 26H2, with Welcome and all nine components active. All ten configs loaded. Check for updates read the live feed and reported `Parallax 0.1.0-alpha.6 is up to date.` After `!Quit`, no helper process from that profile was left running. The only log errors were Media's, because the WebNowPlaying plugin was deliberately not installed in that profile: 14 plugin-load errors, then the cover image failing to open `0.png` on every update (193 lines in ~30 s); fixed on main 2026-10-20, leaving only the 14 load errors ([Media.md](modules/Media.md#cover-without-the-wnp-plugin-2026-10-20)). Not covered: a real Skin Installer run into a clean profile (it always targets the live one), and the Notes, cancel, `IO.ini`, portable and withdraw items above.

### Stage 2: Before beta.1 (`0.1.0-alpha.N`)

Goal: a build a stranger can install and upgrade safely, with honest notes on what is unverified and a clear way to report problems. Publish small alphas as items land.

**Re-scoped 2026-10-28.** Features are frozen: the open customization items (ordering, graph ranges, warning thresholds, countdown list length) move to [After 1.0](#after-10), where beta users' requests can rank them. No one else has run Parallax yet, and the maintainer has three machines: the desktop (the 12-thread NVIDIA reference), a laptop, and an institutional PC without admin rights. So hardware breadth starts on those three and widens during the beta, rather than blocking it. A friend's install helps if it happens, but nothing waits on it. The 24-hour soak, the `IO.ini` gate and the full acceptance sweep moved to Stage 4. Launch venues and money questions are in [LAUNCH.md](LAUNCH.md).

- [ ] **Upgrades keep settings.** The settings-preservation and cancel items from Stage 1, as a scripted check: change values in Global Settings and three utilities (including an empty value and a countdown), build a candidate, upgrade through Skin Installer, and diff every `@Resources/User/*.inc`. *Done when* every changed value survives, new defaults appear where nothing was set, and a cancelled install leaves the old version working.
- [ ] **First run as a stranger.** A second, standard (non-admin) Windows account on the desktop, optionally with a non-ASCII name: install Rainmeter fresh, double-click the `.rmskin` and go through Welcome with no WebNowPlaying extension, HWiNFO or Spotify. This also covers the non-admin and non-ASCII-path environment checks that RAM, GPU and Media note as unverified. *Done when* every utility loads, every missing provider shows an honest state, the log has only documented errors, and getting from download to "all loaded" takes under two minutes without the docs.
- [ ] **Display check.** One desktop monitor temporarily at 1080p and 100% scaling: Welcome, Global Settings and every utility at the default scale, plus drag snapping. *Done when* screenshots at that setting look right.
- [ ] **Laptop and institutional PC.**
  - **Laptop:** a normal install, repeating the first-run check. It is likely the first non-NVIDIA (integrated or hybrid) GPU, a different thread count and a different screen scale.
  - **Institutional PC, no admin rights:** Rainmeter's installer has a portable option that writes only to a folder you own, such as Documents. That machine would cover the portable-Rainmeter updater test (Skin Installer located through `#PROGRAMPATH#`), the non-admin test and a locked-down environment. Locked-down matters: RAM, GPU and Media run hidden Windows PowerShell helpers, which managed PCs often restrict, and those utilities must then show an honest unavailable state rather than break or fill the log.
  - **Caveats for the institutional PC:** no admin rights is not permission, so first confirm that IT rules allow running your own portable apps. Application blocking may stop Rainmeter from starting at all, which is a result worth recording. No Spotify sign-in there.
  
  *Done when* each machine you could use has a row in the hardware table below, and every problem is either fixed or listed as a known issue.
- [ ] **Performance headline.** One multi-hour run of the default suite (`tools/Start-ParallaxOvernightTrace.ps1`, `tools/Benchmark-Parallax.ps1`), recording CPU % and memory on the named hardware. *Done when* the number is in the README. The several-hour all-providers profile, budgets and soak stay in Stages 3–4.
- [ ] **README for users.** Today's README is aimed at developers and is stale (it says Check for updates lives in Welcome; it moved to Global Settings on 2026-10-26). In order:
  - a screenshot and a short GIF
  - what's included
  - install in three steps
  - optional extras: the WebNowPlaying extension, HWiNFO exports, and the Spotify queue (your own Spotify developer app, plus Premium)
  - a "verified vs. not yet" list
  - privacy: no telemetry; the update check contacts GitHub about once a day and can be turned off; Spotify only after sign-in
  - how to report a bug, and a support link
  
  Developer material moves to `docs/DEVELOPMENT.md`.
- [ ] **Feedback channel.** Issue templates in `.github/`: a bug form asking for Windows and Rainmeter versions, GPU and CPU, monitor scaling, the utility and a Rainmeter log excerpt; and a feature-request form. Enable GitHub Discussions for questions. Optional: a "Report a problem" link in Global Settings.
- [ ] **Maintainer tools out of the way.** Global Settings ▸ Developer keeps working for the maintainer but reads as not for ordinary users, for example placed last and labelled "Contributors".
- [ ] **Spotify queue labelled experimental.** Spotify's 2026 Development Mode rules require each app's owner to have Premium and allow 5 users per app. Parallax has every user register their own app, so everyone who wants the queue needs their own Premium; the setup text must say so. The maintainer has Premium, so a live row-click skip (never run, see [Media](modules/Media.md#row-clicks-and-refresh-2026-10-27)) can be tested before beta.1.
- [ ] **Release mechanics.** Set `0.2.0-beta.1` in `packaging/release.json` and `Version.inc`, write release notes with a Known Issues section, and publish it marked Latest. Cadence: release freely while no one else is installing. Once download counts show strangers, move to about one release a week, with hotfixes only for real breakage, because every release prompts each installed copy within a day.

Not blocking beta.1: the stale `Test-SettingsRefresh.ps1` fixture ([UNRELEASED.md](UNRELEASED.md)) and developer mode across several monitors.

**Hardware table.** One row per machine. Beta reports add rows.

| Machine | GPU | Threads | Scaling | Result |
| --- | --- | --- | --- | --- |
| Maintainer desktop | NVIDIA | 12 | 4K at 150% (Rainmeter DPI-unaware) | Reference; daily use |
| Maintainer laptop | — | — | — | Not yet run |
| Institutional PC (no admin, portable) | — | — | — | Not yet run |

### Stage 3: Beta (`0.2.0-beta.N`)

Goal: no new features; other people's hardware finds the bugs, and performance and stability are measured, not assumed. How and where to announce each beta is in [LAUNCH.md](LAUNCH.md).

- [ ] **Triage once or twice a week.** Label each issue *confirmed*, *needs info*, *after 1.0* or *won't fix*, and batch fixes into the next `beta.N`.
- [ ] **Hardware breadth.** At least a few confirmed installs on non-NVIDIA GPUs, and machines with more or fewer than 12 threads, recorded in the Stage 2 hardware table.
- [ ] **Interaction and provider passes** on real use. Real pointer and keyboard input on every settings panel, the numeric editors, the color picker, the Chronometer event editor and the Media controls. Each optional provider installed, disconnected and reconnected: WebNowPlaying and its extension, the Spotify queue (auth expiry, API errors), HWiNFO exports, and a WLAN adapter for Network. Missing states must stay honest.
- [ ] **Display breadth.** Mixed-monitor DPI, drag snapping and desktop alignment at every preset scale, and long labels and values at both widths, from the maintainer's monitors and testers' reports.
- [ ] **Long-run performance.** Profile the default suite and the all-providers configuration for at least several hours: per-skin update duration, CPU fraction of one core, working set, and handle/thread growth. Compare against Rainmeter without Parallax on the same documented hardware. The current [PERFORMANCE.md](PERFORMANCE.md) samples are 5–10 seconds long and explicitly do not establish this.
- [ ] Set budgets from those measurements and tune defaults (Visualizer cadence, CPU per-thread history) to meet them.
- [ ] **Exit to RC** when no defect above cosmetic has been open for two weeks and testers have upgraded from `beta.N` to `beta.N+1` with no settings lost.

### Stage 4: Release candidate (`1.0.0-rc.N`)

Goal: the exact bytes that will ship as 1.0.0, minus the version number.

- [ ] Complete every item in the [PACKAGING.md release gates](PACKAGING.md#release-gates) against the rc package, including clean install and upgrade from the last beta.
- [ ] Soak test: 24+ hours loaded, including sleep/resume and a display change, with no leaks, orphaned helper processes or stuck providers (moved from Stage 3 on 2026-10-28).
- [ ] Exercise the retired `Parallax\IO\IO.ini` upgrade gate from [PACKAGING.md](PACKAGING.md#release-gates) (moved from Stage 1).
- [ ] The portable-Rainmeter updater test, if the Stage 2 institutional-PC check could not cover it.
- [ ] Run a full pre-release acceptance sweep (every scale, layout and module test suite), the broad validation that day-to-day work deliberately skips (moved from Stage 3).
- [ ] Review attribution and licenses: `NOTICE.txt`, the MIT `LICENSE`, the IBM Plex OFL, WebNowPlaying, and Lucide ISC/MIT, with no ModernGadgets code or assets.
- [ ] Refresh the README screenshots, install instructions and the dependency tables in [DEPENDENCIES.md](DEPENDENCIES.md).
- [ ] No open defects rated above cosmetic. An rc that needs a fix becomes `rc.N+1`, not a patch on top.

### Stage 5: 1.0.0

- [ ] Rebuild from the final rc commit with only the version changed, in both `release.json` and `Version.inc`.
- [ ] Publish `v1.0.0` marked Latest, with release notes covering everything since the last public beta.
- [ ] Confirm from an installed rc that **Check for updates** offers 1.0.0 and upgrades cleanly.

### After 1.0

Semantic versioning from here on: `1.0.x` for fixes, `1.x.0` for features, and `2.0.0` only if saved settings or config paths break. Candidate work:

- Updater: an opt-in check when Welcome opens, a Global Settings entry, a stable/beta channel, and a signed manifest ([UPDATES.md](UPDATES.md#possible-later-steps)).
- The customization items frozen out of the beta on 2026-10-28: ordering, graph ranges, warning thresholds and countdown list length. Beta users' requests decide the order.
- Multiple disks in Disk Meter; RAM cache and compressed-memory details; optional per-process network attribution, if the overhead justifies it.

## Feature history

The sections below record how the suite reached its current state.

### Foundation and initial instruments

Implemented: shared Default theme, scale/gutter geometry, independent utility configs, variable preservation, baseline native metrics, timer/event controls, optional-provider setup and validated source staging. Global Settings now includes two accents, title/header/body typography, rounding, background transparency and border/divider controls with a reusable color picker.

### Customization and integrations

Module settings now cover several visibility and layout choices, with dedicated settings utilities where implemented. Continue with ordering, graph ranges, warning thresholds and module launch controls. Extend countdown list lengths and dated-event behavior beyond the current slots. Expand real-hardware acceptance for sensor selection and device discovery.

Media includes optional WebNowPlaying controls and an authenticated Spotify queue provider. Initial live queue authorization and refresh passed; wider player/API failure cases and performance remain acceptance work. Network is independently loadable with connection information; process traffic attribution or connection tracing remains an opt-in extension only if overhead justifies it.

### Integration and distribution

Run every utility alone and together, check settings refresh without losing countdowns, reload persistence, missing sources, long strings, scaled snapping and mixed-DPI layouts. Record Rainmeter plus provider CPU/memory at idle, normal activity and visualizer load. Establish budgets from measurements on documented hardware, then tune defaults.

Build the `.rmskin` with `tools/Package-Parallax.ps1` (or the official Skin Packager) from a fresh stage, review dependencies and attribution, verify clean install and settings-preserving upgrades with that package, then publish a versioned artifact only after acceptance. A validated stage or a structurally verified package is useful development output but is not an installation test or a release-readiness claim.
