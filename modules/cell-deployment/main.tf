# Prism Cell Deployment Module
# Manages deployment and orchestration of cell-based infrastructure patterns

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Local variables for configuration
locals {
  common_labels = merge(var.common_tags, {
    "prism.io/component" = "cell-deployment"
    "prism.io/version"   = "v1.2"
    "app.kubernetes.io/managed-by" = "terraform"
  })

  # Cell types supported by the platform
  cell_types = [
    "logic",
    "channel", 
    "data",
    "security",
    "external",
    "integration",
    "legacy",
    "observability"
  ]

  # Cell network policies based on communication matrix
  cell_network_policies = var.enable_ebpf_policies ? {
    for cell_type in local.cell_types : cell_type => {
      namespace = "${cell_type}-cell"
      spec = {
        endpointSelector = {
          matchLabels = {
            "prism.io/cell-type" = cell_type
          }
        }
        ingress = cell_type == "channel" ? [
          {
            fromEntities = ["world"]
            toPorts = [
              {
                ports = [
                  { port = "80", protocol = "TCP" },
                  { port = "443", protocol = "TCP" }
                ]
              }
            ]
          }
        ] : [
          {
            fromEndpoints = [
              {
                matchLabels = {
                  "prism.io/cell-type" = "channel"
                }
              },
              {
                matchLabels = {
                  "prism.io/cell-type" = "logic"
                }
              }
            ]
          }
        ]
        egress = cell_type == "external" ? [
          {
            toEntities = ["world"]
          }
        ] : [
          {
            toEndpoints = [
              {
                matchLabels = {}  # Allow internal cluster communication
              }
            ]
          }
        ]
      }
    }
  } : {}
}

# Create cell namespaces
resource "kubernetes_namespace" "cell_namespaces" {
  for_each = toset(local.cell_types)

  metadata {
    name = "${each.value}-cell"
    labels = merge(local.common_labels, {
      "prism.io/cell-type" = each.value
      "prism.io/network-zone" = each.value == "channel" ? "dmz" : each.value == "security" ? "high-security" : "internal"
      "istio-injection" = var.enable_service_mesh ? "enabled" : "disabled"
      "pod-security.kubernetes.io/enforce" = contains(["security", "channel", "data"], each.value) ? "restricted" : "baseline"
    })
    annotations = {
      "prism.io/managed-by" = "cell-deployment"
      "prism.io/created" = timestamp()
    }
  }
}

# Create ServiceAccounts for each cell type
resource "kubernetes_service_account" "cell_service_accounts" {
  for_each = toset(local.cell_types)

  metadata {
    name      = "${each.value}-cell-sa"
    namespace = kubernetes_namespace.cell_namespaces[each.value].metadata[0].name
    labels    = local.common_labels
  }

  automount_service_account_token = true
}

# Create NetworkPolicies for cell communication (if eBPF is enabled)
resource "kubernetes_manifest" "cell_network_policies" {
  for_each = local.cell_network_policies

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "${each.key}-cell-policy"
      namespace = each.value.namespace
      labels    = local.common_labels
    }
    spec = each.value.spec
  }

  depends_on = [kubernetes_namespace.cell_namespaces]
}

# Create ResourceQuotas for each cell namespace
resource "kubernetes_resource_quota" "cell_quotas" {
  for_each = toset(local.cell_types)

  metadata {
    name      = "${each.value}-cell-quota"
    namespace = kubernetes_namespace.cell_namespaces[each.value].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    hard = {
      "requests.cpu"    = each.value == "data" ? "8" : each.value == "logic" ? "16" : "4"
      "requests.memory" = each.value == "data" ? "32Gi" : each.value == "logic" ? "32Gi" : "16Gi"
      "limits.cpu"      = each.value == "data" ? "16" : each.value == "logic" ? "32" : "8"
      "limits.memory"   = each.value == "data" ? "64Gi" : each.value == "logic" ? "64Gi" : "32Gi"
      "persistentvolumeclaims" = each.value == "data" ? "10" : "5"
      "requests.storage" = each.value == "data" ? "1Ti" : each.value == "observability" ? "500Gi" : "100Gi"
      "pods"            = "100"
      "services"        = "20"
      "secrets"         = "10"
      "configmaps"      = "20"
    }
  }

  depends_on = [kubernetes_namespace.cell_namespaces]
}

# Create LimitRanges for pod-level resource constraints
resource "kubernetes_limit_range" "cell_limits" {
  for_each = toset(local.cell_types)

  metadata {
    name      = "${each.value}-cell-limits"
    namespace = kubernetes_namespace.cell_namespaces[each.value].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "1000m"
        memory = "2Gi"
      }
      default_request = {
        cpu    = "100m"
        memory = "256Mi"
      }
      max = {
        cpu    = "4000m"
        memory = "8Gi"
      }
      min = {
        cpu    = "50m"
        memory = "128Mi"
      }
    }
  }

  depends_on = [kubernetes_namespace.cell_namespaces]
}

# Create monitoring ServiceMonitors for cells (if observability is enabled)
resource "kubernetes_manifest" "cell_service_monitors" {
  for_each = var.enable_observability ? toset(local.cell_types) : toset([])

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${each.value}-cell-monitor"
      namespace = kubernetes_namespace.cell_namespaces[each.value].metadata[0].name
      labels = merge(local.common_labels, {
        "prism.io/monitoring" = "enabled"
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "prism.io/cell-type" = each.value
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace.cell_namespaces]
}

# Create PodMonitors for automatic pod discovery (if observability is enabled)
resource "kubernetes_manifest" "cell_pod_monitors" {
  for_each = var.enable_observability ? toset(local.cell_types) : toset([])

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "${each.value}-cell-pod-monitor"
      namespace = kubernetes_namespace.cell_namespaces[each.value].metadata[0].name
      labels = merge(local.common_labels, {
        "prism.io/monitoring" = "enabled"
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "prism.io/cell-type" = each.value
        }
      }
      podMetricsEndpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace.cell_namespaces]
}

# Output cell namespace information
output "cell_namespaces" {
  description = "Created cell namespaces"
  value = {
    for k, v in kubernetes_namespace.cell_namespaces : k => v.metadata[0].name
  }
}

output "cell_service_accounts" {
  description = "Created cell service accounts"
  value = {
    for k, v in kubernetes_service_account.cell_service_accounts : k => {
      name      = v.metadata[0].name
      namespace = v.metadata[0].namespace
    }
  }
}

output "cell_network_policies" {
  description = "Cell network policies status"
  value = var.enable_ebpf_policies ? {
    enabled = true
    policies = keys(local.cell_network_policies)
  } : {
    enabled = false
    policies = []
  }
} 