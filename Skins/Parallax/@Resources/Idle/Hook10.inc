; Idle pause after 10 minutes without keyboard or mouse input (Global Settings;
; User\Settings.inc IdlePauseMinutes=10). The coordinator (Parallax\Idle) applies
; the minutes; every on-value loads the same stand-down hook.
[Variables]
; Delayed joins of the Parallax\Idle coordinator, after the load's own first
; update and Rainmeter's startup walk: at 100 ms, and again at 10.6 s so a
; load built in standby can fail live without waiting for the hook's own
; 60-second schedule. Group targets stay silent if a reload removed the hook.
ParallaxIdleJoinAction=[!Delay 100][!UpdateMeasureGroup ParallaxIdleJoin][!Delay 10500][!UpdateMeasureGroup ParallaxIdleJoin]
@IncludeParallaxIdleHook=#@#Idle\Hook.inc
