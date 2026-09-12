; IO settings. Edit, save, then refresh the IO skin. Preserved on package upgrades.
[Variables]
Columns=1
PanelHeight=174
; bytes = binary B/s; bits = decimal bit/s. Capacity always uses binary bytes.
IODiskUnits=bytes
; Drive roots for capacity; IOShowDrive2=0 disables the second row measures.
IODrive1=C:
IODrive2=D:
IOShowDrive2=0
; 0 includes removable USB drives; 1 ignores them. Optical capacity is unsupported.
IOIgnoreRemovable=0
; DiskQuota=0 shows whole-volume capacity, not the current user's quota.
IODiskQuota=0
; Optional IO-Disk.ini only. Use English performance-counter category names.
; Allowed categories: PhysicalDisk or LogicalDisk. Name is an exact instance name.
; _Total aggregates the category and is independent of the capacity drive rows.
IODiskCategory=PhysicalDisk
IODiskInstance=_Total
; Fixed transfer graph ceiling in binary mebibytes/second, for each direction.
IODiskMaxMiBs=500
