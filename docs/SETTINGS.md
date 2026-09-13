# Global settings

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when Global Settings changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native meters; shared Parallax includes and `Scripts/Settings.lua` | Required; supplied by Rainmeter or bundled with Parallax | Draws and controls the panel. Event-driven (`Update=-1`), with no collection worker. Missing suite source is an incomplete installation. |
| Rainmeter standard RunCommand plugin; Windows PowerShell 5.1, WinForms and System.Drawing | Required for numeric editing; host/Windows components, no extra package installation | One hidden-console helper invocation per clicked numeric field; exits on apply/cancel. If blocked or unavailable, numeric editing cannot complete. Theme, color and other native actions have separate paths. |
| `Scripts/SettingsInput.ps1` and Windows Segoe UI | Bundled helper and platform font | Displays the numeric textbox and returns the fixed validation protocol. No helper-side preference writes or recurring process. |
| Parallax ColorPicker config, `ColorPicker.lua` and `ColorMath.lua` | Bundled utility; required for swatch editing | Opens the shared RGB/HSV/Lab picker. Missing picker files prevent visual color selection. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Panel typography; see shared attribution. No system installation. |
| Writable `@Resources/User/Settings.inc` | Required for persistence | Accepted changes save here through Rainmeter. A read-only installation cannot persist them. |
| Windows Notepad | Optional convenience | The Edit settings action opens the include on demand; another editor can be used manually. |

No HWiNFO, Net Monitor, WebNowPlaying, Spotify account or network service is required by Global Settings. Planned theme import/export and launchers are not current dependencies.

The **X** in the top-right corner closes only Global Settings, including while its theme menu is open. Other utilities remain loaded.

Load `Parallax\Settings\Settings.ini` after installing a development copy. **Global Settings** provides a Theme dropdown, twelve numeric fields, nine color swatches and refresh presets. **Appearance** groups the theme, layout, two accents, title/header/body typography, background transparency, panel borders, section dividers, table-header borders and data bar thickness. **Performance** groups the refresh presets and sampling summary. Major section separators use DividerColor/DividerThickness; the Panel style and Text settings column underlines retain the independent table-header border settings. Accepted changes save to `@Resources/User/Settings.inc` and refresh currently loaded Parallax skins. Modules must persist their state across refresh; test this before release.

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

Title size also scales utility icons that lead the title. Those titles and icons share a vertical center, while the title's available width accounts for the enlarged icon and nearby controls. Media's static Media Player title uses Monitor Play with that same title-size contract. Its current-player name is on a separate Body-size row with a 14 logical px Audio Lines icon that scales with the suite, independently of Title size. Gear and close buttons retain their click-target sizes and align to the title row. The saved 12 pt title preference is independent of Media's source name and metadata, which follow Body size; Default retains its 10 pt title preset.

Independent utility settings panels map value text to the body color (`TextColor`), including clickable values, toggles, numbers and available choices. This changes their color only. Action buttons keep their accents, and color swatches plus diagnostic/disabled states retain their semantic colors.

Settings section names use Accent 1 (`AccentColor`), including Global Settings' Appearance, Performance, Panel style and Text settings headings. Independent utility section names retain `HeaderFontSize`; table column labels retain their separate header role. Changing Header color still affects ordinary utility headings and table labels.

Utility settings details should collapse when their corresponding utility feature is hidden by an existing visibility choice. Keep the heading and a show/hide control accessible, remove the hidden controls and their unused space, and restore their saved values when the feature is shown again. This behavior is being applied by the utility owners. An unloaded skin, disabled provider or unavailable reading does not by itself hide a settings section; shared setup and recovery actions stay accessible.

CPU, RAM, GPU, Disk Meter, Chronometer, Network, Media and Audio settings show a short note below the title identifying which utility they control. Click "Global Settings are found here." to open the suite-wide panel. This navigation leaves the utility settings open and does not save or refresh anything. The independent settings panels follow the [shared Global Settings layout](UTILITY-SETTINGS.md), with Accent 1 section headings and body-colored values. [APPEARANCE.md](APPEARANCE.md#independent-settings-conversion) records each panel's sections and current status.

Settings form labels and numeric controls use fixed neutral editor text and 9/8 pt form sizes, scaled with the suite. Its main title still reflects the title controls. The picker's editor text colors, opaque background and border remain neutral while editing other colors; picker font sizes still inherit suite typography. This keeps editing controls distinct from the values being previewed. Settings secondary actions deliberately show Accent 2.

Edit settings opens the user include in Notepad. Save changes, then click Apply saved edits. The module-specific `User/<Module>.inc` is included after global values, allowing intentional overrides. A full module launcher, sensor setup wizard and theme import/export remain future milestones. Content padding defaults to 6 pixels. Module layouts must be checked for clipping across supported font sizes.

The Refresh row cycles Balanced/Economy using either arrow or a forward click on its centered value. Its displayed name is derived from all four saved intervals; unmatched settings show Custom and remain untouched until a preset is chosen. From Custom, Previous chooses Economy and Next/center chooses Balanced. No additional preference key is stored. Balanced requests eligible metrics every second, sensors every two seconds, capacity every 30 seconds and spectrum every 50 ms. Economy requests 2s/4s/60s/100ms respectively. Native network remains 1s, chronometer timing remains independent, and UsageMonitor/HWiNFO may keep their own cadence. These presets are not benchmarked CPU guarantees. Unload optional skins/providers when not needed; closing the settings panel leaves other utilities running.

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
