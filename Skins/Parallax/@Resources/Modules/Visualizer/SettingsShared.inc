; Spectrum steppers shared by Audio settings (Visualizer\Settings\Settings.ini,
; through Settings.inc) and Media settings (Media\Settings\Settings.ini): the
; Settings.lua controller, its one-shot numeric input, and the Height, Bar gap,
; Color, Top round, Axis gap, Quality, Interval, Sensitivity, Attack and Decay
; rows with their Appearance / Performance / Animation headings. Both write the
; same User\Visualizer.inc, so the standalone and Media's drawer share one set
; of choices. The host defines:
;   VisualizerSettingsTop         logical px added to every Y (0 in Audio settings)
;   VisualizerSettingsLeftShift   extra Y for the left column's rows (0, or -28
;                                 where the host has no Width row above Height)
;   VisualizerSettingsRuleDrop    extra Y for the heading rules, to match the
;                                 host's own heading-to-rule spacing (0 or 3)
;   VisualizerSettingsAppearanceTitle   left column heading text
;   VisualizerSettingsHeight      the Visualizer's PanelHeight preset
;   VisualizerSettingsColumnWidth, VisualizerSettingsValueWidth,
;   VisualizerSettingsRightX      the two-column grid
;   [StyleVisualizerSettingsUI]   group / update behavior for these meters
;
; The frame (Row) carries no tooltip: its value text covers it and shows the
; same one. Rainmeter creates a tooltip window per meter at load, measured at
; about 40 ms each on this suite's test host, so each one saved is ~40 ms.

; Event-only settings: arrows step presets; numeric centers open the shared
; one-shot data-only editor. Opening this panel starts no audio capture.
[MeasureVisualizerSettings]
Measure=Script
ScriptFile=#@#Modules\Visualizer\Settings.lua
UpdateDivider=-1

[MeasureVisualizerSettingsInput]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
Parameter=-NoProfile -NonInteractive
State=Hide
OutputType=UTF8
Timeout=300000
FinishAction=[!UpdateMeasure MeasureVisualizerSettingsInput][!CommandMeasure MeasureVisualizerSettings "CommitInput()"]
UpdateDivider=-1
DynamicVariables=1

[MeasureVisualizerSettingsHeightValue]
Measure=String
DynamicVariables=1
String=#VisualizerSettingsHeight# px
UpdateDivider=-1

[MeasureVisualizerSettingsSpacingValue]
Measure=String
DynamicVariables=1
String=#VisualizerBandGap# px
UpdateDivider=-1

[MeasureVisualizerSettingsColorValue]
Measure=String
DynamicVariables=1
String=#VisualizerColorMode#
RegExpSubstitute=1
Substitute="^0$":"Media","^1$":"Accent 1","^2$":"Accent 2","^3$":"Horiz.","^4$":"Vert."
UpdateDivider=-1

[MeasureVisualizerSettingsQualityValue]
Measure=String
DynamicVariables=1
String=#VisualizerQuality#
RegExpSubstitute=1
Substitute="^0$":"Low","^1$":"Normal","^2$":"High"
UpdateDivider=-1

[MeasureVisualizerSettingsCadenceValue]
Measure=String
DynamicVariables=1
String=#VisualizerUpdateOverride#
RegExpSubstitute=1
Substitute="^0$":"Suite","^33$":"33 ms","^50$":"50 ms","^100$":"100 ms"
UpdateDivider=-1

[MeterVisualizerSettingsAppearance]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+74)*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=#VisualizerSettingsAppearanceTitle#

[MeterVisualizerSettingsAppearanceRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsRuleDrop#+92)*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsPerformance]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+74)*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Performance

[MeterVisualizerSettingsPerformanceRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsRuleDrop#+92)*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsAnimation]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+162)*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Animation

[MeterVisualizerSettingsAnimationRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsRuleDrop#+180)*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsHeightRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+128)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]

[MeterVisualizerSettingsHeightLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+130)*#Scale#)
W=(70*#Scale#)
Text=Height
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]

[MeterVisualizerSettingsHeightPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+129)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Height',-1)"]

[MeterVisualizerSettingsHeightValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+129)*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsHeightValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]

[MeterVisualizerSettingsHeightNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+129)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Height',1)"]

[MeterVisualizerSettingsSpacingRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+156)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]

[MeterVisualizerSettingsSpacingLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+158)*#Scale#)
W=(70*#Scale#)
Text=Bar gap
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]

[MeterVisualizerSettingsSpacingPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+157)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Spacing',-1)"]

[MeterVisualizerSettingsSpacingValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+157)*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsSpacingValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]

[MeterVisualizerSettingsSpacingNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+157)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Spacing',1)"]

[MeterVisualizerSettingsColorRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+184)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]

[MeterVisualizerSettingsColorLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+186)*#Scale#)
W=(70*#Scale#)
Text=Color
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]

[MeterVisualizerSettingsColorPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+185)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Color',-1)"]

[MeterVisualizerSettingsColorValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+185)*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsColorValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]

[MeterVisualizerSettingsColorNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+185)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Color',1)"]

[MeterVisualizerSettingsRadiusRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+212)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]

[MeterVisualizerSettingsRadiusLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+214)*#Scale#)
W=(70*#Scale#)
Text=Top round
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]

[MeterVisualizerSettingsRadiusPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+213)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Radius',-1)"]

[MeterVisualizerSettingsRadiusValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+213)*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerBarRadius# px
DynamicVariables=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]

[MeterVisualizerSettingsRadiusNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+213)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Radius',1)"]

[MeterVisualizerSettingsBaselineRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+240)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]

[MeterVisualizerSettingsBaselineLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+242)*#Scale#)
W=(70*#Scale#)
Text=Axis gap
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]

[MeterVisualizerSettingsBaselinePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+241)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Baseline',-1)"]

[MeterVisualizerSettingsBaselineValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+241)*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerBaselineGap# px
DynamicVariables=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]

[MeterVisualizerSettingsBaselineNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+#VisualizerSettingsLeftShift#+241)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Baseline',1)"]

[MeterVisualizerSettingsQualityRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+100)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]

[MeterVisualizerSettingsQualityLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+102)*#Scale#)
W=(70*#Scale#)
Text=Quality
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]

[MeterVisualizerSettingsQualityPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+101)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Quality',-1)"]

[MeterVisualizerSettingsQualityValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+101)*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsQualityValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]

[MeterVisualizerSettingsQualityNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+101)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Quality',1)"]

[MeterVisualizerSettingsCadenceRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+128)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]

[MeterVisualizerSettingsCadenceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+130)*#Scale#)
W=(70*#Scale#)
Text=Interval
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]

[MeterVisualizerSettingsCadencePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+129)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Cadence',-1)"]

[MeterVisualizerSettingsCadenceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+129)*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsCadenceValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]

[MeterVisualizerSettingsCadenceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+129)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Cadence',1)"]

[MeterVisualizerSettingsSensitivityRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+188)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]

[MeterVisualizerSettingsSensitivityLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+190)*#Scale#)
W=(70*#Scale#)
Text=Sensitivity
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]

[MeterVisualizerSettingsSensitivityPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+189)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Sensitivity',-1)"]

[MeterVisualizerSettingsSensitivityValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+189)*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerSensitivity# dB
DynamicVariables=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]

[MeterVisualizerSettingsSensitivityNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+189)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Sensitivity',1)"]

[MeterVisualizerSettingsAttackRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+216)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]

[MeterVisualizerSettingsAttackLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+218)*#Scale#)
W=(70*#Scale#)
Text=Attack
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]

[MeterVisualizerSettingsAttackPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+217)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Attack',-1)"]

[MeterVisualizerSettingsAttackValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+217)*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerAttack# ms
DynamicVariables=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]

[MeterVisualizerSettingsAttackNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+217)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Attack',1)"]

[MeterVisualizerSettingsDecayRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+244)*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]

[MeterVisualizerSettingsDecayLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+(#VisualizerSettingsTop#+246)*#Scale#)
W=(70*#Scale#)
Text=Decay
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]

[MeterVisualizerSettingsDecayPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+245)*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Decay',-1)"]

[MeterVisualizerSettingsDecayValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+(#VisualizerSettingsTop#+245)*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerDecay# ms
DynamicVariables=1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]

[MeterVisualizerSettingsDecayNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+(#VisualizerSettingsTop#+245)*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Decay',1)"]
