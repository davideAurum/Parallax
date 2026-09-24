; Styles contain no Meter key. Every visible or bounds meter below declares it.
[StyleRAMRowLabel]
W=(42*#Scale#)
H=(18*#Scale#)
Group=RAMLayout
DynamicVariables=1
UpdateDivider=-1

[StyleRAMRowValue]
X=(#ContentX#+#ContentWidth#)
W=(#ContentWidth#-46*#Scale#)
H=(18*#Scale#)
StringAlign=Right
FontColor=#TextColor#
NumOfDecimals=#RAMDecimals#
AutoScale=0
Group=RAMLayout
DynamicVariables=1

[MeterRAMBounds]
Meter=Image
MeterStyle=StyleBounds
; Honor larger custom heights, while old saved 170px skins still fit the UI.
H=(Max(#PanelHeightPx#,Round((242+#RAMInfoHeight#+#GraphHeight#+2*Max(0,#DataBarThickness#-6))*#Scale#))+#Gap#)
Group=RAMLayout
DynamicVariables=1

[MeterRAMPanel]
Meter=Shape
MeterStyle=StylePanel
Shape=Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(Max(#PanelHeightPx#,Round((242+#RAMInfoHeight#+#GraphHeight#+2*Max(0,#DataBarThickness#-6))*#Scale#))-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)
Group=RAMLayout
DynamicVariables=1

[MeterRAMTitle]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow
X=(#ContentX#+#TitleIconSize#+#TitleIconGap#)
W=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-64*#Scale#)
Text=#RAMTitle#
UpdateDivider=-1

; User-selected Lucide memory-stick SVG, adapted to native Shapes. Source and
; license notices are in Icons/Lucide/. Preserve its 24x24 coordinates, round
; caps/joins and 2-unit strokes while fitting the shared title icon canvas.
[MeterRAMIcon]
Meter=Shape
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Line (12*#TitleIconSize#/24),(12*#TitleIconSize#/24),(12*#TitleIconSize#/24),(10*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape2=Line (12*#TitleIconSize#/24),(18*#TitleIconSize#/24),(12*#TitleIconSize#/24),(16*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape3=Line (16*#TitleIconSize#/24),(12*#TitleIconSize#/24),(16*#TitleIconSize#/24),(10*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape4=Line (16*#TitleIconSize#/24),(18*#TitleIconSize#/24),(16*#TitleIconSize#/24),(16*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape5=Line (2*#TitleIconSize#/24),(11*#TitleIconSize#/24),(3.5*#TitleIconSize#/24),(11*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape6=Line (20*#TitleIconSize#/24),(18*#TitleIconSize#/24),(20*#TitleIconSize#/24),(16*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape7=Line (20.5*#TitleIconSize#/24),(11*#TitleIconSize#/24),(22*#TitleIconSize#/24),(11*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape8=Line (4*#TitleIconSize#/24),(18*#TitleIconSize#/24),(4*#TitleIconSize#/24),(16*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape9=Line (8*#TitleIconSize#/24),(12*#TitleIconSize#/24),(8*#TitleIconSize#/24),(10*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape10=Line (8*#TitleIconSize#/24),(18*#TitleIconSize#/24),(8*#TitleIconSize#/24),(16*#TitleIconSize#/24) | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape11=Rectangle (2*#TitleIconSize#/24),(6*#TitleIconSize#/24),(20*#TitleIconSize#/24),(10*#TitleIconSize#/24),(2*#TitleIconSize#/24) | Fill Color 0,0,0,0 | Stroke Color #RAMColor# | StrokeWidth (2*#TitleIconSize#/24) | StrokeLineJoin Round
UpdateDivider=-1

[MeterRAMOptions]
Meter=Shape
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
LeftMouseUpAction=[!ActivateConfig "Parallax\RAM\Settings" "Settings.ini"]
ToolTipText=Open the RAM Settings utility. Changes apply and save immediately.

[MeterRAMPercent]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow
FontSize=((#FontSize#+1)*#Scale#)
FontColor=#TextColor#
MeasureName=MeasureRAMUsed
X=(#ContentX#+#ContentWidth#)
W=(62*#Scale#)
StringAlign=RightCenter
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
Y=(#Inset#+(#RAMInfoHeight#+Max(54,57-#DataBarThickness#/2))*#Scale#)
Group=RAMLayout
DynamicVariables=1
W=#ContentWidth#
H=#DataBarThicknessPx#
BarOrientation=Horizontal
BarColor=#RAMColor#
SolidColor=#TrackColor#
Hidden=(1-#RAMShowBar#)
ToolTipText=Used physical RAM / OS-usable total. Used: [MeasureRAMUsed:0] bytes; total: [MeasureRAMTotal:0] bytes.

[MeterRAMPageBar]
Meter=Bar
MeasureName=MeasureRAMPageRatio
X=#ContentX#
Y=(#Inset#+(#RAMInfoHeight#+Max(86,89-#DataBarThickness#/2)+Max(0,#DataBarThickness#-6))*#Scale#)
Group=RAMLayout
DynamicVariables=1
W=#ContentWidth#
H=#DataBarThicknessPx#
BarOrientation=Horizontal
BarColor=#RAMColor#
SolidColor=#TrackColor#
; The controller shows this only when enabled and current allocation is known.
Hidden=1
ToolTipText=Paging-file space in use / current allocated capacity. Waiting for Windows paging-file enumeration.

[MeterRAMUsedLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowLabel
Y=(#Inset#+(#RAMInfoHeight#+34)*#Scale#)
Text=RAM:
ToolTipText=Used physical RAM / OS-usable total. Available: [MeasureRAMAvailable:0] bytes; used: [MeasureRAMUsed:0] bytes; total: [MeasureRAMTotal:0] bytes.

[MeterRAMUsedGiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMUsed
MeasureName2=MeasureRAMTotal
Y=(#Inset#+(#RAMInfoHeight#+34)*#Scale#)
Scale=1000000000.0
Text=%1/%2 GB
Hidden=#RAMUseMiB#

[MeterRAMUsedMiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
MeasureName=MeasureRAMUsed
MeasureName2=MeasureRAMTotal
Y=(#Inset#+(#RAMInfoHeight#+34)*#Scale#)
Scale=1000000.0
Text=%1/%2 MB
Hidden=(1-#RAMUseMiB#)

[MeterRAMPageLabel]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowLabel
Y=(#Inset#+(#RAMInfoHeight#+66+Max(0,#DataBarThickness#-6))*#Scale#)
Text=PAGE:
ToolTipText=Paging-file space in use / current allocated capacity, excluding physical RAM. Waiting for Windows paging-file enumeration.

[MeterRAMPageGiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
Y=(#Inset#+(#RAMInfoHeight#+66+Max(0,#DataBarThickness#-6))*#Scale#)
Text=Checking...
Hidden=#RAMUseMiB#

[MeterRAMPageMiB]
Meter=String
MeterStyle=StyleLabel | StyleRAMRowValue
Y=(#Inset#+(#RAMInfoHeight#+66+Max(0,#DataBarThickness#-6))*#Scale#)
Text=Checking...
Hidden=(1-#RAMUseMiB#)

[MeterRAMHistoryLabel]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+(#RAMInfoHeight#+216+2*Max(0,#DataBarThickness#-6))*#Scale#)
W=(#ContentWidth#-60*#Scale#)
H=(18*#Scale#)
Text=History
Group=RAMLayout
DynamicVariables=1
Hidden=(1-#RAMShowHistory#)
ToolTipText=Used physical RAM, newest at right. History starts over on refresh and fills one sample per update. Uncollected history is not a measurement.
UpdateDivider=-1

[MeterRAMHistoryRange]
Meter=String
MeterStyle=StyleLabel
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+(#RAMInfoHeight#+216+2*Max(0,#DataBarThickness#-6))*#Scale#)
W=(58*#Scale#)
H=(18*#Scale#)
FontSize=(#FontSize#*#Scale#)
StringAlign=Right
Text=0 - 100%
Group=RAMLayout
DynamicVariables=1
Hidden=(1-#RAMShowHistory#)
UpdateDivider=-1

[MeterRAMHistory]
Meter=Line
MeasureName=MeasureRAMUsed
X=#ContentX#
Y=(#Inset#+(#RAMInfoHeight#+236+2*Max(0,#DataBarThickness#-6))*#Scale#)
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
DynamicVariables=1
Hidden=(1-#RAMShowHistory#)
UpdateDivider=1
ToolTipText=Native physical RAM history with a fixed 0-100% range. Each horizontal pixel holds one update; width, suite scale and MetricsInterval change the nominal time span. Refresh clears history.

; Native Line starts with a zero-filled ring buffer. Cover its uncollected
; left side; do not portray those zeros as observed memory usage. Until full,
; overlap by 2 logical pixels to cover the antialiased startup transition.
[MeterRAMHistoryUncollected]
Meter=Shape
X=#ContentX#
Y=(#Inset#+(#RAMInfoHeight#+236+2*Max(0,#DataBarThickness#-6))*#Scale#)
Shape=Rectangle 0,0,(Min(#ContentWidth#,Max(0,(#ContentWidth#-[MeasureRAMHistorySamples]+2*#Scale#)*([MeasureRAMHistorySamples]<#ContentWidth#)))),(#GraphHeight#*#Scale#) | Fill Color #RAMHistoryEmptyColor#,255 | StrokeWidth 0
Hidden=(1-#RAMShowHistory#)
Group=RAMLayout
DynamicVariables=1
UpdateDivider=1
ToolTipText=This blank area has no collected samples yet. History fills from the right and restarts on refresh.

; Overlay guides after the startup cover so blank history still has a grid.
[MeterRAMHistoryFrame]
Meter=Shape
MeterStyle=StyleGraph
Y=(#Inset#+(#RAMInfoHeight#+236+2*Max(0,#DataBarThickness#-6))*#Scale#)
Shape=Rectangle 0.5,0.5,(#ContentWidth#-1),(#GraphHeight#*#Scale#-1),(2*#Scale#) | Fill Color 0,0,0,0 | Stroke Color #BorderColor# | StrokeWidth 1
Hidden=(1-#RAMShowHistory#)
Group=RAMLayout
DynamicVariables=1
