# Global Settings and color selection review

Expanded 2026-09-11. Global Settings provides the Default theme, four geometry fields, Accent 1/2, background color/transparency, border and section-divider color/thickness, and title/header/body size and color. All eight swatches open the independent RGB/HSV/CIELAB picker. These checks used isolated copies without modifying the live Rainmeter configuration.

## Delivered behavior

- Default applies 34 appearance values while preserving size, cadence and module overrides.
- Ten numeric fields validate their ranges, apply on Enter, and cancel on Escape or focus loss. Border/divider thickness accepts 0–4 logical pixels; 0 hides the stroke.
- Color readouts support RGB/RGBA and six/eight-digit hex. Picker Apply writes only the selected allowlisted key; Cancel preserves settings. Background color selection retains alpha; other targets export opaque RGB. Lab gamut clipping is shown.
- Transparency updates only BackgroundColor alpha, preserving RGB. Alpha has 256 levels: 37.5% rounds to alpha 159 and displays as 37.65%. No separate transparency variable is persisted.
- Settings and ColorPicker remain event-driven. Numeric editing launches one Windows PowerShell/WinForms helper per edit. Neutral editor controls remain readable while customizing text; the picker keeps an opaque neutral surface.

Behavior and ranges are in [SETTINGS.md](SETTINGS.md), [APPEARANCE.md](APPEARANCE.md) and [COLOR-PICKER.md](COLOR-PICKER.md).

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Settings controller and native bounds | 449 assertions/checks, Lua 5.1, default 416×652 | `build/settings-test-73ece8f0720b4fa6a3e3d451fc32e3bf/` |
| Declared geometry | 100 width/scale/gap combinations | `tools/tests/test_settings_geometry.py` |
| Native theme actions/persistence | All 34 keys restored in default/narrow layouts; one selection refresh | `build/theme-dropdown-test-af9785dad3504dbaa8afc995f866f093/` |
| Numeric helper and native HWND handlers | 759 assertions under Windows PowerShell 5.1, including 70 handler scenarios | `tools/tests/Test-SettingsInput.ps1` |
| Settings → RunCommand → callback → file | 30 cases: ten accepted, ten cancelled, ten malformed | `build/settings-fields-test-ab0e1a9acd9145a287fee5c240102e9b/report.json` |
| Picker math, routing and persistence | 900 Lua assertions per load, eight targets/two layouts, 18 captures | `build/color-picker-test-fd6ba0537e5044f3b156fd3427d1e1fb/report.json` |

The field test dispatched production source actions through RunCommand and its fixed FinishAction with a deterministic helper in the isolated copy. The copied real helper validator checked launch parameters and normalization. Each accepted edit refreshed Settings and a Parallax witness once (generation 11); an unrelated witness stayed at 1. Cancelled/malformed results preserved the file byte-for-byte. No unrelated keys changed and Rainmeter logged no errors. The separate textbox test exercised Enter/Escape/deactivation on private HWNDs without displaying UI.

Picker checks cover closed/already-open/reopened routing, Apply/Cancel, invalid targets, and alpha 0/128/255 in RGB/RGBA/hex forms. Native background edits retained alpha 128 and 0, including a transparent suite fixture with black text/borders. The picker remained readable. A test teardown timing race was corrected before the successful final run.

## Pixel review

The subsequent top-right X uses a neutral Shape icon and deactivates only `Parallax\Settings`. It renders after the theme overlay so the menu cannot intercept it; the title reserves its width. The existing geometry matrix passed 100 cases, native controller/bounds checks passed 450 (`build/settings-test-c104afe613da455a9ea02692ee6e2318/`), and theme interactions/captures passed in both layouts (`build/theme-dropdown-test-837d608cae314e16a147cb9524e685a9/`). These runs did not alter the live profile.

Root inspected default and narrow closed-theme captures above: 416×652 and 282×489. The surface table and text section fit with readable hex codes, swatches and fields.

Current preference captures: `build/Parallax-visual-preview-20260911T232701763Z-df2c5122/captures/`, Settings 416×652 and ColorPicker 416×384. A four-second preview initially found only the first window; a twelve-second run completed with both and no Rainmeter errors. This was capture readiness, not a production update change.

The final 22-pixel title boxes were also inspected at maximum 12/10/10 pt typography with border 4 in both layouts: `build/ram-audio-max-default-3589d6a457d944da90cf266d53915eeb/` and `build/ram-audio-max-narrow-859f5f8e2554424184faeaa895733d6d/`, under `captures/Settings.png` and `captures/ColorPicker.png`. No glyph clipping, overlapping controls or cut outer borders were observed.

These are native action/rendering checks, not physical cursor hit testing or mixed-monitor DPI certification. Utility typography/surface checks are in `docs/modules/`. Sustained performance and packaged installation/upgrade acceptance remain release work. Preview directories contain instrumentation and must not be distributed; no `.rmskin` was produced by this settings revision.
