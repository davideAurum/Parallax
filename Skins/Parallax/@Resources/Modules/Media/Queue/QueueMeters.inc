[QueueRowStyle]
H=(18*#Scale#)
Group=QueueRows
Hidden=1

[QueueActionStyle]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontColor=#AccentColor#
FontWeight=600
AntiAlias=1
ClipString=1
StringAlign=Center
Padding=0,0,0,0
H=(18*#Scale#)
SolidColor=0,0,0,1
MouseActionCursor=1

[MeterBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterPanel]
Meter=Shape
MeterStyle=StylePanel

[MeterHeading]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow
W=(#ContentWidth#-34*#Scale#)
Text=Spotify queue
UpdateDivider=-1

[MeterQueueStatus]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel
MeasureName=MeasureQueueStatus
Y=(#Inset#+26*#Scale#)
H=(18*#Scale#)
Text=%1

[MeterQueueRow1]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+46*#Scale#)
Text=

[MeterQueueRow2]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+64*#Scale#)
Text=

[MeterQueueRow3]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+82*#Scale#)
Text=

[MeterQueueRow4]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+100*#Scale#)
Text=

[MeterQueueRow5]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+118*#Scale#)
Text=

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+138*#Scale#)

[MeterQueueConnect]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=QueueActionStyle
X=(#ContentX#+(#ContentWidth#-12*#Scale#)/6)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Sign in
LeftMouseUpAction=["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" "-NoExit" "-File" "#@#Modules\Media\Queue\QueueProvider.ps1" "-Command" "Connect" "-PollSeconds" "#QueuePollSeconds#"]

[MeterQueueStart]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=QueueActionStyle
X=(#ContentX#+#ContentWidth#/2)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Start
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Start')"]

[MeterQueueStop]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=QueueActionStyle|StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-(#ContentWidth#-12*#Scale#)/6)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Stop
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Stop')"]
