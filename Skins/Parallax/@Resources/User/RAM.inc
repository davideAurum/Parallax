; Persistent RAM display choices. Edit, save, then refresh Parallax\RAM.
; Keep these values under [Variables] for Skin Packager preservation.
[Variables]
Columns=1
; A smaller saved height expands at runtime to fit hardware info and history.
PanelHeight=282
RAMTitle=RAM
; 0 = GiB (2^30 bytes), 1 = MiB (2^20 bytes). Labels follow the selection.
RAMUseMiB=0
; Display precision only; use 0, 1, or 2. Stored native values remain bytes.
RAMDecimals=1
RAMPercentDecimals=0
; 0 hides, 1 shows. Hidden areas keep the same window and snap geometry.
RAMShowBar=1
RAMShowHistory=1
; RGB only: opaque cover for not-yet-collected history, not a telemetry value.
RAMHistoryEmptyColor=25,25,25
; Shared colors, FontFace, FontSize, Scale, and MetricsInterval can be
; overridden locally here. MetricsInterval is milliseconds; refresh to apply.
