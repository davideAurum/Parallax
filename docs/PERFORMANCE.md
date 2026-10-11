# Performance pass

Checked 2026-09-13 against Rainmeter 4.5.26.3894 on Windows. This pass focused on frame pacing, redundant paint work, and subprocess launch behavior. It did not change the user's live Rainmeter profile or install dependencies.

## Findings and corrections

- Chronometer, its event row, the GPU overview, RAM process/PAGE views, and Media were explicitly updating meter groups and calling `!Redraw` from their normal periodic Lua `Update()` paths. Rainmeter already performs the regular meter update and redraw at the end of each skin cycle, so these calls could create extra partial frames in the same tick. Periodic paths now only update cached options and defer painting to the normal cycle. Event-driven timer actions, settings redisplay, and Media hover feedback retain immediate meter updates and redraws.
- Media's Source and Queue Start/Stop/Restart/Disconnect buttons directly launched `powershell.exe`. Even with `-WindowStyle Hidden`, a direct shell action can briefly create a console window. These operations now use dormant RunCommand measures with `State=Hide`, fixed working directories, bounded 15-second timeouts, noninteractive hidden parameters, fixed action allowlists, and overlap rejection. Queue polling remains one persistent worker; this does not add polling or a process per sample.
- Spotify queue **Sign in** deliberately remains a visible `-NoExit` PowerShell flow because it presents setup instructions and opens the authorization browser. The Chronometer event editor and numeric field editors are also deliberate one-shot UI processes. Persistent CPU/RAM/GPU/Media helpers remain hidden and are not relaunched per sample.
- The suite validator now rejects PowerShell RunCommand measures without `State=Hide` and rejects direct one-shot PowerShell actions except the explicitly visible Media Connect flow. This makes console-flash regressions fail the normal static check.
- Rainmeter creates a native tooltip control for each tooltip-bearing meter and revisits it on every skin update, including hidden meters. The fixed IO A-Z bank carried 78 redundant read/write glyph and legend tooltips, CPU's shared sensor style inherited one tooltip onto all 128 temperature/VID cells, and the 20 FPS Visualizer carried five separate diagnostic tooltips. IO now leaves its hidden placeholders tooltip-free and keeps the detailed controller-supplied tips on selected drives. CPU starts its sensor tooltip bank inactive, passes the current visible-row count into `Sensors.lua`, and clears cells as they leave the page. Visualizer consolidates volume, endpoint, scale and unavailable-state help into its device tooltip, retaining only that tooltip and the actionable settings-gear tooltip.
- Static validation now protects those three contracts so hidden tooltip fan-out fails the suite check. Settings utility tooltips remain because those configs are loaded only while their panels are open and their controls require descriptive hover help.
- **2026-09-19 follow-up:** a suite-wide sweep found the same fan-out had recurred on an unguarded sibling style and that 307 tooltip strings were duplicated across adjacent meters. 86 redundant declarations were removed and the `CPUStyleRow*` validator rule generalised. Measured cost is 1 USER handle and ~6 GDI objects per tooltip, created eagerly rather than on hover. See [TOOLTIP-AUDIT.md](TOOLTIP-AUDIT.md) for the A/B benchmark and the full inventory.

## Measurements

The full default suite was staged into a private, offscreen Rainmeter profile and sampled without touching the live profile. CPU percentages below are fractions of one logical core, not whole-machine CPU.

| Sample | CPU | Working set | Threads | Handles |
| --- | ---: | ---: | ---: | ---: |
| Initial full-suite 5-second sample | 15.62% | 114.61 MB | 30 | 822 |
| Post-change full-suite 5-second sample | 12.50% | 111.61 MB | 30 | 814 |
| Post-change repeat, three 4-second windows | 15.62% average (12.89–18.36%) | 112.25 MB | 30 | 822 |
| Final staged run after 30-second settle, three 10-second windows | 16.56% average (13.59–18.75%) | 109.40 MB | 27 | 757 |

The repeated samples show that CPU variance is larger than the observed before/after difference, so this pass does **not** claim a proven reduction in average CPU. It does remove redundant forced frame boundaries and direct click-launched hidden consoles, which target the reported skipping and terminal flashes more directly.

