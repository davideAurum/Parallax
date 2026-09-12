# Drive I/O module report

Status: appearance revision 2 plus main-drive header percentage and independent settings utility implemented, 2026-09-11. Drive I/O owns drives only; the dedicated Network utility owns NIC monitoring. Both variants have rendered in isolated Rainmeter 4.5.26.3894 with clean logs. This is a validated prototype appearance, not a release/performance certification.

## Delivered

- `Skins/Parallax/IO/IO.ini`: native capacity with an optional second drive; no network measures or UsageMonitor queries.

- `Skins/Parallax/IO/IO-Disk.ini`: alternate file in the same config, adding explicit disk read/write counters. Switching variants replaces the current IO skin.

- `@Resources/Modules/IO/Native.inc`, `Disk.inc`, `View.inc`, `IO.lua`: module-owned sources, presentation, and formatting. The controller reads existing measures; it launches no process, polls no external helper, makes no network request, and writes no runtime files.

- `Skins/Parallax/IO/Settings/Settings.ini`, `@Resources/Modules/IO/Settings.lua`, and `SettingsMeters.inc`: independent module settings utility, event-driven with `Update=-1`.
- `@Resources/User/IO.inc`: all supported module settings in `[Variables]`, including geometry and provider selection.
- `@Resources/Modules/IO/tests/check_geometry.py` and `ControllerSuite.lua`, `SettingsSuite.lua`, and `Run-SettingsSmoke.ps1`: development checks, excluded by packaging; no fixture telemetry is displayed in the real skin.

Both main entrypoints join `Group=Parallax|ParallaxIO`, include defaults/global user/module user/geometry/styles in the prescribed order, provide the suite-settings context action, and use transparent bounds and painted-panel styles. Every actual meter declares its type; styles do not draw independently. The default painted panel is 200 x 174 with a 208 x 182 window. `Columns=2` widens the same instrument to the shared two-column geometry. Fixed string widths clip long labels; hover tooltips expose capacity details and provider scope.

No shared, root, Network, or other-module files were edited. No ModernGadgets code or assets were copied; all module code is original. No dependencies were installed, binaries downloaded, live Rainmeter configuration changed, or releases published.

## Configuration and controls

Load `Parallax\IO`, `IO.ini` through Rainmeter after the suite is installed. The top-right header shows the main drive's **used percentage**, rounded to a whole percent; its tooltip gives one decimal place and the configured drive. The main drive defaults to C:. Invalid capacity displays `--`, while a completely free or full drive correctly displays `0%` or `100%`.

Hover anywhere over Drive I/O to replace the percentage with the CPU-style gear. Leaving the skin restores the percentage. Click the gear or right-click **Drive I/O settings** to open `Parallax\IO\Settings`, `Settings.ini`, a separate two-column utility. Its close control unloads only that settings window. Both IO variants share this behavior.

The settings panel offers main/second drive-letter arrows; second-row, removable-drive, and quota controls; byte/bit rate units; PhysicalDisk/LogicalDisk category; graph-ceiling presets; and All/Main/Second counter-instance shortcuts. Main/Second automatically select LogicalDisk with the selected capacity drive letter. All selects `_Total` in the current category. Capacity selection and transfer selection remain independent.

Changes save immediately to the existing keys in `User\IO.inc` and refresh only the main `ParallaxIO` group. Opening settings makes no writes. The popup joins `Parallax` without `ParallaxIO`, so ordinary changes leave it open. **Load native capacity** / **Load disk counters** switch variants explicitly. Custom volume roots or exact physical-disk instances remain editable through **Edit file**, followed by **Reload**. **Edit advanced IO options** is also available in the main context menu. **Parallax settings** opens the shared suite settings.

The popup uses its own `Columns=2`, `PanelHeight=326` geometry without saving those values over the main monitor's choices. It introduces no new persisted keys or helper processes.

| Setting | Default | Meaning |

| --- | --- | --- |

| `Columns` | `1` | Shared one- or two-column width. |

| `PanelHeight` | `174` | Logical painted height. Keep at least 174 for this compact layout. |

| `IODrive1` | `C:` | First native capacity drive. |

| `IODrive2` | `D:` | Second native capacity drive. |

| `IOShowDrive2` | `0` | Use `1` to enable the second row's native measures. |

| `IOIgnoreRemovable` | `0` | Includes USB/removable drives; `1` ignores them. |

| `IODiskQuota` | `0` | Whole-volume capacity; `1` requests user quota semantics. |

| `IODiskCategory` | `PhysicalDisk` | Optional counters: only `PhysicalDisk` or `LogicalDisk`. English names are translated by UsageMonitor. |

