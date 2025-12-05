# Image Sync

Synchronize container images between two Kubernetes worker nodes, ensuring image availability and consistency across nodes.

**Version:** 2.0.0

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
├── tests/                   # Test documentation
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

### Required Settings

```bash
# Worker node hostnames (SSH accessible)
NODE1="k8s-worker1"
NODE2="k8s-worker2"

# Primary image prefix to sync
PREFIX1="bcm11"

# Logging directory
LOG_DIR="/var/log/giindia/image-sync"
```

### Optional Settings

```bash
# Secondary image prefix (leave empty to disable)
PREFIX2="nvcr.io/nvidia"

# Timeout for pulling a single image (default: 1800 seconds / 30 minutes)
TIME_OUT=1800

# Maximum parallel pulls per node (default: 4)
MAX_PARALLEL=4

# SSH connection timeout in seconds (default: 10)
SSH_CONNECT_TIMEOUT=10
```

### Log Management Settings

```bash
# Log level threshold: DEBUG, INFO, WARNING, ERROR (default: INFO)
LOG_LEVEL="INFO"

# Maximum size per daily log file in bytes (default: 10485760 / 10 MB)
MAX_LOG_SIZE=10485760

# Days to retain log files before automatic cleanup (default: 30)
LOG_RETENTION_DAYS=30
```

### Configuration Notes

- `NODE1` and `NODE2`: Must be accessible via SSH with key-based authentication
- `PREFIX1`: Replace `bcm11` with your Harbor registry hostname
- `TIME_OUT`: Prevents stuck downloads; pulls exceeding this are terminated
- `MAX_PARALLEL`: Higher values speed up sync but increase load
- `LOG_LEVEL`: Set to `DEBUG` for verbose output during troubleshooting
- `MAX_LOG_SIZE`: Once reached, no more entries are written for that day
- `LOG_RETENTION_DAYS`: Old log files are automatically deleted on startup

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

Logs are created daily with date suffixes for automatic rotation and retention management.

| File Pattern | Description |
|--------------|-------------|
| `image-sync-YYYY-MM-DD.log` | Full execution logs for that day |
| `success_images-YYYY-MM-DD.log` | Successfully pulled images |
| `failed_images-YYYY-MM-DD.log` | Failed image pulls |
| `cron.log` | Output when run via cron |

### Log Retention

- Old log files (older than `LOG_RETENTION_DAYS`) are automatically cleaned up on each run
- Daily log files have a maximum size limit (`MAX_LOG_SIZE`) to prevent disk space issues

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

Check today's sync results:

```bash
sudo tail -50 /var/log/giindia/image-sync/image-sync-$(date +%Y-%m-%d).log
```

Check recent successful pulls:

```bash
sudo tail -20 /var/log/giindia/image-sync/success_images-$(date +%Y-%m-%d).log
```

Check recent failures:

```bash
sudo cat /var/log/giindia/image-sync/failed_images-$(date +%Y-%m-%d).log
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

### Image Pull Timeout

```
ERROR: TIMEOUT: Pulling <image> on <node> exceeded 1800s
```

**Solution**: Increase `TIME_OUT` in configuration if large images are expected:
```bash
sudo nano /etc/image-sync/image-sync.conf
# Set TIME_OUT=3600 for 1 hour timeout
```

### Debug Mode

For verbose logging during troubleshooting:
```bash
sudo nano /etc/image-sync/image-sync.conf
# Set LOG_LEVEL="DEBUG"
```

---

## License

Copyright (c) Global Infoventures - GRIL Team. All rights reserved.
