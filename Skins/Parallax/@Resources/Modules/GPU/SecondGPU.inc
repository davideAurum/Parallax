; Second GPU section (GPU Settings Second GPU, GPUSecondGPU): the next
; hardware GPU in Windows' high-performance order beside the main one, read by
; the same telemetry host (DriverTemperature.cs.txt, <session>.second) and shown
; by SecondGPU.lua between the memory rows and the process table, in the
; Engine table's row styles.
;   One line (1):  name and load, the load in the trace colour.
;   Rows (2):      adds a Video row with its bar and a memory-in-use row
;                  (VRAM on a discrete GPU, Shared on an integrated one).
;   Rows + history trace (3): also MeterGPUSecondGraph on the History graph.
;   Off (0):       nothing is sampled or shown.
; Collapsed (GPUSecondBlock=0) every meter here is hidden and has no height,
; so a single-GPU panel is unchanged. SecondGPU.lua opens it by setting
; GPUSecondBlock and re-reading the GPUSecondLayout group (the panel, these
; rows, the process table and the History block, which all move down by it),
; then showing GPUSecondLine / GPUSecondRows / GPUSecondTrace.
; Rows start 8 px below the Shared row, 16 px apart, with 8 px before the
; process table (or History): 24 px for One line, 56 px for Rows.

[MeasureGPUSecondHistory]
Measure=Calc
Formula=0
MinValue=0
MaxValue=100
UpdateDivider=-1

[MeasureGPUSecond]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\GPU\SecondGPU.lua
Mode=#GPUSecondGPU#

[MeterGPUSecondName]
Meter=String
MeterStyle=GPUStyleEngineLabel
Group=GPUSecondLayout|GPUSecondLine|ParallaxIdleFreeze
Y=#GPUSecondTop#
W=(#ContentWidth#-#GPUEngineValueWidth#-4*#Scale#)
H=(16*#Scale#*#GPUSecondShown#)
Text=Second GPU
Hidden=1

[MeterGPUSecondLoad]
Meter=String
MeterStyle=GPUStyleEngineValue
Group=GPUSecondLayout|GPUSecondLine|ParallaxIdleFreeze
Y=#GPUSecondTop#
H=(16*#Scale#*#GPUSecondShown#)
FontColor=#AccentColor#
Hidden=1

[MeterGPUSecondVideoLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Group=GPUSecondLayout|GPUSecondRows|ParallaxIdleFreeze
Y=(#GPUSecondTop#+16*#Scale#*#GPUSecondRowsShown#)
H=(16*#Scale#*#GPUSecondRowsShown#)
Text=Video
Hidden=1

[MeterGPUSecondVideoBar]
Meter=Shape
MeterStyle=GPUStyleEngineBar
Group=GPUSecondLayout|GPUSecondRows|ParallaxIdleFreeze
Y=(#GPUSecondTop#+(16*#Scale#+(16*#Scale#-#DataBarThicknessPx#)/2)*#GPUSecondRowsShown#)
H=(#DataBarThicknessPx#*#GPUSecondRowsShown#)
Hidden=1

[MeterGPUSecondVideoValue]
Meter=String
MeterStyle=GPUStyleEngineValue
Group=GPUSecondLayout|GPUSecondRows|ParallaxIdleFreeze
Y=(#GPUSecondTop#+16*#Scale#*#GPUSecondRowsShown#)
H=(16*#Scale#*#GPUSecondRowsShown#)
Hidden=1

[MeterGPUSecondMemoryLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Group=GPUSecondLayout|GPUSecondRows|ParallaxIdleFreeze
Y=(#GPUSecondTop#+32*#Scale#*#GPUSecondRowsShown#)
H=(16*#Scale#*#GPUSecondRowsShown#)
Text=VRAM
Hidden=1

; Occupied/total, right-aligned on the content edge like the VRAM: row.
[MeterGPUSecondMemoryValue]
Meter=String
MeterStyle=GPUStyleEngineLabel
Group=GPUSecondLayout|GPUSecondRows|ParallaxIdleFreeze
X=(#ContentX#+#ContentWidth#)
Y=(#GPUSecondTop#+32*#Scale#*#GPUSecondRowsShown#)
W=(#ContentWidth#-#GPUEngineLabelWidth#-4*#Scale#)
H=(16*#Scale#*#GPUSecondRowsShown#)
StringAlign=Right
Text=--
Hidden=1
