#!/bin/bash

# Prism Platform - Quick Environment Setup Script
# Automated setup for Phase 1 testing environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║           Prism Platform v1.2 Environment Setup              ║
║                  Quick Testing Configuration                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
log_info "🚀 Setting up Prism testing environment..."

# Step 1: Load or create environment variables
log_info "📋 Setting up environment variables..."

if [[ ! -f "${PROJECT_ROOT}/.env.testing" ]]; then
    log_info "Creating .env.testing file..."
    
    cat > "${PROJECT_ROOT}/.env.testing" << 'EOF'
# ===========================================
# Prism Platform Testing Configuration
# ===========================================

# Test Configuration
export PRISM_TEST_ENVIRONMENT="testing"
export PRISM_TEST_REGION="us-east-1"
export PRISM_TEST_DURATION="10m"
export PRISM_TEST_VUS="50"

# Cloud Provider Settings
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
export GCP_PROJECT="your-gcp-project"
export GCP_REGION="us-central1"
export AZURE_SUBSCRIPTION_ID="your-azure-subscription"

# Kubernetes Configuration
export KUBECONFIG="$HOME/.kube/config"
export KUBE_NAMESPACE="prism-platform"

# Testing Features
export ENABLE_PERFORMANCE_TESTING="true"
export ENABLE_COST_ANALYSIS="true"
export ENABLE_MULTI_CLOUD_TESTING="false"
export CLEANUP_AFTER_TESTS="true"

# Monitoring Configuration
export PROMETHEUS_RETENTION="24h"
export GRAFANA_ADMIN_PASSWORD="prism-test-2024"
export ENABLE_ALERTS="true"

# Cost Management
export INFRACOST_API_KEY=""
export COST_BUDGET_LIMIT="100"

# Security Settings
export ENABLE_SECURITY_SCANNING="true"
export POD_SECURITY_STANDARD="restricted"

# Performance Tuning
export MAX_PARALLEL_TESTS="3"
export TEST_TIMEOUT="30m"
export RESOURCE_CLEANUP_TIMEOUT="10m"

# eBPF Testing
export ENABLE_EBPF_TESTING="true"
export CILIUM_VERSION="1.15.3"
export TETRAGON_VERSION="0.10.0"

# Service Mesh Testing
export ENABLE_SERVICE_MESH_TESTING="true"
export ISTIO_VERSION="1.26.1"
export ENABLE_MERBRIDGE="true"
EOF
    
    log_success "Created .env.testing file"
else
    log_success ".env.testing file already exists"
fi

# Load environment variables
source "${PROJECT_ROOT}/.env.testing"
log_success "Environment variables loaded"

# Step 2: Verify required tools
log_info "🛠️  Verifying required tools..."

verify_tool() {
    local tool="$1"
    local install_cmd="$2"
    
    if command -v "$tool" >/dev/null 2>&1; then
        log_success "$tool is installed"
        return 0
    else
        log_error "$tool is not installed"
        if [[ -n "$install_cmd" ]]; then
            log_info "To install: $install_cmd"
        fi
        return 1
    fi
}

tools_ok=true
verify_tool "terraform" "https://terraform.io/downloads" || tools_ok=false
verify_tool "kubectl" "https://kubernetes.io/docs/tasks/tools/" || tools_ok=false
verify_tool "helm" "https://helm.sh/docs/intro/install/" || tools_ok=false
verify_tool "jq" "sudo apt-get install jq" || tools_ok=false
verify_tool "curl" "sudo apt-get install curl" || tools_ok=false

if [[ "$tools_ok" != "true" ]]; then
    log_error "Some required tools are missing. Please install them and run this script again."
    exit 1
fi

# Step 3: Verify cloud access
log_info "☁️  Verifying cloud provider access..."

cloud_configured=false

if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        region=$(aws configure get region 2>/dev/null || echo "us-east-1")
        log_success "AWS configured (Account: ${account}, Region: ${region})"
        cloud_configured=true
    else
        log_warning "AWS CLI found but not configured. Run: aws configure"
    fi
else
    log_warning "AWS CLI not found"
fi

if command -v gcloud >/dev/null 2>&1; then
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        project=$(gcloud config get-value project 2>/dev/null || echo "none")
        log_success "GCP configured (Project: ${project})"
        cloud_configured=true
    else
        log_warning "GCP CLI found but not authenticated. Run: gcloud auth login"
    fi
else
    log_warning "GCP CLI not found"
fi

if [[ "$cloud_configured" != "true" ]]; then
    log_error "No cloud providers are configured. Please configure at least one:"
    echo "  AWS: aws configure"
    echo "  GCP: gcloud auth login"
    exit 1
fi

# Step 4: Verify Kubernetes access
log_info "🎛️  Verifying Kubernetes cluster access..."

