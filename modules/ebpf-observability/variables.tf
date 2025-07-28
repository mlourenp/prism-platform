# Prism eBPF Observability Module Variables

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure, oracle, ibm, baremetal)"
  type        = string
  validation {
    condition = contains(["aws", "gcp", "azure", "oracle", "ibm", "baremetal"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, gcp, azure, oracle, ibm, baremetal."
  }
}

variable "region" {
  description = "Cloud provider region"
  type        = string
}

# Cilium Configuration
variable "cilium_namespace" {
  description = "Namespace for Cilium installation"
  type        = string
  default     = "cilium-system"
}

variable "cilium_chart_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.15.3"
}

variable "cluster_id" {
  description = "Unique identifier for the cluster"
  type        = number
  default     = 1
  validation {
    condition = var.cluster_id >= 1 && var.cluster_id <= 255
    error_message = "Cluster ID must be between 1 and 255."
  }
}

variable "enable_cilium_networking" {
  description = "Enable Cilium as the CNI plugin"
  type        = bool
  default     = true
}

variable "install_cni" {
  description = "Install CNI configuration"
  type        = bool
  default     = true
}

variable "cni_chaining_mode" {
  description = "CNI chaining mode (none, aws-cni, flannel, generic-veth, portmap)"
  type        = string
  default     = "none"
}

# eBPF Features
variable "enable_masquerade" {
  description = "Enable masquerading with eBPF"
  type        = bool
  default     = true
}

variable "enable_host_routing" {
  description = "Enable host routing with eBPF"
  type        = bool
  default     = true
}

variable "enable_transparent_proxy" {
  description = "Enable transparent proxy with eBPF"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable network encryption"
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "Type of encryption (ipsec, wireguard)"
  type        = string
  default     = "ipsec"
  validation {
    condition = contains(["ipsec", "wireguard"], var.encryption_type)
    error_message = "Encryption type must be ipsec or wireguard."
  }
}

# Network Policy
variable "policy_enforcement_mode" {
  description = "Policy enforcement mode (default, always, never)"
  type        = string
  default     = "default"
  validation {
    condition = contains(["default", "always", "never"], var.policy_enforcement_mode)
    error_message = "Policy enforcement mode must be default, always, or never."
  }
}

variable "enable_network_policies" {
  description = "Enable creation of network policies"
  type        = bool
  default     = true
}

variable "create_default_deny_policy" {
  description = "Create a default deny-all network policy"
  type        = bool
  default     = false
}

# Load Balancer Configuration
variable "load_balancer_algorithm" {
  description = "Load balancer algorithm (round_robin, least_connection, random)"
  type        = string
  default     = "round_robin"
}

variable "load_balancer_mode" {
  description = "Load balancer mode (snat, dsr, hybrid)"
  type        = string
  default     = "snat"
}

# Hubble Configuration
variable "enable_hubble" {
  description = "Enable Hubble for network observability"
  type        = bool
  default     = true
}

variable "enable_hubble_ui" {
  description = "Enable Hubble UI"
  type        = bool
  default     = true
}

variable "hubble_ui_service_type" {
  description = "Service type for Hubble UI (ClusterIP, NodePort, LoadBalancer)"
  type        = string
  default     = "ClusterIP"
}

variable "enable_hubble_ingress" {
  description = "Enable ingress for Hubble UI"
  type        = bool
  default     = false
}

variable "hubble_ui_hostname" {
  description = "Hostname for Hubble UI ingress"
  type        = string
  default     = "hubble.local"
}

variable "hubble_ingress_class_name" {
  description = "Ingress class name for Hubble UI"
  type        = string
  default     = "nginx"
}

variable "hubble_ingress_annotations" {
  description = "Annotations for Hubble UI ingress"
  type        = map(string)
  default     = {}
}

variable "enable_hubble_tls" {
  description = "Enable TLS for Hubble UI ingress"
  type        = bool
  default     = false
}

variable "hubble_tls_secret_name" {
  description = "Secret name for Hubble UI TLS certificate"
  type        = string
  default     = "hubble-tls"
}

# Metrics Configuration
variable "enable_metrics" {
  description = "Enable Hubble metrics collection"
  type        = bool
  default     = true
}

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus operator"
  type        = bool
  default     = true
}

# Tetragon Configuration
variable "enable_tetragon" {
  description = "Enable Tetragon for runtime security"
  type        = bool
  default     = true
}

variable "tetragon_chart_version" {
  description = "Tetragon Helm chart version"
  type        = string
  default     = "0.10.0"
}

variable "tetragon_version" {
  description = "Tetragon version"
  type        = string
  default     = "v0.10.0"
}

variable "tetragon_image_repository" {
  description = "Tetragon image repository"
  type        = string
  default     = "quay.io/cilium/tetragon"
}

variable "enable_tetragon_grpc" {
  description = "Enable Tetragon gRPC API"
  type        = bool
  default     = true
}

variable "enable_tetragon_stdout" {
  description = "Enable Tetragon stdout export"
  type        = bool
  default     = true
}

variable "tetragon_export_allowlist" {
  description = "Tetragon export allowlist"
  type        = list(string)
  default     = []
}

variable "tetragon_export_denylist" {
  description = "Tetragon export denylist"
  type        = list(string)
  default     = []
}

variable "tetragon_export_filenames" {
  description = "Tetragon export filenames"
  type        = list(string)
  default     = []
}

variable "enable_process_filter" {
  description = "Enable Tetragon process filtering"
  type        = bool
  default     = true
}

variable "process_filter_specs" {
  description = "Process filter specifications for Tetragon"
  type        = list(map(string))
  default     = []
}

variable "enable_tetragon_operator" {
  description = "Enable Tetragon operator"
  type        = bool
  default     = true
}

variable "tetragon_operator_image_repository" {
  description = "Tetragon operator image repository"
  type        = string
  default     = "quay.io/cilium/tetragon-operator"
}

# Resource Configuration
variable "operator_replicas" {
  description = "Number of Cilium operator replicas"
  type        = number
  default     = 2
}

variable "operator_resources" {
  description = "Resource requests and limits for Cilium operator"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "agent_resources" {
  description = "Resource requests and limits for Cilium agent"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "4000m"
      memory = "4Gi"
    }
  }
}

variable "tetragon_resources" {
  description = "Resource requests and limits for Tetragon"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "tetragon_operator_resources" {
  description = "Resource requests and limits for Tetragon operator"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

# Kubernetes API Configuration
variable "k8s_service_host" {
  description = "Kubernetes API server host"
  type        = string
  default     = ""
}

variable "k8s_service_port" {
  description = "Kubernetes API server port"
  type        = string
  default     = "443"
}

# Network Policy Definitions
variable "cell_network_policies" {
  description = "Cell-specific network policies"
  type = map(object({
    namespace = string
    spec      = any
  }))
  default = {}
}

variable "cluster_network_policies" {
  description = "Cluster-wide network policies"
  type        = map(any)
  default     = {}
}

variable "tetragon_tracing_policies" {
  description = "Tetragon tracing policies"
  type        = map(any)
  default     = {}
} 