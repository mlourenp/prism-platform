#!/bin/bash

# Prism Platform Telemetry Toggle Script
# Easily enable or disable telemetry collection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="prism-observability"
CONFIG_MAP="telemetry-config"
DEPLOYMENT="telemetry-agent"

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
Prism Platform Telemetry Toggle Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    enable      Enable telemetry collection
    disable     Disable telemetry collection
    status      Show current telemetry status
    privacy     Change privacy level
    config      Show current configuration
    help        Show this help message

OPTIONS:
    -n, --namespace     Kubernetes namespace (default: $NAMESPACE)
    -l, --level         Privacy level: minimal, standard, detailed
    -q, --quiet         Suppress output except errors
    -y, --yes           Skip confirmation prompts

EXAMPLES:
    $0 enable                           # Enable telemetry with current settings
    $0 disable                          # Disable telemetry
    $0 privacy --level minimal          # Change to minimal privacy level
    $0 status                           # Show current status
    $0 config                           # Show current configuration

PRIVACY LEVELS:
    minimal     Basic cluster info only (fully anonymized)
    standard    + Resource usage and workload types (anonymized)
    detailed    + Network policies and performance metrics (hashed IDs)

EOF
}

check_prerequisites() {
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is required but not found in PATH"
        exit 1
    fi

    # Check if we can connect to cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace '$NAMESPACE' does not exist"
        log_info "Please deploy Prism platform first or specify correct namespace with -n"
        exit 1
    fi

    # Check if configmap exists
    if ! kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Telemetry configuration not found in namespace '$NAMESPACE'"
        log_info "Please ensure Prism platform is deployed with telemetry agent module"
        exit 1
    fi
}

