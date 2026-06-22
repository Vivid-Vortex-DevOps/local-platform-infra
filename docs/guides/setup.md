# Platform Setup Guide

## Prerequisites

| Tool | Version | Location |
|------|---------|----------|
| WSL2 (Ubuntu) | 20.04+ | Windows feature |
| Docker Desktop | Latest | C:\Program Files\Docker |
| kind | v0.27.0 | ~/bin |
| kubectl | v1.32.2 | ~/bin |
| helm | v3.21.1 | ~/bin |
| argocd CLI | v3.4.4 | ~/bin |
| kubeseal | v0.29.0 | ~/bin |

## Quick Start

```bash
# 1. Start Docker Desktop (Windows)

# 2. Bootstrap the platform (WSL2)
cd ~/code/local-platform-infra
./bootstrap/bootstrap.sh

# 3. Verify
./bootstrap/verify.sh

# 4. Access services
./bootstrap/port-forward.sh
```

## .wslconfig

Create `C:\Users\<username>\.wslconfig`:
```ini
[wsl2]
memory=16GB
processors=4
swap=4GB
```

## Service Access

| Service | Command | URL |
|---------|---------|-----|
| ArgoCD | `kubectl port-forward svc/argocd-server -n argocd 8080:443` | https://localhost:8080 |
| Grafana | `kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80` | http://localhost:3000 (admin/prom-operator) |
| Prometheus | `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090` | http://localhost:9090 |
| Jaeger | `kubectl port-forward svc/jaeger -n monitoring 16686:16686` | http://localhost:16686 |
| Kiali | `kubectl port-forward svc/kiali -n istio-system 20001:20001` | http://localhost:20001 |

## Self-Hosted Runner

```bash
cd ~/actions-runner
./config.sh --url https://github.com/Vivid-Vortex-DevOps --token <TOKEN> --labels self-hosted,linux,wsl2,local
./run.sh
```

## Destruction and Recovery

```bash
# Destroy
./bootstrap/destroy.sh

# Recreate
./bootstrap/bootstrap.sh
```
