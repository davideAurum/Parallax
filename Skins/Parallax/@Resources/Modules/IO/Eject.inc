; One-shot eject, launched only by a click on a removable or optical drive's
; eject icon. IO.lua validates the letter, sets Parameter, then Runs; State=Hide
; keeps the console from flashing. Parameter runs the bundled Eject.ps1: the
; taskbar's device-eject request for removable drives, a tray open for optical.
; The finish action re-reads the inventory so an ejected drive leaves promptly.
[MeasureIOEject]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
Parameter=-NoLogo -NoProfile -NonInteractive
State=Hide
OutputType=UTF8
Timeout=30000
UpdateDivider=-1
DynamicVariables=1
FinishAction=[!CommandMeasure MeasureIO "EjectFinished()"]
