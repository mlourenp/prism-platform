# Prism Telemetry Agent Module
# Provides optional call-home telemetry for infrastructure insights and optimization recommendations

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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

variable "namespace" {
  description = "Namespace for telemetry agent deployment"
  type        = string
  default     = "prism-observability"
}

variable "enable_telemetry" {
  description = "Enable telemetry data collection and transmission"
  type        = bool
  default     = false
}

variable "privacy_level" {
  description = "Data privacy level: minimal, standard, detailed"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["minimal", "standard", "detailed"], var.privacy_level)
    error_message = "Privacy level must be one of: minimal, standard, detailed."
  }
}

variable "telemetry_endpoint" {
  description = "Corrective Drift telemetry collection endpoint"
  type        = string
  default     = "https://telemetry.prism-platform.com/v1/collect"
}

variable "cluster_id" {
  description = "Unique cluster identifier (auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Human-readable cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure, oracle, ibm, baremetal)"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "reporting_interval_minutes" {
  description = "Telemetry reporting interval in minutes"
  type        = number
  default     = 60
}

variable "api_key" {
  description = "Optional API key for premium insights (enterprise users)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "local_retention_days" {
  description = "Days to retain telemetry data locally"
  type        = number
  default     = 7
}

# Generate unique cluster ID if not provided
resource "random_uuid" "cluster_id" {
  count = var.cluster_id == "" ? 1 : 0
}

locals {
  cluster_id = var.cluster_id != "" ? var.cluster_id : random_uuid.cluster_id[0].result
  
  # Privacy level configurations
  privacy_configs = {
    minimal = {
      collect_cluster_info = true
      collect_node_metrics = true
      collect_resource_usage = false
      collect_workload_types = false
      collect_network_policies = false
      collect_performance_metrics = false
      anonymize_data = true
      hash_identifiers = true
    }
    standard = {
      collect_cluster_info = true
      collect_node_metrics = true
      collect_resource_usage = true
      collect_workload_types = true
      collect_network_policies = false
      collect_performance_metrics = true
      anonymize_data = true
      hash_identifiers = true
    }
    detailed = {
      collect_cluster_info = true
      collect_node_metrics = true
      collect_resource_usage = true
      collect_workload_types = true
      collect_network_policies = true
      collect_performance_metrics = true
      anonymize_data = false
      hash_identifiers = true
    }
  }
  
  current_privacy_config = local.privacy_configs[var.privacy_level]
}

# Create ConfigMap for telemetry configuration
resource "kubernetes_config_map" "telemetry_config" {
  metadata {
    name      = "telemetry-config"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "telemetry-agent"
      "app.kubernetes.io/component"  = "telemetry"
      "app.kubernetes.io/managed-by" = "terraform"
      "prism.io/component"           = "telemetry"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      telemetry = {
        enabled = var.enable_telemetry
        endpoint = var.telemetry_endpoint
        cluster_id = local.cluster_id
        cluster_name = var.cluster_name
        environment = var.environment
        cloud_provider = var.cloud_provider
        region = var.region
        privacy_level = var.privacy_level
        reporting_interval_minutes = var.reporting_interval_minutes
        local_retention_days = var.local_retention_days
        
        # Collection rules based on privacy level
        collection = local.current_privacy_config
        
        # Consent tracking
        consent = {
          timestamp = timestamp()
          version = "1.0"
          privacy_policy_url = "https://prism-platform.com/privacy"
          terms_url = "https://prism-platform.com/terms"
        }
        
        # Transmission settings
        transmission = {
          batch_size = 100
          flush_interval_seconds = 300
          max_retries = 3
          retry_backoff_seconds = 30
          timeout_seconds = 30
          compression = "gzip"
        }
      }
      
      # Define metrics to collect
      metrics = {
        infrastructure = [
          "kubernetes_version",
          "cluster_node_count",
          "total_cpu_cores", 
          "total_memory_gb",
          "total_storage_gb",
          "kubernetes_distribution",
          "container_runtime",
          "cni_plugin"
        ]
        
        platform_usage = [
          "prism_version",
          "cells_deployed_count",
          "cell_types_active",
          "crossplane_enabled",
          "service_mesh_enabled", 
          "observability_stack_enabled",
          "ebpf_features_enabled",
          "crossplane_providers_count",
          "custom_resources_count"
        ]
        
        performance = [
          "average_pod_startup_time_seconds",
          "network_latency_p50_ms",
          "network_latency_p95_ms", 
          "storage_iops_average",
          "cpu_utilization_average",
          "memory_utilization_average",
          "cost_efficiency_score"
        ]
        
        workloads = [
          "deployment_count",
          "statefulset_count", 
          "daemonset_count",
          "job_count",
          "cronjob_count",
          "service_count",
          "ingress_count"
        ]
      }
    })
    
    # Privacy policy summary
    "privacy-summary.txt" = <<-EOT
Prism Telemetry Agent - Privacy Summary

Privacy Level: ${var.privacy_level}
Data Collection: ${var.enable_telemetry ? "Enabled" : "Disabled"}
Anonymization: ${local.current_privacy_config.anonymize_data ? "Enabled" : "Disabled"}

What we collect:
${local.current_privacy_config.collect_cluster_info ? "✓" : "✗"} Basic cluster information (K8s version, node count)
${local.current_privacy_config.collect_resource_usage ? "✓" : "✗"} Resource usage metrics (CPU, memory, storage)
${local.current_privacy_config.collect_workload_types ? "✓" : "✗"} Workload types and counts
${local.current_privacy_config.collect_network_policies ? "✓" : "✗"} Network policy configurations
${local.current_privacy_config.collect_performance_metrics ? "✓" : "✗"} Performance benchmarks

What we NEVER collect:
✗ Application source code or data
✗ Secrets, passwords, or credentials
✗ Personal or sensitive information
✗ Application logs or user data

Data Use:
• Infrastructure optimization recommendations
• Community performance benchmarks
• Platform improvement insights
• Anomaly and drift detection

Your Rights:
• Opt-out at any time
• Request data deletion
• Change privacy level
• View collected data

For more information: https://prism-platform.com/privacy
EOT
  }
}

