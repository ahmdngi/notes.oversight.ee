---
icon: material/console-line
tags:
  - storage
  - gpfs
  - ibm-storage-scale
  - commands
  - operations
date: 2025-09-15
---

# GPFS Command Reference

This page is a practical command reference for common IBM Storage Scale / GPFS administration tasks.

## How To Use This Page

Use this document as a quick operator reference. Commands are grouped by task so it is easier to find the right starting point during administration or troubleshooting.

Typical placeholders used below:

- `<filesystem>`
- `<node>`
- `<node-list>`
- `<fileset>`
- `<ces-node>`
- `<ces-ip>`
- `<export-path>`
- `<client-subnet>`
- `<user>`
- `<group>`

## Cluster Basics

### Show cluster information

```bash
mmlscluster
```

### Show the cluster manager node

```bash
mmlsmgr
```

### Show cluster configuration

```bash
mmlsconfig
```

### Change cluster configuration

```bash
mmchconfig
```

### Show mounted GPFS file systems

```bash
mmlsmount all -L
```

### Show GPFS daemon state

```bash
mmgetstate
mmgetstate -a -L -v
mmgetstate -s
```

### Show build and runtime diagnostics

```bash
mmdiag
mmdiag --all
```

## File System and Capacity Checks

### Show file system properties

```bash
mmlsfs <filesystem>
```

### Show capacity and inode usage

```bash
mmdf <filesystem>
```

### Show filesets

```bash
mmlsfileset <filesystem>
```

### Show node classes

```bash
mmlsnodeclass
```

## Health Monitoring

### Node-level health

```bash
mmhealth node show
mmhealth node show -N all
mmhealth node eventlog
mmhealth node eventlog --hour --verbose
```

### Cluster-level health

```bash
mmhealth cluster show
mmhealth cluster show --verbose
mmhealth cluster show node
mmhealth cluster show filesystem
mmhealth cluster show gpfs
```

### Show only unhealthy node output

```bash
mmhealth cluster show node | grep -v HEALTHY
```

### Inspect a specific event

```bash
mmhealth event show <event-id>
mmhealth event show quorum_down
```

### Resync health metadata if cluster state looks inconsistent

```bash
mmhealth node show --resync
```

## Logs and Diagnostics

### Common log locations

```text
/var/adm/ras/mmfs.log.latest
/var/log/messages
```

### Dump GPFS waiters

```bash
mmfsadm dump waiters
```

### Review system logs

```bash
journalctl -p 4
grep "mmfs:" /var/log/messages
```

### CCR-related checks

```bash
mmccr lsnodes
mmccr check -e -Y
```

## CES Administration

Use these commands when working with Cluster Export Services.

### Show CES cluster configuration

```bash
mmlscluster --ces
```

### Show CES service state

```bash
mmces service list -a
mmces state show
mmhealth cluster show ces
```

### Show CES addresses

```bash
mmces address list --full-list
```

### Show CES log level

```bash
mmces log level
```

### List CES events

```bash
mmces events list -a
```

### Move a CES IP manually

```bash
mmces address move --ces-ip <ces-ip> --ces-node <ces-node>
```

### Useful CES troubleshooting commands

```bash
mmhealth node show
mmhealth cluster show ces
mmces state cluster ces
```

If CES status looks mismatched between `mmhealth` and `mmces`, a metadata resync may help:

```bash
mmhealth node show --resync
```

## NFS Export Management

### List current NFS exports

```bash
mmnfs export list
```

### Add a new export

```bash
mmnfs export add <export-path> --client "<client-subnet>(Access_Type=RW)"
```

Example:

```bash
mmnfs export add /gpfs/<filesystem>/<fileset> --client "10.0.0.0/24(Access_Type=RW)"
```

### Add another client to an existing export

```bash
mmnfs export change <export-path> --nfsadd "<client-ip-or-subnet>(Access_Type=RW)"
```

### Remove client access from an export

```bash
mmnfs export change <export-path> --nfsremove "<client-ip-or-subnet>"
```

### Remove an export

```bash
mmnfs export remove <export-path>
```

### Load exports from a saved configuration

```bash
mmnfs export load /path/to/gpfs.ganesha.exports.conf
```

This is useful when restoring many exports after a service failure or failover issue.

## SMB Preparation

These are generic Linux-side setup steps often used before exposing a directory through SMB.

### Create the shared directory

```bash
mkdir /gpfs/<filesystem>/smb/<share-name>
```

### Assign owner and group

```bash
chown <user> /gpfs/<filesystem>/smb/<share-name>
chgrp <group> /gpfs/<filesystem>/smb/<share-name>
```

### Set permissions

```bash
chmod o-rx /gpfs/<filesystem>/smb/<share-name>
chmod g+ws /gpfs/<filesystem>/smb/<share-name>
```

## User and Access Preparation

If a workflow requires a local service account, create it with your site’s standard UID and group conventions.

### Create a local user

```bash
useradd -u <uid> <user>
```

### Create a local group

```bash
groupadd -g <gid> <group>
```

### Add a user to a group

```bash
usermod -aG <group> <user>
```

## Quick Investigation Set

When you need a compact first-pass check, these are a good starting point:

```bash
mmlscluster
mmlsconfig
mmgetstate -a -L -v
mmhealth cluster show --verbose
mmhealth node eventlog --hour --verbose
mmdiag --all
mmlsfs <filesystem>
mmdf <filesystem>
mmccr lsnodes
```

## Notes
- For troubleshooting workflows, pair this page with [gpfs-troubleshooting.md](gpfs-troubleshooting.md) and [gpfs-notes.md](gpfs-notes.md).
