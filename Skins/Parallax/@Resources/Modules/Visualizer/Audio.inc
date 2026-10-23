; Output-row measures shared by the standalone Visualizer and Media's open
; spectrum drawer: relative dB axis labels, the Windows default-output volume /
; output-switch target, and device naming/discovery. The capture parent, state
; and bands live in Capture.inc; the palette script lives in Spectrum.inc. The
; host sets VisualizerVolumeDivider, VisualizerDeviceNameDivider and
; VisualizerVolumeAvailable=0 for its own skin cadence, and defines
; MeterVisualizerVolume and MeterVisualizerDeviceName at UpdateDivider=-1:
; the measures below update them when what they show changes.

; Axis values invert AudioLevel's normalized FFT/band sensitivity scale.
; This is a relative spectrum dB scale, not calibrated dBFS or sound pressure.
[MeasureVisualizerDbMid]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#/2)
UpdateDivider=-1

[MeasureVisualizerDbMin]
Measure=Calc
Formula=(-#VisualizerSensitivityDb#)
UpdateDivider=-1

; Windows default output volume and explicit output-switch command target.
; Device commands run only from the current-output row; volume stays read-only.
; Switching clears the custom AudioLevel ID and refreshes to follow the new default.
; Win7Audio returns -1 while muted. Its string reports device discovery errors;
; failed numeric getters can retain a prior value, with no freshness signal.
[MeasureVisualizerVolume]
Measure=Plugin
Plugin=Win7AudioPlugin
UpdateDivider=#VisualizerVolumeDivider#
IfMatch=^(?:$|ERROR(?: - |$))
IfMatchAction=[!SetVariable VisualizerVolumeAvailable 0]
IfNotMatchAction=[!SetVariable VisualizerVolumeAvailable 1]
IfMatchMode=0

; A Calc binding keeps String %1 numeric instead of the plugin's device name.
[MeasureVisualizerVolumeValue]
Measure=Calc
Formula=MeasureVisualizerVolume
MinValue=-1
MaxValue=100
DynamicVariables=1
UpdateDivider=#VisualizerVolumeDivider#
IfCondition=#VisualizerVolumeAvailable#=0
IfTrueAction=[!SetOption MeterVisualizerVolume Text "--"][!UpdateMeter MeterVisualizerVolume]
IfCondition2=(#VisualizerVolumeAvailable#=1)&&(MeasureVisualizerVolumeValue<0)
IfTrueAction2=[!SetOption MeterVisualizerVolume Text "Muted"][!UpdateMeter MeterVisualizerVolume]
IfCondition3=(#VisualizerVolumeAvailable#=1)&&(MeasureVisualizerVolumeValue>=0)
IfTrueAction3=[!SetOption MeterVisualizerVolume Text "%1%"][!UpdateMeter MeterVisualizerVolume]
IfConditionMode=0

; The readout meters are UpdateDivider=-1 in both hosts: a due meter repaints
; the whole window, so they repaint only when what they show changes
; (docs/PERFORMANCE-REVIEW.md VIS-03). This Calc's value is the readout's
; state: -2 unavailable, -1 muted, otherwise the volume. It changes on every
; displayed change, including an availability flip with an unchanged number,
; which the value binding above cannot see. OnChangeAction runs after the
; text actions above and never on the load's first update. Nothing here reads
; the Win7Audio string again: an OnChangeAction there would re-run its COM
; device lookup.
[MeasureVisualizerVolumeShown]
Measure=Calc
Formula=(#VisualizerVolumeAvailable#=0 ? -2 : MeasureVisualizerVolumeValue)
DynamicVariables=1
UpdateDivider=#VisualizerVolumeDivider#
OnChangeAction=[!UpdateMeter MeterVisualizerVolume][!Redraw]

; AudioLevel returns its cached device name, so the change check is cheap.
[MeasureVisualizerDeviceName]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceName
UpdateDivider=#VisualizerDeviceNameDivider#
Substitute="":"No output device"
OnChangeAction=[!UpdateMeter MeterVisualizerDeviceName][!Redraw]

; Discovery only: no separate capture parent and no file/clipboard export.
[MeasureVisualizerDeviceList]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceList
UpdateDivider=-1
