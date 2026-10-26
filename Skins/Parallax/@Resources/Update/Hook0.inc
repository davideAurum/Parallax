; Automatic update check is Off (Global Settings > Updates > Auto check;
; User\Settings.inc UpdateCheck=0). Utility entrypoints include
; @Resources\Update\Hook#UpdateCheck#.inc; this variant adds nothing, so no
; background check runs and nothing contacts the network. Hook1.inc loads
; the check. A hand-edited value has no file: Rainmeter logs the missing
; include and the skin runs as with Off.
