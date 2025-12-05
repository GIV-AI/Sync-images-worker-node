# Edge Case Test Cases

## Test ID: EDGE-001 to EDGE-020

---

## Overview

Edge case tests cover boundary conditions, unusual inputs, and scenarios that may not occur frequently but could cause unexpected behavior.

---

## Category: Empty/Null Conditions

### EDGE-001: Both Nodes Have Identical Images

**Priority:** Medium  
**Description:** Test when nodes are perfectly synchronized.

**Pre-conditions:**
- Both nodes have exact same images

**Test Steps:**
1. Manually sync nodes to identical state
2. Run script
3. Verify no unnecessary operations

**Expected Result:**
- "All images are already synced" message
- No pull operations
- SUCCESS_COUNT = 0
- FAILED_COUNT = 0

**Pass Criteria:**
- [ ] Sync detection correct
- [ ] No unnecessary work
- [ ] Quick completion

---

### EDGE-002: Both Nodes Have Zero Images

**Priority:** Low  
**Description:** Test when both nodes have no images matching prefixes.

**Pre-conditions:**
- No images with configured prefixes on either node

**Test Steps:**
1. Ensure no images match PREFIX1 or PREFIX2
2. Run script
3. Check handling

**Expected Result:**
- "Images on NODE: 0" for both
- "All images are already synced"
- Script completes successfully

**Pass Criteria:**
- [ ] Empty lists handled
- [ ] No errors
- [ ] Clean completion

---

### EDGE-003: One Node Has Images, Other Has None

**Priority:** Medium  
**Description:** Test asymmetric case where one node is completely empty.

**Pre-conditions:**
- Node 1 has images, Node 2 has none

**Test Steps:**
1. Clear all matching images on Node 2
2. Run script
3. Verify all images synced to Node 2

**Expected Result:**
- All images from Node 1 pulled to Node 2
- Correct count logged
- SUCCESS_COUNT = (number of images)

**Pass Criteria:**
- [ ] All images synced
- [ ] Counts accurate
- [ ] No errors

---

### EDGE-004: Single Image Difference

**Priority:** Medium  
**Description:** Test when only one image differs between nodes.

**Pre-conditions:**
- Exactly one image different

**Test Steps:**
1. Ensure all images match except one
2. Run script
3. Verify only that one image synced

**Expected Result:**
- Only single image pulled
- Efficient detection
- SUCCESS_COUNT = 1

**Pass Criteria:**
- [ ] Only one image synced
- [ ] No unnecessary operations

---

## Category: Image Name Edge Cases

### EDGE-005: Image with No Tag (Latest)

**Priority:** Medium  
**Description:** Test handling of images without explicit tags.

**Pre-conditions:**
- Image pulled without tag (defaults to :latest)

**Test Steps:**
1. Pull image without tag:
   ```bash
   ssh k8s-worker1 "crictl pull bcm11/testimage"
   ```
2. Check how crictl lists it
3. Run sync
4. Verify handling

**Expected Result:**
- Image detected (may be listed as :latest)
- Synced correctly
- No confusion

**Pass Criteria:**
- [ ] Tagless images handled
- [ ] Correct sync

---

### EDGE-006: Image with SHA256 Digest

**Priority:** Medium  
**Description:** Test images referenced by digest instead of tag.

**Pre-conditions:**
- Image pulled by digest

**Test Steps:**
1. Pull by digest:
   ```bash
   ssh k8s-worker1 "crictl pull bcm11/image@sha256:abc123..."
   ```
2. Check listing format
3. Run sync

**Expected Result:**
- Digest images handled
- May or may not sync (based on repoTags)
- No errors

**Pass Criteria:**
- [ ] Digest format handled
- [ ] No crashes

---

### EDGE-007: Very Long Image Names

**Priority:** Low  
**Description:** Test with unusually long image names/tags.

**Pre-conditions:**
- Create image with very long name

**Test Steps:**
1. Create image with 200+ character name
2. Run sync
3. Check for truncation or errors

**Expected Result:**
- Long names handled
- No truncation issues
- Logs display correctly

**Pass Criteria:**
- [ ] Long names work
- [ ] No truncation

---

### EDGE-008: Image Name with Unicode Characters

