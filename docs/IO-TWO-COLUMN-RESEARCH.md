# Disk Meter two-column layouts (research, not pursued)

Status, 2026-10-26: exploratory only. The user reviewed these three layouts and does not plan to pursue a dedicated two-column Disk Meter. Nothing here is implemented; this note records the current behavior and the measured options in case the question comes back.

## Current behavior

`Columns=2` in `User/IO.inc` is accepted and covered by `tests/check_geometry.py`, but it only widens the window to the shared double width (456 px at width 220 / scale 1; content x10–446, 436 px). The single-column stack is unchanged: each drive's full-width name, bar and read/write/capacity row, then the 62 px graph, all stretched across 436 px. Disk Meter settings expose no Columns control (Chronometer, GPU, Media and Network do); it is reachable only by editing the file.

With C, D, G selected the stretched double layout is 456×265, the same height as single column.

## Candidates

All figures are logical px at width 220, scale 1 and the default 6 px data bar, derived from the formulas in `IO.lua` `layout()` (drive pitch 50, names y42, bar y60, rates y68, graph 62 tall, 6 px bottom padding). Window height is panel height + 8 (gap). The right half of the double panel uses the shared column grid: content x238–446, giving two 208 px halves that match single-column `ContentWidth` exactly.

| | A · Drive grid | B · Drives left, tall history right | C · Wide table rows |
|---|---|---|---|
| Drives | Two 208 px cells per row; drive `i` at column `i%2`, row `floor(i/2)`, 50 px pitch | The existing single-column stack in x10–218 | One full-width row per drive: name / read / write / free-total on one line, bar beneath, 32 px pitch |
| Graph | Full width 436×62 below the grid | Right column x238–446, from y42 to the stack bottom, minimum 62 tall, `History` header with the scale at y24 | Full width 436×62 below the table |
| Panel height | `157+50·(ceil(n/2)−1)` | `max(110, 92+50·(n−1))` | `142+32·(n−1)` |
| n = 1 / 2 / 3 / 4 | 157 / 157 / 207 / 207 | 110 / 142 / 192 / 242 | 142 / 174 / 206 / 238 |
| Window at n = 3 | 456×215 | 456×200 | 456×214 |
| Change size | Small: a column/row index in `layout()` | Small: drives unchanged, graph moves and resizes | Largest: column header, new row geometry |

Notes per candidate:

- **A.** Cell text math is identical to single column (208 px cells, 56/56/88 px rate/rate/capacity at the 4 px cell gaps). An odd count leaves an empty 208×50 cell, which includes the user's default C, D, G selection.
- **B.** Keeps the 60-sample history at today's 208 px (about 3.5 px per sample). Graph height, and therefore vertical resolution and quarter gridline spacing, changes with drive count. Overlay legend rows (eight letters per row in 208 px) would add 18 px each under the graph.
- **C.** Closest to the approved CPU/Memory table pattern (one header row with a table-header rule, label/value columns, bar directly below). Proposed columns in 436 px: name 160, read 72, write 72, capacity 108 with three 8 px gaps. The name column fits roughly 29 characters at 9 pt; that is an estimate, not a glyph measurement. Header row y24, rule y41, rows at y42+32i, bars at y62+32i, graph at y74+32(n−1).

Open questions any of them would have raised:

- A full-width graph (A, C) either stretches the 60 samples to about 7.3 px each or doubles `historySlots` to 120 (about 3.6 px each, two minutes of history).
- Disk Meter settings would need a Columns 1–2 control matching the other utilities.
- Narrow width 180 / scale 0.75 (content 266 px double) was not worked out; C's column split would need proportional widths.

The candidate mockups were drawn at 1:1 logical px for three drives with placeholder readings; no capture of a running skin was made.
