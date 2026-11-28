; Preserved module preferences. Refresh the Media config after editing.
; Columns: 1 = standard, 2 = double. Use the skin context menu to switch.
; MediaInterval changes skin refresh only, not WebNowPlaying's own polling.
[Variables]
Columns=2
PanelHeight=162
MediaInterval=1000
; Hover the header gear for Media-specific settings. Display defaults also exist
; in entrypoints so older preserved preference files can omit these keys.
QueueExpanded=0
QueueRowLimit=5
QueueShowDetails=1
; Queue request seconds. Use Restart in Media settings after changing this value.
QueuePollSeconds=30
; Spectrum drawer above the player: 0 hidden, 1 tab only, 2 open. While open,
; Rainmeter's AudioLevel plugin captures the Windows output device. Its height,
; colors and sensitivity follow Audio settings (User\Visualizer.inc).
VisualizerDrawer=1
; Where the spectrum drawer sits: 0 a Spectrum tab in the drawer under the
; player, beside Queue and Playlists; 1 a slider above the player.
VisualizerPlacement=0
; The drawer tab the folder tab reopens: 0 queue, 1 spectrum. Media writes it.
QueueDrawerTab=0
; Title icon animation while a WebNowPlaying player reports Playing: 20 (frames
; per second, the default), 10, or 0 for a static icon. Literal digits; any
; other number means 20. With 0 and the spectrum drawer closed, Media updates
; once per MediaInterval instead of every 50 ms.
MediaTitleAnimation=20
; Queue drawer row size: 1 Normal (36 px rows, 32 px covers, song above
; artist; the default) or 0 Compact (18 px rows, 16 px covers, one line).
QueueRowSize=1
; Album colors: 1 lets the current cover recolor the player (title icon,
; progress bar, song/artist/album text and a tint on the gray surfaces); 2
; does the same and slides the text gradient left to right while a track plays
; (more CPU: Media then redraws about 10 times a second); 0 keeps the theme.
; Needs the bundled Chameleon plugin.
MediaAlbumColors=1
; How far the gray surfaces lean toward the cover's main color, 0-30 (%).
MediaAlbumTint=10
; Cover: 0 shows the whole picture (a wide video has bars above and below); 1
; zooms to fill the square, cutting the sides. Also in Media's right-click menu.
MediaCoverZoom=0
