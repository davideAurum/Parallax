; VisualizerDrawer=2: the open spectrum drawer. Media.ini includes this file
; only in that state, so the AudioLevel capture exists only while the drawer is
; open; collapsing it refreshes Media and AudioLevel releases the capture.
; Media hosts the Visualizer's shared Capture.inc and Spectrum.inc; the plot
; box comes from the spectrum block in InlineQueueGeometry.inc.
[Variables]
; Only this file opens the drawer geometry (InlineQueueGeometry.inc): a saved
; value that does not name this file can never lift an empty sheet.
MediaVisualizerOpen=1
; Media updates every #MediaAnimationInterval# (50 ms). The Visualizer cadence
; maps onto that tick: 50 and 33 ms both run every tick (33 ms cannot be met
; inside Media), 100 ms every other tick.
VisualizerCaptureDivider=(Max(1,Round(#VisualizerEffectiveInterval#/#MediaAnimationInterval#)))
VisualizerPlotInnerWidth=(#MediaVisualizerPlotWidth#-2)
VisualizerPlotInnerHeight=(#MediaVisualizerPlotHeight#-2)
VisualizerSpectrumX=(#MediaVisualizerPlotX#+1)
VisualizerSpectrumY=(#MediaVisualizerPlotY#+1)
; Output-row cadence on Media's tick: Win7Audio volume and the device name
; and status once a second each, as in the standalone. Every Win7Audio read
; is a full COM device enumeration (docs/PERFORMANCE-REVIEW.md VIS-04).
VisualizerVolumeDivider=(Max(1,Round(1000/#MediaAnimationInterval#)))
VisualizerDeviceNameDivider=(Max(1,Round(1000/#MediaAnimationInterval#)))
VisualizerVolumeAvailable=0

[MediaVisualizerCaptureInclude]
@Include18=#@#Modules\Visualizer\Capture.inc

; The standalone's output-row measures: dB ticks, Win7Audio volume and device
; switching, device name and discovery. Win7Audio exists only while open too.
[MediaVisualizerAudioInclude]
@Include21=#@#Modules\Visualizer\Audio.inc

; Selects the solid or gradient fill once per load. UpdateDivider=-1 updates it
; once, after every meter exists; Apply(false) leaves drawing to Media's update.
[MeasureVisualizerColorApply]
Measure=Calc
Formula=1
UpdateDivider=-1
OnUpdateAction=[!CommandMeasure MeasureVisualizerColor "Apply(false)"]

; Frame and grid of the drawer's plot. Its axes and output row match the
; standalone Visualizer's (View.inc).
[MeterVisualizerPlot]
Meter=Shape
X=#MediaVisualizerPlotX#
Y=#MediaVisualizerPlotY#
W=#MediaVisualizerPlotWidth#
H=#MediaVisualizerPlotHeight#
Shape=Rectangle 0.5,0.5,(#MediaVisualizerPlotWidth#-1),(#MediaVisualizerPlotHeight#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
; Grid lines sit on pixel centres (Floor(...)+1.5), within half a pixel of the
; exact quarters, so each 1px line renders as one crisp row.
Shape2=Line 1,(Floor(#VisualizerBarHeight#/4)+1.5),(#MediaVisualizerPlotWidth#-1),(Floor(#VisualizerBarHeight#/4)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(Floor(#VisualizerBarHeight#/2)+1.5),(#MediaVisualizerPlotWidth#-1),(Floor(#VisualizerBarHeight#/2)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(Floor(3*#VisualizerBarHeight#/4)+1.5),(#MediaVisualizerPlotWidth#-1),(Floor(3*#VisualizerBarHeight#/4)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1

; The single non-live overlay. MeasureVisualizerState (Capture.inc) sets its
; text and color and forces its update: Output unavailable, Idle - quiet or
; Unsupported format; it hides while there is signal.
[MeterVisualizerUnavailable]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerPlotX#+#MediaVisualizerPlotWidth#/2)
Y=(#MediaVisualizerPlotY#+#MediaVisualizerPlotHeight#/2)
W=(#MediaVisualizerPlotWidth#-8*#Scale#)
StringAlign=CenterCenter
Text=Output unavailable
FontColor=#WarningColor#
SolidColor=#GraphBackgroundColor#
UpdateDivider=-1

; Output row, as the standalone draws it (View.inc): the user-selected Lucide
; Speaker (Icons\Lucide\README.md) and the clipped device name on the left,
; the read-only Windows output volume on the right. One transparent target
; switches the Windows default output, like the standalone's row.
[MeterVisualizerOutputIcon]
Meter=Shape
X=#MediaVisualizerRowX#
Y=(#MediaVisualizerRowY#+2*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
AntiAlias=1
Shape=Rectangle (4*14*#Scale#/24),(2*14*#Scale#/24),(16*14*#Scale#/24),(20*14*#Scale#/24),(2*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape2=Line (12*14*#Scale#/24),(6*14*#Scale#/24),(12.01*14*#Scale#/24),(6*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape3=Ellipse (12*14*#Scale#/24),(14*14*#Scale#/24),(4*14*#Scale#/24),(4*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape4=Line (12*14*#Scale#/24),(14*14*#Scale#/24),(12.01*14*#Scale#/24),(14*14*#Scale#/24) | Extend LucideSpeakerStroke
LucideSpeakerStroke=Fill Color 0,0,0,0 | Stroke Color #MediaColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UpdateDivider=-1

; Both output-row texts are event-driven (UpdateDivider=-1): Audio.inc's
; measures update them and repaint when what they show changes, so they keep
; no periodic repaint alive in a quiet drawer.
[MeterVisualizerDeviceName]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDeviceName
X=(#MediaVisualizerRowX#+18*#Scale#)
Y=#MediaVisualizerRowY#
W=(#MediaVisualizerRowWidth#-18*#Scale#-64*#Scale#)
H=(18*#Scale#)
Text=%1
UpdateDivider=-1

; Audio.inc's MeasureVisualizerVolumeValue sets this text: a whole percent,
; Muted, or -- when Win7Audio reports no device.
[MeterVisualizerVolume]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerVolumeValue
X=(#MediaVisualizerRowX#+#MediaVisualizerRowWidth#)
Y=#MediaVisualizerRowY#
W=(60*#Scale#)
StringAlign=Right
Text=--
NumOfDecimals=0
UpdateDivider=-1

; Switching clears a custom capture ID and refreshes, because AudioLevel parent
; options cannot change at runtime; the standalone Visualizer refreshes too so
; both captures follow the new default.
[MeterVisualizerDeviceHit]
Meter=Image
X=#MediaVisualizerRowX#
Y=#MediaVisualizerRowY#
W=#MediaVisualizerRowWidth#
H=(18*#Scale#)
SolidColor=0,0,0,1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerVolume "ToggleNext"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh "Parallax\Visualizer"][!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()"]
MouseScrollDownAction=[!CommandMeasure MeasureVisualizerVolume "ToggleNext"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh "Parallax\Visualizer"][!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()"]
MouseScrollUpAction=[!CommandMeasure MeasureVisualizerVolume "TogglePrevious"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh "Parallax\Visualizer"][!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()"]
DynamicVariables=1
UpdateDivider=-1

; Axis labels, as the standalone Visualizer draws them: a relative dB scale in
; the gutter left of the plot (0 at full height, the midpoint at minus half the
; sensitivity, the bottom at minus the sensitivity - AudioLevel's normalized
; band scale inverted; Audio.inc's MeasureVisualizerDbMid/Min) and the
; capture's 40 Hz / 16 kHz range under it.

[MeterVisualizerDbMax]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerPlotX#-4*#Scale#)
Y=(#MediaVisualizerPlotY#+1)
W=(36*#Scale#)
StringAlign=Right
FontColor=#MutedColor#
Text=0 dB
UpdateDivider=-1

[MeterVisualizerDbMid]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDbMid
X=(#MediaVisualizerPlotX#-4*#Scale#)
Y=(#MediaVisualizerPlotY#+1+#VisualizerBarHeight#/2)
W=(36*#Scale#)
StringAlign=RightCenter
FontColor=#MutedColor#
Text=%1
NumOfDecimals=1
UpdateDivider=-1

[MeterVisualizerDbMin]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDbMin
X=(#MediaVisualizerPlotX#-4*#Scale#)
Y=(#MediaVisualizerPlotY#+1+#VisualizerBarHeight#)
W=(36*#Scale#)
StringAlign=RightBottom
FontColor=#MutedColor#
Text=%1
NumOfDecimals=1
UpdateDivider=-1

[MeterVisualizerLow]
Meter=String
MeterStyle=StyleLabel
X=#MediaVisualizerPlotX#
Y=(#MediaVisualizerPlotY#+#MediaVisualizerPlotHeight#+1*#Scale#)
W=(50*#Scale#)
FontColor=#MutedColor#
Text=40 Hz
UpdateDivider=-1

[MeterVisualizerHigh]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerPlotX#+#MediaVisualizerPlotWidth#)
Y=(#MediaVisualizerPlotY#+#MediaVisualizerPlotHeight#+1*#Scale#)
W=(50*#Scale#)
StringAlign=Right
FontColor=#MutedColor#
Text=16 kHz
UpdateDivider=-1

; Last section of this file, so Rainmeter appends Spectrum.inc's sections here
; and the measured bars paint over the plot frame.
[MediaVisualizerSpectrumInclude]
@Include19=#@#Modules\Visualizer\Spectrum.inc
