; GPUShowProcessMemory=1: the process table's VRAM column. ProcessMeasures1.inc
; includes this file only in that state (ProcessMemoryMeasures0.inc otherwise),
; so the GPU Process Memory category has a reader only while the column shows.
[Variables]
; Only this file opens the VRAM column's geometry (GPU.ini, ProcessMeters1.inc)
; and ProcessGraph.lua's memory bindings.
GPUProcessMemoryColumn=1

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
