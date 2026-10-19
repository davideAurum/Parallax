[MeterSetupStatus]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Y=#MediaMetadataY#
FontColor=#WarningColor#
Text=Optional WebNowPlaying
UpdateDivider=-1

[MeterSetupInstructions]
Meter=String
MeterStyle=StyleLabel
Y=(#MediaMetadataY#+20*#Scale#)
H=(36*#Scale#)
ClipString=2
Text=1. WNP plugin is bundled.#CRLF#2. Open a player.
UpdateDivider=-1

[MeterDesktopNote]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Y=(#MediaMetadataY#+62*#Scale#)
H=(18*#Scale#)
Text=Browser: add extension.
UpdateDivider=-1

[MeterWNPDocs]
Meter=String
MeterStyle=MediaButtonStyle|StyleSecondaryButton
X=(#ContentX#+(#ContentWidth#-8*#Scale#)/4)
Y=#MediaTimingY#
W=((#ContentWidth#-8*#Scale#)/2)
Text=WNP docs
LeftMouseUpAction=["https://wnp.keifufu.dev/rainmeter/getting-started"]
UpdateDivider=-1

[MeterLoadPlayer]
Meter=String
MeterStyle=MediaButtonStyle
X=(#ContentX#+#ContentWidth#-(#ContentWidth#-8*#Scale#)/4)
Y=#MediaTimingY#
W=((#ContentWidth#-8*#Scale#)/2)
Text=Load player
LeftMouseUpAction=[!ActivateConfig "Parallax\Media" "Media.ini"]
UpdateDivider=-1
