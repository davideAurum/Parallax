; Original compact controls for the independent Drive I/O settings utility.
; Fixed actions call validated presets; saved labels never form commands.

[IOStyleSettingsText]
FontFace=#FontFace#
FontSize=(#FontSize#*#Scale#)
FontWeight=500
FontColor=#TextColor#
AntiAlias=1
ClipString=1
X=#ContentX#
W=#IOSettingsCellW#
H=(18*#Scale#)
Group=IOSettingsUI

[IOStyleSettingsButton]
FontColor=#AccentColor#
MouseActionCursor=1

[IOStyleSettingsClickable]
MouseActionCursor=1

[IOStyleSettingsMetadata]
FontSize=((#FontSize#-1)*#Scale#)
FontColor=#MutedColor#

[IOStyleSettingsSection]
FontSize=(#HeaderFontSize#*#Scale#)
FontColor=#HeaderTextColor#
FontWeight=600

[MeterIOSettingsTitle]
Meter=String
MeterStyle=StyleTitle
X=#ContentX#
Y=(#Inset#+6*#Scale#)
W=(#ContentWidth#-26*#Scale#)
H=(20*#Scale#)
Text=Drive I/O Settings
Group=IOSettingsUI

[MeterIOSettingsClose]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton|StyleSecondaryButton
X=(#ContentX#+#ContentWidth#-18*#Scale#)
Y=(#Inset#+6*#Scale#)
W=(18*#Scale#)
Text=X
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Close()"]
ToolTipText=Close only these settings. Drive I/O remains loaded; saved choices remain active.

[MeterIOSettingsSubtitle]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=#ContentX#
Y=(#Inset#+27*#Scale#)
W=#ContentWidth#
H=(16*#Scale#)
Text=Capacity drives and optional transfer counters

[MeterIOSettingsCapacitySection]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsSection
X=#ContentX#
Y=(#Inset#+46*#Scale#)
Text=Capacity

[MeterIOSettingsTransfersSection]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsSection
X=#IOSettingsRightX#
Y=(#Inset#+46*#Scale#)
Text=Transfers

[MeterIOSettingsDrive1Label]
Meter=String
MeterStyle=IOStyleSettingsText
X=#ContentX#
Y=(#Inset#+68*#Scale#)
W=(#IOSettingsCellW#-102*#Scale#)
Text=Main drive

[MeterIOSettingsDrive1Previous]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#-98*#Scale#)
Y=(#Inset#+68*#Scale#)
W=(18*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleDrive(1,-1)"]
ToolTipText=Choose the main capacity drive letter. Arrows cycle A: to Z:. Custom volume roots can be set with Edit file.

[MeterIOSettingsDrive1Value]
Meter=String
MeterStyle=IOStyleSettingsText
X=(#ContentX#+#IOSettingsCellW#-22*#Scale#)
Y=(#Inset#+68*#Scale#)
W=(54*#Scale#)
StringAlign=Right
Text=...
ToolTipText=Choose the main capacity drive letter. Arrows cycle A: to Z:. Custom volume roots can be set with Edit file.

[MeterIOSettingsDrive1Next]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#-18*#Scale#)
Y=(#Inset#+68*#Scale#)
W=(18*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleDrive(1,1)"]
ToolTipText=Choose the main capacity drive letter. Arrows cycle A: to Z:. Custom volume roots can be set with Edit file.

[MeterIOSettingsDrive2Label]
Meter=String
MeterStyle=IOStyleSettingsText
X=#ContentX#
Y=(#Inset#+92*#Scale#)
W=(#IOSettingsCellW#-102*#Scale#)
Text=Second

[MeterIOSettingsDrive2Previous]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#-98*#Scale#)
Y=(#Inset#+92*#Scale#)
W=(18*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleDrive(2,-1)"]
ToolTipText=Choose the second capacity drive letter. Enable its row below. A missing drive remains unavailable.

[MeterIOSettingsDrive2Value]
Meter=String
MeterStyle=IOStyleSettingsText
X=(#ContentX#+#IOSettingsCellW#-22*#Scale#)
Y=(#Inset#+92*#Scale#)
W=(54*#Scale#)
StringAlign=Right
Text=...
ToolTipText=Choose the second capacity drive letter. Enable its row below. A missing drive remains unavailable.

[MeterIOSettingsDrive2Next]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#-18*#Scale#)
Y=(#Inset#+92*#Scale#)
W=(18*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleDrive(2,1)"]
ToolTipText=Choose the second capacity drive letter. Enable its row below. A missing drive remains unavailable.

[MeterIOSettingsSecondLabel]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsClickable
X=#ContentX#
Y=(#Inset#+116*#Scale#)
W=(#IOSettingsCellW#-78*#Scale#)
Text=Show second
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IOShowDrive2')"]
ToolTipText=Enable or disable the second capacity row and its native drive measures.

[MeterIOSettingsSecondValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#)
Y=(#Inset#+116*#Scale#)
W=(70*#Scale#)
StringAlign=Right
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IOShowDrive2')"]
ToolTipText=Enable or disable the second capacity row and its native drive measures.

[MeterIOSettingsRemovableLabel]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsClickable
X=#ContentX#
Y=(#Inset#+140*#Scale#)
W=(#IOSettingsCellW#-78*#Scale#)
Text=Removable
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IOIgnoreRemovable')"]
ToolTipText=Include or ignore removable drives. Optical capacity remains unsupported.

[MeterIOSettingsRemovableValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#)
Y=(#Inset#+140*#Scale#)
W=(70*#Scale#)
StringAlign=Right
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IOIgnoreRemovable')"]
ToolTipText=Include or ignore removable drives. Optical capacity remains unsupported.

[MeterIOSettingsQuotaLabel]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsClickable
X=#ContentX#
Y=(#Inset#+164*#Scale#)
W=(#IOSettingsCellW#-78*#Scale#)
Text=Disk quotas
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IODiskQuota')"]
ToolTipText=On: respect the current user's Windows disk quota. Off: use whole-volume capacity.

[MeterIOSettingsQuotaValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+#IOSettingsCellW#)
Y=(#Inset#+164*#Scale#)
W=(70*#Scale#)
StringAlign=Right
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Toggle('IODiskQuota')"]
ToolTipText=On: respect the current user's Windows disk quota. Off: use whole-volume capacity.

[MeterIOSettingsUnitsLabel]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsClickable
X=#IOSettingsRightX#
Y=(#Inset#+68*#Scale#)
W=(#IOSettingsCellW#-78*#Scale#)
Text=Rate units
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]
ToolTipText=Bytes use binary B/s, KiB/s and MiB/s. Bits use decimal bit/s, kbit/s and Mbit/s. Capacity always uses binary bytes.

[MeterIOSettingsUnitsValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+#IOSettingsCellW#)
Y=(#Inset#+68*#Scale#)
W=(70*#Scale#)
StringAlign=Right
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleUnits()"]
ToolTipText=Bytes use binary B/s, KiB/s and MiB/s. Bits use decimal bit/s, kbit/s and Mbit/s. Capacity always uses binary bytes.

[MeterIOSettingsCategoryLabel]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsClickable
X=#IOSettingsRightX#
Y=(#Inset#+92*#Scale#)
W=(#IOSettingsCellW#-78*#Scale#)
Text=Category
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleCategory()"]
ToolTipText=Switch PhysicalDisk or LogicalDisk. The exact instance is preserved: choose All, Main, Second, or edit a matching custom Perfmon name.

[MeterIOSettingsCategoryValue]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+#IOSettingsCellW#)
Y=(#Inset#+92*#Scale#)
W=(70*#Scale#)
StringAlign=Right
Text=...
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleCategory()"]
ToolTipText=Switch PhysicalDisk or LogicalDisk. The exact instance is preserved: choose All, Main, Second, or edit a matching custom Perfmon name.

[MeterIOSettingsLimitLabel]
Meter=String
MeterStyle=IOStyleSettingsText
X=#IOSettingsRightX#
Y=(#Inset#+116*#Scale#)
W=(#IOSettingsCellW#-102*#Scale#)
Text=MiB/s cap

[MeterIOSettingsLimitPrevious]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+#IOSettingsCellW#-98*#Scale#)
Y=(#Inset#+116*#Scale#)
W=(18*#Scale#)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(-1)"]
ToolTipText=Cycle fixed per-direction graph ceilings: 10, 50, 100, 250, 500, 1000, 2000 or 5000 MiB/s. Custom limits are preserved until changed.

[MeterIOSettingsLimitValue]
Meter=String
MeterStyle=IOStyleSettingsText
X=(#IOSettingsRightX#+#IOSettingsCellW#-22*#Scale#)
Y=(#Inset#+116*#Scale#)
W=(54*#Scale#)
StringAlign=Right
Text=...
ToolTipText=Cycle fixed per-direction graph ceilings: 10, 50, 100, 250, 500, 1000, 2000 or 5000 MiB/s. Custom limits are preserved until changed.

[MeterIOSettingsLimitNext]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+#IOSettingsCellW#-18*#Scale#)
Y=(#Inset#+116*#Scale#)
W=(18*#Scale#)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "CycleLimit(1)"]
ToolTipText=Cycle fixed per-direction graph ceilings: 10, 50, 100, 250, 500, 1000, 2000 or 5000 MiB/s. Custom limits are preserved until changed.

[MeterIOSettingsInstanceLabel]
Meter=String
MeterStyle=IOStyleSettingsText
X=#IOSettingsRightX#
Y=(#Inset#+140*#Scale#)
Text=Exact disk instance

[MeterIOSettingsInstanceValue]
Meter=String
MeterStyle=IOStyleSettingsText
X=#IOSettingsRightX#
Y=(#Inset#+158*#Scale#)
W=#IOSettingsCellW#
Text=...
ToolTipText=Exact Perfmon instance. Use Edit file for a custom physical disk name.

[MeterIOSettingsInstanceAll]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#IOSettingsRightX#
Y=(#Inset#+182*#Scale#)
W=(38*#Scale#)
Text=All
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "UseTotal()"]
ToolTipText=Select _Total in the current category. Capacity drive rows are independent.

[MeterIOSettingsInstanceMain]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+46*#Scale#)
Y=(#Inset#+182*#Scale#)
W=(48*#Scale#)
Text=Main
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "UseCapacityDrive(1)"]
ToolTipText=Select LogicalDisk and the main capacity drive letter. Custom roots require an exact instance in Edit file.

[MeterIOSettingsInstanceSecond]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#IOSettingsRightX#+102*#Scale#)
Y=(#Inset#+182*#Scale#)
W=(#IOSettingsCellW#-102*#Scale#)
Text=Second
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "UseCapacityDrive(2)"]
ToolTipText=Select LogicalDisk and the second capacity drive letter, even when its capacity row is hidden.

[MeterIOSettingsCustomHint]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=#ContentX#
Y=(#Inset#+208*#Scale#)
W=#ContentWidth#
H=(16*#Scale#)
FontColor=#MutedColor#
Text=Custom instance/root: Edit file, then Reload.
ToolTipText=Open IO.inc for exact Perfmon instance names, custom volume roots or graph limits. Save, then click Reload; only Drive I/O and these settings refresh.

[MeterIOSettingsNative]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#ContentX#
Y=(#Inset#+230*#Scale#)
W=#IOSettingsCellW#
Text=Load native capacity
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Activate('native')"]
ToolTipText=Load IO.ini: native capacity only. Removes this display's UsageMonitor queries; another skin may still use the same category worker.

[MeterIOSettingsCounters]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=#IOSettingsRightX#
Y=(#Inset#+230*#Scale#)
W=#IOSettingsCellW#
Text=Load disk counters
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Activate('counters')"]
ToolTipText=Load IO-Disk.ini: native capacity plus optional UsageMonitor disk read/write counters. Adds an independent 1 Hz category worker.

[MeterIOSettingsEditFile]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton|StyleSecondaryButton
X=#ContentX#
Y=(#Inset#+254*#Scale#)
W=(70*#Scale#)
Text=Edit file
LeftMouseUpAction=["notepad.exe" "#@#User\IO.inc"]
ToolTipText=Edit advanced IO.inc values in Notepad. Save and click Reload. No input text is embedded in a Rainmeter action.

[MeterIOSettingsReload]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsButton
X=(#ContentX#+82*#Scale#)
Y=(#Inset#+254*#Scale#)
W=(62*#Scale#)
Text=Reload
LeftMouseUpAction=[!CommandMeasure MeasureIOSettings "Apply()"]
ToolTipText=Read manual file edits by refreshing only the Drive I/O group and this settings utility.

[MeterIOSettingsProviderHint]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=#IOSettingsRightX#
Y=(#Inset#+254*#Scale#)
W=#IOSettingsCellW#
FontColor=#MutedColor#
Text=Zero / age may be unknown
ToolTipText=UsageMonitor cannot prove freshness or distinguish zero activity from unavailable counters. The display preserves those limitations.

[MeterIOSettingsNotice]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=#ContentX#
Y=(#Inset#+280*#Scale#)
W=#ContentWidth#
H=(16*#Scale#)
FontColor=#MutedColor#
Text=Changes save immediately.

[MeterIOSettingsIndependence]
Meter=String
MeterStyle=IOStyleSettingsText|IOStyleSettingsMetadata
X=#ContentX#
Y=(#Inset#+302*#Scale#)
W=#ContentWidth#
H=(16*#Scale#)
FontColor=#MutedColor#
Text=Close settings independently of Drive I/O.
