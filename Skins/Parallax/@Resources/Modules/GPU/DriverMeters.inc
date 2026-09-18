; Dedicated framebuffer occupancy and shared system RAM are memory amounts.
; Activity domains are independent busy-time percentages, never allocations.
; No section headings: the memory rows sit directly under the adapter panel,
; and each activity domain is a label/value row with a full-width bar beneath
; it (the VRAM row's own pattern: text at Y, bar at Y+20). Rows step 32 px so
; a 12 px DataBarThickness bar still ends where the next label begins; the bus
; bar ends by 284 and the temperature row below starts at 290.
[MeterGPUVRAMUsage]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
Y=(#Inset#+96*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=VRAM: Checking...
ToolTipText=Occupied and total dedicated framebuffer from the selected GPU driver. Occupied includes memory reserved by the driver.

[MeterGPUVRAMBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+116*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUSharedMemory]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
Y=(#Inset#+134*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=Shared RAM: --
ToolTipText=Windows-reported shared GPU residency in system RAM. This is separate from dedicated VRAM and from the maximum shared-memory allowance.

[MeterGPULoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+156*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=GPU
ToolTipText=NVIDIA GPU-domain busy time. This is a driver activity reading, distinct from Windows D3D engine counters. Each activity domain is independent; these percentages are not portions of GPU memory and are not added together.

[MeterGPULoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+156*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPULoadBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+176*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUControllerLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+188*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Memory ctrl.
ToolTipText=Framebuffer/memory-controller busy time. It does not measure how much VRAM is occupied.

[MeterGPUControllerLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+188*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUControllerLoadBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+208*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUVideoLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+220*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Video
ToolTipText=Driver video-domain busy time. It does not measure memory allocated to video.

[MeterGPUVideoLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+220*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUVideoLoadBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+240*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUBusLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+252*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Bus
ToolTipText=Driver bus-interface busy time. It is not memory capacity or a transfer rate in bytes per second.

[MeterGPUBusLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+252*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUBusLoadBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+272*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat
