# Placeholder for GCP Billing Ingestion Terraform resources

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region for resources."
  type        = string
}

variable "tags" {
  description = "A map of labels to assign to resources."
  type        = map(string)
  default     = {}
}

# TODO: Define resources such as service accounts with permissions
# to access BigQuery billing data, or configurations for billing export sinks.

output "gcp_billing_ingestion_example_output" {
  value = "Placeholder output"
}
