#!/bin/bash

# Prism Platform - Baseline Performance Testing Script
# Collects baseline performance metrics for Phase 1 testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/test-results/performance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Configuration
TEST_DURATION="10m"
VUS="50"
RAMP_TIME="2m"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required"; exit 1; }
    command -v k6 >/dev/null 2>&1 || log_warning "k6 not found, install from https://k6.io/docs/getting-started/installation/"
    command -v curl >/dev/null 2>&1 || { log_error "curl is required"; exit 1; }
    
    # Check if cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes cluster not accessible"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Collect baseline infrastructure metrics
collect_baseline_metrics() {
    local test_name="$1"
    log_info "Collecting baseline metrics for ${test_name}..."
    
    local metrics_file="${RESULTS_DIR}/baseline_${test_name}_${TIMESTAMP}.json"
    
    # System information
    cat > "${metrics_file}" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_name": "${test_name}",
  "cluster_info": {
EOF
    
    # Node information
    echo '    "nodes": [' >> "${metrics_file}"
    kubectl get nodes -o json | jq -r '.items[] | {name: .metadata.name, cpu: .status.capacity.cpu, memory: .status.capacity.memory, architecture: .status.nodeInfo.architecture}' | sed 's/^/      /' >> "${metrics_file}"
    echo '    ],' >> "${metrics_file}"
    
    # Current resource usage
    echo '    "current_usage": {' >> "${metrics_file}"
    
    # Node resource usage
    if kubectl top nodes >/dev/null 2>&1; then
        echo '      "node_usage": [' >> "${metrics_file}"
        kubectl top nodes --no-headers | awk '{print "        {\"name\": \"" $1 "\", \"cpu\": \"" $2 "\", \"memory\": \"" $4 "\"}"}' | paste -sd ',' - >> "${metrics_file}"
        echo '' >> "${metrics_file}"
        echo '      ],' >> "${metrics_file}"
    fi
    
    # Pod resource usage
    if kubectl top pods --all-namespaces >/dev/null 2>&1; then
        echo '      "pod_usage": [' >> "${metrics_file}"
        kubectl top pods --all-namespaces --no-headers | awk '{print "        {\"namespace\": \"" $1 "\", \"name\": \"" $2 "\", \"cpu\": \"" $3 "\", \"memory\": \"" $4 "\"}"}' | paste -sd ',' - >> "${metrics_file}"
        echo '' >> "${metrics_file}"
        echo '      ]' >> "${metrics_file}"
    fi
    
    echo '    }' >> "${metrics_file}"
    echo '  },' >> "${metrics_file}"
    
    # Pod count by namespace
    echo '  "pod_distribution": [' >> "${metrics_file}"
    kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c | awk '{print "    {\"namespace\": \"" $2 "\", \"count\": " $1 "}"}' | paste -sd ',' - >> "${metrics_file}"
    echo '' >> "${metrics_file}"
    echo '  ]' >> "${metrics_file}"
    echo '}' >> "${metrics_file}"
    
    log_success "Baseline metrics collected: ${metrics_file}"
}

# Create K6 test script for basic performance testing
create_k6_test_script() {
    local test_name="$1"
    local service_url="$2"
    local script_file="${RESULTS_DIR}/k6_${test_name}_${TIMESTAMP}.js"
    
    cat > "${script_file}" << EOF
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('error_rate');
export let responseTime = new Trend('response_time');
export let requests = new Counter('total_requests');

export let options = {
  stages: [
    { duration: '${RAMP_TIME}', target: ${VUS} },
    { duration: '${TEST_DURATION}', target: ${VUS} },
    { duration: '${RAMP_TIME}', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    error_rate: ['rate<0.1'],
  },
};

export default function() {
  let response;
  
  // Test main endpoint
  response = http.get('${service_url}/health');
  
  let isSuccess = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  errorRate.add(!isSuccess);
  responseTime.add(response.timings.duration);
  requests.add(1);
  
  // Test metrics endpoint if available
  if (Math.random() < 0.1) {
    response = http.get('${service_url}/metrics');
    check(response, {
      'metrics endpoint available': (r) => r.status === 200,
    });
  }
  
  sleep(1);
}

export function handleSummary(data) {
  return {
    '${RESULTS_DIR}/k6_summary_${test_name}_${TIMESTAMP}.json': JSON.stringify(data, null, 2),
  };
}
EOF
    
    echo "${script_file}"
}

# Run Kubernetes performance tests
run_kubernetes_performance_test() {
    local test_name="$1"
    log_info "Running Kubernetes performance test: ${test_name}"
    
    # Test pod creation performance
    log_info "Testing pod creation performance..."
    local start_time=$(date +%s)
    
    # Create test pods
    kubectl run test-pod-1 --image=nginx:alpine --restart=Never
    kubectl run test-pod-2 --image=nginx:alpine --restart=Never
    kubectl run test-pod-3 --image=nginx:alpine --restart=Never
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod/test-pod-1 --timeout=60s
    kubectl wait --for=condition=ready pod/test-pod-2 --timeout=60s
    kubectl wait --for=condition=ready pod/test-pod-3 --timeout=60s
    
    local end_time=$(date +%s)
    local creation_time=$((end_time - start_time))
    
    log_info "Pod creation time: ${creation_time} seconds"
    
    # Test service discovery
    log_info "Testing service discovery..."
    kubectl expose pod test-pod-1 --port=80 --target-port=80 --name=test-service
    sleep 5
    
    # Test internal connectivity
    kubectl run test-client --image=busybox --rm -it --restart=Never -- nslookup test-service
    
    # Cleanup test resources
    kubectl delete pod test-pod-1 test-pod-2 test-pod-3 --ignore-not-found
    kubectl delete service test-service --ignore-not-found
    
    # Save performance metrics
    cat > "${RESULTS_DIR}/kubernetes_performance_${test_name}_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_name": "${test_name}",
  "pod_creation_time_seconds": ${creation_time},
  "test_duration": "${TEST_DURATION}",
  "virtual_users": ${VUS}
}
EOF
    
    log_success "Kubernetes performance test completed"
}

# Test network performance with eBPF
test_ebpf_network_performance() {
    local test_name="$1"
    log_info "Testing eBPF network performance..."
    
    # Check if Cilium is running
    if ! kubectl get pods -n kube-system | grep cilium >/dev/null 2>&1; then
        log_warning "Cilium not found, skipping eBPF network tests"
        return
    fi
    
    # Create network test pods
    kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-test-server
  labels:
    app: network-test-server
spec:
  containers:
  - name: server
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: network-test-service
spec:
  selector:
    app: network-test-server
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-client
spec:
  containers:
  - name: client
    image: curlimages/curl:latest
    command: ['sleep', '3600']
EOF
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod/network-test-server --timeout=60s
    kubectl wait --for=condition=ready pod/network-test-client --timeout=60s
    
    # Run network performance test
    log_info "Running network latency test..."
    local latency_result=$(kubectl exec network-test-client -- sh -c 'for i in $(seq 1 10); do time curl -s http://network-test-service > /dev/null; done' 2>&1 | grep real | awk '{print $2}' | sed 's/[^0-9.]//g' | awk '{sum+=$1} END {print sum/NR}')
    
    log_info "Average network latency: ${latency_result}s"
    
    # Save network performance results
    cat > "${RESULTS_DIR}/network_performance_${test_name}_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_name": "${test_name}",
  "ebpf_enabled": true,
  "average_latency_seconds": ${latency_result:-0},
  "cilium_version": "$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].spec.containers[0].image}' | cut -d':' -f2)"
}
EOF
    
    # Cleanup
    kubectl delete pod network-test-server network-test-client --ignore-not-found
    kubectl delete service network-test-service --ignore-not-found
    
    log_success "eBPF network performance test completed"
}

