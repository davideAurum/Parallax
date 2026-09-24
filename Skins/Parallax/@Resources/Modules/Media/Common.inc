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

; Tab contents, printed on the sheet: defined before MeterPanel so the panel
; occludes everything but the notch. Clicking still runs ToggleQueue().
[MeterQueueDrawer]
Meter=Shape
AntiAlias=1
DynamicVariables=1
X=#MediaSurfaceX#
Y=#MediaQueueDrawerTop#
Hidden=(1-#MediaQueueDrawer#)
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#MediaQueueDrawerRight#-#MediaSurfaceX#-#BorderThickness#*#Scale#),(#MediaQueueDrawerBottom#-#MediaQueueDrawerTop#-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #MediaQueueDrawerFill# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)

[MeterQueueToggle]
Meter=Shape
H=(18*#Scale#)
X=(#MediaQueueTabX#+6*#Scale#)
Y=(#MediaQueueTabCenterY#-9*#Scale#)
W=(18*#Scale#)
Hidden=(1-#MediaQueueDrawer#)
AntiAlias=1
DynamicVariables=1
UpdateDivider=-1
; Lucide List Plus / List Minus from the user-supplied SVGs in Icons\Lucide.
Shape=Rectangle 0,0,(18*#Scale#),(18*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Line (16*14*#Scale#/24),(5*14*#Scale#/24),(3*14*#Scale#/24),(5*14*#Scale#/24) | Extend MediaQueueToggleStroke
Shape3=Line (11*14*#Scale#/24),(12*14*#Scale#/24),(3*14*#Scale#/24),(12*14*#Scale#/24) | Extend MediaQueueToggleStroke
Shape4=Line (16*14*#Scale#/24),(19*14*#Scale#/24),(3*14*#Scale#/24),(19*14*#Scale#/24) | Extend MediaQueueToggleStroke
Shape5=Line (21*14*#Scale#/24),(12*14*#Scale#/24),(15*14*#Scale#/24),(12*14*#Scale#/24) | Extend MediaQueueToggleStroke
Shape6=Line (18*14*#Scale#/24),(9*14*#Scale#/24),(18*14*#Scale#/24),(15*14*#Scale#/24) | Stroke Color #HeaderTextColor# | StrokeWidth (2*14*#Scale#/24*(1-#QueueExpanded#)) | StrokeStartCap Round | StrokeEndCap Round | Offset (2*#Scale#),(2*#Scale#)
MediaQueueToggleStroke=Stroke Color #HeaderTextColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | Offset (2*#Scale#),(2*#Scale#)
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]

[MeterQueueHeading]
Meter=String
MeterStyle=StyleHeader
X=(#MediaQueueTabX#+30*#Scale#)
Y=#MediaQueueTabCenterY#
; At the narrowest column the transport group sits far enough left that the
; tab is barely wider than the toggle, so the label has no room: clamp instead
; of going negative, and the tab degrades to the icon alone. Where the buttons
; live on the x-axis is the open question that really settles this.
W=(Max(1,#MediaQueueTabWidth#-34*#Scale#))
Hidden=(1-#MediaQueueDrawer#)
StringAlign=LeftCenter
MeasureName=MeasureMediaOptions
Text=%1
ToolTipText=Expand or collapse the Spotify queue below Media. This display choice is remembered.
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]

[MeterPanel]
Meter=Shape
MeterStyle=StylePanel
X=#MediaSurfaceX#
Y=#MediaSurfaceY#
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#MediaSurfaceWidth#-#BorderThickness#*#Scale#),(#PanelHeightPx#-#MediaSurfaceOffset#-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)
; Shape2 is the cutout; the combined result keeps Shape's fill and stroke, so
; the panel border traces the notch, which is what sells the cut-away look.
Shape2=Rectangle #MediaQueueNotchX#,#MediaQueueNotchY#,#MediaQueueTabWidth#,(#MediaQueueTabHeight#+10*#Scale#),#MediaQueueTabRadius# | StrokeWidth 0
Shape3=Combine Shape | Exclude Shape2

; Rounded fallback for idle and plugin-free Setup; the player hides it for tracks.
[MeterArtworkPlaceholder]
Meter=Shape
AntiAlias=1
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#MediaCoverSize#-#Scale#),(#MediaCoverSize#-#Scale#),(#MediaCoverRadius#-#Scale#/2) | Fill Color #GraphBackgroundColor# | Stroke Color 255,255,255 | StrokeWidth #Scale#
Hidden=(1-#MediaWide#)
UpdateDivider=-1

[MeterArtworkLabel]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
X=(#MediaCoverX#+#MediaCoverSize#/2)
Y=(#MediaCoverY#+(#MediaCoverSize#-18*#Scale#)/2)
W=(#MediaCoverSize#-6*#Scale#)
StringAlign=Center
Text=N/A
ToolTipText=No artwork available.
Hidden=(1-#MediaWide#)
UpdateDivider=-1

[MeterHeading]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow
X=(#ContentX#+#TitleIconSize#+#TitleIconGap#)
Y=(#TitleRowCenterY#+#MediaSurfaceOffset#)
W=#MediaHeadingWidth#
Text=Media Player
UpdateDivider=-1

[MeterPlayerName]
Meter=String
MeterStyle=StyleLabel
FontSize=(#TitleFontSize#*#Scale#)
FontWeight=600
X=(#MediaPlayerRowX#+#TitleIconSize#+#TitleIconGap#)
Y=#MediaPlayerRowY#
W=(Max(1,#ContentX#+#ContentWidth#-#MediaPlayerRowX#-#TitleIconSize#-#TitleIconGap#-24*#MediaWide#*#Scale#))
H=(18*#Scale#)
Padding=0,0,0,0
MeasureName=MeasureMediaHeader
Text=%1
UpdateDivider=1

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule
X=#MediaQueueX#
Y=(#Inset#+#MediaBodyHeightPx#-29*#Scale#)
Shape=Line 0,0,#MediaQueueWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
Hidden=#MediaQueueHidden#



[MeterQueueStatus]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
MeasureName=MeasureQueueStatus
Hidden=#MediaQueueHidden#
X=(#MediaQueueX#+66*#Scale#)
Y=(#Inset#+#MediaBodyHeightPx#-12*#Scale#)
W=(#MediaQueueWidth#-66*#Scale#)
StringAlign=LeftCenter
FontColor=#MediaColor#
Text=%1
ToolTipText=Expand or collapse the Spotify queue. Use the gear for queue display and connection settings. The Spotify account queue may differ from WebNowPlaying's player.
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]

; Both dividers match Media.ini/Setup.ini's fast animation tick back down to
; the original #MediaInterval# cadence; see InlineQueueGeometry.inc.
[MeasureMediaOptions]
Measure=Script
ScriptFile=#@#Modules\Media\MediaOptions.lua
UpdateDivider=#MediaLegacyDivider#

[MeasureQueueStatus]
Measure=Script
ScriptFile=#@#Modules\Media\Queue\QueueReader.lua
; Compact footer labels; the standalone queue keeps the full status wording.
Substitute="Storage unavailable":"Storage error","Spotify unavailable":"Spotify error","Queue unavailable":"Queue error","App quota reached":"Quota reached","Provider stopped":"Stopped"
QueueExpanded=#QueueExpanded#
QueueInline=1
UpdateDivider=#MediaLegacyDivider#

[MediaUtilityIncludes]
@Include14=#@#Modules\Media\HeaderGear.inc
@Include15=#@#Modules\Media\InlineQueueMeters.inc
