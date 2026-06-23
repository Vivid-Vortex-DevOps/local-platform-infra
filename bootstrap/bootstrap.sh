#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="vvd-local"
CLUSTER_CONFIG="$REPO_DIR/cluster/kind-single-node.yaml"
export PATH="$HOME/bin:$PATH"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_prerequisites() {
    info "Checking prerequisites..."
    local tools=("docker" "kubectl" "helm" "kind")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            error "$tool is not installed. Run: ./bootstrap/setup-prerequisites.sh"
        fi
    done
    if ! docker ps &>/dev/null 2>&1; then
        error "Docker is not running. Start Docker first."
    fi
    info "All prerequisites met"
}

create_cluster() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
        kubectl cluster-info --context "kind-${CLUSTER_NAME}" &>/dev/null || error "Cluster exists but is not reachable"
        return
    fi
    info "Creating Kind cluster: ${CLUSTER_NAME}..."
    kind create cluster --config "$CLUSTER_CONFIG" --wait 120s
    info "Cluster created"
}

install_metallb() {
    if kubectl get namespace metallb-system --context "kind-${CLUSTER_NAME}" &>/dev/null 2>&1; then
        if kubectl get pods -n metallb-system --context "kind-${CLUSTER_NAME}" --no-headers 2>/dev/null | grep -q Running; then
            info "MetalLB already installed and running"
            return
        fi
    fi
    info "Installing MetalLB..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --context "kind-${CLUSTER_NAME}"
    info "Waiting for MetalLB pods..."
    kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=120s --context "kind-${CLUSTER_NAME}" 2>/dev/null || true
    sleep 5

    local KIND_NET_CIDR
    KIND_NET_CIDR=$(docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | tr ' ' '\n' | grep -v ':' | head -1)
    local BASE_IP
    BASE_IP=$(echo "$KIND_NET_CIDR" | sed 's|\.0/.*||')

    kubectl apply --context "kind-${CLUSTER_NAME}" -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - ${BASE_IP}.200-${BASE_IP}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
    info "MetalLB installed (pool: ${BASE_IP}.200-250)"
}

install_argocd() {
    info "Installing ArgoCD..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update argo
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd --create-namespace \
        --values "$REPO_DIR/helm/argocd/values.yaml" \
        --kube-context "kind-${CLUSTER_NAME}" \
        --wait --timeout 300s
    info "ArgoCD installed"
}

apply_projects() {
    info "Applying ArgoCD projects..."
    kubectl apply -f "$REPO_DIR/argocd/projects/" --context "kind-${CLUSTER_NAME}"
    info "Projects applied (platform, applications)"
}

apply_root_app() {
    info "Applying root App of Apps..."
    kubectl apply -f "$REPO_DIR/argocd/root.yaml" --context "kind-${CLUSTER_NAME}"
    info "Root application applied — ArgoCD will now manage all platform components"
}

wait_for_platform() {
    info "Waiting for ArgoCD to sync all applications..."
    local max_wait=600
    local elapsed=0
    local check_interval=15

    while [ $elapsed -lt $max_wait ]; do
        local total
        total=$(kubectl get applications -n argocd --context "kind-${CLUSTER_NAME}" --no-headers 2>/dev/null | wc -l)
        local synced
        synced=$(kubectl get applications -n argocd --context "kind-${CLUSTER_NAME}" --no-headers 2>/dev/null | grep -c "Synced" || true)
        local healthy
        healthy=$(kubectl get applications -n argocd --context "kind-${CLUSTER_NAME}" --no-headers 2>/dev/null | grep -c "Healthy" || true)

        echo -ne "\r  Apps: ${total} total, ${synced} synced, ${healthy} healthy (${elapsed}s)..."

        if [ "$total" -gt 5 ] && [ "$synced" -eq "$total" ] && [ "$healthy" -eq "$total" ]; then
            echo ""
            info "All ${total} applications are Synced and Healthy!"
            return
        fi

        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))
    done
    echo ""
    warn "Not all applications healthy within ${max_wait}s — check ArgoCD dashboard"
}

print_access_info() {
    echo ""
    echo "=========================================="
    echo "  Platform Ready!"
    echo "=========================================="
    echo ""
    echo "ArgoCD manages all platform components via App of Apps pattern."
    echo ""
    kubectl get applications -n argocd --context "kind-${CLUSTER_NAME}" 2>/dev/null
    echo ""
    echo "Access services via Ingress (add to /etc/hosts or C:\\Windows\\System32\\drivers\\etc\\hosts):"
    echo ""
    echo "  127.0.0.1 argocd.local grafana.local prometheus.local jaeger.local kiali.local"
    echo ""
    echo "  ArgoCD:      http://argocd.local      (admin / <see below>)"
    echo "  Grafana:     http://grafana.local      (admin / prom-operator)"
    echo "  Prometheus:  http://prometheus.local"
    echo "  Jaeger:      http://jaeger.local"
    echo "  Kiali:       http://kiali.local"
    echo ""
    info "ArgoCD admin password:"
    kubectl -n argocd get secret argocd-initial-admin-secret --context "kind-${CLUSTER_NAME}" -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || warn "Password not yet available"
    echo ""
    echo "Fallback: ./bootstrap/port-forward.sh (if hosts file not configured)"
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "  Local Platform Bootstrap"
    echo "  Cluster: ${CLUSTER_NAME}"
    echo "=========================================="
    echo ""
    echo "  Strategy: ArgoCD App of Apps"
    echo "  Bootstrap installs: Kind cluster + MetalLB + ArgoCD"
    echo "  ArgoCD manages: Everything else (12+ components)"
    echo ""

    check_prerequisites
    create_cluster
    install_metallb
    install_argocd
    apply_projects
    apply_root_app
    wait_for_platform
    print_access_info
}

main "$@"
