variable "bucket_name" {
  description = "The name of the S3 bucket for the data lake. Must be globally unique."
  type        = string
  default     = "prism-platform-data-lake-unique" # CHANGE THIS to a unique name
}

variable "region" {
  description = "The AWS region where the S3 bucket will be created."
  type        = string
  default     = "us-east-1"
}
