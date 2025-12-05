# Functional Test Cases

## Test ID: FUNC-001 to FUNC-025

---

## Configuration Reference

> **Important:** All test cases use placeholder variables that match your `image-sync.conf` file.
> Replace these placeholders with actual values from your deployment environment.

| Placeholder | Config Variable | Example Value | Description |
|-------------|-----------------|---------------|-------------|
| `$NODE1` | NODE1 | k8s-worker1 | First worker node hostname |
| `$NODE2` | NODE2 | k8s-worker2 | Second worker node hostname |
| `$PREFIX1` | PREFIX1 | bcm11 | First image prefix filter |
| `$PREFIX2` | PREFIX2 | nvcr.io/nvidia | Second image prefix filter |
| `$LOG_DIR` | LOG_DIR | /var/log/giindia/sync-worker-node-images | Log directory path |
| `$TIME_OUT` | TIME_OUT | 1800 | Pull timeout in seconds |
| `$MAX_PARALLEL` | MAX_PARALLEL | 4 | Max concurrent pulls |

**Before testing:** Verify your `image-sync.conf` values and substitute accordingly in all commands.

---

## Category: Configuration Loading

### FUNC-001: Valid Configuration File Loading

**Priority:** High  
**Description:** Verify script loads configuration file correctly.

**Pre-conditions:**
- Valid `image-sync.conf` exists in script directory

**Test Steps:**
1. Ensure config file has all required variables
2. Run the script:
   ```bash
   ./image-sync.sh
   ```
3. Check logs for configuration values

**Expected Result:**
- Script starts without config errors
- Uses values from config file

**Pass Criteria:**
- [ ] No "Config file not found" error
- [ ] Correct NODE1/NODE2 used

---

### FUNC-002: Missing Configuration File

**Priority:** High  
**Description:** Verify script handles missing config file gracefully.

**Pre-conditions:**
- Temporarily rename/remove config file

**Test Steps:**
1. Rename config file:
   ```bash
   mv image-sync.conf image-sync.conf.bak
   ```
2. Run script:
   ```bash
   ./image-sync.sh
   ```
3. Restore config:
   ```bash
   mv image-sync.conf.bak image-sync.conf
   ```

**Expected Result:**
- Script exits with error code 1
- Clear error message displayed

**Pass Criteria:**
- [ ] Error message: "ERROR: Config file not found"
- [ ] Exit code: 1

---

### FUNC-003: Partial Configuration File

**Priority:** Medium  
**Description:** Verify script behavior with missing config variables.

**Pre-conditions:**
- Create config file missing some variables

**Test Steps:**
1. Create partial config:
   ```bash
   cat > test-partial.conf << 'EOF'
   NODE1="your-worker-node"
   # Missing NODE2, PREFIX1, PREFIX2, etc.
   EOF
   ```
2. Modify script to use test config (or temporarily replace)
3. Run script and observe behavior

**Expected Result:**
- Script should fail or use default values
- Should not crash silently

**Pass Criteria:**
- [ ] Handles missing variables gracefully
- [ ] Clear error or warning displayed

---

## Category: SSH Connectivity

### FUNC-004: SSH Check - Both Nodes Reachable

**Priority:** High  
**Description:** Verify SSH connectivity check passes for both nodes.

**Pre-conditions:**
- Both nodes are running and accessible

**Test Steps:**
1. Run script:
   ```bash
   ./image-sync.sh
   ```
2. Check log output for SSH messages

**Expected Result:**
- "SSH OK: $NODE1" logged
- "SSH OK: $NODE2" logged

**Pass Criteria:**
- [ ] Both SSH checks pass
- [ ] Script continues to image fetching

---

### FUNC-005: SSH Check - Node 1 Unreachable

**Priority:** High  
**Description:** Verify script exits when Node 1 is unreachable.

**Pre-conditions:**
- Temporarily block access to Node 1 (firewall/shutdown)

