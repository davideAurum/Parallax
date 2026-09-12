; Optional variant only. These are disk-device counters, NOT Process I/O aliases.
; One independent 1 Hz UsageMonitor category worker is shared by these measures.
; RawValue=0 is required for cooked Bytes/sec, not cumulative raw FirstValue.
[MeasureIODiskRead]
Measure=Plugin
Plugin=UsageMonitor
Category=#IODiskCategory#
Counter=Disk Read Bytes/sec
Name=#IODiskInstance#
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))

[MeasureIODiskWrite]
Measure=Plugin
Plugin=UsageMonitor
Category=#IODiskCategory#
Counter=Disk Write Bytes/sec
Name=#IODiskInstance#
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
