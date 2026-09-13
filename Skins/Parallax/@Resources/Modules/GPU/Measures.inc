; Built-in UsageMonitor has a shared 1 Hz worker independent of UpdateDivider.
; Keep the raw PID/adapter/engine instance: translating to an executable name
; may combine multiple engines or PIDs. Index=1 selects one ranked instance.
[MeasureGPUActivity]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=1
Rollup=0
PIDToName=0
Percent=0
RawValue=0

; Values can remain in the registry after HWiNFO stops. This is a snapshot.
; List membership distinguishes a missing ValueRawN from a real numeric zero.
; All banks start disabled; Temperature.lua enables only explicitly selected
; canonical HWiNFO sources once at initialization, without formula evaluation.
[MeasureGPURegistryNames]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerSensor]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Sensor#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerLabel]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Label#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerValue]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Value#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerValueRaw]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockSensor]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Sensor#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockLabel]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Label#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockValue]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Value#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockValueRaw]
Measure=Registry
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

; One metadata query on load/refresh, never a recurring telemetry process.
; Original helper selects a discrete DXCore adapter, queries its metadata, and
; provides the exact adapter identity to the direct telemetry provider.
[MeasureGPUInfo]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\GPU\
Parameter=-NoLogo -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $ErrorActionPreference='Stop'; try { Add-Type -TypeDefinition ([IO.File]::ReadAllText('AdapterInfo.cs.txt')); [Console]::Write([ParallaxGpuInfo]::ReadForSkin()) } catch { [Console]::Write('UNAVAILABLE') }"
State=Hide
OutputType=UTF8
Timeout=12000
UpdateDivider=1
FinishAction=[!UpdateMeasure MeasureGPUInfo][!UpdateMeasure MeasureGPUView]

; Keep the view last: it reads the current counter, metadata and registry measures.
[MeasureGPUView]
Measure=Script
ScriptFile=#@#Modules\GPU\GPU.lua
