; Independent CPU settings: shared label/value fields and bounded steppers.
; Layout variables are event-driven by Settings.lua; hidden details have zero bounds.

[CPUStyleSettingsSection]
MeterStyle=StyleUtilitySettingsSection
FontColor=#AccentColor#
Group=CPUSettingsUI
DynamicVariables=1

[CPUStyleSettingsLabel]
MeterStyle=StyleUtilitySettingsLabel
X=#ContentX#
W=(126*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[CPUStyleSettingsValue]
MeterStyle=StyleUtilitySettingsValue
X=(#ContentX#+132*#Scale#)
W=(#ContentWidth#-138*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsTitle]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow
X=#ContentX#
W=(#ContentWidth#-28*#Scale#)
Text=CPU Settings
Group=CPUSettingsUI

[MeterSettingsClose]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+#ContentWidth#)
Y=#TitleRowCenterY#
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=RightCenter
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!DeactivateConfig]
ToolTipText=Close CPU Settings. Saved choices stay active and the CPU meter keeps running.
Group=CPUSettingsUI
FontSize=(#FontSize#*#Scale#)

[MeterSettingsAppearanceSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|CPUStyleSettingsSection
Y=(#Inset#+#CPUSettingsAppearanceSectionY#*#Scale#)
Text=Appearance

[MeterSettingsAppearanceRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(#CPUSettingsAppearanceSectionY#-6)*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsProcessesSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|CPUStyleSettingsSection
Y=(#Inset#+#CPUSettingsProcessesSectionY#*#Scale#)
Text=Processes

[MeterSettingsProcessesRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(#CPUSettingsProcessesSectionY#-6)*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsGraphSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|CPUStyleSettingsSection
Y=(#Inset#+#CPUSettingsGraphSectionY#*#Scale#)
Text=History

[MeterSettingsGraphRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(#CPUSettingsGraphSectionY#-6)*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsRatesSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|CPUStyleSettingsSection
Y=(#Inset#+#CPUSettingsRatesSectionY#*#Scale#)
Text=Performance

[MeterSettingsRatesRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(#CPUSettingsRatesSectionY#-6)*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsSensorsSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|CPUStyleSettingsSection
Y=(#Inset#+#CPUSettingsSensorsSectionY#*#Scale#)
Text=HWiNFO setup

[MeterSettingsSensorsRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+(#CPUSettingsSensorsSectionY#-6)*#Scale#)
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsInfoLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsInfoHidden#)*(#Inset#+(#CPUSettingsInfoY#+2)*#Scale#))
W=((1-#CPUSettingsInfoHidden#)*(126*#Scale#))
H=((1-#CPUSettingsInfoHidden#)*18*#Scale#)
Hidden=#CPUSettingsInfoHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Processor info
ToolTipText=Show or hide the processor panel, clock and fan rows.
MouseActionCursor=0

[MeterSettingsInfoRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsInfoHidden#)*(#Inset#+(#CPUSettingsInfoY#+0)*#Scale#))
W=((1-#CPUSettingsInfoHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsInfoHidden#)*20*#Scale#)
Hidden=#CPUSettingsInfoHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsInfoHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsInfoHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowInfo')"]
ToolTipText=Show or hide the processor panel, clock and fan rows.

[MeterSettingsInfoValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsInfoHidden#)*(#Inset#+(#CPUSettingsInfoY#+0)*#Scale#))
W=((1-#CPUSettingsInfoHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsInfoHidden#)*18*#Scale#)
Hidden=#CPUSettingsInfoHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowInfo')"]
ToolTipText=Show or hide the processor panel, clock and fan rows.

[MeterSettingsCPUFanLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsCPUFanHidden#)*(#Inset#+(#CPUSettingsCPUFanY#+2)*#Scale#))
W=((1-#CPUSettingsCPUFanHidden#)*(126*#Scale#))
H=((1-#CPUSettingsCPUFanHidden#)*18*#Scale#)
Hidden=#CPUSettingsCPUFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=CPU fan
ToolTipText=Show or hide the CPU fan RPM row beneath Clock.
MouseActionCursor=0

[MeterSettingsCPUFanRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsCPUFanHidden#)*(#Inset#+(#CPUSettingsCPUFanY#+0)*#Scale#))
W=((1-#CPUSettingsCPUFanHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsCPUFanHidden#)*20*#Scale#)
Hidden=#CPUSettingsCPUFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsCPUFanHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsCPUFanHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowFan')"]
ToolTipText=Show or hide the CPU fan RPM row beneath Clock.

[MeterSettingsCPUFanValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsCPUFanHidden#)*(#Inset#+(#CPUSettingsCPUFanY#+0)*#Scale#))
W=((1-#CPUSettingsCPUFanHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsCPUFanHidden#)*18*#Scale#)
Hidden=#CPUSettingsCPUFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowFan')"]
ToolTipText=Show or hide the CPU fan RPM row beneath Clock.

[MeterSettingsMotherboardFanLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsMotherboardFanHidden#)*(#Inset#+(#CPUSettingsMotherboardFanY#+2)*#Scale#))
W=((1-#CPUSettingsMotherboardFanHidden#)*(126*#Scale#))
H=((1-#CPUSettingsMotherboardFanHidden#)*18*#Scale#)
Hidden=#CPUSettingsMotherboardFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Motherboard fan
ToolTipText=Show or hide the motherboard fan RPM row beneath the CPU fan.
MouseActionCursor=0

[MeterSettingsMotherboardFanRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsMotherboardFanHidden#)*(#Inset#+(#CPUSettingsMotherboardFanY#+0)*#Scale#))
W=((1-#CPUSettingsMotherboardFanHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsMotherboardFanHidden#)*20*#Scale#)
Hidden=#CPUSettingsMotherboardFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsMotherboardFanHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsMotherboardFanHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowMotherboardFan')"]
ToolTipText=Show or hide the motherboard fan RPM row beneath the CPU fan.

[MeterSettingsMotherboardFanValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsMotherboardFanHidden#)*(#Inset#+(#CPUSettingsMotherboardFanY#+0)*#Scale#))
W=((1-#CPUSettingsMotherboardFanHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsMotherboardFanHidden#)*18*#Scale#)
Hidden=#CPUSettingsMotherboardFanHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowMotherboardFan')"]
ToolTipText=Show or hide the motherboard fan RPM row beneath the CPU fan.

[MeterSettingsCoresLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsCoresHidden#)*(#Inset#+(#CPUSettingsCoresY#+2)*#Scale#))
W=((1-#CPUSettingsCoresHidden#)*(126*#Scale#))
H=((1-#CPUSettingsCoresHidden#)*18*#Scale#)
Hidden=#CPUSettingsCoresHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Thread table
ToolTipText=Show or hide the thread table, including utilization and paired core voltage/temperature readings.
MouseActionCursor=0

[MeterSettingsCoresRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsCoresHidden#)*(#Inset#+(#CPUSettingsCoresY#+0)*#Scale#))
W=((1-#CPUSettingsCoresHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsCoresHidden#)*20*#Scale#)
Hidden=#CPUSettingsCoresHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsCoresHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsCoresHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowCores')"]
ToolTipText=Show or hide the thread table, including utilization and paired core voltage/temperature readings.

[MeterSettingsCoresValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsCoresHidden#)*(#Inset#+(#CPUSettingsCoresY#+0)*#Scale#))
W=((1-#CPUSettingsCoresHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsCoresHidden#)*18*#Scale#)
Hidden=#CPUSettingsCoresHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowCores')"]
ToolTipText=Show or hide the thread table, including utilization and paired core voltage/temperature readings.

[MeterSettingsDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsDecimalsHidden#)*(#Inset#+(#CPUSettingsDecimalsY#+2)*#Scale#))
W=((1-#CPUSettingsDecimalsHidden#)*(126*#Scale#))
H=((1-#CPUSettingsDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Percent decimals
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsDecimalsInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsDecimalsHidden#)*(#Inset#+(#CPUSettingsDecimalsY#+0)*#Scale#))
W=((1-#CPUSettingsDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsDecimalsHidden#)*20*#Scale#)
Hidden=#CPUSettingsDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsDecimalsHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsDecimalsHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUDecimals')"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsDecimalsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsDecimalsHidden#)*(#Inset#+(#CPUSettingsDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUDecimals',-1)"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsDecimalsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsDecimalsHidden#)*(#Inset#+(#CPUSettingsDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUDecimals')"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsDecimalsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsDecimalsHidden#)*(#Inset#+(#CPUSettingsDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUDecimals',1)"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsVoltageDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsVoltageDecimalsHidden#)*(#Inset#+(#CPUSettingsVoltageDecimalsY#+2)*#Scale#))
W=((1-#CPUSettingsVoltageDecimalsHidden#)*(126*#Scale#))
H=((1-#CPUSettingsVoltageDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Voltage decimals
ToolTipText=Enter an integer from 0 to 3. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsVoltageDecimalsInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsVoltageDecimalsHidden#)*(#Inset#+(#CPUSettingsVoltageDecimalsY#+0)*#Scale#))
W=((1-#CPUSettingsVoltageDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsVoltageDecimalsHidden#)*20*#Scale#)
Hidden=#CPUSettingsVoltageDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsVoltageDecimalsHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsVoltageDecimalsHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUVoltageDecimals')"]
ToolTipText=Enter an integer from 0 to 3. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsVoltageDecimalsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsVoltageDecimalsHidden#)*(#Inset#+(#CPUSettingsVoltageDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsVoltageDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsVoltageDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUVoltageDecimals',-1)"]
ToolTipText=Enter an integer from 0 to 3. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsVoltageDecimalsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsVoltageDecimalsHidden#)*(#Inset#+(#CPUSettingsVoltageDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsVoltageDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsVoltageDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUVoltageDecimals')"]
ToolTipText=Enter an integer from 0 to 3. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsVoltageDecimalsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsVoltageDecimalsHidden#)*(#Inset#+(#CPUSettingsVoltageDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsVoltageDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsVoltageDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUVoltageDecimals',1)"]
ToolTipText=Enter an integer from 0 to 3. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsTemperatureDecimalsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsTemperatureDecimalsHidden#)*(#Inset#+(#CPUSettingsTemperatureDecimalsY#+2)*#Scale#))
W=((1-#CPUSettingsTemperatureDecimalsHidden#)*(126*#Scale#))
H=((1-#CPUSettingsTemperatureDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Temp decimals
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsTemperatureDecimalsInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsTemperatureDecimalsHidden#)*(#Inset#+(#CPUSettingsTemperatureDecimalsY#+0)*#Scale#))
W=((1-#CPUSettingsTemperatureDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsTemperatureDecimalsHidden#)*20*#Scale#)
Hidden=#CPUSettingsTemperatureDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsTemperatureDecimalsHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsTemperatureDecimalsHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUTemperatureDecimals')"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsTemperatureDecimalsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsTemperatureDecimalsHidden#)*(#Inset#+(#CPUSettingsTemperatureDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsTemperatureDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsTemperatureDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUTemperatureDecimals',-1)"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsTemperatureDecimalsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsTemperatureDecimalsHidden#)*(#Inset#+(#CPUSettingsTemperatureDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsTemperatureDecimalsHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsTemperatureDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUTemperatureDecimals')"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsTemperatureDecimalsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsTemperatureDecimalsHidden#)*(#Inset#+(#CPUSettingsTemperatureDecimalsY#+1)*#Scale#))
W=((1-#CPUSettingsTemperatureDecimalsHidden#)*(18*#Scale#))
H=((1-#CPUSettingsTemperatureDecimalsHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureDecimalsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUTemperatureDecimals',1)"]
ToolTipText=Enter an integer from 0 to 1. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsThreadColorsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsThreadColorsHidden#)*(#Inset#+(#CPUSettingsThreadColorsY#+2)*#Scale#))
W=((1-#CPUSettingsThreadColorsHidden#)*(126*#Scale#))
H=((1-#CPUSettingsThreadColorsHidden#)*18*#Scale#)
Hidden=#CPUSettingsThreadColorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Thread colors
ToolTipText=Open CPU-only Thread Colors. Each selected color is shared by its Thread bar and matching per-thread graph trace.
MouseActionCursor=0

[MeterSettingsThreadColorsRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsThreadColorsHidden#)*(#Inset#+(#CPUSettingsThreadColorsY#+0)*#Scale#))
W=((1-#CPUSettingsThreadColorsHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsThreadColorsHidden#)*20*#Scale#)
Hidden=#CPUSettingsThreadColorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsThreadColorsHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsThreadColorsHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!ActivateConfig "Parallax\CPU\Colors" "Colors.ini"]
ToolTipText=Open CPU-only Thread Colors. Each selected color is shared by its Thread bar and matching per-thread graph trace.

[MeterSettingsThreadColorsValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsThreadColorsHidden#)*(#Inset#+(#CPUSettingsThreadColorsY#+0)*#Scale#))
W=((1-#CPUSettingsThreadColorsHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsThreadColorsHidden#)*18*#Scale#)
Hidden=#CPUSettingsThreadColorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Edit
LeftMouseUpAction=[!ActivateConfig "Parallax\CPU\Colors" "Colors.ini"]
ToolTipText=Open CPU-only Thread Colors. Each selected color is shared by its Thread bar and matching per-thread graph trace.

[MeterSettingsProcessesLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsProcessesHidden#)*(#Inset#+(#CPUSettingsProcessesY#+2)*#Scale#))
W=((1-#CPUSettingsProcessesHidden#)*(126*#Scale#))
H=((1-#CPUSettingsProcessesHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Show processes
ToolTipText=Show or hide the list of processes using the most CPU.
MouseActionCursor=0

[MeterSettingsProcessesRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsProcessesHidden#)*(#Inset#+(#CPUSettingsProcessesY#+0)*#Scale#))
W=((1-#CPUSettingsProcessesHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsProcessesHidden#)*20*#Scale#)
Hidden=#CPUSettingsProcessesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsProcessesHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsProcessesHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowProcesses')"]
ToolTipText=Show or hide the list of processes using the most CPU.

[MeterSettingsProcessesValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsProcessesHidden#)*(#Inset#+(#CPUSettingsProcessesY#+0)*#Scale#))
W=((1-#CPUSettingsProcessesHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsProcessesHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowProcesses')"]
ToolTipText=Show or hide the list of processes using the most CPU.

[MeterSettingsProcessCountLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsProcessCountHidden#)*(#Inset#+(#CPUSettingsProcessCountY#+2)*#Scale#))
W=((1-#CPUSettingsProcessCountHidden#)*(126*#Scale#))
H=((1-#CPUSettingsProcessCountHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessCountHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Process count
ToolTipText=Enter an integer from 1 to 10. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsProcessCountInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsProcessCountHidden#)*(#Inset#+(#CPUSettingsProcessCountY#+0)*#Scale#))
W=((1-#CPUSettingsProcessCountHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsProcessCountHidden#)*20*#Scale#)
Hidden=#CPUSettingsProcessCountHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsProcessCountHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsProcessCountHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUProcessCount')"]
ToolTipText=Enter an integer from 1 to 10. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsProcessCountDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsProcessCountHidden#)*(#Inset#+(#CPUSettingsProcessCountY#+1)*#Scale#))
W=((1-#CPUSettingsProcessCountHidden#)*(18*#Scale#))
H=((1-#CPUSettingsProcessCountHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessCountHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUProcessCount',-1)"]
ToolTipText=Enter an integer from 1 to 10. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsProcessCountValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsProcessCountHidden#)*(#Inset#+(#CPUSettingsProcessCountY#+1)*#Scale#))
W=((1-#CPUSettingsProcessCountHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsProcessCountHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessCountHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUProcessCount')"]
ToolTipText=Enter an integer from 1 to 10. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsProcessCountIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsProcessCountHidden#)*(#Inset#+(#CPUSettingsProcessCountY#+1)*#Scale#))
W=((1-#CPUSettingsProcessCountHidden#)*(18*#Scale#))
H=((1-#CPUSettingsProcessCountHidden#)*18*#Scale#)
Hidden=#CPUSettingsProcessCountHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUProcessCount',1)"]
ToolTipText=Enter an integer from 1 to 10. Arrows change by 1 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsHistoryLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsHistoryHidden#)*(#Inset#+(#CPUSettingsHistoryY#+2)*#Scale#))
W=((1-#CPUSettingsHistoryHidden#)*(126*#Scale#))
H=((1-#CPUSettingsHistoryHidden#)*18*#Scale#)
Hidden=#CPUSettingsHistoryHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Show history
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.
MouseActionCursor=0

[MeterSettingsHistoryRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsHistoryHidden#)*(#Inset#+(#CPUSettingsHistoryY#+0)*#Scale#))
W=((1-#CPUSettingsHistoryHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsHistoryHidden#)*20*#Scale#)
Hidden=#CPUSettingsHistoryHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsHistoryHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsHistoryHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowHistory')"]
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.

[MeterSettingsHistoryValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsHistoryHidden#)*(#Inset#+(#CPUSettingsHistoryY#+0)*#Scale#))
W=((1-#CPUSettingsHistoryHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsHistoryHidden#)*18*#Scale#)
Hidden=#CPUSettingsHistoryHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowHistory')"]
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.

[MeterSettingsSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsSourceHidden#)*(#Inset#+(#CPUSettingsSourceY#+2)*#Scale#))
W=((1-#CPUSettingsSourceHidden#)*(126*#Scale#))
H=((1-#CPUSettingsSourceHidden#)*18*#Scale#)
Hidden=#CPUSettingsSourceHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=History source
ToolTipText=Previous/next choices wrap. Click the center for the next choice.
MouseActionCursor=0

[MeterSettingsSourceInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsSourceHidden#)*(#Inset#+(#CPUSettingsSourceY#+0)*#Scale#))
W=((1-#CPUSettingsSourceHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSourceHidden#)*20*#Scale#)
Hidden=#CPUSettingsSourceHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsSourceHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsSourceHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySource()"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSourceDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsSourceHidden#)*(#Inset#+(#CPUSettingsSourceY#+1)*#Scale#))
W=((1-#CPUSettingsSourceHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSourceHidden#)*18*#Scale#)
Hidden=#CPUSettingsSourceHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySource(-1)"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSourceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsSourceHidden#)*(#Inset#+(#CPUSettingsSourceY#+1)*#Scale#))
W=((1-#CPUSettingsSourceHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSourceHidden#)*18*#Scale#)
Hidden=#CPUSettingsSourceHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySource()"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSourceIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsSourceHidden#)*(#Inset#+(#CPUSettingsSourceY#+1)*#Scale#))
W=((1-#CPUSettingsSourceHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSourceHidden#)*18*#Scale#)
Hidden=#CPUSettingsSourceHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySource(1)"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSamplesLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsSamplesHidden#)*(#Inset#+(#CPUSettingsSamplesY#+2)*#Scale#))
W=((1-#CPUSettingsSamplesHidden#)*(126*#Scale#))
H=((1-#CPUSettingsSamplesHidden#)*18*#Scale#)
Hidden=#CPUSettingsSamplesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=History samples
ToolTipText=Enter an integer from 10 to 300. Arrows change by 10 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsSamplesInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsSamplesHidden#)*(#Inset#+(#CPUSettingsSamplesY#+0)*#Scale#))
W=((1-#CPUSettingsSamplesHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSamplesHidden#)*20*#Scale#)
Hidden=#CPUSettingsSamplesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsSamplesHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsSamplesHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUHistorySamples')"]
ToolTipText=Enter an integer from 10 to 300. Arrows change by 10 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSamplesDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsSamplesHidden#)*(#Inset#+(#CPUSettingsSamplesY#+1)*#Scale#))
W=((1-#CPUSettingsSamplesHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSamplesHidden#)*18*#Scale#)
Hidden=#CPUSettingsSamplesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUHistorySamples',-1)"]
ToolTipText=Enter an integer from 10 to 300. Arrows change by 10 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSamplesValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsSamplesHidden#)*(#Inset#+(#CPUSettingsSamplesY#+1)*#Scale#))
W=((1-#CPUSettingsSamplesHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSamplesHidden#)*18*#Scale#)
Hidden=#CPUSettingsSamplesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUHistorySamples')"]
ToolTipText=Enter an integer from 10 to 300. Arrows change by 10 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSamplesIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsSamplesHidden#)*(#Inset#+(#CPUSettingsSamplesY#+1)*#Scale#))
W=((1-#CPUSettingsSamplesHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSamplesHidden#)*18*#Scale#)
Hidden=#CPUSettingsSamplesHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUHistorySamples',1)"]
ToolTipText=Enter an integer from 10 to 300. Arrows change by 10 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsUpdateRateLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsUpdateRateHidden#)*(#Inset#+(#CPUSettingsUpdateRateY#+2)*#Scale#))
W=((1-#CPUSettingsUpdateRateHidden#)*(126*#Scale#))
H=((1-#CPUSettingsUpdateRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsUpdateRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=CPU refresh (ms)
ToolTipText=Enter an integer from 500 to 2000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsUpdateRateInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsUpdateRateHidden#)*(#Inset#+(#CPUSettingsUpdateRateY#+0)*#Scale#))
W=((1-#CPUSettingsUpdateRateHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsUpdateRateHidden#)*20*#Scale#)
Hidden=#CPUSettingsUpdateRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsUpdateRateHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsUpdateRateHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUUpdateInterval')"]
ToolTipText=Enter an integer from 500 to 2000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsUpdateRateDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsUpdateRateHidden#)*(#Inset#+(#CPUSettingsUpdateRateY#+1)*#Scale#))
W=((1-#CPUSettingsUpdateRateHidden#)*(18*#Scale#))
H=((1-#CPUSettingsUpdateRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsUpdateRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUUpdateInterval',-1)"]
ToolTipText=Enter an integer from 500 to 2000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsUpdateRateValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsUpdateRateHidden#)*(#Inset#+(#CPUSettingsUpdateRateY#+1)*#Scale#))
W=((1-#CPUSettingsUpdateRateHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsUpdateRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsUpdateRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUUpdateInterval')"]
ToolTipText=Enter an integer from 500 to 2000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsUpdateRateIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsUpdateRateHidden#)*(#Inset#+(#CPUSettingsUpdateRateY#+1)*#Scale#))
W=((1-#CPUSettingsUpdateRateHidden#)*(18*#Scale#))
H=((1-#CPUSettingsUpdateRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsUpdateRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUUpdateInterval',1)"]
ToolTipText=Enter an integer from 500 to 2000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSensorRateLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsSensorRateHidden#)*(#Inset#+(#CPUSettingsSensorRateY#+2)*#Scale#))
W=((1-#CPUSettingsSensorRateHidden#)*(126*#Scale#))
H=((1-#CPUSettingsSensorRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Sensor read (ms)
ToolTipText=Enter an integer from 500 to 5000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.
MouseActionCursor=0

[MeterSettingsSensorRateInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsSensorRateHidden#)*(#Inset#+(#CPUSettingsSensorRateY#+0)*#Scale#))
W=((1-#CPUSettingsSensorRateHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSensorRateHidden#)*20*#Scale#)
Hidden=#CPUSettingsSensorRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsSensorRateHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsSensorRateHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUSensorInterval')"]
ToolTipText=Enter an integer from 500 to 5000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSensorRateDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsSensorRateHidden#)*(#Inset#+(#CPUSettingsSensorRateY#+1)*#Scale#))
W=((1-#CPUSettingsSensorRateHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSensorRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUSensorInterval',-1)"]
ToolTipText=Enter an integer from 500 to 5000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSensorRateValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsSensorRateHidden#)*(#Inset#+(#CPUSettingsSensorRateY#+1)*#Scale#))
W=((1-#CPUSettingsSensorRateHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSensorRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "BeginNumberInput('CPUSensorInterval')"]
ToolTipText=Enter an integer from 500 to 5000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSensorRateIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsSensorRateHidden#)*(#Inset#+(#CPUSettingsSensorRateY#+1)*#Scale#))
W=((1-#CPUSettingsSensorRateHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSensorRateHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorRateHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "AdjustNumber('CPUSensorInterval',1)"]
ToolTipText=Enter an integer from 500 to 5000. Arrows change by 500 and stop at the limits. Enter applies; Esc cancels.

[MeterSettingsSensorsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsSensorsHidden#)*(#Inset#+(#CPUSettingsSensorsY#+2)*#Scale#))
W=((1-#CPUSettingsSensorsHidden#)*(126*#Scale#))
H=((1-#CPUSettingsSensorsHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Enable sensors
ToolTipText=Enable individual HWiNFO core sensors, the CPU-wide current clock, and the optional CPU-wide summary. Each core reading appears on its two paired thread rows.
MouseActionCursor=0

[MeterSettingsSensorsRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsSensorsHidden#)*(#Inset#+(#CPUSettingsSensorsY#+0)*#Scale#))
W=((1-#CPUSettingsSensorsHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsSensorsHidden#)*20*#Scale#)
Hidden=#CPUSettingsSensorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsSensorsHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsSensorsHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUSensorsEnabled')"]
ToolTipText=Enable individual HWiNFO core sensors, the CPU-wide current clock, and the optional CPU-wide summary. Each core reading appears on its two paired thread rows.

[MeterSettingsSensorsValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsSensorsHidden#)*(#Inset#+(#CPUSettingsSensorsY#+0)*#Scale#))
W=((1-#CPUSettingsSensorsHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsSensorsHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorsHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUSensorsEnabled')"]
ToolTipText=Enable individual HWiNFO core sensors, the CPU-wide current clock, and the optional CPU-wide summary. Each core reading appears on its two paired thread rows.

[MeterSettingsTemperatureLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsTemperatureHidden#)*(#Inset#+(#CPUSettingsTemperatureY#+2)*#Scale#))
W=((1-#CPUSettingsTemperatureHidden#)*(126*#Scale#))
H=((1-#CPUSettingsTemperatureHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=CPU-wide T
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.
MouseActionCursor=0

[MeterSettingsTemperatureRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsTemperatureHidden#)*(#Inset#+(#CPUSettingsTemperatureY#+0)*#Scale#))
W=((1-#CPUSettingsTemperatureHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsTemperatureHidden#)*20*#Scale#)
Hidden=#CPUSettingsTemperatureHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsTemperatureHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsTemperatureHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('TEMP')"]
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.

[MeterSettingsTemperatureValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsTemperatureHidden#)*(#Inset#+(#CPUSettingsTemperatureY#+0)*#Scale#))
W=((1-#CPUSettingsTemperatureHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsTemperatureHidden#)*18*#Scale#)
Hidden=#CPUSettingsTemperatureHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('TEMP')"]
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.

[MeterSettingsVoltageLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsVoltageHidden#)*(#Inset#+(#CPUSettingsVoltageY#+2)*#Scale#))
W=((1-#CPUSettingsVoltageHidden#)*(126*#Scale#))
H=((1-#CPUSettingsVoltageHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=CPU-wide V
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.
MouseActionCursor=0

[MeterSettingsVoltageRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsVoltageHidden#)*(#Inset#+(#CPUSettingsVoltageY#+0)*#Scale#))
W=((1-#CPUSettingsVoltageHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsVoltageHidden#)*20*#Scale#)
Hidden=#CPUSettingsVoltageHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsVoltageHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsVoltageHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('VOLT')"]
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.

[MeterSettingsVoltageValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsVoltageHidden#)*(#Inset#+(#CPUSettingsVoltageY#+0)*#Scale#))
W=((1-#CPUSettingsVoltageHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsVoltageHidden#)*18*#Scale#)
Hidden=#CPUSettingsVoltageHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('VOLT')"]
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.

[MeterSettingsSensorHiveLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsSensorHiveHidden#)*(#Inset#+(#CPUSettingsSensorHiveY#+2)*#Scale#))
W=((1-#CPUSettingsSensorHiveHidden#)*(126*#Scale#))
H=((1-#CPUSettingsSensorHiveHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorHiveHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Search scope
ToolTipText=Previous/next choices wrap. Click the center for the next choice.
MouseActionCursor=0

[MeterSettingsSensorHiveInput]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
X=(#ContentX#+152*#Scale#)
Y=((1-#CPUSettingsSensorHiveHidden#)*(#Inset#+(#CPUSettingsSensorHiveY#+0)*#Scale#))
W=((1-#CPUSettingsSensorHiveHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSensorHiveHidden#)*20*#Scale#)
Hidden=#CPUSettingsSensorHiveHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle (#Scale#/2),(#Scale#/2),((1-#CPUSettingsSensorHiveHidden#)*((#ContentWidth#-172*#Scale#)-#Scale#)),((1-#CPUSettingsSensorHiveHidden#)*19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive()"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSensorHiveDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+141*#Scale#)
Y=((1-#CPUSettingsSensorHiveHidden#)*(#Inset#+(#CPUSettingsSensorHiveY#+1)*#Scale#))
W=((1-#CPUSettingsSensorHiveHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSensorHiveHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorHiveHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive(-1)"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSensorHiveValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
X=(#ContentX#+152*#Scale#+((#ContentWidth#-172*#Scale#))/2)
Y=((1-#CPUSettingsSensorHiveHidden#)*(#Inset#+(#CPUSettingsSensorHiveY#+1)*#Scale#))
W=((1-#CPUSettingsSensorHiveHidden#)*((#ContentWidth#-172*#Scale#)))
H=((1-#CPUSettingsSensorHiveHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorHiveHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive()"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsSensorHiveIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=((1-#CPUSettingsSensorHiveHidden#)*(#Inset#+(#CPUSettingsSensorHiveY#+1)*#Scale#))
W=((1-#CPUSettingsSensorHiveHidden#)*(18*#Scale#))
H=((1-#CPUSettingsSensorHiveHidden#)*18*#Scale#)
Hidden=#CPUSettingsSensorHiveHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive(1)"]
ToolTipText=Previous/next choices wrap. Click the center for the next choice.

[MeterSettingsReconnectLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|CPUStyleSettingsLabel
X=#ContentX#
Y=((1-#CPUSettingsReconnectHidden#)*(#Inset#+(#CPUSettingsReconnectY#+2)*#Scale#))
W=((1-#CPUSettingsReconnectHidden#)*(126*#Scale#))
H=((1-#CPUSettingsReconnectHidden#)*18*#Scale#)
Hidden=#CPUSettingsReconnectHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Reconnect
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.
MouseActionCursor=0

[MeterSettingsReconnectRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsReconnectHidden#)*(#Inset#+(#CPUSettingsReconnectY#+0)*#Scale#))
W=((1-#CPUSettingsReconnectHidden#)*(#ContentWidth#-132*#Scale#))
H=((1-#CPUSettingsReconnectHidden#)*20*#Scale#)
Hidden=#CPUSettingsReconnectHidden#
Group=CPUSettingsUI
DynamicVariables=1
Shape=Rectangle 0,0,((1-#CPUSettingsReconnectHidden#)*(#ContentWidth#-132*#Scale#)),((1-#CPUSettingsReconnectHidden#)*20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ReconnectSensors()"]
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.

[MeterSettingsReconnectValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|CPUStyleSettingsValue
X=(#ContentX#+132*#Scale#)
Y=((1-#CPUSettingsReconnectHidden#)*(#Inset#+(#CPUSettingsReconnectY#+0)*#Scale#))
W=((1-#CPUSettingsReconnectHidden#)*(#ContentWidth#-138*#Scale#))
H=((1-#CPUSettingsReconnectHidden#)*18*#Scale#)
Hidden=#CPUSettingsReconnectHidden#
Group=CPUSettingsUI
DynamicVariables=1
Text=Retry
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ReconnectSensors()"]
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.

[MeterSettingsOpenHWiNFO]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+4*#Scale#+0*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+#CPUSettingsOpenHWiNFOY#*#Scale#)
W=((#ContentWidth#-16*#Scale#)/3)
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=Left
FontSize=(#FontSize#*#Scale#)
SolidColor=#GraphBackgroundColor#
Text=Open HWiNFO
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "OpenHWiNFO()"]
ToolTipText=Open the installed HWiNFO application so its Gadget reporting can be configured.
Group=CPUSettingsUI
DynamicVariables=1
FontColor=#TextColor#

[MeterSettingsGuide]
Meter=String
MeterStyle=StyleButton|StyleSecondaryButton
X=(#ContentX#+4*#Scale#+1*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+#CPUSettingsGuideY#*#Scale#)
W=((#ContentWidth#-16*#Scale#)/3)
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=Left
FontSize=(#FontSize#*#Scale#)
SolidColor=#GraphBackgroundColor#
Text=Setup guide
LeftMouseUpAction=["https://docs.rainmeter.net/tips/hwinfo/"]
ToolTipText=Open the official Rainmeter guide to configuring HWiNFO reporting.
Group=CPUSettingsUI
DynamicVariables=1
FontColor=#TextColor#

[MeterSettingsScan]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+4*#Scale#+2*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+#CPUSettingsScanY#*#Scale#)
W=((#ContentWidth#-16*#Scale#)/3)
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=Left
FontSize=(#FontSize#*#Scale#)
SolidColor=#GraphBackgroundColor#
Text=Scan sensors
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ScanSensors()"]
ToolTipText=Take a new snapshot of the available HWiNFO sensor exports for the selectors below.
Group=CPUSettingsUI
DynamicVariables=1
FontColor=#TextColor#

[MeterSettingsSensorGuide1]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorGuide1Y#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=1. Open Sensors, then click the gear.
Group=CPUSettingsUI
ToolTipText=1. Open Sensors, then click the gear.
DynamicVariables=1

[MeterSettingsSensorGuide2]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorGuide2Y#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=2. Enable Remember Preferences + Gadget reporting.
Group=CPUSettingsUI
ToolTipText=In HWiNFO main settings enable Remember Preferences. In Sensors settings > Gadget, enable reporting to Gadget.
DynamicVariables=1

[MeterSettingsSensorGuide3]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorGuide3Y#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=3. Pick clocks, CPU/board fans, Core temps and Core N VID.
Group=CPUSettingsUI
ToolTipText=Report CPU [#0] Core Clocks for the current CPU-wide clock, the RPM reading named CPU or CPU Fan, and the Mainboard or Motherboard RPM reading. For each physical core, report Core N under CPU DTS and Core N VID under CPU. Distance to TjMAX is not a temperature. CPU Package/Core Temperatures and Vcore/Core VIDs are optional summary readings.
DynamicVariables=1

[MeterSettingsSensorGuide4]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorGuide4Y#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=4. Report each value. OK, then Quit & Save once.
Group=CPUSettingsUI
ToolTipText=Enable Report value in Gadget separately for each chosen sensor, click OK, then use Quit & Save once so HWiNFO restores those exports after restart. Reopen HWiNFO and scan here.
DynamicVariables=1

[MeterSettingsSensorStatus]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorStatusY#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
ClipString=1
Text=Last scan: not yet available
ToolTipText=Results from the last sensor scan. Scanning is a snapshot, not continuous telemetry.
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsSensorDetail]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorDetailY#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(36*#Scale#)
FontSize=(#FontSize#*#Scale#)
ClipString=2
Text=Scan sensors to inspect the exported readings. These are snapshot results.
ToolTipText=Results from the last sensor scan. Scanning is a snapshot, not continuous telemetry.
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsSensorsHint]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsSensorsHintY#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Clock/Fan: CPU-wide. VID: requested.
ToolTipText=HWiNFO Core Clocks supplies the current CPU-wide clock row; a validated CPU or CPU Fan RPM export supplies the fan row. Each HWiNFO Core N supplies V and T to two adjacent thread rows: Core 0 to threads 1/2, Core 1 to threads 3/4, and so on. CPU-wide T/V selectors control the summary only. V displays VID (requested voltage), not measured Vcore.
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsHint]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsHintY#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Changes apply immediately and are saved.
Group=CPUSettingsUI
DynamicVariables=1

[MeterSettingsIndependence]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+#CPUSettingsIndependenceY#*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Close this window independently of the CPU meter.
Group=CPUSettingsUI
DynamicVariables=1

