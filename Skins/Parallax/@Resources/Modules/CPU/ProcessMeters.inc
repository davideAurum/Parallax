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
Hidden=1
Group=CPUProcessFrame|CPUUI|ParallaxIdleFreeze

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
Hidden=1
Group=CPUProcessFrame|CPUUI|ParallaxIdleFreeze

[MeterProcessHeaderRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
Hidden=1
Group=CPUProcessFrame|CPUUI|ParallaxIdleFreeze

[MeterProcessFooterRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#DividerThickness#*#Scale#)
Shape=Line 0,(#DividerThickness#*#Scale#/2),#ContentWidth#,(#DividerThickness#*#Scale#/2) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
Hidden=1
Group=CPUProcessFrame|CPUUI|ParallaxIdleFreeze

[MeterProcessesState]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+48*#Scale#)
H=(28*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Waiting for process data...
Hidden=1
Group=CPUUI|ParallaxIdleFreeze

[MeterProcessName1]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess1|CPUUI|ParallaxIdleFreeze

[MeterProcessValue1]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess1|CPUUI|ParallaxIdleFreeze

[MeterProcessName2]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess2|CPUUI|ParallaxIdleFreeze

[MeterProcessValue2]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess2|CPUUI|ParallaxIdleFreeze

[MeterProcessName3]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess3|CPUUI|ParallaxIdleFreeze

[MeterProcessValue3]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess3|CPUUI|ParallaxIdleFreeze

[MeterProcessName4]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess4|CPUUI|ParallaxIdleFreeze

[MeterProcessValue4]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess4|CPUUI|ParallaxIdleFreeze

[MeterProcessName5]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess5|CPUUI|ParallaxIdleFreeze

[MeterProcessValue5]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess5|CPUUI|ParallaxIdleFreeze

[MeterProcessName6]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess6|CPUUI|ParallaxIdleFreeze

[MeterProcessValue6]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess6|CPUUI|ParallaxIdleFreeze

[MeterProcessName7]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess7|CPUUI|ParallaxIdleFreeze

[MeterProcessValue7]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess7|CPUUI|ParallaxIdleFreeze

[MeterProcessName8]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess8|CPUUI|ParallaxIdleFreeze

[MeterProcessValue8]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess8|CPUUI|ParallaxIdleFreeze

[MeterProcessName9]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess9|CPUUI|ParallaxIdleFreeze

[MeterProcessValue9]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess9|CPUUI|ParallaxIdleFreeze

[MeterProcessName10]
Meter=String
MeterStyle=CPUStyleRowLabel
W=(#ContentWidth#-#CPUProcessUsageWidth#-4*#Scale#)
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI|ParallaxIdleFreeze

[MeterProcessValue10]
Meter=String
MeterStyle=CPUStyleRowValue
Y=(#Inset#+48*#Scale#)
Text=
Group=CPUProcess10|CPUUI|ParallaxIdleFreeze
