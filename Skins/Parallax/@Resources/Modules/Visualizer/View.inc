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
Shape2=Line 1,(1+#VisualizerBarHeight#/4),(#VisualizerPlotWidth#-1),(1+#VisualizerBarHeight#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(1+#VisualizerBarHeight#/2),(#VisualizerPlotWidth#-1),(1+#VisualizerBarHeight#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(1+3*#VisualizerBarHeight#/4),(#VisualizerPlotWidth#-1),(1+3*#VisualizerBarHeight#/4) | Stroke Color #GridColor# | StrokeWidth 1
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

; One fully opaque native path mask; measured heights update with the spectrum.
; Only top corners are rounded. Fixed bounds retain the full plot at silence.
[MeterVisualizerSpectrumMask]
Meter=Shape
X=(#VisualizerPlotX#+1)
Y=(#Inset#+#VisualizerPlotTop#*#Scale#+1)
W=#VisualizerPlotInnerWidth#
H=#VisualizerPlotInnerHeight#
SolidColor=0,0,0,0
AntiAlias=1
DynamicVariables=1
Group=VisualizerSpectrum
Hidden=1
Shape=Path BandPath0 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath0=#VisualizerBandLeft0#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft0#,(#VisualizerBandTop0#+#VisualizerBandRadius0#) | CurveTo (#VisualizerBandLeft0#+#VisualizerBandRadius0#),#VisualizerBandTop0#,#VisualizerBandLeft0#,(#VisualizerBandTop0#+0.44771525*#VisualizerBandRadius0#),(#VisualizerBandLeft0#+0.44771525*#VisualizerBandRadius0#),#VisualizerBandTop0# | LineTo ((#VisualizerBandLeft0#+#VisualizerBandWidth0#)-#VisualizerBandRadius0#),#VisualizerBandTop0# | CurveTo (#VisualizerBandLeft0#+#VisualizerBandWidth0#),(#VisualizerBandTop0#+#VisualizerBandRadius0#),((#VisualizerBandLeft0#+#VisualizerBandWidth0#)-0.44771525*#VisualizerBandRadius0#),#VisualizerBandTop0#,(#VisualizerBandLeft0#+#VisualizerBandWidth0#),(#VisualizerBandTop0#+0.44771525*#VisualizerBandRadius0#) | LineTo (#VisualizerBandLeft0#+#VisualizerBandWidth0#),#VisualizerBarHeight# | ClosePath 1
Shape2=Path BandPath1 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath1=#VisualizerBandLeft1#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft1#,(#VisualizerBandTop1#+#VisualizerBandRadius1#) | CurveTo (#VisualizerBandLeft1#+#VisualizerBandRadius1#),#VisualizerBandTop1#,#VisualizerBandLeft1#,(#VisualizerBandTop1#+0.44771525*#VisualizerBandRadius1#),(#VisualizerBandLeft1#+0.44771525*#VisualizerBandRadius1#),#VisualizerBandTop1# | LineTo ((#VisualizerBandLeft1#+#VisualizerBandWidth1#)-#VisualizerBandRadius1#),#VisualizerBandTop1# | CurveTo (#VisualizerBandLeft1#+#VisualizerBandWidth1#),(#VisualizerBandTop1#+#VisualizerBandRadius1#),((#VisualizerBandLeft1#+#VisualizerBandWidth1#)-0.44771525*#VisualizerBandRadius1#),#VisualizerBandTop1#,(#VisualizerBandLeft1#+#VisualizerBandWidth1#),(#VisualizerBandTop1#+0.44771525*#VisualizerBandRadius1#) | LineTo (#VisualizerBandLeft1#+#VisualizerBandWidth1#),#VisualizerBarHeight# | ClosePath 1
Shape3=Path BandPath2 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath2=#VisualizerBandLeft2#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft2#,(#VisualizerBandTop2#+#VisualizerBandRadius2#) | CurveTo (#VisualizerBandLeft2#+#VisualizerBandRadius2#),#VisualizerBandTop2#,#VisualizerBandLeft2#,(#VisualizerBandTop2#+0.44771525*#VisualizerBandRadius2#),(#VisualizerBandLeft2#+0.44771525*#VisualizerBandRadius2#),#VisualizerBandTop2# | LineTo ((#VisualizerBandLeft2#+#VisualizerBandWidth2#)-#VisualizerBandRadius2#),#VisualizerBandTop2# | CurveTo (#VisualizerBandLeft2#+#VisualizerBandWidth2#),(#VisualizerBandTop2#+#VisualizerBandRadius2#),((#VisualizerBandLeft2#+#VisualizerBandWidth2#)-0.44771525*#VisualizerBandRadius2#),#VisualizerBandTop2#,(#VisualizerBandLeft2#+#VisualizerBandWidth2#),(#VisualizerBandTop2#+0.44771525*#VisualizerBandRadius2#) | LineTo (#VisualizerBandLeft2#+#VisualizerBandWidth2#),#VisualizerBarHeight# | ClosePath 1
Shape4=Path BandPath3 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath3=#VisualizerBandLeft3#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft3#,(#VisualizerBandTop3#+#VisualizerBandRadius3#) | CurveTo (#VisualizerBandLeft3#+#VisualizerBandRadius3#),#VisualizerBandTop3#,#VisualizerBandLeft3#,(#VisualizerBandTop3#+0.44771525*#VisualizerBandRadius3#),(#VisualizerBandLeft3#+0.44771525*#VisualizerBandRadius3#),#VisualizerBandTop3# | LineTo ((#VisualizerBandLeft3#+#VisualizerBandWidth3#)-#VisualizerBandRadius3#),#VisualizerBandTop3# | CurveTo (#VisualizerBandLeft3#+#VisualizerBandWidth3#),(#VisualizerBandTop3#+#VisualizerBandRadius3#),((#VisualizerBandLeft3#+#VisualizerBandWidth3#)-0.44771525*#VisualizerBandRadius3#),#VisualizerBandTop3#,(#VisualizerBandLeft3#+#VisualizerBandWidth3#),(#VisualizerBandTop3#+0.44771525*#VisualizerBandRadius3#) | LineTo (#VisualizerBandLeft3#+#VisualizerBandWidth3#),#VisualizerBarHeight# | ClosePath 1
Shape5=Path BandPath4 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath4=#VisualizerBandLeft4#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft4#,(#VisualizerBandTop4#+#VisualizerBandRadius4#) | CurveTo (#VisualizerBandLeft4#+#VisualizerBandRadius4#),#VisualizerBandTop4#,#VisualizerBandLeft4#,(#VisualizerBandTop4#+0.44771525*#VisualizerBandRadius4#),(#VisualizerBandLeft4#+0.44771525*#VisualizerBandRadius4#),#VisualizerBandTop4# | LineTo ((#VisualizerBandLeft4#+#VisualizerBandWidth4#)-#VisualizerBandRadius4#),#VisualizerBandTop4# | CurveTo (#VisualizerBandLeft4#+#VisualizerBandWidth4#),(#VisualizerBandTop4#+#VisualizerBandRadius4#),((#VisualizerBandLeft4#+#VisualizerBandWidth4#)-0.44771525*#VisualizerBandRadius4#),#VisualizerBandTop4#,(#VisualizerBandLeft4#+#VisualizerBandWidth4#),(#VisualizerBandTop4#+0.44771525*#VisualizerBandRadius4#) | LineTo (#VisualizerBandLeft4#+#VisualizerBandWidth4#),#VisualizerBarHeight# | ClosePath 1
Shape6=Path BandPath5 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath5=#VisualizerBandLeft5#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft5#,(#VisualizerBandTop5#+#VisualizerBandRadius5#) | CurveTo (#VisualizerBandLeft5#+#VisualizerBandRadius5#),#VisualizerBandTop5#,#VisualizerBandLeft5#,(#VisualizerBandTop5#+0.44771525*#VisualizerBandRadius5#),(#VisualizerBandLeft5#+0.44771525*#VisualizerBandRadius5#),#VisualizerBandTop5# | LineTo ((#VisualizerBandLeft5#+#VisualizerBandWidth5#)-#VisualizerBandRadius5#),#VisualizerBandTop5# | CurveTo (#VisualizerBandLeft5#+#VisualizerBandWidth5#),(#VisualizerBandTop5#+#VisualizerBandRadius5#),((#VisualizerBandLeft5#+#VisualizerBandWidth5#)-0.44771525*#VisualizerBandRadius5#),#VisualizerBandTop5#,(#VisualizerBandLeft5#+#VisualizerBandWidth5#),(#VisualizerBandTop5#+0.44771525*#VisualizerBandRadius5#) | LineTo (#VisualizerBandLeft5#+#VisualizerBandWidth5#),#VisualizerBarHeight# | ClosePath 1
Shape7=Path BandPath6 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath6=#VisualizerBandLeft6#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft6#,(#VisualizerBandTop6#+#VisualizerBandRadius6#) | CurveTo (#VisualizerBandLeft6#+#VisualizerBandRadius6#),#VisualizerBandTop6#,#VisualizerBandLeft6#,(#VisualizerBandTop6#+0.44771525*#VisualizerBandRadius6#),(#VisualizerBandLeft6#+0.44771525*#VisualizerBandRadius6#),#VisualizerBandTop6# | LineTo ((#VisualizerBandLeft6#+#VisualizerBandWidth6#)-#VisualizerBandRadius6#),#VisualizerBandTop6# | CurveTo (#VisualizerBandLeft6#+#VisualizerBandWidth6#),(#VisualizerBandTop6#+#VisualizerBandRadius6#),((#VisualizerBandLeft6#+#VisualizerBandWidth6#)-0.44771525*#VisualizerBandRadius6#),#VisualizerBandTop6#,(#VisualizerBandLeft6#+#VisualizerBandWidth6#),(#VisualizerBandTop6#+0.44771525*#VisualizerBandRadius6#) | LineTo (#VisualizerBandLeft6#+#VisualizerBandWidth6#),#VisualizerBarHeight# | ClosePath 1
Shape8=Path BandPath7 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath7=#VisualizerBandLeft7#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft7#,(#VisualizerBandTop7#+#VisualizerBandRadius7#) | CurveTo (#VisualizerBandLeft7#+#VisualizerBandRadius7#),#VisualizerBandTop7#,#VisualizerBandLeft7#,(#VisualizerBandTop7#+0.44771525*#VisualizerBandRadius7#),(#VisualizerBandLeft7#+0.44771525*#VisualizerBandRadius7#),#VisualizerBandTop7# | LineTo ((#VisualizerBandLeft7#+#VisualizerBandWidth7#)-#VisualizerBandRadius7#),#VisualizerBandTop7# | CurveTo (#VisualizerBandLeft7#+#VisualizerBandWidth7#),(#VisualizerBandTop7#+#VisualizerBandRadius7#),((#VisualizerBandLeft7#+#VisualizerBandWidth7#)-0.44771525*#VisualizerBandRadius7#),#VisualizerBandTop7#,(#VisualizerBandLeft7#+#VisualizerBandWidth7#),(#VisualizerBandTop7#+0.44771525*#VisualizerBandRadius7#) | LineTo (#VisualizerBandLeft7#+#VisualizerBandWidth7#),#VisualizerBarHeight# | ClosePath 1
Shape9=Path BandPath8 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath8=#VisualizerBandLeft8#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft8#,(#VisualizerBandTop8#+#VisualizerBandRadius8#) | CurveTo (#VisualizerBandLeft8#+#VisualizerBandRadius8#),#VisualizerBandTop8#,#VisualizerBandLeft8#,(#VisualizerBandTop8#+0.44771525*#VisualizerBandRadius8#),(#VisualizerBandLeft8#+0.44771525*#VisualizerBandRadius8#),#VisualizerBandTop8# | LineTo ((#VisualizerBandLeft8#+#VisualizerBandWidth8#)-#VisualizerBandRadius8#),#VisualizerBandTop8# | CurveTo (#VisualizerBandLeft8#+#VisualizerBandWidth8#),(#VisualizerBandTop8#+#VisualizerBandRadius8#),((#VisualizerBandLeft8#+#VisualizerBandWidth8#)-0.44771525*#VisualizerBandRadius8#),#VisualizerBandTop8#,(#VisualizerBandLeft8#+#VisualizerBandWidth8#),(#VisualizerBandTop8#+0.44771525*#VisualizerBandRadius8#) | LineTo (#VisualizerBandLeft8#+#VisualizerBandWidth8#),#VisualizerBarHeight# | ClosePath 1
Shape10=Path BandPath9 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath9=#VisualizerBandLeft9#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft9#,(#VisualizerBandTop9#+#VisualizerBandRadius9#) | CurveTo (#VisualizerBandLeft9#+#VisualizerBandRadius9#),#VisualizerBandTop9#,#VisualizerBandLeft9#,(#VisualizerBandTop9#+0.44771525*#VisualizerBandRadius9#),(#VisualizerBandLeft9#+0.44771525*#VisualizerBandRadius9#),#VisualizerBandTop9# | LineTo ((#VisualizerBandLeft9#+#VisualizerBandWidth9#)-#VisualizerBandRadius9#),#VisualizerBandTop9# | CurveTo (#VisualizerBandLeft9#+#VisualizerBandWidth9#),(#VisualizerBandTop9#+#VisualizerBandRadius9#),((#VisualizerBandLeft9#+#VisualizerBandWidth9#)-0.44771525*#VisualizerBandRadius9#),#VisualizerBandTop9#,(#VisualizerBandLeft9#+#VisualizerBandWidth9#),(#VisualizerBandTop9#+0.44771525*#VisualizerBandRadius9#) | LineTo (#VisualizerBandLeft9#+#VisualizerBandWidth9#),#VisualizerBarHeight# | ClosePath 1
Shape11=Path BandPath10 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath10=#VisualizerBandLeft10#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft10#,(#VisualizerBandTop10#+#VisualizerBandRadius10#) | CurveTo (#VisualizerBandLeft10#+#VisualizerBandRadius10#),#VisualizerBandTop10#,#VisualizerBandLeft10#,(#VisualizerBandTop10#+0.44771525*#VisualizerBandRadius10#),(#VisualizerBandLeft10#+0.44771525*#VisualizerBandRadius10#),#VisualizerBandTop10# | LineTo ((#VisualizerBandLeft10#+#VisualizerBandWidth10#)-#VisualizerBandRadius10#),#VisualizerBandTop10# | CurveTo (#VisualizerBandLeft10#+#VisualizerBandWidth10#),(#VisualizerBandTop10#+#VisualizerBandRadius10#),((#VisualizerBandLeft10#+#VisualizerBandWidth10#)-0.44771525*#VisualizerBandRadius10#),#VisualizerBandTop10#,(#VisualizerBandLeft10#+#VisualizerBandWidth10#),(#VisualizerBandTop10#+0.44771525*#VisualizerBandRadius10#) | LineTo (#VisualizerBandLeft10#+#VisualizerBandWidth10#),#VisualizerBarHeight# | ClosePath 1
Shape12=Path BandPath11 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath11=#VisualizerBandLeft11#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft11#,(#VisualizerBandTop11#+#VisualizerBandRadius11#) | CurveTo (#VisualizerBandLeft11#+#VisualizerBandRadius11#),#VisualizerBandTop11#,#VisualizerBandLeft11#,(#VisualizerBandTop11#+0.44771525*#VisualizerBandRadius11#),(#VisualizerBandLeft11#+0.44771525*#VisualizerBandRadius11#),#VisualizerBandTop11# | LineTo ((#VisualizerBandLeft11#+#VisualizerBandWidth11#)-#VisualizerBandRadius11#),#VisualizerBandTop11# | CurveTo (#VisualizerBandLeft11#+#VisualizerBandWidth11#),(#VisualizerBandTop11#+#VisualizerBandRadius11#),((#VisualizerBandLeft11#+#VisualizerBandWidth11#)-0.44771525*#VisualizerBandRadius11#),#VisualizerBandTop11#,(#VisualizerBandLeft11#+#VisualizerBandWidth11#),(#VisualizerBandTop11#+0.44771525*#VisualizerBandRadius11#) | LineTo (#VisualizerBandLeft11#+#VisualizerBandWidth11#),#VisualizerBarHeight# | ClosePath 1
Shape13=Path BandPath12 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath12=#VisualizerBandLeft12#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft12#,(#VisualizerBandTop12#+#VisualizerBandRadius12#) | CurveTo (#VisualizerBandLeft12#+#VisualizerBandRadius12#),#VisualizerBandTop12#,#VisualizerBandLeft12#,(#VisualizerBandTop12#+0.44771525*#VisualizerBandRadius12#),(#VisualizerBandLeft12#+0.44771525*#VisualizerBandRadius12#),#VisualizerBandTop12# | LineTo ((#VisualizerBandLeft12#+#VisualizerBandWidth12#)-#VisualizerBandRadius12#),#VisualizerBandTop12# | CurveTo (#VisualizerBandLeft12#+#VisualizerBandWidth12#),(#VisualizerBandTop12#+#VisualizerBandRadius12#),((#VisualizerBandLeft12#+#VisualizerBandWidth12#)-0.44771525*#VisualizerBandRadius12#),#VisualizerBandTop12#,(#VisualizerBandLeft12#+#VisualizerBandWidth12#),(#VisualizerBandTop12#+0.44771525*#VisualizerBandRadius12#) | LineTo (#VisualizerBandLeft12#+#VisualizerBandWidth12#),#VisualizerBarHeight# | ClosePath 1
Shape14=Path BandPath13 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath13=#VisualizerBandLeft13#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft13#,(#VisualizerBandTop13#+#VisualizerBandRadius13#) | CurveTo (#VisualizerBandLeft13#+#VisualizerBandRadius13#),#VisualizerBandTop13#,#VisualizerBandLeft13#,(#VisualizerBandTop13#+0.44771525*#VisualizerBandRadius13#),(#VisualizerBandLeft13#+0.44771525*#VisualizerBandRadius13#),#VisualizerBandTop13# | LineTo ((#VisualizerBandLeft13#+#VisualizerBandWidth13#)-#VisualizerBandRadius13#),#VisualizerBandTop13# | CurveTo (#VisualizerBandLeft13#+#VisualizerBandWidth13#),(#VisualizerBandTop13#+#VisualizerBandRadius13#),((#VisualizerBandLeft13#+#VisualizerBandWidth13#)-0.44771525*#VisualizerBandRadius13#),#VisualizerBandTop13#,(#VisualizerBandLeft13#+#VisualizerBandWidth13#),(#VisualizerBandTop13#+0.44771525*#VisualizerBandRadius13#) | LineTo (#VisualizerBandLeft13#+#VisualizerBandWidth13#),#VisualizerBarHeight# | ClosePath 1
Shape15=Path BandPath14 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath14=#VisualizerBandLeft14#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft14#,(#VisualizerBandTop14#+#VisualizerBandRadius14#) | CurveTo (#VisualizerBandLeft14#+#VisualizerBandRadius14#),#VisualizerBandTop14#,#VisualizerBandLeft14#,(#VisualizerBandTop14#+0.44771525*#VisualizerBandRadius14#),(#VisualizerBandLeft14#+0.44771525*#VisualizerBandRadius14#),#VisualizerBandTop14# | LineTo ((#VisualizerBandLeft14#+#VisualizerBandWidth14#)-#VisualizerBandRadius14#),#VisualizerBandTop14# | CurveTo (#VisualizerBandLeft14#+#VisualizerBandWidth14#),(#VisualizerBandTop14#+#VisualizerBandRadius14#),((#VisualizerBandLeft14#+#VisualizerBandWidth14#)-0.44771525*#VisualizerBandRadius14#),#VisualizerBandTop14#,(#VisualizerBandLeft14#+#VisualizerBandWidth14#),(#VisualizerBandTop14#+0.44771525*#VisualizerBandRadius14#) | LineTo (#VisualizerBandLeft14#+#VisualizerBandWidth14#),#VisualizerBarHeight# | ClosePath 1
Shape16=Path BandPath15 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath15=#VisualizerBandLeft15#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft15#,(#VisualizerBandTop15#+#VisualizerBandRadius15#) | CurveTo (#VisualizerBandLeft15#+#VisualizerBandRadius15#),#VisualizerBandTop15#,#VisualizerBandLeft15#,(#VisualizerBandTop15#+0.44771525*#VisualizerBandRadius15#),(#VisualizerBandLeft15#+0.44771525*#VisualizerBandRadius15#),#VisualizerBandTop15# | LineTo ((#VisualizerBandLeft15#+#VisualizerBandWidth15#)-#VisualizerBandRadius15#),#VisualizerBandTop15# | CurveTo (#VisualizerBandLeft15#+#VisualizerBandWidth15#),(#VisualizerBandTop15#+#VisualizerBandRadius15#),((#VisualizerBandLeft15#+#VisualizerBandWidth15#)-0.44771525*#VisualizerBandRadius15#),#VisualizerBandTop15#,(#VisualizerBandLeft15#+#VisualizerBandWidth15#),(#VisualizerBandTop15#+0.44771525*#VisualizerBandRadius15#) | LineTo (#VisualizerBandLeft15#+#VisualizerBandWidth15#),#VisualizerBarHeight# | ClosePath 1
Shape17=Path BandPath16 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath16=#VisualizerBandLeft16#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft16#,(#VisualizerBandTop16#+#VisualizerBandRadius16#) | CurveTo (#VisualizerBandLeft16#+#VisualizerBandRadius16#),#VisualizerBandTop16#,#VisualizerBandLeft16#,(#VisualizerBandTop16#+0.44771525*#VisualizerBandRadius16#),(#VisualizerBandLeft16#+0.44771525*#VisualizerBandRadius16#),#VisualizerBandTop16# | LineTo ((#VisualizerBandLeft16#+#VisualizerBandWidth16#)-#VisualizerBandRadius16#),#VisualizerBandTop16# | CurveTo (#VisualizerBandLeft16#+#VisualizerBandWidth16#),(#VisualizerBandTop16#+#VisualizerBandRadius16#),((#VisualizerBandLeft16#+#VisualizerBandWidth16#)-0.44771525*#VisualizerBandRadius16#),#VisualizerBandTop16#,(#VisualizerBandLeft16#+#VisualizerBandWidth16#),(#VisualizerBandTop16#+0.44771525*#VisualizerBandRadius16#) | LineTo (#VisualizerBandLeft16#+#VisualizerBandWidth16#),#VisualizerBarHeight# | ClosePath 1
Shape18=Path BandPath17 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath17=#VisualizerBandLeft17#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft17#,(#VisualizerBandTop17#+#VisualizerBandRadius17#) | CurveTo (#VisualizerBandLeft17#+#VisualizerBandRadius17#),#VisualizerBandTop17#,#VisualizerBandLeft17#,(#VisualizerBandTop17#+0.44771525*#VisualizerBandRadius17#),(#VisualizerBandLeft17#+0.44771525*#VisualizerBandRadius17#),#VisualizerBandTop17# | LineTo ((#VisualizerBandLeft17#+#VisualizerBandWidth17#)-#VisualizerBandRadius17#),#VisualizerBandTop17# | CurveTo (#VisualizerBandLeft17#+#VisualizerBandWidth17#),(#VisualizerBandTop17#+#VisualizerBandRadius17#),((#VisualizerBandLeft17#+#VisualizerBandWidth17#)-0.44771525*#VisualizerBandRadius17#),#VisualizerBandTop17#,(#VisualizerBandLeft17#+#VisualizerBandWidth17#),(#VisualizerBandTop17#+0.44771525*#VisualizerBandRadius17#) | LineTo (#VisualizerBandLeft17#+#VisualizerBandWidth17#),#VisualizerBarHeight# | ClosePath 1
Shape19=Path BandPath18 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath18=#VisualizerBandLeft18#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft18#,(#VisualizerBandTop18#+#VisualizerBandRadius18#) | CurveTo (#VisualizerBandLeft18#+#VisualizerBandRadius18#),#VisualizerBandTop18#,#VisualizerBandLeft18#,(#VisualizerBandTop18#+0.44771525*#VisualizerBandRadius18#),(#VisualizerBandLeft18#+0.44771525*#VisualizerBandRadius18#),#VisualizerBandTop18# | LineTo ((#VisualizerBandLeft18#+#VisualizerBandWidth18#)-#VisualizerBandRadius18#),#VisualizerBandTop18# | CurveTo (#VisualizerBandLeft18#+#VisualizerBandWidth18#),(#VisualizerBandTop18#+#VisualizerBandRadius18#),((#VisualizerBandLeft18#+#VisualizerBandWidth18#)-0.44771525*#VisualizerBandRadius18#),#VisualizerBandTop18#,(#VisualizerBandLeft18#+#VisualizerBandWidth18#),(#VisualizerBandTop18#+0.44771525*#VisualizerBandRadius18#) | LineTo (#VisualizerBandLeft18#+#VisualizerBandWidth18#),#VisualizerBarHeight# | ClosePath 1
Shape20=Path BandPath19 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath19=#VisualizerBandLeft19#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft19#,(#VisualizerBandTop19#+#VisualizerBandRadius19#) | CurveTo (#VisualizerBandLeft19#+#VisualizerBandRadius19#),#VisualizerBandTop19#,#VisualizerBandLeft19#,(#VisualizerBandTop19#+0.44771525*#VisualizerBandRadius19#),(#VisualizerBandLeft19#+0.44771525*#VisualizerBandRadius19#),#VisualizerBandTop19# | LineTo ((#VisualizerBandLeft19#+#VisualizerBandWidth19#)-#VisualizerBandRadius19#),#VisualizerBandTop19# | CurveTo (#VisualizerBandLeft19#+#VisualizerBandWidth19#),(#VisualizerBandTop19#+#VisualizerBandRadius19#),((#VisualizerBandLeft19#+#VisualizerBandWidth19#)-0.44771525*#VisualizerBandRadius19#),#VisualizerBandTop19#,(#VisualizerBandLeft19#+#VisualizerBandWidth19#),(#VisualizerBandTop19#+0.44771525*#VisualizerBandRadius19#) | LineTo (#VisualizerBandLeft19#+#VisualizerBandWidth19#),#VisualizerBarHeight# | ClosePath 1
Shape21=Path BandPath20 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath20=#VisualizerBandLeft20#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft20#,(#VisualizerBandTop20#+#VisualizerBandRadius20#) | CurveTo (#VisualizerBandLeft20#+#VisualizerBandRadius20#),#VisualizerBandTop20#,#VisualizerBandLeft20#,(#VisualizerBandTop20#+0.44771525*#VisualizerBandRadius20#),(#VisualizerBandLeft20#+0.44771525*#VisualizerBandRadius20#),#VisualizerBandTop20# | LineTo ((#VisualizerBandLeft20#+#VisualizerBandWidth20#)-#VisualizerBandRadius20#),#VisualizerBandTop20# | CurveTo (#VisualizerBandLeft20#+#VisualizerBandWidth20#),(#VisualizerBandTop20#+#VisualizerBandRadius20#),((#VisualizerBandLeft20#+#VisualizerBandWidth20#)-0.44771525*#VisualizerBandRadius20#),#VisualizerBandTop20#,(#VisualizerBandLeft20#+#VisualizerBandWidth20#),(#VisualizerBandTop20#+0.44771525*#VisualizerBandRadius20#) | LineTo (#VisualizerBandLeft20#+#VisualizerBandWidth20#),#VisualizerBarHeight# | ClosePath 1
Shape22=Path BandPath21 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath21=#VisualizerBandLeft21#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft21#,(#VisualizerBandTop21#+#VisualizerBandRadius21#) | CurveTo (#VisualizerBandLeft21#+#VisualizerBandRadius21#),#VisualizerBandTop21#,#VisualizerBandLeft21#,(#VisualizerBandTop21#+0.44771525*#VisualizerBandRadius21#),(#VisualizerBandLeft21#+0.44771525*#VisualizerBandRadius21#),#VisualizerBandTop21# | LineTo ((#VisualizerBandLeft21#+#VisualizerBandWidth21#)-#VisualizerBandRadius21#),#VisualizerBandTop21# | CurveTo (#VisualizerBandLeft21#+#VisualizerBandWidth21#),(#VisualizerBandTop21#+#VisualizerBandRadius21#),((#VisualizerBandLeft21#+#VisualizerBandWidth21#)-0.44771525*#VisualizerBandRadius21#),#VisualizerBandTop21#,(#VisualizerBandLeft21#+#VisualizerBandWidth21#),(#VisualizerBandTop21#+0.44771525*#VisualizerBandRadius21#) | LineTo (#VisualizerBandLeft21#+#VisualizerBandWidth21#),#VisualizerBarHeight# | ClosePath 1
Shape23=Path BandPath22 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath22=#VisualizerBandLeft22#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft22#,(#VisualizerBandTop22#+#VisualizerBandRadius22#) | CurveTo (#VisualizerBandLeft22#+#VisualizerBandRadius22#),#VisualizerBandTop22#,#VisualizerBandLeft22#,(#VisualizerBandTop22#+0.44771525*#VisualizerBandRadius22#),(#VisualizerBandLeft22#+0.44771525*#VisualizerBandRadius22#),#VisualizerBandTop22# | LineTo ((#VisualizerBandLeft22#+#VisualizerBandWidth22#)-#VisualizerBandRadius22#),#VisualizerBandTop22# | CurveTo (#VisualizerBandLeft22#+#VisualizerBandWidth22#),(#VisualizerBandTop22#+#VisualizerBandRadius22#),((#VisualizerBandLeft22#+#VisualizerBandWidth22#)-0.44771525*#VisualizerBandRadius22#),#VisualizerBandTop22#,(#VisualizerBandLeft22#+#VisualizerBandWidth22#),(#VisualizerBandTop22#+0.44771525*#VisualizerBandRadius22#) | LineTo (#VisualizerBandLeft22#+#VisualizerBandWidth22#),#VisualizerBarHeight# | ClosePath 1
Shape24=Path BandPath23 | Fill Color 255,255,255,255 | StrokeWidth 0
BandPath23=#VisualizerBandLeft23#,#VisualizerBarHeight# | LineTo #VisualizerBandLeft23#,(#VisualizerBandTop23#+#VisualizerBandRadius23#) | CurveTo (#VisualizerBandLeft23#+#VisualizerBandRadius23#),#VisualizerBandTop23#,#VisualizerBandLeft23#,(#VisualizerBandTop23#+0.44771525*#VisualizerBandRadius23#),(#VisualizerBandLeft23#+0.44771525*#VisualizerBandRadius23#),#VisualizerBandTop23# | LineTo ((#VisualizerBandLeft23#+#VisualizerBandWidth23#)-#VisualizerBandRadius23#),#VisualizerBandTop23# | CurveTo (#VisualizerBandLeft23#+#VisualizerBandWidth23#),(#VisualizerBandTop23#+#VisualizerBandRadius23#),((#VisualizerBandLeft23#+#VisualizerBandWidth23#)-0.44771525*#VisualizerBandRadius23#),#VisualizerBandTop23#,(#VisualizerBandLeft23#+#VisualizerBandWidth23#),(#VisualizerBandTop23#+0.44771525*#VisualizerBandRadius23#) | LineTo (#VisualizerBandLeft23#+#VisualizerBandWidth23#),#VisualizerBarHeight# | ClosePath 1

; The full-height fill is masked by the measured paths. Its gradient does not
; stretch with individual bar heights; alpha is applied only by this fill.
[MeterVisualizerFill]
Meter=Shape
Container=MeterVisualizerSpectrumMask
X=0
Y=0
W=#VisualizerPlotInnerWidth#
H=#VisualizerPlotInnerHeight#
Shape=Rectangle 0,0,#VisualizerPlotInnerWidth#,#VisualizerBarHeight# | Fill Color #MediaColor# | StrokeWidth 0
SpectrumGradient=180 | #AccentColor# ; 0 | #AccentColor2# ; 1
Group=VisualizerSpectrum
Hidden=1
UpdateDivider=-1
