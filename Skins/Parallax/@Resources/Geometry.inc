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
