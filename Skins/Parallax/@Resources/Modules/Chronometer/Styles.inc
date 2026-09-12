; Original compact module styles; actual meters explicitly declare their types.
[ChronometerLabel]
Group=ChronometerData
W=(#ContentWidth#-72*#Scale#)
H=(Ceil((16+2*#ChronometerBodyExtra#)*#Scale#))
FontColor=#TextColor#

[ChronometerState]
Group=ChronometerData
X=(#ContentX#+#ContentWidth#)
W=(68*#Scale#)
H=((15+2*#ChronometerBodyExtra#)*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
StringAlign=Right

[ChronometerTime]
Group=ChronometerData
W=(#ContentWidth#-90*#Scale#)
H=((18+#ChronometerBodyExtra#)*#Scale#)
FontSize=((#FontSize#-0.5)*#Scale#)
FontColor=#ClockColor#

[ChronometerAction]
H=((18+#ChronometerBodyExtra#)*#Scale#)
Padding=0,0,0,0
StringAlign=CenterCenter
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#AccentColor#
SolidColor=0,0,0,1

[ChronometerToggle]
Group=ChronometerData
X=(#ContentX#+#ContentWidth#-64*#Scale#)
W=(Ceil(45*#Scale#))
ToolTipText=Start, pause, or resume this timer. Again restarts a completed timer.

[ChronometerReset]
X=(#ContentX#+#ContentWidth#-18*#Scale#)
W=(36*#Scale#)
Text=Reset
FontColor=#AccentColor2#
ToolTipText=Stop this timer and restore its configured duration.
