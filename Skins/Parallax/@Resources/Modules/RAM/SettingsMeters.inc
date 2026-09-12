; Visible controls for the independent RAM Settings utility.
; Settings.lua updates values on load and explicit user actions only.
[StyleRAMSettingsSection]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)
Group=RAMSettingsUI

[StyleRAMSettingsLabel]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=(#ContentX#+8*#Scale#)
W=(#ContentWidth#-62*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1
Group=RAMSettingsUI

[StyleRAMSettingsValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=600
FontColor=#AccentColor#
AntiAlias=1
ClipString=1
StringAlign=Right
X=(#ContentX#+#ContentWidth#-8*#Scale#)
W=(42*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1
Group=RAMSettingsUI

[StyleRAMSettingsRow]
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(24*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-8*#Scale#),(24*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
MouseActionCursor=1
Group=RAMSettingsUI

[MeterRAMSettingsTitle]
Meter=String
MeterStyle=StyleTitle
X=#ContentX#
Y=(#Inset#+6*#Scale#)
W=(#ContentWidth#-28*#Scale#)
H=(22*#Scale#)
Text=RAM Settings
Group=RAMSettingsUI

[MeterRAMSettingsClose]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+6*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!DeactivateConfig]
ToolTipText=Close RAM Settings. Saved choices stay active and the RAM meter keeps running.
Group=RAMSettingsUI

[MeterRAMSettingsDisplay]
Meter=String
MeterStyle=StyleRAMSettingsSection
Y=(#Inset#+30*#Scale#)
Text=Memory display

[MeterRAMSettingsVisibility]
Meter=String
MeterStyle=StyleRAMSettingsSection
Y=(#Inset#+132*#Scale#)
Text=Usage display

[MeterRAMSettingsUnitsRow]
Meter=Shape
MeterStyle=StyleRAMSettingsRow
Y=(#Inset#+48*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between binary GiB and MiB for installed, used, available and total memory. Applies and saves immediately.

[MeterRAMSettingsUnitsLabel]
Meter=String
MeterStyle=StyleRAMSettingsLabel
Y=(#Inset#+52*#Scale#)
Text=Memory units
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between binary GiB and MiB for installed, used, available and total memory. Applies and saves immediately.

[MeterRAMSettingsUnits]
Meter=String
MeterStyle=StyleRAMSettingsValue
Y=(#Inset#+52*#Scale#)
Text=GiB
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between binary GiB and MiB for installed, used, available and total memory. Applies and saves immediately.

[MeterRAMSettingsDecimalsRow]
Meter=Shape
MeterStyle=StyleRAMSettingsRow
Y=(#Inset#+74*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMDecimals')"]
ToolTipText=Cycle memory precision through 0, 1 and 2 decimal places. Applies and saves immediately.

[MeterRAMSettingsDecimalsLabel]
Meter=String
MeterStyle=StyleRAMSettingsLabel
Y=(#Inset#+78*#Scale#)
Text=Memory decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMDecimals')"]
ToolTipText=Cycle memory precision through 0, 1 and 2 decimal places. Applies and saves immediately.

[MeterRAMSettingsDecimals]
Meter=String
MeterStyle=StyleRAMSettingsValue
Y=(#Inset#+78*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMDecimals')"]
ToolTipText=Cycle memory precision through 0, 1 and 2 decimal places. Applies and saves immediately.

[MeterRAMSettingsPercentDecimalsRow]
Meter=Shape
MeterStyle=StyleRAMSettingsRow
Y=(#Inset#+100*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMPercentDecimals')"]
ToolTipText=Cycle header percentage precision through 0, 1 and 2 decimal places.

[MeterRAMSettingsPercentDecimalsLabel]
Meter=String
MeterStyle=StyleRAMSettingsLabel
Y=(#Inset#+104*#Scale#)
Text=Percent decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMPercentDecimals')"]
ToolTipText=Cycle header percentage precision through 0, 1 and 2 decimal places.

[MeterRAMSettingsPercentDecimals]
Meter=String
MeterStyle=StyleRAMSettingsValue
Y=(#Inset#+104*#Scale#)
Text=0
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMPercentDecimals')"]
ToolTipText=Cycle header percentage precision through 0, 1 and 2 decimal places.

[MeterRAMSettingsBarRow]
Meter=Shape
MeterStyle=StyleRAMSettingsRow
Y=(#Inset#+150*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]
ToolTipText=Show or hide the thin physical RAM usage bar. Keeps the panel size.

[MeterRAMSettingsBarLabel]
Meter=String
MeterStyle=StyleRAMSettingsLabel
Y=(#Inset#+154*#Scale#)
Text=Capacity bar
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]
ToolTipText=Show or hide the thin physical RAM usage bar. Keeps the panel size.

[MeterRAMSettingsBar]
Meter=String
MeterStyle=StyleRAMSettingsValue
Y=(#Inset#+154*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]
ToolTipText=Show or hide the thin physical RAM usage bar. Keeps the panel size.

[MeterRAMSettingsHistoryRow]
Meter=Shape
MeterStyle=StyleRAMSettingsRow
Y=(#Inset#+176*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]
ToolTipText=Show or hide history without clearing collected samples. Sampling continues.

[MeterRAMSettingsHistoryLabel]
Meter=String
MeterStyle=StyleRAMSettingsLabel
Y=(#Inset#+180*#Scale#)
Text=Usage history
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]
ToolTipText=Show or hide history without clearing collected samples. Sampling continues.

[MeterRAMSettingsHistory]
Meter=String
MeterStyle=StyleRAMSettingsValue
Y=(#Inset#+180*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]
ToolTipText=Show or hide history without clearing collected samples. Sampling continues.

[MeterRAMSettingsHint]
Meter=String
MeterStyle=StyleLabel
X=#ContentX#
Y=(#Inset#+206*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Changes save automatically.
Group=RAMSettingsUI

[MeterRAMSettingsIndependence]
Meter=String
MeterStyle=StyleLabel
X=#ContentX#
Y=(#Inset#+226*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=The RAM meter keeps running when settings close.
Group=RAMSettingsUI
