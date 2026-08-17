# Multi-host readiness recipe

This is the next-step recipe for moving beyond the single-host kind ceiling and establishing stronger distributed evidence.

## Goal

Validate real control/data-plane behavior across multiple hosts, not just a single laptop-run kind cluster.

## Minimum environment

- 2 to 3 commodity Linux hosts with Docker or containerd
- network connectivity between hosts
- shared access to the same image registry or image tarball distribution
- a Kubernetes distro such as k3d, kubeadm, or managed control plane

## Suggested topology

- 1 control-plane node
- 2 to 3 worker nodes
- 1 or more orchestrator replicas
- 1 IPFS/metadata service
- 20, 100, 300, 500 worker replicas depending on host capacity

## Production-like changes

- do not run the entire fleet in one node
- use separate hosts for control-plane and workload nodes
- keep the `node-agent` replica count bounded by per-host resource headroom
- keep the cert pool on a shared volume or per-node secret distribution path
- record pod readiness, etcd/controller-plane health, and request latency together

## Basic workflow

1. Build the repository images locally or in CI.
2. Push or distribute them to all hosts.
3. Create a multi-node Kubernetes cluster.
4. Deploy the orchestrator and metadata service.
5. Deploy the node-agent StatefulSet with a pool of certs.
6. Scale in stages: 20 -> 100 -> 300 -> 500.
7. Capture logs, pod state, and latency deltas at each stage.

## Evidence to collect

- pod readiness by stage
- mean and p95 submit latency
- control-plane stability
- mTLS validation and auth check results
- any failure or restart events

## Why this matters

A single kind cluster on one laptop creates a disk I/O ceiling that is unrelated to the application logic. Multi-host deployment evidence would prove the control/data planes work across host boundaries, which is the missing evidence the repo currently calls out as a gap.
