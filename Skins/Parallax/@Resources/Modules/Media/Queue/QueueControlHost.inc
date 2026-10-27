; Row clicks and Refresh in Media.ini's queue drawer: QueueReader.lua hands a
; click to QueueControl.lua, which runs one short hidden QueueProvider.ps1
; request (Play or Refresh) on this host; the running helper does the Spotify
; work. The same pair as the standalone Queue.ini, inert until a click supplies
; the command. Media.ini only: Setup holds nothing that can launch beyond the
; two resume hosts, so its rows are never clickable.
[MeasureQueueControl]
Measure=Script
ScriptFile=#@#Modules\Media\Queue\QueueControl.lua
UpdateDivider=-1

[MeasureQueueProviderControl]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\Media\Queue\
Parameter=-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "Refresh" -Quiet
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=-1
DynamicVariables=1
