# Image Sync - User Guide

## What is Image Sync?

Image Sync is an automated background service that keeps container images synchronized across the Kubernetes worker nodes in your cluster. It runs periodically without any user intervention.

---

## Why Was This Introduced?

In a multi-node Kubernetes cluster, container images may exist on one worker node but not on another. This can cause:

- **Delayed pod startup** – Pods scheduled on a node without the required image must wait for the image to be pulled
- **Scheduling inefficiencies** – Kubernetes may schedule workloads on nodes that don't have the image cached, leading to longer startup times
- **Inconsistent experience** – Same workload may start quickly on one node but slowly on another

**Image Sync solves this** by ensuring all worker nodes have the same set of images, so your pods start quickly regardless of which node they're scheduled on.

---

## Which Images Are Synced?

The following container images are automatically synchronized between worker nodes:

| Image Source | Description |
|--------------|-------------|
| **Harbor Registry** | Internal images hosted on the headnode Harbor registry |
| **NVIDIA NGC** | GPU-optimized images from NVIDIA NGC catalog (images starting with `nvcr.io/nvidia`) |

> **Note:** Only images matching these prefixes are synced. External images from Docker Hub or other registries are not included.

---

## How Does This Benefit You?

✅ **Faster pod startup** – Images are pre-cached on all nodes  
✅ **Consistent performance** – No surprise delays when pods land on different nodes  
✅ **Seamless experience** – Works automatically in the background  
✅ **Resource efficiency** – Avoids redundant pulls during peak hours  

---

## Sync Schedule

The synchronization runs automatically at regular intervals (typically every 30 minutes). No action is required from users.

---

## Questions?

For any questions or issues related to image availability on the cluster, please contact your system administrator.

