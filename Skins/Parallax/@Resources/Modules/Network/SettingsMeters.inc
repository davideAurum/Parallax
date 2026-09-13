; Independent Network settings: aligned labels and compact value fields.
[StyleNetworkSettingsUI]
Group=NetworkSettingsUI

[MeterNetworkSettingsTitle]
Meter=String
MeterStyle=StyleTitle | StyleTitleRow | StyleNetworkSettingsUI
X=#ContentX#
W=(#ContentWidth#-28*#Scale#)
Text=Network Settings

[MeterNetworkSettingsClose]
Meter=String
MeterStyle=StyleButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#)
Y=#TitleRowCenterY#
W=(18*#Scale#)
H=(18*#Scale#)
StringAlign=RightCenter
Padding=0,0,0,0
Text=X
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "Close()"]
ToolTipText=Close Network Settings independently. Saved choices and Network stay active.

[MeterNetworkSettingsAdapterRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+101*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "OpenFile()"]
ToolTipText=Edit NetworkInterface in the settings file: Best, exact adapter alias/description, or a positive interface index. Save, then Apply saved file. A selected traffic adapter does not choose the separate WLAN source.

[MeterNetworkSettingsAdapterLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+103*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Adapter selector
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "OpenFile()"]
ToolTipText=Edit NetworkInterface in the settings file: Best, exact adapter alias/description, or a positive interface index. Save, then Apply saved file. A selected traffic adapter does not choose the separate WLAN source.

[MeterNetworkSettingsAdapterValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleNetworkSettingsUI
Y=(#Inset#+101*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-156*#Scale#)
H=(18*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
StringAlign=Left
SolidColor=0,0,0,0
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "OpenFile()"]
ToolTipText=Edit NetworkInterface in the settings file: Best, exact adapter alias/description, or a positive interface index. Save, then Apply saved file. A selected traffic adapter does not choose the separate WLAN source.

[MeterNetworkSettingsUnitsRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+129*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsUnitsLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+131*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Traffic units
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleUnits()"]
ToolTipText=Previous or next traffic units; wraps between decimal bits/s and binary bytes/s. Center switches the current choice.

[MeterNetworkSettingsUnitsDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+130*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "CycleUnits(-1)"]
ToolTipText=Previous or next traffic units; wraps between decimal bits/s and binary bytes/s. Center switches the current choice.

[MeterNetworkSettingsUnitsFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+129*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleUnits()"]
ToolTipText=Previous or next traffic units; wraps between decimal bits/s and binary bytes/s. Center switches the current choice.

[MeterNetworkSettingsUnitsValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+130*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleUnits()"]
ToolTipText=Previous or next traffic units; wraps between decimal bits/s and binary bytes/s. Center switches the current choice.

[MeterNetworkSettingsUnitsIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+130*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "CycleUnits(1)"]
ToolTipText=Previous or next traffic units; wraps between decimal bits/s and binary bytes/s. Center switches the current choice.

[MeterNetworkSettingsWidthRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+157*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsWidthLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+159*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Network columns
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('Columns')"]
ToolTipText=Whole columns, 1 or 2. Arrows stop at the limits; click the center to type. This settings window keeps its own width.

[MeterNetworkSettingsWidthDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+158*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('Columns',-1)"]
ToolTipText=Whole columns, 1 or 2. Arrows stop at the limits; click the center to type. This settings window keeps its own width.

[MeterNetworkSettingsWidthFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+157*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('Columns')"]
ToolTipText=Whole columns, 1 or 2. Arrows stop at the limits; click the center to type. This settings window keeps its own width.

[MeterNetworkSettingsWidthValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+158*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('Columns')"]
ToolTipText=Whole columns, 1 or 2. Arrows stop at the limits; click the center to type. This settings window keeps its own width.

[MeterNetworkSettingsWidthIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+158*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('Columns',1)"]
ToolTipText=Whole columns, 1 or 2. Arrows stop at the limits; click the center to type. This settings window keeps its own width.

[MeterNetworkSettingsHeightRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+185*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsHeightLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+187*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Minimum height (px)
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('PanelHeight')"]
ToolTipText=Saved minimum height in logical pixels. Arrows adjust by one pixel and stop at editor limits. Click the center for decimal entry; formulas and other saved custom values remain available through Edit settings file. The monitor grows to fit its content.

[MeterNetworkSettingsHeightDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+186*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('PanelHeight',-1)"]
ToolTipText=Saved minimum height in logical pixels. Arrows adjust by one pixel and stop at editor limits. Click the center for decimal entry; formulas and other saved custom values remain available through Edit settings file. The monitor grows to fit its content.

[MeterNetworkSettingsHeightFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+185*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('PanelHeight')"]
ToolTipText=Saved minimum height in logical pixels. Arrows adjust by one pixel and stop at editor limits. Click the center for decimal entry; formulas and other saved custom values remain available through Edit settings file. The monitor grows to fit its content.

[MeterNetworkSettingsHeightValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+186*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('PanelHeight')"]
ToolTipText=Saved minimum height in logical pixels. Arrows adjust by one pixel and stop at editor limits. Click the center for decimal entry; formulas and other saved custom values remain available through Edit settings file. The monitor grows to fit its content.

[MeterNetworkSettingsHeightIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+186*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('PanelHeight',1)"]
ToolTipText=Saved minimum height in logical pixels. Arrows adjust by one pixel and stop at editor limits. Click the center for decimal entry; formulas and other saved custom values remain available through Edit settings file. The monitor grows to fit its content.

[MeterNetworkSettingsInCeilingRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+242*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsInCeilingLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+244*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Inbound (Mbit/s)
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkInCeilingMbps')"]
ToolTipText=Inbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsInCeilingDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+243*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkInCeilingMbps',-1)"]
ToolTipText=Inbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsInCeilingFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+242*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkInCeilingMbps')"]
ToolTipText=Inbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsInCeilingValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+243*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkInCeilingMbps')"]
ToolTipText=Inbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsInCeilingIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+243*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkInCeilingMbps',1)"]
ToolTipText=Inbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsOutCeilingRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+270*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsOutCeilingLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+272*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Outbound (Mbit/s)
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkOutCeilingMbps')"]
ToolTipText=Outbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsOutCeilingDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+271*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkOutCeilingMbps',-1)"]
ToolTipText=Outbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsOutCeilingFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+270*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkOutCeilingMbps')"]
ToolTipText=Outbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsOutCeilingValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+271*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkOutCeilingMbps')"]
ToolTipText=Outbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsOutCeilingIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+271*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkOutCeilingMbps',1)"]
ToolTipText=Outbound history ceiling in Mbit/s. Arrows choose neighboring presets 10, 25, 50, 100, 250, 500, 1000 without wrapping. Click the center to type a custom positive decimal. This is not measured Internet bandwidth.

[MeterNetworkSettingsWiFiEnabledRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+355*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleWiFi()"]
ToolTipText=Enable or disable this panel's native Wi-Fi queries. This does not turn the Windows radio on or off. Saves and refreshes Network.

[MeterNetworkSettingsWiFiEnabledLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+357*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=Wi-Fi queries
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleWiFi()"]
ToolTipText=Enable or disable this panel's native Wi-Fi queries. This does not turn the Windows radio on or off. Saves and refreshes Network.

[MeterNetworkSettingsWiFiEnabledValue]
Meter=String
MeterStyle=StyleUtilitySettingsValue | StyleNetworkSettingsUI
Y=(#Inset#+355*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-156*#Scale#)
H=(18*#Scale#)
Padding=(3*#Scale#),#Scale#,(3*#Scale#),#Scale#
StringAlign=Left
SolidColor=0,0,0,0
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ToggleWiFi()"]
ToolTipText=Enable or disable this panel's native Wi-Fi queries. This does not turn the Windows radio on or off. Saves and refreshes Network.

[MeterNetworkSettingsWiFiIndexRow]
Meter=Shape
MeterStyle=StyleUtilitySettingsRow | StyleNetworkSettingsUI
Y=(#Inset#+383*#Scale#)
X=(#ContentX#+150*#Scale#)
W=(#ContentWidth#-150*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(#ContentWidth#-150*#Scale#),(20*#Scale#) | Fill Color #GraphBackgroundColor# | StrokeWidth 0
; Backing is passive. Labels and separated controls declare their own hit targets.

[MeterNetworkSettingsWiFiIndexLabel]
Meter=String
MeterStyle=StyleUtilitySettingsLabel | StyleNetworkSettingsUI
Y=(#Inset#+385*#Scale#)
X=#ContentX#
W=(144*#Scale#)
H=(18*#Scale#)
Padding=0,0,0,0
Text=WLAN source index
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkWiFiInterface')"]
ToolTipText=Whole WLAN list position, 0 through 63. Arrows stop at the limits; click the center to type. This is separate from the traffic adapter; a nonexistent native index may fall back to 0. Verify the SSID. Query-off source controls remain available.

[MeterNetworkSettingsWiFiIndexDecrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+159*#Scale#)
Y=(#Inset#+384*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkWiFiInterface',-1)"]
ToolTipText=Whole WLAN list position, 0 through 63. Arrows stop at the limits; click the center to type. This is separate from the traffic adapter; a nonexistent native index may fall back to 0. Verify the SSID. Query-off source controls remain available.

[MeterNetworkSettingsWiFiIndexFrame]
Meter=Shape
MeterStyle=StyleSettingsStepperFrame | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#)
Y=(#Inset#+383*#Scale#)
W=(#ContentWidth#-194*#Scale#)
H=(20*#Scale#)
Shape=Rectangle (#Scale#/2),(#Scale#/2),(#ContentWidth#-195*#Scale#),(19*#Scale#),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth #Scale#
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkWiFiInterface')"]
ToolTipText=Whole WLAN list position, 0 through 63. Arrows stop at the limits; click the center to type. This is separate from the traffic adapter; a nonexistent native index may fall back to 0. Verify the SSID. Query-off source controls remain available.

[MeterNetworkSettingsWiFiIndexValue]
Meter=String
MeterStyle=StyleSettingsStepperValue | StyleNetworkSettingsUI
X=(#ContentX#+172*#Scale#+(#ContentWidth#-194*#Scale#)/2)
Y=(#Inset#+384*#Scale#)
W=(#ContentWidth#-200*#Scale#)
H=(18*#Scale#)
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "BeginNumberInput('NetworkWiFiInterface')"]
ToolTipText=Whole WLAN list position, 0 through 63. Arrows stop at the limits; click the center to type. This is separate from the traffic adapter; a nonexistent native index may fall back to 0. Verify the SSID. Query-off source controls remain available.

[MeterNetworkSettingsWiFiIndexIncrease]
Meter=String
MeterStyle=StyleSettingsStepperButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#-9*#Scale#)
Y=(#Inset#+384*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "AdjustNumber('NetworkWiFiInterface',1)"]
ToolTipText=Whole WLAN list position, 0 through 63. Arrows stop at the limits; click the center to type. This is separate from the traffic adapter; a nonexistent native index may fall back to 0. Verify the SSID. Query-off source controls remain available.

[MeterNetworkSettingsTrafficSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleNetworkSettingsUI
Y=(#Inset#+74*#Scale#)
Text=Traffic display

[MeterNetworkSettingsTrafficRule]
Meter=Shape
MeterStyle=StyleRule | StyleNetworkSettingsUI
Y=(#Inset#+95*#Scale#)

[MeterNetworkSettingsHistorySection]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleNetworkSettingsUI
Y=(#Inset#+215*#Scale#)
Text=History scales

[MeterNetworkSettingsHistoryRule]
Meter=Shape
MeterStyle=StyleRule | StyleNetworkSettingsUI
Y=(#Inset#+236*#Scale#)

[MeterNetworkSettingsWiFiSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleNetworkSettingsUI
Y=(#Inset#+328*#Scale#)
Text=Wi-Fi source

[MeterNetworkSettingsWiFiRule]
Meter=Shape
MeterStyle=StyleRule | StyleNetworkSettingsUI
Y=(#Inset#+349*#Scale#)

[MeterNetworkSettingsActionsSection]
Meter=String
MeterStyle=StyleUtilitySettingsSection | StyleNetworkSettingsUI
Y=(#Inset#+459*#Scale#)
Text=Open and apply

[MeterNetworkSettingsActionsRule]
Meter=Shape
MeterStyle=StyleRule | StyleNetworkSettingsUI
Y=(#Inset#+480*#Scale#)

[MeterNetworkSettingsCeilingHint]
Meter=String
MeterStyle=StyleLabel | StyleNetworkSettingsUI
X=#ContentX#
Y=(#Inset#+298*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=Click a number to type its value.
ToolTipText=Type a positive decimal in Mbit/s, up to four decimal places within the editor range. Existing wider, exponent-form or finer-precision saved values remain supported through Edit settings file.

[MeterNetworkSettingsWiFiHint]
Meter=String
MeterStyle=StyleLabel | StyleNetworkSettingsUI
X=#ContentX#
Y=(#Inset#+411*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=WLAN index is separate from the traffic adapter.
ToolTipText=WLAN index is separate from the traffic adapter.

[MeterNetworkSettingsWiFiHint2]
Meter=String
MeterStyle=StyleLabel | StyleNetworkSettingsUI
X=#ContentX#
Y=(#Inset#+429*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=Verify the SSID after changing its source.
ToolTipText=Verify the SSID after changing its source.

[MeterNetworkSettingsStatus]
Meter=String
MeterStyle=StyleLabel | StyleNetworkSettingsUI
X=#ContentX#
Y=(#Inset#+552*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=Changes save immediately. File edits need Apply.
ToolTipText=Changes save immediately. File edits need Apply.

[MeterNetworkSettingsIndependence]
Meter=String
MeterStyle=StyleLabel | StyleNetworkSettingsUI
X=#ContentX#
Y=(#Inset#+570*#Scale#)
W=#ContentWidth#
H=(18*#Scale#)
Text=Closing settings leaves Network running.
ToolTipText=Closing settings leaves Network running.

[MeterNetworkSettingsOpenNetwork]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton | StyleNetworkSettingsUI
X=(#ContentX#+#ContentWidth#/2)
Y=(#Inset#+498*#Scale#)
W=#ContentWidth#
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=CenterCenter
SolidColor=#GraphBackgroundColor#
Text=Show Network
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "OpenPanel('Network')"]
ToolTipText=Open the combined Network monitor without closing settings.

[MeterNetworkSettingsOpenFile]
Meter=String
MeterStyle=StyleButton | StyleSecondaryButton | StyleNetworkSettingsUI
X=(#ContentX#+0*((#ContentWidth#-4*#Scale#)/2+4*#Scale#)+(#ContentWidth#-4*#Scale#)/4)
Y=(#Inset#+530*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=CenterCenter
SolidColor=#GraphBackgroundColor#
Text=Edit settings file
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "OpenFile()"]
ToolTipText=Open Network.inc for a custom adapter, ceiling, WLAN index or saved height. Save it, then use Apply saved file.

[MeterNetworkSettingsApplyFile]
Meter=String
MeterStyle=StyleButton | StyleNetworkSettingsUI
X=(#ContentX#+1*((#ContentWidth#-4*#Scale#)/2+4*#Scale#)+(#ContentWidth#-4*#Scale#)/4)
Y=(#Inset#+530*#Scale#)
W=((#ContentWidth#-4*#Scale#)/2)
H=(24*#Scale#)
Padding=0,0,0,0
StringAlign=CenterCenter
SolidColor=#GraphBackgroundColor#
Text=Apply saved file
LeftMouseUpAction=[!CommandMeasure MeasureNetworkSettings "ApplyFile()"]
ToolTipText=Request a refresh of Network and this settings window. Network history restarts if loaded; an unopened monitor stays closed.
