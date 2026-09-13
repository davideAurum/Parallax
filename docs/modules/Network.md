# Network module report

Network and Connection are now one independently loaded utility: `Parallax\Network`, `Network.ini`. It shows adapter and PC Internet information, Wi-Fi quality, current traffic and both histories in one panel. Network Settings remains a separate editor. The former Connection entrypoint is a compatibility redirect with no telemetry or visible panel.

This is still a prototype. Installed Rainmeter 4.5.26.3894 supplies the native runtime used for isolated checks. Real transfer/WLAN accuracy, sustained cost and mixed-monitor DPI remain acceptance work. No dependencies were installed, live configuration refreshed or release published for this merge.

## Delivered behavior

The single Network header contains the original three-node icon, `bits`/`bytes` control and `1x`/`2x` width control. Below it are the selected adapter alias/model and operational state, Windows' PC-wide Internet report, local address/gateway, reported receive/transmit link speeds, Wi-Fi SSID/quality/radio, then current inbound/outbound rates and separate histories. The traffic sampling state and sample count stay visible.

Click the adapter name or use **Network settings** in the context menu to open the editor. The context menu also retains Global Settings, the module settings-file editor and Windows Wi-Fi settings. There is one monitor width preference; the Connection block no longer has its own title, frame, width control or navigation action.

Rates use native `UseBits=1`. The display uses decimal bit/s, kbit/s, Mbit/s and Gbit/s or binary B/s, KiB/s, MiB/s and GiB/s. Byte display divides bits by eight. Link rates are reported link capacity, not a speed test or measured Internet bandwidth. Traffic includes LAN activity, not just Internet traffic.

Each graph retains up to 60 valid one-second samples without prefilling. It clips only the trace to its independent configured ceiling and reports clipping while an over-ceiling sample remains in history; numeric traffic stays unclipped. Invalid ceilings leave rates usable and show a configuration message. A singleton has no invented predecessor or line segment.

## Appearance and geometry

One shared surface contains all data. Metadata rows use the existing body layout, followed by the shared-thickness Wi-Fi bar and two 42-logical-pixel histories. Icons, lines and history geometry retain their distinct styling. Fonts/colors, borders, section dividers and grid spacing follow [APPEARANCE.md](../APPEARANCE.md). No upstream code or artwork was copied.

The saved `Columns` controls the complete monitor. Its saved `PanelHeight` is a minimum, preserved unchanged. After shared Geometry loads, the monitor computes:

```text
PanelHeightPx = Max(Round(PanelHeight * Scale),
                    Round(464 * Scale) + DataBarThicknessPx)
DataBarThicknessPx = Max(1, Round(DataBarThickness * Scale))
```

At scale 1 and the default 6 px bar, the panel paints 470 logical pixels high. At column width 220 with the default gutter, the window is 228×478 for one column or 456×478 for two. Larger saved minimums remain honored. The legacy Connection height and width do not enlarge or resize the merged monitor.

The Wi-Fi track begins at logical Y=218. Radio follows at `Inset + 220*Scale + DataBarThicknessPx`; traffic content then moves by the same rendered bar height. Both track and valid fill use the shared rounded height, including the one-pixel minimum. The footer ends above the maximum inside border. Scaling a bar does not change quality, cadence or graph history.

## Sources, identity and states

Existing native banks and cadences are preserved within the single skin: two Net measures, five traffic SysInfo measures and the traffic controller update each second; eleven connection SysInfo measures update every two seconds; five enabled WiFiStatus measures update every five seconds; the connection presentation controller updates each second. Economy mode leaves those intervals unchanged. Opening Network now also loads the former companion's work; this is not a claim of the old traffic-only skin's resource cost. The two native metadata banks retain their previous availability/cadence behavior; this merge does not introduce a provider or a polling process.

