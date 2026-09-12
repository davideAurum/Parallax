# Network module report

Status: initial prototype restyled to appearance revision 2, with a matching Connection companion added on 2026-09-11. The compact black instruments follow the user's ModernGadgets reference through original meters and the shared palette/font. Native Rainmeter loading and geometry are checked in an isolated instance of the installed Rainmeter 4.5.26.3894. Traffic accuracy, mixed-monitor DPI behavior, and sustained performance remain acceptance work. This module task installed no dependencies, changed no live Rainmeter configuration, and published no release.

## Appearance revision 2

Panel height is now 236 logical pixels, reduced from 364. A small original three-node network icon sits beside the title and compact units/width controls. The adapter subtitle and short operational state remain visible. IN and OUT use aligned compact label/value rows, yellow and green metric rates, ceiling captions, and separate histories. Each history has a thin inner border and horizontal grid lines behind the trace. The later independent-typography update below adapts row spacing and history heights to the selected text sizes. The panel inherits the shared near-black surface, border, IBM Plex Sans `FontFace`, weights, six-pixel padding, and three-pixel corners. No upstream code or artwork was copied.

The telemetry/state core is unchanged. Presentation edits only shorten status/caption/footer wording, adopt shared metric colors, and match the smaller graph geometry; full status details remain in tooltips. Both persistent controls, the 60-sample history, invalid-selector protection, one-second native updates, warm-up, and unknown-history behavior remain intact. Follow [the shared appearance contract](../APPEARANCE.md) for supported font/color changes.

Pixel review found that the width control could render an ellipsis at ColumnWidth=180, Scale=0.75. Its text box is now 22 logical pixels (previously 14); the units box is 38 (previously 30). Header positions reserve the enlarged boxes plus shared padding while leaving 70 logical pixels for the title at width 180. Network-only native captures at 180/0.75/Columns1 and 200/1/Columns1 were inspected after this fix: the title, units, and `1x` are readable, and panel/graph rendering is intact. No telemetry code changed for this correction.

## Delivered behavior

Load `Parallax\Network`, `Network.ini` independently. The panel shows the selected adapter, operational state, inbound/outbound rates, and two separate histories. `Best` is the default selection. The header's `bits`/`bytes` button persists display units; `1x`/`2x` persists `Columns` and refreshes Network. The context menu opens the shared settings skin or the module's settings file.

Two native network measures and five native SysInfo measures update every 1,000 ms, even when global `MetricsInterval` is 5,000 ms in Economy mode. A Lua controller formats their values and keeps at most 60 in-memory sample pairs. It performs no polling subprocesses, packet capture, process tracing, network requests, or periodic file writes. The histories use two Shape paths, with at most 60 points each. Colors and dimensions use shared styles and geometry; transparent outer gutters stay inside the window.

Rates use `UseBits=1` internally. Display units are decimal bit/s, kbit/s, Mbit/s, Gbit/s or binary B/s, KiB/s, MiB/s, GiB/s, respectively. Conversion divides bits by eight before byte scaling. Numeric rates remain unclipped; plots clip to independent configured ceilings and say `clipped` while an over-ceiling sample remains in history. An invalid ceiling leaves the rate usable and displays a configuration message instead of a trace.

Histories fill from the right and cover up to 60 consecutive valid samples, nominally about a minute. They reset on skin refresh, detected adapter/selector changes, disconnection/unavailability, invalid samples, backward/repeated wall-clock seconds, or an update gap longer than three seconds. Unknown samples are never filled with measured-looking zeros. Two updates are discarded after startup, adapter change, reconnect, or a detected long gap to allow native counter baselines to settle. Unit changes retain history; width changes refresh the skin and therefore reset it.

## Connection companion

Open the companion by clicking Network's adapter name or choosing **Show Connection information** from its context menu. It can also load independently as `Parallax\Network\Connection`, `Connection.ini`. Its own `1x`/`2x` control persists `NetworkConnectionColumns`; changing it does not change the traffic panel's width. Its context menu opens Network, the shared settings, the module settings file, or Windows Wi-Fi settings.