The initial isolation split identified the two expected continuous costs: Visualizer was about 5.94% of one core at its default 50 ms / 20 FPS cadence, and CPU was about 6.56% with per-thread history enabled. GPU was about 0.62%; the other utilities were comparatively light. The existing Economy refresh profile changes eligible metrics to 2 seconds, sensors to 4 seconds, capacity to 60 seconds, and Visualizer to 100 ms / 10 FPS. UsageMonitor workers and Network's native banks have independent cadences, so the profile is not a universal throttle. Unload optional CPU process/thread views, Visualizer, or provider-backed utilities when they are not needed to remove their consumers. Media's spectrum drawer (2026-10-10) adds a comparable AudioLevel capture, FFT and 24-path mask rebuild to Media only while the drawer is open, on Media's existing 50 ms tick, with a larger window to redraw (456×278 instead of 456×186 at default width and scale). As shipped it saturated Rainmeter's main thread; see [Spectrum drawer path cost](#spectrum-drawer-path-cost-2026-10-11) for the cause, the correction and its measurements. Collapsing the drawer removes the capture, and running it alongside the standalone Visualizer doubles the capture work.

The tooltip revision removes 78 direct IO placeholder declarations, the CPU style declaration inherited by 128 sensor cells, and five high-frequency Visualizer declarations. On this 12-thread machine, CPU now creates 24 sensor-cell tooltips instead of 128, a reduction of 104 native tooltip targets while preserving both temperature and VID help on every visible row. Visualizer's main panel has two tooltip-bearing meters instead of seven. This is a structural reduction in per-tick tooltip work; no statistically stable CPU percentage is claimed from the short process-wide samples.

The final nine-window preview rendered usable captures for Settings, Chronometer, CPU, RAM, GPU, IO, Network, Media Setup and Visualizer with zero Rainmeter errors or warnings. Evidence: `build/Parallax-visual-preview-20260913T195251806Z-966d3ed5/`. The final steady-state measurement restarted only that staged profile, settled for 30 seconds, sampled for 30 seconds, and stopped its owned process.

## Spectrum drawer path cost (2026-10-11)

After the spectrum drawer shipped (134f516), the live Rainmeter process with seven Parallax skins loaded and the drawer open spent 92% of one core on its main thread, which slowed every skin and Rainmeter's own UI. Media alone reproduced it in an isolated offscreen instance staged from the live skin copy (WebNowPlaying and RunCommand stubbed): 96% with the drawer open, about 10% collapsed.

**Cause.** The spectrum mask needs `DynamicVariables=1`, so on every update it re-reads its 24 `BandPath` options, re-expands every variable they name and re-resolves every `[Measure]` reference. Rainmeter stores `[Variables]` values pre-expanded, so each band's `Left`, `Width` and `Radius` already carry a full copy of the host's plot width. The standalone's width is an 86-character formula and its paths expand to about 8 KB each. In Media, `VisualizerPlotInnerWidth=(#MediaVisualizerPlotWidth#-2)` is a 7.4 KB geometry chain inlined about 36 times per path: about 271 KB per path, 6.5 MB of formula text parsed every 50 ms tick.

Bisection, Media only, main-thread share of one core:

| Variant | Main thread |
| --- | ---: |
| Shipped raw paths (live capture) | 96% |
| Width read from one Calc measure: text down 42× to 154 KB per update, ~1,250 `[Measure]` lookups | 49% |
| Width as a literal number | 22% |
| Mask not re-reading its paths (`DynamicVariables=0`) | 8.6% |
| AudioLevel stubbed, raw paths | 42.5% |
| Drawer collapsed | 8–10% |

Per-update cost followed both formula length and the number of section-variable references; the capture and FFT were a few percent.

**Correction.** `SpectrumPaths.lua` runs once per load (`UpdateDivider=-1`) in both hosts. It evaluates Spectrum.inc's own `VisualizerBandLeft/WidthN`, `VisualizerBarHeight` and `VisualizerBarRadiusPx` with Rainmeter's parser and rewrites the 24 `BandPath` options with those as literal numbers, so only each band's height stays dynamic. A zero radius cancels every corner term, so a bar becomes its four corners and reads its band measure twice instead of sixteen times. If any input fails to evaluate, the raw paths stay and draw the same bars at the old cost.

With a synthetic moving signal (bars drawn every tick; three 8-second windows after a 12-second settle): raw paths 88.8%, compiled square bars 9.3%, compiled 4 px rounded bars 11.4%, against the 8–10% collapsed baseline.

**Equivalence.** A native check in isolated Rainmeter pinned all 24 band measures to 15 values from −0.25 to 1.5 and had Rainmeter's parser evaluate every coordinate of the raw and compiled paths. Eight configurations: Media double and compact, Scale 0.75/1/1.25, radius 0/3/4/5/12 (including fractional caps), band gap 0–3, baseline gap 0/8/24, and the standalone at two of them. Each ran 360 cases with 0 mismatches, a maximum difference of 0 and no log errors. The square form omits the raw path's zero-length corner curves; its distinct vertices match exactly. `validate.mjs` now requires the once-per-load compile measure and limits the script to setting the mask's path options.

Limits: short process-wide samples, not a latency trace. The benchmark and equivalence scripts ran from a scratch directory and are not checked in. The standalone Visualizer's own before/after CPU, mixed DPI and long-run behaviour are unmeasured.

## Validation and limits

- `tools/Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors`: 22 configs, 84 INI/include files, zero errors and warnings.
- Chronometer: 88 Lua/native scenarios passed.
- Media: 503 Lua assertions, 4,347 lifecycle assertions, focused native settings layouts, and the updated hidden-control contract passed.
- GPU: 3,507 Lua assertions, native settings/provider smoke, and 450 driver lifecycle/ABI assertions passed.
- RAM: 97,497 source assertions and all 20 native cases passed after updating the validator for the event/periodic display split.
- IO and Network retained their complete controller/native checks; the final isolated full-suite preview logged no errors.
- Tooltip-focused validation passed the 60-case CPU sensor suite, IO's 328,925 source geometry/bank checks, the suite validator, and its packaging fixtures. A fresh isolated CPU/IO/Visualizer preview produced three usable captures with no Rainmeter errors at `build/Parallax-visual-preview-20260914T010520814Z-e27dd5b9`.

These are short steady-state samples, not a long-run latency trace. They do not establish mixed-DPI performance, counter-provider accuracy, hardware-specific driver cost, physical click delivery, or statistical CPU improvement. A future long-run profiler should record per-skin update duration and frame-lateness percentiles; Rainmeter's process-wide CPU alone cannot attribute brief stalls to a specific skin.
