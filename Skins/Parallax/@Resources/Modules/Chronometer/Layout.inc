; Main utility only. Hidden sections contribute no height; timers keep updating.
[Variables]
; The shared centered title row ends at logical Y=26; smaller titles still reserve that box.
ChronometerTitleExtra=(Max(2,2*(#TitleFontSize#-10)))
ChronometerBodyExtra=(Max(0,2*(#FontSize#-9)))
ChronometerHeaderExtra=(Max(0,2*(#HeaderFontSize#-8)))
ChronometerRuleExtra=(Max(0,#DividerThickness#-1))
; A full date wraps at larger body sizes in the narrow single-column layout.
ChronometerDateExtra=(((#Columns#=1)&&(#ColumnWidth#<200)&&(#FontSize#>9))?(16+#ChronometerBodyExtra#):0)
ChronometerClockHeight=(52+2*#ChronometerBodyExtra#+#ChronometerRuleExtra#+#ChronometerDateExtra#)
ChronometerUptimeHeight=(24+#ChronometerBodyExtra#+#ChronometerRuleExtra#)
ChronometerEventLineHeight=(Ceil(1.8*#FontSize#*#Scale#))
ChronometerEventHeight=(8+2*#ChronometerEventLineHeight#/#Scale#+#ChronometerRuleExtra#)
ChronometerTimersHeight=(208+#ChronometerHeaderExtra#+13*#ChronometerBodyExtra#+4*#ChronometerRuleExtra#)
ChronometerClockY=(24+#ChronometerTitleExtra#)
ChronometerUptimeY=(#ChronometerClockY#+#ChronometerClockHeight#*#ChronometerShowClock#)
ChronometerEventY=(#ChronometerUptimeY#+#ChronometerUptimeHeight#*#ChronometerShowUptime#)
ChronometerTimersY=(#ChronometerEventY#+#ChronometerEventHeight#*#ChronometerShowEvent#)
; Preserve additional user padding while keeping older, shorter User files usable.
ChronometerVisibleHeight=(30+#ChronometerTitleExtra#+Max(0,#PanelHeight#-356)+#ChronometerClockHeight#*#ChronometerShowClock#+#ChronometerUptimeHeight#*#ChronometerShowUptime#+#ChronometerEventHeight#*#ChronometerShowEvent#+#ChronometerTimersHeight#*#ChronometerShowTimers#)
PanelHeightPx=(Round(#ChronometerVisibleHeight#*#Scale#))
WindowHeight=(#PanelHeightPx#+#Gap#)
