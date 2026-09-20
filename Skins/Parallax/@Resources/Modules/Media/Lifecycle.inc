; Used only by Player, Setup and standalone Queue, never by Settings.
[MeasureMediaLifecycle]
Measure=Script
ScriptFile=#@#Modules\Media\MediaLifecycle.lua
UpdateDivider=-1

; Hidden launch hosts for the one-shot resume commands. Rainmeter's own [] file
; bang ShellExecutes with a visible show state, so console-subsystem
; powershell.exe gets a console before it can parse -WindowStyle Hidden and hide
; itself: measured at ~230ms of visible window per launch. RunCommand creates the
; process with SW_HIDE instead, so no console is ever shown. This is the same
; hidden host the Settings panel and standalone queue already use for provider
; control; the lifecycle path was the only launcher still using a raw bang.
;
; Both hosts stay inert. No Program, no Parameter, no update, no finish action
; and no starting command, so loading a view cannot run anything: only
; ResumeProviders() can, and only after its own path, profile and opt-in checks
; pass and it supplies the validated command itself. One host per provider,
; because a second Run cannot reuse a host that is still launching.
[MeasureMediaSourceResume]
Measure=Plugin
Plugin=RunCommand
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=-1
DynamicVariables=1

[MeasureMediaQueueResume]
Measure=Plugin
Plugin=RunCommand
State=Hide
OutputType=UTF8
Timeout=15000
UpdateDivider=-1
DynamicVariables=1
