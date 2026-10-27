[QueueRowStyle]
H=(18*#Scale#)
Group=QueueRows
Hidden=1
; Clicking a row skips to it (QueueReader.lua PlayRow); the reader shows the
; hand cursor only on rows it marks clickable.
MouseActionCursor=0

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

; Asks the running helper to read the queue now, at the status row's right end.
; It shows with the rows (QueueRows), when the status is a short "Next N" or
; a click's outcome; the long unavailable states keep the whole line.
[MeterQueueRefresh]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
Hidden=1
MeterStyle=QueueActionStyle
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+26*#Scale#)
W=(56*#Scale#)
StringAlign=Right
Text=Refresh
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Refresh')"]

[MeterQueueRow1]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+46*#Scale#)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(1)"]

[MeterQueueRow2]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+64*#Scale#)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(2)"]

[MeterQueueRow3]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+82*#Scale#)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(3)"]

[MeterQueueRow4]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+100*#Scale#)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(4)"]

[MeterQueueRow5]
Meter=String
Group=QueueRows | ParallaxIdleFreeze
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+118*#Scale#)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureQueueStatus "PlayRow(5)"]

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
