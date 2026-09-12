# Visualizer

Status: compact appearance revision 2 with semantic typography, Accent Color 2 and shared surface controls implemented; offline validation passed on 2026-09-11. Live audio, Rainmeter rendering and performance remain unverified. The running Rainmeter 4.5.26.3894 installation was inspected read-only; no live settings were changed.

## Delivered behavior

Load `Parallax\Visualizer\Visualizer.ini` separately from Media or other utilities. It uses Rainmeter's bundled AudioLevel plugin: one output capture parent, one FFT configuration, and exactly 24 logarithmic bands over the configured analysis range of 40–16000 Hz. The graph uses the output endpoint's stereo/first-two-channel average. It displays mixed app audio using that endpoint; it is not Spotify-only, an equalizer, a volume control, or an audio processor. No capture data is written to disk.

The 146-logical-pixel panel follows appearance revision 2: an original three-stroke blue icon beside a short Audio header, compact device and full-width status rows, a 42-pixel spectrum plot with an inside border and subtle horizontal grid, frequency labels, and small Stop / Retry footer actions. It replaces the original 232-pixel card. FontFace, MediaColor, GraphBackgroundColor, GridColor and other shared appearance settings are inherited. No fonts or assets were downloaded by this module task. Long device names have a fixed clipped row with the full name and format in the tooltip. No illustrative or fabricated readings are substituted.

The [ModernGadgets reference preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png) was inspected for compact density and dark instrument styling. All meters and the header icon remain original; no upstream code or assets are distributed.

| Status | Evidence and display |
| --- | --- |
| OUTPUT UNAVAILABLE | AudioLevel DeviceStatus is zero; graph is hidden. Capture initialization can fail even if Windows lists an endpoint. |
| FORMAT UNSUPPORTED | Active endpoint plus AudioLevel Format containing `<invalid>`; graph is hidden. |
| IDLE - QUIET | Endpoint available, no explicit invalid-format marker, and smoothed RMS at or below the configured threshold; graph is hidden. |
| LIVE - MIXED OUTPUT | Available endpoint and smoothed RMS above threshold; the 24 measured bands are shown. |

DeviceStatus is not a freshness timestamp or a full format-support guarantee. Quiet playback, mute and silence cannot be distinguished by RMS. An empty format string is inconclusive. Other driver/capture problems may require Rainmeter About > Log. FFT arrays can retain old values on empty input, so this module deliberately hides the graph during idle. AudioLevel's `Avg` channel uses the first two channels in the reviewed 4.5 source; it is not a surround-wide sum. These behaviors were checked in the [official AudioLevel implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.20.3803/Plugins/PluginAudioLevel/PluginAudioLevel.cpp), not verified through live capture.

## Controls and configuration

- STOP unloads only this config with `!DeactivateConfig`. Reload it from Rainmeter Manage to resume.
- RETRY refreshes this config, applies saved capture options and reconnects the selected endpoint.
- The context menu opens Parallax Settings, edits Visualizer options in Notepad, selects width/quality/cadence, reconnects or unloads. Notepad is launched only by a user action.
- Context changes write only `@Resources/User/Visualizer.inc` and refresh only Visualizer. No timer performs file writes.

Shared typography and action roles:

| Element | Size | Color |
| --- | --- | --- |
| Audio title | TitleFontSize | TitleTextColor |
| Device name | FontSize (body) | TextColor |
| Output mix / frequency labels | FontSize (body) | MutedColor, intentional metadata |
| Status / unavailable overlay | FontSize (body) | Existing GoodColor, WarningColor or MutedColor state |
| Stop | FontSize (body) | AccentColor |
| Retry | FontSize (body) | AccentColor2 via StyleSecondaryButton |

There are no section headers, so HeaderFontSize and HeaderTextColor add no targets here. The chosen title/body sizes are used directly, without a clamp or minus-one offset. Title text has 22 logical pixels of height and body rows have 18; the chart shrank by four pixels to keep the user's 146-pixel panel height. Wider frequency labels and the Output mix caption accommodate the maximum body size. No saved module/global preferences, capture settings or actions changed in this typography revision.

The outer panel inherits BorderThickness and BackgroundColor RGBA through StylePanel. At thicknesses above 2 logical pixels, derived layout values shift the title/device/status rows down by up to 2 pixels and reduce the plot height from 42 to 40, retaining the same panel height and selected fonts. Content stays inside the maximum 4-pixel border. There are no section separators or table rules in Visualizer, so DividerColor/DividerThickness have no local target; the spectrum outline and grid retain their existing BorderColor/GridColor styling. Background transparency is inherited without rewriting its alpha.

