[Variables]
MediaHeaderLucideScale=(#TitleIconSize#/24)
MediaPlayerLucideScale=(#TitleIconSize#/24)

; Last measure: read the current provider/source sample without starting either.
; Divider matches WebNowPlaying.inc's: this only needs the original cadence.
[MeasureMediaHeader]
Measure=Script
ScriptFile=#@#Modules\Media\MediaHeader.lua
UpdateDivider=#MediaLegacyDivider#

; Constant Lucide monitor-play beside the title, audio-lines beside the player.
; SVG source and license: Icons\Lucide\README.md.
[MediaHeaderIconStyle]
X=#ContentX#
Y=(#TitleRowCenterY#+#MediaSurfaceOffset#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
AntiAlias=1
Group=MediaPlayerIcons
UpdateDivider=-1

[MeterMediaIcon]
Meter=Shape
MeterStyle=MediaHeaderIconStyle
Hidden=0
Shape=Path LucideMonitorPlayPath | Extend LucideMonitorPlayStroke
Shape2=Line (12*#MediaHeaderLucideScale#),(17*#MediaHeaderLucideScale#),(12*#MediaHeaderLucideScale#),(21*#MediaHeaderLucideScale#) | Extend LucideMonitorPlayStroke
Shape3=Line (8*#MediaHeaderLucideScale#),(21*#MediaHeaderLucideScale#),(16*#MediaHeaderLucideScale#),(21*#MediaHeaderLucideScale#) | Extend LucideMonitorPlayStroke
Shape4=Rectangle (2*#MediaHeaderLucideScale#),(3*#MediaHeaderLucideScale#),(20*#MediaHeaderLucideScale#),(14*#MediaHeaderLucideScale#),(2*#MediaHeaderLucideScale#) | Extend LucideMonitorPlayStroke
LucideMonitorPlayStroke=Fill Color 0,0,0,0 | Stroke Color #MediaColor# | StrokeWidth (2*#MediaHeaderLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
; SVG sweep=1 maps to Rainmeter clockwise SweepDirection=0.
LucideMonitorPlayPath=(15.033*#MediaHeaderLucideScale#),(9.44*#MediaHeaderLucideScale#) | ArcTo (15.033*#MediaHeaderLucideScale#),(10.56*#MediaHeaderLucideScale#),(0.647*#MediaHeaderLucideScale#),(0.647*#MediaHeaderLucideScale#),0,0,0 | LineTo (10.968*#MediaHeaderLucideScale#),(12.912*#MediaHeaderLucideScale#) | ArcTo (10*#MediaHeaderLucideScale#),(12.352*#MediaHeaderLucideScale#),(0.645*#MediaHeaderLucideScale#),(0.645*#MediaHeaderLucideScale#),0,0,0 | LineTo (10*#MediaHeaderLucideScale#),(7.648*#MediaHeaderLucideScale#) | ArcTo (10.967*#MediaHeaderLucideScale#),(7.088*#MediaHeaderLucideScale#),(0.645*#MediaHeaderLucideScale#),(0.645*#MediaHeaderLucideScale#),0,0,0 | ClosePath 1
ToolTipText=Media player

[MeterPlayerIcon]
Meter=Shape
DynamicVariables=1
; Overrides the style's UpdateDivider=-1: while a track is playing,
; MediaPulse.lua rewrites each bar (Shape..Shape6) every tick via !SetOption,
; matching the audio-lines equalizer pulse at https://lucide-animated.com/.
; This meter must take part in normal updates for that to repaint. Idle,
; paused or disconnected, it settles back to the static bars below.
UpdateDivider=1
MeterStyle=MediaHeaderIconStyle
X=#MediaPlayerRowX#
Y=(#MediaPlayerRowY#+(18*#Scale#-#TitleIconSize#)/2)
W=#TitleIconSize#
H=#TitleIconSize#
Hidden=0
Shape=Line (2*#MediaPlayerLucideScale#),(10*#MediaPlayerLucideScale#),(2*#MediaPlayerLucideScale#),(13*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
Shape2=Line (6*#MediaPlayerLucideScale#),(6*#MediaPlayerLucideScale#),(6*#MediaPlayerLucideScale#),(17*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
Shape3=Line (10*#MediaPlayerLucideScale#),(3*#MediaPlayerLucideScale#),(10*#MediaPlayerLucideScale#),(21*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
Shape4=Line (14*#MediaPlayerLucideScale#),(8*#MediaPlayerLucideScale#),(14*#MediaPlayerLucideScale#),(15*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
Shape5=Line (18*#MediaPlayerLucideScale#),(5*#MediaPlayerLucideScale#),(18*#MediaPlayerLucideScale#),(18*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
Shape6=Line (22*#MediaPlayerLucideScale#),(10*#MediaPlayerLucideScale#),(22*#MediaPlayerLucideScale#),(13*#MediaPlayerLucideScale#) | Extend LucideAudioLinesStroke
LucideAudioLinesStroke=Fill Color 0,0,0,0 | Stroke Color #MediaColor# | StrokeWidth (2*#MediaPlayerLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
ToolTipText=Current player
