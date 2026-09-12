[MeasureIO]
Measure=Script
ScriptFile=#@#Modules\IO\IO.lua
DiskProvider=#IODiskProvider#

; Dense instrument styles. Every actual meter declares Meter explicitly.
[StyleIOText]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontColor=#TextColor#
StringStyle=Normal
FontWeight=500
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleIOSecondary]
FontFace=#FontFace#
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#
FontWeight=500
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(16*#Scale#)

[StyleIOHeader]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontColor=#HeaderTextColor#
FontWeight=600
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleIOBar]
X=#ContentX#
W=#ContentWidth#
H=(Max(1,#Scale#))
BarOrientation=Horizontal
BarColor=#DiskReadColor#
SolidColor=#TrackColor#
Hidden=1

[StyleIOGlyph]
X=#ContentX#
W=(16*#Scale#)
H=(16*#Scale#)
UpdateDivider=-1

[MeterIOBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterIOPanel]
Meter=Shape
MeterStyle=StylePanel

; Original drive outline: front slot and indicator, no imported image asset.
[MeterIOIcon]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=(#Inset#+5*#Scale#)
W=(16*#Scale#)
H=(16*#Scale#)
Shape=Rectangle (1*#Scale#),(3*#Scale#),(12*#Scale#),(9*#Scale#),(1*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (Max(1,#Scale#))
Shape2=Line (2*#Scale#),(7*#Scale#),(12*#Scale#),(7*#Scale#) | Stroke Color #MutedColor# | StrokeWidth (Max(1,#Scale#))
Shape3=Ellipse (10*#Scale#),(10*#Scale#),(1*#Scale#),(1*#Scale#) | Fill Color #DiskReadColor# | StrokeWidth 0
UpdateDivider=-1

[MeterIOTitle]
Meter=String
MeterStyle=StyleTitle
X=(#ContentX#+19*#Scale#)
Y=(#Inset#+2*#Scale#)
W=(#ContentWidth#-71*#Scale#)
H=(22*#Scale#)
Text=Drive I/O

[MeterIOTotal]
Meter=String
MeterStyle=StyleTitle
; This is live capacity data, independent of title typography.
FontSize=(#FontSize#*#Scale#)
FontColor=#TextColor#
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+4*#Scale#)
W=(48*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--
ToolTipText=Main drive used percentage. Unavailable until native capacity is valid.

[MeterIOOptions]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
; Original eight-tooth gear; hidden meters have no mouse hit target.
Shape=Path GearPath | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Ellipse (9*#Scale#),(9*#Scale#),(2.5*#Scale#),(2.5*#Scale#) | Fill Color #BackgroundColor# | StrokeWidth 0
GearPath=(9.000*#Scale#),(3.300*#Scale#) | LineTo (10.444*#Scale#),(1.742*#Scale#) | LineTo (11.832*#Scale#),(2.163*#Scale#) | LineTo (12.167*#Scale#),(4.261*#Scale#) | LineTo (13.031*#Scale#),(4.969*#Scale#) | LineTo (15.153*#Scale#),(4.889*#Scale#) | LineTo (15.837*#Scale#),(6.168*#Scale#) | LineTo (14.590*#Scale#),(7.888*#Scale#) | LineTo (14.700*#Scale#),(9.000*#Scale#) | LineTo (16.258*#Scale#),(10.444*#Scale#) | LineTo (15.837*#Scale#),(11.832*#Scale#) | LineTo (13.739*#Scale#),(12.167*#Scale#) | LineTo (13.031*#Scale#),(13.031*#Scale#) | LineTo (13.111*#Scale#),(15.153*#Scale#) | LineTo (11.832*#Scale#),(15.837*#Scale#) | LineTo (10.112*#Scale#),(14.590*#Scale#) | LineTo (9.000*#Scale#),(14.700*#Scale#) | LineTo (7.556*#Scale#),(16.258*#Scale#) | LineTo (6.168*#Scale#),(15.837*#Scale#) | LineTo (5.833*#Scale#),(13.739*#Scale#) | LineTo (4.969*#Scale#),(13.031*#Scale#) | LineTo (2.847*#Scale#),(13.111*#Scale#) | LineTo (2.163*#Scale#),(11.832*#Scale#) | LineTo (3.410*#Scale#),(10.112*#Scale#) | LineTo (3.300*#Scale#),(9.000*#Scale#) | LineTo (1.742*#Scale#),(7.556*#Scale#) | LineTo (2.163*#Scale#),(6.168*#Scale#) | LineTo (4.261*#Scale#),(5.833*#Scale#) | LineTo (4.969*#Scale#),(4.969*#Scale#) | LineTo (4.889*#Scale#),(2.847*#Scale#) | LineTo (6.168*#Scale#),(2.163*#Scale#) | LineTo (7.888*#Scale#),(3.410*#Scale#) | ClosePath 1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\IO\Settings" "Settings.ini"]
ToolTipText=Open the separate Drive I/O settings utility.


[MeterIOCapacityHeading]
Meter=String
MeterStyle=StyleIOHeader
Y=(#Inset#+24*#Scale#)
Text=Capacity: free / total
ToolTipText=Native capacity. Bars show used percentage.

[MeterIODrive1]
Meter=String
MeterStyle=StyleIOText
Y=(#Inset#+42*#Scale#)
W=(24*#Scale#)
Text=C:
ToolTipText=#IODrive1#

[MeterIOCapacity1]
Meter=String
MeterStyle=StyleIOText
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+42*#Scale#)
W=(#ContentWidth#-26*#Scale#)
StringAlign=Right
Text=Unavailable

[MeterIOUsed1]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsed1
Y=(#Inset#+60*#Scale#)

[MeterIODrive2]
Meter=String
MeterStyle=StyleIOText
Y=(#Inset#+62*#Scale#)
W=(24*#Scale#)
Text=D:
ToolTipText=#IODrive2#

[MeterIOCapacity2]
Meter=String
MeterStyle=StyleIOText
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+62*#Scale#)
W=(#ContentWidth#-26*#Scale#)
StringAlign=Right
Text=Off

[MeterIOUsed2]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsed2
Y=(#Inset#+80*#Scale#)

[MeterIODiskHeading]
Meter=String
MeterStyle=StyleIOHeader
Y=(#Inset#+83*#Scale#)
Text=Disk transfers
ToolTipText=Transfer counter scope is independent of the capacity drives.

[MeterIODiskStatus]
Meter=String
MeterStyle=StyleIOSecondary
Y=(#Inset#+101*#Scale#)
Text=Counters off

; Original chevrons mirror the read/up and write/down instrument convention.
[MeterIODiskReadLabel]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=(#Inset#+120*#Scale#)
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
ToolTipText=Disk read rate
UpdateDivider=-1

[MeterIODiskWriteLabel]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#+8*#Scale#)/2)
Y=(#Inset#+120*#Scale#)
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
ToolTipText=Disk write rate
UpdateDivider=-1

[MeterIODiskRead]
Meter=String
MeterStyle=StyleIOText
X=(#ContentX#+11*#Scale#)
Y=(#Inset#+118*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2-11*#Scale#)
H=(18*#Scale#)
FontColor=#TextColor#
Text=--

[MeterIODiskWrite]
Meter=String
MeterStyle=StyleIOText
X=(#ContentX#+(#ContentWidth#+8*#Scale#)/2+11*#Scale#)
Y=(#Inset#+118*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2-11*#Scale#)
H=(18*#Scale#)
FontColor=#TextColor#
Text=--

; The native-only variant binds zero internally and keeps both bars hidden.
[MeasureIODiskReadBar]
Measure=Calc
Formula=#IODiskReadSource#
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))

[MeasureIODiskWriteBar]
Measure=Calc
Formula=#IODiskWriteSource#
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))

[MeterIODiskReadBar]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIODiskReadBar
Y=(#Inset#+136*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2)

[MeterIODiskWriteBar]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIODiskWriteBar
X=(#ContentX#+(#ContentWidth#+8*#Scale#)/2)
Y=(#Inset#+136*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2)
BarColor=#DiskWriteColor#

[MeterIODiskScale]
Meter=String
MeterStyle=StyleIOSecondary
Y=(#Inset#+137*#Scale#)
Text=Native capacity only

[MeterIOToggle]
Meter=String
MeterStyle=StyleIOText
Y=(#Inset#+154*#Scale#)
H=(18*#Scale#)
FontColor=#AccentColor#
MouseActionCursor=1
Text=Enable counters
LeftMouseUpAction=[!ActivateConfig "Parallax\IO" "IO-Disk.ini"]
ToolTipText=Load the optional disk counter variant.
