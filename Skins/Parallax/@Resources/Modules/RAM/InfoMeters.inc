; One compact, wrapping summary per distinct module configuration.
[MeterRAMInfoPanel]
Meter=Shape
X=#ContentX#
Y=(#Inset#+28*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(#ContentWidth#-#Scale#),(#RAMInfoHeight#*#Scale#-#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
Group=RAMLayout
DynamicVariables=1
UpdateDivider=-1

[MeterRAMInfoSummary]
Meter=String
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
StringAlign=Left
ClipString=2
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+32*#Scale#)
W=(#ContentWidth#-12*#Scale#)
Text=Checking...
ToolTipText=Reading each memory module once on refresh.
Group=RAMHardwareInfo
DynamicVariables=1
UpdateDivider=-1
