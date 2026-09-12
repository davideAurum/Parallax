; Styles contain no Meter key. Every visible or bounds meter below declares it.
[StyleRAMRowLabel]
W=(#ContentWidth#*0.38)
H=(18*#Scale#)
UpdateDivider=-1

[StyleRAMRowValue]
X=(#ContentX#+#ContentWidth#)
W=(#ContentWidth#*0.60)
H=(18*#Scale#)
StringAlign=Right
FontColor=#TextColor#
NumOfDecimals=#RAMDecimals#
AutoScale=0
DynamicVariables=1

[MeterRAMBounds]
Meter=Image
MeterStyle=StyleBounds
; Honor larger custom heights, while old saved 170px skins still fit the UI.
H=(Max(#PanelHeightPx#,Round((262+#GraphHeight#)*#Scale#))+#Gap#)

[MeterRAMPanel]
Meter=Shape
MeterStyle=StylePanel
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(Max(#PanelHeightPx#,Round((262+#GraphHeight#)*#Scale#))-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)

[MeterRAMTitle]
Meter=String
MeterStyle=StyleTitle
X=(#ContentX#+17*#Scale#)
Y=(#Inset#+5*#Scale#)
W=(#ContentWidth#-81*#Scale#)
H=(22*#Scale#)
Text=#RAMTitle#
UpdateDivider=-1

; Original small DIMM outline and pins, drawn with native primitives.
[MeterRAMIcon]
Meter=Shape
X=(#ContentX#+1*#Scale#)
Y=(#Inset#+10*#Scale#)
Shape=Rectangle 0,0,(12*#Scale#),(7*#Scale#),(0.5*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #RAMColor# | StrokeWidth #Scale#
Shape2=Rectangle (2*#Scale#),(2*#Scale#),(3*#Scale#),(3*#Scale#) | Fill Color #RAMColor# | StrokeWidth 0
Shape3=Rectangle (7*#Scale#),(2*#Scale#),(3*#Scale#),(3*#Scale#) | Fill Color #RAMColor# | StrokeWidth 0
Shape4=Line (2*#Scale#),(7*#Scale#),(2*#Scale#),(10*#Scale#) | Stroke Color #RAMColor# | StrokeWidth #Scale#
Shape5=Line (6*#Scale#),(7*#Scale#),(6*#Scale#),(10*#Scale#) | Stroke Color #RAMColor# | StrokeWidth #Scale#
Shape6=Line (10*#Scale#),(7*#Scale#),(10*#Scale#),(10*#Scale#) | Stroke Color #RAMColor# | StrokeWidth #Scale#
UpdateDivider=-1

[MeterRAMOptions]
Meter=Shape
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(18*#Scale#)
H=(18*#Scale#)
; Original eight-tooth gear; hidden meters have no mouse hit target.
Shape=Path GearPath | Fill Color #AccentColor# | StrokeWidth 0
Shape2=Ellipse (9*#Scale#),(9*#Scale#),(2.5*#Scale#),(2.5*#Scale#) | Fill Color #BackgroundColor# | StrokeWidth 0
GearPath=(9.000*#Scale#),(3.300*#Scale#) | LineTo (10.444*#Scale#),(1.742*#Scale#) | LineTo (11.832*#Scale#),(2.163*#Scale#) | LineTo (12.167*#Scale#),(4.261*#Scale#) | LineTo (13.031*#Scale#),(4.969*#Scale#) | LineTo (15.153*#Scale#),(4.889*#Scale#) | LineTo (15.837*#Scale#),(6.168*#Scale#) | LineTo (14.590*#Scale#),(7.888*#Scale#) | LineTo (14.700*#Scale#),(9.000*#Scale#) | LineTo (16.258*#Scale#),(10.444*#Scale#) | LineTo (15.837*#Scale#),(11.832*#Scale#) | LineTo (13.739*#Scale#),(12.167*#Scale#) | LineTo (13.031*#Scale#),(13.031*#Scale#) | LineTo (13.111*#Scale#),(15.153*#Scale#) | LineTo (11.832*#Scale#),(15.837*#Scale#) | LineTo (10.112*#Scale#),(14.590*#Scale#) | LineTo (9.000*#Scale#),(14.700*#Scale#) | LineTo (7.556*#Scale#),(16.258*#Scale#) | LineTo (6.168*#Scale#),(15.837*#Scale#) | LineTo (5.833*#Scale#),(13.739*#Scale#) | LineTo (4.969*#Scale#),(13.031*#Scale#) | LineTo (2.847*#Scale#),(13.111*#Scale#) | LineTo (2.163*#Scale#),(11.832*#Scale#) | LineTo (3.410*#Scale#),(10.112*#Scale#) | LineTo (3.300*#Scale#),(9.000*#Scale#) | LineTo (1.742*#Scale#),(7.556*#Scale#) | LineTo (2.163*#Scale#),(6.168*#Scale#) | LineTo (4.261*#Scale#),(5.833*#Scale#) | LineTo (4.969*#Scale#),(4.969*#Scale#) | LineTo (4.889*#Scale#),(2.847*#Scale#) | LineTo (6.168*#Scale#),(2.163*#Scale#) | LineTo (7.888*#Scale#),(3.410*#Scale#) | ClosePath 1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!ActivateConfig "Parallax\RAM\Settings" "Settings.ini"]
ToolTipText=Open the RAM Settings utility. Changes apply and save immediately.

[MeterRAMSubtitle]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+151*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=PHYSICAL RAM
ToolTipText=Operating-system usable physical RAM. Commit and pagefile usage are separate metrics.
UpdateDivider=-1

[MeterRAMPercent]
Meter=String
MeterStyle=StyleTitle
FontSize=((#FontSize#+1)*#Scale#)
FontColor=#TextColor#
MeasureName=MeasureRAMUsed
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+5*#Scale#)
W=(62*#Scale#)
H=(21*#Scale#)
StringAlign=Right
Percentual=1
Hidden=0
NumOfDecimals=#RAMPercentDecimals#
AutoScale=0
Text=%1%
ToolTipText=Used physical RAM divided by the native total physical RAM range.

[MeterRAMBar]
Meter=Bar
MeasureName=MeasureRAMUsed
X=#ContentX#
Y=(#Inset#+230*#Scale#)
W=#ContentWidth#
H=(2*#Scale#)
BarOrientation=Horizontal
BarColor=#RAMColor#
SolidColor=#TrackColor#
Hidden=(1-#RAMShowBar#)

[MeterRAMUsedLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowLabel
Y=(#Inset#+171*#Scale#)
Text=Used

[MeterRAMUsedGiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMUsed
Y=(#Inset#+171*#Scale#)
Scale=1073741824.0
Text=%1 GiB
Hidden=#RAMUseMiB#
ToolTipText=Used physical RAM: [MeasureRAMUsed:0] bytes.

[MeterRAMUsedMiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMUsed
Y=(#Inset#+171*#Scale#)
Scale=1048576.0
Text=%1 MiB
Hidden=(1-#RAMUseMiB#)
ToolTipText=Used physical RAM: [MeasureRAMUsed:0] bytes.

[MeterRAMAvailableLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowLabel
Y=(#Inset#+190*#Scale#)
Text=Available
ToolTipText=Physical RAM available to allocate, including reclaimable standby memory. This is not only the Windows Free list.

[MeterRAMAvailableGiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMAvailable
Y=(#Inset#+190*#Scale#)
Scale=1073741824.0
Text=%1 GiB
Hidden=#RAMUseMiB#
ToolTipText=Available physical RAM: [MeasureRAMAvailable:0] bytes.

[MeterRAMAvailableMiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMAvailable
Y=(#Inset#+190*#Scale#)
Scale=1048576.0
Text=%1 MiB
Hidden=(1-#RAMUseMiB#)
ToolTipText=Available physical RAM: [MeasureRAMAvailable:0] bytes.

[MeterRAMTotalLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowLabel
Y=(#Inset#+209*#Scale#)
Text=Total
ToolTipText=Physical RAM available to Windows. Hardware-reserved memory can make this lower than installed RAM.

[MeterRAMTotalGiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMTotal
Y=(#Inset#+209*#Scale#)
Scale=1073741824.0
Text=%1 GiB
Hidden=#RAMUseMiB#
ToolTipText=OS-usable physical RAM total: [MeasureRAMTotal:0] bytes.

[MeterRAMTotalMiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMTotal
Y=(#Inset#+209*#Scale#)
Scale=1048576.0
Text=%1 MiB
Hidden=(1-#RAMUseMiB#)
ToolTipText=OS-usable physical RAM total: [MeasureRAMTotal:0] bytes.

[MeterRAMHistoryLabel]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+236*#Scale#)
W=(#ContentWidth#-60*#Scale#)
H=(18*#Scale#)
Text=History
Hidden=(1-#RAMShowHistory#)
ToolTipText=Used physical RAM, newest at right. History starts over on refresh and fills one sample per update. Uncollected history is not a measurement.
UpdateDivider=-1

[MeterRAMHistoryRange]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+236*#Scale#)
W=(58*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
StringAlign=Right
Text=0 - 100%
Hidden=(1-#RAMShowHistory#)
UpdateDivider=-1

[MeterRAMHistory]
Meter=Line
MeasureName=MeasureRAMUsed
X=#ContentX#
Y=(#Inset#+256*#Scale#)
W=#ContentWidth#
H=(#GraphHeight#*#Scale#)
LineCount=1
LineColor=#RAMColor#
LineWidth=#Scale#
SolidColor=#GraphBackgroundColor#
AutoScale=0
Scale=1
GraphStart=Right
GraphOrientation=Vertical
AntiAlias=1
Hidden=(1-#RAMShowHistory#)
UpdateDivider=1
ToolTipText=Native physical RAM history with a fixed 0-100% range. Each horizontal pixel holds one update; width, suite scale and MetricsInterval change the nominal time span. Refresh clears history.

; Native Line starts with a zero-filled ring buffer. Cover its uncollected
; left side; do not portray those zeros as observed memory usage. Until full,
; overlap by 2 logical pixels to cover the antialiased startup transition.
[MeterRAMHistoryUncollected]
Meter=Shape
X=#ContentX#
Y=(#Inset#+256*#Scale#)
Shape=Rectangle 0,0,(Min(#ContentWidth#,Max(0,(#ContentWidth#-[MeasureRAMHistorySamples]+2*#Scale#)*([MeasureRAMHistorySamples]<#ContentWidth#)))),(#GraphHeight#*#Scale#) | Fill Color #RAMHistoryEmptyColor#,255 | StrokeWidth 0
Hidden=(1-#RAMShowHistory#)
DynamicVariables=1
UpdateDivider=1
ToolTipText=This blank area has no collected samples yet. History fills from the right and restarts on refresh.

; Overlay guides after the startup cover so blank history still has a grid.
[MeterRAMHistoryFrame]
Meter=Shape
MeterStyle=StyleGraph
Y=(#Inset#+256*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #BorderColor# | StrokeWidth 1
Hidden=(1-#RAMShowHistory#)
