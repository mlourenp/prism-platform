# Global Configuration Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# Multi-Cloud Provider Configuration
variable "aws_region" {
  description = "AWS region for provider configuration"
  type        = string
  default     = ""
}

variable "gcp_project_id" {
  description = "Google Cloud project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "Google Cloud region"
  type        = string
  default     = ""
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
}

variable "oci_tenancy_ocid" {
  description = "Oracle Cloud tenancy OCID"
  type        = string
  default     = ""
}

variable "ibm_api_key" {
  description = "IBM Cloud API key"
  type        = string
  default     = ""
  sensitive   = true
}

# Feature Configuration
variable "enable_cost_estimation" {
  description = "Enable Infracost integration for cost transparency"
  type        = bool
  default     = true
}

variable "crossplane_version" {
  description = "Version of Crossplane to install"
  type        = string
  default     = "1.14.0"
}

variable "provider_versions" {
  description = "Versions of Crossplane providers to install"
  type = object({
    aws   = string
    gcp   = string
    azure = string
  })
  default = {
    aws   = "v0.44.0"
    gcp   = "v0.22.0"
    azure = "v0.19.0"
  }
}

# Kubernetes Configuration
variable "kubernetes_namespace" {
  description = "Kubernetes namespace for Crossplane system"
  type        = string
  default     = "crossplane-system"
}

# Resource Configuration
variable "crossplane_resources" {
  description = "Resource limits and requests for Crossplane"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
  }
} 