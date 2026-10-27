[Variables]
; The fast animation tick (matching the Visualizer module's own default
; cadence) for the title-icon pulse and the open spectrum drawer.
MediaAnimationInterval=50
; Title icon animation (User\Media.inc MediaTitleAnimation: 20, 10 or 0 for a
; static icon; any other number means 20) as skin ticks per animation frame.
MediaTitleFrameTicks=(#MediaTitleAnimation#=0 ? 0 : (#MediaTitleAnimation#=10 ? 2 : 1))
; Media's own tick (Media.ini/Setup.ini Update): the fast tick only where
; something can move, Media.ini's animated title icon (MediaPlayerHost, set by
; the entrypoint before its includes) or its open spectrum drawer while it
; captures (MediaDrawerCapture=0, Modules\Media\CaptureState.inc; a paused or
; deferred drawer draws nothing that moves), and otherwise the provider
; cadence itself. Chosen here, BEFORE MediaLegacyDivider
; derives from it, from values the entrypoint and User\Media.inc settle before
; this file (docs/PERFORMANCE-REVIEW.md XMOD-03: a later override of the tick
; would be the wrong place to choose it). While Media is stood down for the
; idle pause (MediaStandby=1, CaptureState.inc) the title icon does not
; animate either, so the standby load ticks at the provider cadence.
MediaTickInterval=((#MediaPlayerHost#*(#MediaTitleFrameTicks#>0)*(1-#MediaStandby#)+#MediaVisualizerHost#*(#VisualizerDrawer#=2)*(#MediaDrawerCapture#=0))>0 ? #MediaAnimationInterval# : #MediaInterval#)
; MediaLegacyDivider holds every measure that only ever needs the original
; #MediaInterval# cadence (WebNowPlaying polling, queue/options refresh) to it
; on the faster tick, so nothing polls more often than before the animation
; existed. Media.ini's DefaultUpdateDivider holds every meter without its own
; divider to it too, so the window repaints on change, not on every tick.
MediaLegacyDivider=(Max(1,Round(#MediaInterval#/#MediaTickInterval#)))
; MediaPulse.lua's cadence: one animation frame, or with animation off the
; provider cadence of the play state it watches.
MediaPulseDivider=(#MediaTitleFrameTicks#>0 ? #MediaTitleFrameTicks# : #MediaLegacyDivider#)
; Two columns retain the shared outer pitch while the cover overhangs the
; narrower surface, sized from its fixed top-left by the rule below.
MediaWide=(#Columns#-1)
; --- Spectrum drawer (top) ---------------------------------------------
; A second sheet behind the panel that rises ABOVE it, the way the queue sheet
; drops below it. Its folder tab is the gear's own 18px column carried up into
; the strip the double-width artwork already leaves above the panel (the art
; overhangs the panel's top by #MediaSurfaceOffset#), so neither the title nor
; the gear moves. User\Media.inc VisualizerDrawer: 0 hidden, 1 collapsed (tab
; only), 2 expanded. The value also names the include that carries the
; AudioLevel capture (Media.ini, VisualizerDrawer<n>.inc), so the OPEN state is
; set by that include itself: MediaVisualizerOpen stays 0 here and
; VisualizerDrawer2.inc raises it. Any other text - even '02' or '2 ' - finds no
; include, logs Rainmeter's missing-file error and stays closed, so the window
; never lifts an empty sheet. MediaVisualizerHost comes from the
; entrypoint, BEFORE this file: 1 in Media.ini; 0 in Setup.ini, which gets no
; tab, no capture and no lift but the same panel position. Do not override it
; after the includes instead: Rainmeter's final variable pass resolves
; forward references (e.g. MediaCoverSize -> MediaBodyHeightPx) with values
; from its last include pass, so a late override leaks the old value.
MediaVisualizerShown=(#VisualizerDrawer#=1 ? 1 : (#VisualizerDrawer#=2 ? 1 : 0))
MediaVisualizerTab=(#MediaVisualizerHost#*#MediaVisualizerShown#)
MediaVisualizerOpen=0
; The drawer's plot is the standalone Visualizer's own plot height for the
; Audio settings Height preset (Options.inc), captured by Media.ini through
; Modules\Visualizer\HeightPresets\.
VisualizerPanelHeight=#VisualizerPresetHeight#
MediaVisualizerPlotHeight=#VisualizerPlotHeightPx#
; Axes, as the standalone Visualizer draws them (View.inc): a dB scale in a
; 40S gutter left of the plot. The 40 Hz / 16 kHz labels have no row of their
; own: they sit in the strip between the plot and the panel's top border
; (#MediaSurfaceOffset#, the strip the double-width art overhangs).
MediaVisualizerAxisWidth=(40*#Scale#)
; Output row above the plot, as in the standalone: speaker icon, device name
; and the Windows output volume in an 18S box, then 1S to the plot frame.
MediaVisualizerDeviceRow=(19*#Scale#)
; Buffer between the double-width art's top-right corner and the plot's origin,
; both across and up (user request, 2026-10-25).
MediaVisualizerOriginGap=(5*#Scale#)
; How far the open window grows upward: the output row, the plot and the
; origin buffer under it, plus the queue sheet's inset (#MediaDrawerPadding#
; unless a large corner radius needs more; see MediaVisualizerPlotInset) at the
; far edge. The plot's bottom edge is the buffer above #MediaTop#, the
; artwork's top. Whole pixels, because this value is also
; the config's AnchorY while the drawer is open (MediaOptions.lua): Rainmeter
; keeps the anchor point at the saved WindowY, so the panel holds its screen
; position while the window grows above it.
MediaVisualizerOpenLift=(Ceil(#MediaVisualizerPlotInset#+#MediaVisualizerDeviceRow#+#MediaVisualizerPlotHeight#+#MediaVisualizerOriginGap#))
MediaVisualizerLift=(#MediaVisualizerOpen#*#MediaVisualizerOpenLift#)
; Vertical origin of the whole player: the window's top inset plus the lift.
; Every player position below is measured from it. Parked queue meters stay at
; #Inset#, which is inside the window in every state.
MediaTop=(#Inset#+#MediaVisualizerLift#)
MediaSurfaceX=(#Inset#+96*#MediaWide#*#Scale#)
MediaSurfaceWidth=(#PanelWidth#-96*#MediaWide#*#Scale#)
; The compact layout reserves the same 12px strip while the tab can show. It
; follows the preference rather than the entrypoint, so Media.ini and Setup.ini
; keep one panel position; VisualizerDrawer=0 restores the flush compact panel.
MediaSurfaceOffset=(Round(12*Max(#MediaWide#,#MediaVisualizerShown#)*#Scale#))
MediaSurfaceY=(#MediaTop#+#MediaSurfaceOffset#)
MediaHeaderY=#MediaSurfaceY#
MediaCoverX=(#Inset#+#Padding#*(1-#MediaWide#))
; Compact art tops the metadata block it sits beside (#MediaMetadataY#), which
; also keeps it clear of the title icon directly above it at #ContentX#.
MediaCoverY=(#MediaTop#+(1-#MediaWide#)*(#MediaMetadataY#-#MediaTop#))
MediaCoverBaseSize=(48*#Scale#*(1-#MediaWide#)+Round(#UnitWidth#*0.9)*#MediaWide#)
MediaLegacyCoverSize=(Round(#MediaCoverBaseSize#*0.75))
MediaCoverSize=((1-#MediaWide#)*#MediaLegacyCoverSize#+#MediaWide#*Round(#MediaTop#+#MediaBodyHeightPx#+#MediaSurfaceOffset#-#MediaCoverY#))
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
; The title carries the current player ("Media Player: <name>"), so it is one
; row at both widths: from after the title icon to 24px before the content's
; right edge, which is the 18px gear plus a 6px gap. With the spectrum drawer
; open the gear's spot shows the output volume while not hovered (up to
; "Muted" or "100%", about 34px at the default body font), so 40px is kept.
MediaHeadingWidth=(#ContentWidth#-#TitleIconSize#-#TitleIconGap#-(24+16*#MediaVisualizerOpen#)*#Scale#)
; Keyed to MediaCoverSize, not MediaCoverBaseSize: the base is the unshrunk
; figure, so keying to it left the metadata block indented from the title row
; and progress bar. All three now share the same 8*Scale gutter off the art.
MediaMetadataX=(#Inset#+#Padding#+#MediaWide#*(#MediaCoverSize#+8*#Scale#-#Padding#)+54*(1-#MediaWide#)*#Scale#)
MediaMetadataWidth=(#Inset#+#PanelWidth#-#Padding#-#MediaMetadataX#)
; The panel stacks three subsections - title row, song metadata, then the
; progress/transport block - separated by one shared gap. MediaHeaderBottom is
; where the title row ends: the centered heading's lower edge
; (#TitleRowCenterY#+#TitleRowHeight#/2, i.e. 26*Scale below the surface) at
; both widths, now that no separate player-name row wraps below it.
MediaSectionGap=(4*#Scale#)
; A text row's box carries leading below its glyphs, but the progress bar's top
; edge is solid ink, so an equal box gap reads as visibly tighter above the bar.
; Add that leading back. It is an optical constant rather than a derived one:
; Rainmeter cannot query font metrics, and the true value drifts with FontFace
; and TitleFontSize (measured ~6px for IBM Plex Sans at default typography,
; ranging ~5-8px across the min/max title sizes).
MediaBarOpticalPad=(6*#Scale#)
MediaHeaderBottom=(#MediaSurfaceY#+26*#Scale#)
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
; Where the shuffle/repeat toggles show, the timing text moves up to share the
; album row (PlayerMeters.inc), right-aligned to the bar's end, so its width is
; a fixed reservation the album stops short of: room for "12:34 / 45:06" in
; the default 9pt body font, clipped beyond. Where they are hidden it keeps
; its place under the bar's right end and its old bound, and the album its
; full width. It is centre-aligned in both places (StringAlign cannot follow
; a formula, and !SetOption does not re-apply it at runtime). Under the bar
; that centres the text in the same 18S box it used to top-align in, which
; draws it 1px lower than before (measured 2026-10-26, IBM Plex Sans 9pt,
; compact 220, scale 1).
MediaTimingMaxWidth=(#MediaTransportToggles#*88*#Scale#+(1-#MediaTransportToggles#)*Max(1,#ContentX#+#ContentWidth#-#MediaTransportLeft#-104*#Scale#))
MediaTimingGap=(8*#Scale#)
MediaAlbumTimingReserve=(#MediaTransportToggles#*(#MediaTimingMaxWidth#+#MediaTimingGap#))
MediaTimingCenterY=(#MediaTransportToggles#*(#MediaMetadataY#+2*#MediaMetadataPitch#+12*#Scale#)+(1-#MediaTransportToggles#)*(#MediaProgressY#+#DataBarThicknessPx#+11*#Scale#))
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
; The notch spans from the artwork to the transport circles (the shuffle
; toggle, leftmost of the row), so its width is
; derived from both rather than fixed: move the buttons and it follows. Its
; right clearance is deliberately still 4 - that edge is really a question of
; where the buttons live on the x-axis, which is being decided separately.
MediaQueueTabRight=(#MediaTransportGroupX#-#MediaTransportToggles#*#MediaTransportToggleSpan#-#MediaTransportShadowPad#-4*#Scale#)
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
MediaQueueTabHeight=(#MediaTop#+#MediaBodyHeightPx#-#MediaQueueTabY#)
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
MediaQueueDrawerClosedBottom=(#MediaTop#+#MediaBodyHeightPx#)
; --- Queue object (the drawer's only content) --------------------------
; Its top is not the container's padding: it clears whichever of the artwork
; and the panel hangs lower. In the wide layout (Columns=2) the artwork
; overhangs the panel's lower border, so the artwork wins; in the narrow one
; it is a small thumbnail high in the body, so the panel wins. Anchoring to
; the artwork alone put the table halfway up the narrow body, across the
; progress bar, and left the sheet shorter than its own contents - at
; QueueRowLimit=1 the sheet's height went negative.
; The panel's lower border is #MediaTop#+#MediaBodyHeightPx#, not
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
MediaQueueTop=(Max(#MediaCoverY#+#MediaCoverSize#,#MediaTop#+#MediaBodyHeightPx#)+#MediaSectionGap#)
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
; The header row's Refresh action, right-aligned at the rows' right edge. Only
; Media.ini has one: Queue\QueueControlHost.inc sets 56S; Setup keeps 0.
MediaQueueRefreshWidth=0
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
; --- Spectrum drawer sheet, tab and plot (top) -------------------------
; The same container rules, mirrored above the panel: the open sheet shares the
; queue sheet's x-bounds and padding, and its only object is the spectrum plot.
; Tab: the gear's 18px column, so the chevron's centre is the gear's centre.
; It moves left of the gear only when the panel's corner radius exceeds the
; padding, so the tab never sits on the corner's curve. Both edges snap to
; whole pixels, as Rainmeter truncates the gear's own X: at scales where
; 18*Scale is fractional (0.75, 1.25) the tab is then 14 or 23px wide and the
; chevron, kept on the gear's centre, sits 0.25px left of the tab's centre.
MediaVisualizerTabRight=(Floor(Min(#ContentX#+#ContentWidth#,#MediaSurfaceX#+#MediaSurfaceWidth#-#CornerRadius#*#Scale#)))
MediaVisualizerTabX=(Floor(#MediaVisualizerTabRight#-18*#Scale#))
MediaVisualizerTabWidth=(#MediaVisualizerTabRight#-#MediaVisualizerTabX#)
; The sheet's outline is stroked half a border inside its box, like StylePanel.
MediaVisualizerStroke=(#BorderThickness#*#Scale#/2)
MediaVisualizerTabRadius=(Min(#CornerRadius#*#Scale#,#MediaVisualizerTabWidth#/2-#MediaVisualizerStroke#))
; Toggle box. Collapsed: the tab, i.e. the clear strip directly above the
; panel in the gear's column. Expanded: the sheet's top-right corner, the last
; 18S column of the output row (the device name stops short of it), so the
; 16 kHz label can end at the plot's right edge again (user request,
; 2026-10-25).
MediaVisualizerToggleX=(#MediaVisualizerOpen#*Floor(#MediaVisualizerRowRight#-18*#Scale#)+(1-#MediaVisualizerOpen#)*#MediaVisualizerTabX#)
MediaVisualizerToggleY=(#MediaVisualizerOpen#*#MediaVisualizerRowY#+(1-#MediaVisualizerOpen#)*#MediaTop#)
MediaVisualizerToggleWidth=(#MediaVisualizerOpen#*18*#Scale#+(1-#MediaVisualizerOpen#)*#MediaVisualizerTabWidth#)
MediaVisualizerToggleHeight=(#MediaVisualizerOpen#*18*#Scale#+(1-#MediaVisualizerOpen#)*(#MediaSurfaceY#-#MediaTop#))
; The chevron is centred below the tab's own top stroke in the strip's visible
; part when collapsed. Expanded it mirrors the speaker icon's 14S box at the
; row's other end: centred 7S in from the row's right edge (the plot's) and 9S
; below the row's top, level with the icon.
MediaVisualizerGlyphCenterY=(#MediaVisualizerOpen#*(#MediaVisualizerRowY#+9*#Scale#)+(1-#MediaVisualizerOpen#)*(#MediaTop#+#BorderThickness#*#Scale#+#MediaSurfaceY#)/2)
MediaVisualizerGlyphScale=(14*#Scale#/24)
MediaVisualizerGlyphX=(#MediaVisualizerOpen#*(#MediaVisualizerRowRight#-7*#Scale#-#MediaVisualizerToggleX#)+(1-#MediaVisualizerOpen#)*9*#Scale#-12*#MediaVisualizerGlyphScale#)
MediaVisualizerGlyphY=(#MediaVisualizerGlyphCenterY#-#MediaVisualizerToggleY#-12*#MediaVisualizerGlyphScale#)
; Sheet: just the tab when collapsed. Expanded it ends at the queue sheet's
; right edge and starts the plot inset left of the dB gutter, so no unused
; margin is left of the scale (at the default double width that is x129, not
; the panel's x100; compact it is the panel's edge). Its top is always
; #Inset#. The square-cornered bottom tucks behind the panel deep enough to
; clear the panel's own top corner curve.
MediaVisualizerSheetTuck=(Max(8,#CornerRadius#)*#Scale#)
MediaVisualizerOpenSheetX=(#MediaVisualizerPlotX#-#MediaVisualizerAxisWidth#-#MediaVisualizerPlotInset#)
MediaVisualizerSheetX=(#MediaVisualizerOpen#*#MediaVisualizerOpenSheetX#+(1-#MediaVisualizerOpen#)*#MediaVisualizerTabX#)
MediaVisualizerSheetRight=(#MediaVisualizerOpen#*#MediaQueueDrawerRight#+(1-#MediaVisualizerOpen#)*#MediaVisualizerTabRight#)
MediaVisualizerSheetWidth=(#MediaVisualizerSheetRight#-#MediaVisualizerSheetX#)
MediaVisualizerSheetHeight=(#MediaSurfaceY#+#MediaVisualizerSheetTuck#-#Inset#)
MediaVisualizerSheetRadius=(#MediaVisualizerOpen#*#CornerRadius#*#Scale#+(1-#MediaVisualizerOpen#)*#MediaVisualizerTabRadius#)
; The plot's inset inside the open sheet is the queue sheet's padding, unless
; the sheet's rounded top corners would come closer to the plot frame's corners
; than that padding keeps along the straight sides (Padding - Border). Corner
; centres: the sheet's inner stroke edge is a circle of radius R-B/2 centred
; B/2+R in from each edge; the frame's outer edge (drawn at 0.5 with radius 2S)
; is a circle of radius 2S+0.5 centred that far in from the plot's corner. With
; R=CornerRadius*S and B=BorderThickness*S, keeping that clearance needs
;   inset >= B/2 + R - (2S+0.5) - (R - B/2 - (2S+0.5) - (Padding-B)) / sqrt(2),
; which stays at the padding up to CornerRadius 10 at scale 1 (border 1).
MediaVisualizerPlotInset=(Max(#MediaDrawerPadding#,Ceil(#BorderThickness#*#Scale#/2+#CornerRadius#*#Scale#-(2*#Scale#+0.5)-(#CornerRadius#*#Scale#-#BorderThickness#*#Scale#/2-(2*#Scale#+0.5)-(#MediaDrawerPadding#-#BorderThickness#*#Scale#))*0.70710678)))
; The plot's origin (its lower-left corner) sits north-east of the double-width
; artwork's top-right corner, #MediaVisualizerOriginGap# clear of it both ways:
; its bottom edge that far above #MediaTop# (the art's top), its left edge that
; far right of the art's right edge. The dB gutter must still
; fit inside the left inset, which keeps the clearance from the sheet's
; rounded corners, so the origin never moves left of that; the compact layout
; (art below the title) always uses it. The lift's Ceil slack lands in the far
; padding.
MediaVisualizerPlotX=(Max(#MediaSurfaceX#+#MediaVisualizerPlotInset#+#MediaVisualizerAxisWidth#,#MediaWide#*(#MediaCoverX#+#MediaCoverSize#+#MediaVisualizerOriginGap#)))
MediaVisualizerPlotWidth=(#MediaQueueDrawerRight#-#MediaVisualizerPlotInset#-#MediaVisualizerPlotX#)
MediaVisualizerPlotY=(#MediaTop#-#MediaVisualizerOriginGap#-#MediaVisualizerPlotHeight#)
; Frequency labels in the strip beside the art, under the plot and its buffer.
; Their boxes are centred 1S above the strip's centre: a centred box put the
; digits' ink 1px low (3 clear rows above, 1 above the panel border, IBM Plex
; Sans 9pt at scale 1). 40 Hz starts at the origin's x, which the buffer keeps
; clear of the art's border; 16 kHz ends at the plot's right edge (the
; expanded chevron sits in the sheet's top-right corner instead).
MediaVisualizerAxisLabelY=((#MediaTop#+#MediaSurfaceY#)/2-#Scale#)
MediaVisualizerLowLabelX=#MediaVisualizerPlotX#
MediaVisualizerHighLabelRight=(#MediaVisualizerPlotX#+#MediaVisualizerPlotWidth#)
; The output row spans the sheet's padded width, from the dB gutter's left edge
; to the plot's right edge, directly above the plot.
MediaVisualizerRowX=(#MediaVisualizerPlotX#-#MediaVisualizerAxisWidth#)
MediaVisualizerRowWidth=(#MediaQueueDrawerRight#-#MediaVisualizerPlotInset#-#MediaVisualizerRowX#)
MediaVisualizerRowRight=(#MediaVisualizerRowX#+#MediaVisualizerRowWidth#)
; Output volume: in the gear's spot on the title row, right-aligned to the
; gear's right edge and centred on its row; it swaps with the gear on hover.
MediaVisualizerVolumeRight=(#ContentX#+#ContentWidth#)
MediaVisualizerVolumeY=(#MediaHeaderY#+#TitleRowCenterY#-#Inset#)
MediaVisualizerRowY=(#MediaVisualizerPlotY#-#MediaVisualizerDeviceRow#)
; Bottom of the timing text: the last thing inside the panel once the queue is
; hidden, since the transport row now straddles the panel's lower border.
MediaTimingTextBottom=(#MediaProgressY#+#DataBarThicknessPx#+20*#Scale#)
; Preserve the existing queue anchor at normal widths. Only extend it when the
; enlarged art would otherwise collide with the untouched queue footer.
MediaLegacyProgressY=(#MediaSurfaceY#+50*#Scale#+3*#MediaMetadataPitch#+Max(2*#Scale#,6*#Scale#-#DataBarThicknessPx#/2))
MediaLegacyTimingY=(#MediaLegacyProgressY#+#DataBarThicknessPx#+8*#Scale#)
MediaLegacyBodyHeightPx=(Max(Round(#PanelHeight#*#Scale#)+#MediaSurfaceOffset#,Ceil(Max(#MediaCoverY#+#MediaLegacyCoverSize#,#MediaLegacyTimingY#+26*#Scale#)-#MediaTop#+37*#Scale#)))
; The artwork no longer contributes: it deliberately overhangs the panel's
; lower edge, so it must not drive the panel's height (and referencing it here
; would make MediaCoverSize circular, since the art is now derived from this).
MediaBodyHeightPx=((1-#MediaQueueHidden#)*Max(#MediaLegacyBodyHeightPx#,Ceil(#MediaTimingY#+26*#Scale#-#MediaTop#+37*#Scale#))+#MediaQueueHidden#*Ceil(#MediaTimingTextBottom#-#MediaTop#+#Padding#))
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
; Enabled transport glyphs (stroke, and fill while hovered) on the AccentColor
; face: white (user request, 2026-10-25). Disabled glyphs keep MutedColor.
; Media.lua reads this on every update.
MediaTransportGlyphColor=255,255,255
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
MediaTransportCenterY=(#MediaTop#+#MediaBodyHeightPx#)
MediaTransportY=(#MediaTransportCenterY#-#MediaTransportBox#/2)
; Statically centred in the panel background remaining to the right of the
; artwork. The old LayoutTransport centring measured against the timing text,
; which is no longer the transport row.
MediaTransportGap=(4*#Scale#)
MediaTransportGroupWidth=(3*#MediaTransportSize#+2*#MediaTransportGap#)
MediaTransportCenteredX=(((#MediaCoverX#+#MediaCoverSize#)+(#Inset#+#PanelWidth#))/2-#MediaTransportGroupWidth#/2)
; Shuffle and repeat: smaller secondary circles flanking the three, one
; #MediaTransportGap# out, on the same centre line. Their 24-unit art is
; drawn at 18S (the 34S circles carry 24S art, the same 0.7 ratio), with the
; suite's 2S stroke kept rather than scaled, so all five strokes match.
; The row's left end bounds the queue notch, which must keep room for its
; icon and "Queue" label (#MediaQueueTabMinWidth#). Where the centred row
; would cut the notch below that, the whole row slides right by just enough,
; never closer than #Padding# to the panel's right edge. Where even that is
; not enough (measured 2026-10-26: compact at width 220 and below, double at
; 180, every scale; double 220 slides 26S right of centre), the toggles are
; hidden and parked and the three keep their centred place, exactly as
; before. MediaTransportToggles is that 1/0 choice.
MediaTransportToggleSize=(26*#Scale#)
MediaTransportToggleSpan=(#MediaTransportGap#+#MediaTransportToggleSize#)
MediaQueueTabMinWidth=(76*#Scale#)
MediaTransportToggleNeed=(Max(0,#MediaQueueTabX#+#MediaQueueTabMinWidth#+4*#Scale#+#MediaTransportShadowPad#-(#MediaTransportCenteredX#-#MediaTransportToggleSpan#)))
MediaTransportToggleRoom=(#Inset#+#PanelWidth#-#Padding#-(#MediaTransportCenteredX#+#MediaTransportGroupWidth#+#MediaTransportToggleSpan#))
MediaTransportToggles=(#MediaTransportToggleNeed#<=#MediaTransportToggleRoom# ? 1 : 0)
MediaTransportGroupX=(#MediaTransportCenteredX#+#MediaTransportToggles#*#MediaTransportToggleNeed#)
MediaTransportToggleBox=(#MediaTransportToggleSize#+2*#MediaTransportShadowPad#)
MediaTransportToggleY=(#MediaTransportCenterY#-#MediaTransportToggleBox#/2)
MediaTransportToggleGlyphScale=(18*#Scale#/24)
MediaTransportToggleGlyphOffset=((#MediaTransportToggleBox#-18*#Scale#)/2)
; Hidden toggles park at #Inset#, inside the window in every layout, so they
; cannot widen it (a hidden meter still counts toward the skin's bounds).
MediaTransportShuffleX=(#MediaTransportToggles#*(#MediaTransportGroupX#-#MediaTransportToggleSpan#)+(1-#MediaTransportToggles#)*(#Inset#+#MediaTransportShadowPad#))
MediaTransportRepeatX=(#MediaTransportToggles#*(#MediaTransportGroupX#+#MediaTransportGroupWidth#+#MediaTransportGap#)+(1-#MediaTransportToggles#)*(#Inset#+#MediaTransportShadowPad#))
; Off: an opaque neutral face ringed in the panel border colour, so the panel
; border never shows through it; on: the AccentColor face of the trio.
MediaTransportToggleOffFill=#GraphBackgroundColor#
MediaOverhangBottom=(Max(#MediaCoverY#+#MediaCoverSize#,#MediaTransportY#+#MediaTransportBox#))
; The panel band clears the lift above it; the overhang and the open queue
; sheet are absolute positions, so they already include it.
WindowHeight=(Max(Max(#MediaVisualizerLift#+#PanelHeightPx#+#Gap#,Ceil(#MediaOverhangBottom#+#Inset#)),Ceil(#MediaQueueDrawerBottom#+#Inset#)))
