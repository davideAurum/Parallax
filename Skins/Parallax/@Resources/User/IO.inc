; Disk Meter settings. Select drive readouts and one shared graph mode.
[Variables]
Columns=1
; Minimum panel height in logical pixels; 0 fits the selected drives. It only
; ever adds space below the graph. Replaces PanelHeight (157 until alpha.10).
IOMinPanelHeight=0
IODiskUnits=bytes
; C preserves the original layout. all follows detected drive letters.
; Custom selection: uppercase comma-separated letters in alphabetical order; none hides rows.
IODiskDrives=C
; c = C only, combined = selected sum, overlay = per-drive traces, split = read above/write below zero.
IOGraphMode=combined
; letters, volume (Windows label), model (device model), or both.
IODriveNames=volume
; Optional IODriveColorA through IODriveColorZ values (R,G,B) are saved by the color boxes beside each drive in Disk Meter settings.
; An absent letter uses its fixed default color in Overlay graph mode.
IODiskQuota=0
IODiskMaxMiBs=500
