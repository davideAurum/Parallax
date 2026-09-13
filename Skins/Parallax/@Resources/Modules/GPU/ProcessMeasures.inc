; Ranks share UsageMonitor's existing GPU Engine collection worker. Rank 1
; reuses MeasureGPUActivity. Keep raw PID/adapter/engine identities and values.
[MeasureGPUProcess2]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=2
Rollup=0
PIDToName=0
Percent=0
RawValue=0

[MeasureGPUProcess3]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=3
Rollup=0
PIDToName=0
Percent=0
RawValue=0

[MeasureGPUProcess4]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=4
Rollup=0
PIDToName=0
Percent=0
RawValue=0

[MeasureGPUProcess5]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=5
Rollup=0
PIDToName=0
Percent=0
RawValue=0

[MeasureGPUProcessController]
Measure=Script
ScriptFile=#@#Modules\GPU\ProcessGraph.lua
