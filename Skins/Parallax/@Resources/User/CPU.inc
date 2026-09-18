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
; Fan rows are independently collapsible while Processor info is visible.
CPUShowFan=1
CPUShowMotherboardFan=1
CPUShowCores=1
CPUShowProcesses=1
; Number of ranked process names, 1..10. Same-name instances are grouped.
CPUProcessCount=5
CPUShowHistory=1
; Graph source: 0 = overall CPU utilization, 1 = individual logical threads.
CPUHistorySource=1
; CPU Meter refresh cadence in milliseconds: 500, 1000, or 2000.
CPUUpdateInterval=1000
; HWiNFO registry-read target in milliseconds: 500, 1000, 2000, or 5000.
; The actual rate cannot be faster than CPUUpdateInterval.
CPUSensorInterval=2000
; Rolling samples, 10..300. Endpoint seconds = (samples-1) * CPUUpdateInterval / 1000.
CPUHistorySamples=60
CPUDecimals=1
; HWiNFO display precision. Voltage supports 0..3 decimal places; temperature supports 0..1.
CPUVoltageDecimals=2
CPUTemperatureDecimals=0
; Advertised turbo boost limit for this CPU. This configured spec is not a live clock reading.
CPUTurboClock=4.60 GHz
; Optional CPUThreadColor1 through CPUThreadColor64 values are saved by Thread Colors.
; They use opaque R,G,B values; absent entries use the bounded module palette.

; HWiNFO Gadget exports: discovered on load or Reconnect in CPU Settings.
; Individual physical-core sensors and a separate CPU-wide summary.
CPUSensorsEnabled=1
; Auto, HKCU, or HKLM. -1 selects a uniquely identified exported reading.
CPUSensorHive=Auto
CPUTemperatureIndex=-1
CPUVoltageIndex=-1
