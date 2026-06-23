#!/bin/bash
set -euo pipefail

echo "Starting port-forwards (background)..."
echo ""

kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
echo "  ArgoCD:     https://localhost:8080"

kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &>/dev/null &
echo "  Grafana:    http://localhost:3000"

kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &>/dev/null &
echo "  Prometheus: http://localhost:9090"

kubectl port-forward svc/jaeger -n monitoring 16686:16686 &>/dev/null &
echo "  Jaeger:     http://localhost:16686"

kubectl port-forward svc/kiali -n istio-system 20001:20001 &>/dev/null &
echo "  Kiali:      http://localhost:20001"

echo ""
echo "All port-forwards started. Press Ctrl+C to stop all."
wait
