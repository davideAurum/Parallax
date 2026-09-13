# Visualizer

Status: spectrum-focused main layout, read-only Windows default-output volume, four palette modes including Accent 1 → Accent 2 gradient, and separate Audio settings with previous/value/next controls and typed numeric entry are implemented. Native gradient/settings captures and four actual WinForms input-path cases passed; controller and source checks are recorded separately below. Physical hover/click/typing, audio accuracy, broader DPI behavior and performance remain unverified.

## Dependencies

This inventory describes the current implementation. Windows 10/11 and Rainmeter 4.5.26 or newer are the suite's target, as recorded in [README.md](../../README.md); the native checks below cover specific local configurations, not every supported OS/version combination.

| Dependency | Use | Required or optional | Missing fallback | Cadence |
| --- | --- | --- | --- | --- |
| Windows and Rainmeter | Host the independently loaded monitor/settings skins. Native meters, Calc state/volume measures, six static settings String measures and action bangs provide display and control. | Required runtime. | No supported alternative runtime. Without Rainmeter the skins do not run. | Main skin defaults to 50 ms; local 33/100 ms options. Settings uses `Update=-1`; its measures use `UpdateDivider=-1`. |
| Rainmeter's built-in Lua/Script measure | Color.lua assigns solid or gradient band colors on main refresh. Settings.lua owns the nine-key allowlist, previous/next behavior, numeric-entry requests and validated saves. | Required for palette selection and settings interactions; included in Rainmeter, with original Lua files shipped in the module. | Missing scripts disable their corresponding actions; restore the module files and inspect the log. No external Lua installation is used. | Color Apply runs once from OnRefreshAction, with no Update callback or file access. Settings runs on initialization and explicit actions; no recurring collection or helper work. |
| Windows output endpoint, audio driver and audio stack | Supply mixed output-device audio through AudioLevel; blank VisualizerDeviceID follows the default endpoint at capture initialization. | Required for measured spectrum data. | No endpoint/capture availability shows Output unavailable; an explicitly invalid format shows Unsupported format. An available quiet endpoint shows Idle - quiet. No substitute readings. | Capture remains active while the main skin is loaded, including idle. Main display interval does not guarantee equivalent audio-worker throttling. |
| Rainmeter-bundled AudioLevel plugin | One output capture/FFT parent; 24 band children plus RMS, device status/name/format and refresh-only discovery. RMS determines whether bars or the single non-live overlay are shown. | Required for the spectrum; supplied with Rainmeter, not separately downloaded by Parallax. | No alternate capture provider. Failed/unavailable capture hides bands; missing-plugin errors require the Rainmeter log and a working Rainmeter installation. | FFT bands, RMS and state follow the main 33/50/100 ms interval. Device-name text updates about once a second; device-list discovery is refresh-only. |
| Rainmeter-bundled Win7AudioPlugin | One read-only measure for Windows default-output master volume; a native Calc binding supplies numeric text rather than the plugin's device-name string. It reads the default `eRender/eConsole` endpoint, independently of a custom spectrum device. | Required for the volume readout; bundled with Rainmeter. No additional capture parent, helper or download. | Empty/error device metadata displays `--`; the provider's muted value displays Muted. Failed numeric getters can retain an old value even with a valid name, so freshness is not guaranteed. | `Max(1,Round(250/VisualizerEffectiveInterval))` updates: 264 ms at 33 ms, 250 ms at 50 ms, or 300 ms at 100 ms skin cadence. |
| Shared Parallax resources | Defaults, persisted global/module choices, geometry/styles and the settings panel's UtilitySettingsNote. | Required suite files, included with Parallax. | Missing includes have no standalone module fallback; restore the suite files and inspect the Rainmeter log. | Read on load/refresh; preference writes occur only on user actions. |
| Bundled IBM Plex Sans | Shared FontFace appearance; Regular, Medium, SemiBold and Bold load privately from `Skins/Parallax/@Resources/Fonts/`. | Included for the intended appearance; another installed FontFace can be selected. | The module has no explicit alternate-font chain. Select an available installed face if needed; automatic fallback selection and its text fit are not verified. | Font resources are used at load/render; no download or system-wide font installation. |
| Rainmeter-bundled RunCommand, Windows PowerShell and Windows Forms | Open validated numeric entry through the shared `@Resources/Scripts/SettingsInput.ps1` helper with fixed `UtilityNumber` bounds. The helper returns data; Settings.lua validates the intended field and saves it. | Required only for typed numeric entry; no download or installation. Arrows and categorical choices do not launch it. | Unavailable/failed input produces no accepted edit; presets and Advanced file editing remain alternatives. Inspect the Rainmeter log and refresh settings after a failed launch if needed. | One hidden-console PowerShell process with a visible input field only on a numeric-entry action; no launch on settings load, no polling and no helper file writes. |
| Windows Notepad (`notepad.exe`) | Open User/Visualizer.inc through Advanced or the advanced-options context action. | Optional editing convenience; the nine built-in preference controls do not require it. | If unavailable, edit the file with another installed text editor, save and reconnect. No automatic editor substitute. | One launch only when the user invokes the edit action; never polled. |
| Node.js and PowerShell verification tools | Run offline checks and repository static/native preview tooling. | Development/verification only; separate from PowerShell's on-demand numeric-entry role above. | Those checks cannot run without their tools; skins do not invoke the test tooling. | Explicit test runs only. Staged smoke helpers are local evidence, distinct from the shipped Color.lua and Settings.lua controllers. |

