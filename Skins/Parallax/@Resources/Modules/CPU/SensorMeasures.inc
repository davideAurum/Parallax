; Native HWiNFO Gadget reads. No shared-memory plugin and no subprocess polling.
[MeasureCPUHWiNFORunning]
Measure=Process
ProcessName=HWiNFO64.exe
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorNamesUser]
Measure=Registry
Disabled=1
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorNamesMachine]
Measure=Registry
Disabled=1
RegHKey=HKEY_LOCAL_MACHINE
RegKey=SOFTWARE\HWiNFO64\VSB
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorTemperatureSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorTemperatureLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorTemperatureFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorTemperatureRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorVoltageSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorVoltageLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorVoltageFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorVoltageRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))
Group=CPUSensorNative

[MeasureCPUSensorDiscover]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\CPU\
Parameter=-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "DiscoverSensors.ps1"
State=Hide
OutputType=UTF8
Timeout=10000
UpdateDivider=1
FinishAction=[!UpdateMeasure MeasureCPUSensorDiscover][!CommandMeasure MeasureCPUSensors "ApplyDiscovery()"]

[MeasureCPUSensors]
Measure=Script
ScriptFile=#@#Modules\CPU\Sensors.lua
UpdateDivider=(Max(1,Ceil(#SensorInterval#/Max(1,#MetricsInterval#))))

[MeasureCPUSensorReconnect]
Measure=Calc
Formula=0
UpdateDivider=-1
Group=ParallaxCPUSensorReconnect
OnUpdateAction=[!CommandMeasure MeasureCPUSensors "Reconnect()"]
