# eBPF Observability Stack for Prism Platform
# Deploys Cilium, Tetragon, and Falco for comprehensive network and security observability

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
  description = "Namespace for eBPF components"
  type        = string
}

variable "enable_cilium" {
  description = "Enable Cilium CNI and network policies"
  type        = bool
  default     = true
}

variable "enable_tetragon" {
  description = "Enable Tetragon runtime security"
  type        = bool
  default     = true
}

variable "enable_falco" {
  description = "Enable Falco threat detection"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "prism-platform"
}

# Cilium deployment for eBPF networking and security
resource "helm_release" "cilium" {
  count = var.enable_cilium ? 1 : 0
  
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = "1.14.1"

  values = [
    file("${path.module}/cilium-values.yaml")
  ]

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }
  
  # Enable eBPF-based observability features
  set {
    name  = "hubble.enabled"
    value = "true"
  }
  
  set {
    name  = "hubble.metrics.enabled"
    value = "{dns,drop,tcp,flow,port-distribution,icmp,http}"
  }
  
  set {
    name  = "hubble.relay.enabled"
    value = "true"
  }
  
  set {
    name  = "hubble.ui.enabled"
    value = "true"
  }
  
  # Enable Prometheus metrics
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  
  set {
    name  = "operator.prometheus.enabled"
    value = "true"
  }
}

# Tetragon deployment for runtime security observability
resource "helm_release" "tetragon" {
  count = var.enable_tetragon ? 1 : 0
  
  name       = "tetragon"
  repository = "https://helm.cilium.io/"
  chart      = "tetragon"
  namespace  = "tetragon-system"
  version    = "1.0.2"
  
  create_namespace = true

  values = [
    file("${path.module}/tetragon-values.yaml")
  ]
  
  # Enable metrics and tracing
  set {
    name  = "tetragon.prometheus.enabled"
    value = "true"
  }
  
  set {
    name  = "tetragon.grpc.enabled"
    value = "true"
  }
  
  set {
    name  = "tetragon.exportFilename"
    value = "/var/log/tetragon/tetragon.log"
  }
}

# Falco deployment for threat detection
resource "helm_release" "falco" {
  count = var.enable_falco ? 1 : 0
  
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  namespace  = "falco-system"
  version    = "3.8.4"
  
  create_namespace = true

  values = [
    file("${path.module}/falco-values.yaml")
  ]
  
  # Configure eBPF driver
  set {
    name  = "driver.kind"
    value = "ebpf"
  }
  
  set {
    name  = "falco.grpc.enabled"
    value = "true"
  }
  
  set {
    name  = "falco.grpcOutput.enabled"
    value = "true"
  }
  
  # Enable metrics for Prometheus
  set {
    name  = "falco.metrics.enabled"
    value = "true"
  }
}

# Create ServiceMonitors for eBPF components
resource "kubernetes_manifest" "cilium_servicemonitor" {
  count = var.enable_cilium ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "cilium"
      namespace = var.namespace
      labels = {
        "prism.io/monitoring" = "enabled"
        "app.kubernetes.io/component" = "ebpf"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "cilium-agent"
        }
      }
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      endpoints = [{
        port = "prometheus"
        interval = "30s"
        path = "/metrics"
      }]
    }
  }
}

resource "kubernetes_manifest" "tetragon_servicemonitor" {
  count = var.enable_tetragon ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "tetragon"
      namespace = var.namespace
      labels = {
        "prism.io/monitoring" = "enabled"
        "app.kubernetes.io/component" = "ebpf"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "tetragon"
        }
      }
      namespaceSelector = {
        matchNames = ["tetragon-system"]
      }
      endpoints = [{
        port = "metrics"
        interval = "30s"
        path = "/metrics"
      }]
    }
  }
}

resource "kubernetes_manifest" "falco_servicemonitor" {
  count = var.enable_falco ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "falco"
      namespace = var.namespace
      labels = {
        "prism.io/monitoring" = "enabled"
        "app.kubernetes.io/component" = "ebpf"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "falco"
        }
      }
      namespaceSelector = {
        matchNames = ["falco-system"]
      }
      endpoints = [{
        port = "metrics"
        interval = "30s"
        path = "/metrics"
      }]
    }
  }
}

# Output important endpoints for eBPF components
output "cilium_hubble_ui_url" {
  value = var.enable_cilium ? "http://hubble-ui.kube-system.svc.cluster.local:80" : null
}

output "tetragon_metrics_url" {
  value = var.enable_tetragon ? "http://tetragon.tetragon-system.svc.cluster.local:2112/metrics" : null
}

output "falco_metrics_url" {
  value = var.enable_falco ? "http://falco.falco-system.svc.cluster.local:8765/metrics" : null
} 