Font provenance and distribution terms are retained in [NOTICE.txt](../../Skins/Parallax/@Resources/Licenses/NOTICE.txt) and [IBM-Plex-OFL.txt](../../Skins/Parallax/@Resources/Licenses/IBM-Plex-OFL.txt). The shared files are unmodified IBM Plex Sans from IBM's official repository under SIL OFL 1.1; the module inherits FontFace and does not provision fonts itself.

Opening Audio settings starts neither AudioLevel capture nor Win7Audio polling. Its Lua controller and six String displays are static; numeric entry launches the existing shared helper only on an explicit action, and Advanced launches Notepad only when invoked. Main-panel height/spacing formulas and refresh-only color interpolation add no collection work. Visualizer requires no separately installed provider, companion service, Spotify/player integration, credentials or runtime network connection. Media is independently loadable and is not a dependency; any app's audio can appear when routed through the selected output endpoint.

Maintain this section whenever implementation dependencies change. Record each added or removed provider/helper, whether it ships with Rainmeter or Parallax, required versus optional behavior, missing/unsupported state, capture or polling cadence, and license/provenance paths. Add dependencies only after their runtime path exists; keep proposed integrations and documentation links separate from implemented requirements.

## Delivered behavior

Load `Parallax\Visualizer\Visualizer.ini` separately from Media or other utilities. It uses Rainmeter's bundled AudioLevel plugin: one output capture parent, one FFT configuration, and exactly 24 logarithmic bands over the configured analysis range of 40–16000 Hz. The graph uses the output endpoint's stereo/first-two-channel average. It displays mixed app audio using that endpoint; it is not Spotify-only, an equalizer, a volume control, or an audio processor. No capture data is written to disk.

The current main panel preserves the user's 146-logical-pixel height and double width (`Columns=2`), with selectable Small / Normal / Tall heights and bar spacing/color presets. An original three-stroke icon sits beside the Audio title, with a Windows default-output volume readout visible at the right by default. Below are the clipped spectrum-device row, the spectrum plot with an inside border and horizontal grid, and frequency labels. The retained Normal height provides a 78–80-pixel plot; Small and Tall provide 58–60 and 118–120 pixels. The previous Output mix caption, standalone status row, and Stop / Retry footer buttons remain removed. On skin hover, the readout hides and the original Parallax settings gear appears in its place; mouse-leave restores the readout. FontFace, MediaColor, GraphBackgroundColor, GridColor and other shared appearance settings are inherited. No fonts or assets were downloaded by this module task. The full spectrum-device name, format and mixed-output explanation remain in the device tooltip. No illustrative or fabricated readings are substituted.