The matching 236-pixel panel shows the selected adapter alias and description, link type and operational state, **Internet (PC)** status, local IP, gateway, receive/transmit link speeds, Wi-Fi SSID, signal percentage and colored signal bar, and radio standard. Long values clip within the shared geometry; tooltips preserve complete values. Yellow receive and green transmit values match the traffic panel. The existing Network panel supplies actual inbound/outbound throughput and histories alongside these connection details.

The companion uses eleven native SysInfo measures every two seconds, five native WiFiStatus measures every five seconds, and a one-second presentation controller. These cadences remain fixed under Economy mode. All adapter-scoped SysInfo measures use the same `NetworkInterface` selector as Network. A missing/mismatched identity suppresses its addressing and link rates; a known down/disconnected adapter retains its name and state but shows `--` for those values. Receive/transmit link speed is the rate Windows reports for that interface, in decimal bits/s; it is not a speed test or measured Internet bandwidth.

**Internet (PC)** intentionally describes Windows' machine-wide Network List Manager result. `Detected` means Windows reports Internet connectivity on some connection. `Not reported` includes both lack of reported connectivity and an unavailable native query; it does not assert that the PC is offline. This measure cannot be scoped to the selected adapter and does not prove access to any particular site. It remains independent when a pinned traffic adapter is unavailable. [SysInfo implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureSysInfo.cpp), [Microsoft connectivity API](https://learn.microsoft.com/en-us/windows/win32/api/netlistmgr/nf-netlistmgr-inetworklistmanager-getconnectivity).

The Wi-Fi section is a separate WLAN source. Rainmeter exposes a zero-based WLAN list position, not the adapter GUID, alias, or Windows interface index needed to match it to `NetworkInterface`. With Ethernet selected, the companion can therefore show Ethernet details above a Wi-Fi connection below. Verify the displayed SSID on systems with several WLAN devices. A nonexistent positive WLAN position can silently fall back to position zero; the panel cannot detect that substitution. The shipped index is zero. Configuration accepts digits from zero through 63 and disables querying for malformed/out-of-range inputs. Native measures start disabled with a fixed safe zero index, and the controller applies only a validated index before enabling them. [WiFiStatus reference](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/wifistatus.html), [installed-version implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureWifiStatus.cpp).

Signal quality is Windows' reported 0–100 percentage. A valid connected snapshot with a reported **0%** remains 0%; a failed or unavailable WLAN query shows `--` and an unfilled track. The controller requires an SSID plus a recognized radio standard or positive native link rate before treating numeric signal as usable. Connecting/authenticating reports show `Pending`. Since Rainmeter queries fields separately, this is conservative availability handling rather than an atomic connection snapshot or native freshness guarantee. Signal is not latency, packet loss, Internet speed, or measured throughput. The radio label is the reported Wi-Fi standard, not an inferred frequency band or channel. [Microsoft WLAN association fields](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_association_attributes).

No Wi-Fi hardware, radio off, disconnection, unavailable WLAN service, and permission denial cannot always be distinguished through these native values. They produce an honest unavailable display. Windows 11 24H2 can require desktop-app Location access for the current-connection query; the panel does not change that setting. Native Rainmeter may invoke Windows' access prompt/indicator. If needed, check Windows Location permissions and refresh the panel. Rainmeter also caches the WLAN list and shares its selected WLAN source across loaded WiFiStatus measures: use the same index in other Wi-Fi skins, and unload/reload all such skins after interface/service changes. [Windows Wi-Fi access changes](https://learn.microsoft.com/en-us/windows/win32/nativewifi/wi-fi-access-location-changes), [Rainmeter WiFiStatus implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureWifiStatus.cpp).

The radio tooltip also includes native WLAN receive/transmit link rates when available. Rainmeter **4.5.26.3894** converts Windows' kbit/s fields to bits/s internally, despite the WiFiStatus documentation describing kbit/s; the controller formats the actual returned bits/s without multiplying again. Recheck this behavior when changing the supported Rainmeter version. The module adds no plugin, scan, polling process, ping, public-IP request, or external speed-test endpoint. It writes settings only when the user operates a persistent control.

## Settings

All shipped persistent settings are in `Skins/Parallax/@Resources/User/Network.inc`. Edit and save, then refresh each loaded Network/Connection panel. Skin Packager must preserve this variables file alongside shared user settings. No runtime history is persisted.

