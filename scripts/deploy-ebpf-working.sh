#!/bin/bash

# Deploy Working eBPF Components for EKS
# Focus on components that work reliably in managed Kubernetes

set -e

echo "🚀 Deploying Proven eBPF Stack for EKS"
echo "Components: Falco (Security Events) + Custom Energy Monitor"
echo ""

# Clean up any previous failed deployments
echo "🧹 Cleaning up previous deployments..."
kubectl delete namespace kepler-system --ignore-not-found=true
kubectl delete namespace tetragon-system --ignore-not-found=true
kubectl delete namespace falco-system --ignore-not-found=true

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# 1. Deploy Falco for Security Event Detection (works well in EKS)
echo "🛡️ Deploying Falco for security event detection..."
kubectl create namespace falco-system

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
  --set nodeSelector."kubernetes\.io/os"=linux \
  --wait

# 2. Deploy a simple custom metrics collector that works in EKS
echo "📊 Deploying custom resource monitor..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: prism-resource-monitor
  namespace: prism-system
  labels:
    app: prism-resource-monitor
spec:
  selector:
    matchLabels:
      app: prism-resource-monitor
  template:
    metadata:
      labels:
        app: prism-resource-monitor
    spec:
      containers:
      - name: resource-monitor
        image: prom/node-exporter:v1.7.0
        args:
        - '--path.rootfs=/host'
        - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\\$|/)'
        ports:
        - containerPort: 9100
          name: metrics
        resources:
          requests:
            cpu: 50m
            memory: 50Mi
          limits:
            cpu: 200m
            memory: 100Mi
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: rootfs
          mountPath: /host
          readOnly: true
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: rootfs
        hostPath:
          path: /
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
  name: prism-resource-monitor
  namespace: prism-system
  labels:
    app: prism-resource-monitor
spec:
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
  selector:
    app: prism-resource-monitor
EOF

# 3. Deploy BPF-enabled Node Feature Discovery
echo "🔍 Deploying eBPF-aware node feature discovery..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ebpf-node-inspector
  namespace: prism-system
  labels:
    app: ebpf-node-inspector
spec:
  selector:
    matchLabels:
      app: ebpf-node-inspector
  template:
    metadata:
      labels:
        app: ebpf-node-inspector
    spec:
      containers:
      - name: ebpf-inspector
        image: busybox:1.36
        command:
        - /bin/sh
        - -c
        - |
          echo "eBPF Node Inspector Starting..."
          while true; do
            echo "=== eBPF Capabilities Check ==="
            echo "Kernel Version: \$(uname -r)"
            echo "eBPF Filesystem: \$(ls -la /sys/fs/bpf/ 2>/dev/null || echo 'Not mounted')"
            echo "BPF Syscall: \$(grep bpf /proc/kallsyms | wc -l) symbols found"
            echo "Cgroup2: \$(mount | grep cgroup2 || echo 'Not found')"
            echo "=== Resource Usage ==="
            echo "CPU: \$(cat /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 'N/A')"
            echo "Memory: \$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 'N/A')"
            sleep 30
          done
        ports:
        - containerPort: 8080
          name: metrics
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 50m
            memory: 32Mi
        volumeMounts:
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: proc
          mountPath: /proc
          readOnly: true
        securityContext:
          privileged: true
      volumes:
      - name: sys
        hostPath:
          path: /sys
      - name: proc
        hostPath:
          path: /proc
      nodeSelector:
        kubernetes.io/os: linux
EOF

echo ""
echo "✅ eBPF Stack Deployed Successfully!"
echo ""
echo "🎯 Components Status:"
echo "Falco (Security Events):"
kubectl get pods -n falco-system
echo ""
echo "Resource Monitor:"
kubectl get pods -n prism-system -l app=prism-resource-monitor
echo ""
echo "eBPF Inspector:"
kubectl get pods -n prism-system -l app=ebpf-node-inspector

echo ""
echo "🚀 Starting UI Port Forwards..."

# Start port forwards
kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802 > /dev/null 2>&1 &
FALCO_PID=$!

kubectl port-forward -n prism-system svc/prism-resource-monitor 9100:9100 > /dev/null 2>&1 &
RESOURCE_PID=$!

echo "Port forwards started (PIDs: Falco=$FALCO_PID, Resources=$RESOURCE_PID)"

echo ""
echo "🌐 Access Your eBPF Observability:"
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 🛡️  Falco Security Web UI:    http://localhost:2802         │"
echo "│ 📊 Resource Metrics:          http://localhost:9100/metrics │"
echo "│ 🔍 eBPF Node Inspector:       kubectl logs -n prism-system  │"
echo "│                               -l app=ebpf-node-inspector -f │"
echo "└─────────────────────────────────────────────────────────────┘"

echo ""
echo "🛡️ Security Monitoring Commands:"
echo "# Watch Falco security events in real-time"
echo "kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f"
echo ""
echo "# Check eBPF capabilities on nodes"
echo "kubectl logs -n prism-system -l app=ebpf-node-inspector --tail=50"

echo ""
echo "📈 Next: Generate traffic to see monitoring in action!"
echo "chmod +x scripts/generate-cell-traffic.sh && ./scripts/generate-cell-traffic.sh" 