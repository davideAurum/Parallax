# Global settings

The **X** in the top-right corner closes only Global Settings, including while its theme menu is open. Other utilities remain loaded.

Load `Parallax\Settings\Settings.ini` after installing a development copy. **Global Settings** provides a Theme dropdown, ten numeric fields, eight color swatches and refresh presets. Controls cover layout, two accents, separate title/header/body typography, background transparency, panel borders and section dividers. Accepted changes save to `@Resources/User/Settings.inc` and refresh currently loaded Parallax skins. Modules must persist their state across refresh; test this before release.

Open Theme and select **Default** to apply the suite's ModernGadgets-inspired appearance in one action. It is the only theme currently available and saves these 34 keys, matching the shipped defaults:

| Group | Saved keys |
| --- | --- |
| Identity, typography and spacing | `Theme`, `FontFace`, `FontSize`, `TitleFontSize`, `HeaderFontSize`, `PanelPadding`, `CornerRadius` |
| Text and accents | `TextColor`, `TitleTextColor`, `HeaderTextColor`, `MutedColor`, `AccentColor`, `AccentColor2` |
| Surfaces | `BackgroundColor`, `BorderColor`, `BorderThickness`, `DividerColor`, `DividerThickness`, `TrackColor` |
| Graphs | `GraphBackgroundColor`, `GridColor`, `GraphHeight` |
| Status | `GoodColor`, `WarningColor`, `DangerColor` |
| Utility colors | `CPUColor`, `RAMColor`, `GPUColor`, `DiskReadColor`, `DiskWriteColor`, `NetworkInColor`, `NetworkOutColor`, `MediaColor`, `ClockColor` |

Selecting Default again reapplies it after customization. Click the dropdown again, click elsewhere in Settings, or move the pointer out of Settings to dismiss without applying.

Themes change shared appearance. Scale, column width, snap gap, collection cadence and module-specific User includes retain their values. A module's explicit appearance overrides continue to take precedence. `Theme=default` records the last applied base theme; individual edits and color selection may customize that base. Future themes can add named bundles in `Scripts/Settings.lua` and corresponding dropdown choices.

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

Rounding controls the shared panel surface across utilities, including module settings and the color picker. The Default theme restores radius 3 and border/divider thickness 1. Border thickness controls panel outlines; divider thickness controls section separators. Zero hides the corresponding stroke. Graph frames, grids and telemetry strokes retain their separate styling. Sizing is logical geometry scaled by the suite factor, not Windows DPI. Intermediate field values are supported; the established width/scale matrix remains the release baseline for module testing.

Transparency changes only the background fill, preserving its RGB channels. Zero percent is opaque; 100% is fully transparent. The stored alpha is the nearest integer from 0 to 255, and the field displays the percentage derived from that byte. For example, entering `37.5%` saves alpha 159 and displays `37.65%` when read back. There is no separate persisted `BackgroundTransparency` key. The Default theme restores `BackgroundColor=15,15,15,255`.

Each color row displays its current hex code and matching swatch (`#RRGGBB`, or `#RRGGBBAA` when alpha is present). The eight picker targets are:

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

Click a swatch to open the reusable `Parallax\ColorPicker` utility, seeded from that selected global color, with RGB, HSV and CIELAB D50 spectrum modes. Preview changes locally, then Apply to write only the selected key, refresh Parallax and close the picker. Background color edits preserve its existing alpha; other targets save opaque RGB. Cancel closes without writing. Opening another target discards the previous preview. Out-of-sRGB Lab selections show a warning and use the clipped color for preview and Apply. See `COLOR-PICKER.md` for channel semantics and gamut handling.

Panel titles use the title controls; section and table headings use header controls; regular labels and values use body controls, with compact size offsets where required. Defaults are 10/8/9 pt respectively, with bundled IBM Plex Sans (SIL OFL 1.1). Shared button styles use Accent 1 for primary actions and Accent 2 for secondary actions. Utility metric colors and semantic status colors remain independent, so changing text or either accent does not recolor every graph or status. A module's explicit appearance overrides still take precedence.

Settings form labels and numeric controls use fixed neutral editor text and 9/8 pt form sizes, scaled with the suite. Its main title still reflects the title controls. The picker's editor text colors, opaque background and border remain neutral while editing other colors; picker font sizes still inherit suite typography. This keeps editing controls distinct from the values being previewed. Settings secondary actions deliberately show Accent 2.

Edit settings opens the user include in Notepad. Save changes, then click Apply saved edits. The module-specific `User/<Module>.inc` is included after global values, allowing intentional overrides. A full module launcher, sensor setup wizard and theme import/export remain future milestones. Content padding defaults to 6 pixels. Module layouts must be checked for clipping across supported font sizes.

Balanced requests eligible metrics every second, sensors every two seconds, capacity every 30 seconds and spectrum every 50 ms. Economy requests 2s/4s/60s/100ms respectively. Native network remains 1s, chronometer timing remains independent, and UsageMonitor/HWiNFO may keep their own cadence. These presets are not benchmarked CPU guarantees. Unload optional skins/providers when not needed; closing the settings panel leaves other utilities running.

The settings panel and picker are event-driven (`Update=-1`). Each of the ten numeric fields launches `Scripts/SettingsInput.ps1` once through Rainmeter's bundled RunCommand plugin, using existing Windows PowerShell 5.1 and WinForms. The console stays hidden; only a borderless textbox appears over the field. It uses the installed Segoe UI font for editing, writes no files and exits on apply/cancel. Its output is a fixed ASCII numeric/cancel protocol. A fixed FinishAction calls Lua, which reads the measure's string value as data, revalidates it, and writes only the corresponding known setting or background alpha. There is no recurring helper process. InputText's raw action interpolation is not used. The helper is one of the exact reviewed packaging exceptions.

Validation on 2026-09-11 used installed Rainmeter 4.5.26 / Lua 5.1 with isolated settings INIs and SkinPaths:

- `tools/tests/Test-Settings.ps1`: 449 controller/native-bound checks, including the 34-key theme, include precedence, fixed callback validation, surface/color controls and the default 416 x 652 settings window.
- `tools/tests/test_settings_geometry.py`: 100 baseline size combinations, including popup option bounds.
- `tools/tests/Test-SettingsInput.ps1`: 759 assertions for all field families, unit suffixes, decimal precision, invariant output, adversarial text and private WinForms handles at 100%/75% scale; no textbox was shown.
- `tools/tests/Test-SettingsFields.ps1`: 30 actual native action/RunCommand/callback cases, covering accepted, cancelled and malformed results for all ten fields. Ten saves refreshed Settings and its Parallax witness exactly ten times; the unrelated control never refreshed. Cancelled/malformed results preserved settings bytes, and transparency saved only background alpha. Local report: `build/settings-fields-test-ab0e1a9acd9145a287fee5c240102e9b/report.json`.
- Color picker: 900 assertions and 18 captures across default/narrow layouts, including all eight targets, Apply/Cancel, alpha retention and gamut clipping. Local report: `build/color-picker-test-fd6ba0537e5044f3b156fd3427d1e1fb/report.json`.

These local QA artifacts are not distribution files. Native interaction/capture evidence is recorded in [SETTINGS-REVIEW.md](SETTINGS-REVIEW.md). System cursor hit testing, mixed Windows DPI and actual pointer alignment across monitors remain release checks.
