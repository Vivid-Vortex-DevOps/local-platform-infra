#!/bin/bash
set -euo pipefail

# Prerequisites setup for WSL2 Ubuntu
# Installs tools to ~/bin (no sudo required for tool installation)
# Run this INSIDE WSL2: ./bootstrap/setup-prerequisites.sh

BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_wsl2() {
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        error "This script must run inside WSL2"
        exit 1
    fi
    info "Running inside WSL2"
}

setup_path() {
    if ! grep -q 'HOME/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        info "Added ~/bin to PATH in .bashrc"
    fi
    export PATH="$HOME/bin:$PATH"
}

check_docker() {
    if command -v docker &>/dev/null && docker ps &>/dev/null 2>&1; then
        info "Docker available: $(docker --version 2>/dev/null)"
        return
    fi

    # Check if Docker Desktop provides docker via WSL integration
    if [ -e "/mnt/wsl/docker-desktop/docker" ] || command -v docker &>/dev/null; then
        warn "Docker CLI found but daemon not running."
        warn "Start Docker Desktop on Windows, or install native Docker Engine."
        warn "Continuing — Docker will be needed for Kind cluster creation."
        return
    fi

    warn "Docker not found. Options:"
    warn "  1. Start Docker Desktop on Windows (WSL2 integration must be enabled)"
    warn "  2. Install native Docker Engine: see docs/guides/setup.md"
    warn "Continuing without Docker — it will be needed for Kind cluster."
}

install_kubectl() {
    if [ -x "$BIN_DIR/kubectl" ]; then
        info "kubectl already installed: $($BIN_DIR/kubectl version --client --short 2>/dev/null || echo 'installed')"
        return
    fi
    info "Installing kubectl..."
    local version
    version=$(curl -sL https://dl.k8s.io/release/stable.txt 2>/dev/null || echo "v1.32.2")
    if [ -z "$version" ]; then version="v1.32.2"; fi
    curl -sLo "$BIN_DIR/kubectl" "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"
    chmod +x "$BIN_DIR/kubectl"
    info "kubectl ${version} installed"
}

install_helm() {
    if [ -x "$BIN_DIR/helm" ]; then
        info "helm already installed: $($BIN_DIR/helm version --short 2>/dev/null)"
        return
    fi
    info "Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | HELM_INSTALL_DIR="$BIN_DIR" USE_SUDO=false bash
    info "helm installed"
}

install_kind() {
    if [ -x "$BIN_DIR/kind" ]; then
        info "kind already installed: $($BIN_DIR/kind version 2>/dev/null)"
        return
    fi
    info "Installing kind..."
    local kind_version
    kind_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "v0.27.0")
    if [ -z "$kind_version" ]; then kind_version="v0.27.0"; fi
    curl -sLo "$BIN_DIR/kind" "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-amd64"
    chmod +x "$BIN_DIR/kind"
    info "kind ${kind_version} installed"
}

install_argocd_cli() {
    if [ -x "$BIN_DIR/argocd" ]; then
        info "argocd CLI already installed"
        return
    fi
    info "Installing argocd CLI..."
    curl -sSL -o "$BIN_DIR/argocd" https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x "$BIN_DIR/argocd"
    info "argocd CLI installed"
}

install_kubeseal() {
    if [ -x "$BIN_DIR/kubeseal" ]; then
        info "kubeseal already installed: $($BIN_DIR/kubeseal --version 2>/dev/null)"
        return
    fi
    info "Installing kubeseal..."
    local version="0.29.0"
    curl -sL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${version}/kubeseal-${version}-linux-amd64.tar.gz" \
        -o /tmp/kubeseal.tar.gz
    tar xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal
    mv /tmp/kubeseal "$BIN_DIR/kubeseal"
    chmod +x "$BIN_DIR/kubeseal"
    rm -f /tmp/kubeseal.tar.gz
    info "kubeseal v${version} installed"
}

install_extras() {
    info "Checking extra tools (jq, make, git)..."
    local missing=()
    for tool in jq make git curl; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        info "Installing: ${missing[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${missing[@]}"
    fi
    info "Extra tools ready"
}

verify_all() {
    echo ""
    info "=== Verification ==="
    echo ""
    local tools=("docker" "kubectl" "helm" "kind" "argocd" "kubeseal" "git" "jq" "make")
    local all_ok=true
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${RED}✗${NC} $tool"
            all_ok=false
        fi
    done
    echo ""
    if $all_ok; then
        info "All prerequisites installed!"
        info "Tools location: $BIN_DIR"
    else
        warn "Some tools are missing. Check Docker Desktop or re-run."
    fi
}

main() {
    echo ""
    echo "=========================================="
    echo "  Local Platform Prerequisites Setup"
    echo "=========================================="
    echo ""

    check_wsl2
    setup_path
    check_docker
    install_kubectl
    install_helm
    install_kind
    install_argocd_cli
    install_kubeseal
    install_extras
    verify_all
}

main "$@"
