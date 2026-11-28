; The player card's TV view: the TV's title,
; channel, thumbnail, progress and time in the places of this PC's
; (PlayerMeters.inc), fed by the TvCard.inc measures. Media.lua shows these and
; hides this PC's text while the card shows the TV; the cover placeholder,
; frame and row icons are shared. Media.ini only.
[MeterTvTitle]
Meter=String
MeterStyle=StyleLabel
Group=MediaTv|ParallaxIdleFreeze
MeasureName=MeasureTvTitle
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#)
H=(24*#Scale#)
StringAlign=LeftCenter
FontColor=#TextColor#
FontWeight=600
Text=%1
Hidden=1

[MeterTvChannel]
Meter=String
MeterStyle=StyleLabel
Group=MediaTv|ParallaxIdleFreeze
MeasureName=MeasureTvChannel
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+#MediaMetadataPitch#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#)
H=(24*#Scale#)
StringAlign=LeftCenter
Text=%1
Hidden=1

; Where it plays, in the album row.
[MeterTvPlace]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTv
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+2*#MediaMetadataPitch#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#-#MediaAlbumTimingReserve#)
H=(24*#Scale#)
StringAlign=LeftCenter
Text=On the TV
Hidden=1
UpdateDivider=-1

; The 16:9 thumbnail fills the square mask, cropped at the sides.
[MeterTvCover]
Meter=Image
Group=ParallaxIdleFreeze
MeasureName=MeasureTvCover
Container=MeterCoverMask
X=0
Y=0
W=#MediaCoverSize#
H=#MediaCoverSize#
PreserveAspectRatio=2
Hidden=1
UpdateDivider=#MediaLegacyDivider#

[MeterTvProgress]
Meter=Bar
Group=ParallaxIdleFreeze
MeasureName=MeasureTvProgress
X=#MediaProgressX#
Y=#MediaProgressY#
W=#MediaProgressWidth#
H=#DataBarThicknessPx#
BarOrientation=Horizontal
BarColor=#MediaColor#
SolidColor=#TrackColor#
Hidden=1

[MeterTvTiming]
Meter=String
MeterStyle=MediaTimingStyle
Group=ParallaxIdleFreeze
MeasureName=MeasureTvTiming
Text=%1
Hidden=1
