#!/bin/bash

# Deploy COMPLETE eBPF Observability Stack
# Components: Cilium + Hubble, Falco, Pixie, Tetragon, Kepler
# All with proper UI configurations

set -e

echo "🚀 Deploying COMPLETE eBPF Observability Stack"
echo "Components: Cilium+Hubble, Falco, Pixie, Tetragon, Kepler"
echo "All with companion UIs where available!"
echo ""

# Add all required Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add cilium https://helm.cilium.io/
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add pixie-operator https://pixie-operator-charts.storage.googleapis.com
helm repo add sustainable-computing-io https://sustainable-computing-io.github.io/kepler-helm-chart
helm repo update

# Check if we're on EKS (need to replace CNI)
EKS_CLUSTER=$(kubectl config current-context | grep -o 'eks' || echo "")

if [[ -n "$EKS_CLUSTER" ]]; then
    echo "🔧 EKS detected - Cilium will be installed as CNI replacement"
    echo "⚠️  Note: This requires cluster restart for full CNI replacement"
fi

# 1. Deploy Cilium with Hubble UI
echo "🌐 Deploying Cilium + Hubble for eBPF networking and security..."
kubectl create namespace cilium-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cilium cilium/cilium \
    --namespace cilium-system \
    --set kubeProxyReplacement=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
    --set cluster.name=prism-cluster \
    --set cluster.id=1 \
    --set ipam.mode=kubernetes \
    --set prometheus.enabled=true \
    --set operator.prometheus.enabled=true \
    --set hubble.enabled=true \
    --set hubble.metrics.enabled=true \
    --set k8sServiceHost=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||') \
    --set k8sServicePort=443 \
    --timeout=10m \
    --wait

echo "✅ Cilium + Hubble deployed!"

# 2. Deploy Pixie for deep application observability
echo "🔍 Deploying Pixie for deep application observability..."
kubectl create namespace pl-system --dry-run=client -o yaml | kubectl apply -f -

# Deploy Pixie operator first
helm upgrade --install pixie-operator pixie-operator/pixie-operator-chart \
    --namespace pl-system \
    --set deployKey="" \
    --set clusterName=prism-cluster \
    --timeout=10m \
    --wait

# Deploy Pixie cloud connector (for self-hosted deployment)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: pl-cluster-secrets
  namespace: pl-system
type: Opaque
stringData:
  cluster-name: "prism-cluster"
  deploy-key: ""
---
apiVersion: px.dev/v1alpha1
kind: Vizier
metadata:
  name: pixie
  namespace: pl-system
spec:
  version: latest
  deployKey: ""
  clusterName: "prism-cluster"
  cloudAddr: "withpixie.ai:443"
  devCloudNamespace: ""
  pemMemoryLimit: "2Gi"
  dataAccess: "Full"
  useEtcdOperator: false
EOF

echo "✅ Pixie deployed!"

# 3. Deploy Falco (already working, but let's ensure it's properly configured)
echo "🛡️ Ensuring Falco is properly deployed..."
if ! kubectl get namespace falco-system &>/dev/null; then
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
        --set falcosidekick.webui.redis.storageEnabled=false \
        --set falcosidekick.webui.redis.persistence.enabled=false \
        --set nodeSelector."kubernetes\.io/os"=linux \
        --timeout=10m \
        --wait
else
    echo "Falco already deployed ✅"
fi

# 4. Deploy Tetragon (already working)
echo "🔍 Ensuring Tetragon is properly deployed..."
if ! kubectl get namespace tetragon-system &>/dev/null; then
    kubectl create namespace tetragon-system
    
    helm upgrade --install tetragon cilium/tetragon \
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
else
    echo "Tetragon already deployed ✅"
fi

# 5. Deploy Kepler with proper working configuration
echo "🌱 Deploying Kepler for energy and carbon monitoring..."
kubectl create namespace kepler-system --dry-run=client -o yaml | kubectl apply -f -

# Clean up any existing broken Kepler deployment
kubectl delete daemonset kepler -n kepler-system --ignore-not-found=true

# Deploy Kepler with a working image and configuration
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
        image: quay.io/sustainable_computing_io/kepler:v0.7.10
        command: ["/usr/bin/kepler"]
        args:
        - -address=0.0.0.0:8888
        - -enable-gpu=false
        - -log-level=1
        - -v=1
        ports:
        - containerPort: 8888
          name: http-metrics
        livenessProbe:
          httpGet:
            path: /metrics
            port: 8888
          initialDelaySeconds: 30
          periodSeconds: 30
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /metrics
            port: 8888
          initialDelaySeconds: 5
          periodSeconds: 10
          failureThreshold: 3
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
        - name: ENABLE_CGROUP_ID
          value: "true"
        - name: ENABLE_PROCESS_METRICS
          value: "true"
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

