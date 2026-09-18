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
ToolTipText=Close GPU Settings. The GPU meter keeps running and saved choices remain active.
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
ToolTipText=Enter one or two GPU monitor columns. The arrows stop at these limits; this settings window keeps its own size.
W=(134*#Scale#)

[MeterSettingsColumnsPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "StepColumns(-1)"]
ToolTipText=Enter one or two GPU monitor columns. Arrows stop at the supported limits.

[MeterSettingsColumnsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+100*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]
ToolTipText=Enter one or two GPU monitor columns. Arrows stop at the supported limits.

[MeterSettingsColumnsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+101*#Scale#)
W=(56*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]
ToolTipText=Enter one or two GPU monitor columns. Arrows stop at the supported limits.

[MeterSettingsColumnsNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "StepColumns(1)"]
ToolTipText=Enter one or two GPU monitor columns. Arrows stop at the supported limits.

[MeterSettingsHeightLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+130*#Scale#)
Text=Fit panel height
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
ToolTipText=Set the GPU meter height to 650 logical pixels to fit its GPU overview, process bars and sensor rows.
W=(134*#Scale#)

[MeterSettingsHeightValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
Y=(#Inset#+128*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
ToolTipText=Set the GPU meter height to 650 logical pixels to fit its GPU overview, process bars and sensor rows.
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
ToolTipText=Regular GPU temperature from the installed NVIDIA driver. Hotspot is a separate reading and is not reported here. HWiNFO is not required.

[MeterSettingsTemperatureValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+188*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Driver
MouseActionCursor=0
ToolTipText=Regular GPU temperature from the installed NVIDIA driver. Hotspot is a separate reading and is not reported here. HWiNFO is not required.

[MeterSettingsTemperatureClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+188*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Refresh
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]
ToolTipText=Refresh the GPU monitor to detect the card again and restart direct temperature, memory and activity readings. Saved preferences stay unchanged.
SolidColor=#GraphBackgroundColor#

[MeterSettingsPowerSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+218*#Scale#)
Text=Power source
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]
ToolTipText=Choose Driver or an explicit HWiNFO power override. Sources do not switch automatically; saved mappings are preserved.

[MeterSettingsPowerSourcePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power',-1)"]
ToolTipText=Choose the previous or next power source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsPowerSourceFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+216*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]
ToolTipText=Choose the previous or next power source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsPowerSourceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+217*#Scale#)
W=(56*#Scale#)
Text=Driver
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power')"]
ToolTipText=Choose the previous or next power source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsPowerSourceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Power',1)"]
ToolTipText=Choose the previous or next power source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsClockSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+246*#Scale#)
Text=Clock source
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]
ToolTipText=Choose Driver for the current graphics clock, or an explicit HWiNFO clock override. This does not change the base and boost specifications in the overview.

[MeterSettingsClockSourcePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock',-1)"]
ToolTipText=Choose the previous or next current-clock source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsClockSourceFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+244*#Scale#)
W=(56*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(56*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]
ToolTipText=Choose the previous or next current-clock source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsClockSourceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+188*#Scale#)
Y=(#Inset#+245*#Scale#)
W=(56*#Scale#)
Text=Driver
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock')"]
ToolTipText=Choose the previous or next current-clock source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsClockSourceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+227*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleSource('Clock',1)"]
ToolTipText=Choose the previous or next current-clock source. Center cycles forward. Saved mappings remain unchanged.

[MeterSettingsSensorsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+274*#Scale#)
Text=HWiNFO overrides
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]
ToolTipText=Enable or disable explicit HWiNFO power and clock overrides. Each reading must also have source HWiNFO selected and a matching Gadget export. Direct driver readings are independent.

[MeterSettingsSensorsValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
Y=(#Inset#+272*#Scale#)
W=(#ContentWidth#-146*#Scale#)
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]
ToolTipText=Enable or disable explicit HWiNFO power and clock overrides. Each reading must also have source HWiNFO selected and a matching Gadget export. Direct driver readings are independent.
X=(#ContentX#+140*#Scale#)

[MeterSettingsHiveLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+302*#Scale#)
Text=Manual hive
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
ToolTipText=Switch between current-user and local-machine HWiNFO exports for optional power and clock readings.
W=(134*#Scale#)

[MeterSettingsHivePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+149*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive(-1)"]
ToolTipText=Choose the previous or next HWiNFO registry hive. Center cycles forward. The custom key remains unchanged.

[MeterSettingsHiveFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame
Group=GPUSettingsUI
X=(#ContentX#+160*#Scale#)
Y=(#Inset#+300*#Scale#)
W=(112*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(112*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
ToolTipText=Choose the previous or next HWiNFO registry hive. Center cycles forward. The custom key remains unchanged.

[MeterSettingsHiveValue]
Meter=String
MeterStyle=StyleSettingsStepperValue
Group=GPUSettingsUI
X=(#ContentX#+216*#Scale#)
Y=(#Inset#+301*#Scale#)
W=(112*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
ToolTipText=Choose the previous or next HWiNFO registry hive. Center cycles forward. The custom key remains unchanged.

[MeterSettingsHiveNext]
Meter=String
MeterStyle=StyleSettingsStepperButton
Group=GPUSettingsUI
X=(#ContentX#+283*#Scale#)
Y=(#Inset#+301*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive(1)"]
ToolTipText=Choose the previous or next HWiNFO registry hive. Center cycles forward. The custom key remains unchanged.

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
ToolTipText=HWiNFO export path for optional power and clock readings. Use Advanced to edit a custom registry key, then reopen settings.
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
ToolTipText=Choose the exported power reading for your GPU. Review its identity and unit. Mapping does not change the source; select HWiNFO above to use it.

[MeterSettingsPowerValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Power')"]
ToolTipText=Choose the exported power reading for your GPU. Review its identity and unit. Mapping does not change the source; select HWiNFO above to use it.

[MeterSettingsPowerClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Power')"]
ToolTipText=Clear only the power mapping. Other GPU settings stay as saved.
SolidColor=#GraphBackgroundColor#

[MeterSettingsClockLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|GPUSettingsLabel
Y=(#Inset#+386*#Scale#)
W=(134*#Scale#)
Text=Clock override
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]
ToolTipText=Choose the exported clock reading for your GPU. Review its identity and unit. Mapping does not change the source; select HWiNFO above to use it.

[MeterSettingsClockValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|GPUSettingsValue
FontColor=#TextColor#
Y=(#Inset#+384*#Scale#)
X=(#ContentX#+140*#Scale#)
W=(#ContentWidth#-212*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]
ToolTipText=Choose the exported clock reading for your GPU. Review its identity and unit. Mapping does not change the source; select HWiNFO above to use it.

[MeterSettingsClockClear]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+384*#Scale#)
X=(#ContentX#+#ContentWidth#-58*#Scale#)
W=(52*#Scale#)
StringAlign=Left
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Clock')"]
ToolTipText=Clear only the clock mapping. Other GPU settings stay as saved.
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
ToolTipText=Read the current export list again for the selected sensor row. Scanning does not enable sensors.
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
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

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
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

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
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

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
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

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
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPrevious]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+564*#Scale#)
X=#ContentX#
W=(70*#Scale#)
Text=< Previous
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "PrevPage()"]
ToolTipText=Show the previous five exported readings.

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
ToolTipText=Show the next five exported readings.

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
ToolTipText=Open the driver temperature and optional HWiNFO power/clock setup guide.
StringAlign=Left

[MeterSettingsAdvanced]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction|StyleSecondaryButton
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+1*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
Text=Advanced
LeftMouseUpAction=["notepad.exe" "#@#User\GPU.inc"]
ToolTipText=Edit advanced GPU options or a custom registry path. Save, reopen these settings, then refresh GPU.
StringAlign=Left

[MeterSettingsRefresh]
Meter=String
MeterStyle=StyleButton|GPUSettingsAction
Y=(#Inset#+620*#Scale#)
X=(#ContentX#+2*(#ContentWidth#+6*#Scale#)/4)
W=((#ContentWidth#-18*#Scale#)/4-6*#Scale#)
Text=Refresh GPU
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]
ToolTipText=Reload the GPU meter with its saved settings, detect its name, memory and base/boost clocks again, and restart direct temperature, memory and activity readings.
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
ToolTipText=Open global Parallax appearance and scale settings.
