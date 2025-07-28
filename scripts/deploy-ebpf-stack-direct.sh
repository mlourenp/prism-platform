#!/bin/bash

# Deploy eBPF Observability Stack Directly
# Complete stack: Kepler + Tetragon + Falco (Cilium in EKS requires special setup)

set -e

echo "🚀 Deploying Complete eBPF Observability Stack (Direct Method)"
echo "Components: Kepler (Energy) + Tetragon (Security) + Falco (Events)"
echo ""

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add sustainable-computing-io https://sustainable-computing-io.github.io/kepler-helm-chart
helm repo add cilium https://helm.cilium.io
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# 1. Deploy Kepler for Energy Monitoring
echo "🌱 Deploying Kepler for energy consumption monitoring..."
kubectl create namespace kepler-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kepler sustainable-computing-io/kepler \
  --namespace kepler-system \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=kepler-system \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --set securityContext.privileged=true \
  --set extraEnvVars.KEPLER_LOG_LEVEL=1 \
  --set extraEnvVars.METRICS_PATH="/metrics" \
  --set extraEnvVars.BIND_ADDRESS="0.0.0.0:8888" \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=400Mi \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=1Gi \
  --wait

# 2. Deploy Tetragon for eBPF Runtime Security
echo "🔒 Deploying Tetragon for eBPF runtime security monitoring..."
kubectl create namespace tetragon-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon-system \
  --set tetragon.enabled=true \
  --set tetragonOperator.enabled=true \
  --set export.stdout.enabled=true \
  --set export.mode=stdout \
  --set processcreds.enabled=true \
  --set processns.enabled=true \
  --wait

# 3. Deploy Falco for Security Event Detection
echo "🛡️ Deploying Falco for security event detection..."
kubectl create namespace falco-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install falco falcosecurity/falco \
  --namespace falco-system \
  --set driver.kind=ebpf \
  --set ebpf.enabled=true \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true \
  --set falco.httpOutput.enabled=true \
  --set falco.httpOutput.url="http://falcosidekick:2801" \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --wait

echo ""
echo "✅ eBPF Observability Stack Deployed Successfully!"
echo ""
echo "🎯 Components Status:"
kubectl get pods -n kepler-system
kubectl get pods -n tetragon-system  
kubectl get pods -n falco-system

echo ""
echo "📊 Available Endpoints:"
echo "  • Kepler Metrics: kubectl port-forward -n kepler-system svc/kepler 8888:8888"
echo "  • Tetragon Events: kubectl logs -n tetragon-system -l app.kubernetes.io/name=tetragon -f"
echo "  • Falco Web UI: kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802"

echo ""
echo "🌱 Sustainability Dashboard:"
echo "Kepler provides real-time energy consumption metrics for your Kubernetes workloads"
echo "Access via: http://localhost:8888/metrics (after port-forward)"

echo ""
echo "🔍 Security Monitoring:"
echo "• Tetragon: Process-level security monitoring with eBPF"
echo "• Falco: Runtime security event detection and alerting" 