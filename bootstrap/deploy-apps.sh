#!/bin/bash
set -euo pipefail
export PATH="$HOME/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE="$(dirname "$REPO_DIR")"
CLUSTER_NAME="vvd-local"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_cluster() {
    kubectl cluster-info --context "kind-${CLUSTER_NAME}" &>/dev/null \
        || error "Kind cluster '${CLUSTER_NAME}' not reachable. Run bootstrap.sh first."
    info "Cluster reachable"
}

clone_or_pull() {
    local repo_name="$1"
    local branch="${2:-main}"
    local repo_url="https://github.com/Vivid-Vortex-DevOps/${repo_name}.git"
    local repo_path="${WORKSPACE}/${repo_name}"

    if [ -d "$repo_path/.git" ]; then
        info "${repo_name}: pulling latest (${branch})"
        git -C "$repo_path" checkout "$branch" 2>/dev/null || true
        git -C "$repo_path" pull origin "$branch" 2>/dev/null || warn "Pull failed — using local copy"
    else
        info "${repo_name}: cloning (${branch})"
        git clone -b "$branch" "$repo_url" "$repo_path"
    fi
}

build_and_load() {
    local service="$1"
    local service_path="${WORKSPACE}/${service}"

    if [ ! -f "$service_path/Dockerfile" ]; then
        error "Dockerfile not found at $service_path/Dockerfile"
    fi

    info "Building ${service}..."
    docker build -t "${service}:latest" "$service_path"

    info "Loading ${service} into Kind..."
    kind load docker-image "${service}:latest" --name "$CLUSTER_NAME"
}

wait_for_apps() {
    info "Waiting for ArgoCD to deploy applications..."
    local max_wait=180
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        local go_health
        go_health=$(kubectl get application go-crud-service-dev -n argocd --context "kind-${CLUSTER_NAME}" -o jsonpath="{.status.health.status}" 2>/dev/null || echo "Unknown")
        local spring_health
        spring_health=$(kubectl get application springboot-crud-service-dev -n argocd --context "kind-${CLUSTER_NAME}" -o jsonpath="{.status.health.status}" 2>/dev/null || echo "Unknown")

        if [ "$go_health" = "Healthy" ] && [ "$spring_health" = "Healthy" ]; then
            info "Both applications are Healthy!"
            return
        fi
        echo -ne "\r  Go: ${go_health}, Spring: ${spring_health} (${elapsed}s)..."
        sleep 10
        elapsed=$((elapsed + 10))
    done
    echo ""
    warn "Applications did not become healthy within ${max_wait}s — check ArgoCD"
}

print_status() {
    echo ""
    echo "=========================================="
    echo "  Applications Deployed!"
    echo "=========================================="
    echo ""
    kubectl get applications -n argocd --context "kind-${CLUSTER_NAME}" 2>/dev/null
    echo ""
    kubectl get pods -n applications-dev --context "kind-${CLUSTER_NAME}" 2>/dev/null
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "  Deploy Applications"
    echo "=========================================="
    echo ""
    echo "  Builds images and loads into Kind."
    echo "  ArgoCD manages the actual deployment."
    echo ""

    check_cluster

    clone_or_pull "go-crud-service" "local_main"
    clone_or_pull "springboot-crud-service" "local_main"

    build_and_load "go-crud-service"
    build_and_load "springboot-crud-service"

    wait_for_apps
    print_status
}

main "$@"
