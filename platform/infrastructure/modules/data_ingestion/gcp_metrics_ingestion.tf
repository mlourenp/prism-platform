# Placeholder for GCP Cloud Monitoring Metrics Ingestion Terraform resources

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
# to access Cloud Monitoring, Pub/Sub topics for metric data, etc.

output "gcp_metrics_ingestion_example_output" {
  value = "Placeholder output"
}
