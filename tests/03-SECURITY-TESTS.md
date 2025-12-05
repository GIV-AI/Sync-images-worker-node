# Security Test Cases

## Test ID: SEC-001 to SEC-025

---

## ⚠️ CRITICAL NOTICE

Security tests are **highest priority**. Any failure in this section represents a potential vulnerability that must be addressed before production deployment.

---

## Category: File System Security

### SEC-001: Config File Permissions

**Priority:** Critical  
**Description:** Verify configuration file has restrictive permissions (contains sensitive node information).

**Pre-conditions:**
- Configuration file exists

**Test Steps:**
1. Check file permissions:
   ```bash
   ls -la image-sync.conf
   stat image-sync.conf
   ```
2. Verify ownership

**Expected Result:**
- Permissions: 600 or 640 (owner read/write only)
- Owned by root or appropriate service account
- Group has no write access

**Security Risk if Failed:**
- Unauthorized users could modify node targets
- Could redirect sync to malicious nodes

**Pass Criteria:**
- [ ] Permissions <= 640
- [ ] Owned by appropriate user
- [ ] No world-readable/writable

---

### SEC-002: Script File Permissions

**Priority:** High  
**Description:** Verify script has appropriate permissions.

**Pre-conditions:**
- Script file exists

**Test Steps:**
1. Check permissions:
   ```bash
   ls -la image-sync.sh
   ```

**Expected Result:**
- Permissions: 700 or 750
- Executable only by owner/group
- Not world-writable

**Security Risk if Failed:**
- Malicious code injection into script
- Unauthorized execution

**Pass Criteria:**
- [ ] No world-write permission
- [ ] Owned by root or service account

---

### SEC-003: Lock File Location Security

**Priority:** High  
**Description:** Verify lock file is in secure location.

**Pre-conditions:**
- Script creates lock file

**Test Steps:**
1. Check lock file location and permissions:
   ```bash
   ls -la /var/run/image-sync.lock
   ```
2. Verify /var/run permissions

**Expected Result:**
- Lock file in /var/run (protected directory)
- Appropriate permissions

**Security Risk if Failed:**
- Lock file manipulation could allow concurrent runs
- Denial of service by creating permanent lock

**Pass Criteria:**
- [ ] Lock file in protected location
- [ ] Cannot be created/deleted by regular users

---

### SEC-004: Log Directory Permissions

**Priority:** High  
**Description:** Verify log directory has appropriate permissions.

**Pre-conditions:**
- Log directory exists

**Test Steps:**
1. Check directory permissions:
   ```bash
   ls -la /var/log/giindia/
   ls -la /var/log/giindia/sync-worker-node-images/
   ```

**Expected Result:**
- Directory owned by root or service account
- Permissions: 750 or stricter
- Not world-writable

**Security Risk if Failed:**
- Log injection attacks
- Log tampering to hide malicious activity

**Pass Criteria:**
- [ ] Directory not world-writable
- [ ] Appropriate ownership

---

### SEC-005: Log File Permissions

**Priority:** Medium  
**Description:** Verify log files have restrictive permissions.

**Pre-conditions:**
- Log files exist

**Test Steps:**
1. Check log file permissions:
   ```bash
   ls -la /var/log/giindia/sync-worker-node-images/*.log
   ```

**Expected Result:**
- Permissions: 640 or stricter
- Owned by script execution user

**Security Risk if Failed:**
- Sensitive information exposure
- Log modification by attackers

**Pass Criteria:**
- [ ] Logs not world-readable
- [ ] No sensitive data exposed

---

### SEC-006: Temporary File Security

**Priority:** High  
**Description:** Verify temporary files are created securely.

**Pre-conditions:**
- Script creates temp files with mktemp

**Test Steps:**
1. Monitor temp file creation:
   ```bash
   # In another terminal, watch /tmp
   watch -n1 "ls -la /tmp/tmp.* 2>/dev/null | tail -5"
   ```
