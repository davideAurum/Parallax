; Fixed native meter bank, compacted by IO.lua. Hidden rows stay at Y=0.
; Each letter's eleven meters share Group=IORow<letter> and ship idle
; (UpdateDivider=-1). IO.lua sets the group to 1 while the letter is shown
; and back to -1 when it is hidden, forcing one group update each time.
; Drive names open their root on click. Hovering underlines the whole name;
; idle, InlinePattern=^\d matches nothing (names always start with a letter), so
; no underline shows. Patterns avoid brackets inside bangs.
; Eject icons brighten on hover; their hit box is the whole 20x18 meter.
[MeterIODriveA]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=A:
MouseActionCursor=1
LeftMouseUpAction=["A:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveA InlinePattern ".*"][!UpdateMeter MeterIODriveA][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveA InlinePattern "^\d"][!UpdateMeter MeterIODriveA][!Redraw]
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectA]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('A')"]
MouseOverAction=[!SetOption MeterIOEjectA IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectA][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectA IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectA][!Redraw]
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedA]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedA
Y=0
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelA]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelA]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeA]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadA]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendA]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=A:
Hidden=1
Group=IORowA|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveB]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=B:
MouseActionCursor=1
LeftMouseUpAction=["B:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveB InlinePattern ".*"][!UpdateMeter MeterIODriveB][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveB InlinePattern "^\d"][!UpdateMeter MeterIODriveB][!Redraw]
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectB]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('B')"]
MouseOverAction=[!SetOption MeterIOEjectB IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectB][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectB IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectB][!Redraw]
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedB]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedB
Y=0
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelB]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelB]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeB]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadB]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendB]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=B:
Hidden=1
Group=IORowB|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveC]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=C:
MouseActionCursor=1
LeftMouseUpAction=["C:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveC InlinePattern ".*"][!UpdateMeter MeterIODriveC][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveC InlinePattern "^\d"][!UpdateMeter MeterIODriveC][!Redraw]
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectC]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('C')"]
MouseOverAction=[!SetOption MeterIOEjectC IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectC][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectC IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectC][!Redraw]
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedC]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedC
Y=0
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelC]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelC]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeC]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadC]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendC]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=C:
Hidden=1
Group=IORowC|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveD]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=D:
MouseActionCursor=1
LeftMouseUpAction=["D:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveD InlinePattern ".*"][!UpdateMeter MeterIODriveD][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveD InlinePattern "^\d"][!UpdateMeter MeterIODriveD][!Redraw]
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectD]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('D')"]
MouseOverAction=[!SetOption MeterIOEjectD IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectD][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectD IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectD][!Redraw]
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedD]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedD
Y=0
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelD]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelD]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeD]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadD]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendD]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=D:
Hidden=1
Group=IORowD|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveE]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=E:
MouseActionCursor=1
LeftMouseUpAction=["E:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveE InlinePattern ".*"][!UpdateMeter MeterIODriveE][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveE InlinePattern "^\d"][!UpdateMeter MeterIODriveE][!Redraw]
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectE]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('E')"]
MouseOverAction=[!SetOption MeterIOEjectE IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectE][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectE IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectE][!Redraw]
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedE]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedE
Y=0
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelE]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelE]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeE]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadE]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendE]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=E:
Hidden=1
Group=IORowE|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveF]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=F:
MouseActionCursor=1
LeftMouseUpAction=["F:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveF InlinePattern ".*"][!UpdateMeter MeterIODriveF][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveF InlinePattern "^\d"][!UpdateMeter MeterIODriveF][!Redraw]
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectF]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('F')"]
MouseOverAction=[!SetOption MeterIOEjectF IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectF][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectF IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectF][!Redraw]
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedF]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedF
Y=0
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelF]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelF]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeF]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadF]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendF]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=F:
Hidden=1
Group=IORowF|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveG]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=G:
MouseActionCursor=1
LeftMouseUpAction=["G:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveG InlinePattern ".*"][!UpdateMeter MeterIODriveG][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveG InlinePattern "^\d"][!UpdateMeter MeterIODriveG][!Redraw]
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectG]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('G')"]
MouseOverAction=[!SetOption MeterIOEjectG IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectG][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectG IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectG][!Redraw]
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedG]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedG
Y=0
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelG]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelG]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeG]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadG]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendG]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=G:
Hidden=1
Group=IORowG|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveH]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=H:
MouseActionCursor=1
LeftMouseUpAction=["H:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveH InlinePattern ".*"][!UpdateMeter MeterIODriveH][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveH InlinePattern "^\d"][!UpdateMeter MeterIODriveH][!Redraw]
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectH]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('H')"]
MouseOverAction=[!SetOption MeterIOEjectH IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectH][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectH IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectH][!Redraw]
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedH]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedH
Y=0
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelH]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelH]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeH]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadH]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendH]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=H:
Hidden=1
Group=IORowH|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveI]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=I:
MouseActionCursor=1
LeftMouseUpAction=["I:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveI InlinePattern ".*"][!UpdateMeter MeterIODriveI][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveI InlinePattern "^\d"][!UpdateMeter MeterIODriveI][!Redraw]
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectI]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('I')"]
MouseOverAction=[!SetOption MeterIOEjectI IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectI][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectI IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectI][!Redraw]
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedI]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedI
Y=0
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelI]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelI]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeI]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadI]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendI]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=I:
Hidden=1
Group=IORowI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveJ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=J:
MouseActionCursor=1
LeftMouseUpAction=["J:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveJ InlinePattern ".*"][!UpdateMeter MeterIODriveJ][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveJ InlinePattern "^\d"][!UpdateMeter MeterIODriveJ][!Redraw]
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectJ]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('J')"]
MouseOverAction=[!SetOption MeterIOEjectJ IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectJ][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectJ IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectJ][!Redraw]
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedJ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedJ
Y=0
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelJ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelJ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeJ]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadJ]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendJ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=J:
Hidden=1
Group=IORowJ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveK]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=K:
MouseActionCursor=1
LeftMouseUpAction=["K:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveK InlinePattern ".*"][!UpdateMeter MeterIODriveK][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveK InlinePattern "^\d"][!UpdateMeter MeterIODriveK][!Redraw]
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectK]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('K')"]
MouseOverAction=[!SetOption MeterIOEjectK IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectK][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectK IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectK][!Redraw]
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedK]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedK
Y=0
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelK]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelK]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeK]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadK]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendK]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=K:
Hidden=1
Group=IORowK|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveL]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=L:
MouseActionCursor=1
LeftMouseUpAction=["L:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveL InlinePattern ".*"][!UpdateMeter MeterIODriveL][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveL InlinePattern "^\d"][!UpdateMeter MeterIODriveL][!Redraw]
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectL]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('L')"]
MouseOverAction=[!SetOption MeterIOEjectL IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectL][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectL IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectL][!Redraw]
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedL]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedL
Y=0
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelL]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelL]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeL]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadL]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendL]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=L:
Hidden=1
Group=IORowL|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveM]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=M:
MouseActionCursor=1
LeftMouseUpAction=["M:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveM InlinePattern ".*"][!UpdateMeter MeterIODriveM][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveM InlinePattern "^\d"][!UpdateMeter MeterIODriveM][!Redraw]
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectM]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('M')"]
MouseOverAction=[!SetOption MeterIOEjectM IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectM][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectM IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectM][!Redraw]
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedM]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedM
Y=0
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelM]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelM]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeM]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadM]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendM]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=M:
Hidden=1
Group=IORowM|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveN]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=N:
MouseActionCursor=1
LeftMouseUpAction=["N:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveN InlinePattern ".*"][!UpdateMeter MeterIODriveN][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveN InlinePattern "^\d"][!UpdateMeter MeterIODriveN][!Redraw]
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectN]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('N')"]
MouseOverAction=[!SetOption MeterIOEjectN IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectN][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectN IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectN][!Redraw]
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedN]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedN
Y=0
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelN]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelN]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeN]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadN]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendN]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=N:
Hidden=1
Group=IORowN|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveO]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=O:
MouseActionCursor=1
LeftMouseUpAction=["O:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveO InlinePattern ".*"][!UpdateMeter MeterIODriveO][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveO InlinePattern "^\d"][!UpdateMeter MeterIODriveO][!Redraw]
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectO]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('O')"]
MouseOverAction=[!SetOption MeterIOEjectO IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectO][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectO IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectO][!Redraw]
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedO]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedO
Y=0
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelO]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelO]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeO]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadO]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendO]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=O:
Hidden=1
Group=IORowO|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveP]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=P:
MouseActionCursor=1
LeftMouseUpAction=["P:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveP InlinePattern ".*"][!UpdateMeter MeterIODriveP][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveP InlinePattern "^\d"][!UpdateMeter MeterIODriveP][!Redraw]
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectP]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('P')"]
MouseOverAction=[!SetOption MeterIOEjectP IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectP][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectP IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectP][!Redraw]
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedP]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedP
Y=0
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelP]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelP]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeP]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadP]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendP]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=P:
Hidden=1
Group=IORowP|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveQ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Q:
MouseActionCursor=1
LeftMouseUpAction=["Q:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveQ InlinePattern ".*"][!UpdateMeter MeterIODriveQ][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveQ InlinePattern "^\d"][!UpdateMeter MeterIODriveQ][!Redraw]
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectQ]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('Q')"]
MouseOverAction=[!SetOption MeterIOEjectQ IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectQ][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectQ IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectQ][!Redraw]
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedQ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedQ
Y=0
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelQ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelQ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeQ]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadQ]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendQ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Q:
Hidden=1
Group=IORowQ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveR]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=R:
MouseActionCursor=1
LeftMouseUpAction=["R:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveR InlinePattern ".*"][!UpdateMeter MeterIODriveR][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveR InlinePattern "^\d"][!UpdateMeter MeterIODriveR][!Redraw]
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectR]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('R')"]
MouseOverAction=[!SetOption MeterIOEjectR IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectR][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectR IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectR][!Redraw]
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedR]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedR
Y=0
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelR]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelR]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeR]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadR]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendR]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=R:
Hidden=1
Group=IORowR|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveS]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=S:
MouseActionCursor=1
LeftMouseUpAction=["S:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveS InlinePattern ".*"][!UpdateMeter MeterIODriveS][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveS InlinePattern "^\d"][!UpdateMeter MeterIODriveS][!Redraw]
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectS]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('S')"]
MouseOverAction=[!SetOption MeterIOEjectS IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectS][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectS IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectS][!Redraw]
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedS]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedS
Y=0
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelS]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelS]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeS]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadS]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendS]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=S:
Hidden=1
Group=IORowS|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveT]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=T:
MouseActionCursor=1
LeftMouseUpAction=["T:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveT InlinePattern ".*"][!UpdateMeter MeterIODriveT][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveT InlinePattern "^\d"][!UpdateMeter MeterIODriveT][!Redraw]
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectT]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('T')"]
MouseOverAction=[!SetOption MeterIOEjectT IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectT][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectT IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectT][!Redraw]
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedT]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedT
Y=0
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelT]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelT]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeT]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadT]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendT]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=T:
Hidden=1
Group=IORowT|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveU]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=U:
MouseActionCursor=1
LeftMouseUpAction=["U:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveU InlinePattern ".*"][!UpdateMeter MeterIODriveU][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveU InlinePattern "^\d"][!UpdateMeter MeterIODriveU][!Redraw]
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectU]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('U')"]
MouseOverAction=[!SetOption MeterIOEjectU IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectU][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectU IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectU][!Redraw]
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedU]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedU
Y=0
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelU]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelU]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeU]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadU]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendU]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=U:
Hidden=1
Group=IORowU|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveV]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=V:
MouseActionCursor=1
LeftMouseUpAction=["V:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveV InlinePattern ".*"][!UpdateMeter MeterIODriveV][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveV InlinePattern "^\d"][!UpdateMeter MeterIODriveV][!Redraw]
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectV]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('V')"]
MouseOverAction=[!SetOption MeterIOEjectV IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectV][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectV IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectV][!Redraw]
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedV]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedV
Y=0
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelV]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelV]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeV]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadV]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendV]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=V:
Hidden=1
Group=IORowV|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveW]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=W:
MouseActionCursor=1
LeftMouseUpAction=["W:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveW InlinePattern ".*"][!UpdateMeter MeterIODriveW][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveW InlinePattern "^\d"][!UpdateMeter MeterIODriveW][!Redraw]
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectW]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('W')"]
MouseOverAction=[!SetOption MeterIOEjectW IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectW][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectW IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectW][!Redraw]
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedW]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedW
Y=0
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelW]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelW]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeW]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadW]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendW]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=W:
Hidden=1
Group=IORowW|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveX]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=X:
MouseActionCursor=1
LeftMouseUpAction=["X:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveX InlinePattern ".*"][!UpdateMeter MeterIODriveX][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveX InlinePattern "^\d"][!UpdateMeter MeterIODriveX][!Redraw]
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectX]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('X')"]
MouseOverAction=[!SetOption MeterIOEjectX IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectX][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectX IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectX][!Redraw]
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedX]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedX
Y=0
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelX]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelX]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeX]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadX]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendX]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=X:
Hidden=1
Group=IORowX|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveY]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Y:
MouseActionCursor=1
LeftMouseUpAction=["Y:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveY InlinePattern ".*"][!UpdateMeter MeterIODriveY][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveY InlinePattern "^\d"][!UpdateMeter MeterIODriveY][!Redraw]
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectY]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('Y')"]
MouseOverAction=[!SetOption MeterIOEjectY IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectY][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectY IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectY][!Redraw]
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedY]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedY
Y=0
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelY]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelY]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeY]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadY]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendY]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Y:
Hidden=1
Group=IORowY|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODriveZ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Z:
MouseActionCursor=1
LeftMouseUpAction=["Z:\"]
InlineSetting=Underline
InlinePattern=^\d
MouseOverAction=[!SetOption MeterIODriveZ InlinePattern ".*"][!UpdateMeter MeterIODriveZ][!Redraw]
MouseLeaveAction=[!SetOption MeterIODriveZ InlinePattern "^\d"][!UpdateMeter MeterIODriveZ][!Redraw]
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOEjectZ]
Meter=Shape
MeterStyle=StyleIOEject
X=(#ContentX#+#ContentWidth#-20*#Scale#)
Y=0
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureIO "Eject('Z')"]
MouseOverAction=[!SetOption MeterIOEjectZ IOEjectColor "Stroke Color #TextColor#"][!UpdateMeter MeterIOEjectZ][!Redraw]
MouseLeaveAction=[!SetOption MeterIOEjectZ IOEjectColor "Stroke Color #MutedColor#"][!UpdateMeter MeterIOEjectZ][!Redraw]
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOCapacityZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.58)
StringAlign=Right
Text=Unavailable
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOUsedZ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedZ
Y=0
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadLabelZ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteLabelZ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+36*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskReadZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=((#ContentWidth#-51*#Scale#)*0.42)
Text=--
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIODiskWriteZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+47*#Scale#)
Y=0
W=(#ContentWidth#-47*#Scale#)
Text=--
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOGaugeZ]
Meter=Shape
MeterStyle=StyleIOGauge
X=#ContentX#
Y=0
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLoadZ]
Meter=String
MeterStyle=StyleIODriveName
X=#ContentX#
Y=0
W=(36*#Scale#)
Text=--
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1

[MeterIOLegendZ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Z:
Hidden=1
Group=IORowZ|ParallaxIdleFreeze
UpdateDivider=-1
