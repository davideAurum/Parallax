; Queue object contents: a header, a divider, then a numbered row per track.
; Two columns: the position digit, and one flowing "Song / Artist" string.
;
; The artist half is accented via InlineSetting/InlinePattern. QueueReader.lua
; owns both the text and the pattern: it concatenates the row, so it emits a
; pattern matching the literal artist anchored at the end of the string. The
; separator is therefore never coloured, and a "/" in a song or artist name
; cannot shift the boundary - nothing infers structure from the text.
;
; Every meter sits in the QueueRows group so the drawer shows and hides them
; together; QueueReader.lua hides rows past the queue's length and positions
; them from #MediaQueueRowsY# / #MediaQueueRowPitch#.

; Position column. Right aligned so the digit sits against the title, and so a
; two-digit position would still line up if QueueRowLimit ever grows.
[MediaInlineQueueNumberStyle]
X=#MediaQueueNumberRight#
W=#MediaQueueNumberWidth#
H=(18*#Scale#)
StringAlign=Right
Group=QueueRows
Hidden=1

; TRIAL: the artist is accented. InlinePattern is rewritten per row by Lua.
[MediaInlineQueueRowStyle]
X=#MediaQueueTextX#
W=#MediaQueueTextWidth#
H=(18*#Scale#)
ClipString=1
InlineSetting=Color | #MediaQueueArtistColor#
InlinePattern=$^
Group=QueueRows
Hidden=1

; One segment per row, inset top and bottom so the column reads as a dashed
; delimiter rather than a single line. QueueReader.lua places and hides these
; with their row, so they never outlast the tracks they separate.
[MediaInlineQueueDividerStyle]
X=#MediaQueueDividerX#
Group=QueueRows
Hidden=1
Shape=Line 0,#MediaQueueDividerInset#,0,(#MediaQueueRowPitch#-#MediaQueueDividerInset#) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
UpdateDivider=-1

[MeterQueueHeaderNumber]
Meter=String
MeterStyle=StyleHeader|MediaInlineQueueNumberStyle
Y=#MediaQueueHeaderY#
Text=#

[MeterQueueHeaderTrack]
Meter=String
MeterStyle=StyleHeader
X=#MediaQueueTextX#
W=#MediaQueueTextWidth#
H=(18*#Scale#)
Y=#MediaQueueHeaderY#
Group=QueueRows
Hidden=1
; Mirrors the rows: the artist half accented, the separator left neutral. The
; text is fixed here, so the pattern can be a literal rather than Lua-supplied.
InlineSetting=Color | #MediaQueueArtistColor#
InlinePattern=Artist$
Text=Song / Artist

[MeterQueueHeaderDivider]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#MediaQueueHeaderY#

; Lightweight divider between the header and the rows, matching the suite's
; #DividerColor#/#DividerThickness# rule styling and spanning the content width.
[MeterQueueHeaderRule]
Meter=Shape
X=#MediaQueueX#
Y=#MediaQueueDividerY#
Group=QueueRows
Hidden=1
Shape=Line 0,0,#MediaQueueWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
UpdateDivider=-1

[MeterQueueNumber1]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueNumberStyle
Y=#Inset#
Text=1

[MeterQueueRow1]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueNumber2]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueNumberStyle
Y=#Inset#
Text=2

[MeterQueueRow2]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueNumber3]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueNumberStyle
Y=#Inset#
Text=3

[MeterQueueRow3]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueNumber4]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueNumberStyle
Y=#Inset#
Text=4

[MeterQueueRow4]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueNumber5]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueNumberStyle
Y=#Inset#
Text=5

[MeterQueueRow5]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueDivider1]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#Inset#

[MeterQueueDivider2]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#Inset#

[MeterQueueDivider3]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#Inset#

[MeterQueueDivider4]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#Inset#

[MeterQueueDivider5]
Meter=Shape
MeterStyle=MediaInlineQueueDividerStyle
Y=#Inset#
