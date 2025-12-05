# Test Prerequisites and Environment Setup

## Test ID: PREREQ-001 to PREREQ-010

---

## Overview

Before executing any tests, ensure the test environment meets all requirements listed below.

---

## Required Infrastructure

### Test Nodes

| Component | Requirement | Verification Command |
|-----------|-------------|---------------------|
| Worker Node 1 | Kubernetes worker with containerd | `kubectl get nodes` |
| Worker Node 2 | Kubernetes worker with containerd | `kubectl get nodes` |
| Test Machine | Linux with bash 4+ | `bash --version` |

---

## PREREQ-001: SSH Access Verification

### Description
Verify passwordless SSH access to both worker nodes.

### Test Steps

1. From the test machine, execute:
   ```bash
   ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-worker1 "echo ok"
   ```

2. Execute for second node:
   ```bash
   ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-worker2 "echo ok"
   ```

### Expected Result
- Both commands return `ok` without password prompt
- Exit code is 0

### Pass Criteria
- [ ] Node 1 SSH successful
- [ ] Node 2 SSH successful

---

## PREREQ-002: crictl Installation

### Description
Verify crictl is installed and accessible on both nodes.

### Test Steps

1. Check crictl on Node 1:
   ```bash
   ssh k8s-worker1 "which crictl && crictl version"
   ```

2. Check crictl on Node 2:
   ```bash
   ssh k8s-worker2 "which crictl && crictl version"
   ```

### Expected Result
- crictl path is displayed
- Version information is shown

### Pass Criteria
- [ ] crictl installed on Node 1
- [ ] crictl installed on Node 2

---

## PREREQ-003: jq Installation

### Description
Verify jq JSON processor is installed on test machine.

### Test Steps

```bash
which jq && jq --version
```

### Expected Result
- jq path and version displayed

### Pass Criteria
- [ ] jq is installed and accessible

---

## PREREQ-004: Bash Version

### Description
Verify bash version 4+ for mapfile support.

### Test Steps

```bash
bash --version | head -1
```

### Expected Result
- Bash version 4.0 or higher

### Pass Criteria
- [ ] Bash version >= 4.0

---

## PREREQ-005: Lock File Directory

### Description
Verify /var/run directory exists and is writable.

### Test Steps

```bash
ls -la /var/run/ | head -5
touch /var/run/test-lock-$$ && rm /var/run/test-lock-$$
echo "Exit code: $?"
```

### Expected Result
- Directory exists
- Test file creation succeeds (exit code 0)

### Pass Criteria
- [ ] /var/run is writable

---

## PREREQ-006: Log Directory Creation

### Description
Verify log directory can be created.

### Test Steps

```bash
mkdir -p /var/log/giindia/sync-worker-node-images
ls -la /var/log/giindia/
```

### Expected Result
- Directory is created successfully
- Directory has appropriate permissions

### Pass Criteria
- [ ] Log directory created
- [ ] Directory is writable

---

## PREREQ-007: Configuration File

### Description
Verify configuration file exists and is readable.

### Test Steps

```bash
ls -la image-sync.conf
cat image-sync.conf
```

### Expected Result
- File exists
- Contains NODE1, NODE2, PREFIX1, PREFIX2, LOG_DIR, TIME_OUT, MAX_PARALLEL

### Pass Criteria
- [ ] Config file exists
- [ ] All variables defined

---

## PREREQ-008: Script Permissions

### Description
Verify script has execute permissions.

### Test Steps

```bash
ls -la image-sync.sh
file image-sync.sh
```

### Expected Result
- Execute permission set (x flag)
- Identified as Bash script

### Pass Criteria
- [ ] Script is executable

---

## PREREQ-009: Network Connectivity

### Description
Verify network access to image registries.

### Test Steps

1. Test Harbor registry access:
   ```bash
   ssh k8s-worker1 "curl -s -o /dev/null -w '%{http_code}' https://bcm11/v2/"
   ```

2. Test NVIDIA NGC access:
   ```bash
   ssh k8s-worker1 "curl -s -o /dev/null -w '%{http_code}' https://nvcr.io/v2/"
   ```

### Expected Result
- HTTP 200 or 401 (authentication required but reachable)

### Pass Criteria
- [ ] Harbor registry reachable
- [ ] NVIDIA NGC reachable

---

## PREREQ-010: Existing Images

### Description
Verify nodes have some images for testing.

### Test Steps

1. List images on Node 1:
   ```bash
   ssh k8s-worker1 "crictl images" | head -10
   ```

2. List images on Node 2:
   ```bash
   ssh k8s-worker2 "crictl images" | head -10
   ```

### Expected Result
- Images are listed on both nodes

### Pass Criteria
- [ ] Node 1 has images
- [ ] Node 2 has images

---

## Test Data Setup

### Creating Test Images (Optional)

If you need to create specific test scenarios with known images:

```bash
# On Node 1 - Pull a test image
ssh k8s-worker1 "crictl pull bcm11/test-image:v1"

# Verify it's NOT on Node 2
ssh k8s-worker2 "crictl images | grep test-image"
```

---

## Environment Cleanup Checklist

After testing, cleanup test artifacts:

- [ ] Remove test lock files: `rm -f /var/run/image-sync.lock`
- [ ] Archive test logs: `tar -cvzf test-logs-$(date +%Y%m%d).tar.gz /var/log/giindia/sync-worker-node-images/`
- [ ] Remove test images if created
- [ ] Reset configuration file to production values

---

## Prerequisites Verification Summary

| Test ID | Description | Status | Tester | Date |
|---------|-------------|--------|--------|------|
| PREREQ-001 | SSH Access | | | |
| PREREQ-002 | crictl Installation | | | |
| PREREQ-003 | jq Installation | | | |
| PREREQ-004 | Bash Version | | | |
| PREREQ-005 | Lock File Directory | | | |
| PREREQ-006 | Log Directory | | | |
| PREREQ-007 | Configuration File | | | |
| PREREQ-008 | Script Permissions | | | |
| PREREQ-009 | Network Connectivity | | | |
| PREREQ-010 | Existing Images | | | |

**All prerequisites must PASS before proceeding with functional tests.**

