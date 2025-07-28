# Prism Service Mesh Module Variables

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

# Istio Configuration
variable "istio_namespace" {
  description = "Namespace for Istio installation"
  type        = string
  default     = "istio-system"
}

variable "istio_version" {
  description = "Istio version to install"
  type        = string
  default     = "1.26.1"
}

variable "istio_chart_version" {
  description = "Istio Helm chart version"
  type        = string
  default     = "1.26.1"
}

variable "istio_hub" {
  description = "Container registry for Istio images"
  type        = string
  default     = "docker.io/istio"
}

variable "mesh_id" {
  description = "Unique identifier for the service mesh"
  type        = string
  default     = "mesh1"
}

variable "network_name" {
  description = "Network name for multi-cluster setup"
  type        = string
  default     = "network1"
}

# Multi-cluster Configuration
variable "enable_multi_cluster" {
  description = "Enable multi-cluster service mesh"
  type        = bool
  default     = false
}

variable "mesh_networks" {
  description = "Configuration for mesh networks in multi-cluster setup"
  type = list(object({
    name     = string
    registry = string
    gateways = list(object({
      service = string
      port    = number
    }))
  }))
  default = []
}

# Gateway Configuration
variable "enable_ingress_gateway" {
  description = "Enable Istio ingress gateway"
  type        = bool
  default     = true
}

variable "ingress_gateway_type" {
  description = "Type of ingress gateway service (LoadBalancer, NodePort, ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "ingress_source_ranges" {
  description = "Source IP ranges allowed to access ingress gateway"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# eBPF Acceleration (Merbridge)
variable "enable_ebpf_acceleration" {
  description = "Enable eBPF acceleration with Merbridge"
  type        = bool
  default     = true
}

variable "merbridge_image" {
  description = "Merbridge container image"
  type        = string
  default     = "ghcr.io/merbridge/merbridge"
}

variable "merbridge_version" {
  description = "Merbridge version"
  type        = string
  default     = "v0.5.0"
}

variable "cni_mode" {
  description = "CNI mode for Merbridge (auto, cilium, flannel, calico)"
  type        = string
  default     = "auto"
}

variable "merbridge_node_selector" {
  description = "Node selector for Merbridge DaemonSet"
  type        = map(string)
  default     = {}
}

variable "merbridge_tolerations" {
  description = "Tolerations for Merbridge DaemonSet"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = [
    {
      key      = "node-role.kubernetes.io/master"
      operator = "Exists"
      value    = ""
      effect   = "NoSchedule"
    },
    {
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Exists"
      value    = ""
      effect   = "NoSchedule"
    }
  ]
}

# Resource Configuration
variable "pilot_resources" {
  description = "Resource requests and limits for Istio pilot"
  type = object({
    cpu_request    = string
    memory_request = string
    cpu_limit      = string
    memory_limit   = string
  })
  default = {
    cpu_request    = "500m"
    memory_request = "2Gi"
    cpu_limit      = "1000m"
    memory_limit   = "4Gi"
  }
}

variable "gateway_resources" {
  description = "Resource requests and limits for Istio gateways"
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
      cpu    = "2000m"
      memory = "1Gi"
    }
  }
}

variable "merbridge_resources" {
  description = "Resource requests and limits for Merbridge"
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
      memory = "200Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "500Mi"
    }
  }
}

# Security Configuration
variable "mtls_mode" {
  description = "mTLS mode for service mesh (STRICT, PERMISSIVE, DISABLE)"
  type        = string
  default     = "STRICT"
  validation {
    condition = contains(["STRICT", "PERMISSIVE", "DISABLE"], var.mtls_mode)
    error_message = "mTLS mode must be STRICT, PERMISSIVE, or DISABLE."
  }
}

# Observability Configuration
variable "enable_telemetry" {
  description = "Enable telemetry collection"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable distributed tracing"
  type        = bool
  default     = true
}

variable "tracing_sampling_rate" {
  description = "Sampling rate for distributed tracing (0.0 to 1.0)"
  type        = number
  default     = 0.1
  validation {
    condition = var.tracing_sampling_rate >= 0.0 && var.tracing_sampling_rate <= 1.0
    error_message = "Tracing sampling rate must be between 0.0 and 1.0."
  }
}

# Access Log Configuration
variable "enable_access_logs" {
  description = "Enable access logs for Envoy proxies"
  type        = bool
  default     = true
}

variable "access_log_format" {
  description = "Format for access logs (JSON or TEXT)"
  type        = string
  default     = "JSON"
  validation {
    condition = contains(["JSON", "TEXT"], var.access_log_format)
    error_message = "Access log format must be JSON or TEXT."
  }
} 