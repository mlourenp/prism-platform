# /iac/terraform/modules/s3_data_lake/outputs.tf

output "bucket_id" {
  description = "The ID (name) of the S3 bucket."
  value       = aws_s3_bucket.data_lake.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.data_lake.arn
}

output "bucket_region" {
  description = "The AWS region the bucket is located in."
  value       = aws_s3_bucket.data_lake.region
}
