# local-platform-infra

Local platform infrastructure for the GitOps Pipeline POC.

Replaces cloud-platform-infra for local development using WSL2 + Kind + ArgoCD.

## Purpose

Manage all local platform components:

* Kind cluster configuration
* Bootstrap scripts
* Helm value files (ArgoCD, Istio, Prometheus, Grafana, Loki, Jaeger, JFrog, PostgreSQL)
* ArgoCD application definitions
* Namespace definitions
* Self-hosted runner setup

## Quick Start

```bash
./bootstrap/bootstrap.sh
```

## Destroy

```bash
./bootstrap/destroy.sh
```

See [CLAUDE_LOCAL.md](https://github.com/Vivid-Vortex-DevOps/GitOpsLocalPipelinePoc) for the full design document.
