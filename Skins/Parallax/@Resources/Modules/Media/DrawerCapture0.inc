; MediaDrawerCapture=0 (Modules\Media\CaptureState.inc): the live spectrum
; drawer, included last by VisualizerDrawer2.inc. Only this variant creates
; the AudioLevel capture (with its silent render stream, which keeps the
; Windows audio engine running until the measure is unloaded) and Win7Audio.
; Its sections are the open drawer's live content before the 2026-10-23
; split, unchanged and in the same order, plus the capture lease.

[Variables]
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

[MediaVisualizerCaptureParentInclude]
@Include22=#@#Modules\Visualizer\Capture.inc

; The standalone's output-row measures: dB ticks, Win7Audio volume and device
; switching, device name and discovery. Win7Audio exists only while live too.
[MediaVisualizerAudioInclude]
@Include21=#@#Modules\Visualizer\Audio.inc

; Selects the solid or gradient fill once per load. UpdateDivider=-1 updates it
; once, after every meter exists; Apply(false) leaves drawing to Media's update.
[MeasureVisualizerColorApply]
Measure=Calc
Formula=1
UpdateDivider=-1
OnUpdateAction=[!CommandMeasure MeasureVisualizerColor "Apply(false)"]

; The capture lease (Modules\Media\CaptureLease.lua): parks this capture after
; 2 minutes of silence while you are away and resumes it on input, playback
; or a click, through MediaOptions.ApplyLease. About once a second (the
; provider cadence), plus each idle broadcast and the delayed join.
[MeasureMediaCaptureLease]
Measure=Script
ScriptFile=#@#Modules\Media\CaptureLease.lua
Group=ParallaxIdleHook | ParallaxIdleJoin | ParallaxMediaCompanion
UpdateDivider=#MediaLegacyDivider#

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

; The two sensitivity ticks (Audio.inc's MeasureVisualizerDbMid/Min).
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

; Last section of this file, so Rainmeter appends Spectrum.inc's sections here
; and the measured bars paint over the plot frame.
[MediaVisualizerSpectrumInclude]
@Include19=#@#Modules\Visualizer\Spectrum.inc
