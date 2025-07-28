variable "bucket_name" {
  description = "The name of the S3 bucket to be used as the data lake."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the S3 bucket."
  type        = map(string)
  default     = {}
}

resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = merge(
    {
      "Name"        = var.bucket_name,
      "Project"     = "Prism Platform",
      "ManagedBy"   = "Terraform"
    },
    var.tags
  )
}

resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake_access_block" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create placeholder objects to define the directory structure
resource "aws_s3_object" "raw_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/"
  source = "/dev/null" # Use an empty file as the source
}

resource "aws_s3_object" "normalized_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "normalized/"
  source = "/dev/null"
}

resource "aws_s3_object" "raw_aws_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/aws/"
  source = "/dev/null"
}

resource "aws_s3_object" "raw_azure_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/azure/"
  source = "/dev/null"
}

resource "aws_s3_object" "raw_gcp_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/gcp/"
  source = "/dev/null"
}