| Key | Default | Meaning |
| --- | --- | --- |
| `Columns` | `1` | `1` or `2`, using the shared grid. |
| `PanelHeight` | `236` | Logical panel height; leave at its shipped value for this layout. |
| `NetworkInterface` | `Best` | Best, exact adapter alias/description, or a positive decimal interface index. |
| `NetworkUnits` | `bits` | `bits` for decimal bit rates; `bytes` for binary byte rates. |
| `NetworkInCeilingMbps` | `100` | Positive inbound graph ceiling in decimal Mbit/s. |
| `NetworkOutCeilingMbps` | `25` | Positive outbound graph ceiling in decimal Mbit/s. |
| `NetworkConnectionColumns` | `1` | Independent `1` or `2` column width for the Connection companion. |
| `NetworkConnectionHeight` | `236` | Companion logical height; leave at its shipped value. |
| `NetworkWiFiEnabled` | `1` | `1` enables this panel's native Wi-Fi queries; `0` disables them. This does not change the Windows radio. |
| `NetworkWiFiInterface` | `0` | Native WLAN enumeration position, digits `0` through `63`; independent of `NetworkInterface`. Use `0` for a normal single-WLAN system. |

Use the adapter alias or description from Rainmeter's About information or debug log when pinning an interface. Numeric indexes may change after Windows adapter changes; alias/description is usually easier to maintain. Index `0` (all interfaces), empty selectors, signed/fractional/exponential numeric selectors, and values outside the signed 32-bit positive range are unsupported. A numeric alias such as `123` is inherently interpreted as an index by Rainmeter. For adapters with identical descriptions, prefer a unique alias.

The plotted ceilings are user-chosen chart scales, not speed tests or inferred Internet bandwidth. The selected unit button changes their displayed units but not their configured Mbit/s values. Shared colors, font, `Scale`, and padding may be overridden locally in this variables file according to the architecture contract. The module uses `NetworkInColor`, `NetworkOutColor`, `GraphBackgroundColor`, and `GridColor`; it does not hardcode a font or ship a separate font download.

## Identity, states, and limitations

Presentation requires a canonical nonzero adapter GUID and operational status `Up`; an explicitly disconnected media state suppresses readings. Unknown media state alone does not reject a virtual adapter whose operational status is Up. Other operational states have distinct text, including down, not present, lower layer down, dormant, testing, and unknown. A custom named selector must exactly match the reported alias or description, ignoring case. This prevents silently relabeling fallback aggregate or Best traffic as the requested adapter.

The implementation checks both identity and status because native selector failure behavior differs between Net and SysInfo. The relevant installed-version source was reviewed. `Best` can reselect because every involved native measure has `DynamicVariables=1`; it prefers wired to wireless. It is not a guarantee of the path used by every process, VPN, route, or destination. [Net reference](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/net.html), [SysInfo reference](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/sysinfo.html).

Adapter Up is a link/operational statement, not verified Internet availability. Native measures provide no per-sample freshness or counter-error flag. A reported zero on an Up adapter may mean idle traffic or an unreported native failure; stale values cannot always be detected. In particular, the installed native Net source contains an interface-index/count guard that warrants a transfer check on adapters with high or noncontiguous indexes. Its counters also retain their prior baseline when the selector changes, which is why the module discards transition samples. A native counter reset can still produce an indistinguishable zero. [Rainmeter 4.5.26.3894 Net source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureNet.cpp), [matching SysInfo selector source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureSysInfo.cpp).

NIC traffic includes LAN transfers. It is neither Internet-only traffic nor whole-network Internet usage, and cannot measure other devices' traffic through a router. Virtual/VPN interfaces may represent another view of the same data. This module deliberately has no aggregate or billing-total display. [Official traffic semantics](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/net.html).

Wall-clock gap detection is a presentation precaution, not a native sample timestamp or proof of freshness. Windows scheduling, suspend/resume, clock changes, and native counter behavior still require live QA. No per-process attribution is claimed.

## Validation

Automated results from the final implementation are recorded below. The test-only synthetic inputs exercise state transitions; production display receives only native measures.

