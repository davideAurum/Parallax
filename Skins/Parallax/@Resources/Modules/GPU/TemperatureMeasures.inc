; One bounded setup command, followed by one persistent direct-driver host.
; RunCommand owns the hidden process and kills it on unload. A session lease
; also bounds startup/unload races. No command is launched per sample.
[MeasureGPUTemperatureBootstrap]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\GPU\
Parameter=
State=Hide
OutputType=UTF8
Timeout=12000
UpdateDivider=1

[MeasureGPUTemperatureDriver]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\GPU\
Parameter=
State=Hide
OutputType=UTF8
Timeout=-1
UpdateDivider=1

[MeasureGPUTemperatureController]
Measure=Script
ScriptFile=#@#Modules\GPU\Temperature.lua

; Temperature.lua returns the driver's GPU busy percentage as this Script
; measure's number (0 while the direct reading is unavailable) and the
; process-name packet as its string. Wrapping it in an explicit 0-100 range
; keeps the Line meter's native scaling (AutoScale=0) correct. It sits after
; the controller so each update traces the sample just read.
[MeasureGPUUtilizationHistory]
Measure=Calc
Formula=MeasureGPUTemperatureController
MinValue=0
MaxValue=100
UpdateDivider=1
