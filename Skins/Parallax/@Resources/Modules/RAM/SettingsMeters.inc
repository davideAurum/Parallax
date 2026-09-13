; Visible controls for the independent RAM Settings utility.
; Settings.lua updates values on load and explicit user actions only.
[StyleRAMSettingsUI]
Group=RAMSettingsUI

; Keep the longer RAM labels aligned with a single Global Settings-style
; value column. Value padding supplies the final 6 logical pixels of width.
[StyleRAMSettingsLabel]
W=(132*#Scale#)
Group=RAMSettingsUI

[StyleRAMSettingsValue]
X=(#ContentX#+138*#Scale#)
W=(#ContentWidth#-144*#Scale#)
Group=RAMSettingsUI

; Formatting steppers use the same left boundary as the visibility fields:
; 18 px arrow, 2 px gap, 56 px center, 2 px gap, 18 px arrow.
[StyleRAMSettingsStepperValue]
X=(#ContentX#+186*#Scale#)
Group=RAMSettingsUI

[StyleRAMSettingsStepperFrame]
X=(#ContentX#+158*#Scale#)
Group=RAMSettingsUI

[StyleRAMSettingsStepperPrev]
X=(#ContentX#+147*#Scale#)
Group=RAMSettingsUI

[StyleRAMSettingsStepperNext]
X=(#ContentX#+225*#Scale#)
Group=RAMSettingsUI

[MeterRAMSettingsTitle]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow
X=#ContentX#
W=(#ContentWidth#-28*#Scale#)
Text=RAM Settings
Group=RAMSettingsUI

[MeterRAMSettingsClose]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton
X=(#ContentX#+#ContentWidth#)
Y=#TitleRowCenterY#
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=RightCenter
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!DeactivateConfig]
ToolTipText=Close RAM Settings. Saved choices stay active and the RAM meter keeps running.
Group=RAMSettingsUI

[MeterRAMSettingsDisplay]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleRAMSettingsUI
Y=(#Inset#+74*#Scale#)
Text=Memory formatting

[MeterRAMSettingsDisplayRule]
Meter=Shape
MeterStyle=StyleRule | StyleRAMSettingsUI
Y=(#Inset#+95*#Scale#)

[MeterRAMSettingsVisibility]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleRAMSettingsUI
Y=(#Inset#+188*#Scale#)
Text=Visibility

[MeterRAMSettingsVisibilityRule]
Meter=Shape
MeterStyle=StyleRule | StyleRAMSettingsUI
Y=(#Inset#+209*#Scale#)

[MeterRAMSettingsUnitsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+102*#Scale#)
Text=Memory units
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between decimal GB (1,000,000,000 bytes) and MB (1,000,000 bytes) for module sizes, process memory, RAM and PAGE readouts. Applies and saves immediately.

[MeterRAMSettingsUnitsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+100*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between decimal GB and MB. The arrows select the previous or next unit.

[MeterRAMSettingsUnits]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+101*#Scale#)
Text=GB
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]
ToolTipText=Switch between decimal GB (1,000,000,000 bytes) and MB (1,000,000 bytes) for module sizes, process memory, RAM and PAGE readouts. Applies and saves immediately.

[MeterRAMSettingsUnitsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB',-1)"]
ToolTipText=Previous memory unit. GB and MB wrap around.

[MeterRAMSettingsUnitsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB',1)"]
ToolTipText=Next memory unit. GB and MB wrap around.

[MeterRAMSettingsDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+130*#Scale#)
Text=Memory decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]
ToolTipText=Use the arrows to change memory precision by one. Click the value to type 0 to 2; Enter applies and Esc cancels.

[MeterRAMSettingsDecimalsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+128*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]
ToolTipText=Type memory precision from 0 to 2 as a whole number. Enter applies; Esc cancels.

[MeterRAMSettingsDecimals]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+129*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]
ToolTipText=Type memory precision from 0 to 2 as a whole number. Enter applies; Esc cancels.

[MeterRAMSettingsDecimalsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+129*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMDecimals',-1)"]
ToolTipText=Decrease memory precision by one, stopping at 0.

[MeterRAMSettingsDecimalsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+129*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMDecimals',1)"]
ToolTipText=Increase memory precision by one, stopping at 2.

[MeterRAMSettingsPercentDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+158*#Scale#)
Text=Percent decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]
ToolTipText=Use the arrows to change header percentage precision by one. Click the value to type 0 to 2; Enter applies and Esc cancels.

[MeterRAMSettingsPercentDecimalsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+156*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]
ToolTipText=Type header percentage precision from 0 to 2 as a whole number. Enter applies; Esc cancels.

[MeterRAMSettingsPercentDecimals]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+157*#Scale#)
Text=0
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]
ToolTipText=Type header percentage precision from 0 to 2 as a whole number. Enter applies; Esc cancels.

[MeterRAMSettingsPercentDecimalsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+157*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMPercentDecimals',-1)"]
ToolTipText=Decrease header percentage precision by one, stopping at 0.

[MeterRAMSettingsPercentDecimalsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+157*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMPercentDecimals',1)"]
ToolTipText=Increase header percentage precision by one, stopping at 2.

[MeterRAMSettingsBarLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+216*#Scale#)
Text=RAM bar
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]
ToolTipText=Show or hide the physical RAM usage bar. Keeps the panel size.

[MeterRAMSettingsBar]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+214*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]
ToolTipText=Show or hide the physical RAM usage bar. Keeps the panel size.

[MeterRAMSettingsPageBarLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+244*#Scale#)
Text=PAGE bar
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowPageBar')"]
ToolTipText=Show or hide the paging-file usage bar. Keeps the panel size.

[MeterRAMSettingsPageBar]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+242*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowPageBar')"]
ToolTipText=Show or hide the paging-file usage bar. Keeps the panel size.

[MeterRAMSettingsHistoryLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+272*#Scale#)
Text=Usage history
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]
ToolTipText=Show or hide history without clearing collected samples. Sampling continues.

[MeterRAMSettingsHistory]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+270*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]
ToolTipText=Show or hide history without clearing collected samples. Sampling continues.

[MeterRAMSettingsHint]
Meter=String
MeterStyle=StyleLabel
X=#ContentX#
Y=(#Inset#+298*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Changes save automatically.
Group=RAMSettingsUI

[MeterRAMSettingsIndependence]
Meter=String
MeterStyle=StyleLabel
X=#ContentX#
Y=(#Inset#+318*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=The RAM meter keeps running when settings close.
Group=RAMSettingsUI