- Shared static validator: `tools/Test-Parallax.ps1` passed with zero errors and warnings at the time of this module's check. It verifies includes, meter references, and script paths; it does not validate telemetry.
- `@Resources/Modules/Network/Tests/Run-Tests.ps1`: 27 passed, zero failed using the installed Rainmeter Lua runtime. Tests cover selector fallback, missing/malformed identity, status transitions, warm-up/reconnect/resume, invalid values, bounded history, clipping, units, real controller target names, label sanitization, and writes occurring only at user actions.
- `@Resources/Modules/Network/QA/Run-Smoke.ps1`: **52 passed** covering all five widths (180/200/240/280/320), five scales (0.75/1/1.25/1.5/2), both Columns values, and invalid-name/index-zero cases under `MetricsInterval=5000`. It loads temporary copies of the actual entrypoint, scripts, includes, styles, and locally bundled fonts with native measures; checks real window/meter bounds including the icon and grid meters, native update options and graph path bounds; and confirms the controller/history update. No Rainmeter error log entries were found.

| Suite scale (ColumnWidth=200) | One-column window | Two-column window | Painted panel widths |
| --- | --- | --- | --- |
| 75% | 156 x 183 | 312 x 183 | 150 / 306 |
| 100% | 208 x 244 | 416 x 244 | 200 / 408 |
| 125% | 260 x 305 | 520 x 305 | 250 / 510 |
| 150% | 312 x 366 | 624 x 366 | 300 / 612 |
| 200% | 416 x 488 | 832 x 488 | 400 / 816 |

At the narrowest supported combination (ColumnWidth=180, Scale=0.75), the expected windows are 141 x 183 and 282 x 183. Text meters have fixed widths and clip long adapter labels; the full adapter identity remains available in its tooltip.

Run the test scripts with PowerShell using an existing Rainmeter installation. Both runners create their own settings and an existing isolated SkinPath, keep windows invisible, and stop only their own process. Generated run directories are removed after the check. Tests do not invoke remote operations or change the installed suite's settings. No actual NIC identity, address, credentials, or raw telemetry is saved in the module report.

The smoke test is not a screenshot comparison, throughput comparison, performance measurement, disconnect test, or claim of release readiness. Assertions operate on real Rainmeter meters and native availability but do not prove visual text rendering or accuracy against another source.

Focused post-fix visual evidence is retained outside distributable sources:

- Narrow 180 / scale 0.75 / Columns 1: `build/Parallax-visual-preview-20260911T175547864Z-cb3a13f9/captures/Network.png` (141 x 183).
- Default 200 / scale 1 / Columns 1: `build/Parallax-visual-preview-20260911T175619222Z-68c36658/captures/Network.png` (208 x 244).

Both used `tools/Preview-Parallax.ps1 -Modules Network` with isolated settings and no Rainmeter error log entries. These are actual isolated-window captures with native traffic, not mockups; preview build directories must not be distributed. Mixed-monitor DPI, other configured fonts, and transfer accuracy remain outside this focused visual check.

The focused native glyph regression check (`QA/Run-Smoke.ps1 -ColumnWidths 180`) passed **12/12 cases**, with no Rainmeter error log entries and successful cleanup. It covers both columns at all five supported scales, plus the two unavailable-selector cases, and uses unbounded String probes with the target meter's actual font options to compare measured glyph layout to the usable text box. At width 180 / scale 0.75 / Columns 1, the measured width x height results were:

| Text | Intrinsic native layout | Available text box |
| --- | --- | --- |
| `1x` | 11 x 12 | 16 x 12 |
| `2x` | 11 x 12 | 16 x 12 |
| `bytes` | 23 x 12 | 28 x 12 |
| `Network` | 40 x 13 | 51 x 13 |

The former 14-pixel width box became 10 physical pixels at minimum scale, less than the native 11-pixel requirement. Testing stored `Text` or outer meter bounds alone would miss this clipping, so the native probe is retained in the smoke harness.

In the final expanded run, one Best-adapter snapshot (width 240, scale 2, Columns 1) was in an unavailable/sampling state at the check instant; its bounds and state checks passed. The other 49 Best cases had a valid controller snapshot. Both intentionally invalid selectors correctly suppressed telemetry. This is a layout/behavior pass, not a claim that all native samples were available or accurate.

## Manual acceptance checklist

