---
icon: material/export
tags:
  - storage
  - gpfs
  - ibm-storage-scale
  - ces
  - smb
  - nfs
  - backup
date: 2026-02-01
---

# GPFS CES Configuration and Backup

This page collects practical notes for working with IBM Storage Scale Cluster Export Services (CES), with a focus on service checks, SMB configuration handling, and backup planning.

## What CES Does

When a CES node leaves the GPFS cluster, CES IP addresses assigned to that node can be redistributed to other healthy CES nodes. The exact behavior depends on the configured address distribution policy and current service state.

CES is commonly used for:

- NFS exports
- SMB shares
- protocol service failover
- protocol configuration management

## Quick CES Checks

These are useful first checks when validating CES behavior or investigating a failover issue.

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

### Show CES component state across the cluster

```bash
mmces state cluster ces
```

### List CES events

```bash
mmces events list -a
```

### Move a CES IP manually

```bash
mmces address move --ces-ip <ces-ip> --ces-node <ces-node>
```

## CES Troubleshooting Notes

If CES health information appears inconsistent:

```bash
mmhealth node show
mmhealth cluster show ces
mmces state show
mmces state cluster ces
```

If `mmhealth` metadata appears stale or out of sync, a resync may help:

```bash
mmhealth node show --resync
```

Use that carefully and confirm cluster health again afterward.

## SMB Configuration in CES

In CES deployments, SMB uses GPFS-managed service components such as:

- `gpfs-smb`
- `gpfs-winbind`

### Important Configuration Rule

Make changes in the main Samba configuration source used for import, not in generated GPFS-managed runtime files that may be overwritten later.

For example:

- source config: `/etc/samba/smb.conf`
- generated or managed config: `/var/mmfs/ces/smb.conf`

Do not edit the generated file directly unless you fully understand the regeneration workflow.

## Example SMB Configuration Pattern

The exact values will vary by environment, but a typical Active Directory backed CES SMB configuration includes:

- AD workgroup and realm settings
- idmap backend configuration
- Kerberos settings
- default home directory and shell templates
- encryption settings
- one or more managed share definitions

## Applying SMB Configuration Changes

After updating the source configuration:

### Validate the config

```bash
testparm
```

### Import it into the CES-managed configuration

```bash
net conf import /etc/samba/smb.conf
```

### Restart CES SMB services

Restart the services in the correct order so name mapping and SMB state come back cleanly:

```bash
systemctl restart gpfs-smb
systemctl restart gpfs-winbind
```

A compact one-liner looks like:

```bash
net conf import /etc/samba/smb.conf && systemctl restart gpfs-smb && systemctl restart gpfs-winbind
```

## SMB Logs and Diagnostics

Useful log files include:

```text
/var/adm/ras/log.smbd
/var/adm/ras/log.smbd.old
/var/adm/ras/log.winbindd
/var/adm/ras/log.winbindd-idmap
/var/adm/ras/log.winbindd-dc-connect
```

Useful commands:

```bash
tail -F /var/adm/ras/log.smbd
tail -F /var/adm/ras/log.winbindd
tail -F /var/adm/ras/log.winbindd-idmap
tail -F /var/adm/ras/log.winbindd-dc-connect
grep smbd /var/log/messages
grep winbindd /var/log/messages
```

### Cache location example

```text
/var/lib/gpfs-samba/winbindd_idmap.tdb
```

## Preparing a New SMB Share

Linux-side preparation often looks like this:

### Create the share directory

```bash
mkdir /gpfs/<filesystem>/smbgroup/<share-name>
```

### Set owner and group

```bash
chown <user> /gpfs/<filesystem>/smbgroup/<share-name>
chgrp <group> /gpfs/<filesystem>/smbgroup/<share-name>
```

### Set permissions

```bash
chmod o-rx /gpfs/<filesystem>/smbgroup/<share-name>
chmod g+ws /gpfs/<filesystem>/smbgroup/<share-name>
```

