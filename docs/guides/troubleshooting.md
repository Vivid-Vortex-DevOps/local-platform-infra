# Troubleshooting Guide

## Docker / WSL2

**Docker daemon not running**
```bash
# Ensure Docker Desktop is started (Windows)
# Or for native Docker Engine: sudo systemctl start docker
docker ps
```

**kubectl broken symlink**
```bash
# Docker Desktop creates /usr/local/bin/kubectl → Docker Desktop path
# Use standalone kubectl in ~/bin instead
export PATH=$HOME/bin:$PATH
kubectl version --client
```

## Kind Cluster

**Cluster not reachable**
```bash
kind get clusters              # Check cluster exists
kubectl cluster-info --context kind-vvd-local
docker ps | grep vvd-local     # Check Kind container is running
```

**Pods stuck in Pending/CrashLoopBackOff after Docker restart**
```bash
# Pods usually recover within 2-3 minutes after Docker restarts
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

**Image not found (ErrImagePull)**
```bash
# Images must be loaded into Kind after every rebuild
docker build -t my-service:latest .
kind load docker-image my-service:latest --name vvd-local
```

## ArgoCD

**Application stuck OutOfSync**
```bash
# Force refresh
kubectl annotate application <app-name> argocd.argoproj.io/refresh=hard -n argocd --overwrite
```

**Deployment selector immutable error**
```bash
# Delete the existing Helm release, let ArgoCD recreate
helm uninstall <release> -n applications-dev --kube-context kind-vvd-local
# ArgoCD auto-sync will recreate resources
```

**ArgoCD admin password**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## Grafana

**CrashLoopBackOff: "Only one datasource per organization can be marked as default"**
```bash
# Check for duplicate isDefault datasource configmaps
kubectl get configmap -n monitoring -l grafana_datasource=1 -o yaml | grep isDefault
# Fix: ensure only Prometheus has isDefault: true
```

## Sealed Secrets

**"Resource already exists and is not managed by SealedSecret"**
```bash
# Delete the plain secret, then re-apply the SealedSecret
kubectl delete secret <name> -n <namespace>
kubectl delete sealedsecret <name> -n <namespace>
kubectl apply -f <sealed-secret.yaml>
```

**Regenerate SealedSecrets after cluster recreation**
```bash
# SealedSecrets are tied to the controller's key pair
# After bootstrap.sh, recreate all SealedSecrets with kubeseal
kubectl create secret generic <name> --from-literal=key=value --dry-run=client -o yaml | \
  kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets -o yaml > sealed.yaml
```
