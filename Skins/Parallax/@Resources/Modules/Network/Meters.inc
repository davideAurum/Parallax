; Original compact Network instrument; inherits shared appearance revision 2.
[MeterNetworkBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterNetworkPanel]
Meter=Shape
MeterStyle=StylePanel

; Original three-node icon on a 14x14 canvas. All geometry follows title size.
[MeterNetworkIcon]
Meter=Shape
X=#ContentX#
Y=(Round(#TitleRowCenterY#-#TitleIconSize#/2))
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Rectangle (5*#TitleIconScale#),(0.5*#TitleIconScale#),(4*#TitleIconScale#),(3*#TitleIconScale#) | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Line (7*#TitleIconScale#),(3.5*#TitleIconScale#),(7*#TitleIconScale#),(6.5*#TitleIconScale#) | Stroke Color #AccentColor# | StrokeWidth #TitleIconScale#
Shape3=Line (2*#TitleIconScale#),(6.5*#TitleIconScale#),(12*#TitleIconScale#),(6.5*#TitleIconScale#) | Stroke Color #AccentColor# | StrokeWidth #TitleIconScale#
Shape4=Line (2*#TitleIconScale#),(6.5*#TitleIconScale#),(2*#TitleIconScale#),(10.5*#TitleIconScale#) | Stroke Color #AccentColor# | StrokeWidth #TitleIconScale#
Shape5=Line (12*#TitleIconScale#),(6.5*#TitleIconScale#),(12*#TitleIconScale#),(10.5*#TitleIconScale#) | Stroke Color #AccentColor# | StrokeWidth #TitleIconScale#
Shape6=Rectangle 0,(10.5*#TitleIconScale#),(4*#TitleIconScale#),(3*#TitleIconScale#) | Fill Color #AccentColor# | StrokeWidth 0
Shape7=Rectangle (10*#TitleIconScale#),(10.5*#TitleIconScale#),(4*#TitleIconScale#),(3*#TitleIconScale#) | Fill Color #AccentColor# | StrokeWidth 0
UpdateDivider=-1
AntiAlias=1

[MeterNetworkTitle]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow
X=(#ContentX#+#TitleIconSize#+#TitleIconGap#)
W=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-78*#Scale#)
Text=Network

; Native glyph layout needs room beyond visible ink, especially at Scale=0.75.
; Shared padding adds 6 px width / 2 px height: 44x18 and 28x18 totals.
[MeterNetworkUnits]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+#ContentWidth#-76*#Scale#)
Y=#TitleRowCenterY#
W=(38*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
StringAlign=LeftCenter
Text=bits
LeftMouseUpAction=[!CommandMeasure MeasureNetworkController "ToggleUnits()"]
ToolTipText=Switch rate display between decimal bits/s and binary bytes/s. Saves the module choice.

[MeterNetworkWidth]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-28*#Scale#)
Y=#TitleRowCenterY#
W=(22*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
StringAlign=LeftCenter
Text=1x
LeftMouseUpAction=[!CommandMeasure MeasureNetworkController "ToggleWidth()"]
ToolTipText=Switch between one and two columns. Saves the module choice and refreshes Network.

[MeterNetworkTrafficRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+242*#Scale#+#DataBarThicknessPx#)

[MeterNetworkStatus]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+246*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Waiting for native measures

[MeterNetworkInLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+266*#Scale#+#DataBarThicknessPx#)
W=(30*#Scale#)
H=(18*#Scale#)
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
Text=IN

[MeterNetworkInRate]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+266*#Scale#+#DataBarThicknessPx#)
W=(#ContentWidth#-32*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#NetworkInColor#
Text=--

[MeterNetworkInCeiling]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+284*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Graph ceiling
ToolTipText=User-configured inbound graph ceiling. Clipped means history exceeds the scale; the numeric rate remains unclipped.

[MeterNetworkInGrid]
Meter=Shape
X=#ContentX#
Y=(#Inset#+304*#Scale#+#DataBarThicknessPx#)
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
Y=(#Inset#+304*#Scale#+#DataBarThicknessPx#)
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
Y=(#Inset#+352*#Scale#+#DataBarThicknessPx#)
W=(30*#Scale#)
H=(18*#Scale#)
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
Text=OUT

[MeterNetworkOutRate]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+352*#Scale#+#DataBarThicknessPx#)
W=(#ContentWidth#-32*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#NetworkOutColor#
Text=--

[MeterNetworkOutCeiling]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+370*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Graph ceiling
ToolTipText=User-configured outbound graph ceiling. Clipped means history exceeds the scale; the numeric rate remains unclipped.

[MeterNetworkOutGrid]
Meter=Shape
X=#ContentX#
Y=(#Inset#+390*#Scale#+#DataBarThicknessPx#)
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
Y=(#Inset#+390*#Scale#+#DataBarThicknessPx#)
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
Y=(#Inset#+436*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=60 samples / incl. LAN
ToolTipText=Up to sixty one-second samples. Selected NIC traffic includes LAN; it is not whole-network Internet traffic.
