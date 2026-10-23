; RAMShowProcesses=1: the top-process table. Measures.inc includes this file
; only in that state (ProcessMeasures0.inc otherwise), before the table's
; controller. Bundled UsageMonitor ranks private resident memory in bytes.
; All five measures share its Process category worker, which samples
; independently at 1 Hz and is shared process-wide with CPU Meter's process
; list; it stops only when no loaded measure in any skin names the category.

[MeasureRAMProcess1]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=1
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess2]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=2
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess3]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=3
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess4]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=4
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess5]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=5
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1
