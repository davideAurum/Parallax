; Video cover on (MediaVideoCover=1): the ParallaxVideoCover plugin draws live
; video on this skin's own window, over the cover: the browser's
; picture-in-picture window, or else the video in the YouTube web app's window
; (the Media module doc, "Video cover and cover preview"). Two columns, a YouTube player, and not
; under the Idle pause. Without the plugin Rainmeter logs that it cannot load and
; the cover stays as it was.
[MeasureVideoCover]
Measure=Plugin
Plugin=ParallaxVideoCover
Group=ParallaxIdlePause
; Every tick, so the picture keeps up when the page scrolls or is resized; the
; plugin itself looks for windows at most once a second.
UpdateDivider=1
DynamicVariables=1
Show=((#MediaWide#=1) && (#MediaStandby#=0) ? 1 : 0)
Player=[MeasurePlayer]
AllowPlayer=YouTube
X=[MeterCoverPlaceholder:X]
Y=[MeterCoverPlaceholder:Y]
Size=[MeterCoverPlaceholder:W]
Radius=#MediaCoverRadius#
Zoom=#MediaCoverZoom#
; While a video is drawn, the still thumbnail is covered so that it cannot show
; around a picture of another shape.
IfCondition=MeasureVideoCover = 1
IfTrueAction=[!ShowMeter MeterVideoCoverBack][!Redraw]
IfFalseAction=[!HideMeter MeterVideoCoverBack][!Redraw]

[MeterVideoCoverBack]
Meter=Shape
AntiAlias=1
X=#MediaCoverX#
Y=#MediaCoverY#
W=#MediaCoverSize#
H=#MediaCoverSize#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#MediaCoverSize#-#Scale#),(#MediaCoverSize#-#Scale#),(#MediaCoverRadius#-#Scale#/2) | Fill Color #GraphBackgroundColor# | Stroke Color 255,255,255 | StrokeWidth #Scale#
Hidden=1
UpdateDivider=-1
