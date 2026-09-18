; Parallax Welcome component rows. One row per loadable config: a check box, a
; check mark shown only while that config is loaded, a name and a description.
; Welcome.lua owns the check mark visibility and the name color; slot numbers
; match its components table order.

[StyleWelcomeBox]
X=#ContentX#
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(13*#Scale#),(13*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
MouseActionCursor=1
UpdateDivider=-1
Group=WelcomeRows

[StyleWelcomeCheck]
X=#ContentX#
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Line (3.5*#Scale#),(7.5*#Scale#),(6*#Scale#),(10.5*#Scale#) | StrokeWidth (2*#Scale#) | Stroke Color #AccentColor#
Shape2=Line (6*#Scale#),(10.5*#Scale#),(10.5*#Scale#),(3.5*#Scale#) | StrokeWidth (2*#Scale#) | Stroke Color #AccentColor#
Hidden=1
MouseActionCursor=1
UpdateDivider=-1
Group=WelcomeRows

; Style sections stay flat; Rainmeter does not resolve MeterStyle inside one.
[StyleWelcomeName]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#MutedColor#
AntiAlias=1
ClipString=1
X=(#ContentX#+24*#Scale#)
W=(92*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1
UpdateDivider=-1
Group=WelcomeRows

[StyleWelcomeDescription]
FontFace=#FontFace#
FontSize=((#FontSize#-1)*#Scale#)
FontWeight=500
FontColor=#MutedColor#
AntiAlias=1
ClipString=1
X=(#ContentX#+120*#Scale#)
W=(#ContentWidth#-120*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1
UpdateDivider=-1
Group=WelcomeRows

[MeterWelcomeBox1]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+107*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Chronometer')"]
ToolTipText=Load or unload Chronometer.

[MeterWelcomeCheck1]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+107*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Chronometer')"]

[MeterWelcomeName1]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+105*#Scale#)
Text=Chronometer
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Chronometer')"]
ToolTipText=Load or unload Chronometer.

[MeterWelcomeDescription1]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+105*#Scale#)
Text=Clock, uptime and countdown lists
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Chronometer')"]

[MeterWelcomeBox2]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+131*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('CPU')"]
ToolTipText=Load or unload CPU.

[MeterWelcomeCheck2]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+131*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('CPU')"]

[MeterWelcomeName2]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+129*#Scale#)
Text=CPU
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('CPU')"]
ToolTipText=Load or unload CPU.

[MeterWelcomeDescription2]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+129*#Scale#)
Text=Processor load, logical cores and sensors
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('CPU')"]

[MeterWelcomeBox3]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+155*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('RAM')"]
ToolTipText=Load or unload RAM.

[MeterWelcomeCheck3]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+155*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('RAM')"]

[MeterWelcomeName3]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+153*#Scale#)
Text=RAM
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('RAM')"]
ToolTipText=Load or unload RAM.

[MeterWelcomeDescription3]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+153*#Scale#)
Text=Memory Meter: physical RAM and page file
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('RAM')"]

[MeterWelcomeBox4]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+179*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('GPU')"]
ToolTipText=Load or unload GPU.

[MeterWelcomeCheck4]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+179*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('GPU')"]

[MeterWelcomeName4]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+177*#Scale#)
Text=GPU
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('GPU')"]
ToolTipText=Load or unload GPU.

[MeterWelcomeDescription4]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+177*#Scale#)
Text=Graphics activity, VRAM and temperature
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('GPU')"]

[MeterWelcomeBox5]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+203*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('IO')"]
ToolTipText=Load or unload IO.

[MeterWelcomeCheck5]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+203*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('IO')"]

[MeterWelcomeName5]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+201*#Scale#)
Text=IO
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('IO')"]
ToolTipText=Load or unload IO.

[MeterWelcomeDescription5]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+201*#Scale#)
Text=Disk Meter: drive capacity and activity
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('IO')"]

[MeterWelcomeBox6]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+227*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Network')"]
ToolTipText=Load or unload Network.

[MeterWelcomeCheck6]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+227*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Network')"]

[MeterWelcomeName6]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+225*#Scale#)
Text=Network
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Network')"]
ToolTipText=Load or unload Network.

[MeterWelcomeDescription6]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+225*#Scale#)
Text=Adapter status and traffic rates
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Network')"]

[MeterWelcomeBox7]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+251*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Media')"]
ToolTipText=Load or unload Media.

[MeterWelcomeCheck7]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+251*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Media')"]

[MeterWelcomeName7]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+249*#Scale#)
Text=Media
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Media')"]
ToolTipText=Load or unload Media. Playback needs WebNowPlaying.

[MeterWelcomeDescription7]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+249*#Scale#)
Text=Now playing and playback controls
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Media')"]

[MeterWelcomeBox8]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+275*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Visualizer')"]
ToolTipText=Load or unload Visualizer.

[MeterWelcomeCheck8]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+275*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Visualizer')"]

[MeterWelcomeName8]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+273*#Scale#)
Text=Visualizer
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Visualizer')"]
ToolTipText=Load or unload Visualizer.

[MeterWelcomeDescription8]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+273*#Scale#)
Text=Output-device audio spectrum
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Visualizer')"]

[MeterWelcomeBox9]
Meter=Shape
MeterStyle=StyleWelcomeBox
Y=(#Inset#+311*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Settings')"]
ToolTipText=Load or unload Global Settings.

[MeterWelcomeCheck9]
Meter=Shape
MeterStyle=StyleWelcomeCheck
Y=(#Inset#+311*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Settings')"]

[MeterWelcomeName9]
Meter=String
MeterStyle=StyleWelcomeName
Y=(#Inset#+309*#Scale#)
Text=Global Settings
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Settings')"]
ToolTipText=Load or unload Global Settings.

[MeterWelcomeDescription9]
Meter=String
MeterStyle=StyleWelcomeDescription
Y=(#Inset#+309*#Scale#)
Text=Suite appearance, sizing and refresh rates
LeftMouseUpAction=[!CommandMeasure MeasureWelcome "Toggle('Settings')"]