Edit the module's `[Variables]` settings and refresh. All supported persistent module keys ship with defaults:

| Key | Default | Meaning |
| --- | --- | --- |
| Columns | 1 | 1 standard or 2 double width, changed through context actions. |
| PanelHeight | 146 | Logical panel height. Keep 146 for the supported compact layout. |
| VisualizerUpdateOverride | 0 | 0 follows shared VisualizerInterval; local choices are 33, 50 or 100 ms. Other numeric choices fall back to 50. |
| VisualizerQuality | 1 | 0 economy / 512 FFT; 1 balanced / 1024; 2 detailed / 2048. Values at or below 0 select 512, values at or above 2 select 2048; others select 1024. |
| VisualizerDeviceID | blank | Blank selects default output. A user may locally enter an AudioLevel endpoint ID. None is shipped. |
| VisualizerAttack | 50 | FFT attack milliseconds, constrained to 0–2000. |
| VisualizerDecay | 250 | FFT decay milliseconds, constrained to 0–5000. |
| VisualizerSensitivity | 35 | Display sensitivity in dB, constrained to 10–80. Does not alter audio volume. |
| VisualizerIdleThreshold | 0.001 | RMS idle threshold, constrained to 0.00001–0.1. |

The shared `VisualizerInterval=50` default gives a 20 FPS update target. Optional 33 and 100 ms settings target about 30 and 10 FPS. The local override defaults to inheritance so global changes still work. Invalid nonnumeric text is not validated; use the menu or documented numeric values.

Bands remain fixed at 24 for both widths and all qualities. FFT overlap stays zero to bound extra work. Increasing FFT size changes frequency resolution and cost, not the number of painted bands. Economy mode provides coarse low-frequency information. The end labels describe the analysis range, not calibrated per-bar center-frequency readouts.

The module includes `MeasureVisualizerDeviceList` as a child with `UpdateDivider=-1`. Inspect its string in Rainmeter About > Skins to discover output IDs, and refresh to rediscover devices. The UI shows the selected device, including when it differs from Windows' new default. Use RETRY after changing the default if the old endpoint remains selected. Automatic default switching is version-dependent.

Parent options must be applied with refresh; only certain child options can be changed dynamically. See the [official AudioLevel option contract](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/audiolevel.html). The module uses documented [Bar meters](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/bar.html), [IfConditions](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/general-options/ifconditions.html), [IfMatch actions](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/general-options/ifmatchactions.html), and [Rainmeter bangs](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/bangs.html).

## Capture lifetime and cost

Unloading is the stop-capture control. Hiding the panel, muting playback, closing shared Settings or merely disabling a measure is not a capture-release promise. AudioLevel finalizes its parent and releases streams on unload; this was reviewed in source, while actual release on the installed version remains a live acceptance check.

No scripts, shells, external processes or third-party providers poll at runtime. Spectrum, RMS, device status and format use the Visualizer cadence; the device label updates about once a second and discovery is refresh-only. Analysis and capture remain active while idle. AudioLevel can process multiple source channels internally even though the display reads their first-two-channel average. A slower skin interval does not guarantee proportionally less audio processing. No CPU, latency or battery-use claim has been established.

## Geometry and offline validation

Owned implementation files:

- `Skins/Parallax/Visualizer/Visualizer.ini`: loadable config and actions.
- `Skins/Parallax/@Resources/User/Visualizer.inc`: persistent choices.
- `Skins/Parallax/@Resources/Modules/Visualizer/Config.inc`: derived bounds and transient format flag.
- `Skins/Parallax/@Resources/Modules/Visualizer/Audio.inc`: one parent, children, state transitions.
- `Skins/Parallax/@Resources/Modules/Visualizer/View.inc`: original panel and bars.
- `Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs`: dependency-free Node offline checks; not required to run the skin.

The config follows the shared include order, joins Group=Parallax and links shared Settings. All actual meters explicitly declare Meter; styles do not. Shared StyleBounds reserves the transparent gutters. Standard and double modes use the same entrypoint.

Run from the project directory:

```powershell
node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs
& ./tools/Test-Parallax.ps1
```

