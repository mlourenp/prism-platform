# Cell Deployment Module Variables
# Variables for cell-based infrastructure deployment and management

variable "namespace" {
  description = "Primary namespace for platform components"
  type        = string
  default     = "prism-system"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "cloud_provider" {
  description = "Primary cloud provider (aws, gcp, azure, oracle, ibm, baremetal)"
  type        = string
  
  validation {
    condition = contains(["aws", "gcp", "azure", "oracle", "ibm", "baremetal"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, gcp, azure, oracle, ibm, baremetal."
  }
}

# Feature toggles
variable "enable_service_mesh" {
  description = "Enable Istio service mesh integration for cells"
  type        = bool
  default     = false
}

variable "enable_ebpf_policies" {
  description = "Enable eBPF-based network policies for cell communication"
  type        = bool
  default     = false
}

variable "enable_observability" {
  description = "Enable observability stack for cell monitoring"
  type        = bool
  default     = true
}

# Common tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Platform    = "prism"
    ManagedBy   = "terraform"
    Component   = "cell-deployment"
  }
} 