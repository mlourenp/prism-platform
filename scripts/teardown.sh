#!/bin/bash

# Prism Platform Teardown Script
# Comprehensive cleanup and resource management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRISM_DIR="$(dirname "$SCRIPT_DIR")"
FORCE_CLEANUP=false
SKIP_CONFIRMATION=false
CLEANUP_SAMPLES_ONLY=false
PRESERVE_DATA=false
DRY_RUN=false

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

log_header() {
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC} $1 ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────╯${NC}"
}

show_help() {
    cat << EOF
Prism Platform Teardown Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Force cleanup even if errors occur
    -y, --yes               Skip confirmation prompts
    -n, --dry-run           Show what would be done without executing
    --samples-only          Only cleanup sample cells, preserve platform
    --preserve-data         Preserve persistent volumes and data
    --complete              Complete cleanup including all resources

EXAMPLES:
    # Interactive teardown with confirmations
    $0

    # Force cleanup without prompts
    $0 --force --yes

    # Dry run to see what would be removed
    $0 --dry-run

    # Only remove sample cells
    $0 --samples-only

    # Complete cleanup preserving data
    $0 --preserve-data --yes

EOF
}

confirm_action() {
    local message="$1"
    
    if [[ "$SKIP_CONFIRMATION" == "true" ]]; then
        log_info "Auto-confirming: $message"
        return 0
    fi
    
    log_warning "$message"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Operation cancelled"
        return 1
    fi
    return 0
}

check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check required tools
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes
    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Cannot connect to Kubernetes cluster"
        log_info "Some cleanup operations may not be possible"
    else
        log_success "Connected to Kubernetes cluster"
    fi
    
    # Check if Terraform state exists
    cd "$PRISM_DIR"
    if [[ ! -f "terraform.tfstate" && ! -f ".terraform/terraform.tfstate" ]]; then
        log_warning "No Terraform state found"
        log_info "Only Kubernetes-based cleanup will be performed"
    else
        log_info "Terraform state found"
    fi
}

