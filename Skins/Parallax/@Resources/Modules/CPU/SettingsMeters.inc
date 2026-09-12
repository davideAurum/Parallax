; Visible controls for the independent CPU Settings utility.
; Settings.lua updates values only on load and explicit user actions.

[CPUStyleSettingsSection]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontWeight=600
FontColor=#HeaderTextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)
Group=CPUSettingsUI

[CPUStyleSettingsLabel]
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
Group=CPUSettingsUI

[CPUStyleSettingsValue]
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
Group=CPUSettingsUI

[CPUStyleSettingsRow]
X=(#ContentX#+4*#Scale#)
W=(#ContentWidth#-8*#Scale#)
H=(24*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-8*#Scale#),(24*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
MouseActionCursor=1
Group=CPUSettingsUI

[MeterSettingsTitle]
Meter=String
MeterStyle=StyleTitle
X=#ContentX#
Y=(#Inset#+6*#Scale#)
W=(#ContentWidth#-28*#Scale#)
H=(20*#Scale#)
Text=CPU Settings
Group=CPUSettingsUI

[MeterSettingsClose]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+6*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!DeactivateConfig]
ToolTipText=Close CPU Settings. Saved choices stay active and the CPU meter keeps running.
Group=CPUSettingsUI
FontSize=(#FontSize#*#Scale#)

[MeterSettingsInfoSection]
Meter=String
MeterStyle=CPUStyleSettingsSection
Y=(#Inset#+30*#Scale#)
Text=Processor Info

[MeterSettingsInfoRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+48*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowInfo')"]
ToolTipText=Show or hide the processor name and physical/logical core counts.

[MeterSettingsInfoLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+52*#Scale#)
Text=Show processor info
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowInfo')"]
ToolTipText=Show or hide the processor name and physical/logical core counts.

[MeterSettingsInfoValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+52*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowInfo')"]
ToolTipText=Show or hide the processor name and physical/logical core counts.

[MeterSettingsTableSection]
Meter=String
MeterStyle=CPUStyleSettingsSection
Y=(#Inset#+80*#Scale#)
Text=CPU Table

[MeterSettingsCoresRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+98*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowCores')"]
ToolTipText=Show or hide individual logical processor usage rows.

[MeterSettingsCoresLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+102*#Scale#)
Text=Show CPU table
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowCores')"]
ToolTipText=Show or hide individual logical processor usage rows.

[MeterSettingsCoresValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+102*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowCores')"]
ToolTipText=Show or hide individual logical processor usage rows.

[MeterSettingsDecimalsRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+126*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ToggleDecimals()"]
ToolTipText=Switch CPU usage percentages between whole numbers and one decimal place. Applies to total and logical processor values.

[MeterSettingsDecimalsLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+130*#Scale#)
Text=Percentage decimals
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ToggleDecimals()"]
ToolTipText=Switch CPU usage percentages between whole numbers and one decimal place. Applies to total and logical processor values.

[MeterSettingsDecimalsValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+130*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ToggleDecimals()"]
ToolTipText=Switch CPU usage percentages between whole numbers and one decimal place. Applies to total and logical processor values.

[MeterSettingsProcessesSection]
Meter=String
MeterStyle=CPUStyleSettingsSection
Y=(#Inset#+158*#Scale#)
Text=Top Process List

[MeterSettingsProcessesRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+176*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowProcesses')"]
ToolTipText=Show or hide the list of processes using the most CPU.

[MeterSettingsProcessesLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+180*#Scale#)
Text=Show top process list
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowProcesses')"]
ToolTipText=Show or hide the list of processes using the most CPU.

[MeterSettingsProcessesValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+180*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowProcesses')"]
ToolTipText=Show or hide the list of processes using the most CPU.

[MeterSettingsProcessCountRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+204*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleProcessCount()"]
ToolTipText=Cycle the maximum number of listed processes through 3, 5 and 10.

[MeterSettingsProcessCountLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+208*#Scale#)
Text=Processes shown
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleProcessCount()"]
ToolTipText=Cycle the maximum number of listed processes through 3, 5 and 10.

[MeterSettingsProcessCountValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+208*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleProcessCount()"]
ToolTipText=Cycle the maximum number of listed processes through 3, 5 and 10.

[MeterSettingsGraphSection]
Meter=String
MeterStyle=CPUStyleSettingsSection
Y=(#Inset#+236*#Scale#)
Text=Graph

[MeterSettingsHistoryRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+254*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowHistory')"]
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.

[MeterSettingsHistoryLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+258*#Scale#)
Text=Show graph
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowHistory')"]
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.

[MeterSettingsHistoryValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+258*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUShowHistory')"]
ToolTipText=Show or hide the CPU usage history graph. Changing this option starts a fresh history.

[MeterSettingsSamplesRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+282*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySamples()"]
ToolTipText=Cycle the history capacity through 30, 60, 120 and 300 samples. Changing capacity starts a fresh history.

[MeterSettingsSamplesLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+286*#Scale#)
Text=History samples
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySamples()"]
ToolTipText=Cycle the history capacity through 30, 60, 120 and 300 samples. Changing capacity starts a fresh history.

[MeterSettingsSamplesValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+286*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleHistorySamples()"]
ToolTipText=Cycle the history capacity through 30, 60, 120 and 300 samples. Changing capacity starts a fresh history.

[MeterSettingsSensorsSection]
Meter=String
MeterStyle=CPUStyleSettingsSection
Y=(#Inset#+314*#Scale#)
Text=HWiNFO Setup

[MeterSettingsSensorsRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+332*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUSensorsEnabled')"]
ToolTipText=Enable CPU sensor readings exposed by HWiNFO. Shared CPU/package readings are repeated in logical-processor rows.

[MeterSettingsSensorsLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+336*#Scale#)
Text=Enable sensor readings
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUSensorsEnabled')"]
ToolTipText=Enable CPU sensor readings exposed by HWiNFO. Shared CPU/package readings are repeated in logical-processor rows.

[MeterSettingsSensorsValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+336*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "Toggle('CPUSensorsEnabled')"]
ToolTipText=Enable CPU sensor readings exposed by HWiNFO. Shared CPU/package readings are repeated in logical-processor rows.

[MeterSettingsOpenHWiNFO]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+4*#Scale#+0*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+364*#Scale#)
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

[MeterSettingsGuide]
Meter=String
MeterStyle=StyleButton|StyleSecondaryButton
X=(#ContentX#+4*#Scale#+1*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+364*#Scale#)
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

[MeterSettingsScan]
Meter=String
MeterStyle=StyleButton
X=(#ContentX#+4*#Scale#+2*((#ContentWidth#-16*#Scale#)/3+4*#Scale#))
Y=(#Inset#+364*#Scale#)
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

[MeterSettingsSensorGuide1]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+398*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=1. Open Sensors, then click the gear.
Group=CPUSettingsUI
ToolTipText=1. Open Sensors, then click the gear.

[MeterSettingsSensorGuide2]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+416*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=2. HWiNFO Gadget > Enable reporting to Gadget.
Group=CPUSettingsUI
ToolTipText=2. HWiNFO Gadget > Enable reporting to Gadget.

[MeterSettingsSensorGuide3]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+434*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=3. Pick CPU Package, then Vcore (or Core VIDs).
Group=CPUSettingsUI
ToolTipText=Select CPU Package temperature, enable Report value in Gadget, then repeat for Vcore or Core VIDs under CPU [#0].

[MeterSettingsSensorGuide4]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+452*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=4. Report value in Gadget for each. OK, then scan.
Group=CPUSettingsUI
ToolTipText=Enable Report value in Gadget separately for each chosen sensor, click OK to save in HWiNFO, then click Scan sensors here.

[MeterSettingsSensorStatus]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+472*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
ClipString=2
Text=Last scan: not yet available
ToolTipText=Results from the last sensor scan. Scanning is a snapshot, not continuous telemetry.
Group=CPUSettingsUI

[MeterSettingsSensorDetail]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+490*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(36*#Scale#)
FontSize=(#FontSize#*#Scale#)
ClipString=2
Text=Scan sensors to inspect the exported readings. These are snapshot results.
ToolTipText=Results from the last sensor scan. Scanning is a snapshot, not continuous telemetry.
Group=CPUSettingsUI

[MeterSettingsTemperatureRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+528*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('TEMP')"]
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.

[MeterSettingsTemperatureLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+532*#Scale#)
W=(90*#Scale#)
Text=Temperature
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('TEMP')"]
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.

[MeterSettingsTemperatureValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+532*#Scale#)
W=(#ContentWidth#-115*#Scale#)
Text=Auto
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('TEMP')"]
ToolTipText=Choose automatic detection or one of the CPU temperature exports found in the last scan.

[MeterSettingsVoltageRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+560*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('VOLT')"]
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.

[MeterSettingsVoltageLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+564*#Scale#)
W=(90*#Scale#)
Text=Voltage
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('VOLT')"]
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.

[MeterSettingsVoltageValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+564*#Scale#)
W=(#ContentWidth#-115*#Scale#)
Text=Auto
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensor('VOLT')"]
ToolTipText=Choose automatic detection or one of the Vcore or VID exports found in the last scan. VID is requested voltage.

[MeterSettingsSensorHiveRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+592*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive()"]
ToolTipText=Cycle the registry search scope between automatic detection, current user (HKCU), and local machine (HKLM).

[MeterSettingsSensorHiveLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+596*#Scale#)
W=(90*#Scale#)
Text=Search scope
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive()"]
ToolTipText=Cycle the registry search scope between automatic detection, current user (HKCU), and local machine (HKLM).

[MeterSettingsSensorHiveValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+596*#Scale#)
W=(#ContentWidth#-115*#Scale#)
Text=Auto
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "CycleSensorHive()"]
ToolTipText=Cycle the registry search scope between automatic detection, current user (HKCU), and local machine (HKLM).

[MeterSettingsReconnectRow]
Meter=Shape
MeterStyle=CPUStyleSettingsRow
Y=(#Inset#+624*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ReconnectSensors()"]
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.

[MeterSettingsReconnectLabel]
Meter=String
MeterStyle=CPUStyleSettingsLabel
Y=(#Inset#+628*#Scale#)
Text=Apply / reconnect
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ReconnectSensors()"]
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.

[MeterSettingsReconnectValue]
Meter=String
MeterStyle=CPUStyleSettingsValue
Y=(#Inset#+628*#Scale#)
Text=Retry
LeftMouseUpAction=[!CommandMeasure MeasureCPUSettings "ReconnectSensors()"]
ToolTipText=Apply the chosen sensor selections, rescan HWiNFO exports, and reconnect the loaded CPU meter.

[MeterSettingsSensorsHint]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+656*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=CPU-wide sensors: temperature + voltage / VID
ToolTipText=These are shared CPU/package readings repeated in every logical-processor row, not per-thread sensors. Vcore is preferred; VID is requested voltage, not a measured supply voltage, and is labeled explicitly if used.
Group=CPUSettingsUI

[MeterSettingsHint]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+676*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Changes apply immediately and are saved.
Group=CPUSettingsUI

[MeterSettingsIndependence]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+6*#Scale#)
Y=(#Inset#+694*#Scale#)
W=(#ContentWidth#-12*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
Text=Close this window independently of the CPU meter.
Group=CPUSettingsUI

