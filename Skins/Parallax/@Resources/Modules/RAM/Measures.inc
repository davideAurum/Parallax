; Live physical memory uses native measures with no process polling.
; PhysicalMemory supplies bytes with a native 0..total physical RAM range.
[MeasureRAMUsed]
Measure=PhysicalMemory
UpdateDivider=1

[MeasureRAMTotal]
Measure=PhysicalMemory
Total=1
UpdateDivider=1

; Paging-file-only accounting comes from one resident EnumPageFiles host; no
; shell is launched per poll. One bounded launcher (plain PowerShell, no
; compile) mints the random session, writes its lease, starts the host hidden
; and detached, waits until it has captured its Rainmeter ancestor, then
; exits, so no RunCommand thread stays attached to it. The host's lifetime
; rests on the session lease, that retained ancestor handle and the skin
; removing the lease on close.
[MeasureRAMPageLauncher]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\RAM\
Parameter=
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=1

[MeasureRAMPageView]
Measure=Script
ScriptFile=#@#Modules\RAM\PageFile.lua
UpdateDivider=1

; Cached PAGE ratio only. The display bridge updates this Calc on new data;
; it performs no query and does not sample physical-memory history.
[MeasureRAMPageRatio]
Measure=Calc
Formula=0
MinValue=0
MaxValue=1
UpdateDivider=-1

; Self reference starts at zero on load AND refresh; global Counter does not.
; Match the Line meter's update cadence. This is a sample count, not telemetry.
; Once the plot holds ContentWidth samples the cover has zero width until the
; next refresh. Retire it then: hide it and stop its per-tick Shape rebuild and
; this count (UpdateDivider=-1 keeps the full count). Refresh restarts both.
[MeasureRAMHistorySamples]
Measure=Calc
Formula=Min(MeasureRAMHistorySamples+1,#ContentWidth#)
IfCondition=MeasureRAMHistorySamples >= #ContentWidth#
IfTrueAction=[!HideMeter MeterRAMHistoryUncollected][!SetOption MeterRAMHistoryUncollected UpdateDivider -1][!SetOption MeasureRAMHistorySamples UpdateDivider -1]
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

; Watches cached command status, settles wrapped layout, then disables updates.
[MeasureRAMInfoView]
Measure=Script
ScriptFile=#@#Modules\RAM\Info.lua
UpdateDivider=1

; Bundled UsageMonitor ranks private resident memory in bytes. All five
; measures share its Process category worker, which samples independently at 1 Hz.

[MeasureRAMProcess1]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=1
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess2]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=2
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess3]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=3
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess4]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=4
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

[MeasureRAMProcess5]
Measure=Plugin
Plugin=UsageMonitor
Alias=RAM
Index=5
Rollup=1
Percent=0
Blacklist=_Total|Idle
UpdateDivider=1

; Runs after the ranked measures; preferences reformat its cached sample only.
[MeasureRAMProcessView]
Measure=Script
ScriptFile=#@#Modules\RAM\Process.lua
UpdateDivider=1
