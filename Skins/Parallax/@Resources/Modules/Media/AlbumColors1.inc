; Album colors on (User\Media.inc MediaAlbumColors=1, the default): the current
; cover recolors the player. Design and decisions:
; docs/superpowers/specs/2026-11-19-media-queue-art-and-album-colors-design.md.
;
; The bundled Chameleon plugin (BSD-3, Socks the Fox; packaging\Plugins\
; Chameleon) samples WebNowPlaying's cover file in-process and re-samples on
; its own when WebNowPlaying overwrites that file for the next track (measured
; 2026-11-19: about 1 s). Only Light1, Light2 and Average are read: the
; Background/Foreground/Dark outputs fell back to white/black between good
; samples in the same measurements. Without the plugin these measures stay
; empty (Rainmeter logs that the plugin cannot load) and the theme stays.
;
; Everything here runs at the provider cadence (#MediaLegacyDivider#), never
; on the 50 ms animation tick. AlbumColors.lua recolors only when the sampled
; colors or the shown text change.

[MeasureAlbumSampler]
Measure=Plugin
Plugin=Chameleon
Type=File
; WebNowPlaying's cover path; empty without a track. A short dynamic option:
; it carries no pre-expanded geometry variable.
Path=[MeasureCover]
DynamicVariables=1
UpdateDivider=#MediaLegacyDivider#
Group=ParallaxIdlePause

[MeasureAlbumLight1]
Measure=Plugin
Plugin=Chameleon
Parent=MeasureAlbumSampler
Color=Light1
UpdateDivider=#MediaLegacyDivider#
Group=ParallaxIdlePause

[MeasureAlbumLight2]
Measure=Plugin
Plugin=Chameleon
Parent=MeasureAlbumSampler
Color=Light2
UpdateDivider=#MediaLegacyDivider#
Group=ParallaxIdlePause

[MeasureAlbumAverage]
Measure=Plugin
Plugin=Chameleon
Parent=MeasureAlbumSampler
Color=Average
UpdateDivider=#MediaLegacyDivider#
Group=ParallaxIdlePause

[MeasureAlbumColors]
Measure=Script
ScriptFile=#@#Modules\Media\AlbumColors.lua
UpdateDivider=#MediaLegacyDivider#
Group=ParallaxIdlePause
Tint=#MediaAlbumTint#

; Text-width probes for the song/artist/album gradients. Rainmeter stretches a
; GradientColor over the String meter's box, not its words, so the script
; measures each line here and ends the gradient where the words end. Bound to
; the same measures (no text passes through a bang), drawn fully transparent,
; parked at the window's inset and capped at their line's width: a long title
; wraps here rather than widening the window. Forced updates only.
[AlbumMeasureStyle]
X=#Inset#
Y=#Inset#
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontColor=0,0,0,0
AntiAlias=1
ClipString=2
; One line box: wraps past it are clipped, never grow the window.
H=(24*#Scale#)
UpdateDivider=-1
Text=%1

[MeterAlbumMeasureTitle]
Meter=String
MeterStyle=AlbumMeasureStyle
MeasureName=MeasureTitle
FontWeight=600
ClipStringW=(#MediaMetadataWidth#-20*#Scale#)

[MeterAlbumMeasureArtist]
Meter=String
MeterStyle=AlbumMeasureStyle
MeasureName=MeasureArtist
ClipStringW=(#MediaMetadataWidth#-20*#Scale#)

[MeterAlbumMeasureAlbum]
Meter=String
MeterStyle=AlbumMeasureStyle
MeasureName=MeasureAlbum
ClipStringW=(#MediaMetadataWidth#-20*#Scale#-#MediaAlbumTimingReserve#)
