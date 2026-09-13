# Global color picker

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when the picker changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape/String/Image meters | Required; supplied by Rainmeter | Draws the spectrum and handles interaction without a background process or polling. |
| `ColorPicker.ini`, `Modules/ColorPicker/ColorPicker.lua`, `ColorMath.lua` and shared Parallax includes | Bundled source; required | Local RGB/HSV/CIELAB calculations, editor state and geometry. Missing source is an incomplete installation. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Uses the suite font and typography. No system installation. |
| Writable `@Resources/User/Settings.inc` | Required for Apply persistence | Apply writes the one selected key; preview and Cancel need no preference write. |
| Global Settings | Optional launcher; bundled | Its swatches open and select a target. The picker can also load independently, starting with Accent 1. |

The picker requires no PowerShell helper, external plugin, color-selection package, network service or account. Spectrum rendering uses original local Lua and native gradients rather than downloaded images.

Open a color swatch in **Global Settings**, or load `Parallax\ColorPicker\ColorPicker.ini` in Rainmeter. The picker edits Accent Color 1, Accent Color 2, Title Text Color, Header Text Color, Body Text Color, Background Color, Border Color, Divider Color, or Table header border; its title identifies the active target. A direct standalone load selects Accent Color 1. It uses the suite's two-column geometry, font, padding, and rounding. Its logical panel height is 376 pixels: the default window is 456 × 384 pixels, including the snapping gutter. At column width 180 and scale 0.75, the window is 282 × 288 pixels.

Click the spectrum to choose two channels, then click the horizontal strip to change the remaining channel. Channel **− / +** buttons and the mouse wheel over a channel value adjust it by one unit. The marker shows the selected position; Current and New swatches show the saved and proposed colors.

| Mode | Spectrum, left to right | Spectrum, bottom to top | Horizontal strip | Channel limits |
| --- | --- | --- | --- | --- |
| RGB | Red | Green | Blue | 0–255 each |
| HSV | Saturation | Value | Hue | H 0–360°, S/V 0–100% |
| CIELAB | a* | b* | Lightness L* | L* 0–100; a*/b* −128–127 |

CIELAB uses the **D50 reference white**, with Bradford adaptation between sRGB's D65 white and D50. Some Lab coordinates cannot be represented in sRGB. The requested Lab coordinates remain visible, while the spectrum, swatch, hex value, and saved RGB use channel clipping to 0–255. A yellow message explicitly marks this condition. This is simple clipping, rather than perceptual gamut mapping. Switching modes starts from the displayed, rounded sRGB color.

**Apply** writes only the selected color key in `@Resources\User\Settings.inc`, refreshes the active `Parallax` group, and closes the picker. **Cancel**, unloading, or closing the picker discards uncommitted preview changes. Opening a target again, or switching to another target while the picker is open, discards the previous preview and reads the selected global color. Size, update intervals, other colors, and module overrides are preserved.

The seed accepts Rainmeter comma RGB/RGBA and six/eight-digit hexadecimal colors (with an optional leading `#`). **Background Color preserves its seeded alpha**: Apply saves `R,G,B,A`, with the selected RGB and the original alpha byte. RGB and six-digit hex imply alpha 255. RGBA and eight-digit hex retain alpha, including 0, partial opacity, and 255. The status line reports the preserved background opacity; transparency is edited independently in Global Settings. The Current/New swatches display RGB as opaque color previews so the hue remains visible even when background opacity is zero.

Other targets edit color without opacity: they ignore seed alpha and Apply saves an opaque comma-separated `R,G,B` value. The picker does not expose free-text input or interpolate user-entered strings into Rainmeter actions.

Table header border is independent of section dividers and the outer panel border. Editing it changes only `TableHeaderBorderColor`; divider/border colors and all line thicknesses retain their saved values. If the new key is absent, the picker seeds it with `50,50,50,255` and Apply saves opaque `50,50,50` unless the preview changes.

## Integration contract

`MeasureColorPicker` exposes `OpenTarget(key)`. The exact, case-sensitive allowlist is:

| Global key | Picker title |
| --- | --- |
| `AccentColor` | Accent Color 1 |
| `AccentColor2` | Accent Color 2 |
| `TitleTextColor` | Title Text Color |
| `HeaderTextColor` | Header Text Color |
| `TextColor` | Body Text Color |
| `BackgroundColor` | Background Color |
| `BorderColor` | Border Color |
| `DividerColor` | Divider Color |
| `TableHeaderBorderColor` | Table header border |

