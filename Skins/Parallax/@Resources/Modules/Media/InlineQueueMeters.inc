; Queue object contents: a header, a divider, then one row per track.
; Each row leads with the track's cover (2026-11-19; the old # column and its
; | dividers are gone) and then its text. QueueRowSize picks the row's shape
; (InlineQueueGeometry.inc): Normal puts the song above the artist; Compact
; keeps the old single "Song / Artist" line.
;
; Compact's artist half is accented via InlineSetting/InlinePattern.
; QueueReader.lua owns both the text and the pattern: it concatenates the row,
; so it emits a pattern matching the literal artist anchored at the end of the
; string. The separator is therefore never coloured, and a "/" in a song or
; artist name cannot shift the boundary - nothing infers structure from the
; text. Normal rows put the artist in its own meter instead. With album colors
; on, AlbumColors.lua replaces the accent with the cover's.
;
; Every meter sits in the QueueRows group so the drawer shows and hides them
; together; QueueReader.lua hides rows past the queue's length and positions
; them from #MediaQueueRowsY# / #MediaQueueRowPitch#. None takes part in
; periodic updates (UpdateDivider=-1): QueueReader.lua forces
; [!UpdateMeterGroup QueueRows][!Redraw] whenever it changes a row, and the
; header text is fixed.
;
; Per row, back to front: the hit surface (click, hover highlight), the cover
; tile, the rounded mask that contains the cover image, the cover, the song
; line and the artist line. Text and images carry no mouse actions, so the
; hit surface beneath them takes every click and hover over the row.

; Click and hover surface. The hand cursor and the hover lift show only on rows
; QueueReader.lua marks clickable; both start off.
[MediaInlineQueueHitStyle]
X=#MediaQueueHitX#
W=#MediaQueueHitWidth#
H=#MediaQueueRowPitch#
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,#MediaQueueHitWidth#,#MediaQueueRowPitch#,#MediaQueueHitRadius# | Extend MediaQueueHitPaint
MediaQueueHitPaint=Fill Color #MediaQueueRestFill# | StrokeWidth 0
MouseActionCursor=0

; Neutral tile under every cover: what a row shows when its cover is missing.
[MediaInlineQueueTileStyle]
X=#MediaQueueX#
W=#MediaQueueThumbSize#
H=#MediaQueueThumbSize#
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,#MediaQueueThumbSize#,#MediaQueueThumbSize#,#MediaQueueThumbRadius# | Fill Color #MediaQueueThumbFill# | StrokeWidth 0

; Rounded alpha mask the cover is drawn through (Container), like the big
; cover's MeterCoverMask.
[MediaInlineQueueMaskStyle]
X=#MediaQueueX#
W=#MediaQueueThumbSize#
H=#MediaQueueThumbSize#
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,#MediaQueueThumbSize#,#MediaQueueThumbSize#,#MediaQueueThumbRadius# | Fill Color 255,255,255,255 | StrokeWidth 0

; The cover itself, cropped to fill its square. QueueReader.lua sets ImageName
; to a validated file in the helper's covers folder, or hides it.
[MediaInlineQueueArtStyle]
X=0
Y=0
W=#MediaQueueThumbSize#
H=#MediaQueueThumbSize#
PreserveAspectRatio=2
Group=QueueRows
Hidden=1
UpdateDivider=-1

; Song line (Compact: the whole "Song / Artist" line).
[MediaInlineQueueRowStyle]
X=#MediaQueueTextX#
W=#MediaQueueTextWidth#
H=#MediaQueueTitleHeight#
ClipString=1
InlineSetting=Color | #MediaQueueArtistColor#
InlinePattern=$^
Group=QueueRows
Hidden=1
UpdateDivider=-1

; Artist line under the song (Normal rows only).
[MediaInlineQueueArtistStyle]
X=#MediaQueueTextX#
W=#MediaQueueTextWidth#
H=#MediaQueueArtistHeight#
ClipString=1
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MediaQueueArtistColor#
Group=QueueRows
Hidden=1
UpdateDivider=-1

; The heading starts at the queue's own left edge, flush with the rule and the
; covers (2026-11-24). Over the song text it read as out of line with the list
; once the # column beside it was gone.
[MeterQueueHeaderTrack]
Meter=String
MeterStyle=StyleHeader
X=#MediaQueueX#
W=(#MediaQueueWidth#-#MediaQueueRefreshWidth#)
H=(18*#Scale#)
Y=#MediaQueueHeaderY#
Group=QueueRows
Hidden=1
; Mirrors the rows: the artist half accented, the separator left neutral. The
; text is fixed here, so the pattern can be a literal rather than Lua-supplied.
InlineSetting=Color | #MediaQueueArtistColor#
InlinePattern=Artist$
Text=Song / Artist
UpdateDivider=-1

; Media.ini's Refresh icon sits at this row's right end; it lives in
; Queue\QueueControlHost.inc beside the measure it calls, so Setup has none.

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

[MeterQueueHit1]
Meter=Shape
MeterStyle=MediaInlineQueueHitStyle
Y=#Inset#
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(1)"]
MouseOverAction=[!CommandMeasure MeasureQueueStatus "HoverRow(1,1)"]
MouseLeaveAction=[!CommandMeasure MeasureQueueStatus "HoverRow(1,0)"]

[MeterQueueTile1]
Meter=Shape
MeterStyle=MediaInlineQueueTileStyle
Y=#Inset#

[MeterQueueArtMask1]
Meter=Shape
MeterStyle=MediaInlineQueueMaskStyle
Y=#Inset#

[MeterQueueArt1]
Meter=Image
MeterStyle=MediaInlineQueueArtStyle
Container=MeterQueueArtMask1

[MeterQueueRow1]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueArtist1]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueArtistStyle
Y=#Inset#
Text=

[MeterQueueHit2]
Meter=Shape
MeterStyle=MediaInlineQueueHitStyle
Y=#Inset#
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(2)"]
MouseOverAction=[!CommandMeasure MeasureQueueStatus "HoverRow(2,1)"]
MouseLeaveAction=[!CommandMeasure MeasureQueueStatus "HoverRow(2,0)"]

[MeterQueueTile2]
Meter=Shape
MeterStyle=MediaInlineQueueTileStyle
Y=#Inset#

[MeterQueueArtMask2]
Meter=Shape
MeterStyle=MediaInlineQueueMaskStyle
Y=#Inset#

[MeterQueueArt2]
Meter=Image
MeterStyle=MediaInlineQueueArtStyle
Container=MeterQueueArtMask2

[MeterQueueRow2]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueArtist2]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueArtistStyle
Y=#Inset#
Text=

[MeterQueueHit3]
Meter=Shape
MeterStyle=MediaInlineQueueHitStyle
Y=#Inset#
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(3)"]
MouseOverAction=[!CommandMeasure MeasureQueueStatus "HoverRow(3,1)"]
MouseLeaveAction=[!CommandMeasure MeasureQueueStatus "HoverRow(3,0)"]

[MeterQueueTile3]
Meter=Shape
MeterStyle=MediaInlineQueueTileStyle
Y=#Inset#

[MeterQueueArtMask3]
Meter=Shape
MeterStyle=MediaInlineQueueMaskStyle
Y=#Inset#

[MeterQueueArt3]
Meter=Image
MeterStyle=MediaInlineQueueArtStyle
Container=MeterQueueArtMask3

[MeterQueueRow3]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueArtist3]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueArtistStyle
Y=#Inset#
Text=

[MeterQueueHit4]
Meter=Shape
MeterStyle=MediaInlineQueueHitStyle
Y=#Inset#
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(4)"]
MouseOverAction=[!CommandMeasure MeasureQueueStatus "HoverRow(4,1)"]
MouseLeaveAction=[!CommandMeasure MeasureQueueStatus "HoverRow(4,0)"]

[MeterQueueTile4]
Meter=Shape
MeterStyle=MediaInlineQueueTileStyle
Y=#Inset#

[MeterQueueArtMask4]
Meter=Shape
MeterStyle=MediaInlineQueueMaskStyle
Y=#Inset#

[MeterQueueArt4]
Meter=Image
MeterStyle=MediaInlineQueueArtStyle
Container=MeterQueueArtMask4

[MeterQueueRow4]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueArtist4]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueArtistStyle
Y=#Inset#
Text=

[MeterQueueHit5]
Meter=Shape
MeterStyle=MediaInlineQueueHitStyle
Y=#Inset#
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(5)"]
MouseOverAction=[!CommandMeasure MeasureQueueStatus "HoverRow(5,1)"]
MouseLeaveAction=[!CommandMeasure MeasureQueueStatus "HoverRow(5,0)"]

[MeterQueueTile5]
Meter=Shape
MeterStyle=MediaInlineQueueTileStyle
Y=#Inset#

[MeterQueueArtMask5]
Meter=Shape
MeterStyle=MediaInlineQueueMaskStyle
Y=#Inset#

[MeterQueueArt5]
Meter=Image
MeterStyle=MediaInlineQueueArtStyle
Container=MeterQueueArtMask5

[MeterQueueRow5]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueRowStyle
Y=#Inset#
Text=

[MeterQueueArtist5]
Meter=String
MeterStyle=StyleLabel|MediaInlineQueueArtistStyle
Y=#Inset#
Text=
