# RAM module — appearance revision 2

Implemented and restyled on 2026-09-11 to `docs/APPEARANCE.md` revision 2. Native smoke checks pass; this is not a performance or release-readiness claim.

## Delivered result

Entrypoints: `Skins/Parallax/RAM/RAM.ini` and the independent utility `Skins/Parallax/RAM/Settings/Settings.ini`. Implementation ownership remains limited to RAM's skin directory, `@Resources/Modules/RAM/`, `@Resources/User/RAM.inc` and this report. Shared files and other utilities were not edited.

The panel is 310 logical pixels high with a hardware-information inset at the top, matching the CPU/GPU layout. An original DIMM icon, title and right-aligned percentage share a compact header. The inset shows Installed, Type, Rate, Devices and Format on 18-pixel rows. A physical-RAM subtitle precedes Used, Available and Total rows on 19-pixel baselines. A 2-pixel cyan capacity bar and 48-pixel outlined, gridded history complete the panel. It inherits the shared font, neutral palette, inside border and transparent snap gutters. `RAMColor` controls the icon, bar and history. All actual meters declare a type; styles do not draw independently.

Three native `PhysicalMemory` measures supply used, available and total bytes, and a Calc measure counts collected history samples. These telemetry measures are unchanged. The independent Settings utility uses `Settings.lua` and `SettingsMeters.inc`, with `Update=-1` and no telemetry measures. The RAM meter uses the event-only `Display.lua` bridge for hover and preference changes. Hardware inventory uses Rainmeter's bundled `RunCommand` plugin and one hidden Windows PowerShell query per RAM refresh. Opening or changing Settings never launches that query. No installation, elevation, repeated process polling, credentials or persisted telemetry is required. Test-only Lua and fixtures remain isolated under Tests and excluded from staging.

`Update=#MetricsInterval#` controls native sampling and history cadence. Measures, graph and startup cover use divider 1; static labels, icon, panel and graph guides update on refresh. Interval changes require refresh. Hiding history preserves window size and does not claim to stop sampling; unloading stops this skin's work.

## Memory semantics

The new **MEMORY HARDWARE** inset reads Windows `Win32_PhysicalMemory` and `Win32_PhysicalMemoryArray` once per refresh:

- **Installed:** sum of reported device capacities, formatted in the selected GiB/MiB and precision. It is distinct from OS-usable Total below. If any capacity is missing, the total is Unknown or Partial; an incomplete sum is never presented as installed capacity.
- **Type:** raw SMBIOS memory type, such as DDR4, DDR5 or LPDDR5. The raw SMBIOS enumeration differs from WMI's older `MemoryType` enumeration.
- **Rate:** configured transfer rate, shown as MT/s with the Windows value unchanged. Current SMBIOS defines this as a transfer rate; older SMBIOS and Microsoft's WMI documentation call it MHz. The tooltip explains that ambiguity. The skin never doubles the value, falls back to the differently documented `Speed` property, or claims a live clock measurement.
- **Devices:** positive-capacity device records / firmware-reported system-memory slots or sockets, when the inventory is complete and consistent. Otherwise it shows the number of reported device records alone. Unknown-use arrays, zero slot counts or a failed array query leave the denominator unknown. Known non-system arrays are excluded. Firmware records do not establish removable modules, upgradeable slots or channel mode.
- **Format:** WMI form factor, such as DIMM, SODIMM or BGA. These codes also differ from raw SMBIOS form-factor codes.

Different known types/rates/form factors show Mixed; one known value accompanied by missing values shows Partial. All missing values show Unknown. Tooltips retain the distinct known values. Unsupported or malformed output shows Unavailable without disturbing the independent live physical-memory readings. No ECC-active, channel-count or maximum-upgrade claims are inferred.

`MemoryInfo.ps1.txt` selects only capacity/type/rate/form and array use/count. Its versioned numeric wire format is bounded and parsed by `InfoModel.lua`; it emits no manufacturer, serial number, machine identifier or user data. `Info.lua` watches the cached command result until completion, then disables its own periodic updates. The process has a 12-second timeout; the view also settles to Unavailable after a 15-second guard, on the next skin update, if completion is not delivered. Refresh retries the query. No runtime inventory file is written.

- **Used:** OS-usable total minus available physical RAM, in bytes.
- **Available:** `PhysicalMemory` with `InvertMeasure=1`, including reclaimable standby memory. It is not solely the Windows Free list; the tooltip explains this.
- **Total:** `PhysicalMemory` with `Total=1`, meaning physical RAM usable by Windows. Hardware reservations can make this lower than installed RAM. Separate native calls can introduce small instantaneous differences between used + available and total while memory changes.

These are physical RAM figures, not commit charge, commit limit or pagefile occupancy. Commit describes memory Windows has committed to back; it is not current physical use or actual pagefile contents. Cache, compressed memory, hardware reservations and per-process details remain deferred, with no fake values shown.

