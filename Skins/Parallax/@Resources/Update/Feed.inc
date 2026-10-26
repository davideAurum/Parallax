; The release feed request, shared by Global Settings and the utility hook
; (Hook1.inc). Inert until Update.lua enables it for one request; its finish
; and error actions report back to MeasureParallaxUpdate. The pattern takes up
; to 8193 characters of any non-empty body, so GitHub's "Not Found" or a
; rate-limit page still reaches Update.lua's Classify(), and a feed over the
; 8192-character limit is still recognized as too large. UpdateDivider=-1:
; it updates only when Update.lua or its own FinishAction asks.
[MeasureParallaxUpdateFeed]
Measure=WebParser
URL=#UpdateFeedURL#
RegExp=(?s)^(.{1,8193})
StringIndex=1
Codepage=65001
ForceReload=1
LogSubstringErrors=0
Disabled=1
UpdateDivider=-1
FinishAction=[!UpdateMeasure MeasureParallaxUpdateFeed][!CommandMeasure MeasureParallaxUpdate "FeedReady()"]
OnConnectErrorAction=[!CommandMeasure MeasureParallaxUpdate "FeedError('connect')"]
OnRegExpErrorAction=[!CommandMeasure MeasureParallaxUpdate "FeedError('format')"]
