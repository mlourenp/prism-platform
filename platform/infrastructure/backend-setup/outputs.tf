output "s3_bucket_name" {
  description = "The name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_profile" {
  description = "The AWS profile used for authentication"
  value       = var.aws_profile
}

output "terraform_backend_config" {
  description = "The backend configuration for Terraform projects"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "path/to/your/project/terraform.tfstate"
      region         = "${var.region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      encrypt        = true
      profile        = "${var.aws_profile}"
    }
  EOT
}

output "backend_config_instructions" {
  description = "Instructions for using the backend"
  value       = <<-EOT
    To use this backend in your Terraform projects:

    Option 1: Configure directly in your terraform block:
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "path/to/your/project/terraform.tfstate"
        region         = "${var.region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
        profile        = "${var.aws_profile}"
      }
    }

    Option 2: Use a backend.conf file:
    1. Create a backend.conf file with these contents:
       bucket         = "${aws_s3_bucket.terraform_state.id}"
       key            = "path/to/your/project/terraform.tfstate"
       region         = "${var.region}"
       dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
       encrypt        = true
       profile        = "${var.aws_profile}"

    2. In your terraform project, include:
       terraform {
         backend "s3" {}
       }

    3. Initialize with:
       terraform init -backend-config=backend.conf

    4. Make sure the AWS profile "${var.aws_profile}" is configured:
       aws configure --profile ${var.aws_profile}
  EOT
}
