---
icon : material/harddisk
date: 2026-03-01
---
# **Hardware**

## Disk Failures
!!! quote inline end "**Michael W Lucas**"

    Disks are evil. They lie about their characteristics and layout, they hide errors, and they fail in unexpected ways. Your disks are secretly plotting against you.

One of the most significant threats to data integrity and system performance in GPFS is hardware disk failures. Understanding how GPFS handles disk failures and their potential impact on the overall system is crucial for maintaining data availability and minimizing downtime.  Disk failures can lead to temporary performance degradation and increased operational complexity.



``` title="Lists information about RAID recovery groups"
#mmlsrecoverygroup ocean1 -L --pdisk
```

``` title="Displays Network Shared Disk (NSD) information"
#mmlsnsd -X
```

``` title="Displays the environmental status of RAID disk enclosures"
#mmlsenclosure all
```

Once we get the state from any of the above command we can check what that mean from [Pdisk States List](https://www.ibm.com/docs/en/storage-scale-system/6.1.4_ece?topic=pdisks-pdisk-states)

## [Disks and RAID](gpfs-notes.md#disk-configurations)

Detailed references for Disk management is located in RAID administration guide from IBM.

`mmvdisk` greatly simplifies IBM Spectrum Scale RAID administration

Command structure: `mmvdisk <noun> <parameter>`

The nouns that mmvdisk recognizes are  

* `mmvdisk nodeclass`  - Manage server node classes  
* `mmvdisk server`  - Manage recovery group servers  
* `mmvdisk recoverygroup`  - Manage recovery groups  
* `mmvdisk vdiskset`  - Manage vdisk sets  
* `mmvdisk filesystem`  - Manage file systems made from vdisk sets  
* `mmvdisk pdisk`  - Manage pdisks  
* `mmvdisk vdisk`  - Manage vdisks  

Parameters are applied to nouns, but specific parameters are designed to work with certain nouns. Common parameters include actions such as `list`, `change`, `add`, `delete`, and `configure`.

??? example "Expand to show mmvdisk examples"

    ``` title="List Parameter"
    #mmvdisk server list
    #mmvdisk vdiskset list --vdisk-set all
    #mmvdisk vdiskset list --recovery-group all
    #mmvdisk pdisk list  -L
    #mmvdisk recoverygroup list --declustered-array
    #mmvdisk recoverygroup list --recovery-group <rg name> --server
    ```


## Disk Topography
Disk subsystem configuration on an IBM Spectrum Scale RAID server can be captured by following the next times


``` title="Creating topography file"
#mmgetpdisktopology > server.top
```
``` title="View Summary of the topography file"
#topsummary server.top 
``` 


## Failed Disk Replacement


Locating the Disk: to locate the failed disk we have more than one option:

``` title="1. Locating the failed Disk marked for replacement"
#mmvdisk pdisk list --replace --recovery-group all
```
or this command
``` title="2. Locating the failed Disk and more details"
#mmvdisk pdisk list -L --recovery-group all --not-ok
```
or this command
``` title="3. Listing all disks states"
#mmlsrecoverygroup ocean1 -L --pdisk
```
or simply looking into the logs
``` title="4. log filtering by the disk name"
#grep -5 "<disk-name>" /var/log/messages
```


**Replacing a pdisk requires the following three steps**

1. Run the `mmvdisk pdisk replace --prepare` command to prepare the pdisk for physical removal.
2. Physically remove the disk and replace it with a new disk of the same type.
3. Run the `mmvdisk pdisk replace` command to complete the replacement.


!!! warning
    Please consult with your support before replacing the disk since this process can void the support agreement.


``` title="Preparing the Disk for removal"
#mmvdisk pdisk replace --prepare --recovery-group <server> --pdisk <disk-name>
```

after removal of old disk and insertion of the new disk we need to issue this command

``` title="After adding the new disk"
#mmvdisk pdisk replace --recovery-group <server> --pdisk <disk-name>
```


## Extra Commands 
``` title="Displays the environmental status of RAID disk enclosures"
#mmlsenclosure all
```

``` title="Determining pdisk-group fault-tolerance"
#mmlsrecoverygroup RecoveryGroupName -L
```

``` title="Displays Network Shared Disk (NSD) extended information"
#mmlsnsd -X
```
``` title="Lists information for vdisks"
#mmlsvdisk
```

??? References
    [mmvdisk command](https://www.ibm.com/docs/en/storage-scale-system/6.1.8_cd?topic=command-mmvdisk-pdisk)