# Create Secret for API credentials (if provided)
resource "kubernetes_secret" "telemetry_credentials" {
  count = var.api_key != "" ? 1 : 0
  
  metadata {
    name      = "telemetry-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "telemetry-agent"
      "app.kubernetes.io/component"  = "telemetry"
    }
  }

  data = {
    api_key = var.api_key
  }
  
  type = "Opaque"
}

# Create ServiceAccount for telemetry agent
resource "kubernetes_service_account" "telemetry_agent" {
  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "telemetry-agent"
      "app.kubernetes.io/component"  = "telemetry"
    }
  }
}

# Create ClusterRole for telemetry data collection
resource "kubernetes_cluster_role" "telemetry_reader" {
  metadata {
    name = "prism-telemetry-reader"
    labels = {
      "app.kubernetes.io/name"      = "telemetry-agent"
      "app.kubernetes.io/component" = "telemetry"
    }
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "namespaces", 
      "pods",
      "services",
      "endpoints",
      "persistentvolumes",
      "persistentvolumeclaims"
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
    api_groups = ["batch"]
    resources = ["jobs", "cronjobs"]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources = ["ingresses", "networkpolicies"]
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
  
  # Crossplane resources
  rule {
    api_groups = ["pkg.crossplane.io"]
    resources = ["providers", "configurations"]
    verbs = ["get", "list"]
  }
}

# Bind telemetry agent to cluster role
resource "kubernetes_cluster_role_binding" "telemetry_reader" {
  metadata {
    name = "prism-telemetry-reader"
    labels = {
      "app.kubernetes.io/name"      = "telemetry-agent"
      "app.kubernetes.io/component" = "telemetry"
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
  count = var.enable_telemetry ? 1 : 0
  
  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "telemetry-agent"
      "app.kubernetes.io/component"  = "telemetry"
      "app.kubernetes.io/version"    = "v1.2.0"
      "app.kubernetes.io/managed-by" = "terraform"
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
          "app.kubernetes.io/name"      = "telemetry-agent"
          "app.kubernetes.io/component" = "telemetry"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
          "prometheus.io/path"   = "/metrics"
          "config/hash"          = sha256(kubernetes_config_map.telemetry_config.data["config.yaml"])
        }
      }

      spec {
        service_account_name = kubernetes_service_account.telemetry_agent.metadata[0].name
        
        container {
          name  = "telemetry-agent"
          image = "prism-platform/prism-telemetry-agent:v1.2.0"
          
          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }
          
          port {
            name           = "metrics"
            container_port = 9090
            protocol       = "TCP"
          }
          
          env {
            name  = "CONFIG_PATH"
            value = "/etc/telemetry/config.yaml"
          }
          
          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }
          
          env {
            name  = "LOG_FORMAT"
            value = "json"
          }
          
          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          
          dynamic "env" {
            for_each = var.api_key != "" ? [1] : []
            content {
              name = "API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.telemetry_credentials[0].metadata[0].name
                  key  = "api_key"
                }
              }
            }
          }
          
          volume_mount {
            name       = "config"
            mount_path = "/etc/telemetry"
            read_only  = true
          }
          
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/telemetry"
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
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 65534
            read_only_root_filesystem  = true
            
            capabilities {
              drop = ["ALL"]
            }
          }
        }
        
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.telemetry_config.metadata[0].name
          }
        }
        
        volume {
          name = "data"
          empty_dir {}
        }
        
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }
      }
    }
  }
}

# Create Service for telemetry agent
resource "kubernetes_service" "telemetry_agent" {
  count = var.enable_telemetry ? 1 : 0
  
  metadata {
    name      = "telemetry-agent"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "telemetry-agent"
      "app.kubernetes.io/component" = "telemetry"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    type = "ClusterIP"
    
    selector = {
      "app.kubernetes.io/name" = "telemetry-agent"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    
    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }
  }
} 