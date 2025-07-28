# Prism Infrastructure Platform - Main Configuration
# Open-core infrastructure management plane with toggleable observability

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.84"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Variables for platform configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "prism-platform"
}

variable "cloud_provider" {
  description = "Primary cloud provider (aws, gcp, azure, oracle, ibm, baremetal)"
  type        = string
  default     = "aws"
  
  validation {
    condition = contains(["aws", "gcp", "azure", "oracle", "ibm", "baremetal"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, gcp, azure, oracle, ibm, baremetal."
  }
}

variable "region" {
  description = "Primary deployment region"
  type        = string
  default     = "us-east-1"
}

# Core Platform Features - Toggle switches for "flip of a switch" observability
variable "enable_crossplane" {
  description = "Enable Crossplane for multi-cloud orchestration"
  type        = bool
  default     = true
}

variable "enable_service_mesh" {
  description = "Enable Istio service mesh with Merbridge eBPF acceleration"
  type        = bool
  default     = false
}

variable "enable_observability_stack" {
  description = "Flip of a switch: Enable comprehensive observability (Prometheus, Grafana, Alertmanager)"
  type        = bool
  default     = true
}

variable "enable_ebpf_observability" {
  description = "Enable eBPF-based observability (Cilium, Tetragon, Falco)"
  type        = bool
  default     = false
}

variable "enable_pixie" {
  description = "Enable Pixie for deep observability and debugging"
  type        = bool
  default     = false
}

variable "enable_datadog_alternative" {
  description = "Enable Datadog agent APM as alternative to eBPF (requires credentials)"
  type        = bool
  default     = false
}

variable "enable_telemetry_agent" {
  description = "Enable telemetry agent for infrastructure insights (requires consent)"
  type        = bool
  default     = false
}

variable "enable_cost_estimation" {
  description = "Enable Infracost integration for cost transparency"
  type        = bool
  default     = true
}

variable "enable_cell_deployment" {
  description = "Enable cell-based deployment patterns"
  type        = bool
  default     = true
}

# Observability configuration
variable "observability_retention_days" {
  description = "Data retention period for observability stack"
  type        = number
  default     = 15
}

variable "observability_storage_size" {
  description = "Storage size for observability data"
  type        = string
  default     = "50Gi"
}

# Telemetry configuration
variable "telemetry_privacy_level" {
  description = "Telemetry privacy level: minimal, standard, detailed"
  type        = string
  default     = "standard"
  
  validation {
    condition = contains(["minimal", "standard", "detailed"], var.telemetry_privacy_level)
    error_message = "Telemetry privacy level must be one of: minimal, standard, detailed."
  }
}

variable "telemetry_endpoint" {
  description = "Custom telemetry endpoint (optional)"
  type        = string
  default     = ""
}

variable "telemetry_reporting_interval" {
  description = "Telemetry reporting interval in minutes"
  type        = number
  default     = 60
}

variable "telemetry_api_key" {
  description = "Optional API key for premium telemetry insights (enterprise)"
  type        = string
  default     = ""
  sensitive   = true
}

# Datadog configuration (if enabled)
variable "datadog_api_key" {
  description = "Datadog API key (required if enable_datadog_alternative is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, etc.)"
  type        = string
  default     = "datadoghq.com"
}

# Common tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Platform    = "prism"
    ManagedBy   = "terraform"
    Repository  = "prism-platform"
  }
}

# Local values
locals {
  # Generate unique cluster ID for telemetry
  cluster_id = "${var.cluster_name}-${random_id.cluster_suffix.hex}"
  
  # Namespace for platform components
  platform_namespace = "prism-system"
  observability_namespace = "prism-observability"
  
  # Merged tags
  tags = merge(var.common_tags, {
    Environment   = var.environment
    CloudProvider = var.cloud_provider
    Region        = var.region
    ClusterName   = var.cluster_name
  })
}

# Generate random suffix for cluster ID
resource "random_id" "cluster_suffix" {
  byte_length = 4
}

# Create platform namespace
resource "kubernetes_namespace" "platform" {
  metadata {
    name = local.platform_namespace
    labels = merge(local.tags, {
      "prism.io/component" = "platform"
      "prism.io/managed"   = "terraform"
    })
  }
}

# Deploy Crossplane for multi-cloud orchestration
module "crossplane" {
  count  = var.enable_crossplane ? 1 : 0
  source = "./modules/crossplane-bootstrap"
  
  environment = var.environment
  name_prefix = var.cluster_name
  aws_region = var.region
  common_tags = local.tags
  
  depends_on = [kubernetes_namespace.platform]
}

# Deploy service mesh (Istio + Merbridge)
module "service_mesh" {
  count  = var.enable_service_mesh ? 1 : 0
  source = "./modules/service-mesh"
  
  environment = var.environment
  name_prefix = var.cluster_name
  region = var.region
  cloud_provider = var.cloud_provider
  common_tags = local.tags
  
  depends_on = [kubernetes_namespace.platform]
}

# Deploy comprehensive observability stack
module "observability_stack" {
  count  = var.enable_observability_stack ? 1 : 0
  source = "./modules/observability-stack"
  
  namespace = local.observability_namespace
  