2. Run script
3. Verify temp file permissions

**Expected Result:**
- mktemp creates files with 600 permissions
- Files cleaned up after script completion

**Security Risk if Failed:**
- Temp file race condition (symlink attacks)
- Information disclosure

**Pass Criteria:**
- [ ] Temp files have 600 permissions
- [ ] Files removed after execution
- [ ] Uses mktemp (not predictable names)

---

## Category: Command Injection Prevention

### SEC-007: Config Variable Injection - NODE Names

**Priority:** Critical  
**Description:** Test for command injection via NODE1/NODE2 variables.

**Pre-conditions:**
- Ability to modify config file

**Test Steps:**
1. Create malicious config:
   ```bash
   # Backup original
   cp image-sync.conf image-sync.conf.bak
   
   # Test injection attempt
   cat > image-sync.conf << 'EOF'
   NODE1="k8s-worker1; touch /tmp/pwned"
   NODE2="k8s-worker2"
   PREFIX1="bcm11"
   PREFIX2="nvcr.io/nvidia"
   LOG_DIR="/var/log/giindia/sync-worker-node-images"
   TIME_OUT=1800
   MAX_PARALLEL=4
   EOF
   ```
2. Run script
3. Check if injection succeeded:
   ```bash
   ls -la /tmp/pwned
   ```
4. Restore config:
   ```bash
   mv image-sync.conf.bak image-sync.conf
   ```

**Expected Result:**
- Injection should NOT succeed
- /tmp/pwned should NOT exist
- Script should fail safely or sanitize input

**Security Risk if Failed:**
- Remote code execution
- Full system compromise

**Pass Criteria:**
- [ ] Injection blocked
- [ ] No file created
- [ ] Script fails safely

---

### SEC-008: Config Variable Injection - Prefixes

**Priority:** Critical  
**Description:** Test for command injection via PREFIX variables.

**Pre-conditions:**
- Ability to modify config file

**Test Steps:**
1. Create malicious config:
   ```bash
   cat > test-inject.conf << 'EOF'
   NODE1="k8s-worker1"
   NODE2="k8s-worker2"
   PREFIX1="bcm11|touch /tmp/pwned2;#"
   PREFIX2="nvcr.io/nvidia"
   LOG_DIR="/var/log/giindia/sync-worker-node-images"
   TIME_OUT=1800
   MAX_PARALLEL=4
   EOF
   ```
2. Run with test config
3. Check for injection

**Expected Result:**
- Injection blocked
- grep pattern should be treated as pattern, not command

**Security Risk if Failed:**
- Code execution via regex injection

**Pass Criteria:**
- [ ] No command execution
- [ ] Safe pattern handling

---

### SEC-009: Config Variable Injection - LOG_DIR

**Priority:** Critical  
**Description:** Test for path traversal/injection via LOG_DIR.

**Pre-conditions:**
- Ability to modify config file

**Test Steps:**
1. Test path traversal:
   ```bash
   LOG_DIR="/var/log/giindia/../../../tmp/malicious"
   ```
2. Test with command injection:
   ```bash
   LOG_DIR="/tmp/test; touch /tmp/pwned3"
   ```
3. Run script with each config
4. Check results

**Expected Result:**
- Path traversal should be prevented or contained
- Command injection should not execute

**Security Risk if Failed:**
- Writing logs to arbitrary locations
- Code execution

**Pass Criteria:**
- [ ] Path traversal handled
- [ ] Command injection blocked

---

### SEC-010: Image Name Injection

**Priority:** Critical  
**Description:** Test for command injection via malicious image names.

**Pre-conditions:**
- Ability to influence image names in registry

**Test Steps:**
1. If possible, create image with malicious name:
   ```bash
   # Image name like: bcm11/test$(touch /tmp/pwned4):v1
   # Or: bcm11/test`id`:v1
   ```
2. Run sync script
3. Check if injection executed

