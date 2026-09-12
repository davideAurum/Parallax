; Original compact Network instrument; inherits shared appearance revision 2.
[MeterNetworkBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterNetworkPanel]
Meter=Shape
MeterStyle=StylePanel

; Three nodes and a branching cable, drawn here rather than importing an asset.
[MeterNetworkIcon]
Meter=Shape
X=#ContentX#
Y=(#Inset#+9*#Scale#)
W=(15*#Scale#)
H=(13*#Scale#)
Shape=Rectangle (5.5*#Scale#),0,(4*#Scale#),(3*#Scale#) | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Line (7.5*#Scale#),(3*#Scale#),(7.5*#Scale#),(6.5*#Scale#) | Stroke Color #AccentColor# | StrokeWidth #Scale#
Shape3=Line (2.5*#Scale#),(6.5*#Scale#),(12.5*#Scale#),(6.5*#Scale#) | Stroke Color #AccentColor# | StrokeWidth #Scale#
Shape4=Line (2.5*#Scale#),(6.5*#Scale#),(2.5*#Scale#),(9*#Scale#) | Stroke Color #AccentColor# | StrokeWidth #Scale#
Shape5=Line (12.5*#Scale#),(6.5*#Scale#),(12.5*#Scale#),(9*#Scale#) | Stroke Color #AccentColor# | StrokeWidth #Scale#
Shape6=Rectangle 0,(9*#Scale#),(5*#Scale#),(4*#Scale#) | Fill Color #AccentColor# | StrokeWidth 0
Shape7=Rectangle (10*#Scale#),(9*#Scale#),(5*#Scale#),(4*#Scale#) | Fill Color #AccentColor# | StrokeWidth 0
UpdateDivider=-1
AntiAlias=1

[MeterNetworkTitle]
Meter=String
MeterStyle=StyleTitle
X=(#ContentX#+20*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(#ContentWidth#-98*#Scale#)
H=((18+#NetworkTitleExtra#)*#Scale#)
Text=Network

; Native glyph layout needs room beyond visible ink, especially at Scale=0.75.
; Shared padding adds 6 px width / 2 px height: 44x18 and 28x18 totals.
[MeterNetworkUnits]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+#ContentWidth#-76*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(38*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=bits
LeftMouseUpAction=[!CommandMeasure MeasureNetworkController "ToggleUnits()"]
ToolTipText=Switch rate display between decimal bits/s and binary bytes/s. Saves the module choice.

[MeterNetworkWidth]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-28*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(22*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=1x
LeftMouseUpAction=[!CommandMeasure MeasureNetworkController "ToggleWidth()"]
ToolTipText=Switch between one and two columns. Saves the module choice and refreshes Network.

[MeterNetworkAdapter]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(25+#NetworkTitleExtra#)*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
FontColor=#TextColor#
Text=Resolving adapter...
ToolTipText=Selected adapter identity. Edit Network settings from the context menu to choose an adapter.
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Network\Connection" "Connection.ini"]

[MeterNetworkStatus]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(42+#NetworkTitleExtra#+#NetworkRowExtra#)*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=Waiting for native measures

[MeterNetworkInLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(60+#NetworkTitleExtra#+2*#NetworkRowExtra#)*#Scale#)
W=(30*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
Text=IN

[MeterNetworkInRate]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(60+#NetworkTitleExtra#+2*#NetworkRowExtra#)*#Scale#)
W=(#ContentWidth#-32*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
StringAlign=Right
FontColor=#NetworkInColor#
Text=--

[MeterNetworkInCeiling]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(76+#NetworkTitleExtra#+3*#NetworkRowExtra#)*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=Graph ceiling
ToolTipText=User-configured inbound graph ceiling. Clipped means history exceeds the scale; the numeric rate remains unclipped.

[MeterNetworkInGrid]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(94+#NetworkTitleExtra#+4*#NetworkRowExtra#)*#Scale#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#NetworkGraphHeight#*#Scale#/4),(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#NetworkGraphHeight#*#Scale#/2),(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#NetworkGraphHeight#*#Scale#/4),(#ContentWidth#-1),(3*#NetworkGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1
AntiAlias=1

[MeterNetworkInGraph]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(94+#NetworkTitleExtra#+4*#NetworkRowExtra#)*#Scale#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0,0,#ContentWidth#,(#NetworkGraphHeight#*#Scale#) | Fill Color 0,0,0,0 | StrokeWidth 0
Shape2=Path History | Stroke Color #NetworkInColor# | StrokeWidth #Scale# | Fill Color 0,0,0,0
History=1,1 | LineTo 1,1
DynamicVariables=1
AntiAlias=1
ToolTipText=Recent inbound NIC samples; newest at right. Gaps clear history. Includes LAN traffic.

[MeterNetworkOutLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(140+#NetworkTitleExtra#/2+#NetworkRowExtra#)*#Scale#)
W=(30*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
Text=OUT

[MeterNetworkOutRate]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(140+#NetworkTitleExtra#/2+#NetworkRowExtra#)*#Scale#)
W=(#ContentWidth#-32*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
StringAlign=Right
FontColor=#NetworkOutColor#
Text=--

[MeterNetworkOutCeiling]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(156+#NetworkTitleExtra#/2+2*#NetworkRowExtra#)*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=Graph ceiling
ToolTipText=User-configured outbound graph ceiling. Clipped means history exceeds the scale; the numeric rate remains unclipped.

[MeterNetworkOutGrid]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(174+#NetworkTitleExtra#/2+3*#NetworkRowExtra#)*#Scale#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#NetworkGraphHeight#*#Scale#/4),(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#NetworkGraphHeight#*#Scale#/2),(#ContentWidth#-1),(#NetworkGraphHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#NetworkGraphHeight#*#Scale#/4),(#ContentWidth#-1),(3*#NetworkGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1
AntiAlias=1

[MeterNetworkOutGraph]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(174+#NetworkTitleExtra#/2+3*#NetworkRowExtra#)*#Scale#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0,0,#ContentWidth#,(#NetworkGraphHeight#*#Scale#) | Fill Color 0,0,0,0 | StrokeWidth 0
Shape2=Path History | Stroke Color #NetworkOutColor# | StrokeWidth #Scale# | Fill Color 0,0,0,0
History=1,1 | LineTo 1,1
DynamicVariables=1
AntiAlias=1
ToolTipText=Recent outbound NIC samples; newest at right. Gaps clear history. Includes LAN traffic.

[MeterNetworkFooter]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+(216-#NetworkRowExtra#)*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
Text=60 samples / incl. LAN
ToolTipText=Up to sixty one-second samples. Selected NIC traffic includes LAN; it is not whole-network Internet traffic.
