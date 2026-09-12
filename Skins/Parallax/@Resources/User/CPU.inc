; CPU-owned persistent settings. Refresh CPU after manual edits.
[Variables]
Columns=1
; Minimum logical height. Visible sections determine the actual height.
PanelHeight=80
; 1 fits every detected logical processor on one page and grows the panel.
CPUAutoRows=1
; Used only with CPUAutoRows=0: 1..64 logical processors per page.
CPUCoresPerPage=8
CPUPage=1
; 0 uses the detected count. Positive values can only reduce that count.
CPUCoreLimit=0
CPUShowInfo=1
CPUShowCores=1
CPUShowProcesses=1
; Number of ranked process names, 1..10. Same-name instances are grouped.
CPUProcessCount=5
CPUShowHistory=1
; Rolling samples, 10..300. Endpoint seconds = (samples-1) * MetricsInterval / 1000.
CPUHistorySamples=60
CPUDecimals=0

; HWiNFO Gadget exports: discovered on load or Reconnect in CPU Settings.
; These are shared CPU/package readings, not individual logical-core sensors.
CPUSensorsEnabled=1
; Auto, HKCU, or HKLM. -1 selects a uniquely identified exported reading.
CPUSensorHive=Auto
CPUTemperatureIndex=-1
CPUVoltageIndex=12
