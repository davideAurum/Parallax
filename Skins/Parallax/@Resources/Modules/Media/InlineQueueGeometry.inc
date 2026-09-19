[Variables]
; Media.ini/Setup.ini both tick at this fast, fixed rate (matching the
; Visualizer module's own default cadence) so Media.lua can animate the
; player icon smoothly; MediaLegacyDivider throttles every measure that only
; ever needs the original #MediaInterval# cadence (WebNowPlaying polling,
; queue/options refresh) back down to it, so nothing polls more often than
; before this animation existed.
MediaAnimationInterval=50
MediaLegacyDivider=(Max(1,Round(#MediaInterval#/#MediaAnimationInterval#)))
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
; The panel stacks three subsections - title row, song metadata, then the
; progress/transport block - separated by one shared gap. MediaHeaderBottom is
; where the title row ends: the centered heading's lower edge at double width
; (#TitleRowCenterY#+#TitleRowHeight#/2, i.e. 26*Scale below the surface), or
; the player-name row's lower edge where it wraps below the heading at standard
; width (#MediaPlayerRowY#+18*Scale, i.e. 48*Scale below the surface).
MediaSectionGap=(4*#Scale#)
; A text row's box carries leading below its glyphs, but the progress bar's top
; edge is solid ink, so an equal box gap reads as visibly tighter above the bar.
; Add that leading back. It is an optical constant rather than a derived one:
; Rainmeter cannot query font metrics, and the true value drifts with FontFace
; and TitleFontSize (measured ~6px for IBM Plex Sans at default typography,
; ranging ~5-8px across the min/max title sizes).
MediaBarOpticalPad=(6*#Scale#)
MediaHeaderBottom=(#MediaSurfaceY#+(48-22*#MediaWide#)*#Scale#)
MediaMetadataY=(#MediaHeaderBottom#+#MediaSectionGap#)
MediaMetadataPitch=(24*#Scale#)
MediaProgressX=#ContentX#
MediaProgressWidth=#ContentWidth#
; The album row's box reaches exactly #MediaMetadataY#+3*Pitch (its
; StringAlign=Center vertical anchor puts its true bottom there), so the same
; #MediaSectionGap# that sits under the title row also sits under the metadata
; block. It is outside MediaMetadataPitch, so title/artist/album keep their own
; spacing, and the timing text and transport row follow the bar down.
MediaProgressY=(#MediaMetadataY#+3*#MediaMetadataPitch#+#MediaSectionGap#+#MediaBarOpticalPad#)
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
