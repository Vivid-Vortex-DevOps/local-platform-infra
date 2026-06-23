#!/bin/bash
set -euo pipefail
export PATH="$HOME/bin:$PATH"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo "=========================================="
echo "  Platform Health Check"
echo "=========================================="
echo ""

echo "Cluster:"
kubectl cluster-info --context kind-vvd-local &>/dev/null && ok "Kind cluster reachable" || fail "Kind cluster not reachable"
echo ""

echo "Nodes:"
kubectl get nodes --no-headers 2>/dev/null | while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $2}')
    if [ "$status" = "Ready" ]; then ok "$name ($status)"; else fail "$name ($status)"; fi
done
echo ""

echo "Namespaces:"
for ns in argocd istio-system monitoring applications-dev metallb-system ingress-nginx sealed-secrets; do
    kubectl get ns "$ns" &>/dev/null && ok "$ns" || fail "$ns"
done
echo ""

echo "Platform Components:"
declare -A components=(
    ["argocd"]="argocd-server"
    ["monitoring"]="prometheus"
    ["monitoring"]="grafana"
    ["istio-system"]="istiod"
    ["istio-system"]="kiali"
    ["applications-dev"]="postgresql"
)

for ns in argocd monitoring istio-system applications-dev ingress-nginx sealed-secrets; do
    pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
    ready=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$pods" -gt 0 ]; then
        ok "$ns: $ready/$pods pods running"
    else
        fail "$ns: no pods"
    fi
done
echo ""

echo "Done."
