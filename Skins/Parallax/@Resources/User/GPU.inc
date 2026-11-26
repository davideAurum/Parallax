; GPU settings are preserved as [Variables] values during package upgrades.
; The GPU gear opens its independent settings utility. Choices save immediately.
; Advanced file edits need a refresh. No provider is enabled by mapping alone.
; Right-click GPU > GPU mapping guide opens the bundled setup instructions.
[Variables]
Columns=1
; Minimum monitor height. 462 is the natural height of the current layout
; (Fit); larger values add space below the history graph. 650 was the Fit
; value of the previous layout and is still treated as Fit.
PanelHeight=462
; Process table (the five busiest GPU processes): 1 shows it; 0 hides it and
; loads none of its UsageMonitor measures, so Windows' GPU Engine and GPU
; Process Memory counters are not read at all, and a fitted panel shortens.
GPUShowProcesses=1
; The table's VRAM column: 0 hides it and loads none of its GPU Process
; Memory measures; the GPU % column is unaffected.
GPUShowProcessMemory=1
; Main GPU, the one the header, Engine table and History follow: 0 Auto
; (the first discrete GPU in Windows' high-performance order, else the first
; integrated one), 1 Integrated, 2 Discrete. A choice with no matching GPU
; falls back to Auto.
GPUMainGPU=0
; Second GPU, shown only when Windows exposes two hardware GPUs: 0 Off (not
; sampled), 1 One line (name and load), 2 Rows (adds video load and memory
; in use), 3 Rows + history trace (also drawn on the History graph).
GPUSecondGPU=1
GPUEnableSensors=1
; Power/clock source: 0=direct driver (default), 1=explicit HWiNFO override.
; Overrides also require GPUEnableSensors=1 and a valid mapping below.
GPUPowerSource=0
GPUClockSource=0
GPURegHKey=HKEY_CURRENT_USER
GPURegKey=SOFTWARE\HWiNFO64\VSB
; Temperature uses the detected GPU driver independently of GPUEnableSensors.
; Preserve these legacy temperature keys for upgrades; they are unused now.
; -1 means unmapped. Indices depend on this computer's Gadget export selection.
; Copy the EXACT SensorN and LabelN strings for each chosen Index N.
GPUTemperatureIndex=-1
GPUTemperatureSensor=
GPUTemperatureLabel=
; Optional HWiNFO power and live-clock mappings:
GPUPowerIndex=-1
GPUPowerSensor=
GPUPowerLabel=
GPUClockIndex=-1
GPUClockSensor=
GPUClockLabel=