| `IODiskInstance` | `_Total` | Exact performance-counter instance; `_Total` explicitly selects the category aggregate. Blank/whitespace instances are rejected in the display. |

| `IODiskUnits` | `bytes` | `bytes`: binary B/s, KiB/s, MiB/s; `bits`: decimal bit/s, kbit/s, Mbit/s. Capacity always uses binary bytes. |

| `IODiskMaxMiBs` | `500` | Each transfer bar's fixed ceiling in MiB/s, independent of text units. Positive number required. |

For a logical-volume transfer view, use `IODiskCategory=LogicalDisk` and the exact volume instance shown by Windows Performance Monitor, commonly `IODiskInstance=C:`. For an individual physical disk, find its exact instance in Performance Monitor; do not assume a disk index or hardcode machine-specific identifiers into a distributable package. Capacity drive selection and disk transfer instance selection are independent. The optional heading names the transfer category/instance so `_Total` is not presented as the capacity drive's traffic.

The shared `CapacityInterval` remains authoritative. Capacity measures use `Max(5,Ceil(CapacityInterval/1000))` with the one-second skin tick: 30 seconds by default, rounded upward, minimum five seconds. The heading tooltip reports the configured cadence. Drive appearance/removal can therefore take up to the next capacity sample to appear. Settings take effect on refresh; the telemetry controller never writes settings. The separate settings controller writes only in response to explicit controls. Global scale/color/font overrides continue to apply through shared includes.

Transfer bars show the current reported sample relative to the configured ceiling; this prototype does not retain historical graphs. Text preserves the reported magnitude when the bar saturates. Capacity bars and the main-drive header show percentage used, while row text shows free and total capacity.

## Honest data states

| Condition | Display behavior |

| --- | --- |

| Valid drive total and free bytes, including zero free bytes | Capacity values and used-space bar. A full disk is valid, not missing. |

| Native drive type `Error`/`Removed`, or invalid/zero total | Missing/unavailable text and hidden used-space bar. |

| Optical drive | Explicit unsupported-capacity text. |

| Removable drive intentionally ignored | Ignored or unavailable text, depending on the native type response. |

| Second drive disabled | `Off` beside its configured drive; its three native measures are disabled. |

| Native-only variant | Disk counters off; read/write `--`; no UsageMonitor worker requested by IO. |

| Optional positive cooked disk rate | Provider-reported value and bar, with visible `Reported; age unknown` status. |

| Optional zero, negative, nonfinite, missing measure, or initial sample | `--` for that direction; its bar is hidden. The label explains idle/unavailable ambiguity. |

| Unsupported category or blank instance | Configuration/status message; values and bars suppressed. |

UsageMonitor cannot reliably distinguish a missing counter from a valid idle zero. A named query's returned string can equal the configured name even when the instance is absent. A zero indexed query can have an empty string even when valid. Failed collection can retain old nonzero values. Consequently the module never treats the returned name as a presence probe, never invents a freshness timer, and never labels an unsupported zero as measured throughput. A positive value is explicitly only provider-reported. A flat value is not proof that it is stale.

`RawValue=0` and `Percent=0` preserve cooked `Disk Read Bytes/sec` / `Disk Write Bytes/sec` values in B/s. `RawValue=1` would expose the raw cumulative counter. `Rollup=0` preserves exact instance semantics. Process aliases such as `IOREAD`/`IOWRITE` are not used: they can count network/device/file I/O and are not physical disk throughput. Native capacity availability does not establish optional counter availability.

UsageMonitor samples through an independent category worker at 1 Hz. The two IO queries share their category. Neither a low-power `MetricsInterval` nor slower skin updates throttle that worker. Switch back to `IO.ini` to release this skin's queries; the worker stops only when no remaining skin uses the category. This design adds no packet capture or helper polling.

## Shared typography and surface controls

The main and settings titles inherit `TitleFontSize` / `TitleTextColor` from `StyleTitle`. Capacity/transfer headings and the popup section headings use `HeaderFontSize` / `HeaderTextColor`; local header styles retain their own column geometry. The live header percentage explicitly uses body `FontSize` / `TextColor`. Capacity values and transfer readings also use body typography. Missing/disabled/unsupported capacity remains `MutedColor`; transfer availability/status metadata retains its smaller, muted styling. Disk activity colors and bar tracks are unchanged.

