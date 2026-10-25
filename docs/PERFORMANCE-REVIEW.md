# Performance review, step 1: burden, bottlenecks and fix design

Review date 2026-10-22, against commit 71bfcdc (0.1.0-alpha.6 plus the WebNowPlaying placeholder fix), Rainmeter 4.5.28.3936, Windows 11 on an i7-8700 (6 cores / 12 threads) with a GTX 1080 and UHD 630. **This step changed no skin code.** It added measurement tools only (see [Tooling](#tooling-added-in-this-step)). Step 2 (building the fixes) waits for the owner's review of this document.

CPU figures are **percent of one logical core** unless stated otherwise. 100% means one of the 12 hardware threads is fully busy; the whole machine is 1200%.

## Where it stands (2026-10-25)

- **Six live skins:** 20.5% of a core at baseline, 9.0 after phase A, 7.7 after phase B (−63%). With the CPU, RAM and GPU process lists hidden: 4.7 (−77%). Measured in an isolated benchmark with live preferences, 3 interleaved trials. See [Phase B result](#phase-b-result-merged-and-measured-2026-10-23).
- **The overnight fan peaks are not Parallax.** They come with bursts of display re-detection work in explorer and NVIDIA's display service, about every 50 s, with the screens off. Parallax is a steady floor of about a quarter of the night-time load. See [Overnight trace](#overnight-trace-2026-102223-what-drives-the-night-time-fan).
- **Cause found and fixed (2026-10-25): the left monitor's DisplayPort link was dropping.** With the screens off, it disconnected and reconnected 70-100 times an hour.
  - **The fan.** That is the display re-detection behind the fan peaks.
  - **The slowdown over days.** Each reconnect also made Windows leak a kernel copy of every Parallax skin's image, about 2.2 MB, which explains the slowdown that only a restart cleared.
  - **The fix.** Swapping the two DisplayPort cables stopped it: 0 dropouts in 25 dark minutes, against 11-17 in 5-6 minutes before.
  - See [Display dropouts and the kernel memory leak](#display-dropouts-and-the-kernel-memory-leak-2026-102425).
- **Phase C is merged.**
  - **Idle pause (C2):** off by default; when on, it takes the six skins from 8.5 to 3.65% while paused.
  - **The drawer (C1):** releases its audio capture after silence while you are away.
  - **Its idle coordinator** cost about 57 UI-thread wakeups/s beside the open drawer, a Rainmeter per-window cost; the fix C3 removed the avoidable part. See [Phase C result](#phase-c-result-merged-and-measured-2026-10-23).
  - **Re-measured on 2026-10-25 after a restart, that window cost is about 2.** It came from the machine's degraded state (a runaway TextInputHost and days of leaked kernel memory), not from the coordinator. Every skin's UI thread was cheaper too. See [TextInputHost and the after re-measure](#display-dropouts-and-the-kernel-memory-leak-2026-102425).
- **Step 3: are the gains additive? It depends on where you look.**
  - **Inside Media, synergistic:** the two halves of A1 save 4.5 points alone and 8.5 together.
  - **Across the six skins, antagonistic:** the packages save 21 points when each is added alone, 12.7 together.
  - **In the standalone Visualizer, additive.**
  - The likely shared cause of the overlap is Rainmeter's single, contended UI thread. See [Step 3 result](#step-3-result-2026-10-24-are-the-gains-additive).
- **Nothing has reached the desktop yet.** The live skin changes only when a release is installed.
- **Open for the owner:**
  - **The cable fix** still needs an overnight confirmation;
  - whether to hide the process lists (the largest remaining cost);
  - the C3 options (a lazy coordinator for the drawer; it would now save about 2 wakeups/s, not 57);
  - the stand-down helper kill race.

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

**Update 2026-10-23: the overnight trace answered this.**
- **The regular fan peaks,** about every 50 s, come with bursts in explorer and NVIDIA's display container, not in Parallax. That fits display re-detection while the screens are off.
- **Parallax is a steady floor** of about a quarter of the night-time load. The fan speeds turned out to be exported under labels that do not say "fan"; the trace now records them.
- See [Overnight trace](#overnight-trace-2026-102223-what-drives-the-night-time-fan).

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

## Phase A result (first measurement, 2026-10-22)

This is not the full step-3 protocol. It compares baseline `916c9ab` with all of phase A merged at `dfe55b8`.

**How it was measured:**
- Each build was staged from its own temporary worktree under `C:\pxab`, using that commit's own tools.
- The isolated benchmark ran with the live preferences (drawer open, per-thread history, sensors) and hardware rendering.
- 3 trials per build were interleaved build by build. Reports: `*-live-baseline-t*` and `*-live-phaseA-t*`.
- A WINCH session was reading files during part of the run. The interleaving spreads that load over both builds.

CPU in % of one core; median [min-max].

| Scenario | Baseline | Phase A | Change | UI thread | Plugin threads | Helpers | p95 second | Rainmeter wakeups/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Six live skins | 25.54 [25.42-31.15] | **10.28** [9.45-12.59] | **−15.26 (−60%)** | 16.89 → 4.65 | 6.97 → 4.80 | 1.97 → 0.97 | 37.9 → 17.2 | 1,172 → 808 |
| Media (drawer open, silent) | 11.91 [11.27-13.42] | **2.23** [1.69-2.98] | **−9.67 (−81%)** | 11.01 → 1.74 | 0.89 → 0.10 | — | 20.9 → 6.2 | 461 → 164 |
| Visualizer | 5.30 [5.07-6.30] | **1.34** [1.29-2.13] | **−3.96 (−75%)** | 4.66 → 1.29 | 0.74 → 0.05 | — | 13.7 → 4.6 | 458 → 172 |
| CPU | 5.90 [5.71-7.18] | **4.43** [4.38-4.87] | **−1.47 (−25%)** | 2.28 → 1.59 | 3.62 → 2.98 | — | 9.4 → 6.2 | 196 → 166 |
| GPU | 2.94 [2.72-3.22] | **1.90** [1.42-2.10] | **−1.05 (−35%)** | 0.79 → 0.45 | 0.89 → 1.04 | 1.26 → 0.37 | 7.0 → 5.4 | 252 → 252 |
| RAM | 3.94 [3.81-4.35] | 3.97 [3.75-4.21] | +0.04 (no change) | 0.40 → 0.20 | 3.08 → 3.47 | 0.36 → 0.28 | 7.7 → 6.2 | 248 → 256 |

Reading it:
- **The six-skin total fell by 60%, and the shared UI thread by 72%.** Spikes roughly halved.
- **Every change beyond the trial spread is a reduction.** Only RAM stayed flat: its cost is the shared UsageMonitor Process reader, which phase B (B2) addresses.
- **GPU's helper fell from 1.26% to 0.37% of a core.** That is GPU-02's once-per-frame identity check.
- **A hint of synergy, not yet a claim.** The six-skin gain (15.3) exceeds the sum of the measured solo gains (Media 9.7 + CPU 1.5 + GPU 1.1 + RAM 0 = 12.2; IO and Chronometer were not measured solo). But the difference (3.1) is about the baseline's wide spread (±2.9). Step 3's per-fix builds decide it.
- **What this run cannot show.** A2's Source-helper gain needs the live trace after a release; isolated profiles keep Media's providers inert. audiodg, kept alive by the open drawer's capture, is phase C1.

## Phase B result (merged and measured 2026-10-23)

Each package was built in its own worktree and then reviewed by an independent agent that tried to break it. B4 and B6 came back with required changes, were fixed and reviewed again. All five were approved. They are merged on the review branch, one merge per package: `bee188c` B1, `7ccad28` B2, `9bb2a1b` B4, `44ad4b5` B5, `0fd5b39` B6. B1, B2 and B4 were built in sequence, each on the previous one. B5 and B6 were built from `191a1cd`. The five packages share no files.

| Package | Commits | What changed | Visible to the owner |
| --- | ---: | --- | --- |
| **B1** helpers | 8 | RAM's PAGE host and GPU's telemetry host now run detached from RunCommand. That ends RunCommand's 1 ms polling thread, measured live at 64-104 wakeups/s per host. The compiling bootstrap is gone: one fewer C# compile per load (RAM 2 → 1, GPU 3 → 2). PowerShell starts per load are unchanged against baseline. RAM's snapshot is written only on change, plus a heartbeat. A failed session retries after 10, 60 and 300 s. | PAGE and GPU readings recover by themselves after a stall. Before, the live "PAGE: Unavailable" never recovered; the cause was reproduced by suspending Rainmeter for 20 s. After a refresh, the old host lingers up to about 17 s, then removes its own files. |
| **B2** UsageMonitor | 5 | UsageMonitor measures load by include variant. Nothing changes at the defaults. Savings appear only with the opt-outs: `GPUShowProcesses=0`, `GPUShowProcessMemory=0`, and `CPUShowProcesses=0` together with the new `RAMShowProcesses=0`. The suspected second Process read does not exist; the UsageMonitor source confirms it. | New RAM setting to hide the process list. |
| **B4** HWiNFO | 7 | A frozen export now names the fix in CPU's footer: "HWiNFO: open Sensors". The plan's longer text does not fit the narrowest footer. CPU's clock falls back to Windows and is marked as a Windows reading. GPU's HWiNFO override shows "Not updating" after 60 s without change. GPU's mapping guide is updated. | Clear messages when HWiNFO's sensors window is closed. |
| **B5** Media transport | 1 | Media's transport buttons repaint when the play state changes outside Media, for example a media key or another app. The bug predates phase A. No periodic repaint was added. | The Play/Pause button follows external pauses within about 1 s. |
| **B6** step-3 tooling | 11 | `New-PerfBuild` makes baseline + k and all − k builds, with a byte-exact UTF-16 merge. `tools/perf-fixes.json` lists 43 phase-A fixes in 30 units. `Invoke-PerfMatrix` runs the matrix and classifies interactions by the rule above. A new validator rule (XMOD-04) flags unconditional repaint bangs. The workflow is in `docs/PERF-STEP3.md`. | None (developer tooling). |

**Not built, with reasons:**
- **GPU write-on-change.** GPU's payload changed on 19 of 19 idle samples, because board power moves every sample.
- **Folding GPU's adapter query into the host.** It reshapes adapter state and is not low-risk.
- **RAM-02, slower PAGE sampling.** Not approved.
- **B3, the shared helper-kit file.** A new executable file needs a staging-allowlist change. RAM's change-only writer landed inside B1 instead.
- **The compiled-assembly cache.** Out of scope for this phase.

**Checks on the merged tree:**
- `Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors`: 23 configs, 109 files, 0 errors, 0 warnings. This includes the new XMOD-04 rule run over every package's Lua.
- Tool tests: `Test-RepaintRule` 50 assertions, `Test-PerfBuild` 49, `Test-PerfMatrix` 107, `Test-PerfManifest -SkipBuilds` 309, and the 15 tests in `test_merge_utf16.py`. All pass.
- Native Rainmeter runs passed on each package's own branch. None ran on the merged tree, so the overnight trace stayed clean.

**Open minor issues from the reviews (not fixed):**
1. A hand-edited `CPUShowProcesses` other than 0 or 1 loads no process slots and asks for a refresh that cannot help. The settings window only writes 0 or 1.
2. With GPU's table off, GPU Settings reads "462 px / Fit" while the fitted panel is 352 px.
3. RAM and GPU retries rely on each launcher measure being declared before its controller. Swapping the order would use up all three retries at once.
4. Closing a skin in its first seconds leaves the new host running until its 15 s lease lapses. It can also leave a small `.lease` file in TEMP.
5. Media's `LayoutTransport`, currently disabled, would force its meters twice if re-enabled. The comment on why the periodic path needs no `!Redraw` names the wrong engine mechanism.
6. CPU says "HWiNFO: open Sensors" where GPU says "Not updating" for the same condition.
7. `Invoke-PerfMatrix -Metric` is fragile with a partial metric list.

The stale doc lines the reviewers flagged (ARCHITECTURE, PACKAGING, DEPENDENCIES, RAM.md, GPU.md) were corrected at merge.

**Measured 2026-10-23, 08:38-09:53.**
- **Setup:** isolated benchmark, live preferences (drawer open), hardware rendering.
- **Trials:** 3 per build, interleaved in a rotating order.
- **Same instrument for every build:** the benchmark tooling is byte-identical in all three commits.
- **"Lists hidden":** phase B with `CPUShowProcesses=0`, `RAMShowProcesses=0` and `GPUShowProcesses=0`, from a copy of the live preferences.
- **Reports:** `build/perf-benchmark/*-live-pb-*-t*.json`.

CPU in % of one core, median [min-max].

| Scenario | Baseline `916c9ab` | Phase A `dfe55b8` | Phase B `08ecb9f` | Phase B, lists hidden |
| --- | ---: | ---: | ---: | ---: |
| **Six live skins** | 20.54 [11.48-21.58] | 9.02 [6.81-9.44] | **7.68** [7.50-9.28] | **4.69** [4.30-5.48] |
| UI thread | 12.54 | 2.97 | 2.99 | 3.14 |
| Plugin threads | 5.20 | 4.22 | 3.88 | 0.64 |
| Helpers | 2.54 | 0.80 | 0.81 | 0.92 |
| p95 second | 27.74 | 15.34 | 14.39 | 10.13 |
| Rainmeter wakeups/s | 1,154 | 642 | 567 | 531 |
| Media | 9.89 | 2.20 | 2.00 | — |
| Visualizer | 4.19 | 1.80 | 1.48 | — |
| CPU | 5.02 | 4.37 | 4.47 | 1.70 |
| GPU | 4.10 | 2.03 | 2.02 | 1.11 |
| GPU wakeups/s | 263 | 257 | **155** | 127 |
| RAM | 3.66 | 3.64 | 3.39 | 0.74 |
| RAM wakeups/s | 251 | 266 | **159** | 131 |

**Reading it:**
- **From baseline, the six skins cost 63% less after phase B** (20.5 → 7.7), and 77% less with the process lists hidden (→ 4.7). The peak second fell from 27.7 to 14.4.
- **Phase B's CPU change at the default settings is inside the trial spread** (9.0 → 7.7, with overlapping ranges). That was expected: B1 removes wakeups rather than CPU time, and B2 changes nothing at the defaults.
- **B1's wakeup cut is clear.** GPU and RAM each lose about 100 Rainmeter wakeups a second (257 → 155, 266 → 159). That matches the 104/s measured live for RunCommand's polling thread.
- **The process lists are now the largest remaining cost.** Hiding them takes the six skins from 7.7 to 4.7, and plugin-thread time from 3.9 to 0.6. That plugin time is UsageMonitor's whole-category Process and GPU readers. Hiding the lists is a feature trade-off and the owner's choice; the defaults keep them.
- **One outlier.** Baseline's first six-skin trial read 11.5, about half the other two (21.6 and 20.5), and its UI-thread time was half as well. The median uses all three trials.
- **Why these differ from yesterday's run** (25.5 at baseline, 10.3 after phase A): that ran under different background load. Today's numbers come from one interleaved session, so they compare like with like.

## Phase C result (merged and measured 2026-10-23)

**How it was built.**
- **Design first.** A designer agent wrote the design from the Rainmeter 4.5.28 source, with line references.
- **Then an adversarial review of the design.** It found 1 blocking and 6 major problems, all corrected before any code was written. Examples: meters whose dividers modules change at runtime would have stayed frozen after a pause; a stand-down could stick after a missed broadcast; a coordinator started inside a skin's load could deactivate itself mid-refresh.
- **C1 and C2 were then built in sequence, each reviewed by an independent agent.** C1 was approved directly (7 commits). C2 needed one round of fixes and a second review (23 commits, 10 of them review fixes).
- **Merged** as `6406612` (C1) and `67e83c5` (C2). `95331f9` then fixes a Windows PowerShell 5.1 default-parameter bug in the new variants test, and `4e1d711` merges the wakeup follow-up C3 (below).

**The shared idle signal: a hidden coordinator config, `Parallax\Idle`.**
- **Why a separate config.** Windows' "time since last keyboard or mouse input" reaches a skin only through the SysInfo `IDLE_TIME` measure. Any SysInfo measure turns its skin into a network-table poller: `GetIfTable2` runs on every tick of that skin, about 2 ms per call on this machine (`Skin.cpp`, `NetworkUtil.cpp`). Inside Media's 50 ms tick that would cost about 0.8% of a core. So the suite's only SysInfo measure lives in a separate hidden skin that ticks every 2 s.
- **When it runs.** It loads only while something needs it: an open drawer, or Idle pause set to 5, 10 or 30 minutes. It unloads itself otherwise.
- **The 49.7-day wrap** of Windows' input clock is handled.
- **A safety net.** The coordinator re-broadcasts every minute. A skin that hears nothing for 3 minutes resumes by itself, so a lost broadcast can never leave a skin frozen.

**C1, the drawer's capture lease (owner decision 1).**
- **When it parks.** After 2 minutes of silence, plus 5 minutes without keyboard or mouse input, while no WebNowPlaying player reports Playing.
- **What parking does.** Media reloads into a variant with no AudioLevel measure, so Windows' audio engine can stop. Wednesday's live A/B measured that engine at 9.8% of a core with the drawer open, and not running with it collapsed. The drawer shows "Capture paused".
- **How it resumes.** On input, on playback, or on a click.
- **One capture at a time.** While the standalone Audio Visualizer is loaded, the drawer shows "Spectrum is shown in Audio Visualizer" instead of opening a second capture.
- **No extra helper launches.** Media's own lease reloads skip the provider-resume launches (MEDIA-08).
- **VIS-04** (the volume readout) was already done in A1.

**C2, Idle pause (owner decision 2).**
- **The setting.** Global Settings → Refresh → Idle pause: Off / 5 / 10 / 30 min, **default Off**.
- **While paused:**
  - Title rows read "Paused (idle)", and the headline value is hidden rather than covered. Meters stop repainting and measures pause.
  - Media and the standalone Visualizer reload into a 1 s variant with no audio capture.
  - The RAM page-file host and the GPU telemetry host stop.
- **On resume (first keyboard or mouse input):** histories restart, and the helpers show Checking... for a few seconds.

**Measured 2026-10-23, 18:37-19:33.** Same setup as phase B (live preferences, hardware rendering, 3 interleaved trials). "Paused" is phase C with Idle pause on and every skin stood down, forced through the coordinator's test hooks in a staged copy. Reports: `*-live-pc-*`.

CPU in % of one core, median [min-max].

| Scenario | Phase B `08ecb9f` | Phase C `95331f9` | Phase C, paused |
| --- | ---: | ---: | ---: |
| **Six live skins** | 8.47 [7.78-8.96] | 8.50 [8.40-9.02] | **3.65** [3.63-4.12] |
| UI thread | 4.07 | 4.08 | **0.50** |
| Plugin threads | 3.42 | 3.69 | 3.13 |
| Rainmeter wakeups/s | 718 | 830 | 425 |
| Media (drawer open) | 1.89 | 1.89 | 0.20 |
| Visualizer | 1.84 | 1.74 | 0.20 |
| CPU | 3.80 | 4.28 | 2.74 |
| GPU | 1.61 | 1.74 | 0.94 |
| RAM | 3.19 | 2.99 | 2.74 |

**Reading it:**
- **With Idle pause off, phase C costs what phase B did** (8.5 against 8.5). C1's lease cannot act inside a 45 s isolated trial, because it needs 2 minutes of silence and 5 minutes away. Its gain is the audio engine's ~10% of a core once parked, taken from Wednesday's live A/B, not from this run.
- **Paused, the six skins fall by 57% and the UI thread by 88%.** What remains is mostly UsageMonitor's process-wide readers (3.1 points), which keep running by design. Unloading them while paused would mean reloading CPU, RAM and GPU each time: a "deep stand-down", listed as a later option.
- **Wakeups went the wrong way where the coordinator runs.** With the drawer open, Media's UI thread wakes about 72 more times a second than in phase B (101 → 173). With Idle pause on, CPU, GPU and RAM each wake about 30 more times a second while paused than while active. The design expected about 2.5 a second from the coordinator. The diagnosis follows below.

**Diagnosis and fix: C3, `e11f6a6`, merged as `4e1d711` on 2026-10-24.**

A follow-up agent isolated the cause with staged variants that each differed in one thing (3 trials each). An independent reviewer confirmed the cause in the Rainmeter source and re-measured. Two costs add up.

1. **The coordinator's window: about 57 of the 72 extra wakeups beside Media's open drawer, 31 beside CPU Meter, and 15 on its own.**
   - **Any hidden window does it.** A bare hidden 1x1 skin with no measures costs the same, whether hidden or shown, ticking or not, and with hardware or software rendering. Each further hidden window adds about as much again.
   - **Where the time goes.** Stack samples show a `CallNextHookEx` call from `dxgi.dll` inside `GetMessage`. It appears only once a second skin window exists, and it blocks on a win32k lock, most likely the session's USER lock, two to three times per message. That is why it scales with the other skins' message rate.
   - **It cannot be removed in Rainmeter 4.5.28** while the coordinator is a separate config.
   - **This machine makes it worse.** TextInputHost running away at about 90% of a core is the probable lock holder; that is not proven.
   - **Update 2026-10-25:** after TextInputHost was ended and the PC restarted, the window cost fell to about 2 wakeups/s beside Media. See [the after re-measure](#display-dropouts-and-the-kernel-memory-leak-2026-102425).
2. **The SysInfo reading: 13-15 wakeups/s.** The fix reads it only when a reading could change the state: about once a minute while you are at the computer. It still reads every 2 s while you are away or skins are paused, so input is seen within one tick.

**Result.** UI-thread wakeups/s from the reviewer's clean re-measure:

| Scenario | Before the fix | After | Without the coordinator | A bare hidden window |
| --- | ---: | ---: | ---: | ---: |
| Media, drawer open | 174 | 160 | 104 | 161 |
| CPU Meter, Idle pause on | 92 | 78 | 47 | — |

CPU time is unchanged within noise.

**Open options, not built:**
- **A lazy coordinator for the drawer.** It would join only after 2 minutes of drawer silence, or while parked. On the degraded machine that saved about 57 wakeups/s while music played; after the 2026-10-25 restart the window costs about 2, so the gain is now small, and it still needs a protocol change.
- **Read IDLE_TIME inside Network when Network is loaded.** Network already reads the interface table every tick, so the reading would cost nothing extra there.
- **Restart TextInputHost and re-measure: done 2026-10-25.** The per-window cost fell from about 60 to about 2 wakeups/s beside Media.

**Suite-wide lesson.** Every extra Rainmeter window, including a Settings window left open and Media's Queue or Setup, adds this per-message hook call. Weigh that before splitting the UI into more configs. On a freshly restarted machine the cost was about 2 wakeups/s per hidden window, so it matters mainly when the machine is in a bad state.

**Minor review notes:**
- **A rare tick-token collision** is possible on a quick double refresh after 24.8 days of uptime.
- **The re-armed tick drifts a few milliseconds per tick,** so the heartbeat comes about every 60.5 s.
- **Unexplained RAM double hosts.** Two of 5 combined native runs of the fixed code started two RAM hosts, both during display re-detection, against 0 of 2 runs at the base. The cause was not found.

**Owner choices the build made (the behaviour-preserving option, or one the design required):**
- **A new hidden config.** `Parallax\Idle` appears in Rainmeter's Manage list (not as a Welcome row) whenever the drawer is open or Idle pause is on.
- **Idle counts keyboard and mouse only.** Watching a video or playing with a gamepad counts as idle. That matters only for Idle pause, which is off by default; the drawer additionally needs silence and no player reporting Playing.
- **Media pauses on input idleness even while music plays,** when Idle pause is on.
- **The standalone Audio Visualizer has no silence lease.** Decision 1 named the drawer. It does stand down under Idle pause.
- **Chronometer hides its clock face while paused,** because a frozen time reads as current.
- **Some background work keeps running while paused:** UsageMonitor's readers, Network's interface polling, and Media's Source and Queue helpers.
- **Resume costs a little:** about 1 s of UI-thread work with all nine skins loaded, plus one PowerShell start and compile for each of the RAM and GPU hosts.

**Known issue, not fixed: a helper-launch kill race (only with Idle pause on).**
- **What happens.** If a stand-down lands within milliseconds of a RAM or GPU helper launch, RunCommand logs "Error 102: Program not running" and the launch carries on.
- **What it costs.** Nobody renews the stranded host's lease, so it exits when the lease lapses, about 15 s later.
- **Why it is open.** Each clean fix needs a design decision; the options are written up in `docs/modules/RAM.md` and `docs/modules/GPU.md`.

**Checks on the merged tree:**
- `Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors`: 24 configs, 122 files, 0 errors, 0 warnings.
- `Test-ParallaxVariants.ps1`: 9 variant sets, 8,449 static bang targets resolved.
- `test_idle_freeze_contract.py`: 10 tests.
- `Test-RepaintRule`: 50 assertions. `Test-PackagingTools`: passed.
- The builders' native runs (coordinator, capture lease, stand-down across all skins, hover and headline matrices) passed in isolated instances.

**Not verified:**
- **Real input.** Transitions were driven by a test idle file, not physical keyboard and mouse input.
- **Real WebNowPlaying** playback.
- **Sleep and resume, and graceful-exit paths,** natively.
- **The audio engine stopping on this machine after a park.** Only the drawer's own render session was seen disappearing.
- **Behaviour after a real release install** on the live profile.

## Step 3 result (2026-10-24): are the gains additive?

**What was measured.** One build matrix for the phase A packages.
- **Builds:** baseline `916c9ab` and all `dfe55b8`. For each of A1, A2, A3, A4 and A6, one plus build (the package alone on the baseline) and one minus build (the package removed from all).
- **A5 is counted as zero.** It acts only when settings are clicked.
- **Setup:** live preferences, hardware rendering, 5 rounds with rotated order, a 60 s window after a 15 s settle, 60 invocations, finished at 03:10.
- **The rule, declared before measuring:**
  - G is the combined gain: cost at baseline minus cost with all fixes.
  - gₖ is package k's gain added alone to the baseline; mₖ is its gain measured by removing it from all.
  - I = G − Σgₖ is the interaction. It counts as synergistic or antagonistic when beyond 2s, where s is the pooled sample standard deviation of the trials.
- **Analysis:** `build/perf-matrix/s3-pkg-live/analysis.md`, with every trial in `analysis.json`.

**Six live skins.** % of one core, medians of 5 trials.

| Package | What it fixed | g, alone on the baseline | m, inside all |
| --- | --- | ---: | ---: |
| A1 | Media and Visualizer repaint cadence | 9.38 | 7.91 |
| A2 | Media Source helper (live only) | 1.55 | −0.23 |
| A3 | CPU Meter | 1.49 | 0.87 |
| A4 | GPU Meter | 5.40 | 2.39 |
| A6 | RAM, Disk, Network | 3.28 | 0.47 |
| **Sum** |  | **21.09** | **11.41** |

**The combined gain is G = 12.68** (21.77 → 9.09, −58%). I = −8.41 against 2s = 2.73, so by the declared rule **the gains are antagonistic**: they overlap.
- **Each package saves more alone than together.** Added alone to the original build, each saves more than it does once the others are in place. The gap is largest for GPU (5.4 alone, 2.4 together) and the small modules (3.3 against 0.5).
- **Wakeups overlap even more.** Rainmeter's wakeups fall by 260/s in total, but the packages alone add up to 733/s. Inside all, removing any single package changes wakeups by almost nothing (Σm ≈ 0).
- **The split by thread is mixed.** By medians, UI-thread, plugin-thread and helper time are each additive. By means, the UI thread is also sub-additive (I = −4.35).

**How robust the classification is:**
- **Consistent across statistics and rounds.** Means give the same verdict as medians (I = −8.06). Four of the 5 rounds have I between −9 and −17; one has +5.5.
- **The noise floor of a single g is about 1-1.5 points.** A2, which cannot change anything in an isolated profile, reads 1.55.
- **The rule has a built-in weakness.** It subtracts the baseline once per package, so the baseline's noise counts five times, and the 2s threshold does not scale for that. The rule was declared beforehand and is kept. The size of the overlap (about 8 points, against a per-g noise of about 1.5) is well beyond what that weakness explains.
- **Inside all, the marginal gains add up.** G − Σm = 1.27, within 2s. Once the others are in place, each package's remaining gain adds up to the whole.

**Media alone is additive.** G = 8.22, Σg = 7.62, I = 0.60 against 2s = 1.58. A1 accounts for all of it: 8.14 alone, 9.43 inside all. The wakeup and p95 metrics read "synergistic" by medians. That comes from two-level wakeup readings (about 400 or about 440/s from run to run) in the builds that A1 does not touch; by means it is additive (I = 11 against 2s = 41).

**Why the gains overlap: a hypothesis, consistent with C3's finding.**
- Every skin shares one Rainmeter UI thread.
- On this machine, each window message that thread handles waits on a contended win32k lock, once per extra skin window.
- The original build keeps that thread far busier, so removing any one skin's work also shortens every other skin's waits. Alone, a package gets credit for both.
- A cost that grows faster than the load behaves exactly like this.
- This is not proven. The 2026-10-25 re-measure supports it: after a restart the six skins' UI thread woke about 310 times a second instead of 554, and the per-window cost fell from about 60 to 2. Step 3 itself was not re-run, so how much of the overlap remains is unknown.

**The protocol's expected interactions:**
- **A1 with C1 (expected synergistic):** not testable here; C1 needs minutes of silence and absence.
- **A3 with B2 (expected antagonistic):** phase B was not in the matrix.
- **The surprise:** antagonism where none was expected, between A1 and the GPU and small-module packages, through the shared thread.

**Not in the matrix:**
- **Phase B.** At the defaults only B1's wakeup cut is visible, and it was measured directly.
- **Phase C.** Its gains need idle minutes, and the paused benchmark above measures C2.
- **Each package's single fixes,** except A1 (below).

**Inside A1: the two halves of Media's fix are synergistic.** A second matrix (`build/perf-matrix/s3-a1-live`) split A1 into its two units:
- **U1 = A1-1, A1-2, A1-5, A1-6:** Media's meters held to the provider cadence, no per-tick geometry formulas, the volume read once a second, and the Title animation setting.
- **U2 = A1-3, A1-4:** the hidden spectrum mask parked, and the output row repainted only on change.

The setup was the same (5 rounds, 60 s, live preferences, hardware rendering). With two units, "baseline + U1" and "all − U2" are the same tree, as are "baseline + U2" and "all − U1". Their measured differences (0.04-0.85 points) show the noise floor directly.

| Unit | Media (drawer open): alone / inside A1 | Audio Visualizer: alone / inside A1 |
| --- | ---: | ---: |
| U1, Media cadence | 4.27 / 7.42 | −0.03 / 0.52 |
| U2, spectrum repaint | 0.21 / 3.60 | 2.17 / 3.25 |
| **G (all of A1)** | **8.48** (Σg 4.48, I = +4.00, 2s = 1.48: **synergistic**) | **2.74** (Σg 2.14, I = +0.59, 2s = 0.72: additive) |

**For Media, neither half helps much alone, and together they remove 82% of its cost.**
- **Why: Rainmeter 4.5 repaints the whole window whenever any meter is due** (T1).
- **U1 alone** stops Media's own meters, but the drawer's spectrum meters still fire 20 times a second, so the window still repaints at 20 Hz.
- **U2 alone** quiets the spectrum, but Media's own meters still fire at 20 Hz.
- **Only both together** stop the 20 Hz repaint.
- **Wakeups show it most clearly:** −5 and −33/s for each half alone, 225/s together.

This is the mechanism the protocol predicted for A1 with C1 (the parked capture removes the rest of the drawer's work). It is confirmed here, one level down. In the standalone Audio Visualizer, U2 does almost all the work and the CPU gain is additive.

**Answer to the step-3 question.** Phase A's suite-wide gain is not one class:
- **Inside Media it is synergistic:** fixes that each remove one of several 20 Hz repaint triggers only pay off together.
- **Across the six live skins it is antagonistic:** each package removes load from one shared, contended UI thread, so their gains overlap. Together they still deliver 58% (this matrix) to 63% (phase B benchmark).
- **Within Audio Visualizer it is additive.**

## Overnight trace (2026-10-22/23): what drives the night-time fan

**Setup.**
- `Trace-ParallaxLive.ps1` ran from 23:31:53 to 08:31:50 at a 5 s interval, giving 6,275 samples (`build/perf-trace/20261022T233145-overnight-baseline*`).
- The live skin was the installed build, from before phase A. The drawer was open.
- HWiNFO's sensors window was open, so CPU temperatures and both fan speeds are live.
- PowerToys Awake was on.
- The screens were off all night except two 5-minute wakes, at 23:44 and 03:49. Both were logged as mouse input and ended by the idle timeout.
- Kernel-Power logged no other screen transitions. So the monitors' "half-wakes" the owner saw were not Windows waking the display.

**The night splits into three windows:**
- **W1, 23:31-03:58:** my phase B builders were running, and so was a stuck Adobe Desktop Service. One of its threads was busy-waiting at 13,000 context switches/s, 83% in the kernel, with no I/O. The Creative Cloud tree was ended at 03:58:40, logged in `build/perf-trace/overnight-events.csv`.
- **W2, 03:58-04:50:** the builders were finishing; Adobe was gone.
- **W3, 04:50-08:31:** nothing of mine and no Adobe. This is the clean overnight record.

Screen-off figures. CPU in % of one core; "busy" is % of all cores.

| Window | Busy | CPU °C mean / p95 / max | CPU fan RPM mean / p95 / max | Board fan mean | Parallax total | Rainmeter main | audiodg | Largest others |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| W1 (249 min) | 30.1% | 75.5 / 83 / 92 | 3,371 / 3,794 / 4,032 | 1,869 | 30.7 | 15.1 | 8.7 | Adobe 60, TextInputHost 34, Defender 28, my PowerShell 22 |
| W2 (50 min) | 24.9% | 71.3 / 82 / 88 | 3,090 / 3,629 / 4,069 | 1,618 | 27.9 | 13.5 | 8.0 | TextInputHost 61, explorer 30, NVIDIA display 25 |
| **W3 (214 min)** | **22.5%** | **68.7 / 79 / 86** | **2,872 / 3,354 / 3,938** | **1,448** | **26.6** | **12.3** | **7.7** | TextInputHost 60, explorer 30, NVIDIA display 21, SearchIndexer 19 |

**The regular fan peaks (symptom c) are not Parallax.**
- **How often:** in W3 the CPU fan crossed its 90th percentile (3,292 RPM) upward 173 times in 3.7 hours. The median gap between peaks was 52 s; half the gaps fell between 32 and 104 s.
- **What rises into a peak:** in the 15 s leading into a peak, explorer rose from 30% to 67% of a core and NVIDIA's display container from 21% to 50%. dwm and Steam's web helper roughly doubled.
- **What does not:** Parallax and Rainmeter's UI thread are unchanged into a peak.
- **Correlation with the fan:** 0.02 for Parallax and −0.02 for Rainmeter's main thread, against 0.71 for total machine load and 0.54 for CPU temperature.

Explorer, the NVIDIA display container and dwm bursting together is how display re-detection work shows up. With the screens off, that is consistent with the monitors cycling their inputs or DisplayPort links, which matches the one-monitor-then-the-other half-wakes the owner saw. It is consistent, not proven. The test is to turn off the monitors' Auto Source Switch (and DisplayPort deep sleep, if needed) and trace another night. **Update 2026-10-25:** confirmed and fixed; Auto Source Switch was not the cause. See [Display dropouts and the kernel memory leak](#display-dropouts-and-the-kernel-memory-leak-2026-102425).

**What Parallax contributes is a steady floor, not the peaks.**
- **Size:** about 27% of a core all night, about a quarter of the steady load. That is 12% on Rainmeter's UI thread, 9% in helpers and 8% in audiodg, which the open drawer keeps running.
- **Phase A and B:** these reduce that floor; the next section measures by how much.
- **C1:** releases audiodg after silence.
- **C2:** opt-in; would stop Parallax entirely while idle.

**Other findings:**
- **TextInputHost**, the Windows touch-keyboard, emoji and input-method host, is the largest steady consumer: about 60% of a core from 04:00 onwards, up from 34% earlier in the night. Nobody was typing, so this is not normal. It is the owner's call whether to end it; Windows restarts it on demand.
- **Search indexing** climbed from 5% to 22% of a core over the night.

## Display dropouts and the kernel memory leak (2026-10-24/25)

**Symptom.** The machine slowed over days, and only a restart helped. At 2.9 days uptime (2026-10-24):
- kernel paged pool was 13.8 GB and nonpaged 1.3 GB;
- commit was 48.3 of 51.8 GB, with 2.8 GB of RAM free;
- Intel's igfxEM held 147,488 handles and NVIDIA's display container 35,431.

**Method.** Everything was read-only except the steps marked as owner-approved.
- **Leak logger.** `build/leak-watch/Watch-Leak.ps1` is a diagnostic, not part of Parallax. Every 10 min it records pool, commit and handle samples. It also logs each display-settings change with the screen layout, and screen on/off comes from Kernel-Power event 566.
- **Pool by tag.** `NtQuerySystemInformation` gave pool usage per tag (class 22) and per large allocation (class 66).
- **GDI objects per process.** `GetGuiResources`, run elevated once with the owner's OK.
- **The scripts** are in the session scratchpad, not the repo.

**Finding 1: the left monitor keeps dropping its DisplayPort link.**
- **How often.** The left monitor (Samsung U32J59x, `DISPLAY2`) disappeared from Windows' screen list and came back 1,383 times in the 20 hours after the 2026-10-24 restart. That is 70-100 an hour in bursts, each outage about 1.5 s.
- **When.** Only while Windows had blanked the screens: the first drop came 10-45 s after blanking, then pairs about 8 s apart, repeating every 30-80 s.
- **Invisible.** The backlight stays off throughout, so it can only be seen in the logs.
- **The fan.** This is the display re-detection behind the overnight fan peaks above.

**Finding 2: each reconnect leaks one kernel copy of every Parallax skin's image.**
- **Growth.** Paged pool grew 150-220 MB an hour while the drops continued, from 974 MB after boot to 4.5 GB.
- **Which tag.** Almost all of the growth is pool tag `Gpbm`, GDI bitmap memory in `win32kbase.sys`/`win32kfull.sys`: 3.1 GB in about 11,600 large allocations.
- **Owned by no process.** Every process in the session together held only 3,713 GDI objects.
- **The sizes give it away.** Six sizes recur about 1,300-1,366 times each, about once per reconnect. Each matches one of the six Parallax skins on that monitor, as `width × height × 4` bytes rounded up to whole 4 KB pages, at the size Rainmeter draws it.
- **Why ⅔.** Rainmeter 4.5.28 runs DPI-unaware, and both monitors are 3840×2160 at 150%, so Windows stretches each skin 1.5×. The leaked copies are the unstretched images.

| Skin | On screen (px) | Rainmeter draws (px) | Bytes, page-rounded | Leaked allocations of that size |
| --- | --- | --- | ---: | ---: |
| Media | 684×474 | 456×316 | 577,536 | 1,362 |
| CPU | 342×837 | 228×558 | 512,000 | 1,366 |
| GPU | 342×705 | 228×470 | 430,080 | 1,345 |
| RAM | 342×509 | 228×339 | 311,296 | 1,308 |
| IO | 342×398 | 228×265 | 245,760 | 1,301 |
| Chronometer | 342×240 | 228×160 | 147,456 | 1,308 |

- **Who holds it.** The copies are allocated by Windows' kernel graphics code when it rebuilds the display layout. They are never freed and belong to no process, so ending a process cannot release them; only a restart does.
  - **Ending igfxEM** (owner-approved, 2026-10-25 13:02:15) freed 5 MB. igfxEM does leak about 29 handles per reconnect, and NVIDIA's container about 6, but those are side leaks.
  - **Ending Razer's app** (owner-approved, 13:12:50) freed its 10,000 GDI objects, the per-process cap, but none of the `Gpbm` memory.
- **Parallax's part.** Parallax does not cause the dropouts. Its windows are what gets copied, so its size and skin count set the cost per dropout. The leak is a Windows defect; there is nothing to change in the skins.

**Finding 3: the fix.** Each test ran the screens dark with a 1-minute timeout and counted dropouts with the logger.

| Left monitor | Dark | Dropouts |
| --- | --- | ---: |
| DP 1.2, input source changed from Auto to Manual | 6 min | 17 |
| DP 1.1 (NVIDIA kept 4K 60 Hz by switching to YCbCr 4:2:2, limited range) | 4 min | 2, then none |
| DP 1.2, straight after the switch back (a power-cycle) | 5 min | 11 |
| **DP 1.2, both DisplayPort cables swapped end to end, same GPU ports** | **24¾ min** | **0** |

- **The leak stopped.** During the last test paged pool stayed at 4,693-4,695 MB. The only event was one resync 2 s after the screens woke.
- **Likely cause.** The old left cable did not fail on the right monitor either, so a poorly seated plug, or a cable that is marginal at DP 1.2 speed with the left monitor, is the likely cause.
- **Still to confirm:** a full night with the logger.

**TextInputHost and the after re-measure.**
- **What happened.** It had run at about 85-90% of a core since 2026-10-21 17:54 (97,205 CPU-seconds). It was ended with the owner's OK on 2026-10-24 at 16:14:27, and Windows restarted it as a quiet instance.
- **The re-measure.** Both runs used the same three staged copies of the C3 merge (`5474212`): with the coordinator, without it, and with a bare hidden 1x1 window in its place. They used the live preferences and hardware rendering, with 3 interleaved trials per variant. No run saw a display event.
  - **"Before"** ran on 2026-10-24 from 15:59 to 16:14, with TextInputHost running away and 2.9 days of leaked kernel memory (paged pool about 13.8 GB).
  - **"After"** ran on 2026-10-25 from 18:25 to 18:39: two hours after a restart, with TextInputHost quiet and the cables swapped.

| UI-thread wakeups/s, median of 3 | Before, with coordinator | Before, without | After, with coordinator | After, without |
| --- | ---: | ---: | ---: | ---: |
| Media alone | 169 | 108 | 88 | 86 |
| Six skins | 663 | 554 | 298 | 310 |

- **The coordinator's window cost is gone.**
  - Beside Media it fell from +60.5 to +2.1 wakeups/s; a bare hidden window went from +55.2 to +1.7.
  - Across the six skins it went from +109 to -12, which is noise.
- **Everything else got cheaper too.**
  - Without the coordinator, Media's UI thread fell from 108 to 86 wakeups/s and the six skins' from 554 to 310.
  - Load times fell from about 3.6 s to 0.7 s for Media and from 7.1 s to 1.5 s for the six skins.
  - Total CPU moved within noise: the six skins without the coordinator went from 8.7% to 8.8% of a core.
- **The cause was the machine's state, not Parallax.** The extra cost went away with the TextInputHost kill and the restart. This run cannot separate the two. The kernel state before the restart was about 13.8 GB of paged pool (mostly leaked GDI bitmaps), with igfxEM holding 147,488 handles.
- **What it changes.**
  - The lazy coordinator (a C3 option) would now save about 2 wakeups/s, not 57.
  - The Step 3 overlap was measured in the old state and may be smaller now; it was not re-run.
- **Live Rainmeter, for context only.** A 30 s read-only sample, not like-for-like, because the drawer and Spotify states were not recorded: the UI thread went from 741 to 360 wakeups/s, and the process from 18.5% to 10.6% of a core.
- **Files.** The logs and summary are in `build/wakeup-recheck/` (git-ignored); the reports are `build/perf-benchmark/*-live-wr-*.json`.

**Not verified.**
- Whether skins on the steady monitor, or a DPI-aware Rainmeter, would also leak per reconnect.
- How much of the fan's night-time pattern remains after the fix. The overnight trace in the evidence protocol should be re-run.

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

**Measured for decision 3 (Media's idle 50 ms tick).** Phase-A build, shipped defaults (drawer collapsed, nothing playing), hardware rendering, 3 interleaved trials. Reports `*-default-anim20-t*` and `*-default-anim0-t*`.

| Title animation | Media total | UI thread | Plugin threads | UI-thread wakeups/s | Rainmeter wakeups/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 20 fps (default) | 0.35 [0.34-0.45] | 0.20 | 0.15 | 99 | 173 |
| Off | 0.30 [0.30-0.35] | 0.25 | 0.05 | 46 | 118 |

- **The idle tick costs about 0.05% of a core,** inside the trial spread, plus about 53 wakeups/s.
- **Media idle cost about 9.9% before phase A** (default preferences, software rendering); it is now 0.35%.
- **Removing the remaining tick** would need ActionTimer or a reload on play/pause, which is more code for a negligible CPU gain.
- **Owner decision (2026-10-22): leave the tick as it is.** No ActionTimer pulse. The owner can set Title animation to Off to halve those wakeups, and C2's idle stand-down covers nights.

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
