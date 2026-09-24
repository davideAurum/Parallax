# Tooltip audit and trim — 2026-09-19

A suite-wide sweep of every `ToolTipText` declaration, an A/B benchmark of what
tooltips actually cost at runtime, and a redundancy trim. This follows the
2026-09-13 tooltip work recorded in [PERFORMANCE.md](PERFORMANCE.md); that pass
fixed three specific fan-out sites, this one sweeps the whole suite.

Measured with `tools/Benchmark-Tooltips.ps1` against Rainmeter 4.5.26.3894 on
Windows 11. Every run cold-starts an **isolated** Rainmeter instance from a
generated stage with off-screen windows. The live profile is never read, written,
refreshed or sent a bang.

## What a tooltip costs

Rainmeter creates one native `tooltips_class32` control per tooltip-bearing
meter, eagerly when the meter is built — not lazily on hover. Measured by
enumerating windows of that class in the benchmark process:

| | tooltip windows | USER objects | GDI objects |
| --- | ---: | ---: | ---: |
| Main skins, as built | 359 | 414 | 2,193 |
| Main skins, every `ToolTipText` line stripped | 125 | 180 | 789 |
| Difference | **-234** | **-234** | **-1,404** |

USER objects fall by exactly the number of tooltip windows removed, so the cost
is **1 USER handle and ~6 GDI objects per tooltip**, paid whether or not anyone
hovers. The 125 that survive a full static strip are assigned at runtime from
Lua (CPU per-thread labels, sensor cells, process rows) and cannot be removed by
editing `.inc`/`.ini` files.

Two multipliers make the source-line count misleading:

- A `ToolTipText` in a **style** section is inherited by every meter using that
  style. `CPUStyleRowTemperature` was one line that became 64 tooltip controls.
- Lua assigns tooltips per slot, so a single `set(...)` call inside a loop
  produces one control per visible row.

136 static lines in the main skins therefore produced 359 controls.

## Sweep

658 `ToolTipText` declarations across 37 files and 10 utilities before the trim.

| Scope | Declarations | Notes |
| --- | ---: | --- |
| Settings panels | 522 | Control help text; loaded only while a panel is open |
| Main utility skins | 136 | Always loaded; the everyday hover surface |

Of the 658, 480 were static literals, 173 sat in sections already marked
`DynamicVariables=1`, and only 2 contained measure references that are re-parsed
each tick — so per-tick string work was never the main cost. Window and handle
pressure was. 101 distinct strings were used more than once, accounting for 307
redundant copies; total tooltip text was 65,699 characters.

## Trim applied

86 declarations removed (658 → 572), plus one rewrite. No informative text was
lost — every removal was either a duplicate of an adjacent meter's tooltip, a
restatement of the visible label, or content already carried by a column header.

| Where | Removed | Why |
| --- | ---: | --- |
| `IO/SettingsMeters.inc` | 52 | One sentence repeated on all 52 A–Z drive cells; folded into the drive-selector heading |
| `Settings/Settings.ini` | 12 | Stepper frame hit-rects sitting behind the value meter, which carries the specific text and the same click action |
| `Welcome/Rows.inc` | 9 | Identical tooltip on both halves of each row; the name half keeps it |
| `RAM/Meters.inc` | 4 | Same paragraph on the GB and MB variants of a row whose label already carries it |
| `Media/Header.inc`, `PlayerMeters.inc`, `Common.inc` | 6 | Icons naming themselves — `Media player`, `Current player`, `Artist`, `Album`, a tooltip equal to its own label, and a duplicated queue-toggle tooltip |
| `IO/View.inc` | 2 | Graph track duplicating the graph tooltip; a `0` axis marker whose tooltip restated it |
| `CPU/CPU.ini` | 1 | `CPUStyleRowTemperature` — inherited by 64 cells; the temperature column header already states it, and `Sensors.lua` supplies per-cell detail |

## Result

Main utility skins, five cold starts each, median:

| Metric | Before | After | Change |
| --- | ---: | ---: | ---: |
| Tooltip windows | 359 | 277 | **-82 (-23%)** |
| USER objects | 414 | 332 | **-82 (-20%)** |
| GDI objects | 2,193 | 1,701 | **-492 (-22%)** |
| Load to fully built | 12,910 ms | 9,485 ms | **-3,425 ms (-27%)** |
| Working set | 116.1 MB | 117.5 MB | no clear change |
| Idle CPU over 8 s | 2,672 ms | 3,297 ms | no clear change |

Tooltip-window, USER and GDI counts were byte-identical across every trial, so
those reductions are exact. Load time is noisy — individual trials ranged 8.8 s
to 34.2 s — and includes constant process, plugin and provider startup, so treat
-27% as directional rather than precise.

Working set and idle CPU did **not** improve measurably. Tooltip cost is handle
and window pressure, not memory or per-tick CPU, and this change should not be
described as reducing either.

The 52 IO drive-cell removals are a source-clarity win whose runtime benefit
scales with drive count: `[IOStyleSettingsDrive]` sets `Hidden=1`, and hidden
meters get no tooltip control, so on a machine with few drives most of those 52
lines were never materialising windows.

## Regression guard

`tools/Test-Parallax.ps1` already rejected a tooltip on `CPUStyleRowSensor`.
`CPUStyleRowTemperature` was an unguarded sibling with the same defect, so the
rule now covers every `CPUStyleRow*` style. Verified by re-adding a tooltip to
that style and confirming the validator fails.

## Limits

Static validation passes with 0 errors and 0 warnings. This audit covers
declarations reachable from the shipped configs; it does not establish hover
latency, long-run behaviour, mixed-DPI cost, or behaviour on hardware exposing
more sensors, drives or threads than this machine. Runtime tooltips assigned
from Lua were measured in aggregate, not attributed per call site.
