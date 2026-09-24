; Lucide transport SVGs translated to native Shape paths, at their original
; 24-unit coordinates. See Icons\Lucide\README.md for sources and license.
; Every art shape is centred in #MediaTransportBox# by
; #MediaTransportGlyphOffset#. Media.lua then adds
; #MediaTransportGlyphNudge# to the outer two, optically centring their solid
; forms rather than their bounding boxes.
; Circular buttons centred on the panel's lower border, so half of each sits
; outside the panel. They are defined after the panel and artwork, and
; Rainmeter paints in definition order, so they land above both.
[MediaTransportIconStyle]
AntiAlias=1
DynamicVariables=1
UpdateDivider=-1
Group=MediaDynamic|MediaTransport
Y=#MediaTransportY#
W=#MediaTransportBox#
H=#MediaTransportBox#
; Shape/Shape2 are the faked shadow, Shape3 the button face; the Lucide art
; starts at Shape4. The filled circle is also the click target, so hit
; testing still follows painted geometry.
Shape=Ellipse (#MediaTransportBox#/2),(#MediaTransportBox#/2+3*#Scale#),(#MediaTransportSize#/2+2*#Scale#),(#MediaTransportSize#/2+2*#Scale#) | Fill Color 0,0,0,28 | StrokeWidth 0
Shape2=Ellipse (#MediaTransportBox#/2),(#MediaTransportBox#/2+2*#Scale#),(#MediaTransportSize#/2+#Scale#),(#MediaTransportSize#/2+#Scale#) | Fill Color 0,0,0,38 | StrokeWidth 0
Shape3=Ellipse (#MediaTransportBox#/2),(#MediaTransportBox#/2),(#MediaTransportSize#/2),(#MediaTransportSize#/2) | Fill Color #AccentColor# | StrokeWidth 0
LucideTransportStroke=Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#Scale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset #MediaTransportGlyphOffset#,#MediaTransportGlyphOffset#
MouseActionCursor=0

[MeterPrevious]
Meter=Shape
MeterStyle=MediaTransportIconStyle
X=(#MediaTransportGroupX#-#MediaTransportShadowPad#)
Shape4=Path LucideRewindLeftPath | Extend LucideTransportStroke
Shape5=Path LucideRewindRightPath | Extend LucideTransportStroke
; SVG sweep=0 maps to Rainmeter counter-clockwise SweepDirection=1.
LucideRewindLeftPath=(12*#Scale#),(6*#Scale#) | ArcTo (8.586*#Scale#),(4.586*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (2.586*#Scale#),(10.586*#Scale#) | ArcTo (2.586*#Scale#),(13.414*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (8.586*#Scale#),(19.414*#Scale#) | ArcTo (12*#Scale#),(18*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | ClosePath 1
LucideRewindRightPath=(22*#Scale#),(6*#Scale#) | ArcTo (18.586*#Scale#),(4.586*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (12.586*#Scale#),(10.586*#Scale#) | ArcTo (12.586*#Scale#),(13.414*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (18.586*#Scale#),(19.414*#Scale#) | ArcTo (22*#Scale#),(18*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | ClosePath 1
ToolTipText=Previous track unavailable until the connected player reports support.
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Previous',true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Previous',false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Previous')"]

[MeterPlayPause]
Meter=Shape
MeterStyle=MediaTransportIconStyle
X=(#MediaTransportGroupX#-#MediaTransportShadowPad#+#MediaTransportSize#+#MediaTransportGap#)
Shape4=Path LucideTransportPlayPath | Extend LucideTransportStroke
Shape5=Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0
Shape6=Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0
; SVG sweep=1 maps to Rainmeter clockwise SweepDirection=0.
LucideTransportPlayPath=(5*#Scale#),(5*#Scale#) | ArcTo (8.008*#Scale#),(3.272*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (20.005*#Scale#),(10.27*#Scale#) | ArcTo (20.008*#Scale#),(13.728*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (8.008*#Scale#),(20.728*#Scale#) | ArcTo (5*#Scale#),(19*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | ClosePath 1
LucideTransportPlayOffUpperPath=(10.215*#Scale#),(4.56*#Scale#) | LineTo (20.005*#Scale#),(10.27*#Scale#) | ArcTo (20.008*#Scale#),(13.728*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (19.615*#Scale#),(13.958*#Scale#)
LucideTransportPlayOffLowerPath=(16.042*#Scale#),(16.042*#Scale#) | LineTo (8.008*#Scale#),(20.728*#Scale#) | ArcTo (5*#Scale#),(19*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (5*#Scale#),(5*#Scale#)
LucideTransportPlayOffSlashPath=(2*#Scale#),(2*#Scale#) | LineTo (22*#Scale#),(22*#Scale#)
LucideTransportStepForwardPath=(10.029*#Scale#),(4.285*#Scale#) | ArcTo (7*#Scale#),(6*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (7*#Scale#),(18*#Scale#) | ArcTo (10.029*#Scale#),(19.715*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | LineTo (20.026*#Scale#),(13.717*#Scale#) | ArcTo (20.029*#Scale#),(10.285*#Scale#),(2*#Scale#),(2*#Scale#),0,1,0 | ClosePath 1
LucideTransportStepForwardBarPath=(3*#Scale#),(4*#Scale#) | LineTo (3*#Scale#),(20*#Scale#)
ToolTipText=Play or pause unavailable until the connected player reports support.
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverPlayPause(true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverPlayPause(false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('PlayPause')"]

[MeterNext]
Meter=Shape
MeterStyle=MediaTransportIconStyle
X=(#MediaTransportGroupX#-#MediaTransportShadowPad#+2*(#MediaTransportSize#+#MediaTransportGap#))
Shape4=Path LucideFastForwardRightPath | Extend LucideTransportStroke
Shape5=Path LucideFastForwardLeftPath | Extend LucideTransportStroke
LucideFastForwardRightPath=(12*#Scale#),(6*#Scale#) | ArcTo (15.414*#Scale#),(4.586*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (21.414*#Scale#),(10.586*#Scale#) | ArcTo (21.414*#Scale#),(13.414*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (15.414*#Scale#),(19.414*#Scale#) | ArcTo (12*#Scale#),(18*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | ClosePath 1
LucideFastForwardLeftPath=(2*#Scale#),(6*#Scale#) | ArcTo (5.414*#Scale#),(4.586*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (11.414*#Scale#),(10.586*#Scale#) | ArcTo (11.414*#Scale#),(13.414*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | LineTo (5.414*#Scale#),(19.414*#Scale#) | ArcTo (2*#Scale#),(18*#Scale#),(2*#Scale#),(2*#Scale#),0,0,0 | ClosePath 1
ToolTipText=Next track unavailable until the connected player reports support.
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Next',true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Next',false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Next')"]
