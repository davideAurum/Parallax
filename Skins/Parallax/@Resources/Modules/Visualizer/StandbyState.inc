; Runtime state of the standalone Audio Visualizer for the Global Settings Idle
; pause. Not a preference: only Companion.lua's IdleStandby writes this file,
; and a release install replaces it with this zero. Visualizer.ini reads it
; to choose Standalone<n>.inc and its update interval; it defines the same
; default itself, so a missing file means live capture.
[Variables]
; 0 live capture, 1 stood down (no AudioLevel or Win7Audio, 1 s tick).
VisualizerStandby=0
