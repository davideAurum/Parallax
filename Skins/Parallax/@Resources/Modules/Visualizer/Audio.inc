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
IfTrueAction=[!SetOption MeterVisualizerStatus Text "OUTPUT UNAVAILABLE"][!SetOption MeterVisualizerStatus FontColor "#WarningColor#"][!SetOption MeterVisualizerUnavailable Text "Output unavailable"][!HideMeterGroup VisualizerSpectrum][!ShowMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerStatus]
IfCondition2=MeasureVisualizerState=1
IfTrueAction2=[!SetOption MeterVisualizerStatus Text "IDLE - QUIET"][!SetOption MeterVisualizerStatus FontColor "#MutedColor#"][!HideMeterGroup VisualizerSpectrum][!HideMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerStatus]
IfCondition3=MeasureVisualizerState=2
IfTrueAction3=[!SetOption MeterVisualizerStatus Text "LIVE - MIXED OUTPUT"][!SetOption MeterVisualizerStatus FontColor "#GoodColor#"][!ShowMeterGroup VisualizerSpectrum][!HideMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerStatus]
IfCondition4=MeasureVisualizerState=3
IfTrueAction4=[!SetOption MeterVisualizerStatus Text "FORMAT UNSUPPORTED"][!SetOption MeterVisualizerStatus FontColor "#WarningColor#"][!SetOption MeterVisualizerUnavailable Text "Unsupported format"][!HideMeterGroup VisualizerSpectrum][!ShowMeter MeterVisualizerUnavailable][!UpdateMeter MeterVisualizerStatus]
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
