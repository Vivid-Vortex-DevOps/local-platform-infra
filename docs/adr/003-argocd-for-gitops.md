# ADR-003: ArgoCD for GitOps Continuous Delivery

**Status:** Accepted  
**Date:** 2026-06-22

## Context

We need a deployment mechanism that treats Git as the single source of truth for cluster state.

## Decision

Use ArgoCD with automated sync, prune, and self-heal enabled.

## Rationale

- ArgoCD watches Git repos and automatically applies changes to the cluster
- Declarative — desired state is in Git, ArgoCD reconciles actual state
- Drift detection — ArgoCD reports when cluster state diverges from Git
- Self-heal reverses manual changes made outside Git
- UI for visualizing application state and sync status
- Industry standard for Kubernetes GitOps

## Consequences

- All deployment changes must go through Git (no `kubectl apply` for app resources)
- Helm releases are managed by ArgoCD, not `helm install` directly
- ArgoCD needs read access to application Git repositories