**Priority:** Low  
**Description:** Test with unicode in image names (if allowed by registry).

**Pre-conditions:**
- Registry allows unicode (unlikely, but test)

**Test Steps:**
1. Attempt to create image with unicode
2. Run sync
3. Observe handling

**Expected Result:**
- If registry allows: handled correctly
- If not: proper error handling

**Pass Criteria:**
- [ ] Unicode handled or rejected gracefully

---

### EDGE-009: Multiple Tags for Same Image

**Priority:** Medium  
**Description:** Test when same image has multiple tags.

**Pre-conditions:**
- Image tagged with multiple tags

**Test Steps:**
1. Tag image multiple ways:
   ```bash
   crictl tag image:v1 image:v1.0
   crictl tag image:v1 image:latest
   ```
2. Run sync
3. Verify all tags synced

**Expected Result:**
- Each tag treated as separate image
- All tags synced
- Some may be quick (same underlying image)

**Pass Criteria:**
- [ ] All tags synced
- [ ] Efficient handling of same underlying data

---

## Category: Prefix Edge Cases

### EDGE-010: Prefix Matches Full Image Name

**Priority:** Low  
**Description:** Test when prefix exactly matches an image name.

**Pre-conditions:**
- Image name equals prefix

**Test Steps:**
1. Create image named exactly `bcm11:latest`
2. Run sync
3. Verify handling

**Expected Result:**
- Image matched and synced
- No regex issues

**Pass Criteria:**
- [ ] Exact prefix match works

---

### EDGE-011: Similar Prefixes

**Priority:** Medium  
**Description:** Test discrimination between similar prefixes.

**Pre-conditions:**
- Images with similar but different prefixes

**Test Steps:**
1. Have images like:
   - `bcm11/app:v1` (should match)
   - `bcm111/app:v1` (should NOT match)
   - `bcm1/app:v1` (should NOT match)
2. Run sync
3. Verify correct filtering

**Expected Result:**
- Only exact prefix matches included
- Similar prefixes excluded

**Pass Criteria:**
- [ ] Exact prefix matching
- [ ] No false positives

---

### EDGE-012: Overlapping Prefixes

**Priority:** Low  
**Description:** Test when PREFIX1 is substring of PREFIX2 or vice versa.

**Pre-conditions:**
- Configure overlapping prefixes

**Test Steps:**
1. Configure:
   ```bash
   PREFIX1="nvcr.io"
   PREFIX2="nvcr.io/nvidia"
   ```
2. Run sync
3. Check for duplicates or issues

**Expected Result:**
- Both prefixes work
- No duplicate processing
- Correct filtering

**Pass Criteria:**
- [ ] Overlapping prefixes work
- [ ] No duplicates

---

## Category: Timing Edge Cases

### EDGE-013: Image Deleted During Sync

**Priority:** High  
**Description:** Test when image is deleted from source during sync.

**Pre-conditions:**
- Image exists on source node

**Test Steps:**
1. Start sync script
2. During execution, delete image from source:
   ```bash
   ssh k8s-worker1 "crictl rmi <image>"
   ```
3. Observe behavior when sync tries to pull

**Expected Result:**
- Pull may fail (image no longer at source)
- Error logged
- Script continues

**Pass Criteria:**
- [ ] Deletion handled
- [ ] Error logged
- [ ] No crash

---

### EDGE-014: Image Added During Sync

**Priority:** Medium  
**Description:** Test when new image appears during sync.

**Pre-conditions:**
- Sync in progress

**Test Steps:**
1. Start sync script
2. During execution, pull new image:
   ```bash
   ssh k8s-worker1 "crictl pull bcm11/newimage:v1"
   ```
3. Observe if new image is detected

**Expected Result:**
- New image NOT detected (already past image listing)
- Will be synced on next run
- No errors

**Pass Criteria:**
- [ ] No errors from timing
- [ ] Consistent behavior

---

### EDGE-015: Simultaneous Pull on Target Node

**Priority:** Medium  
**Description:** Test when someone else pulls same image to target during sync.

**Pre-conditions:**
- Image missing on target

**Test Steps:**
1. Identify missing image
2. Start sync
3. Simultaneously manually pull same image to target
4. Observe behavior

