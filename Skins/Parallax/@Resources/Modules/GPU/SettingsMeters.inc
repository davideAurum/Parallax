; Original meters for the independent GPU Settings utility.
; Settings use shared appearance; only explicit controls persist choices.

[GPUSettingsLabel]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=(128*#Scale#)
H=(18*#Scale#)
Group=GPUSettingsUI

[GPUSettingsValue]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#AccentColor#
AntiAlias=1
ClipString=1
StringAlign=Right
X=(#ContentX#+#ContentWidth#)
W=(#ContentWidth#-134*#Scale#)
H=(18*#Scale#)
MouseActionCursor=1
Group=GPUSettingsUI

[GPUSettingsAction]
FontFace=#FontFace#
FontSize=((#FontSize#-1)*#Scale#)
FontWeight=500
FontColor=#AccentColor#
AntiAlias=1
ClipString=1
H=(18*#Scale#)
MouseActionCursor=1
Group=GPUSettingsUI

[GPUSettingsSection]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)
Group=GPUSettingsUI

[MeterSettingsTitle]
Meter=String
MeterStyle=StyleTitle
Y=(#Inset#+6*#Scale#)
X=#ContentX#
W=(#ContentWidth#-32*#Scale#)
H=(18*#Scale#)
Text=GPU Settings
Group=GPUSettingsUI

[MeterSettingsClose]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+6*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(22*#Scale#)
StringAlign=Right
Text=X
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Close()"]
ToolTipText=Close GPU Settings. The GPU meter keeps running and saved choices remain active.

[MeterSettingsDisplaySection]
Meter=String
MeterStyle=GPUSettingsSection
Y=(#Inset#+30*#Scale#)
Text=Display

[MeterSettingsColumnsLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+52*#Scale#)
Text=Meter width
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleColumns()"]
ToolTipText=Switch the GPU meter between one and two columns. This settings window keeps its own size.

[MeterSettingsColumnsValue]
Meter=String
MeterStyle=GPUSettingsValue
Y=(#Inset#+52*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleColumns()"]
ToolTipText=Switch the GPU meter between one and two columns. This settings window keeps its own size.

[MeterSettingsHeightLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+74*#Scale#)
Text=Fit panel height
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
ToolTipText=Set the GPU meter height to 288 logical pixels to fit its current capabilities and sensor rows.

[MeterSettingsHeightValue]
Meter=String
MeterStyle=GPUSettingsValue
Y=(#Inset#+74*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "FitHeight()"]
ToolTipText=Set the GPU meter height to 288 logical pixels to fit its current capabilities and sensor rows.

[MeterSettingsSensorsSection]
Meter=String
MeterStyle=GPUSettingsSection
Y=(#Inset#+100*#Scale#)
W=(#ContentWidth#-80*#Scale#)
Text=HWiNFO sensors

[MeterSettingsSensorsValue]
Meter=String
MeterStyle=GPUSettingsValue
Y=(#Inset#+100*#Scale#)
W=(72*#Scale#)
Text=Off
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]
ToolTipText=Enable or disable the three mapped sensor readings. HWiNFO Gadget export must be configured separately.

[MeterSettingsHiveLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+124*#Scale#)
Text=Registry hive
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
ToolTipText=Switch between current-user and local-machine HWiNFO exports.

[MeterSettingsHiveValue]
Meter=String
MeterStyle=GPUSettingsValue
Y=(#Inset#+124*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "CycleHive()"]
ToolTipText=Switch between current-user and local-machine HWiNFO exports.

[MeterSettingsKeyLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+146*#Scale#)
Text=Registry key

[MeterSettingsKeyValue]
Meter=String
MeterStyle=GPUSettingsValue
Y=(#Inset#+146*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#
MouseActionCursor=0
Text=...
ToolTipText=HWiNFO export path. Use Advanced to edit a custom registry key, then reopen settings.

[MeterSettingsTemperatureLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+170*#Scale#)
W=(86*#Scale#)
Text=Temperature
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Temperature')"]
ToolTipText=Choose the exported temperature reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsTemperatureValue]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+170*#Scale#)
X=(#ContentX#+90*#Scale#)
W=(#ContentWidth#-148*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Temperature')"]
ToolTipText=Choose the exported temperature reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsTemperatureClear]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+170*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(44*#Scale#)
StringAlign=Right
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Temperature')"]
ToolTipText=Clear only the temperature mapping. Other GPU settings stay as saved.

[MeterSettingsPowerLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+194*#Scale#)
W=(86*#Scale#)
Text=Power
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Power')"]
ToolTipText=Choose the exported power reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsPowerValue]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+194*#Scale#)
X=(#ContentX#+90*#Scale#)
W=(#ContentWidth#-148*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Power')"]
ToolTipText=Choose the exported power reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsPowerClear]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+194*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(44*#Scale#)
StringAlign=Right
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Power')"]
ToolTipText=Clear only the power mapping. Other GPU settings stay as saved.

[MeterSettingsClockLabel]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+218*#Scale#)
W=(86*#Scale#)
Text=Clock
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]
ToolTipText=Choose the exported clock reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsClockValue]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+218*#Scale#)
X=(#ContentX#+90*#Scale#)
W=(#ContentWidth#-148*#Scale#)
Text=Unmapped / choose
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Browse('Clock')"]
ToolTipText=Choose the exported clock reading for your GPU. Review the sensor identity and unit before selecting.

[MeterSettingsClockClear]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+218*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(44*#Scale#)
StringAlign=Right
Text=Clear
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Clear('Clock')"]
ToolTipText=Clear only the clock mapping. Other GPU settings stay as saved.

[MeterSettingsPickerTitle]
Meter=String
MeterStyle=GPUSettingsSection
Y=(#Inset#+244*#Scale#)
W=(#ContentWidth#-66*#Scale#)
Text=Choose a sensor row above
Group=GPUSettingsUI|GPUSettingsPicker

[MeterSettingsRescan]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+244*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(58*#Scale#)
StringAlign=Right
Text=Rescan
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Rescan()"]
ToolTipText=Read the current export list again for the selected sensor row. Scanning does not enable sensors.

[MeterSettingsPickerPanel]
Meter=Shape
X=#ContentX#
Y=(#Inset#+260*#Scale#)
W=#ContentWidth#
H=(94*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(94*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
UpdateDivider=-1

[MeterSettingsPick1]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+264*#Scale#)
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(16*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(1)"]
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPick2]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+282*#Scale#)
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(16*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(2)"]
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPick3]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+300*#Scale#)
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(16*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(3)"]
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPick4]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+318*#Scale#)
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(16*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(4)"]
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPick5]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+336*#Scale#)
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(16*#Scale#)
Text=
Group=GPUSettingsUI|GPUSettingsPicker
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "Select(5)"]
ToolTipText=Select this exported sensor for the chosen row. Confirm the GPU identity, measurement and unit.

[MeterSettingsPrevious]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+356*#Scale#)
X=#ContentX#
W=(62*#Scale#)
Text=< Previous
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "PrevPage()"]
ToolTipText=Show the previous five exported readings.

[MeterSettingsPage]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+#ContentWidth#/2)
W=(#ContentWidth#-140*#Scale#)
StringAlign=Center
FontColor=#MutedColor#
MouseActionCursor=0
Text=
Group=GPUSettingsUI|GPUSettingsPicker

[MeterSettingsNext]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+356*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(62*#Scale#)
StringAlign=Right
Text=Next >
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "NextPage()"]
ToolTipText=Show the next five exported readings.

[MeterSettingsNotice]
Meter=String
MeterStyle=GPUSettingsLabel
Y=(#Inset#+376*#Scale#)
W=#ContentWidth#
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#
Text=Changes save immediately.

[MeterSettingsGuide]
Meter=String
MeterStyle=GPUSettingsAction|StyleSecondaryButton
Y=(#Inset#+400*#Scale#)
X=#ContentX#
W=(38*#Scale#)
Text=Guide
LeftMouseUpAction=["notepad.exe" "#@#Modules\GPU\Mapping.txt"]
ToolTipText=Open the HWiNFO export setup and GPU mapping guide.

[MeterSettingsAdvanced]
Meter=String
MeterStyle=GPUSettingsAction|StyleSecondaryButton
Y=(#Inset#+400*#Scale#)
X=(#ContentX#+48*#Scale#)
W=(64*#Scale#)
Text=Advanced
LeftMouseUpAction=["notepad.exe" "#@#User\GPU.inc"]
ToolTipText=Edit advanced GPU options or a custom registry path. Save, reopen these settings, then refresh GPU.

[MeterSettingsRefresh]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+400*#Scale#)
X=(#ContentX#+124*#Scale#)
W=(78*#Scale#)
Text=Refresh GPU
LeftMouseUpAction=[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]
ToolTipText=Reload the GPU meter with its saved settings and query its capabilities again.

[MeterSettingsGlobal]
Meter=String
MeterStyle=GPUSettingsAction
Y=(#Inset#+400*#Scale#)
X=(#ContentX#+#ContentWidth#)
W=(100*#Scale#)
StringAlign=Right
Text=Global settings
LeftMouseUpAction=[!ActivateConfig "Parallax\Settings" "Settings.ini"]
ToolTipText=Open global Parallax appearance and scale settings.
