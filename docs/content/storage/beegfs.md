---
icon: material/bee-flower
tags:
  - storage
  - beegfs
  - parallel-file-system
  - hpc
date: 2025-10-01
---

# Comprehensive Guide: BeeGFS Installation and Configuration

This guide details the installation, configuration, and maintenance of a BeeGFS (Parallel File System) cluster. It covers high-availability setups using Buddy Mirroring for both metadata and storage.

## What does a BeeGFS cluster architecture look like?

A standard BeeGFS cluster separates concerns into four distinct node types. Below is a sample architecture used in this guide:

*   **Management Node:** `node01` (Hosts the management daemon)
*   **Metadata Nodes:** `node01`, `node02` (Primary/Secondary for HA)
*   **Storage Nodes:** `node01`, `node02`, `node03`, `node04`
*   **Client Nodes:** `node04`, `client-node`
cku
**Note:** While it is possible to run multiple services on a single node, ensure adequate hardware resources (RAM/CPU/Network) are allocated to prevent bottlenecks.

## How do I install BeeGFS on RHEL/CentOS?

### What are the prerequisites for BeeGFS?
*   **OS:** Enterprise Linux 7/8/9 or compatible.
*   **Kernel Headers:** Required for building client kernel modules.
*   **Network:** Low-latency networking is recommended (preferably 10GbE or faster).
*   **Time Sync:** Ensure NTP/Chrony is running on all nodes.

### How do I install BeeGFS packages?

**Step 1: Configure Repository**
Run on **all nodes**:
```bash
wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/beegfs_7_1/dists/beegfs-rhel7.repo
yum install kernel-devel
```

**Step 2: Install Service Packages**
Install the specific packages required for each node's role.

*   **Management Node (`node01`):**
    ```bash
    yum install beegfs-mgmtd beegfs-storage beegfs-meta
    ```
*   **Metadata + Storage Node (`node02`):**
    ```bash
    yum install beegfs-meta beegfs-storage
    ```
*   **Dedicated Storage Node (`node03`):**
    ```bash
    yum install beegfs-storage
    ```
*   **Client + Storage Node (`node04`):**
    ```bash
    yum install beegfs-storage beegfs-helperd beegfs-utils beegfs-client
    ```

### How do I configure BeeGFS services?

During setup, replace `<MGMT_IP>` with the IP address of your Management Node.

**Management Node (`node01`) Configuration:**
```bash
# Configure Management Service
/opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/beegfs/mgmtd

# Configure Storage Service (Pointing to local or remote management)
/opt/beegfs/sbin/beegfs-setup-storage -p /data/beegfs/storage -m <MGMT_IP>

# Configure Metadata Service
/opt/beegfs/sbin/beegfs-setup-meta -p /data/beegfs/meta -m <MGMT_IP>
```

**Secondary Node (`node02`) Configuration:**
```bash
# Configure Metadata
/opt/beegfs/sbin/beegfs-setup-meta -p /data/beegfs/meta -m <MGMT_IP>

# Configure Storage
/opt/beegfs/sbin/beegfs-setup-storage -p /data/beegfs/storage -m <MGMT_IP>
```

**Storage Node (`node03`) Configuration:**
```bash
/opt/beegfs/sbin/beegfs-setup-storage -p /data/beegfs/storage -m <MGMT_IP>
```

**Client Node (`node04`) Configuration:**
```bash
# Setup Client
/opt/beegfs/sbin/beegfs-setup-client -m <MGMT_IP>

# Define Mount Point
echo "/mnt/beegfs /etc/beegfs/beegfs-client.conf" >> /etc/beegfs/beegfs-mounts.conf

# Create the mount directory
mkdir -p /mnt/beegfs

# (Optional) Disable sanity check if mount fails during boot
sed -i 's/sysMountSanityCheckMS=.*/sysMountSanityCheckMS=0/' /etc/beegfs/beegfs-client.conf
```

## How do I configure BeeGFS Buddy Mirroring for HA?

BeeGFS Buddy Mirroring provides redundancy for metadata and storage targets.

### How do I configure storage mirroring?

Create automatic mirror groups for storage targets.

**Create Groups:**
```bash
beegfs-ctl --addmirrorgroup --automatic --nodetype=storage
```

