; Idle pause is Off (Global Settings; User\Settings.inc IdlePauseMinutes=0).
; Utility entrypoints include @Resources\Idle\Hook#IdlePauseMinutes#.inc as their
; last section; this variant adds nothing, so no stand-down hook, idle
; coordinator join or "Paused (idle)" line is loaded. Hook5/10/30.inc load
; the hook (Hook.inc). A hand-edited value has no file: Rainmeter logs the
; missing include and the skin runs as with Off.
