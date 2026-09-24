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
; narrower surface, sized from its fixed top-left by the rule below.
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
MediaCoverSize=((1-#MediaWide#)*#MediaLegacyCoverSize#+#MediaWide#*Round(#Inset#+#MediaBodyHeightPx#+#MediaSurfaceOffset#-#MediaCoverY#))
MediaCoverRadius=((6+4*#MediaWide#)*#Scale#)
; Double-width artwork keeps its top-left anchor so it lines up with the
; utilities directly above. Its size is derived, not tuned: the art overhangs
; the panel's top edge by #MediaSurfaceOffset#, and its lower edge mirrors that
; same overhang past the panel's bottom edge. Being square, that height
; also sets its width, so ContentX, MediaMetadataX, the progress bar and the
; timing text all follow from it. Nothing here depends on ContentX, so the
; vertical chain that feeds #MediaProgressY# stays acyclic.
; Title/progress follow the resized cover. Metadata retains its horizontal bounds.
; Queue has its own surface-wide bounds below both artwork and controls.
ContentX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverSize#+8*#Scale#-#Padding#))
ContentWidth=(#Inset#+#PanelWidth#-#Padding#-#ContentX#)
; Current-player identity now shares the title row, after its fixed title label.
MediaHeadingWidth=(97*#MediaWide#*#Scale#+(1-#MediaWide#)*(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-24*#Scale#))
MediaPlayerRowX=(#MediaWide#*(#ContentX#+#TitleIconSize#+#TitleIconGap#+#MediaHeadingWidth#+6*#Scale#)+(1-#MediaWide#)*(#ContentX#+54*#Scale#))
MediaPlayerRowY=(#MediaWide#*(#MediaHeaderY#+#TitleRowCenterY#-#Inset#-9*#Scale#)+(1-#MediaWide#)*(#MediaSurfaceY#+30*#Scale#))
; Keyed to MediaCoverSize, not MediaCoverBaseSize: the base is the unshrunk
; figure, so keying to it left the metadata block indented from the title row
; and progress bar. All three now share the same 8*Scale gutter off the art.
MediaMetadataX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverSize#+8*#Scale#-#Padding#)+54*(1-#MediaWide#)*#Scale#)
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
; Left boundary of the content beside the artwork; still bounds the timing
; text's width. Compact artwork sits above that row, so it uses ContentX.
MediaTransportLeft=((#MediaCoverX#+#MediaCoverSize#)*#MediaWide#+#ContentX#*(1-#MediaWide#))
MediaTimingMaxWidth=(Max(1,#ContentX#+#ContentWidth#-#MediaTransportLeft#-104*#Scale#))
; TEMPORARY exploration: 1 hides the queue footer and reclaims the height it
; reserved, so the panel ends just below the timing text. Set to 0 to restore.
MediaQueueHidden=1
; Queue drawer: a sheet sitting behind the panel, revealed through a notch cut
; out of the panel's lower border - the physical file-folder label idea, where
; the label is on the back sheet and the front is cut away over it. The tab
; contents are drawn before MeterPanel, so the panel hides all of the sheet
; except the notch. Set MediaQueueDrawer=0 to disable (Setup.ini has no queue);
; that parks the notch above the panel so the Exclude removes nothing.
MediaQueueDrawer=1
; Notch corners are rounded well beyond the panel's own radius so the cut
; reads as a soft cut-away rather than a punched rectangle. Only the top
; two corners are visible; the notch runs past the panel's lower edge.
MediaQueueTabRadius=(Max(10,#CornerRadius#*2)*#Scale#)
; The notch spans from the artwork to the transport circles, so its width is
; derived from both rather than fixed: move the buttons and it follows. Its
; right clearance is deliberately still 4 - that edge is really a question of
; where the buttons live on the x-axis, which is being decided separately.
MediaQueueTabRight=(#MediaTransportGroupX#-#MediaTransportShadowPad#-4*#Scale#)
; Sits in the only clear strip on the bottom edge: right of the artwork and
; left of the transport circles. Its left edge is #ContentX# - the same line
; the title icon, the metadata icons and the progress bar all start on - so it
; is aligned with the content column by construction rather than by a gap that
; happens to work out. That puts 8px between it and the artwork, and it follows
; automatically if the art resizes. Its top clears the progress bar by
; #MediaQueueTabGap#, and its height is whatever is left down to the panel
; edge, so that gap holds if the bar moves or thickens. The right clearance is
; deliberately neither of these; see MediaQueueTabRight.
MediaQueueTabGap=#Padding#
MediaQueueTabX=#ContentX#
MediaQueueTabWidth=(#MediaQueueTabRight#-#MediaQueueTabX#)
MediaQueueTabY=(#MediaProgressY#+#DataBarThicknessPx#+#MediaQueueTabGap#)
MediaQueueTabHeight=(#Inset#+#MediaBodyHeightPx#-#MediaQueueTabY#)
; The sheet must read as a separate surface behind the panel. GraphBackgroundColor
; is only 10 levels lighter than BackgroundColor, which is invisible through a
; small notch. If this design sticks, promote it to a theme token in Settings.inc.
MediaQueueDrawerFill=45,45,45,255
MediaQueueTabCenterY=(#MediaQueueTabY#+#MediaQueueTabHeight#/2)
; The sheet starts above the notch so no top seam shows through it, and when
; closed its lower edge is flush with the panel's.
; The sheet stops at the progress bar's right edge rather than the panel's,
; so when it slides out it reads as a distinct layer instead of a
; continuation of the panel. That is also where the queue rows end.
MediaQueueDrawerRight=(#ContentX#+#ContentWidth#)
MediaQueueDrawerTop=(#MediaQueueTabY#-8*#Scale#)
MediaQueueDrawerClosedBottom=(#Inset#+#MediaBodyHeightPx#)
; --- Queue object (the drawer's only content) --------------------------
; Its top is not the container's padding: it clears whichever of the artwork
; and the panel hangs lower. In the wide layout (Columns=2) the artwork
; overhangs the panel's lower border, so the artwork wins; in the narrow one
; it is a small thumbnail high in the body, so the panel wins. Anchoring to
; the artwork alone put the table halfway up the narrow body, across the
; progress bar, and left the sheet shorter than its own contents - at
; QueueRowLimit=1 the sheet's height went negative.
; The panel's lower border is #Inset#+#MediaBodyHeightPx#, not
; #MediaSurfaceY#+#PanelHeightPx#: MeterPanel draws its rectangle
; #MediaSurfaceOffset# shorter to absorb the surface offset it is shifted by.
; It deliberately does NOT clear the transport circles, which hang lower
; still (182 vs 172 when wide): the header's text is short and fixed, so it
; ends well left of the buttons even though its meter box spans the full
; width. The ROWS are what can run long, and they start a header plus a
; divider lower - far enough down that they clear the circles anyway. If the
; header text ever becomes long or data-driven, this has to go back to
; Max(artwork, circles).
; QueueReader.lua places each row at MediaQueueTop + n*MediaQueueRowPitch, so
; this block is the single source of the queue's geometry.
; One token for the artist accent - the rows and the header label both read
; it, so trying colours is a single edit rather than two that can drift.
MediaQueueArtistColor=#AccentColor2#
MediaQueueRowPitch=(18*#Scale#)
MediaQueueTop=(Max(#MediaCoverY#+#MediaCoverSize#,#Inset#+#MediaBodyHeightPx#)+#MediaSectionGap#)
; A header line labels the columns, then a divider, then the rows. The gap is
; split either side of the rule so it sits centred between the two.
; Both header anchors park at #Inset# while the drawer is closed, the same way
; QueueReader.lua parks the rows: the window shrinks back to the panel then,
; and a hidden meter left at its open position still counts toward the skin's
; native bounds even though it paints nothing.
MediaQueueDividerGap=(5*#Scale#)
MediaQueueHeaderOpenY=#MediaQueueTop#
MediaQueueHeaderRuleOpenY=(#MediaQueueTop#+#MediaQueueRowPitch#+#MediaQueueDividerGap#/2)
MediaQueueHeaderY=(#QueueExpanded#*#MediaQueueHeaderOpenY#+(1-#QueueExpanded#)*#Inset#)
; The rule is a stroked line, so its parked anchor sits half a stroke below
; #Inset# to keep the stroke's outer edge on the boundary rather than across it.
MediaQueueDividerY=(#QueueExpanded#*#MediaQueueHeaderRuleOpenY#+(1-#QueueExpanded#)*(#Inset#+#DividerThickness#*#Scale#/2))
MediaQueueRowsY=(#MediaQueueTop#+#MediaQueueRowPitch#+#MediaQueueDividerGap#)
; Left column carries the queue position; the track column takes the rest.
MediaQueueNumberWidth=(16*#Scale#)
MediaQueueNumberRight=(#MediaQueueX#+#MediaQueueNumberWidth#)
MediaQueueTextX=(#MediaQueueNumberRight#+6*#Scale#)
; Delimiter between the position column and the track column. Drawn as a short
; Shape segment per row rather than one continuous rule, so it reads as a
; divider without turning into a hard border running the table's full height.
; The inset is what creates the gap between consecutive segments.
MediaQueueDividerX=((#MediaQueueNumberRight#+#MediaQueueTextX#)/2)
MediaQueueDividerInset=(3*#Scale#)
MediaQueueTextWidth=(#MediaQueueX#+#MediaQueueWidth#-#MediaQueueTextX#)
; Song and artist share one flowing string per row, so the artist sits right
; after the title instead of in a column that leaves a ragged gap. The accent
; is applied by InlinePattern, which QueueReader.lua sets per row to the
; literal artist text anchored to the end - it builds the string, so it knows
; exactly which characters are the artist. That makes a "/" inside either
; field harmless, unlike a pattern that tries to find the separator.
; Do NOT reintroduce fixed columns chained with [Meter:W] section variables:
; for a String meter that reports the ALLOCATED width, not the rendered text
; width, so a short title still measures its full cap and later meters get
; pushed past the sheet. With DynamicWindowSize=1 that grows the whole skin
; and can move the window between monitors.
MediaQueueHeight=((1+#QueueRowLimit#)*#MediaQueueRowPitch#+#MediaQueueDividerGap#)
MediaQueueBottom=(#MediaQueueTop#+#MediaQueueHeight#)
MediaQueueDrawerOpenBottom=(#MediaQueueBottom#+#MediaDrawerPadding#)
MediaQueueDrawerBottom=((1-#QueueExpanded#)*#MediaQueueDrawerClosedBottom#+#QueueExpanded#*#MediaQueueDrawerOpenBottom#)
; Notch in panel-local coordinates, parked clear of the panel when disabled.
MediaQueueNotchX=(#MediaQueueTabX#-#MediaSurfaceX#)
MediaQueueNotchY=(#MediaQueueDrawer#*(#MediaQueueTabY#-#MediaSurfaceY#)-(1-#MediaQueueDrawer#)*(#MediaQueueTabHeight#+10*#Scale#))
; --- Drawer container -------------------------------------------------
; The sheet is a container. It holds one object today (the queue), so its
; inner padding is declared once here rather than being folded into that
; object's own numbers - a second object can then stack against the same edges.
MediaDrawerPadding=(8*#Scale#)
MediaDrawerContentX=(#MediaSurfaceX#+#MediaDrawerPadding#)
MediaDrawerContentWidth=(#MediaQueueDrawerRight#-#MediaSurfaceX#-2*#MediaDrawerPadding#)
MediaQueueX=#MediaDrawerContentX#
MediaQueueWidth=#MediaDrawerContentWidth#
; Bottom of the timing text: the last thing inside the panel once the queue is
; hidden, since the transport row now straddles the panel's lower border.
MediaTimingTextBottom=(#MediaProgressY#+#DataBarThicknessPx#+20*#Scale#)
; Preserve the existing queue anchor at normal widths. Only extend it when the
; enlarged art would otherwise collide with the untouched queue footer.
MediaLegacyProgressY=(#MediaSurfaceY#+50*#Scale#+3*#MediaMetadataPitch#+Max(2*#Scale#,6*#Scale#-#DataBarThicknessPx#/2))
MediaLegacyTimingY=(#MediaLegacyProgressY#+#DataBarThicknessPx#+8*#Scale#)
MediaLegacyBodyHeightPx=(Max(Round(#PanelHeight#*#Scale#)+#MediaSurfaceOffset#,Ceil(Max(#MediaCoverY#+#MediaLegacyCoverSize#,#MediaLegacyTimingY#+26*#Scale#)-#Inset#+37*#Scale#)))
; The artwork no longer contributes: it deliberately overhangs the panel's
; lower edge, so it must not drive the panel's height (and referencing it here
; would make MediaCoverSize circular, since the art is now derived from this).
MediaBodyHeightPx=((1-#MediaQueueHidden#)*Max(#MediaLegacyBodyHeightPx#,Ceil(#MediaTimingY#+26*#Scale#-#Inset#+37*#Scale#))+#MediaQueueHidden#*Ceil(#MediaTimingTextBottom#-#Inset#+#Padding#))
MediaSurfaceHeightPx=(#MediaBodyHeightPx#-#MediaSurfaceOffset#)
; PanelHeight is the user's base Media height. Expansion never overwrites it.
PanelHeightPx=(#MediaBodyHeightPx#+Round((1-#MediaQueueHidden#)*#QueueExpanded#*(8+18*#QueueRowLimit#)*#Scale#))
; Transport circles straddle the panel's lower border: centred on it, so half
; sits outside the panel. Rainmeter clips to the window, so the window has to
; clear both them and the artwork's own overhang below the panel.
MediaTransportSize=(34*#Scale#)
; Rainmeter shapes have no drop shadow, so one is faked with translucent
; ellipses stacked behind the circle. They need room inside the meter box:
; the pad is sized so the lowest, widest ring lands exactly on its edge.
MediaTransportShadowPad=(5*#Scale#)
MediaTransportBox=(#MediaTransportSize#+2*#MediaTransportShadowPad#)
; Centres the 24-unit Lucide art on the circle face. The face sits at the
; box centre, so this is measured off the box, shadow pad included. Media.lua
; rewrites this same stroke every update, so both must read this one value.
MediaTransportGlyphOffset=((#MediaTransportBox#-24*#Scale#)/2)
; Optical centring for the outer transport art. Perceived centre follows the
; centroid, not the bounding box. The glyphs are drawn as outlines but read as
; solid figures - a closed contour encloses a region the eye groups as one
; shape - and on hover Media.lua literally fills the interior, so the solid
; form is the one to centre on. Centroids of the solid figure in the 24-unit
; box (centre 12), measured by rasterising the filled path plus its stroke:
;   rewind        bbox 12.293  solid centroid 13.180  -> leans +1.180 right
;   fast-forward  bbox 11.707  solid centroid 10.820  -> leans -1.180 left
; They are mirror images, so both lean inward, crowding the play button.
; Centring by bounding box removes only 0.293 of that. For reference the
; unfilled ring sits at +-1.305, so the glyph shifts 0.125px on hover; the
; solid value is exact while hovered and well inside a pixel when not.
; Play is deliberately excluded: its bbox leans +0.504 right while its mass
; leans -1.005 left, because Lucide already shifted the triangle right to
; offset its own weight - that is what makes it look centred. Media.lua applies
; this per button, since it rewrites the same stroke option every update.
MediaTransportGlyphNudge=(1.1795*#Scale#)
MediaTransportCenterY=(#Inset#+#MediaBodyHeightPx#)
MediaTransportY=(#MediaTransportCenterY#-#MediaTransportBox#/2)
; Statically centred in the panel background remaining to the right of the
; artwork. The old LayoutTransport centring measured against the timing text,
; which is no longer the transport row.
MediaTransportGap=(4*#Scale#)
MediaTransportGroupWidth=(3*#MediaTransportSize#+2*#MediaTransportGap#)
MediaTransportGroupX=(((#MediaCoverX#+#MediaCoverSize#)+(#Inset#+#PanelWidth#))/2-#MediaTransportGroupWidth#/2)
MediaOverhangBottom=(Max(#MediaCoverY#+#MediaCoverSize#,#MediaTransportY#+#MediaTransportBox#))
WindowHeight=(Max(Max(#PanelHeightPx#+#Gap#,Ceil(#MediaOverhangBottom#+#Inset#)),Ceil(#MediaQueueDrawerBottom#+#Inset#)))
