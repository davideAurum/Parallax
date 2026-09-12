# Chronometer prototype

Chronometer provides a local clock/date, system uptime, a named event countdown, and three named lists with four independent duration timers per list. It uses Rainmeter's built-in Time, Uptime and Script measures. The bundled RunCommand plugin opens the original native event editor only on request; there is no downloaded plugin, polling process or network request. This is an initial implementation, not a performance or release-readiness certification.

## Use and configuration

Load `Parallax\Chronometer`, `Chronometer.ini`. The settings menu organizes the utility into four sections: **Clock/Date**, **Uptime**, **Event Countdown**, and **Timers**. Each section has a **Shown / Hidden** control. Hiding a section closes its space without stopping its timekeeping; the header and hover gear remain accessible even when all four sections are hidden.

Use the timer arrows to select a list. All twelve timers continue independently when another list is displayed or the Timers section is hidden; the visible footer counts running and completed timers across all lists.

- **Start** begins a timer. **Pause** freezes its remaining seconds. **Resume** starts a new deadline from that remaining time. **Again** restarts a completed timer at its configured duration.
- **Reset** stops only that timer and restores its configured duration. There is no automatic sequencing or cycling.
- **Edit lists** opens the dedicated Chronometer settings menu, as does the gear that appears at the top right while hovering over the utility. The title remains centered. The context menu also offers Chronometer settings, direct module editing and shared Parallax settings.
- Edit `ChronometerList1Name` through `ChronometerList3Name`. Edit each `ChronometerList<list>Timer<row>Label` and `ChronometerList<list>Timer<row>Seconds`, with list 1–3 and row 1–4. Seconds must be decimal whole numbers from 1 to 604800 (seven days); empty values, expressions, decimals, negatives, and out-of-range values show **Fix duration** and disable that timer. Leading zeros are accepted. Missing keys use shipped defaults; blank labels use default names.
- Label characters `#`, `%`, `[` and `]`, and control characters are replaced with spaces before display to prevent Rainmeter expression expansion. Timer/list labels are single-line text and clip to their declared meter width. The settings file itself is ordinary trusted Rainmeter INI configuration, not an untrusted import format.
- `Columns=1` or `Columns=2` changes painted width using shared geometry. The same four timer rows expand horizontally in the double-width variant. At default font and divider settings, all sections together use 356 logical pixels in height. Hidden sections are removed from that height. `PanelHeight=356` is the baseline; lower values in older User files are handled automatically, while values above 356 retain the difference as extra padding. Larger supported fonts and thicker dividers add the space described under Appearance and layout.
- `ChronometerClockFormat=%H:%M:%S` defaults to a 24-hour clock. For twelve-hour time use `%I:%M:%S %p`. `ChronometerDateFormat=%A, %d %B %Y` controls the local date using the official Time measure format syntax.

Visibility is saved in `[Variables]` in `@Resources/User/Chronometer.inc`. Each key defaults to `1`; `0` hides the whole section, including its dividers and, for Timers, its footer.

| Section | Saved key | Default height contribution |
| --- | --- | --- |
| Clock/Date | `ChronometerShowClock` | 52 logical pixels |
| Uptime | `ChronometerShowUptime` | 24 logical pixels |
| Event Countdown | `ChronometerShowEvent` | 42 logical pixels |
| Timers | `ChronometerShowTimers` | 208 logical pixels |

Each section separator is the top border of the section below it: Uptime, Event Countdown or Timers. Its visibility and vertical position follow that section, so hiding the final sections leaves no floating divider beneath the remaining content. The clock keeps its existing header layout. Timer-row and footer dividers remain part of Timers.

The module's `Defaults.inc` loads before the preserved User include, so upgrades with missing visibility keys show all four sections. Existing explicit choices take precedence. Hiding Event Countdown retains its saved target and its continuing countdown. Hiding Timers retains running deadlines, paused states and completion processing; show the section again to see them.

Duration edits reset only the corresponding slot on reload. Renaming a timer or list preserves its state. Identity is its list/row position: moving settings between slots does not move state. Invalidating a duration discards that slot's active state; correcting it creates a fresh stopped timer. Visibility, scale, color, clock-format, and `Columns` changes preserve every unchanged-duration timer.

## System uptime

The section immediately below the time and date shows **Uptime** as days and `hours:minutes:seconds`, updating once per second. It measures time since the last full Windows restart using the native Uptime measure. It does not reset when Chronometer is refreshed or Rainmeter is reopened. Windows Fast Startup can preserve this value through a normal shutdown; a full restart resets it. See the [official Uptime measure documentation](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/uptime.html).

At default typography and divider settings, this contributes a 24-logical-pixel row between dividers. Hiding Uptime removes that row and closes the space. It adds no plugin, script, process launch, or persisted state.

Historical uptime-only validation, before adding the event section and visibility controls: four native Rainmeter cases passed **2,152 assertions**, with no errors, at width 180, Columns 1/2 and scales 0.75/2. Checks cover real uptime advancement, agreement between elapsed seconds and displayed days/time, eight minute/hour/day rollover samples in an isolated formatting measure, native text fit through `9999d 23:59:59`, divider/label/value/list separation, and the existing countdown and gear controls. That version used a 310-logical-pixel panel; its single/double windows measured 141×239 / 282×239 at 75% and 376×636 / 752×636 at 200%. These checks did not restart Windows or change the live desktop.

## Event countdown

The event section contains only two tightly spaced, left-aligned body-text lines:

~~~text
Countdown to Vacation:
5d 3h 20m 10s
~~~

There are no commas or spaces between a number and its unit; the four groups have one space between them. The numeric line starts directly below the label. The main panel has no separate Event countdown heading, inline Add/Edit link or ordinary target-date row. A long name clips on its own line so the numeric countdown stays visible; hover either line for the complete event text and target date.

Open the hover gear, then **Event Countdown → Add / edit event countdown** to configure the event. Enter a name, date and local time, then click **Save event**. New events default to tomorrow at midnight, so selecting just a date counts toward the start of that day. The same settings button reopens the form; **Clear event** removes the countdown and **Cancel** preserves the saved event.

The numbers update once per second. At or after the target, the label becomes **Event reached: Vacation** and the numeric line stays at **0d 0h 0m 0s**. Missing or unreadable data and editor failures show concise setup/repair guidance in these same two lines. No extra status-row space is reserved. The event continues through sleep, closed-app time and Rainmeter restarts; changing its presentation does not alter the saved deadline. Saving an event does not reset the twelve duration timers. System clock adjustments affect remaining time. There is no pause, recurrence, alarm, notification or automatic removal.
Date/time entry uses the current Windows time zone and accepts years 2000–2099. Times skipped or repeated during daylight-saving transitions are rejected with an inline explanation; choose an unambiguous local time. Saving resolves the chosen time to one fixed UTC instant. Changing the Windows time zone later changes the displayed local target, not the event's deadline. Names allow up to 80 UTF-16 code units, including ordinary Unicode text, but not control characters or whitespace-only names. Rainmeter expression delimiters are neutralized only for display.

The event lives in `#SETTINGSPATH#Parallax-Chronometer-event-v1.state`, separate from distributable User settings and the duration-timer snapshots. The inert ASCII envelope contains a version, integer UTC deadline, UTF-8 name encoded as hex, original local-entry text and checksum. A clear action atomically saves a disabled record. Saves replace the complete file from a temporary file in the same directory and read back the result. Invalid/truncated data shows **Event unavailable** with an edit-to-repair prompt. The skin reads this small file on load, explicit reload and editor completion; ordinary ticks do not read or write it. Keep this file out of distribution and source control.

The form is original C# WinForms code compiled with the installed .NET Framework compiler. It runs only while editing and needs no installation, network access, external PowerShell runtime or execution-policy change. Closing the settings menu leaves an open event form usable because the main Chronometer config owns its launch. Reloading the utility while editing does not change the existing saved event; refresh once more if a save finishes after that reload.

At default typography and divider settings, the visible event section contributes 42 logical pixels. Hiding it removes that space while retaining the event. The all-visible main baseline is 356 logical pixels; the current four-section settings menu is 526 logical pixels high. Older, smaller main `PanelHeight` settings no longer need manual enlargement.

Historical event validation, before the four-section visibility layout: countdown logic passed **70 Lua checks**, including codec parity, strict input validation and time-boundary behavior. Four native frontend cases passed **2,716 assertions** across width 180, Columns 1/2 and scales 0.75/2; a settings lifecycle case passed **408 assertions**. That version used a 398-logical-pixel utility and a 444-logical-pixel settings menu. Native checks cover missing/future/reached/invalid/cleared events, advancement, long names, sanitization, date-only targets, cached reads and existing timer/settings controls. These historical results do not verify the new visibility or typography layout. The editor form has separate validation described below.

### Editor build and validation

`EventEditor.exe` is compiled locally from `EventEditor.cs` and `EventEditorForm.cs` using the existing .NET Framework C# compiler and runs on .NET Framework 4.6 or newer. It is a Windows GUI executable, not a downloaded application or script interpreter. The optional `Build-EventEditor.ps1` wrapper invokes this command; where script execution is restricted, the compiler can be invoked directly from a development shell without changing execution policy:

