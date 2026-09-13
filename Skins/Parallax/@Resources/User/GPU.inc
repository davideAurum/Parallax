; GPU settings are preserved as [Variables] values during package upgrades.
; The GPU gear opens its independent settings utility. Choices save immediately.
; Advanced file edits need a refresh. No provider is enabled by mapping alone.
; Right-click GPU > GPU mapping guide opens the bundled setup instructions.
[Variables]
Columns=1
PanelHeight=560
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
