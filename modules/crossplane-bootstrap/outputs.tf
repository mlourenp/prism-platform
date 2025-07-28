# Crossplane System Information
output "crossplane_namespace" {
  description = "Kubernetes namespace where Crossplane is installed"
  value       = kubernetes_namespace.crossplane_system.metadata[0].name
}

output "crossplane_version" {
  description = "Version of Crossplane that was installed"
  value       = var.crossplane_version
}

# Provider Information
output "enabled_providers" {
  description = "List of enabled cloud providers"
  value = compact([
    var.aws_region != "" ? "aws" : "",
    var.gcp_project_id != "" ? "gcp" : "",
    var.azure_subscription_id != "" ? "azure" : "",
    var.oci_tenancy_ocid != "" ? "oci" : "",
    var.ibm_api_key != "" ? "ibm" : ""
  ])
}

output "aws_provider_config_name" {
  description = "Name of the AWS ProviderConfig (if enabled)"
  value       = var.aws_region != "" ? "aws-provider-config" : null
}

output "gcp_provider_config_name" {
  description = "Name of the GCP ProviderConfig (if enabled)"
  value       = var.gcp_project_id != "" ? "gcp-provider-config" : null
}

output "azure_provider_config_name" {
  description = "Name of the Azure ProviderConfig (if enabled)"
  value       = var.azure_subscription_id != "" ? "azure-provider-config" : null
}

# Configuration Status
output "cost_estimation_enabled" {
  description = "Whether cost estimation is enabled"
  value       = var.enable_cost_estimation
}

output "crossplane_ready" {
  description = "Indicates that Crossplane installation is complete"
  value       = true
  depends_on  = [helm_release.crossplane]
} 