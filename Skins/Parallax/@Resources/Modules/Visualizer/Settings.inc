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

[MeasureVisualizerSettingsWidthValue]
Measure=String
String=#Columns#
RegExpSubstitute=1
Substitute="^1$":"Single","^2$":"Double"
UpdateDivider=-1

[MeasureVisualizerSettingsHeightValue]
Measure=String
String=#PanelHeight# px
UpdateDivider=-1

[MeasureVisualizerSettingsSpacingValue]
Measure=String
String=#VisualizerBandGap# px
UpdateDivider=-1

[MeasureVisualizerSettingsColorValue]
Measure=String
String=#VisualizerColorMode#
RegExpSubstitute=1
Substitute="^0$":"Media","^1$":"Accent 1","^2$":"Accent 2","^3$":"Horiz.","^4$":"Vert."
UpdateDivider=-1

[MeasureVisualizerSettingsQualityValue]
Measure=String
String=#VisualizerQuality#
RegExpSubstitute=1
Substitute="^0$":"Low","^1$":"Normal","^2$":"High"
UpdateDivider=-1

[MeasureVisualizerSettingsCadenceValue]
Measure=String
String=#VisualizerUpdateOverride#
RegExpSubstitute=1
Substitute="^0$":"Suite","^33$":"33 ms","^50$":"50 ms","^100$":"100 ms"
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
ToolTipText=Close Audio settings. Saved choices remain active; the Visualizer keeps its current loaded or unloaded state.

[MeterVisualizerSettingsAppearance]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+74*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Appearance

[MeterVisualizerSettingsAppearanceRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+92*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsPerformance]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+74*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Performance

[MeterVisualizerSettingsPerformanceRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+92*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

[MeterVisualizerSettingsAnimation]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+162*#Scale#)
W=#VisualizerSettingsColumnWidth#
Text=Animation

[MeterVisualizerSettingsAnimationRule]
Meter=Shape
MeterStyle=StyleRule | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+180*#Scale#)
Shape=Line 0,0,#VisualizerSettingsColumnWidth#,0 | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)

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
ToolTipText=Previous/next: Single (Standard, one column) or Double (two columns). Click the value to cycle.

[MeterVisualizerSettingsWidthLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+102*#Scale#)
W=(70*#Scale#)
Text=Width
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Width')"]
ToolTipText=Previous/next: Single (Standard, one column) or Double (two columns). Click the value to cycle.

[MeterVisualizerSettingsWidthPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Width',-1)"]
ToolTipText=Previous/next: Single (Standard, one column) or Double (two columns). Click the value to cycle.

[MeterVisualizerSettingsWidthValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+101*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsWidthValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Width')"]
ToolTipText=Previous/next: Single (Standard, one column) or Double (two columns). Click the value to cycle.

[MeterVisualizerSettingsWidthNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Width',1)"]
ToolTipText=Previous/next: Single (Standard, one column) or Double (two columns). Click the value to cycle.

[MeterVisualizerSettingsHeightRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+128*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]
ToolTipText=Arrows: 126, 146, 186 px, stopping at the ends. Click to type exactly 126, 146 or 186. This is a minimum; a large axis gap may increase the panel height to keep labels readable.

[MeterVisualizerSettingsHeightLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+130*#Scale#)
W=(70*#Scale#)
Text=Height
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]
ToolTipText=Arrows: 126, 146, 186 px, stopping at the ends. Click to type exactly 126, 146 or 186. This is a minimum; a large axis gap may increase the panel height to keep labels readable.

[MeterVisualizerSettingsHeightPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Height',-1)"]
ToolTipText=Arrows: 126, 146, 186 px, stopping at the ends. Click to type exactly 126, 146 or 186. This is a minimum; a large axis gap may increase the panel height to keep labels readable.

[MeterVisualizerSettingsHeightValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+129*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsHeightValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Height')"]
ToolTipText=Arrows: 126, 146, 186 px, stopping at the ends. Click to type exactly 126, 146 or 186. This is a minimum; a large axis gap may increase the panel height to keep labels readable.

[MeterVisualizerSettingsHeightNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Height',1)"]
ToolTipText=Arrows: 126, 146, 186 px, stopping at the ends. Click to type exactly 126, 146 or 186. This is a minimum; a large axis gap may increase the panel height to keep labels readable.

[MeterVisualizerSettingsSpacingRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+156*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]
ToolTipText=Arrows: 0, 1, 3, 4 px, stopping at the ends. Click to type a whole number from 0 to 4.

[MeterVisualizerSettingsSpacingLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+158*#Scale#)
W=(70*#Scale#)
Text=Bar gap
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]
ToolTipText=Arrows: 0, 1, 3, 4 px, stopping at the ends. Click to type a whole number from 0 to 4.

[MeterVisualizerSettingsSpacingPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+157*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Spacing',-1)"]
ToolTipText=Arrows: 0, 1, 3, 4 px, stopping at the ends. Click to type a whole number from 0 to 4.

[MeterVisualizerSettingsSpacingValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+157*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsSpacingValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Spacing')"]
ToolTipText=Arrows: 0, 1, 3, 4 px, stopping at the ends. Click to type a whole number from 0 to 4.

[MeterVisualizerSettingsSpacingNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+157*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Spacing',1)"]
ToolTipText=Arrows: 0, 1, 3, 4 px, stopping at the ends. Click to type a whole number from 0 to 4.

[MeterVisualizerSettingsColorRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+184*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]
ToolTipText=Previous/next: Media, Accent 1, Accent 2, Horizontal gradient, Vertical gradient. Click the value to cycle. Horizontal: left Accent 1 to right Accent 2. Vertical: bottom Accent 1 to top Accent 2.

[MeterVisualizerSettingsColorLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+186*#Scale#)
W=(70*#Scale#)
Text=Color
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]
ToolTipText=Previous/next: Media, Accent 1, Accent 2, Horizontal gradient, Vertical gradient. Click the value to cycle. Horizontal: left Accent 1 to right Accent 2. Vertical: bottom Accent 1 to top Accent 2.

[MeterVisualizerSettingsColorPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+185*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Color',-1)"]
ToolTipText=Previous/next: Media, Accent 1, Accent 2, Horizontal gradient, Vertical gradient. Click the value to cycle. Horizontal: left Accent 1 to right Accent 2. Vertical: bottom Accent 1 to top Accent 2.

[MeterVisualizerSettingsColorValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+185*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsColorValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Color')"]
ToolTipText=Previous/next: Media, Accent 1, Accent 2, Horizontal gradient, Vertical gradient. Click the value to cycle. Horizontal: left Accent 1 to right Accent 2. Vertical: bottom Accent 1 to top Accent 2.

[MeterVisualizerSettingsColorNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+185*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Color',1)"]
ToolTipText=Previous/next: Media, Accent 1, Accent 2, Horizontal gradient, Vertical gradient. Click the value to cycle. Horizontal: left Accent 1 to right Accent 2. Vertical: bottom Accent 1 to top Accent 2.

[MeterVisualizerSettingsRadiusRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+212*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 12. Click to type a whole number from 0 to 12. Round only the top corners of spectrum bars. Actual rounding is limited by each bar width and height.

[MeterVisualizerSettingsRadiusLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+214*#Scale#)
W=(70*#Scale#)
Text=Top round
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 12. Click to type a whole number from 0 to 12. Round only the top corners of spectrum bars. Actual rounding is limited by each bar width and height.

[MeterVisualizerSettingsRadiusPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+213*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Radius',-1)"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 12. Click to type a whole number from 0 to 12. Round only the top corners of spectrum bars. Actual rounding is limited by each bar width and height.

[MeterVisualizerSettingsRadiusValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+213*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerBarRadius# px
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Radius')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 12. Click to type a whole number from 0 to 12. Round only the top corners of spectrum bars. Actual rounding is limited by each bar width and height.

[MeterVisualizerSettingsRadiusNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+213*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Radius',1)"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 12. Click to type a whole number from 0 to 12. Round only the top corners of spectrum bars. Actual rounding is limited by each bar width and height.

[MeterVisualizerSettingsBaselineRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#)
Y=(#Inset#+240*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 24. Click to type a whole number from 0 to 24. Lift the bars above the bottom x-axis. Short panels grow as needed to keep the dB scale readable.

[MeterVisualizerSettingsBaselineLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#ContentX#
Y=(#Inset#+242*#Scale#)
W=(70*#Scale#)
Text=Axis gap
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 24. Click to type a whole number from 0 to 24. Lift the bars above the bottom x-axis. Short panels grow as needed to keep the dB scale readable.

[MeterVisualizerSettingsBaselinePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+85*#Scale#)
Y=(#Inset#+241*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Baseline',-1)"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 24. Click to type a whole number from 0 to 24. Lift the bars above the bottom x-axis. Short panels grow as needed to keep the dB scale readable.

[MeterVisualizerSettingsBaselineValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#ContentX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+241*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerBaselineGap# px
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Baseline')"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 24. Click to type a whole number from 0 to 24. Lift the bars above the bottom x-axis. Short panels grow as needed to keep the dB scale readable.

[MeterVisualizerSettingsBaselineNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+241*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Baseline',1)"]
ToolTipText=Arrows change by 1 px, stopping at 0 and 24. Click to type a whole number from 0 to 24. Lift the bars above the bottom x-axis. Short panels grow as needed to keep the dB scale readable.

[MeterVisualizerSettingsQualityRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+100*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]
ToolTipText=Previous/next: Low (512), Normal (1024), High (2048 FFT). Click the value to cycle. All retain 24 bands.

[MeterVisualizerSettingsQualityLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+102*#Scale#)
W=(70*#Scale#)
Text=Quality
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]
ToolTipText=Previous/next: Low (512), Normal (1024), High (2048 FFT). Click the value to cycle. All retain 24 bands.

[MeterVisualizerSettingsQualityPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Quality',-1)"]
ToolTipText=Previous/next: Low (512), Normal (1024), High (2048 FFT). Click the value to cycle. All retain 24 bands.

[MeterVisualizerSettingsQualityValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+101*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsQualityValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Quality')"]
ToolTipText=Previous/next: Low (512), Normal (1024), High (2048 FFT). Click the value to cycle. All retain 24 bands.

[MeterVisualizerSettingsQualityNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+101*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Quality',1)"]
ToolTipText=Previous/next: Low (512), Normal (1024), High (2048 FFT). Click the value to cycle. All retain 24 bands.

[MeterVisualizerSettingsCadenceRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+128*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]
ToolTipText=Previous/next: Suite, 33 ms, 50 ms, 100 ms. Click the value to cycle. Suite follows the shared spectrum interval.

[MeterVisualizerSettingsCadenceLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+130*#Scale#)
W=(70*#Scale#)
Text=Interval
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]
ToolTipText=Previous/next: Suite, 33 ms, 50 ms, 100 ms. Click the value to cycle. Suite follows the shared spectrum interval.

[MeterVisualizerSettingsCadencePrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Cadence',-1)"]
ToolTipText=Previous/next: Suite, 33 ms, 50 ms, 100 ms. Click the value to cycle. Suite follows the shared spectrum interval.

[MeterVisualizerSettingsCadenceValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+129*#Scale#)
W=#VisualizerSettingsValueWidth#
MeasureName=MeasureVisualizerSettingsCadenceValue
Text=%1
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Cadence')"]
ToolTipText=Previous/next: Suite, 33 ms, 50 ms, 100 ms. Click the value to cycle. Suite follows the shared spectrum interval.

[MeterVisualizerSettingsCadenceNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+129*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Cadence',1)"]
ToolTipText=Previous/next: Suite, 33 ms, 50 ms, 100 ms. Click the value to cycle. Suite follows the shared spectrum interval.

[MeterVisualizerSettingsSensitivityRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+188*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]
ToolTipText=Arrows: 10, 20, 35, 50, 65, 80 dB, stopping at the ends. Click to type a whole number from 10 to 80. Sets the spectrum dB range from minus this value to 0; the axis midpoint follows automatically. Does not change system volume.

[MeterVisualizerSettingsSensitivityLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+190*#Scale#)
W=(70*#Scale#)
Text=Sensitivity
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]
ToolTipText=Arrows: 10, 20, 35, 50, 65, 80 dB, stopping at the ends. Click to type a whole number from 10 to 80. Sets the spectrum dB range from minus this value to 0; the axis midpoint follows automatically. Does not change system volume.

[MeterVisualizerSettingsSensitivityPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+189*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Sensitivity',-1)"]
ToolTipText=Arrows: 10, 20, 35, 50, 65, 80 dB, stopping at the ends. Click to type a whole number from 10 to 80. Sets the spectrum dB range from minus this value to 0; the axis midpoint follows automatically. Does not change system volume.

[MeterVisualizerSettingsSensitivityValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+189*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerSensitivity# dB
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Sensitivity')"]
ToolTipText=Arrows: 10, 20, 35, 50, 65, 80 dB, stopping at the ends. Click to type a whole number from 10 to 80. Sets the spectrum dB range from minus this value to 0; the axis midpoint follows automatically. Does not change system volume.

[MeterVisualizerSettingsSensitivityNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+189*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Sensitivity',1)"]
ToolTipText=Arrows: 10, 20, 35, 50, 65, 80 dB, stopping at the ends. Click to type a whole number from 10 to 80. Sets the spectrum dB range from minus this value to 0; the axis midpoint follows automatically. Does not change system volume.

[MeterVisualizerSettingsAttackRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+216*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]
ToolTipText=Arrows: 0, 50, 100, 200, 2000 ms, stopping at the ends. Click to type a whole number from 0 to 2000.

[MeterVisualizerSettingsAttackLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+218*#Scale#)
W=(70*#Scale#)
Text=Attack
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]
ToolTipText=Arrows: 0, 50, 100, 200, 2000 ms, stopping at the ends. Click to type a whole number from 0 to 2000.

[MeterVisualizerSettingsAttackPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Attack',-1)"]
ToolTipText=Arrows: 0, 50, 100, 200, 2000 ms, stopping at the ends. Click to type a whole number from 0 to 2000.

[MeterVisualizerSettingsAttackValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+217*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerAttack# ms
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Attack')"]
ToolTipText=Arrows: 0, 50, 100, 200, 2000 ms, stopping at the ends. Click to type a whole number from 0 to 2000.

[MeterVisualizerSettingsAttackNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+217*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Attack',1)"]
ToolTipText=Arrows: 0, 50, 100, 200, 2000 ms, stopping at the ends. Click to type a whole number from 0 to 2000.

[MeterVisualizerSettingsDecayRow]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#)
Y=(#Inset#+244*#Scale#)
W=#VisualizerSettingsValueWidth#
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#VisualizerSettingsValueWidth#-#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]
ToolTipText=Arrows: 0, 100, 250, 500, 1000, 5000 ms, stopping at the ends. Click to type a whole number from 0 to 5000.

[MeterVisualizerSettingsDecayLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleVisualizerSettingsUI
X=#VisualizerSettingsRightX#
Y=(#Inset#+246*#Scale#)
W=(70*#Scale#)
Text=Decay
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]
ToolTipText=Arrows: 0, 100, 250, 500, 1000, 5000 ms, stopping at the ends. Click to type a whole number from 0 to 5000.

[MeterVisualizerSettingsDecayPrevious]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+85*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Decay',-1)"]
ToolTipText=Arrows: 0, 100, 250, 500, 1000, 5000 ms, stopping at the ends. Click to type a whole number from 0 to 5000.

[MeterVisualizerSettingsDecayValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+96*#Scale#+#VisualizerSettingsValueWidth#/2)
Y=(#Inset#+245*#Scale#)
W=#VisualizerSettingsValueWidth#
Text=#VisualizerDecay# ms
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Activate('Decay')"]
ToolTipText=Arrows: 0, 100, 250, 500, 1000, 5000 ms, stopping at the ends. Click to type a whole number from 0 to 5000.

[MeterVisualizerSettingsDecayNext]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleVisualizerSettingsUI
X=(#VisualizerSettingsRightX#+#VisualizerSettingsColumnWidth#-9*#Scale#)
Y=(#Inset#+245*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureVisualizerSettings "Step('Decay',1)"]
ToolTipText=Arrows: 0, 100, 250, 500, 1000, 5000 ms, stopping at the ends. Click to type a whole number from 0 to 5000.

[MeterVisualizerSettingsAdvanced]
Meter=String
MeterStyle=StyleButton | StyleVisualizerSettingsCommand | StyleVisualizerSettingsUI
X=(#ContentX#+#VisualizerSettingsColumnWidth#/4)
Y=(#Inset#+300*#Scale#)
W=(#VisualizerSettingsColumnWidth#/2-2*#Scale#)
Text=Advanced
LeftMouseUpAction=["notepad.exe" "#@#User\Visualizer.inc"]
ToolTipText=Edit the local output-device ID, quiet threshold and custom appearance or smoothing values in Visualizer options. Save, then click Reconnect to apply.

[MeterVisualizerSettingsReconnect]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton | StyleVisualizerSettingsCommand | StyleVisualizerSettingsUI
X=(#ContentX#+3*#VisualizerSettingsColumnWidth#/4)
Y=(#Inset#+300*#Scale#)
W=(#VisualizerSettingsColumnWidth#/2-2*#Scale#)
Text=Reconnect
LeftMouseUpAction=[!Refresh "Parallax\Visualizer"][!Refresh]
ToolTipText=Refresh the loaded Visualizer to reconnect its selected output and apply saved options. This does not load a stopped Visualizer.

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
