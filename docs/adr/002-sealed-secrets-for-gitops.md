# ADR-002: Sealed Secrets for GitOps-Safe Secret Management

**Status:** Accepted  
**Date:** 2026-06-22

## Context

ArgoCD syncs from Git, but Kubernetes Secrets cannot be stored in Git (base64 is not encryption). We need a way to store encrypted secrets in Git that only the cluster can decrypt.

## Decision

Use Bitnami Sealed Secrets with kubeseal CLI.

## Rationale

- SealedSecret CRDs can be safely committed to Git
- Only the Sealed Secrets controller (with its private key) can decrypt them
- kubeseal encrypts using the controller's public certificate
- Simpler than Vault or external secret managers for local development
- Native Kubernetes integration — SealedSecrets create standard K8s Secrets

## Consequences

- Sealed Secrets are cluster-specific (tied to the controller's key pair)
- If the cluster is destroyed and recreated, new SealedSecrets must be generated
- The controller's private key should be backed up for production use
