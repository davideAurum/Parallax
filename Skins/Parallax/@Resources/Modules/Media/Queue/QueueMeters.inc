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
MeterStyle=StyleLabel
MeasureName=MeasureQueueStatus
Y=(#Inset#+26*#Scale#)
H=(18*#Scale#)
Text=%1
ToolTipText=Only a validated, unexpired Spotify snapshot can show queue rows. Sign in once, then use Start or Stop. This queue can differ from the player selected by WebNowPlaying.

[MeterQueueRow1]
Meter=String
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+46*#Scale#)
Text=

[MeterQueueRow2]
Meter=String
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+64*#Scale#)
Text=

[MeterQueueRow3]
Meter=String
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+82*#Scale#)
Text=

[MeterQueueRow4]
Meter=String
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+100*#Scale#)
Text=

[MeterQueueRow5]
Meter=String
MeterStyle=StyleLabel|QueueRowStyle
Y=(#Inset#+118*#Scale#)
Text=

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+138*#Scale#)

[MeterQueueConnect]
Meter=String
MeterStyle=QueueActionStyle
X=(#ContentX#+(#ContentWidth#-12*#Scale#)/6)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Sign in
ToolTipText=Open the helper's setup console and sign in through Spotify in your browser. Only your public Client ID is needed; no client secret.
LeftMouseUpAction=["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" "-NoExit" "-File" "#@#Modules\Media\Queue\QueueProvider.ps1" "-Command" "Connect" "-PollSeconds" "#QueuePollSeconds#"]

[MeterQueueStart]
Meter=String
MeterStyle=QueueActionStyle
X=(#ContentX#+#ContentWidth#/2)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Start
ToolTipText=Start one background queue helper using your saved Spotify authorization. It refreshes at most every 30 seconds and honors server wait times.
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Start')"]

[MeterQueueStop]
Meter=String
MeterStyle=QueueActionStyle|StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-(#ContentWidth#-12*#Scale#)/6)
Y=(#Inset#+140*#Scale#)
W=((#ContentWidth#-12*#Scale#)/3)
Text=Stop
ToolTipText=Stop the optional queue helper and clear displayed rows. Saved authorization stays available until Disconnect in the context menu.
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Stop')"]
