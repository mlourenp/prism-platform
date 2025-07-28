variable "cur_s3_bucket_arn" {
  description = "ARN of the S3 bucket where AWS Cost and Usage Reports (CUR) are stored."
  type        = string
  # Example: "arn:aws:s3:::your-cur-bucket-name"
}

variable "cur_report_path_prefix" {
  description = "The path prefix within the CUR S3 bucket where reports are located (e.g., 'cur-reports/'). Should end with a '/' if it's a folder structure."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

locals {
  # If prefix is empty, allow access to all objects. If prefix is specified, scope down.
  cur_bucket_objects_path = var.cur_report_path_prefix == "" ? "/*" : "/${var.cur_report_path_prefix}*"
  # For ListBucket, the resource is the bucket itself, but the condition narrows down the prefix for listing.
  # If no prefix, ListBucket applies to the whole bucket.
  s3_list_condition_block = var.cur_report_path_prefix != "" ? {
    test     = "StringLike"
    variable = "s3:prefix"
    values   = [var.cur_report_path_prefix == "" ? "*" : "${var.cur_report_path_prefix}*"] # List objects under this prefix
    } : null
}

resource "aws_iam_role" "cur_ingestion_role" {
  name = "CURBillingIngestionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Placeholder: Assuming an ECS task will run the script. Adjust if running elsewhere (e.g., Lambda, EC2)
        }
      },
      # Potentially add other trusted entities if needed, e.g. a specific EC2 instance profile or another account.
    ]
  })
  tags = var.tags
}

resource "aws_iam_policy" "cur_s3_access_policy" {
  name        = "CURS3AccessPolicy"
  description = "Allows access to specific CUR S3 bucket and objects for billing data ingestion."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ListCURBucket",
        Effect = "Allow",
        Action = "s3:ListBucket",
        Resource = var.cur_s3_bucket_arn,
        # Condition to restrict listing to the specified prefix, if provided.
        # s3:prefix condition in ListBucket requires the prefix to match the beginning of the key.
        Condition = local.s3_list_condition_block != null ? [local.s3_list_condition_block] : []
      },
      {
        Sid    = "GetCURObjects",
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        # Resource should be bucket_arn + prefix + object_name
        # e.g., arn:aws:s3:::your-cur-bucket/your-prefix/*
        Resource = "${var.cur_s3_bucket_arn}${local.cur_bucket_objects_path}"
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cur_ingestion_role_s3_policy_attachment" {
  role       = aws_iam_role.cur_ingestion_role.name
  policy_arn = aws_iam_policy.cur_s3_access_policy.arn
}

output "cur_ingestion_role_arn" {
  description = "ARN of the IAM role for CUR ingestion."
  value       = aws_iam_role.cur_ingestion_role.arn
}
