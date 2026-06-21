#!/bin/bash
set -euo pipefail

# Self-hosted GitHub Actions Runner setup for WSL2
# Reference: https://github.com/Vivid-Vortex/Misc/blob/dev_m1_1.0.0/Concepts/DevOps/CICD/RunGithubActionRunnerLocally.md

RUNNER_DIR="$HOME/actions-runner"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [ -d "$RUNNER_DIR" ] && [ -f "$RUNNER_DIR/run.sh" ]; then
    info "Runner already installed at $RUNNER_DIR"
    echo ""
    echo "To reconfigure: cd $RUNNER_DIR && ./config.sh remove && ./config.sh --url <REPO_URL> --token <TOKEN>"
    echo "To start:       cd $RUNNER_DIR && ./run.sh"
    echo "To install as service: cd $RUNNER_DIR && sudo ./svc.sh install && sudo ./svc.sh start"
    exit 0
fi

info "Setting up GitHub Actions self-hosted runner..."
echo ""

# Get latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
info "Latest runner version: ${RUNNER_VERSION}"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

info "Downloading runner..."
curl -o actions-runner-linux-x64.tar.gz -L \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

info "Extracting..."
tar xzf actions-runner-linux-x64.tar.gz
rm actions-runner-linux-x64.tar.gz

echo ""
warn "Runner downloaded. Now configure it:"
echo ""
echo "  1. Go to your GitHub org/repo → Settings → Actions → Runners → New self-hosted runner"
echo "  2. Copy the token"
echo "  3. Run:"
echo ""
echo "     cd $RUNNER_DIR"
echo "     ./config.sh --url https://github.com/Vivid-Vortex-DevOps --token <YOUR_TOKEN> --labels self-hosted,linux,wsl2,local"
echo ""
echo "  4. Start the runner:"
echo ""
echo "     ./run.sh"
echo ""
echo "  5. (Optional) Install as systemd service:"
echo ""
echo "     sudo ./svc.sh install"
echo "     sudo ./svc.sh start"
echo ""