All adapter-scoped sources use `NetworkInterface`. A valid identity needs a usable GUID and matching selector/alias/description. Unsupported aggregate index zero or an invalid pinned name cannot silently present fallback-adapter traffic. Network discards two transition samples, clears history on identity changes/disconnects/missing readings and resets after a wall-clock gap greater than three seconds or clock rollback. Refresh starts a fresh history.

Native measures expose no per-sample freshness/counter-error flag. A zero on an Up interface can mean idle traffic or an unreported failure. The installed Net source's interface-index/count guard warrants transfer checks on high/noncontiguous indexes. Wall-clock gap detection is a presentation precaution, not a native timestamp. [Installed Net source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureNet.cpp), [selector utility](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Common/NetworkUtil.cpp).

Connection metadata suppresses IP/gateway/link values when identity is invalid or the selected adapter is down, while retaining known identity/state. Adapter Up describes the link, not verified Internet reachability.

**Internet (PC)** is Windows' machine-wide Network List Manager report. `Detected` means reported Internet connectivity on some connection. `Not reported` includes absence of reported connectivity or an unavailable query; it does not establish that the PC is offline. This value stays independent of the selected adapter and does not prove access to a specific site. [Installed SysInfo source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureSysInfo.cpp), [Microsoft connectivity API](https://learn.microsoft.com/en-us/windows/win32/api/netlistmgr/nf-netlistmgr-inetworklistmanager-getconnectivity).

### Wi-Fi source and limitations

Wi-Fi remains a separate WLAN source even though the information shares one panel. Its zero-based enumeration position is not the adapter GUID/alias/Windows interface index used by Network. Ethernet details can therefore appear above a different Wi-Fi connection. Verify the shown SSID on systems with multiple WLAN devices. A nonexistent positive native index may silently fall back to zero, which the panel cannot detect.

Measures begin disabled with safe index zero; Lua validates the query-enabled flag and a digit index from zero through 63 before enabling all five fields with the same index. Invalid settings leave them disabled. The selected list is cached/shared by Rainmeter WiFiStatus; other Wi-Fi skins should use the same index, and such skins may need unloading/reloading after interface/service changes. [WiFiStatus reference](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/wifistatus.html), [installed implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/MeasureWifiStatus.cpp).

A usable SSID plus recognized PHY or a positive native link rate is required before accepting signal quality. A connected reported **0%** stays a measured zero with zero-width fill; unavailable data shows `--` and no colored fill. Connecting/authenticating states show `Pending`. Queries are separate fields, not an atomic snapshot or freshness guarantee. Quality is Windows' 0–100 percentage, not latency, loss or bandwidth. Radio is the reported Wi-Fi standard, not inferred frequency/channel. [WLAN association fields](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_association_attributes).

No hardware, radio off, disconnection, unavailable WLAN service and denied access cannot always be distinguished through native readings. They show an honest unavailable state. Windows 11 24H2 may require desktop-app Location access for current-connection queries; the panel changes no permissions. Native Rainmeter may invoke Windows' prompt/indicator. [Windows Wi-Fi access changes](https://learn.microsoft.com/en-us/windows/win32/nativewifi/wi-fi-access-location-changes).

The radio tooltip includes native WLAN RX/TX link rates when known. Rainmeter 4.5.26.3894 converts Windows' kbit/s fields to bits/s internally despite the WiFiStatus documentation describing kbit/s; this controller formats the returned bits/s without another multiplier. Recheck that behavior when changing the supported runtime.

## Settings

Open `Parallax\Network\Settings`, `Settings.ini` from the adapter click/context action or independently. It follows the [Global Settings structure](../UTILITY-SETTINGS.md): title/close and shared context/global link, aligned labels and compact shaded fields on a 28 px pitch. Traffic display, History scales, Wi-Fi source and Open and apply groups keep their relevant controls. Section names use Accent 1 and `HeaderFontSize`; values use body typography/color; section rules use divider settings independently of table-header styling.

