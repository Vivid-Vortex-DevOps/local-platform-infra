.PHONY: prerequisites setup cluster platform destroy verify port-forward status

prerequisites:
	./bootstrap/setup-prerequisites.sh

setup: prerequisites
	./bootstrap/bootstrap.sh

cluster:
	kind create cluster --config cluster/kind-single-node.yaml --wait 120s

platform:
	./bootstrap/bootstrap.sh

destroy:
	./bootstrap/destroy.sh

verify:
	./bootstrap/verify.sh

port-forward:
	./bootstrap/port-forward.sh

status:
	@kubectl get nodes 2>/dev/null || echo "Cluster not running"
	@echo ""
	@kubectl get pods -A --no-headers 2>/dev/null | awk '{print $$1}' | sort | uniq -c | sort -rn || true
