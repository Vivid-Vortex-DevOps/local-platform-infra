# ADR-001: Kind over K3s for Local Kubernetes

**Status:** Accepted  
**Date:** 2026-06-21

## Context

We need a local Kubernetes cluster for development that mirrors cloud-managed K8s (AKS/EKS/GKE).

## Decision

Use Kind (Kubernetes IN Docker) over K3s.

## Rationale

- Kind runs upstream Kubernetes (identical API surface to cloud providers)
- K3s modifies the Kubernetes distribution (replaces etcd with SQLite, bundles Traefik)
- Kind clusters are disposable — `kind delete cluster` and `bootstrap.sh` recreates everything
- Kind works natively with Docker Desktop and native Docker Engine
- Better for learning standard Kubernetes patterns

## Consequences

- Requires Docker to be running (Kind runs K8s nodes as Docker containers)
- Single-node cluster is sufficient for dev; multi-node config available for testing
- LoadBalancer services require MetalLB (installed in bootstrap)
