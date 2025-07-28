#!/bin/bash

# Generate Traffic Across All Prism Cell Types
# This creates realistic workload patterns for eBPF observability monitoring

set -e

echo "🚀 Generating Traffic Across Prism Cell Architecture"
echo "This will create realistic workloads to demonstrate eBPF monitoring"
echo ""

# Function to create traffic for a specific cell
generate_cell_traffic() {
    local cell_type=$1
    local namespace=$2
    local service=$3
    local duration=${4:-60}
    
    echo "📊 Generating traffic for $cell_type cell..."
    
    # Create a job to generate traffic
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: traffic-gen-$cell_type-$(date +%s)
  namespace: $namespace
spec:
  template:
    spec:
      containers:
      - name: traffic-generator
        image: curlimages/curl:8.5.0
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting traffic generation for $cell_type cell"
          for i in \$(seq 1 $duration); do
            # Make requests to the service
            curl -s http://$service.$namespace.svc.cluster.local/ -m 2 || true
            curl -s http://$service.$namespace.svc.cluster.local/health -m 2 || true
            curl -s http://$service.$namespace.svc.cluster.local/metrics -m 2 || true
            
            # Create some computational load
            dd if=/dev/zero of=/tmp/test bs=1M count=10 2>/dev/null || true
            rm -f /tmp/test
            
            # Sleep between requests
            sleep \$((RANDOM % 3 + 1))
          done
          echo "Traffic generation completed for $cell_type cell"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
      restartPolicy: Never
  backoffLimit: 0
EOF
}

# Function to create CPU-intensive workload
generate_cpu_load() {
    local namespace=$1
    local duration=${2:-300}
    
    echo "🔥 Creating CPU-intensive workload in $namespace..."
    
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: cpu-stress-$(date +%s)
  namespace: $namespace
spec:
  template:
    spec:
      containers:
      - name: cpu-stress
        image: polinux/stress:1.0.4
        command: ["stress"]
        args: 
        - "--cpu"
        - "2"
        - "--timeout"
        - "${duration}s"
        - "--verbose"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 128Mi
      restartPolicy: Never
  backoffLimit: 0
EOF
}

# Generate traffic for all cell types
echo "🎯 Starting traffic generation for all cells..."

# Data Cell Traffic (high memory usage)
generate_cell_traffic "data" "data-cell" "data-processor" 180
generate_cpu_load "data-cell" 180

# ML Cell Traffic (high CPU/GPU usage)  
generate_cell_traffic "ml" "ml-cell" "ml-inference" 180
generate_cpu_load "ml-cell" 300

# Channel Cell Traffic (high network I/O)
generate_cell_traffic "channel" "channel-cell" "api-gateway" 120

# Logic Cell Traffic (computational load)
generate_cell_traffic "logic" "logic-cell" "business-logic" 150
generate_cpu_load "logic-cell" 200

# Security Cell Traffic
generate_cell_traffic "security" "security-cell" "security-scanner" 90

# External Cell Traffic  
generate_cell_traffic "external" "external-cell" "integration-hub" 120

# Integration Cell Traffic
generate_cell_traffic "integration" "integration-cell" "workflow-engine" 100

# Legacy Cell Traffic
generate_cell_traffic "legacy" "legacy-cell" "legacy-adapter" 90

echo ""
echo "🌊 Traffic Generation Jobs Created!"
echo ""
echo "📊 Monitor your eBPF observability stack:"
echo "• Kepler Energy: http://localhost:8888/metrics"
echo "• Falco Security: http://localhost:2802"
echo "• Tetragon Events: kubectl logs -n tetragon-system -l app.kubernetes.io/name=tetragon -f"

echo ""
echo "🔍 Watch Real-time Activity:"
echo "kubectl get jobs --all-namespaces --watch"
echo "kubectl top nodes"
echo "kubectl top pods --all-namespaces --sort-by=cpu"

echo ""
echo "🌱 Energy Monitoring Commands:"
echo "# View raw Kepler metrics"
echo "curl http://localhost:8888/metrics | grep kepler"
echo ""
echo "# Monitor power consumption"
echo "watch -n 5 'curl -s http://localhost:8888/metrics | grep kepler_container_package_joules_total'"

echo ""
echo "🛡️ Security Event Monitoring:"
echo "# Watch Tetragon process events"
echo "kubectl logs -n tetragon-system -l app.kubernetes.io/name=tetragon --tail=100 -f"
echo ""
echo "# Watch Falco security alerts"
echo "kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=50 -f"

echo ""
echo "⏱️ Traffic Duration: ~5 minutes total"
echo "🎯 All cells will receive realistic workload patterns"
echo "📈 Perfect for demonstrating energy consumption and security monitoring!" 