Popup labels/readouts use body typography, with primary preset controls on `AccentColor`. **Edit file** and **Close** use the shared `StyleSecondaryButton` color modifier (`AccentColor2`). Title/body text boxes and the compact monitor row positions now allow the global maximum 12/10/10-point settings; popup drive/limit controls have wider value slots. No selected size is clamped, no saved preference is rewritten, and the main/popup panel heights remain 174/326.

Both panels inherit the shared `StylePanel`, including background RGBA and `BorderThickness`. IO contains no decorative section separators or table rules to migrate to `DividerColor` / `DividerThickness`: its existing lines are drive/arrow artwork or semantic capacity/transfer bars. Divider preferences therefore leave IO unchanged. No shared source or module user default was edited for this integration.

Changed paths for this integration: `@Resources/Modules/IO/View.inc`, `IO.lua`, `SettingsMeters.inc`, `tests/ControllerSuite.lua`, `tests/check_geometry.py`, `tests/Run-SettingsSmoke.ps1`, and this report. Native measure/provider definitions and settings actions are unchanged.

### Typography and surface validation, 2026-09-11

Five successful native runs used the same isolated smoke runner, with all captured images opened and inspected. Distinct title/header/body probe colors were applied only in generated stages for the maximum-font captures. No overlap, clipped fixed labels, unexpected panel growth, or Rainmeter errors appeared in the sampled layouts. Every run also passed the existing 46-test / 1,489-assertion Lua suites and the units-save/main-refresh/independent-close checks. Provider correctness was not re-benchmarked.

| Width / scale | Variant | Title/header/body | Border / divider thickness | Evidence directory under `build/` |
| --- | --- | --- | --- | --- |
| 180 / 1 | IO.ini | 12/10/10 | Existing defaults | `Parallax-io-settings-smoke-20260911T231248678Z-f7aeac2f` |
| 180 / 1 | IO-Disk.ini | 12/10/10 | Existing defaults | `Parallax-io-settings-smoke-20260911T231248473Z-d4dbc71b` |
| 200 / 1 | IO.ini | 12/10/10 | 0 / 0 | `Parallax-io-settings-smoke-20260911T231632054Z-fed65882` |
| 200 / 1 | IO-Disk.ini | 12/10/10 | 4 / 4 | `Parallax-io-settings-smoke-20260911T231632456Z-8a4f1a10` |
| 180 / 0.75 | IO.ini, hover action replay | 10/8/9 | 4 / 4 | `Parallax-io-settings-smoke-20260911T231700180Z-c3d70f68` |

Each directory includes `captures/IO.png` (or `IO-hover.png`), `captures/IO-Settings.png`, suite results, observed saved units, and its own Rainmeter log. The smoke runner now accepts `-IOVariant`, `-Typography Current|Default|Maximum`, `-RoleColors`, and `-Surfaces Current|None|Thick`. It waits for positive native window dimensions before capture; earlier fixed-delay attempts encountered unfinished popup layout during simultaneous task activity. Static validation passed with zero errors/warnings; the scoped Git whitespace check passed. Numerical geometry covers all supported widths/scales and both main column counts; native coverage remains the five samples above, not an exhaustive DPI/font/provider cross-product.

## Checks performed

1. Read `AGENTS.md`, `docs/ARCHITECTURE.md`, and the relevant official measure/provider documents and stable source. A separate read-only agent reviewed provider semantics and implementation. Its empty-instance finding was fixed.

2. Ran `tools/Test-Parallax.ps1`: source validation passed with zero errors/warnings, and the latest fresh stage contained 20 configs and 65 INI/include files with zero errors/warnings. Source totals can include other tasks' concurrent test fixtures. This checks INI structure, includes, and shared contracts, not live Rainmeter behavior.
3. Ran `@Resources/Modules/IO/tests/check_geometry.py` against actual shared/module formulas and styles. All 4,400 meter bounds checks passed: 1,150 for the main monitor and 1,050 for settings per typography profile, across widths 180/200/240/280/320 and scales 0.75/1/1.25/1.5/2. Both default (10/8/9) and maximum (12/10/10) title/header/body profiles are checked. The monitor covers both Columns values; the independent settings utility uses two columns. Right-aligned strings are checked using their real left bounds. These are numerical bounds checks, separate from the captures below.

4. Evaluated the actual used-capacity formula for half-full, full, empty, and zero-total input. Results were 50%, 100%, 0%, and a finite internal value for the zero-total case; the controller hides the invalid zero-total bar. Verified 30-second default capacity dividers, upward rounding (31,001 ms to 32 seconds), and the five-second lower bound.

5. Checked that the base include graph contains neither NIC nor UsageMonitor sources, and that the optional query definitions specify the two cooked disk counters without a Process alias.

