; Original GPU settings: Global Settings field layout and shared utility styles.
; Field rows are 28 logical pixels apart; only values have shaded backgrounds.

[GPUSettingsLabel]
W=(134*#Scale#)
Group=GPUSettingsUI

[GPUSettingsValue]
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-146*#Scale#)
Group=GPUSettingsUI

[GPUSettingsAction]
FontSize=((#FontSize#-1)*#Scale#)
Group=GPUSettingsUI

[GPUSettingsSection]
Group=GPUSettingsUI

[GPUSettingsPickerValue]
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Group=GPUSettingsUI|GPUSettingsPicker

[MeterSettingsTitle]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow
X=#ContentX#
W=(#ContentWidth#-32*#Scale#)
Text=GPU Settings
Group=GPUSettingsUI

[MeterSettingsClose]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=#TitleRowCenterY#
X=(#ContentX#+#ContentWidth#)
W=(22*#Scale#)
H=#TitleRowHeight#
StringAlign=RightCenter
Text=X
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Close()"]
Padding=0,0,0,0

[MeterSettingsDisplaySection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|GPUSettingsSection
Y=(#Inset#+74*#Scale#)
Text=Display

[MeterSettingsDisplayRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+94*#Scale#)
W=#ContentWidth#
H=(Max(1,#DividerThickness#*#Scale#))

[MeterSettingsColumnsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+102*#Scale#)
Text=Meter width
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]
W=(134*#Scale#)

[MeterSettingsColumnsPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "StepColumns(-1)"]

[MeterSettingsColumnsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+100*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]

[MeterSettingsColumnsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+101*#Scale#)
W=(56*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]

[MeterSettingsColumnsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "StepColumns(1)"]

[MeterSettingsHeightLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+130*#Scale#)
Text=Fit panel height
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
W=(134*#Scale#)

[MeterSettingsHeightValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
Y=(#Inset#+128*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-146*#Scale#)

[MeterSettingsSensorsSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection|GPUSettingsSection
Y=(#Inset#+162*#Scale#)
W=#ContentWidth#
Text=Provider setup

[MeterSettingsSensorsRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+182*#Scale#)
W=#ContentWidth#
H=(Max(1,#DividerThickness#*#Scale#))

[MeterSettingsTemperatureLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+190*#Scale#)
W=(134*#Scale#)
Text=Temperature
MouseActionCursor=0

[MeterSettingsTemperatureValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+188*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Driver
MouseActionCursor=0

[MeterSettingsTemperatureClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+188*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Refresh
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]
SolidColor=#GraphBackgroundColor#

[MeterSettingsPowerSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+218*#Scale#)
Text=Power source
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]

[MeterSettingsPowerSourcePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power',-1)"]

[MeterSettingsPowerSourceFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+216*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]

[MeterSettingsPowerSourceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+217*#Scale#)
W=(56*#Scale#)
Text=Driver
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]

[MeterSettingsPowerSourceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power',1)"]

[MeterSettingsClockSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+246*#Scale#)
Text=Clock source
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]

[MeterSettingsClockSourcePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock',-1)"]

[MeterSettingsClockSourceFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+244*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]

[MeterSettingsClockSourceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+245*#Scale#)
W=(56*#Scale#)
Text=Driver
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]

[MeterSettingsClockSourceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock',1)"]

[MeterSettingsSensorsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+274*#Scale#)
Text=HWiNFO overrides
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]

[MeterSettingsSensorsValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
Y=(#Inset#+272*#Scale#)
W=(#ContentWidth#-146*#Scale#)
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]
X=(#ContentX#+140*#Scale#)

[MeterSettingsHiveLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+302*#Scale#)
Text=Manual hive
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
W=(134*#Scale#)

[MeterSettingsHivePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive(-1)"]

[MeterSettingsHiveFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+300*#Scale#)
W=(112*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(112*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]

[MeterSettingsHiveValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+216*#Scale#)
Y=(#Inset#+301*#Scale#)
W=(112*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]

[MeterSettingsHiveNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+283*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive(1)"]

[MeterSettingsKeyLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+330*#Scale#)
Text=Manual key
W=(134*#Scale#)

[MeterSettingsKeyValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
Y=(#Inset#+328*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#TextColor#
MouseActionCursor=0
Text=...
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-146*#Scale#)

[MeterSettingsPowerLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+358*#Scale#)
W=(134*#Scale#)
Text=Power override
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Power')"]

[MeterSettingsPowerValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Power')"]

[MeterSettingsPowerClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Power')"]
SolidColor=#GraphBackgroundColor#

[MeterSettingsClockLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+386*#Scale#)
W=(134*#Scale#)
Text=Clock override
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]

[MeterSettingsClockValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+384*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]

[MeterSettingsClockClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+384*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Clock')"]
SolidColor=#GraphBackgroundColor#

[MeterSettingsPickerTitle]
Meter=String
MeterStyle=StyleUtilitySettingsSection|GPUSettingsSection
Y=(#Inset#+418*#Scale#)
W=(#ContentWidth#-72*#Scale#)
Text=Choose an override above
Group=GPUSettingsUI|GPUSettingsPicker

[MeterSettingsRescan]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+416*#Scale#)
X=(#ContentX#+#ContentWidth#-64*#Scale#)
W=(58*#Scale#)
StringAlign=Left
Text=Rescan
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Rescan()"]
SolidColor=#GraphBackgroundColor#

[MeterSettingsPickerRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+438*#Scale#)
W=#ContentWidth#
H=(Max(1,#DividerThickness#*#Scale#))

[MeterSettingsPick1]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsPickerValue
FontColor=#TextColor#
Y=(#Inset#+446*#Scale#)
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
H=(18*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(1)"]

[MeterSettingsPick2]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsPickerValue
FontColor=#TextColor#
Y=(#Inset#+468*#Scale#)
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
H=(18*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(2)"]

[MeterSettingsPick3]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsPickerValue
FontColor=#TextColor#
Y=(#Inset#+490*#Scale#)
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
H=(18*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(3)"]

[MeterSettingsPick4]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsPickerValue
FontColor=#TextColor#
Y=(#Inset#+512*#Scale#)
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
H=(18*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(4)"]

[MeterSettingsPick5]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsPickerValue
FontColor=#TextColor#
Y=(#Inset#+534*#Scale#)
X=#ContentX#
W=(#ContentWidth#-6*#Scale#)
H=(18*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(5)"]

[MeterSettingsPrevious]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+564*#Scale#)
X=#ContentX#
W=(70*#Scale#)
Text=< Previous
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "PrevPage()"]

[MeterSettingsPage]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+564*#Scale#)
X=(#ContentX#+#ContentWidth#/2)
W=(#ContentWidth#-168*#Scale#)
StringAlign=Center
FontColor=#MutedColor#
MouseActionCursor=0
Text=
Group=GPUSettingsUI|GPUSettingsPicker
Padding=0,0,0,0

[MeterSettingsNext]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+564*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(62*#Scale#)
StringAlign=Right
Text=Next >
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "NextPage()"]

[MeterSettingsNotice]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+592*#Scale#)
W=#ContentWidth#
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#
Text=Changes save immediately.
X=#ContentX#
MouseActionCursor=0

[MeterSettingsGuide]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction|StyleSecondaryButton
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+0*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
Text=Guide
LeftMouseUpAction=["notepad.exe" "#@#Modules\GPU\Mapping.txt"]
StringAlign=Left

[MeterSettingsAdvanced]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction|StyleSecondaryButton
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+1*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
Text=Advanced
LeftMouseUpAction=["notepad.exe" "#@#User\GPU.inc"]
StringAlign=Left

[MeterSettingsRefresh]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+2*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
Text=Refresh GPU
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]
StringAlign=Left

[MeterSettingsGlobal]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+3*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
StringAlign=Left
Text=Global
LeftMouseUpAction=[!ActivateConfig "Parallax\Settings" "Settings.ini"]
