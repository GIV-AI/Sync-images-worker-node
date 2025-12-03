# Stress Test Cases

## Test ID: STRESS-001 to STRESS-020

---

## Overview

Stress tests verify the script's behavior under heavy load, resource constraints, and adverse conditions. These tests help identify performance bottlenecks and ensure stability.

---

## Category: Volume Testing

### STRESS-001: Large Number of Images

**Priority:** High  
**Description:** Test synchronization with a large number of images (100+).

**Pre-conditions:**
- Nodes have many images to sync

**Test Steps:**
1. Pull 100+ different images to one node
2. Run sync script
3. Monitor:
   - Execution time
   - Memory usage
   - CPU usage
   - Log file size

**Test Commands:**
```bash
# Monitor during test
watch -n5 "ps aux | grep image-sync | grep -v grep"
watch -n5 "du -sh /var/log/giindia/sync-worker-node-images/"

# Time the execution
time ./image-sync.sh
```

**Expected Result:**
- Script completes successfully
- All images synced
- No memory exhaustion
- Reasonable execution time

**Metrics to Record:**
- Total execution time: ____
- Peak memory usage: ____
- Number of images synced: ____
- Any failures: ____

**Pass Criteria:**
- [ ] Script completes without crash
- [ ] All images synced
- [ ] Memory usage stays reasonable

---

### STRESS-002: Very Large Image Sizes

**Priority:** High  
**Description:** Test with images >5GB in size.

**Pre-conditions:**
- Large images available in registry

**Test Steps:**
1. Identify or create a large image (5GB+)
2. Ensure it's missing on one node
3. Run sync with extended timeout
4. Monitor disk I/O and network

**Expected Result:**
- Large images handled
- Timeout configurable for large images
- No partial/corrupted downloads

**Metrics to Record:**
- Image size: ____
- Download time: ____
- Network throughput: ____

**Pass Criteria:**
- [ ] Large images sync successfully
- [ ] No corruption
- [ ] Progress visible in logs

---

### STRESS-003: Maximum Parallel Pulls

**Priority:** High  
**Description:** Test MAX_PARALLEL limit under load.

**Pre-conditions:**
- Many images need syncing
- MAX_PARALLEL=4

**Test Steps:**
1. Configure MAX_PARALLEL=4
2. Queue 20+ image pulls
3. Monitor concurrent processes:
   ```bash
   while true; do 
     ssh k8s-worker1 "ps aux | grep 'crictl pull' | grep -v grep | wc -l"
     sleep 2
   done
   ```

**Expected Result:**
- Never more than MAX_PARALLEL concurrent pulls
- All images eventually pulled
- No resource exhaustion

**Metrics to Record:**
- Max observed parallel processes: ____
- Total execution time: ____
- Queue handling time: ____

**Pass Criteria:**
- [ ] Parallel limit respected
- [ ] No more than 4 concurrent pulls
- [ ] All images completed

---

### STRESS-004: Varying MAX_PARALLEL Values

**Priority:** Medium  
**Description:** Test different MAX_PARALLEL configurations.

**Pre-conditions:**
- Multiple images to sync

**Test Steps:**
1. Test with MAX_PARALLEL=1:
   ```bash
   # Measure sequential performance
   time ./image-sync.sh
   ```
2. Test with MAX_PARALLEL=8:
   ```bash
   time ./image-sync.sh
   ```
3. Test with MAX_PARALLEL=16:
   ```bash
   time ./image-sync.sh
   ```
4. Compare results

**Expected Result:**
- Higher parallel values = faster completion (up to a point)
- Diminishing returns at high values
- No crashes at any value

**Metrics to Record:**
| MAX_PARALLEL | Execution Time | Errors |
|--------------|----------------|--------|
| 1 | | |
| 4 | | |
| 8 | | |
| 16 | | |

**Pass Criteria:**
- [ ] All configurations work
- [ ] Performance scales reasonably

---

## Category: Resource Constraints

### STRESS-005: Low Disk Space on Target Node

**Priority:** High  
**Description:** Test behavior when target node has low disk space.

**Pre-conditions:**
- Fill disk on target node

