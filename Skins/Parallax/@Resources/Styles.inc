[StyleBounds]
X=0
Y=0
W=#WindowWidth#
H=#WindowHeight#
SolidColor=0,0,0,0
UpdateDivider=-1

[StylePanel]
X=#Inset#
Y=#Inset#
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(#PanelHeightPx#-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)
UpdateDivider=-1

[StyleLabel]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleTitle]
FontFace=#FontFace#
FontSize=(#TitleFontSize#*#Scale#)
FontColor=#TitleTextColor#
FontWeight=600
AntiAlias=1
ClipString=1
X=#ContentX#
Y=#ContentY#
W=#ContentWidth#
H=(20*#Scale#)

[StyleHeader]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontColor=#HeaderTextColor#
FontWeight=600
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleValue]
FontFace=#FontFace#
FontSize=((#FontSize#+3)*#Scale#)
FontWeight=600
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(22*#Scale#)

[StyleButton]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#AccentColor#
SolidColor=0,0,0,0
AntiAlias=1
ClipString=1
H=(18*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
MouseActionCursor=1

[StyleRule]
X=#ContentX#
Shape=Line 0,0,#ContentWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
UpdateDivider=-1

[StyleSecondaryButton]
FontColor=#AccentColor2#

[StyleGraph]
X=#ContentX#
W=#ContentWidth#
H=(#GraphHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#GraphHeight#*#Scale#/4),(#ContentWidth#-1),(#GraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#GraphHeight#*#Scale#/2),(#ContentWidth#-1),(#GraphHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#GraphHeight#*#Scale#/4),(#ContentWidth#-1),(3*#GraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1