Use a static key in the existing swatch action, after activation, and explicitly address the picker config:

```ini
LeftMouseUpAction=[!ActivateConfig "Parallax\ColorPicker" "ColorPicker.ini"][!CommandMeasure "MeasureColorPicker" "OpenTarget('AccentColor2')" "Parallax\ColorPicker"]
```

This sequence supports a closed picker and an already-open picker. `OpenTarget` returns true for a valid key. Unknown keys and non-string inputs return false without changing the target, preview, or preferences. Invalid values are never interpolated into an action; Apply obtains its key only from the validated active target. Direct calls to Apply therefore continue to use the prior valid target after an invalid targeting attempt.

## Rendering and cost

The production skin uses `Update=-1`. It has no polling, animation loop, background process, third-party plugin, generated image files, or external assets. All spectrum colors are calculated by the original Lua implementation and drawn by Rainmeter Shape meters.

The plane uses 48 horizontal gradient strips with 25 sampled stops per strip. Opening, changing modes, or changing the slice channel rebuilds the plane. Selecting a point within the plane updates only the values, swatches, markers, and small slice strip. Integer-aligned strip edges avoid native antialias seams. The displayed gradients approximate the mathematical plane; the selected/exported color is calculated directly from the selected channel coordinates.

Editor labels, title, values, and buttons use fixed neutral foreground colors. The editor panel also has a fixed opaque near-black fill and neutral border. Selecting black text, a black border, or a fully transparent background therefore leaves the picker readable. The Current/New swatches and hex value still represent the actual target RGB. Shared font sizing remains in use. Rounded-corner and scaled layouts reserve the same external gutter as the rest of the suite.

## Verification

Run the focused test from the repository root with an existing Rainmeter installation:

```powershell
& '.\Skins\Parallax\@Resources\Modules\ColorPicker\tests\Test-ColorPicker.ps1'
```

The test creates an isolated copy under `build/color-picker-test-<id>`, runs a hidden Rainmeter instance with its own absolute settings path, and stops only that process. It does not modify or capture the live Rainmeter configuration. PNG captures use `PrintWindow` on windows belonging to the test PID.

Coverage includes sRGB/HSV primaries, D50 Lab white/black, the published W3C leaf-color example, 125-color conversion round trips, eight-digit hexadecimal seeds, gamut clipping, native geometry at default/narrow sizes, radius 24, mode/channel/plane/strip source actions, Apply, and Cancel. A separate isolated launcher config tests the exact activation/target action sequence with every allowed key, including opening, reopening an unsaved preview, and reopening a saved color. Each key is independently applied and cancelled; persistence checks compare every global key and an isolated module override. Background tests cover RGB/hex6 default alpha 255 and RGBA/hex8 alpha 0, 128, and 255; native persistence runs preserve both zero and partial background opacity. A direct mock of the production Lua API verifies the target allowlist with malformed strings, action-like strings, non-string inputs, and nil, keeping those test payloads as data. Captures include black title/body/border preferences and a fully transparent background to verify editor readability. The capture harness substitutes percentage coordinates into the actual source action strings; it does not test system cursor hit testing, keyboard focus, mixed DPI, or live configuration behavior.

The table header border addition extends these existing harnesses with the ninth target. Its API cases cover independent line-color writes, preserved thicknesses, opaque saves from RGBA/hex8 seeds, and the missing-key fallback. This addition has source verification only; the expanded native harness has not been run for it.

## Primary references

- [W3C CSS Color 4 conversion sample code](https://www.w3.org/TR/css-color-4/#color-conversion-code): sRGB transfer functions, RGB/XYZ matrices, D65/D50 adaptation, and Lab equations.
- [W3C CSS Color 4 Lab colors](https://www.w3.org/TR/css-color-4/#lab-colors): D50 Lab coordinates and color-space behavior.
- [W3C CSS Color 4 gamut mapping](https://www.w3.org/TR/css-color-4/#gamut-mapping): the distinction between out-of-gamut colors, clipping, and gamut mapping.
- [Python standard library colorsys](https://docs.python.org/3/library/colorsys.html) and [its primary implementation](https://github.com/python/cpython/blob/main/Lib/colorsys.py): HSV definitions and conversion behavior.
- [Rainmeter Shape meter](https://docs.rainmeter.net/manual/meters/shape/): native linear-gradient fills.
- [Rainmeter mouse variables](https://docs.rainmeter.net/manual/variables/mouse-variables/): meter-relative percentage coordinates in mouse actions.
