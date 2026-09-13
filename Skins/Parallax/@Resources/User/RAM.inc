; Persistent RAM display choices. Edit, save, then refresh Parallax\RAM.
; Keep these values under [Variables] for Skin Packager preservation.
[Variables]
Columns=1
; A smaller saved height expands to fit module info, history and top processes.
PanelHeight=282
RAMTitle=Memory Meter
; Legacy key retained: 0 = GB (10^9 bytes), 1 = MB (10^6 bytes), both decimal.
; Applies to module sizes, processes, RAM and PAGE readouts. Keep 0/1 choice.
RAMUseMiB=0
; Display precision only; use 0, 1, or 2. Stored native values remain bytes.
RAMDecimals=1
RAMPercentDecimals=0
; 0 hides, 1 shows. Hidden areas keep the same window and snap geometry.
RAMShowBar=1
RAMShowPageBar=1
RAMShowHistory=1
; RGB only: opaque cover for not-yet-collected history, not a telemetry value.
RAMHistoryEmptyColor=25,25,25
; Shared colors, FontFace, FontSize, Scale, and MetricsInterval can be
; overridden locally here. MetricsInterval is milliseconds; refresh to apply.
