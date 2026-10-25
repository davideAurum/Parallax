; Selected native capacity banks. Disabled stops recurring updates, not refresh-time initialization.
[MeasureIOTotalA]
Measure=FreeDiskSpace
Drive=A:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityA|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeA]
Measure=FreeDiskSpace
Drive=A:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityA|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedA]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeA/Max(1,MeasureIOTotalA)))))
MinValue=0
MaxValue=100
Group=IOCapacityA|ParallaxIdlePause
Disabled=1

[MeasureIOTotalB]
Measure=FreeDiskSpace
Drive=B:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityB|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeB]
Measure=FreeDiskSpace
Drive=B:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityB|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedB]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeB/Max(1,MeasureIOTotalB)))))
MinValue=0
MaxValue=100
Group=IOCapacityB|ParallaxIdlePause
Disabled=1

[MeasureIOTotalC]
Measure=FreeDiskSpace
Drive=C:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityC|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeC]
Measure=FreeDiskSpace
Drive=C:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityC|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedC]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeC/Max(1,MeasureIOTotalC)))))
MinValue=0
MaxValue=100
Group=IOCapacityC|ParallaxIdlePause
Disabled=1

[MeasureIOTotalD]
Measure=FreeDiskSpace
Drive=D:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityD|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeD]
Measure=FreeDiskSpace
Drive=D:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityD|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedD]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeD/Max(1,MeasureIOTotalD)))))
MinValue=0
MaxValue=100
Group=IOCapacityD|ParallaxIdlePause
Disabled=1

[MeasureIOTotalE]
Measure=FreeDiskSpace
Drive=E:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityE|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeE]
Measure=FreeDiskSpace
Drive=E:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityE|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedE]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeE/Max(1,MeasureIOTotalE)))))
MinValue=0
MaxValue=100
Group=IOCapacityE|ParallaxIdlePause
Disabled=1

[MeasureIOTotalF]
Measure=FreeDiskSpace
Drive=F:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityF|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeF]
Measure=FreeDiskSpace
Drive=F:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityF|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedF]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeF/Max(1,MeasureIOTotalF)))))
MinValue=0
MaxValue=100
Group=IOCapacityF|ParallaxIdlePause
Disabled=1

[MeasureIOTotalG]
Measure=FreeDiskSpace
Drive=G:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityG|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeG]
Measure=FreeDiskSpace
Drive=G:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityG|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedG]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeG/Max(1,MeasureIOTotalG)))))
MinValue=0
MaxValue=100
Group=IOCapacityG|ParallaxIdlePause
Disabled=1

[MeasureIOTotalH]
Measure=FreeDiskSpace
Drive=H:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityH|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeH]
Measure=FreeDiskSpace
Drive=H:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityH|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedH]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeH/Max(1,MeasureIOTotalH)))))
MinValue=0
MaxValue=100
Group=IOCapacityH|ParallaxIdlePause
Disabled=1

[MeasureIOTotalI]
Measure=FreeDiskSpace
Drive=I:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityI|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeI]
Measure=FreeDiskSpace
Drive=I:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityI|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedI]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeI/Max(1,MeasureIOTotalI)))))
MinValue=0
MaxValue=100
Group=IOCapacityI|ParallaxIdlePause
Disabled=1

[MeasureIOTotalJ]
Measure=FreeDiskSpace
Drive=J:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityJ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeJ]
Measure=FreeDiskSpace
Drive=J:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityJ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedJ]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeJ/Max(1,MeasureIOTotalJ)))))
MinValue=0
MaxValue=100
Group=IOCapacityJ|ParallaxIdlePause
Disabled=1

[MeasureIOTotalK]
Measure=FreeDiskSpace
Drive=K:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityK|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeK]
Measure=FreeDiskSpace
Drive=K:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityK|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedK]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeK/Max(1,MeasureIOTotalK)))))
MinValue=0
MaxValue=100
Group=IOCapacityK|ParallaxIdlePause
Disabled=1

[MeasureIOTotalL]
Measure=FreeDiskSpace
Drive=L:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityL|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeL]
Measure=FreeDiskSpace
Drive=L:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityL|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedL]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeL/Max(1,MeasureIOTotalL)))))
MinValue=0
MaxValue=100
Group=IOCapacityL|ParallaxIdlePause
Disabled=1

[MeasureIOTotalM]
Measure=FreeDiskSpace
Drive=M:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityM|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeM]
Measure=FreeDiskSpace
Drive=M:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityM|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedM]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeM/Max(1,MeasureIOTotalM)))))
MinValue=0
MaxValue=100
Group=IOCapacityM|ParallaxIdlePause
Disabled=1

