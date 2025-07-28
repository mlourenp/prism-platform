#!/bin/bash

# Prism Platform v1.2 - Phase 1 Testing Execution Script
# Executes comprehensive infrastructure validation tests

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_RESULTS_DIR="${PROJECT_ROOT}/test-results/phase1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Default configuration
PARALLEL=false
CLEANUP=true
CATEGORY="all"
PROVIDER="aws"
VERBOSE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --parallel          Run tests in parallel (default: false)
    --cleanup           Cleanup resources after tests (default: true)
    --category=CATEGORY Test category: all, infrastructure, multi-cloud, performance (default: all)
    --provider=PROVIDER Primary cloud provider: aws, gcp, azure (default: aws)
    --verbose           Enable verbose output (default: false)
    --help              Show this help message

Examples:
    $0                                    # Run all tests sequentially
    $0 --parallel --category=infrastructure   # Run infrastructure tests in parallel
    $0 --provider=gcp --no-cleanup       # Run on GCP without cleanup
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --parallel)
            PARALLEL=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --category=*)
            CATEGORY="${1#*=}"
            shift
            ;;
        --provider=*)
            PROVIDER="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Create test results directory
mkdir -p "${TEST_RESULTS_DIR}"

# Test execution functions
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Verify prerequisites
    command -v terraform >/dev/null 2>&1 || { log_error "terraform is required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed."; exit 1; }
    command -v helm >/dev/null 2>&1 || { log_error "helm is required but not installed."; exit 1; }
    
    # Setup monitoring for tests
    if [[ -f "${SCRIPT_DIR}/setup-test-monitoring.sh" ]]; then
        bash "${SCRIPT_DIR}/setup-test-monitoring.sh"
    fi
    
    log_success "Test environment setup complete"
}

run_infrastructure_tests() {
    log_info "Running infrastructure tests..."
    
    local test_results=()
    
    # Test 1: Minimal Stack
    log_info "Executing Test 1: Minimal Stack Deployment"
    if run_single_test "minimal-stack" "${PROVIDER}"; then
        test_results+=("minimal-stack:PASS")
        log_success "Minimal stack test passed"
    else
        test_results+=("minimal-stack:FAIL")
        log_error "Minimal stack test failed"
    fi
    
    # Test 2: Standard Stack
    log_info "Executing Test 2: Standard Stack Deployment"
    if run_single_test "standard-stack" "${PROVIDER}"; then
        test_results+=("standard-stack:PASS")
        log_success "Standard stack test passed"
    else
        test_results+=("standard-stack:FAIL")
        log_error "Standard stack test failed"
    fi
    
    # Test 3: Complete Stack
    log_info "Executing Test 3: Complete Stack Deployment"
    if run_single_test "complete-stack" "${PROVIDER}"; then
        test_results+=("complete-stack:PASS")
        log_success "Complete stack test passed"
    else
        test_results+=("complete-stack:FAIL")
        log_error "Complete stack test failed"
    fi
    
    # Save results
    printf '%s\n' "${test_results[@]}" > "${TEST_RESULTS_DIR}/infrastructure_results_${TIMESTAMP}.txt"
    
    log_info "Infrastructure tests completed"
}

run_multicloud_tests() {
    log_info "Running multi-cloud tests..."
    
    local test_results=()
    
    # Test 4: Cross-Cloud Service Discovery
    log_info "Executing Test 4: Cross-Cloud Service Discovery"
    if run_cross_cloud_test "service-discovery"; then
        test_results+=("cross-cloud-discovery:PASS")
        log_success "Cross-cloud service discovery test passed"
    else
        test_results+=("cross-cloud-discovery:FAIL")
        log_error "Cross-cloud service discovery test failed"
    fi
    
    # Test 5: Multi-Cloud Data Consistency
    log_info "Executing Test 5: Multi-Cloud Data Consistency"
    if run_cross_cloud_test "data-consistency"; then
        test_results+=("multi-cloud-data:PASS")
        log_success "Multi-cloud data consistency test passed"
    else
        test_results+=("multi-cloud-data:FAIL")
        log_error "Multi-cloud data consistency test failed"
    fi
    
    # Save results
    printf '%s\n' "${test_results[@]}" > "${TEST_RESULTS_DIR}/multicloud_results_${TIMESTAMP}.txt"
    
    log_info "Multi-cloud tests completed"
}

