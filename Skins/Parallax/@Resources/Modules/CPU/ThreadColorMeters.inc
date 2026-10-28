; Static bounded slots. ThreadColors.lua arranges and shows only detected logical threads.

[MeterThreadColorLabel1]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor1|CPUThreadColorsUI
Text=Thread 1
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(1)"]
MouseActionCursor=1
[MeterThreadColorValue1]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor1|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(1)"]
MouseActionCursor=1
[MeterThreadColorSwatch1]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor1|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor1','MeterThreadColorSwatch1')"]
MouseActionCursor=1

[MeterThreadColorLabel2]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor2|CPUThreadColorsUI
Text=Thread 2
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(2)"]
MouseActionCursor=1

[MeterThreadColorValue2]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor2|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(2)"]
MouseActionCursor=1

[MeterThreadColorSwatch2]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor2|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor2','MeterThreadColorSwatch2')"]
MouseActionCursor=1

[MeterThreadColorLabel3]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor3|CPUThreadColorsUI
Text=Thread 3
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(3)"]
MouseActionCursor=1

[MeterThreadColorValue3]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor3|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(3)"]
MouseActionCursor=1

[MeterThreadColorSwatch3]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor3|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor3','MeterThreadColorSwatch3')"]
MouseActionCursor=1

[MeterThreadColorLabel4]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor4|CPUThreadColorsUI
Text=Thread 4
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(4)"]
MouseActionCursor=1

[MeterThreadColorValue4]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor4|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(4)"]
MouseActionCursor=1

[MeterThreadColorSwatch4]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor4|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor4','MeterThreadColorSwatch4')"]
MouseActionCursor=1

[MeterThreadColorLabel5]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor5|CPUThreadColorsUI
Text=Thread 5
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(5)"]
MouseActionCursor=1

[MeterThreadColorValue5]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor5|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(5)"]
MouseActionCursor=1

[MeterThreadColorSwatch5]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor5|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor5','MeterThreadColorSwatch5')"]
MouseActionCursor=1

[MeterThreadColorLabel6]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor6|CPUThreadColorsUI
Text=Thread 6
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(6)"]
MouseActionCursor=1

[MeterThreadColorValue6]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor6|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(6)"]
MouseActionCursor=1

[MeterThreadColorSwatch6]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor6|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor6','MeterThreadColorSwatch6')"]
MouseActionCursor=1

[MeterThreadColorLabel7]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor7|CPUThreadColorsUI
Text=Thread 7
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(7)"]
MouseActionCursor=1

[MeterThreadColorValue7]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor7|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(7)"]
MouseActionCursor=1

[MeterThreadColorSwatch7]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor7|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor7','MeterThreadColorSwatch7')"]
MouseActionCursor=1

[MeterThreadColorLabel8]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor8|CPUThreadColorsUI
Text=Thread 8
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(8)"]
MouseActionCursor=1

[MeterThreadColorValue8]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor8|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(8)"]
MouseActionCursor=1

[MeterThreadColorSwatch8]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor8|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor8','MeterThreadColorSwatch8')"]
MouseActionCursor=1

[MeterThreadColorLabel9]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor9|CPUThreadColorsUI
Text=Thread 9
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(9)"]
MouseActionCursor=1

[MeterThreadColorValue9]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor9|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(9)"]
MouseActionCursor=1

[MeterThreadColorSwatch9]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor9|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor9','MeterThreadColorSwatch9')"]
MouseActionCursor=1

[MeterThreadColorLabel10]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor10|CPUThreadColorsUI
Text=Thread 10
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(10)"]
MouseActionCursor=1

[MeterThreadColorValue10]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor10|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(10)"]
MouseActionCursor=1

[MeterThreadColorSwatch10]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor10|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor10','MeterThreadColorSwatch10')"]
MouseActionCursor=1

[MeterThreadColorLabel11]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor11|CPUThreadColorsUI
Text=Thread 11
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(11)"]
MouseActionCursor=1

[MeterThreadColorValue11]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor11|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(11)"]
MouseActionCursor=1

