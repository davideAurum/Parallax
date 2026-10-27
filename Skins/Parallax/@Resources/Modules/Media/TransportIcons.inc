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
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Next',true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Next',false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Next')"]

; Shuffle and repeat: Lucide shuffle, repeat and repeat-1 at 18S on 26S
; circles (see #MediaTransportToggleSize#). Media.lua sets the face (on, off,
; hovered) and the art's stroke from WNP's Shuffle/Repeat state and Supports*
; capabilities; repeat-one swaps the extra "1" stroke into Shape8.
[MediaTransportToggleStyle]
AntiAlias=1
DynamicVariables=1
UpdateDivider=-1
Group=MediaDynamic|MediaTransport
Y=#MediaTransportToggleY#
; Hidden (and parked) where the five-button row has no room; see
; MediaTransportToggles in InlineQueueGeometry.inc.
Hidden=(1-#MediaTransportToggles#)
W=#MediaTransportToggleBox#
H=#MediaTransportToggleBox#
Shape=Ellipse (#MediaTransportToggleBox#/2),(#MediaTransportToggleBox#/2+3*#Scale#),(#MediaTransportToggleSize#/2+2*#Scale#),(#MediaTransportToggleSize#/2+2*#Scale#) | Fill Color 0,0,0,28 | StrokeWidth 0
Shape2=Ellipse (#MediaTransportToggleBox#/2),(#MediaTransportToggleBox#/2+2*#Scale#),(#MediaTransportToggleSize#/2+#Scale#),(#MediaTransportToggleSize#/2+#Scale#) | Fill Color 0,0,0,38 | StrokeWidth 0
; The ring is stroked inside the face's edge, so the click target and the
; painted face keep the same outer radius on and off.
Shape3=Ellipse (#MediaTransportToggleBox#/2),(#MediaTransportToggleBox#/2),(#MediaTransportToggleSize#/2-#BorderThickness#*#Scale#/2),(#MediaTransportToggleSize#/2-#BorderThickness#*#Scale#/2) | Extend MediaTransportToggleFace
MediaTransportToggleFace=Fill Color #MediaTransportToggleOffFill# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)
LucideToggleStroke=Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#Scale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset #MediaTransportToggleGlyphOffset#,#MediaTransportToggleGlyphOffset#
MouseActionCursor=0

[MeterShuffle]
Meter=Shape
MeterStyle=MediaTransportToggleStyle
X=(#MediaTransportShuffleX#-#MediaTransportShadowPad#)
Shape4=Path LucideShuffleLowerArrowPath | Extend LucideToggleStroke
Shape5=Path LucideShuffleUpperArrowPath | Extend LucideToggleStroke
Shape6=Path LucideShuffleCrossPath | Extend LucideToggleStroke
Shape7=Path LucideShuffleUpperTailPath | Extend LucideToggleStroke
Shape8=Path LucideShuffleLowerTailPath | Extend LucideToggleStroke
LucideShuffleLowerArrowPath=(18*#MediaTransportToggleGlyphScale#),(14*#MediaTransportToggleGlyphScale#) | LineTo (22*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | LineTo (18*#MediaTransportToggleGlyphScale#),(22*#MediaTransportToggleGlyphScale#)
LucideShuffleUpperArrowPath=(18*#MediaTransportToggleGlyphScale#),(2*#MediaTransportToggleGlyphScale#) | LineTo (22*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#) | LineTo (18*#MediaTransportToggleGlyphScale#),(10*#MediaTransportToggleGlyphScale#)
; SVG sweep=0 maps to Rainmeter SweepDirection=1, sweep=1 to 0.
LucideShuffleCrossPath=(2*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | LineTo (3.973*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | ArcTo (7.273*#MediaTransportToggleGlyphScale#),(16.3*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,1,0 | LineTo (12.727*#MediaTransportToggleGlyphScale#),(7.7*#MediaTransportToggleGlyphScale#) | ArcTo (16.027*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,0,0 | LineTo (22*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#)
LucideShuffleUpperTailPath=(2*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#) | LineTo (3.972*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#) | ArcTo (7.572*#MediaTransportToggleGlyphScale#),(8.2*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,0,0
LucideShuffleLowerTailPath=(22*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | LineTo (15.959*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | ArcTo (12.659*#MediaTransportToggleGlyphScale#),(16.2*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,0,0 | LineTo (12.3*#MediaTransportToggleGlyphScale#),(15.75*#MediaTransportToggleGlyphScale#)
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Shuffle',true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Shuffle',false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Shuffle')"]

[MeterRepeat]
Meter=Shape
MeterStyle=MediaTransportToggleStyle
X=(#MediaTransportRepeatX#-#MediaTransportShadowPad#)
Shape4=Path LucideRepeatUpperArrowPath | Extend LucideToggleStroke
Shape5=Path LucideRepeatUpperPath | Extend LucideToggleStroke
Shape6=Path LucideRepeatLowerArrowPath | Extend LucideToggleStroke
Shape7=Path LucideRepeatLowerPath | Extend LucideToggleStroke
Shape8=Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0
LucideRepeatUpperArrowPath=(17*#MediaTransportToggleGlyphScale#),(2*#MediaTransportToggleGlyphScale#) | LineTo (21*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#) | LineTo (17*#MediaTransportToggleGlyphScale#),(10*#MediaTransportToggleGlyphScale#)
LucideRepeatUpperPath=(3*#MediaTransportToggleGlyphScale#),(11*#MediaTransportToggleGlyphScale#) | LineTo (3*#MediaTransportToggleGlyphScale#),(10*#MediaTransportToggleGlyphScale#) | ArcTo (7*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,0,0 | LineTo (21*#MediaTransportToggleGlyphScale#),(6*#MediaTransportToggleGlyphScale#)
LucideRepeatLowerArrowPath=(7*#MediaTransportToggleGlyphScale#),(22*#MediaTransportToggleGlyphScale#) | LineTo (3*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#) | LineTo (7*#MediaTransportToggleGlyphScale#),(14*#MediaTransportToggleGlyphScale#)
LucideRepeatLowerPath=(21*#MediaTransportToggleGlyphScale#),(13*#MediaTransportToggleGlyphScale#) | LineTo (21*#MediaTransportToggleGlyphScale#),(14*#MediaTransportToggleGlyphScale#) | ArcTo (17*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),(4*#MediaTransportToggleGlyphScale#),0,0,0 | LineTo (3*#MediaTransportToggleGlyphScale#),(18*#MediaTransportToggleGlyphScale#)
; repeat-1's extra stroke; Media.lua shows it in Shape8 only while repeating one.
LucideRepeatOnePath=(11*#MediaTransportToggleGlyphScale#),(10*#MediaTransportToggleGlyphScale#) | LineTo (12*#MediaTransportToggleGlyphScale#),(10*#MediaTransportToggleGlyphScale#) | LineTo (12*#MediaTransportToggleGlyphScale#),(14*#MediaTransportToggleGlyphScale#)
MouseOverAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Repeat',true)"]
MouseLeaveAction=[!CommandMeasure "MeasureMediaUI" "HoverTransport('Repeat',false)"]
LeftMouseUpAction=[!CommandMeasure "MeasureMediaUI" "Control('Repeat')"]