Settings has its own two-column, 598-logical-pixel layout. It reads the module user include as literal data so its own width/height cannot mask saved monitor values. Existing custom and unknown keys are preserved. Missing/invalid choices do not cause writes on load; a nonnumeric height shows `Custom` with its unevaluated literal tooltip.

| Key | Shipped default | Current meaning |
| --- | --- | --- |
| `Columns` | `1` | One or two columns for the entire merged monitor. |
| `PanelHeight` | `236` | Saved minimum; derived content geometry increases the actual height as above. |
| `NetworkInterface` | `Best` | Best, exact adapter alias/description, or positive decimal interface index. |
| `NetworkUnits` | `bits` | Decimal bits/s or binary bytes/s. |
| `NetworkInCeilingMbps` | `100` | Positive inbound graph ceiling in decimal Mbit/s. |
| `NetworkOutCeilingMbps` | `25` | Positive outbound graph ceiling in decimal Mbit/s. |
| `NetworkWiFiEnabled` | `1` | Enable module Wi-Fi queries; does not change the Windows radio. |
| `NetworkWiFiInterface` | `0` | Separate WLAN enumeration position, digits 0–63. |
| `NetworkConnectionColumns` | `1` | Deprecated, preserved and ignored. |
| `NetworkConnectionHeight` | `236` | Deprecated, preserved and ignored. |