**Test Steps:**
1. Create large file to fill disk:
   ```bash
   ssh k8s-worker1 "dd if=/dev/zero of=/tmp/fillfile bs=1G count=50"
   ```
2. Run sync script
3. Observe error handling
4. Clean up:
   ```bash
   ssh k8s-worker1 "rm /tmp/fillfile"
   ```

**Expected Result:**
- Pull fails with clear error
- Script continues with other images
- No partial corrupted images left

**Pass Criteria:**
- [ ] Graceful disk full handling
- [ ] Clear error message
- [ ] Other images still processed

---

### STRESS-006: Low Memory Conditions

**Priority:** Medium  
**Description:** Test under memory pressure.

**Pre-conditions:**
- Ability to create memory pressure

**Test Steps:**
1. Create memory pressure:
   ```bash
   # On test machine, consume memory
   stress --vm 2 --vm-bytes 1G &
   ```
2. Run sync script
3. Monitor behavior
4. Release memory

**Expected Result:**
- Script handles memory pressure
- No OOM kills (or graceful handling)
- Operations complete or fail clearly

**Pass Criteria:**
- [ ] Script continues under memory pressure
- [ ] No silent failures

---

### STRESS-007: High CPU Load

**Priority:** Medium  
**Description:** Test under high CPU utilization.

**Pre-conditions:**
- Ability to generate CPU load

**Test Steps:**
1. Generate CPU load:
   ```bash
   stress --cpu 4 &
   ```
2. Run sync script
3. Measure impact on performance
4. Stop stress test

**Expected Result:**
- Script completes (possibly slower)
- No timeout false positives
- Operations are resilient

**Pass Criteria:**
- [ ] Script completes under load
- [ ] Acceptable performance degradation

---

### STRESS-008: Network Bandwidth Limitation

**Priority:** High  
**Description:** Test with limited network bandwidth.

**Pre-conditions:**
- Ability to limit bandwidth (tc command)

**Test Steps:**
1. Limit bandwidth:
   ```bash
   # On node, limit to 1Mbps
   ssh k8s-worker1 "tc qdisc add dev eth0 root tbf rate 1mbit burst 32kbit latency 400ms"
   ```
2. Run sync script with appropriate timeout
3. Observe behavior
4. Remove limit:
   ```bash
   ssh k8s-worker1 "tc qdisc del dev eth0 root"
   ```

**Expected Result:**
- Pulls are slower but complete (if timeout sufficient)
- Timeouts occur appropriately for large images
- No connection drops

**Pass Criteria:**
- [ ] Handles slow network
- [ ] Timeouts work correctly
- [ ] Recovery after bandwidth restored

---

### STRESS-009: Network Latency

**Priority:** Medium  
**Description:** Test with high network latency.

**Pre-conditions:**
- Ability to add latency

**Test Steps:**
1. Add latency:
   ```bash
   ssh k8s-worker1 "tc qdisc add dev eth0 root netem delay 500ms"
   ```
2. Run sync script
3. Check SSH timeouts and pull behavior
4. Remove latency

**Expected Result:**
- SSH operations succeed (with delay)
- Pulls complete (slower)
- No false timeout failures for short operations

**Pass Criteria:**
- [ ] Handles latency gracefully
- [ ] Connection timeouts appropriate

---

### STRESS-010: Network Packet Loss

**Priority:** Medium  
**Description:** Test with packet loss.

**Pre-conditions:**
- Ability to simulate packet loss

**Test Steps:**
1. Add packet loss:
   ```bash
   ssh k8s-worker1 "tc qdisc add dev eth0 root netem loss 5%"
   ```
2. Run sync script
3. Observe retries and error handling
4. Remove packet loss

**Expected Result:**
- Operations retry where appropriate
- Failures are logged
- No data corruption

**Pass Criteria:**
- [ ] Handles packet loss
- [ ] No corruption
- [ ] Appropriate retries

---

## Category: Concurrency Testing

### STRESS-011: Rapid Sequential Executions

**Priority:** High  
**Description:** Test rapid sequential runs of the script.

**Pre-conditions:**
- Lock mechanism in place

