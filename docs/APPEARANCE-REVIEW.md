# Parallax appearance revision 2

This is a historical appearance snapshot. Later Global Settings fields, rounding and the RGB/HSV/Lab color picker are documented in [SETTINGS-REVIEW.md](SETTINGS-REVIEW.md). Module reports describe subsequent CPU, Chronometer, Network and Media additions; the utility screenshot sheet below predates those additions.

The suite now uses the dense ModernGadgets-inspired starting point requested on 2026-09-11. Each utility was restyled within its dedicated task: compact icon/title headers, aligned readings, hairline bars, neutral black/gray surfaces, small controls, and bordered/grid histories where applicable. IBM Plex Sans is bundled under SIL OFL 1.1 with the user's approval. Parallax's meters/icons are original implementations.

Default single panels paint 200 px inside a 208 px window. Double panels paint 408 px inside a 416 px window, matching two single windows including the gap. Five width presets, five scales, global palette and per-module overrides remain available.

| Utility | Painted height before | Painted height now |
| --- | ---: | ---: |
| Chronometer | 530 | 286 |
| CPU | 388 | 352 |
| RAM | 300 | 170 |
| GPU | 328 | 184 |
| Drive I/O | 300 | 174 |
| Network | 364 | 236 |
| Media | 332 | 162 |
| Visualizer | 232 | 146 |
| Settings | 560 | 336 |

The numerical reductions describe logical panel size at this snapshot. Module reports document retained behavior and test coverage. The Media queue was unimplemented when these initial captures were made; its later source/native checks and initial live API acceptance are recorded in `docs/modules/Media.md`.

The user's CPU follow-up adds a `CPU Meter` header and a compact processor information panel, increasing its initial revision 2 height from 288 to 352 logical pixels. Processor model comes from a static native Registry measure; physical/logical totals use Rainmeter's bundled RunCommand plugin for one hidden PowerShell CIM query on load/refresh, with a 10-second timeout and explicit unavailable states. There is no recurring process polling. HWiNFO is not required for these fields. See `docs/modules/CPU.md` for topology and validation limits.

## Native visual evidence

`tools/Preview-Parallax.ps1` captured all nine configs at default 200/100%/single width, narrow 180/75%/single width, and 200/100%/double width (Settings stays double). All three snapshots reported no Rainmeter errors. These are real isolated Rainmeter windows using actual measures and available/missing provider states. No live desktop screenshot or synthetic telemetry was used.

- Default source captures: `build/Parallax-visual-preview-20260911T175154965Z-fd8438a6/captures/`.
- Narrow source captures: `build/Parallax-visual-preview-20260911T175255277Z-631e1424/captures/`.
- Double-width source captures, including Drive I/O counters: `build/Parallax-visual-preview-20260911T175255162Z-2c85b92a/captures/`.
- Unscaled review sheet: `build/appearance-review-v2/Parallax.png` (a layout of individual captures, with a source/position manifest alongside it).

The first pixel review found one narrow Network header control that ellipsized its width label. The module owner widened its text box and reallocated the adjacent controls. Root inspected the corrected narrow capture (`build/Parallax-visual-preview-20260911T175547864Z-cb3a13f9/captures/Network.png`) and default capture (`build/Parallax-visual-preview-20260911T175619222Z-68c36658/captures/Network.png`): Network, bits and 1x now render fully. Both had zero Rainmeter errors. The review sheet uses this corrected default Network capture alongside the other default captures. Other tested views showed readable controls, aligned rows and no visible overlap. Long adapter names intentionally truncate and retain full text in tooltips.

The original revision 2 global settings passed 188 Lua/native assertions and all 100 preset geometry combinations. The subsequent Theme dropdown passes 229 Lua/native assertions and the same 100 combinations. Per-module tests cover additional widths, scales, state transitions and glyph bounds; see `docs/modules/`. Native screenshots are visual smoke evidence, not sustained performance, provider-accuracy, mixed-monitor DPI, authentication or distribution acceptance.

The subsequent CPU metadata update passed the module owner's 50 geometry cases. Root inspected its new default capture (`build/Parallax-visual-preview-20260911T180143774Z-f78f39d0/captures/CPU.png`) and narrow capture (`build/Parallax-visual-preview-20260911T180214845Z-9bb921c7/captures/CPU.png`); the processor name, physical/logical counts and controls render readably without visible overlap.

The user's next CPU refinement replaces the always-visible Edit text with a settings gear that appears over the top-right total while hovering the utility. Leaving restores the latest total. Native mouse actions handle visibility without changing telemetry or panel dimensions. The owner reran 50 geometry cases and an isolated action harness across normal metric updates. Root inspected `build/Parallax-visual-preview-20260911T180901400Z-6824a1ab/CPU-hover.png` and `CPU-leave.png`. The review sheet uses the latter normal-state capture.

Later module work is newer than this screenshot sheet: Chronometer adds a hover gear and independent `Chronometer/Settings/Settings.ini` with `Modules/Chronometer/Settings.lua`. Its owner reports 53 Lua checks, 1,844 native frontend assertions and 388 native settings lifecycle assertions, including real writes and retention of an unrelated running timer's deadline. Its painted height remains 286. The screenshot sheet predates this menu/clock-spacing change; pointer hit testing, new pixel captures and mixed DPI remain separate checks. CPU is also developing dedicated settings and an expanded all-core view after another user request; its latest module report is authoritative for that ongoing work.

Global Settings now replaces the four surface choices with a Theme dropdown containing only Default. It applies 26 shared appearance values at once, leaving size/cadence and module overrides in place. `tools/tests/Test-ThemeDropdown.ps1` passed native source-action checks for opening, toggling, outside dismissal, mouse leave and selection, including real isolated persistence and exactly one refresh. Root inspected default open/closed and narrow open captures under `build/theme-dropdown-test-75dc27fed5fc45baa4d64edc802994c7/{default,narrow}/captures/`. Default bounds remain 416 x 344; narrow 180/75% bounds remain 282 x 258. These tests exercise the actual action strings in Rainmeter rather than system cursor hit testing; mixed Windows DPI remains unverified. The captures retain the test's Economy cadence to demonstrate that applying Default leaves sampling choices intact.

The source reference is the [ModernGadgets preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png) and [shared stylesheet](https://github.com/raiguard/ModernGadgets/blob/master/Skins/ModernGadgets/%40Resources/StyleSheet.inc). Font source and terms are included in `Skins/Parallax/@Resources/Licenses/`.

## Clean staging

Last complete revision 2 source stage before the CPU and Theme follow-ups: `build/Parallax-0.1.0-dev-20260911T175823877Z-d69a28f7/`. It contains 59 files, including four unmodified IBM Plex fonts and license/notice files. All nine User include paths are listed for upgrade preservation. The staged 11 configs and 41 INI/include files passed with zero errors/warnings. Test and preview instrumentation is excluded. A new complete stage must include the CPU/Theme refinements and the separately developing Spotify queue once its helper validation and precise packaging allowlist are complete. Creating and acceptance-testing an actual `.rmskin` remains a release milestone.

The attempted CPU restage exposed a race with temporary files being removed by concurrent module tests. Validator and staging now prune excluded developer/hidden/runtime/cache directories before traversing them. A regression staged all required configs while a realistic Chronometer QA runtime file was locked; required missing/malformed production includes still fail. Current source static validation after the Theme change passes 12 configs/43 INI/includes with zero errors/warnings; this does not establish completion of the new queue provider.
