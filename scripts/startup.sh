#!/bin/bash

# Prism Platform Startup Script
# Comprehensive deployment and configuration management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRISM_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE=""
DEPLOY_SAMPLES=false
SKIP_CHECKS=false
ENVIRONMENT="dev"
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
Prism Platform Startup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Use custom Terraform variables file
    -s, --deploy-samples    Deploy sample cells after platform setup
    -e, --environment ENV   Environment name (dev, staging, prod) [default: dev]
    -n, --dry-run          Show what would be done without executing
    --skip-checks          Skip prerequisite checks
    --minimal              Deploy minimal stack (no observability)
    --full-stack           Deploy full stack with all features
    --datadog-stack        Deploy with Datadog instead of built-in observability
    --ebpf-only            Deploy with eBPF observability only

EXAMPLES:
    # Basic development deployment
    $0

    # Production deployment with custom config
    $0 --config production.tfvars --environment prod

    # Full stack with sample cells
    $0 --full-stack --deploy-samples

    # Datadog integration
    $0 --datadog-stack --config datadog.tfvars

    # Minimal deployment for testing
    $0 --minimal --skip-checks

EOF
}

check_prerequisites() {
    if [[ "$SKIP_CHECKS" == "true" ]]; then
        log_info "Skipping prerequisite checks"
        return 0
    fi

    log_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
    
    # Check Kubernetes connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Cannot connect to Kubernetes cluster"
        log_info "Please ensure kubectl is configured and you have access to a cluster"
        exit 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $tf_version"
    
    # Check Kubernetes version
    local k8s_version=$(kubectl version --client=true -o json | jq -r '.clientVersion.gitVersion')
    log_info "kubectl version: $k8s_version"
    
    # Check Helm version
    local helm_version=$(helm version --short)
    log_info "Helm version: $helm_version"
    
    log_success "All prerequisites met"
}

detect_environment() {
    log_header "Environment Detection"
    
    # Try to detect cloud provider
    local cloud_provider="unknown"
    
    # Check if running on AWS
    if curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id &> /dev/null; then
        cloud_provider="aws"
    # Check if running on GCP
    elif curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id &> /dev/null; then
        cloud_provider="gcp"
    # Check if running on Azure
    elif curl -s --max-time 5 -H "Metadata: true" http://169.254.169.254/metadata/instance?api-version=2021-02-01 &> /dev/null; then
        cloud_provider="azure"
    fi
    
    log_info "Detected cloud provider: $cloud_provider"
    log_info "Target environment: $ENVIRONMENT"
    
    # Check cluster context
    local current_context=$(kubectl config current-context)
    log_info "Current kubectl context: $current_context"
    
    # Warn if production environment
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_warning "Deploying to PRODUCTION environment!"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi
}

create_terraform_config() {
    log_header "Creating Terraform Configuration"
    
    cd "$PRISM_DIR"
    
    # Create terraform.tfvars if it doesn't exist
    if [[ ! -f "terraform.tfvars" && -z "$CONFIG_FILE" ]]; then
        log_info "Creating default terraform.tfvars"
        
        cat > terraform.tfvars << EOF
# Prism Platform Configuration
# Generated by startup script on $(date)

# Environment configuration
environment = "$ENVIRONMENT"
cluster_name = "prism-$ENVIRONMENT"

# Feature toggles (adjust as needed)
enable_crossplane = true
enable_observability_stack = true
enable_cell_deployment = true
enable_cost_estimation = true

# Observability configuration
observability_retention_days = 15
observability_storage_size = "50Gi"

# Advanced features (disabled by default)
enable_service_mesh = false
enable_ebpf_observability = false
enable_pixie = false
enable_datadog_alternative = false
enable_telemetry_agent = false

# Telemetry configuration (if enabled)
telemetry_privacy_level = "standard"

# Common tags
common_tags = {
  Environment = "$ENVIRONMENT"
  Platform    = "prism"
  ManagedBy   = "terraform"
  DeployedBy  = "startup-script"
}
EOF
        CONFIG_FILE="terraform.tfvars"
        log_success "Created default configuration: terraform.tfvars"
    elif [[ -n "$CONFIG_FILE" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "Configuration file not found: $CONFIG_FILE"
            exit 1
        fi
        log_info "Using configuration file: $CONFIG_FILE"
    else
        log_info "Using existing terraform.tfvars"
        CONFIG_FILE="terraform.tfvars"
    fi
}

setup_deployment_profiles() {
    log_header "Setting Up Deployment Profile"
    
    case "$1" in
        "minimal")
            log_info "Configuring minimal deployment profile"
            cat >> "$CONFIG_FILE" << EOF

# Minimal deployment profile
enable_observability_stack = false
enable_service_mesh = false
enable_ebpf_observability = false
enable_pixie = false
enable_datadog_alternative = false
enable_telemetry_agent = false
EOF
            ;;
        "full-stack")
            log_info "Configuring full-stack deployment profile"
            cat >> "$CONFIG_FILE" << EOF

# Full-stack deployment profile
enable_observability_stack = true
enable_service_mesh = true
enable_ebpf_observability = true
enable_pixie = false  # Can be resource intensive
enable_datadog_alternative = false
enable_telemetry_agent = false
observability_retention_days = 30
observability_storage_size = "100Gi"
EOF
            ;;
        "datadog-stack")
            log_info "Configuring Datadog deployment profile"
            cat >> "$CONFIG_FILE" << EOF

