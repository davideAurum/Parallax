; Disk Meter settings. Select drive readouts and one shared graph mode.
[Variables]
Columns=1
PanelHeight=157
IODiskUnits=bytes
; C preserves the original layout. all follows detected drive letters.
; Custom selection: uppercase comma-separated letters in alphabetical order; none hides rows.
IODiskDrives=C,D,G
; c = C only, combined = selected sum, overlay = per-drive traces, split = read above/write below zero.
IOGraphMode=combined
; letters, volume (Windows label), model (device model), or both.
IODriveNames=volume
IODiskQuota=0
IODiskMaxMiBs=500
