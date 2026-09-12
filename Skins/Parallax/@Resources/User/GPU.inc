; GPU settings are preserved as [Variables] values during package upgrades.
; The GPU gear opens its independent settings utility. Choices save immediately.
; Advanced file edits need a refresh. No provider is enabled by mapping alone.
; Right-click GPU > GPU mapping guide opens the bundled setup instructions.
[Variables]
Columns=1
PanelHeight=288
GPUEnableSensors=0
GPURegHKey=HKEY_CURRENT_USER
GPURegKey=SOFTWARE\HWiNFO64\VSB
; -1 means unmapped. Indices depend on this computer's Gadget export selection.
; Copy the EXACT SensorN and LabelN strings for each chosen Index N.
GPUTemperatureIndex=-1
GPUTemperatureSensor=
GPUTemperatureLabel=
GPUPowerIndex=-1
GPUPowerSensor=
GPUPowerLabel=
GPUClockIndex=-1
GPUClockSensor=
GPUClockLabel=
