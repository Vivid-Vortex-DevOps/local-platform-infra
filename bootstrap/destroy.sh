#!/bin/bash
set -euo pipefail

CLUSTER_NAME="vvd-local"

echo ""
echo "=========================================="
echo "  Destroying Local Platform"
echo "  Cluster: ${CLUSTER_NAME}"
echo "=========================================="
echo ""

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Deleting Kind cluster: ${CLUSTER_NAME}..."
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "Cluster deleted."
else
    echo "Cluster '${CLUSTER_NAME}' not found. Nothing to delete."
fi

echo ""
echo "Platform destroyed. Run ./bootstrap/bootstrap.sh to recreate."
