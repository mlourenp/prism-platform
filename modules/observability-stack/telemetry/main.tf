# Prism Telemetry Agent Module
# Provides optional call-home telemetry for infrastructure insights and benchmarking

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

variable "namespace" {
  description = "Namespace for telemetry agent"
  type        = string
}

variable "enable_call_home" {
  description = "Enable call-home telemetry (requires user consent)"
  type        = bool
  default     = false
}

variable "telemetry_endpoint" {
  description = "Telemetry collection endpoint"
  type        = string
  default     = "https://telemetry.prism-platform.io/v1/metrics"
}

variable "cluster_id" {
  description = "Unique cluster identifier (auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "reporting_interval" {
  description = "Telemetry reporting interval in minutes"
  type        = number
  default     = 60
}

variable "data_privacy_level" {
  description = "Privacy level: minimal, standard, detailed"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["minimal", "standard", "detailed"], var.data_privacy_level)
    error_message = "Privacy level must be one of: minimal, standard, detailed."
  }
}

# Create ConfigMap for telemetry configuration
resource "kubernetes_config_map" "telemetry_config" {
  metadata {
    name      = "telemetry-config"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "telemetry"
      "prism.io/managed"   = "terraform"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      telemetry = {
        enabled = var.enable_call_home
        endpoint = var.telemetry_endpoint
        cluster_id = var.cluster_id != "" ? var.cluster_id : uuidv4()
        reporting_interval_minutes = var.reporting_interval
        privacy_level = var.data_privacy_level
        
        # Define what data to collect based on privacy level
        collection_rules = {
          minimal = {
            collect_cluster_info = true
            collect_node_count = true
            collect_resource_usage = false
            collect_workload_types = false
            collect_network_policies = false
            anonymize_data = true
          }
          standard = {
            collect_cluster_info = true
            collect_node_count = true
            collect_resource_usage = true
            collect_workload_types = true
            collect_network_policies = false
            anonymize_data = true
          }
          detailed = {
            collect_cluster_info = true
            collect_node_count = true
            collect_resource_usage = true
            collect_workload_types = true
            collect_network_policies = true
            anonymize_data = false
          }
        }
        
        # User consent tracking
        consent = {
          timestamp = timestamp()
          version = "1.0"
          privacy_policy_url = "https://prism-platform.io/privacy"
        }
      }
      
      # Metrics collection configuration
      metrics = {
        # Infrastructure metrics
        infrastructure = [
          "cluster_version",
          "node_count",
          "total_cpu_cores",
          "total_memory_gb",
          "cloud_provider",
          "kubernetes_distribution"
        ]
        
        # Platform usage metrics
        platform_usage = [
          "cells_deployed",
          "cell_types_used",
          "observability_stack_enabled",
          "ebpf_features_enabled",
          "crossplane_providers_used"
        ]
        
        # Performance benchmarks (anonymized)
        performance = [
          "average_pod_startup_time",
          "network_latency_p95",
          "storage_iops_average",
          "cost_efficiency_score"
        ]
      }
    })
  }
}

# Create ServiceAccount for telemetry agent
resource "kubernetes_service_account" "telemetry_agent" {
  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "telemetry"
    }
  }
}

# Create ClusterRole for telemetry data collection
resource "kubernetes_cluster_role" "telemetry_reader" {
  metadata {
    name = "prism-telemetry-reader"
    labels = {
      "prism.io/component" = "telemetry"
    }
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "namespaces",
      "pods",
      "services",
      "endpoints"
    ]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources = [
      "deployments",
      "replicasets",
      "daemonsets",
      "statefulsets"
    ]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources = ["nodes", "pods"]
    verbs = ["get", "list"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources = ["customresourcedefinitions"]
    verbs = ["get", "list"]
  }
}

# Bind telemetry agent to cluster role
resource "kubernetes_cluster_role_binding" "telemetry_agent" {
  metadata {
    name = "prism-telemetry-agent"
    labels = {
      "prism.io/component" = "telemetry"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.telemetry_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.telemetry_agent.metadata[0].name
    namespace = var.namespace
  }
}

# Deploy telemetry agent
resource "kubernetes_deployment" "telemetry_agent" {
  count = var.enable_call_home ? 1 : 0

  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "telemetry"
      "app.kubernetes.io/name" = "telemetry-agent"
      "app.kubernetes.io/part-of" = "prism-platform"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "telemetry-agent"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "telemetry-agent"
          "prism.io/component" = "telemetry"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port" = "8080"
          "prometheus.io/path" = "/metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.telemetry_agent.metadata[0].name
        
        container {
          name  = "telemetry-agent"
          image = "prism-platform/telemetry-agent:v1.0.0"
          
          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }
          
          env {
            name = "CONFIG_PATH"
            value = "/etc/telemetry/config.yaml"
          }
          
          env {
            name = "LOG_LEVEL"
            value = "INFO"
          }
          
          env {
            name = "CLUSTER_NAME"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          
          volume_mount {
            name       = "config"
            mount_path = "/etc/telemetry"
            read_only  = true
          }
          
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
          
          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
        
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.telemetry_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Create Service for telemetry agent
resource "kubernetes_service" "telemetry_agent" {
  count = var.enable_call_home ? 1 : 0

  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "prism.io/component" = "telemetry"
      "app.kubernetes.io/name" = "telemetry-agent"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port" = "8080"
      "prometheus.io/path" = "/metrics"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "telemetry-agent"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Create ServiceMonitor for telemetry agent metrics
resource "kubernetes_manifest" "telemetry_servicemonitor" {
  count = var.enable_call_home ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "telemetry-agent"
      namespace = var.namespace
      labels = {
        "prism.io/monitoring" = "enabled"
        "prism.io/component" = "telemetry"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "telemetry-agent"
        }
      }
      endpoints = [{
        port = "http"
        interval = "60s"
        path = "/metrics"
      }]
    }
  }
}

# Outputs
output "telemetry_enabled" {
  value = var.enable_call_home
}

output "telemetry_endpoint" {
  value = var.enable_call_home ? kubernetes_service.telemetry_agent[0].metadata[0].name : null
}

output "cluster_id" {
  value = var.cluster_id != "" ? var.cluster_id : uuidv4()
  sensitive = true
}

output "privacy_level" {
  value = var.data_privacy_level
} 