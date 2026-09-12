[MeterConnection]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
MeasureName=MeasureMediaUI
Y=(#Inset#+25*#Scale#)
W=(#ContentWidth#-72*#Scale#)
Text=%1
ToolTipText=WebNowPlaying connection and playback state. Disconnected includes a missing or inactive provider; idle means connected with no title. WNP supplies no reliable heartbeat timestamp, so stalled data cannot be detected here.

[MeterNoMedia]
Meter=String
MeterStyle=StyleLabel
Group=MediaDynamic
Y=(#Inset#+46*#Scale#)
H=(44*#Scale#)
ClipString=2
Text=No active media.#CRLF#Open a player or use Setup.

[MeterCoverPlaceholder]
Meter=Image
Group=MediaTrack
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
SolidColor=#GraphBackgroundColor#
Hidden=1

[MeterCoverLabel]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTrack
X=(#MediaCoverX#+#MediaCoverSize#/2)
Y=(#MediaCoverY#+(16+48*#MediaWide#)*#Scale#)
W=(#MediaCoverSize#-6*#Scale#)
StringAlign=Center
Text=No art
Hidden=1

[MeterCover]
Meter=Image
Group=MediaTrack
MeasureName=MeasureCover
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
PreserveAspectRatio=2
Hidden=1

[MeterTrackTitle]
Meter=String
MeterStyle=StyleLabel
Group=MediaTrack
MeasureName=MeasureTitle
X=(#ContentX#+54*(1-#MediaWide#)*#Scale#)
Y=(#Inset#+44*#Scale#)
W=(#ContentWidth#-54*(1-#MediaWide#)*#Scale#)
H=(18*#Scale#)
FontColor=#TextColor#
FontWeight=600
Text=%1
Hidden=1

[MeterArtist]
Meter=String
MeterStyle=StyleLabel
Group=MediaTrack
MeasureName=MeasureArtist
X=(#ContentX#+54*(1-#MediaWide#)*#Scale#)
Y=(#Inset#+62*#Scale#)
W=(#ContentWidth#-54*(1-#MediaWide#)*#Scale#)
H=(18*#Scale#)
Text=%1
Hidden=1

[MeterAlbum]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTrack
MeasureName=MeasureAlbum
X=(#ContentX#+54*(1-#MediaWide#)*#Scale#)
Y=(#Inset#+80*#Scale#)
W=(#ContentWidth#-54*(1-#MediaWide#)*#Scale#)
H=(18*#Scale#)
Text=%1
Hidden=1

[MeterProgress]
Meter=Bar
Group=MediaTimeline
MeasureName=MeasureProgress
X=#ContentX#
Y=(#Inset#+100*#Scale#)
W=#ContentWidth#
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#MediaColor#
SolidColor=#TrackColor#
Hidden=1

[MeterTiming]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTimeline
MeasureName=MeasurePosition
MeasureName2=MeasureDuration
Y=(#Inset#+110*#Scale#)
W=(#ContentWidth#-68*#Scale#)
Text=%1 / %2
Hidden=1

[MeterTimingUnavailable]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Y=(#Inset#+110*#Scale#)
W=(#ContentWidth#-68*#Scale#)
Text=Time unavailable
Group=MediaDynamic

[MeterPlayerName]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTrack
MeasureName=MeasureMediaSource
X=(#ContentX#+#ContentWidth#-68*#Scale#)
Y=(#Inset#+25*#Scale#)
W=(68*#Scale#)
Text=%1
ToolTipText=Source detection can identify Spotify from matching local Windows media sessions. Start it in Media settings; no Spotify sign-in is required.
Hidden=1

[MeterPrevious]
Meter=String
MeterStyle=MediaButtonStyle
Group=MediaDynamic
X=(#ContentX#+#ContentWidth#-54*#Scale#)
Y=(#Inset#+110*#Scale#)
W=(20*#Scale#)
FontColor=#MutedColor#
Text=|<
ToolTipText=Previous track unavailable until the connected player reports support.
MouseActionCursor=0
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Previous')"]

[MeterPlayPause]
Meter=String
MeterStyle=MediaButtonStyle
Group=MediaDynamic
X=(#ContentX#+#ContentWidth#-32*#Scale#)
Y=(#Inset#+110*#Scale#)
W=(20*#Scale#)
FontColor=#MutedColor#
Text=>
ToolTipText=Play or pause unavailable until the connected player reports support.
MouseActionCursor=0
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('PlayPause')"]

[MeterNext]
Meter=String
MeterStyle=MediaButtonStyle
Group=MediaDynamic
X=(#ContentX#+#ContentWidth#-10*#Scale#)
Y=(#Inset#+110*#Scale#)
W=(20*#Scale#)
FontColor=#MutedColor#
Text=>|
ToolTipText=Next track unavailable until the connected player reports support.
MouseActionCursor=0
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Next')"]
