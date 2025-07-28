variable "bucket_name" {}
variable "region" {}

resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = {
    Name        = "Prism Platform Data Lake"
    Project     = "Prism Platform"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake_lifecycle" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id      = "log"
    status  = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  rule {
    id      = "raw_data"
    status  = "Enabled"

    filter {
        prefix = "raw/"
    }

    # Transition objects to Glacier for long-term archival after 1 year
    transition {
        days          = 365
        storage_class = "GLACIER"
    }

    # Configure expiration for non-current versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Creates empty directory objects for the defined structure
resource "aws_s3_object" "directory_structure" {
  for_each = toset([
    "raw/billing/aws/",
    "raw/billing/azure/",
    "raw/billing/gcp/",
    "raw/metrics/aws/",
    "raw/metrics/azure/",
    "raw/metrics/gcp/",
    "normalized/billing/",
    "normalized/metrics/",
    "logs/"
  ])

  bucket = aws_s3_bucket.data_lake.id
  key    = each.key
  source = "/dev/null" # Use an empty file source
}
