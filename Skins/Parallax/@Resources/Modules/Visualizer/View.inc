; Original compact Audio instrument. Shared palette/font/geometry are inherited.
; Styles omit Meter=. Every actual meter declares its own type.
[StyleVisualizerBand]
Y=(#Inset#+(61+#VisualizerTopShift#)*#Scale#+1)
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

[StyleVisualizerButton]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#AccentColor#
SolidColor=0,0,0,1
AntiAlias=1
ClipString=1
H=(18*#Scale#)
Padding=0,0,0,0
StringAlign=Center
MouseActionCursor=1
UpdateDivider=-1

[MeterVisualizerBounds]
Meter=Image
MeterStyle=StyleBounds

[MeterVisualizerPanel]
Meter=Shape
MeterStyle=StylePanel

; Three original level strokes; no external icon/font asset.
[MeterVisualizerIcon]
Meter=Shape
X=#ContentX#
Y=(#Inset#+7*#Scale#)
W=(12*#Scale#)
H=(14*#Scale#)
Shape=Rectangle 0,(7*#Scale#),(2*#Scale#),(7*#Scale#),(#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape2=Rectangle (5*#Scale#),(2*#Scale#),(2*#Scale#),(12*#Scale#),(#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
Shape3=Rectangle (10*#Scale#),(5*#Scale#),(2*#Scale#),(9*#Scale#),(#Scale#) | Fill Color #MediaColor# | StrokeWidth 0
UpdateDivider=-1

[MeterVisualizerTitle]
Meter=String
MeterStyle=StyleTitle
X=(#ContentX#+16*#Scale#)
Y=(#Inset#+(2+#VisualizerTopShift#)*#Scale#)
W=(#ContentWidth#-106*#Scale#)
H=(22*#Scale#)
Text=Audio
UpdateDivider=-1

[MeterVisualizerScope]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+6*#Scale#)
W=(80*#Scale#)
StringAlign=Right
Text=Output mix
ToolTipText=Mixed output-device audio, using the first two channels. Includes apps using this endpoint. Display only; no Spotify isolation, EQ or volume processing.
UpdateDivider=-1

[MeterVisualizerDeviceName]
Meter=String
MeterStyle=StyleLabel
MeasureName=MeasureVisualizerDeviceName
Y=(#Inset#+(24+#VisualizerTopShift#)*#Scale#)
H=(18*#Scale#)
Text=%1
ToolTipText=[MeasureVisualizerDeviceName] | [MeasureVisualizerFormat]
DynamicVariables=1
UpdateDivider=(Max(1,Round(1000/#VisualizerEffectiveInterval#)))

[MeterVisualizerStatus]
Meter=String
MeterStyle=StyleVisualizerSmall
X=#ContentX#
Y=(#Inset#+(42+#VisualizerTopShift#)*#Scale#)
W=#ContentWidth#
Text=OUTPUT UNAVAILABLE
FontColor=#WarningColor#
ToolTipText=LIVE means RMS exceeds the display threshold. IDLE means the available endpoint is below it; mute, silence and very quiet playback are indistinguishable.
UpdateDivider=-1

; One physical pixel border stays inside the chart. Empty/idle charts show no bars.
[MeterVisualizerPlot]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(61+#VisualizerTopShift#)*#Scale#)
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
Y=(#Inset#+(73+#VisualizerTopShift#/2)*#Scale#)
W=(#ContentWidth#-8*#Scale#)
StringAlign=Center
Text=Output unavailable
FontColor=#WarningColor#
SolidColor=#GraphBackgroundColor#
ToolTipText=AudioLevel reports unavailable capture or an unsupported format. Check Windows output settings and Rainmeter About > Log, then use Retry.

[MeterVisualizerLow]
Meter=String
MeterStyle=StyleVisualizerSmall
X=#ContentX#
Y=(#Inset#+104*#Scale#)
W=(50*#Scale#)
Text=40 Hz
UpdateDivider=-1

[MeterVisualizerHigh]
Meter=String
MeterStyle=StyleVisualizerSmall
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+104*#Scale#)
W=(50*#Scale#)
StringAlign=Right
Text=16 kHz
UpdateDivider=-1

[MeterVisualizerStop]
Meter=String
MeterStyle=StyleVisualizerButton
X=(#ContentX#+21*#Scale#)
Y=(#Inset#+123*#Scale#)
W=(42*#Scale#)
Text=Stop
LeftMouseUpAction=[!DeactivateConfig]
ToolTipText=Stop capture and unload Visualizer. Reload Visualizer.ini from Rainmeter Manage to resume.

[MeterVisualizerRetry]
Meter=String
MeterStyle=StyleVisualizerButton|StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-21*#Scale#)
Y=(#Inset#+123*#Scale#)
W=(42*#Scale#)
Text=Retry
LeftMouseUpAction=[!Refresh]
ToolTipText=Refresh this Visualizer and reconnect its selected output device. Also applies saved Visualizer options.

[MeterVisualizerBand0]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand0
X=(#ContentX#+1+Round(0*(#ContentWidth#-2)/24))
W=(Max(1,Round(1*(#ContentWidth#-2)/24)-Round(0*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand1]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand1
X=(#ContentX#+1+Round(1*(#ContentWidth#-2)/24))
W=(Max(1,Round(2*(#ContentWidth#-2)/24)-Round(1*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand2]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand2
X=(#ContentX#+1+Round(2*(#ContentWidth#-2)/24))
W=(Max(1,Round(3*(#ContentWidth#-2)/24)-Round(2*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand3]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand3
X=(#ContentX#+1+Round(3*(#ContentWidth#-2)/24))
W=(Max(1,Round(4*(#ContentWidth#-2)/24)-Round(3*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand4]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand4
X=(#ContentX#+1+Round(4*(#ContentWidth#-2)/24))
W=(Max(1,Round(5*(#ContentWidth#-2)/24)-Round(4*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand5]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand5
X=(#ContentX#+1+Round(5*(#ContentWidth#-2)/24))
W=(Max(1,Round(6*(#ContentWidth#-2)/24)-Round(5*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand6]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand6
X=(#ContentX#+1+Round(6*(#ContentWidth#-2)/24))
W=(Max(1,Round(7*(#ContentWidth#-2)/24)-Round(6*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand7]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand7
X=(#ContentX#+1+Round(7*(#ContentWidth#-2)/24))
W=(Max(1,Round(8*(#ContentWidth#-2)/24)-Round(7*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand8]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand8
X=(#ContentX#+1+Round(8*(#ContentWidth#-2)/24))
W=(Max(1,Round(9*(#ContentWidth#-2)/24)-Round(8*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand9]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand9
X=(#ContentX#+1+Round(9*(#ContentWidth#-2)/24))
W=(Max(1,Round(10*(#ContentWidth#-2)/24)-Round(9*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand10]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand10
X=(#ContentX#+1+Round(10*(#ContentWidth#-2)/24))
W=(Max(1,Round(11*(#ContentWidth#-2)/24)-Round(10*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand11]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand11
X=(#ContentX#+1+Round(11*(#ContentWidth#-2)/24))
W=(Max(1,Round(12*(#ContentWidth#-2)/24)-Round(11*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand12]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand12
X=(#ContentX#+1+Round(12*(#ContentWidth#-2)/24))
W=(Max(1,Round(13*(#ContentWidth#-2)/24)-Round(12*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand13]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand13
X=(#ContentX#+1+Round(13*(#ContentWidth#-2)/24))
W=(Max(1,Round(14*(#ContentWidth#-2)/24)-Round(13*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand14]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand14
X=(#ContentX#+1+Round(14*(#ContentWidth#-2)/24))
W=(Max(1,Round(15*(#ContentWidth#-2)/24)-Round(14*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand15]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand15
X=(#ContentX#+1+Round(15*(#ContentWidth#-2)/24))
W=(Max(1,Round(16*(#ContentWidth#-2)/24)-Round(15*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand16]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand16
X=(#ContentX#+1+Round(16*(#ContentWidth#-2)/24))
W=(Max(1,Round(17*(#ContentWidth#-2)/24)-Round(16*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand17]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand17
X=(#ContentX#+1+Round(17*(#ContentWidth#-2)/24))
W=(Max(1,Round(18*(#ContentWidth#-2)/24)-Round(17*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand18]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand18
X=(#ContentX#+1+Round(18*(#ContentWidth#-2)/24))
W=(Max(1,Round(19*(#ContentWidth#-2)/24)-Round(18*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand19]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand19
X=(#ContentX#+1+Round(19*(#ContentWidth#-2)/24))
W=(Max(1,Round(20*(#ContentWidth#-2)/24)-Round(19*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand20]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand20
X=(#ContentX#+1+Round(20*(#ContentWidth#-2)/24))
W=(Max(1,Round(21*(#ContentWidth#-2)/24)-Round(20*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand21]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand21
X=(#ContentX#+1+Round(21*(#ContentWidth#-2)/24))
W=(Max(1,Round(22*(#ContentWidth#-2)/24)-Round(21*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand22]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand22
X=(#ContentX#+1+Round(22*(#ContentWidth#-2)/24))
W=(Max(1,Round(23*(#ContentWidth#-2)/24)-Round(22*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))

[MeterVisualizerBand23]
Meter=Bar
MeterStyle=StyleVisualizerBand
MeasureName=MeasureVisualizerBand23
X=(#ContentX#+1+Round(23*(#ContentWidth#-2)/24))
W=(Max(1,Round(24*(#ContentWidth#-2)/24)-Round(23*(#ContentWidth#-2)/24)-Max(1,Round(#Scale#))))