Volume is the Windows default render/console endpoint's master setting, not AudioLevel amplitude, app/Spotify volume, or necessarily the manually selected spectrum endpoint. The readout shows an integer 0–100%, Muted for the provider's numeric -1, or `--` when its device metadata is empty or begins with the documented ERROR marker. `MeasureVisualizerVolumeValue` binds the numeric value through Calc because direct String binding would use the device name. The plugin is queried about every quarter-second, with the exact intervals in Dependencies. Parallax sends no volume, mute or device-selection command bangs. The [official Win7Audio documentation](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/win7audio.html) describes its separate numeric/string values; the [reviewed plugin source](https://github.com/rainmeter/rainmeter/blob/v4.5.20.3803/Plugins/PluginWin7Audio/Win7AudioPlugin.cpp) identifies the default endpoint and getter behavior. A numeric getter can fail while device metadata remains valid and leave the prior value in place; the module has no stale-reading guarantee. The added native volume capture below verifies one visible-readout configuration, not physical hover/leave dispatch or all volume/error states.

The [ModernGadgets reference preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png) was inspected for compact density and dark instrument styling. All meters and the header icon remain original; no upstream code or assets are distributed.

| Capture state | Evidence and display |
| --- | --- |
| Unavailable | AudioLevel DeviceStatus is zero; bands are hidden and the centered overlay reads Output unavailable in WarningColor. Capture initialization can fail even if Windows lists an endpoint. |
| Unsupported format | Active endpoint plus AudioLevel Format containing `<invalid>`; bands are hidden and the centered overlay reads Unsupported format in WarningColor. |
| Idle | Endpoint available, no explicit invalid-format marker, and smoothed RMS at or below the configured threshold; bands are hidden and the centered overlay reads Idle - quiet in MutedColor. |
| Active signal | Available endpoint and smoothed RMS above threshold; the 24 measured bands are shown and the overlay is hidden. No live-status caption is displayed. |

DeviceStatus is not a freshness timestamp or a full format-support guarantee. Quiet playback, mute and silence cannot be distinguished by RMS. An empty format string is inconclusive. Other driver/capture problems may require Rainmeter About > Log. FFT arrays can retain old values on empty input, so this module deliberately hides the bars during idle; the plot frame and grid remain visible behind the single overlay. AudioLevel's `Avg` channel uses the first two channels in the reviewed 4.5 source; it is not a surround-wide sum. These behaviors were checked in the [official AudioLevel implementation](https://github.com/rainmeter/rainmeter/blob/v4.5.20.3803/Plugins/PluginAudioLevel/PluginAudioLevel.cpp), not verified through live capture.

## Controls and configuration

- The volume readout starts visible and the 18×18 logical-pixel settings gear starts hidden. Skin mouse-over hides volume and shows the gear; mouse-leave reverses that exchange. Clicking the gear opens `Parallax\Visualizer\Settings`, `Settings.ini`. Hover alone does not load settings, change volume or alter capture; the readout has no volume-control action.
- Audio settings groups nine preferences under Appearance, Performance and Animation, with Advanced and Reconnect in Setup. Each setting has previous/value/next controls. Width, color, quality and interval wrap through categorical choices; clicking their value or label cycles forward. Numeric arrows choose the next strictly lower/higher preset and stop at the ends without writing or refreshing. Clicking a numeric value, label or center frame opens typed entry. Saved custom values remain visible until an explicit edit.
- The main skin's context menu retains Parallax Settings, direct width/quality/cadence choices, Reconnect output device, and Stop capture / unload Visualizer. Its Visualizer options action currently opens `@Resources/User/Visualizer.inc` in Notepad; Notepad launches only on that user action.
- Reconnect output device refreshes only Visualizer, applies saved capture options and reconnects the selected endpoint. Stop capture / unload Visualizer uses `!DeactivateConfig`; reload the main skin from Rainmeter Manage to resume. Neither action remains as a main-panel footer button.
- Context changes write only `@Resources/User/Visualizer.inc` and refresh only Visualizer. No timer performs file writes.

| Settings group | Control | Arrow choices | Center action |
| --- | --- | --- | --- |
| Appearance | Width | Single / Double → Columns 1 / 2 | Cycle forward; Single is standard one-column width |
| Appearance | Height | 126 / 146 / 186 px → PanelHeight | Type exactly 126, 146 or 186 |
| Appearance | Bar gap | 0 / 1 / 3 / 4 px → VisualizerBandGap | Type an integer from 0–4 |
| Appearance | Color | Media / Accent 1 / Accent 2 / Gradient → VisualizerColorMode 0 / 1 / 2 / 3 | Cycle forward |
| Performance | Quality | Low / Normal / High → VisualizerQuality 0 / 1 / 2, using 512 / 1024 / 2048 FFT | Cycle forward |
| Performance | Interval | Suite / 33 / 50 / 100 ms → VisualizerUpdateOverride 0 / 33 / 50 / 100 | Cycle forward; Suite remains an inherited choice |
| Animation | Sensitivity | 10 / 20 / 35 / 50 / 65 / 80 dB → VisualizerSensitivity | Type an integer from 10–80 |
| Animation | Attack | 0 / 50 / 100 / 200 / 2000 ms → VisualizerAttack | Type an integer from 0–2000 |
| Animation | Decay | 0 / 100 / 250 / 500 / 1000 / 5000 ms → VisualizerDecay | Type an integer from 0–5000 |

Audio settings is a static `Update=-1` utility with a local 344-pixel height and double shared-column window width, independently of the spectrum's selected dimensions. It follows the [utility settings contract](../UTILITY-SETTINGS.md) with aligned labels and compact controls. Two inner columns have a 12-pixel logical gap: Appearance and Setup are on the left, Performance and Animation on the right. The imported Columns and PanelHeight values remain available to the controls; only local derived settings-window dimensions are overridden, never saved as spectrum preferences. The shared utility note identifies Visualizer and links Global Settings. Opening the panel initializes its event-driven Lua controller and static displays, without audio capture, volume polling or helper launches.

A valid changed setting writes only its corresponding allowlisted key to User/Visualizer.inc, refreshes the loaded `Parallax\Visualizer`, then refreshes settings. Numeric entry accepts whole numbers without units, expressions or exponents: Enter applies and Escape cancels. The shared helper validates range/precision, and Settings.lua rechecks the returned data, exact field, bounds and height membership before saving. Cancel, invalid results and unchanged values do not write or refresh. A custom numeric value steps to the nearest preset in the selected direction; an unrecognized categorical value selects the first category on an explicit step. Legacy expressions remain available through file editing rather than typed entry.

Advanced opens the local file in Notepad for the device ID, quiet threshold and advanced values; save, then use Reconnect. Reconnect refreshes the loaded main config and settings panel without activating an unloaded Visualizer. The X closes only Audio settings. Capture unloading remains available through the main skin's context menu or Rainmeter Manage. These controls change the visualization; they send no system-volume or mute commands.

The four section headings inherit StyleUtilitySettingsSection, HeaderFontSize and Accent 1 (AccentColor). Labels and current values use body FontSize/TextColor; arrow text uses Accent 1 through the shared stepper styles. The 70-pixel labels leave a six-pixel gap before each group: 18-pixel arrow, two-pixel gap, centered value field, two-pixel gap and 18-pixel arrow. The field expands with column width from a nominal 56 pixels at narrow width. Its frame is 20 pixels high; value/arrows have 18-pixel height one pixel below the frame top. GraphBackgroundColor shades the center field, and BorderColor outlines it. Labels start two pixels below the frame top; rows retain 28-pixel pitch. Advanced uses AccentColor; Reconnect and close use AccentColor2. The shared utility note retains its specified body-minus-one size. Semantic section lines use StyleRule with DividerColor/DividerThickness.

Visualizer has no saved feature show/hide preference, so there are no dependent settings sections to collapse. The nine controls and Advanced device/quiet-threshold options stay available. Main-panel hover and capture availability change transient display state; unloading capture leaves settings and recovery accessible. This revision adds no visibility key.

Main-panel typography and color roles:

| Element | Size | Color |
| --- | --- | --- |
| Audio title | TitleFontSize | TitleTextColor |
| Windows default-output volume | FontSize (body); 60px box × Scale | TextColor, including Muted and `--` text |
| Device name | FontSize (body) | TextColor |
| Frequency labels | FontSize (body) | MutedColor, intentional metadata |
| Non-live overlay | FontSize (body) | WarningColor for unavailable/unsupported; MutedColor for idle |
| Settings gear | Fixed 18px canvas × Scale | AccentColor2; center cutout follows BackgroundColor |
| Identity icon | Title-scaled vector | MediaColor |
| Spectrum bars | Measured bands | MediaColor by default; AccentColor, AccentColor2 or a left-to-right Accent 1 → Accent 2 gradient when selected |

Title, identity icon, volume readout and settings gear share `TitleRowCenterY=Inset+15*Scale`. The Audio title layers `StyleTitleRow` after `StyleTitle`, retaining left alignment with a vertical-center anchor; volume uses RightCenter in a 60-pixel-wide, 18-pixel-high body-text box. The identity drawing is normalized to a 14×14 canvas; its path coordinates, stroke widths, heights and corner radii use `TitleIconScale=Scale*TitleFontSize/10`. At suite scale 1, the icon canvas is 8.4, 14 and 16.8 pixels for 6, 10 and 12 pt titles. Title X follows the growing icon plus TitleIconGap. Its width reserves 66 logical pixels at the right: the 60-pixel readout plus a 6-pixel gap. The fixed 18-pixel gear occupies the right side of that reserved area only while volume is hidden. The gear uses the existing original Parallax vector and suite scaling, independently of title size.

The first device row remains at logical Y=`24+VisualizerTopShift`. The centered title's transparent 22-pixel layout rectangle can overlap the device rectangle by up to 2 logical pixels. Historical native and bundled-font probes found separated text ink for this unchanged title/device arrangement. Subsequent main captures verify the visible readout at standard double width and at narrow single width with Scale=0.75, but do not establish every font/DPI combination. Header checks must include the physical volume/gear visibility exchange and narrower title reservation as well as device/plot separation, overlay containment and frequency-label clearance.

There are no section headers in the main panel, so HeaderFontSize and HeaderTextColor add no main-panel targets. Chosen title/body sizes are used directly, without a clamp or minus-one offset. Title text has 22 logical pixels of height and body rows have 18. Frequency labels retain 50-pixel widths for the maximum body size. This revision preserves saved module/global preferences and capture settings while moving main-panel controls into settings/context actions.

The outer panel inherits BorderThickness and BackgroundColor RGBA through StylePanel. `VisualizerTopShift=Max(0,BorderThickness-2)` moves the device row down by 0–2 logical pixels across the supported border range. The plot starts at Y=`43+VisualizerTopShift`, has height `PanelHeight-66-VisualizerTopShift`, and ends at Y=`PanelHeight-23`. Frequency labels start one pixel later at Y=`PanelHeight-22`. Thus the 126/146/186-pixel panel presets yield 60/80/120-pixel plots before the up-to-two-pixel border adjustment. The retained 146-pixel choice still yields the previous geometry.

Band spacing uses `Round(clamp(VisualizerBandGap,0,4)*Scale)` physical pixels, subtracted within each of the fixed 24 horizontal slots; every bar keeps at least one physical pixel of width. Color.lua applies the selected palette once after meters exist on refresh: mode 0 or an unrecognized mode uses MediaColor, mode 1 uses AccentColor, mode 2 uses AccentColor2, and mode 3 interpolates Accent 1 → Accent 2 across the 24 bands from left to right. Each individual band remains a solid fill; the first and last bands use the two endpoint colors.

Gradient interpolation includes alpha and accepts literal RGB/RGBA or six/eight-digit hexadecimal endpoint colors. Omitted alpha becomes 255; explicit zero stays transparent. Numeric components are rounded and bounded to bytes. Invalid advanced formulas/text fall back independently to the shipped corresponding accent color. The script has no Update callback, file access or recurring appearance work. Identity, volume, gear and state colors retain their roles. Volume remains text, with no scalar bar, so the data-bar audit below remains applicable. The spectrum frame/grid retain BorderColor/GridColor styling, and background alpha is inherited unchanged.

Global data-bar thickness audit, 2026-09-12: Visualizer has no scalar utilization, capacity, level or progress gauge to map to `DataBarThicknessPx`. All 24 `Meter=Bar` meters in View.inc display AudioLevel FFT bands. The RMS child only drives the quiet/active state; it has no visible level bar. The plot frame/grid, identity/gear artwork and settings decoration are separate from the global scalar-bar setting. Consequently, `DataBarThickness` (default 6 logical pixels, supported 1–12) adds no module target, override or new gauge here. The original documentation-only audit preserved implementation and saved preferences, and the existing 540-case validation passed. Subsequent height/spacing controls change FFT geometry explicitly; the new volume readout remains text, so the audit's conclusion still applies.

Edit the module's `[Variables]` settings and refresh. The table distinguishes initial defaults from the retained local width choice; this revision does not reset the user's preferences:

| Key | Initial default / current choice | Meaning |
| --- | --- | --- |
| Columns | Initially 1; current workspace 2 | 1 standard or 2 double width. The current double-width preference is preserved. |
| PanelHeight | 146 | Logical main-panel height. Supported presets are 126 Small, 146 Normal and 186 Tall. Settings-window height is separate. |
| VisualizerBandGap | Initially 1; current workspace 3 | Logical space between spectrum bars, constrained to 0–4 then rounded after scaling. Settings arrows offer 0 / 1 / 3 / 4; typed entry accepts every integer in range. The current preference is preserved. |
| VisualizerColorMode | 0 | 0 MediaColor, 1 AccentColor, 2 AccentColor2, 3 Accent 1 → Accent 2 gradient across the bands; other values use MediaColor. Applies on refresh. |
| VisualizerUpdateOverride | 0 | 0 follows shared VisualizerInterval; local choices are 33, 50 or 100 ms. Other numeric choices fall back to 50. |
| VisualizerQuality | 1 | 0 Low (economy) / 512 FFT; 1 Normal (balanced) / 1024; 2 High (detailed) / 2048. Values at or below 0 select 512, values at or above 2 select 2048; others select 1024. |
| VisualizerDeviceID | blank | Blank selects default output. A user may locally enter an AudioLevel endpoint ID. None is shipped. |
| VisualizerAttack | 50 | FFT attack milliseconds, constrained to 0–2000. Typed entry accepts integers in range; arrows include both bounds. |
| VisualizerDecay | 250 | FFT decay milliseconds, constrained to 0–5000. Typed entry accepts integers in range; arrows include both bounds. |
| VisualizerSensitivity | 35 | Display sensitivity in dB, constrained to 10–80. Typed entry accepts integers in range; arrows include both bounds. Does not alter audio volume. |
| VisualizerIdleThreshold | 0.001 | RMS idle threshold, constrained to 0.00001–0.1. |

The shared `VisualizerInterval=50` default gives a 20 FPS update target. Optional 33 and 100 ms settings target about 30 and 10 FPS. The local override defaults to inheritance so global changes still work. Invalid nonnumeric advanced-option text is not validated; use the settings choices, context menu or documented numeric values.

Bands remain fixed at 24 for both widths and all qualities. FFT overlap stays zero to bound extra work. Increasing FFT size changes frequency resolution and cost, not the number of painted bands. Economy mode provides coarse low-frequency information. The end labels describe the analysis range, not calibrated per-bar center-frequency readouts.

The module includes `MeasureVisualizerDeviceList` as a child with `UpdateDivider=-1`. Inspect its string in Rainmeter About > Skins to discover output IDs, and refresh to rediscover devices. The UI shows the selected device, including when it differs from Windows' new default. Use Reconnect output device after changing the default if the old endpoint remains selected. Automatic default switching is version-dependent.

Parent options must be applied with refresh; only certain child options can be changed dynamically. See the [official AudioLevel option contract](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/audiolevel.html). The module uses documented [Bar meters](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/bar.html), [IfConditions](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/general-options/ifconditions.html), [IfMatch actions](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/general-options/ifmatchactions.html), and [Rainmeter bangs](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/bangs.html).

## Capture lifetime and cost

Unloading the main Visualizer config is the stop-capture control. Use its Stop capture / unload Visualizer context action or Rainmeter Manage. Hiding the panel or gear, muting playback, closing a settings panel or merely disabling a measure is not a capture-release promise. AudioLevel finalizes its parent and releases streams on unload; this was reviewed in source, while actual release on the installed version remains a live acceptance check.

No scripts, shells, external processes or third-party providers poll at runtime. Spectrum, RMS, device status and format use the Visualizer cadence; the device label updates about once a second and discovery is refresh-only. Analysis and capture remain active while idle. AudioLevel can process multiple source channels internally even though the display reads their first-two-channel average. A slower skin interval does not guarantee proportionally less audio processing. No CPU, latency or battery-use claim has been established.

## Geometry and offline validation

Owned implementation files:

- `Skins/Parallax/Visualizer/Visualizer.ini`: loadable config and actions.
- `Skins/Parallax/Visualizer/Settings/Settings.ini`: separate static Audio settings entrypoint and local window geometry.
- `Skins/Parallax/@Resources/User/Visualizer.inc`: persistent choices.
- `Skins/Parallax/@Resources/Modules/Visualizer/Config.inc`: bounded capture options, plot geometry, volume cadence and transient provider flags.
- `Skins/Parallax/@Resources/Modules/Visualizer/Audio.inc`: one AudioLevel parent and children, state transitions, read-only Win7Audio volume and refresh-only spectrum palette selection.
- `Skins/Parallax/@Resources/Modules/Visualizer/View.inc`: original panel and bars.
- `Skins/Parallax/@Resources/Modules/Visualizer/Color.lua`: refresh-only solid/gradient band colors.
- `Skins/Parallax/@Resources/Modules/Visualizer/Settings.inc`: shared-style controls, static String displays, Script and dormant RunCommand bindings.
- `Skins/Parallax/@Resources/Modules/Visualizer/Settings.lua`: event-driven arrow/input validation and allowlisted save actions.
- `Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs`: dependency-free Node offline checks; not required to run the skin.
- `Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate-settings.mjs`: focused offline settings cycle, action and geometry checks; not a runtime dependency.
- `Skins/Parallax/@Resources/Modules/Visualizer/Tests/ColorSuite.lua` and `SettingsSuite.lua`: controller tests with mocked SKIN in an isolated Lua host; not runtime dependencies.

The main config follows the shared include order, joins Group=Parallax and links shared Settings. All actual meters explicitly declare Meter; styles do not. Shared StyleBounds reserves the transparent gutters. Standard and double monitor modes use the same entrypoint; the separate settings config does not replace the capture config.

Run from the project directory:

```powershell
node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs
node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs --title-focus
node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate-settings.mjs
& ./tools/Test-Parallax.ps1
```

The module check parses shipped includes and formulas and simulates declared state actions; it does not emulate Rainmeter. The revised main check passed Node syntax validation and its full 540-case matrix: six widths (180/200/220/240/280/320), five scales (0.75/1/1.25/1.5/2), both Columns values, title 6/10/12 pt profiles, and surface thickness 0/1/4. The focused matrix contains 36 cases: title 6/10/12, scale 0.75/1/2, width 180/220, both columns, and a 4-pixel border. Its separately recorded earlier pass belongs to the historical title-alignment revision; the current full run includes those combinations.

The revised main check covers the removed status/scope/footer targets, alternating gear/readout visibility, one AudioLevel output parent, all 24 band bindings, Win7Audio numeric/error/mute states and update schedules, numeric bounds, single-overlay state transitions and initialization, context reconnect/unload actions, enlarged plot and shape bounds, retained first row, and header centering. The current full 540-case run and the additional 144 height/gap combinations passed, including refresh-only palette/fallback checks. The only intended main-panel text-box overlap remains the transparent title/device region described above.

The focused settings source check passed nine allowlisted controls, 37 displayed preset/end-point choices, custom-value display and 45 fixed label/frame/value/arrow action targets. It verifies one event-driven Script, dormant RunCommand and six static String measures, shared Accent 1 headings/arrows and body values. Forty geometry cases passed: widths 180/220, five suite scales, border/divider profiles 0/4 and imported Columns 1/2. Checks include stepper/frame bounds, 28-pixel pitch, note/section clearance, command spacing and preservation of monitor dimensions. Shared rounding can make the nominal 56-pixel narrow value field less than one physical pixel smaller after scaling. These source checks do not execute Lua, persistence or the input dialog; controller and native evidence follow below.

| Suite scale | Standard 220 standard / double windows | Narrow 180 standard / double windows |
| --- | --- | --- |
| 75% | 171 × 116 / 342 × 116 | 141 × 116 / 282 × 116 |
| 100% | 228 × 154 / 456 × 154 | 188 × 154 / 376 × 154 |
| 125% | 285 × 193 / 570 × 193 | 235 × 193 / 470 × 193 |
| 150% | 342 × 231 / 684 × 231 | 282 × 231 / 564 × 231 |
| 200% | 456 × 308 / 912 × 308 | 376 × 308 / 752 × 308 |

The table contains calculated main-window rectangles for the retained Normal PanelHeight=146. Other supported heights use `Round(PanelHeight*Scale)+Gap` for the window height. Audio settings always uses two shared pitches and `Round(344*Scale)+Gap`; at scale 1 and gap 8 it is 456×352 at width 220 or 376×352 at width 180. Its section headings start at Y=74 for Appearance/Performance, Y=162 for Animation and Y=218 for Setup; the final hint occupies Y=320–338. Mixed-monitor DPI and drag snapping remain unverified. Unsupported font sizes, padding, widths or manual heights outside the presets can break the layout. Current and historical native results are separated below; neither establishes rendering across the whole matrix.

An earlier process-private IBM Plex Sans review measured 65 fixed-text/scale cases. Its 10pt high-frequency width was 42.45 pixels, supporting the retained 50-pixel label box; title/body line heights were 20.80/17.33 pixels inside 22/18-pixel boxes. Long device names intentionally clip with the full value in the tooltip. GDI+ sizing is advisory and is not Rainmeter/DirectWrite rendering evidence.

## Gradient native check

The module task verified a 456×154 isolated main window at ColumnWidth=220, Columns=2, Scale=1 and TitleFontSize=10. A private ColorMode=3 override showed actual spectrum activity colored from the user's purple Accent 1 to green Accent 2, with the real Win7Audio readout at 12%. The plotted readings were not simulated. The Rainmeter log had zero warnings/errors. The source kept ColorMode=0 and the current BandGap=3 preference.

Evidence: [native gradient capture](../../build/Parallax-visualizer-gradient-stepper-163e3636f1b04e7abb5dbc033b474992/captures/Visualizer.png), [native report](../../build/Parallax-visualizer-gradient-stepper-163e3636f1b04e7abb5dbc033b474992/native-Visualizer.txt) and [36-case color suite result](../../build/Parallax-visualizer-gradient-stepper-163e3636f1b04e7abb5dbc033b474992/suite-results.txt). The color suite executes production Color.lua in native Rainmeter Lua with mocked SKIN calls, separately from the real spectrum capture. It checks color behavior without controlling the user's meters or preferences.

## Settings controller and native checks

Production Settings.lua passed 179 cases in native Rainmeter Lua in both default and narrow isolated previews, with zero log warnings/errors. The [controller suite result](../../build/Parallax-visualizer-gradient-stepper-5e81d8c720ba410aa3782de38c3c712a/suite-results.txt) uses mocked SKIN calls: it tests arrow/category rules, numeric bounds and membership, strict result parsing, no-op/cancel behavior and intended save actions without claiming real helper-dialog or persistence coverage.

The module task inspected the [456×352 default-width form](../../build/Parallax-visualizer-gradient-stepper-5e81d8c720ba410aa3782de38c3c712a/captures/Visualizer.png) and the [final 376×352 narrow form](../../build/Parallax-visualizer-gradient-stepper-98ed4b9f38534ae89d15cfd44e48aece/captures/Visualizer.png). The latter used width 180, Scale=1, title/header/body 12/10/10 and border/divider 4. Its private preferences showed Single, Gradient, attack 2000 ms and decay 5000 ms; all fields fit. Its [179-case result](../../build/Parallax-visualizer-gradient-stepper-98ed4b9f38534ae89d15cfd44e48aece/suite-results.txt) passed again, with zero log warnings/errors. These are isolated native rendering and controller checks; no physical mouse dispatch or live installation is claimed.

The [actual numeric-input integration report](../../build/Visualizer-typed-input-8eaddcf981d24585b3141b46765c0664/report.json) passed four cases through production Settings.lua → RunCommand → the unchanged shared WinForms helper → production FinishAction/CommitInput. It replayed the source center action and sent text/key window messages only to the confirmed helper child process; it used neither ValidateOnly nor helper Cancel switches.

| Input case | Observed result |
| --- | --- |
| Spacing 2, Enter | Returned 2, saved only spacing and reloaded it; settings and the passive main refresh witness each refreshed once. |
| Escape | Canceled with no preference-byte change. |
| Spacing 5, Enter | The real form stayed open with no accepted result or save; Escape then canceled. |
| Height 150, Enter | The helper returned 150, but module membership validation rejected it and retained height 146. |

The staged controller/helper hashes matched production and the source User include hash stayed unchanged. The log had zero warnings/errors and all owned helper/Rainmeter processes were closed. The test used a passive main refresh witness and test-only 100 ms reporting; it did not load the audio monitor. This verifies the real helper/persistence path with programmatic window events, not physical input, input-overlay rendering, audio capture or performance.

## Earlier native evidence

These isolated previews establish only their recorded revisions and configurations. They used owned preview instances and local captures, not a live installation or physical mouse dispatch. The shared harness sometimes reports BoundsMeter as missing because its lookup name differs; captured HWND dimensions were obtained independently. All local build artifacts are verification evidence and must not ship.

| Earlier check | Result and limit |
| --- | --- |
| [Title alignment](../../build/Parallax-visual-preview-20260912T212858928Z-bdd06914/captures/Visualizer.png) | 188×154, width 180, single column, scale 1, title 12: separated title/device ink. Predates the expanded plot and current controls. |
| [Pre-volume gear](../../build/Parallax-visual-preview-20260912T233703200Z-009a870b/captures/Visualizer.png) | 456×154, width 220, double column, scale 1, title 12/body 9: 80px plot and right gear. The staged OnRefreshAction executed the production hover action; this was not physical hover proof. |
| [Volume header](../../build/Parallax-visual-preview-20260913T002350705Z-8ba75917/captures/Visualizer.png) | Same main dimensions, real 28% readout and hidden gear. No volume-control, freshness or mute/error-transition claim. |
| [Narrow tall appearance](../../build/Parallax-visualizer-appearance-a394266c403e4a27a73246dd9c46911d/captures/Visualizer.png) | 141×146, width 180, single column, scale 0.75, title 12/body 10, border 4, height 186, gap 3, mode 2: green bands and fitting 26% readout. It used a cloned validated snapshot plus current owned files/styles because concurrent IO work blocked whole-suite staging; not a whole-suite result. |
| [Previous settings form](../../build/Parallax-visualizer-settings-0436cc2e3dfd4079a3f5cc2f71cb7d7b/captures/Visualizer.png) | 376×352, width 180, scale 1, title/header/body 12/10/10 and border/divider 4: compact form fit. Its [30-transition action pass](../../build/Parallax-visualizer-settings-0436cc2e3dfd4079a3f5cc2f71cb7d7b/settings-cycles.txt) preserved preferences and fixed bounds, with no capture/volume poller. It predates the current arrows, numeric editor and gradient choice. |

The four earlier main captures had no log warnings/errors. The previous settings action test had zero errors and 30 expected inactive-main refresh warnings, with no others. These records establish neither current typed-entry behavior nor full DPI, audio accuracy, capture-release or performance acceptance.

## Remaining acceptance and extension plan

1. In an authorized Rainmeter test configuration, play actual audio and confirm measured bands with no live caption, the single non-live overlay, and the device tooltip. Test quiet audio around the threshold, mute, stopped playback, silence, and resume; idle must hide old bars and show Idle - quiet.
2. Test no endpoint, a deliberately invalid local device ID, unplug/reconnect, changing Windows default while the old device stays active, and formats reported invalid. Verify the matching single overlay and Reconnect output device recovery; check logs for errors or repeated messages.
3. Verify the gear is hidden initially, appears on physical skin hover, hides on leave, and opens only Audio settings when clicked. Exercise physical arrows, categorical centers and numeric-entry targets with a loaded Visualizer, plus Advanced, Reconnect, close and Global Settings navigation. Refresh, unload/reload and restart Rainmeter to verify preference preservation, shared cadence inheritance, correct refresh targets, and exactly one capture parent. Clear locally entered device IDs before distribution.
4. Inspect main and settings panels across the remaining width/scale/font combinations and mixed Windows DPI. The recorded main captures cover standard double width and narrow single width with a scaled tall plot; the final settings capture covers narrow double width at maximum supported title/header/body sizes and thick borders/dividers. They do not cover the full supported matrix. Check the shared settings note, long endpoint names, varied fonts, adjacent single panels, title/volume/gear clearance, enlarged plot, overlay centering, frequency labels, settings fields, bounds and snap alignment.
5. Measure Rainmeter CPU and capture lifetime with only the main Visualizer loaded: silence and playback, three intervals, three qualities, both widths, then use the context Stop capture / unload action. Record hardware, endpoint format, sample rate and observation duration. Unloading should remove its capture/analysis cost. No benchmark is currently recorded.
6. After runtime results, consider configurable frequency bounds with validation, mono/surround channel selection, measured low-power presets and more compact diagnostics. Keep the single-parent design and explicit provider states. Audio-processing EQ or app-isolated capture would require a separate capability design.

Proposed shared integration only: preserve User/Visualizer.inc in packaging; retain shared VisualizerInterval=50; optionally expose an explicit Load/Unload Visualizer action in Media or shared Settings. Visualizer adds no background launcher and does not autoload with Media. The integration owner may exclude Tests/ from release packages. No shared files are owned by this module task. The owned files above implement the current main view, read-only volume, bounded appearance choices and separate static Audio settings. The spectrum capture formulas, bounded audio options and one-parent/24-band design are retained. The user's saved Columns=2 and PanelHeight=146 remain preserved; new controls change those values only when invoked.

All module implementation is original. No ModernGadgets code/assets or third-party binaries were copied. Official Rainmeter documentation and source were reviewed for API behavior; no upstream implementation was vendored.