**Expected Result:**
- Image names properly quoted
- No command execution from image names

**Security Risk if Failed:**
- Remote code execution via crafted image names

**Pass Criteria:**
- [ ] Special characters in image names handled safely
- [ ] No command execution

---

## Category: SSH Security

### SEC-011: SSH Key-Based Authentication

**Priority:** Critical  
**Description:** Verify script uses key-based auth, not passwords.

**Pre-conditions:**
- SSH configured for nodes

**Test Steps:**
1. Check SSH command in script uses BatchMode:
   ```bash
   grep "BatchMode" image-sync.sh
   ```
2. Verify no password prompts occur

**Expected Result:**
- BatchMode=yes enforced (fails if password needed)
- No passwords in script or config

**Security Risk if Failed:**
- Password exposure in logs or process list

**Pass Criteria:**
- [ ] BatchMode=yes used
- [ ] No password parameters

---

### SEC-012: SSH Host Key Verification

**Priority:** High  
**Description:** Verify SSH doesn't blindly accept unknown hosts.

**Pre-conditions:**
- SSH configured

**Test Steps:**
1. Check if StrictHostKeyChecking is disabled:
   ```bash
   grep -i "StrictHostKeyChecking" image-sync.sh
   grep -i "StrictHostKeyChecking" ~/.ssh/config
   ```
2. Test with unknown host

**Expected Result:**
- Should NOT have StrictHostKeyChecking=no
- Unknown hosts should be rejected

**Security Risk if Failed:**
- Man-in-the-middle attacks

**Pass Criteria:**
- [ ] No StrictHostKeyChecking=no
- [ ] Host keys verified

---

### SEC-013: SSH Private Key Permissions

**Priority:** Critical  
**Description:** Verify SSH private keys have correct permissions.

**Pre-conditions:**
- SSH keys used for authentication

**Test Steps:**
1. Check key permissions:
   ```bash
   ls -la ~/.ssh/id_*
   ls -la ~/.ssh/config
   ```

**Expected Result:**
- Private keys: 600
- Config: 600 or 644
- .ssh directory: 700

**Security Risk if Failed:**
- Key theft
- SSH refusing to use keys

**Pass Criteria:**
- [ ] Private key permissions = 600
- [ ] .ssh directory = 700

---

### SEC-014: SSH Agent Forwarding

**Priority:** Medium  
**Description:** Verify SSH agent forwarding is not enabled unnecessarily.

**Pre-conditions:**
- SSH configured

**Test Steps:**
1. Check for agent forwarding:
   ```bash
   grep -i "ForwardAgent" image-sync.sh
   grep -i "ForwardAgent" ~/.ssh/config
   ```

**Expected Result:**
- Agent forwarding should be disabled
- No -A flag in SSH commands

**Security Risk if Failed:**
- Key exposure on remote hosts

**Pass Criteria:**
- [ ] No unnecessary agent forwarding

---

## Category: Privilege & Access Control

### SEC-015: Minimum Privilege Principle

**Priority:** High  
**Description:** Verify script runs with minimum necessary privileges.

**Pre-conditions:**
- Script can be analyzed

**Test Steps:**
1. Identify required privileges:
   - SSH to nodes
   - Write to log directory
   - Create lock file
2. Verify no additional privileges needed
3. Test running as non-root (if possible)

**Expected Result:**
- Script works without root where possible
- Only necessary capabilities required

**Security Risk if Failed:**
- Privilege escalation
- Unnecessary system access

**Pass Criteria:**
- [ ] Minimum privileges documented
- [ ] No unnecessary root operations

---

### SEC-016: Remote Command Scope

**Priority:** Critical  
**Description:** Verify remote commands are limited to necessary operations.

**Pre-conditions:**
- Script executes SSH commands

**Test Steps:**
1. List all SSH commands in script:
   ```bash
   grep "ssh.*\$NODE" image-sync.sh
   ```
2. Verify each command is necessary and safe

