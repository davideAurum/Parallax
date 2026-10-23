; CPUShowProcesses=1: the process list. Measures.inc includes this file only
; in that state (ProcessMeasures0.inc otherwise). Alias=CPU is the Process
; category, whose 1 Hz reader is shared process-wide with RAM's process
; measures; it stops only when no loaded measure in any skin names it.
; No DynamicVariables: CPU.lua enables and disables these slots on change only.
[MeasureCPUProcess1]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=1
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess2]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=2
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess3]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=3
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess4]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=4
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess5]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=5
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess6]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=6
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess7]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=7
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess8]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=8
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess9]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=9
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1

[MeasureCPUProcess10]
Measure=Plugin
Group=ParallaxIdlePause
Plugin=UsageMonitor
Alias=CPU
Index=10
Blacklist=_Total|Idle
Rollup=1
MinValue=0
MaxValue=100
Disabled=1
UpdateDivider=1
