---
icon: material/alert-circle-outline
tags:
  - storage
  - gpfs
  - troubleshooting
  - ibm-storage-scale
---
# **Troubleshooting** 

I will outline the steps I use to identify the issue and provide direct links to relevant documentation where the solution is described.

First we need to check GPFS state on the node.
```title="GPFS State on the Node"
#mmgetstate
```

The second step involves running `mmhealth` command to gain an overview of the issue.


Cluster Level

```title="Cluster Health Status"
#mmhealth cluster show --verbose
```

Node Level

```title="All Nodes Health Status"
#mmhealth node show -N all
```

```title="Node Health Status"
#mmhealth node show --verbose
```

Event Analysis
```title="Node Event Logs"
#mmhealth node eventlog --verbose
```
once we have the event type we can look into the details

```title="Logs related to quorum_down event"
#mmhealth event show quorum_down
```



## **Logs**

The GPFS log can be found in the `/var/adm/ras` directory on each node. The GPFS log file is named `mmfs.log.date.nodeName`, where date is the time stamp when the instance of GPFS started on the node and nodeName is the name of the node. The latest GPFS log file can be found by using the symbolic file name `/var/adm/ras/mmfs.log.latest`.

```title="mmfs log"
#/var/adm/ras/mmfs.log.latest
```
```title="Operating system error logs"
#/var/adm/ras/mmsysmonitor.localhost.log
```
```title="simply grepping mmfs"
#grep "mmfs:" /var/log/messages
```
```title="CCR logs"
#/var/mmf/ccr/*
```
```title="winbind logs"
#egrep '([0-9]{1,3}\.){3}[0-9]{1,3}$' /var/adm/ras/log.wb-<domain>
```

## **Monitoring Events**
The recorded events are stored in the local database on each node. The user can get a list of recorded events by using the mmhealth node eventlog command. Users can use the mmhealth node show or mmhealth cluster show commands to display the active events in the node and cluster respectively.

when using `mmhealth node eventlog` you will be presented with ==Event Name== for each event type we can get more details and solution recommendations from the [RAS events list](https://www.ibm.com/docs/en/storage-scale/5.1.1?topic=references-events). This can be very helpful for locating the issue.

!!! example "disk_down Event"
    For example if we have `disk_down` event we can go to the list of [disk events](https://www.ibm.com/docs/en/storage-scale/5.1.1?topic=events-disk) where we will find cause and recommened user action.





## **Log Dump**
In case needed for incident report or sending to IBM support for diagonics.

``` title="Lenovo DSS-G specific debug data collection"
#dssg.snap
```

``` title="Creating a master GPFS log file"
#gpfs.snap --gather-logs -d /tmp/logs -N all
```

Also you can look into the [Trace facility](https://www.ibm.com/docs/en/storage-scale/5.2.1?topic=traces-trace-facility#trace).


## Extra Commands

## [CCR](gpfs-notes.md#clustered-configuration-repository-ccr)

``` title="CCR Check"
#mmccr check -e -Y
```
``` title="CCR Nodes"
#mmccr lsnodes
```



??? References

    RAS stands for Reliability, Availability, and Serviceability  

    [Master Log](https://www.ibm.com/docs/en/storage-scale/5.2.1?topic=logs-creating-master-gpfs-log-file)

    [Troubleshooting Overview](https://www.ibm.com/docs/en/storage-scale/5.2.1?topic=troubleshooting)

    [Events](https://www.ibm.com/docs/en/storage-scale/5.2.1?topic=references-events)

    [Event Types](https://www.ibm.com/docs/en/storage-scale/5.0.3?topic=command-event-type-monitoring-status-system-health)

    [CCR](https://www.ibm.com/docs/en/storage-scale/5.2.1?topic=troubleshooting-ccr-issues)