6. Performed one-time read-only Windows checks, with no persistent telemetry output: the default native drive was ready, its total was positive, and free bytes were in range. Both `PhysicalDisk(_Total)` read/write counter paths returned status 0 with finite nonnegative cooked values. These confirm host API/counter availability, not the rendered skin or UsageMonitor runtime.
7. Executed both production controllers under real Rainmeter Lua 5.1 with separate mock SKIN/SELF environments: **46 tests, 1,489 assertions, zero failures**. `ControllerSuite.lua` contributes 21 tests / 220 assertions, including the header's 0%, 100%, valid percentage and unavailable states, plus configured valid-reading and unavailable colors. `SettingsSuite.lua` contributes 25 tests / 1,269 assertions covering every preset control, validation/rejection, batched writes, group scope, independent close, custom-value preservation, and fresh-controller persistence. The suites issue no real bangs or fixture telemetry in the main display.

### Header and separate-settings native checks

Ran `@Resources/Modules/IO/tests/Run-SettingsSmoke.ps1` against fresh stages and independent offscreen Rainmeter INI/SkinPath instances. The runner launches and stops only its own PID. It replays the gear's actual activation action, captures both native windows, invokes the production units control, verifies that `User/IO.inc` persisted the choice and that the refreshed main skin read it, then invokes the production close control and checks that only the main monitor remains. Both runs passed with zero Rainmeter errors.

| Width | Scale | Main window | Settings window | Evidence directory under `build/` |
| --- | --- | --- | --- | --- |
| 180 | 1 | 188 x 182 | 376 x 334 | `Parallax-io-settings-smoke-20260911T185405166Z-d23a9e60` |
| 180 | 0.75 | 141 x 137 | 282 x 251 | `Parallax-io-settings-smoke-20260911T185543248Z-146c1cbf` |

Opened and inspected each run's `captures/IO-Settings.png`; the first run has `captures/IO.png` with the live main-drive percentage, and the second has `captures/IO-hover.png` with the percentage replaced by the gear while normal updates continue. The second run replays the source enter/leave actions; this is not a physical pointer/click test. The captures show fitting controls and stable window bounds at both sampled sizes. They inherit the shared palette present when staged.

Each evidence directory contains `suite-results.txt`, `main-observed-units.txt`, and the Rainmeter log. Instrumentation changes only the generated copy (including a temporary settings tick to drive the explicit actions). Production settings remain event-driven with `Update=-1`. The initial lifecycle runner checked too early for its delayed close; it was corrected to wait on the actual remaining windows. A staging attempt encountered an incomplete concurrent Network include; the subsequent complete workspace passed validation without IO-task edits to Network.

The test files and generated stages are development artifacts, excluded from distribution. The suite interfaces remain `local count, report = dofile(suitePath).run(productionPath)`. Native save/refresh verification currently samples the units control; the mock suite covers all other controls. Physical mouse hit testing, all native option permutations, process-restart persistence, mixed DPI and performance remain release checks.

### Appearance revision 2 and isolated rendering

Read `docs/APPEARANCE.md` revision 2 and inspected the official ModernGadgets reference image. Reduced the panel from 300 to 174 logical pixels; added an original vector drive icon and read/up and write/down chevrons; aligned compact capacity values to the right; reduced tracks to a minimum one physical pixel. Typography follows shared FontFace/FontSize and neutral colors, with shared DiskReadColor/DiskWriteColor for activity. No font or asset was downloaded by this module task. There is no invented history chart; this module retains its instantaneous bars.

Only presentation strings/tooltip text changed in `IO.lua`; availability conditions, rates, native measures, update cadence, provider selection, and variant actions are preserved. Capacity now appears under an explicit “free / total” heading, allowing shorter values. Provider status remains visible as “Counters off,” “Reported; age unknown,” or “Idle or unavailable”; full scope and caveats remain in hover text. Long rate values are also repeated in the tooltip.

Native checks used `tools/Preview-Parallax.ps1 -Modules IO` with fresh staged SkinPath/INI files, hidden/offscreen windows, and capture restricted to the launched PID. Both the controller and providers ran inside actual Rainmeter Lua 5.1. The original user's Rainmeter configuration was not touched. Every captured image was opened and inspected; no overlapping/clipped text or rendering defects were observed in the sampled data/states.

| Width | Scale | Columns | Variant | Actual window | Evidence directory under `build/` |

| --- | --- | --- | --- | --- | --- |

| 180 | 1 | 1 | IO.ini | 188 x 182 | `Parallax-visual-preview-20260911T174726498Z-d4b3fd2f` |

