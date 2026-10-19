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

[MeterRAMSettingsUnitsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+100*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]

[MeterRAMSettingsUnits]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+101*#Scale#)
Text=GB
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB')"]

[MeterRAMSettingsUnitsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB',-1)"]

[MeterRAMSettingsUnitsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMUseMiB',1)"]

[MeterRAMSettingsDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+130*#Scale#)
Text=Memory decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]

[MeterRAMSettingsDecimalsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+128*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]

[MeterRAMSettingsDecimals]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+129*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMDecimals')"]

[MeterRAMSettingsDecimalsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+129*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMDecimals',-1)"]

[MeterRAMSettingsDecimalsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+129*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMDecimals',1)"]

[MeterRAMSettingsPercentDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+158*#Scale#)
Text=Percent decimals
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]

[MeterRAMSettingsPercentDecimalsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleRAMSettingsStepperFrame
Y=(#Inset#+156*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]

[MeterRAMSettingsPercentDecimals]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleRAMSettingsStepperValue
Y=(#Inset#+157*#Scale#)
Text=0
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Edit('RAMPercentDecimals')"]

[MeterRAMSettingsPercentDecimalsPrev]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperPrev
Y=(#Inset#+157*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMPercentDecimals',-1)"]

[MeterRAMSettingsPercentDecimalsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleRAMSettingsStepperNext
Y=(#Inset#+157*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Adjust('RAMPercentDecimals',1)"]

[MeterRAMSettingsBarLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+216*#Scale#)
Text=RAM bar
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]

[MeterRAMSettingsBar]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+214*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowBar')"]

[MeterRAMSettingsPageBarLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+244*#Scale#)
Text=PAGE bar
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowPageBar')"]

[MeterRAMSettingsPageBar]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+242*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowPageBar')"]

[MeterRAMSettingsHistoryLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleRAMSettingsLabel
Y=(#Inset#+272*#Scale#)
Text=Usage history
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]

[MeterRAMSettingsHistory]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleRAMSettingsValue
Y=(#Inset#+270*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureRAMSettings "Cycle('RAMShowHistory')"]

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
