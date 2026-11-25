; VisualizerPlacement=1: the spectrum slides up above the player. Included by
; VisualizerDrawer2.inc, so only while it is open.
[Variables]
; The title-row volume is a headline value: Idle pause hides it with the
; heading, and keeps it hidden on a hover-out (Media.ini).
MediaVisualizerVolumeGroup=MediaHeaderValue
MediaIdleHeadlineVolume=|MeterVisualizerVolume
MediaIdleHoverSwap=MeterMediaOptions|MeterVisualizerVolume
