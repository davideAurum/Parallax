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

[MediaVisualizerCaptureInclude]
@Include18=#@#Modules\Visualizer\Capture.inc

; Selects the solid or gradient fill once per load. UpdateDivider=-1 updates it
; once, after every meter exists; Apply(false) leaves drawing to Media's update.
[MeasureVisualizerColorApply]
Measure=Calc
Formula=1
UpdateDivider=-1
OnUpdateAction=[!CommandMeasure MeasureVisualizerColor "Apply(false)"]

; Frame and grid of the drawer's only object. No dB axis, frequency labels,
; output-device row or volume readout: those stay in the standalone
; Visualizer, and the tab's tooltip names the range and the relative scale.
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

; Last section of this file, so Rainmeter appends Spectrum.inc's sections here
; and the measured bars paint over the plot frame.
[MediaVisualizerSpectrumInclude]
@Include19=#@#Modules\Visualizer\Spectrum.inc
