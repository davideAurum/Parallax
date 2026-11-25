# Independent utility settings

Use Global Settings as the layout reference for Chronometer, CPU, RAM, GPU, Disk Meter, Network, Media and Audio settings: meaningful sections, aligned labels and compact shaded value fields. This is the target contract for the conversion; each module's report records its implementation and validation status. Utility settings use body typography for values and header font size with Accent 1 for section headings. Global Settings keeps neutral field and table-column text while its section headings also use Accent 1; ColorPicker retains its neutral editor typography.

## Window and header

Each settings config is an independently loadable double-column window. Include shared defaults, persisted global choices and the module's user include, then set settings-local `Columns=2` and a content-appropriate `PanelHeight` before including Geometry and Styles. These local layout values must not be written back over the monitor's saved `Columns` or `PanelHeight`. Fit the height to the utility's actual settings and conditional content. The first time it opens it takes its step from the top left ([ARCHITECTURE.md](ARCHITECTURE.md#first-placement)).

Use `StyleBounds` and `StylePanel` for the window. The title follows `StyleTitle|StyleTitleRow`; reserve space for a top-right close control aligned with the title row. Closing deactivates only the settings config and leaves the monitor running. Set `SettingsUtilityName` and include `UtilitySettingsNote.inc` after the background meters. Its context line is at `Inset+32*Scale`, and its Global Settings link is at `Inset+50*Scale`; both reserve 18 logical px of height. Opening Global Settings is navigation and does not save choices or refresh the utility.

## Tall panels

Rainmeter is not DPI aware, so Windows scaling divides the screen first: a 1920 × 1080 screen is a 1536 × 816 work area at 125% and 1280 × 672 at 150%. Keep on screen, on by default, holds a window's top edge to its screen even while it is dragged, so before 2026-11-25 the rows below the screen could not be reached. Window heights at the default suite scale, gutter included, measured in an isolated Rainmeter with the shipped options; *tallest* shows every feature that folds rows away:

| Panel | Shipped | Tallest | Work area 816 px (1080p at 125%) | 672 px (1080p at 150%) |
| --- | --- | --- | --- | --- |
| CPU settings | 1064 | 1064 | Scrolls | Scrolls |
| Global Settings | 1005 | 1005 | Scrolls | Scrolls |
| Media settings | 822 | 906, queue expanded | **Not fixed.** Nothing lost as shipped (6 px of margin); with the queue expanded, Open queue, Player setup and Help | **Not fixed.** The queue's Start, Stop and Restart, the Connections link, Open queue, Player setup and Help; with the queue expanded, Source detection's Start and Stop too |
| Chronometer settings | 544 | 760, timers shown | Fits | Fits as shipped; scrolls with the timers |
| GPU settings | 712 | 712 | Fits | Scrolls |
| Network settings | 606 | 606 | Fits | Fits |
| Disk settings | 502 with one drive row, 558 on this laptop | 28 more for each row | Fits to 12 rows | Fits to 7 rows |
| Audio settings | 408 | 408 | Fits | Fits |
| Memory settings | 404 | 404 | Fits | Fits |
| Welcome | 408 | 408 | Fits | Fits |
| Connections | 326 | 326 | Fits | Fits |

Thread colors grows with the processor: 224 px at 8 threads; it passes 672 px above 40 threads and 816 px above 50. A larger suite scale multiplies all of these, and the panels without a scroll are then too tall sooner: Network settings is 909 px at 150%.

`@Resources/PanelScroll.inc` and `Scripts/PanelScroll.lua` (2026-11-25) fit a panel to the screen it is on. Global Settings and the CPU, Chronometer and GPU settings use them.

- **A work area tall enough:** the panel keeps its designed height, wherever it stands, and looks as before. The container below only re-composites the rows; against the previous commit the largest difference is one level in 255.
- **Too short:** the window ends at the work area's bottom edge, so it is shorter the lower its top stands; the title row (and the note lines, or Global Settings' Layout line and Connections) stays, and the rest scrolls. The wheel moves two rows. Two arrows left of the close button move a screenful less one row, for a touch screen or a mouse without a wheel; each is muted at its end. A thin bar in the right padding shows the position, and a divider marks where scrolled rows end.
- **Which screen:** the one holding the panel's center, as Keep on screen does. The fit is made when the panel loads, when the pointer enters it and when it scrolls, so a panel that was dragged, moved by [Arrange](WELCOME.md#arrange) or overtaken by a new scaling is right again when you next use it. Nothing polls. It counts from the panel's top because Keep on screen measures the whole screen, taskbar included, and because Arrange steps a panel down 30 px when a screen is full.
- **The position** survives a refresh, since nearly every saved value refreshes the suite. It is written to `%TEMP%\ParallaxScroll-<config>.txt` when you scroll and deleted when the panel closes.
- **The wheel** belongs to the panel's own actions, which Rainmeter runs only where no meter under the pointer has a wheel action, so a control that used the wheel would keep it. None of these panels' controls does. While a number is being typed the panel does not scroll, since the text box lies over its field.