# Generate performance report
generate_performance_report() {
    local test_name="$1"
    log_info "Generating performance report..."
    
    local report_file="${RESULTS_DIR}/performance_report_${test_name}_${TIMESTAMP}.md"
    
    cat > "${report_file}" << EOF
# Performance Test Report - ${test_name}

**Test Date**: $(date)  
**Test Duration**: ${TEST_DURATION}  
**Virtual Users**: ${VUS}  
**Ramp Time**: ${RAMP_TIME}  

## Test Configuration

- **Cluster**: $(kubectl config current-context)
- **Nodes**: $(kubectl get nodes --no-headers | wc -l)
- **Total Pods**: $(kubectl get pods --all-namespaces --no-headers | wc -l)

## Performance Metrics

### Infrastructure Baseline
EOF
    
    # Add baseline metrics if available
    if [[ -f "${RESULTS_DIR}/baseline_${test_name}_${TIMESTAMP}.json" ]]; then
        echo "See: \`baseline_${test_name}_${TIMESTAMP}.json\`" >> "${report_file}"
    fi
    
    cat >> "${report_file}" << EOF

### Kubernetes Performance
EOF
    
    # Add Kubernetes performance metrics if available
    if [[ -f "${RESULTS_DIR}/kubernetes_performance_${test_name}_${TIMESTAMP}.json" ]]; then
        local pod_creation_time=$(jq -r '.pod_creation_time_seconds' "${RESULTS_DIR}/kubernetes_performance_${test_name}_${TIMESTAMP}.json")
        echo "- **Pod Creation Time**: ${pod_creation_time} seconds" >> "${report_file}"
    fi
    
    cat >> "${report_file}" << EOF

### Network Performance
EOF
    
    # Add network performance metrics if available
    if [[ -f "${RESULTS_DIR}/network_performance_${test_name}_${TIMESTAMP}.json" ]]; then
        local avg_latency=$(jq -r '.average_latency_seconds' "${RESULTS_DIR}/network_performance_${test_name}_${TIMESTAMP}.json")
        local cilium_version=$(jq -r '.cilium_version' "${RESULTS_DIR}/network_performance_${test_name}_${TIMESTAMP}.json")
        echo "- **Average Network Latency**: ${avg_latency} seconds" >> "${report_file}"
        echo "- **Cilium Version**: ${cilium_version}" >> "${report_file}"
    fi
    
    cat >> "${report_file}" << EOF

### Load Testing Results
EOF
    
    # Add K6 results if available
    if [[ -f "${RESULTS_DIR}/k6_summary_${test_name}_${TIMESTAMP}.json" ]]; then
        echo "See: \`k6_summary_${test_name}_${TIMESTAMP}.json\`" >> "${report_file}"
    fi
    
    cat >> "${report_file}" << EOF

## Files Generated

- **Baseline Metrics**: \`baseline_${test_name}_${TIMESTAMP}.json\`
- **Kubernetes Performance**: \`kubernetes_performance_${test_name}_${TIMESTAMP}.json\`
- **Network Performance**: \`network_performance_${test_name}_${TIMESTAMP}.json\`
- **Load Test Results**: \`k6_summary_${test_name}_${TIMESTAMP}.json\`

## Next Steps

1. Compare results with previous baselines
2. Identify performance bottlenecks
3. Optimize configuration based on results
4. Schedule regular performance testing

---
*Generated by Prism Performance Testing Suite*
EOF
    
    log_success "Performance report generated: ${report_file}"
}

# Main execution function
main() {
    local test_name="${1:-baseline}"
    local service_url="${2:-http://kubernetes.default.svc.cluster.local}"
    
    log_info "Starting baseline performance test: ${test_name}"
    log_info "Test configuration: Duration=${TEST_DURATION}, VUs=${VUS}, Ramp=${RAMP_TIME}"
    
    check_prerequisites
    
    # Collect baseline metrics
    collect_baseline_metrics "${test_name}"
    
    # Run Kubernetes performance tests
    run_kubernetes_performance_test "${test_name}"
    
    # Test eBPF network performance
    test_ebpf_network_performance "${test_name}"
    
    # Run load testing if K6 is available
    if command -v k6 >/dev/null 2>&1; then
        log_info "Running K6 load testing..."
        local k6_script=$(create_k6_test_script "${test_name}" "${service_url}")
        k6 run "${k6_script}" || log_warning "K6 load test failed"
    else
        log_warning "K6 not available, skipping load testing"
    fi
    
    # Generate comprehensive report
    generate_performance_report "${test_name}"
    
    log_success "Baseline performance testing completed"
    log_info "Results available in: ${RESULTS_DIR}"
}

# Usage information
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "Usage: $0 [TEST_NAME] [SERVICE_URL]"
    echo ""
    echo "Arguments:"
    echo "  TEST_NAME    Name of the test (default: baseline)"
    echo "  SERVICE_URL  URL to test (default: kubernetes.default.svc.cluster.local)"
    echo ""
    echo "Environment Variables:"
    echo "  TEST_DURATION  Test duration (default: 10m)"
    echo "  VUS           Virtual users (default: 50)"
    echo "  RAMP_TIME     Ramp up/down time (default: 2m)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run baseline test"
    echo "  $0 minimal-stack                     # Run test named 'minimal-stack'"
    echo "  TEST_DURATION=30m VUS=100 $0         # Run with custom settings"
    exit 0
fi

# Execute main function
main "$@" 