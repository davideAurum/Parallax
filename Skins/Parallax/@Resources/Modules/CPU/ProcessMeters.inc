; Ranked process names and usage percentages are shown together by CPU.lua.
[MeterProcessesHeading]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+30*#Scale#)
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
H=(16*#Scale#)
FontColor=#HeaderTextColor#
FontSize=(#HeaderFontSize#*#Scale#)
Text=Process
ToolTipText=Highest CPU usage first. Processes with the same name are grouped; percentages are shares of total CPU. Idle and _Total are excluded.
Hidden=1
Group=CPUProcessFrame|CPUUI

[MeterProcessUsageHeader]
Meter=Image
; Center the Lucide Gauge over the same field used by process values.
X=(#ContentX#+#ContentWidth#-#CPUProcessUsageWidth#/2-7*#Scale#)
Y=(#Inset#+31*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
; Official Lucide Gauge artwork, shared with the CPU utilization column.
ImageName=#@#Modules\CPU\Icons\gauge.png
Greyscale=1
ImageTint=#HeaderTextColor#,255
ToolTipText=Gauge symbol: Process utilization as a share of total CPU; same-name instances are grouped.
Hidden=1
Group=CPUProcessFrame|CPUUI

[MeterProcessHeaderRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
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
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI

[MeterProcessValue10]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI
