# Integration Test Cases

## Test ID: INT-001 to INT-015

---

## Overview

Integration tests verify the script works correctly when integrated with other systems including cron, monitoring, and the broader Kubernetes infrastructure.

---

## Category: Cron Integration

### INT-001: Cron Execution - Basic

**Priority:** High  
**Description:** Verify script runs correctly when executed by cron.

**Pre-conditions:**
- cron service running
- Script path known

**Test Steps:**
1. Add cron entry:
   ```bash
   crontab -e
   # Add: * * * * * /path/to/image-sync.sh >> /var/log/giindia/sync-worker-node-images/cron.log 2>&1
   ```
2. Wait for next minute
3. Check execution:
   ```bash
   tail -f /var/log/giindia/sync-worker-node-images/cron.log
   ```
4. Remove cron entry after test

**Expected Result:**
- Script executes at scheduled time
- Output captured in log
- No environment issues

**Pass Criteria:**
- [ ] Cron triggers script
- [ ] Script runs to completion
- [ ] Logs captured correctly

---

### INT-002: Cron Execution - Environment Variables

**Priority:** High  
**Description:** Verify script works with cron's minimal environment.

**Pre-conditions:**
- Cron has minimal PATH

**Test Steps:**
1. Check cron PATH
2. Verify script has full paths for commands
3. Run via cron
4. Check for "command not found" errors

**Expected Result:**
- All commands found
- Script works in cron environment
- No path-related failures

**Pass Criteria:**
- [ ] No missing command errors
- [ ] PATH issues handled

---

### INT-003: Cron Execution - Working Directory

**Priority:** Medium  
**Description:** Verify script handles working directory correctly when run from cron.

**Pre-conditions:**
- Cron executes from different directory

**Test Steps:**
1. Run script from different directory manually:
   ```bash
   cd /tmp && /path/to/image-sync.sh
   ```
2. Check config file loading
3. Verify paths work

**Expected Result:**
- Config loaded using script's directory
- All paths work correctly
- No relative path issues

**Pass Criteria:**
- [ ] Config found regardless of cwd
- [ ] All operations succeed

---

### INT-004: Cron Lock Conflict

**Priority:** High  
**Description:** Test cron job when previous job still running.

**Pre-conditions:**
- Long-running sync in progress
- Cron schedules another run

**Test Steps:**
1. Start script manually (long running)
2. Trigger cron job
3. Check lock conflict handling
4. Verify in cron.log

**Expected Result:**
- Second instance blocked
- Lock error logged
- No concurrent runs
- First instance continues

**Pass Criteria:**
- [ ] Lock prevents overlap
- [ ] Error logged in cron.log
- [ ] No corruption

---

### INT-005: Cron Multiple Schedules

**Priority:** Medium  
**Description:** Test multiple cron schedules don't overlap.

**Pre-conditions:**
- Multiple cron entries (or rapid schedule)

**Test Steps:**
1. Add rapid schedule for testing:
   ```bash
   */2 * * * * /path/to/image-sync.sh
   ```
2. Monitor for 10 minutes
3. Verify sequential execution

**Expected Result:**
- Each run completes before next
- Lock prevents overlap
- All runs logged

**Pass Criteria:**
- [ ] No overlapping runs
- [ ] All executions logged

---

## Category: System Integration

### INT-006: Systemd Service Integration

**Priority:** Medium  
**Description:** Test script as systemd service (if applicable).

**Pre-conditions:**
- systemd available

**Test Steps:**
1. Create service file:
   ```ini
   [Unit]
   Description=Image Sync Service
   
   [Service]
   Type=oneshot
   ExecStart=/path/to/image-sync.sh
   
   [Install]
   WantedBy=multi-user.target
   ```
2. Start service:
   ```bash
   systemctl start image-sync.service
   ```
3. Check status and logs

**Expected Result:**
- Service starts and completes
- Status shows success/failure
- Journal has logs

**Pass Criteria:**
- [ ] Service runs
- [ ] Logs in journal
- [ ] Exit code reflects success/failure

---

### INT-007: Integration with Kubernetes Events

**Priority:** Low  
**Description:** Test script impact on Kubernetes cluster.

**Pre-conditions:**
- Active Kubernetes cluster

**Test Steps:**
1. Check cluster state before sync:
   ```bash
   kubectl get pods --all-namespaces | wc -l
   ```
2. Run sync
3. Verify no pod disruptions
4. Check node status

**Expected Result:**
- No pod restarts
- Nodes remain Ready
- No cluster impact

**Pass Criteria:**
- [ ] No pod disruptions
- [ ] Cluster healthy
- [ ] Nodes Ready

---

### INT-008: containerd Socket Integration

**Priority:** High  
**Description:** Verify script works with containerd socket permissions.

**Pre-conditions:**
- containerd running on nodes

**Test Steps:**
1. Check socket permissions on nodes:
   ```bash
   ssh k8s-worker1 "ls -la /run/containerd/containerd.sock"
   ```
2. Verify SSH user can access socket
3. Run crictl command via SSH

**Expected Result:**
- Socket accessible
- crictl commands work
- No permission denied

**Pass Criteria:**
- [ ] Socket permissions correct
- [ ] SSH user in correct group

---

## Category: Monitoring Integration

### INT-009: Log Aggregation Integration

**Priority:** Medium  
**Description:** Test logs are suitable for log aggregation (ELK, Splunk, etc.).

**Pre-conditions:**
- Log aggregation system (or manual review)

**Test Steps:**
1. Review log format:
   ```bash
   head -20 /var/log/giindia/sync-worker-node-images/image-sync.log
   ```
2. Verify structured format
3. Check timestamp format
4. Verify parseable

**Expected Result:**
- Consistent timestamp format
- Machine-parseable entries
- Suitable for aggregation

**Pass Criteria:**
- [ ] Timestamps ISO format or parseable
- [ ] Consistent structure
- [ ] No multi-line breaks

---

### INT-010: Exit Code for Monitoring

**Priority:** High  
**Description:** Verify exit codes are suitable for monitoring integration.

**Pre-conditions:**
- Script can succeed or fail

**Test Steps:**
1. Run successful sync:
   ```bash
   ./image-sync.sh
   echo "Exit code: $?"
   ```
2. Force failure (e.g., bad config):
   ```bash
   # Temporarily break config
   ./image-sync.sh
   echo "Exit code: $?"
   ```
3. Document exit codes

**Expected Result:**
- Exit 0 on success
- Exit 1 on failure
- Exit code reflects actual outcome

**Exit Code Documentation:**
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failure |

**Pass Criteria:**
- [ ] Exit 0 on success
- [ ] Non-zero on failure
- [ ] Consistent behavior

---

### INT-011: Alerting Integration

**Priority:** Medium  
**Description:** Test integration with alerting systems.

**Pre-conditions:**
- Alerting system (or manual simulation)

**Test Steps:**
1. Create wrapper script that sends alert on failure:
   ```bash
   #!/bin/bash
   if ! /path/to/image-sync.sh; then
     # Send alert (email, webhook, etc.)
     echo "Sync failed!" | mail -s "Image Sync Alert" admin@example.com
   fi
   ```
2. Test with failure scenario
3. Verify alert sent

**Expected Result:**
- Alerts sent on failure
- No false alerts on success
- Alert contains useful info

**Pass Criteria:**
- [ ] Failures trigger alerts
- [ ] Success doesn't alert
- [ ] Alert content helpful

---

## Category: End-to-End Tests

### INT-012: Full Sync Cycle Test

**Priority:** Critical  
**Description:** Complete end-to-end sync verification.

**Pre-conditions:**
- Fresh environment
- Known image difference

**Test Steps:**
1. Create known difference:
   ```bash
   ssh k8s-worker1 "crictl pull bcm11/e2e-test:v1"
   ssh k8s-worker2 "crictl rmi bcm11/e2e-test:v1 || true"
   ```
2. Run sync:
   ```bash
   ./image-sync.sh
   ```
