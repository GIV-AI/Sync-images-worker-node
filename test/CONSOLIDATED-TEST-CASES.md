# Consolidated Test Cases - Image Sync Script

## Overview

This document contains **only critical test cases** that cannot be verified by source code inspection alone. These tests require actual runtime execution to validate behavior under real conditions.

**Total Tests: 16**

---

## Category 1: Security Injection Tests (2 tests)

These tests verify the script is not vulnerable to command injection attacks.

### SEC-INJ-001: Command Injection via NODE Variables

**Priority:** Critical  
**Risk:** Remote Code Execution

**Why This Test is Necessary:**
The script passes NODE1/NODE2 directly to SSH commands. Source code inspection cannot guarantee shell expansion won't occur in all edge cases.

**Test Steps:**
1. Backup original config:
   ```bash
   cp image-sync.conf image-sync.conf.bak
   ```

2. Create malicious config:
   ```bash
   cat > image-sync.conf << 'EOF'
   NODE1="k8s-worker1; touch /tmp/injection-test-node"
   NODE2="k8s-worker2"
   PREFIX1="bcm11"
   PREFIX2="nvcr.io/nvidia"
   LOG_DIR="/var/log/giindia/sync-worker-node-images"
   TIME_OUT=1800
   MAX_PARALLEL=4
   EOF
   ```

3. Run script:
   ```bash
   ./image-sync.sh
   ```

4. Check if injection succeeded:
   ```bash
   ls -la /tmp/injection-test-node
   ```

5. Restore config:
   ```bash
   mv image-sync.conf.bak image-sync.conf
   rm -f /tmp/injection-test-node
   ```

**Expected Result:**
- File `/tmp/injection-test-node` should NOT exist
- Script should fail safely (SSH to invalid host)

**Pass Criteria:**
- [ ] No injection file created
- [ ] Script exits with error (not success)

---

### SEC-INJ-002: Command Injection via Image Names

**Priority:** Critical  
**Risk:** Remote Code Execution via crafted image names

**Why This Test is Necessary:**
Image names are fetched from remote nodes and passed to `crictl pull`. Malicious image names could potentially execute commands.

**Test Steps:**
1. If possible, create or simulate an image with injection attempt in name:
   ```bash
   # Simulated malicious image name patterns to test:
   # bcm11/test$(touch /tmp/img-inject):v1
   # bcm11/test`id`:v1
   # bcm11/test;rm -rf /:v1
   ```

2. Check script's handling of special characters in jq/grep pipeline

3. Verify no command execution occurs

**Expected Result:**
- Special characters in image names are treated as literals
- No command execution from image name content

**Pass Criteria:**
- [ ] No unintended commands executed
- [ ] Script handles special characters safely

---

## Category 2: Stress Tests (6 tests)

These tests verify behavior under load and resource constraints that cannot be predicted from code.

### STRESS-001: Large Number of Images (100+)

**Priority:** High  
**Risk:** Memory exhaustion, performance degradation

**Why This Test is Necessary:**
Array handling, parallel job management, and memory usage under volume cannot be determined from source code.

**Test Steps:**
1. Ensure one node has 100+ images matching prefixes that need syncing

2. Monitor resources during execution:
   ```bash
   # Terminal 1: Run script with timing
   time ./image-sync.sh
   
   # Terminal 2: Monitor memory
   watch -n5 "ps aux | grep image-sync | grep -v grep"
   
   # Terminal 3: Monitor parallel jobs
   watch -n2 "ssh k8s-worker1 'ps aux | grep crictl | grep -v grep | wc -l'"
   ```

3. Record metrics:
   - Total execution time
   - Peak memory usage
   - Any errors or failures

**Expected Result:**
- Script completes without crash
- Memory usage remains bounded
- All images eventually synced

**Pass Criteria:**
- [ ] Script completes successfully
- [ ] No out-of-memory errors
- [ ] SUCCESS_COUNT matches expected

**Metrics:**
| Metric | Value |
|--------|-------|
| Execution time | |
| Images synced | |
| Peak memory | |
| Errors | |

---

### STRESS-002: Very Large Image (5GB+)

**Priority:** High  
**Risk:** Timeout misconfiguration, network issues

**Why This Test is Necessary:**
Actual download time for large images cannot be predicted; timeout behavior needs validation.

**Test Steps:**
1. Identify or pull a large image (5GB+) to one node only

2. Verify TIME_OUT is sufficient (default 1800s = 30 min)

