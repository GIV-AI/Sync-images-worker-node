# System Architecture

This document describes the high-level architecture of the Image Sync tool.

## Overview

Image Sync is a Bash-based automation tool that ensures container images are synchronized across Kubernetes worker nodes. It runs from a management host and uses SSH to communicate with target nodes.

## Architecture Diagram

```mermaid
flowchart TB
    subgraph Management["Management Host"]
        IS[image-sync<br/>Main Executable]
        LIB[common.sh<br/>Library Module]
        CONF["/etc/image-sync/<br/>image-sync.conf"]
        LOGS["/var/log/giindia/image-sync/<br/>Day-wise Log Files"]
        LOCK["/var/run/<br/>image-sync.lock"]
        
        IS --> LIB
        IS --> CONF
        IS --> LOGS
        IS --> LOCK
    end
    
    subgraph K8sCluster["Kubernetes Cluster"]
        subgraph Node1["Worker Node 1"]
            CR1[containerd/CRI-O<br/>Container Runtime]
            IMG1[(Container<br/>Images)]
            CR1 --- IMG1
        end
        
        subgraph Node2["Worker Node 2"]
            CR2[containerd/CRI-O<br/>Container Runtime]
            IMG2[(Container<br/>Images)]
            CR2 --- IMG2
        end
    end
    
    IS -- "SSH + crictl images" --> CR1
    IS -- "SSH + crictl images" --> CR2
    IS -- "SSH + crictl pull" --> CR1
    IS -- "SSH + crictl pull" --> CR2
    
    style IS fill:#4a90d9,color:#fff
    style LIB fill:#6db33f,color:#fff
    style CONF fill:#f5a623,color:#fff
    style LOGS fill:#7b68ee,color:#fff
    style CR1 fill:#326ce5,color:#fff
    style CR2 fill:#326ce5,color:#fff
```

## Components

| Component | Location | Description |
|-----------|----------|-------------|
| **image-sync** | `/opt/image-sync/bin/` | Main executable script |
| **common.sh** | `/opt/image-sync/lib/` | Shared library (logging, config, SSH helpers) |
| **image-sync.conf** | `/etc/image-sync/` | Configuration file |
| **Log Directory** | `/var/log/giindia/image-sync/` | Day-wise rotating logs |
| **Lock File** | `/var/run/image-sync.lock` | Prevents concurrent execution |
| **Symlink** | `/usr/local/bin/image-sync` | System-wide command access |

## External Dependencies

| Dependency | Purpose |
|------------|---------|
| **SSH** | Secure communication with worker nodes |
| **jq** | JSON parsing for `crictl images` output |
| **crictl** | Container runtime CLI (on worker nodes) |
| **flock** | File locking for concurrency control |

## Execution Model

- **Trigger**: Cron job (recommended: every 30 minutes)
- **Concurrency**: Single instance enforced via flock
- **Parallelism**: Up to `MAX_PARALLEL` concurrent image pulls per node
- **Timeout**: Individual pull operations timeout after `TIME_OUT` seconds