### Using it in another panel

1. In the panel's `[Variables]`, set `PanelScrollTop` (logical px from the panel's top to where scrolling starts, above every scrolling meter) and `PanelScrollEditor` (its numeric entry measure, or leave it out).
2. `DynamicWindowSize=1`, and `DynamicVariables=1` on `MeterBounds`, `MeterPanel` and any other meter the size of the window.
3. Include `PanelScroll.inc` right after `MeterPanel`, before the rows. Leave 4 logical px free above the panel's bottom edge.
4. Add `Container=MeterScrollBody` to every meter that scrolls: all but the two above, the title, the close button, the note lines and a whole-window layer. Positions stay as they are, because the container starts at 0,0. `meter:GetX()` and `GetY()` already include the scroll, so text boxes and the color picker open where the row is.
5. In `[Rainmeter]`: `MouseOverAction=[!CommandMeasure MeasurePanelScroll "Fit()"]`, `MouseScrollDownAction=[!CommandMeasure MeasurePanelScroll "Wheel(1)"]`, the same with `Wheel(-1)` for up, and `Forget()` added to `OnCloseAction`.
6. A controller that changes `PanelHeight` sends `!CommandMeasure MeasurePanelScroll "Fit(true)"` after setting it and before it updates the meters.

### Why a scrolling body

| Way | Result |
| --- | --- |
| **Scrolling body (chosen)** | One container and one script. No row moves in the source, so the panels' reflow (CPU, Chronometer) and layout tests keep working. It fits any work area, suite scale and number of rows. It has to be discovered, hence the arrows and the bar, and its position has to survive a refresh. |
| Section tabs | Global Settings' Appearance section is 532 px, so with the title and footer it would fill 672 px at the default suite scale and fit neither screen at 150%. Tabs need a second layout for the two panels' 244 meters (or change how a tall screen looks), and the open tab has to survive a refresh too. |
| Collapsible sections | The same limit: the tallest section decides. Global Settings' rows have fixed positions, so each section would need the kind of reflow CPU settings has, plus remembered open and closed sections. |
| Shrinking the panel to fit | One formula, but 9 pt text becomes 6 pt at 672 px, which Windows then enlarges and blurs, on a screen someone set to 150% to read more easily. |

### Checks, 2026-11-25

`tools/tests/Test-PanelScroll.ps1` loads the four panels, in their tallest state, in an isolated Rainmeter and replaces only the work-area height that `PanelScroll.lua` reads. On the Surface laptop (Rainmeter 4.5.28.3936) it passed 9,849 checks at work areas of 816, 672 and 4000 px, each at 75%, 100% and 150% suite scale:

- The window is the designed height, or the work area's where that is shorter.
- Every clickable control (83 in Global Settings, 63 in CPU settings, 69 in Chronometer and 51 in GPU settings, arrows included) lies whole inside the visible part at some stop of the wheel, and again of the arrows, and every line of text does at some stop of the wheel.
- A mouse click posted to each control's center reached that control's action through Rainmeter's own hit test, and a click on the title part never reached a row scrolled behind it. The actions were replaced by a recorder first.
- Moved 30 and 200 px down the real screen, a panel too tall for the work area ends at its bottom edge at the next pointer entry, with every control still reachable at 30, and has its full height again at the top; a panel with room keeps its height.
- One posted wheel message moved the panel two rows; nothing moved while a stand-in for the number box was open; a refresh kept the place; closing forgot it and left no file.
- At 4000 px nothing scrolls and no arrow shows.

It saves a capture of every page. Six deliberate faults each made it fail: a control left out of the container, a range 40 px short, no fit at all, scrolling while typing, forgetting on a refresh, and ignoring where the panel stands. Captures at 4000 px differ from the previous commit's by at most one level in 255 for CPU, Chronometer and GPU settings (75%, 100% and 150%) and for Global Settings above its moved footer (100%).

On the real screen (1600 × 1067, work area 1019), unpatched and with Keep on screen on, CPU settings opened 1019 px tall instead of 1064 at the top and 619 with a saved position 400 px down, and Global Settings kept its 1005.

