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
W=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-66*#Scale#)
Text=Network
; Static text: drawn from the refresh update, never changed afterwards.
UpdateDivider=-1

; Native glyph layout needs room beyond visible ink, especially at Scale=0.75.
; Shared padding adds 6 px width / 2 px height: 44x18 and 28x18 totals.
[MeterNetworkUnits]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleButton
X=(#ContentX#+#ContentWidth#-62*#Scale#)
Y=#TitleRowCenterY#
W=(38*#Scale#)
H=((16+#NetworkRowExtra#)*#Scale#)
StringAlign=LeftCenter
Text=bits
LeftMouseUpAction=[!CommandMeasure MeasureNetworkController "ToggleUnits()"]

; Settings gear in the header's right corner (the width toggle's old spot; the
; meter is fixed at one column). Same eight-tooth gear as the other utilities.
[MeterNetworkOptions]
Meter=Shape
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#TitleRowCenterY#-9*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
Shape=Path GearPath | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Ellipse (9*#Scale#),(9*#Scale#),(2.5*#Scale#),(2.5*#Scale#) | Fill Color #BackgroundColor# | StrokeWidth 0
GearPath=(9.000*#Scale#),(3.300*#Scale#) | LineTo (10.444*#Scale#),(1.742*#Scale#) | LineTo (11.832*#Scale#),(2.163*#Scale#) | LineTo (12.167*#Scale#),(4.261*#Scale#) | LineTo (13.031*#Scale#),(4.969*#Scale#) | LineTo (15.153*#Scale#),(4.889*#Scale#) | LineTo (15.837*#Scale#),(6.168*#Scale#) | LineTo (14.590*#Scale#),(7.888*#Scale#) | LineTo (14.700*#Scale#),(9.000*#Scale#) | LineTo (16.258*#Scale#),(10.444*#Scale#) | LineTo (15.837*#Scale#),(11.832*#Scale#) | LineTo (13.739*#Scale#),(12.167*#Scale#) | LineTo (13.031*#Scale#),(13.031*#Scale#) | LineTo (13.111*#Scale#),(15.153*#Scale#) | LineTo (11.832*#Scale#),(15.837*#Scale#) | LineTo (10.112*#Scale#),(14.590*#Scale#) | LineTo (9.000*#Scale#),(14.700*#Scale#) | LineTo (7.556*#Scale#),(16.258*#Scale#) | LineTo (6.168*#Scale#),(15.837*#Scale#) | LineTo (5.833*#Scale#),(13.739*#Scale#) | LineTo (4.969*#Scale#),(13.031*#Scale#) | LineTo (2.847*#Scale#),(13.111*#Scale#) | LineTo (2.163*#Scale#),(11.832*#Scale#) | LineTo (3.410*#Scale#),(10.112*#Scale#) | LineTo (3.300*#Scale#),(9.000*#Scale#) | LineTo (1.742*#Scale#),(7.556*#Scale#) | LineTo (2.163*#Scale#),(6.168*#Scale#) | LineTo (4.261*#Scale#),(5.833*#Scale#) | LineTo (4.969*#Scale#),(4.969*#Scale#) | LineTo (4.889*#Scale#),(2.847*#Scale#) | LineTo (6.168*#Scale#),(2.163*#Scale#) | LineTo (7.888*#Scale#),(3.410*#Scale#) | ClosePath 1
UpdateDivider=-1
AntiAlias=1
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Network\Settings" "Settings.ini"]

[MeterNetworkTrafficRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+242*#Scale#+#DataBarThicknessPx#)

[MeterNetworkStatus]
Meter=String
Group=ParallaxIdleFreeze
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
UpdateDivider=-1

[MeterNetworkInRate]
Meter=String
Group=ParallaxIdleFreeze
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
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel
Y=(#Inset#+284*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Graph ceiling

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
Group=ParallaxIdleFreeze
X=#ContentX#
Y=(#Inset#+304*#Scale#+#DataBarThicknessPx#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0,0,#ContentWidth#,(#NetworkGraphHeight#*#Scale#) | Fill Color 0,0,0,0 | StrokeWidth 0
Shape2=Path History | Stroke Color #NetworkInColor# | StrokeWidth #Scale# | Fill Color 0,0,0,0
; Network.lua's !SetOption of History/Shape2 forces a one-shot re-read on change.
History=1,1 | LineTo 1,1
AntiAlias=1

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
UpdateDivider=-1

[MeterNetworkOutRate]
Meter=String
Group=ParallaxIdleFreeze
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
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel
Y=(#Inset#+370*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=Graph ceiling

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
Group=ParallaxIdleFreeze
X=#ContentX#
Y=(#Inset#+390*#Scale#+#DataBarThicknessPx#)
W=#ContentWidth#
H=(#NetworkGraphHeight#*#Scale#)
Shape=Rectangle 0,0,#ContentWidth#,(#NetworkGraphHeight#*#Scale#) | Fill Color 0,0,0,0 | StrokeWidth 0
Shape2=Path History | Stroke Color #NetworkOutColor# | StrokeWidth #Scale# | Fill Color 0,0,0,0
; Network.lua's !SetOption of History/Shape2 forces a one-shot re-read on change.
History=1,1 | LineTo 1,1
AntiAlias=1

[MeterNetworkFooter]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleLabel
Y=(#Inset#+436*#Scale#+#DataBarThicknessPx#)
H=(18*#Scale#)
Text=60 samples / incl. LAN