# Datadog deployment profile
enable_observability_stack = false
enable_datadog_alternative = true
enable_service_mesh = true
enable_ebpf_observability = false  # Avoid conflicts with Datadog
enable_pixie = false
enable_telemetry_agent = false

# Note: You must set datadog_api_key and datadog_app_key
# datadog_api_key = "your-datadog-api-key"
# datadog_app_key = "your-datadog-app-key"
EOF
            log_warning "Remember to set your Datadog API keys in the configuration file!"
            ;;
        "ebpf-only")
            log_info "Configuring eBPF-only deployment profile"
            cat >> "$CONFIG_FILE" << EOF

# eBPF-only deployment profile
enable_observability_stack = false
enable_service_mesh = true
enable_ebpf_observability = true
enable_pixie = true
enable_datadog_alternative = false
enable_telemetry_agent = false
EOF
            ;;
    esac
}

deploy_platform() {
    log_header "Deploying Prism Platform"
    
    cd "$PRISM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    if ! terraform init; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    if ! terraform validate; then
        log_error "Terraform validation failed"
        exit 1
    fi
    
    # Plan deployment
    log_info "Planning deployment..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute terraform plan"
        terraform plan -var-file="$CONFIG_FILE"
        return 0
    fi
    
    if ! terraform plan -var-file="$CONFIG_FILE" -out=tfplan; then
        log_error "Terraform planning failed"
        exit 1
    fi
    
    # Apply deployment
    log_info "Applying deployment..."
    if ! terraform apply tfplan; then
        log_error "Terraform apply failed"
        exit 1
    fi
    
    log_success "Platform deployment completed!"
    
    # Clean up plan file
    rm -f tfplan
}

deploy_sample_cells() {
    if [[ "$DEPLOY_SAMPLES" != "true" ]]; then
        return 0
    fi
    
    log_header "Deploying Sample Cells"
    
    local sample_script="$SCRIPT_DIR/deploy-sample-cells.sh"
    
    if [[ -f "$sample_script" ]]; then
        log_info "Executing sample cells deployment..."
        if bash "$sample_script"; then
            log_success "Sample cells deployed successfully!"
        else
            log_warning "Sample cells deployment had issues, but platform is still functional"
        fi
    else
        log_warning "Sample cells deployment script not found: $sample_script"
    fi
}

show_access_information() {
    log_header "Platform Access Information"
    
    cd "$PRISM_DIR"
    
    # Get platform information from Terraform outputs
    if terraform output platform_info &> /dev/null; then
        log_info "Platform Information:"
        terraform output -json platform_info | jq -r 'to_entries[] | "  \(.key): \(.value)"'
        echo
    fi
    
    if terraform output enabled_features &> /dev/null; then
        log_info "Enabled Features:"
        terraform output -json enabled_features | jq -r 'to_entries[] | select(.value == true) | "  ✓ \(.key)"'
        echo
    fi
    
    if terraform output access_instructions &> /dev/null; then
        log_info "Access Instructions:"
        terraform output -json access_instructions | jq -r 'to_entries[] | "  \(.key): \(.value)"'
        echo
    fi
    
    log_info "Common Commands:"
    echo "  # Access Grafana (if enabled):"
    echo "    kubectl port-forward -n prism-observability svc/prometheus-grafana 3000:80"
    echo ""
    echo "  # Access Prometheus (if enabled):"
    echo "    kubectl port-forward -n prism-observability svc/prometheus 9090:9090"
    echo ""
    echo "  # Check platform status:"
    echo "    kubectl get all -n prism-system"
    echo ""
    echo "  # View sample cells (if deployed):"
    echo "    kubectl get namespaces | grep -cell"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--deploy-samples)
            DEPLOY_SAMPLES=true
            shift
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --minimal)
            DEPLOYMENT_PROFILE="minimal"
            shift
            ;;
        --full-stack)
            DEPLOYMENT_PROFILE="full-stack"
            shift
            ;;
        --datadog-stack)
            DEPLOYMENT_PROFILE="datadog-stack"
            shift
            ;;
        --ebpf-only)
            DEPLOYMENT_PROFILE="ebpf-only"
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
    log_header "Prism Platform Startup"
    
    log_info "Starting Prism Platform deployment..."
    log_info "Environment: $ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Execute deployment steps
    check_prerequisites
    detect_environment
    create_terraform_config
    
    if [[ -n "$DEPLOYMENT_PROFILE" ]]; then
        setup_deployment_profiles "$DEPLOYMENT_PROFILE"
    fi
    
    deploy_platform
    deploy_sample_cells
    show_access_information
    
    log_success "Prism Platform startup completed successfully!"
    log_info "Your platform is ready for use."
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_warning "Remember to review and adjust resource limits for production workloads"
    fi
}

# Execute main function
main "$@" 