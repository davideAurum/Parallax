; Shared context and navigation for independent utility settings panels.
; Set SettingsUtilityName locally and reserve the area below the title.
[StyleUtilitySettingsNote]
FontFace=#FontFace#
FontSize=((#FontSize#-1)*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)
Padding=0,0,0,0
UpdateDivider=-1

[MeterUtilitySettingsNote]
Meter=String
MeterStyle=StyleUtilitySettingsNote
Y=(#Inset#+32*#Scale#)
Text=#SettingsUtilityName# settings are found here.

[MeterUtilitySettingsGlobalLink]
Meter=String
MeterStyle=StyleUtilitySettingsNote
Y=(#Inset#+50*#Scale#)
FontColor=#AccentColor#
Text=Global Settings are found here.
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\Settings" "Settings.ini"]
ToolTipText=Open Global Settings for suite-wide appearance, text, colors and geometry.
