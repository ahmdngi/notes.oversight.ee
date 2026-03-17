---
icon: material/package-variant
tags:
  - sysadmin
  - pxe
  - provisioning
  - boot
---
# HPC Center: PXE Server Implementation Guide

This guide outlines the configuration and workflow of a PXE (Preboot eXecution Environment) server for provisioning nodes in an HPC cluster.

## 1. PXE Boot Process Overview

The PXE boot process differs slightly depending on whether the machine uses BIOS or UEFI firmware.

1.  **Power On:** CPU initializes and loads firmware from ROM.
2.  **Network Boot:** The firmware requests an IP address via DHCP.
3.  **DHCP Response:** The PXE server responds with an IP and the location of the boot file (via TFTP).
4.  **Bootloader Handoff:**
    *   **BIOS:** Loads `pxelinux.0`.
    *   **UEFI:** Loads `shim.efi` and `grub.efi`.
5.  **Kernel Loading:** The bootloader fetches the kernel (`vmlinuz`) and initial RAM disk (`initrd.img`) via TFTP.
6.  **Installation:** The installer retrieves the OS image and Kickstart configuration via HTTP.

---

## 2. Server Configuration

### DHCP Server (`/etc/dhcp/dhcpd.conf`)

The DHCP server directs clients to the correct boot files based on their architecture.

**Host Reservation Example:**
```conf
host node01 {
    hardware ethernet <MAC_ADDRESS>;
    fixed-address <NODE_IP>;
    send host-name "node01";
    filename "pxelinux.0";
}
```

**Architecture Detection (UEFI vs BIOS):**
This configuration checks the client architecture type to serve the correct bootloader.
```conf
class "pxeclients" {
    match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
    next-server <SERVER_IP>;

    if option architecture-type = 00:07 {
        # UEFI Clients
        filename "shim.efi";
    } else {
        # BIOS Clients
        filename "pxelinux/pxelinux.0";
    }
}
```

### TFTP Server Structure
All boot files are served from `/var/lib/tftpboot/`. Recommended structure:

```text
/var/lib/tftpboot/
├── grub.cfg
├── shim.efi
├── grub.efi
├── pxelinux/
│   ├── pxelinux.0
│   ├── menu.c32
│   ├── pxelinux.cfg/
│   │   └── default
│   └── images/
│       ├── centos7/
│       └── rocky9/
└── images/
    ├── centos7/
    └── rocky9/
```

---

## 3. Bootloader Configuration

### BIOS (`/var/lib/tftpboot/pxelinux/pxelinux.cfg/default`)

```conf
default menu.c32
timeout 60
menu title BIOS PXE Installation Menu

label CentOS_7_Node
  kernel images/centos7/vmlinuz
  append initrd=images/centos7/initrd.img inst.repo=http://<SERVER_IP>/centos7/ inst.ks=http://<SERVER_IP>/compute-ks.cfg

label Rocky_9_NAS
  kernel images/rocky9/vmlinuz
  append initrd=images/rocky9/initrd.img inst.repo=http://<SERVER_IP>/rocky9/ inst.ks=http://<SERVER_IP>/nas-ks-r9.cfg
```

### UEFI (`/var/lib/tftpboot/grub.cfg`)

```conf
set timeout=0

menuentry 'CentOS 7' {
  linuxefi images/centos7/vmlinuz ip=dhcp inst.repo=http://<SERVER_IP>/centos7/ inst.ks=http://<SERVER_IP>/compute-ks.cfg
  initrdefi images/centos7/initrd.img
}

menuentry 'Rocky 9' {
  linuxefi images/rocky9/vmlinuz ip=dhcp inst.repo=http://<SERVER_IP>/rocky9/ inst.ks=http://<SERVER_IP>/nas-ks-r9.cfg
  initrdefi images/rocky9/initrd.img
}
```

---

## 4. Adding a New OS (Example: Rocky 9)

To add a new Operating System to the PXE server:

1.  **Prepare Directories:**
    ```bash
    mkdir -p /var/lib/tftpboot/images/rocky9
    mkdir -p /var/www/html/rocky9
    ```