| 180 | 0.75 | 1 | IO.ini and IO-Disk.ini | 141 x 137 | `Parallax-visual-preview-20260911T174921811Z-7cba491a` |

| 200 | 2 | 2 | IO.ini | 832 x 364 | `Parallax-visual-preview-20260911T174942679Z-69ee4c34` |

| 200 | 1 | 1 | IO-Disk.ini | 208 x 182 | `Parallax-visual-preview-20260911T175205438Z-dd6cc459` |

| 180 | 1.5 | 2 | IO-Disk.ini | 564 x 273 | `Parallax-visual-preview-20260911T175229670Z-498a4f5e` |

Each isolated launch had zero Rainmeter error log entries. `captures/IO.png` contains the corresponding native window; the second directory also retains `captures/IO-Disk.png` from restarting only that own stage with the optional variant. The default-width optional capture shows a nonpositive read as `--` beside a positive write, with the honest unverified-age status. Optional small-scale captures show real positive throughput with fitting binary rate labels. These are local test artifacts, excluded from distribution; their host data is not shipped.

Remaining limits: no complete visual cross-product of all 50 geometry combinations; no mixed Windows DPI/snap test; long custom fonts, extreme values, real USB removal/quota cases, actual missing-plugin installation, manual footer clicks, exhaustive option/restart persistence, and CPU/power cost are not fully validated. Source/style regression checks and successful startup do not establish release readiness.

The earlier CPU-style hover gear was added to both IO entrypoints and the shared IO view before the independent settings utility. Its title space is reserved at every width. Static validation passed with zero errors/warnings; the geometry check includes the gear. The initially hidden and revealed states rendered in an isolated 180px/Scale1/Columns1 window with zero Rainmeter errors; evidence is `build/Parallax-visual-preview-20260911T181437453Z-f94283c9/captures/IO.png` and `IO-hover.png`. The revealed-state check replays the actual show/redraw action on refresh in the isolated copy; it does not claim a physical mouse/click test. That earlier gear-only revision did not change controller or polling code. The current revision adds the capacity-derived header percentage and the separate event-driven settings controller described above.

## Runtime acceptance and extension plan

Before release, extend the isolated startup/capture checks to every menu/footer action and exhaustive option/restart persistence. Test a full volume, a missing drive, USB attach/remove with each ignore setting, disabled second drive, optical media, and a long configured drive label. Validate positive disk reads/writes against Performance Monitor, missing/blank instance handling, missing category/plugin behavior, and explicit idle ambiguity. Test both unit modes and saturated/invalid graph ceilings. Complete visual checks at 75%, 100%, 125%, 150%, and 200% suite scale, all supported widths, both Columns values, real edge snapping, mixed Windows DPI, and long text clipping.

Measure CPU cost for native-only versus optional counters with the rest of the suite loaded; include the worker cost and check release when switching variants. A future provider adapter may expose explicit successful-collection timestamps and per-counter availability, allowing true zero/idle and stale/missing states to be separated. Add history only when gaps can remain visibly unknown, rather than filling them with zero. Future drive enumeration or more capacity rows should preserve explicit drives and avoid repeated process launches. No shared schema changes are required for this prototype; package integration and upgrade preservation for `User/IO.inc` remain integration-owner follow-ups.

## Primary references

- [Rainmeter FreeDiskSpace](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/freediskspace.html): native capacity, drive types, removable drives, quotas, and optical limitation.

- [Rainmeter UsageMonitor](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/usagemonitor.html): category/counter/name selectors, translation, worker cadence, raw values, and aliases.

- [UsageMonitor stable implementation, v4.5.26.3894](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Plugins/PluginUsageMonitor/UsageMonitor.cs): named fallback, cooked counter calculation, and retained values on failed collection.

- [Current UsageMonitor implementation](https://github.com/rainmeter/rainmeter/blob/master/Library/MeasureUsageMonitor.cpp): cross-check of the same availability limitations.

- [Rainmeter Lua scripting](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html): measure access, option mutation, and escaped Lua strings.

- [Rainmeter Bar meter](https://docs.rainmeter.net/manual/meters/bar/): measure-range bars.

- [Microsoft physical disk performance counters](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history-for-drives): transfer counters and byte units.

- [Microsoft Process counter definitions](https://learn.microsoft.com/en-us/previous-versions/aa394323(v=vs.85)): why process I/O is not a disk-device throughput measure.

- [Rainmeter Shape meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html): original icon and chevron construction.

- [Rainmeter String meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/string/index.html): font weights, right-aligned anchors, and clipping.

