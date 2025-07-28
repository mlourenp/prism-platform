output "data_lake_bucket_name" {
  description = "The name of the S3 data lake bucket."
  value       = aws_s3_bucket.data_lake.bucket
}

output "data_lake_bucket_arn" {
  description = "The ARN of the S3 data lake bucket."
  value       = aws_s3_bucket.data_lake.arn
}
