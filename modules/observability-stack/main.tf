# Prism Observability Stack Module
# Provides toggleable observability capabilities for the Prism platform

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Variables for observability stack configuration
variable "enable_prometheus" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana visualization"
  type        = bool
  default     = true
}

variable "enable_ebpf_observability" {
  description = "Enable eBPF-based observability (Cilium, Tetragon, Falco)"
  type        = bool
  default     = false
}

variable "enable_pixie" {
  description = "Enable Pixie for deep observability"
  type        = bool
  default     = false
}

variable "enable_datadog_alternative" {
  description = "Enable Datadog agent as alternative to eBPF stack"
  type        = bool
  default     = false
}

variable "enable_telemetry_agent" {
  description = "Enable telemetry agent for call-home insights"
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace for observability stack"
  type        = string
  default     = "prism-observability"
}

variable "retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 15
}

variable "storage_size" {
  description = "Storage size for time-series data"
  type        = string
  default     = "50Gi"
}

# Datadog configuration variables
variable "datadog_api_key" {
  description = "Datadog API key (required if enable_datadog_alternative is true)"
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, etc.)"
  type        = string
  default     = null
}
    
# Create namespace for observability stack
resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
    labels = {
      "prism.io/component" = "observability"
      "prism.io/managed"   = "terraform"
    }
  }
}

# Prometheus deployment
resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "51.3.0"

  values = [
    file("${path.module}/configs/prometheus-values.yaml")
  ]

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.retention_days}d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.storage_size
  }

  set {
    name  = "grafana.enabled"
    value = var.enable_grafana
      }
}

# eBPF Observability Stack
module "ebpf_stack" {
  count  = var.enable_ebpf_observability ? 1 : 0
  source = "./ebpf"
  
  namespace = var.namespace
}

# Pixie deployment
resource "helm_release" "pixie" {
  count = var.enable_pixie ? 1 : 0
  
  name       = "pixie"
  repository = "https://pixie-helm-charts.storage.googleapis.com"
  chart      = "pixie-operator-chart"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    file("${path.module}/configs/pixie-values.yaml")
  ]
}

# Datadog alternative
module "datadog_stack" {
  count  = var.enable_datadog_alternative ? 1 : 0
  source = "./datadog"
  
  namespace = var.namespace
  cluster_name = "prism-platform"  # Default cluster name
  datadog_api_key = var.datadog_api_key != null ? var.datadog_api_key : ""
  datadog_app_key = var.datadog_app_key != null ? var.datadog_app_key : ""
  site = var.datadog_site != null ? var.datadog_site : "datadoghq.com"
}

# Telemetry agent
module "telemetry_agent" {
  count  = var.enable_telemetry_agent ? 1 : 0
  source = "./telemetry"
  
  namespace = var.namespace
}

# Output important endpoints
output "prometheus_url" {
  value = var.enable_prometheus ? "http://prometheus.${var.namespace}.svc.cluster.local:9090" : null
}

output "grafana_url" {
  value = var.enable_grafana ? "http://prometheus-grafana.${var.namespace}.svc.cluster.local:80" : null
}
  
output "observability_namespace" {
  value = kubernetes_namespace.observability.metadata[0].name
} 