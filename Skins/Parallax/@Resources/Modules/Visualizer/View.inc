; Original compact Audio instrument. Shared palette/font/geometry are inherited.
; Styles omit Meter=. Every actual meter declares its own type.
[StyleVisualizerBand]
Y=(#Inset#+#VisualizerPlotTop#*#Scale#+1)
H=(#VisualizerPlotHeight#*#Scale#-2)
BarColor=#MediaColor#
SolidColor=0,0,0,0
BarOrientation=Vertical
Group=VisualizerSpectrum
Hidden=1

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
ToolTipText=Windows default output volume: [MeasureVisualizerVolume]. This may differ from a manually selected spectrum device.
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
ToolTipText=Open Audio settings for panel width, spectrum quality and update rate.
LeftMouseUpAction=[!ActivateConfig "Parallax\Visualizer\Settings" "Settings.ini"]

[MeterVisualizerDeviceName]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDeviceName
Y=(#Inset#+(24+#VisualizerTopShift#)*#Scale#)
H=(18*#Scale#)
Text=%1
ToolTipText=[MeasureVisualizerDeviceName] | [MeasureVisualizerFormat] | Audio playing through this output device; first two channels. Display only, with no volume processing.
DynamicVariables=1
UpdateDivider=(Max(1,Round(1000/#VisualizerEffectiveInterval#)))

; One physical pixel border stays inside the chart. Empty/idle charts show no bars.
[MeterVisualizerPlot]
Meter=Shape
X=#ContentX#
Y=(#Inset#+#VisualizerPlotTop#*#Scale#)
W=#ContentWidth#
H=(#VisualizerPlotHeight#*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#VisualizerPlotHeight#*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1
Shape2=Line 1,(#VisualizerPlotHeight#*#Scale#/4),(#ContentWidth#-1),(#VisualizerPlotHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
Shape3=Line 1,(#VisualizerPlotHeight#*#Scale#/2),(#ContentWidth#-1),(#VisualizerPlotHeight#*#Scale#/2) | Stroke Color #GridColor# | StrokeWidth 1
Shape4=Line 1,(3*#VisualizerPlotHeight#*#Scale#/4),(#ContentWidth#-1),(3*#VisualizerPlotHeight#*#Scale#/4) | Stroke Color #GridColor# | StrokeWidth 1
UpdateDivider=-1

[MeterVisualizerUnavailable]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#ContentX#+#ContentWidth#/2)
Y=(#Inset#+(#VisualizerPlotTop#+#VisualizerPlotHeight#/2)*#Scale#)
W=(#ContentWidth#-8*#Scale#)
StringAlign=CenterCenter
Text=Output unavailable
FontColor=#WarningColor#
SolidColor=#GraphBackgroundColor#
ToolTipText=Quiet means the available endpoint is below the display threshold; mute, silence and quiet playback are indistinguishable. For capture problems, check Windows output settings and Rainmeter About > Log, then choose Reconnect output device from this skin's context menu.

[MeterVisualizerLow]
Meter=String
MeterStyle=StyleVisualizerSmall
X=#ContentX#
Y=(#Inset#+(#PanelHeight#-22)*#Scale#)
W=(50*#Scale#)
Text=40 Hz
UpdateDivider=-1

[MeterVisualizerHigh]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(#PanelHeight#-22)*#Scale#)
W=(50*#Scale#)
StringAlign=Right
Text=16 kHz
UpdateDivider=-1

[MeterVisualizerBand0]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand0
X=(#ContentX#+1+Round(0*(#ContentWidth#-2)/24))
W=(Max(1,Round(1*(#ContentWidth#-2)/24)-Round(0*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand1]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand1
X=(#ContentX#+1+Round(1*(#ContentWidth#-2)/24))
W=(Max(1,Round(2*(#ContentWidth#-2)/24)-Round(1*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand2]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand2
X=(#ContentX#+1+Round(2*(#ContentWidth#-2)/24))
W=(Max(1,Round(3*(#ContentWidth#-2)/24)-Round(2*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand3]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand3
X=(#ContentX#+1+Round(3*(#ContentWidth#-2)/24))
W=(Max(1,Round(4*(#ContentWidth#-2)/24)-Round(3*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand4]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand4
X=(#ContentX#+1+Round(4*(#ContentWidth#-2)/24))
W=(Max(1,Round(5*(#ContentWidth#-2)/24)-Round(4*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand5]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand5
X=(#ContentX#+1+Round(5*(#ContentWidth#-2)/24))
W=(Max(1,Round(6*(#ContentWidth#-2)/24)-Round(5*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand6]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand6
X=(#ContentX#+1+Round(6*(#ContentWidth#-2)/24))
W=(Max(1,Round(7*(#ContentWidth#-2)/24)-Round(6*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand7]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand7
X=(#ContentX#+1+Round(7*(#ContentWidth#-2)/24))
W=(Max(1,Round(8*(#ContentWidth#-2)/24)-Round(7*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand8]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand8
X=(#ContentX#+1+Round(8*(#ContentWidth#-2)/24))
W=(Max(1,Round(9*(#ContentWidth#-2)/24)-Round(8*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand9]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand9
X=(#ContentX#+1+Round(9*(#ContentWidth#-2)/24))
W=(Max(1,Round(10*(#ContentWidth#-2)/24)-Round(9*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand10]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand10
X=(#ContentX#+1+Round(10*(#ContentWidth#-2)/24))
W=(Max(1,Round(11*(#ContentWidth#-2)/24)-Round(10*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand11]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand11
X=(#ContentX#+1+Round(11*(#ContentWidth#-2)/24))
W=(Max(1,Round(12*(#ContentWidth#-2)/24)-Round(11*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand12]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand12
X=(#ContentX#+1+Round(12*(#ContentWidth#-2)/24))
W=(Max(1,Round(13*(#ContentWidth#-2)/24)-Round(12*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand13]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand13
X=(#ContentX#+1+Round(13*(#ContentWidth#-2)/24))
W=(Max(1,Round(14*(#ContentWidth#-2)/24)-Round(13*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand14]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand14
X=(#ContentX#+1+Round(14*(#ContentWidth#-2)/24))
W=(Max(1,Round(15*(#ContentWidth#-2)/24)-Round(14*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand15]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand15
X=(#ContentX#+1+Round(15*(#ContentWidth#-2)/24))
W=(Max(1,Round(16*(#ContentWidth#-2)/24)-Round(15*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand16]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand16
X=(#ContentX#+1+Round(16*(#ContentWidth#-2)/24))
W=(Max(1,Round(17*(#ContentWidth#-2)/24)-Round(16*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand17]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand17
X=(#ContentX#+1+Round(17*(#ContentWidth#-2)/24))
W=(Max(1,Round(18*(#ContentWidth#-2)/24)-Round(17*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand18]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand18
X=(#ContentX#+1+Round(18*(#ContentWidth#-2)/24))
W=(Max(1,Round(19*(#ContentWidth#-2)/24)-Round(18*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand19]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand19
X=(#ContentX#+1+Round(19*(#ContentWidth#-2)/24))
W=(Max(1,Round(20*(#ContentWidth#-2)/24)-Round(19*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand20]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand20
X=(#ContentX#+1+Round(20*(#ContentWidth#-2)/24))
W=(Max(1,Round(21*(#ContentWidth#-2)/24)-Round(20*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand21]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand21
X=(#ContentX#+1+Round(21*(#ContentWidth#-2)/24))
W=(Max(1,Round(22*(#ContentWidth#-2)/24)-Round(21*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand22]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand22
X=(#ContentX#+1+Round(22*(#ContentWidth#-2)/24))
W=(Max(1,Round(23*(#ContentWidth#-2)/24)-Round(22*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))

[MeterVisualizerBand23]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand23
X=(#ContentX#+1+Round(23*(#ContentWidth#-2)/24))
W=(Max(1,Round(24*(#ContentWidth#-2)/24)-Round(23*(#ContentWidth#-2)/24)-#VisualizerBandGapPx#))