[MeasureIOTotalN]
Measure=FreeDiskSpace
Drive=N:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityN|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeN]
Measure=FreeDiskSpace
Drive=N:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityN|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedN]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeN/Max(1,MeasureIOTotalN)))))
MinValue=0
MaxValue=100
Group=IOCapacityN|ParallaxIdlePause
Disabled=1

[MeasureIOTotalO]
Measure=FreeDiskSpace
Drive=O:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityO|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeO]
Measure=FreeDiskSpace
Drive=O:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityO|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedO]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeO/Max(1,MeasureIOTotalO)))))
MinValue=0
MaxValue=100
Group=IOCapacityO|ParallaxIdlePause
Disabled=1

[MeasureIOTotalP]
Measure=FreeDiskSpace
Drive=P:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityP|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeP]
Measure=FreeDiskSpace
Drive=P:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityP|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedP]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeP/Max(1,MeasureIOTotalP)))))
MinValue=0
MaxValue=100
Group=IOCapacityP|ParallaxIdlePause
Disabled=1

[MeasureIOTotalQ]
Measure=FreeDiskSpace
Drive=Q:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityQ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeQ]
Measure=FreeDiskSpace
Drive=Q:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityQ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedQ]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeQ/Max(1,MeasureIOTotalQ)))))
MinValue=0
MaxValue=100
Group=IOCapacityQ|ParallaxIdlePause
Disabled=1

[MeasureIOTotalR]
Measure=FreeDiskSpace
Drive=R:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityR|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeR]
Measure=FreeDiskSpace
Drive=R:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityR|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedR]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeR/Max(1,MeasureIOTotalR)))))
MinValue=0
MaxValue=100
Group=IOCapacityR|ParallaxIdlePause
Disabled=1

[MeasureIOTotalS]
Measure=FreeDiskSpace
Drive=S:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityS|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeS]
Measure=FreeDiskSpace
Drive=S:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityS|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedS]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeS/Max(1,MeasureIOTotalS)))))
MinValue=0
MaxValue=100
Group=IOCapacityS|ParallaxIdlePause
Disabled=1

[MeasureIOTotalT]
Measure=FreeDiskSpace
Drive=T:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityT|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeT]
Measure=FreeDiskSpace
Drive=T:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityT|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedT]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeT/Max(1,MeasureIOTotalT)))))
MinValue=0
MaxValue=100
Group=IOCapacityT|ParallaxIdlePause
Disabled=1

[MeasureIOTotalU]
Measure=FreeDiskSpace
Drive=U:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityU|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeU]
Measure=FreeDiskSpace
Drive=U:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityU|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedU]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeU/Max(1,MeasureIOTotalU)))))
MinValue=0
MaxValue=100
Group=IOCapacityU|ParallaxIdlePause
Disabled=1

[MeasureIOTotalV]
Measure=FreeDiskSpace
Drive=V:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityV|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeV]
Measure=FreeDiskSpace
Drive=V:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityV|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedV]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeV/Max(1,MeasureIOTotalV)))))
MinValue=0
MaxValue=100
Group=IOCapacityV|ParallaxIdlePause
Disabled=1

[MeasureIOTotalW]
Measure=FreeDiskSpace
Drive=W:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityW|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeW]
Measure=FreeDiskSpace
Drive=W:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityW|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedW]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeW/Max(1,MeasureIOTotalW)))))
MinValue=0
MaxValue=100
Group=IOCapacityW|ParallaxIdlePause
Disabled=1

[MeasureIOTotalX]
Measure=FreeDiskSpace
Drive=X:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityX|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeX]
Measure=FreeDiskSpace
Drive=X:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityX|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedX]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeX/Max(1,MeasureIOTotalX)))))
MinValue=0
MaxValue=100
Group=IOCapacityX|ParallaxIdlePause
Disabled=1

[MeasureIOTotalY]
Measure=FreeDiskSpace
Drive=Y:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityY|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeY]
Measure=FreeDiskSpace
Drive=Y:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityY|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedY]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeY/Max(1,MeasureIOTotalY)))))
MinValue=0
MaxValue=100
Group=IOCapacityY|ParallaxIdlePause
Disabled=1

[MeasureIOTotalZ]
Measure=FreeDiskSpace
Drive=Z:
Total=1
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityZ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFreeZ]
Measure=FreeDiskSpace
Drive=Z:
IgnoreRemovable=0
DiskQuota=#IODiskQuota#
Group=IOCapacityZ|ParallaxIdlePause
Disabled=1
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsedZ]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFreeZ/Max(1,MeasureIOTotalZ)))))
MinValue=0
MaxValue=100
Group=IOCapacityZ|ParallaxIdlePause
Disabled=1