The module check parses shipped includes and formulas. It passed: one output parent, all 24 unique indices and meter bindings, bounds on numeric settings, all four status paths, idle/unavailable/unsupported blanking, recovery transitions, unload/retry actions, local write scope, and all 300 geometry/font/surface cases: five widths (180/200/240/280/320), five scales (0.75/1/1.25/1.5/2), both Columns values, and default (title/header/body 10/8/9 pt) plus maximum (12/10/10 pt) font profiles, with BorderThickness/DividerThickness set to 0, 1 and 4. The divider settings have no rendered target in this module; the panel border and content clearance are checked at each thickness. Checks also verify title/body font selection without silent offsets, title/body/metadata colors, separate primary/secondary action accents, and unchanged spectrum color. Shape strokes stay within their declared rectangles, all content stays inside the panel border, all 24 bars stay inside the plot, and header/row/footer targets do not overlap. It simulates the declared state actions; it does not emulate Rainmeter.

| Suite scale | Default 200 standard / double windows | Narrow 180 standard / double windows |
| --- | --- | --- |
| 75% | 156 × 116 / 312 × 116 | 141 × 116 / 282 × 116 |
| 100% | 208 × 154 / 416 × 154 | 188 × 154 / 376 × 154 |
| 125% | 260 × 193 / 520 × 193 | 235 × 193 / 470 × 193 |
| 150% | 312 × 231 / 624 × 231 | 282 × 231 / 564 × 231 |
| 200% | 416 × 308 / 832 × 308 | 376 × 308 / 752 × 308 |

These are calculated rectangles, not rendered screenshots. Checks confirm positive bar widths, ordering, fixed content bounds and even gutters. Mixed monitor DPI, font rendering and drag snapping remain unverified. Typography was checked through the new UI maxima. Unsupported font sizes or changes to PanelPadding, ColumnWidth outside the supported set, or PanelHeight can still break the fixed layout; the table uses the revised shared geometry and font settings. Native screenshot capture belongs to the integration task; it was not run by this restyle task. No concrete native rendering issue is established yet, but final glyph clipping, grid visibility, and icon alignment still need screenshot review.

The whole-suite static validator run during this typography revision reported 20 configs, 65 INI/include files, zero errors and zero warnings. This is static validation, not release acceptance. An independent read-only font review measured 65 fixed-text/scale cases with process-private bundled IBM Plex Sans. At maximum size, the longest status measured 151.79 logical pixels inside the narrow 168-pixel row. The 10pt high-frequency label measured 42.45 pixels, so its width was expanded from 42 to 50; Output mix was expanded to 80. The measured title/body line heights of 20.80/17.33 fit the 22/18-pixel boxes. Long device names intentionally clip with the full value retained in the tooltip. GDI+ sizing is advisory and is not Rainmeter/DirectWrite rendering evidence.

## Remaining acceptance and extension plan

1. In an authorized Rainmeter test configuration, play actual audio and confirm bands, status and device tooltip. Test quiet audio around the threshold, mute, stop, silence, and resume; an idle graph must not freeze at old values.
2. Test no endpoint, a deliberately invalid local device ID, unplug/reconnect, changing Windows default while the old device stays active, and formats reported invalid. Verify RETRY recovery and check logs for errors or repeated messages.
3. Change each menu setting, refresh, unload/reload, and restart Rainmeter. Verify preservation, shared cadence inheritance, and exactly one parent instance. Clear locally entered device IDs before distribution.
4. Inspect both widths at all five suite scales and mixed Windows DPI. Use long endpoint names, varied fonts and adjacent single panels to check clipping, bounds and snap alignment.
5. Measure Rainmeter CPU and capture lifetime with only Visualizer loaded: silence and playback, three intervals, three qualities, both widths, then STOP/unload. Record hardware, endpoint format, sample rate and observation duration. Unloading should remove its capture/analysis cost. No benchmark is currently recorded.
6. After runtime results, consider configurable frequency bounds with validation, mono/surround channel selection, measured low-power presets and more compact diagnostics. Keep the single-parent design and explicit provider states. Audio-processing EQ or app-isolated capture would require a separate capability design.

Proposed shared integration only: preserve User/Visualizer.inc in packaging; retain shared VisualizerInterval=50; optionally expose an explicit Load/Unload Visualizer action in Media or shared Settings. Visualizer adds no background launcher and does not autoload with Media. The integration owner may exclude Tests/ from release packages. No shared files were edited by this module task. The latest typography/surface revision changed only Modules/Visualizer/View.inc, Modules/Visualizer/Config.inc (derived layout values only), Modules/Visualizer/Tests/validate.mjs, and this report. Earlier appearance work set PanelHeight=146 and shortened two overlay strings. Capture formulas, state transitions, saved settings, and actions remain unchanged.

All module implementation is original. No ModernGadgets code/assets or third-party binaries were copied. Official Rainmeter documentation and source were reviewed for API behavior; no upstream implementation was vendored.
