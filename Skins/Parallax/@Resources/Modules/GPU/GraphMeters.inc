; GPU load history in Memory Meter's style: a History header with its fixed
; range at the right, then the graph. The trace is the driver's GPU busy time
; (the header value and the Engine table's Core row), supplied by
; Temperature.lua through MeasureGPUUtilizationHistory. Height follows the
; shared #GraphHeight# variable; the panel grows to fit.

[MeterGPUHistoryLabel]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+(386+#GPUBarExtra#)*#Scale#)
W=(#ContentWidth#-60*#Scale#)
H=(18*#Scale#)
Text=History
ToolTipText=GPU busy time from the selected card's driver, newest at right. History starts over on refresh and fills one sample per update. Uncollected history is not a measurement.
UpdateDivider=-1

[MeterGPUHistoryRange]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(386+#GPUBarExtra#)*#Scale#)
W=(58*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=0 - 100%
UpdateDivider=-1

[MeterGPUUtilizationGraph]
Meter=Line
MeasureName=MeasureGPUUtilizationHistory
X=#ContentX#
Y=(#Inset#+(406+#GPUBarExtra#)*#Scale#)
W=#ContentWidth#
H=(#GraphHeight#*#Scale#)
LineCount=1
LineColor=#GPUColor#
LineWidth=#Scale#
SolidColor=#GraphBackgroundColor#
AutoScale=0
Scale=1
GraphStart=Right
GraphOrientation=Vertical
AntiAlias=1
DynamicVariables=1
UpdateDivider=1
ToolTipText=Driver GPU busy time, fixed 0-100% range. Each horizontal pixel holds one update; width, suite scale and MetricsInterval change the nominal time span. While the direct driver reading is unavailable the trace reads 0% and the header shows --. Refresh clears history.

; Native Line starts with a zero-filled ring buffer. Cover its uncollected
; left side; do not portray those zeros as observed GPU usage. Overlap by
; 2 logical pixels to cover the antialiased startup transition.
[MeterGPUGraphUncollected]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(406+#GPUBarExtra#)*#Scale#)
Shape=Rectangle 0,0,(Min(#ContentWidth#,Max(0,(#ContentWidth#-[MeasureGPUGraphSamples]+2*#Scale#)*([MeasureGPUGraphSamples]<#ContentWidth#)))),(#GraphHeight#*#Scale#) | Fill Color #GraphBackgroundColor#,255 | StrokeWidth 0
; DynamicVariables is required: without it [MeasureGPUGraphSamples] is read once
; at load (0 samples), leaving this cover at full width over the whole graph.
DynamicVariables=1
UpdateDivider=1
ToolTipText=This blank area has no collected samples yet. History fills from the right and restarts on refresh.

; Overlay guide after the startup cover so blank history still has a frame.
[MeterGPUGraphFrame]
Meter=Shape
MeterStyle=StyleGraph
Y=(#Inset#+(406+#GPUBarExtra#)*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #BorderColor# | StrokeWidth 1