**Test Steps:**
1. Block SSH to Node 1:
   ```bash
   # Option A: Add firewall rule
   # Option B: Use invalid hostname in config
   ```
2. Run script:
   ```bash
   ./image-sync.sh
   ```

**Expected Result:**
- Script logs error for Node 1
- Script exits with code 1
- Does NOT attempt Node 2 operations

**Pass Criteria:**
- [ ] Error logged: "ERROR: Cannot connect to $NODE1"
- [ ] Exit code: 1
- [ ] No partial execution

---

### FUNC-006: SSH Check - Node 2 Unreachable

**Priority:** High  
**Description:** Verify script exits when Node 2 is unreachable.

**Pre-conditions:**
- Node 1 is accessible, Node 2 is blocked

**Test Steps:**
1. Block SSH to Node 2 only
2. Run script:
   ```bash
   ./image-sync.sh
   ```

**Expected Result:**
- Node 1 SSH passes
- Node 2 SSH fails
- Script exits with error

**Pass Criteria:**
- [ ] "SSH OK: $NODE1" logged
- [ ] "ERROR: Cannot connect to $NODE2" logged
- [ ] Exit code: 1

---

### FUNC-007: SSH Connection Timeout

**Priority:** Medium  
**Description:** Verify SSH timeout (10 seconds) is enforced.

**Pre-conditions:**
- Create network latency or use unresponsive host

**Test Steps:**
1. Configure NODE1 to an IP that drops packets:
   ```bash
   # Edit image-sync.conf and set NODE1 to a non-routable IP
   # Example: NODE1="10.255.255.1"
   ```
2. Time the script execution:
   ```bash
   time ./image-sync.sh
   ```

**Expected Result:**
- Script times out after ~10 seconds per node
- Total wait should not exceed 20+ seconds

**Pass Criteria:**
- [ ] Timeout occurs within expected time
- [ ] Proper error message displayed

---

## Category: Image List Retrieval

### FUNC-008: Fetch Images from Nodes

**Priority:** High  
**Description:** Verify images are fetched correctly from both nodes.

**Pre-conditions:**
- Both nodes have container images

**Test Steps:**
1. Run script and observe logs:
   ```bash
   ./image-sync.sh 2>&1 | grep -E "Images on|Fetching"
   ```

**Expected Result:**
- "Fetching images from nodes..." logged
- Image count displayed for both nodes

**Pass Criteria:**
- [ ] Image counts are reasonable (> 0)
- [ ] No JSON parsing errors

---

### FUNC-009: Empty Image List on Node

**Priority:** Medium  
**Description:** Verify handling when a node has no images.

**Pre-conditions:**
- One node has no matching images (or use prefix that matches nothing)

**Test Steps:**
1. Temporarily modify PREFIX1/PREFIX2 to non-matching values
2. Run script
3. Check handling of empty lists

**Expected Result:**
- Script handles empty list gracefully
- "Images on NODE: 0" logged

**Pass Criteria:**
- [ ] No crash on empty list
- [ ] Proper count displayed

---

### FUNC-010: Image Prefix Filtering

**Priority:** High  
**Description:** Verify only images matching prefixes are synced.

**Pre-conditions:**
- Nodes have images with different prefixes

**Test Steps:**
1. Manually check images on nodes:
   ```bash
   ssh $NODE1 "crictl images" | grep -E "^$PREFIX1|^$PREFIX2"
   ssh $NODE1 "crictl images" | grep -v -E "^$PREFIX1|^$PREFIX2"
   ```
2. Run script
3. Verify only matching prefixes are processed

