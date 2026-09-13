; Original ranked process-engine graph. Each bar uses a fixed 0-100% scale.
; The Lua controller provides validated widths; provider strings never form shapes.

[MeterGPUProcessName1]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+396*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessValue1]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+396*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessBar1]
Meter=Shape
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+414*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat
[MeterGPUProcessName2]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+428*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessValue2]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+428*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessBar2]
Meter=Shape
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+446*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat
[MeterGPUProcessName3]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+460*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessValue3]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+460*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessBar3]
Meter=Shape
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+478*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat


[MeterGPUProcessName4]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+492*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessValue4]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+492*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessBar4]
Meter=Shape
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+510*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat


[MeterGPUProcessName5]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+524*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessValue5]
Meter=String
MeterStyle=StyleLabel
Group=GPUProcessGraph
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+524*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontSize=((#FontSize#-1)*#Scale#)
Text=--

[MeterGPUProcessBar5]
Meter=Shape
Group=GPUProcessGraph
X=#ContentX#
Y=(#Inset#+542*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat
