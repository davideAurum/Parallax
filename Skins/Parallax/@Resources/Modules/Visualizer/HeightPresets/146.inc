; Media's spectrum drawer reads the Audio settings Height preset through this
; file's NAME. Media.ini includes HeightPresets\#PanelHeight#.inc directly after
; User\Visualizer.inc: Rainmeter resolves an include path as it reads it, while
; PanelHeight still holds the Visualizer's value, but resolves variables only
; after every file, when Media's own PanelHeight has replaced it.
; Only the three Audio settings presets exist; any other hand-edited height
; makes Media log one missing-file error and keep Fallbacks.inc's 146.
[Variables]
VisualizerPresetHeight=146
