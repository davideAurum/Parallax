; Original compact Audio instrument. Shared palette/font/geometry are inherited.
; Styles omit Meter=. Every actual meter declares its own type.
[StyleVisualizerSmall]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#MutedColor#
AntiAlias=1
ClipString=1
H=(18*#Scale#)

[MeterVisualizerBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterVisualizerPanel]
Meter=Shape
MeterStyle=StylePanel

; Original 14x14 level icon. Scale the drawing itself with title typography.
[MeterVisualizerIcon]
Meter=Shape
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Rectangle (#TitleIconScale#),(7*#TitleIconScale#),(2*#TitleIconScale#),(7*#TitleIconScale#),(#TitleIconScale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape2=Rectangle (6*#TitleIconScale#),0,(2*#TitleIconScale#),(14*#TitleIconScale#),(#TitleIconScale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape3=Rectangle (11*#TitleIconScale#),(4*#TitleIconScale#),(2*#TitleIconScale#),(10*#TitleIconScale#),(#TitleIconScale#) | Fill Color #MediaColor# | StrokeWidth 0
UpdateDivider=-1

[MeterVisualizerTitle]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow
X=(#ContentX#+#TitleIconSize#+#TitleIconGap#)
W=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-66*#Scale#)
Text=Audio
UpdateDivider=-1

[MeterVisualizerVolume]
Meter=String
MeterStyle=StyleVisualizerSmall
MeasureName=MeasureVisualizerVolumeValue
X=(#ContentX#+#ContentWidth#)
Y=#TitleRowCenterY#
W=(60*#Scale#)
StringAlign=RightCenter
FontColor=#TextColor#
Text=--
NumOfDecimals=0
DynamicVariables=1
UpdateDivider=#VisualizerVolumeDivider#

; Original Parallax gear, matching the other utility headers and hover behavior.
[MeterVisualizerOptions]
Meter=Shape
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#TitleRowCenterY#-9*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
SolidColor=0,0,0,1
Shape=Path GearPath | Fill Color #AccentColor2# | StrokeWidth 0
Shape2=Ellipse (9*#Scale#),(9*#Scale#),(2.5*#Scale#),(2.5*#Scale#) | Fill Color #BackgroundColor# | StrokeWidth 0
GearPath=(9.000*#Scale#),(3.300*#Scale#) | LineTo (10.444*#Scale#),(1.742*#Scale#) | LineTo (11.832*#Scale#),(2.163*#Scale#) | LineTo (12.167*#Scale#),(4.261*#Scale#) | LineTo (13.031*#Scale#),(4.969*#Scale#) | LineTo (15.153*#Scale#),(4.889*#Scale#) | LineTo (15.837*#Scale#),(6.168*#Scale#) | LineTo (14.590*#Scale#),(7.888*#Scale#) | LineTo (14.700*#Scale#),(9.000*#Scale#) | LineTo (16.258*#Scale#),(10.444*#Scale#) | LineTo (15.837*#Scale#),(11.832*#Scale#) | LineTo (13.739*#Scale#),(12.167*#Scale#) | LineTo (13.031*#Scale#),(13.031*#Scale#) | LineTo (13.111*#Scale#),(15.153*#Scale#) | LineTo (11.832*#Scale#),(15.837*#Scale#) | LineTo (10.112*#Scale#),(14.590*#Scale#) | LineTo (9.000*#Scale#),(14.700*#Scale#) | LineTo (7.556*#Scale#),(16.258*#Scale#) | LineTo (6.168*#Scale#),(15.837*#Scale#) | LineTo (5.833*#Scale#),(13.739*#Scale#) | LineTo (4.969*#Scale#),(13.031*#Scale#) | LineTo (2.847*#Scale#),(13.111*#Scale#) | LineTo (2.163*#Scale#),(11.832*#Scale#) | LineTo (3.410*#Scale#),(10.112*#Scale#) | LineTo (3.300*#Scale#),(9.000*#Scale#) | LineTo (1.742*#Scale#),(7.556*#Scale#) | LineTo (2.163*#Scale#),(6.168*#Scale#) | LineTo (4.261*#Scale#),(5.833*#Scale#) | LineTo (4.969*#Scale#),(4.969*#Scale#) | LineTo (4.889*#Scale#),(2.847*#Scale#) | LineTo (6.168*#Scale#),(2.163*#Scale#) | LineTo (7.888*#Scale#),(3.410*#Scale#) | ClosePath 1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
ToolTipText=Open Audio settings for spectrum color, rounding, axis gap, sensitivity and animation.
LeftMouseUpAction=[!ActivateConfig "Parallax\Visualizer\Settings" "Settings.ini"]

; User-selected Lucide Speaker beside the current output device.
; Exact SVG source and ISC license: Icons\Lucide\README.md.
[MeterVisualizerOutputIcon]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(26+#VisualizerTopShift#)*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
AntiAlias=1
Shape=Rectangle (4*14*#Scale#/24),(2*14*#Scale#/24),(16*14*#Scale#/24),(20*14*#Scale#/24),(2*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape2=Line (12*14*#Scale#/24),(6*14*#Scale#/24),(12.01*14*#Scale#/24),(6*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape3=Ellipse (12*14*#Scale#/24),(14*14*#Scale#/24),(4*14*#Scale#/24),(4*14*#Scale#/24) | Extend LucideSpeakerStroke
Shape4=Line (12*14*#Scale#/24),(14*14*#Scale#/24),(12.01*14*#Scale#/24),(14*14*#Scale#/24) | Extend LucideSpeakerStroke
LucideSpeakerStroke=Fill Color 0,0,0,0 | Stroke Color #MediaColor# | StrokeWidth (2*14*#Scale#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UpdateDivider=-1

[MeterVisualizerDeviceName]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDeviceName
X=(#ContentX#+18*#Scale#)
Y=(#Inset#+(24+#VisualizerTopShift#)*#Scale#)
W=(#ContentWidth#-18*#Scale#)
H=(18*#Scale#)
Text=%1
DynamicVariables=1
UpdateDivider=(Max(1,Round(1000/#VisualizerEffectiveInterval#)))

; One transparent hit target keeps icon and text on a single interactive row.
; Switching changes the Windows default output, clears a custom capture ID and
; refreshes because AudioLevel parent options cannot be changed dynamically.
[MeterVisualizerDeviceHit]
Meter=Image
X=#ContentX#
Y=(#Inset#+(24+#VisualizerTopShift#)*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
SolidColor=0,0,0,1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerVolume "ToggleNext"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh]
MouseScrollDownAction=[!CommandMeasure MeasureVisualizerVolume "ToggleNext"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh]
MouseScrollUpAction=[!CommandMeasure MeasureVisualizerVolume "TogglePrevious"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!Refresh]
ToolTipText=Click for the next Windows output device; scroll for previous or next. Switching changes the system default output, clears a custom Visualizer device ID and reconnects the spectrum. [MeasureVisualizerDeviceName] | [MeasureVisualizerFormat] | Windows default output volume: [MeasureVisualizerVolume]. Audio playing through this spectrum device uses the first two channels and no volume processing. Spectrum dB scale: 0 at full normalized height, midpoint at minus half the selected sensitivity, and the bottom at minus the selected sensitivity. It is neither calibrated dBFS nor sound pressure and is separate from Windows volume. Quiet means the available endpoint is below the display threshold; mute, silence and quiet playback are indistinguishable. For capture problems, check Windows output settings and Rainmeter About > Log, then choose Reconnect output device from this skin's context menu.
DynamicVariables=1
UpdateDivider=-1

; One physical pixel border stays inside the chart. Empty/idle charts show no bars.
[MeterVisualizerPlot]
Meter=Shape
X=#VisualizerPlotX#
Y=(#Inset#+#VisualizerPlotTop#*#Scale#)
W=#VisualizerPlotWidth#
H=(#VisualizerPlotHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#VisualizerPlotWidth#-1),(#VisualizerPlotHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
; Grid lines sit on pixel centres (Floor(...)+1.5), within half a pixel of the
; exact quarters, so each 1px line renders as one crisp row.
Shape2=Line 1,(Floor(#VisualizerBarHeight#/4)+1.5),(#VisualizerPlotWidth#-1),(Floor(#VisualizerBarHeight#/4)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(Floor(#VisualizerBarHeight#/2)+1.5),(#VisualizerPlotWidth#-1),(Floor(#VisualizerBarHeight#/2)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(Floor(3*#VisualizerBarHeight#/4)+1.5),(#VisualizerPlotWidth#-1),(Floor(3*#VisualizerBarHeight#/4)+1.5) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1

[MeterVisualizerUnavailable]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#VisualizerPlotX#+#VisualizerPlotWidth#/2)
Y=(#Inset#+(#VisualizerPlotTop#+#VisualizerPlotHeight#/2)*#Scale#)
W=(#VisualizerPlotWidth#-8*#Scale#)
StringAlign=CenterCenter
Text=Output unavailable
FontColor=#WarningColor#
SolidColor=#GraphBackgroundColor#

[MeterVisualizerLow]
Meter=String
MeterStyle=StyleVisualizerSmall
X=#VisualizerPlotX#
Y=(#Inset#+#PanelHeightPx#-22*#Scale#)
W=(50*#Scale#)
Text=40 Hz
UpdateDivider=-1

[MeterVisualizerHigh]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+#PanelHeightPx#-22*#Scale#)
W=(50*#Scale#)
StringAlign=Right
Text=16 kHz
UpdateDivider=-1

; Spectrum dB ticks invert AudioLevel's sensitivity-normalized band scale.
[MeterVisualizerDbMax]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#VisualizerPlotX#-4*#Scale#)
Y=(#Inset#+#VisualizerPlotTop#*#Scale#+1)
W=(36*#Scale#)
StringAlign=Right
Text=0 dB
UpdateDivider=-1

[MeterVisualizerDbMid]
Meter=String
MeterStyle=StyleVisualizerSmall
MeasureName=MeasureVisualizerDbMid
X=(#VisualizerPlotX#-4*#Scale#)
Y=(#Inset#+#VisualizerPlotTop#*#Scale#+1+#VisualizerBarHeight#/2)
W=(36*#Scale#)
StringAlign=RightCenter
Text=%1
NumOfDecimals=1
UpdateDivider=-1

[MeterVisualizerDbMin]
Meter=String
MeterStyle=StyleVisualizerSmall
MeasureName=MeasureVisualizerDbMin
X=(#VisualizerPlotX#-4*#Scale#)
Y=(#Inset#+#VisualizerPlotTop#*#Scale#+1+#VisualizerBarHeight#)
W=(36*#Scale#)
StringAlign=RightBottom
Text=%1
NumOfDecimals=1
UpdateDivider=-1
