; Optional external plugin, installed by the user. Requires WebNowPlaying 2.x+.
; Reference: https://wnp.keifufu.dev/rainmeter/usage
; UpdateDivider=#MediaLegacyDivider# below keeps every plugin poll at the
; original #MediaInterval# cadence even though the skin's own Update now ticks
; much faster (#MediaAnimationInterval#) to animate the player icon smoothly;
; see InlineQueueGeometry.inc for both variables.
[MeasureConnection]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Status
UpdateDivider=#MediaLegacyDivider#

[MeasurePlayer]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Player
UpdateDivider=#MediaLegacyDivider#

[MeasureTitle]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Title
UpdateDivider=#MediaLegacyDivider#

[MeasureArtist]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Artist
Substitute="":"Artist unavailable"
UpdateDivider=#MediaLegacyDivider#

; Raw artist value for matching local Windows sessions; never substitute metadata.
[MeasureSourceArtist]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Artist
UpdateDivider=#MediaLegacyDivider#

[MeasureAlbum]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Album
Substitute="":"Album unavailable"
UpdateDivider=#MediaLegacyDivider#

[MeasureCover]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Cover
UpdateDivider=#MediaLegacyDivider#

; State: 1=Playing, 2=Paused, 0=Stopped. Media.lua's Update() reads this
; directly (as it already does for the play/pause icon) to drive the
; player icon's pulse; no separate skin Variable needed.
[MeasureState]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=State
UpdateDivider=#MediaLegacyDivider#

[MeasurePosition]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Position
UpdateDivider=#MediaLegacyDivider#

[MeasureDuration]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Duration
UpdateDivider=#MediaLegacyDivider#

[MeasureProgress]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Progress
MinValue=0
MaxValue=100
UpdateDivider=#MediaLegacyDivider#

[MeasureCanPrevious]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsSkipPrevious
UpdateDivider=#MediaLegacyDivider#

[MeasureCanPlayPause]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsPlayPause
UpdateDivider=#MediaLegacyDivider#

[MeasureCanNext]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsSkipNext
UpdateDivider=#MediaLegacyDivider#

; Passive source reader uses this update's metadata and never starts the helper.
[MeasureMediaSource]
Measure=Script
ScriptFile=#@#Modules\Media\Source\SourceReader.lua
UpdateDivider=#MediaLegacyDivider#

; Player-icon pulse. Runs every fast tick (no divider) so the animation is
; smooth; it only reads the two measures' last-cached values between their own
; slower refreshes, so it adds no extra plugin polling. Kept out of Media.lua
; because that adapter must stay a pure function of the current sample.
[MeasureMediaPulse]
Measure=Script
ScriptFile=#@#Modules\Media\MediaPulse.lua

; Last measure: reads this update's provider values and guards every command.
[MeasureMediaUI]
Measure=Script
ScriptFile=#@#Modules\Media\Media.lua
UpdateDivider=#MediaLegacyDivider#