```powershell
$chronoModule = (Resolve-Path './Skins/Parallax/@Resources/Modules/Chronometer').Path
& "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ '/reference:System.Windows.Forms.dll,System.Drawing.dll' "/out:$chronoModule\EventEditor.exe" "$chronoModule\EventEditor.cs" "$chronoModule\EventEditorForm.cs"
```

The native executable passed **14 codec/storage/CLI checks**, covering local-to-UTC conversion, invalid/ambiguous DST times, Unicode and name limits, matching Lua checksum vectors, corruption rejection, atomic replacement and failed-write preservation, clear records, and redirected output. The interactive harness successfully launched the production executable through Rainmeter's actual RunCommand action, but the computer-use tool did not expose the form's window; that manual Save test timed out and is not counted as a pass. Physical mouse/keyboard interaction remains unverified. All test state was isolated from the user's event and timer files.

Seven additional form-controller checks passed against the actual unshown form, exercising Save/Clear handlers, cancellation, prefill, Unicode, validation, midnight defaults and control bounds. An authored-control render at `Tests/.preview/event-editor.png` was inspected for readability and clipping; it is not a desktop screenshot. A separate **29-check automated Rainmeter integration passed**: a test-only executable compiled from the production sources plus an alternate test entrypoint populated the unshown form, called its actual Save handler, and emitted `SAVED`. The copied skin retained the production RunCommand arguments and FinishAction while targeting that test executable. The real FinishAction loaded the new name, date and advancing countdown without a test-driven Reload. The production executable was unchanged. See `Tests/EventEditorSmoke/README.md` for the distinction between this automated result and the unfinished physical interaction check.

## Dedicated settings menu

The hover gear opens `Parallax\Chronometer\Settings`, `Settings.ini`, as a separate config. The clock and all countdowns keep running while the menu is open; its **X** closes only the menu. The menu is 526 logical pixels high and always spans two columns for readable controls, independently of Chronometer's selected width. It follows the shared scale, typography and colors. Refresh Rainmeter's skin list once after adding this subconfig to an existing installation.

- The four section headings are **Clock/Date**, **Uptime**, **Event Countdown**, and **Timers**. Click the **Shown / Hidden** button beside a heading to change that section's visibility in the main utility. Its settings remain available in this menu while the section is hidden.
- Under **Clock/Date**, click **Clock** to switch 12/24-hour time, **Seconds** to show/hide clock seconds, and **Date** to cycle full/short/ISO formats. **Panel width** switches Chronometer between one and two columns. Custom clock/date formats remain available through advanced editing; clicking the corresponding preset control replaces a custom format with a standard one.
- **Uptime** explains the native Windows uptime measurement. **Event Countdown** provides **Add / edit event countdown** for the separate name/date/time form, alongside its visibility choice.
- Use the list arrows to choose one of the three lists for editing. This selection does not change the list currently displayed by the running utility.
- Click a countdown duration to cycle presets: 1, 5, 10, 15, 25, 30, 45, 60, 90 and 120 minutes, then 4/8/12 hours and 1/2/7 days. **Step** cycles through 1 second, 1 minute, 5 minutes and 1 hour; **- / +** adjusts that row using the chosen step. Durations stay within 1–604800 seconds. An invalid duration reads **Fix duration**; a duration control repairs it to the first preset, one minute.
- Each successful change saves immediately to `User/Chronometer.inc`, verifies the written value, and refreshes only `Parallax\Chronometer`. A duration change resets that timer; other timer deadlines and paused states remain intact. A failed save displays an error instead of reporting success. These controls do not change shared settings.
- **Edit names / advanced** opens the module include in Rainmeter's configured editor for list names, timer labels, exact durations and custom formats. Save the file and click **Apply saved edits** to reload both the utility and this menu. This also updates names displayed by the menu.

The menu uses fixed commands and native `!WriteKeyValue`; it preserves unrelated configuration keys and comments. It launches no background polling process and does not use InputText. Duration buttons avoid passing arbitrary text into an executable Rainmeter action. Original gear geometry is shared visually with the other Parallax utilities without adding a shared-file dependency. The main layout uses the selected text sizes and adds space when supported font sizes or divider thickness increase.

