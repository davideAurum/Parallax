; Per-letter logical volume rates. Disabled stops updates but does not unload the provider.
; One independent 1 Hz UsageMonitor category worker shares three counter datasets.
; Load is busy time, 100 - % Idle Time, computed by IO.lua.
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
Group=IORatesA|ParallaxIdlePause
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
Group=IORatesA|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleA]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=A:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesA|ParallaxIdlePause
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
Group=IORatesB|ParallaxIdlePause
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
Group=IORatesB|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleB]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=B:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesB|ParallaxIdlePause
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
Group=IORatesC|ParallaxIdlePause
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
Group=IORatesC|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleC]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=C:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesC|ParallaxIdlePause
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
Group=IORatesD|ParallaxIdlePause
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
Group=IORatesD|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleD]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=D:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesD|ParallaxIdlePause
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
Group=IORatesE|ParallaxIdlePause
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
Group=IORatesE|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleE]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=E:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesE|ParallaxIdlePause
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
Group=IORatesF|ParallaxIdlePause
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
Group=IORatesF|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleF]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=F:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesF|ParallaxIdlePause
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
Group=IORatesG|ParallaxIdlePause
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
Group=IORatesG|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleG]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=G:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesG|ParallaxIdlePause
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
Group=IORatesH|ParallaxIdlePause
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
Group=IORatesH|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleH]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=H:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesH|ParallaxIdlePause
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
Group=IORatesI|ParallaxIdlePause
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
Group=IORatesI|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleI]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=I:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesI|ParallaxIdlePause
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
Group=IORatesJ|ParallaxIdlePause
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
Group=IORatesJ|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleJ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=J:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesJ|ParallaxIdlePause
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
Group=IORatesK|ParallaxIdlePause
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
Group=IORatesK|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleK]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=K:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesK|ParallaxIdlePause
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
Group=IORatesL|ParallaxIdlePause
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
Group=IORatesL|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleL]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=L:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesL|ParallaxIdlePause
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
Group=IORatesM|ParallaxIdlePause
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
Group=IORatesM|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleM]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=M:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesM|ParallaxIdlePause
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
Group=IORatesN|ParallaxIdlePause
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
Group=IORatesN|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleN]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=N:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesN|ParallaxIdlePause
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
Group=IORatesO|ParallaxIdlePause
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
Group=IORatesO|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleO]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=O:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesO|ParallaxIdlePause
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
Group=IORatesP|ParallaxIdlePause
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
Group=IORatesP|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleP]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=P:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesP|ParallaxIdlePause
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
Group=IORatesQ|ParallaxIdlePause
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
Group=IORatesQ|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleQ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=Q:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesQ|ParallaxIdlePause
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
Group=IORatesR|ParallaxIdlePause
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
Group=IORatesR|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleR]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=R:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesR|ParallaxIdlePause
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
Group=IORatesS|ParallaxIdlePause
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
Group=IORatesS|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleS]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=S:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesS|ParallaxIdlePause
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
Group=IORatesT|ParallaxIdlePause
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
Group=IORatesT|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleT]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=T:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesT|ParallaxIdlePause
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
Group=IORatesU|ParallaxIdlePause
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
Group=IORatesU|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleU]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=U:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesU|ParallaxIdlePause
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
Group=IORatesV|ParallaxIdlePause
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
Group=IORatesV|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleV]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=V:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesV|ParallaxIdlePause
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
Group=IORatesW|ParallaxIdlePause
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
Group=IORatesW|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleW]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=W:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesW|ParallaxIdlePause
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
Group=IORatesX|ParallaxIdlePause
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
Group=IORatesX|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleX]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=X:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesX|ParallaxIdlePause
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
Group=IORatesY|ParallaxIdlePause
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
Group=IORatesY|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleY]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=Y:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesY|ParallaxIdlePause
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
Group=IORatesZ|ParallaxIdlePause
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
Group=IORatesZ|ParallaxIdlePause
Disabled=1

[MeasureIODiskIdleZ]
Measure=Plugin
Plugin=UsageMonitor
Category=LogicalDisk
Counter=% Idle Time
Name=Z:
Rollup=0
Percent=0
RawValue=0
MinValue=0
MaxValue=100
Group=IORatesZ|ParallaxIdlePause
Disabled=1
