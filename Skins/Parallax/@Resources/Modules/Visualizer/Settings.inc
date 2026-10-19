; Audio settings: title, Width (standalone-only) and Setup. The ten spectrum
; steppers and their Settings.lua controller are shared with Media settings.
[VisualizerSettingsSharedInclude]
@Include=#@#Modules\Visualizer\SettingsShared.inc

[MeasureVisualizerSettingsWidthValue]
Measure=String
DynamicVariables=1
String=#Columns#
RegExpSubstitute=1
Substitute="^1$":"Single","^2$":"Double"
UpdateDivider=-1

[StyleVisualizerSettingsUI]
Group=VisualizerSettingsUI
UpdateDivider=-1

[StyleVisualizerSettingsCommand]
StringAlign=Center
Padding=0,0,0,0
H=(20*#Scale#)

[MeterVisualizerSettingsTitle]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow | StyleVisualizerSettingsUI
X=#ContentX#
W=(#ContentWidth#-28*#Scale#)
Text=Audio settings

[MeterVisualizerSettingsClose]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton | StyleVisualizerSettingsUI
X=(#ContentX#+#ContentWidth#)
Y=#TitleRowCenterY#
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=RightCenter
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!DeactivateConfig]

[MeterVisualizerSettingsSetup]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+274*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Setup

[MeterVisualizerSettingsSetupRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+292*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsWidthRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+100*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Width')"]

[MeterVisualizerSettingsWidthLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+102*#Scale#)
W=(70*#Scale#)
Text=Width
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Width')"]

[MeterVisualizerSettingsWidthPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Width',-1)"]

[MeterVisualizerSettingsWidthValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+101*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsWidthValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Width')"]

[MeterVisualizerSettingsWidthNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Width',1)"]

[MeterVisualizerSettingsAdvanced]
Meter=String
MeterStyle=StyleButton | StyleVisualizerSettingsCommand | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#/4)
Y=(#Inset#+300*#Scale#)
W=(#VisualizerSettingsColumnWidth#/2-2*#Scale#)
Text=Advanced
LeftMouseUpAction=["notepad.exe" "#@#User\Visualizer.inc"]

[MeterVisualizerSettingsReconnect]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton | StyleVisualizerSettingsCommand | StyleVisualizerSettingsUI
X=(#ContentX#+3*#VisualizerSettingsColumnWidth#/4)
Y=(#Inset#+300*#Scale#)
W=(#VisualizerSettingsColumnWidth#/2-2*#Scale#)
Text=Reconnect
LeftMouseUpAction=[!Refresh "Parallax\Visualizer"][!Refresh]

[MeterVisualizerSettingsSetupHint]
Meter=String
MeterStyle=StyleLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+328*#Scale#)
W=#VisualizerSettingsColumnWidth#
H=(36*#Scale#)
Text=Edit device and quiet#CRLF#threshold in Advanced.

[MeterVisualizerSettingsHint]
Meter=String
MeterStyle=StyleLabel | StyleVisualizerSettingsUI
Y=(#Inset#+376*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=Arrows step; click a value to edit or cycle.
