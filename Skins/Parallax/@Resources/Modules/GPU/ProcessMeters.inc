; Ranked GPU processes as a 3-column table in the CPU process table's style:
; Process (left) / VRAM / GPU % (icon headers, values centered under them),
; 16 px rows, a header underline and a closing divider. Rows are grouped by
; PID -- a PID appearing at more than one ranked engine instance becomes one
; row showing its busiest engine's percentage (Task Manager's own convention;
; see https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/), not
; a sum. VRAM is bound once per row from that PID's identity, never summed
; across engine rows. ProcessGraph.lua hides rows beyond the distinct PID
; count for this cycle instead of padding them with placeholder text.
; Everything here sits #GPUBarExtra# lower when the shared bar is thicker
; than 6 px, because the VRAM bar above grows in place.

[GPUStyleProcessName]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=(#ContentWidth#-#GPUProcessMemoryWidth#-#GPUProcessValueWidth#-8*#Scale#)
H=(16*#Scale#)
Text=--

[GPUStyleProcessMemory]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Center
X=(#ContentX#+#ContentWidth#-#GPUProcessValueWidth#-4*#Scale#-#GPUProcessMemoryWidth#/2)
W=#GPUProcessMemoryWidth#
H=(16*#Scale#)
Text=--

[GPUStyleProcessValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Center
X=(#ContentX#+#ContentWidth#-#GPUProcessValueWidth#/2)
W=#GPUProcessValueWidth#
H=(16*#Scale#)
Text=--

[MeterGPUProcessHeading]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(276+#GPUBarExtra#)*#Scale#)
W=(#ContentWidth#-#GPUProcessMemoryWidth#-#GPUProcessValueWidth#-8*#Scale#)
H=(16*#Scale#)
FontColor=#HeaderTextColor#
FontSize=(#HeaderFontSize#*#Scale#)
Text=Process
ToolTipText=Highest GPU usage first, from Windows GPU Engine counters across all exposed GPUs. A process using more than one engine is shown once, at its busiest engine's percentage -- matching how Task Manager reports per-process GPU%, not a sum of engines.

; Lucide "gpu" icon (the same glyph as this module's own title icon, at
; header-icon size), adapted to native Shapes rather than a bitmap.
[MeterGPUProcessMemoryHeader]
Meter=Shape
X=(#ContentX#+#ContentWidth#-#GPUProcessValueWidth#-4*#Scale#-#GPUProcessMemoryWidth#/2-7*#Scale#)
Y=(#Inset#+(277+#GPUBarExtra#)*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path GPUProcessCardBoard | Extend GPUProcessHeaderIconStroke
Shape2=Line (2*14*#Scale#/24),(21*14*#Scale#/24),(2*14*#Scale#/24),(3*14*#Scale#/24) | Extend GPUProcessHeaderIconStroke
Shape3=Path GPUProcessCardConnector | Extend GPUProcessHeaderIconStroke
Shape4=Ellipse (16*14*#Scale#/24),(11*14*#Scale#/24),(2*14*#Scale#/24),(2*14*#Scale#/24) | Extend GPUProcessHeaderIconStroke
Shape5=Ellipse (8*14*#Scale#/24),(11*14*#Scale#/24),(2*14*#Scale#/24),(2*14*#Scale#/24) | Extend GPUProcessHeaderIconStroke
GPUProcessHeaderIconStroke=Fill Color 0,0,0,0 | Stroke Color #HeaderTextColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
GPUProcessCardBoard=(2*14*#Scale#/24),(17*14*#Scale#/24) | LineTo (20*14*#Scale#/24),(17*14*#Scale#/24) | ArcTo (22*14*#Scale#/24),(15*14*#Scale#/24),(2*14*#Scale#/24),(2*14*#Scale#/24),0,1,0 | LineTo (22*14*#Scale#/24),(7*14*#Scale#/24) | ArcTo (20*14*#Scale#/24),(5*14*#Scale#/24),(2*14*#Scale#/24),(2*14*#Scale#/24),0,1,0 | LineTo (2*14*#Scale#/24),(5*14*#Scale#/24)
GPUProcessCardConnector=(7*14*#Scale#/24),(17*14*#Scale#/24) | LineTo (7*14*#Scale#/24),(20*14*#Scale#/24) | ArcTo (8*14*#Scale#/24),(21*14*#Scale#/24),(1*14*#Scale#/24),(1*14*#Scale#/24),0,1,0 | LineTo (13*14*#Scale#/24),(21*14*#Scale#/24) | ArcTo (14*14*#Scale#/24),(20*14*#Scale#/24),(1*14*#Scale#/24),(1*14*#Scale#/24),0,1,0 | LineTo (14*14*#Scale#/24),(17*14*#Scale#/24)
UpdateDivider=-1
ToolTipText=VRAM. Windows dedicated GPU memory attributed to this process on its adapter -- not summed across a process's multiple engine rows, and separate from the Shared system-memory reading above.

; Lucide gauge icon, adapted to native Shapes from the exact path data in
; @Resources/Modules/CPU/Icons/gauge.svg (this module reuses the same glyph
; at header-icon size rather than a bitmap, matching GPU's own title-icon
; convention of native Shapes over raster assets).
[MeterGPUProcessUtilHeader]
Meter=Shape
X=(#ContentX#+#ContentWidth#-#GPUProcessValueWidth#/2-7*#Scale#)
Y=(#Inset#+(277+#GPUBarExtra#)*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path GPUProcessGaugeArc | Extend GPUProcessHeaderIconStroke2
Shape2=Line (12*14*#Scale#/24),(14*14*#Scale#/24),(16*14*#Scale#/24),(10*14*#Scale#/24) | Extend GPUProcessHeaderIconStroke2
GPUProcessHeaderIconStroke2=Fill Color 0,0,0,0 | Stroke Color #HeaderTextColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
; SVG "a10 10 0 1 1" = large arc, clockwise. Rainmeter's SweepDirection is the
; reverse of SVG's sweep flag (0 = clockwise, 1 = counter-clockwise), so this
; must be 0,0,1 -- 0,1,1 draws the arc as a bowl below the needle, clipped.
GPUProcessGaugeArc=(3.34*14*#Scale#/24),(19*14*#Scale#/24) | ArcTo (20.66*14*#Scale#/24),(19*14*#Scale#/24),(10*14*#Scale#/24),(10*14*#Scale#/24),0,0,1
UpdateDivider=-1
ToolTipText=GPU %. Busiest ranked engine per process, from the top 5 process-engine instances across all exposed GPUs. Not a whole-adapter or whole-process total; a process may use additional engines outside this ranked list.

[MeterGPUProcessHeaderRule]
Meter=Shape
MeterStyle=StyleTableHeaderRule
Y=(#Inset#+(292+#GPUBarExtra#)*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)

[MeterGPUProcessName1]
Meter=String
MeterStyle=GPUStyleProcessName
Group=GPUProcessGraph|GPUProcessRow1
Y=(#Inset#+(296+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory1]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow1
Y=(#Inset#+(296+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessValue1]
Meter=String
MeterStyle=GPUStyleProcessValue
Group=GPUProcessGraph|GPUProcessRow1
Y=(#Inset#+(296+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessName2]
Meter=String
MeterStyle=GPUStyleProcessName
Group=GPUProcessGraph|GPUProcessRow2
Y=(#Inset#+(312+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory2]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow2
Y=(#Inset#+(312+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessValue2]
Meter=String
MeterStyle=GPUStyleProcessValue
Group=GPUProcessGraph|GPUProcessRow2
Y=(#Inset#+(312+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessName3]
Meter=String
MeterStyle=GPUStyleProcessName
Group=GPUProcessGraph|GPUProcessRow3
Y=(#Inset#+(328+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory3]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow3
Y=(#Inset#+(328+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessValue3]
Meter=String
MeterStyle=GPUStyleProcessValue
Group=GPUProcessGraph|GPUProcessRow3
Y=(#Inset#+(328+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessName4]
Meter=String
MeterStyle=GPUStyleProcessName
Group=GPUProcessGraph|GPUProcessRow4
Y=(#Inset#+(344+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory4]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow4
Y=(#Inset#+(344+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessValue4]
Meter=String
MeterStyle=GPUStyleProcessValue
Group=GPUProcessGraph|GPUProcessRow4
Y=(#Inset#+(344+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessName5]
Meter=String
MeterStyle=GPUStyleProcessName
Group=GPUProcessGraph|GPUProcessRow5
Y=(#Inset#+(360+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory5]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow5
Y=(#Inset#+(360+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessValue5]
Meter=String
MeterStyle=GPUStyleProcessValue
Group=GPUProcessGraph|GPUProcessRow5
Y=(#Inset#+(360+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessFooterRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(378+#GPUBarExtra#)*#Scale#)
