; Global Settings > Developer: the controller script and the one-shot helper launcher.
; DevPanel.lua sets Parameter and runs the measure once per click (Dev mode on or off,
; Compare); the helper (@Resources\Dev\DevMode.ps1) reports ASCII protocol lines that
; DevPanel.lua reads as data. Nothing polls and no process stays running.
[MeasureDevPanel]
Measure=Script
ScriptFile=#@#Dev\DevPanel.lua

[MeasureDevPanelRun]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
Parameter=-NoProfile -NonInteractive
State=Hide
OutputType=UTF8
Timeout=120000
FinishAction=[!UpdateMeasure MeasureDevPanelRun][!CommandMeasure MeasureDevPanel "Finished()"]
UpdateDivider=-1
DynamicVariables=1
