#!/bin/bash

# Deploy Complete eBPF Observability Stack - Final Working Version
# Components: Falco + Kepler + Tetragon (with proper configurations)

set -e

echo "🚀 Deploying Complete eBPF Observability Stack"
echo "Components: Falco (Security) + Kepler (Energy) + Tetragon (Process Monitoring)"
echo ""

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add sustainable-computing-io https://sustainable-computing-io.github.io/kepler-helm-chart
helm repo add cilium https://helm.cilium.io
helm repo update

# 1. Deploy Falco with corrected configuration (no UI persistence issues)
echo "🛡️ Deploying Falco for eBPF security monitoring..."
kubectl create namespace falco-system

helm install falco falcosecurity/falco \
  --namespace falco-system \
  --set driver.kind=ebpf \
  --set ebpf.enabled=true \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true \
  --set falco.httpOutput.enabled=true \
  --set falco.httpOutput.url="http://falcosidekick:2801" \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falcosidekick.webui.redis.storageEnabled=false \
  --set falcosidekick.webui.redis.persistence.enabled=false \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --timeout=10m \
  --wait

echo "✅ Falco deployed successfully!"

# 2. Deploy Kepler with simplified configuration
echo "🌱 Deploying Kepler for energy consumption monitoring..."
kubectl create namespace kepler-system

# Deploy Kepler manually with a working configuration
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kepler
  namespace: kepler-system
  labels:
    app.kubernetes.io/name: kepler
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kepler
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kepler
    spec:
      containers:
      - name: kepler
        image: quay.io/sustainable_computing_io/kepler:v0.7.11
        command: ["/usr/bin/kepler"]
        args:
        - -address=0.0.0.0:8888
        - -metrics-path=/metrics
        - -enable-gpu=true
        - -log-level=1
        ports:
        - containerPort: 8888
          name: http-metrics
        livenessProbe:
          httpGet:
            path: /metrics
            port: 8888
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /metrics
            port: 8888
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 400Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
---
apiVersion: v1
kind: Service
metadata:
  name: kepler
  namespace: kepler-system
  labels:
    app.kubernetes.io/name: kepler
spec:
  ports:
  - port: 8888
    targetPort: 8888
    name: http-metrics
  selector:
    app.kubernetes.io/name: kepler
EOF

echo "✅ Kepler deployed successfully!"

# 3. Deploy Tetragon for eBPF process monitoring
echo "🔍 Deploying Tetragon for eBPF process monitoring..."
kubectl create namespace tetragon-system

helm install tetragon cilium/tetragon \
  --namespace tetragon-system \
  --set tetragon.enabled=true \
  --set tetragonOperator.enabled=true \
  --set export.stdout.enabled=true \
  --set export.mode=stdout \
  --set processcreds.enabled=true \
  --set processns.enabled=true \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --timeout=10m \
  --wait

echo "✅ Tetragon deployed successfully!"

# Wait for all components to be ready
echo ""
echo "⏳ Waiting for all eBPF components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=falco -n falco-system --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kepler -n kepler-system --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tetragon -n tetragon-system --timeout=300s

echo ""
echo "🎯 Component Status Check:"
echo "Falco (Security Events):"
kubectl get pods -n falco-system
echo ""
echo "Kepler (Energy Monitoring):"
kubectl get pods -n kepler-system
echo ""
echo "Tetragon (Process Monitoring):"
kubectl get pods -n tetragon-system

echo ""
echo "🚀 Starting UI Port Forwards..."

# Start port forwards in background
kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802 > /dev/null 2>&1 &
FALCO_PID=$!

kubectl port-forward -n kepler-system svc/kepler 8888:8888 > /dev/null 2>&1 &
KEPLER_PID=$!

# Give port forwards time to establish
sleep 3

echo "Port forwards started (PIDs: Falco=$FALCO_PID, Kepler=$KEPLER_PID)"

echo ""
echo "🌐 Access Your Complete eBPF Observability Stack:"
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 🛡️  Falco Security Web UI:    http://localhost:2802         │"
echo "│ 🌱 Kepler Energy Metrics:     http://localhost:8888/metrics │"
echo "│ 🔍 Tetragon Process Events:   kubectl logs -n tetragon-sys  │"
echo "│                               -l app.kubernetes.io/name=tetragon -f │"
echo "└─────────────────────────────────────────────────────────────┘"

echo ""
echo "🔍 Monitoring Commands:"
echo "# Watch Falco security events"
echo "kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f"
echo ""
echo "# View Kepler energy metrics"
echo "curl http://localhost:8888/metrics | grep kepler_container"
echo ""
echo "# Watch Tetragon process events"
echo "kubectl logs -n tetragon-system -l app.kubernetes.io/name=tetragon -f"

echo ""
echo "📈 Next Steps:"
echo "• Open browsers to the URLs above"
echo "• Run: chmod +x scripts/generate-cell-traffic.sh && ./scripts/generate-cell-traffic.sh"
echo "• Monitor energy consumption and security events in real-time"
echo "• Use 'kill $FALCO_PID $KEPLER_PID' to stop port forwards"

echo ""
echo "✨ eBPF Observability Stack is Ready!" 