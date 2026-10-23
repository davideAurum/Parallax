; Parallax idle stand-down hook (Global Settings "Idle pause"; docs/ARCHITECTURE.md
; "Idle stand-down"). Loaded only through Hook5/10/30.inc, which every utility
; entrypoint includes as its LAST section ([ParallaxIdleHookInclude]), so the
; "Paused (idle)" line draws on top. The entrypoint, after its own includes,
; sets the line's placement (ParallaxPausedX/Y/W/H/Align), names the headline
; meters the line replaces (ParallaxIdleHeadline, hidden while paused) and any
; gear/value hover pair (ParallaxIdleHoverSwap), names its module controllers
; (ParallaxIdleControllers) and derives the hook's divider
; (ParallaxIdleHookDivider, about ParallaxIdleHookMs of its own ticks).
;
; Groups this hook acts on (docs/ARCHITECTURE.md; tools/tests/
; test_idle_freeze_contract.py checks them statically):
;   ParallaxIdleFreeze  every meter that can repaint (meters only)
;   ParallaxIdlePause   every periodic measure except this hook, join and
;                       lease members, RunCommand hosts and Media's lifecycle

[Variables]
; Coordinator state for this load (Parallax\Idle broadcasts with
; !SetVariableGroup; ignored until ParallaxIdleSync=1).
ParallaxIdleAway=0
ParallaxIdlePaused=0
ParallaxIdleSync=0
ParallaxIdleBeat=0
; Appended to the skin's hover actions before their !Redraw: while paused, a
; hover-out that shows the frozen headline value has it hidden again.
ParallaxIdleHoverAction=[!CommandMeasure MeasureParallaxStandDown "Hover()"]

[MeasureParallaxStandDown]
Measure=Script
ScriptFile=#@#Idle\StandDown.lua
; Forced by each coordinator broadcast and by the delayed joins; its own
; schedule (about a minute) only watches for a coordinator that went quiet.
; Never paused.
Group=ParallaxIdleHook | ParallaxIdleJoin
UpdateDivider=#ParallaxIdleHookDivider#

; Takes the headline's place while paused: StandDown.lua hides the
; ParallaxIdleHeadline meters, so a stale headline is never shown as current.
; No fill: covering is not hiding once Global Settings Background transparency
; makes BackgroundColor translucent. Frozen values elsewhere stay visible.
[MeterParallaxPaused]
Meter=String
MeterStyle=StyleLabel
X=#ParallaxPausedX#
Y=#ParallaxPausedY#
W=#ParallaxPausedW#
H=#ParallaxPausedH#
StringAlign=#ParallaxPausedAlign#
FontColor=#MutedColor#
Text=Paused (idle)
Hidden=1
UpdateDivider=-1
