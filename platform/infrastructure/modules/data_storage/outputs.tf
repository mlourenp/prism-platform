output "aws_s3_raw_data_bucket_id" {
  description = "The ID (name) of the S3 bucket for raw data."
  value       = try(aws_s3_bucket.raw_data[0].id, null)
}

output "aws_s3_raw_data_bucket_arn" {
  description = "The ARN of the S3 bucket for raw data."
  value       = try(aws_s3_bucket.raw_data[0].arn, null)
}

output "gcp_gcs_raw_data_bucket_name" {
  description = "The name of the GCS bucket for raw data."
  value       = try(google_storage_bucket.raw_data[0].name, null)
}

output "gcp_gcs_raw_data_bucket_url" {
  description = "The URL of the GCS bucket for raw data."
  value       = try(google_storage_bucket.raw_data[0].url, null)
}

output "azure_storage_account_raw_data_id" {
  description = "The ID of the Azure Storage Account for raw data."
  value       = try(azurerm_storage_account.raw_data[0].id, null)
}

output "azure_storage_container_raw_data_id" {
  description = "The ID of the Azure Blob Container for raw data."
  value       = try(azurerm_storage_container.raw_data[0].id, null)
}

output "gcp_bigquery_dataset_id" {
  description = "The ID of the BigQuery dataset."
  value       = try(google_bigquery_dataset.default[0].dataset_id, null)
}

# Add outputs for Redshift and Synapse when implemented
output "aws_redshift_cluster_id" {
  description = "The ID of the Redshift cluster."
  value       = "Not Implemented"
}

output "azure_synapse_workspace_id" {
  description = "The ID of the Azure Synapse Workspace."
  value       = "Not Implemented"
}