**Test Steps:**
1. Run script multiple times rapidly:
   ```bash
   for i in {1..10}; do
     ./image-sync.sh &
     sleep 1
   done
   wait
   ```
2. Check for lock conflicts
3. Verify data integrity

**Expected Result:**
- Only one instance runs at a time
- Others exit with lock error
- No data corruption

**Pass Criteria:**
- [ ] Lock prevents concurrent runs
- [ ] Clean error messages
- [ ] No race conditions

---

### STRESS-012: Long-Running Operations

**Priority:** High  
**Description:** Test script behavior during extended execution.

**Pre-conditions:**
- Many large images to sync

**Test Steps:**
1. Configure for long run (many images, large sizes)
2. Run script
3. Monitor for hours:
   - Memory growth
   - File handle leaks
   - Log file growth
   - Temp file cleanup

**Expected Result:**
- No memory leaks
- No file handle leaks
- Log files manageable
- Temp files cleaned

**Metrics to Record:**
- Duration: ____
- Final memory usage: ____
- Log file size: ____
- Open file handles: ____

**Pass Criteria:**
- [ ] No resource leaks
- [ ] Stable over time

---

### STRESS-013: Interrupted Execution

**Priority:** High  
**Description:** Test behavior when script is interrupted.

**Pre-conditions:**
- Script running with operations in progress

**Test Steps:**
1. Start script:
   ```bash
   ./image-sync.sh &
   PID=$!
   ```
2. Wait for operations to start
3. Interrupt:
   ```bash
   kill -INT $PID
   # Or
   kill -TERM $PID
   ```
4. Check cleanup:
   - Lock file released?
   - Temp files cleaned?
   - Partial downloads handled?

**Expected Result:**
- Graceful shutdown
- Lock released
- Temp files cleaned
- No corrupt state

**Pass Criteria:**
- [ ] Clean shutdown on SIGINT
- [ ] Clean shutdown on SIGTERM
- [ ] Lock released

---

### STRESS-014: Kill -9 Recovery

**Priority:** Medium  
**Description:** Test recovery after forceful termination.

**Pre-conditions:**
- Script can be forcefully killed

**Test Steps:**
1. Start script
2. Forcefully kill:
   ```bash
   kill -9 $PID
   ```
3. Check state:
   - Lock file status
   - Can script run again?
   - Any cleanup needed?

**Expected Result:**
- Lock file may remain (expected with kill -9)
- Manual cleanup possible
- Script can recover

**Recovery Steps to Document:**
```bash
# If lock file stuck:
rm -f /var/run/image-sync.lock
```

**Pass Criteria:**
- [ ] Recovery procedure documented
- [ ] No permanent damage
- [ ] Manual cleanup works

---

## Category: Timeout Testing

### STRESS-015: Pull Timeout at Boundary

**Priority:** High  
**Description:** Test timeout behavior at exact boundary.

**Pre-conditions:**
- Configurable timeout

**Test Steps:**
1. Set short timeout:
   ```bash
   TIME_OUT=60
   ```
2. Pull image that takes ~60 seconds
3. Observe if timeout triggers correctly

**Expected Result:**
- Timeout triggers at configured time
- Process killed cleanly
- TIMEOUT logged

**Pass Criteria:**
- [ ] Timeout accurate (within seconds)
- [ ] Clean termination

---

### STRESS-016: SSH Timeout Under Load

**Priority:** Medium  
**Description:** Test SSH connection timeout during network congestion.

**Pre-conditions:**
- Network can be congested

**Test Steps:**
1. Create network congestion
2. Run script
3. Observe SSH timeout behavior

**Expected Result:**
- SSH times out at configured value (10s)
- Clear error message
- Script handles timeout appropriately

**Pass Criteria:**
- [ ] SSH timeout works
- [ ] Proper error handling

---

### STRESS-017: Multiple Timeouts

**Priority:** Medium  
**Description:** Test behavior when multiple pulls timeout.

**Pre-conditions:**
- Multiple slow/stuck pulls

**Test Steps:**
1. Configure conditions for multiple timeouts
2. Run script
3. Verify all timeouts logged
4. Check resource cleanup