**What a simulated screen does not prove.** Only the number changed: Windows scaling itself, and so how the enlarged panel looks, was not exercised, and that Rainmeter reports 816 and 672 is arithmetic (1080 divided by the scaling, less a 48 px taskbar), not seen. Not tried either: a hand on a wheel, a touchpad (which can send many small wheel messages, each of which moves two rows) or a touch screen; dragging the panel on a short screen; several screens or mixed scaling; a taskbar on another edge; Rainmeter 4.5.26, whose container, hit-test and wheel code is identical to 4.5.28's in the source; and 5.x, whose code differs. A panel that does fit its work area can still be dragged or saved up to a taskbar's height lower, behind the taskbar, as before.

## Sections and rows

Organize related controls into named sections such as Appearance, Performance or Setup, according to the utility's actual options. Global Settings groups its controls under Appearance and Performance; utility panels should not add empty sections to reproduce those names.

Use `StyleUtilitySettingsSection`, `StyleUtilitySettingsLabel` and `StyleUtilitySettingsValue` from shared `Styles.inc`. Semantic section separators use `StyleRule`; only actual column-header underlines use `StyleTableHeaderRule`. Each visible meter still declares its own `Meter=String` or `Meter=Shape`; apply module-specific groups and actions after the shared style. Numeric dimensions below are logical px multiplied by `Scale`; expressions already include scaling. Horizontal positions are relative to `ContentX`.

| Element | Geometry and appearance |
| --- | --- |
| Section heading | Start below the shared note area; x=0, width `ContentWidth`, height 18. Use shared `HeaderFontSize`, Accent 1 (`AccentColor`) and weight 600 through `StyleUtilitySettingsSection`. |
| Table column heading | Use `HeaderFontSize` and `HeaderTextColor`, retaining Global Settings' neutral editor exception. Table column labels are distinct from section names. |
| Section separator | Use `StyleRule` with `DividerColor` and `DividerThickness` to separate semantic sections. Leave clearance around the heading, rule and adjacent controls for the supported 0–4 px stroke. |
| Column-header underline | Use `StyleTableHeaderRule` beneath actual table column labels, such as the color/size columns in Global Settings. It uses `TableHeaderBorderColor` and `TableHeaderBorderThickness`, independently of section dividers; reserve clearance for its supported 0–4 px stroke. |
| Setting row | Use 28 px pitch within a section. Leave the label area on the panel surface; shade the value field rather than the full row. |
| Label | x=0, default width `70*Scale`, height 18. Shared body font size/color and weight 500. Align its text with the adjacent field; Global Settings places the label 2 logical px below the field's top. |
| Value field | x=`76*Scale`, default width `ContentWidth-82*Scale`, height 18, padding 3/1/3/1. Shared body font size/color with `GraphBackgroundColor` fill. Padding adds 6 px to the rendered width and 2 px to the height. |
| Optional field backing | `StyleUtilitySettingsRow` draws only the value-field background at x=`76*Scale`, width `ContentWidth-76*Scale`, height 20. It may be omitted when the value meter's `SolidColor` supplies the background. Keep any local override aligned with the field's padded bounds. |
| Following section | Reserve space between the preceding content, the next heading and its separator. Longer explanations or conditional content need their own measured space. |

All values and available choices use `FontSize` and `TextColor`, including clickable toggles, numbers and selectors. Settings section headings use `HeaderFontSize` and Accent 1. Ordinary monitor headings and table column labels keep their existing header role. Retain semantic diagnostic/disabled colors where they convey state. An interactive setting is not an accent-colored command.

Keep a consistent label/value boundary within a section. Override the default field width for compact numbers, toggles, swatches or grouped choices; longer labels and values may require a different column split. Account for padding when calculating adjacent fields and panel bounds. Clip text within declared widths. Settings controls carry no tooltips, so labels must stand on their own and longer explanations belong in the module document. Do not allow a long device name, source or status to enlarge the window or cover its label.

Use the CPU-inspired previous/value/next control for numeric and cyclable settings, as detailed below. Keep explicit commands such as Open, Scan, Retry, Fit or Apply in their relevant sections. On/off choices remain toggles, and provider identity pickers retain their discovery/selection semantics. Passive status fields must not imply a click action.

## Numeric and cycling controls

Numeric controls have a decrement arrow, a centered editable value and an increment arrow. Arrows stop at the supported limits and do not write or refresh at a limit. Clicking the center opens validated numeric entry; Enter applies and Escape cancels. Keep the existing setting's units and supported values, including discrete sets where appropriate. A settings preset is not automatically the full supported numeric range. Preserve custom saved values until an explicit valid edit, and retain file editing for legacy expressions that the bounded numeric editor cannot represent.

