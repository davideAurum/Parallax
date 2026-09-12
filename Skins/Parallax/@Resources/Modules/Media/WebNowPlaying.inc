; Optional external plugin, installed by the user. Requires WebNowPlaying 2.x+.
; Reference: https://wnp.keifufu.dev/rainmeter/usage
[MeasureConnection]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Status

[MeasurePlayer]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Player

[MeasureTitle]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Title

[MeasureArtist]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Artist
Substitute="":"Artist unavailable"

; Raw artist value for matching local Windows sessions; never substitute metadata.
[MeasureSourceArtist]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Artist

[MeasureAlbum]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Album
Substitute="":"Album unavailable"

[MeasureCover]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Cover

[MeasureState]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=State

[MeasurePosition]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Position

[MeasureDuration]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Duration

[MeasureProgress]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=Progress
MinValue=0
MaxValue=100

[MeasureCanPrevious]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsSkipPrevious

[MeasureCanPlayPause]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsPlayPause

[MeasureCanNext]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=SupportsSkipNext

; Passive source reader uses this update's metadata and never starts the helper.
[MeasureMediaSource]
Measure=Script
ScriptFile=#@#Modules\Media\Source\SourceReader.lua

; Last measure: reads this update's provider values and guards every command.
[MeasureMediaUI]
Measure=Script
ScriptFile=#@#Modules\Media\Media.lua