3. Run sync and monitor:
   ```bash
   time ./image-sync.sh
   ```

4. Watch for timeout vs completion

**Expected Result:**
- Large image syncs successfully OR times out gracefully
- No partial/corrupted images
- Timeout logged if exceeded

**Pass Criteria:**
- [ ] Large image handled (success or clean timeout)
- [ ] No corruption
- [ ] Appropriate log entry

---

### STRESS-003: Low Disk Space on Target Node

**Priority:** High  
**Risk:** Corrupted state, unclear errors

**Why This Test is Necessary:**
Error handling when disk fills during pull cannot be determined from code inspection.

**Test Steps:**
1. Fill disk on target node:
   ```bash
   ssh k8s-worker1 "dd if=/dev/zero of=/tmp/fillfile bs=1G count=50"
   ```

2. Run sync script:
   ```bash
   ./image-sync.sh
   ```

3. Check error handling and logs

4. Cleanup:
   ```bash
   ssh k8s-worker1 "rm /tmp/fillfile"
   ```

**Expected Result:**
- Pull fails with clear disk space error
- Script continues with other operations
- No corrupted partial images left behind

**Pass Criteria:**
- [ ] Clear error message logged
- [ ] Script doesn't crash
- [ ] Other nodes/images still processed

---

### STRESS-004: Network Degradation

**Priority:** High  
**Risk:** Hangs, data corruption, unclear failures

**Why This Test is Necessary:**
Behavior under real network issues (latency, packet loss) cannot be simulated by code reading.

**Test Steps:**
1. Add network latency and packet loss:
   ```bash
   ssh k8s-worker1 "sudo tc qdisc add dev eth0 root netem delay 200ms loss 5%"
   ```

2. Run sync:
   ```bash
   time ./image-sync.sh
   ```

3. Observe behavior (slower but functional, or failures)

4. Remove network degradation:
   ```bash
   ssh k8s-worker1 "sudo tc qdisc del dev eth0 root"
   ```

**Expected Result:**
- Operations complete (slower) or timeout appropriately
- No data corruption
- Clear error messages if failures

**Pass Criteria:**
- [ ] No hangs
- [ ] Timeouts work correctly
- [ ] No corruption

---

### STRESS-005: Interrupted Execution (SIGINT/SIGTERM)

**Priority:** High  
**Risk:** Orphaned processes, stale locks, corrupted state

**Why This Test is Necessary:**
Signal handling and cleanup behavior must be tested at runtime.

**Test Steps:**
1. Start script:
   ```bash
   ./image-sync.sh &
   PID=$!
   ```

2. Wait for operations to begin (5-10 seconds)

3. Send interrupt:
   ```bash
   kill -INT $PID
   # Wait, then check state
   ```

4. Check cleanup:
   ```bash
   # Lock file released?
   ls -la /var/run/image-sync.lock
   
   # Temp files cleaned?
   ls -la /tmp/tmp.*
   
   # Can run again?
   ./image-sync.sh
   ```

**Expected Result:**
- Script terminates
- Lock file released (may need manual cleanup)
- Temp files removed
- Subsequent runs work

**Pass Criteria:**
- [ ] Script exits on signal
- [ ] No permanent lock stuck
- [ ] Next run works

---

### STRESS-006: Kill -9 Recovery

**Priority:** Medium  
**Risk:** Stale lock preventing future runs

**Why This Test is Necessary:**
Forced termination leaves lock file; recovery procedure must be tested.

**Test Steps:**
1. Start script:
   ```bash
   ./image-sync.sh &
   PID=$!
   sleep 5
   ```

2. Force kill:
   ```bash
   kill -9 $PID
   ```

3. Attempt to run again:
   ```bash
   ./image-sync.sh
   # Should show lock error
   ```

4. Manual recovery:
   ```bash
   rm -f /var/run/image-sync.lock
   ./image-sync.sh
   # Should work now
   ```

**Expected Result:**
- Lock file remains after kill -9 (expected)
- Manual removal allows re-run
- No other permanent damage

**Pass Criteria:**
- [ ] Lock error message clear
- [ ] Manual recovery works
- [ ] No data corruption

**Recovery Procedure (document for ops):**
```bash
# If script won't run due to stale lock:
rm -f /var/run/image-sync.lock
```

---

## Category 3: Concurrency Tests (2 tests)

### CONC-001: Concurrent Execution Prevention

**Priority:** Critical  
**Risk:** Race conditions, duplicate operations, data corruption

**Why This Test is Necessary:**
Lock mechanism must be tested under actual concurrent execution.

