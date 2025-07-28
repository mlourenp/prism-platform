variable "gcp_project_id" {
  description = "The GCP project ID where the billing export bucket resides and for other resources."
  type        = string
}

variable "gcp_billing_export_bucket_name" {
  description = "The name of the GCS bucket where GCP billing data is exported."
  type        = string
}

variable "gcp_service_account_email" {
  description = "The email of the GCP service account that will be used to read billing data."
  type        = string
  # This service account should be created separately and granted permissions to run the ingestion script.
}

# In a typical setup, the billing export bucket is automatically created by GCP when you enable billing export.
# This resource definition is more for completeness or if you were creating a separate bucket for staging.
# Ensure the actual billing export is configured to this bucket if you manage it via Terraform.
resource "google_storage_bucket" "billing_export_bucket_if_managed" {
  count = 0 # Disabled by default, enable if you are creating/managing the bucket here

  name                        = var.gcp_billing_export_bucket_name
  project                     = var.gcp_project_id
  location                    = "US" # Choose an appropriate location
  uniform_bucket_level_access = true

  # It's crucial that the service account for the ingestion script has read access to this bucket.
  # This is typically granted via IAM roles on the bucket or project level.
}

# Grant the service account permissions to read from the billing export bucket.
# This assumes the bucket already exists (either created by GCP billing export or manually/elsewhere).
resource "google_storage_bucket_iam_member" "billing_data_reader" {
  bucket = var.gcp_billing_export_bucket_name
  role   = "roles/storage.objectViewer" # Allows listing and reading objects
  member = "serviceAccount:${var.gcp_service_account_email}"
}

# Optionally, if the service account also needs to list buckets in the project (e.g., to discover the billing bucket dynamically)
# resource "google_project_iam_member" "bucket_lister" {
#   project = var.gcp_project_id
#   role    = "roles/storage.admin" # Overly permissive; prefer roles/storage.objectViewer on specific buckets
#   member  = "serviceAccount:${var.gcp_service_account_email}"
# }

output "gcp_billing_export_bucket_id" {
  description = "The ID of the GCS bucket for billing exports."
  value       = var.gcp_billing_export_bucket_name # google_storage_bucket.billing_export_bucket_if_managed.id if created here
}

output "gcp_service_account_email_for_billing_ingestion" {
  description = "The email of the service account configured for GCP billing ingestion."
  value       = var.gcp_service_account_email
}
