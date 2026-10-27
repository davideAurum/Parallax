; Row clicks and Refresh in Media.ini's queue drawer: QueueReader.lua hands a
; click to QueueControl.lua, which runs one short hidden QueueProvider.ps1
; request (Play or Refresh) on this host; the running helper does the Spotify
; work. The same pair as the standalone Queue.ini, inert until a click supplies
; the command. Media.ini only: Setup holds nothing that can launch beyond the
; two resume hosts, so its rows are never clickable and it has no Refresh.
; Included after InlineQueueGeometry.inc, so this width wins there.
[Variables]
MediaQueueRefreshWidth=(56*#Scale#)

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

; Asks the running helper to read the queue now (QueueControl.lua Refresh).
; Right end of the drawer's header row (InlineQueueMeters.inc), in the accent
; the standalone panel's actions use. A click's outcome replaces the
; "Song / Artist" text beside it.
[MeterQueueRefresh]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueX#+#MediaQueueWidth#)
W=#MediaQueueRefreshWidth#
H=(18*#Scale#)
Y=#MediaQueueHeaderY#
StringAlign=Right
FontColor=#AccentColor#
SolidColor=0,0,0,1
Group=QueueRows
Hidden=1
Text=Refresh
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Refresh')"]
UpdateDivider=-1
