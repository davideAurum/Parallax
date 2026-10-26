; Shared shipped defaults. Persistent overrides belong in User/Settings.inc.
[Variables]
SuiteName=Parallax
SuiteVersion=0.1.0-dev
Theme=default
Scale=1
ColumnWidth=220
Gutter=8
PanelPadding=6
CornerRadius=3
Columns=1
PanelHeight=200
FontFace=IBM Plex Sans
FontSize=9
TitleFontSize=10
HeaderFontSize=8
TextColor=220,220,220
TitleTextColor=220,220,220
HeaderTextColor=175,175,175
MutedColor=175,175,175
AccentColor=137,190,250
AccentColor2=181,161,226
BackgroundColor=15,15,15,255
BorderColor=50,50,50,255
BorderThickness=1
DividerColor=50,50,50,255
DividerThickness=1
TableHeaderBorderColor=50,50,50,255
TableHeaderBorderThickness=1
DataBarThickness=6
TrackColor=50,50,50,255
GoodColor=100,230,90
WarningColor=240,225,40
DangerColor=235,55,75
MetricsInterval=1000
SensorInterval=2000
CapacityInterval=30000
VisualizerInterval=50
; Idle pause (Global Settings): 0 is Off; 5, 10 or 30 minutes without
; keyboard or mouse input pause the utilities (@Resources\Idle\Hook<n>.inc).
; Any other value acts as Off.
IdlePauseMinutes=0
; Automatic update check (Global Settings > Updates): 1 checks the release
; feed about once a day from the loaded utilities (@Resources\Update\Hook1.inc);
; 0 is Off. On by default, including for upgrades from builds without the key.
UpdateCheck=1
GraphBackgroundColor=25,25,25,255
GridColor=50,50,50,180
GraphHeight=48
CPUColor=235,55,75
RAMColor=105,205,255
GPUColor=120,205,45
DiskReadColor=100,230,90
DiskWriteColor=240,225,40
NetworkInColor=240,225,40
NetworkOutColor=100,230,90
MediaColor=137,190,250
ClockColor=137,190,250
; Idle stand-down hook (@Resources\Idle\Hook.inc). Neutral unless Idle pause
; is on: then Hook5/10/30.inc sets the delayed coordinator join, and each
; utility entrypoint, after its includes, places its "Paused (idle)" line,
; names the headline meters it replaces (ParallaxIdleHeadline) and any
; gear/value hover pair (ParallaxIdleHoverSwap), names its module controllers
; and derives the hook's divider from ParallaxIdleHookMs (about one run a
; minute). Hover actions end with #ParallaxIdleHoverAction# (before their
; !Redraw), which Hook.inc sets; empty here, so Off changes nothing.
ParallaxIdleJoinAction=
ParallaxIdleHoverAction=
ParallaxIdleHookMs=60000
ParallaxIdleHookDivider=60
ParallaxIdleControllers=
ParallaxIdleHeadline=
ParallaxIdleHoverSwap=
ParallaxPausedX=0
ParallaxPausedY=0
ParallaxPausedW=1
ParallaxPausedH=1
ParallaxPausedAlign=Right
