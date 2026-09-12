; Original Parallax layout: compact at one column, overhanging art at two.
; Local actions have zero padding and a subtle hit surface, not wide tiles.
[MediaButtonStyle]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=600
FontColor=#AccentColor#
SolidColor=0,0,0,1
AntiAlias=1
ClipString=1
StringAlign=Center
Padding=0,0,0,0
H=(18*#Scale#)
MouseActionCursor=1

[MediaSecondaryStyle]
H=(18*#Scale#)

[MeterBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterPanel]
Meter=Shape
MeterStyle=StylePanel
X=#MediaSurfaceX#
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#MediaSurfaceWidth#-#BorderThickness#*#Scale#),(#PanelHeightPx#-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)

; Keep the double-column tile present during idle and plugin-free Setup states.
; The player draws its normal cover/placeholder on top when a track is available.
[MeterArtworkPlaceholder]
Meter=Image
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
SolidColor=#GraphBackgroundColor#
Hidden=(1-#MediaWide#)
UpdateDivider=-1

[MeterArtworkLabel]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
X=(#MediaCoverX#+#MediaCoverSize#/2)
Y=(#MediaCoverY#+(16+48*#MediaWide#)*#Scale#)
W=(#MediaCoverSize#-6*#Scale#)
StringAlign=Center
Text=No art
Hidden=(1-#MediaWide#)
UpdateDivider=-1

[MeterHeading]
Meter=String
MeterStyle=StyleTitle
X=(#ContentX#+18*#Scale#)
Y=(#Inset#+3*#Scale#)
W=(#ContentWidth#-42*#Scale#)
H=(22*#Scale#)
Text=Media
UpdateDivider=-1

[MeterMediaIcon]
Meter=Shape
X=#ContentX#
Y=(#Inset#+8*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Rectangle (7*#Scale#),(1*#Scale#),(2*#Scale#),(9*#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape2=Ellipse (5*#Scale#),(10*#Scale#),(3*#Scale#),(2*#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape3=Rectangle (7*#Scale#),(1*#Scale#),(5*#Scale#),(2*#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
UpdateDivider=-1

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule
Y=(#Inset#+133*#Scale#)

[MeterQueueHeading]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+141*#Scale#)
W=(56*#Scale#)
MeasureName=MeasureMediaOptions
Text=%1
ToolTipText=Expand or collapse the Spotify queue below Media. This display choice is remembered.
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]

[MeterQueueStatus]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
MeasureName=MeasureQueueStatus
X=(#ContentX#+60*#Scale#)
Y=(#Inset#+141*#Scale#)
W=(#ContentWidth#-60*#Scale#)
FontColor=#MediaColor#
Text=%1
ToolTipText=Expand or collapse the Spotify queue. Use the gear for queue display and connection settings. The Spotify account queue may differ from WebNowPlaying's player.
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]

[MeasureMediaOptions]
Measure=Script
ScriptFile=#@#Modules\Media\MediaOptions.lua

[MeasureQueueStatus]
Measure=Script
ScriptFile=#@#Modules\Media\Queue\QueueReader.lua
; Compact footer labels; the standalone queue keeps the full status wording.
Substitute="Storage unavailable":"Storage error","Spotify unavailable":"Spotify error","Queue unavailable":"Queue error","App quota reached":"Quota reached","Provider stopped":"Stopped"
QueueExpanded=#QueueExpanded#
QueueInline=1

[MediaUtilityIncludes]
@Include14=#@#Modules\Media\HeaderGear.inc
@Include15=#@#Modules\Media\InlineQueueMeters.inc
