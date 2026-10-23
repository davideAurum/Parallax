; GPUShowProcesses=1: the process table. GPU.ini includes this file only in
; that state (ProcessMeasures0.inc otherwise), because UsageMonitor reads a
; whole counter category once a second, process-wide, for as long as any
; loaded measure names it: Disabled=1 does not stop that reader, only not
; loading the measure does. Every UsageMonitor measure in GPU lives here.
[Variables]
; Only this file opens the table's geometry (GPU.ini): a saved value that does
; not name this file can never leave an empty table in the panel.
GPUProcessTable=1

; Ranks share UsageMonitor's GPU Engine collection worker. Keep the raw
; PID/adapter/engine instance: translating to an executable name may combine
; multiple engines or PIDs. Index=1 selects one ranked instance; it feeds
; row 1 of the process table only. The header figure and the History graph
; come from the direct driver sample (TemperatureMeasures.inc).
; PIDToName=0 also keeps UsageMonitor from starting its own 1 Hz read of the
; whole Process category to map PIDs to names; names come from the GPU
; helper (Temperature.lua) instead.
[MeasureGPUActivity]
Measure=Plugin
Plugin=UsageMonitor
Alias=GPU
Index=1
Rollup=0
PIDToName=0
Percent=0
RawValue=0

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

; The VRAM column's five GPU Process Memory lookups, or a comment-only stub
; while GPUShowProcessMemory=0, so that category is not read either.
[GPUProcessMemoryMeasureInclude]
@Include12=#@#Modules\GPU\ProcessMemoryMeasures#GPUShowProcessMemory#.inc

[MeasureGPUProcessController]
Measure=Script
ScriptFile=#@#Modules\GPU\ProcessGraph.lua