cleanup_sample_cells() {
    log_header "Cleaning Up Sample Cells"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would cleanup sample cells"
        return 0
    fi
    
    # List of sample cell namespaces
    local sample_namespaces=(
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
    
    for namespace in "${sample_namespaces[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            log_info "Removing namespace: $namespace"
            
            if [[ "$PRESERVE_DATA" == "true" ]]; then
                # Delete deployments and services but preserve PVCs
                kubectl delete deployments,services,configmaps,secrets -n "$namespace" --all --ignore-not-found=true
                log_info "Preserved persistent volumes in $namespace"
            else
                # Delete entire namespace
                kubectl delete namespace "$namespace" --ignore-not-found=true
            fi
            
            log_success "Cleaned up $namespace"
        else
            log_info "Namespace $namespace not found, skipping"
        fi
    done
    
    if [[ "$CLEANUP_SAMPLES_ONLY" == "true" ]]; then
        log_success "Sample cells cleanup completed"
        return 0
    fi
}

cleanup_terraform_resources() {
    log_header "Cleaning Up Terraform Resources"
    
    cd "$PRISM_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute terraform destroy"
        if [[ -f "terraform.tfstate" || -f ".terraform/terraform.tfstate" ]]; then
            terraform plan -destroy
        fi
        return 0
    fi
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" && ! -f ".terraform/terraform.tfstate" ]]; then
        log_warning "No Terraform state found, skipping Terraform cleanup"
        return 0
    fi
    
    # Initialize Terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init
    fi
    
    # Show destroy plan
    log_info "Planning Terraform destroy..."
    if ! terraform plan -destroy -out=destroy-plan; then
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_warning "Terraform plan failed, but continuing with force cleanup"
        else
            log_error "Terraform plan failed"
            return 1
        fi
    fi
    
    # Execute destroy
    log_info "Executing Terraform destroy..."
    if terraform apply destroy-plan; then
        log_success "Terraform resources destroyed successfully"
    else
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_warning "Terraform destroy failed, but continuing with force cleanup"
        else
            log_error "Terraform destroy failed"
            return 1
        fi
    fi
    
    # Clean up plan file
    rm -f destroy-plan
}

cleanup_kubernetes_resources() {
    log_header "Cleaning Up Kubernetes Resources"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would cleanup Kubernetes resources"
        kubectl get namespaces | grep -E "(prism|observability)" || true
        return 0
    fi
    
    # Platform namespaces to clean up
    local platform_namespaces=(
        "prism-system"
        "prism-observability"
        "crossplane-system"
        "istio-system"
        "cilium-system"
        "tetragon-system"
        "falco-system"
        "monitoring"
    )
    
    for namespace in "${platform_namespaces[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            log_info "Cleaning up namespace: $namespace"
            
            if [[ "$PRESERVE_DATA" == "true" && "$namespace" =~ (observability|monitoring) ]]; then
                # Preserve monitoring data
                kubectl delete deployments,services,configmaps,secrets -n "$namespace" --all --ignore-not-found=true
                log_info "Preserved data in $namespace"
            else
                # Force delete if stuck
                if [[ "$FORCE_CLEANUP" == "true" ]]; then
                    kubectl delete namespace "$namespace" --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
                else
                    kubectl delete namespace "$namespace" --ignore-not-found=true
                fi
            fi
            
            log_success "Cleaned up $namespace"
        fi
    done
    
    # Clean up CRDs if force cleanup
    if [[ "$FORCE_CLEANUP" == "true" ]]; then
        log_info "Force cleaning up CRDs..."
        
        # Remove Crossplane CRDs
        kubectl get crd | grep crossplane.io | awk '{print $1}' | xargs kubectl delete crd --ignore-not-found=true 2>/dev/null || true
        
        # Remove Istio CRDs
        kubectl get crd | grep istio.io | awk '{print $1}' | xargs kubectl delete crd --ignore-not-found=true 2>/dev/null || true
        
        # Remove Cilium CRDs
        kubectl get crd | grep cilium.io | awk '{print $1}' | xargs kubectl delete crd --ignore-not-found=true 2>/dev/null || true
        
        # Remove monitoring CRDs
        kubectl get crd | grep monitoring.coreos.com | awk '{print $1}' | xargs kubectl delete crd --ignore-not-found=true 2>/dev/null || true
        
        log_info "CRDs cleanup completed"
    fi
}

cleanup_local_files() {
    log_header "Cleaning Up Local Files"
    
    cd "$PRISM_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would cleanup local files"
        find . -name "terraform.tfstate*" -o -name ".terraform" -o -name "tfplan" | head -10
        return 0
    fi
    
    # Remove Terraform state and cache
    log_info "Removing Terraform state and cache..."
    rm -f terraform.tfstate*
    rm -f tfplan destroy-plan
    rm -rf .terraform
    
    # Remove generated configs (ask for confirmation)
    if [[ -f "terraform.tfvars" ]]; then
        if confirm_action "Remove generated terraform.tfvars?"; then
            rm -f terraform.tfvars
            log_info "Removed terraform.tfvars"
        fi
    fi
    
    # Remove log files
    find . -name "*.log" -delete 2>/dev/null || true
    
    log_success "Local files cleaned up"
}

show_remaining_resources() {
    log_header "Checking Remaining Resources"
    
    log_info "Remaining namespaces with 'prism' or 'observability':"
    kubectl get namespaces | grep -E "(prism|observability)" || log_info "None found"
    
    echo
    log_info "Remaining PVCs (if preserve-data was used):"
    kubectl get pvc --all-namespaces | grep -E "(prism|observability)" || log_info "None found"
    
    echo
    log_info "Remaining CRDs:"
    kubectl get crd | grep -E "(crossplane|istio|cilium|monitoring)" | wc -l | xargs echo "Count:" || log_info "None found"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_CLEANUP=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --samples-only)
            CLEANUP_SAMPLES_ONLY=true
            shift
            ;;
        --preserve-data)
            PRESERVE_DATA=true
            shift
            ;;
        --complete)
            FORCE_CLEANUP=true
            SKIP_CONFIRMATION=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_header "Prism Platform Teardown"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    if [[ "$FORCE_CLEANUP" == "true" ]]; then
        log_warning "FORCE CLEANUP MODE - Errors will be ignored"
    fi
    
    if [[ "$PRESERVE_DATA" == "true" ]]; then
        log_info "PRESERVE DATA MODE - Persistent volumes will be kept"
    fi
    
    # Execute cleanup steps
    check_prerequisites
    
    if [[ "$CLEANUP_SAMPLES_ONLY" == "true" ]]; then
        if confirm_action "This will remove all sample cells but preserve the platform"; then
            cleanup_sample_cells
        fi
    else
        if confirm_action "This will completely remove the Prism platform and all its resources"; then
            cleanup_sample_cells
            cleanup_terraform_resources || true
            cleanup_kubernetes_resources || true
            cleanup_local_files
        fi
    fi
    
    show_remaining_resources
    
    log_success "Prism Platform teardown completed!"
    
    if [[ "$PRESERVE_DATA" == "true" ]]; then
        log_info "Data has been preserved as requested"
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Platform has been removed from your cluster"
    fi
}

# Execute main function
main "$@" 