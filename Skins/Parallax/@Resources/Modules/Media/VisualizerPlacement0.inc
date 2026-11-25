; VisualizerPlacement=0 (the default): the spectrum is the third tab of the
; bottom drawer. Included by VisualizerDrawer2.inc, so only while it shows.
[Variables]
; The volume ends the drawer's own output row, so neither hover nor Idle pause
; swaps it with the gear.
MediaVisualizerVolumeGroup=MediaDrawerValue

; The strip QueueReader.lua's header shows, drawn here with Spectrum current.
; The compact layout shows its one label, which goes back to the queue.
[MeterSpectrumTabQueue]
Meter=String
MeterStyle=StyleHeader
X=#MediaQueueX#
Y=#MediaQueueHeaderY#
W=(39*#MediaQueueTabUnit#)
Text=Queue
Hidden=(#Columns#=1)
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ShowQueue('queue')"]

[MeterSpectrumTabBar1]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+39*#MediaQueueTabUnit#)
Y=#MediaQueueHeaderY#
W=(8*#MediaQueueTabUnit#)
Text=|
Hidden=(#Columns#=1)
UpdateDivider=-1

[MeterSpectrumTabPlaylists]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+48*#MediaQueueTabUnit#)
Y=#MediaQueueHeaderY#
W=(55*#MediaQueueTabUnit#)
Text=Playlists
Hidden=(#Columns#=1)
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ShowQueue('playlists')"]

[MeterSpectrumTabBar2]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+103*#MediaQueueTabUnit#)
Y=#MediaQueueHeaderY#
W=(8*#MediaQueueTabUnit#)
Text=|
Hidden=(#Columns#=1)
UpdateDivider=-1

[MeterSpectrumTabSpectrum]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+(#Columns#=1 ? 0 : 112*#MediaQueueTabUnit#))
Y=#MediaQueueHeaderY#
W=(60*#MediaQueueTabUnit#)
Text=Spectrum
FontColor=#TextColor#
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "CompactSpectrumClick()"]

[MeterSpectrumTabRule]
Meter=Shape
X=#MediaQueueX#
Y=#MediaQueueDividerY#
Shape=Line 0,0,#MediaQueueWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
UpdateDivider=-1
