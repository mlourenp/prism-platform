# Placeholder for Azure Monitor Metrics Ingestion Terraform resources

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
}

# TODO: Define resources such as service principals or managed identities
# for accessing Azure Monitor, Event Hubs for metric streaming, etc.

output "azure_metrics_ingestion_example_output" {
  value = "Placeholder output"
}