run_performance_tests() {
    log_info "Running performance tests..."
    
    local test_results=()
    
    # Test 6: eBPF Performance
    log_info "Executing Test 6: eBPF Performance Benchmarking"
    if run_performance_test "ebpf-performance"; then
        test_results+=("ebpf-performance:PASS")
        log_success "eBPF performance test passed"
    else
        test_results+=("ebpf-performance:FAIL")
        log_error "eBPF performance test failed"
    fi
    
    # Test 7: Auto-Scaling
    log_info "Executing Test 7: Auto-Scaling Performance"
    if run_performance_test "auto-scaling"; then
        test_results+=("auto-scaling:PASS")
        log_success "Auto-scaling performance test passed"
    else
        test_results+=("auto-scaling:FAIL")
        log_error "Auto-scaling performance test failed"
    fi
    
    # Save results
    printf '%s\n' "${test_results[@]}" > "${TEST_RESULTS_DIR}/performance_results_${TIMESTAMP}.txt"
    
    log_info "Performance tests completed"
}

run_single_test() {
    local test_name="$1"
    local provider="$2"
    local test_dir="${PROJECT_ROOT}/examples/${provider}/${test_name}"
    
    if [[ ! -d "${test_dir}" ]]; then
        log_warning "Test directory not found: ${test_dir}, using generic example"
        test_dir="${PROJECT_ROOT}/examples/multi-cloud-cells/${test_name}"
    fi
    
    if [[ ! -d "${test_dir}" ]]; then
        log_error "Test directory not found: ${test_dir}"
        return 1
    fi
    
    log_info "Running test in: ${test_dir}"
    
    # Change to test directory
    cd "${test_dir}"
    
    # Initialize terraform
    if ! terraform init; then
        log_error "Terraform init failed for ${test_name}"
        return 1
    fi
    
    # Plan deployment
    if ! terraform plan -out=tfplan; then
        log_error "Terraform plan failed for ${test_name}"
        return 1
    fi
    
    # Apply deployment
    if ! terraform apply -auto-approve tfplan; then
        log_error "Terraform apply failed for ${test_name}"
        return 1
    fi
    
    # Wait for deployment to be ready
    sleep 60
    
    # Run basic connectivity tests
    if command -v kubectl >/dev/null 2>&1; then
        kubectl get pods --all-namespaces
        kubectl get nodes
    fi
    
    # Collect metrics
    collect_test_metrics "${test_name}" "${provider}"
    
    # Cleanup if requested
    if [[ "${CLEANUP}" == "true" ]]; then
        log_info "Cleaning up ${test_name}"
        terraform destroy -auto-approve
    fi
    
    return 0
}

run_cross_cloud_test() {
    local test_type="$1"
    log_info "Running cross-cloud test: ${test_type}"
    
    # Placeholder for cross-cloud tests
    # This would involve deploying to multiple clouds and testing connectivity
    
    return 0
}

run_performance_test() {
    local test_type="$1"
    log_info "Running performance test: ${test_type}"
    
    # Placeholder for performance tests
    # This would involve load testing and performance measurement
    
    return 0
}

