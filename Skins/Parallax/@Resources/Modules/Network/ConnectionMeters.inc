[StyleConnectionLabel]
MeterStyle=StyleLabel
X=#ContentX#
W=(80*#Scale#)
H=(18*#Scale#)
; Static row labels: drawn from the refresh update, never changed afterwards.
UpdateDivider=-1

[StyleConnectionValue]
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
W=(#ContentWidth#-84*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#TextColor#

; Identity panel (CPU-style): four 18-pixel lines in a 72-pixel box, then the
; operational status line. Together they take the rows the old Adapter,
; Description and Status lines used, plus the Wi-Fi name and radio lines that
; left the Wi-Fi block below; every later row sits 38 pixels lower.
[StyleConnectionPanelLine]
MeterStyle=StyleLabel
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(18*#Scale#)

[MeterConnectionIdentity]
Meter=Shape
X=#ContentX#
Y=(#Inset#+26*#Scale#)
W=#ContentWidth#
H=(72*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(72*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
UpdateDivider=-1

; Link type from the native adapter type: Ethernet, Wi-Fi or Other.
[MeterConnectionType]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+26*#Scale#)
FontColor=#TextColor#
Text=Resolving adapter...

; Adapter model name; also opens the Network settings window.
[MeterConnectionName]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+44*#Scale#)
FontColor=#TextColor#
Text=Adapter information
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Network\Settings" "Settings.ini"]

; Blank unless a Wi-Fi connection is reported.
[MeterConnectionSSID]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+62*#Scale#)
FontColor=#AccentColor#
Text=

; Wi-Fi standard (802.11ax...). Rainmeter's WiFiStatus has no channel field.
[MeterConnectionRadio]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+80*#Scale#)
FontColor=#AccentColor#
Text=

[MeterConnectionStatus]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel
Y=(#Inset#+100*#Scale#)
H=(18*#Scale#)
Text=Waiting for adapter

[MeterConnectionInternetLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+118*#Scale#)
Text=Internet (PC)

[MeterConnectionInternet]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+118*#Scale#)
Text=Unknown

[MeterConnectionIPLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+136*#Scale#)
W=(54*#Scale#)
Text=Local IP

[MeterConnectionIP]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+136*#Scale#)
W=(#ContentWidth#-58*#Scale#)
Text=--

[MeterConnectionGatewayLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+154*#Scale#)
W=(56*#Scale#)
Text=Gateway

[MeterConnectionGateway]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+154*#Scale#)
W=(#ContentWidth#-58*#Scale#)
Text=--

[MeterConnectionRxLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+172*#Scale#)
W=(52*#Scale#)
Text=Link RX

[MeterConnectionRx]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+172*#Scale#)
W=(#ContentWidth#-56*#Scale#)
FontColor=#NetworkInColor#
Text=--

[MeterConnectionTxLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+190*#Scale#)
W=(52*#Scale#)
Text=Link TX

[MeterConnectionTx]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+190*#Scale#)
W=(#ContentWidth#-56*#Scale#)
FontColor=#NetworkOutColor#
Text=--

[MeterConnectionRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+212*#Scale#)

[MeterConnectionSignalLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+218*#Scale#)
Text=Signal

[MeterConnectionSignal]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+218*#Scale#)
Text=--

[MeterConnectionSignalBar]
Meter=Shape
Group=ParallaxIdleFreeze
X=#ContentX#
Y=(#Inset#+238*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Rectangle 0,0,#ContentWidth#,#DataBarThicknessPx# | Fill Color #TrackColor# | StrokeWidth 0
; Connection.lua's !SetOption of Shape2 forces a one-shot re-read when the
; fill changes; otherwise the shapes are not rebuilt every second.
Shape2=Line 0,0,0,0 | StrokeWidth 0
