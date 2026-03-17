---
icon: material/scale-balance
tags:
  - storage
  - truenas
  - truenas-scale
  - zfs
  - backup
---

# TrueNAS SCALE Notes

This page captures practical evaluation notes for TrueNAS SCALE, including platform choice, ZFS pool design, monitoring considerations, and operational checks.

## Why Consider SCALE

TrueNAS CORE has historically been regarded as mature and stable, but SCALE has become the more actively developed platform for new features and ongoing product direction.

In practice, this means:

- new feature development is centered on SCALE
- some fixes may land in SCALE and not be backported to CORE
- long-term planning should account for the vendor’s focus on SCALE

Useful reading:

- [TrueNAS SCALE download page](https://www.truenas.com/download-truenas-scale/)
- [TrueNAS CORE download page](https://www.truenas.com/download-truenas-core/)
- [Discussion on the future of CORE](https://www.truenas.com/community/threads/what-is-the-future-of-truenas-core.116049/)

## ZFS Pool Layout Basics

When evaluating a pool layout, it helps to compare these six metrics:

1. Read IOPS
2. Write IOPS
3. Streaming read throughput
4. Streaming write throughput
5. Usable capacity efficiency
6. Fault tolerance

Helpful reference:

- [ZFS capacity calculator](https://www.truenas.com/docs/references/zfscapacitycalculator/)
- [iXsystems ZFS storage pool layout white paper](https://static.ixsystems.co/uploads/2020/09/ZFS_Storage_Pool_Layout_White_Paper_2020_WEB.pdf)

## Pool Layout Summary

### Striped vdev

For an `N`-wide striped vdev:

1. Read IOPS: `N * read IOPS of one drive`
2. Write IOPS: `N * write IOPS of one drive`
3. Streaming read: `N * single-drive read throughput`
4. Streaming write: `N * single-drive write throughput`
5. Space efficiency: `100%`
6. Fault tolerance: none

### Mirrored vdev

For an `N`-way mirror:

1. Read IOPS: `N * read IOPS of one drive`
2. Write IOPS: approximately `single-drive write IOPS`
3. Streaming read: `N * single-drive read throughput`
4. Streaming write: approximately `single-drive write throughput`

### RAIDZ vdev

For an `N`-wide RAIDZ vdev with parity level `p`:

1. Read IOPS: approximately `single-drive read IOPS`
2. Write IOPS: approximately `single-drive write IOPS`
3. Streaming read: `(N - p) * single-drive read throughput`
4. Streaming write: `(N - p) * single-drive write throughput`
5. Space efficiency: `(N - p) / N`
6. Fault tolerance depends on parity level:
   `RAIDZ1 = 1 disk`, `RAIDZ2 = 2 disks`, `RAIDZ3 = 3 disks`

## Design Considerations

For backup and file share workloads with many files, the tradeoff is usually between:

- higher usable capacity
- better random I/O behavior
- rebuild and resilver risk
- fault tolerance during disk failures

A balanced design often favors:

- RAIDZ2 for a backup-oriented pool where resilience matters
- mirrors where high IOPS matters more than space efficiency

## Example Deployment Pattern

A generalized backup-oriented layout might look like:

- `2 x 6-wide RAIDZ2 vdevs`
- `2 spare disks`
- SSD or NVMe devices for boot and metadata-adjacent roles where appropriate
- one high-speed data network
- one management interface

This kind of design usually aims to provide:

- reasonable capacity efficiency
- tolerance for multiple disk failures per vdev
- acceptable backup and file-share performance

## ZFS Notes

### ZIL / SLOG

- the ZIL handles synchronous write intent
- SLOG devices mainly benefit sync-write-heavy workloads
- SLOG design should be planned carefully because a bad design decision can affect pool behavior and reliability

Reference:

- [ZIL and SLOG reference](https://www.truenas.com/docs/references/zilandslog/)

### ARC

ARC is the main in-memory ZFS cache. It tracks both frequently used data and recently evicted blocks to improve read efficiency.

## Hardware Planning

Instead of documenting exact serializable inventory in a shared note, it is often better to track hardware by category:

- CPU class
- memory size
- boot devices
- data devices
- HBA model
- network interfaces
- power design

For public or shared documentation, keep exact management addresses and device identifiers out of the page.

## Disk Failure and Hardware Operations

When handling disk failures, enclosure tools such as `sesutil` or the Linux equivalent can help identify and locate failed drives, depending on the operating system and hardware stack in use.

Reference:

- [TrueNAS hardware guide](https://www.truenas.com/docs/core/13.0/gettingstarted/corehardwareguide/#storage-solutions)

## Monitoring

Monitoring should cover:

- pool health
- disk faults
- capacity trends
- network state
- replication and backup tasks
- service health

One common approach is:

- enable SNMP where appropriate
- integrate with Zabbix, Prometheus, or another monitoring stack
- verify that templates or OIDs match the TrueNAS version in use

Reference:

- [Zabbix TrueNAS CORE SNMP template](https://git.zabbix.com/projects/ZBX/repos/zabbix/browse/templates/app/truenas_snmp/template_app_truenas_core_snmp.yaml?at=release%2F7.0)

### Monitoring References

General monitoring and dashboard references:

- [Node Exporter Full Grafana dashboard](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
- [TrueNAS Graphite Flux Grafana dashboard](https://grafana.com/grafana/dashboards/20199-truenas-graphite-flux/)
- [Grafana + Prometheus getting started](https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus/)

Community notes and discussions:

- [How to expose data for Prometheus](https://www.truenas.com/community/threads/how-to-expose-data-for-prometheus.98532/#post-797642)
- [Metrics from TrueNAS SCALE into Grafana](https://www.truenas.com/community/threads/metrics-from-truenas-scale-server-into-grafana.115903/)
- [SNMP OID changes in TrueNAS SCALE](https://www.reddit.com/r/truenas/comments/16omezn/truenas_scale_oid_of_snmp_changed_drastically/)
- [Free disk space from TrueNAS Graphite discussion](https://www.reddit.com/r/truenas/comments/18tnw9x/how_to_get_free_disk_space_from_truenas_graphite/)

Video references:

- [TrueNAS monitoring walkthrough 1](https://www.youtube.com/watch?v=G7Y69_w_N-c)
- [TrueNAS monitoring walkthrough 2](https://www.youtube.com/watch?v=9TJx7QTrTyo&t=312s)
- [TrueNAS monitoring walkthrough 3](https://www.youtube.com/watch?v=2jSwrok3tSY)
- [Prometheus / Grafana setup reference](https://www.youtube.com/watch?v=xN47J-Tp2oU)
- [Zabbix SNMPv3 monitoring reference](https://www.youtube.com/watch?v=MaG8f3NPUws)

## Platform Notes

### Firewall management

SCALE does not follow the same firewall management expectations as a traditional hand-managed Linux host. In many cases, direct local firewall customization is either restricted, discouraged, or expected to be handled through the platform’s own management model.

### Package management

APT is typically disabled by default on TrueNAS SCALE because the platform is intended to be managed through the appliance workflow and UI. Enabling unmanaged package changes can introduce drift or break supported behavior.

## Useful Services and Logs

### Services

- `ix-netif.service` - network setup
- `networking.service` - network interface activation
- `middlewared` - the backend service layer used by the UI and API

### Useful paths

```text
/var/log/middlewared.log
/var/run/middleware
```

## Example Commands

### Show pool health

```bash
zpool status -v
```

### Show pool I/O statistics

```bash
zpool iostat 1
```

### List snapshots

```bash
zfs list -t snapshot
```

### Check ashift

```bash
zdb -C <pool-name> | grep ashift
```

## Persistent VLAN Example

If a deployment needs a persistent VLAN configuration, document it with placeholders rather than production addresses.

Example:

```ini
auto <interface>
iface <interface> inet manual
    mtu 9000

auto <interface>.<vlan-id>
iface <interface>.<vlan-id> inet static
    address <ip-address>
    netmask <subnet-mask>
    mtu 9000
```

## Suggested Evaluation Checklist

- confirm whether SCALE is the right long-term platform for the workload
- validate pool layout against actual IOPS and resiliency requirements
- test disk replacement workflow
- validate monitoring coverage before production use
- confirm backup and restore procedures
- avoid unmanaged package drift
- document network and service dependencies clearly

## References

- [TrueNAS SCALE download](https://www.truenas.com/download-truenas-scale/)
- [TrueNAS CORE download](https://www.truenas.com/download-truenas-core/)
- [ZFS capacity calculator](https://www.truenas.com/docs/references/zfscapacitycalculator/)
- [ZIL / SLOG reference](https://www.truenas.com/docs/references/zilandslog/)
- [ZFS storage pool layout white paper](https://static.ixsystems.co/uploads/2020/09/ZFS_Storage_Pool_Layout_White_Paper_2020_WEB.pdf)
- [Intro to ZFS](https://www.truenas.com/community/resources/introduction-to-zfs.111/)
- [Uncle Fester's TrueNAS beginner's guide](https://www.truenas.com/community/resources/uncle-festers-truenas-beginners-guide.120/)