Historical settings validation on 2026-09-11, before the event and section-visibility additions: **53/53 Lua checks passed**, comprising the existing 38 timer/store/adapter checks and 15 settings cases. The additional cases cover toggles, preset/step bounds, list isolation, custom formats, label sanitization, failed saves, targeted refresh, and UTF-8 BOM/UTF-16 scalar readback. Four focused native frontend cases (width 180, Columns 1/2, scales 0.75/2) passed **1,844 assertions** for the hover actions, layout and twelve-hour clock text fit. One native settings lifecycle case (width 180, initial Columns 1, scale 0.75) passed **388 assertions**: the actual gear opens the nested config, literal percent clock formats survive a real settings write, a duration change resets only that timer, another running timer retains its exact deadline through refreshes, width changes persist while the menu stays two columns wide, and closing the menu leaves Chronometer loaded. No Rainmeter errors were logged. All checks used copied skins and isolated settings, without changing the live desktop. Native action dispatch and meter geometry were tested; physical pointer hover, screenshot appearance and mixed-monitor DPI were not.

## Appearance and layout

The layout builds on `docs/APPEARANCE.md` revision 2: an original clock-face icon and compact header, a centered 20-point clock at the default body size, a small local date, tight list arrows, and four timer rows with a 37-logical-pixel pitch at default sizes. Native text probes showed that default body labels need a 16-logical-pixel box; the additional pixel in each row brings the Timers section to 208 logical pixels. It inherits `FontFace` and shared surfaces/borders. No upstream code, icons, or reference imagery are included.

Typography and color have distinct roles. `TitleFontSize` and `TitleTextColor` style the utility/settings titles. `HeaderFontSize` and `HeaderTextColor` style section and list headings. `FontSize`, `TextColor` and `MutedColor` style body and supporting text; the large clock and countdown digits derive their sizes from `FontSize`. The selected title, header and body sizes are used directly, with extra space for larger supported choices rather than a hidden font-size clamp. `ClockColor` colors time values and the clock icon. `AccentColor` colors primary controls; `AccentColor2` colors secondary actions such as Reset, Edit lists, the event editor action and settings close/advanced controls. `DividerColor` and `DividerThickness` control dividers and row separators, independently of panel borders. Shared choices may be overridden locally in `User/Chronometer.inc`.

With all sections shown, default fonts/dividers and `PanelHeight=356`, the painted panel is 356 logical pixels high. At the default 200-pixel painted column and scale 1, its full window is 208 × 364 pixels; two columns produce a 416 × 364 window. A 180-pixel column produces a 188 × 364 window. Hiding all sections leaves a 30-logical-pixel header at default sizes. Larger title sizes and extra user padding can make that header-only panel taller. Transparent gutters remain unchanged. Fixed text and control boxes keep long labels from enlarging the window; supported typography changes adjust the planned boxes and spacing instead. Label, title, clock and footer boxes round upward to whole pixels where needed at fractional scales. Buttons retain zero padding and descriptive tooltips.

`Layout.inc`, loaded after shared geometry, computes the main utility's height. At default font sizes and scale 1 this is `max(356, PanelHeight) - 52*(1-Clock) - 24*(1-Uptime) - 42*(1-Event) - 208*(1-Timers)`, where each section flag is 0 or 1. The full calculation includes typography, per-line pixel rounding and divider spacing:

| Layout value | Logical-pixel calculation |
| --- | --- |
| `TitleExtra` | `max(0, 2*(TitleFontSize-10))` |
| `BodyExtra` | `max(0, 2*(FontSize-9))` |
| `HeaderExtra` | `max(0, 2*(HeaderFontSize-8))` |
| `RuleExtra` | `max(0, DividerThickness-1)` |
| `DateExtra` | `16 + BodyExtra` when `Columns=1`, `ColumnWidth<200` and `FontSize>9`; otherwise `0` |
| Clock height | `52 + 2*BodyExtra + RuleExtra + DateExtra` |
| Uptime height | `24 + BodyExtra + RuleExtra` |
| EventLineHeight (physical pixels) | `ceil(1.8*FontSize*Scale)` |
| Event height | `8 + 2*EventLineHeight/Scale + RuleExtra` |
| Timers height | `208 + HeaderExtra + 13*BodyExtra + 4*RuleExtra` |

The total is `30 + TitleExtra + max(0, PanelHeight-356)` plus the heights of shown sections. Content begins at `24 + TitleExtra`; each subsequent section starts after the shown sections above it. The extra date line accommodates a full date at larger body sizes in a narrow single-column panel. Pixel height is `Round(logical height * Scale)`, and the full window adds the shared transparent `Gap`. The table uses shorter names for the `Chronometer...` variables in `Layout.inc`. Each event line rounds upward to physical pixels and the numeric line begins immediately after the label, so fractional scales can differ slightly from simply scaling the 356-pixel baseline.

Clock/date formats, timer definitions, transitions and snapshot schemas are preserved. The normal footer remains `All lists: N running / N done`. Existing users preserving `PanelHeight=530` can set it to 356 to remove their extra padding; values below 356 use the current minimum automatically. Higher saved values, including the former 398-pixel baseline, retain extra padding until explicitly changed. Wider panels remain available through global `ColumnWidth` and module `Columns` settings.

