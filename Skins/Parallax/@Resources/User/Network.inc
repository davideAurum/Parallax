; Preserved module choices. Edit, save, then refresh loaded Network/Connection panels.
[Variables]
Columns=1
PanelHeight=236
; Best, an exact adapter alias/description, or a positive interface index.
; Best prefers wired over wireless. Index 0 / aggregate mode is not supported.
NetworkInterface=Best
; bits uses decimal bit/s; bytes uses binary B/s, KiB/s, MiB/s.
NetworkUnits=bits
; Independent fixed graph ceilings in decimal Mbit/s, regardless of display units.
; Positive plain numbers only. These are graph scales, not measured link speeds.
NetworkInCeilingMbps=100
NetworkOutCeilingMbps=25

; Matching Connection companion: independent width, shared adapter and appearance.
NetworkConnectionColumns=1
NetworkConnectionHeight=236
; This only enables module queries; it never turns the Windows Wi-Fi radio on/off.
NetworkWiFiEnabled=1
; Native WLAN list position, NOT NetworkInterface / Windows IfIndex.
; Use 0 normally. Digits 0..63 only; higher-than-present indexes may fall back to 0.
; Verify the displayed SSID when using multiple Wi-Fi adapters.
NetworkWiFiInterface=0
