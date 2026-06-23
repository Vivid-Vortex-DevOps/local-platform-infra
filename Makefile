.PHONY: prerequisites platform apps deploy-apps destroy verify port-forward status all clean runner

# Full setup: prerequisites → platform → apps
all: prerequisites platform deploy-apps
	@echo ""
	@echo "Platform fully deployed! Run 'make verify' to check health."

# Install CLI tools (kubectl, helm, kind, argocd, kubeseal)
prerequisites:
	./bootstrap/setup-prerequisites.sh

# Create Kind cluster and install all platform components
platform:
	./bootstrap/bootstrap.sh

# Build app images, load into Kind, create secrets, apply ArgoCD apps
deploy-apps:
	./bootstrap/deploy-apps.sh

# Alias for deploy-apps
apps: deploy-apps

# Destroy the Kind cluster (all data lost)
destroy:
	./bootstrap/destroy.sh

# Health check all components
verify:
	./bootstrap/verify.sh

# Start port-forwards for UI access
port-forward:
	./bootstrap/port-forward.sh

# Quick status overview
status:
	@export PATH="$$HOME/bin:$$PATH"; \
	kubectl get nodes --context kind-vvd-local 2>/dev/null || echo "Cluster not running"; \
	echo ""; \
	kubectl get applications -n argocd --context kind-vvd-local 2>/dev/null || true; \
	echo ""; \
	kubectl get pods -n applications-dev --context kind-vvd-local 2>/dev/null || true

# Download and extract GitHub Actions runner (interactive config required after)
runner:
	./runner/setup-runner.sh

# Full rebuild: destroy → platform → apps
clean: destroy platform deploy-apps

# Help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  all            Full setup from scratch (prereqs + platform + apps)"
	@echo "  prerequisites  Install CLI tools in ~/bin"
	@echo "  platform       Create Kind cluster + install platform components"
	@echo "  deploy-apps    Build images, load into Kind, deploy via ArgoCD"
	@echo "  destroy        Delete the Kind cluster"
	@echo "  clean          Destroy and rebuild everything"
	@echo "  verify         Health check all components"
	@echo "  port-forward   Start port-forwards for UI access"
	@echo "  status         Quick cluster and app status"
	@echo "  runner         Download self-hosted runner binary"
	@echo "  help           Show this help"
