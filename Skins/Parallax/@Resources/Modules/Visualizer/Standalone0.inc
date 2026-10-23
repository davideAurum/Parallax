; Standalone Audio Visualizer, live (StandbyState.inc VisualizerStandby=0): the
; capture, the output row, the frame and the spectrum, in the order the
; entrypoint always loaded them. Section-naming [Rainmeter] actions come from
; the variant, because the standby variant has no volume readout or palette.
[Variables]
VisualizerRefreshAction=[!CommandMeasure MeasureVisualizerColor "Apply()"]
VisualizerHoverIn=[!HideMeter MeterVisualizerVolume][!ShowMeter MeterVisualizerOptions][!Redraw]
VisualizerHoverOut=[!HideMeter MeterVisualizerOptions][!ShowMeter MeterVisualizerVolume][!Redraw]
VisualizerOverlayText=Output unavailable
VisualizerOverlayColor=#WarningColor#
VisualizerDeviceNextAction=[!CommandMeasure MeasureVisualizerVolume "ToggleNext"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()" "Parallax\Media"][!Refresh]
VisualizerDevicePreviousAction=[!CommandMeasure MeasureVisualizerVolume "TogglePrevious"][!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\Visualizer.inc"][!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()" "Parallax\Media"][!Refresh]
@Include11=#@#Modules\Visualizer\Capture.inc
@Include7=#@#Modules\Visualizer\Audio.inc
@Include8=#@#Modules\Visualizer\View.inc
; Last, so the measured bars paint over the plot frame.
@Include12=#@#Modules\Visualizer\Spectrum.inc
