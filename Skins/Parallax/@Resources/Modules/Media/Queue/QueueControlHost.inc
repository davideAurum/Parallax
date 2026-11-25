; Row clicks, Refresh and the Playlists view in Media.ini's queue drawer:
; QueueReader.lua hands a click to the running helper, which does the Spotify
; work, by a small request file. Only when that cannot be written does
; QueueControl.lua run one short hidden QueueProvider.ps1 request (Play or
; Refresh) on this host, the same pair as the standalone Queue.ini, inert until
; then. Media.ini only: Setup holds nothing that can launch beyond the
; two resume hosts, so its rows are never clickable and it has no Refresh.
; Included after InlineQueueGeometry.inc, so this width wins there.
[Variables]
MediaQueueRefreshWidth=(18*#Scale#)
MediaRefreshGlyph=(14*#Scale#/24)
; The view switch is placed by the header's own text size (8 pt is the default).
MediaQueueTabUnit=(#Scale#*#HeaderFontSize#/8)
; The "queue is off" line: the first row's place, below the transport circles
; that overhang the header band; parked inside the panel while the drawer is
; closed, as InlineQueueGeometry.inc parks the header.
MediaQueueOffY=(#MediaQueueExpanded#*#MediaQueueRowsY#+(1-#MediaQueueExpanded#)*#Inset#)
; The header's tabs take 114 units, 176 with the Spectrum tab.
MediaQueueTabsWidth=((114+62*#MediaSpectrumTab#)*#MediaQueueTabUnit#)

[MeasureQueueControl]
Measure=Script
ScriptFile=#@#Modules\Media\Queue\QueueControl.lua
UpdateDivider=-1

[MeasureQueueProviderControl]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\Media\Queue\
Parameter=-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "Refresh" -Quiet
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=-1
DynamicVariables=1

; The drawer's two views (2026-11-24). QueueReader.lua owns their text, colors
; and visibility: the shared header meter says Queue, these add the bar and
; Playlists, and a note of which playlists show at the right. The compact
; layout's header sits behind the transport buttons, so there only the header's
; own word shows and a click on it changes the view. Wheel over the rows pages
; the playlists (InlineQueueMeters.inc).
[MeterQueueTabQueue]
Meter=Shape
X=#MediaQueueX#
Y=#MediaQueueHeaderY#
W=(44*#MediaQueueTabUnit#)
H=(18*#Scale#)
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,(44*#MediaQueueTabUnit#),(18*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "ShowView('queue')"]

[MeterQueueTabBar]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+39*#MediaQueueTabUnit#)
Y=#MediaQueueHeaderY#
W=(8*#MediaQueueTabUnit#)
Group=QueueRows
Hidden=1
UpdateDivider=-1
Text=|

[MeterQueueTabPlaylists]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+48*#MediaQueueTabUnit#)
Y=#MediaQueueHeaderY#
W=(64*#MediaQueueTabUnit#)
Group=QueueRows
Hidden=1
UpdateDivider=-1
Text=Playlists
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "ShowView('playlists')"]

; The third tab, where VisualizerPlacement puts the spectrum in this drawer.
; QueueReader.lua shows it with the other two; the compact layout's one label
; reaches the spectrum by cycling instead. VisualizerPlacement0.inc draws the
; same strip while the spectrum is the view.
[MeterQueueTabSpectrumBar]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+(#Columns#=1 ? 0 : 103*#MediaQueueTabUnit#))
Y=#MediaQueueHeaderY#
W=(8*#MediaQueueTabUnit#)
Hidden=1
UpdateDivider=-1
Text=|

[MeterQueueTabSpectrum]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+(#Columns#=1 ? 0 : 112*#MediaQueueTabUnit#))
Y=#MediaQueueHeaderY#
W=(60*#MediaQueueTabUnit#)
Hidden=1
UpdateDivider=-1
Text=Spectrum
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ShowSpectrum()"]

[MeterQueueHeaderNote]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+#MediaQueueWidth#-#MediaQueueRefreshWidth#-6*#Scale#)
Y=#MediaQueueHeaderY#
W=(Max(1,#MediaQueueWidth#-#MediaQueueRefreshWidth#-6*#Scale#-#MediaQueueTabsWidth#))
StringAlign=Right
Group=QueueRows
Hidden=1
UpdateDivider=-1
; Only while it says Sign in again, which QueueReader.lua checks.
MouseActionCursor=0
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "OpenConnections()"]

; Asks the running helper to read the shown view now (QueueReader.lua). Right end of the drawer's header row (InlineQueueMeters.inc), in the accent
; the standalone panel's actions use: Lucide refresh-cw (Icons\Lucide, pinned
; revision) at the queue icon's 14/24 scale and 2-unit round stroke, centred in
; an 18S box (2026-11-19; it was the word Refresh). A click's outcome replaces
; the "Song / Artist" text beside it. SVG sweep=1 arcs map to Rainmeter's
; clockwise SweepDirection=0.
[MeterQueueRefresh]
Meter=Shape
X=(#MediaQueueX#+#MediaQueueWidth#-18*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
Y=#MediaQueueHeaderY#
AntiAlias=1
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,(18*#Scale#),(18*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Path MediaRefreshArcTop | Extend MediaRefreshStroke
Shape3=Path MediaRefreshHeadTop | Extend MediaRefreshStroke
Shape4=Path MediaRefreshArcBottom | Extend MediaRefreshStroke
Shape5=Path MediaRefreshHeadBottom | Extend MediaRefreshStroke
MediaRefreshStroke=Fill Color 0,0,0,0 | Stroke Color #AccentColor# | StrokeWidth (2*#MediaRefreshGlyph#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset (2*#Scale#),(2*#Scale#)
MediaRefreshArcTop=(3*#MediaRefreshGlyph#),(12*#MediaRefreshGlyph#) | ArcTo (12*#MediaRefreshGlyph#),(3*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),0,0,0 | ArcTo (18.74*#MediaRefreshGlyph#),(5.74*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),0,0,0 | LineTo (21*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#)
MediaRefreshHeadTop=(21*#MediaRefreshGlyph#),(3*#MediaRefreshGlyph#) | LineTo (21*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#) | LineTo (16*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#)
MediaRefreshArcBottom=(21*#MediaRefreshGlyph#),(12*#MediaRefreshGlyph#) | ArcTo (12*#MediaRefreshGlyph#),(21*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),0,0,0 | ArcTo (5.26*#MediaRefreshGlyph#),(18.26*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),0,0,0 | LineTo (3*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#)
MediaRefreshHeadBottom=(8*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#) | LineTo (3*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#) | LineTo (3*#MediaRefreshGlyph#),(21*#MediaRefreshGlyph#)
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "RefreshView()"]

; What an open drawer says while the optional queue helper was never started (no
; snapshot file), where it used to be blank. QueueReader.lua shows and hides it
; on that state alone; nothing here starts the helper. One row tall: in a narrow
; Normal drawer the text wraps, in a Compact one it ends in an ellipsis. Media.ini
; only, like the rest of this file: Setup has no drawer, and the standalone queue
; has its own status.
; The link takes the second accent and opens the panel that has the sign-in.
[MeterQueueOff]
Meter=String
MeterStyle=StyleLabel
X=#MediaQueueX#
W=#MediaQueueWidth#
H=#MediaQueueRowPitch#
Y=#MediaQueueOffY#
ClipString=2
Hidden=1
UpdateDivider=-1
InlineSetting=Color | #AccentColor2#
InlinePattern=Connections$
Text=Spotify queue is off: Connections
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Connections" "Connections.ini"]