**Expected Result:**
- Only `crictl` commands executed remotely
- No shell expansions on remote side

**Security Risk if Failed:**
- Remote code execution
- Data exfiltration

**Pass Criteria:**
- [ ] Commands are minimal
- [ ] No dangerous operations

---

### SEC-017: sudo/Privilege Escalation

**Priority:** Critical  
**Description:** Verify no unauthorized privilege escalation.

**Pre-conditions:**
- Script analyzed

**Test Steps:**
1. Check for sudo/su usage:
   ```bash
   grep -E "sudo|su -" image-sync.sh
   ```
2. Check remote commands for privilege escalation

**Expected Result:**
- No sudo in script (if not needed)
- No su to other users

**Security Risk if Failed:**
- Privilege escalation vectors

**Pass Criteria:**
- [ ] No unnecessary sudo
- [ ] No su commands

---

## Category: Information Disclosure

### SEC-018: Sensitive Data in Logs

**Priority:** High  
**Description:** Verify logs don't contain sensitive information.

**Pre-conditions:**
- Script has generated logs

**Test Steps:**
1. Search logs for sensitive patterns:
   ```bash
   grep -iE "password|secret|key|token|credential" /var/log/giindia/sync-worker-node-images/*.log
   ```
2. Check for IP addresses or internal hostnames

**Expected Result:**
- No passwords or secrets in logs
- Only necessary information logged

**Security Risk if Failed:**
- Credential leakage
- Infrastructure mapping

**Pass Criteria:**
- [ ] No sensitive data in logs
- [ ] Appropriate log level

---

### SEC-019: Error Message Information Leakage

**Priority:** Medium  
**Description:** Verify error messages don't reveal sensitive details.

**Pre-conditions:**
- Trigger various errors

**Test Steps:**
1. Cause authentication failure
2. Cause network failure
3. Review error messages for sensitive info

**Expected Result:**
- Error messages are helpful but not revealing
- No stack traces or internal paths exposed to users

**Security Risk if Failed:**
- Information useful for attackers

**Pass Criteria:**
- [ ] Errors don't reveal internal structure
- [ ] No stack traces in user output

---

### SEC-020: Process List Exposure

**Priority:** High  
**Description:** Verify sensitive data not visible in process list.

**Pre-conditions:**
- Script running

**Test Steps:**
1. While script runs, check process list:
   ```bash
   ps aux | grep image-sync
   ps aux | grep ssh
   ps aux | grep crictl
   ```
2. Look for passwords or sensitive args

**Expected Result:**
- No passwords in process arguments
- No sensitive tokens visible

**Security Risk if Failed:**
- Credential exposure to local users

**Pass Criteria:**
- [ ] No sensitive data in ps output

---

## Category: Network Security

### SEC-021: Registry Authentication

**Priority:** High  
**Description:** Verify secure authentication to container registries.

**Pre-conditions:**
- Private registries require authentication

**Test Steps:**
1. Check how registry credentials are stored
2. Verify credentials aren't in script or config
3. Check crictl auth method

**Expected Result:**
- Credentials stored securely (e.g., containerd config)
- Not in plaintext in script

**Security Risk if Failed:**
- Registry credential exposure

**Pass Criteria:**
- [ ] Credentials not in script
- [ ] Secure credential storage

---

### SEC-022: TLS/SSL Certificate Verification

**Priority:** High  
**Description:** Verify TLS certificates are validated for registries.

**Pre-conditions:**
- HTTPS registries

**Test Steps:**
1. Check if insecure registries are allowed:
   ```bash
   ssh k8s-worker1 "cat /etc/containerd/config.toml | grep -A5 insecure"
   ```
2. Verify no --insecure flags

**Expected Result:**
- TLS verification enabled
- No insecure registry connections

**Security Risk if Failed:**
- Man-in-the-middle attacks
- Malicious image injection

**Pass Criteria:**
- [ ] TLS verification enabled
- [ ] No --insecure flags