**Test Steps:**
1. Start first instance:
   ```bash
   ./image-sync.sh &
   FIRST_PID=$!
   echo "First instance PID: $FIRST_PID"
   ```

2. Immediately start second instance:
   ```bash
   ./image-sync.sh
   SECOND_EXIT=$?
   echo "Second instance exit code: $SECOND_EXIT"
   ```

3. Verify behavior:
   ```bash
   # Second should have exited with error
   # First should still be running or completed normally
   wait $FIRST_PID
   echo "First instance exit code: $?"
   ```

**Expected Result:**
- Second instance exits immediately with error
- Error message: "Script already running. Lock active"
- Exit code: 1 for second instance
- First instance continues unaffected

**Pass Criteria:**
- [ ] Second instance blocked
- [ ] Clear lock error message
- [ ] First instance completes normally

---

### CONC-002: Rapid Sequential Executions

**Priority:** High  
**Risk:** Lock release timing issues

**Why This Test is Necessary:**
Lock release behavior between rapid runs must be verified at runtime.

**Test Steps:**
1. Run multiple sequential executions:
   ```bash
   for i in {1..5}; do
     echo "=== Run $i ==="
     ./image-sync.sh
     echo "Exit code: $?"
     echo ""
   done
   ```

2. Verify each run succeeds without lock conflicts

**Expected Result:**
- Each run completes successfully
- No lock conflicts between sequential runs
- All exit codes are 0 (assuming nodes reachable)

**Pass Criteria:**
- [ ] All 5 runs complete
- [ ] No lock errors
- [ ] Consistent behavior

---

## Category 4: Integration Tests (3 tests)

### INT-001: Cron Execution

**Priority:** High  
**Risk:** Environment differences, path issues

**Why This Test is Necessary:**
Cron runs with minimal environment; actual cron execution must be tested.

**Test Steps:**
1. Add cron entry (test with 1-minute schedule):
   ```bash
   crontab -e
   # Add line:
   # * * * * * /full/path/to/image-sync.sh >> /var/log/giindia/sync-worker-node-images/cron-test.log 2>&1
   ```

2. Wait for execution (1-2 minutes)

3. Check results:
   ```bash
   cat /var/log/giindia/sync-worker-node-images/cron-test.log
   ```

4. Remove cron entry:
   ```bash
   crontab -e
   # Remove the test line
   ```

**Expected Result:**
- Script executes from cron
- Config file found (uses dirname $0)
- All commands found in cron's PATH
- Logs captured correctly

**Pass Criteria:**
- [ ] Script runs from cron
- [ ] No "command not found" errors
- [ ] Config loaded successfully
- [ ] Normal operation logged

---

### INT-002: Full End-to-End Sync Cycle

**Priority:** Critical  
**Risk:** Sync doesn't actually work

**Why This Test is Necessary:**
Ultimate verification that images actually sync between nodes.

**Test Steps:**
1. Create known difference:
   ```bash
   # Pull test image to Node 1 only
   ssh k8s-worker1 "crictl pull bcm11/e2e-test-image:v1"
   
   # Ensure it's NOT on Node 2
   ssh k8s-worker2 "crictl rmi bcm11/e2e-test-image:v1 2>/dev/null || true"
   
   # Verify difference
   echo "Node 1:"
   ssh k8s-worker1 "crictl images | grep e2e-test"
   echo "Node 2:"
   ssh k8s-worker2 "crictl images | grep e2e-test"
   ```

2. Run sync:
   ```bash
   ./image-sync.sh
   ```

3. Verify sync completed:
   ```bash
   echo "Node 1:"
   ssh k8s-worker1 "crictl images | grep e2e-test"
   echo "Node 2:"
   ssh k8s-worker2 "crictl images | grep e2e-test"
   ```

4. Check logs:
   ```bash
   grep "e2e-test" /var/log/giindia/sync-worker-node-images/image-sync.log
   grep "e2e-test" /var/log/giindia/sync-worker-node-images/success_images.log
   ```

**Expected Result:**
- Image now present on both nodes
- SUCCESS logged for the pull
- Summary shows correct count

**Pass Criteria:**
- [ ] Image synced to Node 2
- [ ] Success logged
- [ ] Both nodes verified

---

### INT-003: Bidirectional Sync Verification

**Priority:** Critical  
**Risk:** One-way sync only

**Why This Test is Necessary:**
Verify both directions work in single run.

