; One bounded launcher (plain PowerShell, no compile) mints the random
; session, writes its lease, starts the persistent direct-driver host hidden
; and detached, and exits once the host holds its Rainmeter ancestor, so no
; RunCommand thread stays attached to it. The host stops when that ancestor
; exits, when its session lease lapses, or when the controller removes the
; lease on close. No command runs per sample.
[MeasureGPUTemperatureLauncher]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\GPU\
Parameter=
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=1

[MeasureGPUTemperatureController]
Measure=Script
Group=ParallaxIdlePause
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
