; Persistent Visualizer choices. Save, then refresh Visualizer to apply.
; Shipped settings never contain a machine-specific endpoint ID.
[Variables]
Columns=2
PanelHeight=146
; Spectrum appearance. Height presets use PanelHeight 126 / 146 / 186.
; Gap is logical pixels (0..4); colors follow shared palette choices.
; Color: 0 Media, 1 Accent 1, 2 Accent 2, 3 horizontal, 4 vertical.
; Gradients use Accent 1 to Accent 2, left-to-right or bottom-to-top.
VisualizerBandGap=3
VisualizerColorMode=3
; Appearance inherits shared FontFace, MediaColor, GraphBackgroundColor and GridColor.

; 0 follows global VisualizerInterval (shipped 50 ms). Local choices: 33, 50, 100.
; Invalid numeric interval choices fall back to 50 ms.
VisualizerUpdateOverride=0

; 0 = economy 512-point FFT; 1 = balanced 1024; 2 = detailed 2048.
; Fixed 24 display bands at every quality and width. FFTOverlap stays 0.
VisualizerQuality=1

; Blank uses the Windows default output. Optional local WASAPI endpoint ID.
; Find IDs using AudioLevel Type=DeviceList in Rainmeter About > Skins.
; Refresh after a default-device change if the old endpoint remains selected.
VisualizerDeviceID=

; FFT temporal smoothing in milliseconds, bounded by the module.
VisualizerAttack=50
VisualizerDecay=250

; Display sensitivity in dB (10..80). Does not change system audio volume.
VisualizerSensitivity=35

; RMS threshold for the IDLE label, after RMS smoothing (0.00001..0.1).
; It is a display threshold, not proof that playback has stopped.
VisualizerIdleThreshold=0.001

; Top-corner rounding in logical pixels (0..12 whole pixels).
; Rendering also limits radius by each bar width and visible height.
VisualizerBarRadius=0
; Gap above the bottom x-axis in logical pixels (0..24 whole pixels).
; This lifts bars; a short panel grows if needed to keep the dB scale readable.
VisualizerBaselineGap=0
