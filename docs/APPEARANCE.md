# ModernGadgets-inspired appearance, revision 2

User direction, 2026-09-11: make every utility look substantially closer to raiguard's **ModernGadgets** as the starting point. This supersedes the earlier spacious dark-card interpretation. Keep Parallax's customization, independent modules, source semantics and snapping geometry.

Visual reference: [official preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png). The local research copy is `build/reference/moderngadgets-preview.png`, outside distributable sources. Behavior/style reference: [ModernGadgets stylesheet](https://github.com/raiguard/ModernGadgets/blob/master/Skins/ModernGadgets/%40Resources/StyleSheet.inc). Implement original Rainmeter meters; do not copy upstream code or images. Its exact default panel width is 150 logical pixels; Parallax starts at 200 to accommodate its expanded controls.

## Shared defaults

- Painted column 200 px; double 408 px with the existing 8 px gutter. Supported widths 180, 200, 240, 280 and 320; suite scale 0.75, 1, 1.25, 1.5 and 2. PanelPadding=6, CornerRadius=3.
- Neutral near-black background `15,15,15,255`, graph/inset `25,25,25,255`, border/divider/track `50,50,50,255`, primary text `220,220,220`, secondary text `175,175,175`, Accent 1 `137,190,250` and Accent 2 `181,161,226`.
- Panel titles use `TitleFontSize=10` / `TitleTextColor=220,220,220`, weight 600. Section and table headings use `HeaderFontSize=8` / `HeaderTextColor=175,175,175`, weight 600. Ordinary body text uses `FontSize=9` / `TextColor=220,220,220`, weight 500. Global Settings supports title 6–12 pt and header/body 6–10 pt, including two decimal places. FontFace=IBM Plex Sans, bundled with the user's explicit approval under SIL OFL 1.1 in `@Resources/Fonts` and `@Resources/Licenses`. Follow `FontFace` rather than hardcoding a font. The fonts load privately in Rainmeter; module tasks must not download fonts or assets.
- The Default theme has an opaque background, 1 px border and section dividers, and 3 px corners. `BackgroundColor` carries background alpha; the transparency field derives and updates that alpha. `BorderThickness` and `DividerThickness` accept 0–4 logical px, with 0 hiding the stroke. The border is inset by half its scaled thickness to stay inside the panel. Shared transparent gutters still define snapping. Avoid shadows/large empty margins.
- One compact header, roughly 20 px high: original small icon on left, title immediately beside it, main live value at the right where relevant. Label/value rows should share baselines, typically 16–18 logical px apart.
- Hairline progress tracks: 1–2 px where appropriate, with colored activity on neutral tracks. Do not turn all metrics into oversized numbers.
- History graphs typically 42–52 logical px tall with a near-black inset, thin border and subtle horizontal grid lines. Use original data series colors; preserve unknown-history behavior and source semantics.
- Controls are small text/icon actions, not large padded tiles. Shared `StyleButton` padding is now 3,1,3,1 times Scale (adds 6 px width / 2 px height); H=18 times Scale. Tooltips supply full descriptions. Brief status text stays visible; lengthy provider caveats belong in hover text/docs.

Shared per-metric colors: CPUColor (red), RAMColor (cyan), GPUColor (green), DiskReadColor (green), DiskWriteColor (yellow), NetworkInColor (yellow), NetworkOutColor (green), MediaColor and ClockColor (blue). These are user-editable global variables. Individual modules may override them in their User include.

`AccentColor` remains the compatibility key for Accent 1 and primary controls. `AccentColor2` supplies secondary controls through the FontColor-only `StyleSecondaryButton` modifier. Append that modifier after `StyleButton`; do not let it replace local geometry. Section rules use `DividerColor`/`DividerThickness`; history grids retain `GridColor`. Preserve semantic metric/status colors and deliberate size differences for clocks or readings. Global Settings uses fixed neutral control text so changing body typography does not make its editor unusable. ColorPicker also keeps an opaque neutral editor surface; its preview still reflects the selected target.

## Module direction

| Utility | Visual target |
| --- | --- |
| Chronometer | Centered accent clock around 18–20 pt, compact date, tight list selector and countdown rows with small controls. Keep all countdown behavior and persistence. |
| CPU | CPU icon/title and total in header; compact detected processor model and physical/logical core counts; logical-processor label, percent and thin bar per row; short gridded graph; compact pagination. |
| RAM | RAM header and percent; compact used/available/total rows, thin capacity bar, short gridded graph. |
| GPU | GPU header plus small activity readout; aligned sensor label/value rows and honest short availability/status labels. No invented graph or telemetry. |
| Drive I/O | Drive icon/title, compact capacity rows and thin usage bars; read/write arrows and rates inline for optional counters. |
| Network | Network icon/title, adapter subtitle, two compact colored rate rows, short gridded inbound/outbound histories. |
| Media | Small album art beside compact title/artist, slim progress, small transport symbols; setup state uses same panel. Queue remains honest about implementation status. |
| Visualizer | Short Audio header, compact device/status, tightly packed blue/colored bars on the near-black surface; small footer actions. |
| Settings | Global Settings title; Default theme dropdown; single fields for scale, width, gap and rounding; Accent 1/2 hex codes and swatches; Panel style rows for background color/transparency, border color/size and divider color/size; Text settings rows for title/header/body size and color. All eight swatches open the same independent RGB/HSV/Lab picker. Root owns this skin. |

Reduce each module's PanelHeight to match its content. Keep all necessary controls and meaningful states; no fake data to resemble a screenshot. Both Columns values must remain usable. Validate narrow width 180 and default 200, scales 0.75–2, long values and unknown states. Run relevant existing logic checks and real isolated Rainmeter checks where available. Root will capture actual isolated windows for visual inspection and stage the result.
