[Variables]
IOLucideScale=(#TitleIconSize#/24)
IOGraphHeight=62
IOBarExtra=(Max(0,#DataBarThicknessPx#/#Scale#-6))
; Grow only the derived height; keep the user's saved panel minimum intact.
; Inline the shared pixel rule: WindowHeight expands before the later bar keys.
PanelHeightPx=(Round(Max(#IOMinPanelHeight#,152+Max(0,Max(1,Round(#DataBarThickness#*#Scale#))/#Scale#-6))*#Scale#))

[MeasureIO]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\IO\IO.lua

; Dense instrument styles. Every actual meter declares Meter explicitly.
[StyleIOText]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontColor=#TextColor#
StringStyle=Normal
FontWeight=500
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

; Leave H undefined: ClipString=1 then uses natural single-line text height.
; Do not inherit StyleIOText, whose fixed H can admit wrapping at small fonts.
[StyleIODriveName]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontColor=#TextColor#
StringStyle=Normal
FontWeight=500
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#

[StyleIOHeader]
FontFace=#FontFace#
FontSize=(#HeaderFontSize#*#Scale#)
FontColor=#HeaderTextColor#
FontWeight=600
AntiAlias=1
ClipString=1
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[StyleIOBar]
X=#ContentX#
W=#ContentWidth#
H=#DataBarThicknessPx#
BarOrientation=Horizontal
BarColor=#DiskReadColor#
SolidColor=#TrackColor#
Hidden=1

[StyleIOGlyph]
X=#ContentX#
W=(16*#Scale#)
H=(16*#Scale#)
UpdateDivider=-1

; Lucide gauge, adapted to native Shapes from @Resources/Modules/CPU/Icons/gauge.svg
; at 14 logical px, as GPU Meter does. It labels the load percentage below it.
[StyleIOGauge]
W=(14*#Scale#)
H=(14*#Scale#)
Shape=Path IOGaugeArc | Extend IOGaugeStroke
Shape2=Line (12*14*#Scale#/24),(14*14*#Scale#/24),(16*14*#Scale#/24),(10*14*#Scale#/24) | Extend IOGaugeStroke
IOGaugeStroke=Fill Color 0,0,0,0 | Stroke Color #TextColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
; SVG "a10 10 0 1 1" = large arc, clockwise; Rainmeter's sweep flag is the
; reverse of SVG's, so this must be 0,0,1.
IOGaugeArc=(3.34*14*#Scale#/24),(19*14*#Scale#/24) | ArcTo (20.66*14*#Scale#/24),(19*14*#Scale#/24),(10*14*#Scale#/24),(10*14*#Scale#/24),0,0,1

; Original eject glyph on the same 24-unit grid and 2-unit round stroke as
; the Lucide icons: a triangle over a bar, at 14 logical px. The meter is a
; 20x18 hit box (the name row's height plus the 6px gap before it): Shape
; meters only take clicks on drawn pixels, so an alpha-1 rectangle fills it.
; The glyph keeps its place at the box's right edge, 1px below the row top,
; and brightens from MutedColor to TextColor on hover.
[StyleIOEject]
W=(20*#Scale#)
H=(18*#Scale#)
Shape=Rectangle 0,0,(20*#Scale#),(18*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Path IOEjectTriangle | Extend IOEjectStroke, IOEjectColor
Shape3=Line (5*14*#Scale#/24),(18*14*#Scale#/24),(19*14*#Scale#/24),(18*14*#Scale#/24) | Extend IOEjectStroke, IOEjectColor
IOEjectStroke=Fill Color 0,0,0,0 | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round | Offset (6*#Scale#),#Scale#
IOEjectColor=Stroke Color #MutedColor#
IOEjectTriangle=(12*14*#Scale#/24),(5*14*#Scale#/24) | LineTo (19*14*#Scale#/24),(13*14*#Scale#/24) | LineTo (5*14*#Scale#/24),(13*14*#Scale#/24) | ClosePath 1

[MeterIOBounds]
Meter=Image
MeterStyle=StyleBounds
DynamicVariables=1

[MeterIOPanel]
Meter=Shape
MeterStyle=StylePanel
DynamicVariables=1

; User-selected Lucide hard-drive; source and license: Icons/Lucide/README.md.
[MeterIOIcon]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Path LucideHardDrivePath | Extend LucideHardDriveStroke
Shape2=Line (21.946*#IOLucideScale#),(12.013*#IOLucideScale#),(2.054*#IOLucideScale#),(12.013*#IOLucideScale#) | Extend LucideHardDriveStroke
Shape3=Line (10*#IOLucideScale#),(16*#IOLucideScale#),(10.01*#IOLucideScale#),(16*#IOLucideScale#) | Extend LucideHardDriveStroke
Shape4=Line (6*#IOLucideScale#),(16*#IOLucideScale#),(6.01*#IOLucideScale#),(16*#IOLucideScale#) | Extend LucideHardDriveStroke
LucideHardDriveStroke=Fill Color 0,0,0,0 | Stroke Color #MutedColor# | StrokeWidth (2*#IOLucideScale#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
LucideHardDrivePath=(2.212*#IOLucideScale#),(11.577*#IOLucideScale#) | ArcTo (2*#IOLucideScale#),(12.473*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | LineTo (2*#IOLucideScale#),(18*#IOLucideScale#) | ArcTo (4*#IOLucideScale#),(20*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | LineTo (20*#IOLucideScale#),(20*#IOLucideScale#) | ArcTo (22*#IOLucideScale#),(18*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | LineTo (22*#IOLucideScale#),(12.473*#IOLucideScale#) | ArcTo (21.788*#IOLucideScale#),(11.577*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | LineTo (18.55*#IOLucideScale#),(5.11*#IOLucideScale#) | ArcTo (16.76*#IOLucideScale#),(4*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | LineTo (7.24*#IOLucideScale#),(4*#IOLucideScale#) | ArcTo (5.45*#IOLucideScale#),(5.11*#IOLucideScale#),(2*#IOLucideScale#),(2*#IOLucideScale#),0,1,0 | ClosePath 1
UpdateDivider=-1

[MeterIOTitle]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleTitle|StyleTitleRow
X=(#ContentX#+#TitleIconSize#+#TitleIconGap#)
W=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-52*#Scale#)
Text=Disk Meter

[MeterIOTotal]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleTitle|StyleTitleRow
; This is live capacity data, independent of title typography.
FontSize=(#FontSize#*#Scale#)
FontColor=#TextColor#
X=(#ContentX#+#ContentWidth#)
W=(48*#Scale#)
StringAlign=RightCenter
Text=--

[MeterIOOptions]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#TitleRowCenterY#-9*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
; Original eight-tooth gear; hidden meters have no mouse hit target.
Shape=Path GearPath | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Ellipse (9*#Scale#),(9*#Scale#),(2.5*#Scale#),(2.5*#Scale#) | Fill Color #BackgroundColor# | StrokeWidth 0
GearPath=(9.000*#Scale#),(3.300*#Scale#) | LineTo (10.444*#Scale#),(1.742*#Scale#) | LineTo (11.832*#Scale#),(2.163*#Scale#) | LineTo (12.167*#Scale#),(4.261*#Scale#) | LineTo (13.031*#Scale#),(4.969*#Scale#) | LineTo (15.153*#Scale#),(4.889*#Scale#) | LineTo (15.837*#Scale#),(6.168*#Scale#) | LineTo (14.590*#Scale#),(7.888*#Scale#) | LineTo (14.700*#Scale#),(9.000*#Scale#) | LineTo (16.258*#Scale#),(10.444*#Scale#) | LineTo (15.837*#Scale#),(11.832*#Scale#) | LineTo (13.739*#Scale#),(12.167*#Scale#) | LineTo (13.031*#Scale#),(13.031*#Scale#) | LineTo (13.111*#Scale#),(15.153*#Scale#) | LineTo (11.832*#Scale#),(15.837*#Scale#) | LineTo (10.112*#Scale#),(14.590*#Scale#) | LineTo (9.000*#Scale#),(14.700*#Scale#) | LineTo (7.556*#Scale#),(16.258*#Scale#) | LineTo (6.168*#Scale#),(15.837*#Scale#) | LineTo (5.833*#Scale#),(13.739*#Scale#) | LineTo (4.969*#Scale#),(13.031*#Scale#) | LineTo (2.847*#Scale#),(13.111*#Scale#) | LineTo (2.163*#Scale#),(11.832*#Scale#) | LineTo (3.410*#Scale#),(10.112*#Scale#) | LineTo (3.300*#Scale#),(9.000*#Scale#) | LineTo (1.742*#Scale#),(7.556*#Scale#) | LineTo (2.163*#Scale#),(6.168*#Scale#) | LineTo (4.261*#Scale#),(5.833*#Scale#) | LineTo (4.969*#Scale#),(4.969*#Scale#) | LineTo (4.889*#Scale#),(2.847*#Scale#) | LineTo (6.168*#Scale#),(2.163*#Scale#) | LineTo (7.888*#Scale#),(3.410*#Scale#) | ClosePath 1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\IO\Settings" "Settings.ini"]


[IODriveMeterInclude]
@Include10=#@#Modules\IO\DriveMeters.inc

[MeterIOEmpty]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleIOText
Y=(#Inset#+24*#Scale#)
Text=Select drives in settings.
Hidden=1

; Match the CPU graph's compact frame and quarter-height grid.
[MeterIODiskGraphTrack]
Meter=Shape
MeterStyle=StyleGraph
Y=(#Inset#+(84+#IOBarExtra#)*#Scale#)
H=(#IOGraphHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#IOGraphHeight#*#Scale#-1) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#IOGraphHeight#*#Scale#/4),(#ContentWidth#-1),(#IOGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#IOGraphHeight#*#Scale#/2),(#ContentWidth#-1),(#IOGraphHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#IOGraphHeight#*#Scale#/4),(#ContentWidth#-1),(3*#IOGraphHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1

[MeterIODiskGraph]
Meter=Shape
Group=ParallaxIdleFreeze
X=#ContentX#
Y=(#Inset#+(84+#IOBarExtra#)*#Scale#)
W=#ContentWidth#
H=(#IOGraphHeight#*#Scale#)
; The controller draws only observations; startup history is empty.
Shape=Line 0,0,0,0 | StrokeWidth 0
Hidden=1
DynamicVariables=1
UpdateDivider=1

; Split-mode axis markers stay inside the single graph. Controller positions
; and shows these only for the positive/negative view; no extra graph is drawn.
[StyleIOGraphAxis]
FontFace=#FontFace#
FontSize=(Max(6,#FontSize#-2)*#Scale#)
FontColor=#MutedColor#
FontWeight=500
AntiAlias=1
ClipString=1
StringAlign=Right
X=(#ContentX#+#ContentWidth#-2*#Scale#)
Y=0
W=(12*#Scale#)
H=(14*#Scale#)
Hidden=1

[MeterIOGraphPositive]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleIOGraphAxis
Text=+

[MeterIOGraphZero]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleIOGraphAxis
Text=0

[MeterIOGraphNegative]
Meter=String
Group=ParallaxIdleFreeze
MeterStyle=StyleIOGraphAxis
Text=-
