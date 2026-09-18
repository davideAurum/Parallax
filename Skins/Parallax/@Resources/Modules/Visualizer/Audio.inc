; Resolve the selected shared palette on refresh; no recurring appearance work.
[MeasureVisualizerColor]
Measure=Script
ScriptFile=#@#Modules\Visualizer\Color.lua
UpdateDivider=-1

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

; Rainmeter's bundled AudioLevel: one loopback capture / FFT parent.
; Parent options cannot change dynamically; use !Refresh after editing.
[MeasureVisualizerAudio]
Measure=Plugin
Plugin=AudioLevel
Port=Output
ID=#VisualizerDeviceID#
FFTSize=#VisualizerFFTSize#
FFTOverlap=0
Bands=24
FreqMin=40
FreqMax=16000
FFTAttack=#VisualizerAttackMs#
FFTDecay=#VisualizerDecayMs#
Sensitivity=#VisualizerSensitivityDb#
RMSAttack=50
RMSDecay=500
RMSGain=1

[MeasureVisualizerDevice]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceStatus

[MeasureVisualizerDeviceName]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceName
UpdateDivider=(Max(1,Round(1000/#VisualizerEffectiveInterval#)))
Substitute="":"No output device"

[MeasureVisualizerFormat]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Format
IfMatch=<invalid>
IfMatchAction=[!SetVariable VisualizerFormatInvalid 1]
IfNotMatchAction=[!SetVariable VisualizerFormatInvalid 0]
IfMatchMode=0

; Discovery only: no separate capture parent and no file/clipboard export.
[MeasureVisualizerDeviceList]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceList
UpdateDivider=-1

[MeasureVisualizerRMS]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=RMS
Channel=Avg

; DeviceStatus is endpoint availability, not a freshness timestamp.
; States: 0 = unavailable, 1 = below threshold, 2 = signal, 3 = invalid format.
; On silence, hide bands: AudioLevel can retain its last FFT arrays.
[MeasureVisualizerState]
Measure=Calc
Formula=(MeasureVisualizerDevice<=0 ? 0 : (#VisualizerFormatInvalid#=1 ? 3 : (MeasureVisualizerRMS>#VisualizerIdleFloor# ? 2 : 1)))
DynamicVariables=1
IfCondition=MeasureVisualizerState=0
IfTrueAction=[!SetOption MeterVisualizerUnavailable Text "Output unavailable"][!SetOption MeterVisualizerUnavailable FontColor "#WarningColor#"][!HideMeterGroup VisualizerSpectrum][!ShowMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerUnavailable]
IfCondition2=MeasureVisualizerState=1
IfTrueAction2=[!SetOption MeterVisualizerUnavailable Text "Idle - quiet"][!SetOption MeterVisualizerUnavailable FontColor "#MutedColor#"][!HideMeterGroup VisualizerSpectrum][!ShowMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerUnavailable]
IfCondition3=MeasureVisualizerState=2
IfTrueAction3=[!ShowMeterGroup VisualizerSpectrum][!HideMeter MeterVisualizerUnavailable]
IfCondition4=MeasureVisualizerState=3
IfTrueAction4=[!SetOption MeterVisualizerUnavailable Text "Unsupported format"][!SetOption MeterVisualizerUnavailable FontColor "#WarningColor#"][!HideMeterGroup VisualizerSpectrum][!ShowMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerUnavailable]
IfConditionMode=0

[MeasureVisualizerBand0]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=0
MinValue=0
MaxValue=1

[MeasureVisualizerBand1]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=1
MinValue=0
MaxValue=1

[MeasureVisualizerBand2]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=2
MinValue=0
MaxValue=1

[MeasureVisualizerBand3]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=3
MinValue=0
MaxValue=1

[MeasureVisualizerBand4]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=4
MinValue=0
MaxValue=1

[MeasureVisualizerBand5]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=5
MinValue=0
MaxValue=1

[MeasureVisualizerBand6]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=6
MinValue=0
MaxValue=1

[MeasureVisualizerBand7]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=7
MinValue=0
MaxValue=1

[MeasureVisualizerBand8]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=8
MinValue=0
MaxValue=1

[MeasureVisualizerBand9]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=9
MinValue=0
MaxValue=1

[MeasureVisualizerBand10]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=10
MinValue=0
MaxValue=1

[MeasureVisualizerBand11]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=11
MinValue=0
MaxValue=1

[MeasureVisualizerBand12]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=12
MinValue=0
MaxValue=1

[MeasureVisualizerBand13]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=13
MinValue=0
MaxValue=1

[MeasureVisualizerBand14]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=14
MinValue=0
MaxValue=1

[MeasureVisualizerBand15]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=15
MinValue=0
MaxValue=1

[MeasureVisualizerBand16]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=16
MinValue=0
MaxValue=1

[MeasureVisualizerBand17]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=17
MinValue=0
MaxValue=1

[MeasureVisualizerBand18]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=18
MinValue=0
MaxValue=1

[MeasureVisualizerBand19]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=19
MinValue=0
MaxValue=1

[MeasureVisualizerBand20]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=20
MinValue=0
MaxValue=1

[MeasureVisualizerBand21]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=21
MinValue=0
MaxValue=1

[MeasureVisualizerBand22]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=22
MinValue=0
MaxValue=1

[MeasureVisualizerBand23]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=23
MinValue=0
MaxValue=1
