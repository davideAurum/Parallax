[Variables]
; Two columns retain the shared outer pitch while the cover overhangs the
; narrower surface. Artwork is 75% of its former size, at the same top-left.
MediaWide=(#Columns#-1)
MediaSurfaceX=(#Inset#+96*#MediaWide#*#Scale#)
MediaSurfaceWidth=(#PanelWidth#-96*#MediaWide#*#Scale#)
MediaSurfaceOffset=(Round(12*#MediaWide#*#Scale#))
MediaSurfaceY=(#Inset#+#MediaSurfaceOffset#)
MediaHeaderY=#MediaSurfaceY#
MediaCoverX=(#Inset#+#Padding#*(1-#MediaWide#))
MediaCoverY=(#Inset#+44*(1-#MediaWide#)*#Scale#)
MediaCoverBaseSize=(48*#Scale#*(1-#MediaWide#)+Round(#UnitWidth#*0.9)*#MediaWide#)
MediaCoverSize=(Round(#MediaCoverBaseSize#*0.75))
MediaCoverRadius=((6+4*#MediaWide#)*#Scale#)
; Title/progress follow the resized cover. Metadata retains its prior bounds.
; Queue has its own surface-wide bounds below both artwork and controls.
ContentX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverSize#+8*#Scale#-#Padding#))
ContentWidth=(#Inset#+#PanelWidth#-#Padding#-#ContentX#)
; Compact source text sits beside the preserved artwork; wide text follows
; the title. Both use an 18-pixel body row below the fixed title row.
MediaPlayerRowX=(#ContentX#+54*(1-#MediaWide#)*#Scale#)
MediaPlayerRowY=(#MediaSurfaceY#+30*#Scale#)
MediaMetadataX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverBaseSize#+8*#Scale#-#Padding#)+54*(1-#MediaWide#)*#Scale#)
MediaMetadataWidth=(#Inset#+#PanelWidth#-#Padding#-#MediaMetadataX#)
MediaMetadataY=(#MediaSurfaceY#+50*#Scale#)
MediaMetadataPitch=(24*#Scale#)
MediaProgressX=(#ContentX#-4*#MediaWide#*#Scale#)
MediaProgressWidth=(#ContentWidth#+4*#MediaWide#*#Scale#)
MediaProgressY=(#MediaMetadataY#+3*#MediaMetadataPitch#+Max(2*#Scale#,6*#Scale#-#DataBarThicknessPx#/2))
MediaTimingY=(#MediaProgressY#+#DataBarThicknessPx#+8*#Scale#)
; Center the 92-pixel transport group between artwork and measured time text.
; Compact artwork sits above this row, so its left boundary is ContentX.
MediaTransportLeft=((#MediaCoverX#+#MediaCoverSize#)*#MediaWide#+#ContentX#*(1-#MediaWide#))
MediaTimingMaxWidth=(Max(1,#ContentX#+#ContentWidth#-#MediaTransportLeft#-104*#Scale#))
MediaQueueX=(#MediaSurfaceX#+#Padding#)
MediaQueueWidth=(#MediaSurfaceWidth#-2*#Padding#)
; Reserve the footer below both artwork and enlarged controls. Grow only the
; rendered body; retain the saved PanelHeight as a minimum.
MediaBodyHeightPx=(Max(Round(#PanelHeight#*#Scale#)+#MediaSurfaceOffset#,Ceil(Max(#MediaCoverY#+#MediaCoverSize#,#MediaTimingY#+26*#Scale#)-#Inset#+37*#Scale#)))
MediaSurfaceHeightPx=(#MediaBodyHeightPx#-#MediaSurfaceOffset#)
; PanelHeight is the user's base Media height. Expansion never overwrites it.
PanelHeightPx=(#MediaBodyHeightPx#+Round(#QueueExpanded#*(8+18*#QueueRowLimit#)*#Scale#))
WindowHeight=(#PanelHeightPx#+#Gap#)
