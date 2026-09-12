# Parallax shared contract v2

## Ownership and scope

The original task owns global settings, shared appearance/geometry, integration and packaging coordination. Eight dedicated tasks own Chronometer, CPU, RAM, GPU, IO, Network, Media and Visualizer. Media owns optional Spotify queue; Visualizer is a separately loaded output-device spectrum companion. IO owns disk capacity/transfer rates. Network is independently loadable and owns NIC throughput, adapter selection and traffic history.

The separate ColorPicker config is a global-settings utility owned by the integration task. One reusable RGB/HSV/CIELAB D50 picker handles eight allowlisted targets: `AccentColor`, `AccentColor2`, `TitleTextColor`, `HeaderTextColor`, `TextColor`, `BackgroundColor`, `BorderColor` and `DividerColor`. Preview remains local until Apply writes only the selected key, refreshes Parallax and closes the picker. Background edits preserve its existing alpha; other targets save opaque RGB. Cancel writes nothing. Ten numeric Global Settings fields use the reviewed one-shot SettingsInput helper and fixed data-only result protocol; neither settings utility adds recurring collection work.

Implement original assets and code. ModernGadgets is design inspiration, not an imported dependency. The user's revised visual direction is much closer to its dense black instruments; follow `docs/APPEARANCE.md` revision 2 for the current contract. All colors remain configurable.

## Files and settings

Every config joins `[Rainmeter] Group=Parallax` and supplies a context action opening `Parallax\Settings`, `Settings.ini`. Include these files in this order from a `[Variables]` section using numbered `@Include` keys:

1. `#@#Defaults.inc` (shared defaults).
2. `#@#User\Settings.inc` (persisted global choices).
3. Optional `#@#User\<Module>.inc` (module-owned overrides/defaults).
4. `#@#Geometry.inc` (derived dimensions).
5. `#@#Styles.inc` (shared meter styles).

Set `Columns=1` or `Columns=2` and `PanelHeight=<logical pixels>` BEFORE Geometry.inc, either in module User variables or the entrypoint. Do not override a user's module choices later in the entrypoint. Includes contain their own section headers. Rainmeter merges layered `[Variables]` sections by key. Keep include identifiers unique in an entrypoint. Use `@Resources/Modules/<Module>/` for module scripts and includes.

Global changes persist through `!WriteKeyValue` into `@Resources/User/Settings.inc`, then refresh only `Parallax` configs using `!RefreshGroup`. Module settings may override global colors, fonts and `Scale` locally in their own User file. All persistable settings live in `[Variables]` for Skin Packager variable preservation. Ship every supported user key with a default. New keys must retain useful defaults during upgrades. Runtime data (timer state, queue caches, OAuth tokens) is separate from distributable configuration, with its persistence and migration documented by the module owner. No OAuth material in skins.

The global Theme dropdown currently contains only Default. Its 34-key bundle matches shipped defaults and includes the theme identifier, font family and all three text sizes/colors, both accents, panel/background/divider styling, padding/corners, graph styling, status colors and utility metric colors. It refreshes Parallax once. The theme leaves suite scale, column width, snap gap, cadence and module-owned includes intact; module appearance overrides retain precedence. `Theme=default` records the last applied base theme and is preserved with other global variables. [SETTINGS.md](SETTINGS.md) lists the exact bundle and controls.

Numeric fields accept scale 75–200%, column width 180–320 px, gap 0–16 px, rounding 0–24 px, title size 6–12 pt, header/body size 6–10 pt, background transparency 0–100%, and border/divider thickness 0–4 px. Width/gap/rounding require whole pixels; other fields allow up to two decimals and optional appropriate unit suffixes. The helper receives only known keys and canonical launch values. RunCommand returns a fixed ASCII numeric/cancel protocol, and a fixed FinishAction calls Lua to read the result as data and validate it again. The helper writes no files; accepted changes use the shared persistence path above.

`BackgroundTransparency` is an input operation, not a persisted variable. It preserves background RGB and writes the nearest 8-bit alpha into `BackgroundColor`; zero percent is opaque and 100% fully transparent. The displayed value is derived from the saved alpha and rounded to two decimals: 37.5% becomes alpha 159, then displays 37.65%. The Default theme restores `BackgroundColor=15,15,15,255`.

## Geometry

`ColumnWidth=200` is the painted width of one panel at scale 1. `Gutter=8` is the visible gap between edge-snapped panels, included as equal transparent outer margins. `Scale=1` initially. These are editable choices, not a Rainmeter hardcoded snap distance.

- `UnitWidth = Round(ColumnWidth * Scale)`.
- `Gap = 2 * Round(Gutter * Scale / 2)` (even physical pixels).
- `Inset = Gap / 2`.
- `Pitch = UnitWidth + Gap`.
- `WindowWidth = Columns * Pitch`.
- `PanelWidth = WindowWidth - Gap`.
- `WindowHeight = Round(PanelHeight * Scale) + Gap`.