The percentage String uses `Percentual=1`. Bar and Line bind directly to the used native measure. No synthetic `MaxValue` is supplied; Rainmeter provides the 0-to-total range. Line `AutoScale=0` and `Scale=1` retain a fixed 100% ceiling.

Byte Strings divide by exactly 1,073,741,824 for GiB or 1,048,576 for MiB, with automatic scaling disabled. Each unit has a matching constant divisor and suffix. Precision only affects displayed text. Value tooltips use explicit section variables for raw bytes: Rainmeter's tooltip `%1` substitution forces different formatting and must not be paired with a fixed GiB/MiB suffix.

## Settings

Hover anywhere over the RAM panel to replace the header percentage with the same gear used by CPU. Click it to open the separate **RAM Settings** utility (`Parallax\RAM\Settings`, `Settings.ini`). Leaving the RAM panel hides its gear and restores the percentage even while Settings remains open. The hardware inset and live readout remain visible while configuring RAM.

The utility follows CPU Settings: a two-column panel with a compact header, close control, grouped settings rows and automatic saving. Its logical height is 248 pixels (default window 416 by 256 pixels at scale 1). It inherits the shared font, palette, width, scale and RAM-specific appearance overrides. Utility-only Columns/PanelHeight values set its own window dimensions and never overwrite the RAM meter's saved layout.

Click a setting's row, label or value to change memory units, memory decimals, percentage decimals, capacity-bar visibility or history visibility. Changes apply immediately and save only the selected key in `@Resources/User/RAM.inc`. Units and precision also reformat Installed from cached inventory. Click **X** to close only Settings; RAM continues collecting and showing history. Settings can also run with the RAM meter unloaded: saved choices are applied when RAM next loads. Reopening Settings reads the saved choices.

The main RAM config belongs to `ParallaxRAM`. A settings action broadcasts the selected variable to that group, then updates only its `ParallaxRAMApply` Script measure. This targeted bridge changes affected display meters without refreshing RAM, forcing a Line update, resetting the history counter or launching inventory. The settings utility does not join the RAM meter group and has no recurring updates. Its close action is unqualified `!DeactivateConfig`, so it targets only its own config. The main skin no longer includes settings meters or overlay state.

Both configs retain the shared Settings context action and Edit RAM options in Notepad; the main context menu also opens RAM Settings. Save and refresh after manual file edits. Persisted choices remain under `[Variables]` and module fallbacks precede the user include.

| Key | Default | Supported choices |
| --- | --- | --- |
| `Columns` | `1` | `1` or `2`. |
| `PanelHeight` | `282` (preserved) | Requested logical height. The RAM bounds and surface enforce a minimum of `262 + GraphHeight` (310 by default) to fit the shared typography sizes; larger choices are honored. Saved heights remain intact and expand only at runtime. |
| `RAMTitle` | `RAM` | Plain title; fixed bounds clip long text. |
| `RAMUseMiB` | `0` | `0` = GiB; `1` = MiB. |
| `RAMDecimals` | `1` | Byte precision: 0, 1 or 2. |
| `RAMPercentDecimals` | `0` | Percentage precision: 0, 1 or 2. |
| `RAMShowBar` | `1` | `0` hides; `1` shows. |
| `RAMShowHistory` | `1` | `0` hides plot, labels and guides; `1` shows. |
| `RAMHistoryEmptyColor` | `25,25,25` | RGB only; opaque alpha is added. Match to a customized graph background. |

Shared inherited settings include `FontFace`, `FontSize`, `RAMColor`, `GraphBackgroundColor`, `GridColor`, `GraphHeight`, `Scale`, `ColumnWidth`, `Gutter`, `PanelPadding`, colors and `MetricsInterval`. Add module-local overrides in the RAM user file if needed. Supported widths are 180, 200, 240, 280 and 320, with scales 0.75, 1, 1.25, 1.5 and 2, and both column counts. GraphHeight defaults to 48; the runtime minimum height also accommodates increases. Oversized values clip inside their fixed cells and retain full values in their tooltips. Arbitrary oversized fonts or narrower custom widths are not tested presets.

The RAM and RAM Settings titles use `TitleFontSize`/`TitleTextColor`. PHYSICAL RAM, History, MEMORY HARDWARE and the settings section headings use `HeaderFontSize`/`HeaderTextColor`. Body readings, inventory fields and settings rows use `FontSize`/`TextColor`; primary settings values and the gear retain `AccentColor`. The Settings close control uses `AccentColor2` through `StyleSecondaryButton`. The percentage is a live reading with body-derived `FontSize + 1` and `TextColor`, independent of title controls. The icon/bar/history retain `RAMColor`. Text boxes and spacing accommodate the shared maximum title/header/body sizes of 12/10/10 without clamping user font choices or overwriting saved RAM preferences.

