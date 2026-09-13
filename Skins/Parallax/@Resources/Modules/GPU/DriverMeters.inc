; Dedicated framebuffer occupancy and shared system RAM are memory amounts.
; Activity domains are independent busy-time percentages, never allocations.
[MeterGPUMemoryHeader]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+96*#Scale#)
H=(16*#Scale#)
Text=GPU memory

[MeterGPUVRAMUsage]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
Y=(#Inset#+114*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=VRAM: Checking...
ToolTipText=Occupied and total dedicated framebuffer from the selected GPU driver. Occupied includes memory reserved by the driver.

[MeterGPUVRAMBar]
Meter=Shape
Group=GPUDriverReadout
X=#ContentX#
Y=(#Inset#+134*#Scale#)
W=#ContentWidth#
H=#DataBarThicknessPx#
Shape=Line 0,(#DataBarThicknessPx#/2),#ContentWidth#,(#DataBarThicknessPx#/2) | StrokeWidth #DataBarThicknessPx# | Stroke Color #TrackColor# | StrokeStartCap Flat | StrokeEndCap Flat
Shape2=Line 0,(#DataBarThicknessPx#/2),0,(#DataBarThicknessPx#/2) | StrokeWidth 0 | Stroke Color #GPUColor# | StrokeStartCap Flat | StrokeEndCap Flat

[MeterGPUSharedMemory]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
Y=(#Inset#+152*#Scale#)
H=(18*#Scale#)
FontSize=((#FontSize#-1)*#Scale#)
Text=Shared RAM: --
ToolTipText=Windows-reported shared GPU residency in system RAM. This is separate from dedicated VRAM and from the maximum shared-memory allowance.

[MeterGPUUtilizationHeader]
Meter=String
MeterStyle=StyleHeader
Y=(#Inset#+178*#Scale#)
H=(16*#Scale#)
Text=GPU activity
ToolTipText=Driver activity for the selected card. Each domain is independent; these percentages are not portions of GPU memory and are not added together.

[MeterGPULoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+196*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=GPU
ToolTipText=NVIDIA GPU-domain busy time. This is a driver activity reading, distinct from Windows D3D engine counters.

[MeterGPULoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+196*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUControllerLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+214*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Memory ctrl.
ToolTipText=Framebuffer/memory-controller busy time. It does not measure how much VRAM is occupied.

[MeterGPUControllerLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+214*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUVideoLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+232*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Video
ToolTipText=Driver video-domain busy time. It does not measure memory allocated to video.

[MeterGPUVideoLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+232*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--

[MeterGPUBusLoadLabel]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+250*#Scale#)
W=(#ContentWidth#-54*#Scale#)
H=(18*#Scale#)
Text=Bus
ToolTipText=Driver bus-interface busy time. It is not memory capacity or a transfer rate in bytes per second.

[MeterGPUBusLoadValue]
Meter=String
MeterStyle=StyleLabel
Group=GPUDriverReadout
X=(#ContentX#+#ContentWidth#)
Y=(#Inset#+250*#Scale#)
W=(50*#Scale#)
H=(18*#Scale#)
StringAlign=Right
Text=--
