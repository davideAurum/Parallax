# Color picker

One small picker edits any color variable in the suite. Its title is **Color picker: \<target\>**, and the target is a dropdown listing every color variable. A swatch anywhere in the suite opens the picker on its own variable, beside the skin that holds the swatch.

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when the picker changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape/String/Image meters | Required; supplied by Rainmeter | Draws the spectrum and handles interaction without a background process or polling. |
| `ColorPicker.ini`, `Modules/ColorPicker/ColorPicker.lua`, `ColorMath.lua`, `Targets.lua` and shared Parallax includes | Bundled source; required | Local RGB/HSV/CIELAB calculations, the target registry, editor state and geometry. Missing source is an incomplete installation. |
| `Modules/ColorPicker/Launcher.lua` | Bundled source; required by any skin with swatches | Opens the picker on one target beside the calling skin. Without it a swatch does nothing; the picker still loads on its own, starting with Accent Color 1. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Uses the suite font and typography. No system installation. |
| Writable `@Resources/User/*.inc` | Required for Apply persistence | Apply writes the one selected key to the file that stores it; preview and Cancel write nothing. |

The picker requires no PowerShell helper, external plugin, color-selection package, network service or account. Spectrum rendering uses original local Lua and native gradients rather than downloaded images.

## Using it

The panel is one column, 280 logical pixels wide and 262 high (288 × 270 pixels at scale 1 with the default gutter). It keeps the suite's gutter, scale, padding, rounding and fonts, but not the saved column width: the title must fit "Color picker: Table header border" at the largest title size.

- **Title dropdown.** Click the target name or its chevron. A ten-row list replaces the editor: group headings, then one row per variable with a dot showing its current color. Scroll with the mouse wheel (a thin bar at the right edge shows the position). Click a row to switch to it; click the title again to close the list. Switching discards the previous preview and reads the new variable's saved color.
- **Spectrum and strip.** Click the spectrum to choose two channels, then the strip below it for the third. The marker shows the selected position.
- **Mode.** RGB, HSV or Lab (CIELAB D50) under the strip. The active mode is brighter.
- **Channels.** Three cells show each channel's value. **−** and **+** step it by one unit, as does the mouse wheel over the value.
- **Footer.** A split swatch shows the saved color (left) and the preview (right), then the preview's hex value. **Cancel** closes without writing; **Apply** saves.
- **Notes.** The right end of the mode row shows `Outside sRGB: clipped` (yellow) when a Lab choice leaves the sRGB gamut, or `Opacity N% kept` for a target that keeps its alpha. It is empty otherwise.

| Mode | Spectrum, left to right | Spectrum, bottom to top | Strip | Channel limits |
| --- | --- | --- | --- | --- |
| RGB | Red | Green | Blue | 0–255 each |
| HSV | Saturation | Value | Hue | H 0–360, S/V 0–100% |
| Lab | a* | b* | Lightness L* | L* 0–100; a*/b* −128–127 |

CIELAB uses the **D50 reference white**, with Bradford adaptation between sRGB's D65 white and D50. Some Lab coordinates cannot be represented in sRGB. The requested coordinates remain visible, while the spectrum, swatch, hex value and saved RGB use channel clipping to 0–255. This is simple clipping, not perceptual gamut mapping. Switching modes starts from the displayed, rounded sRGB color.

The seed accepts Rainmeter comma RGB/RGBA and six/eight-digit hexadecimal colors (with an optional leading `#`). There is no free-text input, and no user-entered string reaches a Rainmeter action.

## Targets

`Modules/ColorPicker/Targets.lua` is the registry: the dropdown, the launcher and Apply all take their keys from it, and nothing else is ever written or put in an action. Keys are exact and case-sensitive.

| Group | Keys (label) | Stored in | Saved as |
| --- | --- | --- | --- |
| Text and accents | `AccentColor` (Accent Color 1), `AccentColor2` (Accent Color 2), `TitleTextColor`, `HeaderTextColor`, `TextColor` (Body Text Color), `MutedColor` | `User\Settings.inc` | `R,G,B` |
| Surfaces | `BackgroundColor`, `GraphBackgroundColor` (Graph Background), `GridColor` (Graph Grid) | `User\Settings.inc` | `R,G,B,A`, keeping the saved alpha byte |
| Surfaces | `BorderColor`, `DividerColor`, `TableHeaderBorderColor` (Table header border), `TrackColor` | `User\Settings.inc` | `R,G,B` |
| Status | `GoodColor`, `WarningColor`, `DangerColor` | `User\Settings.inc` | `R,G,B` |
| Utilities | `CPUColor`, `RAMColor`, `GPUColor`, `DiskReadColor`, `DiskWriteColor`, `NetworkInColor`, `NetworkOutColor`, `MediaColor`, `ClockColor` | `User\Settings.inc` | `R,G,B` |
| Utilities | `RAMHistoryEmptyColor` (Memory History Cover) | `User\RAM.inc` | `R,G,B` (the skin appends its own alpha) |
| CPU threads | `CPUThreadColor1` … `CPUThreadColor64` (CPU Thread N) | `User\CPU.inc` | `R,G,B` |

The thread rows in the list are the logical threads the CPU meter shows (detected processors, capped by `CPUCoreLimit`); the keys 1–64 are all valid. An unset thread color starts from the Thread Colors palette. A color whose saved value carries alpha but is not in the alpha-keeping rows above (Border, Divider, Table header border, Track) is saved opaque, as before.

**Apply** writes only the selected key to the file that stores it, then reloads what reads it, and closes the picker:

- Shared colors: `!RefreshGroup Parallax`, since every skin reads them.
- `RAMHistoryEmptyColor`: `!RefreshGroup ParallaxRAM` only.
- `CPUThreadColorN`: the value is pushed to the running CPU meter (`!SetVariableGroup` and `!UpdateMeasureGroup ParallaxCPUApply`), as the Thread Colors panel always did, and only the open Thread Colors panel reloads (`ParallaxCPUColors`). The CPU meter and its sensor host are not reloaded.

**Cancel**, unloading or closing the picker discards the preview. Size, update intervals, other colors and module overrides are preserved. A new shared color in `Defaults.inc` needs one line in `Targets.lua`; `TargetTests.lua` fails until it has one.

## Opening it from a swatch

`Modules/ColorPicker/Launcher.lua` is the script every swatch uses. Give the skin one Script measure, then point the swatch at it:

```ini
[MeasureColorLauncher]
Measure=Script
ScriptFile=#@#Modules\ColorPicker\Launcher.lua

[MeterRAMSwatch]
...
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('RAMColor','MeterRAMSwatch')"]
```

`Open(key, swatchMeter)` returns false, with no bang, for a key that is not in the registry. For a valid key it activates `Parallax\ColorPicker`, moves it, and calls `OpenTarget(key)` in that order, so a closed and an already-open picker both end up on the new target (Rainmeter logs a warning when it is already active). The second argument is optional.

**Placement.** The picker goes against the skin's right edge; if that would leave the monitor holding the skin, against its left edge. Both skins carry their own transparent gutter, so edge to edge leaves the suite's normal gap. Vertically it is top-aligned with the skin, or, when the swatch meter is named, centered on the swatch and kept within the skin's height. It is always kept inside that monitor's work area. A skin that is on no monitor (the isolated test places it off screen) gets the picker beside it, unclamped. The picker's window size comes from `Targets.lua` (`PickerColumnWidth`, `PickerPanelHeight`) and the suite's scale and gutter, so the calling skin must load `Defaults.inc` and `User\Settings.inc`, as every suite skin does.

Wired today:

| Swatch | Skin | Action |
| --- | --- | --- |
| The nine color rows (Accent 1 and 2, Title, Header, Body, Background, Border, Divider, Table header border) | Global Settings | `OpenColor(key)` in `Settings.lua`, which first applies a pending refresh, then calls the launcher through a delayed `!CommandMeasure` so the reload cannot reset the new target |
| Each Thread N swatch | CPU Thread Colors | `LeftMouseUpAction` on `MeterThreadColorSwatchN`; the label and hex text still open the typed hex editor |

The other color variables (utility, status, graph) have no swatch of their own yet; reach them from the dropdown. A skin that adds one only needs the measure and action above.

## Rendering and cost

The production skin uses `Update=-1`. It has no polling, animation loop, background process, third-party plugin, generated image files or external assets. All spectrum colors are calculated by the original Lua implementation and drawn by Rainmeter Shape meters.

The plane uses 48 horizontal gradient strips with 25 sampled stops per strip. Opening, changing modes or changing the strip channel rebuilds the plane; selecting a point updates only the values, swatches, markers and strip. The dropdown rewrites its ten rows on open and on each scroll. It reads `User\RAM.inc` and `User\CPU.inc` (a few kilobytes each) on open to color the dots and count threads. Integer-aligned strip edges avoid native antialias seams. The displayed gradients approximate the mathematical plane; the saved color is calculated directly from the selected channel coordinates.

Editor labels, title, values and buttons use fixed neutral foreground colors on a fixed opaque near-black panel, so selecting black text, a black border or a transparent background leaves the picker readable. The swatches and hex value always show the actual target RGB. The launcher runs only on a click.

