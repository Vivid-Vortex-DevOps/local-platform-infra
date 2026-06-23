# Infrastructure Patterns Q&A

## Q: How do mature companies manage platform infrastructure instead of manual helm install?

**A:** Mature companies use the **ArgoCD App of Apps** pattern:

### The Problem
Running `helm install` manually is imperative — there's no record of what was installed, no drift detection, and no easy way to recreate the environment. This is fine for a quick start but breaks down in production.

### The Enterprise Pattern

**1. Minimal Bootstrap (imperative — chicken-and-egg)**
Only the bare minimum is installed manually:
- Kubernetes cluster creation (EKS/GKE/Kind)
- Networking prerequisites (MetalLB/CNI)
- ArgoCD itself (the GitOps controller)

**2. ArgoCD Manages Everything Else (declarative)**
Every platform component gets an ArgoCD `Application` CRD:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts  # chart from upstream
      chart: kube-prometheus-stack
      helm:
        valueFiles:
          - $values/helm/prometheus/values.yaml   # values from YOUR repo
    - repoURL: https://github.com/your-org/infra.git
      ref: values                                  # git ref for values
  destination:
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**3. Root App of Apps**
A single "root" Application points to a directory of Application CRDs. ArgoCD reads that directory and creates all child Applications:
```
argocd/
  root.yaml          # Only thing manually applied after bootstrap
  apps/              # All child Application CRDs
    sealed-secrets.yaml
    postgresql.yaml
    kube-prometheus-stack.yaml
    loki.yaml
    jaeger.yaml
    ...
```

### Sync Waves
Components are ordered using `argocd.argoproj.io/sync-wave` annotations:
- **Wave 0**: Core infra (sealed-secrets, ingress controller)
- **Wave 1**: Databases (PostgreSQL)
- **Wave 2**: Observability (Prometheus, Loki, Jaeger)
- **Wave 3**: Service mesh (Istio, Kiali)
- **Wave 4**: Platform config (ingress routes, network policies, secrets)
- **Wave 5**: Application services

### Multi-Source Applications
The gold standard for Helm-based components: chart from the upstream Helm repo + values from your Git repo. This means:
- Chart version pinning is declarative
- Values changes go through Git PR review
- ArgoCD auto-syncs when either the chart version or values change

### Benefits
- **Drift detection**: ArgoCD shows when actual state diverges from Git
- **Self-healing**: If someone manually changes something, ArgoCD reverts it
- **Visibility**: Every component visible in the ArgoCD dashboard
- **Reproducibility**: Destroy and recreate the entire platform from Git
- **Auditability**: Every change to infrastructure goes through Git history

### Our Implementation
```
local-platform-infra/
  argocd/
    root.yaml                            # Root app-of-apps
    apps/                                # 13 ArgoCD Application CRDs
      sealed-secrets.yaml    (wave 0)
      nginx-ingress.yaml     (wave 0)
      postgresql.yaml        (wave 1)
      kube-prometheus-stack.yaml (wave 2)
      loki.yaml              (wave 2)
      jaeger.yaml            (wave 2)
      istio-base.yaml        (wave 3)
      istiod.yaml            (wave 3)
      kiali.yaml             (wave 3)
      platform-ingress.yaml  (wave 4)
      app-resources-dev.yaml (wave 4)
      go-crud-service-dev.yaml    (wave 5)
      springboot-crud-service-dev.yaml (wave 5)
    projects/
      platform.yaml          # ArgoCD project for infra
      applications.yaml      # ArgoCD project for app workloads
    resources/dev/           # Raw K8s resources (sealed secrets, network policies)
  bootstrap/
    bootstrap.sh             # Only: cluster + MetalLB + ArgoCD + root app
  helm/                      # Values files for each component
```

## Q: How do companies keep services like ArgoCD always accessible without port-forwarding?

**A:** They use **Ingress** resources — a reverse proxy (NGINX, Traefik, or cloud ALB) routes traffic by hostname.

In production:
- DNS records point `argocd.company.com` → load balancer IP
- Ingress controller terminates TLS and routes to the ArgoCD service
- No one ever runs `kubectl port-forward` in production

In our local setup:
- NGINX Ingress Controller handles routing
- Windows hosts file maps `argocd.local` → `127.0.0.1`
- Kind maps host ports 80/443 to the ingress controller

Access: `http://argocd.local`, `http://grafana.local`, etc.