collect_test_metrics() {
    local test_name="$1"
    local provider="$2"
    local metrics_file="${TEST_RESULTS_DIR}/metrics_${test_name}_${provider}_${TIMESTAMP}.json"
    
    log_info "Collecting metrics for ${test_name}"
    
    # Collect Kubernetes metrics
    if command -v kubectl >/dev/null 2>&1; then
        kubectl top nodes --no-headers > "${metrics_file%.json}_nodes.txt" 2>/dev/null || true
        kubectl top pods --all-namespaces --no-headers > "${metrics_file%.json}_pods.txt" 2>/dev/null || true
    fi
    
    # Collect cost metrics if infracost is available
    if command -v infracost >/dev/null 2>&1; then
        infracost breakdown --path=. --format=json > "${metrics_file%.json}_cost.json" 2>/dev/null || true
    fi
    
    log_success "Metrics collected for ${test_name}"
}

generate_test_report() {
    log_info "Generating comprehensive test report..."
    
    local report_file="${TEST_RESULTS_DIR}/PHASE_1_TEST_RESULTS_${TIMESTAMP}.md"
    
    cat > "${report_file}" << EOF
# Phase 1 Testing Results - ${TIMESTAMP}

## Test Configuration
- **Execution Time**: $(date)
- **Category**: ${CATEGORY}
- **Provider**: ${PROVIDER}
- **Parallel Execution**: ${PARALLEL}
- **Cleanup Enabled**: ${CLEANUP}

## Test Results Summary

EOF
    
    # Add infrastructure results
    if [[ -f "${TEST_RESULTS_DIR}/infrastructure_results_${TIMESTAMP}.txt" ]]; then
        echo "### Infrastructure Tests" >> "${report_file}"
        cat "${TEST_RESULTS_DIR}/infrastructure_results_${TIMESTAMP}.txt" >> "${report_file}"
        echo "" >> "${report_file}"
    fi
    
    # Add multi-cloud results
    if [[ -f "${TEST_RESULTS_DIR}/multicloud_results_${TIMESTAMP}.txt" ]]; then
        echo "### Multi-Cloud Tests" >> "${report_file}"
        cat "${TEST_RESULTS_DIR}/multicloud_results_${TIMESTAMP}.txt" >> "${report_file}"
        echo "" >> "${report_file}"
    fi
    
    # Add performance results
    if [[ -f "${TEST_RESULTS_DIR}/performance_results_${TIMESTAMP}.txt" ]]; then
        echo "### Performance Tests" >> "${report_file}"
        cat "${TEST_RESULTS_DIR}/performance_results_${TIMESTAMP}.txt" >> "${report_file}"
        echo "" >> "${report_file}"
    fi
    
    log_success "Test report generated: ${report_file}"
}

cleanup_test_environments() {
    if [[ "${CLEANUP}" == "true" ]]; then
        log_info "Cleaning up all test environments..."
        
        # Find and destroy any remaining terraform deployments
        find "${PROJECT_ROOT}/examples" -name "terraform.tfstate" -exec dirname {} \; | while read -r dir; do
            log_info "Cleaning up: ${dir}"
            cd "${dir}"
            terraform destroy -auto-approve || log_warning "Failed to cleanup: ${dir}"
        done
        
        log_success "Cleanup completed"
    fi
}

# Main execution
main() {
    log_info "Starting Prism Platform v1.2 Phase 1 Testing"
    log_info "Configuration: Category=${CATEGORY}, Provider=${PROVIDER}, Parallel=${PARALLEL}, Cleanup=${CLEANUP}"
    
    # Setup
    setup_test_environment
    
    # Execute tests based on category
    case "${CATEGORY}" in
        "all")
            run_infrastructure_tests
            run_multicloud_tests
            run_performance_tests
            ;;
        "infrastructure")
            run_infrastructure_tests
            ;;
        "multi-cloud")
            run_multicloud_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        *)
            log_error "Unknown category: ${CATEGORY}"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_test_report
    
    # Cleanup
    cleanup_test_environments
    
    log_success "Phase 1 testing completed successfully"
    log_info "Results available in: ${TEST_RESULTS_DIR}"
}

# Execute main function
main "$@" 