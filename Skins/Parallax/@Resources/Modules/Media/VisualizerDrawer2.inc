; VisualizerDrawer=2: the open spectrum drawer. Media.ini includes this file
; only in that state. It holds what every open drawer shows: the drawer
; geometry, the plot frame and grid, the static axis labels, the speaker icon
; and the status overlay. Its last section includes the capture variant that
; CaptureState.inc names (Modules\Media\DrawerCapture<MediaDrawerCapture>.inc):
;   0 live: the AudioLevel capture, output row and spectrum;
;   1 capture paused: no capture; "Capture paused", resumed by a click;
;   2 deferred: no capture while the standalone Audio Visualizer shows it.
; Only variant 0 creates an AudioLevel or Win7Audio measure, so the capture
; exists only while the drawer is open and live; any change of variant is a
; refresh, which is the only way AudioLevel releases its streams.
; Media hosts the Visualizer's shared Capture.inc and Spectrum.inc; the plot
; box comes from the spectrum block in InlineQueueGeometry.inc.
[Variables]
; Only this file opens the drawer geometry (InlineQueueGeometry.inc): a saved
; value that does not name this file can never lift an empty sheet. All three
; capture variants share it, so the window never changes size between them.
MediaVisualizerOpen=1
; While the drawer is open and live Media ticks every #MediaAnimationInterval#
; (50 ms; InlineQueueGeometry.inc chooses #MediaTickInterval#). The Visualizer
; cadence maps onto that tick: 50 and 33 ms both run every tick (33 ms cannot
; be met inside Media), 100 ms every other tick.
VisualizerCaptureDivider=(Max(1,Round(#VisualizerEffectiveInterval#/#MediaTickInterval#)))
VisualizerPlotInnerWidth=(#MediaVisualizerPlotWidth#-2)
VisualizerPlotInnerHeight=(#MediaVisualizerPlotHeight#-2)
VisualizerSpectrumX=(#MediaVisualizerPlotX#+1)
VisualizerSpectrumY=(#MediaVisualizerPlotY#+1)
; Output-row cadence on Media's tick: Win7Audio volume and the device name
; and status once a second each, as in the standalone. Every Win7Audio read
; is a full COM device enumeration (docs/PERFORMANCE-REVIEW.md VIS-04).
VisualizerVolumeDivider=(Max(1,Round(1000/#MediaTickInterval#)))
VisualizerDeviceNameDivider=(Max(1,Round(1000/#MediaTickInterval#)))
VisualizerVolumeAvailable=0
; The bars' baseline inside the plot. Spectrum.inc defines the same value for
; the live variant; the grid and the dB labels need it in every variant.
VisualizerBarHeight=(#VisualizerPlotInnerHeight#-#VisualizerBaselineGapPx#)
; The status overlay's text, colour and box, and the static axis texts. The
; live variant starts from "Output unavailable" until Capture.inc's state
; measure sets the real state; the other variants set their own values.
MediaVisualizerOverlayText=Output unavailable
MediaVisualizerOverlayColor=#WarningColor#
MediaVisualizerOverlayFill=#GraphBackgroundColor#
MediaVisualizerOverlayX=(#MediaVisualizerPlotX#+#MediaVisualizerPlotWidth#/2)
MediaVisualizerOverlayY=(#MediaVisualizerPlotY#+#MediaVisualizerPlotHeight#/2)
MediaVisualizerOverlayWidth=(#MediaVisualizerPlotWidth#-8*#Scale#)
MediaVisualizerOverlayHeight=(18*#Scale#)
MediaVisualizerOverlayClip=1
MediaVisualizerAxisTopText=0 dB
MediaVisualizerAxisLowText=40 Hz
MediaVisualizerAxisHighText=16 kHz

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

; The single non-live overlay. In the live variant MeasureVisualizerState
; (Capture.inc) sets its text and color and forces its update: Output
; unavailable, Idle - quiet or Unsupported format; it hides while there is
; signal. The paused and deferred variants show their own fixed text.
[MeterVisualizerUnavailable]
Meter=String
MeterStyle=StyleLabel
X=#MediaVisualizerOverlayX#
Y=#MediaVisualizerOverlayY#
W=#MediaVisualizerOverlayWidth#
H=#MediaVisualizerOverlayHeight#
ClipString=#MediaVisualizerOverlayClip#
StringAlign=CenterCenter
Text=#MediaVisualizerOverlayText#
FontColor=#MediaVisualizerOverlayColor#
SolidColor=#MediaVisualizerOverlayFill#
UpdateDivider=-1

; Output row, as the standalone draws it (View.inc): the user-selected Lucide
; Speaker (Icons\Lucide\README.md) on the left; the variant draws the clipped
; device name after it, out to the chevron's column: the drawer's collapse
; chevron (Common.inc) holds the row's last 18S, at the plot's right edge.
; The read-only Windows output volume sits in the title row instead.
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

; Axis labels, as the standalone Visualizer draws them: a relative dB scale in
; the gutter left of the plot (0 at full height, the midpoint at minus half the
; sensitivity, the bottom at minus the sensitivity - AudioLevel's normalized
; band scale inverted; the variant draws those two) and the capture's
; 40 Hz / 16 kHz range under it. None of these overlaps a variant's meter, so
; drawing them before the variant paints the same pixels as before the split.

[MeterVisualizerDbMax]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerPlotX#-4*#Scale#)
Y=(#MediaVisualizerPlotY#+1)
W=(36*#Scale#)
StringAlign=Right
FontColor=#MutedColor#
Text=#MediaVisualizerAxisTopText#
UpdateDivider=-1

[MeterVisualizerLow]
Meter=String
MeterStyle=StyleLabel
X=#MediaVisualizerLowLabelX#
Y=#MediaVisualizerAxisLabelY#
W=(50*#Scale#)
StringAlign=LeftCenter
FontColor=#MutedColor#
Text=#MediaVisualizerAxisLowText#
UpdateDivider=-1

[MeterVisualizerHigh]
Meter=String
MeterStyle=StyleLabel
X=#MediaVisualizerHighLabelRight#
Y=#MediaVisualizerAxisLabelY#
W=(50*#Scale#)
StringAlign=RightCenter
FontColor=#MutedColor#
Text=#MediaVisualizerAxisHighText#
UpdateDivider=-1

; Last section of this file, so Rainmeter appends the variant's sections here
; and, in the live variant, the measured bars paint over the plot frame.
[MediaVisualizerCaptureInclude]
@Include18=#@#Modules\Media\DrawerCapture#MediaDrawerCapture#.inc