[MeterThreadColorSwatch11]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor11|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor11','MeterThreadColorSwatch11')"]
MouseActionCursor=1

[MeterThreadColorLabel12]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor12|CPUThreadColorsUI
Text=Thread 12
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(12)"]
MouseActionCursor=1

[MeterThreadColorValue12]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor12|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(12)"]
MouseActionCursor=1

[MeterThreadColorSwatch12]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor12|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor12','MeterThreadColorSwatch12')"]
MouseActionCursor=1

[MeterThreadColorLabel13]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor13|CPUThreadColorsUI
Text=Thread 13
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(13)"]
MouseActionCursor=1

[MeterThreadColorValue13]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor13|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(13)"]
MouseActionCursor=1

[MeterThreadColorSwatch13]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor13|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor13','MeterThreadColorSwatch13')"]
MouseActionCursor=1

[MeterThreadColorLabel14]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor14|CPUThreadColorsUI
Text=Thread 14
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(14)"]
MouseActionCursor=1

[MeterThreadColorValue14]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor14|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(14)"]
MouseActionCursor=1

[MeterThreadColorSwatch14]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor14|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor14','MeterThreadColorSwatch14')"]
MouseActionCursor=1

[MeterThreadColorLabel15]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor15|CPUThreadColorsUI
Text=Thread 15
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(15)"]
MouseActionCursor=1

[MeterThreadColorValue15]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor15|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(15)"]
MouseActionCursor=1

[MeterThreadColorSwatch15]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor15|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor15','MeterThreadColorSwatch15')"]
MouseActionCursor=1

[MeterThreadColorLabel16]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor16|CPUThreadColorsUI
Text=Thread 16
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(16)"]
MouseActionCursor=1

[MeterThreadColorValue16]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor16|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(16)"]
MouseActionCursor=1

[MeterThreadColorSwatch16]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor16|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor16','MeterThreadColorSwatch16')"]
MouseActionCursor=1

[MeterThreadColorLabel17]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor17|CPUThreadColorsUI
Text=Thread 17
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(17)"]
MouseActionCursor=1

[MeterThreadColorValue17]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor17|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(17)"]
MouseActionCursor=1

[MeterThreadColorSwatch17]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor17|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor17','MeterThreadColorSwatch17')"]
MouseActionCursor=1

[MeterThreadColorLabel18]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor18|CPUThreadColorsUI
Text=Thread 18
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(18)"]
MouseActionCursor=1

[MeterThreadColorValue18]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor18|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(18)"]
MouseActionCursor=1

[MeterThreadColorSwatch18]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor18|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor18','MeterThreadColorSwatch18')"]
MouseActionCursor=1

[MeterThreadColorLabel19]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor19|CPUThreadColorsUI
Text=Thread 19
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(19)"]
MouseActionCursor=1

[MeterThreadColorValue19]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor19|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(19)"]
MouseActionCursor=1

[MeterThreadColorSwatch19]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor19|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor19','MeterThreadColorSwatch19')"]
MouseActionCursor=1

[MeterThreadColorLabel20]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor20|CPUThreadColorsUI
Text=Thread 20
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(20)"]
MouseActionCursor=1

[MeterThreadColorValue20]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor20|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(20)"]
MouseActionCursor=1

[MeterThreadColorSwatch20]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor20|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor20','MeterThreadColorSwatch20')"]
MouseActionCursor=1

[MeterThreadColorLabel21]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor21|CPUThreadColorsUI
Text=Thread 21
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(21)"]
MouseActionCursor=1

[MeterThreadColorValue21]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor21|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(21)"]
MouseActionCursor=1

[MeterThreadColorSwatch21]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor21|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor21','MeterThreadColorSwatch21')"]
MouseActionCursor=1

[MeterThreadColorLabel22]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor22|CPUThreadColorsUI
Text=Thread 22
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(22)"]
MouseActionCursor=1

[MeterThreadColorValue22]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor22|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(22)"]
MouseActionCursor=1

[MeterThreadColorSwatch22]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor22|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor22','MeterThreadColorSwatch22')"]
MouseActionCursor=1

[MeterThreadColorLabel23]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor23|CPUThreadColorsUI
Text=Thread 23
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(23)"]
MouseActionCursor=1

[MeterThreadColorValue23]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor23|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(23)"]
MouseActionCursor=1

[MeterThreadColorSwatch23]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor23|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor23','MeterThreadColorSwatch23')"]
MouseActionCursor=1

[MeterThreadColorLabel24]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor24|CPUThreadColorsUI
Text=Thread 24
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(24)"]
MouseActionCursor=1

[MeterThreadColorValue24]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor24|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(24)"]
MouseActionCursor=1

[MeterThreadColorSwatch24]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor24|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor24','MeterThreadColorSwatch24')"]
MouseActionCursor=1

[MeterThreadColorLabel25]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor25|CPUThreadColorsUI
Text=Thread 25
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(25)"]
MouseActionCursor=1

[MeterThreadColorValue25]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor25|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(25)"]
MouseActionCursor=1

[MeterThreadColorSwatch25]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor25|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor25','MeterThreadColorSwatch25')"]
MouseActionCursor=1

[MeterThreadColorLabel26]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor26|CPUThreadColorsUI
Text=Thread 26
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(26)"]
MouseActionCursor=1

[MeterThreadColorValue26]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor26|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(26)"]
MouseActionCursor=1

[MeterThreadColorSwatch26]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor26|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor26','MeterThreadColorSwatch26')"]
MouseActionCursor=1

[MeterThreadColorLabel27]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor27|CPUThreadColorsUI
Text=Thread 27
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(27)"]
MouseActionCursor=1

[MeterThreadColorValue27]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor27|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(27)"]
MouseActionCursor=1

[MeterThreadColorSwatch27]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor27|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor27','MeterThreadColorSwatch27')"]
MouseActionCursor=1

[MeterThreadColorLabel28]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor28|CPUThreadColorsUI
Text=Thread 28
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(28)"]
MouseActionCursor=1

[MeterThreadColorValue28]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor28|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(28)"]
MouseActionCursor=1

[MeterThreadColorSwatch28]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor28|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor28','MeterThreadColorSwatch28')"]
MouseActionCursor=1

[MeterThreadColorLabel29]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor29|CPUThreadColorsUI
Text=Thread 29
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(29)"]
MouseActionCursor=1

[MeterThreadColorValue29]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor29|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(29)"]
MouseActionCursor=1

[MeterThreadColorSwatch29]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor29|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor29','MeterThreadColorSwatch29')"]
MouseActionCursor=1

[MeterThreadColorLabel30]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor30|CPUThreadColorsUI
Text=Thread 30
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(30)"]
MouseActionCursor=1

[MeterThreadColorValue30]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor30|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(30)"]
MouseActionCursor=1

[MeterThreadColorSwatch30]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor30|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor30','MeterThreadColorSwatch30')"]
MouseActionCursor=1

[MeterThreadColorLabel31]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor31|CPUThreadColorsUI
Text=Thread 31
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(31)"]
MouseActionCursor=1

[MeterThreadColorValue31]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor31|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(31)"]
MouseActionCursor=1

[MeterThreadColorSwatch31]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor31|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor31','MeterThreadColorSwatch31')"]
MouseActionCursor=1

[MeterThreadColorLabel32]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor32|CPUThreadColorsUI
Text=Thread 32
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(32)"]
MouseActionCursor=1

[MeterThreadColorValue32]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor32|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(32)"]
MouseActionCursor=1

[MeterThreadColorSwatch32]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor32|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor32','MeterThreadColorSwatch32')"]
MouseActionCursor=1

[MeterThreadColorLabel33]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor33|CPUThreadColorsUI
Text=Thread 33
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(33)"]
MouseActionCursor=1

[MeterThreadColorValue33]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor33|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(33)"]
MouseActionCursor=1

[MeterThreadColorSwatch33]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor33|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor33','MeterThreadColorSwatch33')"]
MouseActionCursor=1

[MeterThreadColorLabel34]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor34|CPUThreadColorsUI
Text=Thread 34
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(34)"]
MouseActionCursor=1

[MeterThreadColorValue34]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor34|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(34)"]
MouseActionCursor=1

[MeterThreadColorSwatch34]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor34|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor34','MeterThreadColorSwatch34')"]
MouseActionCursor=1

[MeterThreadColorLabel35]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor35|CPUThreadColorsUI
Text=Thread 35
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(35)"]
MouseActionCursor=1

[MeterThreadColorValue35]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor35|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(35)"]
MouseActionCursor=1

[MeterThreadColorSwatch35]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor35|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor35','MeterThreadColorSwatch35')"]
MouseActionCursor=1

[MeterThreadColorLabel36]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor36|CPUThreadColorsUI
Text=Thread 36
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(36)"]
MouseActionCursor=1

[MeterThreadColorValue36]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor36|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(36)"]
MouseActionCursor=1

[MeterThreadColorSwatch36]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor36|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor36','MeterThreadColorSwatch36')"]
MouseActionCursor=1

[MeterThreadColorLabel37]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor37|CPUThreadColorsUI
Text=Thread 37
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(37)"]
MouseActionCursor=1

[MeterThreadColorValue37]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor37|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(37)"]
MouseActionCursor=1

[MeterThreadColorSwatch37]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor37|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor37','MeterThreadColorSwatch37')"]
MouseActionCursor=1

[MeterThreadColorLabel38]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor38|CPUThreadColorsUI
Text=Thread 38
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(38)"]
MouseActionCursor=1

[MeterThreadColorValue38]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor38|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(38)"]
MouseActionCursor=1

[MeterThreadColorSwatch38]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor38|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor38','MeterThreadColorSwatch38')"]
MouseActionCursor=1

[MeterThreadColorLabel39]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor39|CPUThreadColorsUI
Text=Thread 39
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(39)"]
MouseActionCursor=1

[MeterThreadColorValue39]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor39|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(39)"]
MouseActionCursor=1

[MeterThreadColorSwatch39]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor39|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor39','MeterThreadColorSwatch39')"]
MouseActionCursor=1

[MeterThreadColorLabel40]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor40|CPUThreadColorsUI
Text=Thread 40
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(40)"]
MouseActionCursor=1

[MeterThreadColorValue40]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor40|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(40)"]
MouseActionCursor=1

[MeterThreadColorSwatch40]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor40|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor40','MeterThreadColorSwatch40')"]
MouseActionCursor=1

[MeterThreadColorLabel41]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor41|CPUThreadColorsUI
Text=Thread 41
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(41)"]
MouseActionCursor=1

[MeterThreadColorValue41]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor41|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(41)"]
MouseActionCursor=1

[MeterThreadColorSwatch41]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor41|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor41','MeterThreadColorSwatch41')"]
MouseActionCursor=1

[MeterThreadColorLabel42]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor42|CPUThreadColorsUI
Text=Thread 42
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(42)"]
MouseActionCursor=1

[MeterThreadColorValue42]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor42|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(42)"]
MouseActionCursor=1

[MeterThreadColorSwatch42]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor42|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor42','MeterThreadColorSwatch42')"]
MouseActionCursor=1

[MeterThreadColorLabel43]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor43|CPUThreadColorsUI
Text=Thread 43
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(43)"]
MouseActionCursor=1

[MeterThreadColorValue43]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor43|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(43)"]
MouseActionCursor=1

[MeterThreadColorSwatch43]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor43|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor43','MeterThreadColorSwatch43')"]
MouseActionCursor=1

[MeterThreadColorLabel44]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor44|CPUThreadColorsUI
Text=Thread 44
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(44)"]
MouseActionCursor=1

[MeterThreadColorValue44]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor44|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(44)"]
MouseActionCursor=1

[MeterThreadColorSwatch44]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor44|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor44','MeterThreadColorSwatch44')"]
MouseActionCursor=1

[MeterThreadColorLabel45]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor45|CPUThreadColorsUI
Text=Thread 45
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(45)"]
MouseActionCursor=1

[MeterThreadColorValue45]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor45|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(45)"]
MouseActionCursor=1

[MeterThreadColorSwatch45]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor45|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor45','MeterThreadColorSwatch45')"]
MouseActionCursor=1

[MeterThreadColorLabel46]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor46|CPUThreadColorsUI
Text=Thread 46
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(46)"]
MouseActionCursor=1

[MeterThreadColorValue46]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor46|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(46)"]
MouseActionCursor=1

[MeterThreadColorSwatch46]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor46|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor46','MeterThreadColorSwatch46')"]
MouseActionCursor=1

[MeterThreadColorLabel47]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor47|CPUThreadColorsUI
Text=Thread 47
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(47)"]
MouseActionCursor=1

[MeterThreadColorValue47]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor47|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(47)"]
MouseActionCursor=1

[MeterThreadColorSwatch47]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor47|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor47','MeterThreadColorSwatch47')"]
MouseActionCursor=1

[MeterThreadColorLabel48]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor48|CPUThreadColorsUI
Text=Thread 48
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(48)"]
MouseActionCursor=1

[MeterThreadColorValue48]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor48|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(48)"]
MouseActionCursor=1

[MeterThreadColorSwatch48]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor48|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor48','MeterThreadColorSwatch48')"]
MouseActionCursor=1

[MeterThreadColorLabel49]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor49|CPUThreadColorsUI
Text=Thread 49
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(49)"]
MouseActionCursor=1

[MeterThreadColorValue49]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor49|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(49)"]
MouseActionCursor=1

[MeterThreadColorSwatch49]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor49|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor49','MeterThreadColorSwatch49')"]
MouseActionCursor=1

[MeterThreadColorLabel50]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor50|CPUThreadColorsUI
Text=Thread 50
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(50)"]
MouseActionCursor=1

[MeterThreadColorValue50]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor50|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(50)"]
MouseActionCursor=1

[MeterThreadColorSwatch50]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor50|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor50','MeterThreadColorSwatch50')"]
MouseActionCursor=1

[MeterThreadColorLabel51]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor51|CPUThreadColorsUI
Text=Thread 51
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(51)"]
MouseActionCursor=1

[MeterThreadColorValue51]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor51|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(51)"]
MouseActionCursor=1

[MeterThreadColorSwatch51]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor51|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor51','MeterThreadColorSwatch51')"]
MouseActionCursor=1

[MeterThreadColorLabel52]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor52|CPUThreadColorsUI
Text=Thread 52
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(52)"]
MouseActionCursor=1

[MeterThreadColorValue52]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor52|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(52)"]
MouseActionCursor=1

[MeterThreadColorSwatch52]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor52|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor52','MeterThreadColorSwatch52')"]
MouseActionCursor=1

[MeterThreadColorLabel53]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor53|CPUThreadColorsUI
Text=Thread 53
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(53)"]
MouseActionCursor=1

[MeterThreadColorValue53]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor53|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(53)"]
MouseActionCursor=1

[MeterThreadColorSwatch53]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor53|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor53','MeterThreadColorSwatch53')"]
MouseActionCursor=1

[MeterThreadColorLabel54]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor54|CPUThreadColorsUI
Text=Thread 54
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(54)"]
MouseActionCursor=1

[MeterThreadColorValue54]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor54|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(54)"]
MouseActionCursor=1

[MeterThreadColorSwatch54]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor54|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor54','MeterThreadColorSwatch54')"]
MouseActionCursor=1

[MeterThreadColorLabel55]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor55|CPUThreadColorsUI
Text=Thread 55
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(55)"]
MouseActionCursor=1

[MeterThreadColorValue55]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor55|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(55)"]
MouseActionCursor=1

[MeterThreadColorSwatch55]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor55|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor55','MeterThreadColorSwatch55')"]
MouseActionCursor=1

[MeterThreadColorLabel56]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor56|CPUThreadColorsUI
Text=Thread 56
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(56)"]
MouseActionCursor=1

[MeterThreadColorValue56]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor56|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(56)"]
MouseActionCursor=1

[MeterThreadColorSwatch56]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor56|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor56','MeterThreadColorSwatch56')"]
MouseActionCursor=1

[MeterThreadColorLabel57]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor57|CPUThreadColorsUI
Text=Thread 57
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(57)"]
MouseActionCursor=1

[MeterThreadColorValue57]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor57|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(57)"]
MouseActionCursor=1

[MeterThreadColorSwatch57]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor57|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor57','MeterThreadColorSwatch57')"]
MouseActionCursor=1

[MeterThreadColorLabel58]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor58|CPUThreadColorsUI
Text=Thread 58
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(58)"]
MouseActionCursor=1

[MeterThreadColorValue58]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor58|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(58)"]
MouseActionCursor=1

[MeterThreadColorSwatch58]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor58|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor58','MeterThreadColorSwatch58')"]
MouseActionCursor=1

[MeterThreadColorLabel59]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor59|CPUThreadColorsUI
Text=Thread 59
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(59)"]
MouseActionCursor=1

[MeterThreadColorValue59]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor59|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(59)"]
MouseActionCursor=1

[MeterThreadColorSwatch59]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor59|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor59','MeterThreadColorSwatch59')"]
MouseActionCursor=1

[MeterThreadColorLabel60]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor60|CPUThreadColorsUI
Text=Thread 60
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(60)"]
MouseActionCursor=1

[MeterThreadColorValue60]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor60|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(60)"]
MouseActionCursor=1

[MeterThreadColorSwatch60]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor60|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor60','MeterThreadColorSwatch60')"]
MouseActionCursor=1

[MeterThreadColorLabel61]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor61|CPUThreadColorsUI
Text=Thread 61
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(61)"]
MouseActionCursor=1

[MeterThreadColorValue61]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor61|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(61)"]
MouseActionCursor=1

[MeterThreadColorSwatch61]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor61|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor61','MeterThreadColorSwatch61')"]
MouseActionCursor=1

[MeterThreadColorLabel62]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor62|CPUThreadColorsUI
Text=Thread 62
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(62)"]
MouseActionCursor=1

[MeterThreadColorValue62]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor62|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(62)"]
MouseActionCursor=1

[MeterThreadColorSwatch62]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor62|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor62','MeterThreadColorSwatch62')"]
MouseActionCursor=1

[MeterThreadColorLabel63]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor63|CPUThreadColorsUI
Text=Thread 63
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(63)"]
MouseActionCursor=1

[MeterThreadColorValue63]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor63|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(63)"]
MouseActionCursor=1

[MeterThreadColorSwatch63]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor63|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor63','MeterThreadColorSwatch63')"]
MouseActionCursor=1

[MeterThreadColorLabel64]
Meter=String
MeterStyle=StyleLabel
X=0
Y=0
W=(54*#Scale#)
H=(18*#Scale#)
Hidden=1
Group=CPUThreadColor64|CPUThreadColorsUI
Text=Thread 64
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(64)"]
MouseActionCursor=1
[MeterThreadColorValue64]
Meter=String
MeterStyle=StyleButton
FontColor=#TextColor#
SolidColor=#GraphBackgroundColor#
StringAlign=Left
X=0
Y=0
W=(88*#Scale#)
H=(20*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
Hidden=1
Group=CPUThreadColor64|CPUThreadColorsUI
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureCPUThreadColors "BeginEdit(64)"]
MouseActionCursor=1

[MeterThreadColorSwatch64]
Meter=Shape
X=0
Y=0
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #CPUColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Hidden=1
Group=CPUThreadColor64|CPUThreadColorsUI
LeftMouseUpAction=[!CommandMeasure MeasureColorLauncher "Open('CPUThreadColor64','MeterThreadColorSwatch64')"]
MouseActionCursor=1
