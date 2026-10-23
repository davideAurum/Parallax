; No UsageMonitor measure lives here: the process table's GPU Engine ranks,
; including MeasureGPUActivity (row 1), load only with the table
; (ProcessMeasures<GPUShowProcesses>.inc), because a loaded UsageMonitor
; measure keeps its category reader running even while Disabled. The header
; figure and the History graph come from the direct driver sample
; (TemperatureMeasures.inc).

; Self reference starts at zero on load AND refresh; global Counter does not.
; Counts History points: Temperature.lua forces it together with the Line
; meter for each point it pushes (and Rainmeter updates both once at load).
; This is a point count, not telemetry; it only drives the startup cover.
[MeasureGPUGraphSamples]
Measure=Calc
Formula=Min(MeasureGPUGraphSamples+1,#ContentWidth#)
UpdateDivider=-1
; Once the graph is full the startup cover has nothing left to cover: hide it
; and end its per-update re-read for the rest of the load. The cover's
; SetOption forces one last re-read, which takes the new divider; hiding
; alone would not stop its updates. A refresh restores the INI values.
IfCondition=MeasureGPUGraphSamples>=#ContentWidth#
IfTrueAction=[!SetOption MeterGPUGraphUncollected DynamicVariables 0][!SetOption MeterGPUGraphUncollected UpdateDivider -1][!HideMeter MeterGPUGraphUncollected]

; Values can remain in the registry after HWiNFO stops. This is a snapshot.
; List membership distinguishes a missing ValueRawN from a real numeric zero.
; All banks start disabled; Temperature.lua enables only explicitly selected
; canonical HWiNFO sources once at initialization, without formula evaluation.
[MeasureGPURegistryNames]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerSensor]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Sensor#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerLabel]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Label#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerValue]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Value#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUPowerValueRaw]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw#GPUPowerIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockSensor]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Sensor#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockLabel]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Label#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockValue]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=Value#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUClockValueRaw]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw#GPUClockIndex#
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

; Freshness reference for an HWiNFO override. The Gadget export has no
; timestamp, HWiNFO writes it only while its Sensors window is open, and a
; mapped clock can legitimately hold one value for minutes (an idle GPU).
; The first eight exported raw values join the mapped ones in one signature;
; Temperature.lua withholds the overrides only when all of them stay
; unchanged for 60 s. Enabled with MeasureGPURegistryNames, only for an
; explicit override; the default driver path never reads them.
[MeasureGPUExportProbe0]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw0
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe1]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe2]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw2
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe3]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw3
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe4]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw4
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe5]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw5
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe6]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw6
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Disabled=1

[MeasureGPUExportProbe7]
Measure=Registry
Group=ParallaxIdlePause
RegHKey=#GPURegHKey#
RegKey=#GPURegKey#
RegValue=ValueRaw7
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
Group=ParallaxIdlePause
ScriptFile=#@#Modules\GPU\GPU.lua