3. Verify image now on both nodes:
   ```bash
   ssh k8s-worker1 "crictl images | grep e2e-test"
   ssh k8s-worker2 "crictl images | grep e2e-test"
   ```
4. Check logs for correct reporting

**Expected Result:**
- Image synced to Node 2
- Logs show SUCCESS
- Both nodes now have image

**Pass Criteria:**
- [ ] Image synced correctly
- [ ] Logs accurate
- [ ] Both nodes verified

---

### INT-013: Bidirectional Sync Verification

**Priority:** Critical  
**Description:** End-to-end test of bidirectional sync.

**Pre-conditions:**
- Different images on each node

**Test Steps:**
1. Setup:
   ```bash
   ssh k8s-worker1 "crictl pull bcm11/node1-only:v1"
   ssh k8s-worker2 "crictl pull bcm11/node2-only:v1"
   ssh k8s-worker1 "crictl rmi bcm11/node2-only:v1 || true"
   ssh k8s-worker2 "crictl rmi bcm11/node1-only:v1 || true"
   ```
2. Run sync
3. Verify both nodes have both images:
   ```bash
   for node in k8s-worker1 k8s-worker2; do
     echo "=== $node ==="
     ssh $node "crictl images | grep -E 'node1-only|node2-only'"
   done
   ```

**Expected Result:**
- node1-only synced to Node 2
- node2-only synced to Node 1
- Both nodes now identical

**Pass Criteria:**
- [ ] Both directions synced
- [ ] Images verified on both nodes

---

### INT-014: Recovery After Network Outage

**Priority:** High  
**Description:** Test sync recovery after temporary network failure.

**Pre-conditions:**
- Ability to disrupt and restore network

**Test Steps:**
1. Start sync
2. Disrupt network briefly (5-10 seconds)
3. Restore network
4. Let sync complete or fail
5. Run sync again
6. Verify final state

**Expected Result:**
- First sync may partially fail
- Second sync completes successfully
- Final state is consistent

**Pass Criteria:**
- [ ] Recovers from network issues
- [ ] Eventual consistency achieved
- [ ] No permanent corruption

---

### INT-015: Multi-Registry Test

**Priority:** High  
**Description:** Test syncing images from both configured registries.

**Pre-conditions:**
- Images from both PREFIX1 and PREFIX2 registries

**Test Steps:**
1. Ensure images from both registries:
   ```bash
   # Harbor images
   ssh k8s-worker1 "crictl images | grep bcm11 | head -3"
   # NVIDIA images
   ssh k8s-worker1 "crictl images | grep nvcr.io/nvidia | head -3"
   ```
2. Create difference with both types
3. Run sync
4. Verify both registry types synced

**Expected Result:**
- Both Harbor and NVIDIA images synced
- Prefixes filter correctly
- Both registries accessible

**Pass Criteria:**
- [ ] Harbor images synced
- [ ] NVIDIA images synced
- [ ] Both registries work

---

## Integration Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| INT-001 | Cron Basic | High | | | |
| INT-002 | Cron Environment | High | | | |
| INT-003 | Cron Working Dir | Medium | | | |
| INT-004 | Cron Lock Conflict | High | | | |
| INT-005 | Cron Multiple Schedules | Medium | | | |
| INT-006 | Systemd Service | Medium | | | |
| INT-007 | Kubernetes Events | Low | | | |
| INT-008 | containerd Socket | High | | | |
| INT-009 | Log Aggregation | Medium | | | |
| INT-010 | Exit Code | High | | | |
| INT-011 | Alerting Integration | Medium | | | |
| INT-012 | Full Sync Cycle | Critical | | | |
| INT-013 | Bidirectional Verify | Critical | | | |
| INT-014 | Network Recovery | High | | | |
| INT-015 | Multi-Registry | High | | | |

---

## Integration Environment Checklist

Before integration testing, verify:

- [ ] Cron service running
- [ ] systemd available (if testing service)
- [ ] Log aggregation accessible (if testing)
- [ ] Monitoring/alerting configured (if testing)
- [ ] Both registries accessible
- [ ] Kubernetes cluster healthy

