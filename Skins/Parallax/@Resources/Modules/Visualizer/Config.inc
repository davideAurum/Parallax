; Standalone Visualizer layout. Options.inc holds the derived options this
; config shares with Media's spectrum drawer; Spectrum.inc holds the per-band
; geometry. User choices are read earlier and are never persisted here.
[Variables]
; The standalone follows its own saved PanelHeight (126 / 146 / 186 presets).
VisualizerPanelHeight=#PanelHeight#
; Runtime-only provider evidence. Never written to the user's settings.
VisualizerVolumeAvailable=0
VisualizerVolumeDivider=(Max(1,Round(250/#VisualizerEffectiveInterval#)))
VisualizerPlotTop=(43+#VisualizerTopShift#)
VisualizerPlotHeight=(#VisualizerPlotHeightPx#/#Scale#)
PanelHeightPx=(Round((66+#VisualizerTopShift#)*#Scale#)+#VisualizerPlotHeightPx#)
WindowHeight=(#PanelHeightPx#+#Gap#)
; Reserve the spectrum dB scale inside the panel.
VisualizerAxisWidth=(40*#Scale#)
VisualizerPlotX=(#ContentX#+#VisualizerAxisWidth#)
VisualizerPlotWidth=(#ContentWidth#-#VisualizerAxisWidth#)
VisualizerPlotInnerWidth=(#VisualizerPlotWidth#-2)
VisualizerPlotInnerHeight=(#VisualizerPlotHeightPx#-2)
; Spectrum.inc's mask sits one physical pixel inside the plot border, and
; its capture measures run on every skin update (this config's own cadence).
VisualizerSpectrumX=(#VisualizerPlotX#+1)
VisualizerSpectrumY=(#Inset#+#VisualizerPlotTop#*#Scale#+1)
VisualizerCaptureDivider=1
