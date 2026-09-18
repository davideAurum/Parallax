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

; Dedicated memory lookups share one GPU Process Memory collection worker.
; Name is an exact validated PID/LUID/physical-adapter prefix, never a rank
; or process name. The inert name remains nonempty to avoid Index=0 totals.
[MeasureGPUProcessMemory1]
Measure=Plugin
Plugin=UsageMonitor
Alias=VRAM
Name=__ParallaxNoGPUProcess__
Index=0
Rollup=0
PIDToName=0
Percent=0
RawValue=1
Disabled=1

[MeasureGPUProcessMemory2]
Measure=Plugin
Plugin=UsageMonitor
Alias=VRAM
Name=__ParallaxNoGPUProcess__
Index=0
Rollup=0
PIDToName=0
Percent=0
RawValue=1
Disabled=1

[MeasureGPUProcessMemory3]
Measure=Plugin
Plugin=UsageMonitor
Alias=VRAM
Name=__ParallaxNoGPUProcess__
Index=0
Rollup=0
PIDToName=0
Percent=0
RawValue=1
Disabled=1

[MeasureGPUProcessMemory4]
Measure=Plugin
Plugin=UsageMonitor
Alias=VRAM
Name=__ParallaxNoGPUProcess__
Index=0
Rollup=0
PIDToName=0
Percent=0
RawValue=1
Disabled=1

[MeasureGPUProcessMemory5]
Measure=Plugin
Plugin=UsageMonitor
Alias=VRAM
Name=__ParallaxNoGPUProcess__
Index=0
Rollup=0
PIDToName=0
Percent=0
RawValue=1
Disabled=1

[MeasureGPUProcessController]
Measure=Script
ScriptFile=#@#Modules\GPU\ProcessGraph.lua
