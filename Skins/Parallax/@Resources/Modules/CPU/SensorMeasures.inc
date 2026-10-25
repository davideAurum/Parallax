; Native Windows aggregate clock. Processor Frequency is the nominal/current
; P-state frequency; Processor Performance carries turbo and throttling. Their
; product follows Windows' aggregate performance-clock model without a helper.
[MeasureCPUNativeFrequency]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Category=Processor Information
Counter=Processor Frequency
Name=_Total
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=10000
UpdateDivider=1

[MeasureCPUNativePerformance]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Category=Processor Information
Counter=% Processor Performance
Name=_Total
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=1000
UpdateDivider=1

[MeasureCPUNativeClock]
Measure=Calc
Group=ParallaxIdlePause
Formula=(MeasureCPUNativeFrequency>0 && MeasureCPUNativePerformance>0 ? MeasureCPUNativeFrequency*MeasureCPUNativePerformance/100 : 0)
MinValue=0
MaxValue=10000
UpdateDivider=1

; Native HWiNFO Gadget reads. No shared-memory plugin and no subprocess polling.
[MeasureCPUHWiNFORunning]
Measure=Process
ProcessName=HWiNFO64.exe
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorNamesUser]
Measure=Registry
Disabled=1
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorNamesMachine]
Measure=Registry
Disabled=1
RegHKey=HKEY_LOCAL_MACHINE
RegKey=SOFTWARE\HWiNFO64\VSB
OutputType=ValueList
OutputDelimiter=|
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorTemperatureSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorTemperatureLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorTemperatureFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorTemperatureRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorVoltageSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorVoltageLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorVoltageFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorVoltageRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorClockSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorClockLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorClockFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorClockRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorFanSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorFanLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorFanFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorFanRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorMotherboardFanSensor]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Sensor0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorMotherboardFanLabel]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Label0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorMotherboardFanFormatted]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=Value0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[MeasureCPUSensorMotherboardFanRaw]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=SOFTWARE\HWiNFO64\VSB
RegValue=ValueRaw0
Disabled=1
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))
Group=CPUSensorNative|ParallaxIdlePause

[CPUCoreSensorMeasureInclude]
@Include10=#@#Modules\CPU\CoreSensorMeasures.inc

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
Group=ParallaxIdlePause
ScriptFile=#@#Modules\CPU\Sensors.lua
UpdateDivider=(Max(1,Ceil(#CPUSensorInterval#/Max(1,#CPUUpdateInterval#))))

[MeasureCPUSensorReconnect]
Measure=Calc
Formula=0
UpdateDivider=-1
Group=ParallaxCPUSensorReconnect
OnUpdateAction=[!CommandMeasure MeasureCPUSensors "Reconnect()"]
