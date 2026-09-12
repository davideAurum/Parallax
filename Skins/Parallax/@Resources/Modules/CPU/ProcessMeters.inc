; Ranked process names, usage bars and values are shown together by CPU.lua.
[MeterProcessesHeading]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+30*#Scale#)
W=(#ContentWidth#-56*#Scale#)
H=(16*#Scale#)
FontColor=#HeaderTextColor#
FontSize=(#HeaderFontSize#*#Scale#)
Text=Process
ToolTipText=Highest CPU usage first. Processes with the same name are grouped; percentages are shares of total CPU. Idle and _Total are excluded.
Hidden=1
Group=CPUProcessFrame|CPUUI

[MeterProcessUsageHeader]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+30*#Scale#)
W=(52*#Scale#)
FontSize=(#HeaderFontSize#*#Scale#)
Text=%
ToolTipText=Process utilization as a share of total CPU; same-name instances are grouped.
Hidden=1
Group=CPUProcessFrame|CPUUI
FontColor=#HeaderTextColor#
H=(16*#Scale#)

[MeterProcessHeaderRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#DividerThickness#*#Scale#)
Shape=Line 0,(#DividerThickness#*#Scale#/2),#ContentWidth#,(#DividerThickness#*#Scale#/2) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
Hidden=1
Group=CPUProcessFrame|CPUUI

[MeterProcessFooterRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#DividerThickness#*#Scale#)
Shape=Line 0,(#DividerThickness#*#Scale#/2),#ContentWidth#,(#DividerThickness#*#Scale#/2) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
Hidden=1
Group=CPUProcessFrame|CPUUI

[MeterProcessesState]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+48*#Scale#)
H=(28*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Waiting for process data...
ToolTipText=UsageMonitor supplies no separate freshness signal. Empty rankings can mean no active samples or unavailable counters; they are not displayed as measured zero.
Hidden=1
Group=CPUUI

[MeterProcessName1]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess1|CPUUI

[MeterProcessBar1]
Meter=Bar
MeasureName=MeasureCPUProcess1
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess1|CPUUI

[MeterProcessValue1]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess1|CPUUI

[MeterProcessName2]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess2|CPUUI

[MeterProcessBar2]
Meter=Bar
MeasureName=MeasureCPUProcess2
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess2|CPUUI

[MeterProcessValue2]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess2|CPUUI

[MeterProcessName3]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess3|CPUUI

[MeterProcessBar3]
Meter=Bar
MeasureName=MeasureCPUProcess3
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess3|CPUUI

[MeterProcessValue3]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess3|CPUUI

[MeterProcessName4]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess4|CPUUI

[MeterProcessBar4]
Meter=Bar
MeasureName=MeasureCPUProcess4
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess4|CPUUI

[MeterProcessValue4]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess4|CPUUI

[MeterProcessName5]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess5|CPUUI

[MeterProcessBar5]
Meter=Bar
MeasureName=MeasureCPUProcess5
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess5|CPUUI

[MeterProcessValue5]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess5|CPUUI

[MeterProcessName6]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess6|CPUUI

[MeterProcessBar6]
Meter=Bar
MeasureName=MeasureCPUProcess6
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess6|CPUUI

[MeterProcessValue6]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess6|CPUUI

[MeterProcessName7]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess7|CPUUI

[MeterProcessBar7]
Meter=Bar
MeasureName=MeasureCPUProcess7
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess7|CPUUI

[MeterProcessValue7]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess7|CPUUI

[MeterProcessName8]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess8|CPUUI

[MeterProcessBar8]
Meter=Bar
MeasureName=MeasureCPUProcess8
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess8|CPUUI

[MeterProcessValue8]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess8|CPUUI

[MeterProcessName9]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess9|CPUUI

[MeterProcessBar9]
Meter=Bar
MeasureName=MeasureCPUProcess9
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess9|CPUUI

[MeterProcessValue9]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess9|CPUUI

[MeterProcessName10]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-92*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI

[MeterProcessBar10]
Meter=Bar
MeasureName=MeasureCPUProcess10
X=(#ContentX#+#ContentWidth#-88*#Scale#)
Y=(#Inset#+55*#Scale#)
W=(32*#Scale#)
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#CPUColor#
SolidColor=#TrackColor#
Hidden=1
Group=CPUProcess10|CPUUI

[MeterProcessValue10]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI
