; Fixed text and shapes below use UpdateDivider=-1: Media.lua only shows and
; hides them, and a due meter would repaint the whole window on every tick
; (docs/PERFORMANCE-REVIEW.md MEDIA-01). Measure-bound text keeps Media.ini's
; DefaultUpdateDivider, the provider cadence of the measures it shows.
[MeterNoMedia]
Meter=String
MeterStyle=StyleLabel
Group=MediaDynamic
Y=#MediaMetadataY#
H=(44*#Scale#)
ClipString=2
Text=No active media.#CRLF#Open a player or use Setup.
UpdateDivider=-1

[MeterCoverPlaceholder]
Meter=Shape
AntiAlias=1
Group=MediaTrack
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
Shape=Rectangle 0,0,#MediaCoverSize#,#MediaCoverSize#,#MediaCoverRadius# | Fill Color #GraphBackgroundColor# | StrokeWidth 0
Hidden=1
UpdateDivider=-1

[MeterCoverLabel]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTrack
X=(#MediaCoverX#+#MediaCoverSize#/2)
Y=(#MediaCoverY#+(#MediaCoverSize#-18*#Scale#)/2)
W=(#MediaCoverSize#-6*#Scale#)
StringAlign=Center
Text=N/A
Hidden=1
UpdateDivider=-1

; The opaque rounded Shape masks child images; it paints no rectangle itself.
; Keep the container outside visibility groups and hide the image child instead.
[MeterCoverMask]
Meter=Shape
AntiAlias=1
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
Shape=Rectangle 0,0,#MediaCoverSize#,#MediaCoverSize#,#MediaCoverRadius# | Fill Color 255,255,255,255 | StrokeWidth 0
UpdateDivider=-1

; Hidden meters still update, so this reads MeasureCover only at its own
; cadence rather than every animation tick.
[MeterCover]
Meter=Image
Group=MediaTrack|ParallaxIdleFreeze
MeasureName=MeasureCover
Container=MeterCoverMask
X=0
Y=0
W=#MediaCoverSize#
H=#MediaCoverSize#
PreserveAspectRatio=2
Hidden=1
UpdateDivider=#MediaLegacyDivider#

[MeterCoverFrame]
Meter=Shape
AntiAlias=1
Group=MediaTrack
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#MediaCoverSize#-#Scale#),(#MediaCoverSize#-#Scale#),(#MediaCoverRadius#-#Scale#/2) | Fill Color 0,0,0,0 | Stroke Color 255,255,255 | StrokeWidth #Scale#
Hidden=1
UpdateDivider=-1

; Lucide's 24-unit artwork fits the existing 14-pixel metadata canvas.
[Variables]
MediaLucideScale=(14*#Scale#/24)

; Vector icons avoid font-symbol dependencies at every suite scale.
[MediaMetadataIconStyle]
AntiAlias=1
DynamicVariables=1
X=#MediaMetadataX#
W=(14*#Scale#)
H=(14*#Scale#)
Group=MediaTrack
Hidden=1
UpdateDivider=-1

[MeterSongIcon]
Meter=Shape
MeterStyle=MediaMetadataIconStyle
Y=(#MediaMetadataY#+5*#Scale#)
; Lucide music, adapted from SVG. Attribution/license: Icons\Lucide\README.md.
Shape=Path LucideMusicPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape2=Ellipse (6*#MediaLucideScale#),(18*#MediaLucideScale#),(3*#MediaLucideScale#),(3*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
Shape3=Ellipse (18*#MediaLucideScale#),(16*#MediaLucideScale#),(3*#MediaLucideScale#),(3*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
LucideMusicPath=(9*#MediaLucideScale#),(18*#MediaLucideScale#) | LineTo (9*#MediaLucideScale#),(5*#MediaLucideScale#) | LineTo (21*#MediaLucideScale#),(3*#MediaLucideScale#) | LineTo (21*#MediaLucideScale#),(16*#MediaLucideScale#)

[MeterArtistIcon]
Meter=Shape
MeterStyle=MediaMetadataIconStyle
Y=(#MediaMetadataY#+#MediaMetadataPitch#+5*#Scale#)
; Lucide user-round-group. Rainmeter's counter-clockwise flag is 1 (SVG uses 0).
Shape=Path LucideArtistBodyPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape2=Path LucideArtistRightPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape3=Path LucideArtistLeftPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape4=Ellipse (12*#MediaLucideScale#),(13*#MediaLucideScale#),(3*#MediaLucideScale#),(3*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
Shape5=Ellipse (18.5*#MediaLucideScale#),(4.5*#MediaLucideScale#),(2.5*#MediaLucideScale#),(2.5*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
Shape6=Ellipse (5.5*#MediaLucideScale#),(4.5*#MediaLucideScale#),(2.5*#MediaLucideScale#),(2.5*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
LucideArtistBodyPath=(17*#MediaLucideScale#),(21*#MediaLucideScale#) | ArcTo (7*#MediaLucideScale#),(21*#MediaLucideScale#),(5*#MediaLucideScale#),(5*#MediaLucideScale#),0,1,0
LucideArtistRightPath=(22*#MediaLucideScale#),(10.5*#MediaLucideScale#) | ArcTo (16.493*#MediaLucideScale#),(7.632*#MediaLucideScale#),(3.5*#MediaLucideScale#),(3.5*#MediaLucideScale#),0,1,0
LucideArtistLeftPath=(7.507*#MediaLucideScale#),(7.632*#MediaLucideScale#) | ArcTo (2*#MediaLucideScale#),(10.5*#MediaLucideScale#),(3.5*#MediaLucideScale#),(3.5*#MediaLucideScale#),0,1,0

[MeterAlbumIcon]
Meter=Shape
MeterStyle=MediaMetadataIconStyle
Y=(#MediaMetadataY#+2*#MediaMetadataPitch#+5*#Scale#)
; Lucide disc-3, including its original cubic curves. See Icons\Lucide\README.md.
Shape=Ellipse (12*#MediaLucideScale#),(12*#MediaLucideScale#),(10*#MediaLucideScale#),(10*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
Shape2=Path LucideDiscUpperPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape3=Ellipse (12*#MediaLucideScale#),(12*#MediaLucideScale#),(2*#MediaLucideScale#),(2*#MediaLucideScale#) | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#)
Shape4=Path LucideDiscLowerPath | Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#MediaLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
LucideDiscUpperPath=(6*#MediaLucideScale#),(12*#MediaLucideScale#) | CurveTo (7.8*#MediaLucideScale#),(7.8*#MediaLucideScale#),(6*#MediaLucideScale#),(10.3*#MediaLucideScale#),(6.7*#MediaLucideScale#),(8.8*#MediaLucideScale#)
LucideDiscLowerPath=(18*#MediaLucideScale#),(12*#MediaLucideScale#) | CurveTo (16.2*#MediaLucideScale#),(16.2*#MediaLucideScale#),(18*#MediaLucideScale#),(13.7*#MediaLucideScale#),(17.3*#MediaLucideScale#),(15.2*#MediaLucideScale#)

[MeterTrackTitle]
Meter=String
MeterStyle=StyleLabel
Group=MediaTrack|ParallaxIdleFreeze
MeasureName=MeasureTitle
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#)
H=(24*#Scale#)
StringAlign=LeftCenter
FontColor=#TextColor#
FontWeight=600
Text=%1
Hidden=1

[MeterArtist]
Meter=String
MeterStyle=StyleLabel
Group=MediaTrack|ParallaxIdleFreeze
MeasureName=MeasureArtist
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+#MediaMetadataPitch#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#)
H=(24*#Scale#)
StringAlign=LeftCenter
Text=%1
Hidden=1

[MeterAlbum]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Group=MediaTrack|ParallaxIdleFreeze
MeasureName=MeasureAlbum
X=(#MediaMetadataX#+20*#Scale#)
Y=(#MediaMetadataY#+2*#MediaMetadataPitch#+12*#Scale#)
W=(#MediaMetadataWidth#-20*#Scale#)
H=(24*#Scale#)
StringAlign=LeftCenter
Text=%1
Hidden=1

[MeterProgress]
Meter=Bar
Group=MediaTimeline|ParallaxIdleFreeze
MeasureName=MeasureProgress
X=#MediaProgressX#
Y=#MediaProgressY#
W=#MediaProgressWidth#
H=#DataBarThicknessPx#
BarOrientation=Horizontal
BarColor=#MediaColor#
SolidColor=#TrackColor#
Hidden=1

; Auto-size the time text inside a bounded, single-line area. Its measured left
; edge supplies the transport centering boundary; no hidden width probe needed.
; No DynamicVariables: these options change only with a refresh, and Media's
; pre-expanded geometry chains made each re-read about 23 KB of formula text
; (docs/PERFORMANCE-REVIEW.md MEDIA-03). The time itself comes from measures.
[MediaTimingStyle]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=2
ClipStringW=#MediaTimingMaxWidth#
H=(18*#Scale#)
Padding=0,0,0,0
X=(#MediaProgressX#+#MediaProgressWidth#)
Y=(#MediaProgressY#+#DataBarThicknessPx#+2*#Scale#)
StringAlign=Right

; Neither timing meter calls Media.lua's LayoutTransport() while that layout
; is disabled (TEMPORARY there): an OnUpdateAction ran a no-op Lua call on
; every update. When the transport x-axis returns, call it from Media.lua's
; change path instead of per meter update.
[MeterTiming]
Meter=String
MeterStyle=MediaTimingStyle
Group=MediaTimeline|ParallaxIdleFreeze
MeasureName=MeasurePosition
MeasureName2=MeasureDuration
Text=%1 / %2
Hidden=1

[MeterTimingUnavailable]
Meter=String
MeterStyle=MediaTimingStyle
Text=-- / --
Group=MediaDynamic
UpdateDivider=-1

[MediaTransportInclude]
@Include17=#@#Modules\Media\TransportIcons.inc
