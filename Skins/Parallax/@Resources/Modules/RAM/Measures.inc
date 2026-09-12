; Live physical memory uses native measures with no process polling.
; PhysicalMemory supplies bytes with a native 0..total physical RAM range.
[MeasureRAMUsed]
Measure=PhysicalMemory
UpdateDivider=1

[MeasureRAMAvailable]
Measure=PhysicalMemory
InvertMeasure=1
UpdateDivider=1

[MeasureRAMTotal]
Measure=PhysicalMemory
Total=1
UpdateDivider=1

; Self reference starts at zero on load AND refresh; global Counter does not.
; Match the Line meter's update cadence. This is a sample count, not telemetry.
[MeasureRAMHistorySamples]
Measure=Calc
Formula=Min(MeasureRAMHistorySamples+1,#ContentWidth#)
UpdateDivider=1

; Event-only display bridge. Settings updates this group without resampling.
[MeasureRAMSettings]
Measure=Script
ScriptFile=#@#Modules\RAM\Display.lua
Group=ParallaxRAMApply
UpdateDivider=-1

; One hidden, bounded Windows inventory query on refresh. Updating RunCommand
; reads its cached result; only the entrypoint OnRefreshAction launches it.
[MeasureRAMInfo]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\RAM\
Parameter=-NoLogo -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); try { & ([ScriptBlock]::Create([IO.File]::ReadAllText('MemoryInfo.ps1.txt'))) } catch { [Console]::Write('UNAVAILABLE') }"
State=Hide
OutputType=UTF8
Timeout=12000
UpdateDivider=1
FinishAction=[!UpdateMeasure MeasureRAMInfo][!CommandMeasure MeasureRAMInfoView "Complete()"]

; Watches only the cached command status until settled, then disables updates.
[MeasureRAMInfoView]
Measure=Script
ScriptFile=#@#Modules\RAM\Info.lua
UpdateDivider=1