- [ ] Load/unload Network independently and confirm Settings can close without stopping it; check About for errors.
- [ ] Compare sustained inbound and outbound transfers against Task Manager for the exact same adapter over several seconds. Exercise a LAN transfer and an Internet transfer separately. Check high/noncontiguous interface indexes and unique alias selection.
- [ ] Confirm decimal bits versus binary bytes on the same transfer: 8 Mbit/s is about 976.6 KiB/s. Confirm an Up idle adapter can display zero; do not interpret zero alone as proof of availability.
- [ ] Disconnect/reconnect the selected adapter. Switch wired/wireless while using Best, attach/remove a VPN/virtual adapter, and test a pinned missing adapter. Expect unavailable text and `--`, reset history, and a warm-up before new samples. Do not mix old adapter history with new traffic.
- [ ] Suspend/resume and adjust system time in a disposable test environment. Look for the expected history reset and no transition spike after the warm-up.
- [ ] Set valid small/large graph ceilings, then zero, negative, or nonnumeric ceilings. Check clipping labels, unclipped numeric rates, and a blank trace with a useful message for invalid ceilings.
- [ ] Toggle units, restart Rainmeter, and verify persistence. Toggle widths and refresh; verify persistence and expected history reset. Confirm module settings are preserved in a staged upgrade.
- [ ] Inspect long adapter names, all state messages, large rates, configured fonts, and tooltips at widths 180/200/240/280/320 and 75/100/125/150/200% suite scale. Check side-by-side single versus double snap alignment, transparent gutters, and mixed Windows monitor DPI. The original integration task owns the all-suite visual capture.
- [ ] Confirm no extra helpers/processes remain and measure CPU/memory impact over a sustained workload with the user's full suite loaded. No idle/polling cost target is claimed by this prototype.
- [ ] Load Connection independently and from the Network adapter/context action. Toggle its width and verify only `NetworkConnectionColumns` changes; refresh/restart and confirm both panels retain their independent widths.
- [ ] On an active WLAN, compare SSID, signal quality and radio standard with Windows; test valid weak signal, connecting, disconnect/reconnect, disabled queries and Location denial. Confirm unknown quality never becomes a measured-looking zero. Do not change permissions or disconnect the user's session just to run acceptance.
- [ ] Test Ethernet plus Wi-Fi and multiple WLAN devices. Confirm the PC-wide Internet label and separate WLAN source are understood. Verify the selected SSID after changing WLAN index; unload/reload all WiFiStatus skins after adapter/service changes.

## Extension plan and shared proposals

1. Complete transfer, disconnect, DPI, and sustained-resource QA before release. Recheck native counter behavior when setting the supported Rainmeter baseline.
2. Add an optional adapter-selection UI that lists native identities and warns when a saved selection no longer matches. Any shared settings navigation change belongs to the original integration task; none was made here.
3. Consider configurable history duration after performance measurements. Receive/transmit link-speed metadata is now supplied by the Connection companion; keep chart ceilings separate from link speed and Internet bandwidth.
4. Per-process network attribution is a future opt-in provider, off by default. Design it once for Network, with declared privileges, overhead, attribution limitations, consent, and graceful unavailability. Do not add duplicated process tracing, packet capture, subprocess polling, or a mandatory service to this baseline.

Integration: include `Network\Network.ini` and `Network\Connection\Connection.ini` in shared navigation/packaging as needed and preserve `User\Network.inc`, including the four new companion settings. Existing module-local navigation already connects the two panels. Exclude module `Tests/` and `QA/` from end-user packages if shared packaging policy excludes developer tooling. These are proposals to the original owner; no shared files were edited.

## Originality and primary references

All production module code and its visual layout are original Parallax work. No ModernGadgets code or assets were imported. Official documentation/source was consulted for behavior and syntax, not copied as implementation.

- [Native Net options](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/net.html).
- [Native SysInfo options](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/sysinfo.html).
- [Shape path syntax](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html).
- [Lua lifecycle, measure access, and meter API](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html).
- [Installed-version selector utility](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Common/NetworkUtil.cpp).

