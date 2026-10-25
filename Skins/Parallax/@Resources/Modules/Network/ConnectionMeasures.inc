; Adapter metadata stays on the same selector as Network's traffic measures.
; Alias, description, GUID, status and state come from Network's identical
; MeasureNetwork* bank (Measures.inc, earlier in update order); the controller
; samples them on this bank's ticks so the section stays one 2 s snapshot.
[MeasureConnectionType]
Measure=SysInfo
Group=ParallaxIdlePause
SysInfoType=ADAPTER_TYPE
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

; Native Internet status is PC-wide; SysInfoData cannot scope it to one adapter.
[MeasureConnectionInternet]
Measure=SysInfo
Group=ParallaxIdlePause
SysInfoType=INTERNET_CONNECTIVITY
UpdateDivider=2

[MeasureConnectionIP]
Measure=SysInfo
Group=ParallaxIdlePause
SysInfoType=IP_ADDRESS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionGateway]
Measure=SysInfo
Group=ParallaxIdlePause
SysInfoType=GATEWAY_ADDRESS
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionRxLink]
Measure=SysInfo
Group=ParallaxIdlePause
SysInfoType=ADAPTER_RECEIVE_SPEED
SysInfoData=#NetworkInterface#
UpdateDivider=2
DynamicVariables=1

[MeasureConnectionTxLink]
Measure=SysInfo
Group=ParallaxIdlePause
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
Group=ConnectionWiFi|ParallaxIdlePause
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiQuality]
Measure=WiFiStatus
WiFiInfoType=Quality
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi|ParallaxIdlePause
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiPHY]
Measure=WiFiStatus
WiFiInfoType=PHY
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi|ParallaxIdlePause
UpdateDivider=5
DynamicVariables=1

; Installed Rainmeter 4.5.26 converts WLAN's kbit/s to bits/s internally.
[MeasureConnectionWiFiRx]
Measure=WiFiStatus
WiFiInfoType=RXRate
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi|ParallaxIdlePause
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionWiFiTx]
Measure=WiFiStatus
WiFiInfoType=TXRate
WiFiIntfID=0
Disabled=1
Group=ConnectionWiFi|ParallaxIdlePause
UpdateDivider=5
DynamicVariables=1

[MeasureConnectionController]
Measure=Script
Group=ParallaxIdlePause
ScriptFile=#@#Modules\Network\Connection.lua
CoreFile=#@#Modules\Network\Core.lua
ConnectionCoreFile=#@#Modules\Network\ConnectionCore.lua
SignalWidth=#ContentWidth#
SignalHeight=#DataBarThicknessPx#
; Must equal the UpdateDivider of the SysInfo connection bank and of the
; Wi-Fi measures above: the controller only re-derives the view on their ticks.
BankDivider=2
WiFiDivider=5
UpdateDivider=1
