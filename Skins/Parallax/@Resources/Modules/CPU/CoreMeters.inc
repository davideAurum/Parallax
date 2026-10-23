; Startup slots overlap while hidden. CPU.lua positions only detected, active rows.
; Idle slots keep UpdateDivider=-1 so their hidden meters skip every meter pass.
; CPU.lua sets 1 and forces one update when it binds a slot, which also applies
; values set while it was idle, and sets -1 again when the slot is unbound.

[MeterCoreLabel1]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore1|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar1]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU1
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore1|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue1]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU1
Y=(#Inset#+120*#Scale#)
Group=CPUCore1|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel2]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore2|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar2]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU2
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore2|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue2]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU2
Y=(#Inset#+120*#Scale#)
Group=CPUCore2|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel3]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore3|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar3]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU3
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore3|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue3]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU3
Y=(#Inset#+120*#Scale#)
Group=CPUCore3|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel4]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore4|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar4]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU4
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore4|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue4]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU4
Y=(#Inset#+120*#Scale#)
Group=CPUCore4|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel5]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore5|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar5]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU5
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore5|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue5]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU5
Y=(#Inset#+120*#Scale#)
Group=CPUCore5|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel6]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore6|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar6]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU6
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore6|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue6]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU6
Y=(#Inset#+120*#Scale#)
Group=CPUCore6|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel7]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore7|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar7]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU7
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore7|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue7]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU7
Y=(#Inset#+120*#Scale#)
Group=CPUCore7|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel8]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore8|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar8]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU8
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore8|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue8]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU8
Y=(#Inset#+120*#Scale#)
Group=CPUCore8|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel9]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore9|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar9]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU9
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore9|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue9]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU9
Y=(#Inset#+120*#Scale#)
Group=CPUCore9|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel10]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore10|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar10]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU10
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore10|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue10]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU10
Y=(#Inset#+120*#Scale#)
Group=CPUCore10|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel11]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore11|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar11]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU11
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore11|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue11]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU11
Y=(#Inset#+120*#Scale#)
Group=CPUCore11|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel12]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore12|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar12]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU12
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore12|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue12]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU12
Y=(#Inset#+120*#Scale#)
Group=CPUCore12|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel13]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore13|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar13]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU13
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore13|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue13]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU13
Y=(#Inset#+120*#Scale#)
Group=CPUCore13|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel14]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore14|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar14]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU14
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore14|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue14]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU14
Y=(#Inset#+120*#Scale#)
Group=CPUCore14|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel15]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore15|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar15]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU15
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore15|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue15]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU15
Y=(#Inset#+120*#Scale#)
Group=CPUCore15|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel16]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore16|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar16]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU16
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore16|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue16]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU16
Y=(#Inset#+120*#Scale#)
Group=CPUCore16|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel17]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore17|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar17]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU17
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore17|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue17]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU17
Y=(#Inset#+120*#Scale#)
Group=CPUCore17|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel18]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore18|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar18]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU18
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore18|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue18]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU18
Y=(#Inset#+120*#Scale#)
Group=CPUCore18|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel19]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore19|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar19]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU19
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore19|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue19]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU19
Y=(#Inset#+120*#Scale#)
Group=CPUCore19|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel20]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore20|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar20]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU20
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore20|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue20]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU20
Y=(#Inset#+120*#Scale#)
Group=CPUCore20|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel21]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore21|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar21]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU21
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore21|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue21]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU21
Y=(#Inset#+120*#Scale#)
Group=CPUCore21|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel22]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore22|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar22]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU22
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore22|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue22]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU22
Y=(#Inset#+120*#Scale#)
Group=CPUCore22|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel23]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore23|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar23]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU23
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore23|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue23]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU23
Y=(#Inset#+120*#Scale#)
Group=CPUCore23|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel24]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore24|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar24]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU24
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore24|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue24]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU24
Y=(#Inset#+120*#Scale#)
Group=CPUCore24|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel25]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore25|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar25]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU25
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore25|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue25]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU25
Y=(#Inset#+120*#Scale#)
Group=CPUCore25|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel26]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore26|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar26]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU26
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore26|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue26]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU26
Y=(#Inset#+120*#Scale#)
Group=CPUCore26|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel27]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore27|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar27]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU27
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore27|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue27]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU27
Y=(#Inset#+120*#Scale#)
Group=CPUCore27|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel28]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore28|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar28]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU28
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore28|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue28]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU28
Y=(#Inset#+120*#Scale#)
Group=CPUCore28|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel29]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore29|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar29]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU29
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore29|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue29]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU29
Y=(#Inset#+120*#Scale#)
Group=CPUCore29|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel30]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore30|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar30]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU30
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore30|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue30]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU30
Y=(#Inset#+120*#Scale#)
Group=CPUCore30|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel31]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore31|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar31]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU31
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore31|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue31]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU31
Y=(#Inset#+120*#Scale#)
Group=CPUCore31|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel32]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore32|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar32]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU32
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore32|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue32]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU32
Y=(#Inset#+120*#Scale#)
Group=CPUCore32|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel33]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore33|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar33]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU33
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore33|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue33]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU33
Y=(#Inset#+120*#Scale#)
Group=CPUCore33|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel34]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore34|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar34]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU34
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore34|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue34]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU34
Y=(#Inset#+120*#Scale#)
Group=CPUCore34|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel35]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore35|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar35]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU35
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore35|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue35]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU35
Y=(#Inset#+120*#Scale#)
Group=CPUCore35|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel36]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore36|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar36]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU36
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore36|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue36]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU36
Y=(#Inset#+120*#Scale#)
Group=CPUCore36|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel37]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore37|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar37]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU37
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore37|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue37]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU37
Y=(#Inset#+120*#Scale#)
Group=CPUCore37|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel38]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore38|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar38]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU38
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore38|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue38]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU38
Y=(#Inset#+120*#Scale#)
Group=CPUCore38|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel39]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore39|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar39]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU39
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore39|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue39]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU39
Y=(#Inset#+120*#Scale#)
Group=CPUCore39|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel40]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore40|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar40]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU40
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore40|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue40]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU40
Y=(#Inset#+120*#Scale#)
Group=CPUCore40|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel41]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore41|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar41]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU41
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore41|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue41]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU41
Y=(#Inset#+120*#Scale#)
Group=CPUCore41|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel42]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore42|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar42]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU42
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore42|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue42]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU42
Y=(#Inset#+120*#Scale#)
Group=CPUCore42|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel43]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore43|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar43]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU43
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore43|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue43]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU43
Y=(#Inset#+120*#Scale#)
Group=CPUCore43|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel44]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore44|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar44]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU44
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore44|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue44]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU44
Y=(#Inset#+120*#Scale#)
Group=CPUCore44|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel45]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore45|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar45]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU45
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore45|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue45]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU45
Y=(#Inset#+120*#Scale#)
Group=CPUCore45|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel46]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore46|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar46]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU46
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore46|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue46]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU46
Y=(#Inset#+120*#Scale#)
Group=CPUCore46|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel47]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore47|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar47]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU47
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore47|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue47]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU47
Y=(#Inset#+120*#Scale#)
Group=CPUCore47|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel48]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore48|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar48]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU48
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore48|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue48]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU48
Y=(#Inset#+120*#Scale#)
Group=CPUCore48|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel49]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore49|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar49]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU49
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore49|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue49]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU49
Y=(#Inset#+120*#Scale#)
Group=CPUCore49|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel50]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore50|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar50]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU50
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore50|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue50]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU50
Y=(#Inset#+120*#Scale#)
Group=CPUCore50|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel51]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore51|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar51]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU51
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore51|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue51]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU51
Y=(#Inset#+120*#Scale#)
Group=CPUCore51|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel52]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore52|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar52]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU52
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore52|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue52]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU52
Y=(#Inset#+120*#Scale#)
Group=CPUCore52|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel53]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore53|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar53]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU53
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore53|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue53]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU53
Y=(#Inset#+120*#Scale#)
Group=CPUCore53|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel54]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore54|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar54]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU54
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore54|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue54]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU54
Y=(#Inset#+120*#Scale#)
Group=CPUCore54|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel55]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore55|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar55]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU55
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore55|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue55]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU55
Y=(#Inset#+120*#Scale#)
Group=CPUCore55|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel56]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore56|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar56]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU56
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore56|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue56]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU56
Y=(#Inset#+120*#Scale#)
Group=CPUCore56|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel57]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore57|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar57]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU57
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore57|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue57]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU57
Y=(#Inset#+120*#Scale#)
Group=CPUCore57|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel58]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore58|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar58]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU58
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore58|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue58]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU58
Y=(#Inset#+120*#Scale#)
Group=CPUCore58|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel59]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore59|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar59]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU59
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore59|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue59]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU59
Y=(#Inset#+120*#Scale#)
Group=CPUCore59|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel60]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore60|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar60]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU60
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore60|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue60]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU60
Y=(#Inset#+120*#Scale#)
Group=CPUCore60|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel61]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore61|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar61]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU61
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore61|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue61]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU61
Y=(#Inset#+120*#Scale#)
Group=CPUCore61|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel62]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore62|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar62]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU62
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore62|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue62]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU62
Y=(#Inset#+120*#Scale#)
Group=CPUCore62|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel63]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore63|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar63]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU63
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore63|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue63]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU63
Y=(#Inset#+120*#Scale#)
Group=CPUCore63|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreLabel64]
Meter=String
MeterStyle=CPUStyleRowLabel
Y=(#Inset#+120*#Scale#)
Text=
Group=CPUCore64|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreBar64]
Meter=Bar
MeterStyle=CPUStyleRowBar
MeasureName=MeasureCPU64
Y=(#Inset#+120*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))
Group=CPUCore64|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreValue64]
Meter=String
MeterStyle=CPUStyleTableUsageValue
MeasureName=MeasureCPU64
Y=(#Inset#+120*#Scale#)
Group=CPUCore64|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage1]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore1|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature1]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore1|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage2]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore2|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature2]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore2|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage3]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore3|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature3]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore3|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage4]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore4|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature4]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore4|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage5]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore5|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature5]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore5|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage6]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore6|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature6]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore6|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage7]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore7|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature7]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore7|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage8]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore8|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature8]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore8|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage9]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore9|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature9]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore9|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage10]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore10|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature10]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore10|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage11]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore11|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature11]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore11|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage12]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore12|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature12]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore12|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage13]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore13|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature13]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore13|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage14]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore14|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature14]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore14|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage15]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore15|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature15]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore15|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage16]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore16|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature16]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore16|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage17]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore17|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature17]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore17|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage18]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore18|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature18]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore18|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage19]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore19|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature19]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore19|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage20]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore20|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature20]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore20|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage21]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore21|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature21]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore21|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage22]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore22|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature22]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore22|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage23]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore23|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature23]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore23|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage24]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore24|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature24]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore24|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage25]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore25|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature25]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore25|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage26]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore26|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature26]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore26|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage27]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore27|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature27]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore27|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage28]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore28|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature28]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore28|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage29]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore29|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature29]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore29|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage30]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore30|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature30]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore30|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage31]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore31|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature31]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore31|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage32]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore32|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature32]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore32|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage33]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore33|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature33]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore33|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage34]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore34|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature34]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore34|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage35]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore35|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature35]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore35|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage36]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore36|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature36]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore36|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage37]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore37|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature37]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore37|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage38]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore38|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature38]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore38|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage39]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore39|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature39]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore39|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage40]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore40|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature40]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore40|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage41]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore41|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature41]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore41|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage42]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore42|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature42]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore42|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage43]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore43|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature43]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore43|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage44]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore44|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature44]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore44|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage45]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore45|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature45]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore45|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage46]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore46|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature46]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore46|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage47]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore47|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature47]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore47|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage48]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore48|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature48]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore48|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage49]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore49|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature49]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore49|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage50]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore50|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature50]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore50|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage51]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore51|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature51]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore51|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage52]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore52|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature52]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore52|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage53]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore53|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature53]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore53|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage54]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore54|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature54]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore54|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage55]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore55|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature55]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore55|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage56]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore56|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature56]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore56|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage57]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore57|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature57]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore57|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage58]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore58|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature58]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore58|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage59]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore59|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature59]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore59|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage60]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore60|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature60]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore60|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage61]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore61|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature61]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore61|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage62]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore62|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature62]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore62|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage63]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore63|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature63]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore63|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreVoltage64]
Meter=String
MeterStyle=CPUStyleRowSensor
X=(#ContentX#+#CPUCoreColumnWidth#+22*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(44*#Scale#)
Group=CPUCore64|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterCoreTemperature64]
Meter=String
MeterStyle=CPUStyleRowTemperature
X=(#ContentX#+#CPUCoreColumnWidth#+78*#Scale#)
Y=(#Inset#+120*#Scale#)
W=(34*#Scale#)
Group=CPUCore64|CPUUI|ParallaxIdleFreeze
UpdateDivider=-1

[MeterTableCoreHeader]
Meter=String
MeterStyle=StyleLabel
X=#ContentX#
Y=(#Inset#+30*#Scale#)
; The header row has no bar, so the label may run up to the Zap icon at +15.
; At width 180 that is 47 px, holding "Thread" at the 10 pt header maximum (43.2 px).
W=(#CPUCoreColumnWidth#+15*#Scale#)
H=(16*#Scale#)
FontColor=#HeaderTextColor#
FontSize=(#HeaderFontSize#*#Scale#)
Text=Thread
Hidden=1
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze

[MeterTableVoltageHeader]
Meter=Image
X=(#ContentX#+#CPUCoreColumnWidth#+15*#Scale#)
Y=(#Inset#+31*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
; Official Lucide Zap artwork, exported from Icons/zap.svg at 128 px.
ImageName=#@#Modules\CPU\Icons\zap.png
Greyscale=1
ImageTint=#WarningColor#,255
Hidden=1
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze

[MeterTableTemperatureHeader]
Meter=Image
X=(#ContentX#+#CPUCoreColumnWidth#+54*#Scale#)
Y=(#Inset#+31*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
; Official Lucide Flame artwork, exported from Icons/flame.svg at 128 px.
ImageName=#@#Modules\CPU\Icons\flame.png
Greyscale=1
ImageTint=#CPUColor#,255
Hidden=1
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze

[MeterTableUsageHeader]
Meter=Image
X=(#ContentX#+#CPUCoreColumnWidth#+104*#Scale#)
Y=(#Inset#+31*#Scale#)
W=(14*#Scale#)
H=(14*#Scale#)
; Official Lucide Gauge artwork, exported from Icons/gauge.svg at 128 px.
ImageName=#@#Modules\CPU\Icons\gauge.png
Greyscale=1
ImageTint=#HeaderTextColor#,255
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze
Hidden=1

[MeterTableHeaderRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#TableHeaderBorderThickness#*#Scale#)
Shape=Line 0,(#TableHeaderBorderThickness#*#Scale#/2),#ContentWidth#,(#TableHeaderBorderThickness#*#Scale#/2) | Stroke Color #TableHeaderBorderColor# | StrokeWidth (#TableHeaderBorderThickness#*#Scale#)
Hidden=1
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze

[MeterTableFooterRule]
Meter=Shape
X=#ContentX#
Y=(#Inset#+30*#Scale#)
W=#ContentWidth#
H=(#DividerThickness#*#Scale#)
Shape=Line 0,(#DividerThickness#*#Scale#/2),#ContentWidth#,(#DividerThickness#*#Scale#/2) | Stroke Color #DividerColor# | StrokeWidth (#DividerThickness#*#Scale#)
Hidden=1
Group=CPUTableFrame|CPUUI|ParallaxIdleFreeze