Both outer surfaces use `BackgroundColor` RGBA and `BorderColor`/`BorderThickness`. The main RAM surface adapts the shared inside-stroke formula to its minimum-height layout, including a zero-width border. Settings inherits `StylePanel` directly. RAM has no section-separator or table-rule meters; the existing graph guides retain their graph-specific style.

## History and unavailable information

The native Line buffer stores one sample per horizontal pixel, newest at right. At default width 200, one column, scale 1, there are 188 slots: nominal capacity is 188 seconds at a 1000 ms interval, with 187 intervals between oldest and newest samples. Width, scale and cadence change capacity. This is update-based history, not a timestamped recorder; scheduling delays and suspension affect wall time.

Rainmeter zero-fills its initial Line buffer. An opaque shape covers uncollected slots with a two-logical-pixel overlap to hide the antialiased startup transition. A self-referencing Calc count resets on refresh and reveals actual collected samples; the cover vanishes at capacity. Grid and border render above the cover so blank history still has guides. These guides are not telemetry. The first few samples can be covered by the conservative overlap.

History is not saved. Refresh, reload or geometry changes applied by refresh restart it. Avoid graph-only `!UpdateMeter` actions, including `!UpdateMeter *`, unless the sample count is coordinated; normal full updates keep them aligned.

The hardware inset reports an unavailable inventory explicitly. Native PhysicalMemory exposes no freshness/status display here, so the skin cannot independently detect stalled live values or OS query failures. It invents neither freshness timestamps nor recovery states.

## Validation results

- **Source checks passed:** `Validate-RAM.ps1` passed **30,785 assertions across 225 geometry cases** (150 main RAM and 75 Settings cases): five widths, five scales, both main column counts, the utility's two-column layout and border widths 0/1/4. It reads actual files and checks includes, semantic typography, action routing, native bindings, normalization, byte divisors/labels/visibility, every Shape component and stroke extent, text rectangles, transparent gutters and startup-cover bounds. It also checks the hardware provider contract and expansion for saved heights. Positive half-up rounding handles half-pixel geometry such as padding at scale 0.75.
- **Native checks passed:** `Tests/Test-RAMNative.ps1` ran **20 cases and 22,142 checks** (12,162 main-meter and 9,980 utility checks) in Rainmeter **4.5.26.3894**, with **zero log errors**. Cases cover widths 180/200, both RAM column counts and all five scales, long titles, precision 2, alternating GiB/MiB, border widths 0/1/4, and ten default plus ten maximum 12/10/10 title/header/body typography cases. Distinct test colors verify the semantic roles; unconstrained native String probes verify font heights against the actual text boxes. These probes caught a maximum-title clipping issue at scales 0.75/1.5; the main title box is now 22 logical pixels high and passes. Double-column RAM cases retain `PanelHeight=170` and verify expansion without overwriting that saved choice.
- **Dedicated utility behavior passed:** the actual gear action opens a separate Settings config. All five controls apply across configs and persist only their selected keys. Installed-capacity formatting updates immediately, Settings closes independently, the main hover gear hides on leave, and history sample counts remain continuous. Each utility opens/closes twice and verifies all saved values after reopening. The utility has independent bounds and no physical-memory, hardware-inventory or history measures. Test copies isolate RAM groups per case to avoid cross-case preference changes. The offscreen harness invokes real action strings, not physical pointer events.
- **Hardware regression coverage:** the existing model checks retain mixed/unknown/partial/unavailable and malformed-input coverage; the native matrix uses one real query, eighteen explicit fixture cases and one unfinished-provider timeout. The latest sandbox query reported Unavailable honestly. Earlier hardware-panel validation used a read-only query and isolated native run with normal Windows access and returned complete hardware fields through the production provider and UI. That earlier success verifies the integration on this computer, not firmware accuracy on every machine; no new hardware-accuracy claim is made by the settings change.
- **Provider checks passed:** `Tests/Test-RAMInventoryProvider.ps1` passed **28 checks** with deterministic input objects, including missing/unknown arrays, multiple-array aggregation, zero counts, empty inventory and denied device/array queries. Each invocation issues at most one query per class. These tests never read actual hardware or write files.
- **Suite static scan passed:** `tools/Test-Parallax.ps1` inspected 20 configs and 65 INI/include files with zero errors and zero warnings after the dedicated utility and appearance integration.

Latest native evidence: `Skins/Parallax/@Resources/Modules/RAM/Tests/.runtime/ram-native-20260911T232306934Z-010be24be9e94e2097b64a73b6450f42/summary.json`, plus per-case reports and the isolated log. The earlier successful real-inventory run is under `ram-native-20260911T185528022Z-6f07a53e43ad44b6b16655bf8db71858`. These runtime snapshots and hardware output are test-only and must not be distributed. Tests write unique RAM-owned scratch directories, use a separate absolute INI and SkinPath, load copied skins hidden/offscreen, and stop only the process they launched. The final native run used a 60-second harness deadline after the 45-second run expired during utility reopening under concurrent test load; this is not a performance result. No live user configuration was read or changed. Existing shared fonts were copied only into test scratch; no font was downloaded or installed.