if kubectl cluster-info >/dev/null 2>&1; then
    context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    log_success "Kubernetes cluster accessible (Context: ${context}, Nodes: ${nodes})"
    
    # Check basic permissions
    if kubectl auth can-i create pods >/dev/null 2>&1; then
        log_success "Required permissions verified"
    else
        log_error "Insufficient Kubernetes permissions"
        exit 1
    fi
else
    log_error "Kubernetes cluster not accessible. Please configure kubectl:"
    echo "  For EKS: aws eks update-kubeconfig --region us-east-1 --name cluster-name"
    echo "  For GKE: gcloud container clusters get-credentials cluster-name --region us-central1"
    echo "  For local: ensure your kubeconfig is properly configured"
    exit 1
fi

# Step 5: Create test namespace
log_info "🏗️  Setting up test namespace..."

if kubectl get namespace prism-platform-testing >/dev/null 2>&1; then
    log_success "Test namespace already exists"
else
    kubectl create namespace prism-platform-testing
    log_success "Created test namespace: prism-platform-testing"
fi

# Step 6: Create test results directory
log_info "📁 Setting up test directories..."

mkdir -p "${PROJECT_ROOT}/test-results/phase1"
mkdir -p "${PROJECT_ROOT}/test-results/metrics"
mkdir -p "${PROJECT_ROOT}/test-results/logs"

log_success "Test directories created"

# Step 7: Verify network connectivity
log_info "🌐 Checking network connectivity..."

network_ok=true
if curl -s --max-time 10 "https://registry.terraform.io/v1/modules" >/dev/null 2>&1; then
    log_success "Terraform registry accessible"
else
    log_warning "Terraform registry not accessible"
    network_ok=false
fi

if curl -s --max-time 10 "https://storage.googleapis.com/kubernetes-release/release/stable.txt" >/dev/null 2>&1; then
    log_success "Kubernetes releases accessible"
else
    log_warning "Kubernetes releases not accessible"
    network_ok=false
fi

if [[ "$network_ok" != "true" ]]; then
    log_warning "Some network connectivity issues detected. Tests may have limited functionality."
fi

# Step 8: Optional tool configuration
log_info "🔧 Checking optional tools..."

if command -v k6 >/dev/null 2>&1; then
    log_success "K6 available for load testing"
else
    log_warning "K6 not found - load testing will be limited"
    echo "  Install: https://k6.io/docs/getting-started/installation/"
fi

if command -v infracost >/dev/null 2>&1; then
    if infracost auth status >/dev/null 2>&1; then
        log_success "Infracost configured for cost analysis"
    else
        log_warning "Infracost found but not authenticated"
        echo "  Configure: infracost auth login"
    fi
else
    log_warning "Infracost not found - cost analysis will be skipped"
    echo "  Install: curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh"
fi

# Step 9: Create quick test script
log_info "📝 Creating quick test commands..."

cat > "${PROJECT_ROOT}/quick-test.sh" << 'EOF'
#!/bin/bash
# Quick test execution script

echo "🚀 Running quick Prism platform test..."

# Load environment
source .env.testing

# Run basic performance test
./scripts/run-baseline-performance-test.sh quick-test

echo "✅ Quick test completed!"
echo "📊 Check results in: test-results/"
EOF

chmod +x "${PROJECT_ROOT}/quick-test.sh"
log_success "Created quick test script"

# Step 10: Final verification
log_info "✅ Running final verification..."

if [[ -x "${PROJECT_ROOT}/scripts/verify-environment.sh" ]]; then
    log_info "Running comprehensive environment check..."
    if "${PROJECT_ROOT}/scripts/verify-environment.sh"; then
        verification_passed=true
    else
        verification_passed=false
    fi
else
    log_warning "Environment verification script not found"
    verification_passed=true
fi

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        SETUP COMPLETE                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$verification_passed" == "true" ]]; then
    log_success "Environment setup completed successfully!"
    echo ""
    echo "🎯 Ready for testing! Next steps:"
    echo ""
    echo "  Quick Test (2 minutes):"
    echo "    ./quick-test.sh"
    echo ""
    echo "  Infrastructure Tests (15 minutes):"
    echo "    ./scripts/run-phase1-tests.sh --category=infrastructure"
    echo ""
    echo "  Complete Phase 1 Testing (45 minutes):"
    echo "    ./scripts/run-phase1-tests.sh"
    echo ""
    echo "  Setup Monitoring:"
    echo "    ./scripts/setup-test-monitoring.sh"
    echo ""
else
    log_warning "Environment setup completed with some issues"
    echo ""
    echo "⚠️  Some checks failed. You can still try basic testing:"
    echo ""
    echo "  Basic Test:"
    echo "    ./quick-test.sh"
    echo ""
    echo "  For optimal experience, fix the issues and run setup again."
fi

echo ""
echo "📚 Documentation:"
echo "  Environment Setup: ENVIRONMENT_SETUP.md"
echo "  Testing Guide: PHASE_1_TESTING_VALIDATION.md"
echo "  Quick Start: QUICK_START_TESTING.md"

echo ""
log_info "Setup completed at $(date)" 