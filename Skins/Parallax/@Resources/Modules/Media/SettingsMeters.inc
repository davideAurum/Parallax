; Media settings presentation. Settings.lua owns preference values and save behavior.
; Labels remain on the panel; only value fields and explicit commands are shaded.

[MediaSettingsData]
Group=MediaSettingsData
DynamicVariables=1

[MediaSettingsLabel]
W=(114*#Scale#)

[MediaSettingsValue]
X=(#ContentX#+122*#Scale#)
W=(#ContentWidth#-128*#Scale#)

[MediaSettingsButton]
Group=MediaSettingsData
Padding=0,0,0,0
H=(22*#Scale#)
SolidColor=#GraphBackgroundColor#
StringAlign=LeftCenter
MouseActionCursor=1

[MediaSettingsCentered]
StringAlign=CenterCenter

[MediaSettingsGuidance]
X=#ContentX#
W=#ContentWidth#
H=(18*#Scale#)

[MeterTitle]
Meter=String
MeterStyle=StyleTitle|StyleTitleRow|MediaSettingsData
X=(#ContentX#+#ContentWidth#/2)
W=(#ContentWidth#-44*#Scale#)
StringAlign=CenterCenter
Text=Media settings

[MeterClose]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+#ContentWidth#-10*#Scale#)
Y=#TitleRowCenterY#
W=(20*#Scale#)
H=(18*#Scale#)
Text=X
ToolTipText=Close settings. Media and the Spotify queue helper keep running.
LeftMouseUpAction=[!DeactivateConfig]

[MeterDisplayHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+74*#Scale#)
Text=Display

[MeterDisplayRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+95*#Scale#)

[MeterWidthLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+102*#Scale#)
Text=Panel columns
ToolTipText=Set the panel width to 1 or 2 columns for Media and the standalone Queue panel. Click the number to type; Enter applies and Esc cancels.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
ToolTipText=Decrease the panel width by one column; minimum 1.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('Columns',-1)"]

[MeterWidthFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+100*#Scale#)
ToolTipText=Set the panel width to 1 or 2 columns for Media and the standalone Queue panel. Click the number to type; Enter applies and Esc cancels.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=1
ToolTipText=Set the panel width to 1 or 2 columns for Media and the standalone Queue panel. Click the number to type; Enter applies and Esc cancels.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
ToolTipText=Increase the panel width by one column; maximum 2.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('Columns',1)"]

[MeterQueueExpandedLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+130*#Scale#)
Text=Queue section
ToolTipText=Expand or collapse the queue below the Media player. This does not start or stop its helper.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueExpanded()"]

[MeterQueueExpandedValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|MediaSettingsValue|MediaSettingsData
Y=(#Inset#+128*#Scale#)
Text=Collapsed
ToolTipText=Expand or collapse the queue below the Media player. This does not start or stop its helper.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueExpanded()"]

[MeterQueueRowsLabel]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(114*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+158*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Queue rows
ToolTipText=Set 1 to 5 visible queue items. This saved choice also applies to the standalone Queue panel. Click the number to type; Enter applies and Esc cancels. Spotify determines how many items are available.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+157*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=<
ToolTipText=Decrease the visible queue length by one item; minimum 1. The saved choice also applies to the standalone Queue panel.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueueRowLimit',-1)"]

[MeterQueueRowsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+156*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(56*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(20*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Shape=Rectangle (#Scale#*#MediaSettingsQueueDetailsVisible#/2),(#Scale#*#MediaSettingsQueueDetailsVisible#/2),(55*#Scale#*#MediaSettingsQueueDetailsVisible#),(19*#Scale#*#MediaSettingsQueueDetailsVisible#),(2*#Scale#*#MediaSettingsQueueDetailsVisible#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#Scale#*#MediaSettingsQueueDetailsVisible#)
ToolTipText=Set 1 to 5 visible queue items. This saved choice also applies to the standalone Queue panel. Click the number to type; Enter applies and Esc cancels. Spotify determines how many items are available.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+157*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(56*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=5
ToolTipText=Set 1 to 5 visible queue items. This saved choice also applies to the standalone Queue panel. Click the number to type; Enter applies and Esc cancels. Spotify determines how many items are available.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+157*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=>
ToolTipText=Increase the visible queue length by one item; maximum 5. The saved choice also applies to the standalone Queue panel.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueueRowLimit',1)"]

[MeterQueueDetailsLabel]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(114*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+186*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Queue details
ToolTipText=Show or hide artist and podcast details beside queue titles. This saved choice also applies to the standalone Queue panel.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueDetails()"]

[MeterQueueDetailsValue]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=((#ContentWidth#-128*#Scale#)*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=(3*#Scale#*#MediaSettingsQueueDetailsVisible#),(#Scale#*#MediaSettingsQueueDetailsVisible#),(3*#Scale#*#MediaSettingsQueueDetailsVisible#),(#Scale#*#MediaSettingsQueueDetailsVisible#)
Meter=String
MeterStyle=StyleUtilitySettingsValue|MediaSettingsValue|MediaSettingsData
Y=(#Inset#+184*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Shown
ToolTipText=Show or hide artist and podcast details beside queue titles. This saved choice also applies to the standalone Queue panel.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueDetails()"]

[MeterSamplingHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(218-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Queue sampling

[MeterSamplingRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(239-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterQueuePollLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+(246-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Queue refresh (s)
ToolTipText=Set the Spotify queue refresh interval from 30 to 150 seconds. Click the number to type; Enter applies and Esc cancels. Use Restart to apply the saved interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+(245-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=<
ToolTipText=Decrease the queue refresh interval by one second; minimum 30. Use Restart to apply the saved interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueuePollSeconds',-1)"]

[MeterQueuePollFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+(244-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
ToolTipText=Set the Spotify queue refresh interval from 30 to 150 seconds. Click the number to type; Enter applies and Esc cancels. Use Restart to apply the saved interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+(245-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=30
ToolTipText=Set the Spotify queue refresh interval from 30 to 150 seconds. Click the number to type; Enter applies and Esc cancels. Use Restart to apply the saved interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+(245-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=>
ToolTipText=Increase the queue refresh interval by one second; maximum 150. Use Restart to apply the saved interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueuePollSeconds',1)"]

[MeterStatus]
Meter=String
MeterStyle=StyleLabel|MediaSettingsData|MediaSettingsGuidance
Y=(#Inset#+(272-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Changes save when clicked.

[MeterSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(302-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Source detection

[MeterSourceRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(323-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterSourceStart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+0*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(339-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Start
ToolTipText=Start local Windows media-session detection to identify Spotify. No login is needed; this runs independently of the Spotify queue helper.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Source','Start')"]

[MeterSourceStop]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+1*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(339-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Stop
ToolTipText=Stop local Windows source detection. This leaves playback, Spotify sign-in and the separate queue helper unchanged.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Source','Stop')"]

[MeterSourceGuidance]
Meter=String
MeterStyle=StyleLabel|MediaSettingsGuidance|MediaSettingsData
Y=(#Inset#+(356-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Identifies Spotify locally; no sign-in needed.
ToolTipText=Start local Windows media-session detection to identify Spotify. This observer runs independently of the Spotify queue helper; opening settings does not start it.

[MeterQueueHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(386-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Spotify queue

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(407-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterSignIn]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+0*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(423-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Sign in
ToolTipText=Open Spotify sign-in in your browser. A console guides setup if a public Client ID is needed.
LeftMouseUpAction=["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" "-NoExit" "-File" "#@#Modules\Media\Queue\QueueProvider.ps1" "-Command" "Connect" "-PollSeconds" "#QueuePollSeconds#"]
DynamicVariables=1

[MeterStart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+1*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(423-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Start
ToolTipText=Start the local queue helper with the saved interval. An existing helper keeps its current interval.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Start')"]
DynamicVariables=1

[MeterStop]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+2*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(423-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Stop
ToolTipText=Stop queue polling and clear displayed queue data. Spotify sign-in is retained.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Stop')"]

[MeterRestart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+0*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(451-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Restart
ToolTipText=Restart the queue helper with the saved refresh interval. Existing Spotify rate limits remain in effect.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Restart')"]
DynamicVariables=1

[MeterDisconnect]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+1*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(451-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Disconnect
ToolTipText=Stop the queue helper and delete this user's saved Spotify tokens. The public Client ID is retained.
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Disconnect')"]

[MeterQueueGuidance]
Meter=String
MeterStyle=StyleLabel|MediaSettingsGuidance|MediaSettingsData
Y=(#Inset#+(468-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Sign in starts polling. Restart applies changes.
ToolTipText=Sign in starts queue polling. Start resumes a stopped helper; Restart applies the saved interval. Stop keeps sign-in, while Disconnect deletes saved tokens and retains the public Client ID.

[MeterLinksHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(498-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Tools & help

[MeterLinksRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(519-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterOpenQueue]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+0*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(535-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Open queue
ToolTipText=Open the separate queue panel. The expandable Media queue uses the same saved preferences.
LeftMouseUpAction=[!ActivateConfig "Parallax\Media\Queue" "Queue.ini"]

[MeterPlayerSetup]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+1*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(535-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Player setup
ToolTipText=Open the plugin-free Media setup panel in place of the player.
LeftMouseUpAction=[!ActivateConfig "Parallax\Media" "Setup.ini"]

[MeterHelp]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+2*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(535-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Help
ToolTipText=Open the Spotify queue setup and troubleshooting guide.
LeftMouseUpAction=["#@#Modules\Media\Queue\README.md"]
