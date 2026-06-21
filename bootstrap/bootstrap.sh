#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="vvd-local"
CLUSTER_CONFIG="$REPO_DIR/cluster/kind-single-node.yaml"

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

apply_namespaces() {
    info "Creating namespaces..."
    kubectl apply -f "$REPO_DIR/namespaces/all.yaml"
    info "Namespaces created"
}

install_metallb() {
    info "Installing MetalLB..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
    info "Waiting for MetalLB pods..."
    kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=120s 2>/dev/null || true

    # Get Kind docker network subnet for MetalLB address pool
    local KIND_NET_CIDR
    KIND_NET_CIDR=$(docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}')
    local BASE_IP
    BASE_IP=$(echo "$KIND_NET_CIDR" | sed 's|\.0/.*||')

    kubectl apply -f - <<EOF
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
    info "MetalLB installed"
}

install_nginx_ingress() {
    info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    info "Waiting for Ingress Controller..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s 2>/dev/null || true
    info "NGINX Ingress Controller installed"
}

install_sealed_secrets() {
    info "Installing Sealed Secrets..."
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
    helm repo update
    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace sealed-secrets \
        --wait --timeout 120s
    info "Sealed Secrets installed"
}

install_argocd() {
    info "Installing ArgoCD..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --values "$REPO_DIR/helm/argocd/values.yaml" \
        --wait --timeout 300s
    info "ArgoCD installed"
    info "ArgoCD initial admin password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || warn "Password not yet available"
}

install_postgresql() {
    info "Installing PostgreSQL..."
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo update
    helm upgrade --install postgresql bitnami/postgresql \
        --namespace applications-dev \
        --values "$REPO_DIR/helm/postgresql/values.yaml" \
        --wait --timeout 180s
    info "PostgreSQL installed"
}

install_prometheus_stack() {
    info "Installing Prometheus + Grafana (kube-prometheus-stack)..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$REPO_DIR/helm/prometheus/values.yaml" \
        --wait --timeout 300s
    info "Prometheus + Grafana installed"
}

install_loki() {
    info "Installing Loki..."
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo update
    helm upgrade --install loki grafana/loki-stack \
        --namespace monitoring \
        --values "$REPO_DIR/helm/loki/values.yaml" \
        --wait --timeout 180s
    info "Loki installed"
}

install_jaeger() {
    info "Installing Jaeger..."
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
    helm repo update
    helm upgrade --install jaeger jaegertracing/jaeger \
        --namespace monitoring \
        --values "$REPO_DIR/helm/jaeger/values.yaml" \
        --wait --timeout 180s
    info "Jaeger installed"
}

install_istio() {
    info "Installing Istio..."
    helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
    helm repo update
    helm upgrade --install istio-base istio/base \
        --namespace istio-system \
        --wait --timeout 120s
    helm upgrade --install istiod istio/istiod \
        --namespace istio-system \
        --values "$REPO_DIR/helm/istio/values.yaml" \
        --wait --timeout 300s
    info "Istio installed"
}

install_kiali() {
    info "Installing Kiali..."
    helm repo add kiali https://kiali.org/helm-charts 2>/dev/null || true
    helm repo update
    helm upgrade --install kiali kiali/kiali-server \
        --namespace istio-system \
        --values "$REPO_DIR/helm/kiali/values.yaml" \
        --wait --timeout 180s
    info "Kiali installed"
}

print_access_info() {
    echo ""
    echo "=========================================="
    echo "  Platform Ready!"
    echo "=========================================="
    echo ""
    echo "Access services via port-forward:"
    echo ""
    echo "  ArgoCD:      kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "               https://localhost:8080"
    echo ""
    echo "  Grafana:     kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
    echo "               http://localhost:3000  (admin/prom-operator)"
    echo ""
    echo "  Prometheus:  kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
    echo "               http://localhost:9090"
    echo ""
    echo "  Jaeger:      kubectl port-forward svc/jaeger-query -n monitoring 16686:16686"
    echo "               http://localhost:16686"
    echo ""
    echo "  Kiali:       kubectl port-forward svc/kiali -n istio-system 20001:20001"
    echo "               http://localhost:20001"
    echo ""
    echo "Or run: ./bootstrap/port-forward.sh"
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "  Local Platform Bootstrap"
    echo "  Cluster: ${CLUSTER_NAME}"
    echo "=========================================="
    echo ""

    check_prerequisites
    create_cluster
    apply_namespaces
    install_metallb
    install_nginx_ingress
    install_sealed_secrets
    install_argocd
    install_postgresql
    install_prometheus_stack
    install_loki
    install_jaeger
    install_istio
    install_kiali
    print_access_info
}

main "$@"
