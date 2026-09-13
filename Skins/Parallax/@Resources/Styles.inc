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

; Layer after StyleTitle. Keep opt-in so existing unrelated String meters do
; not change their anchor until their module explicitly adopts the header row.
[StyleTitleRow]
Y=#TitleRowCenterY#
H=#TitleRowHeight#
StringAlign=LeftCenter

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

; Independent utility settings follow Global Settings labels and value fields.
; Define Y and module groups locally; adjust label/field widths together for
; longer labels or compact option cells. Row is an optional value-field backing.
[StyleUtilitySettingsSection]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#AccentColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleUtilitySettingsLabel]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=#ContentX#
W=(70*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1

[StyleUtilitySettingsValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=(#ContentX#+76*#Scale#)
W=(#ContentWidth#-82*#Scale#)
H=(18*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
SolidColor=#GraphBackgroundColor#
MouseActionCursor=1

[StyleUtilitySettingsRow]
X=(#ContentX#+76*#Scale#)
W=(#ContentWidth#-76*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-76*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
MouseActionCursor=1

[StyleTableHeaderRule]
X=#ContentX#
Shape=Line 0,0,#ContentWidth#,0 | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
UpdateDivider=-1

; CPU-inspired previous / editable value / next controls. Declare X/Y and
; actions locally. String X is its horizontal center; frame X is its left edge.
; Default group: 18 px arrow, 2 px gap, 56 px field, 2 px gap, 18 px arrow.
[StyleSettingsStepperButton]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=600
FontColor=#AccentColor#
AntiAlias=1
ClipString=1
StringAlign=Center
W=(18*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
SolidColor=0,0,0,0
MouseActionCursor=1

[StyleSettingsStepperValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Center
W=(56*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
SolidColor=0,0,0,0
MouseActionCursor=1

[StyleSettingsStepperFrame]
W=(56*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
MouseActionCursor=1
UpdateDivider=-1

[StyleGraph]
X=#ContentX#
W=#ContentWidth#
H=(#GraphHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#GraphHeight#*#Scale#/4),(#ContentWidth#-1),(#GraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#GraphHeight#*#Scale#/2),(#ContentWidth#-1),(#GraphHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#GraphHeight#*#Scale#/4),(#ContentWidth#-1),(3*#GraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1