**Expected Result:**
- Each timeout logged separately
- Script continues with other images
- No zombie processes

**Pass Criteria:**
- [ ] All timeouts logged
- [ ] Script continues
- [ ] No zombies

---

## Category: Log Stress Testing

### STRESS-018: Log File Growth

**Priority:** Medium  
**Description:** Test log file behavior over many runs.

**Pre-conditions:**
- Script run multiple times

**Test Steps:**
1. Run script 100 times:
   ```bash
   for i in {1..100}; do
     ./image-sync.sh
     sleep 5
   done
   ```
2. Check log file sizes
3. Verify log rotation if implemented

**Expected Result:**
- Logs don't grow unbounded
- Log rotation works (if implemented)
- System not affected by log size

**Metrics to Record:**
- Final log sizes: ____
- Disk usage impact: ____

**Pass Criteria:**
- [ ] Log sizes manageable
- [ ] No disk filling from logs

---

### STRESS-019: Concurrent Log Writing

**Priority:** Low  
**Description:** Test log integrity during parallel operations.

**Pre-conditions:**
- Parallel operations writing to same log

**Test Steps:**
1. Configure high MAX_PARALLEL
2. Trigger many simultaneous operations
3. Verify log file integrity:
   ```bash
   # Check for interleaved lines
   grep -E "^\[" /var/log/giindia/sync-worker-node-images/image-sync.log | head -20
   ```

**Expected Result:**
- Log entries not interleaved mid-line
- Timestamps accurate
- No corrupted entries

**Pass Criteria:**
- [ ] Log entries intact
- [ ] No corruption

---

## Category: Edge Performance

### STRESS-020: First Run vs Subsequent Runs

**Priority:** Low  
**Description:** Compare performance of first run vs subsequent runs.

**Pre-conditions:**
- Clean state for first run

**Test Steps:**
1. Clear all synced state
2. Time first run:
   ```bash
   time ./image-sync.sh
   ```
3. Immediately time second run:
   ```bash
   time ./image-sync.sh
   ```
4. Compare metrics

**Expected Result:**
- First run: actual sync operations
- Second run: fast (no sync needed)
- Subsequent runs efficient

**Metrics to Record:**
| Run | Time | Images Synced |
|-----|------|---------------|
| 1st | | |
| 2nd | | |
| 3rd | | |

**Pass Criteria:**
- [ ] Second run much faster
- [ ] Efficient "already synced" detection

---

## Stress Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| STRESS-001 | Large Number of Images | High | | | |
| STRESS-002 | Very Large Image Sizes | High | | | |
| STRESS-003 | MAX_PARALLEL Limit | High | | | |
| STRESS-004 | Varying MAX_PARALLEL | Medium | | | |
| STRESS-005 | Low Disk Space | High | | | |
| STRESS-006 | Low Memory | Medium | | | |
| STRESS-007 | High CPU Load | Medium | | | |
| STRESS-008 | Network Bandwidth Limit | High | | | |
| STRESS-009 | Network Latency | Medium | | | |
| STRESS-010 | Network Packet Loss | Medium | | | |
| STRESS-011 | Rapid Sequential Runs | High | | | |
| STRESS-012 | Long-Running Operations | High | | | |
| STRESS-013 | Interrupted Execution | High | | | |
| STRESS-014 | Kill -9 Recovery | Medium | | | |
| STRESS-015 | Pull Timeout Boundary | High | | | |
| STRESS-016 | SSH Timeout Under Load | Medium | | | |
| STRESS-017 | Multiple Timeouts | Medium | | | |
| STRESS-018 | Log File Growth | Medium | | | |
| STRESS-019 | Concurrent Log Writing | Low | | | |
| STRESS-020 | First vs Subsequent Runs | Low | | | |

---

## Performance Baseline Metrics

Record baseline metrics for future comparison:

| Metric | Value | Date |
|--------|-------|------|
| Avg sync time (10 images) | | |
| Avg sync time (100 images) | | |
| Peak memory usage | | |
| Avg network throughput | | |
| Max log file size (1 week) | | |

