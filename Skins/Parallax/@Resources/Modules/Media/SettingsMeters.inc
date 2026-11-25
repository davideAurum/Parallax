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
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('Columns',-1)"]

[MeterWidthFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+100*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=1
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('Columns')"]

[MeterWidthIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('Columns',1)"]

; Spectrum drawer: a three-way categorical choice, so it uses the shared
; previous/value/next group with wrapping (UTILITY-SETTINGS.md). Its field is
; 76px rather than 56 so Collapsed/Expanded fit at the largest body size.
[MeterVisualizerDrawerLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+130*#Scale#)
Text=Spectrum drawer
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',1)"]

[MeterVisualizerDrawerDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',-1)"]

[MeterVisualizerDrawerFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+128*#Scale#)
W=(76*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(76*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',1)"]

[MeterVisualizerDrawerValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+180*#Scale#)
Y=(#Inset#+129*#Scale#)
W=(76*#Scale#)
Text=Collapsed
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',1)"]

[MeterVisualizerDrawerIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+229*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',1)"]

; Where the spectrum sits: Bottom, a tab of the drawer under the player
; (the default), or Top, the slider above it.
[MeterVisualizerPlacementLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+158*#Scale#)
Text=Spectrum position
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerPlacement',1)"]

[MeterVisualizerPlacementDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+157*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerPlacement',-1)"]

[MeterVisualizerPlacementFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+156*#Scale#)
W=(76*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(76*#Scale#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerPlacement',1)"]

[MeterVisualizerPlacementValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+180*#Scale#)
Y=(#Inset#+157*#Scale#)
W=(76*#Scale#)
Text=Bottom
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerPlacement',1)"]

[MeterVisualizerPlacementIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+229*#Scale#)
Y=(#Inset#+157*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerPlacement',1)"]

; Title icon animation while a player reports Playing: a three-way categorical
; choice (Off / 10 fps / 20 fps) in the shared previous/value/next group with
; wrapping; the default 56px field fits each at the largest body size. Saving
; refreshes Media, which picks its tick and pulse cadence when it loads.
[MeterTitleAnimationLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+186*#Scale#)
Text=Title animation
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaTitleAnimation',1)"]

[MeterTitleAnimationDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+185*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaTitleAnimation',-1)"]

[MeterTitleAnimationFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+184*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaTitleAnimation',1)"]

[MeterTitleAnimationValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+185*#Scale#)
Text=20 fps
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaTitleAnimation',1)"]

[MeterTitleAnimationIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+185*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaTitleAnimation',1)"]

; Album colors (2026-11-19): On lets the current cover recolor the player
; (AlbumColors1.inc); Off loads no color measure and keeps the theme.
[MeterAlbumColorsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+214*#Scale#)
Text=Album colors
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaAlbumColors',1)"]

[MeterAlbumColorsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+213*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaAlbumColors',-1)"]

[MeterAlbumColorsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+212*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaAlbumColors',1)"]

[MeterAlbumColorsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+213*#Scale#)
Text=On
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaAlbumColors',1)"]

[MeterAlbumColorsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+213*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('MediaAlbumColors',1)"]

; Album tint: how far the gray surfaces lean toward the cover's main color,
; 0-30 %, in the shared numeric stepper (arrows step 1, the value opens typed
; entry).
[MeterAlbumTintLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+242*#Scale#)
Text=Album tint %
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('MediaAlbumTint')"]

[MeterAlbumTintDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+241*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('MediaAlbumTint',-1)"]

[MeterAlbumTintFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+240*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('MediaAlbumTint')"]

[MeterAlbumTintValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+241*#Scale#)
Text=10
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('MediaAlbumTint')"]

[MeterAlbumTintIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+241*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('MediaAlbumTint',1)"]

[MeterQueueExpandedLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+270*#Scale#)
Text=Queue section
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueExpanded()"]

[MeterQueueExpandedValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue|MediaSettingsValue|MediaSettingsData
Y=(#Inset#+268*#Scale#)
Text=Collapsed
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueExpanded()"]

[MeterQueueRowsLabel]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(114*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+298*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Queue rows
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+297*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueueRowLimit',-1)"]

[MeterQueueRowsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+296*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(56*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(20*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Shape=Rectangle (#Scale#*#MediaSettingsQueueDetailsVisible#/2),(#Scale#*#MediaSettingsQueueDetailsVisible#/2),(55*#Scale#*#MediaSettingsQueueDetailsVisible#),(19*#Scale#*#MediaSettingsQueueDetailsVisible#),(2*#Scale#*#MediaSettingsQueueDetailsVisible#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#Scale#*#MediaSettingsQueueDetailsVisible#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+297*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(56*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=5
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueueRowLimit')"]

[MeterQueueRowsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+297*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueueRowLimit',1)"]

[MeterQueueDetailsLabel]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(114*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+326*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Queue details
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueDetails()"]

[MeterQueueDetailsValue]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=((#ContentWidth#-128*#Scale#)*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=(3*#Scale#*#MediaSettingsQueueDetailsVisible#),(#Scale#*#MediaSettingsQueueDetailsVisible#),(3*#Scale#*#MediaSettingsQueueDetailsVisible#),(#Scale#*#MediaSettingsQueueDetailsVisible#)
Meter=String
MeterStyle=StyleUtilitySettingsValue|MediaSettingsValue|MediaSettingsData
Y=(#Inset#+324*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Shown
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ToggleQueueDetails()"]

; Queue row size (2026-11-19): Normal (36 px rows, 32 px covers, song above
; artist) or Compact (18 px rows, 16 px covers, one line). A queue display
; detail like the two rows above, so it hides with them. The 76 px field (as
; the Spectrum drawer row) fits "Compact" at the largest body size.
[MeterQueueRowSizeLabel]
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(114*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+354*#Scale#*#MediaSettingsQueueDetailsVisible#)
Text=Queue row size
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('QueueRowSize',1)"]

[MeterQueueRowSizeDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+353*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('QueueRowSize',-1)"]

[MeterQueueRowSizeFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+352*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(76*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(20*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Shape=Rectangle (#Scale#*#MediaSettingsQueueDetailsVisible#/2),(#Scale#*#MediaSettingsQueueDetailsVisible#/2),(75*#Scale#*#MediaSettingsQueueDetailsVisible#),(19*#Scale#*#MediaSettingsQueueDetailsVisible#),(2*#Scale#*#MediaSettingsQueueDetailsVisible#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#Scale#*#MediaSettingsQueueDetailsVisible#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('QueueRowSize',1)"]

[MeterQueueRowSizeValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+180*#Scale#)
Y=(#Inset#+353*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(76*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=Normal
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('QueueRowSize',1)"]

[MeterQueueRowSizeIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+229*#Scale#)
Y=(#Inset#+353*#Scale#*#MediaSettingsQueueDetailsVisible#)
Hidden=(1-#MediaSettingsQueueDetailsVisible#)
W=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
H=(18*#Scale#*#MediaSettingsQueueDetailsVisible#)
Padding=0,0,0,0
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepChoice('QueueRowSize',1)"]

; Spectrum: the ten steppers Audio settings shows, writing the same
; User\Visualizer.inc, so the drawer and the standalone Visualizer share them.
; In this window they join MediaSettingsData, so a queue-row toggle above
; re-places them with the rest of the form.
[StyleVisualizerSettingsUI]
Group=MediaSettingsData
DynamicVariables=1

[MediaSettingsSpectrumInclude]
@Include=#@#Modules\Visualizer\SettingsShared.inc

[MeterSamplingHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(590-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Queue sampling

[MeterSamplingRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(611-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterQueuePollLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel|MediaSettingsLabel|MediaSettingsData
Y=(#Inset#+(618-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Queue refresh (s)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+131*#Scale#)
Y=(#Inset#+(617-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueuePollSeconds',-1)"]

[MeterQueuePollFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame|MediaSettingsData
X=(#ContentX#+142*#Scale#)
Y=(#Inset#+(616-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollValue]
Meter=String
MeterStyle=StyleSettingsStepperValue|MediaSettingsData
X=(#ContentX#+170*#Scale#)
Y=(#Inset#+(617-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=30
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "BeginNumberInput('QueuePollSeconds')"]

[MeterQueuePollIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton|MediaSettingsData
X=(#ContentX#+209*#Scale#)
Y=(#Inset#+(617-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "StepNumber('QueuePollSeconds',1)"]

[MeterStatus]
Meter=String
MeterStyle=StyleLabel|MediaSettingsData|MediaSettingsGuidance
Y=(#Inset#+(644-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Changes save when clicked.

[MeterSourceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(674-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Source detection

[MeterSourceRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(695-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterSourceStart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+0*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(711-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Start
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Source','Start')"]

[MeterSourceStop]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-4*#Scale#)/2)/2+1*(((#ContentWidth#-4*#Scale#)/2)+4*#Scale#))
Y=(#Inset#+(711-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
Text=Stop
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Source','Stop')"]

[MeterSourceGuidance]
Meter=String
MeterStyle=StyleLabel|MediaSettingsGuidance|MediaSettingsData
Y=(#Inset#+(728-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Identifies Spotify locally; no sign-in needed.

[MeterQueueHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(758-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Spotify queue (experimental)

[MeterQueueRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(779-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterStart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+0*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(795-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Start
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Start')"]
DynamicVariables=1

[MeterStop]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+1*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(795-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Stop
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Stop')"]

[MeterRestart]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+2*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(795-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Restart
LeftMouseUpAction=[!CommandMeasure MeasureMediaSettings "ProviderControl('Queue','Restart')"]
DynamicVariables=1

; Sign in and Disconnect are in Connections (2026-11-25).
[MeterConnections]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+#ContentWidth#/2)
Y=(#Inset#+(823-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=#ContentWidth#
Text=Spotify sign-in: Connections
LeftMouseUpAction=[!ActivateConfig "Parallax\Connections" "Connections.ini"]

[MeterQueueGuidance]
Meter=String
MeterStyle=StyleLabel|MediaSettingsGuidance|MediaSettingsData
Y=(#Inset#+(840-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Needs Spotify Premium. Signing in also starts it.

[MeterLinksHeading]
Meter=String
MeterStyle=StyleUtilitySettingsSection|MediaSettingsData
Y=(#Inset#+(870-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
Text=Tools & help

[MeterLinksRule]
Meter=Shape
MeterStyle=StyleRule|MediaSettingsData
Y=(#Inset#+(891-#MediaSettingsQueueCollapsedHeight#)*#Scale#)

[MeterOpenQueue]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+0*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(907-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Open queue
LeftMouseUpAction=[!ActivateConfig "Parallax\Media\Queue" "Queue.ini"]

[MeterPlayerSetup]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+1*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(907-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Player setup
LeftMouseUpAction=[!ActivateConfig "Parallax\Media" "Setup.ini"]

[MeterHelp]
Meter=String
MeterStyle=StyleButton|MediaSettingsButton|MediaSettingsCentered|StyleSecondaryButton|MediaSettingsData
X=(#ContentX#+((#ContentWidth#-8*#Scale#)/3)/2+2*(((#ContentWidth#-8*#Scale#)/3)+4*#Scale#))
Y=(#Inset#+(907-#MediaSettingsQueueCollapsedHeight#)*#Scale#)
W=((#ContentWidth#-8*#Scale#)/3)
Text=Help
LeftMouseUpAction=["#@#Modules\Media\Queue\README.md"]
