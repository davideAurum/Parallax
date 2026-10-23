; MediaDrawerCapture=2 (Modules\Media\CaptureState.inc): the open drawer while
; the standalone Audio Visualizer is loaded, included last by
; VisualizerDrawer2.inc. One capture is enough: no AudioLevel, Win7Audio or
; spectrum script exists here. The drawer points to the Audio Visualizer and
; the output row shows --. Nothing here is clickable; the drawer returns to
; live capture when the Audio Visualizer unloads.

; With no spectrum there is no plot or scale to read, so the message covers
; the plot box and its dB gutter in the drawer's own fill, and the shared axis
; labels are blank. The full content width keeps the message within two lines
; at the narrowest supported layout (width 180, scale 0.75, compact) with the
; largest body font; inside the plot alone it would need three. One extra
; pixel on each side covers the frame's antialiased edge at fractional scales.
[Variables]
MediaVisualizerOverlayText=Spectrum is shown in Audio Visualizer
MediaVisualizerOverlayColor=#MutedColor#
MediaVisualizerOverlayFill=#MediaQueueDrawerFill#
MediaVisualizerOverlayX=(#MediaVisualizerRowX#+#MediaVisualizerRowWidth#/2)
MediaVisualizerOverlayWidth=(#MediaVisualizerRowWidth#+2)
MediaVisualizerOverlayHeight=(#MediaVisualizerPlotHeight#+2)
MediaVisualizerOverlayClip=2
MediaVisualizerAxisTopText=
MediaVisualizerAxisLowText=
MediaVisualizerAxisHighText=

; The capture lease (Modules\Media\CaptureLease.lua) owns this state.
[MeasureMediaCaptureLease]
Measure=Script
ScriptFile=#@#Modules\Media\CaptureLease.lua
UpdateDivider=-1

[MeterVisualizerDeviceName]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerRowX#+18*#Scale#)
Y=#MediaVisualizerRowY#
W=(#MediaVisualizerRowWidth#-18*#Scale#-64*#Scale#)
H=(18*#Scale#)
FontColor=#MutedColor#
Text=--
UpdateDivider=-1

[MeterVisualizerVolume]
Meter=String
MeterStyle=StyleLabel
X=(#MediaVisualizerRowX#+#MediaVisualizerRowWidth#)
Y=#MediaVisualizerRowY#
W=(60*#Scale#)
StringAlign=Right
FontColor=#MutedColor#
Text=--
UpdateDivider=-1
