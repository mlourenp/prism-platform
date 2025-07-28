# Datadog Observability Stack for Prism Platform
# Alternative to eBPF-based observability with APM auto-instrumentation

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

variable "namespace" {
  description = "Namespace for Datadog components"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cluster_name" {
  description = "Kubernetes cluster name for Datadog"
  type        = string
  default     = "prism-platform"
}

variable "enable_apm" {
  description = "Enable APM and distributed tracing"
  type        = bool
  default     = true
}

variable "enable_log_collection" {
  description = "Enable log collection"
  type        = bool
  default     = true
}

variable "enable_process_agent" {
  description = "Enable process monitoring"
  type        = bool
  default     = true
}

variable "enable_system_probe" {
  description = "Enable system probe for network performance monitoring"
  type        = bool
  default     = true
}

variable "enable_security_agent" {
  description = "Enable security monitoring"
  type        = bool
  default     = true
}

variable "site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, etc.)"
  type        = string
  default     = "datadoghq.com"
}

# Create secret for Datadog credentials
resource "kubernetes_secret" "datadog_credentials" {
  metadata {
    name      = "datadog-credentials"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "datadog"
    }
  }

  data = {
    api-key = var.datadog_api_key
    app-key = var.datadog_app_key
  }

  type = "Opaque"
}

# Deploy Datadog Agent
resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = var.namespace
  version    = "3.41.0"

  values = [
    file("${path.module}/datadog-values.yaml")
  ]

  # Basic configuration
  set {
    name  = "datadog.site"
    value = var.site
  }

  set {
    name  = "datadog.clusterName"
    value = var.cluster_name
  }

  set_sensitive {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_credentials.metadata[0].name
  }

  set_sensitive {
    name  = "datadog.appKeyExistingSecret"
    value = kubernetes_secret.datadog_credentials.metadata[0].name
  }

  # APM Configuration
  set {
    name  = "datadog.apm.enabled"
    value = var.enable_apm
  }

  set {
    name  = "datadog.apm.portEnabled"
    value = var.enable_apm
  }

  set {
    name  = "datadog.apm.useSocketVolume"
    value = var.enable_apm
  }

  # Log Collection
  set {
    name  = "datadog.logs.enabled"
    value = var.enable_log_collection
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = var.enable_log_collection
  }

  # Process Agent
  set {
    name  = "datadog.processAgent.enabled"
    value = var.enable_process_agent
  }

  set {
    name  = "datadog.processAgent.processCollection"
    value = var.enable_process_agent
  }

  # System Probe (Network Performance Monitoring)
  set {
    name  = "datadog.systemProbe.enabled"
    value = var.enable_system_probe
  }

  set {
    name  = "datadog.networkMonitoring.enabled"
    value = var.enable_system_probe
  }

  # Security Agent
  set {
    name  = "datadog.securityAgent.runtime.enabled"
    value = var.enable_security_agent
  }

  set {
    name  = "datadog.securityAgent.compliance.enabled"
    value = var.enable_security_agent
  }

  # Kubernetes integration
  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = "true"
  }

  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = "true"
  }

  # Enable cluster checks
  set {
    name  = "clusterChecksRunner.enabled"
    value = "true"
  }

  # Prism-specific tags
  set {
    name  = "datadog.tags[0]"
    value = "platform:prism"
  }

  set {
    name  = "datadog.tags[1]"
    value = "environment:${var.cluster_name}"
  }
}

# Create admission controller for auto-instrumentation
resource "kubernetes_mutating_webhook_configuration" "datadog_admission_controller" {
  count = var.enable_apm ? 1 : 0

  metadata {
    name = "datadog-admission-controller"
    labels = {
      "prism.io/component" = "datadog"
    }
  }

  webhook {
    name = "datadog.admission.controller"
    
    client_config {
      service {
        name      = "datadog-admission-controller"
        namespace = var.namespace
        path      = "/injectagent"
      }
    }

    rule {
      operations   = ["CREATE"]
      api_groups   = [""]
      api_versions = ["v1"]
      resources    = ["pods"]
    }

    admission_review_versions = ["v1", "v1beta1"]
    side_effects             = "None"

    namespace_selector {
      match_expressions {
        key      = "name"
        operator = "In"
        values   = ["${var.namespace}", "data-cell", "ml-cell", "observability-cell", "prism-system"]
      }
    }
  }
}

# Create ConfigMap for auto-instrumentation settings
resource "kubernetes_config_map" "datadog_auto_instrumentation" {
  count = var.enable_apm ? 1 : 0

  metadata {
    name      = "datadog-auto-instrumentation"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "datadog"
    }
  }

  data = {
    "instrumentation.yaml" = yamlencode({
      # Auto-instrumentation for different languages
      java = {
        enabled = true
        version = "latest"
        env = {
          DD_LOGS_INJECTION = "true"
          DD_TRACE_SAMPLE_RATE = "1.0"
          DD_PROFILING_ENABLED = "true"
        }
      }
      
      python = {
        enabled = true
        version = "latest"
        env = {
          DD_LOGS_INJECTION = "true"
          DD_TRACE_SAMPLE_RATE = "1.0"
          DD_PROFILING_ENABLED = "true"
        }
      }
      
      nodejs = {
        enabled = true
        version = "latest"
        env = {
          DD_LOGS_INJECTION = "true"
          DD_TRACE_SAMPLE_RATE = "1.0"
          DD_PROFILING_ENABLED = "true"
        }
      }
      
      go = {
        enabled = true
        version = "latest"
        env = {
          DD_LOGS_INJECTION = "true"
          DD_TRACE_SAMPLE_RATE = "1.0"
          DD_PROFILING_ENABLED = "true"
        }
      }
      
      dotnet = {
        enabled = true
        version = "latest"
        env = {
          DD_LOGS_INJECTION = "true"
          DD_TRACE_SAMPLE_RATE = "1.0"
          DD_PROFILING_ENABLED = "true"
        }
      }
    })
    
    # Cell-specific configurations
    "cell-configs.yaml" = yamlencode({
      # Data cell monitoring
      data_cell = {
        metrics = ["database.queries", "data.processing.latency", "storage.usage"]
        traces = ["data.pipeline", "etl.jobs"]
        logs = ["application", "database", "system"]
      }
      
      # ML cell monitoring  
      ml_cell = {
        metrics = ["ml.inference.latency", "model.accuracy", "gpu.utilization"]
        traces = ["inference.request", "model.training"]
        logs = ["model", "inference", "training"]
      }
      
      # Observability cell monitoring
      observability_cell = {
        metrics = ["metrics.ingestion.rate", "alert.response.time"]
        traces = ["monitoring.pipeline"]
        logs = ["prometheus", "grafana", "alertmanager"]
      }
    })
  }
}

# Create custom dashboard configurations
resource "kubernetes_config_map" "datadog_dashboards" {
  metadata {
    name      = "datadog-dashboards"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "datadog"
    }
  }

  data = {
    "prism-overview.json" = file("${path.module}/dashboards/prism-overview.json")
    "cell-performance.json" = file("${path.module}/dashboards/cell-performance.json")
    "ebpf-network.json" = file("${path.module}/dashboards/ebpf-network.json")
  }
}

# Outputs
output "datadog_agent_endpoint" {
  value = "datadog.${var.namespace}.svc.cluster.local"
}

output "apm_endpoint" {
  value = var.enable_apm ? "http://datadog.${var.namespace}.svc.cluster.local:8126" : null
}

output "logs_endpoint" {
  value = var.enable_log_collection ? "datadog.${var.namespace}.svc.cluster.local:10518" : null
}

output "cluster_name" {
  value = var.cluster_name
} 