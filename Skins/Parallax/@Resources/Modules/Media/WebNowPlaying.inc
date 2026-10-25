; Optional external plugin, installed by the user. Requires WebNowPlaying 2.x+.
; Reference: https://wnp.keifufu.dev/rainmeter/usage
; UpdateDivider=#MediaLegacyDivider# below keeps every plugin poll at the
; original #MediaInterval# cadence even when the skin's own Update ticks much
; faster (#MediaTickInterval#) to animate the player icon or the open spectrum
; drawer smoothly; see InlineQueueGeometry.inc for the variables.
[MeasureConnection]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Status
UpdateDivider=#MediaLegacyDivider#

[MeasurePlayer]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Player
UpdateDivider=#MediaLegacyDivider#

[MeasureTitle]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Title
UpdateDivider=#MediaLegacyDivider#

[MeasureArtist]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Artist
Substitute="":"Artist unavailable"
UpdateDivider=#MediaLegacyDivider#

; Raw artist value for matching local Windows sessions; never substitute metadata.
[MeasureSourceArtist]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Artist
UpdateDivider=#MediaLegacyDivider#

[MeasureAlbum]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Album
Substitute="":"Album unavailable"
UpdateDivider=#MediaLegacyDivider#

; A plugin that fails to load reports the number 0, which MeterCover would
; otherwise open as Media\0.png (one log error per update). Anchored so a real
; path containing 0 is never touched; empty means no image, not a missing file.
[MeasureCover]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Cover
RegExpSubstitute=1
Substitute="^0$":""
UpdateDivider=#MediaLegacyDivider#

; State: 1=Playing, 2=Paused, 0=Stopped. Read directly by Media.lua (the
; play/pause icon), MediaPulse.lua (the title icon swap and pulse) and
; MediaHeader.lua (the title's player name); no separate skin Variable needed.
[MeasureState]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=State
UpdateDivider=#MediaLegacyDivider#

[MeasurePosition]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Position
UpdateDivider=#MediaLegacyDivider#

[MeasureDuration]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Duration
UpdateDivider=#MediaLegacyDivider#

[MeasureProgress]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=Progress
MinValue=0
MaxValue=100
UpdateDivider=#MediaLegacyDivider#

[MeasureCanPrevious]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=SupportsSkipPrevious
UpdateDivider=#MediaLegacyDivider#

[MeasureCanPlayPause]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=SupportsPlayPause
UpdateDivider=#MediaLegacyDivider#

[MeasureCanNext]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=WebNowPlaying
PlayerType=SupportsSkipNext
UpdateDivider=#MediaLegacyDivider#

; Passive source reader uses this update's metadata and never starts the helper.
[MeasureMediaSource]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\Source\SourceReader.lua
UpdateDivider=#MediaLegacyDivider#

; Title icon: swaps monitor-play for audio-lines while a track plays, and
; pulses the bars. Runs once per animation frame (every tick at 20 fps, every
; other tick at 10 fps; the provider cadence with animation off), explicitly,
; because Media.ini's DefaultUpdateDivider would otherwise hold it to the
; provider cadence. It only reads three measures' last-cached values between
; their own slower refreshes, so it adds no extra plugin polling, and it
; returns at once while nothing animates. Kept out of Media.lua because that
; adapter must stay a pure function of the current sample.
[MeasureMediaPulse]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\MediaPulse.lua
UpdateDivider=#MediaPulseDivider#

; Last measure: reads this update's provider values and guards every command.
[MeasureMediaUI]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Media\Media.lua
UpdateDivider=#MediaLegacyDivider#