Cyclable categorical choices use previous/next arrows with wrapping and show their current option in the center. The center retains an appropriate selection action such as opening its menu or cycling forward. Do not allow arbitrary typed text for an enumerated choice. A single available choice has visibly disabled arrows with no click action. On/off toggles, provider identity pickers, navigation, scanning and other commands retain their existing controls. Do not expose internal numeric enum IDs as scalar settings; for example, Visualizer cadence's zero means Suite inheritance.

Shared `StyleSettingsStepperButton`, `StyleSettingsStepperValue` and `StyleSettingsStepperFrame` provide the common typography and frame. Arrow text uses Accent 1; values use body `TextColor`. Global Settings retains its neutral editor text override. Each module declares `Meter`, X/Y, groups and actions locally. String X is the horizontal center; frame X is its left edge. A default group is 96 logical px wide: 18 px arrow, 2 px gap, 56 px field, 2 px gap and 18 px arrow. Frame height is 20 px, with the 18 px value and arrows one pixel below its top. Widen the field for longer numbers/units/options; override both frame W/Shape and value W together. Keep the group's alignment consistent with other value fields and remove every component's hit bounds when its dependent settings row collapses.

Reuse the existing one-shot `@Resources/Scripts/SettingsInput.ps1` helper for new typed numeric fields. The module passes fixed `-Key UtilityNumber`, canonical `-Minimum`, `-Maximum` and `-DecimalPlaces` (0–4), plus the existing initial value and physical window coordinates/size/scale. Plain signed decimal values are bounded to magnitude 1,000,000,000; units, expressions and exponents are not input syntax. The result remains `PARALLAX_INPUT_V1|ok|<number>` or `PARALLAX_INPUT_V1|cancel|`. The module owns the exact setting-key allowlist, validates direction, range, precision and any discrete membership again, and performs its established persistence/apply action. User text is data and must never enter a Rainmeter action or PowerShell command. The helper receives no module key or destination path and writes no files. Numeric entry adds one process only on an explicit click; arrows and categorical cycling launch none. Update the module dependency list when adopting RunCommand/PowerShell/WinForms for this input.

Global Settings' **Idle pause** row (2026-10-23) is another cyclable categorical choice of this kind: Off / 5 min / 10 min / 30 min with wrapping arrows and a forward-cycling centre; a hand-edited value shows Custom and is kept until a choice. Its apply scope differs by step (see [SETTINGS.md](SETTINGS.md#idle-pause)). Utility settings panels have no idle option of their own: the pause is suite-wide.

## Behavior and validation

When a saved visibility option hides a section on the utility, collapse that feature's corresponding settings details. Keep its section heading and visibility control accessible, either together in a compact collapsed row or through the existing Visibility group, so the feature can be shown again. Remove the hidden controls' occupied space and hit targets, reflow later sections and resize the settings window. Showing the feature restores its details and previously saved values. In a mixed section, collapse only the dependent subsection or rows, preserving controls used by other visible features.

Use the utility's existing visibility state, not whether the skin is loaded, telemetry is unavailable or an optional provider is disconnected. Keep setup and recovery controls available. General Appearance, Performance and Setup sections remain when they have applicable controls. Do not invent new visibility preferences or start polling merely to support this layout. Recompute through the existing initialization, settings-change and refresh paths, and preserve the monitor's saved width and height.

Reorganize presentation while preserving every existing option, provider selection, supported value, persistence key and save/apply behavior. Do not start providers or collection work simply because a settings window opens unless that is already the documented behavior. Preserve missing-provider states, setup guidance and access to existing actions. Update the module's Dependencies section if the implementation changes runtime, helper, plugin, service or asset requirements; layout changes alone do not create a new dependency.

Validate the settings window independently of the monitor's single/double-column selection and saved height. Check at least column widths 180 and 220 and scales 0.75, 1, 1.25, 1.5 and 2, including maximum title/header/body font sizes of 12/10/10 pt. Cover long values, unknown/disabled states and conditional sections. Confirm title/close clearance, note/form separation, label/value bounds, usable click targets and a panel height that contains the final row.

Use relevant existing controller tests to verify actions and persistence. Where isolated native Rainmeter checks are available, exercise fields and associated click targets, save or apply, refresh persistence, independent close and Global Settings navigation without modifying the user's live configuration. Inspect representative native captures for clipping, text/field alignment and separator/header-rule clearance. Record what was checked and any runtime limits in the module report; source-only geometry checks do not establish native rendering success.

For conditional sections, check hide/show transitions, accessible re-enable controls, hidden hit targets, compact reflow and restored values after reopening or refresh. Validate representative all-visible and collapsed states at narrow and large scale. Report explicitly when a utility has no applicable visibility-controlled settings details.
