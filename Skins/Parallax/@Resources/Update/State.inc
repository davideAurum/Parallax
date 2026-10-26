; Runtime state of the update check, shared by Global Settings, the update
; prompt and the check in each utility. Not a preference: only
; @Resources\Update\Update.lua writes this file, no skin includes it, and a
; release install replaces it with these blanks, so an upgraded copy checks
; again about a minute after it loads.
[Variables]
; os.time() when the last check started, and when its result arrived.
UpdateCheckedAt=0
UpdateResultAt=0
; current, available, offline, missing, ratelimit or format; empty until the
; first check reports.
UpdateResult=
; The newest release a check has read: version, when, package, SHA-256, notes.
UpdateLatest=
UpdateLatestAt=0
UpdateUrl=
UpdateSha256=
UpdateNotes=
; The version whose prompt was closed with Later.
UpdateDismissed=
