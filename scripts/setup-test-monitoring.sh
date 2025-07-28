#!/bin/bash

# Prism Platform - Test Monitoring Setup Script
# Sets up monitoring infrastructure for Phase 1 testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Create monitoring namespace
setup_monitoring_namespace() {
    log_info "Setting up monitoring namespace..."
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace monitoring istio-injection=enabled --overwrite
    
    log_success "Monitoring namespace ready"
}

# Deploy Prometheus for test metrics
deploy_prometheus() {
    log_info "Deploying Prometheus for test monitoring..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-test-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "test_rules.yml"
    
    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: \$1:\$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name

  test_rules.yml: |
    groups:
    - name: test_performance
      rules:
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: High CPU usage detected during testing
      
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: High memory usage detected during testing
      
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: Pod is crash looping during testing
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-test
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-test
  template:
    metadata:
      labels:
        app: prometheus-test
    spec:
      serviceAccountName: prometheus-test
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=24h'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-test-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-test
  namespace: monitoring
spec:
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus-test
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-test
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-test
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-test
subjects:
- kind: ServiceAccount
  name: prometheus-test
  namespace: monitoring
EOF

    log_success "Prometheus deployed for test monitoring"
}

# Deploy Grafana for visualization
deploy_grafana() {
    log_info "Deploying Grafana for test visualization..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-test-config
  namespace: monitoring
data:
  grafana.ini: |
    [server]
    http_port = 3000
    
    [security]
    admin_user = admin
    admin_password = prism-test-2024
    
    [users]
    allow_sign_up = false

  datasources.yml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus-test:9090
      isDefault: true

  dashboards.yml: |
    apiVersion: 1
    providers:
    - name: 'test-dashboards'
      type: file
      options:
        path: /var/lib/grafana/dashboards

  test-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Prism Test Overview",
        "tags": ["prism", "testing"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "CPU Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "avg(rate(container_cpu_usage_seconds_total[5m]))",
                "refId": "A"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Memory Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "avg(container_memory_usage_bytes)",
                "refId": "A"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "5s"
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-test
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana-test
  template:
    metadata:
      labels:
        app: grafana-test
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.0.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "prism-test-2024"
        volumeMounts:
        - name: config
          mountPath: /etc/grafana
        - name: dashboards
          mountPath: /var/lib/grafana/dashboards
        - name: storage
          mountPath: /var/lib/grafana
      volumes:
      - name: config
        configMap:
          name: grafana-test-config
          items:
          - key: grafana.ini
            path: grafana.ini
          - key: datasources.yml
            path: provisioning/datasources/datasources.yml
          - key: dashboards.yml
            path: provisioning/dashboards/dashboards.yml
      - name: dashboards
        configMap:
          name: grafana-test-config
          items:
          - key: test-overview.json
            path: test-overview.json
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-test
  namespace: monitoring
spec:
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana-test
EOF

    log_success "Grafana deployed for test visualization"
}

# Setup test metrics collection
setup_metrics_collection() {
    log_info "Setting up test metrics collection..."
    
    # Create test metrics directory
    mkdir -p "${PROJECT_ROOT}/test-results/metrics"
    
    # Create metrics collection script
    cat << 'EOF' > "${PROJECT_ROOT}/scripts/collect-current-metrics.sh"
#!/bin/bash

METRICS_DIR="${PROJECT_ROOT}/test-results/metrics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Collect Kubernetes metrics
kubectl top nodes --no-headers > "${METRICS_DIR}/nodes_${TIMESTAMP}.txt" 2>/dev/null || true
kubectl top pods --all-namespaces --no-headers > "${METRICS_DIR}/pods_${TIMESTAMP}.txt" 2>/dev/null || true

# Collect Prometheus metrics
if kubectl get service prometheus-test -n monitoring >/dev/null 2>&1; then
    kubectl port-forward -n monitoring svc/prometheus-test 9090:9090 &
    PF_PID=$!
    sleep 5
    
    # Query key metrics
    curl -s "http://localhost:9090/api/v1/query?query=rate(container_cpu_usage_seconds_total[5m])" \
        > "${METRICS_DIR}/cpu_usage_${TIMESTAMP}.json" 2>/dev/null || true
    
    curl -s "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes" \
        > "${METRICS_DIR}/memory_usage_${TIMESTAMP}.json" 2>/dev/null || true
    
    kill $PF_PID 2>/dev/null || true
fi

echo "Metrics collected at ${TIMESTAMP}"
EOF

    chmod +x "${PROJECT_ROOT}/scripts/collect-current-metrics.sh"
    
    log_success "Metrics collection setup complete"
}

# Setup test alerting
setup_test_alerting() {
    log_info "Setting up test alerting..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-test-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'prism-tests@example.com'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'console'
    
    receivers:
    - name: 'console'
      webhook_configs:
      - url: 'http://localhost:9093/webhook'
        send_resolved: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager-test
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager-test
  template:
    metadata:
      labels:
        app: alertmanager-test
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.25.0
        args:
          - '--config.file=/etc/alertmanager/alertmanager.yml'
          - '--storage.path=/alertmanager'
        ports:
        - containerPort: 9093
        volumeMounts:
        - name: config
          mountPath: /etc/alertmanager
        - name: storage
          mountPath: /alertmanager
      volumes:
      - name: config
        configMap:
          name: alertmanager-test-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-test
  namespace: monitoring
spec:
  ports:
  - port: 9093
    targetPort: 9093
  selector:
    app: alertmanager-test
EOF

    log_success "Test alerting setup complete"
}

# Display access information
display_access_info() {
    log_info "Test monitoring setup complete!"
    echo ""
    echo "Access Information:"
    echo "=================="
    echo "Prometheus: kubectl port-forward -n monitoring svc/prometheus-test 9090:9090"
    echo "Grafana:    kubectl port-forward -n monitoring svc/grafana-test 3000:3000"
    echo "            Username: admin, Password: prism-test-2024"
    echo "AlertManager: kubectl port-forward -n monitoring svc/alertmanager-test 9093:9093"
    echo ""
    echo "Metrics Collection:"
    echo "==================="
    echo "Run: ${PROJECT_ROOT}/scripts/collect-current-metrics.sh"
    echo "Results: ${PROJECT_ROOT}/test-results/metrics/"
}

# Main execution
main() {
    log_info "Starting test monitoring setup..."
    
    setup_monitoring_namespace
    deploy_prometheus
    deploy_grafana
    setup_metrics_collection
    setup_test_alerting
    
    # Wait for deployments to be ready
    log_info "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-test -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/grafana-test -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/alertmanager-test -n monitoring
    
    display_access_info
    
    log_success "Test monitoring setup completed successfully"
}

main "$@" 