; Standalone-only measures: relative dB axis labels, the Windows default-output
; volume / output-switch target, and device naming/discovery. The capture parent,
; state and bands live in Capture.inc; the palette script lives in Spectrum.inc.

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

[MeasureVisualizerDeviceName]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceName
UpdateDivider=(Max(1,Round(1000/#VisualizerEffectiveInterval#)))
Substitute="":"No output device"

; Discovery only: no separate capture parent and no file/clipboard export.
[MeasureVisualizerDeviceList]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceList
UpdateDivider=-1
