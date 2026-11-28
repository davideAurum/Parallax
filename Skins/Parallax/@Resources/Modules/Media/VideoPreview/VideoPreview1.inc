; Cover preview on (MediaCoverPreview=1): while a YouTube video plays, the cover
; cycles three still frames from it, each fading into the next. The video's id comes from the player
; plugin's cover address; the frames are fetched once per video from YouTube's
; thumbnail host (undocumented addresses; a video without them keeps its cover).
[MeasureCoverAddress]
Measure=Plugin
Plugin=WebNowPlaying
PlayerType=CoverWebAddress
Group=ParallaxIdlePause
UpdateDivider=#MediaLegacyDivider#

[MeasurePreviewFrame1]
Measure=WebParser
; VideoPreview.lua gives the address and enables this once per video.
URL=https://i.ytimg.com/
Download=1
; Once per request; the script asks again for each new video.
UpdateRate=2147483
DynamicVariables=1
Disabled=1
FinishAction=[!CommandMeasure MeasureVideoPreview "Ready(1)"]
Group=ParallaxIdlePause
UpdateDivider=#MediaLegacyDivider#

[MeasurePreviewFrame2]
Measure=WebParser
; VideoPreview.lua gives the address and enables this once per video.
URL=https://i.ytimg.com/
Download=1
; Once per request; the script asks again for each new video.
UpdateRate=2147483
DynamicVariables=1
Disabled=1
FinishAction=[!CommandMeasure MeasureVideoPreview "Ready(2)"]
Group=ParallaxIdlePause
UpdateDivider=#MediaLegacyDivider#

[MeasurePreviewFrame3]
Measure=WebParser
; VideoPreview.lua gives the address and enables this once per video.
URL=https://i.ytimg.com/
Download=1
; Once per request; the script asks again for each new video.
UpdateRate=2147483
DynamicVariables=1
Disabled=1
FinishAction=[!CommandMeasure MeasureVideoPreview "Ready(3)"]
Group=ParallaxIdlePause
UpdateDivider=#MediaLegacyDivider#

[MeasureVideoPreview]
Measure=Script
ScriptFile=#@#Modules\Media\VideoPreview\VideoPreview.lua
Group=ParallaxIdlePause
; Every tick, for the fade; it redraws only while a picture is changing.
UpdateDivider=1

; Drawn in the cover's rounded mask, above the still thumbnail: the picture
; being left, and the one fading in over it.
[MeterCoverPreview]
Meter=Image
Container=MeterCoverMask
X=0
Y=0
W=#MediaCoverSize#
H=#MediaCoverSize#
PreserveAspectRatio=(1+#MediaCoverZoom#)
Group=ParallaxIdleFreeze
Hidden=1
UpdateDivider=-1

[MeterCoverPreviewNext]
Meter=Image
Container=MeterCoverMask
X=0
Y=0
W=#MediaCoverSize#
H=#MediaCoverSize#
PreserveAspectRatio=(1+#MediaCoverZoom#)
Group=ParallaxIdleFreeze
Hidden=1
UpdateDivider=-1
ImageAlpha=0