## Troubleshooting compressed or unstyled panels

If several Parallax utilities collapse into a small area, first check Rainmeter's configured **SkinPath**, before editing scale or meter geometry. The `Parallax` suite folder must be directly inside the configured skin folder:

```text
<SkinPath>\Parallax\Chronometer\Chronometer.ini
<SkinPath>\Parallax\@Resources\Defaults.inc
<SkinPath>\Parallax\@Resources\Geometry.inc
<SkinPath>\Parallax\@Resources\Styles.inc
```

For development from this repository, SkinPath must be `<repository>\Skins\`, not `<repository>\`. The loaded config should be named `Parallax\Chronometer`, not `Skins\Parallax\Chronometer`. For a normal installation, copy the whole repository `Skins/Parallax` directory into the existing Rainmeter skins folder. All utilities share this requirement.

Rainmeter resolves `#@#` from the first config folder under SkinPath. When the repository root is used as SkinPath, that first folder becomes `Skins`; Rainmeter then looks for shared resources in `<repository>\Skins\@Resources\` instead of `<repository>\Skins\Parallax\@Resources\`. Missing includes remove shared dimensions, styles, and module settings. This is a suite-wide installation-root problem; changing every module's sizes would not repair it.

Confirmed during live-configuration diagnosis on 2026-09-11. Earlier native smoke tests staged the correct folder topology, so they did not detect this installation error. A read-only preflight is available as `@Resources/Modules/Chronometer/Tests/Test-InstallationRoot.ps1`; it reads Rainmeter.ini and checks shared resources and all main utility entrypoints. It does not change Rainmeter or launch processes.

The preflight passed eight isolated positive/negative filesystem fixtures, with file hashes confirming no changes. After explicit user approval, the live installation was backed up and corrected; saved Chronometer/CPU config names were migrated while retaining positions and options. Rainmeter restarted normally. The live preflight then found all shared files, all nine main configs, and two valid active Parallax configs. Rainmeter's About log showed both modules refreshing under the correct root with no error or warning entries.

Repair requires a backup of Rainmeter.ini, the corrected SkinPath, migration of saved `Skins\Parallax\...` config sections to `Parallax\...` while retaining their settings, and a Rainmeter restart. Preserve state snapshot files and User settings. This troubleshooting guidance does not authorize an automated change to a user's live installation.

## Countdown semantics

Running timers use a persisted deadline in epoch seconds from Lua `os.time()`. Remaining time is `max(0, deadline - current time)`, sampled once per second. Paused timers persist a remaining-seconds value instead of advancing a deadline.

Sleep, hibernation, unloaded skins, a stopped Rainmeter process, and a computer restart all count toward a running timer. Reopening an expired timer shows **Done** at the next update. Paused timers remain paused across those events. Refreshing the module or a shared `!RefreshGroup Parallax` reads saved state before continuing.

These are wall-clock duration timers: moving the system clock forward shortens or completes running timers; moving it backward extends them, potentially beyond the original configured duration. A timer already marked Done stays Done after a later backward adjustment. Time-zone and daylight-saving display changes do not alter epoch deadlines when the underlying system timestamp is unchanged. Resolution is one second, with display/action latency dependent on Rainmeter scheduling. This version has no sound, notification, scheduled wake, lap/stopwatch, or automatic restart behavior. It is not a monotonic elapsed-time stopwatch. The separate dated-event section follows its fixed target rather than these start/pause/reset transitions.

## Persistence and recovery

Runtime data lives outside the skin distribution, beside Rainmeter.ini in the directory provided by `#SETTINGSPATH#`:

```text
Parallax-Chronometer-v1.a.state
Parallax-Chronometer-v1.b.state
```

Each snapshot has a version, increasing generation, selected list, twelve numeric/state records, and a terminator/checksum. The decoder limits file size, validates complete record count and slot order, bounds numeric fields, and accepts only supported states. It never executes persisted text. The checksum detects accidental damage; it does not authenticate edits.

Every save writes the alternate snapshot, closes it, and reads it back for validation before advancing its generation. Startup selects the valid snapshot with the greatest generation. An interrupted save can therefore fall back to the previous completed save, potentially losing the most recent action. If a file is damaged, the skin displays a recovery message and logs it. If neither snapshot is readable/valid, timers start stopped at their configured durations. An unknown future schema is treated as unreadable rather than executed. The v1 filenames isolate future migrations, which must be explicit.