Revision-2 validation: **27 logic tests passed, 0 failed; 52 isolated full-skin checks passed** before the header glyph correction. After the correction, **12 focused native checks passed**, including intrinsic layout probes for `1x`, `2x`, `bytes`, and the title; narrow/default actual Network captures were visually inspected. All completed runs used installed Rainmeter 4.5.26.3894 and local copies of bundled fonts, with zero Rainmeter error log entries. Temporary QA files were removed. The shared static check has **0 errors, 0 warnings**. No unresolved Network header clipping, meter-bound, or graph-bound failure remains. All-suite integration review, mixed-monitor DPI, and traffic/performance acceptance remain as described above.

## Connection validation, 2026-09-11

- `Tests/Run-ConnectionTests.ps1`: **32 passed, zero failed** in installed Rainmeter 4.5.26.3894. Synthetic cases cover Wi-Fi setting validation, selected adapter identity/fallback/down states, independent Internet status, missing/error/pending Wi-Fi values, valid 0% signal, quality range/colors, actual native bits/s unit formatting, text sanitization, all five safe measure initializations, cached presentation updates, no polling writes, and the independent width setting. These tests execute the production core/controller; they do not simulate real WLAN accuracy. The isolated runtime was cleaned up.
- `QA/Run-ConnectionSmoke.ps1 -Capture`: **23 passed**, with **161 intrinsic glyph-fit checks** and **552 meter-bounds checks**. It loads actual native SysInfo/WiFiStatus, controller, entrypoint, styles and local fonts in an isolated Rainmeter process. Coverage is widths 180/200 at all five scales and both column choices, plus invalid adapter, invalid WLAN index, and disabled Wi-Fi cases. It verifies header separation, exact 2/5/1-second cadences, safe native indexes, unavailable signal rendering, adapter fallback suppression, and correct independent geometry under Economy settings. No Rainmeter error entries occurred.
- Original traffic-panel regression: **27 passed, zero failed** after adding the companion navigation and tooltip. Shared static validation passed with **zero errors and warnings** after all production changes.
- A final harness correction classifies `Pending`, `Unavailable`, and `--` as unknown signal while keeping numeric `0%` valid. The focused native rerun at width 180 passed **13/13 cases**, with no Rainmeter errors and generated runtime cleanup; the original captures remain retained.

Actual companion captures were inspected at width 180 / scale 0.75 / one column (**141 x 183**) and width 200 / scale 1 / one column (**208 x 244**). Title and width controls are readable, labels/values remain in their rows, long adapter descriptions clip as intended, and there is no unresolved bounds or signal-track overflow. Captures and native reports are retained for local review under `@Resources/Modules/Network/QA/connection-run-2235a2e9efb64a9aa7bc0fb3a9fa4756/`; this entire developer QA directory is excluded from distribution. The images are `Captures/Connection-width180-scale0.75.png` and `Captures/Connection-width200-scale1.png`.

The host was using Ethernet and returned unavailable Wi-Fi data. The native capture consequently shows `Wi-Fi unavailable` and `--`, without fabricated signal. Real connected WLAN quality, Wi-Fi transitions, Windows Location behavior, mixed-monitor DPI, sustained cost, and Internet/transfer accuracy remain manual acceptance work. Tests used offscreen windows and existing installed Rainmeter only; they did not activate a skin in the user's live configuration.

## Independent typography and surface controls, 2026-09-11

Both panel titles inherit `TitleFontSize` and `TitleTextColor`. Network's IN/OUT graph headings use `HeaderFontSize` and `HeaderTextColor`, including header weight 600. Adapter/device descriptions, status text, captions, rates, connection rows and footer text use the full body `FontSize`; the former `FontSize-1` overrides are removed. Body text follows `TextColor`, except meaningful traffic, status and availability colors, which retain their existing semantics. Both width controls layer `StyleSecondaryButton` after `StyleButton` and therefore use `AccentColor2`; Network's units control and original icons retain primary `AccentColor`.

Network reserves additional text space when title/body/header sizes grow. Its graph height is 40 logical pixels at the 10/8/9 title/header/body defaults and 32 at the supported 12/10/10 maxima. The controller, trace and grid use the same derived height, retaining the full history count and configured rate ceilings. Row positions also account for mixed settings such as body 10 with title 10. No selected font size is reduced, and the persisted 236-pixel panel height and independent width preferences are unchanged.

