variable "aws_region" {
  description = "AWS region for S3 bucket and Redshift cluster."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID for GCS bucket and BigQuery dataset."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for GCS bucket and BigQuery dataset."
  type        = string
}

variable "azure_resource_group_name" {
  description = "Azure resource group name for Blob Storage and Synapse Analytics."
  type        = string
}

variable "azure_location" {
  description = "Azure location for Blob Storage and Synapse Analytics."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

# S3 Bucket specific variables
variable "s3_bucket_name_prefix" {
  description = "Prefix for the S3 raw data bucket name. A random suffix will be appended."
  type        = string
  default     = "prism-platform-raw-data"
}

# GCS Bucket specific variables
variable "gcs_bucket_name_prefix" {
  description = "Prefix for the GCS raw data bucket name. A random suffix will be appended."
  type        = string
  default     = "prism-platform-raw-data"
}

# Azure Blob Storage specific variables
variable "azure_storage_account_name_prefix" {
  description = "Prefix for the Azure Storage Account name. A random suffix will be appended."
  type        = string
  default     = "correctivedriftrawdata"
}

variable "azure_blob_container_name" {
  description = "Name for the Azure Blob container for raw data."
  type        = string
  default     = "raw-data"
}

# Data Warehouse specific variables
# For this MVP, we might start with simpler managed solutions or even just structured storage in data lakes.
# Full-fledged data warehouses like Redshift, BigQuery, Synapse can be complex to set up initially.
# We'll include placeholders that can be expanded.

variable "enable_aws_redshift" {
  description = "Flag to enable/disable Redshift cluster creation."
  type        = bool
  default     = false # Keep false for initial setup to manage costs/complexity
}

variable "enable_gcp_bigquery_dataset" {
  description = "Flag to enable/disable BigQuery dataset creation."
  type        = bool
  default     = true # BigQuery is often simpler to start with for datasets
}

variable "enable_azure_synapse_workspace" {
  description = "Flag to enable/disable Azure Synapse Analytics workspace creation."
  type        = bool
  default     = false # Keep false for initial setup
}

variable "bigquery_dataset_id" {
  description = "ID for the BigQuery dataset."
  type        = string
  default     = "prism_platform_data"
}