## CES and Protocol Configuration Backup

Backups for a GPFS environment should include more than file data alone. In practice, administrators usually protect at least these categories:

1. Cluster configuration data
2. File system configuration data
3. File system contents
4. Protocol configuration data

### Why CCR matters

When the Cluster Configuration Repository (CCR) is used, the master copy of configuration data is stored redundantly across quorum nodes instead of relying on a separate primary or backup configuration server.

That improves resilience for GPFS administrative metadata as long as a quorum of CCR participants remains available.

## Cluster Configuration Backup

At a minimum, save:

- the output of `mmlscluster`
- a CCR backup or `mmsdrfs`-equivalent repository backup, depending on repository type
- any operational snapshots or supporting restore data your site depends on

### Record cluster configuration

```bash
mmlscluster > /path/to/backup/mmlscluster.txt
```

## CCR Backup and Restore

If your environment uses an `mmsdrbackup` user exit workflow, document and automate it clearly.

### Backup

Example:

```bash
/path/to/mmsdrbackup-wrapper <backup-version> CCR
```

The implementation details depend on how your site configured the backup wrapper around the user exit.

### Restore

```bash
mmsdrrestore -F <backup-file>
```

Before using `mmsdrrestore`, confirm:

- the backup file is valid
- the target nodes are correct
- you understand the recovery scope

## File System Backup with SOBAR

For disaster recovery scenarios, GPFS file system configuration and image backup workflows often use:

- `mmbackupconfig`
- `mmimgbackup`
- `mmrestoreconfig`
- `mmimgrestore`

### Important ordering

Run:

1. `mmbackupconfig`
2. snapshot creation
3. `mmimgbackup`

For restore:

1. `mmrestoreconfig`
2. mount read-only if required
3. `mmimgrestore`
4. restore quotas if needed
5. remount read-write

### What `mmbackupconfig` captures

The backup file can include items such as:

- NSD and disk configuration
- storage pools
- filesets and junctions
- policy rules
- quota definitions and limits
- file system attributes

It does not back up normal user file data.

## Example SOBAR Backup Workflow

### Back up file system configuration

```bash
mmbackupconfig <filesystem> -o /path/to/backup/mmbackupconfig-output
```

### Create a global snapshot

```bash
mmcrsnapshot <filesystem> <snapshot-name>
```

### Back up the image

```bash
mmimgbackup <filesystem> -S <snapshot-name> -g /path/to/backup -N <node-list>
```

## Example SOBAR Restore Workflow

### Optional: generate a report file for recreation planning

```bash
mmrestoreconfig <filesystem> -i /path/to/mmbackupconfig-output -F /path/to/reportfile
```

### Restore essential configuration

```bash
mmrestoreconfig <filesystem> -i /path/to/mmbackupconfig-output --image-restore
```

### Mount read-only if required for image restore

```bash
mmmount <filesystem> -o ro
```

### Restore the image

```bash
mmimgrestore <filesystem> /path/to/<snapshot-name>
```

### Unmount after restore

```bash
mmumount <filesystem>
```

### Restore quotas if needed

```bash
mmrestoreconfig <filesystem> -i /path/to/mmbackupconfig-output -Q only
```

### Mount read-write again

```bash
mmmount <filesystem>
```

## Recommended Backup Checklist

- export `mmlscluster` output regularly
- maintain a tested CCR backup workflow
- back up SMB/NFS protocol configuration in a repeatable way
- document where imported Samba config is stored
- include `mmbackupconfig` outputs in file system backup procedures
- pair image backups with consistent snapshots
- periodically test restore steps in a non-production environment

## References

- IBM Storage Scale Administration Guide sections on CES, CCR, SMB, and SOBAR
- [IBM Spectrum Scale and Linux compatibility matrix](https://www.ibm.com/support/pages/full-story-ibm-spectrum-scale-and-linux-version-compatibility)