Numeric and cyclable fields follow the [shared stepper contract](../UTILITY-SETTINGS.md#numeric-and-cycling-controls): Accent 1 previous/next arrows surround a centered body-colored value. The five numeric centers open validated entry. Bits/bytes arrows wrap and its center switches the choice. Wi-Fi querying remains an On/Off toggle, and the adapter selector retains its existing file-editor action; settings does not discover adapters. Passive field backing has no click action. The existing 28 px row pitch, sections and independent 598 px geometry remain unchanged.

| Numeric field | Arrow behavior | Center input |
| --- | --- | --- |
| Network columns | Decrease/increase by one, stopping at 1 and 2. | Whole number 1 or 2. |
| Minimum height (logical px) | Decrease/increase by one within the editor range. | Positive decimal 0.0001–1,000,000,000, up to four decimals. |
| Inbound/outbound history ceiling (Mbit/s) | Previous/next neighboring preset: 10, 25, 50, 100, 250, 500, 1000. Stop at endpoints without wrapping; a custom value can move inward to its nearest preset. | Positive decimal 0.0001–1,000,000,000, up to four decimals; the presets are not a discrete membership restriction. |
| WLAN source index | Decrease/increase by one, stopping at 0 and 63. | Whole number 0–63. |

The shared editor's bounded decimal syntax does not narrow the existing file format. Existing finer-precision, wider or positive exponent-form numeric values remain preserved and retain their production semantics. Geometry formulas remain literal `Custom` values in settings. When the current saved value is not representable as supported plain decimal input, clicking its center uses the existing file editor; the tooltip explains that fallback. No numeric helper or invented starting value is used in that case. Unsupported current numeric values are not rewritten merely by opening settings. Arrow limits and numerically unchanged edits cause no write or monitor refresh, including equivalent legacy spellings. Persistent actions reread current saved data, write only their allowlisted key, verify it, and request a refresh of Network only.

Numeric entry launches the existing shared PowerShell/WinForms helper once through RunCommand on an explicit click. It receives canonical range/geometry and initial numeric data, no module key or file path. Its fixed completion action sends a bounded ASCII result to the module controller, which validates numeric syntax, precision and key-specific bounds again. A pending edit blocks further persistent actions; completion rejects changed saved values. Arrows and categorical choices launch no process, and settings collects no telemetry.

The adapter field and **Edit settings file** use the existing Notepad editor, retaining exact custom ceilings/indexes and saved-height formulas. Save, then **Apply saved file** to refresh Network and settings. It does not activate a closed monitor. **Show Network**, Global Settings and Close are navigation actions without writes; Close leaves Network running. No standalone Connection options or commands remain.

There is no saved visibility choice to collapse: disabling Wi-Fi queries keeps visible module-off/unavailable rows. Its source/recovery settings remain accessible. Unloaded skins, disconnected adapters and missing providers do not define visibility. Settings uses `Update=-1` with no collection work.

Numeric selector zero, signed/fractional/exponential selector syntax and indexes outside the positive signed 32-bit range are unsupported. Numeric aliases are interpreted as indexes by native Rainmeter. Prefer a unique alias when descriptions collide; indexes can change after hardware changes.

## Migration and integration

`Network/Connection/Connection.ini` is retained only as a compatibility route for old shortcuts. It has `Update=-1`, no measures and a transparent one-pixel bounds meter; on load it activates the canonical Network config and deactivates itself. It must not be advertised as a second utility or included as a standalone visual-preview target.

Network retains existing `Columns`, `PanelHeight`, adapter, units, ceilings and Wi-Fi choices. Legacy Connection geometry keys remain byte-for-byte values in the user include and are never rewritten by the merged UI. No runtime history migrates or persists.

The shared integration owner should expose only Network and Network Settings in navigation/utility indexes, retaining the redirect for compatibility. Distribution must preserve `User/Network.inc` and exclude module `Tests/` and `QA/` trees. No shared integration files were changed by this module task.

## Dependencies

Maintain this list whenever implemented runtimes, providers, helpers or assets change, including unavailable-feature behavior. See the [suite dependency index](../DEPENDENCIES.md), [provider constraints](../PROVIDERS.md) and [packaging requirements](../PACKAGING.md). Planned integrations below are not installed dependencies.

| Component | Classification and lifecycle | Feature, fallback and setup |
| --- | --- | --- |
| Windows and existing Rainmeter | Required, separately installed. Windows 10/11 is the suite target; tested runtime is 4.5.26.3894. | Hosts the skin, native meters and Lua. No installer or standalone executable is bundled; tests do not establish every OS/version combination. |
| Native NetIn/NetOut and SysInfo | Supplied by Rainmeter. Traffic bank at 1 s, connection bank at 2 s as detailed above. | Traffic, identity/status, addressing, link rates and PC-wide Internet report. Invalid identity suppresses selected-adapter values; missing values remain unavailable, with native freshness limitations. |
| Native WiFiStatus and Windows WLAN capabilities/access | Supplied by Rainmeter; five validated, enabled queries every 5 s. Wi-Fi hardware/service/access are conditional. | SSID, quality/bar, radio and link tooltip. Missing/off/disconnected/denied states stay explicit. No additional plugin. Source selection, service caching and Location constraints are documented above. |
| Core.lua, Network.lua, ConnectionCore.lua, Connection.lua | Bundled original Lua, inside Rainmeter; two presentation controllers every 1 s. | Identity/availability, unit formatting, memory-only history and display. Required files; absence is a broken installation, not an optional provider fallback. No external polling helper. |
| Settings.lua, SettingsMeters.inc and shared utility styles/note | Bundled original source; load/user actions only, Update=-1. | Literal saved choices, allowlisted verified writes and scoped navigation. Legacy redirect adds no measures/provider. |
| Native RunCommand, Windows PowerShell 5.1, WinForms and shared SettingsInput.ps1 | Rainmeter-supplied plugin, Windows components and bundled suite helper. One process only when a numeric center is clicked; no installation or polling. | Validated numeric input with Enter/apply and Escape/cancel. A fixed data-only result is revalidated by the module before persistence. Missing helper/runtime affects numeric entry; arrows, file editing and telemetry remain separate. The helper writes no files. |
| Shared includes/user files, IBM Plex Sans and original Shape icons | Bundled appearance/assets, loaded privately with the skin. | Writes require access to the module user include on persistent user actions. Retain the [font notice](../../Skins/Parallax/@Resources/Licenses/NOTICE.txt) and [SIL OFL](../../Skins/Parallax/@Resources/Licenses/IBM-Plex-OFL.txt). No system font installation or icon download. Missing/substitute font fit is not certified. |
| Notepad and Windows ms-settings:network-wifi handler | On-demand Windows UI actions only. | File editing and Windows Wi-Fi settings. Missing handlers affect shortcuts, not telemetry. |
| Additional third-party software, accounts or external services | None in the implemented baseline. | No credentials, public-IP endpoint, ping or speed-test service is needed. |

Economy mode preserves the native/controller intervals. On-demand developer tests/QA also use PowerShell 5.1 and an existing Rainmeter installation; their generated artifacts are not distributed. The numeric editor's separate on-click runtime use is listed above.

## Validation

The numeric/cycling controller revision passes **47/47 isolated Rainmeter tests**. Coverage includes both arrow directions, integer/decimal limits, no wrapping for numeric controls, no write/refresh on unchanged choices, strict protocol/range/precision validation, cancellation, single-use completion, pending-action blocking and rejection after a saved key changes. Existing valid numeric spelling is preserved on equivalent edits; an explicit valid replacement can repair previously invalid source syntax. Legacy expressions and unsupported current decimals use the file-editor fallback, with no helper seed or automatic rewrite. Independent read-only review found no actionable issue in the final controller, entrypoint or meter actions.

Focused stepper native QA passes **3 layouts, 321 intrinsic glyph checks, 31 control/persistence checks and 7 typed-input cases**. Layouts cover width 180/scale 0.75/maximum typography, width 220/scale 1/default typography, and width 220/scale 1/maximum typography, with 107 glyph probes each. Arrow, frame, value and associated label actions retain clear bounds and their shared color roles. A one-physical-pixel tolerance applies only to centered arrow hit bounds versus the passive backing because Rainmeter rounds their positions and dimensions separately; glyph fit, adjacent hit separation and panel/window bounds remain strict. Wi-Fi query-off controls remain accessible, and the passive stepper backing has no action. There are no saved visibility-controlled details to collapse.

The real RunCommand path and shared helper's hidden native WinForms controls exercise valid columns, fractional height, graph ceiling and WLAN-index entry, invalid entry followed by Escape, cancellation and unchanged acceptance. Replay rejection, pending-action blocking, exact Network refreshes, inactive Apply, navigation, unrelated preferences and legacy keys all pass. Closing Settings terminates its verified own PowerShell child in under 3,000 ms while a delayed input is pending, preserving saved preferences and other isolated observer windows. No Rainmeter errors occurred. Test-only instrumentation replaces the copied helper's `ShowDialog` boundary to invoke its real hidden HWND/event handlers; it does not claim displayed-overlay focus, desktop input, provider accuracy or mixed-DPI behavior. The shared helper remains unmodified in production, with SHA256 `6FFC3A1B0E9D373B9317B948F8A1F5B18D9B1277E45C5A66BF83EADFF617631B`.

Final stepper evidence is under `@Resources/Modules/Network/QA/settings-run-54b5c5607233468fb1f1bc5567ebabab/`, including `run-report.json` and `source-agreement.json`. Production controller/meters/shared-source hashes match the tested copies. Both `Captures/NetworkSettings-width180-scale0.75-maximum.png` and `Captures/NetworkSettings-width220-scale1-default.png` were inspected and are clear; these use explicit test appearance preferences. Static validation after the production changes again passed 22 configs and 83 INI/includes with zero errors or warnings. No main-monitor geometry, user preferences or live Rainmeter configuration changed in this settings-control revision.

After the merge, the original production logic suites pass **27 Network tests** and **33 connection tests**. Duplicate adapter output and obsolete companion width persistence were removed from controllers and their target assertions. History, native-data handling, unit/Columns persistence and known-zero versus unavailable signal fixtures remain covered. These execute inside isolated installed Rainmeter, with no live settings changes.

Before the stepper conversion, the merged settings controller passed **30/30 tests**, preserving custom values, inactive-monitor behavior and the deprecated companion keys. Its merge-era native QA passed **20/20 layouts and 1,600 intrinsic glyph checks** at widths 180/220, all five supported scales and default/maximum typography. Actual units/Wi-Fi/index saves refreshed only Network; Global navigation, active/inactive Apply, Show Network and independent Close passed against isolated observer targets. The inert legacy Connection observer was never refreshed, and unrelated/module/global settings remained preserved. No Rainmeter errors occurred. These earlier checks validate the merged editor's routing/lifecycle, not the subsequently added numeric input controls.

Merge-era settings captures were inspected under `@Resources/Modules/Network/QA/settings-run-6bce1a332292490b81d7b7c0ada31b4a/Captures/`: `NetworkSettings-width180-scale0.75-maximum.png` and `NetworkSettings-width220-scale2-maximum.png`. These use explicit test preferences. The default-width/scale settings window remains 456×606; the narrow 75% window is 282×455.

The combined monitor passes **30/30 native cases and 3,390 intrinsic glyph checks**: 29 layout/state/bar cases plus the actual canonical legacy redirect, with 113 glyph probes per case. Coverage includes widths 180/220, all five supported scales, one/two columns, maximum typography and 4 px borders/dividers; representative 1, 2.5, 6 and 12 logical-pixel bar heights; invalid NIC, disabled Wi-Fi queries and malformed WLAN index. Checks cover connection/traffic offsets, graph/grid bounds, valid multi-point history paths, single-sample suppression, one header/panel and legacy geometry ignored while preserved. The real old entrypoint activates Network and deactivates its own one-pixel window, leaving exactly one combined monitor. No preferences were written and no Rainmeter errors occurred. Source hashes matched the isolated tested copies.

Current monitor evidence is under `@Resources/Modules/Network/QA/unified-run-055592b24bfc43b5bf81fa3f0f9c15b6/`. Inspected captures are `Captures/Network-combined-width180-scale0.75-maximum.png` (141×359) and `Captures/Network-combined-width220-scale1-maximum.png` (228×478). Wi-Fi was unavailable on the test machine and its fill stayed hidden. These two captures each show one valid traffic sample after startup/gap resets, so no line is drawn; other matrix cases exercised multi-point histories. They use explicit test appearance preferences and are not evidence of real WLAN accuracy. Pre-merge separate-panel captures are historical.

`QA/Run-UnifiedSmoke.ps1` is the current monitor harness. The old `Run-Smoke.ps1` and `Run-ConnectionSmoke.ps1` commands forward to it. The final shared static validator passed 22 configs and 83 INI/includes with zero errors or warnings. These checks establish tested layout, routing and state handling; transfer accuracy, mixed-monitor DPI and sustained performance remain separate acceptance work.

## Remaining acceptance and extensions

- Compare real transfer rates with Windows/another source, including high/noncontiguous interface indexes, reconnects and suspend/resume.
- On actual WLAN, compare SSID/quality/radio and exercise valid weak signal, pending/disconnect states and access denial without disrupting the user's session merely for a test.
- Inspect long names/addresses, mixed-monitor DPI, supported widths/scales, transparency/snapping and sustained CPU/memory cost before release.
- A native adapter-selection list and optional per-process attribution remain future proposals, with explicit provider/privilege/cost design. No process tracing, packet capture or mandatory service is implemented.

## Originality and primary references

All module production code and visual geometry are original Parallax work. ModernGadgets is visual inspiration only; none of its code or assets were imported.

- [Native Net options](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/net.html).
- [Native SysInfo options](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/sysinfo.html).
- [Shape path syntax](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html).
- [Lua lifecycle, measure and meter API](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html).
