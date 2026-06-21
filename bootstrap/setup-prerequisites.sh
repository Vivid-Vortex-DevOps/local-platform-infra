#!/bin/bash
set -euo pipefail

# Prerequisites setup for WSL2 Ubuntu
# Run this INSIDE WSL2: ./bootstrap/setup-prerequisites.sh

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

enable_systemd() {
    if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
        info "systemd already enabled"
        return
    fi
    warn "systemd is not enabled. Configuring..."
    sudo tee /etc/wsl.conf > /dev/null <<'WSLCONF'
[boot]
systemd=true
WSLCONF
    warn "systemd configured. You must restart WSL2:"
    warn "  From PowerShell: wsl --shutdown"
    warn "  Then reopen Ubuntu"
    warn "Re-run this script after restart."
    exit 0
}

install_docker_engine() {
    if command -v docker &>/dev/null && docker ps &>/dev/null 2>&1; then
        local docker_ver
        docker_ver=$(docker --version 2>/dev/null || echo "unknown")
        info "Docker already installed: $docker_ver"
        # Check if it's Docker Desktop or native
        if docker context ls 2>/dev/null | grep -q "desktop-linux"; then
            warn "Docker Desktop detected. For native Docker Engine:"
            warn "  1. Close Docker Desktop on Windows"
            warn "  2. Uninstall Docker packages: sudo apt remove docker-desktop"
            warn "  3. Re-run this script"
        fi
        return
    fi

    info "Installing Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER"
    info "Docker Engine installed. You may need to log out and back in for group changes."
}

install_kubectl() {
    if command -v kubectl &>/dev/null; then
        info "kubectl already installed: $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 || echo 'installed')"
        return
    fi
    info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    info "kubectl installed"
}

install_helm() {
    if command -v helm &>/dev/null; then
        info "helm already installed: $(helm version --short 2>/dev/null)"
        return
    fi
    info "Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    info "helm installed"
}

install_kind() {
    if command -v kind &>/dev/null; then
        info "kind already installed: $(kind version 2>/dev/null)"
        return
    fi
    info "Installing kind..."
    local KIND_VERSION
    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    info "kind installed: ${KIND_VERSION}"
}

install_argocd_cli() {
    if command -v argocd &>/dev/null; then
        info "argocd CLI already installed: $(argocd version --client --short 2>/dev/null || echo 'installed')"
        return
    fi
    info "Installing argocd CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x argocd-linux-amd64
    sudo mv argocd-linux-amd64 /usr/local/bin/argocd
    info "argocd CLI installed"
}

install_extras() {
    info "Installing jq, yq, make..."
    sudo apt-get install -y jq make curl wget
    if ! command -v yq &>/dev/null; then
        local YQ_VERSION
        YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        curl -Lo ./yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
        chmod +x ./yq
        sudo mv ./yq /usr/local/bin/yq
    fi
    info "Extra tools installed"
}

verify_all() {
    echo ""
    info "=== Verification ==="
    echo ""
    local tools=("docker" "kubectl" "helm" "kind" "argocd" "git" "jq" "yq" "make")
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
        info "All prerequisites installed successfully!"
    else
        error "Some tools are missing. Re-run this script."
    fi
}

main() {
    echo ""
    echo "=========================================="
    echo "  Local Platform Prerequisites Setup"
    echo "=========================================="
    echo ""

    check_wsl2
    enable_systemd
    install_docker_engine
    install_kubectl
    install_helm
    install_kind
    install_argocd_cli
    install_extras
    verify_all
}

main "$@"
