; Standalone Audio Visualizer stood down for the Global Settings Idle pause
; (StandbyState.inc VisualizerStandby=1; @Resources\Idle\StandDown.lua). No
; AudioLevel or Win7Audio measure exists, so the capture, its silent render
; stream and the volume polling are released; the window keeps its frame and
; shows "Paused (idle)" in the plot. The entrypoint ticks once a second. The
; first input reloads the live variant (Standalone0.inc).
[Variables]
VisualizerRefreshAction=
VisualizerHoverIn=[!ShowMeter MeterVisualizerOptions][!Redraw]
VisualizerHoverOut=[!HideMeter MeterVisualizerOptions][!Redraw]
VisualizerOverlayText=Paused (idle)
VisualizerOverlayColor=#MutedColor#
VisualizerDeviceNextAction=
VisualizerDevicePreviousAction=
; The plot frame's grid and dB ticks use the bar height the live variant's
; spectrum include defines; the same formula here.
VisualizerBarHeight=(#VisualizerPlotInnerHeight#-#VisualizerBaselineGapPx#)

; Static stand-ins for the values View.inc names; read once at load.
[MeasureVisualizerDbMid]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#/2)
UpdateDivider=-1

[MeasureVisualizerDbMin]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#)
UpdateDivider=-1

; No volume reading while stood down: the readout keeps its "--".
[MeasureVisualizerVolumeValue]
Measure=Calc
Formula=-1
UpdateDivider=-1

; No output device is queried while stood down.
[MeasureVisualizerDeviceName]
Measure=String
String=--
UpdateDivider=-1

[VisualizerStandbyViewInclude]
@Include8=#@#Modules\Visualizer\View.inc
