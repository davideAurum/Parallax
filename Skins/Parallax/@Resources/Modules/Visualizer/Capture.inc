; Shared capture: one AudioLevel output parent, its state children and 24 bands.
; Used by the standalone Visualizer and by Media's expanded spectrum drawer,
; which is the only Media state that includes this file. The host defines
; VisualizerCaptureDivider (1 standalone; Media maps the Visualizer cadence onto
; its own 50 ms tick) and the MeterVisualizerUnavailable overlay plus the
; VisualizerSpectrum meter group that MeasureVisualizerState drives.

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
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerDevice]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=DeviceStatus
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerFormat]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Format
IfMatch=<invalid>
IfMatchAction=[!SetVariable VisualizerFormatInvalid 1]
IfNotMatchAction=[!SetVariable VisualizerFormatInvalid 0]
IfMatchMode=0
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerRMS]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=RMS
Channel=Avg
UpdateDivider=#VisualizerCaptureDivider#

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
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand0]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=0
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand1]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=1
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand2]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=2
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand3]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=3
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand4]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=4
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand5]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=5
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand6]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=6
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand7]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=7
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand8]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=8
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand9]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=9
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand10]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=10
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand11]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=11
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand12]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=12
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand13]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=13
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand14]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=14
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand15]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=15
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand16]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=16
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand17]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=17
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand18]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=18
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand19]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=19
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand20]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=20
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand21]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=21
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand22]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=22
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#

[MeasureVisualizerBand23]
Measure=Plugin
Plugin=AudioLevel
Parent=MeasureVisualizerAudio
Type=Band
Channel=Avg
BandIdx=23
MinValue=0
MaxValue=1
UpdateDivider=#VisualizerCaptureDivider#
