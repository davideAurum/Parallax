; Per-letter logical volume rates. Disabled stops updates but does not unload the provider.
; One independent 1 Hz UsageMonitor category worker shares two counter datasets.
[MeasureIODiskReadA]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=A:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesA
Disabled=1

[MeasureIODiskWriteA]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=A:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesA
Disabled=1

[MeasureIODiskReadB]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=B:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesB
Disabled=1

[MeasureIODiskWriteB]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=B:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesB
Disabled=1

[MeasureIODiskReadC]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=C:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesC
Disabled=1

[MeasureIODiskWriteC]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=C:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesC
Disabled=1

[MeasureIODiskReadD]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=D:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesD
Disabled=1

[MeasureIODiskWriteD]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=D:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesD
Disabled=1

[MeasureIODiskReadE]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=E:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesE
Disabled=1

[MeasureIODiskWriteE]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=E:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesE
Disabled=1

[MeasureIODiskReadF]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=F:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesF
Disabled=1

[MeasureIODiskWriteF]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=F:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesF
Disabled=1

[MeasureIODiskReadG]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=G:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesG
Disabled=1

[MeasureIODiskWriteG]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=G:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesG
Disabled=1

[MeasureIODiskReadH]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=H:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesH
Disabled=1

[MeasureIODiskWriteH]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=H:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesH
Disabled=1

[MeasureIODiskReadI]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=I:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesI
Disabled=1

[MeasureIODiskWriteI]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=I:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesI
Disabled=1

[MeasureIODiskReadJ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=J:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesJ
Disabled=1

[MeasureIODiskWriteJ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=J:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesJ
Disabled=1

[MeasureIODiskReadK]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=K:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesK
Disabled=1

[MeasureIODiskWriteK]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=K:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesK
Disabled=1

[MeasureIODiskReadL]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=L:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesL
Disabled=1

[MeasureIODiskWriteL]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=L:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesL
Disabled=1

[MeasureIODiskReadM]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=M:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesM
Disabled=1

[MeasureIODiskWriteM]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=M:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesM
Disabled=1

[MeasureIODiskReadN]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=N:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesN
Disabled=1

[MeasureIODiskWriteN]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=N:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesN
Disabled=1

[MeasureIODiskReadO]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=O:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesO
Disabled=1

[MeasureIODiskWriteO]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=O:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesO
Disabled=1

[MeasureIODiskReadP]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=P:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesP
Disabled=1

[MeasureIODiskWriteP]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=P:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesP
Disabled=1

[MeasureIODiskReadQ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=Q:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesQ
Disabled=1

[MeasureIODiskWriteQ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=Q:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesQ
Disabled=1

[MeasureIODiskReadR]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=R:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesR
Disabled=1

[MeasureIODiskWriteR]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=R:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesR
Disabled=1

[MeasureIODiskReadS]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=S:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesS
Disabled=1

[MeasureIODiskWriteS]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=S:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesS
Disabled=1

[MeasureIODiskReadT]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=T:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesT
Disabled=1

[MeasureIODiskWriteT]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=T:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesT
Disabled=1

[MeasureIODiskReadU]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=U:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesU
Disabled=1

[MeasureIODiskWriteU]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=U:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesU
Disabled=1

[MeasureIODiskReadV]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=V:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesV
Disabled=1

[MeasureIODiskWriteV]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=V:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesV
Disabled=1

[MeasureIODiskReadW]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=W:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesW
Disabled=1

[MeasureIODiskWriteW]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=W:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesW
Disabled=1

[MeasureIODiskReadX]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=X:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesX
Disabled=1

[MeasureIODiskWriteX]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=X:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesX
Disabled=1

[MeasureIODiskReadY]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=Y:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesY
Disabled=1

[MeasureIODiskWriteY]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=Y:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesY
Disabled=1

[MeasureIODiskReadZ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Read Bytes/sec
Name=Z:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesZ
Disabled=1

[MeasureIODiskWriteZ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=Disk Write Bytes/sec
Name=Z:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=(Max(1,#IODiskMaxMiBs#*1048576))
Group=IORatesZ
Disabled=1