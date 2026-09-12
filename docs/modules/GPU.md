# GPU module prototype

Implemented and restyled 2026-09-11. This is a bounded module prototype, not a release-readiness or performance result. Source changes are confined to GPU-owned paths; isolated preview evidence is generated under `build/`. No shared settings, styles, geometry, other modules, live Rainmeter configuration, dependencies or registry values were changed by this task.

## Delivered behavior

Load `Parallax\GPU\GPU.ini` through Rainmeter when testing the suite. The dense black panel follows `docs/APPEARANCE.md` revision 2: an original vector board icon, GPU title and small green activity value share one header; a CPU-style bordered inset shows the discrete GPU model and five capability details. **Peak process engine**, PID / engine type and scope remain visible below. Labels and values align on 18px rows. The panel height is 288 logical pixels, including the capability inset and the CPU-style hover gear. Shared `GPUColor`, `FontFace`, palette, border and geometry are inherited, with no imported icon or new telemetry/history graph. The official [ModernGadgets preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png) and [stylesheet](https://github.com/raiguard/ModernGadgets/blob/master/Skins/ModernGadgets/%40Resources/StyleSheet.inc) were inspected only as visual references.

The monitor joins `Group=Parallax|ParallaxGPU`, uses the prescribed include order and transparent snap gutters, and retains all context actions. Its separate settings utility joins only `Parallax`, so GPU-specific refreshes leave settings open. Every actual meter declares its type; no styles create meters. The new model metadata is separate from existing activity collection and sensor-mapping validation.

Hovering over the painted panel reveals the same original Parallax gear used by CPU, temporarily replacing the header activity value. Leaving hides the gear and restores the latest value; normal telemetry updates continue throughout. The hidden gear has no mouse hit target. Native skin-level `MouseOverAction` / `MouseLeaveAction` and `ShowMeter` / `HideMeter` bangs handle this without polling or resizing. [Rainmeter mouse actions](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/mouse-actions.html)

## Main discrete GPU information

The inset displays the driver-reported name of the first discrete graphics adapter in Windows' high-performance ordering, without a separate heading. A one-time DXCore query enumerates D3D12 graphics adapters and explicitly checks `IsHardware=true` and `IsIntegrated=false`; vendor names and reported VRAM are not used as classification shortcuts. External discrete GPUs may rank ahead of internal ones. This identifies Windows' performance preference, not necessarily the adapter driving the monitor. [Microsoft enumeration and preference guide](https://learn.microsoft.com/en-us/windows/win32/dxcore/dxcore-enum-adapters), [adapter property definitions](https://learn.microsoft.com/en-us/windows/win32/api/dxcore_interface/ne-dxcore_interface-dxcoreadapterproperty)

The original `AdapterInfo.cs.txt` contains source code, not a binary. RunCommand invokes Windows PowerShell once from `OnRefreshAction`, compiles that source with `Add-Type`, and reads metadata through Windows DXCore. It resolves the selected adapter's LUID through DXGI and briefly creates a Direct3D 12 device for capability queries, releasing it after reading. The `.cs.txt` suffix lets the current packaging allowlist preserve this clearly identified source file; native assemblies/plugins are not distributed. Query output remains in memory. The process is hidden, bounded by a 12-second timeout, and is not relaunched by updates. The Lua view converts failed or incomplete results to an honest status after completion/timeout. [Rainmeter RunCommand](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/runcommand.html)

| Capability row | Meaning |
| --- | --- |
| VRAM | Driver-reported dedicated adapter memory in GiB, with exact bytes in the tooltip. Excludes shared RAM; not current usage or an available-memory budget |
| Direct3D | Highest reported hardware feature level, displayed as `FL 12_1`, for example. This is functionality, not the installed DirectX version or a performance score |
| Shader | Highest shader model exposed by this GPU, driver and Windows runtime |
| Ray tracing | DirectX ray-tracing tier, or `Unsupported` only when the API explicitly returns no support. Does not establish dedicated RT cores or predict speed |
| Driver | Windows graphics driver version; may differ from the vendor's package version |

All five rows describe the selected discrete GPU. Per-field query failures show `Unknown` while preserving other successful results and the model name. Feature probing steps down when an older runtime rejects a newer query; it does not infer capabilities from model names. Full values and explanations are available in tooltips. These details share the single load/refresh query. [DXCore memory and driver properties](https://learn.microsoft.com/en-us/windows/win32/api/dxcore_interface/ne-dxcore_interface-dxcoreadapterproperty), [Direct3D feature levels](https://learn.microsoft.com/en-us/windows/win32/direct3d12/hardware-feature-levels), [DirectX ray-tracing tiers](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ne-d3d12-d3d12_raytracing_tier)

`No discrete GPU found` means no compatible discrete candidate was exposed. `Multiple discrete GPUs` means more than one candidate exists but performance sorting is unsupported. `GPU name unavailable` covers missing DXCore, unsupported properties, query failures, stale enumeration and process/compilation failures. Integrated/software adapters are never substituted. This initial path requires DXCore (Windows 10 build 18936 or later) and D3D12 graphics enumeration support; legacy adapters may not be exposed. Refresh after hardware changes. Long names clip within the inset; the complete name is in the tooltip. The activity percentage still spans **all GPUs**, as its visible scope states.

The activity measure uses Rainmeter's built-in UsageMonitor:

```ini
Alias=GPU
Index=1
PIDToName=0
Rollup=0
Percent=0
RawValue=0
```

This selects the highest exposed **single process / adapter / engine instance**. It does not add engines, identify the busiest adapter, or represent whole-adapter utilization. A process using one engine at 30% and another at 20% contributes a 30% candidate here. Two processes sharing one engine are not aggregated into an adapter figure. Microsoft describes a different aggregation for Task Manager's whole-adapter total. [Microsoft GPU telemetry semantics](https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/)

Raw identity is intentional: name translation can merge multiple engine instances with the same executable name. `Rollup=0` alone does not prevent that. The script requires PID, adapter LUID and engine identity before showing a percentage. A blank engine type is permitted; it shows the PID alone. The complete raw identity is available in the tooltip. Some Rainmeter 4.5 UsageMonitor cache paths can also share translated names with another skin; the identity guard suppresses those results instead of treating them as a peak engine. This was checked against the exact installed version's source. [Official UsageMonitor 4.5.26.3894 implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Plugins/PluginUsageMonitor/UsageMonitor.cs#L359)

At zero, a ranked UsageMonitor instance has no name. The panel shows `--` and **Idle / unavailable**, covering startup, genuine inactivity, unsupported drivers and missing counters without inventing a zero reading. Unexpected identities show **Unsupported counter format**. Collection failures may retain an earlier observation; UsageMonitor does not expose a timestamp here. No stale detector is claimed. Windows 10 Fall Creators Update or later and a suitable GPU driver are required by this counter family. [UsageMonitor options and limitations](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/usagemonitor.html)

## Optional sensor setup

The top-right **gear** and **GPU settings** context action open `Parallax\GPU\Settings\Settings.ini` as a distinct Rainmeter utility. GPU remains loaded. This window provides meter width, fit-height, sensor enable/disable, registry hive, and Temperature/Power/Clock mapping controls. Click a sensor row to browse exported readings, select an exact identity, or clear that row. **Rescan** retries discovery; **Previous/Next** browse five candidates per page. Choices save immediately to `@Resources\User\GPU.inc` and refresh only the `ParallaxGPU` monitor group. Opening or closing settings writes no choices; X closes only the settings config. The utility keeps its own two-column, 422-logical-pixel layout regardless of the monitor's saved width or height.

The window also exposes **Guide**, **Advanced**, **Refresh GPU**, and **Global settings**. The installed guide remains `@Resources\Modules\GPU\Mapping.txt`. Advanced opens the module include for custom registry paths and manual mappings; save, reopen settings to read file edits, then refresh GPU. Existing unrelated/custom module options are preserved. The settings controller is event-driven; its RunCommand measure checks cached completion on the skin's one-second cadence and launches no background scan until Browse/Rescan is requested. [Config and group bangs](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/bangs.html)

`DiscoverExports.ps1.txt` is original executable source preserved by the existing source-only packaging rules. A fixed RunCommand reads that file from the GPU module directory and executes it once. It reads the fixed relative GPU include to locate the chosen HKCU/HKLM source, opens the 64-bit registry view read-only, and returns a bounded, versioned UTF-8 hex protocol. It never places provider strings in commands. Discovery lists only complete Sensor/Label/Value/ValueRaw tuples with finite numeric raw values; it does not infer the GPU, metric type, or export freshness. The user chooses the intended GPU and measurement. Missing/unreadable sources and empty or malformed results have explicit statuses. No discovery output is written to disk.

Mapping selections persist only an allowlisted row's exact index and identity. Rainmeter expression syntax, quotes and control characters are rejected, with a narrow exception for ordinary HWiNFO ordinal markers such as `[#0]`. A changed hive/key invalidates the picker list. Clearing stores `-1` and empty identity strings without enabling sensors. The saved include supports UTF-8 and Rainmeter's UTF-16LE output. Opening settings never rewrites custom preferences; each action writes only its own keys.

GPU titles inherit `TitleFontSize`/`TitleTextColor`; the activity section and settings section headings inherit `HeaderFontSize`/`HeaderTextColor`. Provider values and the live activity value use body-derived sizing, retaining `GPUColor` for activity and `MutedColor` for status/scope. Guide and Advanced use `AccentColor2`; primary setting actions retain `AccentColor`. Outer panels inherit `BorderThickness`, and the GPU section separator inherits `DividerColor`/`DividerThickness` from `StyleRule`. The settings window inherits the shared bundled font without provisioning assets.

The optional source is HWiNFO Gadget registry export. It requires neither the external HWiNFO Rainmeter plugin nor Shared Memory. HWiNFO must be configured separately to export the selected sensors. The shipped config has `GPUEnableSensors=0`, every index `-1`, and every expected identity empty. No machine-specific index is supplied as a default. The user chooses and verifies the GPU and the meaning of each temperature, power or clock sensor. [Official export setup](https://github.com/rainmeter/rainmeter-docs/blob/master/source/tips/hwinfo.html)

| Setting | Shipped value / purpose |
| --- | --- |
| `Columns` | `1`; supports `1` or `2` |
| `PanelHeight` | `288`; keep enough height for the capability inset and all rows |
| `GPUEnableSensors` | `0`; set exactly `1` to enable registry reads |
| `GPURegHKey` | `HKEY_CURRENT_USER`; use the hive containing the user's export |
| `GPURegKey` | `SOFTWARE\HWiNFO64\VSB` |
| `GPUTemperatureIndex/Sensor/Label` | `-1` / empty / empty; selected temperature identity |
| `GPUPowerIndex/Sensor/Label` | `-1` / empty / empty; selected power identity |
| `GPUClockIndex/Sensor/Label` | `-1` / empty / empty; selected clock identity |

For each local index N, map the exact `SensorN` and `LabelN` strings. The module checks those identities and the existence of `SensorN`, `LabelN`, `ValueN` and `ValueRawN` in `OutputType=ValueList` before using a value. The raw value must parse as a finite number; the formatted export must contain a number and a unit rather than a bare numeric fallback. Formatting and units are retained from HWiNFO instead of assuming Celsius, watts or MHz. [Registry measure syntax](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/registry.html)

| Row state | Meaning |
| --- | --- |
| Off | Optional registry measures disabled |
| Unmapped | Index or either expected identity missing |
| Check mapping | Invalid index or identity mismatch |
| Unavailable | Required export absent or unusable value |
| Formatted value | Matching exported snapshot, including valid raw zero |

The footer explicitly says **Snapshot / age unknown** whenever enabled. Exports can remain after HWiNFO stops, and repeated values cannot distinguish a stable sensor from a stale export. Individual registry reads are not an atomic snapshot. Identical sensor / label strings cannot distinguish duplicate identities. Localized raw decimal formats rejected by Lua's numeric parser show Unavailable and still need integration testing. These readings are not alarms. Adding or removing Gadget exports may change indices; remap after changing the selection. The mapped sensors may describe a different GPU from the activity peak, which always considers all exposed adapters.

## Cadence, files and persistence

The skin uses `MetricsInterval` (default 1000 ms). Optional registry measures use `Max(1,Ceil(SensorInterval/Max(1,MetricsInterval)))` as their divider: the requested interval rounds up to a whole skin update. The default is 2000 ms. HWiNFO controls its own acquisition cadence. UsageMonitor's shared GPU category worker continues at 1 Hz independently of these settings; unload GPU to remove this consumer, and unload every consumer to release the category. No repeated subprocess or shell polling is used; the GPU-name command is a one-time metadata query at load/refresh.

`GPU.lua` only interprets measures and updates displayed text / tooltips when they change. Provider strings are stripped of option-expression delimiters before use in display options. Nothing is executed from those strings. The module writes no history, provider cache or runtime data. All user settings live in the preserved `[Variables]` file. Include `Parallax\@Resources\User\GPU.inc` in the package's Variables files list. Preserve changed values and empty strings during the actual package upgrade test. [Documented Lua APIs](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html)

## Validation performed

All checks below were performed on 2026-09-11.

| Check | Result |
| --- | --- |
| GPU-specific offline validator | Passed after adding capability rows: seven config/includes, 29 explicit meters, 50 geometry cases, four sensor-cadence cases. Checks capability row separation and inset containment |
| Geometry matrix | Widths 180 / 200 / 240 / 280 / 320, Columns 1 / 2, scales 0.75 / 1 / 1.25 / 1.5 / 2. Includes actual shared padding, icon bounds and label/value non-overlap. Fixed text widths and clipping keep long values inside the window |
| Shared suite validator during settings implementation | 20 configs, 63 INI/include files, zero errors and zero warnings |
| Initial native Windows GPU counter spot check | A read-only `Get-Counter` snapshot exposed 439 instances; all 439 met the module's raw identity guard, 12 had empty engine type, five were nonzero |
| Independent source/code reviews | Counter merge/cache semantics, Lua API use, mapping guards and geometry reviewed; no remaining actionable defect reported |
| Isolated Rainmeter / Lua execution | Four GPU-only offscreen preview runs passed on Rainmeter 4.5.26.3894, using Lua 5.1, with zero logged errors. Only each generated test profile / process was used and stopped |
| Actual window captures | Inspected all four captures listed below. Compact header, divider, sensor rows, scope, idle state and footer actions render without visible overlap; positive activity also rendered. No unresolved rendering defect found in these cases |
| HWiNFO integration, mixed Windows DPI, upgrade persistence, CPU cost | **Not performed** |

The isolated previews contain actual counter data, not fabricated telemetry. Their screenshots and native reports are retained outside distribution. No local PID, LUID, sensor mapping or sampled value was saved in distributable source. Optional sensors remained disabled during these captures; enabled missing-provider, index-drift and long exported-value states still need native integration tests. Long text is bounded by fixed clipped meters, but font fit for every possible value is not established.

| Native case | Window | Preview evidence under `build/` |
| --- | --- | --- |
| Width180, scale0.75, Columns1 | 141 x 144 | `Parallax-visual-preview-20260911T174658470Z-b0a8f5cf` |
| Width200, scale1, Columns1 | 208 x 192 | `Parallax-visual-preview-20260911T174715054Z-eb6c582e` |
| Width180, scale1, Columns2 | 376 x 192 | `Parallax-visual-preview-20260911T174740459Z-f52e66b0` |
| Width200, scale2, Columns2 | 832 x 384 | `Parallax-visual-preview-20260911T174833200Z-9aacebd8` |

Each folder contains `captures/GPU.png`, `native-GPU.txt` and `preview-report.json`. Root owns the all-suite visual capture. The other scale/width combinations were checked offline rather than captured natively.

The later hover gear change was checked separately in `build/Parallax-visual-preview-20260911T181506560Z-1e45e8db`, with a 208 x 168 native window. `gpu-hover-status.txt` confirms the gear starts hidden, remains visible while activity stays hidden through several normal GPU updates, and hides again when the leave action restores activity. `GPU-hover.png` and `GPU-leave.png` record both render states. The current suite validator reported zero errors / warnings and the isolated Rainmeter log contained no errors. This test executes the source mouse actions in Rainmeter without moving the user's pointer; actual pointer event delivery and the Notepad click were not automated. All instrumentation remains only in the generated test stage.

The adapter-name addition was verified directly with Windows PowerShell `Add-Type` and then through the production RunCommand/Lua path in isolated Rainmeter. Both detected **NVIDIA GeForce GTX 1080** from Windows; this is a test result, not a shipped default. The default-width native capture is `build/Parallax-visual-preview-20260911T182352745Z-dd395675/captures/GPU.png` (208 x 216). The width180, scale0.75 capture is `build/Parallax-visual-preview-20260911T182442905Z-b1c57fce/captures/GPU.png` (141 x 162). Staging preserved `AdapterInfo.cs.txt`, the full name fit the inset at both sizes, and both Rainmeter logs had no errors. Classification failure, integrated-only and multiple-discrete hardware branches were source-reviewed rather than reproduced on hardware.

The capability expansion was verified on the same hardware through the production Windows PowerShell 5.1 and Rainmeter paths. The actual query returned 8,450,473,984 dedicated bytes (displayed as **7.9 GiB**), feature level **12_1**, shader model **6.8**, **DXR 1.0**, and Windows driver **32.0.15.8266**. These are observed values, not shipped defaults or model lookup entries. An injected D3D12 failure preserved the name, memory and driver with unknown graphics capabilities; an unsupported-memory probe preserved the other fields. These probes modified source only in memory. The direct Windows PowerShell compile/query took about 4.37 seconds in this check; this is startup evidence, not a benchmark.

The complete capability panel was captured and visually inspected at width200/scale1 (208 x 296) in `build/Parallax-visual-preview-20260911T184355719Z-92e3b9a4/captures/GPU.png` and width180/scale0.75 (141 x 222) in `build/Parallax-visual-preview-20260911T184410279Z-02b0db85/captures/GPU.png`. The name, all five values and existing readings fit without overlap. Both reports contain zero Rainmeter errors. The earlier captures above record prior layouts.

A separate isolated native Lua 5.1 harness passed **25 parser cases**: complete and partial results, unknown versus unsupported ray tracing, malformed fields, absent/ambiguous adapters, pending completion, timeout, missing/failed processes, display sanitization, caching and refresh reset. Evidence is `build/gpu-capability-parser-20260911T134304725/results.txt`; its source snapshot SHA-256 matches the production Lua. Fixture inputs are test-only and are not real telemetry. Integrated-only/multiple-discrete hardware, 32-bit processes, additional drivers and long-term performance remain untested.

Repeat the offline check with any existing Python 3.9+ runtime from the repository root:

```powershell
python .\Skins\Parallax\@Resources\Modules\GPU\Validate-GPU.py
.\tools\Test-Parallax.ps1
.\tools\Preview-Parallax.ps1 -Modules GPU -Scale 0.75 -ColumnWidth 180 -Columns 1 -SettleSeconds 4
```

The Python validator uses only the standard library, checks the actual include tree and numeric layout formulas, and makes no changes. It is development tooling under the module's owned path; the existing packaging allowlist excludes `.py` files. It does not interpret Lua or Rainmeter. No dependencies were installed.

### Independent GPU Settings verification

The settings controller passed **141 assertions across 12 cases** under native Rainmeter Lua 5.1. Cases cover no writes/launches on opening or ordinary updates, fixed settings geometry versus saved monitor dimensions, exact-key persistence, provider toggling, height fitting, hive changes, exact ordinal identities, clearing, invalid inputs, pagination, changed-source rejection, unavailable/malformed discovery, independent close and GPU-only refresh. The separate settings validator passed **40 meters across 50 geometry cases** with fixed two-column settings dimensions and no string-box overlap. Fourteen direct PowerShell helper conversion checks covered complete/missing export fields, valid zero, numeric failures, oversize strings and UTF-8 identities.

The full native run is `build/Parallax-gpu-settings-smoke-20260911T231654477Z-d568cbe8`. It replayed the actual gear action to open a second Rainmeter config while GPU stayed active; hash checks found no writes on opening. Column, sensor-toggle and fit-height actions saved and reloaded the GPU monitor while settings remained 416 x 430. A test-only encoded discovery fixture selected `GPU [#0]: Test adapter`, and the complete literal identity survived native file persistence and GPU reload. Closing/reopening settings preserved the mapping and left GPU running; only the staged GPU include changed. Actual discovery returned **MISSING** on this machine, with zero Rainmeter errors. Successful discovery data was simulated only inside the generated test stage, without changing the registry or claiming live HWiNFO coverage.

Default and narrow settings captures were inspected in the full run above and `build/Parallax-gpu-settings-smoke-20260911T231651371Z-f3a92429` (282 x 323). Maximum title/header/body sizes of 12/10/10 pt were inspected at width200/scale1 with border/divider thickness 4 in `build/Parallax-gpu-settings-smoke-20260911T231648757Z-e7c75564`, and width180/scale0.75 with thickness 0 in `build/Parallax-gpu-settings-smoke-20260911T231649741Z-4f01bd09`. Settings controls fit without visible overlap or vertical text clipping. Shared preferences, including both accent colors, were inherited. Actual pointer delivery and launching the external Advanced/Guide editor were not automated; native tests execute the source actions.

Final maximum-font captures waited for the real GPU metadata to finish: `build/Parallax-gpu-settings-smoke-20260911T232034202Z-dd3d2f64` contains width200/scale1 with border/divider thickness 4; `build/Parallax-gpu-settings-smoke-20260911T232034207Z-72ffbf99` contains width180/scale0.75 with thickness 0. Both include `captures/GPU.png`, `captures/GPU-Settings.png` and `metadata-observed.txt`. The full model and driver fit at default width; the narrow model ellipsizes cleanly with full text retained in its tooltip. All capability values, header text and settings controls remain contained, with no vertical cropping or Rainmeter errors. No font preference is clamped by the module.

Repeat these settings checks from the repository root:

```powershell
python .\Skins\Parallax\@Resources\Modules\GPU\tests\Validate-Settings.py
.\Skins\Parallax\@Resources\Modules\GPU\tests\Run-SettingsSmoke.ps1
.\Skins\Parallax\@Resources\Modules\GPU\tests\Run-SettingsSmoke.ps1 -CaptureOnly -MaxTypography -ColumnWidth 180 -Scale 0.75
```

The tests live only in the GPU-owned `tests/` directory and are excluded from distribution. The helper's `.ps1.txt` source was preserved by normal staging. Tests launch and stop only a fresh isolated Rainmeter process; no installed configuration, source preferences, other modules, shared tooling or providers are changed.

## Next steps and extension plan

1. Check actual pointer delivery, keyboard/advanced-editor interactions and long tooltips for GPU Settings. Co-load another GPU counter to exercise the Rainmeter 4.5 name-cache conflict guard. Simulate unavailable counters and collection failures without claiming stale detection.
2. Test real HWiNFO export absence, partial mapping, label mismatch, index drift, real zero, decimal formats, stop/restart and lingering registry values. Confirm that the unknown-age label stays visible throughout.
3. Complete the remaining native width/scale combinations and mixed Windows DPI, then test package upgrade preservation of changed mappings. Existing personalized installations that preserved an earlier `PanelHeight` retain that value; set it to 288 and refresh to make room for the capability inset. Measure Rainmeter CPU / memory with this module alone and with other category consumers; separately account for HWiNFO and one-time GPU metadata startup cost. Exercise integrated-only, multiple-discrete, external-GPU, missing-DXCore and restricted-PowerShell cases.
4. Add adapter selection only with reliable discovery and documented adapter / engine identity. An adapter-total view must aggregate processes per adapter-engine before selecting the busiest engine, or consume an explicitly mapped adapter-load sensor. Never relabel an engine sum as a 0-100 adapter total.
5. Add a sensor-only variant that omits UsageMonitor entirely for users who want exported sensors without that category worker. Consider mapped VRAM, fan and hotspot rows after distinguishing dedicated versus shared memory and the exact sensor semantics.

No shared-file changes are requested by this prototype. All shipped implementation and presentation code is original; no ModernGadgets code or assets were used. Official Rainmeter and Microsoft materials above were consulted for interface semantics, not copied as implementation. HWiNFO remains a separate optional application subject to its own license.