echo "✅ Kepler deployed!"

# Wait for all components to be ready
echo ""
echo "⏳ Waiting for all eBPF components to be ready..."

# Wait for Cilium
echo "Waiting for Cilium..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cilium-operator -n cilium-system --timeout=300s
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n cilium-system --timeout=300s

# Wait for Hubble
echo "Waiting for Hubble..."
kubectl wait --for=condition=ready pod -l k8s-app=hubble-relay -n cilium-system --timeout=300s
kubectl wait --for=condition=ready pod -l k8s-app=hubble-ui -n cilium-system --timeout=300s

# Wait for Pixie
echo "Waiting for Pixie..."
kubectl wait --for=condition=ready pod -l name=vizier-operator -n pl-system --timeout=300s || echo "Pixie may take longer to initialize"

# Wait for Falco
echo "Waiting for Falco..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=falco -n falco-system --timeout=300s

# Wait for Tetragon
echo "Waiting for Tetragon..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tetragon -n tetragon-system --timeout=300s

# Wait for Kepler
echo "Waiting for Kepler..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kepler -n kepler-system --timeout=300s

echo ""
echo "🎯 Complete eBPF Stack Status:"
echo ""

echo "📊 Cilium + Hubble (Network Security & Observability):"
kubectl get pods -n cilium-system
echo ""

echo "🔍 Pixie (Deep Application Observability):"
kubectl get pods -n pl-system
echo ""

echo "🛡️ Falco (Security Events):"
kubectl get pods -n falco-system | head -3
echo ""

echo "🔍 Tetragon (Process Monitoring):"
kubectl get pods -n tetragon-system | head -3
echo ""

echo "🌱 Kepler (Energy Monitoring):"
kubectl get pods -n kepler-system
echo ""

echo "🚀 Starting ALL eBPF UI Port Forwards..."

# Start port forwards for all UIs
kubectl port-forward -n cilium-system svc/hubble-ui 12000:80 > /dev/null 2>&1 &
HUBBLE_PID=$!

kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802 > /dev/null 2>&1 &
FALCO_PID=$!

kubectl port-forward -n kepler-system svc/kepler 8888:8888 > /dev/null 2>&1 &
KEPLER_PID=$!

# Try to set up Pixie UI port forward (if available)
if kubectl get svc -n pl-system | grep -q pixie-ui; then
    kubectl port-forward -n pl-system svc/pixie-ui 8080:80 > /dev/null 2>&1 &
    PIXIE_PID=$!
else
    echo "Note: Pixie UI service not yet available (may need cloud setup)"
    PIXIE_PID="N/A"
fi

# Give port forwards time to establish
sleep 5

echo "Port forwards started:"
echo "- Hubble (Cilium): PID=$HUBBLE_PID"
echo "- Falco: PID=$FALCO_PID" 
echo "- Kepler: PID=$KEPLER_PID"
echo "- Pixie: PID=$PIXIE_PID"

echo ""
echo "🌐 Access Your COMPLETE eBPF Observability Stack:"
echo "┌─────────────────────────────────────────────────────────────────────────┐"
echo "│ 🌐 Cilium Hubble UI (Network Flows):    http://localhost:12000           │"
echo "│ 🛡️  Falco Security UI:                   http://localhost:2802           │"
echo "│ 🌱 Kepler Energy Metrics:               http://localhost:8888/metrics    │"
echo "│ 🔍 Pixie Deep Observability:            Requires cloud setup             │"
echo "│ 🔍 Tetragon Process Events:             kubectl logs -n tetragon-system  │"
echo "│                                         -l app.kubernetes.io/name=tetragon -f │"
echo "└─────────────────────────────────────────────────────────────────────────┘"

echo ""
echo "🔍 Live Monitoring Commands:"
echo ""
echo "# Watch Cilium network flows"
echo "kubectl exec -n cilium-system -it ds/cilium -- hubble observe"
echo ""
echo "# Watch Falco security events"
echo "kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f"
echo ""
echo "# Watch Tetragon process events"
echo "kubectl logs -n tetragon-system -l app.kubernetes.io/name=tetragon -f"
echo ""
echo "# View Kepler energy metrics"
echo "curl http://localhost:8888/metrics | grep kepler_container"
echo ""
echo "# Check Pixie status"
echo "kubectl get pods -n pl-system"

echo ""
echo "📈 Next Steps:"
echo "• Open browsers to the UI URLs above"
echo "• Run: ./scripts/generate-cell-traffic.sh to create activity"
echo "• Monitor network flows, security events, and energy consumption"
echo "• Use 'kill $HUBBLE_PID $FALCO_PID $KEPLER_PID' to stop port forwards"

echo ""
echo "✨ COMPLETE eBPF Observability Stack is Ready!"
echo "🎯 You now have the full suite: Network, Security, Process, and Energy monitoring!" 