**Test Steps:**
1. Setup asymmetric state:
   ```bash
   # Image A on Node 1 only
   ssh k8s-worker1 "crictl pull bcm11/bidir-test-a:v1"
   ssh k8s-worker2 "crictl rmi bcm11/bidir-test-a:v1 2>/dev/null || true"
   
   # Image B on Node 2 only
   ssh k8s-worker2 "crictl pull bcm11/bidir-test-b:v1"
   ssh k8s-worker1 "crictl rmi bcm11/bidir-test-b:v1 2>/dev/null || true"
   ```

2. Verify setup:
   ```bash
   echo "=== Before sync ==="
   echo "Node 1:"; ssh k8s-worker1 "crictl images | grep bidir-test"
   echo "Node 2:"; ssh k8s-worker2 "crictl images | grep bidir-test"
   ```

3. Run sync:
   ```bash
   ./image-sync.sh
   ```

4. Verify both directions:
   ```bash
   echo "=== After sync ==="
   echo "Node 1:"; ssh k8s-worker1 "crictl images | grep bidir-test"
   echo "Node 2:"; ssh k8s-worker2 "crictl images | grep bidir-test"
   ```

**Expected Result:**
- Node 1 now has bidir-test-b
- Node 2 now has bidir-test-a
- Both nodes identical

**Pass Criteria:**
- [ ] Image A synced to Node 2
- [ ] Image B synced to Node 1
- [ ] SUCCESS_COUNT = 2

---

## Category 5: Race Condition Tests (1 test)

### RACE-001: Image Deleted During Sync

**Priority:** High  
**Risk:** Failed pulls, unclear errors

**Why This Test is Necessary:**
Behavior when source image disappears during sync cannot be predicted from code.

**Test Steps:**
1. Ensure a unique image exists on one node for syncing

2. Start sync script:
   ```bash
   ./image-sync.sh &
   SYNC_PID=$!
   ```

3. Quickly delete the source image:
   ```bash
   # Timing is tricky - need to delete after image list but before pull completes
   ssh k8s-worker1 "crictl rmi bcm11/race-test:v1"
   ```

4. Wait for sync to complete:
   ```bash
   wait $SYNC_PID
   ```

5. Check logs for handling

**Expected Result:**
- Pull fails (image no longer available)
- Error logged appropriately
- Script continues and completes
- No crash

**Pass Criteria:**
- [ ] No crash
- [ ] Error logged
- [ ] Script completes

---

## Test Execution Summary

| Test ID | Category | Priority | Status | Tester | Date |
|---------|----------|----------|--------|--------|------|
| SEC-INJ-001 | Security | Critical | | | |
| SEC-INJ-002 | Security | Critical | | | |
| STRESS-001 | Stress | High | | | |
| STRESS-002 | Stress | High | | | |
| STRESS-003 | Stress | High | | | |
| STRESS-004 | Stress | High | | | |
| STRESS-005 | Stress | High | | | |
| STRESS-006 | Stress | Medium | | | |
| CONC-001 | Concurrency | Critical | | | |
| CONC-002 | Concurrency | High | | | |
| INT-001 | Integration | High | | | |
| INT-002 | Integration | Critical | | | |
| INT-003 | Integration | Critical | | | |
| RACE-001 | Race Condition | High | | | |

**Critical Tests (must pass before production):** 6  
**High Priority Tests:** 7  
**Medium Priority Tests:** 1  

---

## Why Other Tests Were Eliminated

| Eliminated Category | Reason |
|---------------------|--------|
| Config file loading | `source` behavior is standard bash |
| SSH timeout values | Hardcoded in script, visible in code |
| Parallel job limit | Logic using `jobs -rp` is deterministic |
| Log format/timestamps | `date '+%F %T'` format is explicit |
| Exit codes | All exit codes (0, 1, 124) explicit in code |
| Empty list handling | `comm` and `sed` cleanup logic visible |
| Prefix filtering | `grep -E` regex pattern is explicit |
| File permission tests | Environment setup, not script logic |
| Most error message tests | Output strings visible in source |

---

## Prerequisites Checklist

Before running these tests, verify:

- [ ] SSH access to both nodes (passwordless)
- [ ] `crictl` installed on both nodes
- [ ] `jq` installed on test machine
- [ ] Write access to `/var/run` and log directory
- [ ] Test images available in registry (bcm11/*)
- [ ] Network tools available for stress tests (`tc` command)
- [ ] Ability to run commands as root or with sudo

---

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Reduced from:** 115+ tests to 14 essential tests

