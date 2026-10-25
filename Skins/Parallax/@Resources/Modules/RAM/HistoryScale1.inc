; Auto history scale (RAMHistoryScale=1). HistoryRange.lua sets the Calc proxy's
; MinValue/MaxValue; the Line meter maps its stored samples with the bound
; measure's current range at draw time, which PhysicalMemory (MaxValue forced
; to the total) cannot offer. The controller precedes the proxy so a new range
; applies to the same update's draw. Both join the idle pause with the other
; history measures. Chosen at load: RAM Settings refreshes Memory Meter.
[Variables]
RAMHistoryMeasure=MeasureRAMHistoryValue

[MeasureRAMHistoryRange]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\RAM\HistoryRange.lua
UpdateDivider=1

[MeasureRAMHistoryValue]
Measure=Calc
Group=ParallaxIdlePause
Formula=MeasureRAMUsed
MinValue=0
MaxValue=1000000000000
UpdateDivider=1
