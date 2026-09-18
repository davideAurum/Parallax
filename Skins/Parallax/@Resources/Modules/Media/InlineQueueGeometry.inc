[Variables]
; Two columns retain the shared outer pitch while the cover overhangs the
; narrower surface. Wide artwork grows 20 logical pixels from its fixed top-left.
MediaWide=(#Columns#-1)
MediaSurfaceX=(#Inset#+96*#MediaWide#*#Scale#)
MediaSurfaceWidth=(#PanelWidth#-96*#MediaWide#*#Scale#)
MediaSurfaceOffset=(Round(12*#MediaWide#*#Scale#))
MediaSurfaceY=(#Inset#+#MediaSurfaceOffset#)
MediaHeaderY=#MediaSurfaceY#
MediaCoverX=(#Inset#+#Padding#*(1-#MediaWide#))
MediaCoverY=(#Inset#+44*(1-#MediaWide#)*#Scale#)
MediaCoverBaseSize=(48*#Scale#*(1-#MediaWide#)+Round(#UnitWidth#*0.9)*#MediaWide#)
MediaLegacyCoverSize=(Round(#MediaCoverBaseSize#*0.75))
MediaCoverSize=(#MediaLegacyCoverSize#+Round(20*#MediaWide#*#Scale#))
MediaCoverRadius=((6+4*#MediaWide#)*#Scale#)
; Title/progress follow the resized cover. Metadata retains its horizontal bounds.
; Queue has its own surface-wide bounds below both artwork and controls.
ContentX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverSize#+8*#Scale#-#Padding#))
ContentWidth=(#Inset#+#PanelWidth#-#Padding#-#ContentX#)
; Current-player identity now shares the title row, after its fixed title label.
MediaHeadingWidth=(97*#MediaWide#*#Scale#+(1-#MediaWide#)*(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-24*#Scale#))
MediaPlayerRowX=(#MediaWide#*(#ContentX#+#TitleIconSize#+#TitleIconGap#+#MediaHeadingWidth#+6*#Scale#)+(1-#MediaWide#)*(#ContentX#+54*#Scale#))
MediaPlayerRowY=(#MediaWide#*(#MediaHeaderY#+#TitleRowCenterY#-#Inset#-9*#Scale#)+(1-#MediaWide#)*(#MediaSurfaceY#+30*#Scale#))
MediaMetadataX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverBaseSize#+8*#Scale#-#Padding#)+54*(1-#MediaWide#)*#Scale#)
MediaMetadataWidth=(#Inset#+#PanelWidth#-#Padding#-#MediaMetadataX#)
MediaMetadataY=(#MediaSurfaceY#+(50-20*#MediaWide#)*#Scale#)
MediaMetadataPitch=(24*#Scale#)
MediaProgressX=#ContentX#
MediaProgressWidth=#ContentWidth#
MediaProgressY=(#MediaMetadataY#+3*#MediaMetadataPitch#+Max(2*#Scale#,6*#Scale#-#DataBarThicknessPx#/2))
MediaTimingY=(#MediaProgressY#+#DataBarThicknessPx#+8*#Scale#)
; Center the 92-pixel transport group between artwork and measured time text.
; Compact artwork sits above this row, so its left boundary is ContentX.
MediaTransportLeft=((#MediaCoverX#+#MediaCoverSize#)*#MediaWide#+#ContentX#*(1-#MediaWide#))
MediaTimingMaxWidth=(Max(1,#ContentX#+#ContentWidth#-#MediaTransportLeft#-104*#Scale#))
MediaQueueX=(#MediaSurfaceX#+#Padding#)
MediaQueueWidth=(#MediaSurfaceWidth#-2*#Padding#)
; Preserve the existing queue anchor at normal widths. Only extend it when the
; enlarged art would otherwise collide with the untouched queue footer.
MediaLegacyProgressY=(#MediaSurfaceY#+50*#Scale#+3*#MediaMetadataPitch#+Max(2*#Scale#,6*#Scale#-#DataBarThicknessPx#/2))
MediaLegacyTimingY=(#MediaLegacyProgressY#+#DataBarThicknessPx#+8*#Scale#)
MediaLegacyBodyHeightPx=(Max(Round(#PanelHeight#*#Scale#)+#MediaSurfaceOffset#,Ceil(Max(#MediaCoverY#+#MediaLegacyCoverSize#,#MediaLegacyTimingY#+26*#Scale#)-#Inset#+37*#Scale#)))
MediaBodyHeightPx=(Max(#MediaLegacyBodyHeightPx#,Ceil(Max(#MediaCoverY#+#MediaCoverSize#,#MediaTimingY#+26*#Scale#)-#Inset#+37*#Scale#)))
MediaSurfaceHeightPx=(#MediaBodyHeightPx#-#MediaSurfaceOffset#)
; PanelHeight is the user's base Media height. Expansion never overwrites it.
PanelHeightPx=(#MediaBodyHeightPx#+Round(#QueueExpanded#*(8+18*#QueueRowLimit#)*#Scale#))
WindowHeight=(#PanelHeightPx#+#Gap#)
