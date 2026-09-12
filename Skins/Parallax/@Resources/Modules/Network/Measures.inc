; All interface selectors use the same setting and are reread every second.
[MeasureNetworkAlias]
Measure=SysInfo
SysInfoType=ADAPTER_ALIAS
SysInfoData=#NetworkInterface#
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkDescription]
Measure=SysInfo
SysInfoType=ADAPTER_DESCRIPTION
SysInfoData=#NetworkInterface#
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkGuid]
Measure=SysInfo
SysInfoType=ADAPTER_GUID
SysInfoData=#NetworkInterface#
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkStatus]
Measure=SysInfo
SysInfoType=ADAPTER_STATUS
SysInfoData=#NetworkInterface#
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkState]
Measure=SysInfo
SysInfoType=ADAPTER_STATE
SysInfoData=#NetworkInterface#
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkIn]
Measure=NetIn
Interface=#NetworkInterface#
UseBits=1
Cumulative=0
UpdateDivider=1
DynamicVariables=1

[MeasureNetworkOut]
Measure=NetOut
Interface=#NetworkInterface#
UseBits=1
Cumulative=0
UpdateDivider=1
DynamicVariables=1

; Defined after native measures so presentation sees this update's samples.
[MeasureNetworkController]
Measure=Script
ScriptFile=#@#Modules\Network\Network.lua
CoreFile=#@#Modules\Network\Core.lua
GraphWidth=#ContentWidth#
GraphHeight=(#NetworkGraphHeight#*#Scale#)
GraphScale=#Scale#
UpdateDivider=1
