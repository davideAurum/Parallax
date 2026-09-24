# Parallax milestones

## Release roadmap

Parallax ships as public alphas first, then betas, then a 1.0 release. Every public build carries the Welcome update check ([UPDATES.md](UPDATES.md)), so each stage below can reach users who installed an earlier one. Versions follow the updater's ordering:

```text
0.1.0-alpha  <  0.1.0-alpha.2  <  …  <  0.2.0-beta.1  <  …  <  1.0.0-rc.1  <  1.0.0
```

Publish every one of them as a normal GitHub release marked **Latest**, not **Pre-release**. The update check reads only the Latest release; the version string already says alpha or beta. A stage is finished when every exit item is checked. Record the evidence in the relevant doc; an honest "unverified" is allowed only where a stage says so.

### Stage 0: Go public (now)

Goal: the repository and the first package are public, and the update check has something to read.

- [ ] Commit the update check, the MIT license and the pending Media/IO/RAM/Settings work.
- [ ] Repair `tools/tests/Test-PackagingTools.ps1`. It fails at the Settings-only fixture on clean `main`, so none of its packaging assertions run. Add fixtures for the `Version.inc` check, the update feed and the `UpdateInstall.ps1` exception.
- [ ] Review the 7-commit history once more, then make `davideAurum/Parallax` public.
- [ ] Build `0.1.0-alpha` with `Package-Parallax.ps1`. Install it into a **disposable** Rainmeter profile and confirm that the Welcome panel loads, Load all works, and the log shows no Parallax errors.
- [ ] Publish release `v0.1.0-alpha` with the package, `.sha256` and `parallax-update.json`, marked Latest. From the installed copy, **Check for updates** must report `up to date`.

Allowed to remain unverified: everything in Stage 1 onward. State in the release notes that this is an alpha for early testers.

### Stage 1: Prove the upgrade path (`0.1.0-alpha.2`)

Goal: an installed copy upgrades itself through the Welcome panel without losing settings. Every later stage depends on this, so it comes before feature work.

- [ ] Starting from the Stage 0 install in the disposable profile, change settings in Global Settings and in at least three utilities (including an empty value and a countdown).
- [ ] Publish `0.1.0-alpha.2`. Check for updates, then Install, then Skin Installer, then confirm. Verify that the new version loads, every changed `@Resources/User/*.inc` value survives, and new defaults appear where no value was set.
- [ ] Verify the offered-state layout (Install and Notes visible), the Notes link, and a declined Skin Installer (cancel leaves the old version intact).
- [ ] Exercise the retired `Parallax\IO\IO.ini` upgrade gate from [PACKAGING.md](PACKAGING.md#release-gates).
- [ ] Try the updater on a portable Rainmeter install (Skin Installer located through `#PROGRAMPATH#`).
- [ ] Withdraw a release: mark alpha.2's predecessor Latest again, then confirm the check stops offering alpha.2.

### Stage 2: Alpha hardening (`0.1.0-alpha.N`)

Goal: close the known gaps the module docs list as unverified, one alpha at a time. Publish small alphas as items land.

- [ ] **Physical interaction pass.** Real pointer and keyboard input on every settings panel, the numeric editors, the color picker, the Chronometer event editor and the Media controls. Most of this has only been exercised through harnesses.
- [ ] **Display pass.** Mixed-monitor DPI, drag snapping and desktop alignment at every preset scale, and long labels and values at both widths.
- [ ] **Environment pass.** Non-ASCII user and temp paths, which RAM, GPU and Media helpers all note as unverified. Also a standard, non-admin Windows account.
- [ ] **Provider pass.** Each optional provider absent, installed, disconnected and reconnected: WebNowPlaying and its browser extension, the Spotify queue (auth expiry, API errors), HWiNFO exports, and a WLAN adapter for Network. Missing states must stay honest.
- [ ] **Hardware breadth.** At least one non-NVIDIA GPU, and a machine with more or fewer cores than the 12-thread reference.
- [ ] Triage issues reported by alpha testers; fix or defer each one explicitly.

### Stage 3: Beta (`0.2.0-beta.N`), feature freeze

Goal: no new features; performance and stability are measured, not assumed.

- [ ] Freeze features. The open customization items (ordering, graph ranges, warning thresholds, countdown list length) either land before the first beta or move to post-1.0.
- [ ] **Long-run performance.** Profile the default suite and the all-providers configuration for at least several hours: per-skin update duration, CPU fraction of one core, working set, and handle/thread growth. Compare against Rainmeter without Parallax on the same documented hardware. The current [PERFORMANCE.md](PERFORMANCE.md) samples are 5–10 seconds long and explicitly do not establish this.
- [ ] Set budgets from those measurements and tune defaults (Visualizer cadence, CPU per-thread history) to meet them.
- [ ] Soak test: 24+ hours loaded, including sleep/resume and a display change, with no leaks, orphaned helper processes or stuck providers.
- [ ] Run a full pre-release acceptance sweep (every scale, layout and module test suite), the broad validation that day-to-day work deliberately skips.

### Stage 4: Release candidate (`1.0.0-rc.N`)

Goal: the exact bytes that will ship as 1.0.0, minus the version number.

- [ ] Complete every item in the [PACKAGING.md release gates](PACKAGING.md#release-gates) against the rc package, including clean install and upgrade from the last beta.
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
- The customization items that Stage 3 deferred.
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
