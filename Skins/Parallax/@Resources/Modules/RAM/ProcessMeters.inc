; Compact top-five process table. All positions follow the wrapped overview.
[StyleRAMProcessName]
W=(#ContentWidth#-92*#Scale#)
H=(18*#Scale#)
Group=RAMLayout | RAMProcesses
DynamicVariables=1
UpdateDivider=-1

[StyleRAMProcessValue]
X=(#ContentX#+#ContentWidth#)
W=(84*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Group=RAMLayout | RAMProcesses
DynamicVariables=1
UpdateDivider=-1

[MeterRAMProcessesHeader]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+(#RAMInfoHeight#+96+2*Max(0,#DataBarThickness#-6))*#Scale#)
W=(#ContentWidth#-52*#Scale#)
Text=Process
Group=RAMLayout
DynamicVariables=1
UpdateDivider=-1
ToolTipText=Five largest private working sets, highest first. Processes with the same name are combined. Shared pages, kernel memory and cache are excluded; rows do not add up to total used RAM.

[MeterRAMProcessesMemoryHeader]
Meter=String
MeterStyle=StyleHeader
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(#RAMInfoHeight#+96+2*Max(0,#DataBarThickness#-6))*#Scale#)
W=(44*#Scale#)
StringAlign=Right
Text=RAM
Group=RAMLayout
DynamicVariables=1
UpdateDivider=-1
ToolTipText=Private physical memory currently resident for each process group, in the selected GB or MB units.

[MeterRAMProcessesHeaderRule]
Meter=Shape
MeterStyle=StyleTableHeaderRule
Y=(#Inset#+(#RAMInfoHeight#+114+2*Max(0,#DataBarThickness#-6))*#Scale#)
Shape=Line 0,0,#ContentWidth#,0 | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
Group=RAMLayout
DynamicVariables=1
UpdateDivider=-1

[MeterRAMProcessesState]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(#RAMInfoHeight#+118+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=Waiting for process data...
W=#ContentWidth#
H=(36*#Scale#)
ClipString=2
Group=RAMLayout | RAMProcesses
DynamicVariables=1
UpdateDivider=-1
ToolTipText=Windows process counters have not supplied a ranked sample yet.

[MeterRAMProcessName1]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessName
Y=(#Inset#+(#RAMInfoHeight#+118+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessValue1]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessValue
Y=(#Inset#+(#RAMInfoHeight#+118+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessName2]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessName
Y=(#Inset#+(#RAMInfoHeight#+136+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessValue2]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessValue
Y=(#Inset#+(#RAMInfoHeight#+136+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessName3]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessName
Y=(#Inset#+(#RAMInfoHeight#+154+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessValue3]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessValue
Y=(#Inset#+(#RAMInfoHeight#+154+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessName4]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessName
Y=(#Inset#+(#RAMInfoHeight#+172+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessValue4]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessValue
Y=(#Inset#+(#RAMInfoHeight#+172+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessName5]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessName
Y=(#Inset#+(#RAMInfoHeight#+190+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1

[MeterRAMProcessValue5]
Meter=String
MeterStyle=StyleLabel | StyleRAMProcessValue
Y=(#Inset#+(#RAMInfoHeight#+190+2*Max(0,#DataBarThickness#-6))*#Scale#)
Text=
Hidden=1
