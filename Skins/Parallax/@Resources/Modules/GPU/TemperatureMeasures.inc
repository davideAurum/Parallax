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

; History source. Temperature.lua pushes exactly one point per new driver
; sample (the Core percentage), or a 0 per sampling interval while the direct
; reading is unavailable: it sets this Formula to that literal value, then
; forces this measure, MeasureGPUGraphSamples and the Line meter. The
; UpdateDivider=-1 keeps the 1 s skin cycle from plotting a 2 s sample twice.
; The explicit 0-100 range keeps the Line meter's native scaling (AutoScale=0)
; correct.
[MeasureGPUUtilizationHistory]
Measure=Calc
Formula=0
MinValue=0
MaxValue=100
UpdateDivider=-1
