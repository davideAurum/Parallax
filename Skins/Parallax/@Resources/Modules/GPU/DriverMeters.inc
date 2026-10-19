; Engine activity table and memory rows, fed by Temperature.lua from the direct
; driver sample. Activity domains are independent busy-time percentages and
; are never summed; dedicated VRAM and shared residency are memory amounts.
;
; The Engine table follows the CPU thread table: a header row and underline,
; then 16 px rows of label / bar / centered percentage, closed by a divider.
; Bars are Shape meters whose fill (Shape2) Lua sets as a flat-capped line of
; #DataBarThicknessPx#, centered in the row so 1-12 px bars never touch the
; neighboring rows. The memory block follows Memory Meter's RAM:/PAGE: rows:
; a label, a right-aligned reading and a full-width bar directly below, with
; later content shifted by #GPUBarExtra# for bars thicker than 6 px.

[GPUStyleEngineLabel]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#GPUEngineLabelWidth#
H=(16*#Scale#)

[GPUStyleEngineValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Center
X=(#ContentX#+#ContentWidth#-#GPUEngineValueWidth#/2)
W=#GPUEngineValueWidth#
H=(16*#Scale#)
Group=GPUDriverReadout
Text=--

[GPUStyleEngineBar]
X=#GPUEngineBarX#
W=#GPUEngineBarWidth#
H=#DataBarThicknessPx#
Group=GPUDriverReadout
Shape=Line 0,(#DataBarThicknessPx#/2),#GPUEngineBarWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUEngineHeader]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+124*#Scale#)
W=(#ContentWidth#-#GPUEngineValueWidth#-4*#Scale#)
H=(16*#Scale#)
FontColor=#HeaderTextColor#
FontSize=(#HeaderFontSize#*#Scale#)
Text=Engine

; Lucide gauge, adapted to native Shapes from @Resources/Modules/CPU/Icons/gauge.svg
; (the CPU table's own column glyph), centered over the percentage column.
[MeterGPUEngineUsageHeader]
Meter=Shape
X=(#ContentX#+#ContentWidth#-#GPUEngineValueWidth#/2-7*#Scale#)
Y=(#Inset#+125*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path GPUEngineGaugeArc | Extend GPUEngineHeaderIconStroke
Shape2=Line (12*14*#Scale#/24),(14*14*#Scale#/24),(16*14*#Scale#/24),(10*14*#Scale#/24) | Extend GPUEngineHeaderIconStroke
GPUEngineHeaderIconStroke=Fill Color 0,0,0,0 | Stroke Color #HeaderTextColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
; SVG "a10 10 0 1 1" = large arc, clockwise; Rainmeter's sweep flag is the
; reverse of SVG's, so this must be 0,0,1.
GPUEngineGaugeArc=(3.34*14*#Scale#/24),(19*14*#Scale#/24) | ArcTo (20.66*14*#Scale#/24),(19*14*#Scale#/24),(10*14*#Scale#/24),(10*14*#Scale#/24),0,0,1
UpdateDivider=-1

[MeterGPUEngineHeaderRule]
Meter=Shape
MeterStyle=StyleTableHeaderRule
Y=(#Inset#+140*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)

[MeterGPULoadLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Y=(#Inset#+144*#Scale#)
Text=Core

[MeterGPULoadBar]
Meter=Shape
MeterStyle=GPUStyleEngineBar
Y=(#Inset#+144*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))

[MeterGPULoadValue]
Meter=String
MeterStyle=GPUStyleEngineValue
Y=(#Inset#+144*#Scale#)

[MeterGPUControllerLoadLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Y=(#Inset#+160*#Scale#)
Text=Memory

[MeterGPUControllerLoadBar]
Meter=Shape
MeterStyle=GPUStyleEngineBar
Y=(#Inset#+160*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))

[MeterGPUControllerLoadValue]
Meter=String
MeterStyle=GPUStyleEngineValue
Y=(#Inset#+160*#Scale#)

[MeterGPUVideoLoadLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Y=(#Inset#+176*#Scale#)
Text=Video

[MeterGPUVideoLoadBar]
Meter=Shape
MeterStyle=GPUStyleEngineBar
Y=(#Inset#+176*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))

[MeterGPUVideoLoadValue]
Meter=String
MeterStyle=GPUStyleEngineValue
Y=(#Inset#+176*#Scale#)

[MeterGPUBusLoadLabel]
Meter=String
MeterStyle=GPUStyleEngineLabel
Y=(#Inset#+192*#Scale#)
Text=Bus

[MeterGPUBusLoadBar]
Meter=Shape
MeterStyle=GPUStyleEngineBar
Y=(#Inset#+192*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))

[MeterGPUBusLoadValue]
Meter=String
MeterStyle=GPUStyleEngineValue
Y=(#Inset#+192*#Scale#)

[MeterGPUEngineFooterRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+210*#Scale#)

[MeterGPUVRAMLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+218*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
Text=VRAM:

[MeterGPUVRAMValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+218*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=Checking...

[MeterGPUVRAMBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+(218+Max(20,23-#DataBarThickness#/2))*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUSharedLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(250+#GPUBarExtra#)*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
Text=Shared:

[MeterGPUSharedValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(250+#GPUBarExtra#)*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--