**Expected Output:**
```text
New mirror groups:
BuddyGroupID Target type Target
============ =========== =======
           1     primary        1 @ beegfs-storage node01 [ID: 1]
               secondary        2 @ beegfs-storage node02 [ID: 2]
           2     primary        3 @ beegfs-storage node03 [ID: 3]
               secondary        4 @ beegfs-storage node04 [ID: 4]
```

**Verify Configuration:**
```bash
beegfs-ctl --listtargets --mirrorgroups
beegfs-ctl --listmirrorgroups --nodetype=storage
```

**Set Striping Pattern:**
Configure the directory to use the buddy mirror groups.
```bash
# Set pattern to use 2 targets (mirror buddies) with 1M chunk size
beegfs-ctl --setpattern --numtargets=2 --chunksize=1M --pattern=buddymirror /mnt/beegfs

# Verify
beegfs-ctl --getentryinfo /mnt/beegfs
```

### How do I configure metadata mirroring?

Create mirror groups for metadata nodes.

**Create Groups:**
```bash
beegfs-ctl --addmirrorgroup --automatic --nodetype=meta
```

**Activate Metadata Mirroring:**
```bash
beegfs-ctl --mirrormd
```

**Verify:**
```bash
beegfs-ctl --listmirrorgroups --nodetype=meta
```

## How do I manage BeeGFS services?

### What is the correct startup sequence for BeeGFS?
Services must be started in a specific order.

1.  **Management:** `systemctl start beegfs-mgmtd`
2.  **Metadata:** `systemctl start beegfs-meta`
3.  **Storage:** `systemctl start beegfs-storage`
4.  **Clients:** `systemctl start beegfs-helperd` then `systemctl start beegfs-client`

### How do I shut down a BeeGFS cluster?

Use this script to cleanly shut down the cluster. This prevents data corruption.

```bash
#!/bin/bash
# BeeGFS Cluster Shutdown Script
set -e
set -o pipefail

# Configuration Variables
MGMNT_NODE="<MGMT_NODE_IP>"
META_NODES=( "<META_NODE_IP>" )
STORAGE_NODES=( "<STORAGE_NODE1_IP>" "<STORAGE_NODE2_IP>" )
CLIENT_NODES=( "<CLIENT_NODE1_IP>" "<CLIENT_NODE2_IP>" )

# Function to run command on remote host
run_ssh() {
    ssh "root@$1" "$2"
}

# 1. Stop Clients
for host in "${CLIENT_NODES[@]}"; do
    echo "Stopping client on $host..."
    run_ssh "$host" "systemctl stop beegfs-client"
    if run_ssh "$host" "mount | grep -q beegfs"; then
        echo "WARNING: BeeGFS still mounted on $host!"
    fi
done

# 2. Stop Metadata
for host in "${META_NODES[@]}"; do
    echo "Stopping metadata on $host..."
    run_ssh "$host" "systemctl stop beegfs-meta"
done

# 3. Stop Storage
for host in "${STORAGE_NODES[@]}"; do
    echo "Stopping storage on $host..."
    run_ssh "$host" "systemctl stop beegfs-storage"
done

# 4. Stop Management
echo "Stopping management on $MGMNT_NODE..."
run_ssh "$MGMNT_NODE" "systemctl stop beegfs-mgmtd"

echo "Cluster shutdown complete."
```

## How do I check and maintain a BeeGFS cluster?

### How do I run a file system check?
Run these commands from a client or management node.

```bash
# Check read-only (safe)
beegfs-fsck --checkfs --readOnly

# Check and auto-repair
beegfs-fsck --checkfs --automatic

# Check Target States
beegfs-ctl --listtargets --nodetype=meta --state
beegfs-ctl --listtargets --nodetype=storage --state
```

### What BeeGFS CLI commands are commonly used?

```bash
# View Disk Usage
beegfs-df

# Check Server Connectivity
beegfs-check-servers
beegfs-ctl --listnodes --nodetype=storage --nicdetails

# Get File Info
beegfs-ctl --getentryinfo /mnt/beegfs/example_file

# List Reachable Metadata Nodes
beegfs-ctl --listnodes --nodetype=meta --reachable
```

## How do I benchmark BeeGFS performance?