The Connection companion retains its saved height with a 22-pixel title box and 18-pixel body rows. Link labels are abbreviated to RX/TX with descriptive tooltips. The longest operational status displays `Lower layer down`, with the full adapter-type/status text retained in its tooltip. Full adapter and SSID descriptions remain in tooltips when they exceed a row's width.

Outer panel borders inherit shared `BorderThickness` and `BorderColor`, and the Connection section rule inherits `DividerThickness` and `DividerColor` through `StyleRule`. Main Network's graph grid and series keep their graph/data colors and stroke semantics. Background color and transparency continue to inherit `BackgroundColor` unchanged. This module update writes no shared styles or settings, changes no saved user choices, and does not refresh the live suite.

Footer boxes are positioned above the inner edge of the maximum four-pixel panel border. The native harness checks this inner-boundary clearance in addition to the overall window bounds.

Main Network validation: `QA/Run-Smoke.ps1 -ColumnWidths 180,200 -Capture` and the same command with `-MaxTypography` each passed **26/26 native cases**, for **572 intrinsic text-fit probes** across both runs. Each covers both widths, all five scales, both column choices, two invalid selectors and four mixed-font/surface cases. Assertions cover actual font-size/color roles, control separation, row non-overlap, panel border widths 0/4, window/meter bounds, and graph/controller dimensions. History assertions distinguish a valid singleton (no fabricated segment) from two or more points (a real path). Both runs had no Rainmeter error entries. Default and maximum narrow/default-size captures were visually inspected; no actionable text clipping remains.

Main default capture evidence: `QA/run-d5c712f9381d40a1a012c0cee95f953c/Captures/Network-width180-scale0.75-type-default.png` and `Network-width200-scale1-type-default.png`. Main maximum capture evidence: `QA/run-6033845510bb47229de5071ad2d23c24/Captures/Network-width180-scale0.75-type-maximum.png` and `Network-width200-scale1-type-maximum.png`. Paths are relative to `@Resources/Modules/Network`; entire generated QA trees remain excluded from distribution.

The **27 original Network logic/controller tests** passed unchanged. The **32 Connection tests** also passed, including the concise lower-layer-down presentation and full tooltip assertion. These tests do not establish real WLAN accuracy, mixed-monitor DPI behavior, sustained performance, or release readiness.

After the final two-pixel inward footer adjustment, Main Network passed another **26/26 default** cases and **16/16 focused maximum/mixed** cases at width 180 plus the existing 200-wide special cases. The final runs explicitly assert clearance from the four-pixel border's inner edge; both were free of Rainmeter errors. Final default captures are in `QA/run-11ea4c4d8e634d14860b80937fd7a11a/Captures/`, and the final narrow maximum capture is in `QA/run-62e9f2ce1567457fb6b7ad899b0022d3/Captures/`, with the same descriptive filenames above. Final captures were visually inspected.

Connection's final maximum/mixed/surface matrix passed **37/37 cases** using `QA/Run-ConnectionSmoke.ps1 -Typography maximum -TypographyEdges -SurfaceEdges -Capture -TimeoutSeconds 60`. Its **80 glyph probes per case (2,960 total)** check every actual text height and complete finite status/unavailable strings, full IPv4 examples, and representative link-rate units. It also verifies body/title font and color roles, fixed panel height, row/column separation, and divider/border widths 0/4. Native measurements prompted wider Internet/IP/Gateway boxes and the concise lower-layer status; those corrections passed the final matrix. No Rainmeter errors occurred. Maximum-type narrow/default captures were visually inspected under `QA/connection-run-53a0dce27cea4a76bee377e8203634fa/Captures/`, named `Connection-width180-scale0.75-type-maximum.png` and `Connection-width200-scale1-type-maximum.png`.

Connection's default-typography matrix then passed **23/23 cases** with **1,840 glyph probes**, no Rainmeter errors, and no further source changes. Both fresh default captures were visually inspected under `QA/connection-run-7ce2e7c047a34f8dad37b0a324951db5/Captures/`, named `Connection-width180-scale0.75-type-default.png` and `Connection-width200-scale1-type-default.png`. Its combined final coverage is **60 native cases**. The final shared static validator reports **zero errors and zero warnings**. All described runs used installed Rainmeter 4.5.26.3894 and isolated copies of already bundled fonts; no dependencies were provisioned or live configuration refreshed.
