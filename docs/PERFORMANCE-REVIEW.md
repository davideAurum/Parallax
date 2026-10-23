# Performance review, step 1: burden, bottlenecks and fix design

Review date 2026-10-22, against commit 71bfcdc (0.1.0-alpha.6 plus the WebNowPlaying placeholder fix), Rainmeter 4.5.28.3936, Windows 11 on an i7-8700 (6 cores / 12 threads) with a GTX 1080 and UHD 630. **This step changed no skin code.** It added measurement tools only (see [Tooling](#tooling-added-in-this-step)). Step 2 (building the fixes) waits for the owner's review of this document.

CPU figures are **percent of one logical core** unless stated otherwise. 100% means one of the 12 hardware threads is fully busy; the whole machine is 1200%.

## Bottom line

1. **Parallax uses about 31% of a core continuously in a quiet state, plus most of audiodg's 11%.** The 31% splits into Rainmeter at 21.7%, of which 16% is its single drawing thread, and Parallax's PowerShell helpers at 9.6%. Measured live, read-only, after 19 hours of uptime; the cumulative counters agree.
2. **Media is the largest single cost.** It redraws its whole window 20 times a second in every state, including paused, silent and with the screen off. The 50 ms tick exists to animate a 14 px title icon while music plays. Media alone costs 9.9% of a core with the drawer collapsed and 15.0% with it open, in isolation and without its helper. Live, with its Source helper, it is about three quarters of Parallax's cost.
3. **Media's Source helper burns 7.6% of a core doing almost nothing.** It checks for a stop request 10 times a second. Each check re-validates a folder path with about 19 PowerShell file-system cmdlets. Every 2 s it also rebuilds its media-session adapter, then rewrites its snapshot with an ACL rewrite and a forced flush. The WebNowPlaying plugin already receives the same media-session events inside Rainmeter, without polling.
4. **The open spectrum drawer keeps the Windows audio engine running all night.** Rainmeter's AudioLevel plugin, as a workaround for a Windows bug, starts a *silent playback stream* next to its loopback capture and never stops it while the measure exists. audiodg.exe then processes audio about every 10 ms even in total silence: 11% of a core live. Disabling or pausing the measure does not release it; only unloading it does. **Confirmed live** (see [Live A/B](#live-ab-drawer-and-spotify-2026-10-22)):
   - With the drawer collapsed, audiodg was not running at all, even with Spotify open and paused.
   - Reopening the drawer started a new audiodg in the same second, which then averaged 9.8% of a core.
   - The drawer also costs about 3.5-4 points on Rainmeter's UI thread.
5. **Nothing in Parallax or in Rainmeter 4.5.28 stands down when you are away or the screen is off.** Every skin, helper, plugin worker and audio stream runs at full cadence 24/7. Rainmeter 4.5 has no occlusion or display-off handling. 5.0 RC1, released 2026-10-12, adds occlusion tracking, but that is not the installed version.
6. **CPU Meter redraws 2.5 times per tick instead of once.** Its Lua controller forces an extra meter pass and redraw from inside every update. 74 UsageMonitor measures, 62 of them disabled, re-register with the plugin every second because they carry `DynamicVariables=1`. When a re-registration lands while the plugin's worker is busy, it starts a new thread.
7. **Background plugin threads are the second-largest Rainmeter cost (about 10% of a core in the full suite).** UsageMonitor runs one fixed 1 Hz reader per Windows counter category (Process, Processor Information, GPU Engine, GPU Process Memory, LogicalDisk). Each tick reads the whole category; `Disabled=1` does not stop it and skin cadence does not slow it. The suite already shares these readers across skins, which is the one measured sharing gain (below).
8. **Rainmeter's GPU use comes from redraw frequency.** The live Rainmeter.ini has `HardwareAcceleration=1`, so each redraw is a Direct3D 11 submission on the NVIDIA card (24 driver threads, about 1.5% CPU), a GPU-to-CPU sync, and a DWM recomposition. Cutting redraws (findings 2, 5 and 6) cuts GPU work proportionally.
9. **Sharing already happens in one place, and it is measured.**
   - The full suite costs 2.1 points of a core *less* than its eight utilities run alone. All of that saving is the UsageMonitor Process reader that CPU and RAM share on plugin threads.
   - The shared .NET runtime saves 118 MB.
   - On the UI thread and in wakeups the suite is slightly *worse* than the sum of its parts (+0.56 points, +155/s), because every skin competes for one drawing thread.
   - The remaining sharing opportunities are audio capture, media-session observation, one idle signal and helper plumbing. Merging all helpers into one process would save memory more than CPU.
10. **Outside Parallax, the largest single cost was a paused, long-running Spotify session.** One of its renderer processes was using about 116% of a core. Closing it gave back more than all of Parallax costs. Fresh Spotify uses 1-3% with or without Spicetify. This is the likeliest main driver of the overnight fan when Spotify is left open. Parallax and the drawer's audio engine, about 40% of a core together, add to it.

## How this was measured

Three independent sources, each blind to the others' conclusions:

- **Live probe (read-only).** One `NtQuerySystemInformation` snapshot every 1-2 s gives CPU time, memory and per-thread context switches for every process, without opening a handle. That includes protected processes such as audiodg and dwm. Thread start addresses were mapped to DLLs to attribute Rainmeter's background threads. No bangs were sent, nothing was written to the live skin or profile, and no process was signalled.
- **Isolated benchmark.** [tools/Benchmark-Parallax.ps1](../tools/Benchmark-Parallax.ps1) stages the working tree. Per trial it cold-starts a private, off-screen Rainmeter with only the scenario's skins, waits for every skin to build, settles 15 s, then samples every second for 30 s. Scenarios: empty Rainmeter, a shell skin (shared includes only), each utility alone, the full suite, and the suite minus each utility. Each was run 3 times in interleaved rounds. A second run used a copy of the live preferences (drawer open, per-thread CPU history and so on).
- **Code review.** One reviewer per utility, plus shared panels, a cross-module sharing lens and an engine-semantics reviewer. The engine reviewer checked Rainmeter 4.5.28.3936 and plugin source on GitHub. Each reviewer's findings then went to an independent verifier instructed to refute them: 69 findings, 12 high, 15 medium, 42 low. Verdicts are in the [finding index](#appendix-finding-index).

Limits that matter for reading the numbers:

- Off-screen windows are still updated and drawn by Rainmeter, but DWM composition of on-screen windows is not represented. Live GPU and dwm costs are therefore only visible in the live probe.
- Isolated profiles keep Media's providers inert by design and lack WebNowPlaying, so **isolated Media numbers exclude the Source helper and WNP**. The live probe covers both.
- CPU time is tick-accounted (about 15.6 ms granularity per thread). Trial-to-trial spread is reported next to every median. A difference smaller than that spread is not claimed.
- The isolated benchmark ran while the live Rainmeter and this review session were also running. Per-process accounting is unaffected, but frequency scaling and contention add noise.

## Live quiet-state footprint

The owner's session on 2026-10-22, about 13:00, with Chronometer, CPU, GPU, Media (drawer open), Disk Meter and RAM loaded, nothing playing and the desk idle:

| Process / thread | CPU (% of one core) | Wakeups/s | Notes |
| --- | ---: | ---: | --- |
| Rainmeter UI thread (all skins update and draw here) | 15.9-16.5 | 440-500 | ~11% average over 19 h of uptime |
| Rainmeter .NET threads (`clr.dll`, 17) | 3.8 | 159 | UsageMonitor category readers and WebNowPlaying |
| NVIDIA D3D driver threads (24) | 1.5 | 152 | hardware-accelerated redraws |
| RunCommand reader thread | 0.3 | 104 | polls the resident GPU host with a 1 ms wait |
| **Rainmeter total** | **21.7** | **~910** | |
| Media Source helper (`SourceProvider.ps1`) | 7.6 | — | continuous: 4,856 CPU-seconds in 19 h |
| GPU telemetry host (`DriverTemp`) | 1.35 | — | restarted at 12:18; Rainmeter started the day before |
| Media Queue helper (30 s poll) | 0.1 | — | |
| **Parallax total** | **~31** | | |
| audiodg.exe | 11.1 | — | 6,059 CPU-seconds in 19 h; drawer capture open (see finding 4) |
| dwm.exe | 14.6-17.8 | — | shared with every app; the Parallax share is not separable live |
| HWiNFO64 | 0.5 | — | external sensor provider used by CPU/GPU sensors |

The RAM page-file host was not running at trace time. It was found neither among Rainmeter's children nor by command line, so the live PAGE row is probably showing a stale or unavailable state. That is a behaviour question, not a performance one; it is noted for the RAM module.

### Ten-minute quiet trace

`Trace-ParallaxLive.ps1`, 2026-10-22 14:06-14:16, 2 s intervals, read-only. The tracer's own cost was 1.3% mean.

| Measure (% of one core) | Mean | p95 | Max |
| --- | ---: | ---: | ---: |
| **Parallax total** | **28.1** | 40.5 | 50.9 |
| Rainmeter UI thread | 14.3 | 21.6 | 27.8 |
| Rainmeter other threads | 5.3 | 8.5 | 16.9 |
| Helpers total | 8.5 | 13.9 | 17.7 |
| └ Media Source | 7.1 | 12.3 | 16.2 |
| └ GPU host | 1.2 | 2.1 | 2.9 |
| └ Media Queue | 0.2 | 0.8 | 1.5 |
| Rainmeter wakeups/s (UI thread alone: 411) | 878 | 963 | 1,298 |
| audiodg | 8.0 | 12.8 | 15.4 |
| dwm (all apps) | 9.2 | 14.2 | 17.8 |
| Rainmeter GPU engine % (10 s samples) | 0.46 | 0.68 | 0.83 |

**Spikes.**
- 28 of 268 intervals were more than 10 points above the median.
- In those intervals the UI thread and the helpers rise together, to 20-28% and 12-18% respectively.
- The timing is irregular, spread across the minute with no fixed period. That is consistent with several unsynchronised 1-2 s timers (UsageMonitor readers, the Source helper's 2 s cycle, the GPU host's 2 s cycle) occasionally landing in the same interval, rather than one periodic job.
- No helper restarted during the trace.

**Other processes during the trace (whole machine 19.4% of all cores busy):**
- **Spotify.exe: 113% of a core on average across 8 processes.** That is more than Parallax, and more than one full core.
- Rainmeter 19%.
- This review session 11%.
- Razer AppEngine 7%.
- dwm 6%.
- audiodg 4%.
- Defender 1.7%.

If Spotify stays open overnight it is a fan suspect in its own right, independent of Parallax. The live A/B below isolates it.

### Live A/B: drawer and Spotify (2026-10-22)

The drawer was toggled with the same `!CommandMeasure MeasureMediaOptions "ToggleVisualizer()"` bang its tab sends, sent to the live Rainmeter with the owner's go-ahead. The owner had collapsed it at 19:19:11. Spotify was closed and relaunched by script, and every change was time-stamped. CPU is % of one core, except the whole-machine column (% of all cores). audiodg figures come from the trace's per-interval records and its process start time; the tracer then had a bug, since fixed, that lost audiodg when it restarted under a new process id.

| Phase (time) | Drawer | Spotify | Rainmeter UI thread | audiodg | Spotify CPU | Whole machine |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 19:06-19:16 | open | long-running session, paused | 16.2 | ~8-10 | 111.9 | 27.6 |
| 19:26-19:28 | collapsed | same session, paused | 12.2 | **not running** | 113.2 | 27.6 |
| 19:28-19:31 | collapsed | closed | 13.8 | **not running** | — | 18.1 |
| 19:31-19:34 | **reopened** | closed | 17.6 | **started 19:31:18** | — | 19.8 |
| 19:34-19:38 | open | fresh plain Spotify, paused | 16.4 | 9.8 (since start) | 1.0-2.9 | 19.1 |
| 19:42-19:50 | open | fresh Spotify **with Spicetify 2.46.2** re-applied, paused | 18.4 | 9.7 | 3.8 mean (1.0 at the end) | busy with other apps |

What this shows:
- **The drawer's capture is what keeps the Windows audio engine running.** Paused Spotify does not.
- **The long-running Spotify session had one renderer spinning at about 116% of a core** (1,140 wakeups/s, 496 MB). A fresh Spotify uses 1-3%, with or without Spicetify, so the runaway builds up over a session rather than coming from Spicetify itself.
- **Closing that session gave back about 114% of a core.** That is roughly four times Parallax's total.
- **What triggers the runaway is unknown.** An overnight trace with `-Watch Spotify.exe` (now the default) would show when it starts.

Spotify's own update on 2026-10-21 had removed Spicetify's patch. At the owner's request, `spicetify upgrade` (2.45.3 → 2.46.2) and `spicetify restore backup apply` re-applied it before the last phase.

## Relative burden by module

### Each utility alone (shipped defaults)

Isolated benchmark, median of 3 trials (min-max of the total in brackets). Empty Rainmeter costs 0.05% and 16 wakeups/s, and a skin with only the shared includes costs 0.10%, so the rows below are effectively each utility's own burden. Run `20261022T175750-default-baseline-standard`.

| Utility | Total CPU | UI thread | Plugin threads | Helpers | Peak second | Wakeups/s | Private MB (Rainmeter + helpers) | GPU % | Load ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Media (drawer collapsed) | **9.89** [8.06-10.96] | 6.86 | 3.03 | — | 32.2 | 398 | 16 + 0 | 0.67 | 543 |
| CPU | **7.04** [6.60-7.35] | 2.58 | 4.61 | — | 27.2 | 132 | 66 + 0 | 0.48 | 843 |
| Visualizer | **4.67** [4.13-4.86] | 3.63 | 0.94 | — | 15.4 | 284 | 12 + 0 | 0.33 | 472 |
| RAM | **3.66** [3.28-3.83] | 0.25 | 3.08 | 0.33 | 7.7 | 155 | 43 + 62 | 0.03 | 414 |
| GPU | **2.60** [2.53-2.94] | 0.50 | 0.65 | 1.31 | 9.3 | 169 | 46 + 80 | 0.05 | 442 |
| IO (Disk Meter) | **0.74** [0.50-0.80] | 0.55 | 0.20 | — | 4.6 | 46 | 43 + 0 | 0.03 | 476 |
| Network | **0.60** [0.55-0.65] | 0.60 | — | — | 3.1 | 98 | 12 + 0 | 0.03 | 444 |
| Chronometer | **0.15** [0.10-0.20] | 0.15 | — | — | 1.5 | 40 | 9 + 0 | 0.02 | 359 |

Reading it:
- **Media and Visualizer are UI-thread costs:** the 20 Hz repaint (T1).
- **CPU and RAM are mostly plugin threads:** UsageMonitor's whole-category readers (T4). RAM's 3.1% is almost entirely the Process reader behind its process table.
- **GPU's largest part is its resident helper (1.31%).**
- **The "peak second" column is the spike behaviour of symptom b.** Media and CPU each reach 27-32% of a core for single seconds.

### With the live preferences

The same benchmark with a copy of the owner's preferences: drawer open, per-thread CPU history, sensors enabled. Run `20261022T184717-live-baseline-live`.

| Scenario | Total CPU | UI thread | Plugin threads | Helpers | Peak second (p95) | Wakeups/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Media, drawer **open** | **15.00** [13.05-15.48] | 8.76 | 5.48 | — | 36.0 | 491 |
| CPU | 8.11 [7.32-8.16] | 2.39 | 5.52 | — | 18.6 | 150 |
| RAM | 3.70 [3.65-3.84] | 0.15 | 3.14 | 0.36 | 6.2 | 161 |
| GPU | 2.72 [2.65-3.27] | 0.55 | 1.04 | 1.13 | 7.4 | 176 |
| **The six live skins together** | **24.10** [22.14-24.87] | 12.13 | 9.68 | 1.54 | 39.7 | 1,065 |
| All eight | 30.17 [28.76-31.40] | 17.31 | 10.10 | 1.83 | 46.2 | 1,430 |

The isolated six-skin figure agrees with the live probe: 24.1%, against live Rainmeter 21.7% plus the GPU and Queue helpers at 1.45%. The live session additionally runs the Source helper (7.6%) and WebNowPlaying, which isolation excludes. Opening the drawer adds about 5 points to Media inside Rainmeter, plus audiodg's cost outside it.

**Where the owner's live ~31% goes, approximately:**

| Utility | Approximate share of the live ~31% | What it is made of |
| --- | ---: | --- |
| Media | ~23 (about three quarters) | ~15 in Rainmeter with the drawer open, 7.6 Source helper, plus WebNowPlaying |
| CPU | ~5-8 | CPU and RAM split the Process reader (see interaction) |
| RAM | ~1-4 | |
| GPU | ~2.7 | |
| IO | ~0.7 | |
| Chronometer | ~0.15 | |

These shares overlap where readers are shared, so they don't sum exactly.

### Together versus alone

Burden = scenario minus empty Rainmeter. Interaction = suite burden − sum of the eight solo burdens. "Reading" applies the step-3 rule: beyond the suite's trial spread or not.

| Metric | Suite burden | Sum of solo burdens | Interaction | Suite spread (±) | Reading |
| --- | ---: | ---: | ---: | ---: | --- |
| Total CPU (%) | 26.85 | 28.95 | **−2.10** | 0.75 | Sub-additive: sharing |
| UI thread (%) | 15.27 | 14.71 | **+0.56** | 0.30 | Super-additive: contention on the one drawing thread |
| Plugin threads (%) | 9.95 | 12.51 | **−2.56** | 0.59 | Sub-additive: CPU and RAM share one UsageMonitor Process reader |
| Helper processes (%) | 1.65 | 1.64 | +0.01 | 0.13 | Additive: helpers share nothing |
| Wakeups/s | 1,344 | 1,190 | **+155** | 70 | Super-additive |
| Rainmeter private memory (MB) | 88 | 206 | **−118** | 2 | Sub-additive: the .NET runtime that UsageMonitor loads (~35 MB) and the renderer are paid once |
| Helper private memory (MB) | 142 | 142 | 0 | 0.4 | Additive: one PowerShell host per module (62 + 80 MB) |
| GPU (%) | 1.64 | 1.64 | 0 | 0.15 | Additive |

Leave-one-out marginals ("what removing one utility from the full suite saves") agree on the UI thread: Media 6.3, Visualizer 4.0, CPU 2.0, GPU 1.3, Network 0.6, Chronometer 0.4. On total CPU the small modules' marginals sit inside the leave-one-out trial spread (up to ±3.8). Their solo figures are the reliable ones.

The plugin-thread marginals show the existing sharing directly. Removing CPU from the suite saves only 0.14% there and removing RAM saves nothing measurable, against 4.6% and 3.1% alone. Whichever one remains keeps the shared Process reader running.

## Your three symptoms, explained

**(a) "The most dynamic-appearing app on the desktop when quiet."** Literally true:
- Media repaints its whole window 20 times a second even when nothing on it changes.
- The 1 Hz skins repaint every second because Rainmeter 4.5 repaints a skin whenever *any* of its meters is due, with no check for whether anything changed.
- Chronometer shows three per-second tickers (clock, uptime, event countdown). Hiding seconds in its settings only affects the clock.

**(b) "Spikes CPU and GPU consistently even when quiet."** The steady part is findings 2, 3, 6 and 7. The *spikes* line up with:
- UsageMonitor's whole-category reads, which are unsynchronised 1 Hz timers on several threads. The isolated full suite peaks at 40% in single seconds against a 27% mean.
- CPU Meter's thread-creation bursts when its 74 re-registrations collide with those reads.
- Media's 20 Hz D3D submissions.
- Helper restarts, each a PowerShell start plus a C# compile, on any refresh. A Global Settings click refreshes every Parallax skin and restarts every helper.

The GPU figure is Rainmeter's own D3D11 rendering under `HardwareAcceleration=1`, plus DWM recomposing each changed layered window.

**(c) "Fan running with regular high-RPM spikes all night, screen off, PowerToys Awake on."** With Awake preventing sleep, nothing in Parallax or Rainmeter 4.5 knows the screen is off. Overnight that means:
- about 31% of a core (Parallax) plus about 11% (audiodg kept active by the drawer's capture) running continuously;
- about 1,000 Rainmeter wakeups a second;
- 20 Hz GPU submissions.

That keeps the CPU package out of its deep idle states. The periodic peaks above ride on that floor. Parallax is very likely a *contributor*. It is not proven to be the *only* cause: Windows maintenance, Defender and Search indexing also run overnight. Defender and Search appeared in this afternoon's spike attribution.

The largest single contributor found was outside Parallax. A long-running, paused Spotify session had a renderer process using about 116% of a core. Closing it gave back more than all of Parallax costs. A fresh Spotify session uses 1-3%. On nights when Spotify was left open in that state, it is likely the main fan driver. Parallax, together with the drawer's audio engine at about 40% of a core, sits on top of it. [tools/Trace-ParallaxLive.ps1](../tools/Trace-ParallaxLive.ps1) is built to settle this. It is a read-only overnight trace that records the Parallax share, audiodg, dwm, HWiNFO temperatures and GPU fan, and the top processes in every spike. HWiNFO currently exports no CPU or case fan speed, so CPU temperature is the available proxy.

## Findings by theme

Each theme combines findings from several reviewers. Severity is the verifier's corrected rating. IDs refer to the [finding index](#appendix-finding-index).

### T1. Redraw follows the clock, not the content (high)

*MEDIA-01, XMOD-03, ENGINE-01, MEDIA-03, MEDIA-04, MEDIA-06, VIS-02, VIS-03, CPU-01, XMOD-04, GPU-03/05/06, RAM-05, IO-01/02, SHARED-04, CHRONO-01.*

Rainmeter 4.5 decides to repaint a skin when any meter's update counter fires (`Skin::Update` → `Redraw` → `UpdateLayeredWindow`). It never checks whether a value changed, and hidden meters still count. In Media, 26 meters fire every 50 ms, so the full 456 px window repaints at 20 Hz in every state. Four of those meters also re-parse about 70 KB of pre-expanded geometry formulas each tick (the same mechanism as the 10-11 drawer incident). Two more fire no-op Lua calls 40 times a second. CPU Meter's controller adds a forced pass and redraw from inside `Update()`, giving about 2.5 repaints per tick. GPU's driver bridge adds about 0.5-1 more.

**Fix design.**
- **Media:** set `DefaultUpdateDivider=#MediaLegacyDivider#` so meters fall back to the 1 s provider cadence. Give `MeasureMediaPulse` an explicit divider of 1. Set static meters to `UpdateDivider=-1`. Drop `DynamicVariables` from geometry-only meters, and write the title icon's position as literals once per load (as `SpectrumPaths.lua` already does). Gate the spectrum mask's divider on capture state in `Capture.inc`'s transition actions (−1 in silence, restored with a forced update on signal). Owner choice for the pulse: keep 20 fps only while playing (recommended), 10 fps, or a setting.
- **CPU / GPU:** remove the periodic `!UpdateMeterGroup` + `!Redraw` from `CPU.lua` `Update`, `Sensors.lua` `render` and `Temperature.lua` `flush`, keeping explicit paints on event paths only. A shared Lua bridge (`set` with a previous-value cache, `paint` only from events) prevents regressions, with a `Test-Parallax` rule against `!Redraw` in periodic paths.
- **Suite:** an opt-in `StyleStatic` (`UpdateDivider=-1`) for titles, labels and buttons.

Owner-visible change: none intended. Media's text still updates on the 1 s provider cadence; hover and queue already redraw explicitly.

### T2. The audio engine is kept awake (high)

*VIS-01, MEDIA-05, XMOD-02, ENGINE-03, VIS-04.*

AudioLevel's `Port=Output` path, with `WINDOWS_BUG_WORKAROUND=1` in 4.5.28, starts a silent shared-mode playback stream before its loopback capture. It never refills or stops that stream until the measure is unloaded or the device errors. A started playback stream keeps the endpoint's engine running. Capture parents are per skin, so the Media drawer and the standalone Visualizer each hold one. Win7Audio does two full COM setup/teardown cycles every 250 ms for the read-only volume readout.

**Fix design.** The only supported off switch is unloading the measure, so gate the capture's *existence*, not its updates:
- After sustained silence (for example 2 min) plus input-idle (for example 5 min), or when no WebNowPlaying player reports Playing, refresh the host into a capture-free variant. It shows an honest "Capture paused" state and re-arms on input, playback or a click.
- The parked flag must persist across the refresh, as a runtime key, and must be cleared reliably.
- One-capture rule: when the standalone Visualizer is loaded, Media's drawer shows "Spectrum is shown in Audio Visualizer" instead of opening a second capture.
- Volume readout: one COM pair per second instead of eight.

Cost of the design: a refresh restarts Media's provider resume checks, so the lease must skip those launches (MEDIA-08), or each park/unpark costs up to four PowerShell cold starts. Behaviour change is owner-visible (see decisions).

### T3. The Media Source helper polls instead of waiting (high)

*MEDIA-02, XMOD-01, ENGINE-10, XMOD-08, MEDIA-08.*

Covered in bottom-line item 3. **Fix design (behaviour-preserving):**
- Validate the data root once and cache the stop and snapshot paths.
- Replace the 100 ms stop-poll loop with one `WaitHandle.WaitAny` over the owner process and a named stop event. The stop file stays as the durable signal.
- Cache the WinRT adapter.
- Set the private ACL once on the directory instead of on every write.
- Write only when the snapshot changes, plus a heartbeat.

Keep the anti-junction ancestor check on every *write*, implemented with .NET calls instead of cmdlets. Expected: 7.6% → under 0.5%.

Larger option for the owner: subscribe to media-session events, or retire the observer if WebNowPlaying's in-process session data covers its matching purpose.

### T4. UsageMonitor category readers (medium)

*ENGINE-04, ENGINE-05, CPU-02, CPU-05, GPU-01, RAM-04, IO-03, XMOD-07.*

- One reader per category for the whole Rainmeter process, at a fixed 1000 ms. Its `PollRate` option is commented out in the 4.5.28 source.
- `Disabled=1` neither stops the reader nor prevents registration.
- GPU's process-name option registers a separate timer that reads the Process category again, so the suite reads Process twice a second.

**Fix design.**
- Remove `DynamicVariables=1` from every UsageMonitor measure; the existing `!SetOption` calls already force exactly one re-read.
- Register optional categories only when their feature is shown, by include variants chosen at load: GPU process table and VRAM column, CPU process list, a new `RAMShowProcesses` opt-out.
- Never add a second process enumeration in a helper.

LogicalDisk is IO's irreducible floor and should be documented as such.

### T5. Resident helpers: wakeups, restarts and compiles (medium)

*ENGINE-06, RAM-01/02/03, GPU-02/07/08, XMOD-05/06, SHARED-02.*

- **RunCommand keeps a 1 ms-timeout polling thread alive for each resident helper.** Measured live at 104 wakeups/s for the GPU host.
- **A GPU or RAM refresh starts three PowerShell processes and two to three C# compiles.** A refresh-all starts up to about 10 PowerShell processes and 5 compiles.
- **Bootstrap hosts compile 1,500 lines of C# only to mint a GUID.**
- **The RAM page-file sample is rewritten every second although it rarely changes.**

**Fix design.**
- Launch resident hosts detached, using Media's owner-lease pattern, so RunCommand's thread ends.
- Fold the bootstrap into the host, minting the token with `[guid]::NewGuid()` in the existing metadata command.
- Use one compile per host, and cache per-boot static inventory.
- Sample PAGE at the capacity cadence.
- Write snapshots only on change, with a heartbeat.

A single shared host for every module is feasible but ranked last: it saves memory more than CPU and couples modules' lifecycles.

### T6. No stand-down when idle or the display is off (high)

*SHARED-01, ENGINE-08, CPU-06, GPU-08, RAM-06, NET-05, SHARED-03.*

**Fix design.**
- **One coordinator signal.** A single slow-ticking skin, or the GPU host via `GUID_CONSOLE_DISPLAY_STATE`, publishes an idle or display-off flag to the `Parallax` group. Each module then:
  - freezes redraws (meters to divider −1, one final paint showing "Paused (idle)");
  - pauses its own samplers;
  - unregisters optional UsageMonitor categories;
  - parks audio capture (T2);
  - tells resident helpers to heartbeat only.

  Resume on first input.
- **Two hazards found in review.**
  - SysInfo `IDLE_TIME` wraps after 49.7 days of uptime, which is realistic with Awake, so it must be taken modulo 2³² ms.
  - Any SysInfo measure turns its skin into a per-tick network-interface-table poller, so it must live in one slow skin, not in every skin.
- **Engine alternative.** Rainmeter 5.0's occlusion tracking would skip repaints of covered or locked skins. It is an RC and would change the baseline, so it is listed as an owner option rather than mixed into this series.

### T7. Refresh storms from settings (medium, interactive only)

*SHARED-02, XMOD-05.*

Every Global Settings arrow click and every ColorPicker Apply runs `!RefreshGroup Parallax`, which reloads every skin, kills and relaunches every helper, and recompiles. **Fix design:**
- Debounce arrow bursts with `!Delay` or ActionTimer, keeping a pending value so a second click doesn't compute from the stale one.
- Scope refreshes to the consumers of the changed key.

No quiet-state cost.

### T8. GPU accounting (medium, owner setting)

*ENGINE-02.*

**Measured 2026-10-22** with the isolated benchmark and the live preferences: `HardwareAcceleration=0` (WARP) against `=1` (D3D11), 3 trials each, interleaved one trial at a time. Reports `*-live-ha0-t*` and `*-live-ha1-t*`.

| Scenario | Renderer | Total | UI thread | Other threads | p95 second | Wakeups/s | Private MB |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Six live skins | 0 (WARP) | 28.23 [27.96-33.02] | 16.15 | 11.97 | 54.8 | 1,444 | 92 |
| Six live skins | 1 (D3D11) | 29.18 [27.11-31.10] | 19.88 | 7.33 | 40.4 | 1,190 | 141 |
| Media | 0 | 16.90 [15.87-17.94] | 11.40 | 5.50 | 35.1 | 702 | 22 |
| Media | 1 | 14.90 [13.39-17.24] | 13.46 | 1.03 | 28.2 | 451 | 73 |
| CPU | 0 | 9.22 [8.20-9.24] | 2.68 | 6.56 | 18.5 | 277 | 68 |
| CPU | 1 | 6.99 [6.30-8.34] | 2.61 | 4.43 | 11.6 | 210 | 118 |

What this shows:
- **The renderer barely changes total CPU.** The six-skin difference is inside the trial spread.
- **It changes where the work runs.** Hardware rendering moves about 3.7 points onto the shared UI thread and takes about 4.6 off the rasterizer worker threads, lowers the worst seconds (p95 55% → 40%) and the wakeups, and costs about 50 MB.
- **Turning acceleration off is not a saving lever.** Fewer repaints (T1) are, on either path.
- **Isolated runs before this one used WARP.** Their totals are representative of the live profile; their UI-thread shares understate the live profile by about 3-4 points.
- **Session drift is real.** The same six-skin WARP scenario measured 24.1% at 13:47 and 28.2% here, while other applications were busy. This is why step 3 compares builds only within one interleaved session.
- **The GPU-engine percentages of off-screen isolated windows** (about 2% under WARP, about 0.1% under D3D11) do not represent on-screen composition and are not used for conclusions.

Parallax must not write the owner's Rainmeter.ini. T1 reduces GPU work on either render path. An owner-run A/B of `HardwareAcceleration` 1 vs 0 (Manage → Settings, then restart), and optionally pinning Rainmeter to the UHD 630 in Windows graphics settings, would show where the remaining cost lands.

## Sharing across modules: what to share and what not

| Resource | Shared today? | Recommendation | Why |
| --- | --- | --- | --- |
| UsageMonitor category readers | **Yes**, process-wide per category | Keep; stop *registering* unused categories | Measured: CPU and RAM together pay one Process reader, 2.6 points less than alone; the .NET runtime is loaded once (−118 MB) |
| Audio capture (AudioLevel parent) | No, one per skin | One-capture rule plus capture lease (T2) | A second capture duplicates the stream, the FFT and audiodg work |
| Media-session observation | Duplicated: WNP in-process and Source helper | Prefer events; consider retiring the observer | Same Windows API polled in PowerShell |
| Resident PowerShell hosts | No (GPU, RAM, Media Source, Media Queue) | Shared helper *kit* (lease, guard, change-only writer) first; shared *process* last | The process saves memory, not CPU; coupling risk |
| Idle / display state | Doesn't exist | One coordinator, broadcast to the group | Must not be per skin (SysInfo hazard) |
| Static hardware inventory | Re-queried on every refresh | Per-boot cache file per module | Removes about 10 PowerShell starts per refresh-all |
| Lua controller bridge (set/paint) | Copy-pasted per module | One shared script loaded per skin | Removes duplicate repaints; enables a validator rule |
| Cross-skin bangs for sharing values | n/a | Avoid for per-tick data | A `!SetVariable` or `!CommandMeasure` across skins forces re-reads; sharing is not free |

## Step 2: build plan

Principles:
- **One fix per commit**, so step 3 can measure each fix alone and in combination.
- **Behaviour-preserving changes first.** Owner-visible behaviour changes only after the decisions below.
- **Every change keeps honest states:** paused and parked states are labelled, never shown as live values.
- **Module-owned files stay with their module.** Shared files change in one serial package.
- **Each package passes its own module suites, `tools/Test-Parallax.ps1`, a focused preview capture where pixels could change, and a quick isolated A/B** (`solo:<Module>` and `suite`, 3 trials) before it merges.

### Phase A: independent, behaviour-preserving (parallel, separate worktrees)

| Package | Findings | Files | Expected gain (measured basis) |
| --- | --- | --- | --- |
| A1 Media and Visualizer paint-on-change | MEDIA-01/03/04/06(a), VIS-02/03/04 | `Media/*`, `Modules/Media/*.inc`, `Modules/Visualizer/{Capture,Spectrum,View,Audio}.inc` | Most of Media's 6.9-8.8% UI-thread share when nothing animates; Visualizer's 3.6% in silence |
| A2 Source helper waits instead of polling | MEDIA-02, XMOD-01/08 (Source), MEDIA-08 | `Modules/Media/Source/SourceProvider.ps1`, `ProviderOwner.psm1` | 7.6% → <0.5% live (helper) |
| A3 CPU Meter hygiene | CPU-01/02/03/04, XMOD-04 (CPU) | `Modules/CPU/*` | CPU's 2.6% UI-thread share toward ~1 redraw per tick; plugin re-registration storm and thread bursts removed |
| A4 GPU hygiene | GPU-02/03/04/05/06, XMOD-04 (GPU) | `Modules/GPU/*` | Small CPU; fewer repaints |
| A5 Settings refresh debounce and scope | SHARED-02 | `@Resources/Scripts/Settings.lua`, `Modules/ColorPicker/ColorPicker.lua` | Interactive only |
| A6 Small-module hygiene (optional) | RAM-02/05, IO-01/02/05, NET-01/02/03, CHRONO-01 | per module | Each below 0.5% |

These touch disjoint files and can be built at the same time, each in its own worktree on its own branch. They merge in the order A2, A3, A4, A1, A5, A6, with a suite benchmark after each merge so an unexpected interaction shows up where it entered.

### Phase B: shared plumbing (serial, after A)

- **B1 Resident helpers launched detached,** with one compile per host and the bootstrap removed (ENGINE-06, RAM-01/03, GPU-07, XMOD-05 cache). Touches GPU and RAM after A3/A4.
- **B2 UsageMonitor registration by include variant** (T4). Touches CPU, GPU and RAM after A3/A4.
- **B3 Shared helper kit and change-only writer** (XMOD-06a, XMOD-08). Optional.
- **B4 HWiNFO export durability.** Added 2026-10-22 at the owner's request. B4 builds on A3's frozen-export detection and touches CPU and GPU files, so it runs after B2.
  - **Cause found the same evening.** HWiNFO polls sensors, and writes its export, only while its sensors window is open. The owner's `HWiNFO64.INI` starts HWiNFO at logon (`Autorun=1`) with its main window minimised and no setting that opens the sensors window. So from the 2026-10-01 reinstall (8.54) on, HWiNFO sat in the tray without polling.
  - **Confirmed by opening the window.** When the owner opened the sensors window at 22:58, the export resumed within seconds: 80-88 of 94 values changing in 4 s, and CPU Meter's readings moving.
  - **The lasting fix is HWiNFO's own setting** to open the sensors window at startup (minimised is fine). It is the owner's to set.

  B4 itself:
  1. **An actionable stale message.** The CPU footer names the fix: "HWiNFO export not updating: open HWiNFO's sensors window".
  2. **CPU clock from Windows.** When HWiNFO's clock is frozen or missing, CPU Meter falls back to Windows' own processor-performance counter, labelled as a different source. Temperatures, voltages and fan speeds have no Windows source without a kernel driver, so they stay HWiNFO-only and are withheld while frozen.
  3. **The same freshness check on GPU Meter's optional HWiNFO override** (`GPUPowerSource`/`GPUClockSource=1`). It is unused by default, but has the same weakness.

### Phase C: owner-visible behaviour (serial, after the decisions)

- **C1 Audio capture lease and one-capture rule** (T2). Shares `Capture.inc` with A1, so it comes after A1.
- **C2 Idle and display-off stand-down** (T6). Last, because it touches every module and depends on A1-B2's dividers and include variants.

### How it runs in this session

Phase A can be one workflow: six builder agents, one per package in its own worktree, each followed by an independent reviewer that tries to break the change against the project rules and the module's tests. I then merge and benchmark serially. B and C run as smaller serial steps with the owner's decisions in hand. Nothing is copied to the live skin. Fixes reach the desktop through the next release, per the owner's preference.

## Step 3: evidence protocol

- **Builds.** Baseline is 71bfcdc. For each fix commit *k*, three builds are staged from temporary worktrees: *baseline + k*, *all fixes*, and *all fixes − k*.
- **Measures.** Isolated benchmark, `solo` for the affected modules plus `suite`, with default and live preferences. 5 interleaved trials, 60 s windows. Metrics: UI-thread CPU, plugin-thread CPU, helper CPU, wakeups/s, private memory and GPU %. audiodg is measured live for T2.
- **Per-fix gain alone:** gₖ = cost(baseline) − cost(baseline + k).
- **Marginal gain inside all fixes:** mₖ = cost(all − k) − cost(all).
- **Combined gain:** G = cost(baseline) − cost(all).
- **Classification, decided before measuring.**
  - **Synergistic:** G − Σgₖ exceeds twice the pooled trial spread.
  - **Antagonistic:** it falls below minus that amount.
  - **Additive:** otherwise.

  Reported per metric. Comparing gₖ with mₖ shows *which* fixes interact.
- **Expected interactions** (to be confirmed or refuted, not assumed):
  - A1 with C1 should be synergistic. Media cannot stop its 20 Hz paint while a capture runs, and the capture lease cannot remove main-thread cost while Media still paints on the clock.
  - A3 with B2 should be antagonistic. Both remove UsageMonitor re-registration and reader work, so their gains overlap.
  - C2 overlaps everything in idle windows, which is expected and fine.
- **Quiet-state and overnight evidence.** The owner runs `Trace-ParallaxLive.ps1` overnight once before installing the release (baseline) and once after. Compared: Parallax share, audiodg, wakeups, CPU temperature and the spike contributor list.
- **Functional guard.** Each fix's module suites and a preview capture. A gain that breaks honest state or displayed values does not count.

## Owner decisions (2026-10-22)

1. **Drawer capture when silent (T2): release it.**
   - **When:** after about 2 minutes of silence plus 5 minutes without input.
   - **While released:** the drawer shows an honest "Capture paused" state.
   - **Resumes:** on input, on WebNowPlaying playback, or on a click.
   - **Where:** phase C1.
2. **Idle stand-down (T6): yes, but off by default.**
   - **Setting:** after N minutes without input, chosen in Global Settings (Off, 5, 10 or 30); **default Off**.
   - **While paused:** skins freeze with a visible "Paused (idle)" line and resume on the first input.
   - **Where:** phase C2.
3. **Title icon pulse (MEDIA-06): all three options, as a setting.**
   - **Setting:** a Media "Title icon animation" setting with 20 fps (default), 10 fps and Off.
   - **Animates:** only while a player reports Playing; otherwise Media paints only on change.
   - **Where:** phase A1.
4. **Source helper (T3): rework and evaluate.**
   - **Rework:** the behaviour-preserving rework.
   - **Evaluation now:** whether WebNowPlaying's in-process session data can replace the observer. The written evaluation and its recommendation come back to the owner before any replacement.
   - **Where:** phase A2.
5. **Hardware acceleration (T8): measure it programmatically.**
   - **How:** an isolated benchmark with `HardwareAcceleration=0` versus `1` in the generated Rainmeter.ini. The live setting and live instance are untouched.
   - **Note:** every isolated run in this review used Rainmeter's default, 0 (software rendering), while the live profile uses 1. Step 3 measures both modes.

6. **Frozen HWiNFO export (A3 honesty commit `1cb1bc7`): keep.**
   - **Confirmed on screen first:** two captures of the live CPU Meter 8 s apart showed every usage value changing, while all voltage, temperature, clock and fan values stayed identical to the export last written on 2026-10-01. The footer read "HWiNFO: connected" because it only checked that HWiNFO was running.
   - **With the commit:** once every bound value has been unchanged for 60 s, the footer reads "HWiNFO: export not updating" and the frozen readings are withheld. They return when values change.

The audiodg attribution question is answered: see [Live A/B](#live-ab-drawer-and-spotify-2026-10-22). 7. **GPU History time axis (A4 `a49a440`): keep.**
   - **Change:** one point per real 2 s driver sample (about 7 min across 208 px) instead of each sample plotted twice (3.5 min).
   - **Accepted trade-off:** GPU History no longer lines up in time with CPU and Memory History, which advance once a second.
   - **To align them later:** set `SensorInterval=1000`, which roughly doubles the GPU helper's sampling cost.

Still open with the owner: whether Media's idle 50 ms wake-up while title animation is on is worth removing (deferred until the phase-A benchmark quantifies it).

## Found along the way (not performance)

- **HWiNFO's registry export is frozen in the live session.**
  - None of its 47 exported values changed over 6 s.
  - All six cores report exactly 4,277.2 MHz.
  - The readings, for example "Core Temperatures = 70 °C" and "GPU Power = 11.351 W", were identical at 12:35 and 14:16.
  - The `HKCU\Software\HWiNFO64\VSB` key was **last written on 2026-10-01 at 08:12:52**, according to its registry last-write time. The running HWiNFO, started 2026-10-21 17:54, has never updated it, so every exported value is a three-week-old snapshot.
  - Either HWiNFO's per-sensor "Report value in Gadget" export is off in the current session, or HWiNFO isn't polling sensors. Which one is not determined.
  - **CPU Meter's sensor rows read this export, so the live VID, clock and temperature figures are probably frozen values.** The project rules require stale data to be shown as stale. Whether CPU's sensor controller detects an export that stops changing has not been checked; it should be checked in step 2.
- **The RAM page-file host was not running live** (see the live footprint section).

## Not verified yet

- **What starts the Spotify renderer runaway.** It was seen only in a long-running session.
- **Fan attribution overnight.** Needs the owner-run overnight trace. HWiNFO exports no CPU or case fan RPM, and its export is currently frozen (above), so the trace's temperature columns need HWiNFO restarted first.
- **Isolated Media figures exclude WebNowPlaying and the Source helper.** Live figures include them.
- **The cost of the five UsageMonitor categories individually.** Plugin-thread totals are measured per module, not per category.
- **DWM's share of Parallax redraws.** Not separable without ETW tracing.
- **Behaviour of the live RAM page-file host** (not running at trace time).

## Tooling added in this step

| Tool | Purpose |
| --- | --- |
| [tools/Parallax.Perf.psm1](../tools/Parallax.Perf.psm1) | Handle-free process, thread, context-switch and GPU-engine accounting shared by the tools below |
| [tools/Benchmark-Parallax.ps1](../tools/Benchmark-Parallax.ps1) | Isolated solo, suite and leave-one-out benchmark with interaction analysis; JSON under `build/perf-benchmark` |
| [tools/Trace-ParallaxLive.ps1](../tools/Trace-ParallaxLive.ps1) | Read-only trace of the running session and whole machine, with HWiNFO sensors and spike attribution; CSV under `build/perf-trace` |
| [tools/perf-dashboard.html](../tools/perf-dashboard.html) and [tools/Serve-PerfDashboard.py](../tools/Serve-PerfDashboard.py) | Live dashboard of both, read-only, served on loopback and optionally on the Tailscale address behind a token |

The tools share one limitation: they measure Rainmeter and its helpers, not DWM's share of composition.

## Verifier notes beyond the reviews

These came from the verifiers' "missed" lists. They are folded into the themes above where they change a design.

- **Every loaded skin arms a 500 ms mouse timer, whatever its Update.** That is 2 wakeups/s per skin, settings panels included (Skin.cpp:485). The six live skins add 12 wakeups/s that no skin change can remove.
- **Network's skin calls `GetIfTable2` before every tick, for every interface** (Skin.cpp:3276). Any SysInfo measure turns its host skin into such a poller. This is why the idle signal must live in one slow skin.
- **SysInfo `IDLE_TIME` uses a 32-bit tick and jumps by about 4.29 million seconds after 49.7 days of uptime.** With Awake that is realistic, so a threshold built on it must use the value modulo 2³² ms.
- **GPU's process-name option registers a second timer that reads the Process category every second, even with the GPU process measures disabled.** Together with the CPU/RAM reader, the suite reads Process twice a second.
- **A refresh can start up to 5 C# compiles, not 3.** GPU and RAM each compile in both their bootstrap and their host.
- **CPU's sensor reconnect sends about 1,064 bangs on each refresh or HWiNFO restart,** each `!SetOption` on a measure first scanning 374 meters. This is a load-time cost.
- **The isolated CPU figure in PERFORMANCE.md (6.56%) predates the 2026-10-18 tooltip removal.** It is superseded by this review's measurements.

## Appendix: finding index

Severity is the verifier's corrected rating. Engine findings had no separate verifier; they are cited from Rainmeter 4.5.28.3936 source. The full reviewer and verifier records, with file and line evidence, proposed fixes and measurement plans, were produced by the review workflow and are summarised in the themes above.

| ID | Severity | Verdict | Resource | Applies in | Fix risk | Finding |
| --- | --- | --- | --- | --- | --- | --- |
| XMOD-01 | high | confirmed | helper process cpu | optional feature | low | Media Source observer polls its stop marker 10×/s through an ancestor-walking path validator in interpreted PowerShell, and republishes with ACL rewrites and a forced flush every 2 s |
| XMOD-02 | high | confirmed | audio engine | default and live | medium | AudioLevel capture keeps the Windows audio engine running in silence, and it is per skin, so Media's drawer and the standalone Visualizer can never share it |
| XMOD-03 | high | confirmed | main thread cpu | default and live | medium | Media's fixed 50 ms tick repaints its whole window 20×/s in every state, and is the dominant main-thread, compositor and wakeup source; per-skin 1 Hz timers are a minor, uncontrollable remainder |
| ENGINE-01 | high | engine (unverified) | main thread cpu | default and live | medium | No dirty-checking: any due meter forces a full-window redraw, so Media repaints 16-20 times a second in every state |
| ENGINE-03 | high | engine (unverified) | audio engine | optional feature | medium | An AudioLevel parent keeps a silent render stream and a loopback stream running for its whole life; Disabled or Paused cannot stop them |
| ENGINE-08 | high | engine (unverified) | idle wakeups | default and live | medium | Nothing in the engine pauses on idle, screen-off or lock; a shared idle governor built on SysInfo IDLE_TIME is the only suite-wide lever |
| ENGINE-10 | high | engine (unverified) | helper process cpu | default and live | medium | WebNowPlaying 2.0.7 already subscribes to GSMTC events in-process; Media's resident source observer polls the same API in PowerShell |
| MEDIA-01 | high | confirmed | main thread cpu | default and live | medium | The 50 ms tick redraws the whole Media window 20 times a second in every state, including idle with the drawer closed |
| MEDIA-02 | high | confirmed | helper process cpu | live only | low | SourceProvider.ps1 polls for Stop 10 times a second with ~19 PowerShell cmdlets per poll, rebuilds its WinRT adapter every cycle, and rewrites, flushes and re-ACLs its snapshot every 2 s |
| MEDIA-05 | high | upgraded | audio engine | live only | medium | The drawer's AudioLevel loopback capture stays open indefinitely, possibly keeping the Windows audio engine (audiodg) active through silent nights |
| SHARED-01 | high | confirmed | idle wakeups | default and live | medium | No suite-wide idle or quiet stand-down: every skin and helper keeps running unchanged all night with the display off |
| VIS-01 | high | confirmed | audio engine | live only | medium | AudioLevel output capture keeps the Windows audio engine running 24/7 (silent render stream + loopback), through silence and screen-off |
| CPU-01 | medium | confirmed | main thread cpu | default and live | low | Two to three full redraws and forced meter passes per tick (redundant !UpdateMeterGroup CPUUI + !Redraw from inside Update()) |
| CPU-02 | medium | confirmed | main thread cpu | default and live | low | 74 UsageMonitor measures carry DynamicVariables=1 (62 of them disabled), so the plugin's Reload runs 74 times every tick and can start threads |
| CPU-06 | medium | downgraded | idle wakeups | default and live | high | No quiet, idle or screen-off mode: the full 1 Hz pipeline runs all night with the display off |
| XMOD-04 | medium | confirmed | main thread cpu | default and live | low | A duplicated controller pattern forces extra full repaints from periodic Update paths (CPU every tick, CPU sensors every 2 s, GPU on every telemetry change), with un-deduplicated !SetOption in CPU |
| ENGINE-02 | medium | engine (unverified) | gpu compositing | live only | low | Live HardwareAcceleration=1: every redraw is a D3D11 submission, a GPU-to-CPU sync for GDI, and a DWM recompose, and it shows as Rainmeter GPU usage |
| ENGINE-04 | medium | engine (unverified) | plugin thread cpu | default and live | medium | UsageMonitor runs one 1 Hz whole-category reader per category for the whole process; Disabled measures still start it and only unloading stops it |
| ENGINE-05 | medium | engine (unverified) | main thread cpu | default and live | low | Disabled measures still re-read options under DynamicVariables; CPU's 74 such UsageMonitor measures cost 74 plugin Reloads a second |
| GPU-01 | medium | confirmed | plugin thread cpu | default and live | low | Process table keeps two UsageMonitor workers reading the whole GPU Engine and GPU Process Memory categories every second |
| GPU-07 | medium | confirmed | load time | default and live | medium | Every GPU load/refresh launches three PowerShell hosts and three csc.exe compiles; Global Settings and ColorPicker trigger it per click |
| GPU-08 | medium | confirmed | idle wakeups | default and live | medium | No GPU work pauses when the display is off; the helper keeps querying the driver every 2 s all night |
| MEDIA-03 | medium | confirmed | main thread cpu | default and live | low | Four always-updating DynamicVariables=1 meters re-parse ~70 KB of pre-expanded geometry formulas every 50 ms, and two OnUpdateActions fire 40 no-op Lua bangs per second |
| MEDIA-04 | medium | confirmed | main thread cpu | live only | low | The open spectrum drawer keeps per-tick mask re-reads, 30 capture measures and its own redraw driver running in silence |
| MEDIA-06 | medium | confirmed | gpu compositing | default and live | low | While playing, the 14 px title-icon pulse costs a 20 fps full-window redraw plus 6 !SetOption calls and a full option re-read per tick |
| SHARED-02 | medium | confirmed | load time | settings panel only | low | Every Global Settings or ColorPicker commit refreshes every loaded Parallax skin, killing and relaunching all module helpers (refresh storm on stepper clicks) |
| VIS-03 | medium | confirmed | gpu compositing | optional feature | low | Standalone Visualizer redraws its whole layered window at 20 FPS even when nothing changes (Idle, Unavailable) |
| CPU-03 | low | downgraded | main thread cpu | default and live | low | MeterHistory re-parses 64 shapes (52 invisible placeholders) and about 17 KB of path text on every re-read, about 2.5 times per second |
| CPU-04 | low | confirmed | main thread cpu | default and live | low | CPU.lua issues un-gated bangs every tick, and hidden slot meters are updated twice per tick |
| CPU-05 | low | downgraded | plugin thread cpu | default and live | medium | The UsageMonitor Process-category worker reads every process's counters every second and keeps running even when the process list is hidden |
| CPU-07 | low | confirmed | main thread cpu | default and live | low | CPU ignores the suite's Balanced/Economy cadence profile |
| CPU-08 | low | confirmed | load time | default and live | medium | Each refresh launches two PowerShell 5.1 processes and parses 684 measures, 512 of them with a formula UpdateDivider |
| CHRONO-01 | low | confirmed | main thread cpu | default and live | medium | Whole-window redraw every second, and 'Show seconds: Hidden' does not stop it |
| CHRONO-02 | low | confirmed | main thread cpu | default and live | low | Per-tick Lua and !SetOption traffic are already change-gated; leftover work is negligible |
| XMOD-05 | low | downgraded | load time | default and live | low | Every load/refresh relaunches about 10 PowerShell processes, 5 C# compiles and several CIM queries across modules for static data; nothing is cached |
| XMOD-06 | low | downgraded | memory | default and live | low | Resident helper hosts duplicate a PowerShell/CLR runtime, the lease, parent-guard and snapshot code, and the compile step; a shared host is feasible but should follow the cheaper shared-kit steps |
| XMOD-07 | low | confirmed | plugin thread cpu | default and live | low | UsageMonitor workers are already shared process-wide per category, but disabled measures still keep category workers alive, and CPU's DynamicVariables re-registers 74 measures every tick, spawning threads when it collides with a worker |
| XMOD-08 | low | confirmed | other | default and live | low | File-based IPC between helpers and skins churns the file system every 1–2 s (new temp file plus replace, ACL rewrites, a forced flush, lease rewrites) even when nothing changed |
| ENGINE-06 | low | engine (unverified) | idle wakeups | default and live | medium | Each resident RunCommand child keeps a 1 ms-timeout polling thread alive inside Rainmeter |
| ENGINE-07 | low | engine (unverified) | main thread cpu | optional feature | low | Win7Audio does a full COM enumerator cycle on every Update and GetString; the drawer's volume measure runs two cycles four times a second |
| ENGINE-09 | low | engine (unverified) | main thread cpu | default and live | low | Cost of bangs, !SetOption and DynamicVariables: the deferred full re-read and repaint dominate; Lua meter handles avoid both |
| GPU-02 | low | downgraded | helper process cpu | default and live | medium | Resident driver host repeats identity checks ~18x and NVML/NVAPI PCI matching twice on every sample |
| GPU-03 | low | confirmed | main thread cpu | default and live | low | Temperature.lua forces an extra full GPU-skin render mid-cycle on every changed driver sample |
| GPU-04 | low | confirmed | main thread cpu | default and live | low | Each 2 s driver sample is re-read, re-parsed and plotted twice; the History graph records duplicated points |
| GPU-05 | low | confirmed | main thread cpu | default and live | low | ProcessGraph.lua sends five Show/HideMeterGroup bangs every tick regardless of change, forcing a resize check and guaranteeing a redraw |
| GPU-06 | low | confirmed | main thread cpu | default and live | low | History Line meter and startup cover re-parse all options every tick forever (DynamicVariables=1) |
| IO-01 | low | confirmed | main thread cpu | default and live | medium | The hidden A-Z meter bank updates every second, and 104 String meters re-measure their text each tick |
| IO-02 | low | downgraded | gpu compositing | default and live | medium | Full-window redraw and graph re-parse every second, even when nothing on screen changed |
| IO-03 | low | confirmed | plugin thread cpu | default and live | low | LogicalDisk UsageMonitor worker reads the whole category at a fixed 1 Hz, regardless of selection |
| IO-04 | low | confirmed | main thread cpu | default and live | low | 30 s inventory batch queries free space and labels for every present letter on the main thread, whether or not it is selected |
| IO-05 | low | confirmed | main thread cpu | default and live | low | Controller recomputes slow-changing selection, layout, name and capacity state every second |
| IO-06 | low | confirmed | helper process cpu | optional feature | low | Model/both name modes relaunch a PowerShell + CIM query on every IO load or group refresh |
| MEDIA-07 | low | confirmed | idle wakeups | optional feature | low | The queue reader and Spotify helper keep reading, polling and writing a queue that no loaded skin displays |
| MEDIA-08 | low | confirmed | load time | live only | low | Each Media refresh launches up to two PowerShell Resume hosts, and the Source Resume makes up to 4 WMI queries before checking whether its worker already runs |
| NET-01 | low | confirmed | main thread cpu | default only | low | Connection bank re-queries slow-changing, relatively expensive system state every 2 s (GetAdaptersAddresses x2, NLM COM create+RPC, GetIpAddrTable x2) |
| NET-02 | low | confirmed | helper process cpu | default only | low | Five WiFiStatus measures issue five identical WLAN RPCs every 5 s; two are not displayed and there is no backoff when Wi-Fi is unavailable or access is denied |
| NET-03 | low | confirmed | main thread cpu | default only | low | Per-tick redundancy: duplicated identity measures, 1 Hz connection controller over 2 s data, always-dynamic options re-resolving 'Best' about 12x/s, and static meters updated every second |
| NET-04 | low | confirmed | main thread cpu | optional feature | medium | Network is pinned to 1 Hz and does not follow the suite's Economy profile |
| NET-05 | low | confirmed | idle wakeups | default only | medium | Nothing pauses while the user is idle or the screen is off; a shared idle gate would let Network stop sampling and redrawing honestly |
| RAM-01 | low | downgraded | idle wakeups | default and live | medium | Resident PAGE host keeps a RunCommand reader thread polling every timer tick for the skin's whole lifetime |
| RAM-02 | low | confirmed | helper process cpu | default and live | low | PAGE is sampled every second with a fresh temp-file create + ReplaceFile, although the value rarely changes |
| RAM-03 | low | downgraded | load time | default and live | medium | Each RAM load/refresh launches three PowerShell processes and compiles the same C# twice |
| RAM-04 | low | downgraded | plugin thread cpu | default and live | medium | Process table rides UsageMonitor's fixed-1 Hz full Process-category read; Disabled does not unregister it, and the suite reads Process twice per second |
| RAM-05 | low | confirmed | main thread cpu | default and live | low | Per-tick meter work: dynamic re-reads of hidden and static meters, an endless cover Shape rebuild, all-row bang storms, and a full redraw each second |
| RAM-06 | low | confirmed | main thread cpu | default and live | medium | No idle or display-off awareness: RAM runs at full cadence all night with the screen off |
| SHARED-03 | low | downgraded | idle wakeups | default and live | medium | Refresh profiles don't reach the fastest consumers: Media's fixed 20 Hz tick, CPU's own interval and the fixed 1 s skins; there is no low-power profile; non-preset VisualizerInterval values fall back to 50 ms |
| SHARED-04 | low | confirmed | gpu compositing | default and live | low | Fixed per-skin cost: any every-tick meter forces a full-window repaint and UpdateLayeredWindow upload, and the shared text styles keep a static title doing that even when nothing changed |
| VIS-02 | low | downgraded | main thread cpu | live only | low | Hidden spectrum mask is still fully re-read every tick in silence, and its X/Y/W/H re-parse long geometry formulas every tick in both states |
| VIS-04 | low | confirmed | main thread cpu | live only | low | Win7Audio volume poll performs two full COM setup/teardown cycles every 250 ms, and DeviceStatus calls GetState every tick |
