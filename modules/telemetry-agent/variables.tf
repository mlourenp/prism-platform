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
  
  validation {
    condition     = var.reporting_interval_minutes >= 5 && var.reporting_interval_minutes <= 1440
    error_message = "Reporting interval must be between 5 and 1440 minutes."
  }
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
  
  validation {
    condition     = var.local_retention_days >= 1 && var.local_retention_days <= 30
    error_message = "Local retention must be between 1 and 30 days."
  }
}

variable "image_registry" {
  description = "Container image registry for telemetry agent"
  type        = string
  default     = "prism-platform"
}

variable "image_tag" {
  description = "Container image tag for telemetry agent"
  type        = string
  default     = "v1.2.0"
}

variable "resources" {
  description = "Resource limits and requests for telemetry agent"
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
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

variable "enable_debug_mode" {
  description = "Enable debug logging and detailed metrics"
  type        = bool
  default     = false
}

variable "network_policy_enabled" {
  description = "Create network policies for telemetry agent"
  type        = bool
  default     = true
}

variable "additional_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "additional_annotations" {
  description = "Additional annotations to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Node selector for telemetry agent pod"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for telemetry agent pod"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}

variable "affinity" {
  description = "Affinity rules for telemetry agent pod"
  type        = any
  default     = {}
} 