---

## Category: Input Validation

### SEC-023: Configuration Value Validation

**Priority:** High  
**Description:** Verify configuration values are validated.

**Pre-conditions:**
- Can modify config file

**Test Steps:**
1. Test invalid TIME_OUT:
   ```bash
   TIME_OUT=-1
   TIME_OUT="abc"
   TIME_OUT=9999999999
   ```
2. Test invalid MAX_PARALLEL:
   ```bash
   MAX_PARALLEL=0
   MAX_PARALLEL=-1
   MAX_PARALLEL=1000
   ```
3. Observe behavior

**Expected Result:**
- Invalid values rejected or sanitized
- Script fails safely

**Security Risk if Failed:**
- Resource exhaustion
- Unexpected behavior

**Pass Criteria:**
- [ ] Invalid values handled
- [ ] Reasonable limits enforced

---

### SEC-024: Path Traversal Prevention

**Priority:** Critical  
**Description:** Verify path traversal is prevented in file operations.

**Pre-conditions:**
- Script creates files/directories

**Test Steps:**
1. Test LOG_DIR with traversal:
   ```bash
   LOG_DIR="../../etc/cron.d"
   LOG_DIR="/var/log/../../../tmp"
   ```
2. Check where files are actually created

**Expected Result:**
- Path traversal blocked
- Files only created in expected locations

**Security Risk if Failed:**
- Arbitrary file write
- System compromise

**Pass Criteria:**
- [ ] Traversal attempts blocked
- [ ] Safe path handling

---

### SEC-025: Special Character Handling

**Priority:** High  
**Description:** Verify special characters are handled safely throughout.

**Pre-conditions:**
- Can test with special inputs

**Test Steps:**
1. Test node names with special chars:
   ```bash
   NODE1='node$(whoami)'
   NODE1='node`id`'
   NODE1='node;rm -rf /'
   ```
2. Observe handling

**Expected Result:**
- Special characters escaped or rejected
- No command execution

**Security Risk if Failed:**
- Command injection
- System damage

**Pass Criteria:**
- [ ] Special chars handled safely
- [ ] No injection possible

---

## Security Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| SEC-001 | Config File Permissions | Critical | | | |
| SEC-002 | Script File Permissions | High | | | |
| SEC-003 | Lock File Security | High | | | |
| SEC-004 | Log Directory Permissions | High | | | |
| SEC-005 | Log File Permissions | Medium | | | |
| SEC-006 | Temp File Security | High | | | |
| SEC-007 | Node Name Injection | Critical | | | |
| SEC-008 | Prefix Injection | Critical | | | |
| SEC-009 | LOG_DIR Injection | Critical | | | |
| SEC-010 | Image Name Injection | Critical | | | |
| SEC-011 | SSH Key Auth | Critical | | | |
| SEC-012 | SSH Host Keys | High | | | |
| SEC-013 | SSH Key Permissions | Critical | | | |
| SEC-014 | SSH Agent Forwarding | Medium | | | |
| SEC-015 | Minimum Privilege | High | | | |
| SEC-016 | Remote Command Scope | Critical | | | |
| SEC-017 | Privilege Escalation | Critical | | | |
| SEC-018 | Sensitive Data in Logs | High | | | |
| SEC-019 | Error Info Leakage | Medium | | | |
| SEC-020 | Process List Exposure | High | | | |
| SEC-021 | Registry Authentication | High | | | |
| SEC-022 | TLS Verification | High | | | |
| SEC-023 | Config Validation | High | | | |
| SEC-024 | Path Traversal | Critical | | | |
| SEC-025 | Special Char Handling | High | | | |

---

## Security Test Sign-off

**All CRITICAL tests must PASS before production deployment.**

| Reviewer | Role | Date | Signature |
|----------|------|------|-----------|
| | Security Lead | | |
| | DevOps Lead | | |
| | System Admin | | |

