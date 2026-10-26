; The one-shot install helper, shared by Global Settings and the update prompt.
; Update.lua sets Parameter and runs it once per Update click; the helper
; downloads and verifies the package, opens Rainmeter's Skin Installer and
; exits, reporting one PARALLAX_UPDATE_V1 line that Update.lua reads as data.
[MeasureParallaxUpdateInstall]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
Parameter=-NoProfile -NonInteractive
State=Hide
OutputType=UTF8
Timeout=180000
FinishAction=[!UpdateMeasure MeasureParallaxUpdateInstall][!CommandMeasure MeasureParallaxUpdate "InstallDone()"]
UpdateDivider=-1
DynamicVariables=1
