---
icon: material/update
tags:
  - storage
  - gpfs
  - ibm-storage-scale
  - gpl
  - kernel
  - operations
date: 2026-01-15
---

# GPFS GPL Update Runbook

This document describes a repeatable process for rebuilding and distributing the GPFS Portability Layer (GPL) after a Linux kernel update.

## Purpose

When the kernel changes on IBM Storage Scale / GPFS nodes, the GPL module may need to be rebuilt so GPFS can start correctly on the new kernel.

This runbook covers:

- checking whether a GPL rebuild is needed
- rebuilding the GPL package on a designated build node
- distributing the resulting package to other nodes
- handling common reboot and rollout issues

## Example Update Flow

One practical workflow looks like this:

1. A designated build node detects that a new kernel is available.
2. The node reboots into the new kernel.
3. A new GPL package is built on that node.
4. The package is published to a shared location.
5. Other nodes reboot and install the updated GPL package on startup.

## Before You Start

Confirm the following first:

- the new kernel is supported by your Storage Scale version
- kernel headers and development packages are available
- you know which node will be used as the GPL build node

Useful references:

- [IBM Spectrum Scale and Linux compatibility matrix](https://www.ibm.com/support/pages/full-story-ibm-spectrum-scale-and-linux-version-compatibility)
- [Using the autoconfig tool to build the GPFS portability layer](https://www.ibm.com/docs/en/storage-scale/5.1.9?topic=bgplln-using-autoconfig-tool-build-gpfs-portability-layer-linux-nodes)

## Quick Checks

### Check GPFS state

```bash
mmgetstate
```

### Check installed and running kernels

On RHEL-compatible systems:

```bash
yum list kernel
uname -r
```

On Ubuntu:

```bash
ls /boot/vmlinuz*
uname -r
```

## Step 1: Prepare the Build Node

Prepare the selected build node before updating its kernel.

Optional checks:

```bash
hostnamectl
yum versionlock list
```

If kernel version locks are in place and must be removed:

```bash
yum versionlock clear
```

## Step 2: Update the Kernel

Install the new kernel on the build node:

```bash
yum update kernel
```

Useful checks:

```bash
yum list kernel
uname -r
```

If you need to confirm which older kernel was previously used, record it before rebooting.

## Step 3: Reboot the Build Node

Reboot the node so it starts with the new kernel:

```bash
reboot
```

After the system returns, verify the running kernel:

```bash
uname -r
```

## Step 4: Build the New GPFS GPL Package

Run the GPL build command on the build node:

```bash
/usr/lpp/mmfs/bin/mmbuildgpl --build-package
```

Typical success indicators include:

- kernel headers are found
- compiler toolchain is present
- `make rpm` completes successfully
- a `gpfs.gplbin-...rpm` package is produced

The output package is commonly written under a path similar to:

```text
/root/rpmbuild/RPMS/x86_64/gpfs.gplbin-<kernel-version>-<scale-version>.x86_64.rpm
```

If the build fails due to a Kbuild-related issue, see:

- [IBM retbleed / Kbuild issue note](https://www.ibm.com/support/pages/ibm-spectrum-scale-alert-retbleed-kernel-patch-may-break-mmbuildgpl-certain-scale-releases)

## Step 5: Activate the New GPL on the Build Node

After a successful build, start GPFS with the new GPL:

```bash
mmstartup
```

Then confirm cluster state:

```bash
mmgetstate
```

## Step 6: Publish the Built Package

One simple approach is to publish the build artifacts over NFS from the build node.

### Server-side example

Install and verify NFS services:

```bash
sudo yum install -y nfs-utils
sudo systemctl status nfs-server
sudo systemctl status rpcbind
sudo systemctl status nfs-mountd
sudo systemctl status nfs-idmapd
```

Allow firewall services:

```bash
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --reload
```

Create the export directory:

```bash
mkdir -p /buildGPL
```

Example `/etc/exports` entry:

```exports
/buildGPL <cluster-subnet>(ro,sync,no_root_squash)
```

Reload exports:

```bash
exportfs -ra
showmount -e localhost
```

### Client-side example

Check the export:

```bash
showmount -e <nfs-server-ip>
```

Mount it locally:

```bash
mkdir -p /mnt/buildGPL
mount -t nfs <nfs-server-ip>:/buildGPL /mnt/buildGPL
df -h /mnt/buildGPL
```

## Step 7: Roll Out to Other Nodes

If you use helper scripts from an admin or base node, keep them generic and parameterized.

A common pattern is:

- a pre-reboot script checks whether an update is needed
- a scheduled reboot is triggered
- a startup script installs the latest GPL package from `/mnt/buildGPL`

## Rocky Linux Notes

If the target nodes use Rocky Linux or another RHEL-compatible distribution, ensure the matching kernel packages are installed:

```bash
sudo yum install kernel-devel
sudo dnf install kernel-headers-$(uname -r)
```

Reference:

- [Linux Capable: install kernel headers on Rocky Linux](https://www.linuxcapable.com/how-to-install-linux-kernel-headers-on-rocky-linux/)

## Known Operational Issues

### Some nodes may not return after reboot

In some environments, a node may come back from reboot in an unhealthy state. If that happens:

1. confirm the node is not returning to service
2. use your standard recovery procedure for the affected hardware
3. verify it boots the intended kernel

## Recommended Cleanup

After the rollout:

- confirm all target nodes are on the expected kernel
- confirm GPFS starts cleanly on each node
- update any version locks if your policy requires them
- archive the built GPL package with a clear version label

## References

- [IBM Spectrum Scale Linux compatibility](https://www.ibm.com/support/pages/full-story-ibm-spectrum-scale-and-linux-version-compatibility)
- [IBM Storage Scale FAQ](https://www.ibm.com/docs/en/storage-scale/5.1.1?topic=spectrum-scale-faq#fsi)
- [IBM: build GPFS portability layer on Linux nodes](https://www.ibm.com/docs/en/storage-scale/5.1.9?topic=bgplln-using-autoconfig-tool-build-gpfs-portability-layer-linux-nodes)
- [Stealthbits: create and mount NFS exports on CentOS Linux](https://stealthbits.com/blog/create-mount-nfs-exports-centos-linux/)
- [BeeGFS NFS export notes](https://doc.beegfs.io/latest/advanced_topics/nfs_export.html)