## Verification

Run the focused test from the repository root with an existing Rainmeter installation:

```powershell
& '.\Skins\Parallax\@Resources\Modules\ColorPicker\tests\Test-ColorPicker.ps1'
```

It creates an isolated copy under `build/color-picker-test-<id>`, runs a hidden Rainmeter instance with its own settings path and stops only that process. It does not touch the live configuration. Captures use `PrintWindow` on this PID's windows.

Offline (no Rainmeter), `ColorMathTests.lua`, `TargetTests.lua` and `LauncherTests.lua` also run inside the native harness at load; any failure blocks the run. They cover:

- sRGB/HSV primaries, D50 Lab white/black, the published W3C leaf-color example, 125-color round trips, gamut clipping.
- The registry: every color in `Defaults.inc` has a target and every shared target is a `Defaults.inc` color; `ColumnWidth`, `PanelHeight` and `Columns` in `ColorPicker.ini` match the numbers the launcher uses.
- Every shared target applies to `Settings.inc` and reloads `Parallax`; alpha is kept only where the registry says; invalid keys (malformed, action-like, non-string, thread index 0/65/01/1.0) change nothing; `RAMHistoryEmptyColor` and `CPUThreadColorN` read and write their own User file and reload only their own scope.
- The dropdown: rows, selection highlight, dots, scroll clamping, group headings ignored, retarget closing the list, Apply after a pick.
- The launcher: exact bang sequence, key validation, and placement on one and two monitors (right, flipped left, squeezed, bottom clamp, swatch alignment, scale 0.75).

The native run (default scale 1, and scale 0.75 with radius 24 and a transparent background) additionally checks, through the real source actions: modes, channels, plane, strip, Apply and Cancel; `Launcher.lua` run from a separate skin for ten keys (the nine Global Settings colors and Graph Grid), each opened, previewed, reopened over an unsaved preview, applied and reopened on its saved color; the picker's window position beside that skin, off screen and on the first monitor (right, flipped left at the right edge, clamped at the bottom); the title dropdown opened from the target text and from the chevron, wheel scrolling both ways, a group heading ignored, a row retargeting, the thread rows at the end of the list, Apply and Cancel after a pick; the `RAM.inc` and `CPU.inc` targets writing only their own key; and no `ERRO` line in the log. The harness substitutes percentage coordinates into the actual action strings; it does not test system cursor hit testing, keyboard focus, mixed DPI or the live configuration.

Two one-off isolated runs (2026-10-28; throwaway scripts, not part of the repeatable suite) ran the real skins end to end by executing the swatch's own `LeftMouseUpAction`. In `Parallax\Settings`, a Border Color click opened the picker beside Settings, centered on the swatch, directly and after a pending debounced refresh (it opened after the reload, on the clicked target). In `Parallax\CPU\Colors`, the Thread 3 swatch opened the picker beside it on its palette color, and Apply wrote only `CPUThreadColor3` to `User\CPU.inc` and reloaded the panel. Neither log had an `ERRO` line. A person clicking in the live skins, a second physical monitor, mixed DPI and the live Rainmeter profile remain unverified; the two-monitor placement rules have only the mock coverage above.

## Primary references

- [W3C CSS Color 4 conversion sample code](https://www.w3.org/TR/css-color-4/#color-conversion-code): sRGB transfer functions, RGB/XYZ matrices, D65/D50 adaptation and Lab equations.
- [W3C CSS Color 4 Lab colors](https://www.w3.org/TR/css-color-4/#lab-colors): D50 Lab coordinates and color-space behavior.
- [W3C CSS Color 4 gamut mapping](https://www.w3.org/TR/css-color-4/#gamut-mapping): the distinction between out-of-gamut colors, clipping and gamut mapping.
- [Python standard library colorsys](https://docs.python.org/3/library/colorsys.html) and [its primary implementation](https://github.com/python/cpython/blob/main/Lib/colorsys.py): HSV definitions and conversion behavior.
- [Rainmeter Shape meter](https://docs.rainmeter.net/manual/meters/shape/): native linear-gradient fills.
- [Rainmeter mouse variables](https://docs.rainmeter.net/manual/variables/mouse-variables/): meter-relative percentage coordinates in mouse actions.
- [Rainmeter built-in variables](https://docs.rainmeter.net/manual/variables/built-in-variables/) and [Lua scripting](https://docs.rainmeter.net/manual/lua-scripting/): monitor work areas, `SKIN:GetX/GetY/GetW/GetH`.