2.  **Copy Boot Files:**
    Copy `vmlinuz` and `initrd.img` from the ISO to the TFTP directory:
    ```bash
    cp /path/to/iso/images/pxeboot/vmlinuz /var/lib/tftpboot/images/rocky9/
    cp /path/to/iso/images/pxeboot/initrd.img /var/lib/tftpboot/images/rocky9/
    ```

3.  **Copy OS Repository:**
    Copy the contents of the ISO to the HTTP directory:
    ```bash
    cp -r /mnt/iso/* /var/www/html/rocky9/
    ```

4.  **Update Bootloaders:**
    Add entries to both `/var/lib/tftpboot/pxelinux/pxelinux.cfg/default` (for BIOS) and `/var/lib/tftpboot/grub.cfg` (for UEFI) as shown in Section 3.

5.  **Create Kickstart File:**
    Place the configuration file (e.g., `nas-ks-r9.cfg`) in `/var/www/html/`.

---

## 5. Kickstart Templates

Below are sanitized templates for automated installation.

### Rocky 8 Template

```kickstart
#version=RHEL8
text

# Installation Source
url --url="http://<SERVER_IP>/rocky8/BaseOS"
repo --name="Minimal" --baseurl=http://<SERVER_IP>/rocky8/Minimal

# System Language and Keyboard
lang en_US.UTF-8
keyboard --xlayouts='us'

# Network Configuration
network  --bootproto=dhcp --device=link --activate

# Timezone
timezone --utc Europe/Tallinn

# User Configuration (ALWAYS CHANGE HASHES)
rootpw --lock
user --groups=wheel --name=admin --password=<encrypted_password_hash> --iscrypted

# Disk Partitioning
ignoredisk --only-use=sda
autopart --type=plain
clearpart --all --initlabel

%packages
@^server-product-environment
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

reboot
```

### CentOS 7 Template (Advanced RAID)

This template demonstrates a robust RAID 1 setup for boot drives.

```kickstart
#version=DEVEL
auth --enableshadow --passalgo=sha512

# Installation Source
url --url="http://<SERVER_IP>/centos7"

# Root Password (Placeholder)
rootpw --iscrypted <encrypted_password_hash>

# System Services
services --enabled="chronyd"
timezone Europe/Tallinn --isUtc

# Bootloader
bootloader --append="crashkernel=auto" --location=mbr --boot-drive=sda

# Partitioning: RAID 1 for OS drives (sda, sdb)
clearpart --all --initlabel --drives=sda,sdb

# Boot Partition (RAID 1)
part raid.01 --fstype="mdmember" --ondisk=sda --size=1024
part raid.02 --fstype="mdmember" --ondisk=sdb --size=1024
raid /boot --device=boot --fstype="ext4" --level=RAID1 raid.01 raid.02

# Root Partition (RAID 1)
part raid.11 --fstype="mdmember" --ondisk=sda --grow --size=1
part raid.12 --fstype="mdmember" --ondisk=sdb --grow --size=1
raid / --device=root --fstype="ext4" --level=RAID1 raid.11 raid.12

%packages
@^minimal
@core
chrony
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end
```

## 6. Machine Reinstallation Workflow

To reinstall a specific machine via PXE:

1.  **Identify Target:** Obtain the MAC address of the target machine.
2.  **Configure DHCP:** Add a host entry in `/etc/dhcp/dhcpd.conf` on the PXE server.
    ```conf
    host node_reinstall {
        hardware ethernet <MAC_ADDRESS>;
        fixed-address <NODE_IP>;
        filename "pxelinux.0";
    }
    ```
3.  **Restart Services:** Restart the DHCP service (`systemctl restart dhcpd`).
4.  **Boot Client:** Boot the target machine. It will pull the installation image defined in the bootloader config.
5.  **Cleanup:** Once installation is complete, remove or comment out the static entry in `dhcpd.conf` to prevent a reinstall loop on the next reboot.

---

## References & Resources

*   [Preparing for a Network Install (CentOS Docs)](https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install/)
*   [Configure PXE Server on CentOS 7](https://www.linuxtechi.com/configure-pxe-installation-server-centos-7/)
*   [Kickstart Syntax Reference](https://linuxhint.com/beginners-kickstart/#1)
*   [UEFI vs BIOS Overview](https://www.freecodecamp.org/news/uefi-vs-bios/)
