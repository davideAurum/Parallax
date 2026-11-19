; Row clicks and Refresh in Media.ini's queue drawer: QueueReader.lua hands a
; click to QueueControl.lua, which runs one short hidden QueueProvider.ps1
; request (Play or Refresh) on this host; the running helper does the Spotify
; work. The same pair as the standalone Queue.ini, inert until a click supplies
; the command. Media.ini only: Setup holds nothing that can launch beyond the
; two resume hosts, so its rows are never clickable and it has no Refresh.
; Included after InlineQueueGeometry.inc, so this width wins there.
[Variables]
MediaQueueRefreshWidth=(18*#Scale#)
MediaRefreshGlyph=(14*#Scale#/24)

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
; the standalone panel's actions use: Lucide refresh-cw (Icons\Lucide, pinned
; revision) at the queue icon's 14/24 scale and 2-unit round stroke, centred in
; an 18S box (2026-11-19; it was the word Refresh). A click's outcome replaces
; the "Song / Artist" text beside it. SVG sweep=1 arcs map to Rainmeter's
; clockwise SweepDirection=0.
[MeterQueueRefresh]
Meter=Shape
X=(#MediaQueueX#+#MediaQueueWidth#-18*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
Y=#MediaQueueHeaderY#
AntiAlias=1
Group=QueueRows
Hidden=1
UpdateDivider=-1
Shape=Rectangle 0,0,(18*#Scale#),(18*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Path MediaRefreshArcTop | Extend MediaRefreshStroke
Shape3=Path MediaRefreshHeadTop | Extend MediaRefreshStroke
Shape4=Path MediaRefreshArcBottom | Extend MediaRefreshStroke
Shape5=Path MediaRefreshHeadBottom | Extend MediaRefreshStroke
MediaRefreshStroke=Fill Color 0,0,0,0 | Stroke Color #AccentColor# | StrokeWidth (2*#MediaRefreshGlyph#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset (2*#Scale#),(2*#Scale#)
MediaRefreshArcTop=(3*#MediaRefreshGlyph#),(12*#MediaRefreshGlyph#) | ArcTo (12*#MediaRefreshGlyph#),(3*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),0,0,0 | ArcTo (18.74*#MediaRefreshGlyph#),(5.74*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),0,0,0 | LineTo (21*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#)
MediaRefreshHeadTop=(21*#MediaRefreshGlyph#),(3*#MediaRefreshGlyph#) | LineTo (21*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#) | LineTo (16*#MediaRefreshGlyph#),(8*#MediaRefreshGlyph#)
MediaRefreshArcBottom=(21*#MediaRefreshGlyph#),(12*#MediaRefreshGlyph#) | ArcTo (12*#MediaRefreshGlyph#),(21*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),(9*#MediaRefreshGlyph#),0,0,0 | ArcTo (5.26*#MediaRefreshGlyph#),(18.26*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),(9.75*#MediaRefreshGlyph#),0,0,0 | LineTo (3*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#)
MediaRefreshHeadBottom=(8*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#) | LineTo (3*#MediaRefreshGlyph#),(16*#MediaRefreshGlyph#) | LineTo (3*#MediaRefreshGlyph#),(21*#MediaRefreshGlyph#)
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureQueueControl "Run('Refresh')"]
