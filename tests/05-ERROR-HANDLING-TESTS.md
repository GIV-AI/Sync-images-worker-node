# Error Handling Test Cases

## Test ID: ERR-001 to ERR-025

---

## Overview

Error handling tests verify the script's ability to handle failures gracefully, provide meaningful error messages, and recover or fail safely.

---

## Category: Configuration Errors

### ERR-001: Corrupt Configuration File

**Priority:** High  
**Description:** Test behavior with syntactically invalid config file.

**Pre-conditions:**
- Create corrupt config file

**Test Steps:**
1. Create corrupt config:
   ```bash
   cp image-sync.conf image-sync.conf.bak
   echo "NODE1=\"k8s-worker1" > image-sync.conf  # Missing closing quote
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
- Script fails with syntax error
- Clear error message
- No partial execution

**Pass Criteria:**
- [ ] Script exits on bad syntax
- [ ] Error message indicates config issue
- [ ] Exit code non-zero

---

### ERR-002: Empty Configuration File

**Priority:** Medium  
**Description:** Test with empty configuration file.

**Pre-conditions:**
- Create empty config

**Test Steps:**
1. Create empty config:
   ```bash
   cp image-sync.conf image-sync.conf.bak
   > image-sync.conf
   ```
2. Run script
3. Restore config

**Expected Result:**
- Script fails due to missing variables
- Variables are undefined/empty
- No silent failures

**Pass Criteria:**
- [ ] Fails safely
- [ ] Error indicates missing config

---

### ERR-003: Invalid Node Hostname

**Priority:** High  
**Description:** Test with non-existent/invalid hostname.

**Pre-conditions:**
- Set invalid hostname in config

**Test Steps:**
1. Modify config:
   ```bash
   NODE1="non-existent-node-xyz"
   ```
2. Run script
3. Check error handling

**Expected Result:**
- SSH fails with host not found
- Script exits cleanly
- Clear error message

**Pass Criteria:**
- [ ] Host resolution fails gracefully
- [ ] Error message helpful
- [ ] Exits with error code

---

### ERR-004: Invalid IP Address Format

**Priority:** Medium  
**Description:** Test with malformed IP address.

**Pre-conditions:**
- Set invalid IP in config

**Test Steps:**
1. Modify config:
   ```bash
   NODE1="999.999.999.999"
   ```
2. Run script
3. Observe error handling

**Expected Result:**
- Connection fails
- Clear error about unreachable host
- Script exits

**Pass Criteria:**
- [ ] Invalid IP handled
- [ ] No crash
- [ ] Clear error

---

### ERR-005: Invalid TIME_OUT Value

**Priority:** Medium  
**Description:** Test with invalid timeout values.

**Test Cases:**
| Value | Type |
|-------|------|
| -1 | Negative |
| 0 | Zero |
| abc | String |
| 1.5 | Float |
| "" | Empty |

**Test Steps:**
1. For each invalid value:
   ```bash
   TIME_OUT=<value>
   ./image-sync.sh
   ```
2. Observe behavior

**Expected Result:**
- Script handles or rejects invalid values
- Uses default or fails safely
- No infinite timeout

**Pass Criteria:**
- [ ] Negative value handled
- [ ] Zero value handled
- [ ] String value handled
- [ ] Float value handled
- [ ] Empty value handled

---

### ERR-006: Invalid MAX_PARALLEL Value

**Priority:** Medium  
**Description:** Test with invalid parallel values.

**Test Cases:**
| Value | Expected Behavior |
|-------|-------------------|
| 0 | Should fail or use default |
| -1 | Should fail or use default |
| 1000 | Should work but may be slow |
| abc | Should fail |

**Test Steps:**
1. Test each value
2. Monitor behavior and resource usage

**Expected Result:**
- Invalid values rejected or sanitized
- Extreme values handled

**Pass Criteria:**
- [ ] Zero handled
- [ ] Negative handled
- [ ] Extreme high handled
- [ ] Non-numeric handled

---

## Category: SSH Errors

### ERR-007: SSH Authentication Failure

**Priority:** High  
**Description:** Test behavior when SSH auth fails.

**Pre-conditions:**
- Remove SSH key or use wrong identity

**Test Steps:**
1. Temporarily rename SSH key:
   ```bash
   mv ~/.ssh/id_rsa ~/.ssh/id_rsa.bak
   ```
2. Run script
3. Restore key:
   ```bash
   mv ~/.ssh/id_rsa.bak ~/.ssh/id_rsa
   ```

**Expected Result:**
- SSH fails with auth error
- Script exits with error
- No password prompt (BatchMode)

**Pass Criteria:**
- [ ] Auth failure detected
- [ ] Clear error message
- [ ] Script exits cleanly

---

### ERR-008: SSH Permission Denied

**Priority:** High  
**Description:** Test when SSH access is denied by remote host.

**Pre-conditions:**
- User blocked on remote host

**Test Steps:**
1. Block user on remote host:
   ```bash
   # On remote host, add to /etc/ssh/sshd_config:
   # DenyUsers testuser
   ```
2. Run script
3. Observe error

**Expected Result:**
- Permission denied error
- Script exits
- Clear message

**Pass Criteria:**
- [ ] Permission denied handled
- [ ] No hanging

---

### ERR-009: SSH Connection Refused

**Priority:** High  
**Description:** Test when SSH service is down.

**Pre-conditions:**
- SSH service stopped on remote

**Test Steps:**
1. Stop SSH on remote:
   ```bash
   ssh k8s-worker1 "sudo systemctl stop sshd"
   # Or simulate with firewall
   ```
2. Run script
3. Restart SSH

**Expected Result:**
- Connection refused error
- Timeout or immediate failure
- Script exits

**Pass Criteria:**
- [ ] Connection refused handled
- [ ] Reasonable timeout
- [ ] Clear error

---

### ERR-010: SSH Drops During Operation

**Priority:** High  
**Description:** Test when SSH connection drops mid-operation.

**Pre-conditions:**
- Long-running SSH operation in progress

**Test Steps:**
1. Start script
2. During pull, kill SSH connection:
   ```bash
   # On remote, kill the SSH session
   ssh k8s-worker1 "pkill -u $(whoami) sshd"
   ```
3. Observe recovery

**Expected Result:**
- Operation fails
- Script detects failure
- Logs error
- Continues with other operations

**Pass Criteria:**
- [ ] Connection drop detected
- [ ] Error logged
- [ ] Script continues

---

## Category: crictl Errors

### ERR-011: crictl Not Installed

**Priority:** High  
**Description:** Test when crictl is not available on node.

**Pre-conditions:**
- crictl missing or not in PATH

**Test Steps:**
1. Rename crictl on remote:
   ```bash
   ssh k8s-worker1 "sudo mv /usr/local/bin/crictl /usr/local/bin/crictl.bak"
   ```
2. Run script
3. Restore:
   ```bash
   ssh k8s-worker1 "sudo mv /usr/local/bin/crictl.bak /usr/local/bin/crictl"
   ```

**Expected Result:**
- Command not found error
- Script fails appropriately
- Clear error message

**Pass Criteria:**
- [ ] Missing crictl detected
- [ ] Error message clear
- [ ] Script fails safely

---

### ERR-012: crictl Connection to containerd Failed

**Priority:** High  
**Description:** Test when containerd is not running.

**Pre-conditions:**
- containerd stopped on node

**Test Steps:**
1. Stop containerd:
   ```bash
   ssh k8s-worker1 "sudo systemctl stop containerd"
   ```
2. Run script
3. Restart containerd:
   ```bash
   ssh k8s-worker1 "sudo systemctl start containerd"
   ```

**Expected Result:**
- crictl commands fail
- Error about containerd connection
- Script handles failure

**Pass Criteria:**
- [ ] containerd failure detected
- [ ] Clear error
- [ ] No hang

---

### ERR-013: crictl Pull - Image Not Found

**Priority:** High  
**Description:** Test when image doesn't exist in registry.

**Pre-conditions:**
- Non-existent image name

**Test Steps:**
1. Add non-existent image to sync list (manually or via test)
2. Run script
3. Check failure handling

**Expected Result:**
- Pull fails with "not found"
- Logged as FAILED
- Script continues

**Pass Criteria:**
- [ ] Image not found handled
- [ ] Logged appropriately
- [ ] Other images still synced

---

### ERR-014: crictl Pull - Registry Unreachable

**Priority:** High  
**Description:** Test when registry is not accessible.

**Pre-conditions:**
- Block access to registry

**Test Steps:**
1. Block registry:
   ```bash
   ssh k8s-worker1 "sudo iptables -A OUTPUT -d registry.example.com -j DROP"
   ```
2. Run script
3. Unblock:
   ```bash
   ssh k8s-worker1 "sudo iptables -D OUTPUT -d registry.example.com -j DROP"
   ```

**Expected Result:**
- Pull fails with network error
- Timeout may occur
- Script handles gracefully

**Pass Criteria:**
- [ ] Registry unreachable handled
- [ ] Timeout works
- [ ] Error logged

---

### ERR-015: crictl JSON Parse Error

**Priority:** Medium  
**Description:** Test when crictl returns invalid JSON.

**Pre-conditions:**
- Somehow crictl returns malformed JSON

**Test Steps:**
1. Create wrapper script that returns bad JSON:
   ```bash
   # Create mock crictl that returns invalid JSON
   ```
2. Test jq error handling

**Expected Result:**
- jq parse error handled
- Script fails safely
- Error logged

**Pass Criteria:**
- [ ] JSON errors handled
- [ ] No silent failure

---

## Category: File System Errors

### ERR-016: Lock File Directory Not Writable

**Priority:** High  
**Description:** Test when /var/run is not writable.

**Pre-conditions:**
- /var/run permissions changed

**Test Steps:**
1. Make /var/run read-only (if possible in test env)
2. Run script
3. Observe error handling

**Expected Result:**
- Cannot create lock file
- Clear error
- Script exits

**Pass Criteria:**
- [ ] Lock creation failure handled
- [ ] Clear error message

---

### ERR-017: Log Directory Not Writable

**Priority:** High  
**Description:** Test when log directory is not writable.

**Pre-conditions:**
- Log directory permissions changed

**Test Steps:**
1. Make log directory read-only:
   ```bash
   chmod 555 /var/log/giindia/sync-worker-node-images
   ```
2. Run script
3. Restore:
   ```bash
   chmod 755 /var/log/giindia/sync-worker-node-images
   ```

**Expected Result:**
- Log write failure
- Script may fail or warn
- No silent failure

**Pass Criteria:**
- [ ] Write failure detected
- [ ] Appropriate handling

---

### ERR-018: Log Directory Does Not Exist

**Priority:** Medium  
**Description:** Test when log directory is missing.

**Pre-conditions:**
- Log directory deleted

**Test Steps:**
1. Remove log directory:
   ```bash
   rm -rf /var/log/giindia/sync-worker-node-images
   ```
2. Run script (should create directory)
3. Verify creation

**Expected Result:**
- mkdir -p creates directory
- Logs work normally
- No error

**Pass Criteria:**
- [ ] Directory auto-created
- [ ] Logs written successfully

---

### ERR-019: Temporary File Creation Failure

**Priority:** Medium  
**Description:** Test when temp files cannot be created.

**Pre-conditions:**
- /tmp is full or read-only

**Test Steps:**
1. Fill /tmp or make read-only
2. Run script
3. Check mktemp failure handling

**Expected Result:**
- mktemp fails
- Script handles error
- No silent failure

**Pass Criteria:**
- [ ] Temp file failure handled
- [ ] Error reported

---

## Category: Data Errors

### ERR-020: Empty Image List Response

**Priority:** Medium  
**Description:** Test when crictl returns empty image list.

**Pre-conditions:**
- Node has no images (or none matching prefix)

**Test Steps:**
1. Clear all images on test node (or use prefix that matches nothing)
2. Run script
3. Check handling

**Expected Result:**
- Empty list handled
- "No images" or similar message
- Script continues

**Pass Criteria:**
- [ ] Empty list handled
- [ ] No crash
- [ ] Appropriate message

---

### ERR-021: Malformed Image Names

**Priority:** Medium  
**Description:** Test with unusual image name formats.

**Test Cases:**
| Image Name | Issue |
|------------|-------|
| `image` | No tag |
| `image:` | Empty tag |
| `repo/image@sha256:...` | Digest format |
| `a/b/c/d/image:tag` | Deep nesting |
| `IMAGE:TAG` | Uppercase |

**Test Steps:**
1. Pull images with various formats
2. Run sync
3. Verify handling

**Expected Result:**
- All valid formats handled
- Invalid formats skipped/logged
- No parsing errors

**Pass Criteria:**
- [ ] Various formats handled
- [ ] No crashes on edge cases

---

### ERR-022: Special Characters in Image Tags

**Priority:** Medium  
**Description:** Test images with special characters in tags.

**Test Cases:**
- `image:v1.2.3-beta+build.123`
- `image:feature/branch-name`
- `image:sha-abc123`

**Test Steps:**
1. Pull images with special character tags
2. Run sync
3. Verify handling

**Expected Result:**
- Special characters handled correctly
- Proper quoting in commands
- Successful sync

**Pass Criteria:**
- [ ] Special chars in tags handled
- [ ] No command parsing issues

---

## Category: Process Errors

### ERR-023: Background Job Failures

**Priority:** High  
**Description:** Test handling when background pull jobs fail.

**Pre-conditions:**
- Parallel pulls in progress

**Test Steps:**
1. Configure conditions for some pulls to fail
2. Run script
3. Verify failure detection and logging

**Expected Result:**
- Failed jobs detected
- Other jobs continue
- Failures logged with correct count

**Pass Criteria:**
- [ ] Failed jobs detected
- [ ] Correct failure count
- [ ] Other jobs unaffected

---

### ERR-024: Wait Command Failures

**Priority:** Low  
**Description:** Test behavior if wait command has issues.

**Pre-conditions:**
- Unusual process states

**Test Steps:**
1. Run script with many parallel jobs
2. Monitor wait behavior
3. Check for orphan processes

**Expected Result:**
- All jobs properly waited
- No orphan processes
- Clean completion

**Pass Criteria:**
- [ ] All jobs cleaned up
- [ ] No orphans

---

### ERR-025: Signal During Pull

**Priority:** Medium  
**Description:** Test when signal received during pull operation.

**Pre-conditions:**
- Pull operation in progress

**Test Steps:**
1. Start script
2. Send various signals:
   ```bash
   kill -HUP $PID
   kill -USR1 $PID
   ```
3. Observe behavior

**Expected Result:**
- Signals handled appropriately
- No corruption
- Logs reflect interruption

**Pass Criteria:**
- [ ] Signals handled
- [ ] No data corruption
- [ ] Clean state

---

## Error Handling Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| ERR-001 | Corrupt Config File | High | | | |
| ERR-002 | Empty Config File | Medium | | | |
| ERR-003 | Invalid Node Hostname | High | | | |
| ERR-004 | Invalid IP Format | Medium | | | |
| ERR-005 | Invalid TIME_OUT | Medium | | | |
| ERR-006 | Invalid MAX_PARALLEL | Medium | | | |
| ERR-007 | SSH Auth Failure | High | | | |
| ERR-008 | SSH Permission Denied | High | | | |
| ERR-009 | SSH Connection Refused | High | | | |
| ERR-010 | SSH Drops Mid-Op | High | | | |
| ERR-011 | crictl Not Installed | High | | | |
| ERR-012 | containerd Not Running | High | | | |
| ERR-013 | Image Not Found | High | | | |
| ERR-014 | Registry Unreachable | High | | | |
| ERR-015 | JSON Parse Error | Medium | | | |
| ERR-016 | Lock Dir Not Writable | High | | | |
| ERR-017 | Log Dir Not Writable | High | | | |
| ERR-018 | Log Dir Missing | Medium | | | |
| ERR-019 | Temp File Creation | Medium | | | |
| ERR-020 | Empty Image List | Medium | | | |
| ERR-021 | Malformed Image Names | Medium | | | |
| ERR-022 | Special Chars in Tags | Medium | | | |
| ERR-023 | Background Job Failures | High | | | |
| ERR-024 | Wait Command Issues | Low | | | |
| ERR-025 | Signal During Pull | Medium | | | |