**Expected Result:**
- One pull succeeds, other may be redundant
- No corruption
- No errors (crictl handles this)

**Pass Criteria:**
- [ ] No corruption
- [ ] Clean handling

---

## Category: Network Edge Cases

### EDGE-016: DNS Resolution Delay

**Priority:** Low  
**Description:** Test when DNS resolution is slow.

**Pre-conditions:**
- DNS can be slowed

**Test Steps:**
1. Add DNS delay (via network tools)
2. Run sync
3. Verify timeout handling

**Expected Result:**
- Handles slow DNS
- May timeout if too slow
- No hanging

**Pass Criteria:**
- [ ] Slow DNS handled
- [ ] Timeouts work

---

### EDGE-017: IPv6 Nodes

**Priority:** Low  
**Description:** Test with IPv6 addresses for nodes.

**Pre-conditions:**
- Nodes accessible via IPv6

**Test Steps:**
1. Configure nodes with IPv6:
   ```bash
   NODE1="2001:db8::1"
   ```
2. Run sync
3. Verify IPv6 handling

**Expected Result:**
- IPv6 addresses work
- SSH connects via IPv6
- No issues

**Pass Criteria:**
- [ ] IPv6 supported
- [ ] No address format issues

---

### EDGE-018: Mixed IPv4/IPv6

**Priority:** Low  
**Description:** Test with one node IPv4 and one IPv6.

**Pre-conditions:**
- Mixed addressing

**Test Steps:**
1. Configure:
   ```bash
   NODE1="192.168.1.100"
   NODE2="2001:db8::2"
   ```
2. Run sync
3. Verify both connections work

**Expected Result:**
- Both protocols work
- Sync completes
- No issues

**Pass Criteria:**
- [ ] Mixed protocols work

---

## Category: Log Edge Cases

### EDGE-019: Very Long Log Lines

**Priority:** Low  
**Description:** Test log handling with very long entries.

**Pre-conditions:**
- Long image names generating long log entries

**Test Steps:**
1. Use images with very long names
2. Run multiple syncs
3. Check log file integrity

**Expected Result:**
- Long lines handled
- No truncation in logs
- Logs readable

**Pass Criteria:**
- [ ] Long lines preserved
- [ ] Log format maintained

---

### EDGE-020: Log File at Maximum Size

**Priority:** Low  
**Description:** Test behavior when log file is very large.

**Pre-conditions:**
- Large log file exists

**Test Steps:**
1. Create large log file (1GB+):
   ```bash
   dd if=/dev/zero bs=1M count=1024 >> /var/log/giindia/sync-worker-node-images/image-sync.log
   ```
2. Run sync
3. Check append behavior
4. Clean up

**Expected Result:**
- Append still works (if disk space)
- No issues with large file
- May need log rotation

**Pass Criteria:**
- [ ] Large files handled
- [ ] Append works

---

## Edge Case Test Summary

| Test ID | Description | Priority | Status | Tester | Date |
|---------|-------------|----------|--------|--------|------|
| EDGE-001 | Identical Images | Medium | | | |
| EDGE-002 | Both Nodes Empty | Low | | | |
| EDGE-003 | One Node Empty | Medium | | | |
| EDGE-004 | Single Image Diff | Medium | | | |
| EDGE-005 | No Tag (Latest) | Medium | | | |
| EDGE-006 | SHA256 Digest | Medium | | | |
| EDGE-007 | Long Image Names | Low | | | |
| EDGE-008 | Unicode Characters | Low | | | |
| EDGE-009 | Multiple Tags | Medium | | | |
| EDGE-010 | Prefix = Full Name | Low | | | |
| EDGE-011 | Similar Prefixes | Medium | | | |
| EDGE-012 | Overlapping Prefixes | Low | | | |
| EDGE-013 | Deleted During Sync | High | | | |
| EDGE-014 | Added During Sync | Medium | | | |
| EDGE-015 | Simultaneous Pull | Medium | | | |
| EDGE-016 | DNS Delay | Low | | | |
| EDGE-017 | IPv6 Nodes | Low | | | |
| EDGE-018 | Mixed IPv4/IPv6 | Low | | | |
| EDGE-019 | Long Log Lines | Low | | | |
| EDGE-020 | Large Log File | Low | | | |

