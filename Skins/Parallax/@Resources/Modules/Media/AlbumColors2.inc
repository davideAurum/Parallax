; Album colors with the sliding text gradient (User\Media.inc
; MediaAlbumColors=2): everything AlbumColors1.inc loads, plus TextSlide.lua,
; which moves the song/artist/album gradient while a track plays.
; InlineQueueGeometry.inc ticks Media at 50 ms for it (MediaTextSlideTicks);
; the slide draws one frame every other tick (10 fps).
[AlbumColorsTextSlideInclude]
@Include25=#@#Modules\Media\AlbumColors1.inc

; After MeasureAlbumColors, which sends it the colors.
[MeasureAlbumSlide]
Measure=Script
ScriptFile=#@#Modules\Media\TextSlide.lua
UpdateDivider=#MediaTextSlideDivider#
Group=ParallaxIdlePause
