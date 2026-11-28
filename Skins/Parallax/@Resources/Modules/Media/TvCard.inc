; Media's player card on the TV. Media.ini only,
; through WebNowPlaying.inc: after the player's own measures (it reads this
; update's state) and before Media.lua, which shows the TV's meters
; (TvPlayerMeters.inc) instead of this PC's while the card shows the TV.
; MeasureTvCard is a second instance of the drawer's reader (TvCard=1): it reads
; the optional TV worker's snapshot (TvQueue\README.md) and applies the one
; PC-or-TV rule. It writes nothing and starts nothing; with no worker it says PC.
; Its value packs the card's fields; each TvField.lua measure hands one of them
; to a meter, so the TV's title and channel never pass through a bang.
[Variables]
; 1 while the audio plays on the TV (the card shows it, or this PC's tab casts):
; Media.lua sets it, and the open spectrum drawer (DrawerCapture0.inc) then says
; so instead of "Idle - quiet" when there is no signal here.
MediaAudioElsewhere=0

[MeasureTvCard]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\Queue\QueueReader.lua
TvCard=1
UpdateDivider=#MediaLegacyDivider#

[MeasureTvTitle]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\TvField.lua
Field=title
UpdateDivider=#MediaLegacyDivider#

[MeasureTvChannel]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\TvField.lua
Field=channel
UpdateDivider=#MediaLegacyDivider#

; The current video's thumbnail in the private TV folder, or empty. Before its
; first update a Script measure reads 0, which MeterTvCover would open as
; Media\0.png (as MeasureCover guards in WebNowPlaying.inc): anchored, so a real
; path is never touched.
[MeasureTvCover]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\TvField.lua
Field=cover
RegExpSubstitute=1
Substitute="^0$":""
UpdateDivider=#MediaLegacyDivider#

; "1:23 / 4:56", or empty while the TV gives no length.
[MeasureTvTiming]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\TvField.lua
Field=timing
UpdateDivider=#MediaLegacyDivider#

[MeasureTvProgress]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\TvField.lua
Field=progress
MinValue=0
MaxValue=100
UpdateDivider=#MediaLegacyDivider#
