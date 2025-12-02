# Sync-images-worker-node

This project provides a **shell script** to synchronize container images between two Kubernetes worker nodes, ensuring image availability and **consistency across nodes**.

---

## Image Sources

- Harbor images → prefix: `bcm11` (headnode-hosted Harbor registry)
- NVIDIA NGC images → prefix: `nvcr.io/nvidia`

Included files:

| File              | Description        |
|-------------------|--------------------|
| `image-sync.sh`   | Main script        |
| `image-sync.conf` | Configuration file |

---

## 📑 Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Logs](#logs)
- [Running](#running)
- [Cron Automation](#cron-automation)
- [Requirements](#requirements)
- [Summary](#summary)

---

## Overview

`image-sync.sh` does the following:

1. Loads config from `image-sync.conf`
2. Checks SSH connectivity
3. Gets image lists using `crictl images -o json`
4. Filters by prefixes
5. Finds missing images between nodes
6. Pulls missing images in parallel
7. Logs success/failure results

---

## Configuration

File: `image-sync.conf`

```bash
# Worker node hostnames
NODE1="k8s-worker1"
NODE2="k8s-worker2"

# Image prefixes to sync
# bcm11 → Harbor registry images (hosted on headnode)
# nvcr.io/nvidia → NVIDIA NGC images
PREFIX1="bcm11"
PREFIX2="nvcr.io/nvidia"

# Logging directory
LOG_DIR="/var/log/giindia/sync-worker-node-images"

# Maximum time (in seconds) allowed for pulling an image.
# Any pull exceeding this limit will be terminated and logged as TIMEOUT.
TIME_OUT=1800

# Maximum number of parallel pulls
MAX_PARALLEL=4
```

> ⚠ Update `NODE1` and `NODE2` with your Kubernetes worker node hostnames.  
> ⚠ Replace `bcm11` in `PREFIX1` with your headnode's hostname (Harbor registry host).  
> ⚠ `LOG_DIR` sets the directory where logs will be stored.  
> ⚠ `TIME_OUT` prevents deadlocks and long-running stuck image downloads.  
> ⚠ `MAX_PARALLEL` allows up to 4 simultaneous image pulls on a node.

---

## Logs

Log files are stored in:

```
/var/log/giindia/sync-worker-node-images/
```

| File | Description |
|------|------------|
| `image-sync.log` | Full execution logs |
| `success_images.log` | Images successfully pulled log |
| `failed_images.log` | Images that failed to pull log |
| `cron.log` | Log output when run via cron scheduler |


---

## Running

Make executable:

```bash
chmod +x image-sync.sh
./image-sync.sh
```

---

## Cron Automation

Open editor:

```bash
crontab -e
```

Daily at 2AM:

```bash
0 2 * * * /path/to/image-sync.sh >> /var/log/giindia/sync-worker-node-images/cron.log 2>&1
```

Every 6 hours:

```bash
0 */6 * * * /path/to/image-sync.sh
```

---

## Requirements

- SSH access to both nodes
- `crictl` installed
- `jq` installed
- Write access to:

```
/var/log/giindia/sync-worker-node-images/
```

---

## Summary

This tool ensures Kubernetes worker nodes stay synchronized with required images from:

- Harbor (`bcm11`)
- NVIDIA NGC (`nvcr.io/nvidia`)

---