**Expected Result:**
- Only $PREFIX1/* and $PREFIX2/* images are synced
- Other images (e.g., docker.io/*) are ignored

**Pass Criteria:**
- [ ] Filtered images match expected prefixes
- [ ] Non-matching images not in sync list

---

## Category: Image Comparison & Sync

### FUNC-011: Detect Missing Images on Node 1

**Priority:** High  
**Description:** Verify detection of images present on Node 2 but missing on Node 1.

**Pre-conditions:**
- Node 2 has images not present on Node 1

**Test Steps:**
1. Identify an image on Node 2 not on Node 1:
   ```bash
   ssh $NODE2 "crictl images" | grep $PREFIX1
   ssh $NODE1 "crictl images" | grep $PREFIX1
   ```
2. Run script
3. Check if missing image is identified

**Expected Result:**
- Script detects and lists missing images
- Attempts to pull missing images to Node 1

**Pass Criteria:**
- [ ] Missing images correctly identified
- [ ] Pull operation initiated

---

### FUNC-012: Detect Missing Images on Node 2

**Priority:** High  
**Description:** Verify detection of images present on Node 1 but missing on Node 2.

**Pre-conditions:**
- Node 1 has images not present on Node 2

**Test Steps:**
1. Create asymmetry by pulling image only to Node 1:
   ```bash
   ssh $NODE1 "crictl pull $PREFIX1/some-test-image:tag"
   ```
2. Run script
3. Verify detection and sync to Node 2

**Expected Result:**
- Script detects images missing on Node 2
- Pulls to Node 2

**Pass Criteria:**
- [ ] Missing images detected
- [ ] Images pulled to Node 2

---

### FUNC-013: Already Synced Nodes

**Priority:** High  
**Description:** Verify behavior when both nodes have identical images.

**Pre-conditions:**
- Both nodes are already in sync

**Test Steps:**
1. Run script once to sync
2. Immediately run script again:
   ```bash
   ./image-sync.sh
   ```
3. Check output

**Expected Result:**
- "All images are already synced" message
- "no new image found" for both nodes
- No pull operations

**Pass Criteria:**
- [ ] Sync message displayed
- [ ] No unnecessary pulls
- [ ] SUCCESS_COUNT = 0

---

### FUNC-014: Bidirectional Sync

**Priority:** High  
**Description:** Verify images are synced in both directions simultaneously.

**Pre-conditions:**
- Node 1 has imageA not on Node 2
- Node 2 has imageB not on Node 1

**Test Steps:**
1. Create test scenario:
   ```bash
   ssh $NODE1 "crictl pull $PREFIX1/test-a:v1"
   ssh $NODE2 "crictl pull $PREFIX1/test-b:v1"
   ```
2. Run script
3. Verify both directions synced

**Expected Result:**
- imageA pulled to Node 2
- imageB pulled to Node 1
- Both operations logged

**Pass Criteria:**
- [ ] Both nodes receive missing images
- [ ] SUCCESS_COUNT reflects both pulls

---

## Category: Image Pulling

### FUNC-015: Successful Image Pull

**Priority:** High  
**Description:** Verify successful image pull is logged correctly.

**Pre-conditions:**
- Missing image available in registry

**Test Steps:**
1. Ensure image is missing on one node
2. Run script
3. Check success logs:
   ```bash
   cat $LOG_DIR/success_images.log | tail -5
   ```

**Expected Result:**
- Image pulled successfully
- "SUCCESS" entry in log
- SUCCESS_COUNT incremented

**Pass Criteria:**
- [ ] Image now exists on target node
- [ ] Success logged with timestamp

---

### FUNC-016: Failed Image Pull

**Priority:** High  
**Description:** Verify failed pull is logged correctly.

**Pre-conditions:**
- Image name is valid format but doesn't exist in registry

**Test Steps:**
1. Manually test a non-existent image:
   ```bash
   ssh $NODE1 "crictl pull $PREFIX1/non-existent-image:v999"
   ```
2. If possible, inject such an image into the comparison
3. Observe failure handling

**Expected Result:**
- Pull fails
- "FAILED" entry in failed_images.log
- FAILED_COUNT incremented

**Pass Criteria:**
- [ ] Failure detected
- [ ] Error logged with exit code
- [ ] Script continues with other images

---

### FUNC-017: Pull Timeout

**Priority:** High  
**Description:** Verify pull timeout (TIME_OUT setting) is enforced.

**Pre-conditions:**
- Configure short timeout for testing
- Use large image or slow connection

**Test Steps:**
1. Modify config:
   ```bash
   TIME_OUT=10  # 10 seconds for testing
   ```
2. Attempt to pull a large image
3. Observe timeout behavior

**Expected Result:**
- Pull times out after configured duration
- "TIMEOUT" entry in failed log
- Script continues with other images

**Pass Criteria:**
- [ ] Timeout occurs at configured time
- [ ] TIMEOUT logged
- [ ] Other pulls not affected

---

### FUNC-018: Parallel Pull Limit

**Priority:** High  
**Description:** Verify MAX_PARALLEL setting limits concurrent pulls.

**Pre-conditions:**
- Multiple images need pulling
- MAX_PARALLEL is set in config (default: 4)

**Test Steps:**
1. Ensure many images need syncing
2. Monitor parallel jobs during execution:
   ```bash
   # In another terminal
   watch -n1 "ssh $NODE1 'ps aux | grep crictl | grep -v grep | wc -l'"
   ```
3. Run script

**Expected Result:**
- Never more than $MAX_PARALLEL crictl processes
- Jobs queued when limit reached

**Pass Criteria:**
- [ ] Parallel jobs <= $MAX_PARALLEL
- [ ] All images eventually pulled

---

### FUNC-019: Empty Image Entry Handling

**Priority:** Low  
**Description:** Verify the script handles edge cases where image arrays contain empty strings.

**Background:**
When `comm` returns no output (both nodes are synced), bash `mapfile` creates an array with one empty element. The script has two layers of protection:
1. Lines 163-165 clean empty entries before processing
2. Line 119 skips any remaining empty entries as a fallback

**Pre-conditions:**
- Both nodes have identical images (already in sync)

**Test Steps:**
1. Ensure both nodes are already synced (run script twice):
   ./image-sync.sh
   ./image-sync.sh
   2. Check logs for any "Skipping empty image entry" messages:
   grep "Skipping empty" $LOG_DIR/image-sync.log
   3. Verify "All images are already synced" message appears

**Expected Result:**
- Script handles already-synced nodes gracefully
- No errors or crashes
- Either "All images are already synced" OR "Skipping empty image entry" logged (depending on cleanup effectiveness)

**Pass Criteria:**
- [ ] Script completes without error
- [ ] No image pull attempts for empty entries
- [ ] Clean exit code: 0

**Note:** This tests defensive code. If "Skipping empty image entry" never appears, it means the primary cleanup (lines 163-165) is working correctly, which is the expected behavior.

---

## Category: Locking Mechanism

### FUNC-020: Lock File Creation

**Priority:** High  
**Description:** Verify lock file is created on script start.

**Pre-conditions:**
- Lock file doesn't exist or is stale

**Test Steps:**
1. Remove existing lock (if any):
   sudo rm -f /var/run/image-sync.lock
   2. Start script in background:
   ./image-sync.sh &
   SCRIPT_PID=$!
   3. Quickly check lock file exists:
   ls -la /var/run/image-sync.lock
   4. (Optional) Verify lock is held using lsof:
   lsof /var/run/image-sync.lock
   5. Wait for script to complete:
   wait $SCRIPT_PID
   **Expected Result:**
- Lock file created at `/var/run/image-sync.lock`
- File owned by user running the script

**Pass Criteria:**
- [ ] Lock file exists during script execution
- [ ] File has appropriate permissions (readable/writable by owner)
- [ ] (Optional) `lsof` shows the script process holding the file

---

### FUNC-021: Concurrent Execution Prevention

**Priority:** Critical  
**Description:** Verify only one instance can run at a time.

**Pre-conditions:**
- Lock file mechanism active

**Test Steps:**
1. Start script in background:
   ```bash
   ./image-sync.sh &
   FIRST_PID=$!
   ```
2. Immediately start second instance:
   ```bash
   ./image-sync.sh
   ```
3. Check second instance output

**Expected Result:**
- Second instance exits immediately
- Error: "Script already running. Lock active"
- First instance continues normally

**Pass Criteria:**
- [ ] Second instance blocked
- [ ] Clear error message
- [ ] Exit code: 1 for second instance

---

### FUNC-022: Lock Release on Normal Exit

**Priority:** High  
**Description:** Verify lock is released when script completes.

**Pre-conditions:**
- Script runs to completion

**Test Steps:**
1. Run script and wait for completion
2. Check if new instance can run:
   ```bash
   ./image-sync.sh
   ./image-sync.sh  # Should work, not be blocked
   ```

**Expected Result:**
- Lock released on exit
- Subsequent runs work

**Pass Criteria:**
- [ ] Second run not blocked
- [ ] No stale lock issues

---

## Category: Logging

### FUNC-023: Log File Creation

**Priority:** High  
**Description:** Verify all log files are created properly.

**Pre-conditions:**
- Clean log directory

**Test Steps:**
1. Clear old logs:
   ```bash
   rm -f $LOG_DIR/*.log
   ```
2. Run script
3. Check log files:
   ```bash
   ls -la $LOG_DIR/
   ```

**Expected Result:**
- image-sync.log created
- success_images.log created (if successes)
- failed_images.log created (if failures)

**Pass Criteria:**
- [ ] Main log file created
- [ ] Logs have timestamps
- [ ] Logs are readable

---

### FUNC-024: Log Timestamp Format

**Priority:** Low  
**Description:** Verify log entries have correct timestamp format.

**Pre-conditions:**
- Script has been run

**Test Steps:**
1. Check log format:
   ```bash
   head -5 $LOG_DIR/image-sync.log
   ```

**Expected Result:**
- Format: `[YYYY-MM-DD HH:MM:SS] message`

**Pass Criteria:**
- [ ] Timestamps present
- [ ] Format consistent

---

### FUNC-025: Summary Statistics

**Priority:** Medium  
**Description:** Verify summary statistics are accurate.

**Pre-conditions:**
- Script has completed with some operations

**Test Steps:**
1. Run script
2. Check summary output:
   ```bash
   tail -10 $LOG_DIR/image-sync.log
   ```
3. Manually count successes/failures
4. Compare with summary

**Expected Result:**
- SUCCESS_COUNT matches actual successes
- FAILED_COUNT matches actual failures
- "IMAGE SYNC COMPLETE" logged

**Pass Criteria:**
- [ ] Counts are accurate
- [ ] Summary logged correctly

---

## Functional Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| FUNC-001 | Valid Config Loading | High | | | |
| FUNC-002 | Missing Config File | High | | | |
| FUNC-003 | Partial Config | Medium | | | |
| FUNC-004 | SSH Both Nodes OK | High | | | |
| FUNC-005 | SSH Node 1 Fail | High | | | |
| FUNC-006 | SSH Node 2 Fail | High | | | |
| FUNC-007 | SSH Timeout | Medium | | | |
| FUNC-008 | Fetch Images | High | | | |
| FUNC-009 | Empty Image List | Medium | | | |
| FUNC-010 | Prefix Filtering | High | | | |
| FUNC-011 | Missing on Node 1 | High | | | |
| FUNC-012 | Missing on Node 2 | High | | | |
| FUNC-013 | Already Synced | High | | | |
| FUNC-014 | Bidirectional Sync | High | | | |
| FUNC-015 | Successful Pull | High | | | |
| FUNC-016 | Failed Pull | High | | | |
| FUNC-017 | Pull Timeout | High | | | |
| FUNC-018 | Parallel Limit | High | | | |
| FUNC-019 | Empty Entry Skip | Medium | | | |
| FUNC-020 | Lock Creation | High | | | |
| FUNC-021 | Concurrent Block | Critical | | | |
| FUNC-022 | Lock Release | High | | | |
| FUNC-023 | Log Creation | High | | | |
| FUNC-024 | Timestamp Format | Low | | | |
| FUNC-025 | Summary Stats | Medium | | | |

