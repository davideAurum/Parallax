; Native capacity sources are sampled slowly. Presentation follows them.
[MeasureIOType1]
Measure=FreeDiskSpace
Drive=#IODrive1#
Type=1
IgnoreRemovable=#IOIgnoreRemovable#
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOTotal1]
Measure=FreeDiskSpace
Drive=#IODrive1#
Total=1
IgnoreRemovable=#IOIgnoreRemovable#
DiskQuota=#IODiskQuota#
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFree1]
Measure=FreeDiskSpace
Drive=#IODrive1#
IgnoreRemovable=#IOIgnoreRemovable#
DiskQuota=#IODiskQuota#
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsed1]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFree1/Max(1,MeasureIOTotal1)))))
MinValue=0
MaxValue=100

[MeasureIOType2]
Measure=FreeDiskSpace
Drive=#IODrive2#
Type=1
IgnoreRemovable=#IOIgnoreRemovable#
Disabled=(1-#IOShowDrive2#)
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOTotal2]
Measure=FreeDiskSpace
Drive=#IODrive2#
Total=1
IgnoreRemovable=#IOIgnoreRemovable#
DiskQuota=#IODiskQuota#
Disabled=(1-#IOShowDrive2#)
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOFree2]
Measure=FreeDiskSpace
Drive=#IODrive2#
IgnoreRemovable=#IOIgnoreRemovable#
DiskQuota=#IODiskQuota#
Disabled=(1-#IOShowDrive2#)
UpdateDivider=(Max(5,Ceil(#CapacityInterval#/1000)))

[MeasureIOUsed2]
Measure=Calc
Formula=(Max(0,Min(100,100*(1-MeasureIOFree2/Max(1,MeasureIOTotal2)))))
MinValue=0
MaxValue=100
