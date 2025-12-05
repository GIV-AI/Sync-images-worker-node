# Dependency Diagram

This document illustrates the dependency relationships between components and external tools.

## Module Dependencies

```mermaid
flowchart TD
    subgraph Scripts["Shell Scripts"]
        BIN["bin/image-sync<br/>(Main Executable)"]
        LIB["lib/common.sh<br/>(Library Module)"]
        INST["install.sh"]
        UNINST["uninstall.sh"]
    end
    
    subgraph Config["Configuration"]
        CONF["conf/image-sync.conf"]
    end
    
    subgraph SystemTools["System Tools (Management Host)"]
        SSH["ssh"]
        JQ["jq"]
        FLOCK["flock"]
        MKTEMP["mktemp"]
        FIND["find"]
        COMM["comm"]
    end
    
    subgraph RemoteTools["Remote Tools (Worker Nodes)"]
        CRICTL["crictl"]
        TIMEOUT["timeout"]
    end
    
    BIN -->|sources| LIB
    BIN -->|reads| CONF
    
    INST -->|validates| BIN
    INST -->|validates| LIB
    INST -->|copies| CONF
    
    LIB -->|uses| SSH
    LIB -->|uses| JQ
    
    BIN -->|uses| FLOCK
    BIN -->|uses| MKTEMP
    BIN -->|uses| COMM
    
    LIB -->|uses| FIND
    
    BIN -->|"SSH executes"| CRICTL
    BIN -->|"SSH executes"| TIMEOUT
    
    style BIN fill:#4a90d9,color:#fff
    style LIB fill:#6db33f,color:#fff
    style CONF fill:#f5a623,color:#fff
    style INST fill:#9b59b6,color:#fff
    style UNINST fill:#9b59b6,color:#fff
```

## Dependency Matrix

### Runtime Dependencies

| Component | Depends On | Type |
|-----------|-----------|------|
| `image-sync` | `common.sh` | Source (library) |
| `image-sync` | `image-sync.conf` | Configuration |
| `image-sync` | `ssh` | System tool |
| `image-sync` | `flock` | Concurrency control |
| `image-sync` | `comm` | Set comparison |
| `image-sync` | `mktemp` | Temp file creation |
| `common.sh` | `ssh` | Remote execution |
| `common.sh` | `jq` | JSON parsing |
| `common.sh` | `find` | Log cleanup |

### Remote Dependencies (on Worker Nodes)

| Tool | Purpose |
|------|---------|
| `crictl` | List and pull container images |
| `timeout` | Enforce pull time limits |

## Function Dependencies

```mermaid
flowchart LR
    subgraph ImageSync["image-sync (main)"]
        MAIN["main()"]
        ACQ["acquire_lock()"]
        PULL["pull_images_parallel()"]
        PULLONE["pull_image()"]
        EXTRACT["extract_images()"]
        ESCAPE["escape_regex()"]
    end
    
    subgraph CommonLib["common.sh"]
        LOADCFG["load_config()"]
        VALCFG["validate_config()"]
        INITLOG["init_logging()"]
        CHKDEP["check_dependencies()"]
        CHKSSH["check_ssh()"]
        GETIMG["get_images()"]
        LOG["log_*()"]
        CLEANUP["cleanup_temp_files()"]
    end
    
    MAIN --> ACQ
    MAIN --> LOADCFG
    MAIN --> VALCFG
    MAIN --> INITLOG
    MAIN --> CHKDEP
    MAIN --> CHKSSH
    MAIN --> GETIMG
    MAIN --> EXTRACT
    MAIN --> PULL
    
    PULL --> PULLONE
    PULLONE --> LOG
    EXTRACT --> ESCAPE
    
    style MAIN fill:#4a90d9,color:#fff
    style LOADCFG fill:#6db33f,color:#fff
    style VALCFG fill:#6db33f,color:#fff
```

## Configuration Parameters

| Parameter | Used By | Default |
|-----------|---------|---------|
| `NODE1`, `NODE2` | `check_ssh()`, `get_images()`, `pull_image()` | Required |
| `PREFIX1`, `PREFIX2` | `extract_images()` | Required / Optional |
| `LOG_DIR` | `init_logging()` | Required |
| `MAX_PARALLEL` | `pull_images_parallel()` | 4 |
| `TIME_OUT` | `pull_image()` | 1800s |
| `SSH_CONNECT_TIMEOUT` | `check_ssh()`, `get_images()` | 10s |
| `LOG_LEVEL` | `log_message()` | INFO |
| `MAX_LOG_SIZE` | `safe_append_log()` | 10MB |
| `LOG_RETENTION_DAYS` | `cleanup_old_logs()` | 30 |