get_current_status() {
    local config_yaml
    config_yaml=$(kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' 2>/dev/null || echo "")
    
    if [ -z "$config_yaml" ]; then
        echo "unknown"
        return
    fi

    # Extract enabled status from YAML (simple grep approach)
    if echo "$config_yaml" | grep -q "enabled: true"; then
        echo "enabled"
    elif echo "$config_yaml" | grep -q "enabled: false"; then
        echo "disabled"
    else
        echo "unknown"
    fi
}

get_privacy_level() {
    local config_yaml
    config_yaml=$(kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' 2>/dev/null || echo "")
    
    if [ -z "$config_yaml" ]; then
        echo "unknown"
        return
    fi

    # Extract privacy level from YAML
    local level
    level=$(echo "$config_yaml" | grep "privacy_level:" | awk '{print $2}' | tr -d '"' | head -1)
    echo "${level:-unknown}"
}

get_cluster_id() {
    local config_yaml
    config_yaml=$(kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' 2>/dev/null || echo "")
    
    if [ -z "$config_yaml" ]; then
        echo "unknown"
        return
    fi

    # Extract cluster ID from YAML
    local cluster_id
    cluster_id=$(echo "$config_yaml" | grep "cluster_id:" | awk '{print $2}' | tr -d '"' | head -1)
    echo "${cluster_id:-unknown}"
}

enable_telemetry() {
    log_header "Enabling Telemetry"
    
    log_info "Updating telemetry configuration..."
    kubectl patch configmap "$CONFIG_MAP" -n "$NAMESPACE" \
        --patch '{"data":{"enabled":"true"}}' >/dev/null

    # Check if deployment exists and restart it
    if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Restarting telemetry agent..."
        kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
        
        log_info "Waiting for telemetry agent to be ready..."
        kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s >/dev/null
    else
        log_warning "Telemetry agent deployment not found - may need to apply Terraform configuration"
    fi

    log_success "Telemetry enabled successfully!"
    
    # Show status
    show_status
}

disable_telemetry() {
    log_header "Disabling Telemetry"
    
    log_info "Updating telemetry configuration..."
    kubectl patch configmap "$CONFIG_MAP" -n "$NAMESPACE" \
        --patch '{"data":{"enabled":"false"}}' >/dev/null

    # Check if deployment exists and restart it
    if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Restarting telemetry agent..."
        kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
        
        log_info "Waiting for telemetry agent to be ready..."
        kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s >/dev/null
    else
        log_info "Telemetry agent deployment not found - configuration updated"
    fi

    log_success "Telemetry disabled successfully!"
    
    # Show status
    show_status
}

change_privacy_level() {
    local new_level="$1"
    
    if [ -z "$new_level" ]; then
        log_error "Privacy level not specified"
        log_info "Available levels: minimal, standard, detailed"
        exit 1
    fi

    if [[ ! "$new_level" =~ ^(minimal|standard|detailed)$ ]]; then
        log_error "Invalid privacy level: $new_level"
        log_info "Available levels: minimal, standard, detailed"
        exit 1
    fi

    log_header "Changing Privacy Level to $new_level"
    
    # Note: This is a simplified approach. In a full implementation,
    # you'd want to properly update the YAML configuration
    log_warning "Privacy level changes require Terraform configuration update"
    log_info "Please update your terraform.tfvars file:"
    log_info "  telemetry_privacy_level = \"$new_level\""
    log_info "Then run: terraform apply"
}

show_status() {
    log_header "Telemetry Status"
    
    local status
    local privacy_level
    local cluster_id
    
    status=$(get_current_status)
    privacy_level=$(get_privacy_level)
    cluster_id=$(get_cluster_id)

    echo -e "${BLUE}Status:${NC}        $status"
    echo -e "${BLUE}Privacy Level:${NC} $privacy_level"
    echo -e "${BLUE}Cluster ID:${NC}    $cluster_id"
    echo -e "${BLUE}Namespace:${NC}     $NAMESPACE"
    
    # Check deployment status
    if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
        local ready_replicas
        ready_replicas=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        echo -e "${BLUE}Agent Status:${NC}  ${ready_replicas}/1 pods ready"
    else
        echo -e "${BLUE}Agent Status:${NC}  Not deployed"
    fi
    
    echo
    
    if [ "$status" = "enabled" ]; then
        echo -e "${GREEN}✓${NC} Telemetry is collecting data"
        echo -e "${GREEN}✓${NC} Data privacy level: $privacy_level"
        echo
        echo -e "${YELLOW}Data Collection Summary (Privacy Level: $privacy_level):${NC}"
        case "$privacy_level" in
            "minimal")
                echo "  ✓ Basic cluster information"
                echo "  ✓ Node count (anonymized)"
                echo "  ✗ Resource usage details"
                echo "  ✗ Workload types"
                echo "  ✗ Network policies"
                echo "  ✗ Performance metrics"
                ;;
            "standard")
                echo "  ✓ Basic cluster information"
                echo "  ✓ Node count and resource usage"
                echo "  ✓ Workload types and counts"
                echo "  ✗ Network policies"
                echo "  ✓ Performance metrics"
                ;;
            "detailed")
                echo "  ✓ Basic cluster information"
                echo "  ✓ Node count and resource usage"
                echo "  ✓ Workload types and counts"
                echo "  ✓ Network policies"
                echo "  ✓ Performance metrics"
                ;;
        esac
    elif [ "$status" = "disabled" ]; then
        echo -e "${RED}✗${NC} Telemetry is disabled"
        echo -e "${YELLOW}ℹ${NC} No data is being collected or transmitted"
    else
        echo -e "${YELLOW}?${NC} Telemetry status unknown"
    fi
}

show_config() {
    log_header "Telemetry Configuration"
    
    log_info "Current configuration:"
    kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" -o yaml
    
    echo
    log_info "Privacy summary:"
    kubectl get configmap "$CONFIG_MAP" -n "$NAMESPACE" -o jsonpath='{.data.privacy-summary\.txt}' 2>/dev/null || echo "Privacy summary not available"
}

# Parse command line arguments
QUIET=false
YES=false
COMMAND=""
PRIVACY_LEVEL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        enable|disable|status|privacy|config|help)
            COMMAND="$1"
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -l|--level)
            PRIVACY_LEVEL="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -y|--yes)
            YES=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show help if no command provided
if [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

# Handle help command
if [ "$COMMAND" = "help" ]; then
    show_help
    exit 0
fi

# Check prerequisites for all commands except help
check_prerequisites

# Execute command
case "$COMMAND" in
    "enable")
        if [ "$YES" = false ]; then
            echo -e "${YELLOW}This will enable telemetry data collection and transmission to Corrective Drift.${NC}"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        fi
        enable_telemetry
        ;;
    "disable")
        if [ "$YES" = false ]; then
            echo -e "${YELLOW}This will disable telemetry data collection.${NC}"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        fi
        disable_telemetry
        ;;
    "status")
        show_status
        ;;
    "privacy")
        change_privacy_level "$PRIVACY_LEVEL"
        ;;
    "config")
        show_config
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac 