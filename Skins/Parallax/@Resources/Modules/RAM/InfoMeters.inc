; Compact static inventory block, styled like the CPU/GPU hardware inset.
[StyleRAMInfoLabel]
X=(#ContentX#+6*#Scale#)
W=(#ContentWidth#*0.34)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
UpdateDivider=-1

[StyleRAMInfoValue]
X=(#ContentX#+#ContentWidth#-6*#Scale#)
W=(#ContentWidth#*0.60-6*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#TextColor#
FontSize=(#FontSize#*#Scale#)
Text=Checking...
ToolTipText=Reading Windows memory inventory once on refresh.
Group=RAMHardwareInfo
UpdateDivider=-1

[MeterRAMInfoPanel]
Meter=Shape
X=#ContentX#
Y=(#Inset#+28*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(#ContentWidth#-#Scale#),(118*#Scale#-#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
UpdateDivider=-1

[MeterRAMInfoHeading]
Meter=String
MeterStyle=StyleHeader
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+32*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
Text=MEMORY HARDWARE
UpdateDivider=-1

[MeterRAMInfoInstalledLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoLabel
Y=(#Inset#+52*#Scale#)
Text=Installed

[MeterRAMInfoInstalled]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoValue
Y=(#Inset#+52*#Scale#)

[MeterRAMInfoTypeLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoLabel
Y=(#Inset#+70*#Scale#)
Text=Type

[MeterRAMInfoType]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoValue
Y=(#Inset#+70*#Scale#)

[MeterRAMInfoSpeedLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoLabel
Y=(#Inset#+88*#Scale#)
Text=Rate

[MeterRAMInfoSpeed]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoValue
Y=(#Inset#+88*#Scale#)

[MeterRAMInfoDevicesLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoLabel
Y=(#Inset#+106*#Scale#)
Text=Devices

[MeterRAMInfoDevices]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoValue
Y=(#Inset#+106*#Scale#)

[MeterRAMInfoFormLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoLabel
Y=(#Inset#+124*#Scale#)
Text=Format

[MeterRAMInfoForm]
Meter=String
MeterStyle=StyleLabel | StyleRAMInfoValue
Y=(#Inset#+124*#Scale#)