State is saved on start/pause/resume/reset, list selection, completion, and reconciliation after duration edits. No per-second checkpoints are needed: a running deadline is already sufficient to reconstruct the countdown after a crash. Idle/paused timers create no periodic writes. Failed writes show **NOT SAVED** in the footer and log an error; pending state is retried after 60 subsequent measure updates, or immediately on another control/completion. Until a successful save, refresh/restart can restore older state. Writes are closed/read-verified, but no OS-level durability guarantee against sudden power loss is claimed.

This initial namespace supports one Chronometer config per Rainmeter settings directory. Duplicating configs that share these two files is unsupported; there is no cross-instance lock. To intentionally clear runtime state, unload this module and remove only these two Chronometer snapshot files, then reload. A portable Rainmeter install places them beside its own Rainmeter.ini. Keep both snapshots out of packages, source control, and example assets. No machine-specific paths or user state ship in this module.

## Implementation and integration

- `Skins/Parallax/Chronometer/Chronometer.ini`: include contract, clock/date/uptime, fixed bounds/panel, clipped text, controls, shared settings context action, `Group=Parallax`.
- `Skins/Parallax/Chronometer/Settings/Settings.ini`: independently loaded module settings menu; packaging must retain this nested config.
- `@Resources/Modules/Chronometer/Settings.lua`: validated preset/step controls, readback-verified settings writes and targeted utility refresh.
- `@Resources/Modules/Chronometer/Defaults.inc`: default-visible section flags loaded before preserved User settings.
- `@Resources/Modules/Chronometer/Layout.inc`: visible-section height and spacing, including typography/divider allowances; loaded after shared geometry in the main utility only.
- `@Resources/Modules/Chronometer/EventCore.lua` and `Event.lua`: strict inert event codec, countdown formatting and cached Rainmeter display adapter.
- `@Resources/Modules/Chronometer/EventEditor.cs`, `EventEditorForm.cs` and compiled `EventEditor.exe`: original native name/date/time editor and atomic event persistence.
- `@Resources/Modules/Chronometer/Core.lua`: Lua 5.1 state transitions and strict serialization; no filesystem or Rainmeter dependency.
- `@Resources/Modules/Chronometer/Store.lua`: alternating snapshot reader/writer.
- `@Resources/Modules/Chronometer/Chronometer.lua`: Rainmeter adapter; only fixed numeric control calls are exposed from actions. Label strings are sanitized before separate-argument `SKIN:Bang` calls.
- `@Resources/Modules/Chronometer/Styles.inc`: module styles without `Meter` keys; all actual meters explicitly declare their type.
- `@Resources/User/Chronometer.inc`: every supported module setting and shipped default under `[Variables]`, for packager preservation.
- `@Resources/Modules/Chronometer/Tests/`: source-level and native Lua test harness; generated runtime artifacts are test-only.

The skin updates at 1000 ms independently of telemetry settings so displayed countdown seconds do not skip when sensor sampling changes. Each update checks twelve duration states and the event deadline, updates changed meter options, and redraws the data groups. It launches no polling process. Only explicit advanced-edit/event actions open editors. It does not depend on a script unload/finalize callback; all durable transitions are saved as they happen.

Shared integration proposal: retain the original compiled `Modules/Chronometer/EventEditor.exe` through an exact packaging allowlist, with its two C# source files and build instructions. No downloaded binary or system installation is needed. Preserve `User/Chronometer.inc`, include the module defaults/layout files, and exclude test runtime/event state. The main include order is shared defaults, shared User settings, module defaults, module User settings, shared geometry, module layout, shared styles, then module styles. The settings menu has its own fixed 526-logical-pixel height and does not apply the main utility's visibility layout. Root owns shared allowlist and packaging changes. Release geometry checks still need actual snapped windows under mixed Windows DPI.

## Validation record

Section-top divider ownership: **21 native layout cases / 6,848 assertions passed**, covering all 16 visibility combinations at width 180, one column and scale 1, plus masks 0/1/3/7/15 at 75% scale with 4-pixel dividers. The checks verify each divider follows its owning section, sits at that section's actual top, resets its hidden anchor to Inset, and never remains below the last visible section. No Rainmeter errors were logged. Static validation passed 20 configs and 65 INI/include files with zero errors or warnings. This change leaves section geometry and timekeeping unchanged and performs no live refresh.

Current compact two-line event format: **77 Lua checks and 705 focused native frontend assertions passed** at width 180, one column and 75% scale. The native window measured 141 × 274, with no Rainmeter errors. Checks verified exact adjacent left-aligned label/value rows, compact units, no removed heading/Edit/date meters, clipped long names with the numeric row intact, complete tooltips, advancing time and reached/invalid/clear states. Saved deadlines and existing preferences were preserved. No live refresh was performed.

Earlier comma-separated combined event text, before the compact two-line refinement: **77 Lua checks passed**, including the new unit-separated formatting and rollover boundaries. Two focused native frontend cases passed **732 checks** at width 180, one column and 75% scale, and **735 checks** with title/header/body sizes 12/10/10, 200% scale and border/divider thickness 4. Checks verified left alignment, natural wrapping of the full requested sentence, full-text tooltips, advancing remaining time, reached zero units, and clear/corrupt states. The corresponding windows measured 141 × 317 and 376 × 1022. No Rainmeter errors were logged. Static validation passed 20 configs / 65 INI/include files with no errors or warnings. Existing saved clock/visibility choices were preserved; fixture-only overrides keep the tests independent of those choices. These checks used isolated skins and state, with no live refresh.

Historical section-visibility and typography validation, before the combined event-text format: **77 Lua checks passed.** Native Rainmeter checks passed all 16 show/hide combinations at width 180, Columns 1 and Scale 1, including actual window collapse, section spacing and the available header gear. After the final timer-label spacing adjustment, the affected eight combinations were repeated and passed **3,212 checks**; combinations without Timers were unchanged. The all-visible default window is 188 × 410, and hiding every section leaves 188 × 38.

Four final native cases at maximum title/header/body sizes **12/10/10**, Columns 1/2, scales 0.75/2 and border/divider thickness 4 passed **1,764 checks**. Twelve native text probes cover title, section/list headers, body labels, wrapped full date, clock, uptime, event/countdown, footer, Resume and invalid-duration text. Maximum-size single-column windows measured 141 × 373 / 376 × 994; double-column windows measured 282 × 359 / 752 × 958. Four maximum-size header-only cases and a zero-border/zero-divider case also passed.

The dedicated settings lifecycle passed **805 checks at default sizes and 805 at maximum sizes**: the actual gear opens the menu, all four production visibility controls save off/on, the main panel compacts after refresh, event bytes and running timer deadlines are preserved, duration edits reset only their own timer, width changes preserve the two-column menu, and closing settings leaves Chronometer running. Full frontend behavior passed **729 checks at default size/75% scale and 732 at maximum fonts/200% scale**, covering timer controls and event-state transitions after the final row adjustment. No Rainmeter errors were logged in passing runs. Shared static validation passed 20 configs and 65 INI/include files with zero errors or warnings.

All native tests used copied skins and isolated state. The checks measure native text extents, geometry and action dispatch; they do not establish physical pointer hit testing, screenshot appearance, mixed-monitor DPI or performance. No live refresh or configuration change was performed for this revision.

The historical checks below used installed Rainmeter **4.5.26.3894 / Lua 5.1** on 2026-09-11. The original appearance revision 2 records predate the settings menu, uptime and event sections; later focused validation is recorded above. They remain evidence for those earlier implementations, not a claim that the current visibility/typography matrix has passed.

- **38 executable checks passed, 0 failed.** Production Core/Store tests cover start/pause/resume/reset, expiry and restart, all-list advancement, invalid durations, offline time, both directions of clock adjustment, configuration reconciliation, complete/strict snapshot parsing, malformed checksummed records, numeric boundaries beyond 2038, truncation/recovery, an actual read-only destination, and simulated partial-write/close/readback failures.
- Adapter tests load the production adapter with a mocked Rainmeter skin/store. They verify immediate action saves, zero ordinary-tick saves, one save for simultaneous hidden-list completions, exactly 60-update retry with one error log, refresh restoration, duration edits, inert labels, and command parameter guards. These mocks do not themselves prove actual Rainmeter UI integration.
- Static inspection verified **35 explicit meters**, style references, style sections without Meter keys, button tooltip availability, `Group=Parallax`, and the include contract. **1,500 fixed String/Image meter-box checks passed** across 50 combinations: widths 180/200/240/280/320, Columns 1/2, and scales 0.75/1/1.25/1.5/2. These checks use declared geometry; they do not substitute for rendered text or mixed-DPI snapping checks.
- **40 native cases passed, 18,000 assertions, zero failures or Rainmeter error entries.** The matrix combines 180/200-pixel widths, Columns 1/2, scales 0.75/1/1.25/1.5/2, and normal/edge fixtures. The 20 normal cases passed 8,900 assertions; the 20 edge cases passed 9,100. Checks inspect actual aligned meter rectangles, non-overlap between timer text and controls, in-panel bounds, native text extents for `7d 00:00:00`, `Resume`, and `Fix duration`, clock/date output, command dispatch, and snapshot persistence. Edge fixtures use long list/timer labels, a seven-day countdown, and an invalid second timer, including its disabled control. All processes exited normally and generated run directories were removed. See the Smoke README for detailed results.

Calculated current baseline dimensions with all sections shown, default fonts/dividers and `PanelHeight=356`:

| Scale | Default 200px single window | Default double window | Painted widths | Transparent gap |
| --- | --- | --- | --- | --- |
| 75% | 156 × 274 | 312 × 274 | 150 / 306 | 6 |
| 100% | 208 × 364 | 416 × 364 | 200 / 408 | 8 |
| 125% | 260 × 455 | 520 × 455 | 250 / 510 | 10 |
| 150% | 312 × 545 | 624 × 545 | 300 / 612 | 12 |
| 200% | 416 × 726 | 832 × 726 | 400 / 816 | 16 |

Historical baseline before appearance revision 2: 38 Lua checks and eight native cases/1,112 assertions passed against the former 280-pixel column and 530-pixel panel height. Those older dimensions are superseded by the table above.

Reproduce the Lua checks in PowerShell from the repository root:

```powershell
& './Skins/Parallax/@Resources/Modules/Chronometer/Tests/Run-Tests.ps1'
# Native checks for 180/200px, both Columns, five scales, normal and edge fixtures:
& './Skins/Parallax/@Resources/Modules/Chronometer/Tests/Smoke/Run-Smoke.ps1'
& './Skins/Parallax/@Resources/Modules/Chronometer/Tests/Smoke/Run-Smoke.ps1' -Fixtures Edge
```

The test harness uses the already installed Rainmeter runtime with a separate settings INI, separate existing SkinPath, and isolated runtime state. It quits from its own test skin, never sends CLI bangs to Rainmeter, and removes only its checked generated run directory. The existing user Rainmeter process/configuration was not changed. No dependencies were installed. See the test README for the reusable isolation pattern.

The native smoke used zero-opacity test windows, inspected Rainmeter objects, and measured native text extents with transparent test-only probes. It did not capture rendered pixels. The integration task owns the all-suite appearance capture/review. Manual mouse hit targets, actual process restart/global refresh and full computer suspend/restart trials, mixed Windows DPI, and measured CPU/disk-I/O budgets remain release checks. Restoration and retry semantics are verified in the separate controlled Lua tests; they were not exercised as desktop restart scenarios. The native window sizes and mathematical snap pitch match the shared contract; actual desktop alignment is not yet certified. This restyle made no live desktop installation or configuration changes.

## Next steps

1. Native visibility and supported typography checks are complete. Verify the actual displayed skin at scales 75%, 100%, 125%, 150%, and 200%, both Columns values and mixed Windows DPI. Check font enlargement, thicker dividers, long Unicode labels, clipping, tooltips, and edge snapping; measure steady-state CPU and I/O with all timers running. The integration task owns suite-wide pixel captures.
2. Consider multiple dated events or recurrence only with an explicit extension to the event schema and time-zone policy. Any snooze control needs separate semantics from duration timers.
3. Consider editable list counts/row paging, per-timer stable IDs, and an explicit migration from positional v1 snapshots. Add instance-scoped state paths before supporting multiple loaded Chronometer copies.
4. Consider optional completion notifications with persisted delivery state and documented offline behavior. Preserve the current silent default and avoid repeated alerts after refresh.
5. Consider a monotonic duration mode only with a reliable built-in time source and explicit suspend/restart reconciliation; do not imply wall-clock immunity for the current engine.

## Primary references and attribution

All module code is original Parallax work. No ModernGadgets code, imagery, fonts, or other assets were copied. Rainmeter documentation and source were consulted for API behavior; the official documentation site returned 403 during this task, so the official repository copies were used.

- [Script measure](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/script.html): script path and command handling.
- [Rainmeter Lua scripting](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html): Lua 5.1, Initialize/Update lifecycle, object methods, and separate-argument Bang calls. No Finalize hook is assumed.
- [Time measure](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/time.html): local clock/date formatting.
- [Built-in variables](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/variables/built-in-variables.html): settings/resource/editor paths.
- [String meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/string/index.html): fixed dimensions, alignment, and clipping.
- [Shape meter](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html): original clock icon and hairline row separators; all geometry is newly authored.
- [Installed-version Rainmeter startup source](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/Rainmeter.cpp): explicit INI-path isolation and per-path instance mutex, used for the local test runner.
- [Installed-version configuration parser](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/ConfigParser.cpp): section-variable expansion, motivating label sanitization before rendering.
- [Installed-version root/resource-path resolution](https://github.com/rainmeter/rainmeter/blob/v4.5.26.3894/Library/Skin.cpp#L5413-L5445): explains why the suite must sit directly inside SkinPath and why a one-level-too-high installation breaks shared includes.