| Scale | Width 180: single / double window | Width 200: single / double window |
| --- | --- | --- |
| 75% | 141 x 239 / 282 x 239 | 156 x 239 / 312 x 239 |
| 100% | 188 x 318 / 376 x 318 | 208 x 318 / 416 x 318 |
| 125% | 235 x 398 / 470 x 398 | 260 x 398 / 520 x 398 |
| 150% | 282 x 477 / 564 x 477 | 312 x 477 / 624 x 477 |
| 200% | 376 x 636 / 752 x 636 | 416 x 636 / 832 x 636 |

Re-run from the repository root in PowerShell:

```powershell
& 'Skins/Parallax/@Resources/Modules/RAM/Validate-RAM.ps1'
& 'Skins/Parallax/@Resources/Modules/RAM/Tests/Test-RAMInventoryProvider.ps1'
& 'Skins/Parallax/@Resources/Modules/RAM/Tests/Test-RAMNative.ps1' -TimeoutSeconds 60
& 'tools/Test-Parallax.ps1'
```

No unresolved parser, meter-bound or tested font-height failures remain. Native smoke does not establish full visual readability, horizontal clipping quality, full-history reveal, mixed-DPI snapping, full RAM unload/reload persistence, external telemetry accuracy or CPU cost. Settings close/reopen persistence is verified separately. The coordinating task owns all-suite capture and final pixel inspection. Check the icon, long MiB text, grid contrast and startup edge in actual captures before release. No performance-budget pass or release readiness is claimed.

## Remaining work and extension plan

1. Finish capture inspection at narrow/default widths and 0.75-scale typography. Compare readings against Windows under changing load; exercise Options/Settings actions, saved edits through refresh/unload/reload, the full-history transition and color customization.
2. Check snapping on mixed-DPI monitors and profile idle/loaded Rainmeter CPU and memory over time. Notepad runs only through a user action and is unrelated to sampling.
3. An optional process list can use built-in UsageMonitor after explicitly choosing working set, private working set or private bytes. These differ and must not be summed or labeled as total physical RAM. Keep the list opt-in, require no privileged helper, retain process names only in memory, and show inaccessible entries honestly. Its independent category worker is not slowed by MetricsInterval; an unloaded optional config avoids that cost.
4. Add commit/pagefile metrics only as separately labeled measurements with verified Windows semantics. A future fixed-duration graph needs a bounded timestamped buffer with explicit gaps.
5. Shared Settings may write documented keys to `User/RAM.inc`, then refresh this RAM config. The coordinator owns packaging, variable preservation, font assets/licensing and release readiness. No shared-file change is required by RAM.

## Sources and attribution

The icon, layout and module code are original. The [official ModernGadgets preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png), inspected through the root-owned local reference, informed density only. No upstream code, icons, fonts or other assets were copied into the RAM implementation. Font provisioning and licensing are shared-owner work.

- [Rainmeter memory measures](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/memory.html), [PhysicalMemory implementation](https://github.com/rainmeter/rainmeter/blob/master/Library/MeasurePhysicalMemory.cpp), and [Microsoft MEMORYSTATUSEX](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex): native values and available/total meaning.
- [String meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/string/index.html) and [tooltips](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/general-options/tooltips.html): percentage, units, precision, clipping and tooltip formatting.
- [Line meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/line.html) and [Line implementation](https://github.com/rainmeter/rainmeter/blob/master/Library/MeterLine.cpp): normalization, buffer size and initialization.
- [Calc measure](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/calc.html), [measure initialization](https://github.com/rainmeter/rainmeter/blob/master/Library/Measure.cpp), [skin update source](https://github.com/rainmeter/rainmeter/blob/master/Library/Skin.cpp), and [formulas](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/formulas.html): reset, ordering and expression behavior.
- [Rainmeter section](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/skins/rainmeter-section/index.html) and [general meter options](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/general-options/index.html): cadence, styles and geometry.
- [Win32_PhysicalMemory](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory), [Win32_PhysicalMemoryArray](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemoryarray), [DMTF SMBIOS 3.9](https://www.dmtf.org/sites/default/files/standards/documents/DSP0134_3.9.0.pdf), and [installed physical memory](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getphysicallyinstalledsystemmemory): device metadata, enumeration codes, configured transfer-rate semantics and installed versus OS-usable capacity.
- [RunCommand](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/runcommand.html) and [Lua scripting](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html): refresh-only execution, cached status, timeout and event-driven redisplay.
