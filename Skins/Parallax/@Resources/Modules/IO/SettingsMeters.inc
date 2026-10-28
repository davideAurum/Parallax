; Original compact value fields for the independent Disk Meter settings utility.
; Fixed actions call validated choices; saved labels never form commands.

[IOStyleSettingsGroup]
Group=IOSettingsUI

[IOStyleSettingsText]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)
Group=IOSettingsUI

[IOStyleSettingsButton]
FontColor=#AccentColor#
MouseActionCursor=1

[IOStyleSettingsMetadata]
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#

[IOStyleSettingsLabel]
X=#ContentX#
W=(110*#Scale#)
MouseActionCursor=1

[IOStyleSettingsValue]
X=(#ContentX#+120*#Scale#)
W=(56*#Scale#)
StringAlign=Left

[IOStyleSettingsDrive]
Y=0
Hidden=1

[IOStyleSettingsDriveLabel]
; Fixed width with natural single-line height lets ClipString ellipsize names.
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=#ContentX#
W=(#ContentWidth#-164*#Scale#)
MouseActionCursor=1

[IOStyleSettingsDriveValue]
X=(#ContentX#+#ContentWidth#-62*#Scale#)
W=(56*#Scale#)

[IOStyleSettingsDriveHex]
; Per-drive overlay color: a click opens the one-line #RRGGBB editor over this field.
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
StringAlign=Left
X=(#ContentX#+#ContentWidth#-158*#Scale#)
W=(60*#Scale#)
H=(18*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
SolidColor=#GraphBackgroundColor#
MouseActionCursor=1

[IOStyleSettingsDriveSwatch]
X=(#ContentX#+#ContentWidth#-88*#Scale#)
W=(22*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (0.5*#Scale#),(0.5*#Scale#),(21*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #TextColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
MouseActionCursor=1

[IOStyleSettingsRule]
W=#ContentWidth#
H=(Max(1,#DividerThickness#*#Scale#))
Shape=Line 0,(#DividerThickness#*#Scale#/2),#ContentWidth#,(#DividerThickness#*#Scale#/2) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterIOSettingsTitle]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow|IOStyleSettingsGroup
X=#ContentX#
W=(#ContentWidth#-26*#Scale#)
Text=Disk Meter Settings

[MeterIOSettingsClose]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton|StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=#TitleRowCenterY#
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=LeftCenter
Text=X
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Close()"]

[MeterIOSettingsDrivesSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|IOStyleSettingsGroup
Y=(#Inset#+74*#Scale#)
Text=Drives

[MeterIOSettingsDrivesRule]
Meter=Shape
MeterStyle=StyleRule|IOStyleSettingsRule|IOStyleSettingsGroup
Y=(#Inset#+94*#Scale#)

[MeterIOSettingsAllLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+104*#Scale#)
Text=All drives
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleAllDrives()"]

[MeterIOSettingsAllValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsGroup
Y=(#Inset#+102*#Scale#)
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleAllDrives()"]

[MeterIOSettingsNamesLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+132*#Scale#)
Text=Drive names
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]

[MeterIOSettingsNamesDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+131*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode(-1)"]

[MeterIOSettingsNamesFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+130*#Scale#)
W=(126*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(126*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]

[MeterIOSettingsNamesValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+203*#Scale#)
Y=(#Inset#+131*#Scale#)
W=(126*#Scale#)
Text=Volume labels
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]

[MeterIOSettingsNamesIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+277*#Scale#)
Y=(#Inset#+131*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode(1)"]
[MeterIOSettingsCOnly]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#ContentX#
Y=(#Inset#+160*#Scale#)
W=(112*#Scale#)
Text=Select C: only
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "SelectCDrive()"]

[MeterIOSettingsDriveValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=(#ContentX#+124*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(#ContentWidth#-244*#Scale#)
Text=1 selected

[MeterIOSettingsInventoryRefresh]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#ContentWidth#-108*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(108*#Scale#)
Text=Refresh drives
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "RefreshInventory()"]

[MeterIOSettingsDriveALabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=A:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('A')"]

[MeterIOSettingsDriveA]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('A')"]

[MeterIOSettingsDriveAHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('A')"]

[MeterIOSettingsDriveASwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('A')"]

[MeterIOSettingsDriveBLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=B:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('B')"]

[MeterIOSettingsDriveB]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('B')"]

[MeterIOSettingsDriveBHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('B')"]

[MeterIOSettingsDriveBSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('B')"]

[MeterIOSettingsDriveCLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=C:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('C')"]

[MeterIOSettingsDriveC]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('C')"]

[MeterIOSettingsDriveCHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('C')"]

[MeterIOSettingsDriveCSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('C')"]

[MeterIOSettingsDriveDLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=D:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('D')"]

[MeterIOSettingsDriveD]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('D')"]

[MeterIOSettingsDriveDHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('D')"]

[MeterIOSettingsDriveDSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('D')"]

[MeterIOSettingsDriveELabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=E:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('E')"]

[MeterIOSettingsDriveE]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('E')"]

[MeterIOSettingsDriveEHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('E')"]

[MeterIOSettingsDriveESwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('E')"]

[MeterIOSettingsDriveFLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=F:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('F')"]

[MeterIOSettingsDriveF]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('F')"]

[MeterIOSettingsDriveFHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('F')"]

[MeterIOSettingsDriveFSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('F')"]

[MeterIOSettingsDriveGLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=G:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('G')"]

[MeterIOSettingsDriveG]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('G')"]

[MeterIOSettingsDriveGHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('G')"]

[MeterIOSettingsDriveGSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('G')"]

[MeterIOSettingsDriveHLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=H:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('H')"]

[MeterIOSettingsDriveH]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('H')"]

[MeterIOSettingsDriveHHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('H')"]

[MeterIOSettingsDriveHSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('H')"]

[MeterIOSettingsDriveILabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=I:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('I')"]

[MeterIOSettingsDriveI]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('I')"]

[MeterIOSettingsDriveIHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('I')"]

[MeterIOSettingsDriveISwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('I')"]

[MeterIOSettingsDriveJLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=J:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('J')"]

[MeterIOSettingsDriveJ]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('J')"]

[MeterIOSettingsDriveJHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('J')"]

[MeterIOSettingsDriveJSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('J')"]

[MeterIOSettingsDriveKLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=K:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('K')"]

[MeterIOSettingsDriveK]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('K')"]

[MeterIOSettingsDriveKHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('K')"]

[MeterIOSettingsDriveKSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('K')"]

[MeterIOSettingsDriveLLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=L:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('L')"]

[MeterIOSettingsDriveL]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('L')"]

[MeterIOSettingsDriveLHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('L')"]

[MeterIOSettingsDriveLSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('L')"]

[MeterIOSettingsDriveMLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=M:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('M')"]

[MeterIOSettingsDriveM]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('M')"]

[MeterIOSettingsDriveMHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('M')"]

[MeterIOSettingsDriveMSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('M')"]

[MeterIOSettingsDriveNLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=N:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('N')"]

[MeterIOSettingsDriveN]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('N')"]

[MeterIOSettingsDriveNHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('N')"]

[MeterIOSettingsDriveNSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('N')"]

[MeterIOSettingsDriveOLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=O:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('O')"]

[MeterIOSettingsDriveO]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('O')"]

[MeterIOSettingsDriveOHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('O')"]

[MeterIOSettingsDriveOSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('O')"]

[MeterIOSettingsDrivePLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=P:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('P')"]

[MeterIOSettingsDriveP]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('P')"]

[MeterIOSettingsDrivePHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('P')"]

[MeterIOSettingsDrivePSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('P')"]

[MeterIOSettingsDriveQLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=Q:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Q')"]

[MeterIOSettingsDriveQ]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Q')"]

[MeterIOSettingsDriveQHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Q')"]

[MeterIOSettingsDriveQSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Q')"]

[MeterIOSettingsDriveRLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=R:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('R')"]

[MeterIOSettingsDriveR]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('R')"]

[MeterIOSettingsDriveRHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('R')"]

[MeterIOSettingsDriveRSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('R')"]

[MeterIOSettingsDriveSLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=S:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('S')"]

[MeterIOSettingsDriveS]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('S')"]

[MeterIOSettingsDriveSHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('S')"]

[MeterIOSettingsDriveSSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('S')"]

[MeterIOSettingsDriveTLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=T:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('T')"]

[MeterIOSettingsDriveT]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('T')"]

[MeterIOSettingsDriveTHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('T')"]

[MeterIOSettingsDriveTSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('T')"]

[MeterIOSettingsDriveULabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=U:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('U')"]

[MeterIOSettingsDriveU]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('U')"]

[MeterIOSettingsDriveUHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('U')"]

[MeterIOSettingsDriveUSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('U')"]

[MeterIOSettingsDriveVLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=V:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('V')"]

[MeterIOSettingsDriveV]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('V')"]

[MeterIOSettingsDriveVHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('V')"]

[MeterIOSettingsDriveVSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('V')"]

[MeterIOSettingsDriveWLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=W:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('W')"]

[MeterIOSettingsDriveW]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('W')"]

[MeterIOSettingsDriveWHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('W')"]

[MeterIOSettingsDriveWSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('W')"]

[MeterIOSettingsDriveXLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=X:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('X')"]

[MeterIOSettingsDriveX]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('X')"]

[MeterIOSettingsDriveXHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('X')"]

[MeterIOSettingsDriveXSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('X')"]

[MeterIOSettingsDriveYLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=Y:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Y')"]

[MeterIOSettingsDriveY]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Y')"]

[MeterIOSettingsDriveYHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Y')"]

[MeterIOSettingsDriveYSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Y')"]

[MeterIOSettingsDriveZLabel]
Meter=String
MeterStyle=IOStyleSettingsDriveLabel|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=Z:
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Z')"]

[MeterIOSettingsDriveZ]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsDrive|IOStyleSettingsDriveValue|IOStyleSettingsGroup
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleDrive('Z')"]

[MeterIOSettingsDriveZHex]
Meter=String
MeterStyle=IOStyleSettingsDriveHex|IOStyleSettingsDrive|IOStyleSettingsGroup
Text=#000000
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Z')"]

[MeterIOSettingsDriveZSwatch]
Meter=Shape
MeterStyle=IOStyleSettingsDriveSwatch|IOStyleSettingsDrive|IOStyleSettingsGroup
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginColorInput('Z')"]

[MeterIOSettingsGraphSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|IOStyleSettingsGroup
Y=(#Inset#+216*#Scale#)
Text=Graph / display

[MeterIOSettingsGraphRule]
Meter=Shape
MeterStyle=StyleRule|IOStyleSettingsRule|IOStyleSettingsGroup
Y=(#Inset#+236*#Scale#)

[MeterIOSettingsGraphLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+246*#Scale#)
Text=Graph mode
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode()"]

[MeterIOSettingsGraphDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode(-1)"]

[MeterIOSettingsGraphFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+244*#Scale#)
W=(126*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(126*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode()"]

[MeterIOSettingsGraphValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+203*#Scale#)
Y=(#Inset#+245*#Scale#)
W=(126*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode()"]

[MeterIOSettingsGraphIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+277*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode(1)"]
[MeterIOSettingsUnitsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+274*#Scale#)
Text=Rate units
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]

[MeterIOSettingsUnitsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+273*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits(-1)"]

[MeterIOSettingsUnitsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+272*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]

[MeterIOSettingsUnitsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+168*#Scale#)
Y=(#Inset#+273*#Scale#)
W=(56*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]

[MeterIOSettingsUnitsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+207*#Scale#)
Y=(#Inset#+273*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits(1)"]
[MeterIOSettingsLimitLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+302*#Scale#)
Text=MB/s cap
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]

[MeterIOSettingsLimitDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(-1)"]

[MeterIOSettingsLimitFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+300*#Scale#)
W=(104*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(104*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]

[MeterIOSettingsLimitValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+192*#Scale#)
Y=(#Inset#+301*#Scale#)
W=(104*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]

[MeterIOSettingsLimitIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+255*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(1)"]
[MeterIOSettingsCapacitySection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|IOStyleSettingsGroup
Y=(#Inset#+332*#Scale#)
Text=Capacity

[MeterIOSettingsCapacityRule]
Meter=Shape
MeterStyle=StyleRule|IOStyleSettingsRule|IOStyleSettingsGroup
Y=(#Inset#+352*#Scale#)

[MeterIOSettingsQuotaLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+362*#Scale#)
Text=Disk quotas
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IODiskQuota')"]

[MeterIOSettingsQuotaValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsGroup
Y=(#Inset#+360*#Scale#)
W=(56*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IODiskQuota')"]

[MeterIOSettingsOpen]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#ContentX#
Y=(#Inset#+400*#Scale#)
W=(132*#Scale#)
Text=Open Disk Meter
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Open()"]

[MeterIOSettingsEditFile]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton|StyleSecondaryButton
X=(#ContentX#+144*#Scale#)
Y=(#Inset#+400*#Scale#)
W=(74*#Scale#)
Text=Edit file
LeftMouseUpAction=["notepad.exe" "#@#User\IO.inc"]

[MeterIOSettingsReload]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+230*#Scale#)
Y=(#Inset#+400*#Scale#)
W=(70*#Scale#)
Text=Reload
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Apply()"]

[MeterIOSettingsProviderHint]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
Y=(#Inset#+426*#Scale#)
H=(16*#Scale#)
Text=Zero activity and unavailable counters can look alike.

[MeterIOSettingsNotice]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
Y=(#Inset#+448*#Scale#)
H=(16*#Scale#)
Text=Changes save immediately.

[MeterIOSettingsIndependence]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
Y=(#Inset#+470*#Scale#)
H=(16*#Scale#)
Text=Close settings independently of Disk Meter.
