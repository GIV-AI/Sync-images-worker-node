# Image Sync Script - Test Documentation Overview

## Purpose

This documentation provides comprehensive test cases for the `image-sync.sh` script. The script synchronizes container images between two Kubernetes worker nodes using SSH and `crictl`.

---

## Test Documents Index

| Document | Description | Priority |
|----------|-------------|----------|
| [01-PREREQUISITES.md](./01-PREREQUISITES.md) | Test environment setup requirements | **Required First** |
| [02-FUNCTIONAL-TESTS.md](./02-FUNCTIONAL-TESTS.md) | Core functionality testing | High |
| [03-SECURITY-TESTS.md](./03-SECURITY-TESTS.md) | Security vulnerability testing | **Critical** |
| [04-STRESS-TESTS.md](./04-STRESS-TESTS.md) | Performance and load testing | Medium |
| [05-ERROR-HANDLING-TESTS.md](./05-ERROR-HANDLING-TESTS.md) | Error recovery and edge cases | High |
| [06-EDGE-CASES.md](./06-EDGE-CASES.md) | Boundary conditions and special scenarios | Medium |
| [07-INTEGRATION-TESTS.md](./07-INTEGRATION-TESTS.md) | End-to-end and cron integration | Medium |
| [08-TEST-RESULTS-TEMPLATE.md](./08-TEST-RESULTS-TEMPLATE.md) | Template for recording results | - |

---

## Script Under Test

**File:** `image-sync.sh`  
**Version:** 1.0  
**Configuration:** `image-sync.conf`

### Script Flow Summary

```
1. Load configuration file
2. Acquire file lock (prevent concurrent runs)
3. Check SSH connectivity to both nodes
4. Fetch image lists from both nodes via crictl
5. Filter images by configured prefixes
6. Compare and identify missing images
7. Pull missing images in parallel (with timeout)
8. Log results (success/failure)
9. Release lock and cleanup
```

---

## Test Environment Requirements

- **Nodes:** 2 Kubernetes worker nodes with `crictl` installed
- **SSH:** Passwordless SSH access from test machine to both nodes
- **Dependencies:** `jq`, `bash 4+`, `timeout`, `flock`
- **Permissions:** Root or sudo access on test machine

---

## Testing Priority Order

1. **Prerequisites Check** - Verify environment is ready
2. **Security Tests** - Critical security vulnerabilities first
3. **Functional Tests** - Core functionality verification
4. **Error Handling Tests** - Failure scenarios
5. **Edge Cases** - Boundary conditions
6. **Stress Tests** - Performance under load
7. **Integration Tests** - Full system integration

---

## How to Use This Documentation

### For Testers

1. Read `01-PREREQUISITES.md` and set up test environment
2. Execute tests in priority order
3. Record results in `08-TEST-RESULTS-TEMPLATE.md`
4. Document any failures with full reproduction steps
5. Take screenshots of terminal output where applicable

### Test Case Format

Each test case contains:
- **Test ID:** Unique identifier
- **Category:** Test category
- **Priority:** Critical/High/Medium/Low
- **Description:** What is being tested
- **Pre-conditions:** Required state before test
- **Test Steps:** Step-by-step execution instructions
- **Expected Result:** What should happen
- **Pass/Fail Criteria:** How to determine result

---

## Severity Definitions

| Severity | Description |
|----------|-------------|
| **Critical** | Security vulnerability or data loss potential |
| **High** | Core functionality broken, no workaround |
| **Medium** | Functionality impaired, workaround exists |
| **Low** | Minor issue, cosmetic, or enhancement |

---

## Contact

For questions about these tests, contact the development team.

---

**Last Updated:** December 2024  
**Document Version:** 1.0

