---
icon: material/bee-flower
---

# Comprehensive Guide: BeeGFS Installation and Configuration

This guide details the installation, configuration, and maintenance of a BeeGFS (Parallel File System) cluster. It covers high-availability setups using Buddy Mirroring for both metadata and storage.

## 1. Cluster Architecture Overview

A standard BeeGFS cluster separates concerns into four distinct node types. Below is a sample architecture used in this guide:

*   **Management Node:** `node01` (Hosts the management daemon)
*   **Metadata Nodes:** `node01`, `node02` (Primary/Secondary for HA)
*   **Storage Nodes:** `node01`, `node02`, `node03`, `node04`
*   **Client Nodes:** `node04`, `client-node`
cku
**Note:** While it is possible to run multiple services on a single node, ensure adequate hardware resources (RAM/CPU/Network) are allocated to prevent bottlenecks.

## 2. Installation Process

### 2.1 Prerequisites
*   **OS:** Enterprise Linux 7/8/9 or compatible.
*   **Kernel Headers:** Required for building client kernel modules.
*   **Network:** Low-latency networking is recommended (preferably 10GbE or faster).
*   **Time Sync:** Ensure NTP/Chrony is running on all nodes.

### 2.2 Package Installation

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

### 2.3 Service Configuration

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

## 3. High Availability: Buddy Mirroring

BeeGFS Buddy Mirroring provides redundancy for metadata and storage targets.

### 3.1 Storage Mirroring

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

### 3.2 Metadata Mirroring

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

## 4. Service Management

### 4.1 Startup Sequence
Services must be started in a specific order.

1.  **Management:** `systemctl start beegfs-mgmtd`
2.  **Metadata:** `systemctl start beegfs-meta`
3.  **Storage:** `systemctl start beegfs-storage`
4.  **Clients:** `systemctl start beegfs-helperd` then `systemctl start beegfs-client`

### 4.2 Cluster Shutdown Script

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

## 5. System Checks & Maintenance

### 5.1 File System Check
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

### 5.2 Useful CLI Commands

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

## 6. Benchmarking

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

## 7. Troubleshooting

### Common Issues
1.  **SELinux:** SELinux often interferes with BeeGFS networking.
    *   Fix: Set `SELINUX=disabled` in `/etc/selinux/config` and reboot.
2.  **Host Resolution:** Ensure all nodes are in `/etc/hosts` or DNS is functioning correctly.
3.  **Client Mount Failures:**
    *   Try setting `sysMountSanityCheckMS=0` in `/etc/beegfs/beegfs-client.conf`.
4.  **Duplicate Target IDs:** When replacing nodes, ensure old target IDs are removed before adding new ones. See the official docs on [Target Management](https://doc.beegfs.io/latest/advanced_topics/target_management.html).

## 8. Complete Removal (Kill Switch)

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

## References
*   [BeeGFS Documentation](https://doc.beegfs.io/latest/quick_start_guide/quick_start_guide.html)
*   [Mirroring Guide](https://doc.beegfs.io/latest/advanced_topics/mirroring.html)
*   [Troubleshooting](https://doc.beegfs.io/latest/trouble_shooting/general.html)