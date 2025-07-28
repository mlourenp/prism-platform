#!/bin/bash

# Prism Platform - Environment Verification Script
# Verifies that all prerequisites are met for Phase 1 testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅]${NC} $1"; CHECKS_PASSED=$((CHECKS_PASSED + 1)); }
log_warning() { echo -e "${YELLOW}[⚠️ ]${NC} $1"; CHECKS_WARNING=$((CHECKS_WARNING + 1)); }
log_error() { echo -e "${RED}[❌]${NC} $1"; CHECKS_FAILED=$((CHECKS_FAILED + 1)); }

# Header
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║              Prism Platform v1.2 Environment Check           ║
║                     Phase 1 Testing Readiness               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Load environment variables if available
if [[ -f "${PROJECT_ROOT}/.env.testing" ]]; then
    source "${PROJECT_ROOT}/.env.testing"
    log_info "Loaded environment variables from .env.testing"
else
    log_warning ".env.testing file not found, using system defaults"
fi

# Check 1: Required Tools
echo ""
log_info "🛠️  Checking required tools..."

check_tool() {
    local tool="$1"
    local min_version="$2"
    local install_url="$3"
    
    if command -v "$tool" >/dev/null 2>&1; then
        local version=$($tool --version 2>/dev/null | head -n1 || echo "unknown")
        log_success "$tool found: $version"
        return 0
    else
        log_error "$tool not found. Install: $install_url"
        return 1
    fi
}

check_tool "terraform" ">=1.0" "https://terraform.io/downloads"
check_tool "kubectl" ">=1.28" "https://kubernetes.io/docs/tasks/tools/"
check_tool "helm" ">=3.8" "https://helm.sh/docs/intro/install/"
check_tool "jq" "any" "sudo apt-get install jq"
check_tool "curl" "any" "sudo apt-get install curl"

# Optional tools
echo ""
log_info "🔧 Checking optional tools..."

if command -v k6 >/dev/null 2>&1; then
    log_success "k6 found (performance testing enabled)"
else
    log_warning "k6 not found (performance testing will be limited)"
fi

if command -v infracost >/dev/null 2>&1; then
    log_success "infracost found (cost analysis enabled)"
else
    log_warning "infracost not found (cost analysis will be skipped)"
fi

# Check 2: Cloud Provider Access
echo ""
log_info "☁️  Checking cloud provider access..."

check_aws() {
    if command -v aws >/dev/null 2>&1; then
        if aws sts get-caller-identity >/dev/null 2>&1; then
            local account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
            local region=$(aws configure get region 2>/dev/null || echo "us-east-1")
            log_success "AWS access verified (Account: ${account}, Region: ${region})"
            return 0
        else
            log_error "AWS CLI configured but access failed. Run: aws configure"
            return 1
        fi
    else
        log_warning "AWS CLI not found. Install: https://aws.amazon.com/cli/"
        return 1
    fi
}

check_gcp() {
    if command -v gcloud >/dev/null 2>&1; then
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
            local project=$(gcloud config get-value project 2>/dev/null || echo "none")
            log_success "GCP access verified (Project: ${project})"
            return 0
        else
            log_warning "GCP CLI found but not authenticated. Run: gcloud auth login"
            return 1
        fi
    else
        log_warning "GCP CLI not found. Install: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
}

check_azure() {
    if command -v az >/dev/null 2>&1; then
        if az account show >/dev/null 2>&1; then
            local subscription=$(az account show --query name -o tsv 2>/dev/null)
            log_success "Azure access verified (Subscription: ${subscription})"
            return 0
        else
            log_warning "Azure CLI found but not authenticated. Run: az login"
            return 1
        fi
    else
        log_warning "Azure CLI not found. Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return 1
    fi
}

# Check at least one cloud provider
aws_ok=$(check_aws && echo "true" || echo "false")
gcp_ok=$(check_gcp && echo "true" || echo "false")
azure_ok=$(check_azure && echo "true" || echo "false")

if [[ "$aws_ok" == "true" || "$gcp_ok" == "true" || "$azure_ok" == "true" ]]; then
    log_success "At least one cloud provider is configured"
else
    log_error "No cloud providers are configured. Configure at least AWS, GCP, or Azure"
fi

# Check 3: Kubernetes Access
echo ""
log_info "🎛️  Checking Kubernetes access..."

if kubectl cluster-info >/dev/null 2>&1; then
    local context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    log_success "Kubernetes cluster accessible (Context: ${context}, Nodes: ${nodes})"
    
    # Check permissions
    if kubectl auth can-i create pods >/dev/null 2>&1; then
        log_success "Pod creation permission verified"
    else
        log_error "Insufficient permissions to create pods"
    fi
    
    if kubectl auth can-i create services >/dev/null 2>&1; then
        log_success "Service creation permission verified"
    else
        log_error "Insufficient permissions to create services"
    fi
    
    if kubectl auth can-i create deployments >/dev/null 2>&1; then
        log_success "Deployment creation permission verified"
    else
        log_error "Insufficient permissions to create deployments"
    fi
    
else
    log_error "Kubernetes cluster not accessible. Configure kubectl"
fi

# Check 4: Environment Variables
echo ""
log_info "🔧 Checking environment variables..."

check_env_var() {
    local var_name="$1"
    local required="$2"
    local description="$3"
    
    if [[ -n "${!var_name}" ]]; then
        log_success "${var_name} = ${!var_name}"
    else
        if [[ "$required" == "true" ]]; then
            log_error "${var_name} not set ($description)"
        else
            log_warning "${var_name} not set ($description)"
        fi
    fi
}

check_env_var "PRISM_TEST_ENVIRONMENT" "false" "Test environment identifier"
check_env_var "PRISM_TEST_REGION" "false" "Primary test region"
check_env_var "AWS_DEFAULT_REGION" "false" "AWS default region"
check_env_var "KUBECONFIG" "false" "Kubernetes config file"
check_env_var "CLEANUP_AFTER_TESTS" "false" "Whether to cleanup resources after tests"

# Check 5: Network Connectivity
echo ""
log_info "🌐 Checking network connectivity..."

check_connectivity() {
    local url="$1"
    local description="$2"
    
    if curl -s --max-time 10 "$url" >/dev/null 2>&1; then
        log_success "$description accessible"
    else
        log_error "$description not accessible ($url)"
    fi
}

check_connectivity "https://registry.terraform.io/v1/modules" "Terraform registry"
check_connectivity "https://storage.googleapis.com/kubernetes-release/release/stable.txt" "Kubernetes releases"
check_connectivity "https://api.github.com" "GitHub API"
check_connectivity "https://hub.docker.com/v2/" "Docker Hub"

# Check 6: Disk Space
echo ""
log_info "💾 Checking disk space..."

available_space=$(df . | tail -1 | awk '{print $4}')
available_gb=$((available_space / 1024 / 1024))

if [[ $available_gb -gt 10 ]]; then
    log_success "Sufficient disk space available (${available_gb}GB)"
elif [[ $available_gb -gt 5 ]]; then
    log_warning "Limited disk space available (${available_gb}GB) - consider freeing up space"
else
    log_error "Insufficient disk space (${available_gb}GB) - need at least 5GB for testing"
fi

# Check 7: Test Directory Structure
echo ""
log_info "📁 Checking test directory structure..."

check_directory() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        log_success "$description exists"
    else
        log_warning "$description missing ($dir)"
    fi
}

check_directory "${PROJECT_ROOT}/examples" "Examples directory"
check_directory "${PROJECT_ROOT}/modules" "Modules directory"
check_directory "${PROJECT_ROOT}/scripts" "Scripts directory"

# Check if test results directory exists, create if not
if [[ ! -d "${PROJECT_ROOT}/test-results" ]]; then
    mkdir -p "${PROJECT_ROOT}/test-results/phase1"
    log_success "Created test results directory"
else
    log_success "Test results directory exists"
fi

# Check 8: Cost Management (Optional)
echo ""
log_info "💰 Checking cost management setup..."

if [[ -n "$INFRACOST_API_KEY" ]]; then
    log_success "Infracost API key configured"
elif command -v infracost >/dev/null 2>&1; then
    if infracost auth status >/dev/null 2>&1; then
        log_success "Infracost authenticated"
    else
        log_warning "Infracost installed but not authenticated. Run: infracost auth login"
    fi
else
    log_warning "Infracost not configured (cost analysis will be skipped)"
fi

# Check 9: Resource Limits (if testing with existing cluster)
echo ""
log_info "📊 Checking cluster resource capacity..."

if kubectl cluster-info >/dev/null 2>&1; then
    # Get cluster resource capacity
    local total_cpu=$(kubectl describe nodes 2>/dev/null | grep "cpu:" | head -1 | awk '{print $2}' | sed 's/m//' || echo "0")
    local total_memory=$(kubectl describe nodes 2>/dev/null | grep "memory:" | head -1 | awk '{print $2}' | sed 's/Ki//' || echo "0")
    
    if [[ $total_cpu -gt 4000 ]]; then
        log_success "Sufficient CPU capacity available"
    elif [[ $total_cpu -gt 2000 ]]; then
        log_warning "Limited CPU capacity - some tests may be resource constrained"
    else
        log_warning "Very limited CPU capacity - consider using larger nodes"
    fi
    
    if [[ $total_memory -gt 8000000 ]]; then
        log_success "Sufficient memory capacity available"
    elif [[ $total_memory -gt 4000000 ]]; then
        log_warning "Limited memory capacity - some tests may be resource constrained"
    else
        log_warning "Very limited memory capacity - consider using larger nodes"
    fi
fi

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        VERIFICATION SUMMARY                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))
echo -e "Total Checks: ${total_checks}"
echo -e "${GREEN}✅ Passed: ${CHECKS_PASSED}${NC}"
echo -e "${YELLOW}⚠️  Warnings: ${CHECKS_WARNING}${NC}"
echo -e "${RED}❌ Failed: ${CHECKS_FAILED}${NC}"

echo ""

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 Environment is ready for Phase 1 testing!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. cd prism/"
    echo "2. ./scripts/setup-test-monitoring.sh"
    echo "3. ./scripts/run-phase1-tests.sh"
    exit_code=0
elif [[ $CHECKS_FAILED -le 2 ]]; then
    echo -e "${YELLOW}⚠️  Environment has minor issues but may work for basic testing${NC}"
    echo ""
    echo "Consider fixing the failed checks for optimal testing experience."
    echo "You can still try running basic tests:"
    echo "1. cd prism/"
    echo "2. ./scripts/run-baseline-performance-test.sh quick-test"
    exit_code=1
else
    echo -e "${RED}❌ Environment has significant issues and is not ready for testing${NC}"
    echo ""
    echo "Please fix the failed checks before proceeding:"
    echo "1. Install missing required tools"
    echo "2. Configure cloud provider credentials"
    echo "3. Ensure Kubernetes cluster access"
    echo "4. Create .env.testing file with required variables"
    exit_code=2
fi

echo ""
echo "For detailed setup instructions, see: ENVIRONMENT_SETUP.md"
echo "For testing documentation, see: PHASE_1_TESTING_VALIDATION.md"

exit $exit_code 