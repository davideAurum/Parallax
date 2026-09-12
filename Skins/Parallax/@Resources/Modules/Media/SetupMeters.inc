[MeterSetupStatus]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Y=(#Inset#+25*#Scale#)
FontColor=#WarningColor#
Text=Optional WebNowPlaying
UpdateDivider=-1

[MeterSetupInstructions]
Meter=String
MeterStyle=StyleLabel
Y=(#Inset#+44*#Scale#)
H=(36*#Scale#)
ClipString=2
Text=1. Install WNP 2.x+.#CRLF#2. Open a player.
UpdateDivider=-1

[MeterDesktopNote]
Meter=String
MeterStyle=StyleLabel|MediaSecondaryStyle
Y=(#Inset#+86*#Scale#)
H=(18*#Scale#)
Text=Browser: add extension.
ToolTipText=Spotify desktop works through Windows media sessions without Spicetify. Browser playback needs the WebNowPlaying extension.
UpdateDivider=-1

[MeterWNPDocs]
Meter=String
MeterStyle=MediaButtonStyle|StyleSecondaryButton
X=(#ContentX#+(#ContentWidth#-8*#Scale#)/4)
Y=(#Inset#+110*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2)
Text=WNP docs
ToolTipText=Open the official WebNowPlaying setup guide in your browser. Nothing is installed automatically.
LeftMouseUpAction=["https://wnp.keifufu.dev/rainmeter/getting-started"]
UpdateDivider=-1

[MeterLoadPlayer]
Meter=String
MeterStyle=MediaButtonStyle
X=(#ContentX#+#ContentWidth#-(#ContentWidth#-8*#Scale#)/4)
Y=(#Inset#+110*#Scale#)
W=((#ContentWidth#-8*#Scale#)/2)
Text=Load player
ToolTipText=Load the Media variant using your installed WebNowPlaying plugin. Install the plugin manually first; this button does not install it.
LeftMouseUpAction=[!ActivateConfig "Parallax\Media" "Media.ini"]
UpdateDivider=-1
