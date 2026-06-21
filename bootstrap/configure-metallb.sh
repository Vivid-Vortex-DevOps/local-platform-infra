#!/bin/bash
set -euo pipefail
export PATH="$HOME/bin:$PATH"

echo "Waiting for MetalLB pods..."
kubectl --context kind-vvd-local wait --namespace metallb-system \
    --for=condition=ready pod --selector=app=metallb --timeout=120s 2>/dev/null || true
sleep 5

# Get the IPv4 subnet (skip IPv6)
KIND_NET_CIDR=$(docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | tr ' ' '\n' | grep -v ':' | head -1)
BASE_IP=$(echo "$KIND_NET_CIDR" | sed 's|\.0/.*||')
echo "Kind network: $KIND_NET_CIDR, Base IP: $BASE_IP"

kubectl --context kind-vvd-local apply -f - <<EOF
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

echo "MetalLB configured"
