# Image Sync

Synchronize container images between two Kubernetes worker nodes, ensuring image availability and consistency across nodes.

## Image Sources

- **Harbor images** → prefix: `bcm11` (headnode-hosted Harbor registry)
- **NVIDIA NGC images** → prefix: `nvcr.io/nvidia`

---

## Table of Contents

- [Project Structure](#project-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Logs](#logs)
- [Cron Automation](#cron-automation)
- [Uninstallation](#uninstallation)
- [Requirements](#requirements)

---

## Project Structure

```
image-sync/
├── bin/
│   └── image-sync           # Main executable
├── lib/
│   └── common.sh            # Shared library (logging, config, SSH)
├── conf/
│   └── image-sync.conf      # Default configuration template
├── test/                    # Test documentation
├── install.sh               # Installation script
├── uninstall.sh             # Uninstallation script
└── README.md
```

### Installation Paths

| Path | Purpose |
|------|---------|
| `/opt/image-sync/` | Application installation (bin/, lib/) |
| `/etc/image-sync/` | System configuration |
| `/var/log/giindia/image-sync/` | Application logs |
| `/usr/local/bin/image-sync` | Command symlink |

---

## Installation

### Prerequisites

- Root access (sudo)
- SSH key-based authentication to worker nodes
- `jq` command-line JSON processor
- `crictl` on worker nodes

### Install

```bash
# Clone or download the repository
cd image-sync

# Run installer as root
sudo ./install.sh
```

The installer will:
1. Copy application files to `/opt/image-sync/`
2. Create configuration directory at `/etc/image-sync/`
3. Create log directory at `/var/log/giindia/image-sync/`
4. Create command symlink at `/usr/local/bin/image-sync`

---

## Configuration

Configuration file: `/etc/image-sync/image-sync.conf`

```bash
# REQUIRED: Worker node hostnames (SSH accessible)
NODE1="k8s-worker1"
NODE2="k8s-worker2"

# REQUIRED: Primary image prefix to sync
PREFIX1="bcm11"

# REQUIRED: Logging directory
LOG_DIR="/var/log/giindia/image-sync"

# OPTIONAL: Secondary image prefix (leave empty to disable)
PREFIX2="nvcr.io/nvidia"

# OPTIONAL: Timeout for pulling a single image (default: 1800 seconds)
TIME_OUT=1800

# OPTIONAL: Maximum parallel pulls per node (default: 4)
MAX_PARALLEL=4
```

### Configuration Notes

- `NODE1` and `NODE2`: Must be accessible via SSH with key-based authentication
- `PREFIX1`: Replace `bcm11` with your Harbor registry hostname
- `TIME_OUT`: Prevents stuck downloads; pulls exceeding this are terminated
- `MAX_PARALLEL`: Higher values speed up sync but increase load

---

## Usage

### Manual Execution

```bash
# Run as root (requires access to lock file and logs)
sudo image-sync
```

### What It Does

1. Acquires exclusive lock (prevents concurrent runs)
2. Loads and validates configuration
3. Checks SSH connectivity to both nodes
4. Fetches image lists using `crictl images -o json`
5. Filters images by configured prefixes
6. Identifies missing images on each node
7. Pulls missing images in parallel
8. Logs results and summary

---

## Logs

Log directory: `/var/log/giindia/image-sync/`

| File | Description |
|------|-------------|
| `image-sync.log` | Full execution logs |
| `success_images.log` | Successfully pulled images |
| `failed_images.log` | Failed image pulls |
| `cron.log` | Output when run via cron |

---

## Cron Automation

The image-sync tool is designed to run periodically via cron to keep worker nodes synchronized.

### Setting Up Cron Job

**Step 1:** Open the root crontab editor:

```bash
sudo crontab -e
```

**Step 2:** Add one of the following cron entries at the end of the file:

```bash
# Recommended: Every 30 minutes
*/30 * * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1

# Alternative: Every hour
0 * * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1

# Alternative: Every 6 hours
0 */6 * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1

# Alternative: Daily at 2 AM
0 2 * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1
```

**Step 3:** Save and exit the editor (`:wq` in vim, `Ctrl+X` then `Y` in nano).

**Step 4:** Verify the cron job is installed:

```bash
sudo crontab -l
```

### Cron Format Reference

```
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-6, Sunday=0)
│ │ │ │ │
* * * * * command
```

### Monitoring Cron Execution

Check cron output:

```bash
sudo tail -f /var/log/giindia/image-sync/cron.log
```

Check last sync results:

```bash
sudo tail -50 /var/log/giindia/image-sync/image-sync.log
```

### Disabling Cron Job

To temporarily disable the cron job:

```bash
sudo crontab -e
# Comment out the line by adding # at the beginning
# */30 * * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1
```

---

## Uninstallation

### Standard Uninstall

Removes application files, preserves configuration and logs:

```bash
sudo ./uninstall.sh
```

### Complete Removal

Removes everything including configuration and logs:

```bash
sudo ./uninstall.sh --purge
```

---

## Requirements

- **OS**: Linux with Bash 4.0+
- **SSH**: Key-based authentication to worker nodes
- **Tools**: `jq`, `ssh`, `flock`
- **On worker nodes**: `crictl`, `timeout`
- **Permissions**: Root access for installation and execution

---

## How It Works

```
┌─────────────────┐                    ┌─────────────────┐
│   Node 1        │                    │   Node 2        │
│   (k8s-worker1) │                    │   (k8s-worker2) │
│                 │                    │                 │
│  ┌───────────┐  │                    │  ┌───────────┐  │
│  │ Images A  │  │    Compare &       │  │ Images B  │  │
│  │ Images B  │◄─┼────Pull Missing────┼─►│ Images C  │  │
│  │           │  │                    │  │           │  │
│  └───────────┘  │                    │  └───────────┘  │
│                 │                    │                 │
│  After sync:    │                    │  After sync:    │
│  A, B, C        │                    │  A, B, C        │
└─────────────────┘                    └─────────────────┘
```

The script ensures both nodes have identical image sets by:
1. Pulling images from Node2 that are missing on Node1
2. Pulling images from Node1 that are missing on Node2

---

## Troubleshooting

### SSH Connection Failed

```
ERROR: Cannot connect to k8s-worker1 via SSH
```

**Solution**: Ensure SSH key-based authentication is configured:
```bash
ssh-copy-id k8s-worker1
ssh-copy-id k8s-worker2
```

### Lock File Error

```
ERROR: Script already running. Lock active: /var/run/image-sync.lock
```

**Solution**: Another instance is running. Wait for it to complete or remove stale lock:
```bash
sudo rm /var/run/image-sync.lock
```

### Missing Dependencies

```
ERROR: Missing required dependencies: jq
```

**Solution**: Install missing tools:
```bash
# Debian/Ubuntu
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

---

## License

Copyright (c) Global Infoventures - GRIL Team. All rights reserved.
