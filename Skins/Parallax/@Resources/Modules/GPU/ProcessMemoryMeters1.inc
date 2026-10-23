; GPUShowProcessMemory=1: the process table's VRAM column, a centered
; column between the name and GPU % columns under the Lucide "gpu" glyph.
; ProcessMeters1.inc includes this file only in that state
; (ProcessMemoryMeters0.inc otherwise). VRAM is bound once per row from
; that PID's identity, never summed across engine rows.

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

[MeterGPUProcessMemory1]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow1|ParallaxIdleFreeze
Y=(#Inset#+(296+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory2]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow2|ParallaxIdleFreeze
Y=(#Inset#+(312+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory3]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow3|ParallaxIdleFreeze
Y=(#Inset#+(328+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory4]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow4|ParallaxIdleFreeze
Y=(#Inset#+(344+#GPUBarExtra#)*#Scale#)

[MeterGPUProcessMemory5]
Meter=String
MeterStyle=GPUStyleProcessMemory
Group=GPUProcessGraph|GPUProcessRow5|ParallaxIdleFreeze
Y=(#Inset#+(360+#GPUBarExtra#)*#Scale#)