Test the performance of your cluster using built-in tools.

**Write Benchmark:**
Simulate 10 clients writing 200GB data concurrently.
```bash
beegfs-ctl --storagebench --alltargets --write --blocksize=512K --size=200G --threads=10
```

**Create Test File:**
```bash
dd if=/dev/zero of=/mnt/beegfs/test_file bs=1G count=10
```

## What are common BeeGFS issues and how do I fix them?

### Common Issues
1.  **SELinux:** SELinux often interferes with BeeGFS networking.
    *   Fix: Set `SELINUX=disabled` in `/etc/selinux/config` and reboot.
2.  **Host Resolution:** Ensure all nodes are in `/etc/hosts` or DNS is functioning correctly.
3.  **Client Mount Failures:**
    *   Try setting `sysMountSanityCheckMS=0` in `/etc/beegfs/beegfs-client.conf`.
4.  **Duplicate Target IDs:** When replacing nodes, ensure old target IDs are removed before adding new ones. See the official docs on [Target Management](https://doc.beegfs.io/latest/advanced_topics/target_management.html).

## How do I completely remove BeeGFS?

**Warning: This deletes all data and configuration.**

```bash
# Stop Services
systemctl stop beegfs-*.service

# Unmount
umount /mnt/beegfs

# Remove Packages
yum remove -y beegfs-*

# Remove Configs and Data
rm -rf /etc/beegfs
rm -rf /data/beegfs  # Adjust path to your storage directory
rm -rf /mnt/beegfs
```

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "How to install BeeGFS on RHEL/CentOS",
  "description": "Step-by-step guide to installing and configuring a BeeGFS parallel file system cluster on RHEL/CentOS 7/8/9.",
  "step": [
    {
      "@type": "HowToStep",
      "position": 1,
      "name": "Configure the BeeGFS repository",
      "text": "Download and install the BeeGFS repository on all nodes.",
      "url": "https://www.beegfs.io/release/beegfs_7_1/dists/beegfs-rhel7.repo",
      "image": "https://www.beegfs.io/img/logo.png"
    },
    {
      "@type": "HowToStep",
      "position": 2,
      "name": "Install kernel development headers",
      "text": "Install kernel-devel on all nodes to enable building client kernel modules.",
      "url": "https://doc.beegfs.io/latest/quick_start_guide/quick_start_guide.html"
    },
    {
      "@type": "HowToStep",
      "position": 3,
      "name": "Install BeeGFS management service",
      "text": "On the management node (node01), install beegfs-mgmtd, beegfs-storage, and beegfs-meta packages.",
      "url": "https://doc.beegfs.io/latest/quick_start_guide/quick_start_guide.html"
    },
    {
      "@type": "HowToStep",
      "position": 4,
      "name": "Install BeeGFS metadata and storage services",
      "text": "On metadata/storage nodes (node02), install beegfs-meta and beegfs-storage packages."
    },
    {
      "@type": "HowToStep",
      "position": 5,
      "name": "Install dedicated storage service",
      "text": "On dedicated storage nodes (node03), install the beegfs-storage package."
    },
    {
      "@type": "HowToStep",
      "position": 6,
      "name": "Install client packages",
      "text": "On client nodes (node04), install beegfs-storage, beegfs-helperd, beegfs-utils, and beegfs-client packages."
    },
    {
      "@type": "HowToStep",
      "position": 7,
      "name": "Configure the management service",
      "text": "Run /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/beegfs/mgmtd on the management node.",
      "url": "https://doc.beegfs.io/latest/quick_start_guide/quick_start_guide.html"
    },
    {
      "@type": "HowToStep",
      "position": 8,
      "name": "Configure storage and metadata services",
      "text": "Run beegfs-setup-storage and beegfs-setup-meta on the management node, then configure secondary metadata and storage nodes, and finally set up client nodes with beegfs-setup-client."
    }
  ]
}
</script>

## References
*   [BeeGFS Documentation](https://doc.beegfs.io/latest/quick_start_guide/quick_start_guide.html)
*   [Mirroring Guide](https://doc.beegfs.io/latest/advanced_topics/mirroring.html)
*   [Troubleshooting](https://doc.beegfs.io/latest/trouble_shooting/general.html)
