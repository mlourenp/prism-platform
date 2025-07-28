# /iac/terraform/environments/dev/outputs.tf

output "data_lake_bucket_id" {
  description = "The ID of the dev data lake S3 bucket."
  value       = module.data_lake.bucket_id
}

output "data_lake_bucket_arn" {
  description = "The ARN of the dev data lake S3 bucket."
  value       = module.data_lake.bucket_arn
}
