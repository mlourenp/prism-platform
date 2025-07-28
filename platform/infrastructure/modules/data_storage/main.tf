terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Random suffix for bucket names to ensure uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# AWS S3 Bucket for Raw Data
resource "aws_s3_bucket" "raw_data" {
  count = 1 # Assuming we always want an S3 bucket for now

  bucket = "${var.s3_bucket_name_prefix}-${random_string.suffix.result}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.s3_bucket_name_prefix}-${random_string.suffix.result}"
      Environment = var.environment
      Purpose     = "Raw data storage for Prism Platform"
    }
  )
}

resource "aws_s3_bucket_versioning" "raw_data_versioning" {
  count  = 1
  bucket = aws_s3_bucket.raw_data[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data_encryption" {
  count  = 1
  bucket = aws_s3_bucket.raw_data[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# GCP GCS Bucket for Raw Data
resource "google_storage_bucket" "raw_data" {
  count = 1 # Assuming we always want a GCS bucket for now

  name          = "${var.gcs_bucket_name_prefix}-${random_string.suffix.result}"
  project       = var.gcp_project_id
  location      = var.gcp_region
  force_destroy = false # Set to true for dev/test if needed, but be cautious
  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = ""
  }

  labels = merge(
    var.tags, # GCP uses labels instead of tags directly on buckets
    {
      environment = var.environment
      purpose     = "raw-data-storage-prism-platform"
    }
  )
}

# Azure Blob Storage for Raw Data
resource "azurerm_storage_account" "raw_data" {
  count = 1 # Assuming we always want Azure Blob storage for now

  name                     = "${var.azure_storage_account_name_prefix}${random_string.suffix.result}"
  resource_group_name      = var.azure_resource_group_name
  location                 = var.azure_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Purpose     = "Raw data storage for Prism Platform"
    }
  )
}

resource "azurerm_storage_container" "raw_data" {
  count = 1

  name                  = var.azure_blob_container_name
  storage_account_name  = azurerm_storage_account.raw_data[0].name
  container_access_type = "private"
}

# GCP BigQuery Dataset
resource "google_bigquery_dataset" "default" {
  count = var.enable_gcp_bigquery_dataset ? 1 : 0

  dataset_id                  = var.bigquery_dataset_id
  project                     = var.gcp_project_id
  location                    = var.gcp_region
  description                 = "Dataset for Prism Platform processed data"
  delete_contents_on_destroy  = false # Set to true for dev/test, be cautious

  labels = merge(
    var.tags,
    {
      environment = var.environment
      purpose     = "processed-data-storage-prism-platform"
    }
  )
}

# Placeholder for AWS Redshift (if enabled)
# resource "aws_redshift_cluster" "default" {
#   count = var.enable_aws_redshift ? 1 : 0
#   # ... configuration ...
# }

# Placeholder for Azure Synapse Workspace (if enabled)
# resource "azurerm_synapse_workspace" "default" {
#   count = var.enable_azure_synapse_workspace ? 1 : 0
#   # ... configuration ...
# }
