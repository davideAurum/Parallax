; Derived options. User choices are read earlier and are never persisted here.
[Variables]
VisualizerEffectiveInterval=(#VisualizerUpdateOverride#=0 ? (#VisualizerInterval#=33 ? 33 : (#VisualizerInterval#=100 ? 100 : 50)) : (#VisualizerUpdateOverride#=33 ? 33 : (#VisualizerUpdateOverride#=100 ? 100 : 50)))
VisualizerFFTSize=(#VisualizerQuality#<=0 ? 512 : (#VisualizerQuality#>=2 ? 2048 : 1024))
VisualizerAttackMs=(Max(0,Min(2000,#VisualizerAttack#)))
VisualizerDecayMs=(Max(0,Min(5000,#VisualizerDecay#)))
VisualizerSensitivityDb=(Max(10,Min(80,#VisualizerSensitivity#)))
VisualizerIdleFloor=(Max(0.00001,Min(0.1,#VisualizerIdleThreshold#)))
; Runtime-only provider evidence. Never written to the user's settings.
VisualizerFormatInvalid=0
VisualizerVolumeAvailable=0
VisualizerVolumeDivider=(Max(1,Round(250/#VisualizerEffectiveInterval#)))
; Reclaim the status row and footer for the spectrum; keep thick-border clearance.
VisualizerTopShift=(Max(0,#BorderThickness#-2))
VisualizerPlotTop=(43+#VisualizerTopShift#)
VisualizerPlotHeight=(#PanelHeight#-66-#VisualizerTopShift#)
VisualizerBandGapPx=(Max(0,Round(Max(0,Min(4,#VisualizerBandGap#))*#Scale#)))
