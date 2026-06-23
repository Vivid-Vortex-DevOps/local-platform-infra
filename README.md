# local-platform-infra

Enterprise-grade local Kubernetes platform managed via ArgoCD App of Apps pattern.

Replaces cloud-platform-infra for local development using WSL2 + Kind + ArgoCD.

## Architecture

```
Bootstrap (imperative)          ArgoCD App of Apps (declarative)
┌─────────────────────┐        ┌─────────────────────────────────┐
│ Kind cluster        │        │ root Application                │
│ MetalLB             │───────>│   ├── sealed-secrets            │
│ ArgoCD              │        │   ├── nginx-ingress             │
│ Root app-of-apps    │        │   ├── postgresql                │
└─────────────────────┘        │   ├── kube-prometheus-stack     │
                               │   ├── loki                      │
                               │   ├── jaeger                    │
                               │   ├── istio-base + istiod       │
                               │   ├── kiali                     │
                               │   ├── platform-ingress          │
                               │   ├── app-resources-dev         │
                               │   ├── go-crud-service-dev       │
                               │   └── springboot-crud-service   │
                               └─────────────────────────────────┘
```

## Quick Start (New Machine)

Prerequisites: Windows 11 + WSL2 (Ubuntu) + Docker Desktop

```bash
# 1. Install CLI tools
make prerequisites

# 2. Full setup: cluster + platform + apps
make all

# 3. Verify everything is healthy
make verify

# 4. Access services (add hosts file entries first — see below)
```

## Hosts File Setup

Add to `C:\Windows\System32\drivers\etc\hosts` (admin required):

```
127.0.0.1 argocd.local grafana.local prometheus.local jaeger.local kiali.local
```

## Service Access

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | http://argocd.local | admin / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Grafana | http://grafana.local | admin / prom-operator |
| Prometheus | http://prometheus.local | — |
| Jaeger | http://jaeger.local | — |
| Kiali | http://kiali.local | — |

Fallback (if hosts file not configured): `make port-forward`

## Make Targets

```
make all            Full setup from scratch (prereqs + platform + apps)
make prerequisites  Install CLI tools in ~/bin
make platform       Create Kind cluster + install platform via ArgoCD
make deploy-apps    Build images, load into Kind
make destroy        Delete the Kind cluster
make clean          Destroy and rebuild everything
make verify         Health check all components
make port-forward   Start port-forwards for UI access
make status         Quick cluster and app status
make runner         Download self-hosted runner binary
make help           Show this help
```

## Repository Structure

```
├── argocd/
│   ├── root.yaml              # Root app-of-apps (entry point)
│   ├── apps/                  # ArgoCD Application CRDs (13 apps)
│   ├── projects/              # ArgoCD AppProjects
│   └── resources/dev/         # Raw K8s resources (secrets, network policies)
├── bootstrap/
│   ├── bootstrap.sh           # Cluster + MetalLB + ArgoCD + root app
│   ├── deploy-apps.sh         # Build images + load into Kind
│   ├── setup-prerequisites.sh # Install CLI tools
│   ├── destroy.sh             # Tear down cluster
│   ├── verify.sh              # Health check
│   └── port-forward.sh        # Port-forward fallback
├── cluster/                   # Kind cluster configs
├── helm/                      # Helm values for each component
├── namespaces/                # Namespace definitions
├── runner/                    # GitHub Actions self-hosted runner
└── docs/                      # Documentation
    ├── adr/                   # Architecture Decision Records
    ├── guides/                # Setup and troubleshooting guides
    └── qa/                    # Q&A documentation
```

## Documentation

- [ADR-001: Kind over K3s](docs/adr/001-kind-over-k3s.md)
- [ADR-002: Sealed Secrets for GitOps](docs/adr/002-sealed-secrets-for-gitops.md)
- [ADR-003: ArgoCD for GitOps](docs/adr/003-argocd-for-gitops.md)
- [Setup Guide](docs/guides/setup.md)
- [Troubleshooting Guide](docs/guides/troubleshooting.md)
- [Infrastructure Patterns Q&A](docs/qa/infrastructure-patterns.md)

## Design Document

See [CLAUDE_LOCAL.md](https://github.com/Vivid-Vortex-DevOps/GitOpsLocalPipelinePoc) for the full design document.
