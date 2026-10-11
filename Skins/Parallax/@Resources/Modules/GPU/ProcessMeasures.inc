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

; Per-process memory lookups share one GPU Process Memory collection worker.
; They read Local Usage, not the VRAM alias's Dedicated Usage: Local Usage is
; what Task Manager's Details "Dedicated GPU memory" column shows (verified on
; Windows 11 build 26300), while Dedicated Usage reads higher and has been seen
; overcounting by terabytes. See docs/modules/GPU.md.
; Name is an exact validated PID/LUID/physical-adapter prefix, never a rank
; or process name. The inert name remains nonempty to avoid Index=0 totals.
[MeasureGPUProcessMemory1]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Process Memory
Counter=Local Usage
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
Category=GPU Process Memory
Counter=Local Usage
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
Category=GPU Process Memory
Counter=Local Usage
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
Category=GPU Process Memory
Counter=Local Usage
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
Category=GPU Process Memory
Counter=Local Usage
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
