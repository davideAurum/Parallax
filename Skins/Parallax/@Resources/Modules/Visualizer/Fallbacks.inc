; Upgrade fallbacks for every Visualizer preference, shared by the standalone
; Visualizer and Media's spectrum drawer. Both include this file FIRST, so the
; user's User\Visualizer.inc (and, for the standalone, Defaults.inc) override it.
[Variables]
VisualizerBandGap=1
VisualizerColorMode=0
VisualizerBarRadius=0
VisualizerBaselineGap=0
VisualizerUpdateOverride=0
VisualizerQuality=1
VisualizerDeviceID=
VisualizerAttack=50
VisualizerDecay=250
VisualizerSensitivity=35
VisualizerIdleThreshold=0.001
; Normal height preset. Only Media relies on it: Media.ini reads the Audio
; settings Height preset by including HeightPresets\#PanelHeight#.inc straight
; after User\Visualizer.inc, before Defaults.inc or Media's own PanelHeight can
; replace it. The standalone's Defaults.inc overrides this value.
PanelHeight=146
VisualizerPresetHeight=146