A single panel paints 200 px inside a 208 px window. A double panel paints 408 px inside a 416 px window: `2 * 200 + 8 = 408`. Two adjacent single windows occupy precisely the same width as one double window. Draw the panel at `(Inset, Inset)` and size it `(PanelWidth, PanelHeightPx)`. Use an invisible bounds meter (StyleBounds) so transparent margins remain part of the skin window. Do not add meters outside the declared window bounds. `StylePanel` draws the surface. Content starts at `ContentX/ContentY`; usable width is `ContentWidth`.

Use logical vertical positions multiplied by `#Scale#`, measured relative to `#Inset#`. Text should clip/truncate long content without growing the window. Use fixed declared widths; do not allow cover art or labels to change snap geometry. Width variants may share an entrypoint with a persistent Columns setting.

Rainmeter `SnapEdges` is a per-skin setting in Rainmeter.ini, not an arbitrary spacing option. Leave normal Rainmeter snapping enabled; a user can disable it or hold Ctrl while dragging. Validate single/double alignment at 100%, 125%, 150% and 200% suite scale and mixed Windows DPI before release. See [official skin settings](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/settings/skin-sections.html).

## Appearance

Shared typography uses `FontFace`, `TitleFontSize`/`TitleTextColor`, `HeaderFontSize`/`HeaderTextColor`, and `FontSize`/`TextColor` for body text. Defaults are IBM Plex Sans, 10/8/9 pt, and RGB 220/220/220 for titles/body versus 175/175/175 for headers. `MutedColor` remains available for secondary information. `AccentColor` defaults to 137/190/250; `AccentColor2` defaults to 181/161/226 for secondary actions. Utility metric colors and `GoodColor`/`WarningColor`/`DangerColor` preserve their semantic roles rather than following general text/accent changes.

Surface variables are `BackgroundColor`, `BorderColor`, `BorderThickness`, `DividerColor`, `DividerThickness`, `TrackColor`, `PanelPadding` and `CornerRadius`; graph background/grid/height retain their separate variables. `StylePanel` draws its border inside the panel using the configured thickness times Scale. `StyleRule` uses divider color and thickness times Scale. Thickness zero hides the corresponding stroke. Graph frames, grids and telemetry strokes keep their separate styling.

Shared styles are `StyleBounds` (Image), `StylePanel` (Shape), `StyleTitle`, `StyleHeader`, `StyleLabel`, `StyleValue`, `StyleButton` (String), `StyleRule` and `StyleGraph` (Shape). Use `StyleTitle` for panel titles, `StyleHeader` for section/table headings, and body styles for labels and live values. `StyleSecondaryButton` is a color-only override layered after `StyleButton` for Accent 2. Every actual meter must declare `Meter=<type>` as well as `MeterStyle=<style>`. Styles contain no Meter key so they do not draw independently. Set meter-specific X/Y/W/H after applying the style when appropriate, and remove local font overrides that would bypass the intended typography role. Buttons require descriptive ToolTipText; statuses must use text as well as color.

The settings editors deliberately retain neutral control text while global text colors are edited. Global Settings form labels/values use fixed 9/8 pt editor sizes scaled with the suite; its main title still inherits title typography. ColorPicker keeps neutral text colors and an opaque neutral surface/border, while its fonts still inherit suite typography. These editor exceptions do not replace module appearance overrides. Module layouts must honor the supported global size ranges without silently capping them locally.

## Data and update policy

Default `MetricsInterval=1000` ms, `SensorInterval=2000` ms, `CapacityInterval=30000` ms. These are targets for native measures whose cadence can be controlled. Use UpdateDivider for slow data; static metadata updates on refresh. UsageMonitor has independent 1 Hz workers per category; slowing skin updates does not reduce those workers. Optional categories/skins must be unloaded to remove that cost.

Keep visualizer in a separate config, default `VisualizerInterval=50` ms (20 FPS), optional 33/100 ms. It captures mixed output-device audio, not solely Spotify. Never run all skins at visualizer frequency. Low power settings do not claim to throttle third-party provider polling. No timer writes every second; save state at user actions/checkpoints as needed.

No provider means unavailable, not measured zero. Distinguish disconnected, stale, unsupported and valid data when the provider exposes enough evidence. Sample timestamps/labels where available; do not invent freshness detection a provider cannot support. Document unavoidable ambiguities.

## Acceptance

Each module delivers usable baseline controls/data within its capability, configuration instructions, source attribution, meaningful checks, and known limitations. Record prototype versus verified live behavior. Test reload persistence, missing providers, long labels, dimensions at multiple scales and CPU cost with helpers included before release. The shared settings skin can close independently without stopping other modules.
