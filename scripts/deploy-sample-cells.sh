#!/bin/bash

# Deploy Comprehensive Sample Cells for Prism Platform
# This script deploys all 8 cell types to demonstrate the full platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRISM_DIR="$(dirname "$SCRIPT_DIR")"

log_info "Deploying comprehensive sample cells..."
log_info "This will create 7 different cell types with monitoring enabled"

# Deploy the comprehensive sample cells
SAMPLE_CELLS_FILE="$PRISM_DIR/examples/comprehensive-cells/sample-cells.yaml"

if [[ ! -f "$SAMPLE_CELLS_FILE" ]]; then
    log_error "Sample cells file not found: $SAMPLE_CELLS_FILE"
    exit 1
fi

log_info "Applying sample cells configuration..."
kubectl apply -f "$SAMPLE_CELLS_FILE"

if [[ $? -eq 0 ]]; then
    log_success "Sample cells deployed successfully!"
else
    log_error "Failed to deploy sample cells"
    exit 1
fi

# Wait for deployments to be ready
log_info "Waiting for deployments to be ready..."

NAMESPACES=(
    "channel-cell"
    "logic-cell" 
    "security-cell"
    "external-cell"
    "integration-cell"
    "legacy-cell"
    "data-cell"
    "ml-cell"
    "observability-cell"
)

for namespace in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Checking deployments in $namespace..."
        
        # Get all deployments in the namespace
        deployments=$(kubectl get deployments -n "$namespace" -o name 2>/dev/null || echo "")
        
        if [[ -n "$deployments" ]]; then
            for deployment in $deployments; do
                deployment_name=$(echo "$deployment" | cut -d'/' -f2)
                log_info "Waiting for $deployment_name in $namespace to be ready..."
                
                if kubectl wait --for=condition=available --timeout=300s deployment/"$deployment_name" -n "$namespace"; then
                    log_success "$deployment_name is ready"
                else
                    log_warning "$deployment_name did not become ready within timeout"
                fi
            done
        else
            log_info "No deployments found in $namespace"
        fi
    else
        log_warning "Namespace $namespace not found"
    fi
done

# Display deployment status
log_info "Deployment status summary:"
echo
printf "%-20s %-15s %-10s %-15s\n" "NAMESPACE" "DEPLOYMENT" "READY" "STATUS"
printf "%-20s %-15s %-10s %-15s\n" "----------" "-----------" "-----" "------"

for namespace in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$namespace" &> /dev/null; then
        deployments=$(kubectl get deployments -n "$namespace" -o name 2>/dev/null || echo "")
        
        if [[ -n "$deployments" ]]; then
            for deployment in $deployments; do
                deployment_name=$(echo "$deployment" | cut -d'/' -f2)
                
                # Get deployment status
                ready=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                desired=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                
                if [[ "$ready" == "$desired" ]] && [[ "$ready" != "0" ]]; then
                    status="✓ Running"
                    status_color="${GREEN}"
                else
                    status="✗ Not Ready"
                    status_color="${RED}"
                fi
                
                printf "%-20s %-15s ${status_color}%-10s %-15s${NC}\n" "$namespace" "$deployment_name" "$ready/$desired" "$status"
            done
        else
            printf "%-20s %-15s %-10s %-15s\n" "$namespace" "No deployments" "-" "Empty"
        fi
    fi
done

echo
log_info "Checking services and metrics endpoints..."

# Check that services are exposing metrics
for namespace in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$namespace" &> /dev/null; then
        services=$(kubectl get services -n "$namespace" -l "prism.io/monitoring=enabled" -o name 2>/dev/null || echo "")
        
        if [[ -n "$services" ]]; then
            for service in $services; do
                service_name=$(echo "$service" | cut -d'/' -f2)
                log_info "✓ Service $service_name in $namespace has monitoring enabled"
            done
        fi
    fi
done

echo
log_success "Sample cells deployment completed!"
log_info "You should now see metrics from all 7 cell types in Grafana"
log_info ""
log_info "To view the metrics, you can:"
log_info "1. Port-forward to Grafana: kubectl port-forward -n prism-system svc/grafana 3000:3000"
log_info "2. Access Grafana at http://localhost:3000 (admin/admin)"
log_info "3. Import the Prism Cell Communication Overview dashboard"
log_info ""
log_info "Cell types deployed:"
log_info "  • Channel Cell    - API Gateway (channel-cell namespace)"
log_info "  • Logic Cell      - Business Logic (logic-cell namespace)"
log_info "  • Data Cell       - Data Processing (data-cell namespace)"
log_info "  • ML Cell         - ML Inference (ml-cell namespace)"
log_info "  • Security Cell   - Security Scanning (security-cell namespace)"
log_info "  • External Cell   - External Integrations (external-cell namespace)"
log_info "  • Integration Cell- Workflow Orchestration (integration-cell namespace)"
log_info "  • Legacy Cell     - Legacy System Adapter (legacy-cell namespace)"
log_info "  • Observability Cell - Monitoring Stack (observability-cell namespace)" 