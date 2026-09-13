[StyleConnectionLabel]
MeterStyle=StyleLabel
X=#ContentX#
W=(80*#Scale#)
H=(18*#Scale#)

[StyleConnectionValue]
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
W=(#ContentWidth#-84*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#TextColor#






[MeterConnectionAdapter]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+26*#Scale#)
H=(18*#Scale#)
FontColor=#TextColor#
Text=Resolving adapter...

MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Network\Settings" "Settings.ini"]

[MeterConnectionDescription]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+44*#Scale#)
H=(18*#Scale#)
Text=Adapter information

[MeterConnectionStatus]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+62*#Scale#)
H=(18*#Scale#)
Text=Waiting for adapter

[MeterConnectionInternetLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+80*#Scale#)
Text=Internet (PC)

[MeterConnectionInternet]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+80*#Scale#)
Text=Unknown
ToolTipText=Windows' PC-wide Internet report. Detected means Windows reports Internet access on some connection. Not reported can mean no access or an unavailable status query; it is not a reachability or speed test.

[MeterConnectionIPLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+98*#Scale#)
W=(54*#Scale#)
Text=Local IP

[MeterConnectionIP]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+98*#Scale#)
W=(#ContentWidth#-58*#Scale#)
Text=--

[MeterConnectionGatewayLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+116*#Scale#)
W=(56*#Scale#)
Text=Gateway

[MeterConnectionGateway]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+116*#Scale#)
W=(#ContentWidth#-58*#Scale#)
Text=--

[MeterConnectionRxLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+134*#Scale#)
W=(52*#Scale#)
Text=Link RX

[MeterConnectionRx]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+134*#Scale#)
W=(#ContentWidth#-56*#Scale#)
FontColor=#NetworkInColor#
Text=--
ToolTipText=Selected adapter receive link speed reported by Windows, in decimal bits/s. Actual traffic is shown below; this is not measured Internet bandwidth.

[MeterConnectionTxLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+152*#Scale#)
W=(52*#Scale#)
Text=Link TX

[MeterConnectionTx]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+152*#Scale#)
W=(#ContentWidth#-56*#Scale#)
FontColor=#NetworkOutColor#
Text=--
ToolTipText=Selected adapter transmit link speed reported by Windows, in decimal bits/s. Actual traffic is shown below; this is not measured Internet bandwidth.

[MeterConnectionRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+174*#Scale#)

[MeterConnectionWiFi]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+180*#Scale#)
H=(18*#Scale#)
FontColor=#TextColor#
Text=Wi-Fi querying...

[MeterConnectionSignalLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+198*#Scale#)
Text=Signal

[MeterConnectionSignal]
Meter=String
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+198*#Scale#)
Text=--

[MeterConnectionSignalBar]
Meter=Shape
X=#ContentX#
Y=(#Inset#+218*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Rectangle 0,0,#ContentWidth#,#DataBarThicknessPx# | Fill Color #TrackColor# | StrokeWidth 0
Shape2=Line 0,0,0,0 | StrokeWidth 0
DynamicVariables=1

[MeterConnectionRadio]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+220*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Radio unavailable
