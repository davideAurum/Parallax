; GPU utilization history -- one tracing for now. This graphs the same
; "busiest ranked process-engine" figure already shown as the panel's
; headline Activity value and as row 1 of the process table above (see
; MeasureGPUActivity's own comments in Measures.inc). It is deliberately
; NOT a true whole-adapter/rollup total: UsageMonitor's GPU Engine category
; only exposes per-engine-instance counters, and summing them risks
; double-counting shared engines, so no single honest "overall GPU %"
; exists here beyond the busiest ranked instance. Height follows the
; shared #GraphHeight# suite variable -- override it in User/GPU.inc to
; give this graph more or less room; the panel grows to fit.

[MeterGPUGraphHeading]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+522*#Scale#)
H=(16*#Scale#)
Text=GPU utilization
ToolTipText=Traces the same busiest-ranked-process-engine figure shown above (the panel's headline % and the process table's top row), not a true whole-adapter total. UsageMonitor's GPU Engine counters cannot be honestly summed into one adapter-wide percentage without risking double-counting shared engines.

[MeterGPUGraphRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+538*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
UpdateDivider=-1

[MeterGPUUtilizationGraph]
Meter=Line
MeasureName=MeasureGPUUtilizationHistory
X=#ContentX#
Y=(#Inset#+546*#Scale#)
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
ToolTipText=GPU utilization history, fixed 0-100% range. Each horizontal pixel holds one update; width, suite scale and MetricsInterval change the nominal time span. Traces the busiest ranked process-engine instance (see the heading above) -- idle and "no counter available" both read as 0% and cannot be told apart here. Refresh clears history.

; Native Line starts with a zero-filled ring buffer. Cover its uncollected
; left side; do not portray those zeros as observed GPU usage. Overlap by
; 2 logical pixels to cover the antialiased startup transition.
[MeterGPUGraphUncollected]
Meter=Shape
X=#ContentX#
Y=(#Inset#+546*#Scale#)
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
Y=(#Inset#+546*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #BorderColor# | StrokeWidth 1
