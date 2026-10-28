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

; Identity panel (CPU-style): eight 18-pixel lines in a 148-pixel box, 2 px padded top and bottom and starting at Y=30 as CPU's block does - link type,
; adapter name, SSID, protocol, band, local IP and gateway (IP and gateway as
; label/value rows) - then the operational status line. The panel and status
; take the old Adapter, Description and Status rows, the Wi-Fi name and radio
; lines and the IP and gateway rows; the rows below are where they were.
[StyleConnectionPanelLine]
MeterStyle=StyleLabel
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(18*#Scale#)

[MeterConnectionIdentity]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(148*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(148*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
UpdateDivider=-1

; Link type from the native adapter type: Ethernet, Wi-Fi or Other.
[MeterConnectionType]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+32*#Scale#)
FontColor=#TextColor#
Text=Resolving adapter...

; Adapter model name; also opens the Network settings window.
[MeterConnectionName]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+50*#Scale#)
FontColor=#TextColor#
Text=Adapter information
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Network\Settings" "Settings.ini"]

; Blank unless a Wi-Fi connection is reported.
[MeterConnectionSSID]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+68*#Scale#)
FontColor=#AccentColor#
Text=

; Wi-Fi protocol, e.g. "Wi-Fi 4 (802.11n)" (native PHY).
[MeterConnectionRadio]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+86*#Scale#)
FontColor=#AccentColor#
Text=

; "Band: 2.4 GHz". WiFiStatus has no band or channel, so Connection.lua runs one
; hidden netsh query per Wi-Fi connection (MeasureConnectionBandRun).
[MeterConnectionBand]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionPanelLine
Y=(#Inset#+104*#Scale#)
FontColor=#AccentColor#
Text=

[MeterConnectionIPLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+122*#Scale#)
X=(#ContentX#+2*#Scale#)
W=(50*#Scale#)
Text=Local IP

[MeterConnectionIP]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+122*#Scale#)
X=(#ContentX#+#ContentWidth#-1*#Scale#)
Text=--
W=(#ContentWidth#-53*#Scale#)

[MeterConnectionGatewayLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+140*#Scale#)
X=(#ContentX#+2*#Scale#)
W=(55*#Scale#)
Text=Gateway

[MeterConnectionGateway]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+140*#Scale#)
X=(#ContentX#+#ContentWidth#-1*#Scale#)
W=(#ContentWidth#-58*#Scale#)
Text=--

; Link capacity on one panel line: receive in the left half, transmit in the right,
; each led by a Lucide icon (phone-incoming / phone-outgoing, adapted to native
; Shapes; see Icons/Lucide/README.md) in the IN / OUT color, value colors as before.
; A value wider than its half clips.
[MeterConnectionRxIcon]
Meter=Shape
X=(#ContentX#+3*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path PhoneHandset | Extend PhoneStroke
Shape2=Path PhoneArrow | Extend PhoneStroke
Shape3=Line (22*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(16*#NetworkPhoneScale#),(8*#NetworkPhoneScale#) | Extend PhoneStroke
PhoneStroke=Fill Color 0,0,0,0 | Stroke Color #NetworkInColor# | StrokeWidth (2*#NetworkPhoneScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
PhoneHandset=(13.832*#NetworkPhoneScale#),(16.568*#NetworkPhoneScale#) | ArcTo (15.045*#NetworkPhoneScale#),(16.265*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),0,1,0 | LineTo (15.4*#NetworkPhoneScale#),(15.8*#NetworkPhoneScale#) | ArcTo (17*#NetworkPhoneScale#),(15*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (20*#NetworkPhoneScale#),(15*#NetworkPhoneScale#) | ArcTo (22*#NetworkPhoneScale#),(17*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (22*#NetworkPhoneScale#),(20*#NetworkPhoneScale#) | ArcTo (20*#NetworkPhoneScale#),(22*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | ArcTo (2*#NetworkPhoneScale#),(4*#NetworkPhoneScale#),(18*#NetworkPhoneScale#),(18*#NetworkPhoneScale#),0,0,0 | ArcTo (4*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (7*#NetworkPhoneScale#),(2*#NetworkPhoneScale#) | ArcTo (9*#NetworkPhoneScale#),(4*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (9*#NetworkPhoneScale#),(7*#NetworkPhoneScale#) | ArcTo (8.2*#NetworkPhoneScale#),(8.6*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (7.732*#NetworkPhoneScale#),(8.951*#NetworkPhoneScale#) | ArcTo (7.44*#NetworkPhoneScale#),(10.184*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),0,1,0 | ArcTo (13.832*#NetworkPhoneScale#),(16.568*#NetworkPhoneScale#),(14*#NetworkPhoneScale#),(14*#NetworkPhoneScale#),0,1,0
PhoneArrow=(16*#NetworkPhoneScale#),(2*#NetworkPhoneScale#) | LineTo (16*#NetworkPhoneScale#),(8*#NetworkPhoneScale#) | LineTo (22*#NetworkPhoneScale#),(8*#NetworkPhoneScale#)
UpdateDivider=-1
AntiAlias=1

[MeterConnectionRx]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+158*#Scale#)
X=(#ContentX#+22*#Scale#)
W=(#ContentWidth#/2-22*#Scale#)
StringAlign=Left
FontColor=#NetworkInColor#
Text=--

[MeterConnectionTxIcon]
Meter=Shape
X=(#ContentX#+#ContentWidth#/2+1*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path PhoneHandset | Extend PhoneStroke
Shape2=Path PhoneArrow | Extend PhoneStroke
Shape3=Line (16*#NetworkPhoneScale#),(8*#NetworkPhoneScale#),(22*#NetworkPhoneScale#),(2*#NetworkPhoneScale#) | Extend PhoneStroke
PhoneStroke=Fill Color 0,0,0,0 | Stroke Color #NetworkOutColor# | StrokeWidth (2*#NetworkPhoneScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
PhoneHandset=(13.832*#NetworkPhoneScale#),(16.568*#NetworkPhoneScale#) | ArcTo (15.045*#NetworkPhoneScale#),(16.265*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),0,1,0 | LineTo (15.4*#NetworkPhoneScale#),(15.8*#NetworkPhoneScale#) | ArcTo (17*#NetworkPhoneScale#),(15*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (20*#NetworkPhoneScale#),(15*#NetworkPhoneScale#) | ArcTo (22*#NetworkPhoneScale#),(17*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (22*#NetworkPhoneScale#),(20*#NetworkPhoneScale#) | ArcTo (20*#NetworkPhoneScale#),(22*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | ArcTo (2*#NetworkPhoneScale#),(4*#NetworkPhoneScale#),(18*#NetworkPhoneScale#),(18*#NetworkPhoneScale#),0,0,0 | ArcTo (4*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (7*#NetworkPhoneScale#),(2*#NetworkPhoneScale#) | ArcTo (9*#NetworkPhoneScale#),(4*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (9*#NetworkPhoneScale#),(7*#NetworkPhoneScale#) | ArcTo (8.2*#NetworkPhoneScale#),(8.6*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),(2*#NetworkPhoneScale#),0,0,0 | LineTo (7.732*#NetworkPhoneScale#),(8.951*#NetworkPhoneScale#) | ArcTo (7.44*#NetworkPhoneScale#),(10.184*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),(1*#NetworkPhoneScale#),0,1,0 | ArcTo (13.832*#NetworkPhoneScale#),(16.568*#NetworkPhoneScale#),(14*#NetworkPhoneScale#),(14*#NetworkPhoneScale#),0,1,0
PhoneArrow=(22*#NetworkPhoneScale#),(8*#NetworkPhoneScale#) | LineTo (22*#NetworkPhoneScale#),(2*#NetworkPhoneScale#) | LineTo (16*#NetworkPhoneScale#),(2*#NetworkPhoneScale#)
UpdateDivider=-1
AntiAlias=1

[MeterConnectionTx]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+158*#Scale#)
X=(#ContentX#+#ContentWidth#/2+20*#Scale#)
W=(#ContentWidth#/2-21*#Scale#)
StringAlign=Left
FontColor=#NetworkOutColor#
Text=--
[MeterConnectionRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+182*#Scale#)

[MeterConnectionSignalLabel]
Meter=String
MeterStyle=StyleLabel | StyleConnectionLabel
Y=(#Inset#+188*#Scale#)
Text=Signal

[MeterConnectionSignal]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel | StyleConnectionValue
Y=(#Inset#+188*#Scale#)
Text=--

[MeterConnectionSignalBar]
Meter=Shape
Group=ParallaxIdleFreeze
X=#ContentX#
Y=(#Inset#+208*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Rectangle 0,0,#ContentWidth#,#DataBarThicknessPx# | Fill Color #TrackColor# | StrokeWidth 0
; Connection.lua's !SetOption of Shape2 forces a one-shot re-read when the
; fill changes; otherwise the shapes are not rebuilt every second.
Shape2=Line 0,0,0,0 | StrokeWidth 0
