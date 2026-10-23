# Global settings

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when Global Settings changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native meters; shared Parallax includes and `Scripts/Settings.lua` | Required; supplied by Rainmeter or bundled with Parallax | Draws and controls the panel. Event-driven (`Update=-1`), with no collection worker. Stepper arrows defer their refresh with the built-in `!Delay` bang; no plugin. Missing suite source is an incomplete installation. |
| Rainmeter standard RunCommand plugin; Windows PowerShell 5.1, WinForms and System.Drawing | Required for numeric editing; host/Windows components, no extra package installation | One hidden-console helper invocation per clicked numeric field; exits on apply/cancel. If blocked or unavailable, numeric editing cannot complete. Theme, color and other native actions have separate paths. |
| `Scripts/SettingsInput.ps1` and Windows Segoe UI | Bundled helper and platform font | Displays the numeric textbox and returns the fixed validation protocol. No helper-side preference writes or recurring process. |
| `Parallax\Idle` input-idle coordinator (`@Resources/Idle`) | Bundled hidden config; optional feature, Off by default | The Idle pause row only saves `IdlePauseMinutes` and reloads the suite or the coordinator; the coordinator (built-in SysInfo `IDLE_TIME`, one 2 s tick) runs only while something needs it. Missing coordinator files: the hook does nothing and every utility runs as with Off. See [Idle pause](#idle-pause). |
| Parallax ColorPicker config, `ColorPicker.lua` and `ColorMath.lua` | Bundled utility; required for swatch editing | Opens the shared RGB/HSV/Lab picker. Missing picker files prevent visual color selection. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Panel typography; see shared attribution. No system installation. |
| Writable `@Resources/User/Settings.inc` | Required for persistence | Accepted changes save here through Rainmeter. A read-only installation cannot persist them. |
| Windows Notepad | Optional convenience | The Edit settings action opens the include on demand; another editor can be used manually. |

No HWiNFO, Net Monitor, WebNowPlaying, Spotify account or network service is required by Global Settings. Planned theme import/export and launchers are not current dependencies.

The **X** in the top-right corner closes only Global Settings, including while its theme menu is open. Other utilities remain loaded.

Load `Parallax\Settings\Settings.ini` after installing a development copy. **Global Settings** provides a Theme dropdown, twelve numeric fields, nine color swatches and refresh presets. **Appearance** groups the theme, layout, two accents, title/header/body typography, background transparency, panel borders, section dividers, table-header borders and data bar thickness. **Performance** groups the refresh presets and sampling summary. Major section separators use DividerColor/DividerThickness; the Panel style and Text settings column underlines retain the independent table-header border settings. Accepted changes save to `@Resources/User/Settings.inc` and refresh currently loaded Parallax skins; stepper arrows defer that refresh until clicking stops ([arrow refresh debounce](#arrow-refresh-debounce)). Modules must persist their state across refresh; test this before release.

Open Theme and select **Default** to apply the suite's ModernGadgets-inspired appearance in one action. It is the only theme currently available and saves these 37 keys, matching the shipped defaults:

| Group | Saved keys |
| --- | --- |
| Identity, typography and spacing | `Theme`, `FontFace`, `FontSize`, `TitleFontSize`, `HeaderFontSize`, `PanelPadding`, `CornerRadius` |
| Text and accents | `TextColor`, `TitleTextColor`, `HeaderTextColor`, `MutedColor`, `AccentColor`, `AccentColor2` |
| Surfaces | `BackgroundColor`, `BorderColor`, `BorderThickness`, `DividerColor`, `DividerThickness`, `TableHeaderBorderColor`, `TableHeaderBorderThickness`, `DataBarThickness`, `TrackColor` |
| Graphs | `GraphBackgroundColor`, `GridColor`, `GraphHeight` |
| Status | `GoodColor`, `WarningColor`, `DangerColor` |
| Utility colors | `CPUColor`, `RAMColor`, `GPUColor`, `DiskReadColor`, `DiskWriteColor`, `NetworkInColor`, `NetworkOutColor`, `MediaColor`, `ClockColor` |

Selecting Default again reapplies it after customization. Click the dropdown again, click elsewhere in Settings, or move the pointer out of Settings to dismiss without applying.

Themes change shared appearance. Scale, column width, snap gap, collection cadence and module-specific User includes retain their values. The standard column is now 220 logical px, matching the CPU meter's previous widened panel; at scale 1 with an 8 px gap, single/double panels paint 220/448 px inside 228/456 px windows. CPU inherits this shared width. A module's explicit appearance overrides continue to take precedence. `Theme=default` records the last applied base theme; individual edits and color selection may customize that base. Future themes can add named bundles in `Scripts/Settings.lua` and corresponding dropdown choices.

Click a numeric field to edit it in place. Enter applies a valid value; Escape or clicking away cancels. Invalid entries remain editable and show a brief explanation. Decimal fields accept up to two decimal places, using a decimal point. Unit suffixes (`%`, `px` or `pt`, as appropriate) are optional. Width, gap and rounding remain whole-pixel fields.

| Field | Accepted values | Saved variable |
| --- | --- | --- |
| Scale | 75–200%, up to two decimal places | `Scale` as a factor, e.g. 112.5% becomes 1.125 |
| Width | 180–320 logical px | `ColumnWidth` |
| Gap | 0–16 logical px | `Gutter` |
| Rounding | 0–24 logical px; 0 gives square corners | `CornerRadius` |
| Title size | 6–12 pt, up to two decimals | `TitleFontSize` |
| Header size | 6–10 pt, up to two decimals | `HeaderFontSize` |
| Body size | 6–10 pt, up to two decimals | `FontSize` |
| Background transparency | 0–100%, up to two decimals | Alpha channel of `BackgroundColor` |
| Border thickness | 0–4 logical px, up to two decimals | `BorderThickness` |
| Divider thickness | 0–4 logical px, up to two decimals | `DividerThickness` |
| Table header thickness | 0–4 logical px, up to two decimals | `TableHeaderBorderThickness` |
| Data bars | 1–12 logical px, up to two decimals; default 6 | `DataBarThickness` |

Rounding controls the shared panel surface across utilities, including module settings and the color picker. The Default theme restores radius 3 and border/divider thickness 1. Border thickness controls panel outlines; divider thickness controls section separators. Zero hides the corresponding stroke. Graph frames, grids and telemetry strokes retain their separate styling. The **Table header** row controls the lines beneath table column headings independently from section dividers, with its own color swatch and thickness field. It affects the CPU thread/process tables and Global Settings tables. Default restores a gray 1 px line; thickness zero hides it. Sizing is logical geometry scaled by the suite factor, not Windows DPI. Intermediate field values are supported; the established width/scale matrix remains the release baseline for module testing.

The **Data bars** row sets the shared thickness of scalar utilization, capacity and playback progress bars. Default restores 6 logical px, matching the CPU meter's previous bar height. Modules use `DataBarThicknessPx=Max(1,Round(DataBarThickness*Scale))` for their track and fill, and reserve space for the supported range. Thickness rounds to whole screen pixels with a one-pixel minimum, so the smallest bar remains visible at 75% scale. Graph traces, spectrum band geometry, icon strokes and divider lines retain their own settings. This appearance change adds no polling.

Transparency changes only the background fill, preserving its RGB channels. Zero percent is opaque; 100% is fully transparent. The stored alpha is the nearest integer from 0 to 255, and the field displays the percentage derived from that byte. For example, entering `37.5%` saves alpha 159 and displays `37.65%` when read back. There is no separate persisted `BackgroundTransparency` key. The Default theme restores `BackgroundColor=15,15,15,255`.

Each color row displays its current hex code and matching swatch (`#RRGGBB`, or `#RRGGBBAA` when alpha is present). The nine picker targets are:

| Color | Variable | Default |
| --- | --- | --- |
| Accent 1 | `AccentColor` | `137,190,250` |
| Accent 2 | `AccentColor2` | `181,161,226` |
| Title text | `TitleTextColor` | `220,220,220` |
| Header text | `HeaderTextColor` | `175,175,175` |
| Body text | `TextColor` | `220,220,220` |
| Background | `BackgroundColor` | `15,15,15,255` |
| Border | `BorderColor` | `50,50,50,255` |
| Divider | `DividerColor` | `50,50,50,255` |
| Table header border | `TableHeaderBorderColor` | `50,50,50,255` |

Click a swatch to open the reusable `Parallax\ColorPicker` utility, seeded from that selected global color, with RGB, HSV and CIELAB D50 spectrum modes. Preview changes locally, then Apply to write only the selected key, refresh Parallax and close the picker. Background color edits preserve its existing alpha; other targets save opaque RGB. Cancel closes without writing. Opening another target discards the previous preview. Out-of-sRGB Lab selections show a warning and use the clipped color for preview and Apply. See `COLOR-PICKER.md` for channel semantics and gamut handling.

Panel titles use the title controls; section and table headings use header controls; regular labels and values use body controls, with compact size offsets where required. Defaults are 10/8/9 pt respectively, with bundled IBM Plex Sans (SIL OFL 1.1). Shared button styles use Accent 1 for primary actions and Accent 2 for secondary actions. Utility metric colors and semantic status colors remain independent, so changing text or either accent does not recolor every graph or status. A module's explicit appearance overrides still take precedence.

Title size also scales utility icons that lead the title. Those titles and icons share a vertical center, while the title's available width accounts for the enlarged icon and nearby controls. Media's title reads `Media Player: stopped` (`paused` for a paused track), or `Media Player: <player>` while a track plays (`Media:` in the compact layout), in title typography. Its single title icon follows that same title-size contract: Monitor Play when nothing is playing, animated Audio Lines while playing. Gear and close buttons retain their click-target sizes and align to the title row. The saved 12 pt title preference is independent of Media's source name and metadata, which follow Body size; Default retains its 10 pt title preset.

Independent utility settings panels map value text to the body color (`TextColor`), including clickable values, toggles, numbers and available choices. This changes their color only. Action buttons keep their accents, and color swatches plus diagnostic/disabled states retain their semantic colors.

Settings section names use Accent 1 (`AccentColor`), including Global Settings' Appearance, Performance, Panel style and Text settings headings. Independent utility section names retain `HeaderFontSize`; table column labels retain their separate header role. Changing Header color still affects ordinary utility headings and table labels.

Utility settings details should collapse when their corresponding utility feature is hidden by an existing visibility choice. Keep the heading and a show/hide control accessible, remove the hidden controls and their unused space, and restore their saved values when the feature is shown again. This behavior is being applied by the utility owners. An unloaded skin, disabled provider or unavailable reading does not by itself hide a settings section; shared setup and recovery actions stay accessible.

CPU, RAM, GPU, Disk Meter, Chronometer, Network, Media and Audio settings show a short note below the title identifying which utility they control. Click "Global Settings are found here." to open the suite-wide panel. This navigation leaves the utility settings open and does not save or refresh anything. The independent settings panels follow the [shared Global Settings layout](UTILITY-SETTINGS.md), with Accent 1 section headings and body-colored values. [APPEARANCE.md](APPEARANCE.md#independent-settings-conversion) records each panel's sections and current status.

Settings form labels and numeric controls use fixed neutral editor text and 9/8 pt form sizes, scaled with the suite. Its main title still reflects the title controls. The picker's editor text colors, opaque background and border remain neutral while editing other colors; picker font sizes still inherit suite typography. This keeps editing controls distinct from the values being previewed. Settings secondary actions deliberately show Accent 2.

Edit settings opens the user include in Notepad. Save changes, then click Apply saved edits. The module-specific `User/<Module>.inc` is included after global values, allowing intentional overrides. A full module launcher, sensor setup wizard and theme import/export remain future milestones. Content padding defaults to 6 pixels. Module layouts must be checked for clipping across supported font sizes.

The Refresh row cycles Balanced/Economy using either arrow or a forward click on its centered value. Its displayed name is derived from all four saved intervals; unmatched settings show Custom and remain untouched until a preset is chosen. From Custom, Previous chooses Economy and Next/center chooses Balanced. No additional preference key is stored. Balanced requests eligible metrics every second, sensors every two seconds, capacity every 30 seconds and spectrum every 50 ms. Economy requests 2s/4s/60s/100ms respectively. Native network remains 1s, chronometer timing remains independent, and UsageMonitor/HWiNFO may keep their own cadence. Choosing a preset reloads only the skins that read these intervals ([refresh preset scope](#refresh-preset-scope)). These presets are not benchmarked CPU guarantees. Unload optional skins/providers when not needed; closing the settings panel leaves other utilities running.

The settings panel and picker are event-driven (`Update=-1`). Each of the twelve numeric fields launches `Scripts/SettingsInput.ps1` once through Rainmeter's bundled RunCommand plugin, using existing Windows PowerShell 5.1 and WinForms. The console stays hidden; only a borderless textbox appears over the field. It uses the installed Segoe UI font for editing, writes no files and exits on apply/cancel. Its output is a fixed ASCII numeric/cancel protocol. A fixed FinishAction calls Lua, which reads the measure's string value as data, revalidates it, and writes only the corresponding known setting or background alpha. There is no recurring helper process. InputText's raw action interpolation is not used. The helper is one of the exact reviewed packaging exceptions.

Validation at the earlier 200 px checkpoint on 2026-09-11 used installed Rainmeter 4.5.26 / Lua 5.1 with isolated settings INIs and SkinPaths:

- `tools/tests/Test-Settings.ps1`: 449 controller/native-bound checks, including the 34-key theme, include precedence, fixed callback validation, surface/color controls and the default 416 x 652 settings window.
- `tools/tests/test_settings_geometry.py`: 100 baseline size combinations, including popup option bounds.
- `tools/tests/Test-SettingsInput.ps1`: 759 assertions for all field families, unit suffixes, decimal precision, invariant output, adversarial text and private WinForms handles at 100%/75% scale; no textbox was shown.
- `tools/tests/Test-SettingsFields.ps1`: 30 actual native action/RunCommand/callback cases, covering accepted, cancelled and malformed results for all ten fields. Ten saves refreshed Settings and its Parallax witness exactly ten times; the unrelated control never refreshed. Cancelled/malformed results preserved settings bytes, and transparency saved only background alpha. Local report: `build/settings-fields-test-ab0e1a9acd9145a287fee5c240102e9b/report.json`.
- Color picker: 900 assertions and 18 captures across default/narrow layouts, including all eight targets, Apply/Cancel, alpha retention and gamut clipping. Local report: `build/color-picker-test-fd6ba0537e5044f3b156fd3427d1e1fb/report.json`.

The later 220 px standard-width change passes 120 static geometry combinations, including matching single/double snapping widths and settings control bounds. Preview tooling accepts 220 explicitly, and the native test fixtures at that checkpoint expected a 456 x 652 default settings window. Those revised native fixtures have not been run for this change; the native results above remain evidence for the earlier checkpoint.

These local QA artifacts are not distribution files. Native interaction/capture evidence is recorded in [SETTINGS-REVIEW.md](SETTINGS-REVIEW.md). System cursor hit testing, mixed Windows DPI and actual pointer alignment across monitors remain release checks.

The table-header border controls extend Global Settings to a 672 px logical panel (456 x 680 window at default width/scale/gap). Source geometry passed 120 combinations; numeric-helper validation passed 858 assertions with no UI shown. Controller/picker Lua tests and native fixtures were updated for the new controls but were not executed for this change. Historical runtime evidence above remains tied to its earlier source checkpoint.

The subsequent title/icon alignment change passed the 120-case shared settings geometry check and three focused isolated native previews of Global Settings and ColorPicker: title 12 pt at scale 1/width 220, title 6 pt at scale 0.75/width 180, and title 10 pt at scale 2/width 220. All six captures were visually inspected with no clipping or header/control overlap, and all three Rainmeter logs were clean. These previews used copied settings in their own INI/process and did not refresh or change the live configuration. Evidence directories are `build/Parallax-visual-preview-20260912T212946582Z-8ce6006a`, `build/Parallax-visual-preview-20260912T213014680Z-cc7600b7` and `build/Parallax-visual-preview-20260912T213040697Z-74433d13`.

The data-bar thickness integration extends the panel to 700 logical px (456 × 708 at default geometry). The input helper passed 980 assertions, the controller/native bounds fixture passed 596 checks, and shared geometry passed 120 combinations including rounded one-pixel-minimum data bars. Actual isolated Rainmeter actions passed all 36 valid/cancel/malformed field cases: 12 saves produced exactly 12 Parallax refreshes while the unrelated witness remained unchanged. Theme selection passed default and narrow layouts, restoring all 37 appearance keys while preserving size, cadence and module overrides. Default and narrow captures were visually inspected; native logs were clean. Evidence: `build/settings-test-cb2f173f549e4a3bb71b4900d46ff198`, `build/settings-fields-test-deeec90df8374badacca0cacd870ef5d`, `build/theme-dropdown-test-32646395c7c449909e7fb6ffb8bd57a8`, and `build/Parallax-visual-preview-20260913T001142378Z-4b770baf`. These runs used isolated copies; live skins and system pointer/DPI behavior were not exercised.

The later Appearance/Performance split uses a 758 logical px panel (456 × 766 default; 282 × 575 at width180/scale0.75). All 120 geometry combinations pass, including semantic section membership, separator clearance and shifted theme-popup bounds; the controller/native fixture passes 600 checks. Both native theme-layout runs pass and their normal/narrow captures were inspected without clipping. Evidence: `build/settings-test-3d06703d63e94ab3ac5bb20e49d03f14` and `build/theme-dropdown-test-4a9f43e0c86147ed92ffcec1cbc03cf1`. Numeric validation and persistence behavior are unchanged from the 36-case data-bar checkpoint above.

The subsequent Accent 1 section-heading change passed static validation (22 configs, 81 INI/includes, no errors or warnings). An isolated 456 × 766 Global Settings capture shows Appearance, Panel style, Text settings and Performance in the saved purple Accent 1, with neutral table labels and values. The inspected capture and error-free native report are in `build/Parallax-visual-preview-20260913T010518007Z-19f8095a`. This change affects heading colors only; the earlier action and geometry checks remain the behavior baseline. Conditional utility settings changes are tracked separately by their owners.


Numeric controls now use decrement/centered-entry/increment fields, following CPU's precision control. The twelve Global Settings values keep their original ranges and typed-input rules. Arrows change scale by one percentage point, whole-pixel geometry by 1 px, font sizes by 0.25 pt, transparency by one percentage point and stroke/data-bar thickness by 0.25 px. They clamp at bounds and do nothing while a textbox is open or when the saved value is invalid. Transparency still changes only the background alpha, so its displayed percentage reflects 8-bit quantization. Default is the only theme; previous/next arrows are disabled while the central dropdown retains Apply Default. The local 758 px form height is unchanged.

The shared helper also serves utility numeric settings through its bounded `UtilityNumber` mode; each module owns its input range and persistence validation. Cyclable categorical choices use previous/next arrows with the current choice centered. On/off controls, identity pickers and explicit commands retain their roles. See [numeric and cycling controls](UTILITY-SETTINGS.md#numeric-and-cycling-controls) for the shared styles, helper protocol and behavior, and [received validation](TASKS.md#received-control-validation) for the module checks and their limits.


The numeric-stepper integration passed 1,338 Lua/controller and native meter-bound assertions in `build/settings-test-a315495070f94222a853db1a755aff2e`, all 120 geometry combinations and 36 actual native input/callback cases in `build/settings-fields-test-bf0d65ca7e7043cbaca10bd20be20962/report.json`. Twelve valid edits each refreshed the Parallax witness once; twelve cancelled and twelve malformed submissions preserved preferences and no unrelated skin refreshed. Both default 456×766 and narrow 282×575 captures were inspected with no Rainmeter warnings/errors in the Global-only fixture documented in [PREVIEW.md](../tools/PREVIEW.md). Shared input helper tests passed 1,862 assertions. These checks do not modify the live installation or establish mixed-DPI behavior.

The final refresh-profile row adds bidirectional wrapping, Custom detection, four-key persistence and pending-input guards. The final controller/native-bound suite passed 1,494 assertions in `build/settings-test-9975da3fbcb543ce8faebaa8c48cf9f0`, and all 120 geometry combinations passed including its arrow/frame/value bounds. Fresh default/narrow captures were inspected with unchanged window sizes and zero Rainmeter errors; [PREVIEW.md](../tools/PREVIEW.md) records the focused fixture. Final Settings.ini SHA-256 is `92929A9DE79EFC375EC040413FF1C4732E624DD78278ADF01B40A5732E8213AA`; Settings.lua is `267068F999ADC33331A4EEEA40E162F62F6D31973A5ADD44CF450FB366F9E412`. The numeric helper and twelve input paths are unchanged by this final categorical row.

## Idle pause

Owner decision 2 (2026-10-22): the utilities can pause while you are away, **off by default**. The **Idle pause** row sits under Refresh in the Performance section and uses the same cycling control: **Off**, **5 min**, **10 min**, **30 min**, wrapping either way; the centre cycles forward. It saves `IdlePauseMinutes` (0, 5, 10 or 30) in `User\Settings.inc`; `Defaults.inc` and the shipped file hold 0. A hand-edited value shows **Custom**, acts as Off (each utility then logs Rainmeter's missing-include error for `Idle\Hook<n>.inc`, as an unsupported `VisualizerDrawer` does) and is kept until a choice is made here; from Custom, next chooses Off and previous chooses 30 min.

**Apply scope** (the arrow debounce: one apply 800 ms after the last click, at once when Settings closes, folded into any whole-suite reload already due):

- Off to on, or on to Off: `!RefreshGroup Parallax`, once. Every utility gains or loses its stand-down hook (`@Resources/Idle/Hook5/10/30.inc` versus the comment-only `Hook0.inc`).
- 5 to 10 to 30 minutes: `!RefreshGroup ParallaxIdleCoordinator`, which reloads only the hidden `Parallax\Idle` coordinator (silent when it is not loaded; a utility starts it on its next join).
- Back to the value the suite loaded with: nothing.

**What it does** ([shared design](ARCHITECTURE.md#idle-stand-down)): after that many minutes without keyboard or mouse input, each loaded utility freezes in place: its headline is hidden and a muted **Paused (idle)** line takes its place, while the other figures stay visible, frozen; Media and the standalone Audio Visualizer reload into a standby variant that releases their audio capture. The first input resumes them within the coordinator's 2 s tick. `IDLE_TIME` counts keyboard and mouse input only, so gamepad play, video playback and some remote tools can let the pause start.

Layout: the row is 28 px, so `PanelHeight` is 786, up from 758 (the window is 456 x 794 by default, 282 x 596 at 180/0.75). Rows below Refresh moved down by 28 px.

Checks (2026-10-23): `tools/tests/SettingsSuite.lua` 2437 assertions offline (display of every value and Custom, forward and back with wrap, Custom kept until a choice, scope Off/on versus minutes, a burst back to the loaded value reloads nothing, superseded and spent timers, close flush, an appearance save covering a pending idle change, invalid directions); `test_settings_geometry.py` 120 combinations at the new height, including the new row's frame, arrows and actions; `Test-Settings.ps1` PASS (456 x 794); `Test-SettingsRefresh.ps1` PASS with a coordinator witness (`Parallax\Idle`, groups `Parallax | ParallaxIdleCoordinator`): Off to 5 min reloaded the whole group once 0.93 s after the click; 5 to 10 min reloaded only the coordinator 0.81 s after the click, with Settings showing `10 min` in place; a burst 10 to 30 to Off reloaded the group once. Preview captures (isolated, fonts 12): at 456 px the before/after difference is exactly the new 28 px band (0 rows differ above it, 0 below after the shift); at 282 px (180/0.75) the row renders correctly but the comparison is inconclusive, because PrintWindow resamples these tall windows on this host (differences up to 69 per channel spread over the whole image, including rows whose geometry did not change).

## Arrow refresh debounce

Until 2026-10-22 every accepted arrow click ran `!RefreshGroup Parallax`, which reloads every loaded Parallax skin one after another and relaunches each module's helpers (PowerShell starts and C# compiles), so a ten-click Scale change repeated all of that ten times (performance finding SHARED-02).

An arrow click still saves its value at once and updates the field, the layout summary and the color values in place. The suite refresh now waits until 800 ms after the last click, so a burst of clicks reloads each loaded skin once. The panel's own size follows on that refresh. The delay uses Rainmeter's built-in `[!Delay 800]` with a token per click; only the newest click's timer refreshes. Until the refresh, Settings reads the values it has saved rather than its stale loaded variables, so consecutive clicks, background transparency included, step from the saved value.

Every other commit stays immediate: typed entry, Default, a refresh preset, Apply saved edits and ColorPicker Apply. Each of these, and a color swatch click, applies a pending arrow change at once; the picker opens only after the posted refreshes, so the reload cannot reset its new target. Closing or unloading Settings applies a pending change through `OnCloseAction`, because unloading discards the timer. While a numeric textbox is open the refresh waits, since reloading Settings would close the editor: Enter applies both, while Esc or an invalid entry restarts the delay.

Validation on 2026-10-22, Rainmeter 4.5.28:

- `tools/tests/SettingsSuite.lua`: 1,878 assertions offline through OBS's LuaJIT and 1,996 Lua and meter-bound checks in `Test-Settings.ps1`. New cases cover bursts that step from saved values (Scale and transparency), stale and superseded timers, token bounds after the CRT clock wraps, an open editor holding the refresh, each immediate commit applying a pending change, and the close flush.
- `tools/tests/Test-SettingsRefresh.ps1` (new): runs the real arrow, refresh-row and close actions in an isolated instance with stand-in witness skins, leaving Settings at `Update=-1`. Five Scale clicks saved 1.05 and drew `105%` before any reload; the only changed capture rows were the Scale field and the layout summary. Settings and every Parallax witness then reloaded exactly once, 0.93–1.08 s after the last click across three runs (the 0.8 s delay plus reload time). Three transparency clicks saved alpha 246 (the stale value would give 252), again with one reload. A refresh preset reloaded at once (0.12–0.15 s). Closing Settings 0.1 s after a click still applied it once. The unrelated control skin never reloaded, and the log had no errors or warnings.
- `Test-SettingsFields.ps1` (12 typed saves, 12 single refreshes), `Test-ThemeDropdown.ps1`, the 120-case geometry check and `tools/Test-Parallax.ps1` pass. A resting Global Settings preview is pixel-identical to the previous build.

Not exercised: physical pointer input, the real module skins and their helper relaunch cost, and the live configuration. The saving itself is left to the suite benchmark.

## Refresh preset scope

A Balanced/Economy choice saves the four interval keys at once, as before, but no longer reloads the whole suite (SHARED-02). It refreshes only the skins that read them:

| Key | Read by | Refreshed as |
| --- | --- | --- |
| `MetricsInterval` | GPU and Memory Meter `Update`; GPU dividers and helpers; RAM's PAGE host | `ParallaxGPU`, `ParallaxRAM` groups |
| `SensorInterval` | GPU sensor dividers and helpers | `ParallaxGPU` group |
| `CapacityInterval` | Disk Meter capacity and inventory measures | `ParallaxIO` group |
| `VisualizerInterval` | `Modules/Visualizer/Options.inc`, included by Audio and Media | `Parallax\Visualizer`, `Parallax\Media` by name |

CPU, Network, Chronometer, Welcome, ColorPicker, the utility settings panels and Global Settings itself are not reloaded. CPU uses its own `CPUUpdateInterval`/`CPUSensorInterval`. Global Settings shows the new preset name and sampling summary in place. The Disk Meter settings panel includes the capacity measures but runs at `Update=-1`, so it is not refreshed. Audio and Media have no group of their own; they are refreshed by name, and when one is not loaded Rainmeter logs a "not active" warning and loads nothing. If an arrow refresh is pending, the preset refreshes the whole suite once instead. A key with no listed consumer would also refresh the whole suite.

Validation on 2026-10-22, Rainmeter 4.5.28:

- `SettingsSuite.lua` checks that each preset refreshes exactly those five targets, never `Parallax` or Settings, shows the preset in place, and steps a second click from the saved preset: 1,882 assertions offline and 2,000 checks in `Test-Settings.ps1`.
- `Test-SettingsRefresh.ps1` reloaded the GPU, RAM, IO, Visualizer and Media witnesses once each, 0.01 s after the click. Settings, the Parallax-only witness and the control did not reload, and Settings showed Economy and `Metrics 2s  Sensors 4s  Disk 60s  Spectrum ~10 FPS` from its saved values. A preset clicked 0.1 s after an arrow refreshed the whole suite once, 0.17 s after the click, with no second refresh when the arrow's timer expired.
- `tools/Test-Parallax.ps1` passes, and the resting Global Settings preview is still pixel-identical to the build before SHARED-02.

The inactive-config warning was read from the 4.5.28 bang code, not reproduced. Group membership for Audio and Media (owned by those modules) would make it silent.
