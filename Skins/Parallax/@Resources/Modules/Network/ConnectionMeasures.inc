; Adapter metadata stays on the same selector as Network's traffic measures.
[MeasureConnectionAlias]
Measure=SysInfo
SysInfoType=ADAPTER_ALIAS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionDescription]
Measure=SysInfo
SysInfoType=ADAPTER_DESCRIPTION
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionGuid]
Measure=SysInfo
SysInfoType=ADAPTER_GUID
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionStatus]
Measure=SysInfo
SysInfoType=ADAPTER_STATUS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionState]
Measure=SysInfo
SysInfoType=ADAPTER_STATE
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionType]
Measure=SysInfo
SysInfoType=ADAPTER_TYPE
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

; Native Internet status is PC-wide; SysInfoData cannot scope it to one adapter.
[MeasureConnectionInternet]
Measure=SysInfo
SysInfoType=INTERNET_CONNECTIVITY
UpdateDivider=2

[MeasureConnectionIP]
Measure=SysInfo
SysInfoType=IP_ADDRESS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionGateway]
Measure=SysInfo
SysInfoType=GATEWAY_ADDRESS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionRxLink]
Measure=SysInfo
SysInfoType=ADAPTER_RECEIVE_SPEED
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionTxLink]
Measure=SysInfo
SysInfoType=ADAPTER_TRANSMIT_SPEED
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

; Safe fixed index on initial read. Lua validates settings before enabling queries.
; All native Wi-Fi fields must share one WLAN enumeration index.
[MeasureConnectionWiFiSSID]
Measure=WiFiStatus
WiFiInfoType=SSID
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiQuality]
Measure=WiFiStatus
WiFiInfoType=Quality
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiPHY]
Measure=WiFiStatus
WiFiInfoType=PHY
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi
UpdateDivider=5
DynamicVariables=1

; Installed Rainmeter 4.5.26 converts WLAN's kbit/s to bits/s internally.
[MeasureConnectionWiFiRx]
Measure=WiFiStatus
WiFiInfoType=RXRate
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiTx]
Measure=WiFiStatus
WiFiInfoType=TXRate
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionController]
Measure=Script
ScriptFile=#@#Modules\Network\Connection.lua
CoreFile=#@#Modules\Network\Core.lua
ConnectionCoreFile=#@#Modules\Network\ConnectionCore.lua
SignalWidth=#ContentWidth#
SignalHeight=#DataBarThicknessPx#
UpdateDivider=1