  # Core observability features
  enable_prometheus = true
  enable_grafana = true
  
  # Advanced observability features (toggleable)
  enable_ebpf_observability = var.enable_ebpf_observability
  enable_pixie = var.enable_pixie
  enable_datadog_alternative = var.enable_datadog_alternative && var.datadog_api_key != ""
  enable_telemetry_agent = var.enable_telemetry_agent
  
  # Configuration
  retention_days = var.observability_retention_days
  storage_size = var.observability_storage_size
  
  # Datadog configuration (passed through if enabled)
  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key
  datadog_site = var.datadog_site
  
  depends_on = [kubernetes_namespace.platform]
}

# Deploy cell-based infrastructure patterns
module "cell_deployment" {
  count  = var.enable_cell_deployment ? 1 : 0
  source = "./modules/cell-deployment"
  
  namespace = local.platform_namespace
  environment = var.environment
  cluster_name = var.cluster_name
  cloud_provider = var.cloud_provider
  common_tags = local.tags
  
  # Feature toggles
  enable_service_mesh = var.enable_service_mesh
  enable_ebpf_policies = var.enable_ebpf_observability
  enable_observability = var.enable_observability_stack
  
  depends_on = [
    kubernetes_namespace.platform,
    module.crossplane,
    module.observability_stack
  ]
}

# Deploy telemetry agent (if enabled)
module "telemetry_agent" {
  count  = var.enable_telemetry_agent ? 1 : 0
  source = "./modules/telemetry-agent"
  
  namespace = local.observability_namespace
  enable_telemetry = var.enable_telemetry_agent
  privacy_level = var.telemetry_privacy_level
  cluster_id = local.cluster_id
  cluster_name = var.cluster_name
  environment = var.environment
  cloud_provider = var.cloud_provider
  region = var.region
  telemetry_endpoint = var.telemetry_endpoint != "" ? var.telemetry_endpoint : "https://telemetry.prism-platform.com/v1/collect"
  reporting_interval_minutes = var.telemetry_reporting_interval
  api_key = var.telemetry_api_key
  
  depends_on = [kubernetes_namespace.observability]
}

# Deploy Datadog alternative (if enabled and configured)
module "datadog_stack" {
  count  = var.enable_datadog_alternative && var.datadog_api_key != "" ? 1 : 0
  source = "./modules/observability-stack/datadog"
  
  namespace = local.observability_namespace
  cluster_name = var.cluster_name
  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key
  site = var.datadog_site
  
  # Enable all Datadog features
  enable_apm = true
  enable_log_collection = true
  enable_process_agent = true
  enable_system_probe = true
  enable_security_agent = true
  
  depends_on = [kubernetes_namespace.platform]
}

# Cost estimation with Infracost (if enabled)
resource "null_resource" "infracost_integration" {
  count = var.enable_cost_estimation ? 1 : 0
  
  triggers = {
    environment = var.environment
    cloud_provider = var.cloud_provider
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Infracost integration enabled for cost transparency"
      echo "Cloud Provider: ${var.cloud_provider}"
      echo "Environment: ${var.environment}"
      echo "Estimated monthly cost will be calculated post-deployment"
    EOT
  }
}

# Outputs
output "platform_info" {
  description = "Prism platform information"
  value = {
    cluster_name = var.cluster_name
    environment = var.environment
    cloud_provider = var.cloud_provider
    region = var.region
    cluster_id = local.cluster_id
    platform_namespace = local.platform_namespace
    observability_namespace = local.observability_namespace
  }
}

output "enabled_features" {
  description = "Enabled platform features"
  value = {
    crossplane = var.enable_crossplane
    service_mesh = var.enable_service_mesh
    observability_stack = var.enable_observability_stack
    ebpf_observability = var.enable_ebpf_observability
    pixie = var.enable_pixie
    datadog_alternative = var.enable_datadog_alternative
    telemetry_agent = var.enable_telemetry_agent
    cost_estimation = var.enable_cost_estimation
    cell_deployment = var.enable_cell_deployment
  }
}

output "endpoints" {
  description = "Platform service endpoints"
  value = {
    prometheus_url = var.enable_observability_stack ? "http://prometheus.${local.observability_namespace}.svc.cluster.local:9090" : null
    grafana_url = var.enable_observability_stack ? "http://prometheus-grafana.${local.observability_namespace}.svc.cluster.local:80" : null
    datadog_endpoint = var.enable_datadog_alternative && var.datadog_api_key != "" ? "datadog.${local.observability_namespace}.svc.cluster.local" : null
    telemetry_endpoint = var.enable_telemetry_agent ? "telemetry-agent.${local.observability_namespace}.svc.cluster.local" : null
  }
}

output "access_instructions" {
  description = "Instructions for accessing platform services"
  value = var.enable_observability_stack ? {
    grafana = "kubectl port-forward -n ${local.observability_namespace} svc/prometheus-grafana 3000:80"
    prometheus = "kubectl port-forward -n ${local.observability_namespace} svc/prometheus 9090:9090"
    alertmanager = "kubectl port-forward -n ${local.observability_namespace} svc/prometheus-alertmanager 9093:9093"
  } : {}
} 