; Automatic update check is on, Daily (Global Settings > Updates > Auto check;
; User\Settings.inc UpdateCheck=1, the default). Each utility entrypoint
; includes @Resources\Update\Hook#UpdateCheck#.inc. This variant adds the
; background check: one Script measure that runs once at load and then on its
; own [!Delay] timer, and the disabled feed WebParser it enables for a single
; request when a check is due. No meter, process or plugin. Every loaded
; utility carries it; they share @Resources\Update\State.inc, so one request
; is made per due check. See @Resources\Update\Update.lua.
[Variables]
@IncludeParallaxUpdateVersion=#@#Version.inc
ParallaxUpdateRole=hook
; First look 60 s after the load (the network is often not up at sign-in),
; then hourly; a check is due 24 h after a good one, 1 h after a failed one.
; Milliseconds; Update.lua clamps both to 1000-86400000.
ParallaxUpdateFirstDelay=60000
ParallaxUpdateTickMs=3600000
@IncludeParallaxUpdateFeed=#@#Update\Feed.inc

[MeasureParallaxUpdate]
Measure=Script
ScriptFile=#@#Update\Update.lua
UpdateDivider=-1
