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
W=(#ContentWidth#-78*#Scale#)
MouseActionCursor=1

[IOStyleSettingsDriveValue]
X=(#ContentX#+#ContentWidth#-62*#Scale#)
W=(56*#Scale#)

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
ToolTipText=Close only these settings. Disk Meter remains loaded; saved choices remain active.

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
ToolTipText=On automatically selects all detected drive letters. Turning it off clears the selection. Individual drive edits leave automatic All mode.

[MeterIOSettingsAllValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsGroup
Y=(#Inset#+102*#Scale#)
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "ToggleAllDrives()"]
ToolTipText=On automatically selects all detected drive letters. Turning it off clears the selection. Individual drive edits leave automatic All mode.

[MeterIOSettingsNamesLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+132*#Scale#)
Text=Drive names
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]
ToolTipText=Choose letters only, volume labels, physical drive models, or both names. Long names stay available in drive tooltips.

[MeterIOSettingsNamesDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+131*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode(-1)"]
ToolTipText=Previous value. Letters only, Volume labels, Drive models or Both. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsNamesFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+130*#Scale#)
W=(126*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(126*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]
ToolTipText=Letters only, Volume labels, Drive models or Both. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsNamesValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+203*#Scale#)
Y=(#Inset#+131*#Scale#)
W=(126*#Scale#)
Text=Volume labels
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode()"]
ToolTipText=Letters only, Volume labels, Drive models or Both. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsNamesIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+277*#Scale#)
Y=(#Inset#+131*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleNamesMode(1)"]
ToolTipText=Next value. Letters only, Volume labels, Drive models or Both. Center cycles forward; arrows select the previous or next choice.
[MeterIOSettingsCOnly]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#ContentX#
Y=(#Inset#+160*#Scale#)
W=(112*#Scale#)
Text=Select C: only
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "SelectCDrive()"]
ToolTipText=Select only C: for the capacity and transfer rows. Graph mode remains unchanged.

[MeterIOSettingsDriveValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=(#ContentX#+124*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(#ContentWidth#-244*#Scale#)
Text=1 selected
ToolTipText=Selected drive letters; availability is read from the native inventory. Volumes without letters are outside this selector.

[MeterIOSettingsInventoryRefresh]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#ContentWidth#-108*#Scale#)
Y=(#Inset#+160*#Scale#)
W=(108*#Scale#)
Text=Refresh drives
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "RefreshInventory()"]
ToolTipText=Refresh the native drive list in this settings utility. Disconnected saved selections remain visible; other offline letters can be selected in the options file.

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
ToolTipText=One graph: C: only, Combined, Overlay or Split + / -. Split sums reads above zero and writes below zero. Click to cycle forward.

[MeterIOSettingsGraphDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode(-1)"]
ToolTipText=Previous value. One graph: C: only, Combined, Overlay or Split + / -. Split sums reads above zero and writes below zero. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsGraphFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+244*#Scale#)
W=(126*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(126*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode()"]
ToolTipText=One graph: C: only, Combined, Overlay or Split + / -. Split sums reads above zero and writes below zero. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsGraphValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+203*#Scale#)
Y=(#Inset#+245*#Scale#)
W=(126*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode()"]
ToolTipText=One graph: C: only, Combined, Overlay or Split + / -. Split sums reads above zero and writes below zero. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsGraphIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+277*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleGraphMode(1)"]
ToolTipText=Next value. One graph: C: only, Combined, Overlay or Split + / -. Split sums reads above zero and writes below zero. Center cycles forward; arrows select the previous or next choice.
[MeterIOSettingsUnitsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+274*#Scale#)
Text=Rate units
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]
ToolTipText=Decimal B/s, KB/s and MB/s. Bits use decimal bit/s, kbit/s and Mbit/s. Capacity uses decimal GB.

[MeterIOSettingsUnitsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+273*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits(-1)"]
ToolTipText=Previous value. Choose decimal byte or bit rate units. Capacity remains decimal GB. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsUnitsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+272*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]
ToolTipText=Choose decimal byte or bit rate units. Capacity remains decimal GB. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsUnitsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+168*#Scale#)
Y=(#Inset#+273*#Scale#)
W=(56*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]
ToolTipText=Choose decimal byte or bit rate units. Capacity remains decimal GB. Center cycles forward; arrows select the previous or next choice.

[MeterIOSettingsUnitsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+207*#Scale#)
Y=(#Inset#+273*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits(1)"]
ToolTipText=Next value. Choose decimal byte or bit rate units. Capacity remains decimal GB. Center cycles forward; arrows select the previous or next choice.
[MeterIOSettingsLimitLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|IOStyleSettingsLabel|IOStyleSettingsGroup
Y=(#Inset#+302*#Scale#)
Text=MB/s cap
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]
ToolTipText=Click to enter 0.0001 to 1000000000 MB/s with up to four decimals. Enter applies; Esc cancels. Arrows choose adjacent presets without wrapping; custom saved values remain until a valid edit.

[MeterIOSettingsLimitDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+129*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(-1)"]
ToolTipText=Previous value. Arrows choose the adjacent graph-cap preset and stop at the limits. Center accepts 0.0001 to 1000000000 MB/s with up to four decimals; Enter applies and Esc cancels. Use Edit file for saved values outside this editor range.

[MeterIOSettingsLimitFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|IOStyleSettingsGroup
X=(#ContentX#+140*#Scale#)
Y=(#Inset#+300*#Scale#)
W=(104*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(104*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]
ToolTipText=Arrows choose the adjacent graph-cap preset and stop at the limits. Center accepts 0.0001 to 1000000000 MB/s with up to four decimals; Enter applies and Esc cancels. Use Edit file for saved values outside this editor range.

[MeterIOSettingsLimitValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|IOStyleSettingsGroup
X=(#ContentX#+192*#Scale#)
Y=(#Inset#+301*#Scale#)
W=(104*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "BeginLimitInput()"]
ToolTipText=Arrows choose the adjacent graph-cap preset and stop at the limits. Center accepts 0.0001 to 1000000000 MB/s with up to four decimals; Enter applies and Esc cancels. Use Edit file for saved values outside this editor range.

[MeterIOSettingsLimitIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|IOStyleSettingsGroup
X=(#ContentX#+255*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(1)"]
ToolTipText=Next value. Arrows choose the adjacent graph-cap preset and stop at the limits. Center accepts 0.0001 to 1000000000 MB/s with up to four decimals; Enter applies and Esc cancels. Use Edit file for saved values outside this editor range.
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
ToolTipText=On respects the current user's Windows disk quota. Off requests free space without applying that quota.

[MeterIOSettingsQuotaValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|IOStyleSettingsValue|IOStyleSettingsGroup
Y=(#Inset#+360*#Scale#)
W=(56*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IODiskQuota')"]
ToolTipText=On respects the current user's Windows disk quota. Off requests free space without applying that quota.

[MeterIOSettingsOpen]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#ContentX#
Y=(#Inset#+400*#Scale#)
W=(132*#Scale#)
Text=Open Disk Meter
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Open()"]
ToolTipText=Open Disk Meter with the selected drives and graph mode. UsageMonitor uses one independent LogicalDisk worker; zero rates and sample freshness may be unknown.

[MeterIOSettingsEditFile]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton|StyleSecondaryButton
X=(#ContentX#+144*#Scale#)
Y=(#Inset#+400*#Scale#)
W=(74*#Scale#)
Text=Edit file
LeftMouseUpAction=["notepad.exe" "#@#User\IO.inc"]
ToolTipText=Edit Disk Meter options, including offline letters and legacy graph caps outside the numeric editor range or precision. IODiskDrives accepts all, none, or a sorted uppercase comma list such as C,D,F. IODiskMaxMiBs retains its compatibility storage units. Save and click Reload.

[MeterIOSettingsReload]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+230*#Scale#)
Y=(#Inset#+400*#Scale#)
W=(70*#Scale#)
Text=Reload
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Apply()"]
ToolTipText=Read manual file edits by refreshing only the Disk Meter group and this settings utility.

[MeterIOSettingsProviderHint]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
Y=(#Inset#+426*#Scale#)
H=(16*#Scale#)
Text=Zero activity and unavailable counters can look alike.
ToolTipText=UsageMonitor cannot prove freshness or distinguish zero activity from unavailable counters. Capacity availability does not prove that transfer counters exist.

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
