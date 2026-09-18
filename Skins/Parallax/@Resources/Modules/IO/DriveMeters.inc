; Fixed native meter bank, compacted by IO.lua. Hidden rows stay at Y=0.
[MeterIODriveA]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=A:
Hidden=1

[MeterIOCapacityA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedA]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedA
Y=0

[MeterIODiskReadLabelA]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelA]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteA]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendA]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=A:
Hidden=1

[MeterIODriveB]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=B:
Hidden=1

[MeterIOCapacityB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedB]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedB
Y=0

[MeterIODiskReadLabelB]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelB]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteB]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendB]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=B:
Hidden=1

[MeterIODriveC]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=C:
Hidden=1

[MeterIOCapacityC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedC]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedC
Y=0

[MeterIODiskReadLabelC]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelC]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteC]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendC]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=C:
Hidden=1

[MeterIODriveD]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=D:
Hidden=1

[MeterIOCapacityD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedD]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedD
Y=0

[MeterIODiskReadLabelD]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelD]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteD]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendD]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=D:
Hidden=1

[MeterIODriveE]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=E:
Hidden=1

[MeterIOCapacityE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedE]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedE
Y=0

[MeterIODiskReadLabelE]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelE]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteE]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendE]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=E:
Hidden=1

[MeterIODriveF]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=F:
Hidden=1

[MeterIOCapacityF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedF]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedF
Y=0

[MeterIODiskReadLabelF]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelF]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteF]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendF]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=F:
Hidden=1

[MeterIODriveG]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=G:
Hidden=1

[MeterIOCapacityG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedG]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedG
Y=0

[MeterIODiskReadLabelG]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelG]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteG]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendG]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=G:
Hidden=1

[MeterIODriveH]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=H:
Hidden=1

[MeterIOCapacityH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedH]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedH
Y=0

[MeterIODiskReadLabelH]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelH]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteH]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendH]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=H:
Hidden=1

[MeterIODriveI]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=I:
Hidden=1

[MeterIOCapacityI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedI]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedI
Y=0

[MeterIODiskReadLabelI]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelI]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteI]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendI]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=I:
Hidden=1

[MeterIODriveJ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=J:
Hidden=1

[MeterIOCapacityJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedJ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedJ
Y=0

[MeterIODiskReadLabelJ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelJ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteJ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendJ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=J:
Hidden=1

[MeterIODriveK]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=K:
Hidden=1

[MeterIOCapacityK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedK]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedK
Y=0

[MeterIODiskReadLabelK]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelK]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteK]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendK]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=K:
Hidden=1

[MeterIODriveL]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=L:
Hidden=1

[MeterIOCapacityL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedL]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedL
Y=0

[MeterIODiskReadLabelL]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelL]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteL]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendL]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=L:
Hidden=1

[MeterIODriveM]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=M:
Hidden=1

[MeterIOCapacityM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedM]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedM
Y=0

[MeterIODiskReadLabelM]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelM]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteM]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendM]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=M:
Hidden=1

[MeterIODriveN]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=N:
Hidden=1

[MeterIOCapacityN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedN]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedN
Y=0

[MeterIODiskReadLabelN]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelN]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteN]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendN]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=N:
Hidden=1

[MeterIODriveO]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=O:
Hidden=1

[MeterIOCapacityO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedO]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedO
Y=0

[MeterIODiskReadLabelO]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelO]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteO]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendO]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=O:
Hidden=1

[MeterIODriveP]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=P:
Hidden=1

[MeterIOCapacityP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedP]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedP
Y=0

[MeterIODiskReadLabelP]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelP]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteP]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendP]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=P:
Hidden=1

[MeterIODriveQ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Q:
Hidden=1

[MeterIOCapacityQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedQ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedQ
Y=0

[MeterIODiskReadLabelQ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelQ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteQ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendQ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Q:
Hidden=1

[MeterIODriveR]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=R:
Hidden=1

[MeterIOCapacityR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedR]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedR
Y=0

[MeterIODiskReadLabelR]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelR]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteR]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendR]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=R:
Hidden=1

[MeterIODriveS]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=S:
Hidden=1

[MeterIOCapacityS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedS]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedS
Y=0

[MeterIODiskReadLabelS]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelS]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteS]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendS]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=S:
Hidden=1

[MeterIODriveT]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=T:
Hidden=1

[MeterIOCapacityT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedT]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedT
Y=0

[MeterIODiskReadLabelT]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelT]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteT]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendT]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=T:
Hidden=1

[MeterIODriveU]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=U:
Hidden=1

[MeterIOCapacityU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedU]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedU
Y=0

[MeterIODiskReadLabelU]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelU]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteU]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendU]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=U:
Hidden=1

[MeterIODriveV]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=V:
Hidden=1

[MeterIOCapacityV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedV]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedV
Y=0

[MeterIODiskReadLabelV]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelV]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteV]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendV]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=V:
Hidden=1

[MeterIODriveW]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=W:
Hidden=1

[MeterIOCapacityW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedW]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedW
Y=0

[MeterIODiskReadLabelW]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelW]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteW]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendW]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=W:
Hidden=1

[MeterIODriveX]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=X:
Hidden=1

[MeterIOCapacityX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedX]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedX
Y=0

[MeterIODiskReadLabelX]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelX]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteX]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendX]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=X:
Hidden=1

[MeterIODriveY]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Y:
Hidden=1

[MeterIOCapacityY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedY]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedY
Y=0

[MeterIODiskReadLabelY]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelY]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteY]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendY]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Y:
Hidden=1

[MeterIODriveZ]
Meter=String
MeterStyle=StyleIODriveName
Y=0
W=#ContentWidth#
Text=Z:
Hidden=1

[MeterIOCapacityZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+#ContentWidth#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.44)
StringAlign=Right
Text=Unavailable
Hidden=1

[MeterIOUsedZ]
Meter=Bar
MeterStyle=StyleIOBar
MeasureName=MeasureIOUsedZ
Y=0

[MeterIODiskReadLabelZ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=#ContentX#
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(6*#Scale#),(4*#Scale#),(3*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(3*#Scale#),(7*#Scale#),(6*#Scale#) | Stroke Color #DiskReadColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskWriteLabelZ]
Meter=Shape
MeterStyle=StyleIOGlyph
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+4*#Scale#)
Y=0
W=(10*#Scale#)
H=(10*#Scale#)
Shape=Line (1*#Scale#),(3*#Scale#),(4*#Scale#),(6*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Shape2=Line (4*#Scale#),(6*#Scale#),(7*#Scale#),(3*#Scale#) | Stroke Color #DiskWriteColor# | StrokeWidth (Max(1,2*#Scale#))
Hidden=1
UpdateDivider=1

[MeterIODiskReadZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+11*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIODiskWriteZ]
Meter=String
MeterStyle=StyleIODriveName
X=(#ContentX#+(#ContentWidth#-8*#Scale#)*0.28+15*#Scale#)
Y=0
W=((#ContentWidth#-8*#Scale#)*0.28-11*#Scale#)
Text=--
Hidden=1

[MeterIOLegendZ]
Meter=String
MeterStyle=StyleIOText
X=#ContentX#
Y=0
W=(26*#Scale#)
H=(18*#Scale#)
Text=Z:
Hidden=1
