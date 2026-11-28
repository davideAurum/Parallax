[Variables]
UnitWidth=(Round(#ColumnWidth#*#Scale#))
Gap=(2*Round(#Gutter#*#Scale#/2))
Inset=(#Gap#/2)
Pitch=(#UnitWidth#+#Gap#)
WindowWidth=(#Columns#*#Pitch#)
PanelWidth=(#WindowWidth#-#Gap#)
PanelHeightPx=(Round(#PanelHeight#*#Scale#))
WindowHeight=(#PanelHeightPx#+#Gap#)
Padding=(Round(#PanelPadding#*#Scale#))
ContentX=(#Inset#+#Padding#)
ContentY=(#Inset#+#Padding#)
ContentWidth=(#PanelWidth#-2*#Padding#)
; Scalar utilization, capacity and progress bars share a logical thickness.
; Native Bar meters use integer dimensions; keep the 1 px setting visible at 75%.
DataBarThicknessPx=(Max(1,Round(#DataBarThickness#*#Scale#)))
; Title icons scale with typography as well as suite scale. The shared header
; center is relative to the painted panel origin; offset surfaces may translate it.
TitleIconScale=(#Scale#*#TitleFontSize#/10)
TitleIconSize=(14*#TitleIconScale#)
TitleIconGap=(4*#Scale#)
TitleRowCenterY=(#Inset#+15*#Scale#)
TitleRowHeight=(22*#Scale#)
; First placement (docs/ARCHITECTURE.md). An entrypoint names its pair in
; DefaultWindowX/Y, which Rainmeter reads only while its settings file has no
; section for that config: a panel that was ever loaded keeps its own position.
; Panels fill columns of one Pitch from the top right of the primary work area:
; CPU | GPU, IO, Chronometer | Network, RAM | Visualizer, Media, Welcome (two
; columns) | Global Settings (two). A work area too short for GPU, IO and
; Chronometer in one column sends IO below Media. Only panels with a steady
; height stand above another one; CPU grows with the processor and stands alone.
PlaceRight=(#PWORKAREAX#+#PWORKAREAWIDTH#)
PlaceBottom=(#PWORKAREAY#+#PWORKAREAHEIGHT#)
; Window heights, gutter included, with each panel's shipped options. GPU's
; includes the 24 px line its shipped Second GPU=1 adds when Windows reports two
; GPUs, which no panel can know at first load; with one GPU that stays empty.
PlaceGPUHeight=(Round((438+#GraphHeight#+Max(0,#DataBarThickness#-6))*#Scale#)+#Gap#)
PlaceIOHeight=(Round((152+Max(0,#DataBarThicknessPx#/#Scale#-6))*#Scale#)+#Gap#)
PlaceChronometerHeight=(Round(152*#Scale#)+#Gap#)
PlaceNetworkHeight=(Round(298*#Scale#)+#DataBarThicknessPx#+#Gap#)
PlaceRAMHeight=(Round((283+#GraphHeight#+2*Max(0,#DataBarThickness#-6))*#Scale#)+#Gap#)
PlaceVisualizerHeight=(Round(66*#Scale#)+Round(80*#Scale#)+#Gap#)
PlaceMediaHeight=(Ceil(Ceil(Round(12*#Scale#)+132*#Scale#+#DataBarThicknessPx#+#Padding#)+22*#Scale#)+#Gap#)
PlaceWelcomeHeight=(Round(400*#Scale#)+#Gap#)
PlaceShort=(#PlaceGPUHeight#+#PlaceIOHeight#+#PlaceChronometerHeight#>#PWORKAREAHEIGHT#)
PlaceCPUX=(Max(#PWORKAREAX#,#PlaceRight#-#WindowWidth#))
PlaceCPUY=#PWORKAREAY#
PlaceGPUX=(Max(#PWORKAREAX#,#PlaceRight#-#Pitch#-#WindowWidth#))
PlaceGPUY=#PWORKAREAY#
PlaceIOX=(Max(#PWORKAREAX#,#PlaceRight#-(1+2*#PlaceShort#)*#Pitch#-#WindowWidth#))
PlaceIOY=(Max(#PWORKAREAY#,Min(#PWORKAREAY#+(1-#PlaceShort#)*#PlaceGPUHeight#+#PlaceShort#*(#PlaceVisualizerHeight#+#PlaceMediaHeight#),#PlaceBottom#-#PlaceIOHeight#)))
PlaceChronometerX=(Max(#PWORKAREAX#,#PlaceRight#-#Pitch#-#WindowWidth#))
PlaceChronometerY=(Max(#PWORKAREAY#,Min(#PWORKAREAY#+#PlaceGPUHeight#+(1-#PlaceShort#)*#PlaceIOHeight#,#PlaceBottom#-#PlaceChronometerHeight#)))
PlaceNetworkX=(Max(#PWORKAREAX#,#PlaceRight#-2*#Pitch#-#WindowWidth#))
PlaceNetworkY=#PWORKAREAY#
PlaceRAMX=(Max(#PWORKAREAX#,#PlaceRight#-2*#Pitch#-#WindowWidth#))
PlaceRAMY=(Max(#PWORKAREAY#,Min(#PWORKAREAY#+#PlaceNetworkHeight#,#PlaceBottom#-#PlaceRAMHeight#)))
PlaceVisualizerX=(Max(#PWORKAREAX#,#PlaceRight#-3*#Pitch#-#WindowWidth#))
PlaceVisualizerY=#PWORKAREAY#
PlaceMediaX=(Max(#PWORKAREAX#,#PlaceRight#-3*#Pitch#-#WindowWidth#))
PlaceMediaY=(Max(#PWORKAREAY#,Min(#PWORKAREAY#+#PlaceVisualizerHeight#,#PlaceBottom#-#PlaceMediaHeight#)))
PlaceWelcomeX=(Max(#PWORKAREAX#,#PlaceRight#-3*#Pitch#-#WindowWidth#))
PlaceWelcomeY=(Max(#PWORKAREAY#,Min(#PWORKAREAY#+#PlaceVisualizerHeight#+#PlaceMediaHeight#,#PlaceBottom#-#PlaceWelcomeHeight#)))
PlaceSettingsX=(Max(#PWORKAREAX#,#PlaceRight#-5*#Pitch#-#WindowWidth#))
PlaceSettingsY=#PWORKAREAY#
; Panels opened from another one (utility settings, Thread colors, the separate
; queue) step down from the top left instead: n steps each way, tallest first.
PlaceStep=(Round(30*#Scale#))
PlaceLowest=(Max(#PWORKAREAY#,#PlaceBottom#-#WindowHeight#))
; Welcome's Arrange (docs/WELCOME.md) sets this to the number it knows the panel
; by, updates the measure below and clears it again. The panel answers with its
; place and size, which no other panel can read. Otherwise the measure is idle.
ParallaxPlaceAsked=0

[MeasureParallaxPlace]
Measure=Calc
Formula=#ParallaxPlaceAsked#
IfCondition=MeasureParallaxPlace>0
IfTrueAction=[!CommandMeasure MeasureWelcome "Placed(#ParallaxPlaceAsked#,#CURRENTCONFIGX#,#CURRENTCONFIGY#,#CURRENTCONFIGWIDTH#,#CURRENTCONFIGHEIGHT#)" "Parallax\Welcome"]
DynamicVariables=1
UpdateDivider=-1
