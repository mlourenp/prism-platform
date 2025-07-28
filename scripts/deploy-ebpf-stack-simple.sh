#!/bin/bash

# Deploy eBPF Observability Stack - Simplified Version
# Components: Kepler + Tetragon + Falco (without ServiceMonitor dependencies)

set -e

echo "🚀 Deploying eBPF Observability Stack (Simplified)"
echo "Components: Kepler (Energy) + Tetragon (Security) + Falco (Events)"
echo ""

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add sustainable-computing-io https://sustainable-computing-io.github.io/kepler-helm-chart
helm repo add cilium https://helm.cilium.io
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# 1. Deploy Kepler for Energy Monitoring (without ServiceMonitor)
echo "🌱 Deploying Kepler for energy consumption monitoring..."
kubectl create namespace kepler-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kepler sustainable-computing-io/kepler \
  --namespace kepler-system \
  --set serviceMonitor.enabled=false \
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
echo "Kepler (Energy Monitoring):"
kubectl get pods -n kepler-system
echo ""
echo "Tetragon (eBPF Security):"
kubectl get pods -n tetragon-system  
echo ""
echo "Falco (Security Events):"
kubectl get pods -n falco-system

echo ""
echo "🚀 Starting UI Port Forwards..."

# Start port forwards in background
kubectl port-forward -n kepler-system svc/kepler 8888:8888 > /dev/null 2>&1 &
KEPLER_PID=$!

kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802 > /dev/null 2>&1 &
FALCO_PID=$!

echo "Port forwards started (PIDs: Kepler=$KEPLER_PID, Falco=$FALCO_PID)"

echo ""
echo "🌐 Access Your eBPF Observability UIs:"
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 🌱 Kepler Energy Dashboard:  http://localhost:8888/metrics  │"
echo "│ 🛡️  Falco Security Web UI:   http://localhost:2802          │"
echo "│ 🔍 Tetragon Events:         kubectl logs -n tetragon-system │"
echo "│                             -l app.kubernetes.io/name=tetragon -f │"
echo "└─────────────────────────────────────────────────────────────┘"

echo ""
echo "💡 Next Steps:"
echo "• Open browsers to the URLs above"
echo "• Generate some traffic to see energy consumption"
echo "• Monitor security events in real-time"
echo "• Use 'kill $KEPLER_PID $FALCO_PID' to stop port forwards" 