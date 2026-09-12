[Variables]
; Two columns retain the shared outer pitch while the cover overhangs the
; narrower surface. One column keeps the compact 48-pixel artwork layout.
MediaWide=(#Columns#-1)
MediaSurfaceX=(#Inset#+96*#MediaWide#*#Scale#)
MediaSurfaceWidth=(#PanelWidth#-96*#MediaWide#*#Scale#)
MediaCoverX=(#Inset#+#Padding#*(1-#MediaWide#))
MediaCoverY=(#Inset#+(44-35*#MediaWide#)*#Scale#)
MediaCoverSize=((48+96*#MediaWide#)*#Scale#)
; These content bounds are local to Media and Setup. Moving the entire content
; column also keeps progress, section rules and every queue row clear of art.
ContentX=(#Inset#+#Padding#+#MediaWide#*(156*#Scale#-#Padding#))
ContentWidth=(#Inset#+#PanelWidth#-#Padding#-#ContentX#)
; PanelHeight is the user's base Media height. Expansion never overwrites it.
PanelHeightPx=(Round((#PanelHeight#+#QueueExpanded#*(8+18*#QueueRowLimit#))*#Scale#))
WindowHeight=(#PanelHeightPx#+#Gap#)
