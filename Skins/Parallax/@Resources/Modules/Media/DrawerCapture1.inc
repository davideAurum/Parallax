; MediaDrawerCapture=1 (Modules\Media\CaptureState.inc): the open drawer with
; its capture paused, included last by VisualizerDrawer2.inc. No AudioLevel,
; Win7Audio or spectrum script exists here, so Windows' audio engine is free to
; stop. The plot says "Capture paused"; the output row shows -- because
; nothing reads the device; a click anywhere on the plot resumes the capture.

[Variables]
MediaVisualizerOverlayText=Capture paused
MediaVisualizerOverlayColor=#MutedColor#
; The capture lease joins the Parallax\Idle input-idle coordinator 100 ms
; after each load (Media.ini appends this to OnRefreshAction): after
; Rainmeter's startup walk and after this reload's own first update
; (docs/ARCHITECTURE.md, input-idle coordinator). Until the coordinator
; broadcasts, the idle state reads unsynced and nothing parks.
ParallaxIdleJoinAction=[!Delay 100][!UpdateMeasureGroup ParallaxIdleJoin]
ParallaxIdleAway=0
ParallaxIdlePaused=0
ParallaxIdleSync=0
ParallaxIdleBeat=0
; Set to 1 by the standalone Audio Visualizer (Modules\Visualizer\Companion.lua)
; with the ParallaxMediaCompanion group update: re-check whether to defer.
ParallaxCompanionCheck=0

; The sensitivity ticks, from the Audio settings value as in the live drawer.
[MeasureMediaDrawerDbMid]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#/2)
UpdateDivider=-1

[MeasureMediaDrawerDbMin]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#)
UpdateDivider=-1

; The capture lease (Modules\Media\CaptureLease.lua) owns this state: it
; resumes the capture on input, playback or this plot's click target, through
; MediaOptions.ApplyLease, and fails live if the idle coordinator is missing
; or silent. About once a second, plus each idle broadcast.
[MeasureMediaCaptureLease]
Measure=Script
ScriptFile=#@#Modules\Media\CaptureLease.lua
Group=ParallaxIdleHook | ParallaxIdleJoin | ParallaxMediaCompanion
UpdateDivider=#MediaLegacyDivider#

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

[MeterVisualizerDbMid]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureMediaDrawerDbMid
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
MeasureName=MeasureMediaDrawerDbMin
X=(#MediaVisualizerPlotX#-4*#Scale#)
Y=(#MediaVisualizerPlotY#+1+#VisualizerBarHeight#)
W=(36*#Scale#)
StringAlign=RightBottom
FontColor=#MutedColor#
Text=%1
NumOfDecimals=1
UpdateDivider=-1

; The click target over the whole plot: nearly transparent (alpha 1, so
; Rainmeter hit-tests it), a hand cursor and no tooltip.
[MeterMediaCaptureResume]
Meter=Image
X=#MediaVisualizerPlotX#
Y=#MediaVisualizerPlotY#
W=#MediaVisualizerPlotWidth#
H=#MediaVisualizerPlotHeight#
SolidColor=0,0,0,1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaCaptureLease "Unpark('click')"]
UpdateDivider=-1
