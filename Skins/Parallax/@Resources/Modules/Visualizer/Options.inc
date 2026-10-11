; Derived capture and spectrum options shared by the standalone Visualizer and
; Media's spectrum drawer. User choices are read earlier and are never
; persisted here. The host names the Height preset it follows as
; VisualizerPanelHeight (the standalone's own PanelHeight; Media's captured
; Audio settings preset).
[Variables]
VisualizerEffectiveInterval=(#VisualizerUpdateOverride#=0 ? (#VisualizerInterval#=33 ? 33 : (#VisualizerInterval#=100 ? 100 : 50)) : (#VisualizerUpdateOverride#=33 ? 33 : (#VisualizerUpdateOverride#=100 ? 100 : 50)))
VisualizerFFTSize=(#VisualizerQuality#<=0 ? 512 : (#VisualizerQuality#>=2 ? 2048 : 1024))
VisualizerAttackMs=(Max(0,Min(2000,#VisualizerAttack#)))
VisualizerDecayMs=(Max(0,Min(5000,#VisualizerDecay#)))
VisualizerSensitivityDb=(Max(10,Min(80,#VisualizerSensitivity#)))
VisualizerIdleFloor=(Max(0.00001,Min(0.1,#VisualizerIdleThreshold#)))
; Runtime-only provider evidence. Never written to the user's settings.
VisualizerFormatInvalid=0
; Reclaim the status row and footer for the spectrum; keep thick-border clearance.
VisualizerTopShift=(Max(0,#BorderThickness#-2))
; Keep all three dB labels readable when a short panel uses a large axis gap.
; Only derived height grows; the user's saved PanelHeight is untouched.
VisualizerBaselineGapPx=(Round(Max(0,Min(24,#VisualizerBaselineGap#))*#Scale#))
VisualizerPlotHeightPx=(Max(Round((#VisualizerPanelHeight#-66-#VisualizerTopShift#)*#Scale#),Ceil(54*#Scale#)+#VisualizerBaselineGapPx#+2))
VisualizerBandGapPx=(Max(0,Round(Max(0,Min(4,#VisualizerBandGap#))*#Scale#)))
VisualizerBarRadiusPx=(Max(0,Min(12,#VisualizerBarRadius#))*#Scale#)
